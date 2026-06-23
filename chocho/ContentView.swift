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
    @State private var hasEnteredHome = ContentViewPreviewBootstrap.isEnabled
    @State private var shouldAutoAdvanceHome = true
    @State private var selectedTab: PanelTab = .dots
    @State private var isRecentPhotoPickerPresented = false
    @State private var didAutoPresentPhotoPicker = ContentViewPreviewBootstrap.isEnabled
    @State private var canvasImage: UIImage? = ContentViewPreviewBootstrap.initialCanvasImage
    @State private var extensionRatio: CGFloat = PuzzleCanvasDefaults.defaultExtensionRatio
    @State private var extensionSide: PuzzleCanvasExtensionSide = .right
    @State private var backgroundStyle: PuzzleBackgroundStyle = .grid
    @State private var backgroundColors = PuzzleBackgroundColors.default
    @State private var backgroundPatternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue
    @State private var imageViewportResetID = UUID()
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset: CGSize = .zero
    @State private var isPanelExpanded = false
    @State private var panelResetID = UUID()
    @State private var panelVisibleHeight: CGFloat = 0
    @State private var dotCount: Double = 10
    @State private var dotScale: Double = DotSizeControl.defaultRenderedScale
    @State private var selectedDotColor: Color = .clear
    @State private var usesRandomDotColors = false
    @State private var randomDrawClickCount = 0
    @State private var selectedDotShape: DotShapeAsset = .defaultSelection
    @State private var selectedDotShapeCategory: DotShapeCategory = .basic
    @State private var dotCharacterText = CharacterDotText.defaultText
    @State private var isTraceDrawingEnabled = false
    @State private var isTraceVisible = true
    @State private var isSubjectOutlineEnabled = false
    @State private var subjectOutlinePoints: [PuzzleCanvasTracePoint] = []
    @State private var traceFeatureSessionSnapshot: TraceFeatureSessionSnapshot?
    @State private var photoCompression: MainPhotoCompression = .none
    @State private var photoCompressionSessionSnapshot: MainPhotoCompression?
    @State private var y2kCCDFilterSettings: Y2KCCDFilterSettings = .default
    @State private var y2kCCDFilterSessionSnapshot: Y2KCCDFilterSettings?
    @State private var y2kCCDFilterCache = Y2KCCDFilterCache()
    @State private var asciiArtSettings: ASCIIArtSettings = .default
    @State private var asciiArtSessionSnapshot: ASCIIArtSettings?
    @State private var asciiArtCache = ASCIIArtCache()
    @State private var filteredCanvasPreviewImage: UIImage?
    @State private var filteredCanvasPreviewKey: String?
    @State private var filteredCanvasPreviewTask: Task<Void, Never>?
    @State private var isDetectingSubjectOutline = false
    @State private var subjectOutlineGenerationID = UUID()

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
    @State private var puzzleDots: [PuzzleDot] = ContentViewPreviewBootstrap.initialPuzzleDots
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
    @State private var hasAttemptedDraftRestore = ContentViewPreviewBootstrap.isEnabled
    @State private var pendingDraftSave: Task<Void, Never>?
    @State private var pendingTraceDotSyncTask: Task<Void, Never>?

    private static let traceDotSyncDebounceInterval: Duration = .milliseconds(300)

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
                        canUndo: canvasHistory.canUndo,
                        canRedo: canvasHistory.canRedo,
                        canClearCanvas: !puzzleDots.isEmpty,
                        onBack: presentRecentPhotoPicker,
                        onDownload: shareCanvas,
                        onClearCanvas: presentClearCanvasConfirmation,
                        onUndo: undoCanvasChange,
                        onRedo: redoCanvasChange
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
                guard !ContentViewPreviewBootstrap.isEnabled else {
                    hasAttemptedDraftRestore = true
                    return
                }
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
                guard !ContentViewPreviewBootstrap.isEnabled else { return }
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
        applyMotionDraftSaveObservers(
            to: content
            .onChange(of: extensionRatio) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: extensionSide) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundStyle) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundColors) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: backgroundPatternSpacing) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: dotScale) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: selectedDotColor) { _, _ in
                usesRandomDotColors = false
                scheduleCanvasDraftSave()
            }
            .onChange(of: usesRandomDotColors) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: selectedDotShape) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: dotCharacterText) { _, _ in scheduleCanvasDraftSave() }
            .onChange(of: isTraceDrawingEnabled) { _, isEnabled in
                if isEnabled, isDotEditingEnabled {
                    withoutAnimation {
                        isDotEditingEnabled = false
                        selectedDotID = nil
                    }
                }
                scheduleCanvasDraftSave()
            }
            .onChange(of: isTraceVisible) { _, _ in
                scheduleCanvasDraftSave()
            }
            .onChange(of: photoCompression) { _, _ in
                refreshStyledPreviewImageIfNeeded(debounces: true)
                scheduleCanvasDraftSave()
            }
        )
    }

    @ViewBuilder
    private func applyMotionDraftSaveObservers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: y2kCCDFilterSettings) { _, newSettings in
                refreshStyledPreviewImageIfNeeded(debounces: true)
                if newSettings.enabled {
                    isSourceLiveMotionEnabled = false
                    stopLivePreviewPlayback()
                }
                scheduleCanvasDraftSave()
            }
            .onChange(of: asciiArtSettings) { _, newSettings in
                refreshStyledPreviewImageIfNeeded(debounces: true)
                if newSettings.enabled {
                    isSourceLiveMotionEnabled = false
                    stopLivePreviewPlayback()
                }
                scheduleCanvasDraftSave()
            }
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
                selectedDotShape: selectedDotShapeBinding,
                selectedDotShapeCategory: $selectedDotShapeCategory,
                dotCharacterText: $dotCharacterText,
                isTraceVisible: $isTraceVisible,
                isSubjectOutlineEnabled: $isSubjectOutlineEnabled,
                photoCompression: $photoCompression,
                y2kCCDFilterSettings: $y2kCCDFilterSettings,
                asciiArtSettings: $asciiArtSettings,
                isDetectingSubjectOutline: isDetectingSubjectOutline
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
            canClearTrace: hasClearableTrace,
            onDrawDots: drawPuzzleDots,
            onToggleSubjectOutline: toggleSubjectOutline,
            onClearTrace: clearTracePoints,
            onBeginTraceFeature: beginTraceFeatureSession,
            onConfirmTraceFeature: confirmTraceFeatureSession,
            onCancelTraceFeature: cancelTraceFeatureSession,
            onBeginPhotoCompressionFeature: beginPhotoCompressionFeatureSession,
            onConfirmPhotoCompressionFeature: confirmPhotoCompressionFeatureSession,
            onCancelPhotoCompressionFeature: cancelPhotoCompressionFeatureSession,
            onBeginY2KCCDFilterFeature: beginY2KCCDFilterFeatureSession,
            onConfirmY2KCCDFilterFeature: confirmY2KCCDFilterFeatureSession,
            onCancelY2KCCDFilterFeature: cancelY2KCCDFilterFeatureSession,
            onBeginASCIIArtFeature: beginASCIIArtFeatureSession,
            onConfirmASCIIArtFeature: confirmASCIIArtFeatureSession,
            onCancelASCIIArtFeature: cancelASCIIArtFeatureSession
        )
        .id(panelResetID)
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
                let previewImage = filteredCanvasPreviewImage ?? canvasImage
                let canvas = PuzzleCanvasView(
                    image: previewImage,
                    layoutImageSize: CanvasImageLoader.pixelSize(for: canvasImage),
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
                    subjectOutlinePoints: subjectOutlinePoints,
                    isTraceDrawingEnabled: isTraceDrawingEnabled,
                    isTraceVisible: isTraceVisible,
                    isSubjectOutlineEnabled: isSubjectOutlineEnabled,
                    liveDotAnimation: liveDotAnimation,
                    livePreviewPlaybackStart: livePreviewPlaybackStart,
                    isStyledPhotoPreviewEnabled: CanvasStyledPhotoRenderer.styledPreviewEnabled(
                        y2kCCDFilterSettings: y2kCCDFilterSettings,
                        asciiArtSettings: asciiArtSettings
                    ),
                    isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
                    sourceLiveVideo: sourceLiveVideo,
                    isDotEditingEnabled: isDotEditingEnabled,
                    selectedDotID: selectedDotID,
                    onTapCanvas: addPuzzleDot(at:),
                    onPanViewport: panCanvasViewport(by:),
                    onDoubleTapBackground: applyCanvasViewportReset,
                    onViewportReset: applyCanvasViewportResetWithoutAnimation,
                    onTraceChanged: updateTracePoints,
                    onTraceStrokeEnded: commitTraceStrokeDots,
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

    @MainActor
    private func invalidateStyledPreviewImage() {
        filteredCanvasPreviewTask?.cancel()
        filteredCanvasPreviewTask = nil
        filteredCanvasPreviewImage = nil
        filteredCanvasPreviewKey = nil
        y2kCCDFilterCache.clear()
        asciiArtCache.clear()
    }

    @MainActor
    private func refreshStyledPreviewImageIfNeeded(debounces: Bool = false) {
        filteredCanvasPreviewTask?.cancel()
        filteredCanvasPreviewTask = nil

        guard CanvasStyledPhotoRenderer.styledPreviewEnabled(
            y2kCCDFilterSettings: y2kCCDFilterSettings,
            asciiArtSettings: asciiArtSettings
        ), let canvasImage else {
            filteredCanvasPreviewImage = nil
            filteredCanvasPreviewKey = nil
            return
        }

        let sourceKey = "preview-\(ASCIIArtRenderer.sourceKey(for: canvasImage))"
        let pixelSize = styledPreviewPixelSize(for: canvasImage)
        let cacheKey = [
            sourceKey,
            "\(Int(pixelSize.width.rounded()))x\(Int(pixelSize.height.rounded()))",
            y2kCCDFilterSettings.cacheKey,
            asciiArtSettings.cacheKey,
            photoCompression.rawValue
        ].joined(separator: "|")

        guard filteredCanvasPreviewKey != cacheKey || filteredCanvasPreviewImage == nil else {
            return
        }

        filteredCanvasPreviewKey = cacheKey

        let ccdSettings = y2kCCDFilterSettings
        let asciiSettings = asciiArtSettings
        let compression = photoCompression
        let ccdCache = y2kCCDFilterCache
        let asciiCache = asciiArtCache
        filteredCanvasPreviewTask = Task {
            if debounces {
                try? await Task.sleep(for: Y2KCCDPreviewRenderPolicy.refreshDebounce)
                guard !Task.isCancelled else { return }
            }

            let filteredImage = await CanvasStyledPhotoRenderer.render(
                image: canvasImage,
                y2kCCDFilterSettings: ccdSettings,
                targetPixelSize: pixelSize,
                sourceKey: sourceKey,
                y2kCCDCache: ccdCache,
                asciiArtSettings: asciiSettings,
                asciiArtCache: asciiCache,
                photoCompression: compression
            )

            guard !Task.isCancelled, filteredCanvasPreviewKey == cacheKey else { return }
            filteredCanvasPreviewImage = filteredImage
        }
    }

    private func styledPreviewPixelSize(for image: UIImage) -> CGSize {
        let pixelSize = CanvasImageLoader.pixelSize(for: image)
        let ccdSize = Y2KCCDPreviewRenderPolicy.pixelSize(for: pixelSize)
        return ASCIIArtPreviewRenderPolicy.pixelSize(for: ccdSize)
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
        pendingTraceDotSyncTask?.cancel()
        pendingTraceDotSyncTask = nil
        stopLivePreviewPlayback()

        traceFeatureSessionSnapshot = nil
        photoCompressionSessionSnapshot = nil
        y2kCCDFilterSessionSnapshot = nil
        asciiArtSessionSnapshot = nil

        selectedTab = .dots
        isPanelExpanded = false
        panelResetID = UUID()

        dotCount = 10
        selectedDotShape = DotShapeAsset(name: PuzzleCanvasUploadDefaults.dotShapeName)
        selectedDotShapeCategory = .pixel
        dotScale = PuzzleCanvasUploadDefaults.dotScale
        selectedDotColor = .clear
        dotCharacterText = CharacterDotText.defaultText

        isTraceDrawingEnabled = false
        isTraceVisible = true
        photoCompression = .none
        y2kCCDFilterSettings = .default
        asciiArtSettings = .default

        extensionRatio = PuzzleCanvasDefaults.defaultExtensionRatio
        extensionSide = .right
        backgroundStyle = .grid
        backgroundColors = PuzzleBackgroundColors.default
        backgroundPatternSpacing = PuzzleBackgroundPatternSpacing.defaultControlValue

        liveDotAnimation = .none
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
        invalidateSubjectOutlineDetection()
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
        invalidateStyledPreviewImage()
        refreshStyledPreviewImageIfNeeded()
        imageViewportResetID = UUID()
        viewportScale = 1
        viewportOffset = .zero
        lastMagnification = 1
        isDotEditingEnabled = false
        selectedDotID = nil
        tracePoints = []
        disableSubjectOutline()
        canvasHistory.reset(to: [])
        puzzleDots = []
        randomDrawClickCount = 0
        usesRandomDotColors = false

        await Task.yield()

        applyPuzzleDots(initialDots)
    }

    private var hasClearableTrace: Bool {
        !tracePoints.isEmpty || !subjectOutlinePoints.isEmpty
    }

    private var activeTracePoints: [PuzzleCanvasTracePoint] {
        combinedTracePoints(
            subjectOutline: isSubjectOutlineEnabled ? subjectOutlinePoints : [],
            manualTrace: tracePoints
        )
    }

    private func combinedTracePoints(
        subjectOutline: [PuzzleCanvasTracePoint],
        manualTrace: [PuzzleCanvasTracePoint]
    ) -> [PuzzleCanvasTracePoint] {
        guard !subjectOutline.isEmpty else { return manualTrace }
        guard !manualTrace.isEmpty else { return subjectOutline }

        var manualWithSeparatedStroke = manualTrace
        if let firstPoint = manualWithSeparatedStroke.first, !firstPoint.startsNewStroke {
            manualWithSeparatedStroke[0] = PuzzleCanvasTracePoint(
                side: firstPoint.side,
                point: firstPoint.point,
                startsNewStroke: true
            )
        }

        return subjectOutline + manualWithSeparatedStroke
    }

    /// 「抽卡」：沿轨迹或随机布局生成波点，并记入撤销栈。每点满 3 次「随机一下」生成一次随机色彩波点。
    @MainActor
    private func drawPuzzleDots() {
        guard canvasImage != nil else {
            showToast("请先上传图片")
            return
        }

        randomDrawClickCount += 1
        usesRandomDotColors = randomDrawClickCount.isMultiple(of: 3)

        invalidateSubjectOutlineDetection()

        if isTraceDrawingEnabled {
            guard !activeTracePoints.isEmpty else {
                showToast("先画一条轨迹")
                return
            }

            guard let newDots = puzzleDotsAlongCurrentTrace(), !newDots.isEmpty else {
                showToast("右侧背景太窄")
                return
            }

            applyPuzzleDots(newDots)
            dismissToast()
            return
        }

        let fallbackDots = PuzzleDotFactory.makeDots(
            count: Int(dotCount.rounded()),
            shapeAssetName: selectedDotShape.name
        )
        applyPuzzleDots(fallbackDots)
        dismissToast()
    }

    @MainActor
    private func toggleSubjectOutline() {
        guard canvasImage != nil else {
            showToast("请先上传图片")
            return
        }

        if isSubjectOutlineEnabled {
            invalidateSubjectOutlineDetection()
            disableSubjectOutline()
            if isTraceDrawingEnabled {
                scheduleTraceDotPreviewSync()
            }
            return
        }

        guard !isDetectingSubjectOutline else { return }

        isSubjectOutlineEnabled = true
        detectSubjectOutline()
    }

    @MainActor
    private func detectSubjectOutline() {
        guard let canvasImage else {
            disableSubjectOutline()
            showToast("请先上传图片")
            return
        }
        guard !isDetectingSubjectOutline else { return }

        let generationID = UUID()
        subjectOutlineGenerationID = generationID
        isDetectingSubjectOutline = true
        showToast("正在识别主体…")

        Task {
            do {
                let outlinePoints = try await SubjectContourDotGenerator().outlineTracePoints(for: canvasImage)
                await MainActor.run {
                    guard subjectOutlineGenerationID == generationID, isSubjectOutlineEnabled else { return }
                    subjectOutlinePoints = outlinePoints
                    isDetectingSubjectOutline = false
                    dismissToast()
                    if isTraceDrawingEnabled {
                        scheduleTraceDotPreviewSync()
                    }
                }
            } catch {
                await MainActor.run {
                    guard subjectOutlineGenerationID == generationID, isSubjectOutlineEnabled else { return }
                    disableSubjectOutline()
                    isDetectingSubjectOutline = false
                    showToast(subjectOutlineErrorMessage(for: error))
                }
            }
        }
    }

    @MainActor
    private func disableSubjectOutline() {
        isSubjectOutlineEnabled = false
        subjectOutlinePoints = []
    }

    private func subjectOutlineErrorMessage(for error: Error) -> String {
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

        invalidateSubjectOutlineDetection()

        let syncedDots: [PuzzleDot]
        if isTraceDrawingEnabled, !activeTracePoints.isEmpty {
            syncedDots = puzzleDotsAlongCurrentTrace(count: count) ?? []
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
        invalidateSubjectOutlineDetection()

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
        invalidateSubjectOutlineDetection()
        tracePoints = points
        dismissToast()
        scheduleCanvasDraftSave()

        if isTraceDrawingEnabled {
            scheduleTraceDotPreviewSync()
        }
    }

    @MainActor
    private func puzzleDotsAlongCurrentTrace(count: Int? = nil) -> [PuzzleDot]? {
        guard !activeTracePoints.isEmpty else { return nil }

        let resolvedCount = count ?? Int(dotCount.rounded())
        let dots = PuzzleDotFactory.makeDots(
            count: resolvedCount,
            along: activeTracePoints,
            extensionRatio: extensionRatio,
            shapeAssetName: selectedDotShape.name
        )
        return dots.isEmpty ? nil : dots
    }

    @MainActor
    private func scheduleTraceDotPreviewSync() {
        pendingTraceDotSyncTask?.cancel()
        pendingTraceDotSyncTask = Task {
            try? await Task.sleep(for: Self.traceDotSyncDebounceInterval)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                previewPuzzleDotsFromCurrentTrace()
            }
        }
    }

    @MainActor
    private func previewPuzzleDotsFromCurrentTrace() {
        guard canvasImage != nil, isTraceDrawingEnabled else { return }
        guard let syncedDots = puzzleDotsAlongCurrentTrace() else { return }

        puzzleDots = syncedDots
        if let selectedDotID, !syncedDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func commitTraceStrokeDots() {
        pendingTraceDotSyncTask?.cancel()
        pendingTraceDotSyncTask = nil

        guard canvasImage != nil, isTraceDrawingEnabled, !activeTracePoints.isEmpty else { return }
        guard let syncedDots = puzzleDotsAlongCurrentTrace() else { return }

        applyPuzzleDots(syncedDots)
    }

    @MainActor
    private func setDotEditingMode(_ isEnabled: Bool) {
        if isEnabled {
            guard canvasImage != nil else { return }
            guard !isDotEditingEnabled else { return }

            withoutAnimation {
                commitTraceStrokeDots()
                isTraceDrawingEnabled = false
                isDotEditingEnabled = true
                selectedDotID = nil
                selectedTab = .dots
                isPanelExpanded = true
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
    private func beginTraceFeatureSession() {
        guard traceFeatureSessionSnapshot == nil else { return }

        traceFeatureSessionSnapshot = TraceFeatureSessionSnapshot(
            tracePoints: tracePoints,
            subjectOutlinePoints: subjectOutlinePoints,
            isSubjectOutlineEnabled: isSubjectOutlineEnabled,
            puzzleDots: puzzleDots,
            dotCount: dotCount
        )

        if isDotEditingEnabled {
            withoutAnimation {
                isDotEditingEnabled = false
                selectedDotID = nil
            }
        }

        isTraceVisible = true
        isTraceDrawingEnabled = true
    }

    @MainActor
    private func confirmTraceFeatureSession() {
        commitTraceStrokeDots()
        traceFeatureSessionSnapshot = nil
        isTraceVisible = true
        isTraceDrawingEnabled = false
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func cancelTraceFeatureSession() {
        guard let snapshot = traceFeatureSessionSnapshot else { return }

        pendingTraceDotSyncTask?.cancel()
        pendingTraceDotSyncTask = nil
        invalidateSubjectOutlineDetection()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tracePoints = snapshot.tracePoints
            subjectOutlinePoints = snapshot.subjectOutlinePoints
            isSubjectOutlineEnabled = snapshot.isSubjectOutlineEnabled
            puzzleDots = snapshot.puzzleDots
            dotCount = snapshot.dotCount
        }

        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }

        traceFeatureSessionSnapshot = nil
        isTraceVisible = true
        isTraceDrawingEnabled = false
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func beginPhotoCompressionFeatureSession() {
        guard photoCompressionSessionSnapshot == nil else { return }
        photoCompressionSessionSnapshot = photoCompression
    }

    @MainActor
    private func confirmPhotoCompressionFeatureSession() {
        photoCompressionSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func cancelPhotoCompressionFeatureSession() {
        guard let snapshot = photoCompressionSessionSnapshot else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            photoCompression = snapshot
        }

        photoCompressionSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func beginY2KCCDFilterFeatureSession() {
        guard y2kCCDFilterSessionSnapshot == nil else { return }
        y2kCCDFilterSessionSnapshot = y2kCCDFilterSettings
        y2kCCDFilterSettings = y2kCCDFilterSettings.enabledForPanelEditing
    }

    @MainActor
    private func confirmY2KCCDFilterFeatureSession() {
        y2kCCDFilterSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func cancelY2KCCDFilterFeatureSession() {
        guard let snapshot = y2kCCDFilterSessionSnapshot else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            y2kCCDFilterSettings = snapshot
        }

        y2kCCDFilterSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func beginASCIIArtFeatureSession() {
        guard asciiArtSessionSnapshot == nil else { return }
        asciiArtSessionSnapshot = asciiArtSettings
        asciiArtSettings = asciiArtSettings.enabledForPanelEditing
    }

    @MainActor
    private func confirmASCIIArtFeatureSession() {
        asciiArtSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func cancelASCIIArtFeatureSession() {
        guard let snapshot = asciiArtSessionSnapshot else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            asciiArtSettings = snapshot
        }

        asciiArtSessionSnapshot = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func clearTracePoints() {
        guard hasClearableTrace else { return }

        pendingTraceDotSyncTask?.cancel()
        pendingTraceDotSyncTask = nil
        invalidateSubjectOutlineDetection()
        tracePoints = []
        disableSubjectOutline()
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

        invalidateSubjectOutlineDetection()
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

        invalidateSubjectOutlineDetection()
        puzzleDots = previousDots
        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        dismissToast()
    }

    @MainActor
    private func redoCanvasChange() {
        guard let nextDots = canvasHistory.redo() else { return }

        invalidateSubjectOutlineDetection()
        puzzleDots = nextDots
        if let selectedDotID, !puzzleDots.contains(where: { $0.id == selectedDotID }) {
            self.selectedDotID = nil
        }
        dismissToast()
    }

    @MainActor
    private func invalidateSubjectOutlineDetection() {
        subjectOutlineGenerationID = UUID()
        if isDetectingSubjectOutline {
            isDetectingSubjectOutline = false
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
        y2kCCDFilterSettings = restored.y2kCCDFilterSettings
        asciiArtSettings = restored.asciiArtSettings
        invalidateStyledPreviewImage()
        refreshStyledPreviewImageIfNeeded()
        liveDotAnimation = restored.liveDotAnimation
        isSourceLiveMotionEnabled = restored.isSourceLiveMotionEnabled
        if y2kCCDFilterSettings.enabled || asciiArtSettings.enabled {
            isSourceLiveMotionEnabled = false
        }
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
        guard !ContentViewPreviewBootstrap.isEnabled else { return }

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
            y2kCCDFilterSettings: y2kCCDFilterSettings,
            asciiArtSettings: asciiArtSettings,
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
            y2kCCDFilterSettings: y2kCCDFilterSettings,
            asciiArtSettings: asciiArtSettings,
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
                        y2kCCDFilterSettings: snapshot.y2kCCDFilterSettings,
                        asciiArtSettings: snapshot.asciiArtSettings,
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
                    let needsMask = snapshot.asciiArtSettings.enabled
                    let asciiArtMask: SubjectMask? = needsMask
                        ? try? await VisionSubjectMaskProvider().subjectMask(for: snapshot.image)
                        : nil

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
                        dotCharacterText: snapshot.dotCharacterText,
                        y2kCCDFilterSettings: snapshot.y2kCCDFilterSettings,
                        asciiArtSettings: snapshot.asciiArtSettings,
                        asciiArtMask: asciiArtMask
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

private struct TraceFeatureSessionSnapshot {
    let tracePoints: [PuzzleCanvasTracePoint]
    let subjectOutlinePoints: [PuzzleCanvasTracePoint]
    let isSubjectOutlineEnabled: Bool
    let puzzleDots: [PuzzleDot]
    let dotCount: Double
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

private enum ContentViewPreviewBootstrap {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var initialCanvasImage: UIImage? {
        isEnabled ? makeSampleImage() : nil
    }

    static var initialPuzzleDots: [PuzzleDot] {
        isEnabled ? PuzzleDotFactory.makeDots(count: 10) : []
    }

    static func makeSampleImage() -> UIImage {
        let size = CGSize(width: 320, height: 220)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.55, green: 0.35, blue: 0.22, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

#Preview("App") {
    ContentView()
}
