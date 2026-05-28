import Photos
import UIKit

/// 分享页承载的导出结果：静图文件 URL，或可分享的 `PHLivePhoto` 及临时资源路径。
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
