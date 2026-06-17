//
//  ContentView.swift
//  chocho
//
//  Created by Ekar on 2026/5/22.
//

import Photos
import SwiftUI
import UIKit

// MARK: - 根屏幕
/// 全屏布局入口：画布、顶栏、底部面板、导出与草稿均由本视图协调。
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    // MARK: 底部面板与波点编辑状态
    @State private var hasEnteredHome = false
    @State private var shouldAutoAdvanceHome = true
    @State private var selectedTab: PanelTab = .dots
    @State private var isRecentPhotoPickerPresented = false
    @State private var didAutoPresentPhotoPicker = false
    @State private var canvasImage: UIImage?
    @State private var extensionRatio: CGFloat = PuzzleCanvasDefaults.defaultExtensionRatio
    @State private var extensionSide: PuzzleCanvasExtensionSide = .right
    @State private var backgroundStyle: PuzzleBackgroundStyle = .grid
    @State private var backgroundColors = PuzzleBackgroundColors.default
    @State private var backgroundPatternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue
    @State private var imageViewportResetID = UUID()
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset: CGSize = .zero
    @State private var isPanelExpanded = true
    @State private var panelVisibleHeight: CGFloat = 0
    @State private var dotCount: Double = 10
    @State private var dotScale: Double = DotSizeControl.defaultRenderedScale
    @State private var selectedDotColor: Color = .clear
    @State private var usesRandomDotColors = false
    @State private var selectedDotShape: DotShapeAsset = .defaultSelection
    @State private var selectedDotShapeCategory: DotShapeCategory = .basic
    @State private var dotCharacterText = CharacterDotText.defaultText
    @State private var isTraceDrawingEnabled = false
    @State private var photoCompression: MainPhotoCompression = .none
    @State private var isDrawingSubjectDots = false
    @State private var subjectDotGenerationID = UUID()

    // MARK: 实况动画（预览播放与导出格式由 liveDotAnimation 决定）
    @State private var liveDotAnimation: LiveDotAnimation = .none
    @State private var livePreviewPlaybackStart: Date?
    @State private var livePreviewProgress: Double = 0
    @State private var livePreviewPlaybackTask: Task<Void, Never>?
    /// 当前画布照片是否来自相册 Live Photo（上传时识别，草稿恢复时为 false）。
    @State private var isSourceLivePhoto = false
    /// 「原图实况」开关；仅 `isSourceLivePhoto` 为 true 时可交互。
    @State private var isSourceLiveMotionEnabled = false
    /// 相册 `PHAsset` local identifier，供后续加载配对视频。
    @State private var sourcePhotoAssetLocalIdentifier: String?
    @State private var sourceLiveVideo: CanvasSourceLiveVideo?

    @State private var tracePoints: [PuzzleCanvasTracePoint] = []
    @State private var puzzleDots: [PuzzleDot] = []
    @State private var canvasHistory = CanvasHistory<[PuzzleDot]>(initialValue: [])
    @State private var showsClearCanvasConfirmation = false
    @State private var isDotEditingEnabled = false
    @State private var selectedDotID: UUID?

    // MARK: 导出与分享
    @State private var toastMessage: CanvasToastMessage?
    @State private var isPhotoLoading = false
    @State private var isExporting = false
    @State private var shareItem: CanvasShareItem?
    @State private var exportSession: CanvasExportSession?
    @State private var shareSheetDetent: PresentationDetent = .medium
    @State private var lastMagnification: CGFloat = 1

    // MARK: 画布草稿（自动保存 / 冷启动恢复）
    @State private var hasAttemptedDraftRestore = false
    @State private var pendingDraftSave: Task<Void, Never>?

    var body: some View {
        ZStack {
            applyLifecycleModifiers(to: rootLayout)

            if !hasEnteredHome {
                HomeLandingView(
                    isStartupWorkReady: isStartupWorkReady,
                    shouldAutoAdvance: shouldAutoAdvanceHome
                ) {
                    hasEnteredHome = true
                    shouldAutoAdvanceHome = true
                }
            }
        }
    }

    private var isStartupWorkReady: Bool {
        hasAttemptedDraftRestore && !isPhotoLoading
    }

    private var rootLayout: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    canvasArea
                        .padding(.top, topCanvasInset(for: proxy))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    CanvasHeader(
                        canDownload: canvasImage != nil,
                        isBusy: isPhotoLoading || isExporting,
                        onBack: presentRecentPhotoPicker,
                        onDownload: shareCanvas
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                bottomPanel(proxy: proxy)
            }
            .background {
                Color.background
                    .ignoresSafeArea()
            }
            .overlay {
                CanvasToastOverlay(message: $toastMessage)
            }
        }
    }

    @ViewBuilder
    private func applyLifecycleModifiers<Content: View>(to content: Content) -> some View {
        applyPresentationModifiers(
            to: applyDraftSaveObservers(
                to: applyAsyncTasks(to: content)
            )
        )
    }

    @ViewBuilder
    private func applyAsyncTasks<Content: View>(to content: Content) -> some View {
        content
            .task {
                await restoreCanvasDraftOnLaunch()
            }
            .onChange(of: hasEnteredHome) { _, entered in
                guard entered else { return }
                presentInitialPhotoPickerIfNeeded()
            }
            .onChange(of: hasAttemptedDraftRestore) { _, attempted in
                guard attempted else { return }
                presentInitialPhotoPickerIfNeeded()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: CanvasDraftStore.autosaveInterval)
                    persistCanvasDraft()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .background || newPhase == .inactive else { return }
                persistCanvasDraft()
            }
    }

    @ViewBuilder
    private func applyDraftSaveObservers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: extensionRatio) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: extensionSide) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundStyle) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundColors) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundPatternSpacing) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: dotScale) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: selectedDotColor) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: usesRandomDotColors) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: selectedDotShape) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: dotCharacterText) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: isTraceDrawingEnabled) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: photoCompression) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: liveDotAnimation) { _, _ in
                stopLivePreviewPlayback()
                scheduleCanvasDraftSave()
            }
            .onChange(of: isSourceLiveMotionEnabled) { _, _ in
                stopLivePreviewPlayback()
                scheduleCanvasDraftSave()
            }
            .onChange(of: dotCount) { _, newDotCount in
                syncPuzzleDots(to: Int(newDotCount.rounded()))
            }
    }

    @ViewBuilder
    private func applyPresentationModifiers<Content: View>(to content: Content) -> some View {
        content
            .sheet(item: $shareItem, onDismiss: handleShareSheetDismiss) { item in
                shareSheet(for: item)
            }
            .fullScreenCover(isPresented: $isRecentPhotoPickerPresented) {
                RecentPhotoPickerView(
                    isImporting: isPhotoLoading,
                    onCancel: dismissRecentPhotoPicker,
                    onSelectAsset: selectRecentPhotoAsset
                )
            }
            .modifier(ClearCanvasConfirmationAlertModifier(
                isPresented: $showsClearCanvasConfirmation,
                onConfirm: clearCanvasContent
            ))
    }

    private var bottomPanelInset: CGFloat {
        BottomSheetPanel.bottomPanelInset(
            isExpanded: isPanelExpanded,
            panelVisibleHeight: panelVisibleHeight
        )
    }

    private func bottomPanel(proxy: GeometryProxy) -> some View {
        BottomSheetPanel(
            panelVisibleHeight: $panelVisibleHeight,
            selectedTab: $selectedTab,
            isExpanded: $isPanelExpanded,
            isDotEditingEnabled: dotEditingModeBinding,
            dotControls: BottomSheetDotControls(
                dotCount: $dotCount,
                dotScale: dotScaleBinding,
                selectedDotColor: $selectedDotColor,
                usesRandomDotColors: $usesRandomDotColors,
                selectedDotShape: selectedDotShapeBinding,
                selectedDotShapeCategory: $selectedDotShapeCategory,
                dotCharacterText: $dotCharacterText,
                isTraceDrawingEnabled: $isTraceDrawingEnabled,
                photoCompression: $photoCompression,
                isDrawingSubjectDots: isDrawingSubjectDots
            ),
            liveControls: BottomSheetLiveControls(
                liveDotAnimation: $liveDotAnimation,
                isSourceLivePhoto: isSourceLivePhoto,
                isSourceLiveMotionEnabled: $isSourceLiveMotionEnabled,
                canPlayLivePreview: canPlayLivePreview,
                livePreviewProgress: livePreviewProgress,
                isLivePreviewPlaying: isLivePreviewPlaying,
                onToggleLivePreviewPlayback: toggleLivePreviewPlayback
            ),
            backgroundControls: BottomSheetBackgroundControls(
                extensionRatio: $extensionRatio,
                extensionSide: $extensionSide,
                backgroundStyle: $backgroundStyle,
                backgroundColors: $backgroundColors,
                backgroundPatternSpacing: $backgroundPatternSpacing
            ),
            bottomSafeAreaInset: proxy.safeAreaInsets.bottom,
            isPanelEnabled: canvasImage != nil,
            canClearTrace: !tracePoints.isEmpty,
            canUndo: canvasHistory.canUndo,
            canRedo: canvasHistory.canRedo,
            canClearCanvas: !puzzleDots.isEmpty,
            onDrawDots: drawPuzzleDots,
            onDrawSubjectDots: drawSubjectPuzzleDots,
            onClearTrace: clearTracePoints,
            onClearCanvas: presentClearCanvasConfirmation,
            onUndo: undoCanvasChange,
            onRedo: redoCanvasChange
        )
        // 面板视觉上延伸进底部安全区，由根视图统一处理，组件内不写 ignoresSafeArea
        .padding(.bottom, -proxy.safeAreaInsets.bottom)
    }

    private func shareSheet(for item: CanvasShareItem) -> some View {
        CanvasShareSheet(
            product: item.product,
            onBeginSaveToPhotos: handleSaveToPhotosStarted,
            onSaveToPhotos: handleSaveToPhotosResult
        )
        .presentationDetents([.medium, .large], selection: $shareSheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            shareSheetDetent = .medium
        }
    }

    @MainActor
    private func restoreCanvasDraftOnLaunch() async {
        guard !hasAttemptedDraftRestore else { return }
        await restoreCanvasDraftIfNeeded()
        hasAttemptedDraftRestore = true
    }

    @ViewBuilder
    private var canvasArea: some View {
        if let canvasImage {
            GeometryReader { canvasProxy in
                let canvas = PuzzleCanvasView(
                    image: canvasImage,
                    extensionRatio: extensionRatio,
                    extensionSide: extensionSide,
                    photoCompression: photoCompression,
                    backgroundStyle: backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
                    imageViewportResetID: imageViewportResetID,
                    bottomPanelInset: bottomPanelInset,
                    dots: puzzleDots,
                    dotScale: CGFloat(dotScale),
                    dotColor: selectedDotColor,
                    usesRandomDotColors: usesRandomDotColors,
                    dotCharacterText: dotCharacterText,
                    viewportScale: viewportScale,
                    viewportOffset: viewportOffset,
                    tracePoints: tracePoints,
                    isTraceDrawingEnabled: isTraceDrawingEnabled,
                    liveDotAnimation: liveDotAnimation,
                    livePreviewPlaybackStart: livePreviewPlaybackStart,
                    isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
                    sourceLiveVideo: sourceLiveVideo,
                    isDotEditingEnabled: isDotEditingEnabled,
                    selectedDotID: selectedDotID,
                    onTapCanvas: addPuzzleDot(at:),
                    onPanViewport: panCanvasViewport(by:),
                    onDoubleTapBackground: applyCanvasViewportReset,
                    onViewportReset: applyCanvasViewportResetWithoutAnimation,
                    onTraceChanged: updateTracePoints,
                    onSelectDot: selectDot,
                    onMoveSelectedDot: previewMoveSelectedDot(to:),
                    onScaleSelectedDot: previewScaleSelectedDot(by:),
                    onRotateSelectedDot: previewRotateSelectedDot(by:),
                    onCommitSelectedDotEdit: commitSelectedDotEdit,
                    onDeleteSelectedDot: deleteSelectedDot
                )

                canvas
                    .simultaneousGesture(
                        canvasMagnifyGesture(
                            availableSize: canvasProxy.size,
                            isEnabled: !isTraceDrawingEnabled && selectedDotID == nil
                        )
                    )
            }
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, bottomPanelInset)
        }
    }

    private func topCanvasInset(for proxy: GeometryProxy) -> CGFloat {
        topActionBarHeight
    }

    private var topActionBarHeight: CGFloat {
        50
    }

    private var isLivePreviewPlaying: Bool {
        livePreviewPlaybackStart != nil
    }

    private var canPlayLivePreview: Bool {
        CanvasLiveMotionTiming.canPlayLivePreview(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            isSourceLivePhoto: isSourceLivePhoto,
            hasSourceLiveVideo: sourceLiveVideo != nil
        )
    }

    private var selectedDotIndex: Int? {
        guard let selectedDotID else { return nil }
        return puzzleDots.firstIndex { $0.id == selectedDotID }
    }

    private var selectedDot: PuzzleDot? {
        guard let selectedDotIndex else { return nil }
        return puzzleDots[selectedDotIndex]
    }

    private var dotEditingModeBinding: Binding<Bool> {
        Binding(
            get: { isDotEditingEnabled },
            set: { setDotEditingMode($0) }
        )
    }

    private var dotScaleBinding: Binding<Double> {
        Binding(
            get: {
                if let selectedDot {
                    return Double(selectedDot.resolvedRenderedScale(globalDotScale: CGFloat(dotScale)))
                }
                return dotScale
            },
            set: { newValue in
                if selectedDotID != nil {
                    applySelectedDotEdit { dot in
                        dot.editing(scaleOverride: CGFloat(newValue))
                    }
                } else {
                    dotScale = newValue
                }
            }
        )
    }

    private var selectedDotShapeBinding: Binding<DotShapeAsset> {
        Binding(
            get: {
                if let selectedDot {
                    return DotShapeAsset.asset(named: selectedDot.resolvedShapeAssetName)
                        ?? DotShapeAsset(name: selectedDot.resolvedShapeAssetName)
                }
                return selectedDotShape
            },
            set: { newShape in
                if selectedDotID != nil {
                    applySelectedDotEdit { dot in
                        dot.editing(shapeAssetNameOverride: newShape.name)
                    }
                    selectedDotShapeCategory = DotShapeCategory.panelOrder.first {
                        newShape.matches(category: $0)
                    } ?? .basic
                } else {
                    selectedDotShape = newShape
                }
            }
        )
    }

    @MainActor
    private func showToast(_ title: String) {
        toastMessage = CanvasToastMessage(title)
    }

    @MainActor
    private func dismissToast() {
        toastMessage = nil
    }

    private func presentInitialPhotoPickerIfNeeded() {
        guard hasEnteredHome else { return }
        guard hasAttemptedDraftRestore else { return }
        guard canvasImage == nil else { return }
        guard !didAutoPresentPhotoPicker else { return }
        guard !isRecentPhotoPickerPresented else { return }
        didAutoPresentPhotoPicker = true
        isRecentPhotoPickerPresented = true
    }

    private func presentRecentPhotoPicker() {
        guard !isPhotoLoading && !isExporting else { return }
        isRecentPhotoPickerPresented = true
    }

    private func dismissRecentPhotoPicker() {
        guard !isPhotoLoading else { return }
        isRecentPhotoPickerPresented = false
    }

    private var livePreviewDuration: TimeInterval {
        CanvasLiveMotionTiming.exportDuration(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            sourceLiveVideoDuration: sourceLiveVideo?.duration
        )
    }

    /// 实况 Tab 内的「预览」：按导出时长循环更新 livePreviewProgress，驱动画布 TimelineView。
    private func toggleLivePreviewPlayback() {
        if isLivePreviewPlaying {
            stopLivePreviewPlayback()
        } else {
            startLivePreviewPlayback()
        }
    }

    @MainActor
    private func startLivePreviewPlayback() {
        guard canPlayLivePreview else { return }

        livePreviewPlaybackTask?.cancel()
        let duration = livePreviewDuration
        guard duration > 0 else { return }
        let start = Date()
        livePreviewPlaybackStart = start
        livePreviewProgress = 0

        livePreviewPlaybackTask = Task { @MainActor in
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                livePreviewProgress = min(1, elapsed / duration)
                if elapsed >= duration {
                    stopLivePreviewPlayback()
                    return
                }
                try? await Task.sleep(for: .seconds(1.0 / 60.0))
            }
        }
    }

    @MainActor
    private func stopLivePreviewPlayback() {
        livePreviewPlaybackTask?.cancel()
        livePreviewPlaybackTask = nil
        livePreviewPlaybackStart = nil
        livePreviewProgress = 0
    }

    @MainActor
    private func applyPhotoUploadDefaults() {
        selectedDotShape = DotShapeAsset(name: PuzzleCanvasUploadDefaults.dotShapeName)
        selectedDotShapeCategory = .basic
        dotScale = PuzzleCanvasUploadDefaults.dotScale
        selectedTab = .draw
    }

    @MainActor
    private func selectRecentPhotoAsset(_ asset: PHAsset) {
        guard !isPhotoLoading && !isExporting else { return }

        Task {
            await loadRecentPhotoAsset(asset)
        }
    }

    @MainActor
    private func loadRecentPhotoAsset(_ asset: PHAsset) async {
        isPhotoLoading = true
        showToast("正在加载…")
        invalidateSubjectDotGeneration()
        defer {
            isPhotoLoading = false
        }

        do {
            let importResult = try await CanvasPhotoImport.importPhoto(from: asset)
            await applyImportedPhotoSource(importResult.source)
            isRecentPhotoPickerPresented = false
            dismissToast()
            persistCanvasDraft()
        } catch {
            isRecentPhotoPickerPresented = false
            showToast("上传失败")
        }
    }

    @MainActor
    private func applyImportedPhotoSource(_ source: CanvasPhotoSource) async {
        applyPhotoUploadDefaults()

        let initialDots = PuzzleCanvasUploadDefaults.initialDots(dotCount: dotCount)

        isSourceLivePhoto = source.isLivePhoto
        isSourceLiveMotionEnabled = false
        sourcePhotoAssetLocalIdentifier = source.assetLocalIdentifier
        sourceLiveVideo?.removeTemporaryFiles()
        sourceLiveVideo = nil
        if source.isLivePhoto {
            sourceLiveVideo = await CanvasSourceLiveVideo.load(
                assetLocalIdentifier: source.assetLocalIdentifier
            )
        }
        canvasImage = source.keyPhoto
        imageViewportResetID = UUID()
        viewportScale = 1
        viewportOffset = .zero
        lastMagnification = 1
        isDotEditingEnabled = false
        selectedDotID = nil
        tracePoints = []
        canvasHistory.reset(to: [])
        puzzleDots = []

        await Task.yield()

        applyPuzzleDots(initialDots)
    }

    /// 「抽卡」：沿轨迹或随机布局生成波点，并记入撤销栈。
    @MainActor
    private func drawPuzzleDots() {
        guard canvasImage != nil else {
            showToast("请先上传图片")
            return
        }

        invalidateSubjectDotGeneration()

        let newDots = PuzzleDotFactory.makeDots(
            count: Int(dotCount.rounded()),
            along: tracePoints,
            extensionRatio: extensionRatio,
            shapeAssetName: selectedDotShape.name
        )
        if isTraceDrawingEnabled {
            guard !tracePoints.isEmpty else {
                showToast("先画一条轨迹")
                return
            }

            guard !newDots.isEmpty else {
                showToast("右侧背景太窄")
                return
            }
        }

        let fallbackDots = isTraceDrawingEnabled
            ? newDots
            : PuzzleDotFactory.makeDots(
                count: Int(dotCount.rounded()),
                shapeAssetName: selectedDotShape.name
        )
        applyPuzzleDots(fallbackDots)
        dismissToast()
    }

    @MainActor
    private func drawSubjectPuzzleDots() {
        guard let canvasImage else {
            showToast("请先上传图片")
            return
        }
        guard !isDrawingSubjectDots else { return }

        let generationID = UUID()
        subjectDotGenerationID = generationID
        isDrawingSubjectDots = true
        showToast("正在识别主体…")

        Task {
            do {
                let dots = try await SubjectContourDotGenerator().dots(
                    for: canvasImage,
                    count: Int(dotCount.rounded()),
                    shapeAssetName: selectedDotShape.name
                )
                await MainActor.run {
                    guard subjectDotGenerationID == generationID else { return }
                    applyPuzzleDots(dots)
                    isDrawingSubjectDots = false
                    dismissToast()
                }
            } catch {
                await MainActor.run {
                    guard subjectDotGenerationID == generationID else { return }
                    isDrawingSubjectDots = false
                    showToast(subjectDotErrorMessage(for: error))
                }
            }
        }
    }

    private func subjectDotErrorMessage(for error: Error) -> String {
        guard let generationError = error as? SubjectContourDotGenerationError else {
            return "主体识别失败"
        }

        switch generationError {
        case .unsupported:
            return "当前系统不支持主体识别"
        case .missingImage:
            return "主体识别失败"
        case .noSubject:
            return "没识别到主体"
        }
    }

    @MainActor
    private func syncPuzzleDots(to count: Int) {
        guard canvasImage != nil else { return }

        invalidateSubjectDotGeneration()

        let syncedDots: [PuzzleDot]
        if isTraceDrawingEnabled, !tracePoints.isEmpty {
            syncedDots = PuzzleDotFactory.makeDots(
                count: count,
                along: tracePoints,
                extensionRatio: extensionRatio,
                shapeAssetName: selectedDotShape.name
            )
        } else {
            syncedDots = PuzzleDotFactory.adjusting(
                puzzleDots,
                toCount: count,
                shapeAssetName: selectedDotShape.name
            )
        }
        applyPuzzleDots(syncedDots)
    }

    @MainActor
    private func addPuzzleDot(at location: PuzzleCanvasTracePoint) {
        guard !isDotEditingEnabled else { return }
        invalidateSubjectDotGeneration()

        let position = PuzzleCanvasCoordinate.dotPosition(
            for: location,
            extensionSide: extensionSide
        )
        var newDots = puzzleDots
        newDots.append(PuzzleDotFactory.makeDot(
            position: position,
            index: puzzleDots.count,
            shapeAssetName: selectedDotShape.name
        ))
        applyPuzzleDots(newDots)
        dismissToast()
    }

    @MainActor
    private func updateTracePoints(_ points: [PuzzleCanvasTracePoint]) {
        invalidateSubjectDotGeneration()
        tracePoints = points
        dismissToast()
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func setDotEditingMode(_ isEnabled: Bool) {
        if isEnabled {
            guard canvasImage != nil else { return }
            guard !isDotEditingEnabled else { return }

            withoutAnimation {
                isTraceDrawingEnabled = false
                isDotEditingEnabled = true
                selectedDotID = nil
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismissToast()
        } else {
            guard isDotEditingEnabled || selectedDotID != nil else { return }

            withoutAnimation {
                isDotEditingEnabled = false
                selectedDotID = nil
            }
        }
    }

    @MainActor
    private func selectDot(_ dotID: UUID?) {
        guard isDotEditingEnabled else { return }

        selectedDotID = dotID
        if dotID == nil {
            return
        }
        if let selectedDot {
            let asset = DotShapeAsset.asset(named: selectedDot.resolvedShapeAssetName)
                ?? DotShapeAsset(name: selectedDot.resolvedShapeAssetName)
            selectedDotShapeCategory = DotShapeCategory.panelOrder.first {
                asset.matches(category: $0)
            } ?? .basic
        }
    }

    @MainActor
    private func previewMoveSelectedDot(to position: CGPoint) {
        previewSelectedDotEdit { dot in
            dot.editing(position: position)
        }
    }

    @MainActor
    private func previewScaleSelectedDot(by multiplier: CGFloat) {
        guard multiplier.isFinite, multiplier > 0 else { return }

        previewSelectedDotEdit { dot in
            let currentScale = dot.resolvedRenderedScale(globalDotScale: CGFloat(dotScale))
            let nextScale = min(
                max(currentScale * multiplier, CGFloat(DotSizeControl.minRenderedScale)),
                CGFloat(DotSizeControl.maxRenderedScale)
            )
            return dot.editing(scaleOverride: nextScale)
        }
    }

    @MainActor
    private func previewRotateSelectedDot(by degrees: CGFloat) {
        guard degrees.isFinite else { return }

        previewSelectedDotEdit { dot in
            dot.editing(rotationDegrees: dot.rotationDegrees + degrees)
        }
    }

    @MainActor
    private func commitSelectedDotEdit() {
        canvasHistory.record(puzzleDots)
        puzzleDots = canvasHistory.currentValue
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func deleteSelectedDot() {
        guard let selectedDotID else { return }

        let editedDots = puzzleDots.filter { $0.id != selectedDotID }
        self.selectedDotID = nil
        applyPuzzleDots(editedDots)
    }

    @MainActor
    private func previewSelectedDotEdit(_ transform: (PuzzleDot) -> PuzzleDot) {
        guard let selectedDotIndex else { return }

        var editedDots = puzzleDots
        editedDots[selectedDotIndex] = transform(editedDots[selectedDotIndex])
        puzzleDots = editedDots
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func applySelectedDotEdit(_ transform: (PuzzleDot) -> PuzzleDot) {
        guard let selectedDotIndex else { return }

        var editedDots = puzzleDots
        editedDots[selectedDotIndex] = transform(editedDots[selectedDotIndex])
        canvasHistory.record(editedDots)
        puzzleDots = canvasHistory.currentValue
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func clearTracePoints() {
        guard !tracePoints.isEmpty else { return }

        invalidateSubjectDotGeneration()
        tracePoints = []
        dismissToast()
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func presentClearCanvasConfirmation() {
        guard !puzzleDots.isEmpty else { return }

        showsClearCanvasConfirmation = true
    }

    @MainActor
    private func clearCanvasContent() {
        guard !puzzleDots.isEmpty else { return }

        invalidateSubjectDotGeneration()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            puzzleDots = canvasHistory.clearValue()
        }
        selectedDotID = nil
        dismissToast()
    }

    @MainActor
    private func undoCanvasChange() {
        guard let previousDots = canvasHistory.undo() else { return }

        invalidateSubjectDotGeneration()
        puzzleDots = previousDots
        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        dismissToast()
    }

    @MainActor
    private func redoCanvasChange() {
        guard let nextDots = canvasHistory.redo() else { return }

        invalidateSubjectDotGeneration()
        puzzleDots = nextDots
        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        dismissToast()
    }

    @MainActor
    private func invalidateSubjectDotGeneration() {
        subjectDotGenerationID = UUID()
        if isDrawingSubjectDots {
            isDrawingSubjectDots = false
        }
    }

    @MainActor
    private func applyPuzzleDots(_ dots: [PuzzleDot]) {
        canvasHistory.record(dots)
        puzzleDots = canvasHistory.currentValue
        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        dismissToast()
        scheduleCanvasDraftSave()
    }

    /// 仅在没有当前照片时恢复上次草稿，避免覆盖用户刚选中的图。
    @MainActor
    private func restoreCanvasDraftIfNeeded() async {
        guard canvasImage == nil else { return }

        guard let restored = await CanvasDraftStore.load() else { return }

        canvasImage = restored.image
        liveDotAnimation = restored.liveDotAnimation
        isSourceLiveMotionEnabled = restored.isSourceLiveMotionEnabled
        sourcePhotoAssetLocalIdentifier = restored.sourcePhotoAssetLocalIdentifier
        sourceLiveVideo?.removeTemporaryFiles()
        sourceLiveVideo = nil
        if let identifier = restored.sourcePhotoAssetLocalIdentifier {
            sourceLiveVideo = await CanvasSourceLiveVideo.load(assetLocalIdentifier: identifier)
            isSourceLivePhoto = sourceLiveVideo != nil
        } else {
            isSourceLivePhoto = false
        }
        extensionRatio = restored.extensionRatio
        extensionSide = restored.extensionSide
        backgroundStyle = restored.backgroundStyle
        backgroundColors = restored.backgroundColors
        backgroundPatternSpacing = restored.backgroundPatternSpacing
        photoCompression = restored.photoCompression
        dotCount = restored.dotCount
        dotScale = restored.dotScale
        selectedDotColor = restored.selectedDotColor
        usesRandomDotColors = restored.usesRandomDotColors
        selectedDotShape = DotShapeAsset.asset(named: restored.selectedDotShapeName)
            ?? .defaultSelection
        dotCharacterText = restored.dotCharacterText
        isTraceDrawingEnabled = restored.isTraceDrawingEnabled
        tracePoints = restored.tracePoints
        viewportScale = restored.viewportScale
        viewportOffset = restored.viewportOffset
        lastMagnification = 1
        imageViewportResetID = UUID()
        canvasHistory.reset(to: restored.puzzleDots)
        puzzleDots = restored.puzzleDots
        isDotEditingEnabled = false
        selectedDotID = nil
        dismissToast()
    }

    @MainActor
    private func scheduleCanvasDraftSave() {
        pendingDraftSave?.cancel()
        pendingDraftSave = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            persistCanvasDraft()
        }
    }

    @MainActor
    private func persistCanvasDraft() {
        pendingDraftSave?.cancel()
        pendingDraftSave = nil

        guard let canvasImage else {
            Task { await CanvasDraftStore.clear() }
            return
        }

        let capture = CanvasDraftCapture(
            image: canvasImage,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            dotCount: dotCount,
            dotScale: dotScale,
            selectedDotColor: selectedDotColor,
            usesRandomDotColors: usesRandomDotColors,
            selectedDotShapeName: selectedDotShape.name,
            dotCharacterText: dotCharacterText,
            isTraceDrawingEnabled: isTraceDrawingEnabled,
            photoCompression: photoCompression,
            puzzleDots: puzzleDots,
            tracePoints: tracePoints,
            viewportScale: viewportScale,
            viewportOffset: viewportOffset,
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            sourcePhotoAssetLocalIdentifier: sourcePhotoAssetLocalIdentifier
        )

        Task {
            await CanvasDraftStore.save(capture)
        }
    }

    @MainActor
    private func applyCanvasViewportReset(scale: CGFloat, offset: CGSize) {
        withAnimation(.easeInOut(duration: 0.24)) {
            viewportScale = scale
            viewportOffset = offset
        }
    }

    @MainActor
    private func applyCanvasViewportResetWithoutAnimation(scale: CGFloat, offset: CGSize) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewportScale = scale
            viewportOffset = offset
        }
    }

    /// 下载入口：按 `LiveDotAnimation` 选静态 JPEG 或 Live Photo（关键帧 + 配对视频）。
    @MainActor
    private func shareCanvas() {
        guard let canvasImage else {
            showToast("请先上传图片")
            return
        }

        guard !isExporting else { return }

        isExporting = true
        let hasSourceLiveVideo = isSourceLiveMotionEnabled && sourceLiveVideo != nil
        let snapshot = CanvasExportSnapshot(
            image: canvasImage,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide,
            photoCompression: photoCompression,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            dots: puzzleDots,
            dotScale: CGFloat(dotScale),
            dotColor: selectedDotColor,
            usesRandomDotColors: usesRandomDotColors,
            dotCharacterText: dotCharacterText,
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            hasSourceLiveVideo: hasSourceLiveVideo,
            sourcePhotoAssetLocalIdentifier: sourcePhotoAssetLocalIdentifier
        )
        showToast(snapshot.exportsAsLivePhoto ? "正在导出实况…" : "正在导出…")

        let preloadedSourceLiveVideo = sourceLiveVideo

        Task {
            defer { isExporting = false }

            let exportSize = exportCanvasSize(
                for: snapshot.image,
                photoCompression: snapshot.photoCompression
            )
            let exportFormat = snapshot.exportFormat

            let product: CanvasExportProduct? = await Task.detached(priority: .userInitiated) {
                switch exportFormat {
                case .livePhoto:
                    let liveSnapshot = CanvasLivePhotoExporter.Snapshot(
                        image: snapshot.image,
                        extensionRatio: snapshot.extensionRatio,
                        extensionSide: snapshot.extensionSide,
                        photoCompression: snapshot.photoCompression,
                        backgroundStyle: snapshot.backgroundStyle,
                        backgroundColors: snapshot.backgroundColors,
                        backgroundPatternSpacing: snapshot.backgroundPatternSpacing,
                        dots: snapshot.dots,
                        dotScale: snapshot.dotScale,
                        dotColor: snapshot.dotColor,
                        usesRandomDotColors: snapshot.usesRandomDotColors,
                        dotCharacterText: snapshot.dotCharacterText,
                        liveDotAnimation: snapshot.liveDotAnimation,
                        isSourceLiveMotionEnabled: snapshot.isSourceLiveMotionEnabled,
                        hasSourceLiveVideo: snapshot.hasSourceLiveVideo,
                        sourcePhotoAssetLocalIdentifier: snapshot.sourcePhotoAssetLocalIdentifier
                    )
                    guard let bundle = await CanvasLivePhotoExporter.export(
                        snapshot: liveSnapshot,
                        keyPhotoSize: exportSize,
                        preloadedSourceLiveVideo: preloadedSourceLiveVideo
                    ) else {
                        return nil
                    }
                    return .livePhoto(bundle)

                case .staticJPEG:
                    guard let renderedImage = CanvasRasterExporter.render(
                        image: snapshot.image,
                        exportSize: exportSize,
                        extensionRatio: snapshot.extensionRatio,
                        extensionSide: snapshot.extensionSide,
                        photoCompression: snapshot.photoCompression,
                        backgroundStyle: snapshot.backgroundStyle,
                        backgroundColors: snapshot.backgroundColors,
                        backgroundPatternSpacing: snapshot.backgroundPatternSpacing,
                        dots: snapshot.dots,
                        dotScale: snapshot.dotScale,
                        dotColor: snapshot.dotColor,
                        usesRandomDotColors: snapshot.usesRandomDotColors,
                        dotCharacterText: snapshot.dotCharacterText
                    ) else {
                        return nil
                    }

                    guard let fileURL = CanvasExportWriter.writeTemporaryStillImage(renderedImage) else {
                        return nil
                    }
                    return .stillImage(fileURL)
                }
            }.value

            guard let product else {
                showToast(snapshot.exportsAsLivePhoto ? "实况导出失败" : "导出失败")
                return
            }

            dismissToast()

            // 在弹出分享页之前于主线程预请求相册权限，避免 UIActivityViewController 挡住系统对话框。
            _ = await CanvasPhotoLibrarySaver.requestAuthorization()

            cleanupCurrentExportSession()
            exportSession = CanvasExportSession(product: product)
            shareItem = CanvasShareItem(product: product)
        }
    }

    @MainActor
    private func handleShareSheetDismiss() {
        guard var exportSession else {
            return
        }
        exportSession.handleDismiss()
        self.exportSession = exportSession.hasCleanedUp ? nil : exportSession
    }

    @MainActor
    private func handleSaveToPhotosStarted() {
        guard var exportSession else { return }

        exportSession.markSaveInProgress()
        self.exportSession = exportSession
    }

    @MainActor
    private func handleSaveToPhotosResult(_ didSave: Bool) {
        if didSave {
            showToast("已保存到相册")
        } else {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .denied || status == .restricted {
                showToast("保存失败，请在设置中允许访问相册")
            } else {
                showToast("保存失败")
            }
        }
        if var exportSession {
            exportSession.handleSaveFinished()
            self.exportSession = nil
        }
    }

    /// 导出像素尺寸：原图边长 + 扩展条比例（与 `PuzzleCanvasLayout` 合成逻辑一致）。
    private func exportCanvasSize(
        for image: UIImage,
        photoCompression: MainPhotoCompression
    ) -> CGSize {
        let sourceWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let sourceHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        let compressedSize = photoCompression.compressedSize(
            for: CGSize(width: sourceWidth, height: sourceHeight)
        )
        let clampedRatio = min(max(extensionRatio, 0), 1)

        switch extensionSide {
        case .left, .right:
            return CGSize(
                width: compressedSize.width * (1 + clampedRatio),
                height: compressedSize.height
            )
        case .top, .bottom:
            return CGSize(
                width: compressedSize.width,
                height: compressedSize.height * (1 + clampedRatio)
            )
        case .center:
            return compressedSize
        }
    }

    @MainActor
    private func panCanvasViewport(by translation: CGSize) {
        viewportOffset = viewportOffset + translation
    }

    private func canvasMagnifyGesture(
        availableSize: CGSize,
        isEnabled: Bool
    ) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard isEnabled else { return }

                let magnificationDelta = value.magnification / lastMagnification
                guard magnificationDelta.isFinite, magnificationDelta > 0 else { return }

                let anchor = value.startLocation
                let nextScale = PuzzleCanvasViewport.clampedScale(
                    viewportScale * magnificationDelta
                )
                let appliedMultiplier = nextScale / viewportScale
                guard appliedMultiplier.isFinite, appliedMultiplier > 0 else { return }

                viewportOffset = PuzzleCanvasViewport.adjustedOffset(
                    anchor: anchor,
                    availableSize: availableSize,
                    scaleMultiplier: appliedMultiplier,
                    baseOffset: viewportOffset
                )
                viewportScale = nextScale
                lastMagnification = value.magnification
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    @MainActor
    private func cleanupCurrentExportSession() {
        guard var exportSession else { return }

        exportSession.cleanupNow()
        self.exportSession = nil
    }

    @MainActor
    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }
}

private struct ClearCanvasConfirmationAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert("打扫波点", isPresented: $isPresented) {
            Button("取消", role: .cancel) {}
            Button("打扫", role: .destructive, action: onConfirm)
        } message: {
            Text("你想要把画布上的波点都打扫掉吗？")
        }
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

private struct CanvasShareItem: Identifiable {
    let id = UUID()
    let product: CanvasExportProduct

    var shareItems: [Any] { product.shareItems }
}
