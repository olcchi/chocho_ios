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
    static let height: CGFloat = 320
    static let collapsedHeight: CGFloat = 78
    static let topCornerRadius: CGFloat = 24
    private static let contentHorizontalInset: CGFloat = 16
    private static let contentBottomInset: CGFloat = 4
    private static let contentToTabGap: CGFloat = 10
    private static let maxVisibleBottomSafeAreaInset: CGFloat = 0
    private static let handleTouchHeight: CGFloat = 28
    private static let collapseDragThreshold: CGFloat = 28

    static func visibleHeight(isExpanded: Bool) -> CGFloat {
        isExpanded ? height : collapsedHeight
    }

    @Binding var selectedTab: PanelTab
    @Binding var isExpanded: Bool
    @Binding var dotCount: Double
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var usesRandomDotColors: Bool
    @Binding var selectedDotShape: DotShapeAsset
    @Binding var isTraceDrawingEnabled: Bool
    var bottomSafeAreaInset: CGFloat = 0
    let onDrawDots: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            panelHandleArea

            panelContent

            panelTabBar
                .padding(.top, isExpanded ? Self.contentToTabGap : 4)
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.bottom, Self.contentBottomInset + visibleBottomSafeAreaInset)
        .frame(maxWidth: .infinity)
        .frame(height: Self.visibleHeight(isExpanded: isExpanded) + bottomSafeAreaInset, alignment: .top)
        .background(panelBackground)
        .clipped()
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.10), radius: 28, x: 0, y: -5)
        .animation(.smooth(duration: 0.24), value: isExpanded)
    }

    private var panelContent: some View {
        PanelContentCard(
            tab: selectedTab,
            dotCount: $dotCount,
            dotScale: $dotScale,
            selectedDotColor: $selectedDotColor,
            usesRandomDotColors: $usesRandomDotColors,
            selectedDotShape: $selectedDotShape,
            isTraceDrawingEnabled: $isTraceDrawingEnabled,
            onDrawDots: onDrawDots
        )
        .padding(.top, isExpanded ? 8 : 0)
        .frame(height: isExpanded ? nil : 0, alignment: .top)
        .opacity(isExpanded ? 1 : 0)
        .accessibilityHidden(!isExpanded)
        .allowsHitTesting(isExpanded)
    }

    private var panelBackground: some View {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: Self.topCornerRadius,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: Self.topCornerRadius
            ),
            style: .continuous
        )
        .fill(Color.popover)
    }

    private var visibleBottomSafeAreaInset: CGFloat {
        min(bottomSafeAreaInset, Self.maxVisibleBottomSafeAreaInset)
    }

    private var panelHandle: some View {
        Capsule(style: .continuous)
            .fill(Color.border)
            .frame(width: 48, height: 6)
    }

    private var panelHandleArea: some View {
        panelHandle
            .frame(maxWidth: .infinity)
            .frame(height: Self.handleTouchHeight)
            .contentShape(Rectangle())
            .gesture(handleDragGesture)
            .accessibilityLabel(isExpanded ? "折叠面板" : "展开面板")
    }

    private var panelTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases) { tab in
                let isSelected = tab == selectedTab

                Button {
                    selectedTab = tab
                    if !isExpanded {
                        setExpanded(true)
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(tab.iconAssetName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)

                        Text(tab.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? activeTabColor : Color.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .scaleEffect(isSelected ? 1.1 : 1)
                    .contentShape(Rectangle())
                    .animation(.smooth(duration: 0.18), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var activeTabColor: Color {
        Color.primary
    }

    private var handleDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                let verticalTranslation = value.translation.height

                guard abs(verticalTranslation) > Self.collapseDragThreshold else { return }

                setExpanded(verticalTranslation < 0)
            }
    }

    private func setExpanded(_ newValue: Bool) {
        withAnimation(.smooth(duration: 0.24)) {
            isExpanded = newValue
        }
    }
}

struct CanvasHistoryControls: View {
    let canUndo: Bool
    let canRedo: Bool
    let canClear: Bool
    let onClear: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onClear) {
                Text("打扫")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.foreground)
                    .frame(height: 26)
                    .padding(.horizontal, 9)
            }
            .buttonStyle(.plain)
            .disabled(!canClear)
            .opacity(canClear ? 1 : 0.42)
            .accessibilityLabel("清空画布内容")

            controlDivider

            historyButton(
                assetName: "public/undo",
                isEnabled: canUndo,
                accessibilityLabel: "撤销",
                action: onUndo
            )

            controlDivider

            historyButton(
                assetName: "public/redo",
                isEnabled: canRedo,
                accessibilityLabel: "重做",
                action: onRedo
            )
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: BottomSheetPanel.topCornerRadius, style: .continuous)
                .fill(Color.popover)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BottomSheetPanel.topCornerRadius, style: .continuous)
                .stroke(Color.border.opacity(0.7), lineWidth: 1)
        }
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 3)
    }

    private func historyButton(
        assetName: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.foreground)
                .frame(width: 30, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PanelContentCard: View {
    let tab: PanelTab
    @Binding var dotCount: Double
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var usesRandomDotColors: Bool
    @Binding var selectedDotShape: DotShapeAsset
    @Binding var isTraceDrawingEnabled: Bool
    let onDrawDots: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotShapePickerPanel(
                    selectedShape: $selectedDotShape,
                    dotScale: $dotScale,
                    selectedDotColor: $selectedDotColor
                )
            case .draw:
                DrawPanelControls(
                    dotCount: $dotCount,
                    usesRandomDotColors: $usesRandomDotColors,
                    isTraceDrawingEnabled: $isTraceDrawingEnabled,
                    onDrawDots: onDrawDots
                )
            case .background:
                PlaceholderPanelContent(title: tab.title)
                    .background(panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 232)
    }

    private var panelFill: Color {
        Color.muted
    }
}

private struct DrawPanelControls: View {
    @Binding var dotCount: Double
    @Binding var usesRandomDotColors: Bool
    @Binding var isTraceDrawingEnabled: Bool
    let onDrawDots: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                StyledSlider(
                    title: "波点数量",
                    value: $dotCount,
                    range: 0...30,
                    step: 1
                )

                HStack(spacing: 10) {
                    compactToggleButton(
                        title: "随机色彩",
                        isOn: usesRandomDotColors
                    ) {
                        usesRandomDotColors.toggle()
                    }

                    controlSeparator

                    compactToggleButton(
                        title: "手绘轨迹",
                        isOn: isTraceDrawingEnabled
                    ) {
                        isTraceDrawingEnabled.toggle()
                    }
                }
                .frame(height: 30)
            }
            .padding(.horizontal, 2)

            Spacer(minLength: 0)

            drawButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var drawButton: some View {
        Button(action: onDrawDots) {
            HStack(spacing: 6) {
                Image("public/sparkles")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)

                Text("抽一张")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.primaryForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(activeColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var activeColor: Color {
        Color.primary
    }

    private var inactiveColor: Color {
        Color.input
    }

    private var separatorColor: Color {
        Color.appAccent.opacity(0.22)
    }

    private var controlSeparator: some View {
        Capsule(style: .continuous)
            .fill(separatorColor)
            .frame(width: 1.5, height: 18)
    }

    private func compactToggleButton(
        title: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Color.primaryForeground : Color.foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isOn ? activeColor : inactiveColor)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isOn ? activeColor.opacity(0.75) : Color.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

private struct PlaceholderPanelContent: View {
    let title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.foreground)
                .padding(.top, 10)
                .padding(.leading, 10)

            Text("占位...")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct DotShapePickerPanel: View {
    @State private var selectedCategory: DotShapeCategory = .objects
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
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

            DotSizeSlider(dotScale: $dotScale)

            DotColorPicker(selectedDotColor: $selectedDotColor)
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

private struct DotSizeSlider: View {
    @Binding var dotScale: Double

    var body: some View {
        StyledSlider(
            title: "大小",
            value: dotControlValue,
            range: DotSizeControl.minControlValue...DotSizeControl.maxControlValue
        )
        .padding(.horizontal, 2)
    }

    private var dotControlValue: Binding<Double> {
        Binding(
            get: {
                DotSizeControl.controlValue(forRenderedScale: dotScale)
            },
            set: { newValue in
                dotScale = DotSizeControl.renderedScale(forControlValue: newValue)
            }
        )
    }
}

private struct DotColorPicker: View {
    @Binding var selectedDotColor: Color

    var body: some View {
        ColorPicker("颜色", selection: $selectedDotColor, supportsOpacity: false)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.foreground)
            .frame(height: 30)
            .padding(.horizontal, 2)
    }
}

private struct DotShapeCategoryTabs: View {
    @Binding var selectedCategory: DotShapeCategory

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(DotShapeCategory.panelOrder) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.foreground)
                            .frame(minWidth: 48)
                            .frame(height: 28)
                            .padding(.horizontal, 2)
                            .background {
                                if category == selectedCategory {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(activeColor)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.foreground.opacity(0.08), lineWidth: 1)
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
        Color.primary
    }
}

private struct DotShapeGrid: View {
    let shapes: [DotShapeAsset]
    @Binding var selectedShape: DotShapeAsset
    let onSelect: (DotShapeAsset) -> Void
    @State private var availableWidth: CGFloat = 361

    private let columnCount = 6
    private let gridSpacing: CGFloat = 8
    private let gridPadding: CGFloat = 8
    private let visibleRowCount: CGFloat = 2

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: columnCount
        )
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(shapes) { shape in
                    DotShapeTile(
                        shape: shape,
                        isSelected: shape == selectedShape
                    ) {
                        onSelect(shape)
                    }
                }
            }
            .padding(gridPadding)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: heightForTwoRows(availableWidth: availableWidth))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.border, lineWidth: 1.5)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: DotShapeGridWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(DotShapeGridWidthKey.self) { width in
            availableWidth = width
        }
    }

    private func heightForTwoRows(availableWidth width: CGFloat) -> CGFloat {
        let horizontalGaps = CGFloat(columnCount - 1) * gridSpacing
        let contentWidth = width - gridPadding * 2 - horizontalGaps
        let tileSide = floor(contentWidth / CGFloat(columnCount))
        let rowGaps = (visibleRowCount - 1) * gridSpacing

        return tileSide * visibleRowCount + rowGaps + gridPadding * 2
    }
}

private struct DotShapeGridWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 361

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DotShapeTile: View {
    let shape: DotShapeAsset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tileBackground)

                shapePreview
                    .padding(shape.previewTilePadding)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.border, lineWidth: isSelected ? 0 : 1.5)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .accessibilityLabel(shape.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var shapePreview: some View {
        if let builtInShape = shape.builtInShape {
            DotShapeDrawing(
                shape: builtInShape,
                color: isSelected ? Color.primaryForeground : Color.foreground
            )
        } else {
            Image(shape.previewAssetName)
                .resizable()
                .scaledToFit()
        }
    }

    private var tileBackground: Color {
        isSelected
            ? Color.primary
            : Color.card
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

    var builtInShape: BuiltInDotShape? {
        BuiltInDotShape(rawValue: name)
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

    static let defaultSelection = DotShapeAsset(name: BuiltInDotShape.circle.rawValue, previewName: nil)

    static let all: [DotShapeAsset] = [
        DotShapeAsset(name: BuiltInDotShape.circle.rawValue, previewName: nil),
        DotShapeAsset(name: BuiltInDotShape.square.rawValue, previewName: nil),
        DotShapeAsset(name: BuiltInDotShape.triangle.rawValue, previewName: nil),
        DotShapeAsset(name: BuiltInDotShape.star.rawValue, previewName: nil),
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
