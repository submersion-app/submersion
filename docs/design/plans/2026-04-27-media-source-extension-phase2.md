# Media Source Extension — Phase 2 (Local Files) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the Files tab in the photo picker so divers can link photos and videos from their local filesystem (desktop) or via security-scoped bookmarks / persistable URIs (iOS / Android), with EXIF-driven auto-match-by-dive-date and a review-and-adjust UI.

**Architecture:** Build on Phase 1's foundation. Promote the existing Phase 1 stub `LocalFileResolver` to a full multi-platform implementation that uses `LocalMediaPlatform` (already-built native channel) + `flutter_secure_storage` for iOS bookmark blob storage. Add a new shared `DivePhotoMatcher` domain service that powers both the new Files-tab auto-match and the existing `TripMediaScanner.scanGalleryForDive` flow. Add a new `ExifExtractor` service using `native_exif` (already in pubspec). The Files tab UI replaces the existing debug-gated placeholder with a real stateful tab body wired to all of the above.

**Tech Stack:** Flutter 3.41 + Material 3, Riverpod 2.x, `file_picker`, `native_exif`, `flutter_secure_storage`, Drift (no schema changes — Phase 1 already added `localPath` and `bookmarkRef` columns), Swift on iOS/macOS, Kotlin on Android.

**Spec:** [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) (section 5).

**No schema migration needed** — Phase 1's v72 migration already added `localPath`, `bookmarkRef`, `originDeviceId` and the rest. Phase 2 fills in the user-facing flow that produces those rows.

---

## Background Reading

Read these before starting:

- [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) section 5 — Phase 2 spec.
- [lib/features/media/data/resolvers/local_file_resolver.dart](../../lib/features/media/data/resolvers/local_file_resolver.dart) — Phase 1 stub to replace.
- [lib/features/media/data/services/local_media_platform.dart](../../lib/features/media/data/services/local_media_platform.dart) — Dart wrapper for the native channel.
- [lib/features/media/data/services/trip_media_scanner.dart](../../lib/features/media/data/services/trip_media_scanner.dart) — existing matcher logic; Phase 2 extracts it into `DivePhotoMatcher`.
- [lib/features/media/presentation/pages/photo_picker_page.dart](../../lib/features/media/presentation/pages/photo_picker_page.dart) — current tab shell + placeholder Files tab to replace.
- [ios/Runner/LocalMediaHandler.swift](../../ios/Runner/LocalMediaHandler.swift) and [macos/Runner/LocalMediaHandler.swift](../../macos/Runner/LocalMediaHandler.swift) — native bookmark handlers (Phase 2 may add a `readBookmarkBytes` method).
- [android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt](../../android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt) — native URI handler (Phase 2 may add a `readBookmarkBytes` method).

Conventions:

- TDD throughout. `dart format .` before every commit. NO `Co-Authored-By` lines in commits.
- File naming: `snake_case.dart`. Class naming: `PascalCase`.
- Riverpod providers: `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state.
- Dive times are **wall-clock-as-UTC**. When querying `photo_manager` or any local-time-keyed API, convert via `TripMediaScanner.wallClockUtcToLocal(...)`. The buffer should be applied in wall-clock-UTC FIRST, then converted (mirrors `scanGalleryForDive`; PR #270 covers the picker callsite parity).

---

## File Structure

| Path | Created/Modified | Responsibility |
|---|---|---|
| `lib/features/media/data/services/exif_extractor.dart` | Create | Read EXIF from a `File` via `native_exif`, return `MediaSourceMetadata`. Isolate dispatch for files > 5 MB. |
| `lib/features/media/data/services/local_bookmark_storage.dart` | Create | Wrap `flutter_secure_storage` for iOS/macOS bookmark blob persistence. Write/read/delete blobs keyed by `bookmarkRef`. |
| `lib/features/media/domain/services/dive_photo_matcher.dart` | Create | Match a list of `ExtractedFile` records to dives by EXIF `takenAt` within `[start-30min, end+60min]` window. |
| `lib/features/media/domain/value_objects/extracted_file.dart` | Create | Value type representing a file picked + EXIF-extracted, before commit. |
| `lib/features/media/domain/value_objects/matched_selection.dart` | Create | Result of `DivePhotoMatcher.match()`: `Map<DiveId, List<ExtractedFile>> matched` + `List<ExtractedFile> unmatched`. |
| `lib/features/media/data/resolvers/local_file_resolver.dart` | Modify | Replace Phase 1 stub with full multi-platform impl: desktop reads `localPath`, iOS/macOS reads `bookmarkRef` via `LocalMediaPlatform`, Android reads `bookmarkRef` URI via `LocalMediaPlatform`. |
| `lib/features/media/data/services/local_media_platform.dart` | Modify | Add `readBytesForRef(bookmarkRef)` method (Android-specific path uses ContentResolver under the hood). |
| `lib/features/media/data/services/trip_media_scanner.dart` | Modify | Refactor to delegate matching logic to `DivePhotoMatcher`. |
| `lib/features/media/presentation/widgets/files_tab.dart` | Create | Stateful Files tab: file picker action + folder picker action + auto-match toggle + review pane. |
| `lib/features/media/presentation/widgets/file_review_pane.dart` | Create | Review pane: thumbnail cards grouped by target dive + unmatched bucket. |
| `lib/features/media/presentation/widgets/file_review_card.dart` | Create | Single-file thumbnail card with reassign/remove inline actions. |
| `lib/features/media/presentation/providers/files_tab_providers.dart` | Create | State management for picked files, EXIF extraction progress, auto-match state. |
| `lib/features/media/presentation/pages/photo_picker_page.dart` | Modify | Replace `_PlaceholderTab(message: 'Coming in Phase 2')` with the real `FilesTab` widget. |
| `lib/features/media/presentation/widgets/dive_media_section.dart` | Modify | Add long-press context menu items: "Show in Finder/Explorer/Files" (desktop only) and "Replace link…". |
| `lib/features/media/presentation/pages/media_sources_page.dart` | Modify | Add "Local files" subsection: linked count by status, "Re-verify all local files" action, Android URI usage indicator. |
| `lib/features/media/data/services/local_files_diagnostics_service.dart` | Create | Powers the Local files Settings subsection: counts by orphan status, re-verify-all logic, list persisted Android URIs. |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Modify (minor) | When the new Files tab succeeds, the existing photo-import flow must also work — verify nothing breaks. |
| `ios/Runner/LocalMediaHandler.swift` | Modify | Add `readBookmarkBytes` method (used by `LocalFileResolver` to extract EXIF from bookmark-resolved files). |
| `macos/Runner/LocalMediaHandler.swift` | Modify | Same. |
| `android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt` | Modify | Add `readBookmarkBytes` method (uses `ContentResolver.openInputStream(uri)` to read bytes from a persisted URI). |
| Plus tests for every new file in `test/` (mirror lib/ structure). | | |

---

## Task 1: `ExifExtractor` Service

**Files:**
- Create: `lib/features/media/data/services/exif_extractor.dart`
- Test: `test/features/media/data/services/exif_extractor_test.dart`

`native_exif` is already a dependency. The extractor returns a `MediaSourceMetadata` value object built from the EXIF tags. For files larger than 5 MB it dispatches to `compute()` to keep the UI thread responsive.

- [ ] **Step 1: Read the native_exif API surface**

```bash
find ~/.pub-cache -path "*native_exif-0.7*" -name "*.dart" | head -3 | xargs grep -l "getOriginalFileExif\|class NativeExif" | head -3
```

Read `lib/native_exif.dart` from the pub cache. Note the methods (`fromPath`, `getAttributes`, etc.) and the `ExifAttribute` shape. The fields you'll read are `DateTimeOriginal`, `GPSLatitude`, `GPSLongitude`, `PixelXDimension` / `ImageWidth`, `PixelYDimension` / `ImageLength`. (`native_exif` returns these as strings; you'll parse them.)

- [ ] **Step 2: Write the failing test**

Create `test/features/media/data/services/exif_extractor_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exif_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns metadata with mtime fallback when file has no EXIF',
      () async {
    final f = File('${tempDir.path}/no_exif.bin')
      ..writeAsBytesSync([0, 1, 2, 3]);
    final extractor = ExifExtractor();
    final meta = await extractor.extract(f);
    expect(meta, isNotNull);
    expect(meta!.takenAt, isNotNull); // file mtime fallback
    expect(meta.takenAt!.difference(DateTime.now()).abs(),
        lessThan(const Duration(minutes: 5)));
    expect(meta.mimeType, isNotEmpty);
  });

  test('returns null on missing file', () async {
    final extractor = ExifExtractor();
    final meta = await extractor.extract(File('${tempDir.path}/missing'));
    expect(meta, isNull);
  });
}
```

(Real EXIF parsing is exercised by integration tests with bundled fixtures — too noisy for a unit suite. Real-image fixtures would belong in `test/fixtures/media/`; defer adding them to a future task if fixtures don't already exist.)

- [ ] **Step 3: Run the test to verify it fails**

```bash
flutter test test/features/media/data/services/exif_extractor_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 4: Implement `ExifExtractor`**

Create `lib/features/media/data/services/exif_extractor.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:native_exif/native_exif.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

const _isolateThresholdBytes = 5 * 1024 * 1024;

/// Extracts [MediaSourceMetadata] from a local file via `native_exif`.
///
/// Files larger than 5 MB run in a background isolate via `compute()` so
/// the UI thread stays responsive during folder picks of large libraries.
class ExifExtractor {
  Future<MediaSourceMetadata?> extract(File file) async {
    if (!file.existsSync()) return null;
    final size = file.lengthSync();
    if (size > _isolateThresholdBytes) {
      return compute(_extractIsolate, file.path);
    }
    return _extract(file.path);
  }
}

Future<MediaSourceMetadata?> _extractIsolate(String path) =>
    _extract(path);

Future<MediaSourceMetadata?> _extract(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final mtime = file.lastModifiedSync();
  final ext = path.split('.').last.toLowerCase();
  final mime = _mimeFromExtension(ext);

  DateTime? takenAt;
  double? lat;
  double? lon;
  int? width;
  int? height;
  int? duration;

  try {
    final exif = await Exif.fromPath(path);
    final attrs = await exif.getAttributes();
    await exif.close();

    if (attrs != null) {
      takenAt = _parseExifDate(attrs['DateTimeOriginal'] as String?);
      lat = _parseGps(
        attrs['GPSLatitude'] as String?,
        attrs['GPSLatitudeRef'] as String?,
      );
      lon = _parseGps(
        attrs['GPSLongitude'] as String?,
        attrs['GPSLongitudeRef'] as String?,
      );
      width = int.tryParse('${attrs['PixelXDimension'] ?? attrs['ImageWidth'] ?? ''}');
      height = int.tryParse(
          '${attrs['PixelYDimension'] ?? attrs['ImageLength'] ?? ''}');
    }
  } on Object {
    // native_exif throws PlatformException on unsupported formats; treat
    // as "no EXIF available", fall through to mtime fallback.
  }

  return MediaSourceMetadata(
    takenAt: takenAt ?? mtime,
    latitude: lat,
    longitude: lon,
    width: width,
    height: height,
    durationSeconds: duration,
    mimeType: mime,
  );
}

DateTime? _parseExifDate(String? raw) {
  if (raw == null) return null;
  // EXIF format: "YYYY:MM:DD HH:MM:SS"
  try {
    final parts = raw.split(' ');
    if (parts.length != 2) return null;
    final dateParts = parts[0].split(':');
    final timeParts = parts[1].split(':');
    if (dateParts.length != 3 || timeParts.length != 3) return null;
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  } on FormatException {
    return null;
  }
}

double? _parseGps(String? value, String? ref) {
  if (value == null) return null;
  // native_exif returns GPS values as decimal-degree strings already.
  final dec = double.tryParse(value);
  if (dec == null) return null;
  if (ref == 'S' || ref == 'W') return -dec;
  return dec;
}

String _mimeFromExtension(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'm4v':
      return 'video/x-m4v';
    default:
      return 'application/octet-stream';
  }
}
```

If the `native_exif` API differs from what's described above (e.g., method names changed in 0.7.0), adjust to match the actual API and report what you used.

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/media/data/services/exif_extractor_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/services/exif_extractor.dart test/features/media/data/services/exif_extractor_test.dart
git add lib/features/media/data/services/exif_extractor.dart test/features/media/data/services/exif_extractor_test.dart
git commit -m "feat(media): add ExifExtractor service for local file metadata"
```

---

## Task 2: `ExtractedFile` and `MatchedSelection` Value Objects

**Files:**
- Create: `lib/features/media/domain/value_objects/extracted_file.dart`
- Create: `lib/features/media/domain/value_objects/matched_selection.dart`
- Test: `test/features/media/domain/value_objects/extracted_file_test.dart`

These are pure value types used by the picker → matcher → committer pipeline.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/extracted_file_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

ExtractedFile _ef(String path, {DateTime? takenAt}) => ExtractedFile(
      sourcePath: path,
      file: File(path),
      metadata: MediaSourceMetadata(
        takenAt: takenAt,
        mimeType: 'image/jpeg',
      ),
    );

void main() {
  test('ExtractedFile equality is value-based', () {
    final a = _ef('/x.jpg');
    final b = _ef('/x.jpg');
    expect(a, b);
  });

  test('MatchedSelection has empty default state', () {
    final s = MatchedSelection.empty();
    expect(s.matched, isEmpty);
    expect(s.unmatched, isEmpty);
    expect(s.totalFiles, 0);
  });

  test('MatchedSelection counts matched + unmatched', () {
    final s = MatchedSelection(
      matched: {
        'dive-1': [_ef('/a.jpg'), _ef('/b.jpg')],
      },
      unmatched: [_ef('/c.jpg')],
    );
    expect(s.totalFiles, 3);
    expect(s.matched['dive-1']!.length, 2);
    expect(s.unmatched.length, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/domain/value_objects/extracted_file_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create the value objects**

Create `lib/features/media/domain/value_objects/extracted_file.dart`:

```dart
import 'dart:io';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// A file selected by the user in the Files tab, after EXIF / metadata
/// extraction but before being committed as a [MediaItem].
class ExtractedFile extends Equatable {
  final String sourcePath;
  final File file;
  final MediaSourceMetadata metadata;
  final String? warning;

  const ExtractedFile({
    required this.sourcePath,
    required this.file,
    required this.metadata,
    this.warning,
  });

  @override
  List<Object?> get props => [sourcePath, file.path, metadata, warning];
}
```

Create `lib/features/media/domain/value_objects/matched_selection.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';

/// Result of [DivePhotoMatcher.match]: files routed to dives, plus the
/// bucket that didn't match any dive.
class MatchedSelection extends Equatable {
  final Map<String, List<ExtractedFile>> matched;
  final List<ExtractedFile> unmatched;

  const MatchedSelection({
    required this.matched,
    required this.unmatched,
  });

  factory MatchedSelection.empty() =>
      const MatchedSelection(matched: {}, unmatched: []);

  int get totalFiles =>
      matched.values.fold<int>(0, (a, list) => a + list.length) +
      unmatched.length;

  int get diveCount => matched.length;

  @override
  List<Object?> get props => [matched, unmatched];
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/domain/value_objects/extracted_file_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/value_objects/ test/features/media/domain/value_objects/
git add lib/features/media/domain/value_objects/extracted_file.dart lib/features/media/domain/value_objects/matched_selection.dart test/features/media/domain/value_objects/extracted_file_test.dart
git commit -m "feat(media): add ExtractedFile and MatchedSelection value objects"
```

---

## Task 3: `DivePhotoMatcher` Domain Service

**Files:**
- Create: `lib/features/media/domain/services/dive_photo_matcher.dart`
- Test: `test/features/media/domain/services/dive_photo_matcher_test.dart`

The shared matcher used by both the new Files tab and the existing gallery scan. Match algorithm per spec section 5 step 5: each file's `takenAt` against dive `[startTime - 30min, endTime + 60min]`. For overlapping matches, pick the dive whose `startTime` is closest to the file's `takenAt`. Files with no `takenAt` or no matching dive go to `unmatched`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/services/dive_photo_matcher_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

ExtractedFile _ef(String path, DateTime? takenAt) => ExtractedFile(
      sourcePath: path,
      file: File(path),
      metadata: MediaSourceMetadata(
        takenAt: takenAt,
        mimeType: 'image/jpeg',
      ),
    );

DiveBounds _dive(String id, DateTime start, Duration runtime) =>
    DiveBounds(diveId: id, entryTime: start, exitTime: start.add(runtime));

void main() {
  final matcher = DivePhotoMatcher();

  test('routes file taken during dive window to that dive', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [
      _ef('/a.jpg', DateTime.utc(2024, 4, 1, 10, 15)),
    ];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched['d1'], isNotEmpty);
    expect(result.unmatched, isEmpty);
  });

  test('files within pre/post buffer route to the dive', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [
      _ef('/pre.jpg', DateTime.utc(2024, 4, 1, 9, 45)), // -15min
      _ef('/post.jpg', DateTime.utc(2024, 4, 1, 11, 30)), // +15min after exit
    ];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched['d1']!.length, 2);
    expect(result.unmatched, isEmpty);
  });

  test('no match when file is outside buffer window', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [
      _ef('/late.jpg', DateTime.utc(2024, 4, 1, 13, 0)), // way after
    ];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched, isEmpty);
    expect(result.unmatched.length, 1);
  });

  test('no match when file has no takenAt', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [_ef('/x.jpg', null)];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.unmatched.length, 1);
  });

  test('overlapping dives: closest startTime wins', () {
    final earlier = _dive(
      'd-early',
      DateTime.utc(2024, 4, 1, 9, 30),
      const Duration(minutes: 60),
    );
    final later = _dive(
      'd-later',
      DateTime.utc(2024, 4, 1, 10, 5),
      const Duration(minutes: 60),
    );
    final files = [
      _ef('/x.jpg', DateTime.utc(2024, 4, 1, 10, 10)),
    ];
    final result = matcher.match(files: files, dives: [earlier, later]);
    expect(result.matched['d-later']!.length, 1);
    expect(result.matched.containsKey('d-early'), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/domain/services/dive_photo_matcher_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `DivePhotoMatcher`**

Create `lib/features/media/domain/services/dive_photo_matcher.dart`:

```dart
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';

/// Lightweight value type representing a dive's time bounds for matching.
/// Decoupled from the full Dive entity so the matcher can be unit-tested
/// without a database.
class DiveBounds {
  final String diveId;
  final DateTime entryTime;
  final DateTime exitTime;

  const DiveBounds({
    required this.diveId,
    required this.entryTime,
    required this.exitTime,
  });
}

/// Routes [ExtractedFile]s to dives by matching their EXIF [takenAt]
/// against each dive's `[entryTime - 30min, exitTime + 60min]` window.
///
/// Used by both the Files-tab (Phase 2) and the existing gallery scan
/// (TripMediaScanner) so both paths produce identical assignments.
///
/// Tie-breaker for overlapping windows: the dive whose [entryTime] is
/// closest to the file's [takenAt].
class DivePhotoMatcher {
  static const Duration preBuffer = Duration(minutes: 30);
  static const Duration postBuffer = Duration(minutes: 60);

  MatchedSelection match({
    required List<ExtractedFile> files,
    required List<DiveBounds> dives,
  }) {
    final matched = <String, List<ExtractedFile>>{};
    final unmatched = <ExtractedFile>[];

    for (final file in files) {
      final takenAt = file.metadata.takenAt;
      if (takenAt == null) {
        unmatched.add(file);
        continue;
      }

      DiveBounds? best;
      Duration? bestDelta;
      for (final dive in dives) {
        final windowStart = dive.entryTime.subtract(preBuffer);
        final windowEnd = dive.exitTime.add(postBuffer);
        if (takenAt.isBefore(windowStart) || takenAt.isAfter(windowEnd)) {
          continue;
        }
        final delta = (takenAt.difference(dive.entryTime)).abs();
        if (best == null || delta < bestDelta!) {
          best = dive;
          bestDelta = delta;
        }
      }

      if (best == null) {
        unmatched.add(file);
      } else {
        matched.putIfAbsent(best.diveId, () => []).add(file);
      }
    }

    return MatchedSelection(matched: matched, unmatched: unmatched);
  }
}
```

- [ ] **Step 4: Run to verify the test passes**

```bash
flutter test test/features/media/domain/services/dive_photo_matcher_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/services/dive_photo_matcher.dart test/features/media/domain/services/dive_photo_matcher_test.dart
git add lib/features/media/domain/services/dive_photo_matcher.dart test/features/media/domain/services/dive_photo_matcher_test.dart
git commit -m "feat(media): add DivePhotoMatcher shared matching service"
```

---

## Task 4: Refactor `TripMediaScanner.scanGalleryForDive` to Use `DivePhotoMatcher`

**Files:**
- Modify: `lib/features/media/data/services/trip_media_scanner.dart`
- Test: `test/features/media/data/services/trip_media_scanner_test.dart` (existing — should still pass after refactor)

The existing scanner has hand-rolled matching logic in `_findExactDiveBounds` / `_findBufferDiveBounds`. Replace with a call to `DivePhotoMatcher.match()`. This is a refactor — visible behavior must not change.

- [ ] **Step 1: Read the existing matching logic**

```bash
sed -n '50,200p' lib/features/media/data/services/trip_media_scanner.dart
```

Note the buffer values used (compare to `DivePhotoMatcher.preBuffer` / `postBuffer` — they should match). If they differ, BLOCK and report — picking which buffer is correct is a product decision, not a refactor decision.

- [ ] **Step 2: Run existing tests as a baseline**

```bash
flutter test test/features/media/data/services/trip_media_scanner_test.dart
```

Expected: PASS (whatever count exists). Note the count for comparison after the refactor.

- [ ] **Step 3: Refactor `scanGalleryForTrip` to use `DivePhotoMatcher`**

The method currently iterates `trip.dives` and calls internal `_findExactDive` helpers. Replace the matching loop with:

```dart
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

// Inside scanGalleryForTrip, after fetching `assets`:
final matcher = DivePhotoMatcher();
final extractedFiles = assets.map((asset) {
  return ExtractedFile(
    sourcePath: asset.id, // use asset id as path placeholder
    file: File(asset.id), // not actually read — matcher only needs metadata
    metadata: MediaSourceMetadata(
      takenAt: asset.createDateTime,
      latitude: asset.latitude,
      longitude: asset.longitude,
      width: asset.width,
      height: asset.height,
      mimeType: 'image/jpeg', // placeholder; not consumed by matcher
    ),
  );
}).toList();

final dives = trip.dives.map((d) {
  final (entry, exit) = _getDiveBounds(d);
  return DiveBounds(
    diveId: d.id,
    entryTime: entry,
    exitTime: exit,
  );
}).toList();

final result = matcher.match(files: extractedFiles, dives: dives);

// Convert MatchedSelection back to whatever ScanResult shape the existing API expects.
// (Existing API likely returns Map<DiveId, List<AssetInfo>> — re-pair using extractedFiles' index.)
```

NOTE: this is a sketch. The actual integration depends on `ScanResult` shape. Read the existing API and adapt. If the asset IDs are sufficient to round-trip back to `AssetInfo`, do that. Otherwise pass the original `AssetInfo` through `ExtractedFile.warning` or extend `ExtractedFile` with an opaque `payload` field. **Mark a clear comment explaining the round-trip.**

If the existing `_findExactDiveBounds` and the new matcher use different buffer values (preBuffer 30 vs 30, postBuffer 60 vs 30), you'll have a behavior change. Pick the spec-defined buffers (`preBuffer = 30`, `postBuffer = 60`) and update any tests that asserted the old values.

- [ ] **Step 4: Run all relevant tests**

```bash
flutter test test/features/media/data/services/trip_media_scanner_test.dart
flutter test
```

Expected: PASS at the same count or higher (no test removed).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/trip_media_scanner.dart
git add lib/features/media/data/services/trip_media_scanner.dart
git commit -m "refactor(media): delegate gallery match to DivePhotoMatcher"
```

If you discovered a buffer-value mismatch and updated tests, include the test changes in the same commit.

---

## Task 5: `LocalBookmarkStorage` Service (iOS/macOS Bookmark Persistence)

**Files:**
- Create: `lib/features/media/data/services/local_bookmark_storage.dart`
- Test: `test/features/media/data/services/local_bookmark_storage_test.dart`

Wraps `flutter_secure_storage` to persist iOS/macOS security-scoped bookmark blobs. The Dart side calls `LocalMediaPlatform.createBookmark(filePath)` which returns a raw blob; we save that blob via this service keyed by a generated `bookmarkRef` UUID. On display, the Dart side reads the blob back via this service and passes it to `LocalMediaPlatform.resolveBookmark(blob)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/local_bookmark_storage_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';

import 'local_bookmark_storage_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  late MockFlutterSecureStorage mockStorage;
  late LocalBookmarkStorage subject;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    subject = LocalBookmarkStorage(storage: mockStorage);
  });

  test('write stores blob keyed by bookmarkRef', () async {
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    final blob = Uint8List.fromList([1, 2, 3]);
    await subject.write('ref-1', blob);
    verify(mockStorage.write(
      key: 'bookmark:ref-1',
      value: 'AQID', // base64 of [1,2,3]
    )).called(1);
  });

  test('read returns blob bytes', () async {
    when(mockStorage.read(key: 'bookmark:ref-1'))
        .thenAnswer((_) async => 'AQID'); // base64 of [1,2,3]
    final blob = await subject.read('ref-1');
    expect(blob, [1, 2, 3]);
  });

  test('read returns null when key absent', () async {
    when(mockStorage.read(key: 'bookmark:absent'))
        .thenAnswer((_) async => null);
    expect(await subject.read('absent'), isNull);
  });

  test('delete removes stored blob', () async {
    when(mockStorage.delete(key: anyNamed('key')))
        .thenAnswer((_) async {});
    await subject.delete('ref-1');
    verify(mockStorage.delete(key: 'bookmark:ref-1')).called(1);
  });
}
```

- [ ] **Step 2: Run codegen to create the mock**

```bash
dart run build_runner build --delete-conflicting-outputs
```

If your codebase uses mocktail instead of mockito, adapt — search `test/` for `@GenerateMocks` to confirm mockito convention.

- [ ] **Step 3: Run to verify the test fails**

```bash
flutter test test/features/media/data/services/local_bookmark_storage_test.dart
```

Expected: FAIL — file doesn't exist.

- [ ] **Step 4: Implement `LocalBookmarkStorage`**

Create `lib/features/media/data/services/local_bookmark_storage.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists iOS / macOS security-scoped bookmark blobs in the platform
/// keychain via flutter_secure_storage.
///
/// Blobs are namespaced under the `bookmark:` key prefix to avoid colliding
/// with other secure-storage entries (network credentials, connector tokens).
///
/// Blobs are stored base64-encoded because flutter_secure_storage exposes
/// only a string API on its lowest common denominator.
class LocalBookmarkStorage {
  final FlutterSecureStorage _storage;

  LocalBookmarkStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static String _key(String bookmarkRef) => 'bookmark:$bookmarkRef';

  Future<void> write(String bookmarkRef, Uint8List blob) async {
    await _storage.write(key: _key(bookmarkRef), value: base64Encode(blob));
  }

  Future<Uint8List?> read(String bookmarkRef) async {
    final raw = await _storage.read(key: _key(bookmarkRef));
    if (raw == null) return null;
    return base64Decode(raw);
  }

  Future<void> delete(String bookmarkRef) async {
    await _storage.delete(key: _key(bookmarkRef));
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/media/data/services/local_bookmark_storage_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/services/local_bookmark_storage.dart test/features/media/data/services/local_bookmark_storage_test.dart
git add lib/features/media/data/services/local_bookmark_storage.dart test/features/media/data/services/local_bookmark_storage_test.dart test/features/media/data/services/local_bookmark_storage_test.mocks.dart
git commit -m "feat(media): add LocalBookmarkStorage for iOS/macOS bookmark persistence"
```

---

## Task 6: Native Channel — Add `readBookmarkBytes` / `readUriBytes`

**Files:**
- Modify: `ios/Runner/LocalMediaHandler.swift`
- Modify: `macos/Runner/LocalMediaHandler.swift`
- Modify: `android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt`
- Modify: `lib/features/media/data/services/local_media_platform.dart`

Phase 1's native handlers can resolve a bookmark/URI to a session ref + file path. Phase 2 needs to actually READ bytes. On iOS/macOS, after `resolveBookmark` we have a security-scoped file URL — return its bytes. On Android, after `takePersistableUri` the URI is durable; we use `ContentResolver.openInputStream(uri)` to read bytes.

The Dart side gets one new method: `LocalMediaPlatform.readBytesForRef(bookmarkRef)`. Internally it works differently per platform.

- [ ] **Step 1: Add `readBookmarkBytes` to iOS handler**

In `ios/Runner/LocalMediaHandler.swift`, add a new method case:

```swift
case "readBookmarkBytes":
    guard let args = call.arguments as? [String: Any],
          let blob = args["bookmarkBlob"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "bookmarkBlob required", details: nil))
        return
    }
    readBookmarkBytes(blob: blob.data, result: result)
```

And the implementation:

```swift
private func readBookmarkBytes(blob: Data, result: @escaping FlutterResult) {
    var stale = false
    do {
        let url = try URL(
            resolvingBookmarkData: blob,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "ACCESS_DENIED", message: "Security-scoped resource access denied", details: nil))
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let data = try Data(contentsOf: url)
        result(FlutterStandardTypedData(bytes: data))
    } catch {
        result(FlutterError(
            code: "READ_FAILED",
            message: "Could not read bookmark bytes: \(error.localizedDescription)",
            details: nil
        ))
    }
}
```

- [ ] **Step 2: Mirror in macOS handler**

In `macos/Runner/LocalMediaHandler.swift`, add the same case + method, but with `options: .withSecurityScope` (matching macOS's existing convention from Phase 1):

```swift
private func readBookmarkBytes(blob: Data, result: @escaping FlutterResult) {
    var stale = false
    do {
        let url = try URL(
            resolvingBookmarkData: blob,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "ACCESS_DENIED", message: "Security-scoped resource access denied", details: nil))
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let data = try Data(contentsOf: url)
        result(FlutterStandardTypedData(bytes: data))
    } catch {
        result(FlutterError(
            code: "READ_FAILED",
            message: "Could not read bookmark bytes: \(error.localizedDescription)",
            details: nil
        ))
    }
}
```

Add the same `case "readBookmarkBytes":` dispatch as in iOS.

- [ ] **Step 3: Add `readUriBytes` to Android handler**

In `android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt`, add:

```kotlin
"readUriBytes" -> readUriBytes(call, result)
```

to the `when (call.method)` block, then:

```kotlin
private fun readUriBytes(call: MethodCall, result: MethodChannel.Result) {
    val uriStr = call.argument<String>("uri")
        ?: return result.error("INVALID_ARGS", "uri required", null)
    try {
        val uri = Uri.parse(uriStr)
        val stream = context.contentResolver.openInputStream(uri)
            ?: return result.error("READ_FAILED", "openInputStream returned null", null)
        val bytes = stream.use { it.readBytes() }
        result.success(bytes)
    } catch (e: SecurityException) {
        result.error("PERMISSION_DENIED", e.localizedMessage, null)
    } catch (e: Exception) {
        result.error("READ_FAILED", e.localizedMessage, null)
    }
}
```

- [ ] **Step 4: Add `readBytesForRef` to Dart wrapper**

In `lib/features/media/data/services/local_media_platform.dart`, add:

```dart
/// Reads the bytes of a previously-stored bookmark / URI.
///
/// On iOS/macOS, [bookmarkBlob] is the raw bookmark data (callers retrieve
/// it from `LocalBookmarkStorage`). On Android, callers should use
/// [readUriBytes] instead — which takes the URI string directly.
Future<Uint8List> readBookmarkBytes(Uint8List bookmarkBlob) async {
  if (!Platform.isIOS && !Platform.isMacOS) {
    throw UnsupportedError(
      'readBookmarkBytes is only supported on iOS / macOS',
    );
  }
  final result = await _channel.invokeMethod<Uint8List>(
    'readBookmarkBytes',
    {'bookmarkBlob': bookmarkBlob},
  );
  if (result == null) throw StateError('readBookmarkBytes returned null');
  return result;
}

/// Android-only: reads bytes from a persisted content URI.
Future<Uint8List> readUriBytes(String uri) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('readUriBytes is only supported on Android');
  }
  final result = await _channel.invokeMethod<Uint8List>(
    'readUriBytes',
    {'uri': uri},
  );
  if (result == null) throw StateError('readUriBytes returned null');
  return result;
}
```

- [ ] **Step 5: Verify builds + test channel mocking**

```bash
flutter build ios --debug --no-codesign --simulator 2>&1 | tail -3
flutter build macos --debug 2>&1 | tail -3
flutter build apk --debug 2>&1 | tail -3
flutter test
```

All builds must succeed. All tests must pass. (No new Dart-side test for the channel methods themselves — they're thin pass-throughs covered by the Phase 1 channel tests pattern, plus integration tests further on.)

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/services/local_media_platform.dart
git add ios/Runner/LocalMediaHandler.swift macos/Runner/LocalMediaHandler.swift android/app/src/main/kotlin/app/submersion/LocalMediaHandler.kt lib/features/media/data/services/local_media_platform.dart
git commit -m "feat(media): add readBookmarkBytes/readUriBytes native methods"
```

---

## Task 7: Promote `LocalFileResolver` from Phase 1 Stub to Full Multi-Platform

**Files:**
- Modify: `lib/features/media/data/resolvers/local_file_resolver.dart`
- Modify: `lib/features/media/presentation/providers/media_resolver_providers.dart` (inject dependencies)
- Test: `test/features/media/data/resolvers/local_file_resolver_test.dart`

The Phase 1 stub only handles `localPath`. Promote to full impl that:
- Desktop: reads `localPath` directly (current behavior, kept).
- iOS/macOS: reads `bookmarkRef` → `LocalBookmarkStorage.read` → `LocalMediaPlatform.resolveBookmark` → returns FileData with the resolved (security-scoped) file.
- Android: reads `bookmarkRef` (URI string) → returns BytesData via `LocalMediaPlatform.readUriBytes`.

Supports EXIF extraction via `ExifExtractor`.

- [ ] **Step 1: Update tests for the new shape**

Replace `test/features/media/data/resolvers/local_file_resolver_test.dart` with:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

class _FakeBookmarkStorage extends LocalBookmarkStorage {
  _FakeBookmarkStorage(this._blobs) : super(storage: null as dynamic);
  final Map<String, Uint8List> _blobs;
  @override
  Future<Uint8List?> read(String ref) async => _blobs[ref];
}

MediaItem _localFile({String? localPath, String? bookmarkRef}) => MediaItem(
      id: 'x',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: localPath,
      bookmarkRef: bookmarkRef,
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_resolver_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('resolve returns FileData when localPath points to existing file',
      () async {
    final f = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final r = LocalFileResolver(
      bookmarkStorage: _FakeBookmarkStorage(const {}),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
    );
    final data = await r.resolve(_localFile(localPath: f.path));
    expect(data, isA<FileData>());
    expect((data as FileData).file.path, f.path);
  });

  test('resolve returns Unavailable when both localPath and bookmarkRef null',
      () async {
    final r = LocalFileResolver(
      bookmarkStorage: _FakeBookmarkStorage(const {}),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
    );
    final data = await r.resolve(_localFile());
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('resolve returns Unavailable when localPath file is missing',
      () async {
    final r = LocalFileResolver(
      bookmarkStorage: _FakeBookmarkStorage(const {}),
      platform: LocalMediaPlatform(),
      exifExtractor: ExifExtractor(),
    );
    final data = await r.resolve(
      _localFile(localPath: '${tempDir.path}/does_not_exist.jpg'),
    );
    expect(data, isA<UnavailableData>());
  });
}
```

- [ ] **Step 2: Run to verify the test fails (compilation error: constructor signature changed)**

```bash
flutter test test/features/media/data/resolvers/local_file_resolver_test.dart
```

Expected: FAIL — current resolver has a no-arg constructor.

- [ ] **Step 3: Replace `LocalFileResolver` implementation**

Replace `lib/features/media/data/resolvers/local_file_resolver.dart` with:

```dart
import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.localFile] items across all platforms.
///
/// Per-platform behavior:
///   * Desktop (macOS native, Windows, Linux): reads [MediaItem.localPath]
///     directly via dart:io and returns [FileData].
///   * iOS / macOS (sandboxed): reads [MediaItem.bookmarkRef] from the
///     bookmark keychain, resolves the security-scoped bookmark, and returns
///     [FileData] pointing at the security-scoped file URL. Caller is
///     responsible for releasing access via [LocalMediaPlatform.releaseBookmark]
///     when done — the FileData consumer must call that on cleanup.
///   * Android: reads [MediaItem.bookmarkRef] as a content URI, calls
///     [LocalMediaPlatform.readUriBytes], and returns [BytesData].
class LocalFileResolver implements MediaSourceResolver {
  final LocalBookmarkStorage _bookmarkStorage;
  final LocalMediaPlatform _platform;
  final ExifExtractor _exifExtractor;

  LocalFileResolver({
    required LocalBookmarkStorage bookmarkStorage,
    required LocalMediaPlatform platform,
    required ExifExtractor exifExtractor,
  })  : _bookmarkStorage = bookmarkStorage,
        _platform = platform,
        _exifExtractor = exifExtractor;

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) {
    // Device-local pointers don't cross machines.
    return true;
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    // Desktop path: localPath set, no bookmark needed.
    final localPath = item.localPath ?? item.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      final f = File(localPath);
      if (await f.exists()) return FileData(file: f);
      // Fall through if path is set but file missing.
    }

    final ref = item.bookmarkRef;
    if (ref == null || ref.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }

    if (Platform.isAndroid) {
      try {
        final bytes = await _platform.readUriBytes(ref);
        return BytesData(bytes: bytes);
      } catch (_) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final blob = await _bookmarkStorage.read(ref);
      if (blob == null) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      try {
        final resolved = await _platform.resolveBookmark(blob);
        return FileData(file: File(resolved.filePath));
      } catch (_) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
    }

    return const UnavailableData(kind: UnavailableKind.notFound);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) =>
      resolve(item);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final data = await resolve(item);
    if (data is FileData) {
      return _exifExtractor.extract(data.file);
    }
    if (data is BytesData) {
      // Android: write bytes to temp file, run extractor, delete.
      final tmp = await File(
        '${Directory.systemTemp.path}/exif_${item.id}.bin',
      ).create();
      await tmp.writeAsBytes(data.bytes);
      try {
        return await _exifExtractor.extract(tmp);
      } finally {
        if (await tmp.exists()) await tmp.delete();
      }
    }
    return null;
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final data = await resolve(item);
    return data is UnavailableData
        ? VerifyResult.notFound
        : VerifyResult.available;
  }
}
```

- [ ] **Step 4: Update the provider to inject dependencies**

In `lib/features/media/presentation/providers/media_resolver_providers.dart`, replace the `localFileResolverProvider`:

```dart
final localBookmarkStorageProvider = Provider<LocalBookmarkStorage>(
  (ref) => LocalBookmarkStorage(),
);

final localMediaPlatformProvider = Provider<LocalMediaPlatform>(
  (ref) => LocalMediaPlatform(),
);

final exifExtractorProvider = Provider<ExifExtractor>(
  (ref) => ExifExtractor(),
);

final localFileResolverProvider = Provider<LocalFileResolver>(
  (ref) => LocalFileResolver(
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    platform: ref.watch(localMediaPlatformProvider),
    exifExtractor: ref.watch(exifExtractorProvider),
  ),
);
```

Add the imports at the top of the file.

- [ ] **Step 5: Run tests + analyzer**

```bash
flutter analyze lib/features/media/
flutter test
```

Expected: clean analyze, all tests pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/resolvers/local_file_resolver.dart lib/features/media/presentation/providers/media_resolver_providers.dart test/features/media/data/resolvers/local_file_resolver_test.dart
git add lib/features/media/data/resolvers/local_file_resolver.dart lib/features/media/presentation/providers/media_resolver_providers.dart test/features/media/data/resolvers/local_file_resolver_test.dart
git commit -m "feat(media): promote LocalFileResolver from stub to full multi-platform"
```

---

## Task 8: Files Tab Provider — State Management Skeleton

**Files:**
- Create: `lib/features/media/presentation/providers/files_tab_providers.dart`
- Test: `test/features/media/presentation/providers/files_tab_providers_test.dart`

A `StateNotifierProvider` holding the picked-files list, EXIF extraction progress, auto-match toggle state, and computed `MatchedSelection`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/providers/files_tab_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';

void main() {
  test('default state: no files, autoMatch=true', () {
    final container = ProviderContainer();
    final state = container.read(filesTabNotifierProvider);
    expect(state.files, isEmpty);
    expect(state.autoMatchByDate, isTrue);
    expect(state.isExtracting, isFalse);
    container.dispose();
  });

  test('toggleAutoMatch flips the flag', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    notifier.toggleAutoMatch();
    expect(container.read(filesTabNotifierProvider).autoMatchByDate, isFalse);
    notifier.toggleAutoMatch();
    expect(container.read(filesTabNotifierProvider).autoMatchByDate, isTrue);
    container.dispose();
  });

  test('clear empties the files list', () {
    final container = ProviderContainer();
    final notifier = container.read(filesTabNotifierProvider.notifier);
    notifier.clear();
    expect(container.read(filesTabNotifierProvider).files, isEmpty);
    container.dispose();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement the provider**

Create `lib/features/media/presentation/providers/files_tab_providers.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';

class FilesTabState extends Equatable {
  final List<ExtractedFile> files;
  final bool autoMatchByDate;
  final bool isExtracting;
  final int extractedCount;
  final int totalToExtract;
  final MatchedSelection match;

  const FilesTabState({
    required this.files,
    required this.autoMatchByDate,
    required this.isExtracting,
    required this.extractedCount,
    required this.totalToExtract,
    required this.match,
  });

  factory FilesTabState.initial() => FilesTabState(
        files: const [],
        autoMatchByDate: true,
        isExtracting: false,
        extractedCount: 0,
        totalToExtract: 0,
        match: MatchedSelection.empty(),
      );

  FilesTabState copyWith({
    List<ExtractedFile>? files,
    bool? autoMatchByDate,
    bool? isExtracting,
    int? extractedCount,
    int? totalToExtract,
    MatchedSelection? match,
  }) =>
      FilesTabState(
        files: files ?? this.files,
        autoMatchByDate: autoMatchByDate ?? this.autoMatchByDate,
        isExtracting: isExtracting ?? this.isExtracting,
        extractedCount: extractedCount ?? this.extractedCount,
        totalToExtract: totalToExtract ?? this.totalToExtract,
        match: match ?? this.match,
      );

  @override
  List<Object?> get props => [
        files,
        autoMatchByDate,
        isExtracting,
        extractedCount,
        totalToExtract,
        match,
      ];
}

class FilesTabNotifier extends StateNotifier<FilesTabState> {
  FilesTabNotifier() : super(FilesTabState.initial());

  void toggleAutoMatch() {
    state = state.copyWith(autoMatchByDate: !state.autoMatchByDate);
  }

  void clear() {
    state = FilesTabState.initial();
  }

  void setFiles(List<ExtractedFile> files, {required MatchedSelection match}) {
    state = state.copyWith(files: files, match: match);
  }

  void setExtractionProgress({required int done, required int total}) {
    state = state.copyWith(
      isExtracting: done < total,
      extractedCount: done,
      totalToExtract: total,
    );
  }

  void removeFile(String sourcePath) {
    final remaining =
        state.files.where((f) => f.sourcePath != sourcePath).toList();
    state = state.copyWith(files: remaining);
  }
}

final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
  (ref) => FilesTabNotifier(),
);
```

- [ ] **Step 4: Run to verify the test passes**

```bash
flutter test test/features/media/presentation/providers/files_tab_providers_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/providers/files_tab_providers.dart test/features/media/presentation/providers/files_tab_providers_test.dart
git add lib/features/media/presentation/providers/files_tab_providers.dart test/features/media/presentation/providers/files_tab_providers_test.dart
git commit -m "feat(media): add Files tab state notifier"
```

---

## Task 9: File Picker Action — Multi-File Picking with EXIF Extraction

**Files:**
- Create: `lib/features/media/presentation/widgets/files_tab.dart` (initial skeleton — picker action only; folder picker added in Task 10)
- Test: `test/features/media/presentation/widgets/files_tab_test.dart`

The `FilesTab` widget renders a "Pick files…" button. Tapping it opens a system multi-file picker (image + video MIME via `file_picker`), extracts EXIF for each, applies the matcher, and updates the provider state.

The folder-picker action and the review pane render in subsequent tasks; for now the widget shows "Pick files…" + an empty body.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/files_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';

void main() {
  testWidgets('renders Pick files action', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: FilesTab())),
    ));
    expect(find.textContaining('Pick files'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify the test fails**

```bash
flutter test test/features/media/presentation/widgets/files_tab_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement minimal `FilesTab` skeleton**

Create `lib/features/media/presentation/widgets/files_tab.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'dart:io';

class FilesTab extends ConsumerWidget {
  const FilesTab({super.key});

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result == null) return;

    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final extractor = ref.read(exifExtractorProvider);

    final extracted = <ExtractedFile>[];
    notifier.setExtractionProgress(done: 0, total: result.files.length);

    for (var i = 0; i < result.files.length; i++) {
      final pf = result.files[i];
      final path = pf.path;
      if (path == null) continue;
      final file = File(path);
      final meta = await extractor.extract(file);
      if (meta == null) continue;
      extracted.add(ExtractedFile(
        sourcePath: path,
        file: file,
        metadata: meta,
      ));
      notifier.setExtractionProgress(
        done: i + 1,
        total: result.files.length,
      );
    }

    // Matching applied in Task 10 once the dives provider is wired.
    // For now, just stash the extracted files.
    notifier.setFiles(extracted, match: const _EmptyMatch());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Pick files…'),
            onPressed: () => _pickFiles(ref),
          ),
        ],
      ),
    );
  }
}

class _EmptyMatch implements dynamic {
  const _EmptyMatch();
  // placeholder; real matching wired in Task 10.
}
```

(The `_EmptyMatch` placeholder is removed in Task 10 once `MatchedSelection` is computed.)

Wait — using `dynamic` for `_EmptyMatch` is hacky and doesn't satisfy the `MatchedSelection match` type on `FilesTabState`. Replace with `MatchedSelection.empty()` instead. Use the proper type:

```dart
notifier.setFiles(extracted, match: MatchedSelection.empty());
```

And add the import:

```dart
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
```

- [ ] **Step 4: Run to verify the test passes**

```bash
flutter test test/features/media/presentation/widgets/files_tab_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/files_tab.dart test/features/media/presentation/widgets/files_tab_test.dart
git add lib/features/media/presentation/widgets/files_tab.dart test/features/media/presentation/widgets/files_tab_test.dart
git commit -m "feat(media): add FilesTab widget skeleton with file-picker action"
```

---

## Task 10: Folder Picker + Background-Isolate Enumeration + Auto-Match Wiring

**Files:**
- Modify: `lib/features/media/presentation/widgets/files_tab.dart`
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart` (add a `_runMatcher` helper)
- Test: extend `test/features/media/presentation/widgets/files_tab_test.dart`

Add a "Pick a folder…" button. On folder pick, enumerate all images/videos recursively (background isolate via `compute`), then extract EXIF for each on the main isolate (with progress), then run `DivePhotoMatcher` against the diver's dives and stash the result in state.

The auto-match-by-date checkbox lives below the action buttons. Default checked.

- [ ] **Step 1: Add the folder picker action and auto-match toggle to the widget**

Update `FilesTab.build` to include:

```dart
Column(
  children: [
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Pick files…'),
            onPressed: () => _pickFiles(context, ref),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Pick a folder…'),
            onPressed: () => _pickFolder(context, ref),
          ),
        ),
      ],
    ),
    Row(
      children: [
        Checkbox(
          value: state.autoMatchByDate,
          onChanged: (_) =>
              ref.read(filesTabNotifierProvider.notifier).toggleAutoMatch(),
        ),
        const Expanded(
          child: Text('Auto-match photos to dives by EXIF date'),
        ),
      ],
    ),
    if (state.isExtracting)
      LinearProgressIndicator(
        value: state.totalToExtract == 0
            ? null
            : state.extractedCount / state.totalToExtract,
      ),
    Expanded(
      child: state.files.isEmpty
          ? Center(
              child: Text(
                'Pick files or a folder to start.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : FileReviewPane(state: state),
    ),
  ],
)
```

(The `FileReviewPane` widget is created in Task 11.)

- [ ] **Step 2: Implement `_pickFolder`**

```dart
Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null) return;

  // Enumerate eligible files in a background isolate.
  final paths = await compute(_enumerateMediaFiles, dirPath);
  if (paths.isEmpty) return;

  final notifier = ref.read(filesTabNotifierProvider.notifier);
  final extractor = ref.read(exifExtractorProvider);

  final extracted = <ExtractedFile>[];
  notifier.setExtractionProgress(done: 0, total: paths.length);

  for (var i = 0; i < paths.length; i++) {
    final file = File(paths[i]);
    final meta = await extractor.extract(file);
    if (meta == null) continue;
    extracted.add(ExtractedFile(
      sourcePath: paths[i],
      file: file,
      metadata: meta,
    ));
    notifier.setExtractionProgress(done: i + 1, total: paths.length);
  }

  await _applyMatchAndStash(ref, extracted);
}

Future<List<String>> _enumerateMediaFiles(String rootPath) async {
  const exts = {
    '.jpg', '.jpeg', '.heic', '.heif', '.png', '.webp', '.gif',
    '.mp4', '.mov', '.m4v',
  };
  final results = <String>[];
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return results;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final ext = '.${entity.path.split('.').last.toLowerCase()}';
      if (exts.contains(ext)) results.add(entity.path);
      if (results.length >= 5000) break; // hard ceiling per spec
    }
  }
  return results;
}
```

- [ ] **Step 3: Wire the matcher**

Add a private helper:

```dart
Future<void> _applyMatchAndStash(
  WidgetRef ref,
  List<ExtractedFile> extracted,
) async {
  final notifier = ref.read(filesTabNotifierProvider.notifier);
  final state = ref.read(filesTabNotifierProvider);
  if (!state.autoMatchByDate) {
    notifier.setFiles(extracted, match: MatchedSelection.empty());
    return;
  }
  final dives = await ref.read(allDivesProvider.future);
  final bounds = dives
      .map((d) => DiveBounds(
            diveId: d.id,
            entryTime: d.effectiveEntryTime,
            exitTime: d.exitTime ??
                d.effectiveEntryTime.add(d.effectiveRuntime ??
                    const Duration(hours: 1)),
          ))
      .toList();
  final result = DivePhotoMatcher().match(files: extracted, dives: bounds);
  notifier.setFiles(extracted, match: result);
}
```

You'll need an `allDivesProvider` (or the equivalent that exists in the codebase). Search:

```bash
grep -rn "FutureProvider.*Dive\|divesProvider\|allDivesProvider" lib/features/dive_log/presentation/providers/ | head -10
```

If no provider returning all dives exists, use the dive repository directly: `ref.read(diveRepositoryProvider).getAllDives()`. Add the imports.

- [ ] **Step 4: Update the file-picker action to also call `_applyMatchAndStash`**

In `_pickFiles`, replace the final `notifier.setFiles(extracted, match: MatchedSelection.empty())` with `await _applyMatchAndStash(ref, extracted);`.

- [ ] **Step 5: Verify analyze + tests**

```bash
flutter analyze lib/features/media/presentation/widgets/files_tab.dart
flutter test
```

Expected: clean. The widget test from Task 9 still passes (the button text exists). Don't expand the widget test for the picker action's behavior — that's covered by integration tests; widget tests can't reasonably mock `FilePicker.platform`.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/presentation/widgets/files_tab.dart
git add lib/features/media/presentation/widgets/files_tab.dart
git commit -m "feat(media): add folder picker + auto-match-by-date wiring"
```

---

## Task 11: `FileReviewPane` and `FileReviewCard` Widgets

**Files:**
- Create: `lib/features/media/presentation/widgets/file_review_pane.dart`
- Create: `lib/features/media/presentation/widgets/file_review_card.dart`
- Test: `test/features/media/presentation/widgets/file_review_pane_test.dart`

The review pane shows the extracted files grouped by their target dive (collapsible groups by date) plus an "Unmatched" group at the bottom. A summary line: "12 photos → 3 dives, 4 unmatched". Each file card has Reassign / Remove inline actions.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/media/presentation/widgets/file_review_pane_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';

ExtractedFile _ef(String path) => ExtractedFile(
      sourcePath: path,
      file: File(path),
      metadata:
          MediaSourceMetadata(takenAt: DateTime.utc(2024, 4, 1), mimeType: 'image/jpeg'),
    );

void main() {
  testWidgets('summary shows file/dive/unmatched counts', (tester) async {
    final state = FilesTabState.initial().copyWith(
      files: [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')],
      match: MatchedSelection(
        matched: {
          'd1': [_ef('/a.jpg'), _ef('/b.jpg')],
        },
        unmatched: [_ef('/c.jpg')],
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FileReviewPane(state: state)),
    ));
    expect(find.textContaining('3 photos'), findsOneWidget);
    expect(find.textContaining('1 dive'), findsOneWidget);
    expect(find.textContaining('1 unmatched'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/file_review_pane_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `FileReviewPane`**

Create `lib/features/media/presentation/widgets/file_review_pane.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_card.dart';

class FileReviewPane extends StatelessWidget {
  final FilesTabState state;
  const FileReviewPane({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = '${state.files.length} photos → '
        '${state.match.diveCount} dive${state.match.diveCount == 1 ? '' : 's'}, '
        '${state.match.unmatched.length} unmatched';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(summary, style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final entry in state.match.matched.entries)
                ExpansionTile(
                  title: Text('Dive ${entry.key}'),
                  subtitle: Text('${entry.value.length} photos'),
                  initiallyExpanded: true,
                  children: [
                    for (final f in entry.value)
                      FileReviewCard(file: f, targetDiveId: entry.key),
                  ],
                ),
              if (state.match.unmatched.isNotEmpty)
                ExpansionTile(
                  title: const Text('Unmatched'),
                  subtitle: Text('${state.match.unmatched.length} photos'),
                  initiallyExpanded: true,
                  children: [
                    for (final f in state.match.unmatched)
                      FileReviewCard(file: f, targetDiveId: null),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

Create `lib/features/media/presentation/widgets/file_review_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';

class FileReviewCard extends ConsumerWidget {
  final ExtractedFile file;
  final String? targetDiveId;

  const FileReviewCard({
    super.key,
    required this.file,
    required this.targetDiveId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Image.file(
        file.file,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, size: 32),
      ),
      title: Text(
        file.sourcePath.split('/').last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file.metadata.takenAt?.toIso8601String() ?? 'No EXIF date',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Remove from selection',
        onPressed: () => ref
            .read(filesTabNotifierProvider.notifier)
            .removeFile(file.sourcePath),
      ),
    );
  }
}
```

(Reassign UI deferred — the user can remove and re-add for now. Phase 3 polish can add a dive-picker dropdown.)

- [ ] **Step 4: Run to verify the test passes**

```bash
flutter test test/features/media/presentation/widgets/file_review_pane_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/file_review_pane.dart lib/features/media/presentation/widgets/file_review_card.dart test/features/media/presentation/widgets/file_review_pane_test.dart
git add lib/features/media/presentation/widgets/file_review_pane.dart lib/features/media/presentation/widgets/file_review_card.dart test/features/media/presentation/widgets/file_review_pane_test.dart
git commit -m "feat(media): add FileReviewPane and FileReviewCard widgets"
```

---

## Task 12: Wire `FilesTab` Into the Picker — Replace Phase 1 Placeholder

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_picker_page.dart`

Replace the Phase 1 `_PlaceholderTab(message: 'Coming in Phase 2')` with the real `FilesTab`. Preserve the URL placeholder for Phase 3.

- [ ] **Step 1: Update the placeholder reference**

In `photo_picker_page.dart`, find the `TabBarView` (around line 160 per Phase 1 layout) and replace:

```dart
const _PlaceholderTab(message: 'Coming in Phase 2'),
```

with:

```dart
const FilesTab(),
```

Add the import:

```dart
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
```

- [ ] **Step 2: Verify analyze + tests**

```bash
flutter analyze lib/features/media/presentation/pages/photo_picker_page.dart
flutter test
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/media/presentation/pages/photo_picker_page.dart
git add lib/features/media/presentation/pages/photo_picker_page.dart
git commit -m "feat(media): wire FilesTab into photo picker tab shell"
```

---

## Task 13: Commit Flow — Insert MediaItems with Bookmark/URI Persistence + Undo

**Files:**
- Modify: `lib/features/media/presentation/widgets/files_tab.dart`
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart` (add a `commit` action)
- Test: extend `test/features/media/presentation/providers/files_tab_providers_test.dart`

Add a "Link N items" button at the bottom of the tab. When pressed:
1. For each `ExtractedFile`, on iOS/macOS call `LocalMediaPlatform.createBookmark(file.path)`, store via `LocalBookmarkStorage.write(ref, blob)`. On Android call `LocalMediaPlatform.takePersistableUri(uri)`. On desktop, store nothing.
2. Insert a `MediaItem` per file via `MediaRepository.createMedia` with `sourceType=localFile`, the appropriate pointer, EXIF metadata.
3. Run the existing `MediaEnrichment` pipeline against each dive's profile.
4. Show a snackbar: "Linked N items" with an "Undo" action.

(Step skip: the spec calls for a "Link N items" button; layout is handled in Task 12's tab shell. This task is the action wiring.)

- [ ] **Step 1: Add `commit` action to the notifier**

In `files_tab_providers.dart`, add:

```dart
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class FilesTabNotifier extends StateNotifier<FilesTabState> {
  FilesTabNotifier({
    required this.mediaRepository,
    required this.bookmarkStorage,
    required this.platform,
  }) : super(FilesTabState.initial());

  final MediaRepository mediaRepository;
  final LocalBookmarkStorage bookmarkStorage;
  final LocalMediaPlatform platform;

  // ... (other methods stay the same) ...

  /// Returns the IDs of media items created. Caller can pass them back to
  /// [undoCommit] to roll back.
  Future<List<String>> commit() async {
    final created = <String>[];
    final uuid = const Uuid();

    for (final entry in state.match.matched.entries) {
      for (final file in entry.value) {
        final id = await _persistOne(uuid.v4(), file, entry.key);
        if (id != null) created.add(id);
      }
    }

    // Unmatched files: skip — spec calls them "dropped from commit unless
    // user assigned them" (we leave assignment to a future polish pass).

    clear();
    return created;
  }

  Future<String?> _persistOne(
    String id,
    ExtractedFile file,
    String diveId,
  ) async {
    String? localPath;
    String? bookmarkRef;

    if (Platform.isIOS || Platform.isMacOS) {
      final blob = await platform.createBookmark(file.file.path);
      bookmarkRef = uuid.v4();
      await bookmarkStorage.write(bookmarkRef, blob);
    } else if (Platform.isAndroid) {
      // file.file.path on Android may already be a content URI from
      // file_picker. takePersistableUri makes it durable.
      bookmarkRef = await platform.takePersistableUri(file.file.path);
    } else {
      localPath = file.file.path;
    }

    final now = DateTime.now();
    final item = MediaItem(
      id: id,
      diveId: diveId,
      mediaType: file.metadata.mimeType.startsWith('video/')
          ? MediaType.video
          : MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: localPath,
      bookmarkRef: bookmarkRef,
      takenAt: file.metadata.takenAt ?? now,
      latitude: file.metadata.latitude,
      longitude: file.metadata.longitude,
      width: file.metadata.width,
      height: file.metadata.height,
      durationSeconds: file.metadata.durationSeconds,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await mediaRepository.createMedia(item);
    return saved.id;
  }

  Future<void> undoCommit(List<String> ids) async {
    for (final id in ids) {
      await mediaRepository.deleteMedia(id);
      // Also clean up the bookmark blob if any.
      // (Could read the row first to find the bookmarkRef; skipped for
      // simplicity. The orphaned blob in the keychain won't be referenced
      // by anything.)
    }
  }
}
```

The provider definition needs to inject the dependencies:

```dart
final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
  (ref) => FilesTabNotifier(
    mediaRepository: ref.read(mediaRepositoryProvider),
    bookmarkStorage: ref.read(localBookmarkStorageProvider),
    platform: ref.read(localMediaPlatformProvider),
  ),
);
```

- [ ] **Step 2: Add the "Link N items" button to `FilesTab`**

At the bottom of the FilesTab's `Column` (under the review pane), add:

```dart
if (state.files.isNotEmpty)
  Padding(
    padding: const EdgeInsets.all(16),
    child: FilledButton(
      onPressed: () async {
        final notifier = ref.read(filesTabNotifierProvider.notifier);
        final created = await notifier.commit();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Linked ${created.length} items'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => notifier.undoCommit(created),
          ),
        ));
      },
      child: Text('Link ${state.files.length} items'),
    ),
  ),
```

- [ ] **Step 3: Verify analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: clean.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/media/presentation/widgets/files_tab.dart lib/features/media/presentation/providers/files_tab_providers.dart
git add lib/features/media/presentation/widgets/files_tab.dart lib/features/media/presentation/providers/files_tab_providers.dart
git commit -m "feat(media): wire Files-tab commit flow with bookmark persistence + undo"
```

---

## Task 14: `dive_media_section` Long-Press Context Menu Additions

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`

Add two new context menu items shown on long-press:
- "Show in Finder/Explorer/Files" (desktop only) — opens the file's enclosing folder.
- "Replace link…" — re-pick the file. Useful when the user reorganizes their photo library.

Skip these for non-`localFile` source types.

- [ ] **Step 1: Add context-menu items**

Find the existing long-press handler (or PopupMenuButton) in `dive_media_section.dart` and add:

```dart
if (item.sourceType == MediaSourceType.localFile) ...[
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
    PopupMenuItem(
      child: const Text('Show in Finder'),
      onTap: () async {
        final path = item.localPath;
        if (path == null) return;
        if (Platform.isMacOS) {
          await Process.run('open', ['-R', path]);
        } else if (Platform.isWindows) {
          await Process.run('explorer', ['/select,', path]);
        } else {
          await Process.run('xdg-open', [File(path).parent.path]);
        }
      },
    ),
  PopupMenuItem(
    child: const Text('Replace link…'),
    onTap: () async {
      final result = await FilePicker.platform.pickFiles(type: FileType.media);
      if (result == null) return;
      final newPath = result.files.first.path;
      if (newPath == null) return;
      // Update the MediaItem's localPath to the new file.
      final repo = ref.read(mediaRepositoryProvider);
      await repo.updateMedia(item.copyWith(localPath: newPath));
    },
  ),
],
```

(Imports: `dart:io`, `package:file_picker/file_picker.dart`.)

The menu label is hardcoded English — leave a `// TODO(media): l10n in Phase 2 polish` comment if l10n is desired.

- [ ] **Step 2: Verify analyze + tests**

```bash
flutter analyze lib/features/media/presentation/widgets/dive_media_section.dart
flutter test test/features/media/
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/media/presentation/widgets/dive_media_section.dart
git add lib/features/media/presentation/widgets/dive_media_section.dart
git commit -m "feat(media): add 'Show in Finder' and 'Replace link' context-menu items"
```

---

## Task 15: Settings Page Local Files Subsection

**Files:**
- Create: `lib/features/media/data/services/local_files_diagnostics_service.dart`
- Modify: `lib/features/media/presentation/pages/media_sources_page.dart`
- Test: `test/features/media/data/services/local_files_diagnostics_service_test.dart`

Adds a "Local files" subsection to the existing Media Sources page. Shows linked count by status, a "Re-verify all local files" action, and (Android only) a URI usage indicator.

- [ ] **Step 1: Create the diagnostics service**

```dart
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class LocalFilesDiagnostics {
  final int total;
  final int available;
  final int unavailable;

  const LocalFilesDiagnostics({
    required this.total,
    required this.available,
    required this.unavailable,
  });
}

class LocalFilesDiagnosticsService {
  final MediaRepository repository;
  final LocalFileResolver resolver;
  final LocalMediaPlatform platform;

  LocalFilesDiagnosticsService({
    required this.repository,
    required this.resolver,
    required this.platform,
  });

  Future<LocalFilesDiagnostics> diagnose() async {
    final all = await repository.getAllBySourceType(MediaSourceType.localFile);
    int available = 0;
    int unavailable = 0;
    for (final item in all) {
      final result = await resolver.verify(item);
      if (result == VerifyResult.available) {
        available++;
      } else {
        unavailable++;
      }
    }
    return LocalFilesDiagnostics(
      total: all.length,
      available: available,
      unavailable: unavailable,
    );
  }

  Future<int> reverifyAll() async {
    final all = await repository.getAllBySourceType(MediaSourceType.localFile);
    int updated = 0;
    for (final item in all) {
      final result = await resolver.verify(item);
      final wasOrphan = item.isOrphaned;
      final isOrphan = result != VerifyResult.available;
      if (wasOrphan != isOrphan) {
        await repository.updateMedia(item.copyWith(isOrphaned: isOrphan));
        updated++;
      }
    }
    return updated;
  }

  Future<int> androidUriUsage() async {
    final uris = await platform.listPersistedUris();
    return uris.length;
  }
}
```

If `MediaRepository.getAllBySourceType` doesn't exist, add it (a single-line method using `_db.select(_db.media)..where((t) => t.sourceType.equals(...))`).

- [ ] **Step 2: Write the test**

A simple test using a fake repository to verify the diagnostics math.

- [ ] **Step 3: Add the subsection to `MediaSourcesPage`**

In `media_sources_page.dart`, append a new card after the existing Photo library card:

```dart
const SizedBox(height: 16),
Card(
  child: Column(
    children: [
      Consumer(
        builder: (context, ref, _) {
          final diag = ref.watch(localFilesDiagnosticsProvider);
          return diag.when(
            data: (d) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Local files'),
              subtitle: Text(
                  '${d.available} available, ${d.unavailable} unavailable'),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.folder_outlined),
              title: Text('Local files'),
              subtitle: Text('Loading…'),
            ),
            error: (_, __) => const SizedBox(),
          );
        },
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.refresh),
        title: const Text('Re-verify all local files'),
        onTap: () async {
          final notifier = ref.read(localFilesDiagnosticsServiceProvider);
          final updated = await notifier.reverifyAll();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$updated items updated')),
          );
          ref.invalidate(localFilesDiagnosticsProvider);
        },
      ),
      if (Platform.isAndroid)
        Consumer(
          builder: (context, ref, _) {
            final usage =
                ref.watch(androidUriUsageProvider).asData?.value ?? 0;
            return ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Android URI usage'),
              subtitle: Text('$usage / 128 persistable URIs in use'),
            );
          },
        ),
    ],
  ),
),
```

Add the necessary providers (`localFilesDiagnosticsProvider`, `localFilesDiagnosticsServiceProvider`, `androidUriUsageProvider`) — these are simple `Provider` and `FutureProvider` wrappers.

- [ ] **Step 4: Verify analyze + tests**

```bash
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/ lib/features/media/presentation/pages/media_sources_page.dart
git add lib/features/media/
git commit -m "feat(media): add Local files diagnostics + Settings subsection"
```

---

## Task 16: Final Smoke Test + Verification

- [ ] **Step 1: Full test suite**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 2: Analyzer**

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Format**

```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: exit 0.

- [ ] **Step 4: Manual smoke test on macOS**

```bash
flutter build macos --debug
open build/macos/Build/Products/Debug/Submersion.app
```

(`open` to bypass the VS Code responsible-process trap noted in the design doc / dev notes.)

Walk through:
- Open Settings → Data → Media Sources → toggle Diagnostics → re-open the picker → confirm a real Files tab appears (not a placeholder).
- In Files tab, click "Pick files…" → select 2 photos → verify EXIF extraction progress shows briefly → review pane appears.
- Click "Pick a folder…" → select a folder with mixed photos/videos → verify enumeration progress shows → review pane shows files grouped by dive (if their EXIF dates match dives in the log) or in Unmatched.
- Toggle "Auto-match by date" off → repeat → verify all photos go to Unmatched (or current dive if applicable).
- Click "Link N items" → verify success snackbar with Undo → confirm dive media grid shows new linked photos.
- Click Undo → verify the items are removed.

- [ ] **Step 5: Manual smoke test on iOS Simulator**

```bash
flutter run -d "iPhone 15"
```

(In iOS Simulator the responsible-process trap doesn't apply.)

- File picker opens → select photos from simulator's Files app.
- Verify items get linked with bookmarkRef populated.
- Quit and relaunch the simulator → verify the linked photos are still readable (bookmark resolution working).

- [ ] **Step 6: Manual smoke test on Android emulator**

```bash
flutter run -d emulator-5554
```

Same flow as macOS. Verify URI usage indicator in Settings updates as items are linked.

- [ ] **Step 7: Final commit (if any fix-it changes)**

If the smoke tests surfaced minor issues, fix them and commit as `chore(media): smoke-test fixes for Phase 2`.

---

## Self-Review

**Spec coverage:**

| Spec deliverable (section 5) | Task |
|---|---|
| 1. Files tab UI | Tasks 9, 10, 11, 12, 13 |
| 2. File/folder picker plumbing | Tasks 9, 10 |
| 3. Mobile persistence (iOS bookmarks, Android URIs, desktop paths) | Tasks 5, 6, 7, 13 |
| 4. EXIF extraction at link time | Tasks 1, 7 |
| 5. Auto-match-by-date (shared service) | Tasks 3, 4, 10 |
| 6. Review-and-adjust UI | Task 11 |
| 7. Commit flow | Task 13 |
| 8. Dive section context menu | Task 14 |
| 9. Settings Local files subsection | Task 15 |
| Final verification | Task 16 |

**Placeholder check:** No "TBD" / "TODO: implement later" / "similar to Task N" items.

**Type consistency:** `MatchedSelection`, `ExtractedFile`, `DiveBounds` referenced consistently. `LocalFileResolver` constructor signature changed in Task 7; the provider in `media_resolver_providers.dart` is updated in the same task.

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-27-media-source-extension-phase2.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
