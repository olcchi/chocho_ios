import SwiftUI

nonisolated enum DotShapeAssetCategoryParser {
    static let basicCategory = "基础"

    static func category(for name: String) -> String {
        if BuiltInDotShape(rawValue: name) != nil {
            return basicCategory
        }
        return DotShapeCatalog.category(for: name) ?? basicCategory
    }

    static func title(for name: String) -> String {
        if let leaf = name.split(separator: "/").last {
            return String(leaf)
        }
        return name
    }

    static func prefersCrispScaling(for name: String) -> Bool {
        category(for: name) == "像素"
    }

    /// Monochrome SVG shapes tint with the selected dot color; full-color sticker assets keep original pixels.
    static func usesTemplateTinting(for name: String) -> Bool {
        let resolvedCategory = category(for: name)
        if resolvedCategory == basicCategory {
            return true
        }
        return resolvedCategory == "像素"
    }

    static func prefersDataAsset(for name: String) -> Bool {
        DotShapeCatalog.prefersDataAsset(for: name)
    }
}

enum DotShapeCategory: String, CaseIterable, Identifiable {
    case recent
    case basic
    case objects
    case paper
    case button
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
        case .pixel:
            "像素"
        }
    }

    static let panelOrder: [DotShapeCategory] = [
        .recent,
        .pixel,
        .basic,
        .objects,
        .paper,
        .button
    ]
}

extension DotShapeCatalog {
    private static let categoryByName: [String: String] = {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0.category) })
    }()

    static func category(for name: String) -> String? {
        categoryByName[name]
    }

    static func contains(_ name: String) -> Bool {
        categoryByName[name] != nil
    }

    static func prefersDataAsset(for name: String) -> Bool {
        guard let category = category(for: name) else { return false }
        switch category {
        case "基础", "像素":
            return false
        default:
            return true
        }
    }
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
        case .objects, .paper, .button, .pixel:
            self.category == category.rawAssetCategory
        }
    }

    @MainActor
    static func shapes(for category: DotShapeCategory, recentNames: [String]) -> [DotShapeAsset] {
        switch category {
        case .recent:
            recentNames.compactMap(asset(named:))
        case .basic, .objects, .paper, .button, .pixel:
            all.filter { $0.matches(category: category) }
        }
    }

    @MainActor
    static func asset(named name: String) -> DotShapeAsset? {
        let migratedName = DotShapeAssetNameMigration.migrate(name)
        if BuiltInDotShape(rawValue: migratedName) != nil
            || migratedName == CharacterDotText.shapeName
            || DotShapeCatalog.contains(migratedName) {
            return DotShapeAsset(name: migratedName)
        }
        return nil
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
        let migratedSelectedName = DotShapeAssetNameMigration.migrate(selectedName)
        let deduped = recentNames
            .map(DotShapeAssetNameMigration.migrate)
            .filter { $0 != migratedSelectedName }
        return Array(([migratedSelectedName] + deduped).prefix(max(limit, 0)))
    }

    static func names(from storageString: String) -> [String] {
        storageString
            .split(separator: Character(separator), omittingEmptySubsequences: true)
            .map { DotShapeAssetNameMigration.migrate(String($0)) }
    }

    static func storageString(for names: [String]) -> String {
        names.joined(separator: separator)
    }
}
