# Tombstone GC and Device Retirement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unsafe 90-day tombstone purge with fleet-acknowledged GC, retire dead devices' cloud logs, and fence retired devices through a cloud-wins rejoin that preserves their unpublished records.

**Architecture:** The per-device sync manifest (already the atomic commit point of every publish) gains an acknowledgment map (`appliedPeerHlc`) and a liveness heartbeat. Tombstones are deleted only when every live peer's manifest acknowledges them. Devices idle past 12 months are retired by any active peer (marker file + log deletion); a retired device that returns detects its marker and rejoins subordinately via the existing adopt/rebuild machinery, replaying its pending (unpublished) records with fresh HLCs.

**Tech Stack:** Flutter/Dart, Drift ORM (SQLite), existing changeset-log sync transport (`lib/core/services/sync/changeset_log/`), `FakeCloudStorageProvider` test harness.

**Spec:** `docs/superpowers/specs/2026-07-16-tombstone-gc-device-retirement-design.md`

## Global Constraints

- Schema migration is **v114** (renumbered twice while the PR was open: planned as v112, moved to v113 after main claimed v112 for equipment.thickness, then to v114 after main claimed v113 for the CNS calculation method). The task steps below were authored at the original v112 numbering but have been reconciled to the shipped **v114** so the migration number matches the code.
- Constants: retirement period **365 days**, heartbeat max age **7 days**, GC safety floor **30 days**.
- HLC comparisons use the fixed-width zero-padded canonical **string** form (`compareTo`), matching the existing v86 deletion filters. Never switch to parsed `Hlc.compareTo` in isolation.
- Manifest changes are **additive JSON fields**; a manifest missing `appliedPeerHlc` acknowledges nothing (blocks GC).
- No emojis anywhere. `dart format .` must be clean before every commit. Run `flutter analyze` before the final commit of each task.
- Worktree setup before starting (if not already done): `git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
- After Task 1's schema change, re-run `dart run build_runner build --delete-conflicting-outputs` (generated `.g.dart` is gitignored; commit source + tests only).
- Drift exports top-level `isNull`/`isNotNull` that collide with flutter_test matchers: test files mixing drift `Value` + matcher null-checks need `import 'package:drift/drift.dart' hide isNull, isNotNull;`.
- Run only the specific test files you touched (`flutter test test/path/file_test.dart`), never the whole suite mid-task (it is slow). Never pipe `flutter analyze` through `tail`/`head`.

---

### Task 1: Schema v114 — deletion-log dedupe + unique index, cursor ack column, logDeletion upsert

**Files:**
- Modify: `lib/core/database/database.dart` (table defs ~line 1956, `migrationVersions` list ~line 2212/2321, version doc comment ~line 2406, `currentSchemaVersion` ~line 2207, onUpgrade ~line 5526, beforeOpen backstop ~line 5556)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`logDeletion` ~line 742)
- Test: `test/core/data/repositories/sync_repository_deletion_dedupe_test.dart` (new)

**Interfaces:**
- Consumes: existing `DeletionLog` table, `SyncPeerCursors` table, `logDeletion`.
- Produces: `SyncPeerCursors.appliedHlcHigh` (`TextColumn`, nullable → generated Dart field `String? appliedHlcHigh` on `SyncPeerCursor`); `AppDatabase.ensureDeletionLogIndex()` (public, idempotent); `logDeletion` now upserts per `(entityType, recordId)` keeping the newest stamp.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/data/repositories/sync_repository_deletion_dedupe_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('logDeletion upserts: one tombstone per (entityType, recordId), newest wins', () async {
    final repo = SyncRepository();
    await repo.logDeletion(entityType: 'dives', recordId: 'd1', deletedAt: 1000);
    await repo.logDeletion(entityType: 'dives', recordId: 'd1', deletedAt: 2000);
    await repo.logDeletion(entityType: 'dives', recordId: 'd2', deletedAt: 1500);

    final all = await repo.getAllDeletions();
    expect(all, hasLength(2));
    final d1 = all.singleWhere((d) => d.recordId == 'd1');
    expect(d1.deletedAt, 2000);
  });

  test('ensureDeletionLogIndex collapses pre-existing duplicates, newest wins', () async {
    final db = DatabaseService.instance.database;
    // Simulate a pre-v114 database: drop the index, insert raw duplicates.
    await db.customStatement('DROP INDEX IF EXISTS idx_deletion_log_entity_record');
    await db.customStatement(
      "INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, hlc) "
      "VALUES ('a', 'dives', 'dup', 1000, NULL)");
    await db.customStatement(
      "INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, hlc) "
      "VALUES ('b', 'dives', 'dup', 3000, NULL)");
    await db.customStatement(
      "INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, hlc) "
      "VALUES ('c', 'dives', 'dup', 2000, NULL)");

    await db.ensureDeletionLogIndex();

    final rows = await db
        .customSelect("SELECT deleted_at FROM deletion_log WHERE record_id = 'dup'")
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.data['deleted_at'], 3000);
  });

  test('sync_peer_cursors has applied_hlc_high column', () async {
    final db = DatabaseService.instance.database;
    final cols = await db
        .customSelect("PRAGMA table_info(sync_peer_cursors)")
        .get();
    expect(cols.map((r) => r.data['name']), contains('applied_hlc_high'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/data/repositories/sync_repository_deletion_dedupe_test.dart`
Expected: FAIL (`ensureDeletionLogIndex` undefined; duplicate tombstones present; column missing).

- [ ] **Step 3: Implement the schema change**

In `lib/core/database/database.dart`:

3a. Add the column to `SyncPeerCursors` (after `lastSeqApplied`):

```dart
  // Highest HLC applied FROM this peer's log -- published in our manifest's
  // appliedPeerHlc map so the peer can garbage-collect tombstones we have
  // provably seen (fleet-acked horizon).
  TextColumn get appliedHlcHigh => text().nullable()();
```

3b. Bump `currentSchemaVersion` to `114`, append `114` to `migrationVersions`, and add to the version doc comment block:

```dart
  /// v114: deletion_log unique index (dedupe tombstones per entity+record) +
  /// sync_peer_cursors.applied_hlc_high (fleet-acked tombstone GC).
```

3c. Add the idempotent index helper as a method on `AppDatabase`:

```dart
  /// Collapse duplicate tombstones (newest deleted_at per entity_type +
  /// record_id wins) and (re-)assert the unique index that keeps the log
  /// collapsed. Cheap when the index already exists; the dedupe DELETE only
  /// runs when index creation fails on pre-existing duplicates. Called from
  /// the v114 upgrade and the beforeOpen backstop (parallel-branch DBs heal
  /// here, mirroring the v111 backstop).
  Future<void> ensureDeletionLogIndex() async {
    const createIndex =
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_deletion_log_entity_record '
        'ON deletion_log (entity_type, record_id)';
    try {
      await customStatement(createIndex);
    } catch (_) {
      await customStatement('''
        DELETE FROM deletion_log WHERE rowid NOT IN (
          SELECT rowid FROM (
            SELECT rowid, ROW_NUMBER() OVER (
              PARTITION BY entity_type, record_id
              ORDER BY deleted_at DESC, COALESCE(hlc, '') DESC, rowid DESC
            ) AS rn FROM deletion_log
          ) WHERE rn = 1
        )
      ''');
      await customStatement(createIndex);
    }
  }
```

3d. In `onUpgrade`, following the `if (from < 111)` block's pattern:

```dart
        if (from < 112) {
          await m.addColumn(syncPeerCursors, syncPeerCursors.appliedHlcHigh);
          await ensureDeletionLogIndex();
        }
        if (from < 112) await reportProgress();
```

3e. In the beforeOpen backstop section (next to the v111 backstop at ~line 5556):

```dart
        // v114 backstop: re-assert sync_peer_cursors.applied_hlc_high and the
        // deletion_log unique index.
        try {
          await customStatement(
            'ALTER TABLE sync_peer_cursors ADD COLUMN applied_hlc_high TEXT',
          );
        } catch (_) {}
        await ensureDeletionLogIndex();
```

3f. Run codegen: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Make `logDeletion` an upsert**

In `lib/core/data/repositories/sync_repository.dart`, inside `logDeletion`, wrap the insert in a transaction that first deletes the existing tombstone for the same key (keep everything else — HLC stamping, logging — unchanged):

```dart
      await _db.transaction(() async {
        // One tombstone per record: replace any prior tombstone for this key
        // so its deletedAt/hlc advance (re-delete refreshes the stamp) and the
        // v114 unique index is never violated.
        await (_db.delete(_db.deletionLog)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.recordId.equals(recordId),
            ))
            .go();
        await _db
            .into(_db.deletionLog)
            .insert(
              DeletionLogCompanion(
                id: Value(id),
                entityType: Value(entityType),
                recordId: Value(recordId),
                deletedAt: Value(now),
                hlc: Value(hlc),
              ),
            );
      });
```

`logDeletionIfMissing` keeps its existing check-then-insert semantics (its insert now lands in an empty slot by definition).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/data/repositories/sync_repository_deletion_dedupe_test.dart`
Expected: PASS (3 tests). Also run the existing suite touching these paths:
`flutter test test/core/data/repositories/ test/core/services/sync/changeset_log/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/data/repositories/sync_repository.dart test/core/data/repositories/sync_repository_deletion_dedupe_test.dart
git commit -m "feat(sync): v114 tombstone dedupe index + peer ack column"
```

---

### Task 2: Layout names + RetirementMarker model

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_log_layout.dart`
- Create: `lib/core/services/sync/changeset_log/retirement_marker.dart`
- Test: `test/core/services/sync/changeset_log/changeset_log_layout_test.dart` (extend)
- Test: `test/core/services/sync/changeset_log/retirement_marker_test.dart` (new)

**Interfaces:**
- Produces: `ChangesetLogLayout.retiredMarkerName(String deviceId) -> String`; `ChangesetLogLayout.isRetiredMarker(String name) -> bool`; `RetirementMarker({required String deviceId, required int retiredAt, int formatVersion = 1})` with `toBytes()`/`fromBytes(Uint8List)`.

- [ ] **Step 1: Write the failing tests**

Append to `changeset_log_layout_test.dart`:

```dart
  test('retirement marker name round-trips device id and is not a manifest', () {
    final name = ChangesetLogLayout.retiredMarkerName('dev-1');
    expect(name, 'ssv1.dev-1.retired.json');
    expect(ChangesetLogLayout.isRetiredMarker(name), isTrue);
    expect(ChangesetLogLayout.deviceIdOf(name), 'dev-1');
    expect(ChangesetLogLayout.isManifest(name), isFalse);
    expect(ChangesetLogLayout.changesetSeqOf(name), isNull);
    expect(ChangesetLogLayout.basePartOf(name), isNull);
    expect(
      ChangesetLogLayout.isRetiredMarker(
        ChangesetLogLayout.manifestName('dev-1'),
      ),
      isFalse,
    );
  });
```

New `retirement_marker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';

void main() {
  test('round-trips through bytes', () {
    const marker = RetirementMarker(deviceId: 'dev-1', retiredAt: 12345);
    final decoded = RetirementMarker.fromBytes(marker.toBytes());
    expect(decoded.deviceId, 'dev-1');
    expect(decoded.retiredAt, 12345);
    expect(decoded.formatVersion, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/changeset_log_layout_test.dart test/core/services/sync/changeset_log/retirement_marker_test.dart`
Expected: FAIL (methods/class undefined).

- [ ] **Step 3: Implement**

In `changeset_log_layout.dart` (inside the class, next to `_manifestSuffix`):

```dart
  static const String _retiredSuffix = '.retired.json';
```

and next to `manifestName`/`isManifest`:

```dart
  static String retiredMarkerName(String deviceId) =>
      '$prefix$deviceId$_retiredSuffix';

  static bool isRetiredMarker(String name) =>
      isOurs(name) && name.endsWith(_retiredSuffix);
```

Note: `changesetSeqOf`/`basePartOf` already return null for marker names (no `.cs.`/`.base.` markers), so the compaction pruner ignores markers, and `deleteAllSyncFiles` (prefix match) wipes markers on library replace — both intended.

New `retirement_marker.dart` (mirror `SyncManifest`'s shape, including the encrypted-envelope guard):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

/// Durable record that a device's changeset log was retired (deleted from the
/// cloud after 12+ months of inactivity). Written BEFORE the log is deleted so
/// the returning device always detects its retirement and rejoins through the
/// fence rather than resurrecting stale data. Persists until the device
/// rejoins (it deletes its own marker at the end of the fence flow).
class RetirementMarker {
  const RetirementMarker({
    required this.deviceId,
    required this.retiredAt,
    this.formatVersion = 1,
  });

  final int formatVersion;
  final String deviceId;
  final int retiredAt;

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'deviceId': deviceId,
    'retiredAt': retiredAt,
  };

  factory RetirementMarker.fromJson(Map<String, dynamic> json) =>
      RetirementMarker(
        formatVersion: (json['formatVersion'] as int?) ?? 1,
        deviceId: json['deviceId'] as String,
        retiredAt: (json['retiredAt'] as int?) ?? 0,
      );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory RetirementMarker.fromBytes(Uint8List bytes) {
    if (SyncEnvelope.hasMagic(bytes)) {
      throw SyncEncryptionRequired(
        libraryKeyId: SyncEnvelope.libraryKeyIdOf(bytes),
        message: 'Retirement marker is encrypted',
      );
    }
    return RetirementMarker.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_log_layout_test.dart test/core/services/sync/changeset_log/retirement_marker_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/changeset_log_layout.dart lib/core/services/sync/changeset_log/retirement_marker.dart test/core/services/sync/changeset_log/
git commit -m "feat(sync): retirement marker file name and model"
```

---

### Task 3: SyncManifest.appliedPeerHlc (additive field)

**Files:**
- Modify: `lib/core/services/sync/changeset_log/sync_manifest.dart`
- Test: `test/core/services/sync/changeset_log/sync_manifest_test.dart` (extend)

**Interfaces:**
- Produces: `SyncManifest.appliedPeerHlc` (`Map<String, String>`, default `const {}`), serialized as JSON key `appliedPeerHlc`, tolerant of absence on decode.

- [ ] **Step 1: Write the failing tests** (append to `sync_manifest_test.dart`)

```dart
  test('appliedPeerHlc round-trips and defaults to empty when absent', () {
    const m = SyncManifest(
      deviceId: 'dev-1',
      provider: 'fake',
      headSeq: 3,
      updatedAt: 999,
      appliedPeerHlc: {'peer-a': '00000000000010:000001:dev-1'},
    );
    final decoded = SyncManifest.fromBytes(m.toBytes());
    expect(decoded.appliedPeerHlc, {'peer-a': '00000000000010:000001:dev-1'});

    // An old-format manifest (field absent) must decode to an empty map:
    // "acknowledges nothing", which blocks GC.
    final legacy = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'fake',
      'headSeq': 1,
      'updatedAt': 5,
    });
    expect(legacy.appliedPeerHlc, isEmpty);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: FAIL (no such named parameter).

- [ ] **Step 3: Implement** — in `sync_manifest.dart` add to the constructor `this.appliedPeerHlc = const {},`; add the field:

```dart
  /// Highest HLC this device has APPLIED from each peer's log
  /// (peerDeviceId -> hlc). Peers read it to garbage-collect tombstones every
  /// live device has provably seen. A missing entry acknowledges nothing.
  final Map<String, String> appliedPeerHlc;
```

In `toJson()` add `'appliedPeerHlc': appliedPeerHlc,`. In `fromJson` add:

```dart
    appliedPeerHlc: Map<String, String>.from(
      (json['appliedPeerHlc'] as Map?) ?? const {},
    ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/sync_manifest.dart test/core/services/sync/changeset_log/sync_manifest_test.dart
git commit -m "feat(sync): manifest appliedPeerHlc acknowledgment map"
```

---

### Task 4: SyncLiveness constants + TombstoneHorizon

**Files:**
- Create: `lib/core/services/sync/changeset_log/sync_liveness.dart`
- Create: `lib/core/services/sync/changeset_log/tombstone_horizon.dart`
- Test: `test/core/services/sync/changeset_log/tombstone_horizon_test.dart` (new)

**Interfaces:**
- Produces: `SyncLiveness.retirementPeriodMillis` / `heartbeatMaxAgeMillis` / `gcFloorMillis` (static const ints); `TombstoneGcDecision` (`bool allowed`, `String? upToHlc` — null with `allowed` means unbounded); `TombstoneHorizon.compute({required String selfDeviceId, required Iterable<SyncManifest> peerManifests, required Set<String> retiredPeerIds, required int nowMillis, int retirementPeriodMillis})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/changeset_log/tombstone_horizon_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/changeset_log/tombstone_horizon.dart';

void main() {
  const now = 1000000000000;
  const month = 30 * 24 * 60 * 60 * 1000;

  SyncManifest peer(
    String id, {
    int ageMillis = 0,
    Map<String, String> applied = const {},
  }) => SyncManifest(
    deviceId: id,
    provider: 'fake',
    headSeq: 1,
    updatedAt: now - ageMillis,
    appliedPeerHlc: applied,
  );

  test('no live peers: GC unbounded', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: const [],
      retiredPeerIds: const {},
      nowMillis: now,
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, isNull);
  });

  test('live peer without an ack entry blocks GC', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [peer('p1')],
      retiredPeerIds: const {},
      nowMillis: now,
    );
    expect(d.allowed, isFalse);
  });

  test('horizon is the minimum ack across live peers', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer('p1', applied: {'self': '00000000000020:000000:x'}),
        peer('p2', applied: {'self': '00000000000010:000000:x'}),
      ],
      retiredPeerIds: const {},
      nowMillis: now,
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, '00000000000010:000000:x');
  });

  test('stale (13-month) and retired peers do not count', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [
        peer('stale', ageMillis: 13 * month), // beyond retirement period
        peer('gone', applied: const {}), // retired below
        peer('live', applied: {'self': '00000000000030:000000:x'}),
      ],
      retiredPeerIds: const {'gone'},
      nowMillis: now,
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, '00000000000030:000000:x');
  });

  test('own manifest is ignored', () {
    final d = TombstoneHorizon.compute(
      selfDeviceId: 'self',
      peerManifests: [peer('self')],
      retiredPeerIds: const {},
      nowMillis: now,
    );
    expect(d.allowed, isTrue);
    expect(d.upToHlc, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/tombstone_horizon_test.dart`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement**

`sync_liveness.dart`:

```dart
/// Tuning constants for fleet-acked tombstone GC and device retirement.
/// See docs/superpowers/specs/2026-07-16-tombstone-gc-device-retirement-design.md.
class SyncLiveness {
  SyncLiveness._();

  /// A device whose manifest is older than this is retired by any live peer.
  static const int retirementPeriodMillis = 365 * 24 * 60 * 60 * 1000;

  /// A sync that publishes nothing still rewrites the manifest when it is
  /// older than this, so a read-mostly device stays provably live.
  static const int heartbeatMaxAgeMillis = 7 * 24 * 60 * 60 * 1000;

  /// Tombstones younger than this are never GC'd regardless of acks (covers
  /// in-flight device joins, twin splits, and backend listing lag).
  static const int gcFloorMillis = 30 * 24 * 60 * 60 * 1000;
}
```

`tombstone_horizon.dart`:

```dart
import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Outcome of a fleet-acked GC computation. [upToHlc] == null with [allowed]
/// means no live peer constrains GC (single-device library): everything past
/// the safety floor may go.
class TombstoneGcDecision {
  const TombstoneGcDecision._(this.allowed, this.upToHlc);
  const TombstoneGcDecision.blocked() : this._(false, null);
  const TombstoneGcDecision.unbounded() : this._(true, null);
  const TombstoneGcDecision.upTo(String hlc) : this._(true, hlc);

  final bool allowed;
  final String? upToHlc;
}

/// Computes how far this device may garbage-collect its own tombstones: the
/// minimum HLC every LIVE peer's manifest acknowledges having applied from us.
/// A live peer with no ack entry (old-format manifest, or a device that has
/// not pulled our log yet) blocks GC entirely -- the safe default.
class TombstoneHorizon {
  static TombstoneGcDecision compute({
    required String selfDeviceId,
    required Iterable<SyncManifest> peerManifests,
    required Set<String> retiredPeerIds,
    required int nowMillis,
    int retirementPeriodMillis = SyncLiveness.retirementPeriodMillis,
  }) {
    String? min;
    var anyLivePeer = false;
    for (final m in peerManifests) {
      if (m.deviceId == selfDeviceId) continue;
      if (retiredPeerIds.contains(m.deviceId)) continue;
      if (nowMillis - m.updatedAt > retirementPeriodMillis) continue;
      final acked = m.appliedPeerHlc[selfDeviceId];
      if (acked == null) return const TombstoneGcDecision.blocked();
      anyLivePeer = true;
      if (min == null || acked.compareTo(min) < 0) min = acked;
    }
    if (!anyLivePeer) return const TombstoneGcDecision.unbounded();
    return TombstoneGcDecision.upTo(min!);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/tombstone_horizon_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/sync_liveness.dart lib/core/services/sync/changeset_log/tombstone_horizon.dart test/core/services/sync/changeset_log/tombstone_horizon_test.dart
git commit -m "feat(sync): liveness constants and fleet-acked tombstone horizon"
```

---

### Task 5: Reader tracks acks, skips retired peers, returns manifests

**Files:**
- Modify: `lib/core/services/sync/changeset_log/peer_cursor_store.dart`
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Test: `test/core/services/sync/changeset_log/changeset_reader_test.dart` (extend)
- Test: `test/core/services/sync/changeset_log/peer_cursor_store_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1's `appliedHlcHigh` column, Task 2's `isRetiredMarker`, Task 3's manifest field.
- Produces: `PeerCursorStore.upsert` gains `String? appliedHlcHigh` (absent-if-null: an omitted value never clears a stored ack); `ChangesetReadResult` gains `List<SyncManifest> peerManifests` (default `const []`), `Set<String> retiredPeerIds` (default `const {}`), `bool retiredPeerHasFiles` (default `false`).

- [ ] **Step 1: Write the failing tests**

Append to `peer_cursor_store_test.dart`:

```dart
  test('upsert with null appliedHlcHigh preserves the stored ack', () async {
    final store = PeerCursorStore(DatabaseService.instance.database);
    await store.upsert(
      peerDeviceId: 'p1',
      provider: 'fake',
      lastSeqApplied: 1,
      appliedHlcHigh: '00000000000010:000000:p1',
    );
    await store.upsert(peerDeviceId: 'p1', provider: 'fake', lastSeqApplied: 2);
    final cursor = await store.get('p1', 'fake');
    expect(cursor!.lastSeqApplied, 2);
    expect(cursor.appliedHlcHigh, '00000000000010:000000:p1');
  });
```

Append to `changeset_reader_test.dart` (match its existing setup: it builds a reader with `ChangesetCodec`/`PeerCursorStore`, seeds peers via `seedPeerLog`, applies with spy callbacks from `test/helpers/changeset_test_helpers.dart`):

```dart
  test('pull records the applied HLC ack on the peer cursor', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1-dive', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');
    final applied = <SyncPayload>[];
    await reader.pull(
      provider: cloud,
      selfDeviceId: 'self',
      folderId: folder,
      apply: (p) async => applied.add(p),
      applyBaseFile: spyApplyBaseFile(applied),
    );
    final manifest = SyncManifest.fromBytes(
      await cloud.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName('peer-1')}',
      ),
    );
    final cursor = await PeerCursorStore(
      DatabaseService.instance.database,
    ).get('peer-1', cloud.providerId);
    expect(cursor!.appliedHlcHigh, manifest.publishedHlcHigh);
  });

  test('pull skips a retired peer and reports it', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1-dive', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');
    await cloud.uploadFile(
      const RetirementMarker(deviceId: 'peer-1', retiredAt: 1).toBytes(),
      ChangesetLogLayout.retiredMarkerName('peer-1'),
      folderId: folder,
    );
    final applied = <SyncPayload>[];
    final result = await reader.pull(
      provider: cloud,
      selfDeviceId: 'self',
      folderId: folder,
      apply: (p) async => applied.add(p),
      applyBaseFile: spyApplyBaseFile(applied),
    );
    expect(applied, isEmpty);
    expect(result.peersProcessed, 0);
    expect(result.retiredPeerIds, {'peer-1'});
    expect(result.retiredPeerHasFiles, isTrue);
    expect(result.peerManifests, isEmpty);
  });

  test('pull returns live peer manifests', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1-dive', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');
    final applied = <SyncPayload>[];
    final result = await reader.pull(
      provider: cloud,
      selfDeviceId: 'self',
      folderId: folder,
      apply: (p) async => applied.add(p),
      applyBaseFile: spyApplyBaseFile(applied),
    );
    expect(result.peerManifests.map((m) => m.deviceId), ['peer-1']);
  });
```

(Add the needed imports at the top of the test file: `retirement_marker.dart`, `peer_cursor_store.dart`, `sync_manifest.dart`, `database_service.dart` — whichever are missing.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/peer_cursor_store_test.dart test/core/services/sync/changeset_log/changeset_reader_test.dart`
Expected: FAIL (missing params/fields).

- [ ] **Step 3: Implement `PeerCursorStore.upsert`** — add the parameter and companion entry:

```dart
  Future<void> upsert({
    required String peerDeviceId,
    required String provider,
    int? baseSeqApplied,
    required int lastSeqApplied,
    String? appliedHlcHigh,
  }) async {
    await _db
        .into(_db.syncPeerCursors)
        .insertOnConflictUpdate(
          SyncPeerCursorsCompanion(
            peerDeviceId: Value(peerDeviceId),
            provider: Value(provider),
            baseSeqApplied: Value(baseSeqApplied),
            lastSeqApplied: Value(lastSeqApplied),
            // Absent (not null) when unknown, so a transport-only upsert never
            // clears a previously recorded acknowledgment.
            appliedHlcHigh: appliedHlcHigh == null
                ? const Value.absent()
                : Value(appliedHlcHigh),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }
```

- [ ] **Step 4: Implement the reader changes** in `changeset_reader.dart`:

4a. Extend the result type:

```dart
class ChangesetReadResult {
  const ChangesetReadResult({
    required this.peersProcessed,
    required this.payloadsApplied,
    this.peerManifests = const [],
    this.retiredPeerIds = const {},
    this.retiredPeerHasFiles = false,
  });
  final int peersProcessed;
  final int payloadsApplied;

  /// Every non-retired peer manifest seen this pull (including stale-epoch
  /// ones, which stay inert for merging but still block/inform tombstone GC).
  final List<SyncManifest> peerManifests;
  final Set<String> retiredPeerIds;

  /// True when a retired peer still has non-marker files in the bucket (a
  /// partial retirement) -- tells the sweeper to retry the deletion.
  final bool retiredPeerHasFiles;
}
```

4b. In `pull()`, after building `byName`/`peerIds`, compute the retired set and leftovers, and skip retired peers; collect manifests before the epoch filter; track the applied ack:

```dart
    final retiredPeerIds = <String>{
      for (final f in files)
        if (ChangesetLogLayout.isRetiredMarker(f.name) &&
            ChangesetLogLayout.deviceIdOf(f.name) != null &&
            ChangesetLogLayout.deviceIdOf(f.name) != selfDeviceId)
          ChangesetLogLayout.deviceIdOf(f.name)!,
    };
    final retiredPeerHasFiles = files.any(
      (f) =>
          !ChangesetLogLayout.isRetiredMarker(f.name) &&
          retiredPeerIds.contains(ChangesetLogLayout.deviceIdOf(f.name)),
    );
    final peerManifests = <SyncManifest>[];
```

Inside the peer loop, first line: `if (retiredPeerIds.contains(peerId)) continue;`. After decoding `manifest` (before the epoch filter): `peerManifests.add(manifest);`.

Add ack tracking around the applies. After `var baseSeqApplied = cursor?.baseSeqApplied;`:

```dart
        var appliedHlc = cursor?.appliedHlcHigh;
```

After a successful base apply, credit the base's HLC only when it is exact (base is the whole log):

```dart
          // The manifest's publishedHlcHigh describes headSeq; it equals the
          // base's own high watermark only when the base IS the head. Never
          // over-claim an ack -- GC relies on it.
          if (baseSeq == manifest.headSeq) {
            appliedHlc = _maxHlc(appliedHlc, manifest.publishedHlcHigh);
          }
```

After each changeset apply (`await apply(cs); payloadsApplied++;`):

```dart
          appliedHlc = _maxHlc(appliedHlc, cs.toHlc);
```

Extend the cursor upsert call with `appliedHlcHigh: appliedHlc,` and add the helper + result fields:

```dart
  static String? _maxHlc(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }
```

```dart
    return ChangesetReadResult(
      peersProcessed: peersProcessed,
      payloadsApplied: payloadsApplied,
      peerManifests: peerManifests,
      retiredPeerIds: retiredPeerIds,
      retiredPeerHasFiles: retiredPeerHasFiles,
    );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/`
Expected: PASS (all changeset_log suites, old and new).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/peer_cursor_store.dart lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/
git commit -m "feat(sync): reader ack tracking, retired-peer skip, manifest reporting"
```

---

### Task 6: Writer publishes the ack map and heartbeats stale manifests

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart`
- Test: `test/core/services/sync/changeset_log/changeset_writer_test.dart` (extend)

**Interfaces:**
- Consumes: Task 3 manifest field, Task 4 `SyncLiveness.heartbeatMaxAgeMillis`.
- Produces: `ChangesetWriteKind.heartbeat` enum value; `ChangesetWriter` constructor gains `int heartbeatMaxAgeMillis = SyncLiveness.heartbeatMaxAgeMillis`; `publish()` gains `Map<String, String> appliedPeerHlc = const {}`.

- [ ] **Step 1: Write the failing tests** (append to `changeset_writer_test.dart`; reuse its `publish()`/`names()` helpers, but add a variant that passes the ack map)

```dart
  test('publish stamps appliedPeerHlc into the manifest', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final deviceId = await SyncRepository().getDeviceId();
    await writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: const [],
      appliedPeerHlc: const {'peer-a': '00000000000010:000000:peer-a'},
    );
    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    expect(manifest.appliedPeerHlc, {
      'peer-a': '00000000000010:000000:peer-a',
    });
  });

  test('empty publish heartbeats a stale manifest, preserving base and nonce', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final deviceId = await SyncRepository().getDeviceId();
    await writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: const [],
      uploadNonce: 'nonce-1',
    );
    // Age the manifest 8 days (past the 7-day heartbeat threshold).
    final name = ChangesetLogLayout.manifestName(deviceId);
    final fresh = SyncManifest.fromBytes(
      await provider.downloadFile('$folder/$name'),
    );
    final aged = SyncManifest(
      deviceId: fresh.deviceId,
      provider: fresh.provider,
      baseSeq: fresh.baseSeq,
      basePartCount: fresh.basePartCount,
      baseBytes: fresh.baseBytes,
      baseChecksum: fresh.baseChecksum,
      basePartChecksums: fresh.basePartChecksums,
      headSeq: fresh.headSeq,
      publishedHlcHigh: fresh.publishedHlcHigh,
      epochId: fresh.epochId,
      uploadNonce: fresh.uploadNonce,
      updatedAt: DateTime.now().millisecondsSinceEpoch -
          8 * 24 * 60 * 60 * 1000,
    );
    await provider.uploadFile(aged.toBytes(), name, folderId: folder);

    final result = await writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: await SyncRepository().getAllDeletions(),
      appliedPeerHlc: const {'peer-a': '00000000000099:000000:peer-a'},
    );
    expect(result.kind, ChangesetWriteKind.heartbeat);
    final after = SyncManifest.fromBytes(
      await provider.downloadFile('$folder/$name'),
    );
    expect(after.baseSeq, fresh.baseSeq);
    expect(after.headSeq, fresh.headSeq);
    expect(after.uploadNonce, 'nonce-1');
    expect(after.appliedPeerHlc, {'peer-a': '00000000000099:000000:peer-a'});
    expect(
      DateTime.now().millisecondsSinceEpoch - after.updatedAt,
      lessThan(60 * 1000),
    );
  });

  test('empty publish against a fresh manifest stays a noop', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

3a. `enum ChangesetWriteKind { base, changeset, compacted, heartbeat, noop }`

3b. Constructor: add `this.heartbeatMaxAgeMillis = SyncLiveness.heartbeatMaxAgeMillis,` and field `final int heartbeatMaxAgeMillis;` (import `sync_liveness.dart`).

3c. `publish()` signature: add `Map<String, String> appliedPeerHlc = const {},`.

3d. Thread `appliedPeerHlc: appliedPeerHlc,` into all three `SyncManifest(` constructions (first-base, changeset, and `_compact`'s — pass the map down to `_compact` as a new required parameter `required Map<String, String> appliedPeerHlc`).

3e. Replace the `_isEmpty` early return with the heartbeat branch:

```dart
    if (_isEmpty(payload)) {
      // Nothing to publish -- but a manifest that goes stale reads as a dead
      // device to peers (retirement) and its acks stop advancing GC. Rewrite
      // it (contents unchanged, fresh updatedAt + acks) past the threshold.
      // The nonce is preserved: a heartbeat is not an upload event and must
      // not disturb twin detection.
      if (ownManifest != null &&
          now - ownManifest.updatedAt > heartbeatMaxAgeMillis) {
        final beat = SyncManifest(
          deviceId: ownManifest.deviceId,
          provider: ownManifest.provider,
          baseSeq: ownManifest.baseSeq,
          basePartCount: ownManifest.basePartCount,
          baseBytes: ownManifest.baseBytes,
          baseChecksum: ownManifest.baseChecksum,
          basePartChecksums: ownManifest.basePartChecksums,
          headSeq: ownManifest.headSeq,
          publishedHlcHigh: ownManifest.publishedHlcHigh,
          epochId: ownManifest.epochId,
          uploadNonce: ownManifest.uploadNonce,
          appliedPeerHlc: appliedPeerHlc,
          updatedAt: now,
        );
        await _writeManifest(provider, folderId, deviceId, beat);
        return ChangesetWriteResult(
          ChangesetWriteKind.heartbeat,
          ownManifest.headSeq,
        );
      }
      return const ChangesetWriteResult(ChangesetWriteKind.noop);
    }
```

Note the base-branch noop (`base.rowCount == 0 && deletions.isEmpty`) stays a plain noop: in that branch there is no manifest to heartbeat.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_writer_test.dart
git commit -m "feat(sync): writer publishes ack map and heartbeats stale manifests"
```

---

### Task 7: Fleet-acked GC replaces the 90-day purge in performSync

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (add `clearAcknowledgedDeletions`, delete `clearOldDeletions`)
- Modify: `lib/core/services/sync/sync_service.dart` (performSync: capture pull result ~line 429, build ack map, pass to publish ~line 471, replace `clearOldDeletions()` at ~line 515)
- Modify: `test/core/data/repositories/sync_repository_error_test.dart:72` (replace the `clearOldDeletions` expectation with `clearAcknowledgedDeletions`)
- Test: `test/core/data/repositories/sync_repository_deletion_dedupe_test.dart` (extend)
- Test: `test/core/services/sync/sync_gc_horizon_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 4–6.
- Produces: `SyncRepository.clearAcknowledgedDeletions({String? upToHlc, required int floorCutoffMillis})`. `performSync` binds `final pullResult = await _changesetReader.pull(...)` and passes `appliedPeerHlc:` to `_changesetWriter.publish(...)`.

- [ ] **Step 1: Write the failing repository tests** (append to `sync_repository_deletion_dedupe_test.dart`)

```dart
  test('clearAcknowledgedDeletions honors hlc bound, floor, and null hlc', () async {
    final db = DatabaseService.instance.database;
    Future<void> seed(String id, int deletedAt, String? hlc) =>
        db.customStatement(
          "INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, hlc) "
          "VALUES ('$id', 'dives', '$id', $deletedAt, ${hlc == null ? 'NULL' : "'$hlc'"})",
        );
    await seed('acked-old', 100, '00000000000010:000000:x');
    await seed('unacked-old', 100, '00000000000050:000000:x');
    await seed('acked-young', 9000, '00000000000011:000000:x');
    await seed('no-hlc', 100, null);

    await SyncRepository().clearAcknowledgedDeletions(
      upToHlc: '00000000000020:000000:x',
      floorCutoffMillis: 5000,
    );

    final left = (await SyncRepository().getAllDeletions())
        .map((d) => d.recordId)
        .toSet();
    expect(left, {'unacked-old', 'acked-young', 'no-hlc'});
  });

  test('clearAcknowledgedDeletions with null upToHlc clears everything past the floor', () async {
    final repo = SyncRepository();
    await repo.logDeletion(entityType: 'dives', recordId: 'old', deletedAt: 100);
    await repo.logDeletion(entityType: 'dives', recordId: 'new', deletedAt: 9000);
    await repo.clearAcknowledgedDeletions(upToHlc: null, floorCutoffMillis: 5000);
    final left = (await repo.getAllDeletions()).map((d) => d.recordId).toSet();
    expect(left, {'new'});
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/data/repositories/sync_repository_deletion_dedupe_test.dart`
Expected: FAIL (method undefined).

- [ ] **Step 3: Implement the repository method and delete `clearOldDeletions`**

In `sync_repository.dart`, replace the whole `clearOldDeletions` method (~line 864) with:

```dart
  /// Fleet-acked tombstone GC: delete tombstones that (a) are older than the
  /// safety floor, (b) carry an HLC (a null-hlc tombstone cannot be compared
  /// so it is kept and rides every base -- rare and harmless), and (c) sort at
  /// or below [upToHlc], the minimum HLC every live peer's manifest
  /// acknowledges having applied from us. A null [upToHlc] means no live peer
  /// constrains GC (single-device library): the floor alone applies.
  /// Replaces the old unconditional 90-day purge, which silently resurrected
  /// records on devices offline longer than the window.
  Future<void> clearAcknowledgedDeletions({
    required String? upToHlc,
    required int floorCutoffMillis,
  }) async {
    try {
      await (_db.delete(_db.deletionLog)..where((t) {
            final base =
                t.deletedAt.isSmallerThanValue(floorCutoffMillis) &
                t.hlc.isNotNull();
            if (upToHlc == null) return base;
            return base & t.hlc.isSmallerOrEqualValue(upToHlc);
          }))
          .go();
      _log.info('Cleared acknowledged deletions (upTo: $upToHlc)');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear acknowledged deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Update `test/core/data/repositories/sync_repository_error_test.dart:72` to:

```dart
      await expectLater(
        repository.clearAcknowledgedDeletions(
          upToHlc: null,
          floorCutoffMillis: 0,
        ),
        throwsA(anything),
      );
```

- [ ] **Step 4: Wire performSync**

In `sync_service.dart` add imports for `tombstone_horizon.dart` and `sync_liveness.dart`. Then:

4a. Bind the pull (~line 429): `final pullResult = await _changesetReader.pull(`.

4b. Build the ack map right after the pull completes (before the publish block, ~line 448):

```dart
      // Acks to publish: the highest HLC applied from each peer, as recorded
      // by the reader (including this very pull).
      final cursorRows = await PeerCursorStore(
        DatabaseService.instance.database,
      ).allForProvider(provider.providerId);
      final appliedPeerHlc = <String, String>{
        for (final c in cursorRows)
          if (c.appliedHlcHigh != null) c.peerDeviceId: c.appliedHlcHigh!,
      };
```

4c. Pass it to the publish call (~line 471): add `appliedPeerHlc: appliedPeerHlc,` to `_changesetWriter.publish(...)`.

4d. Replace `await _syncRepository.clearOldDeletions();` (~line 515) with:

```dart
      // Fleet-acked tombstone GC (replaces the unconditional 90-day purge).
      final gc = TombstoneHorizon.compute(
        selfDeviceId: deviceId,
        peerManifests: pullResult.peerManifests,
        retiredPeerIds: pullResult.retiredPeerIds,
        nowMillis: now.millisecondsSinceEpoch,
      );
      if (gc.allowed) {
        await _syncRepository.clearAcknowledgedDeletions(
          upToHlc: gc.upToHlc,
          floorCutoffMillis:
              now.millisecondsSinceEpoch - SyncLiveness.gcFloorMillis,
        );
      }
```

- [ ] **Step 5: Write the integration test**

```dart
// test/core/services/sync/sync_gc_horizon_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';
import '../../../support/fake_cloud_storage_provider.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  const oldEnough = 40 * 24 * 60 * 60 * 1000; // past the 30-day floor

  Future<void> ageTombstone(String recordId) async {
    // Backdate the tombstone past the GC floor (logDeletion stamps "now").
    final cutoff = DateTime.now().millisecondsSinceEpoch - oldEnough;
    await DatabaseService.instance.database.customStatement(
      "UPDATE deletion_log SET deleted_at = $cutoff WHERE record_id = '$recordId'",
    );
  }

  Future<void> seedPeerManifestWithAck(
    FakeCloudStorageProvider cloud, {
    required String peerId,
    Map<String, String> applied = const {},
    int? updatedAt,
  }) async {
    final folder = await cloud.getOrCreateSyncFolder();
    final manifest = SyncManifest(
      deviceId: peerId,
      provider: cloud.providerId,
      headSeq: 1,
      baseSeq: null,
      publishedHlcHigh: null,
      appliedPeerHlc: applied,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await cloud.uploadFile(
      manifest.toBytes(),
      ChangesetLogLayout.manifestName(peerId),
      folderId: folder,
    );
  }

  test('a live peer without an ack blocks tombstone GC', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DiveRepository().deleteDive('d1');
    await ageTombstone('d1');
    await seedPeerManifestWithAck(cloud, peerId: 'peer-1'); // no acks
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final ids = (await SyncRepository().getAllDeletions())
        .map((d) => d.recordId);
    expect(ids, contains('d1'), reason: 'unacked tombstone must survive');
  });

  test('acked-by-all-live-peers tombstone is GCd; stale peers ignored', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DiveRepository().deleteDive('d1');
    await ageTombstone('d1');
    final selfId = await SyncRepository().getDeviceId();
    // Live peer acks far ahead of the tombstone's HLC; a 13-month-stale peer
    // with no acks must not block.
    await seedPeerManifestWithAck(
      cloud,
      peerId: 'peer-live',
      applied: {selfId: '99999999999999:999999:zzz'},
    );
    await seedPeerManifestWithAck(
      cloud,
      peerId: 'peer-stale',
      updatedAt: DateTime.now().millisecondsSinceEpoch -
          400 * 24 * 60 * 60 * 1000,
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final ids = (await SyncRepository().getAllDeletions())
        .map((d) => d.recordId);
    expect(ids, isNot(contains('d1')));
  });

  test('single-device library GCs down to the floor only', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'old', diveNumber: 1),
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'young', diveNumber: 2),
    );
    await DiveRepository().deleteDive('old');
    await DiveRepository().deleteDive('young');
    await ageTombstone('old'); // 'young' stays inside the 30-day floor
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final ids = (await SyncRepository().getAllDeletions())
        .map((d) => d.recordId)
        .toSet();
    expect(ids, {'young'});
  });
}
```

(`DiveRepository.deleteDive(String id)` is the verified method name — `dive_repository_impl.dart:1399`.)

- [ ] **Step 6: Run tests**

Run: `flutter test test/core/services/sync/sync_gc_horizon_test.dart test/core/data/repositories/sync_repository_deletion_dedupe_test.dart test/core/data/repositories/sync_repository_error_test.dart`
Expected: PASS. Then run the sync service suites to catch regressions:
`flutter test test/core/services/sync/`
Expected: PASS (some legacy tests may reference `clearOldDeletions` — update them to `clearAcknowledgedDeletions` with equivalent semantics if so).

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_service.dart test/core/data/repositories/ test/core/services/sync/sync_gc_horizon_test.dart
git commit -m "feat(sync): fleet-acked tombstone GC replaces the 90-day purge"
```

---

### Task 8: DeviceRetirement sweep

**Files:**
- Create: `lib/core/services/sync/changeset_log/device_retirement.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (performSync, right after the pull / ack-map block from Task 7)
- Test: `test/core/services/sync/changeset_log/device_retirement_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 2, 4, 5.
- Produces: `DeviceRetirement({int retirementPeriodMillis = SyncLiveness.retirementPeriodMillis})` with `Future<int> sweep({required CloudStorageProvider provider, required String folderId, required String selfDeviceId, required List<SyncManifest> peerManifests, required Set<String> alreadyRetired, required bool retiredPeerHasFiles, required int nowMillis})` returning the count of newly retired devices.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/changeset_log/device_retirement_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/device_retirement.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider cloud;
  late String folder;
  const now = 2000000000000;
  const thirteenMonths = 400 * 24 * 60 * 60 * 1000;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    folder = await cloud.getOrCreateSyncFolder();
  });
  tearDown(() => tearDownTestDatabase());

  Future<SyncManifest> peerManifest(String peerId, int updatedAt) async {
    final name = ChangesetLogLayout.manifestName(peerId);
    final fresh = SyncManifest.fromBytes(
      await cloud.downloadFile('$folder/$name'),
    );
    final aged = SyncManifest(
      deviceId: fresh.deviceId,
      provider: fresh.provider,
      baseSeq: fresh.baseSeq,
      basePartCount: fresh.basePartCount,
      baseBytes: fresh.baseBytes,
      baseChecksum: fresh.baseChecksum,
      basePartChecksums: fresh.basePartChecksums,
      headSeq: fresh.headSeq,
      publishedHlcHigh: fresh.publishedHlcHigh,
      updatedAt: updatedAt,
    );
    await cloud.uploadFile(aged.toBytes(), name, folderId: folder);
    return aged;
  }

  Future<List<String>> names() async {
    final files = await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    return files.map((f) => f.name).toList();
  }

  test('retires a 13-month-idle peer: marker first, files deleted', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-old');
    final aged = await peerManifest('peer-old', now - thirteenMonths);

    final retired = await DeviceRetirement().sweep(
      provider: cloud,
      folderId: folder,
      selfDeviceId: 'self',
      peerManifests: [aged],
      alreadyRetired: const {},
      retiredPeerHasFiles: false,
      nowMillis: now,
    );

    expect(retired, 1);
    final ns = await names();
    expect(ns, contains(ChangesetLogLayout.retiredMarkerName('peer-old')));
    expect(
      ns.where((n) => !ChangesetLogLayout.isRetiredMarker(n)).where(
        (n) => ChangesetLogLayout.deviceIdOf(n) == 'peer-old',
      ),
      isEmpty,
      reason: 'manifest, base parts, and changesets must be deleted',
    );
    final marker = RetirementMarker.fromBytes(
      await cloud.downloadFile(
        '$folder/${ChangesetLogLayout.retiredMarkerName('peer-old')}',
      ),
    );
    expect(marker.deviceId, 'peer-old');
  });

  test('never retires a fresh peer or self', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-fresh');
    final fresh = await peerManifest('peer-fresh', now - 1000);
    final selfAged = SyncManifest(
      deviceId: 'self',
      provider: cloud.providerId,
      headSeq: 1,
      updatedAt: now - thirteenMonths,
    );
    final retired = await DeviceRetirement().sweep(
      provider: cloud,
      folderId: folder,
      selfDeviceId: 'self',
      peerManifests: [fresh, selfAged],
      alreadyRetired: const {},
      retiredPeerHasFiles: false,
      nowMillis: now,
    );
    expect(retired, 0);
    expect(
      await names(),
      isNot(contains(ChangesetLogLayout.retiredMarkerName('peer-fresh'))),
    );
  });

  test('retries deletion for an already-marked peer with leftover files', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'p1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-partial');
    await cloud.uploadFile(
      const RetirementMarker(deviceId: 'peer-partial', retiredAt: 1).toBytes(),
      ChangesetLogLayout.retiredMarkerName('peer-partial'),
      folderId: folder,
    );
    final retired = await DeviceRetirement().sweep(
      provider: cloud,
      folderId: folder,
      selfDeviceId: 'self',
      peerManifests: const [],
      alreadyRetired: const {'peer-partial'},
      retiredPeerHasFiles: true,
      nowMillis: now,
    );
    expect(retired, 0);
    final ns = await names();
    expect(ns, contains(ChangesetLogLayout.retiredMarkerName('peer-partial')));
    expect(
      ns.where((n) => !ChangesetLogLayout.isRetiredMarker(n)).where(
        (n) => ChangesetLogLayout.deviceIdOf(n) == 'peer-partial',
      ),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/device_retirement_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement `device_retirement.dart`**

```dart
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Retires peers whose manifest has been idle past the retirement period:
/// writes a durable retirement marker FIRST (so the returning device always
/// detects it and rejoins through the fence), then deletes the peer's
/// manifest, base parts, and changesets. Wholly best-effort and idempotent:
/// leftover files after a partial sweep are retried whenever the reader
/// reports them ([retiredPeerHasFiles]); markers persist until the retired
/// device itself rejoins and deletes its own.
class DeviceRetirement {
  DeviceRetirement({
    this.retirementPeriodMillis = SyncLiveness.retirementPeriodMillis,
  });

  final int retirementPeriodMillis;

  Future<int> sweep({
    required CloudStorageProvider provider,
    required String folderId,
    required String selfDeviceId,
    required List<SyncManifest> peerManifests,
    required Set<String> alreadyRetired,
    required bool retiredPeerHasFiles,
    required int nowMillis,
  }) async {
    final candidates = <String>[
      for (final m in peerManifests)
        if (m.deviceId != selfDeviceId &&
            !alreadyRetired.contains(m.deviceId) &&
            nowMillis - m.updatedAt > retirementPeriodMillis)
          m.deviceId,
    ];
    if (candidates.isEmpty && !retiredPeerHasFiles) return 0;

    final toDelete = {...alreadyRetired};
    var retired = 0;
    for (final id in candidates) {
      // Marker BEFORE deletion: a partially retired device must still fence.
      final marker = RetirementMarker(deviceId: id, retiredAt: nowMillis);
      await provider.uploadFile(
        marker.toBytes(),
        ChangesetLogLayout.retiredMarkerName(id),
        folderId: folderId,
      );
      toDelete.add(id);
      retired++;
    }

    try {
      final files = await provider.listFiles(
        folderId: folderId,
        namePattern: ChangesetLogLayout.prefix,
      );
      for (final f in files) {
        final id = ChangesetLogLayout.deviceIdOf(f.name);
        if (id == null || !toDelete.contains(id)) continue;
        if (ChangesetLogLayout.isRetiredMarker(f.name)) continue;
        try {
          await provider.deleteFile(f.id);
        } catch (_) {
          // Leftovers are retried on a later sweep (retiredPeerHasFiles).
        }
      }
    } catch (_) {
      // Listing failed; markers are durable, deletion retries later.
    }
    return retired;
  }
}
```

- [ ] **Step 4: Wire into performSync** — in `sync_service.dart`, right after the Task 7 ack-map block (still before the publish), add:

```dart
      // Retire peers idle past the retirement period (best-effort; never
      // fatal to the sync). Marker-first ordering guarantees the fence.
      try {
        await DeviceRetirement().sweep(
          provider: provider,
          folderId: folderId,
          selfDeviceId: deviceId,
          peerManifests: pullResult.peerManifests,
          alreadyRetired: pullResult.retiredPeerIds,
          retiredPeerHasFiles: pullResult.retiredPeerHasFiles,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
      } catch (e) {
        _log.warning('Device retirement sweep failed (non-fatal): $e');
      }
```

(Import `device_retirement.dart`.)

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/services/sync/changeset_log/device_retirement_test.dart test/core/services/sync/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/core/services/sync/changeset_log/device_retirement.dart lib/core/services/sync/sync_service.dart test/core/services/sync/changeset_log/device_retirement_test.dart
git commit -m "feat(sync): retire idle devices with marker-first log deletion"
```

---

### Task 9: The fence — retired device rejoins via cloud-wins rebuild

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart`:
  - `_collectEpochBaseSources` (~line 2678): `String epochId` → `String? epochId`, add `Set<String> excludeDeviceIds = const {}`
  - performSync (~line 403, right after the twin-split block): fence check
  - New private methods `_checkRetirementFence`, `_rejoinAfterRetirement`, `_replayPendingSnapshot`
- Test: `test/core/services/sync/sync_retirement_fence_test.dart` (new)

**Interfaces:**
- Consumes: everything above, plus existing `_adoptApplyStreaming`, `_applyRemotePayload`, `PublishStateStore.markAdoptedPendingBase`/`resetForProvider`, `SyncRepository.resetSyncState/maxRowHlc/logDeletion`, `SyncClock.instance.issue()`, `SyncData.fromJson` (`sync_data_serializer.dart:386`).
- Produces: fence behavior inside `performSync`; no new public API.

- [ ] **Step 1: Write the failing end-to-end test**

```dart
// test/core/services/sync/sync_retirement_fence_test.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/changeset_test_helpers.dart';
import '../../../support/fake_cloud_storage_provider.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('retired device rejoins: cloud wins, pending records survive', () async {
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();

    // The current cloud library: peer-1 holds ONLY 'keep-1'. ('stale-1' was
    // deleted fleet-wide long ago; its tombstone is GC'd -- absent here.)
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'keep-1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1'); // resets the local DB afterwards

    // The returning device's local state, built AFTER the reset:
    // - 'stale-1': previously synced (published), deleted elsewhere since.
    // - 'mine-offline': created while offline, never published (pending).
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'stale-1', diveNumber: 2),
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);
    // Now go "offline": log a dive that never syncs before the retirement.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'mine-offline', diveNumber: 3),
    );

    // The fleet retires this device while it is away: marker + files deleted.
    final deviceId = await SyncRepository().getDeviceId();
    await cloud.uploadFile(
      RetirementMarker(
        deviceId: deviceId,
        retiredAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.retiredMarkerName(deviceId),
      folderId: folder,
    );
    await svc.deleteDeviceSyncFile(deviceId);

    // The device comes back and syncs: the fence must rebuild from the cloud.
    final result = await svc.performSync();
    expect(result.status, SyncResultStatus.success);

    final db = DatabaseService.instance.database;
    Future<bool> hasDive(String id) async =>
        (await db
            .customSelect("SELECT id FROM dives WHERE id = '$id'")
            .getSingleOrNull()) !=
        null;
    expect(await hasDive('keep-1'), isTrue, reason: 'cloud library adopted');
    expect(
      await hasDive('stale-1'),
      isFalse,
      reason: 'deleted-elsewhere record removed (silent cloud-wins)',
    );
    expect(
      await hasDive('mine-offline'),
      isTrue,
      reason: 'offline-created pending record must survive the fence',
    );

    // The marker is gone and the device published again (live once more).
    final names = (await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    ))
        .map((f) => f.name)
        .toList();
    expect(
      names,
      isNot(contains(ChangesetLogLayout.retiredMarkerName(deviceId))),
    );
    expect(
      names.where((n) => ChangesetLogLayout.deviceIdOf(n) == deviceId),
      isNotEmpty,
      reason: 'the rejoined device must publish its pending records',
    );

    // And the pending record actually reaches the cloud: a fresh device
    // adopting now must see mine-offline but not stale-1.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final svc2 = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    expect((await svc2.performSync()).status, SyncResultStatus.success);
    expect(await hasDive('mine-offline'), isTrue);
    expect(await hasDive('stale-1'), isFalse);
  });

  test('fence with no readable cloud library re-establishes from local', () async {
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final deviceId = await SyncRepository().getDeviceId();
    // Retired (marker present, own files gone) but NO peer library exists.
    await cloud.uploadFile(
      RetirementMarker(deviceId: deviceId, retiredAt: 1).toBytes(),
      ChangesetLogLayout.retiredMarkerName(deviceId),
      folderId: folder,
    );
    await svc.deleteDeviceSyncFile(deviceId);

    final result = await svc.performSync();
    expect(result.status, SyncResultStatus.success);
    final db = DatabaseService.instance.database;
    final row = await db
        .customSelect("SELECT id FROM dives WHERE id = 'd1'")
        .getSingleOrNull();
    expect(row, isNotNull, reason: 'local data must never be wiped');
    final names = (await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    ))
        .map((f) => f.name)
        .toList();
    expect(
      names,
      isNot(contains(ChangesetLogLayout.retiredMarkerName(deviceId))),
    );
    expect(
      names.where((n) => ChangesetLogLayout.deviceIdOf(n) == deviceId),
      isNotEmpty,
      reason: 'device republishes its library',
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/sync/sync_retirement_fence_test.dart`
Expected: FAIL — first test's `stale-1`/`mine-offline` assertions fail (no fence exists; the device just publishes a fresh base containing `stale-1`, resurrecting it).

- [ ] **Step 3: Generalize `_collectEpochBaseSources`**

Change the signature (~line 2678) to:

```dart
  _collectEpochBaseSources(
    CloudStorageProvider provider,
    String folderId,
    String? epochId, {
    Set<String> excludeDeviceIds = const {},
  }) async {
```

and inside the device loop add, right after `for (final deviceId in deviceIds) {`:

```dart
      if (excludeDeviceIds.contains(deviceId)) continue;
```

(`manifest.epochId != epochId` already handles null == null for the pre-epoch world. Existing callers pass a non-null epoch and no excludes — no behavior change.)

- [ ] **Step 4: Implement the fence** — add to `SyncService` (imports: `retirement_marker.dart` is not needed here since we only check the file NAME; `crypto`/`convert` for the checksum recompute; `sync_clock.dart` already imported):

```dart
  /// Retirement fence: if the fleet retired this device while it was offline
  /// (its retirement marker is present), rebuild from the current cloud
  /// library before doing anything else. Returns a terminal [SyncResult] only
  /// on failure; null means "not fenced" or "fence completed -- continue this
  /// sync normally" (the follow-through pull/publish then republishes us).
  Future<SyncResult?> _checkRetirementFence(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
    String? currentEpochId,
  ) async {
    final markerName = ChangesetLogLayout.retiredMarkerName(deviceId);
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final marker = files.where((f) => f.name == markerName).toList();
    if (marker.isEmpty) return null;
    final retiredPeers = <String>{
      for (final f in files)
        if (ChangesetLogLayout.isRetiredMarker(f.name) &&
            ChangesetLogLayout.deviceIdOf(f.name) != null)
          ChangesetLogLayout.deviceIdOf(f.name)!,
    };
    return _rejoinAfterRetirement(
      provider: provider,
      folderId: folderId,
      deviceId: deviceId,
      currentEpochId: currentEpochId,
      markerId: marker.first.id,
      retiredPeers: retiredPeers,
    );
  }

  Future<SyncResult?> _rejoinAfterRetirement({
    required CloudStorageProvider provider,
    required String folderId,
    required String deviceId,
    required String? currentEpochId,
    required String markerId,
    required Set<String> retiredPeers,
  }) async {
    _log.warning(
      'This device was retired while offline; rejoining from the cloud '
      'library (cloud-wins)',
    );
    final db = DatabaseService.instance.database;

    // 1. Snapshot unpublished local changes: everything above our last
    //    published watermark (rows AND deletions). This is exactly what the
    //    pending bookkeeping tracks, expressed as an HLC delta.
    final state = await _publishStateStore.get(provider.providerId);
    final watermark = state?.publishedHlcHigh;
    SyncPayload? pending;
    if (watermark != null) {
      pending = await _serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: watermark,
        deletions: await _syncRepository.getAllDeletions(),
        seq: 0,
      );
    }

    // 2. Rebuild from the current cloud library (authoritative). Excludes
    //    other retired devices' lingering logs -- their stale data must not
    //    ride back in through the fence.
    final sources = await _collectEpochBaseSources(
      provider,
      folderId,
      currentEpochId,
      excludeDeviceIds: retiredPeers,
    );
    if (sources.baseFilePaths.isEmpty) {
      // No readable library to rebuild from. Re-establish from the local
      // library instead of bricking (mirrors _recoverUnreadableEpoch): drop
      // the marker and let this same sync republish our base. Resurrection is
      // moot -- there is no fleet state to diverge from.
      _log.warning(
        'Retirement fence found no readable cloud library; re-establishing '
        'from the local library',
      );
      await provider.deleteFile(markerId);
      await _publishStateStore.resetForProvider(provider.providerId);
      await PeerCursorStore(db).resetForProvider(provider.providerId);
      return null;
    }
    try {
      await _serializer.applyInDeferredFkTransaction(
        () => _adoptApplyStreaming(
          baseFilePaths: sources.baseFilePaths,
          baseExportedAt: sources.baseExportedAt,
          changesets: sources.changesets,
        ),
      );
    } finally {
      for (final path in sources.baseFilePaths) {
        await _baseSink.deleteQuietly(path);
      }
    }

    // 3. Re-baseline exactly as adopt does: cloud is the authority.
    await _syncRepository.resetSyncState(clearDeletionLog: true);
    final cursorStore = PeerCursorStore(db);
    for (final c in sources.cursors) {
      await cursorStore.upsert(
        peerDeviceId: c.deviceId,
        provider: provider.providerId,
        baseSeqApplied: c.baseSeq,
        lastSeqApplied: c.appliedThrough,
      );
    }
    await _publishStateStore.markAdoptedPendingBase(
      provider.providerId,
      await _syncRepository.maxRowHlc(),
    );

    // 4. Replay the pending snapshot: offline-created records survive.
    if (pending != null) {
      await _replayPendingSnapshot(pending);
    }

    // 5. Live again: drop our marker. The rest of this sync pulls (cursors
    //    already positioned) and publishes the replayed pending records.
    await provider.deleteFile(markerId);
    _log.info('Rejoined after retirement');
    return null;
  }

  /// Re-applies the pre-fence pending snapshot with FRESH HLC stamps. The
  /// adopted watermark (maxRowHlc after the rebuild) is at or above the
  /// snapshot's original stamps, so without re-stamping the rows would sort
  /// below the publish watermark and never reach the cloud. Deletions are
  /// re-logged through logDeletion (which stamps a fresh HLC) for the same
  /// reason; their local effect still applies via the payload's deletions,
  /// under the standard deletedAt-vs-updatedAt LWW (a peer's newer edit
  /// legitimately revives the record -- unchanged semantics).
  Future<void> _replayPendingSnapshot(SyncPayload pending) async {
    await _syncRepository.ensureSyncClockConfigured();
    final dataJson = pending.data.toJson();
    final restamped = <String, dynamic>{};
    for (final entry in dataJson.entries) {
      final rows = entry.value;
      if (rows is! List) {
        restamped[entry.key] = rows;
        continue;
      }
      restamped[entry.key] = [
        for (final row in rows)
          if (row is Map<String, dynamic> && row.containsKey('hlc'))
            {...row, 'hlc': SyncClock.instance.issue()}
          else
            row,
      ];
    }
    final data = SyncData.fromJson(restamped);
    final payload = SyncPayload(
      version: pending.version,
      exportedAt: pending.exportedAt,
      deviceId: pending.deviceId,
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: pending.deletions,
    );
    await _applyRemotePayload(payload, null);
    // Re-mark the replayed rows pending: the fence's resetSyncState cleared
    // the pending table, and the remote-apply path above does not repopulate
    // it, so without this _shouldSkipPublishAfterAdopt would read "nothing to
    // say" and the replayed records would never publish until an unrelated
    // later edit re-tripped the gate. (The publish CONTENT is selected by the
    // HLC watermark; these marks only open the gate.)
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    for (final entry in restamped.entries) {
      final rows = entry.value;
      if (rows is! List) continue;
      for (final row in rows) {
        final id = row is Map<String, dynamic> ? row['id'] : null;
        if (id is! String) continue;
        await _syncRepository.markRecordPending(
          entityType: entry.key,
          recordId: id,
          localUpdatedAt: nowMillis,
        );
      }
    }
    for (final entry in pending.deletions.entries) {
      for (final d in entry.value) {
        await _syncRepository.logDeletion(
          entityType: entry.key,
          recordId: d.id,
          deletedAt: d.deletedAt,
        );
      }
    }
  }
```

- [ ] **Step 5: Wire into performSync** — insert right after the twin-split block (~line 403, after `final adoptedFreshIdentity = twin.adopted;`):

```dart
      // ---- Retirement fence ----
      // The fleet retired this device while it was offline (its tombstone
      // horizon has moved past what we know): rebuild from the cloud library
      // before merging anything, or stale local rows would resurrect
      // fleet-wide. Detected ONLY by the durable marker -- a missing manifest
      // alone is routine listing lag and cold-starts harmlessly.
      final fenceResult = await _checkRetirementFence(
        provider,
        folderId,
        deviceId,
        currentEpochId,
      );
      if (fenceResult != null) return fenceResult;
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/services/sync/sync_retirement_fence_test.dart`
Expected: PASS (2 tests). If the first test fails on `mine-offline` missing from the cloud, check the re-stamp ordering: `maxRowHlc()` must be captured for `markAdoptedPendingBase` BEFORE `_replayPendingSnapshot` runs (the code above does this — step 3 before step 4).

Then the full sync suites:
`flutter test test/core/services/sync/ test/core/data/repositories/`
Expected: PASS.

- [ ] **Step 7: Full verification, format, commit**

```bash
dart format .
flutter analyze
flutter test test/core/services/sync/ test/core/data/repositories/ test/core/database/
git add lib/core/services/sync/sync_service.dart test/core/services/sync/sync_retirement_fence_test.dart
git commit -m "feat(sync): retirement fence -- cloud-wins rejoin preserving pending records"
```

---

## Post-implementation checklist

- [ ] `dart format .` produces no changes; `flutter analyze` clean.
- [ ] Run the complete sync-adjacent suites once: `flutter test test/core/services/sync/ test/core/data/repositories/ test/core/database/`.
- [ ] Verify spec invariants against the code: (1) marker-before-deletion in `DeviceRetirement.sweep`; (2) GC blocked by any live no-ack manifest in `TombstoneHorizon.compute`; (3) base still exports the full retained deletion log (untouched `exportBaseToTempFile` path); (4) heartbeat preserves `uploadNonce`.
- [ ] Update `docs/superpowers/specs/2026-07-16-tombstone-gc-device-retirement-design.md` status line to "Implemented".
