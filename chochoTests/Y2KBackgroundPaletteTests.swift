import Foundation
import Testing
@testable import chocho

struct Y2KBackgroundPaletteTests {
    @Test func pairsCatalogHasThirtyEntries() {
        #expect(Y2KBackgroundPalette.pairs.count == 30)
    }

    @Test func shuffledIndicesIsPermutation() {
        let indices = Y2KBackgroundPalette.shuffledIndices()
        #expect(indices.count == 30)
        #expect(Set(indices) == Set(0..<30))
    }

    @Test func rowShowsNineColorBallsAndFillsWidth() {
        #expect(Y2KBackgroundPalette.colorBallCountPerRow == 9)
        #expect(Y2KBackgroundPalette.slotCountPerRow == 10)

        let width: CGFloat = 343
        let ballSize = Y2KBackgroundPalette.ballSize(availableWidth: width)
        let usedWidth = ballSize * CGFloat(Y2KBackgroundPalette.slotCountPerRow)
            + 6 * CGFloat(Y2KBackgroundPalette.slotCountPerRow - 1)
        #expect(abs(usedWidth - width) < 0.5)
    }

    @Test func applyUpdatesGridColors() {
        let pair = Y2KBackgroundPalette.pairs[0]
        var colors = PuzzleBackgroundColors.default
        Y2KBackgroundPalette.apply(pair, to: &colors, style: .grid)
        #expect(colors.fillColor == pair.fill)
        #expect(colors.lineColor == pair.accent)
    }

    @Test func applyUpdatesStripeColors() {
        let pair = Y2KBackgroundPalette.pairs[1]
        var colors = PuzzleBackgroundColors.default
        Y2KBackgroundPalette.apply(pair, to: &colors, style: .stripes)
        #expect(colors.fillColor == pair.fill)
        #expect(colors.alternateColor == pair.accent)
    }
}
