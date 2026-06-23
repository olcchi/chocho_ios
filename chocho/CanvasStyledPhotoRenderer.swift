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

        if asciiArtSettings.enabled {
            if let mask = asciiArtMask,
               let art = renderASCII(
                   on: result,
                   mask: mask,
                   settings: asciiArtSettings,
                   targetPixelSize: targetPixelSize,
                   sourceKey: sourceKey,
                   photoCompression: photoCompression,
                   cache: asciiArtCache,
                   render: { image, mask, size, key in
                       ASCIIArtRenderer.render(
                           image: image,
                           mask: mask,
                           settings: asciiArtSettings,
                           targetPixelSize: size,
                           sourceKey: key,
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
                sourceKey: sourceKey,
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

        if asciiArtSettings.enabled,
           let art = renderASCII(
               on: result,
               mask: asciiArtMask,
               settings: asciiArtSettings,
               targetPixelSize: targetPixelSize,
               sourceKey: sourceKey,
               photoCompression: photoCompression,
               cache: asciiArtCache,
               render: { image, mask, size, key in
                   ASCIIArtRenderer.render(
                       image: image,
                       mask: mask,
                       settings: asciiArtSettings,
                       targetPixelSize: size,
                       sourceKey: key,
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
        sourceKey: String,
        photoCompression: MainPhotoCompression,
        cache: ASCIIArtCache?,
        render: (UIImage, SubjectMask?, CGSize?, String) -> UIImage?
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
            "\(sourceKey)-ascii-\(photoCompression.rawValue)"
        )
    }

    private nonisolated static func renderASCIIAsync(
        on image: UIImage,
        mask: SubjectMask?,
        settings: ASCIIArtSettings,
        targetPixelSize: CGSize?,
        sourceKey: String,
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
               sourceKey: "\(sourceKey)-ascii-\(photoCompression.rawValue)",
               cache: cache
           ) {
            return art
        }

        return await ASCIIArtRenderer.render(
            image: prepared.image,
            settings: settings,
            targetPixelSize: prepared.targetPixelSize,
            sourceKey: "\(sourceKey)-ascii-\(photoCompression.rawValue)",
            cache: cache
        )
    }

    nonisolated static func styledPreviewEnabled(
        y2kCCDFilterSettings: Y2KCCDFilterSettings,
        asciiArtSettings: ASCIIArtSettings = .default
    ) -> Bool {
        y2kCCDFilterSettings.enabled || asciiArtSettings.enabled
    }
}
