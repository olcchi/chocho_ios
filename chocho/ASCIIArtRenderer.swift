import CoreGraphics
import UIKit
import Vision

// MARK: - 预设

nonisolated enum ASCIIArtPreset: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case heartCollage
    case y2kSparkle
    case softDots

    var id: Self { self }

    var title: String {
        switch self {
        case .heartCollage: "爱心"
        case .y2kSparkle:   "星星"
        case .softDots:     "波点"
        }
    }

    /// 亮度从低到高映射，第一个字符最暗（最密），最后一个最亮（最稀）。
    var fillCharacters: [Character] {
        switch self {
        case .heartCollage: Array("@#♥♡:.")
        case .y2kSparkle:   Array("@☆✧✦*+:.")
        case .softDots:     Array("@◎●○•·")
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .softDots
    }
}

// MARK: - 细节

nonisolated enum ASCIIArtDetail: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case coarse    // 大
    case medium    // 中（默认）
    case fine      // 细

    var id: Self { self }

    var title: String {
        switch self {
        case .coarse: "大"
        case .medium: "中"
        case .fine:   "细"
        }
    }

    /// 每个字符格子在目标分辨率中的边长（像素）。
    var cellSize: CGFloat {
        switch self {
        case .coarse: 24
        case .medium: 14
        case .fine:   8
        }
    }
}

// MARK: - 设置

nonisolated struct ASCIIArtSettings: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var preset: ASCIIArtPreset
    var detail: ASCIIArtDetail
    var showSubject: Bool
    var showOutline: Bool
    var characterColor: CanvasDraftColorComponents

    /// Default ASCII character tint (#A8D8B9).
    nonisolated static let defaultCharacterColor = CanvasDraftColorComponents(
        red: 168.0 / 255.0,
        green: 216.0 / 255.0,
        blue: 185.0 / 255.0
    )

    nonisolated static let `default` = ASCIIArtSettings(
        enabled: false,
        preset: .softDots,
        detail: .coarse,
        showSubject: false,
        showOutline: true,
        characterColor: defaultCharacterColor
    )

    private enum CodingKeys: String, CodingKey {
        case enabled
        case preset
        case detail
        case showSubject
        case showOutline
        case characterColor
    }

    nonisolated init(
        enabled: Bool,
        preset: ASCIIArtPreset,
        detail: ASCIIArtDetail,
        showSubject: Bool,
        showOutline: Bool,
        characterColor: CanvasDraftColorComponents
    ) {
        self.enabled = enabled
        self.preset = preset
        self.detail = detail
        self.showSubject = showSubject
        self.showOutline = showOutline
        self.characterColor = characterColor
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        preset = try container.decode(ASCIIArtPreset.self, forKey: .preset)
        detail = try container.decode(ASCIIArtDetail.self, forKey: .detail)
        showSubject = try container.decodeIfPresent(Bool.self, forKey: .showSubject)
            ?? (!(try container.decodeIfPresent(Bool.self, forKey: .showOutline) ?? true))
        showOutline = try container.decodeIfPresent(Bool.self, forKey: .showOutline) ?? true
        characterColor = try container.decodeIfPresent(
            CanvasDraftColorComponents.self,
            forKey: .characterColor
        ) ?? Self.defaultCharacterColor
    }

    nonisolated var enabledForPanelEditing: ASCIIArtSettings {
        var settings = self
        settings.enabled = true
        return settings
    }

    nonisolated var cacheKey: String {
        [
            enabled ? "1" : "0",
            preset.rawValue,
            detail.rawValue,
            showSubject ? "1" : "0",
            showOutline ? "1" : "0",
            String(format: "%.3f", characterColor.red),
            String(format: "%.3f", characterColor.green),
            String(format: "%.3f", characterColor.blue)
        ].joined(separator: ":")
    }

    nonisolated func renderCacheKey(sourceKey: String, pixelSize: CGSize, maskKey: String) -> String {
        let w = max(1, Int(pixelSize.width.rounded()))
        let h = max(1, Int(pixelSize.height.rounded()))
        return "\(sourceKey)|\(w)x\(h)|\(maskKey)|\(cacheKey)"
    }
}

// MARK: - Cache

nonisolated final class ASCIIArtCache {
    private let maxEntries: Int
    private var imageEntries: [String: UIImage] = [:]
    private var imageKeys: [String] = []
    private var maskEntries: [String: SubjectMask] = [:]
    private var maskKeys: [String] = []
    private let lock = NSLock()

    init(maxEntries: Int = 6) {
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

// MARK: - Preview Policy

nonisolated enum ASCIIArtPreviewRenderPolicy {
    nonisolated static let maxLongEdge: CGFloat = 720
    nonisolated static let refreshDebounce: Duration = .milliseconds(150)

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

// MARK: - Renderer

nonisolated enum ASCIIArtCellRenderStyle: Equatable {
    case subject(String)
    case outline(String)
}

nonisolated enum ASCIIArtRenderer {
    private nonisolated static let maskProvider = VisionSubjectMaskProvider()
    /// Outline glyphs use the lighter preset characters, scaled up slightly for legibility.
    private nonisolated static let outlineFontScale: CGFloat = 1.12

    nonisolated static func sourceKey(for image: UIImage) -> String {
        let pixelSize = CanvasImageLoader.pixelSize(for: image)
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let fingerprint = imageFingerprint(for: image)
        return "\(width)x\(height)-\(fingerprint)"
    }

    nonisolated static func cellSize(
        for detail: ASCIIArtDetail,
        sourcePixelSize: CGSize,
        renderSize: CGSize
    ) -> CGFloat {
        guard sourcePixelSize.width > 0,
              sourcePixelSize.height > 0,
              renderSize.width > 0,
              renderSize.height > 0
        else {
            return detail.cellSize
        }
        let scale = min(
            renderSize.width / sourcePixelSize.width,
            renderSize.height / sourcePixelSize.height
        )
        return max(1, detail.cellSize * scale)
    }

    /// Maps a brightness value [0,1] to a character from the preset's fill set.
    /// Brightness 0 → first character (densest), brightness 1 → last character (sparsest).
    nonisolated static func character(for brightness: CGFloat, preset: ASCIIArtPreset) -> Character {
        let chars = preset.fillCharacters
        guard !chars.isEmpty else { return "?" }
        let clamped = min(1, max(0, brightness))
        let index = Int((clamped * CGFloat(chars.count - 1)).rounded())
        return chars[index]
    }

    nonisolated static func cellRenderStyle(
        avgBrightness: CGFloat,
        subjectFraction: CGFloat,
        isEdge: Bool,
        settings: ASCIIArtSettings,
        hasSubjectMask: Bool
    ) -> ASCIIArtCellRenderStyle? {
        let preset = settings.preset
        if !hasSubjectMask {
            return .subject(String(character(for: avgBrightness, preset: preset)))
        }
        if isEdge, settings.showOutline {
            return .outline(String(character(for: avgBrightness, preset: preset)))
        }
        if subjectFraction > 0.35, settings.showSubject {
            return .subject(String(character(for: avgBrightness, preset: preset)))
        }
        return nil
    }

    nonisolated static func alpha(
        for renderStyle: ASCIIArtCellRenderStyle,
        avgBrightness: CGFloat
    ) -> CGFloat {
        switch renderStyle {
        case .outline:
            return 0.90
        case .subject:
            return 0.82 + avgBrightness * 0.18
        }
    }

    /// Async entry-point: fetches the subject mask (with caching) then delegates to the sync overload.
    nonisolated static func render(
        image: UIImage,
        settings: ASCIIArtSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        cache: ASCIIArtCache? = nil
    ) async -> UIImage? {
        guard settings.enabled else { return nil }

        let inputSize = CanvasImageLoader.pixelSize(for: image)
        let pixelSize = targetPixelSize ?? inputSize
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let renderSize = CGSize(width: width, height: height)
        let sourceKey = sourceKey == "source" ? Self.sourceKey(for: image) : sourceKey
        let maskKey = "\(sourceKey)-mask"
        let cacheKey = settings.renderCacheKey(sourceKey: sourceKey, pixelSize: renderSize, maskKey: maskKey)

        if let cached = cache?.image(for: cacheKey) { return cached }

        let mask: SubjectMask
        if let cachedMask = cache?.mask(for: maskKey) {
            mask = cachedMask
        } else {
            do {
                let detected = try await maskProvider.subjectMask(for: image)
                cache?.setMask(detected, for: maskKey)
                mask = detected
            } catch {
                return render(
                    image: image,
                    mask: nil,
                    settings: settings,
                    targetPixelSize: targetPixelSize,
                    sourceKey: sourceKey,
                    cache: cache
                )
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

    /// Sync overload: uses the provided mask directly, skipping async Vision work.
    nonisolated static func render(
        image: UIImage,
        mask: SubjectMask?,
        settings: ASCIIArtSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        cache: ASCIIArtCache? = nil
    ) -> UIImage? {
        guard settings.enabled else { return nil }

        let inputSize = CanvasImageLoader.pixelSize(for: image)
        let pixelSize = targetPixelSize ?? inputSize
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let renderSize = CGSize(width: width, height: height)
        let sourceKey = sourceKey == "source" ? Self.sourceKey(for: image) : sourceKey
        let maskKey = "\(sourceKey)-mask"
        let cacheKey = settings.renderCacheKey(sourceKey: sourceKey, pixelSize: renderSize, maskKey: maskKey)

        if let cached = cache?.image(for: cacheKey) { return cached }

        guard let rendered = applyASCII(
            to: image,
            mask: mask,
            settings: settings,
            renderSize: renderSize,
            sourcePixelSize: inputSize
        ) else { return nil }

        if let mask {
            cache?.setMask(mask, for: maskKey)
        }
        cache?.setImage(rendered, for: cacheKey)
        return rendered
    }

    // MARK: Core algorithm

    private nonisolated static func applyASCII(
        to image: UIImage,
        mask: SubjectMask?,
        settings: ASCIIArtSettings,
        renderSize: CGSize,
        sourcePixelSize: CGSize
    ) -> UIImage? {
        let renderW = Int(renderSize.width.rounded())
        let renderH = Int(renderSize.height.rounded())
        guard renderW > 0, renderH > 0 else { return nil }

        guard let brightnessMap = makeBrightnessMap(from: image, size: renderSize) else { return nil }
        let detectedMaskBitmap = mask?.boolBitmap(targetSize: renderSize)
        let hasSubjectMask = detectedMaskBitmap?.contains(true) == true
        let maskBitmap = hasSubjectMask
            ? detectedMaskBitmap ?? []
            : [Bool](repeating: true, count: renderW * renderH)

        let cellSize = cellSize(
            for: settings.detail,
            sourcePixelSize: sourcePixelSize,
            renderSize: renderSize
        )
        let edgeBitmap: [Bool] = settings.showOutline && hasSubjectMask
            ? dilateBitmap(
                makeEdgeBitmap(from: maskBitmap, width: renderW, height: renderH),
                width: renderW,
                height: renderH,
                radius: outlineDilationRadius(for: cellSize)
            )
            : []

        let cols = Int(ceil(CGFloat(renderW) / cellSize))
        let rows = Int(ceil(CGFloat(renderH) / cellSize))
        let cellW = CGFloat(renderW) / CGFloat(cols)
        let cellH = CGFloat(renderH) / CGFloat(rows)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let fontSize = min(cellW, cellH) * 0.92
        let subjectFont = UIFont.systemFont(ofSize: max(4, fontSize))
        let outlineFont = UIFont.systemFont(ofSize: max(4, fontSize * Self.outlineFontScale))
        let characterColor = settings.characterColor.uiColor

        return UIGraphicsImageRenderer(size: renderSize, format: format).image { ctx in
            let cgCtx = ctx.cgContext
            image.draw(in: CGRect(origin: .zero, size: renderSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let (avgBrightness, subjectFraction, isEdge) = sampleCell(
                        col: col, row: row,
                        cellW: cellW, cellH: cellH,
                        renderW: renderW, renderH: renderH,
                        brightnessMap: brightnessMap,
                        maskBitmap: maskBitmap,
                        edgeBitmap: settings.showOutline ? edgeBitmap : []
                    )

                    let cellRect = CGRect(
                        x: CGFloat(col) * cellW,
                        y: CGFloat(row) * cellH,
                        width: cellW,
                        height: cellH
                    )

                    guard let renderStyle = cellRenderStyle(
                        avgBrightness: avgBrightness,
                        subjectFraction: subjectFraction,
                        isEdge: isEdge,
                        settings: settings,
                        hasSubjectMask: hasSubjectMask
                    ) else {
                        continue
                    }

                    switch renderStyle {
                    case .outline(let text):
                        drawCharacter(
                            text,
                            in: cellRect,
                            font: outlineFont,
                            color: characterColor,
                            alpha: alpha(for: renderStyle, avgBrightness: avgBrightness),
                            context: cgCtx
                        )
                    case .subject(let text):
                        drawCharacter(
                            text,
                            in: cellRect,
                            font: subjectFont,
                            color: characterColor,
                            alpha: alpha(for: renderStyle, avgBrightness: avgBrightness),
                            context: cgCtx
                        )
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private nonisolated static func makeBrightnessMap(from image: UIImage, size: CGSize) -> [CGFloat]? {
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())
        guard w > 0, h > 0 else { return nil }

        let byteCount = w * h
        var raw = [UInt8](repeating: 0, count: byteCount)
        guard let ctx = CGContext(
            data: &raw,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue
        ) else { return nil }

        guard let cgImage = image.cgImage else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        return raw.map { CGFloat($0) / 255.0 }
    }

    private nonisolated static func imageFingerprint(for image: UIImage) -> String {
        let sampleWidth = 16
        let sampleHeight = 16
        let bytesPerPixel = 4
        var raw = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * bytesPerPixel)
        guard let context = CGContext(
            data: &raw,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = image.cgImage else {
            return "\(ObjectIdentifier(image).hashValue)"
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in raw {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    /// 8-neighbor edge detection on the mask: a pixel is an edge if it's inside the subject
    /// and at least one of its 8 neighbors differs.
    private nonisolated static func makeEdgeBitmap(from maskBitmap: [Bool], width: Int, height: Int) -> [Bool] {
        var edges = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let center = maskBitmap[y * width + x]
                guard center else { continue }
                // Out-of-bounds neighbors are treated as same as center to avoid
                // falsely marking subject pixels at the image border as edges.
                func pixel(_ px: Int, _ py: Int) -> Bool {
                    guard px >= 0, px < width, py >= 0, py < height else { return center }
                    return maskBitmap[py * width + px]
                }
                let isEdge =
                    pixel(x-1, y-1) != center ||
                    pixel(x-1, y)   != center ||
                    pixel(x-1, y+1) != center ||
                    pixel(x,   y-1) != center ||
                    pixel(x,   y+1) != center ||
                    pixel(x+1, y-1) != center ||
                    pixel(x+1, y)   != center ||
                    pixel(x+1, y+1) != center
                edges[y * width + x] = isEdge
            }
        }
        return edges
    }

    /// Expands the 1px contour so coarse cells still pick up outline glyphs.
    nonisolated static func outlineDilationRadius(for cellSize: CGFloat) -> Int {
        max(1, Int((cellSize * 0.45).rounded()))
    }

    private nonisolated static func dilateBitmap(
        _ bitmap: [Bool],
        width: Int,
        height: Int,
        radius: Int
    ) -> [Bool] {
        guard radius > 0, !bitmap.isEmpty else { return bitmap }
        var dilated = bitmap
        for y in 0..<height {
            for x in 0..<width {
                guard bitmap[y * width + x] else { continue }
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let px = x + dx
                        let py = y + dy
                        guard px >= 0, px < width, py >= 0, py < height else { continue }
                        dilated[py * width + px] = true
                    }
                }
            }
        }
        return dilated
    }

    private nonisolated static func sampleCell(
        col: Int, row: Int,
        cellW: CGFloat, cellH: CGFloat,
        renderW: Int, renderH: Int,
        brightnessMap: [CGFloat],
        maskBitmap: [Bool],
        edgeBitmap: [Bool]
    ) -> (avgBrightness: CGFloat, subjectFraction: CGFloat, isEdge: Bool) {
        let startX = Int((CGFloat(col) * cellW).rounded())
        let startY = Int((CGFloat(row) * cellH).rounded())
        let endX = min(renderW, Int((CGFloat(col + 1) * cellW).rounded()))
        let endY = min(renderH, Int((CGFloat(row + 1) * cellH).rounded()))

        var totalBrightness: CGFloat = 0
        var maskCount = 0
        var edgeCount = 0
        var totalCount = 0

        for py in startY..<endY {
            for px in startX..<endX {
                let idx = py * renderW + px
                guard idx < brightnessMap.count else { continue }
                totalBrightness += brightnessMap[idx]
                if idx < maskBitmap.count, maskBitmap[idx] { maskCount += 1 }
                if !edgeBitmap.isEmpty, idx < edgeBitmap.count, edgeBitmap[idx] { edgeCount += 1 }
                totalCount += 1
            }
        }

        guard totalCount > 0 else { return (0, 0, false) }
        let avgBrightness = totalBrightness / CGFloat(totalCount)
        let subjectFraction = CGFloat(maskCount) / CGFloat(totalCount)
        let isEdge = edgeCount > 0
        return (avgBrightness, subjectFraction, isEdge)
    }

    private nonisolated static func drawCharacter(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alpha: CGFloat,
        context: CGContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.withAlphaComponent(alpha)
        ]
        let nsText = text as NSString
        let textSize = nsText.size(withAttributes: attrs)
        let drawRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        UIGraphicsPushContext(context)
        nsText.draw(in: drawRect, withAttributes: attrs)
        UIGraphicsPopContext()
    }
}

// MARK: - SubjectMask boolBitmap

extension SubjectMask {
    /// Scales the mask pixels to targetSize using nearest-neighbor, returns flat Bool array in row-major order.
    nonisolated func boolBitmap(targetSize: CGSize) -> [Bool]? {
        guard width > 0, height > 0 else { return nil }
        let targetW = max(1, Int(targetSize.width.rounded()))
        let targetH = max(1, Int(targetSize.height.rounded()))
        if targetW == width && targetH == height { return pixels }
        var result = [Bool](repeating: false, count: targetW * targetH)
        for ty in 0..<targetH {
            for tx in 0..<targetW {
                let sx = tx * width / targetW
                let sy = ty * height / targetH
                let idx = sy * width + sx
                result[ty * targetW + tx] = idx < pixels.count ? pixels[idx] : false
            }
        }
        return result
    }
}
