import XCTest
@testable import chocho

final class ASCIIArtRendererTests: XCTestCase {
    func test_preset_characterSets_areNonEmpty() {
        for preset in ASCIIArtPreset.allCases {
            XCTAssertFalse(preset.fillCharacters.isEmpty,
                "\(preset.rawValue) fillCharacters should not be empty")
            XCTAssertNotEqual(preset.outlineCharacter, Character(" "),
                "\(preset.rawValue) outlineCharacter should not be a space")
        }
    }

    func test_detail_cellSize_isPositive() {
        for detail in ASCIIArtDetail.allCases {
            XCTAssertGreaterThan(detail.cellSize, 0,
                "\(detail) cellSize should be > 0")
        }
    }

    func test_settings_default_isDisabled() {
        XCTAssertFalse(ASCIIArtSettings.default.enabled)
        XCTAssertEqual(ASCIIArtSettings.default.preset, .softDots)
    }

    func test_brightnessToCharacter_darkMapsToFirstChar() {
        let preset = ASCIIArtPreset.classicASCII
        let char = ASCIIArtRenderer.character(for: 0.0, preset: preset)
        XCTAssertEqual(char, preset.fillCharacters.first)
    }

    func test_brightnessToCharacter_brightMapsToLastChar() {
        let preset = ASCIIArtPreset.classicASCII
        let char = ASCIIArtRenderer.character(for: 1.0, preset: preset)
        XCTAssertEqual(char, preset.fillCharacters.last)
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
        XCTAssertLessThanOrEqual(max(result.width, result.height), ASCIIArtPreviewRenderPolicy.maxLongEdge)
    }

    func test_styledPreviewEnabled_withASCII() {
        var settings = ASCIIArtSettings.default
        settings.enabled = true
        let enabled = CanvasStyledPhotoRenderer.styledPreviewEnabled(
            subjectGlowSettings: .default,
            y2kCCDFilterSettings: .default,
            asciiArtSettings: settings
        )
        XCTAssertTrue(enabled)
    }

    func test_styledPreviewEnabled_allDisabled() {
        let enabled = CanvasStyledPhotoRenderer.styledPreviewEnabled(
            subjectGlowSettings: .default,
            y2kCCDFilterSettings: .default,
            asciiArtSettings: .default
        )
        XCTAssertFalse(enabled)
    }
}
