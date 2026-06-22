import CoreGraphics
import Testing
import UIKit
@testable import chocho

struct Y2KCCDFilterRendererTests {
    @Test func disabledFilterReturnsNil() throws {
        let source = try #require(makeY2KGradientImage(width: 8, height: 6))
        let settings = Y2KCCDFilterSettings.default

        #expect(Y2KCCDFilterRenderer.render(image: source, settings: settings) == nil)
    }

    @Test func cacheKeyIsStableAndNormalizesValues() {
        var lhs = Y2KCCDFilterSettings.default
        lhs.enabled = true
        lhs.downsample = 0.5004
        lhs.temperature = -0.3002

        var rhs = Y2KCCDFilterSettings.default
        rhs.enabled = true
        rhs.downsample = 0.5001
        rhs.temperature = -0.3004

        #expect(lhs.cacheKey == rhs.cacheKey)
        #expect(
            lhs.renderCacheKey(sourceKey: "photo", pixelSize: CGSize(width: 20.2, height: 10.7))
            == "photo|20x11|\(lhs.cacheKey)"
        )
    }

    @Test func renderedImageKeepsInputPixelSize() throws {
        let source = try #require(makeY2KGradientImage(width: 17, height: 11))
        var settings = Y2KCCDFilterSettings.default
        settings.enabled = true

        let output = try #require(Y2KCCDFilterRenderer.render(image: source, settings: settings))
        let pixelSize = CanvasImageLoader.pixelSize(for: output)

        #expect(pixelSize == CGSize(width: 17, height: 11))
    }

    @Test func downsampleAndToneChangeOutputPixels() throws {
        let source = try #require(makeY2KGradientImage(width: 18, height: 10))
        var base = Y2KCCDFilterSettings.default
        base.enabled = true
        base.downsample = 0
        base.bloom = 0
        base.noise = 0
        base.chromaNoise = 0
        base.jpegArtifacts = 0
        base.sharpen = 0
        base.temperature = 0
        base.tint = 0
        base.contrast = 0
        base.saturation = 1
        base.highlightClip = 0
        base.rgbShift = 0

        var toned = base
        toned.temperature = -0.8
        toned.tint = -0.6
        toned.contrast = 0.35
        toned.saturation = 0.8
        var downsampled = base
        downsampled.downsample = 1
        var jpegCrushed = base
        jpegCrushed.jpegArtifacts = 1

        let baseImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: base))
        let tonedImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: toned))
        let downsampledImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: downsampled))
        let jpegImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: jpegCrushed))

        let sampleRect = CGRect(x: 2, y: 2, width: 14, height: 6)
        #expect(containsDifferentPixels(in: baseImage, and: tonedImage, rect: sampleRect))
        #expect(containsDifferentPixels(in: baseImage, and: downsampledImage, rect: sampleRect))
        #expect(containsDifferentPixels(in: baseImage, and: jpegImage, rect: sampleRect))
    }
}

private func makeY2KGradientImage(width: Int, height: Int) -> UIImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    for y in 0..<height {
        for x in 0..<width {
            let red = CGFloat((x * 31 + y * 7) % 256) / 255
            let green = CGFloat((x * 9 + y * 29) % 256) / 255
            let blue = CGFloat((x * 17 + y * 13) % 256) / 255
            context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
    }

    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
}

private func containsDifferentPixels(
    in lhs: UIImage,
    and rhs: UIImage,
    rect: CGRect
) -> Bool {
    guard let lhsImage = lhs.cgImage,
          let rhsImage = rhs.cgImage,
          let lhsData = lhsImage.dataProvider?.data,
          let rhsData = rhsImage.dataProvider?.data,
          let lhsBytes = CFDataGetBytePtr(lhsData),
          let rhsBytes = CFDataGetBytePtr(rhsData) else {
        return false
    }

    let minX = max(0, Int(rect.minX))
    let maxX = min(lhsImage.width, rhsImage.width, Int(rect.maxX))
    let minY = max(0, Int(rect.minY))
    let maxY = min(lhsImage.height, rhsImage.height, Int(rect.maxY))

    for y in minY..<maxY {
        for x in minX..<maxX {
            let lhsIndex = y * lhsImage.bytesPerRow + x * 4
            let rhsIndex = y * rhsImage.bytesPerRow + x * 4
            if lhsBytes[lhsIndex] != rhsBytes[rhsIndex]
                || lhsBytes[lhsIndex + 1] != rhsBytes[rhsIndex + 1]
                || lhsBytes[lhsIndex + 2] != rhsBytes[rhsIndex + 2] {
                return true
            }
        }
    }

    return false
}
