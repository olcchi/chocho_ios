# Dot Puzzle Canvas Implementation Plan

**Goal:** Build a SwiftUI dot puzzle canvas where an uploaded photo sits directly beside a right-side adjustable grid canvas, with generated dot/star marks and export support.

**Architecture:** `ContentView` owns app-level state and export, `PuzzleCanvasView` owns internal photo-plus-grid composition, and `BottomSheetPanel` owns bottom controls. Testable layout and dot generation logic live in small Swift files so behavior can be verified before UI wiring.

**Tech Stack:** SwiftUI, PhotosUI, XCTest, Xcode project targets, `ImageRenderer`, SwiftUI `Canvas`.

---

## File Structure

- Create `chocho/PuzzleCanvasModel.swift`: layout math, dot model, random dot generator.
- Create `chocho/PuzzleCanvasView.swift`: composed photo, right grid canvas, and dot/star drawing.
- Modify `chocho/ContentView.swift`: replace current draggable image area with puzzle canvas state and export.
- Modify `chocho/BottomSheetPanel.swift`: add dot count binding and draw action controls.
- Modify `chocho.xcodeproj/project.pbxproj`: include new source files and add a `chochoTests` unit test target.
- Create `chochoTests/PuzzleCanvasModelTests.swift`: test layout clamping and dot generation.

## Task 1: Testable Puzzle Model

**Files:**
- Create: `chocho/PuzzleCanvasModel.swift`
- Create: `chochoTests/PuzzleCanvasModelTests.swift`
- Modify: `chocho.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add failing model tests**

Create `chochoTests/PuzzleCanvasModelTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import chocho

struct PuzzleCanvasModelTests {
    @Test func layoutClampsExtensionRatioAndFitsComposedCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 1000, height: 500),
            availableSize: CGSize(width: 600, height: 240),
            extensionRatio: 1.4
        )

        #expect(layout.extensionRatio == 1)
        #expect(layout.photoFrame.size.width == 480)
        #expect(layout.photoFrame.size.height == 240)
        #expect(layout.extensionFrame.size.width == 480)
        #expect(layout.extensionFrame.size.height == 240)
        #expect(layout.composedSize.width == 960)
        #expect(layout.composedSize.height == 240)
        #expect(layout.extensionFrame.minX == layout.photoFrame.maxX)
    }

    @Test func layoutAllowsZeroWidthExtensionCanvas() {
        let layout = PuzzleCanvasLayout.layout(
            imageSize: CGSize(width: 800, height: 400),
            availableSize: CGSize(width: 390, height: 300),
            extensionRatio: -0.2
        )

        #expect(layout.extensionRatio == 0)
        #expect(layout.extensionFrame.width == 0)
        #expect(layout.photoFrame.width == 390)
        #expect(layout.photoFrame.height == 195)
    }

    @Test func generatedDotsMatchRequestedCount() {
        let dots = PuzzleDotFactory.makeDots(count: 10)

        #expect(dots.count == 10)
        #expect(dots.allSatisfy { 0...1 ~= $0.position.x && 0...1 ~= $0.position.y })
        #expect(dots.allSatisfy { $0.size > 0 })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData
```

Expected: FAIL because `chochoTests` and `PuzzleCanvasLayout` do not exist yet.

- [ ] **Step 3: Add minimal model implementation**

Create `chocho/PuzzleCanvasModel.swift`:

```swift
import CoreGraphics
import SwiftUI

struct PuzzleCanvasLayoutResult: Equatable {
    let extensionRatio: CGFloat
    let photoFrame: CGRect
    let extensionFrame: CGRect
    let composedSize: CGSize
}

enum PuzzleCanvasLayout {
    static func layout(
        imageSize: CGSize,
        availableSize: CGSize,
        extensionRatio: CGFloat
    ) -> PuzzleCanvasLayoutResult {
        let clampedRatio = min(max(extensionRatio, 0), 1)

        guard imageSize.width > 0,
              imageSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return PuzzleCanvasLayoutResult(
                extensionRatio: clampedRatio,
                photoFrame: .zero,
                extensionFrame: .zero,
                composedSize: .zero
            )
        }

        let composedAspect = (imageSize.width * (1 + clampedRatio)) / imageSize.height
        let fitScale = min(
            availableSize.width / (imageSize.width * (1 + clampedRatio)),
            availableSize.height / imageSize.height
        )
        let photoSize = CGSize(width: imageSize.width * fitScale, height: imageSize.height * fitScale)
        let extensionSize = CGSize(width: photoSize.width * clampedRatio, height: photoSize.height)
        let composedSize = CGSize(width: photoSize.width + extensionSize.width, height: photoSize.height)
        let origin = CGPoint(
            x: (availableSize.width - composedSize.width) / 2,
            y: (availableSize.height - composedSize.height) / 2
        )

        return PuzzleCanvasLayoutResult(
            extensionRatio: clampedRatio,
            photoFrame: CGRect(origin: origin, size: photoSize),
            extensionFrame: CGRect(
                x: origin.x + photoSize.width,
                y: origin.y,
                width: extensionSize.width,
                height: extensionSize.height
            ),
            composedSize: composedSize
        )
    }
}

struct PuzzleDot: Identifiable, Equatable {
    let id: UUID
    let position: CGPoint
    let color: Color
    let size: CGFloat
}

enum PuzzleDotFactory {
    static func makeDots(count: Int) -> [PuzzleDot] {
        let palette: [Color] = [
            Color(red: 138 / 255, green: 255 / 255, blue: 78 / 255),
            Color(red: 77 / 255, green: 238 / 255, blue: 91 / 255),
            Color(red: 82 / 255, green: 72 / 255, blue: 235 / 255),
            Color(red: 255 / 255, green: 233 / 255, blue: 52 / 255),
            Color(red: 255 / 255, green: 48 / 255, blue: 119 / 255)
        ]

        return (0..<max(count, 0)).map { index in
            PuzzleDot(
                id: UUID(),
                position: CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1)),
                color: palette[index % palette.count],
                size: CGFloat.random(in: 24...42)
            )
        }
    }
}
```

- [ ] **Step 4: Wire the test target and source membership**

Update `chocho.xcodeproj/project.pbxproj` so `PuzzleCanvasModel.swift` belongs to the app target and `PuzzleCanvasModelTests.swift` belongs to a new `chochoTests` unit test target that depends on the app target.

- [ ] **Step 5: Run tests to verify they pass**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData
```

Expected: PASS for `PuzzleCanvasModelTests`.

## Task 2: Puzzle Canvas View

**Files:**
- Create: `chocho/PuzzleCanvasView.swift`
- Modify: `chocho.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add `PuzzleCanvasView`**

Create `chocho/PuzzleCanvasView.swift`:

```swift
import SwiftUI
import UIKit

struct PuzzleCanvasView: View {
    let image: UIImage
    let extensionRatio: CGFloat
    let dots: [PuzzleDot]

    var body: some View {
        GeometryReader { proxy in
            let layout = PuzzleCanvasLayout.layout(
                imageSize: image.size,
                availableSize: proxy.size,
                extensionRatio: extensionRatio
            )

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: layout.photoFrame.width, height: layout.photoFrame.height)
                    .position(x: layout.photoFrame.midX, y: layout.photoFrame.midY)

                PuzzleGridCanvas()
                    .frame(width: layout.extensionFrame.width, height: layout.extensionFrame.height)
                    .position(x: layout.extensionFrame.midX, y: layout.extensionFrame.midY)

                PuzzleDotsCanvas(dots: dots, composedFrame: CGRect(
                    x: layout.photoFrame.minX,
                    y: layout.photoFrame.minY,
                    width: layout.composedSize.width,
                    height: layout.composedSize.height
                ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct PuzzleGridCanvas: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 248 / 255, green: 252 / 255, blue: 255 / 255)))

            let spacing: CGFloat = 12
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(Color(red: 200 / 255, green: 229 / 255, blue: 255 / 255)), lineWidth: 1)
        }
    }
}

private struct PuzzleDotsCanvas: View {
    let dots: [PuzzleDot]
    let composedFrame: CGRect

    var body: some View {
        Canvas { context, _ in
            for dot in dots {
                let center = CGPoint(
                    x: composedFrame.minX + dot.position.x * composedFrame.width,
                    y: composedFrame.minY + dot.position.y * composedFrame.height
                )

                context.stroke(starPath(center: center, radius: dot.size / 2), with: .color(dot.color), lineWidth: 4)
            }
        }
    }

    private func starPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let angles: [CGFloat] = [0, .pi / 4, .pi / 2, 3 * .pi / 4]

        for angle in angles {
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
        }

        return path
    }
}
```

- [ ] **Step 2: Add the file to the app target**

Update `chocho.xcodeproj/project.pbxproj` so `PuzzleCanvasView.swift` is included in the `chocho` target sources.

- [ ] **Step 3: Build to verify the component compiles**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Expected: BUILD SUCCEEDED.

## Task 3: Wire App State, Controls, and Export

**Files:**
- Modify: `chocho/ContentView.swift`
- Modify: `chocho/BottomSheetPanel.swift`

- [ ] **Step 1: Replace old canvas image state with puzzle state**

In `ContentView`, keep `selectedPhotoItem`, `canvasImage`, `exportMessage`, and `shareItem`, then add:

```swift
@State private var extensionRatio: CGFloat = 0.2
@State private var dotCount: Double = 10
@State private var puzzleDots: [PuzzleDot] = []
```

- [ ] **Step 2: Render the new puzzle canvas**

Replace `CanvasArea(...)` with conditional rendering that shows `PuzzleCanvasView` after upload and the existing upload placeholder before upload.

- [ ] **Step 3: Regenerate dots from the bottom panel**

Update the `BottomSheetPanel` initializer to accept:

```swift
@Binding var dotCount: Double
let onDrawDots: () -> Void
```

For the draw tab, show a dot count slider and an `抽一张` button that calls `onDrawDots`.

- [ ] **Step 4: Export the composed puzzle**

Update `CanvasExportView` to render `PuzzleCanvasView` at:

```swift
let exportSize = CGSize(
    width: canvasImage.size.width * (1 + min(max(extensionRatio, 0), 1)),
    height: canvasImage.size.height
)
```

Pass `extensionRatio` and `puzzleDots` into the export view.

- [ ] **Step 5: Build to verify the wired UI compiles**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Expected: BUILD SUCCEEDED.

## Task 4: Final Verification

**Files:**
- Verify: `chocho/ContentView.swift`
- Verify: `chocho/BottomSheetPanel.swift`
- Verify: `chocho/PuzzleCanvasView.swift`
- Verify: `chocho/PuzzleCanvasModel.swift`

- [ ] **Step 1: Run unit tests**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData
```

Expected: TEST SUCCEEDED.

- [ ] **Step 2: Run app build**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project chocho.xcodeproj -scheme chocho -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual review checklist**

Confirm in simulator or preview:

- Upload placeholder still appears before image selection.
- Uploaded photo appears on the left of the composed puzzle.
- Right grid canvas touches the photo with no gap.
- `抽一张` generates marks.
- Dot count changes generated mark count.
- Download exports the composed photo-plus-grid image.
