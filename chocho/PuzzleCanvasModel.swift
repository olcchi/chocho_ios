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

struct PuzzleDot: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let color: Color
    let size: CGFloat
    let shapeAssetName: String
}

enum PuzzleDotFactory {
    static func makeDot(
        position: CGPoint,
        index: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> PuzzleDot {
        let palette: [Color] = [
            Color(red: 138 / 255, green: 255 / 255, blue: 78 / 255),
            Color(red: 77 / 255, green: 238 / 255, blue: 91 / 255),
            Color(red: 82 / 255, green: 72 / 255, blue: 235 / 255),
            Color(red: 255 / 255, green: 233 / 255, blue: 52 / 255),
            Color(red: 255 / 255, green: 48 / 255, blue: 119 / 255)
        ]

        return PuzzleDot(
            id: UUID(),
            position: CGPoint(
                x: min(max(position.x, 0), 1),
                y: min(max(position.y, 0), 1)
            ),
            color: palette[max(index, 0) % palette.count],
            size: CGFloat.random(in: 24...42),
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
