import AVFoundation
import Photos
import UIKit

/// Live Photo 导出产物：可预览的 `PHLivePhoto` 及写入磁盘的 JPG/MOV 临时路径。
nonisolated struct CanvasLivePhotoExportBundle {
    let livePhoto: PHLivePhoto
    let imageURL: URL
    let videoURL: URL

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: videoURL)
    }
}

/// Live Photo 尺寸策略：关键帧用全尺寸导出，配对视频最长边 1080、15fps（接近系统相机）。
nonisolated enum CanvasLivePhotoSizing {
    static let videoMaxPixelDimension = 1080
    static let videoFrameRate: Int32 = 15

    static func videoEncodeSize(for keyPhotoSize: CGSize) -> CGSize {
        let fitted = CanvasImageLoader.fittedPixelSize(
            keyPhotoSize,
            maxPixelDimension: videoMaxPixelDimension
        )
        return CGSize(
            width: CGFloat(evenDimension(fitted.width)),
            height: CGFloat(evenDimension(fitted.height))
        )
    }

    static func evenDimension(_ value: CGFloat) -> Int {
        let rounded = max(2, Int(value.rounded()))
        return rounded - (rounded % 2)
    }
}

/// 1) 渲染关键帧并写入带 asset identifier 的 JPEG
/// 2) 按动画逐帧编码 MOV
/// 3) `PHLivePhoto.request` 组装预览
nonisolated enum CanvasLivePhotoExporter {
    static let livePhotoRequestTimeout: Duration = .seconds(8)

    static func export(
        snapshot: CanvasExportSnapshot,
        keyPhotoSize: CGSize,
        preloadedSourceLiveVideo: CanvasSourceLiveVideo? = nil
    ) async -> CanvasLivePhotoExportBundle? {
        guard snapshot.exportsAsLivePhoto else { return nil }
        guard keyPhotoSize.width > 0, keyPhotoSize.height > 0 else { return nil }

        let sourceLiveVideo: CanvasSourceLiveVideo?
        if snapshot.hasSourceLiveVideo {
            if let preloadedSourceLiveVideo {
                sourceLiveVideo = preloadedSourceLiveVideo
            } else {
                sourceLiveVideo = await CanvasSourceLiveVideo.load(
                    assetLocalIdentifier: snapshot.sourcePhotoAssetLocalIdentifier
                )
            }
        } else {
            sourceLiveVideo = nil
        }
        let shouldRemoveLoadedSourceLiveVideo = sourceLiveVideo != nil && preloadedSourceLiveVideo == nil
        defer {
            if shouldRemoveLoadedSourceLiveVideo {
                sourceLiveVideo?.removeTemporaryFiles()
            }
        }

        let exportDuration = snapshot.exportDuration(sourceLiveVideo: sourceLiveVideo)
        guard exportDuration > 0 else { return nil }

        let needsSubjectMask = snapshot.asciiArtSettings.enabled || snapshot.subjectGlowSettings.enabled
        let subjectMask: SubjectMask? = needsSubjectMask
            ? try? await VisionSubjectMaskProvider().subjectMask(for: snapshot.image)
            : nil

        let videoSize = CanvasLivePhotoSizing.videoEncodeSize(for: keyPhotoSize)
        let assetIdentifier = CanvasLivePhotoMetadata.makeAssetIdentifier()
        let imageURL = temporaryURL(extension: "jpg")
        let videoURL = temporaryURL(extension: "mov")
        let styledBaseImage = CanvasStyledPhotoRenderer.renderSync(
            image: snapshot.image,
            y2kCCDFilterSettings: snapshot.y2kCCDFilterSettings,
            sourceKey: "export-base",
            asciiArtSettings: snapshot.asciiArtSettings,
            subjectMask: subjectMask,
            photoCompression: snapshot.photoCompression,
            subjectGlowSettings: snapshot.subjectGlowSettings
        )

        guard
            let keyPhoto = renderFrame(
                snapshot: snapshot,
                exportSize: keyPhotoSize,
                blinkTime: 0,
                sourceLiveVideo: sourceLiveVideo,
                exportDuration: exportDuration,
                subjectMask: subjectMask,
                applySourceLivePhotoFrame: false,
                styledBaseImage: styledBaseImage
            ),
            CanvasLivePhotoMetadata.writeJPEG(
                keyPhoto,
                assetIdentifier: assetIdentifier,
                to: imageURL,
                compressionQuality: CanvasExportWriter.jpegCompressionQuality
            )
        else {
            return nil
        }

        guard await writeVideo(
            snapshot: snapshot,
            videoSize: videoSize,
            assetIdentifier: assetIdentifier,
            outputURL: videoURL,
            sourceLiveVideo: sourceLiveVideo,
            exportDuration: exportDuration,
            subjectMask: subjectMask,
            styledBaseImage: styledBaseImage
        ) else {
            try? FileManager.default.removeItem(at: imageURL)
            return nil
        }

        guard let livePhoto = await requestLivePhoto(
            imageURL: imageURL,
            videoURL: videoURL,
            placeholderImage: keyPhoto
        ) else {
            try? FileManager.default.removeItem(at: imageURL)
            try? FileManager.default.removeItem(at: videoURL)
            return nil
        }

        return CanvasLivePhotoExportBundle(
            livePhoto: livePhoto,
            imageURL: imageURL,
            videoURL: videoURL
        )
    }

    private static func renderFrame(
        snapshot: CanvasExportSnapshot,
        exportSize: CGSize,
        blinkTime: TimeInterval,
        sourceLiveVideo: CanvasSourceLiveVideo?,
        exportDuration: TimeInterval,
        subjectMask: SubjectMask? = nil,
        applySourceLivePhotoFrame: Bool = true,
        styledBaseImage: UIImage? = nil
    ) -> UIImage? {
        let photoFrameImage: UIImage?
        if applySourceLivePhotoFrame,
           snapshot.isSourceLiveMotionEnabled,
           let sourceLiveVideo {
            photoFrameImage = sourceLiveVideo.frame(
                at: blinkTime,
                timelineDuration: exportDuration
            )
        } else {
            photoFrameImage = nil
        }

        return CanvasRasterExporter.render(
            image: snapshot.image,
            exportSize: exportSize,
            extensionRatio: snapshot.extensionRatio,
            extensionSide: snapshot.extensionSide,
            photoCompression: snapshot.photoCompression,
            backgroundStyle: snapshot.backgroundStyle,
            backgroundColors: snapshot.backgroundColors,
            backgroundPatternSpacing: snapshot.backgroundPatternSpacing,
            dots: snapshot.dots,
            dotScale: snapshot.dotScale,
            dotColor: snapshot.dotColor,
            usesRandomDotColors: snapshot.usesRandomDotColors,
            dotCharacterText: snapshot.dotCharacterText,
            textBubbleSettings: snapshot.textBubbleSettings,
            liveDotAnimation: snapshot.liveDotAnimation,
            blinkTime: blinkTime,
            y2kCCDFilterSettings: snapshot.y2kCCDFilterSettings,
            asciiArtSettings: snapshot.asciiArtSettings,
            subjectMask: subjectMask,
            subjectGlowSettings: snapshot.subjectGlowSettings,
            photoFrameImage: photoFrameImage,
            styledBaseImage: styledBaseImage
        )
    }

    private static func writeVideo(
        snapshot: CanvasExportSnapshot,
        videoSize: CGSize,
        assetIdentifier: String,
        outputURL: URL,
        sourceLiveVideo: CanvasSourceLiveVideo?,
        exportDuration: TimeInterval,
        subjectMask: SubjectMask? = nil,
        styledBaseImage: UIImage? = nil
    ) async -> Bool {
        try? FileManager.default.removeItem(at: outputURL)

        let videoWidth = CanvasLivePhotoSizing.evenDimension(videoSize.width)
        let videoHeight = CanvasLivePhotoSizing.evenDimension(videoSize.height)
        let encodedSize = CGSize(width: videoWidth, height: videoHeight)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        } catch {
            return false
        }

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        guard writer.canAdd(input) else { return false }
        writer.add(input)
        writer.metadata = CanvasLivePhotoMetadata.makeVideoMetadataItems(
            assetIdentifier: assetIdentifier
        )
        guard writer.startWriting() else { return false }

        writer.startSession(atSourceTime: .zero)

        let frameRate = CanvasLivePhotoSizing.videoFrameRate
        let frameCount = max(
            1,
            Int((exportDuration * Double(frameRate)).rounded())
        )
        let frameDuration = CMTime(value: 1, timescale: frameRate)

        for frameIndex in 0..<frameCount {
            let blinkTime = Double(frameIndex) / Double(frameRate)

            let frameImage: UIImage? = autoreleasepool {
                renderFrame(
                    snapshot: snapshot,
                    exportSize: encodedSize,
                    blinkTime: blinkTime,
                    sourceLiveVideo: sourceLiveVideo,
                    exportDuration: exportDuration,
                    subjectMask: subjectMask,
                    styledBaseImage: styledBaseImage
                )
            }
            guard let frameImage else {
                input.markAsFinished()
                _ = await finishWriting(writer)
                return false
            }

            let pixelBuffer: CVPixelBuffer? = autoreleasepool {
                makePixelBuffer(from: frameImage, size: encodedSize)
            }
            guard let pixelBuffer else {
                input.markAsFinished()
                _ = await finishWriting(writer)
                return false
            }

            let presentationTime = CMTimeMultiply(
                frameDuration,
                multiplier: Int32(frameIndex)
            )

            while !input.isReadyForMoreMediaData {
                if writer.status == .failed {
                    input.markAsFinished()
                    _ = await finishWriting(writer)
                    return false
                }
                try? await Task.sleep(nanoseconds: 2_000_000)
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                input.markAsFinished()
                _ = await finishWriting(writer)
                return false
            }

            if frameIndex.isMultiple(of: 4) {
                await Task.yield()
            }
        }

        input.markAsFinished()
        return await finishWriting(writer)
    }

    private static func finishWriting(_ writer: AVAssetWriter) async -> Bool {
        let writerBox = SendableAVAssetWriter(writer)
        return await withCheckedContinuation { continuation in
            writerBox.writer.finishWriting {
                continuation.resume(returning: writerBox.writer.status == .completed)
            }
        }
    }

    private static func makePixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CanvasLivePhotoSizing.evenDimension(size.width)
        let height = CanvasLivePhotoSizing.evenDimension(size.height)
        guard width > 0, height > 0 else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private static func requestLivePhoto(
        imageURL: URL,
        videoURL: URL,
        placeholderImage: UIImage
    ) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            let gate = LivePhotoRequestGate()

            PHLivePhoto.request(
                withResourceFileURLs: [imageURL, videoURL],
                placeholderImage: placeholderImage,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                gate.evaluate(livePhoto: livePhoto, info: info) { resolved in
                    continuation.resume(returning: resolved)
                }
            }

            Task {
                try? await Task.sleep(for: livePhotoRequestTimeout)
                gate.timeoutResume { resolved in
                    continuation.resume(returning: resolved)
                }
            }
        }
    }

    private static func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("chocho-live-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }
}

private nonisolated struct SendableAVAssetWriter: @unchecked Sendable {
    let writer: AVAssetWriter

    init(_ writer: AVAssetWriter) {
        self.writer = writer
    }
}

private nonisolated final class LivePhotoRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private var bestLivePhoto: PHLivePhoto?

    func evaluate(
        livePhoto: PHLivePhoto?,
        info: [AnyHashable: Any],
        resume: (PHLivePhoto?) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return }

        if let cancelled = info[PHLivePhotoInfoCancelledKey] as? Bool, cancelled {
            didResume = true
            resume(nil)
            return
        }

        if info[PHLivePhotoInfoErrorKey] != nil {
            didResume = true
            resume(nil)
            return
        }

        if let livePhoto {
            bestLivePhoto = livePhoto
            let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                didResume = true
                resume(livePhoto)
            }
            return
        }

        didResume = true
        resume(bestLivePhoto)
    }

    func timeoutResume(resume: (PHLivePhoto?) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return }
        didResume = true
        resume(bestLivePhoto)
    }
}
