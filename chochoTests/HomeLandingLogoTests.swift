import CoreGraphics
import Testing
@testable import chocho

struct HomeSplashTests {
    @Test func splashUsesProjectBlueBackgroundAndAppIcon() {
        #expect(HomeSplashScreen.backgroundHex == "#24BFE5")
        #expect(HomeSplashScreen.iconAssetName == "SplashAppIcon")
        #expect(HomeSplashScreen.iconSize == 112)
        #expect(HomeSplashScreen.exitScale == 1.18)
    }

    @Test func splashWaitsForStartupWorkWithinTimeLimit() {
        #expect(HomeSplashScreen.minimumDisplayDuration == 0.35)
        #expect(HomeSplashScreen.maximumWaitDuration == 1.6)
        #expect(HomeSplashScreen.exitAnimationDuration == 0.34)
        #expect(abs(HomeSplashScreen.advanceDelay(isStartupWorkReady: true, elapsedTime: 0) - 0.35) < 0.0001)
        #expect(HomeSplashScreen.advanceDelay(isStartupWorkReady: true, elapsedTime: 0.5) == 0)
        #expect(abs(HomeSplashScreen.advanceDelay(isStartupWorkReady: false, elapsedTime: 0.5) - 1.1) < 0.0001)
        #expect(HomeSplashScreen.advanceDelay(isStartupWorkReady: false, elapsedTime: 1.7) == 0)
    }
}
