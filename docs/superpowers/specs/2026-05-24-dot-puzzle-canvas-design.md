# Dot Puzzle Canvas Design

## Goal

Build the first version of the dot puzzle tool around the canvas area shown in the reference: an uploaded photo sits on the left, and a right-side drawing canvas is attached directly to it with no visible gap or border. The right canvas height always matches the photo height. Its width is adjustable from `0` to the displayed photo width, with the initial implementation reserving this state even if the user-facing width control is added later.

## Scope

The first implementation should support:

- Uploading a photo through the existing photo picker.
- Displaying the photo as the left side of a composed puzzle canvas.
- Displaying a right-side light blue grid canvas attached to the photo.
- Generating randomized colored dot/star marks across the composed photo-plus-canvas area.
- Controlling dot count from the bottom panel.
- Exporting the current composed puzzle image.

The first implementation should not include a finished UI for resizing the right canvas unless it falls out naturally from the bottom panel controls. The model state should still represent the width as a ratio so a later slider can bind to it directly.

## Architecture

`ContentView` remains responsible for whole-screen layout, upload/download actions, safe area handling, and placement of the bottom panel.

A new SwiftUI component should own the internal puzzle canvas composition. A likely name is `PuzzleCanvasView`. It receives the uploaded `UIImage`, right canvas width ratio, generated dot data, and any interaction bindings needed by the parent. It is responsible for fitting the composed puzzle into the available screen space and drawing the photo, attached grid, and dots.

`BottomSheetPanel` remains responsible for controls inside the bottom panel. For this feature it should expose bindings/actions for dot count and drawing a new set of dots. The panel should not decide whole-screen canvas placement or safe area behavior.

## Canvas Layout

The source photo defines the base dimensions.

- Photo display width and height preserve the photo aspect ratio.
- Right canvas display height equals the photo display height.
- Right canvas display width is `photoDisplayWidth * extensionRatio`.
- `extensionRatio` is clamped to `0...1`.
- The composed puzzle display width is `photoDisplayWidth + rightCanvasDisplayWidth`.
- The photo and right canvas share an edge, with no spacing, border, or divider.

When fitting into the available screen area, the full composed puzzle should be scaled to fit. This means increasing the right canvas width can reduce the displayed photo size on small screens, but the exported composition still follows the same proportions.

## Drawing

Use SwiftUI `Canvas` for generated visual layers. The photo can remain a normal SwiftUI `Image` layer, with the grid and dots drawn above or beside it as needed.

The right canvas background should start as a light blue square grid similar to the reference. The grid belongs only to the right canvas region.

Dots should be stored as data, not as view state hidden inside drawing code. Each dot should include:

- A normalized point in the composed puzzle area.
- A color.
- A size.
- A style for the mark, initially a simple star/asterisk-like mark matching the reference direction.

Normalized coordinates make the dots stable when the canvas is displayed at different sizes or exported at a different scale.

## Data Flow

`ContentView` owns:

- Uploaded image.
- Right canvas width ratio.
- Dot count.
- Generated dot array.
- Export/share state.

`BottomSheetPanel` receives:

- Selected tab binding.
- Dot count binding.
- Draw/regenerate action.

`PuzzleCanvasView` receives:

- Uploaded image.
- Right canvas width ratio.
- Dot array.

This keeps user controls, app-level actions, and drawing responsibilities separate.

## Export

Export should render the same composed puzzle view used on screen so the downloaded result matches the visible composition. The export size should be derived from the source photo dimensions and `extensionRatio`:

- Export height: source photo pixel height.
- Export photo width: source photo pixel width.
- Export right canvas width: `source photo pixel width * extensionRatio`.
- Export total width: photo width plus right canvas width.

If `extensionRatio` is `0`, export is just the photo plus generated dots that fall inside the photo area.

## Error Handling

If no photo is uploaded, download should keep the existing friendly message asking the user to upload first.

If photo loading fails, keep the existing upload failure message.

If export rendering or file writing fails, keep the existing export failure messages.

If dot generation is requested before a photo is uploaded, keep the action harmless and show a short status message.

## Verification

Swift source changes should be verified with the project build command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project chocho.xcodeproj \
  -scheme chocho \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  build
```

Manual verification should confirm:

- Uploading a photo creates a left photo and attached right grid.
- The shared edge has no gap or border.
- Generated marks appear on both photo and right canvas regions.
- Dot count affects the number of generated marks.
- Exported image preserves the same photo-plus-canvas composition.
