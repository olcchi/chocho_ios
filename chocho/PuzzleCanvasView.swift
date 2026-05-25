import SwiftUI
import UIKit

struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    var extensionSide: PuzzleCanvasExtensionSide = .right
    let dots: [PuzzleDot]
    var dotScale: CGFloat = 1
    var dotColor: Color = .primary
    var usesRandomDotColors = false
    var viewportScale: CGFloat = 1
    var viewportOffset: CGSize = .zero
    var tracePoints: [PuzzleCanvasTracePoint] = []
    var isTraceDrawingEnabled = false
    var onTapCanvas: ((CGPoint) -> Void)?
    var onDoubleTapBackground: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onViewportReset: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onTraceChanged: (([PuzzleCanvasTracePoint]) -> Void)?

    @State private var isTracingCurrentStroke = false
    @State private var activeTracePoints: [PuzzleCanvasTracePoint] = []

    var body: some View {
        GeometryReader { proxy in
            let layout = PuzzleCanvasLayout.layout(
                imageSize: image.size,
                availableSize: proxy.size,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            let referenceFrame = layout.referenceComposedFrame
            let referenceLocalPhotoFrame = layout.referenceLocalPhotoFrame
            let referenceLocalFrame = CGRect(
                origin: .zero,
                size: referenceFrame.size
            )
            let extensionGridFrame = layout.referenceLocalExtensionGridFrame

            ZStack(alignment: .topLeading) {
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
                                x: referenceLocalPhotoFrame.midX,
                                y: referenceLocalPhotoFrame.midY
                            )

                        PuzzleGridCanvas()
                            .frame(
                                width: extensionGridFrame.width,
                                height: extensionGridFrame.height
                            )
                            .position(
                                x: extensionGridFrame.midX,
                                y: extensionGridFrame.midY
                            )

                        PuzzleTraceCanvas(
                            tracePoints: tracePoints,
                            canvasSize: referenceFrame.size,
                            extensionSide: extensionSide
                        )
                        .frame(
                            width: referenceFrame.width,
                            height: referenceFrame.height
                        )
                        .position(
                            x: referenceFrame.width / 2,
                            y: referenceFrame.height / 2
                        )
                        .opacity(isTraceDrawingEnabled ? 1 : 0)

                        PuzzleDotsCanvas(
                            dots: dots,
                            dotScale: dotScale,
                            dotColor: dotColor,
                            usesRandomDotColors: usesRandomDotColors,
                            photoFrame: referenceLocalPhotoFrame,
                            referenceFrame: referenceLocalFrame,
                            extensionSide: extensionSide
                        )
                        .frame(
                            width: referenceFrame.width,
                            height: referenceFrame.height
                        )
                    }
                    .frame(
                        width: referenceFrame.width,
                        height: referenceFrame.height,
                        alignment: .topLeading
                    )
                    .frame(
                        width: layout.composedSize.width,
                        height: layout.composedSize.height,
                        alignment: layout.visibleComposedClipAlignment
                    )
                    .clipped()
                    .position(
                        x: layout.visibleComposedClipPosition.x,
                        y: layout.visibleComposedClipPosition.y
                    )
                    .animation(.none, value: extensionRatio)
                    .animation(.none, value: extensionSide)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
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
            .background {
                ViewportResetObserver(
                    key: CanvasViewportResetKey(
                        extensionRatio: extensionRatio,
                        extensionSide: extensionSide,
                        availableSize: proxy.size,
                        imageSize: image.size
                    ),
                    layout: layout,
                    availableSize: proxy.size,
                    onReset: onViewportReset
                )
            }
        }
    }

    private func tapGesture(
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard !isTraceDrawingEnabled else { return }

                guard let canvasLocation = PuzzleCanvasCoordinate.canvasLocation(
                    for: value.location,
                    availableSize: availableSize,
                    layout: layout,
                    scale: viewportScale,
                    offset: viewportOffset
                ) else {
                    return
                }

                onTapCanvas?(canvasLocation.point)
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

                let reset = PuzzleCanvasViewport.resetTransform(
                    layout: layout,
                    availableSize: availableSize
                )
                onDoubleTapBackground?(reset.scale, reset.offset)
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

private struct ViewportResetObserver: View {
    let key: CanvasViewportResetKey
    let layout: PuzzleCanvasLayoutResult
    let availableSize: CGSize
    let onReset: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: key, initial: true) { _, _ in
                let reset = PuzzleCanvasViewport.resetTransform(
                    layout: layout,
                    availableSize: availableSize
                )
                onReset?(reset.scale, reset.offset)
            }
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
    let photoFrame: CGRect
    let referenceFrame: CGRect
    let extensionSide: PuzzleCanvasExtensionSide

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                let size = DotSizeControl.displaySize(
                    renderedScale: dot.size * dotScale,
                    photoFrameHeight: photoFrame.height
                )
                let radius = size / 2
                let centers = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
                    position: dot.position,
                    referenceFrame: referenceFrame,
                    extensionSide: extensionSide,
                    radius: radius
                )

                ForEach(Array(centers.enumerated()), id: \.offset) { _, center in
                    dotImage(for: dot)
                        .frame(width: size, height: size)
                        .position(center)
                }
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
    let canvasSize: CGSize
    let extensionSide: PuzzleCanvasExtensionSide

    var body: some View {
        Canvas { context, _ in
            let displayPoints: [PuzzleTraceDisplayPoint] = tracePoints.compactMap { tracePoint in
                guard let point = PuzzleCanvasCoordinate.composedCanvasPoint(
                    for: tracePoint,
                    canvasSize: canvasSize,
                    extensionSide: extensionSide
                ) else {
                    return nil
                }

                return PuzzleTraceDisplayPoint(
                    side: tracePoint.side,
                    point: point,
                    startsNewStroke: tracePoint.startsNewStroke
                )
            }

            guard displayPoints.count > 1 else { return }

            var path = Path()
            path.move(to: displayPoints[0].point)
            var previousSide = displayPoints[0].side

            for displayPoint in displayPoints.dropFirst() {
                if displayPoint.startsNewStroke || displayPoint.side != previousSide {
                    path.move(to: displayPoint.point)
                } else {
                    path.addLine(to: displayPoint.point)
                }

                previousSide = displayPoint.side
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
    let side: PuzzleCanvasSide
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
