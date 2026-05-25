import UIKit

enum CanvasExportFormat: Equatable {
    /// Current default: rasterized canvas key frame.
    case staticJPEG
    /// Reserved for Live Photo export (key frame + paired motion).
    case livePhoto
}

enum CanvasExportWriter {
    /// Balances visual quality and encode speed for photo + grid exports.
    nonisolated static let jpegCompressionQuality: CGFloat = 0.92

    nonisolated static func format(for source: CanvasPhotoSource?) -> CanvasExportFormat {
        guard let source, source.isLivePhoto else {
            return .staticJPEG
        }

        // Motion export will branch here once Live Photo rendering exists.
        return .staticJPEG
    }

    nonisolated static func writeTemporaryExport(
        _ image: UIImage,
        source: CanvasPhotoSource?
    ) -> URL? {
        switch format(for: source) {
        case .staticJPEG:
            return writeTemporaryJPEG(image)
        case .livePhoto:
            return writeTemporaryJPEG(image)
        }
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
