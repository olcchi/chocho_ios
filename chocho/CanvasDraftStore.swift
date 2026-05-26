import CoreGraphics
import SwiftUI
import UIKit

struct CanvasDraftCapture: Sendable {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let dotCount: Double
    let dotScale: Double
    let selectedDotColor: Color
    let usesRandomDotColors: Bool
    let selectedDotShapeName: String
    let isTraceDrawingEnabled: Bool
    let puzzleDots: [PuzzleDot]
    let tracePoints: [PuzzleCanvasTracePoint]
    let viewportScale: CGFloat
    let viewportOffset: CGSize
}

struct CanvasDraftRestore: Sendable {
    let image: UIImage
    let extensionRatio: CGFloat
    let extensionSide: PuzzleCanvasExtensionSide
    let backgroundStyle: PuzzleBackgroundStyle
    let backgroundColors: PuzzleBackgroundColors
    let dotCount: Double
    let dotScale: Double
    let selectedDotColor: Color
    let usesRandomDotColors: Bool
    let selectedDotShapeName: String
    let isTraceDrawingEnabled: Bool
    let puzzleDots: [PuzzleDot]
    let tracePoints: [PuzzleCanvasTracePoint]
    let viewportScale: CGFloat
    let viewportOffset: CGSize
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
    static let currentVersion = 2
    static let supportedVersions: Set<Int> = [1, 2]

    var version: Int
    var savedAt: Date
    var extensionRatio: Double
    var extensionSide: String
    var backgroundStyle: String
    var backgroundColors: CanvasDraftStoredBackgroundColors?
    var dotCount: Double
    var dotScale: Double
    var selectedDotColor: CanvasDraftColorComponents
    var usesRandomDotColors: Bool
    var selectedDotShapeName: String
    var isTraceDrawingEnabled: Bool
    var puzzleDots: [CanvasDraftStoredDot]
    var tracePoints: [CanvasDraftStoredTracePoint]
    var viewportScale: Double
    var viewportOffsetWidth: Double
    var viewportOffsetHeight: Double
}

nonisolated struct CanvasDraftColorComponents: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

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
}

nonisolated struct CanvasDraftStoredDot: Codable, Equatable, Sendable {
    var id: UUID
    var positionX: Double
    var positionY: Double
    var color: CanvasDraftColorComponents
    var size: Double
    var shapeAssetName: String

    init(dot: PuzzleDot) {
        id = dot.id
        positionX = Double(dot.position.x)
        positionY = Double(dot.position.y)
        color = CanvasDraftColorComponents(dot.color)
        size = Double(dot.size)
        shapeAssetName = dot.shapeAssetName
    }

    func puzzleDot() -> PuzzleDot {
        PuzzleDot(
            id: id,
            position: CGPoint(x: positionX, y: positionY),
            color: color.color,
            size: CGFloat(size),
            shapeAssetName: shapeAssetName
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

nonisolated enum CanvasDraftStore {
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
            dotCount: capture.dotCount,
            dotScale: capture.dotScale,
            selectedDotColor: CanvasDraftColorComponents(capture.selectedDotColor),
            usesRandomDotColors: capture.usesRandomDotColors,
            selectedDotShapeName: capture.selectedDotShapeName,
            isTraceDrawingEnabled: capture.isTraceDrawingEnabled,
            puzzleDots: capture.puzzleDots.map(CanvasDraftStoredDot.init(dot:)),
            tracePoints: capture.tracePoints.map(CanvasDraftStoredTracePoint.init(point:)),
            viewportScale: Double(capture.viewportScale),
            viewportOffsetWidth: Double(capture.viewportOffset.width),
            viewportOffsetHeight: Double(capture.viewportOffset.height)
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

            let puzzleDots = manifest.puzzleDots.map { $0.puzzleDot() }
            let tracePoints = manifest.tracePoints.compactMap { $0.tracePoint() }

            return CanvasDraftRestore(
                image: image,
                extensionRatio: CGFloat(manifest.extensionRatio),
                extensionSide: extensionSide,
                backgroundStyle: backgroundStyle,
                backgroundColors: manifest.backgroundColors?.puzzleBackgroundColors ?? .default,
                dotCount: manifest.dotCount,
                dotScale: manifest.dotScale,
                selectedDotColor: manifest.selectedDotColor.color,
                usesRandomDotColors: manifest.usesRandomDotColors,
                selectedDotShapeName: manifest.selectedDotShapeName,
                isTraceDrawingEnabled: manifest.isTraceDrawingEnabled,
                puzzleDots: puzzleDots,
                tracePoints: tracePoints,
                viewportScale: CGFloat(manifest.viewportScale),
                viewportOffset: CGSize(
                    width: manifest.viewportOffsetWidth,
                    height: manifest.viewportOffsetHeight
                )
            )
        } catch {
            return nil
        }
    }
}
