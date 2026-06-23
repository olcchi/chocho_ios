import ImageIO
import UIKit

/// 在解码阶段限制最长边，避免把完整分辨率相机图载入内存（画布编辑与导出共用上限）。
enum CanvasImageLoader {
    /// 像素最长边上限；超过则在 `CGImageSource` 缩略图路径或 `preparingThumbnail` 时降采样。
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

    /// 后台解码并 `preparingForDisplay()`，减轻主线程卡顿。
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

    /// 按比例缩小像素尺寸，使最长边不超过给定上限（Live Photo 配对视频编码用）。
    /// Resamples to exact pixel dimensions (scale = 1). Used before ASCII regeneration on compressed photos.
    nonisolated static func resampledImage(_ image: UIImage, to pixelSize: CGSize) -> UIImage? {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        guard width > 0, height > 0 else { return nil }

        let targetSize = CGSize(width: width, height: height)
        let currentSize = Self.pixelSize(for: image)
        if abs(currentSize.width - targetSize.width) < 0.5,
           abs(currentSize.height - targetSize.height) < 0.5 {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

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
