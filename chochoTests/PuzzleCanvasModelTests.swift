import CoreGraphics
import SwiftUI
import Testing
@testable import chocho

struct PuzzleCanvasModelTests {
    @Test func layoutClampsExtensionRatioAndFitsComposedCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 1.4
        )

        #expect(layout.extensionRatio == 1)
        #expect(layout.photoFrame.size.width == 300)
        #expect(layout.photoFrame.size.height == 150)
        #expect(layout.extensionFrame.size.width == 300)
        #expect(layout.extensionFrame.size.height == 150)
        #expect(layout.composedSize.width == 600)
        #expect(layout.composedSize.height == 150)
        #expect(layout.extensionFrame.minX == layout.photoFrame.maxX)
    }

    @Test func layoutAllowsZeroWidthExtensionCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 800, height: 400),
            availableSize: CGSize(width: 390, height: 300),
            extensionRatio: -0.2
        )

        #expect(layout.extensionRatio == 0)
        #expect(layout.extensionFrame.width == 0)
        #expect(layout.photoFrame.width == 390)
        #expect(layout.photoFrame.height == 195)
    }

    @Test func generatedDotsMatchRequestedCount() {
        let dots = PuzzleDotFactory.makeDots(count: 10, shapeAssetName: "眼睛.小物")

        #expect(dots.count == 10)
        #expect(dots.allSatisfy { 0...1 ~= $0.position.x && 0...1 ~= $0.position.y })
        #expect(dots.allSatisfy { $0.size > 0 })
        #expect(dots.allSatisfy { $0.shapeAssetName == "眼睛.小物" })
    }

    @Test func tappedDotUsesSelectedShapeAssetName() {
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.25, y: 0.75),
            index: 0,
            shapeAssetName: "花束.小物"
        )

        #expect(dot.shapeAssetName == "花束.小物")
        #expect(dot.position == CGPoint(x: 0.25, y: 0.75))
    }

    @Test func adjustedDotsGrowAndShrinkToRequestedCount() {
        let originalDots = PuzzleDotFactory.makeDots(count: 2, shapeAssetName: "眼睛.小物")

        let grownDots = PuzzleDotFactory.adjusting(originalDots, toCount: 4, shapeAssetName: "花束.小物")
        let shrunkDots = PuzzleDotFactory.adjusting(grownDots, toCount: 1, shapeAssetName: "花束.小物")

        #expect(grownDots.count == 4)
        #expect(grownDots.prefix(2).map(\.id) == originalDots.map(\.id))
        #expect(grownDots.suffix(2).allSatisfy { $0.shapeAssetName == "花束.小物" })
        #expect(shrunkDots.count == 1)
        #expect(shrunkDots.first?.id == originalDots.first?.id)
    }

    @Test func generatedDotPaletteUsesLightCandyColors() {
        #expect(PuzzleDotFactory.randomColorPaletteHexStrings == [
            "#FF9EEA",
            "#A8F7FF",
            "#FFF38A",
            "#B7FF9D",
            "#CDB4FF",
            "#FFB86B"
        ])
    }

    @Test func dotDisplayColorUsesGeneratedColorOnlyWhenRandomColorsAreEnabled() {
        let selectedColor = Color(red: 0.1, green: 0.2, blue: 0.3)
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.25, y: 0.75),
            index: 1,
            shapeAssetName: "星1"
        )

        #expect(dot.displayColor(usesRandomColor: false, selectedColor: selectedColor) == selectedColor)
        #expect(dot.displayColor(usesRandomColor: true, selectedColor: selectedColor) == dot.color)
    }

    @Test func normalizedPointUsesInverseViewportTransform() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0.2
        )

        let point = PuzzleCanvasCoordinate.normalizedPoint(
            for: CGPoint(x: 400, y: 120),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 2,
            offset: CGSize(width: 100, height: 0)
        )

        #expect(point?.x == 0.5)
        #expect(point?.y == 0.5)
    }

    @Test func normalizedPointRejectsLocationsOutsideComposedCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0.2
        )

        let point = PuzzleCanvasCoordinate.normalizedPoint(
            for: CGPoint(x: 10, y: 10),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 1,
            offset: .zero
        )

        #expect(point == nil)
    }

    @Test func backgroundTapDetectionMatchesCanvasBounds() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0.2
        )

        let insideCanvas = PuzzleCanvasCoordinate.isBackgroundTap(
            at: CGPoint(x: 300, y: 120),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 1,
            offset: .zero
        )
        let outsideCanvas = PuzzleCanvasCoordinate.isBackgroundTap(
            at: CGPoint(x: 10, y: 10),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 1,
            offset: .zero
        )

        #expect(insideCanvas == false)
        #expect(outsideCanvas == true)
    }

    @Test func dotCenterIsClampedInsideComposedCanvasByRadius() {
        let center = PuzzleCanvasCoordinate.clampedDotCenter(
            position: CGPoint(x: 1, y: 1),
            in: CGRect(x: 100, y: 20, width: 300, height: 200),
            radius: 24
        )

        #expect(center.x == 376)
        #expect(center.y == 196)
    }

    @Test func canvasHistoryUndoAndRedoMoveBetweenDotStates() {
        let firstDot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.2, y: 0.3), index: 0)
        let secondDot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.4, y: 0.5), index: 1)
        var history = CanvasHistory<[PuzzleDot]>(initialValue: [])

        history.record([firstDot])
        history.record([firstDot, secondDot])

        #expect(history.canUndo)
        #expect(history.undo() == [firstDot])
        #expect(history.canRedo)
        #expect(history.redo() == [firstDot, secondDot])
    }

    @Test func canvasHistoryClearRecordsEmptyState() {
        let dot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.2, y: 0.3), index: 0)
        var history = CanvasHistory<[PuzzleDot]>(initialValue: [dot])

        let clearedDots = history.clearValue()

        #expect(clearedDots == [])
        #expect(history.canUndo)
        #expect(history.undo() == [dot])
    }

    @Test func canvasHistoryRecordAfterUndoDropsRedoStack() {
        let firstDot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.2, y: 0.3), index: 0)
        let secondDot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.4, y: 0.5), index: 1)
        let replacementDot = PuzzleDotFactory.makeDot(position: CGPoint(x: 0.6, y: 0.7), index: 2)
        var history = CanvasHistory<[PuzzleDot]>(initialValue: [])

        history.record([firstDot])
        history.record([firstDot, secondDot])
        _ = history.undo()
        history.record([replacementDot])

        #expect(history.canRedo == false)
        #expect(history.undo() == [firstDot])
    }

    @Test func dotSizeControlMapsSmallestValueToUsableRenderedSize() {
        #expect(DotSizeControl.renderedScale(forControlValue: 1) == 24)
        #expect(DotSizeControl.renderedScale(forControlValue: 100) == 96)
    }

    @Test func dotSizeControlConvertsRenderedScaleBackToControlValue() {
        #expect(DotSizeControl.controlValue(forRenderedScale: 24) == 1)
        #expect(DotSizeControl.controlValue(forRenderedScale: 96) == 100)
    }

    @Test func dotSizeControlKeepsDefaultRenderedScaleWhenControlRangeChanges() {
        #expect(DotSizeControl.defaultRenderedScale == 40)
    }

    @Test func dotShapeCatalogGroupsItemsByPanelCategory() {
        #expect(DotShapeCategory.panelOrder.map(\.title) == ["最近", "基础", "小物", "彩纸", "贴纸", "纽扣", "水钻", "布", "针线"])
        #expect(DotShapeAsset.all.filter { $0.matches(category: .objects) }.map(\.title).prefix(4) == ["工牌", "未标题-1", "眼睛", "花束"])
    }

    @Test func basicSvgDotShapesUseUnifiedPreviewPadding() {
        let basicShape = DotShapeAsset(name: "星1", previewName: nil)
        let objectShape = DotShapeAsset(name: "眼睛.小物", previewName: "眼睛.小物.preview")

        #expect(basicShape.previewTilePadding == 16)
        #expect(objectShape.previewTilePadding == 9)
    }

    @Test func recentDotShapeListMovesSelectedShapeToFrontWithoutDuplicates() {
        let first = DotShapeAsset(name: "眼睛.小物", previewName: "眼睛.小物.preview")
        let second = DotShapeAsset(name: "花束.小物", previewName: "花束.小物.preview")
        let recentNames = DotShapeRecentList.adding(first.name, to: [second.name, first.name], limit: 3)

        #expect(recentNames == [first.name, second.name])
    }

    @Test func selectingRecentDotShapeKeepsCurrentRecentOrder() {
        let first = DotShapeAsset(name: "眼睛.小物", previewName: "眼睛.小物.preview")
        let second = DotShapeAsset(name: "花束.小物", previewName: "花束.小物.preview")

        let recentNames = DotShapeRecentList.selecting(
            first.name,
            in: .recent,
            recentNames: [second.name, first.name],
            limit: 3
        )

        #expect(recentNames == [second.name, first.name])
    }
}
