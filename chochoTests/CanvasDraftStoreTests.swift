import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import chocho

struct CanvasDraftStoreTests {
    @Test func manifest_currentVersion_is12() {
        #expect(CanvasDraftManifest.currentVersion == 12)
    }

    @Test func manifest_supportsVersion12() {
        #expect(CanvasDraftManifest.supportedVersions.contains(12))
    }

    @Test func writesAndReadsDraftFilesDirectly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-draft-direct-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = makeTestImage()
        guard let photoData = image.jpegData(compressionQuality: 0.92) else {
            Issue.record("Expected JPEG data for test image")
            return
        }

        let dots = PuzzleDotFactory.makeDots(count: 2)
        let backgroundColors = PuzzleBackgroundColors(
            fillColor: Color(red: 0.9, green: 0.2, blue: 0.3),
            alternateColor: Color(red: 0.2, green: 0.8, blue: 0.4),
            lineColor: Color(red: 0.1, green: 0.2, blue: 0.9)
        )
        let manifest = CanvasDraftManifest(
            version: CanvasDraftManifest.currentVersion,
            savedAt: Date(),
            extensionRatio: 0.2,
            extensionSide: PuzzleCanvasExtensionSide.right.rawValue,
            backgroundStyle: PuzzleBackgroundStyle.grid.rawValue,
            backgroundColors: CanvasDraftStoredBackgroundColors(backgroundColors),
            dotCount: 2,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: CanvasDraftColorComponents(Color(red: 0.2, green: 0.3, blue: 0.4)),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
            dotCharacterText: CharacterDotText.defaultText,
            isTraceDrawingEnabled: false,
            puzzleDots: dots.map(CanvasDraftStoredDot.init(dot:)),
            tracePoints: [],
            viewportScale: 1,
            viewportOffsetWidth: 0,
            viewportOffsetHeight: 0
        )

        try CanvasDraftStore.writeDraft(
            manifest: manifest,
            photoData: photoData,
            to: directory
        )

        let restored = try #require(CanvasDraftStore.readDraft(from: directory))
        #expect(restored.puzzleDots.count == dots.count)
        #expect(
            colorsAreApproximatelyEqual(
                restored.backgroundColors.fillColor,
                backgroundColors.fillColor
            )
        )
    }

    @Test func roundTripsCanvasDraftThroughDisk() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-draft-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = makeTestImage()
        let dots = PuzzleDotFactory.makeDots(count: 3, shapeAssetName: BuiltInDotShape.star.rawValue)
        let tracePoints = [
            PuzzleCanvasTracePoint(
                side: .photo,
                point: CGPoint(x: 0.2, y: 0.3),
                startsNewStroke: true
            ),
            PuzzleCanvasTracePoint(
                side: .background,
                point: CGPoint(x: 0.8, y: 0.4)
            )
        ]

        let backgroundColors = PuzzleBackgroundColors(
            fillColor: Color(red: 0.55, green: 0.7, blue: 0.2),
            alternateColor: Color(red: 0.9, green: 0.85, blue: 0.6),
            lineColor: Color(red: 0.3, green: 0.35, blue: 0.4)
        )
        let capture = CanvasDraftCapture(
            image: image,
            extensionRatio: 0.35,
            extensionSide: .left,
            backgroundStyle: .stripes,
            backgroundColors: backgroundColors,
            backgroundPatternSpacing: 24,
            dotCount: 12,
            dotScale: 1.2,
            selectedDotColor: Color(red: 0.2, green: 0.4, blue: 0.9),
            usesRandomDotColors: true,
            selectedDotShapeName: BuiltInDotShape.star.rawValue,
            dotCharacterText: "呱",
            isTraceDrawingEnabled: true,
            photoCompression: .flattened,
            puzzleDots: dots,
            tracePoints: tracePoints,
            viewportScale: 1.5,
            viewportOffset: CGSize(width: 12, height: -8),
            liveDotAnimation: .breathe,
            y2kCCDFilterSettings: Y2KCCDFilterSettings(
                enabled: true,
                downsample: 0.5,
                bloom: 0.6,
                bloomThreshold: 0.7,
                noise: 0.2,
                chromaNoise: 0.1,
                jpegArtifacts: 0.2,
                sharpen: 0.7,
                temperature: -0.3,
                tint: -0.1,
                contrast: 0.15,
                saturation: 1.3,
                highlightClip: 0.8,
                rgbShift: 0.15
            ),
            asciiArtSettings: .default,
            textBubbleSettings: TextBubbleSettings(
                enabled: true,
                bubbles: [
                    TextBubbleItem(
                        id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                        text: "雀巢咖啡自营店",
                        centerX: 0.26,
                        centerY: 0.2,
                        scale: 1.35
                    ),
                    TextBubbleItem(
                        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                        text: "第二条",
                        centerX: 0.58,
                        centerY: 0.36
                    ),
                ]
            ),
            isSourceLiveMotionEnabled: true,
            sourcePhotoAssetLocalIdentifier: "test-live-asset"
        )

        let didSave = await CanvasDraftStore.save(capture, directoryURL: directory)
        #expect(didSave)
        let loaded = try #require(await CanvasDraftStore.load(directoryURL: directory))

        #expect(loaded.extensionRatio == capture.extensionRatio)
        #expect(loaded.extensionSide == capture.extensionSide)
        #expect(loaded.backgroundStyle == capture.backgroundStyle)
        #expect(loaded.backgroundPatternSpacing == capture.backgroundPatternSpacing)
        #expect(loaded.dotCount == capture.dotCount)
        #expect(loaded.dotScale == capture.dotScale)
        #expect(loaded.usesRandomDotColors == capture.usesRandomDotColors)
        #expect(loaded.selectedDotShapeName == capture.selectedDotShapeName)
        #expect(loaded.dotCharacterText == capture.dotCharacterText)
        #expect(loaded.isTraceDrawingEnabled == capture.isTraceDrawingEnabled)
        #expect(loaded.photoCompression == capture.photoCompression)
        #expect(loaded.tracePoints == capture.tracePoints)
        #expect(loaded.viewportScale == capture.viewportScale)
        #expect(loaded.viewportOffset == capture.viewportOffset)
        #expect(loaded.liveDotAnimation == capture.liveDotAnimation)
        #expect(loaded.y2kCCDFilterSettings == capture.y2kCCDFilterSettings)
        #expect(loaded.textBubbleSettings == capture.textBubbleSettings)
        #expect(loaded.isSourceLiveMotionEnabled == capture.isSourceLiveMotionEnabled)
        #expect(loaded.sourcePhotoAssetLocalIdentifier == capture.sourcePhotoAssetLocalIdentifier)
        #expect(loaded.puzzleDots.count == capture.puzzleDots.count)
        for (savedDot, loadedDot) in zip(capture.puzzleDots, loaded.puzzleDots) {
            #expect(savedDot.id == loadedDot.id)
            #expect(savedDot.position == loadedDot.position)
            #expect(savedDot.size == loadedDot.size)
            #expect(savedDot.shapeAssetName == loadedDot.shapeAssetName)
        }
        #expect(
            colorsAreApproximatelyEqual(
                loaded.selectedDotColor,
                capture.selectedDotColor
            )
        )
        #expect(
            colorsAreApproximatelyEqual(
                loaded.backgroundColors.fillColor,
                capture.backgroundColors.fillColor
            )
        )
        #expect(
            colorsAreApproximatelyEqual(
                loaded.backgroundColors.alternateColor,
                capture.backgroundColors.alternateColor
            )
        )
        #expect(
            colorsAreApproximatelyEqual(
                loaded.backgroundColors.lineColor,
                capture.backgroundColors.lineColor
            )
        )
    }

    @Test func restoresDefaultBackgroundColorsForVersionOneDrafts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-draft-v1-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = makeTestImage()
        guard let photoData = image.jpegData(compressionQuality: 0.92) else {
            Issue.record("Expected JPEG data for test image")
            return
        }

        let manifest = CanvasDraftManifest(
            version: 1,
            savedAt: Date(),
            extensionRatio: 0.2,
            extensionSide: PuzzleCanvasExtensionSide.right.rawValue,
            backgroundStyle: PuzzleBackgroundStyle.grid.rawValue,
            backgroundColors: nil,
            dotCount: 2,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: CanvasDraftColorComponents(Color(red: 0.2, green: 0.3, blue: 0.4)),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
            dotCharacterText: nil,
            isTraceDrawingEnabled: false,
            puzzleDots: [],
            tracePoints: [],
            viewportScale: 1,
            viewportOffsetWidth: 0,
            viewportOffsetHeight: 0
        )

        try CanvasDraftStore.writeDraft(
            manifest: manifest,
            photoData: photoData,
            to: directory
        )

        let restored = try #require(CanvasDraftStore.readDraft(from: directory))
        #expect(restored.backgroundColors == PuzzleBackgroundColors.default)
        #expect(restored.backgroundPatternSpacing == PuzzleBackgroundPatternSpacing.defaultControlValue)
        #expect(restored.dotCharacterText == CharacterDotText.defaultText)
        #expect(restored.photoCompression == .none)
    }

    @Test func restoresDefaultBackgroundPatternSpacingForVersionThreeDrafts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-draft-v3-spacing-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let image = makeTestImage()
        guard let photoData = image.jpegData(compressionQuality: 0.92) else {
            Issue.record("Expected JPEG data for test image")
            return
        }

        let manifest = CanvasDraftManifest(
            version: 3,
            savedAt: Date(),
            extensionRatio: 0.2,
            extensionSide: PuzzleCanvasExtensionSide.right.rawValue,
            backgroundStyle: PuzzleBackgroundStyle.stripes.rawValue,
            backgroundColors: CanvasDraftStoredBackgroundColors(.default),
            dotCount: 2,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: CanvasDraftColorComponents(Color(red: 0.2, green: 0.3, blue: 0.4)),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
            dotCharacterText: nil,
            isTraceDrawingEnabled: false,
            puzzleDots: [],
            tracePoints: [],
            viewportScale: 1,
            viewportOffsetWidth: 0,
            viewportOffsetHeight: 0,
            liveDotAnimationRawValue: LiveDotAnimation.none.rawValue
        )

        try CanvasDraftStore.writeDraft(
            manifest: manifest,
            photoData: photoData,
            to: directory
        )

        let restored = try #require(CanvasDraftStore.readDraft(from: directory))
        #expect(restored.backgroundPatternSpacing == PuzzleBackgroundPatternSpacing.defaultControlValue)
    }

    @Test func clearRemovesSavedDraft() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-draft-clear-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let capture = CanvasDraftCapture(
            image: makeTestImage(),
            extensionRatio: 0.2,
            extensionSide: .right,
            backgroundStyle: .grid,
            backgroundColors: .default,
            backgroundPatternSpacing: PuzzleBackgroundPatternSpacing.defaultControlValue,
            dotCount: 5,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: Color(red: 0.1, green: 0.2, blue: 0.3),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
            dotCharacterText: CharacterDotText.defaultText,
            isTraceDrawingEnabled: false,
            photoCompression: .none,
            puzzleDots: PuzzleDotFactory.makeDots(count: 2),
            tracePoints: [],
            viewportScale: 1,
            viewportOffset: .zero,
            liveDotAnimation: .none,
            y2kCCDFilterSettings: .default,
            asciiArtSettings: .default,
            textBubbleSettings: .default,
            isSourceLiveMotionEnabled: false,
            sourcePhotoAssetLocalIdentifier: nil
        )

        await CanvasDraftStore.save(capture, directoryURL: directory)
        #expect(await CanvasDraftStore.load(directoryURL: directory) != nil)

        await CanvasDraftStore.clear(directoryURL: directory)
        #expect(await CanvasDraftStore.load(directoryURL: directory) == nil)
    }

    private func colorsAreApproximatelyEqual(_ lhs: Color, _ rhs: Color) -> Bool {
        let left = CanvasDraftColorComponents(lhs)
        let right = CanvasDraftColorComponents(rhs)
        let tolerance = 0.02

        return abs(left.red - right.red) < tolerance
            && abs(left.green - right.green) < tolerance
            && abs(left.blue - right.blue) < tolerance
            && abs(left.opacity - right.opacity) < tolerance
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20))
        return renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
    }
}
