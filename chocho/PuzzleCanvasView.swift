import SwiftUI
import UIKit

struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    var extensionSide: PuzzleCanvasExtensionSide = .right
    var backgroundStyle: PuzzleBackgroundStyle = .grid
    var imageViewportResetID: UUID = UUID()
    /// Compensates for bottom-panel expansion so layout fit scale does not change.
    var panelLayoutHeightBoost: CGFloat = 0
    let dots: [PuzzleDot]
    var dotScale: CGFloat = 1
    var dotColor: Color = .primary
    var usesRandomDotColors = false
    var viewportScale: CGFloat = 1
    var viewportOffset: CGSize = .zero
    var tracePoints: [PuzzleCanvasTracePoint] = []
    var isTraceDrawingEnabled = false
    var onTapCanvas: ((PuzzleCanvasTracePoint) -> Void)?
    var onDoubleTapBackground: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onViewportReset: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onTraceChanged: (([PuzzleCanvasTracePoint]) -> Void)?
    /// Screen preview uses a lighter filter; export keeps high quality when needed.
    var photoInterpolation: Image.Interpolation = .medium

    @State private var isTracingCurrentStroke = false
    @State private var activeTracePoints: [PuzzleCanvasTracePoint] = []

    var body: some View {
        GeometryReader { proxy in
            let layoutAvailableSize = CGSize(
                width: proxy.size.width,
                height: proxy.size.height + panelLayoutHeightBoost
            )
            let layout = PuzzleCanvasLayout.layout(
                imageSize: image.size,
                availableSize: layoutAvailableSize,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            let referenceFrame = layout.referenceComposedFrame
            let referenceLocalPhotoFrame = layout.referenceLocalPhotoFrame
            let extensionGridFrame = layout.referenceLocalExtensionGridFrame

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(photoInterpolation)
                            .frame(
                                width: layout.photoFrame.width,
                                height: layout.photoFrame.height
                            )
                            .position(
                                x: referenceLocalPhotoFrame.midX,
                                y: referenceLocalPhotoFrame.midY
                            )

                        extensionBackgroundView(photoFrameHeight: referenceLocalPhotoFrame.height)
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
                            image: image,
                            dots: dots,
                            dotScale: dotScale,
                            dotColor: dotColor,
                            usesRandomDotColors: usesRandomDotColors,
                            backgroundStyle: backgroundStyle,
                            photoFrame: referenceLocalPhotoFrame,
                            layout: layout
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
                    .animation(.none, value: backgroundStyle)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .scaleEffect(viewportScale)
                .offset(viewportOffset)
                .animation(BottomSheetPanel.panelMotion, value: panelLayoutHeightBoost)
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
                        imageViewportResetID: imageViewportResetID
                    ),
                    layout: layout,
                    availableSize: proxy.size,
                    onReset: onViewportReset
                )
            }
        }
    }

    @ViewBuilder
    private func extensionBackgroundView(photoFrameHeight: CGFloat) -> some View {
        switch backgroundStyle {
        case .grid:
            PuzzleGridCanvas(photoFrameHeight: photoFrameHeight)
        case .stripes:
            PuzzleStripesCanvas(photoFrameHeight: photoFrameHeight)
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

                onTapCanvas?(canvasLocation)
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

    @State private var awaitingLayoutReset = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: key, initial: true) { _, _ in
                awaitingLayoutReset = true
                attemptReset()
            }
            .onChange(of: availableSize) { _, _ in
                guard awaitingLayoutReset else { return }
                attemptReset()
            }
    }

    private func attemptReset() {
        guard awaitingLayoutReset,
              availableSize.width > 0,
              availableSize.height > 0,
              layout.visibleComposedFrame.width > 0,
              layout.visibleComposedFrame.height > 0 else {
            return
        }

        let reset = PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: availableSize
        )
        onReset?(reset.scale, reset.offset)
        awaitingLayoutReset = false
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
    let photoFrameHeight: CGFloat

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            PuzzleBackgroundCanvasDrawing.fillBase(in: &context, size: size)
            PuzzleBackgroundCanvasDrawing.strokeGrid(
                in: &context,
                size: size,
                photoFrameHeight: photoFrameHeight
            )
        }
    }
}

private struct PuzzleStripesCanvas: View {
    let photoFrameHeight: CGFloat

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            PuzzleBackgroundCanvasDrawing.fillStripes(
                in: &context,
                size: size,
                photoFrameHeight: photoFrameHeight
            )
        }
    }
}

private enum PuzzleBackgroundCanvasDrawing {
    static func fillBase(in context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color.secondary)
        )
    }

    static func strokeGrid(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
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

        stroke(path, in: &context, photoFrameHeight: photoFrameHeight)
    }

    static func fillStripes(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
        var y: CGFloat = 0
        var usesPrimaryStripe = true

        while y < size.height {
            let bandHeight = min(spacing, size.height - y)
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: bandHeight)),
                with: .color(usesPrimaryStripe ? Color.secondary : Color.background)
            )
            y += spacing
            usesPrimaryStripe.toggle()
        }
    }

    private static func stroke(
        _ path: Path,
        in context: inout GraphicsContext,
        photoFrameHeight: CGFloat
    ) {
        context.stroke(
            path,
            with: .color(Color.border),
            lineWidth: PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: photoFrameHeight)
        )
    }
}

private struct PuzzleDotsCanvas: View {
    let image: UIImage
    let dots: [PuzzleDot]
    let dotScale: CGFloat
    let dotColor: Color
    let usesRandomDotColors: Bool
    let backgroundStyle: PuzzleBackgroundStyle
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                let size = DotSizeControl.displaySize(
                    renderedScale: dot.size * dotScale * dot.displaySizeScale,
                    photoFrameHeight: photoFrame.height
                )
                let centers = PuzzleCanvasCoordinate.dotCenters(for: dot.position, in: layout)

                ForEach(Array(centers.enumerated()), id: \.offset) { centerIndex, center in
                    Color.clear
                        .frame(width: size, height: size)
                        .overlay {
                            dotImage(for: dot, centerIndex: centerIndex, size: size)
                                .frame(width: size, height: size, alignment: .topLeading)
                                .clipped()
                        }
                        .position(center)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.none, value: dots.count)
    }

    @ViewBuilder
    private func dotImage(for dot: PuzzleDot, centerIndex: Int, size: CGFloat) -> some View {
        if let builtInShape = dot.builtInShape {
            if PuzzleDotCollageColor.shouldRenderCollageContent(
                for: dot,
                usesRandomDotColors: usesRandomDotColors,
                extensionRatio: layout.extensionRatio,
                selectedDotColor: dotColor
            ) {
                PuzzleDotCollageBasicShapeView(
                    shape: builtInShape,
                    centerIndex: centerIndex,
                    dot: dot,
                    image: image,
                    backgroundStyle: backgroundStyle,
                    photoFrame: photoFrame,
                    layout: layout,
                    dotSize: size
                )
            } else {
                DotShapeDrawing(
                    shape: builtInShape,
                    color: dot.displayColor(
                        usesRandomColor: usesRandomDotColors,
                        selectedColor: dotColor
                    )
                )
            }
        } else if PuzzleDotCollageColor.shouldRenderCollageContent(
            for: dot,
            usesRandomDotColors: usesRandomDotColors,
            extensionRatio: layout.extensionRatio,
            selectedDotColor: dotColor
        ) {
            PuzzleDotCollageAssetShapeView(
                centerIndex: centerIndex,
                dot: dot,
                image: image,
                backgroundStyle: backgroundStyle,
                photoFrame: photoFrame,
                layout: layout,
                dotSize: size
            )
        } else {
            let stickerColor = dot.displayColor(
                usesRandomColor: usesRandomDotColors,
                selectedColor: dotColor
            )

            DotShapeAssetImageView(
                assetName: "public/\(dot.shapeAssetName)",
                renderingMode: dot.usesTemplateColor ? .template : .original,
                tintColor: dot.usesTemplateColor ? stickerColor : nil
            )
        }
    }
}

private struct PuzzleDotCollageBasicShapeView: View {
    let shape: BuiltInDotShape
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    let backgroundStyle: PuzzleBackgroundStyle
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        PuzzleDotCollageMirrorFill(
            centerIndex: centerIndex,
            dot: dot,
            image: image,
            backgroundStyle: backgroundStyle,
            photoFrame: photoFrame,
            layout: layout,
            dotSize: dotSize
        )
        .mask {
            DotShapeDrawing(shape: shape, color: .white)
        }
    }
}

private struct PuzzleDotCollageAssetShapeView: View {
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    let backgroundStyle: PuzzleBackgroundStyle
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        PuzzleDotCollageMirrorFill(
            centerIndex: centerIndex,
            dot: dot,
            image: image,
            backgroundStyle: backgroundStyle,
            photoFrame: photoFrame,
            layout: layout,
            dotSize: dotSize
        )
        .mask {
            DotShapeAssetImageView(
                assetName: "public/\(dot.shapeAssetName)",
                renderingMode: .template,
                tintColor: .white
            )
        }
    }
}

private struct PuzzleDotCollageMirrorFill: View {
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    let backgroundStyle: PuzzleBackgroundStyle
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        let extensionFrame = layout.referenceLocalExtensionGridFrame

        if centerIndex == 0 {
            let mirrorPosition = PuzzleDotCollageColor.referenceExtensionMirrorPosition(
                forPhotoPosition: dot.position,
                extensionSide: layout.extensionSide
            )
            let samplePoint = PuzzleDotCollageColor.clampedExtensionSamplePoint(mirrorPosition)
            let offset = PuzzleDotCollageColor.contentOffsetInDot(
                dotSize: dotSize,
                normalizedPoint: samplePoint,
                contentSize: extensionFrame.size
            )

            PuzzleDotCollageBackgroundFill(
                style: backgroundStyle,
                extensionSize: extensionFrame.size,
                photoFrameHeight: photoFrame.height
            )
            .frame(width: extensionFrame.width, height: extensionFrame.height, alignment: .topLeading)
            .offset(x: offset.width, y: offset.height)
            .frame(width: dotSize, height: dotSize, alignment: .topLeading)
            .clipped()
        } else {
            let offset = PuzzleDotCollageColor.contentOffsetInDot(
                dotSize: dotSize,
                normalizedPoint: dot.position,
                contentSize: photoFrame.size
            )

            Image(uiImage: image)
                .resizable()
                .frame(width: photoFrame.width, height: photoFrame.height, alignment: .topLeading)
                .offset(x: offset.width, y: offset.height)
                .frame(width: dotSize, height: dotSize, alignment: .topLeading)
                .clipped()
        }
    }
}

private struct PuzzleDotCollageBackgroundFill: View {
    let style: PuzzleBackgroundStyle
    let extensionSize: CGSize
    let photoFrameHeight: CGFloat

    var body: some View {
        Canvas { context, _ in
            switch style {
            case .grid:
                PuzzleBackgroundCanvasDrawing.fillBase(in: &context, size: extensionSize)
                PuzzleBackgroundCanvasDrawing.strokeGrid(
                    in: &context,
                    size: extensionSize,
                    photoFrameHeight: photoFrameHeight
                )
            case .stripes:
                PuzzleBackgroundCanvasDrawing.fillStripes(
                    in: &context,
                    size: extensionSize,
                    photoFrameHeight: photoFrameHeight
                )
            }
        }
        .frame(width: extensionSize.width, height: extensionSize.height)
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
