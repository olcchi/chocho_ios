import Testing
@testable import chocho

struct CanvasLiveMotionTimingTests {
    @Test func exportDurationPrefersSourceLiveWhenEnabled() {
        #expect(
            CanvasLiveMotionTiming.exportDuration(
                liveDotAnimation: .randomBlink,
                isSourceLiveMotionEnabled: true,
                sourceLiveVideoDuration: 1.5
            ) == 1.5
        )
    }

    @Test func exportDurationUsesDotAnimationWhenSourceLiveDisabled() {
        #expect(
            CanvasLiveMotionTiming.exportDuration(
                liveDotAnimation: .randomBlink,
                isSourceLiveMotionEnabled: false,
                sourceLiveVideoDuration: 1.5
            ) == LiveDotAnimation.randomBlink.motionExportDuration
        )
    }

    @Test func exportDurationUsesSourceVideoWhenDotAnimationIsNone() {
        #expect(
            CanvasLiveMotionTiming.exportDuration(
                liveDotAnimation: .none,
                isSourceLiveMotionEnabled: true,
                sourceLiveVideoDuration: 2.2
            ) == 2.2
        )
    }

    @Test func sourceTimeMapsLinearlyWhenTimelineMatchesSourceDuration() {
        #expect(
            CanvasSourceLiveVideo.sourceTime(
                timelineTime: 1.2,
                timelineDuration: 1.5,
                sourceDuration: 1.5
            ) == 1.2
        )
    }

    @Test func sourceTimeLoopsWhenTimelineExceedsSourceDuration() {
        #expect(
            CanvasSourceLiveVideo.sourceTime(
                timelineTime: 2.5,
                timelineDuration: 3,
                sourceDuration: 1.5
            ) == 1
        )
    }

    @Test func canPlayLivePreviewWhenSourceMotionEnabled() {
        #expect(
            CanvasLiveMotionTiming.canPlayLivePreview(
                liveDotAnimation: .none,
                isSourceLiveMotionEnabled: true,
                isSourceLivePhoto: true,
                hasSourceLiveVideo: true
            )
        )
    }
}
