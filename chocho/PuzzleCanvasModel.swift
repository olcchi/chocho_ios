import CoreGraphics
import SwiftUI

enum PuzzleCanvasExtensionSide: String, CaseIterable, Identifiable, Equatable {
    case top
    case bottom
    case left
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .top:
            "在上"
        case .bottom:
            "在下"
        case .left:
            "在左"
        case .right:
            "在右"
        }
    }

    var isHorizontal: Bool {
        switch self {
        case .left, .right:
            true
        case .top, .bottom:
            false
        }
    }
}

struct PuzzleCanvasLayoutResult: Equatable {
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let photoFrame: CGRect
    let extensionFrame: CGRect
    let composedSize: CGSize
    /// Full photo + max extension area; dot/trace positions are stable in this space.
    let referenceComposedFrame: CGRect
    /// Photo bounds inside the reference-local coordinate space.
    let referenceLocalPhotoFrame: CGRect
    /// Extension grid bounds inside the reference-local coordinate space.
    let referenceLocalExtensionGridFrame: CGRect

    var visibleComposedFrame: CGRect {
        switch extensionSide {
        case .right:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.minY,
                width: composedSize.width,
                height: referenceComposedFrame.height
            )
        case .left:
            CGRect(
                x: referenceComposedFrame.maxX - composedSize.width,
                y: referenceComposedFrame.minY,
                width: composedSize.width,
                height: referenceComposedFrame.height
            )
        case .bottom:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.minY,
                width: referenceComposedFrame.width,
                height: composedSize.height
            )
        case .top:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.maxY - composedSize.height,
                width: referenceComposedFrame.width,
                height: composedSize.height
            )
        }
    }

    var visibleComposedClipAlignment: Alignment {
        switch extensionSide {
        case .right:
            .topLeading
        case .left:
            .topTrailing
        case .bottom:
            .topLeading
        case .top:
            .bottomLeading
        }
    }

    var visibleComposedClipPosition: CGPoint {
        let frame = visibleComposedFrame
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

enum PuzzleCanvasSide: Equatable {
    case photo
    case background
}

struct PuzzleCanvasTracePoint: Equatable {
    let side: PuzzleCanvasSide
    let point: CGPoint
    let startsNewStroke: Bool

    init(
        side: PuzzleCanvasSide,
        point: CGPoint,
        startsNewStroke: Bool = false
    ) {
        self.side = side
        self.point = point
        self.startsNewStroke = startsNewStroke
    }
}

enum PuzzleCanvasDragMode: Equatable {
    case viewport
    case trace

    static func current(isTraceDrawingEnabled: Bool) -> PuzzleCanvasDragMode {
        isTraceDrawingEnabled ? .trace : .viewport
    }
}

struct PuzzleCanvasTraceSegment: Equatable {
    let start: CGPoint
    let end: CGPoint

    var length: CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }
}

enum PuzzleCanvasTracePath {
    static func segments(
        from tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat
    ) -> [PuzzleCanvasTraceSegment] {
        var segments: [PuzzleCanvasTraceSegment] = []
        var previousTracePoint: PuzzleCanvasTracePoint?

        for tracePoint in tracePoints {
            if tracePoint.startsNewStroke {
                previousTracePoint = tracePoint
                continue
            }

            if let previousTracePoint,
               previousTracePoint.side == tracePoint.side {
                let segment = PuzzleCanvasTraceSegment(
                    start: previousTracePoint.point,
                    end: tracePoint.point
                )

                if segment.length > 0 {
                    segments.append(segment)
                }
            }

            previousTracePoint = tracePoint
        }

        return segments
    }
}

enum PuzzleCanvasLayout {
    static let maxExtensionRatio: CGFloat = 1

    static func layout(
        imageSize: CGSize,
        availableSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide = .right
    ) -> PuzzleCanvasLayoutResult {
        let clampedRatio = min(max(extensionRatio, 0), maxExtensionRatio)

        guard imageSize.width > 0,
              imageSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return PuzzleCanvasLayoutResult(
                extensionRatio: clampedRatio,
                extensionSide: extensionSide,
                photoFrame: .zero,
                extensionFrame: .zero,
                composedSize: .zero,
                referenceComposedFrame: .zero,
                referenceLocalPhotoFrame: .zero,
                referenceLocalExtensionGridFrame: .zero
            )
        }

        // Photo scale is independent of extension width so existing dots stay fixed on the image.
        let fitScale = min(
            availableSize.width / imageSize.width,
            availableSize.height / imageSize.height
        )
        let photoSize = CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
        let photoOrigin = CGPoint(
            x: (availableSize.width - photoSize.width) / 2,
            y: (availableSize.height - photoSize.height) / 2
        )
        let visibleExtensionLength = extensionSide.isHorizontal
            ? photoSize.width * clampedRatio
            : photoSize.height * clampedRatio
        let maxExtensionLength = extensionSide.isHorizontal
            ? photoSize.width * maxExtensionRatio
            : photoSize.height * maxExtensionRatio
        let referenceComposedSize = extensionSide.isHorizontal
            ? CGSize(
                width: photoSize.width + maxExtensionLength,
                height: photoSize.height
            )
            : CGSize(
                width: photoSize.width,
                height: photoSize.height + maxExtensionLength
            )
        let referenceOrigin = CGPoint(
            x: extensionSide == .left ? photoOrigin.x - maxExtensionLength : photoOrigin.x,
            y: extensionSide == .top ? photoOrigin.y - maxExtensionLength : photoOrigin.y
        )
        let referenceComposedFrame = CGRect(
            origin: referenceOrigin,
            size: referenceComposedSize
        )
        let referenceLocalPhotoFrame = CGRect(
            origin: CGPoint(
                x: extensionSide == .left ? maxExtensionLength : 0,
                y: extensionSide == .top ? maxExtensionLength : 0
            ),
            size: photoSize
        )
        let referenceLocalExtensionGridFrame = CGRect(
            origin: CGPoint(
                x: extensionSide == .right ? photoSize.width : 0,
                y: extensionSide == .bottom ? photoSize.height : 0
            ),
            size: CGSize(
                width: extensionSide.isHorizontal ? maxExtensionLength : photoSize.width,
                height: extensionSide.isHorizontal ? photoSize.height : maxExtensionLength
            )
        )
        let extensionFrame = extensionFrameInScreenSpace(
            photoOrigin: photoOrigin,
            photoSize: photoSize,
            visibleExtensionLength: visibleExtensionLength,
            extensionSide: extensionSide
        )
        let composedSize = extensionSide.isHorizontal
            ? CGSize(width: photoSize.width + visibleExtensionLength, height: photoSize.height)
            : CGSize(width: photoSize.width, height: photoSize.height + visibleExtensionLength)

        return PuzzleCanvasLayoutResult(
            extensionRatio: clampedRatio,
            extensionSide: extensionSide,
            photoFrame: CGRect(origin: photoOrigin, size: photoSize),
            extensionFrame: extensionFrame,
            composedSize: composedSize,
            referenceComposedFrame: referenceComposedFrame,
            referenceLocalPhotoFrame: referenceLocalPhotoFrame,
            referenceLocalExtensionGridFrame: referenceLocalExtensionGridFrame
        )
    }

    private static func extensionFrameInScreenSpace(
        photoOrigin: CGPoint,
        photoSize: CGSize,
        visibleExtensionLength: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGRect {
        switch extensionSide {
        case .right:
            CGRect(
                x: photoOrigin.x + photoSize.width,
                y: photoOrigin.y,
                width: visibleExtensionLength,
                height: photoSize.height
            )
        case .left:
            CGRect(
                x: photoOrigin.x - visibleExtensionLength,
                y: photoOrigin.y,
                width: visibleExtensionLength,
                height: photoSize.height
            )
        case .bottom:
            CGRect(
                x: photoOrigin.x,
                y: photoOrigin.y + photoSize.height,
                width: photoSize.width,
                height: visibleExtensionLength
            )
        case .top:
            CGRect(
                x: photoOrigin.x,
                y: photoOrigin.y - visibleExtensionLength,
                width: photoSize.width,
                height: visibleExtensionLength
            )
        }
    }
}

struct CanvasViewportResetKey: Equatable {
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let availableSize: CGSize
    let imageSize: CGSize
}

enum PuzzleCanvasViewport {
    /// Fits the visible photo + background width to the screen edges and centers vertically.
    /// Matches `PuzzleCanvasCoordinate` viewport transform: scale about available center, then offset.
    static func resetTransform(
        layout: PuzzleCanvasLayoutResult,
        availableSize: CGSize
    ) -> (scale: CGFloat, offset: CGSize) {
        let visibleFrame = layout.visibleComposedFrame

        guard visibleFrame.width > 0,
              visibleFrame.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return (1, .zero)
        }

        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )
        let scale = availableSize.width / visibleFrame.width
        let offset = CGSize(
            width: -viewportCenter.x - (visibleFrame.minX - viewportCenter.x) * scale,
            height: availableSize.height / 2
                - viewportCenter.y
                - (visibleFrame.midY - viewportCenter.y) * scale
        )

        return (scale, offset)
    }
}

enum PuzzleCanvasCoordinate {
    static func isBackgroundTap(
        at location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> Bool {
        normalizedPoint(
            for: location,
            availableSize: availableSize,
            layout: layout,
            scale: scale,
            offset: offset
        ) == nil
    }

    static func canvasLocation(
        for location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> PuzzleCanvasTracePoint? {
        guard let unscaledLocation = unscaledLocation(
            for: location,
            availableSize: availableSize,
            scale: scale,
            offset: offset
        ) else {
            return nil
        }

        if layout.photoFrame.contains(unscaledLocation),
           layout.photoFrame.width > 0,
           layout.photoFrame.height > 0 {
            return PuzzleCanvasTracePoint(
                side: .photo,
                point: CGPoint(
                    x: (unscaledLocation.x - layout.photoFrame.minX) / layout.photoFrame.width,
                    y: (unscaledLocation.y - layout.photoFrame.minY) / layout.photoFrame.height
                )
            )
        }

        if layout.extensionFrame.contains(unscaledLocation),
           layout.extensionFrame.width > 0,
           layout.extensionFrame.height > 0,
           layout.photoFrame.width > 0,
           layout.photoFrame.height > 0 {
            return PuzzleCanvasTracePoint(
                side: .background,
                point: backgroundLocalPoint(
                    unscaledLocation: unscaledLocation,
                    layout: layout
                )
            )
        }

        return nil
    }

    /// Background-local coordinates match the right-side baseline: 0 on the edge that touches the photo,
    /// increasing away from the photo (right / left / down / up depending on `extensionSide`).
    static func backgroundLocalPoint(
        unscaledLocation: CGPoint,
        layout: PuzzleCanvasLayoutResult
    ) -> CGPoint {
        let extensionFrame = layout.extensionFrame
        let photoFrame = layout.photoFrame

        switch layout.extensionSide {
        case .right:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .left:
            return CGPoint(
                x: (extensionFrame.maxX - unscaledLocation.x) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .bottom:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .top:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (extensionFrame.maxY - unscaledLocation.y) / photoFrame.height
            )
        }
    }

    static func normalizedPoint(
        for location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint? {
        guard scale > 0,
              availableSize.width > 0,
              availableSize.height > 0,
              layout.composedSize.width > 0,
              layout.composedSize.height > 0 else {
            return nil
        }

        guard let unscaledLocation = unscaledLocation(
            for: location,
            availableSize: availableSize,
            scale: scale,
            offset: offset
        ) else {
            return nil
        }
        let visibleFrame = layout.visibleComposedFrame

        guard visibleFrame.contains(unscaledLocation) else { return nil }

        let referenceFrame = layout.referenceComposedFrame
        guard referenceFrame.width > 0, referenceFrame.height > 0 else { return nil }

        return CGPoint(
            x: (unscaledLocation.x - referenceFrame.minX) / referenceFrame.width,
            y: (unscaledLocation.y - referenceFrame.minY) / referenceFrame.height
        )
    }

    static func composedPosition(
        for tracePoint: PuzzleCanvasTracePoint,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio
    ) -> CGPoint? {
        let clampedRatio = min(max(maxExtensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        let photoSpan = 1 / (1 + clampedRatio)
        let extensionSpan = clampedRatio / (1 + clampedRatio)

        switch tracePoint.side {
        case .photo:
            switch extensionSide {
            case .right:
                return CGPoint(
                    x: tracePoint.point.x * photoSpan,
                    y: tracePoint.point.y
                )
            case .left:
                return CGPoint(
                    x: extensionSpan + tracePoint.point.x * photoSpan,
                    y: tracePoint.point.y
                )
            case .bottom:
                return CGPoint(
                    x: tracePoint.point.x,
                    y: tracePoint.point.y * photoSpan
                )
            case .top:
                return CGPoint(
                    x: tracePoint.point.x,
                    y: extensionSpan + tracePoint.point.y * photoSpan
                )
            }
        case .background:
            guard clampedRatio > 0 else { return nil }

            switch extensionSide {
            case .right:
                guard tracePoint.point.x >= 0, tracePoint.point.x <= clampedRatio else { return nil }
                return CGPoint(
                    x: photoSpan + tracePoint.point.x / (1 + clampedRatio),
                    y: tracePoint.point.y
                )
            case .left:
                guard tracePoint.point.x >= 0, tracePoint.point.x <= clampedRatio else { return nil }
                return CGPoint(
                    x: extensionSpan - tracePoint.point.x / (1 + clampedRatio),
                    y: tracePoint.point.y
                )
            case .bottom:
                guard tracePoint.point.y >= 0, tracePoint.point.y <= clampedRatio else { return nil }
                return CGPoint(
                    x: tracePoint.point.x,
                    y: photoSpan + tracePoint.point.y / (1 + clampedRatio)
                )
            case .top:
                guard tracePoint.point.y >= 0, tracePoint.point.y <= clampedRatio else { return nil }
                return CGPoint(
                    x: tracePoint.point.x,
                    y: extensionSpan - tracePoint.point.y / (1 + clampedRatio)
                )
            }
        }
    }

    /// Renders dots in the fixed reference canvas; narrowing extension only clips them.
    static func dotCentersInReferenceFrame(
        position: CGPoint,
        referenceFrame: CGRect,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio,
        radius: CGFloat
    ) -> [CGPoint] {
        let clampedMaxRatio = min(max(maxExtensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        guard referenceFrame.width > 0, referenceFrame.height > 0 else { return [] }

        let photoSpan = 1 / (1 + clampedMaxRatio)
        let extensionSpan = clampedMaxRatio / (1 + clampedMaxRatio)
        let photoFrame: CGRect
        let mirrorFrame: CGRect
        let mirrorPosition: CGPoint

        switch extensionSide {
        case .right:
            let photoWidth = referenceFrame.width * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: photoWidth,
                height: referenceFrame.height
            )
            mirrorFrame = CGRect(
                x: photoFrame.maxX,
                y: photoFrame.minY,
                width: referenceFrame.width * extensionSpan,
                height: referenceFrame.height
            )
            mirrorPosition = CGPoint(
                x: position.x / max(clampedMaxRatio, .leastNonzeroMagnitude),
                y: position.y
            )
        case .left:
            let photoWidth = referenceFrame.width * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX + referenceFrame.width * extensionSpan,
                y: referenceFrame.minY,
                width: photoWidth,
                height: referenceFrame.height
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width * extensionSpan,
                height: referenceFrame.height
            )
            mirrorPosition = CGPoint(
                x: position.x / max(clampedMaxRatio, .leastNonzeroMagnitude),
                y: position.y
            )
        case .bottom:
            let photoHeight = referenceFrame.height * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width,
                height: photoHeight
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: photoFrame.maxY,
                width: referenceFrame.width,
                height: referenceFrame.height * extensionSpan
            )
            mirrorPosition = CGPoint(
                x: position.x,
                y: position.y / max(clampedMaxRatio, .leastNonzeroMagnitude)
            )
        case .top:
            let photoHeight = referenceFrame.height * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY + referenceFrame.height * extensionSpan,
                width: referenceFrame.width,
                height: photoHeight
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width,
                height: referenceFrame.height * extensionSpan
            )
            mirrorPosition = CGPoint(
                x: position.x,
                y: position.y / max(clampedMaxRatio, .leastNonzeroMagnitude)
            )
        }

        var centers = [
            clampedDotCenter(
                position: position,
                in: photoFrame,
                radius: radius
            )
        ]

        guard clampedMaxRatio > 0 else { return centers }

        centers.append(
            clampedDotCenter(
                position: mirrorPosition,
                in: mirrorFrame,
                radius: radius
            )
        )

        return centers
    }

    static func composedCanvasPoint(
        for tracePoint: PuzzleCanvasTracePoint,
        canvasSize: CGSize,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio
    ) -> CGPoint? {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              let position = composedPosition(
                for: tracePoint,
                extensionSide: extensionSide,
                maxExtensionRatio: maxExtensionRatio
              ) else {
            return nil
        }

        return CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )
    }

    static func clampedDotCenter(
        position: CGPoint,
        in composedFrame: CGRect,
        radius: CGFloat
    ) -> CGPoint {
        let insetFrame = composedFrame.insetBy(dx: radius, dy: radius)
        let center = CGPoint(
            x: composedFrame.minX + position.x * composedFrame.width,
            y: composedFrame.minY + position.y * composedFrame.height
        )

        guard insetFrame.width >= 0, insetFrame.height >= 0 else {
            return CGPoint(x: composedFrame.midX, y: composedFrame.midY)
        }

        return CGPoint(
            x: min(max(center.x, insetFrame.minX), insetFrame.maxX),
            y: min(max(center.y, insetFrame.minY), insetFrame.maxY)
        )
    }

    private static func unscaledLocation(
        for location: CGPoint,
        availableSize: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint? {
        guard scale > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return nil
        }

        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )

        return CGPoint(
            x: viewportCenter.x + (location.x - offset.width - viewportCenter.x) / scale,
            y: viewportCenter.y + (location.y - offset.height - viewportCenter.y) / scale
        )
    }
}

enum DotSizeControl {
    static let minControlValue: Double = 1
    static let maxControlValue: Double = 100
    static let minRenderedScale: Double = 24
    static let maxRenderedScale: Double = 96
    static let defaultControlValue: Double = 23
    static let defaultRenderedScale = renderedScale(forControlValue: defaultControlValue)
    /// Matches a typical on-screen photo height so slider values stay intuitive.
    static let referencePhotoHeight: CGFloat = 240

    static func displaySize(renderedScale: CGFloat, photoFrameHeight: CGFloat) -> CGFloat {
        guard referencePhotoHeight > 0, photoFrameHeight > 0 else {
            return renderedScale
        }

        return renderedScale * (photoFrameHeight / referencePhotoHeight)
    }

    static func renderedScale(forControlValue value: Double) -> Double {
        let clampedValue = min(max(value, minControlValue), maxControlValue)
        let progress = (clampedValue - minControlValue) / (maxControlValue - minControlValue)

        return minRenderedScale + progress * (maxRenderedScale - minRenderedScale)
    }

    static func controlValue(forRenderedScale scale: Double) -> Double {
        let clampedScale = min(max(scale, minRenderedScale), maxRenderedScale)
        let progress = (clampedScale - minRenderedScale) / (maxRenderedScale - minRenderedScale)

        return minControlValue + progress * (maxControlValue - minControlValue)
    }
}

enum PuzzleCanvasUploadDefaults {
    static func initialDots(
        dotCount: Double,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        PuzzleDotFactory.makeDots(
            count: Int(dotCount.rounded()),
            shapeAssetName: shapeAssetName
        )
    }
}

struct CanvasHistory<Value: Equatable> {
    private(set) var currentValue: Value
    private var undoStack: [Value] = []
    private var redoStack: [Value] = []

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    init(initialValue: Value) {
        currentValue = initialValue
    }

    mutating func reset(to value: Value) {
        currentValue = value
        undoStack = []
        redoStack = []
    }

    mutating func record(_ value: Value) {
        guard value != currentValue else { return }

        undoStack.append(currentValue)
        currentValue = value
        redoStack = []
    }

    mutating func undo() -> Value? {
        guard let previousValue = undoStack.popLast() else { return nil }

        redoStack.append(currentValue)
        currentValue = previousValue
        return previousValue
    }

    mutating func redo() -> Value? {
        guard let nextValue = redoStack.popLast() else { return nil }

        undoStack.append(currentValue)
        currentValue = nextValue
        return nextValue
    }
}

extension CanvasHistory where Value: RangeReplaceableCollection {
    mutating func clearValue() -> Value {
        record(Value())
        return currentValue
    }
}

struct PuzzleDot: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let color: Color
    let size: CGFloat
    let shapeAssetName: String

    var usesTemplateColor: Bool {
        !shapeAssetName.contains(".")
    }

    var builtInShape: BuiltInDotShape? {
        BuiltInDotShape(rawValue: shapeAssetName)
    }

    func displayColor(usesRandomColor: Bool, selectedColor: Color) -> Color {
        usesRandomColor ? color : selectedColor
    }
}

enum PuzzleDotFactory {
    private static let unitSize: CGFloat = 1
    static let randomColorPaletteHexStrings = [
        "#FF9EEA",
        "#A8F7FF",
        "#FFF38A",
        "#B7FF9D",
        "#CDB4FF",
        "#FFB86B"
    ]

    static var randomColorPalette: [Color] {
        [
            Color(.sRGB, red: 1.00, green: 0.62, blue: 0.92, opacity: 1),
            Color(.sRGB, red: 0.66, green: 0.97, blue: 1.00, opacity: 1),
            Color(.sRGB, red: 1.00, green: 0.95, blue: 0.54, opacity: 1),
            Color(.sRGB, red: 0.72, green: 1.00, blue: 0.62, opacity: 1),
            Color(.sRGB, red: 0.80, green: 0.71, blue: 1.00, opacity: 1),
            Color(.sRGB, red: 1.00, green: 0.72, blue: 0.42, opacity: 1)
        ]
    }

    static func makeDot(
        position: CGPoint,
        index: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> PuzzleDot {
        return PuzzleDot(
            id: UUID(),
            position: CGPoint(
                x: min(max(position.x, 0), 1),
                y: min(max(position.y, 0), 1)
            ),
            color: randomColorPalette[max(index, 0) % randomColorPalette.count],
            size: unitSize,
            shapeAssetName: shapeAssetName
        )
    }

    static func makeDots(
        count: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        return (0..<max(count, 0)).map { index in
            makeDot(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }
    }

    static func makeDots(
        count: Int,
        along tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        var generator = SystemRandomNumberGenerator()

        return makeDots(
            count: count,
            along: tracePoints,
            extensionRatio: extensionRatio,
            shapeAssetName: shapeAssetName,
            using: &generator
        )
    }

    static func makeDots<Generator: RandomNumberGenerator>(
        count: Int,
        along tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name,
        using generator: inout Generator
    ) -> [PuzzleDot] {
        let segments = PuzzleCanvasTracePath.segments(
            from: tracePoints,
            extensionRatio: extensionRatio
        )
        let positions = tracePoints.map(\.point)
        let normalizedCount = max(count, 0)

        guard normalizedCount > 0, !positions.isEmpty else { return [] }

        return (0..<normalizedCount).map { index in
            return makeDot(
                position: randomPosition(
                    along: segments,
                    fallbackPositions: positions,
                    dotIndex: index,
                    dotCount: normalizedCount,
                    using: &generator
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }
    }

    static func adjusting(
        _ dots: [PuzzleDot],
        toCount count: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        let normalizedCount = max(count, 0)

        if dots.count > normalizedCount {
            return Array(dots.prefix(normalizedCount))
        }

        guard dots.count < normalizedCount else { return dots }

        let newDots = (dots.count..<normalizedCount).map { index in
            makeDot(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }

        return dots + newDots
    }

    private static func randomPosition<Generator: RandomNumberGenerator>(
        along segments: [PuzzleCanvasTraceSegment],
        fallbackPositions: [CGPoint],
        dotIndex: Int,
        dotCount: Int,
        using generator: inout Generator
    ) -> CGPoint {
        let totalLength = segments.reduce(CGFloat.zero) { $0 + $1.length }

        guard totalLength > 0, dotCount > 0 else {
            return fallbackPositions.randomElement(using: &generator) ?? .zero
        }

        let bucketLength = totalLength / CGFloat(dotCount)
        let distance = min(
            totalLength,
            CGFloat(dotIndex) * bucketLength + CGFloat.random(in: 0...bucketLength, using: &generator)
        )

        return position(at: distance, along: segments) ?? segments.last?.end ?? .zero
    }

    private static func position(
        at distance: CGFloat,
        along segments: [PuzzleCanvasTraceSegment]
    ) -> CGPoint? {
        var remainingDistance = distance

        for segment in segments {
            let segmentLength = segment.length

            guard segmentLength > 0 else { continue }

            if remainingDistance <= segmentLength {
                let progress = remainingDistance / segmentLength

                return CGPoint(
                    x: segment.start.x + (segment.end.x - segment.start.x) * progress,
                    y: segment.start.y + (segment.end.y - segment.start.y) * progress
                )
            }

            remainingDistance -= segmentLength
        }

        return segments.last?.end
    }
}
