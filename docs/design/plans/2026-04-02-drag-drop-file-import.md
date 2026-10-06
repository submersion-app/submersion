# Drag-and-Drop File Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to drag-and-drop files into the app (desktop) or share files via OS share sheet (mobile) to auto-open the universal import wizard at the Source Confirmation step.

**Architecture:** Two entry points (desktop `DropTarget` widget from `desktop_drop`, mobile stream listener from `receive_sharing_intent`) converge on a new `UniversalImportNotifier.loadFileFromBytes()` method that runs format detection and sets wizard state. A `GlobalDropTarget` widget wraps `MainScaffold` content with a frosted glass overlay on desktop.

**Tech Stack:** Flutter, desktop_drop, receive_sharing_intent, Riverpod, go_router, existing FormatDetector

**Spec:** `docs/superpowers/specs/2026-04-02-drag-drop-file-import-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `pubspec.yaml` | Modify | Add `desktop_drop` and `receive_sharing_intent` packages |
| `lib/l10n/arb/app_en.arb` | Modify | Add l10n keys for drop overlay and error messages |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Modify | Add `loadFileFromBytes()` method to `UniversalImportNotifier` |
| `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart` | Modify | Add tests for `loadFileFromBytes()` |
| `lib/shared/widgets/global_drop_target.dart` | Create | `GlobalDropTarget` widget with frosted glass overlay |
| `lib/shared/widgets/main_scaffold.dart` | Modify | Wrap content with `GlobalDropTarget` |
| `lib/shared/services/file_share_handler.dart` | Create | Mobile file sharing intent listener |
| `lib/app.dart` | Modify | Initialize `FileShareHandler`, add `scaffoldMessengerKey` |
| `ios/Runner/Info.plist` | Modify | Add SML and SQLite document type declarations |
| `android/app/src/main/AndroidManifest.xml` | Modify | Add intent filters for file sharing/opening |

---

### Task 1: Add packages

**Files:**
- Modify: `pubspec.yaml:58-68` (Platform Integration section)

- [ ] **Step 1: Add desktop_drop and receive_sharing_intent to pubspec.yaml**

In `pubspec.yaml`, add to the `# Platform Integration` section after the existing `share_plus` entry (line 64):

```yaml
  desktop_drop: ^0.4.4
  receive_sharing_intent: ^1.8.1
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully, no version conflicts.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add desktop_drop and receive_sharing_intent packages"
```

---

### Task 2: Add l10n strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add drop target l10n keys to app_en.arb**

Add these entries to `lib/l10n/arb/app_en.arb` in the appropriate alphabetical position (after any existing `dropTarget_` entries, or in a new block near the `universalImport_` section):

```json
  "dropTarget_title": "Drop to Import",
  "dropTarget_subtitle": "Release to open import wizard",
  "dropTarget_error_unsupportedFile": "Unsupported file type",
  "dropTarget_error_wizardActive": "Finish current import first",
  "dropTarget_error_readFailed": "Could not read file",
```

- [ ] **Step 2: Run code generation to produce the l10n Dart files**

Run: `flutter gen-l10n`
Expected: No errors. The generated `app_localizations_en.dart` should include the new getters.

- [ ] **Step 3: Verify the new keys are accessible**

Run: `grep -c "dropTarget_" lib/l10n/arb/app_localizations_en.dart`
Expected: Output `5` (one getter per key).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n strings for drag-and-drop import overlay"
```

---

### Task 3: TDD -- loadFileFromBytes() on UniversalImportNotifier

**Files:**
- Test: `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart:71` (after `_buildPresetRegistry`, before `pickFile`)

- [ ] **Step 1: Write failing tests for loadFileFromBytes()**

Add the following test group to the existing `group('UniversalImportNotifier', () { ... })` block in `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`:

```dart
    group('loadFileFromBytes', () {
      test('sets state to sourceConfirmation for a recognized UDDF file',
          () async {
        final uddfBytes = Uint8List.fromList(
          '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
        );

        final result =
            await notifier.loadFileFromBytes(uddfBytes, 'test.uddf');

        expect(result.format, ImportFormat.uddf);
        expect(
            notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
        expect(notifier.state.fileName, 'test.uddf');
        expect(notifier.state.fileBytes, uddfBytes);
        expect(notifier.state.isLoading, false);
      });

      test('returns unknown for unsupported file types', () async {
        final pngBytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, // PNG magic bytes
          0x0D, 0x0A, 0x1A, 0x0A,
        ]);

        final result =
            await notifier.loadFileFromBytes(pngBytes, 'photo.png');

        expect(result.format, ImportFormat.unknown);
      });

      test('detects FIT format from binary magic bytes', () async {
        final fitBytes = Uint8List(14);
        fitBytes[0] = 14; // header size
        fitBytes[8] = 0x2E; // .
        fitBytes[9] = 0x46; // F
        fitBytes[10] = 0x49; // I
        fitBytes[11] = 0x54; // T

        final result =
            await notifier.loadFileFromBytes(fitBytes, 'dive.fit');

        expect(result.format, ImportFormat.fit);
        expect(result.sourceApp, SourceApp.garminConnect);
      });

      test('detects CSV with dive keywords', () async {
        final csvBytes = _csvBytes(
          'dive number,date,max depth,bottom time,water temp\n'
          '1,2024-01-01,30.0,45,22.0\n',
        );

        final result =
            await notifier.loadFileFromBytes(csvBytes, 'dives.csv');

        expect(result.format, ImportFormat.csv);
      });

      test('resets state before detection to enable auto-advance', () async {
        // Simulate prior wizard state
        notifier.setPendingSourceOverride(SourceApp.subsurface);

        final uddfBytes = Uint8List.fromList(
          '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
        );
        await notifier.loadFileFromBytes(uddfBytes, 'test.uddf');

        expect(
            notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
        expect(notifier.state.error, isNull);
      });

      test('populates detectionResult in state', () async {
        final uddfBytes = Uint8List.fromList(
          '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
        );

        await notifier.loadFileFromBytes(uddfBytes, 'test.uddf');

        expect(notifier.state.detectionResult, isNotNull);
        expect(notifier.state.detectionResult!.format, ImportFormat.uddf);
      });
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart --name "loadFileFromBytes"`
Expected: FAIL -- `loadFileFromBytes` is not defined on `UniversalImportNotifier`.

- [ ] **Step 3: Implement loadFileFromBytes()**

Add this method to `UniversalImportNotifier` in `lib/features/universal_import/presentation/providers/universal_import_providers.dart`, right before the `// -- Step 0: File Selection --` comment (line 71):

```dart
  // -- External File Loading (drag-and-drop / sharing intents) --

  /// Load a file from raw bytes, bypassing the file picker.
  ///
  /// Used by drag-and-drop on desktop and file sharing intents on mobile.
  /// Runs format detection and sets wizard state to [ImportWizardStep.sourceConfirmation].
  /// Returns the [DetectionResult] so callers can check for unsupported formats
  /// before navigating. Detection runs once inside this method -- callers do
  /// not need to run [FormatDetector] separately.
  Future<DetectionResult> loadFileFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentStep: ImportWizardStep.fileSelection,
    );

    try {
      const detector = FormatDetector();
      var detection = detector.detect(bytes);

      if (detection.format == ImportFormat.sqlite) {
        final isShearwater = await ShearwaterDbReader.isShearwaterCloudDb(
          bytes,
        );
        if (isShearwater) {
          detection = const DetectionResult(
            format: ImportFormat.shearwaterDb,
            sourceApp: SourceApp.shearwater,
            confidence: 0.95,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        fileBytes: bytes,
        fileName: fileName,
        detectionResult: detection,
        currentStep: ImportWizardStep.sourceConfirmation,
      );

      return detection;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load file: $e',
      );
      return const DetectionResult(
        format: ImportFormat.unknown,
        confidence: 0.0,
        warnings: ['Failed to detect file format'],
      );
    }
  }

```

Note: this requires adding `import 'dart:typed_data';` at the top of the file if not already present. Check first -- the file already imports `dart:io` which includes `Uint8List` via `dart:typed_data`, but the method signature uses `Uint8List` directly so the import should already be available.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart --name "loadFileFromBytes"`
Expected: All 6 tests PASS.

- [ ] **Step 5: Run full notifier test suite to check for regressions**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`
Expected: All existing tests still PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/universal_import/presentation/providers/universal_import_providers.dart test/features/universal_import/presentation/providers/universal_import_notifier_test.dart
git commit -m "feat: add loadFileFromBytes() to UniversalImportNotifier

Mirrors pickFile() logic but accepts raw bytes instead of using
FilePicker. Used by drag-and-drop and file sharing intents."
```

---

### Task 4: Create GlobalDropTarget widget with frosted glass overlay

**Files:**
- Create: `lib/shared/widgets/global_drop_target.dart`

- [ ] **Step 1: Create the GlobalDropTarget widget**

Create `lib/shared/widgets/global_drop_target.dart`:

```dart
import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wraps content with a desktop drag-and-drop target that navigates to the
/// import wizard when a supported file is dropped.
///
/// On non-desktop platforms, this widget passes through [child] unchanged.
/// Shows a frosted glass overlay when a file is dragged over the app.
class GlobalDropTarget extends ConsumerStatefulWidget {
  const GlobalDropTarget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalDropTarget> createState() => _GlobalDropTargetState();
}

class _GlobalDropTargetState extends ConsumerState<GlobalDropTarget> {
  bool _isDragging = false;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleDrop(details),
      child: Stack(
        children: [
          widget.child,
          if (_isDragging) const _FrostedDropOverlay(),
        ],
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    if (details.files.isEmpty) return;

    // Check if wizard is already active
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/transfer/import-wizard')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dropTarget_error_wizardActive),
          ),
        );
      }
      return;
    }

    // Read the first file only
    final xFile = details.files.first;
    final Uint8List bytes;
    try {
      bytes = await xFile.readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dropTarget_error_readFailed)),
        );
      }
      return;
    }

    // Load into the notifier (runs format detection internally)
    final notifier = ref.read(universalImportNotifierProvider.notifier);
    notifier.reset();
    final detection = await notifier.loadFileFromBytes(bytes, xFile.name);

    if (!mounted) return;

    // Check for unsupported format
    if (detection.format == ImportFormat.unknown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dropTarget_error_unsupportedFile),
        ),
      );
      return;
    }

    // Navigate to the import wizard
    context.go('/transfer/import-wizard');
  }
}

/// Frosted glass overlay shown when a file is dragged over the app.
class _FrostedDropOverlay extends StatelessWidget {
  const _FrostedDropOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Positioned.fill(
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: const Color(0xBF0A1628),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x9964B4FF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      size: 40,
                      color: Color(0xCC64B4FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.dropTarget_title,
                    style: const TextStyle(
                      color: Color(0xE664B4FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dropTarget_subtitle,
                    style: const TextStyle(
                      color: Color(0x99B4C8E6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `flutter analyze lib/shared/widgets/global_drop_target.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/shared/widgets/global_drop_target.dart
git commit -m "feat: create GlobalDropTarget widget with frosted glass overlay

Desktop-only DropTarget that shows a frosted blur overlay when files are
dragged over the app. Validates format via FormatDetector before
navigating to the import wizard."
```

---

### Task 5: Integrate GlobalDropTarget into MainScaffold

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart`

- [ ] **Step 1: Add import for GlobalDropTarget**

Add this import to the top of `lib/shared/widgets/main_scaffold.dart`:

```dart
import 'package:submersion/shared/widgets/global_drop_target.dart';
```

- [ ] **Step 2: Wrap the desktop layout Scaffold body with GlobalDropTarget**

In `lib/shared/widgets/main_scaffold.dart`, in the `build` method, find the desktop layout `Scaffold` (line 280). Wrap its `body` content with `GlobalDropTarget`. Change:

```dart
      return Scaffold(
        body: SafeArea(
          child: Row(
```

To:

```dart
      return Scaffold(
        body: GlobalDropTarget(
          child: SafeArea(
            child: Row(
```

And add the matching closing parenthesis. Find the closing of `SafeArea` (after `const VerticalDivider...` and `Expanded(child: Column(...))`). The structure is:

Before (lines 280-402):
```dart
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              // ... NavigationRail ...
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    const UpdateBanner(),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
```

After:
```dart
      return Scaffold(
        body: GlobalDropTarget(
          child: SafeArea(
            child: Row(
              children: [
                // ... NavigationRail ...
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const UpdateBanner(),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
```

- [ ] **Step 3: Wrap the mobile layout Scaffold body with GlobalDropTarget**

In the mobile layout section (line 406), change:

```dart
    return Scaffold(
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(child: widget.child),
        ],
      ),
```

To:

```dart
    return Scaffold(
      body: GlobalDropTarget(
        child: Column(
          children: [
            const UpdateBanner(),
            Expanded(child: widget.child),
          ],
        ),
      ),
```

Note: `GlobalDropTarget` already checks `Platform.isDesktop` internally and passes through on mobile, but wrapping both layouts ensures the widget tree is consistent and the mobile code path is ready for when `FileShareHandler` navigation shares the same `ScaffoldMessenger` context.

- [ ] **Step 4: Verify the file compiles**

Run: `flutter analyze lib/shared/widgets/main_scaffold.dart`
Expected: No issues found.

- [ ] **Step 5: Run dart format**

Run: `dart format lib/shared/widgets/main_scaffold.dart lib/shared/widgets/global_drop_target.dart`
Expected: No formatting changes (or formatting applied cleanly).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/main_scaffold.dart
git commit -m "feat: integrate GlobalDropTarget into MainScaffold

Wraps both desktop and mobile scaffold bodies so drag-and-drop
is active on all screens."
```

---

### Task 6: iOS platform config

**Files:**
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Add SML document type to CFBundleDocumentTypes**

In `ios/Runner/Info.plist`, find the `CFBundleDocumentTypes` array (line 12). Add a new dict entry after the existing Garmin FIT entry (after line 49):

```xml
		<dict>
			<key>CFBundleTypeName</key>
			<string>Suunto SML File</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.suunto.sml</string>
			</array>
		</dict>
		<dict>
			<key>CFBundleTypeName</key>
			<string>SQLite Database</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.database</string>
			</array>
		</dict>
```

- [ ] **Step 2: Add SML UTI to UTImportedTypeDeclarations**

In `ios/Runner/Info.plist`, find the `UTImportedTypeDeclarations` array (line 136). Add a new dict entry after the existing Garmin FIT entry:

```xml
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.xml</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Suunto SML Dive Log</string>
			<key>UTTypeIdentifier</key>
			<string>com.suunto.sml</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>sml</string>
				</array>
			</dict>
		</dict>
```

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "feat(ios): add SML and SQLite document type declarations

Registers Submersion as a handler for Suunto SML and SQLite database
files so they appear in the iOS share sheet and 'Open with' menu."
```

---

### Task 7: Android platform config

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add intent filters for file sharing and opening**

In `android/app/src/main/AndroidManifest.xml`, find the `<activity>` element's existing `<intent-filter>` for `MAIN`/`LAUNCHER` (line 48-51). Add two new intent filters after that closing `</intent-filter>` tag (after line 51):

```xml
            <!-- Handle files shared via the Share sheet -->
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="*/*"/>
            </intent-filter>
            <!-- Handle "Open with" for dive log files -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="content"/>
                <data android:scheme="file"/>
                <data android:mimeType="*/*"/>
            </intent-filter>
```

Note: We use `*/*` for mimeType because dive log files (.uddf, .fit, .sml) don't have standardized MIME types and Android file managers often send `application/octet-stream`. The actual format validation happens in-app via `FormatDetector`.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): add intent filters for file sharing and opening

Registers Submersion to receive shared files and handle 'Open with'
actions for dive log files."
```

---

### Task 8: Create FileShareHandler service

**Files:**
- Create: `lib/shared/services/file_share_handler.dart`

- [ ] **Step 1: Create the FileShareHandler class**

Create `lib/shared/services/file_share_handler.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Listens for files shared to the app via the OS share sheet (mobile only).
///
/// Call [initialize] once at app startup, and [dispose] when done.
/// On non-mobile platforms, [initialize] is a no-op.
class FileShareHandler {
  FileShareHandler({required this.onFileReceived});

  /// Called when a file is shared to the app.
  /// Receives the file bytes and the original file name.
  final Future<void> Function(Uint8List bytes, String fileName) onFileReceived;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// Start listening for shared files. Only active on iOS and Android.
  void initialize() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Handle files shared while app is running
    _subscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleMediaFiles);

    // Handle file that launched the app (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleMediaFiles);
  }

  Future<void> _handleMediaFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final sharedFile = files.first;
    final file = File(sharedFile.path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last;

    await onFileReceived(bytes, fileName);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `flutter analyze lib/shared/services/file_share_handler.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/shared/services/file_share_handler.dart
git commit -m "feat: create FileShareHandler for mobile file sharing intents

Listens for files shared via the OS share sheet on iOS/Android.
Delegates to a callback for format validation and wizard navigation."
```

---

### Task 9: Integrate FileShareHandler into app startup

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Add imports**

Add these imports to the top of `lib/app.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/services/file_share_handler.dart';
```

- [ ] **Step 2: Add scaffoldMessengerKey and FileShareHandler fields**

In `_SubmersionAppState`, add these fields after the class declaration (line 58):

```dart
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final FileShareHandler _fileShareHandler;
```

- [ ] **Step 3: Initialize FileShareHandler in initState**

Replace the existing `initState` method (lines 61-68) with:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerUpdateMenuChannel(ref);
    _fileShareHandler = FileShareHandler(
      onFileReceived: _handleIncomingFile,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeSyncOnLaunch();
      _fileShareHandler.initialize();
    });
  }
```

- [ ] **Step 4: Dispose FileShareHandler**

Replace the existing `dispose` method (lines 71-74) with:

```dart
  @override
  void dispose() {
    _fileShareHandler.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
```

- [ ] **Step 5: Add the _handleIncomingFile method**

Add this method to `_SubmersionAppState`, after the `_maybeSyncOnResume` method (after line 93):

```dart
  Future<void> _handleIncomingFile(Uint8List bytes, String fileName) async {
    final router = ref.read(appRouterProvider);
    final location =
        router.routeInformationProvider.value.uri.path;

    if (location.startsWith('/transfer/import-wizard')) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Finish current import first')),
      );
      return;
    }

    final notifier = ref.read(universalImportNotifierProvider.notifier);
    notifier.reset();
    final detection = await notifier.loadFileFromBytes(bytes, fileName);

    if (detection.format == ImportFormat.unknown) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Unsupported file type')),
      );
      return;
    }

    router.go('/transfer/import-wizard');
  }
```

Note: The snackbar messages here use hardcoded English strings rather than l10n because `_SubmersionAppState` does not have a `BuildContext` with l10n available outside of `build()`. This is acceptable for a non-widget service callback. If localized messages are needed later, the `scaffoldMessengerKey.currentContext` can be used to access l10n.

- [ ] **Step 6: Add scaffoldMessengerKey to MaterialApp.router**

In the `build` method (line 110), add `scaffoldMessengerKey` to the `MaterialApp.router` constructor:

Change:

```dart
    return MaterialApp.router(
      title: 'Submersion',
```

To:

```dart
    return MaterialApp.router(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Submersion',
```

- [ ] **Step 7: Verify the file compiles**

Run: `flutter analyze lib/app.dart`
Expected: No issues found.

- [ ] **Step 8: Run dart format on all modified files**

Run: `dart format lib/app.dart lib/shared/services/file_share_handler.dart lib/shared/widgets/global_drop_target.dart lib/shared/widgets/main_scaffold.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart`
Expected: All files formatted (0 changed or cleanly formatted).

- [ ] **Step 9: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 10: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 11: Commit**

```bash
git add lib/app.dart
git commit -m "feat: integrate FileShareHandler into app startup

Initializes mobile file sharing listener in SubmersionApp.
Adds scaffoldMessengerKey for snackbar display from non-widget code.
Shared files are validated and routed to the import wizard."
```
