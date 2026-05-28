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
    case livePhoto = "live"

    var id: Self { self }

    var title: String {
        switch self {
        case .dots:
            "波点"
        case .draw:
            "抽卡"
        case .background:
            "背景"
        case .livePhoto:
            "实况"
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
        case .livePhoto:
            "public/sparkles"
        }
    }

    var tabIcon: Image {
        switch self {
        case .livePhoto:
            Image(systemName: "livephoto")
        case .dots, .draw, .background:
            Image(iconAssetName)
        }
    }
}

struct BottomSheetPanel: View {
    static let topCornerRadius: CGFloat = 24
    static let panelMotion: Animation = .smooth(duration: 0.24)
    /// Horizontal inset for panel content; also used for header and history controls aligned to the panel edge.
    static let contentHorizontalInset: CGFloat = 16
    private static let contentBottomInset: CGFloat = 4
    private static let tabBarTopSpacing: CGFloat = 8
    private static let tabBarItemHeight: CGFloat = 42
    private static let handleTouchHeight: CGFloat = 28
    private static let panelContentTopPadding: CGFloat = 8
    private static let collapseDragThreshold: CGFloat = 28

    private static var tabBarSectionHeight: CGFloat {
        tabBarTopSpacing + tabBarItemHeight
    }

    static var collapsedHeight: CGFloat {
        visibleHeight(isExpanded: false, contentHeight: 0)
    }

    static func collapsiblePanelHeight(isExpanded: Bool, contentHeight: CGFloat) -> CGFloat {
        if isExpanded {
            handleTouchHeight
                + panelContentTopPadding
                + contentHeight
                + tabBarTopSpacing
        } else {
            handleTouchHeight
        }
    }

    static func visibleHeight(isExpanded: Bool, contentHeight: CGFloat) -> CGFloat {
        collapsiblePanelHeight(isExpanded: isExpanded, contentHeight: contentHeight)
            + tabBarSectionHeight
            + contentBottomInset
    }

    /// How much vertical space the expanded panel covers beyond its collapsed footprint.
    static func panelExpansionOcclusionHeight(contentHeight: CGFloat) -> CGFloat {
        visibleHeight(isExpanded: true, contentHeight: contentHeight)
            - visibleHeight(isExpanded: false, contentHeight: contentHeight)
    }

    /// Typical expanded content height for the default tab, used before the panel is measured.
    static let defaultExpandedContentHeight: CGFloat = 268

    static var defaultExpandedVisibleHeight: CGFloat {
        visibleHeight(isExpanded: true, contentHeight: defaultExpandedContentHeight)
    }

    /// Height reserved at the bottom of the canvas stack for the panel overlay.
    static func bottomPanelInset(isExpanded: Bool, panelVisibleHeight: CGFloat) -> CGFloat {
        if panelVisibleHeight > 0 {
            return panelVisibleHeight
        }
        return isExpanded ? defaultExpandedVisibleHeight : collapsedHeight
    }

    @Binding var panelVisibleHeight: CGFloat
    @Binding var selectedTab: PanelTab
    @Binding var isExpanded: Bool
    @Binding var dotCount: Double
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var usesRandomDotColors: Bool
    @Binding var selectedDotShape: DotShapeAsset
    @Binding var selectedDotShapeCategory: DotShapeCategory
    @Binding var isTraceDrawingEnabled: Bool
    @Binding var liveDotAnimation: LiveDotAnimation
    var livePreviewProgress: Double = 0
    var isLivePreviewPlaying: Bool = false
    var onToggleLivePreviewPlayback: () -> Void = {}
    @Binding var extensionRatio: CGFloat
    @Binding var extensionSide: PuzzleCanvasExtensionSide
    @Binding var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors
    var bottomSafeAreaInset: CGFloat = 0
    var isPanelEnabled: Bool = true
    let onDrawDots: () -> Void

    /// Vertical offset for history controls anchored to the panel top edge.
    static let historyControlsClearance: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            collapsiblePanelSection

            fixedTabBarSection
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.bottom, Self.contentBottomInset + bottomSafeAreaInset)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { _, newHeight in
            guard newHeight > 0 else { return }
            panelVisibleHeight = newHeight
        }
        .background(panelBackground)
        .clipped()
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.10), radius: 28, x: 0, y: -5)
        .animation(Self.panelMotion, value: isExpanded)
        .animation(Self.panelMotion, value: selectedTab)
    }

    private var collapsiblePanelSection: some View {
        VStack(spacing: 0) {
            panelHandleArea

            if isExpanded {
                panelContent
                    .padding(.top, Self.panelContentTopPadding)
                    .padding(.bottom, Self.tabBarTopSpacing)
                    .transition(.opacity)
                    .animation(Self.panelMotion, value: selectedTab)
            }
        }
        .clipped()
    }

    private var fixedTabBarSection: some View {
        panelTabBar
            .frame(height: Self.tabBarItemHeight, alignment: .top)
            .disabled(!isPanelEnabled)
            .opacity(isPanelEnabled ? 1 : 0.42)
    }

    private var panelContent: some View {
        PanelContentCard(
            tab: selectedTab,
            dotCount: $dotCount,
            dotScale: $dotScale,
            selectedDotColor: $selectedDotColor,
            usesRandomDotColors: $usesRandomDotColors,
            selectedDotShape: $selectedDotShape,
            selectedDotShapeCategory: $selectedDotShapeCategory,
            isTraceDrawingEnabled: $isTraceDrawingEnabled,
            liveDotAnimation: $liveDotAnimation,
            livePreviewProgress: livePreviewProgress,
            isLivePreviewPlaying: isLivePreviewPlaying,
            onToggleLivePreviewPlayback: onToggleLivePreviewPlayback,
            extensionRatio: $extensionRatio,
            extensionSide: $extensionSide,
            backgroundStyle: $backgroundStyle,
            backgroundColors: $backgroundColors,
            onDrawDots: onDrawDots
        )
        .id(selectedTab)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(isPanelEnabled ? 1 : 0.42)
        .allowsHitTesting(isPanelEnabled)
        .disabled(!isPanelEnabled)
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
            ForEach(PanelTab.allCases, id: \.id) { tab in
                panelTabBarButton(for: tab)
            }
        }
    }

    private func panelTabBarButton(for tab: PanelTab) -> some View {
        let isSelected = tab == selectedTab

        return Button {
            if tab != selectedTab {
                withAnimation(Self.panelMotion) {
                    selectedTab = tab
                }
            }
            if !isExpanded {
                setExpanded(true)
            }
        } label: {
            VStack(spacing: 3) {
                tab.tabIcon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text(tab.title)
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(isSelected ? activeTabColor : Color.mutedForeground)
            .frame(maxWidth: .infinity)
            .frame(height: Self.tabBarItemHeight)
            .scaleEffect(isSelected ? 1.1 : 1)
            .contentShape(Rectangle())
            .animation(.smooth(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        withAnimation(Self.panelMotion) {
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
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.foreground)
                    .frame(height: 26)
                    .padding(.horizontal, 9)
            }
            .buttonStyle(.plain)
            .disabled(!canClear)
            .opacity(canClear ? 1 : 0.42)
            .accessibilityLabel("清空画布内容")

            PanelSeparator(orientation: .vertical)

            historyButton(
                assetName: "public/undo",
                isEnabled: canUndo,
                accessibilityLabel: "撤销",
                action: onUndo
            )

            PanelSeparator(orientation: .vertical)

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
    @Binding var selectedDotShapeCategory: DotShapeCategory
    @Binding var isTraceDrawingEnabled: Bool
    @Binding var liveDotAnimation: LiveDotAnimation
    var livePreviewProgress: Double
    var isLivePreviewPlaying: Bool
    var onToggleLivePreviewPlayback: () -> Void
    @Binding var extensionRatio: CGFloat
    @Binding var extensionSide: PuzzleCanvasExtensionSide
    @Binding var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors
    let onDrawDots: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotShapePickerPanel(
                    selectedCategory: $selectedDotShapeCategory,
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
                BackgroundPanelControls(
                    backgroundStyle: $backgroundStyle,
                    backgroundColors: $backgroundColors,
                    extensionRatio: $extensionRatio,
                    extensionSide: $extensionSide
                )
            case .livePhoto:
                LivePanelControls(
                    liveDotAnimation: $liveDotAnimation,
                    livePreviewProgress: livePreviewProgress,
                    isLivePreviewPlaying: isLivePreviewPlaying,
                    onToggleLivePreviewPlayback: onToggleLivePreviewPlayback
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private enum PanelSeparatorStyle {
    static let color = Color.border
    static let thickness: CGFloat = 1
    static let linePadding: CGFloat = 1
    static let verticalLineHeight: CGFloat = 18
}

private struct PanelSeparator: View {
    enum Orientation {
        case horizontal
        case vertical
    }

    var orientation: Orientation

    var body: some View {
        switch orientation {
        case .horizontal:
            Rectangle()
                .fill(PanelSeparatorStyle.color)
                .frame(maxWidth: .infinity)
                .frame(height: PanelSeparatorStyle.thickness)
                .padding(.vertical, PanelSeparatorStyle.linePadding)
        case .vertical:
            Rectangle()
                .fill(PanelSeparatorStyle.color)
                .frame(
                    width: PanelSeparatorStyle.thickness,
                    height: PanelSeparatorStyle.verticalLineHeight
                )
                .padding(.horizontal, PanelSeparatorStyle.linePadding)
        }
    }
}

private struct PanelRowSeparator: View {
    var body: some View {
        PanelSeparator(orientation: .horizontal)
    }
}

private struct LivePanelControls: View {
    @Binding var liveDotAnimation: LiveDotAnimation
    var livePreviewProgress: Double
    var isLivePreviewPlaying: Bool
    var onToggleLivePreviewPlayback: () -> Void

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
    }

    private var canPlayPreview: Bool {
        liveDotAnimation != .none
    }

    private var playbackElapsed: TimeInterval {
        livePreviewProgress * liveDotAnimation.motionExportDuration
    }

    private var playbackTimeLabel: String {
        String(format: "%.1f", playbackElapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("动画")
                    .font(controlLabelFont)
                    .foregroundStyle(Color.foreground)

                Spacer(minLength: 0)

                PanelValueMenu(
                    accessibilityTitle: "动画",
                    selection: $liveDotAnimation,
                    options: LiveDotAnimation.allCases,
                    title: { $0.title },
                    font: controlLabelFont
                )
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)

            PanelRowSeparator()

            HStack(spacing: 10) {
                Button(action: onToggleLivePreviewPlayback) {
                    HStack(spacing: 6) {
                        Image(systemName: isLivePreviewPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isLivePreviewPlaying ? "暂停" : "预览")
                            .font(controlLabelFont)
                        if canPlayPreview {
                            Text(playbackTimeLabel)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.mutedForeground)
                        }
                    }
                    .foregroundStyle(canPlayPreview ? Color.foreground : Color.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.input, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canPlayPreview)
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct Y2KBackgroundColorPairRow: View {
    var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors

    @State private var shuffledIndices: [Int] = Y2KBackgroundPalette.shuffledIndices()
    @State private var rowBallSize: CGFloat = 28

    private let spacing: CGFloat = 6

    var body: some View {
        Color.clear
            .frame(height: rowBallSize)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { proxy in
                    let rowWidth = contentWidth(in: proxy)
                    let ballSize = Y2KBackgroundPalette.ballSize(
                        availableWidth: rowWidth,
                        spacing: spacing
                    )
                    let pairs = visiblePairs

                    HStack(spacing: spacing) {
                        ForEach(pairs) { pair in
                            Button {
                                var colors = backgroundColors
                                Y2KBackgroundPalette.apply(pair, to: &colors, style: backgroundStyle)
                                backgroundColors = colors
                            } label: {
                                SplitColorSwatchBall(
                                    leading: pair.fill,
                                    trailing: pair.accent,
                                    size: ballSize
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Y2K 配色")
                            .accessibilityHint("将这对颜色应用到背景")
                        }

                        Button(action: reshuffleVisiblePairs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: ballSize * 0.38, weight: .semibold))
                                .foregroundStyle(Color.foreground)
                                .frame(width: ballSize, height: ballSize)
                                .background(Color.input, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.border, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("刷新配色")
                        .accessibilityHint("随机换一批 Y2K 配色圆球")
                    }
                    .frame(width: rowWidth, height: ballSize)
                    .position(
                        x: proxy.safeAreaInsets.leading + rowWidth / 2,
                        y: proxy.size.height / 2
                    )
                    .onAppear {
                        rowBallSize = ballSize
                    }
                    .onChange(of: ballSize) { _, newSize in
                        rowBallSize = newSize
                    }
                }
            }
    }

    private func contentWidth(in proxy: GeometryProxy) -> CGFloat {
        let horizontalSafe = proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
        return max(proxy.size.width - horizontalSafe, 1)
    }

    private var visiblePairs: [Y2KBackgroundPalette.Pair] {
        shuffledIndices
            .prefix(Y2KBackgroundPalette.colorBallCountPerRow)
            .map { Y2KBackgroundPalette.pairs[$0] }
    }

    private func reshuffleVisiblePairs() {
        shuffledIndices = Y2KBackgroundPalette.shuffledIndices()
    }
}

private struct SplitColorSwatchBall: View {
    let leading: Color
    let trailing: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [leading, leading, trailing, trailing],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.border.opacity(0.9), lineWidth: 1)
            }
    }
}

private struct BackgroundPanelControls: View {
    @Binding var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors
    @Binding var extensionRatio: CGFloat
    @Binding var extensionSide: PuzzleCanvasExtensionSide

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                backgroundStyleControl
                PanelSeparator(orientation: .vertical)
                backgroundPositionControl
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)

            PanelRowSeparator()

            backgroundColorPickers
                .padding(.horizontal, 2)
                .padding(.vertical, 4)

            Y2KBackgroundColorPairRow(
                backgroundStyle: backgroundStyle,
                backgroundColors: $backgroundColors
            )
            .padding(.bottom, 4)

            PanelRowSeparator()

            StyledSlider(
                title: extensionSizeTitle,
                value: extensionRatioPercent,
                range: 0...100,
                step: 1,
                valueText: { "\(Int($0.rounded()))%" }
            )
            .padding(.horizontal, 2)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
    }

    private var backgroundStyleControl: some View {
        HStack(spacing: 6) {
            Text("背景样式")
                .font(controlLabelFont)
                .foregroundStyle(Color.foreground)

            Spacer(minLength: 0)

            PanelValueMenu(
                accessibilityTitle: "背景样式",
                selection: $backgroundStyle,
                options: PuzzleBackgroundStyle.allCases,
                title: { $0.title },
                font: controlLabelFont
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColorPickers: some View {
        HStack(spacing: 10) {
            switch backgroundStyle {
            case .grid:
                backgroundColorPicker(title: "底色", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "网格线", color: backgroundColorBinding(\.lineColor))
            case .stripes:
                backgroundColorPicker(title: "条纹一", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "条纹二", color: backgroundColorBinding(\.alternateColor))
            case .halftone:
                backgroundColorPicker(title: "底色", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "网点", color: backgroundColorBinding(\.lineColor))
            }
        }
    }

    private func backgroundColorPicker(title: String, color: Binding<Color>) -> some View {
        ColorPicker(title, selection: color, supportsOpacity: false)
            .font(controlLabelFont)
            .foregroundStyle(Color.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
    }

    private func backgroundColorBinding(
        _ keyPath: WritableKeyPath<PuzzleBackgroundColors, Color>
    ) -> Binding<Color> {
        Binding(
            get: { backgroundColors[keyPath: keyPath] },
            set: { backgroundColors[keyPath: keyPath] = $0 }
        )
    }

    private var backgroundPositionControl: some View {
        HStack(spacing: 6) {
            Text("背景位置")
                .font(controlLabelFont)
                .foregroundStyle(Color.foreground)

            Spacer(minLength: 0)

            PanelValueMenu(
                accessibilityTitle: "背景位置",
                selection: $extensionSide,
                options: PuzzleCanvasExtensionSide.allCases,
                title: { $0.title },
                font: controlLabelFont
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var extensionSizeTitle: String {
        extensionSide.isHorizontal ? "背景宽度" : "背景高度"
    }

    private var extensionRatioPercent: Binding<Double> {
        Binding(
            get: {
                Double(min(max(extensionRatio, 0), 1) * 100)
            },
            set: { newValue in
                extensionRatio = CGFloat(min(max(newValue / 100, 0), 1))
            }
        )
    }
}

private struct PanelValueMenu<Value: Hashable & Equatable>: View {
    let accessibilityTitle: String
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> String
    let font: Font

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(title(selection))
                    .font(font)
                    .foregroundStyle(Color.foreground)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.mutedForeground)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(title(selection))
    }
}

private struct DrawPanelControls: View {
    @Binding var dotCount: Double
    @Binding var usesRandomDotColors: Bool
    @Binding var isTraceDrawingEnabled: Bool
    let onDrawDots: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StyledSlider(
                    title: "波点数量",
                    value: $dotCount,
                    range: 0...30,
                    step: 1
                )
                .padding(.bottom, 4)

                PanelRowSeparator()

                HStack(spacing: 10) {
                    compactToggleButton(
                        title: "随机色彩",
                        isOn: usesRandomDotColors
                    ) {
                        usesRandomDotColors.toggle()
                    }

                    PanelSeparator(orientation: .vertical)

                    compactToggleButton(
                        title: "手绘轨迹",
                        isOn: isTraceDrawingEnabled
                    ) {
                        isTraceDrawingEnabled.toggle()
                    }
                }
                .frame(height: 30)
                .padding(.top, 4)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)

            PanelRowSeparator()

            drawButton
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
                    .font(.system(size: 14, weight: .regular))
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

    private func compactToggleButton(
        title: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
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
                .font(.system(size: 12, weight: .regular))
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
    @Binding var selectedCategory: DotShapeCategory
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @AppStorage("chocho.dotShape.recentNames") private var recentShapeNamesStore = DotShapeAsset.defaultSelection.name

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DotShapeCategoryTabs(selectedCategory: $selectedCategory)
                .padding(.bottom, 3)

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
            .padding(.vertical, 3)

            DotSizeSlider(dotScale: $dotScale)
                .padding(.vertical, 3)

            PanelRowSeparator()

            DotColorPicker(selectedDotColor: $selectedDotColor)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .top)
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

    private var usesCollageTint: Bool {
        PuzzleDotCollageColor.usesCollageTint(selectedDotColor: selectedDotColor)
    }

    var body: some View {
        HStack(spacing: 10) {
            ColorPicker("颜色", selection: $selectedDotColor, supportsOpacity: false)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)

            Button {
                selectedDotColor = .clear
            } label: {
                Text("清除")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(usesCollageTint ? Color.primaryForeground : Color.foreground)
                    .frame(width: 48, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(usesCollageTint ? Color.primary : Color.input)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                usesCollageTint ? Color.primary.opacity(0.75) : Color.border,
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("清除颜色")
            .accessibilityHint("恢复主图与背景的互相拼贴")
            .accessibilityAddTraits(usesCollageTint ? .isSelected : [])
        }
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
                            .font(.system(size: 14, weight: .regular))
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

    private let referenceColumnCount = 6
    private let gridSpacing: CGFloat = 8
    private let gridPadding: CGFloat = 8

    private var tileSide: CGFloat {
        let horizontalGaps = CGFloat(referenceColumnCount - 1) * gridSpacing
        let contentWidth = availableWidth - gridPadding * 2 - horizontalGaps
        guard contentWidth > 0 else { return 0 }
        return contentWidth / CGFloat(referenceColumnCount)
    }

    private var gridViewportHeight: CGFloat {
        tileSide + gridPadding * 2
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: gridSpacing) {
                ForEach(shapes) { shape in
                    DotShapeTile(
                        shape: shape,
                        isSelected: shape == selectedShape
                    ) {
                        onSelect(shape)
                    }
                    .frame(width: tileSide, height: tileSide)
                }
            }
            .padding(gridPadding)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: gridViewportHeight)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: DotShapeGridWidthKey.self, value: proxy.size.width)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.border, lineWidth: 1.5)
        }
        .onPreferenceChange(DotShapeGridWidthKey.self) { width in
            availableWidth = width
        }
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
            DotShapeAssetImageView(
                assetName: shape.assetImageName,
                renderingMode: shape.usesTemplatePreview ? .template : .original,
                tintColor: shape.usesTemplatePreview ? previewColor : nil
            )
        }
    }

    private var previewColor: Color {
        isSelected ? Color.primaryForeground : Color.foreground
    }

    private var tileBackground: Color {
        isSelected
            ? Color.primary
            : Color.card
    }
}

nonisolated enum DotShapeAssetCategoryParser {
    static let basicCategory = "基础"
    static let categorizedSuffixes: Set<String> = [
        "小物",
        "彩纸",
        "贴纸",
        "纽扣",
        "水钻",
        "布",
        "针线"
    ]

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

    static let assetCategorySuffixes = Set(
        DotShapeAssetCategoryParser.categorizedSuffixes
    )

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

    var id: String { name }

    var title: String {
        DotShapeAssetCategoryParser.title(for: name)
    }

    var category: String {
        DotShapeAssetCategoryParser.category(for: name)
    }

    private var assetCategorySuffix: String? {
        DotShapeAssetCategoryParser.suffix(in: name)
    }

    var assetImageName: String {
        "public/\(name)"
    }

    var previewTilePadding: CGFloat {
        category == "基础" ? 16 : 9
    }

    var usesTemplatePreview: Bool {
        category == "基础"
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

    static let defaultSelection = DotShapeAsset(name: BuiltInDotShape.circle.rawValue)

    static let all: [DotShapeAsset] =
        BuiltInDotShape.allCases.map { DotShapeAsset(name: $0.rawValue) }
        + DotShapeCatalog.assetNames
            .filter { BuiltInDotShape(rawValue: $0) == nil }
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
