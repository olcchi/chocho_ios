//
//  ContentView.swift
//  chocho
//
//  Created by Ekar on 2026/5/22.
//

import Photos
import PhotosUI
import SwiftUI
import UIKit

// MARK: - 根屏幕
/// 全屏布局入口：画布、顶栏、底部面板、导出与草稿均由本视图协调。
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    // MARK: 底部面板与波点编辑状态
    @State private var selectedTab: PanelTab = .dots
    @State private var selectedPhotoItem: PhotosPickerItem?
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

    // MARK: 导出与分享
    @State private var toastMessage: CanvasToastMessage?
    @State private var isPhotoLoading = false
    @State private var isExporting = false
    @State private var shareItem: CanvasShareItem?
    @State private var exportSession: CanvasExportSession?
    @State private var shareSheetDetent: PresentationDetent = .medium
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    // MARK: 画布草稿（自动保存 / 冷启动恢复）
    @State private var hasAttemptedDraftRestore = false
    @State private var pendingDraftSave: Task<Void, Never>?

    var body: some View {
        applyLifecycleModifiers(to: rootLayout)
    }

    private var rootLayout: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    canvasArea
                        .padding(.top, topCanvasInset(for: proxy))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    panelBackgroundColor
                        .ignoresSafeArea(edges: .top)
                        .frame(height: topActionBarHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)

                    CanvasHeader(
                        selectedPhotoItem: $selectedPhotoItem,
                        canDownload: canvasImage != nil,
                        isBusy: isPhotoLoading || isExporting,
                        onDownload: shareCanvas
                    )
                    .padding(.top, 4)
                    .padding(.horizontal, BottomSheetPanel.contentHorizontalInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
            .task {
                await restoreCanvasDraftOnLaunch()
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

    private var historyControlsOverlay: some View {
        CanvasHistoryControls(
            canUndo: canvasHistory.canUndo,
            canRedo: canvasHistory.canRedo,
            canClear: !puzzleDots.isEmpty,
            onClear: presentClearCanvasConfirmation,
            onUndo: undoCanvasChange,
            onRedo: redoCanvasChange
        )
        .padding(.trailing, BottomSheetPanel.contentHorizontalInset)
        .offset(y: -BottomSheetPanel.historyControlsClearance)
    }

    private func bottomPanel(proxy: GeometryProxy) -> some View {
        BottomSheetPanel(
            panelVisibleHeight: $panelVisibleHeight,
            selectedTab: $selectedTab,
            isExpanded: $isPanelExpanded,
            dotControls: BottomSheetDotControls(
                dotCount: $dotCount,
                dotScale: $dotScale,
                selectedDotColor: $selectedDotColor,
                usesRandomDotColors: $usesRandomDotColors,
                selectedDotShape: $selectedDotShape,
                selectedDotShapeCategory: $selectedDotShapeCategory,
                dotCharacterText: $dotCharacterText,
                isTraceDrawingEnabled: $isTraceDrawingEnabled
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
            onDrawDots: drawPuzzleDots,
            onClearTrace: clearTracePoints
        )
        .overlay(alignment: .topTrailing) {
            historyControlsOverlay
        }
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
        hasAttemptedDraftRestore = true
        await restoreCanvasDraftIfNeeded()
    }

    @ViewBuilder
    private var canvasArea: some View {
        if let canvasImage {
            GeometryReader { canvasProxy in
                let canvas = PuzzleCanvasView(
                    image: canvasImage,
                    extensionRatio: extensionRatio,
                    extensionSide: extensionSide,
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
                    gestureOffset: gestureOffset,
                    tracePoints: tracePoints,
                    isTraceDrawingEnabled: isTraceDrawingEnabled,
                    liveDotAnimation: liveDotAnimation,
                    livePreviewPlaybackStart: livePreviewPlaybackStart,
                    isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
                    sourceLiveVideo: sourceLiveVideo,
                    onTapCanvas: addPuzzleDot(at:),
                    onDoubleTapBackground: applyCanvasViewportReset,
                    onViewportReset: applyCanvasViewportResetWithoutAnimation,
                    onTraceChanged: updateTracePoints
                )

                if isTraceDrawingEnabled {
                    canvas
                } else {
                    canvas.gesture(canvasGesture(availableSize: canvasProxy.size))
                }
            }
        } else {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: CanvasPhotoImport.pickerMatching,
                preferredItemEncoding: .current,
                photoLibrary: CanvasPhotoImport.pickerPhotoLibrary
            ) {
                CanvasUploadPlaceholder()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, bottomPanelInset)
        }
    }

    private func topCanvasInset(for proxy: GeometryProxy) -> CGFloat {
        topActionBarHeight
    }

    private var topActionBarHeight: CGFloat {
        50
    }

    private var panelBackgroundColor: Color {
        Color.popover
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

    @MainActor
    private func showToast(_ title: String) {
        toastMessage = CanvasToastMessage(title)
    }

    @MainActor
    private func dismissToast() {
        toastMessage = nil
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
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        isPhotoLoading = true
        showToast("正在加载…")
        defer {
            isPhotoLoading = false
        }

        do {
            await CanvasPhotoImport.requestPhotoLibraryReadAccessIfNeeded()
            let importResult = try await CanvasPhotoImport.importPhoto(from: selectedPhotoItem)
            let source = importResult.source
            let image = source.keyPhoto

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
            canvasImage = image
            imageViewportResetID = UUID()
            viewportScale = 1
            viewportOffset = .zero
            lastMagnification = 1
            tracePoints = []
            canvasHistory.reset(to: [])
            puzzleDots = []

            await Task.yield()

            applyPuzzleDots(initialDots)
            dismissToast()
            persistCanvasDraft()
        } catch {
            showToast("上传失败")
        }
    }

    /// 「抽卡」：沿轨迹或随机布局生成波点，并记入撤销栈。
    @MainActor
    private func drawPuzzleDots() {
        guard canvasImage != nil else {
            showToast("请先上传图片")
            return
        }

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
    private func syncPuzzleDots(to count: Int) {
        guard canvasImage != nil else { return }

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
        tracePoints = points
        dismissToast()
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func clearTracePoints() {
        guard !tracePoints.isEmpty else { return }

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

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            puzzleDots = canvasHistory.clearValue()
        }
        dismissToast()
    }

    @MainActor
    private func undoCanvasChange() {
        guard let previousDots = canvasHistory.undo() else { return }

        puzzleDots = previousDots
        dismissToast()
    }

    @MainActor
    private func redoCanvasChange() {
        guard let nextDots = canvasHistory.redo() else { return }

        puzzleDots = nextDots
        dismissToast()
    }

    @MainActor
    private func applyPuzzleDots(_ dots: [PuzzleDot]) {
        canvasHistory.record(dots)
        puzzleDots = canvasHistory.currentValue
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

            let exportSize = exportCanvasSize(for: snapshot.image)
            let exportFormat = snapshot.exportFormat

            let product: CanvasExportProduct? = await Task.detached(priority: .userInitiated) {
                switch exportFormat {
                case .livePhoto:
                    let liveSnapshot = CanvasLivePhotoExporter.Snapshot(
                        image: snapshot.image,
                        extensionRatio: snapshot.extensionRatio,
                        extensionSide: snapshot.extensionSide,
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
    private func exportCanvasSize(for image: UIImage) -> CGSize {
        let sourceWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let sourceHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        let clampedRatio = min(max(extensionRatio, 0), 1)

        switch extensionSide {
        case .left, .right:
            return CGSize(
                width: sourceWidth * (1 + clampedRatio),
                height: sourceHeight
            )
        case .top, .bottom:
            return CGSize(
                width: sourceWidth,
                height: sourceHeight * (1 + clampedRatio)
            )
        }
    }

    private func canvasGesture(availableSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .updating($gestureOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    viewportOffset = viewportOffset + value.translation
                },
            MagnifyGesture()
                .onChanged { value in
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
        )
    }

    @MainActor
    private func cleanupCurrentExportSession() {
        guard var exportSession else { return }

        exportSession.cleanupNow()
        self.exportSession = nil
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
