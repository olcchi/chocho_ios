import Photos

nonisolated protocol CanvasPhotoLibrarySaving: AnyObject {
    func savePhoto(at fileURL: URL) async -> Bool
}

enum CanvasPhotoLibrarySaver {
    @MainActor
    static func save(
        fileURL: URL,
        using saver: CanvasPhotoLibrarySaving = SystemCanvasPhotoLibrarySaver()
    ) async -> Bool {
        await saver.savePhoto(at: fileURL)
    }
}

nonisolated final class SystemCanvasPhotoLibrarySaver: CanvasPhotoLibrarySaving {
    func savePhoto(at fileURL: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
