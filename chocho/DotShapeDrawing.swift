import SwiftUI
import UIKit

nonisolated enum BuiltInDotShape: String, CaseIterable, Identifiable {
    case circle = "圆形"
    case square = "正方形"
    case triangle = "等边三角形"
    case star = "五角星"
    case heart = "心"
    case sparkleStar = "星1"
    case softStar = "星2"
    case lightning = "星3"
    case flower = "花1"
    case snow = "雪"

    var id: String { rawValue }
}

extension BuiltInDotShape {
    nonisolated var usesEvenOddFillRule: Bool {
        self == .flower
    }

    nonisolated func bezierPath(in rect: CGRect) -> UIBezierPath {
        switch self {
        case .circle:
            return UIBezierPath(ovalIn: rect)
        case .square:
            return UIBezierPath(rect: rect)
        case .triangle:
            return Self.equilateralTrianglePath(in: rect)
        case .star:
            return Self.fivePointStarPath(in: rect)
        case .heart:
            return Self.pixelHeartPath(in: rect)
        case .sparkleStar:
            return Self.sparkleStarPath(in: rect)
        case .softStar:
            return Self.softStarPath(in: rect)
        case .lightning:
            return Self.lightningPath(in: rect)
        case .flower:
            let path = Self.flowerPath(in: rect)
            path.usesEvenOddFillRule = true
            return path
        case .snow:
            return Self.snowPath(in: rect)
        }
    }

    nonisolated func swiftUIPath(in rect: CGRect) -> Path {
        Path(bezierPath(in: rect).cgPath)
    }

    private nonisolated static func equilateralTrianglePath(in rect: CGRect) -> UIBezierPath {
        let side = min(rect.width, rect.height * 2 / sqrt(3))
        let height = side * sqrt(3) / 2
        let minX = rect.midX - side / 2
        let minY = rect.midY - height / 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: minY))
        path.addLine(to: CGPoint(x: minX + side, y: minY + height))
        path.addLine(to: CGPoint(x: minX, y: minY + height))
        path.close()
        return path
    }

    private nonisolated static func fivePointStarPath(in rect: CGRect) -> UIBezierPath {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()

        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()
        return path
    }

    private nonisolated static func pixelHeartPath(in rect: CGRect) -> UIBezierPath {
        let source = DotShapeSourceSpace(width: 24, height: 24, rect: rect)
        let path = UIBezierPath()
        [
            CGRect(x: 11, y: 20, width: 2, height: 2),
            CGRect(x: 9, y: 18, width: 2, height: 2),
            CGRect(x: 13, y: 18, width: 2, height: 2),
            CGRect(x: 7, y: 16, width: 2, height: 2),
            CGRect(x: 15, y: 16, width: 2, height: 2),
            CGRect(x: 5, y: 14, width: 2, height: 2),
            CGRect(x: 17, y: 14, width: 2, height: 2),
            CGRect(x: 3, y: 12, width: 2, height: 2),
            CGRect(x: 19, y: 12, width: 2, height: 2),
            CGRect(x: 1, y: 6, width: 2, height: 6),
            CGRect(x: 21, y: 6, width: 2, height: 6),
            CGRect(x: 11, y: 6, width: 2, height: 2),
            CGRect(x: 3, y: 4, width: 2, height: 2),
            CGRect(x: 9, y: 4, width: 2, height: 2),
            CGRect(x: 13, y: 4, width: 2, height: 2),
            CGRect(x: 19, y: 4, width: 2, height: 2),
            CGRect(x: 5, y: 2, width: 4, height: 2),
            CGRect(x: 15, y: 2, width: 4, height: 2)
        ].forEach { path.append(UIBezierPath(rect: source.rect($0))) }
        return path
    }

    private nonisolated static func sparkleStarPath(in rect: CGRect) -> UIBezierPath {
        polygonPath(
            sourceSize: CGSize(width: 361, height: 361),
            rect: rect,
            points: [
                CGPoint(x: 180.5, y: 0),
                CGPoint(x: 203.204, y: 95.7661),
                CGPoint(x: 270.75, y: 24.1824),
                CGPoint(x: 242.53, y: 118.47),
                CGPoint(x: 336.818, y: 90.25),
                CGPoint(x: 265.234, y: 157.796),
                CGPoint(x: 361, y: 180.5),
                CGPoint(x: 265.234, y: 203.204),
                CGPoint(x: 336.818, y: 270.75),
                CGPoint(x: 242.53, y: 242.53),
                CGPoint(x: 270.75, y: 336.818),
                CGPoint(x: 203.204, y: 265.234),
                CGPoint(x: 180.5, y: 361),
                CGPoint(x: 157.796, y: 265.234),
                CGPoint(x: 90.25, y: 336.818),
                CGPoint(x: 118.47, y: 242.53),
                CGPoint(x: 24.1824, y: 270.75),
                CGPoint(x: 95.7661, y: 203.204),
                CGPoint(x: 0, y: 180.5),
                CGPoint(x: 95.7661, y: 157.796),
                CGPoint(x: 24.1824, y: 90.25),
                CGPoint(x: 118.47, y: 118.47),
                CGPoint(x: 90.25, y: 24.1824),
                CGPoint(x: 157.796, y: 95.7661)
            ]
        )
    }

    private nonisolated static func softStarPath(in rect: CGRect) -> UIBezierPath {
        let source = DotShapeSourceSpace(width: 361, height: 361, rect: rect)
        let path = UIBezierPath()
        path.move(to: source.point(x: 180.5, y: 0))
        path.addLine(to: source.point(x: 182.425, y: 69.7092))
        path.addCurve(
            to: source.point(x: 291.291, y: 178.575),
            controlPoint1: source.point(x: 184.066, y: 129.141),
            controlPoint2: source.point(x: 231.859, y: 176.934)
        )
        path.addLine(to: source.point(x: 361, y: 180.5))
        path.addLine(to: source.point(x: 291.291, y: 182.425))
        path.addCurve(
            to: source.point(x: 182.425, y: 291.291),
            controlPoint1: source.point(x: 231.859, y: 184.066),
            controlPoint2: source.point(x: 184.066, y: 231.859)
        )
        path.addLine(to: source.point(x: 180.5, y: 361))
        path.addLine(to: source.point(x: 178.575, y: 291.291))
        path.addCurve(
            to: source.point(x: 69.7092, y: 182.425),
            controlPoint1: source.point(x: 176.934, y: 231.859),
            controlPoint2: source.point(x: 129.141, y: 184.066)
        )
        path.addLine(to: source.point(x: 0, y: 180.5))
        path.addLine(to: source.point(x: 69.7092, y: 178.575))
        path.addCurve(
            to: source.point(x: 178.575, y: 69.7092),
            controlPoint1: source.point(x: 129.141, y: 176.934),
            controlPoint2: source.point(x: 176.934, y: 129.141)
        )
        path.addLine(to: source.point(x: 180.5, y: 0))
        path.close()
        return path
    }

    private nonisolated static func lightningPath(in rect: CGRect) -> UIBezierPath {
        polygonPath(
            sourceSize: CGSize(width: 272, height: 272),
            rect: rect,
            points: [
                CGPoint(x: 127.933, y: 126.083),
                CGPoint(x: 184.419, y: 94),
                CGPoint(x: 169.43, y: 126.083),
                CGPoint(x: 236, y: 126.083),
                CGPoint(x: 158.194, y: 147.088),
                CGPoint(x: 142.344, y: 178),
                CGPoint(x: 111.794, y: 158.751),
                CGPoint(x: 36, y: 178),
                CGPoint(x: 92.1961, y: 146.795),
                CGPoint(x: 60.2061, y: 126.083)
            ]
        )
    }

    private nonisolated static func flowerPath(in rect: CGRect) -> UIBezierPath {
        let source = DotShapeSourceSpace(width: 264, height: 264, rect: rect)
        let path = UIBezierPath()
        path.move(to: source.point(x: 132.187, y: 42.3196))
        path.addCurve(
            to: source.point(x: 9.98396, y: 9.04651),
            controlPoint1: source.point(x: 79.8927, y: 3.72283),
            controlPoint2: source.point(x: 30.4073, y: -11.2209)
        )
        path.addCurve(
            to: source.point(x: 42.3197, y: 131.501),
            controlPoint1: source.point(x: -10.4394, y: 29.3139),
            controlPoint2: source.point(x: 4.12476, y: 78.9124)
        )
        path.addCurve(
            to: source.point(x: 9.04651, y: 253.704),
            controlPoint1: source.point(x: 3.72285, y: 183.795),
            controlPoint2: source.point(x: -11.2209, y: 233.28)
        )
        path.addCurve(
            to: source.point(x: 131.501, y: 221.368),
            controlPoint1: source.point(x: 29.3139, y: 274.127),
            controlPoint2: source.point(x: 78.9125, y: 259.563)
        )
        path.addCurve(
            to: source.point(x: 253.704, y: 254.641),
            controlPoint1: source.point(x: 183.795, y: 259.965),
            controlPoint2: source.point(x: 233.28, y: 274.908)
        )
        path.addCurve(
            to: source.point(x: 221.368, y: 132.187),
            controlPoint1: source.point(x: 274.127, y: 234.374),
            controlPoint2: source.point(x: 259.563, y: 184.775)
        )
        path.addCurve(
            to: source.point(x: 254.641, y: 9.9839),
            controlPoint1: source.point(x: 259.965, y: 79.8926),
            controlPoint2: source.point(x: 274.908, y: 30.4072)
        )
        path.addCurve(
            to: source.point(x: 132.187, y: 42.3196),
            controlPoint1: source.point(x: 234.374, y: -10.4394),
            controlPoint2: source.point(x: 184.775, y: 4.1247)
        )
        path.close()
        return path
    }

    private nonisolated static func snowPath(in rect: CGRect) -> UIBezierPath {
        polygonPath(
            sourceSize: CGSize(width: 200, height: 200),
            rect: rect,
            points: [
                CGPoint(x: 75.863, y: 110),
                CGPoint(x: 0, y: 110),
                CGPoint(x: 0, y: 90),
                CGPoint(x: 75.8533, y: 90),
                CGPoint(x: 35.8553, y: 50),
                CGPoint(x: 49.9971, y: 35.8576),
                CGPoint(x: 90, y: 75.8625),
                CGPoint(x: 90, y: 0),
                CGPoint(x: 110, y: 0),
                CGPoint(x: 110, y: 75.8613),
                CGPoint(x: 150.002, y: 35.8575),
                CGPoint(x: 164.144, y: 50),
                CGPoint(x: 124.146, y: 90),
                CGPoint(x: 200, y: 90),
                CGPoint(x: 200, y: 110),
                CGPoint(x: 124.136, y: 110),
                CGPoint(x: 164.144, y: 150.01),
                CGPoint(x: 150.002, y: 164.152),
                CGPoint(x: 110, y: 124.148),
                CGPoint(x: 110, y: 200),
                CGPoint(x: 90, y: 200),
                CGPoint(x: 90, y: 124.147),
                CGPoint(x: 49.9971, y: 164.152),
                CGPoint(x: 35.8553, y: 150.01)
            ]
        )
    }

    private nonisolated static func polygonPath(
        sourceSize: CGSize,
        rect: CGRect,
        points: [CGPoint]
    ) -> UIBezierPath {
        let source = DotShapeSourceSpace(width: sourceSize.width, height: sourceSize.height, rect: rect)
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: source.point(first))
        points.dropFirst().forEach { path.addLine(to: source.point($0)) }
        path.close()
        return path
    }
}

struct DotShapeDrawing: View {
    let shape: BuiltInDotShape
    let color: Color

    var body: some View {
        BuiltInDotShapeVector(shape: shape)
            .fill(color, style: FillStyle(eoFill: shape.usesEvenOddFillRule))
    }
}

struct CharacterDotGlyphView: View {
    let text: String
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: CharacterDotGlyphImageCache.shared.image(
                text: text,
                size: proxy.size,
                color: UIColor(color)
            ))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

@MainActor
private final class CharacterDotGlyphImageCache {
    static let shared = CharacterDotGlyphImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 240
    }

    func image(text: String, size: CGSize, color: UIColor) -> UIImage {
        let displayText = CharacterDotText.displayText(for: text)
        let resolvedColor = color.resolvedColor(with: UITraitCollection.current)
        let scale = max(1, UITraitCollection.current.displayScale)
        let pixelWidth = max(1, Int((size.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((size.height * scale).rounded(.up)))
        let key = "\(displayText)|\(pixelWidth)x\(pixelHeight)|\(resolvedColor.cacheKey)"

        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }

        let image = renderImage(
            text: displayText,
            size: CGSize(width: CGFloat(pixelWidth) / scale, height: CGFloat(pixelHeight) / scale),
            scale: scale,
            color: resolvedColor
        )
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    private func renderImage(
        text: String,
        size: CGSize,
        scale: CGFloat,
        color: UIColor
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let displayText = text as NSString
            let fontSize = CharacterDotGlyphRasterLayout.fittedFontSize(for: displayText, in: size)
            let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byClipping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle,
            ]
            let measuredSize = displayText.size(withAttributes: attributes)
            let drawRect = CGRect(
                x: (size.width - measuredSize.width) / 2,
                y: (size.height - measuredSize.height) / 2,
                width: measuredSize.width,
                height: measuredSize.height
            )
            displayText.draw(in: drawRect, withAttributes: attributes)
        }
    }
}

private extension UIColor {
    var cacheKey: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return [red, green, blue, alpha]
                .map { String(Int(($0 * 255).rounded())) }
                .joined(separator: ",")
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            let component = String(Int((white * 255).rounded()))
            let alphaComponent = String(Int((alpha * 255).rounded()))
            return "\(component),\(component),\(component),\(alphaComponent)"
        }

        return description
    }
}

nonisolated enum CharacterDotGlyphRasterLayout {
    static func fittedFontSize(for text: NSString, in size: CGSize) -> CGFloat {
        let maximumFontSize = max(1, min(size.width, size.height) * 0.86)
        var low: CGFloat = 1
        var high = maximumFontSize

        for _ in 0..<8 {
            let candidate = (low + high) / 2
            let measuredSize = text.size(withAttributes: [
                .font: UIFont.systemFont(ofSize: candidate, weight: .black),
            ])
            if measuredSize.width <= size.width, measuredSize.height <= size.height {
                low = candidate
            } else {
                high = candidate
            }
        }

        return low
    }
}

private struct BuiltInDotShapeVector: Shape {
    let shape: BuiltInDotShape

    func path(in rect: CGRect) -> Path {
        shape.swiftUIPath(in: rect)
    }
}

private nonisolated struct DotShapeSourceSpace {
    private let scale: CGFloat
    private let origin: CGPoint

    init(width: CGFloat, height: CGFloat, rect: CGRect) {
        scale = min(rect.width / width, rect.height / height)
        origin = CGPoint(
            x: rect.midX - width * scale / 2,
            y: rect.midY - height * scale / 2
        )
    }

    func point(_ point: CGPoint) -> CGPoint {
        self.point(x: point.x, y: point.y)
    }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + x * scale,
            y: origin.y + y * scale
        )
    }

    func rect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: origin.x + rect.minX * scale,
            y: origin.y + rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
