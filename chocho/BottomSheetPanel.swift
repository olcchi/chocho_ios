//
//  BottomSheetPanel.swift
//  chocho
//
//  Created by Codex on 2026/5/23.
//

import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case dots
    case draw
    case background

    var id: Self { self }

    var title: String {
        switch self {
        case .dots:
            "波点"
        case .draw:
            "抽卡"
        case .background:
            "背景"
        }
    }

    var customizationID: String {
        "chocho.panel.tab.\(rawValue)"
    }

    var iconAssetName: String {
        switch self {
        case .dots:
            "public/point"
        case .draw:
            "public/random"
        case .background:
            "public/bg"
        }
    }
}

struct BottomSheetPanel: View {
    @Binding var selectedTab: PanelTab
    @Binding var dotCount: Double
    @Binding var selectedDotShape: DotShapeAsset
    let onDrawDots: () -> Void
    @Namespace private var tabCursorNamespace

    var body: some View {
        VStack(spacing: 0) {
            panelHandle
                .padding(.top, 6)

            panelTabBar
                .padding(.top, 8)

            PanelContentCard(
                tab: selectedTab,
                dotCount: $dotCount,
                selectedDotShape: $selectedDotShape,
                onDrawDots: onDrawDots
            )
            .padding(.top, 10)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 297)
        .background(Color(red: 253 / 255, green: 253 / 255, blue: 253 / 255))
        .animation(.smooth(duration: 0.22), value: selectedTab)
    }

    private var panelHandle: some View {
        Capsule(style: .continuous)
            .fill(Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255))
            .frame(width: 48, height: 6)
    }

    private var panelTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title)
                            .font(.system(size: 17, weight: tab == selectedTab ? .semibold : .regular))
                            .foregroundStyle(tab == selectedTab ? Color.black : Color.black.opacity(0.55))

                        ZStack {
                            if tab == selectedTab {
                                Capsule(style: .continuous)
                                    .fill(activeTabColor)
                                    .frame(width: 36, height: 3)
                                    .matchedGeometryEffect(id: "tabCursor", in: tabCursorNamespace)
                            } else {
                                Color.clear
                                    .frame(width: 36, height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == selectedTab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 20)
    }

    private var activeTabColor: Color {
        Color(red: 165 / 255, green: 231 / 255, blue: 76 / 255)
    }
}

private struct PanelContentCard: View {
    let tab: PanelTab
    @Binding var dotCount: Double
    @Binding var selectedDotShape: DotShapeAsset
    let onDrawDots: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotShapePickerPanel(selectedShape: $selectedDotShape)
            case .draw:
                DrawPanelControls(
                    dotCount: $dotCount,
                    onDrawDots: onDrawDots
                )
                .background(panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            case .background:
                PlaceholderPanelContent(title: tab.title)
                    .background(panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 204)
    }

    private var panelFill: Color {
        Color(red: 242 / 255, green: 242 / 255, blue: 242 / 255)
    }
}

private struct DrawPanelControls: View {
    @Binding var dotCount: Double
    let onDrawDots: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Text("波点数量")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.black)

                Slider(value: $dotCount, in: 0...30, step: 1)
                    .tint(activeColor)

                Text("\(Int(dotCount.rounded()))")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .frame(width: 54, height: 32)
                    .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button(action: onDrawDots) {
                HStack(spacing: 8) {
                    Image("public/sparkles")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text("抽一张")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(activeColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var activeColor: Color {
        Color(red: 67 / 255, green: 238 / 255, blue: 98 / 255)
    }
}

private struct PlaceholderPanelContent: View {
    let title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black)
                .padding(.top, 10)
                .padding(.leading, 10)

            Text("占位...")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct DotShapePickerPanel: View {
    @State private var selectedCategory: DotShapeCategory = .objects
    @Binding var selectedShape: DotShapeAsset
    @AppStorage("chocho.dotShape.recentNames") private var recentShapeNamesStore = DotShapeAsset.defaultSelection.name

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            DotShapeCategoryTabs(selectedCategory: $selectedCategory)

            DotShapeGrid(
                shapes: shapes,
                selectedShape: $selectedShape
            ) { shape in
                selectedShape = shape
                let recentShapeNames = DotShapeRecentList.selecting(
                    shape.name,
                    in: selectedCategory,
                    recentNames: recentShapeNames,
                    limit: DotShapeRecentList.defaultLimit
                )
                recentShapeNamesStore = DotShapeRecentList.storageString(for: recentShapeNames)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.22), value: selectedCategory)
    }

    private var shapes: [DotShapeAsset] {
        DotShapeAsset.shapes(for: selectedCategory, recentNames: recentShapeNames)
    }

    private var recentShapeNames: [String] {
        DotShapeRecentList.names(from: recentShapeNamesStore)
    }
}

private struct DotShapeCategoryTabs: View {
    @Binding var selectedCategory: DotShapeCategory

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(DotShapeCategory.panelOrder) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .frame(minWidth: 48)
                            .frame(height: 30)
                            .padding(.horizontal, 2)
                            .background {
                                if category == selectedCategory {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(activeColor)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                        }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == selectedCategory ? .isSelected : [])
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
    }

    private var activeColor: Color {
        Color(red: 0 / 255, green: 235 / 255, blue: 93 / 255)
    }
}

private struct DotShapeGrid: View {
    let shapes: [DotShapeAsset]
    @Binding var selectedShape: DotShapeAsset
    let onSelect: (DotShapeAsset) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 66, maximum: 78), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(shapes) { shape in
                    DotShapeTile(
                        shape: shape,
                        isSelected: shape == selectedShape
                    ) {
                        onSelect(shape)
                    }
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 253 / 255, green: 253 / 255, blue: 253 / 255))
                .stroke(Color(red: 225 / 255, green: 226 / 255, blue: 236 / 255), lineWidth: 1.5)
        )
    }
}

private struct DotShapeTile: View {
    let shape: DotShapeAsset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Image(shape.previewAssetName)
                .resizable()
                .scaledToFit()
                .padding(shape.previewTilePadding)
                .frame(width: 66, height: 66)
                .background(tileBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 225 / 255, green: 226 / 255, blue: 236 / 255), lineWidth: isSelected ? 0 : 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shape.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tileBackground: Color {
        isSelected
            ? Color(red: 0 / 255, green: 235 / 255, blue: 93 / 255)
            : Color(red: 253 / 255, green: 253 / 255, blue: 253 / 255)
    }
}

enum DotShapeCategory: String, CaseIterable, Identifiable {
    case recent
    case basic
    case objects
    case paper
    case sticker
    case button
    case rhinestone
    case fabric
    case thread

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
        case .sticker:
            "贴纸"
        case .button:
            "纽扣"
        case .rhinestone:
            "水钻"
        case .fabric:
            "布"
        case .thread:
            "针线"
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
        case .sticker:
            "贴纸"
        case .button:
            "纽扣"
        case .rhinestone:
            "水钻"
        case .fabric:
            "布"
        case .thread:
            "针线"
        }
    }

    static let panelOrder: [DotShapeCategory] = [
        .recent,
        .basic,
        .objects,
        .paper,
        .sticker,
        .button,
        .rhinestone,
        .fabric,
        .thread
    ]
}

struct DotShapeAsset: Identifiable, Equatable {
    let name: String
    let previewName: String?

    var id: String { name }

    var title: String {
        name.split(separator: ".").first.map(String.init) ?? name
    }

    var category: String {
        let parts = name.split(separator: ".").map(String.init)
        guard parts.count > 1 else { return "基础" }

        return parts.dropFirst().joined(separator: " ")
    }

    var previewAssetName: String {
        "public/shapes/\(previewName ?? name)"
    }

    var previewTilePadding: CGFloat {
        category == "基础" ? 16 : 9
    }

    func matches(category: DotShapeCategory) -> Bool {
        switch category {
        case .recent:
            false
        case .basic:
            self.category == "基础"
        case .objects, .paper, .sticker, .button, .rhinestone, .fabric, .thread:
            self.category == category.rawAssetCategory
        }
    }

    @MainActor
    static func shapes(for category: DotShapeCategory, recentNames: [String]) -> [DotShapeAsset] {
        switch category {
        case .recent:
            recentNames.compactMap(asset(named:))
        case .basic, .objects, .paper, .sticker, .button, .rhinestone, .fabric, .thread:
            all.filter { $0.matches(category: category) }
        }
    }

    @MainActor
    static func asset(named name: String) -> DotShapeAsset? {
        all.first { $0.name == name }
    }

    static let defaultSelection = DotShapeAsset(name: "眼睛.小物", previewName: "眼睛.小物.preview")

    static let all: [DotShapeAsset] = [
        DotShapeAsset(name: "丝带.彩纸", previewName: "丝带.彩纸.preview"),
        DotShapeAsset(name: "乱七八糟.贴纸", previewName: "乱七八糟.贴纸.preview"),
        DotShapeAsset(name: "云1.布", previewName: "云1.布.preview"),
        DotShapeAsset(name: "圆.brush.水钻", previewName: "圆.brush.水钻.preview"),
        DotShapeAsset(name: "圆2.brus.水钻", previewName: "圆2.brus.水钻.preview"),
        DotShapeAsset(name: "小熊.水钻", previewName: "小熊.水钻.preview"),
        DotShapeAsset(name: "工牌.小物", previewName: "工牌.小物.preview"),
        DotShapeAsset(name: "开关.贴纸", previewName: "开关.贴纸.preview"),
        DotShapeAsset(name: "彩纸1.彩纸", previewName: "彩纸1.彩纸.preview"),
        DotShapeAsset(name: "彩纸2.彩纸", previewName: "彩纸2.彩纸.preview"),
        DotShapeAsset(name: "彩纸3.彩纸", previewName: "彩纸3.彩纸.preview"),
        DotShapeAsset(name: "彩纸4.彩纸", previewName: "彩纸4.彩纸.preview"),
        DotShapeAsset(name: "很多个星.贴纸", previewName: "很多个星.贴纸.preview"),
        DotShapeAsset(name: "心", previewName: nil),
        DotShapeAsset(name: "心.水钻", previewName: "心.水钻.preview"),
        DotShapeAsset(name: "心2.布", previewName: "心2.布.preview"),
        DotShapeAsset(name: "星1", previewName: nil),
        DotShapeAsset(name: "星1.纽扣", previewName: "星1.纽扣.preview"),
        DotShapeAsset(name: "星2", previewName: nil),
        DotShapeAsset(name: "星2.纽扣", previewName: "星2.纽扣.preview"),
        DotShapeAsset(name: "星3", previewName: nil),
        DotShapeAsset(name: "星星.水钻", previewName: "星星.水钻.preview"),
        DotShapeAsset(name: "月亮.布", previewName: "月亮.布.preview"),
        DotShapeAsset(name: "未标题-1.小物", previewName: "未标题-1.小物.preview"),
        DotShapeAsset(name: "水滴.水钻", previewName: "水滴.水钻.preview"),
        DotShapeAsset(name: "眼睛.小物", previewName: "眼睛.小物.preview"),
        DotShapeAsset(name: "脸.纽扣", previewName: "脸.纽扣.preview"),
        DotShapeAsset(name: "花1", previewName: nil),
        DotShapeAsset(name: "花1.纽扣", previewName: "花1.纽扣.preview"),
        DotShapeAsset(name: "花2.布", previewName: "花2.布.preview"),
        DotShapeAsset(name: "花3.布", previewName: "花3.布.preview"),
        DotShapeAsset(name: "花4.贴纸", previewName: "花4.贴纸.preview"),
        DotShapeAsset(name: "花束.小物", previewName: "花束.小物.preview"),
        DotShapeAsset(name: "菜单.贴纸", previewName: "菜单.贴纸.preview"),
        DotShapeAsset(name: "蛙.小物", previewName: "蛙.小物.preview"),
        DotShapeAsset(name: "蝴蝶1.纽扣", previewName: "蝴蝶1.纽扣.preview"),
        DotShapeAsset(name: "蝴蝶结.布", previewName: "蝴蝶结.布.preview"),
        DotShapeAsset(name: "针线1.针线", previewName: "针线1.针线.preview"),
        DotShapeAsset(name: "雪", previewName: nil),
        DotShapeAsset(name: "面包.小物", previewName: "面包.小物.preview"),
        DotShapeAsset(name: "风扇.小物", previewName: "风扇.小物.preview"),
        DotShapeAsset(name: "鱼", previewName: "鱼.preview"),
        DotShapeAsset(name: "鱼1.纽扣", previewName: "鱼1.纽扣.preview")
    ]
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
