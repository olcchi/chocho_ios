//
//  BottomSheetPanel.swift
//  chocho
//
//  Created by Codex on 2026/5/23.
//

import SwiftUI

/// 底部面板 Tab：波点 / 抽卡 / 背景 / 实况（控制 `LiveDotAnimation` 与预览播放）。
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

/// 可折叠底部面板：Tab 栏、各 Tab 控件、拖拽把手；不负责安全区，由 `ContentView` 贴底并延伸。
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
    let dotControls: BottomSheetDotControls
    let liveControls: BottomSheetLiveControls
    let backgroundControls: BottomSheetBackgroundControls
    var bottomSafeAreaInset: CGFloat = 0
    var isPanelEnabled: Bool = true
    var canClearTrace: Bool = false
    let onDrawDots: () -> Void
    var onClearTrace: () -> Void = {}

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
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { newHeight in
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
            dotControls: dotControls,
            liveControls: liveControls,
            backgroundControls: backgroundControls,
            canClearTrace: canClearTrace,
            onDrawDots: onDrawDots,
            onClearTrace: onClearTrace
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
    let dotControls: BottomSheetDotControls
    let liveControls: BottomSheetLiveControls
    let backgroundControls: BottomSheetBackgroundControls
    let canClearTrace: Bool
    let onDrawDots: () -> Void
    let onClearTrace: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotShapePickerPanel(
                    selectedCategory: dotControls.selectedDotShapeCategory,
                    selectedShape: dotControls.selectedDotShape,
                    dotScale: dotControls.dotScale,
                    selectedDotColor: dotControls.selectedDotColor,
                    dotCharacterText: dotControls.dotCharacterText
                )
            case .draw:
                DrawPanelControls(
                    dotCount: dotControls.dotCount,
                    usesRandomDotColors: dotControls.usesRandomDotColors,
                    isTraceDrawingEnabled: dotControls.isTraceDrawingEnabled,
                    photoCompression: dotControls.photoCompression,
                    canClearTrace: canClearTrace,
                    onDrawDots: onDrawDots,
                    onClearTrace: onClearTrace
                )
            case .background:
                BackgroundPanelControls(
                    backgroundStyle: backgroundControls.backgroundStyle,
                    backgroundColors: backgroundControls.backgroundColors,
                    extensionRatio: backgroundControls.extensionRatio,
                    extensionSide: backgroundControls.extensionSide,
                    backgroundPatternSpacing: backgroundControls.backgroundPatternSpacing
                )
            case .livePhoto:
                LivePanelControls(
                    liveDotAnimation: liveControls.liveDotAnimation,
                    isSourceLivePhoto: liveControls.isSourceLivePhoto,
                    isSourceLiveMotionEnabled: liveControls.isSourceLiveMotionEnabled,
                    canPlayLivePreview: liveControls.canPlayLivePreview,
                    livePreviewProgress: liveControls.livePreviewProgress,
                    isLivePreviewPlaying: liveControls.isLivePreviewPlaying,
                    onToggleLivePreviewPlayback: liveControls.onToggleLivePreviewPlayback
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

/// 实况 Tab：「动画」菜单绑定 `LiveDotAnimation`；「原图实况」与圆环预览按钮同一行。
private struct LivePanelControls: View {
    @Binding var liveDotAnimation: LiveDotAnimation
    var isSourceLivePhoto: Bool
    @Binding var isSourceLiveMotionEnabled: Bool
    var canPlayLivePreview: Bool
    var livePreviewProgress: Double
    var isLivePreviewPlaying: Bool
    var onToggleLivePreviewPlayback: () -> Void

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
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
                PanelCompactToggleButton(
                    title: "原图实况",
                    isOn: isSourceLiveMotionEnabled,
                    isEnabled: isSourceLivePhoto
                ) {
                    isSourceLiveMotionEnabled.toggle()
                }
                .frame(maxWidth: .infinity)
                .accessibilityHint(
                    isSourceLivePhoto
                        ? "播放上传 Live Photo 的原片动效"
                        : "当前照片不是 Live Photo，无法开启"
                )

                PanelSeparator(orientation: .vertical)

                HStack(spacing: 8) {
                    Text("预览")
                        .font(controlLabelFont)
                        .foregroundStyle(canPlayLivePreview ? Color.foreground : Color.mutedForeground)

                    Button(action: onToggleLivePreviewPlayback) {
                        LivePreviewPlaybackButton(
                            progress: livePreviewProgress,
                            isPlaying: isLivePreviewPlaying,
                            isEnabled: canPlayLivePreview
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPlayLivePreview)
                    .accessibilityLabel(isLivePreviewPlaying ? "暂停预览" : "预览")
                    .accessibilityValue(
                        canPlayLivePreview
                            ? "\(Int((livePreviewProgress * 100).rounded()))%"
                            : "不可用"
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 30)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// 实况预览：圆环表示 `livePreviewProgress`，中心为播放/暂停图标。
private struct LivePreviewPlaybackButton: View {
    var progress: Double
    var isPlaying: Bool
    var isEnabled: Bool

    private let size: CGFloat = 28
    private let lineWidth: CGFloat = 2

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.mutedForeground.opacity(isEnabled ? 0.35 : 0.2),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    isEnabled ? Color.ring : Color.mutedForeground,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.foreground : Color.mutedForeground)
        }
        .frame(width: size, height: size)
        .background(Color.input, in: Circle())
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
    @Binding var backgroundPatternSpacing: Double

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

            if backgroundStyle.supportsPatternSpacing {
                StyledSlider(
                    title: backgroundPatternSpacingTitle,
                    value: $backgroundPatternSpacing,
                    range: PuzzleBackgroundPatternSpacing.minControlValue...PuzzleBackgroundPatternSpacing.maxControlValue,
                    step: PuzzleBackgroundPatternSpacing.step
                )
                .padding(.horizontal, 2)
                .padding(.top, 4)

                PanelRowSeparator()
                    .padding(.top, 4)
            }

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
            case .solid:
                backgroundColorPicker(title: "颜色", color: backgroundColorBinding(\.fillColor))
            case .grid:
                backgroundColorPicker(title: "底色", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "网格线", color: backgroundColorBinding(\.lineColor))
            case .stripes:
                backgroundColorPicker(title: "条纹一", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "条纹二", color: backgroundColorBinding(\.alternateColor))
            case .polkaDots:
                backgroundColorPicker(title: "底色", color: backgroundColorBinding(\.fillColor))
                backgroundColorPicker(title: "圆点", color: backgroundColorBinding(\.lineColor))
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
        if extensionSide == .center {
            return "背景边距"
        }

        return extensionSide.isHorizontal ? "背景宽度" : "背景高度"
    }

    private var backgroundPatternSpacingTitle: String {
        switch backgroundStyle {
        case .solid:
            return "图案间距"
        case .grid:
            return "方格大小"
        case .stripes:
            return "条纹粗细"
        case .polkaDots:
            return "圆点大小"
        case .halftone:
            return "图案间距"
        }
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

enum DrawPanelTraceButtonLayout {
    static let traceToggleWeight: CGFloat = 2
    static let clearTraceButtonWeight: CGFloat = 1
    static let spacing: CGFloat = 8

    static var totalWeight: CGFloat {
        traceToggleWeight + clearTraceButtonWeight
    }

    static func width(for totalWidth: CGFloat, weight: CGFloat) -> CGFloat {
        max(0, totalWidth - spacing) * weight / totalWeight
    }
}

private struct DrawPanelControls: View {
    @Binding var dotCount: Double
    @Binding var usesRandomDotColors: Bool
    @Binding var isTraceDrawingEnabled: Bool
    @Binding var photoCompression: MainPhotoCompression
    let canClearTrace: Bool
    let onDrawDots: () -> Void
    let onClearTrace: () -> Void

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
                    PanelCompactToggleButton(
                        title: "随机色彩",
                        isOn: usesRandomDotColors
                    ) {
                        usesRandomDotColors.toggle()
                    }
                    .frame(maxWidth: .infinity)

                    PanelSeparator(orientation: .vertical)

                    traceButtonGroup
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 30)
                .padding(.top, 4)

                PanelRowSeparator()
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Text("压缩")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.mutedForeground)

                    Spacer(minLength: 8)

                    PanelValueMenu(
                        accessibilityTitle: "压缩",
                        selection: $photoCompression,
                        options: MainPhotoCompression.allCases,
                        title: { $0.title },
                        font: .system(size: 12, weight: .regular)
                    )
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

    private var activeColor: Color {
        Color.primary
    }

    private var traceButtonGroup: some View {
        GeometryReader { proxy in
            HStack(spacing: DrawPanelTraceButtonLayout.spacing) {
                PanelCompactToggleButton(
                    title: "手绘轨迹",
                    isOn: isTraceDrawingEnabled
                ) {
                    isTraceDrawingEnabled.toggle()
                }
                    .frame(
                        width: DrawPanelTraceButtonLayout.width(
                            for: proxy.size.width,
                            weight: DrawPanelTraceButtonLayout.traceToggleWeight
                        )
                    )

                clearTraceButton
                    .frame(
                        width: DrawPanelTraceButtonLayout.width(
                            for: proxy.size.width,
                            weight: DrawPanelTraceButtonLayout.clearTraceButtonWeight
                        )
                    )
            }
        }
        .frame(height: 30)
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

    private var clearTraceButton: some View {
        Button(action: onClearTrace) {
            Image("public/archive")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Color.input, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!canClearTrace)
        .opacity(canClearTrace ? 1 : 0.42)
        .accessibilityLabel("清空手绘轨迹")
    }

}

/// 抽卡 / 实况等面板共用的胶囊开关：按钮即开关，选中时主色底。
private struct PanelCompactToggleButton: View {
    let title: String
    let isOn: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    private var activeColor: Color { Color.primary }
    private var inactiveColor: Color { Color.input }

    var body: some View {
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

private struct DotShapePickerPanel: View {
    @Binding var selectedCategory: DotShapeCategory
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var dotCharacterText: String
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

            if selectedShape.isCharacterDot {
                DotCharacterTextField(text: $dotCharacterText)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)

                PanelRowSeparator()
            }

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

private struct DotCharacterTextField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("字符")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.foreground)

            TextField("输入文字", text: $text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.foreground)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .frame(height: 30)
                .background(Color.input, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                }
        }
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
    @State private var lastPickerColor = DotColorPickerSelection.fallbackPickerColor

    private var usesCollageTint: Bool {
        PuzzleDotCollageColor.usesCollageTint(selectedDotColor: selectedDotColor)
    }

    var body: some View {
        HStack(spacing: 10) {
            ColorPicker("颜色", selection: colorPickerSelection, supportsOpacity: false)
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
        .onAppear(perform: rememberSelectedColorIfNeeded)
        .onChange(of: selectedDotColor) { _, _ in
            rememberSelectedColorIfNeeded()
        }
    }

    private var colorPickerSelection: Binding<Color> {
        Binding(
            get: {
                DotColorPickerSelection.pickerColor(
                    for: selectedDotColor,
                    fallbackColor: lastPickerColor
                )
            },
            set: { newValue in
                let opaqueColor = DotColorPickerSelection.selectedColor(fromPickerColor: newValue)
                lastPickerColor = opaqueColor
                selectedDotColor = opaqueColor
            }
        )
    }

    private func rememberSelectedColorIfNeeded() {
        guard !usesCollageTint else { return }
        lastPickerColor = DotColorPickerSelection.selectedColor(fromPickerColor: selectedDotColor)
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
        if shape.isCharacterDot {
            CharacterDotGlyphView(
                text: CharacterDotText.defaultText,
                color: isSelected ? Color.primaryForeground : Color.foreground
            )
        } else if let builtInShape = shape.builtInShape {
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
