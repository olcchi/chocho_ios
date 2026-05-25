import CoreGraphics
import Testing
import UIKit
@testable import chocho

struct CanvasImageLoaderTests {
    @Test func downsamplesImagesWhoseLongestEdgeExceedsCap() throws {
        let data = try #require(makeJPEGData(width: 4000, height: 3000))
        let image = try #require(CanvasImageLoader.makeUIImage(from: data, maxPixelDimension: 2048))
        let pixelSize = CanvasImageLoader.pixelSize(for: image)

        #expect(pixelSize.width <= 2048)
        #expect(pixelSize.height <= 2048)
        #expect(max(pixelSize.width, pixelSize.height) == 2048)
    }

    @Test func keepsSmallImagesAtOriginalPixelDimensions() throws {
        let data = try #require(makeJPEGData(width: 800, height: 600))
        let image = try #require(CanvasImageLoader.makeUIImage(from: data, maxPixelDimension: 2048))
        let pixelSize = CanvasImageLoader.pixelSize(for: image)

        #expect(pixelSize.width == 800)
        #expect(pixelSize.height == 600)
    }

    @Test func returnsNilForInvalidData() {
        #expect(CanvasImageLoader.makeUIImage(from: Data([0, 1, 2])) == nil)
    }

    @Test func displayReadyUIImageFromUIImageIsDownsampled() async throws {
        let source = try #require(makeSolidImage(width: 4000, height: 3000))
        let image = try #require(
            await CanvasImageLoader.makeDisplayReadyUIImage(
                from: source,
                maxPixelDimension: 2048
            )
        )
        let pixelSize = CanvasImageLoader.pixelSize(for: image)

        #expect(pixelSize.width <= 2048)
        #expect(pixelSize.height <= 2048)
        #expect(max(pixelSize.width, pixelSize.height) == 2048)
    }
}

private func makeJPEGData(width: Int, height: Int) -> Data? {
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

    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9)
}

private func makeSolidImage(width: Int, height: Int) -> UIImage? {
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

    context.setFillColor(CGColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}
