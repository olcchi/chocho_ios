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
        backgroundColors: PuzzleBackgroundColors = .default,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool,
        liveDotAnimation: LiveDotAnimation = .none,
        blinkTime: TimeInterval? = nil
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
                colors: backgroundColors,
                photoFrameHeight: layout.photoFrame.height,
                extensionRatio: layout.extensionRatio,
                extensionSide: layout.extensionSide,
                sourceImage: image
            )

            image.draw(in: layout.photoFrame)

            drawDots(
                in: context,
                layout: layout,
                image: image,
                backgroundStyle: backgroundStyle,
                backgroundColors: backgroundColors,
                dots: dots,
                dotScale: dotScale,
                dotColor: dotColor,
                usesRandomDotColors: usesRandomDotColors,
                liveDotAnimation: liveDotAnimation,
                blinkTime: blinkTime
            )

            context.restoreGState()
        }
    }

    private nonisolated static func drawExtensionBackground(
        in context: CGContext,
        rect: CGRect,
        style: PuzzleBackgroundStyle,
        colors: PuzzleBackgroundColors,
        photoFrameHeight: CGFloat,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide,
        sourceImage: UIImage
    ) {
        guard rect.width > 0, rect.height > 0 else { return }

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)

        switch style {
        case .grid:
            context.setFillColor(UIColor(colors.fillColor).cgColor)
            context.fill(CGRect(origin: .zero, size: rect.size))
            strokeGrid(
                in: context,
                size: rect.size,
                photoFrameHeight: photoFrameHeight,
                lineColor: colors.lineColor
            )
        case .stripes:
            fillStripes(
                in: context,
                size: rect.size,
                photoFrameHeight: photoFrameHeight,
                colors: colors
            )
        case .halftone:
            let renderPixelSize = PuzzleHalftoneBackgroundMetrics.fullExtensionPixelSize(
                imagePixelSize: CanvasImageLoader.pixelSize(for: sourceImage),
                extensionSide: extensionSide
            )
            let visibleCrop = PuzzleHalftoneBackgroundMetrics.visibleCropNormalizedRect(
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            if let surface = PuzzleHalftoneBackgroundRenderer.render(
                sourceImage: sourceImage,
                renderPixelSize: renderPixelSize,
                backgroundColor: colors.fillColor,
                dotColor: colors.lineColor
            ) {
                PuzzleHalftoneBackgroundRenderer.drawVisibleCrop(
                    of: surface,
                    normalizedCrop: visibleCrop,
                    in: CGRect(origin: .zero, size: rect.size)
                )
            } else {
                context.setFillColor(UIColor(colors.fillColor).cgColor)
                context.fill(CGRect(origin: .zero, size: rect.size))
            }
        }

        context.restoreGState()
    }

    private nonisolated static func strokeGrid(
        in context: CGContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        lineColor: Color
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
        let lineWidth = PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: photoFrameHeight)

        context.setStrokeColor(UIColor(lineColor).cgColor)
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
        photoFrameHeight: CGFloat,
        colors: PuzzleBackgroundColors
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: photoFrameHeight)
        var y: CGFloat = 0
        var usesPrimaryStripe = true

        while y < size.height {
            let bandHeight = min(spacing, size.height - y)
            context.setFillColor(
                UIColor(usesPrimaryStripe ? colors.fillColor : colors.alternateColor).cgColor
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
        backgroundColors: PuzzleBackgroundColors,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool,
        liveDotAnimation: LiveDotAnimation,
        blinkTime: TimeInterval?
    ) {
        let referenceOrigin = layout.referenceComposedFrame.origin
        let photoFrameHeight = layout.referenceLocalPhotoFrame.height

        for dot in dots {
            let baseDotSize = DotSizeControl.displaySize(
                renderedScale: dot.size * dotScale * dot.displaySizeScale,
                photoFrameHeight: photoFrameHeight
            )
            let motion = dotMotion(
                dotID: dot.id,
                liveDotAnimation: liveDotAnimation,
                blinkTime: blinkTime
            )
            let dotSize = baseDotSize * motion.scale
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
                            opacity: motion.opacity,
                            in: context,
                            rect: rect,
                            image: image,
                            layout: layout,
                            backgroundStyle: backgroundStyle,
                            backgroundColors: backgroundColors,
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
                            color: uiColor.withAlphaComponent(motion.opacity)
                        )
                    }
                } else if PuzzleDotCollageColor.shouldRenderCollageContent(
                    for: dot,
                    usesRandomDotColors: usesRandomDotColors,
                    extensionRatio: layout.extensionRatio,
                    selectedDotColor: dotColor
                ) {
                    drawAssetDotCollage(
                        assetName: dot.shapeAssetName,
                        centerIndex: centerIndex,
                        dot: dot,
                        opacity: motion.opacity,
                        in: context,
                        rect: rect,
                        image: image,
                        layout: layout,
                        backgroundStyle: backgroundStyle,
                        backgroundColors: backgroundColors,
                        photoFrameHeight: photoFrameHeight
                    )
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
                        usesTemplateColor: dot.usesTemplateColor,
                        opacity: motion.opacity
                    )
                }
            }
        }
    }

    private nonisolated static func dotMotion(
        dotID: UUID,
        liveDotAnimation: LiveDotAnimation,
        blinkTime: TimeInterval?
    ) -> (opacity: CGFloat, scale: CGFloat) {
        guard let blinkTime else { return (1, 1) }
        switch liveDotAnimation {
        case .none:
            return (1, 1)
        case .randomBlink:
            return (
                CGFloat(DotRandomBlinkOpacity.opacity(dotID: dotID, time: blinkTime)),
                1
            )
        case .breathe:
            let sample = DotBreatheAnimation.sample(dotID: dotID, time: blinkTime)
            return (CGFloat(sample.opacity), CGFloat(sample.scale))
        }
    }

    private nonisolated static func drawBuiltInDotCollage(
        _ shape: BuiltInDotShape,
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        photoFrameHeight: CGFloat
    ) {
        let path = shape.bezierPath(in: rect)

        context.saveGState()
        clip(to: path, in: context)
        drawMirrorCollageContent(
            centerIndex: centerIndex,
            dot: dot,
            opacity: opacity,
            in: context,
            rect: rect,
            image: image,
            layout: layout,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            photoFrameHeight: photoFrameHeight
        )
        context.restoreGState()
    }

    private nonisolated static func drawAssetDotCollage(
        assetName: String,
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        photoFrameHeight: CGFloat
    ) {
        guard let maskImage = DotShapeAssetImage.uiImage(named: "public/\(assetName)") else { return }

        // Use the mask image's natural aspect ratio so the shape isn't squashed.
        let drawRect = aspectFitRect(for: maskImage.size, in: rect)
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        // Render collage content into a transparent offscreen context sized to `drawRect`.
        // CGContextClipToMask is avoided here because it maps the mask image in device
        // coordinates, which in UIGraphicsImageRenderer's flipped context causes the
        // mask to appear vertically inverted. Using .destinationIn with UIImage.draw
        // sidesteps the flip entirely since UIImage.draw respects the current CTM.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let localSize = drawRect.size
        let maskedContent = UIGraphicsImageRenderer(size: localSize, format: format).image { offCtx in
            let localRect = CGRect(origin: .zero, size: localSize)
            drawMirrorCollageContent(
                centerIndex: centerIndex,
                dot: dot,
                opacity: 1,
                in: offCtx.cgContext,
                rect: localRect,
                image: image,
                layout: layout,
                backgroundStyle: backgroundStyle,
                backgroundColors: backgroundColors,
                photoFrameHeight: photoFrameHeight
            )
            // Apply shape mask: only the pixels where the mask is opaque survive.
            offCtx.cgContext.setBlendMode(.destinationIn)
            maskImage.draw(in: localRect)
        }

        maskedContent.draw(in: drawRect, blendMode: .normal, alpha: opacity)
    }

    private nonisolated static func drawMirrorCollageContent(
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        photoFrameHeight: CGFloat
    ) {
        let photoSize = layout.referenceLocalPhotoFrame.size
        let extensionSize = layout.referenceLocalExtensionGridFrame.size

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

            // context.setAlpha is ignored by UIImage.draw(in:) which halftone uses internally.
            // Render into an offscreen buffer first, then composite with explicit alpha.
            let offFormat = UIGraphicsImageRendererFormat()
            offFormat.scale = 1
            offFormat.opaque = false
            let offscreen = UIGraphicsImageRenderer(size: extensionSize, format: offFormat)
                .image { offCtx in
                    drawExtensionBackground(
                        in: offCtx.cgContext,
                        rect: CGRect(origin: .zero, size: extensionSize),
                        style: backgroundStyle,
                        colors: backgroundColors,
                        photoFrameHeight: photoFrameHeight,
                        extensionRatio: PuzzleCanvasLayout.maxExtensionRatio,
                        extensionSide: layout.extensionSide,
                        sourceImage: image
                    )
                }
            offscreen.draw(
                in: CGRect(origin: backgroundOrigin, size: extensionSize),
                blendMode: .normal,
                alpha: opacity
            )
        } else {
            let photoOrigin = CGPoint(
                x: rect.midX - dot.position.x * photoSize.width,
                y: rect.midY - dot.position.y * photoSize.height
            )
            image.draw(
                in: CGRect(origin: photoOrigin, size: photoSize),
                blendMode: .normal,
                alpha: opacity
            )
        }
    }

    /// Returns the largest rect with `imageSize`'s aspect ratio that fits in `rect`, centered.
    private nonisolated static func aspectFitRect(for imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else {
            return rect
        }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        return CGRect(
            x: rect.midX - fittedWidth / 2,
            y: rect.midY - fittedHeight / 2,
            width: fittedWidth,
            height: fittedHeight
        )
    }

    private nonisolated static func drawBuiltInDot(
        _ shape: BuiltInDotShape,
        in context: CGContext,
        rect: CGRect,
        color: UIColor
    ) {
        let path = shape.bezierPath(in: rect)

        context.saveGState()
        context.addPath(path.cgPath)
        context.setFillColor(color.cgColor)
        context.fillPath(using: path.usesEvenOddFillRule ? .evenOdd : .winding)
        context.restoreGState()
    }

    private nonisolated static func clip(to path: UIBezierPath, in context: CGContext) {
        context.addPath(path.cgPath)
        context.clip(using: path.usesEvenOddFillRule ? .evenOdd : .winding)
    }

    private nonisolated static func drawAssetDot(
        assetName: String,
        in context: CGContext,
        rect: CGRect,
        color: UIColor,
        usesTemplateColor: Bool,
        opacity: CGFloat = 1
    ) {
        guard let image = DotShapeAssetImage.uiImage(named: "public/\(assetName)") else { return }
        let drawRect = aspectFitRect(for: image.size, in: rect)
        if usesTemplateColor {
            image.withTintColor(color, renderingMode: .alwaysTemplate).draw(
                in: drawRect,
                blendMode: .normal,
                alpha: opacity
            )
        } else {
            image.draw(in: drawRect, blendMode: .normal, alpha: opacity)
        }
    }

}

private nonisolated enum ThemeUIColor {
    static let background = UIColor(red: 245 / 255, green: 254 / 255, blue: 233 / 255, alpha: 1)
    static let secondary = UIColor(red: 238 / 255, green: 247 / 255, blue: 221 / 255, alpha: 1)
    static let border = UIColor(red: 226 / 255, green: 232 / 255, blue: 216 / 255, alpha: 1)
}
