import CoreGraphics
import SwiftUI

struct PuzzleCanvasLayoutResult: Equatable {
    let extensionRatio: CGFloat
    let photoFrame: CGRect
    let extensionFrame: CGRect
    let composedSize: CGSize
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
        var previousPosition: CGPoint?

        for tracePoint in tracePoints {
            guard let position = PuzzleCanvasCoordinate.composedPosition(
                for: tracePoint,
                extensionRatio: extensionRatio
            ) else {
                previousPosition = nil
                continue
            }

            if tracePoint.startsNewStroke {
                previousPosition = position
                continue
            }

            if let previousPosition {
                let segment = PuzzleCanvasTraceSegment(
                    start: previousPosition,
                    end: position
                )

                if segment.length > 0 {
                    segments.append(segment)
                }
            }

            previousPosition = position
        }

        return segments
    }
}

enum PuzzleCanvasLayout {
    static func layout(
        imageSize: CGSize,
        availableSize: CGSize,
        extensionRatio: CGFloat
    ) -> PuzzleCanvasLayoutResult {
        let clampedRatio = min(max(extensionRatio, 0), 1)

        guard imageSize.width > 0,
              imageSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return PuzzleCanvasLayoutResult(
                extensionRatio: clampedRatio,
                photoFrame: .zero,
                extensionFrame: .zero,
                composedSize: .zero
            )
        }

        let fitScale = min(
            availableSize.width / (imageSize.width * (1 + clampedRatio)),
            availableSize.height / imageSize.height
        )
        let photoSize = CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
        let extensionSize = CGSize(
            width: photoSize.width * clampedRatio,
            height: photoSize.height
        )
        let composedSize = CGSize(
            width: photoSize.width + extensionSize.width,
            height: photoSize.height
        )
        let origin = CGPoint(
            x: (availableSize.width - composedSize.width) / 2,
            y: (availableSize.height - composedSize.height) / 2
        )

        return PuzzleCanvasLayoutResult(
            extensionRatio: clampedRatio,
            photoFrame: CGRect(origin: origin, size: photoSize),
            extensionFrame: CGRect(
                x: origin.x + photoSize.width,
                y: origin.y,
                width: extensionSize.width,
                height: extensionSize.height
            ),
            composedSize: composedSize
        )
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
           layout.extensionFrame.height > 0 {
            return PuzzleCanvasTracePoint(
                side: .background,
                point: CGPoint(
                    x: (unscaledLocation.x - layout.extensionFrame.minX) / layout.extensionFrame.width,
                    y: (unscaledLocation.y - layout.extensionFrame.minY) / layout.extensionFrame.height
                )
            )
        }

        return nil
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
        let composedFrame = CGRect(
            x: layout.photoFrame.minX,
            y: layout.photoFrame.minY,
            width: layout.composedSize.width,
            height: layout.composedSize.height
        )

        guard composedFrame.contains(unscaledLocation) else { return nil }

        return CGPoint(
            x: (unscaledLocation.x - composedFrame.minX) / composedFrame.width,
            y: (unscaledLocation.y - composedFrame.minY) / composedFrame.height
        )
    }

    static func composedPosition(
        for tracePoint: PuzzleCanvasTracePoint,
        extensionRatio: CGFloat
    ) -> CGPoint? {
        let clampedRatio = min(max(extensionRatio, 0), 1)
        let photoWidthFraction = 1 / (1 + clampedRatio)
        let backgroundWidthFraction = clampedRatio / (1 + clampedRatio)

        switch tracePoint.side {
        case .photo:
            return CGPoint(
                x: tracePoint.point.x * photoWidthFraction,
                y: tracePoint.point.y
            )
        case .background:
            guard backgroundWidthFraction > 0 else { return nil }

            return CGPoint(
                x: photoWidthFraction + tracePoint.point.x * backgroundWidthFraction,
                y: tracePoint.point.y
            )
        }
    }

    static func composedCanvasPoint(
        for tracePoint: PuzzleCanvasTracePoint,
        extensionRatio: CGFloat,
        canvasSize: CGSize
    ) -> CGPoint? {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              let position = composedPosition(
                for: tracePoint,
                extensionRatio: extensionRatio
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
        let positions = tracePoints.compactMap {
            PuzzleCanvasCoordinate.composedPosition(
                for: $0,
                extensionRatio: extensionRatio
            )
        }
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
