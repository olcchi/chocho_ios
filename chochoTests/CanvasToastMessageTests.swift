import Testing
@testable import chocho

struct CanvasToastMessageTests {
    @Test func createsDistinctMessagesForRepeatedText() {
        let first = CanvasToastMessage("已保存到相册")
        let second = CanvasToastMessage("已保存到相册")

        #expect(first.title == "已保存到相册")
        #expect(second.title == "已保存到相册")
        #expect(first.id != second.id)
    }

    @Test func usesConsistentDefaultDisplayDuration() {
        let message = CanvasToastMessage("导出失败")

        #expect(message.duration == .seconds(2.2))
    }
}
