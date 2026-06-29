import Testing
import SwiftUI
import UIKit
@testable import chocho

struct CanvasRasterExporterTests {
    @Test func rendersNonEmptyImageAtExportSize() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: PuzzleDotFactory.makeDots(count: 4),
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        #expect(exported.size == exportSize)
        #expect(exported.cgImage != nil)
    }

    @Test func rightExtensionExportHasNoLeadingBlankMargin() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(makeExportedImage(source: source, extensionSide: .right))

        #expect(sampleColor(in: exported, at: CGPoint(x: 1, y: 150)).isClose(to: .sourceBlue))
        #expect(sampleColor(in: exported, at: CGPoint(x: 478, y: 150)).isClose(to: .extensionBackground))
    }

    @Test func leftExtensionExportHasNoTrailingBlankMargin() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(makeExportedImage(source: source, extensionSide: .left))

        #expect(sampleColor(in: exported, at: CGPoint(x: 1, y: 150)).isClose(to: .extensionBackground))
        #expect(sampleColor(in: exported, at: CGPoint(x: 478, y: 150)).isClose(to: .sourceBlue))
    }

    @Test func topExtensionExportHasNoBottomBlankMargin() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(makeExportedImage(
            source: source,
            exportSize: CGSize(width: 400, height: 360),
            extensionSide: .top
        ))

        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 1)).isClose(to: .extensionBackground))
        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 358)).isClose(to: .sourceBlue))
    }

    @Test func centerBackgroundExportPlacesPhotoAboveLargerBackground() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 400, height: 300),
                extensionRatio: 0.15,
                extensionSide: .center,
                backgroundStyle: .solid,
                backgroundColors: PuzzleBackgroundColors(
                    fillColor: Color(red: 1, green: 0, blue: 0),
                    alternateColor: Color(red: 0, green: 1, blue: 0),
                    lineColor: Color(red: 0, green: 0, blue: 1)
                ),
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 4, y: 4)).isClose(to: .red))
        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 150)).isClose(to: .sourceBlue))
    }

    @Test func centerBackgroundDotsAreOccludedByPhoto() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.25, y: 0.5),
            color: .clear,
            size: 8,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )
        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 400, height: 300),
                extensionRatio: 0.4,
                extensionSide: .center,
                backgroundStyle: .solid,
                backgroundColors: PuzzleBackgroundColors(
                    fillColor: .red,
                    alternateColor: .green,
                    lineColor: .red
                ),
                dots: [dot],
                dotScale: 1,
                dotColor: .red,
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 100, y: 150)).isClose(to: .sourceBlue))
    }

    @Test func liveExportAnimatesExtensionSideMirrorDots() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.25, y: 0.5),
            color: .clear,
            size: 10,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )

        let dimFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false,
                liveDotAnimation: .randomBlink,
                blinkTime: 0.15
            )
        )
        let brightFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false,
                liveDotAnimation: .randomBlink,
                blinkTime: 1.05
            )
        )

        let samplePoint = CGPoint(x: 430, y: 150)
        let dimSample = sampleColor(in: dimFrame, at: samplePoint)
        let brightSample = sampleColor(in: brightFrame, at: samplePoint)
        #expect(dimSample != brightSample)
    }

    @Test func breatheAnimationChangesRasterizedDotAppearance() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.25, y: 0.5),
            color: .clear,
            size: 10,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )

        let contractedFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false,
                liveDotAnimation: .breathe,
                blinkTime: 2.05
            )
        )
        let expandedFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false,
                liveDotAnimation: .breathe,
                blinkTime: 0.35
            )
        )

        let samplePoint = CGPoint(x: 430, y: 150)
        #expect(
            sampleColor(in: contractedFrame, at: samplePoint)
                != sampleColor(in: expandedFrame, at: samplePoint)
        )
    }

    @Test func rotateAnimationRotatesRasterizedDotAroundItsCenter() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 400, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 10,
            shapeAssetName: BuiltInDotShape.lightning.rawValue
        )

        let initialFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false,
                liveDotAnimation: .rotate,
                blinkTime: 0
            )
        )
        let quarterTurnFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false,
                liveDotAnimation: .rotate,
                blinkTime: 0.75
            )
        )

        #expect(
            containsDifferentPixels(
                in: initialFrame,
                and: quarterTurnFrame,
                rect: CGRect(x: 150, y: 100, width: 100, height: 100)
            )
        )
    }

    @Test func characterDotRendersTypedTextInRasterExport() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 12,
            shapeAssetName: DotShapeAsset.characterSelection.name
        )
        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false,
                dotCharacterText: "字"
            )
        )

        #expect(
            containsDifferentColor(
                in: exported,
                rect: CGRect(x: 170, y: 110, width: 60, height: 80),
                from: .sourceBlue
            )
        )
    }

    @Test func textBubbleStyleRendersOnRasterExport() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false,
                textBubbleSettings: TextBubbleSettings(
                    enabled: true,
                    bubbles: [
                        TextBubbleItem(
                            text: "雀巢咖啡自营店",
                            centerX: 0.28,
                            centerY: 0.2
                        )
                    ]
                )
            )
        )

        #expect(
            containsDifferentColor(
                in: exported,
                rect: CGRect(x: 34, y: 24, width: 170, height: 60),
                from: .sourceBlue
            )
        )
    }

    @Test func characterDotUsesCollageTintWhenDotColorIsClear() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 12,
            shapeAssetName: DotShapeAsset.characterSelection.name
        )

        let collageFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false,
                dotCharacterText: "字"
            )
        )
        let blackFrame = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false,
                dotCharacterText: "字"
            )
        )

        #expect(
            containsDifferentPixels(
                in: collageFrame,
                and: blackFrame,
                rect: CGRect(x: 170, y: 110, width: 60, height: 80)
            )
        )
        #expect(sampleColor(in: collageFrame, at: CGPoint(x: 145, y: 95)).isClose(to: .sourceBlue))
    }

    @Test func clearColorAssetDotMasksCollageToShapeOnly() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 12,
            shapeAssetName: "shapes/像素/像素7"
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 150)) != .sourceBlue)
        #expect(sampleColor(in: exported, at: CGPoint(x: 160, y: 110)).isClose(to: .sourceBlue))
    }

    @Test func clearColorSVGAssetDotMasksCollageToShapeOnly() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exportSize = CGSize(width: 480, height: 300)
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 12,
            shapeAssetName: "shapes/基础/星1"
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: exportSize,
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                dots: [dot],
                dotScale: 8,
                dotColor: .clear,
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 150)) != .sourceBlue)
        #expect(sampleColor(in: exported, at: CGPoint(x: 160, y: 110)).isClose(to: .sourceBlue))
    }

    @Test func zeroExtensionHalftoneCollageDotStillRendersOnPhoto() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let dot = PuzzleDot(
            id: UUID(),
            position: CGPoint(x: 0.5, y: 0.5),
            color: .clear,
            size: 12,
            shapeAssetName: BuiltInDotShape.circle.rawValue
        )
        let baseline = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 400, height: 300),
                extensionRatio: 0,
                extensionSide: .right,
                backgroundStyle: .halftone,
                dots: [],
                dotScale: 10,
                dotColor: .clear,
                usesRandomDotColors: false
            )
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 400, height: 300),
                extensionRatio: 0,
                extensionSide: .right,
                backgroundStyle: .halftone,
                dots: [dot],
                dotScale: 10,
                dotColor: .clear,
                usesRandomDotColors: false
            )
        )

        #expect(
            sampleColor(in: exported, at: CGPoint(x: 200, y: 150))
                != sampleColor(in: baseline, at: CGPoint(x: 200, y: 150))
        )
    }

    @Test func bottomExtensionExportHasNoTopBlankMargin() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let exported = try #require(makeExportedImage(
            source: source,
            exportSize: CGSize(width: 400, height: 360),
            extensionSide: .bottom
        ))

        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 1)).isClose(to: .sourceBlue))
        #expect(sampleColor(in: exported, at: CGPoint(x: 200, y: 358)).isClose(to: .extensionBackground))
    }

    @Test func customBackgroundPatternSpacingChangesGridCellSize() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let colors = PuzzleBackgroundColors(
            fillColor: Color(red: 1, green: 0, blue: 0),
            alternateColor: Color(red: 0, green: 1, blue: 0),
            lineColor: Color(red: 0, green: 0, blue: 1)
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .grid,
                backgroundColors: colors,
                backgroundPatternSpacing: 24,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        // 扩展区宽 80pt（x≥400），间距 24：x=410 为格内底色，x=424 落在竖线上。
        #expect(sampleColor(in: exported, at: CGPoint(x: 410, y: 12)).isClose(to: .red))
        #expect(sampleColor(in: exported, at: CGPoint(x: 424, y: 12)).isClose(to: .lineBlue))
    }

    @Test func solidBackgroundExportUsesOnlyFillColorInExtensionArea() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let colors = PuzzleBackgroundColors(
            fillColor: Color(red: 1, green: 0, blue: 0),
            alternateColor: Color(red: 0, green: 1, blue: 0),
            lineColor: Color(red: 0, green: 0, blue: 1)
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .solid,
                backgroundColors: colors,
                backgroundPatternSpacing: 8,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 410, y: 12)).isClose(to: .red))
        #expect(sampleColor(in: exported, at: CGPoint(x: 424, y: 12)).isClose(to: .red))
        #expect(sampleColor(in: exported, at: CGPoint(x: 440, y: 150)).isClose(to: .red))
    }

    @Test func customBackgroundPatternSpacingChangesStripeThickness() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let colors = PuzzleBackgroundColors(
            fillColor: Color(red: 1, green: 0, blue: 0),
            alternateColor: Color(red: 0, green: 1, blue: 0),
            lineColor: Color(red: 0, green: 0, blue: 1)
        )

        let exported = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .stripes,
                backgroundColors: colors,
                backgroundPatternSpacing: 24,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: exported, at: CGPoint(x: 440, y: 18)).isClose(to: .red))
        #expect(sampleColor(in: exported, at: CGPoint(x: 440, y: 30)).isClose(to: .green))
    }

    @Test func customBackgroundPatternSpacingChangesPolkaDotSizeAndDensity() throws {
        let source = try #require(makeSolidImage(width: 400, height: 300))
        let colors = PuzzleBackgroundColors(
            fillColor: Color(red: 1, green: 0, blue: 0),
            alternateColor: Color(red: 0, green: 1, blue: 0),
            lineColor: Color(red: 0, green: 0, blue: 1)
        )

        let smallDots = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .polkaDots,
                backgroundColors: colors,
                backgroundPatternSpacing: 8,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )
        let largeDots = try #require(
            CanvasRasterExporter.render(
                image: source,
                exportSize: CGSize(width: 480, height: 300),
                extensionRatio: 0.2,
                extensionSide: .right,
                backgroundStyle: .polkaDots,
                backgroundColors: colors,
                backgroundPatternSpacing: 24,
                dots: [],
                dotScale: 8,
                dotColor: Color(red: 0, green: 0, blue: 0),
                usesRandomDotColors: false
            )
        )

        #expect(sampleColor(in: smallDots, at: CGPoint(x: 408, y: 8)).isClose(to: .lineBlue))
        #expect(sampleColor(in: largeDots, at: CGPoint(x: 408, y: 8)).isClose(to: .red))
    }
}

private func makeExportedImage(
    source: UIImage,
    exportSize: CGSize = CGSize(width: 480, height: 300),
    extensionSide: PuzzleCanvasExtensionSide
) -> UIImage? {
    CanvasRasterExporter.render(
        image: source,
        exportSize: exportSize,
        extensionRatio: 0.2,
        extensionSide: extensionSide,
        backgroundStyle: .stripes,
        dots: [],
        dotScale: 8,
        dotColor: Color(red: 0, green: 0, blue: 0),
        usesRandomDotColors: false
    )
}

private func containsDifferentColor(
    in image: UIImage,
    rect: CGRect,
    from expected: SampledColor
) -> Bool {
    let minX = Int(rect.minX)
    let maxX = Int(rect.maxX)
    let minY = Int(rect.minY)
    let maxY = Int(rect.maxY)

    for y in stride(from: minY, through: maxY, by: 4) {
        for x in stride(from: minX, through: maxX, by: 4) {
            if !sampleColor(in: image, at: CGPoint(x: x, y: y)).isClose(to: expected) {
                return true
            }
        }
    }

    return false
}

private func containsDifferentPixels(
    in lhs: UIImage,
    and rhs: UIImage,
    rect: CGRect
) -> Bool {
    let minX = Int(rect.minX)
    let maxX = Int(rect.maxX)
    let minY = Int(rect.minY)
    let maxY = Int(rect.maxY)

    for y in stride(from: minY, through: maxY, by: 4) {
        for x in stride(from: minX, through: maxX, by: 4) {
            let point = CGPoint(x: x, y: y)
            if sampleColor(in: lhs, at: point) != sampleColor(in: rhs, at: point) {
                return true
            }
        }
    }

    return false
}

private struct SampledColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let sourceBlue = SampledColor(red: 51, green: 153, blue: 230)
    static let extensionBackground = SampledColor(red: 238, green: 247, blue: 221)
    static let red = SampledColor(red: 255, green: 0, blue: 0)
    static let green = SampledColor(red: 0, green: 255, blue: 0)
    static let lineBlue = SampledColor(red: 0, green: 0, blue: 255)

    func isClose(to expected: SampledColor, tolerance: UInt8 = 3) -> Bool {
        abs(Int(red) - Int(expected.red)) <= Int(tolerance)
            && abs(Int(green) - Int(expected.green)) <= Int(tolerance)
            && abs(Int(blue) - Int(expected.blue)) <= Int(tolerance)
    }
}

private func sampleColor(in image: UIImage, at point: CGPoint) -> SampledColor {
    guard let cgImage = image.cgImage,
          let dataProvider = cgImage.dataProvider,
          let data = dataProvider.data,
          let bytes = CFDataGetBytePtr(data) else {
        return SampledColor(red: 0, green: 0, blue: 0)
    }

    let x = min(max(Int(point.x), 0), cgImage.width - 1)
    let y = min(max(Int(point.y), 0), cgImage.height - 1)
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let offset = y * cgImage.bytesPerRow + x * bytesPerPixel

    return SampledColor(
        red: bytes[offset],
        green: bytes[offset + 1],
        blue: bytes[offset + 2]
    )
}

private func makeSolidImage(width: Int, height: Int) -> UIImage? {
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

    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}
