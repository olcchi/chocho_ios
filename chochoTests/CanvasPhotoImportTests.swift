import Testing
@testable import chocho

struct CanvasPhotoImportTests {
    @Test func livePhotoKindIsDistinctFromStillImage() {
        #expect(CanvasPhotoImport.Kind.stillImage != .livePhoto)
    }

    @Test func isLivePhotoKindMapping() {
        #expect(CanvasPhotoSource.isLivePhotoKind(.livePhoto))
        #expect(!CanvasPhotoSource.isLivePhotoKind(.stillImage))
    }

    @Test func resolvedKindUsesAssetSubtypeWhenContentTypesMissLivePhoto() {
        #expect(
            CanvasPhotoImport.resolvedKind(
                contentTypesIncludeLivePhoto: false,
                assetHasPhotoLiveSubtype: true
            ) == .livePhoto
        )
    }

    @Test func resolvedKindUsesContentTypesWhenAssetSubtypeUnavailable() {
        #expect(
            CanvasPhotoImport.resolvedKind(
                contentTypesIncludeLivePhoto: true,
                assetHasPhotoLiveSubtype: false
            ) == .livePhoto
        )
    }

    @Test func resolvedKindUsesPairedVideoResourceWhenSubtypeUnavailable() {
        #expect(
            CanvasPhotoImport.resolvedKind(
                contentTypesIncludeLivePhoto: false,
                assetHasPhotoLiveSubtype: false,
                assetHasPairedVideo: true
            ) == .livePhoto
        )
    }

    @Test func resolvedKindReturnsStillImageWhenNeitherSignalMatches() {
        #expect(
            CanvasPhotoImport.resolvedKind(
                contentTypesIncludeLivePhoto: false,
                assetHasPhotoLiveSubtype: false,
                assetHasPairedVideo: false
            ) == .stillImage
        )
    }
}
