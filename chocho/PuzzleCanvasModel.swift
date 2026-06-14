import CoreGraphics
import SwiftUI
import UIKit

nonisolated enum PuzzleCanvasDefaults {
    static let defaultExtensionRatio: CGFloat = 0.15
}

nonisolated enum PuzzleCanvasExtensionSide: String, CaseIterable, Identifiable, Equatable {
    case top
    case bottom
    case left
    case right
    case center

    var id: Self { self }

    var title: String {
        switch self {
        case .top:
            "在上"
        case .bottom:
            "在下"
        case .left:
            "在左"
        case .right:
            "在右"
        case .center:
            "中间"
        }
    }

    var isHorizontal: Bool {
        switch self {
        case .left, .right:
            true
        case .top, .bottom, .center:
            false
        }
    }
}

nonisolated enum PuzzleBackgroundStyle: String, CaseIterable, Identifiable, Equatable {
    case solid
    case grid
    case stripes
    case polkaDots
    case halftone

    var id: Self { self }

    var title: String {
        switch self {
        case .solid:
            "纯色"
        case .grid:
            "方格"
        case .stripes:
            "条纹"
        case .polkaDots:
            "圆点"
        case .halftone:
            "半调"
        }
    }

    var supportsPatternSpacing: Bool {
        switch self {
        case .grid, .stripes, .polkaDots:
            true
        case .solid, .halftone:
            false
        }
    }
}

// MARK: - 实况波点动画
/// 画布波点的预览动画；非「无」时导出为 Live Photo（仅波点动，主图与扩展背景保持静态）。
nonisolated enum LiveDotAnimation: String, CaseIterable, Identifiable, Equatable {
    case none
    case randomBlink
    case breathe
    case rotate

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            "无"
        case .randomBlink:
            "闪烁"
        case .breathe:
            "呼吸"
        case .rotate:
            "旋转"
        }
    }

    /// 是否需要导出配对视频（与菜单项「无」相对）。
    var exportsAsLivePhoto: Bool {
        self != .none
    }

    /// 预览进度条与 Live Photo 视频长度的统一时长。
    var motionExportDuration: TimeInterval {
        switch self {
        case .none:
            0
        case .randomBlink:
            DotRandomBlinkOpacity.exportDuration
        case .breathe:
            DotBreatheAnimation.exportDuration
        case .rotate:
            DotRotateAnimation.exportDuration
        }
    }
}

nonisolated struct DotMotionSample: Equatable {
    let opacity: Double
    let scale: Double
    let rotationRadians: Double

    static let identity = DotMotionSample(opacity: 1, scale: 1, rotationRadians: 0)

    static func sample(
        dotID: UUID,
        liveDotAnimation: LiveDotAnimation,
        time: TimeInterval?
    ) -> DotMotionSample {
        guard let time else { return .identity }

        switch liveDotAnimation {
        case .none:
            return .identity
        case .randomBlink:
            return DotMotionSample(
                opacity: DotRandomBlinkOpacity.opacity(dotID: dotID, time: time),
                scale: 1,
                rotationRadians: 0
            )
        case .breathe:
            let sample = DotBreatheAnimation.sample(dotID: dotID, time: time)
            return DotMotionSample(
                opacity: sample.opacity,
                scale: sample.scale,
                rotationRadians: 0
            )
        case .rotate:
            return DotMotionSample(
                opacity: 1,
                scale: 1,
                rotationRadians: DotRotateAnimation.radians(time: time)
            )
        }
    }
}

/// 「闪烁」：每个波点用独立相位/周期的正弦叠加，导出与预览共用同一公式。
nonisolated enum DotRandomBlinkOpacity {
    static let minimumOpacity: Double = 0.06
    static let maximumOpacity: Double = 1
    static let exportDuration: TimeInterval = 3

    static func opacity(dotID: UUID, time: TimeInterval) -> Double {
        let parameters = blinkParameters(for: dotID)
        let primary = sin(time * parameters.primarySpeed + parameters.primaryPhase)
        let secondary = sin(time * parameters.secondarySpeed + parameters.secondaryPhase)
        let blended = (primary + secondary) * 0.5
        let normalized = (blended + 1) * 0.5
        return minimumOpacity + (maximumOpacity - minimumOpacity) * normalized
    }

    private static func blinkParameters(for dotID: UUID) -> (
        primaryPhase: Double,
        primarySpeed: Double,
        secondaryPhase: Double,
        secondarySpeed: Double
    ) {
        let primaryPeriod = 0.85 + DotAnimationSeed.unit16(dotID, chunk: 0) * 1.35
        let secondaryPeriod = 1.1 + DotAnimationSeed.unit16(dotID, chunk: 1) * 1.6
        return (
            primaryPhase: DotAnimationSeed.unit16(dotID, chunk: 2) * 2 * .pi,
            primarySpeed: (2 * .pi) / primaryPeriod,
            secondaryPhase: DotAnimationSeed.unit16(dotID, chunk: 3) * 2 * .pi,
            secondarySpeed: (2 * .pi) / secondaryPeriod
        )
    }
}

/// 「呼吸」：整体透明度与缩放同步缓动，由 dotID 决定相位偏移。
nonisolated enum DotBreatheAnimation {
    static let minimumOpacity: Double = 0.5
    static let maximumOpacity: Double = 1
    static let minimumScale: Double = 0.78
    static let maximumScale: Double = 1
    static let exportDuration: TimeInterval = 3
    private static let cyclePeriod: TimeInterval = 2.75

    static func sample(dotID: UUID, time: TimeInterval) -> (opacity: Double, scale: Double) {
        let wave = sin((2 * .pi / cyclePeriod) * time + phaseOffset(for: dotID))
        let normalized = (wave + 1) * 0.5
        let eased = normalized * normalized * (3 - 2 * normalized)
        let opacity = minimumOpacity + (maximumOpacity - minimumOpacity) * eased
        let scale = minimumScale + (maximumScale - minimumScale) * eased
        return (opacity, scale)
    }

    private static func phaseOffset(for dotID: UUID) -> Double {
        DotAnimationSeed.unit16(dotID, chunk: 4) * 0.45 * .pi
    }
}

/// 「旋转」：波点围绕自己的中心匀速旋转，大小与透明度保持不变。
nonisolated enum DotRotateAnimation {
    static let exportDuration: TimeInterval = 3

    static func radians(time: TimeInterval) -> Double {
        (2 * .pi / exportDuration) * time
    }
}

private nonisolated enum DotAnimationSeed {
    static func unit16(_ dotID: UUID, chunk: Int) -> Double {
        let bytes = bytes(for: dotID)
        let index = min(max(chunk, 0), 7) * 2
        let value = (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
        return Double(value) / Double(UInt16.max)
    }

    private static func bytes(for dotID: UUID) -> [UInt8] {
        let uuid = dotID.uuid
        return [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15,
        ]
    }
}

struct PuzzleBackgroundColors: Equatable {
    var fillColor: Color
    var alternateColor: Color
    var lineColor: Color

    nonisolated static let `default` = PuzzleBackgroundColors(
        fillColor: .secondary,
        alternateColor: .background,
        lineColor: .border
    )
}

nonisolated struct PuzzleCanvasLayoutResult: Equatable {
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let photoFrame: CGRect
    let extensionFrame: CGRect
    let composedSize: CGSize
    /// 照片 + 最大扩展区域的参考坐标系；波点/轨迹位置在此空间内稳定。
    let referenceComposedFrame: CGRect
    /// 参考系内的照片区域。
    let referenceLocalPhotoFrame: CGRect
    /// 参考系内的扩展背景网格区域。
    let referenceLocalExtensionGridFrame: CGRect

    var backgroundPatternReferenceHeight: CGFloat {
        if extensionSide == .center {
            return referenceLocalExtensionGridFrame.height
        }

        return referenceLocalPhotoFrame.height
    }

    func dotReferenceHeight(forCenterIndex centerIndex: Int) -> CGFloat {
        if extensionSide == .center, centerIndex == 0 {
            return referenceLocalPhotoFrame.height
        }

        return backgroundPatternReferenceHeight
    }

    var visibleComposedFrame: CGRect {
        switch extensionSide {
        case .right:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.minY,
                width: composedSize.width,
                height: referenceComposedFrame.height
            )
        case .left:
            CGRect(
                x: referenceComposedFrame.maxX - composedSize.width,
                y: referenceComposedFrame.minY,
                width: composedSize.width,
                height: referenceComposedFrame.height
            )
        case .bottom:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.minY,
                width: referenceComposedFrame.width,
                height: composedSize.height
            )
        case .top:
            CGRect(
                x: referenceComposedFrame.minX,
                y: referenceComposedFrame.maxY - composedSize.height,
                width: referenceComposedFrame.width,
                height: composedSize.height
            )
        case .center:
            referenceComposedFrame
        }
    }

    var visibleComposedClipAlignment: Alignment {
        switch extensionSide {
        case .right:
            .topLeading
        case .left:
            .topTrailing
        case .bottom:
            .topLeading
        case .top:
            .bottomLeading
        case .center:
            .topLeading
        }
    }

    var visibleComposedClipPosition: CGPoint {
        let frame = visibleComposedFrame
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

nonisolated enum PuzzleCanvasSide: Equatable {
    case photo
    case background
}

nonisolated struct PuzzleCanvasTracePoint: Equatable {
    let side: PuzzleCanvasSide
    let point: CGPoint
    let startsNewStroke: Bool

    init(
        side: PuzzleCanvasSide,
        point: CGPoint,
        startsNewStroke: Bool = false
    ) {
        self.side = side
        self.point = point
        self.startsNewStroke = startsNewStroke
    }
}

enum PuzzleCanvasDragMode: Equatable {
    case viewport
    case trace

    static func current(isTraceDrawingEnabled: Bool) -> PuzzleCanvasDragMode {
        isTraceDrawingEnabled ? .trace : .viewport
    }
}

struct PuzzleCanvasTraceSegment: Equatable {
    let start: CGPoint
    let end: CGPoint

    var length: CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }
}

enum PuzzleCanvasTracePath {
    static func segments(
        from tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat
    ) -> [PuzzleCanvasTraceSegment] {
        var segments: [PuzzleCanvasTraceSegment] = []
        var previousTracePoint: PuzzleCanvasTracePoint?

        for tracePoint in tracePoints {
            if tracePoint.startsNewStroke {
                previousTracePoint = tracePoint
                continue
            }

            if let previousTracePoint,
               previousTracePoint.side == tracePoint.side {
                let segment = PuzzleCanvasTraceSegment(
                    start: previousTracePoint.point,
                    end: tracePoint.point
                )

                if segment.length > 0 {
                    segments.append(segment)
                }
            }

            previousTracePoint = tracePoint
        }

        return segments
    }
}

/// 根据扩展比例与方向计算照片框、扩展条与参考坐标系（预览与 `CanvasRasterExporter` 共用）。
nonisolated enum PuzzleCanvasLayout {
    static let maxExtensionRatio: CGFloat = 1
    static let minimumCenteredPhotoScale: CGFloat = 0.05

    static func layout(
        imageSize: CGSize,
        availableSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide = .right
    ) -> PuzzleCanvasLayoutResult {
        let clampedRatio = min(max(extensionRatio, 0), maxExtensionRatio)

        guard imageSize.width > 0,
              imageSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return PuzzleCanvasLayoutResult(
                extensionRatio: clampedRatio,
                extensionSide: extensionSide,
                photoFrame: .zero,
                extensionFrame: .zero,
                composedSize: .zero,
                referenceComposedFrame: .zero,
                referenceLocalPhotoFrame: .zero,
                referenceLocalExtensionGridFrame: .zero
            )
        }

        if extensionSide == .center {
            return centeredLayout(
                imageSize: imageSize,
                availableSize: availableSize,
                extensionRatio: clampedRatio
            )
        }

        // Photo scale is independent of extension width so existing dots stay fixed on the image.
        let fitScale = min(
            availableSize.width / imageSize.width,
            availableSize.height / imageSize.height
        )
        let photoSize = CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
        let photoOrigin = CGPoint(
            x: (availableSize.width - photoSize.width) / 2,
            y: (availableSize.height - photoSize.height) / 2
        )
        let visibleExtensionLength = extensionSide.isHorizontal
            ? photoSize.width * clampedRatio
            : photoSize.height * clampedRatio
        let maxExtensionLength = extensionSide.isHorizontal
            ? photoSize.width * maxExtensionRatio
            : photoSize.height * maxExtensionRatio
        let referenceComposedSize = extensionSide.isHorizontal
            ? CGSize(
                width: photoSize.width + maxExtensionLength,
                height: photoSize.height
            )
            : CGSize(
                width: photoSize.width,
                height: photoSize.height + maxExtensionLength
            )
        let referenceOrigin = CGPoint(
            x: extensionSide == .left ? photoOrigin.x - maxExtensionLength : photoOrigin.x,
            y: extensionSide == .top ? photoOrigin.y - maxExtensionLength : photoOrigin.y
        )
        let referenceComposedFrame = CGRect(
            origin: referenceOrigin,
            size: referenceComposedSize
        )
        let referenceLocalPhotoFrame = CGRect(
            origin: CGPoint(
                x: extensionSide == .left ? maxExtensionLength : 0,
                y: extensionSide == .top ? maxExtensionLength : 0
            ),
            size: photoSize
        )
        let referenceLocalExtensionGridFrame = CGRect(
            origin: CGPoint(
                x: extensionSide == .right ? photoSize.width : 0,
                y: extensionSide == .bottom ? photoSize.height : 0
            ),
            size: CGSize(
                width: extensionSide.isHorizontal ? maxExtensionLength : photoSize.width,
                height: extensionSide.isHorizontal ? photoSize.height : maxExtensionLength
            )
        )
        let extensionFrame = extensionFrameInScreenSpace(
            photoOrigin: photoOrigin,
            photoSize: photoSize,
            visibleExtensionLength: visibleExtensionLength,
            extensionSide: extensionSide
        )
        let composedSize = extensionSide.isHorizontal
            ? CGSize(width: photoSize.width + visibleExtensionLength, height: photoSize.height)
            : CGSize(width: photoSize.width, height: photoSize.height + visibleExtensionLength)

        return PuzzleCanvasLayoutResult(
            extensionRatio: clampedRatio,
            extensionSide: extensionSide,
            photoFrame: CGRect(origin: photoOrigin, size: photoSize),
            extensionFrame: extensionFrame,
            composedSize: composedSize,
            referenceComposedFrame: referenceComposedFrame,
            referenceLocalPhotoFrame: referenceLocalPhotoFrame,
            referenceLocalExtensionGridFrame: referenceLocalExtensionGridFrame
        )
    }

    private static func extensionFrameInScreenSpace(
        photoOrigin: CGPoint,
        photoSize: CGSize,
        visibleExtensionLength: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGRect {
        switch extensionSide {
        case .right:
            CGRect(
                x: photoOrigin.x + photoSize.width,
                y: photoOrigin.y,
                width: visibleExtensionLength,
                height: photoSize.height
            )
        case .left:
            CGRect(
                x: photoOrigin.x - visibleExtensionLength,
                y: photoOrigin.y,
                width: visibleExtensionLength,
                height: photoSize.height
            )
        case .bottom:
            CGRect(
                x: photoOrigin.x,
                y: photoOrigin.y + photoSize.height,
                width: photoSize.width,
                height: visibleExtensionLength
            )
        case .top:
            CGRect(
                x: photoOrigin.x,
                y: photoOrigin.y - visibleExtensionLength,
                width: photoSize.width,
                height: visibleExtensionLength
            )
        case .center:
            CGRect(origin: photoOrigin, size: photoSize)
        }
    }

    private static func centeredLayout(
        imageSize: CGSize,
        availableSize: CGSize,
        extensionRatio: CGFloat
    ) -> PuzzleCanvasLayoutResult {
        let backgroundScale = min(
            availableSize.width / imageSize.width,
            availableSize.height / imageSize.height
        )
        let backgroundSize = CGSize(
            width: imageSize.width * backgroundScale,
            height: imageSize.height * backgroundScale
        )
        let backgroundOrigin = CGPoint(
            x: (availableSize.width - backgroundSize.width) / 2,
            y: (availableSize.height - backgroundSize.height) / 2
        )
        let photoScale = max(1 - extensionRatio, minimumCenteredPhotoScale)
        let photoSize = CGSize(
            width: backgroundSize.width * photoScale,
            height: backgroundSize.height * photoScale
        )
        let photoOrigin = CGPoint(
            x: backgroundOrigin.x + (backgroundSize.width - photoSize.width) / 2,
            y: backgroundOrigin.y + (backgroundSize.height - photoSize.height) / 2
        )
        let backgroundFrame = CGRect(origin: backgroundOrigin, size: backgroundSize)
        let localPhotoFrame = CGRect(
            origin: CGPoint(
                x: (backgroundSize.width - photoSize.width) / 2,
                y: (backgroundSize.height - photoSize.height) / 2
            ),
            size: photoSize
        )
        let localBackgroundFrame = CGRect(origin: .zero, size: backgroundSize)

        return PuzzleCanvasLayoutResult(
            extensionRatio: extensionRatio,
            extensionSide: .center,
            photoFrame: CGRect(origin: photoOrigin, size: photoSize),
            extensionFrame: backgroundFrame,
            composedSize: backgroundSize,
            referenceComposedFrame: backgroundFrame,
            referenceLocalPhotoFrame: localPhotoFrame,
            referenceLocalExtensionGridFrame: localBackgroundFrame
        )
    }
}

struct CanvasViewportResetKey: Equatable {
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let imageViewportResetID: UUID
}

nonisolated enum CharacterDotText {
    static let shapeName = "字符"
    static let defaultText = "字"

    static func displayText(for text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? defaultText : trimmedText
    }
}

enum PuzzleCanvasViewport {
    /// Target width fraction for interactive viewport reset (double-tap / layout change).
    static let resetViewportWidthFraction: CGFloat = 0.9

    /// Fits the visible photo + background width to the viewport and centers vertically.
    /// Horizontally centers when `targetViewportWidthFraction` is less than 1.
    /// Matches `PuzzleCanvasCoordinate` viewport transform: scale about available center, then offset.
    static func resetTransform(
        layout: PuzzleCanvasLayoutResult,
        availableSize: CGSize,
        bottomPanelInset: CGFloat = 0,
        targetViewportWidthFraction: CGFloat = resetViewportWidthFraction
    ) -> (scale: CGFloat, offset: CGSize) {
        let visibleFrame = layout.visibleComposedFrame

        guard visibleFrame.width > 0,
              visibleFrame.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return (1, .zero)
        }

        let clampedBottomInset = min(
            max(bottomPanelInset, 0),
            max(availableSize.height - 1, 0)
        )
        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )
        let targetCenterY = (availableSize.height - clampedBottomInset) / 2
        let clampedWidthFraction = min(max(targetViewportWidthFraction, 0), 1)
        let targetWidth = availableSize.width * clampedWidthFraction
        let scale = targetWidth / visibleFrame.width
        var offset = CGSize(
            width: -viewportCenter.x - (visibleFrame.minX - viewportCenter.x) * scale,
            height: targetCenterY
                - viewportCenter.y
                - (visibleFrame.midY - viewportCenter.y) * scale
        )
        if clampedWidthFraction < 1 {
            let horizontalInset = (availableSize.width - visibleFrame.width * scale) / 2
            offset.width += horizontalInset
        }

        return (scale, offset)
    }

    /// Fraction of bottom-panel expand/collapse height used for canvas dodge.
    /// Smaller than full re-centering so the canvas nudges without tracking panel travel 1:1.
    static let panelExpansionDodgeFraction: CGFloat = 0.32

    /// Live offset that keeps the composed canvas shifted above the current bottom panel height.
    /// Applied at render time so content tracks panel resize animations frame-by-frame.
    static func panelTrackingOffset(
        layout: PuzzleCanvasLayoutResult,
        availableSize: CGSize,
        bottomPanelInset: CGFloat
    ) -> CGSize {
        let clampedInset = min(
            max(bottomPanelInset, 0),
            max(availableSize.height - 1, 0)
        )
        let baseline = resetTransform(
            layout: layout,
            availableSize: availableSize,
            bottomPanelInset: 0
        )
        let adjusted = resetTransform(
            layout: layout,
            availableSize: availableSize,
            bottomPanelInset: clampedInset
        )
        return CGSize(
            width: adjusted.offset.width - baseline.offset.width,
            height: adjusted.offset.height - baseline.offset.height
        )
    }

    static let minScale: CGFloat = 0.4
    static let maxScale: CGFloat = 6

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    /// Keeps the canvas point under `anchor` fixed while multiplying scale by `scaleMultiplier`.
    /// Matches `PuzzleCanvasCoordinate` transform: scale about available center, then offset.
    static func adjustedOffset(
        anchor: CGPoint,
        availableSize: CGSize,
        scaleMultiplier: CGFloat,
        baseOffset: CGSize
    ) -> CGSize {
        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )

        return CGSize(
            width: anchor.x - viewportCenter.x
                - (anchor.x - baseOffset.width - viewportCenter.x) * scaleMultiplier,
            height: anchor.y - viewportCenter.y
                - (anchor.y - baseOffset.height - viewportCenter.y) * scaleMultiplier
        )
    }
}

enum PuzzleCanvasExport {
    static func viewportTransform(
        imageSize: CGSize,
        exportSize: CGSize,
        extensionRatio: CGFloat,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> (scale: CGFloat, offset: CGSize) {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: exportSize,
            extensionRatio: extensionRatio,
            extensionSide: extensionSide
        )

        return PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: exportSize,
            targetViewportWidthFraction: 1
        )
    }
}

nonisolated enum PuzzleCanvasCoordinate {
    static func isBackgroundTap(
        at location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> Bool {
        normalizedPoint(
            for: location,
            availableSize: availableSize,
            layout: layout,
            scale: scale,
            offset: offset
        ) == nil
    }

    static func canvasLocation(
        for location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> PuzzleCanvasTracePoint? {
        guard let unscaledLocation = unscaledLocation(
            for: location,
            availableSize: availableSize,
            scale: scale,
            offset: offset
        ) else {
            return nil
        }

        if layout.photoFrame.contains(unscaledLocation),
           layout.photoFrame.width > 0,
           layout.photoFrame.height > 0 {
            return PuzzleCanvasTracePoint(
                side: .photo,
                point: CGPoint(
                    x: (unscaledLocation.x - layout.photoFrame.minX) / layout.photoFrame.width,
                    y: (unscaledLocation.y - layout.photoFrame.minY) / layout.photoFrame.height
                )
            )
        }

        if layout.extensionFrame.contains(unscaledLocation),
           layout.extensionFrame.width > 0,
           layout.extensionFrame.height > 0,
           layout.photoFrame.width > 0,
           layout.photoFrame.height > 0 {
            return PuzzleCanvasTracePoint(
                side: .background,
                point: backgroundLocalPoint(
                    unscaledLocation: unscaledLocation,
                    layout: layout
                )
            )
        }

        return nil
    }

    /// Background-local coordinates match the right-side baseline: 0 on the edge that touches the photo,
    /// increasing away from the photo (right / left / down / up depending on `extensionSide`).
    static func backgroundLocalPoint(
        unscaledLocation: CGPoint,
        layout: PuzzleCanvasLayoutResult
    ) -> CGPoint {
        let extensionFrame = layout.extensionFrame
        let photoFrame = layout.photoFrame

        switch layout.extensionSide {
        case .right:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .left:
            return CGPoint(
                x: (extensionFrame.maxX - unscaledLocation.x) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .bottom:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / photoFrame.height
            )
        case .top:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / photoFrame.width,
                y: (extensionFrame.maxY - unscaledLocation.y) / photoFrame.height
            )
        case .center:
            return CGPoint(
                x: (unscaledLocation.x - extensionFrame.minX) / extensionFrame.width,
                y: (unscaledLocation.y - extensionFrame.minY) / extensionFrame.height
            )
        }
    }

    static func normalizedPoint(
        for location: CGPoint,
        availableSize: CGSize,
        layout: PuzzleCanvasLayoutResult,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint? {
        guard scale > 0,
              availableSize.width > 0,
              availableSize.height > 0,
              layout.composedSize.width > 0,
              layout.composedSize.height > 0 else {
            return nil
        }

        guard let unscaledLocation = unscaledLocation(
            for: location,
            availableSize: availableSize,
            scale: scale,
            offset: offset
        ) else {
            return nil
        }
        let visibleFrame = layout.visibleComposedFrame

        guard visibleFrame.contains(unscaledLocation) else { return nil }

        let referenceFrame = layout.referenceComposedFrame
        guard referenceFrame.width > 0, referenceFrame.height > 0 else { return nil }

        return CGPoint(
            x: (unscaledLocation.x - referenceFrame.minX) / referenceFrame.width,
            y: (unscaledLocation.y - referenceFrame.minY) / referenceFrame.height
        )
    }

    static func composedPosition(
        for tracePoint: PuzzleCanvasTracePoint,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio
    ) -> CGPoint? {
        let clampedRatio = min(max(maxExtensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        let photoSpan = 1 / (1 + clampedRatio)
        let extensionSpan = clampedRatio / (1 + clampedRatio)

        switch tracePoint.side {
        case .photo:
            switch extensionSide {
            case .right:
                return CGPoint(
                    x: tracePoint.point.x * photoSpan,
                    y: tracePoint.point.y
                )
            case .left:
                return CGPoint(
                    x: extensionSpan + tracePoint.point.x * photoSpan,
                    y: tracePoint.point.y
                )
            case .bottom:
                return CGPoint(
                    x: tracePoint.point.x,
                    y: tracePoint.point.y * photoSpan
                )
            case .top:
                return CGPoint(
                    x: tracePoint.point.x,
                    y: extensionSpan + tracePoint.point.y * photoSpan
                )
            case .center:
                let photoScale = max(1 - clampedRatio, PuzzleCanvasLayout.minimumCenteredPhotoScale)
                let inset = (1 - photoScale) / 2
                return CGPoint(
                    x: inset + tracePoint.point.x * photoScale,
                    y: inset + tracePoint.point.y * photoScale
                )
            }
        case .background:
            guard clampedRatio > 0 else { return nil }

            switch extensionSide {
            case .right:
                guard tracePoint.point.x >= 0, tracePoint.point.x <= clampedRatio else { return nil }
                return CGPoint(
                    x: photoSpan + tracePoint.point.x / (1 + clampedRatio),
                    y: tracePoint.point.y
                )
            case .left:
                guard tracePoint.point.x >= 0, tracePoint.point.x <= clampedRatio else { return nil }
                return CGPoint(
                    x: extensionSpan - tracePoint.point.x / (1 + clampedRatio),
                    y: tracePoint.point.y
                )
            case .bottom:
                guard tracePoint.point.y >= 0, tracePoint.point.y <= clampedRatio else { return nil }
                return CGPoint(
                    x: tracePoint.point.x,
                    y: photoSpan + tracePoint.point.y / (1 + clampedRatio)
                )
            case .top:
                guard tracePoint.point.y >= 0, tracePoint.point.y <= clampedRatio else { return nil }
                return CGPoint(
                    x: tracePoint.point.x,
                    y: extensionSpan - tracePoint.point.y / (1 + clampedRatio)
                )
            case .center:
                guard 0...1 ~= tracePoint.point.x,
                      0...1 ~= tracePoint.point.y else { return nil }
                return tracePoint.point
            }
        }
    }

    /// Converts a tap on the photo or extension into the normalized photo-space dot position.
    static func dotPosition(
        for canvasLocation: PuzzleCanvasTracePoint,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGPoint {
        switch canvasLocation.side {
        case .photo:
            return canvasLocation.point
        case .background:
            return photoDotPosition(
                fromBackgroundLocal: canvasLocation.point,
                extensionSide: extensionSide
            )
        }
    }

    /// Inverts the mirror mapping used by `dotCentersInReferenceFrame` for extension taps.
    static func photoDotPosition(
        fromBackgroundLocal background: CGPoint,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGPoint {
        switch extensionSide {
        case .right, .bottom:
            return background
        case .left:
            return CGPoint(x: 1 - background.x, y: background.y)
        case .top:
            return CGPoint(x: background.x, y: 1 - background.y)
        case .center:
            return background
        }
    }

    /// Renders dots in the fixed reference canvas; narrowing extension only clips them.
    static func dotCenters(
        for position: CGPoint,
        in layout: PuzzleCanvasLayoutResult
    ) -> [CGPoint] {
        dotCentersInReferenceFrame(
            position: position,
            referenceFrame: CGRect(origin: .zero, size: layout.referenceComposedFrame.size),
            extensionSide: layout.extensionSide,
            maxExtensionRatio: layout.extensionSide == .center
                ? layout.extensionRatio
                : PuzzleCanvasLayout.maxExtensionRatio
        )
    }

    /// Renders dots in the fixed reference canvas; narrowing extension only clips them.
    static func dotCentersInReferenceFrame(
        position: CGPoint,
        referenceFrame: CGRect,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio
    ) -> [CGPoint] {
        let clampedMaxRatio = min(max(maxExtensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        guard referenceFrame.width > 0, referenceFrame.height > 0 else { return [] }

        let photoSpan = 1 / (1 + clampedMaxRatio)
        let extensionSpan = clampedMaxRatio / (1 + clampedMaxRatio)
        let photoFrame: CGRect
        let mirrorFrame: CGRect
        let mirrorPosition = PuzzleDotCollageColor.referenceExtensionMirrorPosition(
            forPhotoPosition: position,
            extensionSide: extensionSide
        )

        switch extensionSide {
        case .right:
            let photoWidth = referenceFrame.width * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: photoWidth,
                height: referenceFrame.height
            )
            mirrorFrame = CGRect(
                x: photoFrame.maxX,
                y: photoFrame.minY,
                width: referenceFrame.width * extensionSpan,
                height: referenceFrame.height
            )
        case .left:
            let photoWidth = referenceFrame.width * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX + referenceFrame.width * extensionSpan,
                y: referenceFrame.minY,
                width: photoWidth,
                height: referenceFrame.height
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width * extensionSpan,
                height: referenceFrame.height
            )
        case .bottom:
            let photoHeight = referenceFrame.height * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width,
                height: photoHeight
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: photoFrame.maxY,
                width: referenceFrame.width,
                height: referenceFrame.height * extensionSpan
            )
        case .top:
            let photoHeight = referenceFrame.height * photoSpan
            photoFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY + referenceFrame.height * extensionSpan,
                width: referenceFrame.width,
                height: photoHeight
            )
            mirrorFrame = CGRect(
                x: referenceFrame.minX,
                y: referenceFrame.minY,
                width: referenceFrame.width,
                height: referenceFrame.height * extensionSpan
            )
        case .center:
            let photoScale = max(1 - clampedMaxRatio, PuzzleCanvasLayout.minimumCenteredPhotoScale)
            let photoSize = CGSize(
                width: referenceFrame.width * photoScale,
                height: referenceFrame.height * photoScale
            )
            photoFrame = CGRect(
                x: referenceFrame.midX - photoSize.width / 2,
                y: referenceFrame.midY - photoSize.height / 2,
                width: photoSize.width,
                height: photoSize.height
            )
            mirrorFrame = referenceFrame
        }

        var centers = [
            dotCenter(
                position: position,
                in: photoFrame
            )
        ]

        guard clampedMaxRatio > 0 else { return centers }

        centers.append(
            dotCenter(
                position: mirrorPosition,
                in: mirrorFrame
            )
        )

        return centers
    }

    static func composedCanvasPoint(
        for tracePoint: PuzzleCanvasTracePoint,
        canvasSize: CGSize,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        maxExtensionRatio: CGFloat = PuzzleCanvasLayout.maxExtensionRatio
    ) -> CGPoint? {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              let position = composedPosition(
                for: tracePoint,
                extensionSide: extensionSide,
                maxExtensionRatio: maxExtensionRatio
              ) else {
            return nil
        }

        return CGPoint(
            x: position.x * canvasSize.width,
            y: position.y * canvasSize.height
        )
    }

    static func composedCanvasPoint(
        for tracePoint: PuzzleCanvasTracePoint,
        in layout: PuzzleCanvasLayoutResult
    ) -> CGPoint? {
        switch tracePoint.side {
        case .photo:
            let frame = layout.referenceLocalPhotoFrame
            guard frame.width > 0, frame.height > 0 else { return nil }

            return CGPoint(
                x: frame.minX + tracePoint.point.x * frame.width,
                y: frame.minY + tracePoint.point.y * frame.height
            )
        case .background:
            return composedBackgroundCanvasPoint(
                tracePoint.point,
                in: layout
            )
        }
    }

    private static func composedBackgroundCanvasPoint(
        _ point: CGPoint,
        in layout: PuzzleCanvasLayoutResult
    ) -> CGPoint? {
        let frame = layout.referenceLocalExtensionGridFrame
        let photoFrame = layout.referenceLocalPhotoFrame
        guard frame.width > 0,
              frame.height > 0,
              photoFrame.width > 0,
              photoFrame.height > 0 else {
            return nil
        }

        switch layout.extensionSide {
        case .right, .bottom:
            return CGPoint(
                x: frame.minX + point.x * photoFrame.width,
                y: frame.minY + point.y * photoFrame.height
            )
        case .left:
            return CGPoint(
                x: frame.maxX - point.x * photoFrame.width,
                y: frame.minY + point.y * photoFrame.height
            )
        case .top:
            return CGPoint(
                x: frame.minX + point.x * photoFrame.width,
                y: frame.maxY - point.y * photoFrame.height
            )
        case .center:
            return CGPoint(
                x: frame.minX + point.x * frame.width,
                y: frame.minY + point.y * frame.height
            )
        }
    }

    /// Maps a normalized dot position to a fixed center in `composedFrame`.
    /// Size changes scale about this center; overflow is clipped by the canvas.
    static func dotCenter(
        position: CGPoint,
        in composedFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: composedFrame.minX + position.x * composedFrame.width,
            y: composedFrame.minY + position.y * composedFrame.height
        )
    }

    private static func unscaledLocation(
        for location: CGPoint,
        availableSize: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint? {
        guard scale > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return nil
        }

        let viewportCenter = CGPoint(
            x: availableSize.width / 2,
            y: availableSize.height / 2
        )

        return CGPoint(
            x: viewportCenter.x + (location.x - offset.width - viewportCenter.x) / scale,
            y: viewportCenter.y + (location.y - offset.height - viewportCenter.y) / scale
        )
    }
}

nonisolated enum DotSizeControl {
    static let minControlValue: Double = 1
    static let maxControlValue: Double = 100
    static let minRenderedScale: Double = 8
    static let maxRenderedScale: Double = 100
    /// Keeps default on-screen dot size near the previous 8…40 scale at control 23.
    static let defaultControlValue: Double = 9
    static let defaultRenderedScale = renderedScale(forControlValue: defaultControlValue)
    /// Matches a typical on-screen photo height so slider values stay intuitive.
    static let referencePhotoHeight: CGFloat = 240

    static func displaySize(renderedScale: CGFloat, photoFrameHeight: CGFloat) -> CGFloat {
        guard referencePhotoHeight > 0, photoFrameHeight > 0 else {
            return renderedScale
        }

        return renderedScale * (photoFrameHeight / referencePhotoHeight)
    }

    static func renderedScale(forControlValue value: Double) -> Double {
        let clampedValue = min(max(value, minControlValue), maxControlValue)
        let progress = (clampedValue - minControlValue) / (maxControlValue - minControlValue)

        return minRenderedScale + progress * (maxRenderedScale - minRenderedScale)
    }

    static func controlValue(forRenderedScale scale: Double) -> Double {
        let clampedScale = min(max(scale, minRenderedScale), maxRenderedScale)
        let progress = (clampedScale - minRenderedScale) / (maxRenderedScale - minRenderedScale)

        return minControlValue + progress * (maxControlValue - minControlValue)
    }
}

nonisolated enum PuzzleBackgroundGridMetrics {
    private static let referenceSpacing: CGFloat = CGFloat(PuzzleBackgroundPatternSpacing.defaultControlValue)
    private static let referenceLineWidth: CGFloat = 1

    static func spacing(photoFrameHeight: CGFloat) -> CGFloat {
        PuzzleBackgroundPatternSpacing.renderedSpacing(
            controlValue: Double(referenceSpacing),
            photoFrameHeight: photoFrameHeight
        )
    }

    static func spacing(controlValue: Double, photoFrameHeight: CGFloat) -> CGFloat {
        PuzzleBackgroundPatternSpacing.renderedSpacing(
            controlValue: controlValue,
            photoFrameHeight: photoFrameHeight
        )
    }

    static func lineWidth(photoFrameHeight: CGFloat) -> CGFloat {
        scaledMetric(referenceLineWidth, photoFrameHeight: photoFrameHeight)
    }

    private static func scaledMetric(
        _ value: CGFloat,
        photoFrameHeight: CGFloat
    ) -> CGFloat {
        guard DotSizeControl.referencePhotoHeight > 0,
              photoFrameHeight > 0 else {
            return value
        }

        return value * (photoFrameHeight / DotSizeControl.referencePhotoHeight)
    }
}

nonisolated enum PuzzleBackgroundPolkaDotMetrics {
    private static let tileSpacingMultiplier: CGFloat = 2

    static func dotDiameter(controlValue: Double, photoFrameHeight: CGFloat) -> CGFloat {
        PuzzleBackgroundPatternSpacing.renderedSpacing(
            controlValue: controlValue,
            photoFrameHeight: photoFrameHeight
        )
    }

    static func tileSpacing(controlValue: Double, photoFrameHeight: CGFloat) -> CGFloat {
        dotDiameter(
            controlValue: controlValue,
            photoFrameHeight: photoFrameHeight
        ) * tileSpacingMultiplier
    }

    static func containsDot(
        point: CGPoint,
        controlValue: Double,
        photoFrameHeight: CGFloat
    ) -> Bool {
        let spacing = tileSpacing(controlValue: controlValue, photoFrameHeight: photoFrameHeight)
        let radius = dotDiameter(controlValue: controlValue, photoFrameHeight: photoFrameHeight) / 2
        guard spacing > 0, radius > 0 else { return false }

        let center = spacing / 2
        let localX = point.x.truncatingRemainder(dividingBy: spacing)
        let localY = point.y.truncatingRemainder(dividingBy: spacing)
        let distance = hypot(localX - center, localY - center)
        return distance <= radius
    }

    static func dotRects(
        in size: CGSize,
        controlValue: Double,
        photoFrameHeight: CGFloat
    ) -> [CGRect] {
        let diameter = dotDiameter(
            controlValue: controlValue,
            photoFrameHeight: photoFrameHeight
        )
        let spacing = tileSpacing(
            controlValue: controlValue,
            photoFrameHeight: photoFrameHeight
        )
        guard spacing > 0, diameter > 0 else { return [] }

        let radius = diameter / 2
        var rects: [CGRect] = []
        var y = spacing / 2
        while y - radius <= size.height {
            var x = spacing / 2
            while x - radius <= size.width {
                rects.append(CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: diameter,
                    height: diameter
                ))
                x += spacing
            }
            y += spacing
        }
        return rects
    }
}

nonisolated enum PuzzleBackgroundPatternSpacing {
    static let minControlValue: Double = 6
    static let maxControlValue: Double = 36
    static let defaultControlValue: Double = 12
    static let step: Double = 1

    static func renderedSpacing(controlValue: Double, photoFrameHeight: CGFloat) -> CGFloat {
        let clampedValue = min(max(controlValue, minControlValue), maxControlValue)
        guard DotSizeControl.referencePhotoHeight > 0,
              photoFrameHeight > 0 else {
            return CGFloat(clampedValue)
        }

        return CGFloat(clampedValue) * (photoFrameHeight / DotSizeControl.referencePhotoHeight)
    }
}

enum PuzzleCanvasUploadDefaults {
    static let dotShapeName = BuiltInDotShape.snow.rawValue
    static let dotScaleControlValue: Double = 10
    static let dotScale = DotSizeControl.renderedScale(forControlValue: dotScaleControlValue)

    static func initialDots(
        dotCount: Double,
        shapeAssetName: String = dotShapeName
    ) -> [PuzzleDot] {
        PuzzleDotFactory.makeDots(
            count: Int(dotCount.rounded()),
            shapeAssetName: shapeAssetName
        )
    }
}

struct CanvasHistory<Value: Equatable> {
    private(set) var currentValue: Value
    private var undoStack: [Value] = []
    private var redoStack: [Value] = []

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    init(initialValue: Value) {
        currentValue = initialValue
    }

    mutating func reset(to value: Value) {
        currentValue = value
        undoStack = []
        redoStack = []
    }

    mutating func record(_ value: Value) {
        guard value != currentValue else { return }

        undoStack.append(currentValue)
        currentValue = value
        redoStack = []
    }

    mutating func undo() -> Value? {
        guard let previousValue = undoStack.popLast() else { return nil }

        redoStack.append(currentValue)
        currentValue = previousValue
        return previousValue
    }

    mutating func redo() -> Value? {
        guard let nextValue = redoStack.popLast() else { return nil }

        undoStack.append(currentValue)
        currentValue = nextValue
        return nextValue
    }
}

extension CanvasHistory where Value: RangeReplaceableCollection {
    mutating func clearValue() -> Value {
        record(Value())
        return currentValue
    }
}

nonisolated struct PuzzleDot: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let color: Color
    let size: CGFloat
    let shapeAssetName: String

    var usesTemplateColor: Bool {
        DotShapeAssetCategoryParser.suffix(in: shapeAssetName) == nil
    }

    /// Category-suffixed asset dots (e.g. `鱼1.纽扣`) render 25% larger than basic dots.
    var displaySizeScale: CGFloat {
        DotShapeAssetCategoryParser.suffix(in: shapeAssetName) == nil ? 1 : 1.25
    }

    var builtInShape: BuiltInDotShape? {
        BuiltInDotShape(rawValue: shapeAssetName)
    }

    var isCharacterDot: Bool {
        shapeAssetName == CharacterDotText.shapeName
    }

    /// Built-in geometry and basic catalog SVG shapes use mirror collage tinting.
    var supportsCollageTinting: Bool {
        if isCharacterDot { return true }
        if builtInShape != nil { return true }
        return usesTemplateColor && DotShapeCatalog.assetNames.contains(shapeAssetName)
    }

    func displayColor(usesRandomColor: Bool, selectedColor: Color) -> Color {
        usesRandomColor ? color : selectedColor
    }
}

/// Default dot tinting: each copy samples the mirrored region on the opposite layer.
nonisolated enum PuzzleDotCollageColor {
    private static let fallbackPrimary = Color(.sRGB, red: 165 / 255, green: 231 / 255, blue: 76 / 255, opacity: 1)
    static func extensionMirrorPosition(
        forPhotoPosition position: CGPoint,
        extensionSide: PuzzleCanvasExtensionSide,
        extensionRatio: CGFloat
    ) -> CGPoint {
        let clampedRatio = min(max(extensionRatio, 0), PuzzleCanvasLayout.maxExtensionRatio)
        let divisor = max(clampedRatio, .leastNonzeroMagnitude)

        switch extensionSide {
        case .right, .left:
            return CGPoint(
                x: position.x / divisor,
                y: position.y
            )
        case .bottom, .top:
            return CGPoint(
                x: position.x,
                y: position.y / divisor
            )
        case .center:
            return position
        }
    }

    /// Mirror position in the full reference extension grid (stable when visible extension is cropped).
    static func referenceExtensionMirrorPosition(
        forPhotoPosition position: CGPoint,
        extensionSide: PuzzleCanvasExtensionSide
    ) -> CGPoint {
        extensionMirrorPosition(
            forPhotoPosition: position,
            extensionSide: extensionSide,
            extensionRatio: PuzzleCanvasLayout.maxExtensionRatio
        )
    }

    /// Transparent dot color means mirror collage; any opaque pick uses flat tint instead.
    static func usesCollageTint(selectedDotColor: Color) -> Bool {
        var alpha: CGFloat = 0
        UIColor(selectedDotColor).getWhite(nil, alpha: &alpha)
        return alpha < 0.01
    }

    static func shouldRenderCollageContent(
        for dot: PuzzleDot,
        usesRandomDotColors: Bool,
        extensionRatio: CGFloat,
        selectedDotColor: Color
    ) -> Bool {
        dot.supportsCollageTinting
            && !usesRandomDotColors
            && usesCollageTint(selectedDotColor: selectedDotColor)
    }

    static func clampedExtensionSamplePoint(_ mirrorPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(mirrorPosition.x, 0), 1),
            y: min(max(mirrorPosition.y, 0), 1)
        )
    }

    static func contentOffsetInDot(
        dotSize: CGFloat,
        normalizedPoint: CGPoint,
        contentSize: CGSize
    ) -> CGSize {
        CGSize(
            width: dotSize / 2 - normalizedPoint.x * contentSize.width,
            height: dotSize / 2 - normalizedPoint.y * contentSize.height
        )
    }

    static func displayColor(
        for dot: PuzzleDot,
        centerIndex: Int,
        layout: PuzzleCanvasLayoutResult,
        image: UIImage,
        backgroundStyle: PuzzleBackgroundStyle,
        backgroundColors: PuzzleBackgroundColors = .default,
        backgroundPatternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue,
        usesRandomDotColors: Bool,
        selectedDotColor: Color
    ) -> Color {
        if usesRandomDotColors {
            return dot.displayColor(usesRandomColor: true, selectedColor: selectedDotColor)
        }

        guard dot.supportsCollageTinting,
              usesCollageTint(selectedDotColor: selectedDotColor) else {
            return selectedDotColor
        }

        let mirrorPosition = referenceExtensionMirrorPosition(
            forPhotoPosition: dot.position,
            extensionSide: layout.extensionSide
        )
        let extensionFrame = layout.referenceLocalExtensionGridFrame

        switch centerIndex {
        case 0:
            return backgroundColor(
                at: mirrorPosition,
                style: backgroundStyle,
                colors: backgroundColors,
                patternSpacing: backgroundPatternSpacing,
                extensionSize: extensionFrame.size,
                photoFrameHeight: layout.backgroundPatternReferenceHeight,
                extensionRatio: layout.extensionRatio,
                extensionSide: layout.extensionSide,
                sourceImage: image
            )
        default:
            return imageColor(at: dot.position, image: image)
        }
    }

    static func imageColor(at normalizedPoint: CGPoint, image: UIImage) -> Color {
        guard let cgImage = image.cgImage else { return fallbackPrimary }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return fallbackPrimary }

        let u = min(max(normalizedPoint.x, 0), 1)
        let v = min(max(normalizedPoint.y, 0), 1)
        let x = min(width - 1, max(0, Int((CGFloat(width) * u).rounded(.down))))
        let y = min(height - 1, max(0, Int((CGFloat(height) * v).rounded(.down))))

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return fallbackPrimary
        }

        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 4)
        let offset = y * cgImage.bytesPerRow + x * bytesPerPixel

        return Color(
            .sRGB,
            red: Double(bytes[offset]) / 255,
            green: Double(bytes[offset + 1]) / 255,
            blue: Double(bytes[offset + 2]) / 255,
            opacity: 1
        )
    }

    static func backgroundColor(
        at normalizedPoint: CGPoint,
        style: PuzzleBackgroundStyle,
        colors: PuzzleBackgroundColors = .default,
        patternSpacing: Double = PuzzleBackgroundPatternSpacing.defaultControlValue,
        extensionSize: CGSize,
        photoFrameHeight: CGFloat,
        extensionRatio: CGFloat = 0,
        extensionSide: PuzzleCanvasExtensionSide = .right,
        sourceImage: UIImage? = nil
    ) -> Color {
        guard extensionSize.width > 0, extensionSize.height > 0 else {
            return colors.fillColor
        }

        let u = min(max(normalizedPoint.x, 0), 1)
        let v = min(max(normalizedPoint.y, 0), 1)
        let point = CGPoint(
            x: u * extensionSize.width,
            y: v * extensionSize.height
        )
        let spacing = PuzzleBackgroundGridMetrics.spacing(
            controlValue: patternSpacing,
            photoFrameHeight: photoFrameHeight
        )
        let lineWidth = PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: photoFrameHeight)

        switch style {
        case .solid:
            return colors.fillColor
        case .grid:
            let nearestVerticalDistance = distanceToGridLine(
                coordinate: point.x,
                spacing: spacing
            )
            let nearestHorizontalDistance = distanceToGridLine(
                coordinate: point.y,
                spacing: spacing
            )
            let nearestGridDistance = min(nearestVerticalDistance, nearestHorizontalDistance)

            if nearestGridDistance <= lineWidth / 2 {
                return colors.lineColor
            }
            return colors.fillColor
        case .stripes:
            let bandIndex = Int(point.y / spacing)
            return bandIndex.isMultiple(of: 2) ? colors.fillColor : colors.alternateColor
        case .polkaDots:
            return PuzzleBackgroundPolkaDotMetrics.containsDot(
                point: point,
                controlValue: patternSpacing,
                photoFrameHeight: photoFrameHeight
            ) ? colors.lineColor : colors.fillColor
        case .halftone:
            guard let sourceImage else {
                return colors.fillColor
            }
            let renderPixelSize = PuzzleHalftoneBackgroundMetrics.fullExtensionPixelSize(
                imagePixelSize: CanvasImageLoader.pixelSize(for: sourceImage),
                extensionSide: extensionSide
            )
            guard let surface = PuzzleHalftoneBackgroundRenderer.render(
                sourceImage: sourceImage,
                renderPixelSize: renderPixelSize,
                backgroundColor: colors.fillColor,
                dotColor: colors.lineColor
            ) else {
                return colors.fillColor
            }
            let fullSamplePoint = PuzzleHalftoneBackgroundMetrics.mapVisiblePointToFullExtension(
                normalizedPoint,
                extensionRatio: extensionRatio,
                extensionSide: extensionSide
            )
            return PuzzleHalftoneBackgroundRenderer.color(
                at: fullSamplePoint,
                surface: surface,
                fallback: colors.fillColor
            )
        }
    }

    private static func distanceToGridLine(coordinate: CGFloat, spacing: CGFloat) -> CGFloat {
        guard spacing > 0 else { return .greatestFiniteMagnitude }

        let remainder = coordinate.truncatingRemainder(dividingBy: spacing)
        return min(remainder, spacing - remainder)
    }
}

nonisolated enum DotColorPickerSelection {
    static let fallbackPickerColor = Color.black

    static func pickerColor(
        for selectedDotColor: Color,
        fallbackColor: Color = fallbackPickerColor
    ) -> Color {
        PuzzleDotCollageColor.usesCollageTint(selectedDotColor: selectedDotColor)
            ? fallbackColor
            : selectedColor(fromPickerColor: selectedDotColor)
    }

    static func selectedColor(fromPickerColor pickerColor: Color) -> Color {
        let uiColor = UIColor(pickerColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        }

        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return Color(.sRGB, red: white, green: white, blue: white, opacity: 1)
        }

        return Color(uiColor.withAlphaComponent(1))
    }
}

enum PuzzleDotFactory {
    private static let unitSize: CGFloat = 1
    static let randomColorPaletteHexStrings = [
        "#FF9EEA",
        "#A8F7FF",
        "#FFF38A",
        "#B7FF9D",
        "#CDB4FF",
        "#FFB86B"
    ]

    static var randomColorPalette: [Color] {
        [
            Color(.sRGB, red: 1.00, green: 0.62, blue: 0.92, opacity: 1),
            Color(.sRGB, red: 0.66, green: 0.97, blue: 1.00, opacity: 1),
            Color(.sRGB, red: 1.00, green: 0.95, blue: 0.54, opacity: 1),
            Color(.sRGB, red: 0.72, green: 1.00, blue: 0.62, opacity: 1),
            Color(.sRGB, red: 0.80, green: 0.71, blue: 1.00, opacity: 1),
            Color(.sRGB, red: 1.00, green: 0.72, blue: 0.42, opacity: 1)
        ]
    }

    static func makeDot(
        position: CGPoint,
        index: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> PuzzleDot {
        return PuzzleDot(
            id: UUID(),
            position: CGPoint(
                x: min(max(position.x, 0), 1),
                y: min(max(position.y, 0), 1)
            ),
            color: randomColorPalette[max(index, 0) % randomColorPalette.count],
            size: unitSize,
            shapeAssetName: shapeAssetName
        )
    }

    static func makeDots(
        count: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        return (0..<max(count, 0)).map { index in
            makeDot(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }
    }

    static func makeDots(
        count: Int,
        along tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        var generator = SystemRandomNumberGenerator()

        return makeDots(
            count: count,
            along: tracePoints,
            extensionRatio: extensionRatio,
            shapeAssetName: shapeAssetName,
            using: &generator
        )
    }

    static func makeDots<Generator: RandomNumberGenerator>(
        count: Int,
        along tracePoints: [PuzzleCanvasTracePoint],
        extensionRatio: CGFloat,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name,
        using generator: inout Generator
    ) -> [PuzzleDot] {
        let segments = PuzzleCanvasTracePath.segments(
            from: tracePoints,
            extensionRatio: extensionRatio
        )
        let positions = tracePoints.map(\.point)
        let normalizedCount = max(count, 0)

        guard normalizedCount > 0, !positions.isEmpty else { return [] }

        return (0..<normalizedCount).map { index in
            return makeDot(
                position: randomPosition(
                    along: segments,
                    fallbackPositions: positions,
                    dotIndex: index,
                    dotCount: normalizedCount,
                    using: &generator
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }
    }

    static func adjusting(
        _ dots: [PuzzleDot],
        toCount count: Int,
        shapeAssetName: String = DotShapeAsset.defaultSelection.name
    ) -> [PuzzleDot] {
        let normalizedCount = max(count, 0)

        if dots.count > normalizedCount {
            return Array(dots.prefix(normalizedCount))
        }

        guard dots.count < normalizedCount else { return dots }

        let newDots = (dots.count..<normalizedCount).map { index in
            makeDot(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1)
                ),
                index: index,
                shapeAssetName: shapeAssetName
            )
        }

        return dots + newDots
    }

    private static func randomPosition<Generator: RandomNumberGenerator>(
        along segments: [PuzzleCanvasTraceSegment],
        fallbackPositions: [CGPoint],
        dotIndex: Int,
        dotCount: Int,
        using generator: inout Generator
    ) -> CGPoint {
        let totalLength = segments.reduce(CGFloat.zero) { $0 + $1.length }

        guard totalLength > 0, dotCount > 0 else {
            return fallbackPositions.randomElement(using: &generator) ?? .zero
        }

        let bucketLength = totalLength / CGFloat(dotCount)
        let distance = min(
            totalLength,
            CGFloat(dotIndex) * bucketLength + CGFloat.random(in: 0...bucketLength, using: &generator)
        )

        return position(at: distance, along: segments) ?? segments.last?.end ?? .zero
    }

    private static func position(
        at distance: CGFloat,
        along segments: [PuzzleCanvasTraceSegment]
    ) -> CGPoint? {
        var remainingDistance = distance

        for segment in segments {
            let segmentLength = segment.length

            guard segmentLength > 0 else { continue }

            if remainingDistance <= segmentLength {
                let progress = remainingDistance / segmentLength

                return CGPoint(
                    x: segment.start.x + (segment.end.x - segment.start.x) * progress,
                    y: segment.start.y + (segment.end.y - segment.start.y) * progress
                )
            }

            remainingDistance -= segmentLength
        }

        return segments.last?.end
    }
}
