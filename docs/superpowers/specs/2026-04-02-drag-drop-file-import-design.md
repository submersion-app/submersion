# Drag-and-Drop File Import

**Date:** 2026-04-02
**Status:** Approved

## Summary

Allow users to drag-and-drop a file into the Submersion application window (desktop) or share a file via the OS share sheet (mobile) to automatically open the universal import wizard with the file pre-loaded at the Source Confirmation step.

## Requirements

1. **Global drop target** -- the user can drop a file anywhere in the app, regardless of which screen they are on
2. **Frosted glass overlay** -- a full-screen semi-transparent blur overlay with a "Drop to Import" message appears when a file is dragged over the app window
3. **Desktop platforms** -- macOS, Windows, Linux via `desktop_drop` package
4. **Mobile platforms** -- iOS, Android via `receive_sharing_intent` package for OS-level file sharing intents ("Open with" / share sheet)
5. **Auto-advance** -- the dropped/shared file bypasses Step 0 (File Selection) and lands on Step 1 (Source Confirmation) with the file already loaded
6. **Content-based validation** -- the existing `FormatDetector` determines whether a file is supported; no extension-based pre-filtering

## Architecture

Two entry points converge on a single ingestion pipeline:

```
Desktop drag-and-drop (desktop_drop) ---+
                                        +--> Validate -> Load into provider -> Navigate to wizard
Mobile sharing intent (receive_sharing_intent) ---+
```

### Key Components

| Component | Location | Responsibility |
|-----------|----------|----------------|
| `GlobalDropTarget` | `lib/shared/widgets/global_drop_target.dart` | Wraps the `Scaffold` body inside `MainScaffold.build()` (both desktop and mobile layouts); provides DropTarget + frosted overlay on desktop; passes through on mobile |
| `loadFileFromBytes()` | `UniversalImportNotifier` | New method: accepts raw bytes + filename, runs format detection, sets wizard state at sourceConfirmation step |
| `FileShareHandler` | `lib/shared/services/file_share_handler.dart` | Listens for incoming file sharing intents on mobile; feeds files into `loadFileFromBytes()` |
| Platform config | `Info.plist`, `AndroidManifest.xml` | Registers Submersion as a handler for dive file types |

## Desktop Drag-and-Drop

### GlobalDropTarget Widget

- Wraps the content area inside `MainScaffold`
- Uses `desktop_drop`'s `DropTarget` widget with `onDragEntered`, `onDragExited`, `onDragDone` callbacks
- Only renders `DropTarget` on desktop platforms (`Platform.isWindows || Platform.isMacOS || Platform.isLinux`); on mobile, passes through the child unchanged
- Manages a local `_isDragging` boolean state (StatefulWidget, no Riverpod provider needed)

### Frosted Glass Overlay

- `Positioned.fill` in a `Stack` layered above app content
- `BackdropFilter(filter: ImageFilter.blur(...))` with a semi-transparent dark scrim
- Dashed icon border with upload icon, "Drop to Import" text, "Release to open import wizard" subtitle
- Animated in/out with a short opacity fade (`AnimatedOpacity` or similar)
- Color scheme: cool blue tones (rgba 100, 180, 255 range) on dark background

### Drop Handler Logic

On `onDragDone` (receives `DropDoneDetails` containing `List<XFile>`):

1. Take the first `XFile` only (ignore additional files if multiple dropped)
2. Check current route via `GoRouterState` -- if path starts with `/transfer/import-wizard`, show snackbar "Finish current import first" and return
3. Read file bytes via `xFile.readAsBytes()`
4. Call `loadFileFromBytes(bytes, fileName)` -- this runs format detection internally and returns the `DetectionResult`
5. If result format is `ImportFormat.unknown`, show snackbar "Unsupported file type" and return
6. Navigate to `/transfer/import-wizard`

## Mobile File Sharing Intents

### Platform Registration

**iOS (`Info.plist`):**
- Add `UTImportedTypeDeclarations` for custom types (`.uddf`, `.fit`, `.sml`)
- Add `CFBundleDocumentTypes` for file extensions: `.uddf`, `.fit`, `.csv`, `.xml`, `.sml`, `.db`

**Android (`AndroidManifest.xml`):**
- Add `<intent-filter>` with `<action android:name="android.intent.action.VIEW"/>`
- Register matching MIME types and file extensions

### FileShareHandler

- Uses `receive_sharing_intent` package
- Listens for incoming files at cold start (`getInitialMedia()`) and while running (`getMediaStream()`)
- On file received: read bytes, run through same validation and ingestion pipeline as desktop drop
- Same edge case handling: wizard active -> toast and ignore; unknown format -> toast and ignore
- Cold start files processed after app initialization completes

## State Management

### New Method: `UniversalImportNotifier.loadFileFromBytes()`

Mirrors the existing `pickFile()` logic minus the `FilePicker` call:

1. Reset state to `fileSelection` step (enables auto-advance transition)
2. Set `isLoading: true`
3. Run `FormatDetector.detect(bytes)`
4. Handle Shearwater SQLite special case (same as `pickFile`)
5. Set state with `fileBytes`, `fileName`, `detectionResult`
6. Advance `currentStep` to `sourceConfirmation`

Returns `DetectionResult` so the caller can check for `ImportFormat.unknown` before navigating. Detection runs once inside this method -- callers do not need to run `FormatDetector` separately.

### Wizard Active Check

Uses current router location: if it starts with `/transfer/import-wizard`, the wizard is active. No new state needed -- the router is the source of truth.

### Overlay State

Local to `GlobalDropTarget` as `_isDragging` boolean in a `StatefulWidget`. Not shared via Riverpod since nothing else consumes it.

## Supported Formats

Content-based detection via `FormatDetector`:

| Format | Detection Method |
|--------|-----------------|
| FIT (Garmin) | Binary magic bytes `.FIT` |
| SQLite / Shearwater Cloud DB | `SQLite format 3` header |
| Subsurface XML | `<divelog program='subsurface'>` |
| UDDF | `<uddf>` root element |
| Diving Log XML | `<DivingLog>` root |
| Suunto SML | `<sml>` root |
| DAN DL7 | DL7 markers |
| CSV (many apps) | Header analysis for MacDive, Diving Log, DiveMate, Subsurface, SSI, Garmin Connect, Shearwater, Submersion, generic dive CSVs |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Unsupported file type | Snackbar "Unsupported file type", stay on current screen |
| Wizard already active | Snackbar "Finish current import first", ignore drop |
| Multiple files dropped | Take the first file only, ignore the rest |
| Empty file (0 bytes) | FormatDetector returns `unknown` -- handled by unsupported path |
| File read fails | Snackbar with error message, stay on current screen |
| Mobile: file at cold start | Process after app initialization completes, then navigate |
| Mobile: file while running | Same flow as desktop drop |
| Drop during navigation animation | Safe -- route check uses current location |

## Dependencies

### New Packages

| Package | Purpose |
|---------|---------|
| `desktop_drop` | Desktop drag-and-drop DropTarget widget |
| `receive_sharing_intent` | Mobile file sharing intent listener |

### Existing Code Touched

| File | Change |
|------|--------|
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Add `loadFileFromBytes()` method |
| `lib/shared/widgets/main_scaffold.dart` | Wrap content with `GlobalDropTarget` |
| `lib/core/router/app_router.dart` | No changes needed -- existing route works |
| `ios/Runner/Info.plist` | Add document type declarations |
| `android/app/src/main/AndroidManifest.xml` | Add intent filter |

### New Files

| File | Purpose |
|------|--------|
| `lib/shared/widgets/global_drop_target.dart` | GlobalDropTarget widget with frosted overlay |
| `lib/shared/services/file_share_handler.dart` | Mobile file sharing intent listener |

## Testing

- Unit test: `loadFileFromBytes()` sets correct state for each supported format
- Unit test: `loadFileFromBytes()` returns unknown for unsupported files
- Widget test: `GlobalDropTarget` shows overlay on drag enter, hides on drag exit
- Widget test: drop while wizard is active shows snackbar and does not navigate
- Widget test: drop of unsupported file shows snackbar and does not navigate
- Integration test: full flow from drop to wizard Source Confirmation step
