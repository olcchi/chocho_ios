import AVFoundation
import Photos
import UIKit

/// 相册 Live Photo 的配对视频；供预览 Timeline 与导出逐帧合成读取。
nonisolated final class CanvasSourceLiveVideo: @unchecked Sendable {
    let duration: TimeInterval
    private let videoURL: URL
    private let generator: AVAssetImageGenerator
    private let lock = NSLock()
    private var cachedSourceTime: TimeInterval?
    private var cachedFrame: UIImage?

    private init(videoURL: URL, duration: TimeInterval, generator: AVAssetImageGenerator) {
        self.videoURL = videoURL
        self.duration = duration
        self.generator = generator
    }

    static func load(assetLocalIdentifier: String?) async -> CanvasSourceLiveVideo? {
        guard let assetLocalIdentifier,
              let phAsset = CanvasPhotoImport.asset(for: assetLocalIdentifier) else {
            return nil
        }

        guard let videoURL = await exportPairedVideo(from: phAsset) else {
            return nil
        }

        let avAsset = AVURLAsset(url: videoURL)
        let loadedDuration: TimeInterval
        do {
            loadedDuration = try await avAsset.load(.duration).seconds
        } catch {
            try? FileManager.default.removeItem(at: videoURL)
            return nil
        }

        guard loadedDuration > 0 else {
            try? FileManager.default.removeItem(at: videoURL)
            return nil
        }

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.02, preferredTimescale: 600)
        // 预览帧只需屏幕分辨率；不限制时 generator 返回视频原始分辨率（可达 4K+），
        // 对 ~390pt 宽的画布来说是大量冗余解码和内存占用。
        // 导出路径使用 CanvasRasterExporter 独立解码，此限制不影响导出质量。
        let previewPixelSize = Self.previewMaxPixelSize()
        generator.maximumSize = CGSize(width: previewPixelSize, height: previewPixelSize)

        return CanvasSourceLiveVideo(
            videoURL: videoURL,
            duration: loadedDuration,
            generator: generator
        )
    }

    /// 将画布时间轴时刻映射到源视频时刻；时间轴与原片等长时不循环。
    static func sourceTime(
        timelineTime: TimeInterval,
        timelineDuration: TimeInterval,
        sourceDuration: TimeInterval
    ) -> TimeInterval {
        guard sourceDuration > 0 else { return 0 }

        let clampedTimelineTime = max(0, timelineTime)
        if timelineDuration > 0, timelineDuration <= sourceDuration + 0.001 {
            return min(clampedTimelineTime, sourceDuration)
        }

        return clampedTimelineTime.truncatingRemainder(dividingBy: sourceDuration)
    }

    func frame(at timelineTime: TimeInterval, timelineDuration: TimeInterval) -> UIImage? {
        let mappedTime = Self.sourceTime(
            timelineTime: timelineTime,
            timelineDuration: timelineDuration,
            sourceDuration: duration
        )

        lock.lock()
        if let cachedSourceTime,
           let cachedFrame,
           abs(cachedSourceTime - mappedTime) < 0.012 {
            let frame = cachedFrame
            lock.unlock()
            return frame
        }
        lock.unlock()

        let cmTime = CMTime(seconds: mappedTime, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) else {
            return nil
        }

        let frame = UIImage(cgImage: cgImage, scale: 1, orientation: .up)

        lock.lock()
        cachedSourceTime = mappedTime
        cachedFrame = frame
        lock.unlock()

        return frame
    }

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: videoURL)
    }

    /// 预览帧输出的最大边（像素）：取主屏幕短边像素的 1.5 倍，覆盖全屏竖排展示所需，
    /// 同时对横向超宽视频也保持合理上限。主屏为空时回退到 1280。
    private static func previewMaxPixelSize() -> Int {
        let screen = UIScreen.main
        let scale = screen.scale
        let shortEdge = min(screen.bounds.width, screen.bounds.height)
        let pixels = Int((shortEdge * scale * 1.5).rounded())
        return max(pixels, 1280)
    }

    private static func exportPairedVideo(from asset: PHAsset) async -> URL? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .pairedVideo }) else {
            return nil
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-source-live-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        try? FileManager.default.removeItem(at: fileURL)

        return await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: fileURL,
                options: options
            ) { error in
                if error != nil {
                    try? FileManager.default.removeItem(at: fileURL)
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }
}

nonisolated enum CanvasLiveMotionTiming {
    static func exportDuration(
        liveDotAnimation: LiveDotAnimation,
        isSourceLiveMotionEnabled: Bool,
        sourceLiveVideoDuration: TimeInterval?
    ) -> TimeInterval {
        if isSourceLiveMotionEnabled,
           let sourceLiveVideoDuration,
           sourceLiveVideoDuration > 0 {
            return sourceLiveVideoDuration
        }
        if liveDotAnimation != .none {
            return liveDotAnimation.motionExportDuration
        }
        return 0
    }

    static func exportsAsLivePhoto(
        liveDotAnimation: LiveDotAnimation,
        isSourceLiveMotionEnabled: Bool,
        hasSourceLiveVideo: Bool
    ) -> Bool {
        if liveDotAnimation.exportsAsLivePhoto {
            return true
        }
        return isSourceLiveMotionEnabled && hasSourceLiveVideo
    }

    static func canPlayLivePreview(
        liveDotAnimation: LiveDotAnimation,
        isSourceLiveMotionEnabled: Bool,
        isSourceLivePhoto: Bool,
        hasSourceLiveVideo: Bool
    ) -> Bool {
        if liveDotAnimation != .none {
            return true
        }
        return isSourceLiveMotionEnabled && isSourceLivePhoto && hasSourceLiveVideo
    }
}
