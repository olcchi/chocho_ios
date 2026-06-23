import CoreGraphics
import ImageIO
import UIKit
import Vision

nonisolated struct SubjectMask: Equatable, Sendable {
    let width: Int
    let height: Int
    let pixels: [Bool]

    func contains(column: Int, row: Int) -> Bool {
        guard column >= 0, column < width, row >= 0, row < height else { return false }
        return pixels[row * width + column]
    }
}

nonisolated struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

enum SubjectContourDotGenerationError: Error, Equatable {
    case unsupported
    case missingImage
    case noSubject
}

protocol SubjectMaskProviding: Sendable {
    func subjectMask(for image: UIImage) async throws -> SubjectMask
}

struct SubjectContourDotGenerator: Sendable {
    let maskProvider: any SubjectMaskProviding

    init(maskProvider: any SubjectMaskProviding = VisionSubjectMaskProvider()) {
        self.maskProvider = maskProvider
    }

    func dots(
        for image: UIImage,
        count: Int,
        shapeAssetName: String
    ) async throws -> [PuzzleDot] {
        let mask = try await maskProvider.subjectMask(for: image)
        var random = SeededRandomNumberGenerator(seed: SubjectContourDotSeed.seed(for: image))
        let positions = SubjectContourSampler.positions(in: mask, count: count, using: &random)
        guard !positions.isEmpty else { throw SubjectContourDotGenerationError.noSubject }
        return positions.enumerated().map { index, position in
            PuzzleDotFactory.makeDot(position: position, index: index, shapeAssetName: shapeAssetName)
        }
    }

    func outlineTracePoints(for image: UIImage) async throws -> [PuzzleCanvasTracePoint] {
        let mask = try await maskProvider.subjectMask(for: image)
        let points = SubjectContourSampler.outlineTracePoints(in: mask)
        guard !points.isEmpty else { throw SubjectContourDotGenerationError.noSubject }
        return points
    }
}

private enum SubjectContourDotSeed {
    static func seed(for image: UIImage) -> UInt64 {
        let width = UInt64(max(Int(image.size.width.rounded()), 1))
        let height = UInt64(max(Int(image.size.height.rounded()), 1))
        return width &* 1_000_003 &+ height
    }
}

struct VisionSubjectMaskProvider: SubjectMaskProviding {
    nonisolated init() {}

    func subjectMask(for image: UIImage) async throws -> SubjectMask {
        guard #available(iOS 17.0, *) else {
            throw SubjectContourDotGenerationError.unsupported
        }
        guard let cgImage = image.cgImage else {
            throw SubjectContourDotGenerationError.missingImage
        }

        let orientation = image.cgImagePropertyOrientation
        return try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try Task.checkCancellation()
            try handler.perform([request])
            try Task.checkCancellation()
            guard let observation = request.results?.first else {
                throw SubjectContourDotGenerationError.noSubject
            }
            try Task.checkCancellation()
            let pixelBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
            try Task.checkCancellation()
            guard let mask = SubjectMask(pixelBuffer: pixelBuffer) else {
                throw SubjectContourDotGenerationError.noSubject
            }
            return mask
        }.value
    }
}

nonisolated enum SubjectContourSampler {
    static func outlineTracePoints(
        in mask: SubjectMask,
        maxPoints: Int = 360
    ) -> [PuzzleCanvasTracePoint] {
        let path = outlinePath(in: mask, maxPoints: maxPoints)
        guard !path.isEmpty else { return [] }

        var points = path.map { PuzzleCanvasTracePoint(side: .photo, point: $0) }
        if let firstPoint = points.first?.point {
            points.append(PuzzleCanvasTracePoint(side: .photo, point: firstPoint))
        }
        return points
    }

    static func outlinePath(in mask: SubjectMask, maxPoints: Int = 360) -> [CGPoint] {
        let boundary = exteriorBoundaryPoints(in: mask)
        guard !boundary.isEmpty else { return [] }

        let center = subjectCenter(in: mask) ?? CGPoint(x: 0.5, y: 0.5)
        let sorted = boundary.sorted { first, second in
            angle(from: center, to: first) < angle(from: center, to: second)
        }

        guard sorted.count > maxPoints else { return sorted }

        let stride = max(1, sorted.count / maxPoints)
        return sorted.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    static func positions<Generator: RandomNumberGenerator>(
        in mask: SubjectMask,
        count: Int,
        using generator: inout Generator
    ) -> [CGPoint] {
        let normalizedCount = max(count, 0)
        guard normalizedCount > 0 else { return [] }

        let boundary = exteriorBoundaryPoints(in: mask)
        guard !boundary.isEmpty else { return [] }

        let center = subjectCenter(in: mask) ?? CGPoint(x: 0.5, y: 0.5)
        let sorted = boundary.sorted { first, second in
            angle(from: center, to: first) < angle(from: center, to: second)
        }

        return (0..<normalizedCount).map { index in
            let bucketStart = CGFloat(index) / CGFloat(normalizedCount)
            let jitter = CGFloat.random(in: -0.35...0.35, using: &generator) / CGFloat(normalizedCount)
            let progress = min(max(bucketStart + jitter, 0), 0.999_999)
            let sourceIndex = min(sorted.count - 1, Int(progress * CGFloat(sorted.count)))
            return nudgedOutward(sorted[sourceIndex], from: center, in: mask)
        }
    }

    private static func exteriorBoundaryPoints(in mask: SubjectMask) -> [CGPoint] {
        guard mask.width > 0, mask.height > 0, mask.pixels.count == mask.width * mask.height else { return [] }
        let exteriorBackground = exteriorBackgroundPixels(in: mask)
        var points: [CGPoint] = []
        for row in 0..<mask.height {
            for column in 0..<mask.width where mask.contains(column: column, row: row) {
                if touchesExteriorBackground(column: column, row: row, exteriorBackground: exteriorBackground, mask: mask) {
                    points.append(normalizedPoint(column: column, row: row, mask: mask))
                }
            }
        }
        return points
    }

    private static func exteriorBackgroundPixels(in mask: SubjectMask) -> Set<Int> {
        var visited: Set<Int> = []
        var queue: [(column: Int, row: Int)] = []

        func enqueueIfExteriorBackground(column: Int, row: Int) {
            guard column >= 0, column < mask.width, row >= 0, row < mask.height else { return }
            guard !mask.contains(column: column, row: row) else { return }
            let index = row * mask.width + column
            guard !visited.contains(index) else { return }
            visited.insert(index)
            queue.append((column, row))
        }

        for column in 0..<mask.width {
            enqueueIfExteriorBackground(column: column, row: 0)
            enqueueIfExteriorBackground(column: column, row: mask.height - 1)
        }
        for row in 0..<mask.height {
            enqueueIfExteriorBackground(column: 0, row: row)
            enqueueIfExteriorBackground(column: mask.width - 1, row: row)
        }

        var readIndex = 0
        while readIndex < queue.count {
            let point = queue[readIndex]
            readIndex += 1
            enqueueIfExteriorBackground(column: point.column - 1, row: point.row)
            enqueueIfExteriorBackground(column: point.column + 1, row: point.row)
            enqueueIfExteriorBackground(column: point.column, row: point.row - 1)
            enqueueIfExteriorBackground(column: point.column, row: point.row + 1)
        }

        return visited
    }

    private static func touchesExteriorBackground(
        column: Int,
        row: Int,
        exteriorBackground: Set<Int>,
        mask: SubjectMask
    ) -> Bool {
        let neighbors = [
            (column: column - 1, row: row),
            (column: column + 1, row: row),
            (column: column, row: row - 1),
            (column: column, row: row + 1),
        ]

        return neighbors.contains { neighbor in
            guard neighbor.column >= 0,
                  neighbor.column < mask.width,
                  neighbor.row >= 0,
                  neighbor.row < mask.height else {
                return true
            }

            return exteriorBackground.contains(neighbor.row * mask.width + neighbor.column)
        }
    }

    private static func subjectCenter(in mask: SubjectMask) -> CGPoint? {
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        var total: CGFloat = 0
        for row in 0..<mask.height {
            for column in 0..<mask.width where mask.contains(column: column, row: row) {
                let point = normalizedPoint(column: column, row: row, mask: mask)
                totalX += point.x
                totalY += point.y
                total += 1
            }
        }
        guard total > 0 else { return nil }
        return CGPoint(x: totalX / total, y: totalY / total)
    }

    private static func normalizedPoint(column: Int, row: Int, mask: SubjectMask) -> CGPoint {
        CGPoint(
            x: (CGFloat(column) + 0.5) / CGFloat(mask.width),
            y: (CGFloat(row) + 0.5) / CGFloat(mask.height)
        )
    }

    private static func angle(from center: CGPoint, to point: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x)
    }

    private static func nudgedOutward(_ point: CGPoint, from center: CGPoint, in mask: SubjectMask) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let length = max(hypot(dx, dy), 0.000_1)
        let offset = 1.5 / CGFloat(max(mask.width, mask.height))
        return CGPoint(
            x: min(max(point.x + dx / length * offset, 0), 1),
            y: min(max(point.y + dy / length * offset, 0), 1)
        )
    }
}

extension SubjectMask {
    nonisolated init?(pixelBuffer: CVPixelBuffer) {
        guard !CVPixelBufferIsPlanar(pixelBuffer) else {
            return nil
        }
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerPixel: Int
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            bytesPerPixel = MemoryLayout<UInt8>.stride
        case kCVPixelFormatType_OneComponent32Float:
            bytesPerPixel = MemoryLayout<Float32>.stride
        default:
            return nil
        }

        guard width > 0, height > 0, bytesPerRow >= width * bytesPerPixel else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        var pixels: [Bool] = []
        pixels.reserveCapacity(width * height)
        for row in 0..<height {
            for column in 0..<width {
                let offset = row * bytesPerRow + column * bytesPerPixel
                switch pixelFormat {
                case kCVPixelFormatType_OneComponent8:
                    pixels.append(bytes[offset] > 0)
                case kCVPixelFormatType_OneComponent32Float:
                    let value = bytes.advanced(by: offset).withMemoryRebound(to: Float32.self, capacity: 1) { pointer in
                        pointer.pointee
                    }
                    pixels.append(value > 0)
                default:
                    return nil
                }
            }
        }

        self.init(width: width, height: height, pixels: pixels)
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
