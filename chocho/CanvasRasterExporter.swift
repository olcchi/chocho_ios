import SwiftUI
import UIKit

// MARK: - 画布光栅导出
/// 用 Core Graphics 合成照片、扩展背景与波点，供静图导出与 Live Photo 逐帧编码。
/// 预览可用 SwiftUI `.opacity()`；此处须对 `UIImage.draw(in:blendMode:alpha:)` 传显式 alpha。
nonisolated enum CanvasRasterExporter {
    nonisolated static func render(
        image: UIImage,
        exportSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide,
        photoCompression: MainPhotoCompression = .none,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors = .default,
        backgroundPatternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool,
        dotCharacterText: String = CharacterDotText.defaultText,
        textBubbleSettings: TextBubbleSettings = .default,
        liveDotAnimation: LiveDotAnimation = .none,
        blinkTime: TimeInterval? = nil,
        y2kCCDFilterSettings: Y2KCCDFilterSettings = .default,
        asciiArtSettings: ASCIIArtSettings = .default,
        asciiArtMask: SubjectMask? = nil,
        photoFrameImage: UIImage? = nil,
        styledBaseImage: UIImage? = nil,
        styledLiveFrameImage: UIImage? = nil
    ) -> UIImage? {
        guard exportSize.width > 0, exportSize.height > 0 else { return nil }

        let sourceImageSize = CanvasImageLoader.pixelSize(for: image)
        let renderImage = styledBaseImage ?? CanvasStyledPhotoRenderer.renderSync(
            image: image,
            y2kCCDFilterSettings: y2kCCDFilterSettings,
            sourceKey: "export-base",
            asciiArtSettings: asciiArtSettings,
            asciiArtMask: asciiArtMask,
            photoCompression: photoCompression
        )
        let renderPhotoFrameImage = styledLiveFrameImage ?? photoFrameImage.map {
            CanvasStyledPhotoRenderer.renderSync(
                image: $0,
                y2kCCDFilterSettings: y2kCCDFilterSettings,
                sourceKey: "export-frame-\(blinkTime ?? 0)",
                asciiArtSettings: asciiArtSettings,
                asciiArtMask: asciiArtMask,
                photoCompression: photoCompression
            )
        }

        let layout = PuzzleCanvasLayout.layout(
            imageSize: sourceImageSize,
            availableSize: exportSize,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide,
            photoCompression: photoCompression
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
                patternSpacing: backgroundPatternSpacing,
                photoFrameHeight: layout.backgroundPatternReferenceHeight,
                extensionRatio: layout.extensionRatio,
                extensionSide: layout.extensionSide,
                sourceImage: renderImage
            )

            if layout.extensionSide == .center {
                drawDots(
                    in: context,
                    layout: layout,
                    image: renderImage,
                    liveFrameImage: renderPhotoFrameImage,
                    backgroundStyle: backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
                    dots: dots,
                    dotScale: dotScale,
                    dotColor: dotColor,
                    usesRandomDotColors: usesRandomDotColors,
                    dotCharacterText: dotCharacterText,
                    liveDotAnimation: liveDotAnimation,
                    blinkTime: blinkTime,
                    centerIndexFilter: .background
                )
            }

            let displayPhoto = renderPhotoFrameImage ?? renderImage
            displayPhoto.draw(in: layout.photoFrame)

            drawDots(
                in: context,
                layout: layout,
                image: renderImage,
                liveFrameImage: renderPhotoFrameImage,
                backgroundStyle: backgroundStyle,
                backgroundColors: backgroundColors,
                backgroundPatternSpacing: backgroundPatternSpacing,
                dots: dots,
                dotScale: dotScale,
                dotColor: dotColor,
                usesRandomDotColors: usesRandomDotColors,
                dotCharacterText: dotCharacterText,
                liveDotAnimation: liveDotAnimation,
                blinkTime: blinkTime,
                centerIndexFilter: layout.extensionSide == .center ? .photo : .all
            )

            drawTextBubbleOverlay(
                settings: textBubbleSettings,
                in: context,
                canvasRect: visibleFrame
            )

            context.restoreGState()
        }
    }

    private nonisolated static func drawExtensionBackground(
        in context: CGContext,
        rect: CGRect,
        style: PuzzleBackgroundStyle,
        colors: PuzzleBackgroundColors,
        patternSpacing: Double,
        photoFrameHeight: CGFloat,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide,
        sourceImage: UIImage
    ) {
        guard rect.width > 0, rect.height > 0 else { return }

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)

        switch style {
        case .solid:
            context.setFillColor(UIColor(colors.fillColor).cgColor)
            context.fill(CGRect(origin: .zero, size: rect.size))
        case .grid:
            context.setFillColor(UIColor(colors.fillColor).cgColor)
            context.fill(CGRect(origin: .zero, size: rect.size))
            strokeGrid(
                in: context,
                size: rect.size,
                photoFrameHeight: photoFrameHeight,
                patternSpacing: patternSpacing,
                lineColor: colors.lineColor
            )
        case .stripes:
            fillStripes(
                in: context,
                size: rect.size,
                photoFrameHeight: photoFrameHeight,
                patternSpacing: patternSpacing,
                colors: colors
            )
        case .polkaDots:
            fillPolkaDots(
                in: context,
                size: rect.size,
                photoFrameHeight: photoFrameHeight,
                dotSize: patternSpacing,
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
        patternSpacing: Double,
        lineColor: Color
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
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
            context.setFillColor(
                UIColor(usesPrimaryStripe ? colors.fillColor : colors.alternateColor).cgColor
            )
            context.fill(CGRect(x: 0, y: y, width: size.width, height: bandHeight))
            y += spacing
            usesPrimaryStripe.toggle()
        }
    }

    private nonisolated static func fillPolkaDots(
        in context: CGContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        dotSize: Double,
        colors: PuzzleBackgroundColors
    ) {
        context.setFillColor(UIColor(colors.fillColor).cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let dotRects = PuzzleBackgroundPolkaDotMetrics.dotRects(
            in: size,
            controlValue: dotSize,
            photoFrameHeight: photoFrameHeight
        )
        context.setFillColor(UIColor(colors.lineColor).cgColor)

        for rect in dotRects {
            context.fillEllipse(in: rect)
        }
    }

    private enum DotCenterIndexFilter {
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

    private nonisolated static func drawDots(
        in context: CGContext,
        layout: PuzzleCanvasLayoutResult,
        image: UIImage,
        liveFrameImage: UIImage?,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        backgroundPatternSpacing: Double,
        dots: [PuzzleDot],
        dotScale: CGFloat,
        dotColor: Color,
        usesRandomDotColors: Bool,
        dotCharacterText: String,
        liveDotAnimation: LiveDotAnimation,
        blinkTime: TimeInterval?,
        centerIndexFilter: DotCenterIndexFilter = .all
    ) {
        let referenceOrigin = layout.referenceComposedFrame.origin

        for dot in dots {
            let motion = DotMotionSample.sample(
                dotID: dot.id,
                liveDotAnimation: liveDotAnimation,
                time: blinkTime
            )
            let centers = PuzzleCanvasCoordinate.dotCenters(for: dot.position, in: layout)

            for (centerIndex, center) in centers.enumerated() {
                guard centerIndexFilter.includes(centerIndex) else { continue }

                let photoFrameHeight = layout.dotReferenceHeight(forCenterIndex: centerIndex)
                let baseDotSize = DotSizeControl.displaySize(
                    renderedScale: dot.resolvedRenderedScale(globalDotScale: dotScale) * dot.displaySizeScale,
                    photoFrameHeight: photoFrameHeight
                )
                let dotSize = baseDotSize * CGFloat(motion.scale)
                let origin = CGPoint(
                    x: referenceOrigin.x + center.x - dotSize / 2,
                    y: referenceOrigin.y + center.y - dotSize / 2
                )
                let rect = CGRect(origin: origin, size: CGSize(width: dotSize, height: dotSize))

                context.saveGState()
                let rotationRadians = CGFloat(motion.rotationRadians) + dot.rotationDegrees * .pi / 180
                applyDotRotation(rotationRadians, in: context, around: rect)

                if dot.isCharacterDot {
                    if PuzzleDotCollageColor.shouldRenderCollageContent(
                        for: dot,
                        usesRandomDotColors: usesRandomDotColors,
                        extensionRatio: layout.extensionRatio,
                        selectedDotColor: dotColor
                    ) {
                        drawCharacterDotCollage(
                            text: dotCharacterText,
                            centerIndex: centerIndex,
                            dot: dot,
                            opacity: CGFloat(motion.opacity),
                            in: context,
                            rect: rect,
                            image: image,
                            liveFrameImage: liveFrameImage,
                            layout: layout,
                            backgroundStyle: backgroundStyle,
                            backgroundColors: backgroundColors,
                            backgroundPatternSpacing: backgroundPatternSpacing,
                            photoFrameHeight: photoFrameHeight
                        )
                    } else {
                        let uiColor = UIColor(
                            dot.displayColor(
                                usesRandomColor: usesRandomDotColors,
                                selectedColor: dotColor
                            )
                        )
                        drawCharacterDot(
                            text: dotCharacterText,
                            in: context,
                            rect: rect,
                            color: uiColor.withAlphaComponent(CGFloat(motion.opacity))
                        )
                    }
                } else if let builtInShape = dot.builtInShape {
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
                            opacity: CGFloat(motion.opacity),
                            in: context,
                            rect: rect,
                            image: image,
                            liveFrameImage: liveFrameImage,
                            layout: layout,
                            backgroundStyle: backgroundStyle,
                            backgroundColors: backgroundColors,
                            backgroundPatternSpacing: backgroundPatternSpacing,
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
                            color: uiColor.withAlphaComponent(CGFloat(motion.opacity))
                        )
                    }
                } else if PuzzleDotCollageColor.shouldRenderCollageContent(
                    for: dot,
                    usesRandomDotColors: usesRandomDotColors,
                    extensionRatio: layout.extensionRatio,
                    selectedDotColor: dotColor
                ) {
                    drawAssetDotCollage(
                        assetName: dot.resolvedShapeAssetName,
                        centerIndex: centerIndex,
                        dot: dot,
                        opacity: CGFloat(motion.opacity),
                        in: context,
                        rect: rect,
                        image: image,
                        liveFrameImage: liveFrameImage,
                        layout: layout,
                        backgroundStyle: backgroundStyle,
                        backgroundColors: backgroundColors,
                        backgroundPatternSpacing: backgroundPatternSpacing,
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
                        assetName: dot.resolvedShapeAssetName,
                        in: context,
                        rect: rect,
                        color: uiColor,
                        usesTemplateColor: dot.usesTemplateColor,
                        opacity: CGFloat(motion.opacity)
                    )
                }

                context.restoreGState()
            }
        }
    }

    private nonisolated static func applyDotRotation(
        _ radians: CGFloat,
        in context: CGContext,
        around rect: CGRect
    ) {
        guard radians != 0 else { return }
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: radians)
        context.translateBy(x: -rect.midX, y: -rect.midY)
    }

    private nonisolated static func drawBuiltInDotCollage(
        _ shape: BuiltInDotShape,
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        liveFrameImage: UIImage?,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        backgroundPatternSpacing: Double,
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
            liveFrameImage: liveFrameImage,
            layout: layout,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        context.restoreGState()
    }

    private nonisolated static func drawCharacterDotCollage(
        text: String,
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        liveFrameImage: UIImage?,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        backgroundPatternSpacing: Double,
        photoFrameHeight: CGFloat
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        guard let clippingMask = characterClippingMask(text: text, size: rect.size) else { return }

        context.saveGState()
        context.clip(to: rect, mask: clippingMask)
        drawMirrorCollageContent(
            centerIndex: centerIndex,
            dot: dot,
            opacity: opacity,
            in: context,
            rect: rect,
            image: image,
            liveFrameImage: liveFrameImage,
            layout: layout,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        context.restoreGState()
    }

    private nonisolated static func characterClippingMask(text: String, size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format)
            .image { rendererContext in
                let rect = CGRect(origin: .zero, size: size)
                drawCharacterDot(text: text, in: rendererContext.cgContext, rect: rect, color: .white)
            }
            .cgImage
    }

    private nonisolated static func drawAssetDotCollage(
        assetName: String,
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        liveFrameImage: UIImage?,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        backgroundPatternSpacing: Double,
        photoFrameHeight: CGFloat
    ) {
        guard let maskImage = DotShapeAssetImage.uiImage(named: "public/\(assetName)") else { return }

        // Use the mask image's natural aspect ratio so the shape isn't squashed.
        let drawRect = aspectFitRect(for: maskImage.size, in: rect)
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        let prefersCrispScaling = DotShapeAssetCategoryParser.prefersCrispScaling(for: assetName)
        guard let clippingMask = alphaClippingMask(
            from: maskImage,
            size: drawRect.size,
            prefersCrispScaling: prefersCrispScaling
        ) else { return }

        context.saveGState()
        context.clip(to: drawRect, mask: clippingMask)
        drawMirrorCollageContent(
            centerIndex: centerIndex,
            dot: dot,
            opacity: opacity,
            in: context,
            rect: drawRect,
            image: image,
            liveFrameImage: liveFrameImage,
            layout: layout,
            backgroundStyle: backgroundStyle,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: backgroundPatternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        context.restoreGState()
    }

    private nonisolated static func alphaClippingMask(
        from image: UIImage,
        size: CGSize,
        prefersCrispScaling: Bool
    ) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format)
            .image { rendererContext in
                let context = rendererContext.cgContext
                let rect = CGRect(origin: .zero, size: size)
                let previousInterpolationQuality = context.interpolationQuality
                if prefersCrispScaling {
                    context.interpolationQuality = .none
                }
                defer { context.interpolationQuality = previousInterpolationQuality }

                image.draw(in: rect)
                context.setBlendMode(.sourceIn)
                context.setFillColor(UIColor.white.cgColor)
                context.fill(rect)
            }
            .cgImage
    }

    /// 渲染拼贴波点内容。
    /// - `centerIndex == 0`：波点位于主图区，显示背景样式内容（背景静止，不受实况影响）。
    /// - `centerIndex == 1`：波点位于扩展区，显示照片内容；`liveFrameImage` 有值时用实况帧。
    private nonisolated static func drawMirrorCollageContent(
        centerIndex: Int,
        dot: PuzzleDot,
        opacity: CGFloat,
        in context: CGContext,
        rect: CGRect,
        image: UIImage,
        liveFrameImage: UIImage?,
        layout: PuzzleCanvasLayoutResult,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors,
        backgroundPatternSpacing: Double,
        photoFrameHeight: CGFloat
    ) {
        let photoSize = layout.referenceLocalPhotoFrame.size
        let extensionSize = layout.referenceLocalExtensionGridFrame.size

        if centerIndex == 0 {
            // 主图区：显示背景样式内容（背景静止）。
            let mirrorPosition = PuzzleDotCollageColor.referenceExtensionMirrorPosition(
                forPhotoPosition: dot.position,
                extensionSide: layout.extensionSide
            )
            let samplePoint = PuzzleDotCollageColor.clampedExtensionSamplePoint(mirrorPosition)
            let backgroundOrigin = CGPoint(
                x: rect.midX - samplePoint.x * extensionSize.width,
                y: rect.midY - samplePoint.y * extensionSize.height
            )

            // `context.setAlpha` 对 `UIImage.draw(in:)` 无效；先离屏绘制再带 alpha 合成。
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
                        patternSpacing: backgroundPatternSpacing,
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
            // 扩展区：显示照片内容；原图实况开启时用当前实况帧。
            let effectiveImage = liveFrameImage ?? image
            let photoOrigin = CGPoint(
                x: rect.midX - dot.position.x * photoSize.width,
                y: rect.midY - dot.position.y * photoSize.height
            )
            effectiveImage.draw(
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

    private nonisolated static func drawCharacterDot(
        text: String,
        in context: CGContext,
        rect: CGRect,
        color: UIColor
    ) {
        let displayText = CharacterDotText.displayText(for: text) as NSString
        let fontSize = CharacterDotGlyphRasterLayout.fittedFontSize(
            for: displayText,
            in: rect.size
        )
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let measuredSize = displayText.size(withAttributes: attributes)
        let drawRect = CGRect(
            x: rect.midX - measuredSize.width / 2,
            y: rect.midY - measuredSize.height / 2,
            width: measuredSize.width,
            height: measuredSize.height
        )

        context.saveGState()
        displayText.draw(in: drawRect, withAttributes: attributes)
        context.restoreGState()
    }

    private nonisolated static func drawTextBubbleOverlay(
        settings: TextBubbleSettings,
        in context: CGContext,
        canvasRect: CGRect
    ) {
        guard settings.enabled else { return }

        for bubble in settings.visibleBubbles {
            let bubbleFrame = TextBubbleCanvasLayout.frame(for: bubble, in: canvasRect)
            drawTextBubble(
                text: bubble.displayText,
                in: context,
                rect: bubbleFrame,
                bubbleColor: settings.bubbleColor.uiColor,
                baseSize: TextBubbleCanvasLayout.baseSize(for: bubble, in: canvasRect.size),
                maximumTextWidth: TextBubbleCanvasLayout.maximumTextWidth(in: canvasRect.size)
            )
        }
    }

    private nonisolated static func drawTextBubble(
        text: String,
        in context: CGContext,
        rect: CGRect,
        bubbleColor: UIColor,
        baseSize: CGFloat,
        maximumTextWidth: CGFloat
    ) {
        let displayText = CharacterDotText.bubbleDisplayText(for: text) as NSString
        let layout = TextBubbleLayout.layout(
            for: text,
            baseSize: baseSize,
            maximumTextWidth: maximumTextWidth
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        let textColor = bubbleColor.withAlphaComponent(1).readableTextColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: layout.fontSize, weight: .regular),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]
        let path = TextBubblePath.bezierPath(in: CGRect(origin: .zero, size: rect.size))

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.addPath(path.cgPath)
        context.setFillColor(bubbleColor.cgColor)
        context.fillPath()
        displayText.draw(in: layout.textRect, withAttributes: attributes)
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
        let previousInterpolationQuality = context.interpolationQuality
        if DotShapeAssetCategoryParser.prefersCrispScaling(for: assetName) {
            context.interpolationQuality = .none
        }
        defer { context.interpolationQuality = previousInterpolationQuality }
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
