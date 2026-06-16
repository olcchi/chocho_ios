import CoreGraphics
import CoreVideo
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

    @Test func samplerIgnoresInteriorHolesInSubjectMask() {
        let mask = SubjectMask.ring(width: 9, height: 9, outerInset: 1, holeInset: 3)
        var generator = SeededRandomNumberGenerator(seed: 11)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 24,
            using: &generator
        )

        let center = CGPoint(x: 0.5, y: 0.5)
        let minimumDistance = positions.map { hypot($0.x - center.x, $0.y - center.y) }.min() ?? 0
        #expect(positions.count == 24)
        #expect(minimumDistance > 0.35)
    }

    @Test func generatorUsesMaskProviderAndCurrentDotShape() async throws {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 3, y: 3, width: 4, height: 4)
        let provider = FakeSubjectMaskProvider(mask: mask)
        let generator = SubjectContourDotGenerator(maskProvider: provider)
        let image = UIImage()

        let dots = try await generator.dots(
            for: image,
            count: 5,
            shapeAssetName: "雪花"
        )

        #expect(dots.count == 5)
        #expect(dots.allSatisfy { $0.shapeAssetName == "雪花" })
    }

    @Test func subjectMaskReadsOneComponent8PixelBuffer() throws {
        let pixelBuffer = try CVPixelBuffer.makeOneComponent8(
            width: 3,
            height: 2,
            values: [
                0, 1, 255,
                8, 0, 16
            ]
        )

        let mask = SubjectMask(pixelBuffer: pixelBuffer)

        #expect(mask == SubjectMask(
            width: 3,
            height: 2,
            pixels: [
                false, true, true,
                true, false, true
            ]
        ))
    }

    @Test func subjectMaskReadsOneComponent32FloatPixelBuffer() throws {
        let pixelBuffer = try CVPixelBuffer.makeOneComponent32Float(
            width: 3,
            height: 2,
            values: [
                0, 0.25, 1,
                0.75, 0, 0.5
            ]
        )

        let mask = SubjectMask(pixelBuffer: pixelBuffer)

        #expect(mask == SubjectMask(
            width: 3,
            height: 2,
            pixels: [
                false, true, true,
                true, false, true
            ]
        ))
    }

    @Test func subjectMaskRejectsUnsupportedPixelBufferFormat() throws {
        let pixelBuffer = try CVPixelBuffer.makeBGRA(width: 2, height: 2)

        #expect(SubjectMask(pixelBuffer: pixelBuffer) == nil)
    }
}

private struct FakeSubjectMaskProvider: SubjectMaskProviding {
    let mask: SubjectMask

    func subjectMask(for image: UIImage) async throws -> SubjectMask {
        mask
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

    static func ring(width: Int, height: Int, outerInset: Int, holeInset: Int) -> SubjectMask {
        var pixels = Array(repeating: false, count: width * height)
        for row in outerInset..<(height - outerInset) {
            for column in outerInset..<(width - outerInset) {
                pixels[row * width + column] = true
            }
        }
        for row in holeInset..<(height - holeInset) {
            for column in holeInset..<(width - holeInset) {
                pixels[row * width + column] = false
            }
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }
}

private enum PixelBufferTestError: Error {
    case createFailed(CVReturn)
    case missingBaseAddress
}

private extension CVPixelBuffer {
    static func makeOneComponent8(width: Int, height: Int, values: [UInt8]) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )
        guard result == kCVReturnSuccess, let pixelBuffer else {
            throw PixelBufferTestError.createFailed(result)
        }
        try pixelBuffer.writeBytes(bytesPerPixel: 1) { bytes, bytesPerRow in
            for row in 0..<height {
                for column in 0..<width {
                    bytes[row * bytesPerRow + column] = values[row * width + column]
                }
            }
        }
        return pixelBuffer
    }

    static func makeBGRA(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard result == kCVReturnSuccess, let pixelBuffer else {
            throw PixelBufferTestError.createFailed(result)
        }
        try pixelBuffer.writeBytes(bytesPerPixel: 4) { bytes, bytesPerRow in
            for row in 0..<height {
                for column in 0..<width {
                    let offset = row * bytesPerRow + column * 4
                    bytes[offset] = 255
                    bytes[offset + 1] = 128
                    bytes[offset + 2] = 64
                    bytes[offset + 3] = 255
                }
            }
        }
        return pixelBuffer
    }

    static func makeOneComponent32Float(width: Int, height: Int, values: [Float32]) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent32Float,
            nil,
            &pixelBuffer
        )
        guard result == kCVReturnSuccess, let pixelBuffer else {
            throw PixelBufferTestError.createFailed(result)
        }
        try pixelBuffer.writeBytes(bytesPerPixel: MemoryLayout<Float32>.stride) { bytes, bytesPerRow in
            for row in 0..<height {
                for column in 0..<width {
                    let offset = row * bytesPerRow + column * MemoryLayout<Float32>.stride
                    bytes.advanced(by: offset).withMemoryRebound(to: Float32.self, capacity: 1) { pointer in
                        pointer.pointee = values[row * width + column]
                    }
                }
            }
        }
        return pixelBuffer
    }

    private func writeBytes(
        bytesPerPixel: Int,
        _ write: (UnsafeMutablePointer<UInt8>, Int) -> Void
    ) throws {
        CVPixelBufferLockBaseAddress(self, [])
        defer { CVPixelBufferUnlockBaseAddress(self, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
            throw PixelBufferTestError.missingBaseAddress
        }
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        guard bytesPerRow >= CVPixelBufferGetWidth(self) * bytesPerPixel else {
            throw PixelBufferTestError.missingBaseAddress
        }
        write(bytes, bytesPerRow)
    }
}
