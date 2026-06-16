# Subject Contour Dots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "主体功能" draw-panel action that uses Vision subject masks to place mirrored puzzle dots around the detected subject silhouette.

**Architecture:** Keep SwiftUI state in `ContentView`; keep panel files UI-only. Add a pure `SubjectContourSampler` for mask-to-position math, then wrap it with an async `SubjectContourDotGenerator` and an iOS 17+ Vision mask provider. Generated dots stay ordinary `PuzzleDot` values so existing preview, mirror, draft, undo, live animation, and export behavior continue unchanged.

**Tech Stack:** SwiftUI, Vision `VNGenerateForegroundInstanceMaskRequest`, UIKit `UIImage`, Swift Testing, Xcode project file system synchronized groups.

---

## File Structure

- Create `chocho/SubjectContourDotGenerator.swift`: owns `SubjectMask`, `SubjectMaskProviding`, `SubjectContourSampler`, `SubjectContourDotGenerator`, and Vision provider code.
- Create `chochoTests/SubjectContourDotGeneratorTests.swift`: focused Swift Testing coverage for sampler and fake-provider generator behavior.
- Modify `chocho/BottomSheetPanelControls.swift`: add subject action state/action to `BottomSheetDotControls`.
- Modify `chocho/BottomSheetPanel.swift`: render "主体功能" in the draw panel and disable it while running.
- Modify `chocho/ContentView.swift`: own `isDrawingSubjectDots`, invoke the generator, map errors to toasts, and ignore stale async results.

---

### Task 1: Mask Sampler

**Files:**
- Create: `chocho/SubjectContourDotGenerator.swift`
- Test: `chochoTests/SubjectContourDotGeneratorTests.swift`

- [ ] **Step 1: Write failing sampler tests**

Create `chochoTests/SubjectContourDotGeneratorTests.swift`:

```swift
import CoreGraphics
import Testing
import UIKit
@testable import chocho

struct SubjectContourDotGeneratorTests {
    @Test func samplerReturnsNoDotsForEmptyMask() {
        let mask = SubjectMask(width: 4, height: 4, pixels: Array(repeating: false, count: 16))
        var generator = SeededRandomNumberGenerator(seed: 1)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 8,
            using: &generator
        )

        #expect(positions.isEmpty)
    }

    @Test func samplerGeneratesRequestedCountAroundRectangle() {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 3, y: 3, width: 4, height: 4)
        var generator = SeededRandomNumberGenerator(seed: 7)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 12,
            using: &generator
        )

        #expect(positions.count == 12)
        #expect(positions.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
    }

    @Test func samplerNudgesDotsOutsideSubjectCenter() {
        let mask = SubjectMask.rectangle(width: 20, height: 20, x: 7, y: 7, width: 6, height: 6)
        var generator = SeededRandomNumberGenerator(seed: 3)

        let positions = SubjectContourSampler.positions(
            in: mask,
            count: 16,
            using: &generator
        )

        let center = CGPoint(x: 0.5, y: 0.5)
        let minimumDistance = positions.map { hypot($0.x - center.x, $0.y - center.y) }.min() ?? 0
        #expect(minimumDistance > 0.15)
    }

    @Test func samplerOutputIsStableWithSeededGenerator() {
        let mask = SubjectMask.rectangle(width: 10, height: 10, x: 2, y: 2, width: 6, height: 6)
        var first = SeededRandomNumberGenerator(seed: 42)
        var second = SeededRandomNumberGenerator(seed: 42)

        let firstPositions = SubjectContourSampler.positions(in: mask, count: 6, using: &first)
        let secondPositions = SubjectContourSampler.positions(in: mask, count: 6, using: &second)

        #expect(firstPositions == secondPositions)
    }
}

private extension SubjectMask {
    static func rectangle(width: Int, height: Int, x: Int, y: Int, width rectWidth: Int, height rectHeight: Int) -> SubjectMask {
        var pixels = Array(repeating: false, count: width * height)
        for row in y..<(y + rectHeight) {
            for column in x..<(x + rectWidth) {
                pixels[row * width + column] = true
            }
        }
        return SubjectMask(width: width, height: height, pixels: pixels)
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData test
```

Expected: FAIL because `SubjectMask`, `SubjectContourSampler`, and `SeededRandomNumberGenerator` are not defined.

- [ ] **Step 3: Implement minimal sampler**

Create `chocho/SubjectContourDotGenerator.swift` with:

```swift
import CoreGraphics

nonisolated struct SubjectMask: Equatable {
    let width: Int
    let height: Int
    let pixels: [Bool]

    func contains(column: Int, row: Int) -> Bool {
        guard column >= 0, column < width, row >= 0, row < height else { return false }
        return pixels[row * width + column]
    }
}

nonisolated struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

nonisolated enum SubjectContourSampler {
    static func positions<Generator: RandomNumberGenerator>(
        in mask: SubjectMask,
        count: Int,
        using generator: inout Generator
    ) -> [CGPoint] {
        let normalizedCount = max(count, 0)
        guard normalizedCount > 0 else { return [] }

        let boundary = boundaryPoints(in: mask)
        guard !boundary.isEmpty else { return [] }

        let center = subjectCenter(in: mask) ?? CGPoint(x: 0.5, y: 0.5)
        let sorted = boundary.sorted { first, second in
            angle(from: center, to: first) < angle(from: center, to: second)
        }

        return (0..<normalizedCount).map { index in
            let bucketStart = CGFloat(index) / CGFloat(normalizedCount)
            let jitter = CGFloat.random(in: -0.35...0.35, using: &generator) / CGFloat(normalizedCount)
            let progress = min(max(bucketStart + jitter, 0), 0.999_999)
            let sourceIndex = min(sorted.count - 1, Int(progress * CGFloat(sorted.count)))
            return nudgedOutward(sorted[sourceIndex], from: center, in: mask)
        }
    }

    private static func boundaryPoints(in mask: SubjectMask) -> [CGPoint] {
        guard mask.width > 0, mask.height > 0, mask.pixels.count == mask.width * mask.height else { return [] }
        var points: [CGPoint] = []
        for row in 0..<mask.height {
            for column in 0..<mask.width where mask.contains(column: column, row: row) {
                if !mask.contains(column: column - 1, row: row)
                    || !mask.contains(column: column + 1, row: row)
                    || !mask.contains(column: column, row: row - 1)
                    || !mask.contains(column: column, row: row + 1) {
                    points.append(normalizedPoint(column: column, row: row, mask: mask))
                }
            }
        }
        return points
    }

    private static func subjectCenter(in mask: SubjectMask) -> CGPoint? {
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        var total: CGFloat = 0
        for row in 0..<mask.height {
            for column in 0..<mask.width where mask.contains(column: column, row: row) {
                let point = normalizedPoint(column: column, row: row, mask: mask)
                totalX += point.x
                totalY += point.y
                total += 1
            }
        }
        guard total > 0 else { return nil }
        return CGPoint(x: totalX / total, y: totalY / total)
    }

    private static func normalizedPoint(column: Int, row: Int, mask: SubjectMask) -> CGPoint {
        CGPoint(
            x: (CGFloat(column) + 0.5) / CGFloat(mask.width),
            y: (CGFloat(row) + 0.5) / CGFloat(mask.height)
        )
    }

    private static func angle(from center: CGPoint, to point: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x)
    }

    private static func nudgedOutward(_ point: CGPoint, from center: CGPoint, in mask: SubjectMask) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let length = max(hypot(dx, dy), 0.000_1)
        let offset = 1.5 / CGFloat(max(mask.width, mask.height))
        return CGPoint(
            x: min(max(point.x + dx / length * offset, 0), 1),
            y: min(max(point.y + dy / length * offset, 0), 1)
        )
    }
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run the same `xcodebuild ... test` command. Expected: the new sampler tests pass.

- [ ] **Step 5: Commit**

```bash
git add chocho/SubjectContourDotGenerator.swift chochoTests/SubjectContourDotGeneratorTests.swift
git commit -m "Add subject contour sampler"
```

---

### Task 2: Generator And Vision Provider

**Files:**
- Modify: `chocho/SubjectContourDotGenerator.swift`
- Modify: `chochoTests/SubjectContourDotGeneratorTests.swift`

- [ ] **Step 1: Write failing generator test**

Append to `SubjectContourDotGeneratorTests`:

```swift
@Test func generatorUsesMaskProviderAndCurrentDotShape() async throws {
    let mask = SubjectMask.rectangle(width: 10, height: 10, x: 3, y: 3, width: 4, height: 4)
    let provider = FakeSubjectMaskProvider(mask: mask)
    let generator = SubjectContourDotGenerator(maskProvider: provider)
    let image = UIImage()

    let dots = try await generator.dots(
        for: image,
        count: 5,
        shapeAssetName: "雪花"
    )

    #expect(dots.count == 5)
    #expect(dots.allSatisfy { $0.shapeAssetName == "雪花" })
}

private struct FakeSubjectMaskProvider: SubjectMaskProviding {
    let mask: SubjectMask

    func subjectMask(for image: UIImage) async throws -> SubjectMask {
        mask
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData test
```

Expected: FAIL because `SubjectMaskProviding` and `SubjectContourDotGenerator` are not defined.

- [ ] **Step 3: Implement generator and Vision provider**

Add these imports at the top of `chocho/SubjectContourDotGenerator.swift`:

```swift
import ImageIO
import UIKit
import Vision
```

Then extend the file with:

```swift
enum SubjectContourDotGenerationError: Error, Equatable {
    case unsupported
    case missingImage
    case noSubject
}

protocol SubjectMaskProviding: Sendable {
    func subjectMask(for image: UIImage) async throws -> SubjectMask
}

struct SubjectContourDotGenerator: Sendable {
    let maskProvider: any SubjectMaskProviding

    init(maskProvider: any SubjectMaskProviding = VisionSubjectMaskProvider()) {
        self.maskProvider = maskProvider
    }

    func dots(
        for image: UIImage,
        count: Int,
        shapeAssetName: String
    ) async throws -> [PuzzleDot] {
        let mask = try await maskProvider.subjectMask(for: image)
        var random = SeededRandomNumberGenerator(seed: SubjectContourDotSeed.seed(for: image))
        let positions = SubjectContourSampler.positions(in: mask, count: count, using: &random)
        guard !positions.isEmpty else { throw SubjectContourDotGenerationError.noSubject }
        return positions.enumerated().map { index, position in
            PuzzleDotFactory.makeDot(position: position, index: index, shapeAssetName: shapeAssetName)
        }
    }
}

private enum SubjectContourDotSeed {
    static func seed(for image: UIImage) -> UInt64 {
        let width = UInt64(max(Int(image.size.width.rounded()), 1))
        let height = UInt64(max(Int(image.size.height.rounded()), 1))
        return width &* 1_000_003 &+ height
    }
}

struct VisionSubjectMaskProvider: SubjectMaskProviding {
    func subjectMask(for image: UIImage) async throws -> SubjectMask {
        guard #available(iOS 17.0, *) else {
            throw SubjectContourDotGenerationError.unsupported
        }
        guard let cgImage = image.cgImage else {
            throw SubjectContourDotGenerationError.missingImage
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImagePropertyOrientation)
            try handler.perform([request])
            guard let observation = request.results?.first else {
                throw SubjectContourDotGenerationError.noSubject
            }
            let pixelBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
            guard let mask = SubjectMask(pixelBuffer: pixelBuffer) else {
                throw SubjectContourDotGenerationError.noSubject
            }
            return mask
        }.value
    }
}
```

Also add pixel-buffer and orientation helpers in the same file:

```swift
extension SubjectMask {
    init?(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer), width > 0, height > 0 else {
            return nil
        }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        var pixels: [Bool] = []
        pixels.reserveCapacity(width * height)
        for row in 0..<height {
            for column in 0..<width {
                pixels.append(bytes[row * bytesPerRow + column] > 0)
            }
        }

        self.init(width: width, height: height, pixels: pixels)
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run the same `xcodebuild ... test` command. Expected: generator tests pass.

- [ ] **Step 5: Commit**

```bash
git add chocho/SubjectContourDotGenerator.swift chochoTests/SubjectContourDotGeneratorTests.swift
git commit -m "Add Vision subject dot generator"
```

---

### Task 3: Draw Panel UI And ContentView Wiring

**Files:**
- Modify: `chocho/BottomSheetPanelControls.swift`
- Modify: `chocho/BottomSheetPanel.swift`
- Modify: `chocho/ContentView.swift`

- [ ] **Step 1: Add compile-failing call sites**

Update `DrawPanelControls` to accept:

```swift
let isDrawingSubjectDots: Bool
let onDrawSubjectDots: () -> Void
```

Update its initializer call inside `PanelContentCard`:

```swift
isDrawingSubjectDots: dotControls.isDrawingSubjectDots,
onDrawSubjectDots: onDrawSubjectDots
```

Expected before model changes: build fails because `BottomSheetDotControls.isDrawingSubjectDots` and `onDrawSubjectDots` are missing.

- [ ] **Step 2: Add controls model properties**

Modify `chocho/BottomSheetPanelControls.swift`:

```swift
struct BottomSheetDotControls {
    var dotCount: Binding<Double>
    var dotScale: Binding<Double>
    var selectedDotColor: Binding<Color>
    var usesRandomDotColors: Binding<Bool>
    var selectedDotShape: Binding<DotShapeAsset>
    var selectedDotShapeCategory: Binding<DotShapeCategory>
    var dotCharacterText: Binding<String>
    var isTraceDrawingEnabled: Binding<Bool>
    var photoCompression: Binding<MainPhotoCompression>
    var isDrawingSubjectDots: Bool = false
}
```

- [ ] **Step 3: Add the subject button**

In `DrawPanelControls`, replace `drawButton` with:

```swift
private var drawActions: some View {
    HStack(spacing: 8) {
        drawButton
        subjectButton
    }
}

private var subjectButton: some View {
    Button(action: onDrawSubjectDots) {
        HStack(spacing: 6) {
            Image(systemName: isDrawingSubjectDots ? "hourglass" : "person.crop.circle")
                .font(.system(size: 15, weight: .regular))

            Text("主体功能")
                .font(.system(size: 14, weight: .regular))
        }
        .foregroundStyle(Color.foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(Color.input, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .disabled(isDrawingSubjectDots)
    .opacity(isDrawingSubjectDots ? 0.5 : 1)
    .accessibilityLabel("主体功能")
}
```

Use `drawActions.padding(.top, 4)` in the body where `drawButton` was used.

- [ ] **Step 4: Add top-level panel action**

Add to `BottomSheetPanel`:

```swift
let onDrawSubjectDots: () -> Void
```

Pass it into `PanelContentCard`, and add the same property to `PanelContentCard`.

- [ ] **Step 5: Add ContentView state and panel arguments**

Add near other draw state:

```swift
@State private var isDrawingSubjectDots = false
@State private var subjectDotGenerationID = UUID()
```

Pass into `BottomSheetDotControls`:

```swift
isDrawingSubjectDots: isDrawingSubjectDots
```

Pass into `BottomSheetPanel`:

```swift
onDrawSubjectDots: drawSubjectPuzzleDots
```

- [ ] **Step 6: Add async ContentView action**

Add to `ContentView` near `drawPuzzleDots()`:

```swift
@MainActor
private func drawSubjectPuzzleDots() {
    guard let canvasImage else {
        showToast("请先上传图片")
        return
    }
    guard !isDrawingSubjectDots else { return }

    let generationID = UUID()
    subjectDotGenerationID = generationID
    isDrawingSubjectDots = true
    showToast("正在识别主体…")

    Task {
        do {
            let dots = try await SubjectContourDotGenerator().dots(
                for: canvasImage,
                count: Int(dotCount.rounded()),
                shapeAssetName: selectedDotShape.name
            )
            await MainActor.run {
                guard subjectDotGenerationID == generationID else { return }
                applyPuzzleDots(dots)
                isDrawingSubjectDots = false
                dismissToast()
            }
        } catch {
            await MainActor.run {
                guard subjectDotGenerationID == generationID else { return }
                isDrawingSubjectDots = false
                showToast(subjectDotErrorMessage(for: error))
            }
        }
    }
}

private func subjectDotErrorMessage(for error: Error) -> String {
    guard let generationError = error as? SubjectContourDotGenerationError else {
        return "主体识别失败"
    }

    switch generationError {
    case .unsupported:
        return "当前系统不支持主体识别"
    case .missingImage:
        return "主体识别失败"
    case .noSubject:
        return "没识别到主体"
    }
}
```

- [ ] **Step 7: Invalidate stale generation on new image**

Inside `loadSelectedPhoto()` after `let image = source.keyPhoto`, add:

```swift
subjectDotGenerationID = UUID()
isDrawingSubjectDots = false
```

- [ ] **Step 8: Run build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Expected: build passes.

- [ ] **Step 9: Commit panel and ContentView wiring**

```bash
git add chocho/BottomSheetPanelControls.swift chocho/BottomSheetPanel.swift chocho/ContentView.swift
git commit -m "Add subject dots draw panel action"
```

---

### Task 4: Final Verification

**Files:**
- Read: all modified Swift files
- Verify: build and tests

- [ ] **Step 1: Run tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData test
```

Expected: all tests pass.

- [ ] **Step 2: Run project build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Expected: build succeeds.

- [ ] **Step 3: Check git status**

```bash
git status --short
```

Expected: only pre-existing unrelated files remain modified, unless the user requested them staged.
