import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// Embeds the paired `content.identifier` metadata required for Photos to treat resources as a Live Photo.
nonisolated enum CanvasLivePhotoMetadata {
  /// Maker Apple dictionary key for the asset identifier (`kFigAppleMakerNote_AssetIdentifier`).
  private static let makerAppleAssetIdentifierKey = "17"

  nonisolated static func makeAssetIdentifier() -> String {
    UUID().uuidString
  }

  nonisolated static func writeJPEG(
    _ image: UIImage,
    assetIdentifier: String,
    to url: URL,
    compressionQuality: CGFloat
  ) -> Bool {
    guard let cgImage = image.cgImage else { return false }

    guard let destination = CGImageDestinationCreateWithURL(
      url as CFURL,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else {
      return false
    }

    let metadata: [String: Any] = [
      kCGImagePropertyMakerAppleDictionary as String: [
        makerAppleAssetIdentifierKey: assetIdentifier,
      ],
      kCGImageDestinationLossyCompressionQuality as String: compressionQuality,
    ]

    CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
    return CGImageDestinationFinalize(destination)
  }

  nonisolated static func makeVideoMetadataItems(assetIdentifier: String) -> [AVMetadataItem] {
    let item = AVMutableMetadataItem()
    item.identifier = .quickTimeMetadataContentIdentifier
    item.value = assetIdentifier as (NSString)
    item.dataType = kCMMetadataBaseDataType_UTF8 as String
    return [item]
  }
}
