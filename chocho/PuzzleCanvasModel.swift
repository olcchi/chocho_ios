import CoreGraphics
import SwiftUI

struct PuzzleCanvasLayoutResult: Equatable {
    let extensionRatio: CGFloat
    let photoFrame: CGRect
    let extensionFrame: CGRect
    let composedSize: CGSize
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

        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )
        let unscaledLocation = CGPoint(
            x: viewportCenter.x + (location.x - offset.width - viewportCenter.x) / scale,
            y: viewportCenter.y + (location.y - offset.height - viewportCenter.y) / scale
        )
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
}

enum PuzzleDotFactory {
    private static let unitSize: CGFloat = 1

    static func makeDot(
        position: CGPoint,
        index: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> PuzzleDot {
        let palette: [Color] = [
            Color.chart1,
            Color.chart2,
            Color.chart3,
            Color.chart4,
            Color.chart5
        ]

        return PuzzleDot(
            id: UUID(),
            position: CGPoint(
                x: min(max(position.x, 0), 1),
                y: min(max(position.y, 0), 1)
            ),
            color: palette[max(index, 0) % palette.count],
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
}
