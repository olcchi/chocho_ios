import ImageIO
import UIKit

/// Prepares user photos for the puzzle canvas without decoding full-resolution originals.
enum CanvasImageLoader {
    /// Longest edge cap for canvas work and export. Large camera photos are downsampled at decode time.
    nonisolated static let maxPixelDimension = 2048

    nonisolated static func makeUIImage(
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

    /// Decodes and prepares an image for on-screen rendering on a background queue.
    nonisolated static func makeDisplayReadyUIImage(
        from data: Data,
        maxPixelDimension: Int = maxPixelDimension
    ) async -> UIImage? {
        let image = await Task.detached(priority: .userInitiated) {
            makeUIImage(from: data, maxPixelDimension: maxPixelDimension)
        }.value

        guard let image else { return nil }

        return await Task.detached(priority: .userInitiated) {
            image.preparingForDisplay()
        }.value
    }

    nonisolated static func makeDisplayReadyUIImage(
        from image: UIImage,
        maxPixelDimension: Int = maxPixelDimension
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let preparedImage = downsampleIfNeeded(
                image,
                maxPixelDimension: maxPixelDimension
            )

            return preparedImage.preparingForDisplay() ?? preparedImage
        }.value
    }

    nonisolated static func pixelSize(for image: UIImage) -> CGSize {
        CGSize(
            width: CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale)),
            height: CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        )
    }

    /// Scales a pixel size down so the longest edge fits `maxPixelDimension`.
    nonisolated static func fittedPixelSize(
        _ size: CGSize,
        maxPixelDimension: Int
    ) -> CGSize {
        guard maxPixelDimension > 0 else { return size }

        let longestEdge = max(size.width, size.height)
        guard longestEdge > CGFloat(maxPixelDimension) else { return size }

        let scale = CGFloat(maxPixelDimension) / longestEdge
        return CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    private nonisolated static func downsampleIfNeeded(
        _ image: UIImage,
        maxPixelDimension: Int
    ) -> UIImage {
        guard maxPixelDimension > 0 else { return image }

        let pixelSize = pixelSize(for: image)
        let longestEdge = max(pixelSize.width, pixelSize.height)
        guard longestEdge > CGFloat(maxPixelDimension) else { return image }

        let targetScale = CGFloat(maxPixelDimension) / longestEdge
        let targetSize = CGSize(
            width: pixelSize.width * targetScale,
            height: pixelSize.height * targetScale
        )

        return image.preparingThumbnail(of: targetSize) ?? image
    }
}
