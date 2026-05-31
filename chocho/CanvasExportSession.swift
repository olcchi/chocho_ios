import Foundation

/// Owns temporary export resources while the share sheet and custom save action are active.
struct CanvasExportSession {
    let product: CanvasExportProduct

    private var cleanup: (() -> Void)?
    private(set) var isRetainingFilesForSave = false

    var hasCleanedUp: Bool {
        cleanup == nil
    }

    init(product: CanvasExportProduct, cleanup: (() -> Void)? = nil) {
        self.product = product
        self.cleanup = cleanup ?? { product.removeTemporaryFiles() }
    }

    mutating func markSaveInProgress() {
        isRetainingFilesForSave = true
    }

    mutating func handleDismiss() {
        guard !isRetainingFilesForSave else { return }
        cleanupNow()
    }

    mutating func handleSaveFinished() {
        isRetainingFilesForSave = false
        cleanupNow()
    }

    mutating func cleanupNow() {
        cleanup?()
        cleanup = nil
        isRetainingFilesForSave = false
    }
}
