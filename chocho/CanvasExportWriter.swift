import UIKit

enum CanvasExportFormat: Equatable {
    /// Rasterized canvas key frame as JPEG.
    case staticJPEG
    /// Key frame plus paired motion video.
    case livePhoto
}

enum CanvasExportWriter {
    /// Balances visual quality and encode speed for photo + grid exports.
    nonisolated static let jpegCompressionQuality: CGFloat = 0.92

    nonisolated static func format(
        liveDotAnimation: LiveDotAnimation,
        source: CanvasPhotoSource? = nil
    ) -> CanvasExportFormat {
        if liveDotAnimation.exportsAsLivePhoto {
            return .livePhoto
        }

        guard let source, source.isLivePhoto else {
            return .staticJPEG
        }

        return .staticJPEG
    }

    nonisolated static func writeTemporaryStillImage(_ image: UIImage) -> URL? {
        writeTemporaryJPEG(image)
    }

    nonisolated static func writeTemporaryJPEG(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: jpegCompressionQuality) else {
            return nil
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-canvas-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}
