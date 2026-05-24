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

