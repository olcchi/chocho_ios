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
                dots: dots,
                dotScale: dotScale,
                dotColor: dotColor,
                usesRandomDotColors: usesRandomDotColors,
                extensionSide: extensionSide
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
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool,
        extensionSide: PuzzleCanvasExtensionSide
    ) {
        let referenceFrame = CGRect(
            origin: .zero,
            size: layout.referenceComposedFrame.size
        )
        let referenceOrigin = layout.referenceComposedFrame.origin
        let photoFrameHeight = layout.referenceLocalPhotoFrame.height

        for dot in dots {
            let dotSize = DotSizeControl.displaySize(
                renderedScale: dot.size * dotScale,
                photoFrameHeight: photoFrameHeight
            )
            let centers = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
                position: dot.position,
                referenceFrame: referenceFrame,
                extensionSide: extensionSide
            )
            let uiColor = UIColor(
                dot.displayColor(
                    usesRandomColor: usesRandomDotColors,
                    selectedColor: dotColor
                )
            )

            for center in centers {
                let origin = CGPoint(
                    x: referenceOrigin.x + center.x - dotSize / 2,
                    y: referenceOrigin.y + center.y - dotSize / 2
                )
                let rect = CGRect(origin: origin, size: CGSize(width: dotSize, height: dotSize))

                if let builtInShape = dot.builtInShape {
                    drawBuiltInDot(
                        builtInShape,
                        in: context,
                        rect: rect,
                        color: uiColor
                    )
                } else {
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

    private nonisolated static func drawBuiltInDot(
        _ shape: BuiltInDotShape,
        in context: CGContext,
        rect: CGRect,
        color: UIColor
    ) {
        let path: UIBezierPath
        switch shape {
        case .circle:
            path = UIBezierPath(ovalIn: rect)
        case .square:
            path = UIBezierPath(rect: rect)
        case .triangle:
            path = equilateralTrianglePath(in: rect)
        case .star:
            path = fivePointStarPath(in: rect)
        }

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
        guard let image = UIImage(named: "public/shapes/\(assetName)") else { return }

        if usesTemplateColor {
            image.withTintColor(color, renderingMode: .alwaysTemplate).draw(in: rect)
        } else {
            image.draw(in: rect)
        }
    }

    private nonisolated static func equilateralTrianglePath(in rect: CGRect) -> UIBezierPath {
        let side = min(rect.width, rect.height * 2 / sqrt(3))
        let height = side * sqrt(3) / 2
        let minX = rect.midX - side / 2
        let minY = rect.midY - height / 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: minY))
        path.addLine(to: CGPoint(x: minX + side, y: minY + height))
        path.addLine(to: CGPoint(x: minX, y: minY + height))
        path.close()
        return path
    }

    private nonisolated static func fivePointStarPath(in rect: CGRect) -> UIBezierPath {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()

        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()
        return path
    }
}

private nonisolated enum ThemeUIColor {
    static let background = UIColor(red: 245 / 255, green: 254 / 255, blue: 233 / 255, alpha: 1)
    static let secondary = UIColor(red: 238 / 255, green: 247 / 255, blue: 221 / 255, alpha: 1)
    static let border = UIColor(red: 226 / 255, green: 232 / 255, blue: 216 / 255, alpha: 1)
}
