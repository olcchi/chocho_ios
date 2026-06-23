import CoreGraphics
import UIKit
import Vision

// MARK: - 预设

nonisolated enum ASCIIArtPreset: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case classicASCII
    case softDots
    case y2kSparkle
    case ccdNoise
    case pixelBlock
    case heartCollage

    var id: Self { self }

    var title: String {
        switch self {
        case .classicASCII: "经典"
        case .softDots:     "波点"
        case .y2kSparkle:   "星星"
        case .ccdNoise:     "CCD"
        case .pixelBlock:   "像素"
        case .heartCollage: "爱心"
        }
    }

    /// 亮度从低到高映射，第一个字符最暗（最密），最后一个最亮（最稀）。
    var fillCharacters: [Character] {
        switch self {
        case .classicASCII: Array("@%#*+=-:.")
        case .softDots:     Array("@◎●○•·")
        case .y2kSparkle:   Array("@☆✧✦*+:.")
        case .ccdNoise:     Array("%#*;:,`.'")
        case .pixelBlock:   Array("█▓▒░")
        case .heartCollage: Array("@#♥♡:.")
        }
    }

    var outlineCharacter: Character {
        switch self {
        case .classicASCII: "*"
        case .softDots:     "•"
        case .y2kSparkle:   "✦"
        case .ccdNoise:     "."
        case .pixelBlock:   "█"
        case .heartCollage: "♡"
        }
    }

    /// 新图片加载时该预设的背景默认开关。
    var defaultShowBackground: Bool {
        switch self {
        case .classicASCII, .softDots, .pixelBlock: false
        case .y2kSparkle, .ccdNoise, .heartCollage: true
        }
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
    var showOutline: Bool
    var showBackground: Bool

    nonisolated static let `default` = ASCIIArtSettings(
        enabled: false,
        preset: .softDots,
        detail: .medium,
        showOutline: false,
        showBackground: ASCIIArtPreset.softDots.defaultShowBackground
    )

    nonisolated var enabledForPanelEditing: ASCIIArtSettings {
        var s = self; s.enabled = true; return s
    }

    nonisolated var cacheKey: String {
        [
            enabled ? "1" : "0",
            preset.rawValue,
            detail.rawValue,
            showOutline ? "1" : "0",
            showBackground ? "1" : "0"
        ].joined(separator: ":")
    }

    nonisolated func renderCacheKey(sourceKey: String, pixelSize: CGSize, maskKey: String) -> String {
        let w = max(1, Int(pixelSize.width.rounded()))
        let h = max(1, Int(pixelSize.height.rounded()))
        return "\(sourceKey)|\(w)x\(h)|\(maskKey)|\(cacheKey)"
    }
}
