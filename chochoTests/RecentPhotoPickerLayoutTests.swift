import CoreGraphics
import Testing
@testable import chocho

struct RecentPhotoPickerLayoutTests {
    @Test func compactWidthsUseThreeColumns() {
        #expect(RecentPhotoPickerLayout.columnCount(forWidth: 390) == 3)
    }

    @Test func largeWidthsUseFourColumns() {
        #expect(RecentPhotoPickerLayout.columnCount(forWidth: 430) == 4)
    }
}
