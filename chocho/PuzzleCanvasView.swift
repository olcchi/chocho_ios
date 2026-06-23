import SwiftUI
import UIKit

// MARK: - 画布预览
/// 照片 + 扩展背景 + 波点层；实况动画时由 `TimelineView` 驱动 `blinkTime`（仅波点，背景不动）。
struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    var extensionSide: PuzzleCanvasExtensionSide = .right
    var photoCompression: MainPhotoCompression = .none
    var backgroundStyle: PuzzleBackgroundStyle = .grid
    var backgroundColors: PuzzleBackgroundColors = .default
    var backgroundPatternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue
    var imageViewportResetID: UUID = UUID()
    /// 底部面板占用高度，用于在面板上方垂直居中合成区域。
    var bottomPanelInset: CGFloat = 0
    let dots: [PuzzleDot]
    var dotScale: CGFloat = 1
    var dotColor: Color = .primary
    var usesRandomDotColors = false
    var dotCharacterText = CharacterDotText.defaultText
    var viewportScale: CGFloat = 1
    var viewportOffset: CGSize = .zero
    var tracePoints: [PuzzleCanvasTracePoint] = []
    var subjectOutlinePoints: [PuzzleCanvasTracePoint] = []
    var isTraceDrawingEnabled = false
    var isTraceVisible = true
    var isSubjectOutlineEnabled = false
    var liveDotAnimation: LiveDotAnimation = .none
    var livePreviewPlaybackStart: Date?
    var isY2KCCDFilterPreviewEnabled = false
    var isSourceLiveMotionEnabled = false
    var sourceLiveVideo: CanvasSourceLiveVideo?
    var isDotEditingEnabled = false
    var selectedDotID: UUID?
    var onTapCanvas: ((PuzzleCanvasTracePoint) -> Void)?
    var onPanViewport: ((CGSize) -> Void)?
    var onDoubleTapBackground: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onViewportReset: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?
    var onTraceChanged: (([PuzzleCanvasTracePoint]) -> Void)?
    var onTraceStrokeEnded: (() -> Void)?
    var onSelectDot: ((UUID?) -> Void)?
    var onMoveSelectedDot: ((CGPoint) -> Void)?
    var onScaleSelectedDot: ((CGFloat) -> Void)?
    var onRotateSelectedDot: ((CGFloat) -> Void)?
    var onCommitSelectedDotEdit: (() -> Void)?
    var onDeleteSelectedDot: (() -> Void)?
    /// 屏幕预览用较轻插值；导出走 `CanvasRasterExporter` 全质量。
    var photoInterpolation: Image.Interpolation = .medium

    @State private var isTracingCurrentStroke = false
    @State private var activeTracePoints: [PuzzleCanvasTracePoint] = []
    @State private var activeCanvasDragMode: PuzzleCanvasActiveDragMode?
    @State private var viewportDragTranslation: CGSize = .zero
    @State private var lastEditMagnification: CGFloat = 1
    @State private var lastEditRotation: Angle = .zero
    @State private var appliedViewportResetKey: CanvasViewportResetKey?

    private var shouldRunLivePreviewTimeline: Bool {
        guard livePreviewPlaybackStart != nil else { return false }
        if liveDotAnimation != .none { return true }
        if isY2KCCDFilterPreviewEnabled { return false }
        return isSourceLiveMotionEnabled && sourceLiveVideo != nil
    }

    private var previewTimelineDuration: TimeInterval {
        CanvasLiveMotionTiming.exportDuration(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            sourceLiveVideoDuration: sourceLiveVideo?.duration
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = PuzzleCanvasLayout.layout(
                imageSize: image.size,
                availableSize: proxy.size,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide,
                photoCompression: photoCompression
            )
            let referenceFrame = layout.referenceComposedFrame
            let referenceLocalPhotoFrame = layout.referenceLocalPhotoFrame
            let extensionGridFrame = layout.referenceLocalExtensionGridFrame
            let displayOffset = displayViewportOffset(
                layout: layout,
                availableSize: proxy.size
            )

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Group {
                        // 实况预览：波点动画和/或原图实况驱动 TimelineView。
                        if shouldRunLivePreviewTimeline, let livePreviewPlaybackStart {
                            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                                composedCanvasLayers(
                                    layout: layout,
                                    referenceFrame: referenceFrame,
                                    referenceLocalPhotoFrame: referenceLocalPhotoFrame,
                                    extensionGridFrame: extensionGridFrame,
                                    blinkTime: timeline.date.timeIntervalSince(livePreviewPlaybackStart)
                                )
                            }
                        } else {
                            composedCanvasLayers(
                                layout: layout,
                                referenceFrame: referenceFrame,
                                referenceLocalPhotoFrame: referenceLocalPhotoFrame,
                                extensionGridFrame: extensionGridFrame,
                                blinkTime: nil
                            )
                        }
                    }
                    .animation(.none, value: extensionRatio)
                    .animation(.none, value: extensionSide)
                    .animation(.none, value: photoCompression)
                    .animation(.none, value: backgroundStyle)
                    .animation(.none, value: backgroundColors)
                    .animation(.none, value: backgroundPatternSpacing)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .scaleEffect(viewportScale)
                .offset(displayOffset)
                .animation(BottomSheetPanel.panelMotion, value: bottomPanelInset)
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
                canvasDragGesture(
                    availableSize: proxy.size,
                    layout: layout
                )
            )
            .modifier(
                DotEditingGestureModifier(
                    isEnabled: isDotEditingEnabled && selectedDotID != nil,
                    magnifyGesture: selectedDotMagnifyGesture,
                    rotateGesture: selectedDotRotationGesture
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
                        photoCompression: photoCompression,
                        imageViewportResetID: imageViewportResetID
                    ),
                    appliedKey: $appliedViewportResetKey,
                    layout: layout,
                    availableSize: proxy.size,
                    onReset: onViewportReset
                )
            }
        }
    }

    @ViewBuilder
    private func composedCanvasLayers(
        layout: PuzzleCanvasLayoutResult,
        referenceFrame: CGRect,
        referenceLocalPhotoFrame: CGRect,
        extensionGridFrame: CGRect,
        blinkTime: TimeInterval?
    ) -> some View {
        ZStack(alignment: .topLeading) {
            halftoneAwareExtensionBackground(
                photoFrameHeight: layout.backgroundPatternReferenceHeight,
                extensionGridFrame: extensionGridFrame
            )

            if layout.extensionSide == .center {
                PuzzleDotsCanvas(
                    image: image,
                    dots: dots,
                    dotScale: dotScale,
                    dotColor: dotColor,
                    usesRandomDotColors: usesRandomDotColors,
                    dotCharacterText: dotCharacterText,
                    liveDotAnimation: liveDotAnimation,
                    blinkTime: blinkTime,
                    liveFrameImage: liveFrameImageForDots(blinkTime: blinkTime),
                    backgroundStyle: backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
                    photoFrame: referenceLocalPhotoFrame,
                    layout: layout,
                    centerIndexFilter: .background
                )
                .frame(
                    width: referenceFrame.width,
                    height: referenceFrame.height
                )
            }

            Image(uiImage: photoImage(for: blinkTime))
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

            PuzzleTraceCanvas(
                tracePoints: tracePoints,
                layout: layout
            )
            .frame(
                width: referenceFrame.width,
                height: referenceFrame.height
            )
            .position(
                x: referenceFrame.width / 2,
                y: referenceFrame.height / 2
            )
            .opacity(isTraceDrawingEnabled && isTraceVisible && !tracePoints.isEmpty ? 1 : 0)

            PuzzleTraceCanvas(
                tracePoints: subjectOutlinePoints,
                layout: layout
            )
            .frame(
                width: referenceFrame.width,
                height: referenceFrame.height
            )
            .position(
                x: referenceFrame.width / 2,
                y: referenceFrame.height / 2
            )
            .opacity(isTraceDrawingEnabled && isTraceVisible && isSubjectOutlineEnabled && !subjectOutlinePoints.isEmpty ? 1 : 0)

            PuzzleDotsCanvas(
                image: image,
                dots: dots,
                dotScale: dotScale,
                dotColor: dotColor,
                usesRandomDotColors: usesRandomDotColors,
                dotCharacterText: dotCharacterText,
                liveDotAnimation: liveDotAnimation,
                blinkTime: blinkTime,
                liveFrameImage: liveFrameImageForDots(blinkTime: blinkTime),
                backgroundStyle: backgroundStyle,
                backgroundColors: backgroundColors,
                backgroundPatternSpacing: backgroundPatternSpacing,
                photoFrame: referenceLocalPhotoFrame,
                layout: layout,
                centerIndexFilter: layout.extensionSide == .center ? .photo : .all
            )
            .frame(
                width: referenceFrame.width,
                height: referenceFrame.height
            )

            DotEditingSelectionOverlay(
                dots: dots,
                selectedDotID: selectedDotID,
                isDotEditingEnabled: isDotEditingEnabled,
                dotScale: dotScale,
                layout: layout,
                onDelete: onDeleteSelectedDot
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
    }

    private func photoImage(for blinkTime: TimeInterval?) -> UIImage {
        guard !isY2KCCDFilterPreviewEnabled else { return image }
        guard isSourceLiveMotionEnabled,
              let sourceLiveVideo,
              let blinkTime else {
            return image
        }

        let duration = previewTimelineDuration
        guard duration > 0 else { return image }

        return sourceLiveVideo.frame(at: blinkTime, timelineDuration: duration) ?? image
    }

    /// 拼贴波点所需的实况帧：原图实况开启且有帧数据时返回；否则 nil（用静态原图）。
    private func liveFrameImageForDots(blinkTime: TimeInterval?) -> UIImage? {
        guard !isY2KCCDFilterPreviewEnabled else { return nil }
        guard isSourceLiveMotionEnabled,
              let sourceLiveVideo,
              let blinkTime else {
            return nil
        }

        let duration = previewTimelineDuration
        guard duration > 0 else { return nil }

        return sourceLiveVideo.frame(at: blinkTime, timelineDuration: duration)
    }

    private func displayViewportOffset(
        layout: PuzzleCanvasLayoutResult,
        availableSize: CGSize
    ) -> CGSize {
        let panelTracking = PuzzleCanvasViewport.panelTrackingOffset(
            layout: layout,
            availableSize: availableSize,
            bottomPanelInset: bottomPanelInset
        )
        return CGSize(
            width: viewportOffset.width + panelTracking.width + viewportDragTranslation.width,
            height: viewportOffset.height + panelTracking.height + viewportDragTranslation.height
        )
    }

    @ViewBuilder
    private func halftoneAwareExtensionBackground(
        photoFrameHeight: CGFloat,
        extensionGridFrame: CGRect
    ) -> some View {
        if backgroundStyle == .halftone {
            let visibleSize = PuzzleHalftoneBackgroundMetrics.visibleDisplaySize(
                fullExtensionSize: extensionGridFrame.size,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            let center = PuzzleHalftoneBackgroundMetrics.visibleDisplayCenter(
                in: extensionGridFrame,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            extensionBackgroundView(
                photoFrameHeight: photoFrameHeight,
                displaySize: visibleSize
            )
            .frame(width: visibleSize.width, height: visibleSize.height)
            .position(x: center.x, y: center.y)
        } else {
            extensionBackgroundView(
                photoFrameHeight: photoFrameHeight,
                displaySize: extensionGridFrame.size
            )
            .frame(width: extensionGridFrame.width, height: extensionGridFrame.height)
            .position(x: extensionGridFrame.midX, y: extensionGridFrame.midY)
        }
    }

    @ViewBuilder
    private func extensionBackgroundView(
        photoFrameHeight: CGFloat,
        displaySize: CGSize
    ) -> some View {
        switch backgroundStyle {
        case .solid:
            Color(backgroundColors.fillColor)
        case .grid:
            PuzzleGridCanvas(
                photoFrameHeight: photoFrameHeight,
                colors: backgroundColors,
                patternSpacing: backgroundPatternSpacing
            )
        case .stripes:
            PuzzleStripesCanvas(
                photoFrameHeight: photoFrameHeight,
                colors: backgroundColors,
                patternSpacing: backgroundPatternSpacing
            )
        case .polkaDots:
            PuzzlePolkaDotsCanvas(
                photoFrameHeight: photoFrameHeight,
                colors: backgroundColors,
                dotSize: backgroundPatternSpacing
            )
        case .halftone:
            PuzzleHalftoneBackgroundView(
                sourceImage: image,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide,
                displaySize: displaySize,
                backgroundColor: backgroundColors.fillColor,
                dotColor: backgroundColors.lineColor
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

                if isDotEditingEnabled {
                    let tappedDotID = dotID(
                        at: value.location,
                        availableSize: availableSize,
                        layout: layout
                    )
                    onSelectDot?(tappedDotID)
                    if tappedDotID == nil {
                        resetViewport(
                            layout: layout,
                            availableSize: availableSize
                        )
                    }
                    return
                }

                guard let canvasLocation = PuzzleCanvasCoordinate.canvasLocation(
                    for: value.location,
                    availableSize: availableSize,
                    layout: layout,
                    scale: viewportScale,
                    offset: displayViewportOffset(
                        layout: layout,
                        availableSize: availableSize
                    )
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
                    offset: displayViewportOffset(
                        layout: layout,
                        availableSize: availableSize
                    )
                ) else {
                    return
                }

                if isDotEditingEnabled {
                    onSelectDot?(nil)
                }

                resetViewport(
                    layout: layout,
                    availableSize: availableSize
                )
            }
    }

    private func resetViewport(
        layout: PuzzleCanvasLayoutResult,
        availableSize: CGSize
    ) {
        let reset = PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: availableSize,
            bottomPanelInset: 0
        )
        onDoubleTapBackground?(reset.scale, reset.offset)
    }

    private func canvasDragGesture(
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> some Gesture {
        DragGesture(minimumDistance: DotEditingGestureMetrics.minimumDragDistance, coordinateSpace: .local)
            .onChanged { value in
                guard PuzzleCanvasViewportPanPolicy.isEnabled(
                    isTraceDrawingEnabled: isTraceDrawingEnabled,
                    isDotEditingEnabled: isDotEditingEnabled,
                    isSelectedDotDragActive: activeCanvasDragMode == .selectedDot
                ) || activeCanvasDragMode == .selectedDot else { return }

                switch resolvedCanvasDragMode(
                    for: value,
                    availableSize: availableSize,
                    layout: layout
                ) {
                case .viewport:
                    viewportDragTranslation = value.translation

                case .selectedDot:
                    moveSelectedDot(
                        with: value,
                        availableSize: availableSize,
                        layout: layout
                    )
                }
            }
            .onEnded { value in
                let endedMode = activeCanvasDragMode
                defer {
                    activeCanvasDragMode = nil
                    viewportDragTranslation = .zero
                }

                switch endedMode {
                case .viewport:
                    onPanViewport?(value.translation)
                case .selectedDot:
                    onCommitSelectedDotEdit?()
                case nil:
                    break
                }
            }
    }

    private func resolvedCanvasDragMode(
        for value: DragGesture.Value,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> PuzzleCanvasActiveDragMode {
        if let activeCanvasDragMode {
            return activeCanvasDragMode
        }

        let startedDotID = dotID(
            at: value.startLocation,
            availableSize: availableSize,
            layout: layout
        )
        let nextMode: PuzzleCanvasActiveDragMode = DotEditingGestureMetrics.shouldBeginSelectedDotDrag(
            startedDotID: startedDotID,
            selectedDotID: selectedDotID
        ) ? .selectedDot : .viewport
        activeCanvasDragMode = nextMode
        return nextMode
    }

    private func moveSelectedDot(
        with value: DragGesture.Value,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) {
        guard let canvasLocation = PuzzleCanvasCoordinate.canvasLocation(
            for: value.location,
            availableSize: availableSize,
            layout: layout,
            scale: viewportScale,
            offset: displayViewportOffset(
                layout: layout,
                availableSize: availableSize
            )
        ) else {
            return
        }
        onMoveSelectedDot?(
            PuzzleCanvasCoordinate.dotPosition(
                for: canvasLocation,
                extensionSide: extensionSide
            )
        )
    }

    private var selectedDotMagnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let delta = value.magnification / lastEditMagnification
                guard delta.isFinite, delta > 0 else { return }
                lastEditMagnification = value.magnification
                onScaleSelectedDot?(delta)
            }
            .onEnded { _ in
                lastEditMagnification = 1
                onCommitSelectedDotEdit?()
            }
    }

    private var selectedDotRotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                let delta = value - lastEditRotation
                lastEditRotation = value
                onRotateSelectedDot?(delta.degrees)
            }
            .onEnded { _ in
                lastEditRotation = .zero
                onCommitSelectedDotEdit?()
            }
    }

    private func dotID(
        at location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult
    ) -> UUID? {
        guard let unscaledLocation = PuzzleCanvasCoordinate.unscaledLocation(
            for: location,
            availableSize: availableSize,
            scale: viewportScale,
            offset: displayViewportOffset(
                layout: layout,
                availableSize: availableSize
            )
        ) else {
            return nil
        }

        let referenceLocation = CGPoint(
            x: unscaledLocation.x - layout.referenceComposedFrame.minX,
            y: unscaledLocation.y - layout.referenceComposedFrame.minY
        )

        return dots.reversed().first { dot in
            let centers = PuzzleCanvasCoordinate.dotCenters(for: dot.position, in: layout)
            return centers.contains { center in
                let displaySize = DotSizeControl.displaySize(
                    renderedScale: dot.resolvedRenderedScale(globalDotScale: dotScale) * dot.displaySizeScale,
                    photoFrameHeight: layout.dotReferenceHeight(forCenterIndex: 0)
                )
                return hypot(referenceLocation.x - center.x, referenceLocation.y - center.y) <= max(displaySize / 2, 22)
            }
        }?.id
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
                        offset: displayViewportOffset(
                            layout: layout,
                            availableSize: availableSize
                        )
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
                onTraceStrokeEnded?()
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
    @Binding var appliedKey: CanvasViewportResetKey?
    let layout: PuzzleCanvasLayoutResult
    let availableSize: CGSize
    let onReset: ((_ scale: CGFloat, _ offset: CGSize) -> Void)?

    @State private var awaitingLayoutReset = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                scheduleResetIfNeeded(for: key)
            }
            .onChange(of: key) { _, newKey in
                scheduleResetIfNeeded(for: newKey)
            }
            .onChange(of: availableSize) { _, _ in
                guard awaitingLayoutReset else { return }
                attemptReset()
            }
    }

    private func scheduleResetIfNeeded(for key: CanvasViewportResetKey) {
        guard key != appliedKey else { return }

        appliedKey = key
        awaitingLayoutReset = true
        attemptReset()
    }

    private func attemptReset() {
        guard awaitingLayoutReset else { return }
        performResetIfPossible()
    }

    private func performResetIfPossible() {
        guard availableSize.width > 0,
              availableSize.height > 0,
              layout.visibleComposedFrame.width > 0,
              layout.visibleComposedFrame.height > 0 else {
            return
        }

        let reset = PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: availableSize,
            bottomPanelInset: 0
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

private enum PuzzleCanvasActiveDragMode {
    case viewport
    case selectedDot
}

private struct DotEditingGestureModifier<Magnify: Gesture, Rotate: Gesture>: ViewModifier {
    let isEnabled: Bool
    let magnifyGesture: Magnify
    let rotateGesture: Rotate

    func body(content: Content) -> some View {
        content
            .highPriorityGesture(isEnabled ? magnifyGesture : nil)
            .highPriorityGesture(isEnabled ? rotateGesture : nil)
    }
}

private struct DotEditingSelectionOverlay: View {
    let dots: [PuzzleDot]
    let selectedDotID: UUID?
    let isDotEditingEnabled: Bool
    let dotScale: CGFloat
    let layout: PuzzleCanvasLayoutResult
    let onDelete: (() -> Void)?
    @GestureState private var isDeletePressing = false

    var body: some View {
        if isDotEditingEnabled,
           let selectedDot,
           let center = PuzzleCanvasCoordinate.dotCenters(for: selectedDot.position, in: layout).first {
            let size = DotSizeControl.displaySize(
                renderedScale: selectedDot.resolvedRenderedScale(globalDotScale: dotScale) * selectedDot.displaySizeScale,
                photoFrameHeight: layout.dotReferenceHeight(forCenterIndex: 0)
            )
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: max(size * 0.12, 8), style: .continuous)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(width: size + 12, height: size + 12)
                    .rotationEffect(.degrees(selectedDot.rotationDegrees))
                    .allowsHitTesting(false)

                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primaryForeground)
                    .frame(width: 24, height: 24)
                    .background(Color.primary, in: Circle())
                    .scaleEffect(isDeletePressing ? 0.88 : 1)
                    .contentShape(Circle())
                    .gesture(deleteGesture)
                    .offset(x: 24, y: -24)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("长按删除选中波点")
            }
            .position(center)
        }
    }

    private var deleteGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
            .updating($isDeletePressing) { currentValue, state, _ in
                state = currentValue
            }
            .onEnded { _ in
                onDelete?()
            }
    }

    private var selectedDot: PuzzleDot? {
        guard let selectedDotID else { return nil }
        return dots.first { $0.id == selectedDotID }
    }
}

private struct PuzzleGridCanvas: View {
    let photoFrameHeight: CGFloat
    let colors: PuzzleBackgroundColors
    let patternSpacing: Double

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            PuzzleBackgroundCanvasDrawing.fillBase(
                in: &context,
                size: size,
                fillColor: colors.fillColor
            )
            PuzzleBackgroundCanvasDrawing.strokeGrid(
                in: &context,
                size: size,
                photoFrameHeight: photoFrameHeight,
                patternSpacing: patternSpacing,
                lineColor: colors.lineColor
            )
        }
    }
}

private struct PuzzleStripesCanvas: View {
    let photoFrameHeight: CGFloat
    let colors: PuzzleBackgroundColors
    let patternSpacing: Double

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            PuzzleBackgroundCanvasDrawing.fillStripes(
                in: &context,
                size: size,
                photoFrameHeight: photoFrameHeight,
                patternSpacing: patternSpacing,
                colors: colors
            )
        }
    }
}

private struct PuzzlePolkaDotsCanvas: View {
    let photoFrameHeight: CGFloat
    let colors: PuzzleBackgroundColors
    let dotSize: Double

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            PuzzleBackgroundCanvasDrawing.fillPolkaDots(
                in: &context,
                size: size,
                photoFrameHeight: photoFrameHeight,
                dotSize: dotSize,
                colors: colors
            )
        }
    }
}

private enum PuzzleBackgroundCanvasDrawing {
    static func fillBase(
        in context: inout GraphicsContext,
        size: CGSize,
        fillColor: Color
    ) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(fillColor)
        )
    }

    static func strokeGrid(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        patternSpacing: Double,
        lineColor: Color
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
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

        stroke(path, in: &context, photoFrameHeight: photoFrameHeight, lineColor: lineColor)
    }

    static func fillStripes(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        patternSpacing: Double,
        colors: PuzzleBackgroundColors
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        var y: CGFloat = 0
        var usesPrimaryStripe = true

        while y < size.height {
            let bandHeight = min(spacing, size.height - y)
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: bandHeight)),
                with: .color(usesPrimaryStripe ? colors.fillColor : colors.alternateColor)
            )
            y += spacing
            usesPrimaryStripe.toggle()
        }
    }

    static func fillPolkaDots(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        dotSize: Double,
        colors: PuzzleBackgroundColors
    ) {
        fillBase(in: &context, size: size, fillColor: colors.fillColor)

        let dotRects = PuzzleBackgroundPolkaDotMetrics.dotRects(
            in: size,
            controlValue: dotSize,
            photoFrameHeight: photoFrameHeight
        )

        for rect in dotRects {
            context.fill(
                Path(ellipseIn: rect),
                with: .color(colors.lineColor)
            )
        }
    }

    private static func stroke(
        _ path: Path,
        in context: inout GraphicsContext,
        photoFrameHeight: CGFloat,
        lineColor: Color
    ) {
        context.stroke(
            path,
            with: .color(lineColor),
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
    let dotCharacterText: String
    var liveDotAnimation: LiveDotAnimation = .none
    var blinkTime: TimeInterval?
    /// 原图实况开启时的当前帧；用于扩展区和照片区拼贴波点的实况采样。
    var liveFrameImage: UIImage?
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    var centerIndexFilter: PuzzleDotCenterIndexFilter = .all

    var body: some View {
        dotsLayer(blinkTime: blinkTime)
            .allowsHitTesting(false)
            .animation(.none, value: dots.count)
    }

    @ViewBuilder
    private func dotsLayer(blinkTime: TimeInterval?) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                let centers = PuzzleCanvasCoordinate.dotCenters(for: dot.position, in: layout)
                let motion = DotMotionSample.sample(
                    dotID: dot.id,
                    liveDotAnimation: liveDotAnimation,
                    time: blinkTime
                )

                ForEach(Array(centers.enumerated()), id: \.offset) { centerIndex, center in
                    if centerIndexFilter.includes(centerIndex) {
                        let size = DotSizeControl.displaySize(
                            renderedScale: dot.resolvedRenderedScale(globalDotScale: dotScale) * dot.displaySizeScale,
                            photoFrameHeight: layout.dotReferenceHeight(forCenterIndex: centerIndex)
                        )
                        let rotation = Angle.degrees(dot.rotationDegrees)
                            + Angle.radians(motion.rotationRadians)
                        Color.clear
                            .frame(width: size, height: size)
                            .overlay {
                                dotImage(for: dot, centerIndex: centerIndex, size: size)
                                    .frame(width: size, height: size, alignment: .topLeading)
                                    .clipped()
                            }
                            .scaleEffect(CGFloat(motion.scale))
                            .rotationEffect(rotation)
                            .opacity(motion.opacity)
                            .position(center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dotImage(for dot: PuzzleDot, centerIndex: Int, size: CGFloat) -> some View {
        if dot.isCharacterDot {
            if PuzzleDotCollageColor.shouldRenderCollageContent(
                for: dot,
                usesRandomDotColors: usesRandomDotColors,
                extensionRatio: layout.extensionRatio,
                selectedDotColor: dotColor
            ) {
                PuzzleDotCollageCharacterShapeView(
                    text: dotCharacterText,
                    centerIndex: centerIndex,
                    dot: dot,
                    image: image,
                    liveFrameImage: liveFrameImage,
                    backgroundStyle: backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
                    photoFrame: photoFrame,
                    layout: layout,
                    dotSize: size
                )
            } else {
                CharacterDotGlyphView(
                    text: dotCharacterText,
                    color: dot.displayColor(
                        usesRandomColor: usesRandomDotColors,
                        selectedColor: dotColor
                    )
                )
            }
        } else if let builtInShape = dot.builtInShape {
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
                    liveFrameImage: liveFrameImage,
                    backgroundStyle: backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
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
                liveFrameImage: liveFrameImage,
                backgroundStyle: backgroundStyle,
                backgroundColors: backgroundColors,
                backgroundPatternSpacing: backgroundPatternSpacing,
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
                assetName: "public/\(dot.resolvedShapeAssetName)",
                renderingMode: dot.usesTemplateColor ? .template : .original,
                tintColor: dot.usesTemplateColor ? stickerColor : nil,
                prefersCrispScaling: DotShapeAssetCategoryParser.prefersCrispScaling(for: dot.resolvedShapeAssetName)
            )
        }
    }
}

private enum PuzzleDotCenterIndexFilter {
    case all
    case photo
    case background

    func includes(_ centerIndex: Int) -> Bool {
        switch self {
        case .all:
            return true
        case .photo:
            return centerIndex == 0
        case .background:
            return centerIndex != 0
        }
    }
}

private struct PuzzleDotCollageCharacterShapeView: View {
    let text: String
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    /// 原图实况开启时的当前帧；nil 表示用静态 `image`。
    let liveFrameImage: UIImage?
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        PuzzleDotCollageMirrorFill(
            centerIndex: centerIndex,
            dot: dot,
            image: image,
            liveFrameImage: liveFrameImage,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            photoFrame: photoFrame,
            layout: layout,
            dotSize: dotSize
        )
        .mask {
            CharacterDotGlyphView(text: text, color: .white)
        }
    }
}

private struct PuzzleDotCollageBasicShapeView: View {
    let shape: BuiltInDotShape
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    /// 原图实况开启时的当前帧；nil 表示用静态 `image`。
    let liveFrameImage: UIImage?
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        PuzzleDotCollageMirrorFill(
            centerIndex: centerIndex,
            dot: dot,
            image: image,
            liveFrameImage: liveFrameImage,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
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
    /// 原图实况开启时的当前帧；nil 表示用静态 `image`。
    let liveFrameImage: UIImage?
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    var body: some View {
        PuzzleDotCollageMirrorFill(
            centerIndex: centerIndex,
            dot: dot,
            image: image,
            liveFrameImage: liveFrameImage,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            photoFrame: photoFrame,
            layout: layout,
            dotSize: dotSize
        )
        .mask {
            DotShapeAssetImageView(
                assetName: "public/\(dot.resolvedShapeAssetName)",
                renderingMode: .template,
                tintColor: .white,
                prefersCrispScaling: DotShapeAssetCategoryParser.prefersCrispScaling(for: dot.resolvedShapeAssetName)
            )
        }
    }
}

private struct PuzzleDotCollageMirrorFill: View {
    let centerIndex: Int
    let dot: PuzzleDot
    let image: UIImage
    /// 原图实况开启时的当前帧；nil 表示用静态 `image`。
    let liveFrameImage: UIImage?
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let photoFrame: CGRect
    let layout: PuzzleCanvasLayoutResult
    let dotSize: CGFloat

    /// 用于采样的有效帧图像：实况帧优先，否则退回静态原图。
    private var effectiveImage: UIImage { liveFrameImage ?? image }

    var body: some View {
        let extensionFrame = layout.referenceLocalExtensionGridFrame

        if centerIndex == 0 {
            // 主图区：显示背景样式内容（背景本身静止，不受实况影响）。
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
                sourceImage: image,
                layout: layout,
                style: backgroundStyle,
                colors: backgroundColors,
                patternSpacing: backgroundPatternSpacing,
                extensionSize: extensionFrame.size,
                photoFrameHeight: layout.backgroundPatternReferenceHeight
            )
            .frame(width: extensionFrame.width, height: extensionFrame.height, alignment: .topLeading)
            .offset(x: offset.width, y: offset.height)
            .frame(width: dotSize, height: dotSize, alignment: .topLeading)
            .clipped()
        } else {
            // 扩展区：显示照片内容；原图实况开启时用当前实况帧。
            let offset = PuzzleDotCollageColor.contentOffsetInDot(
                dotSize: dotSize,
                normalizedPoint: dot.position,
                contentSize: photoFrame.size
            )

            Image(uiImage: effectiveImage)
                .resizable()
                .frame(width: photoFrame.width, height: photoFrame.height, alignment: .topLeading)
                .offset(x: offset.width, y: offset.height)
                .frame(width: dotSize, height: dotSize, alignment: .topLeading)
                .clipped()
        }
    }
}

private struct PuzzleDotCollageBackgroundFill: View {
    let sourceImage: UIImage
    let layout: PuzzleCanvasLayoutResult
    let style: PuzzleBackgroundStyle
    let colors: PuzzleBackgroundColors
    let patternSpacing: Double
    let extensionSize: CGSize
    let photoFrameHeight: CGFloat

    var body: some View {
        Group {
            switch style {
            case .solid:
                Color(colors.fillColor)
            case .grid:
                Canvas { context, _ in
                    PuzzleBackgroundCanvasDrawing.fillBase(
                        in: &context,
                        size: extensionSize,
                        fillColor: colors.fillColor
                    )
                    PuzzleBackgroundCanvasDrawing.strokeGrid(
                        in: &context,
                        size: extensionSize,
                        photoFrameHeight: photoFrameHeight,
                        patternSpacing: patternSpacing,
                        lineColor: colors.lineColor
                    )
                }
            case .stripes:
                Canvas { context, _ in
                    PuzzleBackgroundCanvasDrawing.fillStripes(
                        in: &context,
                        size: extensionSize,
                        photoFrameHeight: photoFrameHeight,
                        patternSpacing: patternSpacing,
                        colors: colors
                    )
                }
            case .polkaDots:
                Canvas { context, _ in
                    PuzzleBackgroundCanvasDrawing.fillPolkaDots(
                        in: &context,
                        size: extensionSize,
                        photoFrameHeight: photoFrameHeight,
                        dotSize: patternSpacing,
                        colors: colors
                    )
                }
            case .halftone:
                PuzzleHalftoneBackgroundView(
                    sourceImage: sourceImage,
                    extensionRatio: PuzzleCanvasLayout.maxExtensionRatio,
                    extensionSide: layout.extensionSide,
                    displaySize: extensionSize,
                    backgroundColor: colors.fillColor,
                    dotColor: colors.lineColor
                )
            }
        }
        .frame(width: extensionSize.width, height: extensionSize.height)
    }
}

private struct PuzzleTraceCanvas: View {
    let tracePoints: [PuzzleCanvasTracePoint]
    let layout: PuzzleCanvasLayoutResult

    var body: some View {
        Canvas { context, _ in
            let displayPoints: [PuzzleTraceDisplayPoint] = tracePoints.compactMap { tracePoint in
                guard let point = PuzzleCanvasCoordinate.composedCanvasPoint(
                    for: tracePoint,
                    in: layout
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
