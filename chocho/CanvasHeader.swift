//
//  CanvasHeader.swift
//  chocho
//
//  Created by Codex on 2026/5/24.
//

import SwiftUI

struct CanvasHeader: View {
    let canDownload: Bool
    var isBusy = false
    let onBack: () -> Void
    let onDownload: () -> Void

    private static let actionButtonContentWidth: CGFloat = 46
    private static let logoHeight: CGFloat = 14

    private enum ButtonAppearance {
        case white
        case brandPrimary

        var background: Color {
            switch self {
            case .white:
                .white
            case .brandPrimary:
                Color.primary
            }
        }

        var foreground: Color {
            switch self {
            case .white:
                Color.black
            case .brandPrimary:
                Color.primaryForeground
            }
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                canvasHeaderButton(
                    title: "图库",
                    systemImage: "chevron.backward",
                    action: onBack,
                    appearance: .white,
                    accessibilityLabel: "图库"
                )

                Spacer(minLength: 0)

                canvasHeaderButton(
                    title: "保存",
                    action: onDownload,
                    appearance: .brandPrimary,
                    isEnabled: canDownload && !isBusy,
                    accessibilityLabel: "保存"
                )
            }

            Image("chocho")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(height: Self.logoHeight)
                .accessibilityLabel("chocho")
                .allowsHitTesting(false)
        }
        .padding(.horizontal, BottomSheetPanel.contentHorizontalInset)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            CanvasHeaderGlassBackground()
                .ignoresSafeArea(edges: .top)
        }
        .compositingGroup()
    }

    private func canvasHeaderButton(
        title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void,
        appearance: ButtonAppearance,
        isEnabled: Bool = true,
        accessibilityLabel: String
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    HStack(spacing: 3) {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(title)
                    }
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 13, weight: .regular))
            .frame(
                width: Self.actionButtonContentWidth,
                alignment: systemImage == nil ? .center : .leading
            )
            .foregroundStyle(appearance.foreground.opacity(isEnabled ? 1 : 0.35))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(
                appearance.background.opacity(isEnabled ? 1 : 0.45),
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct CanvasHeaderGlassBackground: View {
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
