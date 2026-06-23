import CoreGraphics
import CoreImage
import UIKit

// MARK: - Y2K CCD Filter

nonisolated enum Y2KCCDPreset: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case classic
    case cool
    case warm

    var id: Self { self }

    var title: String {
        switch self {
        case .classic:
            "经典"
        case .cool:
            "冷色调"
        case .warm:
            "暖色调"
        }
    }
}

nonisolated struct Y2KCCDResolvedParameters: Equatable, Hashable, Sendable {
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
}

nonisolated struct Y2KCCDFilterSettings: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var preset: Y2KCCDPreset
    var intensity: Double
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
        preset: .classic,
        intensity: 1,
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
        preset: Y2KCCDPreset = .classic,
        intensity: Double = 1,
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
        self.preset = preset
        self.intensity = intensity
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
        case preset
        case intensity
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
        preset = try container.decodeIfPresent(Y2KCCDPreset.self, forKey: .preset) ?? .classic
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity) ?? 1
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
        try container.encode(preset, forKey: .preset)
        try container.encode(intensity, forKey: .intensity)
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

    nonisolated var resolvedParameters: Y2KCCDResolvedParameters {
        let strength = Self.unit(intensity)
        let parameters = Self.parameters(for: preset)

        return Y2KCCDResolvedParameters(
            downsample: Self.unit(parameters.downsample * strength),
            bloom: Self.unit(parameters.bloom * strength),
            bloomThreshold: Self.unit(parameters.bloomThreshold),
            noise: Self.unit(parameters.noise * strength),
            chromaNoise: Self.unit(parameters.chromaNoise * strength),
            jpegArtifacts: Self.unit(parameters.jpegArtifacts * strength),
            sharpen: Self.unit(parameters.sharpen * strength),
            exposure: Self.signedUnit(parameters.exposure * strength),
            temperature: Self.signedUnit(parameters.temperature * strength),
            tint: Self.signedUnit(parameters.tint * strength),
            contrast: Self.signedUnit(parameters.contrast * strength),
            saturation: 1 + (parameters.saturation - 1) * strength,
            highlightClip: Self.unit(parameters.highlightClip),
            rgbShift: Self.unit(parameters.rgbShift * strength)
        )
    }

    nonisolated var cacheKey: String {
        let parameters = resolvedParameters
        return [
            enabled ? "1" : "0",
            preset.rawValue,
            Self.unit(intensity).fixed3,
            parameters.downsample.fixed3,
            parameters.bloom.fixed3,
            parameters.bloomThreshold.fixed3,
            parameters.noise.fixed3,
            parameters.chromaNoise.fixed3,
            parameters.jpegArtifacts.fixed3,
            parameters.sharpen.fixed3,
            parameters.exposure.fixed3,
            parameters.temperature.fixed3,
            parameters.tint.fixed3,
            parameters.contrast.fixed3,
            parameters.saturation.fixed3,
            parameters.highlightClip.fixed3,
            parameters.rgbShift.fixed3
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

    private nonisolated static func parameters(for preset: Y2KCCDPreset) -> Y2KCCDResolvedParameters {
        switch preset {
        case .classic:
            Y2KCCDResolvedParameters(
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
        case .cool:
            Y2KCCDResolvedParameters(
                downsample: 0.24,
                bloom: 0.55,
                bloomThreshold: 0.72,
                noise: 0.22,
                chromaNoise: 0.12,
                jpegArtifacts: 0.24,
                sharpen: 0.72,
                exposure: 0.14,
                temperature: -0.8,
                tint: -0.26,
                contrast: 0.18,
                saturation: 0.92,
                highlightClip: 0.78,
                rgbShift: 0.18
            )
        case .warm:
            Y2KCCDResolvedParameters(
                downsample: 0.18,
                bloom: 0.66,
                bloomThreshold: 0.68,
                noise: 0.18,
                chromaNoise: 0.09,
                jpegArtifacts: 0.18,
                sharpen: 0.64,
                exposure: 0.22,
                temperature: 0.34,
                tint: 0.12,
                contrast: 0.12,
                saturation: 1.12,
                highlightClip: 0.82,
                rgbShift: 0.12
            )
        }
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

        let parameters = settings.resolvedParameters
        guard let lowImage = makeLowDefinitionImage(
            from: image,
            size: renderSize,
            downsample: parameters.downsample
        ) else {
            return nil
        }

        let tonedImage = applyLofiTone(to: lowImage, parameters: parameters) ?? lowImage
        let filteredImage = applyJPEGArtifacts(to: tonedImage, strength: parameters.jpegArtifacts)
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
        parameters: Y2KCCDResolvedParameters
    ) -> UIImage? {
        guard let sourceCGImage = image.cgImage else { return image }
        let source = CIImage(cgImage: sourceCGImage)
        let temperature = Y2KCCDFilterSettings.signedUnit(parameters.temperature)
        let tint = Y2KCCDFilterSettings.signedUnit(parameters.tint)
        let contrast = Y2KCCDFilterSettings.signedUnit(parameters.contrast)
        let exposure = Y2KCCDFilterSettings.signedUnit(parameters.exposure)
        let saturation = min(1.8, max(0.2, parameters.saturation.isFinite ? parameters.saturation : 1))
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
