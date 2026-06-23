import CoreGraphics
import CoreImage
import UIKit

// MARK: - Y2K CCD Filter

nonisolated struct Y2KCCDFilterSettings: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var downsample: Double
    var bloom: Double
    var bloomThreshold: Double
    var noise: Double
    var chromaNoise: Double
    var jpegArtifacts: Double
    var sharpen: Double
    var exposure: Double
    var temperature: Double
    var tint: Double
    var contrast: Double
    var saturation: Double
    var highlightClip: Double
    var rgbShift: Double

    nonisolated static let `default` = Y2KCCDFilterSettings(
        enabled: false,
        downsample: 0.2,
        bloom: 0.6,
        bloomThreshold: 0.7,
        noise: 0.2,
        chromaNoise: 0.1,
        jpegArtifacts: 0.2,
        sharpen: 0.7,
        exposure: 0.18,
        temperature: -0.65,
        tint: -0.2,
        contrast: 0.15,
        saturation: 1.0,
        highlightClip: 0.8,
        rgbShift: 0.15
    )

    nonisolated init(
        enabled: Bool,
        downsample: Double,
        bloom: Double,
        bloomThreshold: Double,
        noise: Double,
        chromaNoise: Double,
        jpegArtifacts: Double,
        sharpen: Double,
        exposure: Double = 0,
        temperature: Double,
        tint: Double,
        contrast: Double,
        saturation: Double,
        highlightClip: Double,
        rgbShift: Double
    ) {
        self.enabled = enabled
        self.downsample = downsample
        self.bloom = bloom
        self.bloomThreshold = bloomThreshold
        self.noise = noise
        self.chromaNoise = chromaNoise
        self.jpegArtifacts = jpegArtifacts
        self.sharpen = sharpen
        self.exposure = exposure
        self.temperature = temperature
        self.tint = tint
        self.contrast = contrast
        self.saturation = saturation
        self.highlightClip = highlightClip
        self.rgbShift = rgbShift
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case downsample
        case bloom
        case bloomThreshold
        case noise
        case chromaNoise
        case jpegArtifacts
        case sharpen
        case exposure
        case temperature
        case tint
        case contrast
        case saturation
        case highlightClip
        case rgbShift
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        downsample = try container.decode(Double.self, forKey: .downsample)
        bloom = try container.decode(Double.self, forKey: .bloom)
        bloomThreshold = try container.decode(Double.self, forKey: .bloomThreshold)
        noise = try container.decode(Double.self, forKey: .noise)
        chromaNoise = try container.decode(Double.self, forKey: .chromaNoise)
        jpegArtifacts = try container.decode(Double.self, forKey: .jpegArtifacts)
        sharpen = try container.decode(Double.self, forKey: .sharpen)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure)
            ?? Y2KCCDFilterSettings.default.exposure
        temperature = try container.decode(Double.self, forKey: .temperature)
        tint = try container.decode(Double.self, forKey: .tint)
        contrast = try container.decode(Double.self, forKey: .contrast)
        saturation = try container.decode(Double.self, forKey: .saturation)
        highlightClip = try container.decode(Double.self, forKey: .highlightClip)
        rgbShift = try container.decode(Double.self, forKey: .rgbShift)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(downsample, forKey: .downsample)
        try container.encode(bloom, forKey: .bloom)
        try container.encode(bloomThreshold, forKey: .bloomThreshold)
        try container.encode(noise, forKey: .noise)
        try container.encode(chromaNoise, forKey: .chromaNoise)
        try container.encode(jpegArtifacts, forKey: .jpegArtifacts)
        try container.encode(sharpen, forKey: .sharpen)
        try container.encode(exposure, forKey: .exposure)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(tint, forKey: .tint)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(highlightClip, forKey: .highlightClip)
        try container.encode(rgbShift, forKey: .rgbShift)
    }

    nonisolated var enabledForPanelEditing: Y2KCCDFilterSettings {
        var settings = self
        settings.enabled = true
        return settings
    }

    nonisolated var cacheKey: String {
        [
            enabled ? "1" : "0",
            Self.unit(downsample).fixed3,
            Self.unit(bloom).fixed3,
            Self.unit(bloomThreshold).fixed3,
            Self.unit(noise).fixed3,
            Self.unit(chromaNoise).fixed3,
            Self.unit(jpegArtifacts).fixed3,
            Self.unit(sharpen).fixed3,
            Self.signedUnit(exposure).fixed3,
            Self.signedUnit(temperature).fixed3,
            Self.signedUnit(tint).fixed3,
            Self.signedUnit(contrast).fixed3,
            Self.unit(saturation).fixed3,
            Self.unit(highlightClip).fixed3,
            Self.unit(rgbShift).fixed3
        ].joined(separator: ":")
    }

    nonisolated func renderCacheKey(sourceKey: String, pixelSize: CGSize) -> String {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        return "\(sourceKey)|\(width)x\(height)|\(cacheKey)"
    }

    fileprivate nonisolated static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    fileprivate nonisolated static func signedUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(-1, value))
    }
}

nonisolated final class Y2KCCDFilterCache {
    private let maxEntries: Int
    private var entries: [String: UIImage] = [:]
    private var keys: [String] = []
    private let lock = NSLock()

    init(maxEntries: Int = 8) {
        self.maxEntries = max(1, maxEntries)
    }

    nonisolated func image(for key: String) -> UIImage? {
        lock.withLock {
            guard let image = entries[key] else { return nil }
            keys.removeAll { $0 == key }
            keys.append(key)
            return image
        }
    }

    nonisolated func setImage(_ image: UIImage, for key: String) {
        lock.withLock {
            if entries[key] != nil {
                keys.removeAll { $0 == key }
            }
            entries[key] = image
            keys.append(key)

            while keys.count > maxEntries, let oldest = keys.first {
                keys.removeFirst()
                entries.removeValue(forKey: oldest)
            }
        }
    }

    nonisolated func clear() {
        lock.withLock {
            entries.removeAll()
            keys.removeAll()
        }
    }
}

nonisolated enum Y2KCCDPreviewRenderPolicy {
    nonisolated static let maxLongEdge: CGFloat = 720
    nonisolated static let refreshDebounce: Duration = .milliseconds(90)

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

nonisolated enum Y2KCCDFilterRenderer {
    private nonisolated static let ciContextBox = Y2KCCDFilterCIContextBox()

    nonisolated static func render(
        image: UIImage,
        settings: Y2KCCDFilterSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        cache: Y2KCCDFilterCache? = nil
    ) -> UIImage? {
        guard settings.enabled else { return nil }

        let inputSize = CanvasImageLoader.pixelSize(for: image)
        let pixelSize = targetPixelSize ?? inputSize
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let renderSize = CGSize(width: width, height: height)
        let cacheKey = settings.renderCacheKey(sourceKey: sourceKey, pixelSize: renderSize)

        if let cached = cache?.image(for: cacheKey) {
            return cached
        }

        guard let lowImage = makeLowDefinitionImage(
            from: image,
            size: renderSize,
            downsample: settings.downsample
        ) else {
            return nil
        }

        let tonedImage = applyLofiTone(to: lowImage, settings: settings) ?? lowImage
        let filteredImage = applyJPEGArtifacts(to: tonedImage, strength: settings.jpegArtifacts)
            ?? tonedImage

        cache?.setImage(filteredImage, for: cacheKey)
        return filteredImage
    }

    private nonisolated static func makeLowDefinitionImage(
        from image: UIImage,
        size: CGSize,
        downsample: Double
    ) -> UIImage? {
        let normalizedDownsample = Y2KCCDFilterSettings.unit(downsample)
        let scale = min(1, max(0.86, 1 - normalizedDownsample * 0.20))
        if scale >= 0.965 {
            return image
        }

        let lowSize = CGSize(
            width: max(1, Int((size.width * scale).rounded())),
            height: max(1, Int((size.height * scale).rounded()))
        )
        let lowFormat = UIGraphicsImageRendererFormat()
        lowFormat.scale = 1
        lowFormat.opaque = true

        let lowRenderer = UIGraphicsImageRenderer(size: lowSize, format: lowFormat)
        let lowImage = lowRenderer.image { context in
            context.cgContext.interpolationQuality = .medium
            image.draw(in: CGRect(origin: .zero, size: lowSize))
        }

        let finalRenderer = UIGraphicsImageRenderer(size: size, format: lowFormat)
        return finalRenderer.image { context in
            context.cgContext.interpolationQuality = upscaleInterpolationQuality(
                for: normalizedDownsample
            )
            lowImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private nonisolated static func upscaleInterpolationQuality(
        for normalizedDownsample: Double
    ) -> CGInterpolationQuality {
        if normalizedDownsample >= 0.72 {
            return .none
        }
        if normalizedDownsample >= 0.38 {
            return .low
        }
        return .medium
    }

    private nonisolated static func applyLofiTone(
        to image: UIImage,
        settings: Y2KCCDFilterSettings
    ) -> UIImage? {
        guard let sourceCGImage = image.cgImage else { return image }
        let source = CIImage(cgImage: sourceCGImage)
        let temperature = Y2KCCDFilterSettings.signedUnit(settings.temperature)
        let tint = Y2KCCDFilterSettings.signedUnit(settings.tint)
        let contrast = Y2KCCDFilterSettings.signedUnit(settings.contrast)
        let exposure = Y2KCCDFilterSettings.signedUnit(settings.exposure)
        let saturation = min(1.8, max(0.2, settings.saturation.isFinite ? settings.saturation : 1))
        let colorControls = source.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: saturation,
            kCIInputBrightnessKey: exposure * 0.24,
            kCIInputContrastKey: 1 + contrast * 0.55
        ])
        let tone = colorControls.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1 + temperature * 0.08 + max(tint, 0) * 0.04, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1 - tint * 0.06, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1 - temperature * 0.08 + max(-tint, 0) * 0.04, w: 0)
        ])

        guard let cgImage = ciContextBox.context.createCGImage(tone, from: source.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// 低质量 JPEG 往返，保留分辨率但带回 8×8 块状伪影。
    private nonisolated static func applyJPEGArtifacts(
        to image: UIImage,
        strength: Double
    ) -> UIImage? {
        let normalizedStrength = Y2KCCDFilterSettings.unit(strength)
        guard normalizedStrength > 0.001 else { return image }

        let compressionQuality = CGFloat(max(0.42, 0.98 - normalizedStrength * 0.72))
        guard let data = image.jpegData(compressionQuality: compressionQuality),
              let decoded = UIImage(data: data) else {
            return image
        }
        return decoded
    }
}

private final class Y2KCCDFilterCIContextBox: @unchecked Sendable {
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
