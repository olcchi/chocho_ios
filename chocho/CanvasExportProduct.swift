import Photos
import UIKit

enum CanvasExportProduct {
    case stillImage(URL)
    case livePhoto(CanvasLivePhotoExportBundle)

    var shareItems: [Any] {
        switch self {
        case .stillImage(let fileURL):
            [fileURL]
        case .livePhoto(let bundle):
            [bundle.livePhoto]
        }
    }

    func removeTemporaryFiles() {
        switch self {
        case .stillImage(let fileURL):
            try? FileManager.default.removeItem(at: fileURL)
        case .livePhoto(let bundle):
            bundle.removeTemporaryFiles()
        }
    }
}
