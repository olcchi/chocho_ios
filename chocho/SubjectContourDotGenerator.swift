import CoreGraphics

nonisolated struct SubjectMask: Equatable {
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

nonisolated enum SubjectContourSampler {
    static func positions<Generator: RandomNumberGenerator>(
        in mask: SubjectMask,
        count: Int,
        using generator: inout Generator
    ) -> [CGPoint] {
        let normalizedCount = max(count, 0)
        guard normalizedCount > 0 else { return [] }

        let boundary = boundaryPoints(in: mask)
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

    private static func boundaryPoints(in mask: SubjectMask) -> [CGPoint] {
        guard mask.width > 0, mask.height > 0, mask.pixels.count == mask.width * mask.height else { return [] }
        var points: [CGPoint] = []
        for row in 0..<mask.height {
            for column in 0..<mask.width where mask.contains(column: column, row: row) {
                if !mask.contains(column: column - 1, row: row)
                    || !mask.contains(column: column + 1, row: row)
                    || !mask.contains(column: column, row: row - 1)
                    || !mask.contains(column: column, row: row + 1) {
                    points.append(normalizedPoint(column: column, row: row, mask: mask))
                }
            }
        }
        return points
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
