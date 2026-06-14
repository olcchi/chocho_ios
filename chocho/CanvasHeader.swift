//
//  CanvasHeader.swift
//  chocho
//
//  Created by Codex on 2026/5/24.
//

import Photos
import PhotosUI
import SwiftUI

struct CanvasHeader: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasCanvasImage: Bool
    let canDownload: Bool
    var isBusy = false
    let onDownload: () -> Void

    nonisolated static func uploadActionTitle(hasCanvasImage: Bool) -> String {
        hasCanvasImage ? "换图" : "上传"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image("chocho")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .accessibilityLabel("chocho")

            Spacer(minLength: 0)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: CanvasPhotoImport.pickerMatching,
                preferredItemEncoding: .current,
                photoLibrary: CanvasPhotoImport.pickerPhotoLibrary
            ) {
                CanvasActionLabel(
                    title: Self.uploadActionTitle(hasCanvasImage: hasCanvasImage),
                    iconAssetName: "public/upload"
                )
            }
            .disabled(isBusy)

            Button(action: onDownload) {
                CanvasActionLabel(
                    title: "下载",
                    iconAssetName: "public/download",
                    isEnabled: canDownload && !isBusy
                )
            }
            .disabled(!canDownload || isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 30)
    }
}

private struct CanvasActionLabel: View {
    let title: String
    let iconAssetName: String
    var isEnabled = true

    var body: some View {
        HStack(spacing: 5) {
            Image(iconAssetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isEnabled ? Color.primaryForeground : Color.primaryForeground.opacity(0.35))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            actionColor.opacity(isEnabled ? 1 : 0.45),
            in: Capsule(style: .continuous)
        )
        .contentShape(Capsule(style: .continuous))
        .accessibilityLabel(title)
    }

    private var actionColor: Color {
        Color.primary
    }
}
