import CoreGraphics
import CoreImage
import UIKit
import Vision

// MARK: - Subject Glow

nonisolated struct SubjectGlowSettings: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var intensity: Double
    var radius: Double

    nonisolated static let `default` = SubjectGlowSettings(
        enabled: false,
        intensity: 0.85,
        radius: 0.55
    )

    nonisolated var enabledForPanelEditing: SubjectGlowSettings {
        var settings = self
        settings.enabled = true
        return settings
    }

    nonisolated var cacheKey: String {
        [
            enabled ? "1" : "0",
            Self.unit(intensity).fixed3,
            Self.unit(radius).fixed3
        ].joined(separator: ":")
    }

    nonisolated func renderCacheKey(sourceKey: String, pixelSize: CGSize, maskKey: String) -> String {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        return "\(sourceKey)|\(width)x\(height)|\(maskKey)|\(cacheKey)"
    }

    nonisolated func resolvedBlurRadius(for imageSize: CGSize) -> Double {
        let longEdge = max(imageSize.width, imageSize.height)
        let spread = Self.unit(radius)
        let strength = Self.unit(intensity)
        return longEdge * 0.018 * ((0.45 + spread * 0.85) + strength * 0.35)
    }

    fileprivate nonisolated static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

nonisolated final class SubjectGlowCache {
    private let maxEntries: Int
    private var imageEntries: [String: UIImage] = [:]
    private var imageKeys: [String] = []
    private var maskEntries: [String: SubjectMask] = [:]
    private var maskKeys: [String] = []
    private let lock = NSLock()

    init(maxEntries: Int = 8) {
        self.maxEntries = max(1, maxEntries)
    }

    nonisolated func image(for key: String) -> UIImage? {
        lock.withLock {
            guard let image = imageEntries[key] else { return nil }
            imageKeys.removeAll { $0 == key }
            imageKeys.append(key)
            return image
        }
    }

    nonisolated func setImage(_ image: UIImage, for key: String) {
        lock.withLock {
            if imageEntries[key] != nil {
                imageKeys.removeAll { $0 == key }
            }
            imageEntries[key] = image
            imageKeys.append(key)
            trimEntries(&imageEntries, keys: &imageKeys)
        }
    }

    nonisolated func mask(for key: String) -> SubjectMask? {
        lock.withLock {
            guard let mask = maskEntries[key] else { return nil }
            maskKeys.removeAll { $0 == key }
            maskKeys.append(key)
            return mask
        }
    }

    nonisolated func setMask(_ mask: SubjectMask, for key: String) {
        lock.withLock {
            if maskEntries[key] != nil {
                maskKeys.removeAll { $0 == key }
            }
            maskEntries[key] = mask
            maskKeys.append(key)
            trimEntries(&maskEntries, keys: &maskKeys)
        }
    }

    nonisolated func clear() {
        lock.withLock {
            imageEntries.removeAll()
            imageKeys.removeAll()
            maskEntries.removeAll()
            maskKeys.removeAll()
        }
    }

    private nonisolated func trimEntries<T>(_ entries: inout [String: T], keys: inout [String]) {
        while keys.count > maxEntries, let oldest = keys.first {
            keys.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }
}

nonisolated enum SubjectGlowPreviewRenderPolicy {
    nonisolated static let maxLongEdge: CGFloat = 720
    nonisolated static let refreshDebounce: Duration = .milliseconds(120)

    nonisolated static func pixelSize(for sourcePixelSize: CGSize) -> CGSize {
        let longEdge = max(sourcePixelSize.width, sourcePixelSize.height)
        guard longEdge > maxLongEdge else { return sourcePixelSize }

        let scale = maxLongEdge / longEdge
        return CGSize(
            width: max(1, (sourcePixelSize.width * scale).rounded()),
            height: max(1, (sourcePixelSize.height * scale).rounded())
        )
    }
}

nonisolated enum SubjectGlowRenderer {
    private nonisolated static let maskProvider = VisionSubjectMaskProvider()
    private nonisolated static let ciContextBox = SubjectGlowCIContextBox()
    private nonisolated static let maskExpansionLongEdgeScale: CGFloat = 0.015
    private nonisolated static let minimumMaskExpansion: CGFloat = 2

    nonisolated static func render(
        image: UIImage,
        settings: SubjectGlowSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        cache: SubjectGlowCache? = nil
    ) async -> UIImage? {
        guard settings.enabled else { return nil }

        let inputSize = CanvasImageLoader.pixelSize(for: image)
        let pixelSize = targetPixelSize ?? inputSize
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let renderSize = CGSize(width: width, height: height)
        let maskKey = "\(sourceKey)-mask"
        let cacheKey = settings.renderCacheKey(
            sourceKey: sourceKey,
            pixelSize: renderSize,
            maskKey: maskKey
        )

        if let cached = cache?.image(for: cacheKey) {
            return cached
        }

        let mask: SubjectMask
        if let cachedMask = cache?.mask(for: maskKey) {
            mask = cachedMask
        } else {
            do {
                let detectedMask = try await maskProvider.subjectMask(for: image)
                cache?.setMask(detectedMask, for: maskKey)
                mask = detectedMask
            } catch {
                return nil
            }
        }

        return render(
            image: image,
            mask: mask,
            settings: settings,
            targetPixelSize: targetPixelSize,
            sourceKey: sourceKey,
            cache: cache
        )
    }

    nonisolated static func render(
        image: UIImage,
        mask: SubjectMask,
        settings: SubjectGlowSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        cache: SubjectGlowCache? = nil
    ) -> UIImage? {
        guard settings.enabled else { return nil }

        let inputSize = CanvasImageLoader.pixelSize(for: image)
        let pixelSize = targetPixelSize ?? inputSize
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let renderSize = CGSize(width: width, height: height)
        let maskKey = "\(sourceKey)-mask"
        let cacheKey = settings.renderCacheKey(
            sourceKey: sourceKey,
            pixelSize: renderSize,
            maskKey: maskKey
        )

        if let cached = cache?.image(for: cacheKey) {
            return cached
        }

        guard let rendered = applyGlow(
            to: image,
            mask: mask,
            settings: settings,
            renderSize: renderSize
        ) else {
            return nil
        }

        cache?.setMask(mask, for: maskKey)
        cache?.setImage(rendered, for: cacheKey)
        return rendered
    }

    private nonisolated static func applyGlow(
        to image: UIImage,
        mask: SubjectMask,
        settings: SubjectGlowSettings,
        renderSize: CGSize
    ) -> UIImage? {
        guard let maskCGImage = mask.grayscaleCGImage(targetSize: renderSize) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let whiteSilhouette = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            context.cgContext.clip(to: CGRect(origin: .zero, size: renderSize), mask: maskCGImage)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: renderSize))
        }

        guard let silhouetteCGImage = whiteSilhouette.cgImage else { return nil }

        let source = CIImage(cgImage: silhouetteCGImage)
        let maskExpansion = resolvedMaskExpansion(for: renderSize)
        let expandedMask = source
            .applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: maskExpansion
            ])
            .cropped(to: source.extent)
        guard let expandedMaskCGImage = ciContextBox.context.createCGImage(expandedMask, from: source.extent) else {
            return nil
        }

        let transparentFormat = UIGraphicsImageRendererFormat()
        transparentFormat.scale = 1
        transparentFormat.opaque = false

        let rect = CGRect(origin: .zero, size: renderSize)
        let expandedSilhouette = UIGraphicsImageRenderer(size: renderSize, format: transparentFormat).image { context in
            context.cgContext.clip(to: rect, mask: expandedMaskCGImage)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(rect)
        }

        let blurRadius = settings.resolvedBlurRadius(for: renderSize)
        let exteriorGlowImage = UIGraphicsImageRenderer(size: renderSize, format: transparentFormat).image { context in
            Self.drawRadialGlow(
                expandedSilhouette,
                in: rect,
                blurRadius: blurRadius
            )
            context.cgContext.setBlendMode(.clear)
            context.cgContext.clip(to: rect, mask: expandedMaskCGImage)
            context.cgContext.clear(rect)
        }

        return UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            image.draw(in: rect)
            exteriorGlowImage.draw(
                in: rect,
                blendMode: .screen,
                alpha: 1
            )
        }
    }

    private nonisolated static func resolvedMaskExpansion(for renderSize: CGSize) -> CGFloat {
        let longEdge = max(renderSize.width, renderSize.height)
        guard longEdge.isFinite, longEdge > 0 else { return minimumMaskExpansion }
        return max(minimumMaskExpansion, longEdge * maskExpansionLongEdgeScale)
    }

    private nonisolated static func drawRadialGlow(
        _ silhouette: UIImage,
        in rect: CGRect,
        blurRadius: CGFloat
    ) {
        let radius = max(1, blurRadius)
        let steps = max(2, min(18, Int(radius.rounded(.up))))
        let directions = 16

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let distance = radius * progress
            let alpha = CGFloat(pow(Double(1 - progress), 1.6)) * 0.2

            for direction in 0..<directions {
                let angle = (Double(direction) / Double(directions)) * (Double.pi * 2)
                let offsetRect = rect.offsetBy(
                    dx: CGFloat(cos(angle)) * distance,
                    dy: CGFloat(sin(angle)) * distance
                )
                silhouette.draw(in: offsetRect, blendMode: .normal, alpha: alpha)
            }
        }
    }
}

nonisolated enum CanvasStyledPhotoRenderer {
    nonisolated static func render(
        image: UIImage,
        subjectGlowSettings: SubjectGlowSettings,
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        subjectGlowMask: SubjectMask? = nil,
        subjectGlowCache: SubjectGlowCache? = nil,
        y2kCCDCache: Y2KCCDFilterCache? = nil,
        asciiArtSettings: ASCIIArtSettings = .default,
        asciiArtMask: SubjectMask? = nil,
        asciiArtCache: ASCIIArtCache? = nil
    ) async -> UIImage {
        var result = image

        if subjectGlowSettings.enabled {
            if let mask = subjectGlowMask,
               let glowed = SubjectGlowRenderer.render(
                   image: result,
                   mask: mask,
                   settings: subjectGlowSettings,
                   targetPixelSize: targetPixelSize,
                   sourceKey: "\(sourceKey)-glow",
                   cache: subjectGlowCache
               ) {
                result = glowed
            } else if let glowed = await SubjectGlowRenderer.render(
                image: result,
                settings: subjectGlowSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-glow",
                cache: subjectGlowCache
            ) {
                result = glowed
            }
        }

        if y2kCCDFilterSettings.enabled {
            if let filtered = Y2KCCDFilterRenderer.render(
                image: result,
                settings: y2kCCDFilterSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ccd",
                cache: y2kCCDCache
            ) {
                result = filtered
            }
        }

        if asciiArtSettings.enabled {
            if let mask = asciiArtMask,
               let art = ASCIIArtRenderer.render(
                   image: result,
                   mask: mask,
                   settings: asciiArtSettings,
                   targetPixelSize: targetPixelSize,
                   sourceKey: "\(sourceKey)-ascii",
                   cache: asciiArtCache
               ) {
                result = art
            } else if let art = await ASCIIArtRenderer.render(
                image: result,
                settings: asciiArtSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ascii",
                cache: asciiArtCache
            ) {
                result = art
            }
        }

        return result
    }

    nonisolated static func renderSync(
        image: UIImage,
        subjectGlowSettings: SubjectGlowSettings,
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        subjectGlowMask: SubjectMask?,
        subjectGlowCache: SubjectGlowCache? = nil,
        y2kCCDCache: Y2KCCDFilterCache? = nil,
        asciiArtSettings: ASCIIArtSettings = .default,
        asciiArtMask: SubjectMask? = nil,
        asciiArtCache: ASCIIArtCache? = nil
    ) -> UIImage {
        var result = image

        if subjectGlowSettings.enabled, let subjectGlowMask {
            if let glowed = SubjectGlowRenderer.render(
                image: result,
                mask: subjectGlowMask,
                settings: subjectGlowSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-glow",
                cache: subjectGlowCache
            ) {
                result = glowed
            }
        }

        if y2kCCDFilterSettings.enabled {
            if let filtered = Y2KCCDFilterRenderer.render(
                image: result,
                settings: y2kCCDFilterSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ccd",
                cache: y2kCCDCache
            ) {
                result = filtered
            }
        }

        if asciiArtSettings.enabled, let asciiArtMask {
            if let art = ASCIIArtRenderer.render(
                image: result,
                mask: asciiArtMask,
                settings: asciiArtSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ascii",
                cache: asciiArtCache
            ) {
                result = art
            }
        }

        return result
    }

    nonisolated static func styledPreviewEnabled(
        subjectGlowSettings: SubjectGlowSettings,
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        asciiArtSettings: ASCIIArtSettings = .default
    ) -> Bool {
        subjectGlowSettings.enabled || y2kCCDFilterSettings.enabled || asciiArtSettings.enabled
    }
}

extension SubjectMask {
    nonisolated func grayscaleCGImage(targetSize: CGSize) -> CGImage? {
        guard width > 0, height > 0 else { return nil }

        let targetWidth = max(1, Int(targetSize.width.rounded()))
        let targetHeight = max(1, Int(targetSize.height.rounded()))

        var gray = [UInt8](repeating: 0, count: width * height)
        for index in pixels.indices {
            gray[index] = pixels[index] ? 255 : 0
        }

        guard let provider = CGDataProvider(data: Data(gray) as CFData) else { return nil }
        guard let nativeMask = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }

        if targetWidth == width, targetHeight == height {
            return nativeMask
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(
            size: CGSize(width: targetWidth, height: targetHeight),
            format: format
        ).image { context in
            context.cgContext.interpolationQuality = .medium
            context.cgContext.draw(
                nativeMask,
                in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
            )
        }.cgImage
    }
}

private final class SubjectGlowCIContextBox: @unchecked Sendable {
    nonisolated init() {}

    let context = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB()
    ])
}

private extension Double {
    nonisolated var fixed3: String {
        String(format: "%.3f", self)
    }
}
