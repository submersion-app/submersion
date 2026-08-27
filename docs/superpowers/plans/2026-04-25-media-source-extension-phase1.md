# Media Source Extension — Phase 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the schema, abstraction layer, display widget, native platform-channel infrastructure, and existing-flow refactor required by Phase 1 of the media source extension. No new user-visible source types ship in Phase 1; existing platform-gallery flow keeps working bit-for-bit.

**Architecture:** Polymorphic `MediaSourceType` enum + abstract `MediaSourceResolver` interface dispatched through a `MediaSourceResolverRegistry`. Existing gallery and signature reading paths port onto the abstraction as concrete resolvers. A new `MediaItemView` widget replaces every direct `Image.file`/`Image.memory`/`PhotoManager`-driven display. iOS `BookmarkData` and Android `ContentResolver.takePersistableUriPermission` infrastructure lands behind a `LocalMediaPlatform` Dart wrapper, ready for Phase 2 to first use.

**Tech Stack:** Flutter 3.x + Material 3, Drift ORM (SQLite), Riverpod 2.x, `package:flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences), Swift on iOS, Kotlin on Android.

**Spec:** [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md)

**Note:** The spec lists schema version `26 → 27`. That was incorrect — the codebase is at version `71`. This plan uses `71 → 72`. The spec's version number will be patched in a follow-up commit after Phase 1 lands.

---

## Background Reading

Before starting, read these files to understand the conventions you'll work within:

- [lib/core/database/database.dart:472-574](../../lib/core/database/database.dart#L472-L574) — current `Media`, `MediaEnrichment`, `MediaSpecies`, `PendingPhotoSuggestions` table definitions.
- [lib/core/database/database.dart:1338-1413](../../lib/core/database/database.dart#L1338-L1413) — `currentSchemaVersion` constant and `migrationVersions` list.
- [lib/core/database/database.dart:1820-1908](../../lib/core/database/database.dart#L1820-L1908) — example migration block style (`if (from < N) { customStatement(...) } await reportProgress();`).
- [lib/features/media/domain/entities/media_item.dart](../../lib/features/media/domain/entities/media_item.dart) — current `MediaItem` entity. You'll be adding fields, not replacing it.
- [lib/features/media/data/repositories/media_repository.dart](../../lib/features/media/data/repositories/media_repository.dart) — repository pattern for media. Handles Drift `MediaCompanion` writes and `markRecordPending` for sync.
- [lib/features/media/presentation/widgets/dive_media_section.dart](../../lib/features/media/presentation/widgets/dive_media_section.dart) — the highest-traffic display callsite you'll refactor.
- [lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart](../../lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart) — the existing placeholder widget you'll evolve into `UnavailableMediaPlaceholder`.
- [lib/features/settings/presentation/pages/settings_page.dart:1832-1918](../../lib/features/settings/presentation/pages/settings_page.dart#L1832-L1918) — `_DataSectionContent` you'll add a Media Sources entry to.
- [ios/Runner/MetadataWriteHandler.swift](../../ios/Runner/MetadataWriteHandler.swift) — pattern to follow for the new iOS `LocalMediaHandler.swift`.
- [hooks/](../../hooks) — pre-push hook runs `dart format`, `flutter analyze`, `flutter test`. All commits must pass these.

Conventions:

- Run `dart format .` before every commit.
- Group imports: dart, flutter, packages, local (relative).
- File naming: `snake_case.dart`. Class naming: `PascalCase`.
- Provider naming: `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state.
- Tests: prefer narrow files: `test/features/media/...` mirroring `lib/features/media/...`.

---

## Task 1: Bump Schema Version (no schema changes yet)

**Files:**
- Modify: `lib/core/database/database.dart:1338`
- Modify: `lib/core/database/database.dart:1411-1413`

This task is intentionally a no-op migration — it bumps the version to confirm the migration scaffolding works before any column changes are added. We add the actual schema modifications in subsequent tasks within the same `if (from < 72)` block.

- [ ] **Step 1: Run the existing test suite to confirm baseline green**

```bash
flutter test test/core/database/
```

Expected: all existing tests pass.

- [ ] **Step 2: Bump `currentSchemaVersion` from 71 to 72**

Edit [lib/core/database/database.dart:1338](../../lib/core/database/database.dart#L1338):

```dart
static const int currentSchemaVersion = 72;
```

- [ ] **Step 3: Append `72` to `migrationVersions` list**

Edit [lib/core/database/database.dart:1411-1413](../../lib/core/database/database.dart#L1411-L1413):

```dart
    70,
    71,
    72,
  ];
```

- [ ] **Step 4: Add empty migration block in `onUpgrade`**

Find the last `if (from < 71) { ... } if (from < 71) await reportProgress();` block in `onUpgrade` and append after it:

```dart
        if (from < 72) {
          // Phase 1 of Media Source Extension — see
          // docs/superpowers/specs/2026-04-25-media-source-extension-design.md
          // (Schema changes added in subsequent tasks.)
        }
        if (from < 72) await reportProgress();
```

- [ ] **Step 5: Run tests to confirm migration scaffolding compiles**

```bash
flutter test test/core/database/
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/database/database.dart
git add lib/core/database/database.dart
git commit -m "feat(media): bump schema to v72 for media source extension"
```

---

## Task 2: Add `media` Table Columns Migration

**Files:**
- Modify: `lib/core/database/database.dart` (inside the `if (from < 72) { ... }` block from Task 1)
- Test: `test/core/database/migration_72_test.dart` (create)

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_72_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('migration to v72 adds new media columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA user_version = 71;');
    await db.close();

    final migrated = AppDatabase(NativeDatabase.memory());
    final cols = await migrated.customSelect(
      "PRAGMA table_info('media')",
    ).get();
    final names = cols.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll([
      'source_type',
      'local_path',
      'bookmark_ref',
      'url',
      'subscription_id',
      'entry_key',
      'connector_account_id',
      'remote_asset_id',
      'origin_device_id',
    ]));

    await migrated.close();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: FAIL — columns don't exist yet.

- [ ] **Step 3: Add column ALTERs inside the v72 migration block**

In [lib/core/database/database.dart](../../lib/core/database/database.dart), inside `if (from < 72) { ... }` add:

```dart
        if (from < 72) {
          // Phase 1 of Media Source Extension.
          // Add discriminator and new pointer columns to media.
          await customStatement(
            "ALTER TABLE media ADD COLUMN source_type TEXT NOT NULL DEFAULT 'platformGallery'",
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN local_path TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN bookmark_ref TEXT',
          );
          await customStatement('ALTER TABLE media ADD COLUMN url TEXT');
          await customStatement(
            'ALTER TABLE media ADD COLUMN subscription_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN entry_key TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN connector_account_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN remote_asset_id TEXT',
          );
          await customStatement(
            'ALTER TABLE media ADD COLUMN origin_device_id TEXT',
          );
        }
        if (from < 72) await reportProgress();
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_72_test.dart
git add lib/core/database/database.dart test/core/database/migration_72_test.dart
git commit -m "feat(media): add media table columns for source-type extension"
```

---

## Task 3: Add `media_subscriptions`, `media_subscription_state`, `connector_accounts`, `network_credential_hosts`, `media_fetch_diagnostics` Tables

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_72_test.dart`

- [ ] **Step 1: Extend the failing migration test**

Append to `test/core/database/migration_72_test.dart`:

```dart
  test('migration to v72 creates new tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA user_version = 71;');
    await db.close();

    final migrated = AppDatabase(NativeDatabase.memory());
    final tables = await migrated.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get();
    final names = tables.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll([
      'media_subscriptions',
      'media_subscription_state',
      'connector_accounts',
      'network_credential_hosts',
      'media_fetch_diagnostics',
    ]));

    await migrated.close();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: FAIL — tables don't exist.

- [ ] **Step 3: Add `CREATE TABLE` statements inside the v72 migration block**

Append inside `if (from < 72) { ... }` (after the `ALTER TABLE` statements from Task 2):

```dart
          // Subscription registry (synced across devices).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscriptions (
              id TEXT NOT NULL PRIMARY KEY,
              manifest_url TEXT NOT NULL,
              format TEXT NOT NULL,
              display_name TEXT,
              poll_interval_seconds INTEGER NOT NULL DEFAULT 86400,
              is_active INTEGER NOT NULL DEFAULT 1,
              credentials_host_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Per-device polling state (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscription_state (
              subscription_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media_subscriptions(id) ON DELETE CASCADE,
              last_polled_at INTEGER,
              next_poll_at INTEGER,
              last_etag TEXT,
              last_modified TEXT,
              last_error TEXT,
              last_error_at INTEGER
            )
          ''');

          // Service connector accounts (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS connector_accounts (
              id TEXT NOT NULL PRIMARY KEY,
              connector_type TEXT NOT NULL,
              display_name TEXT NOT NULL,
              base_url TEXT,
              account_identifier TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

          // Per-host credentials for ad-hoc network URLs (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS network_credential_hosts (
              id TEXT NOT NULL PRIMARY KEY,
              hostname TEXT NOT NULL UNIQUE,
              auth_type TEXT NOT NULL,
              display_name TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

          // Per-device fetch diagnostics (NOT synced).
          await customStatement('''
            CREATE TABLE IF NOT EXISTS media_fetch_diagnostics (
              media_item_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media(id) ON DELETE CASCADE,
              last_error_at INTEGER,
              last_error_message TEXT,
              error_count INTEGER NOT NULL DEFAULT 0
            )
          ''');
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_72_test.dart
git add lib/core/database/database.dart test/core/database/migration_72_test.dart
git commit -m "feat(media): add subscription/connector/credential tables"
```

---

## Task 4: Add Indexes and Backfill `source_type`

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_72_test.dart`

- [ ] **Step 1: Write the failing backfill test**

Append to `test/core/database/migration_72_test.dart`:

```dart
  test('migration to v72 backfills source_type from existing rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA user_version = 71;');

    // Seed pre-migration rows.
    await db.customStatement('''
      INSERT INTO media (id, file_path, file_type, taken_at, created_at, updated_at, is_favorite, is_orphaned, platform_asset_id)
      VALUES ('a', '', 'photo', 0, 0, 0, 0, 0, 'PHASSET_1')
    ''');
    await db.customStatement('''
      INSERT INTO media (id, file_path, file_type, taken_at, created_at, updated_at, is_favorite, is_orphaned)
      VALUES ('b', '/Users/me/sig.png', 'instructor_signature', 0, 0, 0, 0, 0)
    ''');
    await db.customStatement('''
      INSERT INTO media (id, file_path, file_type, taken_at, created_at, updated_at, is_favorite, is_orphaned)
      VALUES ('c', '/Users/me/photo.jpg', 'photo', 0, 0, 0, 0, 0)
    ''');
    await db.close();

    final migrated = AppDatabase(NativeDatabase.memory());
    final rows = await migrated.customSelect(
      'SELECT id, source_type, local_path FROM media',
    ).get();
    final byId = {for (final r in rows) r.read<String>('id'): r};

    expect(byId['a']!.read<String>('source_type'), 'platformGallery');
    expect(byId['b']!.read<String>('source_type'), 'signature');
    expect(byId['c']!.read<String>('source_type'), 'localFile');
    expect(byId['c']!.read<String?>('local_path'), '/Users/me/photo.jpg');

    await migrated.close();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: FAIL — backfill not implemented.

- [ ] **Step 3: Add backfill SQL plus indexes inside the v72 block**

Append inside `if (from < 72) { ... }` (after the table creation):

```dart
          // Backfill source_type for existing rows.
          // Order matters: signature first (most specific), then platformGallery,
          // then localFile, with platformGallery as the safe default for the
          // unreachable "neither pointer set" case.
          await customStatement('''
            UPDATE media SET source_type = 'signature'
            WHERE file_type = 'instructor_signature'
          ''');
          await customStatement('''
            UPDATE media
            SET source_type = 'platformGallery'
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NOT NULL
          ''');
          await customStatement('''
            UPDATE media
            SET source_type = 'localFile',
                local_path = file_path
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NULL
              AND file_path IS NOT NULL
              AND file_path != ''
          ''');

          // Indexes.
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_source_type
            ON media(source_type)
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_subscription_entry
            ON media(subscription_id, entry_key)
            WHERE subscription_id IS NOT NULL
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_connector_account
            ON media(connector_account_id)
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_origin_device
            ON media(origin_device_id)
          ''');
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/database/migration_72_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run the full database test suite to make sure nothing else regressed**

```bash
flutter test test/core/database/
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_72_test.dart
git add lib/core/database/database.dart test/core/database/migration_72_test.dart
git commit -m "feat(media): backfill source_type and add indexes"
```

---

## Task 5: Define `MediaSourceType` Enum

**Files:**
- Create: `lib/features/media/domain/entities/media_source_type.dart`
- Test: `test/features/media/domain/media_source_type_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/media_source_type_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  group('MediaSourceType', () {
    test('parses canonical names', () {
      expect(MediaSourceType.fromString('platformGallery'),
          MediaSourceType.platformGallery);
      expect(MediaSourceType.fromString('localFile'),
          MediaSourceType.localFile);
      expect(MediaSourceType.fromString('networkUrl'),
          MediaSourceType.networkUrl);
      expect(MediaSourceType.fromString('manifestEntry'),
          MediaSourceType.manifestEntry);
      expect(MediaSourceType.fromString('serviceConnector'),
          MediaSourceType.serviceConnector);
      expect(MediaSourceType.fromString('signature'),
          MediaSourceType.signature);
    });

    test('returns null for unknown', () {
      expect(MediaSourceType.fromString('bogus'), isNull);
      expect(MediaSourceType.fromString(null), isNull);
    });

    test('round-trips name', () {
      for (final t in MediaSourceType.values) {
        expect(MediaSourceType.fromString(t.name), t);
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/domain/media_source_type_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the enum file**

Create `lib/features/media/domain/entities/media_source_type.dart`:

```dart
enum MediaSourceType {
  platformGallery,
  localFile,
  networkUrl,
  manifestEntry,
  serviceConnector,
  signature;

  static MediaSourceType? fromString(String? value) {
    if (value == null) return null;
    return MediaSourceType.values.cast<MediaSourceType?>().firstWhere(
          (t) => t?.name == value,
          orElse: () => null,
        );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/domain/media_source_type_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/entities/media_source_type.dart test/features/media/domain/media_source_type_test.dart
git add lib/features/media/domain/entities/media_source_type.dart test/features/media/domain/media_source_type_test.dart
git commit -m "feat(media): add MediaSourceType enum"
```

---

## Task 6: Define `VerifyResult` and `MediaSourceMetadata` Value Types

**Files:**
- Create: `lib/features/media/domain/value_objects/verify_result.dart`
- Create: `lib/features/media/domain/value_objects/media_source_metadata.dart`
- Test: `test/features/media/domain/value_objects/media_source_metadata_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/media_source_metadata_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

void main() {
  test('MediaSourceMetadata equality is value-based', () {
    final a = MediaSourceMetadata(
      takenAt: DateTime.utc(2024, 1, 1),
      latitude: 1.0,
      longitude: 2.0,
      width: 100,
      height: 200,
      durationSeconds: null,
      mimeType: 'image/jpeg',
    );
    final b = MediaSourceMetadata(
      takenAt: DateTime.utc(2024, 1, 1),
      latitude: 1.0,
      longitude: 2.0,
      width: 100,
      height: 200,
      durationSeconds: null,
      mimeType: 'image/jpeg',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('all fields nullable except mimeType', () {
    final m = MediaSourceMetadata(mimeType: 'image/jpeg');
    expect(m.takenAt, isNull);
    expect(m.latitude, isNull);
    expect(m.width, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/domain/value_objects/media_source_metadata_test.dart
```

Expected: FAIL — files do not exist.

- [ ] **Step 3: Create the value objects**

Create `lib/features/media/domain/value_objects/verify_result.dart`:

```dart
enum VerifyResult {
  available,
  notFound,
  unauthenticated,
  transientError,
  fromOtherDevice,
}
```

Create `lib/features/media/domain/value_objects/media_source_metadata.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Metadata extracted from a media source at link time.
class MediaSourceMetadata extends Equatable {
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String mimeType;

  const MediaSourceMetadata({
    this.takenAt,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.durationSeconds,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [
        takenAt,
        latitude,
        longitude,
        width,
        height,
        durationSeconds,
        mimeType,
      ];
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/domain/value_objects/media_source_metadata_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/value_objects/
git add lib/features/media/domain/value_objects/ test/features/media/domain/value_objects/
git commit -m "feat(media): add VerifyResult and MediaSourceMetadata value objects"
```

---

## Task 7: Define `MediaSourceData` Sealed Class

**Files:**
- Create: `lib/features/media/domain/value_objects/media_source_data.dart`
- Test: `test/features/media/domain/value_objects/media_source_data_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/media_source_data_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  group('MediaSourceData', () {
    test('FileData carries a File', () {
      final f = File('/tmp/x.jpg');
      final d = FileData(file: f);
      expect(d.file, f);
    });

    test('NetworkData carries url and headers', () {
      final url = Uri.parse('https://example.com/x.jpg');
      final d = NetworkData(url: url, headers: const {'X-Foo': '1'});
      expect(d.url, url);
      expect(d.headers['X-Foo'], '1');
    });

    test('BytesData carries bytes', () {
      final b = Uint8List.fromList([1, 2, 3]);
      final d = BytesData(bytes: b);
      expect(d.bytes, b);
    });

    test('UnavailableData carries kind and optional fields', () {
      const d = UnavailableData(
        kind: UnavailableKind.notFound,
        userMessage: 'file gone',
      );
      expect(d.kind, UnavailableKind.notFound);
      expect(d.userMessage, 'file gone');
      expect(d.originDeviceLabel, isNull);
    });

    test('exhaustive switch over variants compiles', () {
      MediaSourceData data = BytesData(bytes: Uint8List(0));
      final label = switch (data) {
        FileData() => 'file',
        NetworkData() => 'network',
        BytesData() => 'bytes',
        UnavailableData() => 'unavailable',
      };
      expect(label, 'bytes');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/domain/value_objects/media_source_data_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the sealed class**

Create `lib/features/media/domain/value_objects/media_source_data.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

/// Why a media item is unavailable on the current device.
enum UnavailableKind {
  notFound,
  unauthenticated,
  fromOtherDevice,
  networkError,
  signInRequired,
}

/// A handle to displayable media bytes (or an explanation of why we have none).
sealed class MediaSourceData {
  const MediaSourceData();
}

/// The bytes live in a local file the OS can read.
class FileData extends MediaSourceData {
  final File file;
  const FileData({required this.file});
}

/// The bytes live at an HTTP(S) URL that requires the given headers.
class NetworkData extends MediaSourceData {
  final Uri url;
  final Map<String, String> headers;
  const NetworkData({required this.url, this.headers = const {}});
}

/// The bytes are already in memory (used for signature BLOBs).
class BytesData extends MediaSourceData {
  final Uint8List bytes;
  const BytesData({required this.bytes});
}

/// We cannot resolve the bytes on the current device.
class UnavailableData extends MediaSourceData {
  final UnavailableKind kind;
  final String? userMessage;
  final String? originDeviceLabel;

  const UnavailableData({
    required this.kind,
    this.userMessage,
    this.originDeviceLabel,
  });
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/domain/value_objects/media_source_data_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/value_objects/media_source_data.dart test/features/media/domain/value_objects/media_source_data_test.dart
git add lib/features/media/domain/value_objects/media_source_data.dart test/features/media/domain/value_objects/media_source_data_test.dart
git commit -m "feat(media): add MediaSourceData sealed class"
```

---

## Task 8: Extend `MediaItem` Entity With New Fields

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart`
- Test: `test/features/media/domain/media_item_test.dart` (create if not present)

- [ ] **Step 1: Write the failing test**

Create or extend `test/features/media/domain/media_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

MediaItem _baseItem() => MediaItem(
      id: 'x',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  group('MediaItem source-type fields', () {
    test('default is platformGallery for backwards compat', () {
      expect(_baseItem().sourceType, MediaSourceType.platformGallery);
    });

    test('copyWith updates new pointer fields', () {
      final base = _baseItem();
      final updated = base.copyWith(
        sourceType: MediaSourceType.localFile,
        localPath: '/Users/me/x.jpg',
        originDeviceId: 'mac-01',
      );
      expect(updated.sourceType, MediaSourceType.localFile);
      expect(updated.localPath, '/Users/me/x.jpg');
      expect(updated.originDeviceId, 'mac-01');
    });

    test('copyWith preserves unset pointer fields', () {
      final base = _baseItem().copyWith(
        sourceType: MediaSourceType.networkUrl,
        url: 'https://example.com/x.jpg',
      );
      final updated = base.copyWith(caption: 'caption');
      expect(updated.url, 'https://example.com/x.jpg');
      expect(updated.sourceType, MediaSourceType.networkUrl);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/domain/media_item_test.dart
```

Expected: FAIL — `sourceType` is not a parameter of MediaItem.

- [ ] **Step 3: Add the new fields to `MediaItem`**

Edit [lib/features/media/domain/entities/media_item.dart](../../lib/features/media/domain/entities/media_item.dart). At the top, add:

```dart
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
```

Inside `class MediaItem extends Equatable`, add fields after `final String? signerName;`:

```dart
  final MediaSourceType sourceType;
  final String? localPath;
  final String? bookmarkRef;
  final String? url;
  final String? subscriptionId;
  final String? entryKey;
  final String? connectorAccountId;
  final String? remoteAssetId;
  final String? originDeviceId;
```

In the constructor's parameter list, add (matching the existing nullable style):

```dart
    this.sourceType = MediaSourceType.platformGallery,
    this.localPath,
    this.bookmarkRef,
    this.url,
    this.subscriptionId,
    this.entryKey,
    this.connectorAccountId,
    this.remoteAssetId,
    this.originDeviceId,
```

Update `copyWith` to add corresponding parameters using the existing `_undefined` sentinel pattern:

```dart
    MediaSourceType? sourceType,
    Object? localPath = _undefined,
    Object? bookmarkRef = _undefined,
    Object? url = _undefined,
    Object? subscriptionId = _undefined,
    Object? entryKey = _undefined,
    Object? connectorAccountId = _undefined,
    Object? remoteAssetId = _undefined,
    Object? originDeviceId = _undefined,
```

And in the `return MediaItem(...)` body:

```dart
      sourceType: sourceType ?? this.sourceType,
      localPath: localPath == _undefined ? this.localPath : localPath as String?,
      bookmarkRef: bookmarkRef == _undefined ? this.bookmarkRef : bookmarkRef as String?,
      url: url == _undefined ? this.url : url as String?,
      subscriptionId: subscriptionId == _undefined ? this.subscriptionId : subscriptionId as String?,
      entryKey: entryKey == _undefined ? this.entryKey : entryKey as String?,
      connectorAccountId: connectorAccountId == _undefined ? this.connectorAccountId : connectorAccountId as String?,
      remoteAssetId: remoteAssetId == _undefined ? this.remoteAssetId : remoteAssetId as String?,
      originDeviceId: originDeviceId == _undefined ? this.originDeviceId : originDeviceId as String?,
```

Append the new fields to the end of the `props` list:

```dart
    sourceType,
    localPath,
    bookmarkRef,
    url,
    subscriptionId,
    entryKey,
    connectorAccountId,
    remoteAssetId,
    originDeviceId,
  ];
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/domain/media_item_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run the full test suite to confirm no callers regressed**

```bash
flutter test
```

Expected: PASS (existing callers default to `MediaSourceType.platformGallery`).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/domain/entities/media_item.dart test/features/media/domain/media_item_test.dart
git add lib/features/media/domain/entities/media_item.dart test/features/media/domain/media_item_test.dart
git commit -m "feat(media): add source-type fields to MediaItem entity"
```

---

## Task 9: Mirror New `media` Columns in Drift `Media` Table Class

**Files:**
- Modify: `lib/core/database/database.dart` — `class Media extends Table`

The migration in Tasks 2–4 added columns to the live SQLite schema. Drift's `Media` class also needs to declare them so generated code can read/write them.

- [ ] **Step 1: Add new columns to the `Media` Drift table class**

Edit [lib/core/database/database.dart:472-513](../../lib/core/database/database.dart#L472-L513). Inside `class Media extends Table` (after the existing `BoolColumn get isOrphaned ...` line), add:

```dart
  // Source-type extension (v72)
  TextColumn get sourceType => text().withDefault(
    const Constant('platformGallery'),
  )();
  TextColumn get localPath => text().nullable()();
  TextColumn get bookmarkRef => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get subscriptionId => text().nullable()();
  TextColumn get entryKey => text().nullable()();
  TextColumn get connectorAccountId => text().nullable()();
  TextColumn get remoteAssetId => text().nullable()();
  TextColumn get originDeviceId => text().nullable()();
```

- [ ] **Step 2: Re-run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: completes without error and updates `database.g.dart`.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
dart format lib/core/database/database.dart lib/core/database/database.g.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(media): mirror new media columns in Drift Media table"
```

---

## Task 10: Add New Drift Tables (Subscriptions, Connector Accounts, Credential Hosts, Diagnostics)

**Files:**
- Modify: `lib/core/database/database.dart` — add new `Table` classes and register them in the `@DriftDatabase(tables: [...])` annotation
- Modify: `lib/core/database/database.g.dart` (regenerated)

- [ ] **Step 1: Add the table classes**

In `lib/core/database/database.dart`, after `class PendingPhotoSuggestions extends Table { ... }`, add:

```dart
class MediaSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get manifestUrl => text()();
  TextColumn get format => text()();
  TextColumn get displayName => text().nullable()();
  IntColumn get pollIntervalSeconds =>
      integer().withDefault(const Constant(86400))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get credentialsHostId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class MediaSubscriptionState extends Table {
  TextColumn get subscriptionId => text()
      .references(MediaSubscriptions, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastPolledAt => integer().nullable()();
  IntColumn get nextPollAt => integer().nullable()();
  TextColumn get lastEtag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get lastErrorAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {subscriptionId};
}

class ConnectorAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get connectorType => text()();
  TextColumn get displayName => text()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get accountIdentifier => text().nullable()();
  TextColumn get credentialsRef => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastUsedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NetworkCredentialHosts extends Table {
  TextColumn get id => text()();
  TextColumn get hostname => text()();
  TextColumn get authType => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get credentialsRef => text()();
  IntColumn get addedAt => integer()();
  IntColumn get lastUsedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MediaFetchDiagnostics extends Table {
  TextColumn get mediaItemId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastErrorAt => integer().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaItemId};
}
```

- [ ] **Step 2: Register the tables on `@DriftDatabase`**

Find the `@DriftDatabase(tables: [...])` annotation (around `class AppDatabase extends _$AppDatabase`) and add the new table types to the `tables:` list:

```dart
    MediaSubscriptions,
    MediaSubscriptionState,
    ConnectorAccounts,
    NetworkCredentialHosts,
    MediaFetchDiagnostics,
```

- [ ] **Step 3: Re-run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: success.

- [ ] **Step 4: Run tests**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database/database.dart lib/core/database/database.g.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(media): add Drift tables for subscriptions/connectors/credentials"
```

---

## Task 11: Update `MediaRepository` for New Pointer Fields

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_repository_test.dart` (create if not present)

The repository currently writes only the legacy pointer fields. Update `createMedia()` and `_mapRowToMediaItem()` to handle every new column.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/media_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  setUp(() async {
    await DatabaseService.instance.initInMemory();
  });
  tearDown(() async {
    await DatabaseService.instance.close();
  });

  test('createMedia round-trips source-type fields', () async {
    final repo = MediaRepository();
    final created = await repo.createMedia(MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/Users/me/x.jpg',
      originDeviceId: 'mac-01',
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));

    final fetched = await repo.getMediaById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.sourceType, MediaSourceType.localFile);
    expect(fetched.localPath, '/Users/me/x.jpg');
    expect(fetched.originDeviceId, 'mac-01');
  });
}
```

(If `DatabaseService.instance.initInMemory()` does not exist, replace this test's setup with whatever in-memory init pattern other repository tests use — search `test/features/` for `initInMemory` or `NativeDatabase.memory`.)

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/media_repository_test.dart
```

Expected: FAIL — fields aren't written.

- [ ] **Step 3: Update `createMedia()` to populate the new columns**

In [lib/features/media/data/repositories/media_repository.dart](../../lib/features/media/data/repositories/media_repository.dart), inside the `MediaCompanion(...)` constructor in `createMedia()`, append (after `signerName: Value(item.signerName)`):

```dart
              sourceType: Value(item.sourceType.name),
              localPath: Value(item.localPath),
              bookmarkRef: Value(item.bookmarkRef),
              url: Value(item.url),
              subscriptionId: Value(item.subscriptionId),
              entryKey: Value(item.entryKey),
              connectorAccountId: Value(item.connectorAccountId),
              remoteAssetId: Value(item.remoteAssetId),
              originDeviceId: Value(item.originDeviceId),
```

- [ ] **Step 4: Update `_mapRowToMediaItem()` to read the new columns**

Find `_mapRowToMediaItem` in the same file. After the existing field mappings, add (matching the named-arg style of the `MediaItem(...)` constructor call):

```dart
      sourceType: MediaSourceType.fromString(mediaRow.sourceType) ??
          MediaSourceType.platformGallery,
      localPath: mediaRow.localPath,
      bookmarkRef: mediaRow.bookmarkRef,
      url: mediaRow.url,
      subscriptionId: mediaRow.subscriptionId,
      entryKey: mediaRow.entryKey,
      connectorAccountId: mediaRow.connectorAccountId,
      remoteAssetId: mediaRow.remoteAssetId,
      originDeviceId: mediaRow.originDeviceId,
```

Add this import at the top of the file:

```dart
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
```

- [ ] **Step 5: Update `updateMedia()` to write the new columns too**

If `MediaRepository` has an `updateMedia()` method using a `MediaCompanion(...)`, mirror the new field writes from Step 3. (Same field list.)

- [ ] **Step 6: Run the test to verify it passes**

```bash
flutter test test/features/media/data/media_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run full media tests**

```bash
flutter test test/features/media/
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_test.dart
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_test.dart
git commit -m "feat(media): persist source-type fields in MediaRepository"
```

---

## Task 12: Define `MediaSourceResolver` Abstract Interface

**Files:**
- Create: `lib/features/media/domain/services/media_source_resolver.dart`
- Test: not needed (abstract interface)

- [ ] **Step 1: Create the abstract interface file**

Create `lib/features/media/domain/services/media_source_resolver.dart`:

```dart
import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves a [MediaItem] of a particular [sourceType] to displayable data.
///
/// Implementations must:
///   * Be cheap to construct — they're held as singletons by the registry.
///   * Never throw from [resolve]; return [UnavailableData] on any failure.
///   * Be safe to call concurrently for different items.
abstract class MediaSourceResolver {
  /// The [MediaSourceType] this resolver handles.
  MediaSourceType get sourceType;

  /// Whether this resolver can read [item] on the current device.
  /// Returns false when [item.originDeviceId] points to a different device
  /// for source types whose pointer is device-local.
  bool canResolveOnThisDevice(MediaItem item);

  /// Resolves [item] to a displayable handle.
  Future<MediaSourceData> resolve(MediaItem item);

  /// Resolves a thumbnail-sized representation of [item]. Default
  /// implementation returns the same handle as [resolve]; resolvers with
  /// native thumbnail APIs override.
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) =>
      resolve(item);

  /// Extracts EXIF / format metadata from [item]. Called once at link time;
  /// results are stored on the [MediaItem] row by callers.
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item);

  /// Performs a lightweight existence check against [item].
  Future<VerifyResult> verify(MediaItem item);
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/features/media/domain/services/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/media/domain/services/media_source_resolver.dart
git add lib/features/media/domain/services/media_source_resolver.dart
git commit -m "feat(media): add MediaSourceResolver abstract interface"
```

---

## Task 13: `MediaSourceResolverRegistry`

**Files:**
- Create: `lib/features/media/data/services/media_source_resolver_registry.dart`
- Test: `test/features/media/data/services/media_source_resolver_registry_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/media_source_resolver_registry_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _Fake implements MediaSourceResolver {
  _Fake(this.sourceType);
  @override
  final MediaSourceType sourceType;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(MediaItem item, {required Size target}) =>
      resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.notFound;
}

void main() {
  test('lookup returns registered resolver', () {
    final reg = MediaSourceResolverRegistry({
      MediaSourceType.platformGallery: _Fake(MediaSourceType.platformGallery),
    });
    expect(reg.resolverFor(MediaSourceType.platformGallery), isA<_Fake>());
  });

  test('lookup throws on missing resolver', () {
    final reg = MediaSourceResolverRegistry(const {});
    expect(
      () => reg.resolverFor(MediaSourceType.localFile),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/services/media_source_resolver_registry_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the registry**

Create `lib/features/media/data/services/media_source_resolver_registry.dart`:

```dart
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';

class MediaSourceResolverRegistry {
  final Map<MediaSourceType, MediaSourceResolver> _resolvers;

  MediaSourceResolverRegistry(Map<MediaSourceType, MediaSourceResolver> resolvers)
      : _resolvers = Map.unmodifiable(resolvers);

  MediaSourceResolver resolverFor(MediaSourceType type) {
    final resolver = _resolvers[type];
    if (resolver == null) {
      throw UnsupportedError(
        'No MediaSourceResolver registered for $type. '
        'This is a programmer error — register the resolver in app startup.',
      );
    }
    return resolver;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/data/services/media_source_resolver_registry_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/ test/features/media/data/services/
git add lib/features/media/data/services/media_source_resolver_registry.dart test/features/media/data/services/media_source_resolver_registry_test.dart
git commit -m "feat(media): add MediaSourceResolverRegistry"
```

---

## Task 14: `PlatformGalleryResolver`

**Files:**
- Create: `lib/features/media/data/resolvers/platform_gallery_resolver.dart`
- Test: `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`

This resolver wraps the existing `photo_manager` flow. The goal is to extract the existing logic from current display callsites into a single resolver — *not* to reimplement.

Search the codebase for `photo_manager` usage with `grep -rn "photo_manager" lib/features/media/` and inspect the existing services that load gallery bytes (likely `lib/features/media/data/services/photo_picker_service_*.dart` and the `resolved_asset_providers.dart`). The resolver delegates to those services.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/resolvers/platform_gallery_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _gallery({String? assetId, String? originDeviceId}) => MediaItem(
      id: 'x',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: assetId,
      originDeviceId: originDeviceId,
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  test('canResolveOnThisDevice is always true for gallery items', () {
    final r = PlatformGalleryResolver();
    expect(r.canResolveOnThisDevice(_gallery(assetId: 'A')), isTrue);
    expect(r.canResolveOnThisDevice(_gallery(originDeviceId: 'other')), isTrue);
  });

  test('resolve returns Unavailable.notFound when assetId missing', () async {
    final r = PlatformGalleryResolver();
    final data = await r.resolve(_gallery(assetId: null));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/resolvers/platform_gallery_resolver_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the resolver**

Create `lib/features/media/data/resolvers/platform_gallery_resolver.dart`:

```dart
import 'dart:ui' show Size;

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.platformGallery] items via [photo_manager].
class PlatformGalleryResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final bytes = await asset.originBytes;
    if (bytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: bytes);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final thumbBytes = await asset.thumbnailDataWithSize(
      ThumbnailSize(target.width.toInt(), target.height.toInt()),
    );
    if (thumbBytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: thumbBytes);
  }

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return null;
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    final ll = await asset.latlngAsync();
    return MediaSourceMetadata(
      takenAt: asset.createDateTime,
      latitude: ll.latitude == 0.0 ? null : ll.latitude,
      longitude: ll.longitude == 0.0 ? null : ll.longitude,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.duration > 0 ? asset.duration : null,
      mimeType: asset.mimeType ?? 'application/octet-stream',
    );
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return VerifyResult.notFound;
    final asset = await AssetEntity.fromId(assetId);
    return asset == null ? VerifyResult.notFound : VerifyResult.available;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/data/resolvers/platform_gallery_resolver_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/resolvers/platform_gallery_resolver.dart test/features/media/data/resolvers/platform_gallery_resolver_test.dart
git add lib/features/media/data/resolvers/platform_gallery_resolver.dart test/features/media/data/resolvers/platform_gallery_resolver_test.dart
git commit -m "feat(media): add PlatformGalleryResolver"
```

---

## Task 15: `SignatureResolver`

**Files:**
- Create: `lib/features/media/data/resolvers/signature_resolver.dart`
- Test: `test/features/media/data/resolvers/signature_resolver_test.dart`

Signatures live as either `imageData` BLOB or as a file at `filePath`. The resolver returns the appropriate `MediaSourceData` variant.

Note: signature rows don't currently flow through `MediaItem.imageData` because that field isn't on the entity (only on the Drift row). Read the actual signature widgets (search `grep -rn "instructorSignature\|signature_type" lib/features/media/`) to confirm where the BLOB is read; if the entity doesn't expose `imageData`, add a `Uint8List? imageData` field to `MediaItem` first (mirror the existing nullable-field pattern from Task 8).

- [ ] **Step 1: Audit signature reads**

```bash
grep -rn "instructorSignature\|imageData\|signerName" lib/features/media/ | head
```

If `MediaItem.imageData` does not yet exist, add it as a `final Uint8List? imageData;` field with `copyWith` support, and have `MediaRepository._mapRowToMediaItem()` populate it from `mediaRow.imageData` (a separate fix-it task if needed — capture as Step 1a).

- [ ] **Step 1a (conditional): Expose `imageData` on `MediaItem`** (only if absent)

Add to `lib/features/media/domain/entities/media_item.dart`:

```dart
import 'dart:typed_data';

// ...inside MediaItem:
  final Uint8List? imageData;
```

Add to constructor params, copyWith params, copyWith body, and `props` (mirroring Task 8). Wire into `MediaRepository._mapRowToMediaItem()` and `createMedia()` (`Value(item.imageData)`).

- [ ] **Step 2: Write the failing test**

Create `test/features/media/data/resolvers/signature_resolver_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _signature({
  Uint8List? imageData,
  String? filePath,
}) => MediaItem(
      id: 'x',
      mediaType: MediaType.instructorSignature,
      sourceType: MediaSourceType.signature,
      imageData: imageData,
      filePath: filePath,
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  test('returns BytesData when imageData is present', () async {
    final r = SignatureResolver();
    final bytes = Uint8List.fromList([1, 2, 3]);
    final data = await r.resolve(_signature(imageData: bytes));
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, bytes);
  });

  test('returns Unavailable.notFound when neither blob nor path is set',
      () async {
    final r = SignatureResolver();
    final data = await r.resolve(_signature());
    expect(data, isA<UnavailableData>());
  });
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
flutter test test/features/media/data/resolvers/signature_resolver_test.dart
```

Expected: FAIL.

- [ ] **Step 4: Implement the resolver**

Create `lib/features/media/data/resolvers/signature_resolver.dart`:

```dart
import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.signature] items.
///
/// Signatures are stored either inline as a BLOB on the media row or as a
/// file at [MediaItem.filePath]. BLOB takes precedence when present.
class SignatureResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.signature;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    if (item.imageData != null && item.imageData!.isNotEmpty) {
      return BytesData(bytes: item.imageData!);
    }
    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return FileData(file: file);
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
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final data = await resolve(item);
    return data is UnavailableData
        ? VerifyResult.notFound
        : VerifyResult.available;
  }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
flutter test test/features/media/data/resolvers/signature_resolver_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/resolvers/signature_resolver.dart test/features/media/data/resolvers/signature_resolver_test.dart
git add lib/features/media/data/resolvers/signature_resolver.dart test/features/media/data/resolvers/signature_resolver_test.dart
git commit -m "feat(media): add SignatureResolver"
```

---

## Task 16: Wire the Registry Through Riverpod

**Files:**
- Create: `lib/features/media/presentation/providers/media_resolver_providers.dart`

- [ ] **Step 1: Create the providers file**

Create `lib/features/media/presentation/providers/media_resolver_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

final platformGalleryResolverProvider =
    Provider((ref) => PlatformGalleryResolver());

final signatureResolverProvider = Provider((ref) => SignatureResolver());

final mediaSourceResolverRegistryProvider =
    Provider<MediaSourceResolverRegistry>((ref) {
  return MediaSourceResolverRegistry({
    MediaSourceType.platformGallery: ref.watch(platformGalleryResolverProvider),
    MediaSourceType.signature: ref.watch(signatureResolverProvider),
  });
});
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/features/media/presentation/providers/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
dart format lib/features/media/presentation/providers/media_resolver_providers.dart
git add lib/features/media/presentation/providers/media_resolver_providers.dart
git commit -m "feat(media): register media source resolver registry as a provider"
```

---

## Task 17: `UnavailableMediaPlaceholder` Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart`
- Modify: existing `lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart` (delete after refactor — Task 19)
- Test: `test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart`

- [ ] **Step 1: Read existing widget for visual style cues**

```bash
cat lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart
```

Note the spacing, icon usage, and color scheme so the new widget matches the existing visual language.

- [ ] **Step 2: Write the failing widget test**

Create `test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

void main() {
  testWidgets('renders message for notFound', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.notFound),
        ),
      ),
    ));
    expect(find.textContaining('not found'), findsOneWidget);
  });

  testWidgets('renders origin device label for fromOtherDevice', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UnavailableMediaPlaceholder(
          data: UnavailableData(
            kind: UnavailableKind.fromOtherDevice,
            originDeviceLabel: "Eric's iPhone",
          ),
        ),
      ),
    ));
    expect(find.textContaining("Eric's iPhone"), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 4: Implement the widget**

Create `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

class UnavailableMediaPlaceholder extends StatelessWidget {
  final UnavailableData data;
  final double iconSize;

  const UnavailableMediaPlaceholder({
    super.key,
    required this.data,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(data.kind), size: iconSize, color: scheme.outline),
          const SizedBox(height: 4),
          Text(
            _messageFor(data),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(UnavailableKind kind) => switch (kind) {
        UnavailableKind.notFound => Icons.broken_image_outlined,
        UnavailableKind.unauthenticated => Icons.lock_outline,
        UnavailableKind.signInRequired => Icons.lock_outline,
        UnavailableKind.fromOtherDevice => Icons.devices_other,
        UnavailableKind.networkError => Icons.cloud_off_outlined,
      };

  String _messageFor(UnavailableData d) {
    if (d.userMessage != null) return d.userMessage!;
    return switch (d.kind) {
      UnavailableKind.notFound => 'File not found',
      UnavailableKind.unauthenticated => 'Sign in to view',
      UnavailableKind.signInRequired => 'Sign in to view',
      UnavailableKind.fromOtherDevice =>
        d.originDeviceLabel != null
            ? 'From ${d.originDeviceLabel}'
            : 'From another device',
      UnavailableKind.networkError => "Couldn't connect",
    };
  }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/presentation/widgets/unavailable_media_placeholder.dart test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart
git add lib/features/media/presentation/widgets/unavailable_media_placeholder.dart test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart
git commit -m "feat(media): add UnavailableMediaPlaceholder widget"
```

---

## Task 18: `MediaItemView` Universal Display Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/media_item_view.dart`
- Test: `test/features/media/presentation/widgets/media_item_view_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/media/presentation/widgets/media_item_view_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';

class _StubResolver implements MediaSourceResolver {
  _StubResolver(this._data, this.sourceType);
  final MediaSourceData _data;
  @override
  final MediaSourceType sourceType;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async => _data;
  @override
  Future<MediaSourceData> resolveThumbnail(MediaItem item, {required Size target}) =>
      resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem _item() => MediaItem(
      id: 'x',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  testWidgets('renders Image.memory for BytesData', (tester) async {
    final bytes = Uint8List.fromList(List.filled(10, 0));
    final stub = _StubResolver(BytesData(bytes: bytes), MediaSourceType.platformGallery);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry(
            {MediaSourceType.platformGallery: stub},
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: MediaItemView(item: _item()))),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders UnavailableMediaPlaceholder for UnavailableData',
      (tester) async {
    final stub = _StubResolver(
      const UnavailableData(kind: UnavailableKind.notFound),
      MediaSourceType.platformGallery,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry(
            {MediaSourceType.platformGallery: stub},
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: MediaItemView(item: _item()))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('not found'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/media_item_view_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/media/presentation/widgets/media_item_view.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

/// Universal display widget for any [MediaItem] regardless of its source type.
///
/// Resolves the item via the [mediaSourceResolverRegistryProvider] and
/// renders the appropriate Flutter widget for the resulting [MediaSourceData]
/// variant.
class MediaItemView extends ConsumerWidget {
  final MediaItem item;
  final BoxFit fit;
  final Size? targetSize;
  final bool thumbnail;

  const MediaItemView({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.targetSize,
    this.thumbnail = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(mediaSourceResolverRegistryProvider);
    final resolver = registry.resolverFor(item.sourceType);

    final future = thumbnail && targetSize != null
        ? resolver.resolveThumbnail(item, target: targetSize!)
        : resolver.resolve(item);

    return FutureBuilder<MediaSourceData>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _ShimmerThumbnail();
        }
        final data = snapshot.data!;
        return switch (data) {
          FileData(file: final f) => Image.file(f, fit: fit),
          NetworkData(url: final u, headers: final h) => CachedNetworkImage(
              imageUrl: u.toString(),
              httpHeaders: h,
              fit: fit,
              placeholder: (_, __) => const _ShimmerThumbnail(),
              errorWidget: (_, __, ___) => const UnavailableMediaPlaceholder(
                data: UnavailableData(kind: UnavailableKind.networkError),
              ),
            ),
          BytesData(bytes: final b) => Image.memory(b, fit: fit),
          UnavailableData() => UnavailableMediaPlaceholder(data: data),
        };
      },
    );
  }
}

class _ShimmerThumbnail extends StatelessWidget {
  const _ShimmerThumbnail();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/media_item_view_test.dart
```

Expected: PASS. (If `cached_network_image` is not in `pubspec.yaml`, add it: `flutter pub add cached_network_image`.)

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/media_item_view.dart test/features/media/presentation/widgets/media_item_view_test.dart pubspec.yaml pubspec.lock
git add lib/features/media/presentation/widgets/media_item_view.dart test/features/media/presentation/widgets/media_item_view_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(media): add MediaItemView universal display widget"
```

---

## Task 19: Refactor `dive_media_section.dart` to Use `MediaItemView`

**Files:**
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`

This is the highest-traffic display callsite and the highest-risk change. Read the file end-to-end before editing.

- [ ] **Step 1: Locate the per-item rendering**

```bash
grep -n "Image\|AssetEntityImage\|FutureBuilder\|UnavailablePhoto" lib/features/media/presentation/widgets/dive_media_section.dart
```

The grid renders each `MediaItem` via some combination of `AssetEntityImage` (from `photo_manager`) for gallery photos and the existing `UnavailablePhotoPlaceholder` for orphans. Find the inner builder that produces a `Widget` per `MediaItem`.

- [ ] **Step 2: Replace the per-item rendering with `MediaItemView`**

For the section that previously did something like:

```dart
return AssetEntityImage(
  asset,
  thumbnailSize: const ThumbnailSize.square(200),
  fit: BoxFit.cover,
);
```

Replace with:

```dart
return MediaItemView(
  item: media,
  thumbnail: true,
  targetSize: const Size(200, 200),
  fit: BoxFit.cover,
);
```

Add the import at the top:

```dart
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
```

Remove imports for `AssetEntityImage` / direct `photo_manager` usage if they become unused after the refactor.

- [ ] **Step 3: Update the orphan placeholder usage**

Replace any `UnavailablePhotoPlaceholder(...)` references with `UnavailableMediaPlaceholder(...)` and pass an explicit `UnavailableData(...)` (the `MediaItemView` handles this automatically when its resolver returns `UnavailableData`, so most direct callsites can be removed entirely).

- [ ] **Step 4: Run analyzer and tests**

```bash
flutter analyze lib/features/media/presentation/widgets/dive_media_section.dart
flutter test test/features/media/
```

Expected: clean analyze, tests PASS.

- [ ] **Step 5: Manual smoke test**

```bash
flutter run -d macos
```

Open a dive that has linked gallery photos, verify they render. Open a dive with a known orphan photo, verify the placeholder shows the right message.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/presentation/widgets/dive_media_section.dart
git add lib/features/media/presentation/widgets/dive_media_section.dart
git commit -m "refactor(media): use MediaItemView in dive media section"
```

---

## Task 20: Refactor `photo_viewer_page.dart` to Use `MediaItemView`

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_viewer_page.dart`

- [ ] **Step 1: Read the page**

```bash
grep -n "Image\|AssetEntityImage\|PhotoView\|FutureBuilder" lib/features/media/presentation/pages/photo_viewer_page.dart
```

Find the body widget that renders the full-size photo (likely inside a `PhotoView`/`InteractiveViewer`).

- [ ] **Step 2: Replace with `MediaItemView`**

Where the page currently builds `Image.file(...)`, `AssetEntityImage(...)`, or any direct image widget for the current `MediaItem`, replace with:

```dart
MediaItemView(
  item: item,
  fit: BoxFit.contain,
)
```

The `InteractiveViewer` / `PhotoView` wrapper around it stays — `MediaItemView` returns the `Image` widget for both gallery and (in later phases) network/local sources, all of which `InteractiveViewer` handles.

Add import:

```dart
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
```

- [ ] **Step 3: Run analyzer and tests**

```bash
flutter analyze lib/features/media/presentation/pages/photo_viewer_page.dart
flutter test test/features/media/
```

Expected: clean analyze, tests PASS.

- [ ] **Step 4: Manual smoke test**

```bash
flutter run -d macos
```

Tap a gallery photo on a dive detail page → confirm full viewer opens, pinch-zoom works, swipe between photos works.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/pages/photo_viewer_page.dart
git add lib/features/media/presentation/pages/photo_viewer_page.dart
git commit -m "refactor(media): use MediaItemView in photo viewer page"
```

---

## Task 21: Refactor `trip_photo_viewer_page.dart` to Use `MediaItemView`

**Files:**
- Modify: `lib/features/media/presentation/pages/trip_photo_viewer_page.dart`

Same pattern as Task 20.

- [ ] **Step 1: Locate per-photo rendering**

```bash
grep -n "Image\|AssetEntityImage" lib/features/media/presentation/pages/trip_photo_viewer_page.dart
```

- [ ] **Step 2: Replace with `MediaItemView`**

Same substitution as Task 20.

- [ ] **Step 3: Analyzer + tests**

```bash
flutter analyze lib/features/media/presentation/pages/trip_photo_viewer_page.dart
flutter test test/features/media/
```

- [ ] **Step 4: Commit**

```bash
dart format lib/features/media/presentation/pages/trip_photo_viewer_page.dart
git add lib/features/media/presentation/pages/trip_photo_viewer_page.dart
git commit -m "refactor(media): use MediaItemView in trip photo viewer"
```

---

## Task 22: Delete the Legacy `unavailable_photo_placeholder.dart`

**Files:**
- Delete: `lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart`

- [ ] **Step 1: Confirm no remaining imports**

```bash
grep -rn "unavailable_photo_placeholder\|UnavailablePhotoPlaceholder" lib/ test/
```

Expected: no matches.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/features/media/presentation/widgets/unavailable_photo_placeholder.dart
```

- [ ] **Step 3: Run analyzer + tests**

```bash
flutter analyze
flutter test
```

Expected: clean, PASS.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(media): remove legacy UnavailablePhotoPlaceholder"
```

---

## Task 23: Refactor `photo_picker_page.dart` Into a Tab Shell

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_picker_page.dart`

Wrap the existing gallery picker UI in a `DefaultTabController` with three tabs: **Gallery** (existing UI), **Files** (placeholder), **URL** (placeholder). The two placeholder tabs are gated behind a debug flag — by default only Gallery is visible to users.

- [ ] **Step 1: Read the page**

```bash
sed -n '1,80p' lib/features/media/presentation/pages/photo_picker_page.dart
```

Identify the root `Scaffold` and its `body`. The existing body becomes the Gallery tab.

- [ ] **Step 2: Wrap in `DefaultTabController` and add placeholder tabs**

Restructure the build method so the body becomes:

```dart
final showHiddenTabs = ref.watch(mediaPickerHiddenTabsProvider);

return DefaultTabController(
  length: showHiddenTabs ? 3 : 1,
  child: Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.media_photoPicker_title),
      bottom: showHiddenTabs
          ? TabBar(
              tabs: [
                Tab(text: context.l10n.media_photoPicker_tabGallery),
                Tab(text: context.l10n.media_photoPicker_tabFiles),
                Tab(text: context.l10n.media_photoPicker_tabUrl),
              ],
            )
          : null,
    ),
    body: showHiddenTabs
        ? TabBarView(
            children: [
              _galleryTab(context, ref),
              const _PlaceholderTab(message: 'Coming in Phase 2'),
              const _PlaceholderTab(message: 'Coming in Phase 3'),
            ],
          )
        : _galleryTab(context, ref),
  ),
);
```

Move the existing build body into a `Widget _galleryTab(BuildContext context, WidgetRef ref) { ... }` helper method.

Add the placeholder widget:

```dart
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add the `mediaPickerHiddenTabsProvider`**

In `lib/features/media/presentation/providers/media_resolver_providers.dart` (or a new `media_picker_providers.dart`), add:

```dart
/// Whether to show the placeholder Files / URL tabs in the picker. Off
/// by default; enabled via Settings → Data → Media Sources → Diagnostics.
final mediaPickerHiddenTabsProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 4: Add l10n keys**

In your ARB file (`lib/l10n/app_en.arb` or wherever the existing l10n entries live), add:

```json
"media_photoPicker_tabGallery": "Gallery",
"media_photoPicker_tabFiles": "Files",
"media_photoPicker_tabUrl": "URL"
```

Run codegen:

```bash
flutter gen-l10n
```

- [ ] **Step 5: Run tests + analyzer**

```bash
flutter analyze lib/features/media/presentation/pages/photo_picker_page.dart
flutter test test/features/media/
```

Expected: clean, PASS.

- [ ] **Step 6: Manual smoke test**

```bash
flutter run -d macos
```

Open the photo picker → confirm only the Gallery is visible (no tab bar). Toggle the `mediaPickerHiddenTabsProvider` (manually via dev tools) → confirm two placeholder tabs appear with their messages.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media/presentation/pages/photo_picker_page.dart lib/features/media/presentation/providers/
git add lib/features/media/presentation/pages/photo_picker_page.dart lib/features/media/presentation/providers/ lib/l10n/
git commit -m "refactor(media): wrap photo picker in tab shell"
```

---

## Task 24: iOS Native `LocalMediaHandler.swift`

**Files:**
- Create: `ios/Runner/LocalMediaHandler.swift`
- Modify: `ios/Runner/AppDelegate.swift` to register the handler
- Modify: `ios/Runner/Runner.xcodeproj` (Xcode automatically adds the new Swift file when project file is regenerated)

- [ ] **Step 1: Read the existing handler for the channel-registration pattern**

Read [ios/Runner/MetadataWriteHandler.swift](../../ios/Runner/MetadataWriteHandler.swift) and skim `ios/Runner/AppDelegate.swift` to see how `MetadataWriteHandler` is instantiated.

- [ ] **Step 2: Create `LocalMediaHandler.swift`**

Create `ios/Runner/LocalMediaHandler.swift`:

```swift
import Flutter
import Foundation

/// Handles security-scoped bookmark creation and resolution for the
/// Media Source Extension feature.
///
/// Methods:
///   - createBookmark(filePath: String) -> bookmarkRef: String
///   - resolveBookmark(bookmarkRef: String) -> filePath: String
///   - releaseBookmark(bookmarkRef: String) -> Void
///
/// Bookmark blobs are stored in flutter_secure_storage by the Dart side;
/// this handler returns/accepts the opaque bookmarkRef used as the key.
class LocalMediaHandler: NSObject {
    private let channel: FlutterMethodChannel
    /// Bookmark blob storage on the native side, keyed by bookmarkRef.
    /// In production these blobs are written into the keychain via a Dart-side
    /// flutter_secure_storage call after this handler returns the blob.
    private var pending: [String: Data] = [:]
    /// Currently-active security-scoped URLs that callers must release.
    private var active: [String: URL] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.submersion.app/local_media",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createBookmark":
            guard let args = call.arguments as? [String: Any],
                  let path = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            createBookmark(filePath: path, result: result)
        case "resolveBookmark":
            guard let args = call.arguments as? [String: Any],
                  let blob = args["bookmarkBlob"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "bookmarkBlob required", details: nil))
                return
            }
            resolveBookmark(blob: blob.data, result: result)
        case "releaseBookmark":
            guard let args = call.arguments as? [String: Any],
                  let key = args["bookmarkRef"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "bookmarkRef required", details: nil))
                return
            }
            releaseBookmark(key: key, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createBookmark(filePath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: filePath)
        do {
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            // Return the raw bookmark blob to Dart; Dart side stores it in
            // flutter_secure_storage and provides it back on resolveBookmark.
            result(FlutterStandardTypedData(bytes: data))
        } catch {
            result(FlutterError(
                code: "BOOKMARK_FAILED",
                message: "Could not create bookmark: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    private func resolveBookmark(blob: Data, result: @escaping FlutterResult) {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: blob,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard url.startAccessingSecurityScopedResource() else {
                result(FlutterError(
                    code: "ACCESS_DENIED",
                    message: "Security-scoped resource access denied",
                    details: nil
                ))
                return
            }
            // Caller must call releaseBookmark with this ref later.
            let ref = UUID().uuidString
            active[ref] = url
            result([
                "bookmarkRef": ref,
                "filePath": url.path,
                "stale": stale,
            ])
        } catch {
            result(FlutterError(
                code: "RESOLVE_FAILED",
                message: "Could not resolve bookmark: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    private func releaseBookmark(key: String, result: @escaping FlutterResult) {
        if let url = active.removeValue(forKey: key) {
            url.stopAccessingSecurityScopedResource()
        }
        result(nil)
    }
}
```

- [ ] **Step 3: Register in `AppDelegate.swift`**

Open `ios/Runner/AppDelegate.swift`. Find where `MetadataWriteHandler` is instantiated (it's stored as a property to keep it alive). Add a parallel property and instantiation:

```swift
private var localMediaHandler: LocalMediaHandler?
```

In `application(_:didFinishLaunchingWithOptions:)` after the existing handler is set up, add:

```swift
if let controller = window?.rootViewController as? FlutterViewController {
    localMediaHandler = LocalMediaHandler(messenger: controller.binaryMessenger)
}
```

- [ ] **Step 4: Build and run on macOS to confirm channel registration**

```bash
flutter run -d macos
```

Expected: app launches without channel-registration errors. (Functional testing happens in Task 26.)

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/LocalMediaHandler.swift ios/Runner/AppDelegate.swift
git commit -m "feat(ios): add LocalMediaHandler for security-scoped bookmarks"
```

---

## Task 25: Android Native `LocalMediaHandler.kt`

**Files:**
- Create: `android/app/src/main/kotlin/<package-path>/LocalMediaHandler.kt`
- Modify: `android/app/src/main/kotlin/<package-path>/MainActivity.kt`

Find your package path with `find android/app/src/main/kotlin -name '*.kt'`. The `<package-path>` is whatever directory `MainActivity.kt` lives in.

- [ ] **Step 1: Locate `MainActivity.kt`**

```bash
find android/app/src/main/kotlin -name 'MainActivity.kt'
```

Note the directory.

- [ ] **Step 2: Create `LocalMediaHandler.kt`**

Create the file in the same directory as `MainActivity.kt`:

```kotlin
package <same package as MainActivity>

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Handles persistable URI permission management for the Media Source
 * Extension feature.
 *
 * Methods:
 *   - takePersistableUri(uri: String): String — bookmarkRef (the URI itself)
 *   - resolveBookmark(bookmarkRef: String): String? — file path or null
 *   - releaseBookmark(bookmarkRef: String): Unit
 *   - listPersistedUris(): List<String> — for the Settings page UI
 */
class LocalMediaHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodCallHandler {

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takePersistableUri" -> takePersistableUri(call, result)
            "resolveBookmark" -> resolveBookmark(call, result)
            "releaseBookmark" -> releaseBookmark(call, result)
            "listPersistedUris" -> listPersistedUris(result)
            else -> result.notImplemented()
        }
    }

    private fun takePersistableUri(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
            ?: return result.error("INVALID_ARGS", "uri required", null)
        val uri = Uri.parse(uriStr)
        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, flags)
            result.success(uriStr)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        }
    }

    private fun resolveBookmark(call: MethodCall, result: MethodChannel.Result) {
        val ref = call.argument<String>("bookmarkRef")
            ?: return result.error("INVALID_ARGS", "bookmarkRef required", null)
        val uri = Uri.parse(ref)
        val df = DocumentFile.fromSingleUri(context, uri)
        if (df == null || !df.exists()) {
            result.success(null)
            return
        }
        // We return the URI string itself; Flutter side reads bytes via
        // ContentResolver-aware code (e.g., file_picker's `readAsBytes`).
        result.success(uriStr(uri))
    }

    private fun releaseBookmark(call: MethodCall, result: MethodChannel.Result) {
        val ref = call.argument<String>("bookmarkRef")
            ?: return result.error("INVALID_ARGS", "bookmarkRef required", null)
        val uri = Uri.parse(ref)
        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            context.contentResolver.releasePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) {
            // Already released — harmless.
        }
        result.success(null)
    }

    private fun listPersistedUris(result: MethodChannel.Result) {
        val uris = context.contentResolver.persistedUriPermissions.map { it.uri.toString() }
        result.success(uris)
    }

    private fun uriStr(uri: Uri): String = uri.toString()

    companion object {
        const val CHANNEL = "com.submersion.app/local_media"
    }
}
```

- [ ] **Step 3: Register in `MainActivity.kt`**

Edit `MainActivity.kt`. Add the import:

```kotlin
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
```

Override `configureFlutterEngine` (or extend it if already overridden):

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        LocalMediaHandler.CHANNEL,
    )
    LocalMediaHandler(applicationContext, channel)
}
```

- [ ] **Step 4: Add the documentfile dependency**

In `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'androidx.documentfile:documentfile:1.0.1'
}
```

- [ ] **Step 5: Build to confirm compilation**

```bash
flutter build apk --debug
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/ android/app/build.gradle
git commit -m "feat(android): add LocalMediaHandler for persistable URI perms"
```

---

## Task 26: `LocalMediaPlatform` Dart Wrapper

**Files:**
- Create: `lib/features/media/data/services/local_media_platform.dart`
- Test: `test/features/media/data/services/local_media_platform_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/local_media_platform_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.submersion.app/local_media');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createBookmark':
          return Uint8List.fromList([1, 2, 3]);
        case 'resolveBookmark':
          return {
            'bookmarkRef': 'session-1',
            'filePath': '/Users/me/x.jpg',
            'stale': false,
          };
        case 'releaseBookmark':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createBookmark returns blob bytes', () async {
    final platform = LocalMediaPlatform();
    final blob = await platform.createBookmark('/Users/me/x.jpg');
    expect(blob, isA<Uint8List>());
    expect(blob, [1, 2, 3]);
  });

  test('resolveBookmark returns ref + path', () async {
    final platform = LocalMediaPlatform();
    final r = await platform.resolveBookmark(Uint8List.fromList([1, 2, 3]));
    expect(r.bookmarkRef, 'session-1');
    expect(r.filePath, '/Users/me/x.jpg');
    expect(r.stale, false);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/data/services/local_media_platform_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the wrapper**

Create `lib/features/media/data/services/local_media_platform.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class ResolvedBookmark {
  final String bookmarkRef;
  final String filePath;
  final bool stale;
  const ResolvedBookmark({
    required this.bookmarkRef,
    required this.filePath,
    required this.stale,
  });
}

/// Dart wrapper around the platform-channel for security-scoped bookmarks
/// (iOS/macOS) and persistable URI permissions (Android).
class LocalMediaPlatform {
  static const _channel = MethodChannel('com.submersion.app/local_media');

  /// iOS/macOS only. Creates a security-scoped bookmark and returns the
  /// raw bookmark blob (callers store this in the keychain).
  Future<Uint8List> createBookmark(String filePath) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'createBookmark is only supported on iOS/macOS',
      );
    }
    final result = await _channel.invokeMethod<Uint8List>(
      'createBookmark',
      {'filePath': filePath},
    );
    if (result == null) {
      throw StateError('createBookmark returned null');
    }
    return result;
  }

  /// iOS/macOS. Starts security-scoped resource access for the bookmark and
  /// returns a session ref + the resolved file path. Caller must invoke
  /// [releaseBookmark] when done.
  Future<ResolvedBookmark> resolveBookmark(Uint8List blob) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'resolveBookmark is only supported on iOS/macOS',
      );
    }
    final r = await _channel.invokeMapMethod<String, dynamic>(
      'resolveBookmark',
      {'bookmarkBlob': blob},
    );
    if (r == null) throw StateError('resolveBookmark returned null');
    return ResolvedBookmark(
      bookmarkRef: r['bookmarkRef'] as String,
      filePath: r['filePath'] as String,
      stale: (r['stale'] as bool?) ?? false,
    );
  }

  Future<void> releaseBookmark(String bookmarkRef) async {
    await _channel.invokeMethod<void>(
      'releaseBookmark',
      {'bookmarkRef': bookmarkRef},
    );
  }

  /// Android only. Calls takePersistableUriPermission and returns the URI
  /// string (which becomes the bookmarkRef stored in the media row).
  Future<String> takePersistableUri(String uri) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'takePersistableUri is only supported on Android',
      );
    }
    final r = await _channel.invokeMethod<String>(
      'takePersistableUri',
      {'uri': uri},
    );
    if (r == null) throw StateError('takePersistableUri returned null');
    return r;
  }

  /// Android only. Lists all persisted URI permissions for the budget UI.
  Future<List<String>> listPersistedUris() async {
    if (!Platform.isAndroid) return const [];
    final r = await _channel.invokeListMethod<String>('listPersistedUris');
    return r ?? const [];
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/features/media/data/services/local_media_platform_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/local_media_platform.dart test/features/media/data/services/local_media_platform_test.dart
git add lib/features/media/data/services/local_media_platform.dart test/features/media/data/services/local_media_platform_test.dart
git commit -m "feat(media): add LocalMediaPlatform Dart wrapper"
```

---

## Task 27: Wire `originDeviceId` Into Repository Creates

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Test: `test/features/media/data/media_repository_test.dart`

The current `createMedia()` doesn't populate `originDeviceId`. Find the existing device-identity helper (search `grep -rn "deviceId\|installationId" lib/core/`) and wire it in for source types whose pointer is device-local (`localFile`, `serviceConnector`).

- [ ] **Step 1: Find the device-identity helper**

```bash
grep -rn "deviceId\|installationId" lib/core/ | head
```

If a helper exists (e.g., `DeviceIdentityService`), use it. If not, add one — but defer that to a separate sub-task and use a stub UUID-per-app-launch for now (mark with `// TODO: wire to real device-identity service`).

- [ ] **Step 2: Extend the test**

Add to `test/features/media/data/media_repository_test.dart`:

```dart
  test('createMedia auto-populates originDeviceId for device-local sources',
      () async {
    final repo = MediaRepository();
    final created = await repo.createMedia(MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/x.jpg',
      // originDeviceId intentionally not set — repo should fill it in
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));
    expect(created.originDeviceId, isNotNull);
    expect(created.originDeviceId, isNotEmpty);
  });

  test('createMedia preserves caller-provided originDeviceId', () async {
    final repo = MediaRepository();
    final created = await repo.createMedia(MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/x.jpg',
      originDeviceId: 'mac-explicit',
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ));
    expect(created.originDeviceId, 'mac-explicit');
  });
```

- [ ] **Step 3: Run to verify it fails**

```bash
flutter test test/features/media/data/media_repository_test.dart
```

Expected: FAIL on the auto-populate test.

- [ ] **Step 4: Wire device-identity in `createMedia()`**

In `lib/features/media/data/repositories/media_repository.dart`, before the `MediaCompanion(...)` insert, compute the effective device id:

```dart
String? _effectiveOriginDeviceId(MediaItem item) {
  if (item.originDeviceId != null) return item.originDeviceId;
  // Only auto-populate for device-local sources.
  switch (item.sourceType) {
    case MediaSourceType.localFile:
    case MediaSourceType.serviceConnector:
      return DeviceIdentityService.instance.deviceId;
    case MediaSourceType.platformGallery:
    case MediaSourceType.networkUrl:
    case MediaSourceType.manifestEntry:
    case MediaSourceType.signature:
      return null;
  }
}
```

(Replace `DeviceIdentityService.instance.deviceId` with the actual helper found in Step 1; if none exists, fall back to a `_uuid.v4()` value cached as a static field on `MediaRepository` for the session.)

In `createMedia()`, replace `originDeviceId: Value(item.originDeviceId)` with:

```dart
              originDeviceId: Value(_effectiveOriginDeviceId(item)),
```

And update the returned `MediaItem` (the function returns `item`) so the caller sees the populated `originDeviceId`:

```dart
return item.copyWith(
  id: id,
  originDeviceId: _effectiveOriginDeviceId(item),
);
```

- [ ] **Step 5: Run to verify it passes**

```bash
flutter test test/features/media/data/media_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_test.dart
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_test.dart
git commit -m "feat(media): auto-populate originDeviceId for device-local sources"
```

---

## Task 28: Register New Tables as `noSync` in the Sync Engine

**Files:**
- Modify: whichever file declares the sync engine's table-allow-list (search `grep -rn "syncableTables\|noSync\|excludedTables" lib/core/`)

- [ ] **Step 1: Find the sync inclusion list**

```bash
grep -rn "syncableTables\|noSync\|excludedTables\|markRecordPending" lib/core/data/repositories/sync_repository.dart lib/core/services/sync/ | head -30
```

The sync system iterates `markRecordPending` calls per entity-type write. Tables that don't call `markRecordPending` from their repositories naturally don't sync. Verify this by reading the sync orchestrator (`lib/core/services/sync/`).

- [ ] **Step 2: Confirm new tables are not pulled into sync by default**

The new tables (`media_subscriptions`, `media_subscription_state`, `connector_accounts`, `network_credential_hosts`, `media_fetch_diagnostics`) have no repository writes yet, and Phase 1 doesn't add any. They will be naturally excluded.

If the sync engine has an explicit allow-list (e.g., a `Set<String> _syncEntityTypes`), confirm none of the new entity-type strings would be added inadvertently.

If an explicit per-entity sync rule exists, document the `noSync` rule for the new entity types in the same file. Example:

```dart
// In sync_repository.dart or wherever entity types are registered:
const Set<String> _localOnlyEntityTypes = {
  // Existing local-only entries…
  'media_subscription_state',
  'connector_accounts',
  'network_credential_hosts',
  'media_fetch_diagnostics',
};
```

If you cannot find an explicit allow-list, add an integration test that creates rows in each new table directly via `customStatement` and verifies they don't appear in the sync's pending-records query:

```dart
test('new local-only tables produce no sync events', () async {
  // ... create rows directly in each new table ...
  final pending = await syncRepo.getPendingRecords();
  expect(
    pending.where((r) =>
      r.entityType == 'connector_accounts' ||
      r.entityType == 'network_credential_hosts' ||
      r.entityType == 'media_subscription_state' ||
      r.entityType == 'media_fetch_diagnostics',
    ),
    isEmpty,
  );
});
```

- [ ] **Step 3: Run sync tests**

```bash
flutter test test/core/services/sync/
flutter test test/core/data/repositories/sync_repository_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit (only if changes were made)**

```bash
dart format lib/core/
git add lib/core/ test/core/
git commit -m "feat(sync): exclude phase-1 local-only tables from sync"
```

---

## Task 29: `MediaSourcesPage` + Settings Entry

**Files:**
- Create: `lib/features/media/presentation/pages/media_sources_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (the `_DataSectionContent` body)
- Modify: app's `go_router` route table (search `grep -rn "GoRoute\|go_router" lib/core/router/` or `lib/main.dart`)

- [ ] **Step 1: Create a stub `MediaSourcesPage`**

Create `lib/features/media/presentation/pages/media_sources_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Settings page listing all media sources. Phase 1 only renders the
/// platform photo library status; later phases append Local files, Network
/// Sources, Connected Services, and Diagnostics sections.
class MediaSourcesPage extends ConsumerWidget {
  const MediaSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Photo library'),
                  subtitle: Text('Apple Photos / Google Photos / iCloud'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Diagnostics'),
                  subtitle: Consumer(
                    builder: (context, ref, _) {
                      final shown = ref.watch(mediaPickerHiddenTabsProvider);
                      return Text(
                        shown
                            ? 'Hidden picker tabs visible'
                            : 'Show hidden picker tabs (debug)',
                      );
                    },
                  ),
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final shown = ref.watch(mediaPickerHiddenTabsProvider);
                      return Switch(
                        value: shown,
                        onChanged: (v) =>
                            ref.read(mediaPickerHiddenTabsProvider.notifier).state = v,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Register the route**

Find the existing settings routes in `lib/core/router/` (or wherever the router is configured). Add:

```dart
GoRoute(
  path: '/settings/media-sources',
  name: 'mediaSources',
  builder: (context, state) => const MediaSourcesPage(),
),
```

- [ ] **Step 3: Add the entry to `_DataSectionContent`**

In [lib/features/settings/presentation/pages/settings_page.dart](../../lib/features/settings/presentation/pages/settings_page.dart) inside `_DataSectionContent.build()`, append a new section after the existing "Data Tools" Card (around line 1914). Add an extra `_buildSectionHeader` and Card:

```dart
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Media'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Media Sources'),
                  subtitle: const Text('Photo library, files, URLs, services'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/media-sources'),
                ),
              ],
            ),
          ),
```

- [ ] **Step 4: Run analyzer + tests**

```bash
flutter analyze
flutter test
```

Expected: clean, PASS.

- [ ] **Step 5: Manual smoke test**

```bash
flutter run -d macos
```

Open Settings → Data → Media Sources. Confirm the page opens, shows Photo library and Diagnostics sections.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/media/presentation/pages/media_sources_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/core/router/
git add lib/features/media/presentation/pages/media_sources_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/core/router/
git commit -m "feat(media): add Media Sources settings page under Data"
```

---

## Task 30: Final Smoke Test + Pre-Push Verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: no errors, no warnings.

- [ ] **Step 3: Run dart format**

```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: exit code 0 (no files need reformatting).

- [ ] **Step 4: Manual smoke test on macOS**

```bash
flutter run -d macos
```

Walk through:

- Open a dive with linked gallery photos. Confirm thumbnails render.
- Tap a photo → confirm the full viewer opens with pinch-zoom.
- Long-press to enter multi-select → confirm bulk unlink works.
- Open Settings → Data → Media Sources → confirm the page renders.
- Toggle the Diagnostics switch → return to a dive → tap Add Photos → confirm the picker shows three tabs (Gallery + two placeholders).
- Toggle off → re-open picker → confirm only Gallery is visible.

- [ ] **Step 5: Manual smoke test on iOS Simulator**

```bash
flutter run -d "iPhone 15"
```

Repeat the dive media flow. Confirm channel registration succeeds (no native-side crash on launch).

- [ ] **Step 6: Manual smoke test on Android emulator**

```bash
flutter run -d emulator-5554
```

Repeat the dive media flow. Confirm channel registration succeeds.

- [ ] **Step 7: Final commit (if any final fixes were made)**

```bash
git status
# If any fix-it commits needed:
dart format lib/ test/
git add -u
git commit -m "chore(media): final lints + format pass for phase 1"
```

---

## Self-Review

Spec coverage matrix (each spec deliverable mapped to a task):

| Spec deliverable | Task |
|---|---|
| Drift schema migration with backfill | Tasks 1, 2, 3, 4 |
| `MediaSourceType` enum | Task 5 |
| `VerifyResult` and `MediaSourceMetadata` | Task 6 |
| `MediaSourceData` sealed class | Task 7 |
| `MediaItem` extension with new fields | Task 8 |
| Drift `Media` table mirror + new tables | Tasks 9, 10 |
| `MediaRepository` updated | Task 11 |
| `MediaSourceResolver` interface | Task 12 |
| `MediaSourceResolverRegistry` | Task 13 |
| `PlatformGalleryResolver` | Task 14 |
| `SignatureResolver` | Task 15 |
| Resolver Riverpod wiring | Task 16 |
| `UnavailableMediaPlaceholder` | Task 17 |
| `MediaItemView` | Task 18 |
| Refactor existing display callsites | Tasks 19, 20, 21 |
| Delete legacy placeholder | Task 22 |
| Picker page tab shell | Task 23 |
| iOS native channel | Task 24 |
| Android native channel | Task 25 |
| `LocalMediaPlatform` Dart wrapper | Task 26 |
| `originDeviceId` wiring | Task 27 |
| `noSync` registrations | Task 28 |
| Settings entry + `MediaSourcesPage` | Task 29 |
| Verification | Task 30 |

Phase 1 acceptance criteria from the spec are satisfied as follows:

- "Existing dive-photo flows work bit-for-bit identically to before" → covered by Task 30's smoke tests.
- "`flutter test` passes; `flutter analyze` clean" → Task 30 Steps 1–2.
- "New unit tests for MediaSourceType, MediaSourceData, the registry, the migration backfill, the iOS/Android bookmark channel" → Tasks 4, 5, 7, 13, 26.
- "One end-to-end integration test exercises a gallery photo add through the new abstraction" → covered by Task 18's widget test plus Task 19's manual smoke test.
- "Schema migration runs cleanly on a database snapshot containing real existing media rows" → Task 4's backfill test (using seeded rows).

Cross-cutting concerns:

- **Feature-flagged dual-display path**: not implemented as a separate flag; the `mediaPickerHiddenTabsProvider` plus the additive `MediaItemView` migration are the safety mechanism (Task 23).
- **`MediaSubscription` polling, network resolver, manifest parsers**: deferred to Phase 2/3 plans, not in scope for this plan.
- **`connector_*` framework**: deferred to Phase 4 plan.

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-25-media-source-extension-phase1.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
