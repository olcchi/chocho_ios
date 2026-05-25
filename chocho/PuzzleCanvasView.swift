import SwiftUI
import UIKit

struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    let dots: [PuzzleDot]
    var dotScale: CGFloat = 1
    var dotColor: Color = .primary
    var usesRandomDotColors = false
    var viewportScale: CGFloat = 1
    var viewportOffset: CGSize = .zero
    var tracePoints: [PuzzleCanvasTracePoint] = []
    var isTraceDrawingEnabled = false
    var onTapCanvas: ((CGPoint) -> Void)?
    var onDoubleTapBackground: (() -> Void)?
    var onTraceChanged: (([PuzzleCanvasTracePoint]) -> Void)?

    @State private var isTracingCurrentStroke = false
    @State private var activeTracePoints: [PuzzleCanvasTracePoint] = []

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

                    PuzzleTraceCanvas(
                        tracePoints: tracePoints,
                        extensionRatio: extensionRatio,
                        canvasSize: layout.composedSize
                    )
                    .frame(
                        width: layout.composedSize.width,
                        height: layout.composedSize.height
                    )
                    .position(
                        x: composedFrame.midX,
                        y: composedFrame.midY
                    )
                    .opacity(isTraceDrawingEnabled ? 1 : 0)

                    PuzzleDotsCanvas(
                        dots: dots,
                        dotScale: dotScale,
                        dotColor: dotColor,
                        usesRandomDotColors: usesRandomDotColors,
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
            .modifier(
                TraceGestureModifier(
                    dragMode: PuzzleCanvasDragMode.current(
                        isTraceDrawingEnabled: isTraceDrawingEnabled
                    ),
                    gesture: traceGesture(
                        availableSize: proxy.size,
                        layout: layout
                    )
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
                guard !isTraceDrawingEnabled else { return }

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

    private func traceGesture(
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isTraceDrawingEnabled,
                      let point = PuzzleCanvasCoordinate.canvasLocation(
                        for: value.location,
                        availableSize: availableSize,
                        layout: layout,
                        scale: viewportScale,
                        offset: viewportOffset
                      ) else {
                    return
                }

                if isTracingCurrentStroke {
                    appendTracePoint(point)
                } else {
                    isTracingCurrentStroke = true
                    let strokeStartPoint = PuzzleCanvasTracePoint(
                        side: point.side,
                        point: point.point,
                        startsNewStroke: !tracePoints.isEmpty
                    )
                    activeTracePoints = tracePoints + [strokeStartPoint]
                    onTraceChanged?(activeTracePoints)
                }
            }
            .onEnded { _ in
                isTracingCurrentStroke = false
            }
    }

    private func appendTracePoint(_ point: PuzzleCanvasTracePoint) {
        guard shouldAppendTracePoint(point, after: activeTracePoints.last) else { return }

        activeTracePoints.append(point)
        onTraceChanged?(activeTracePoints)
    }

    private func shouldAppendTracePoint(
        _ point: PuzzleCanvasTracePoint,
        after previousPoint: PuzzleCanvasTracePoint?
    ) -> Bool {
        guard let previousPoint else { return true }
        guard previousPoint.side == point.side else { return true }

        let deltaX = point.point.x - previousPoint.point.x
        let deltaY = point.point.y - previousPoint.point.y

        return hypot(deltaX, deltaY) > 0.006
    }
}

private struct TraceGestureModifier<Trace: Gesture>: ViewModifier {
    let dragMode: PuzzleCanvasDragMode
    let gesture: Trace

    @ViewBuilder
    func body(content: Content) -> some View {
        switch dragMode {
        case .viewport:
            content
        case .trace:
            content.simultaneousGesture(gesture)
        }
    }
}

private struct PuzzleGridCanvas: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.secondary)
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
                with: .color(Color.border),
                lineWidth: 1
            )
        }
    }
}

private struct PuzzleDotsCanvas: View {
    let dots: [PuzzleDot]
    let dotScale: CGFloat
    let dotColor: Color
    let usesRandomDotColors: Bool
    let composedFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                let size = dot.size * dotScale
                let radius = size / 2
                let center = PuzzleCanvasCoordinate.clampedDotCenter(
                    position: dot.position,
                    in: composedFrame,
                    radius: radius
                )

                dotImage(for: dot)
                    .frame(width: size, height: size)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dotImage(for dot: PuzzleDot) -> some View {
        if let builtInShape = dot.builtInShape {
            DotShapeDrawing(
                shape: builtInShape,
                color: dot.displayColor(
                    usesRandomColor: usesRandomDotColors,
                    selectedColor: dotColor
                )
            )
        } else {
            let image = Image("public/shapes/\(dot.shapeAssetName)")

            if dot.usesTemplateColor {
                image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(dot.displayColor(
                        usesRandomColor: usesRandomDotColors,
                        selectedColor: dotColor
                    ))
            } else {
                image
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

private struct PuzzleTraceCanvas: View {
    let tracePoints: [PuzzleCanvasTracePoint]
    let extensionRatio: CGFloat
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            let displayPoints: [PuzzleTraceDisplayPoint] = tracePoints.compactMap { tracePoint in
                guard let point = PuzzleCanvasCoordinate.composedCanvasPoint(
                    for: tracePoint,
                    extensionRatio: extensionRatio,
                    canvasSize: canvasSize
                ) else {
                    return nil
                }

                return PuzzleTraceDisplayPoint(
                    point: point,
                    startsNewStroke: tracePoint.startsNewStroke
                )
            }

            guard displayPoints.count > 1 else { return }

            var path = Path()
            path.move(to: displayPoints[0].point)

            for displayPoint in displayPoints.dropFirst() {
                if displayPoint.startsNewStroke {
                    path.move(to: displayPoint.point)
                } else {
                    path.addLine(to: displayPoint.point)
                }
            }

            context.stroke(
                path,
                with: .color(Color.primary),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [7, 6]
                )
            )
        }
        .allowsHitTesting(false)
    }
}

private struct PuzzleTraceDisplayPoint {
    let point: CGPoint
    let startsNewStroke: Bool
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
    .background(Color.background)
}
