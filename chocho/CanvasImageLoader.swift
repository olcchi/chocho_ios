import ImageIO
import UIKit

/// Prepares user photos for the puzzle canvas without decoding full-resolution originals.
enum CanvasImageLoader {
    /// Longest edge cap for canvas work and export. Large camera photos are downsampled at decode time.
    static let maxPixelDimension = 2048

    static func makeUIImage(
        from data: Data,
        maxPixelDimension: Int = maxPixelDimension
    ) -> UIImage? {
        guard maxPixelDimension > 0 else {
            return UIImage(data: data)
        }

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions as CFDictionary
        ) else {
            return UIImage(data: data)
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    static func pixelSize(for image: UIImage) -> CGSize {
        CGSize(
            width: CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale)),
            height: CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        )
    }
}
