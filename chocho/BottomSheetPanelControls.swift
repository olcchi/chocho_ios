import SwiftUI
import UIKit

struct BottomSheetDotControls {
    var dotCount: Binding<Double>
    var dotScale: Binding<Double>
    var selectedDotColor: Binding<Color>
    var selectedDotShape: Binding<DotShapeAsset>
    var selectedDotShapeCategory: Binding<DotShapeCategory>
    var dotCharacterText: Binding<String>
    var isTraceVisible: Binding<Bool>
    var isTraceDrawingEnabled: Binding<Bool>
    var isSubjectOutlineEnabled: Binding<Bool>
    var photoCompression: Binding<MainPhotoCompression>
    var y2kCCDFilterSettings: Binding<Y2KCCDFilterSettings>
    var asciiArtSettings: Binding<ASCIIArtSettings>
    var subjectGlowSettings: Binding<SubjectGlowSettings>
    var textBubbleSettings: Binding<TextBubbleSettings>
    var isDetectingSubjectOutline: Bool = false
    var onRandomizeDots: () -> Void = {}
}

struct BottomSheetLiveControls {
    var liveDotAnimation: Binding<LiveDotAnimation>
    var isSourceLivePhoto: Bool = false
    var isSourceLiveMotionEnabled: Binding<Bool>
    var canPlayLivePreview: Bool = false
    var livePreviewProgress: Double = 0
    var isLivePreviewPlaying: Bool = false
    var onToggleLivePreviewPlayback: () -> Void = {}
}

struct BottomSheetBackgroundControls {
    var extensionRatio: Binding<CGFloat>
    var extensionSide: Binding<PuzzleCanvasExtensionSide>
    var backgroundStyle: Binding<PuzzleBackgroundStyle>
    var backgroundColors: Binding<PuzzleBackgroundColors>
    var backgroundPatternSpacing: Binding<Double>
    var previewImage: UIImage?
}
