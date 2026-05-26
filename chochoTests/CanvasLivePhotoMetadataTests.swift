import ImageIO
import Testing
import UIKit
@testable import chocho

struct CanvasLivePhotoMetadataTests {
    @Test func jpegIncludesAssetIdentifierMetadata() throws {
        let image = try #require(makeSolidImage(width: 64, height: 48))
        let assetIdentifier = CanvasLivePhotoMetadata.makeAssetIdentifier()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-live-meta-\(UUID().uuidString).jpg")

        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(
            CanvasLivePhotoMetadata.writeJPEG(
                image,
                assetIdentifier: assetIdentifier,
                to: fileURL,
                compressionQuality: 0.9
            )
        )

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let makerApple = properties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any]
        else {
            Issue.record("Missing JPEG metadata")
            return
        }

        #expect(makerApple["17"] as? String == assetIdentifier)
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

    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}
