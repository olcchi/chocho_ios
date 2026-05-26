//
//  ContentView.swift
//  chocho
//
//  Created by Ekar on 2026/5/22.
//

import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: PanelTab = .dots
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var canvasImage: UIImage?
    @State private var extensionRatio: CGFloat = 0.2
    @State private var extensionSide: PuzzleCanvasExtensionSide = .right
    @State private var backgroundStyle: PuzzleBackgroundStyle = .grid
    @State private var backgroundColors = PuzzleBackgroundColors.default
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
    @State private var isTraceDrawingEnabled = false
    @State private var tracePoints: [PuzzleCanvasTracePoint] = []
    @State private var puzzleDots: [PuzzleDot] = []
    @State private var canvasHistory = CanvasHistory<[PuzzleDot]>(initialValue: [])
    @State private var showsClearCanvasConfirmation = false
    @State private var exportMessage: String?
    @State private var isPhotoLoading = false
    @State private var isExporting = false
    @State private var shareItem: CanvasShareItem?
    @State private var shareSheetDetent: PresentationDetent = .medium
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    @State private var hasAttemptedDraftRestore = false
    @State private var pendingDraftSave: Task<Void, Never>?

    var body: some View {
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
                        exportMessage: exportMessage,
                        canDownload: canvasImage != nil,
                        isBusy: isPhotoLoading || isExporting,
                        onDownload: shareCanvas
                    )
                    .padding(.top, 4)
                    .padding(.trailing, BottomSheetPanel.contentHorizontalInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                BottomSheetPanel(
                    panelVisibleHeight: $panelVisibleHeight,
                    selectedTab: $selectedTab,
                    isExpanded: $isPanelExpanded,
                    dotCount: $dotCount,
                    dotScale: $dotScale,
                    selectedDotColor: $selectedDotColor,
                    usesRandomDotColors: $usesRandomDotColors,
                    selectedDotShape: $selectedDotShape,
                    isTraceDrawingEnabled: $isTraceDrawingEnabled,
                    extensionRatio: $extensionRatio,
                    extensionSide: $extensionSide,
                    backgroundStyle: $backgroundStyle,
                    backgroundColors: $backgroundColors,
                    bottomSafeAreaInset: proxy.safeAreaInsets.bottom,
                    isPanelEnabled: canvasImage != nil,
                    onDrawDots: drawPuzzleDots
                )
                .overlay(alignment: .topTrailing) {
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
                .padding(.bottom, -proxy.safeAreaInsets.bottom)
            }
            .background {
                Color.background
                    .ignoresSafeArea()
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .task {
            guard !hasAttemptedDraftRestore else { return }
            hasAttemptedDraftRestore = true
            await restoreCanvasDraftIfNeeded()
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
        .onChange(of: extensionRatio) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: extensionSide) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: backgroundStyle) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: backgroundColors) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: dotScale) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: selectedDotColor) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: usesRandomDotColors) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: selectedDotShape) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: isTraceDrawingEnabled) { _, _ in scheduleCanvasDraftSave() }
        .onChange(of: dotCount) { _, newDotCount in
            syncPuzzleDots(to: Int(newDotCount.rounded()))
        }
        .sheet(item: $shareItem) { item in
            CanvasShareSheet(fileURL: item.fileURL)
                .presentationDetents([.medium, .large], selection: $shareSheetDetent)
                .presentationDragIndicator(.visible)
                .onAppear {
                    shareSheetDetent = .medium
                }
        }
        .alert("打扫波点", isPresented: $showsClearCanvasConfirmation) {
            Button("取消", role: .cancel) {}
            Button("打扫", role: .destructive, action: clearCanvasContent)
        } message: {
            Text("你想要把画布上的波点都打扫掉吗？")
        }
    }

    private var bottomPanelInset: CGFloat {
        BottomSheetPanel.bottomPanelInset(
            isExpanded: isPanelExpanded,
            panelVisibleHeight: panelVisibleHeight
        )
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
                    imageViewportResetID: imageViewportResetID,
                    bottomPanelInset: bottomPanelInset,
                    dots: puzzleDots,
                    dotScale: CGFloat(dotScale),
                    dotColor: selectedDotColor,
                    usesRandomDotColors: usesRandomDotColors,
                    viewportScale: viewportScale,
                    viewportOffset: viewportOffset,
                    gestureOffset: gestureOffset,
                    tracePoints: tracePoints,
                    isTraceDrawingEnabled: isTraceDrawingEnabled,
                    onTapCanvas: addPuzzleDot(at:),
                    onDoubleTapBackground: applyCanvasViewportReset,
                    onViewportReset: applyCanvasViewportReset,
                    onTraceChanged: updateTracePoints
                )

                if isTraceDrawingEnabled {
                    canvas
                } else {
                    canvas.gesture(canvasGesture(availableSize: canvasProxy.size))
                }
            }
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: CanvasPhotoImport.pickerMatching) {
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

    
    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        isPhotoLoading = true
        exportMessage = "正在加载…"
        defer {
            isPhotoLoading = false
        }

        do {
            let importResult = try await CanvasPhotoImport.importPhoto(from: selectedPhotoItem)
            let image = importResult.source.keyPhoto

            let initialDots = PuzzleCanvasUploadDefaults.initialDots(
                dotCount: dotCount,
                shapeAssetName: selectedDotShape.name
            )

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
            exportMessage = nil
            persistCanvasDraft()
        } catch {
            exportMessage = "上传失败"
        }
    }

    @MainActor
    private func drawPuzzleDots() {
        guard canvasImage != nil else {
            exportMessage = "请先上传图片"
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
                exportMessage = "先画一条轨迹"
                return
            }

            guard !newDots.isEmpty else {
                exportMessage = "右侧背景太窄"
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
        exportMessage = nil
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
        exportMessage = nil
    }

    @MainActor
    private func updateTracePoints(_ points: [PuzzleCanvasTracePoint]) {
        tracePoints = points
        exportMessage = nil
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
        exportMessage = nil
    }

    @MainActor
    private func undoCanvasChange() {
        guard let previousDots = canvasHistory.undo() else { return }
	
        puzzleDots = previousDots
        exportMessage = nil
    }

    @MainActor
    private func redoCanvasChange() {
        guard let nextDots = canvasHistory.redo() else { return }

        puzzleDots = nextDots
        exportMessage = nil
    }

    @MainActor
    private func applyPuzzleDots(_ dots: [PuzzleDot]) {
        canvasHistory.record(dots)
        puzzleDots = canvasHistory.currentValue
        exportMessage = nil
        scheduleCanvasDraftSave()
    }

    @MainActor
    private func restoreCanvasDraftIfNeeded() async {
        guard canvasImage == nil else { return }

        guard let restored = await CanvasDraftStore.load() else { return }

        canvasImage = restored.image
        extensionRatio = restored.extensionRatio
        extensionSide = restored.extensionSide
        backgroundStyle = restored.backgroundStyle
        backgroundColors = restored.backgroundColors
        dotCount = restored.dotCount
        dotScale = restored.dotScale
        selectedDotColor = restored.selectedDotColor
        usesRandomDotColors = restored.usesRandomDotColors
        selectedDotShape = DotShapeAsset.asset(named: restored.selectedDotShapeName)
            ?? .defaultSelection
        isTraceDrawingEnabled = restored.isTraceDrawingEnabled
        tracePoints = restored.tracePoints
        viewportScale = restored.viewportScale
        viewportOffset = restored.viewportOffset
        lastMagnification = 1
        imageViewportResetID = UUID()
        canvasHistory.reset(to: restored.puzzleDots)
        puzzleDots = restored.puzzleDots
        exportMessage = nil
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
            dotCount: dotCount,
            dotScale: dotScale,
            selectedDotColor: selectedDotColor,
            usesRandomDotColors: usesRandomDotColors,
            selectedDotShapeName: selectedDotShape.name,
            isTraceDrawingEnabled: isTraceDrawingEnabled,
            puzzleDots: puzzleDots,
            tracePoints: tracePoints,
            viewportScale: viewportScale,
            viewportOffset: viewportOffset
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
    private func shareCanvas() {
        guard let canvasImage else {
            exportMessage = "请先上传图片"
            return
        }

        guard !isExporting else { return }

        isExporting = true
        exportMessage = "正在导出…"

        let snapshot = CanvasExportSnapshot(
            image: canvasImage,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            dots: puzzleDots,
            dotScale: CGFloat(dotScale),
            dotColor: selectedDotColor,
            usesRandomDotColors: usesRandomDotColors
        )

        Task {
            defer { isExporting = false }

            let exportSize = exportCanvasSize(for: snapshot.image)
            let renderedImage = await Task.detached(priority: .userInitiated) {
                CanvasRasterExporter.render(
                    image: snapshot.image,
                    exportSize: exportSize,
                    extensionRatio: snapshot.extensionRatio,
                    extensionSide: snapshot.extensionSide,
                    backgroundStyle: snapshot.backgroundStyle,
                    backgroundColors: snapshot.backgroundColors,
                    dots: snapshot.dots,
                    dotScale: snapshot.dotScale,
                    dotColor: snapshot.dotColor,
                    usesRandomDotColors: snapshot.usesRandomDotColors
                )
            }.value

            guard let renderedImage else {
                exportMessage = "生成失败"
                return
            }

            let fileURL = await Task.detached(priority: .utility) {
                CanvasExportWriter.writeTemporaryJPEG(renderedImage)
            }.value

            guard let fileURL else {
                exportMessage = "导出失败"
                return
            }

            exportMessage = nil
            shareItem = CanvasShareItem(fileURL: fileURL)
        }
    }

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
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

private struct CanvasShareItem: Identifiable {
    let id = UUID()
    let fileURL: URL
}

private struct CanvasUploadPlaceholder: View {
    var body: some View {
        VStack(spacing: 5) {
            Image("public/image-upload")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .padding(.bottom, 5)

            Text("先选张图片吧 :P")
            Text("右侧会生成贴边画布")
            Text("抽一张后会撒上波点")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.appAccent)
        .multilineTextAlignment(.center)
        .frame(width: 308, height: 220)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
        }
    }
}

private struct CanvasShareSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: [SaveCanvasToPhotosActivity(fileURL: fileURL)]
        )
        controller.modalPresentationStyle = .pageSheet
        configureSheetPresentation(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        configureSheetPresentation(for: uiViewController)
    }

    private func configureSheetPresentation(for controller: UIActivityViewController) {
        guard let sheet = controller.sheetPresentationController else { return }
        sheet.detents = [.medium(), .large()]
        sheet.selectedDetentIdentifier = .medium
        sheet.prefersGrabberVisible = true
    }
}

private final class SaveCanvasToPhotosActivity: UIActivity {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }

    override var activityTitle: String? {
        "保存到相册"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "square.and.arrow.down")
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("olcchi.chocho.saveCanvasToPhotos")
    }

    override class var activityCategory: UIActivity.Category {
        .action
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func perform() {
        Task { @MainActor in
            let didSave = await CanvasPhotoLibrarySaver.save(fileURL: fileURL)
            activityDidFinish(didSave)
        }
    }
}

private struct CanvasExportSnapshot {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let dots: [PuzzleDot]
    let dotScale: CGFloat
    let dotColor: Color
    let usesRandomDotColors: Bool
}
