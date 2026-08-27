# Data Quality Assistant — Plan 2: Repairs & Inbox UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the repair layer (time shift, tank/pressure fixes, profile surgery, delegations to consolidation/merge/split/set-primary) and the review-inbox UI (route, badge, cards, scan flow, settings toggles, l10n).

**Architecture:** Repairs are thin: pure computation + delegation to existing persistence (`saveEditedProfile`/`restoreOriginalProfile`, `DiveConsolidationService`, `DiveMergeService` via the combine dialog, `DiveSplitService`, `setPrimaryDataSource`) plus three new set-based repo methods following the `bulkAppendNotes` sync discipline. The inbox is a chip-filtered list of collapsible finding cards; every user-visible string is an l10n key rendered from a finding's numeric `params`.

**Tech Stack:** Flutter/Dart, Drift, Riverpod, go_router, SharedPreferences, flutter gen-l10n.

**Prerequisite:** Plan 1 (`2026-07-17-data-quality-assistant-engine.md`) fully executed. **Spec:** `docs/superpowers/specs/2026-07-17-data-quality-assistant-design.md`.

## Global Constraints

- Same worktree/branch, commit, format, analyze, and test-invocation rules as Plan 1's Global Constraints — they all apply verbatim.
- Every new user-visible string: l10n key in `lib/l10n/arb/app_en.arb` PLUS translations in ALL 10 other locale files (`app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb`), then `flutter gen-l10n`. Translate; never copy the English.
- Anything displaying depth/pressure/temperature respects the diver's unit settings — format numbers through the app's existing unit formatting before interpolating into l10n String placeholders.
- Route ordering: `/dives/quality` MUST be registered before the `:diveId` catch-all (`app_router.dart:349`).
- Widget tests must NOT touch a real Drift database (fake-async deadlock); override the data-quality providers with fakes.
- `DiveTimeMigrationService.applyOffset` (`lib/features/settings/data/services/dive_time_migration_service.dart:67`) is prior art for time shifting but is sync-invisible (no updatedAt bump, no pending marks) — do NOT reuse it for repairs; the new `bulkShiftDiveTimes` below carries the sync discipline.

---

### Task 1: `bulkShiftDiveTimes` repo method + time-shift snapshot

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add after `bulkAppendNotes`, ~line 4300)
- Test: `test/features/data_quality/repairs/bulk_shift_dive_times_test.dart`

**Interfaces:**
- Consumes: existing `_db`, `_syncRepository` fields of `DiveRepository`.
- Produces:
  - `Future<void> bulkShiftDiveTimes(List<String> diveIds, Duration offset)` — shifts `dive_date_time`, non-null `entry_time`, non-null `exit_time`; forces `updated_at = now`; marks each dive pending. No transaction, no notify (caller owns both, same contract as `bulkUpdateFields`).
  - `Future<List<({String id, int diveDateTime, int? entryTime, int? exitTime})>> getDiveTimesSnapshot(List<String> diveIds)` — prior values for undo.
  - `Future<void> restoreDiveTimes(List<({String id, int diveDateTime, int? entryTime, int? exitTime})> snapshot)` — exact restore + pending marks.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/data_quality/repairs/bulk_shift_dive_times_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('shifts entry, exit and legacy dateTime by the offset', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(minutes: 40)),
      ),
    );
    await repo.bulkShiftDiveTimes(['d1'], const Duration(hours: -6));
    final shifted = (await repo.getDiveById('d1'))!;
    expect(shifted.entryTime, entry.subtract(const Duration(hours: 6)));
    expect(
      shifted.exitTime,
      entry.add(const Duration(minutes: 40)).subtract(const Duration(hours: 6)),
    );
  });

  test('null exitTime stays null', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(id: 'd2', dateTime: entry, entryTime: entry),
    );
    await repo.bulkShiftDiveTimes(['d2'], const Duration(hours: 2));
    final shifted = (await repo.getDiveById('d2'))!;
    expect(shifted.exitTime, isNull);
    expect(shifted.entryTime, entry.add(const Duration(hours: 2)));
  });

  test('snapshot + restore round-trips exactly', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await repo.createDive(
      domain.Dive(id: 'd3', dateTime: entry, entryTime: entry),
    );
    final snapshot = await repo.getDiveTimesSnapshot(['d3']);
    await repo.bulkShiftDiveTimes(['d3'], const Duration(hours: 5));
    await repo.restoreDiveTimes(snapshot);
    final restored = (await repo.getDiveById('d3'))!;
    expect(restored.entryTime, entry);
  });

  test('zero offset and empty ids are no-ops', () async {
    await repo.bulkShiftDiveTimes(const [], const Duration(hours: 1));
    await repo.bulkShiftDiveTimes(['missing'], Duration.zero);
    // No throw is the assertion.
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/repairs/bulk_shift_dive_times_test.dart`
Expected: FAIL (methods missing).

- [ ] **Step 3: Implement (after `bulkAppendNotes`, following its discipline verbatim)**

```dart
  /// Shift dive times of every dive in [diveIds] by [offset].
  /// Shifts dive_date_time always, entry_time/exit_time only when non-null.
  /// Forces `updated_at = now` and marks each dive pending. Does NOT open a
  /// transaction or notify sync -- the repair executor owns those.
  Future<void> bulkShiftDiveTimes(List<String> diveIds, Duration offset) async {
    if (diveIds.isEmpty || offset == Duration.zero) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ms = offset.inMilliseconds;
    final placeholders = List.filled(diveIds.length, '?').join(', ');
    await _db.customUpdate(
      'UPDATE dives SET '
      'dive_date_time = dive_date_time + ?, '
      'entry_time = CASE WHEN entry_time IS NULL THEN NULL '
      'ELSE entry_time + ? END, '
      'exit_time = CASE WHEN exit_time IS NULL THEN NULL '
      'ELSE exit_time + ? END, '
      'updated_at = ? '
      'WHERE id IN ($placeholders)',
      variables: [
        Variable.withInt(ms),
        Variable.withInt(ms),
        Variable.withInt(ms),
        Variable.withInt(now),
        ...diveIds.map(Variable.withString),
      ],
      updates: {_db.dives},
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Prior time columns for [diveIds]; feed to [restoreDiveTimes] for undo.
  Future<List<({String id, int diveDateTime, int? entryTime, int? exitTime})>>
  getDiveTimesSnapshot(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final rows = await (_db.select(
      _db.dives,
    )..where((t) => t.id.isIn(diveIds))).get();
    return [
      for (final r in rows)
        (
          id: r.id,
          diveDateTime: r.diveDateTime,
          entryTime: r.entryTime,
          exitTime: r.exitTime,
        ),
    ];
  }

  /// Exact-restore of a [getDiveTimesSnapshot] result (repair undo).
  Future<void> restoreDiveTimes(
    List<({String id, int diveDateTime, int? entryTime, int? exitTime})>
    snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in snapshot) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(s.id))).write(
        DivesCompanion(
          diveDateTime: Value(s.diveDateTime),
          entryTime: Value(s.entryTime),
          exitTime: Value(s.exitTime),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: s.id,
        localUpdatedAt: now,
      );
    }
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/data_quality/repairs/bulk_shift_dive_times_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  test/features/data_quality/repairs/bulk_shift_dive_times_test.dart
git commit -m "feat(data-quality): bulkShiftDiveTimes with snapshot restore"
```

---

### Task 2: Tank-pressure repairs (reassign/swap series, fix tank record)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` (add after `replaceTankPressures`, ~line 150)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (one narrow tank-record method)
- Test: `test/features/data_quality/repairs/tank_pressure_repairs_test.dart`

**Interfaces:**
- Consumes: existing `TankPressureRepository` fields (`_db`, `_syncRepository`, `_uuid` if present); `DiveRepository._db`/`_syncRepository`.
- Produces:
  - `TankPressureRepository.reassignTankPressureSeries({required String diveId, required String fromTankId, required String toTankId})`
  - `TankPressureRepository.swapTankPressureSeries({required String diveId, required String tankIdA, required String tankIdB})`
  - `DiveRepository.updateTankRecordPressures({required String diveId, required String tankId, double? startPressure, double? endPressure})` — writes only non-null args; marks `diveTanks` + `dives` pending.
- All three: no transaction/notify (executor owns), `updated_at` bump on the parent dive, pending marks per the consolidation-era rule that child rows ride on the parent dive.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/repairs/tank_pressure_repairs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed() async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: [
          domain.DiveTank(
            id: 'tA',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 0,
            startPressure: 60,
            endPressure: 200,
          ),
          domain.DiveTank(
            id: 'tB',
            gasMix: domain.GasMix(o2: 50, he: 0),
            order: 1,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [(timestamp: 0, pressure: 200.0), (timestamp: 600, pressure: 150.0)],
      'tB': [(timestamp: 0, pressure: 220.0)],
    });
  }

  test('swapTankPressureSeries exchanges the two series', () async {
    await seed();
    await tankRepo.swapTankPressureSeries(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tB']!.map((p) => p.pressure), [200.0, 150.0]);
    expect(byTank['tA']!.map((p) => p.pressure), [220.0]);
  });

  test('reassignTankPressureSeries moves one series', () async {
    await seed();
    await tankRepo.reassignTankPressureSeries(
      diveId: 'd1',
      fromTankId: 'tB',
      toTankId: 'tA',
    );
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank.containsKey('tB'), isFalse);
    expect(byTank['tA']!, hasLength(3));
  });

  test('updateTankRecordPressures swaps start/end on the record', () async {
    await seed();
    await diveRepo.updateTankRecordPressures(
      diveId: 'd1',
      tankId: 'tA',
      startPressure: 200,
      endPressure: 60,
    );
    final dive = (await diveRepo.getDiveById('d1'))!;
    final tA = dive.tanks.firstWhere((t) => t.id == 'tA');
    expect(tA.startPressure, 200);
    expect(tA.endPressure, 60);
  });
}
```

Note: `getTankPressuresForDive` returns the repository's own record/entity type — adjust the two `.pressure` assertions to its actual field name if different (it is declared at `tank_pressure_repository.dart:23`).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/repairs/tank_pressure_repairs_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the two series methods in TankPressureRepository**

```dart
  /// Move every pressure row of [fromTankId] onto [toTankId] (wrong-cylinder
  /// repair). No transaction/notify -- the repair executor owns those.
  Future<void> reassignTankPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tankPressureProfiles)..where(
          (t) => t.diveId.equals(diveId) & t.tankId.equals(fromTankId),
        ))
        .write(TankPressureProfilesCompanion(tankId: Value(toTankId)));
    await _touchDive(diveId, now);
  }

  /// Exchange the pressure series of two tanks (swapped-transmitter repair).
  Future<void> swapTankPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final aIds = [
      for (final r
          in await (_db.select(_db.tankPressureProfiles)..where(
                (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdA),
              ))
              .get())
        r.id,
    ];
    final bIds = [
      for (final r
          in await (_db.select(_db.tankPressureProfiles)..where(
                (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdB),
              ))
              .get())
        r.id,
    ];
    await (_db.update(_db.tankPressureProfiles)
          ..where((t) => t.id.isIn(aIds)))
        .write(TankPressureProfilesCompanion(tankId: Value(tankIdB)));
    await (_db.update(_db.tankPressureProfiles)
          ..where((t) => t.id.isIn(bIds)))
        .write(TankPressureProfilesCompanion(tankId: Value(tankIdA)));
    await _touchDive(diveId, now);
  }

  /// Child rows sync with the parent dive: bump + mark it pending.
  Future<void> _touchDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }
```

If the file's sync repository field has a different name (check its `deleteTankPressuresForDive` at line 113 for the exact identifier), use that name in `_touchDive`.

- [ ] **Step 4: Implement `updateTankRecordPressures` in DiveRepository (near `bulkShiftDiveTimes`)**

```dart
  /// Narrow tank-record fix for pressure repairs: writes only the provided
  /// pressures on one tank. Marks the tank row and parent dive pending.
  /// No transaction/notify -- the repair executor owns those.
  Future<void> updateTankRecordPressures({
    required String diveId,
    required String tankId,
    double? startPressure,
    double? endPressure,
  }) async {
    if (startPressure == null && endPressure == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankId))).write(
      DiveTanksCompanion(
        startPressure: startPressure != null
            ? Value(startPressure)
            : const Value.absent(),
        endPressure: endPressure != null
            ? Value(endPressure)
            : const Value.absent(),
      ),
    );
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankId,
      localUpdatedAt: now,
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }
```

- [ ] **Step 5: Run tests, commit**

Run: `flutter test test/features/data_quality/repairs/tank_pressure_repairs_test.dart`
Expected: PASS (3 tests).

```bash
dart format .
git add lib/features/dive_log test/features/data_quality
git commit -m "feat(data-quality): tank pressure series and record repairs"
```

---

### Task 3: ProfileRepairService — pure repair math + delegation

**Files:**
- Create: `lib/features/data_quality/data/services/profile_repair_service.dart`
- Modify: `lib/features/data_quality/domain/quality_thresholds.dart` (add `gapFillMaxSeconds`)
- Test: `test/features/data_quality/repairs/profile_repair_service_test.dart`

**Interfaces:**
- Consumes: `DiveRepository.saveEditedProfile(String diveId, List<domain.DiveProfilePoint>)` (`dive_repository_impl.dart:510` — demotes all rows to isPrimary=false, inserts edited rows isPrimary=true/computerId null, recomputes metrics, marks dive pending, notifies) and `restoreOriginalProfile(String diveId)` (`:726`); `getDiveProfile(String diveId)` (`:459`, primary rows); `bulkUpdateFields`.
- Produces:
  - Static pure functions over `List<domain.DiveProfilePoint>`: `despike`, `fillGaps`, `smoothTemperature`, `convertTemperature(points, {required bool kelvinScale})` — each returns a NEW list, never mutates.
  - Instance: `Future<List<domain.DiveProfilePoint>> currentPrimaryProfile(String diveId)`, `Future<void> applyEdited(String diveId, List<domain.DiveProfilePoint> edited)`, `Future<void> undo(String diveId)`, `Future<void> recomputeMetrics(String diveId)`.
- New threshold: `static const int gapFillMaxSeconds = 300;` in `QualityThresholds`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/data_quality/repairs/profile_repair_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

domain.DiveProfilePoint p(int t, double depth, {double? temp}) =>
    domain.DiveProfilePoint(timestamp: t, depth: depth, temperature: temp);

void main() {
  group('despike', () {
    test('replaces the single-sample spike with neighbor interpolation', () {
      // 20 -> 55 -> 20 at 10 s: 3.5 m/s both ways, opposite signs.
      final points = [p(0, 20), p(10, 20), p(20, 55), p(30, 20), p(40, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[2].depth, 20); // midpoint of neighbors 20 and 20
      expect(out.length, points.length);
      expect(points[2].depth, 55); // input untouched
    });

    test('leaves genuine fast-but-possible movement alone', () {
      // 2.5 m/s is below the 3.0 threshold.
      final points = [p(0, 20), p(10, 45), p(20, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[1].depth, 45);
    });
  });

  group('fillGaps', () {
    test('interpolates a 120 s hole at the median interval', () {
      // Median 10 s; hole 100->220 gets 11 synthetic samples at 110..210.
      final points = [
        for (var t = 0; t <= 100; t += 10) p(t, 20),
        for (var t = 220; t <= 300; t += 10) p(t, 30),
      ];
      final out = ProfileRepairService.fillGaps(points);
      final inserted = out.where((q) => q.timestamp > 100 && q.timestamp < 220);
      expect(inserted, hasLength(11));
      // Linear: at t=160 (halfway), depth = (20+30)/2 = 25.
      expect(
        inserted.firstWhere((q) => q.timestamp == 160).depth,
        closeTo(25.0, 1e-9),
      );
    });

    test('holes longer than gapFillMaxSeconds are left alone', () {
      final points = [p(0, 20), p(400, 20), p(410, 20)];
      final out = ProfileRepairService.fillGaps(points);
      expect(out.length, points.length);
    });
  });

  group('smoothTemperature', () {
    test('clamps a single-sample 8 C jump, depth untouched', () {
      final points = [
        p(0, 20, temp: 20),
        p(10, 20, temp: 12), // 8 C jump down and back
        p(20, 20, temp: 20),
      ];
      final out = ProfileRepairService.smoothTemperature(points);
      expect(out[1].temperature, closeTo(20.0, 1e-9));
      expect(out[1].depth, 20);
    });
  });

  group('convertTemperature', () {
    test('kelvin scale: 295.15 -> 22 C', () {
      final out = ProfileRepairService.convertTemperature(
        [p(0, 20, temp: 295.15)],
        kelvinScale: true,
      );
      expect(out.single.temperature, closeTo(22.0, 1e-9));
    });

    test('fahrenheit scale: 72 F -> 22.2 C', () {
      final out = ProfileRepairService.convertTemperature(
        [p(0, 20, temp: 72)],
        kelvinScale: false,
      );
      expect(out.single.temperature, closeTo((72 - 32) * 5 / 9, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/data_quality/repairs/profile_repair_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the threshold, then implement**

Add to `QualityThresholds`: `static const int gapFillMaxSeconds = 300;` (under the sample_gap group).

```dart
// lib/features/data_quality/data/services/profile_repair_service.dart
import 'dart:math' as math;

import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../../domain/quality_thresholds.dart';

/// Profile-sample surgery. The math is pure and static (unit-tested with
/// vectors); persistence delegates to the EXISTING edited-profile pattern:
/// saveEditedProfile demotes originals to isPrimary=false and inserts the
/// corrected series as the new primary -- computer data is never destroyed,
/// and restoreOriginalProfile is the ready-made undo.
class ProfileRepairService {
  ProfileRepairService({DiveRepository? diveRepository})
    : _diveRepo = diveRepository ?? DiveRepository();

  final DiveRepository _diveRepo;

  /// Replace single-sample spikes (QualityThresholds.spikeRateMetersPerSecond
  /// exceeded in both directions with opposite signs) by linear interpolation
  /// of the two neighbors.
  static List<domain.DiveProfilePoint> despike(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    for (var i = 1; i + 1 < out.length; i++) {
      final dt1 = out[i].timestamp - out[i - 1].timestamp;
      final dt2 = out[i + 1].timestamp - out[i].timestamp;
      if (dt1 <= 0 || dt2 <= 0) continue;
      final r1 = (out[i].depth - out[i - 1].depth) / dt1;
      final r2 = (out[i + 1].depth - out[i].depth) / dt2;
      if (r1.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r2.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r1.sign != r2.sign) {
        final span = out[i + 1].timestamp - out[i - 1].timestamp;
        final frac = span > 0
            ? (out[i].timestamp - out[i - 1].timestamp) / span
            : 0.5;
        out[i] = out[i].copyWith(
          depth: out[i - 1].depth + (out[i + 1].depth - out[i - 1].depth) * frac,
        );
      }
    }
    return out;
  }

  /// Fill holes up to QualityThresholds.gapFillMaxSeconds with linearly
  /// interpolated samples at the profile's median interval. Longer holes are
  /// honest data loss and stay.
  static List<domain.DiveProfilePoint> fillGaps(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final intervals = <int>[
      for (var i = 1; i < points.length; i++)
        if (points[i].timestamp > points[i - 1].timestamp)
          points[i].timestamp - points[i - 1].timestamp,
    ];
    if (intervals.isEmpty) return List.of(points);
    final sorted = [...intervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    final threshold = math.max(
      median * QualityThresholds.gapMedianFactor,
      QualityThresholds.gapMinSeconds.toDouble(),
    );
    final out = <domain.DiveProfilePoint>[];
    for (var i = 0; i < points.length; i++) {
      out.add(points[i]);
      if (i + 1 >= points.length) break;
      final gap = points[i + 1].timestamp - points[i].timestamp;
      if (gap <= threshold || gap > QualityThresholds.gapFillMaxSeconds) {
        continue;
      }
      for (
        var t = points[i].timestamp + median;
        t < points[i + 1].timestamp;
        t += median
      ) {
        final frac = (t - points[i].timestamp) / gap;
        out.add(
          domain.DiveProfilePoint(
            timestamp: t,
            depth:
                points[i].depth + (points[i + 1].depth - points[i].depth) * frac,
            temperature: _lerpNullable(
              points[i].temperature,
              points[i + 1].temperature,
              frac,
            ),
          ),
        );
      }
    }
    return out;
  }

  /// Clamp single-sample temperature jumps beyond
  /// QualityThresholds.tempJumpPerSampleC by neighbor interpolation.
  /// Touches ONLY the temperature channel.
  static List<domain.DiveProfilePoint> smoothTemperature(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    for (var i = 1; i + 1 < out.length; i++) {
      final a = out[i - 1].temperature;
      final b = out[i].temperature;
      final c = out[i + 1].temperature;
      if (a == null || b == null || c == null) continue;
      if ((b - a).abs() > QualityThresholds.tempJumpPerSampleC &&
          (c - b).abs() > QualityThresholds.tempJumpPerSampleC &&
          (b - a).sign != (c - b).sign) {
        out[i] = out[i].copyWith(temperature: (a + c) / 2);
      }
    }
    return out;
  }

  /// Repair wrong-unit temperature channels (e.g. the Fahrenheit-as-Kelvin
  /// firmware bug): kelvinScale converts K -> C, otherwise F -> C.
  static List<domain.DiveProfilePoint> convertTemperature(
    List<domain.DiveProfilePoint> points, {
    required bool kelvinScale,
  }) => [
    for (final p in points)
      p.temperature == null
          ? p
          : p.copyWith(
              temperature: kelvinScale
                  ? p.temperature! - 273.15
                  : (p.temperature! - 32) * 5 / 9,
            ),
  ];

  static double? _lerpNullable(double? a, double? b, double frac) =>
      (a == null || b == null) ? null : a + (b - a) * frac;

  Future<List<domain.DiveProfilePoint>> currentPrimaryProfile(String diveId) =>
      _diveRepo.getDiveProfile(diveId);

  Future<void> applyEdited(
    String diveId,
    List<domain.DiveProfilePoint> edited,
  ) => _diveRepo.saveEditedProfile(diveId, edited);

  Future<void> undo(String diveId) => _diveRepo.restoreOriginalProfile(diveId);

  /// Fix stored maxDepth/avgDepth from the primary profile (the maxdepth
  /// mismatch repair) without touching samples.
  Future<void> recomputeMetrics(String diveId) async {
    final dive = await _diveRepo.getDiveById(diveId);
    if (dive == null) return;
    final maxDepth = dive.calculateMaxDepthFromProfile();
    final avgDepth = dive.calculateAvgDepthFromProfile();
    if (maxDepth == null && avgDepth == null) return;
    await _diveRepo.bulkUpdateFields([
      diveId,
    ], DivesCompanion(
      maxDepth: maxDepth != null ? Value(maxDepth) : const Value.absent(),
      avgDepth: avgDepth != null ? Value(avgDepth) : const Value.absent(),
    ));
  }
}
```

Add the imports `bulkUpdateFields` needs (`package:drift/drift.dart show Value` and the database import for `DivesCompanion`) matching the file's style. If `DiveProfilePoint.copyWith` does not exist, add nothing to the entity — construct a new `domain.DiveProfilePoint(...)` copying fields instead. If `calculateMaxDepthFromProfile`'s actual signature differs (it lives at `dive.dart:468`), match it.

- [ ] **Step 4: Run tests, commit**

Run: `flutter test test/features/data_quality/repairs/profile_repair_service_test.dart`
Expected: PASS (7 tests).

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): profile repair math over edited-profile pattern"
```

---

### Task 4: Repair actions + executor

**Files:**
- Create: `lib/features/data_quality/domain/repairs/quality_repair_action.dart`
- Create: `lib/features/data_quality/data/services/quality_repair_executor.dart`
- Test: `test/features/data_quality/repairs/repair_mapping_test.dart`
- Test: `test/features/data_quality/repairs/quality_repair_executor_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 of this plan; Plan 1's `QualityFindingsRepository.setStatus`, `scheduleQualityScan`; `DiveRepository.setPrimaryDataSource({required String diveId, required String computerReadingId})` (`dive_repository_impl.dart:5263`); `SyncEventBus.notifyLocalChange`; `DatabaseService.instance.database`.
- Produces:
  - Sealed `QualityRepairAction` descriptors (data only, no behavior):
    `TimeShiftRepair(suggestedOffset, offerImportWide)`, `ConsolidateDuplicateRepair(targetDiveId, secondaryDiveId)`, `CombineSplitRepair(diveIds)`, `SetPrimarySourceRepair(diveId, sourceId)`, `SplitSourceRepair(diveId, sourceId)`, `DespikeRepair(diveId)`, `FillGapsRepair(diveId)`, `SmoothTemperatureRepair(diveId)`, `ConvertTemperatureRepair(diveId, kelvinScale)`, `RecomputeMetricsRepair(diveId)`, `SwapTankRecordPressuresRepair(diveId, tankId, startBar, endBar)`, `SetTankRecordFromSeriesRepair(diveId, tankId, seriesBar, endpoint)` — one endpoint only; a mismatch finding knows a single sensor value, and writing both endpoints would clobber the correct one, `SwapPressureSeriesRepair(diveId, tankIdA, tankIdB)`, `ReassignPressureSeriesRepair(diveId, fromTankId)`, `CompareSourcesRepair(diveId)`, `GoToDiveRepair(diveId)`.
  - `List<QualityRepairAction> repairOptionsFor(QualityFinding f)` — pure mapping from detectorId + discriminator-bearing `params` to actions.
  - `class QualityRepairExecutor` — executes DATA repairs (everything except `ConsolidateDuplicateRepair`, `CombineSplitRepair`, `CompareSourcesRepair`, `GoToDiveRepair`, which the UI routes to existing flows). Contract per execution: perform writes (transaction where multi-statement) → one `SyncEventBus.notifyLocalChange()` → `findingsRepo.setStatus(findingId, QualityStatus.resolved)` → `scheduleQualityScan(affectedDiveIds)` → return `Future<void> Function()? undo` (null when the op has no inverse).

Mapping table `repairOptionsFor` must implement (params keys are Plan 1's exact spellings; the discriminator is not stored, so branch on which params keys are present):

| detectorId + params signature | Actions (in order) |
|---|---|
| `clock_offset` with `offsetHours` | `TimeShiftRepair(Duration(hours: -offsetHours), offerImportWide: true)`, `GoToDiveRepair` |
| `clock_offset` with `entryTimeMs` (future/ancient) | `TimeShiftRepair(Duration.zero, offerImportWide: true)` (UI sheet lets the user type the offset), `GoToDiveRepair` |
| `clock_offset` with `overlapMinutes` | `GoToDiveRepair(diveId)`, `GoToDiveRepair(relatedDiveId)` |
| `duplicate` | `ConsolidateDuplicateRepair(diveId, relatedDiveId)`, `GoToDiveRepair(relatedDiveId)` |
| `split_pair` | `CombineSplitRepair([diveId, relatedDiveId])` |
| `sample_gap` | `FillGapsRepair`, `GoToDiveRepair` |
| `depth_spike` with `atSeconds` | `DespikeRepair`, `GoToDiveRepair` |
| `depth_spike` with `minDepth` (negative) | `DespikeRepair`, `GoToDiveRepair` |
| `depth_spike` with `storedMaxDepth` | `RecomputeMetricsRepair` |
| `impossible_rate` | `DespikeRepair`, `GoToDiveRepair` |
| `temp_anomaly` with `fahrenheitAsKelvinSuspected == true` | `ConvertTemperatureRepair(kelvinScale: true)`, `GoToDiveRepair` |
| `temp_anomaly` with `deltaC` | `SmoothTemperatureRepair`, `GoToDiveRepair` |
| `temp_anomaly` with `waterTempC` (scalar) | `GoToDiveRepair` |
| `temp_anomaly` other range | `ConvertTemperatureRepair(kelvinScale: false)`, `GoToDiveRepair` |
| `pressure_anomaly` with `startBar`+`endBar` (swap) | `SwapTankRecordPressuresRepair(diveId, tankIdFromParams, endBar, startBar)` |
| `pressure_anomaly` with `recordBar`+`seriesBar` | `SetTankRecordFromSeriesRepair(...)` |
| `pressure_anomaly` with `riseBar` or `surfaceLpm` | `GoToDiveRepair` |
| `gas_mod` (all) | `GoToDiveRepair` (judgment repair — navigate to the editor) |
| `tank_assignment` with `tankIdA`+`tankIdB` (twin) | `SwapPressureSeriesRepair`, `ReassignPressureSeriesRepair(fromTankId: tankIdA)` |
| `tank_assignment` with `tankId` (inactive) | `SwapPressureSeriesRepair(diveId, tankId, otherTankId?)` when exactly 2 tanks — else `ReassignPressureSeriesRepair(fromTankId: tankId)`; plus `GoToDiveRepair` |
| `source_conflict` | `SetPrimarySourceRepair(diveId, params['sourceId'] ?? finding.computerId-derived)`, `SplitSourceRepair`, `CompareSourcesRepair` |

NOTE: `pressure_anomaly` and `tank_assignment` findings need the tank id in `params` to build repairs. Plan 1's detectors emit `tankOrder`/`tankId` in most branches — where `tankId` is missing (`swap:`/`startmismatch:`/`endmismatch:`/`rise:`/`sac:` emit `tankOrder` only), FIRST extend those `params` maps in the Plan 1 detector files to also include `'tankId': tank.id`, and bump nothing (the detectors have not shipped). Same for `source_conflict`: its `depth:`/`duration:`/`temp:` params must include `'sourceId': s.id` (the `depth:` branch already has it; add to the other two). Update the affected Plan 1 detector tests' expected params accordingly.

- [ ] **Step 1: Write the failing mapping test**

```dart
// test/features/data_quality/repairs/repair_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';

QualityFinding f({
  required String detectorId,
  Map<String, Object?> params = const {},
  String? relatedDiveId,
}) => QualityFinding(
  id: 'f1',
  diveId: 'd1',
  relatedDiveId: relatedDiveId,
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: QualitySeverity.warning,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

void main() {
  test('clock offset maps to a pre-filled inverse time shift', () {
    final actions = repairOptionsFor(
      f(detectorId: 'clock_offset', params: {'offsetHours': 3}),
    );
    final shift = actions.whereType<TimeShiftRepair>().single;
    expect(shift.suggestedOffset, const Duration(hours: -3));
    expect(shift.offerImportWide, isTrue);
  });

  test('duplicate maps to consolidate with the pair', () {
    final actions = repairOptionsFor(
      f(detectorId: 'duplicate', relatedDiveId: 'd2'),
    );
    final c = actions.whereType<ConsolidateDuplicateRepair>().single;
    expect(c.targetDiveId, 'd1');
    expect(c.secondaryDiveId, 'd2');
  });

  test('split pair maps to combine', () {
    final actions = repairOptionsFor(
      f(detectorId: 'split_pair', relatedDiveId: 'd2'),
    );
    expect(
      actions.whereType<CombineSplitRepair>().single.diveIds,
      ['d1', 'd2'],
    );
  });

  test('maxdepth mismatch maps to recompute, not despike', () {
    final actions = repairOptionsFor(
      f(detectorId: 'depth_spike', params: {'storedMaxDepth': 40.0}),
    );
    expect(actions.whereType<RecomputeMetricsRepair>(), hasLength(1));
    expect(actions.whereType<DespikeRepair>(), isEmpty);
  });

  test('gas_mod gets navigation only (judgment repair)', () {
    final actions = repairOptionsFor(
      f(detectorId: 'gas_mod', params: {'peakPpO2': 2.25}),
    );
    expect(actions, hasLength(1));
    expect(actions.single, isA<GoToDiveRepair>());
  });

  test('every detector id yields at least one action', () {
    for (final id in [
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
    ]) {
      expect(
        repairOptionsFor(f(detectorId: id, relatedDiveId: 'd2')),
        isNotEmpty,
        reason: id,
      );
    }
  });
}
```

- [ ] **Step 2: Run to verify failure; implement the sealed actions + mapping**

Run: `flutter test test/features/data_quality/repairs/repair_mapping_test.dart` → FAIL, then implement `quality_repair_action.dart`: a sealed base `sealed class QualityRepairAction { const QualityRepairAction(); }`, one const subclass per row of the table (fields exactly as named in Interfaces), and `repairOptionsFor` as a `switch (f.detectorId)` implementing the table above, branching on `f.params.containsKey(...)` for multi-signal detectors. Re-run → PASS.

- [ ] **Step 3: Write the failing executor test**

```dart
// test/features/data_quality/repairs/quality_repair_executor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
  });
  tearDown(tearDownTestDatabase);

  Future<QualityFinding> seedFindingForDive(String diveId) async {
    final finding = QualityFinding(
      id: qualityFindingId(diveId: diveId, detectorId: 'clock_offset'),
      diveId: diveId,
      detectorId: 'clock_offset',
      detectorVersion: 1,
      category: QualityCategory.time,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {diveId},
      ranDetectorIds: {'clock_offset'},
      produced: [finding],
    );
    return finding;
  }

  test('shiftTimes shifts, resolves the finding, and undo restores', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(id: 'd1', dateTime: entry, entryTime: entry),
    );
    final finding = await seedFindingForDive('d1');

    final undo = await executor.shiftTimes(
      diveIds: ['d1'],
      offset: const Duration(hours: -6),
      findingId: finding.id,
    );

    expect(
      (await diveRepo.getDiveById('d1'))!.entryTime,
      entry.subtract(const Duration(hours: 6)),
    );
    final resolved = await findingsRepo.getFindings(diveId: 'd1');
    expect(resolved.single.status, QualityStatus.resolved);

    await undo!();
    expect((await diveRepo.getDiveById('d1'))!.entryTime, entry);
  });

  test('divesInSameImport falls back to just the dive without importId',
      () async {
    await diveRepo.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
    );
    expect(await executor.divesInSameImport('d1'), ['d1']);
  });
}
```

- [ ] **Step 4: Implement the executor**

```dart
// lib/features/data_quality/data/services/quality_repair_executor.dart
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/data/repositories/tank_pressure_repository.dart';
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../../domain/entities/quality_finding.dart';
import '../repositories/quality_findings_repository.dart';
import 'profile_repair_service.dart';
import 'quality_scan_service.dart';

typedef RepairUndo = Future<void> Function();

/// Executes data repairs with one uniform contract: write -> single notify ->
/// mark finding resolved -> queue a targeted rescan -> return an undo
/// closure (null when the operation has no inverse).
class QualityRepairExecutor {
  QualityRepairExecutor({
    DiveRepository? diveRepository,
    TankPressureRepository? tankPressureRepository,
    QualityFindingsRepository? findingsRepository,
    ProfileRepairService? profileRepairService,
  }) : _diveRepo = diveRepository ?? DiveRepository(),
       _tankRepo = tankPressureRepository ?? TankPressureRepository(),
       _findings = findingsRepository ?? QualityFindingsRepository(),
       _profiles = profileRepairService ?? ProfileRepairService();

  final DiveRepository _diveRepo;
  final TankPressureRepository _tankRepo;
  final QualityFindingsRepository _findings;
  final ProfileRepairService _profiles;
  AppDatabase get _db => DatabaseService.instance.database;

  Future<void> _finish(String findingId, Iterable<String> affected) async {
    await _findings.setStatus(findingId, QualityStatus.resolved);
    scheduleQualityScan(affected);
  }

  /// Dives sharing this dive's importId (for "shift the whole import").
  /// Falls back to just the dive when it has no importId.
  Future<List<String>> divesInSameImport(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT b.id AS id FROM dives a JOIN dives b '
          'ON a.import_id IS NOT NULL AND b.import_id = a.import_id '
          'WHERE a.id = ?1',
          variables: [Variable.withString(diveId)],
        )
        .get();
    final ids = [for (final r in rows) r.read<String>('id')];
    return ids.isEmpty ? [diveId] : ids;
  }

  Future<RepairUndo?> shiftTimes({
    required List<String> diveIds,
    required Duration offset,
    required String findingId,
  }) async {
    final snapshot = await _diveRepo.getDiveTimesSnapshot(diveIds);
    await _db.transaction(
      () => _diveRepo.bulkShiftDiveTimes(diveIds, offset),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, diveIds);
    return () async {
      await _db.transaction(() => _diveRepo.restoreDiveTimes(snapshot));
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan(diveIds);
    };
  }

  /// [compute] is one of ProfileRepairService's pure functions.
  Future<RepairUndo?> applyProfileRepair({
    required String diveId,
    required String findingId,
    required List<domain.DiveProfilePoint> Function(
      List<domain.DiveProfilePoint>,
    )
    compute,
  }) async {
    final current = await _profiles.currentPrimaryProfile(diveId);
    if (current.isEmpty) return null;
    // saveEditedProfile notifies internally.
    await _profiles.applyEdited(diveId, compute(current));
    await _finish(findingId, [diveId]);
    return () async {
      await _profiles.undo(diveId); // restoreOriginalProfile notifies
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> recomputeMetrics({
    required String diveId,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    if (dive == null) return null;
    final prior = (maxDepth: dive.maxDepth, avgDepth: dive.avgDepth);
    await _db.transaction(() => _profiles.recomputeMetrics(diveId));
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return () async {
      await _db.transaction(
        () => _diveRepo.bulkUpdateFields([
          diveId,
        ], DivesCompanion(
          maxDepth: Value(prior.maxDepth),
          avgDepth: Value(prior.avgDepth),
        )),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> swapTankRecordPressures({
    required String diveId,
    required String tankId,
    required double newStartBar,
    required double newEndBar,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _diveRepo.updateTankRecordPressures(
        diveId: diveId,
        tankId: tankId,
        startPressure: newStartBar,
        endPressure: newEndBar,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return () async {
      await _db.transaction(
        () => _diveRepo.updateTankRecordPressures(
          diveId: diveId,
          tankId: tankId,
          startPressure: newEndBar,
          endPressure: newStartBar,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  /// Set ONE endpoint of a tank record from its sensor series (the
  /// endpoint-mismatch repair). Never touches the other endpoint.
  Future<RepairUndo?> setTankRecordEndpoint({
    required String diveId,
    required String tankId,
    required String endpoint, // 'start' | 'end'
    required double bar,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    final tank = dive?.tanks.where((t) => t.id == tankId).firstOrNull;
    if (tank == null) return null;
    final prior = endpoint == 'start' ? tank.startPressure : tank.endPressure;
    Future<void> write(double? value) => _db.transaction(
      () => _diveRepo.updateTankRecordPressures(
        diveId: diveId,
        tankId: tankId,
        startPressure: endpoint == 'start' ? value : null,
        endPressure: endpoint == 'end' ? value : null,
      ),
    );
    await write(bar);
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    if (prior == null) return null;
    return () async {
      await write(prior);
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> swapPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _tankRepo.swapTankPressureSeries(
        diveId: diveId,
        tankIdA: tankIdA,
        tankIdB: tankIdB,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return () async {
      await _db.transaction(
        () => _tankRepo.swapTankPressureSeries(
          diveId: diveId,
          tankIdA: tankIdA,
          tankIdB: tankIdB,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> reassignPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _tankRepo.reassignTankPressureSeries(
        diveId: diveId,
        fromTankId: fromTankId,
        toTankId: toTankId,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return () async {
      await _db.transaction(
        () => _tankRepo.reassignTankPressureSeries(
          diveId: diveId,
          fromTankId: toTankId,
          toTankId: fromTankId,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> setPrimarySource({
    required String diveId,
    required String sourceId,
    required String findingId,
  }) async {
    await _diveRepo.setPrimaryDataSource(
      diveId: diveId,
      computerReadingId: sourceId,
    );
    await _finish(findingId, [diveId]);
    return null; // set-primary has its own UI affordance to set back
  }
}
```

Add `import 'package:drift/drift.dart' show Value, Variable;` (and adjust to the file style). If `TankPressureRepository`'s default constructor differs, match it.

- [ ] **Step 5: Extend Plan 1 detector params (tankId/sourceId), run all repair tests**

Make the Plan 1 param extensions described in the NOTE above (add `'tankId': tank.id` to every `pressure_anomaly` emit; `'sourceId': s.id` to `source_conflict`'s duration/temp emits; update their tests).

Run: `flutter test test/features/data_quality/`
Expected: PASS (all).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/data_quality test/features/data_quality
git commit -m "feat(data-quality): repair actions and executor"
```

---

### Task 5: Localization — all keys, all 11 locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Generated: `lib/l10n/arb/app_localizations*.dart` (via `flutter gen-l10n`)

**Interfaces:**
- Produces: every `dataQuality_*` key used by Tasks 6-8, accessible as `context.l10n.dataQuality_*`. All value placeholders that carry unit-bearing numbers are `String` type — call sites format through unit preferences BEFORE interpolating.

- [ ] **Step 1: Add the English keys**

Add to `app_en.arb` (placeholders declared in `@key` metadata per the file's existing style — mirror `diveLog_bulkEdit_appBarTitle` for int, `diveLog_edit_geofenceSuggestion_near` for String):

```jsonc
"dataQuality_inbox_title": "Data quality",
"dataQuality_badge_tooltip": "Data quality review",
"dataQuality_scan_start": "Scan library",
"dataQuality_scan_progress": "Checked {done} of {total} dives",          // int, int
"dataQuality_scan_cancel": "Cancel",
"dataQuality_scan_done": "{count, plural, =0{Scan complete - no new findings} =1{Scan complete - 1 item to review} other{Scan complete - {count} items to review}}",
"dataQuality_scan_errors": "{count} dives could not be fully checked",   // int
"dataQuality_lastScan": "Last scan: {when}",                             // String
"dataQuality_neverScanned": "Your logbook has not been scanned yet",
"dataQuality_empty_title": "All clear",
"dataQuality_empty_subtitle": "No data quality findings. Scan your library to check imported dives for problems.",
"dataQuality_banner_newChecks": "New quality checks are available",
"dataQuality_banner_rescan": "Rescan",
"dataQuality_action_dismiss": "Dismiss",
"dataQuality_action_dismissFiltered": "Dismiss all shown",
"dataQuality_action_goToDive": "Go to dive",
"dataQuality_action_undo": "Undo",
"dataQuality_repair_applied": "Repair applied",
"dataQuality_repair_failed": "Repair failed",
"dataQuality_chip_all": "All",
"dataQuality_chip_time": "Time",
"dataQuality_chip_profile": "Profile",
"dataQuality_chip_gas": "Gas",
"dataQuality_chip_tanks": "Tanks",
"dataQuality_chip_duplicates": "Duplicates",
"dataQuality_chip_sources": "Sources",
"dataQuality_detector_clock_offset": "Clock & timezone",
"dataQuality_detector_duplicate": "Likely duplicate",
"dataQuality_detector_split_pair": "Accidental split",
"dataQuality_detector_sample_gap": "Sample gaps",
"dataQuality_detector_depth_spike": "Depth spike",
"dataQuality_detector_impossible_rate": "Impossible rate",
"dataQuality_detector_temp_anomaly": "Temperature anomaly",
"dataQuality_detector_pressure_anomaly": "Pressure anomaly",
"dataQuality_detector_gas_mod": "Gas/MOD inconsistency",
"dataQuality_detector_tank_assignment": "Wrong cylinder",
"dataQuality_detector_source_conflict": "Conflicting sources",
"dataQuality_msg_clock_future": "Dive is dated in the future ({date})",                       // String
"dataQuality_msg_clock_ancient": "Dive is dated before 1950 ({date})",                        // String
"dataQuality_msg_clock_offset": "A source clock differs by {hours} hours",                    // int
"dataQuality_msg_clock_overlap": "Overlaps another dive by {minutes} min",                    // int
"dataQuality_msg_duplicate": "{percent}% match with a dive {minutes} min apart",              // int, int
"dataQuality_msg_split": "Same computer resumed after a {minutes} min surface interval",      // int
"dataQuality_msg_gap": "{count, plural, =1{1 gap in samples} other{{count} gaps in samples}}, longest {longest}",  // int, String
"dataQuality_msg_spike": "Depth spike to {depth} at {time}",                                  // String, String
"dataQuality_msg_negativeDepth": "{count} negative depth samples",                            // int
"dataQuality_msg_maxDepthMismatch": "Logged max depth {stored} but the profile shows {profile}", // String, String
"dataQuality_msg_rate": "Vertical rate of {rate} sustained for {seconds} s",                  // String, int
"dataQuality_msg_tempRange": "Water temperature outside the plausible range ({min} to {max})",// String, String
"dataQuality_msg_tempUnitBug": "Values look like a temperature unit bug",
"dataQuality_msg_tempJump": "Temperature jumped {delta} in one sample",                       // String
"dataQuality_msg_tempScalar": "Logged water temperature {temp} is implausible",               // String
"dataQuality_msg_pressureSwap": "End pressure {end} is above start pressure {start}",         // String, String
"dataQuality_msg_pressureEndpoint": "Tank record says {record} but the sensor series shows {series}", // String, String
"dataQuality_msg_pressureRise": "Pressure rose {rise} mid-dive with no gas switch",           // String
"dataQuality_msg_sac": "Implied surface consumption of {sac} is implausible",                 // String
"dataQuality_msg_ppo2": "ppO2 reached {ppo2} on {gas} at {depth}",                            // String, String, String
"dataQuality_msg_hypoxic": "Hypoxic mix ({gas}) shown in use at the surface",                 // String
"dataQuality_msg_switchMod": "Gas switch at {depth} is beyond that gas's MOD of {mod}",       // String, String
"dataQuality_msg_tankInactive": "This tank lost {drop} while the gas timeline says it was not in use", // String
"dataQuality_msg_twinTanks": "Two tanks carry a near-identical pressure series",
"dataQuality_msg_sourceDepth": "Sources disagree on max depth: {primary} vs {source}",        // String, String
"dataQuality_msg_salinityHint": "The consistent ratio suggests a salt/fresh water setting difference",
"dataQuality_msg_sourceDuration": "Sources disagree on dive duration",
"dataQuality_msg_sourceTemp": "Sources disagree on water temperature",
"dataQuality_repairLabel_shiftTime": "Shift time by {offset}",                                // String
"dataQuality_repairLabel_shiftImport": "Shift all dives from this import",
"dataQuality_repairLabel_consolidate": "Consolidate",
"dataQuality_repairLabel_combine": "Combine into one dive",
"dataQuality_repairLabel_despike": "Remove spike",
"dataQuality_repairLabel_fillGaps": "Fill gaps",
"dataQuality_repairLabel_smoothTemp": "Smooth temperature",
"dataQuality_repairLabel_convertTemp": "Convert temperature",
"dataQuality_repairLabel_recompute": "Recalculate from profile",
"dataQuality_repairLabel_swapPressures": "Swap start/end pressure",
"dataQuality_repairLabel_setFromSeries": "Use sensor values",
"dataQuality_repairLabel_swapSeries": "Swap tank series",
"dataQuality_repairLabel_reassignSeries": "Move series to another tank",
"dataQuality_repairLabel_setPrimary": "Make this source primary",
"dataQuality_repairLabel_split": "Split into separate dives",
"dataQuality_repairLabel_compare": "Compare profiles",
"dataQuality_settings_title": "Data quality",
"dataQuality_settings_subtitle": "Choose which checks run when scanning",
"dataQuality_summary_flagged": "{count, plural, =1{1 item flagged for review} other{{count} items flagged for review}}",
"dataQuality_summary_review": "Review",
"dataQuality_detail_chip": "Review"
```

- [ ] **Step 2: Translate into the 10 other locale files**

Add every key to `app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb` with real translations (never English copies). Only `app_en.arb` carries the `@key` placeholder metadata.

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n`
Run: `dart run tool/check_arb_consistency.dart` if that checker exists (`ls tool/ | grep -i arb` first); otherwise `flutter analyze` catches missing getters.
Expected: clean; `context.l10n.dataQuality_inbox_title` resolves.

- [ ] **Step 4: Commit**

```bash
dart format .
git add lib/l10n
git commit -m "feat(data-quality): l10n keys for inbox, findings and repairs"
```

---

### Task 6: Inbox page, finding cards, message builder, route

**Files:**
- Modify: `lib/features/data_quality/data/repositories/quality_findings_repository.dart` (add `watchFindings`, `watchOpenCountForDive`, `dismissAll`)
- Create: `lib/features/data_quality/presentation/providers/quality_inbox_providers.dart`
- Create: `lib/features/data_quality/presentation/widgets/quality_finding_message.dart`
- Create: `lib/features/data_quality/presentation/widgets/quality_finding_card.dart`
- Create: `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart`
- Modify: `lib/core/router/app_router.dart` (insert route between `compare-3d` close at line 348 and `:diveId` at line 349)
- Test: `test/features/data_quality/presentation/data_quality_inbox_page_test.dart`

**Interfaces:**
- Consumes: Plan 1 providers; Task 4 `repairOptionsFor` + `QualityRepairExecutor`; Task 5 l10n; `runDiveConsolidation` (`run_dive_consolidation.dart:16`), `showCombineDivesDialog` (`combine_dives_dialog.dart:666`), `diveConsolidationServiceProvider`/`diveSplitServiceProvider` (`dive_providers.dart:157/165`), `OverlaidProfileChart` (`overlaid_profile_chart.dart:23`), `DiveSparkline` (`dive_sparkline.dart:55`).
- Produces:
  - Repo: `Stream<List<QualityFinding>> watchFindings()`, `Stream<int> watchOpenCountForDive(String diveId)`, `Future<void> dismissAll(Iterable<String> ids)` (batch status update, pending marks, ONE notify).
  - Providers: `qualityFindingsStreamProvider` (StreamProvider), `qualityInboxChipProvider` (StateProvider<QualityChip>), `enum QualityChip { all, time, profile, gas, tanks, duplicates, sources }` with `Set<QualityCategory> categoriesFor(QualityChip)`, `diveOpenFindingsCountProvider` (StreamProvider.family<int, String>).
  - `QualityFindingMessage buildFindingMessage(AppLocalizations l10n, QualityFinding f, QualityUnitFormatters fmt)` where `class QualityUnitFormatters { final String Function(double meters) depth; final String Function(double bar) pressure; final String Function(double celsius) temperature; }` — call sites construct it from the app's unit-preference formatting.
  - `String detectorTitle(AppLocalizations l10n, String detectorId)` switch.
  - `DataQualityInboxPage` at route `/dives/quality`, name `dataQuality`.

Chip → category mapping (spec): all→(all); time→{time}; profile→{profile, temperature}; gas→{gas}; tanks→{tank, pressure}; duplicates→{duplicate}; sources→{source}.

- [ ] **Step 1: Add the repo methods (test via the existing repository test file)**

Append to `quality_findings_repository.dart`:

```dart
  Stream<List<QualityFinding>> watchFindings() {
    final query = _db.select(_db.qualityFindings)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => [for (final r in rows) _fromRow(r)]);
  }

  Stream<int> watchOpenCountForDive(String diveId) {
    final count = _db.qualityFindings.id.count();
    final query = _db.selectOnly(_db.qualityFindings)
      ..addColumns([count])
      ..where(
        _db.qualityFindings.status.equals(QualityStatus.open.name) &
            (_db.qualityFindings.diveId.equals(diveId) |
                _db.qualityFindings.relatedDiveId.equals(diveId)),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Bulk dismiss with ONE notify (fifty false positives, one tap).
  Future<void> dismissAll(Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.qualityFindings)..where((t) => t.id.isIn(idList)))
          .write(
            QualityFindingsCompanion(
              status: Value(QualityStatus.dismissed.name),
              updatedAt: Value(now),
            ),
          );
      for (final id in idList) {
        await _sync.markRecordPending(
          entityType: 'qualityFindings',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }
```

Add to `test/features/data_quality/data/quality_findings_repository_test.dart`:

```dart
  test('dismissAll dismisses every id with one call', () async {
    final a = finding();
    final b = finding(detectorId: 'depth_spike');
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap', 'depth_spike'},
      produced: [a, b],
    );
    await repo.dismissAll([a.id, b.id]);
    final all = await repo.getFindings();
    expect(all.map((f) => f.status).toSet(), {QualityStatus.dismissed});
  });

  test('watchOpenCountForDive matches diveId or relatedDiveId', () async {
    final pid = qualityPairIdentity(detectorId: 'duplicate', a: 'dX', b: 'dY');
    await repo.applyScanResults(
      scopeDiveIds: {'dX', 'dY'},
      ranDetectorIds: {'duplicate'},
      produced: [
        QualityFinding(
          id: pid.id,
          diveId: pid.diveId,
          relatedDiveId: pid.relatedDiveId,
          detectorId: 'duplicate',
          detectorVersion: 1,
          category: QualityCategory.duplicate,
          severity: QualitySeverity.warning,
          status: QualityStatus.open,
          createdAt: DateTime.utc(2026, 7, 17),
          updatedAt: DateTime.utc(2026, 7, 17),
        ),
      ],
    );
    expect(await repo.watchOpenCountForDive('dY').first, 1);
  });
```

Run: `flutter test test/features/data_quality/data/quality_findings_repository_test.dart` → PASS.

- [ ] **Step 2: Implement the message builder**

```dart
// lib/features/data_quality/presentation/widgets/quality_finding_message.dart
import '../../../../l10n/arb/app_localizations.dart';
import '../../domain/entities/quality_finding.dart';

class QualityUnitFormatters {
  const QualityUnitFormatters({
    required this.depth,
    required this.pressure,
    required this.temperature,
  });
  final String Function(double meters) depth;
  final String Function(double bar) pressure;
  final String Function(double celsius) temperature;
}

class QualityFindingMessage {
  const QualityFindingMessage({required this.title, required this.detail});
  final String title;
  final String detail;
}

String detectorTitle(AppLocalizations l10n, String detectorId) =>
    switch (detectorId) {
      'clock_offset' => l10n.dataQuality_detector_clock_offset,
      'duplicate' => l10n.dataQuality_detector_duplicate,
      'split_pair' => l10n.dataQuality_detector_split_pair,
      'sample_gap' => l10n.dataQuality_detector_sample_gap,
      'depth_spike' => l10n.dataQuality_detector_depth_spike,
      'impossible_rate' => l10n.dataQuality_detector_impossible_rate,
      'temp_anomaly' => l10n.dataQuality_detector_temp_anomaly,
      'pressure_anomaly' => l10n.dataQuality_detector_pressure_anomaly,
      'gas_mod' => l10n.dataQuality_detector_gas_mod,
      'tank_assignment' => l10n.dataQuality_detector_tank_assignment,
      'source_conflict' => l10n.dataQuality_detector_source_conflict,
      _ => detectorId,
    };

/// Renders a finding's numeric params into localized copy. Facts in, prose
/// out -- the row itself never stores prose, so a finding synced from a
/// metric German desktop renders correctly on an imperial English phone.
QualityFindingMessage buildFindingMessage(
  AppLocalizations l10n,
  QualityFinding f,
  QualityUnitFormatters fmt,
) {
  final p = f.params;
  double? d(String key) => (p[key] as num?)?.toDouble();
  int? i(String key) => (p[key] as num?)?.toInt();

  final title = detectorTitle(l10n, f.detectorId);
  String detail;
  switch (f.detectorId) {
    case 'clock_offset':
      if (p.containsKey('offsetHours')) {
        detail = l10n.dataQuality_msg_clock_offset(i('offsetHours') ?? 0);
      } else if (p.containsKey('overlapMinutes')) {
        detail = l10n.dataQuality_msg_clock_overlap(i('overlapMinutes') ?? 0);
      } else {
        final ms = i('entryTimeMs') ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(ms);
        detail = date.year < 1950
            ? l10n.dataQuality_msg_clock_ancient('$date')
            : l10n.dataQuality_msg_clock_future('$date');
      }
    case 'duplicate':
      detail = l10n.dataQuality_msg_duplicate(
        ((d('score') ?? 0) * 100).round(),
        i('timeDiffMinutes') ?? 0,
      );
    case 'split_pair':
      detail = l10n.dataQuality_msg_split(((i('gapSeconds') ?? 0) / 60).round());
    case 'sample_gap':
      detail = l10n.dataQuality_msg_gap(
        i('gapCount') ?? 0,
        '${i('longestGapSeconds') ?? 0} s',
      );
    case 'depth_spike':
      if (p.containsKey('storedMaxDepth')) {
        detail = l10n.dataQuality_msg_maxDepthMismatch(
          fmt.depth(d('storedMaxDepth') ?? 0),
          fmt.depth(d('profileMaxDepth') ?? 0),
        );
      } else if (p.containsKey('minDepth')) {
        detail = l10n.dataQuality_msg_negativeDepth(i('sampleCount') ?? 0);
      } else {
        final at = i('atSeconds') ?? 0;
        detail = l10n.dataQuality_msg_spike(
          fmt.depth(d('depth') ?? 0),
          '${at ~/ 60}:${(at % 60).toString().padLeft(2, '0')}',
        );
      }
    case 'impossible_rate':
      detail = l10n.dataQuality_msg_rate(
        '${fmt.depth(d('maxRateMetersPerMinute') ?? 0)}/min',
        i('durationSeconds') ?? 0,
      );
    case 'temp_anomaly':
      if (p.containsKey('deltaC')) {
        detail = l10n.dataQuality_msg_tempJump(fmt.temperature(d('deltaC') ?? 0));
      } else if (p.containsKey('waterTempC')) {
        detail = l10n.dataQuality_msg_tempScalar(
          fmt.temperature(d('waterTempC') ?? 0),
        );
      } else {
        detail = l10n.dataQuality_msg_tempRange(
          fmt.temperature(d('minTempC') ?? 0),
          fmt.temperature(d('maxTempC') ?? 0),
        );
        if (p['fahrenheitAsKelvinSuspected'] == true) {
          detail = '$detail ${l10n.dataQuality_msg_tempUnitBug}';
        }
      }
    case 'pressure_anomaly':
      if (p.containsKey('startBar') && p.containsKey('endBar')) {
        detail = l10n.dataQuality_msg_pressureSwap(
          fmt.pressure(d('endBar') ?? 0),
          fmt.pressure(d('startBar') ?? 0),
        );
      } else if (p.containsKey('recordBar')) {
        detail = l10n.dataQuality_msg_pressureEndpoint(
          fmt.pressure(d('recordBar') ?? 0),
          fmt.pressure(d('seriesBar') ?? 0),
        );
      } else if (p.containsKey('riseBar')) {
        detail = l10n.dataQuality_msg_pressureRise(fmt.pressure(d('riseBar') ?? 0));
      } else {
        detail = l10n.dataQuality_msg_sac('${(d('surfaceLpm') ?? 0).round()} L/min');
      }
    case 'gas_mod':
      if (p.containsKey('peakPpO2')) {
        detail = l10n.dataQuality_msg_ppo2(
          (d('peakPpO2') ?? 0).toStringAsFixed(2),
          'EAN${(d('o2Percent') ?? 21).round()}',
          fmt.depth(d('depthAtPeak') ?? 0),
        );
      } else if (p.containsKey('switchDepth')) {
        detail = l10n.dataQuality_msg_switchMod(
          fmt.depth(d('switchDepth') ?? 0),
          fmt.depth(d('modMeters') ?? 0),
        );
      } else {
        detail = l10n.dataQuality_msg_hypoxic(
          '${(d('o2Percent') ?? 0).round()}%',
        );
      }
    case 'tank_assignment':
      detail = p.containsKey('inactiveDropBar')
          ? l10n.dataQuality_msg_tankInactive(
              fmt.pressure(d('inactiveDropBar') ?? 0),
            )
          : l10n.dataQuality_msg_twinTanks;
    case 'source_conflict':
      if (p.containsKey('primaryMaxDepth')) {
        detail = l10n.dataQuality_msg_sourceDepth(
          fmt.depth(d('primaryMaxDepth') ?? 0),
          fmt.depth(d('sourceMaxDepth') ?? 0),
        );
        if (p['salinitySettingSuspected'] == true) {
          detail = '$detail ${l10n.dataQuality_msg_salinityHint}';
        }
      } else if (p.containsKey('primarySeconds')) {
        detail = l10n.dataQuality_msg_sourceDuration;
      } else {
        detail = l10n.dataQuality_msg_sourceTemp;
      }
    default:
      detail = '';
  }
  return QualityFindingMessage(title: title, detail: detail);
}
```

Unit formatting seam: the PAGE constructs `QualityUnitFormatters` once. Read `lib/core/utils/unit_formatter.dart` and use its depth/pressure/temperature functions with the diver's unit settings; if its API differs from a simple `(double) => String` shape, wrap it in closures here — this file must not import settings directly.

- [ ] **Step 3: Implement providers, card, page, route**

```dart
// lib/features/data_quality/presentation/providers/quality_inbox_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/quality_finding.dart';
import 'data_quality_providers.dart';

enum QualityChip { all, time, profile, gas, tanks, duplicates, sources }

Set<QualityCategory> categoriesFor(QualityChip chip) => switch (chip) {
  QualityChip.all => QualityCategory.values.toSet(),
  QualityChip.time => {QualityCategory.time},
  QualityChip.profile => {QualityCategory.profile, QualityCategory.temperature},
  QualityChip.gas => {QualityCategory.gas},
  QualityChip.tanks => {QualityCategory.tank, QualityCategory.pressure},
  QualityChip.duplicates => {QualityCategory.duplicate},
  QualityChip.sources => {QualityCategory.source},
};

final qualityFindingsStreamProvider = StreamProvider<List<QualityFinding>>(
  (ref) => ref.watch(qualityFindingsRepositoryProvider).watchFindings(),
);

final qualityInboxChipProvider = StateProvider<QualityChip>(
  (_) => QualityChip.all,
);

final diveOpenFindingsCountProvider = StreamProvider.family<int, String>(
  (ref, diveId) => ref
      .watch(qualityFindingsRepositoryProvider)
      .watchOpenCountForDive(diveId),
);
```

Card — collapsible, severity-tinted, actions from `repairOptionsFor`:

```dart
// lib/features/data_quality/presentation/widgets/quality_finding_card.dart
import 'package:flutter/material.dart';

import '../../../../l10n/l10n_extension.dart';
import '../../domain/entities/quality_finding.dart';
import '../../domain/repairs/quality_repair_action.dart';
import 'quality_finding_message.dart';

class QualityFindingCard extends StatefulWidget {
  const QualityFindingCard({
    super.key,
    required this.finding,
    required this.formatters,
    required this.onRepair,
    required this.onDismiss,
    required this.onGoToDive,
    this.evidence,
  });

  final QualityFinding finding;
  final QualityUnitFormatters formatters;
  final void Function(QualityRepairAction action) onRepair;
  final VoidCallback onDismiss;
  final void Function(String diveId) onGoToDive;

  /// Optional expanded-state evidence (before/after chart, sparklines...),
  /// injected by the page so this widget stays synchronous.
  final Widget? evidence;

  @override
  State<QualityFindingCard> createState() => _QualityFindingCardState();
}

class _QualityFindingCardState extends State<QualityFindingCard> {
  bool _expanded = false;

  IconData get _icon => switch (widget.finding.severity) {
    QualitySeverity.info => Icons.info_outline,
    QualitySeverity.warning => Icons.warning_amber_outlined,
    QualitySeverity.critical => Icons.error_outline,
  };

  Color _color(ColorScheme scheme) => switch (widget.finding.severity) {
    QualitySeverity.info => scheme.primary,
    QualitySeverity.warning => scheme.tertiary,
    QualitySeverity.critical => scheme.error,
  };

  String _repairLabel(BuildContext context, QualityRepairAction action) {
    final l10n = context.l10n;
    return switch (action) {
      TimeShiftRepair(:final suggestedOffset) =>
        suggestedOffset == Duration.zero
            ? l10n.dataQuality_repairLabel_shiftTime('...')
            : l10n.dataQuality_repairLabel_shiftTime(
                '${suggestedOffset.isNegative ? '' : '+'}'
                '${suggestedOffset.inHours} h',
              ),
      ConsolidateDuplicateRepair() => l10n.dataQuality_repairLabel_consolidate,
      CombineSplitRepair() => l10n.dataQuality_repairLabel_combine,
      SetPrimarySourceRepair() => l10n.dataQuality_repairLabel_setPrimary,
      SplitSourceRepair() => l10n.dataQuality_repairLabel_split,
      DespikeRepair() => l10n.dataQuality_repairLabel_despike,
      FillGapsRepair() => l10n.dataQuality_repairLabel_fillGaps,
      SmoothTemperatureRepair() => l10n.dataQuality_repairLabel_smoothTemp,
      ConvertTemperatureRepair() => l10n.dataQuality_repairLabel_convertTemp,
      RecomputeMetricsRepair() => l10n.dataQuality_repairLabel_recompute,
      SwapTankRecordPressuresRepair() =>
        l10n.dataQuality_repairLabel_swapPressures,
      SetTankRecordFromSeriesRepair() =>
        l10n.dataQuality_repairLabel_setFromSeries,
      SwapPressureSeriesRepair() => l10n.dataQuality_repairLabel_swapSeries,
      ReassignPressureSeriesRepair() =>
        l10n.dataQuality_repairLabel_reassignSeries,
      CompareSourcesRepair() => l10n.dataQuality_repairLabel_compare,
      GoToDiveRepair() => l10n.dataQuality_action_goToDive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = buildFindingMessage(
      context.l10n,
      widget.finding,
      widget.formatters,
    );
    final actions = repairOptionsFor(widget.finding);
    final primary = actions.isNotEmpty ? actions.first : null;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(_icon, color: _color(scheme)),
            title: Text(message.title),
            subtitle: Text(
              message.detail,
              maxLines: _expanded ? null : 1,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            trailing: primary == null
                ? null
                : FilledButton.tonal(
                    onPressed: () => widget.onRepair(primary),
                    child: Text(_repairLabel(context, primary)),
                  ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            if (widget.evidence != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: widget.evidence,
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                for (final action in actions.skip(primary != null ? 1 : 0))
                  TextButton(
                    onPressed: () => widget.onRepair(action),
                    child: Text(_repairLabel(context, action)),
                  ),
                TextButton(
                  onPressed: () =>
                      widget.onGoToDive(widget.finding.diveId),
                  child: Text(context.l10n.dataQuality_action_goToDive),
                ),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(context.l10n.dataQuality_action_dismiss),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

Page — chips, banner, grouped list, scan flow, action dispatch:

```dart
// lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/l10n_extension.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../dive_log/presentation/widgets/combine_dives_dialog.dart';
import '../../../dive_log/presentation/widgets/run_dive_consolidation.dart';
import '../../data/services/quality_repair_executor.dart';
import '../../data/services/quality_scan_service.dart';
import '../../domain/detectors/quality_detector_registry.dart';
import '../../domain/entities/quality_finding.dart';
import '../../domain/repairs/quality_repair_action.dart';
import '../providers/data_quality_providers.dart';
import '../providers/quality_inbox_providers.dart';
import '../widgets/quality_finding_card.dart';
import '../widgets/quality_finding_message.dart';

class DataQualityInboxPage extends ConsumerStatefulWidget {
  const DataQualityInboxPage({super.key, this.filterDiveId});

  /// When set (deep link from import summary / dive detail), only findings
  /// touching this dive are shown.
  final String? filterDiveId;

  @override
  ConsumerState<DataQualityInboxPage> createState() =>
      _DataQualityInboxPageState();
}

class _DataQualityInboxPageState extends ConsumerState<DataQualityInboxPage> {
  ({int done, int total})? _scanProgress;
  bool _cancelRequested = false;

  Future<void> _runFullScan() async {
    setState(() {
      _scanProgress = (done: 0, total: 0);
      _cancelRequested = false;
    });
    final service = ref.read(qualityScanServiceProvider);
    final store = ref.read(qualityScanStateStoreProvider);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await service.scanLibrary(
        onProgress: (done, total) {
          if (mounted) setState(() => _scanProgress = (done: done, total: total));
        },
        isCancelled: () => _cancelRequested,
      );
      await store.recordFullScan(DateTime.now(), qualityDetectorVersions());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.detectorErrors > 0
                ? '${l10n.dataQuality_scan_done(summary.findingsProduced)} '
                      '${l10n.dataQuality_scan_errors(summary.detectorErrors)}'
                : l10n.dataQuality_scan_done(summary.findingsProduced),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanProgress = null);
    }
  }

  Future<void> _runAction(QualityFinding f, QualityRepairAction action) async {
    final executor = QualityRepairExecutor();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> withUndoSnackbar(
      Future<RepairUndo?> Function() run,
    ) async {
      try {
        final undo = await run();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.dataQuality_repair_applied),
            action: undo == null
                ? null
                : SnackBarAction(
                    label: l10n.dataQuality_action_undo,
                    onPressed: () => unawaited(undo()),
                  ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('${l10n.dataQuality_repair_failed}: $e')),
        );
      }
    }

    switch (action) {
      case TimeShiftRepair(:final suggestedOffset, :final offerImportWide):
        final choice = await showTimeShiftSheet(
          context,
          suggestedOffset: suggestedOffset,
          offerImportWide: offerImportWide,
        );
        if (choice == null) return;
        final ids = choice.importWide
            ? await executor.divesInSameImport(f.diveId)
            : [f.diveId];
        await withUndoSnackbar(
          () => executor.shiftTimes(
            diveIds: ids,
            offset: choice.offset,
            findingId: f.id,
          ),
        );
      case ConsolidateDuplicateRepair(
        :final targetDiveId,
        :final secondaryDiveId,
      ):
        await runDiveConsolidation(
          context: context,
          service: ref.read(diveConsolidationServiceProvider),
          targetDiveId: targetDiveId,
          secondaryDiveIds: [secondaryDiveId],
          onConsolidated: () => scheduleQualityScan([targetDiveId]),
        );
      case CombineSplitRepair(:final diveIds):
        await showCombineDivesDialog(context: context, diveIds: diveIds);
        scheduleQualityScan(diveIds);
      case SetPrimarySourceRepair(:final diveId, :final sourceId):
        await withUndoSnackbar(
          () => executor.setPrimarySource(
            diveId: diveId,
            sourceId: sourceId,
            findingId: f.id,
          ),
        );
      case SplitSourceRepair(:final diveId, :final sourceId):
        final newId = await ref
            .read(diveSplitServiceProvider)
            .split(diveId: diveId, sourceId: sourceId);
        scheduleQualityScan([diveId, newId]);
      case DespikeRepair(:final diveId):
        await withUndoSnackbar(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.despike,
          ),
        );
      case FillGapsRepair(:final diveId):
        await withUndoSnackbar(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.fillGaps,
          ),
        );
      case SmoothTemperatureRepair(:final diveId):
        await withUndoSnackbar(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.smoothTemperature,
          ),
        );
      case ConvertTemperatureRepair(:final diveId, :final kelvinScale):
        await withUndoSnackbar(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: (points) => ProfileRepairService.convertTemperature(
              points,
              kelvinScale: kelvinScale,
            ),
          ),
        );
      case RecomputeMetricsRepair(:final diveId):
        await withUndoSnackbar(
          () => executor.recomputeMetrics(diveId: diveId, findingId: f.id),
        );
      case SwapTankRecordPressuresRepair(
        :final diveId,
        :final tankId,
        :final startBar,
        :final endBar,
      ):
        await withUndoSnackbar(
          () => executor.swapTankRecordPressures(
            diveId: diveId,
            tankId: tankId,
            newStartBar: startBar,
            newEndBar: endBar,
            findingId: f.id,
          ),
        );
      case SetTankRecordFromSeriesRepair(
        :final diveId,
        :final tankId,
        :final seriesBar,
        :final endpoint,
      ):
        await withUndoSnackbar(
          () => executor.setTankRecordEndpoint(
            diveId: diveId,
            tankId: tankId,
            endpoint: endpoint,
            bar: seriesBar,
            findingId: f.id,
          ),
        );
      case SwapPressureSeriesRepair(
        :final diveId,
        :final tankIdA,
        :final tankIdB,
      ):
        await withUndoSnackbar(
          () => executor.swapPressureSeries(
            diveId: diveId,
            tankIdA: tankIdA,
            tankIdB: tankIdB,
            findingId: f.id,
          ),
        );
      case ReassignPressureSeriesRepair(:final diveId, :final fromTankId):
        final toTankId = await showReassignTankPicker(
          context,
          ref,
          diveId: diveId,
          excludeTankId: fromTankId,
        );
        if (toTankId == null) return;
        await withUndoSnackbar(
          () => executor.reassignPressureSeries(
            diveId: diveId,
            fromTankId: fromTankId,
            toTankId: toTankId,
            findingId: f.id,
          ),
        );
      case CompareSourcesRepair(:final diveId):
      case GoToDiveRepair(:final diveId):
        context.push('/dives/$diveId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chip = ref.watch(qualityInboxChipProvider);
    final findingsAsync = ref.watch(qualityFindingsStreamProvider);
    final store = ref.watch(qualityScanStateStoreProvider);
    final formatters = buildQualityUnitFormatters(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataQuality_inbox_title),
        actions: [
          if (_scanProgress == null)
            IconButton(
              icon: const Icon(Icons.radar),
              tooltip: l10n.dataQuality_scan_start,
              onPressed: _runFullScan,
            ),
        ],
      ),
      body: findingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final open = [
            for (final f in all)
              if (f.status == QualityStatus.open &&
                  categoriesFor(chip).contains(f.category) &&
                  (widget.filterDiveId == null ||
                      f.diveId == widget.filterDiveId ||
                      f.relatedDiveId == widget.filterDiveId))
                f,
          ];
          return Column(
            children: [
              if (_scanProgress != null)
                _ScanProgressBar(
                  progress: _scanProgress!,
                  onCancel: () => _cancelRequested = true,
                ),
              if (_scanProgress == null && store.hasNewDetectorVersions)
                MaterialBanner(
                  content: Text(l10n.dataQuality_banner_newChecks),
                  actions: [
                    TextButton(
                      onPressed: _runFullScan,
                      child: Text(l10n.dataQuality_banner_rescan),
                    ),
                  ],
                ),
              _ChipRow(chip: chip, findings: all),
              Expanded(
                child: open.isEmpty
                    ? _EmptyState(
                        lastScanAt: store.lastFullScanAt,
                        onScan: _runFullScan,
                      )
                    : ListView(
                        children: [
                          for (final group in _groupByDive(open)) ...[
                            _DiveGroupHeader(diveId: group.diveId),
                            for (final f in group.findings)
                              QualityFindingCard(
                                finding: f,
                                formatters: formatters,
                                onRepair: (a) => _runAction(f, a),
                                onDismiss: () => ref
                                    .read(qualityFindingsRepositoryProvider)
                                    .setStatus(f.id, QualityStatus.dismissed),
                                onGoToDive: (id) => context.push('/dives/$id'),
                                evidence: buildFindingEvidence(ref, f),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

The page file also contains the small private widgets referenced above — implement each in the same file: `_ScanProgressBar` (LinearProgressIndicator + cancel button), `_ChipRow` (the FilterChip horizontal-scroll pattern from `log_filter_bar.dart:11-40`, one chip per `QualityChip` with a count badge computed from `findings`), `_EmptyState` (the `dive_list_content.dart:1482` Column pattern: icon `Icons.verified_outlined`, `dataQuality_empty_title`/`_subtitle`, last-scan line via `dataQuality_lastScan`/`dataQuality_neverScanned`, `FilledButton.icon` scan CTA), `_DiveGroupHeader` (watches `diveProvider(diveId)`, renders date · site · maxDepth line), `_groupByDive` (fold consecutive findings by `diveId` into `({String diveId, List<QualityFinding> findings})` records), `showTimeShiftSheet` (modal bottom sheet: hour/minute fields pre-filled from `suggestedOffset`, an import-wide `CheckboxListTile` shown when `offerImportWide`, returns `({Duration offset, bool importWide})?`), `showReassignTankPicker` (simple dialog listing the dive's other tanks by name/order), `buildQualityUnitFormatters(WidgetRef ref)` (constructs `QualityUnitFormatters` from the app's unit settings — see the Task-6 Step-2 seam note), and `buildFindingEvidence(WidgetRef ref, QualityFinding f)` (profile-repair findings: `OverlaidProfileChart(existingProfile: current, incomingProfile: preview)` where preview applies the matching `ProfileRepairService` function via a `FutureBuilder` on `diveProfileProvider(f.diveId)`; duplicate/split findings: two `DiveSparkline`s from both dives' profiles; everything else: null).

Route — insert in `app_router.dart` between `compare-3d` (line 348) and `:diveId` (line 349):

```dart
              GoRoute(
                path: 'quality',
                name: 'dataQuality',
                builder: (context, state) => DataQualityInboxPage(
                  filterDiveId: state.uri.queryParameters['dive'],
                ),
              ),
```

- [ ] **Step 4: Widget tests (fake repository, no Drift)**

```dart
// test/features/data_quality/presentation/data_quality_inbox_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class FakeFindingsRepository implements QualityFindingsRepository {
  FakeFindingsRepository(this.findings);
  List<QualityFinding> findings;
  final dismissed = <String>[];

  @override
  Stream<List<QualityFinding>> watchFindings() => Stream.value(findings);

  @override
  Future<void> setStatus(String id, QualityStatus status) async {
    dismissed.add(id);
  }

  // Members the page does not touch can throw.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

QualityFinding finding({String detectorId = 'sample_gap'}) => QualityFinding(
  id: 'f-$detectorId',
  diveId: 'd1',
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: QualitySeverity.info,
  status: QualityStatus.open,
  params: const {'gapCount': 2, 'longestGapSeconds': 90},
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

Widget wrap(FakeFindingsRepository repo) => ProviderScope(
  overrides: [
    qualityFindingsRepositoryProvider.overrideWithValue(repo),
    // Override any provider the page watches that would touch the DB or
    // prefs (qualityScanStateStoreProvider, diveProvider families) with
    // fakes as the page's actual watch-set requires.
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DataQualityInboxPage(),
  ),
);

void main() {
  testWidgets('empty inbox shows the all-clear state', (tester) async {
    await tester.pumpWidget(wrap(FakeFindingsRepository([])));
    await tester.pumpAndSettle();
    expect(find.text('All clear'), findsOneWidget);
  });

  testWidgets('a finding renders its detector title', (tester) async {
    await tester.pumpWidget(wrap(FakeFindingsRepository([finding()])));
    await tester.pumpAndSettle();
    expect(find.text('Sample gaps'), findsOneWidget);
  });

  testWidgets('dismiss marks the finding dismissed', (tester) async {
    final repo = FakeFindingsRepository([finding()]);
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); // expand
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(repo.dismissed, ['f-sample_gap']);
  });
}
```

`noSuchMethod` keeps the fake honest: any page dependency not explicitly faked throws in the test, telling you exactly which override to add (the group header's `diveProvider` watch and `qualityScanStateStoreProvider` will surface this way — override them with a stub `Dive` and a `QualityScanStateStore` backed by `SharedPreferences.setMockInitialValues({})`).

Run: `flutter test test/features/data_quality/presentation/data_quality_inbox_page_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/data_quality lib/core/router/app_router.dart test/features/data_quality
git commit -m "feat(data-quality): review inbox page, cards and route"
```

---

### Task 7: Badges & peripheral surfacing

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildAppBar` actions, insert after the sort IconButton at lines 771-775)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (`appBarActions` list at lines 204-225)
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` (`_SuccessView` children, after the skipped row ~line 197)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (header title Column, after line 947)

**Interfaces:**
- Consumes: `openQualityFindingsCountProvider`, `diveOpenFindingsCountProvider`, Task 5 l10n. All four host widgets are already Consumer-based (verify each has `ref` in scope; `import_summary_step`'s `_SuccessView` may need converting to `ConsumerWidget`).

- [ ] **Step 1: Dives app bar (both view modes)**

In `dive_list_content.dart` `_buildAppBar` actions (after the sort button):

```dart
        Consumer(
          builder: (context, ref, _) {
            final count =
                ref.watch(openQualityFindingsCountProvider).value ?? 0;
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.rule),
              ),
              tooltip: context.l10n.dataQuality_badge_tooltip,
              onPressed: () => context.push('/dives/quality'),
            );
          },
        ),
```

Add the same block to `dive_list_page.dart`'s `appBarActions` (with `size: 20` on the Icon to match its neighbors). Wrap in `Consumer` only where `ref` is not already available.

- [ ] **Step 2: Import summary line**

In `import_summary_step.dart` `_SuccessView`, after the skipped `_CountRow` (~line 197), add a Consumer-wrapped row shown when the imported dives have open findings:

```dart
            if (importedDiveIds.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final count = ref
                          .watch(
                            importedDivesOpenFindingsCountProvider(
                              importedDiveIds,
                            ),
                          )
                          .value ??
                      0;
                  if (count == 0) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.rule),
                    title: Text(
                      context.l10n.dataQuality_summary_flagged(count),
                    ),
                    trailing: TextButton(
                      onPressed: () => context.push(
                        '/dives/quality?dive=${importedDiveIds.first}',
                      ),
                      child: Text(context.l10n.dataQuality_summary_review),
                    ),
                  );
                },
              ),
```

Add to `quality_inbox_providers.dart` a small family provider for this (list-keyed families need a stable key — join the sorted ids):

```dart
final importedDivesOpenFindingsCountProvider =
    StreamProvider.family<int, List<String>>((ref, diveIds) {
      final repo = ref.watch(qualityFindingsRepositoryProvider);
      return repo.watchFindings().map(
        (all) => all
            .where(
              (f) =>
                  f.status == QualityStatus.open &&
                  (diveIds.contains(f.diveId) ||
                      diveIds.contains(f.relatedDiveId)),
            )
            .length,
      );
    });
```

(A single dive is linked; the inbox's `filterDiveId` shows that dive's findings. Multi-dive imports link unfiltered — acceptable v1.)

- [ ] **Step 3: Dive detail chip**

In `dive_detail_page.dart`, in the header title Column after the title Text (line 947):

```dart
                    Consumer(
                      builder: (context, ref, _) {
                        final count = ref
                                .watch(
                                  diveOpenFindingsCountProvider(dive.id),
                                )
                                .value ??
                            0;
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ActionChip(
                            avatar: Icon(
                              Icons.rule,
                              size: 16,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            label: Text(
                              '${context.l10n.dataQuality_detail_chip} ($count)',
                            ),
                            onPressed: () => context.push(
                              '/dives/quality?dive=${dive.id}',
                            ),
                          ),
                        );
                      },
                    ),
```

- [ ] **Step 4: Analyze, run the touched widget test files, commit**

Run: `flutter analyze`
Run: `flutter test test/features/import_wizard/ test/features/dive_log/presentation/ --reporter compact`
Expected: no new failures (apply the `QualityScanScheduler.enabled = false` contingency from Plan 1 Task 12 where a pre-existing test file starts flaking).

```bash
dart format .
git add lib/features
git commit -m "feat(data-quality): badges, import summary line, detail chip"
```

---

### Task 8: Settings — per-detector toggles

**Files:**
- Create: `lib/features/data_quality/presentation/providers/quality_detector_toggles.dart`
- Create: `lib/features/data_quality/presentation/pages/data_quality_settings_page.dart`
- Modify: `lib/core/router/app_router.dart` (settings child route, near line 811)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (section tile + `_navigateToSection` case, ~line 339)
- Modify: `lib/features/data_quality/data/services/quality_scan_service.dart` (respect the static disabled set)
- Test: `test/features/data_quality/presentation/quality_detector_toggles_test.dart`

**Interfaces:**
- Produces:
  - `class QualityDetectorToggles { static Set<String> disabled; }` — process-wide mirror read by `QualityScanService._enabled(null)`, so the fire-and-forget scheduler (no ref) honors toggles.
  - `qualityDetectorTogglesProvider` — `StateNotifierProvider<QualityDetectorTogglesNotifier, Set<String>>` (the DISABLED ids), persisted in SharedPreferences under key `quality_disabled_detectors` (StringList), seeding the static mirror at construction (follow `debug_mode_provider.dart` structurally).
  - `DataQualitySettingsPage` — `SwitchListTile` per `kQualityDetectors` entry, titled via `detectorTitle`, following `default_visible_metrics_page.dart`'s scaffold pattern; route `/settings/data-quality`.
- Semantics (spec): toggles gate DETECTION only — a disabled detector's existing findings are untouched (Plan 1's applyScanResults already guarantees this because a disabled detector is not in `ranDetectorIds`).

- [ ] **Step 1: Failing test for the notifier + service wiring**

```dart
// test/features/data_quality/presentation/quality_detector_toggles_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';

void main() {
  test('disabling persists and mirrors to the static set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = QualityDetectorTogglesNotifier(prefs);
    await notifier.setEnabled('impossible_rate', false);
    expect(notifier.state, contains('impossible_rate'));
    expect(QualityDetectorToggles.disabled, contains('impossible_rate'));
    expect(
      prefs.getStringList('quality_disabled_detectors'),
      contains('impossible_rate'),
    );
    await notifier.setEnabled('impossible_rate', true);
    expect(QualityDetectorToggles.disabled, isNot(contains('impossible_rate')));
  });
}
```

- [ ] **Step 2: Implement notifier + static mirror; wire the service**

Implement `quality_detector_toggles.dart` per the interface (constructor seeds `state` and `QualityDetectorToggles.disabled` from prefs; `setEnabled` updates state, static, and prefs). In `quality_scan_service.dart` change `_enabled`:

```dart
  List<QualityDetector> _enabled(Set<String>? enabledIds) {
    if (enabledIds != null) {
      return [
        for (final d in _detectors)
          if (enabledIds.contains(d.id)) d,
      ];
    }
    return [
      for (final d in _detectors)
        if (!QualityDetectorToggles.disabled.contains(d.id)) d,
    ];
  }
```

Add a service test to `quality_scan_service_test.dart`: disable `clock_offset` via `QualityDetectorToggles.disabled = {'clock_offset'}`, scan the future-dated dive, expect no clock finding; reset the static in `tearDown`.

- [ ] **Step 3: Page + routes + settings tile**

`DataQualitySettingsPage`: `ConsumerWidget`, `Scaffold(appBar: AppBar(title: Text(l10n.dataQuality_settings_title)), body: ListView)` with one `SwitchListTile(title: Text(detectorTitle(l10n, d.id)), value: !disabled.contains(d.id), onChanged: (v) => notifier.setEnabled(d.id, v))` per `kQualityDetectors`. Register the route next to `storage` (`app_router.dart:811`):

```dart
              GoRoute(
                path: 'data-quality',
                name: 'dataQualitySettings',
                builder: (context, state) => const DataQualitySettingsPage(),
              ),
```

Add a settings tile + `case 'dataQuality': context.push('/settings/data-quality');` in `settings_page.dart` following the storage entry's pattern.

- [ ] **Step 4: Run, commit**

Run: `flutter test test/features/data_quality/presentation/quality_detector_toggles_test.dart test/features/data_quality/data/quality_scan_service_test.dart`
Expected: PASS.

```bash
dart format .
git add lib/features lib/core/router test/features/data_quality
git commit -m "feat(data-quality): per-detector settings toggles"
```

---

### Task 9: Full verification pass

- [ ] **Step 1:** `dart format .` → no churn; `flutter analyze` (full output) → clean.
- [ ] **Step 2:** `flutter test test/features/data_quality/` → all PASS.
- [ ] **Step 3:** Guard + adjacent suites:

```bash
flutter test \
  test/core/services/sync/quality_findings_sync_test.dart \
  test/core/services/sync/sync_data_serializer_record_ids_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart \
  test/core/database/migration_v118_quality_findings_test.dart \
  test/features/import_wizard/ \
  test/features/dive_log/presentation/pages/
```

Expected: all PASS.

- [ ] **Step 4:** `git status --short` clean (commit format-only stragglers if any).
- [ ] **Step 5:** Note for the PR checklist (do NOT run now): interactive macOS smoke test — import a file with known-bad data, watch the badge appear, walk one repair + undo, verify sync of a dismissal across two devices.

---

## Self-review checklist (run before handing off)

1. Spec coverage for Plan 2's slice: every repair row of the spec's table maps to Task 4's mapping (gas_mod deliberately navigation-only per the judgment-repair rule); inbox layout/chips/cards/bulk-dismiss ("dismiss all shown" + per-card), scan UX + banner, import summary line, detail chip, settings toggles, l10n facts-not-prose rule.
2. Type consistency: `repairOptionsFor` action fields match the executor call sites in Task 6's `_runAction`; `QualityUnitFormatters` shape matches `buildFindingMessage` and the card; params keys consumed here match the exact spellings emitted by Plan 1 detectors (plus the Task-4 NOTE's `tankId`/`sourceId` extensions).
3. Placeholder scan: the deliberate read-then-adapt seams are the unit-formatter closure construction and the small private page widgets, each specified by referenced concrete templates (file:line) — no TBDs remain.
