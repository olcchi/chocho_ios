import Testing
import UIKit
@testable import chocho

struct CanvasPhotoLibrarySaverTests {
    @Test func savesExportByPassingFileURLToPhotoLibrary() async {
        let fileURL = URL(fileURLWithPath: "/tmp/chocho-export.jpg")
        let saver = SpyPhotoLibrarySaver()

        let didSave = await CanvasPhotoLibrarySaver.save(fileURL: fileURL, using: saver)

        #expect(didSave)
        #expect(saver.savedFileURL == fileURL)
    }
}

private final class SpyPhotoLibrarySaver: CanvasPhotoLibrarySaving {
    var savedFileURL: URL?

    func savePhoto(at fileURL: URL) async -> Bool {
        savedFileURL = fileURL
        return true
    }

    func saveLivePhoto(imageURL: URL, videoURL: URL) async -> Bool {
        savedFileURL = imageURL
        return true
    }
}
