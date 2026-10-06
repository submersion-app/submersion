# Multi-Computer Dive Consolidation Completion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete multi-computer dive consolidation: full-fidelity per-computer data (tanks, pressures, events, all sample metrics) in one dive entry, auto-suggested consolidation at import, a working overlapping-dives Combine flow, and a per-source comparison UI — replacing the fragmented `mergeDives`/`consolidateComputer` code paths with one builder + service in the #449 pattern.

**Architecture:** A pure `DiveConsolidationBuilder` (domain, no DB) classifies and plans; a transactional `DiveConsolidationService` (data) applies with snapshot undo, reusing `DiveMergeSnapshot`. Three child tables gain `computerId` attribution (migration v94). All three entry points (import wizard, dive-detail merge, Combine dialog) route through the one service.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, `flutter_test`, `build_runner` codegen.

**Spec:** `docs/superpowers/specs/2026-07-02-multi-computer-consolidation-completion-design.md`

## Global Constraints

- All Dart code must pass `dart format .` with no changes (run on the whole repo before each commit).
- Run `flutter analyze` on the whole project before each commit (never pipe through `tail`/`head`).
- Anything displaying units must use `UnitFormatter` from the active diver's settings — never hard-coded units.
- No emojis anywhere. Immutability always (copyWith, no mutation).
- New user-facing strings: add to `lib/l10n/app_en.arb`, translate into all 10 non-English locales (`app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_ja.arb`, `app_ko.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`, plus the tenth present in `lib/l10n/`; check `ls lib/l10n/`), then run `flutter gen-l10n`.
- Service/DB tests must run with `PRAGMA foreign_keys = ON` (FK-off tests have masked child-before-parent insert bugs in this repo).
- Run targeted test files, not whole directories (broad runs time out).
- Null `computerId` on child rows means "primary source or manual entry" — the established `dive_profiles` convention.
- Commit after each task (pre-authorized). No Co-Authored-By lines in commit messages.
- TDD: write the failing test first in every task.

## Key existing code (read before your task)

| Thing | Where |
|---|---|
| `DiveMergeBuilder` (pattern to mirror) | `lib/features/dive_log/domain/services/dive_merge_builder.dart` |
| `DiveMergeService` (pattern to mirror) | `lib/features/dive_log/data/services/dive_merge_service.dart` |
| `DiveMergeSnapshot` | `lib/features/dive_log/data/services/dive_merge_snapshot.dart` |
| `consolidateComputer` / `mergeDives` / `unlinkComputer` / `setPrimaryDataSource` / `backfillPrimaryDataSource` | `lib/features/dive_log/data/repositories/dive_repository_impl.dart:4436-4897` |
| `importProfile` (writes dive + children + `dive_data_sources` row per download) | `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:805` |
| Wizard adapter consolidate path | `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:322-630` |
| Wizard state (duplicateActions, consolidate ≥0.7 gate) | `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart:217-243,357-440` |
| `DiveMatcher` (0.5 possible / 0.7 probable) | `lib/features/dive_import/domain/services/dive_matcher.dart` |
| Combine dialog overlap dead-end | `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart:100` (`_buildOverlapPanel`) |
| Dive-detail merge dialog + data sources + chart wiring | `lib/features/dive_log/presentation/pages/dive_detail_page.dart:423-449,561,714,1104-1400,4561-4630` |
| Existing tests to keep green | `test/features/dive_log/data/repositories/dive_consolidation_test.dart`, `test/features/dive_log/data/services/dive_merge_service_test.dart`, `test/features/dive_log/domain/services/dive_merge_builder_test.dart`, `test/features/dive_log/integration/multi_computer_integration_test.dart` |

---

### Task 1: Migration v94 — `computerId` on tanks, pressures, events

**Files:**
- Modify: `lib/core/database/database.dart` (three table classes; `currentSchemaVersion` at `:1710`; migration tail at `:4304-4321`)
- Test: `test/core/database/consolidation_attribution_migration_test.dart` (create)

**Interfaces:**
- Produces: `DiveTanks.computerId`, `TankPressureProfiles.computerId`, `DiveProfileEvents.computerId` — all `TextColumn`, nullable, FK → `dive_computers` `ON DELETE SET NULL`. Drift datagen adds `computerId` to the generated companions/rows every later task uses.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/consolidation_attribution_migration_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async => db.close());

  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v94 adds computer_id to the three attribution tables', () async {
    expect(await columnsOf('dive_tanks'), contains('computer_id'));
    expect(await columnsOf('tank_pressure_profiles'), contains('computer_id'));
    expect(await columnsOf('dive_profile_events'), contains('computer_id'));
  });

  test('deleting a computer nulls attribution instead of cascading', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diveComputers).insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: Value(now),
          ),
        );
    await db.into(db.dives).insert(
          DivesCompanion.insert(id: 'dive-1', diveDateTime: now),
        );
    await db.into(db.diveTanks).insert(
          DiveTanksCompanion.insert(
            id: 'tank-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
          ),
        );
    await (db.delete(db.diveComputers)
          ..where((t) => t.id.equals('comp-1')))
        .go();
    final tank = await (db.select(db.diveTanks)
          ..where((t) => t.id.equals('tank-1')))
        .getSingle();
    expect(tank.computerId, isNull);
  });
}
```

Adjust the `DiveComputersCompanion.insert` / `DivesCompanion.insert` required
fields to whatever the generated companions actually require (check an
existing DB test such as `test/features/dive_log/data/repositories/dive_consolidation_test.dart`
for the canonical minimal inserts and the `AppDatabase.forTesting` constructor
name used in this repo — if it is `AppDatabase(NativeDatabase.memory())`, use
that).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/consolidation_attribution_migration_test.dart`
Expected: FAIL — `computer_id` not in column set / `computerId` not a named parameter.

- [ ] **Step 3: Add the columns to the three table classes**

In `lib/core/database/database.dart`, add to `class DiveTanks extends Table` (after `presetName`):

```dart
  // Which computer contributed this tank (null = primary source / manual).
  // Mirrors dive_profiles.computerId semantics (multi-computer consolidation).
  TextColumn get computerId => text().nullable().references(
        DiveComputers,
        #id,
        onDelete: KeyAction.setNull,
      )();
```

Add the identical column (same comment) to `class TankPressureProfiles extends Table` (after `pressure`) and `class DiveProfileEvents extends Table` (after `source`).

- [ ] **Step 4: Bump the schema version and add the migration block**

At `:1710`: `static const int currentSchemaVersion = 94;`

After `if (from < 93) await reportProgress();` (`:4320`), insert:

```dart
        if (from < 94) {
          // Multi-computer consolidation: per-source attribution for tanks,
          // pressure curves, and events. Guarded per table so minimal-schema
          // migration tests without these tables are unaffected; existing
          // rows keep NULL (= primary source / manual entry).
          for (final table in [
            'dive_tanks',
            'tank_pressure_profiles',
            'dive_profile_events',
          ]) {
            final cols = await customSelect(
              "PRAGMA table_info('$table')",
            ).get();
            if (cols.isEmpty) continue;
            final names = cols.map((c) => c.read<String>('name')).toSet();
            if (!names.contains('computer_id')) {
              await customStatement(
                'ALTER TABLE $table ADD COLUMN computer_id TEXT '
                'REFERENCES dive_computers (id) ON DELETE SET NULL',
              );
            }
          }
        }
        if (from < 94) await reportProgress();
```

- [ ] **Step 5: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with no errors; `database.g.dart` gains the columns.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/core/database/consolidation_attribution_migration_test.dart`
Expected: PASS (both tests).

- [ ] **Step 7: Run the existing baseline suites**

Run: `flutter test test/features/dive_log/data/repositories/dive_consolidation_test.dart test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: PASS (49 tests total across the four suites; these two must be green).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(consolidation): add computer_id attribution to tanks, pressures, events (v94)"
```

---

### Task 2: Write-path attribution — downloads stamp `computerId` on children

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`importProfile`, `:805` onward — the blocks that insert `diveTanks`, `tankPressureProfiles`, `diveProfileEvents` rows)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` if it inserts those rows directly (it must mirror download persistence — check with `grep -n "DiveTanksCompanion\|TankPressureProfilesCompanion\|DiveProfileEventsCompanion" lib/features/dive_computer/data/services/reparse_service.dart`; if it delegates to `importProfile`, no change)
- Test: `test/features/dive_log/data/repositories/dive_computer_repository_import_attribution_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's `computerId` companions.
- Produces: every tank / pressure / event row created by a computer download carries that download's `computerId`. (This is what makes unlink (Task 6) and per-source UI (Tasks 10–11) able to attribute rows on dives consolidated after this release.)

- [ ] **Step 1: Write the failing test** — call `importProfile` with a computerId, at least one tank, a few pressure points, and one event (copy the setup from an existing `importProfile` test; `grep -rn "importProfile" test/ | head` to find it). Assert every inserted `dive_tanks`, `tank_pressure_profiles`, and `dive_profile_events` row for the new dive has `computerId` equal to the importing computer's id.

- [ ] **Step 2: Run it** — `flutter test test/features/dive_log/data/repositories/dive_computer_repository_import_attribution_test.dart`. Expected: FAIL (rows have null computerId).

- [ ] **Step 3: Implement** — in `importProfile`, add `computerId: Value(computerId)` to each `DiveTanksCompanion`, `TankPressureProfilesCompanion`, and `DiveProfileEventsCompanion` construction. The method already receives `computerId` as a required parameter. Note: rows on a dive's *primary* source now carry an explicit computerId rather than null — that is intentional and compatible with "null = primary/manual" (null remains the manual/legacy value; an explicit id is strictly more informative). Apply the same change in `reparse_service.dart` if it constructs those companions itself.

- [ ] **Step 4: Run the test + reparse suite** — `flutter test test/features/dive_log/data/repositories/dive_computer_repository_import_attribution_test.dart` plus the existing reparse tests (`ls test/features/dive_computer/`). Expected: PASS.

- [ ] **Step 5: Format, analyze, commit** — `dart format . && flutter analyze`, then:

```bash
git add -A
git commit -m "feat(consolidation): stamp computerId on tanks, pressures, events at import"
```

---

### Task 3: `DiveConsolidationBuilder` (pure domain)

**Files:**
- Create: `lib/features/dive_log/domain/services/dive_consolidation_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_consolidation_builder_test.dart` (create)

**Interfaces:**
- Consumes: `Dive`, `DiveTank`, `DiveProfilePoint` from `lib/features/dive_log/domain/entities/dive.dart`.
- Produces (used verbatim by Tasks 5, 8, 9):

```dart
enum ConsolidationInvalidReason {
  tooFewDives,
  mixedDivers,
  sameComputer,
  notOverlapping,
}

sealed class DiveConsolidationClassification {}
class ConsolidationInvalid extends DiveConsolidationClassification {
  const ConsolidationInvalid(this.reason);
  final ConsolidationInvalidReason reason;
}
class ConsolidationReady extends DiveConsolidationClassification {
  const ConsolidationReady({required this.primary, required this.secondaries});
  final Dive primary;
  final List<Dive> secondaries; // chronological by entry time
}

class DiveConsolidationPlan {
  const DiveConsolidationPlan({
    required this.primary,
    required this.secondaries,
    required this.offsetsSeconds,
    required this.tankMerges,
    required this.previewSeries,
  });
  final Dive primary;
  final List<Dive> secondaries;
  /// Source dive id -> seconds to ADD to that source's child timestamps to
  /// land on the primary's timeline. primary maps to 0; values may be
  /// negative (secondary started before the primary).
  final Map<String, int> offsetsSeconds;
  /// Secondary tank id -> primary tank id it merges into (dedup). Absent
  /// keys are kept as additional attributed tanks.
  final Map<String, String> tankMerges;
  /// Dive id -> depth series shifted onto the primary timeline (preview).
  final Map<String, List<DiveProfilePoint>> previewSeries;
}

class DiveConsolidationBuilder {
  const DiveConsolidationBuilder();
  DiveConsolidationClassification classify(List<Dive> dives, {String? primaryDiveId});
  DiveConsolidationPlan build(List<Dive> dives, {String? primaryDiveId});
}
```

- [ ] **Step 1: Write the failing tests** — table-driven, covering:

```dart
// test/features/dive_log/domain/services/dive_consolidation_builder_test.dart
// Helper: makeDive(id, entry: DateTime, runtimeMin: int, {serial, tanks, profile})
// mirroring the helpers in dive_merge_builder_test.dart (copy them).
//
// classify:
// - single dive -> ConsolidationInvalid(tooFewDives)
// - different diverId -> ConsolidationInvalid(mixedDivers)
// - both dives have identical non-null diveComputerSerial
//     -> ConsolidationInvalid(sameComputer)
// - dive B entirely after dive A (no overlap) -> ConsolidationInvalid(notOverlapping)
// - overlap, no primaryDiveId -> ConsolidationReady with primary = earlier entry
// - overlap, primaryDiveId = later dive -> that dive is primary
// build:
// - offsetsSeconds: primary -> 0; secondary entered 90s after primary -> +90;
//   secondary entered 30s BEFORE primary -> -30
// - tank dedup: secondary AL80 EAN32 (32.0/0.0, 210->60 bar) merges into
//   primary EAN32 (31.8/0.0, 207->63 bar)  [within 0.5% gas, 5 bar]
// - tank kept: gas differs by 1.2% O2 -> no merge entry
// - tank kept: pressures differ by 8 bar -> no merge entry
// - tank kept: secondary has null startPressure -> no merge entry (conservative)
// - two secondary tanks cannot merge into the same primary tank twice
//   (first match wins; second stays separate)
// - previewSeries: secondary series timestamps shifted by its offset,
//   negative timestamps preserved
// - three dives (primary + 2 secondaries) all classified and planned
// - build() on an invalid selection throws ArgumentError
```

Write each of those as a real `test(...)` with exact expected values.

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/dive_log/domain/services/dive_consolidation_builder_test.dart`. Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the builder**

```dart
// lib/features/dive_log/domain/services/dive_consolidation_builder.dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

// (types from the Interfaces block above, verbatim)

class DiveConsolidationBuilder {
  const DiveConsolidationBuilder();

  static const double _gasTolerancePct = 0.5;
  static const double _pressureToleranceBar = 5.0;

  /// The segment's occupied span: declared runtime or last profile sample,
  /// whichever is later (same rule as DiveMergeBuilder._segmentExtent).
  Duration _extent(Dive dive) {
    var extent = dive.effectiveRuntime ?? Duration.zero;
    for (final point in dive.profile) {
      if (point.timestamp > extent.inSeconds) {
        extent = Duration(seconds: point.timestamp);
      }
    }
    return extent;
  }

  bool _overlaps(Dive a, Dive b) {
    final aStart = a.effectiveEntryTime;
    final aEnd = aStart.add(_extent(a));
    final bStart = b.effectiveEntryTime;
    final bEnd = bStart.add(_extent(b));
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  DiveConsolidationClassification classify(
    List<Dive> dives, {
    String? primaryDiveId,
  }) {
    if (dives.length < 2) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.mixedDivers);
    }
    // Two records from the same physical computer are a re-download, not a
    // second computer. Serial is the only computer identity on the domain
    // entity; the service re-checks the computerId FK on the raw rows.
    final serials = <String>{};
    for (final d in dives) {
      final serial = d.diveComputerSerial;
      if (serial != null && serial.isNotEmpty && !serials.add(serial)) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.sameComputer,
        );
      }
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final primary = primaryDiveId == null
        ? sorted.first
        : sorted.firstWhere(
            (d) => d.id == primaryDiveId,
            orElse: () => sorted.first,
          );
    final secondaries = [
      for (final d in sorted)
        if (d.id != primary.id) d,
    ];
    for (final s in secondaries) {
      if (!_overlaps(primary, s)) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.notOverlapping,
        );
      }
    }
    return ConsolidationReady(primary: primary, secondaries: secondaries);
  }

  bool _tankMatches(DiveTank primary, DiveTank secondary) {
    final o2Close =
        (primary.gasMix.o2Percent - secondary.gasMix.o2Percent).abs() <=
            _gasTolerancePct;
    final heClose =
        (primary.gasMix.hePercent - secondary.gasMix.hePercent).abs() <=
            _gasTolerancePct;
    if (!o2Close || !heClose) return false;
    // Conservative: both pressures must exist on both tanks and agree.
    final ps = primary.startPressure, pe = primary.endPressure;
    final ss = secondary.startPressure, se = secondary.endPressure;
    if (ps == null || pe == null || ss == null || se == null) return false;
    return (ps - ss).abs() <= _pressureToleranceBar &&
        (pe - se).abs() <= _pressureToleranceBar;
  }

  DiveConsolidationPlan build(List<Dive> dives, {String? primaryDiveId}) {
    final classification = classify(dives, primaryDiveId: primaryDiveId);
    if (classification is! ConsolidationReady) {
      throw ArgumentError(
        'build() requires a consolidatable selection; got $classification',
      );
    }
    final primary = classification.primary;
    final secondaries = classification.secondaries;

    final offsets = <String, int>{
      primary.id: 0,
      for (final s in secondaries)
        s.id: s.effectiveEntryTime
            .difference(primary.effectiveEntryTime)
            .inSeconds,
    };

    final tankMerges = <String, String>{};
    final claimedPrimaryTanks = <String>{};
    for (final s in secondaries) {
      for (final tank in s.tanks) {
        for (final pTank in primary.tanks) {
          if (claimedPrimaryTanks.contains(pTank.id)) continue;
          if (_tankMatches(pTank, tank)) {
            tankMerges[tank.id] = pTank.id;
            claimedPrimaryTanks.add(pTank.id);
            break;
          }
        }
      }
    }

    final preview = <String, List<DiveProfilePoint>>{
      for (final d in [primary, ...secondaries])
        d.id: [
          for (final p in d.profile)
            DiveProfilePoint(
              timestamp: p.timestamp + (offsets[d.id] ?? 0),
              depth: p.depth,
            ),
        ],
    };

    return DiveConsolidationPlan(
      primary: primary,
      secondaries: secondaries,
      offsetsSeconds: offsets,
      tankMerges: tankMerges,
      previewSeries: preview,
    );
  }
}
```

Check `DiveTank`'s gas accessors: the entity holds `gasMix` (a `GasMix` with `o2Percent`/`hePercent` — verify the exact getter names in `dive.dart:896` and adjust).

- [ ] **Step 4: Run to verify pass** — `flutter test test/features/dive_log/domain/services/dive_consolidation_builder_test.dart`. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): pure DiveConsolidationBuilder with classify, tank dedup, preview"
```

---

### Task 4: Extract shared snapshot capture

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_snapshot.dart`
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart:40-97` (`captureSnapshot`)
- Test: existing `test/features/dive_log/data/services/dive_merge_service_test.dart` (must stay green; no new tests)

**Interfaces:**
- Produces: `static Future<DiveMergeSnapshot> DiveMergeSnapshot.capture(AppDatabase db, List<String> diveIds, String mergedDiveId)` — Task 5 calls this.

- [ ] **Step 1: Move the body** of `DiveMergeService.captureSnapshot` into a new static `capture(AppDatabase db, List<String> diveIds, String mergedDiveId)` on `DiveMergeSnapshot` (add the needed imports: `package:submersion/core/database/database.dart`). Replace the service method body with `return DiveMergeSnapshot.capture(_db, diveIds, mergedDiveId);` (keep the public method — tests call it).

- [ ] **Step 2: Verify** — `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`. Expected: PASS, unchanged count.

- [ ] **Step 3: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "refactor(dive-merge): extract DiveMergeSnapshot.capture for reuse by consolidation"
```

---

### Task 5: `DiveConsolidationService` — transactional apply + undo

**Files:**
- Create: `lib/features/dive_log/data/services/dive_consolidation_service.dart`
- Test: `test/features/dive_log/data/services/dive_consolidation_service_test.dart` (create)

**Interfaces:**
- Consumes: `DiveConsolidationBuilder`/`DiveConsolidationPlan` (Task 3), `DiveMergeSnapshot.capture` (Task 4), `DiveRepository.getDivesByIds` (`dive_repository_impl.dart:1278`), `bulkDeleteDives` (`:1255`), `backfillPrimaryDataSource` (`:4470`).
- Produces (Tasks 7, 8, 9 call these):

```dart
class DiveConsolidationOutcome {
  const DiveConsolidationOutcome({
    required this.targetDiveId,
    required this.snapshot,
  });
  final String targetDiveId;
  final DiveMergeSnapshot snapshot;
}

class DiveConsolidationService {
  DiveConsolidationService(DiveRepository diveRepo);
  /// Folds [secondaryDiveIds] into [targetDiveId] as additional computer
  /// sources. Throws ArgumentError (with the ConsolidationInvalidReason in
  /// the message) when the selection cannot be consolidated. All-or-nothing.
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
  });
  /// Restores the pre-consolidation state byte-for-byte.
  Future<void> undo(DiveMergeSnapshot snapshot);
}
```

- [ ] **Step 1: Write the failing tests** — copy the DB scaffolding (in-memory `AppDatabase`, repository wiring, `PRAGMA foreign_keys = ON`) from `test/features/dive_log/data/services/dive_merge_service_test.dart`. Cover, with real inserted fixtures (two dives, same diver, overlapping entry times 60s apart, each with: 1 computer + dive_data_sources row, profile samples carrying temp/tts/cns, 2 tanks (one dedupable pair), tank pressures, 2 events, 1 media row on the secondary):

1. `apply` re-parents everything: target has both computers' profile rows; secondary's profile/event/pressure timestamps are shifted by +60; secondary children carry the secondary's computerId; secondary dive row is gone (tombstoned — assert via the repo's deletion-log API, see how `dive_merge_service_test.dart` asserts it).
2. Tank dedup: the dedupable secondary tank inserts NO new `dive_tanks` row; its pressure series lands on the primary tank's id with the secondary computerId. The non-dedupable tank is added with fresh id, secondary computerId, `tankOrder` continuing after the target's tanks.
3. `dive_data_sources`: target ends with a primary row (backfilled) + the secondary's row re-pointed (`isPrimary: false`, rawData/rawFingerprint preserved).
4. Pre-existing target children get stamped with the primary's computerId during first consolidation (insert target tank with null computerId before applying; after apply it carries the target dive row's computerId).
5. Events preserved with attribution; gas switches remapped to merged tank ids.
6. Media re-pointed to target.
7. `apply` on same-computer selection throws ArgumentError; nothing written.
8. `undo` restores both dives byte-for-byte (same row-diff assertion style as the merge service test) and works with FK ON.
9. Second consolidation onto an already-consolidated dive unions sources (target ends with 3 `dive_data_sources` rows, never nested).

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/dive_log/data/services/dive_consolidation_service_test.dart`. Expected: FAIL (service missing).

- [ ] **Step 3: Implement the service.** Mirror `DiveMergeService` structure exactly (same imports, `_db`, `_sync`, `SyncEventBus`). Core of `apply`:

```dart
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
  }) async {
    final allIds = [targetDiveId, ...secondaryDiveIds];
    final dives = await _diveRepo.getDivesByIds(allIds);
    final plan = _builder.build(dives, primaryDiveId: targetDiveId);
    final snapshot = await DiveMergeSnapshot.capture(
      _db,
      allIds,
      targetDiveId,
    );
    final now = DateTime.now().millisecondsSinceEpoch;

    // Raw rows for columns the domain entity does not carry.
    final targetRow = snapshot.diveRows.firstWhere(
      (r) => r.id == targetDiveId,
    );
    // Service-level same-computer guard on the FK itself (the builder can
    // only see serials).
    for (final id in secondaryDiveIds) {
      final row = snapshot.diveRows.firstWhere((r) => r.id == id);
      if (row.computerId != null && row.computerId == targetRow.computerId) {
        throw ArgumentError('sameComputer: $id shares ${row.computerId}');
      }
    }

    await _db.transaction(() async {
      await _diveRepo.backfillPrimaryDataSource(targetDiveId);

      // First consolidation: stamp the target's own children with the
      // primary computer so null stays reserved for manual entries.
      if (targetRow.computerId != null) {
        for (final table in [_db.diveTanks, _db.tankPressureProfiles]) {
          // (write per-table; Drift has no polymorphic update -- do three
          //  explicit updates: diveTanks, tankPressureProfiles,
          //  diveProfileEvents, each:
          //  ..where diveId == target AND computerId IS NULL
          //  ..write computerId = targetRow.computerId)
        }
      }

      var nextTankOrder = snapshot.tankRows
              .where((r) => r.diveId == targetDiveId)
              .fold<int>(-1, (m, r) => r.tankOrder > m ? r.tankOrder : m) +
          1;
      final tankIdMap = <String, String>{}; // old secondary id -> id on target

      for (final secondary in plan.secondaries) {
        final secRow = snapshot.diveRows.firstWhere(
          (r) => r.id == secondary.id,
        );
        final offset = plan.offsetsSeconds[secondary.id] ?? 0;

        // Data sources: re-point existing rows; synthesize when none.
        final secSources = snapshot.dataSourceRows
            .where((r) => r.diveId == secondary.id)
            .toList();
        if (secSources.isEmpty) {
          // Synthesize from the dives row -- same companion mergeDives
          // builds today (dive_repository_impl.dart:4616-4652), with
          // diveId: targetDiveId, isPrimary: false.
        } else {
          for (final row in secSources) {
            await _db.into(_db.diveDataSources).insert(
                  row.toCompanion(false).copyWith(
                        id: Value(_uuid.v4()),
                        diveId: Value(targetDiveId),
                        isPrimary: const Value(false),
                      ),
                );
          }
        }

        // Tanks: merged ones map, kept ones copy with attribution.
        final secTanks = snapshot.tankRows
            .where((r) => r.diveId == secondary.id)
            .toList()
          ..sort((a, b) => a.tankOrder.compareTo(b.tankOrder));
        for (final tank in secTanks) {
          final mergeInto = plan.tankMerges[tank.id];
          if (mergeInto != null) {
            tankIdMap[tank.id] = mergeInto;
          } else {
            final freshId = _uuid.v4();
            tankIdMap[tank.id] = freshId;
            await _db.into(_db.diveTanks).insert(
                  tank.toCompanion(false).copyWith(
                        id: Value(freshId),
                        diveId: Value(targetDiveId),
                        computerId: Value(secRow.computerId),
                        tankOrder: Value(nextTankOrder++),
                      ),
                );
            await _sync.markRecordPending(
              entityType: 'diveTanks',
              recordId: freshId,
              localUpdatedAt: now,
            );
          }
        }

        // Profiles: copy every column, re-based, attributed, never primary.
        await _db.batch((batch) {
          for (final row in snapshot.profileRows.where(
            (r) => r.diveId == secondary.id,
          )) {
            batch.insert(
              _db.diveProfiles,
              row.toCompanion(false).copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(targetDiveId),
                    timestamp: Value(row.timestamp + offset),
                    computerId: Value(row.computerId ?? secRow.computerId),
                    isPrimary: const Value(false),
                  ),
            );
          }
          // Tank pressures: re-based, remapped, attributed.
          for (final row in snapshot.tankPressureRows.where(
            (r) => r.diveId == secondary.id,
          )) {
            final mappedTank = tankIdMap[row.tankId];
            if (mappedTank == null) continue;
            batch.insert(
              _db.tankPressureProfiles,
              row.toCompanion(false).copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(targetDiveId),
                    tankId: Value(mappedTank),
                    timestamp: Value(row.timestamp + offset),
                    computerId: Value(secRow.computerId),
                  ),
            );
          }
        });

        // Events + gas switches: same shape as DiveMergeService.apply
        // steps 5-6 (fresh id, diveId=target, timestamp+offset, tankId
        // remapped via tankIdMap, markRecordPending) PLUS
        // computerId: Value(secRow.computerId) on events.

        // Media: same as DiveMergeService.apply step 12, filtered to
        // entries whose snapshot.mediaDiveIds value == secondary.id.
      }

      // Touch the target so sync carries the consolidation.
      await (_db.update(_db.dives)
            ..where((t) => t.id.equals(targetDiveId)))
          .write(DivesCompanion(updatedAt: Value(now)));
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: targetDiveId,
        localUpdatedAt: now,
      );

      // Delete secondaries through the tombstone-logging path (this is the
      // fix for mergeDives' raw delete, which never logged deletions and
      // let sync resurrect the folded dive).
      await _diveRepo.bulkDeleteDives(secondaryDiveIds.toList());
    });

    SyncEventBus.notifyLocalChange();
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: snapshot,
    );
  }
```

The commented pseudo-lines above (per-table stamping, synthesized data source, events/gas-switches/media blocks) must be written out fully — copy the concrete code from `mergeDives` (`dive_repository_impl.dart:4616-4652`) and `DiveMergeService.apply` steps 5, 6, 12, adding the `computerId` values shown.

`undo(snapshot)`: identical to `DiveMergeService.undo` with ONE difference — do not call `_diveRepo.deleteDive(mergedId)`; the target dive was modified, not created, and its original row is in `snapshot.diveRows` (the child-delete batch plus verbatim re-inserts with `InsertMode.insertOrReplace` already restore it). Copy the method, delete that one call, keep everything else including per-row `markRecordPending` and media-pointer restore.

- [ ] **Step 4: Run to verify pass** — `flutter test test/features/dive_log/data/services/dive_consolidation_service_test.dart`. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): transactional DiveConsolidationService with snapshot undo"
```

---

### Task 6: Extend `unlinkComputer` to move attributed children

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:4691-4822` (`unlinkComputer`)
- Test: extend `test/features/dive_log/data/repositories/dive_consolidation_test.dart`

**Interfaces:**
- Consumes: Task 1 columns. No signature change: `Future<String> unlinkComputer({required String diveId, required String computerReadingId})`.

- [ ] **Step 1: Write failing tests** — consolidate (via Task 5 service) then unlink the secondary reading. Assert: the new standalone dive owns the tanks / tank pressures / events whose `computerId` matched the unlinked reading (with `computerId` preserved on the moved rows); the original dive no longer has them; a merged (deduped) tank's pressure rows follow their `computerId` to the new dive while the shared tank row itself STAYS on the original dive (the new dive gets a fresh tank row synthesized from the pressure rows' tankId is NOT required — instead: pressure rows for the unlinked computer are re-parented to the new dive with `tankId` set to a fresh tank cloned from the shared tank, preserving gas/pressures). Also: unlink with a null-computerId reading moves no tanks/events (existing profile behavior only).

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/dive_log/data/repositories/dive_consolidation_test.dart`. Expected: new tests FAIL.

- [ ] **Step 3: Implement** inside the existing transaction, after the profile re-parenting block (`:4746-4776`), when `reading.computerId != null`:

```dart
        // Move this computer's attributed children to the new dive.
        final cid = reading.computerId!;
        await (_db.update(_db.diveTanks)
              ..where(
                (t) => t.diveId.equals(diveId) & t.computerId.equals(cid),
              ))
            .write(DiveTanksCompanion(diveId: Value(newDiveId)));
        await (_db.update(_db.diveProfileEvents)
              ..where(
                (t) => t.diveId.equals(diveId) & t.computerId.equals(cid),
              ))
            .write(DiveProfileEventsCompanion(diveId: Value(newDiveId)));

        // Pressure curves recorded by this computer on a SHARED (deduped)
        // tank need a home tank on the new dive: clone the shared tank once,
        // then re-parent this computer's pressure rows onto the clone.
        final pressureRows = await (_db.select(_db.tankPressureProfiles)
              ..where(
                (t) => t.diveId.equals(diveId) & t.computerId.equals(cid),
              ))
            .get();
        final movedTankIds = (await (_db.select(_db.diveTanks)
                  ..where((t) => t.diveId.equals(newDiveId)))
                .get())
            .map((t) => t.id)
            .toSet();
        final cloneBySharedTank = <String, String>{};
        for (final row in pressureRows) {
          var homeTankId = row.tankId;
          if (!movedTankIds.contains(homeTankId)) {
            homeTankId = cloneBySharedTank[row.tankId] ??= await () async {
              final shared = await (_db.select(_db.diveTanks)
                    ..where((t) => t.id.equals(row.tankId)))
                  .getSingle();
              final cloneId = _uuid.v4();
              await _db.into(_db.diveTanks).insert(
                    shared.toCompanion(false).copyWith(
                          id: Value(cloneId),
                          diveId: Value(newDiveId),
                          computerId: Value(cid),
                        ),
                  );
              return cloneId;
            }();
          }
          await (_db.update(_db.tankPressureProfiles)
                ..where((t) => t.id.equals(row.id)))
              .write(
            TankPressureProfilesCompanion(
              diveId: Value(newDiveId),
              tankId: Value(homeTankId),
            ),
          );
        }
```

- [ ] **Step 4: Run to verify pass** — `flutter test test/features/dive_log/data/repositories/dive_consolidation_test.dart`. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): unlink moves attributed tanks, pressures, events"
```

---

### Task 7: Route dive-detail "Merge with another dive" through the service; delete `mergeDives`

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4614-4630` (`_showMergeDiveDialog` / its confirm handler)
- Modify: `lib/features/dive_log/presentation/widgets/merge_dive_dialog.dart` (result plumbing only)
- Delete: `mergeDives` from `lib/features/dive_log/data/repositories/dive_repository_impl.dart:4596-4680` (after the call sites are gone)
- Modify: a Riverpod provider file — add `diveConsolidationServiceProvider` next to wherever `DiveMergeService` is provided (`grep -rn "DiveMergeService(" lib --include=*.dart` to find it)
- Test: `test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart` (update expectations)

**Interfaces:**
- Consumes: `DiveConsolidationService.apply/undo` (Task 5).
- Produces: `final diveConsolidationServiceProvider = Provider<DiveConsolidationService>(...)` — Tasks 8 and 9 read it.

- [ ] **Step 1: Add the provider** (mirror the `DiveMergeService` provider's shape exactly, same file).
- [ ] **Step 2: Update the failing test first** — in `merge_dive_dialog_test.dart`, replace the assertion that `repository.mergeDives` is invoked with one that `DiveConsolidationService.apply(targetDiveId: current, secondaryDiveIds: [selected])` is invoked, and add a test that a SnackBar with an Undo action appears (mirror the combine flow's snackbar test in `combine_dives_dialog_test.dart` — note `persist: false` + `showCloseIcon: true` per this repo's SnackBar convention).
- [ ] **Step 3: Rewire** the confirm handler at `dive_detail_page.dart:4621`: call `ref.read(diveConsolidationServiceProvider).apply(...)`, keep the current dive as `targetDiveId`, show the Undo SnackBar whose action calls `service.undo(outcome.snapshot)`, and surface `ArgumentError` reasons as user-visible text: map `sameComputer` → `context.l10n.diveLog_consolidate_error_sameComputer`, `notOverlapping` → `context.l10n.diveLog_consolidate_error_notOverlapping` (add both keys, plus generic fallback, to `app_en.arb` + all locales; run `flutter gen-l10n`).
- [ ] **Step 4: Delete `mergeDives`** from the repository and its interface declaration (`grep -rn "mergeDives" lib test` must return zero production references; delete or rewrite any repository-level tests of it in `dive_consolidation_test.dart` to target the service instead).
- [ ] **Step 5: Verify** — `flutter test test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart test/features/dive_log/data/repositories/dive_consolidation_test.dart`. Expected: PASS.
- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): dive-detail merge uses consolidation service with undo; drop mergeDives"
```

---

### Task 8: Import wizard — auto-suggest consolidation; close the re-download hole; full-fidelity consolidate

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — add `getSourceKeysByDiveId` next to `getSourceUuidByDiveId` (`:4348`)
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` — `detectDuplicate` (find with `grep -n "detectDuplicate" `) gains a fingerprint pass
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:322-360` (`checkDuplicates`) and `:554-609` (`_consolidateDive`)
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart:217-243` (state build) — seed auto-defaults
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart` — add `matchedComputerId` to `DiveMatchResult`
- Modify: `lib/features/universal_import/presentation/providers/import_consolidation_service.dart` — route through the new service
- Delete: `consolidateComputer` from `dive_repository_impl.dart:4549-4589` once callers are gone
- Tests: `test/features/import_wizard/` (extend the adapter/provider tests; `ls test/features/import_wizard/` for names)

**Interfaces:**
- Consumes: `DiveConsolidationService` (Task 5), `importSingleDiveAsNew` (`dive_import_service.dart:501`).
- Produces:
  - `Future<Map<String, Set<String>>> getSourceKeysByDiveId({String? diverId})` — dive id → every non-empty `sourceUuid` and hex `rawFingerprint` across ALL of its `dive_data_sources` rows (not just the primary).
  - `DiveMatchResult.matchedComputerId` (`String?`) — the matched existing dive's `computerId`.
  - Auto-default rule (constant in the wizard providers): `const double kAutoConsolidateScore = 0.85;`

- [ ] **Step 1: Failing tests first**, three groups:
  1. Repo: after consolidating two downloads, `getSourceKeysByDiveId` returns the target dive with BOTH computers' fingerprints (this is the assertion that fails today via `getSourceUuidByDiveId`).
  2. Provider: given `matchResults` where score = 0.9 and `matchedComputerId != currentComputerId`, the wizard state is seeded with `DuplicateAction.consolidate` for that index; score 0.9 with SAME computerId seeds nothing; score 0.7 cross-computer seeds nothing (stays pending per #200).
  3. Adapter: `_consolidateDive` path produces a target dive that contains the secondary's tanks and events (full fidelity) — assert through the DB after `performImport` with a consolidate action.
- [ ] **Step 2: Run to verify failures** — run the three test files touched. Expected: FAIL.
- [ ] **Step 3: Implement `getSourceKeysByDiveId`** — same SQL shape as `getSourceUuidByDiveId` but selecting `source_uuid` and `hex(raw_fingerprint) as fp`, accumulating both into a `Set<String>` per dive (skip null/empty). Keep `getSourceUuidByDiveId` (other callers) — implement it as a thin wrapper over the new method to avoid drift between them.
- [ ] **Step 4: Fingerprint pass in `detectDuplicate`** — before fuzzy matching, if the downloaded dive has a `rawFingerprint`, look it up in `getSourceKeysByDiveId` (hex-encode the same way); a hit returns a duplicate result with score 1.0 against that dive. This makes a re-download from an already-consolidated *secondary* computer resolve as an exact duplicate → default Skip.
- [ ] **Step 5: `matchedComputerId`** — add the nullable field to `DiveMatchResult` (constructor + any `copyWith`/props), populate it in `dive_computer_adapter.checkDuplicates` (`:339`) by loading the matched dive's row (`_db` is not on the adapter — fetch via `_diveRepository.getDivesByIds([result.matchingDiveId!])` and read `diveComputerSerial`? No: the domain entity lacks computerId, so add a small repo helper `Future<String?> getComputerIdForDive(String diveId)` doing a one-column select; that is the produced interface — same helper is reused by the providers test).
- [ ] **Step 6: Seed auto-defaults** in the wizard state build (`import_wizard_providers.dart:217-243`): for each dive `matchResults[i]` with `score >= kAutoConsolidateScore` and `matchedComputerId != null` and `matchedComputerId != currentComputer.id`, seed `duplicateActions[ImportEntityType.dives][i] = DuplicateAction.consolidate`. Everything else stays pending (explicit user choice, #200). Update the doc comment at `:217` which currently says "no auto-defaults".
- [ ] **Step 7: Full-fidelity consolidate** — replace `_consolidateDive`'s hand-rolled companion building (`:554-609`) with import-then-consolidate:

```dart
  Future<void> _consolidateDive(
    DownloadedDive dive,
    String targetDiveId,
    DiveComputer comp,
  ) async {
    final newDiveId = await _importService.importSingleDiveAsNew(
      dive,
      computerId: comp.id,
      diverId: _diverId,
      descriptorVendor: _descriptorVendor,
      descriptorProduct: _descriptorProduct,
      descriptorModel: _descriptorModel,
      libdivecomputerVersion: _libdivecomputerVersion,
    );
    await _consolidationService.apply(
      targetDiveId: targetDiveId,
      secondaryDiveIds: [newDiveId],
    );
  }
```

(`importSingleDiveAsNew` persists every sample column, tanks, pressures, events, and the raw-data `dive_data_sources` row via `importProfile`; consolidation then folds all of it in with attribution. This replaces today's lossy copy that dropped heart rate, O2 sensors, CNS/TTS samples, tanks, and events.) Inject `DiveConsolidationService` into the adapter the same way `_importService` is injected. Update `lib/features/universal_import/presentation/providers/import_consolidation_service.dart` the same way (its `performConsolidations` should call the service, not `consolidateComputer`).
- [ ] **Step 8: Delete `consolidateComputer`** from the repository + interface; `grep -rn "consolidateComputer" lib` must return nothing.
- [ ] **Step 9: Verify** — run the touched test files plus `test/features/dive_log/integration/multi_computer_integration_test.dart` (update it where it called the deleted repo methods — its scenarios now go through the service). Expected: PASS.
- [ ] **Step 10: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): auto-suggest consolidate at import, fingerprint dedup for all sources, full-fidelity consolidate"
```

---

### Task 9: Combine dialog — overlapping selections consolidate

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart` (replace `_buildOverlapPanel`, `:100` and `:380-410`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart:379` (pass-through only if the dialog needs the consolidation service — prefer `ref.read` inside the dialog if it is a `ConsumerStatefulWidget`)
- Modify: `lib/l10n/app_en.arb` + all locales; run `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart` (extend)

**Interfaces:**
- Consumes: `DiveConsolidationBuilder.classify/build` (Task 3) for the preview; `diveConsolidationServiceProvider` (Task 7) for apply/undo.

- [ ] **Step 1: Failing widget tests** — selecting two overlapping dives now shows: (a) a preview chart with BOTH depth series on the shared timeline, (b) a primary selector (two radio tiles labeled with each dive's computer/model + entry time, earliest pre-selected), (c) a confirm button labeled with the new l10n key `diveLog_consolidate_confirm` ("Combine into one dive with N computers" — English copy: "Keep as one dive with both computers"). Tapping confirm calls `DiveConsolidationService.apply` with the selected primary as target; an Undo SnackBar appears. A `ConsolidationInvalid(sameComputer)` selection shows the error text instead of the confirm button.
- [ ] **Step 2: Run to verify failure.** `flutter test test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`
- [ ] **Step 3: Implement** — in the dialog's build, where classification dispatches at `:100`, replace `MergeOverlapping() => _buildOverlapPanel(context)` with `MergeOverlapping() => _buildConsolidationPanel(context)`. The new panel: run `const DiveConsolidationBuilder().classify(widget.dives, primaryDiveId: _selectedPrimaryId)`; on `ConsolidationInvalid` render the mapped l10n error (reuse Task 7's keys); on `ConsolidationReady` call `build(...)` and render the `previewSeries` through the dialog's existing preview-chart widget (it already draws a depth series list — pass one line per source with the per-computer colors from `computerColorAt`), the radio group bound to `_selectedPrimaryId` (new `String?` state field, default = ready.primary.id), and the confirm button. Confirm: `Navigator.pop`, `apply(targetDiveId: _selectedPrimaryId!, secondaryDiveIds: others)`, then the same Undo SnackBar pattern as the sequential path (`persist: false`, `showCloseIcon: true`). New l10n keys: `diveLog_consolidate_confirm`, `diveLog_consolidate_selectPrimary`, `diveLog_consolidate_error_sameComputer`, `diveLog_consolidate_error_notOverlapping` (the last two exist from Task 7 — reuse). Remove `_buildOverlapPanel` and its now-unused l10n keys (`diveLog_combine_overlapTitle`, `diveLog_combine_overlapBody`, `diveLog_combine_overlapHintTwoDives`) from every locale.
- [ ] **Step 4: Verify** — `flutter test test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`. Expected: PASS.
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): combine dialog consolidates overlapping dives with primary selector"
```

---

### Task 10: Data Sources comparison grid

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`
- Modify: `lib/l10n/app_en.arb` + all locales; `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart` (create or extend — check `ls test/features/dive_log/presentation/widgets/`)

**Interfaces:**
- Consumes: existing `DataSourcesSection({required List<DiveDataSource> dataSources, required UnitFormatter units, onSetPrimary, onUnlink, ...})` (`data_sources_section.dart:19-45`) — no constructor change.

- [ ] **Step 1: Failing widget test** — pump `DataSourcesSection` with two `DiveDataSource` fixtures (different maxDepth/waterTemp/cns/otu/decoAlgorithm/gf values) and metric units; assert a comparison grid renders one column per source (header = computer model), rows labeled with the new l10n keys, values formatted via `UnitFormatter` (e.g. `30.1 m` vs `30.4 m`), and the primary column shows the existing primary badge. With ONE source, assert the grid is absent (cards-only, unchanged today's behavior).
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** — add a private `_SourceComparisonGrid extends StatelessWidget` in the same file, rendered above the per-source cards when `widget.dataSources.length >= 2`:

```dart
class _SourceComparisonGrid extends StatelessWidget {
  const _SourceComparisonGrid({required this.sources, required this.units});
  final List<DiveDataSource> sources;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <(String, String? Function(DiveDataSource))>[
      (l10n.diveLog_sources_row_maxDepth,
          (s) => s.maxDepth != null ? units.formatDepth(s.maxDepth!) : null),
      (l10n.diveLog_sources_row_avgDepth,
          (s) => s.avgDepth != null ? units.formatDepth(s.avgDepth!) : null),
      (l10n.diveLog_sources_row_duration,
          (s) => s.duration != null
              ? l10n.diveLog_sources_minutes(s.duration! ~/ 60)
              : null),
      (l10n.diveLog_sources_row_waterTemp,
          (s) => s.waterTemp != null
              ? units.formatTemperature(s.waterTemp!, decimals: 1)
              : null),
      (l10n.diveLog_sources_row_cns,
          (s) => s.cns != null ? '${s.cns!.toStringAsFixed(0)}%' : null),
      (l10n.diveLog_sources_row_otu,
          (s) => s.otu?.toStringAsFixed(0)),
      (l10n.diveLog_sources_row_decoAlgorithm, (s) => s.decoAlgorithm),
      (l10n.diveLog_sources_row_gf,
          (s) => s.gradientFactorLow != null && s.gradientFactorHigh != null
              ? '${s.gradientFactorLow}/${s.gradientFactorHigh}'
              : null),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 34,
        columns: [
          DataColumn(label: Text(l10n.diveLog_sources_row_metric)),
          for (final s in sources)
            DataColumn(
              label: Text(
                s.computerModel ?? l10n.diveLog_sources_unknownComputer,
                style: s.isPrimary
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
            ),
        ],
        rows: [
          for (final (label, pick) in rows)
            if (sources.any((s) => pick(s) != null))
              DataRow(
                cells: [
                  DataCell(Text(label)),
                  for (final s in sources) DataCell(Text(pick(s) ?? '—')),
                ],
              ),
        ],
      ),
    );
  }
}
```

Confirm `DiveDataSource` exposes `otu` (check `lib/features/dive_log/domain/entities/dive_data_source.dart`; if the entity lacks it while the table has it, add the field + mapping in `_mapRowToDataSource`). New l10n keys: `diveLog_sources_row_metric`, `_maxDepth`, `_avgDepth`, `_duration`, `_waterTemp`, `_cns`, `_otu`, `_decoAlgorithm`, `_gf`, `diveLog_sources_minutes` (plural), `diveLog_sources_unknownComputer` — all locales.
- [ ] **Step 4: Verify** — run the widget test file. Expected: PASS.
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): per-source comparison grid in Data Sources section"
```

---

### Task 11: Chart — toggle bar drives all per-computer overlays; real labels; tank badges

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:1104-1400` (toggle-item construction + chart args)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (find with `grep -rn "class DiveProfileChart" lib`) — filter overlays by `visibleComputers`
- Modify: the tanks section widget (find with `grep -rn "tanks" lib/features/dive_log/presentation/pages/dive_detail_page.dart | grep -i section` or the tank card widget file) — source badge
- Test: extend the chart/detail widget tests (`ls test/features/dive_log/presentation/` for the chart test file)

**Interfaces:**
- Consumes: profiles-by-source provider (`profilesBySourceProvider`), `dive_data_sources` (for computer display names + true primary), Task 1 attribution on events/pressures.

Fix three concrete defects at `dive_detail_page.dart:1130-1150` while wiring:
1. `label: computerId` renders a raw UUID — resolve display names from the dive's data sources (`dataSourcesProvider` already feeds the Data Sources section at `:423-449`; reuse it: map `computerId -> computerModel ?? serial`, fallback to the l10n `diveLog_sources_unknownComputer` key from Task 10).
2. `isPrimary: idx == 0` guesses — use the data source rows' real `isPrimary`.
3. Event markers / temperature / pressure curves ignore computer visibility — thread `visibleComputers` through: events carry `computerId` after Task 1, so filter `analysis?.events` (and the temp/pressure series if the chart draws per-computer variants) to visible computers; series from hidden computers are dropped before painting. Where the chart currently renders only the primary dive.profile-derived temperature curve, extend it to draw one temperature line per visible computer from `computerProfiles` (each profile point already carries `temperature`), color-matched via `computerLineColors` at reduced opacity.

- [ ] **Step 1: Failing widget tests** — (a) toggle labels show "Perdix 2" not a UUID; (b) the bold/primary toggle chip matches the data source marked primary, not map order; (c) hiding a computer removes its event markers and temperature line from the chart (assert via the chart's painted series/marker widgets — follow the existing chart test's assertion style).
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** per the three fixes above. Tank badge: in the tank card/row widget, when the dive has ≥2 data sources and the tank's `computerId` is non-null and differs from the primary source's computerId, render a small `Chip`/`Badge` with the source computer's short name (reuse the name-resolution map; new l10n not needed — the name is data). The `DiveTank` domain entity needs the field: add `computerId` to `DiveTank` (`dive.dart:896`, constructor + `copyWith` + `props`) and map it in the repository's tank row↔entity conversions (`grep -n "DiveTank(" lib/features/dive_log/data/repositories/dive_repository_impl.dart`).
- [ ] **Step 4: Verify** — run the touched widget-test files plus `flutter test test/features/dive_log/domain/` (entity change ripple). Expected: PASS.
- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add -A
git commit -m "feat(consolidation): per-computer chart overlays follow toggle bar; real names; tank source badges"
```

---

### Task 12: Cleanup, sync round-trip test, final verification

**Files:**
- Delete: `lib/features/dive_log/presentation/widgets/profile_selector_widget.dart` (+ its l10n keys from every locale; `grep -rn "ProfileSelectorWidget\|profileSelector" lib test` to find keys/references)
- Modify: `docs/FEATURE_ROADMAP.md:180-200` (§2.2: mark "Profile merging" complete, describe toggle bar not selector), `docs/features/profile-analysis.md:119-145`, `docs/guide/dive-computer.md:140-152`
- Test: `test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart` (create)
- Modify: `docs/superpowers/specs/2026-07-02-multi-computer-consolidation-completion-design.md` — status line to "Implemented"

**Interfaces:**
- Consumes: everything prior; sync test harness — copy the two-device scaffolding from an existing sync round-trip test (`grep -rln "roundtrip\|round_trip\|two device" test/ | head`).

- [ ] **Step 1: Sync round-trip test (failing first if it exposes a bug):** device A consolidates two dives → sync → device B: target dive arrives with both sources, attributed children (tanks/pressures/events carry computerId), and the folded secondary dive does NOT exist on B (tombstone honored). Then device A undoes → sync → B has both original dives back and no orphaned children (`SELECT count(*)` on each child table scoped to the deleted target-children ids).
- [ ] **Step 2: Fix whatever the round-trip exposes** (most likely candidates: missing `markRecordPending` on a child type in Task 5, or the deletion-log interplay from `bulkDeleteDives` + undo re-insert — see the stale-restore/deletion-log invariants in the sync docs; never clear the deletion log).
- [ ] **Step 3: Delete `ProfileSelectorWidget`** + l10n keys; `flutter gen-l10n`; `flutter analyze` confirms no dangling references.
- [ ] **Step 4: Update the three docs** — replace "Profile selector" descriptions with the toggle-bar + Data Sources comparison model; roadmap §2.2 "Profile merging" → ✅ with a pointer to the spec.
- [ ] **Step 5: Full verification sweep**

```bash
dart format .
flutter analyze
flutter test \
  test/core/database/consolidation_attribution_migration_test.dart \
  test/features/dive_log/domain/services/dive_consolidation_builder_test.dart \
  test/features/dive_log/data/services/dive_consolidation_service_test.dart \
  test/features/dive_log/data/services/dive_merge_service_test.dart \
  test/features/dive_log/data/repositories/dive_consolidation_test.dart \
  test/features/dive_log/domain/services/dive_merge_builder_test.dart \
  test/features/dive_log/integration/multi_computer_integration_test.dart \
  test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart \
  test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart \
  test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart
```

Expected: all PASS.

- [ ] **Step 6: Manual smoke on macOS** — `flutter run -d macos`: import two overlapping dives (fixtures or two UDDF files), Combine → consolidation preview → confirm → check Data Sources grid, toggle bar names, tank badges, Set primary, Unlink, Undo.
- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(consolidation): sync round-trip coverage, remove dead ProfileSelectorWidget, update docs"
```

---

## Self-review notes (already applied)

- Spec §1 → Task 1; §2 → Tasks 3–7; §3 → Task 8; §4 → Tasks 9–11 + 12 docs; §5 → tests embedded per task + Task 12 round-trip. Characterize-first is realized as TDD: every task writes the correct-behavior test before touching code, and Tasks 5/8 explicitly encode the known bugs (no re-basing, lossy consolidate, raw delete, primary-only UUID matching) as assertions.
- Type consistency: `DiveConsolidationPlan`/`ConsolidationReady`/`DiveConsolidationOutcome`/`getSourceKeysByDiveId`/`kAutoConsolidateScore`/`diveConsolidationServiceProvider` are each defined once (Tasks 3, 5, 7, 8) and consumed by name afterwards.
- Known judgment calls an implementer may hit: exact required fields on generated companions (Task 1), `GasMix` getter names (Task 3), chart-internal series plumbing (Task 11). In each case the task names the file and the grep to resolve it — do not invent parallel structures.
