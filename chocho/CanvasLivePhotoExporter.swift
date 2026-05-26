import AVFoundation
import Photos
import SwiftUI
import UIKit

nonisolated struct CanvasLivePhotoExportBundle {
    let livePhoto: PHLivePhoto
    let imageURL: URL
    let videoURL: URL

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: videoURL)
    }
}

/// Live Photo export sizing: full-quality key frame, lower-resolution paired motion (like iOS camera).
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

nonisolated enum CanvasLivePhotoExporter {
    static let livePhotoRequestTimeout: Duration = .seconds(8)

    struct Snapshot {
        let image: UIImage
        let extensionRatio: CGFloat
        let extensionSide: PuzzleCanvasExtensionSide
        let backgroundStyle: PuzzleBackgroundStyle
        let backgroundColors: PuzzleBackgroundColors
        let dots: [PuzzleDot]
        let dotScale: CGFloat
        let dotColor: Color
        let usesRandomDotColors: Bool
        let liveDotAnimation: LiveDotAnimation
    }

    static func export(
        snapshot: Snapshot,
        keyPhotoSize: CGSize
    ) async -> CanvasLivePhotoExportBundle? {
        guard snapshot.liveDotAnimation.exportsAsLivePhoto else { return nil }
        guard keyPhotoSize.width > 0, keyPhotoSize.height > 0 else { return nil }

        let videoSize = CanvasLivePhotoSizing.videoEncodeSize(for: keyPhotoSize)
        let assetIdentifier = CanvasLivePhotoMetadata.makeAssetIdentifier()
        let imageURL = temporaryURL(extension: "jpg")
        let videoURL = temporaryURL(extension: "mov")

        guard
            let keyPhoto = renderFrame(
                snapshot: snapshot,
                exportSize: keyPhotoSize,
                blinkTime: 0
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
            outputURL: videoURL
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
        snapshot: Snapshot,
        exportSize: CGSize,
        blinkTime: TimeInterval
    ) -> UIImage? {
        CanvasRasterExporter.render(
            image: snapshot.image,
            exportSize: exportSize,
            extensionRatio: snapshot.extensionRatio,
            extensionSide: snapshot.extensionSide,
            backgroundStyle: snapshot.backgroundStyle,
            backgroundColors: snapshot.backgroundColors,
            dots: snapshot.dots,
            dotScale: snapshot.dotScale,
            dotColor: snapshot.dotColor,
            usesRandomDotColors: snapshot.usesRandomDotColors,
            liveDotAnimation: snapshot.liveDotAnimation,
            blinkTime: blinkTime
        )
    }

    private static func writeVideo(
        snapshot: Snapshot,
        videoSize: CGSize,
        assetIdentifier: String,
        outputURL: URL
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
            Int((snapshot.liveDotAnimation.motionExportDuration * Double(frameRate)).rounded())
        )
        let frameDuration = CMTime(value: 1, timescale: frameRate)

        for frameIndex in 0..<frameCount {
            let blinkTime = Double(frameIndex) / Double(frameRate)

            let frameImage: UIImage? = autoreleasepool {
                renderFrame(
                    snapshot: snapshot,
                    exportSize: encodedSize,
                    blinkTime: blinkTime
                )
            }
            guard let frameImage else {
                input.markAsFinished()
                await finishWriting(writer)
                return false
            }

            let pixelBuffer: CVPixelBuffer? = autoreleasepool {
                makePixelBuffer(from: frameImage, size: encodedSize)
            }
            guard let pixelBuffer else {
                input.markAsFinished()
                await finishWriting(writer)
                return false
            }

            let presentationTime = CMTimeMultiply(
                frameDuration,
                multiplier: Int32(frameIndex)
            )

            while !input.isReadyForMoreMediaData {
                if writer.status == .failed {
                    input.markAsFinished()
                    await finishWriting(writer)
                    return false
                }
                try? await Task.sleep(nanoseconds: 2_000_000)
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                input.markAsFinished()
                await finishWriting(writer)
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
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume(returning: writer.status == .completed)
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

private final class LivePhotoRequestGate: @unchecked Sendable {
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
