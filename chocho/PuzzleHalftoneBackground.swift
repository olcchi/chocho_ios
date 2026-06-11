import CoreImage
import CoreGraphics
import SwiftUI
import UIKit

nonisolated enum PuzzleHalftoneBackgroundMetrics {
    static let surfaceCacheLimit = 6
    static let radiusScale: CGFloat = 0.35
    static let surfaceMaxEdge: CGFloat = 960
    static let defaultPaperHex = "#f0eee6"
    /// Tone-blur intensity (0…40); keep low so photo contours stay readable.
    static let defaultBlurAmount: Double = 0

    static func toneBlurRadius(blurAmount: Double) -> CGFloat {
        let clamped = min(max(blurAmount, 0), 40)
        return (clamped * Double(radiusScale) * 10).rounded() / 10
    }

    /// Extension area size in source-image pixels for a given ratio.
    static func extensionPixelSize(
        imagePixelSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGSize {
        let ratio = min(max(extensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        let width = max(1, imagePixelSize.width)
        let height = max(1, imagePixelSize.height)

        switch extensionSide {
        case .left, .right:
            return CGSize(width: max(1, width * ratio), height: height)
        case .top, .bottom:
            return CGSize(width: width, height: max(1, height * ratio))
        }
    }

    /// Full extension strip at max ratio — render once, crop while adjusting width.
    static func fullExtensionPixelSize(
        imagePixelSize: CGSize,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGSize {
        extensionPixelSize(
            imagePixelSize: imagePixelSize,
            extensionRatio: PuzzleCanvasLayout.maxExtensionRatio,
            extensionSide: extensionSide
        )
    }

    /// Visible slice of the full extension bitmap (normalized 0…1, photo-adjacent edge aligned).
    static func visibleCropNormalizedRect(
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGRect {
        let maxRatio = PuzzleCanvasLayout.maxExtensionRatio
        let fraction = min(max(extensionRatio, 0), maxRatio) / max(maxRatio, 0.0001)
        guard fraction > 0 else { return .zero }

        switch extensionSide {
        case .right:
            return CGRect(x: 0, y: 0, width: fraction, height: 1)
        case .left:
            return CGRect(x: 1 - fraction, y: 0, width: fraction, height: 1)
        case .bottom:
            return CGRect(x: 0, y: 0, width: 1, height: fraction)
        case .top:
            return CGRect(x: 0, y: 1 - fraction, width: 1, height: fraction)
        }
    }

    static func mapVisiblePointToFullExtension(
        _ normalizedVisiblePoint: CGPoint,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGPoint {
        let crop = visibleCropNormalizedRect(
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )
        guard crop.width > 0, crop.height > 0 else {
            return normalizedVisiblePoint
        }

        let u = min(max(normalizedVisiblePoint.x, 0), 1)
        let v = min(max(normalizedVisiblePoint.y, 0), 1)
        return CGPoint(
            x: crop.minX + u * crop.width,
            y: crop.minY + v * crop.height
        )
    }

    static func photoAdjacentAlignment(for extensionSide: PuzzleCanvasExtensionSide) -> Alignment {
        switch extensionSide {
        case .right:
            .leading
        case .left:
            .trailing
        case .bottom:
            .top
        case .top:
            .bottom
        }
    }

    static func visibleDisplaySize(
        fullExtensionSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGSize {
        let crop = visibleCropNormalizedRect(
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )
        return CGSize(
            width: max(0, fullExtensionSize.width * crop.width),
            height: max(0, fullExtensionSize.height * crop.height)
        )
    }

    static func visibleDisplayCenter(
        in fullExtensionFrame: CGRect,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGPoint {
        let size = visibleDisplaySize(
            fullExtensionSize: fullExtensionFrame.size,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )
        let origin = CGPoint(
            x: extensionSide == .left
                ? fullExtensionFrame.maxX - size.width
                : fullExtensionFrame.minX,
            y: extensionSide == .top
                ? fullExtensionFrame.maxY - size.height
                : fullExtensionFrame.minY
        )
        return CGPoint(
            x: origin.x + size.width / 2,
            y: origin.y + size.height / 2
        )
    }
}

/// Photo-derived halftone extension background (ported from web canvas tone-blur).
nonisolated enum PuzzleHalftoneBackgroundRenderer {
    private static let cacheLock = NSLock()
    private static var surfaceCache: [String: UIImage] = [:]
    private static var cacheOrder: [String] = []

    private static let ciContext = CIContext(options: nil)

    static func render(
        sourceImage: UIImage,
        sourceCacheKey: String? = nil,
        renderPixelSize: CGSize,
        backgroundColor: Color,
        dotColor: Color,
        blurAmount: Double = PuzzleHalftoneBackgroundMetrics.defaultBlurAmount
    ) -> UIImage? {
        let requestedWidth = max(0, renderPixelSize.width.rounded())
        let requestedHeight = max(0, renderPixelSize.height.rounded())
        guard requestedWidth > 0, requestedHeight > 0 else { return nil }

        let scale = min(
            1,
            PuzzleHalftoneBackgroundMetrics.surfaceMaxEdge
                / max(requestedWidth, requestedHeight)
        )
        let width = max(1, Int((requestedWidth * scale).rounded()))
        let height = max(1, Int((requestedHeight * scale).rounded()))
        let blurRadius = PuzzleHalftoneBackgroundMetrics.toneBlurRadius(blurAmount: blurAmount)

        let sourceKey =
            sourceCacheKey
            ?? "\(CanvasImageLoader.pixelSize(for: sourceImage).width)x\(CanvasImageLoader.pixelSize(for: sourceImage).height)"

        let cacheKey = [
            HalftoneHash.fnv1a(sourceKey),
            HalftoneColor.hexString(backgroundColor) ?? PuzzleHalftoneBackgroundMetrics.defaultPaperHex,
            HalftoneColor.hexString(dotColor) ?? "dot",
            Int(blurAmount.rounded()),
            width,
            height,
            "halftone-v5",
        ]
        .map { "\($0)" }
        .joined(separator: "|")

        cacheLock.lock()
        if let cached = surfaceCache[cacheKey] {
            cacheOrder.removeAll { $0 == cacheKey }
            cacheOrder.append(cacheKey)
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let rendered = renderSurface(
            sourceImage: sourceImage,
            width: width,
            height: height,
            blurAmount: blurAmount,
            blurRadius: blurRadius,
            backgroundColor: backgroundColor,
            dotColor: dotColor,
            cacheKey: cacheKey
        ) else {
            return nil
        }

        cacheLock.lock()
        surfaceCache[cacheKey] = rendered
        cacheOrder.removeAll { $0 == cacheKey }
        cacheOrder.append(cacheKey)
        if cacheOrder.count > PuzzleHalftoneBackgroundMetrics.surfaceCacheLimit,
           let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            surfaceCache.removeValue(forKey: oldest)
        }
        cacheLock.unlock()

        return rendered
    }

    static func color(
        at normalizedPoint: CGPoint,
        surface: UIImage,
        fallback: Color
    ) -> Color {
        guard let cgImage = surface.cgImage else { return fallback }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return fallback }

        let u = min(max(normalizedPoint.x, 0), 1)
        let v = min(max(normalizedPoint.y, 0), 1)
        let x = min(width - 1, max(0, Int((CGFloat(width) * u).rounded(.down))))
        let y = min(height - 1, max(0, Int((CGFloat(height) * v).rounded(.down))))

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return fallback
        }

        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 4)
        let offset = y * cgImage.bytesPerRow + x * bytesPerPixel

        return Color(
            .sRGB,
            red: Double(bytes[offset]) / 255,
            green: Double(bytes[offset + 1]) / 255,
            blue: Double(bytes[offset + 2]) / 255,
            opacity: Double(bytes[offset + 3]) / 255
        )
    }

    static func croppedSurface(
        _ surface: UIImage,
        normalizedCrop: CGRect
    ) -> UIImage? {
        guard normalizedCrop.width > 0,
              normalizedCrop.height > 0,
              let cgImage = surface.cgImage else {
            return nil
        }

        let pixelRect = CGRect(
            x: normalizedCrop.minX * CGFloat(cgImage.width),
            y: normalizedCrop.minY * CGFloat(cgImage.height),
            width: normalizedCrop.width * CGFloat(cgImage.width),
            height: normalizedCrop.height * CGFloat(cgImage.height)
        ).integral

        guard pixelRect.width > 0,
              pixelRect.height > 0,
              let cropped = cgImage.cropping(to: pixelRect) else {
            return nil
        }

        return UIImage(
            cgImage: cropped,
            scale: surface.scale,
            orientation: surface.imageOrientation
        )
    }

    static func drawVisibleCrop(
        of surface: UIImage,
        normalizedCrop: CGRect,
        in destinationRect: CGRect
    ) {
        guard destinationRect.width > 0,
              destinationRect.height > 0,
              let cropped = croppedSurface(surface, normalizedCrop: normalizedCrop) else {
            return
        }
        cropped.draw(in: destinationRect)
    }

    private static func renderSurface(
        sourceImage: UIImage,
        width: Int,
        height: Int,
        blurAmount: Double,
        blurRadius: CGFloat,
        backgroundColor: Color,
        dotColor: Color,
        cacheKey: String
    ) -> UIImage? {
        let damage = HalftoneMath.clamp(blurAmount / 40, min: 0, max: 1)
        let dotStep = max(4, Int((5 + damage * 3).rounded()))
        let sampleWidth = max(1, Int(ceil(Double(width) / Double(dotStep))))
        let sampleHeight = max(1, Int(ceil(Double(height) / Double(dotStep))))

        let paperColor = HalftoneColor.resolvedPaperColor(backgroundColor)
        let dotRGB = HalftoneColor.halftoneDotColor(dotColor)
        let overscan = Int(ceil((blurRadius + damage * 2) * 2))
        let overscanCells = Int(ceil(Double(overscan) / Double(dotStep)))

        guard let samplePixels = makeBlurredSamplePixels(
            sourceImage: sourceImage,
            sampleWidth: sampleWidth,
            sampleHeight: sampleHeight,
            paperColor: paperColor,
            dotStep: dotStep,
            overscanCells: overscanCells,
            blurRadius: blurRadius,
            damage: damage
        ) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(paperColor.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.setBlendMode(.multiply)

            var random = HalftoneSeededRandom(seed: HalftoneHash.fnv1a(cacheKey))

            for row in 0..<sampleHeight {
                for column in 0..<sampleWidth {
                    let index = (row * sampleWidth + column) * 4
                    let red = CGFloat(samplePixels[index])
                    let green = CGFloat(samplePixels[index + 1])
                    let blue = CGFloat(samplePixels[index + 2])

                    let luminance = HalftoneMath.posterize(
                        HalftoneMath.clamp(
                            (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255,
                            min: 0,
                            max: 1
                        ),
                        levels: 5
                    )
                    let darkness = 1 - luminance
                    let missing = random.next() < damage * 0.03 && darkness < 0.75
                    if darkness < 0.07 || missing {
                        continue
                    }

                    let centerX = CGFloat(column * dotStep) + CGFloat(dotStep) / 2
                    let centerY = CGFloat(row * dotStep) + CGFloat(dotStep) / 2
                    let baseRadius = CGFloat(dotStep) * (0.34 + min(darkness, 0.85) * 0.1)
                    let posterLevel = (darkness * 4).rounded() / 4
                    let alpha = HalftoneMath.clamp(0.24 + posterLevel * 0.72, min: 0, max: 0.92)
                    let jitterX = (random.next() - 0.5) * damage * 0.9
                    let jitterY = (random.next() - 0.5) * damage * 0.9

                    drawHalftoneDot(
                        in: context,
                        center: CGPoint(x: centerX + jitterX, y: centerY + jitterY),
                        radius: baseRadius,
                        color: dotRGB,
                        alpha: alpha
                    )

                    if random.next() < damage * 0.018 * darkness {
                        let scatterRadius = CGFloat(dotStep) * 0.18
                        drawHalftoneDot(
                            in: context,
                            center: CGPoint(
                                x: centerX + (random.next() - 0.5) * CGFloat(dotStep) * 2.4,
                                y: centerY + (random.next() - 0.5) * CGFloat(dotStep) * 2.4
                            ),
                            radius: scatterRadius,
                            color: dotRGB,
                            alpha: 0.45
                        )
                    }
                }
            }

            context.setBlendMode(.normal)
            context.setFillColor(HalftoneColor.hazeColor(backgroundColor).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private static func makeBlurredSamplePixels(
        sourceImage: UIImage,
        sampleWidth: Int,
        sampleHeight: Int,
        paperColor: UIColor,
        dotStep: Int,
        overscanCells: Int,
        blurRadius: CGFloat,
        damage: Double
    ) -> [UInt8]? {
        let drawWidth = sampleWidth + overscanCells * 2
        let drawHeight = sampleHeight + overscanCells * 2
        let drawOriginX = -overscanCells
        let drawOriginY = -overscanCells

        let drawRect = CGRect(
            x: CGFloat(drawOriginX),
            y: CGFloat(drawOriginY),
            width: CGFloat(drawWidth),
            height: CGFloat(drawHeight)
        )

        let sampleFormat = UIGraphicsImageRendererFormat()
        sampleFormat.scale = 1
        sampleFormat.opaque = true
        let sampleRenderer = UIGraphicsImageRenderer(
            size: CGSize(width: sampleWidth, height: sampleHeight),
            format: sampleFormat
        )
        let sampleUIImage = sampleRenderer.image { _ in
            paperColor.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            sourceImage.draw(in: drawRect)
        }

        guard let sampleImage = sampleUIImage.cgImage else { return nil }

        let filterRadius = blurRadius * 0.18 + damage * 0.55
        let sampleForPixels: CGImage
        if filterRadius < 0.75 {
            sampleForPixels = sampleImage
        } else if let blurred = applyGaussianBlur(
            to: sampleImage,
            radius: max(0.4, filterRadius)
        ) {
            sampleForPixels = blurred
        } else {
            sampleForPixels = sampleImage
        }

        return readRGBABytes(from: sampleForPixels)
    }

    private static func applyGaussianBlur(to image: CGImage, radius: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return image }
        let extent = input.extent
        return ciContext.createCGImage(output.cropped(to: extent), from: extent)
    }

    private static func readRGBABytes(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func drawHalftoneDot(
        in context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        color: (r: Int, g: Int, b: Int),
        alpha: CGFloat
    ) {
        guard radius > 0, alpha > 0 else { return }

        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.setFillColor(
            red: CGFloat(color.r) / 255,
            green: CGFloat(color.g) / 255,
            blue: CGFloat(color.b) / 255,
            alpha: HalftoneMath.clamp(alpha, min: 0, max: 1)
        )
        context.fillEllipse(in: rect)
    }
}

private nonisolated enum HalftoneMath {
    static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.min(Swift.max(value, min), max)
    }

    static func posterize(_ value: CGFloat, levels: Int) -> CGFloat {
        let safeLevels = max(2, levels)
        let clamped = clamp(value, min: 0, max: 1)
        return (clamped * CGFloat(safeLevels - 1)).rounded() / CGFloat(safeLevels - 1)
    }
}

private nonisolated enum HalftoneHash {
    static func fnv1a(_ value: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }
}

private nonisolated struct HalftoneSeededRandom {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> Double {
        state = state &+ 0x6d2b_79f5
        var t = imul32(state ^ (state >> 15), 1 | state)
        t ^= t &+ imul32(t ^ (t >> 7), 61 | state)
        return Double((t ^ (t >> 14)) >> 0) / 4_294_967_296
    }

    private func imul32(_ left: UInt32, _ right: UInt32) -> UInt32 {
        UInt32(truncatingIfNeeded: Int32(bitPattern: left) &* Int32(bitPattern: right))
    }
}

private nonisolated enum HalftoneColor {
    static func resolvedPaperColor(_ color: Color) -> UIColor {
        if let rgb = rgbComponents(color) {
            return UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        }
        return uiColor(hex: PuzzleHalftoneBackgroundMetrics.defaultPaperHex)
    }

    static func hazeColor(_ color: Color) -> UIColor {
        guard let rgb = rgbComponents(color) else {
            return UIColor(red: 245 / 255, green: 242 / 255, blue: 232 / 255, alpha: 0.12)
        }
        return UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 0.12)
    }

    static func halftoneDotColor(_ color: Color) -> (r: Int, g: Int, b: Int) {
        let base = rgbComponents(color) ?? (r: 0, g: 70 / 255.0, b: 1)
        let darkenAmount = 0.32
        return (
            r: Int((base.r * (1 - darkenAmount) * 255).rounded()),
            g: Int((base.g * (1 - darkenAmount) * 255).rounded()),
            b: Int((base.b * (1 - darkenAmount) * 255).rounded())
        )
    }

    static func hexString(_ color: Color) -> String? {
        guard let rgb = rgbComponents(color) else { return nil }
        let r = Int((rgb.r * 255).rounded())
        let g = Int((rgb.g * 255).rounded())
        let b = Int((rgb.b * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    private static func rgbComponents(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              alpha > 0.001 else {
            return nil
        }
        return (red, green, blue)
    }

    private static func uiColor(hex hexString: String) -> UIColor {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xff) / 255
            g = CGFloat((int >> 8) & 0xff) / 255
            b = CGFloat(int & 0xff) / 255
        default:
            r = 240 / 255
            g = 238 / 255
            b = 230 / 255
        }
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}

struct PuzzleHalftoneBackgroundView: View {
    let sourceImage: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    /// Visible extension frame on screen; width changes only crop the full halftone bitmap.
    let displaySize: CGSize
    let backgroundColor: Color
    let dotColor: Color
    var blurAmount: Double = PuzzleHalftoneBackgroundMetrics.defaultBlurAmount

    @State private var fullExtensionImage: UIImage?

    private var visibleCrop: CGRect {
        PuzzleHalftoneBackgroundMetrics.visibleCropNormalizedRect(
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )
    }

    var body: some View {
        Group {
            if let fullExtensionImage, visibleCrop.width > 0, visibleCrop.height > 0 {
                Image(uiImage: fullExtensionImage)
                    .resizable()
                    .interpolation(.medium)
                    .frame(
                        width: cropDisplayWidth(for: fullExtensionImage),
                        height: cropDisplayHeight(for: fullExtensionImage),
                        alignment: PuzzleHalftoneBackgroundMetrics.photoAdjacentAlignment(
                            for: extensionSide
                        )
                    )
            } else {
                Color(backgroundColor)
            }
        }
        .frame(
            width: displaySize.width,
            height: displaySize.height,
            alignment: PuzzleHalftoneBackgroundMetrics.photoAdjacentAlignment(for: extensionSide)
        )
        .clipped()
        .task(id: renderTaskID) {
            let renderPixelSize = PuzzleHalftoneBackgroundMetrics.fullExtensionPixelSize(
                imagePixelSize: CanvasImageLoader.pixelSize(for: sourceImage),
                extensionSide: extensionSide
            )
            fullExtensionImage = PuzzleHalftoneBackgroundRenderer.render(
                sourceImage: sourceImage,
                renderPixelSize: renderPixelSize,
                backgroundColor: backgroundColor,
                dotColor: dotColor,
                blurAmount: blurAmount
            )
        }
    }

    private var renderTaskID: String {
        [
            extensionSide.rawValue,
            HalftoneColor.hexString(backgroundColor) ?? "paper",
            HalftoneColor.hexString(dotColor) ?? "dot",
            "\(blurAmount)",
            "\(CanvasImageLoader.pixelSize(for: sourceImage).width)x\(CanvasImageLoader.pixelSize(for: sourceImage).height)",
        ].joined(separator: "|")
    }

    private func cropDisplayWidth(for image: UIImage) -> CGFloat {
        guard visibleCrop.width > 0 else { return displaySize.width }
        return displaySize.width / visibleCrop.width
    }

    private func cropDisplayHeight(for image: UIImage) -> CGFloat {
        guard visibleCrop.height > 0 else { return displaySize.height }
        return displaySize.height / visibleCrop.height
    }
}
