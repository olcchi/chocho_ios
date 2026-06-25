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
        downsample: 0.32,
        bloom: 0.6,
        bloomThreshold: 0.7,
        noise: 0.38,
        chromaNoise: 0.18,
        jpegArtifacts: 0.36,
        sharpen: 0.72,
        exposure: 0.14,
        temperature: -0.2,
        tint: 0,
        contrast: 0.12,
        saturation: 0.96,
        highlightClip: 0.72,
        rgbShift: 0.28
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
            // 经典：清透 lofi，画质有 CCD 颗粒/JPEG 块感，但白平衡基本端正、只带极轻冷调
            Y2KCCDResolvedParameters(
                downsample: 0.32,
                bloom: 0.6,
                bloomThreshold: 0.7,
                noise: 0.38,
                chromaNoise: 0.18,
                jpegArtifacts: 0.36,
                sharpen: 0.72,
                exposure: 0.14,
                temperature: -0.2,
                tint: 0,
                contrast: 0.12,
                saturation: 0.96,
                highlightClip: 0.72,
                rgbShift: 0.28
            )
        case .cool:
            // 冷色调：保留 lofi 画质，色彩端正，只比经典再多一点点冷感
            Y2KCCDResolvedParameters(
                downsample: 0.38,
                bloom: 0.55,
                bloomThreshold: 0.72,
                noise: 0.44,
                chromaNoise: 0.22,
                jpegArtifacts: 0.42,
                sharpen: 0.78,
                exposure: 0.08,
                temperature: -0.4,
                tint: 0,
                contrast: 0.14,
                saturation: 0.93,
                highlightClip: 0.68,
                rgbShift: 0.35
            )
        case .warm:
            // 暖色调：保留 lofi 画质，色彩端正，只带轻微暖意
            Y2KCCDResolvedParameters(
                downsample: 0.26,
                bloom: 0.66,
                bloomThreshold: 0.68,
                noise: 0.32,
                chromaNoise: 0.14,
                jpegArtifacts: 0.30,
                sharpen: 0.65,
                exposure: 0.28,
                temperature: 0.3,
                tint: 0.04,
                contrast: 0.1,
                saturation: 1.0,
                highlightClip: 0.62,
                rgbShift: 0.20
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
        let sharpenedImage = applySharpen(to: tonedImage, strength: parameters.sharpen) ?? tonedImage
        let noisyImage = applyNoise(to: sharpenedImage, noise: parameters.noise) ?? sharpenedImage
        let shiftedImage = applyRGBShift(to: noisyImage, strength: parameters.rgbShift) ?? noisyImage
        let filteredImage = applyJPEGArtifacts(to: shiftedImage, strength: parameters.jpegArtifacts)
            ?? shiftedImage

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
        let exposure = Y2KCCDFilterSettings.signedUnit(parameters.exposure)

        // 不做任何白平衡 / 色调 / 饱和度 / 对比度处理，保持色彩完全端正；
        // 仅做极轻微提亮，营造清透感（亮度操作不引入偏色）。
        let tone: CIImage
        if abs(exposure) > 0.001 {
            tone = source.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: exposure * 0.18
            ])
        } else {
            tone = source
        }

        // 高光裁切：CCD 高光溢出，亮度超过阈值后压成纯白（线性渐变到白）
        let highlightClip = Y2KCCDFilterSettings.unit(parameters.highlightClip)
        let clipped: CIImage
        if highlightClip < 0.99 {
            // 阈值以上的像素线性推向白色，模拟 CCD 高光溢出
            let threshold = Float(0.72 + highlightClip * 0.22)  // 0.72–0.94 范围
            let clippedFilter = CIFilter(name: "CIToneCurve")
            let p0 = CIVector(x: 0, y: 0)
            let p1 = CIVector(x: CGFloat(threshold * 0.6), y: CGFloat(threshold * 0.6))
            let p2 = CIVector(x: CGFloat(threshold), y: CGFloat(threshold))
            let p3 = CIVector(x: CGFloat(min(1.0, threshold + 0.08)), y: 1.0)
            let p4 = CIVector(x: 1.0, y: 1.0)
            clippedFilter?.setValue(tone, forKey: kCIInputImageKey)
            clippedFilter?.setValue(p0, forKey: "inputPoint0")
            clippedFilter?.setValue(p1, forKey: "inputPoint1")
            clippedFilter?.setValue(p2, forKey: "inputPoint2")
            clippedFilter?.setValue(p3, forKey: "inputPoint3")
            clippedFilter?.setValue(p4, forKey: "inputPoint4")
            clipped = clippedFilter?.outputImage ?? tone
        } else {
            clipped = tone
        }

        guard let cgImage = ciContextBox.context.createCGImage(clipped, from: source.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// 反锐化蒙版：模拟 CCD 机内处理的过度锐化边缘感。
    private nonisolated static func applySharpen(
        to image: UIImage,
        strength: Double
    ) -> UIImage? {
        let normalized = Y2KCCDFilterSettings.unit(strength)
        guard normalized > 0.01, let sourceCGImage = image.cgImage else { return image }
        let source = CIImage(cgImage: sourceCGImage)
        // CIUnsharpMask: radius 控制边缘范围，intensity 控制锐化强度
        // 注意：CIUnsharpMask 只支持 inputRadius / inputIntensity，
        // 传入其它 key（如 inputThreshold）会触发 setValue:forUndefinedKey: 崩溃。
        let sharpened = source.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: Float(normalized * 2.2),
            kCIInputIntensityKey: Float(normalized * 0.9)
        ])
        guard let cgImage = ciContextBox.context.createCGImage(sharpened, from: source.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// CCD 传感器噪点：仅中性灰亮度颗粒，不含色度噪点（避免引入彩色色块）。
    /// 全程 Core Image GPU 管线，不阻塞主线程。
    private nonisolated static func applyNoise(
        to image: UIImage,
        noise: Double
    ) -> UIImage? {
        let normalizedNoise = Y2KCCDFilterSettings.unit(noise)
        guard normalizedNoise > 0.005 else { return image }
        guard let sourceCGImage = image.cgImage else { return image }

        let source = CIImage(cgImage: sourceCGImage)
        let extent = source.extent

        // CIRandomGenerator 生成 [0,1] 随机纹理，裁剪到图像尺寸
        guard let randomFilter = CIFilter(name: "CIRandomGenerator") else { return image }
        let randomFull = randomFilter.outputImage!
            .cropped(to: extent)

        // --- 亮度噪点：中性灰颗粒 ---
        // 三个通道都取随机图的同一通道（R），保证是中性灰噪点而非彩色雪花。
        // 将随机值映射到 [-noiseAmp, +noiseAmp] 范围，再叠加到原图。
        let lumaScale = Float(normalizedNoise * 0.15)  // 最大约 ±0.15 亮度
        let lumaNoise = randomFull.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: CGFloat(lumaScale), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: CGFloat(lumaScale), y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: CGFloat(lumaScale), y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: CGFloat(-lumaScale / 2),
                                        y: CGFloat(-lumaScale / 2),
                                        z: CGFloat(-lumaScale / 2),
                                        w: 0)
        ])

        // 只叠加中性灰亮度噪点到原图（AdditionCompositing = 线性加法）。
        let withLuma = lumaNoise
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: source])
            .cropped(to: extent)

        guard let cgImage = ciContextBox.context.createCGImage(withLuma, from: extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// RGB 色差偏移：R 通道右移、B 通道左移，模拟廉价镜头色差。
    /// 使用 Core Image 分通道平移后合并，避免创建两个完整像素缓冲区。
    private nonisolated static func applyRGBShift(
        to image: UIImage,
        strength: Double
    ) -> UIImage? {
        let normalized = Y2KCCDFilterSettings.unit(strength)
        guard normalized > 0.005, let sourceCGImage = image.cgImage else { return image }

        let ciSource = CIImage(cgImage: sourceCGImage)
        let extent = ciSource.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        // 偏移量（点数）：最大约宽度的 0.6%
        let shiftPx = CGFloat(extent.width * CGFloat(normalized) * 0.006).rounded()
        guard shiftPx >= 0.5 else { return image }

        let edgeExtendedSource = ciSource.clampedToExtent()

        // 提取 R 通道（仅保留 R，G/B 清零）并向右平移。
        // 先扩展边缘再裁回原尺寸，避免平移后边缘丢失红/蓝通道，导致整体偏绿。
        let rOnly = edgeExtendedSource.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: shiftPx, y: 0))
            .cropped(to: extent)

        // 提取 B 通道并向左平移。alpha 必须保留；否则预乘 alpha 合成会把蓝色当透明吃掉。
        let bOnly = edgeExtendedSource.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: -shiftPx, y: 0))
            .cropped(to: extent)

        // G 通道保持原位
        let gOnly = ciSource.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        // 用加法合并三通道（AdditionCompositing）
        let combined = rOnly
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: gOnly])
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: bOnly])
            .cropped(to: extent)

        guard let cgImage = ciContextBox.context.createCGImage(combined, from: extent) else {
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
