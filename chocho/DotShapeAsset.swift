import SwiftUI

nonisolated enum DotShapeAssetCategoryParser {
    static let basicCategory = "基础"
    static let categorizedSuffixes: Set<String> = [
        "小物",
        "彩纸",
        "纽扣",
        "水钻",
        "针线",
        "像素"
    ]

    static func prefersCrispScaling(for name: String) -> Bool {
        suffix(in: name) == "像素"
    }

    /// Monochrome SVG shapes tint with the selected dot color; full-color sticker assets keep original pixels.
    static func usesTemplateTinting(for name: String) -> Bool {
        guard let suffix = suffix(in: name) else { return true }
        return suffix == "像素"
    }

    static func category(for name: String) -> String {
        suffix(in: name) ?? basicCategory
    }

    static func title(for name: String) -> String {
        guard suffix(in: name) != nil, let suffixSeparatorIndex = name.lastIndex(of: ".") else {
            return name
        }

        return String(name[..<suffixSeparatorIndex])
    }

    static func suffix(in name: String) -> String? {
        guard let suffixSeparatorIndex = name.lastIndex(of: ".") else { return nil }

        let suffixStartIndex = name.index(after: suffixSeparatorIndex)
        let suffix = String(name[suffixStartIndex...])
        return categorizedSuffixes.contains(suffix) ? suffix : nil
    }
}

enum DotShapeCategory: String, CaseIterable, Identifiable {
    case recent
    case basic
    case objects
    case paper
    case button
    case rhinestone
    case thread
    case pixel

    var id: Self { self }

    var title: String {
        switch self {
        case .recent:
            "最近"
        case .basic:
            "基础"
        case .objects:
            "小物"
        case .paper:
            "彩纸"
        case .button:
            "纽扣"
        case .rhinestone:
            "水钻"
        case .thread:
            "针线"
        case .pixel:
            "像素"
        }
    }

    var rawAssetCategory: String? {
        switch self {
        case .recent:
            nil
        case .basic:
            nil
        case .objects:
            "小物"
        case .paper:
            "彩纸"
        case .button:
            "纽扣"
        case .rhinestone:
            "水钻"
        case .thread:
            "针线"
        case .pixel:
            "像素"
        }
    }

    static let assetCategorySuffixes = Set(
        DotShapeAssetCategoryParser.categorizedSuffixes
    )

    static let panelOrder: [DotShapeCategory] = [
        .recent,
        .pixel,
        .basic,
        .objects,
        .paper,
        .button,
        .rhinestone,
        .thread
    ]
}

struct DotShapeAsset: Identifiable, Equatable {
    let name: String

    var id: String { name }

    var title: String {
        DotShapeAssetCategoryParser.title(for: name)
    }

    var category: String {
        DotShapeAssetCategoryParser.category(for: name)
    }

    var assetImageName: String {
        "public/\(name)"
    }

    var previewTilePadding: CGFloat {
        switch category {
        case "基础":
            16
        case "像素":
            6
        default:
            9
        }
    }

    var prefersCrispScaling: Bool {
        DotShapeAssetCategoryParser.prefersCrispScaling(for: name)
    }

    var usesTemplatePreview: Bool {
        DotShapeAssetCategoryParser.usesTemplateTinting(for: name)
    }

    var builtInShape: BuiltInDotShape? {
        BuiltInDotShape(rawValue: name)
    }

    var isCharacterDot: Bool {
        name == CharacterDotText.shapeName
    }

    func matches(category: DotShapeCategory) -> Bool {
        switch category {
        case .recent:
            false
        case .basic:
            self.category == "基础"
        case .objects, .paper, .button, .rhinestone, .thread, .pixel:
            self.category == category.rawAssetCategory
        }
    }

    @MainActor
    static func shapes(for category: DotShapeCategory, recentNames: [String]) -> [DotShapeAsset] {
        switch category {
        case .recent:
            recentNames.compactMap(asset(named:))
        case .basic, .objects, .paper, .button, .rhinestone, .thread, .pixel:
            all.filter { $0.matches(category: category) }
        }
    }

    @MainActor
    static func asset(named name: String) -> DotShapeAsset? {
        all.first { $0.name == name }
    }

    static let defaultSelection = DotShapeAsset(name: BuiltInDotShape.circle.rawValue)

    static let characterSelection = DotShapeAsset(name: CharacterDotText.shapeName)

    static let all: [DotShapeAsset] =
        BuiltInDotShape.allCases.map { DotShapeAsset(name: $0.rawValue) }
        + [characterSelection]
        + DotShapeCatalog.assetNames
            .filter { BuiltInDotShape(rawValue: $0) == nil }
            .filter { $0 != characterSelection.name }
            .map { DotShapeAsset(name: $0) }
}

enum DotShapeRecentList {
    static let defaultLimit = 12
    private static let separator = "\n"

    static func selecting(
        _ selectedName: String,
        in category: DotShapeCategory,
        recentNames: [String],
        limit: Int
    ) -> [String] {
        guard category != .recent else {
            return recentNames
        }

        return adding(selectedName, to: recentNames, limit: limit)
    }

    static func adding(_ selectedName: String, to recentNames: [String], limit: Int) -> [String] {
        let deduped = recentNames.filter { $0 != selectedName }
        return Array(([selectedName] + deduped).prefix(max(limit, 0)))
    }

    static func names(from storageString: String) -> [String] {
        storageString
            .split(separator: Character(separator), omittingEmptySubsequences: true)
            .map(String.init)
    }

    static func storageString(for names: [String]) -> String {
        names.joined(separator: separator)
    }
}
