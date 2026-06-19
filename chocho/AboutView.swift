import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                appInfoSection
                aboutSeparator
                developerSection
                aboutSeparator
                contactSection
                aboutSeparator
                legalSection
            }
            .padding(.horizontal, RecentPhotoPickerLayout.horizontalInset)
            .padding(.bottom, 32)
        }
        .background(Color.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            aboutTopBar
        }
        .navigationBarHidden(true)
        .environment(\.colorScheme, .light)
    }

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
        .padding(.horizontal, RecentPhotoPickerLayout.horizontalInset)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background {
            RecentPhotoPickerHeaderGlassBackground()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var appInfoSection: some View {
        VStack(spacing: 6) {
            Image("SplashAppIcon")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
                .padding(.bottom, 4)

            Text(AboutContent.appName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.foreground)

            Text("用 chocho 给照片加点古早味 (o^^o)")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.mutedForeground)
                .padding(.top, 2)

            Text("在社交媒体带上 **#chocho需要更多波点**\n让更多人认识 chocho ♡")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.mutedForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("关于我")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foreground)

            Text(AboutContent.developerIntroduction)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.foreground)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("开发者")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mutedForeground)
                    Button {
                        openURL(AboutContent.developerWebsiteURL)
                    } label: {
                        Text(AboutContent.developerName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryForeground)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    Text("小红书")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mutedForeground)
                    Button {
                        openURL(AboutContent.xiaohongshuURL)
                    } label: {
                        Text(AboutContent.xiaohongshuHandle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryForeground)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("联系方式")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foreground)

            VStack(spacing: 0) {
                Button {
                    openURL(AboutContent.supportURL)
                } label: {
                    AboutLegalLinkRow(title: "支持")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("支持")

                aboutSeparator

                Button {
                    openURL(AboutContent.contactEmailURL)
                } label: {
                    HStack(spacing: 12) {
                        Text("邮箱")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.foreground)

                        Spacer(minLength: 0)

                        Text(AboutContent.contactEmail)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.mutedForeground)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.mutedForeground)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("邮箱 \(AboutContent.contactEmail)")
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("法律信息")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foreground)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(AboutLegalDocument.allCases.enumerated()), id: \.element.id) { index, document in
                    Button {
                        openURL(document.externalURL)
                    } label: {
                        AboutLegalLinkRow(title: document.title)
                    }
                    .buttonStyle(.plain)

                    if index < AboutLegalDocument.allCases.count - 1 {
                        aboutSeparator
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var aboutSeparator: some View {
        Divider()
            .overlay(Color.border)
    }
}

private struct AboutLegalLinkRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.foreground)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mutedForeground)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}
