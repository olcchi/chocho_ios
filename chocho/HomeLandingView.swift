import SwiftUI

nonisolated enum HomeSplashScreen {
    static let backgroundHex = "#24BFE5"
    static let iconAssetName = "SplashAppIcon"
    static let iconSize: CGFloat = 112
    static let minimumDisplayDuration: TimeInterval = 0.35
    static let maximumWaitDuration: TimeInterval = 1.6
    static let exitAnimationDuration: TimeInterval = 0.34
    static let exitScale: CGFloat = 1.18

    static func advanceDelay(
        isStartupWorkReady: Bool,
        elapsedTime: TimeInterval
    ) -> TimeInterval {
        guard elapsedTime < maximumWaitDuration else { return 0 }

        if isStartupWorkReady {
            return max(0, minimumDisplayDuration - elapsedTime)
        }
        return max(0, maximumWaitDuration - elapsedTime)
    }
}

struct HomeLandingView: View {
    let isStartupWorkReady: Bool
    let onEnter: () -> Void
    @State private var startTime = Date()
    @State private var hasAdvanced = false
    @State private var isExiting = false

    var body: some View {
        ZStack {
            Color(hex: HomeSplashScreen.backgroundHex)
                .ignoresSafeArea()

            Image(HomeSplashScreen.iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: HomeSplashScreen.iconSize, height: HomeSplashScreen.iconSize)
                .accessibilityLabel("chocho")
        }
        .compositingGroup()
        .scaleEffect(isExiting ? HomeSplashScreen.exitScale : 1)
        .opacity(isExiting ? 0 : 1)
        .task(id: isStartupWorkReady) {
            let elapsedTime = Date().timeIntervalSince(startTime)
            let delay = HomeSplashScreen.advanceDelay(
                isStartupWorkReady: isStartupWorkReady,
                elapsedTime: elapsedTime
            )
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await advanceOnce()
        }
    }

    @MainActor
    private func advanceOnce() async {
        guard !hasAdvanced else { return }
        hasAdvanced = true

        withAnimation(.easeInOut(duration: HomeSplashScreen.exitAnimationDuration)) {
            isExiting = true
        }

        try? await Task.sleep(for: .seconds(HomeSplashScreen.exitAnimationDuration))
        guard !Task.isCancelled else { return }
        onEnter()
    }
}

#Preview("Home Splash") {
    HomeLandingView(isStartupWorkReady: true) {}
}
