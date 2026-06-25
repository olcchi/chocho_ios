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

    @Test func defaultSettingsRepresentTunedCCDPreset() {
        let settings = Y2KCCDFilterSettings.default

        #expect(!settings.enabled)
        #expect(settings.preset == .classic)
        #expect(settings.intensity == 1)
        #expect(settings.downsample == 0.32)
        #expect(settings.exposure == 0.14)
        #expect(settings.temperature == -0.2)
        #expect(settings.jpegArtifacts == 0.36)
    }

    @Test func presetsExposeChineseTitlesAndResolvedLooks() {
        #expect(Y2KCCDPreset.allCases.map(\.title) == ["经典", "冷色调", "暖色调"])

        var cool = Y2KCCDFilterSettings.default
        cool.preset = .cool
        cool.intensity = 1
        let coolParameters = cool.resolvedParameters

        var warm = Y2KCCDFilterSettings.default
        warm.preset = .warm
        warm.intensity = 1
        let warmParameters = warm.resolvedParameters

        #expect(coolParameters.temperature < 0)
        #expect(warmParameters.temperature > 0)
        #expect(coolParameters.jpegArtifacts > 0)
        #expect(warmParameters.jpegArtifacts > 0)
    }

    @Test func intensityBlendsPresetTowardNeutralSettings() {
        var settings = Y2KCCDFilterSettings.default
        settings.preset = .cool
        settings.intensity = 0

        let neutral = settings.resolvedParameters

        #expect(neutral.downsample == 0)
        #expect(neutral.exposure == 0)
        #expect(neutral.temperature == 0)
        #expect(neutral.tint == 0)
        #expect(neutral.jpegArtifacts == 0)
        #expect(neutral.contrast == 0)
        #expect(neutral.saturation == 1)
    }

    @Test func missingExposureDecodesToTunedCCDPresetExposure() throws {
        let json = """
        {
          "enabled": true,
          "downsample": 0.2,
          "bloom": 0.6,
          "bloomThreshold": 0.7,
          "noise": 0.2,
          "chromaNoise": 0.1,
          "jpegArtifacts": 0.2,
          "sharpen": 0.7,
          "temperature": -0.65,
          "tint": -0.2,
          "contrast": 0.15,
          "saturation": 1.0,
          "highlightClip": 0.8,
          "rgbShift": 0.15
        }
        """

        let settings = try JSONDecoder().decode(
            Y2KCCDFilterSettings.self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(settings.exposure == Y2KCCDFilterSettings.default.exposure)
    }

    @Test func panelEditingDefaultsToEnabledAndKeepsAdjustableValues() {
        var settings = Y2KCCDFilterSettings.default
        settings.enabled = false
        settings.preset = .warm
        settings.intensity = 0.68
        settings.downsample = 0.72
        settings.exposure = 0.18
        settings.temperature = 0.36
        settings.jpegArtifacts = 0.44

        let editingSettings = settings.enabledForPanelEditing

        #expect(editingSettings.enabled)
        #expect(editingSettings.preset == settings.preset)
        #expect(editingSettings.intensity == settings.intensity)
        #expect(editingSettings.downsample == settings.downsample)
        #expect(editingSettings.exposure == settings.exposure)
        #expect(editingSettings.temperature == settings.temperature)
        #expect(editingSettings.jpegArtifacts == settings.jpegArtifacts)
    }

    @Test func previewRenderPolicyDownsamplesLargeImagesForInteractiveUpdates() {
        let largeSize = CGSize(width: 2_000, height: 1_000)
        let smallSize = CGSize(width: 320, height: 240)

        #expect(Y2KCCDPreviewRenderPolicy.pixelSize(for: largeSize) == CGSize(width: 720, height: 360))
        #expect(Y2KCCDPreviewRenderPolicy.pixelSize(for: smallSize) == smallSize)
        #expect(Y2KCCDPreviewRenderPolicy.refreshDebounce == .milliseconds(90))
    }

    @Test func renderedImageKeepsInputPixelSize() throws {
        let source = try #require(makeY2KGradientImage(width: 17, height: 11))
        var settings = Y2KCCDFilterSettings.default
        settings.enabled = true

        let output = try #require(Y2KCCDFilterRenderer.render(image: source, settings: settings))
        let pixelSize = CanvasImageLoader.pixelSize(for: output)

        #expect(pixelSize == CGSize(width: 17, height: 11))
    }

    @Test func presetAndIntensityChangeOutputPixels() throws {
        let source = try #require(makeY2KGradientImage(width: 18, height: 10))
        var base = Y2KCCDFilterSettings.default
        base.enabled = true
        base.intensity = 0

        var classic = base
        classic.preset = .classic
        classic.intensity = 1
        var cool = base
        cool.preset = .cool
        cool.intensity = 1
        var warm = base
        warm.preset = .warm
        warm.intensity = 1

        let baseImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: base))
        let classicImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: classic))
        let coolImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: cool))
        let warmImage = try #require(Y2KCCDFilterRenderer.render(image: source, settings: warm))

        let sampleRect = CGRect(x: 2, y: 2, width: 14, height: 6)
        #expect(containsDifferentPixels(in: baseImage, and: classicImage, rect: sampleRect))
        #expect(containsDifferentPixels(in: coolImage, and: warmImage, rect: sampleRect))
    }

    @Test func renderedNeutralGraysDoNotGainGreenCast() throws {
        for level: UInt8 in [60, 128, 200] {
            let source = try #require(makeSolidGrayImage(level: level, width: 96, height: 96))

            for preset in Y2KCCDPreset.allCases {
                for intensity in [0.15, 0.5, 1.0] {
                    var settings = Y2KCCDFilterSettings.default
                    settings.enabled = true
                    settings.preset = preset
                    settings.intensity = intensity

                    let output = try #require(Y2KCCDFilterRenderer.render(image: source, settings: settings))
                    let mean = averageRGB(in: output)
                    let greenCast = mean.green - (mean.red + mean.blue) / 2

                    #expect(abs(greenCast) <= 1.25)
                }
            }
        }
    }
}

private func makeSolidGrayImage(level: UInt8, width: Int, height: Int) -> UIImage? {
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

    let value = CGFloat(level) / 255
    context.setFillColor(CGColor(red: value, green: value, blue: value, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
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

private func averageRGB(in image: UIImage) -> (red: Double, green: Double, blue: Double) {
    guard let cgImage = image.cgImage,
          let data = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else {
        return (0, 0, 0)
    }

    var red = 0.0
    var green = 0.0
    var blue = 0.0
    var count = 0.0

    for y in 0..<cgImage.height {
        for x in 0..<cgImage.width {
            let index = y * cgImage.bytesPerRow + x * 4
            red += Double(bytes[index])
            green += Double(bytes[index + 1])
            blue += Double(bytes[index + 2])
            count += 1
        }
    }

    guard count > 0 else { return (0, 0, 0) }
    return (red / count, green / count, blue / count)
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
