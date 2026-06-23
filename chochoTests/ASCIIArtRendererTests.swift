import XCTest
@testable import chocho

final class ASCIIArtRendererTests: XCTestCase {
    func test_preset_characterSets_areNonEmpty() {
        for preset in ASCIIArtPreset.allCases {
            XCTAssertFalse(preset.fillCharacters.isEmpty,
                "\(preset.rawValue) fillCharacters should not be empty")
            XCTAssertFalse(String(preset.outlineCharacter).isEmpty,
                "\(preset.rawValue) outlineCharacter should not be empty")
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
}
