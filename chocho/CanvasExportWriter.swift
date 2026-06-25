import UIKit

/// 分享/保存时的产物类型。
enum CanvasExportFormat: Equatable {
    /// 单张合成画布 JPEG。
    case staticJPEG
    /// 关键帧 JPEG + 配对 MOV（系统 Live Photo）。
    case livePhoto
}

/// 根据实况动画与图片来源选择导出格式，并写入临时 JPEG。
enum CanvasExportWriter {
    /// 草稿、静态导出、Live Photo 关键帧共用的 JPEG 质量。
    nonisolated static let jpegCompressionQuality: CGFloat = 0.92

    nonisolated static func format(
        liveDotAnimation: LiveDotAnimation,
        isSourceLiveMotionEnabled: Bool = false,
        hasSourceLiveVideo: Bool = false
    ) -> CanvasExportFormat {
        if exportsAsLivePhoto(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            hasSourceLiveVideo: hasSourceLiveVideo
        ) {
            return .livePhoto
        }

        return .staticJPEG
    }

    nonisolated static func exportsAsLivePhoto(
        liveDotAnimation: LiveDotAnimation,
        isSourceLiveMotionEnabled: Bool,
        hasSourceLiveVideo: Bool
    ) -> Bool {
        CanvasLiveMotionTiming.exportsAsLivePhoto(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            hasSourceLiveVideo: hasSourceLiveVideo
        )
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
