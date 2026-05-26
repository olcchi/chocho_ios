import SwiftUI
import UIKit

/// Renders the composed puzzle canvas with Core Graphics instead of SwiftUI `ImageRenderer`.
nonisolated enum CanvasRasterExporter {
    nonisolated static func render(
        image: UIImage,
        exportSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide,
        backgroundStyle: PuzzleBackgroundStyle,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool
    ) -> UIImage? {
        guard exportSize.width > 0, exportSize.height > 0 else { return nil }

        let imageSize = CanvasImageLoader.pixelSize(for: image)
        let layout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: exportSize,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: exportSize, format: format)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(ThemeUIColor.background.cgColor)
            context.fill(CGRect(origin: .zero, size: exportSize))

            let visibleFrame = layout.visibleComposedFrame

            context.saveGState()
            context.clip(to: CGRect(origin: .zero, size: exportSize))
            context.translateBy(x: -visibleFrame.minX, y: -visibleFrame.minY)
            context.clip(to: visibleFrame)

            drawExtensionBackground(
                in: context,
                rect: layout.extensionFrame,
                style: backgroundStyle,
                photoFrameHeight: layout.photoFrame.height
            )

            image.draw(in: layout.photoFrame)

            drawDots(
                in: context,
                layout: layout,
                image: image,
                backgroundStyle: backgroundStyle,
                dots: dots,
                dotScale: dotScale,
                dotColor: dotColor,
                usesRandomDotColors: usesRandomDotColors
            )

            context.restoreGState()
        }
    }

    private nonisolated static func drawExtensionBackground(
        in context: CGContext,
        rect: CGRect,
        style: PuzzleBackgroundStyle,
        photoFrameHeight: CGFloat
    ) {
        guard rect.width > 0, rect.height > 0 else { return }

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)

        switch style {
        case .grid:
            context.setFillColor(ThemeUIColor.secondary.cgColor)
            context.fill(CGRect(origin: .zero, size: rect.size))
            strokeGrid(in: context, size: rect.size, photoFrameHeight: photoFrameHeight)
        case .stripes:
            fillStripes(in: context, size: rect.size, photoFrameHeight: photoFrameHeight)
        }

        context.restoreGState()
    }

    private nonisolated static func strokeGrid(
        in context: CGContext,
        size: CGSize,
        photoFrameHeight: CGFloat
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
        let lineWidth = PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: photoFrameHeight)

        context.setStrokeColor(ThemeUIColor.border.cgColor)
        context.setLineWidth(lineWidth)

        var x: CGFloat = 0
        while x <= size.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.strokePath()
    }

    private nonisolated static func fillStripes(
        in context: CGContext,
        size: CGSize,
        photoFrameHeight: CGFloat
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
        var y: CGFloat = 0
        var usesPrimaryStripe = true

        while y < size.height {
            let bandHeight = min(spacing, size.height - y)
            context.setFillColor(
                (usesPrimaryStripe ? ThemeUIColor.secondary : ThemeUIColor.background).cgColor
            )
            context.fill(CGRect(x: 0, y: y, width: size.width, height: bandHeight))
            y += spacing
            usesPrimaryStripe.toggle()
        }
    }

    private nonisolated static func drawDots(
        in context: CGContext,
        layout: PuzzleCanvasLayoutResult,
        image: UIImage,
        backgroundStyle: PuzzleBackgroundStyle,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool
    ) {
        let referenceOrigin = layout.referenceComposedFrame.origin
        let photoFrameHeight = layout.referenceLocalPhotoFrame.height

        for dot in dots {
            let dotSize = DotSizeControl.displaySize(
                renderedScale: dot.size * dotScale * dot.displaySizeScale,
                photoFrameHeight: photoFrameHeight
            )
            let centers = PuzzleCanvasCoordinate.dotCenters(for: dot.position, in: layout)

            for (centerIndex, center) in centers.enumerated() {
                let origin = CGPoint(
                    x: referenceOrigin.x + center.x - dotSize / 2,
                    y: referenceOrigin.y + center.y - dotSize / 2
                )
                let rect = CGRect(origin: origin, size: CGSize(width: dotSize, height: dotSize))

                if let builtInShape = dot.builtInShape {
                    if PuzzleDotCollageColor.shouldRenderCollageContent(
                        for: dot,
                        usesRandomDotColors: usesRandomDotColors,
                        extensionRatio: layout.extensionRatio,
                        selectedDotColor: dotColor
                    ) {
                        drawBuiltInDotCollage(
                            builtInShape,
                            centerIndex: centerIndex,
                            dot: dot,
                            in: context,
                            rect: rect,
                            image: image,
                            layout: layout,
                            backgroundStyle: backgroundStyle,
                            photoFrameHeight: photoFrameHeight
                        )
                    } else {
                        let uiColor = UIColor(
                            dot.displayColor(
                                usesRandomColor: usesRandomDotColors,
                                selectedColor: dotColor
                            )
                        )
                        drawBuiltInDot(
                            builtInShape,
                            in: context,
                            rect: rect,
                            color: uiColor
                        )
                    }
                } else {
                    let uiColor = UIColor(
                        dot.displayColor(
                            usesRandomColor: usesRandomDotColors,
                            selectedColor: dotColor
                        )
                    )
                    drawAssetDot(
                        assetName: dot.shapeAssetName,
                        in: context,
                        rect: rect,
                        color: uiColor,
                        usesTemplateColor: dot.usesTemplateColor
                    )
                }
            }
        }
    }

    private nonisolated static func drawBuiltInDotCollage(
        _ shape: BuiltInDotShape,
        centerIndex: Int,
        dot: PuzzleDot,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        photoFrameHeight: CGFloat
    ) {
        let path = shape.bezierPath(in: rect)
        let photoSize = layout.referenceLocalPhotoFrame.size
        let extensionSize = layout.referenceLocalExtensionGridFrame.size

        context.saveGState()
        path.addClip()

        if centerIndex == 0 {
            let mirrorPosition = PuzzleDotCollageColor.referenceExtensionMirrorPosition(
                forPhotoPosition: dot.position,
                extensionSide: layout.extensionSide
            )
            let samplePoint = PuzzleDotCollageColor.clampedExtensionSamplePoint(mirrorPosition)
            let backgroundOrigin = CGPoint(
                x: rect.midX - samplePoint.x * extensionSize.width,
                y: rect.midY - samplePoint.y * extensionSize.height
            )

            drawExtensionBackground(
                in: context,
                rect: CGRect(origin: backgroundOrigin, size: extensionSize),
                style: backgroundStyle,
                photoFrameHeight: photoFrameHeight
            )
        } else {
            let photoOrigin = CGPoint(
                x: rect.midX - dot.position.x * photoSize.width,
                y: rect.midY - dot.position.y * photoSize.height
            )
            image.draw(in: CGRect(origin: photoOrigin, size: photoSize))
        }

        context.restoreGState()
    }

    private nonisolated static func drawBuiltInDot(
        _ shape: BuiltInDotShape,
        in context: CGContext,
        rect: CGRect,
        color: UIColor
    ) {
        let path = shape.bezierPath(in: rect)

        context.saveGState()
        color.setFill()
        path.fill()
        context.restoreGState()
    }

    private nonisolated static func drawAssetDot(
        assetName: String,
        in context: CGContext,
        rect: CGRect,
        color: UIColor,
        usesTemplateColor: Bool
    ) {
        guard let image = DotShapeAssetImage.uiImage(named: "public/\(assetName)") else { return }

        if usesTemplateColor {
            image.withTintColor(color, renderingMode: .alwaysTemplate).draw(in: rect)
        } else {
            image.draw(in: rect)
        }
    }

}

private nonisolated enum ThemeUIColor {
    static let background = UIColor(red: 245 / 255, green: 254 / 255, blue: 233 / 255, alpha: 1)
    static let secondary = UIColor(red: 238 / 255, green: 247 / 255, blue: 221 / 255, alpha: 1)
    static let border = UIColor(red: 226 / 255, green: 232 / 255, blue: 216 / 255, alpha: 1)
}
