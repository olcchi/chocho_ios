import Foundation
import UIKit
import Testing
@testable import chocho

struct CanvasExportSessionTests {
    @Test func dismissRetainsLivePhotoFilesUntilSaveFinishes() throws {
        let product = CanvasExportProduct.stillImage(try makeTemporaryExportFile())
        var cleanupCount = 0
        var session = CanvasExportSession(product: product) {
            cleanupCount += 1
        }

        session.markSaveInProgress()
        session.handleDismiss()

        #expect(cleanupCount == 0)
        #expect(session.isRetainingFilesForSave)

        session.handleSaveFinished()

        #expect(cleanupCount == 1)
        #expect(!session.isRetainingFilesForSave)
    }

    @Test func dismissCleansFilesWhenSaveWasNotStarted() throws {
        let product = CanvasExportProduct.stillImage(try makeTemporaryExportFile())
        var cleanupCount = 0
        var session = CanvasExportSession(product: product) {
            cleanupCount += 1
        }

        session.handleDismiss()

        #expect(cleanupCount == 1)
        #expect(!session.isRetainingFilesForSave)
    }

    @Test func saveActivityMarksSaveBeforeShareSheetDismissCanCleanFiles() throws {
        let product = CanvasExportProduct.stillImage(try makeTemporaryExportFile())
        var beginCount = 0
        let activity = SaveCanvasToPhotosActivity(
            product: product,
            onBeginSaveToPhotos: {
                beginCount += 1
            },
            onSaveToPhotos: { _ in }
        )

        activity.prepare(withActivityItems: product.shareItems)
        activity.prepare(withActivityItems: product.shareItems)

        #expect(beginCount == 1)
    }
}

private func makeTemporaryExportFile() throws -> URL {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocho-export-session-test-\(UUID().uuidString)")
        .appendingPathExtension("jpg")
    try Data([0x63]).write(to: fileURL, options: .atomic)
    return fileURL
}
