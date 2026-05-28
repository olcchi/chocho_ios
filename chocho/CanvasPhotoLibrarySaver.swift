import Photos

nonisolated protocol CanvasPhotoLibrarySaving: AnyObject {
    func savePhoto(at fileURL: URL) async -> Bool
    func saveLivePhoto(imageURL: URL, videoURL: URL) async -> Bool
}

/// 将导出产物写入系统相册；权限请求必须在主线程，实际写入可在后台执行。
enum CanvasPhotoLibrarySaver {
    @MainActor
    static func save(
        product: CanvasExportProduct,
        using saver: CanvasPhotoLibrarySaving = SystemCanvasPhotoLibrarySaver()
    ) async -> Bool {
        // 非隔离的 saver 可能在后台线程跑，系统权限弹窗只能由主线程唤起。
        guard await requestAuthorization() else { return false }

        switch product {
        case .stillImage(let fileURL):
            return await saver.savePhoto(at: fileURL)
        case .livePhoto(let bundle):
            return await saver.saveLivePhoto(imageURL: bundle.imageURL, videoURL: bundle.videoURL)
        }
    }

    @MainActor
    static func save(
        fileURL: URL,
        using saver: CanvasPhotoLibrarySaving = SystemCanvasPhotoLibrarySaver()
    ) async -> Bool {
        await saver.savePhoto(at: fileURL)
    }

    @MainActor
    static func requestAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let updated = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return updated == .authorized || updated == .limited
        default:
            return false
        }
    }
}

nonisolated final class SystemCanvasPhotoLibrarySaver: CanvasPhotoLibrarySaving {
    // Authorization is always pre-checked by CanvasPhotoLibrarySaver.save(product:)
    // on @MainActor before these methods are called, so no separate check is needed here.

    func savePhoto(at fileURL: URL) async -> Bool {
        return await performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        }
    }

    func saveLivePhoto(imageURL: URL, videoURL: URL) async -> Bool {
        return await performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
        }
    }

    private func performChanges(_ apply: @escaping () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                apply()
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
