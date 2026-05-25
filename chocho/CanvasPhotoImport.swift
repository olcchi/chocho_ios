import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Imports photos from `PhotosPicker` for the puzzle canvas.
///
/// Today the canvas edits a single key frame (`UIImage`). Live Photo motion is not rendered yet,
/// but `CanvasPhotoSource` keeps the picker item and kind so export can later produce a Live Photo.
enum CanvasPhotoImport {
    nonisolated enum Kind: Equatable {
        case stillImage
        case livePhoto
    }

    struct Result {
        let source: CanvasPhotoSource
    }

    enum ImportError: Error {
        case missingData
        case decodeFailed
    }

    /// Picker filter shared by header and empty-state upload controls.
    static let pickerMatching = PHPickerFilter.any(of: [.images, .livePhotos])

    static func isLivePhotoItem(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .livePhoto) }
    }

    static func importPhoto(from item: PhotosPickerItem) async throws -> Result {
        let kind: Kind = isLivePhotoItem(item) ? .livePhoto : .stillImage

        if let keyPhoto = await importAssetKeyFrame(
            from: item,
            requiringLivePhoto: kind == .livePhoto
        ) {
            return Result(
                source: CanvasPhotoSource(
                    keyPhoto: keyPhoto,
                    kind: kind,
                    pickerItem: item
                )
            )
        }

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportError.missingData
        }

        guard let keyPhoto = await CanvasImageLoader.makeDisplayReadyUIImage(from: data) else {
            throw ImportError.decodeFailed
        }

        return Result(
            source: CanvasPhotoSource(
                keyPhoto: keyPhoto,
                kind: kind,
                pickerItem: item
            )
        )
    }

    /// Key frame for canvas preview. Full `PHLivePhoto` export will load from `pickerItem` later.
    private static func importAssetKeyFrame(
        from item: PhotosPickerItem,
        requiringLivePhoto: Bool
    ) async -> UIImage? {
        guard let identifier = item.itemIdentifier else { return nil }

        let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        ).firstObject

        guard let asset else { return nil }
        if requiringLivePhoto, !asset.mediaSubtypes.contains(.photoLive) {
            return nil
        }

        guard let image = await requestKeyPhoto(from: asset) else { return nil }

        return await CanvasImageLoader.makeDisplayReadyUIImage(from: image)
    }

    private static func requestKeyPhoto(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            let maxDimension = CGFloat(CanvasImageLoader.maxPixelDimension)
            let targetSize = CGSize(width: maxDimension, height: maxDimension)

            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !didResume else { return }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if info?[PHImageErrorKey] != nil {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard let image, !isDegraded else { return }

                didResume = true
                continuation.resume(returning: image)
            }
        }
    }
}

nonisolated struct CanvasPhotoSource {
    let keyPhoto: UIImage
    let kind: CanvasPhotoImport.Kind
    let pickerItem: PhotosPickerItem

    var isLivePhoto: Bool {
        kind == .livePhoto
    }
}
