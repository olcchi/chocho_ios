//
//  BottomSheetPanel.swift
//  chocho
//
//  Created by Codex on 2026/5/23.
//

import SwiftUI
import UIKit

/// 底部面板 Tab：波点 / 风格 / 背景 / 实况（控制 `LiveDotAnimation` 与预览播放）。
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
    private static let detailHeaderHeight: CGFloat = 36
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
    let onToggleSubjectOutline: () -> Void
    var onClearTrace: () -> Void = {}
    var onBeginTraceFeature: () -> Void = {}
    var onConfirmTraceFeature: () -> Void = {}
    var onCancelTraceFeature: () -> Void = {}
    var onBeginPhotoCompressionFeature: () -> Void = {}
    var onConfirmPhotoCompressionFeature: () -> Void = {}
    var onCancelPhotoCompressionFeature: () -> Void = {}
    var onRemovePhotoCompressionFeature: () -> Void = {}
    var onBeginY2KCCDFilterFeature: () -> Void = {}
    var onConfirmY2KCCDFilterFeature: () -> Void = {}
    var onCancelY2KCCDFilterFeature: () -> Void = {}
    var onRemoveY2KCCDFilterFeature: () -> Void = {}
    var onBeginASCIIArtFeature: () -> Void = {}
    var onConfirmASCIIArtFeature: () -> Void = {}
    var onCancelASCIIArtFeature: () -> Void = {}
    var onRemoveASCIIArtFeature: () -> Void = {}
    var onBeginTextBubbleFeature: () -> Void = {}
    var onConfirmTextBubbleFeature: () -> Void = {}
    var onCancelTextBubbleFeature: () -> Void = {}
    var onRemoveTextBubbleFeature: () -> Void = {}
    @State private var selectedStyleFeature: StylePanelFeature?
    @State private var selectedDotFeature: DotPanelFeature?
    @State private var isBackgroundStyleDetailPresented = false

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
        .animation(Self.panelMotion, value: selectedDotFeature)
        .animation(Self.panelMotion, value: isBackgroundStyleDetailPresented)
        .onChange(of: selectedTab) { _, _ in
            cancelActiveFeatureSessionIfNeeded()
            selectedStyleFeature = nil
            selectedDotFeature = nil
            isBackgroundStyleDetailPresented = false
        }
        .onChange(of: isExpanded) { _, isExpanded in
            if !isExpanded {
                cancelActiveFeatureSessionIfNeeded()
                selectedStyleFeature = nil
                selectedDotFeature = nil
                isBackgroundStyleDetailPresented = false
            }
        }
        .onChange(of: selectedStyleFeature) { _, feature in
            switch feature {
            case .photoCompression:
                onBeginPhotoCompressionFeature()
            case .ccd:
                onBeginY2KCCDFilterFeature()
            case .ascii:
                onBeginASCIIArtFeature()
            case .textBubble:
                onBeginTextBubbleFeature()
            default:
                break
            }
        }
        .onChange(of: selectedDotFeature) { _, feature in
            if feature == .generate {
                onBeginTraceFeature()
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
            if !showsPanelFeatureActionRow {
                panelContent
                    .padding(.bottom, Self.detailHeaderBottomSpacing)

                PanelDetailHeader(
                    title: detailHeaderTitle,
                    onBack: closeDetailOrSubmenu
                )
            } else {
                panelContent
            }
        }
        .opacity(isPanelEnabled ? 1 : 0.42)
        .allowsHitTesting(isPanelEnabled)
        .disabled(!isPanelEnabled)
    }

    private var showsPanelFeatureActionRow: Bool {
        if selectedTab == .style, let selectedStyleFeature {
            return selectedStyleFeature == .photoCompression
                || selectedStyleFeature == .ccd
                || selectedStyleFeature == .ascii
                || selectedStyleFeature == .textBubble
        }
        return false
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
            selectedDotFeature: $selectedDotFeature,
            isBackgroundStyleDetailPresented: $isBackgroundStyleDetailPresented,
            onToggleSubjectOutline: onToggleSubjectOutline,
            onClearTrace: onClearTrace,
            onConfirmTraceFeature: confirmTraceFeature,
            onCancelTraceFeature: cancelTraceFeature,
            onConfirmPhotoCompressionFeature: confirmPhotoCompressionFeature,
            onCancelPhotoCompressionFeature: cancelPhotoCompressionFeature,
            onRemovePhotoCompressionFeature: removePhotoCompressionFeature,
            onConfirmY2KCCDFilterFeature: confirmY2KCCDFilterFeature,
            onCancelY2KCCDFilterFeature: cancelY2KCCDFilterFeature,
            onRemoveY2KCCDFilterFeature: removeY2KCCDFilterFeature,
            onConfirmASCIIArtFeature: confirmASCIIArtFeature,
            onCancelASCIIArtFeature: cancelASCIIArtFeature,
            onRemoveASCIIArtFeature: removeASCIIArtFeature,
            onConfirmTextBubbleFeature: confirmTextBubbleFeature,
            onCancelTextBubbleFeature: cancelTextBubbleFeature,
            onRemoveTextBubbleFeature: removeTextBubbleFeature
        )
        .id(selectedTab)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detailHeaderTitle: String {
        if selectedTab == .dots, let selectedDotFeature {
            return selectedDotFeature.title
        }
        if selectedTab == .style, let selectedStyleFeature {
            return selectedStyleFeature.title
        }
        if selectedTab == .background, isBackgroundStyleDetailPresented {
            return backgroundControls.backgroundStyle.wrappedValue.title
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

    private func closeDetailOrSubmenu() {
        if selectedTab == .dots {
            if selectedDotFeature == .generate {
                confirmTraceFeature()
                return
            }
            if selectedDotFeature != nil {
                withAnimation(Self.panelMotion) {
                    selectedDotFeature = nil
                }
                return
            }
            closeDetail()
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
        if selectedTab == .style, selectedStyleFeature == .ascii {
            cancelASCIIArtFeature()
            return
        }
        if selectedTab == .style, selectedStyleFeature == .textBubble {
            cancelTextBubbleFeature()
            return
        }
        if selectedTab == .style, selectedStyleFeature != nil {
            withAnimation(Self.panelMotion) {
                selectedStyleFeature = nil
            }
            return
        }
        if selectedTab == .background, isBackgroundStyleDetailPresented {
            withAnimation(Self.panelMotion) {
                isBackgroundStyleDetailPresented = false
            }
            return
        }
        closeDetail()
    }

    private func cancelActiveFeatureSessionIfNeeded() {
        if selectedDotFeature == .generate {
            onCancelTraceFeature()
        }
        switch selectedStyleFeature {
        case .photoCompression:
            onCancelPhotoCompressionFeature()
        case .ccd:
            onCancelY2KCCDFilterFeature()
        case .ascii:
            onCancelASCIIArtFeature()
        case .textBubble:
            onCancelTextBubbleFeature()
        default:
            break
        }
    }

    private func cancelTraceFeature() {
        onCancelTraceFeature()
        withAnimation(Self.panelMotion) {
            selectedDotFeature = nil
        }
    }

    private func confirmTraceFeature() {
        onConfirmTraceFeature()
        withAnimation(Self.panelMotion) {
            selectedDotFeature = nil
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

    private func removePhotoCompressionFeature() {
        onRemovePhotoCompressionFeature()
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

    private func removeY2KCCDFilterFeature() {
        onRemoveY2KCCDFilterFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func cancelASCIIArtFeature() {
        onCancelASCIIArtFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func confirmASCIIArtFeature() {
        onConfirmASCIIArtFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func removeASCIIArtFeature() {
        onRemoveASCIIArtFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func cancelTextBubbleFeature() {
        onCancelTextBubbleFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func confirmTextBubbleFeature() {
        onConfirmTextBubbleFeature()
        withAnimation(Self.panelMotion) {
            selectedStyleFeature = nil
        }
    }

    private func removeTextBubbleFeature() {
        onRemoveTextBubbleFeature()
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

    private static let rowHeight: CGFloat = 36

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.foreground)
                        .frame(width: Self.rowHeight, height: Self.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Spacer(minLength: 0)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.foreground)
                .allowsHitTesting(false)
        }
        .frame(height: Self.rowHeight)
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
    let canErase: Bool
    let isEraserEnabled: Bool
    let onClear: () -> Void
    let onToggleEraser: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            historyButton(
                assetName: "public/trash",
                isEnabled: canClear,
                accessibilityLabel: "清空画布内容",
                action: onClear
            )

            historyButton(
                assetName: "public/MajesticonsEraserLine",
                isEnabled: canErase || isEraserEnabled,
                isSelected: isEraserEnabled,
                accessibilityLabel: "橡皮擦",
                action: onToggleEraser
            )

            historyButton(
                assetName: "public/undo",
                isEnabled: canUndo,
                accessibilityLabel: "撤销",
                action: onUndo
            )

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
        isSelected: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(isSelected ? Color.primaryForeground : Color.foreground)
                .frame(width: 32, height: 28)
                .background(
                    isSelected ? Color.primary : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
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
    @Binding var selectedDotFeature: DotPanelFeature?
    @Binding var isBackgroundStyleDetailPresented: Bool
    let onToggleSubjectOutline: () -> Void
    let onClearTrace: () -> Void
    let onConfirmTraceFeature: () -> Void
    let onCancelTraceFeature: () -> Void
    let onConfirmPhotoCompressionFeature: () -> Void
    let onCancelPhotoCompressionFeature: () -> Void
    let onRemovePhotoCompressionFeature: () -> Void
    let onConfirmY2KCCDFilterFeature: () -> Void
    let onCancelY2KCCDFilterFeature: () -> Void
    let onRemoveY2KCCDFilterFeature: () -> Void
    let onConfirmASCIIArtFeature: () -> Void
    let onCancelASCIIArtFeature: () -> Void
    let onRemoveASCIIArtFeature: () -> Void
    let onConfirmTextBubbleFeature: () -> Void
    let onCancelTextBubbleFeature: () -> Void
    let onRemoveTextBubbleFeature: () -> Void

    var body: some View {
        Group {
            switch tab {
            case .dots:
                DotPanelControls(
                    selectedFeature: $selectedDotFeature,
                    selectedCategory: dotControls.selectedDotShapeCategory,
                    selectedShape: dotControls.selectedDotShape,
                    dotScale: dotControls.dotScale,
                    selectedDotColor: dotControls.selectedDotColor,
                    dotCharacterText: dotControls.dotCharacterText,
                    isTraceDrawingEnabled: dotControls.isTraceDrawingEnabled,
                    isSubjectOutlineEnabled: dotControls.isSubjectOutlineEnabled,
                    dotCount: dotControls.dotCount,
                    canClearTrace: canClearTrace,
                    isDetectingSubjectOutline: dotControls.isDetectingSubjectOutline,
                    onToggleSubjectOutline: onToggleSubjectOutline,
                    onClearTrace: onClearTrace,
                    onRandomizeDots: dotControls.onRandomizeDots
                )
            case .style:
                StylePanelControls(
                    selectedFeature: $selectedStyleFeature,
                    photoCompression: dotControls.photoCompression,
                    y2kCCDFilterSettings: dotControls.y2kCCDFilterSettings,
                    asciiArtSettings: dotControls.asciiArtSettings,
                    textBubbleSettings: dotControls.textBubbleSettings,
                    onConfirmPhotoCompressionFeature: onConfirmPhotoCompressionFeature,
                    onCancelPhotoCompressionFeature: onCancelPhotoCompressionFeature,
                    onRemovePhotoCompressionFeature: onRemovePhotoCompressionFeature,
                    onConfirmY2KCCDFilterFeature: onConfirmY2KCCDFilterFeature,
                    onCancelY2KCCDFilterFeature: onCancelY2KCCDFilterFeature,
                    onRemoveY2KCCDFilterFeature: onRemoveY2KCCDFilterFeature,
                    onConfirmASCIIArtFeature: onConfirmASCIIArtFeature,
                    onCancelASCIIArtFeature: onCancelASCIIArtFeature,
                    onRemoveASCIIArtFeature: onRemoveASCIIArtFeature,
                    onConfirmTextBubbleFeature: onConfirmTextBubbleFeature,
                    onCancelTextBubbleFeature: onCancelTextBubbleFeature,
                    onRemoveTextBubbleFeature: onRemoveTextBubbleFeature
                )
            case .background:
                BackgroundPanelControls(
                    isStyleDetailPresented: $isBackgroundStyleDetailPresented,
                    backgroundStyle: backgroundControls.backgroundStyle,
                    backgroundColors: backgroundControls.backgroundColors,
                    extensionRatio: backgroundControls.extensionRatio,
                    extensionSide: backgroundControls.extensionSide,
                    backgroundPatternSpacing: backgroundControls.backgroundPatternSpacing,
                    previewImage: backgroundControls.previewImage
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
    @Binding var isStyleDetailPresented: Bool
    @Binding var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors
    @Binding var extensionRatio: CGFloat
    @Binding var extensionSide: PuzzleCanvasExtensionSide
    @Binding var backgroundPatternSpacing: Double
    var previewImage: UIImage?

    var body: some View {
        Group {
            if isStyleDetailPresented {
                BackgroundStyleControlsPanel(
                    backgroundStyle: $backgroundStyle,
                    backgroundColors: $backgroundColors,
                    extensionRatio: $extensionRatio,
                    extensionSide: $extensionSide,
                    backgroundPatternSpacing: $backgroundPatternSpacing
                )
            } else {
                BackgroundStylePickerPanel(
                    selectedStyle: $backgroundStyle,
                    backgroundColors: backgroundColors,
                    backgroundPatternSpacing: backgroundPatternSpacing,
                    extensionRatio: extensionRatio,
                    extensionSide: extensionSide,
                    previewImage: previewImage
                ) {
                    withAnimation(BottomSheetPanel.panelMotion) {
                        isStyleDetailPresented = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(BottomSheetPanel.panelMotion, value: isStyleDetailPresented)
    }
}

private struct BackgroundStylePickerPanel: View {
    @Binding var selectedStyle: PuzzleBackgroundStyle
    var backgroundColors: PuzzleBackgroundColors
    var backgroundPatternSpacing: Double
    var extensionRatio: CGFloat
    var extensionSide: PuzzleCanvasExtensionSide
    var previewImage: UIImage?
    let onOpenStyleControls: () -> Void

    private let tileWidth: CGFloat = 96
    private let tileHeight: CGFloat = 62

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(PuzzleBackgroundStyle.allCases) { style in
                    BackgroundStyleTile(
                        style: style,
                        isSelected: style == selectedStyle,
                        colors: backgroundColors,
                        patternSpacing: backgroundPatternSpacing,
                        extensionRatio: extensionRatio,
                        extensionSide: extensionSide,
                        previewImage: previewImage
                    ) {
                        selectedStyle = style
                        onOpenStyleControls()
                    }
                    .frame(width: tileWidth)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .frame(height: tileHeight + 18)
    }
}

private struct BackgroundStyleTile: View {
    let style: PuzzleBackgroundStyle
    let isSelected: Bool
    let colors: PuzzleBackgroundColors
    let patternSpacing: Double
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    var previewImage: UIImage?
    let action: () -> Void

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                BackgroundStylePreviewSurface(
                    style: style,
                    colors: colors,
                    patternSpacing: patternSpacing,
                    extensionRatio: extensionRatio,
                    extensionSide: extensionSide,
                    previewImage: previewImage
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.primary : Color.border, lineWidth: isSelected ? 2 : 1)
                }

                Text(style.title)
                    .font(.caption2)
                    .foregroundStyle(Color.foreground)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BackgroundStylePreviewSurface: View {
    let style: PuzzleBackgroundStyle
    let colors: PuzzleBackgroundColors
    let patternSpacing: Double
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    var previewImage: UIImage?

    private let photoFrameHeight: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            preview(in: proxy.size)
        }
        .aspectRatio(1.45, contentMode: .fit)
        .background(Color.input)
    }

    @ViewBuilder
    private func preview(in size: CGSize) -> some View {
        switch style {
        case .solid:
            Color(colors.fillColor)
        case .grid:
            Canvas { context, canvasSize in
                BackgroundStylePreviewDrawing.fillBase(
                    in: &context,
                    size: canvasSize,
                    fillColor: colors.fillColor
                )
                BackgroundStylePreviewDrawing.strokeGrid(
                    in: &context,
                    size: canvasSize,
                    photoFrameHeight: photoFrameHeight,
                    patternSpacing: patternSpacing,
                    lineColor: colors.lineColor
                )
            }
        case .stripes:
            Canvas { context, canvasSize in
                BackgroundStylePreviewDrawing.fillStripes(
                    in: &context,
                    size: canvasSize,
                    photoFrameHeight: photoFrameHeight,
                    patternSpacing: patternSpacing,
                    colors: colors
                )
            }
        case .polkaDots:
            Canvas { context, canvasSize in
                BackgroundStylePreviewDrawing.fillPolkaDots(
                    in: &context,
                    size: canvasSize,
                    photoFrameHeight: photoFrameHeight,
                    dotSize: patternSpacing,
                    colors: colors
                )
            }
        case .halftone:
            if let previewImage {
                PuzzleHalftoneBackgroundView(
                    sourceImage: previewImage,
                    extensionRatio: extensionRatio,
                    extensionSide: extensionSide,
                    displaySize: size,
                    backgroundColor: colors.fillColor,
                    dotColor: colors.lineColor
                )
            } else {
                Canvas { context, canvasSize in
                    BackgroundStylePreviewDrawing.fillPolkaDots(
                        in: &context,
                        size: canvasSize,
                        photoFrameHeight: photoFrameHeight,
                        dotSize: patternSpacing,
                        colors: colors
                    )
                }
            }
        }
    }
}

private enum BackgroundStylePreviewDrawing {
    static func fillBase(
        in context: inout GraphicsContext,
        size: CGSize,
        fillColor: Color
    ) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fillColor))
    }

    static func strokeGrid(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        patternSpacing: Double,
        lineColor: Color
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        var path = Path()

        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.stroke(
            path,
            with: .color(lineColor),
            lineWidth: PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: photoFrameHeight)
        )
    }

    static func fillStripes(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        patternSpacing: Double,
        colors: PuzzleBackgroundColors
    ) {
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        var y: CGFloat = 0
        var usesPrimaryStripe = true

        while y < size.height {
            let bandHeight = min(spacing, size.height - y)
            context.fill(
                Path(CGRect(x: 0, y: y, width: size.width, height: bandHeight)),
                with: .color(usesPrimaryStripe ? colors.fillColor : colors.alternateColor)
            )
            y += spacing
            usesPrimaryStripe.toggle()
        }
    }

    static func fillPolkaDots(
        in context: inout GraphicsContext,
        size: CGSize,
        photoFrameHeight: CGFloat,
        dotSize: Double,
        colors: PuzzleBackgroundColors
    ) {
        fillBase(in: &context, size: size, fillColor: colors.fillColor)

        let dotRects = PuzzleBackgroundPolkaDotMetrics.dotRects(
            in: size,
            controlValue: dotSize,
            photoFrameHeight: photoFrameHeight
        )

        for rect in dotRects {
            context.fill(Path(ellipseIn: rect), with: .color(colors.lineColor))
        }
    }
}

private struct BackgroundStyleControlsPanel: View {
    @Binding var backgroundStyle: PuzzleBackgroundStyle
    @Binding var backgroundColors: PuzzleBackgroundColors
    @Binding var extensionRatio: CGFloat
    @Binding var extensionSide: PuzzleCanvasExtensionSide
    @Binding var backgroundPatternSpacing: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            backgroundPositionControl
            backgroundColorPickers

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
            }

            StyledSlider(
                title: extensionSizeTitle,
                value: extensionRatioPercent,
                range: 0...100,
                step: 1,
                valueText: { "\(Int($0.rounded()))%" }
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var controlLabelFont: Font {
        .system(size: 13, weight: .regular)
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
    case photoCompression
    case ccd
    case ascii
    case textBubble

    var id: Self { self }

    var title: String {
        switch self {
        case .photoCompression:
            "挤压"
        case .ccd:
            "CCD"
        case .ascii:
            "ASCII"
        case .textBubble:
            "气泡"
        }
    }

    var menuIcon: Image {
        switch self {
        case .photoCompression:
            Image("public/CarbonZip")
        case .ccd:
            Image("public/ccd")
        case .ascii:
            Image("public/LucideLabGridLines")
        case .textBubble:
            Image("public/LucideMessageSquare")
        }
    }

    var menuIconScale: CGFloat { 1 }
}

/// 波点 Tab 子功能入口。
enum DotPanelFeature: String, CaseIterable, Identifiable {
    case style
    case generate

    var id: Self { self }

    var title: String {
        switch self {
        case .style:
            "样式"
        case .generate:
            "生成"
        }
    }

    var menuIcon: Image {
        switch self {
        case .style:
            Image("public/CarbonDewPoint")
        case .generate:
            Image("public/LucideTriangleDashed")
        }
    }

    var menuIconScale: CGFloat {
        switch self {
        case .generate:
            0.82
        default:
            1
        }
    }
}

private struct PanelDotFeatureMenuGrid: View {
    let onSelect: (DotPanelFeature) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DotPanelFeature.allCases) { feature in
                PanelDotFeatureMenuItem(feature: feature) {
                    onSelect(feature)
                }
            }
        }
    }
}

private struct PanelDotFeatureMenuItem: View {
    let feature: DotPanelFeature
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

private struct DotPanelControls: View {
    @Binding var selectedFeature: DotPanelFeature?
    @Binding var selectedCategory: DotShapeCategory
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var dotCharacterText: String
    @Binding var isTraceDrawingEnabled: Bool
    @Binding var isSubjectOutlineEnabled: Bool
    @Binding var dotCount: Double
    let canClearTrace: Bool
    let isDetectingSubjectOutline: Bool
    let onToggleSubjectOutline: () -> Void
    let onClearTrace: () -> Void
    let onRandomizeDots: () -> Void

    var body: some View {
        Group {
            if let selectedFeature {
                dotFeatureDetail(for: selectedFeature)
            } else {
                dotFeatureMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(BottomSheetPanel.panelMotion, value: selectedFeature)
    }

    private var dotFeatureMenu: some View {
        PanelDotFeatureMenuGrid { feature in
            withAnimation(BottomSheetPanel.panelMotion) {
                selectedFeature = feature
            }
        }
        .frame(height: BottomSheetPanel.menuSectionHeight())
    }

    @ViewBuilder
    private func dotFeatureDetail(for feature: DotPanelFeature) -> some View {
        switch feature {
        case .style:
            DotStylePanel(
                selectedCategory: $selectedCategory,
                selectedShape: $selectedShape,
                dotScale: $dotScale,
                selectedDotColor: $selectedDotColor,
                dotCharacterText: $dotCharacterText
            )
        case .generate:
            DotGeneratePanel(
                isTraceDrawingEnabled: $isTraceDrawingEnabled,
                isSubjectOutlineEnabled: $isSubjectOutlineEnabled,
                dotCount: $dotCount,
                canClearTrace: canClearTrace,
                isDetectingSubjectOutline: isDetectingSubjectOutline,
                onToggleSubjectOutline: onToggleSubjectOutline,
                onClearTrace: onClearTrace,
                onRandomizeDots: onRandomizeDots
            )
        }
    }
}

private struct StylePanelControls: View {
    @Binding var selectedFeature: StylePanelFeature?
    @Binding var photoCompression: MainPhotoCompression
    @Binding var y2kCCDFilterSettings: Y2KCCDFilterSettings
    @Binding var asciiArtSettings: ASCIIArtSettings
    @Binding var textBubbleSettings: TextBubbleSettings
    let onConfirmPhotoCompressionFeature: () -> Void
    let onCancelPhotoCompressionFeature: () -> Void
    let onRemovePhotoCompressionFeature: () -> Void
    let onConfirmY2KCCDFilterFeature: () -> Void
    let onCancelY2KCCDFilterFeature: () -> Void
    let onRemoveY2KCCDFilterFeature: () -> Void
    let onConfirmASCIIArtFeature: () -> Void
    let onCancelASCIIArtFeature: () -> Void
    let onRemoveASCIIArtFeature: () -> Void
    let onConfirmTextBubbleFeature: () -> Void
    let onCancelTextBubbleFeature: () -> Void
    let onRemoveTextBubbleFeature: () -> Void

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
        case .photoCompression:
            photoCompressionFeatureDetail
        case .ccd:
            ccdFeatureDetail
        case .ascii:
            ASCIIArtControlsPanel(
                settings: $asciiArtSettings,
                onCancel: onCancelASCIIArtFeature,
                onRemove: onRemoveASCIIArtFeature,
                onConfirm: onConfirmASCIIArtFeature
            )
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        case .textBubble:
            TextBubbleControlsPanel(
                settings: $textBubbleSettings,
                onRemove: onRemoveTextBubbleFeature,
                onConfirm: onConfirmTextBubbleFeature
            )
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
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
                onRemove: onRemovePhotoCompressionFeature,
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
            onRemove: onRemoveY2KCCDFilterFeature,
            onConfirm: onConfirmY2KCCDFilterFeature
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

}

private struct DotStylePanel: View {
    @Binding var selectedCategory: DotShapeCategory
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color
    @Binding var dotCharacterText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DotShapeStylePanel(
                selectedCategory: $selectedCategory,
                selectedShape: $selectedShape,
                dotCharacterText: $dotCharacterText,
                selectedDotColor: selectedDotColor
            )

            DotAdjustPanel(
                dotScale: $dotScale,
                selectedDotColor: $selectedDotColor
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct DotGeneratePanel: View {
    @Binding var isTraceDrawingEnabled: Bool
    @Binding var isSubjectOutlineEnabled: Bool
    @Binding var dotCount: Double
    let canClearTrace: Bool
    let isDetectingSubjectOutline: Bool
    let onToggleSubjectOutline: () -> Void
    let onClearTrace: () -> Void
    let onRandomizeDots: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("生成方式")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.foreground)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    PanelCompactToggleButton(
                        title: "手绘",
                        iconName: "public/LucideTriangleDashed",
                        isOn: isTraceDrawingEnabled,
                        accessibilityLabel: "手绘轨迹"
                    ) {
                        isTraceDrawingEnabled.toggle()
                    }
                    .frame(width: 58)

                    PanelCompactToggleButton(
                        title: "主体",
                        iconName: "public/LucideLabCrosshairSquare",
                        isOn: isSubjectOutlineEnabled,
                        isEnabled: !isDetectingSubjectOutline,
                        accessibilityLabel: "主体识别"
                    ) {
                        onToggleSubjectOutline()
                    }
                    .frame(width: 58)

                    PanelCompactToggleButton(
                        title: "随机",
                        iconName: "public/random",
                        isOn: false,
                        accessibilityLabel: "随机生成波点",
                        accessibilityValue: "点击生成"
                    ) {
                        onRandomizeDots()
                    }
                    .frame(width: 58)

                    clearTraceButton
                }
            }
            .frame(height: 30)

            DotCountSlider(dotCount: $dotCount)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var clearTraceButton: some View {
        Button(action: onClearTrace) {
            Image("public/LucideBrushCleaning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.foreground)
                .frame(width: 18, height: 18)
                .frame(width: 30, height: 30)
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

private struct DotAdjustPanel: View {
    @Binding var dotScale: Double
    @Binding var selectedDotColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DotSizeSlider(dotScale: $dotScale)
                .padding(.vertical, 3)

            DotColorPicker(selectedDotColor: $selectedDotColor)
                .padding(.horizontal, 2)
                .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct Y2KCCDFilterControlsPanel: View {
    @Binding var settings: Y2KCCDFilterSettings
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            presetRow

            StyledSlider(
                title: "强度",
                value: intensityPercent,
                range: 0...100,
                step: 1,
                valueText: percentText
            )

            PanelFeatureActionRow(
                title: StylePanelFeature.ccd.title,
                onRemove: onRemove,
                onConfirm: onConfirm
            )
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(Y2KCCDPreset.allCases) { preset in
                let isSelected = settings.preset == preset
                Button {
                    settings.preset = preset
                } label: {
                    Text(preset.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isSelected ? Color.primaryForeground : Color.foreground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            isSelected ? Color.primary : Color.input,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var intensityPercent: Binding<Double> {
        Binding(
            get: { clamped(settings.intensity, in: 0...1) * 100 },
            set: { settings.intensity = clamped($0 / 100, in: 0...1) }
        )
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func clamped(_ value: Double, in range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct PanelFeatureActionRow: View {
    let title: String
    let onRemove: () -> Void
    let onConfirm: () -> Void

    private static let rowHeight: CGFloat = 36
    private static let removeIconSize: CGFloat = 16
    private static let confirmIconSize: CGFloat = 14

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Button(action: onRemove) {
                    Image("public/trash")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.foreground)
                        .frame(width: Self.removeIconSize, height: Self.removeIconSize)
                        .frame(width: Self.rowHeight, height: Self.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除\(title)")

                Spacer(minLength: 0)

                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: Self.confirmIconSize, weight: .semibold))
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
    var iconName: String? = nil
    let isOn: Bool
    var isEnabled: Bool = true
    var accessibilityLabel: String? = nil
    var accessibilityValue: String? = nil
    let action: () -> Void

    private var activeColor: Color { Color.primary }
    private var inactiveColor: Color { Color.input }

    var body: some View {
        Button(action: action) {
            label
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
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityValue(accessibilityValue ?? (isOn ? "已开启" : "已关闭"))
    }

    @ViewBuilder
    private var label: some View {
        if let iconName {
            HStack(spacing: 4) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text(title)
            }
        } else {
            Text(title)
        }
    }
}

private struct DotShapeStylePanel: View {
    @Binding var selectedCategory: DotShapeCategory
    @Binding var selectedShape: DotShapeAsset
    @Binding var dotCharacterText: String
    let selectedDotColor: Color
    @AppStorage("chocho.dotShape.recentNames") private var recentShapeNamesStore = DotShapeAsset.defaultSelection.name

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DotShapeCategoryTabs(selectedCategory: $selectedCategory)
                .padding(.bottom, 3)

            DotShapeGrid(
                shapes: shapes,
                selectedShape: $selectedShape,
                selectedDotColor: selectedDotColor
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
                Text("拼贴")
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
            .accessibilityLabel("拼贴波点")
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
    let selectedDotColor: Color
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
                        isSelected: shape == selectedShape,
                        selectedDotColor: selectedDotColor
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
    /// The currently selected dot color; used to tint template-rendered shapes.
    let selectedDotColor: Color
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
                color: isSelected ? Color.primaryForeground : dotPreviewColor
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

    /// Resolved color for template/drawing shapes in normal (unselected) state.
    /// When the dot color is the collage-transparent sentinel, fall back to black.
    private var dotPreviewColor: Color {
        let isCollage = PuzzleDotCollageColor.usesCollageTint(selectedDotColor: selectedDotColor)
        return isCollage ? Color.black : selectedDotColor
    }

    private var previewColor: Color {
        isSelected ? Color.primaryForeground : dotPreviewColor
    }

    private var tileBackground: Color {
        isSelected
            ? Color.primary
            : Color.card
    }
}

private struct TextBubbleControlsPanel: View {
    @Binding var settings: TextBubbleSettings
    let onRemove: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ColorPicker("颜色", selection: bubbleColorSelection, supportsOpacity: false)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)

            Button {
                var nextSettings = settings
                nextSettings.addBubble()
                settings = nextSettings
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("添加气泡")
                        .font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.input, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加气泡")

            PanelFeatureActionRow(
                title: StylePanelFeature.textBubble.title,
                onRemove: onRemove,
                onConfirm: onConfirm
            )
        }
    }

    private var bubbleColorSelection: Binding<Color> {
        Binding(
            get: {
                settings.bubbleColor.color
            },
            set: { newValue in
                var nextSettings = settings
                nextSettings.bubbleColor = TextBubbleColorComponents(newValue)
                settings = nextSettings
            }
        )
    }
}

private struct ASCIIArtControlsPanel: View {
    @Binding var settings: ASCIIArtSettings
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onConfirm: () -> Void

    private var controlFont: Font { .system(size: 13, weight: .regular) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("样式").font(controlFont).foregroundStyle(Color.foreground)
                Spacer(minLength: 0)
                PanelValueMenu(
                    accessibilityTitle: "ASCII 样式",
                    selection: $settings.preset,
                    options: ASCIIArtPreset.allCases,
                    title: { $0.title },
                    font: controlFont
                )
            }
            .frame(height: 30)

            HStack(spacing: 6) {
                Text("细节").font(controlFont).foregroundStyle(Color.foreground)
                Spacer(minLength: 0)
                PanelValueMenu(
                    accessibilityTitle: "ASCII 细节",
                    selection: $settings.detail,
                    options: ASCIIArtDetail.allCases,
                    title: { $0.title },
                    font: controlFont
                )
            }
            .frame(height: 30)

            HStack(spacing: 8) {
                PanelCompactToggleButton(title: "主体", isOn: settings.showSubject) {
                    settings.showSubject.toggle()
                }
                PanelCompactToggleButton(title: "轮廓", isOn: settings.showOutline) {
                    settings.showOutline.toggle()
                }
                Spacer(minLength: 0)
            }
            .frame(height: 30)

            ColorPicker("颜色", selection: characterColorBinding, supportsOpacity: false)
                .font(controlFont)
                .foregroundStyle(Color.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)

            PanelFeatureActionRow(
                title: StylePanelFeature.ascii.title,
                onRemove: onRemove,
                onConfirm: onConfirm
            )
        }
    }

    private var characterColorBinding: Binding<Color> {
        Binding(
            get: { settings.characterColor.color },
            set: { newValue in
                settings.characterColor = CanvasDraftColorComponents(
                    DotColorPickerSelection.selectedColor(fromPickerColor: newValue)
                )
            }
        )
    }
}
