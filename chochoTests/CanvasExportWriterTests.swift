import Testing
import UIKit
@testable import chocho

struct CanvasExportWriterTests {
    @Test func liveAnimationSelectsLivePhotoExportFormat() {
        #expect(
            CanvasExportWriter.format(liveDotAnimation: .randomBlink) == .livePhoto
        )
        #expect(
            CanvasExportWriter.format(liveDotAnimation: .breathe) == .livePhoto
        )
        #expect(
            CanvasExportWriter.format(liveDotAnimation: .none) == .staticJPEG
        )
    }

    @Test func writesJPEGFileToTemporaryDirectory() throws {
        let image = try #require(makeSolidImage(width: 120, height: 80))
        let fileURL = try #require(CanvasExportWriter.writeTemporaryStillImage(image))

        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(fileURL.pathExtension.lowercased() == "jpg")
        let data = try Data(contentsOf: fileURL)
        #expect(!data.isEmpty)
        #expect(UIImage(data: data) != nil)
    }
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

    context.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}
