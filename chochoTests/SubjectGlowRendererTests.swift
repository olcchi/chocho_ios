import Testing
import UIKit
@testable import chocho

struct SubjectGlowRendererTests {
    @Test func rendersGlowOutsideSubjectWithFadingRadius() throws {
        let image = try #require(makeSolidImage(width: 9, height: 9, color: .black))
        let mask = SubjectMask(
            width: 9,
            height: 9,
            pixels: (0..<81).map { index in
                let x = index % 9
                let y = index / 9
                return x >= 3 && x <= 5 && y >= 3 && y <= 5
            }
        )
        let settings = SubjectGlowSettings(
            enabled: true,
            color: CanvasDraftColorComponents(red: 1, green: 0, blue: 0),
            radius: 0.22
        )

        let rendered = try #require(SubjectGlowRenderer.render(
            image: image,
            mask: mask,
            settings: settings
        ))

        #expect(sampleColor(in: rendered, at: CGPoint(x: 4, y: 4)).isClose(to: .black))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 3, y: 4)).isClose(to: .red))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 2, y: 4)).isClose(to: .red))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 0, y: 4)).isClose(to: .black))
    }

    @Test func preservesOrientedImageAppearanceWhenGlowHasNoOutsidePixels() throws {
        let image = try #require(makeQuadrantImage(orientation: .down))
        let mask = SubjectMask(width: 2, height: 2, pixels: Array(repeating: true, count: 4))
        let settings = SubjectGlowSettings(
            enabled: true,
            color: CanvasDraftColorComponents(red: 1, green: 0, blue: 0),
            radius: 0.20
        )

        let rendered = try #require(SubjectGlowRenderer.render(
            image: image,
            mask: mask,
            settings: settings
        ))

        #expect(sampleColor(in: rendered, at: CGPoint(x: 0, y: 0)).isClose(to: .white))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 1, y: 0)).isClose(to: .blue))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 0, y: 1)).isClose(to: .green))
        #expect(sampleColor(in: rendered, at: CGPoint(x: 1, y: 1)).isClose(to: .red))
    }
}

private struct SampledColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let black = SampledColor(red: 0, green: 0, blue: 0)
    static let blue = SampledColor(red: 0, green: 0, blue: 255)
    static let green = SampledColor(red: 0, green: 255, blue: 0)
    static let red = SampledColor(red: 255, green: 0, blue: 0)
    static let white = SampledColor(red: 255, green: 255, blue: 255)

    func isClose(to expected: SampledColor, tolerance: UInt8 = 3) -> Bool {
        abs(Int(red) - Int(expected.red)) <= Int(tolerance)
            && abs(Int(green) - Int(expected.green)) <= Int(tolerance)
            && abs(Int(blue) - Int(expected.blue)) <= Int(tolerance)
    }
}

private func sampleColor(in image: UIImage, at point: CGPoint) -> SampledColor {
    guard let cgImage = image.cgImage else {
        return SampledColor(red: 0, green: 0, blue: 0)
    }

    let x = min(max(Int(point.x), 0), cgImage.width - 1)
    let y = min(max(Int(point.y), 0), cgImage.height - 1)
    guard let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
        return SampledColor(red: 0, green: 0, blue: 0)
    }

    var pixel = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        return SampledColor(red: 0, green: 0, blue: 0)
    }

    context.interpolationQuality = .none
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return SampledColor(
        red: pixel[0],
        green: pixel[1],
        blue: pixel[2]
    )
}

private func makeSolidImage(width: Int, height: Int, color: UIColor) -> UIImage? {
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

    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}

private func makeQuadrantImage(orientation: UIImage.Orientation) -> UIImage? {
    let bytes: [UInt8] = [
        255, 0, 0, 255,     0, 255, 0, 255,
        0, 0, 255, 255,     255, 255, 255, 255
    ]
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let cgImage = CGImage(
              width: 2,
              height: 2,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: 8,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ) else {
        return nil
    }

    return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
}
