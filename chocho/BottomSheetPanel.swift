//
//  BottomSheetPanel.swift
//  chocho
//
//  Created by Codex on 2026/5/23.
//

import SwiftUI

/// 底部面板 Tab：波点 / 风格 / 布局 / 实况（控制 `LiveDotAnimation` 与预览播放）。
enum PanelTab: String, CaseIterable, Identifiable {
    case dots
    case style
    case background
    case livePhoto = "live"

    var id: Self { self }

    var title: String {
        switch self {
        case .dots:
            "波点"
        case .style:
            "风格"
        case .background:
            "布局"
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
            "public/LucideAsterisk"
        case .style:
            "public/CarbonChartVennDiagram"
        case .background:
            "public/LucideWaves"
        case .livePhoto:
            "public/sparkles"
        }
    }

    var tabIcon: Image {
        switch self {
        case .livePhoto:
            Image(systemName: "livephoto")
        case .dots, .style, .background:
            Image(iconAssetName)
        }
    }
}

/// 可折叠底部面板：菜单入口与各 Tab 详情；不负责安全区，由 `ContentView` 贴底并延伸。
struct BottomSheetPanel: View {
    static let panelMotion: Animation = .smooth(duration: 0.24)
    /// Horizontal inset for panel content and header alignment.
    static let contentHorizontalInset: CGFloat = 16
    private static let contentBottomInset: CGFloat = 4
    private static let menuRowHeight: CGFloat = 42
    private static let detailHeaderHeight: CGFloat = 28
    private static let detailHeaderBottomSpacing: CGFloat = 8
    private static let panelInnerTopInset: CGFloat = 16

    static func menuSectionHeight() -> CGFloat {
        menuRowHeight
    }

    static var collapsedHeight: CGFloat {
        visibleHeight(isExpanded: false, contentHeight: 0)
    }

    static func detailSectionHeight(contentHeight: CGFloat) -> CGFloat {
        detailHeaderHeight + detailHeaderBottomSpacing + contentHeight
    }

    static func visibleHeight(isExpanded: Bool, contentHeight: CGFloat) -> CGFloat {
        panelInnerTopInset
            + (isExpanded
                ? detailSectionHeight(contentHeight: contentHeight)
                : menuSectionHeight())
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
    @Binding var isDotEditingEnabled: Bool
    let dotControls: BottomSheetDotControls
    let liveControls: BottomSheetLiveControls
    let backgroundControls: BottomSheetBackgroundControls
    var bottomSafeAreaInset: CGFloat = 0
    var isPanelEnabled: Bool = true
    var canClearTrace: Bool = false
    let onDrawDots: () -> Void
    let onToggleSubjectOutline: () -> Void
    var onClearTrace: () -> Void = {}
    var onBeginTraceFeature: () -> Void = {}
    var onConfirmTraceFeature: () -> Void = {}
    var onCancelTraceFeature: () -> Void = {}
    var onBeginPhotoCompressionFeature: () -> Void = {}
    var onConfirmPhotoCompressionFeature: () -> Void = {}
    var onCancelPhotoCompressionFeature: () -> Void = {}
    var onBeginY2KCCDFilterFeature: () -> Void = {}
    var onConfirmY2KCCDFilterFeature: () -> Void = {}
    var onCancelY2KCCDFilterFeature: () -> Void = {}
    @State private var selectedStyleFeature: StylePanelFeature?

    var body: some View {
        Group {
            if isExpanded {
                panelDetailView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                panelMenuView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.top, Self.panelInnerTopInset)
        .padding(.bottom, Self.contentBottomInset + bottomSafeAreaInset)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { newHeight in
            guard newHeight > 0 else { return }
            panelVisibleHeight = newHeight
        }
        .background(panelBackground)
        .clipped()
        .animation(Self.panelMotion, value: isExpanded)
        .animation(Self.panelMotion, value: selectedTab)
        .animation(Self.panelMotion, value: selectedStyleFeature)
        .onChange(of: selectedTab) { _, _ in
            cancelActiveStyleFeatureSessionIfNeeded()
            selectedStyleFeature = nil
        }
        .onChange(of: isExpanded) { _, isExpanded in
            if !isExpanded {
                cancelActiveStyleFeatureSessionIfNeeded()
                selectedStyleFeature = nil
            }
        }
        .onChange(of: selectedStyleFeature) { _, feature in
            switch feature {
            case .trace:
                onBeginTraceFeature()
            case .photoCompression:
                onBeginPhotoCompressionFeature()
            case .ccd:
                onBeginY2KCCDFilterFeature()
            default:
                break
            }
        }
    }

    private var panelMenuView: some View {
        PanelMenuGrid(onSelect: openDetail(for:))
            .frame(height: Self.menuSectionHeight())
            .disabled(!isPanelEnabled)
            .opacity(isPanelEnabled ? 1 : 0.42)
    }

    private var panelDetailView: some View {
        VStack(spacing: 0) {
            if !showsStyleFeatureActionRow {
                PanelDetailHeader(
                    title: detailHeaderTitle,
                    onBack: closeDetailOrStyleFeature
                )

                panelContent
                    .padding(.top, Self.detailHeaderBottomSpacing)
            } else {
                panelContent
            }
        }
        .opacity(isPanelEnabled ? 1 : 0.42)
        .allowsHitTesting(isPanelEnabled)
        .disabled(!isPanelEnabled)
    }

    private var showsStyleFeatureActionRow: Bool {
        selectedTab == .style
            && (
                selectedStyleFeature == .trace
                    || selectedStyleFeature == .photoCompression
                    || selectedStyleFeature == .ccd
            )
    }

    private var panelContent: some View {
        PanelContentCard(
            tab: selectedTab,
            dotControls: dotControls,
            liveControls: liveControls,
            backgroundControls: backgroundControls,
            isDotEditingEnabled: isDotEditingEnabled,
            canClearTrace: canClearTrace,
            selectedStyleFeature: $selectedStyleFeature,
            onDrawDots: onDrawDots,
            onToggleSubjectOutline: onToggleSubjectOutline,
            onClearTrace: onClearTrace,
            onConfirmTraceFeature: confirmTraceFeature,
            onCancelTraceFeature: cancelTraceFeature,
            onConfirmPhotoCompressionFeature: confirmPhotoCompressionFeature,
            onCancelPhotoCompressionFeature: cancelPhotoCompressionFeature,
            onConfirmY2KCCDFilterFeature: confirmY2KCCDFilterFeature,
            onCancelY2KCCDFilterFeature: cancelY2KCCDFilterFeature
        )
        .id(selectedTab)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detailHeaderTitle: String {
        if selectedTab == .style, let selectedStyleFeature {
            return selectedStyleFeature.title
        }
        return selectedTab.title
    }

    private var panelBackground: some View {
        PanelGlassBackground()
    }

    private func openDetail(for tab: PanelTab) {
        withAnimation(Self.panelMotion) {
            selectedTab = tab
            isExpanded = true
        }
    }

    private func closeDetail() {
        withAnimation(Self.panelMotion) {
            isExpanded = false
        }
    }

    private func closeDetailOrStyleFeature() {
        if selectedTab == .style, selectedStyleFeature == .trace {
            cancelTraceFeature()
            return
        }
        if selectedTab == .style, selectedStyleFeature == .photoCompression {
            cancelPhotoCompressionFeature()
            return
        }
        if selectedTab == .style, selectedStyleFeature == .ccd {
            cancelY2KCCDFilterFeature()
            return
        }
        if selectedTab == .style, selectedStyleFeature != nil {
            withAnimation(Self.panelMotion) {
                selectedStyleFeature = nil
            }
        } else {
            closeDetail()
        }
    }

    private func cancelActiveStyleFeatureSessionIfNeeded() {
        switch selectedStyleFeature {
        case .trace:
            onCancelTraceFeature()
        case .photoCompression:
            onCancelPhotoCompressionFeature()
        case .ccd:
            onCancelY2KCCDFilterFeature()
        default:
            break
        }
    }

    private func cancelTraceFeature() {
        onCancelTraceFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func confirmTraceFeature() {
        onConfirmTraceFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func cancelPhotoCompressionFeature() {
        onCancelPhotoCompressionFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func confirmPhotoCompressionFeature() {
        onConfirmPhotoCompressionFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func cancelY2KCCDFilterFeature() {
        onCancelY2KCCDFilterFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func confirmY2KCCDFilterFeature() {
        onConfirmY2KCCDFilterFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }
}

private struct PanelMenuGrid: View {
    let onSelect: (PanelTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases) { tab in
                PanelMenuItem(tab: tab) {
                    onSelect(tab)
                }
            }
        }
    }
}

private struct PanelMenuItem: View {
    let tab: PanelTab
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                tab.tabIcon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundStyle(Color.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: BottomSheetPanel.menuSectionHeight())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

private struct PanelDetailHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))

                    Text("返回")
                        .font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(Color.foreground)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.foreground)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 52, height: 28)
        }
        .frame(height: 28)
    }
}

private struct PanelGlassBackground: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(Color.popover.opacity(0.28))
                    .glassEffect(
                        .regular.tint(Color.popover.opacity(0.42)),
                        in: Rectangle()
                    )
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Rectangle()
                            .fill(Color.popover.opacity(0.68))
                    }
            }
        }
        .environment(\.colorScheme, .light)
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
            historyButton(
                assetName: "public/trash",
                isEnabled: canClear,
                accessibilityLabel: "清空画布内容",
                action: onClear
            )

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
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PanelEditModeToggle: View {
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        Button {
            guard isEnabled else { return }

            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))

                Text("编辑")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(isOn ? Color.primaryForeground : Color.foreground)
            .frame(height: 30)
            .padding(.horizontal, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(isOn ? Color.primary : Color.clear)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isOn ? Color.primary.opacity(0.75) : Color.border,
                            lineWidth: 1
                        )
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel("编辑")
        .accessibilityValue(isOn ? "已开启" : "已关闭")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct PanelContentCard: View {
    let tab: PanelTab
    let dotControls: BottomSheetDotControls
    let liveControls: BottomSheetLiveControls
    let backgroundControls: BottomSheetBackgroundControls
    let isDotEditingEnabled: Bool
    let canClearTrace: Bool
    @Binding var selectedStyleFeature: StylePanelFeature?
    let onDrawDots: () -> Void
    let onToggleSubjectOutline: () -> Void
    let onClearTrace: () -> Void
    let onConfirmTraceFeature: () -> Void
    let onCancelTraceFeature: () -> Void
    let onConfirmPhotoCompressionFeature: () -> Void
    let onCancelPhotoCompressionFeature: () -> Void
    let onConfirmY2KCCDFilterFeature: () -> Void
    let onCancelY2KCCDFilterFeature: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotShapePickerPanel(
                    selectedCategory: dotControls.selectedDotShapeCategory,
                    selectedShape: dotControls.selectedDotShape,
                    dotScale: dotControls.dotScale,
                    dotCount: dotControls.dotCount,
                    selectedDotColor: dotControls.selectedDotColor,
                    dotCharacterText: dotControls.dotCharacterText,
                    onDrawDots: onDrawDots
                )
            case .style:
                StylePanelControls(
                    selectedFeature: $selectedStyleFeature,
                    isTraceVisible: dotControls.isTraceVisible,
                    isSubjectOutlineEnabled: dotControls.isSubjectOutlineEnabled,
                    dotCount: dotControls.dotCount,
                    photoCompression: dotControls.photoCompression,
                    y2kCCDFilterSettings: dotControls.y2kCCDFilterSettings,
                    canClearTrace: canClearTrace,
                    isDetectingSubjectOutline: dotControls.isDetectingSubjectOutline,
                    onToggleSubjectOutline: onToggleSubjectOutline,
                    onClearTrace: onClearTrace,
                    onConfirmTraceFeature: onConfirmTraceFeature,
                    onCancelTraceFeature: onCancelTraceFeature,
                    onConfirmPhotoCompressionFeature: onConfirmPhotoCompressionFeature,
                    onCancelPhotoCompressionFeature: onCancelPhotoCompressionFeature,
                    onConfirmY2KCCDFilterFeature: onConfirmY2KCCDFilterFeature,
                    onCancelY2KCCDFilterFeature: onCancelY2KCCDFilterFeature
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
                    isY2KCCDFilterEnabled: dotControls.y2kCCDFilterSettings.wrappedValue.enabled,
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
    var isY2KCCDFilterEnabled: Bool
    var isSourceLivePhoto: Bool
    @Binding var isSourceLiveMotionEnabled: Bool
    var canPlayLivePreview: Bool
    var livePreviewProgress: Double
    var isLivePreviewPlaying: Bool
    var onToggleLivePreviewPlayback: () -> Void

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
    }

    private var canUseSourceLiveMotion: Bool {
        isSourceLivePhoto && !isY2KCCDFilterEnabled
    }

    private var sourceLiveMotionAccessibilityHint: String {
        if isY2KCCDFilterEnabled {
            return "CCD 滤镜开启时无法使用原图实况"
        }
        if isSourceLivePhoto {
            return "播放上传 Live Photo 的原片动效"
        }
        return "当前照片不是 Live Photo，无法开启"
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
                    isEnabled: canUseSourceLiveMotion
                ) {
                    isSourceLiveMotionEnabled.toggle()
                }
                .frame(maxWidth: .infinity)
                .accessibilityHint(sourceLiveMotionAccessibilityHint)

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                backgroundStyleControl
                PanelSeparator(orientation: .vertical)
                backgroundPositionControl
            }
            .padding(.horizontal, 2)

            backgroundColorPickers
                .padding(.horizontal, 2)

            Y2KBackgroundColorPairRow(
                backgroundStyle: backgroundStyle,
                backgroundColors: $backgroundColors
            )

            if backgroundStyle.supportsPatternSpacing {
                StyledSlider(
                    title: backgroundPatternSpacingTitle,
                    value: $backgroundPatternSpacing,
                    range: PuzzleBackgroundPatternSpacing.minControlValue...PuzzleBackgroundPatternSpacing.maxControlValue,
                    step: PuzzleBackgroundPatternSpacing.step
                )
                .padding(.horizontal, 2)
            }

            StyledSlider(
                title: extensionSizeTitle,
                value: extensionRatioPercent,
                range: 0...100,
                step: 1,
                valueText: { "\(Int($0.rounded()))%" }
            )
            .padding(.horizontal, 2)
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

/// 风格 Tab 子功能入口。
enum StylePanelFeature: String, CaseIterable, Identifiable {
    case trace
    case photoCompression
    case ccd

    var id: Self { self }

    var title: String {
        switch self {
        case .trace:
            "手绘轨迹"
        case .photoCompression:
            "挤压"
        case .ccd:
            "CCD"
        }
    }

    var menuIcon: Image {
        switch self {
        case .trace:
            Image("public/LucideTriangleDashed")
        case .photoCompression:
            Image("public/CarbonZip")
        case .ccd:
            Image("public/ccd")
        }
    }

    /// Lucide 线稿在 24×24 viewBox 内更贴边，需略缩小才能与 Carbon 32×32 图标视觉对齐。
    var menuIconScale: CGFloat {
        switch self {
        case .trace:
            0.82
        default:
            1
        }
    }
}

private struct PanelStyleFeatureMenuGrid: View {
    let onSelect: (StylePanelFeature) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StylePanelFeature.allCases) { feature in
                PanelStyleFeatureMenuItem(feature: feature) {
                    onSelect(feature)
                }
            }
        }
    }
}

private struct PanelStyleFeatureMenuItem: View {
    let feature: StylePanelFeature
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                feature.menuIcon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .scaleEffect(feature.menuIconScale)

                Text(feature.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: BottomSheetPanel.menuSectionHeight())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature.title)
    }
}

private struct StylePanelControls: View {
    @Binding var selectedFeature: StylePanelFeature?
    @Binding var isTraceVisible: Bool
    @Binding var isSubjectOutlineEnabled: Bool
    @Binding var dotCount: Double
    @Binding var photoCompression: MainPhotoCompression
    @Binding var y2kCCDFilterSettings: Y2KCCDFilterSettings
    let canClearTrace: Bool
    let isDetectingSubjectOutline: Bool
    let onToggleSubjectOutline: () -> Void
    let onClearTrace: () -> Void
    let onConfirmTraceFeature: () -> Void
    let onCancelTraceFeature: () -> Void
    let onConfirmPhotoCompressionFeature: () -> Void
    let onCancelPhotoCompressionFeature: () -> Void
    let onConfirmY2KCCDFilterFeature: () -> Void
    let onCancelY2KCCDFilterFeature: () -> Void

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
    }

    var body: some View {
        Group {
            if let selectedFeature {
                styleFeatureDetail(for: selectedFeature)
            } else {
                styleFeatureMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var styleFeatureMenu: some View {
        PanelStyleFeatureMenuGrid { feature in
            withAnimation(BottomSheetPanel.panelMotion) {
                selectedFeature = feature
            }
        }
        .frame(height: BottomSheetPanel.menuSectionHeight())
    }

    @ViewBuilder
    private func styleFeatureDetail(for feature: StylePanelFeature) -> some View {
        switch feature {
        case .trace:
            traceFeatureDetail
        case .photoCompression:
            photoCompressionFeatureDetail
        case .ccd:
            ccdFeatureDetail
        }
    }

    private var traceFeatureDetail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("手绘轨迹")
                    .font(controlLabelFont)
                    .foregroundStyle(Color.foreground)

                Spacer(minLength: 0)

                PanelCompactToggleButton(
                    title: "主体识别",
                    isOn: isSubjectOutlineEnabled,
                    isEnabled: !isDetectingSubjectOutline
                ) {
                    onToggleSubjectOutline()
                }
                .frame(width: 92)

                PanelTraceVisibilityButton(isVisible: $isTraceVisible)
            }
            .frame(height: 30)

            DotCountSlider(dotCount: $dotCount)

            clearTraceButton

            PanelFeatureActionRow(
                title: StylePanelFeature.trace.title,
                onCancel: onCancelTraceFeature,
                onConfirm: onConfirmTraceFeature
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var photoCompressionFeatureDetail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(MainPhotoCompression.allCases) { option in
                    PanelCompactToggleButton(
                        title: option.title,
                        isOn: photoCompression == option
                    ) {
                        photoCompression = option
                    }
                }
            }
            .frame(height: 30)

            PanelFeatureActionRow(
                title: StylePanelFeature.photoCompression.title,
                onCancel: onCancelPhotoCompressionFeature,
                onConfirm: onConfirmPhotoCompressionFeature
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var ccdFeatureDetail: some View {
        Y2KCCDFilterControlsPanel(
            settings: $y2kCCDFilterSettings,
            onCancel: onCancelY2KCCDFilterFeature,
            onConfirm: onConfirmY2KCCDFilterFeature
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var clearTraceButton: some View {
        Button(action: onClearTrace) {
            Text("删除轨迹")
                .font(.system(size: 13, weight: .regular))
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
        .accessibilityLabel("删除轨迹")
    }

}

private struct Y2KCCDFilterControlsPanel: View {
    @Binding var settings: Y2KCCDFilterSettings
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            StyledSlider(
                title: "曝光",
                value: exposurePercent,
                range: -10...35,
                step: 1,
                valueText: signedPercentText
            )

            StyledSlider(
                title: "清晰度",
                value: clarityPercent,
                range: 65...95,
                step: 1,
                valueText: percentText
            )

            StyledSlider(
                title: "色温",
                value: temperaturePercent,
                range: -85 ... -40,
                step: 1,
                valueText: signedPercentText
            )

            StyledSlider(
                title: "锯齿",
                value: jpegArtifactsPercent,
                range: 8...42,
                step: 1,
                valueText: percentText
            )

            PanelFeatureActionRow(
                title: StylePanelFeature.ccd.title,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }

    private var exposurePercent: Binding<Double> {
        Binding(
            get: { clamped(settings.exposure, in: -0.1...0.35) * 100 },
            set: { settings.exposure = clamped($0 / 100, in: -0.1...0.35) }
        )
    }

    private var clarityPercent: Binding<Double> {
        Binding(
            get: { clamped((1 - settings.downsample) * 100, in: 65...95) },
            set: { settings.downsample = clamped(1 - ($0 / 100), in: 0.05...0.35) }
        )
    }

    private var temperaturePercent: Binding<Double> {
        Binding(
            get: { clamped(settings.temperature, in: -0.85 ... -0.4) * 100 },
            set: { settings.temperature = clamped($0 / 100, in: -0.85 ... -0.4) }
        )
    }

    private var jpegArtifactsPercent: Binding<Double> {
        Binding(
            get: { clamped(settings.jpegArtifacts, in: 0.08...0.42) * 100 },
            set: { settings.jpegArtifacts = clamped($0 / 100, in: 0.08...0.42) }
        )
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func signedPercentText(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)%"
        }
        return "\(rounded)%"
    }

    private func clamped(_ value: Double, in range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct PanelTraceVisibilityButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            (isVisible ? Image("public/LucideEye") : Image("public/LucideEyeClosed"))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.foreground)
                .frame(width: 30, height: 30)
                .background(Color.input, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("轨迹可见性")
        .accessibilityValue(isVisible ? "可视" : "不可视")
    }
}

private struct PanelFeatureActionRow: View {
    let title: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private static let rowHeight: CGFloat = 36
    private static let actionIconSize: CGFloat = 14

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: Self.actionIconSize, weight: .semibold))
                        .foregroundStyle(Color.foreground)
                        .frame(width: Self.rowHeight, height: Self.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消")

                Spacer(minLength: 0)

                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: Self.actionIconSize, weight: .semibold))
                        .foregroundStyle(Color.foreground)
                        .frame(width: Self.rowHeight, height: Self.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("应用")
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.foreground)
                .allowsHitTesting(false)
        }
        .frame(height: Self.rowHeight)
    }
}

/// 风格 / 实况等面板共用的胶囊开关：按钮即开关，选中时主色底。
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
    @Binding var dotCount: Double
    @Binding var selectedDotColor: Color
    @Binding var dotCharacterText: String
    let onDrawDots: () -> Void
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
            }

            DotCountSlider(dotCount: $dotCount)
                .padding(.vertical, 3)

            DotSizeSlider(dotScale: $dotScale)
                .padding(.vertical, 3)

            HStack(spacing: 10) {
                DotColorPicker(selectedDotColor: $selectedDotColor)
                    .frame(maxWidth: .infinity)

                PanelSeparator(orientation: .vertical)

                drawDotsButton
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 30)
            .padding(.horizontal, 2)
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

    private var drawDotsButton: some View {
        Button(action: onDrawDots) {
            HStack(spacing: 6) {
                Image("public/sparkles")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)

                Text("随机一下")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(Color.primaryForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("随机一下")
    }
}

private struct DotCountSlider: View {
    @Binding var dotCount: Double

    var body: some View {
        StyledSlider(
            title: "波点数量",
            value: $dotCount,
            range: 0...60,
            step: 1
        )
        .padding(.horizontal, 2)
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
            title: "波点大小",
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
                Text("透明")
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
            .accessibilityLabel("透明波点")
            .accessibilityHint("恢复主图与背景的互相拼贴")
            .accessibilityAddTraits(usesCollageTint ? .isSelected : [])
        }
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
                tintColor: shape.usesTemplatePreview ? previewColor : nil,
                prefersCrispScaling: shape.prefersCrispScaling
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
