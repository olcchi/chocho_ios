import SwiftUI
import UIKit

struct CanvasExportSnapshot {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let photoCompression: MainPhotoCompression
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let dots: [PuzzleDot]
    let dotScale: CGFloat
    let dotColor: Color
    let usesRandomDotColors: Bool
    let dotCharacterText: String
    let liveDotAnimation: LiveDotAnimation
    let y2kCCDFilterSettings: Y2KCCDFilterSettings
    let asciiArtSettings: ASCIIArtSettings
    let isSourceLiveMotionEnabled: Bool
    /// 与预览一致：内存中已成功加载源 Live 配对视频，而非仅持有相册 identifier。
    let hasSourceLiveVideo: Bool
    let sourcePhotoAssetLocalIdentifier: String?

    var exportsAsLivePhoto: Bool {
        CanvasExportWriter.exportsAsLivePhoto(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            hasSourceLiveVideo: hasSourceLiveVideo
        )
    }

    var exportFormat: CanvasExportFormat {
        CanvasExportWriter.format(
            liveDotAnimation: liveDotAnimation,
            isSourceLiveMotionEnabled: isSourceLiveMotionEnabled,
            hasSourceLiveVideo: hasSourceLiveVideo
        )
    }
}
