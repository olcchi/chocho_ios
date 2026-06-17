import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 从相册选择入口导入照片到画布。
///
/// 当前编辑的是单张关键帧（`UIImage`）；若用户选的是相册 Live Photo，会保留资源类型与
/// `assetLocalIdentifier`，便于日后从原资源导出系统 Live Photo，画布上的「实况」动画仍由
/// `LiveDotAnimation` 控制。
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

    /// 顶栏与空态上传区共用的相册筛选：静图 + Live Photo。
    static let pickerMatching = PHPickerFilter.any(of: [.images, .livePhotos])

    /// 必须绑定共享相册，否则 `PhotosPickerItem.itemIdentifier` 为空，无法识别 Live Photo。
    static let pickerPhotoLibrary = PHPhotoLibrary.shared()

    static func isLivePhotoItem(_ item: PhotosPickerItem) -> Bool {
        let types = item.supportedContentTypes
        if types.contains(where: { contentType in
            contentType.conforms(to: .livePhoto)
                || contentType.identifier.contains("live-photo")
        }) {
            return true
        }

        let hasStill = types.contains { $0.conforms(to: .image) }
        let hasVideo = types.contains {
            $0.conforms(to: .movie)
                || $0.conforms(to: .video)
                || $0.identifier.contains("quicktime-movie")
        }
        return hasStill && hasVideo
    }

    /// 读取相册资源前请求权限；无权限时 `PHAsset.fetchAssets` 会返回空。
    @MainActor
    static func requestPhotoLibraryReadAccessIfNeeded() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    nonisolated static func assetHasPairedVideoResource(_ asset: PHAsset) -> Bool {
        PHAssetResource.assetResources(for: asset).contains { $0.type == .pairedVideo }
    }

    /// 识别相册来源类型；`PHAsset.mediaSubtypes` 比 `supportedContentTypes` 更可靠。
    static func resolveKind(for item: PhotosPickerItem) -> Kind {
        resolvedKind(
            contentTypesIncludeLivePhoto: isLivePhotoItem(item),
            assetHasPhotoLiveSubtype: assetHasPhotoLiveSubtype(
                itemIdentifier: item.itemIdentifier
            ),
            assetHasPairedVideo: assetHasPairedVideoResource(
                itemIdentifier: item.itemIdentifier
            )
        )
    }

    static func resolvedKind(
        contentTypesIncludeLivePhoto: Bool,
        assetHasPhotoLiveSubtype: Bool,
        assetHasPairedVideo: Bool = false
    ) -> Kind {
        if contentTypesIncludeLivePhoto
            || assetHasPhotoLiveSubtype
            || assetHasPairedVideo {
            return .livePhoto
        }
        return .stillImage
    }

    static func resolvedKind(for asset: PHAsset, item: PhotosPickerItem) -> Kind {
        resolvedKind(
            contentTypesIncludeLivePhoto: isLivePhotoItem(item),
            assetHasPhotoLiveSubtype: asset.mediaSubtypes.contains(.photoLive),
            assetHasPairedVideo: assetHasPairedVideoResource(asset)
        )
    }

    static func resolvedKind(for asset: PHAsset) -> Kind {
        resolvedKind(
            contentTypesIncludeLivePhoto: false,
            assetHasPhotoLiveSubtype: asset.mediaSubtypes.contains(.photoLive),
            assetHasPairedVideo: assetHasPairedVideoResource(asset)
        )
    }

    nonisolated static func assetHasPhotoLiveSubtype(itemIdentifier: String?) -> Bool {
        guard let asset = asset(for: itemIdentifier) else { return false }
        return asset.mediaSubtypes.contains(.photoLive)
    }

    nonisolated static func assetHasPairedVideoResource(itemIdentifier: String?) -> Bool {
        guard let asset = asset(for: itemIdentifier) else { return false }
        return assetHasPairedVideoResource(asset)
    }

    nonisolated static func asset(for itemIdentifier: String?) -> PHAsset? {
        guard let itemIdentifier else { return nil }

        return PHAsset.fetchAssets(
            withLocalIdentifiers: [itemIdentifier],
            options: nil
        ).firstObject
    }

    static func importPhoto(from item: PhotosPickerItem) async throws -> Result {
        if let source = await importFromPhotoLibraryAsset(from: item) {
            return Result(source: source)
        }

        let kind = resolveKind(for: item)

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportError.missingData
        }

        guard let keyPhoto = await CanvasImageLoader.makeDisplayReadyUIImage(from: data) else {
            throw ImportError.decodeFailed
        }

        return Result(source: CanvasPhotoSource(keyPhoto: keyPhoto, kind: kind, pickerItem: item))
    }

    static func importPhoto(from asset: PHAsset) async throws -> Result {
        guard let image = await requestKeyPhoto(from: asset) else {
            throw ImportError.missingData
        }

        guard let keyPhoto = await CanvasImageLoader.makeDisplayReadyUIImage(from: image) else {
            throw ImportError.decodeFailed
        }

        return Result(source: CanvasPhotoSource(
            keyPhoto: keyPhoto,
            kind: resolvedKind(for: asset),
            assetLocalIdentifier: asset.localIdentifier
        ))
    }

    /// 优先从 `PHAsset` 拉关键帧，并用资源 subtype 判定 Live Photo。
    private static func importFromPhotoLibraryAsset(
        from item: PhotosPickerItem
    ) async -> CanvasPhotoSource? {
        guard let asset = asset(for: item.itemIdentifier) else { return nil }

        guard let image = await requestKeyPhoto(from: asset) else { return nil }
        guard let keyPhoto = await CanvasImageLoader.makeDisplayReadyUIImage(from: image) else {
            return nil
        }

        let kind = resolvedKind(for: asset, item: item)
        return CanvasPhotoSource(
            keyPhoto: keyPhoto,
            kind: kind,
            pickerItem: item,
            assetLocalIdentifier: asset.localIdentifier
        )
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
    let pickerItem: PhotosPickerItem?
    let assetLocalIdentifier: String?

    init(
        keyPhoto: UIImage,
        kind: CanvasPhotoImport.Kind,
        pickerItem: PhotosPickerItem? = nil,
        assetLocalIdentifier: String? = nil
    ) {
        self.keyPhoto = keyPhoto
        self.kind = kind
        self.pickerItem = pickerItem
        self.assetLocalIdentifier = assetLocalIdentifier ?? pickerItem?.itemIdentifier
    }

    var isLivePhoto: Bool {
        Self.isLivePhotoKind(kind)
    }

    static func isLivePhotoKind(_ kind: CanvasPhotoImport.Kind) -> Bool {
        kind == .livePhoto
    }
}
