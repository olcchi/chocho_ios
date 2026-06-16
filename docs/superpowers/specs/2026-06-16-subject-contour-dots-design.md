# Subject Contour Dots Design

## Goal

Add a subject-aware generation action to the draw panel. When the user taps "主体功能", the app uses Apple's Vision foreground instance mask support to find the main subject in the current photo, then generates puzzle dots around the outside of that subject's silhouette.

The generated dots remain normal `PuzzleDot` values in photo-normalized coordinates. The existing canvas renderer continues to mirror each dot into the photo layer and extension layer, preserving current collage tinting, random colors, live dot animations, undo/redo, drafts, and raster export behavior.

## User Experience

- The "抽卡" panel gains a separate "主体功能" action near the existing "抽一张" action.
- "抽一张" keeps its current behavior: random dots, or trace-based dots when "手绘轨迹" is enabled and a trace exists.
- "主体功能" does not toggle trace drawing and does not consume trace points.
- While subject detection is running, the subject action is disabled and the app shows a short loading toast.
- If no photo is loaded, show "请先上传图片".
- If the OS does not support the Vision request, show "当前系统不支持主体识别".
- If Vision cannot find a usable subject mask, show "没识别到主体".
- If generation succeeds, the new dots replace the current dots and are recorded in history.

## Architecture

`ContentView` remains the state owner. It passes a new `onDrawSubjectDots` action and `isDrawingSubjectDots` state into `BottomSheetPanel`.

`BottomSheetPanel` and `DrawPanelControls` only render controls and call the new action. They do not know about Vision, images, masks, or canvas geometry.

Subject detection and dot placement live outside the view layer:

- `SubjectContourDotGenerator`: async facade used by `ContentView`.
- `SubjectMaskProvider`: thin Vision wrapper around `VNGenerateForegroundInstanceMaskRequest`, available on iOS 17+.
- `SubjectContourSampler`: pure geometry and mask algorithm that turns a binary mask into normalized dot positions.

The sampler is the main test target. The Vision wrapper stays thin because model output is device and image dependent.

## Dot Placement

The sampler treats the Vision foreground mask as the subject. It extracts boundary pixels where foreground touches background, groups those boundary points into angle buckets around the subject center, then samples `dotCount` buckets at roughly equal intervals. Inside each selected bucket it chooses a point with small deterministic jitter so the result feels hand-arranged rather than perfectly mechanical.

Each sampled point is nudged away from the subject center by a small amount in normalized photo space. The final point is clamped to `0...1` so it remains valid for `PuzzleDot.position`.

Because positions stay in photo-normalized coordinates, existing `PuzzleCanvasCoordinate.dotCenters(for:in:)` continues to create the mirrored pair:

- center index `0`: dot on the photo side, showing extension/background collage content when collage tinting is active.
- center index `1`: mirrored dot on the extension side, showing photo content when collage tinting is active.

No new export rendering behavior is required.

## Data Flow

1. User taps "主体功能".
2. `ContentView.drawSubjectPuzzleDots()` validates that `canvasImage` exists.
3. `SubjectContourDotGenerator` requests a foreground instance mask for the current `UIImage`.
4. `SubjectContourSampler` produces normalized positions around the subject outline.
5. Positions are converted into `PuzzleDot` values using the current shape and existing random color palette pattern.
6. `ContentView.applyPuzzleDots(_:)` records the dots in undo history and schedules draft save.

## Error Handling

The action is async and cancellable by normal Swift task cancellation. If the user imports a new photo while detection is running, the result should be ignored unless it still belongs to the current image.

Vision failures are mapped to user-facing toast messages. Internal errors should not crash the app.

## Tests

Add focused unit tests for `SubjectContourSampler`:

- Returns no dots for empty masks.
- Generates the requested number of dots for a simple rectangular subject.
- Places dots outside the source foreground boundary directionally, while keeping them clamped to normalized photo coordinates.
- Produces stable output with a seeded random generator.

Add a light `ContentView`-independent test for the generator path by dependency-injecting a fake mask provider.

## Out Of Scope

- User-selectable multiple subjects.
- Manual subject editing or erasing.
- Motion in the extension background.
- New raster export code paths.
- VisionKit long-press subject interaction.
