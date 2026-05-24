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
    @State private var dotCount: Double = 10
    @State private var selectedDotShape: DotShapeAsset = .defaultSelection
    @State private var puzzleDots: [PuzzleDot] = []
    @State private var exportMessage: String?
    @State private var shareItem: CanvasShareItem?
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color(red: 245 / 255, green: 254 / 255, blue: 233 / 255)
                    .ignoresSafeArea()

                panelBackgroundColor
                    .ignoresSafeArea(edges: .top)
                    .frame(height: topActionBarHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                canvasArea
                .padding(.top, topCanvasInset(for: proxy))
                .padding(.bottom, 297 - proxy.safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(alignment: .trailing, spacing: 8) {
                    canvasActions()

                    if let exportMessage {
                        CanvasStatusLabel(title: exportMessage)
                    }
                }
                .padding(.top, 4)
                .padding(.trailing, 25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(1)

                BottomSheetPanel(
                    selectedTab: $selectedTab,
                    dotCount: $dotCount,
                    selectedDotShape: $selectedDotShape,
                    onDrawDots: drawPuzzleDots
                )
                    .padding(.bottom, -proxy.safeAreaInsets.bottom)
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .sheet(item: $shareItem) { item in
            CanvasShareSheet(fileURL: item.fileURL)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var canvasArea: some View {
        if let canvasImage {
            PuzzleCanvasView(
                image: canvasImage,
                extensionRatio: extensionRatio,
                dots: puzzleDots,
                viewportScale: viewportScale * gestureScale,
                viewportOffset: viewportOffset + gestureOffset,
                onTapCanvas: addPuzzleDot(at:),
                onDoubleTapBackground: resetCanvasViewport
            )
            .gesture(canvasGesture)
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                CanvasUploadPlaceholder()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func canvasActions() -> some View {
        let canDownload = canvasImage != nil

        return HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                CanvasActionLabel(title: "上传", iconAssetName: "public/upload")
            }
            .buttonStyle(.plain)

            Button {
                shareCanvas()
            } label: {
                CanvasActionLabel(title: "下载", iconAssetName: "public/download", isEnabled: canDownload)
            }
            .buttonStyle(.plain)
            .disabled(!canDownload)
        }
    }

    private func topCanvasInset(for proxy: GeometryProxy) -> CGFloat {
        topActionBarHeight
    }

    private var topActionBarHeight: CGFloat {
        50
    }

    private var panelBackgroundColor: Color {
        Color(red: 253 / 255, green: 253 / 255, blue: 253 / 255)
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
            viewportScale = 1
            viewportOffset = .zero
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

        puzzleDots = PuzzleDotFactory.makeDots(
            count: Int(dotCount.rounded()),
            shapeAssetName: selectedDotShape.name
        )
        exportMessage = nil
    }

    @MainActor
    private func addPuzzleDot(at position: CGPoint) {
        puzzleDots.append(PuzzleDotFactory.makeDot(
            position: position,
            index: puzzleDots.count,
            shapeAssetName: selectedDotShape.name
        ))
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

private struct CanvasActionLabel: View {
    let title: String
    let iconAssetName: String
    var isEnabled = true

    var body: some View {
        Image(iconAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(isEnabled ? Color.black : Color.black.opacity(0.35))
            .frame(width: 36, height: 30)
            .background(
                actionColor.opacity(isEnabled ? 1 : 0.45),
                in: Capsule(style: .continuous)
            )
            .accessibilityLabel(title)
    }

    private var actionColor: Color {
        Color(red: 165 / 255, green: 231 / 255, blue: 76 / 255)
    }
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
        .foregroundStyle(Color(red: 0 / 255, green: 195 / 255, blue: 255 / 255))
        .multilineTextAlignment(.center)
        .frame(width: 308, height: 220)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color(red: 0 / 255, green: 195 / 255, blue: 255 / 255),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
        }
    }
}

private struct CanvasStatusLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Color(red: 165 / 255, green: 231 / 255, blue: 76 / 255),
                in: Capsule(style: .continuous)
            )
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
    let size: CGSize

    var body: some View {
        PuzzleCanvasView(
            image: image,
            extensionRatio: extensionRatio,
            dots: dots
        )
        .frame(width: size.width, height: size.height)
    }
}
