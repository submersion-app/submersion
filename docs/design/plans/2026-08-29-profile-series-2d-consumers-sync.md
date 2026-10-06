# Profile Series Plan 2d: SQL Consumers and Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every remaining reader of `dive_profiles` / `tank_pressure_profiles` outside the 2b fallbacks moves to the series tables, the two series entities become first-class synced entities (export by hlc, LWW apply, tombstones, parent guards), the legacy entities stop being exported but still apply when an older peer sends them (packed into series on arrival), the schema floor rises to 182, the computer unlink and relink statements get series twins, and the thirteen tests plan 2c left red go green.

**Architecture:** Plans 2a to 2c (done) created the tables, made reads series-first with a legacy fallback and moved every writer. What is left reads legacy rows directly: nine SQL consumers (deco signals, profile span, quality context and prefilters, the two whole-library aggregations), the sync serializer, and three `UPDATE dive_profiles` unlink or relink statements. Seven of the nine consumers stay SQL and read the series summary columns (`has_deco_type`, `has_deco_stop`, `has_positive_ceiling`, `first_depth`, `last_depth`, `start_timestamp`, `end_timestamp`); the two aggregations (sustained ascent and descent rates, time-at-depth buckets) move to Dart over decoded primary series on a worker isolate with the same window and threshold constants. Sync registers `diveProfileSeries` and `tankPressureSeries` the way `gpsTracks` is registered (a BLOB entity exported by `hlc > since`, base64 on the wire). The legacy entities leave `_baseTables` and `SyncData.toJson` but stay parseable on the inbound side; after a merge that carried legacy rows, the migration packer runs so a new dive from an older peer lands as series.

**Tech Stack:** Flutter, Drift 2.34.3, SQLite; `ProfileSeriesCodec` / `TankPressureSeriesCodec` (PR 1); `flutter test`; `dart format`; `flutter analyze`; `compute` from `package:flutter/foundation.dart`.

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md` (sections 3, 6 "Reads", 7, 9, 12 bind this plan; section 10's benchmark gates and section 8's VACUUM are plan 2e). The 2b/2c hand-off notes (session scratchpad `2b-handoff-checklist.md`) are folded into the constraints and Task 9.

## Global Constraints

- Schema version stays 182. No migration, no new table, no new column. `AppDatabase.minimumCompatibleSchemaVersion` rises from 170 to 182 (Task 3) with the doc paragraph the existing comment format requires.
- Series summary columns are the SQL surface: `dive_profile_series(id, dive_id, computer_id, source_id, is_primary, sample_count, start_timestamp, end_timestamp, max_depth, first_depth, last_depth, has_deco_type, has_deco_stop, has_positive_ceiling, codec_version, samples, created_at, updated_at, hlc)` and `tank_pressure_series(id, dive_id, tank_id, computer_id, sample_count, start_timestamp, end_timestamp, codec_version, samples, created_at, updated_at, hlc)`. No SQL in this plan decodes `samples`.
- Decode only inside the two series repositories and, for the two whole-library aggregations, inside the worker-isolate entry points of `lib/features/statistics/data/series_profile_aggregates.dart` (spec section 6: "Whole-library aggregations decode on a worker isolate via `compute`").
- Parity rule: each moved consumer returns exactly what the legacy SQL returned for the equivalent rows. The legacy scanned ALL rows of a dive for the deco flags and the profile span, PRIMARY rows only for quality samples, prefilters and the two aggregations; the series versions scan the same set of series.
- Legacy DELETE statements and the 2b `_...Legacy` fallbacks stay (plan 2e removes them). No task in this plan adds a legacy INSERT or UPDATE; the three existing `UPDATE dive_profiles SET computer_id` statements STAY and gain series twins beside them.
- Sync: the series entities are exported by `hlc > since` with `blob: true` (base64 `samples`), applied by `insertOnConflictUpdate` on the series id (LWW by hlc through the existing `_mergeEntity`), tombstoned one per series, guarded by `parentRefs` (`dives`, `diveComputers`, `diveDataSources`, plus `diveTanks` for tank series). The legacy entities keep their inbound apply, delete, `recordIdsFor` and `tableFor` cases and their `parentRefs` entries, but leave `_baseTables`, `SyncData.toJson`, `exportChangeset` and `entityHasUpdatedAt`.
- Apply-time validation: a series row arriving from a peer is decoded once before it is written; a blob that fails `ProfileSeriesCodec.decode` / `TankPressureSeriesCodec.decode`, or whose decoded sample count differs from `sampleCount`, is logged and skipped (never written). A corrupt peer blob must not reach the readers.
- Drift name clash: files that import both `database.dart` and `entities/profile_series.dart` import the entity file `as series`.
- No em-dashes (U+2014) or en-dashes used as punctuation anywhere (code, comments, tests, commit messages). No emojis. Immutability: never mutate a list handed in; build new lists.
- TDD per task; `dart format .` from the worktree root; `flutter analyze` zero issues (infos included); tests run per file with `flutter test <path>`, never piped; stage explicit paths; one local commit per task with the message given; no push; no `Co-Authored-By` trailer; never `git stash`.
- Worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage-2`, branch `worktree-profile-sample-storage-2`, absolute paths only.
- Known red on entry (plan 2c left them; every one goes green in this plan): `quality_context_builder_test` (2), `quality_prefilters_test` (1), `dashboard_queries_test` (1), `dive_repository_deco_filter_test` (3), `dive_times_accessors_test` (2), `deco_filter_providers_test` (3), `consolidation_sync_roundtrip_test` (1). `local_file_resolver_test` is a machine flake (mounted `$TMPDIR`).

## File structure

| File | Responsibility after this plan |
|---|---|
| `lib/core/services/sync/sync_data_serializer.dart` | series entities in `_baseTables`, `SyncData`, `exportChangeset`, `fetchRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `tableFor`, `deleteRecord`; apply-time blob validation; legacy entities inbound-only; `packLegacySamples()` shim entry |
| `lib/core/services/sync/sync_service.dart` | `mergeOrder`, `entityHasUpdatedAt`, `parentRefs` entries for the series; post-merge packing call |
| `lib/core/database/database.dart` | `minimumCompatibleSchemaVersion = 182` and its doc paragraph |
| `lib/features/statistics/data/dive_filter_sql.dart` | `decoSignalCondition` over series flags |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `had_deco`, `_effectiveRuntimeSql`, `_diveTimesSelect` over series; `readsFrom` sets |
| `lib/features/statistics/data/repositories/statistics_repository.dart` | `scanRecordedDecoSignals` over series flags; `getAscentDescentRates` / `getTimeAtDepthRanges` delegate to the Dart aggregates; `watchStatisticsChanges` watches the series tables |
| `lib/features/statistics/data/series_profile_aggregates.dart` (new) | pure aggregation functions over decoded series plus the `compute` entry points that decode raw blobs |
| `lib/features/data_quality/data/services/quality_context_builder.dart`, `quality_prefilters.dart` | primary samples and pressures from the series repositories; neighbour first/last depth and prefilter EXISTS over series |
| `lib/features/dive_log/data/repositories/profile_series_repository.dart`, `tank_pressure_series_repository.dart` | `clearComputer`, `clearComputersOfDiverForForeignDives`, `relinkComputer` (profile only) |
| `lib/features/divers/data/repositories/diver_repository.dart`, `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | series twins beside the three legacy `UPDATE dive_profiles` statements; `getDiveIdsForComputer` over series |

---

### Task 1: Register the series entities in sync

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`SyncData` fields/`toJson`/`fromJson`; `_baseTables`; `exportChangeset`; `fetchRecord`; `upsertRecord`; `upsertRecords`; `recordIdsFor`; `tableFor`; `deleteRecord`)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` entries; `entityHasUpdatedAt`; `parentRefs`)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` gains the two tables)
- Test: `test/core/services/sync/profile_series_sync_test.dart` (new)

**Interfaces:**
- Consumes: `DiveProfileSeriesRow` / `TankPressureSeriesRow` (Drift data classes with `fromJson(json, {serializer})` / `toJson({serializer})`), `_syncBlobSerializer`, `_exportGpsTracks` as the pattern, `ProfileSeriesCodec().decode(Uint8List)` and `TankPressureSeriesCodec().decode(Uint8List)` (each returns an object exposing `samples`; check the exact return type in `lib/features/dive_log/domain/codecs/`), `ProfileSeriesCodecException` (and the tank codec's exception type; check its name).
- Produces: wire keys `diveProfileSeries` and `tankPressureSeries` (the entity types already used by `SyncRepository.hlcTargets` and the repositories' tombstones); `SyncData.diveProfileSeries` / `SyncData.tankPressureSeries` (`List<Map<String, dynamic>>`); `SyncDataSerializer` cases for both types in every switch; `SyncService.parentRefs['diveProfileSeries']` and `['tankPressureSeries']`.

- [ ] **Step 1: Write the failing test**

`test/core/services/sync/profile_series_sync_test.dart`, modelled on `test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart` (two `AppDatabase`s, `switchTo(db)` via `DatabaseService.instance.setTestDatabase`, `FakeCloudStorageProvider`, `SyncService(syncRepository: SyncRepository(), serializer: SyncDataSerializer(), cloudProvider: cloud)`, `performSync()`), with FK parents seeded on both devices the way that test's `seedFkPrereqs` does (diver, computers, tags):

```dart
  test('a series pushed by A arrives on B byte for byte and reads back', () async {
    dbB = await setUpTestDatabase();
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 1, 1, 10),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
          domain.DiveProfilePoint(timestamp: 60, depth: 18.5, decoType: 2, ceiling: 3.0),
        ],
      ),
    );
    final rowOnA = (await ProfileSeriesRepository().getRowsForDives(['d1'])).single;
    expect((await buildService().performSync()).isSuccess, isTrue);

    switchTo(dbB);
    await seedFkPrereqs(dbB);
    expect((await buildService().performSync()).isSuccess, isTrue);
    final rowOnB = (await ProfileSeriesRepository().getRowsForDives(['d1'])).single;
    expect(rowOnB.id, rowOnA.id);
    expect(rowOnB.samples, rowOnA.samples);
    expect(rowOnB.hasDecoStop, isTrue);
    expect((await DiveRepository().getDiveProfile('d1')).map((p) => p.depth), [0.0, 18.5]);
  });

  test('a series deleted on A is tombstoned and removed on B', () async {
    // seed as above, sync both ways, then on A:
    await ProfileSeriesRepository().deleteForDive('d1');
    expect((await buildService().performSync()).isSuccess, isTrue);
    switchTo(dbB);
    expect((await buildService().performSync()).isSuccess, isTrue);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test('fetchRecord carries samples as base64 and upsertRecord round-trips it', () async {
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedFkPrereqs(dbA);
    final id = await ProfileSeriesRepository().insertSeries(
      diveId: 'd1', // seed dive d1 first with DivesCompanion.insert
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord('diveProfileSeries', id);
    expect(json!['samples'], isA<String>());
    await ProfileSeriesRepository().deleteForDive('d1');
    await SyncDataSerializer().upsertRecord('diveProfileSeries', json);
    expect((await ProfileSeriesRepository().getSeriesForDive('d1')).single.samples.single.depth, 1.0);
  });

  test('a corrupt peer blob is skipped, never written', () async {
    // fetchRecord as above, then corrupt: json['samples'] = base64Encode([1, 2, 3]);
    await SyncDataSerializer().upsertRecord('diveProfileSeries', corrupted);
    expect(await ProfileSeriesRepository().getSeriesForDive('d1'), isEmpty);
  });

  test('a peer blob whose sample count disagrees with the header is skipped', () async {
    // fetchRecord, then json['sampleCount'] = 99; upsert; expect no row.
  });
```

Add the tank twins of the first and third tests (`TankPressureSeriesRepository`, a tank seeded on both devices, `getRowsForDives`, `fetchRecord('tankPressureSeries', id)`). Write every body in full; the `seedFkPrereqs` / `switchTo` / `buildService` helpers are copied from the consolidation round-trip test.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/profile_series_sync_test.dart`
Expected: B holds no series (the entity is not exported); `fetchRecord` returns null for the unknown type.

- [ ] **Step 3: Serializer registration**

In `sync_data_serializer.dart`:

1. `SyncData`: add `final List<Map<String, dynamic>> diveProfileSeries;` and `final List<Map<String, dynamic>> tankPressureSeries;` as the LAST two fields, constructor parameters `this.diveProfileSeries = const [], this.tankPressureSeries = const []` last, `toJson` entries `'diveProfileSeries': diveProfileSeries, 'tankPressureSeries': tankPressureSeries` last, `fromJson` entries `diveProfileSeries: _parseList(json['diveProfileSeries']), tankPressureSeries: _parseList(json['tankPressureSeries'])` last. Order matters: `_baseTables` must list exactly `SyncData.toJson` keys in order (`base_publish_streaming_parity_test`).
2. `_baseTables`: append `(key: 'diveProfileSeries', table: _db.diveProfileSeries, blob: true, full: null)` and `(key: 'tankPressureSeries', table: _db.tankPressureSeries, blob: true, full: null)` as the LAST two entries (after `fieldPresets`; every FK parent, `dives`, `diveComputers`, `diveTanks`, `diveDataSources`, precedes them).
3. `exportChangeset`: after the last `_safeExport` add `diveProfileSeries: await _safeExport('diveProfileSeries', () => _exportDiveProfileSeries(hlcSince)), tankPressureSeries: await _safeExport('tankPressureSeries', () => _exportTankPressureSeries(hlcSince)),` and add, next to `_exportGpsTracks`:

```dart
  Future<List<Map<String, dynamic>>> _exportDiveProfileSeries(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.diveProfileSeries);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    // The packed samples BLOB rides as base64, like gps_tracks.points.
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTankPressureSeries(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tankPressureSeries);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }
```

4. `fetchRecord`: cases mirroring `gpsTracks` (`select ... where id equals`, `row?.toJson(serializer: _syncBlobSerializer)`).
5. `upsertRecord`: 

```dart
      case 'diveProfileSeries':
        final row = DiveProfileSeriesRow.fromJson(
          data,
          serializer: _syncBlobSerializer,
        );
        if (!_profileSeriesBlobIsSound(row)) return;
        await _db.into(_db.diveProfileSeries).insertOnConflictUpdate(row);
        return;
      case 'tankPressureSeries':
        final row = TankPressureSeriesRow.fromJson(
          data,
          serializer: _syncBlobSerializer,
        );
        if (!_tankSeriesBlobIsSound(row)) return;
        await _db.into(_db.tankPressureSeries).insertOnConflictUpdate(row);
        return;
```

with

```dart
  /// A peer's packed samples are decoded once before they are written so a
  /// corrupt or truncated blob never reaches the readers. Returns false (and
  /// logs) when the blob does not decode or its sample count disagrees with
  /// the header the row carries.
  bool _profileSeriesBlobIsSound(DiveProfileSeriesRow row) {
    try {
      final decoded = const ProfileSeriesCodec().decode(row.samples);
      if (decoded.samples.length != row.sampleCount) {
        _log.warning(
          'Skipping diveProfileSeries ${row.id}: header says '
          '${row.sampleCount} samples, blob holds ${decoded.samples.length}',
        );
        return false;
      }
      return true;
    } on ProfileSeriesCodecException catch (e) {
      _log.warning('Skipping diveProfileSeries ${row.id}: $e');
      return false;
    }
  }
```

and the tank twin (`TankPressureSeriesCodec`, its exception type). Check the codec API (`decode` return shape and exception names) in `lib/features/dive_log/domain/codecs/` before writing; if `decode` returns a record or a class with a different accessor, adapt the two lines that read `samples`. `_log` is the serializer's existing logger field (grep `_log` in the file; if the file logs through another name, use that).

6. `upsertRecords`: batch cases like `gpsTracks` but filtered through the soundness check:

```dart
      case 'diveProfileSeries':
        final rows = [
          for (final r in records)
            DiveProfileSeriesRow.fromJson(r, serializer: _syncBlobSerializer),
        ].where(_profileSeriesBlobIsSound).toList();
        if (rows.isEmpty) return;
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(_db.diveProfileSeries, rows),
        );
        return;
```

and the tank twin.

7. `recordIdsFor`: `case 'diveProfileSeries': return plain(_db.diveProfileSeries, _db.diveProfileSeries.id);` and the tank twin. `tableFor`: return the two tables. `deleteRecord`: `delete ... where id equals recordId` for both, like `gpsTracks`.

In `sync_service.dart`:

8. `mergeOrder`: insert, immediately AFTER the `diveDataSources` entry, `(type: 'diveProfileSeries', records: data.diveProfileSeries, hasUpdatedAt: true), (type: 'tankPressureSeries', records: data.tankPressureSeries, hasUpdatedAt: true),` (every FK parent precedes: `diveComputers`, `dives`, `diveTanks`, `diveDataSources`).
9. `entityHasUpdatedAt`: `'diveProfileSeries': true, 'tankPressureSeries': true,`.
10. `parentRefs`:

```dart
    'diveProfileSeries': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
      (field: 'sourceId', parent: 'diveDataSources', nullable: true),
    ],
    'tankPressureSeries': [
      (field: 'diveId', parent: 'dives', nullable: false),
      (field: 'tankId', parent: 'diveTanks', nullable: false),
      (field: 'computerId', parent: 'diveComputers', nullable: true),
    ],
```

11. `test/core/services/sync/sync_parent_refs_completeness_test.dart`: add `'dive_profile_series': 'diveProfileSeries', 'tank_pressure_series': 'tankPressureSeries',` to `syncedTables`.

- [ ] **Step 4: Run the tests**

Run the new file, then `test/core/services/sync/base_publish_streaming_parity_test.dart`, `sync_parent_refs_completeness_test.dart`, `sync_hlc_target_registration_test.dart`, the structural test that asserts `entityHasUpdatedAt` covers exactly the `SyncData` entities (`grep -rl "entityHasUpdatedAt" test/core/services/sync`), `cross_version_roundtrip_test.dart`, `test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart` (this was red on entry; it must pass now), and `grep -rl "SyncDataSerializer()" test/core/services/sync | head -20` files.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/profile_series_sync_test.dart
git commit -m "feat(sync): profile and tank pressure series are synced entities with apply-time blob validation"
```

---

### Task 2: Legacy sample entities become inbound-only, packed on arrival

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_baseTables`, `SyncData.toJson`, `exportChangeset`; delete `_exportDiveProfiles` / `_exportTankPressureProfiles`; add `packLegacySamples`)
- Modify: `lib/core/services/sync/sync_service.dart` (`entityHasUpdatedAt`; post-merge packing)
- Test: `test/core/services/sync/legacy_sample_entities_inbound_test.dart` (new)

**Interfaces:**
- Consumes: `packLegacyProfileRows(DatabaseConnectionUser db, {int? nowMs})` from `lib/core/database/profile_series_pack.dart` (packs every dive that has legacy rows and NO series row, deterministic migrated ids, one series per identity group); the legacy `upsertRecord` / `upsertRecords` cases for `diveProfiles` / `tankPressureProfiles` (kept).
- Produces: `Future<ProfilePackReport> SyncDataSerializer.packLegacySamples()`; `SyncData.diveProfiles` / `tankPressureProfiles` documented as inbound-only (parsed by `fromJson`, absent from `toJson`).

- [ ] **Step 1: Write the failing test**

`test/core/services/sync/legacy_sample_entities_inbound_test.dart`, on the fixture of `cross_version_roundtrip_test.dart` (`seedPeerBaseFromPayload(cloud, 'peer-181', payload)` with a hand-built `SyncPayload`, then `performSync()`):

```dart
  test('exportChangeset carries no legacy sample entities', () async {
    await DiveRepository().createDive(dive('d1', twoPoints));
    final data = await SyncDataSerializer().exportChangeset(
      deviceId: 'me',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(data.toJson().containsKey('diveProfiles'), isFalse);
    expect(data.toJson().containsKey('tankPressureProfiles'), isFalse);
    expect(data.diveProfileSeries, hasLength(1));
  });

  test('a v181 peer payload with legacy rows for a new dive lands as a series', () async {
    // build a dives row (fetchRecord('dives', ...) style, see cross_version_roundtrip_test)
    // for 'd-old' plus two legacy diveProfiles maps:
    final profiles = [
      {'id': 'p1', 'diveId': 'd-old', 'timestamp': 0, 'depth': 0.0, 'isPrimary': true},
      {'id': 'p2', 'diveId': 'd-old', 'timestamp': 60, 'depth': 12.0, 'isPrimary': true},
    ];
    final data = SyncData(dives: [diveRow], diveProfiles: profiles);
    // SyncData.fromJson(data.toJson()) would DROP diveProfiles (inbound only),
    // so build the payload JSON by hand: jsonEncode({...data.toJson(), 'diveProfiles': profiles})
    await pullPeerPayload(payloadJson);
    final series = await ProfileSeriesRepository().getSeriesForDive('d-old');
    expect(series, hasLength(1));
    expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
    expect(series.single.id, profileSeriesMigratedId(diveId: 'd-old', computerId: null, sourceId: null, isPrimary: true));
  });

  test('legacy rows for a dive that already has series are ignored', () async {
    await DiveRepository().createDive(dive('d1', twoPoints));
    final before = (await ProfileSeriesRepository().getSeriesForDive('d1')).single;
    // payload with legacy diveProfiles for d1 carrying depth 99
    await pullPeerPayload(payloadJson);
    final after = (await ProfileSeriesRepository().getSeriesForDive('d1')).single;
    expect(after.id, before.id);
    expect(after.samples.map((s) => s.depth), before.samples.map((s) => s.depth));
  });

  test('SyncData.fromJson still parses the legacy keys', () {
    final data = SyncData.fromJson({'diveProfiles': [{'id': 'x'}], 'tankPressureProfiles': [{'id': 'y'}]});
    expect(data.diveProfiles.single['id'], 'x');
    expect(data.tankPressureProfiles.single['id'], 'y');
  });
```

Check `profileSeriesMigratedId`'s exact named parameters in `lib/features/dive_log/domain/entities/profile_series_identity.dart`. Write every body in full.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/legacy_sample_entities_inbound_test.dart`
Expected: the export test fails on `containsKey('diveProfiles')`; the inbound tests fail on an empty series list.

- [ ] **Step 3: Implement**

`sync_data_serializer.dart`:
- Remove the `diveProfiles` and `tankPressureProfiles` entries from `_baseTables` and from `SyncData.toJson`; keep the two fields, their constructor defaults and their `fromJson` lines, and add above the fields: `/// Inbound only since v182: older peers still send row-per-sample arrays; they apply into the legacy tables and are packed into series by [SyncDataSerializer.packLegacySamples]. Never exported, absent from [toJson].`
- Remove the two `_safeExport('diveProfiles', ...)` / `_safeExport('tankPressureProfiles', ...)` lines from `exportChangeset`; delete `_exportDiveProfiles` and `_exportTankPressureProfiles`.
- Add:

```dart
  /// Packs legacy row-per-sample rows that an older peer's changeset left in
  /// `dive_profiles` / `tank_pressure_profiles` into series rows. Dives that
  /// already have a series are left alone: the peer is held below the floor
  /// and will migrate its own rows when it upgrades.
  Future<ProfilePackReport> packLegacySamples() => packLegacyProfileRows(_db);
```

(import `package:submersion/core/database/profile_series_pack.dart`; `ProfilePackReport` is its typedef.)

`sync_service.dart`:
- Remove `'diveProfiles'` and `'tankPressureProfiles'` from `entityHasUpdatedAt` (the structural test compares its keys to `SyncData.toJson`). Keep their `mergeOrder` entries (they read `data.diveProfiles` / `data.tankPressureProfiles`, still parsed inbound), their `parentRefs` entries, and every legacy switch case in the serializer.
- In the merge method, after the `for (final entry in mergeOrder)` loop and BEFORE `await _serializer.repairDanglingForeignKeys();`, add:

```dart
    if (data.diveProfiles.isNotEmpty || data.tankPressureProfiles.isNotEmpty) {
      // v182 receive-side tolerance: an older peer's row-per-sample arrays
      // become series for dives that have none yet.
      final packed = await _serializer.packLegacySamples();
      _log.info(
        'Packed legacy sample rows from a peer: '
        '${packed.profileSeries} profile series, '
        '${packed.tankSeries} tank series',
      );
    }
```

(`data` is the `SyncData` the merge method receives; check the parameter name in `sync_service.dart` and use it.)

- [ ] **Step 4: Run the tests**

Run the new file, `profile_series_sync_test.dart`, `base_publish_streaming_parity_test.dart`, the `entityHasUpdatedAt` structural test, `cross_version_roundtrip_test.dart`, `consolidation_sync_roundtrip_test.dart`, and every test under `test/core/services/sync/` that mentions `diveProfiles` or `tankPressureProfiles` (`grep -rl "diveProfiles\|tankPressureProfiles" test/core/services/sync`); expectations that asserted the legacy keys in an EXPORT change to the series keys; expectations about INBOUND legacy apply stay.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/legacy_sample_entities_inbound_test.dart <every adjusted sync test by path>
git commit -m "feat(sync): legacy sample entities are inbound-only and packed into series on arrival"
```

---

### Task 3: Raise the schema floor to 182

**Files:**
- Modify: `lib/core/database/database.dart` (`minimumCompatibleSchemaVersion` and its doc comment, near line 3460)
- Modify: `test/core/services/sync/cross_version_roundtrip_test.dart` (one new group for the v182 boundary)
- Verify: whatever test pins the floor value today (`grep -rln "minimumCompatibleSchemaVersion" test`); update its expected number.

**Interfaces:**
- Consumes: Task 2's inbound packing (`SyncDataSerializer.packLegacySamples`, the kept legacy apply cases).
- Produces: `AppDatabase.minimumCompatibleSchemaVersion == 182`.

- [ ] **Step 1: Write the failing test**

Append to `cross_version_roundtrip_test.dart` a group `'v181 peer round-trip across the series boundary (plan 2d)'` with the same `setUp` / `buildService` / `pullPeerDive`-style helpers as the v137 group (copy them; the payload helper takes a `SyncData` plus a raw legacy map because `SyncData.toJson` no longer carries the legacy keys):

```dart
    test('the floor is 182', () {
      expect(AppDatabase.minimumCompatibleSchemaVersion, 182);
    });

    test('an old peer that still sends dive_profiles rows produces a series here', () async {
      // seedModernDive('dive-old') as the v137 group does, then delete its
      // series locally so the dive looks like one the peer created:
      await ProfileSeriesRepository().deleteForDive('dive-old');
      await SyncRepository().resetSyncState();
      final legacyRows = [
        {'id': 'r1', 'diveId': 'dive-old', 'timestamp': 0, 'depth': 0.0, 'isPrimary': true},
        {'id': 'r2', 'diveId': 'dive-old', 'timestamp': 30, 'depth': 9.0, 'isPrimary': true},
      ];
      await pullPeerPayloadWithLegacy(diveRow, legacyRows);
      final series = await ProfileSeriesRepository().getSeriesForDive('dive-old');
      expect(series.single.samples.map((s) => s.depth), [0.0, 9.0]);
    });

    test('a series row pushed by a modern peer applies with LWW by hlc', () async {
      // seedModernDive('dive-new'); fetchRecord('diveProfileSeries', id) of its
      // series; bump hlc and updatedAt by 60000 like the v137 group does for
      // dives; replace samples with a re-encoded two-sample blob built through
      // ProfileSeriesCodec().encode (base64 via _syncBlobSerializer semantics:
      // base64Encode(bytes)); pull; assert getDiveProfile shows the peer's samples.
    });
```

Write the bodies in full; `pullPeerPayloadWithLegacy` builds the payload JSON as `{...data.toJson(), 'diveProfiles': legacyRows}` and signs it the way the v137 helper does (`sha256` over the encoded `data` map that INCLUDES the legacy key; check `SyncPayload` / `seedPeerBaseFromPayload` in `test/helpers/changeset_test_helpers.dart` for how the checksum is computed and mirror it).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/cross_version_roundtrip_test.dart`
Expected: 'the floor is 182' fails (170).

- [ ] **Step 3: Raise the floor**

In `database.dart`, above `static const int minimumCompatibleSchemaVersion = 170;` add the paragraph in the existing format and change the value:

```dart
  /// Raised 170 -> 182 by the packed profile series: v182 replaces the synced
  /// entities diveProfiles and tankPressureProfiles with diveProfileSeries and
  /// tankPressureSeries, which the first rule above classifies as breaking.
  /// Peers below 182 are held until they update. Their payloads still arrive
  /// here; SyncData keeps the two legacy keys inbound-only and
  /// SyncDataSerializer.packLegacySamples packs them into series on apply.
  static const int minimumCompatibleSchemaVersion = 182;
```

Update the floor-pinning test found in Step 0 to 182.

- [ ] **Step 4: Run the tests**

Run `cross_version_roundtrip_test.dart`, the floor-pinning test, `test/core/services/sync/sync_service_test.dart` (if it exists), and `grep -rl "held\|schema_version\|minimumCompatible" test/core/services/sync | head` files.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart test/core/services/sync/cross_version_roundtrip_test.dart <floor-pinning test by path>
git commit -m "feat(sync): raise the schema floor to 182 for the series entities"
```

---

### Task 4: Deco signals over series flags, watchers, summary equivalence

**Files:**
- Modify: `lib/features/statistics/data/dive_filter_sql.dart` (`decoSignalCondition`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`had_deco` near line 4802 and its `readsFrom`; the `readsFrom` sets of every query that calls `decoSignalCondition`, near lines 2395 and 2508; the two watchers' doc comments already name the series tables)
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (`scanRecordedDecoSignals` near line 2419; `watchStatisticsChanges` near line 119)
- Test: `test/features/dive_log/domain/codecs/summary_flags_sql_equivalence_test.dart` (new; spec section 10's summary-scalar equivalence)
- Verify (red on entry, must pass): `test/features/dive_log/data/repositories/dive_repository_deco_filter_test.dart` (3), `test/features/dive_log/presentation/providers/deco_filter_providers_test.dart` (3); plus `grep -rl "scanRecordedDecoSignals\|decoSignalCondition\|had_deco\|hadDeco" test` files.

**Interfaces:**
- Consumes: the series flag columns `has_deco_type`, `has_deco_stop`, `has_positive_ceiling` (booleans stored as 0/1).
- Produces: `decoSignalCondition({required bool wantDeco, required String diveIdRef})` with the same signature and truth table, over series.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/domain/codecs/summary_flags_sql_equivalence_test.dart`: for a dive seeded through `ProfileSeriesRepository().insertSeries` with samples covering each case (no deco fields at all; `decoType: 1` only; `decoType: 2`; `ceiling: 3.0` with no deco type; `ceiling: 0.0`), assert that the row's `has_deco_type`, `has_deco_stop`, `has_positive_ceiling` equal what the legacy SQL would compute over the decoded samples, i.e. `samples.any((s) => s.decoType != null)`, `samples.any((s) => s.decoType == 2)`, `samples.any((s) => (s.ceiling ?? 0) > 0)`, and that `max_depth`, `first_depth`, `last_depth`, `start_timestamp`, `end_timestamp`, `sample_count` equal the obvious folds over the decoded samples. One test per case, reading the raw row with `getRowsForDives`.

Then run the two red files to see the failing assertions (they build dives with `createDive` carrying `decoType` / `ceiling` points and expect the deco classification).

- [ ] **Step 2: Run the tests to verify they fail**

Run the new file (may pass already if the codec summary is correct; that is fine, it is the pin) and the two red files (fail on classification sets).

- [ ] **Step 3: Move the SQL**

`dive_filter_sql.dart`:

```dart
  final hasDecoStop =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_deco_stop = 1) '
      "OR EXISTS (SELECT 1 FROM dive_profile_events e "
      "WHERE e.dive_id = $diveIdRef AND e.event_type = 'decoStopStart')";
  final hasDecoType =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_deco_type = 1)';
  final hasPositiveCeiling =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_positive_ceiling = 1)';
```

(the combination logic below is unchanged; update the doc comment's "profile" wording to name the series flags).

`dive_repository_impl.dart` `had_deco`:

```dart
            'EXISTS(SELECT 1 FROM dive_profile_series s WHERE s.dive_id = d.id '
            'AND (s.has_deco_stop = 1 OR s.has_positive_ceiling = 1)) AS had_deco '
```

and `readsFrom: {_db.dives, _db.diveProfileSeries}` there and on every query whose WHERE embeds `decoSignalCondition` (they also read `_db.diveProfileEvents`; keep that).

`statistics_repository.dart` `scanRecordedDecoSignals`:

```dart
        signals AS (
          SELECT
            s.dive_id AS dive_id,
            MAX(CASE WHEN ps.id IS NOT NULL THEN 1 ELSE 0 END) AS has_profile,
            MAX(CASE WHEN ps.has_deco_type = 1 THEN 1 ELSE 0 END)
              AS has_deco_type,
            MAX(CASE WHEN ps.has_deco_stop = 1 THEN 1 ELSE 0 END) AS deco_stop,
            MAX(CASE WHEN ps.has_positive_ceiling = 1 THEN 1 ELSE 0 END)
              AS positive_ceiling
          FROM scoped s
          LEFT JOIN dive_profile_series ps ON ps.dive_id = s.dive_id
          GROUP BY s.dive_id
        ),
```

(the rest of the query unchanged). `watchStatisticsChanges`: add `TableUpdateQuery.onTable(_db.diveProfileSeries)` and `TableUpdateQuery.onTable(_db.tankPressureSeries)` after the two legacy entries (legacy entries stay until 2e).

- [ ] **Step 4: Run the tests**

Run the new file, the two formerly-red files, and every file from `grep -rl "scanRecordedDecoSignals\|decoSignalCondition\|had_deco\|hadDeco\|watchStatisticsChanges" test`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/statistics/data/dive_filter_sql.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/statistics/data/repositories/statistics_repository.dart test/features/dive_log/domain/codecs/summary_flags_sql_equivalence_test.dart
git commit -m "feat(series): deco signals read the series summary flags; statistics watch the series tables"
```

---

### Task 5: Profile span, quality context and prefilters over series

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_effectiveRuntimeSql` near line 3388; `_diveTimesSelect` near line 4920; the `readsFrom` sets of every query using them, near lines 3432, 3456, 4955, 4981, 5010)
- Modify: `lib/features/data_quality/data/services/quality_context_builder.dart` (`_build` sample and pressure loads; `_neighbors` first/last depth)
- Modify: `lib/features/data_quality/data/services/quality_prefilters.dart` (`withProfiles`, `withPressures`)
- Test: `test/features/dive_log/data/repositories/profile_span_series_test.dart` (new)
- Verify (red on entry, must pass): `test/features/data_quality/data/quality_context_builder_test.dart` (2), `quality_prefilters_test.dart` (1), `test/features/dive_log/data/repositories/dashboard_queries_test.dart` (1), `dive_times_accessors_test.dart` (2).

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getSeriesForDive(diveId, {primaryOnly})`, `TankPressureSeriesRepository.getSeriesForDive(diveId)`, `mergeSeriesPoints`, `mergeTankSeriesPoints` (plan 2b, `lib/features/dive_log/domain/services/profile_series_merge.dart`), series columns `start_timestamp`, `end_timestamp`, `first_depth`, `last_depth`, `is_primary`.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/repositories/profile_span_series_test.dart`: seed a dive with no `runtime`, no `exit_time`, `bottom_time` 40 minutes, and two series (a primary one t=0..600 and a demoted one t=0..900, both through `ProfileSeriesRepository().insertSeries`); assert `DiveRepository().getDiveTimes(diveId)` reports `effectiveRuntime` of 900 seconds (the span over ALL series, as the legacy span was over all rows), and that a dive with a single-sample series (zero span) falls through to `bottom_time` (2400 seconds). Use the accessor the red `dive_times_accessors_test.dart` uses (`getDiveTimes` and its `DiveTimes.effectiveRuntime`).

- [ ] **Step 2: Run the tests to verify they fail**

Run the new file and the four red files.
Expected: spans null / samples empty.

- [ ] **Step 3: Move the SQL and the loads**

`dive_repository_impl.dart`:

```dart
      'NULLIF((SELECT MAX(s.end_timestamp) - MIN(s.start_timestamp) '
      'FROM dive_profile_series s WHERE s.dive_id = d.id), 0), '
```

in `_effectiveRuntimeSql` (replacing the `dive_profiles` subquery, keeping the surrounding COALESCE), and

```dart
      '(SELECT MAX(s.end_timestamp) - MIN(s.start_timestamp) '
      'FROM dive_profile_series s WHERE s.dive_id = d.id) AS profile_span '
```

in `_diveTimesSelect`. Every `readsFrom: {_db.dives, _db.diveProfiles}` on a query that embeds either constant becomes `readsFrom: {_db.dives, _db.diveProfileSeries}`; grep `_effectiveRuntimeSql\|_diveTimesSelect` to find them all (lines near 3432, 3456, 4955, 4981, 5010).

`quality_context_builder.dart` `_build`: replace the `dive_profiles` select with

```dart
    final primarySeries = await _profileSeries.getSeriesForDive(
      dive.id,
      primaryOnly: true,
    );
    final samples = <QualitySample>[
      for (final p in mergeSeriesPoints(primarySeries))
        if (p.depth.isFinite && (p.temperature == null || p.temperature!.isFinite))
          QualitySample(t: p.timestamp, depth: p.depth, temp: p.temperature),
    ];
```

and the `tank_pressure_profiles` select with

```dart
    final pressures = <String, List<QualityPressureSample>>{};
    final tankSeries = await _tankSeries.getSeriesForDive(dive.id);
    final byTank = <String, List<series.TankPressureSeries>>{};
    for (final s in tankSeries) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    for (final entry in byTank.entries) {
      for (final p in mergeTankSeriesPoints(entry.value)) {
        if (!p.pressure.isFinite) continue;
        pressures
            .putIfAbsent(entry.key, () => [])
            .add(QualityPressureSample(t: p.timestamp, bar: p.pressure));
      }
    }
```

with fields `final _profileSeries = ProfileSeriesRepository(); final _tankSeries = TankPressureSeriesRepository();` and imports of the two repositories, `profile_series_merge.dart`, and the entity file `as series`. `_neighbors`: replace the two scalar subqueries with

```dart
          '(SELECT s.first_depth FROM dive_profile_series s '
          'WHERE s.dive_id = dives.id AND s.is_primary = 1 '
          'ORDER BY s.start_timestamp ASC, s.id ASC LIMIT 1) AS first_depth, '
          '(SELECT s.last_depth FROM dive_profile_series s '
          'WHERE s.dive_id = dives.id AND s.is_primary = 1 '
          'ORDER BY s.end_timestamp DESC, s.id DESC LIMIT 1) AS last_depth '
```

and `readsFrom: {_db.dives, _db.diveProfileSeries}`.

`quality_prefilters.dart`:

```dart
    final withProfiles = await ids(
      'SELECT d.id AS id FROM dives d WHERE EXISTS '
      '(SELECT 1 FROM dive_profile_series s WHERE s.dive_id = d.id '
      'AND s.is_primary = 1)',
    );
    final withPressures = await ids(
      'SELECT d.id AS id FROM dives d WHERE EXISTS '
      '(SELECT 1 FROM tank_pressure_series t WHERE t.dive_id = d.id)',
    );
```

- [ ] **Step 4: Run the tests**

Run the new file, the four formerly-red files, `test/features/data_quality/` (`find test/features/data_quality -name '*_test.dart'`, each), `dashboard_queries_test.dart`, `dive_times_accessors_test.dart`, `dive_repository_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/data_quality/data/services/quality_context_builder.dart lib/features/data_quality/data/services/quality_prefilters.dart test/features/dive_log/data/repositories/profile_span_series_test.dart
git commit -m "feat(series): profile span, quality context and prefilters read the series tables"
```

---

### Task 6: Sustained rates and time-at-depth in Dart over decoded series

**Files:**
- Create: `lib/features/statistics/data/series_profile_aggregates.dart`
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (`getAscentDescentRates` near line 2200; `getTimeAtDepthRanges` near line 2297)
- Test: `test/features/statistics/data/series_profile_aggregates_test.dart` (new)
- Verify: `grep -rl "getAscentDescentRates\|getTimeAtDepthRanges" test` files (the statistics repository tests seed dives through `createDive`, which writes series since plan 2c).

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getRowsForDives(List<String>)` (raw rows: `diveId`, `computerId`, `isPrimary`, `samples`, `codecVersion`), `ProfileSeriesCodec().decode(Uint8List)`, the constants `_rateWindowSeconds` (15, from `AscentRateCalculator.defaultSmoothingWindowSeconds`), `_sustainedTransitThreshold` (3.0), `_maxSampleGapFactor` (4) which move to the new file as public constants.
- Produces:
  - `class SeriesBlob { final String diveId; final String? computerId; final Uint8List samples; }` (a plain record for the isolate boundary)
  - `({double? avgAscent, double? avgDescent}) ascentDescentRatesFromBlobs(List<SeriesBlob> blobs)` and `List<({int lowerDepth, int? upperDepth, int minutes})> timeAtDepthRangesFromBlobs(List<SeriesBlob> blobs)` (top-level, isolate-safe, decode then aggregate)
  - `({double? avgAscent, double? avgDescent}) ascentDescentRates(Map<(String, String?), List<ProfileSample>> samplesByStream)` and `List<({int lowerDepth, int? upperDepth, int minutes})> timeAtDepthRanges(Map<(String, String?), List<ProfileSample>> samplesByStream)` (pure, over decoded samples grouped by `(diveId, computerId)`, each list already in `(timestamp, stored order)`)
  - `const int rateWindowSeconds = 15; const double sustainedTransitThreshold = 3.0; const int maxSampleGapFactor = 4;`

- [ ] **Step 1: Write the failing test**

`test/features/statistics/data/series_profile_aggregates_test.dart` (pure functions, no database):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/statistics/data/series_profile_aggregates.dart';

void main() {
  List<ProfileSample> ramp({required int step, required int count, required double perStep, double start = 0}) => [
    for (var i = 0; i < count; i++) ProfileSample(timestamp: i * step, depth: start + i * perStep),
  ];

  group('ascentDescentRates', () {
    test('a steady descent then ascent averages the two transit rates', () {
      // 10 s samples: descend 1 m per 10 s for 120 s (6 m/min), hold, ascend
      // 0.5 m per 10 s (3 m/min, exactly the threshold, included)
      final samples = [
        ...ramp(step: 10, count: 13, perStep: 1.0), // t 0..120, depth 0..12
        for (var i = 1; i <= 6; i++) ProfileSample(timestamp: 120 + i * 10, depth: 12.0), // hold to 180
        for (var i = 1; i <= 24; i++) ProfileSample(timestamp: 180 + i * 10, depth: 12.0 - i * 0.5), // ascend to 0 at 420
      ];
      final r = ascentDescentRates({('d1', 'c1'): samples});
      expect(r.avgDescent, closeTo(6.0, 0.05));
      expect(r.avgAscent, closeTo(3.0, 0.05));
    });

    test('a flat profile yields nulls', () {
      final r = ascentDescentRates({('d1', null): [for (var t = 0; t <= 300; t += 10) ProfileSample(timestamp: t, depth: 20.0)]});
      expect(r.avgAscent, isNull);
      expect(r.avgDescent, isNull);
    });

    test('windows are averaged per stream, not across dives', () {
      final descent = ramp(step: 10, count: 13, perStep: 1.0);
      final r1 = ascentDescentRates({('d1', 'c1'): descent});
      final r2 = ascentDescentRates({('d1', 'c1'): descent, ('d2', 'c1'): descent});
      expect(r2.avgDescent, closeTo(r1.avgDescent!, 1e-9));
    });

    test('empty input yields nulls', () {
      final r = ascentDescentRates(const {});
      expect(r.avgAscent, isNull);
      expect(r.avgDescent, isNull);
    });
  });

  group('timeAtDepthRanges', () {
    test('buckets whole intervals by the interval start depth and caps gaps', () {
      // 60 s at 5 m, 60 s at 15 m, then a 600 s gap (capped by cadence), then 60 s at 25 m
      final samples = [
        const ProfileSample(timestamp: 0, depth: 5.0),
        const ProfileSample(timestamp: 60, depth: 15.0),
        const ProfileSample(timestamp: 120, depth: 25.0),
        const ProfileSample(timestamp: 720, depth: 25.0),
        const ProfileSample(timestamp: 780, depth: 25.0),
      ];
      // cadence cap = (780 - 0) * 4 / (5 - 1) = 780 s, so the 600 s gap is kept whole
      final r = timeAtDepthRanges({('d1', null): samples});
      expect(r, [
        (lowerDepth: 0, upperDepth: 10, minutes: 1),
        (lowerDepth: 10, upperDepth: 20, minutes: 1),
        (lowerDepth: 20, upperDepth: 30, minutes: 11),
      ]);
    });

    test('a gap longer than the cadence cap is clipped to the cap', () {
      // 10 s cadence for 5 samples then a 3600 s gap: cap = (3640 * 4) / 5 = 2912
      final samples = [
        for (var i = 0; i < 5; i++) ProfileSample(timestamp: i * 10, depth: 45.0),
        const ProfileSample(timestamp: 3640, depth: 45.0),
      ];
      final r = timeAtDepthRanges({('d1', null): samples});
      expect(r.single.lowerDepth, 40);
      expect(r.single.upperDepth, isNull);
      expect(r.single.minutes, ((40 + 2912) / 60).round());
    });

    test('a stream with a single sample contributes nothing', () {
      expect(timeAtDepthRanges({('d1', null): const [ProfileSample(timestamp: 0, depth: 10.0)]}), isEmpty);
    });

    test('buckets come back ascending by lower depth', () {
      final r = timeAtDepthRanges({('d1', null): [
        const ProfileSample(timestamp: 0, depth: 35.0),
        const ProfileSample(timestamp: 60, depth: 5.0),
        const ProfileSample(timestamp: 120, depth: 5.0),
      ]});
      expect(r.map((b) => b.lowerDepth), [0, 30]);
    });
  });

  test('the blob entry points decode and agree with the pure functions', () {
    // encode a stream with ProfileSeriesCodec().encode(samples).bytes (check the
    // encode result's accessor in profile_series_codec.dart), wrap it in a
    // SeriesBlob, and assert ascentDescentRatesFromBlobs / timeAtDepthRangesFromBlobs
    // equal the pure results over the same samples.
  });
}
```

Adjust the arithmetic of the expected values only if the legacy SQL (reproduced verbatim in Step 3) gives a different number for the same input; the SQL is the oracle.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/series_profile_aggregates_test.dart`
Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement the aggregates**

`lib/features/statistics/data/series_profile_aggregates.dart` (top-level functions; the file is imported by the statistics repository and by `compute` callbacks, so it must not import Flutter widgets):

```dart
import 'dart:typed_data';

import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// Samples are averaged into fixed windows of this many seconds before the
/// rate between consecutive windows is taken (see StatisticsRepository's
/// sustained-rate doc comment).
const int rateWindowSeconds = AscentRateCalculator.defaultSmoothingWindowSeconds;

/// Windows slower than this (m/min) are neither ascent nor descent.
const double sustainedTransitThreshold = 3.0;

/// A gap longer than the stream's mean interval times this factor counts as
/// the capped interval, not the gap.
const int maxSampleGapFactor = 4;

typedef StreamKey = (String diveId, String? computerId);
typedef DepthBucket = ({int lowerDepth, int? upperDepth, int minutes});

/// One primary series as it crosses the isolate boundary: identity plus the
/// undecoded blob. Decoding happens on the worker.
class SeriesBlob {
  const SeriesBlob({
    required this.diveId,
    required this.computerId,
    required this.samples,
  });
  final String diveId;
  final String? computerId;
  final Uint8List samples;
}

Map<StreamKey, List<ProfileSample>> _decodeStreams(List<SeriesBlob> blobs) {
  const codec = ProfileSeriesCodec();
  final streams = <StreamKey, List<ProfileSample>>{};
  for (final b in blobs) {
    final decoded = codec.decode(b.samples).samples;
    streams.update(
      (b.diveId, b.computerId),
      (existing) => _mergedByTimestamp(existing, decoded),
      ifAbsent: () => decoded,
    );
  }
  return streams;
}

/// Stable interleave of two timestamp-ordered lists (two series of one
/// stream, the legacy `ORDER BY at, sample_id` tiebreak in stored order).
List<ProfileSample> _mergedByTimestamp(List<ProfileSample> a, List<ProfileSample> b) {
  final out = <ProfileSample>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (b[j].timestamp < a[i].timestamp) {
      out.add(b[j++]);
    } else {
      out.add(a[i++]);
    }
  }
  out.addAll(a.sublist(i));
  out.addAll(b.sublist(j));
  return out;
}

({double? avgAscent, double? avgDescent}) ascentDescentRatesFromBlobs(List<SeriesBlob> blobs) =>
    ascentDescentRates(_decodeStreams(blobs));

List<DepthBucket> timeAtDepthRangesFromBlobs(List<SeriesBlob> blobs) =>
    timeAtDepthRanges(_decodeStreams(blobs));

/// The legacy SQL, in Dart: per stream, samples fall into windows of
/// [rateWindowSeconds] by `timestamp ~/ rateWindowSeconds`; each window
/// contributes its mean depth and mean timestamp; consecutive windows (in
/// window order) give `rate = (prevDepth - depth) * 60 / (at - prevAt)` when
/// `at > prevAt`; ascents average the rates at or above the threshold,
/// descents the rates at or below its negative (negated).
({double? avgAscent, double? avgDescent}) ascentDescentRates(
  Map<StreamKey, List<ProfileSample>> samplesByStream,
) {
  final ascents = <double>[];
  final descents = <double>[];
  for (final samples in samplesByStream.values) {
    final windows = <int, ({double depthSum, double atSum, int n})>{};
    for (final s in samples) {
      final index = s.timestamp ~/ rateWindowSeconds;
      final w = windows[index];
      windows[index] = w == null
          ? (depthSum: s.depth, atSum: s.timestamp.toDouble(), n: 1)
          : (depthSum: w.depthSum + s.depth, atSum: w.atSum + s.timestamp, n: w.n + 1);
    }
    final ordered = windows.keys.toList()..sort();
    double? prevDepth;
    double? prevAt;
    for (final index in ordered) {
      final w = windows[index]!;
      final depth = w.depthSum / w.n;
      final at = w.atSum / w.n;
      if (prevAt != null && at > prevAt) {
        final rate = (prevDepth! - depth) * 60.0 / (at - prevAt);
        if (rate >= sustainedTransitThreshold) ascents.add(rate);
        if (rate <= -sustainedTransitThreshold) descents.add(-rate);
      }
      prevDepth = depth;
      prevAt = at;
    }
  }
  double? mean(List<double> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  return (avgAscent: mean(ascents), avgDescent: mean(descents));
}

/// The legacy SQL, in Dart: per stream with more than one sample, the cadence
/// cap is `(maxAt - minAt) * maxSampleGapFactor / (n - 1)`; each interval to
/// the next sample (in stored order after the timestamp sort) is bucketed by
/// its start depth (`< 10` -> 0, `< 20` -> 10, `< 30` -> 20, `< 40` -> 30,
/// else 40) and contributes `min(seconds, cap)` when `seconds > 0`. Buckets
/// come back ascending; empty buckets are absent.
List<DepthBucket> timeAtDepthRanges(
  Map<StreamKey, List<ProfileSample>> samplesByStream,
) {
  final seconds = <int, double>{};
  for (final samples in samplesByStream.values) {
    if (samples.length < 2) continue;
    final minAt = samples.first.timestamp;
    final maxAt = samples.last.timestamp;
    final cap = (maxAt - minAt) * maxSampleGapFactor / (samples.length - 1.0);
    for (var i = 0; i + 1 < samples.length; i++) {
      final gap = samples[i + 1].timestamp - samples[i].timestamp;
      if (gap <= 0) continue;
      final lo = _bucketLo(samples[i].depth);
      seconds[lo] = (seconds[lo] ?? 0) + (gap < cap ? gap.toDouble() : cap);
    }
  }
  final los = seconds.keys.toList()..sort();
  return [
    for (final lo in los)
      (
        lowerDepth: lo,
        upperDepth: lo >= 40 ? null : lo + 10,
        minutes: (seconds[lo]! / 60).round(),
      ),
  ];
}

int _bucketLo(double depth) {
  if (depth < 10) return 0;
  if (depth < 20) return 10;
  if (depth < 30) return 20;
  if (depth < 40) return 30;
  return 40;
}
```

Two parity notes for the implementer: (1) the legacy `cadence` CTE used `MIN(at)` / `MAX(at)` over the stream, which after the timestamp sort are the first and last sample; a stream whose samples are not sorted must be sorted first, so `_decodeStreams` relies on the codec's monotonic samples and the stable merge; the pure functions assume sorted input and say so in their doc comments. (2) the legacy `SUM(MIN(i.seconds * 1.0, c.max_interval))` is `min(gap, cap)` per interval, exactly as written.

`statistics_repository.dart`: replace the two `customSelect` bodies. Both start by scoping dive ids exactly the way `scanRecordedDecoSignals` does:

```dart
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];
      final scoped = await _db
          .customSelect(
            'SELECT d.id AS id FROM dives d WHERE 1=1 $diverFilter ${df.clause}',
            variables: params.map((p) => Variable(p)).toList(),
            readsFrom: {_db.dives},
          )
          .get();
      final diveIds = [for (final r in scoped) r.read<String>('id')];
      if (diveIds.isEmpty) return (avgAscent: null, avgDescent: null); // or [] for buckets
      final rows = await _profileSeries.getRowsForDives(diveIds);
      final blobs = [
        for (final r in rows)
          if (r.isPrimary)
            SeriesBlob(diveId: r.diveId, computerId: r.computerId, samples: r.samples),
      ];
      return await compute(ascentDescentRatesFromBlobs, blobs);
```

(`compute` from `package:flutter/foundation.dart`; the repository already imports Flutter foundation or add it; `_profileSeries` is a new `final _profileSeries = ProfileSeriesRepository();` field). `getTimeAtDepthRanges` mirrors it with `timeAtDepthRangesFromBlobs` and returns `[]` for an empty scope. Delete the three private constants from the repository (they moved) and update the two doc comments to say the aggregation runs in Dart on a worker isolate over decoded primary series, same windows and thresholds.

- [ ] **Step 4: Run the tests**

Run the new file and every file from `grep -rl "getAscentDescentRates\|getTimeAtDepthRanges\|ascent_descent\|time_at_depth\|timeAtDepth" test`.
Expected: all pass. If a repository test's expected number differs from the Dart result, compare against the legacy SQL over the same seeded samples (run it by hand through `db.customSelect` in a scratch test) before changing either side; the SQL is the oracle and the Dart must match it, not the other way round.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/statistics/data/series_profile_aggregates.dart lib/features/statistics/data/repositories/statistics_repository.dart test/features/statistics/data/series_profile_aggregates_test.dart
git commit -m "feat(series): sustained rates and time-at-depth aggregate decoded series on a worker isolate"
```

---

### Task 7: Series twins for the computer unlink and relink statements; getDiveIdsForComputer

**Files:**
- Modify: `lib/features/dive_log/data/repositories/profile_series_repository.dart` (`clearComputer`, `clearComputersOfDiverForForeignDives`, `relinkComputer`)
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` (`clearComputer`, `clearComputersOfDiverForForeignDives`)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (near line 373)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`deleteComputer` near line 379; the relink near line 529; `getDiveIdsForComputer` near line 1012)
- Test: `test/features/dive_log/data/repositories/series_computer_link_test.dart` (new)
- Modify tests: the legacy unlink/relink tests in `dive_computer_repository_impl_test.dart` (near lines 394, 560, 680) and `test/features/divers/data/repositories/diver_repository_test.dart` gain series assertions beside their legacy ones (legacy rows and statements stay until 2e).

**Interfaces:**
- Consumes: the repositories' `_ids`, `_markPending`, `_db`; Drift `isInQuery` / `isNotInQuery` on columns.
- Produces:
  - `Future<int> ProfileSeriesRepository.clearComputer(String computerId, {int? now})` and the tank twin: `SET computer_id = NULL, updated_at = now WHERE computer_id = ?`, mark every touched series pending, return the count.
  - `Future<int> ProfileSeriesRepository.clearComputersOfDiverForForeignDives(String diverId, {int? now})` and the tank twin: `SET computer_id = NULL WHERE computer_id IN (SELECT id FROM dive_computers WHERE diver_id = ?) AND dive_id NOT IN (SELECT id FROM dives WHERE diver_id = ?)`, marked pending.
  - `Future<int> ProfileSeriesRepository.relinkComputer(String computerId, List<String> diveIds, {int? now})` (profile only, legacy parity): `SET computer_id = ? WHERE computer_id IS NULL AND dive_id IN (...) AND (SELECT COUNT(*) FROM dive_data_sources s WHERE s.dive_id = dive_profile_series.dive_id AND s.source_format = 'dive_computer') = 1`, marked pending.
  - `DiveComputerRepository.getDiveIdsForComputer` reads `dive_profile_series`.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/repositories/series_computer_link_test.dart` (fixture: dives `d-mine` (diver `diver-a`) and `d-theirs` (diver `diver-b`), computers `comp-a` (diver `diver-a`) and `comp-x`, data sources as each case needs; seed through the Drift companions used in `dive_computer_repository_impl_test.dart`):

```dart
  test('clearComputer nulls the computer on every series of that computer and restamps hlc', () async {
    final id = await profileSeries.insertSeries(diveId: 'd-mine', computerId: 'comp-a', samples: one, now: 1000);
    final keep = await profileSeries.insertSeries(diveId: 'd-mine', computerId: 'comp-x', samples: one, now: 1000);
    final before = (await profileSeries.getRowsForDives(['d-mine'])).firstWhere((r) => r.id == id).hlc;
    expect(await profileSeries.clearComputer('comp-a', now: 2000), 1);
    final rows = await profileSeries.getRowsForDives(['d-mine']);
    expect(rows.firstWhere((r) => r.id == id).computerId, isNull);
    expect(rows.firstWhere((r) => r.id == id).hlc, isNot(before));
    expect(rows.firstWhere((r) => r.id == keep).computerId, 'comp-x');
  });

  test('clearComputersOfDiverForForeignDives touches only dives the diver does not own', () async {
    final mine = await profileSeries.insertSeries(diveId: 'd-mine', computerId: 'comp-a', samples: one, now: 1000);
    final theirs = await profileSeries.insertSeries(diveId: 'd-theirs', computerId: 'comp-a', samples: one, now: 1000);
    expect(await profileSeries.clearComputersOfDiverForForeignDives('diver-a', now: 2000), 1);
    final rows = await profileSeries.getRowsForDives(['d-mine', 'd-theirs']);
    expect(rows.firstWhere((r) => r.id == mine).computerId, 'comp-a');
    expect(rows.firstWhere((r) => r.id == theirs).computerId, isNull);
  });

  test('relinkComputer stamps null-computer series of dives with exactly one computer source', () async {
    // d-mine has ONE dive_data_sources row with source_format 'dive_computer';
    // d-theirs has TWO. Both carry a null-computer series.
    final a = await profileSeries.insertSeries(diveId: 'd-mine', samples: one, now: 1000);
    final b = await profileSeries.insertSeries(diveId: 'd-theirs', samples: one, now: 1000);
    expect(await profileSeries.relinkComputer('comp-a', ['d-mine', 'd-theirs'], now: 2000), 1);
    final rows = await profileSeries.getRowsForDives(['d-mine', 'd-theirs']);
    expect(rows.firstWhere((r) => r.id == a).computerId, 'comp-a');
    expect(rows.firstWhere((r) => r.id == b).computerId, isNull);
  });

  test('deleteComputer clears the series before the FK cascade would', () async {
    // seed a computer-owned profile series and tank series on d-mine, call
    // DiveComputerRepository().deleteComputer('comp-a') (check the method's
    // name and signature), assert both series survive with computerId null
    // AND an hlc different from before (the FK SET NULL alone would not restamp).
  });

  test('getDiveIdsForComputer lists dives by their series', () async {
    await profileSeries.insertSeries(diveId: 'd-mine', computerId: 'comp-a', samples: one, now: 1000);
    expect(await DiveComputerRepository().getDiveIdsForComputer('comp-a'), ['d-mine']);
    expect(await DiveComputerRepository().getDiveIdsForComputer('comp-x'), isEmpty);
  });
```

plus the tank twins of the first two tests. Write every body in full.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/series_computer_link_test.dart`
Expected: compile errors on the new methods; `getDiveIdsForComputer` returns empty.

- [ ] **Step 3: Implement**

`profile_series_repository.dart`:

```dart
  /// Nulls `computer_id` on every series of [computerId] and restamps each
  /// (the FK's ON DELETE SET NULL would change the rows without an hlc bump,
  /// so peers would never learn). Returns the number of series touched.
  Future<int> clearComputer(String computerId, {int? now}) =>
      _setComputer(null, (t) => t.computerId.equals(computerId), now: now);

  /// Diver reassignment: a computer that now belongs to [diverId] must not
  /// stay attributed on dives the diver does not own.
  Future<int> clearComputersOfDiverForForeignDives(String diverId, {int? now}) =>
      _setComputer(
        null,
        (t) =>
            t.computerId.isInQuery(
              _db.selectOnly(_db.diveComputers)
                ..addColumns([_db.diveComputers.id])
                ..where(_db.diveComputers.diverId.equals(diverId)),
            ) &
            t.diveId.isNotInQuery(
              _db.selectOnly(_db.dives)
                ..addColumns([_db.dives.id])
                ..where(_db.dives.diverId.equals(diverId)),
            ),
        now: now,
      );

  /// A recreated computer takes back the null-computer series of [diveIds]
  /// whose only computer source is the one being relinked (the legacy
  /// `dive_profiles` relink, series twin).
  Future<int> relinkComputer(String computerId, List<String> diveIds, {int? now}) {
    if (diveIds.isEmpty) return Future.value(0);
    return _setComputer(
      computerId,
      (t) =>
          t.computerId.isNull() &
          t.diveId.isIn(diveIds) &
          t.diveId.isInQuery(
            _db.selectOnly(_db.diveDataSources)
              ..addColumns([_db.diveDataSources.diveId])
              ..where(_db.diveDataSources.sourceFormat.equals('dive_computer'))
              ..groupBy(
                [_db.diveDataSources.diveId],
                having: _db.diveDataSources.id.count().equals(1),
              ),
          ),
      now: now,
    );
  }

  Future<int> _setComputer(
    String? computerId,
    Expression<bool> Function($DiveProfileSeriesTable t) where, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(where);
    if (ids.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(_db.diveProfileSeries)..where((t) => t.id.isIn(ids)))
          .write(
            DiveProfileSeriesCompanion(
              computerId: Value(computerId),
              updatedAt: Value(nowMs),
            ),
          );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
    return ids.length;
  }
```

(check the `dive_data_sources.source_format` column's Drift name, `sourceFormat`, and Drift's `groupBy(..., having:)` on `selectOnly`; if `isInQuery` with a grouped subquery does not compile, express the relink as `customStatement` with the legacy SQL text against `dive_profile_series` plus a preceding `customSelect` of the matching ids to mark pending). `tank_pressure_series_repository.dart`: `clearComputer` and `clearComputersOfDiverForForeignDives` with the same shape over `_db.tankPressureSeries` (no relink).

`diver_repository.dart` near line 373: after the legacy `UPDATE dive_profiles SET computer_id = NULL ...` statement add `await ProfileSeriesRepository().clearComputersOfDiverForForeignDives(id); await TankPressureSeriesRepository().clearComputersOfDiverForForeignDives(id);` (fields if the class keeps repositories as fields; otherwise construct inline; `id` is the diver id the legacy statement binds).

`dive_computer_repository_impl.dart`: in `deleteComputer` BEFORE the legacy `UPDATE dive_profiles SET computer_id = NULL WHERE computer_id = ?` add `await _profileSeries.clearComputer(id); await _tankSeries.clearComputer(id);`; in the relink block after the legacy `UPDATE dive_profiles SET computer_id = ? ...` add `await _profileSeries.relinkComputer(computerId, matchedDiveIds);`. `getDiveIdsForComputer`: `INNER JOIN dive_profile_series dp ON d.id = dp.dive_id WHERE dp.computer_id = ?` (the rest unchanged).

- [ ] **Step 4: Run the tests**

Run the new file, `dive_computer_repository_impl_test.dart`, `diver_repository_test.dart` (add one series assertion beside each legacy unlink/relink assertion: seed a series with the same computer next to the legacy row and assert its `computerId` after the call), `dive_computer_series_reads_test.dart`, `profile_series_repository_writers_test.dart`, `tank_pressure_series_repository_writers_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/profile_series_repository.dart lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart lib/features/divers/data/repositories/diver_repository.dart lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/series_computer_link_test.dart test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart test/features/divers/data/repositories/diver_repository_test.dart
git commit -m "feat(series): computer unlink and relink stamp the series; getDiveIdsForComputer reads series"
```

---

### Task 8: Verification

**Files:** none new.

- [ ] **Step 1: No legacy reads outside the allowed set**

```bash
grep -rn "dive_profiles\|tank_pressure_profiles\|_db.diveProfiles\|_db.tankPressureProfiles\|db.diveProfiles\|db.tankPressureProfiles" lib --include='*.dart' | grep -v "database.dart\|database.g.dart\|profile_series_pack\|performance_indexes.dart" | grep -v "^\s*//\|///" | grep -v "Legacy\|delete(\|DELETE FROM\|deleteWhere\|UPDATE dive_profiles SET computer_id\|profileRows\|tankPressureRows\|case 'diveProfiles'\|case 'tankPressureProfiles'\|_db.diveProfiles,$\|_db.tankPressureProfiles,$\|onTable(_db.diveProfiles)\|onTable(_db.tankPressureProfiles)"
```

Expected: nothing, or only lines inside the 2b `_...Legacy` method bodies (open each hit and confirm it sits inside a method whose name ends in `Legacy`, inside `undo`'s verbatim re-inserts, inside `DiveMergeSnapshot.capture`, or inside the serializer's inbound legacy cases). Anything else is a missed consumer: fix it in this task and say so in the report.

- [ ] **Step 2: The thirteen formerly-red tests**

Run each: `quality_context_builder_test.dart`, `quality_prefilters_test.dart`, `dashboard_queries_test.dart`, `dive_repository_deco_filter_test.dart`, `dive_times_accessors_test.dart`, `deco_filter_providers_test.dart`, `consolidation_sync_roundtrip_test.dart`.
Expected: every file passes.

- [ ] **Step 3: Every test file this plan created or touched, individually, plus the sync suite**

The seven new files, every modified test file named in Tasks 1 to 7, every file under `test/core/services/sync/`, `test/features/statistics/` and `test/features/data_quality/`.
Expected: every file passes.

- [ ] **Step 4: Format, analyze, layering**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test test/core/database/database_import_graph_test.dart
```

Expected: exit 0, "No issues found!", pass.

- [ ] **Step 5: Full suite once**

Background, output to the session scratchpad `full-suite-2d.log` with `exit=$?` appended. Known machine flakes: `local_file_resolver_test.dart` (passes with `TMPDIR=/private/tmp/claude-501/sysvol-tmp`), `changeset_writer_test.dart`, `backup_encryption_service_test.dart`, `database_security_service_test.dart`. Any other failure: rerun the file alone once; a repeat is real. There is NO known-red list after this plan.

- [ ] **Step 6: Report**

The commit list from `git log --oneline 30234a3973e..HEAD`, the grep results, the per-file results, the full-suite summary and exit, flake reruns.

---

## Self-review

**Spec coverage.** Section 7 (sync): registration with `blob: true`, export by `hlc > since` (Task 1's `_exportDiveProfileSeries` mirrors `_exportGpsTracks`), `updated_at` / hlc-bearing (`hasUpdatedAt: true`, `entityHasUpdatedAt`), apply by `insertOnConflictUpdate` on the series id with LWW through `_mergeEntity`, `parentRefs` incl. `dive_tanks` for tank series (Task 1); the legacy entities leave `_baseTables`, `SyncData.toJson`, `entityHasUpdatedAt` and the export path but keep inbound apply, delete, `recordIdsFor`, `tableFor` (Task 2; the spec's "leave the switches" is deferred to 2e so older peers' payloads and tombstones still apply, which the spec's own next paragraph requires); one tombstone per series (the repositories, plan 2a); floor to 182 and the round-trip projection (Task 3); receive-side packing with the migration packer (Task 2). Section 9: rows 1 to 6 (Task 4: deco classification, `decoSignalCondition`, `had_deco`; Task 5: profile span, quality first/last depth, prefilters), row 7 (source ownership) was finished in plan 2c (`ownsAny`, `promoteWinnerOwnedBy`), rows 8 and 9 (Task 6, Dart on a worker isolate). Section 6 "Decoding one series is on the order of a millisecond ... Whole-library aggregations decode on a worker isolate via `compute`" (Task 6). The three `UPDATE dive_profiles SET computer_id` statements the 2c review found (Task 7). The apply-time validation carried from PR 1's review ("bounded inflate for peer blobs") is the soundness check in Task 1.

Not in this plan by design: dropping the tables, the `_...Legacy` fallbacks, the legacy deletes and undo re-inserts, the snapshot's legacy lists, `TankPressurePoint.id`, `performance_indexes.dart`'s legacy index heal, the legacy sync switch cases and `parentRefs` entries, VACUUM, the benchmark fixture and gates (all plan 2e).

**Placeholder scan.** Every task carries the code it changes and the tests with their assertions. Task 1's round-trip tests, Task 2's inbound tests and Task 3's boundary tests reuse the fixtures of `consolidation_sync_roundtrip_test.dart` and `cross_version_roundtrip_test.dart` by name (copy, not import) and spell out each assertion. Task 6's expected numbers are stated with their arithmetic and the legacy SQL is named as the oracle. Task 7's `relinkComputer` names a `customStatement` fallback if Drift's grouped `isInQuery` does not compile. No "add error handling", no "similar to Task N".

**Type consistency.** `SyncData.diveProfileSeries` / `tankPressureSeries` (Task 1) are read by Task 2's export test and Task 3's payload builder; `packLegacySamples()` returns `ProfilePackReport` (the packer's typedef, fields `profileSeries`, `tankSeries`, `droppedSamples`, `skippedOrphans`, `skippedRows`) and Task 2's log reads `profileSeries` / `tankSeries`; `decoSignalCondition({required bool wantDeco, required String diveIdRef})` keeps its signature (Task 4) so its two callers in `dive_repository_impl.dart` compile unchanged; `SeriesBlob(diveId, computerId, samples)`, `ascentDescentRatesFromBlobs`, `timeAtDepthRangesFromBlobs`, `ascentDescentRates`, `timeAtDepthRanges`, `StreamKey`, `DepthBucket` (Task 6) match the repository call sites and the test; `clearComputer(String computerId, {int? now})`, `clearComputersOfDiverForForeignDives(String diverId, {int? now})`, `relinkComputer(String computerId, List<String> diveIds, {int? now})` (Task 7) match their three call sites and the test; `getRowsForDives` (plan 2c Task 1) returns rows with `diveId`, `computerId`, `isPrimary`, `samples` as Task 6 reads them.
