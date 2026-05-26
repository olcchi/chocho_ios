import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import chocho

struct PuzzleCanvasModelTests {
    @Test func dragModeUsesViewportPanningWhenTraceDrawingIsDisabled() {
        #expect(PuzzleCanvasDragMode.current(isTraceDrawingEnabled: false) == .viewport)
    }

    @Test func dragModeUsesTraceDrawingWhenTraceModeIsEnabled() {
        #expect(PuzzleCanvasDragMode.current(isTraceDrawingEnabled: true) == .trace)
    }

    @Test func layoutClampsExtensionRatioAndFitsComposedCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 1.4
        )

        #expect(layout.extensionRatio == 1)
        #expect(layout.photoFrame.size.width == 480)
        #expect(layout.photoFrame.size.height == 240)
        #expect(layout.extensionFrame.size.width == 480)
        #expect(layout.extensionFrame.size.height == 240)
        #expect(layout.composedSize.width == 960)
        #expect(layout.composedSize.height == 240)
        #expect(layout.extensionFrame.minX == layout.photoFrame.maxX)
    }

    @Test func panelLayoutHeightBoostKeepsPhotoFitScaleStable() {
        let contentHeight = BottomSheetPanel.fallbackContentHeight
        let boost = BottomSheetPanel.layoutHeightBoost(
            isExpanded: true,
            contentHeight: contentHeight
        )
        #expect(boost > 0)

        let collapsedViewport = CGSize(width: 390, height: 500)
        let expandedViewport = CGSize(width: 390, height: 500 - boost)
        let imageSize = CGSize(width: 1000, height: 500)

        let collapsedLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: collapsedViewport,
            extensionRatio: 0.5
        )
        let expandedLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: CGSize(
                width: expandedViewport.width,
                height: expandedViewport.height + boost
            ),
            extensionRatio: 0.5
        )

        #expect(collapsedLayout.photoFrame.size == expandedLayout.photoFrame.size)
        #expect(collapsedLayout.photoFrame.origin == expandedLayout.photoFrame.origin)
        #expect(
            BottomSheetPanel.layoutHeightBoost(
                isExpanded: false,
                contentHeight: contentHeight
            ) == 0
        )
    }

    @Test func shorterPanelContentProducesSmallerLayoutHeightBoost() {
        let tallContent: CGFloat = 320
        let shortContent: CGFloat = 120

        let tallBoost = BottomSheetPanel.layoutHeightBoost(
            isExpanded: true,
            contentHeight: tallContent
        )
        let shortBoost = BottomSheetPanel.layoutHeightBoost(
            isExpanded: true,
            contentHeight: shortContent
        )

        #expect(shortBoost < tallBoost)
    }

    @Test func panelExpansionOffsetDeltaShiftsCanvasUpWhenPanelExpands() {
        let boost = BottomSheetPanel.layoutHeightBoost(
            isExpanded: true,
            contentHeight: BottomSheetPanel.fallbackContentHeight
        )
        let dodge = boost * PuzzleCanvasViewport.panelExpansionDodgeFraction

        let expandedDelta = PuzzleCanvasViewport.panelExpansionOffsetDelta(
            panelHeightBoost: boost,
            isPanelExpanded: true
        )
        let collapsedDelta = PuzzleCanvasViewport.panelExpansionOffsetDelta(
            panelHeightBoost: boost,
            isPanelExpanded: false
        )

        #expect(expandedDelta.width == 0)
        #expect(expandedDelta.height == -dodge)
        #expect(collapsedDelta.height == -expandedDelta.height)
        #expect(dodge < boost)
    }

    @Test func layoutKeepsPhotoSizeWhenExtensionRatioChanges() {
        let baseline = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0
        )
        let extended = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0.8
        )

        #expect(baseline.photoFrame.size == extended.photoFrame.size)
        #expect(baseline.photoFrame.origin == extended.photoFrame.origin)
        #expect(extended.composedSize.width > baseline.composedSize.width)
        #expect(extended.extensionFrame.width == baseline.photoFrame.width * 0.8)
        #expect(extended.referenceComposedFrame == baseline.referenceComposedFrame)
    }

    @Test func viewportResetFitsComposedWidthToNinetyPercentOfScreen() {
        let availableSize = CGSize(width: 600, height: 240)
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: availableSize,
            extensionRatio: 1
        )
        let reset = PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: availableSize
        )
        let viewportCenter = CGPoint(x: availableSize.width / 2, y: availableSize.height / 2)
        let visibleFrame = layout.visibleComposedFrame
        let scale = reset.scale
        let horizontalInset = availableSize.width * (1 - PuzzleCanvasViewport.resetViewportWidthFraction) / 2

        #expect(isApproximatelyEqual(scale, 600.0 * 0.9 / 960.0))
        #expect(
            reset.offset.width
            == -viewportCenter.x
                - (visibleFrame.minX - viewportCenter.x) * scale
                + horizontalInset
        )
        #expect(
            reset.offset.height
            == availableSize.height / 2
                - viewportCenter.y
                - (visibleFrame.midY - viewportCenter.y) * scale
        )

        let leftEdge = viewportCenter.x
            + (visibleFrame.minX - viewportCenter.x) * scale
            + reset.offset.width
        let rightEdge = viewportCenter.x
            + (visibleFrame.maxX - viewportCenter.x) * scale
            + reset.offset.width

        #expect(isApproximatelyEqual(leftEdge, horizontalInset))
        #expect(isApproximatelyEqual(rightEdge, availableSize.width - horizontalInset))
    }

    @Test func magnifyAdjustedOffsetKeepsAnchorPointFixed() {
        let availableSize = CGSize(width: 600, height: 400)
        let anchor = CGPoint(x: 180, y: 260)
        let baseOffset = CGSize(width: 24, height: -36)
        let scaleMultiplier: CGFloat = 1.35
        let viewportCenter = CGPoint(x: availableSize.width / 2, y: availableSize.height / 2)
        let baseScale: CGFloat = 1.6

        let adjustedOffset = PuzzleCanvasViewport.adjustedOffset(
            anchor: anchor,
            availableSize: availableSize,
            scaleMultiplier: scaleMultiplier,
            baseOffset: baseOffset
        )
        let nextScale = baseScale * scaleMultiplier
        let contentPoint = CGPoint(
            x: viewportCenter.x + (anchor.x - baseOffset.width - viewportCenter.x) / baseScale,
            y: viewportCenter.y + (anchor.y - baseOffset.height - viewportCenter.y) / baseScale
        )
        let anchoredScreenPoint = CGPoint(
            x: viewportCenter.x + (contentPoint.x - viewportCenter.x) * nextScale + adjustedOffset.width,
            y: viewportCenter.y + (contentPoint.y - viewportCenter.y) * nextScale + adjustedOffset.height
        )

        #expect(anchoredScreenPoint.x == anchor.x)
        #expect(anchoredScreenPoint.y == anchor.y)
    }

    @Test func viewportResetScalesPhotoOnlyCanvasToNinetyPercentOfScreen() {
        let availableSize = CGSize(width: 600, height: 240)
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: availableSize,
            extensionRatio: 0
        )
        let reset = PuzzleCanvasViewport.resetTransform(
            layout: layout,
            availableSize: availableSize
        )
        let horizontalInset = availableSize.width * (1 - PuzzleCanvasViewport.resetViewportWidthFraction) / 2

        #expect(isApproximatelyEqual(reset.scale, 600.0 * 0.9 / 480.0))
        #expect(isApproximatelyEqual(reset.offset.width, horizontalInset))
        #expect(reset.offset.height == 0)
    }

    @Test func exportViewportTransformAlignsVisibleCompositionToExportBounds() {
        let exportSize = CGSize(width: 1200, height: 500)
        let transform = PuzzleCanvasExport.viewportTransform(
            imageSize: CGSize(width: 1000, height: 500),
            exportSize: exportSize,
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: exportSize,
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let viewportCenter = CGPoint(x: exportSize.width / 2, y: exportSize.height / 2)
        let visibleFrame = layout.visibleComposedFrame

        let exportedLeftEdge = viewportCenter.x
            + (visibleFrame.minX - viewportCenter.x) * transform.scale
            + transform.offset.width
        let exportedRightEdge = viewportCenter.x
            + (visibleFrame.maxX - viewportCenter.x) * transform.scale
            + transform.offset.width

        #expect(transform.scale == 1)
        #expect(exportedLeftEdge == 0)
        #expect(exportedRightEdge == exportSize.width)
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

    @Test func dotCentersUseFixedReferencePositionsForMirroredCopies() {
        let referenceFrame = CGRect(x: 0, y: 0, width: 800, height: 200)
        let centers = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
            position: CGPoint(x: 0.1, y: 0.25),
            referenceFrame: referenceFrame
        )

        #expect(centers == [
            CGPoint(x: 40, y: 50),
            CGPoint(x: 440, y: 50)
        ])
    }

    @Test func dotCentersKeepMirrorAtReferenceEdgeForRightPhotoPositions() {
        let referenceFrame = CGRect(x: 0, y: 0, width: 800, height: 200)
        let centers = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
            position: CGPoint(x: 0.9, y: 0.25),
            referenceFrame: referenceFrame
        )

        #expect(centers == [
            CGPoint(x: 360, y: 50),
            CGPoint(x: 760, y: 50)
        ])
    }

    @Test func dotCentersStayInMaxBackgroundCoordinatesWhenRightBackgroundIsClipped() {
        let imageSize = CGSize(width: 1000, height: 500)
        let availableSize = CGSize(width: 600, height: 240)
        let fullBackgroundLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: availableSize,
            extensionRatio: 1,
            extensionSide: .right
        )
        let clippedBackgroundLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: availableSize,
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let position = CGPoint(x: 0.8, y: 0.4)

        let fullCenters = PuzzleCanvasCoordinate.dotCenters(
            for: position,
            in: fullBackgroundLayout
        )
        let clippedCenters = PuzzleCanvasCoordinate.dotCenters(
            for: position,
            in: clippedBackgroundLayout
        )

        #expect(fullCenters == clippedCenters)
        #expect(clippedCenters == [
            CGPoint(x: 384, y: 96),
            CGPoint(x: 864, y: 96)
        ])
        #expect(clippedBackgroundLayout.visibleComposedFrame.maxX < clippedCenters[1].x)
    }

    @Test func dotCentersStayInMaxBackgroundCoordinatesForAllBackgroundSides() {
        let imageSize = CGSize(width: 1000, height: 500)
        let availableSize = CGSize(width: 600, height: 240)
        let position = CGPoint(x: 0.3, y: 0.7)

        for side in PuzzleCanvasExtensionSide.allCases {
            let fullBackgroundLayout = PuzzleCanvasLayout.layout(
                imageSize: imageSize,
                availableSize: availableSize,
                extensionRatio: 1,
                extensionSide: side
            )
            let clippedBackgroundLayout = PuzzleCanvasLayout.layout(
                imageSize: imageSize,
                availableSize: availableSize,
                extensionRatio: 0.2,
                extensionSide: side
            )

            #expect(
                PuzzleCanvasCoordinate.dotCenters(
                    for: position,
                    in: fullBackgroundLayout
                )
                == PuzzleCanvasCoordinate.dotCenters(
                    for: position,
                    in: clippedBackgroundLayout
                )
            )
        }
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

    @Test func collageDisplayColorSamplesOppositeLayerAtMirrorPosition() throws {
        let image = try #require(makeSolidTestImage())
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 100, height: 100),
            availableSize: CGSize(width: 240, height: 120),
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.5, y: 0.5),
            index: 0,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )
        let photoDotColor = PuzzleDotCollageColor.displayColor(
            for: dot,
            centerIndex: 0,
            layout: layout,
            image: image,
            backgroundStyle: .stripes,
            usesRandomDotColors: false,
            selectedDotColor: .clear
        )
        let backgroundDotColor = PuzzleDotCollageColor.displayColor(
            for: dot,
            centerIndex: 1,
            layout: layout,
            image: image,
            backgroundStyle: .stripes,
            usesRandomDotColors: false,
            selectedDotColor: .clear
        )

        #expect(photoDotColor != .clear)
        #expect(backgroundDotColor != .clear)
        #expect(
            PuzzleDotCollageColor.imageColor(at: dot.position, image: image)
            == backgroundDotColor
        )
        #expect(
            PuzzleDotCollageColor.backgroundColor(
                at: PuzzleDotCollageColor.referenceExtensionMirrorPosition(
                    forPhotoPosition: dot.position,
                    extensionSide: layout.extensionSide
                ),
                style: .stripes,
                extensionSize: layout.referenceLocalExtensionGridFrame.size,
                photoFrameHeight: layout.referenceLocalPhotoFrame.height
            )
            == photoDotColor
        )
    }

    @Test func collagePhotoDotAppearanceIsStableWhenExtensionIsCropped() throws {
        let image = try #require(makeSolidTestImage())
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.7, y: 0.4),
            index: 0,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )
        let wideLayout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 100, height: 100),
            availableSize: CGSize(width: 240, height: 120),
            extensionRatio: 0.8,
            extensionSide: .right
        )
        let narrowLayout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 100, height: 100),
            availableSize: CGSize(width: 240, height: 120),
            extensionRatio: 0.2,
            extensionSide: .right
        )

        let widePhotoDotColor = PuzzleDotCollageColor.displayColor(
            for: dot,
            centerIndex: 0,
            layout: wideLayout,
            image: image,
            backgroundStyle: .stripes,
            usesRandomDotColors: false,
            selectedDotColor: .clear
        )
        let narrowPhotoDotColor = PuzzleDotCollageColor.displayColor(
            for: dot,
            centerIndex: 0,
            layout: narrowLayout,
            image: image,
            backgroundStyle: .stripes,
            usesRandomDotColors: false,
            selectedDotColor: .clear
        )

        #expect(widePhotoDotColor == narrowPhotoDotColor)
    }

    @Test func opaqueSelectedColorDisablesCollageRendering() {
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.5, y: 0.5),
            index: 0,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )

        #expect(PuzzleDotCollageColor.usesCollageTint(selectedDotColor: .clear))
        #expect(!PuzzleDotCollageColor.usesCollageTint(selectedDotColor: Color.red))
        #expect(
            !PuzzleDotCollageColor.shouldRenderCollageContent(
                for: dot,
                usesRandomDotColors: false,
                extensionRatio: 0.2,
                selectedDotColor: Color.red
            )
        )
        #expect(
            PuzzleDotCollageColor.shouldRenderCollageContent(
                for: dot,
                usesRandomDotColors: false,
                extensionRatio: 0.2,
                selectedDotColor: .clear
            )
        )
    }

    @Test func basicSvgDotSupportsCollageTinting() {
        let svgDot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.5, y: 0.5),
            index: 0,
            shapeAssetName: "星1"
        )

        #expect(svgDot.supportsCollageTinting)
        #expect(
            PuzzleDotCollageColor.shouldRenderCollageContent(
                for: svgDot,
                usesRandomDotColors: false,
                extensionRatio: 0.2,
                selectedDotColor: .clear
            )
        )
    }

    @Test func collageDisplayColorIgnoresPngStickerDots() throws {
        let image = try #require(makeSolidTestImage())
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 100, height: 100),
            availableSize: CGSize(width: 240, height: 120),
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let pngDot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.5, y: 0.5),
            index: 0,
            shapeAssetName: "鱼"
        )
        let selectedColor = Color.red

        #expect(!pngDot.supportsCollageTinting)
        #expect(
            PuzzleDotCollageColor.displayColor(
                for: pngDot,
                centerIndex: 0,
                layout: layout,
                image: image,
                backgroundStyle: .stripes,
                usesRandomDotColors: false,
                selectedDotColor: selectedColor
            )
            == selectedColor
        )
        #expect(
            PuzzleDotCollageColor.displayColor(
                for: pngDot,
                centerIndex: 1,
                layout: layout,
                image: image,
                backgroundStyle: .stripes,
                usesRandomDotColors: false,
                selectedDotColor: selectedColor
            )
            == selectedColor
        )
    }

    @Test func builtInBasicDotShapesAreAvailableForDrawing() {
        let builtInNames = BuiltInDotShape.allCases.map(\.rawValue)
        let basicShapeNames = DotShapeAsset.shapes(for: .basic, recentNames: []).map(\.name)
        let dot = PuzzleDotFactory.makeDot(
            position: CGPoint(x: 0.25, y: 0.75),
            index: 0,
            shapeAssetName: BuiltInDotShape.star.rawValue
        )

        #expect(basicShapeNames.starts(with: builtInNames))
        #expect(dot.builtInShape == .star)
        #expect(dot.usesTemplateColor)
    }

    @Test func categorizedAssetDotsRenderLargerThanBasicDots() {
        let basicDot = PuzzleDotFactory.makeDot(
            position: .zero,
            index: 0,
            shapeAssetName: "星1"
        )
        let categorizedDot = PuzzleDotFactory.makeDot(
            position: .zero,
            index: 0,
            shapeAssetName: "鱼1.纽扣"
        )

        #expect(basicDot.displaySizeScale == 1)
        #expect(categorizedDot.displaySizeScale == 1.25)
    }

    @Test func assetDotsWithoutKnownCategorySuffixRenderAsBasicDots() {
        let basicDot = PuzzleDotFactory.makeDot(
            position: .zero,
            index: 0,
            shapeAssetName: "圆.brush"
        )

        #expect(basicDot.usesTemplateColor)
        #expect(basicDot.displaySizeScale == 1)
    }

    @Test func defaultDotShapeSelectionIsCircle() {
        #expect(DotShapeAsset.defaultSelection.name == BuiltInDotShape.circle.rawValue)
        #expect(DotShapeAsset.defaultSelection.builtInShape == .circle)
    }

    @Test func photoUploadDefaultDotsUseCurrentCountAndShape() {
        let dots = PuzzleCanvasUploadDefaults.initialDots(
            dotCount: 10.4,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )

        #expect(dots.count == 10)
        #expect(dots.allSatisfy { $0.shapeAssetName == BuiltInDotShape.circle.rawValue })
        #expect(dots.allSatisfy { 0...1 ~= $0.position.x && 0...1 ~= $0.position.y })
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

        #expect(point?.x == 0.25)
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

    @Test func backgroundLocalPointUsesContactEdgeAsOriginForEachSide() {
        let imageSize = CGSize(width: 1000, height: 500)
        let availableSize = CGSize(width: 600, height: 240)

        let rightLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: availableSize,
            extensionRatio: 0.2,
            extensionSide: .right
        )
        let leftLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: availableSize,
            extensionRatio: 0.2,
            extensionSide: .left
        )
        let topLayout = PuzzleCanvasLayout.layout(
            imageSize: imageSize,
            availableSize: availableSize,
            extensionRatio: 0.2,
            extensionSide: .top
        )

        let rightContact = CGPoint(
            x: rightLayout.extensionFrame.minX,
            y: rightLayout.extensionFrame.midY
        )
        let leftContact = CGPoint(
            x: leftLayout.extensionFrame.maxX,
            y: leftLayout.extensionFrame.midY
        )
        let topContact = CGPoint(
            x: topLayout.extensionFrame.midX,
            y: topLayout.extensionFrame.maxY
        )

        #expect(
            PuzzleCanvasCoordinate.backgroundLocalPoint(
                unscaledLocation: rightContact,
                layout: rightLayout
            ).x == 0
        )
        #expect(
            PuzzleCanvasCoordinate.backgroundLocalPoint(
                unscaledLocation: leftContact,
                layout: leftLayout
            ).x == 0
        )
        #expect(
            PuzzleCanvasCoordinate.backgroundLocalPoint(
                unscaledLocation: topContact,
                layout: topLayout
            ).y == 0
        )
    }

    @Test func dotMirrorOnLeftKeepsSameLocalOffsetFromContactAsRight() {
        let referenceFrame = CGRect(x: 0, y: 0, width: 800, height: 200)
        let rightCenters = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
            position: CGPoint(x: 0.1, y: 0.25),
            referenceFrame: referenceFrame,
            extensionSide: .right
        )
        let leftCenters = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
            position: CGPoint(x: 0.1, y: 0.25),
            referenceFrame: referenceFrame,
            extensionSide: .left
        )

        #expect(rightCenters == [CGPoint(x: 40, y: 50), CGPoint(x: 440, y: 50)])
        #expect(leftCenters == [CGPoint(x: 440, y: 50), CGPoint(x: 40, y: 50)])
    }

    @Test func dotPositionMapsBackgroundTapToMatchingPhotoCoordinate() {
        let backgroundTap = PuzzleCanvasTracePoint(
            side: .background,
            point: CGPoint(x: 0.1, y: 0.5)
        )

        #expect(
            PuzzleCanvasCoordinate.dotPosition(for: backgroundTap, extensionSide: .right)
                == CGPoint(x: 0.1, y: 0.5)
        )
        #expect(
            PuzzleCanvasCoordinate.dotPosition(for: backgroundTap, extensionSide: .bottom)
                == CGPoint(x: 0.1, y: 0.5)
        )
    }

    @Test func dotPositionMirrorsBackgroundTapForLeftAndTopExtensions() {
        let backgroundTap = PuzzleCanvasTracePoint(
            side: .background,
            point: CGPoint(x: 0.9, y: 0.25)
        )

        #expect(
            PuzzleCanvasCoordinate.dotPosition(for: backgroundTap, extensionSide: .left)
                == CGPoint(x: 0.1, y: 0.25)
        )
        #expect(
            PuzzleCanvasCoordinate.dotPosition(for: backgroundTap, extensionSide: .top)
                == CGPoint(x: 0.9, y: 0.75)
        )
    }

    @Test func dotPositionKeepsPhotoTapUnchanged() {
        let photoTap = PuzzleCanvasTracePoint(
            side: .photo,
            point: CGPoint(x: 0.2, y: 0.5)
        )

        #expect(
            PuzzleCanvasCoordinate.dotPosition(for: photoTap, extensionSide: .right)
                == CGPoint(x: 0.2, y: 0.5)
        )
    }

    @Test func backgroundTapDotRendersOnPhotoAndExtensionForRightExtension() {
        let referenceFrame = CGRect(x: 0, y: 0, width: 800, height: 200)
        let photoPosition = PuzzleCanvasCoordinate.dotPosition(
            for: PuzzleCanvasTracePoint(
                side: .background,
                point: CGPoint(x: 0.1, y: 0.25)
            ),
            extensionSide: .right
        )
        let centers = PuzzleCanvasCoordinate.dotCentersInReferenceFrame(
            position: photoPosition,
            referenceFrame: referenceFrame,
            extensionSide: .right
        )

        #expect(photoPosition == CGPoint(x: 0.1, y: 0.25))
        #expect(centers == [
            CGPoint(x: 40, y: 50),
            CGPoint(x: 440, y: 50)
        ])
    }

    @Test func canvasLocationSeparatesPhotoAndBackgroundSides() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 0.2
        )

        let photoLocation = PuzzleCanvasCoordinate.canvasLocation(
            for: CGPoint(x: 156, y: 120),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 1,
            offset: .zero
        )
        let backgroundLocation = PuzzleCanvasCoordinate.canvasLocation(
            for: CGPoint(x: 588, y: 120),
            availableSize: CGSize(width: 600, height: 240),
            layout: layout,
            scale: 1,
            offset: .zero
        )

        #expect(photoLocation?.side == .photo)
        #expect(photoLocation?.point.x == 0.2)
        #expect(photoLocation?.point.y == 0.5)
        #expect(backgroundLocation?.side == .background)
        #expect(backgroundLocation?.point.x == 0.1)
        #expect(backgroundLocation?.point.y == 0.5)
    }

    @Test func traceDotsAreGeneratedWithinDrawnTraceBounds() {
        let trace = [
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.25, y: 0.4)),
            PuzzleCanvasTracePoint(side: .background, point: CGPoint(x: 0.75, y: 0.6))
        ]

        let dots = PuzzleDotFactory.makeDots(
            count: 2,
            along: trace,
            extensionRatio: 0.2,
            shapeAssetName: "星1"
        )

        #expect(dots.count == 2)
        #expect(dots.allSatisfy { 0.25...0.75 ~= $0.position.x })
        #expect(dots.allSatisfy { 0.4...0.6 ~= $0.position.y })
        #expect(dots.allSatisfy { $0.shapeAssetName == "星1" })
    }

    @Test func traceDotsUseSideLocalCoordinates() {
        let trace = [
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.8, y: 0.2)),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 1.0, y: 0.2))
        ]
        var generator = SeededRandomNumberGenerator(seed: 3)

        let dots = PuzzleDotFactory.makeDots(
            count: 8,
            along: trace,
            extensionRatio: 0.2,
            shapeAssetName: "星1",
            using: &generator
        )

        #expect(dots.count == 8)
        #expect(dots.allSatisfy { 0.8...1.0 ~= $0.position.x })
        #expect(dots.allSatisfy { $0.position.y == 0.2 })
    }

    @Test func traceSegmentsSkipLiftedStrokeBreaks() {
        let trace = [
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.0, y: 0.0)),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.2, y: 0.0)),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.8, y: 1.0), startsNewStroke: true),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 1.0, y: 1.0))
        ]

        let segments = PuzzleCanvasTracePath.segments(
            from: trace,
            extensionRatio: 0
        )

        #expect(segments.count == 2)
        #expect(segments[0].start == CGPoint(x: 0.0, y: 0.0))
        #expect(segments[0].end == CGPoint(x: 0.2, y: 0.0))
        #expect(segments[1].start == CGPoint(x: 0.8, y: 1.0))
        #expect(segments[1].end == CGPoint(x: 1.0, y: 1.0))
    }

    @Test func traceDotsAreRandomizedForEachDraw() {
        let trace = [
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.1, y: 0.2)),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.2, y: 0.3)),
            PuzzleCanvasTracePoint(side: .photo, point: CGPoint(x: 0.3, y: 0.4)),
            PuzzleCanvasTracePoint(side: .background, point: CGPoint(x: 0.4, y: 0.5)),
            PuzzleCanvasTracePoint(side: .background, point: CGPoint(x: 0.1, y: 0.6)),
            PuzzleCanvasTracePoint(side: .background, point: CGPoint(x: 0.2, y: 0.7))
        ]
        var firstGenerator = SeededRandomNumberGenerator(seed: 1)
        var secondGenerator = SeededRandomNumberGenerator(seed: 2)

        let firstPositions = PuzzleDotFactory.makeDots(
            count: 12,
            along: trace,
            extensionRatio: 0.2,
            shapeAssetName: "星1",
            using: &firstGenerator
        ).map(\.position)
        let secondPositions = PuzzleDotFactory.makeDots(
            count: 12,
            along: trace,
            extensionRatio: 0.2,
            shapeAssetName: "星1",
            using: &secondGenerator
        ).map(\.position)

        #expect(firstPositions != secondPositions)
    }

    @Test func traceDisplayPointUsesReferenceComposedCoordinates() {
        let point = PuzzleCanvasCoordinate.composedCanvasPoint(
            for: PuzzleCanvasTracePoint(side: .background, point: CGPoint(x: 0.1, y: 0.25)),
            canvasSize: CGSize(width: 600, height: 300)
        )

        #expect(point?.x == 330)
        #expect(point?.y == 75)
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

    @Test func dotCenterStaysAtNormalizedPositionRegardlessOfSize() {
        let center = PuzzleCanvasCoordinate.dotCenter(
            position: CGPoint(x: 1, y: 1),
            in: CGRect(x: 100, y: 20, width: 300, height: 200)
        )

        #expect(center.x == 400)
        #expect(center.y == 220)
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
        #expect(DotSizeControl.renderedScale(forControlValue: 1) == 8)
        #expect(DotSizeControl.renderedScale(forControlValue: 100) == 40)
    }

    @Test func dotSizeControlConvertsRenderedScaleBackToControlValue() {
        #expect(DotSizeControl.controlValue(forRenderedScale: 8) == 1)
        #expect(DotSizeControl.controlValue(forRenderedScale: 40) == 100)
    }

    @Test func dotSizeControlKeepsDefaultRenderedScaleWhenControlRangeChanges() {
        #expect(DotSizeControl.defaultRenderedScale == 15.11111111111111)
    }

    @Test func dotDisplaySizeScalesWithPhotoFrameHeight() {
        #expect(
            DotSizeControl.displaySize(renderedScale: 16, photoFrameHeight: 240)
            == 16
        )
        #expect(
            DotSizeControl.displaySize(renderedScale: 16, photoFrameHeight: 120)
            == 8
        )
    }

    @Test func backgroundGridMetricsScaleWithPhotoFrameHeight() {
        #expect(
            PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: 240)
            == 12
        )
        #expect(
            PuzzleBackgroundGridMetrics.spacing(photoFrameHeight: 500)
            == 25
        )
        #expect(
            isApproximatelyEqual(
                PuzzleBackgroundGridMetrics.lineWidth(photoFrameHeight: 500),
                500.0 / 240.0
            )
        )
    }

    @Test func dotShapeCatalogGroupsItemsByPanelCategory() {
        #expect(DotShapeCategory.panelOrder.map(\.title) == ["最近", "基础", "小物", "彩纸", "贴纸", "纽扣", "水钻", "布", "针线"])
        #expect(DotShapeAsset.all.filter { $0.matches(category: .objects) }.map(\.name).contains("眼睛.小物"))
    }

    @Test func assetDotNamesUseFinalComponentAsCategory() {
        let rhinestoneShape = DotShapeAsset(name: "圆.brush.水钻")

        #expect(rhinestoneShape.title == "圆.brush")
        #expect(rhinestoneShape.category == "水钻")
        #expect(rhinestoneShape.matches(category: .rhinestone))
    }

    @Test func dotShapeCategoryUsesOnlyKnownFinalSuffix() {
        let basicShapeWithDotInName = DotShapeAsset(name: "圆.brush")
        let basicShapeNames = DotShapeAsset.shapes(for: .basic, recentNames: []).map(\.name)
        let stickerShapeNames = DotShapeAsset.shapes(for: .sticker, recentNames: []).map(\.name)
        let rhinestoneShapeNames = DotShapeAsset.shapes(for: .rhinestone, recentNames: []).map(\.name)

        #expect(basicShapeWithDotInName.title == "圆.brush")
        #expect(basicShapeWithDotInName.category == "基础")
        #expect(basicShapeWithDotInName.matches(category: .basic))
        #expect(basicShapeNames.contains("心"))
        #expect(!basicShapeNames.contains("心.水钻"))
        #expect(rhinestoneShapeNames.contains("心.水钻"))
        #expect(stickerShapeNames.contains("鱼.贴纸"))
    }

    @Test func generatedDotShapeCatalogFeedsPanelShapeList() {
        let paperShapeNames = DotShapeAsset.shapes(for: .paper, recentNames: []).map(\.name)

        #expect(paperShapeNames.contains("彩纸5.彩纸"))
    }

    @Test func assetDotImageNamesUseCompiledCatalogName() {
        let shape = DotShapeAsset(name: "彩纸5.彩纸")

        #expect(shape.assetImageName == "public/彩纸5.彩纸")
    }

    @Test func basicAssetDotPreviewsUseTemplateTinting() {
        let basicShape = DotShapeAsset(name: "星1")
        let categorizedShape = DotShapeAsset(name: "彩纸5.彩纸")

        #expect(basicShape.usesTemplatePreview)
        #expect(!categorizedShape.usesTemplatePreview)
    }

    @Test func datasetDotAssetsLoadAsImagesForPanelPreview() {
        let image = DotShapeAssetImage.uiImage(named: DotShapeAsset(name: "彩纸5.彩纸").assetImageName)

        #expect(image != nil)
    }

    @Test func categorizedDotAssetImagesUseExactDataAssetInsteadOfBaseImageFallback() throws {
        for assetName in ["public/心.水钻", "public/星1.纽扣"] {
            let loadedImage = try #require(DotShapeAssetImage.uiImage(named: assetName))
            let dataAsset = try #require(NSDataAsset(name: assetName))
            let exactImage = try #require(UIImage(data: dataAsset.data))

            #expect(normalizedPNGData(loadedImage) == normalizedPNGData(exactImage))
        }
    }

    @Test func basicSvgDotShapesUseUnifiedPreviewPadding() {
        let basicShape = DotShapeAsset(name: "星1")
        let objectShape = DotShapeAsset(name: "眼睛.小物")

        #expect(basicShape.previewTilePadding == 16)
        #expect(objectShape.previewTilePadding == 9)
    }

    @Test func recentDotShapeListMovesSelectedShapeToFrontWithoutDuplicates() {
        let first = DotShapeAsset(name: "眼睛.小物")
        let second = DotShapeAsset(name: "花束.小物")
        let recentNames = DotShapeRecentList.adding(first.name, to: [second.name, first.name], limit: 3)

        #expect(recentNames == [first.name, second.name])
    }

    @Test func selectingRecentDotShapeKeepsCurrentRecentOrder() {
        let first = DotShapeAsset(name: "眼睛.小物")
        let second = DotShapeAsset(name: "花束.小物")

        let recentNames = DotShapeRecentList.selecting(
            first.name,
            in: .recent,
            recentNames: [second.name, first.name],
            limit: 3
        )

        #expect(recentNames == [second.name, first.name])
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}

@discardableResult
private func isApproximatelyEqual(
    _ lhs: CGFloat,
    _ rhs: CGFloat,
    tolerance: CGFloat = 0.000001
) -> Bool {
    abs(lhs - rhs) <= tolerance
}

private func makeSolidTestImage(
    width: Int = 40,
    height: Int = 40,
    red: CGFloat = 0.2,
    green: CGFloat = 0.6,
    blue: CGFloat = 0.9
) -> UIImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}

private func normalizedPNGData(
    _ image: UIImage,
    size: CGSize = CGSize(width: 64, height: 64)
) -> Data? {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }.pngData()
}
