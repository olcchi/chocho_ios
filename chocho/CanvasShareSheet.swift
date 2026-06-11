import SwiftUI
import UIKit

struct CanvasShareSheet: UIViewControllerRepresentable {
    let product: CanvasExportProduct
    let onBeginSaveToPhotos: () -> Void
    let onSaveToPhotos: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: product.shareItems,
            applicationActivities: [
                SaveCanvasToPhotosActivity(
                    product: product,
                    onBeginSaveToPhotos: onBeginSaveToPhotos,
                    onSaveToPhotos: onSaveToPhotos
                ),
            ]
        )
        // Exclude the system "Save Image / Save to Photos" entry so only our custom
        // "保存到相册" button appears, avoiding a duplicate Chinese + English pair.
        controller.excludedActivityTypes = [.saveToCameraRoll]
        controller.modalPresentationStyle = .pageSheet
        configureSheetPresentation(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        configureSheetPresentation(for: uiViewController)
    }

    private func configureSheetPresentation(for controller: UIActivityViewController) {
        guard let sheet = controller.sheetPresentationController else { return }
        sheet.detents = [.medium(), .large()]
        sheet.selectedDetentIdentifier = .medium
        sheet.prefersGrabberVisible = true
    }
}

final class SaveCanvasToPhotosActivity: UIActivity {
    private let product: CanvasExportProduct
    private let onBeginSaveToPhotos: () -> Void
    private let onSaveToPhotos: (Bool) -> Void
    private var didBeginSave = false

    init(
        product: CanvasExportProduct,
        onBeginSaveToPhotos: @escaping () -> Void,
        onSaveToPhotos: @escaping (Bool) -> Void
    ) {
        self.product = product
        self.onBeginSaveToPhotos = onBeginSaveToPhotos
        self.onSaveToPhotos = onSaveToPhotos
        super.init()
    }

    override var activityTitle: String? {
        "保存到相册"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "square.and.arrow.down")
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("olcchi.chocho.saveCanvasToPhotos")
    }

    override class var activityCategory: UIActivity.Category {
        .action
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        super.prepare(withActivityItems: activityItems)
        beginSaveIfNeeded()
    }

    override func perform() {
        Task { @MainActor in
            beginSaveIfNeeded()
            let didSave = await CanvasPhotoLibrarySaver.save(product: product)
            onSaveToPhotos(didSave)
            activityDidFinish(didSave)
        }
    }

    @MainActor
    private func beginSaveIfNeeded() {
        guard !didBeginSave else { return }

        didBeginSave = true
        onBeginSaveToPhotos()
    }
}
