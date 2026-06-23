import CoreGraphics
import SwiftUI
import UIKit

struct CanvasDraftCapture: Sendable {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let dotCount: Double
    let dotScale: Double
    let selectedDotColor: Color
    let usesRandomDotColors: Bool
    let selectedDotShapeName: String
    let dotCharacterText: String
    let isTraceDrawingEnabled: Bool
    let photoCompression: MainPhotoCompression
    let puzzleDots: [PuzzleDot]
    let tracePoints: [PuzzleCanvasTracePoint]
    let viewportScale: CGFloat
    let viewportOffset: CGSize
    let liveDotAnimation: LiveDotAnimation
    let y2kCCDFilterSettings: Y2KCCDFilterSettings
    let asciiArtSettings: ASCIIArtSettings
    let isSourceLiveMotionEnabled: Bool
    let sourcePhotoAssetLocalIdentifier: String?
}

struct CanvasDraftRestore: Sendable {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let backgroundPatternSpacing: Double
    let dotCount: Double
    let dotScale: Double
    let selectedDotColor: Color
    let usesRandomDotColors: Bool
    let selectedDotShapeName: String
    let dotCharacterText: String
    let isTraceDrawingEnabled: Bool
    let photoCompression: MainPhotoCompression
    let puzzleDots: [PuzzleDot]
    let tracePoints: [PuzzleCanvasTracePoint]
    let viewportScale: CGFloat
    let viewportOffset: CGSize
    let liveDotAnimation: LiveDotAnimation
    let y2kCCDFilterSettings: Y2KCCDFilterSettings
    let asciiArtSettings: ASCIIArtSettings
    let isSourceLiveMotionEnabled: Bool
    let sourcePhotoAssetLocalIdentifier: String?
}

nonisolated struct CanvasDraftStoredBackgroundColors: Codable, Equatable, Sendable {
    var fillColor: CanvasDraftColorComponents
    var alternateColor: CanvasDraftColorComponents
    var lineColor: CanvasDraftColorComponents

    init(_ colors: PuzzleBackgroundColors) {
        fillColor = CanvasDraftColorComponents(colors.fillColor)
        alternateColor = CanvasDraftColorComponents(colors.alternateColor)
        lineColor = CanvasDraftColorComponents(colors.lineColor)
    }

    var puzzleBackgroundColors: PuzzleBackgroundColors {
        PuzzleBackgroundColors(
            fillColor: fillColor.color,
            alternateColor: alternateColor.color,
            lineColor: lineColor.color
        )
    }
}

nonisolated struct CanvasDraftManifest: Codable, Equatable, Sendable {
    static let currentVersion = 10
    static let supportedVersions: Set<Int> = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    var version: Int
    var savedAt: Date
    var extensionRatio: Double
    var extensionSide: String
    var backgroundStyle: String
    var backgroundColors: CanvasDraftStoredBackgroundColors?
    /// v4+：方格大小 / 条纹粗细（旧草稿缺省为 nil → 恢复为默认 12）
    var backgroundPatternSpacing: Double?
    var dotCount: Double
    var dotScale: Double
    var selectedDotColor: CanvasDraftColorComponents
    var usesRandomDotColors: Bool
    var selectedDotShapeName: String
    /// v5+：字符波点输入内容（旧草稿缺省为 nil → 恢复为默认“字”）
    var dotCharacterText: String?
    var isTraceDrawingEnabled: Bool
    /// v6+：主图压缩类型（旧草稿缺省为 nil → 恢复为 .none）
    var photoCompressionRawValue: String?
    var puzzleDots: [CanvasDraftStoredDot]
    var tracePoints: [CanvasDraftStoredTracePoint]
    var viewportScale: Double
    var viewportOffsetWidth: Double
    var viewportOffsetHeight: Double
    /// v3+：波点动画类型（旧草稿缺省为 nil → 恢复为 .none）
    var liveDotAnimationRawValue: String?
    /// v8+：Y2K CCD 滤镜设置（旧草稿缺省为 .default，即关闭）
    var y2kCCDFilterSettings: Y2KCCDFilterSettings?
    /// v9 legacy：旧草稿可能含主体发光设置，恢复时忽略。
    var subjectGlowSettings: LegacySubjectGlowSettings?
    /// v10+：ASCII 字符纹理设置（旧草稿缺省为 nil → 恢复为 .default，即关闭）
    var asciiArtSettings: ASCIIArtSettings?
    /// v3+：原图实况开关（旧草稿缺省为 nil → 恢复为 false）
    var isSourceLiveMotionEnabled: Bool?
    /// v3+：相册 PHAsset local identifier（旧草稿缺省为 nil）
    var sourcePhotoAssetLocalIdentifier: String?
}

nonisolated struct LegacySubjectGlowSettings: Codable, Equatable, Sendable {
    var enabled: Bool
    var intensity: Double
    var radius: Double
}

nonisolated struct CanvasDraftColorComponents: Codable, Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var redComponent: CGFloat = 0
        var greenComponent: CGFloat = 0
        var blueComponent: CGFloat = 0
        var alphaComponent: CGFloat = 0
        uiColor.getRed(
            &redComponent,
            green: &greenComponent,
            blue: &blueComponent,
            alpha: &alphaComponent
        )
        red = Double(redComponent)
        green = Double(greenComponent)
        blue = Double(blueComponent)
        opacity = Double(alphaComponent)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}

nonisolated struct CanvasDraftStoredDot: Codable, Equatable, Sendable {
    var id: UUID
    var positionX: Double
    var positionY: Double
    var color: CanvasDraftColorComponents
    var size: Double
    var shapeAssetName: String
    var scaleOverride: Double?
    var shapeAssetNameOverride: String?
    var rotationDegrees: Double?

    init(dot: PuzzleDot) {
        id = dot.id
        positionX = Double(dot.position.x)
        positionY = Double(dot.position.y)
        color = CanvasDraftColorComponents(dot.color)
        size = Double(dot.size)
        shapeAssetName = dot.shapeAssetName
        scaleOverride = dot.scaleOverride.map(Double.init)
        shapeAssetNameOverride = dot.shapeAssetNameOverride
        rotationDegrees = Double(dot.rotationDegrees)
    }

    func puzzleDot() -> PuzzleDot {
        PuzzleDot(
            id: id,
            position: CGPoint(x: positionX, y: positionY),
            color: color.color,
            size: CGFloat(size),
            shapeAssetName: shapeAssetName,
            scaleOverride: scaleOverride.map { CGFloat($0) },
            shapeAssetNameOverride: shapeAssetNameOverride,
            rotationDegrees: CGFloat(rotationDegrees ?? 0)
        )
    }
}

nonisolated struct CanvasDraftStoredTracePoint: Codable, Equatable, Sendable {
    var side: String
    var pointX: Double
    var pointY: Double
    var startsNewStroke: Bool

    init(point: PuzzleCanvasTracePoint) {
        switch point.side {
        case .photo:
            side = "photo"
        case .background:
            side = "background"
        }
        pointX = Double(point.point.x)
        pointY = Double(point.point.y)
        startsNewStroke = point.startsNewStroke
    }

    func tracePoint() -> PuzzleCanvasTracePoint? {
        let resolvedSide: PuzzleCanvasSide
        switch side {
        case "photo":
            resolvedSide = .photo
        case "background":
            resolvedSide = .background
        default:
            return nil
        }

        return PuzzleCanvasTracePoint(
            side: resolvedSide,
            point: CGPoint(x: pointX, y: pointY),
            startsNewStroke: startsNewStroke
        )
    }
}

/// 画布草稿：Application Support 下 manifest.json + photo.jpg，支持版本迁移与后台读写。
nonisolated enum CanvasDraftStore {
    /// 定时任务与进入后台时触发保存的间隔。
    static let autosaveInterval: Duration = .seconds(30)

    private static let directoryName = "chocho-canvas-draft"
    private static let manifestFileName = "manifest.json"
    private static let photoFileName = "photo.jpg"

    static func defaultDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    @discardableResult
    static func save(
        _ capture: CanvasDraftCapture,
        directoryURL: URL? = nil
    ) async -> Bool {
        let directory = directoryURL ?? defaultDirectoryURL()

        guard let photoData = capture.image.jpegData(
            compressionQuality: CanvasExportWriter.jpegCompressionQuality
        ) else {
            return false
        }

        let manifest = CanvasDraftManifest(
            version: CanvasDraftManifest.currentVersion,
            savedAt: Date(),
            extensionRatio: Double(capture.extensionRatio),
            extensionSide: capture.extensionSide.rawValue,
            backgroundStyle: capture.backgroundStyle.rawValue,
            backgroundColors: CanvasDraftStoredBackgroundColors(capture.backgroundColors),
            backgroundPatternSpacing: capture.backgroundPatternSpacing,
            dotCount: capture.dotCount,
            dotScale: capture.dotScale,
            selectedDotColor: CanvasDraftColorComponents(capture.selectedDotColor),
            usesRandomDotColors: capture.usesRandomDotColors,
            selectedDotShapeName: capture.selectedDotShapeName,
            dotCharacterText: capture.dotCharacterText,
            isTraceDrawingEnabled: capture.isTraceDrawingEnabled,
            photoCompressionRawValue: capture.photoCompression.rawValue,
            puzzleDots: capture.puzzleDots.map(CanvasDraftStoredDot.init(dot:)),
            tracePoints: capture.tracePoints.map(CanvasDraftStoredTracePoint.init(point:)),
            viewportScale: Double(capture.viewportScale),
            viewportOffsetWidth: Double(capture.viewportOffset.width),
            viewportOffsetHeight: Double(capture.viewportOffset.height),
            liveDotAnimationRawValue: capture.liveDotAnimation.rawValue,
            y2kCCDFilterSettings: capture.y2kCCDFilterSettings,
            asciiArtSettings: capture.asciiArtSettings,
            isSourceLiveMotionEnabled: capture.isSourceLiveMotionEnabled,
            sourcePhotoAssetLocalIdentifier: capture.sourcePhotoAssetLocalIdentifier
        )

        return await Task.detached(priority: .utility) {
            do {
                try writeDraft(
                    manifest: manifest,
                    photoData: photoData,
                    to: directory
                )
                return true
            } catch {
                return false
            }
        }.value
    }

    static func load(directoryURL: URL? = nil) async -> CanvasDraftRestore? {
        let directory = directoryURL ?? defaultDirectoryURL()

        return await Task.detached(priority: .utility) {
            readDraft(from: directory)
        }.value
    }

    static func clear(directoryURL: URL? = nil) async {
        let directory = directoryURL ?? defaultDirectoryURL()

        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: directory)
        }.value
    }

    nonisolated static func writeDraft(
        manifest: CanvasDraftManifest,
        photoData: Data,
        to directory: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let manifestURL = directory.appendingPathComponent(manifestFileName)
        let photoURL = directory.appendingPathComponent(photoFileName)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)

        try manifestData.write(to: manifestURL, options: .atomic)
        try photoData.write(to: photoURL, options: .atomic)
    }

    nonisolated static func readDraft(from directory: URL) -> CanvasDraftRestore? {
        let manifestURL = directory.appendingPathComponent(manifestFileName)
        let photoURL = directory.appendingPathComponent(photoFileName)

        guard FileManager.default.fileExists(atPath: manifestURL.path),
              FileManager.default.fileExists(atPath: photoURL.path) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try decoder.decode(CanvasDraftManifest.self, from: manifestData)

            guard CanvasDraftManifest.supportedVersions.contains(manifest.version) else {
                return nil
            }

            let photoData = try Data(contentsOf: photoURL)
            guard let image = CanvasImageLoader.makeUIImage(from: photoData) else {
                return nil
            }

            guard let extensionSide = PuzzleCanvasExtensionSide(rawValue: manifest.extensionSide),
                  let backgroundStyle = PuzzleBackgroundStyle(rawValue: manifest.backgroundStyle) else {
                return nil
            }

            let puzzleDots = manifest.puzzleDots.map { storedDot -> PuzzleDot in
                var migratedDot = storedDot
                migratedDot.shapeAssetName = DotShapeAssetNameMigration.migrate(storedDot.shapeAssetName)
                migratedDot.shapeAssetNameOverride = storedDot.shapeAssetNameOverride.map(DotShapeAssetNameMigration.migrate)
                return migratedDot.puzzleDot()
            }
            let tracePoints = manifest.tracePoints.compactMap { $0.tracePoint() }

            let liveDotAnimation = manifest.liveDotAnimationRawValue
                .flatMap { LiveDotAnimation(rawValue: $0) } ?? .none
            let photoCompression = manifest.photoCompressionRawValue
                .flatMap { MainPhotoCompression(rawValue: $0) } ?? .none

            return CanvasDraftRestore(
                image: image,
                extensionRatio: CGFloat(manifest.extensionRatio),
                extensionSide: extensionSide,
                backgroundStyle: backgroundStyle,
                backgroundColors: manifest.backgroundColors?.puzzleBackgroundColors ?? .default,
                backgroundPatternSpacing: manifest.backgroundPatternSpacing
                    ?? PuzzleBackgroundPatternSpacing.defaultControlValue,
                dotCount: manifest.dotCount,
                dotScale: manifest.dotScale,
                selectedDotColor: manifest.selectedDotColor.color,
                usesRandomDotColors: manifest.usesRandomDotColors,
                selectedDotShapeName: DotShapeAssetNameMigration.migrate(manifest.selectedDotShapeName),
                dotCharacterText: manifest.dotCharacterText ?? CharacterDotText.defaultText,
                isTraceDrawingEnabled: manifest.isTraceDrawingEnabled,
                photoCompression: photoCompression,
                puzzleDots: puzzleDots,
                tracePoints: tracePoints,
                viewportScale: CGFloat(manifest.viewportScale),
                viewportOffset: CGSize(
                    width: manifest.viewportOffsetWidth,
                    height: manifest.viewportOffsetHeight
                ),
                liveDotAnimation: liveDotAnimation,
                y2kCCDFilterSettings: manifest.y2kCCDFilterSettings ?? .default,
                asciiArtSettings: manifest.asciiArtSettings ?? .default,
                isSourceLiveMotionEnabled: manifest.isSourceLiveMotionEnabled ?? false,
                sourcePhotoAssetLocalIdentifier: manifest.sourcePhotoAssetLocalIdentifier
            )
        } catch {
            return nil
        }
    }
}
