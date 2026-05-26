# AGENTS.md

Guidance for coding agents working in this repository.

## Project Shape

- This is a SwiftUI iOS app in an Xcode project.
- App entry point: `chocho/chochoApp.swift`.
- Root screen: `chocho/ContentView.swift`.
- Current bottom panel component: `chocho/BottomSheetPanel.swift`.
- Xcode project: `chocho.xcodeproj`.
- Scheme: `chocho`.

Keep responsibilities clear:

- `chochoApp` wires the app root.
- `ContentView` owns whole-screen layout, background, safe area decisions, and where child components sit on screen.
- Component files, such as `BottomSheetPanel`, own their internal layout and interactions only.

For example, a bottom panel should not usually call `.ignoresSafeArea(.bottom)` by itself. The parent screen should decide whether the panel extends into the device bottom safe area.

## SwiftUI Development Flow

When changing UI:

1. Start from the root view to understand the full screen.
2. Find the component being edited and keep the change scoped.
3. Prefer small SwiftUI subviews over one large view body.
4. Use `@State` for state owned by the current view.
5. Use `@Binding` when a child needs to read or mutate parent-owned state.
6. Avoid adding view models until state or behavior is complex enough to justify one.

For this project, prefer:

```swift
ContentView
  -> screen background, safe area, panel placement
BottomSheetPanel
  -> panel shape, tabs, cursor, panel content
```

## Previews

Use previews for two different purposes:

- Root preview: shows the whole current app screen.
- Component preview: shows one component in isolation.

The root app preview belongs in `ContentView.swift`:

```swift
#Preview("App") {
    ContentView()
}
```

If editing a component but wanting to keep the whole screen visible in Xcode Canvas, it is OK to also add a temporary or permanent app preview in that component file:

```swift
#Preview("App") {
    ContentView()
}
```

Component previews should include enough surrounding layout to make the component understandable, but should not pretend to validate whole-screen safe area behavior unless they render the root view.

Xcode Canvas normally shows previews from the current file. To inspect the whole app while editing another component, either:

- open `ContentView.swift`, or
- add `#Preview("App") { ContentView() }` in the current component file, or
- pin the root preview in Xcode Canvas.

Use Simulator runs for final checks involving animation, safe areas, gestures, keyboard behavior, and device-specific layout. Preview is a fast layout tool, not the final authority.

## Build Commands

The active developer directory may point at Command Line Tools, so use full Xcode explicitly:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project chocho.xcodeproj \
  -scheme chocho \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  build
```

Use project-local derived data under `.build/DerivedData` so build output stays inside the workspace.

If `xcodebuild` reports that the active developer directory is `/Library/Developer/CommandLineTools`, rerun with the `DEVELOPER_DIR` prefix above.

## Debugging With Build iOS Apps

When asked to run, inspect, or debug the app on a simulator, prefer the Build iOS Apps debugger workflow:

1. Discover the booted simulator.
2. Set session defaults with:
   - project path: `chocho.xcodeproj`
   - scheme: `chocho`
   - configuration: `Debug`
   - latest available iOS runtime
3. Build and run the app.
4. Verify launch with a UI description or screenshot before interacting.
5. Use UI description before taps, typing, or gestures.
6. Capture logs when diagnosing runtime behavior.

If no simulator is booted, ask the user to boot one instead of silently changing their simulator state.

## Debugging Order

When something breaks, use this order:

1. Read the exact compiler, runtime, or Canvas error.
2. Identify the smallest file or view involved.
3. Check state ownership: `@State`, `@Binding`, environment, initializer inputs.
4. Check whether the issue only happens in Preview or also in Simulator.
5. Build with `xcodebuild` to separate Canvas problems from compiler problems.
6. If it is a runtime issue, run on Simulator and inspect UI/logs.
7. Fix the smallest cause and rebuild.

Do not guess from screenshots alone when logs, compiler output, or UI hierarchy are available.

## Safe Area And Bottom Panels

For bottom-attached UI:

- The root screen should decide safe area behavior.
- A bottom panel component should describe its own height, background, shape, content, and interaction.
- Use parent placement such as `ZStack(alignment: .bottom)` for screen positioning.
- If the design calls for the panel to visually continue below the safe area, apply that at the parent boundary, where `GeometryProxy.safeAreaInsets.bottom` is available.

This keeps reusable components from forcing whole-screen behavior.

## Live Panel Animations (实况)

The **实况** bottom-panel tab controls canvas motion for preview and export. It is not the same as importing an iOS Live Photo from the library (that path only supplies a key frame today).

### What the select controls

- UI: `LivePanelControls` in `chocho/BottomSheetPanel.swift` — label **动画**, `PanelValueMenu` bound to `LiveDotAnimation`.
- State owner: `ContentView` holds `@State private var liveDotAnimation` and passes `$liveDotAnimation` through `BottomSheetPanel` → `PanelContentCard` → `LivePanelControls`.
- Options source: `LiveDotAnimation.allCases` (order = menu order). User-facing labels come from `LiveDotAnimation.title` (e.g. **无**, **闪烁**).

### What animations apply to (scope)

| Layer | Animated when animation ≠ 无? |
| --- | --- |
| Puzzle dots (`PuzzleDot`) | Yes — per-dot opacity over time |
| Main photo (`UIImage` in canvas) | No — static |
| Extension background (grid / stripes) | No — static |

Do not add motion to the extension panel background unless the product explicitly asks for it. Live Photo motion should come from dots only so the background does not compete with the effect.

### Type and naming conventions

Define animations in `chocho/PuzzleCanvasModel.swift`:

```swift
nonisolated enum LiveDotAnimation: String, CaseIterable, Identifiable, Equatable {
    case none
    case randomBlink
    // add new cases here

    var title: String { ... }           // menu label (Chinese UI copy)
    var exportsAsLivePhoto: Bool { self != .none }
}
```

- `none` — preview and download behave like a normal still export (JPEG).
- Any other case — treated as live motion; `exportsAsLivePhoto` is `true` when `self != .none` (adjust if a future case should preview without Live Photo export).

Put animation math/helpers next to the enum (e.g. `DotRandomBlinkOpacity` for **闪烁**). Keep helpers `nonisolated` if used from export on a background queue.

### Preview pipeline

- `PuzzleCanvasView` takes `liveDotAnimation` and, when `== .randomBlink`, drives a single `TimelineView` (~60 fps) that passes `blinkTime` into:
  - `PuzzleDotsCanvas` — applies per-dot opacity from `DotRandomBlinkOpacity.opacity(dotID:time:)`.
- Extension background views (`PuzzleGridCanvas` / `PuzzleStripesCanvas`) do **not** take `blinkTime`.

### Export / download pipeline

When the user taps download (`ContentView.shareCanvas`):

1. `CanvasExportWriter.format(liveDotAnimation:)` → `.livePhoto` if `exportsAsLivePhoto`, else `.staticJPEG`.
2. **Live Photo** (`CanvasLivePhotoExporter`):
   - Key still: full `exportCanvasSize` JPEG with `CanvasLivePhotoMetadata` asset identifier.
   - Paired video: lower resolution (`CanvasLivePhotoSizing`, max long edge 1080px, 15 fps, ~3 s) rendered via `CanvasRasterExporter.render(..., liveDotAnimation:, blinkTime:)`.
   - Assemble with `PHLivePhoto.request`; save via `CanvasPhotoLibrarySaver.saveLivePhoto` (photo + `.pairedVideo` resources).
3. **Still** — single `CanvasRasterExporter.render` without motion, JPEG to temp, share sheet.

Temporary live export files must stay on disk until save finishes; `ContentView` defers cleanup for live exports when the share sheet dismisses (see `retainsLivePhotoExportFilesOnDismiss`).

### Raster export rules (important for new animations)

Preview can use SwiftUI `.opacity()`. Export uses `CanvasRasterExporter` and Core Graphics:

- **Do not rely on `CGContext.setAlpha` alone** for `UIImage.draw(in:)` — it is ignored. Pass explicit `opacity` into draw helpers and use `image.draw(in:blendMode:alpha:)` or `color.withAlphaComponent(opacity)`.
- Collage mirror dots: `centerIndex == 0` → extension sample inside dot on photo side; `centerIndex == 1` → photo sample inside dot on extension side. Both must receive the same dot opacity for that frame.

### Adding a new animation (checklist)

1. Add a `LiveDotAnimation` case + `title` in `PuzzleCanvasModel.swift`.
2. Implement preview in `PuzzleCanvasView` / `PuzzleDotsCanvas` (or shared helper) when `liveDotAnimation == .yourCase`.
3. Implement export frames in `CanvasRasterExporter` (same visual logic as preview, explicit alpha on images).
4. If motion should export as Live Photo, no change needed if `exportsAsLivePhoto` remains `self != .none`; otherwise override that property.
5. Wire nothing extra in `LivePanelControls` — `PanelValueMenu(..., options: LiveDotAnimation.allCases, ...)` picks up new cases automatically.
6. Add tests: export format selection in `CanvasExportWriterTests`; optional raster regression in `CanvasRasterExporterTests` if opacity/geometry is easy to assert.
7. Verify in Simulator: preview, then 实况 → download → save Live Photo → long-press in Photos (photo area and extension dots both move if applicable).

### File map

| Concern | File |
| --- | --- |
| Enum + dot opacity math | `PuzzleCanvasModel.swift` (`LiveDotAnimation`, `DotRandomBlinkOpacity`) |
| Panel select UI | `BottomSheetPanel.swift` (`LivePanelControls`) |
| Screen state + download | `ContentView.swift` |
| Canvas preview | `PuzzleCanvasView.swift` |
| Frame rasterization | `CanvasRasterExporter.swift` |
| Live Photo assembly | `CanvasLivePhotoExporter.swift`, `CanvasLivePhotoMetadata.swift`, `CanvasLivePhotoSizing` (in exporter file) |
| Export format branch | `CanvasExportWriter.swift` |
| Share / save product | `CanvasExportProduct.swift`, `CanvasPhotoLibrarySaver.swift` |

## Git And Generated Files

- Do not revert user changes unless explicitly asked.
- Keep edits scoped to the requested task.
- `.build/` is local build output and should not be treated as source.
- Xcode user data under `xcuserdata/` is usually local machine state; avoid changing or relying on it unless the user specifically asks.

## Verification Before Handoff

Before saying a change is complete:

- For Swift source changes, run the project build command above.
- For documentation-only changes, verify the file exists and read the changed content.
- Report any command that could not run and why.

