# Rental Gear Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A diver who returns to a dive center sees what worked last time with its rental gear (notes they wrote, plus the lead, weighting feedback and tanks of their last dive there) and can copy that dive's weights and tanks into the new dive in one tap.

**Architecture:** One new synced child table of dive centers, `dive_center_gear_notes`, holds the diver's judgements. The "last dive here" facts are never stored: a repository query picks the latest non-planned dive at the center, the fully hydrated dive is loaded, and a pure value object converts it into display rows and fresh-id copies of its weights and tanks. Two surfaces render the same data: a card in the dive edit form under the dive center row, and a section on the dive center detail page. One shared bottom sheet creates, edits and deletes notes.

**Tech Stack:** Flutter, Riverpod (hand-written providers), Drift (`dart run build_runner build`), `flutter gen-l10n` ARB localization, `flutter_test`, in-memory SQLite for repository tests.

**Spec:** `docs/superpowers/specs/2026-09-18-rental-gear-memory-design.md`. Every decision there is fixed; this plan implements it. Two deliberate deviations from the spec text, both forced by the codebase: timestamps are stored as Unix milliseconds in integer columns like every neighbouring table (the spec said "datetime"), and the resolver takes the single hydrated latest dive rather than a list, because the repository query already excludes the current dive and orders by date.

## Global Constraints

- Schema rung is **221**. Main is at 219 and three open PRs (#2040, #1980, #1978) each claim 220. Re-check before Task 2 and again before the push: `git fetch origin && git show origin/main:lib/core/database/database.dart | grep "currentSchemaVersion ="` and `for n in 2040 1980 1978; do gh pr diff $n | grep -o "currentSchemaVersion = [0-9]*"; done`. If 221 has been taken, use the next free number everywhere this plan says 221.
- `minimumCompatibleSchemaVersion` stays 210. A new table never raises the floor.
- The Drift output `lib/core/database/database.g.dart` is gitignored and rebuilt per tree. After any change to `database.dart` run `dart run build_runner build --delete-conflicting-outputs` before compiling. Never stage a `.g.dart` file.
- The l10n output `lib/l10n/arb/app_localizations*.dart` (12 files) IS committed. Run `flutter gen-l10n` only after every one of the 11 ARBs carries the new keys (running it earlier bakes English into the other locales), then commit the 11 ARBs and the 12 generated files together.
- New user-visible strings are translated in all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. Locale ARBs get no `@` metadata; only `app_en.arb` does. New keys are appended at the end of each file, before the closing brace.
- Every value shown to the diver goes through `UnitFormatter` (weight and volume units, dates). Input in the diver's unit is converted with `UnitFormatter.weightToKg` and `volumeToLiters`; seeded text uses `formatRoundedForInput` and is read back with `parseUserDecimal`.
- Enum text read from the database uses `Enum.values.firstWhere((v) => v.name == text, orElse: ...)`, never `byName`.
- Never use em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens as punctuation, in code, comments, tests, ARB strings, commit messages or the PR body.
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file. No `Co-Authored-By` trailer.
- No emojis in code, comments or docs.
- Immutability: never mutate a list or map that was passed in.
- TDD: write the failing test first, watch it fail, then implement.
- Run `dart format .` on the whole project before each commit.
- Run `flutter analyze` on its own, never piped through `grep` or `tail` (a pipe hides the exit status). Infos are fatal in CI.
- Run specific test files per task, never the full suite; the full suite runs once, in Task 10. Do not start a `flutter test` while another one is running on this machine.
- The Bash tool's working directory can reset; run every command from the worktree root `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/loving-keller-f8f99d` and stage explicit paths (`git add <path>`), never `git add -A` or `git add -u`.
- Widget tests pin `locale: const Locale('en')`.
- The PR body must contain `Closes #2075`.
- Sync entity type string is `diveCenterGearNotes`; SQL table is `dive_center_gear_notes`; Drift table class is `DiveCenterGearNotes`; Drift row class is `DiveCenterGearNoteRow` (the domain entity is `DiveCenterGearNote`).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/dive_centers/domain/entities/dive_center_gear_note.dart` (create) | `RentalVerdict` enum, `DiveCenterGearNote` entity with `copyWith`, enum parsing helpers |
| `lib/features/dive_centers/domain/services/rental_memory_resolver.dart` (create) | `LastDiveAtCenter` value object: built from a hydrated `Dive`, exposes lead total and fresh-id copies of weights and tanks |
| `lib/core/database/database.dart` (modify) | `DiveCenterGearNotes` table, v221 rung, `_assertDiveCenterGearNotesSchema`, beforeOpen backstop, child hlc list |
| `lib/core/data/repositories/sync_repository.dart` (modify) | `hlcTargets` entry |
| `lib/core/services/sync/sync_data_serializer.dart` (modify) | `SyncData` field, base table, export, fetch, upsert, delete, id selector, parent-gated sets |
| `lib/core/services/sync/sync_service.dart` (modify) | apply order, `entityHasUpdatedAt`, `parentRefs` |
| `lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart` (create) | CRUD, change stream, pending marks and tombstones |
| `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (modify) | `latestDiveIdAtCenter`; `deleteDiveCenter` tombstones the notes it cascades |
| `lib/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart` (create) | repository provider, notes-by-center, last-dive-at-center |
| `lib/l10n/arb/app_*.arb` (modify, 11 files) plus regenerated `app_localizations*.dart` (12 files) | 27 new strings |
| `lib/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart` (create) | `showRentalGearNoteSheet`, the editor, delete confirm |
| `lib/features/dive_centers/presentation/widgets/rental_memory_card.dart` (create) | the "Last time at {center}" card for the edit form |
| `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart` (modify) | `centerChild` slot |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (modify) | card wiring and `_applyLastDiveAtCenter` |
| `lib/features/dive_centers/presentation/widgets/rental_gear_section.dart` (create) | the detail page section |
| `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (modify) | mounts the section |

---

### Task 1: Domain entity and the last-dive value object

**Files:**
- Create: `lib/features/dive_centers/domain/entities/dive_center_gear_note.dart`
- Create: `lib/features/dive_centers/domain/services/rental_memory_resolver.dart`
- Test: `test/features/dive_centers/domain/entities/dive_center_gear_note_test.dart`
- Test: `test/features/dive_centers/domain/services/rental_memory_resolver_test.dart`

**Interfaces:**
- Consumes: `EquipmentType`, `WeightType`, `WeightingFeedback`, `TankRole`, `GasMix` from `lib/core/constants/enums.dart` and `lib/features/dive_log/domain/entities/dive.dart`; `DiveWeight` from `lib/features/dive_log/domain/entities/dive_weight.dart`.
- Produces: `enum RentalVerdict { worked, avoid }`; `class DiveCenterGearNote` with fields `id, diveCenterId, gearType (EquipmentType), label (String?), size (String?), verdict, leadAdjustmentKg (double?), volumeLiters (double?), note (String), diveId (String?), notedAt, createdAt, updatedAt (DateTime)`, `copyWith` with `clearLabel, clearSize, clearLeadAdjustment, clearVolume, clearDiveId` flags, static `verdictFromName(String?)` and `gearTypeFromName(String?)`; `class LastDiveAtCenter` with `diveId, dateTime, weights, weightingFeedback, weightingFeedbackKg, tanks`, `double get totalLeadKg`, `factory LastDiveAtCenter.fromDive(Dive)`, `List<DiveWeight> weightsForNewDive({required String diveId, required String Function() newId})`, `List<DiveTank> tanksForNewDive({required String Function() newId, required double startPressure, required double endPressure})`.

- [ ] **Step 1: Write the failing entity test**

Create `test/features/dive_centers/domain/entities/dive_center_gear_note_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 10);

  DiveCenterGearNote note() => DiveCenterGearNote(
    id: 'n1',
    diveCenterId: 'c1',
    gearType: EquipmentType.regulator,
    label: '14',
    size: null,
    verdict: RentalVerdict.avoid,
    leadAdjustmentKg: null,
    volumeLiters: null,
    note: 'Breathed wet below 20 m',
    diveId: 'd1',
    notedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  test('copyWith replaces only the given fields', () {
    final changed = note().copyWith(
      verdict: RentalVerdict.worked,
      leadAdjustmentKg: 2.0,
    );
    expect(changed.verdict, RentalVerdict.worked);
    expect(changed.leadAdjustmentKg, 2.0);
    expect(changed.label, '14');
    expect(changed.diveId, 'd1');
    expect(changed.note, 'Breathed wet below 20 m');
  });

  test('copyWith clear flags null a nullable field', () {
    final cleared = note().copyWith(
      clearLabel: true,
      clearDiveId: true,
    );
    expect(cleared.label, isNull);
    expect(cleared.diveId, isNull);
    // The untouched nullable stays.
    expect(cleared.copyWith(size: 'L').size, 'L');
  });

  test('verdictFromName falls back to worked for unknown text', () {
    expect(DiveCenterGearNote.verdictFromName('avoid'), RentalVerdict.avoid);
    expect(DiveCenterGearNote.verdictFromName('worked'), RentalVerdict.worked);
    expect(DiveCenterGearNote.verdictFromName('later'), RentalVerdict.worked);
    expect(DiveCenterGearNote.verdictFromName(null), RentalVerdict.worked);
  });

  test('gearTypeFromName falls back to other for a newer peer type', () {
    expect(DiveCenterGearNote.gearTypeFromName('bcd'), EquipmentType.bcd);
    expect(
      DiveCenterGearNote.gearTypeFromName('hoverboard'),
      EquipmentType.other,
    );
    expect(DiveCenterGearNote.gearTypeFromName(null), EquipmentType.other);
  });

  test('equality is by value', () {
    expect(note(), note());
    expect(note() == note().copyWith(note: 'x'), isFalse);
  });
}
```

- [ ] **Step 2: Write the failing resolver test**

Create `test/features/dive_centers/domain/services/rental_memory_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

void main() {
  final when = DateTime(2026, 3, 12, 9, 30);

  Dive dive({
    List<DiveWeight> weights = const [],
    List<DiveTank> tanks = const [],
    WeightingFeedback? feedback,
    double? feedbackKg,
  }) => Dive(
    id: 'd1',
    dateTime: when,
    weights: weights,
    tanks: tanks,
    weightingFeedback: feedback,
    weightingFeedbackKg: feedbackKg,
  );

  const belt = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.belt,
    amountKg: 6,
    notes: 'their belt',
  );
  const trim = DiveWeight(
    id: 'w2',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
  );
  const al80 = DiveTank(
    id: 't1',
    name: 'Their AL80',
    volume: 11.1,
    workingPressure: 207,
    startPressure: 200,
    endPressure: 60,
    gasMix: GasMix(oxygen: 32),
    role: TankRole.backGas,
    material: TankMaterial.aluminum,
    order: 0,
    presetName: 'al80',
    computerId: 'comp',
    transmitterSerial: 'TX1',
    sourceTankIndex: 0,
    regulatorEquipmentId: 'reg',
    equipmentId: 'tank',
  );

  test('fromDive carries date, weights, feedback and tanks', () {
    final last = LastDiveAtCenter.fromDive(
      dive(
        weights: const [belt, trim],
        tanks: const [al80],
        feedback: WeightingFeedback.overweighted,
        feedbackKg: 1,
      ),
    );
    expect(last.diveId, 'd1');
    expect(last.dateTime, when);
    expect(last.weights, const [belt, trim]);
    expect(last.tanks, const [al80]);
    expect(last.weightingFeedback, WeightingFeedback.overweighted);
    expect(last.weightingFeedbackKg, 1);
    expect(last.totalLeadKg, 8);
  });

  test('a dive with no weights or tanks resolves with empty lists', () {
    final last = LastDiveAtCenter.fromDive(dive());
    expect(last.weights, isEmpty);
    expect(last.tanks, isEmpty);
    expect(last.totalLeadKg, 0);
    expect(last.weightingFeedback, isNull);
  });

  test('weightsForNewDive copies type, amount and notes under fresh ids', () {
    final last = LastDiveAtCenter.fromDive(dive(weights: const [belt, trim]));
    var n = 0;
    final copies = last.weightsForNewDive(
      diveId: 'new',
      newId: () => 'id${n++}',
    );
    expect(copies.map((w) => w.id), ['id0', 'id1']);
    expect(copies.map((w) => w.diveId), ['new', 'new']);
    expect(copies.first.weightType, WeightType.belt);
    expect(copies.first.amountKg, 6);
    expect(copies.first.notes, 'their belt');
    expect(copies.last.weightType, WeightType.trimWeights);
    // The source list is untouched.
    expect(last.weights.first.id, 'w1');
  });

  test('tanksForNewDive keeps the rig and takes default pressures', () {
    final last = LastDiveAtCenter.fromDive(dive(tanks: const [al80]));
    final copies = last.tanksForNewDive(
      newId: () => 'fresh',
      startPressure: 210,
      endPressure: 50,
    );
    final copy = copies.single;
    expect(copy.id, 'fresh');
    expect(copy.name, 'Their AL80');
    expect(copy.volume, 11.1);
    expect(copy.workingPressure, 207);
    expect(copy.presetName, 'al80');
    expect(copy.material, TankMaterial.aluminum);
    expect(copy.gasMix, const GasMix(oxygen: 32));
    expect(copy.role, TankRole.backGas);
    expect(copy.order, 0);
    expect(copy.startPressure, 210);
    expect(copy.endPressure, 50);
    // Device, transmitter and owned-gear links belong to the old dive.
    expect(copy.computerId, isNull);
    expect(copy.transmitterSerial, isNull);
    expect(copy.sourceTankIndex, isNull);
    expect(copy.regulatorEquipmentId, isNull);
    expect(copy.equipmentId, isNull);
  });
}
```

If `Dive`'s constructor requires more than `id` and `dateTime` (check `lib/features/dive_log/domain/entities/dive.dart` around line 140 for `required` parameters), add those required arguments to the `dive()` helper with neutral values; do not change the entity.

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/dive_centers/domain/`
Expected: FAIL with "Target of URI doesn't exist" for both new imports.

- [ ] **Step 4: Write the entity**

Create `lib/features/dive_centers/domain/entities/dive_center_gear_note.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Whether a piece of an operator's rental gear is worth asking for again.
enum RentalVerdict { worked, avoid }

/// One thing a diver learned about a dive center's rental gear (issue
/// #2075): "their size-L wetsuit runs small", "regulator 14 breathes wet",
/// "their AL80 really holds 11.1 L", "I needed 2 kg more with their BCD".
///
/// A note belongs to the center, not to a dive: it survives the dive it was
/// written on and shows on every later visit. [diveId] only records where it
/// was noticed.
class DiveCenterGearNote extends Equatable {
  final String id;
  final String diveCenterId;
  final EquipmentType gearType;

  /// The operator's own mark for the item: "14", "AL80", "blue".
  final String? label;
  final String? size;
  final RentalVerdict verdict;

  /// Signed, in kg: how much more (positive) or less lead this gear needed
  /// than the diver's usual.
  final double? leadAdjustmentKg;

  /// The cylinder's true capacity, for tank notes.
  final double? volumeLiters;
  final String note;
  final String? diveId;
  final DateTime notedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveCenterGearNote({
    required this.id,
    required this.diveCenterId,
    required this.gearType,
    this.label,
    this.size,
    this.verdict = RentalVerdict.worked,
    this.leadAdjustmentKg,
    this.volumeLiters,
    this.note = '',
    this.diveId,
    required this.notedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A stored verdict name, tolerating a value this build does not know.
  static RentalVerdict verdictFromName(String? name) =>
      RentalVerdict.values.firstWhere(
        (v) => v.name == name,
        orElse: () => RentalVerdict.worked,
      );

  /// A stored gear type name; a type added by a newer peer reads as other.
  static EquipmentType gearTypeFromName(String? name) =>
      EquipmentType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => EquipmentType.other,
      );

  DiveCenterGearNote copyWith({
    String? id,
    String? diveCenterId,
    EquipmentType? gearType,
    String? label,
    bool clearLabel = false,
    String? size,
    bool clearSize = false,
    RentalVerdict? verdict,
    double? leadAdjustmentKg,
    bool clearLeadAdjustment = false,
    double? volumeLiters,
    bool clearVolume = false,
    String? note,
    String? diveId,
    bool clearDiveId = false,
    DateTime? notedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveCenterGearNote(
      id: id ?? this.id,
      diveCenterId: diveCenterId ?? this.diveCenterId,
      gearType: gearType ?? this.gearType,
      label: clearLabel ? null : (label ?? this.label),
      size: clearSize ? null : (size ?? this.size),
      verdict: verdict ?? this.verdict,
      leadAdjustmentKg: clearLeadAdjustment
          ? null
          : (leadAdjustmentKg ?? this.leadAdjustmentKg),
      volumeLiters: clearVolume ? null : (volumeLiters ?? this.volumeLiters),
      note: note ?? this.note,
      diveId: clearDiveId ? null : (diveId ?? this.diveId),
      notedAt: notedAt ?? this.notedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveCenterId,
    gearType,
    label,
    size,
    verdict,
    leadAdjustmentKg,
    volumeLiters,
    note,
    diveId,
    notedAt,
    createdAt,
    updatedAt,
  ];
}
```

- [ ] **Step 5: Write the value object**

Create `lib/features/dive_centers/domain/services/rental_memory_resolver.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

/// What the diver's most recent dive at a center says about the rental rig
/// they used (issue #2075): the lead they carried, how it felt, and the
/// cylinders. Nothing here is stored; it is read off the hydrated dive every
/// time, so it can never drift from the dive itself.
///
/// Build it only from the fully hydrated dive (`DiveRepository.getDiveById`).
/// The lean analysis hydration leaves `weights` empty, which would make every
/// last dive look weightless.
class LastDiveAtCenter extends Equatable {
  final String diveId;
  final DateTime dateTime;
  final List<DiveWeight> weights;
  final WeightingFeedback? weightingFeedback;
  final double? weightingFeedbackKg;
  final List<DiveTank> tanks;

  const LastDiveAtCenter({
    required this.diveId,
    required this.dateTime,
    required this.weights,
    required this.weightingFeedback,
    required this.weightingFeedbackKg,
    required this.tanks,
  });

  factory LastDiveAtCenter.fromDive(Dive dive) => LastDiveAtCenter(
    diveId: dive.id,
    dateTime: dive.dateTime,
    weights: List.unmodifiable(dive.weights),
    weightingFeedback: dive.weightingFeedback,
    weightingFeedbackKg: dive.weightingFeedbackKg,
    tanks: List.unmodifiable(dive.tanks),
  );

  double get totalLeadKg => weights.fold(0.0, (sum, w) => sum + w.amountKg);

  /// The weights as rows for a new dive, under fresh ids so the copies are
  /// independent of the source dive once applied.
  List<DiveWeight> weightsForNewDive({
    required String diveId,
    required String Function() newId,
  }) => [
    for (final w in weights)
      DiveWeight(
        id: newId(),
        diveId: diveId,
        weightType: w.weightType,
        amountKg: w.amountKg,
        notes: w.notes,
      ),
  ];

  /// The cylinders as rows for a new dive: the rig (size, rating, preset,
  /// material, mix, role, order) travels; the pressures do not, because the
  /// new dive has not happened yet, and neither do the computer, transmitter
  /// and owned-gear links, which describe the old dive's hardware.
  List<DiveTank> tanksForNewDive({
    required String Function() newId,
    required double startPressure,
    required double endPressure,
  }) => [
    for (final t in tanks)
      DiveTank(
        id: newId(),
        name: t.name,
        volume: t.volume,
        workingPressure: t.workingPressure,
        startPressure: startPressure,
        endPressure: endPressure,
        gasMix: t.gasMix,
        role: t.role,
        material: t.material,
        order: t.order,
        presetName: t.presetName,
        decoSwitchDepth: t.decoSwitchDepth,
        isTravelGas: t.isTravelGas,
      ),
  ];

  @override
  List<Object?> get props => [
    diveId,
    dateTime,
    weights,
    weightingFeedback,
    weightingFeedbackKg,
    tanks,
  ];
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_centers/domain/`
Expected: all tests PASS. If the tank test fails on a `GasMix` constructor name (the field may be `o2Percent` rather than `oxygen`), read `class GasMix` in `dive.dart` and fix the test, not the code.

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_centers/domain/entities/dive_center_gear_note.dart lib/features/dive_centers/domain/services/rental_memory_resolver.dart test/features/dive_centers/domain/entities/dive_center_gear_note_test.dart test/features/dive_centers/domain/services/rental_memory_resolver_test.dart
git commit -m "feat(dive-centers): rental gear note entity and last-dive value object"
```

---

### Task 2: Schema v221, the `dive_center_gear_notes` table

**Files:**
- Modify: `lib/core/database/database.dart` (table after `WeightPresetEntries` ~line 1412; `@DriftDatabase` tables list ~line 4199; `currentSchemaVersion` line 4211; `migrationVersions` tail ~line 4283; the v219 rung ~line 12254; `beforeOpen` backstops ~line 12379; `_assertChildHlcColumns` list ~line 5242; new helper next to `_assertEquipmentTagSchema` ~line 8271)
- Modify: `test/core/database/migration_v219_equipment_tags_test.dart:92`
- Test: `test/core/database/migration_v221_dive_center_gear_notes_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: Drift table `DiveCenterGearNotes` (getter `db.diveCenterGearNotes`), row class `DiveCenterGearNoteRow`, companion `DiveCenterGearNotesCompanion` with fields `id, diveCenterId, gearType, label, size, verdict, leadAdjustmentKg, volumeLiters, note, diveId, notedAt, createdAt, updatedAt, hlc`; `AppDatabase.currentSchemaVersion == 221`.

- [ ] **Step 1: Re-check the rung**

Run the two commands from Global Constraints. If main is still at 219 and no open PR claims 221, continue with 221.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v221_dive_center_gear_notes_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v221: rental gear memory, the dive_center_gear_notes table
/// (issue #2075).
void main() {
  /// A v219 database with the two parents the new table references and
  /// the tables the beforeOpen backstops touch, and no
  /// dive_center_gear_notes.
  NativeDatabase setupDb({
    int userVersion = 219,
    bool withDiveCenters = true,
  }) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        if (withDiveCenters) {
          rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        }
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  test('v221 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 221);
    expect(AppDatabase.migrationVersions, contains(221));
    expect(AppDatabase.migrationStepCount(219), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('adds the dive_center_gear_notes table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'dive_center_gear_notes'),
      containsAll(<String>[
        'id',
        'dive_center_id',
        'gear_type',
        'label',
        'size',
        'verdict',
        'lead_adjustment_kg',
        'volume_liters',
        'note',
        'dive_id',
        'noted_at',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('the table cascades from its center and detaches from a dive', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final ddl = await ddlOf(db, 'table', 'dive_center_gear_notes');
    expect(ddl, contains('REFERENCES dive_centers (id) ON DELETE CASCADE'));
    expect(ddl, contains('REFERENCES dives (id) ON DELETE SET NULL'));
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'dive_center_gear_notes'),
      await tableInfo(fresh, 'dive_center_gear_notes'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'dive_center_gear_notes'),
      await ddlOf(fresh, 'table', 'dive_center_gear_notes'),
    );
  });

  test(
    'a database stamped v221 without the table heals in beforeOpen',
    () async {
      // A parallel branch that claimed 221 first carries a device past the
      // rung; the beforeOpen backstop must build what the rung would have.
      final db = AppDatabase(setupDb(userVersion: 221));
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'dive_center_gear_notes'),
        contains('dive_center_id'),
      );
    },
  );

  test('a fixture without dive_centers skips the table', () async {
    final db = AppDatabase(setupDb(withDiveCenters: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'dive_center_gear_notes'), isEmpty);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v221_dive_center_gear_notes_test.dart`
Expected: FAIL on the first test (`currentSchemaVersion` is 219) and the table tests (empty column set).

- [ ] **Step 4: Add the table**

In `lib/core/database/database.dart`, directly after the closing brace of `class WeightPresetEntries extends Table` (about line 1412), add:

```dart
/// Rental gear memory (v221, issue #2075): what a diver learned about a dive
/// center's rental gear, kept per center so it surfaces on a return visit.
/// The note is the diver's judgement; the numbers of the last dive at the
/// center (lead, feedback, tanks) are read off that dive, never copied here.
@DataClassName('DiveCenterGearNoteRow')
class DiveCenterGearNotes extends Table {
  TextColumn get id => text()();
  TextColumn get diveCenterId =>
      text().references(DiveCenters, #id, onDelete: KeyAction.cascade)();

  /// EquipmentType.name of the rental item.
  TextColumn get gearType => text()();

  /// The operator's mark for the item: "14", "AL80".
  TextColumn get label => text().nullable()();
  TextColumn get size => text().nullable()();

  /// RentalVerdict.name: worked or avoid.
  TextColumn get verdict => text()();

  /// Signed kg: lead needed beyond the diver's usual with this gear.
  RealColumn get leadAdjustmentKg => real().nullable()();

  /// The cylinder's true capacity, for tank notes.
  RealColumn get volumeLiters => real().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The dive the note was written on, if any; the note outlives it.
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  IntColumn get notedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// This child's own clock, stamped when it is marked pending, so the merge
  /// refuses a remote copy strictly older than the local one
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
```

- [ ] **Step 5: Register the table, bump the version, add the rung**

In the `@DriftDatabase(tables: [...])` list, after `CylinderConfigItems,` (about line 4199) add:

```dart
    // Rental gear memory (v221, issue #2075)
    DiveCenterGearNotes,
```

Change line 4211:

```dart
  static const int currentSchemaVersion = 221;
```

At the tail of `migrationVersions`, after `    219,` add:

```dart
    // v221: rental gear memory (issue #2075). dive_center_gear_notes, a
    // child of dive_centers. Table-only rung, no backfill, so the
    // compatibility floor stays. Takes 221, not 220: three open PRs held
    // 220 when this landed, and a rung at or below the shipped version
    // never runs its onUpgrade step.
    221,
```

In `onUpgrade`, directly after `if (from < 219) await reportProgress();` add:

```dart
        // v221: rental gear memory (issue #2075). Table-only rung, no
        // backfill.
        if (from < 221) {
          await _assertDiveCenterGearNotesSchema();
        }
        if (from < 221) await reportProgress();
```

In `beforeOpen`, directly after the `await _assertEquipmentTagSchema();` backstop (about line 12379) add:

```dart
        // v221 backstop: the rental gear notes table (parallel-branch
        // version-collision self-heal; createTable is idempotent).
        await _assertDiveCenterGearNotesSchema();
```

In `_assertChildHlcColumns`, add `'dive_center_gear_notes',` after `'gas_switches',` in the list (the column is created with the table; the entry keeps the parent-gated list and this list in step).

Next to `_assertEquipmentTagSchema` (about line 8271) add:

```dart
  /// Idempotent creation of the v221 `dive_center_gear_notes` table (issue
  /// #2075). Called from the v221 rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain a table
  /// whose foreign keys point nowhere.
  Future<void> _assertDiveCenterGearNotesSchema() async {
    for (final parent in const ['dive_centers', 'dives']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await createMigrator().createTable(diveCenterGearNotes);
  }
```

- [ ] **Step 6: Relax the v219 tripwire**

In `test/core/database/migration_v219_equipment_tags_test.dart` line 92, change

```dart
    expect(AppDatabase.currentSchemaVersion, 219);
```

to

```dart
    // Relaxed once v221 (rental gear memory) landed on top; the newest rung
    // owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(219));
```

- [ ] **Step 7: Regenerate Drift and run the migration tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v221_dive_center_gear_notes_test.dart test/core/database/migration_v219_equipment_tags_test.dart test/core/database/migration_v218_site_detail_sections_test.dart
```

Expected: all PASS. If the cascade DDL assertion fails on spacing, print the DDL (`print(ddl)`) once, match Drift's exact `REFERENCES dive_centers (id) ON DELETE CASCADE` spelling, and remove the print.

- [ ] **Step 8: Run the sync registration pin tests to see what Task 3 owes**

Run: `flutter test test/core/services/sync/sync_hlc_target_registration_test.dart`
Expected: FAIL on "every table with an hlc column is registered in hlcTargets" naming `dive_center_gear_notes`. That failure is Task 3's first red test; do not fix it here.

- [ ] **Step 9: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart test/core/database/migration_v221_dive_center_gear_notes_test.dart test/core/database/migration_v219_equipment_tags_test.dart
git commit -m "feat(database): schema v221, the dive_center_gear_notes table (#2075)"
```

---

### Task 3: Sync registration for `diveCenterGearNotes`

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`, the v210 parent-gated block after `'weightPresetEntries'` ~line 142)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`SyncData` field ~284, constructor default ~379, `toJson` ~469, `fromJson` ~560, `_baseTables` ~894, `_buildSyncData` ~1776, `parentGatedChildEntities` ~1471, `parentGatedTables` ~1527, `fetchRecord` ~2339, `fetchRecords` ~2741, `upsertRecord` ~3630, `upsertRecords` ~4480, id selector ~5212, `TableInfo` switch ~5596, `deleteRecord` ~5941, and a new `_exportDiveCenterGearNotes` next to `_exportDiveCenters` ~6669)
- Modify: `lib/core/services/sync/sync_service.dart` (apply order ~1274, `entityHasUpdatedAt` ~2297, `parentRefs` ~2434)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` map ~line 29)
- Test: `test/core/services/sync/dive_center_gear_notes_sync_test.dart` (create)

**Interfaces:**
- Consumes: Task 2's `db.diveCenterGearNotes` and `DiveCenterGearNoteRow`.
- Produces: entity type `'diveCenterGearNotes'` accepted by `SyncDataSerializer.upsertRecord / upsertRecords / fetchRecord / fetchRecords / deleteRecord / recordIdsFor`, carried by `SyncData.diveCenterGearNotes`, applied by `SyncService` after `diveCenters`.

Every occurrence of `diveCenters` in the serializer and the service is the anchor: the new entity goes immediately after it in each list so the payload order, the base-table order and the apply order agree (three tests pin those orders).

- [ ] **Step 1: Write the failing sync test**

Create `test/core/services/sync/dive_center_gear_notes_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// diveCenterGearNotes is a parent-gated child of diveCenters (issue #2075):
/// own id, own hlc, exported with its center and on its own when pending,
/// applied after diveCenters and dives.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> noteJson(String id, {String? diveId}) => {
    'id': id,
    'diveCenterId': 'c1',
    'gearType': 'regulator',
    'label': '14',
    'size': null,
    'verdict': 'avoid',
    'leadAdjustmentKg': null,
    'volumeLiters': null,
    'note': 'wet',
    'diveId': diveId,
    'notedAt': 1000,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertCenter(String id) =>
      serializer.upsertRecord('diveCenters', {
        'id': id,
        'name': id,
        'affiliations': '',
        'notes': '',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('is registered everywhere a parent-gated child must be', () {
    expect(
      SyncRepository.hlcTargets['diveCenterGearNotes'],
      (table: 'dive_center_gear_notes', pk: 'id'),
    );
    expect(
      SyncDataSerializer.parentGatedChildEntities,
      contains('diveCenterGearNotes'),
    );
    expect(
      SyncDataSerializer.parentGatedTables['diveCenterGearNotes'],
      'dive_center_gear_notes',
    );
    expect(SyncService.entityHasUpdatedAt['diveCenterGearNotes'], isFalse);
    expect(SyncService.parentRefs['diveCenterGearNotes'], [
      (field: 'diveCenterId', parent: 'diveCenters', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: true),
    ]);
  });

  test('SyncData carries the entity right after diveCenters', () {
    final keys = const SyncData().toJson().keys.toList();
    expect(keys.indexOf('diveCenterGearNotes'), keys.indexOf('diveCenters') + 1);
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      contains('diveCenterGearNotes'),
    );
    expect(
      SyncData.fromJson({
        'diveCenterGearNotes': [noteJson('n1')],
      }).diveCenterGearNotes,
      hasLength(1),
    );
  });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertCenter('c1');
    await serializer.upsertRecord('diveCenterGearNotes', noteJson('n1'));

    final row = await serializer.fetchRecord('diveCenterGearNotes', 'n1');
    expect(row, isNotNull);
    expect(row!['diveCenterId'], 'c1');
    expect(row['gearType'], 'regulator');
    expect(row['verdict'], 'avoid');
    expect(row['label'], '14');
    expect(row['note'], 'wet');

    await serializer.deleteRecord('diveCenterGearNotes', 'n1');
    expect(await serializer.fetchRecord('diveCenterGearNotes', 'n1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertCenter('c1');
    await serializer.upsertRecords('diveCenterGearNotes', [
      noteJson('n1'),
      noteJson('n2'),
    ]);
    final fetched = await serializer.fetchRecords('diveCenterGearNotes', [
      'n1',
      'n2',
    ]);
    expect(fetched.keys, containsAll(['n1', 'n2']));
    expect(
      await serializer.recordIdsFor('diveCenterGearNotes'),
      containsAll(['n1', 'n2']),
    );
  });

  test('a note whose center moved is exported by watermark', () async {
    await insertCenter('c1');
    await serializer.upsertRecord('diveCenterGearNotes', noteJson('n1'));
    // Stamp the center so its hlc is above the old watermark.
    await SyncRepository().markRecordPending(
      entityType: 'diveCenters',
      recordId: 'c1',
      localUpdatedAt: 2000,
    );
    final since = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '000000000000000:000000:0',
      deletions: const [],
    );
    expect(
      since.data.diveCenterGearNotes.map((r) => r['id']),
      contains('n1'),
    );
    final base = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(base.data.diveCenterGearNotes.map((r) => r['id']), contains('n1'));
  });
}
```

- [ ] **Step 2: Run it and the pin tests to verify they fail**

Run: `flutter test test/core/services/sync/dive_center_gear_notes_sync_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart`
Expected: FAIL: `hlcTargets['diveCenterGearNotes']` is null, `SyncData` has no such getter (compile error in the test is the expected red here), the census test names the unregistered table.

- [ ] **Step 3: Register the HLC target**

In `lib/core/data/repositories/sync_repository.dart`, in `hlcTargets`, after `'weightPresetEntries': (table: 'weight_preset_entries', pk: 'id'),` add:

```dart
    'diveCenterGearNotes': (table: 'dive_center_gear_notes', pk: 'id'),
```

- [ ] **Step 4: Carry the entity in `SyncData`**

In `lib/core/services/sync/sync_data_serializer.dart`, make these edits, each immediately after the `diveCenters` line at the quoted location:

After `  final List<Map<String, dynamic>> diveCenters;` (~284):

```dart
  final List<Map<String, dynamic>> diveCenterGearNotes;
```

After `    this.diveCenters = const [],` (~379):

```dart
    this.diveCenterGearNotes = const [],
```

After `    'diveCenters': diveCenters,` in `toJson` (~469):

```dart
    'diveCenterGearNotes': diveCenterGearNotes,
```

After `      diveCenters: _parseList(json['diveCenters']),` in `fromJson` (~560):

```dart
      diveCenterGearNotes: _parseList(json['diveCenterGearNotes']),
```

After `    (key: 'diveCenters', table: _db.diveCenters, blob: false, full: null),` in `_baseTables` (~894):

```dart
    (
      key: 'diveCenterGearNotes',
      table: _db.diveCenterGearNotes,
      blob: false,
      full: null,
    ),
```

In `_buildSyncData`, after the `diveCenters: await _safeExport(...)` argument (~1776 to 1779):

```dart
      diveCenterGearNotes: await _safeExport(
        'diveCenterGearNotes',
        () async => _withPendingChildren(
          'diveCenterGearNotes',
          await _exportDiveCenterGearNotes(hlcSince),
          pendingChildren,
        ),
      ),
```

- [ ] **Step 5: Parent-gated sets and the export query**

In `parentGatedChildEntities` add `'diveCenterGearNotes',` after `'weightPresetEntries',`. In `parentGatedTables` add `'diveCenterGearNotes': 'dive_center_gear_notes',` after the `weightPresetEntries` entry. Nothing goes in `_parentGatedKeyColumns` (single `id` key).

Next to `_exportDiveCenters` add:

```dart
  /// Rental gear notes ride their center: an incremental export re-sends
  /// the whole note set of every center whose hlc moved, mirroring
  /// [_exportWeightPresetEntries]. A note edited on its own reaches peers
  /// through the pending-children path.
  Future<List<Map<String, dynamic>>> _exportDiveCenterGearNotes(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final modified = await (_db.select(
        _db.diveCenters,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final ids = modified.map((c) => c.id).toSet();
      if (ids.isEmpty) return [];
      final rows = await (_db.select(
        _db.diveCenterGearNotes,
      )..where((t) => t.diveCenterId.isIn(ids))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.diveCenterGearNotes).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- [ ] **Step 6: The per-record switches**

Add a `case 'diveCenterGearNotes':` arm directly after the `case 'diveCenters':` arm in each of these switches, shaped like the `weightPresetEntries` arms:

`fetchRecord` (~2339):

```dart
      case 'diveCenterGearNotes':
        final row = await (_db.select(
          _db.diveCenterGearNotes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

`fetchRecords` (~2741):

```dart
      case 'diveCenterGearNotes':
        final rows = await (_db.select(
          _db.diveCenterGearNotes,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

`upsertRecord` (~3630):

```dart
      case 'diveCenterGearNotes':
        await _db
            .into(_db.diveCenterGearNotes)
            .insertOnConflictUpdate(DiveCenterGearNoteRow.fromJson(data));
        return;
```

`upsertRecords` (~4480):

```dart
      case 'diveCenterGearNotes':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.diveCenterGearNotes,
            records.map((r) => DiveCenterGearNoteRow.fromJson(r)).toList(),
          ),
        );
        return;
```

Id selector (~5212):

```dart
      case 'diveCenterGearNotes':
        return plain(_db.diveCenterGearNotes, _db.diveCenterGearNotes.id);
```

`TableInfo` switch (~5596):

```dart
      case 'diveCenterGearNotes':
        return _db.diveCenterGearNotes;
```

`deleteRecord` (~5941):

```dart
      case 'diveCenterGearNotes':
        await (_db.delete(
          _db.diveCenterGearNotes,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

If the variable names in a switch differ from `recordId`, `idList`, `data` or `records` at that location, use the names the neighbouring `diveCenters` arm uses. If `DiveCenterGearNoteRow.fromJson(data)` is rejected by `insertOnConflictUpdate`, append `.toCompanion(false)` as the `diveCenters` arm does.

- [ ] **Step 7: The service**

In `lib/core/services/sync/sync_service.dart`:

After `(type: 'diveCenters', records: data.diveCenters, hasUpdatedAt: true),` (~1274):

```dart
          // Child of diveCenters (and optionally dives); applied after both
          // so the deferred-FK commit sees the parent rows.
          (
            type: 'diveCenterGearNotes',
            records: data.diveCenterGearNotes,
            hasUpdatedAt: false,
          ),
```

If `dives` is applied later in that list than `diveCenters`, move the new entry to directly after the `dives` entry instead, and keep the comment.

After `'diveCenters': true,` in `entityHasUpdatedAt` (~2297):

```dart
    'diveCenterGearNotes': false,
```

In `parentRefs`, after the `'dives': [...]` entry (~2435):

```dart
    'diveCenterGearNotes': [
      (field: 'diveCenterId', parent: 'diveCenters', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: true),
    ],
```

- [ ] **Step 8: The completeness test's table map**

In `test/core/services/sync/sync_parent_refs_completeness_test.dart`, in `syncedTables`, after `'dive_centers': 'diveCenters',` add:

```dart
    'dive_center_gear_notes': 'diveCenterGearNotes',
```

- [ ] **Step 9: Run every sync pin test**

Run: `flutter test test/core/services/sync/dive_center_gear_notes_sync_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/child_hlc_test.dart test/core/services/sync/pending_child_export_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: all PASS. A failure in the two parity tests means the new key's position differs between `toJson` and `_baseTables`; put it directly after `diveCenters` in both.

- [ ] **Step 10: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/dive_center_gear_notes_sync_test.dart
git commit -m "feat(sync): carry dive center gear notes as a parent-gated child (#2075)"
```

---

### Task 4: Repository, the latest-dive query and the providers

**Files:**
- Create: `lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart`
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (`deleteDiveCenter` ~line 222; new method after `getDiveCountForCenter` ~line 273)
- Create: `lib/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart`
- Test: `test/features/dive_centers/data/repositories/dive_center_gear_note_repository_test.dart` (create)
- Test: `test/features/dive_centers/data/repositories/dive_center_repository_latest_dive_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's `DiveCenterGearNote`, `RentalVerdict`, `LastDiveAtCenter`; Task 2's table; `DiveRepository.getDiveById` and `watchDivesChanges` (existing); `SyncRepository.markRecordPending` and `logDeletion` (existing).
- Produces: `class DiveCenterGearNoteRepository` with `Stream<void> watchChanges()`, `Future<List<DiveCenterGearNote>> getForCenter(String centerId)` (newest `notedAt` first), `Future<DiveCenterGearNote?> getById(String id)`, `Future<DiveCenterGearNote> create(DiveCenterGearNote note)` (assigns the id when `note.id` is empty), `Future<void> update(DiveCenterGearNote note)`, `Future<void> delete(String id)`; `DiveCenterRepository.latestDiveIdAtCenter(String centerId, {String? excludingDiveId})` returning `Future<String?>`; providers `diveCenterGearNoteRepositoryProvider`, `diveCenterGearNotesProvider(centerId)` (`FutureProvider.family<List<DiveCenterGearNote>, String>`), `typedef LastDiveAtCenterQuery = ({String centerId, String? excludingDiveId})`, `lastDiveAtCenterProvider(query)` (`FutureProvider.family<LastDiveAtCenter?, LastDiveAtCenterQuery>`).

- [ ] **Step 1: Write the failing repository test**

Create `test/features/dive_centers/data/repositories/dive_center_gear_note_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveCenterGearNoteRepository repository;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveCenterGearNoteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  Future<void> seedDive(String id, {String? centerId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(stale),
          diveCenterId: Value(centerId),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  DiveCenterGearNote note({
    String id = '',
    String centerId = 'c1',
    EquipmentType type = EquipmentType.regulator,
    String? diveId,
    DateTime? notedAt,
  }) {
    final now = DateTime.utc(2026, 9, 18, 10);
    return DiveCenterGearNote(
      id: id,
      diveCenterId: centerId,
      gearType: type,
      label: '14',
      verdict: RentalVerdict.avoid,
      leadAdjustmentKg: 2,
      note: 'wet',
      diveId: diveId,
      notedAt: notedAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> pendingCountFor(String recordId) async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = "
                "'diveCenterGearNotes' AND record_id = ? "
                "AND sync_status = 'pending'",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  Future<int> tombstoneCountFor(String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = '
                "'diveCenterGearNotes' AND record_id = ?",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  test('create assigns an id, stores every field and marks pending', () async {
    await seedCenter('c1');
    await seedDive('d1', centerId: 'c1');

    final created = await repository.create(note(diveId: 'd1'));

    expect(created.id, isNotEmpty);
    final stored = await repository.getById(created.id);
    expect(stored, isNotNull);
    expect(stored!.diveCenterId, 'c1');
    expect(stored.gearType, EquipmentType.regulator);
    expect(stored.label, '14');
    expect(stored.size, isNull);
    expect(stored.verdict, RentalVerdict.avoid);
    expect(stored.leadAdjustmentKg, 2);
    expect(stored.volumeLiters, isNull);
    expect(stored.note, 'wet');
    expect(stored.diveId, 'd1');
    expect(stored.notedAt, DateTime.utc(2026, 9, 18, 10));
    expect(await pendingCountFor(created.id), 1);
  });

  test('getForCenter lists newest noted first and only that center', () async {
    await seedCenter('c1');
    await seedCenter('c2');
    final older = await repository.create(
      note(notedAt: DateTime.utc(2026, 1, 1)),
    );
    final newer = await repository.create(
      note(notedAt: DateTime.utc(2026, 6, 1), type: EquipmentType.bcd),
    );
    await repository.create(note(centerId: 'c2'));

    final notes = await repository.getForCenter('c1');
    expect(notes.map((n) => n.id), [newer.id, older.id]);
  });

  test('update rewrites the row and marks it pending again', () async {
    await seedCenter('c1');
    final created = await repository.create(note());

    await repository.update(
      created.copyWith(
        verdict: RentalVerdict.worked,
        size: 'L',
        clearLeadAdjustment: true,
        volumeLiters: 11.1,
        note: 'fine after service',
      ),
    );

    final stored = await repository.getById(created.id);
    expect(stored!.verdict, RentalVerdict.worked);
    expect(stored.size, 'L');
    expect(stored.leadAdjustmentKg, isNull);
    expect(stored.volumeLiters, 11.1);
    expect(stored.note, 'fine after service');
    expect(stored.updatedAt.isBefore(created.updatedAt), isFalse);
    expect(await pendingCountFor(created.id), 1);
  });

  test('delete removes the row and writes a tombstone', () async {
    await seedCenter('c1');
    final created = await repository.create(note());

    await repository.delete(created.id);

    expect(await repository.getById(created.id), isNull);
    expect(await tombstoneCountFor(created.id), 1);
  });

  test('deleting the dive it was noted on keeps the note, detached', () async {
    await seedCenter('c1');
    await seedDive('d1', centerId: 'c1');
    final created = await repository.create(note(diveId: 'd1'));

    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();

    final stored = await repository.getById(created.id);
    expect(stored, isNotNull);
    expect(stored!.diveId, isNull);
  });

  test('deleting the center cascades its notes and tombstones each', () async {
    await seedCenter('c1');
    final a = await repository.create(note());
    final b = await repository.create(note(type: EquipmentType.wetsuit));

    await DiveCenterRepository().deleteDiveCenter('c1');

    expect(await repository.getForCenter('c1'), isEmpty);
    expect(await tombstoneCountFor(a.id), 1);
    expect(await tombstoneCountFor(b.id), 1);
  });

  test('watchChanges emits after a write', () async {
    await seedCenter('c1');
    final events = <void>[];
    final sub = repository.watchChanges().listen(events.add);
    addTearDown(sub.cancel);

    await repository.create(note());
    await Future<void>.delayed(Duration.zero);

    expect(events, isNotEmpty);
  });
}
```

- [ ] **Step 2: Write the failing latest-dive test**

Create `test/features/dive_centers/data/repositories/dive_center_repository_latest_dive_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';

import '../../../../helpers/test_database.dart';

/// The "last time here" lookup (issue #2075): the newest real dive logged
/// with a center, skipping the dive being edited and planned dives.
void main() {
  late AppDatabase db;
  late DiveCenterRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveCenterRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> seedDive(
    String id, {
    required String centerId,
    required int at,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at),
          diveCenterId: Value(centerId),
          isPlanned: Value(planned),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  test('returns the newest dive at the center', () async {
    await seedCenter('c1');
    await seedCenter('c2');
    await seedDive('old', centerId: 'c1', at: 1000);
    await seedDive('new', centerId: 'c1', at: 3000);
    await seedDive('other', centerId: 'c2', at: 9000);

    expect(await repository.latestDiveIdAtCenter('c1'), 'new');
  });

  test('skips the dive being edited', () async {
    await seedCenter('c1');
    await seedDive('old', centerId: 'c1', at: 1000);
    await seedDive('new', centerId: 'c1', at: 3000);

    expect(
      await repository.latestDiveIdAtCenter('c1', excludingDiveId: 'new'),
      'old',
    );
  });

  test('skips planned dives and returns null when nothing is left', () async {
    await seedCenter('c1');
    await seedDive('plan', centerId: 'c1', at: 5000, planned: true);

    expect(await repository.latestDiveIdAtCenter('c1'), isNull);
  });
}
```

If `DivesCompanion` has no `isPlanned` field, grep `database.dart` for `is_planned` to find the Drift column name (for example `isPlanned` or `planned`) and use it.

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/dive_centers/data/repositories/dive_center_gear_note_repository_test.dart test/features/dive_centers/data/repositories/dive_center_repository_latest_dive_test.dart`
Expected: FAIL to compile: no `DiveCenterGearNoteRepository`, no `latestDiveIdAtCenter`.

- [ ] **Step 4: Write the repository**

Create `lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

/// CRUD for a dive center's rental gear notes (issue #2075). Mirrors
/// [WeightPresetRepository]: HLC-stamped writes, a change stream for the
/// providers, and per-row sync bookkeeping after the write.
class DiveCenterGearNoteRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveCenterGearNoteRepository);

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveCenterGearNotes));

  /// The center's notes, newest observation first.
  Future<List<DiveCenterGearNote>> getForCenter(String centerId) async {
    final rows =
        await (_db.select(_db.diveCenterGearNotes)
              ..where((t) => t.diveCenterId.equals(centerId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.notedAt),
                (t) => OrderingTerm.desc(t.createdAt),
              ]))
            .get();
    return rows.map(fromRow).toList();
  }

  Future<DiveCenterGearNote?> getById(String id) async {
    final row = await (_db.select(
      _db.diveCenterGearNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  /// Insert [note]; an empty id is replaced with a fresh uuid.
  Future<DiveCenterGearNote> create(DiveCenterGearNote note) async {
    try {
      final id = note.id.isEmpty ? _uuid.v4() : note.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.diveCenterGearNotes)
          .insert(
            DiveCenterGearNotesCompanion(
              id: Value(id),
              diveCenterId: Value(note.diveCenterId),
              gearType: Value(note.gearType.name),
              label: Value(_trimmedOrNull(note.label)),
              size: Value(_trimmedOrNull(note.size)),
              verdict: Value(note.verdict.name),
              leadAdjustmentKg: Value(note.leadAdjustmentKg),
              volumeLiters: Value(note.volumeLiters),
              note: Value(note.note.trim()),
              diveId: Value(note.diveId),
              notedAt: Value(note.notedAt.millisecondsSinceEpoch),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveCenterGearNotes',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return (await getById(id))!;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create rental gear note for ${note.diveCenterId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> update(DiveCenterGearNote note) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveCenterGearNotes,
      )..where((t) => t.id.equals(note.id))).write(
        DiveCenterGearNotesCompanion(
          gearType: Value(note.gearType.name),
          label: Value(_trimmedOrNull(note.label)),
          size: Value(_trimmedOrNull(note.size)),
          verdict: Value(note.verdict.name),
          leadAdjustmentKg: Value(note.leadAdjustmentKg),
          volumeLiters: Value(note.volumeLiters),
          note: Value(note.note.trim()),
          diveId: Value(note.diveId),
          notedAt: Value(note.notedAt.millisecondsSinceEpoch),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveCenterGearNotes',
        recordId: note.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update rental gear note ${note.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.diveCenterGearNotes,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'diveCenterGearNotes',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete rental gear note $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String? _trimmedOrNull(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static DiveCenterGearNote fromRow(DiveCenterGearNoteRow row) =>
      DiveCenterGearNote(
        id: row.id,
        diveCenterId: row.diveCenterId,
        gearType: DiveCenterGearNote.gearTypeFromName(row.gearType),
        label: row.label,
        size: row.size,
        verdict: DiveCenterGearNote.verdictFromName(row.verdict),
        leadAdjustmentKg: row.leadAdjustmentKg,
        volumeLiters: row.volumeLiters,
        note: row.note,
        diveId: row.diveId,
        notedAt: DateTime.fromMillisecondsSinceEpoch(row.notedAt, isUtc: true),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
      );
}
```

- [ ] **Step 5: The center repository: latest dive, and tombstones on center delete**

In `lib/features/dive_centers/data/repositories/dive_center_repository.dart`, after `getDiveCountForCenter` add:

```dart
  /// The newest real dive logged with [centerId], skipping planned dives
  /// and [excludingDiveId] (the dive being edited), for the "last time
  /// here" card (issue #2075). Null when the diver has no other dive there.
  Future<String?> latestDiveIdAtCenter(
    String centerId, {
    String? excludingDiveId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT id FROM dives
      WHERE dive_center_id = ?
        AND is_planned = 0
        AND (? IS NULL OR id <> ?)
      ORDER BY dive_date_time DESC, id DESC
      LIMIT 1
    ''',
          variables: [
            Variable.withString(centerId),
            Variable<String>(excludingDiveId),
            Variable<String>(excludingDiveId),
          ],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('id');
  }
```

Then in `deleteDiveCenter`, inside the transaction and before the `_db.delete(_db.diveCenters)` line, add the note tombstones (SQLite cascades emit no deletion-log rows, so a peer would resurrect the notes):

```dart
        final notes = await (_db.select(
          _db.diveCenterGearNotes,
        )..where((t) => t.diveCenterId.equals(id))).get();
```

and after the existing `logDeletion(entityType: 'diveCenters', ...)` call, still inside the transaction:

```dart
        for (final note in notes) {
          await _syncRepository.logDeletion(
            entityType: 'diveCenterGearNotes',
            recordId: note.id,
          );
        }
```

Update the method's doc comment to mention that its rental gear notes are cascaded and tombstoned.

- [ ] **Step 6: Run the repository tests**

Run: `flutter test test/features/dive_centers/data/repositories/`
Expected: all PASS, including the pre-existing dive center repository tests.

- [ ] **Step 7: Write the providers**

Create `lib/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final diveCenterGearNoteRepositoryProvider =
    Provider<DiveCenterGearNoteRepository>((ref) {
      return DiveCenterGearNoteRepository();
    });

/// A center's rental gear notes, newest first. Self-invalidates on any
/// write to the table, local or synced.
final diveCenterGearNotesProvider =
    FutureProvider.family<List<DiveCenterGearNote>, String>((
      ref,
      centerId,
    ) async {
      final repository = ref.watch(diveCenterGearNoteRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getForCenter(centerId);
    });

/// Which center, and which dive to leave out (the one being edited).
typedef LastDiveAtCenterQuery = ({String centerId, String? excludingDiveId});

/// The diver's most recent other dive at a center, fully hydrated, or null.
/// Reads the `dives` table, so it self-invalidates on dive changes.
final lastDiveAtCenterProvider =
    FutureProvider.family<LastDiveAtCenter?, LastDiveAtCenterQuery>((
      ref,
      query,
    ) async {
      final centers = ref.watch(diveCenterRepositoryProvider);
      final dives = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(dives.watchDivesChanges());
      final id = await centers.latestDiveIdAtCenter(
        query.centerId,
        excludingDiveId: query.excludingDiveId,
      );
      if (id == null) return null;
      final dive = await dives.getDiveById(id);
      return dive == null ? null : LastDiveAtCenter.fromDive(dive);
    });
```

If `invalidateSelfWhen` is not reachable through `core/providers/provider.dart`, add `import 'package:submersion/core/providers/ref_invalidate_on_change.dart';`.

- [ ] **Step 8: Analyze, format and commit**

```bash
flutter analyze
dart format .
git add lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart lib/features/dive_centers/data/repositories/dive_center_repository.dart lib/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart test/features/dive_centers/data/repositories/dive_center_gear_note_repository_test.dart test/features/dive_centers/data/repositories/dive_center_repository_latest_dive_test.dart
git commit -m "feat(dive-centers): rental gear note repository, latest-dive lookup and providers (#2075)"
```

---

### Task 5: Localized strings in all 11 locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (12 files, committed)
- Test: `test/l10n/rental_gear_memory_strings_test.dart` (create)

**Interfaces:**
- Produces the `AppLocalizations` getters listed in the table below. Later tasks call them through `context.l10n`.

| Key | English |
| --- | --- |
| `diveCenters_rental_sectionTitle` | Rental gear |
| `diveCenters_rental_lastTimeAt` | Last time at {center} |
| `diveCenters_rental_lastDiveOn` | Last dive here: {date} |
| `diveCenters_rental_noHistory` | No other dives logged here yet. |
| `diveCenters_rental_empty` | No rental notes for this center yet. |
| `diveCenters_rental_addNote` | Add rental note |
| `diveCenters_rental_applyLastDive` | Apply last dive |
| `diveCenters_rental_applied` | Weights and tanks copied from your last dive here. |
| `diveCenters_rental_applyConfirmTitle` | Replace weights and tanks? |
| `diveCenters_rental_applyConfirmBody` | This dive already has weights or tanks. Replace them with the ones from your last dive here? |
| `diveCenters_rental_applyConfirmReplace` | Replace |
| `diveCenters_rental_leadTotal` | Lead: {total} |
| `diveCenters_rental_feedbackOver` | {amount} over |
| `diveCenters_rental_feedbackUnder` | {amount} under |
| `diveCenters_rental_tanksLabel` | Tanks |
| `diveCenters_rental_verdictWorked` | Worked |
| `diveCenters_rental_verdictAvoid` | Avoid |
| `diveCenters_rental_extraLead` | {amount} extra lead |
| `diveCenters_rental_lessLead` | {amount} less lead |
| `diveCenters_rental_actualCapacity` | Actual capacity {volume} |
| `diveCenters_rental_sheetTitleNew` | New rental note |
| `diveCenters_rental_sheetTitleEdit` | Edit rental note |
| `diveCenters_rental_gearTypeLabel` | Gear type |
| `diveCenters_rental_labelLabel` | Label or number |
| `diveCenters_rental_sizeLabel` | Size |
| `diveCenters_rental_leadAdjustmentLabel` | Extra lead needed ({unit}) |
| `diveCenters_rental_volumeLabel` | Actual capacity ({unit}) |
| `diveCenters_rental_noteLabel` | Note |
| `diveCenters_rental_deleteConfirm` | Delete this rental note? |

Existing keys reused, not added: `common_action_save`, `common_action_cancel`, `common_action_delete`, `diveLog_edit_weightFeedback_correct`, `diveLog_edit_weightFeedback_over`, `diveLog_edit_weightFeedback_under`.

- [ ] **Step 1: Write the failing strings test**

Create `test/l10n/rental_gear_memory_strings_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every rental gear memory string (issue #2075) exists in every locale, so
/// gen-l10n never falls back to English for one of them.
void main() {
  const keys = [
    'diveCenters_rental_sectionTitle',
    'diveCenters_rental_lastTimeAt',
    'diveCenters_rental_lastDiveOn',
    'diveCenters_rental_noHistory',
    'diveCenters_rental_empty',
    'diveCenters_rental_addNote',
    'diveCenters_rental_applyLastDive',
    'diveCenters_rental_applied',
    'diveCenters_rental_applyConfirmTitle',
    'diveCenters_rental_applyConfirmBody',
    'diveCenters_rental_applyConfirmReplace',
    'diveCenters_rental_leadTotal',
    'diveCenters_rental_feedbackOver',
    'diveCenters_rental_feedbackUnder',
    'diveCenters_rental_tanksLabel',
    'diveCenters_rental_verdictWorked',
    'diveCenters_rental_verdictAvoid',
    'diveCenters_rental_extraLead',
    'diveCenters_rental_lessLead',
    'diveCenters_rental_actualCapacity',
    'diveCenters_rental_sheetTitleNew',
    'diveCenters_rental_sheetTitleEdit',
    'diveCenters_rental_gearTypeLabel',
    'diveCenters_rental_labelLabel',
    'diveCenters_rental_sizeLabel',
    'diveCenters_rental_leadAdjustmentLabel',
    'diveCenters_rental_volumeLabel',
    'diveCenters_rental_noteLabel',
    'diveCenters_rental_deleteConfirm',
  ];
  const locales = ['ar', 'de', 'en', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh'];

  for (final locale in locales) {
    test('app_$locale.arb carries every rental gear memory key', () {
      final file = File('lib/l10n/arb/app_$locale.arb');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final missing = [
        for (final key in keys)
          if (json[key] is! String || (json[key] as String).isEmpty) key,
      ];
      expect(missing, isEmpty, reason: 'missing in $locale');
    });
  }

  test('the English placeholders are declared', () {
    final json =
        jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in const [
      'diveCenters_rental_lastTimeAt',
      'diveCenters_rental_lastDiveOn',
      'diveCenters_rental_leadTotal',
      'diveCenters_rental_feedbackOver',
      'diveCenters_rental_feedbackUnder',
      'diveCenters_rental_extraLead',
      'diveCenters_rental_lessLead',
      'diveCenters_rental_actualCapacity',
      'diveCenters_rental_leadAdjustmentLabel',
      'diveCenters_rental_volumeLabel',
    ]) {
      expect(json['@$key'], isA<Map<String, dynamic>>(), reason: key);
      expect(
        (json['@$key'] as Map<String, dynamic>)['placeholders'],
        isNotNull,
        reason: key,
      );
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/l10n/rental_gear_memory_strings_test.dart`
Expected: FAIL, 29 keys missing in every locale.

- [ ] **Step 3: Append the strings with a script**

Save this as `/tmp/add_rental_strings.py` (a scratch file, never committed) and run it with `python3.14 /tmp/add_rental_strings.py` from the worktree root. It appends each key textually before the closing brace of each ARB, adds `@` placeholder metadata to `app_en.arb` only, and proves every file still parses.

```python
import json
from pathlib import Path

ARB = Path("lib/l10n/arb")

STRINGS = {
 "diveCenters_rental_sectionTitle": {
  "en": "Rental gear", "ar": "معدات مستأجرة", "de": "Leihausrüstung", "es": "Equipo de alquiler",
  "fr": "Matériel de location", "he": "ציוד מושכר", "hu": "Bérelt felszerelés", "it": "Attrezzatura a noleggio",
  "nl": "Huuruitrusting", "pt": "Equipamento alugado", "zh": "租赁装备"},
 "diveCenters_rental_lastTimeAt": {
  "en": "Last time at {center}", "ar": "آخر مرة في {center}", "de": "Letztes Mal bei {center}",
  "es": "La última vez en {center}", "fr": "La dernière fois chez {center}", "he": "בפעם הקודמת ב-{center}",
  "hu": "Legutóbb itt: {center}", "it": "L'ultima volta da {center}", "nl": "Vorige keer bij {center}",
  "pt": "Da última vez em {center}", "zh": "上次在{center}"},
 "diveCenters_rental_lastDiveOn": {
  "en": "Last dive here: {date}", "ar": "آخر غوصة هنا: {date}", "de": "Letzter Tauchgang hier: {date}",
  "es": "Última inmersión aquí: {date}", "fr": "Dernière plongée ici : {date}", "he": "הצלילה האחרונה כאן: {date}",
  "hu": "Legutóbbi merülés itt: {date}", "it": "Ultima immersione qui: {date}", "nl": "Laatste duik hier: {date}",
  "pt": "Último mergulho aqui: {date}", "zh": "上次在此潜水：{date}"},
 "diveCenters_rental_noHistory": {
  "en": "No other dives logged here yet.", "ar": "لا توجد غوصات أخرى مسجلة هنا بعد.",
  "de": "Hier sind noch keine weiteren Tauchgänge eingetragen.", "es": "Aún no hay otras inmersiones registradas aquí.",
  "fr": "Aucune autre plongée enregistrée ici pour le moment.", "he": "עדיין לא נרשמו כאן צלילות נוספות.",
  "hu": "Itt még nincs más rögzített merülés.", "it": "Nessun'altra immersione registrata qui.",
  "nl": "Hier zijn nog geen andere duiken gelogd.", "pt": "Ainda não há outros mergulhos registados aqui.",
  "zh": "此处尚无其他潜水记录。"},
 "diveCenters_rental_empty": {
  "en": "No rental notes for this center yet.", "ar": "لا توجد ملاحظات عن المعدات المستأجرة لهذا المركز بعد.",
  "de": "Noch keine Notizen zur Leihausrüstung dieses Centers.", "es": "Aún no hay notas de alquiler para este centro.",
  "fr": "Aucune note de location pour ce centre pour le moment.", "he": "עדיין אין הערות על ציוד מושכר במרכז הזה.",
  "hu": "Ehhez a központhoz még nincs bérlési jegyzet.", "it": "Nessuna nota sul noleggio per questo centro.",
  "nl": "Nog geen huurnotities voor dit centrum.", "pt": "Ainda não há notas de aluguer para este centro.",
  "zh": "此中心尚无租赁备注。"},
 "diveCenters_rental_addNote": {
  "en": "Add rental note", "ar": "إضافة ملاحظة تأجير", "de": "Leihnotiz hinzufügen", "es": "Añadir nota de alquiler",
  "fr": "Ajouter une note de location", "he": "הוספת הערת השכרה", "hu": "Bérlési jegyzet hozzáadása",
  "it": "Aggiungi nota noleggio", "nl": "Huurnotitie toevoegen", "pt": "Adicionar nota de aluguer", "zh": "添加租赁备注"},
 "diveCenters_rental_applyLastDive": {
  "en": "Apply last dive", "ar": "تطبيق آخر غوصة", "de": "Letzten Tauchgang übernehmen", "es": "Aplicar última inmersión",
  "fr": "Reprendre la dernière plongée", "he": "החלת הצלילה האחרונה", "hu": "Legutóbbi merülés alkalmazása",
  "it": "Applica ultima immersione", "nl": "Laatste duik toepassen", "pt": "Aplicar último mergulho", "zh": "套用上次潜水"},
 "diveCenters_rental_applied": {
  "en": "Weights and tanks copied from your last dive here.", "ar": "تم نسخ الأثقال والأسطوانات من آخر غوصة لك هنا.",
  "de": "Blei und Flaschen vom letzten Tauchgang hier übernommen.", "es": "Lastre y botellas copiados de tu última inmersión aquí.",
  "fr": "Lest et blocs repris de votre dernière plongée ici.", "he": "המשקולות והמכלים הועתקו מהצלילה האחרונה שלך כאן.",
  "hu": "Az ólom és a palackok átmásolva az itteni legutóbbi merülésedből.", "it": "Zavorra e bombole copiate dalla tua ultima immersione qui.",
  "nl": "Lood en flessen overgenomen van je laatste duik hier.", "pt": "Lastro e garrafas copiados do seu último mergulho aqui.",
  "zh": "已从你上次在此的潜水复制配重和气瓶。"},
 "diveCenters_rental_applyConfirmTitle": {
  "en": "Replace weights and tanks?", "ar": "استبدال الأثقال والأسطوانات؟", "de": "Blei und Flaschen ersetzen?",
  "es": "¿Reemplazar lastre y botellas?", "fr": "Remplacer le lest et les blocs ?", "he": "להחליף משקולות ומכלים?",
  "hu": "Lecseréled az ólmot és a palackokat?", "it": "Sostituire zavorra e bombole?", "nl": "Lood en flessen vervangen?",
  "pt": "Substituir lastro e garrafas?", "zh": "替换配重和气瓶？"},
 "diveCenters_rental_applyConfirmBody": {
  "en": "This dive already has weights or tanks. Replace them with the ones from your last dive here?",
  "ar": "تحتوي هذه الغوصة بالفعل على أثقال أو أسطوانات. هل تريد استبدالها بتلك الموجودة في آخر غوصة لك هنا؟",
  "de": "Dieser Tauchgang hat bereits Blei oder Flaschen. Durch die vom letzten Tauchgang hier ersetzen?",
  "es": "Esta inmersión ya tiene lastre o botellas. ¿Reemplazarlos por los de tu última inmersión aquí?",
  "fr": "Cette plongée a déjà du lest ou des blocs. Les remplacer par ceux de votre dernière plongée ici ?",
  "he": "לצלילה הזו כבר יש משקולות או מכלים. להחליף אותם באלה מהצלילה האחרונה שלך כאן?",
  "hu": "Ehhez a merüléshez már tartozik ólom vagy palack. Lecseréled az itteni legutóbbi merülésedéire?",
  "it": "Questa immersione ha già zavorra o bombole. Sostituirle con quelle della tua ultima immersione qui?",
  "nl": "Deze duik heeft al lood of flessen. Vervangen door die van je laatste duik hier?",
  "pt": "Este mergulho já tem lastro ou garrafas. Substituir pelos do seu último mergulho aqui?",
  "zh": "此次潜水已有配重或气瓶。是否替换为你上次在此潜水的配置？"},
 "diveCenters_rental_applyConfirmReplace": {
  "en": "Replace", "ar": "استبدال", "de": "Ersetzen", "es": "Reemplazar", "fr": "Remplacer", "he": "החלפה",
  "hu": "Csere", "it": "Sostituisci", "nl": "Vervangen", "pt": "Substituir", "zh": "替换"},
 "diveCenters_rental_leadTotal": {
  "en": "Lead: {total}", "ar": "الأثقال: {total}", "de": "Blei: {total}", "es": "Lastre: {total}", "fr": "Lest : {total}",
  "he": "משקולות: {total}", "hu": "Ólom: {total}", "it": "Zavorra: {total}", "nl": "Lood: {total}", "pt": "Lastro: {total}",
  "zh": "配重：{total}"},
 "diveCenters_rental_feedbackOver": {
  "en": "{amount} over", "ar": "{amount} زيادة", "de": "{amount} zu viel", "es": "{amount} de más", "fr": "{amount} de trop",
  "he": "{amount} יותר מדי", "hu": "{amount} túl sok", "it": "{amount} in più", "nl": "{amount} te veel",
  "pt": "{amount} a mais", "zh": "超重{amount}"},
 "diveCenters_rental_feedbackUnder": {
  "en": "{amount} under", "ar": "{amount} نقص", "de": "{amount} zu wenig", "es": "{amount} de menos", "fr": "{amount} de moins",
  "he": "{amount} פחות מדי", "hu": "{amount} túl kevés", "it": "{amount} in meno", "nl": "{amount} te weinig",
  "pt": "{amount} a menos", "zh": "欠重{amount}"},
 "diveCenters_rental_tanksLabel": {
  "en": "Tanks", "ar": "الأسطوانات", "de": "Flaschen", "es": "Botellas", "fr": "Blocs", "he": "מכלים", "hu": "Palackok",
  "it": "Bombole", "nl": "Flessen", "pt": "Garrafas", "zh": "气瓶"},
 "diveCenters_rental_verdictWorked": {
  "en": "Worked", "ar": "مناسب", "de": "Hat gepasst", "es": "Funcionó", "fr": "Convenait", "he": "התאים", "hu": "Bevált",
  "it": "Andava bene", "nl": "Beviel", "pt": "Funcionou", "zh": "好用"},
 "diveCenters_rental_verdictAvoid": {
  "en": "Avoid", "ar": "تجنّب", "de": "Meiden", "es": "Evitar", "fr": "À éviter", "he": "להימנע", "hu": "Kerülendő",
  "it": "Da evitare", "nl": "Vermijden", "pt": "Evitar", "zh": "避免"},
 "diveCenters_rental_extraLead": {
  "en": "{amount} extra lead", "ar": "{amount} أثقال إضافية", "de": "{amount} mehr Blei", "es": "{amount} más de lastre",
  "fr": "{amount} de lest en plus", "he": "{amount} משקולות נוספות", "hu": "{amount} plusz ólom", "it": "{amount} di zavorra in più",
  "nl": "{amount} extra lood", "pt": "{amount} de lastro a mais", "zh": "多带{amount}配重"},
 "diveCenters_rental_lessLead": {
  "en": "{amount} less lead", "ar": "{amount} أثقال أقل", "de": "{amount} weniger Blei", "es": "{amount} menos de lastre",
  "fr": "{amount} de lest en moins", "he": "{amount} פחות משקולות", "hu": "{amount} kevesebb ólom", "it": "{amount} di zavorra in meno",
  "nl": "{amount} minder lood", "pt": "{amount} de lastro a menos", "zh": "少带{amount}配重"},
 "diveCenters_rental_actualCapacity": {
  "en": "Actual capacity {volume}", "ar": "السعة الفعلية {volume}", "de": "Tatsächliches Volumen {volume}",
  "es": "Capacidad real {volume}", "fr": "Capacité réelle {volume}", "he": "קיבולת בפועל {volume}",
  "hu": "Tényleges térfogat {volume}", "it": "Capacità reale {volume}", "nl": "Werkelijke inhoud {volume}",
  "pt": "Capacidade real {volume}", "zh": "实际容量{volume}"},
 "diveCenters_rental_sheetTitleNew": {
  "en": "New rental note", "ar": "ملاحظة تأجير جديدة", "de": "Neue Leihnotiz", "es": "Nueva nota de alquiler",
  "fr": "Nouvelle note de location", "he": "הערת השכרה חדשה", "hu": "Új bérlési jegyzet", "it": "Nuova nota noleggio",
  "nl": "Nieuwe huurnotitie", "pt": "Nova nota de aluguer", "zh": "新建租赁备注"},
 "diveCenters_rental_sheetTitleEdit": {
  "en": "Edit rental note", "ar": "تعديل ملاحظة التأجير", "de": "Leihnotiz bearbeiten", "es": "Editar nota de alquiler",
  "fr": "Modifier la note de location", "he": "עריכת הערת השכרה", "hu": "Bérlési jegyzet szerkesztése",
  "it": "Modifica nota noleggio", "nl": "Huurnotitie bewerken", "pt": "Editar nota de aluguer", "zh": "编辑租赁备注"},
 "diveCenters_rental_gearTypeLabel": {
  "en": "Gear type", "ar": "نوع المعدات", "de": "Ausrüstungstyp", "es": "Tipo de equipo", "fr": "Type de matériel",
  "he": "סוג ציוד", "hu": "Felszerelés típusa", "it": "Tipo di attrezzatura", "nl": "Type uitrusting", "pt": "Tipo de equipamento",
  "zh": "装备类型"},
 "diveCenters_rental_labelLabel": {
  "en": "Label or number", "ar": "الملصق أو الرقم", "de": "Kennzeichnung oder Nummer", "es": "Etiqueta o número",
  "fr": "Étiquette ou numéro", "he": "תווית או מספר", "hu": "Címke vagy szám", "it": "Etichetta o numero",
  "nl": "Label of nummer", "pt": "Etiqueta ou número", "zh": "标签或编号"},
 "diveCenters_rental_sizeLabel": {
  "en": "Size", "ar": "المقاس", "de": "Größe", "es": "Talla", "fr": "Taille", "he": "מידה", "hu": "Méret", "it": "Taglia",
  "nl": "Maat", "pt": "Tamanho", "zh": "尺码"},
 "diveCenters_rental_leadAdjustmentLabel": {
  "en": "Extra lead needed ({unit})", "ar": "الأثقال الإضافية المطلوبة ({unit})", "de": "Zusätzlich benötigtes Blei ({unit})",
  "es": "Lastre adicional necesario ({unit})", "fr": "Lest supplémentaire nécessaire ({unit})", "he": "משקולות נוספות נדרשות ({unit})",
  "hu": "Szükséges plusz ólom ({unit})", "it": "Zavorra aggiuntiva necessaria ({unit})", "nl": "Extra lood nodig ({unit})",
  "pt": "Lastro adicional necessário ({unit})", "zh": "需额外配重（{unit}）"},
 "diveCenters_rental_volumeLabel": {
  "en": "Actual capacity ({unit})", "ar": "السعة الفعلية ({unit})", "de": "Tatsächliches Volumen ({unit})",
  "es": "Capacidad real ({unit})", "fr": "Capacité réelle ({unit})", "he": "קיבולת בפועל ({unit})",
  "hu": "Tényleges térfogat ({unit})", "it": "Capacità reale ({unit})", "nl": "Werkelijke inhoud ({unit})",
  "pt": "Capacidade real ({unit})", "zh": "实际容量（{unit}）"},
 "diveCenters_rental_noteLabel": {
  "en": "Note", "ar": "ملاحظة", "de": "Notiz", "es": "Nota", "fr": "Note", "he": "הערה", "hu": "Jegyzet", "it": "Nota",
  "nl": "Notitie", "pt": "Nota", "zh": "备注"},
 "diveCenters_rental_deleteConfirm": {
  "en": "Delete this rental note?", "ar": "حذف ملاحظة التأجير هذه؟", "de": "Diese Leihnotiz löschen?",
  "es": "¿Eliminar esta nota de alquiler?", "fr": "Supprimer cette note de location ?", "he": "למחוק את הערת ההשכרה הזו?",
  "hu": "Törlöd ezt a bérlési jegyzetet?", "it": "Eliminare questa nota sul noleggio?", "nl": "Deze huurnotitie verwijderen?",
  "pt": "Eliminar esta nota de aluguer?", "zh": "删除此租赁备注？"},
}

PLACEHOLDERS = {
 "diveCenters_rental_lastTimeAt": ["center"],
 "diveCenters_rental_lastDiveOn": ["date"],
 "diveCenters_rental_leadTotal": ["total"],
 "diveCenters_rental_feedbackOver": ["amount"],
 "diveCenters_rental_feedbackUnder": ["amount"],
 "diveCenters_rental_extraLead": ["amount"],
 "diveCenters_rental_lessLead": ["amount"],
 "diveCenters_rental_actualCapacity": ["volume"],
 "diveCenters_rental_leadAdjustmentLabel": ["unit"],
 "diveCenters_rental_volumeLabel": ["unit"],
}

LOCALES = ["ar", "de", "en", "es", "fr", "he", "hu", "it", "nl", "pt", "zh"]

for locale in LOCALES:
    path = ARB / f"app_{locale}.arb"
    src = path.read_text(encoding="utf-8")
    existing = json.loads(src)
    lines = []
    for key, values in STRINGS.items():
        if key in existing:
            continue
        lines.append('  %s: %s' % (json.dumps(key), json.dumps(values[locale], ensure_ascii=False)))
        if locale == "en" and key in PLACEHOLDERS:
            meta = {"placeholders": {p: {"type": "Object"} for p in PLACEHOLDERS[key]}}
            lines.append('  %s: %s' % (json.dumps("@" + key), json.dumps(meta, ensure_ascii=False)))
    if not lines:
        continue
    head, sep, tail = src.rstrip().rpartition("}")
    assert sep == "}" and tail == "", path
    head = head.rstrip()
    if not head.endswith(","):
        head += ","
    out = head + "\n" + ",\n".join(lines) + "\n}\n"
    json.loads(out)
    path.write_text(out, encoding="utf-8")
    print(locale, len(lines), "lines added")
```

Then check the diff is even across locales (English carries ten extra `@` lines):

```bash
git diff --numstat -- lib/l10n/arb/
```

Expected: `29 1` for ten locales and `39 1` for `app_en.arb` (the `1` is the previous last line losing its missing comma; if a file shows `29 0` its last key already ended with a comma, which is also fine).

- [ ] **Step 4: Generate and verify the Dart**

```bash
flutter gen-l10n
grep -A1 "get diveCenters_rental_verdictAvoid" lib/l10n/arb/app_localizations_de.dart
flutter test test/l10n/rental_gear_memory_strings_test.dart
```

Expected: the German getter returns `'Meiden'`, and the test PASSES.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_ar.dart lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_en.dart lib/l10n/arb/app_localizations_es.dart lib/l10n/arb/app_localizations_fr.dart lib/l10n/arb/app_localizations_he.dart lib/l10n/arb/app_localizations_hu.dart lib/l10n/arb/app_localizations_it.dart lib/l10n/arb/app_localizations_nl.dart lib/l10n/arb/app_localizations_pt.dart lib/l10n/arb/app_localizations_zh.dart test/l10n/rental_gear_memory_strings_test.dart
git commit -m "i18n: rental gear memory strings in all locales (#2075)"
```

---

### Task 6: The rental gear note sheet

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart`
- Test: `test/features/dive_centers/presentation/widgets/rental_gear_note_sheet_test.dart` (create)

**Interfaces:**
- Consumes: Task 1's entity, Task 4's `diveCenterGearNoteRepositoryProvider`, Task 5's strings, `UnitFormatter` (`lib/core/utils/unit_formatter.dart`), `parseUserDecimal` and `formatRoundedForInput` (`lib/core/utils/number_input.dart`), `equipmentTypeIcon` (`lib/features/equipment/presentation/utils/equipment_type_icon.dart`), `EquipmentTypeDisplay.localizedName` (`lib/features/equipment/presentation/utils/equipment_enum_display.dart`), `kCanonicalTypeOrder` (`lib/features/equipment/domain/constants/equipment_type_order.dart`).
- Produces: `Future<void> showRentalGearNoteSheet(BuildContext context, {required String diveCenterId, String? diveId, DiveCenterGearNote? editing})` and `Future<bool> confirmDeleteRentalGearNote(BuildContext context, WidgetRef ref, DiveCenterGearNote note)` (returns true when deleted).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_centers/presentation/widgets/rental_gear_note_sheet_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveCenterGearNoteRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveCenterGearNoteRepository();
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion(
            id: const Value('c1'),
            name: const Value('Reef Divers'),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    DiveCenterGearNote? editing,
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRentalGearNoteSheet(
                  context,
                  diveCenterId: 'c1',
                  diveId: 'd1',
                  editing: editing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder fieldLabelled(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TextField),
  );

  testWidgets('creates a note with the typed fields converted to metric', (
    tester,
  ) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('New rental note'), findsOneWidget);
    // The volume field only shows for tanks.
    expect(find.text('Actual capacity (cuft)'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCD').last);
    await tester.pumpAndSettle();
    await tester.enterText(fieldLabelled('Label or number'), 'blue 3');
    await tester.enterText(fieldLabelled('Size'), 'L');
    await tester.tap(find.text('Avoid'));
    await tester.enterText(fieldLabelled('Extra lead needed (lbs)'), '4.4');
    await tester.enterText(fieldLabelled('Note'), 'inflator sticks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.gearType, EquipmentType.bcd);
    expect(stored.label, 'blue 3');
    expect(stored.size, 'L');
    expect(stored.verdict, RentalVerdict.avoid);
    expect(stored.leadAdjustmentKg, closeTo(2.0, 0.01));
    expect(stored.volumeLiters, isNull);
    expect(stored.note, 'inflator sticks');
    expect(stored.diveId, 'd1');
    // The sheet closed.
    expect(find.text('New rental note'), findsNothing);
  });

  testWidgets('a tank note shows and stores the actual capacity', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tank').last);
    await tester.pumpAndSettle();
    expect(find.text('Actual capacity (L)'), findsOneWidget);
    await tester.enterText(fieldLabelled('Label or number'), 'AL80');
    await tester.enterText(fieldLabelled('Actual capacity (L)'), '11.1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.gearType, EquipmentType.tank);
    expect(stored.volumeLiters, 11.1);
    expect(stored.verdict, RentalVerdict.worked);
  });

  testWidgets('editing seeds the fields and saves over the row', (
    tester,
  ) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.regulator,
        label: '14',
        verdict: RentalVerdict.avoid,
        leadAdjustmentKg: 1.5,
        note: 'wet',
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    expect(find.text('Edit rental note'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('wet'), findsOneWidget);

    await tester.enterText(fieldLabelled('Note'), 'fine after service');
    await tester.tap(find.text('Worked'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.id, existing.id);
    expect(stored.verdict, RentalVerdict.worked);
    expect(stored.note, 'fine after service');
    expect(stored.leadAdjustmentKg, 1.5);
  });

  testWidgets('delete asks first, then removes the note', (tester) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.wetsuit,
        size: 'L',
        verdict: RentalVerdict.avoid,
        note: 'runs small',
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this rental note?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getForCenter('c1'), isEmpty);
    expect(find.text('Edit rental note'), findsNothing);
  });
}
```

`MockSettingsNotifier` (`test/helpers/mock_providers.dart`) defaults to metric; `setImperial()` switches it to pounds (`lbs`) and cubic feet (`cuft`), which is what the first test's field labels assert.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_gear_note_sheet_test.dart`
Expected: FAIL to compile: no `showRentalGearNoteSheet`.

- [ ] **Step 3: Write the sheet**

Create `lib/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the rental gear note editor (issue #2075) for a center. With
/// [editing], the sheet edits that note; otherwise it creates one for
/// [diveCenterId], remembering [diveId] as where it was noticed.
Future<void> showRentalGearNoteSheet(
  BuildContext context, {
  required String diveCenterId,
  String? diveId,
  DiveCenterGearNote? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RentalGearNoteSheet(
      diveCenterId: diveCenterId,
      diveId: diveId,
      editing: editing,
    ),
  );
}

/// Asks before deleting [note], then deletes it. Returns true when the
/// note is gone. Shared by the sheet and the detail page section.
Future<bool> confirmDeleteRentalGearNote(
  BuildContext context,
  WidgetRef ref,
  DiveCenterGearNote note,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.diveCenters_rental_deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  await ref.read(diveCenterGearNoteRepositoryProvider).delete(note.id);
  return true;
}

class _RentalGearNoteSheet extends ConsumerStatefulWidget {
  final String diveCenterId;
  final String? diveId;
  final DiveCenterGearNote? editing;

  const _RentalGearNoteSheet({
    required this.diveCenterId,
    this.diveId,
    this.editing,
  });

  @override
  ConsumerState<_RentalGearNoteSheet> createState() =>
      _RentalGearNoteSheetState();
}

class _RentalGearNoteSheetState extends ConsumerState<_RentalGearNoteSheet> {
  late EquipmentType _gearType;
  late RentalVerdict _verdict;
  late final TextEditingController _label;
  late final TextEditingController _size;
  late final TextEditingController _lead;
  late final TextEditingController _volume;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _gearType = existing?.gearType ?? EquipmentType.other;
    _verdict = existing?.verdict ?? RentalVerdict.worked;
    _label = TextEditingController(text: existing?.label ?? '');
    _size = TextEditingController(text: existing?.size ?? '');
    _lead = TextEditingController(
      text: existing?.leadAdjustmentKg == null
          ? ''
          : formatRoundedForInput(
              units.convertWeight(existing!.leadAdjustmentKg!),
              2,
            ),
    );
    _volume = TextEditingController(
      text: existing?.volumeLiters == null
          ? ''
          : formatRoundedForInput(
              units.convertVolume(existing!.volumeLiters!),
              2,
            ),
    );
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _size.dispose();
    _lead.dispose();
    _volume.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final leadText = _lead.text.trim();
    final volumeText = _volume.text.trim();
    final lead = leadText.isEmpty ? null : parseUserDecimal(leadText);
    final volume = volumeText.isEmpty ? null : parseUserDecimal(volumeText);
    // Unreadable text is refused rather than silently dropped.
    if ((leadText.isNotEmpty && lead == null) ||
        (_gearType == EquipmentType.tank &&
            volumeText.isNotEmpty &&
            volume == null)) {
      setState(() => _error = l10n.numberInput_invalidValue);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(diveCenterGearNoteRepositoryProvider);
      final existing = widget.editing;
      final leadKg = lead == null ? null : units.weightToKg(lead);
      final volumeL = _gearType == EquipmentType.tank && volume != null
          ? units.volumeToLiters(volume)
          : null;
      if (existing == null) {
        final now = DateTime.now().toUtc();
        await repo.create(
          DiveCenterGearNote(
            id: '',
            diveCenterId: widget.diveCenterId,
            gearType: _gearType,
            label: _label.text,
            size: _size.text,
            verdict: _verdict,
            leadAdjustmentKg: leadKg,
            volumeLiters: volumeL,
            note: _note.text,
            diveId: widget.diveId,
            notedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repo.update(
          existing.copyWith(
            gearType: _gearType,
            label: _label.text,
            clearLabel: _label.text.trim().isEmpty,
            size: _size.text,
            clearSize: _size.text.trim().isEmpty,
            verdict: _verdict,
            leadAdjustmentKg: leadKg,
            clearLeadAdjustment: leadKg == null,
            volumeLiters: volumeL,
            clearVolume: volumeL == null,
            note: _note.text,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A concurrent sync can delete the center mid-save. Say so and keep
      // the editor open to try again.
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final note = widget.editing;
    if (note == null) return;
    final deleted = await confirmDeleteRentalGearNote(context, ref, note);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.editing == null
                  ? l10n.diveCenters_rental_sheetTitleNew
                  : l10n.diveCenters_rental_sheetTitleEdit,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentType>(
              initialValue: _gearType,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_gearTypeLabel,
              ),
              isExpanded: true,
              items: [
                for (final type in kCanonicalTypeOrder)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.localizedName(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _gearType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_labelLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _size,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_sizeLabel,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RentalVerdict>(
              segments: [
                ButtonSegment(
                  value: RentalVerdict.worked,
                  label: Text(l10n.diveCenters_rental_verdictWorked),
                ),
                ButtonSegment(
                  value: RentalVerdict.avoid,
                  label: Text(l10n.diveCenters_rental_verdictAvoid),
                ),
              ],
              selected: {_verdict},
              onSelectionChanged: (selection) =>
                  setState(() => _verdict = selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lead,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_leadAdjustmentLabel(
                  units.weightSymbol,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            if (_gearType == EquipmentType.tank) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _volume,
                decoration: InputDecoration(
                  labelText: l10n.diveCenters_rental_volumeLabel(
                    units.volumeSymbol,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_noteLabel,
              ),
              maxLines: 3,
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.editing != null)
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.common_action_delete),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.common_action_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

`numberInput_invalidValue` and `common_error_tryAgain` already exist in the ARBs (the first is the last key of `app_en.arb`, the second is used by the observation sheet). If `common_error_tryAgain` is named differently, grep `app_en.arb` for `tryAgain` and use that key.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_gear_note_sheet_test.dart`
Expected: 4 tests PASS. If the dropdown tap finds two `BCD` texts (the closed field and the open menu), the test already uses `.last`; if it finds none because the localized label differs, use the string `EquipmentType.bcd.localizedName` yields in English from `enum_equipmentType_bcd` in `app_en.arb`.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart test/features/dive_centers/presentation/widgets/rental_gear_note_sheet_test.dart
git commit -m "feat(dive-centers): rental gear note sheet (#2075)"
```

---

### Task 7: The "Last time here" card and the trip section slot

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/rental_memory_card.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart`
- Test: `test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart` (create)
- Test: `test/features/dive_log/presentation/widgets/edit_sections/trip_section_test.dart` (modify)

**Interfaces:**
- Consumes: Task 4's `diveCenterGearNotesProvider`, `lastDiveAtCenterProvider`, `LastDiveAtCenterQuery`; Task 1's `LastDiveAtCenter`, `DiveCenterGearNote`; Task 6's `showRentalGearNoteSheet`; Task 5's strings.
- Produces: `class RentalMemoryCard extends ConsumerWidget` with `const RentalMemoryCard({required DiveCenter center, String? currentDiveId, required void Function(LastDiveAtCenter last) onApplyLastDive})`; `TripSection` gains `final Widget? centerChild`.

The card is pure presentation: it never touches the edit form's state. Applying is the page's job through `onApplyLastDive`, which is where the confirm dialog lives (Task 8), because only the page knows whether the form already holds weights or tanks.

- [ ] **Step 1: Write the failing card test**

Create `test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final center = DiveCenter(
    id: 'c1',
    name: 'Reef Divers',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final last = LastDiveAtCenter(
    diveId: 'd0',
    dateTime: DateTime(2026, 3, 12),
    weights: const [
      DiveWeight(
        id: 'w1',
        diveId: 'd0',
        weightType: WeightType.belt,
        amountKg: 6,
      ),
      DiveWeight(
        id: 'w2',
        diveId: 'd0',
        weightType: WeightType.trimWeights,
        amountKg: 2,
      ),
    ],
    weightingFeedback: WeightingFeedback.overweighted,
    weightingFeedbackKg: 1,
    tanks: const [
      DiveTank(id: 't1', volume: 11.1, workingPressure: 207, presetName: 'al80'),
    ],
  );

  final notes = [
    DiveCenterGearNote(
      id: 'n1',
      diveCenterId: 'c1',
      gearType: EquipmentType.regulator,
      label: '14',
      verdict: RentalVerdict.avoid,
      note: 'breathes wet',
      notedAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
    DiveCenterGearNote(
      id: 'n2',
      diveCenterId: 'c1',
      gearType: EquipmentType.bcd,
      size: 'L',
      verdict: RentalVerdict.worked,
      leadAdjustmentKg: 2,
      notedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required LastDiveAtCenter? lastDive,
    required List<DiveCenterGearNote> withNotes,
    void Function(LastDiveAtCenter)? onApply,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveCenterGearNotesProvider(
            'c1',
          ).overrideWith((ref) async => withNotes),
          lastDiveAtCenterProvider((
            centerId: 'c1',
            excludingDiveId: 'd1',
          )).overrideWith((ref) async => lastDive),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RentalMemoryCard(
                center: center,
                currentDiveId: 'd1',
                onApplyLastDive: onApply ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the last dive facts and the notes', (tester) async {
    await pump(tester, lastDive: last, withNotes: notes);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.textContaining('Last dive here:'), findsOneWidget);
    expect(find.text('Lead: 8.0 kg'), findsOneWidget);
    expect(find.text('1.0 kg over'), findsOneWidget);
    expect(find.textContaining('11 L'), findsOneWidget);
    expect(find.text('Apply last dive'), findsOneWidget);
    // Notes, newest first, with their verdicts and numbers.
    expect(find.text('14'), findsOneWidget);
    expect(find.text('breathes wet'), findsOneWidget);
    expect(find.text('Avoid'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Worked'), findsOneWidget);
    expect(find.text('2.0 kg extra lead'), findsOneWidget);
    expect(find.text('Add rental note'), findsOneWidget);
  });

  testWidgets('apply hands the last dive to the page', (tester) async {
    LastDiveAtCenter? applied;
    await pump(
      tester,
      lastDive: last,
      withNotes: const [],
      onApply: (l) => applied = l,
    );
    await tester.tap(find.text('Apply last dive'));
    await tester.pump();
    expect(applied, same(last));
  });

  testWidgets('with no history and no notes only the add button shows', (
    tester,
  ) async {
    await pump(tester, lastDive: null, withNotes: const []);
    expect(find.text('Add rental note'), findsOneWidget);
    expect(find.text('Apply last dive'), findsNothing);
    expect(find.text('Last time at Reef Divers'), findsNothing);
    expect(find.textContaining('Lead:'), findsNothing);
  });

  testWidgets('notes without history still show under the header', (
    tester,
  ) async {
    await pump(tester, lastDive: null, withNotes: notes);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.text('No other dives logged here yet.'), findsOneWidget);
    expect(find.text('breathes wet'), findsOneWidget);
    expect(find.text('Apply last dive'), findsNothing);
  });
}
```

- [ ] **Step 2: Extend the trip section test**

Append this test to `test/features/dive_log/presentation/widgets/edit_sections/trip_section_test.dart`, inside `main()`:

```dart
  testWidgets('the center child renders under the dive center row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripSection(
              expanded: true,
              onToggle: () {},
              summary: 'Reef Divers',
              isEmpty: false,
              tripName: null,
              onPickTrip: () {},
              onClearTrip: () {},
              diveCenterName: 'Reef Divers',
              onPickDiveCenter: () {},
              onClearDiveCenter: () {},
              centerChild: const Text('CENTER_CHILD'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('CENTER_CHILD'), findsOneWidget);
    final child = tester.getTopLeft(find.text('CENTER_CHILD'));
    final row = tester.getTopLeft(find.text('Reef Divers').last);
    expect(child.dy, greaterThan(row.dy));
  });
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart test/features/dive_log/presentation/widgets/edit_sections/trip_section_test.dart`
Expected: FAIL to compile: no `RentalMemoryCard`, no `centerChild` parameter.

- [ ] **Step 4: Add the slot**

In `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart`:

Add the constructor parameter after `this.centerCaption,`:

```dart
    this.centerChild,
```

Add the field after the `centerCaption` field:

```dart
  /// Rendered under the dive center row when a center is selected: the
  /// "last time here" rental memory card (issue #2075).
  final Widget? centerChild;
```

In `build`, inside the second `Column`, after `if (centerCaption != null) _caption(context, centerCaption!),` add:

```dart
            if (centerChild != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FormStyle.groupRadius,
                  0,
                  FormStyle.groupRadius,
                  10,
                ),
                child: centerChild,
              ),
```

- [ ] **Step 5: Write the card**

Create `lib/features/dive_centers/presentation/widgets/rental_memory_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Last time at {center}" (issue #2075): the diver's most recent other
/// dive at the selected center (lead, how it felt, cylinders) and their
/// rental gear notes, with a way to add a note and to copy that dive's
/// weights and tanks into the form.
///
/// Shown under the dive center row of the dive edit form. The card only
/// reports; [onApplyLastDive] hands the last dive to the page, which owns
/// the form state and the confirm dialog.
class RentalMemoryCard extends ConsumerWidget {
  final DiveCenter center;

  /// The dive being edited, left out of the "last dive" lookup. Null while
  /// creating a dive.
  final String? currentDiveId;
  final void Function(LastDiveAtCenter last) onApplyLastDive;

  const RentalMemoryCard({
    super.key,
    required this.center,
    this.currentDiveId,
    required this.onApplyLastDive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notes =
        ref.watch(diveCenterGearNotesProvider(center.id)).value ??
        const <DiveCenterGearNote>[];
    final lastAsync = ref.watch(
      lastDiveAtCenterProvider((
        centerId: center.id,
        excludingDiveId: currentDiveId,
      )),
    );
    final last = lastAsync.value;

    void addNote() => showRentalGearNoteSheet(
      context,
      diveCenterId: center.id,
      diveId: currentDiveId,
    );

    if (last == null && notes.isEmpty) {
      if (lastAsync.isLoading) return const SizedBox.shrink();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: addNote,
          icon: const Icon(Icons.note_add_outlined),
          label: Text(l10n.diveCenters_rental_addNote),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.diveCenters_rental_lastTimeAt(center.name),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (last == null)
              Text(
                l10n.diveCenters_rental_noHistory,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _LastDiveRows(last: last, units: units),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final note in notes)
                RentalNoteTile(
                  note: note,
                  units: units,
                  onTap: () => showRentalGearNoteSheet(
                    context,
                    diveCenterId: center.id,
                    diveId: currentDiveId,
                    editing: note,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: addNote,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(l10n.diveCenters_rental_addNote),
                ),
                if (last != null)
                  FilledButton.tonalIcon(
                    onPressed: () => onApplyLastDive(last),
                    icon: const Icon(Icons.history),
                    label: Text(l10n.diveCenters_rental_applyLastDive),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastDiveRows extends StatelessWidget {
  final LastDiveAtCenter last;
  final UnitFormatter units;

  const _LastDiveRows({required this.last, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.diveCenters_rental_lastDiveOn(units.formatDate(last.dateTime)),
          style: muted,
        ),
        if (last.weights.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.diveCenters_rental_leadTotal(
                  units.formatWeight(last.totalLeadKg),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              for (final w in last.weights)
                Text(
                  '${w.weightType.localizedName(l10n)} '
                  '${units.formatWeight(w.amountKg)}',
                  style: muted,
                ),
              if (feedbackLabel(l10n, units) case final label?)
                Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        if (last.tanks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.diveCenters_rental_tanksLabel, style: muted),
          for (final t in last.tanks)
            Text(
              [
                if (t.presetName case final p?) p.toUpperCase()
                else if (t.name case final n?) n,
                if (t.volume case final v?) units.formatVolume(v),
                if (t.workingPressure case final p?) units.formatPressure(p),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }

  String? feedbackLabel(AppLocalizations l10n, UnitFormatter units) {
    final kg = last.weightingFeedbackKg;
    return switch (last.weightingFeedback) {
      null => null,
      WeightingFeedback.correct => l10n.diveLog_edit_weightFeedback_correct,
      WeightingFeedback.overweighted =>
        kg == null
            ? l10n.diveLog_edit_weightFeedback_over
            : l10n.diveCenters_rental_feedbackOver(units.formatWeight(kg)),
      WeightingFeedback.underweighted =>
        kg == null
            ? l10n.diveLog_edit_weightFeedback_under
            : l10n.diveCenters_rental_feedbackUnder(units.formatWeight(kg)),
    };
  }
}

/// One rental note: icon, label and size, verdict, its number, its text.
/// Public because the dive center detail page section reuses it.
class RentalNoteTile extends StatelessWidget {
  final DiveCenterGearNote note;
  final UnitFormatter units;
  final VoidCallback onTap;

  const RentalNoteTile({
    super.key,
    required this.note,
    required this.units,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final avoid = note.verdict == RentalVerdict.avoid;
    final details = <String>[
      if (note.leadAdjustmentKg case final kg? when kg != 0)
        kg > 0
            ? l10n.diveCenters_rental_extraLead(units.formatWeight(kg))
            : l10n.diveCenters_rental_lessLead(units.formatWeight(-kg)),
      if (note.volumeLiters case final v?)
        l10n.diveCenters_rental_actualCapacity(
          units.formatVolume(v, decimals: 1),
        ),
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(equipmentTypeIcon(note.gearType)),
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(note.gearType.localizedName(l10n)),
          if (note.label case final label?) Text(label),
          if (note.size case final size?) Text(size),
          Chip(
            label: Text(
              avoid
                  ? l10n.diveCenters_rental_verdictAvoid
                  : l10n.diveCenters_rental_verdictWorked,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: avoid
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.secondaryContainer,
          ),
        ],
      ),
      subtitle: details.isEmpty && note.note.isEmpty
          ? null
          : Text([...details, if (note.note.isNotEmpty) note.note].join('\n')),
      onTap: onTap,
    );
  }
}
```

The formatter names used are verified: `formatDate(DateTime?)` (no l10n argument), `formatPressure(double?, {int decimals = 0})`, `formatVolume(double?, {int decimals = 0})`, `formatWeight(double?, {int decimals = 1})`. `WeightType.localizedName` comes from `lib/features/weight_planner/presentation/widgets/weight_enum_display.dart`, imported above.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart test/features/dive_log/presentation/widgets/edit_sections/trip_section_test.dart`
Expected: all PASS. The `11 L` and `8.0 kg` expectations depend on the default formatter decimals (`formatVolume` defaults to 0, `formatWeight` to 1); if a text differs by decimals only, align the test with the formatter's output rather than changing the formatter.

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_centers/presentation/widgets/rental_memory_card.dart lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart test/features/dive_centers/presentation/widgets/rental_memory_card_test.dart test/features/dive_log/presentation/widgets/edit_sections/trip_section_test.dart
git commit -m "feat(dive-log): last-time-here rental memory card under the dive center row (#2075)"
```

---

### Task 8: The edit page applies the last dive

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_buildTripGroupSection` ~line 2390; a new `_applyLastDiveAtCenter` method next to `_applyWeightPreset` ~line 4524; imports)
- Test: `test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart` (create)

**Interfaces:**
- Consumes: Task 7's `RentalMemoryCard`, Task 1's `LastDiveAtCenter.weightsForNewDive` and `tanksForNewDive`, the page's `_weights`, `_tanks`, `_tanksDirty`, `_markDirty`, `_uuid`, `_selectedDiveCenter`, `widget.diveId`.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing page test**

Create `test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart`, modelled on `dive_edit_weight_preset_test.dart` (read that file first and copy its `pumpEditor` helper exactly, including the seeding of the current diver after pumping):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2075: applying the last dive at a center copies its weights and
/// tanks into the dive being edited.
void main() {
  late DiveRepository dives;
  late DiveCenter center;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    final now = DateTime.now();
    diverId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'Tester', createdAt: now, updatedAt: now),
    )).id;
    center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        diverId: diverId,
        name: 'Reef Divers',
        createdAt: now,
        updatedAt: now,
      ),
    );
    // The earlier dive at the center: 6 kg belt, one AL80.
    await dives.createDive(
      Dive(
        id: 'earlier',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 12, 9),
        diveCenter: center,
        weights: const [
          DiveWeight(
            id: 'w-earlier',
            diveId: 'earlier',
            weightType: WeightType.belt,
            amountKg: 6,
          ),
        ],
        tanks: const [
          DiveTank(
            id: 't-earlier',
            volume: 11.1,
            workingPressure: 207,
            startPressure: 200,
            endPressure: 60,
            presetName: 'al80',
          ),
        ],
      ),
    );
    // The dive being edited: same center, no weights, no tanks.
    await dives.createDive(
      Dive(
        id: 'current',
        diverId: diverId,
        dateTime: DateTime(2026, 9, 18, 9),
        diveCenter: center,
      ),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpEditor(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandTrip(WidgetTester tester) async {
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
  }

  testWidgets('apply copies the earlier weights and tanks into the form', (
    tester,
  ) async {
    await pumpEditor(tester, 'current');
    await expandTrip(tester);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.text('Lead: 6.0 kg'), findsOneWidget);

    await tester.tap(find.text('Apply last dive'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Weights and tanks copied'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await dives.getDiveById('current'))!;
    expect(saved.weights.single.weightType, WeightType.belt);
    expect(saved.weights.single.amountKg, 6);
    expect(saved.weights.single.id, isNot('w-earlier'));
    expect(saved.tanks.single.volume, 11.1);
    expect(saved.tanks.single.presetName, 'al80');
    expect(saved.tanks.single.id, isNot('t-earlier'));
    // The pressures are the defaults for a new tank, not the old dive's.
    expect(saved.tanks.single.endPressure, 50);
    expect(saved.tanks.single.startPressure, isNot(200));
  });

  testWidgets('apply on a form that already has weights asks first', (
    tester,
  ) async {
    await dives.updateDive(
      (await dives.getDiveById('current'))!.copyWith(
        weights: const [
          DiveWeight(
            id: 'w-current',
            diveId: 'current',
            weightType: WeightType.integrated,
            amountKg: 4,
          ),
        ],
      ),
    );
    await pumpEditor(tester, 'current');
    await expandTrip(tester);

    await tester.tap(find.text('Apply last dive'));
    await tester.pumpAndSettle();
    expect(find.text('Replace weights and tanks?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await dives.getDiveById('current'))!;
    expect(saved.weights.single.weightType, WeightType.belt);
    expect(saved.weights.single.amountKg, 6);
  });
}
```

If `Dive` has required constructor parameters beyond those used, or `createDive` / `updateDive` / `Dive.copyWith` are named differently, read `dive_repository_impl.dart` and `dive.dart` and adjust the test's calls, keeping the assertions. If the save button's text is not `Save` in embedded mode, copy the tap the weight preset test uses.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart`
Expected: FAIL at `find.text('Last time at Reef Divers')` (nothing rendered under the center row yet).

- [ ] **Step 3: Wire the card and the apply**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart` add the imports:

```dart
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
```

In `_buildTripGroupSection`, after `centerCaption: _selectedDiveCenter?.displayLocation,` add:

```dart
      centerChild: _selectedDiveCenter == null || widget.isBulk
          ? null
          : RentalMemoryCard(
              center: _selectedDiveCenter!,
              currentDiveId: widget.diveId,
              onApplyLastDive: _applyLastDiveAtCenter,
            ),
```

Next to `_applyWeightPreset` add:

```dart
  /// Copies the weights and tanks of the diver's last dive at the selected
  /// center into the form (issue #2075). Asks first when the form already
  /// holds any, because the copy replaces them.
  Future<void> _applyLastDiveAtCenter(LastDiveAtCenter last) async {
    final l10n = context.l10n;
    if (_weights.any((w) => w.amountKg > 0) || _tanks.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.diveCenters_rental_applyConfirmTitle),
          content: Text(l10n.diveCenters_rental_applyConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.diveCenters_rental_applyConfirmReplace),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final settings = ref.read(settingsProvider);
    setState(() {
      _markDirty();
      _tanksDirty = true;
      _weights = last.weightsForNewDive(
        diveId: widget.diveId ?? '',
        newId: _uuid.v4,
      );
      _tanks
        ..clear()
        ..addAll(
          last.tanksForNewDive(
            newId: _uuid.v4,
            startPressure: settings.defaultStartPressure.toDouble(),
            endPressure: 50.0,
          ),
        );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.diveCenters_rental_applied)));
  }
```

The `50.0` end pressure and `settings.defaultStartPressure` are exactly what `_addTank` uses for a new tank; keep them identical so an applied tank and a hand-added tank start the same.

- [ ] **Step 4: Run the page tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart test/features/dive_log/presentation/pages/dive_edit_weight_preset_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart`
Expected: all PASS. If the `Trip` group is collapsed by default and `find.text('Trip')` matches more than one widget, tap `find.text('Trip').first`. If a pre-existing test fails on the database service for the new providers, that test now renders the center row with a selected center; add `diveCenterGearNotesProvider(<id>).overrideWith((ref) async => [])` and `lastDiveAtCenterProvider(...)` overrides to it as the card test does.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart
git commit -m "feat(dive-log): apply the last dive at a center to the dive being edited (#2075)"
```

---

### Task 9: The dive center detail page section

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/rental_gear_section.dart`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (body composition ~line 96)
- Test: `test/features/dive_centers/presentation/widgets/rental_gear_section_test.dart` (create)

**Interfaces:**
- Consumes: Task 4's `diveCenterGearNotesProvider`, Task 6's `showRentalGearNoteSheet`, Task 7's `RentalNoteTile`, `kCanonicalTypeOrder` and `equipmentTypeRank` from `equipment_type_order.dart`.
- Produces: `class RentalGearSection extends ConsumerWidget` with `const RentalGearSection({required String centerId})`.

- [ ] **Step 1: Write the failing section test**

Create `test/features/dive_centers/presentation/widgets/rental_gear_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  DiveCenterGearNote note(String id, EquipmentType type, {String? label}) =>
      DiveCenterGearNote(
        id: id,
        diveCenterId: 'c1',
        gearType: type,
        label: label,
        verdict: RentalVerdict.worked,
        notedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> pump(
    WidgetTester tester,
    List<DiveCenterGearNote> notes,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveCenterGearNotesProvider('c1').overrideWith((ref) async => notes),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RentalGearSection(centerId: 'c1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups notes by gear type in the canonical order', (
    tester,
  ) async {
    await pump(tester, [
      note('n1', EquipmentType.fins, label: 'fins'),
      note('n2', EquipmentType.regulator, label: 'reg 14'),
      note('n3', EquipmentType.regulator, label: 'reg 9'),
    ]);
    expect(find.text('Rental gear'), findsOneWidget);
    final reg14 = tester.getTopLeft(find.text('reg 14'));
    final reg9 = tester.getTopLeft(find.text('reg 9'));
    final fins = tester.getTopLeft(find.text('fins'));
    // Regulators come before fins in the canonical order.
    expect(reg14.dy, lessThan(fins.dy));
    expect(reg9.dy, lessThan(fins.dy));
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('with no notes shows the empty line and the add button', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.text('Rental gear'), findsOneWidget);
    expect(find.text('No rental notes for this center yet.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('the add button opens the sheet', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('New rental note'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_gear_section_test.dart`
Expected: FAIL to compile: no `RentalGearSection`.

- [ ] **Step 3: Write the section**

Create `lib/features/dive_centers/presentation/widgets/rental_gear_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive center detail page's rental gear notes (issue #2075), grouped
/// by gear type in the canonical equipment order, with add on the header
/// and edit on tap. Matches the page's other sections: a titled column with
/// a 16 px gutter, no card.
class RentalGearSection extends ConsumerWidget {
  final String centerId;

  const RentalGearSection({super.key, required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notes =
        ref.watch(diveCenterGearNotesProvider(centerId)).value ??
        const <DiveCenterGearNote>[];
    final ordered = [...notes]
      ..sort((a, b) {
        final byType =
            equipmentTypeRank(a.gearType, kCanonicalTypeOrder) -
            equipmentTypeRank(b.gearType, kCanonicalTypeOrder);
        if (byType != 0) return byType;
        return b.notedAt.compareTo(a.notedAt);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.diveCenters_rental_sectionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.diveCenters_rental_addNote,
                onPressed: () =>
                    showRentalGearNoteSheet(context, diveCenterId: centerId),
              ),
            ],
          ),
          if (ordered.isEmpty)
            Text(
              l10n.diveCenters_rental_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final note in ordered)
              RentalNoteTile(
                note: note,
                units: units,
                onTap: () => showRentalGearNoteSheet(
                  context,
                  diveCenterId: centerId,
                  editing: note,
                ),
              ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Mount it on the page**

In `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`, add the import:

```dart
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_section.dart';
```

In the body `Column` (about line 99), between the notes block and `const Divider(height: 32),` that precedes `_DivesSection`, insert:

```dart
              const Divider(height: 32),
              RentalGearSection(centerId: widget.centerId),
```

so the order reads: map, header, divider, contact, (divider, notes), divider, rental gear, divider, dives.

- [ ] **Step 5: Run the section and page tests**

Run: `flutter test test/features/dive_centers/presentation/widgets/rental_gear_section_test.dart test/features/dive_centers/presentation/pages/dive_center_detail_page_test.dart`
Expected: all PASS. If a detail page test fails because the section's provider reaches the database, add `diveCenterGearNotesProvider(center.id).overrideWith((ref) async => [])` to that test's overrides next to its `diveCenterDiveCountProvider` override.

- [ ] **Step 6: Format, analyze and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_centers/presentation/widgets/rental_gear_section.dart lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart test/features/dive_centers/presentation/widgets/rental_gear_section_test.dart
git commit -m "feat(dive-centers): rental gear section on the dive center page (#2075)"
```

---

### Task 10: Whole-project verification and the PR

**Files:**
- No new files. Fixes only where a check below fails.

- [ ] **Step 1: Architecture guards**

New files under `lib/` were added in Tasks 1, 4, 6, 7 and 9; the guard suite scans all of `lib/` and never runs in an affected-directory run.

Run: `flutter test test/architecture/`
Expected: PASS. A failure names the file and the rule; fix the file.

- [ ] **Step 2: Re-check the schema rung**

Run the two commands from Global Constraints once more. If main moved to 220 or 221 while this branch was built, merge `origin/main` into the branch, renumber this rung to the next free number in `database.dart` (the constant, the `migrationVersions` entry and comment, both `from < 221` guards, the backstop comment), rename and update `migration_v221_dive_center_gear_notes_test.dart`, and re-run Task 2's tests.

- [ ] **Step 3: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `dart format` reports 0 changed files; `flutter analyze` prints `No issues found!`. Infos are fatal in CI, so fix them too.

- [ ] **Step 4: Regenerate l10n and confirm nothing changes**

```bash
flutter gen-l10n
git status --porcelain -- lib/l10n/arb/
```

Expected: empty output. Any line means an ARB edit was never generated; commit the generated files with an `i18n:` commit.

- [ ] **Step 5: The full test suite, once**

Do not start it while another `flutter test` is running on this machine (`pgrep -fl "flutter test"` must print nothing).

Run: `flutter test`
Expected: every test passes. Read the exit status directly, never through a pipe. A failure in a file this branch never touched means main is red; check `gh run list --branch main --limit 3` before blaming the branch.

- [ ] **Step 6: Commit any fixes, then push and open the PR**

```bash
git status --short
```

Stage and commit only files this branch changed. Then:

```bash
git push -u origin ericgriffin/rental-gear-memory-2db80e
```

The pre-push hook runs format, analyze, the l10n staleness check and tests; let it run. Then open the PR against `main` with this body, written to a scratch file and passed with `--body-file`:

```markdown
Closes #2075

Remember what worked with a dive center's rental gear, and surface it on a return visit.

- A new synced child table of dive centers, `dive_center_gear_notes` (schema v221), holds typed notes: gear type, the operator's label, size, a worked/avoid verdict, an optional lead adjustment, an optional true tank capacity, free text, and the dive it was noticed on.
- In the dive edit form, picking a dive center shows "Last time at {center}": the lead, weighting feedback and tanks of the most recent other dive there, plus the notes. "Apply last dive" copies those weights and tanks (fresh ids, default pressures) into the form, asking first when the form already has any. "Add rental note" opens the shared sheet.
- The dive center detail page gains a "Rental gear" section grouped by gear type, with add and tap-to-edit.
- Notes sync as a parent-gated child of dive centers; deleting a center tombstones its notes so peers do not resurrect them. Deleting a dive detaches its notes rather than removing them.
- All values respect the diver's weight and volume units. Strings in all 11 locales.

Design: `docs/superpowers/specs/2026-09-18-rental-gear-memory-design.md`. Plan: `docs/superpowers/plans/2026-09-18-rental-gear-memory.md`.
```

Title: `feat(dive-centers): remember what worked with an operator's rental gear`

```bash
gh pr create --base main --title "feat(dive-centers): remember what worked with an operator's rental gear" --body-file /tmp/rental_pr_body.md
```

- [ ] **Step 7: Watch CI**

Use the desktop app's PR tools (`bind_pr`, then `get_status`) rather than polling `gh`. A single shard failing on a libsqlcipher hash mismatch or a pdfium fetch reset is a transient download; rerun the failed jobs after the run completes. Every shard failing the same way is real.
