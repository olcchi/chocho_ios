import SwiftUI
import UIKit

enum DotShapeAssetImage {
    nonisolated static func uiImage(named assetName: String) -> UIImage? {
        if shouldPreferExactDataAsset(named: assetName),
           let image = uiImageFromDataAsset(named: assetName) {
            return image
        }

        if let image = UIImage(named: assetName), image.size.width > 0, image.size.height > 0 {
            return image
        }

        return uiImageFromDataAsset(named: assetName)
    }

    private nonisolated static func shouldPreferExactDataAsset(named assetName: String) -> Bool {
        DotShapeAssetCategoryParser.suffix(in: assetName) != nil
    }

    private nonisolated static func uiImageFromDataAsset(named assetName: String) -> UIImage? {
        guard let dataAsset = NSDataAsset(name: assetName) else { return nil }
        return UIImage(data: dataAsset.data)
    }
}

struct DotShapeAssetImageView: View {
    let assetName: String
    var renderingMode: Image.TemplateRenderingMode = .original
    var tintColor: Color?

    var body: some View {
        if let uiImage = DotShapeAssetImage.uiImage(named: assetName) {
            if renderingMode == .template, let tintColor {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tintColor)
            } else {
                Image(uiImage: uiImage)
                    .renderingMode(renderingMode)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
