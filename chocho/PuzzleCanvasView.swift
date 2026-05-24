import SwiftUI
import UIKit

struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    let dots: [PuzzleDot]
    var viewportScale: CGFloat = 1
    var viewportOffset: CGSize = .zero
    var onTapCanvas: ((CGPoint) -> Void)?
    var onDoubleTapBackground: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let layout = PuzzleCanvasLayout.layout(
                imageSize: image.size,
                availableSize: proxy.size,
                extensionRatio: extensionRatio
            )
            let composedFrame = CGRect(
                x: layout.photoFrame.minX,
                y: layout.photoFrame.minY,
                width: layout.composedSize.width,
                height: layout.composedSize.height
            )

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(
                            width: layout.photoFrame.width,
                            height: layout.photoFrame.height
                        )
                        .position(
                            x: layout.photoFrame.midX,
                            y: layout.photoFrame.midY
                        )

                    PuzzleGridCanvas()
                        .frame(
                            width: layout.extensionFrame.width,
                            height: layout.extensionFrame.height
                        )
                        .position(
                            x: layout.extensionFrame.midX,
                            y: layout.extensionFrame.midY
                        )

                    PuzzleDotsCanvas(
                        dots: dots,
                        composedFrame: composedFrame
                    )
                }
                .scaleEffect(viewportScale)
                .offset(viewportOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                tapGesture(
                    availableSize: proxy.size,
                    layout: layout
                )
            )
            .simultaneousGesture(
                backgroundDoubleTapGesture(
                    availableSize: proxy.size,
                    layout: layout
                )
            )
        }
    }

    private func tapGesture(
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard let point = PuzzleCanvasCoordinate.normalizedPoint(
                    for: value.location,
                    availableSize: availableSize,
                    layout: layout,
                    scale: viewportScale,
                    offset: viewportOffset
                ) else {
                    return
                }

                onTapCanvas?(point)
            }
    }

    private func backgroundDoubleTapGesture(
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                guard PuzzleCanvasCoordinate.isBackgroundTap(
                    at: value.location,
                    availableSize: availableSize,
                    layout: layout,
                    scale: viewportScale,
                    offset: viewportOffset
                ) else {
                    return
                }

                onDoubleTapBackground?()
            }
    }
}

private struct PuzzleGridCanvas: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 248 / 255, green: 252 / 255, blue: 255 / 255))
            )

            let spacing: CGFloat = 12
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(
                path,
                with: .color(Color(red: 200 / 255, green: 229 / 255, blue: 255 / 255)),
                lineWidth: 1
            )
        }
    }
}

private struct PuzzleDotsCanvas: View {
    let dots: [PuzzleDot]
    let composedFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                let radius = dot.size / 2
                let center = PuzzleCanvasCoordinate.clampedDotCenter(
                    position: dot.position,
                    in: composedFrame,
                    radius: radius
                )

                Image("public/shapes/\(dot.shapeAssetName)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: dot.size, height: dot.size)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Puzzle Canvas") {
    let renderer = ImageRenderer(content: Color.brown.frame(width: 320, height: 220))
    let image = renderer.uiImage ?? UIImage()

    PuzzleCanvasView(
        image: image,
        extensionRatio: 0.2,
        dots: PuzzleDotFactory.makeDots(count: 10)
    )
    .padding()
    .background(Color(red: 245 / 255, green: 254 / 255, blue: 233 / 255))
}
