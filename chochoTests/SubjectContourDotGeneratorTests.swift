import CoreGraphics
import Testing
import UIKit
@testable import chocho

struct SubjectContourDotGeneratorTests {
    @Test func samplerReturnsNoDotsForEmptyMask() {
        let mask = SubjectMask(width: 4, height: 4, pixels: Array(repeating: false, count: 16))
        var generator = SeededRandomNumberGenerator(seed: 1)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 8,
            using: &generator
        )

        #expect(positions.isEmpty)
    }

    @Test func samplerReturnsNoDotsForZeroOrNegativeCount() {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 3, y: 3, width: 4, height: 4)
        var zeroCountGenerator = SeededRandomNumberGenerator(seed: 2)
        var negativeCountGenerator = SeededRandomNumberGenerator(seed: 2)

        let zeroCountPositions = SubjectContourSampler.positions(
            in: mask,
            count: 0,
            using: &zeroCountGenerator
        )
        let negativeCountPositions = SubjectContourSampler.positions(
            in: mask,
            count: -4,
            using: &negativeCountGenerator
        )

        #expect(zeroCountPositions.isEmpty)
        #expect(negativeCountPositions.isEmpty)
    }

    @Test func samplerReturnsNoDotsForInvalidMasks() {
        let mismatchedPixels = SubjectMask(width: 4, height: 4, pixels: Array(repeating: true, count: 15))
        let zeroWidth = SubjectMask(width: 0, height: 4, pixels: [])
        var mismatchedGenerator = SeededRandomNumberGenerator(seed: 4)
        var zeroWidthGenerator = SeededRandomNumberGenerator(seed: 4)

        let mismatchedPositions = SubjectContourSampler.positions(
            in: mismatchedPixels,
            count: 8,
            using: &mismatchedGenerator
        )
        let zeroWidthPositions = SubjectContourSampler.positions(
            in: zeroWidth,
            count: 8,
            using: &zeroWidthGenerator
        )

        #expect(mismatchedPositions.isEmpty)
        #expect(zeroWidthPositions.isEmpty)
    }

    @Test func samplerGeneratesRequestedCountAroundRectangle() {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 3, y: 3, width: 4, height: 4)
        var generator = SeededRandomNumberGenerator(seed: 7)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 12,
            using: &generator
        )

        #expect(positions.count == 12)
        #expect(positions.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
    }

    @Test func samplerClampsOutwardNudgeAtImageEdges() {
        let mask = SubjectMask.rectangle(width: 4, height: 4, x: 0, y: 0, width: 2, height: 2)
        var generator = SeededRandomNumberGenerator(seed: 9)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 16,
            using: &generator
        )

        #expect(positions.count == 16)
        #expect(positions.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
        #expect(positions.contains { $0.x == 0 || $0.y == 0 })
    }

    @Test func samplerNudgesDotsOutsideSubjectCenter() {
        let mask = SubjectMask.rectangle(width: 20, height: 20, x: 7, y: 7, width: 6, height: 6)
        var generator = SeededRandomNumberGenerator(seed: 3)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 16,
            using: &generator
        )

        let center = CGPoint(x: 0.5, y: 0.5)
        let minimumDistance = positions.map { hypot($0.x - center.x, $0.y - center.y) }.min() ?? 0
        #expect(minimumDistance > 0.15)
    }

    @Test func samplerOutputIsStableWithSeededGenerator() {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 2, y: 2, width: 6, height: 6)
        var first = SeededRandomNumberGenerator(seed: 42)
        var second = SeededRandomNumberGenerator(seed: 42)

        let firstPositions = SubjectContourSampler.positions(in: mask, count: 6, using: &first)
        let secondPositions = SubjectContourSampler.positions(in: mask, count: 6, using: &second)

        #expect(firstPositions == secondPositions)
    }
}

private extension SubjectMask {
    static func rectangle(width: Int, height: Int, x: Int, y: Int, width rectWidth: Int, height rectHeight: Int) -> SubjectMask {
        var pixels = Array(repeating: false, count: width * height)
        for row in y..<(y + rectHeight) {
            for column in x..<(x + rectWidth) {
                pixels[row * width + column] = true
            }
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }
}
