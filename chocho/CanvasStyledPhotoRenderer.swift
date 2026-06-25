import UIKit

nonisolated enum CanvasStyledPhotoRenderer {
    nonisolated static func render(
        image: UIImage,
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        y2kCCDCache: Y2KCCDFilterCache? = nil,
        asciiArtSettings: ASCIIArtSettings = .default,
        asciiArtMask: SubjectMask? = nil,
        asciiArtCache: ASCIIArtCache? = nil,
        photoCompression: MainPhotoCompression = .none
    ) async -> UIImage {
        var result = image
        let originalSourcePixelSize = CanvasImageLoader.pixelSize(for: image)
        let asciiSourcePixelSize = photoCompression.compressedSize(for: originalSourcePixelSize)

        if y2kCCDFilterSettings.enabled {
            if let filtered = Y2KCCDFilterRenderer.render(
                image: result,
                settings: y2kCCDFilterSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ccd",
                cache: y2kCCDCache
            ) {
                result = filtered
            }
        }

        let asciiSourceKey = asciiSourceKey(
            baseSourceKey: sourceKey,
            y2kCCDFilterSettings: y2kCCDFilterSettings
        )
        if asciiArtSettings.enabled {
            if let mask = asciiArtMask,
               let art = renderASCII(
                   on: result,
                   mask: mask,
                   settings: asciiArtSettings,
                   targetPixelSize: targetPixelSize,
                   sourcePixelSize: asciiSourcePixelSize,
                   sourceKey: asciiSourceKey,
                   maskSourceKey: sourceKey,
                   photoCompression: photoCompression,
                   cache: asciiArtCache,
                   render: { image, mask, size, sourceSize, key, maskKey in
                       ASCIIArtRenderer.render(
                           image: image,
                           mask: mask,
                           settings: asciiArtSettings,
                           targetPixelSize: size,
                           sourcePixelSize: sourceSize,
                           sourceKey: key,
                           maskSourceKey: maskKey,
                           cache: asciiArtCache
                       )
                   }
               ) {
                result = art
            } else if let art = await renderASCIIAsync(
                on: result,
                mask: asciiArtMask,
                settings: asciiArtSettings,
                targetPixelSize: targetPixelSize,
                sourcePixelSize: asciiSourcePixelSize,
                sourceKey: asciiSourceKey,
                maskSourceKey: sourceKey,
                photoCompression: photoCompression,
                cache: asciiArtCache
            ) {
                result = art
            }
        }

        return result
    }

    nonisolated static func renderSync(
        image: UIImage,
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        targetPixelSize: CGSize? = nil,
        sourceKey: String = "source",
        y2kCCDCache: Y2KCCDFilterCache? = nil,
        asciiArtSettings: ASCIIArtSettings = .default,
        asciiArtMask: SubjectMask? = nil,
        asciiArtCache: ASCIIArtCache? = nil,
        photoCompression: MainPhotoCompression = .none
    ) -> UIImage {
        var result = image
        let originalSourcePixelSize = CanvasImageLoader.pixelSize(for: image)
        let asciiSourcePixelSize = photoCompression.compressedSize(for: originalSourcePixelSize)

        if y2kCCDFilterSettings.enabled {
            if let filtered = Y2KCCDFilterRenderer.render(
                image: result,
                settings: y2kCCDFilterSettings,
                targetPixelSize: targetPixelSize,
                sourceKey: "\(sourceKey)-ccd",
                cache: y2kCCDCache
            ) {
                result = filtered
            }
        }

        let asciiSourceKey = asciiSourceKey(
            baseSourceKey: sourceKey,
            y2kCCDFilterSettings: y2kCCDFilterSettings
        )
        if asciiArtSettings.enabled,
           let art = renderASCII(
               on: result,
               mask: asciiArtMask,
               settings: asciiArtSettings,
               targetPixelSize: targetPixelSize,
               sourcePixelSize: asciiSourcePixelSize,
               sourceKey: asciiSourceKey,
               maskSourceKey: sourceKey,
               photoCompression: photoCompression,
               cache: asciiArtCache,
               render: { image, mask, size, sourceSize, key, maskKey in
                   ASCIIArtRenderer.render(
                       image: image,
                       mask: mask,
                       settings: asciiArtSettings,
                       targetPixelSize: size,
                       sourcePixelSize: sourceSize,
                       sourceKey: key,
                       maskSourceKey: maskKey,
                       cache: asciiArtCache
                   )
               }
           ) {
            result = art
        }

        return result
    }

    private nonisolated static func asciiInput(
        for image: UIImage,
        photoCompression: MainPhotoCompression,
        targetPixelSize: CGSize?
    ) -> (image: UIImage, targetPixelSize: CGSize)? {
        let fallbackSize = targetPixelSize ?? CanvasImageLoader.pixelSize(for: image)
        guard photoCompression != .none else {
            return (image, fallbackSize)
        }

        let sourcePixelSize = CanvasImageLoader.pixelSize(for: image)
        let compressedPixelSize = photoCompression.compressedSize(for: sourcePixelSize)
        let roundedCompressedSize = CGSize(
            width: max(1, compressedPixelSize.width.rounded()),
            height: max(1, compressedPixelSize.height.rounded())
        )
        guard let compressed = CanvasImageLoader.resampledImage(image, to: roundedCompressedSize) else {
            return nil
        }
        return (compressed, roundedCompressedSize)
    }

    private nonisolated static func renderASCII(
        on image: UIImage,
        mask: SubjectMask?,
        settings: ASCIIArtSettings,
        targetPixelSize: CGSize?,
        sourcePixelSize: CGSize,
        sourceKey: String,
        maskSourceKey: String,
        photoCompression: MainPhotoCompression,
        cache: ASCIIArtCache?,
        render: (UIImage, SubjectMask?, CGSize?, CGSize, String, String) -> UIImage?
    ) -> UIImage? {
        guard let prepared = asciiInput(
            for: image,
            photoCompression: photoCompression,
            targetPixelSize: targetPixelSize
        ) else {
            return nil
        }

        return render(
            prepared.image,
            mask,
            prepared.targetPixelSize,
            sourcePixelSize,
            "\(sourceKey)-ascii-\(photoCompression.rawValue)",
            "\(maskSourceKey)-ascii-\(photoCompression.rawValue)"
        )
    }

    private nonisolated static func renderASCIIAsync(
        on image: UIImage,
        mask: SubjectMask?,
        settings: ASCIIArtSettings,
        targetPixelSize: CGSize?,
        sourcePixelSize: CGSize,
        sourceKey: String,
        maskSourceKey: String,
        photoCompression: MainPhotoCompression,
        cache: ASCIIArtCache?
    ) async -> UIImage? {
        guard let prepared = asciiInput(
            for: image,
            photoCompression: photoCompression,
            targetPixelSize: targetPixelSize
        ) else {
            return nil
        }

        if let mask,
           let art = ASCIIArtRenderer.render(
               image: prepared.image,
               mask: mask,
               settings: settings,
               targetPixelSize: prepared.targetPixelSize,
               sourcePixelSize: sourcePixelSize,
               sourceKey: "\(sourceKey)-ascii-\(photoCompression.rawValue)",
               maskSourceKey: "\(maskSourceKey)-ascii-\(photoCompression.rawValue)",
               cache: cache
           ) {
            return art
        }

        return await ASCIIArtRenderer.render(
            image: prepared.image,
            settings: settings,
            targetPixelSize: prepared.targetPixelSize,
            sourcePixelSize: sourcePixelSize,
            sourceKey: "\(sourceKey)-ascii-\(photoCompression.rawValue)",
            maskSourceKey: "\(maskSourceKey)-ascii-\(photoCompression.rawValue)",
            cache: cache
        )
    }

    private nonisolated static func asciiSourceKey(
        baseSourceKey: String,
        y2kCCDFilterSettings: Y2KCCDFilterSettings
    ) -> String {
        guard y2kCCDFilterSettings.enabled else { return baseSourceKey }
        return "\(baseSourceKey)-ccd-\(y2kCCDFilterSettings.cacheKey)"
    }

    nonisolated static func styledPreviewEnabled(
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        asciiArtSettings: ASCIIArtSettings = .default
    ) -> Bool {
        y2kCCDFilterSettings.enabled || asciiArtSettings.enabled
    }
}
