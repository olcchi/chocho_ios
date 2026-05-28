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

private struct SampledColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let sourceBlue = SampledColor(red: 51, green: 153, blue: 230)
    static let extensionBackground = SampledColor(red: 238, green: 247, blue: 221)

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
