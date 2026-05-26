import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import chocho

struct CanvasDraftStoreTests {
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
        let manifest = CanvasDraftManifest(
            version: CanvasDraftManifest.currentVersion,
            savedAt: Date(),
            extensionRatio: 0.2,
            extensionSide: PuzzleCanvasExtensionSide.right.rawValue,
            backgroundStyle: PuzzleBackgroundStyle.grid.rawValue,
            dotCount: 2,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: CanvasDraftColorComponents(Color(red: 0.2, green: 0.3, blue: 0.4)),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
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

        let restored = CanvasDraftStore.readDraft(from: directory)
        #expect(restored != nil)
        #expect(restored?.puzzleDots.count == dots.count)
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

        let capture = CanvasDraftCapture(
            image: image,
            extensionRatio: 0.35,
            extensionSide: .left,
            backgroundStyle: .stripes,
            dotCount: 12,
            dotScale: 1.2,
            selectedDotColor: Color(red: 0.2, green: 0.4, blue: 0.9),
            usesRandomDotColors: true,
            selectedDotShapeName: BuiltInDotShape.star.rawValue,
            isTraceDrawingEnabled: true,
            puzzleDots: dots,
            tracePoints: tracePoints,
            viewportScale: 1.5,
            viewportOffset: CGSize(width: 12, height: -8)
        )

        let didSave = await CanvasDraftStore.save(capture, directoryURL: directory)
        #expect(didSave)
        let loaded = try #require(await CanvasDraftStore.load(directoryURL: directory))

        #expect(loaded.extensionRatio == capture.extensionRatio)
        #expect(loaded.extensionSide == capture.extensionSide)
        #expect(loaded.backgroundStyle == capture.backgroundStyle)
        #expect(loaded.dotCount == capture.dotCount)
        #expect(loaded.dotScale == capture.dotScale)
        #expect(loaded.usesRandomDotColors == capture.usesRandomDotColors)
        #expect(loaded.selectedDotShapeName == capture.selectedDotShapeName)
        #expect(loaded.isTraceDrawingEnabled == capture.isTraceDrawingEnabled)
        #expect(loaded.tracePoints == capture.tracePoints)
        #expect(loaded.viewportScale == capture.viewportScale)
        #expect(loaded.viewportOffset == capture.viewportOffset)
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
            dotCount: 5,
            dotScale: DotSizeControl.defaultRenderedScale,
            selectedDotColor: Color(red: 0.1, green: 0.2, blue: 0.3),
            usesRandomDotColors: false,
            selectedDotShapeName: DotShapeAsset.defaultSelection.name,
            isTraceDrawingEnabled: false,
            puzzleDots: PuzzleDotFactory.makeDots(count: 2),
            tracePoints: [],
            viewportScale: 1,
            viewportOffset: .zero
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
