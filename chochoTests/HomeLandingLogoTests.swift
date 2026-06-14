import Testing
@testable import chocho

struct HomeLandingLogoTests {
    @Test func logoLettersSpellChochoWithImageAssets() {
        let letters = HomeLandingLogoLetter.chocho

        #expect(letters.map(\.assetName) == ["home-c", "home-h", "home-o", "home-c", "home-h", "home-o"])
        #expect(letters.map(\.accessibilityLabel).joined() == "chocho")
    }

    @Test func logoLettersUseStaggeredWavePhases() {
        let letters = HomeLandingLogoLetter.chocho

        #expect(letters.map(\.wavePhaseOffset) == [0, 0.18, 0.36, 0.54, 0.72, 0.90])
    }

    @Test func sineMotionFloatsUpAndReturns() {
        let motion = HomeLandingLogoMotion(amplitude: 10, period: 1)

        #expect(abs(motion.verticalOffset(at: 0, phaseOffset: 0)) < 0.0001)
        #expect(abs(motion.verticalOffset(at: 0.25, phaseOffset: 0) + 10) < 0.0001)
        #expect(abs(motion.verticalOffset(at: 0.5, phaseOffset: 0)) < 0.0001)
    }

    @Test func snowflakesUseSmallCreamRealtimeRendering() {
        let snowflakes = HomeLandingSnowflake.scattered

        #expect(snowflakes.count == 18)
        #expect(snowflakes.allSatisfy { (12...28).contains($0.size) })
        #expect(HomeLandingSnowflake.tintHex == "#F4FFE6")
        #expect(HomeLandingSnowflake.fadePeriod == 6)
    }

    @Test func snowflakeOpacityAppearsAndDisappearsOverTime() {
        let snowflake = HomeLandingSnowflake(
            id: 0,
            xFraction: 0.5,
            yFraction: 0.5,
            size: 14,
            phaseOffset: 0
        )

        #expect(snowflake.opacity(at: 0, period: 1) == 0)
        #expect(snowflake.opacity(at: 0.25, period: 1) > 0.9)
        #expect(snowflake.opacity(at: 0.75, period: 1) == 0)
    }

}
