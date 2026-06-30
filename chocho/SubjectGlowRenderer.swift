import CoreGraphics
import SwiftUI
import UIKit

nonisolated struct SubjectGlowSettings: Codable, Equatable, Hashable, Sendable {
    var enabled: Bool
    var color: CanvasDraftColorComponents
    /// Width of the glow as a fraction of the shorter image edge.
    var radius: Double

    nonisolated static let defaultColor = CanvasDraftColorComponents(
        red: 1,
        green: 238.0 / 255.0,
        blue: 103.0 / 255.0
    )

    nonisolated static let `default` = SubjectGlowSettings(
        enabled: false,
        color: defaultColor,
        radius: 0.12
    )

    nonisolated var enabledForPanelEditing: SubjectGlowSettings {
        var settings = self
        settings.enabled = true
        return settings
    }

    nonisolated var cacheKey: String {
        [
            enabled ? "1" : "0",
            color.red.fixed3,
            color.green.fixed3,
            color.blue.fixed3,
            clampedRadius.fixed3
        ].joined(separator: ":")
    }

    nonisolated var clampedRadius: Double {
        guard radius.isFinite else { return Self.default.radius }
        return min(max(radius, 0.01), 0.30)
    }
}

nonisolated enum SubjectGlowRenderer {
    static func render(
        image: UIImage,
        mask: SubjectMask?,
        settings: SubjectGlowSettings
    ) -> UIImage? {
        guard settings.enabled, let mask else { return image }

        let pixelSize = CanvasImageLoader.pixelSize(for: image)
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        guard width > 0, height > 0, mask.width > 0, mask.height > 0 else { return image }

        let renderSize = CGSize(width: width, height: height)
        guard let subjectPixels = mask.boolBitmap(targetSize: renderSize),
              subjectPixels.count >= width * height else {
            return image
        }
        let edgePixels = SubjectMaskRaster.makeEdgeBitmap(
            from: subjectPixels,
            width: width,
            height: height
        )
        let distances = distanceField(from: subjectPixels, width: width, height: height)
        let radiusPixels = max(1, Float(min(width, height)) * Float(settings.clampedRadius))
        let glowColor = settings.color.uiColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        glowColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let glowRed = Double(red * 255)
        let glowGreen = Double(green * 255)
        let glowBlue = Double(blue * 255)
        var overlayBytes = [UInt8](repeating: 0, count: width * height * 4)

        for index in subjectPixels.indices {
            let isSubjectEdge = index < edgePixels.count && edgePixels[index]
            guard !subjectPixels[index] || isSubjectEdge else { continue }

            let distance = isSubjectEdge ? 0 : distances[index]
            guard distance.isFinite, distance >= 0, distance <= radiusPixels + 1 else { continue }

            let opacity = Double(max(0, min(1, 1 - max(0, distance - 1) / radiusPixels))) * Double(alpha)
            guard opacity > 0 else { continue }

            let offset = index * 4
            let alphaByte = UInt8(min(max((opacity * 255).rounded(), 0), 255))
            overlayBytes[offset] = UInt8(min(max((glowRed * opacity).rounded(), 0), 255))
            overlayBytes[offset + 1] = UInt8(min(max((glowGreen * opacity).rounded(), 0), 255))
            overlayBytes[offset + 2] = UInt8(min(max((glowBlue * opacity).rounded(), 0), 255))
            overlayBytes[offset + 3] = alphaByte
        }

        guard let overlay = makeImage(bytes: &overlayBytes, width: width, height: height, scale: 1) else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: renderSize)
            image.draw(in: rect)
            overlay.draw(in: rect)
        }
    }

    private static func distanceField(from subjectPixels: [Bool], width: Int, height: Int) -> [Float] {
        let diagonal = Float(2).squareRoot()
        var distances = subjectPixels.map { $0 ? Float(0) : Float.infinity }

        for y in 0..<height {
            for x in 0..<width where !subjectPixels[y * width + x] {
                let index = y * width + x
                if x > 0 {
                    distances[index] = min(distances[index], distances[index - 1] + 1)
                }
                if y > 0 {
                    distances[index] = min(distances[index], distances[index - width] + 1)
                    if x > 0 {
                        distances[index] = min(distances[index], distances[index - width - 1] + diagonal)
                    }
                    if x + 1 < width {
                        distances[index] = min(distances[index], distances[index - width + 1] + diagonal)
                    }
                }
            }
        }

        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) where !subjectPixels[y * width + x] {
                let index = y * width + x
                if x + 1 < width {
                    distances[index] = min(distances[index], distances[index + 1] + 1)
                }
                if y + 1 < height {
                    distances[index] = min(distances[index], distances[index + width] + 1)
                    if x + 1 < width {
                        distances[index] = min(distances[index], distances[index + width + 1] + diagonal)
                    }
                    if x > 0 {
                        distances[index] = min(distances[index], distances[index + width - 1] + diagonal)
                    }
                }
            }
        }

        return distances
    }

    private static func makeImage(bytes: inout [UInt8], width: Int, height: Int, scale: CGFloat) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        return bytes.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: colorSpace,
                      bitmapInfo: bitmapInfo
                  ),
                  let cgImage = context.makeImage() else {
                return nil
            }

            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }
    }
}

private extension Double {
    nonisolated var fixed3: String {
        String(format: "%.3f", self)
    }
}
