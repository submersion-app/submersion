# Incremental Sync — Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the data-layer foundation for incremental changeset-log sync — two new Drift tables (schema v84) with their stores, the manifest model, the on-storage naming/layout, the base byte-chunker, and an in-memory fake `CloudStorageProvider` — all unit-tested, with **zero change to runtime sync behavior**.

**Architecture:** Approach A from the design spec (`docs/superpowers/specs/2026-06-14-incremental-sync-changeset-log-design.md`): each device publishes an append-only changeset log plus a periodic compacted base, on the unchanged `CloudStorageProvider` abstraction and HLC/LWW merge core. This phase builds only the passive pieces those later phases consume. New code lives in a `lib/core/services/sync/changeset_log/` package (one focused file per responsibility).

**Spec deviation (flagged for reconciliation):** the spec illustrates the layout as a per-device subfolder tree (`submersion-sync/v1/<deviceId>/…`). Subfolder *discovery* behaves differently across backends (S3 recursive prefix vs. Drive/iCloud folder children), so this plan implements the identical logical structure as a **flat, filename-encoded layout in the single existing sync folder** — `ssv1.<deviceId>.cs.<seq>.json`, `ssv1.<deviceId>.base.<baseSeq>.pNNNN`, `ssv1.<deviceId>.manifest.json`. This reuses the proven `listFiles(folder, namePattern)` path on every backend. Update §4 of the spec to match once this phase lands.

**Phase roadmap:** (1) Foundation ← *this plan*; (2) Serialization (HLC-watermark delta export, changeset/base build); (3) Write path; (4) Read path; (5) Resumability + compaction; (6) Restore + coexistence. Each later phase gets its own plan.

**Tech Stack:** Flutter, Drift ORM (codegen via `build_runner`), `crypto` (sha256), `flutter_test`.

---

### Task 1: Schema v84 — `SyncPeerCursors` and `LocalPublishStates` tables

**Files:**
- Modify: `lib/core/database/database.dart` (add 2 table classes after `DeletionLog` ~line 1367; register in `@DriftDatabase(tables: [...])` ~line 1535; bump `currentSchemaVersion` line 1570; add migration in `onUpgrade` after the `from < 83` block ~line 1969; bump `migrationStepCount` line 1693)
- Test: `test/core/database/migration_v84_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/migration_v84_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v84 schema includes sync_peer_cursors and local_publish_states', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['sync_peer_cursors', 'local_publish_states']));
  });

  test('sync_peer_cursors round-trips a row keyed by (peer, provider)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.syncPeerCursors).insert(SyncPeerCursorsCompanion(
          peerDeviceId: const Value('peer-1'),
          provider: const Value('s3'),
          baseSeqApplied: const Value(12),
          lastSeqApplied: const Value(20),
          updatedAt: const Value(111),
        ));
    final row = await (db.select(db.syncPeerCursors)
          ..where((t) => t.peerDeviceId.equals('peer-1') & t.provider.equals('s3')))
        .getSingle();
    expect(row.lastSeqApplied, 20);
    expect(row.baseSeqApplied, 12);
  });

  test('local_publish_states defaults headSeq and changesetBytesSinceBase to 0',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.localPublishStates).insert(
        LocalPublishStatesCompanion(provider: const Value('s3'), updatedAt: const Value(1)));
    final row = await (db.select(db.localPublishStates)
          ..where((t) => t.provider.equals('s3')))
        .getSingle();
    expect(row.headSeq, 0);
    expect(row.changesetBytesSinceBase, 0);
    expect(row.baseSeq, isNull);
  });

  test('v83 -> v84 upgrade creates both tables', () async {
    final native = NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 83');
    });
    final db = AppDatabase(native);
    addTearDown(db.close);
    // Force the migration to run by touching the database.
    await db.customSelect('SELECT 1').get();

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['sync_peer_cursors', 'local_publish_states']));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v84_test.dart`
Expected: compile error / FAIL — `syncPeerCursors` getter and `SyncPeerCursorsCompanion` do not exist yet.

- [ ] **Step 3: Add the two table classes**

In `lib/core/database/database.dart`, immediately after the `DeletionLog` class (~line 1367):

```dart
/// Per-peer download cursor: how far this device has consumed each peer's
/// changeset log. Scoped per provider so a backend switch starts fresh
/// (mirrors the v81 per-provider cursor lesson).
@DataClassName('SyncPeerCursor')
class SyncPeerCursors extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get provider => text()();
  IntColumn get baseSeqApplied => integer().nullable()();
  IntColumn get lastSeqApplied => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {peerDeviceId, provider};
}

/// This device's own published position in its changeset log, per provider.
/// Splits the old conflated lastSyncTimestamp: this is the upload side
/// (per-peer cursors are the download side).
@DataClassName('LocalPublishState')
class LocalPublishStates extends Table {
  TextColumn get provider => text()();
  IntColumn get baseSeq => integer().nullable()();
  IntColumn get basePartCount => integer().nullable()();
  IntColumn get baseBytes => integer().nullable()();
  IntColumn get headSeq => integer().withDefault(const Constant(0))();
  TextColumn get publishedHlcHigh => text().nullable()();
  IntColumn get changesetBytesSinceBase =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider};
}
```

- [ ] **Step 4: Register the tables, bump the version, add the migration**

In the `@DriftDatabase(tables: [...])` list, after `DeletionLog,` (~line 1535):

```dart
    DeletionLog,
    SyncPeerCursors,
    LocalPublishStates,
```

Change `currentSchemaVersion` (line 1570):

```dart
  static const int currentSchemaVersion = 84;
```

In `onUpgrade`, immediately after the `if (from < 83) await reportProgress();` line (~line 1969):

```dart
      if (from < 84) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS sync_peer_cursors (
            peer_device_id TEXT NOT NULL,
            provider TEXT NOT NULL,
            base_seq_applied INTEGER,
            last_seq_applied INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (peer_device_id, provider)
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS local_publish_states (
            provider TEXT NOT NULL PRIMARY KEY,
            base_seq INTEGER,
            base_part_count INTEGER,
            base_bytes INTEGER,
            head_seq INTEGER NOT NULL DEFAULT 0,
            published_hlc_high TEXT,
            changeset_bytes_since_base INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
          )
        ''');
      }
      if (from < 84) await reportProgress();
```

In `migrationStepCount` (line 1693), the new `reportProgress()` adds one step for any DB below 84. Open the function and add to its returned total a `+ (fromVersion < 84 ? 1 : 0)` term, matching the existing pattern used for prior versions (each `if (from < N) await reportProgress();` has a corresponding `< N` term in this count).

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `database.g.dart` with `SyncPeerCursor`, `LocalPublishState`, their `*Companion` classes, and the `syncPeerCursors` / `localPublishStates` getters on `AppDatabase`. No errors.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v84_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Format and commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_v84_test.dart
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v84_test.dart
git commit -m "feat(sync): add v84 schema for changeset-log cursors and publish state"
```

---

### Task 2: `PeerCursorStore`

**Files:**
- Create: `lib/core/services/sync/changeset_log/peer_cursor_store.dart`
- Test: `test/core/services/sync/changeset_log/peer_cursor_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/peer_cursor_store_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';

void main() {
  late AppDatabase db;
  late PeerCursorStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = PeerCursorStore(db);
  });
  tearDown(() => db.close());

  test('get returns null for an unknown peer', () async {
    expect(await store.get('peer-x', 's3'), isNull);
  });

  test('upsert then get round-trips, and upsert overwrites', () async {
    await store.upsert(peerDeviceId: 'p1', provider: 's3', baseSeqApplied: 5, lastSeqApplied: 9);
    var c = await store.get('p1', 's3');
    expect(c!.lastSeqApplied, 9);

    await store.upsert(peerDeviceId: 'p1', provider: 's3', baseSeqApplied: 5, lastSeqApplied: 14);
    c = await store.get('p1', 's3');
    expect(c!.lastSeqApplied, 14);
  });

  test('cursors are isolated per provider', () async {
    await store.upsert(peerDeviceId: 'p1', provider: 's3', lastSeqApplied: 9);
    await store.upsert(peerDeviceId: 'p1', provider: 'icloud', lastSeqApplied: 2);
    expect((await store.get('p1', 's3'))!.lastSeqApplied, 9);
    expect((await store.get('p1', 'icloud'))!.lastSeqApplied, 2);
  });

  test('resetForProvider clears only that provider', () async {
    await store.upsert(peerDeviceId: 'p1', provider: 's3', lastSeqApplied: 9);
    await store.upsert(peerDeviceId: 'p1', provider: 'icloud', lastSeqApplied: 2);
    await store.resetForProvider('s3');
    expect(await store.get('p1', 's3'), isNull);
    expect(await store.get('p1', 'icloud'), isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/peer_cursor_store_test.dart`
Expected: FAIL — `peer_cursor_store.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/peer_cursor_store.dart
import 'package:drift/drift.dart';

import '../../../database/database.dart';

/// Reads and writes per-peer download cursors (one row per peer x provider).
class PeerCursorStore {
  PeerCursorStore(this._db);

  final AppDatabase _db;

  Future<SyncPeerCursor?> get(String peerDeviceId, String provider) {
    return (_db.select(_db.syncPeerCursors)
          ..where((t) =>
              t.peerDeviceId.equals(peerDeviceId) & t.provider.equals(provider)))
        .getSingleOrNull();
  }

  Future<List<SyncPeerCursor>> allForProvider(String provider) {
    return (_db.select(_db.syncPeerCursors)
          ..where((t) => t.provider.equals(provider)))
        .get();
  }

  Future<void> upsert({
    required String peerDeviceId,
    required String provider,
    int? baseSeqApplied,
    required int lastSeqApplied,
  }) async {
    await _db.into(_db.syncPeerCursors).insertOnConflictUpdate(
          SyncPeerCursorsCompanion(
            peerDeviceId: Value(peerDeviceId),
            provider: Value(provider),
            baseSeqApplied: Value(baseSeqApplied),
            lastSeqApplied: Value(lastSeqApplied),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// Drop every cursor for [provider] — used on backend switch and on
  /// stale-restore recovery so the device re-pulls each peer from scratch.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(_db.syncPeerCursors)
          ..where((t) => t.provider.equals(provider)))
        .go();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/peer_cursor_store_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/changeset_log/peer_cursor_store.dart test/core/services/sync/changeset_log/peer_cursor_store_test.dart
git add lib/core/services/sync/changeset_log/peer_cursor_store.dart test/core/services/sync/changeset_log/peer_cursor_store_test.dart
git commit -m "feat(sync): add PeerCursorStore for per-peer download cursors"
```

---

### Task 3: `PublishStateStore`

**Files:**
- Create: `lib/core/services/sync/changeset_log/publish_state_store.dart`
- Test: `test/core/services/sync/changeset_log/publish_state_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/publish_state_store_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';

void main() {
  late AppDatabase db;
  late PublishStateStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = PublishStateStore(db);
  });
  tearDown(() => db.close());

  test('get returns null before any publish', () async {
    expect(await store.get('s3'), isNull);
  });

  test('upsert round-trips and overwrites', () async {
    await store.upsert(LocalPublishStatesCompanion(
      provider: const Value('s3'),
      baseSeq: const Value(10),
      headSeq: const Value(12),
      publishedHlcHigh: const Value('000000000000100:000000:dev'),
      changesetBytesSinceBase: const Value(2048),
      updatedAt: const Value(1),
    ));
    var s = await store.get('s3');
    expect(s!.headSeq, 12);
    expect(s.publishedHlcHigh, '000000000000100:000000:dev');

    await store.upsert(LocalPublishStatesCompanion(
      provider: const Value('s3'),
      headSeq: const Value(15),
      updatedAt: const Value(2),
    ));
    s = await store.get('s3');
    expect(s!.headSeq, 15);
  });

  test('resetForProvider clears only that provider', () async {
    await store.upsert(LocalPublishStatesCompanion(provider: const Value('s3'), updatedAt: const Value(1)));
    await store.upsert(LocalPublishStatesCompanion(provider: const Value('icloud'), updatedAt: const Value(1)));
    await store.resetForProvider('s3');
    expect(await store.get('s3'), isNull);
    expect(await store.get('icloud'), isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/publish_state_store_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/publish_state_store.dart
import 'package:drift/drift.dart';

import '../../../database/database.dart';

/// Reads and writes this device's per-provider publish position.
class PublishStateStore {
  PublishStateStore(this._db);

  final AppDatabase _db;

  Future<LocalPublishState?> get(String provider) {
    return (_db.select(_db.localPublishStates)
          ..where((t) => t.provider.equals(provider)))
        .getSingleOrNull();
  }

  /// Upsert by provider. Caller supplies a companion with `provider` set and
  /// only the fields it wants written (insertOnConflictUpdate writes the
  /// present columns; absent columns keep their value on update).
  Future<void> upsert(LocalPublishStatesCompanion entry) async {
    await _db.into(_db.localPublishStates).insertOnConflictUpdate(entry);
  }

  /// Drop publish state for [provider] — used on backend switch so the device
  /// republishes a base as if new on the new backend.
  Future<void> resetForProvider(String provider) async {
    await (_db.delete(_db.localPublishStates)
          ..where((t) => t.provider.equals(provider)))
        .go();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/publish_state_store_test.dart`
Expected: PASS (3 tests).

> NOTE on `insertOnConflictUpdate` semantics: in the second `upsert` of the round-trip test, only `provider`, `headSeq`, `updatedAt` are set in the companion. Drift's `insertOnConflictUpdate` writes the *present* columns and leaves absent columns (e.g. `baseSeq`) at their prior value. The test asserts only `headSeq` changed; do not assert `baseSeq` was preserved unless you confirm this behavior on your Drift version (it holds for current Drift). If your Drift version overwrites absent columns with defaults, change callers in Phase 3 to read-modify-write the full row instead.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/changeset_log/publish_state_store.dart test/core/services/sync/changeset_log/publish_state_store_test.dart
git add lib/core/services/sync/changeset_log/publish_state_store.dart test/core/services/sync/changeset_log/publish_state_store_test.dart
git commit -m "feat(sync): add PublishStateStore for per-provider publish position"
```

---

### Task 4: `ChangesetLogLayout` (flat naming + peer discovery)

**Files:**
- Create: `lib/core/services/sync/changeset_log/changeset_log_layout.dart`
- Test: `test/core/services/sync/changeset_log/changeset_log_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/changeset_log_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';

void main() {
  const dev = '550e8400-e29b-41d4-a716-446655440000';

  test('names carry the prefix and the device id', () {
    expect(ChangesetLogLayout.manifestName(dev), 'ssv1.$dev.manifest.json');
    expect(ChangesetLogLayout.isOurs(ChangesetLogLayout.manifestName(dev)), isTrue);
    expect(ChangesetLogLayout.isOurs('submersion_sync_$dev.json'), isFalse);
  });

  test('changeset names are zero-padded and sort by seq', () {
    final a = ChangesetLogLayout.changesetName(dev, 9);
    final b = ChangesetLogLayout.changesetName(dev, 10);
    expect(a.compareTo(b) < 0, isTrue, reason: 'lexical order must match seq order');
    expect(ChangesetLogLayout.changesetSeqOf(a), 9);
    expect(ChangesetLogLayout.changesetSeqOf(b), 10);
  });

  test('base part names parse back to (baseSeq, part)', () {
    final n = ChangesetLogLayout.basePartName(dev, 12, 3);
    final parsed = ChangesetLogLayout.basePartOf(n);
    expect(parsed, isNotNull);
    expect(parsed!.baseSeq, 12);
    expect(parsed.part, 3);
  });

  test('classifiers distinguish file kinds', () {
    expect(ChangesetLogLayout.isManifest(ChangesetLogLayout.manifestName(dev)), isTrue);
    expect(ChangesetLogLayout.changesetSeqOf(ChangesetLogLayout.manifestName(dev)), isNull);
    expect(ChangesetLogLayout.basePartOf(ChangesetLogLayout.changesetName(dev, 1)), isNull);
  });

  test('deviceIdOf extracts the uuid; non-ours returns null', () {
    expect(ChangesetLogLayout.deviceIdOf(ChangesetLogLayout.changesetName(dev, 5)), dev);
    expect(ChangesetLogLayout.deviceIdOf('random.txt'), isNull);
  });

  test('peerDeviceIds dedupes and excludes self', () {
    const other = '11111111-1111-1111-1111-111111111111';
    final names = [
      ChangesetLogLayout.manifestName(dev),
      ChangesetLogLayout.changesetName(dev, 1),
      ChangesetLogLayout.manifestName(other),
      'unrelated.json',
    ];
    expect(ChangesetLogLayout.peerDeviceIds(names, dev), {other});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/changeset_log_layout_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/changeset_log_layout.dart
//
// Flat, filename-encoded layout for the v1 changeset log. Everything lives in
// the single existing sync folder; the device id and file kind are encoded in
// the name so discovery needs only listFiles(folder, namePattern) — uniform
// across S3 (recursive prefix), iCloud and Google Drive. Device ids are UUIDs
// (no '.'), so '.' is a safe field separator. Seqs are zero-padded so lexical
// name order matches numeric seq order.
class ChangesetLogLayout {
  static const String prefix = 'ssv1.';
  static const String _manifestSuffix = '.manifest.json';
  static const String _csMarker = '.cs.';
  static const String _baseMarker = '.base.';
  static const int seqPad = 12;
  static const int partPad = 4;

  /// namePattern to pass to listFiles to fetch only this format's files.
  static const String listPattern = prefix;

  static String manifestName(String deviceId) => '$prefix$deviceId$_manifestSuffix';

  static String changesetName(String deviceId, int seq) =>
      '$prefix$deviceId$_csMarker${_pad(seq, seqPad)}.json';

  static String basePartName(String deviceId, int baseSeq, int part) =>
      '$prefix$deviceId$_baseMarker${_pad(baseSeq, seqPad)}.p${_pad(part, partPad)}';

  static bool isOurs(String name) => name.startsWith(prefix);

  static bool isManifest(String name) =>
      isOurs(name) && name.endsWith(_manifestSuffix);

  /// The device id encoded in [name], or null if [name] is not ours.
  static String? deviceIdOf(String name) {
    if (!isOurs(name)) return null;
    final rest = name.substring(prefix.length);
    final dot = rest.indexOf('.');
    if (dot <= 0) return null;
    return rest.substring(0, dot);
  }

  /// The changeset seq encoded in [name], or null if [name] is not a changeset.
  static int? changesetSeqOf(String name) {
    if (!isOurs(name)) return null;
    final i = name.indexOf(_csMarker);
    if (i < 0) return null;
    final after = name.substring(i + _csMarker.length);
    final end = after.indexOf('.');
    if (end < 0) return null;
    return int.tryParse(after.substring(0, end));
  }

  /// The (baseSeq, part) encoded in [name], or null if not a base part.
  static ({int baseSeq, int part})? basePartOf(String name) {
    if (!isOurs(name)) return null;
    final i = name.indexOf(_baseMarker);
    if (i < 0) return null;
    final after = name.substring(i + _baseMarker.length);
    final pIdx = after.indexOf('.p');
    if (pIdx < 0) return null;
    final baseSeq = int.tryParse(after.substring(0, pIdx));
    final part = int.tryParse(after.substring(pIdx + 2));
    if (baseSeq == null || part == null) return null;
    return (baseSeq: baseSeq, part: part);
  }

  /// Distinct peer device ids present in [fileNames], excluding [selfId].
  static Set<String> peerDeviceIds(Iterable<String> fileNames, String selfId) {
    final ids = <String>{};
    for (final name in fileNames) {
      final id = deviceIdOf(name);
      if (id != null && id != selfId) ids.add(id);
    }
    return ids;
  }

  static String _pad(int v, int width) => v.toString().padLeft(width, '0');
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/changeset_log_layout_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/changeset_log/changeset_log_layout.dart test/core/services/sync/changeset_log/changeset_log_layout_test.dart
git add lib/core/services/sync/changeset_log/changeset_log_layout.dart test/core/services/sync/changeset_log/changeset_log_layout_test.dart
git commit -m "feat(sync): add ChangesetLogLayout flat naming and peer discovery"
```

---

### Task 5: `SyncManifest` model

**Files:**
- Create: `lib/core/services/sync/changeset_log/sync_manifest.dart`
- Test: `test/core/services/sync/changeset_log/sync_manifest_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/sync_manifest_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

void main() {
  SyncManifest sample() => const SyncManifest(
        deviceId: 'dev-1',
        provider: 's3',
        baseSeq: 12,
        basePartCount: 3,
        baseBytes: 24,
        baseChecksum: 'sha256:abc',
        basePartChecksums: ['sha256:p0', 'sha256:p1', 'sha256:p2'],
        headSeq: 15,
        publishedHlcHigh: '000000000000100:000000:dev-1',
        epochId: 'epoch-1',
        uploadNonce: 'nonce-1',
        updatedAt: 999,
      );

  test('toBytes -> fromBytes round-trips every field', () {
    final m = sample();
    final back = SyncManifest.fromBytes(m.toBytes());
    expect(back.deviceId, 'dev-1');
    expect(back.baseSeq, 12);
    expect(back.basePartChecksums, ['sha256:p0', 'sha256:p1', 'sha256:p2']);
    expect(back.headSeq, 15);
    expect(back.publishedHlcHigh, '000000000000100:000000:dev-1');
    expect(back.uploadNonce, 'nonce-1');
    expect(back.formatVersion, 1);
  });

  test('fromJson tolerates a missing base (a device that has only changesets)', () {
    final back = SyncManifest.fromJson({
      'formatVersion': 1,
      'deviceId': 'dev-1',
      'provider': 's3',
      'headSeq': 0,
      'updatedAt': 1,
    });
    expect(back.baseSeq, isNull);
    expect(back.basePartChecksums, isEmpty);
    expect(back.headSeq, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/sync_manifest.dart
import 'dart:convert';
import 'dart:typed_data';

/// The per-device manifest: the small, rewritten-each-publish "commit point"
/// that names the current base and changeset range. The only mutable file in
/// a device's namespace.
class SyncManifest {
  const SyncManifest({
    required this.deviceId,
    required this.provider,
    required this.headSeq,
    required this.updatedAt,
    this.baseSeq,
    this.basePartCount,
    this.baseBytes,
    this.baseChecksum,
    this.basePartChecksums = const [],
    this.publishedHlcHigh,
    this.epochId,
    this.uploadNonce,
    this.formatVersion = 1,
  });

  final int formatVersion;
  final String deviceId;
  final String provider;
  final int? baseSeq;
  final int? basePartCount;
  final int? baseBytes;
  final String? baseChecksum;
  final List<String> basePartChecksums;
  final int headSeq;
  final String? publishedHlcHigh;
  final String? epochId;
  final String? uploadNonce;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'deviceId': deviceId,
        'provider': provider,
        'baseSeq': baseSeq,
        'basePartCount': basePartCount,
        'baseBytes': baseBytes,
        'baseChecksum': baseChecksum,
        'basePartChecksums': basePartChecksums,
        'headSeq': headSeq,
        'publishedHlcHigh': publishedHlcHigh,
        'epochId': epochId,
        'uploadNonce': uploadNonce,
        'updatedAt': updatedAt,
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
        formatVersion: (json['formatVersion'] as int?) ?? 1,
        deviceId: json['deviceId'] as String,
        provider: json['provider'] as String,
        baseSeq: json['baseSeq'] as int?,
        basePartCount: json['basePartCount'] as int?,
        baseBytes: json['baseBytes'] as int?,
        baseChecksum: json['baseChecksum'] as String?,
        basePartChecksums:
            ((json['basePartChecksums'] as List?) ?? const []).cast<String>(),
        headSeq: (json['headSeq'] as int?) ?? 0,
        publishedHlcHigh: json['publishedHlcHigh'] as String?,
        epochId: json['epochId'] as String?,
        uploadNonce: json['uploadNonce'] as String?,
        updatedAt: (json['updatedAt'] as int?) ?? 0,
      );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory SyncManifest.fromBytes(Uint8List bytes) =>
      SyncManifest.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/changeset_log/sync_manifest.dart test/core/services/sync/changeset_log/sync_manifest_test.dart
git add lib/core/services/sync/changeset_log/sync_manifest.dart test/core/services/sync/changeset_log/sync_manifest_test.dart
git commit -m "feat(sync): add SyncManifest model"
```

---

### Task 6: `BaseChunker`

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_chunker.dart`
- Test: `test/core/services/sync/changeset_log/base_chunker_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/base_chunker_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

void main() {
  Uint8List bytes(int n) => Uint8List.fromList(List.generate(n, (i) => i % 256));

  test('slice then reassemble is identity', () {
    final data = bytes(1000);
    final parts = BaseChunker.slice(data, partSize: 256);
    expect(parts.length, 4); // 256+256+256+232
    expect(BaseChunker.reassemble(parts), data);
  });

  test('exact multiple of partSize slices evenly', () {
    final data = bytes(512);
    final parts = BaseChunker.slice(data, partSize: 256);
    expect(parts.length, 2);
    expect(BaseChunker.reassemble(parts), data);
  });

  test('empty data yields one empty part and round-trips', () {
    final parts = BaseChunker.slice(Uint8List(0), partSize: 256);
    expect(parts.length, 1);
    expect(BaseChunker.reassemble(parts).length, 0);
  });

  test('checksum is stable and detects corruption', () {
    final data = bytes(300);
    final c1 = BaseChunker.checksum(data);
    expect(c1, startsWith('sha256:'));
    expect(BaseChunker.checksum(data), c1);
    final corrupted = Uint8List.fromList(data)..[0] ^= 0xFF;
    expect(BaseChunker.checksum(corrupted), isNot(c1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/base_chunker_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/base_chunker.dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Byte-slices a serialized base snapshot into resumable parts and verifies
/// integrity. Parts are raw slices (not individually parseable): download all,
/// reassemble, verify the whole checksum, then parse once.
class BaseChunker {
  static const int defaultPartSize = 8 * 1024 * 1024;

  static List<Uint8List> slice(Uint8List data, {int partSize = defaultPartSize}) {
    if (data.isEmpty) return [Uint8List(0)];
    final parts = <Uint8List>[];
    for (var off = 0; off < data.length; off += partSize) {
      final end = (off + partSize < data.length) ? off + partSize : data.length;
      parts.add(Uint8List.sublistView(data, off, end));
    }
    return parts;
  }

  static Uint8List reassemble(List<Uint8List> parts) {
    final total = parts.fold<int>(0, (a, p) => a + p.length);
    final out = Uint8List(total);
    var off = 0;
    for (final p in parts) {
      out.setAll(off, p);
      off += p.length;
    }
    return out;
  }

  /// `sha256:<hex>` — same convention as the manifest checksum fields.
  static String checksum(Uint8List bytes) => 'sha256:${sha256.convert(bytes)}';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/base_chunker_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/services/sync/changeset_log/base_chunker.dart test/core/services/sync/changeset_log/base_chunker_test.dart
git add lib/core/services/sync/changeset_log/base_chunker.dart test/core/services/sync/changeset_log/base_chunker_test.dart
git commit -m "feat(sync): add BaseChunker for resumable base slicing"
```

---

### Task 7: `FakeCloudStorageProvider` (test double)

**Files:**
- Create: `test/support/fake_cloud_storage_provider.dart`
- Test: `test/support/fake_cloud_storage_provider_test.dart`

This is test infrastructure — the keystone for every later phase's deterministic multi-device test. It lives under `test/support/` so production code never imports it.

- [ ] **Step 1: Write the failing test**

```dart
// test/support/fake_cloud_storage_provider_test.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'fake_cloud_storage_provider.dart';

void main() {
  Uint8List u(String s) => Uint8List.fromList(utf8.encode(s));

  test('upload, list by pattern, download, delete', () async {
    final p = FakeCloudStorageProvider();
    final folder = await p.getOrCreateSyncFolder();

    final up = await p.uploadFile(u('hello'), 'ssv1.dev.cs.000000000001.json', folderId: folder);
    await p.uploadFile(u('ignore'), 'other.txt', folderId: folder);

    final listed = await p.listFiles(folderId: folder, namePattern: 'ssv1.');
    expect(listed.map((f) => f.name), ['ssv1.dev.cs.000000000001.json']);

    expect(utf8.decode(await p.downloadFile(up.fileId)), 'hello');
    expect(await p.fileExists(up.fileId), isTrue);

    await p.deleteFile(up.fileId);
    expect(await p.fileExists(up.fileId), isFalse);
  });

  test('uploadFile overwrites the same name (upsert)', () async {
    final p = FakeCloudStorageProvider();
    final folder = await p.getOrCreateSyncFolder();
    await p.uploadFile(u('v1'), 'm.json', folderId: folder);
    final up2 = await p.uploadFile(u('v2'), 'm.json', folderId: folder);
    expect(utf8.decode(await p.downloadFile(up2.fileId)), 'v2');
    final listed = await p.listFiles(folderId: folder, namePattern: 'm.json');
    expect(listed.length, 1);
  });

  test('downloadFile throws for a missing file', () async {
    final p = FakeCloudStorageProvider();
    expect(() => p.downloadFile('sync/nope'), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/support/fake_cloud_storage_provider_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// test/support/fake_cloud_storage_provider.dart
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// In-memory CloudStorageProvider for deterministic sync tests. Keys are
/// "<folderId>/<filename>". A monotonic counter stands in for modified time so
/// tests never depend on the wall clock. Optionally simulates list lag (a
/// just-written file invisible to listFiles for N calls) to exercise the
/// eventual-consistency / transient-missing paths in later phases.
class FakeCloudStorageProvider implements CloudStorageProvider {
  FakeCloudStorageProvider({this.providerId = 's3', this.listLagCalls = 0});

  @override
  final String providerId;

  /// Number of listFiles calls during which a freshly-written key stays hidden.
  final int listLagCalls;

  static const String _folder = 'sync';

  final Map<String, Uint8List> _files = {};
  final Map<String, int> _modified = {};
  final Map<String, int> _visibleAfterCall = {};
  int _clock = 0;
  int _listCalls = 0;

  @override
  String get providerName => 'Fake ($providerId)';

  String _key(String? folder, String name) => '${folder ?? _folder}/$name';

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> authenticate() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> getUserEmail() async => 'test@example.com';
  @override
  Future<String> getOrCreateSyncFolder() async => _folder;

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) async =>
      parentFolderId == null ? folderName : '$parentFolderId/$folderName';

  @override
  Future<UploadResult> uploadFile(Uint8List data, String filename, {String? folderId}) async {
    final key = _key(folderId, filename);
    _files[key] = Uint8List.fromList(data);
    _modified[key] = ++_clock;
    if (listLagCalls > 0) _visibleAfterCall[key] = _listCalls + listLagCalls;
    return UploadResult(
      fileId: key,
      uploadTime: DateTime.fromMillisecondsSinceEpoch(_clock),
    );
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final data = _files[fileId];
    if (data == null) {
      throw CloudStorageException('Fake: not found: $fileId');
    }
    return Uint8List.fromList(data);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({String? folderId, String? namePattern}) async {
    final call = ++_listCalls;
    final folder = folderId ?? _folder;
    final out = <CloudFileInfo>[];
    for (final entry in _files.entries) {
      final visibleAt = _visibleAfterCall[entry.key];
      if (visibleAt != null && call < visibleAt) continue;
      final slash = entry.key.indexOf('/');
      final f = entry.key.substring(0, slash);
      final name = entry.key.substring(slash + 1);
      if (f != folder) continue;
      if (namePattern != null && !name.contains(namePattern)) continue;
      out.add(CloudFileInfo(
        id: entry.key,
        name: name,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(_modified[entry.key]!),
        sizeBytes: entry.value.length,
      ));
    }
    return out;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    _files.remove(fileId);
    _modified.remove(fileId);
    _visibleAfterCall.remove(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async => _files.containsKey(fileId);

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final data = _files[fileId];
    if (data == null) return null;
    final slash = fileId.indexOf('/');
    return CloudFileInfo(
      id: fileId,
      name: fileId.substring(slash + 1),
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(_modified[fileId]!),
      sizeBytes: data.length,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/support/fake_cloud_storage_provider_test.dart`
Expected: PASS (3 tests).

> NOTE: if `flutter analyze` reports the fake is missing a newly-added `CloudStorageProvider` member in a future change, that is the intended signal — add the member here too (the analyzer is the safety net that keeps the double in sync with the interface).

- [ ] **Step 5: Format and commit**

```bash
dart format test/support/fake_cloud_storage_provider.dart test/support/fake_cloud_storage_provider_test.dart
git add test/support/fake_cloud_storage_provider.dart test/support/fake_cloud_storage_provider_test.dart
git commit -m "test(sync): add in-memory FakeCloudStorageProvider test double"
```

---

### Phase 1 wrap-up

- [ ] **Run the full sync test subtree and analyze**

Run: `flutter test test/core/services/sync/ test/core/database/migration_v84_test.dart test/support/`
Run: `flutter analyze`
Expected: all green; analyze reports no new issues.

At this point the data layer exists and is tested, with no change to runtime sync. **Phase 2 (serialization: HLC-watermark delta export + changeset/base assembly) builds on these pieces** and gets its own plan.
