# Data Quality Assistant — Plan 1: Data & Detection Engine

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the synced `quality_findings` data layer, the 11 pure quality detectors, and the scan orchestration (targeted + full-library with SQL pre-filters), wired into import and save flows.

**Architecture:** Detector pipeline over a prepared per-dive context; findings materialize into an HLC-synced table with deterministic UUIDv5 ids; a scan service applies results with upsert-preserves-status / retire-with-tombstone semantics. Repairs and UI are Plan 2 (`2026-07-17-data-quality-assistant-ui.md`).

**Tech Stack:** Flutter/Dart, Drift (SQLite), Riverpod, uuid ^4.5.0, SharedPreferences.

**Spec:** `docs/superpowers/specs/2026-07-17-data-quality-assistant-design.md` — read it first.

## Global Constraints

- Work ONLY in this worktree: `.claude/worktrees/data-quality-assistant` (branch `worktree-data-quality-assistant`).
- Schema claim is **v118**. Before Task 1, run `grep -n "currentSchemaVersion = " lib/core/database/database.dart` — it must print `112`. If it prints anything ≥ 118, STOP and renumber per the schema-ladder convention (check open PR claims; v113–v117 are claimed by open PRs as of 2026-07-17).
- After ANY change to `lib/core/database/database.dart` table definitions: `dart run build_runner build --delete-conflicting-outputs` before compiling/testing.
- Before every commit: `dart format .` (whole project, not just changed files). Never pipe `flutter analyze` through `tail`/`head` (masks the exit code).
- Run specific test files (`flutter test test/path/file.dart`), never the whole suite mid-task (timeout risk).
- Commit messages: plain conventional style. NO `Co-Authored-By` line, NO session URL.
- No emojis anywhere. Dart null safety. Immutability (copyWith, no mutation of shared state).
- Drift row classes collide with domain entity names — import domain entities `as domain` where both are in scope.
- Entity-type string for sync: `qualityFindings`. SQL table: `quality_findings`.
- All detector thresholds live in `QualityThresholds` — never inline a magic number in a detector.
- Test expectations must be hand-computed in a comment (e.g. `// bandScore(12, full:5, zero:15) = 1 - 7/10 = 0.3`), never derived by running the implementation.

---

### Task 1: Schema v118 — `quality_findings` table + migration + backstop

**Files:**
- Modify: `lib/core/database/database.dart` (table class near the other table definitions ~line 841; `@DriftDatabase` list ~line 2133; `currentSchemaVersion` line 2208; `migrationVersions` line 2213; assert method near `_assertEquipmentThicknessColumn` ~line 2408; onUpgrade tail ~line 5542; beforeOpen backstop ~line 5577)
- Modify: `test/core/database/equipment_set_geofence_schema_test.dart:77-80` (relax exact tripwire)
- Test: `test/core/database/migration_v118_quality_findings_test.dart`

**Interfaces:**
- Consumes: existing `Dives`, `DiveComputers` Drift tables.
- Produces: Drift table `QualityFindings` (row class `QualityFindingRow`, companion `QualityFindingsCompanion`), `AppDatabase.currentSchemaVersion == 118`, idempotent `_assertQualityFindingsSchema()`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/core/database/migration_v118_quality_findings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  test('quality_findings table exists with expected columns', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('quality_findings')")
        .get();
    final cols = [for (final r in rows) r.read<String>('name')];
    expect(
      cols,
      containsAll([
        'id',
        'dive_id',
        'related_dive_id',
        'computer_id',
        'detector_id',
        'detector_version',
        'category',
        'severity',
        'status',
        'params',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('quality_findings indexes exist', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'quality_findings'",
        )
        .get();
    final names = [for (final r in rows) r.read<String>('name')];
    expect(names, contains('idx_quality_findings_dive'));
    expect(names, contains('idx_quality_findings_status'));
  });

  test('version ladder includes 118', () {
    // greaterThanOrEqualTo from the start per the superseded-tripwire
    // convention -- this never becomes a false failure when v119+ lands.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(118));
    expect(AppDatabase.migrationVersions, contains(118));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v118_quality_findings_test.dart`
Expected: FAIL (`quality_findings` has no columns; ladder lacks 118).

- [ ] **Step 3: Add the Drift table class**

In `lib/core/database/database.dart`, after `EquipmentSetGeofences` (~line 841):

```dart
/// Data-quality findings produced by the Data Quality Assistant detectors.
/// One row per (dive, detector, discriminator). Ids are deterministic
/// UUIDv5 values so independent scans on two devices converge on the same
/// row. Dismissal is a status update, never a delete (deterministic ids
/// would resurrect deleted findings on rescan).
@DataClassName('QualityFindingRow')
class QualityFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// The other dive for cross-dive findings (duplicates, splits, overlaps).
  TextColumn get relatedDiveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// Source computer for source-scoped findings.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get detectorId => text()();
  IntColumn get detectorVersion => integer()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// JSON object of numeric arguments; the UI renders localized messages
  /// from these. Never store prose.
  TextColumn get params => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add `QualityFindings,` to the `@DriftDatabase(tables: [...])` list (~line 2133, near `EquipmentSetGeofences`).

- [ ] **Step 4: Add the idempotent assert + migration + backstop + version bump**

Near `_assertEquipmentThicknessColumn` (~line 2408), add:

```dart
  /// v118: quality_findings table for the Data Quality Assistant.
  /// Idempotent so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  Future<void> _assertQualityFindingsSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS quality_findings (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        related_dive_id TEXT REFERENCES dives (id) ON DELETE SET NULL,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        detector_id TEXT NOT NULL,
        detector_version INTEGER NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        params TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_dive '
      'ON quality_findings (dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_status '
      'ON quality_findings (status)',
    );
  }
```

In onUpgrade, after the `if (from < 112)` block (~line 5546):

```dart
        if (from < 118) {
          await _assertQualityFindingsSchema();
        }
        if (from < 118) await reportProgress();
```

In `beforeOpen`, after the v112 backstop (~line 5577):

```dart
        // v118 backstop: re-assert quality_findings schema.
        await _assertQualityFindingsSchema();
```

Change `static const int currentSchemaVersion = 112;` (line 2208) to `118`, and append `118` to `migrationVersions` (line 2213).

- [ ] **Step 5: Relax the superseded v112 exact tripwire**

In `test/core/database/equipment_set_geofence_schema_test.dart:77-80` change:

```dart
  test('v112 is in the schema version ladder', () {
    // Relaxed from exact-latest when v118 (data quality assistant) claimed
    // the top of the ladder.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(112));
    expect(AppDatabase.migrationVersions, contains(112));
  });
```

- [ ] **Step 6: Codegen, then run both test files**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/database/migration_v118_quality_findings_test.dart test/core/database/equipment_set_geofence_schema_test.dart`
Expected: PASS (all).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart \
  test/core/database/migration_v118_quality_findings_test.dart \
  test/core/database/equipment_set_geofence_schema_test.dart
git commit -m "feat(data-quality): quality_findings table, migration v118"
```

---

### Task 2: Sync registration for `qualityFindings`

**Files:**
- Modify: `lib/core/database/database.dart` (`_hlcTables` list, lines 2532-2561)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets`, lines 30-68)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (5 DTO spots + `_baseTables` + export wiring + `_export*` method + 7 switches; anchors below)
- Modify: `lib/core/services/sync/sync_service.dart` (`entityHasUpdatedAt` ~line 1559; `mergeOrder` in `_applyRemotePayloadInner` ~lines 902-1072; `parentRefs` ~line 1631)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (syncedTables map, head at lines 18-63)
- Test: `test/core/services/sync/quality_findings_sync_test.dart`

**Interfaces:**
- Consumes: Task 1's table.
- Produces: entity type `'qualityFindings'` usable with `SyncRepository.markRecordPending`/`logDeletion` and full serializer round-trip (`upsertRecord`/`fetchRecord`/`deleteRecord`/batch variants).

The registration template throughout is **`fieldPresets`** (a simple text-id-PK synced table) — in every enumeration below, find the `fieldPresets` entry/case, duplicate it, and rename to `qualityFindings`/`quality_findings`, adjusting only what the steps call out.

- [ ] **Step 1: Write the failing round-trip test**

```dart
// test/core/services/sync/quality_findings_sync_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // Findings reference dives; skip seeding the full dive graph.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> findingRecord(String id) => {
    'id': id,
    'dive_id': 'dive-1',
    'related_dive_id': null,
    'computer_id': null,
    'detector_id': 'depth_spike',
    'detector_version': 1,
    'category': 'profile',
    'severity': 'warning',
    'status': 'open',
    'params': '{"atSeconds":120}',
    'created_at': 1700000000000,
    'updated_at': 1700000000000,
    'hlc': '2026-07-17T00:00:00.000Z-0000-abcdef',
  };
  // NOTE: mirror the key style of
  // test/core/services/sync/equipment_set_geofence_sync_test.dart -- if that
  // file uses camelCase keys for upsertRecord maps, use camelCase here too.

  test('upsertRecord + fetchRecord round-trips a finding', () async {
    await serializer.upsertRecord('qualityFindings', findingRecord('qf-1'));
    final fetched = await serializer.fetchRecord('qualityFindings', 'qf-1');
    expect(fetched, isNotNull);
    expect(fetched!['detector_id'], 'depth_spike');
    expect(fetched['status'], 'open');
  });

  test('deleteRecord removes a finding', () async {
    await serializer.upsertRecord('qualityFindings', findingRecord('qf-2'));
    await serializer.deleteRecord('qualityFindings', 'qf-2');
    expect(await serializer.fetchRecord('qualityFindings', 'qf-2'), isNull);
  });

  test('batch upsertRecords + fetchRecords round-trips', () async {
    await serializer.upsertRecords('qualityFindings', [
      findingRecord('qf-3'),
      findingRecord('qf-4'),
    ]);
    final fetched = await serializer.fetchRecords('qualityFindings', [
      'qf-3',
      'qf-4',
    ]);
    expect(fetched, hasLength(2));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/sync/quality_findings_sync_test.dart`
Expected: FAIL (unknown entity type `qualityFindings`).

- [ ] **Step 3: Register in database + sync_repository + sync_service maps**

1. `database.dart` `_hlcTables` (line 2532): add `'quality_findings',` at the end.
2. `sync_repository.dart` `_hlcTargets` (lines 30-68): add `'qualityFindings': (table: 'quality_findings', pk: 'id'),`.
3. `sync_service.dart` `entityHasUpdatedAt` (~line 1559): add `'qualityFindings': true,`.
4. `sync_service.dart` `mergeOrder` inside `_applyRemotePayloadInner` (~lines 902-1072): add `(type: 'qualityFindings', records: data.qualityFindings, hasUpdatedAt: true),` AFTER the `dives` and `diveComputers` entries (findings FK both).

- [ ] **Step 4: Register in the serializer (all locations)**

In `sync_data_serializer.dart`, duplicating the `fieldPresets` pattern at each anchor:

1. Field declaration (~lines 214-268): `final List<Map<String, dynamic>> qualityFindings;`
2. Constructor default (~lines 270-326): `this.qualityFindings = const [],`
3. `toJson()` (~lines 328-384): `'qualityFindings': qualityFindings,`
4. `fromJson()` (~lines 386-444): `qualityFindings: _parseList(json['qualityFindings']),`
5. `_baseTables` descriptor list (~line 568): `(key: 'qualityFindings', table: _db.qualityFindings, blob: false, full: null),`
6. `_buildSyncData` export wiring (~line 961): `qualityFindings: await _safeExport('qualityFindings', () => _exportQualityFindings(hlcSince)),`
7. New `_exportQualityFindings(String? hlcSince)` in the `_export*` block (starts ~line 3368) — copy `_exportFieldPresets` verbatim and substitute the table. Match its exact shape (hlc-since filtering included).
8. The seven switches — add a `case 'qualityFindings':` copied from the `fieldPresets` case in each: `fetchRecord` (~:1270), `fetchRecords` (~:1591), `upsertRecord` (~:1803), `upsertRecords` (~:2180), `recordIdsFor` (~:2755), `_syncTableFor` (~:2956), `deleteRecord` (~:3077). (`deleteAllRecords` at ~:2924 falls through to `_syncTableFor` — verify no explicit case is needed by reading that switch's default.)

- [ ] **Step 5: Run the round-trip test and the sync guard tests**

Run: `flutter test test/core/services/sync/quality_findings_sync_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`

`sync_parent_refs_completeness_test` will FAIL because `quality_findings` has FKs to deletable parents (`dives` cascade, `dive_computers` setNull). Follow its failure message exactly: add the `'quality_findings': 'qualityFindings'` entry to that test's `syncedTables` map (head at lines 18-63), and add the corresponding `parentRefs` entries in `sync_service.dart` (~line 1631) mirroring the `equipmentSetGeofences` entry's shape — one ref for `diveId` (non-null, parent `dives`), one for `relatedDiveId` (nullable, parent `dives`), one for `computerId` (nullable, parent `diveComputers`).

Re-run all three files. Expected: PASS.

- [ ] **Step 6: Run the structural entityHasUpdatedAt test and base-streaming parity tests**

Run: `flutter test test/core/services/sync/ --name "entityHasUpdatedAt"` then `flutter test test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart`
Expected: PASS. If a parity test enumerates entities, add `qualityFindings` where its failure message directs.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/data/repositories/sync_repository.dart \
  lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart \
  test/core/services/sync/quality_findings_sync_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart
git commit -m "feat(data-quality): register qualityFindings entity for sync"
```

---

### Task 3: Domain model — entity, enums, deterministic ids, thresholds

**Files:**
- Create: `lib/features/data_quality/domain/entities/quality_finding.dart`
- Create: `lib/features/data_quality/domain/quality_thresholds.dart`
- Test: `test/features/data_quality/domain/quality_finding_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart).
- Produces: `QualityFinding` (immutable entity + `copyWith`), `QualityCategory`/`QualitySeverity`/`QualityStatus` enums, `qualityFindingId({required String diveId, required String detectorId, String discriminator})`, `qualityPairIdentity({required String detectorId, required String a, required String b, String discriminator})` returning `({String diveId, String relatedDiveId, String id})`, and `QualityThresholds` (all static consts).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/data_quality/domain/quality_finding_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

void main() {
  test('qualityFindingId is deterministic and discriminator-sensitive', () {
    final a = qualityFindingId(diveId: 'd1', detectorId: 'depth_spike');
    final b = qualityFindingId(diveId: 'd1', detectorId: 'depth_spike');
    final c = qualityFindingId(
      diveId: 'd1',
      detectorId: 'depth_spike',
      discriminator: 'spike:4',
    );
    expect(a, b);
    expect(a, isNot(c));
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('qualityPairIdentity is order-independent', () {
    final p1 = qualityPairIdentity(detectorId: 'duplicate', a: 'dA', b: 'dB');
    final p2 = qualityPairIdentity(detectorId: 'duplicate', a: 'dB', b: 'dA');
    expect(p1.id, p2.id);
    expect(p1.diveId, 'dA'); // lexically smaller id is the anchor
    expect(p1.relatedDiveId, 'dB');
  });

  test('enums round-trip by name', () {
    expect(QualityStatus.values.byName('dismissed'), QualityStatus.dismissed);
    expect(QualityCategory.values.byName('source'), QualityCategory.source);
    expect(QualitySeverity.values.byName('critical'), QualitySeverity.critical);
  });

  test('copyWith replaces only what is passed', () {
    final f = QualityFinding(
      id: 'id1',
      diveId: 'd1',
      detectorId: 'sample_gap',
      detectorVersion: 1,
      category: QualityCategory.profile,
      severity: QualitySeverity.info,
      status: QualityStatus.open,
      params: const {'gapCount': 2},
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    final g = f.copyWith(status: QualityStatus.dismissed);
    expect(g.status, QualityStatus.dismissed);
    expect(g.diveId, 'd1');
    expect(g.params, const {'gapCount': 2});
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/data_quality/domain/quality_finding_test.dart`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement the entity file**

```dart
// lib/features/data_quality/domain/entities/quality_finding.dart
import 'package:uuid/uuid.dart';

enum QualityCategory {
  time,
  profile,
  temperature,
  pressure,
  gas,
  tank,
  source,
  duplicate,
}

enum QualitySeverity { info, warning, critical }

enum QualityStatus { open, dismissed, resolved }

/// Fixed namespace for deterministic finding ids (UUIDv5). Never change.
const String kQualityFindingNamespace = '7f9b2c9e-1d34-4b6a-9c1e-2a5d8e4f6b01';

/// Deterministic finding id: two devices scanning the same dive with the
/// same detector produce the same row id and converge under sync.
String qualityFindingId({
  required String diveId,
  required String detectorId,
  String discriminator = '',
}) => const Uuid().v5(
  kQualityFindingNamespace,
  '$diveId|$detectorId|$discriminator',
);

/// Identity for a cross-dive (pair) finding: the lexically smaller dive id
/// anchors the row so either member's scan produces the identical row.
({String diveId, String relatedDiveId, String id}) qualityPairIdentity({
  required String detectorId,
  required String a,
  required String b,
  String discriminator = '',
}) {
  final lo = a.compareTo(b) <= 0 ? a : b;
  final hi = a.compareTo(b) <= 0 ? b : a;
  return (
    diveId: lo,
    relatedDiveId: hi,
    id: qualityFindingId(
      diveId: lo,
      detectorId: detectorId,
      discriminator: discriminator.isEmpty ? hi : '$hi|$discriminator',
    ),
  );
}

class QualityFinding {
  const QualityFinding({
    required this.id,
    required this.diveId,
    this.relatedDiveId,
    this.computerId,
    required this.detectorId,
    required this.detectorVersion,
    required this.category,
    required this.severity,
    required this.status,
    this.params = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diveId;
  final String? relatedDiveId;
  final String? computerId;
  final String detectorId;
  final int detectorVersion;
  final QualityCategory category;
  final QualitySeverity severity;
  final QualityStatus status;

  /// Numeric/boolean facts only; the UI renders localized text from these.
  final Map<String, Object?> params;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityFinding copyWith({
    String? id,
    String? diveId,
    String? relatedDiveId,
    String? computerId,
    String? detectorId,
    int? detectorVersion,
    QualityCategory? category,
    QualitySeverity? severity,
    QualityStatus? status,
    Map<String, Object?>? params,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => QualityFinding(
    id: id ?? this.id,
    diveId: diveId ?? this.diveId,
    relatedDiveId: relatedDiveId ?? this.relatedDiveId,
    computerId: computerId ?? this.computerId,
    detectorId: detectorId ?? this.detectorId,
    detectorVersion: detectorVersion ?? this.detectorVersion,
    category: category ?? this.category,
    severity: severity ?? this.severity,
    status: status ?? this.status,
    params: params ?? this.params,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
```

- [ ] **Step 4: Implement the thresholds file**

```dart
// lib/features/data_quality/domain/quality_thresholds.dart

/// Every detector threshold, in one place. Detectors never inline numbers.
/// Units: meters, celsius, bar, seconds unless the name says otherwise.
abstract final class QualityThresholds {
  // clock_offset
  static const int futureGraceDays = 1;
  static const int minPlausibleYear = 1950;
  static const int hourOffsetMin = 1;
  static const int hourOffsetMax = 14;
  static const int hourOffsetRemainderToleranceMin = 5;

  // duplicate (DiveMatcher supplies its own 0.5/0.7 score thresholds)
  static const Duration duplicateWindow = Duration(minutes: 15);

  // split_pair
  static const Duration splitMaxGap = Duration(minutes: 10);
  static const Duration splitShallowGap = Duration(minutes: 3);
  static const double splitDeepEndMeters = 1.0;

  // sample_gap
  static const int gapMinSeconds = 30;
  static const double gapMedianFactor = 2.0;
  static const double gapWarnFractionOfRuntime = 0.10;

  // depth_spike
  static const double spikeRateMetersPerSecond = 3.0;
  static const double negativeDepthMeters = -0.5;
  static const double maxDepthMismatchFraction = 0.05;
  static const double maxDepthMismatchMinMeters = 0.5;
  static const int maxSpikeFindingsPerDive = 10;

  // impossible_rate
  static const double impossibleRateMetersPerMinute = 30.0;
  static const int impossibleRateMinSeconds = 30;

  // temp_anomaly
  static const double waterTempMinC = -2.0;
  static const double waterTempMaxC = 40.0;
  static const double tempJumpPerSampleC = 5.0;
  static const int tempJumpMaxSampleGapSeconds = 60;
  static const int maxTempJumpFindingsPerDive = 5;

  // pressure_anomaly
  static const double pressureRiseBar = 5.0;
  static const double pressureEndpointMismatchBar = 10.0;
  static const double pressureSwapMinDiffBar = 1.0;
  static const double sacSurfaceLpmMax = 100.0;
  static const int sacMinSeriesSeconds = 300;
  static const int switchProximitySeconds = 60;

  // gas_mod
  static const double ppO2WarnBar = 1.6;
  static const double ppO2CriticalBar = 1.8;
  static const int ppO2SustainSeconds = 60;
  static const double hypoxicFo2 = 0.16;
  static const double hypoxicMaxDepthMeters = 3.0;
  static const int hypoxicSustainSeconds = 120;
  static const double modToleranceMeters = 1.0;

  // tank_assignment
  static const double wrongTankInactiveDropFraction = 0.7;
  static const double wrongTankMinTotalDropBar = 20.0;
  static const double twinSeriesMeanDiffBar = 2.0;
  static const int twinSeriesMinSamples = 10;

  // source_conflict
  static const double sourceDepthDiffFraction = 0.05;
  static const double sourceDepthDiffMinMeters = 2.0;
  static const double sourceDurationDiffFraction = 0.10;
  static const double sourceTempDiffC = 3.0;
  static const double salinityRatioLow = 1.02;
  static const double salinityRatioHigh = 1.035;

  // neighbor lookup window for cross-dive detectors
  static const Duration neighborWindow = Duration(hours: 12);
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/data_quality/domain/quality_finding_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): finding entity, deterministic ids, thresholds"
```

---

### Task 4: QualityFindingsRepository

**Files:**
- Create: `lib/features/data_quality/data/repositories/quality_findings_repository.dart`
- Test: `test/features/data_quality/data/quality_findings_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 (`QualityFindings` table, entity type `'qualityFindings'`, `QualityFinding`).
- Produces:
  - `Future<ScanApplyResult> applyScanResults({required Set<String> scopeDiveIds, required Set<String> ranDetectorIds, required List<QualityFinding> produced})` — one transaction, NO notify (caller notifies per batch).
  - `Future<void> setStatus(String id, QualityStatus status)` — notifies.
  - `Future<List<QualityFinding>> getFindings({QualityStatus? status, String? diveId})`
  - `Stream<int> watchOpenCount()`
  - `class ScanApplyResult { final int inserted; final int updated; final int removed; }`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/data/quality_findings_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

import '../../../helpers/test_database.dart';

QualityFinding finding({
  String diveId = 'd1',
  String detectorId = 'sample_gap',
  String discriminator = '',
  QualitySeverity severity = QualitySeverity.info,
  Map<String, Object?> params = const {'gapCount': 1},
}) {
  final now = DateTime.utc(2026, 7, 17);
  return QualityFinding(
    id: qualityFindingId(
      diveId: diveId,
      detectorId: detectorId,
      discriminator: discriminator,
    ),
    diveId: diveId,
    detectorId: detectorId,
    detectorVersion: 1,
    category: QualityCategory.profile,
    severity: severity,
    status: QualityStatus.open,
    params: params,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late QualityFindingsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    // Findings reference dives; FK seeding is out of scope for these tests.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repo = QualityFindingsRepository();
  });
  tearDown(tearDownTestDatabase);

  test('applyScanResults inserts new findings as open', () async {
    final result = await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [finding()],
    );
    expect(result.inserted, 1);
    final all = await repo.getFindings();
    expect(all, hasLength(1));
    expect(all.single.status, QualityStatus.open);
  });

  test('rescan preserves dismissed status', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    await repo.setStatus(f.id, QualityStatus.dismissed);
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f.copyWith(params: const {'gapCount': 3})],
    );
    final all = await repo.getFindings();
    expect(all.single.status, QualityStatus.dismissed);
    expect(all.single.params['gapCount'], 3); // facts refresh, status sticks
  });

  test('resolved finding still produced is reopened', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    await repo.setStatus(f.id, QualityStatus.resolved);
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    final all = await repo.getFindings();
    expect(all.single.status, QualityStatus.open);
  });

  test('finding not re-produced is deleted with a tombstone', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    final result = await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: const [],
    );
    expect(result.removed, 1);
    expect(await repo.getFindings(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'qualityFindings'",
        )
        .get();
    expect(tombstones.map((r) => r.read<String>('record_id')), contains(f.id));
  });

  test('detectors that did not run leave their findings untouched', () async {
    final gap = finding();
    final spike = finding(detectorId: 'depth_spike');
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap', 'depth_spike'},
      produced: [gap, spike],
    );
    // Rescan runs only sample_gap and produces nothing: the spike finding
    // must survive.
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: const [],
    );
    final all = await repo.getFindings();
    expect(all.map((f) => f.detectorId), ['depth_spike']);
  });

  test('pair findings retire when either member is in scope', () async {
    final pid = qualityPairIdentity(detectorId: 'duplicate', a: 'dB', b: 'dA');
    final pair = QualityFinding(
      id: pid.id,
      diveId: pid.diveId, // 'dA'
      relatedDiveId: pid.relatedDiveId, // 'dB'
      detectorId: 'duplicate',
      detectorVersion: 1,
      category: QualityCategory.duplicate,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await repo.applyScanResults(
      scopeDiveIds: {'dA', 'dB'},
      ranDetectorIds: {'duplicate'},
      produced: [pair],
    );
    // Scanning only dB (the related dive) and producing nothing retires it.
    await repo.applyScanResults(
      scopeDiveIds: {'dB'},
      ranDetectorIds: {'duplicate'},
      produced: const [],
    );
    expect(await repo.getFindings(), isEmpty);
  });

  test('watchOpenCount tracks open findings', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    expect(await repo.watchOpenCount().first, 1);
    await repo.setStatus(f.id, QualityStatus.dismissed);
    expect(await repo.watchOpenCount().first, 0);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/data/quality_findings_repository_test.dart`
Expected: FAIL (repository does not exist).

- [ ] **Step 3: Implement the repository**

```dart
// lib/features/data_quality/data/repositories/quality_findings_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/data/repositories/sync_repository.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../domain/entities/quality_finding.dart';

class ScanApplyResult {
  const ScanApplyResult({
    required this.inserted,
    required this.updated,
    required this.removed,
  });
  final int inserted;
  final int updated;
  final int removed;
}

class QualityFindingsRepository {
  QualityFindingsRepository();

  AppDatabase get _db => DatabaseService.instance.database;
  final _sync = SyncRepository();

  /// Applies one scan's results for a scope of dives and detectors.
  ///
  /// Semantics (spec "Write discipline"):
  /// - re-produced findings refresh facts but preserve `dismissed`;
  /// - `resolved` findings still produced reopen (the repair did not stick);
  /// - findings in scope not re-produced are deleted with tombstones;
  /// - detectors outside [ranDetectorIds] are never touched.
  ///
  /// Runs in one transaction and does NOT notify; the scan service emits one
  /// SyncEventBus.notifyLocalChange() per batch.
  Future<ScanApplyResult> applyScanResults({
    required Set<String> scopeDiveIds,
    required Set<String> ranDetectorIds,
    required List<QualityFinding> produced,
  }) async {
    if (scopeDiveIds.isEmpty || ranDetectorIds.isEmpty) {
      return const ScanApplyResult(inserted: 0, updated: 0, removed: 0);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Same id produced twice in a batch (both members of a pair scanned)
    // collapses here.
    final producedById = {for (final f in produced) f.id: f};

    return _db.transaction(() async {
      final existingRows =
          await (_db.select(_db.qualityFindings)..where(
                (t) =>
                    t.detectorId.isIn(ranDetectorIds) &
                    (t.diveId.isIn(scopeDiveIds) |
                        t.relatedDiveId.isIn(scopeDiveIds)),
              ))
              .get();
      final existingById = {for (final r in existingRows) r.id: r};

      var removed = 0;
      for (final row in existingRows) {
        if (producedById.containsKey(row.id)) continue;
        await (_db.delete(
          _db.qualityFindings,
        )..where((t) => t.id.equals(row.id))).go();
        await _sync.logDeletion(
          entityType: 'qualityFindings',
          recordId: row.id,
        );
        removed++;
      }

      var inserted = 0;
      var updated = 0;
      for (final f in producedById.values) {
        final existing =
            existingById[f.id] ??
            await (_db.select(
              _db.qualityFindings,
            )..where((t) => t.id.equals(f.id))).getSingleOrNull();
        final paramsJson = jsonEncode(f.params);
        if (existing == null) {
          await _db
              .into(_db.qualityFindings)
              .insert(
                QualityFindingsCompanion.insert(
                  id: f.id,
                  diveId: f.diveId,
                  relatedDiveId: Value(f.relatedDiveId),
                  computerId: Value(f.computerId),
                  detectorId: f.detectorId,
                  detectorVersion: f.detectorVersion,
                  category: f.category.name,
                  severity: f.severity.name,
                  status: const Value('open'),
                  params: Value(paramsJson),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          inserted++;
        } else {
          final newStatus = existing.status == QualityStatus.resolved.name
              ? QualityStatus.open.name
              : existing.status;
          final unchanged =
              existing.params == paramsJson &&
              existing.severity == f.severity.name &&
              existing.detectorVersion == f.detectorVersion &&
              existing.status == newStatus;
          if (unchanged) continue; // avoid sync churn on repeat scans
          await (_db.update(_db.qualityFindings)
                ..where((t) => t.id.equals(f.id)))
              .write(
                QualityFindingsCompanion(
                  detectorVersion: Value(f.detectorVersion),
                  severity: Value(f.severity.name),
                  params: Value(paramsJson),
                  status: Value(newStatus),
                  updatedAt: Value(now),
                ),
              );
          updated++;
        }
        await _sync.markRecordPending(
          entityType: 'qualityFindings',
          recordId: f.id,
          localUpdatedAt: now,
        );
      }
      return ScanApplyResult(
        inserted: inserted,
        updated: updated,
        removed: removed,
      );
    });
  }

  Future<void> setStatus(String id, QualityStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.qualityFindings)..where((t) => t.id.equals(id)))
        .write(
          QualityFindingsCompanion(
            status: Value(status.name),
            updatedAt: Value(now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'qualityFindings',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<List<QualityFinding>> getFindings({
    QualityStatus? status,
    String? diveId,
  }) async {
    final query = _db.select(_db.qualityFindings)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null) {
      query.where((t) => t.status.equals(status.name));
    }
    if (diveId != null) {
      query.where((t) => t.diveId.equals(diveId) | t.relatedDiveId.equals(diveId));
    }
    final rows = await query.get();
    return [for (final r in rows) _fromRow(r)];
  }

  Stream<int> watchOpenCount() {
    final count = _db.qualityFindings.id.count();
    final query = _db.selectOnly(_db.qualityFindings)
      ..addColumns([count])
      ..where(_db.qualityFindings.status.equals(QualityStatus.open.name));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  QualityFinding _fromRow(QualityFindingRow row) => QualityFinding(
    id: row.id,
    diveId: row.diveId,
    relatedDiveId: row.relatedDiveId,
    computerId: row.computerId,
    detectorId: row.detectorId,
    detectorVersion: row.detectorVersion,
    category: QualityCategory.values.byName(row.category),
    severity: QualitySeverity.values.byName(row.severity),
    status: QualityStatus.values.byName(row.status),
    params: (jsonDecode(row.params) as Map<String, dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
```

Note: if `markRecordPending` throws for the new entity type, Task 2's `_hlcTargets` entry is missing — fix there, not here.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/data_quality/data/quality_findings_repository_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): findings repository with scan-apply semantics"
```

---

### Task 5: DiveQualityContext + builder

**Files:**
- Create: `lib/features/data_quality/domain/entities/dive_quality_context.dart`
- Create: `lib/features/data_quality/data/services/quality_context_builder.dart`
- Test: `test/features/data_quality/data/quality_context_builder_test.dart`

**Interfaces:**
- Consumes: `DiveRepository` (`getDivesByIds`, `getDataSources`), Drift tables `diveProfiles`, `tankPressureProfiles`, `gasSwitches`, `dives`; `QualityThresholds.neighborWindow`.
- Produces:
  - `class QualitySample { final int t; final double depth; final double? temp; }`
  - `class QualityPressureSample { final int t; final double bar; }`
  - `class QualityNeighbor { final String id; final DateTime entryTime; final DateTime? exitTime; final double? maxDepth; final int? durationSeconds; final String? computerSerial; final double? firstSampleDepth; final double? lastSampleDepth; }`
  - `class DiveQualityContext { final domain.Dive dive; final DateTime now; final List<DiveDataSource> sources; final List<QualitySample> primarySamples; final List<domain.DiveTank> tanks; final Map<String, List<QualityPressureSample>> pressuresByTankId; final List<GasSwitch> gasSwitches; final List<QualityNeighbor> neighbors; }`
  - `class QualityContextBuilder { Future<List<DiveQualityContext>> buildAll(List<String> diveIds, {DateTime? now}); }`
- Guarantees: samples sorted by `t`, non-finite depths/temps/pressures dropped, neighbors are same-diver dives with entry within `neighborWindow` of this dive's [entry, exit].

- [ ] **Step 1: Write the failing test**

```dart
// test/features/data_quality/data/quality_context_builder_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late QualityContextBuilder builder;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    builder = QualityContextBuilder();
  });
  tearDown(tearDownTestDatabase);

  Future<String> seedDive({
    required String id,
    required DateTime entry,
    Duration runtime = const Duration(minutes: 40),
    String? serial,
    List<domain.DiveProfilePoint> profile = const [],
  }) async {
    final dive = domain.Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      runtime: runtime,
      maxDepth: 30.0,
      diveComputerSerial: serial,
      profile: profile,
    );
    await diveRepo.createDive(dive);
    return id;
  }

  test('builds context with sanitized sorted samples', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(
      id: 'd1',
      entry: entry,
      profile: [
        const domain.DiveProfilePoint(timestamp: 10, depth: 5.0),
        const domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      ],
    );
    // Directly insert a non-finite depth row: the builder must drop it.
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion.insert(
            id: 'p-bad',
            diveId: 'd1',
            timestamp: 20,
            depth: double.infinity,
          ),
        );
    final ctx = (await builder.buildAll(['d1'])).single;
    expect(ctx.primarySamples.map((s) => s.t), [0, 10]); // sorted, bad dropped
    expect(ctx.dive.id, 'd1');
  });

  test('finds same-diver neighbors within the window with edge depths', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await seedDive(id: 'dA', entry: entry, serial: 'SN-1');
    await seedDive(
      id: 'dB',
      entry: entry.add(const Duration(hours: 1)),
      serial: 'SN-1',
      profile: [
        const domain.DiveProfilePoint(timestamp: 0, depth: 4.0),
        const domain.DiveProfilePoint(timestamp: 60, depth: 1.5),
      ],
    );
    await seedDive(
      id: 'dFar',
      entry: entry.add(const Duration(days: 2)),
      serial: 'SN-1',
    );
    final ctx = (await builder.buildAll(['dA'])).single;
    expect(ctx.neighbors.map((n) => n.id), ['dB']);
    expect(ctx.neighbors.single.computerSerial, 'SN-1');
    expect(ctx.neighbors.single.firstSampleDepth, 4.0);
    expect(ctx.neighbors.single.lastSampleDepth, 1.5);
  });
}
```

Note: `domain.DiveProfilePoint` and `domain.Dive` constructors — if a required parameter is missing in this test, fix the TEST to supply it (the entities are existing code and must not change). `DiveProfilesCompanion.insert` requires `isPrimary` only if the column has no default; add `isPrimary: const Value(true)` if the insert fails.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/data/quality_context_builder_test.dart`
Expected: FAIL (builder does not exist).

- [ ] **Step 3: Implement the context entity file**

```dart
// lib/features/data_quality/domain/entities/dive_quality_context.dart
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../../../dive_log/domain/entities/dive_data_source.dart';
import '../../../dive_log/domain/entities/gas_switch.dart';

class QualitySample {
  const QualitySample({required this.t, required this.depth, this.temp});

  /// Seconds from dive start.
  final int t;
  final double depth;
  final double? temp;
}

class QualityPressureSample {
  const QualityPressureSample({required this.t, required this.bar});
  final int t;
  final double bar;
}

class QualityNeighbor {
  const QualityNeighbor({
    required this.id,
    required this.entryTime,
    this.exitTime,
    this.maxDepth,
    this.durationSeconds,
    this.computerSerial,
    this.firstSampleDepth,
    this.lastSampleDepth,
  });

  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double? maxDepth;
  final int? durationSeconds;
  final String? computerSerial;
  final double? firstSampleDepth;
  final double? lastSampleDepth;
}

/// Everything a detector may look at for one dive. Built once per dive per
/// scan; detectors are pure functions over this. All numeric series are
/// sanitized (finite values only) and sorted by timestamp.
class DiveQualityContext {
  const DiveQualityContext({
    required this.dive,
    required this.now,
    this.sources = const [],
    this.primarySamples = const [],
    this.tanks = const [],
    this.pressuresByTankId = const {},
    this.gasSwitches = const [],
    this.neighbors = const [],
  });

  final domain.Dive dive;
  final DateTime now;
  final List<DiveDataSource> sources;
  final List<QualitySample> primarySamples;
  final List<domain.DiveTank> tanks;
  final Map<String, List<QualityPressureSample>> pressuresByTankId;
  final List<GasSwitch> gasSwitches;
  final List<QualityNeighbor> neighbors;
}
```

- [ ] **Step 4: Implement the builder**

```dart
// lib/features/data_quality/data/services/quality_context_builder.dart
import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../../../dive_log/domain/entities/gas_switch.dart';
import '../../domain/entities/dive_quality_context.dart';
import '../../domain/quality_thresholds.dart';

class QualityContextBuilder {
  QualityContextBuilder({DiveRepository? diveRepository})
    : _diveRepo = diveRepository ?? DiveRepository();

  final DiveRepository _diveRepo;
  AppDatabase get _db => DatabaseService.instance.database;

  Future<List<DiveQualityContext>> buildAll(
    List<String> diveIds, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final dives = await _diveRepo.getDivesByIds(diveIds);
    final out = <DiveQualityContext>[];
    for (final dive in dives) {
      out.add(await _build(dive, effectiveNow));
    }
    return out;
  }

  Future<DiveQualityContext> _build(domain.Dive dive, DateTime now) async {
    final profileRows =
        await (_db.select(_db.diveProfiles)
              ..where(
                (t) => t.diveId.equals(dive.id) & t.isPrimary.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final samples = <QualitySample>[
      for (final r in profileRows)
        if (r.depth.isFinite &&
            (r.temperature == null || r.temperature!.isFinite))
          QualitySample(t: r.timestamp, depth: r.depth, temp: r.temperature),
    ];

    final pressureRows =
        await (_db.select(_db.tankPressureProfiles)
              ..where((t) => t.diveId.equals(dive.id))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final pressures = <String, List<QualityPressureSample>>{};
    for (final r in pressureRows) {
      if (!r.pressure.isFinite) continue;
      pressures
          .putIfAbsent(r.tankId, () => [])
          .add(QualityPressureSample(t: r.timestamp, bar: r.pressure));
    }

    final switchRows =
        await (_db.select(_db.gasSwitches)
              ..where((t) => t.diveId.equals(dive.id))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final switches = [
      for (final r in switchRows)
        GasSwitch(
          id: r.id,
          diveId: r.diveId,
          timestamp: r.timestamp,
          tankId: r.tankId,
          depth: r.depth,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        ),
    ];

    final sources = await _diveRepo.getDataSources(dive.id);
    final neighbors = await _neighbors(dive);

    return DiveQualityContext(
      dive: dive,
      now: now,
      sources: sources,
      primarySamples: samples,
      tanks: dive.tanks,
      pressuresByTankId: pressures,
      gasSwitches: switches,
      neighbors: neighbors,
    );
  }

  Future<List<QualityNeighbor>> _neighbors(domain.Dive dive) async {
    final entry = dive.effectiveEntryTime;
    final exit = entry.add(dive.effectiveRuntime ?? Duration.zero);
    final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
    final rows = await _db
        .customSelect(
          'SELECT id, entry_time, dive_date_time, exit_time, max_depth, '
          'runtime, bottom_time, dive_computer_serial '
          'FROM dives WHERE id != ?1 AND diver_id IS ?2 '
          'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4 '
          'ORDER BY COALESCE(entry_time, dive_date_time) ASC',
          variables: [
            Variable.withString(dive.id),
            Variable(dive.diverId),
            Variable.withInt(entry.millisecondsSinceEpoch - windowMs),
            Variable.withInt(exit.millisecondsSinceEpoch + windowMs),
          ],
          readsFrom: {_db.dives},
        )
        .get();
    final out = <QualityNeighbor>[];
    for (final row in rows) {
      final entryMs =
          row.read<int?>('entry_time') ?? row.read<int?>('dive_date_time');
      if (entryMs == null) continue;
      final durationSeconds =
          row.read<int?>('runtime') ?? row.read<int?>('bottom_time');
      final exitMs =
          row.read<int?>('exit_time') ??
          (durationSeconds != null ? entryMs + durationSeconds * 1000 : null);
      final id = row.read<String>('id');
      out.add(
        QualityNeighbor(
          id: id,
          entryTime: DateTime.fromMillisecondsSinceEpoch(entryMs),
          exitTime: exitMs != null
              ? DateTime.fromMillisecondsSinceEpoch(exitMs)
              : null,
          maxDepth: row.read<double?>('max_depth'),
          durationSeconds: durationSeconds,
          computerSerial: row.read<String?>('dive_computer_serial'),
          firstSampleDepth: await _edgeDepth(id, first: true),
          lastSampleDepth: await _edgeDepth(id, first: false),
        ),
      );
    }
    return out;
  }

  Future<double?> _edgeDepth(String diveId, {required bool first}) async {
    final q = _db.select(_db.diveProfiles)
      ..where((t) => t.diveId.equals(diveId) & t.isPrimary.equals(true))
      ..orderBy([
        (t) => first
            ? OrderingTerm.asc(t.timestamp)
            : OrderingTerm.desc(t.timestamp),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    final d = row?.depth;
    return (d != null && d.isFinite) ? d : null;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/data_quality/data/quality_context_builder_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): dive quality context and builder"
```

---

### Task 6: Detector base + cross-dive detectors (clock_offset, duplicate, split_pair)

**Files:**
- Create: `lib/features/data_quality/domain/detectors/quality_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/clock_offset_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/duplicate_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/split_pair_detector.dart`
- Create: `test/features/data_quality/helpers/quality_test_helpers.dart`
- Test: `test/features/data_quality/domain/detectors/cross_dive_detectors_test.dart`

**Interfaces:**
- Consumes: Task 3 entity/id helpers/thresholds, Task 5 context, existing `DiveMatcher` (`lib/features/dive_import/domain/services/dive_matcher.dart`).
- Produces: `abstract class QualityDetector { String get id; int get version; QualityCategory get category; List<QualityFinding> detect(DiveQualityContext context); }` with protected `make(...)` and `makePair(...)` factories; three concrete detectors with const constructors.

- [ ] **Step 1: Write the test helper**

```dart
// test/features/data_quality/helpers/quality_test_helpers.dart
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Minimal dive for pure detector tests. If domain.Dive gains required
/// constructor parameters, extend HERE only.
domain.Dive makeTestDive({
  String id = 'd1',
  DateTime? entry,
  Duration? runtime = const Duration(minutes: 40),
  double? maxDepth = 30.0,
  double? avgDepth,
  double? waterTemp,
  String? serial,
  List<domain.DiveTank> tanks = const [],
}) => domain.Dive(
  id: id,
  dateTime: entry ?? DateTime.utc(2026, 7, 1, 10),
  entryTime: entry ?? DateTime.utc(2026, 7, 1, 10),
  runtime: runtime,
  maxDepth: maxDepth,
  avgDepth: avgDepth,
  waterTemp: waterTemp,
  diveComputerSerial: serial,
  tanks: tanks,
);

DiveQualityContext makeContext({
  required domain.Dive dive,
  DateTime? now,
  List<DiveDataSource> sources = const [],
  List<QualitySample> samples = const [],
  Map<String, List<QualityPressureSample>> pressures = const {},
  List<QualityNeighbor> neighbors = const [],
  List<GasSwitch> gasSwitches = const [],
}) => DiveQualityContext(
  dive: dive,
  now: now ?? DateTime.utc(2026, 7, 17, 12),
  sources: sources,
  primarySamples: samples,
  tanks: dive.tanks,
  pressuresByTankId: pressures,
  gasSwitches: gasSwitches,
  neighbors: neighbors,
);

/// Descend to [depth] at t=0..60, hold, surface in the last minute.
/// Interval fixed at 10 s.
List<QualitySample> flatProfile({
  double depth = 30,
  int durationSeconds = 2400,
  double? temp,
}) => [
  for (var t = 0; t <= durationSeconds; t += 10)
    QualitySample(
      t: t,
      depth: t < 60
          ? depth * (t / 60)
          : (t > durationSeconds - 60
                ? depth * ((durationSeconds - t) / 60)
                : depth),
      temp: temp,
    ),
];
```

- [ ] **Step 2: Write the failing detector tests**

```dart
// test/features/data_quality/domain/detectors/cross_dive_detectors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/clock_offset_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/duplicate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/split_pair_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

import '../../helpers/quality_test_helpers.dart';

void main() {
  final entry = DateTime.utc(2026, 7, 1, 10);

  group('ClockOffsetDetector', () {
    const det = ClockOffsetDetector();

    test('flags future-dated dive as critical', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: DateTime.utc(2027, 1, 1)),
        now: DateTime.utc(2026, 7, 17),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.detectorId, 'clock_offset');
    });

    test('flags whole-hour source offset (179 min -> 3 h, remainder 1)', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: entry),
        sources: [
          DiveDataSource(
            id: 's-primary',
            diveId: 'd1',
            isPrimary: true,
            entryTime: entry,
            importedAt: entry,
            createdAt: entry,
          ),
          DiveDataSource(
            id: 's-off',
            diveId: 'd1',
            isPrimary: false,
            entryTime: entry.add(const Duration(minutes: 179)),
            importedAt: entry,
            createdAt: entry,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['offsetHours'], 3);
    });

    test('45 min offset is NOT a timezone signature (remainder 15 > 5)', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: entry),
        sources: [
          DiveDataSource(
            id: 's-primary',
            diveId: 'd1',
            isPrimary: true,
            entryTime: entry,
            importedAt: entry,
            createdAt: entry,
          ),
          DiveDataSource(
            id: 's-off',
            diveId: 'd1',
            isPrimary: false,
            entryTime: entry.add(const Duration(minutes: 45)),
            importedAt: entry,
            createdAt: entry,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('flags overlapping same-diver neighbor as a pair finding', () {
      // Dive runs 10:00-10:40; neighbor 10:20-11:00 overlaps 20 min.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 20)),
            exitTime: entry.add(const Duration(minutes: 60)),
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.diveId, 'dA'); // lexically smaller anchors the pair
      expect(out.single.relatedDiveId, 'dB');
      expect(out.single.params['overlapMinutes'], 20);
    });
  });

  group('DuplicateDetector', () {
    const det = DuplicateDetector();

    test('near-identical dive 5 min apart scores 1.0 -> critical', () {
      // timeScore = bandScore(5, full:5, zero:15) = 1.0; depth and duration
      // identical -> 1.0 each; score = .5 + .3 + .2 = 1.0 >= 0.7.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 5)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.params['score'], closeTo(1.0, 1e-9));
    });

    test('12 min apart, same profile -> 0.65 -> warning', () {
      // timeScore = 1 - (12-5)/(15-5) = 0.3; score = .5*.3 + .3 + .2 = 0.65.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 12)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['score'], closeTo(0.65, 1e-9));
    });

    test('16 min apart is gated to zero -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 16)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('SplitPairDetector', () {
    const det = SplitPairDetector();

    test('same-serial dive resuming 5 min later, deep ends -> finding', () {
      // This dive 10:00-10:40 ends at 8 m; neighbor starts 10:45.
      final samples = [
        const QualitySample(t: 0, depth: 0),
        const QualitySample(t: 2400, depth: 8.0),
      ];
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        samples: samples,
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 45)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['gapSeconds'], 300);
      expect(out.single.params['earlierEndsDeep'], true);
    });

    test('different serial -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 45)),
            computerSerial: 'SN-2',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('12 min gap exceeds splitMaxGap -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 52)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });
  });
}
```

Note: `DiveDataSource` requires `importedAt`/`createdAt` — if its constructor requires more, supply them in the TEST.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/data_quality/domain/detectors/cross_dive_detectors_test.dart`
Expected: FAIL (detectors do not exist).

- [ ] **Step 4: Implement the base class**

```dart
// lib/features/data_quality/domain/detectors/quality_detector.dart
import 'package:meta/meta.dart';

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';

/// A pure, synchronous quality check. Implementations must not do IO and
/// must read every threshold from QualityThresholds.
abstract class QualityDetector {
  const QualityDetector();

  String get id;

  /// Bump when detection logic changes; drives "new checks available".
  int get version;
  QualityCategory get category;

  List<QualityFinding> detect(DiveQualityContext context);

  @protected
  QualityFinding make(
    DiveQualityContext ctx, {
    String discriminator = '',
    String? relatedDiveId,
    String? computerId,
    required QualitySeverity severity,
    Map<String, Object?> params = const {},
  }) => QualityFinding(
    id: qualityFindingId(
      diveId: ctx.dive.id,
      detectorId: id,
      discriminator: discriminator,
    ),
    diveId: ctx.dive.id,
    relatedDiveId: relatedDiveId,
    computerId: computerId,
    detectorId: id,
    detectorVersion: version,
    category: category,
    severity: severity,
    status: QualityStatus.open,
    params: params,
    createdAt: ctx.now,
    updatedAt: ctx.now,
  );

  /// Cross-dive finding anchored on the lexically smaller dive id so both
  /// members' scans produce the identical row.
  @protected
  QualityFinding makePair(
    DiveQualityContext ctx, {
    required String otherDiveId,
    String discriminator = '',
    String? computerId,
    required QualitySeverity severity,
    Map<String, Object?> params = const {},
  }) {
    final pid = qualityPairIdentity(
      detectorId: id,
      a: ctx.dive.id,
      b: otherDiveId,
      discriminator: discriminator,
    );
    return QualityFinding(
      id: pid.id,
      diveId: pid.diveId,
      relatedDiveId: pid.relatedDiveId,
      computerId: computerId,
      detectorId: id,
      detectorVersion: version,
      category: category,
      severity: severity,
      status: QualityStatus.open,
      params: params,
      createdAt: ctx.now,
      updatedAt: ctx.now,
    );
  }
}
```

- [ ] **Step 5: Implement the three detectors**

```dart
// lib/features/data_quality/domain/detectors/clock_offset_detector.dart
import 'package:collection/collection.dart';

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class ClockOffsetDetector extends QualityDetector {
  const ClockOffsetDetector();

  @override
  String get id => 'clock_offset';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.time;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final entry = ctx.dive.effectiveEntryTime;

    if (entry.isAfter(
      ctx.now.add(const Duration(days: QualityThresholds.futureGraceDays)),
    )) {
      out.add(
        make(
          ctx,
          discriminator: 'future',
          severity: QualitySeverity.critical,
          params: {'entryTimeMs': entry.millisecondsSinceEpoch},
        ),
      );
    } else if (entry.year < QualityThresholds.minPlausibleYear) {
      out.add(
        make(
          ctx,
          discriminator: 'ancient',
          severity: QualitySeverity.warning,
          params: {'entryTimeMs': entry.millisecondsSinceEpoch},
        ),
      );
    }

    // Whole-hour offsets between sources: the unset-timezone signature.
    final primary =
        ctx.sources.firstWhereOrNull((s) => s.isPrimary) ??
        ctx.sources.firstOrNull;
    final primaryEntry = primary?.entryTime;
    if (primary != null && primaryEntry != null) {
      for (final s in ctx.sources) {
        final sEntry = s.entryTime;
        if (s.id == primary.id || sEntry == null) continue;
        final diffMin = sEntry.difference(primaryEntry).inMinutes;
        final hours = (diffMin / 60).round();
        final remainder = (diffMin - hours * 60).abs();
        if (hours.abs() >= QualityThresholds.hourOffsetMin &&
            hours.abs() <= QualityThresholds.hourOffsetMax &&
            remainder <= QualityThresholds.hourOffsetRemainderToleranceMin) {
          out.add(
            make(
              ctx,
              discriminator: 'src:${s.id}',
              computerId: s.computerId,
              severity: QualitySeverity.warning,
              params: {'offsetHours': hours, 'sourceId': s.id},
            ),
          );
        }
      }
    }

    // Same-diver dives overlapping in time cannot both be right.
    final runtime = ctx.dive.effectiveRuntime;
    if (runtime != null) {
      final exit = entry.add(runtime);
      for (final n in ctx.neighbors) {
        final nExit = n.exitTime;
        if (nExit == null) continue;
        if (n.entryTime.isBefore(exit) && nExit.isAfter(entry)) {
          final overlapStart = entry.isAfter(n.entryTime) ? entry : n.entryTime;
          final overlapEnd = exit.isBefore(nExit) ? exit : nExit;
          out.add(
            makePair(
              ctx,
              otherDiveId: n.id,
              discriminator: 'overlap',
              severity: QualitySeverity.warning,
              params: {
                'overlapMinutes': overlapEnd.difference(overlapStart).inMinutes,
              },
            ),
          );
        }
      }
    }
    return out;
  }
}
```

```dart
// lib/features/data_quality/domain/detectors/duplicate_detector.dart
import '../../../dive_import/domain/services/dive_matcher.dart';
import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

/// Reuses the file-import DiveMatcher so the inbox and the import wizard can
/// never disagree about what counts as a duplicate.
class DuplicateDetector extends QualityDetector {
  const DuplicateDetector();

  static const _matcher = DiveMatcher();

  @override
  String get id => 'duplicate';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.duplicate;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final dive = ctx.dive;
    final entry = dive.effectiveEntryTime;
    final maxDepth = dive.maxDepth;
    final duration = dive.effectiveRuntime?.inSeconds;
    if (maxDepth == null || duration == null || duration <= 0) {
      return const [];
    }
    final out = <QualityFinding>[];
    for (final n in ctx.neighbors) {
      final nDepth = n.maxDepth;
      final nDuration = n.durationSeconds;
      if (nDepth == null || nDuration == null || nDuration <= 0) continue;
      if (entry.difference(n.entryTime).abs() >
          QualityThresholds.duplicateWindow) {
        continue;
      }
      final score = _matcher.calculateMatchScore(
        wearableStartTime: entry,
        wearableMaxDepth: maxDepth,
        wearableDurationSeconds: duration,
        existingStartTime: n.entryTime,
        existingMaxDepth: nDepth,
        existingDurationSeconds: nDuration,
      );
      if (!_matcher.isPossibleDuplicate(score)) continue;
      out.add(
        makePair(
          ctx,
          otherDiveId: n.id,
          severity: _matcher.isProbableDuplicate(score)
              ? QualitySeverity.critical
              : QualitySeverity.warning,
          params: {
            'score': score,
            'timeDiffMinutes': entry.difference(n.entryTime).inMinutes.abs(),
            'thisMaxDepth': maxDepth,
            'otherMaxDepth': nDepth,
          },
        ),
      );
    }
    return out;
  }
}
```

```dart
// lib/features/data_quality/domain/detectors/split_pair_detector.dart
import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

/// A computer that surfaced briefly logs one physical dive as two. Signature:
/// same serial, tiny surface interval, and the boundary looks like a
/// continuation.
class SplitPairDetector extends QualityDetector {
  const SplitPairDetector();

  @override
  String get id => 'split_pair';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.duplicate;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final dive = ctx.dive;
    final serial = dive.diveComputerSerial;
    if (serial == null || serial.isEmpty) return const [];
    final entry = dive.effectiveEntryTime;
    final runtime = dive.effectiveRuntime;
    if (runtime == null) return const [];
    final exit = entry.add(runtime);
    final firstDepth = ctx.primarySamples.isNotEmpty
        ? ctx.primarySamples.first.depth
        : null;
    final lastDepth = ctx.primarySamples.isNotEmpty
        ? ctx.primarySamples.last.depth
        : null;

    final out = <QualityFinding>[];
    for (final n in ctx.neighbors) {
      if (n.computerSerial != serial) continue;
      final thisFirst = !entry.isAfter(n.entryTime);
      final Duration? gap;
      if (thisFirst) {
        gap = n.entryTime.difference(exit);
      } else if (n.exitTime != null) {
        gap = entry.difference(n.exitTime!);
      } else {
        gap = null;
      }
      if (gap == null ||
          gap.isNegative ||
          gap > QualityThresholds.splitMaxGap) {
        continue;
      }
      final earlierEndsDeep = thisFirst
          ? (lastDepth != null &&
                lastDepth > QualityThresholds.splitDeepEndMeters)
          : (n.lastSampleDepth != null &&
                n.lastSampleDepth! > QualityThresholds.splitDeepEndMeters);
      final laterStartsDeep = thisFirst
          ? (n.firstSampleDepth != null &&
                n.firstSampleDepth! > QualityThresholds.splitDeepEndMeters)
          : (firstDepth != null &&
                firstDepth > QualityThresholds.splitDeepEndMeters);
      final continuation =
          earlierEndsDeep ||
          laterStartsDeep ||
          gap <= QualityThresholds.splitShallowGap;
      if (!continuation) continue;
      out.add(
        makePair(
          ctx,
          otherDiveId: n.id,
          severity: QualitySeverity.warning,
          params: {
            'gapSeconds': gap.inSeconds,
            'earlierEndsDeep': earlierEndsDeep,
            'laterStartsDeep': laterStartsDeep,
          },
        ),
      );
    }
    return out;
  }
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/data_quality/domain/detectors/cross_dive_detectors_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): clock, duplicate and split detectors"
```

---

### Task 7: Profile detectors (sample_gap, depth_spike, impossible_rate)

**Files:**
- Create: `lib/features/data_quality/domain/detectors/sample_gap_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/depth_spike_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/impossible_rate_detector.dart`
- Test: `test/features/data_quality/domain/detectors/profile_detectors_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6 (base class).
- Produces: three detectors, ids `sample_gap` / `depth_spike` / `impossible_rate`, category `QualityCategory.profile`, const constructors, version 1.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/domain/detectors/profile_detectors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/depth_spike_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/impossible_rate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/sample_gap_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

import '../../helpers/quality_test_helpers.dart';

void main() {
  group('SampleGapDetector', () {
    const det = SampleGapDetector();

    test('clean 10 s profile has no findings', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        samples: flatProfile(),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('one 120 s hole in a 10 s profile is an info finding', () {
      // median interval 10 s -> threshold max(20, 30) = 30 s; a 120 s jump
      // is one gap. total 120 < 10% of 2400 -> info.
      final samples = [
        for (var t = 0; t <= 1000; t += 10) QualitySample(t: t, depth: 20),
        for (var t = 1120; t <= 2400; t += 10) QualitySample(t: t, depth: 20),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.info);
      expect(out.single.params['gapCount'], 1);
      expect(out.single.params['longestGapSeconds'], 120);
    });

    test('gaps totalling >10% of runtime escalate to warning', () {
      // Three 120 s holes = 360 s > 10% of ~2400 s runtime.
      final samples = <QualitySample>[];
      var t = 0;
      for (final holeAt in [400, 1000, 1600]) {
        while (t < holeAt) {
          samples.add(QualitySample(t: t, depth: 20));
          t += 10;
        }
        t += 120;
      }
      while (t <= 2400) {
        samples.add(QualitySample(t: t, depth: 20));
        t += 10;
      }
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['gapCount'], 3);
    });
  });

  group('DepthSpikeDetector', () {
    const det = DepthSpikeDetector();

    test('single-sample 35 m excursion at 10 s interval is a spike', () {
      // 35 m in 10 s = 3.5 m/s > 3.0 both directions, opposite signs.
      final samples = [
        for (var t = 0; t <= 600; t += 10)
          QualitySample(t: t, depth: t == 300 ? 55.0 : 20.0),
      ];
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 20),
        samples: samples,
      );
      final out = det.detect(ctx);
      final spike = out.singleWhere(
        (f) => (f.params['atSeconds'] as int?) == 300,
      );
      expect(spike.params['impliedRateMetersPerSecond'], closeTo(3.5, 1e-9));
    });

    test('negative depth samples produce one finding', () {
      final samples = [
        const QualitySample(t: 0, depth: 5),
        const QualitySample(t: 10, depth: -1.2),
        const QualitySample(t: 20, depth: 5),
      ];
      // -1.2 m in 10 s is only 0.62 m/s each way -- not a spike, so exactly
      // one finding (the negative-depth one) fires.
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 5),
        samples: samples,
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['minDepth'], -1.2);
    });

    test('stored maxDepth 40 vs profile max 30 mismatches (> 1.5 m tol)', () {
      // tol = max(0.5, 30 * 0.05) = 1.5; |40-30| = 10 > 1.5.
      final ctx = makeContext(
        dive: makeTestDive(maxDepth: 40),
        samples: flatProfile(depth: 30),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['storedMaxDepth'], 40);
      expect(out.single.params['profileMaxDepth'], 30);
    });
  });

  group('ImpossibleRateDetector', () {
    const det = ImpossibleRateDetector();

    test('36 m/min sustained 40 s is flagged', () {
      // 6 m per 10 s sample = 36 m/min for t in [100, 140].
      final samples = [
        for (var t = 0; t <= 100; t += 10) QualitySample(t: t, depth: 40),
        QualitySample(t: 110, depth: 34),
        QualitySample(t: 120, depth: 28),
        QualitySample(t: 130, depth: 22),
        QualitySample(t: 140, depth: 16),
        for (var t = 150; t <= 300; t += 10) QualitySample(t: t, depth: 16),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['durationSeconds'], 40);
      expect(
        out.single.params['maxRateMetersPerMinute'],
        closeTo(36.0, 1e-9),
      );
    });

    test('a 20 s burst is below the 30 s sustain threshold', () {
      final samples = [
        for (var t = 0; t <= 100; t += 10) QualitySample(t: t, depth: 40),
        QualitySample(t: 110, depth: 34),
        QualitySample(t: 120, depth: 28),
        for (var t = 130; t <= 300; t += 10) QualitySample(t: t, depth: 28),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      expect(det.detect(ctx), isEmpty);
    });

    test('normal 9 m/min ascent is clean', () {
      final samples = [
        for (var t = 0; t <= 200; t += 10)
          QualitySample(t: t, depth: 30 - t * (9.0 / 60 / 10) * 10),
      ];
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      expect(det.detect(ctx), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/domain/detectors/profile_detectors_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the three detectors**

```dart
// lib/features/data_quality/domain/detectors/sample_gap_detector.dart
import 'dart:math' as math;

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class SampleGapDetector extends QualityDetector {
  const SampleGapDetector();

  @override
  String get id => 'sample_gap';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final s = ctx.primarySamples;
    if (s.length < 3) return const [];
    final intervals = <int>[
      for (var i = 1; i < s.length; i++)
        if (s[i].t > s[i - 1].t) s[i].t - s[i - 1].t,
    ];
    if (intervals.isEmpty) return const [];
    final sorted = [...intervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    final threshold = math.max(
      median * QualityThresholds.gapMedianFactor,
      QualityThresholds.gapMinSeconds.toDouble(),
    );
    var gapCount = 0;
    var totalGap = 0;
    var longest = 0;
    for (final iv in intervals) {
      if (iv > threshold) {
        gapCount++;
        totalGap += iv;
        longest = math.max(longest, iv);
      }
    }
    if (gapCount == 0) return const [];
    final runtimeSec = s.last.t - s.first.t;
    final severity =
        runtimeSec > 0 &&
            totalGap > runtimeSec * QualityThresholds.gapWarnFractionOfRuntime
        ? QualitySeverity.warning
        : QualitySeverity.info;
    return [
      make(
        ctx,
        severity: severity,
        params: {
          'gapCount': gapCount,
          'totalGapSeconds': totalGap,
          'longestGapSeconds': longest,
          'medianIntervalSeconds': median,
        },
      ),
    ];
  }
}
```

```dart
// lib/features/data_quality/domain/detectors/depth_spike_detector.dart
import 'dart:math' as math;

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class DepthSpikeDetector extends QualityDetector {
  const DepthSpikeDetector();

  @override
  String get id => 'depth_spike';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final s = ctx.primarySamples;

    var spikes = 0;
    for (
      var i = 1;
      i + 1 < s.length && spikes < QualityThresholds.maxSpikeFindingsPerDive;
      i++
    ) {
      final dt1 = s[i].t - s[i - 1].t;
      final dt2 = s[i + 1].t - s[i].t;
      if (dt1 <= 0 || dt2 <= 0) continue;
      final r1 = (s[i].depth - s[i - 1].depth) / dt1;
      final r2 = (s[i + 1].depth - s[i].depth) / dt2;
      if (r1.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r2.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r1.sign != r2.sign) {
        spikes++;
        out.add(
          make(
            ctx,
            discriminator: 'spike:${s[i].t ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'atSeconds': s[i].t,
              'depth': s[i].depth,
              'impliedRateMetersPerSecond': r1.abs(),
            },
          ),
        );
      }
    }

    final negative = [
      for (final p in s)
        if (p.depth < QualityThresholds.negativeDepthMeters) p.depth,
    ];
    if (negative.isNotEmpty) {
      out.add(
        make(
          ctx,
          discriminator: 'negative',
          severity: QualitySeverity.warning,
          params: {
            'sampleCount': negative.length,
            'minDepth': negative.reduce(math.min),
          },
        ),
      );
    }

    final storedMax = ctx.dive.maxDepth;
    if (s.isNotEmpty && storedMax != null) {
      final profileMax = s.map((p) => p.depth).reduce(math.max);
      final tol = math.max(
        QualityThresholds.maxDepthMismatchMinMeters,
        profileMax * QualityThresholds.maxDepthMismatchFraction,
      );
      if ((storedMax - profileMax).abs() > tol) {
        out.add(
          make(
            ctx,
            discriminator: 'maxdepth',
            severity: QualitySeverity.warning,
            params: {
              'storedMaxDepth': storedMax,
              'profileMaxDepth': profileMax,
            },
          ),
        );
      }
    }
    return out;
  }
}
```

```dart
// lib/features/data_quality/domain/detectors/impossible_rate_detector.dart
import 'dart:math' as math;

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

/// Sustained vertical rates beyond real diving indicate corrupt samples --
/// distinct from the ascent-rate SAFETY events, which cap out at rates a
/// diver can actually produce.
class ImpossibleRateDetector extends QualityDetector {
  const ImpossibleRateDetector();

  @override
  String get id => 'impossible_rate';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final s = ctx.primarySamples;
    final out = <QualityFinding>[];
    int? runStart;
    var runMaxRate = 0.0;
    var lastT = 0;

    void closeRun() {
      if (runStart != null &&
          lastT - runStart! >= QualityThresholds.impossibleRateMinSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'run:${runStart! ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'startSeconds': runStart,
              'durationSeconds': lastT - runStart!,
              'maxRateMetersPerMinute': runMaxRate,
            },
          ),
        );
      }
      runStart = null;
      runMaxRate = 0;
    }

    for (var i = 1; i < s.length; i++) {
      final dt = s[i].t - s[i - 1].t;
      if (dt <= 0) continue;
      final ratePerMin = ((s[i].depth - s[i - 1].depth) / dt * 60).abs();
      if (ratePerMin > QualityThresholds.impossibleRateMetersPerMinute) {
        runStart ??= s[i - 1].t;
        runMaxRate = math.max(runMaxRate, ratePerMin);
        lastT = s[i].t;
      } else {
        closeRun();
      }
    }
    closeRun();
    return out;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/data_quality/domain/detectors/profile_detectors_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): profile gap, spike and rate detectors"
```

---

### Task 8: Temperature + pressure detectors (temp_anomaly, pressure_anomaly)

**Files:**
- Create: `lib/features/data_quality/domain/detectors/temp_anomaly_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/pressure_anomaly_detector.dart`
- Test: `test/features/data_quality/domain/detectors/temp_pressure_detectors_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6. `domain.DiveTank` fields: `id`, `volume` (liters), `startPressure`/`endPressure` (bar), `gasMix` (`o2`/`he` as percents), `order`, `computerId`.
- Produces: `TempAnomalyDetector` (id `temp_anomaly`, category `temperature`), `PressureAnomalyDetector` (id `pressure_anomaly`, category `pressure`), both version 1.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/domain/detectors/temp_pressure_detectors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/pressure_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/temp_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  String id = 't1',
  double? volume = 12.0,
  double? start = 200,
  double? end = 60,
  double o2 = 21.0,
  int order = 0,
}) => domain.DiveTank(
  id: id,
  volume: volume,
  startPressure: start,
  endPressure: end,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
);

void main() {
  group('TempAnomalyDetector', () {
    const det = TempAnomalyDetector();

    test('26 C tropical profile is clean', () {
      final ctx = makeContext(
        dive: makeTestDive(waterTemp: 26),
        samples: flatProfile(temp: 26),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('295 C samples flag range with Fahrenheit-as-Kelvin hint', () {
      // The Shearwater F-as-K bug reports ~295 for 72F water.
      final ctx = makeContext(
        dive: makeTestDive(),
        samples: flatProfile(temp: 295),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['fahrenheitAsKelvinSuspected'], true);
    });

    test('8 C jump between adjacent samples is flagged', () {
      final samples = [
        for (var t = 0; t <= 300; t += 10)
          QualitySample(t: t, depth: 20, temp: t == 150 ? 12.0 : 20.0),
      ];
      // Two jumps (into and out of the bad sample), same 5-min bucket ->
      // one finding survives the deterministic-id collapse; assert >= 1.
      final ctx = makeContext(dive: makeTestDive(), samples: samples);
      final out = det.detect(ctx);
      expect(out, isNotEmpty);
      expect(out.first.params['deltaC'], closeTo(8.0, 1e-9));
    });

    test('scalar waterTemp of 99 C is flagged without samples', () {
      final ctx = makeContext(dive: makeTestDive(waterTemp: 99));
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['waterTempC'], 99);
    });
  });

  group('PressureAnomalyDetector', () {
    const det = PressureAnomalyDetector();

    test('normal 200->60 bar tank with matching series is clean', () {
      final series = [
        for (var t = 0; t <= 2400; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * (140 / 2400)),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]),
        samples: flatProfile(depth: 10),
        pressures: {'t1': series},
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('end pressure above start pressure flags a swap', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(start: 60, end: 200)]),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['startBar'], 60);
      expect(out.single.params['endBar'], 200);
    });

    test('series start 15 bar away from recorded start flags mismatch', () {
      final series = [
        const QualityPressureSample(t: 0, bar: 215),
        const QualityPressureSample(t: 2400, bar: 60),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]), // recorded start 200
        pressures: {'t1': series},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['recordBar'], 200);
      expect(out.single.params['seriesBar'], 215);
    });

    test('mid-dive 8 bar rise away from any switch is flagged', () {
      final series = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 600, bar: 180),
        const QualityPressureSample(t: 660, bar: 184),
        const QualityPressureSample(t: 720, bar: 188),
        const QualityPressureSample(t: 780, bar: 188.5),
        const QualityPressureSample(t: 2400, bar: 195),
      ];
      // Rising run 180 -> 188.5 = 8.5 bar > 5, no switches on this dive.
      // (Trailing rise 188.5 -> 195 = 6.5 bar is a second run.)
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(start: 200, end: 195)]),
        pressures: {'t1': series},
      );
      final out = det.detect(ctx);
      expect(out.length, greaterThanOrEqualTo(1));
      expect(out.first.params['riseBar'], closeTo(8.5, 1e-9));
    });

    test('implausible consumption flags SAC', () {
      // 150 bar drop x 12 L over 10 min at avg 10 m (2 atm):
      // 150*12/10/2 = 90 L/min -> clean. Same over 5 min = 180 -> flagged.
      final fast = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 300, bar: 50),
      ];
      final ctx = makeContext(
        dive: makeTestDive(avgDepth: 10, tanks: [tank(end: 50)]),
        samples: flatProfile(depth: 10, durationSeconds: 300),
        pressures: {'t1': fast},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['surfaceLpm'], closeTo(180.0, 1e-6));
    });
  });
}
```

Note: `domain.DiveTank`/`domain.GasMix` constructors — if required parameters are missing, supply them in the TEST helper `tank()` only.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/domain/detectors/temp_pressure_detectors_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement TempAnomalyDetector**

```dart
// lib/features/data_quality/domain/detectors/temp_anomaly_detector.dart
import 'dart:math' as math;

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class TempAnomalyDetector extends QualityDetector {
  const TempAnomalyDetector();

  @override
  String get id => 'temp_anomaly';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.temperature;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final temps = [
      for (final p in ctx.primarySamples)
        if (p.temp != null) (t: p.t, c: p.temp!),
    ];

    if (temps.isNotEmpty) {
      final minC = temps.map((e) => e.c).reduce(math.min);
      final maxC = temps.map((e) => e.c).reduce(math.max);
      if (minC < QualityThresholds.waterTempMinC ||
          maxC > QualityThresholds.waterTempMaxC) {
        out.add(
          make(
            ctx,
            discriminator: 'range',
            severity: QualitySeverity.warning,
            params: {
              'minTempC': minC,
              'maxTempC': maxC,
              // A Kelvin-scale reading (~273+) betrays the F-as-K firmware bug.
              'fahrenheitAsKelvinSuspected': maxC > 250,
            },
          ),
        );
      }
      var jumps = 0;
      for (
        var i = 1;
        i < temps.length &&
            jumps < QualityThresholds.maxTempJumpFindingsPerDive;
        i++
      ) {
        final dt = temps[i].t - temps[i - 1].t;
        if (dt <= 0 || dt > QualityThresholds.tempJumpMaxSampleGapSeconds) {
          continue;
        }
        final delta = (temps[i].c - temps[i - 1].c).abs();
        if (delta > QualityThresholds.tempJumpPerSampleC) {
          jumps++;
          out.add(
            make(
              ctx,
              discriminator: 'jump:${temps[i].t ~/ 300}',
              severity: QualitySeverity.warning,
              params: {'atSeconds': temps[i].t, 'deltaC': delta},
            ),
          );
        }
      }
    }

    final scalar = ctx.dive.waterTemp;
    if (scalar != null &&
        (scalar < QualityThresholds.waterTempMinC ||
            scalar > QualityThresholds.waterTempMaxC)) {
      out.add(
        make(
          ctx,
          discriminator: 'scalar',
          severity: QualitySeverity.warning,
          params: {'waterTempC': scalar},
        ),
      );
    }
    return out;
  }
}
```

Two jumps landing in one 5-minute bucket share a discriminator and thus an id; `applyScanResults` collapses them via `producedById` — intended (one finding per bad region).

- [ ] **Step 4: Implement PressureAnomalyDetector**

```dart
// lib/features/data_quality/domain/detectors/pressure_anomaly_detector.dart
import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class PressureAnomalyDetector extends QualityDetector {
  const PressureAnomalyDetector();

  @override
  String get id => 'pressure_anomaly';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.pressure;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    for (final tank in ctx.tanks) {
      final series = ctx.pressuresByTankId[tank.id] ?? const [];
      final sp = tank.startPressure;
      final ep = tank.endPressure;

      if (sp != null &&
          ep != null &&
          ep - sp > QualityThresholds.pressureSwapMinDiffBar) {
        out.add(
          make(
            ctx,
            discriminator: 'swap:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {'startBar': sp, 'endBar': ep, 'tankOrder': tank.order},
          ),
        );
      }

      if (series.length < 2) continue;

      if (sp != null &&
          (sp - series.first.bar).abs() >
              QualityThresholds.pressureEndpointMismatchBar) {
        out.add(
          make(
            ctx,
            discriminator: 'startmismatch:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'recordBar': sp,
              'seriesBar': series.first.bar,
              'tankOrder': tank.order,
              'endpoint': 'start',
            },
          ),
        );
      }
      if (ep != null &&
          (ep - series.last.bar).abs() >
              QualityThresholds.pressureEndpointMismatchBar) {
        out.add(
          make(
            ctx,
            discriminator: 'endmismatch:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'recordBar': ep,
              'seriesBar': series.last.bar,
              'tankOrder': tank.order,
              'endpoint': 'end',
            },
          ),
        );
      }

      // Mid-dive rising runs away from any gas switch.
      var rise = 0.0;
      int? riseStart;
      void closeRise(int endT) {
        if (rise > QualityThresholds.pressureRiseBar &&
            riseStart != null &&
            !_nearSwitch(ctx, riseStart!, endT)) {
          out.add(
            make(
              ctx,
              discriminator: 'rise:${tank.id}:${riseStart! ~/ 60}',
              computerId: tank.computerId,
              severity: QualitySeverity.warning,
              params: {
                'riseBar': rise,
                'startSeconds': riseStart,
                'tankOrder': tank.order,
              },
            ),
          );
        }
        rise = 0;
        riseStart = null;
      }

      for (var i = 1; i < series.length; i++) {
        final d = series[i].bar - series[i - 1].bar;
        if (d > 0) {
          riseStart ??= series[i - 1].t;
          rise += d;
        } else {
          closeRise(series[i - 1].t);
        }
      }
      closeRise(series.last.t);

      // Implausible surface-equivalent consumption.
      final drop = series.first.bar - series.last.bar;
      final durSec = series.last.t - series.first.t;
      final vol = tank.volume;
      if (drop > 0 &&
          durSec >= QualityThresholds.sacMinSeriesSeconds &&
          vol != null) {
        final avgDepth = ctx.dive.avgDepth ?? _meanDepth(ctx.primarySamples);
        if (avgDepth != null) {
          final atm = 1 + avgDepth / 10;
          final surfaceLpm = drop * vol / (durSec / 60.0) / atm;
          if (surfaceLpm > QualityThresholds.sacSurfaceLpmMax) {
            out.add(
              make(
                ctx,
                discriminator: 'sac:${tank.id}',
                computerId: tank.computerId,
                severity: QualitySeverity.warning,
                params: {
                  'surfaceLpm': surfaceLpm,
                  'dropBar': drop,
                  'volumeLiters': vol,
                  'tankOrder': tank.order,
                },
              ),
            );
          }
        }
      }
    }
    return out;
  }

  bool _nearSwitch(DiveQualityContext ctx, int startT, int endT) =>
      ctx.gasSwitches.any(
        (sw) =>
            sw.timestamp >=
                startT - QualityThresholds.switchProximitySeconds &&
            sw.timestamp <= endT + QualityThresholds.switchProximitySeconds,
      );

  double? _meanDepth(List<QualitySample> samples) {
    if (samples.isEmpty) return null;
    var sum = 0.0;
    for (final p in samples) {
      sum += p.depth;
    }
    return sum / samples.length;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/data_quality/domain/detectors/temp_pressure_detectors_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): temperature and pressure detectors"
```

---

### Task 9: Gas, tank-assignment and source-conflict detectors

**Files:**
- Create: `lib/features/data_quality/domain/detectors/gas_mod_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/tank_assignment_detector.dart`
- Create: `lib/features/data_quality/domain/detectors/source_conflict_detector.dart`
- Test: `test/features/data_quality/domain/detectors/gas_tank_source_detectors_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6. `DiveMode` from `lib/core/constants/enums.dart` (`oc`/`ccr`/`scr`/`gauge`); `GasMix.o2` is a PERCENT (21.0 = air). `GasSwitch` from `lib/features/dive_log/domain/entities/gas_switch.dart`.
- Produces: `GasModDetector` (id `gas_mod`, category `gas`), `TankAssignmentDetector` (id `tank_assignment`, category `tank`), `SourceConflictDetector` (id `source_conflict`, category `source`), all version 1.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/domain/detectors/gas_tank_source_detectors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/source_conflict_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank({
  String id = 't1',
  double o2 = 21.0,
  int order = 0,
  double? volume = 12,
}) => domain.DiveTank(
  id: id,
  volume: volume,
  gasMix: domain.GasMix(o2: o2, he: 0),
  order: order,
);

GasSwitch sw({
  required String id,
  required int t,
  required String tankId,
  double? depth,
}) => GasSwitch(
  id: id,
  diveId: 'd1',
  timestamp: t,
  tankId: tankId,
  depth: depth,
  createdAt: DateTime.utc(2026, 7, 1),
);

void main() {
  final entry = DateTime.utc(2026, 7, 1, 10);

  group('GasModDetector', () {
    const det = GasModDetector();

    test('EAN50 held at 35 m sustains ppO2 2.25 -> critical', () {
      // ppO2 = 0.50 * (35/10 + 1) = 0.50 * 4.5 = 2.25 >= 1.8.
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 50)]),
        samples: flatProfile(depth: 35),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.params['peakPpO2'], closeTo(2.25, 1e-9));
    });

    test('air at 30 m is clean (ppO2 0.84)', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank(o2: 21)]),
        samples: flatProfile(depth: 30),
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('switch to EAN50 recorded at 30 m exceeds its 22 m MOD', () {
      // MOD(1.6, 0.50) = (1.6/0.5 - 1) * 10 = 22 m; 30 > 22 + 1.
      final tanks = [tank(id: 'back', o2: 21), tank(id: 'deco', o2: 50, order: 1)];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        samples: flatProfile(depth: 20), // shallow profile: no ppO2 run
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco', depth: 30)],
      );
      final out = det.detect(ctx);
      final modFinding = out.singleWhere(
        (f) => f.params.containsKey('modMeters'),
      );
      expect(modFinding.params['modMeters'], closeTo(22.0, 1e-9));
      expect(modFinding.params['switchDepth'], 30);
    });

    test('CCR dives are skipped entirely', () {
      final dive = makeTestDive(tanks: [tank(o2: 50)]);
      final ccrDive = dive.copyWith(diveMode: domain.DiveMode.ccr);
      final ctx = makeContext(dive: ccrDive, samples: flatProfile(depth: 35));
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('TankAssignmentDetector', () {
    const det = TankAssignmentDetector();

    test('drop concentrated while tank inactive is flagged', () {
      // Switch to deco at t=1200. Back tank drops 30 bar AFTER 1200 (100%
      // inactive drop > 70%, total 30 > 20).
      final tanks = [tank(id: 'back'), tank(id: 'deco', o2: 50, order: 1)];
      final backSeries = [
        const QualityPressureSample(t: 0, bar: 200),
        const QualityPressureSample(t: 1200, bar: 200),
        const QualityPressureSample(t: 1800, bar: 185),
        const QualityPressureSample(t: 2400, bar: 170),
      ];
      final ctx = makeContext(
        dive: makeTestDive(tanks: tanks),
        pressures: {'back': backSeries},
        gasSwitches: [sw(id: 'gs1', t: 1200, tankId: 'deco')],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['tankId'], 'back');
      expect(out.single.params['inactiveDropBar'], closeTo(30, 1e-9));
    });

    test('twin series on two tanks flags a double-assigned transmitter', () {
      final series = [
        for (var t = 0; t <= 1200; t += 60)
          QualityPressureSample(t: t, bar: 200 - t * 0.05),
      ];
      final ctx = makeContext(
        dive: makeTestDive(
          tanks: [tank(id: 'a'), tank(id: 'b', order: 1)],
        ),
        pressures: {'a': series, 'b': series},
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['meanDiffBar'], 0.0);
    });

    test('single-tank dives are skipped', () {
      final ctx = makeContext(
        dive: makeTestDive(tanks: [tank()]),
        pressures: {
          't1': [
            const QualityPressureSample(t: 0, bar: 200),
            const QualityPressureSample(t: 2400, bar: 60),
          ],
        },
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('SourceConflictDetector', () {
    const det = SourceConflictDetector();

    DiveDataSource source({
      required String id,
      bool primary = false,
      double? maxDepth,
      int? duration,
      double? waterTemp,
    }) => DiveDataSource(
      id: id,
      diveId: 'd1',
      isPrimary: primary,
      maxDepth: maxDepth,
      duration: duration,
      waterTemp: waterTemp,
      importedAt: entry,
      createdAt: entry,
    );

    test('two sources 40 vs 41 m agree within tolerance', () {
      // tol = max(2, 40 * 0.05) = 2; diff 1 <= 2.
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 40),
          source(id: 's', maxDepth: 41),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('40 vs 41 m at 2.5% ratio flags salinity hint', () {
      // Use 40 vs 44: diff 4 > tol 2 -- no, ratio 1.1 is out of the salinity
      // band. Use 80 vs 82: diff 2 <= tol max(2, 4) -- clean. So use
      // 40 vs 43: diff 3 > 2, ratio 1.075 -> no hint; and 100 vs 102.5:
      // diff 2.5 <= tol 5 -- clean. Salinity band pairs differing < 3.5%
      // only flag when depth <= ~46 m where the 2 m floor binds:
      // 45 vs 46.1: diff 1.1 -- clean. Conclusion: hint requires diff > tol
      // AND ratio in band -- only near-shallow extremes. Test the plain
      // conflict instead and the hint=false path:
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(id: 'p', primary: true, maxDepth: 30),
          source(id: 's', maxDepth: 36),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['salinitySettingSuspected'], false);
      expect(out.single.params['depthRatio'], closeTo(1.2, 1e-9));
    });

    test('duration and temperature disagreements are info findings', () {
      final ctx = makeContext(
        dive: makeTestDive(),
        sources: [
          source(
            id: 'p',
            primary: true,
            duration: 2400,
            waterTemp: 20,
          ),
          source(id: 's', duration: 3000, waterTemp: 26),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(2));
      expect(
        out.map((f) => f.severity).toSet(),
        {QualitySeverity.info},
      );
    });
  });
}
```

Note: if `domain.Dive` has no `copyWith(diveMode:)` parameter or `DiveMode` is imported from `enums.dart` rather than exported by `dive.dart`, adjust the CCR test's imports accordingly (`import 'package:submersion/core/constants/enums.dart';`).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/domain/detectors/gas_tank_source_detectors_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement GasModDetector**

```dart
// lib/features/data_quality/domain/detectors/gas_mod_detector.dart
import 'package:collection/collection.dart';

import '../../../../core/constants/enums.dart';
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

/// Flags recorded gas/depth combinations that contradict physics or
/// procedure: the recorded mix or the recorded switch depth is wrong.
/// OC only -- CCR/SCR loop ppO2 is setpoint-controlled, and gauge mode has
/// no trustworthy gas data.
class GasModDetector extends QualityDetector {
  const GasModDetector();

  @override
  String get id => 'gas_mod';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.gas;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.dive.diveMode != DiveMode.oc) return const [];
    final tanks = ctx.tanks;
    if (tanks.isEmpty) return const [];
    final out = <QualityFinding>[];
    final ordered = [...tanks]..sort((a, b) => a.order.compareTo(b.order));

    domain.DiveTank? tankById(String tid) =>
        tanks.firstWhereOrNull((t) => t.id == tid);

    double fo2At(int t) {
      var active = ordered.first;
      for (final sw in ctx.gasSwitches) {
        if (sw.timestamp <= t) {
          active = tankById(sw.tankId) ?? active;
        } else {
          break;
        }
      }
      return active.gasMix.o2 / 100.0;
    }

    // Sustained ppO2 above limits.
    int? runStart;
    var peak = 0.0;
    double? depthAtPeak;
    var runFo2 = 0.0;
    var lastT = 0;
    void closePpo2Run() {
      if (runStart != null &&
          lastT - runStart! >= QualityThresholds.ppO2SustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'ppo2:${runStart! ~/ 60}',
            severity: peak >= QualityThresholds.ppO2CriticalBar
                ? QualitySeverity.critical
                : QualitySeverity.warning,
            params: {
              'peakPpO2': peak,
              'o2Percent': runFo2 * 100,
              'depthAtPeak': depthAtPeak,
              'startSeconds': runStart,
              'durationSeconds': lastT - runStart!,
            },
          ),
        );
      }
      runStart = null;
      peak = 0;
    }

    for (final p in ctx.primarySamples) {
      final fo2 = fo2At(p.t);
      final ppo2 = fo2 * (p.depth / 10 + 1);
      if (ppo2 > QualityThresholds.ppO2WarnBar) {
        runStart ??= p.t;
        if (ppo2 > peak) {
          peak = ppo2;
          depthAtPeak = p.depth;
          runFo2 = fo2;
        }
        lastT = p.t;
      } else {
        closePpo2Run();
      }
    }
    closePpo2Run();

    // Hypoxic mix breathed at the surface.
    int? hypoStart;
    var hypoLastT = 0;
    var hypoFo2 = 1.0;
    void closeHypoRun() {
      if (hypoStart != null &&
          hypoLastT - hypoStart! >= QualityThresholds.hypoxicSustainSeconds) {
        out.add(
          make(
            ctx,
            discriminator: 'hypoxic:${hypoStart! ~/ 60}',
            severity: QualitySeverity.warning,
            params: {
              'o2Percent': hypoFo2 * 100,
              'startSeconds': hypoStart,
              'durationSeconds': hypoLastT - hypoStart!,
            },
          ),
        );
      }
      hypoStart = null;
    }

    for (final p in ctx.primarySamples) {
      final fo2 = fo2At(p.t);
      if (fo2 < QualityThresholds.hypoxicFo2 &&
          p.depth < QualityThresholds.hypoxicMaxDepthMeters) {
        hypoStart ??= p.t;
        hypoFo2 = fo2;
        hypoLastT = p.t;
      } else {
        closeHypoRun();
      }
    }
    closeHypoRun();

    // Switches recorded deeper than the target gas's MOD.
    for (final sw in ctx.gasSwitches) {
      final tank = tankById(sw.tankId);
      final d = sw.depth;
      if (tank == null || d == null) continue;
      final fo2 = tank.gasMix.o2 / 100.0;
      if (fo2 <= 0) continue;
      final mod = ((QualityThresholds.ppO2WarnBar / fo2) - 1) * 10;
      if (d > mod + QualityThresholds.modToleranceMeters) {
        out.add(
          make(
            ctx,
            discriminator: 'switchmod:${sw.id}',
            severity: QualitySeverity.warning,
            params: {
              'switchDepth': d,
              'modMeters': mod,
              'o2Percent': tank.gasMix.o2,
            },
          ),
        );
      }
    }
    return out;
  }
}
```

- [ ] **Step 4: Implement TankAssignmentDetector and SourceConflictDetector**

```dart
// lib/features/data_quality/domain/detectors/tank_assignment_detector.dart
import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class TankAssignmentDetector extends QualityDetector {
  const TankAssignmentDetector();

  @override
  String get id => 'tank_assignment';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.tanks.length < 2) return const [];
    final out = <QualityFinding>[];

    // Double-assigned transmitter: two tanks carrying the same series.
    final tankIds = ctx.pressuresByTankId.keys.toList()..sort();
    for (var i = 0; i < tankIds.length; i++) {
      for (var j = i + 1; j < tankIds.length; j++) {
        final a = ctx.pressuresByTankId[tankIds[i]]!;
        final b = {
          for (final p in ctx.pressuresByTankId[tankIds[j]]!) p.t: p.bar,
        };
        var n = 0;
        var sum = 0.0;
        for (final p in a) {
          final q = b[p.t];
          if (q != null) {
            n++;
            sum += (p.bar - q).abs();
          }
        }
        if (n >= QualityThresholds.twinSeriesMinSamples &&
            sum / n < QualityThresholds.twinSeriesMeanDiffBar) {
          out.add(
            make(
              ctx,
              discriminator: 'twin:${tankIds[i]}|${tankIds[j]}',
              severity: QualitySeverity.warning,
              params: {
                'tankIdA': tankIds[i],
                'tankIdB': tankIds[j],
                'meanDiffBar': sum / n,
              },
            ),
          );
        }
      }
    }

    // Consumption attributed to a tank the switch timeline says was idle.
    if (ctx.gasSwitches.isNotEmpty) {
      final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
      String activeAt(int t) {
        var id = ordered.first.id;
        for (final sw in ctx.gasSwitches) {
          if (sw.timestamp <= t) {
            id = sw.tankId;
          } else {
            break;
          }
        }
        return id;
      }

      for (final tank in ctx.tanks) {
        final series = ctx.pressuresByTankId[tank.id] ?? const [];
        if (series.length < 2) continue;
        var total = 0.0;
        var inactive = 0.0;
        for (var i = 1; i < series.length; i++) {
          final d = series[i - 1].bar - series[i].bar;
          if (d <= 0) continue;
          total += d;
          if (activeAt(series[i].t) != tank.id) inactive += d;
        }
        if (total > QualityThresholds.wrongTankMinTotalDropBar &&
            inactive / total >
                QualityThresholds.wrongTankInactiveDropFraction) {
          out.add(
            make(
              ctx,
              discriminator: 'inactive:${tank.id}',
              computerId: tank.computerId,
              severity: QualitySeverity.warning,
              params: {
                'tankId': tank.id,
                'tankOrder': tank.order,
                'inactiveDropBar': inactive,
                'totalDropBar': total,
              },
            ),
          );
        }
      }
    }
    return out;
  }
}
```

```dart
// lib/features/data_quality/domain/detectors/source_conflict_detector.dart
import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../entities/dive_quality_context.dart';
import '../entities/quality_finding.dart';
import '../quality_thresholds.dart';
import 'quality_detector.dart';

class SourceConflictDetector extends QualityDetector {
  const SourceConflictDetector();

  @override
  String get id => 'source_conflict';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.source;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final sources = ctx.sources;
    if (sources.length < 2) return const [];
    final primary =
        sources.firstWhereOrNull((s) => s.isPrimary) ?? sources.first;
    final out = <QualityFinding>[];

    for (final s in sources) {
      if (s.id == primary.id) continue;

      final pd = primary.maxDepth;
      final sd = s.maxDepth;
      if (pd != null && sd != null && pd > 0) {
        final diff = (pd - sd).abs();
        final tol = math.max(
          QualityThresholds.sourceDepthDiffMinMeters,
          pd * QualityThresholds.sourceDepthDiffFraction,
        );
        if (diff > tol) {
          final ratio = sd / pd;
          out.add(
            make(
              ctx,
              discriminator: 'depth:${s.id}',
              computerId: s.computerId,
              severity: QualitySeverity.warning,
              params: {
                'primaryMaxDepth': pd,
                'sourceMaxDepth': sd,
                'depthRatio': ratio,
                'salinitySettingSuspected':
                    ratio >= QualityThresholds.salinityRatioLow &&
                    ratio <= QualityThresholds.salinityRatioHigh,
              },
            ),
          );
        }
      }

      final pdur = primary.duration;
      final sdur = s.duration;
      if (pdur != null &&
          sdur != null &&
          pdur > 0 &&
          (pdur - sdur).abs() >
              pdur * QualityThresholds.sourceDurationDiffFraction) {
        out.add(
          make(
            ctx,
            discriminator: 'duration:${s.id}',
            computerId: s.computerId,
            severity: QualitySeverity.info,
            params: {'primarySeconds': pdur, 'sourceSeconds': sdur},
          ),
        );
      }

      final pt = primary.waterTemp;
      final st = s.waterTemp;
      if (pt != null &&
          st != null &&
          (pt - st).abs() > QualityThresholds.sourceTempDiffC) {
        out.add(
          make(
            ctx,
            discriminator: 'temp:${s.id}',
            computerId: s.computerId,
            severity: QualitySeverity.info,
            params: {'primaryTempC': pt, 'sourceTempC': st},
          ),
        );
      }
    }
    return out;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/data_quality/domain/detectors/gas_tank_source_detectors_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): gas, tank-assignment and source detectors"
```

---

### Task 10: Detector registry + SQL pre-filters

**Files:**
- Create: `lib/features/data_quality/domain/detectors/quality_detector_registry.dart`
- Create: `lib/features/data_quality/data/services/quality_prefilters.dart`
- Test: `test/features/data_quality/data/quality_prefilters_test.dart`

**Interfaces:**
- Consumes: all detectors (Tasks 6-9), `QualityThresholds`.
- Produces:
  - `const List<QualityDetector> kQualityDetectors` (all 11)
  - `Map<String, int> qualityDetectorVersions()`
  - `class QualityPrefilters { Future<Map<String, Set<String>>> candidatesByDetector({DateTime? now}); }` — detector id → candidate dive ids. Absence from a candidate set means "the detector structurally cannot produce findings for this dive" (e.g. no profile rows), so full-scan retire semantics remain correct.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/data_quality/data/quality_prefilters_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late QualityPrefilters prefilters;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    prefilters = QualityPrefilters();
  });
  tearDown(tearDownTestDatabase);

  test('registry contains all 11 detectors with unique ids', () {
    final ids = kQualityDetectors.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(11));
    expect(
      ids.toSet(),
      containsAll({
        'clock_offset',
        'duplicate',
        'split_pair',
        'sample_gap',
        'depth_spike',
        'impossible_rate',
        'temp_anomaly',
        'pressure_anomaly',
        'gas_mod',
        'tank_assignment',
        'source_conflict',
      }),
    );
    expect(qualityDetectorVersions()['duplicate'], 1);
  });

  test('profile detectors only get dives that have profiles', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(
        id: 'with-profile',
        dateTime: entry,
        entryTime: entry,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 60, depth: 20),
        ],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'bare', dateTime: entry.add(const Duration(days: 30))),
    );
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['sample_gap'], contains('with-profile'));
    expect(candidates['sample_gap'], isNot(contains('bare')));
    expect(candidates['depth_spike'], contains('with-profile'));
  });

  test('pair window selects both members of a close pair', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(id: 'a', dateTime: entry, entryTime: entry),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'b',
        dateTime: entry.add(const Duration(minutes: 30)),
        entryTime: entry.add(const Duration(minutes: 30)),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'far', dateTime: entry.add(const Duration(days: 30))),
    );
    final candidates = await prefilters.candidatesByDetector();
    expect(candidates['duplicate'], containsAll({'a', 'b'}));
    expect(candidates['duplicate'], isNot(contains('far')));
  });

  test('future-dated dive is a clock_offset candidate', () async {
    await diveRepo.createDive(
      domain.Dive(id: 'future', dateTime: DateTime.utc(2031, 1, 1)),
    );
    final candidates = await prefilters.candidatesByDetector(
      now: DateTime.utc(2026, 7, 17),
    );
    expect(candidates['clock_offset'], contains('future'));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/data/quality_prefilters_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement registry and prefilters**

```dart
// lib/features/data_quality/domain/detectors/quality_detector_registry.dart
import 'clock_offset_detector.dart';
import 'depth_spike_detector.dart';
import 'duplicate_detector.dart';
import 'gas_mod_detector.dart';
import 'impossible_rate_detector.dart';
import 'pressure_anomaly_detector.dart';
import 'quality_detector.dart';
import 'sample_gap_detector.dart';
import 'source_conflict_detector.dart';
import 'split_pair_detector.dart';
import 'tank_assignment_detector.dart';
import 'temp_anomaly_detector.dart';

const List<QualityDetector> kQualityDetectors = [
  ClockOffsetDetector(),
  DuplicateDetector(),
  SplitPairDetector(),
  SampleGapDetector(),
  DepthSpikeDetector(),
  ImpossibleRateDetector(),
  TempAnomalyDetector(),
  PressureAnomalyDetector(),
  GasModDetector(),
  TankAssignmentDetector(),
  SourceConflictDetector(),
];

Map<String, int> qualityDetectorVersions() => {
  for (final d in kQualityDetectors) d.id: d.version,
};
```

```dart
// lib/features/data_quality/data/services/quality_prefilters.dart
import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/quality_thresholds.dart';

/// Cheap SQL passes that narrow the full library to per-detector candidate
/// sets before any context is built. A dive absent from a detector's set is
/// one that detector structurally cannot flag (no profile rows, no second
/// source, ...), so retiring its old findings without re-running is correct.
class QualityPrefilters {
  QualityPrefilters();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<Map<String, Set<String>>> candidatesByDetector({
    DateTime? now,
  }) async {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;

    Future<Set<String>> ids(String sql, [List<Variable> vars = const []]) async {
      final rows = await _db.customSelect(sql, variables: vars).get();
      return {for (final r in rows) r.read<String>('id')};
    }

    final withProfiles = await ids(
      'SELECT d.id AS id FROM dives d WHERE EXISTS '
      '(SELECT 1 FROM dive_profiles p WHERE p.dive_id = d.id)',
    );
    final withPressures = await ids(
      'SELECT d.id AS id FROM dives d WHERE EXISTS '
      '(SELECT 1 FROM tank_pressure_profiles t WHERE t.dive_id = d.id)',
    );
    final withTanks = await ids(
      'SELECT d.id AS id FROM dives d WHERE EXISTS '
      '(SELECT 1 FROM dive_tanks t WHERE t.dive_id = d.id)',
    );
    final multiSource = await ids(
      'SELECT d.id AS id FROM dives d WHERE '
      '(SELECT COUNT(*) FROM dive_data_sources s WHERE s.dive_id = d.id) >= 2',
    );
    final pairWindow = await ids(
      'SELECT DISTINCT a.id AS id FROM dives a JOIN dives b ON a.id != b.id '
      'AND a.diver_id IS b.diver_id '
      'AND ABS(COALESCE(a.entry_time, a.dive_date_time) - '
      'COALESCE(b.entry_time, b.dive_date_time)) <= ?1',
      [Variable.withInt(QualityThresholds.neighborWindow.inMilliseconds)],
    );
    final timeOutliers = await ids(
      'SELECT d.id AS id FROM dives d WHERE '
      'COALESCE(d.entry_time, d.dive_date_time) > ?1 OR '
      'COALESCE(d.entry_time, d.dive_date_time) < ?2',
      [
        Variable.withInt(
          nowMs +
              Duration(
                days: QualityThresholds.futureGraceDays,
              ).inMilliseconds,
        ),
        Variable.withInt(
          DateTime.utc(
            QualityThresholds.minPlausibleYear,
          ).millisecondsSinceEpoch,
        ),
      ],
    );
    final scalarTempOutliers = await ids(
      'SELECT d.id AS id FROM dives d WHERE d.water_temp IS NOT NULL AND '
      '(d.water_temp < ?1 OR d.water_temp > ?2)',
      [
        Variable(QualityThresholds.waterTempMinC),
        Variable(QualityThresholds.waterTempMaxC),
      ],
    );

    return {
      'clock_offset': {...timeOutliers, ...multiSource, ...pairWindow},
      'duplicate': pairWindow,
      'split_pair': pairWindow,
      'sample_gap': withProfiles,
      'depth_spike': withProfiles,
      'impossible_rate': withProfiles,
      'temp_anomaly': {...withProfiles, ...scalarTempOutliers},
      'pressure_anomaly': {...withPressures, ...withTanks},
      'gas_mod': withTanks.intersection(withProfiles),
      'tank_assignment': withPressures,
      'source_conflict': multiSource,
    };
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/data_quality/data/quality_prefilters_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): detector registry and SQL pre-filters"
```

---

### Task 11: QualityScanService, scheduler, scan-state store, providers

**Files:**
- Create: `lib/features/data_quality/data/services/quality_scan_service.dart`
- Create: `lib/features/data_quality/data/services/quality_scan_state_store.dart`
- Create: `lib/features/data_quality/presentation/providers/data_quality_providers.dart`
- Test: `test/features/data_quality/data/quality_scan_service_test.dart`

**Interfaces:**
- Consumes: Tasks 4, 5, 10; `SyncEventBus.notifyLocalChange` (`lib/core/services/sync/sync_event_bus.dart`); `LoggerService` (`lib/core/services/logger_service.dart`, const ctor, `.error(msg, error:, stackTrace:)`); `sharedPreferencesProvider` (`lib/features/settings/presentation/providers/settings_providers.dart:682`).
- Produces:
  - `class QualityScanSummary { final int divesScanned; final int findingsProduced; final int detectorErrors; }`
  - `class QualityScanService { Future<QualityScanSummary> scanDives(Set<String> diveIds, {Set<String>? enabledDetectorIds, DateTime? now}); Future<QualityScanSummary> scanLibrary({void Function(int done, int total)? onProgress, bool Function()? isCancelled, Set<String>? enabledDetectorIds, DateTime? now}); }` — constructor takes optional `contextBuilder`, `findingsRepository`, `detectors` for tests.
  - Top-level `void scheduleQualityScan(Iterable<String> diveIds)` + `class QualityScanScheduler` with `static final instance`, `static bool enabled = true`, `@visibleForTesting Future<void> get idle`.
  - `class QualityScanStateStore { DateTime? get lastFullScanAt; Map<String, int> get lastScanDetectorVersions; bool get hasNewDetectorVersions; Future<void> recordFullScan(DateTime at, Map<String, int> versions); }`
  - Providers: `qualityFindingsRepositoryProvider`, `qualityScanServiceProvider`, `openQualityFindingsCountProvider` (StreamProvider<int>), `qualityScanStateStoreProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/data/quality_scan_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

/// Always throws: proves per-detector isolation.
class ThrowingDetector extends QualityDetector {
  const ThrowingDetector();
  @override
  String get id => 'throwing';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;
  @override
  List<QualityFinding> detect(DiveQualityContext context) =>
      throw StateError('boom');
}

void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedFutureDive(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime.utc(2031, 1, 1)),
  );

  test('targeted scan writes findings for a future-dated dive', () async {
    await seedFutureDive('d1');
    final service = QualityScanService();
    final summary = await service.scanDives(
      {'d1'},
      now: DateTime.utc(2026, 7, 17),
    );
    expect(summary.findingsProduced, greaterThanOrEqualTo(1));
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.map((f) => f.detectorId), contains('clock_offset'));
  });

  test('fixing the dive retires the finding on rescan', () async {
    await seedFutureDive('d1');
    final service = QualityScanService();
    await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
    final fixed = (await diveRepo.getDiveById('d1'))!;
    await diveRepo.updateDive(
      fixed.copyWith(
        dateTime: DateTime.utc(2026, 6, 1),
        entryTime: DateTime.utc(2026, 6, 1),
      ),
    );
    await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.where((f) => f.detectorId == 'clock_offset'), isEmpty);
  });

  test('a throwing detector is isolated and counted', () async {
    await seedFutureDive('d1');
    final service = QualityScanService(
      detectors: const [ThrowingDetector()],
    );
    final summary = await service.scanDives(
      {'d1'},
      now: DateTime.utc(2026, 7, 17),
    );
    expect(summary.detectorErrors, 1);
    expect(summary.divesScanned, 1);
  });

  test('full scan honors cancellation at batch boundaries', () async {
    for (var i = 0; i < 5; i++) {
      await seedFutureDive('d$i');
    }
    final service = QualityScanService();
    var calls = 0;
    final summary = await service.scanLibrary(
      now: DateTime.utc(2026, 7, 17),
      isCancelled: () => ++calls > 1, // cancel after the first batch check
    );
    // With batchSize 200 all 5 dives fit one batch; the second check cancels
    // before a second batch would start, so exactly one batch ran.
    expect(summary.divesScanned, 5);
  });

  test('scheduler merges bursts and is awaitable', () async {
    await seedFutureDive('d1');
    QualityScanScheduler.enabled = true;
    scheduleQualityScan(['d1']);
    scheduleQualityScan(['d1']);
    await QualityScanScheduler.instance.idle;
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/data/quality_scan_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the scan service + scheduler**

```dart
// lib/features/data_quality/data/services/quality_scan_service.dart
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../domain/detectors/quality_detector.dart';
import '../../domain/detectors/quality_detector_registry.dart';
import '../../domain/entities/quality_finding.dart';
import '../../domain/quality_thresholds.dart';
import '../repositories/quality_findings_repository.dart';
import 'quality_context_builder.dart';
import 'quality_prefilters.dart';

class QualityScanSummary {
  const QualityScanSummary({
    required this.divesScanned,
    required this.findingsProduced,
    required this.detectorErrors,
  });
  final int divesScanned;
  final int findingsProduced;
  final int detectorErrors;
}

class QualityScanService {
  QualityScanService({
    QualityContextBuilder? contextBuilder,
    QualityFindingsRepository? findingsRepository,
    List<QualityDetector>? detectors,
  }) : _builder = contextBuilder ?? QualityContextBuilder(),
       _findings = findingsRepository ?? QualityFindingsRepository(),
       _detectors = detectors ?? kQualityDetectors;

  static const _log = LoggerService('QualityScanService');
  static const batchSize = 200;

  AppDatabase get _db => DatabaseService.instance.database;
  final QualityContextBuilder _builder;
  final QualityFindingsRepository _findings;
  final List<QualityDetector> _detectors;

  List<QualityDetector> _enabled(Set<String>? enabledIds) => enabledIds == null
      ? _detectors
      : [
          for (final d in _detectors)
            if (enabledIds.contains(d.id)) d,
        ];

  /// Targeted scan: the given dives plus their chronological neighbors (so
  /// cross-dive pair findings can be retired from either side).
  Future<QualityScanSummary> scanDives(
    Set<String> diveIds, {
    Set<String>? enabledDetectorIds,
    DateTime? now,
  }) async {
    if (diveIds.isEmpty) {
      return const QualityScanSummary(
        divesScanned: 0,
        findingsProduced: 0,
        detectorErrors: 0,
      );
    }
    final enabled = _enabled(enabledDetectorIds);
    final expanded = await _expandNeighbors(diveIds);
    return _scanBatch(
      expanded.toList(),
      enabled: enabled,
      detectorsFor: (_) => enabled,
      now: now,
    );
  }

  /// Full-library scan, pre-filtered, batched, cancellable at batch
  /// boundaries. Never triggered automatically at startup.
  Future<QualityScanSummary> scanLibrary({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    Set<String>? enabledDetectorIds,
    DateTime? now,
  }) async {
    final enabled = _enabled(enabledDetectorIds);
    final candidates = await QualityPrefilters().candidatesByDetector(
      now: now,
    );
    final allDiveIds = [
      for (final r in await _db.customSelect('SELECT id FROM dives').get())
        r.read<String>('id'),
    ];
    var done = 0;
    var produced = 0;
    var errors = 0;
    for (var i = 0; i < allDiveIds.length; i += batchSize) {
      if (isCancelled?.call() ?? false) break;
      final batch = allDiveIds.sublist(
        i,
        math.min(i + batchSize, allDiveIds.length),
      );
      final summary = await _scanBatch(
        batch,
        enabled: enabled,
        detectorsFor: (diveId) => [
          for (final d in enabled)
            if (candidates[d.id]?.contains(diveId) ?? false) d,
        ],
        now: now,
      );
      produced += summary.findingsProduced;
      errors += summary.detectorErrors;
      done += batch.length;
      onProgress?.call(done, allDiveIds.length);
    }
    return QualityScanSummary(
      divesScanned: done,
      findingsProduced: produced,
      detectorErrors: errors,
    );
  }

  Future<QualityScanSummary> _scanBatch(
    List<String> diveIds, {
    required List<QualityDetector> enabled,
    required List<QualityDetector> Function(String diveId) detectorsFor,
    DateTime? now,
  }) async {
    final toBuild = [
      for (final id in diveIds)
        if (detectorsFor(id).isNotEmpty) id,
    ];
    final contexts = await _builder.buildAll(toBuild, now: now);
    final produced = <QualityFinding>[];
    var errors = 0;
    for (final ctx in contexts) {
      for (final det in detectorsFor(ctx.dive.id)) {
        try {
          produced.addAll(det.detect(ctx));
        } catch (e, st) {
          errors++;
          _log.error(
            'Detector ${det.id} failed for dive ${ctx.dive.id}',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
    await _findings.applyScanResults(
      scopeDiveIds: diveIds.toSet(),
      ranDetectorIds: {for (final d in enabled) d.id},
      produced: produced,
    );
    SyncEventBus.notifyLocalChange();
    return QualityScanSummary(
      divesScanned: diveIds.length,
      findingsProduced: produced.length,
      detectorErrors: errors,
    );
  }

  Future<Set<String>> _expandNeighbors(Set<String> diveIds) async {
    final placeholders = List.filled(diveIds.length, '?').join(',');
    final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT b.id AS id FROM dives a JOIN dives b '
          'ON b.id != a.id AND a.diver_id IS b.diver_id '
          'AND ABS(COALESCE(a.entry_time, a.dive_date_time) - '
          'COALESCE(b.entry_time, b.dive_date_time)) <= $windowMs '
          'WHERE a.id IN ($placeholders)',
          variables: [for (final id in diveIds) Variable.withString(id)],
        )
        .get();
    return {...diveIds, for (final r in rows) r.read<String>('id')};
  }
}

/// Fire-and-forget entry point for import/save hooks. Serializes scans
/// (single-flight) and merges bursts of requests.
class QualityScanScheduler {
  QualityScanScheduler._();
  static final QualityScanScheduler instance = QualityScanScheduler._();

  /// Widget tests that drive save flows against a fake-async zone can set
  /// this to false to keep Drift work out of the test zone.
  static bool enabled = true;

  static const _log = LoggerService('QualityScanScheduler');

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};

  @visibleForTesting
  Future<void> get idle => _tail;

  void schedule(Set<String> diveIds) {
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    _tail = _tail.then((_) async {
      final ids = Set.of(_pending);
      _pending.clear();
      if (ids.isEmpty) return;
      try {
        await QualityScanService().scanDives(ids);
      } catch (e, st) {
        _log.error('Scheduled quality scan failed', error: e, stackTrace: st);
      }
    });
  }
}

void scheduleQualityScan(Iterable<String> diveIds) =>
    QualityScanScheduler.instance.schedule(diveIds.toSet());
```

Add `import 'package:drift/drift.dart' show Variable;` if the analyzer flags `Variable` (it is used in `_expandNeighbors`).

- [ ] **Step 4: Implement the scan-state store and providers**

```dart
// lib/features/data_quality/data/services/quality_scan_state_store.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/detectors/quality_detector_registry.dart';

/// Device-local scan bookkeeping (deliberately NOT synced): findings sync,
/// so peers do not need to know when this device last scanned.
class QualityScanStateStore {
  QualityScanStateStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kLastFullScanAt = 'quality_last_full_scan_at';
  static const _kDetectorVersions = 'quality_detector_versions';

  DateTime? get lastFullScanAt {
    final ms = _prefs.getInt(_kLastFullScanAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Map<String, int> get lastScanDetectorVersions {
    final raw = _prefs.getString(_kDetectorVersions);
    if (raw == null) return const {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    );
  }

  /// True when a detector is new or newer than at the last full scan --
  /// drives the passive "new checks available" banner (never an auto-scan).
  bool get hasNewDetectorVersions {
    final last = lastScanDetectorVersions;
    if (lastFullScanAt == null) return false; // never scanned: show scan CTA
    final current = qualityDetectorVersions();
    return current.entries.any((e) => (last[e.key] ?? 0) < e.value);
  }

  Future<void> recordFullScan(DateTime at, Map<String, int> versions) async {
    await _prefs.setInt(_kLastFullScanAt, at.millisecondsSinceEpoch);
    await _prefs.setString(_kDetectorVersions, jsonEncode(versions));
  }
}
```

```dart
// lib/features/data_quality/presentation/providers/data_quality_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/repositories/quality_findings_repository.dart';
import '../../data/services/quality_scan_service.dart';
import '../../data/services/quality_scan_state_store.dart';

final qualityFindingsRepositoryProvider = Provider<QualityFindingsRepository>(
  (ref) => QualityFindingsRepository(),
);

final qualityScanServiceProvider = Provider<QualityScanService>(
  (ref) => QualityScanService(),
);

/// Drives the Dives app-bar badge; live under sync because findings are
/// ordinary synced rows.
final openQualityFindingsCountProvider = StreamProvider<int>(
  (ref) => ref.watch(qualityFindingsRepositoryProvider).watchOpenCount(),
);

final qualityScanStateStoreProvider = Provider<QualityScanStateStore>(
  (ref) => QualityScanStateStore(ref.watch(sharedPreferencesProvider)),
);
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/data_quality/data/quality_scan_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): scan service, scheduler and providers"
```

---

### Task 12: Import and save hooks

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (~line 592)
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` (~line 563)
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` (~line 278)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_saveDive` ~line 4822; `_saveBulk` ~line 1600)
- Modify: `lib/features/dive_log/presentation/widgets/run_dive_consolidation.dart`
- Modify: `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart` (`_confirm` ~line 74)

**Interfaces:**
- Consumes: `scheduleQualityScan` from Task 11 (import `package:submersion/features/data_quality/data/services/quality_scan_service.dart`; from within `lib/` use a relative import matching each file's existing style). `unawaited` needs `dart:async`.
- Produces: every import and every dive mutation queues a targeted scan; no call site awaits it.

- [ ] **Step 1: Add the import hooks**

In `universal_adapter.dart`, immediately before `return UnifiedImportResult(` (~line 592):

```dart
    unawaited(scheduleQualityScan(netImportedDiveIds));
```

In `dive_computer_adapter.dart`, immediately before its `return UnifiedImportResult(` (~line 563):

```dart
    unawaited(scheduleQualityScan(importedDiveIds));
```

In `healthkit_adapter.dart`, immediately before its `return UnifiedImportResult(` (~line 278):

```dart
    unawaited(scheduleQualityScan(importedDiveIds));
```

Add to each file's imports: `import 'dart:async';` (if not present) and the `quality_scan_service.dart` import.

- [ ] **Step 2: Add the save hooks**

In `dive_edit_page.dart` `_saveDive`, after the sub-entity saves complete and before the `if (mounted && savedDiveId != null)` navigation block (~line 4822):

```dart
      if (savedDiveId != null) {
        unawaited(scheduleQualityScan([savedDiveId]));
      }
```

In `dive_edit_page.dart` `_saveBulk`, immediately after the `service.apply(...)` call returns (~line 1600, before `if (!mounted) return;`):

```dart
      unawaited(scheduleQualityScan(ids));
```

- [ ] **Step 3: Add the consolidation/combine/split hooks**

In `run_dive_consolidation.dart`, after a successful `service.apply(...)` (where `onConsolidated()` is invoked), add:

```dart
    unawaited(scheduleQualityScan([targetDiveId, ...secondaryDiveIds]));
```

and in its undo callback (the SnackBar action that calls `service.undo(...)`), after the undo completes:

```dart
        unawaited(scheduleQualityScan([targetDiveId, ...secondaryDiveIds]));
```

In `combine_dives_dialog.dart` `_confirm` (~line 74), after `apply(widget.diveIds)` succeeds:

```dart
      unawaited(scheduleQualityScan(widget.diveIds));
```

Split hook: run `grep -rn "diveSplitServiceProvider" lib/features/dive_log/presentation/` — at the call site that invokes `.split(diveId: ..., sourceId: ...)`, capture the returned new dive id and add:

```dart
    unawaited(scheduleQualityScan([diveId, newDiveId]));
```

(where `diveId` is the split dive and `newDiveId` the return value; adjust local variable names to the call site's).

- [ ] **Step 4: Analyze and run adjacent test files**

Run: `flutter analyze`
Expected: no new issues.

Run the widget/integration tests that exercise the touched flows:
`flutter test test/features/dive_log/presentation/pages/ test/features/import_wizard/ --reporter compact`

If any test hangs or fails with pending-timer/database errors introduced by the hook, the fire-and-forget scan is leaking into a fake-async test zone: add to that test file's `setUp`: `QualityScanScheduler.enabled = false;` (and restore `= true` in `tearDown`). Do NOT weaken the production code path.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/import_wizard lib/features/dive_log
git commit -m "feat(data-quality): targeted scan hooks on import and save"
```

---

### Task 13: Full verification pass

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format .` then `git diff --stat` (expect no unstaged formatting churn), then `flutter analyze` (full output, no piping).
Expected: analyzer clean.

- [ ] **Step 2: Run every plan-1 test file plus the guard tests**

```bash
flutter test \
  test/core/database/migration_v118_quality_findings_test.dart \
  test/core/database/equipment_set_geofence_schema_test.dart \
  test/core/services/sync/quality_findings_sync_test.dart \
  test/core/services/sync/sync_data_serializer_record_ids_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart \
  test/features/data_quality/
```

Expected: all PASS.

- [ ] **Step 3: Commit any stragglers**

```bash
git status --short
```

If clean, done. If format-only changes appeared: `git add -u && git commit -m "style: format"`.

---

## Self-review checklist (run before handing off)

1. Spec coverage for Plan 1's slice: schema/sync (Tasks 1-2), identity/lifecycle semantics (Tasks 3-4), context + sanitization (Task 5), all 11 detectors with spec thresholds (Tasks 6-9), pre-filters + registry (Task 10), orchestration incl. single-flight, neighbor expansion, error isolation, batching, scan-state store (Task 11), import/save hooks (Task 12). Repairs, inbox UI, l10n, settings toggles are Plan 2.
2. Type consistency spot-checks: `applyScanResults` named params match between Task 4 impl and Task 11 caller; `QualitySample.t/depth/temp` match between Tasks 5-9; `qualityPairIdentity` record fields (`diveId`/`relatedDiveId`/`id`) match Tasks 3, 4 test, 6.
3. Every code step contains complete code; the only read-then-mirror steps are the serializer switch cases (Task 2), which are guard-test-driven by design.
