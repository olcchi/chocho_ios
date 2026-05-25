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
    @State private var selectedTab: PanelTab = .dots
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var canvasImage: UIImage?
    @State private var extensionRatio: CGFloat = 0.2
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset: CGSize = .zero
    @State private var isPanelExpanded = true
    @State private var dotCount: Double = 10
    @State private var dotScale: Double = DotSizeControl.defaultRenderedScale
    @State private var selectedDotColor: Color = .primary
    @State private var usesRandomDotColors = false
    @State private var selectedDotShape: DotShapeAsset = .defaultSelection
    @State private var isTraceDrawingEnabled = false
    @State private var tracePoints: [PuzzleCanvasTracePoint] = []
    @State private var puzzleDots: [PuzzleDot] = []
    @State private var canvasHistory = CanvasHistory<[PuzzleDot]>(initialValue: [])
    @State private var showsClearCanvasConfirmation = false
    @State private var exportMessage: String?
    @State private var shareItem: CanvasShareItem?
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.background
                    .ignoresSafeArea()

                panelBackgroundColor
                    .ignoresSafeArea(edges: .top)
                    .frame(height: topActionBarHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                canvasArea
                .padding(.top, topCanvasInset(for: proxy))
                .padding(.bottom, BottomSheetPanel.visibleHeight(isExpanded: isPanelExpanded))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.smooth(duration: 0.24), value: isPanelExpanded)

                CanvasHeader(
                    selectedPhotoItem: $selectedPhotoItem,
                    exportMessage: exportMessage,
                    canDownload: canvasImage != nil,
                    onDownload: shareCanvas
                )
                .padding(.top, 4)
                .padding(.trailing, 25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(1)

                BottomSheetPanel(
                    selectedTab: $selectedTab,
                    isExpanded: $isPanelExpanded,
                    dotCount: $dotCount,
                    dotScale: $dotScale,
                    selectedDotColor: $selectedDotColor,
                    usesRandomDotColors: $usesRandomDotColors,
                    selectedDotShape: $selectedDotShape,
                    isTraceDrawingEnabled: $isTraceDrawingEnabled,
                    bottomSafeAreaInset: proxy.safeAreaInsets.bottom,
                    onDrawDots: drawPuzzleDots
                )
                    .padding(.bottom, -proxy.safeAreaInsets.bottom)

                CanvasHistoryControls(
                    canUndo: canvasHistory.canUndo,
                    canRedo: canvasHistory.canRedo,
                    canClear: !puzzleDots.isEmpty,
                    onClear: presentClearCanvasConfirmation,
                    onUndo: undoCanvasChange,
                    onRedo: redoCanvasChange
                )
                .padding(.trailing, 20)
                .padding(.bottom, historyControlsBottomPadding(for: proxy))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .zIndex(2)
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .onChange(of: dotCount) { _, newDotCount in
            syncPuzzleDots(to: Int(newDotCount.rounded()))
        }
        .sheet(item: $shareItem) { item in
            CanvasShareSheet(fileURL: item.fileURL)
                .ignoresSafeArea()
        }
        .alert("打扫波点", isPresented: $showsClearCanvasConfirmation) {
            Button("取消", role: .cancel) {}
            Button("打扫", role: .destructive, action: clearCanvasContent)
        } message: {
            Text("你想要把画布上的波点都打扫掉吗？")
        }
    }

    @ViewBuilder
    private var canvasArea: some View {
        if let canvasImage {
            let canvas = PuzzleCanvasView(
                image: canvasImage,
                extensionRatio: extensionRatio,
                dots: puzzleDots,
                dotScale: CGFloat(dotScale),
                dotColor: selectedDotColor,
                usesRandomDotColors: usesRandomDotColors,
                viewportScale: viewportScale * gestureScale,
                viewportOffset: viewportOffset + gestureOffset,
                tracePoints: tracePoints,
                isTraceDrawingEnabled: isTraceDrawingEnabled,
                onTapCanvas: addPuzzleDot(at:),
                onDoubleTapBackground: resetCanvasViewport,
                onTraceChanged: updateTracePoints
            )

            if isTraceDrawingEnabled {
                canvas
            } else {
                canvas.gesture(canvasGesture)
            }
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                CanvasUploadPlaceholder()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

    private func historyControlsBottomPadding(for proxy: GeometryProxy) -> CGFloat {
        BottomSheetPanel.visibleHeight(isExpanded: isPanelExpanded) + 10
    }
    
    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                exportMessage = "无法读取照片"
                return
            }

            canvasImage = image
            puzzleDots = []
            canvasHistory.reset(to: [])
            tracePoints = []
            viewportScale = 1
            viewportOffset = .zero
            applyPuzzleDots(PuzzleCanvasUploadDefaults.initialDots(
                dotCount: dotCount,
                shapeAssetName: selectedDotShape.name
            ))
            exportMessage = nil
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
    private func addPuzzleDot(at position: CGPoint) {
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
    }

    @MainActor
    private func presentClearCanvasConfirmation() {
        guard !puzzleDots.isEmpty else { return }

        showsClearCanvasConfirmation = true
    }

    @MainActor
    private func clearCanvasContent() {
        guard !puzzleDots.isEmpty else { return }

        puzzleDots = canvasHistory.clearValue()
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
    }

    @MainActor
    private func resetCanvasViewport() {
        withAnimation(.easeInOut(duration: 0.24)) {
            viewportScale = 1
            viewportOffset = .zero
        }
    }

    @MainActor
    private func shareCanvas() {
        guard let canvasImage else {
            exportMessage = "请先上传图片"
            return
        }

        let exportSize = exportCanvasSize(for: canvasImage)
        let renderer = ImageRenderer(
            content: CanvasExportView(
                image: canvasImage,
                extensionRatio: extensionRatio,
                dots: puzzleDots,
                dotScale: CGFloat(dotScale),
                dotColor: selectedDotColor,
                usesRandomDotColors: usesRandomDotColors,
                size: exportSize
            )
        )
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            exportMessage = "生成失败"
            return
        }

        guard let fileURL = exportCanvasImage(image) else {
            exportMessage = "导出失败"
            return
        }

        exportMessage = nil
        shareItem = CanvasShareItem(fileURL: fileURL)
    }

    private func exportCanvasImage(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-canvas-\(UUID().uuidString)")
            .appendingPathExtension("png")

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private func exportCanvasSize(for image: UIImage) -> CGSize {
        let sourceWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let sourceHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        let clampedRatio = min(max(extensionRatio, 0), 1)

        return CGSize(
            width: sourceWidth * (1 + clampedRatio),
            height: sourceHeight
        )
    }

    private var canvasGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .updating($gestureOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    viewportOffset = viewportOffset + value.translation
                },
            MagnifyGesture()
                .updating($gestureScale) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    viewportScale = min(max(viewportScale * value.magnification, 0.4), 6)
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
        UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: [SaveCanvasToPhotosActivity(fileURL: fileURL)]
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
        guard let image = UIImage(contentsOfFile: fileURL.path) else {
            activityDidFinish(false)
            return
        }

        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func saveCompleted(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        activityDidFinish(error == nil)
    }
}

private struct CanvasExportView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    let dots: [PuzzleDot]
    let dotScale: CGFloat
    let dotColor: Color
    let usesRandomDotColors: Bool
    let size: CGSize

    var body: some View {
        PuzzleCanvasView(
            image: image,
            extensionRatio: extensionRatio,
            dots: dots,
            dotScale: dotScale,
            dotColor: dotColor,
            usesRandomDotColors: usesRandomDotColors
        )
        .frame(width: size.width, height: size.height)
    }
}
