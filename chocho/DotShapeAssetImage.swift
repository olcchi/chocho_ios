import SwiftUI
import UIKit

enum DotShapeAssetImage {
    nonisolated static func uiImage(named assetName: String) -> UIImage? {
        let catalogName = catalogAssetName(from: assetName)
        if shouldPreferExactDataAsset(named: catalogName),
           let image = uiImageFromDataAsset(named: assetName) {
            return image
        }

        if let image = UIImage(named: assetName), image.size.width > 0, image.size.height > 0 {
            return image
        }

        return uiImageFromDataAsset(named: assetName)
    }

    private nonisolated static func catalogAssetName(from assetName: String) -> String {
        if assetName.hasPrefix("public/") {
            return String(assetName.dropFirst("public/".count))
        }
        return assetName
    }

    private nonisolated static func shouldPreferExactDataAsset(named catalogName: String) -> Bool {
        DotShapeAssetCategoryParser.prefersDataAsset(for: catalogName)
    }

    private nonisolated static func uiImageFromDataAsset(named assetName: String) -> UIImage? {
        guard let dataAsset = NSDataAsset(name: assetName) else { return nil }
        return UIImage(data: dataAsset.data)
    }

    /// 将形状资源绘入上下文，供 `.destinationIn` 蒙版裁剪使用（仅其 alpha 通道参与裁剪）。
    nonisolated static func drawAlphaMask(
        named assetName: String,
        in context: CGContext,
        rect: CGRect,
        prefersCrispScaling: Bool
    ) {
        guard let image = uiImage(named: assetName) else { return }
        let previousInterpolationQuality = context.interpolationQuality
        if prefersCrispScaling {
            context.interpolationQuality = .none
        }
        defer { context.interpolationQuality = previousInterpolationQuality }
        image.draw(in: rect)
    }
}

struct DotShapeAssetImageView: View {
    let assetName: String
    var renderingMode: Image.TemplateRenderingMode = .original
    var tintColor: Color?
    var prefersCrispScaling = false

    var body: some View {
        if let uiImage = DotShapeAssetImage.uiImage(named: assetName) {
            if renderingMode == .template, let tintColor {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(prefersCrispScaling ? .none : .medium)
                    .scaledToFit()
                    .foregroundStyle(tintColor)
            } else {
                Image(uiImage: uiImage)
                    .renderingMode(renderingMode)
                    .resizable()
                    .interpolation(prefersCrispScaling ? .none : .medium)
                    .scaledToFit()
            }
        }
    }
}
