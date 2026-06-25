import SwiftUI

private enum AboutViewStyle {
    static let sectionLabelFont = Font.system(size: 11, weight: .semibold)
    static let rowTitleFont = Font.system(size: 14, weight: .medium)
    static let rowDetailFont = Font.system(size: 13, weight: .regular)
    static let cardCornerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = RecentPhotoPickerLayout.horizontalInset
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                appHeroSection
                    .padding(.top, 8)

                developerCard

                aboutGroupSection(title: "联系方式") {
                    contactCard
                }

                aboutGroupSection(title: "法律信息") {
                    legalCard
                }
            }
            .padding(.horizontal, AboutViewStyle.horizontalPadding)
            .padding(.bottom, 48)
        }
        .background(Color.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            aboutTopBar
        }
        .navigationBarHidden(true)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Top Bar

    private var aboutTopBar: some View {
        ZStack {
            Text("关于")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.foreground)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.foreground)
                .accessibilityLabel("返回")

                Spacer()
            }
        }
        .padding(.horizontal, AboutViewStyle.horizontalPadding)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background {
            RecentPhotoPickerHeaderGlassBackground()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Hero Section

    private var appHeroSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.18))
                    .frame(width: 112, height: 112)
                    .blur(radius: 16)

                Image("SplashAppIcon")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 16)

            Text("chocho")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.foreground)
                .padding(.bottom, 6)

            Text("给照片加点古早味")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.mutedForeground)
                .padding(.bottom, 14)

            Text("在社交媒体带上 **#chocho需要更多波点**\n让更多人认识 chocho")
                .font(.system(size: 13))
                .foregroundStyle(Color.mutedForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: AboutViewStyle.cardCornerRadius, style: .continuous)
                .fill(Color.card)
        }
    }

    // MARK: - Developer Card

    private var developerCard: some View {
        Button {
            openURL(AboutContent.xiaohongshuURL)
        } label: {
            HStack(spacing: 14) {
                AboutIconBadge(systemName: "person")

                VStack(alignment: .leading, spacing: 2) {
                    Text("chocho 的开发者")
                        .font(AboutViewStyle.rowTitleFont)
                        .foregroundStyle(Color.foreground)

                    HStack(spacing: 4) {
                        Text("小红书")
                            .font(AboutViewStyle.rowDetailFont)
                            .foregroundStyle(Color.mutedForeground)

                        Text("·")
                            .font(AboutViewStyle.rowDetailFont)
                            .foregroundStyle(Color.mutedForeground)

                        Text(AboutContent.xiaohongshuHandle)
                            .font(AboutViewStyle.rowDetailFont)
                            .foregroundStyle(Color.mutedForeground)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mutedForeground.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: AboutViewStyle.cardCornerRadius, style: .continuous)
                .fill(Color.card)
        }
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        VStack(spacing: 0) {
            Button {
                openURL(AboutContent.supportURL)
            } label: {
                AboutCardRow(
                    icon: AboutIconBadge(systemName: "message"),
                    title: "支持",
                    detail: nil
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("支持")

            AboutCardDivider()

            Button {
                openURL(AboutContent.contactEmailURL)
            } label: {
                AboutCardRow(
                    icon: AboutIconBadge(systemName: "envelope"),
                    title: "邮箱",
                    detail: AboutContent.contactEmail
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("邮箱 \(AboutContent.contactEmail)")
        }
        .background {
            RoundedRectangle(cornerRadius: AboutViewStyle.cardCornerRadius, style: .continuous)
                .fill(Color.card)
        }
    }

    // MARK: - Legal Card

    private var legalCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(AboutLegalDocument.allCases.enumerated()), id: \.element.id) { index, document in
                Button {
                    openURL(document.externalURL)
                } label: {
                    AboutCardRow(
                        icon: AboutIconBadge(systemName: legalIconName(for: document)),
                        title: document.title,
                        detail: nil
                    )
                }
                .buttonStyle(.plain)

                if index < AboutLegalDocument.allCases.count - 1 {
                    AboutCardDivider()
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: AboutViewStyle.cardCornerRadius, style: .continuous)
                .fill(Color.card)
        }
    }

    private func legalIconName(for document: AboutLegalDocument) -> String {
        switch document {
        case .privacyPolicy: "lock"
        case .termsOfService: "doc.text"
        }
    }

    // MARK: - Section Group Helper

    private func aboutGroupSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(AboutViewStyle.sectionLabelFont)
                .foregroundStyle(Color.mutedForeground)
                .padding(.horizontal, 4)

            content()
        }
    }
}

// MARK: - Subviews

private struct AboutIconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.mutedForeground)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }
}

private struct AboutCardRow<Icon: View>: View {
    let icon: Icon
    let title: String
    let detail: String?

    var body: some View {
        HStack(spacing: 14) {
            icon

            Text(title)
                .font(AboutViewStyle.rowTitleFont)
                .foregroundStyle(Color.foreground)

            Spacer(minLength: 0)

            if let detail {
                Text(detail)
                    .font(AboutViewStyle.rowDetailFont)
                    .foregroundStyle(Color.mutedForeground)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.mutedForeground.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct AboutCardDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.border)
            .padding(.leading, 62)
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}
