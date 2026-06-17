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
    let onBack: () -> Void
    let onDownload: () -> Void

    nonisolated static func uploadActionTitle(hasCanvasImage: Bool) -> String {
        hasCanvasImage ? "换图" : "上传"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 17))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("返回")

            Spacer(minLength: 0)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: CanvasPhotoImport.pickerMatching,
                preferredItemEncoding: .current,
                photoLibrary: CanvasPhotoImport.pickerPhotoLibrary
            ) {
                CanvasIconActionButton(
                    accessibilityLabel: Self.uploadActionTitle(hasCanvasImage: hasCanvasImage),
                    iconAssetName: "public/upload"
                )
            }
            .disabled(isBusy)

            Button(action: onDownload) {
                CanvasIconActionButton(
                    accessibilityLabel: "下载",
                    iconAssetName: "public/download",
                    isEnabled: canDownload && !isBusy
                )
            }
            .disabled(!canDownload || isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 30)
    }
}

private struct CanvasIconActionButton: View {
    let accessibilityLabel: String
    let iconAssetName: String
    var isEnabled = true

    var body: some View {
        Image(iconAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 15, height: 15)
            .foregroundStyle(isEnabled ? Color.primaryForeground : Color.primaryForeground.opacity(0.35))
            .frame(width: 30, height: 30)
            .background(
                actionColor.opacity(isEnabled ? 1 : 0.45),
                in: Capsule(style: .continuous)
            )
            .contentShape(Capsule(style: .continuous))
            .accessibilityLabel(accessibilityLabel)
    }

    private var actionColor: Color {
        Color.primary
    }
}
