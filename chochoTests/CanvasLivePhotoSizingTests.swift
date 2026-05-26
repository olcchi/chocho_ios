import CoreGraphics
import Testing
@testable import chocho

struct CanvasLivePhotoSizingTests {
    @Test func videoEncodeSizeIsSmallerThanKeyPhotoForLargeCanvas() {
        let keyPhotoSize = CGSize(width: 2400, height: 1800)
        let videoSize = CanvasLivePhotoSizing.videoEncodeSize(for: keyPhotoSize)

        #expect(videoSize.width <= 1080)
        #expect(videoSize.height <= 1080)
        #expect(videoSize.width < keyPhotoSize.width)
        #expect(videoSize.height < keyPhotoSize.height)
    }

    @Test func videoEncodeDimensionsAreEvenForH264() {
        let videoSize = CanvasLivePhotoSizing.videoEncodeSize(
            for: CGSize(width: 1501, height: 999)
        )

        #expect(Int(videoSize.width) % 2 == 0)
        #expect(Int(videoSize.height) % 2 == 0)
    }
}
