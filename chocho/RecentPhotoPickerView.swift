import Photos
import SwiftUI
import UIKit

nonisolated enum RecentPhotoPickerLayout {
    static let largeWidthThreshold: CGFloat = 414
    static let gridSpacing: CGFloat = 3
    static let horizontalInset: CGFloat = 12

    static func columnCount(forWidth width: CGFloat) -> Int {
        width >= largeWidthThreshold ? 4 : 3
    }
}

struct RecentPhotoPickerView: View {
    let isImporting: Bool
    let onCancel: () -> Void
    let onSelectAsset: (PHAsset) -> Void

    @State private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    @State private var isAboutPresented = false

    var body: some View {
        NavigationStack {
            pickerContent
                .navigationDestination(isPresented: $isAboutPresented) {
                    AboutView()
                }
        }
    }

    private var pickerContent: some View {
        GeometryReader { proxy in
            content(width: proxy.size.width)
        }
        .background(Color.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .task {
            await refreshLibrary()
        }
        .overlay {
            if isImporting {
                importingOverlay
            }
        }
    }

    private var topBar: some View {
        topBarContent
            .frame(maxWidth: .infinity)
            .background {
                RecentPhotoPickerHeaderGlassBackground()
                    .ignoresSafeArea(edges: .top)
            }
            .environment(\.colorScheme, .light)
    }

    private var topBarContent: some View {
        ZStack {
            Text("最近图片")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.foreground)

            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.foreground)
                .accessibilityLabel("关闭")

                Spacer()

                Button {
                    isAboutPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .regular))
                        Text("关于")
                            .font(.system(size: 13, weight: .regular))
                    }
                    .frame(height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.foreground)
                .accessibilityLabel("关于")
            }
        }
        .padding(.horizontal, RecentPhotoPickerLayout.horizontalInset)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        if isLoading {
            RecentPhotoPickerStatusView(title: "正在读取…", systemImage: "photo.on.rectangle")
        } else if !canReadPhotos {
            RecentPhotoPickerStatusView(title: "需要相册权限", systemImage: "lock")
        } else if assets.isEmpty {
            RecentPhotoPickerStatusView(title: "没有最近图片", systemImage: "photo")
        } else {
            photoGrid(width: width)
        }
    }

    private func photoGrid(width: CGFloat) -> some View {
        let columnCount = RecentPhotoPickerLayout.columnCount(forWidth: width)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: RecentPhotoPickerLayout.gridSpacing),
            count: columnCount
        )

        return ScrollView {
            LazyVGrid(columns: columns, spacing: RecentPhotoPickerLayout.gridSpacing) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    Button {
                        onSelectAsset(asset)
                    } label: {
                        RecentPhotoThumbnailView(asset: asset)
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }
            }
            .padding(.horizontal, RecentPhotoPickerLayout.horizontalInset)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.visible, axes: .vertical)
        .scrollIndicatorsFlash(onAppear: true)
        .background(Color.background)
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ProgressView("正在加载…")
                .font(.system(size: 15, weight: .medium))
                .tint(Color.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.popover, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var canReadPhotos: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    @MainActor
    private func refreshLibrary() async {
        isLoading = true

        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        authorizationStatus = status
        assets = canReadPhotos ? Self.fetchRecentAssets() : []
        isLoading = false
    }

    private static func fetchRecentAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
}

struct RecentPhotoPickerHeaderGlassBackground: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(Color.popover.opacity(0.28))
                    .glassEffect(
                        .regular.tint(Color.popover.opacity(0.42)),
                        in: Rectangle()
                    )
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Rectangle()
                            .fill(Color.popover.opacity(0.68))
                    }
            }
        }
        .environment(\.colorScheme, .light)
    }
}

private struct RecentPhotoThumbnailView: View {
    let asset: PHAsset

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var imageRequestID: PHImageRequestID?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color.secondary)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

                if asset.mediaSubtypes.contains(.photoLive) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .task(id: asset.localIdentifier) {
            requestThumbnail()
        }
        .onDisappear {
            cancelThumbnailRequest()
        }
        .accessibilityLabel("照片")
    }

    @MainActor
    private func requestThumbnail() {
        cancelThumbnailRequest()

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let targetDimension = 180 * max(displayScale, 1)
        imageRequestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: targetDimension, height: targetDimension),
            contentMode: .aspectFill,
            options: options
        ) { nextImage, info in
            guard let nextImage else { return }
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                return
            }

            Task { @MainActor in
                image = nextImage
            }
        }
    }

    @MainActor
    private func cancelThumbnailRequest() {
        if let imageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
            self.imageRequestID = nil
        }
    }
}

private struct RecentPhotoPickerStatusView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.appAccent)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

#Preview("Recent Photos") {
    RecentPhotoPickerView(
        isImporting: false,
        onCancel: {},
        onSelectAsset: { _ in }
    )
}
