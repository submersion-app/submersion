# Media Capture-Time Offset and Unmatched Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver see why a picked file matched no dive, correct a constant camera-clock offset with live re-matching, and link any file to a dive regardless of its timestamp.

**Architecture:** Three additive layers. The domain layer gains timestamp provenance (`TakenAtSource`), a per-file failure reason (`UnmatchedDiagnostic`), and an `offset` parameter on `DivePhotoMatcher.match`. The state layer gains a session-scoped `captureTimeOffset` that is applied both when matching and when writing `taken_at`. The presentation layer gains an offset bar, a diagnostic subtitle, and a dive-picker escape hatch. No database schema change.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` + `FutureProvider`), Equatable value objects, Drift (untouched here), `flutter gen-l10n` with checked-in generated ARB output.

**Spec:** `docs/superpowers/specs/2026-08-26-media-capture-time-offset-design.md`

## Global Constraints

- Working tree is the worktree `.claude/worktrees/media-capture-time-offset` on branch `worktree-media-capture-time-offset`. All paths below are relative to it. Never edit the main checkout at `/Users/ericgriffin/repos/submersion-app/submersion/lib/...`.
- **No em-dashes (U+2014) in any output**: code, comments, commit messages, ARB strings, docs. En-dashes as prose punctuation and " - " as prose punctuation are equally forbidden. Hyphens in compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **TDD**: every behavior gets a failing test before the implementation.
- **Immutability**: never mutate an existing list or map in place; build a new one.
- **No schema change.** This work claims no schema version. If you find yourself editing `lib/core/database/`, stop: you have gone outside the plan.
- File size target 200-400 lines, 800 max.
- Run `dart format .` from the worktree root after every task before committing.
- Provider naming: `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state.
- Import grouping: dart, flutter, packages, local.
- Commit messages must not contain a `Co-Authored-By` line or a Claude Code session URL.

---

## File Structure

**Create:**

| Path | Responsibility |
| --- | --- |
| `lib/features/media/domain/value_objects/taken_at_source.dart` | Enum naming which cascade tier produced a `takenAt`. |
| `lib/features/media/domain/value_objects/unmatched_diagnostic.dart` | Enum + value object describing why one file matched no dive. |
| `lib/features/media/presentation/widgets/capture_time_offset_bar.dart` | The offset stepper row, plus `formatSignedOffset`. |

**Modify:**

| Path | Change |
| --- | --- |
| `lib/features/media/domain/value_objects/media_source_metadata.dart` | Add `takenAtSource`. |
| `lib/features/media/data/services/exif_extractor.dart` | Tag each cascade tier. |
| `lib/features/media/domain/value_objects/matched_selection.dart` | Add `diagnostics` + `copyWith`. |
| `lib/features/media/domain/services/dive_photo_matcher.dart` | Add `offset`; emit diagnostics. |
| `lib/features/media/presentation/providers/files_tab_providers.dart` | `diveBoundsProvider`, `captureTimeOffset`, offset-aware persist, diagnostic-preserving mutators. |
| `lib/features/media/presentation/widgets/files_tab.dart` | Use `diveBoundsProvider`; localize. |
| `lib/features/media/presentation/widgets/file_review_pane.dart` | Host the offset bar; localize. |
| `lib/features/media/presentation/widgets/file_review_card.dart` | Diagnostic subtitle, escape hatch, localize. |
| `lib/l10n/arb/app_en.arb` + 10 locale ARBs + regenerated `app_localizations*.dart` | New keys. |

---

## Task 1: Timestamp provenance

**Files:**
- Create: `lib/features/media/domain/value_objects/taken_at_source.dart`
- Modify: `lib/features/media/domain/value_objects/media_source_metadata.dart`
- Modify: `lib/features/media/data/services/exif_extractor.dart`
- Test: `test/features/media/data/services/exif_extractor_test.dart`

**Interfaces:**
- Produces: `enum TakenAtSource { nativeExif, containerMetadata, fileModifiedTime, none }`; `MediaSourceMetadata.takenAtSource` (non-null, defaults to `TakenAtSource.none`).

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/data/services/exif_extractor_test.dart`, inside `main()`:

```dart
  group('takenAtSource provenance', () {
    test('reports fileModifiedTime when nothing else can date the file', () async {
      final dir = await Directory.systemTemp.createTemp('exif_source_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/undated.png')
        ..writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);

      final meta = await ExifExtractor().extract(file);

      expect(meta, isNotNull);
      expect(meta!.takenAtSource, TakenAtSource.fileModifiedTime);
      expect(meta.takenAt, isNotNull);
    });

    test('reports containerMetadata when the pure-Dart reader dates a JPEG', () async {
      final dir = await Directory.systemTemp.createTemp('exif_source_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/dated.jpg')
        ..writeAsBytesSync(_jpegWithDateTimeOriginal(DateTime.utc(2025, 12, 27, 11, 47)));

      final meta = await ExifExtractor().extract(file);

      expect(meta!.takenAtSource, TakenAtSource.containerMetadata);
      expect(meta.takenAt, DateTime.utc(2025, 12, 27, 11, 47));
    });
  });
```

Reuse the existing helper in that file that builds a JPEG carrying an EXIF `DateTimeOriginal`. The file already has a "pure-Dart image fallback" group around line 271; read it first and call whatever helper it uses instead of `_jpegWithDateTimeOriginal` if the name differs. Add the import `package:submersion/features/media/domain/value_objects/taken_at_source.dart`.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/data/services/exif_extractor_test.dart --plain-name "takenAtSource provenance"
```

Expected: FAIL. Compile error, `TakenAtSource` is not defined.

- [ ] **Step 3: Create the enum**

`lib/features/media/domain/value_objects/taken_at_source.dart`:

```dart
/// Which tier of [ExifExtractor]'s cascade produced a [MediaSourceMetadata.takenAt].
///
/// Surfaced on the Files-tab review card so a diver can tell a real capture
/// time from a filesystem timestamp before deciding whether a failed dive
/// match is the app's fault or the file's.
enum TakenAtSource {
  /// `native_exif` read DateTimeOriginal. iOS and Android only.
  nativeExif,

  /// The pure-Dart reader parsed JPEG EXIF or an MP4/MOV `mvhd` box.
  containerMetadata,

  /// Nothing could date the file, so its modification time was used. This is
  /// the copy-to-disk time for most transfer routes and rarely lands inside a
  /// dive window.
  fileModifiedTime,

  /// No timestamp at all. Only reachable if the file vanished mid-read.
  none,
}
```

- [ ] **Step 4: Add the field to MediaSourceMetadata**

In `lib/features/media/domain/value_objects/media_source_metadata.dart`, add the import, the field, the constructor parameter with its default, and the props entry:

```dart
  final TakenAtSource takenAtSource;
```

```dart
    this.takenAtSource = TakenAtSource.none,
```

```dart
    takenAtSource,
```

The default keeps every existing construction site compiling unchanged.

- [ ] **Step 5: Tag the cascade in ExifExtractor**

In `lib/features/media/data/services/exif_extractor.dart`, inside `_extract`, declare the source alongside `takenAt`:

```dart
  DateTime? takenAt;
  var takenAtSource = TakenAtSource.none;
```

In the `native_exif` block, immediately after `takenAt = parseExifDateTimeOriginal(...)`:

```dart
      if (takenAt != null) takenAtSource = TakenAtSource.nativeExif;
```

Replace the pure-Dart fallback line with an explicit branch so the tier is recorded:

```dart
  if (takenAt == null) {
    takenAt = readLocalCaptureTime(file, mime);
    if (takenAt != null) takenAtSource = TakenAtSource.containerMetadata;
  }
```

And in the return, record the mtime tier:

```dart
  return MediaSourceMetadata(
    takenAt: takenAt ?? mtime,
    takenAtSource: takenAt == null
        ? TakenAtSource.fileModifiedTime
        : takenAtSource,
    ...
  );
```

Add the import for `taken_at_source.dart`. Update the class doc comment's cascade description to mention that each tier is now recorded.

- [ ] **Step 6: Run the whole extractor test file**

```bash
flutter test test/features/media/data/services/exif_extractor_test.dart
```

Expected: PASS, including every pre-existing test.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/media/domain/value_objects/taken_at_source.dart \
        lib/features/media/domain/value_objects/media_source_metadata.dart \
        lib/features/media/data/services/exif_extractor.dart \
        test/features/media/data/services/exif_extractor_test.dart
git commit -m "feat(media): record which cascade tier produced a capture time"
```

---

## Task 2: Unmatched diagnostic value object

**Files:**
- Create: `lib/features/media/domain/value_objects/unmatched_diagnostic.dart`
- Modify: `lib/features/media/domain/value_objects/matched_selection.dart`
- Test: `test/features/media/domain/value_objects/matched_selection_test.dart` (create)

**Interfaces:**
- Produces: `enum UnmatchedReason { noTimestamp, outsideAllWindows }`; `UnmatchedDiagnostic({required reason, nearestDiveId, gapToNearest})`; `MatchedSelection.diagnostics` (`Map<String, UnmatchedDiagnostic>`, keyed by `ExtractedFile.sourcePath`, defaults to `const {}`); `MatchedSelection.copyWith({matched, unmatched, diagnostics})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/matched_selection_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

void main() {
  test('diagnostics default to empty', () {
    final selection = MatchedSelection(matched: const {}, unmatched: [_ef('/a.jpg')]);
    expect(selection.diagnostics, isEmpty);
  });

  test('copyWith preserves diagnostics when only buckets change', () {
    const diagnostic = UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp);
    final selection = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {'/a.jpg': diagnostic},
    );

    final moved = selection.copyWith(
      matched: {
        'dive-1': [_ef('/a.jpg')],
      },
      unmatched: const [],
    );

    expect(moved.diagnostics, {'/a.jpg': diagnostic});
    expect(moved.unmatched, isEmpty);
  });

  test('diagnostics participate in equality', () {
    final a = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {
        '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
      },
    );
    final b = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {
        '/a.jpg': UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(hours: 5),
        ),
      },
    );
    expect(a, isNot(b));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/domain/value_objects/matched_selection_test.dart
```

Expected: FAIL. `unmatched_diagnostic.dart` does not exist.

- [ ] **Step 3: Create the value object**

`lib/features/media/domain/value_objects/unmatched_diagnostic.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Why one file matched no dive.
enum UnmatchedReason {
  /// No capture time could be read at all, so the matcher had nothing to
  /// compare. Shifting capture times cannot rescue these.
  noTimestamp,

  /// A capture time exists but falls outside every dive's match window. A
  /// constant offset correction may rescue these.
  outsideAllWindows,
}

/// The matcher's explanation for a single unmatched file.
///
/// Produced by [DivePhotoMatcher.match] and carried on
/// [MatchedSelection.diagnostics], keyed by [ExtractedFile.sourcePath].
class UnmatchedDiagnostic extends Equatable {
  final UnmatchedReason reason;

  /// The dive whose match window this file came closest to. Null when
  /// [reason] is [UnmatchedReason.noTimestamp], and when there are no dives.
  final String? nearestDiveId;

  /// Signed distance from the file's capture time to the nearest dive's match
  /// window: negative when the file is before the window, positive when after.
  /// Shifting capture times by the negation of this value brings the file to
  /// the window edge.
  final Duration? gapToNearest;

  const UnmatchedDiagnostic({
    required this.reason,
    this.nearestDiveId,
    this.gapToNearest,
  });

  @override
  List<Object?> get props => [reason, nearestDiveId, gapToNearest];
}
```

- [ ] **Step 4: Extend MatchedSelection**

Rewrite `lib/features/media/domain/value_objects/matched_selection.dart` to add the field, the default, `copyWith`, and the props entry. Keep the existing `totalFiles` and `diveCount` getters untouched:

```dart
  /// Why each unmatched file failed, keyed by [ExtractedFile.sourcePath].
  ///
  /// Optional and empty by default so callers that build a selection by hand
  /// (the Files tab's manual-assignment branches, TripMediaScanner's merge)
  /// keep compiling. Entries for files that later move into a dive group are
  /// left in place and simply go unread: the review card only consults a
  /// diagnostic for a file sitting in [unmatched].
  final Map<String, UnmatchedDiagnostic> diagnostics;

  const MatchedSelection({
    required this.matched,
    required this.unmatched,
    this.diagnostics = const {},
  });

  MatchedSelection copyWith({
    Map<String, List<ExtractedFile>>? matched,
    List<ExtractedFile>? unmatched,
    Map<String, UnmatchedDiagnostic>? diagnostics,
  }) => MatchedSelection(
    matched: matched ?? this.matched,
    unmatched: unmatched ?? this.unmatched,
    diagnostics: diagnostics ?? this.diagnostics,
  );
```

Add `diagnostics` to `props` and import `unmatched_diagnostic.dart`.

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/media/domain/value_objects/matched_selection_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/media/domain/value_objects/unmatched_diagnostic.dart \
        lib/features/media/domain/value_objects/matched_selection.dart \
        test/features/media/domain/value_objects/matched_selection_test.dart
git commit -m "feat(media): add per-file unmatched diagnostics to MatchedSelection"
```

---

## Task 3: Matcher offset and diagnostics

**Files:**
- Modify: `lib/features/media/domain/services/dive_photo_matcher.dart`
- Test: `test/features/media/domain/services/dive_photo_matcher_test.dart`

**Interfaces:**
- Consumes: `UnmatchedDiagnostic`, `UnmatchedReason`, `MatchedSelection.diagnostics` from Task 2.
- Produces: `DivePhotoMatcher.match({required List<ExtractedFile> files, required List<DiveBounds> dives, Duration offset = Duration.zero})`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/domain/services/dive_photo_matcher_test.dart` inside `main()`. Read the top of that file first and reuse its existing `_ef`-style helper for building an `ExtractedFile` with a given `takenAt`; the helper below assumes one named `_file(path, takenAt)`:

```dart
  group('capture-time offset', () {
    final dive = DiveBounds(
      diveId: 'dive-1',
      entryTime: DateTime.utc(2025, 12, 27, 11, 26),
      exitTime: DateTime.utc(2025, 12, 27, 12, 9),
    );

    test('zero offset matches exactly as before', () {
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = const DivePhotoMatcher().match(files: [file], dives: [dive]);
      expect(result.matched['dive-1'], [file]);
    });

    test('a negative offset pulls a too-late file into the window', () {
      // Camera clock five hours fast: 16:47 recorded for an 11:47 photo.
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));

      final before = const DivePhotoMatcher().match(files: [file], dives: [dive]);
      expect(before.unmatched, [file]);

      final after = const DivePhotoMatcher().match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: -5),
      );
      expect(after.matched['dive-1'], [file]);
      expect(after.unmatched, isEmpty);
    });

    test('a positive offset pushes a too-early file into the window', () {
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 6, 47));
      final result = const DivePhotoMatcher().match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: 5),
      );
      expect(result.matched['dive-1'], [file]);
    });
  });

  group('unmatched diagnostics', () {
    final dive = DiveBounds(
      diveId: 'dive-1',
      entryTime: DateTime.utc(2025, 12, 27, 11, 26),
      exitTime: DateTime.utc(2025, 12, 27, 12, 9),
    );

    test('a file with no capture time reports noTimestamp', () {
      final file = _file('/a.jpg', null);
      final result = const DivePhotoMatcher().match(files: [file], dives: [dive]);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.noTimestamp);
      expect(diagnostic.nearestDiveId, isNull);
      expect(diagnostic.gapToNearest, isNull);
    });

    test('a late file reports a positive gap past the post-buffer', () {
      // Window ends at exit 12:09 + 60 min post-buffer = 13:09.
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
      final result = const DivePhotoMatcher().match(files: [file], dives: [dive]);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.outsideAllWindows);
      expect(diagnostic.nearestDiveId, 'dive-1');
      expect(diagnostic.gapToNearest, const Duration(hours: 3, minutes: 38));
    });

    test('an early file reports a negative gap before the pre-buffer', () {
      // Window starts at entry 11:26 - 30 min pre-buffer = 10:56.
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 9, 56));
      final result = const DivePhotoMatcher().match(files: [file], dives: [dive]);

      expect(result.diagnostics['/a.jpg']!.gapToNearest, const Duration(hours: -1));
    });

    test('the nearest dive wins among several', () {
      final later = DiveBounds(
        diveId: 'dive-2',
        entryTime: DateTime.utc(2025, 12, 27, 15, 0),
        exitTime: DateTime.utc(2025, 12, 27, 15, 40),
      );
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 18, 0));

      final result = const DivePhotoMatcher().match(
        files: [file],
        dives: [dive, later],
      );

      expect(result.diagnostics['/a.jpg']!.nearestDiveId, 'dive-2');
    });

    test('the gap is measured after the offset is applied', () {
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
      final result = const DivePhotoMatcher().match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: -1),
      );
      expect(result.diagnostics['/a.jpg']!.gapToNearest, const Duration(hours: 2, minutes: 38));
    });

    test('matched files get no diagnostic entry', () {
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = const DivePhotoMatcher().match(files: [file], dives: [dive]);
      expect(result.diagnostics, isEmpty);
    });

    test('no dives at all still reports outsideAllWindows with no nearest', () {
      final file = _file('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = const DivePhotoMatcher().match(files: [file], dives: const []);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.outsideAllWindows);
      expect(diagnostic.nearestDiveId, isNull);
    });
  });
```

Add the import for `unmatched_diagnostic.dart`.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/domain/services/dive_photo_matcher_test.dart
```

Expected: FAIL. `match` has no `offset` named parameter.

- [ ] **Step 3: Implement offset and diagnostics**

In `lib/features/media/domain/services/dive_photo_matcher.dart`, replace the body of `match`:

```dart
  /// Routes [files] to [dives] by capture date.
  ///
  /// [offset] is added to each file's `takenAt` before comparison and is not
  /// written back to the file: the caller owns applying the same offset when
  /// persisting, so a shift-rescued photo enriches against the same corrected
  /// time it matched on.
  MatchedSelection match({
    required List<ExtractedFile> files,
    required List<DiveBounds> dives,
    Duration offset = Duration.zero,
  }) {
    final matched = <String, List<ExtractedFile>>{};
    final unmatched = <ExtractedFile>[];
    final diagnostics = <String, UnmatchedDiagnostic>{};

    for (final file in files) {
      final rawTakenAt = file.metadata.takenAt;
      if (rawTakenAt == null) {
        unmatched.add(file);
        diagnostics[file.sourcePath] = const UnmatchedDiagnostic(
          reason: UnmatchedReason.noTimestamp,
        );
        continue;
      }
      final takenAt = rawTakenAt.add(offset);

      DiveBounds? best;
      Duration? bestDelta;
      for (final dive in dives) {
        final windowStart = dive.entryTime.subtract(preBuffer);
        final windowEnd = dive.exitTime.add(postBuffer);
        if (takenAt.isBefore(windowStart) || takenAt.isAfter(windowEnd)) {
          continue;
        }
        final delta = takenAt.difference(dive.entryTime).abs();
        if (best == null || delta < bestDelta!) {
          best = dive;
          bestDelta = delta;
        }
      }

      if (best == null) {
        unmatched.add(file);
        diagnostics[file.sourcePath] = _outsideDiagnostic(takenAt, dives);
      } else {
        matched.putIfAbsent(best.diveId, () => []).add(file);
      }
    }

    return MatchedSelection(
      matched: matched,
      unmatched: unmatched,
      diagnostics: diagnostics,
    );
  }

  /// Finds the dive whose match window [takenAt] came closest to, measuring to
  /// the window edge rather than to entry time so the reported gap is the
  /// amount of shift that would actually bring the file into range.
  static UnmatchedDiagnostic _outsideDiagnostic(
    DateTime takenAt,
    List<DiveBounds> dives,
  ) {
    String? nearestDiveId;
    Duration? nearestGap;
    for (final dive in dives) {
      final windowStart = dive.entryTime.subtract(preBuffer);
      final windowEnd = dive.exitTime.add(postBuffer);
      final gap = takenAt.isBefore(windowStart)
          ? takenAt.difference(windowStart)
          : takenAt.difference(windowEnd);
      if (nearestGap == null || gap.abs() < nearestGap.abs()) {
        nearestGap = gap;
        nearestDiveId = dive.diveId;
      }
    }
    return UnmatchedDiagnostic(
      reason: UnmatchedReason.outsideAllWindows,
      nearestDiveId: nearestDiveId,
      gapToNearest: nearestGap,
    );
  }
```

Add the import for `unmatched_diagnostic.dart`. Update the class doc to mention the offset and diagnostics.

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/domain/services/dive_photo_matcher_test.dart
```

Expected: PASS, all pre-existing tests included.

- [ ] **Step 5: Verify the gallery path still compiles and passes**

`TripMediaScanner` calls `match` positionally-free and merges selections; the new parameter is optional so it is source-compatible.

```bash
flutter test test/features/media/data/services/trip_media_scanner_test.dart \
             test/features/media/data/services/trip_media_scanner_boundary_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/media/domain/services/dive_photo_matcher.dart \
        test/features/media/domain/services/dive_photo_matcher_test.dart
git commit -m "feat(media): add a capture-time offset and failure reasons to DivePhotoMatcher"
```

---

## Task 4: Extract diveBoundsProvider

**Files:**
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart`
- Modify: `lib/features/media/presentation/widgets/files_tab.dart:187-205`
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`

**Interfaces:**
- Produces: `final diveBoundsProvider = FutureProvider<List<DiveBounds>>(...)`.

The offset bar has to re-run the matcher without an OS picker round-trip, and today the `DiveBounds` derivation is inlined in a `coverage:ignore` block reachable only through `FilePicker`. Extracting it makes it both reusable and testable for the first time.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/presentation/providers/files_tab_providers_test.dart` inside `main()`:

```dart
  group('diveBoundsProvider', () {
    test('uses the dive exit time when present', () async {
      final dive = Dive(
        id: 'dive-1',
        diveDateTime: DateTime.utc(2025, 12, 27, 11, 26),
        exitTime: DateTime.utc(2025, 12, 27, 12, 9),
      );
      final container = ProviderContainer(
        overrides: [divesProvider.overrideWith((ref) async => [dive])],
      );
      addTearDown(container.dispose);

      final bounds = await container.read(diveBoundsProvider.future);

      expect(bounds.single.diveId, 'dive-1');
      expect(bounds.single.entryTime, dive.effectiveEntryTime);
      expect(bounds.single.exitTime, DateTime.utc(2025, 12, 27, 12, 9));
    });

    test('falls back to entry plus one hour when there is no exit or runtime', () async {
      final dive = Dive(
        id: 'dive-2',
        diveDateTime: DateTime.utc(2025, 12, 27, 11, 26),
      );
      final container = ProviderContainer(
        overrides: [divesProvider.overrideWith((ref) async => [dive])],
      );
      addTearDown(container.dispose);

      final bounds = await container.read(diveBoundsProvider.future);

      expect(
        bounds.single.exitTime,
        dive.effectiveEntryTime.add(const Duration(hours: 1)),
      );
    });
  });
```

Construct `Dive` with whatever required parameters the entity actually declares; read `lib/features/dive_log/domain/entities/dive.dart` and mirror how the existing tests in `test/features/media/data/services/trip_media_scanner_test.dart` build one. Add imports for `dive.dart`, `dive_providers.dart`, and `dive_photo_matcher.dart`.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart --plain-name "diveBoundsProvider"
```

Expected: FAIL. `diveBoundsProvider` is not defined.

- [ ] **Step 3: Add the provider**

At the bottom of `lib/features/media/presentation/providers/files_tab_providers.dart`, next to `filesTabNotifierProvider`:

```dart
/// The dive time windows the Files tab matches picked media against.
///
/// Kept separate from [filesTabNotifierProvider] so the review pane can re-run
/// [DivePhotoMatcher] with a new capture-time offset without sending the user
/// back through the OS file picker.
///
/// A dive with no recorded exit time gets one synthesised from its runtime,
/// and a dive with neither gets a one-hour window. That is deliberately
/// generous: [DivePhotoMatcher] adds a 30-minute pre-buffer and a 60-minute
/// post-buffer on top, and a window that is slightly too wide costs a
/// correctable mis-assignment, while one that is too narrow silently drops
/// photos into the unmatched bucket.
final diveBoundsProvider = FutureProvider<List<DiveBounds>>((ref) async {
  final dives = await ref.watch(divesProvider.future);
  return [
    for (final d in dives)
      DiveBounds(
        diveId: d.id,
        entryTime: d.effectiveEntryTime,
        exitTime:
            d.exitTime ??
            d.effectiveEntryTime.add(
              d.effectiveRuntime ?? const Duration(hours: 1),
            ),
      ),
  ];
});
```

Add imports for `package:submersion/features/dive_log/presentation/providers/dive_providers.dart` and `package:submersion/features/media/domain/services/dive_photo_matcher.dart`.

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart --plain-name "diveBoundsProvider"
```

Expected: PASS.

- [ ] **Step 5: Use it from files_tab.dart**

In `_applyMatchAndStash`, replace the inlined derivation (the `final dives = await ref.read(divesProvider.future);` block through the `bounds` list literal) with:

```dart
    final bounds = await ref.read(diveBoundsProvider.future);
    final result = const DivePhotoMatcher().match(
      files: extracted,
      dives: bounds,
    );
    notifier.setFiles(extracted, match: result);
```

`state.captureTimeOffset` does not exist yet; Task 5 Step 6 adds the `offset:` argument to this same call. Remove the now-unused `dive_providers.dart` import from `files_tab.dart` if nothing else there uses it, and update the `coverage:ignore` comment above `_applyMatchAndStash` to point at `files_tab_providers_test.dart` for the bounds derivation instead of `trip_media_scanner_test.dart`.

- [ ] **Step 6: Run the files tab tests**

```bash
flutter test test/features/media/presentation/widgets/files_tab_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/media/presentation/providers/files_tab_providers.dart \
        lib/features/media/presentation/widgets/files_tab.dart \
        test/features/media/presentation/providers/files_tab_providers_test.dart
git commit -m "refactor(media): extract diveBoundsProvider so matching can be re-run"
```

---

## Task 5: Session capture-time offset in state

**Files:**
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart`
- Modify: `lib/features/media/presentation/widgets/files_tab.dart`
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`

**Interfaces:**
- Produces: `FilesTabState.captureTimeOffset` (`Duration`, defaults to `Duration.zero`); `FilesTabNotifier.setCaptureTimeOffset(Duration offset, {required MatchedSelection match})`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/presentation/providers/files_tab_providers_test.dart` inside `main()`:

```dart
  group('capture time offset', () {
    test('defaults to zero', () {
      expect(FilesTabState.initial().captureTimeOffset, Duration.zero);
    });

    test('setCaptureTimeOffset updates the offset and the match together', () {
      final notifier = _notifier();
      final rematched = MatchedSelection(
        matched: {
          'dive-1': [_ef('/a.jpg')],
        },
        unmatched: const [],
      );

      notifier.setCaptureTimeOffset(const Duration(hours: -5), match: rematched);

      expect(notifier.state.captureTimeOffset, const Duration(hours: -5));
      expect(notifier.state.match, rematched);
    });

    test('clearStagedFiles resets the offset but keeps the auto-match preference', () {
      final notifier = _notifier();
      notifier.toggleAutoMatch();
      notifier.setCaptureTimeOffset(
        const Duration(hours: 5),
        match: MatchedSelection.empty(),
      );

      notifier.clearStagedFiles();

      expect(notifier.state.captureTimeOffset, Duration.zero);
      expect(notifier.state.autoMatchByDate, isFalse);
    });

    test('the diagnostics survive a manual assignment', () {
      final notifier = _notifier();
      final file = _ef('/a.jpg');
      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: const {},
          unmatched: [file],
          diagnostics: const {
            '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
          },
        ),
      );

      notifier.assignToDive('/a.jpg', 'dive-1');

      expect(notifier.state.match.diagnostics, isNotEmpty);
      expect(notifier.state.match.matched['dive-1'], [file]);
    });
  });
```

Reuse the file's existing notifier-construction helper; if it does not have one named `_notifier()`, read the top of the file and use whatever it does (the file already builds notifiers with unused-repository stubs). Same for `_ef`. Add imports for `unmatched_diagnostic.dart`.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart --plain-name "capture time offset"
```

Expected: FAIL. `captureTimeOffset` is not defined.

- [ ] **Step 3: Add the state field**

In `FilesTabState`, add the field, constructor parameter, `initial()` value, `copyWith` parameter, and props entry:

```dart
  /// A correction added to every staged file's capture time before matching
  /// and before persisting.
  ///
  /// Scoped to one picking session. Cleared by [FilesTabNotifier.clearStagedFiles]
  /// along with the files themselves: the notifier is not autoDispose, so an
  /// offset left set would silently follow the user into their next import.
  final Duration captureTimeOffset;
```

```dart
    required this.captureTimeOffset,
```

```dart
    captureTimeOffset: Duration.zero,
```

```dart
    Duration? captureTimeOffset,
```

```dart
    captureTimeOffset: captureTimeOffset ?? this.captureTimeOffset,
```

```dart
    captureTimeOffset,
```

- [ ] **Step 4: Add the notifier method and reset the offset**

Add to `FilesTabNotifier`:

```dart
  /// Applies a new capture-time [offset] together with the [match] it
  /// produced.
  ///
  /// Both move in one state update so the review pane's summary count and the
  /// rendered groups can never disagree: a caller that set the offset first
  /// and the match second would publish an intermediate state showing the new
  /// offset against the old grouping.
  void setCaptureTimeOffset(Duration offset, {required MatchedSelection match}) {
    state = state.copyWith(captureTimeOffset: offset, match: match);
  }
```

In `clearStagedFiles`, add `captureTimeOffset: Duration.zero,` to the `copyWith` call.

- [ ] **Step 5: Preserve diagnostics through the mutators**

In `removeFile`, `assignToDive`, and `assignAllUnmatched`, replace each `MatchedSelection(matched: ..., unmatched: ...)` construction with `state.match.copyWith(matched: ..., unmatched: ...)` so the diagnostics map is carried forward instead of being silently dropped.

- [ ] **Step 6: Pass the offset when matching**

In `files_tab.dart` `_applyMatchAndStash`, add the offset argument to the matcher call added in Task 4:

```dart
      offset: state.captureTimeOffset,
```

`state` is already read at the top of that method.

- [ ] **Step 7: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart
```

Expected: PASS, all pre-existing tests included.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/media/presentation/providers/files_tab_providers.dart \
        lib/features/media/presentation/widgets/files_tab.dart \
        test/features/media/presentation/providers/files_tab_providers_test.dart
git commit -m "feat(media): hold a session capture-time offset in the Files tab state"
```

---

## Task 6: Apply the offset when persisting

**Files:**
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart:363`
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`

This is the correctness core of the feature. `EnrichmentService.calculateEnrichment` derives `elapsedSeconds` from the persisted `taken_at` minus the dive start, and a negative elapsed falls into the "before first profile point" branch that returns the first profile sample's depth for every such photo. Matching on a shifted time while persisting the unshifted one would give every shift-rescued photo the same wrong near-surface depth badge.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/presentation/providers/files_tab_providers_test.dart` inside `main()`:

```dart
  group('offset is applied when persisting', () {
    test('commit writes taken_at shifted by the session offset', () async {
      final captured = <MediaItem>[];
      final notifier = _notifierCapturing(captured);
      final file = _ef(
        '/a.jpg',
        metadata: const MediaSourceMetadata(mimeType: 'image/jpeg')
            .copyWithTakenAt(DateTime.utc(2025, 12, 27, 16, 47)),
      );

      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: {
            'dive-1': [file],
          },
          unmatched: const [],
        ),
      );
      notifier.setCaptureTimeOffset(
        const Duration(hours: -5),
        match: notifier.state.match,
      );

      await notifier.commit(target: const DiveAttachTarget(diveId: 'dive-1'));

      expect(captured.single.takenAt, DateTime.utc(2025, 12, 27, 11, 47));
    });

    test('a zero offset writes the extracted time unchanged', () async {
      final captured = <MediaItem>[];
      final notifier = _notifierCapturing(captured);
      final file = _ef(
        '/a.jpg',
        metadata: const MediaSourceMetadata(mimeType: 'image/jpeg')
            .copyWithTakenAt(DateTime.utc(2025, 12, 27, 11, 47)),
      );

      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: {
            'dive-1': [file],
          },
          unmatched: const [],
        ),
      );

      await notifier.commit(target: const DiveAttachTarget(diveId: 'dive-1'));

      expect(captured.single.takenAt, DateTime.utc(2025, 12, 27, 11, 47));
    });
  });
```

`MediaSourceMetadata` has no `copyWithTakenAt`; build the metadata with the constructor instead: `MediaSourceMetadata(mimeType: 'image/jpeg', takenAt: DateTime.utc(2025, 12, 27, 16, 47))`. Use the file's existing pattern for a repository stub that records the `MediaItem` passed to `createMedia` and returns it with an id; the file already has commit tests around line 878 that do exactly this, so copy that stub rather than writing a new one, and name the helper `_notifierCapturing` or reuse theirs.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart --plain-name "offset is applied when persisting"
```

Expected: FAIL. The first test writes 16:47 instead of 11:47.

- [ ] **Step 3: Apply the offset at the write site**

In `_persistOne`, replace:

```dart
      takenAt: file.metadata.takenAt ?? now,
```

with:

```dart
      // The offset is baked into the stored value, not merely used for
      // matching. EnrichmentService derives elapsed-since-entry from this
      // column to place the photo on the profile chart and derive its depth
      // badge; persisting an unshifted time for a file that only matched
      // because of the shift would give every such photo a large negative
      // elapsed, which resolves to the first profile sample's depth.
      takenAt: file.metadata.takenAt?.add(state.captureTimeOffset) ?? now,
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/media/presentation/providers/files_tab_providers.dart \
        test/features/media/presentation/providers/files_tab_providers_test.dart
git commit -m "fix(media): persist the corrected capture time so enrichment agrees with matching"
```

---

## Task 7: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Modify (generated): `lib/l10n/arb/app_localizations.dart` and `app_localizations_<locale>.dart`
- Test: `test/l10n/arb_parity_test.dart` (existing, must stay green)

**Interfaces:**
- Produces: 28 `media_photoPicker_files_*` getters on `AppLocalizations`, consumed by Tasks 8 through 11.

This task lands every key the remaining tasks need, in one ARB change and one codegen run, so the 378-test l10n hub is regenerated once rather than four times.

**Ordering trap, read before starting:** run `flutter gen-l10n` **last**, after all ten translations are in place. Running it earlier bakes the English fallback into `app_localizations_XX.dart`, and adding the real translations afterwards updates the ARBs but not the generated Dart. Nothing catches this: `flutter analyze` is clean, the suite is green (widget tests pin `locale: const Locale('en')`), and CI's Code Generation job does not verify l10n output.

- [ ] **Step 1: Add the English keys**

Insert these into `lib/l10n/arb/app_en.arb` immediately after the existing `"media_photoPicker_thumbnailToggleSelectedLabel"` entry (around line 7177). **Do not `json.dumps` the whole file**: its compact one-line `@meta` entries explode into roughly 485 changed lines. Insert the lines textually by anchor.

```json
  "media_photoPicker_files_pickFilesButton": "Pick files…",
  "media_photoPicker_files_pickFolderButton": "Pick a folder…",
  "media_photoPicker_files_autoMatchLabel": "Auto-match photos and videos to dives by date",
  "media_photoPicker_files_emptyHint": "Pick files or a folder to start.",
  "media_photoPicker_files_linkButton": "{count, plural, =1{Link 1 item} other{Link {count} items}}",
  "@media_photoPicker_files_linkButton": {"placeholders": {"count": {"type": "num", "format": "decimalPattern"}}},
  "media_photoPicker_files_attachToSiteButton": "{count, plural, =1{Attach 1 item to this site} other{Attach {count} items to this site}}",
  "@media_photoPicker_files_attachToSiteButton": {"placeholders": {"count": {"type": "num", "format": "decimalPattern"}}},
  "media_photoPicker_files_summary": "{fileCount, plural, =1{1 file} other{{fileCount} files}}, {diveCount, plural, =1{1 dive} other{{diveCount} dives}}, {unmatchedCount} unmatched",
  "@media_photoPicker_files_summary": {"placeholders": {"fileCount": {"type": "num", "format": "decimalPattern"}, "diveCount": {"type": "num", "format": "decimalPattern"}, "unmatchedCount": {"type": "Object"}}},
  "media_photoPicker_files_itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@media_photoPicker_files_itemCount": {"placeholders": {"count": {"type": "num", "format": "decimalPattern"}}},
  "media_photoPicker_files_diveGroupTitle": "Dive {diveId}",
  "@media_photoPicker_files_diveGroupTitle": {"placeholders": {"diveId": {"type": "String"}}},
  "media_photoPicker_files_groupCount": "{count, plural, =1{1 file} other{{count} files}}",
  "@media_photoPicker_files_groupCount": {"placeholders": {"count": {"type": "num", "format": "decimalPattern"}}},
  "media_photoPicker_files_unmatchedGroupTitle": "Unmatched",
  "media_photoPicker_files_addAllToDive": "{count, plural, =1{Add 1 to this dive} other{Add all {count} to this dive}}",
  "@media_photoPicker_files_addAllToDive": {"placeholders": {"count": {"type": "num", "format": "decimalPattern"}}},
  "media_photoPicker_files_addToDiveTooltip": "Add to this dive",
  "media_photoPicker_files_chooseDiveTooltip": "Choose a dive",
  "media_photoPicker_files_removeTooltip": "Remove from selection",
  "media_photoPicker_files_sourceExif": "from EXIF",
  "media_photoPicker_files_sourceContainer": "from file metadata",
  "media_photoPicker_files_sourceFileDate": "from file date",
  "media_photoPicker_files_sourceNone": "no date found",
  "media_photoPicker_files_shiftedTime": "{shifted} (was {original})",
  "@media_photoPicker_files_shiftedTime": {"placeholders": {"shifted": {"type": "String"}, "original": {"type": "String"}}},
  "media_photoPicker_files_reasonNoTimestamp": "No capture time could be read",
  "media_photoPicker_files_reasonBeforeDive": "{gap} before the nearest dive",
  "@media_photoPicker_files_reasonBeforeDive": {"placeholders": {"gap": {"type": "String"}}},
  "media_photoPicker_files_reasonAfterDive": "{gap} after the nearest dive",
  "@media_photoPicker_files_reasonAfterDive": {"placeholders": {"gap": {"type": "String"}}},
  "media_photoPicker_files_reasonNoDives": "No dives to match against",
  "media_photoPicker_files_offsetLabel": "Shift capture times by",
  "media_photoPicker_files_offsetResetTooltip": "Reset to no shift",
  "media_photoPicker_files_offsetBackTooltip": "Shift {amount} earlier",
  "@media_photoPicker_files_offsetBackTooltip": {"placeholders": {"amount": {"type": "String"}}},
  "media_photoPicker_files_offsetForwardTooltip": "Shift {amount} later",
  "@media_photoPicker_files_offsetForwardTooltip": {"placeholders": {"amount": {"type": "String"}}},
```

- [ ] **Step 2: Prove the ARB still parses**

```bash
python3 -c "import json; json.load(open('lib/l10n/arb/app_en.arb')); print('ok')"
```

Expected: `ok`.

- [ ] **Step 3: Translate into all ten locales**

Insert the same 28 keys into each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`, with real translations. These must be genuine translations, not English copies: `flutter gen-l10n` silently emits the English value as a fallback for a missing key, and Copilot's PR review flags this per locale.

Rules:
- Insert by the same textual anchor in every file so each diff is `+N/-0`. Build each line as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`, then `json.loads` the whole file afterwards to prove it still parses.
- Never write a locale ARB back with `json.dump`. All ten carry compact one-line `@meta` entries that `json.dumps(indent=2)` re-indents, which adds an identical unrelated 13-line hunk to every one of the ten files. Read, splice the new lines in textually, write.
- Preserve every ICU placeholder and plural structure verbatim. Each locale may use its own plural categories (Arabic has six; Chinese has one).
- Locale ARBs carry `@meta` only for plural keys, so copy the `@` entries only for the six plural keys listed above and omit them for the simple placeholder keys.
- Match the terminology already used in each locale's neighbouring dive and media keys rather than inventing new nouns. Check what each file already uses for "dive", "site", and "photo" before writing. Arabic uses "ملف الغوصة" for dive profile, Chinese uses "轮廓"; look at the surrounding block, not a dictionary.
- Diacritics: parts of `app_fr.arb` and `app_hu.arb` are diacritic-stripped in some blocks and fully accented in others. Match the neighbouring keys in the same feature block; do not strip accents by default.

Worked example, German (`app_de.arb`), to establish tone:

```json
  "media_photoPicker_files_pickFilesButton": "Dateien auswählen…",
  "media_photoPicker_files_pickFolderButton": "Ordner auswählen…",
  "media_photoPicker_files_autoMatchLabel": "Fotos und Videos automatisch nach Datum den Tauchgängen zuordnen",
  "media_photoPicker_files_emptyHint": "Wähle Dateien oder einen Ordner aus, um zu beginnen.",
  "media_photoPicker_files_unmatchedGroupTitle": "Nicht zugeordnet",
  "media_photoPicker_files_addToDiveTooltip": "Zu diesem Tauchgang hinzufügen",
  "media_photoPicker_files_chooseDiveTooltip": "Tauchgang auswählen",
  "media_photoPicker_files_removeTooltip": "Aus der Auswahl entfernen",
  "media_photoPicker_files_sourceExif": "aus EXIF",
  "media_photoPicker_files_sourceContainer": "aus Dateimetadaten",
  "media_photoPicker_files_sourceFileDate": "aus Dateidatum",
  "media_photoPicker_files_sourceNone": "kein Datum gefunden",
  "media_photoPicker_files_reasonNoTimestamp": "Keine Aufnahmezeit lesbar",
  "media_photoPicker_files_reasonBeforeDive": "{gap} vor dem nächsten Tauchgang",
  "media_photoPicker_files_reasonAfterDive": "{gap} nach dem nächsten Tauchgang",
  "media_photoPicker_files_reasonNoDives": "Keine Tauchgänge zum Abgleichen",
  "media_photoPicker_files_offsetLabel": "Aufnahmezeiten verschieben um",
  "media_photoPicker_files_offsetResetTooltip": "Verschiebung zurücksetzen",
  "media_photoPicker_files_shiftedTime": "{shifted} (war {original})",
```

- [ ] **Step 4: Verify every key reached every locale**

```bash
python3 - <<'PY'
import json, glob, os
en = json.load(open('lib/l10n/arb/app_en.arb'))
new = [k for k in en if k.startswith('media_photoPicker_files_') and not k.startswith('@')]
print(len(new), 'new keys')
for path in sorted(glob.glob('lib/l10n/arb/app_*.arb')):
    if path.endswith('app_en.arb'):
        continue
    d = json.load(open(path))
    missing = [k for k in new if k not in d]
    english = [k for k in new if k in d and d[k] == en[k] and len(en[k]) > 12]
    print(os.path.basename(path), 'missing:', missing, 'still English:', english)
PY
```

Expected: `missing: []` for every locale. The "still English" list flags untranslated copies; a short token like a placeholder-only string may legitimately match, but a full sentence must not.

- [ ] **Step 5: Generate, last**

```bash
flutter gen-l10n
```

Then verify by hand that a real translation, not an English fallback, made it into the generated Dart:

```bash
grep -A1 "get media_photoPicker_files_unmatchedGroupTitle" lib/l10n/arb/app_localizations_de.dart
```

Expected: `Nicht zugeordnet`, not `Unmatched`.

- [ ] **Step 6: Run the parity guard**

```bash
flutter test test/l10n/
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n: add Files-tab review pane strings in all locales"
```

---

## Task 8: Capture-time offset bar

**Files:**
- Create: `lib/features/media/presentation/utils/capture_time_offset_format.dart`
- Create: `lib/features/media/presentation/widgets/capture_time_offset_bar.dart`
- Modify: `lib/features/media/presentation/widgets/file_review_pane.dart`
- Test: `test/features/media/presentation/utils/capture_time_offset_format_test.dart` (create)
- Test: `test/features/media/presentation/widgets/capture_time_offset_bar_test.dart` (create)

**Interfaces:**
- Consumes: `diveBoundsProvider` (Task 4), `FilesTabNotifier.setCaptureTimeOffset` (Task 5), the l10n getters (Task 7).
- Produces: `String formatSignedOffset(Duration)`, `String formatOffsetMagnitude(Duration)`, `class CaptureTimeOffsetBar extends ConsumerWidget { const CaptureTimeOffsetBar({super.key, required this.state}); final FilesTabState state; }`.

- [ ] **Step 1: Write the failing formatter test**

Create `test/features/media/presentation/utils/capture_time_offset_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';

void main() {
  group('formatSignedOffset', () {
    test('zero has no sign', () {
      expect(formatSignedOffset(Duration.zero), '0m');
    });

    test('positive whole hours pad the minutes', () {
      expect(formatSignedOffset(const Duration(hours: 5)), '+5h 00m');
    });

    test('negative offsets keep the sign on the hours', () {
      expect(formatSignedOffset(const Duration(hours: -1, minutes: -15)), '-1h 15m');
    });

    test('sub-hour offsets omit the hour part', () {
      expect(formatSignedOffset(const Duration(minutes: 45)), '+45m');
      expect(formatSignedOffset(const Duration(minutes: -15)), '-15m');
    });
  });

  group('formatOffsetMagnitude', () {
    test('drops the sign', () {
      expect(formatOffsetMagnitude(const Duration(hours: -3, minutes: -38)), '3h 38m');
      expect(formatOffsetMagnitude(const Duration(hours: 3, minutes: 38)), '3h 38m');
    });

    test('sub-hour magnitudes omit the hour part', () {
      expect(formatOffsetMagnitude(const Duration(minutes: -45)), '45m');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/utils/capture_time_offset_format_test.dart
```

Expected: FAIL, file not found.

- [ ] **Step 3: Write the formatters**

`lib/features/media/presentation/utils/capture_time_offset_format.dart`:

```dart
/// Formats a capture-time correction for display.
///
/// Deliberately locale-independent digits with bare `h` and `m` units: the
/// value is a duration knob the user is dialling, not a timestamp, and the
/// surrounding label carries the translated prose.
String formatSignedOffset(Duration offset) {
  if (offset == Duration.zero) return '0m';
  final sign = offset.isNegative ? '-' : '+';
  return '$sign${formatOffsetMagnitude(offset)}';
}

/// The absolute size of [offset], with no sign. Used where the direction is
/// already carried by the surrounding sentence.
String formatOffsetMagnitude(Duration offset) {
  final abs = offset.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/utils/capture_time_offset_format_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write the failing bar test**

Create `test/features/media/presentation/widgets/capture_time_offset_bar_test.dart`. Use `testApp` from `test/helpers/test_app.dart` so localization delegates and a `ProviderScope` are both present, and pin the locale:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/capture_time_offset_bar.dart';

import '../../../../helpers/test_app.dart';

ExtractedFile _ef(String path, DateTime takenAt) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
);

void main() {
  testWidgets('shows the current offset and re-matches on a step', (tester) async {
    final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
    final state = FilesTabState.initial().copyWith(
      files: [file],
      match: MatchedSelection(matched: const {}, unmatched: [file]),
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          divesProvider.overrideWith((ref) async => [
            Dive(
              id: 'dive-1',
              diveDateTime: DateTime.utc(2025, 12, 27, 11, 26),
              exitTime: DateTime.utc(2025, 12, 27, 12, 9),
            ),
          ]),
        ],
        child: CaptureTimeOffsetBar(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0m'), findsOneWidget);

    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureTimeOffsetBar)),
    );
    final result = container.read(filesTabNotifierProvider);
    expect(result.captureTimeOffset, const Duration(hours: -5));
    expect(result.match.matched['dive-1'], isNotNull);
  });

  testWidgets('reset returns the offset to zero', (tester) async {
    final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
    final state = FilesTabState.initial().copyWith(
      files: [file],
      match: MatchedSelection(matched: const {}, unmatched: [file]),
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          divesProvider.overrideWith((ref) async => [
            Dive(
              id: 'dive-1',
              diveDateTime: DateTime.utc(2025, 12, 27, 11, 26),
              exitTime: DateTime.utc(2025, 12, 27, 12, 9),
            ),
          ]),
        ],
        child: CaptureTimeOffsetBar(state: state),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Shift 1h 00m earlier'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reset to no shift'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CaptureTimeOffsetBar)),
    );
    expect(
      container.read(filesTabNotifierProvider).captureTimeOffset,
      Duration.zero,
    );
  });
}
```

Note that the bar rebuilds from the `state` it was constructed with, not from the provider, so both tests assert against the notifier's state rather than against on-screen text.

The widget reads the real `filesTabNotifierProvider`, whose default construction pulls a media repository. If that throws in this test environment, override `filesTabNotifierProvider` with a seeded notifier the way `file_review_card_test.dart` does with its `_SeededFilesTabNotifier`; copy that pattern rather than inventing a new one.

- [ ] **Step 6: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/capture_time_offset_bar_test.dart
```

Expected: FAIL, `capture_time_offset_bar.dart` not found.

- [ ] **Step 7: Write the bar**

`lib/features/media/presentation/widgets/capture_time_offset_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Coarse and fine steppers that shift every staged file's capture time and
/// re-run [DivePhotoMatcher] live.
///
/// Fixes the case where a camera clock was set to the wrong timezone or never
/// adjusted after travelling: the error is constant across the whole card, so
/// one correction rescues every file at once (issue #312).
///
/// The bar is rendered whenever files are staged and auto-match is on, not
/// only while something is unmatched. Gating it on the unmatched count would
/// make the control vanish the moment a shift succeeded, leaving no way to
/// undo or fine-tune it.
class CaptureTimeOffsetBar extends ConsumerWidget {
  final FilesTabState state;

  const CaptureTimeOffsetBar({super.key, required this.state});

  static const _coarse = Duration(hours: 1);
  static const _fine = Duration(minutes: 15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.media_photoPicker_files_offsetLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _step(context, ref, -_coarse, Icons.keyboard_double_arrow_left),
          _step(context, ref, -_fine, Icons.chevron_left),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              formatSignedOffset(state.captureTimeOffset),
              style: theme.textTheme.titleMedium,
            ),
          ),
          _step(context, ref, _fine, Icons.chevron_right),
          _step(context, ref, _coarse, Icons.keyboard_double_arrow_right),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.media_photoPicker_files_offsetResetTooltip,
            onPressed: state.captureTimeOffset == Duration.zero
                ? null
                : () => _apply(ref, Duration.zero),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, WidgetRef ref, Duration delta, IconData icon) {
    final amount = formatOffsetMagnitude(delta);
    return IconButton(
      icon: Icon(icon),
      tooltip: delta.isNegative
          ? context.l10n.media_photoPicker_files_offsetBackTooltip(amount)
          : context.l10n.media_photoPicker_files_offsetForwardTooltip(amount),
      onPressed: () => _apply(ref, state.captureTimeOffset + delta),
    );
  }

  /// Re-runs the matcher against the freshly loaded dive windows and publishes
  /// the offset and its result in a single state update.
  Future<void> _apply(WidgetRef ref, Duration offset) async {
    final bounds = await ref.read(diveBoundsProvider.future);
    final match = const DivePhotoMatcher().match(
      files: state.files,
      dives: bounds,
      offset: offset,
    );
    ref
        .read(filesTabNotifierProvider.notifier)
        .setCaptureTimeOffset(offset, match: match);
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/capture_time_offset_bar_test.dart
```

Expected: PASS.

- [ ] **Step 9: Host the bar in the review pane**

In `file_review_pane.dart`, insert between the summary `Padding` and the `Expanded`:

```dart
        if (state.files.isNotEmpty && state.autoMatchByDate)
          CaptureTimeOffsetBar(state: state),
```

The `flat` (site session) case returns before this point, so no extra guard is needed for it. Add the import.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/media/presentation/utils/capture_time_offset_format.dart \
        lib/features/media/presentation/widgets/capture_time_offset_bar.dart \
        lib/features/media/presentation/widgets/file_review_pane.dart \
        test/features/media/presentation/utils/capture_time_offset_format_test.dart \
        test/features/media/presentation/widgets/capture_time_offset_bar_test.dart
git commit -m "feat(media): add a live capture-time offset control to the Files review pane"
```

---

## Task 9: Diagnostic subtitle on the review card

**Files:**
- Modify: `lib/features/media/presentation/widgets/file_review_card.dart`
- Test: `test/features/media/presentation/widgets/file_review_card_test.dart`

**Interfaces:**
- Consumes: `TakenAtSource` (Task 1), `UnmatchedDiagnostic` (Task 2), `formatOffsetMagnitude` (Task 8), l10n getters (Task 7).
- Produces: `FileReviewCard.diagnostic` (`UnmatchedDiagnostic?`) and `FileReviewCard.captureTimeOffset` (`Duration`, defaults to `Duration.zero`).

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/presentation/widgets/file_review_card_test.dart`. Migrate the file's pump helper to `testApp` first (see Task 11 if it has not happened yet; if this task runs first, wrap with `testApp(locale: const Locale('en'), overrides: [...], child: ...)` here and let Task 11 finish the rest of the file).

```dart
  testWidgets('shows the provenance of an EXIF capture time', (tester) async {
    final file = _ef(
      '/a.jpg',
      metadata: MediaSourceMetadata(
        takenAt: DateTime.utc(2025, 12, 27, 11, 47),
        takenAtSource: TakenAtSource.nativeExif,
        mimeType: 'image/jpeg',
      ),
    );
    await _pumpCard(tester, file: file);

    expect(find.textContaining('from EXIF'), findsOneWidget);
  });

  testWidgets('flags a capture time that is only the file date', (tester) async {
    final file = _ef(
      '/a.jpg',
      metadata: MediaSourceMetadata(
        takenAt: DateTime.utc(2026, 4, 2, 9, 0),
        takenAtSource: TakenAtSource.fileModifiedTime,
        mimeType: 'image/jpeg',
      ),
    );
    await _pumpCard(tester, file: file);

    expect(find.textContaining('from file date'), findsOneWidget);
  });

  testWidgets('shows the shifted time alongside the original', (tester) async {
    final file = _ef(
      '/a.jpg',
      metadata: MediaSourceMetadata(
        takenAt: DateTime.utc(2025, 12, 27, 16, 47),
        takenAtSource: TakenAtSource.nativeExif,
        mimeType: 'image/jpeg',
      ),
    );
    await _pumpCard(
      tester,
      file: file,
      captureTimeOffset: const Duration(hours: -5),
    );

    expect(find.textContaining('was'), findsOneWidget);
    expect(find.textContaining('11:47'), findsOneWidget);
  });

  testWidgets('explains an unmatched file with no capture time', (tester) async {
    await _pumpCard(
      tester,
      file: _ef('/a.jpg'),
      diagnostic: const UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
    );

    expect(find.text('No capture time could be read'), findsOneWidget);
  });

  testWidgets('reports how far a late file missed the nearest dive', (tester) async {
    await _pumpCard(
      tester,
      file: _ef('/a.jpg'),
      diagnostic: const UnmatchedDiagnostic(
        reason: UnmatchedReason.outsideAllWindows,
        nearestDiveId: 'dive-1',
        gapToNearest: Duration(hours: 3, minutes: 38),
      ),
    );

    expect(find.text('3h 38m after the nearest dive'), findsOneWidget);
  });

  testWidgets('reports how far an early file missed the nearest dive', (tester) async {
    await _pumpCard(
      tester,
      file: _ef('/a.jpg'),
      diagnostic: const UnmatchedDiagnostic(
        reason: UnmatchedReason.outsideAllWindows,
        nearestDiveId: 'dive-1',
        gapToNearest: Duration(hours: -1),
      ),
    );

    expect(find.text('1h 00m before the nearest dive'), findsOneWidget);
  });

  testWidgets('says so when there were no dives to match against', (tester) async {
    await _pumpCard(
      tester,
      file: _ef('/a.jpg'),
      diagnostic: const UnmatchedDiagnostic(
        reason: UnmatchedReason.outsideAllWindows,
      ),
    );

    expect(find.text('No dives to match against'), findsOneWidget);
  });
```

Add a `_pumpCard` helper near the top of the file that wraps the existing seeded-notifier override pattern:

```dart
Future<void> _pumpCard(
  WidgetTester tester, {
  required ExtractedFile file,
  UnmatchedDiagnostic? diagnostic,
  Duration captureTimeOffset = Duration.zero,
  String? assignableDiveId,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        filesTabNotifierProvider.overrideWith(
          (ref) => _SeededFilesTabNotifier(
            FilesTabState.initial().copyWith(files: [file]),
          ),
        ),
      ],
      child: FileReviewCard(
        file: file,
        targetDiveId: null,
        assignableDiveId: assignableDiveId,
        diagnostic: diagnostic,
        captureTimeOffset: captureTimeOffset,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/file_review_card_test.dart
```

Expected: FAIL. `FileReviewCard` has no `diagnostic` parameter.

- [ ] **Step 3: Add the parameters and the subtitle**

In `file_review_card.dart`, add the fields:

```dart
  /// Why this file matched no dive, when it is sitting in the unmatched
  /// bucket. Null for a file in a dive group.
  final UnmatchedDiagnostic? diagnostic;

  /// The session's capture-time correction, so the card can show the
  /// corrected time next to the one actually read from the file.
  final Duration captureTimeOffset;
```

with `this.diagnostic` and `this.captureTimeOffset = Duration.zero` in the constructor. Replace the subtitle with:

```dart
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_timeLine(context)),
          if (diagnostic != null)
            Text(
              _reasonLine(context, diagnostic!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      isThreeLine: diagnostic != null,
```

and add the two builders:

```dart
  /// The capture time plus where it came from. When a session offset is in
  /// effect the corrected time leads and the value actually read from the file
  /// follows in parentheses, so a diver can see what was changed on their
  /// behalf before committing.
  String _timeLine(BuildContext context) {
    final l10n = context.l10n;
    final source = switch (file.metadata.takenAtSource) {
      TakenAtSource.nativeExif => l10n.media_photoPicker_files_sourceExif,
      TakenAtSource.containerMetadata =>
        l10n.media_photoPicker_files_sourceContainer,
      TakenAtSource.fileModifiedTime =>
        l10n.media_photoPicker_files_sourceFileDate,
      TakenAtSource.none => l10n.media_photoPicker_files_sourceNone,
    };
    final takenAt = file.metadata.takenAt;
    if (takenAt == null) return source;

    final original = _format(takenAt);
    if (captureTimeOffset == Duration.zero) return '$original ($source)';
    final shifted = _format(takenAt.add(captureTimeOffset));
    return '${l10n.media_photoPicker_files_shiftedTime(shifted, original)} '
        '($source)';
  }

  String _reasonLine(BuildContext context, UnmatchedDiagnostic diagnostic) {
    final l10n = context.l10n;
    switch (diagnostic.reason) {
      case UnmatchedReason.noTimestamp:
        return l10n.media_photoPicker_files_reasonNoTimestamp;
      case UnmatchedReason.outsideAllWindows:
        final gap = diagnostic.gapToNearest;
        if (gap == null) return l10n.media_photoPicker_files_reasonNoDives;
        final magnitude = formatOffsetMagnitude(gap);
        return gap.isNegative
            ? l10n.media_photoPicker_files_reasonBeforeDive(magnitude)
            : l10n.media_photoPicker_files_reasonAfterDive(magnitude);
    }
  }

  /// `taken_at` is wall-clock-UTC by codebase convention, so format its UTC
  /// components directly. Running it through a local-timezone formatter would
  /// re-introduce the host-offset skew this convention exists to avoid.
  String _format(DateTime value) =>
      DateFormat('yyyy-MM-dd HH:mm').format(value.toUtc());
```

Add imports for `taken_at_source.dart`, `unmatched_diagnostic.dart`, `capture_time_offset_format.dart`, `package:submersion/l10n/l10n_extension.dart`, and `package:intl/intl.dart`. Delete the `// TODO(media): l10n` marker above the `ListTile` once every string in the file is localized (Task 11 finishes the tooltips).

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/file_review_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Feed the diagnostics from the pane**

In `file_review_pane.dart`, pass both new arguments to every `FileReviewCard` in the unmatched group:

```dart
                      FileReviewCard(
                        file: f,
                        targetDiveId: null,
                        assignableDiveId: assignableDiveId,
                        diagnostic: state.match.diagnostics[f.sourcePath],
                        captureTimeOffset: state.captureTimeOffset,
                      ),
```

and pass only `captureTimeOffset:` to the matched-group and flat-variant cards (a matched file has no diagnostic).

- [ ] **Step 6: Run the pane tests**

```bash
flutter test test/features/media/presentation/widgets/file_review_pane_test.dart
```

Expected: PASS. If the existing summary test now fails on a missing `ProviderScope` or missing localizations, migrate it to `testApp` as described in Task 11 and re-run.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/file_review_card.dart \
        lib/features/media/presentation/widgets/file_review_pane.dart \
        test/features/media/presentation/widgets/file_review_card_test.dart \
        test/features/media/presentation/widgets/file_review_pane_test.dart
git commit -m "feat(media): explain on the review card why a file matched no dive"
```

---

## Task 10: Dive-picker escape hatch

**Files:**
- Modify: `lib/features/media/presentation/widgets/file_review_card.dart`
- Test: `test/features/media/presentation/widgets/file_review_card_test.dart`

Without this, a file that matches no dive has no route into the database at all when the picker was opened from the library rather than from a dive: `commit()` walks only `state.match.matched`, and both existing assign affordances are gated on `assignableDiveId != null`.

**Interfaces:**
- Consumes: `showDivePickerSheet(BuildContext) -> Future<String?>` from `lib/features/media/presentation/widgets/dive_picker_sheet.dart`, and `FilesTabNotifier.assignToDive`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/presentation/widgets/file_review_card_test.dart`:

```dart
  testWidgets('offers a dive chooser when there is no assignable dive', (tester) async {
    await _pumpCard(tester, file: _ef('/a.jpg'));

    expect(find.byTooltip('Choose a dive'), findsOneWidget);
    expect(find.byTooltip('Add to this dive'), findsNothing);
  });

  testWidgets('keeps the direct add action when a dive is assignable', (tester) async {
    await _pumpCard(tester, file: _ef('/a.jpg'), assignableDiveId: 'dive-1');

    expect(find.byTooltip('Add to this dive'), findsOneWidget);
    expect(find.byTooltip('Choose a dive'), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/file_review_card_test.dart --plain-name "dive chooser"
```

Expected: FAIL, no widget with tooltip "Choose a dive".

- [ ] **Step 3: Implement the escape hatch**

Replace the `if (canAssign)` block in the `trailing` row with:

```dart
          if (canAssign)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: context.l10n.media_photoPicker_files_addToDiveTooltip,
              onPressed: () => ref
                  .read(filesTabNotifierProvider.notifier)
                  .assignToDive(file.sourcePath, assignTo),
            )
          else if (targetDiveId == null)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: context.l10n.media_photoPicker_files_chooseDiveTooltip,
              onPressed: () => _chooseDive(context, ref),
            ),
```

and add:

```dart
  /// Routes a file with no usable timestamp into a dive the diver picks by
  /// hand.
  ///
  /// Only [FilesTabNotifier.commit] persists files sitting in a dive group, so
  /// for a file the matcher rejected in a library-import session this is the
  /// sole route into the database (issue #312).
  Future<void> _chooseDive(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final diveId = await showDivePickerSheet(context);
    if (diveId == null) return;
    notifier.assignToDive(file.sourcePath, diveId);
  }
```

The notifier is read before the await so no `BuildContext` crosses an async gap.

Add the import for `dive_picker_sheet.dart`. Update the class doc: the "sole route into the database" sentence now applies to both the gated and the ungated case.

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/file_review_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/file_review_card.dart \
        test/features/media/presentation/widgets/file_review_card_test.dart
git commit -m "feat(media): let any staged file be linked to a hand-picked dive"
```

---

## Task 11: Finish localizing the Files tab and migrate its tests

**Files:**
- Modify: `lib/features/media/presentation/widgets/files_tab.dart`
- Modify: `lib/features/media/presentation/widgets/file_review_pane.dart`
- Modify: `lib/features/media/presentation/widgets/file_review_card.dart`
- Test: `test/features/media/presentation/widgets/files_tab_test.dart`
- Test: `test/features/media/presentation/widgets/file_review_pane_test.dart`
- Test: `test/features/media/presentation/widgets/file_review_card_test.dart`

Three `TODO(media): l10n` markers remain. Clearing them now avoids shipping new translated strings sitting next to old hardcoded English in the same widget.

**The test migration is not optional.** `file_review_pane_test.dart` currently pumps a bare `MaterialApp` with neither a `ProviderScope` nor localization delegates. Once the pane calls `context.l10n` and hosts a provider-reading offset bar, that test throws. `file_review_card_test.dart` has a `ProviderScope` but no delegates.

- [ ] **Step 1: Migrate the three test files to `testApp`**

Replace every `pumpWidget(MaterialApp(...))` and `pumpWidget(ProviderScope(... MaterialApp(...)))` in the three files with `testApp(locale: const Locale('en'), overrides: [...], child: ...)` from `test/helpers/test_app.dart`. `testApp` already supplies the `ProviderScope`, the delegates, and a `Scaffold`, so drop any hand-rolled wrapper. Pin `locale: const Locale('en')` in every case: the assertions below match English text, and an unpinned locale resolves against the host.

- [ ] **Step 2: Run the three files to confirm they still pass unmodified behavior**

```bash
flutter test test/features/media/presentation/widgets/files_tab_test.dart \
             test/features/media/presentation/widgets/file_review_pane_test.dart \
             test/features/media/presentation/widgets/file_review_card_test.dart
```

Expected: PASS. This is a refactor of the harness only, so a failure here is a migration mistake, not a behavior change.

- [ ] **Step 3: Localize `files_tab.dart`**

Replace the hardcoded strings with l10n calls: the two picker button labels, the auto-match checkbox label, the empty-state hint, and `_commitLabel`. `_commitLabel` becomes:

```dart
  String _commitLabel(BuildContext context, FilesTabState state) {
    final count = _committableCount(state);
    return _isSiteSession
        ? context.l10n.media_photoPicker_files_attachToSiteButton(count)
        : context.l10n.media_photoPicker_files_linkButton(count);
  }
```

Update its call site to pass `context`. Delete the `TODO(media): l10n` marker.

- [ ] **Step 4: Localize `file_review_pane.dart`**

Replace the summary string with:

```dart
    final summary = context.l10n.media_photoPicker_files_summary(
      state.files.length,
      state.match.diveCount,
      state.match.unmatched.length,
    );
```

Confirm the generated getter's parameter order against `lib/l10n/arb/app_localizations.dart` after Task 7's codegen and match it. Replace the dive group title with `media_photoPicker_files_diveGroupTitle(entry.key)`, the group subtitles with `media_photoPicker_files_groupCount(...)`, the unmatched title with `media_photoPicker_files_unmatchedGroupTitle`, the bulk button with `media_photoPicker_files_addAllToDive(...)`, and the flat count with `media_photoPicker_files_itemCount(count)`. Delete both `TODO(media): l10n` markers.

- [ ] **Step 5: Localize the remaining card tooltip**

Replace `tooltip: 'Remove from selection'` with `context.l10n.media_photoPicker_files_removeTooltip`.

- [ ] **Step 6: Confirm no hardcoded English remains**

```bash
grep -n "TODO(media): l10n" lib/features/media/presentation/widgets/files_tab.dart \
                            lib/features/media/presentation/widgets/file_review_pane.dart \
                            lib/features/media/presentation/widgets/file_review_card.dart
```

Expected: no output.

- [ ] **Step 7: Run the three test files plus the l10n guards**

```bash
flutter test test/features/media/presentation/widgets/files_tab_test.dart \
             test/features/media/presentation/widgets/file_review_pane_test.dart \
             test/features/media/presentation/widgets/file_review_card_test.dart \
             test/features/media/presentation/widgets/capture_time_offset_bar_test.dart \
             test/l10n/
```

Expected: PASS. Assertions that matched the old hardcoded strings may need their expected text updated to the new ARB values; update the expectation, never the ARB, to make a test pass.

- [ ] **Step 8: Commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/ test/features/media/presentation/widgets/
git commit -m "refactor(media): localize the Files tab review surface"
```

---

## Task 12: Verification and pull request

**Files:** none modified beyond fixes this task surfaces.

- [ ] **Step 1: Format the whole project**

```bash
dart format .
git diff --stat
```

Expected: no unstaged formatting changes. If there are, commit them.

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze
```

Expected: `No issues found!`. Do not pipe this through `grep` or `head`: the pipeline's exit status is the last command's, which masks a failure. Infos are fatal in CI, so treat every reported line as a blocker.

- [ ] **Step 3: Run the full test suite, once**

```bash
flutter test
```

Expected: all tests pass. Do not pipe it. Run it exactly once and do not run another suite concurrently in a sibling session: overlapping runs collide on shared temp directories and manufacture failures that do not reproduce alone. If a single unfamiliar file fails, re-run that file by itself before believing it.

- [ ] **Step 4: Push and open the PR**

```bash
git push -u origin worktree-media-capture-time-offset
gh pr create --base main --title "Explain and correct capture-time mismatches when linking media" --body "$(cat <<'BODY'
Closes #312.

Linking picked files to dives failed silently in two different ways, and the review pane never said which.

## What changed

**Timestamp provenance.** `ExifExtractor` resolves a capture time through three tiers (native EXIF, a pure-Dart container parse, then the file's modification time) and previously discarded which one it used. Each tier is now recorded as a `TakenAtSource` and shown on the review card, so a filesystem timestamp is visibly distinguishable from a real capture time.

**Match diagnostics.** `DivePhotoMatcher` collapsed "no timestamp at all" and "timestamp outside every dive window" into the same unmatched bucket. It now reports which, plus the nearest dive and the signed gap to its match window, and the card renders that as a reason line.

**A capture-time offset.** The most common cause of a total match failure is a camera clock left on the wrong timezone, which puts a constant error on every file from the card. The review pane gained a stepper that shifts every staged file's capture time and re-runs the matcher live, so one correction rescues the whole import.

The offset is applied when writing `taken_at`, not only when matching. `EnrichmentService` derives elapsed-since-entry from that column to place a photo on the profile chart and derive its depth badge, so persisting an unshifted time for a file that only matched because of the shift would give every such photo a large negative elapsed, which resolves to the first profile sample's depth.

**A route in for undateable files.** When the picker was opened from the library rather than from a dive, an unmatched file could not reach the database at all: `commit()` persists only files sitting in a dive group, and both existing assign affordances were gated on having a dive in context. The card now offers the existing dive picker sheet in that case.

## Scope

Files tab only. The gallery scan path shares the domain layer but has its own review dialog and no assignable unmatched group; the domain changes here are additive so it can adopt them later. No database schema change.

The Files tab's `TODO(media): l10n` debt is cleared as part of this, since most of its strings were being rewritten anyway.
BODY
)"
```

- [ ] **Step 5: Reply on issue #312**

After the PR opens, comment on the issue explaining which remedy addresses which of the reporter's two cases: the offset control for the camera-and-computer clock mismatch, and the dive picker for photos edited and re-saved after the dive whose original capture time is gone.

---

## Self-Review Notes

Checked against the spec:

- Provenance (spec section 1) is Task 1.
- Matcher offset and diagnostics (section 2) are Tasks 2 and 3.
- Persist-time offset (section 3) is Task 6, with the enrichment rationale carried into a code comment so it survives the plan.
- State, including the `clearStagedFiles` reset and `diveBoundsProvider` (section 4), is Tasks 4 and 5.
- UI: offset bar, card subtitle, escape hatch (section 5) are Tasks 8, 9, 10.
- Localization (section 6) is Tasks 7 and 11.
- Testing (section 7) is distributed across every task, with the full-suite gate in Task 12.

Two corrections to the spec, applied here:

1. The spec estimated "roughly 15 keys". The real count is 28, because clearing the `TODO(media): l10n` debt covers the picker buttons, the checkbox label, the empty hint, both commit-button variants, and the group headers, not only the new diagnostic strings.
2. The spec did not mention that `MatchedSelection` needs a `copyWith`, nor that `removeFile` / `assignToDive` / `assignAllUnmatched` would silently drop the new `diagnostics` map by rebuilding the selection from scratch. Task 5 Step 5 covers it, with a test in Task 5 Step 1.
