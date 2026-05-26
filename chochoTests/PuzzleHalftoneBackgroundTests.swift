import Testing
import UIKit
@testable import chocho

struct PuzzleHalftoneBackgroundTests {
    @Test func seededRandomIsDeterministicForSameSeed() {
        var first = HalftoneSeededRandomTestHarness(seed: 42)
        var second = HalftoneSeededRandomTestHarness(seed: 42)
        let firstValues = (0..<8).map { _ in first.next() }
        let secondValues = (0..<8).map { _ in second.next() }
        #expect(firstValues == secondValues)
    }

    @Test func renderProducesImageForSolidSource() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor(white: 0.2, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let surface = PuzzleHalftoneBackgroundRenderer.render(
            sourceImage: image,
            surfaceSize: CGSize(width: 80, height: 40),
            backgroundColor: Color(hex: "#f0eee6"),
            dotColor: Color(hex: "#0046ff"),
            blurAmount: 24
        )

        #expect(surface != nil)
        #expect(surface?.size.width == 80)
        #expect(surface?.size.height == 40)
    }
}

/// Test-only mirror of the private seeded PRNG.
private struct HalftoneSeededRandomTestHarness {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> Double {
        state = state &+ 0x6d2b_79f5
        var t = imul32(state ^ (state >> 15), 1 | state)
        t ^= t &+ imul32(t ^ (t >> 7), 61 | state)
        return Double((t ^ (t >> 14)) >> 0) / 4_294_967_296
    }

    private func imul32(_ left: UInt32, _ right: UInt32) -> UInt32 {
        UInt32(truncatingIfNeeded: Int32(bitPattern: left) &* Int32(bitPattern: right))
    }
}
