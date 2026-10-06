# Adjustable Media Upload Quality — Phase A (Photos) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each device choose a per-media-type upload quality level (`Original / High / Balanced / Small`); photos at a non-`Original` level upload a compressed JPEG rendition instead of the original, plus a per-item re-upload override.

**Architecture:** Add a derived `smv1/renditions/<hash>.<ext>` object tier keyed by the original's content hash (not hash-verified), mirroring the existing thumbnail tier. The upload pipeline gains a `MediaCompressor` seam and per-device `MediaStorePolicies` and branches on the level; the resolver gains an `original -> compressed -> thumb` read tier with a freshness check. Video wiring exists but degrades to uploading the original until Phase B (the ffmpeg `submersion_transcoder` plugin) lands.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, `package:image` (photo compression), `shared_preferences` (per-device policy), `flutter gen-l10n` (localization).

**Spec:** `docs/superpowers/specs/2026-07-20-adjustable-media-upload-quality-design.md` (commit 458efa6f343).

## Global Constraints

- Main DB schema version is currently `129`; this plan advances it to `130` (`AppDatabase.currentSchemaVersion`, `lib/core/database/database.dart:2817`). Confirm no other unmerged branch has claimed 130 at execution time; renumber on collision.
- Local cache DB schema version is currently `3`; this plan advances it to `4` (`LocalCacheDatabase`, `lib/core/database/local_cache_database.dart`).
- Media store date columns are `IntColumn` epoch-millis, NOT drift `DateTimeColumn`. Write with `Value(dt.millisecondsSinceEpoch)`; read with `DateTime.fromMillisecondsSinceEpoch(row.col!)`.
- Every stamp/update on `media` MUST replicate the sync trailer: `await _syncRepository.markRecordPending(entityType: 'media', recordId: mediaId, localUpdatedAt: now)` then `SyncEventBus.notifyLocalChange()`.
- `copyWith` uses the `const _undefined = Object();` sentinel (`media_item.dart:478`); nullable params are typed `Object? x = _undefined` and cast back.
- Per-device policy defaults MUST preserve today's behavior: both quality defaults are `original` (no silent re-encoding for existing users).
- New user-facing strings go in ALL 11 `.arb` files under `lib/l10n/arb/` (`app_en.arb` is the template; the other 10 are `ar de es fr he hu it nl pt zh`). After editing, run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` (they are tracked).
- Drift codegen: after editing any `@DataClassName`/table, run `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated `*.g.dart`.
- Patch coverage gate is 80% (`codecov.yml`); the media-store bar for this work is **>= 90%**. `*.g.dart`, `*.freezed.dart`, and `lib/l10n/**` are excluded from coverage.
- All code must pass `dart format .` and `flutter analyze` (info-level lints fail CI) before commit.
- Video is OUT of scope for Phase A: the `VideoTranscoder` interface ships with NO implementation, so a non-`Original` video level falls back to uploading the original.

---

## Test Harness Reference

Two setup blocks are reused across tasks. Copy them verbatim where a task says "use the Pipeline Harness" or "use the Cache Harness."

**Pipeline Harness** (from `test/features/media_store/media_upload_pipeline_test.dart:81-120`):
```dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';
import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

late MediaRepository mediaRepository;
late LocalCacheDatabase cacheDb;
late Directory root;
late InMemoryMediaObjectStore fakeStore;
late MediaCacheStore cache;
late MediaTransferQueueRepository queue;

Future<void> harnessSetUp() async {
  await setUpTestDatabase();
  mediaRepository = MediaRepository();
  cacheDb = LocalCacheDatabase(NativeDatabase.memory());
  root = await Directory.systemTemp.createTemp('quality_test');
  fakeStore = InMemoryMediaObjectStore();
  cache = MediaCacheStore(database: cacheDb, root: root);
  queue = MediaTransferQueueRepository(database: cacheDb);
}

Future<void> harnessTearDown() async {
  await cacheDb.close();
  await root.delete(recursive: true);
  await tearDownTestDatabase();
}
```

**Cache Harness** (from `test/features/media_store/thumbnail_generator_test.dart:21-45`): a `LocalCacheDatabase(NativeDatabase.memory())`, a `Directory.systemTemp.createTemp(...)`, and `MediaCacheStore(database: db, root: root)`; tear down with `db.close()` + `root.delete(recursive: true)`.

**PNG fixture helper** (photos are decodable by `package:image`; from the pipeline test):
```dart
import 'package:image/image.dart' as img;
List<int> pngBytes({int width = 8, int height = 8}) =>
    img.encodePng(img.Image(width: width, height: height));
```

**Commands:**
- Single file: `flutter test test/path/to/file_test.dart`
- Media-store suite: `flutter test test/features/media_store/ test/features/media/data/media_store_resolver_test.dart`
- Analyze/format: `flutter analyze` and `dart format .`
- Coverage (scoped): `flutter test --coverage test/features/media_store/`

---

## Task 1: `MediaUploadQuality` enum + quality presets

**Files:**
- Create: `lib/features/media_store/domain/media_upload_quality.dart`
- Create: `lib/features/media_store/data/quality_presets.dart`
- Test: `test/features/media_store/quality_presets_test.dart`

**Interfaces:**
- Produces: `enum MediaUploadQuality { original, high, balanced, small }`; `PhotoQualityPreset { int maxDimension; int jpegQuality }`; `VideoQualityPreset { int maxHeight; int crf; int audioBitrateKbps }`; `PhotoQualityPreset? photoPresetFor(MediaUploadQuality)`; `VideoQualityPreset? videoPresetFor(MediaUploadQuality)` (both return `null` for `original`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/quality_presets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

void main() {
  test('original has no preset', () {
    expect(photoPresetFor(MediaUploadQuality.original), isNull);
    expect(videoPresetFor(MediaUploadQuality.original), isNull);
  });

  test('photo presets shrink with level', () {
    expect(photoPresetFor(MediaUploadQuality.high)!.maxDimension, 3072);
    expect(photoPresetFor(MediaUploadQuality.balanced)!.maxDimension, 2048);
    expect(photoPresetFor(MediaUploadQuality.small)!.maxDimension, 1280);
    expect(photoPresetFor(MediaUploadQuality.small)!.jpegQuality, 75);
  });

  test('enum round-trips through name', () {
    expect(MediaUploadQuality.values.byName('balanced'),
        MediaUploadQuality.balanced);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/quality_presets_test.dart`
Expected: FAIL (target of URI doesn't exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/media_store/domain/media_upload_quality.dart

/// Per-device, per-media-type upload quality. `original` uploads the
/// untouched file (today's behavior); the others upload a compressed
/// rendition. Persisted by name via [MediaUploadQuality.name].
enum MediaUploadQuality { original, high, balanced, small }
```

```dart
// lib/features/media_store/data/quality_presets.dart
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Photo rendition target: a long-edge ceiling and a JPEG quality.
class PhotoQualityPreset {
  const PhotoQualityPreset({
    required this.maxDimension,
    required this.jpegQuality,
  });
  final int maxDimension;
  final int jpegQuality;
}

/// Video rendition target (consumed in Phase B by the ffmpeg transcoder).
class VideoQualityPreset {
  const VideoQualityPreset({
    required this.maxHeight,
    required this.crf,
    required this.audioBitrateKbps,
  });
  final int maxHeight;
  final int crf;
  final int audioBitrateKbps;
}

const Map<MediaUploadQuality, PhotoQualityPreset> _photo = {
  MediaUploadQuality.high: PhotoQualityPreset(maxDimension: 3072, jpegQuality: 90),
  MediaUploadQuality.balanced: PhotoQualityPreset(maxDimension: 2048, jpegQuality: 85),
  MediaUploadQuality.small: PhotoQualityPreset(maxDimension: 1280, jpegQuality: 75),
};

const Map<MediaUploadQuality, VideoQualityPreset> _video = {
  MediaUploadQuality.high: VideoQualityPreset(maxHeight: 1080, crf: 20, audioBitrateKbps: 128),
  MediaUploadQuality.balanced: VideoQualityPreset(maxHeight: 720, crf: 23, audioBitrateKbps: 128),
  MediaUploadQuality.small: VideoQualityPreset(maxHeight: 480, crf: 26, audioBitrateKbps: 96),
};

PhotoQualityPreset? photoPresetFor(MediaUploadQuality level) => _photo[level];
VideoQualityPreset? videoPresetFor(MediaUploadQuality level) => _video[level];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/quality_presets_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/domain/media_upload_quality.dart lib/features/media_store/data/quality_presets.dart test/features/media_store/quality_presets_test.dart
git commit -m "feat(media-store): add MediaUploadQuality enum and presets"
```

---

## Task 2: `StoreKeys.renditionKey`

**Files:**
- Modify: `lib/core/services/media_store/store_keys.dart` (add after `thumbKey`, ~line 20)
- Test: `test/core/services/media_store/store_keys_test.dart` (create if absent; otherwise append)

**Interfaces:**
- Produces: `static String StoreKeys.renditionKey(String contentHash, {required String ext})` -> `smv1/renditions/<aa>/<hash>.<ext>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/media_store/store_keys_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

void main() {
  test('renditionKey shards by first two hex chars and uses the given ext', () {
    expect(
      StoreKeys.renditionKey('abcdef0123', ext: 'jpg'),
      'smv1/renditions/ab/abcdef0123.jpg',
    );
    expect(
      StoreKeys.renditionKey('abcdef0123', ext: 'mp4'),
      'smv1/renditions/ab/abcdef0123.mp4',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/media_store/store_keys_test.dart`
Expected: FAIL (method `renditionKey` not defined).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/services/media_store/store_keys.dart — add below thumbKey (line ~20)
  /// Compressed rendition, keyed by the ORIGINAL's hash (like [thumbKey]);
  /// [ext] is the rendition's own output format (jpg for photos, mp4 for
  /// video), not the original's extension. NOT hash-verified on read.
  static String renditionKey(String contentHash, {required String ext}) =>
      'smv1/renditions/${contentHash.substring(0, 2)}/$contentHash.$ext';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/media_store/store_keys_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/media_store/store_keys.dart test/core/services/media_store/store_keys_test.dart
git commit -m "feat(media-store): add renditionKey store-key derivation"
```

---

## Task 3: Main DB schema v130 — compressed rendition columns

**Files:**
- Modify: `lib/core/database/database.dart` — the `Media` table class (~line 1229), `currentSchemaVersion` (line 2817), `migrationVersions` list (line 2822), the onUpgrade steps (~line 6474, after the `if (from < 103)` block), a new `_assertMediaCompressedRenditionColumns()` helper (place beside `_assertMediaStoreSchema` ~line 3548), and the `beforeOpen` backstop (~line 6707).
- Regenerate: `lib/core/database/database.g.dart`
- Test: `test/core/database/media_compressed_columns_migration_test.dart`

**Interfaces:**
- Produces: `media.compressedLevel` (TextColumn, nullable), `media.compressedSizeBytes` (IntColumn, nullable), `media.remoteCompressedUploadedAt` (IntColumn, nullable, epoch millis). Drift companion `MediaCompanion` and row `MediaData` gain these fields after codegen.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/media_compressed_columns_migration_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('media has the compressed rendition columns after open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('media')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, containsAll(<String>{
      'compressed_level',
      'compressed_size_bytes',
      'remote_compressed_uploaded_at',
    }));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/media_compressed_columns_migration_test.dart`
Expected: FAIL (columns absent).

- [ ] **Step 3a: Add the columns to the `Media` table**

```dart
// lib/core/database/database.dart — in class Media, right after remoteThumbUploadedAt (line ~1229)
  // Adjustable upload quality (v130): a compressed rendition, keyed by the
  // original's content hash, may be uploaded instead of the original.
  TextColumn get compressedLevel => text().nullable()();
  IntColumn get compressedSizeBytes => integer().nullable()();
  IntColumn get remoteCompressedUploadedAt => integer().nullable()();
```

- [ ] **Step 3b: Bump the schema version**

```dart
// lib/core/database/database.dart:2817
  static const int currentSchemaVersion = 130;
```
Also append `130` to the `migrationVersions` list (line ~2822) following the existing formatting.

- [ ] **Step 3c: Add the idempotent DDL helper** (beside `_assertMediaStoreSchema`, ~line 3548)

```dart
  /// Idempotent DDL for the v130 compressed-rendition columns. Called from
  /// the v130 onUpgrade step and the beforeOpen backstop, matching the
  /// _assertMediaStoreSchema pattern so a schema-version collision cannot
  /// strand a database without them.
  Future<void> _assertMediaCompressedRenditionColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    Future<void> add(String name, String type) async {
      if (!names.contains(name)) {
        await customStatement('ALTER TABLE media ADD COLUMN $name $type');
      }
    }

    await add('compressed_level', 'TEXT');
    await add('compressed_size_bytes', 'INTEGER');
    await add('remote_compressed_uploaded_at', 'INTEGER');
  }
```

- [ ] **Step 3d: Add the onUpgrade step** (in `onUpgrade`, after the `if (from < 103) await reportProgress();` line ~6474, following the file's `if (from < N)` + `reportProgress()` convention)

```dart
        if (from < 130) {
          await _assertMediaCompressedRenditionColumns();
        }
        if (from < 130) await reportProgress();
```

- [ ] **Step 3e: Add the beforeOpen backstop** (in `beforeOpen`, after the existing `_assertMediaStoreSchema()` call ~line 6707)

```dart
        // v130 backstop: re-assert compressed-rendition columns.
        await _assertMediaCompressedRenditionColumns();
```

- [ ] **Step 3f: Regenerate drift**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` updates; `MediaCompanion`/`MediaData` gain the three fields.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/database/media_compressed_columns_migration_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/media_compressed_columns_migration_test.dart
git commit -m "feat(media-store): add v130 compressed rendition columns"
```

---

## Task 4: `MediaItem` entity fields

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart` (fields ~94, constructor ~102, copyWith ~157, `props` list ~end)
- Test: `test/features/media/domain/media_item_compressed_fields_test.dart`

**Interfaces:**
- Produces: `MediaItem.compressedLevel` (String?), `MediaItem.compressedSizeBytes` (int?), `MediaItem.remoteCompressedUploadedAt` (DateTime?); all three added to the constructor (named, optional) and to `copyWith` using the `_undefined` sentinel.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/domain/media_item_compressed_fields_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem base() => MediaItem(
      id: 'm1',
      mediaType: MediaType.photo,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('copyWith sets and clears remoteCompressedUploadedAt', () {
    final withStamp =
        base().copyWith(remoteCompressedUploadedAt: DateTime(2026, 2, 2));
    expect(withStamp.remoteCompressedUploadedAt, DateTime(2026, 2, 2));
    final cleared = withStamp.copyWith(remoteCompressedUploadedAt: null);
    expect(cleared.remoteCompressedUploadedAt, isNull);
  });

  test('copyWith leaves compressedLevel untouched when omitted', () {
    final a = base().copyWith(compressedLevel: 'balanced');
    final b = a.copyWith(caption: 'hi');
    expect(b.compressedLevel, 'balanced');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/domain/media_item_compressed_fields_test.dart`
Expected: FAIL (no named parameter `remoteCompressedUploadedAt`).

- [ ] **Step 3: Write minimal implementation**

Add the three fields (after `remoteThumbUploadedAt`, line ~94):
```dart
  final String? compressedLevel;
  final int? compressedSizeBytes;
  final DateTime? remoteCompressedUploadedAt;
```
Add to the constructor (after `this.remoteThumbUploadedAt`, line ~137):
```dart
    this.compressedLevel,
    this.compressedSizeBytes,
    this.remoteCompressedUploadedAt,
```
Add to `copyWith` params (after `remoteThumbUploadedAt`):
```dart
    Object? compressedLevel = _undefined,
    Object? compressedSizeBytes = _undefined,
    Object? remoteCompressedUploadedAt = _undefined,
```
Add to the `copyWith` body (after the `remoteThumbUploadedAt:` mapping):
```dart
      compressedLevel: compressedLevel == _undefined
          ? this.compressedLevel
          : compressedLevel as String?,
      compressedSizeBytes: compressedSizeBytes == _undefined
          ? this.compressedSizeBytes
          : compressedSizeBytes as int?,
      remoteCompressedUploadedAt: remoteCompressedUploadedAt == _undefined
          ? this.remoteCompressedUploadedAt
          : remoteCompressedUploadedAt as DateTime?,
```
Add the three to the Equatable `props` list (find the existing `props` getter that lists `contentHash, contentSizeBytes, remoteUploadedAt, remoteThumbUploadedAt` and append the three new names).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/domain/media_item_compressed_fields_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/domain/entities/media_item.dart test/features/media/domain/media_item_compressed_fields_test.dart
git commit -m "feat(media): add compressed rendition fields to MediaItem"
```

---

## Task 5: `MediaRepository` — persistence, stamps, refcounts, backfill fix

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_repository_compressed_test.dart`

**Interfaces:**
- Produces:
  - `_mapRowToMediaItem` rehydrates the three new columns (internal).
  - `createMedia`/`updateMedia` companions write the three new columns (internal).
  - `Future<void> stampRemoteCompressedUploaded(String mediaId, {required DateTime uploadedAt, required String level, required int sizeBytes})`
  - `Future<void> clearRemoteUploaded(String mediaId)`
  - `Future<void> clearRemoteCompressed(String mediaId)`
  - `Future<int> countRowsWithOriginal(String contentHash)`
  - `Future<int> countRowsWithRendition(String contentHash)`
  - `getBackfillCandidateIds` treats a compressed-only photo as done.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/data/media_repository_compressed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import '../../../helpers/test_database.dart';

void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  MediaItem photo(String id, {String? hash}) => MediaItem(
        id: id,
        mediaType: MediaType.photo,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        contentHash: hash,
      );

  test('stampRemoteCompressedUploaded persists level, size, stamp', () async {
    await repo.createMedia(photo('m1', hash: 'h1'));
    await repo.stampRemoteCompressedUploaded('m1',
        uploadedAt: DateTime(2026, 2, 2), level: 'balanced', sizeBytes: 4321);
    final got = await repo.getMediaById('m1');
    expect(got!.remoteCompressedUploadedAt, DateTime(2026, 2, 2));
    expect(got.compressedLevel, 'balanced');
    expect(got.compressedSizeBytes, 4321);
  });

  test('countRowsWithOriginal counts only rows with remoteUploadedAt set',
      () async {
    await repo.createMedia(photo('a', hash: 'h9').copyWith(
        remoteUploadedAt: DateTime(2026, 1, 2)));
    await repo.createMedia(photo('b', hash: 'h9')); // no original stamp
    expect(await repo.countRowsWithOriginal('h9'), 1);
  });

  test('compressed-only photo is NOT a backfill candidate', () async {
    await repo.createMedia(photo('c', hash: 'h3').copyWith(
        remoteCompressedUploadedAt: DateTime(2026, 1, 3)));
    expect(await repo.getBackfillCandidateIds(), isNot(contains('c')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/media_repository_compressed_test.dart`
Expected: FAIL (`stampRemoteCompressedUploaded` not defined).

- [ ] **Step 3a: Rehydrate the columns in `_mapRowToMediaItem`** (after the `remoteThumbUploadedAt:` mapping, ~line 1000)

```dart
      compressedLevel: row.compressedLevel,
      compressedSizeBytes: row.compressedSizeBytes,
      remoteCompressedUploadedAt: row.remoteCompressedUploadedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.remoteCompressedUploadedAt!)
          : null,
```

- [ ] **Step 3b: Write the columns in `createMedia` (~line 148) and `updateMedia` (~line 223) companions** — add to each `MediaCompanion(...)`:

```dart
              compressedLevel: Value(item.compressedLevel),
              compressedSizeBytes: Value(item.compressedSizeBytes),
              remoteCompressedUploadedAt: Value(
                item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
              ),
```

- [ ] **Step 3c: Add the stamp + clear + count methods** (beside `stampRemoteThumbUploaded`, ~line 943)

```dart
  /// Confirms a compressed rendition exists in the store, recording which
  /// level produced it (first-writer-wins) and its byte size.
  Future<void> stampRemoteCompressedUploaded(
    String mediaId, {
    required DateTime uploadedAt,
    required String level,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteCompressedUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        compressedLevel: Value(level),
        compressedSizeBytes: Value(sizeBytes),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the original-upload stamp (used when a re-upload override
  /// switches an item from original to compressed).
  Future<void> clearRemoteUploaded(String mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteUploadedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the compressed-rendition stamps (override switching to original).
  Future<void> clearRemoteCompressed(String mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteCompressedUploadedAt: const Value(null),
        compressedLevel: const Value(null),
        compressedSizeBytes: const Value(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Number of media rows sharing [contentHash] that still want the original
  /// object (remote_uploaded_at set). Used to guard a targeted delete.
  Future<int> countRowsWithOriginal(String contentHash) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(
        _db.media.contentHash.equals(contentHash) &
            _db.media.remoteUploadedAt.isNotNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Number of media rows sharing [contentHash] that still want the rendition.
  Future<int> countRowsWithRendition(String contentHash) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(
        _db.media.contentHash.equals(contentHash) &
            _db.media.remoteCompressedUploadedAt.isNotNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }
```

- [ ] **Step 3d: Fix `getBackfillCandidateIds`** (~line 902) so a compressed-only photo is not re-queued. Change the photo predicate to require BOTH stamps null:

```dart
      ..where(
        (_db.media.remoteUploadedAt.isNull() &
                _db.media.remoteCompressedUploadedAt.isNull() &
                _db.media.fileType.equals('photo') &
                _db.media.sourceType.isIn([
                  'platformGallery',
                  'localFile',
                  'serviceConnector',
                ])) |
            (_db.media.remoteThumbUploadedAt.isNull() &
                _db.media.fileType.equals('video') &
                _db.media.sourceType.equals('serviceConnector')),
      )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/media_repository_compressed_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_compressed_test.dart
git commit -m "feat(media): compressed stamps, refcounts, and backfill fix"
```

---

## Task 6: `MediaStorePolicies` — per-media-type quality

**Files:**
- Modify: `lib/core/services/media_store/media_store_policies.dart`
- Test: `test/core/services/media_store/media_store_policies_quality_test.dart`

**Interfaces:**
- Produces: `Future<MediaUploadQuality> photoUploadQuality()`, `Future<void> setPhotoUploadQuality(MediaUploadQuality)`, `Future<MediaUploadQuality> videoUploadQuality()`, `Future<void> setVideoUploadQuality(MediaUploadQuality)`, and `Future<MediaUploadQuality> qualityFor(MediaType)`. Storage keys `media_store_photo_quality` / `media_store_video_quality`; default `original`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/media_store/media_store_policies_quality_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to original for both media types', () async {
    final p = MediaStorePolicies(prefs: await SharedPreferences.getInstance());
    expect(await p.photoUploadQuality(), MediaUploadQuality.original);
    expect(await p.qualityFor(MediaType.video), MediaUploadQuality.original);
  });

  test('round-trips a set level', () async {
    final p = MediaStorePolicies(prefs: await SharedPreferences.getInstance());
    await p.setPhotoUploadQuality(MediaUploadQuality.small);
    expect(await p.photoUploadQuality(), MediaUploadQuality.small);
    expect(await p.qualityFor(MediaType.photo), MediaUploadQuality.small);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/media_store/media_store_policies_quality_test.dart`
Expected: FAIL (`photoUploadQuality` not defined).

- [ ] **Step 3: Write minimal implementation** (add imports + members to `MediaStorePolicies`)

```dart
// add imports at top
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

// add keys beside the existing static const keys
  static const String photoQualityKey = 'media_store_photo_quality';
  static const String videoQualityKey = 'media_store_video_quality';

// add methods
  Future<MediaUploadQuality> photoUploadQuality() async =>
      _readQuality(photoQualityKey);

  Future<void> setPhotoUploadQuality(MediaUploadQuality value) async =>
      (await _resolved).setString(photoQualityKey, value.name);

  Future<MediaUploadQuality> videoUploadQuality() async =>
      _readQuality(videoQualityKey);

  Future<void> setVideoUploadQuality(MediaUploadQuality value) async =>
      (await _resolved).setString(videoQualityKey, value.name);

  Future<MediaUploadQuality> qualityFor(MediaType type) async =>
      type == MediaType.video
          ? await videoUploadQuality()
          : await photoUploadQuality();

  Future<MediaUploadQuality> _readQuality(String key) async {
    final raw = (await _resolved).getString(key);
    if (raw == null) return MediaUploadQuality.original;
    try {
      return MediaUploadQuality.values.byName(raw);
    } on ArgumentError {
      return MediaUploadQuality.original;
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/media_store/media_store_policies_quality_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/media_store/media_store_policies.dart test/core/services/media_store/media_store_policies_quality_test.dart
git commit -m "feat(media-store): per-media-type upload quality policy"
```

---

## Task 7: `MediaCacheStore` — rendition pool + freshness

**Files:**
- Modify: `lib/features/media_store/data/media_cache_store.dart`
- Test: `test/features/media_store/media_cache_store_rendition_test.dart`

**Interfaces:**
- Produces: `MediaCacheKind.rendition`; a `renditionsCapBytes` pool (default 1 GiB) evicted independently; `get(hash, kind, {DateTime? freshAfter})` treats an entry whose `createdAt < freshAfter` as a miss (deletes it, returns null).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/media_cache_store_rendition_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cache_rendition');
    cache = MediaCacheStore(database: db, root: root);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<File> staged(List<int> bytes) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  test('rendition pool stores and retrieves separately from original',
      () async {
    await cache.put('h1', MediaCacheKind.rendition, await staged([1, 2, 3]));
    final got = await cache.get('h1', MediaCacheKind.rendition);
    expect(got, isNotNull);
    expect(await cache.get('h1', MediaCacheKind.original), isNull);
  });

  test('get with freshAfter after the cache time is a miss', () async {
    await cache.put('h2', MediaCacheKind.rendition, await staged([9]));
    final stale = await cache.get('h2', MediaCacheKind.rendition,
        freshAfter: DateTime.now().add(const Duration(days: 1)));
    expect(stale, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_cache_store_rendition_test.dart`
Expected: FAIL (`MediaCacheKind.rendition` not defined).

- [ ] **Step 3: Write minimal implementation**

```dart
// media_cache_store.dart
// 1) extend the enum
enum MediaCacheKind { original, thumb, rendition }

// 2) add a cap field + ctor param (default 1 GiB)
  MediaCacheStore({
    required LocalCacheDatabase database,
    required Directory root,
    this.originalsCapBytes = 2 * 1024 * 1024 * 1024,
    this.thumbsCapBytes = 256 * 1024 * 1024,
    this.renditionsCapBytes = 1 * 1024 * 1024 * 1024,
  }) : _db = database,
       _root = root;
  final int renditionsCapBytes;

// 3) extend the two mappers
  String _kindName(MediaCacheKind kind) => switch (kind) {
        MediaCacheKind.original => 'original',
        MediaCacheKind.thumb => 'thumb',
        MediaCacheKind.rendition => 'rendition',
      };

  String _relativePath(String contentHash, MediaCacheKind kind) => p.join(
        switch (kind) {
          MediaCacheKind.original => 'originals',
          MediaCacheKind.thumb => 'thumbs',
          MediaCacheKind.rendition => 'renditions',
        },
        contentHash.substring(0, 2),
        contentHash,
      );

// 4) add freshAfter to get(): after loading `row`, before the file check:
  Future<File?> get(
    String contentHash,
    MediaCacheKind kind, {
    DateTime? freshAfter,
  }) async {
    final row = await (_db.select(_db.mediaCacheEntries)
          ..where((t) =>
              t.contentHash.equals(contentHash) &
              t.kind.equals(_kindName(kind))))
        .getSingleOrNull();
    if (row == null) return null;
    if (freshAfter != null &&
        row.createdAt < freshAfter.millisecondsSinceEpoch) {
      // Stale: the store object was overwritten after we cached it.
      final f = File(p.join(_root.path, row.relativePath));
      if (await f.exists()) await f.delete();
      await _deleteEntry(contentHash, kind);
      return null;
    }
    // ... existing body (file existence check, LRU touch, return file) ...
```

Also extend `evictIfNeeded()` to run the rendition pool:
```dart
  Future<void> evictIfNeeded() async {
    await _evictPool(MediaCacheKind.original, originalsCapBytes);
    await _evictPool(MediaCacheKind.thumb, thumbsCapBytes);
    await _evictPool(MediaCacheKind.rendition, renditionsCapBytes);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_cache_store_rendition_test.dart`
Expected: PASS. Also run `flutter test test/features/media_store/` to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_cache_store.dart test/features/media_store/media_cache_store_rendition_test.dart
git commit -m "feat(media-store): rendition cache pool with freshness check"
```

---

## Task 8: `MediaCompressor` seam + `ImageCompressor` + `VideoTranscoder` interface

**Files:**
- Create: `lib/features/media_store/data/media_compressor.dart` (seam + `CompressionResult`)
- Create: `lib/features/media_store/data/image_compressor.dart`
- Create: `lib/features/media_store/data/video_transcoder.dart` (interface only)
- Test: `test/features/media_store/image_compressor_test.dart`

**Interfaces:**
- Produces:
  - `class CompressionResult { final File file; final String ext; final int sizeBytes; }`
  - `abstract class MediaCompressor { Future<CompressionResult?> compress(MediaItem item, File source, MediaUploadQuality level); }` (returns `null` => "upload the original instead").
  - `class ImageCompressor implements MediaCompressor` — ctor `ImageCompressor({required MediaSourceResolverRegistry registry, required MediaCacheStore cache})`.
  - `abstract class VideoTranscoder { Future<CompressionResult?> transcode(MediaItem item, File source, MediaUploadQuality level); }` (NO implementation in Phase A).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/image_compressor_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'support/fake_local_file_resolver.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late ImageCompressor compressor;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('img_compress');
    cache = MediaCacheStore(database: db, root: root);
    compressor = ImageCompressor(
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: FakeLocalFileResolver(),
      }),
      cache: cache,
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem photo() => MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        originalFilename: 'shot.png',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('downsizes a large image to the level ceiling and emits jpg', () async {
    final big = img.Image(width: 4000, height: 3000);
    final source = await cache.stagingFile();
    await source.writeAsBytes(img.encodePng(big), flush: true);

    final result =
        await compressor.compress(photo(), source, MediaUploadQuality.balanced);

    expect(result, isNotNull);
    expect(result!.ext, 'jpg');
    final decoded = img.decodeJpg(await result.file.readAsBytes())!;
    expect(decoded.width, 2048); // balanced ceiling, aspect preserved
  });

  test('returns null (upload original) when already under the ceiling',
      () async {
    final small = img.Image(width: 800, height: 600);
    final source = await cache.stagingFile();
    await source.writeAsBytes(img.encodePng(small), flush: true);
    final result =
        await compressor.compress(photo(), source, MediaUploadQuality.balanced);
    expect(result, isNull);
  });
}
```

Note: this test decodes `source` directly (non-gallery path). `FakeLocalFileResolver` exists at `test/features/media_store/support/fake_local_file_resolver.dart`; add a copy or import under `test/features/media_store/support/` for this test's directory.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/image_compressor_test.dart`
Expected: FAIL (targets don't exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/media_store/data/media_compressor.dart
import 'dart:io';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// A produced rendition: [file] holds the compressed bytes, [ext] is its
/// output format (jpg | mp4), [sizeBytes] its length.
class CompressionResult {
  const CompressionResult({
    required this.file,
    required this.ext,
    required this.sizeBytes,
  });
  final File file;
  final String ext;
  final int sizeBytes;
}

/// Produces a compressed rendition, or null to mean "upload the original
/// instead" (already under the level's ceiling, or an undecodable input).
abstract class MediaCompressor {
  Future<CompressionResult?> compress(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  );
}
```

```dart
// lib/features/media_store/data/video_transcoder.dart
import 'dart:io';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Video transcoding seam. Phase A ships the interface only; with no
/// implementation registered, the pipeline falls back to uploading the
/// original for a non-Original video level. Phase B provides the
/// ffmpeg-backed implementation (submersion_transcoder plugin).
abstract class VideoTranscoder {
  Future<CompressionResult?> transcode(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  );
}
```

```dart
// lib/features/media_store/data/image_compressor.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Photo compressor (pure Dart). Gallery items route through the source
/// resolver's sized-thumbnail path (photo_manager decodes HEIC natively);
/// everything else decodes [source] with package:image. Returns null to
/// upload the original when already under the ceiling or undecodable.
class ImageCompressor implements MediaCompressor {
  ImageCompressor({
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
  })  : _registry = registry,
        _cache = cache;

  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(ImageCompressor);

  @override
  Future<CompressionResult?> compress(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  ) async {
    final preset = photoPresetFor(level);
    if (preset == null) return null; // original: no compression
    try {
      if (item.sourceType == MediaSourceType.platformGallery) {
        // photo_manager returns a sized, JPEG-encoded rendition; HEIC-safe.
        final data = await _registry.resolverFor(item.sourceType).resolveThumbnail(
              item,
              target: Size(
                preset.maxDimension.toDouble(),
                preset.maxDimension.toDouble(),
              ),
            );
        if (data is BytesData) return _writeJpeg(data.bytes);
        return null;
      }
      final bytes = await source.readAsBytes();
      return _encode(bytes, item.originalFilename, preset);
    } on Exception catch (e) {
      _log.warning('Image compression failed for ${item.id}: $e');
      return null;
    }
  }

  Future<CompressionResult?> _encode(
    Uint8List bytes,
    String? name,
    PhotoQualityPreset preset,
  ) async {
    final decoded = name != null && name.contains('.')
        ? img.decodeNamedImage(name, bytes)
        : img.decodeImage(bytes);
    if (decoded == null) return null; // undecodable (e.g. HEIC on desktop)
    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest <= preset.maxDimension) return null; // ceiling: upload original
    final resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? preset.maxDimension : null,
      height: decoded.height > decoded.width ? preset.maxDimension : null,
    );
    return _writeJpeg(img.encodeJpg(resized, quality: preset.jpegQuality));
  }

  Future<CompressionResult> _writeJpeg(List<int> jpeg) async {
    final staged = await _cache.stagingFile();
    await staged.writeAsBytes(jpeg, flush: true);
    return CompressionResult(
      file: staged,
      ext: 'jpg',
      sizeBytes: jpeg.length,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/image_compressor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_compressor.dart lib/features/media_store/data/image_compressor.dart lib/features/media_store/data/video_transcoder.dart test/features/media_store/image_compressor_test.dart
git commit -m "feat(media-store): MediaCompressor seam + pure-Dart ImageCompressor"
```

---

## Task 9: Transfer queue — `overrideLevel` (cache DB v4) + `enqueueReupload`

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (add column to `MediaTransferQueue`, bump `schemaVersion` 3->4, add migration step)
- Regenerate: `lib/core/database/local_cache_database.g.dart`
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart` (add `enqueueReupload`)
- Test: `test/features/media_store/media_transfer_queue_reupload_test.dart`

**Interfaces:**
- Produces: `media_transfer_queue.override_level` (TextColumn, nullable); `Future<int> MediaTransferQueueRepository.enqueueReupload({required String mediaId, required String overrideLevel})` — deletes any existing upload rows for `mediaId` and inserts a fresh `pending` row carrying `overrideLevel`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media_store/media_transfer_queue_reupload_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository queue;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: db);
  });
  tearDown(() => db.close());

  test('enqueueReupload replaces prior rows and carries overrideLevel',
      () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final id = await queue.enqueueReupload(mediaId: 'm1', overrideLevel: 'small');
    final rows = await queue.allForTesting();
    expect(rows.where((r) => r.mediaId == 'm1').length, 1);
    expect(rows.single.id, id);
    expect(rows.single.overrideLevel, 'small');
    expect(rows.single.state, 'pending');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_transfer_queue_reupload_test.dart`
Expected: FAIL (`enqueueReupload` / `overrideLevel` not defined).

- [ ] **Step 3a: Add the column + bump the cache DB schema**

```dart
// lib/core/database/local_cache_database.dart — in class MediaTransferQueue, after totalBytes
  // Adjustable upload quality: a per-item re-upload override level.
  TextColumn get overrideLevel => text().nullable()();
```
Bump `schemaVersion` from `3` to `4` and add a migration step in the cache DB's `onUpgrade`:
```dart
        if (from < 4) {
          await m.addColumn(mediaTransferQueue, mediaTransferQueue.overrideLevel);
        }
```
(Follow the file's existing `MigrationStrategy` shape; the v3 step that added `progressBytes`/`totalBytes` is the template.)

- [ ] **Step 3b: Regenerate drift**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3c: Add `enqueueReupload`** (in `MediaTransferQueueRepository`, beside `enqueueUpload`)

```dart
  /// Forces a fresh upload of [mediaId] at [overrideLevel], replacing any
  /// existing upload row (any state). Used by the per-item re-upload
  /// override; unlike enqueueUpload it bypasses the terminal-state guard.
  Future<int> enqueueReupload({
    required String mediaId,
    required String overrideLevel,
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.mediaTransferQueue)
            ..where((t) => t.mediaId.equals(mediaId) &
                t.direction.equals('upload')))
          .go();
      final now = DateTime.now().millisecondsSinceEpoch;
      return _db.into(_db.mediaTransferQueue).insert(
            MediaTransferQueueCompanion.insert(
              mediaId: mediaId,
              overrideLevel: Value(overrideLevel),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }
```
(Ensure `import 'package:drift/drift.dart';` is present for `Value`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_transfer_queue_reupload_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/local_cache_database.dart lib/core/database/local_cache_database.g.dart lib/features/media_store/data/media_transfer_queue_repository.dart test/features/media_store/media_transfer_queue_reupload_test.dart
git commit -m "feat(media-store): queue overrideLevel column + enqueueReupload"
```

---

## Task 10: Pipeline — branch on quality level (non-override path)

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
- Test: `test/features/media_store/media_upload_pipeline_quality_test.dart`

**Interfaces:**
- Consumes: `MediaStorePolicies.qualityFor`, `MediaCompressor.compress`, `VideoTranscoder?`, `StoreKeys.renditionKey`, `MediaRepository.stampRemoteCompressedUploaded`, `photoPresetFor`.
- Produces: `MediaUploadPipeline` ctor gains `required MediaStorePolicies policies`, `required MediaCompressor imageCompressor`, `VideoTranscoder? videoTranscoder`. A non-`Original` photo uploads to `renditionKey` and stamps compressed; the dedup gate treats a rendition as done.

- [ ] **Step 1: Write the failing test** (use the Pipeline Harness; construct the pipeline with the new args and a fake compressor)

```dart
// test/features/media_store/media_upload_pipeline_quality_test.dart
// ...imports from the Pipeline Harness, plus:
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCompressor implements MediaCompressor {
  @override
  Future<CompressionResult?> compress(item, source, level) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes([1, 2, 3, 4], flush: true);
    return CompressionResult(file: f, ext: 'jpg', sizeBytes: 4);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harnessSetUp();
  });
  tearDown(harnessTearDown);

  test('compressed photo uploads a rendition and stamps compressed, not original',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final policies = MediaStorePolicies(prefs: prefs);
    await policies.setPhotoUploadQuality(MediaUploadQuality.balanced);

    final resolver = _FakeLocalFileResolver(/* returns a real PNG file */);
    final registry = MediaSourceResolverRegistry(
        {MediaSourceType.localFile: resolver});
    final pipeline = MediaUploadPipeline(
      mediaRepository: mediaRepository,
      queue: queue,
      store: fakeStore,
      registry: registry,
      cache: cache,
      policies: policies,
      imageCompressor: _StubCompressor(),
      now: () => DateTime(2026, 7, 20, 12),
    );

    // ... create a localFile photo, enqueue, process ...
    // Assert:
    //   fakeStore.objects.keys.any((k) => k.startsWith('smv1/renditions/'))
    //   item.remoteCompressedUploadedAt != null && item.remoteUploadedAt == null
    //   item.compressedLevel == 'balanced'
  });
}
```

Fill in the fake resolver returning a `FileData` PNG (mirror the existing `_FakeLocalFileResolver` in `media_upload_pipeline_test.dart`) and the create/enqueue/process wiring from that same file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_upload_pipeline_quality_test.dart`
Expected: FAIL (ctor has no `policies` parameter).

- [ ] **Step 3: Write minimal implementation** — extend the ctor and the `process` flow.

Add fields + ctor params (after `cache`):
```dart
    required MediaStorePolicies policies,
    required MediaCompressor imageCompressor,
    VideoTranscoder? videoTranscoder,
    // ...
       _policies = policies,
       _imageCompressor = imageCompressor,
       _videoTranscoder = videoTranscoder,
  final MediaStorePolicies _policies;
  final MediaCompressor _imageCompressor;
  final VideoTranscoder? _videoTranscoder;
```

Change the dedup gate near the top of `process` (currently checks `remoteUploadedAt`):
```dart
    final alreadyUploaded = item.remoteUploadedAt != null ||
        item.remoteCompressedUploadedAt != null;
    if (_isThumbOnly(item)
        ? item.remoteThumbUploadedAt != null
        : alreadyUploaded) {
      await _queue.markDone(entry.id);
      return UploadOutcome.deduplicated;
    }
```

Replace the "upload original" block (after the thumb step) with a level branch:
```dart
      final level = await _policies.qualityFor(item.mediaType);
      final rendition = await _renditionFor(item, staged, level);
      if (rendition != null) {
        final key = StoreKeys.renditionKey(digest.hash, ext: rendition.ext);
        if (await _store.head(key) == null) {
          await _store.putFile(key, rendition.file,
              contentType: StoreKeys.contentTypeFor(rendition.ext));
        }
        await _mediaRepository.stampRemoteCompressedUploaded(
          item.id,
          uploadedAt: _now(),
          level: level.name,
          sizeBytes: rendition.sizeBytes,
        );
        await _cleanupRendition(rendition.file);
        await _queue.markDone(entry.id);
        return UploadOutcome.uploaded;
      }
      // Original level, ceiling fallback, or (video, Phase A) no transcoder:
      // upload the untouched original exactly as before.
      final extension = StoreKeys.extensionFor(item.originalFilename);
      // ... existing objectKey + head + putFile(resumable) + stampRemoteUploaded ...
```

Add the compressor dispatch + temp cleanup helpers:
```dart
  /// Chooses the compressor by media type; returns null for the Original
  /// level, when the compressor declines (ceiling/undecodable), or when a
  /// video has no transcoder registered (Phase A).
  Future<CompressionResult?> _renditionFor(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  ) async {
    if (level == MediaUploadQuality.original) return null;
    if (item.mediaType == MediaType.video) {
      return _videoTranscoder?.transcode(item, source, level);
    }
    return _imageCompressor.compress(item, source, level);
  }

  Future<void> _cleanupRendition(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // already gone
    }
  }
```
Add the imports for `MediaStorePolicies`, `MediaCompressor`/`CompressionResult`, `VideoTranscoder`, `MediaUploadQuality`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_upload_pipeline_quality_test.dart`
Then run the existing pipeline test file (its ctor calls need the new required args — update those call sites to pass `policies: MediaStorePolicies(prefs: ...)` defaulting to `original`, and `imageCompressor: ImageCompressor(registry: registry, cache: cache)`):
Run: `flutter test test/features/media_store/media_upload_pipeline_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_upload_pipeline.dart test/features/media_store/media_upload_pipeline_quality_test.dart test/features/media_store/media_upload_pipeline_test.dart
git commit -m "feat(media-store): pipeline branches uploads on quality level"
```

---

## Task 11: Pipeline — per-item override (forced re-process + guarded delete)

**Files:**
- Modify: `lib/features/media_store/data/media_upload_pipeline.dart`
- Test: `test/features/media_store/media_upload_pipeline_override_test.dart`

**Interfaces:**
- Consumes: `entry.overrideLevel`, `MediaRepository.clearRemoteUploaded/clearRemoteCompressed/countRowsWithOriginal/countRowsWithRendition`, `MediaObjectStore.delete`, `StoreKeys.objectKey/renditionKey`.
- Produces: when `entry.overrideLevel != null`, `process` re-renders regardless of existing stamps, swaps namespaces, and deletes the abandoned object when no remaining row wants it.

- [ ] **Step 1: Write the failing test** (use the Pipeline Harness; seed an item that already has an original uploaded, then re-upload at `small`)

```dart
// test/features/media_store/media_upload_pipeline_override_test.dart
// Assert, after processing an override entry (overrideLevel: 'small') for an
// item whose remoteUploadedAt was set and whose original object exists:
//   - a rendition object now exists (smv1/renditions/...)
//   - the original object (smv1/objects/...) was deleted (no other row wants it)
//   - item.remoteUploadedAt == null && item.remoteCompressedUploadedAt != null
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_upload_pipeline_override_test.dart`
Expected: FAIL (override not handled; original not deleted).

- [ ] **Step 3: Write minimal implementation**

Skip the dedup short-circuit for override entries:
```dart
    final isOverride = entry.overrideLevel != null;
    if (!isOverride) {
      // ... existing alreadyUploaded dedup gate ...
    }
```
Resolve the level from the override when present:
```dart
    final level = isOverride
        ? MediaUploadQuality.values.byName(entry.overrideLevel!)
        : await _policies.qualityFor(item.mediaType);
```
Capture prior state before stamping, and after a successful namespace switch, clear the other stamp and delete the abandoned object when unreferenced:
```dart
    final hadOriginal = item.remoteUploadedAt != null;
    final hadCompressed = item.remoteCompressedUploadedAt != null;
    // ... on the compressed branch, after stampRemoteCompressedUploaded: ...
    if (hadOriginal) {
      await _mediaRepository.clearRemoteUploaded(item.id);
      if (await _mediaRepository.countRowsWithOriginal(digest.hash) == 0) {
        await _store.delete(
          StoreKeys.objectKey(digest.hash,
              extension: StoreKeys.extensionFor(item.originalFilename)),
        );
      }
    }
    // ... on the original branch, after stampRemoteUploaded: symmetric with
    //     clearRemoteCompressed + countRowsWithRendition + delete(renditionKey)
```
(`_renditionFor` already returns a rendition for a non-Original override level; the ceiling rule still applies, so a large photo overridden to `small` compresses, a tiny one uploads its original.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_upload_pipeline_override_test.dart`
Expected: PASS. Re-run Task 10's test to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/data/media_upload_pipeline.dart test/features/media_store/media_upload_pipeline_override_test.dart
git commit -m "feat(media-store): per-item re-upload override with guarded delete"
```

---

## Task 12: Resolver — original -> compressed -> thumb tier + freshness

**Files:**
- Modify: `lib/features/media/data/resolvers/media_store_resolver.dart`
- Test: `test/features/media/data/media_store_resolver_compressed_test.dart`

**Interfaces:**
- Consumes: `item.remoteCompressedUploadedAt`, `StoreKeys.renditionKey`, `MediaCacheKind.rendition`, `MediaCacheStore.get(..., freshAfter:)`.
- Produces: `tryResolveRemote` serves a rendition when the original is absent but a rendition exists; the rendition cache validates against `remoteCompressedUploadedAt`.

- [ ] **Step 1: Write the failing test** (use the resolver test setup at `test/features/media/data/media_store_resolver_test.dart:15-33`)

```dart
// Put rendition bytes at StoreKeys.renditionKey(hash, ext: 'jpg'); build a
// MediaItem with contentHash = hash, remoteUploadedAt = null,
// remoteCompressedUploadedAt = <a time>. Assert tryResolveRemote(item,
// thumbnail: false) returns FileData whose bytes == the rendition bytes.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/media_store_resolver_compressed_test.dart`
Expected: FAIL (resolver returns null; no compressed tier).

- [ ] **Step 3: Write minimal implementation** — insert a compressed tier between original and null in `tryResolveRemote`:

```dart
    if (item.remoteUploadedAt != null) {
      final original = await _fetchOriginal(item, hash);
      if (original != null) return original;
    }
    if (item.remoteCompressedUploadedAt != null) {
      return _fetchCompressed(item, hash);
    }
    return null;
```
Add `_fetchCompressed` (mirrors `_fetchThumb`: no hash verification, but passes `freshAfter` for mutability):
```dart
  Future<MediaSourceData?> _fetchCompressed(MediaItem item, String hash) async {
    final ext = item.mediaType == MediaType.video ? 'mp4' : 'jpg';
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.rendition,
          freshAfter: item.remoteCompressedUploadedAt);
      if (cached != null) return FileData(file: cached);
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.renditionKey(hash, ext: ext), staging);
      final file =
          await _cache.put(hash, MediaCacheKind.rendition, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Rendition fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }
```
Adjust the thumbnail fall-through so a thumbnail request with no thumb still reaches the compressed tier (it already falls through to the original branch; the compressed tier is directly below it).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/media_store_resolver_compressed_test.dart`
Then `flutter test test/features/media/data/media_store_resolver_test.dart` (no regression).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/resolvers/media_store_resolver.dart test/features/media/data/media_store_resolver_compressed_test.dart
git commit -m "feat(media-store): resolver serves compressed renditions with freshness"
```

---

## Task 13: Provider wiring — inject compressor/policies; re-upload entry point

**Files:**
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (the `mediaStoreRuntimeProvider` pipeline construction ~line 179; add a re-upload provider)
- Modify: `lib/features/media_store/data/media_store_worker.dart` (add `reuploadAndKick`)
- Test: `test/features/media_store/media_store_worker_reupload_test.dart`

**Interfaces:**
- Produces: `MediaStoreWorker.reuploadAndKick(String mediaId, MediaUploadQuality level)`; `mediaStoreReuploadProvider` exposing `Future<void> Function(String mediaId, MediaUploadQuality level)`.
- Consumes: existing `mediaStorePoliciesProvider`, `mediaSourceResolverRegistryProvider`, the runtime's `worker`.

- [ ] **Step 1: Write the failing test**

```dart
// Construct a MediaStoreWorker with a real queue (in-memory cache DB) and a
// stub pipeline that records processed entries; call
// worker.reuploadAndKick('m1', MediaUploadQuality.small); await
// worker.activeDrain; assert the processed entry had overrideLevel == 'small'.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_store_worker_reupload_test.dart`
Expected: FAIL (`reuploadAndKick` not defined).

- [ ] **Step 3: Write minimal implementation**

```dart
// media_store_worker.dart — beside enqueueAndKick
  Future<void> reuploadAndKick(String mediaId, MediaUploadQuality level) async {
    await _queue.enqueueReupload(mediaId: mediaId, overrideLevel: level.name);
    _activeDrain = drain();
    unawaited(_activeDrain!);
  }
```
Wire the pipeline's new required args in `mediaStoreRuntimeProvider` (~line 179):
```dart
      final pipeline = MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: MediaTransferQueueRepository(),
        store: store,
        registry: ref.watch(mediaSourceResolverRegistryProvider),
        cache: cache,
        policies: policies,
        imageCompressor: ImageCompressor(
          registry: ref.watch(mediaSourceResolverRegistryProvider),
          cache: cache,
        ),
        // videoTranscoder: null (Phase B)
      );
```
Add the re-upload provider (near `mediaStoreEnqueueImplProvider`, ~line 244):
```dart
final mediaStoreReuploadProvider =
    Provider<Future<void> Function(String, MediaUploadQuality)>((ref) {
  return (mediaId, level) async {
    final runtime = await ref.read(mediaStoreRuntimeProvider.future);
    await runtime?.worker?.reuploadAndKick(mediaId, level);
  };
});
```
(Add imports for `ImageCompressor` and `MediaUploadQuality`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_store_worker_reupload_test.dart`
Expected: PASS. Run `flutter analyze` to confirm the provider graph still compiles.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/presentation/providers/media_store_providers.dart lib/features/media_store/data/media_store_worker.dart test/features/media_store/media_store_worker_reupload_test.dart
git commit -m "feat(media-store): wire compressor into pipeline + reupload entry point"
```

---

## Task 14: l10n keys for the Upload quality section

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces localized getters: `settings_mediaStorage_quality_section`, `_quality_photos`, `_quality_video`, `_quality_original`, `_quality_high`, `_quality_balanced`, `_quality_small`, `_quality_caveat`.

- [ ] **Step 1: Add keys to the template** `lib/l10n/arb/app_en.arb` (in the `settings_mediaStorage_*` block, before `bodyWeight_*`):

```json
  "settings_mediaStorage_quality_section": "Upload quality",
  "settings_mediaStorage_quality_photos": "Photos",
  "settings_mediaStorage_quality_video": "Video",
  "settings_mediaStorage_quality_original": "Original",
  "settings_mediaStorage_quality_high": "High",
  "settings_mediaStorage_quality_balanced": "Balanced",
  "settings_mediaStorage_quality_small": "Small",
  "settings_mediaStorage_quality_caveat": "With a compression level set, full-resolution originals are not uploaded — they remain only on this device.",
```

- [ ] **Step 2: Add the same 8 keys to the other 10 locales** (`app_ar app_de app_es app_fr app_he app_hu app_it app_nl app_pt app_zh`). Provide translations where known; an English fallback value is acceptable for a first pass and will be flagged by the standard l10n follow-up. Keep keys identical.

- [ ] **Step 3: Regenerate + verify**

Run: `flutter gen-l10n`
Then confirm compile: `flutter analyze`
Expected: `AppLocalizations` exposes the 8 new getters; analyzer clean.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): upload quality strings across 11 locales"
```

---

## Task 15: Settings UI — two quality dropdowns + caveat

**Files:**
- Modify: `lib/features/media_store/presentation/pages/media_storage_page.dart`
- Test: `test/features/media_store/media_storage_page_test.dart` (extend)

**Interfaces:**
- Consumes: `mediaStorePoliciesProvider`, the new l10n getters, `MediaUploadQuality`.
- Produces: an "Upload quality" section (keys `media-quality-photos`, `media-quality-video`) inside the `if (connected)` block, before the backfill button (~line 599); loads `_photoQuality`/`_videoQuality` in `_loadPolicies`; writes via `setPhotoUploadQuality`/`setVideoUploadQuality`.

- [ ] **Step 1: Write the failing widget test** (mirror the policy write-through test at `media_storage_page_test.dart:424-462`; view size `Size(800, 2200)`)

```dart
// Pump app(statusHint: 'dive-media @ minio'); ensureVisible the photos
// dropdown Key('media-quality-photos'); select MediaUploadQuality.small;
// assert SharedPreferences.getInstance().getString('media_store_photo_quality')
// == 'small'.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_storage_page_test.dart`
Expected: FAIL (dropdown key not found).

- [ ] **Step 3: Write minimal implementation**

Add nullable state fields beside `_autoUpload`:
```dart
  MediaUploadQuality? _photoQuality;
  MediaUploadQuality? _videoQuality;
```
Load them in `_loadPolicies`:
```dart
    final photoQuality = await policies.photoUploadQuality();
    final videoQuality = await policies.videoUploadQuality();
    // ... in setState:
      _photoQuality = photoQuality;
      _videoQuality = videoQuality;
```
Insert the section before the backfill button (after line 598), following the dropdown house style (`DropdownButton` as `ListTile.trailing`, `underline: SizedBox()`), with a helper that maps each `MediaUploadQuality` to its localized label and a shared `onChanged` that calls `setState` + `setPhotoUploadQuality`. Add the caveat as a `Padding` + `Text(l10n.settings_mediaStorage_quality_caveat, style: Theme.of(context).textTheme.bodySmall)`. Guard rendering on `_photoQuality != null`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_storage_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store/presentation/pages/media_storage_page.dart test/features/media_store/media_storage_page_test.dart
git commit -m "feat(media-store): Upload quality settings section"
```

---

## Task 16: Per-item re-upload action in the UI

**Files:**
- Modify: the media detail overflow menu and/or Transfers row (identify the media detail page that shows a single `MediaItem`; the Transfers list is `lib/features/media_store/presentation/pages/transfers_page.dart`)
- Test: a widget test asserting the action calls `mediaStoreReuploadProvider`

**Interfaces:**
- Consumes: `mediaStoreReuploadProvider`.
- Produces: a "Re-upload quality" action presenting the four levels; on selection calls the reupload function with the chosen `MediaUploadQuality`.

- [ ] **Step 1: Write the failing widget test** — override `mediaStoreReuploadProvider` with a recording double; tap the action; choose `Small`; assert the double received `(mediaId, MediaUploadQuality.small)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media_store/media_reupload_action_test.dart`
Expected: FAIL (action absent).

- [ ] **Step 3: Write minimal implementation** — add a `PopupMenuButton`/`ListTile` action that shows the four levels (localized) and calls `await ref.read(mediaStoreReuploadProvider)(item.id, level)`, then a `SnackBar` confirming "Re-upload queued." Gate visibility on the store being connected (`ref.watch(mediaStoreResolverProvider) != null`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/media_store/media_reupload_action_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(media-store): per-item re-upload quality action"
```

---

## Task 17: End-to-end compressed photo flow + full suite green

**Files:**
- Test: `test/features/media_store/media_store_quality_end_to_end_test.dart`

- [ ] **Step 1: Write an integration test** using the Pipeline Harness + a real `ImageCompressor`: create a large-PNG `localFile` photo, set photo policy to `balanced`, run the worker drain, assert (a) a `smv1/renditions/` object exists, (b) `remoteUploadedAt` is null and `remoteCompressedUploadedAt`/`compressedLevel` are set, (c) a second device view — a fresh `MediaStoreResolver` over the same `fakeStore` — resolves the item to the rendition bytes.

- [ ] **Step 2: Run it**

Run: `flutter test test/features/media_store/media_store_quality_end_to_end_test.dart`
Expected: PASS.

- [ ] **Step 3: Run the whole suite + analyze + format**

Run:
```bash
dart format .
flutter analyze
flutter test test/features/media_store/ test/features/media/data/ test/core/database/media_compressed_columns_migration_test.dart test/core/services/media_store/
```
Expected: format clean, analyzer clean, all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add test/features/media_store/media_store_quality_end_to_end_test.dart
git commit -m "test(media-store): end-to-end compressed photo upload + read"
```

---

## Self-Review notes (coverage map)

- Spec section 6 (data model) -> Tasks 3, 4, 5, 6, 9.
- Spec section 7 (store layout / renditionKey) -> Task 2.
- Spec section 8 (levels/presets/ceiling) -> Tasks 1, 8, 10.
- Spec section 9 (compressors) -> Task 8 (photo); video interface only (Phase B).
- Spec section 10 (pipeline) -> Tasks 10, 11.
- Spec section 11 (read path + freshness) -> Tasks 7, 12.
- Spec section 12 (per-item override) -> Tasks 9, 11, 13, 16.
- Spec section 13 (GC) -> Task 11 targeted delete ONLY. General Verify Library sweep is NOT built here (it does not exist in the shipped Media Store; it belongs to a future Media-Store Phase 5). This is a deliberate scope narrowing vs. the spec's section 13 wording; the spec is corrected to reflect it.
- Spec section 14 (multi-device) -> covered by the synced stamps (Tasks 3, 5) + Task 17 second-device assertion.
- Spec section 15 (settings UI) -> Tasks 14, 15.
- Spec sections 16/17 (ffmpeg plugin / Phase B) -> OUT of scope; `VideoTranscoder` interface placeholder (Task 8) is the only Phase-A surface.
