import XCTest
import UIKit
@testable import chocho

final class ASCIIArtRendererTests: XCTestCase {
    func test_preset_onlyKeepsHeartStarAndDots() {
        XCTAssertEqual(
            ASCIIArtPreset.allCases.map(\.title),
            ["爱心", "星星", "波点"]
        )
    }

    func test_preset_characterSets_areNonEmpty() {
        for preset in ASCIIArtPreset.allCases {
            XCTAssertFalse(preset.fillCharacters.isEmpty,
                "\(preset.rawValue) fillCharacters should not be empty")
        }
    }

    func test_cellRenderStyle_outlineUsesSubjectCharacterMapping() {
        var settings = ASCIIArtSettings.default
        settings.showOutline = true

        XCTAssertEqual(
            ASCIIArtRenderer.cellRenderStyle(
                avgBrightness: 0,
                subjectFraction: 1,
                isEdge: true,
                settings: settings,
                hasSubjectMask: true
            ),
            .outline(String(settings.preset.fillCharacters.first!))
        )
        XCTAssertEqual(
            ASCIIArtRenderer.cellRenderStyle(
                avgBrightness: 1,
                subjectFraction: 1,
                isEdge: true,
                settings: settings,
                hasSubjectMask: true
            ),
            .outline(String(settings.preset.fillCharacters.last!))
        )
    }

    func test_detail_cellSize_isPositive() {
        for detail in ASCIIArtDetail.allCases {
            XCTAssertGreaterThan(detail.cellSize, 0,
                "\(detail) cellSize should be > 0")
        }
    }

    func test_settings_default_usesMintCharacterColor() {
        XCTAssertFalse(ASCIIArtSettings.default.showSubject)
        XCTAssertTrue(ASCIIArtSettings.default.showOutline)
        let color = ASCIIArtSettings.defaultCharacterColor
        XCTAssertEqual(ASCIIArtSettings.default.characterColor, color)
    }

    func test_settings_decodesMissingCharacterColorAsDefault() throws {
        let json = """
        {
            "enabled": true,
            "preset": "softDots",
            "detail": "medium",
            "showOutline": false
        }
        """
        let settings = try JSONDecoder().decode(
            ASCIIArtSettings.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(settings.characterColor, ASCIIArtSettings.defaultCharacterColor)
        XCTAssertTrue(settings.showSubject)
        XCTAssertFalse(settings.showOutline)
    }

    func test_settings_default_isDisabled() {
        XCTAssertFalse(ASCIIArtSettings.default.enabled)
        XCTAssertEqual(ASCIIArtSettings.default.preset, .softDots)
        XCTAssertEqual(ASCIIArtSettings.default.detail, .coarse)
    }

    func test_brightnessToCharacter_darkMapsToFirstChar() {
        let preset = ASCIIArtPreset.softDots
        let char = ASCIIArtRenderer.character(for: 0.0, preset: preset)
        XCTAssertEqual(char, preset.fillCharacters.first)
    }

    func test_brightnessToCharacter_brightMapsToLastChar() {
        let preset = ASCIIArtPreset.softDots
        let char = ASCIIArtRenderer.character(for: 1.0, preset: preset)
        XCTAssertEqual(char, preset.fillCharacters.last)
    }

    func test_preset_decodesLegacyPresetAsSoftDots() throws {
        let data = Data("\"classicASCII\"".utf8)
        let preset = try JSONDecoder().decode(ASCIIArtPreset.self, from: data)
        XCTAssertEqual(preset, .softDots)
    }

    func test_cache_hitAfterSet() {
        let cache = ASCIIArtCache()
        let image = UIImage()
        cache.setImage(image, for: "key1")
        XCTAssertNotNil(cache.image(for: "key1"))
    }

    func test_cache_missWhenEmpty() {
        let cache = ASCIIArtCache()
        XCTAssertNil(cache.image(for: "missing"))
    }

    func test_previewPolicy_downscalesLargeImage() {
        let large = CGSize(width: 3000, height: 4000)
        let result = ASCIIArtPreviewRenderPolicy.pixelSize(for: large)
        XCTAssertEqual(result, CGSize(width: 1080, height: 1440))
        XCTAssertLessThanOrEqual(max(result.width, result.height), ASCIIArtPreviewRenderPolicy.maxLongEdge)
    }

    func test_sourceKey_distinguishesSameSizedImages() throws {
        let red = try XCTUnwrap(makeSolidImage(width: 8, height: 8, color: .red))
        let blue = try XCTUnwrap(makeSolidImage(width: 8, height: 8, color: .blue))

        XCTAssertNotEqual(
            ASCIIArtRenderer.sourceKey(for: red),
            ASCIIArtRenderer.sourceKey(for: blue)
        )
    }

    func test_scaledCellSize_preservesSourceGridAcrossPreviewAndExport() {
        let sourceSize = CGSize(width: 3000, height: 4000)
        let previewSize = ASCIIArtPreviewRenderPolicy.pixelSize(for: sourceSize)
        let detail = ASCIIArtDetail.medium

        let previewCellSize = ASCIIArtRenderer.cellSize(
            for: detail,
            sourcePixelSize: sourceSize,
            renderSize: previewSize
        )
        let exportCellSize = ASCIIArtRenderer.cellSize(
            for: detail,
            sourcePixelSize: sourceSize,
            renderSize: sourceSize
        )

        XCTAssertEqual(
            ceil(previewSize.width / previewCellSize),
            ceil(sourceSize.width / exportCellSize),
            accuracy: 0.001
        )
        XCTAssertEqual(
            ceil(previewSize.height / previewCellSize),
            ceil(sourceSize.height / exportCellSize),
            accuracy: 0.001
        )
    }

    func test_cellRenderStyle_subjectOnlyDrawsInsideSubject() {
        var settings = ASCIIArtSettings.default
        settings.enabled = true
        settings.showSubject = true
        settings.showOutline = false

        XCTAssertEqual(
            ASCIIArtRenderer.cellRenderStyle(
                avgBrightness: 0,
                subjectFraction: 1,
                isEdge: false,
                settings: settings,
                hasSubjectMask: true
            ),
            .subject(String(settings.preset.fillCharacters.first!))
        )
        XCTAssertNil(ASCIIArtRenderer.cellRenderStyle(
            avgBrightness: 0,
            subjectFraction: 0,
            isEdge: false,
            settings: settings,
            hasSubjectMask: true
        ))
    }

    func test_cellRenderStyle_withoutSubjectMaskDrawsFullFrame() {
        var settings = ASCIIArtSettings.default
        settings.enabled = true
        settings.showSubject = false
        settings.showOutline = false

        XCTAssertEqual(
            ASCIIArtRenderer.cellRenderStyle(
                avgBrightness: 1,
                subjectFraction: 0,
                isEdge: false,
                settings: settings,
                hasSubjectMask: false
            ),
            .subject(String(settings.preset.fillCharacters.last!))
        )
    }

    func test_outlineDilationRadius_scalesWithCellSize() {
        XCTAssertEqual(ASCIIArtRenderer.outlineDilationRadius(for: 24), 11)
        XCTAssertEqual(ASCIIArtRenderer.outlineDilationRadius(for: 8), 4)
        XCTAssertEqual(ASCIIArtRenderer.outlineDilationRadius(for: 1), 1)
    }

    func test_styledPreviewEnabled_withASCII() {
        var settings = ASCIIArtSettings.default
        settings.enabled = true
        let enabled = CanvasStyledPhotoRenderer.styledPreviewEnabled(
            y2kCCDFilterSettings: .default,
            asciiArtSettings: settings
        )
        XCTAssertTrue(enabled)
    }

    func test_styledPreviewEnabled_allDisabled() {
        let enabled = CanvasStyledPhotoRenderer.styledPreviewEnabled(
            y2kCCDFilterSettings: .default,
            asciiArtSettings: .default
        )
        XCTAssertFalse(enabled)
    }

    func test_styledRendererRecomputesASCIIWhenUpstreamCCDChanges() throws {
        let source = try XCTUnwrap(makeGradientImage(width: 96, height: 64))
        let asciiCache = ASCIIArtCache()
        let sourceKey = "style-pipeline-test"
        var asciiSettings = ASCIIArtSettings.default
        asciiSettings.enabled = true
        asciiSettings.showSubject = true
        asciiSettings.showOutline = false

        let asciiOnly = CanvasStyledPhotoRenderer.renderSync(
            image: source,
            y2kCCDFilterSettings: .default,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourceKey: sourceKey,
            asciiArtSettings: asciiSettings,
            asciiArtCache: asciiCache
        )

        var ccdSettings = Y2KCCDFilterSettings.default
        ccdSettings.enabled = true
        ccdSettings.preset = .warm
        ccdSettings.intensity = 1

        let asciiAfterCCD = CanvasStyledPhotoRenderer.renderSync(
            image: source,
            y2kCCDFilterSettings: ccdSettings,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourceKey: sourceKey,
            asciiArtSettings: asciiSettings,
            asciiArtCache: asciiCache
        )

        XCTAssertNotEqual(asciiOnly.pngData(), asciiAfterCCD.pngData())
    }

    func test_asciiGridKeepsOriginalSourceScaleWhenCCDIsEnabled() throws {
        let source = try XCTUnwrap(makeSolidImage(width: 192, height: 128, color: .white))
        var asciiSettings = ASCIIArtSettings.default
        asciiSettings.enabled = true
        asciiSettings.showSubject = false
        asciiSettings.showOutline = false
        asciiSettings.characterColor = CanvasDraftColorComponents(red: 0, green: 0, blue: 0)

        var ccdSettings = Y2KCCDFilterSettings.default
        ccdSettings.enabled = true
        ccdSettings.intensity = 1

        let styledImage = CanvasStyledPhotoRenderer.renderSync(
            image: source,
            y2kCCDFilterSettings: ccdSettings,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourceKey: "ascii-grid-scale-test",
            asciiArtSettings: asciiSettings
        )
        let ccdImage = try XCTUnwrap(Y2KCCDFilterRenderer.render(
            image: source,
            settings: ccdSettings,
            targetPixelSize: CGSize(width: 96, height: 64)
        ))
        let expectedImage = try XCTUnwrap(ASCIIArtRenderer.render(
            image: ccdImage,
            mask: nil,
            settings: asciiSettings,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourcePixelSize: CGSize(width: 192, height: 128),
            sourceKey: "ascii-grid-scale-test-ccd-\(ccdSettings.cacheKey)-ascii-none"
        ))
        let wrongScaleImage = try XCTUnwrap(ASCIIArtRenderer.render(
            image: ccdImage,
            mask: nil,
            settings: asciiSettings,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourceKey: "ascii-grid-scale-wrong"
        ))

        XCTAssertEqual(styledImage.pngData(), expectedImage.pngData())
        XCTAssertNotEqual(expectedImage.pngData(), wrongScaleImage.pngData())
    }

    func test_asciiGridUsesCompressedSourceScaleWhenPhotoCompressionIsEnabled() throws {
        let source = try XCTUnwrap(makeSolidImage(width: 192, height: 128, color: .white))
        var asciiSettings = ASCIIArtSettings.default
        asciiSettings.enabled = true
        asciiSettings.showSubject = false
        asciiSettings.showOutline = false
        asciiSettings.characterColor = CanvasDraftColorComponents(red: 0, green: 0, blue: 0)

        var ccdSettings = Y2KCCDFilterSettings.default
        ccdSettings.enabled = true
        ccdSettings.intensity = 1

        let styledImage = CanvasStyledPhotoRenderer.renderSync(
            image: source,
            y2kCCDFilterSettings: ccdSettings,
            targetPixelSize: CGSize(width: 96, height: 64),
            sourceKey: "ascii-compressed-grid-scale-test",
            asciiArtSettings: asciiSettings,
            photoCompression: .narrowed
        )
        let ccdImage = try XCTUnwrap(Y2KCCDFilterRenderer.render(
            image: source,
            settings: ccdSettings,
            targetPixelSize: CGSize(width: 96, height: 64)
        ))
        let compressedCCDImage = try XCTUnwrap(CanvasImageLoader.resampledImage(
            ccdImage,
            to: CGSize(width: 60, height: 64)
        ))
        let expectedImage = try XCTUnwrap(ASCIIArtRenderer.render(
            image: compressedCCDImage,
            mask: nil,
            settings: asciiSettings,
            targetPixelSize: CGSize(width: 60, height: 64),
            sourcePixelSize: CGSize(width: 120, height: 128),
            sourceKey: "ascii-compressed-grid-scale-test-ccd-\(ccdSettings.cacheKey)-ascii-narrowed"
        ))
        let uncompressedScaleImage = try XCTUnwrap(ASCIIArtRenderer.render(
            image: compressedCCDImage,
            mask: nil,
            settings: asciiSettings,
            targetPixelSize: CGSize(width: 60, height: 64),
            sourcePixelSize: CGSize(width: 192, height: 128),
            sourceKey: "ascii-compressed-grid-scale-wrong"
        ))

        XCTAssertEqual(styledImage.pngData(), expectedImage.pngData())
        XCTAssertNotEqual(expectedImage.pngData(), uncompressedScaleImage.pngData())
    }

    private func makeSolidImage(width: Int, height: Int, color: UIColor) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    private func makeGradientImage(width: Int, height: Int) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                for y in 0..<height {
                    for x in 0..<width {
                        UIColor(
                            red: CGFloat((x * 29 + y * 11) % 256) / 255,
                            green: CGFloat((x * 7 + y * 31) % 256) / 255,
                            blue: CGFloat((x * 17 + y * 13) % 256) / 255,
                            alpha: 1
                        ).setFill()
                        context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
    }

}
