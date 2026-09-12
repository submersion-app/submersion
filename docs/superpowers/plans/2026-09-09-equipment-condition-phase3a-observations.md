# Equipment Condition Intelligence, Phase 3a: Observations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver record what a piece of gear did on a dive (an OK check or a tagged issue with a note), from the dive's equipment and cylinder rows and from the item's own page, sync those observations between devices, attribute an incident to an item, and carry observations through the UDDF full export and import, the Excel workbook and a CSV file.

**Architecture:** `equipment_observations` (created in v202) becomes a synced aggregate root with its own HLC, wired through the serializer and the merge order like `incidents`. A pure entity plus a tag catalog keyed by `EquipmentType` sits in the domain layer; one repository owns reads, writes and the sync bookkeeping; two family providers self-invalidate on the repository's change stream. The check-in sheet is one widget used from three places (dive equipment rows, dive cylinder rows, the item page). The domain `DiveTank` gains a read-only `equipmentId` so a cylinder row can find its gear item. Exports resolve dive references through the dive's UDDF id, which the full importer already keeps as `sourceUuid`. No schema rung.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, xml builder, excel_community, csv, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Data model: `equipment_observations` and `ObservationTag`; Observations and incidents; Sync; Export and import). This plan is the first half of phase 3; phase 3b (condition engine, findings, review marker, settings toggles) stacks on it.

**Decisions taken for phase 3 (asked and answered 2026-09-09):** two stacked PRs, 3a observations then 3b engine; the check-in chip and sheet appear on the dive's equipment rows AND on cylinder rows that carry a gear link; rule toggles (3b) always compute and hide at display time; the engine toggles (3b) live in `diver_settings` columns behind a v206 rung. Nothing in 3a takes a rung.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings). Rewrite the sentence instead.
- No tool or vendor attribution in any commit, comment, file or PR body.
- Run `dart format .` before every commit. The pre-push hook runs format, analyze, l10n staleness and tests.
- TDD: write the failing test first, run it, watch it fail, then implement.
- Every user-facing string goes through `context.l10n` and is added to all 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`). Only `app_en.arb` is alphabetical; in the other ten files insert each key next to the same neighbouring key it sits beside in English. Regenerate with `flutter gen-l10n` after editing ARB files. The generated `lib/l10n/arb/app_localizations*.dart` files are tracked and must be staged with the ARB edits. Key style is `section_camelCase`.
- Anything displaying units respects the active diver's unit settings (`UnitFormatter`): dates through `units.formatDate` / `formatDateTime(l10n: ...)`.
- **No schema rung.** `equipment_observations` and `incidents.equipment_id` exist since v202. `currentSchemaVersion` stays at 203.
- The word `build` alone in a Bash command can be refused by the harness; codegen is not needed in this plan (no `database.dart` change).
- Commit after every task with the message given in the task. Never `git add -A`; stage the listed paths.
- Tests importing both `drift` and `flutter_test` must `hide isNull, isNotNull` on the drift import.
- A bare `ProviderScope` that reaches `currentDiverIdProvider` overrides it with `MockCurrentDiverIdNotifier()` from `test/helpers/mock_providers.dart`.
- Every new regression test is run once against the code before the implementation lands, to prove it fails.

## File structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/equipment_observation.dart` | `ObservationStatus`, `ObservationTag`, `EquipmentObservation`, tag JSON codec |
| `lib/features/equipment/domain/constants/observation_tag_catalog.dart` | `observationTagsFor(EquipmentType)` |
| `lib/features/equipment/data/repositories/equipment_observation_repository.dart` | Reads, writes, sync bookkeeping, change stream |
| `lib/features/equipment/presentation/providers/equipment_observation_providers.dart` | Repository provider, per-item and per-dive families |
| `lib/features/equipment/presentation/utils/observation_tag_display.dart` | `ObservationTag.localizedName(l10n)` |
| `lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart` | The check-in sheet (list, add, edit, delete) |
| `lib/features/equipment/presentation/widgets/observation_status_chip.dart` | The trailing chip on dive rows |
| `lib/features/equipment/presentation/widgets/observations_card.dart` | The item page card |
| `lib/core/services/export/excel/observations_excel_export_service.dart` | "Observations" sheet |
| `test/features/equipment/domain/entities/equipment_observation_test.dart` | Entity and codec |
| `test/features/equipment/domain/constants/observation_tag_catalog_test.dart` | Catalog coverage |
| `test/features/equipment/data/repositories/equipment_observation_repository_test.dart` | CRUD, cascade, set-null, sync marks |
| `test/core/services/sync/equipment_observations_sync_test.dart` | Round trip and delta export |
| `test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart` | Read-only tank gear link |
| `test/features/equipment/presentation/providers/equipment_observation_providers_test.dart` | Families refresh on write |
| `test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart` | Add, edit, delete, tag filter |
| `test/features/equipment/presentation/widgets/observation_status_chip_test.dart` | Chip states |
| `test/features/equipment/presentation/widgets/observations_card_test.dart` | Card list and actions |
| `test/core/services/export/excel/observations_excel_export_service_test.dart` | Sheet content |
| `test/core/services/export/uddf/uddf_observations_round_trip_test.dart` | Export and import of parentref and observations |

Modified files: `lib/features/dive_log/domain/entities/dive.dart` (`DiveTank.equipmentId`), `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (two tank read mappers), `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `test/core/services/sync/sync_parent_refs_completeness_test.dart`, `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/widgets/cylinders_card.dart`, `lib/features/equipment/presentation/pages/equipment_detail_page.dart` and every test that pumps it, `lib/features/safety/domain/entities/incident.dart`, `lib/features/safety/data/repositories/incident_repository.dart`, `lib/features/safety/presentation/pages/incident_edit_page.dart`, `lib/core/services/export/uddf/uddf_export_builders.dart`, `lib/core/services/export/uddf/uddf_full_export_service.dart`, `lib/core/services/export/uddf/uddf_import_parsers.dart`, `lib/core/services/export/uddf/uddf_full_import_service.dart`, `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/core/services/export/excel/excel_export_service.dart`, `lib/core/services/export/csv/csv_export_service.dart`, `lib/core/services/export/export_service.dart`, `lib/features/settings/presentation/providers/export_providers.dart`, `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`, `lib/features/transfer/presentation/pages/transfer_page.dart`, the 11 ARB files.

---

### Task 0: Branch and preflight

**Files:** none modified.

- [ ] **Step 1: Branch from the phase 2 branch**

```bash
git checkout -b ericgriffin/equipment-condition-phase3a-observations ericgriffin/equipment-condition-phase2-sensor-summary
git branch --show-current
```

Expected: `ericgriffin/equipment-condition-phase3a-observations`.

- [ ] **Step 2: Confirm the worktree and analyzer**

```bash
git submodule update --init --recursive && flutter pub get && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Confirm the table and the registry entry**

```bash
grep -n "class EquipmentObservations" lib/core/database/database.dart
grep -n "'equipmentObservations'" lib/core/data/repositories/sync_repository.dart
grep -n "DataClassName('EquipmentObservationRow')" lib/core/database/database.dart
```

Expected: one hit each. The generated companion is `EquipmentObservationsCompanion`; confirm with `grep -n "class EquipmentObservationsCompanion" lib/core/database/database.g.dart`.

---

### Task 1: Observation entity, tags and codec

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_observation.dart`
- Create: `lib/features/equipment/domain/constants/observation_tag_catalog.dart`
- Test: `test/features/equipment/domain/entities/equipment_observation_test.dart`
- Test: `test/features/equipment/domain/constants/observation_tag_catalog_test.dart`

**Interfaces:**
- Produces: `enum ObservationStatus { ok, issue }` with `dbValue`/`fromDbValue`; `enum ObservationTag` (35 values, names are the stored values) with `dbValue`/`fromDbValue` (null for unknown); `EquipmentObservation` (`id, diverId?, equipmentId, diveId?, observedAt, status, issueTags, note, createdAt, updatedAt`, `copyWith` with `clearDiveId`, `bool get isIssue`); `encodeObservationTags(List<ObservationTag>) -> String`, `decodeObservationTags(String) -> List<ObservationTag>`; `List<ObservationTag> observationTagsFor(EquipmentType type)` (always ends with `other`, never duplicates).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/domain/entities/equipment_observation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

void main() {
  test('status round-trips and unknown falls back to ok', () {
    expect(ObservationStatus.issue.dbValue, 'issue');
    expect(ObservationStatus.fromDbValue('issue'), ObservationStatus.issue);
    expect(ObservationStatus.fromDbValue('bogus'), ObservationStatus.ok);
  });

  test('tags round-trip and unknown names are dropped', () {
    expect(ObservationTag.freeFlow.dbValue, 'freeFlow');
    expect(ObservationTag.fromDbValue('leakZip'), ObservationTag.leakZip);
    expect(ObservationTag.fromDbValue('nope'), isNull);
    final json = encodeObservationTags([
      ObservationTag.freeFlow,
      ObservationTag.other,
    ]);
    expect(json, '["freeFlow","other"]');
    expect(decodeObservationTags(json), [
      ObservationTag.freeFlow,
      ObservationTag.other,
    ]);
    expect(decodeObservationTags('["freeFlow","nope"]'), [
      ObservationTag.freeFlow,
    ]);
    expect(decodeObservationTags('[]'), isEmpty);
    expect(decodeObservationTags(''), isEmpty);
    expect(decodeObservationTags('garbage'), isEmpty);
  });

  test('entity is a value object with clearDiveId', () {
    final a = EquipmentObservation(
      id: 'o1',
      equipmentId: 'e1',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 9, 9, 15),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow],
      note: 'Free flow at 30 m',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 9, 16),
    );
    expect(a.isIssue, isTrue);
    expect(a.copyWith(clearDiveId: true).diveId, isNull);
    expect(a.copyWith(status: ObservationStatus.ok).isIssue, isFalse);
    expect(a, a.copyWith());
  });
}
```

```dart
// test/features/equipment/domain/constants/observation_tag_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

void main() {
  test('every type ends with other and has no duplicates', () {
    for (final type in EquipmentType.values) {
      final tags = observationTagsFor(type);
      expect(tags.last, ObservationTag.other, reason: type.name);
      expect(tags.toSet().length, tags.length, reason: type.name);
    }
  });

  test('the spec groups are honoured', () {
    expect(observationTagsFor(EquipmentType.regulator), [
      ObservationTag.freeFlow,
      ObservationTag.hardBreathing,
      ObservationTag.wetBreathing,
      ObservationTag.leak,
      ObservationTag.hoseDamage,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.drysuit), [
      ObservationTag.leakNeck,
      ObservationTag.leakWrist,
      ObservationTag.leakZip,
      ObservationTag.leakBoot,
      ObservationTag.leakValve,
      ObservationTag.leakSeam,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.hood), [
      ObservationTag.tear,
      ObservationTag.seamFailure,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.transmitter), [
      ObservationTag.dropout,
      ObservationTag.batteryLow,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.o2Cell), [
      ObservationTag.slowResponse,
      ObservationTag.erratic,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.mask), [
      ObservationTag.strapBroke,
      ObservationTag.leak,
      ObservationTag.other,
    ]);
    expect(observationTagsFor(EquipmentType.weights), [ObservationTag.other]);
  });

  test('every tag is offered for at least one type', () {
    final offered = {
      for (final type in EquipmentType.values) ...observationTagsFor(type),
    };
    expect(offered, ObservationTag.values.toSet());
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/entities/equipment_observation_test.dart test/features/equipment/domain/constants/observation_tag_catalog_test.dart`
Expected: FAIL, imports do not resolve.

- [ ] **Step 3: Write the entity**

```dart
// lib/features/equipment/domain/entities/equipment_observation.dart
import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Whether a check-in recorded a problem. An `ok` row is a deliberate
/// check and is evidence in its own right ("no issue in 12 checked dives").
enum ObservationStatus {
  ok,
  issue;

  String get dbValue => name;

  static ObservationStatus fromDbValue(String? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return ObservationStatus.ok;
  }
}

/// What went wrong. Names are the stored values; the catalog says which
/// tags each equipment type is offered.
enum ObservationTag {
  freeFlow,
  hardBreathing,
  wetBreathing,
  leak,
  hoseDamage,
  inflatorStuck,
  inflatorSlow,
  bladderLeak,
  dumpLeak,
  leakNeck,
  leakWrist,
  leakZip,
  leakBoot,
  leakValve,
  leakSeam,
  tear,
  seamFailure,
  dim,
  died,
  flooded,
  switchFault,
  batteryLow,
  screenFault,
  connectionFault,
  dropout,
  cellWarning,
  loopLeak,
  solenoidFault,
  scrubberBreakthrough,
  slowResponse,
  erratic,
  lowCapacity,
  propFault,
  strapBroke,
  other;

  String get dbValue => name;

  /// Null for a name this build does not know (a newer peer), so the
  /// caller drops it rather than mislabel it.
  static ObservationTag? fromDbValue(String value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

/// One post-dive (or bench) check-in on one item. Any number may share an
/// item and a dive.
class EquipmentObservation extends Equatable {
  final String id;
  final String? diverId;
  final String equipmentId;

  /// The dive the check-in belongs to; null for a bench observation.
  final String? diveId;
  final DateTime observedAt;
  final ObservationStatus status;
  final List<ObservationTag> issueTags;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentObservation({
    required this.id,
    this.diverId,
    required this.equipmentId,
    this.diveId,
    required this.observedAt,
    required this.status,
    this.issueTags = const [],
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIssue => status == ObservationStatus.issue;

  EquipmentObservation copyWith({
    String? id,
    String? diverId,
    String? equipmentId,
    String? diveId,
    bool clearDiveId = false,
    DateTime? observedAt,
    ObservationStatus? status,
    List<ObservationTag>? issueTags,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EquipmentObservation(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    equipmentId: equipmentId ?? this.equipmentId,
    diveId: clearDiveId ? null : (diveId ?? this.diveId),
    observedAt: observedAt ?? this.observedAt,
    status: status ?? this.status,
    issueTags: issueTags ?? this.issueTags,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    equipmentId,
    diveId,
    observedAt,
    status,
    issueTags,
    note,
    createdAt,
    updatedAt,
  ];
}

String encodeObservationTags(List<ObservationTag> tags) =>
    jsonEncode([for (final t in tags) t.dbValue]);

/// Lenient: the column defaults to `[]`, and a tag a newer build added must
/// not make the row unreadable. Unknown names are dropped.
List<ObservationTag> decodeObservationTags(String json) {
  if (json.isEmpty) return const [];
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (entry is String) ?ObservationTag.fromDbValue(entry),
  ];
}
```

- [ ] **Step 4: Write the catalog**

```dart
// lib/features/equipment/domain/constants/observation_tag_catalog.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

/// The tags a check-in offers for one equipment type, in display order,
/// always ending with `other`. Mirrors the spec's table; a type the spec
/// does not name gets `other` only.
List<ObservationTag> observationTagsFor(EquipmentType type) {
  final specific = switch (type) {
    EquipmentType.regulator ||
    EquipmentType.firstStage ||
    EquipmentType.secondStage ||
    EquipmentType.hose => const [
      ObservationTag.freeFlow,
      ObservationTag.hardBreathing,
      ObservationTag.wetBreathing,
      ObservationTag.leak,
      ObservationTag.hoseDamage,
    ],
    EquipmentType.bcd || EquipmentType.wing => const [
      ObservationTag.inflatorStuck,
      ObservationTag.inflatorSlow,
      ObservationTag.bladderLeak,
      ObservationTag.dumpLeak,
    ],
    EquipmentType.drysuit => const [
      ObservationTag.leakNeck,
      ObservationTag.leakWrist,
      ObservationTag.leakZip,
      ObservationTag.leakBoot,
      ObservationTag.leakValve,
      ObservationTag.leakSeam,
    ],
    EquipmentType.wetsuit ||
    EquipmentType.undersuit ||
    EquipmentType.baselayer ||
    EquipmentType.rashGuard ||
    EquipmentType.hood ||
    EquipmentType.gloves ||
    EquipmentType.boots => const [
      ObservationTag.tear,
      ObservationTag.seamFailure,
    ],
    EquipmentType.light || EquipmentType.strobe => const [
      ObservationTag.dim,
      ObservationTag.died,
      ObservationTag.flooded,
      ObservationTag.switchFault,
    ],
    EquipmentType.computer || EquipmentType.instrument => const [
      ObservationTag.batteryLow,
      ObservationTag.screenFault,
      ObservationTag.connectionFault,
    ],
    EquipmentType.transmitter => const [
      ObservationTag.dropout,
      ObservationTag.batteryLow,
    ],
    EquipmentType.rebreather => const [
      ObservationTag.cellWarning,
      ObservationTag.loopLeak,
      ObservationTag.solenoidFault,
      ObservationTag.scrubberBreakthrough,
    ],
    EquipmentType.o2Cell => const [
      ObservationTag.slowResponse,
      ObservationTag.erratic,
    ],
    EquipmentType.battery => const [
      ObservationTag.died,
      ObservationTag.lowCapacity,
    ],
    EquipmentType.dpv => const [
      ObservationTag.died,
      ObservationTag.flooded,
      ObservationTag.propFault,
    ],
    EquipmentType.fins || EquipmentType.mask || EquipmentType.snorkel => const [
      ObservationTag.strapBroke,
      ObservationTag.leak,
    ],
    EquipmentType.camera || EquipmentType.housing => const [
      ObservationTag.flooded,
    ],
    _ => const <ObservationTag>[],
  };
  return [...specific, ObservationTag.other];
}
```

The spec names the primary types; the near relatives above (first and second stages, hoses, wings, strobes, instruments, base layers, camera housings) get the group their parent type gets, so a diver who logs stages separately still sees the regulator tags. Confirm every `EquipmentType` value used exists in `lib/core/constants/enums.dart` (the list at the time of writing: regulator firstStage secondStage hose bcd backplate wing harness wetsuit drysuit undersuit baselayer rashGuard fins mask snorkel computer transmitter instrument compass tank rebreather weights light camera housing strobe smb reel knife tool hood gloves boots dpv o2Cell battery other).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/entities/equipment_observation_test.dart test/features/equipment/domain/constants/observation_tag_catalog_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/domain/entities/equipment_observation.dart lib/features/equipment/domain/constants/observation_tag_catalog.dart test/features/equipment/domain/entities/equipment_observation_test.dart test/features/equipment/domain/constants/observation_tag_catalog_test.dart
git add lib/features/equipment/domain/entities/equipment_observation.dart lib/features/equipment/domain/constants/observation_tag_catalog.dart test/features/equipment/domain/entities/equipment_observation_test.dart test/features/equipment/domain/constants/observation_tag_catalog_test.dart
git commit -m "feat(equipment): observation entity, tag catalog and codec (condition phase 3a)"
```

---

### Task 2: EquipmentObservationRepository

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_observation_repository.dart`
- Test: `test/features/equipment/data/repositories/equipment_observation_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.equipmentObservations` (row `EquipmentObservationRow`, companion `EquipmentObservationsCompanion`), `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})` and `logDeletion({entityType, recordId})` (`lib/core/data/repositories/sync_repository.dart`), `SyncEventBus.notifyLocalChange()` (`lib/core/services/sync/sync_event_bus.dart`), `DatabaseService.instance.database`, `Uuid`.
- Produces:
  - `EquipmentObservationRepository({AppDatabase? db, SyncRepository? syncRepository})`
  - `static const String entityType = 'equipmentObservations';`
  - `Stream<void> watchChanges()`
  - `Future<List<EquipmentObservation>> getForEquipment(String equipmentId)` (newest `observedAt` first)
  - `Future<List<EquipmentObservation>> getForDive(String diveId)`
  - `Future<List<EquipmentObservation>> getForEquipmentOnDive(String equipmentId, String diveId)`
  - `Future<List<EquipmentObservation>> getAll({String? diverId})`
  - `Future<EquipmentObservation?> getById(String id)`
  - `Future<EquipmentObservation> create({required String equipmentId, String? diveId, String? diverId, required DateTime observedAt, required ObservationStatus status, List<ObservationTag> issueTags = const [], String note = '', DateTime? now})`
  - `Future<void> update(EquipmentObservation observation, {DateTime? now})`
  - `Future<void> delete(String id)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/repositories/equipment_observation_repository_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, date) in [('d1', 1000), ('d2', 2000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('create stores the row, stamps an hlc and reads back', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 9, 9, 15),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow, ObservationTag.other],
      note: 'Free flow at depth',
      now: DateTime.utc(2026, 9, 9, 16),
    );
    expect(created.id, isNotEmpty);
    expect(created.createdAt, DateTime.utc(2026, 9, 9, 16));

    final stored = await repo.getById(created.id);
    expect(stored, created);

    final row = await (db.select(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.issueTags, '["freeFlow","other"]');
    expect(row.status, 'issue');
    expect(row.hlc, isNotNull);
  });

  test('queries by item, by dive and by both, newest first', () async {
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd2',
      observedAt: DateTime.utc(2026, 2, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
    );
    await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 3, 1),
      status: ObservationStatus.ok,
    );

    final byItem = await repo.getForEquipment('reg');
    expect(byItem.map((o) => o.observedAt.month), [3, 2, 1]);
    expect((await repo.getForDive('d2')).single.isIssue, isTrue);
    expect(await repo.getForEquipmentOnDive('reg', 'd1'), hasLength(1));
    expect(await repo.getForEquipmentOnDive('reg', 'nope'), isEmpty);
    expect(await repo.getAll(), hasLength(3));
  });

  test('update rewrites the row and bumps updatedAt', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
      now: DateTime.utc(2026, 1, 1),
    );
    await repo.update(
      created.copyWith(
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.hoseDamage],
        note: 'Hose cracked',
      ),
      now: DateTime.utc(2026, 1, 2),
    );
    final stored = await repo.getById(created.id);
    expect(stored!.isIssue, isTrue);
    expect(stored.issueTags, [ObservationTag.hoseDamage]);
    expect(stored.note, 'Hose cracked');
    expect(stored.updatedAt, DateTime.utc(2026, 1, 2));
  });

  test('delete removes the row and logs a deletion', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await repo.delete(created.id);
    expect(await repo.getById(created.id), isNull);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((t) => t.recordId == created.id).single.entityType,
      'equipmentObservations',
    );
  });

  test('deleting the item cascades, deleting the dive sets null', () async {
    final onDive = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect((await repo.getById(onDive.id))!.diveId, isNull);

    await (db.delete(db.equipment)..where((t) => t.id.equals('reg'))).go();
    expect(await repo.getById(onDive.id), isNull);
  });

  test('a tag this build does not know is dropped on read', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
    );
    await (db.update(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).write(
      const EquipmentObservationsCompanion(
        issueTags: Value('["leak","futureTag"]'),
      ),
    );
    expect((await repo.getById(created.id))!.issueTags, [ObservationTag.leak]);
  });
}
```

Check `EquipmentCompanion.insert` required fields (`grep -n "EquipmentCompanion.insert({" -A30 lib/core/database/database.g.dart | grep required`) and the deletion log table name (`grep -n "class DeletionLog" lib/core/database/database.dart`) and its column names; adjust the two spots.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_observation_repository_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the repository**

```dart
// lib/features/equipment/data/repositories/equipment_observation_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

/// Owns `equipment_observations`, a synced aggregate root with its own HLC:
/// every write marks the row pending, every delete logs a tombstone, like
/// `IncidentRepository`.
class EquipmentObservationRepository {
  static const String entityType = 'equipmentObservations';

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  EquipmentObservationRepository({
    AppDatabase? db,
    SyncRepository? syncRepository,
  }) : _dbOverride = db,
       _syncRepository = syncRepository ?? SyncRepository();

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Stream<void> watchChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.equipmentObservations))
      .map((_) {});

  Future<List<EquipmentObservation>> getForEquipment(String equipmentId) =>
      _query((t) => t.equipmentId.equals(equipmentId));

  Future<List<EquipmentObservation>> getForDive(String diveId) =>
      _query((t) => t.diveId.equals(diveId));

  Future<List<EquipmentObservation>> getForEquipmentOnDive(
    String equipmentId,
    String diveId,
  ) => _query(
    (t) => t.equipmentId.equals(equipmentId) & t.diveId.equals(diveId),
  );

  Future<List<EquipmentObservation>> getAll({String? diverId}) => _query(
    diverId == null ? null : (t) => t.diverId.equals(diverId),
  );

  Future<EquipmentObservation?> getById(String id) async {
    final row = await (_db.select(
      _db.equipmentObservations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<EquipmentObservation> create({
    required String equipmentId,
    String? diveId,
    String? diverId,
    required DateTime observedAt,
    required ObservationStatus status,
    List<ObservationTag> issueTags = const [],
    String note = '',
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final observation = EquipmentObservation(
      id: _uuid.v4(),
      diverId: diverId,
      equipmentId: equipmentId,
      diveId: diveId,
      observedAt: observedAt,
      status: status,
      issueTags: issueTags,
      note: note,
      createdAt: stamp,
      updatedAt: stamp,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.equipmentObservations)
          .insert(_toCompanion(observation));
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: observation.id,
        localUpdatedAt: stamp.millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
    return observation;
  }

  Future<void> update(EquipmentObservation observation, {DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    final updated = observation.copyWith(updatedAt: stamp);
    await _db.transaction(() async {
      await _db
          .into(_db.equipmentObservations)
          .insertOnConflictUpdate(_toCompanion(updated));
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: updated.id,
        localUpdatedAt: stamp.millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.equipmentObservations,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<List<EquipmentObservation>> _query(
    Expression<bool> Function($EquipmentObservationsTable t)? where,
  ) async {
    final query = _db.select(_db.equipmentObservations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.observedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (where != null) query.where(where);
    final rows = await query.get();
    return [for (final row in rows) _toDomain(row)];
  }

  EquipmentObservationsCompanion _toCompanion(EquipmentObservation o) =>
      EquipmentObservationsCompanion.insert(
        id: o.id,
        diverId: Value(o.diverId),
        equipmentId: o.equipmentId,
        diveId: Value(o.diveId),
        observedAt: o.observedAt.millisecondsSinceEpoch,
        status: o.status.dbValue,
        issueTags: Value(encodeObservationTags(o.issueTags)),
        note: Value(o.note),
        createdAt: o.createdAt.millisecondsSinceEpoch,
        updatedAt: o.updatedAt.millisecondsSinceEpoch,
      );

  EquipmentObservation _toDomain(EquipmentObservationRow row) =>
      EquipmentObservation(
        id: row.id,
        diverId: row.diverId,
        equipmentId: row.equipmentId,
        diveId: row.diveId,
        observedAt: DateTime.fromMillisecondsSinceEpoch(
          row.observedAt,
          isUtc: true,
        ),
        status: ObservationStatus.fromDbValue(row.status),
        issueTags: decodeObservationTags(row.issueTags),
        note: row.note,
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

Check `SyncRepository(database: db)` is the constructor parameter name (`grep -n "SyncRepository({" -A3 lib/core/data/repositories/sync_repository.dart`) and how `markRecordPending` stamps the row's `hlc` for a table listed in `hlcTargets` (it does for `equipmentObservations`, which phase 1 registered).

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/repositories/equipment_observation_repository_test.dart`
Expected: all pass. If the hlc assertion fails, read `SyncRepository.markRecordPending` to confirm it writes `hlc` through `hlcTargets`; the phase 1 registry entry is the reason it should.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/data/repositories/equipment_observation_repository.dart test/features/equipment/data/repositories/equipment_observation_repository_test.dart
git add lib/features/equipment/data/repositories/equipment_observation_repository.dart test/features/equipment/data/repositories/equipment_observation_repository_test.dart
git commit -m "feat(equipment): observation repository with sync bookkeeping (condition phase 3a)"
```

---

### Task 3: Observations travel through sync

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every arm listed below)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder`, `entityHasUpdatedAt`, `parentRefs`)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` map)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (`targets` list)
- Test: `test/core/services/sync/equipment_observations_sync_test.dart`

**Interfaces:**
- Produces: `SyncData.equipmentObservations`; serializer arms keyed `'equipmentObservations'`; merge order entry after `incidents`; `parentRefs['equipmentObservations']`.

Every arm mirrors the `incidents` arm at the lines found by `grep -n "'incidents'" lib/core/services/sync/sync_data_serializer.dart` (466, 553, 987, 1594, 2116, 3165, 4125, 4462, 4701, 5093 at the time of writing) plus the field (line 301) and constructor default (line 385). Place each new entry immediately AFTER its `incidents` sibling so `debugBaseTableKeys` and `SyncData.toJson` stay in the same order.

- [ ] **Step 1: Write the failing round-trip test**

```dart
// test/core/services/sync/equipment_observations_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  Map<String, dynamic> observation(String id, {String? diveId}) => {
    'id': id,
    'diverId': null,
    'equipmentId': 'reg',
    'diveId': diveId,
    'observedAt': 1000,
    'status': 'issue',
    'issueTags': '["freeFlow"]',
    'note': 'n',
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  test('SyncData carries the entity and the base table key', () {
    expect(SyncDataSerializer.debugBaseTableKeys, contains('equipmentObservations'));
    expect(
      SyncData.fromJson({
        'equipmentObservations': [observation('o1')],
      }).equipmentObservations,
      hasLength(1),
    );
    expect(
      const SyncData().toJson().keys,
      contains('equipmentObservations'),
    );
  });

  test('upsertRecord then fetchRecord round-trips every column', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'reg',
      'name': 'Reg',
      'type': 'regulator',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1,
      'updatedAt': 1,
    });
    await serializer.upsertRecord(
      'equipmentObservations',
      observation('o1', diveId: null),
    );
    final back = await serializer.fetchRecord('equipmentObservations', 'o1');
    expect(back!['equipmentId'], 'reg');
    expect(back['status'], 'issue');
    expect(back['issueTags'], '["freeFlow"]');
    expect(back['note'], 'n');
  });

  test('a local write is exported by hlc and deletion propagates', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'reg',
      'name': 'Reg',
      'type': 'regulator',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1,
      'updatedAt': 1,
    });
    final repo = EquipmentObservationRepository(
      syncRepository: SyncRepository(),
    );
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.ok,
    );
    final changeset = await serializer.exportChangeset(hlcSince: null);
    expect(
      changeset.equipmentObservations.map((r) => r['id']),
      contains(created.id),
    );
    await repo.delete(created.id);
    expect(await serializer.fetchRecord('equipmentObservations', created.id), isNull);
  });

  test('the merge order, updatedAt map and parent refs know the entity', () {
    expect(SyncService.entityHasUpdatedAt['equipmentObservations'], isTrue);
    final refs = SyncService.parentRefs['equipmentObservations']!;
    expect(refs.map((r) => r.field), ['diverId', 'equipmentId', 'diveId']);
    expect(refs.where((r) => r.field == 'equipmentId').single.nullable, isFalse);
  });
}
```

Check the actual names of `exportChangeset`'s parameter and return type (`grep -n "Future<SyncData> exportChangeset" lib/core/services/sync/sync_data_serializer.dart`), `const SyncData()` being const-constructible, and the `ParentRef` record field names (`grep -n "typedef ParentRef" lib/core/services/sync/sync_service.dart`); adjust the test to match.

- [ ] **Step 2: Run the test and the two census tests to verify they fail**

Run: `flutter test test/core/services/sync/equipment_observations_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: the new test fails to compile (`equipmentObservations` unknown); the completeness test fails because `equipment_observations` has an FK to a deletable parent but no `parentRefs` entry. (If the completeness test already passes because the table is not in its `syncedTables` map, it is still added in Step 5.)

- [ ] **Step 3: Serializer arms**

In `sync_data_serializer.dart`, after each `incidents` line add the `equipmentObservations` twin:

1. Field: `final List<Map<String, dynamic>> equipmentObservations;`
2. Constructor default: `this.equipmentObservations = const [],`
3. `toJson`: `'equipmentObservations': equipmentObservations,`
4. `fromJson`: `equipmentObservations: _parseList(json['equipmentObservations']),`
5. `_baseTables`: `(key: 'equipmentObservations', table: _db.equipmentObservations, blob: false, full: null),`
6. `exportChangeset`: 

```dart
      equipmentObservations: await _safeExport(
        'equipmentObservations',
        () => _exportEquipmentObservations(hlcSince),
      ),
```

7. Exporter, next to `_exportIncidents`:

```dart
  Future<List<Map<String, dynamic>>> _exportEquipmentObservations(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final rows = await (_db.select(
        _db.equipmentObservations,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.equipmentObservations).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

8. `fetchRecord`:

```dart
      case 'equipmentObservations':
        final row = await (_db.select(
          _db.equipmentObservations,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

9. `upsertRecord`:

```dart
      case 'equipmentObservations':
        await _db
            .into(_db.equipmentObservations)
            .insertOnConflictUpdate(EquipmentObservationRow.fromJson(data));
        return;
```

10. `upsertRecords` (batch):

```dart
      case 'equipmentObservations':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentObservations,
            records.map((r) => EquipmentObservationRow.fromJson(r)).toList(),
          ),
        );
        return;
```

11. `recordIdsFor`: `case 'equipmentObservations': return plain(_db.equipmentObservations, _db.equipmentObservations.id);`
12. Table lookup: `case 'equipmentObservations': return _db.equipmentObservations;`
13. `deleteRecord`:

```dart
      case 'equipmentObservations':
        await (_db.delete(
          _db.equipmentObservations,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 4: Sync service**

In `sync_service.dart`:

1. `mergeOrder`, after the `incidents` record:

```dart
          (
            type: 'equipmentObservations',
            records: data.equipmentObservations,
            hasUpdatedAt: true,
          ),
```

2. `entityHasUpdatedAt`: `'equipmentObservations': true,` after `'incidents': true,`.
3. `parentRefs`, after the `incidents` entry:

```dart
    // v202: a gear check-in; the item is required, the dive optional.
    'equipmentObservations': [
      (field: 'diverId', parent: 'divers', nullable: true),
      (field: 'equipmentId', parent: 'equipment', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: true),
    ],
```

- [ ] **Step 5: Census tests**

In `test/core/services/sync/sync_parent_refs_completeness_test.dart` add `'equipment_observations': 'equipmentObservations',` to the `syncedTables` map next to `'incidents'`. In `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` add `(type: 'equipmentObservations', table: db.equipmentObservations.actualTableName),` to `targets` next to the `incidents` entry.

- [ ] **Step 6: Run the sync tests**

Run:

```bash
flutter test test/core/services/sync/equipment_observations_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_service_entity_flags_test.dart
```

(Skip any file that does not exist; `ls test/core/services/sync | grep -i "flag\|order"` finds the test that asserts `entityHasUpdatedAt` covers `SyncData`.) Expected: all pass.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/equipment_observations_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/equipment_observations_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart
git commit -m "feat(sync): equipment observations travel as an aggregate root (condition phase 3a)"
```

---

### Task 4: A dive tank knows its gear item

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`DiveTank`, after `regulatorEquipmentId` around line 1084)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (the two `domain.DiveTank(` read mappers at lines 3591 and 3999)
- Test: `test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart`

**Interfaces:**
- Produces: `DiveTank.equipmentId` (`String?`, read-only: mapped on read, never written by the edit flows, exactly like `computerId`; the transmitter registry's `applyToExistingDives` is the writer).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'al80',
            name: 'AL80',
            type: 'tank',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
          ).copyWith(equipmentId: const Value('al80')),
        );
  });

  tearDown(tearDownTestDatabase);

  test('the gear link is read onto the domain tank', () async {
    final dive = await DiveRepository().getDiveById('d1');
    expect(dive!.tanks.single.equipmentId, 'al80');
  });

  test('an edit that rebuilds the tank keeps the gear link', () async {
    final repo = DiveRepository();
    final dive = await repo.getDiveById('d1');
    await repo.updateDive(
      dive!.copyWith(
        tanks: [dive.tanks.single.copyWith(startPressure: 200)],
      ),
    );
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    expect(row.equipmentId, 'al80');
    expect(row.startPressure, 200);
  });
}
```

Check the concrete class name and constructor used elsewhere in tests (`grep -rn "DiveRepository()" test | head -2`), that `DiveTank.copyWith` exists with `startPressure`, and that `Dive.copyWith(tanks: ...)` exists; adjust.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart`
Expected: FAIL, `equipmentId` is not defined on `DiveTank`.

- [ ] **Step 3: Add the field**

In `dive.dart`, after the `regulatorEquipmentId` field doc block add:

```dart
  /// The gear item this cylinder is (the `dive_tanks.equipment_id` link the
  /// transmitter registry writes when a serial is assigned to an item).
  /// Read-only on the domain side: edit flows rebuild the tank field by
  /// field and never write it, like [computerId], so a rebuild that forgot
  /// it cannot wipe what the registry recorded.
  final String? equipmentId;
```

Add `this.equipmentId,` to the constructor next to `this.regulatorEquipmentId,`, `equipmentId` to `props`, and to `copyWith` (`String? equipmentId,` and `equipmentId: equipmentId ?? this.equipmentId,`; do NOT add a clear flag, nothing on the domain side clears it).

In `dive_repository_impl.dart`, in both `domain.DiveTank(` read mappers add `equipmentId: t.equipmentId,` next to `regulatorEquipmentId: t.regulatorEquipmentId,`. Do not touch `_tankCompanion` or the update path.

- [ ] **Step 4: Run the test and the tank tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart test/features/dive_log/domain/entities`
Expected: all pass. If a `props` parity or `copyWith` exhaustiveness test exists for `DiveTank`, it now lists `equipmentId`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_tank_equipment_id_test.dart
git commit -m "feat(dive-log): expose the cylinder's gear item on the domain tank (condition phase 3a)"
```

---

### Task 5: Observation providers

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_observation_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_observation_providers_test.dart`

**Interfaces:**
- Produces: `equipmentObservationRepositoryProvider`, `observationsForEquipmentProvider = FutureProvider.family<List<EquipmentObservation>, String>`, `observationsForDiveProvider = FutureProvider.family<List<EquipmentObservation>, String>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/providers/equipment_observation_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    container = ProviderContainer(
      overrides: [equipmentObservationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('both families refresh after a write', () async {
    final byItem = container.listen(
      observationsForEquipmentProvider('reg'),
      (_, _) {},
    );
    final byDive = container.listen(observationsForDiveProvider('d1'), (_, _) {});
    addTearDown(byItem.close);
    addTearDown(byDive.close);
    expect(
      await container.read(observationsForEquipmentProvider('reg').future),
      isEmpty,
    );

    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.issue,
    );
    for (var i = 0; i < 50; i++) {
      final v = container.read(observationsForEquipmentProvider('reg')).value;
      if (v != null && v.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      await container.read(observationsForEquipmentProvider('reg').future),
      hasLength(1),
    );
    expect(
      await container.read(observationsForDiveProvider('d1').future),
      hasLength(1),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_observation_providers_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the providers**

```dart
// lib/features/equipment/presentation/providers/equipment_observation_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

final equipmentObservationRepositoryProvider =
    Provider<EquipmentObservationRepository>(
      (ref) => EquipmentObservationRepository(),
    );

/// Every check-in on one item, newest first. Self-invalidates on the
/// observations table so a sync pull or a sheet write is reflected.
final observationsForEquipmentProvider =
    FutureProvider.family<List<EquipmentObservation>, String>((
      ref,
      equipmentId,
    ) async {
      final repo = ref.watch(equipmentObservationRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getForEquipment(equipmentId);
    });

/// Every check-in on one dive, across items; the dive detail rows derive
/// their chip from it with one read per dive rather than one per row.
final observationsForDiveProvider =
    FutureProvider.family<List<EquipmentObservation>, String>((
      ref,
      diveId,
    ) async {
      final repo = ref.watch(equipmentObservationRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getForDive(diveId);
    });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/providers/equipment_observation_providers_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/presentation/providers/equipment_observation_providers.dart test/features/equipment/presentation/providers/equipment_observation_providers_test.dart
git add lib/features/equipment/presentation/providers/equipment_observation_providers.dart test/features/equipment/presentation/providers/equipment_observation_providers_test.dart
git commit -m "feat(equipment): observation providers per item and per dive (condition phase 3a)"
```

---

### Task 6: Localised strings for tags, the sheet, the chip and the card

**Files:**
- Modify: the 11 ARB files
- Create: `lib/features/equipment/presentation/utils/observation_tag_display.dart`
- Test: `test/features/equipment/presentation/utils/observation_tag_display_test.dart`

**Interfaces:**
- Produces: `extension ObservationTagDisplay on ObservationTag { String localizedName(AppLocalizations l10n); }`, `extension ObservationStatusDisplay on ObservationStatus { String localizedName(AppLocalizations l10n); }`, and the keys below.

- [ ] **Step 1: Add the English keys**

In `app_en.arb`, insert after the last `equipmentConditionSettings_` key (`equipmentConditionSettings_rebuild_failed`) so the equipment condition keys stay together:

```json
  "equipmentObservation_tag_freeFlow": "Free flow",
  "equipmentObservation_tag_hardBreathing": "Hard breathing",
  "equipmentObservation_tag_wetBreathing": "Wet breathing",
  "equipmentObservation_tag_leak": "Leak",
  "equipmentObservation_tag_hoseDamage": "Hose damage",
  "equipmentObservation_tag_inflatorStuck": "Inflator stuck",
  "equipmentObservation_tag_inflatorSlow": "Inflator slow",
  "equipmentObservation_tag_bladderLeak": "Bladder leak",
  "equipmentObservation_tag_dumpLeak": "Dump valve leak",
  "equipmentObservation_tag_leakNeck": "Neck seal leak",
  "equipmentObservation_tag_leakWrist": "Wrist seal leak",
  "equipmentObservation_tag_leakZip": "Zip leak",
  "equipmentObservation_tag_leakBoot": "Boot leak",
  "equipmentObservation_tag_leakValve": "Valve leak",
  "equipmentObservation_tag_leakSeam": "Seam leak",
  "equipmentObservation_tag_tear": "Tear",
  "equipmentObservation_tag_seamFailure": "Seam failure",
  "equipmentObservation_tag_dim": "Dim",
  "equipmentObservation_tag_died": "Died",
  "equipmentObservation_tag_flooded": "Flooded",
  "equipmentObservation_tag_switchFault": "Switch fault",
  "equipmentObservation_tag_batteryLow": "Battery low",
  "equipmentObservation_tag_screenFault": "Screen fault",
  "equipmentObservation_tag_connectionFault": "Connection fault",
  "equipmentObservation_tag_dropout": "Dropout",
  "equipmentObservation_tag_cellWarning": "Cell warning",
  "equipmentObservation_tag_loopLeak": "Loop leak",
  "equipmentObservation_tag_solenoidFault": "Solenoid fault",
  "equipmentObservation_tag_scrubberBreakthrough": "Scrubber breakthrough",
  "equipmentObservation_tag_slowResponse": "Slow response",
  "equipmentObservation_tag_erratic": "Erratic",
  "equipmentObservation_tag_lowCapacity": "Low capacity",
  "equipmentObservation_tag_propFault": "Prop fault",
  "equipmentObservation_tag_strapBroke": "Strap broke",
  "equipmentObservation_tag_other": "Other",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Issue",
  "equipmentObservation_sheet_title": "Check-in: {item}",
  "@equipmentObservation_sheet_title": {"placeholders": {"item": {"type": "String"}}},
  "equipmentObservation_sheet_empty": "No check-ins on this dive yet.",
  "equipmentObservation_sheet_emptyBench": "No check-ins yet.",
  "equipmentObservation_sheet_add": "Add check-in",
  "equipmentObservation_sheet_edit": "Edit check-in",
  "equipmentObservation_sheet_delete": "Delete check-in",
  "equipmentObservation_sheet_deleteConfirm": "Delete this check-in?",
  "equipmentObservation_sheet_noteLabel": "Note",
  "equipmentObservation_sheet_tagsLabel": "What happened",
  "equipmentObservation_sheet_dateLabel": "Observed",
  "equipmentObservation_sheet_diveLabel": "Dive",
  "equipmentObservation_sheet_noDive": "No dive (bench)",
  "equipmentObservation_sheet_pickDive": "Choose a dive",
  "equipmentObservation_sheet_save": "Save",
  "equipmentObservation_sheet_cancel": "Cancel",
  "equipmentObservation_sheet_tagRequired": "Pick at least one tag for an issue",
  "equipmentObservation_chip_ok": "Checked OK",
  "equipmentObservation_chip_issue": "Issue reported",
  "equipmentObservation_chip_none": "Check in",
  "equipmentObservation_card_title": "Check-ins",
  "equipmentObservation_card_empty": "No check-ins recorded for this item.",
  "equipmentObservation_card_add": "Add check-in",
  "equipmentObservation_card_onDive": "Dive #{number}",
  "@equipmentObservation_card_onDive": {"placeholders": {"number": {"type": "int"}}},
  "equipmentObservation_card_bench": "Bench",
```

Expand the `@` metadata to the file's multi-line style (see `safetySettings_analyzeAll_progress`).

- [ ] **Step 2: Add the ten translations**

Use the Translation Appendix at the end of this plan; insert each block after the same anchor (`equipmentConditionSettings_rebuild_failed`) in each file.

- [ ] **Step 3: Regenerate and gate**

Run: `flutter gen-l10n && flutter test test/l10n`
Expected: parity passes.

- [ ] **Step 4: Write the failing display test**

```dart
// test/features/equipment/presentation/utils/observation_tag_display_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every tag has a label and none is the raw name', () {
    for (final tag in ObservationTag.values) {
      final label = tag.localizedName(l10n);
      expect(label, isNotEmpty, reason: tag.name);
      expect(label, isNot(tag.name), reason: tag.name);
    }
    expect(ObservationTag.freeFlow.localizedName(l10n), 'Free flow');
    expect(ObservationStatus.issue.localizedName(l10n), 'Issue');
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/utils/observation_tag_display_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 6: Write the display extension**

```dart
// lib/features/equipment/presentation/utils/observation_tag_display.dart
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

extension ObservationTagDisplay on ObservationTag {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ObservationTag.freeFlow => l10n.equipmentObservation_tag_freeFlow,
    ObservationTag.hardBreathing => l10n.equipmentObservation_tag_hardBreathing,
    ObservationTag.wetBreathing => l10n.equipmentObservation_tag_wetBreathing,
    ObservationTag.leak => l10n.equipmentObservation_tag_leak,
    ObservationTag.hoseDamage => l10n.equipmentObservation_tag_hoseDamage,
    ObservationTag.inflatorStuck => l10n.equipmentObservation_tag_inflatorStuck,
    ObservationTag.inflatorSlow => l10n.equipmentObservation_tag_inflatorSlow,
    ObservationTag.bladderLeak => l10n.equipmentObservation_tag_bladderLeak,
    ObservationTag.dumpLeak => l10n.equipmentObservation_tag_dumpLeak,
    ObservationTag.leakNeck => l10n.equipmentObservation_tag_leakNeck,
    ObservationTag.leakWrist => l10n.equipmentObservation_tag_leakWrist,
    ObservationTag.leakZip => l10n.equipmentObservation_tag_leakZip,
    ObservationTag.leakBoot => l10n.equipmentObservation_tag_leakBoot,
    ObservationTag.leakValve => l10n.equipmentObservation_tag_leakValve,
    ObservationTag.leakSeam => l10n.equipmentObservation_tag_leakSeam,
    ObservationTag.tear => l10n.equipmentObservation_tag_tear,
    ObservationTag.seamFailure => l10n.equipmentObservation_tag_seamFailure,
    ObservationTag.dim => l10n.equipmentObservation_tag_dim,
    ObservationTag.died => l10n.equipmentObservation_tag_died,
    ObservationTag.flooded => l10n.equipmentObservation_tag_flooded,
    ObservationTag.switchFault => l10n.equipmentObservation_tag_switchFault,
    ObservationTag.batteryLow => l10n.equipmentObservation_tag_batteryLow,
    ObservationTag.screenFault => l10n.equipmentObservation_tag_screenFault,
    ObservationTag.connectionFault =>
      l10n.equipmentObservation_tag_connectionFault,
    ObservationTag.dropout => l10n.equipmentObservation_tag_dropout,
    ObservationTag.cellWarning => l10n.equipmentObservation_tag_cellWarning,
    ObservationTag.loopLeak => l10n.equipmentObservation_tag_loopLeak,
    ObservationTag.solenoidFault => l10n.equipmentObservation_tag_solenoidFault,
    ObservationTag.scrubberBreakthrough =>
      l10n.equipmentObservation_tag_scrubberBreakthrough,
    ObservationTag.slowResponse => l10n.equipmentObservation_tag_slowResponse,
    ObservationTag.erratic => l10n.equipmentObservation_tag_erratic,
    ObservationTag.lowCapacity => l10n.equipmentObservation_tag_lowCapacity,
    ObservationTag.propFault => l10n.equipmentObservation_tag_propFault,
    ObservationTag.strapBroke => l10n.equipmentObservation_tag_strapBroke,
    ObservationTag.other => l10n.equipmentObservation_tag_other,
  };
}

extension ObservationStatusDisplay on ObservationStatus {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ObservationStatus.ok => l10n.equipmentObservation_status_ok,
    ObservationStatus.issue => l10n.equipmentObservation_status_issue,
  };
}
```

- [ ] **Step 7: Run the test to verify it passes, then commit**

Run: `flutter test test/features/equipment/presentation/utils/observation_tag_display_test.dart test/l10n`

```bash
dart format lib/features/equipment/presentation/utils/observation_tag_display.dart test/features/equipment/presentation/utils/observation_tag_display_test.dart
git add lib/features/equipment/presentation/utils/observation_tag_display.dart test/features/equipment/presentation/utils/observation_tag_display_test.dart lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(l10n): observation tags, check-in sheet, chip and card strings (condition phase 3a)"
```

---

### Task 7: The check-in sheet

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 5, 6; `UnitFormatter.formatDateTime` (check its signature and `l10n:` parameter in `lib/core/utils/unit_formatter.dart`); `showLinkDivePicker(context) -> Future<String?>` (`lib/features/pre_dive/presentation/widgets/link_dive_picker.dart`); `currentDiverIdProvider`; `Dive` (`exitTime`, `dateTime`, `effectiveRuntime`).
- Produces:

```dart
/// Opens the check-in sheet for [equipment]. With [dive] the sheet lists and
/// adds observations on that dive; without it (the item page) each new
/// observation may pick a dive or stay a bench note.
Future<void> showEquipmentObservationSheet(
  BuildContext context, {
  required EquipmentItem equipment,
  Dive? dive,
});

/// The default observed-at for a dive: exit time, else start plus runtime,
/// else start.
DateTime defaultObservedAt(Dive dive);
```

Layout (one `showModalBottomSheet`, `isScrollControlled: true`, a `DraggableScrollableSheet` is not required): title `equipmentObservation_sheet_title(item.name)`; a list of the observations for the item (on the dive when given), each a `ListTile` with a leading check or warning icon, title = tags joined by ", " (or the status label for an OK row), subtitle = note plus formatted date, trailing edit and delete icons; an empty text when the list is empty; a `FilledButton.icon` "Add check-in" that swaps the list for the editor. The editor: `SegmentedButton<ObservationStatus>` (OK / Issue); when Issue, a `Wrap` of `FilterChip`s from `observationTagsFor(item.type)`; a `TextField` for the note; when `dive == null`, a `ListTile` showing the picked dive number or "No dive (bench)" that opens `showLinkDivePicker`; Save and Cancel. Save with status Issue and no tag shows `equipmentObservation_sheet_tagRequired` and does not write. Delete asks `equipmentObservation_sheet_deleteConfirm`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;

  final reg = EquipmentItem(
    id: 'reg',
    name: 'Apeks XTX',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );
  final dive = Dive(
    id: 'd1',
    diveNumber: 12,
    dateTime: DateTime.utc(2026, 9, 9, 10),
    exitTime: DateTime.utc(2026, 9, 9, 11),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Apeks XTX',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(WidgetTester tester, {Dive? withDive}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          equipmentObservationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEquipmentObservationSheet(
                  context,
                  equipment: reg,
                  dive: withDive,
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

  testWidgets('adds an issue with tags filtered to the item type', (
    tester,
  ) async {
    await pumpAndOpen(tester, withDive: dive);
    expect(find.text('Check-in: Apeks XTX'), findsOneWidget);
    expect(find.text('No check-ins on this dive yet.'), findsOneWidget);

    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();
    // Regulator tags are offered; a drysuit tag is not.
    expect(find.text('Free flow'), findsOneWidget);
    expect(find.text('Neck seal leak'), findsNothing);
    expect(find.text('Other'), findsOneWidget);

    // Saving without a tag is refused.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one tag for an issue'), findsOneWidget);

    await tester.tap(find.text('Free flow'));
    await tester.enterText(find.byType(TextField).last, 'At 30 m');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await repo.getForEquipmentOnDive('reg', 'd1');
    expect(stored.single.issueTags, [ObservationTag.freeFlow]);
    expect(stored.single.note, 'At 30 m');
    expect(stored.single.observedAt, DateTime.utc(2026, 9, 9, 11));
    // Back on the list, the new row shows.
    expect(find.text('Free flow'), findsOneWidget);
  });

  testWidgets('an OK check needs no tag and edits in place', (tester) async {
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForDive('d1')).single.isIssue, isFalse);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'All good');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForDive('d1')).single.note, 'All good');
  });

  testWidgets('delete asks first and then removes the row', (tester) async {
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.ok,
    );
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this check-in?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(await repo.getForDive('d1'), isEmpty);
  });

  testWidgets('without a dive the editor offers a bench default', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    expect(find.text('No dive (bench)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForEquipment('reg')).single.diveId, isNull);
  });

  test('defaultObservedAt prefers exit time, then start plus runtime', () {
    expect(defaultObservedAt(dive), DateTime.utc(2026, 9, 9, 11));
    final noExit = Dive(
      id: 'd2',
      dateTime: DateTime.utc(2026, 9, 9, 10),
      runtime: const Duration(minutes: 50),
    );
    expect(defaultObservedAt(noExit), DateTime.utc(2026, 9, 9, 10, 50));
    expect(
      defaultObservedAt(Dive(id: 'd3', dateTime: DateTime.utc(2026, 9, 9, 10))),
      DateTime.utc(2026, 9, 9, 10),
    );
  });
}
```

Check the `Dive` and `EquipmentItem` constructors' required parameters (`grep -n "const Dive({" -A20 lib/features/dive_log/domain/entities/dive.dart | grep required`) and fill in whatever is required; the delete confirm button label comes from `MaterialLocalizations` or `common_action_delete` (the incident page uses `l10n.common_action_delete`, so reuse that key).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the sheet**

```dart
// lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/link_dive_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The default observed-at for a check-in on [dive]: the exit time when the
/// log has one, else the start plus the runtime, else the start.
DateTime defaultObservedAt(Dive dive) {
  final exit = dive.exitTime;
  if (exit != null) return exit;
  final runtime = dive.effectiveRuntime;
  if (runtime != null) return dive.dateTime.add(runtime);
  return dive.dateTime;
}

/// Opens the check-in sheet for [equipment]. With [dive], the sheet lists
/// and adds observations on that dive; without it (the item page) each new
/// observation may pick a dive or stay a bench note.
Future<void> showEquipmentObservationSheet(
  BuildContext context, {
  required EquipmentItem equipment,
  Dive? dive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ObservationSheet(equipment: equipment, dive: dive),
  );
}

class _ObservationSheet extends ConsumerStatefulWidget {
  final EquipmentItem equipment;
  final Dive? dive;

  const _ObservationSheet({required this.equipment, this.dive});

  @override
  ConsumerState<_ObservationSheet> createState() => _ObservationSheetState();
}

class _ObservationSheetState extends ConsumerState<_ObservationSheet> {
  /// Null while the list shows; a draft while the editor shows.
  _Draft? _draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dive = widget.dive;
    final observationsAsync = dive == null
        ? ref.watch(observationsForEquipmentProvider(widget.equipment.id))
        : ref.watch(observationsForDiveProvider(dive.id));
    final observations = [
      for (final o in observationsAsync.value ?? const <EquipmentObservation>[])
        if (o.equipmentId == widget.equipment.id) o,
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.equipmentObservation_sheet_title(widget.equipment.name),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_draft case final draft?)
            _Editor(
              draft: draft,
              equipment: widget.equipment,
              hasDive: dive != null,
              onCancel: () => setState(() => _draft = null),
              onSave: () => _save(draft),
            )
          else ...[
            if (observations.isEmpty)
              Text(
                dive == null
                    ? l10n.equipmentObservation_sheet_emptyBench
                    : l10n.equipmentObservation_sheet_empty,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in observations)
                      _ObservationTile(
                        observation: o,
                        onEdit: () =>
                            setState(() => _draft = _Draft.fromExisting(o)),
                        onDelete: () => _delete(o),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(
                () => _draft = _Draft.fresh(
                  observedAt: dive == null
                      ? DateTime.now().toUtc()
                      : defaultObservedAt(dive),
                  diveId: dive?.id,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.equipmentObservation_sheet_add),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(_Draft draft) async {
    final l10n = context.l10n;
    if (draft.status == ObservationStatus.issue && draft.tags.isEmpty) {
      setState(() => draft.error = l10n.equipmentObservation_sheet_tagRequired);
      return;
    }
    final repo = ref.read(equipmentObservationRepositoryProvider);
    final tags = draft.status == ObservationStatus.issue
        ? draft.tags.toList()
        : const <ObservationTag>[];
    final existing = draft.existing;
    if (existing == null) {
      await repo.create(
        equipmentId: widget.equipment.id,
        diveId: draft.diveId,
        diverId: ref.read(currentDiverIdProvider),
        observedAt: draft.observedAt,
        status: draft.status,
        issueTags: tags,
        note: draft.note.text.trim(),
      );
    } else {
      await repo.update(
        existing.copyWith(
          diveId: draft.diveId,
          clearDiveId: draft.diveId == null,
          observedAt: draft.observedAt,
          status: draft.status,
          issueTags: tags,
          note: draft.note.text.trim(),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _draft = null);
  }

  Future<void> _delete(EquipmentObservation observation) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.equipmentObservation_sheet_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.equipmentObservation_sheet_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(equipmentObservationRepositoryProvider).delete(observation.id);
  }
}

class _Draft {
  final EquipmentObservation? existing;
  ObservationStatus status;
  final Set<ObservationTag> tags;
  final TextEditingController note;
  DateTime observedAt;
  String? diveId;
  String? error;

  _Draft({
    this.existing,
    required this.status,
    required this.tags,
    required this.note,
    required this.observedAt,
    this.diveId,
  });

  factory _Draft.fresh({required DateTime observedAt, String? diveId}) =>
      _Draft(
        status: ObservationStatus.ok,
        tags: {},
        note: TextEditingController(),
        observedAt: observedAt,
        diveId: diveId,
      );

  factory _Draft.fromExisting(EquipmentObservation o) => _Draft(
    existing: o,
    status: o.status,
    tags: o.issueTags.toSet(),
    note: TextEditingController(text: o.note),
    observedAt: o.observedAt,
    diveId: o.diveId,
  );
}

class _Editor extends ConsumerStatefulWidget {
  final _Draft draft;
  final EquipmentItem equipment;
  final bool hasDive;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _Editor({
    required this.draft,
    required this.equipment,
    required this.hasDive,
    required this.onCancel,
    required this.onSave,
  });

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = widget.draft;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<ObservationStatus>(
          segments: [
            for (final s in ObservationStatus.values)
              ButtonSegment(value: s, label: Text(s.localizedName(l10n))),
          ],
          selected: {draft.status},
          onSelectionChanged: (sel) => setState(() {
            draft.status = sel.first;
            draft.error = null;
          }),
        ),
        if (draft.status == ObservationStatus.issue) ...[
          const SizedBox(height: 12),
          Text(
            l10n.equipmentObservation_sheet_tagsLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in observationTagsFor(widget.equipment.type))
                FilterChip(
                  label: Text(tag.localizedName(l10n)),
                  selected: draft.tags.contains(tag),
                  onSelected: (on) => setState(() {
                    if (on) {
                      draft.tags.add(tag);
                    } else {
                      draft.tags.remove(tag);
                    }
                    draft.error = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: draft.note,
          decoration: InputDecoration(
            labelText: l10n.equipmentObservation_sheet_noteLabel,
          ),
          maxLines: 3,
        ),
        if (!widget.hasDive)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.scuba_diving),
            title: Text(l10n.equipmentObservation_sheet_diveLabel),
            subtitle: Text(
              draft.diveId == null
                  ? l10n.equipmentObservation_sheet_noDive
                  : draft.diveId!,
            ),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showLinkDivePicker(context);
                if (picked == null || !mounted) return;
                final dive = await ref.read(diveProvider(picked).future);
                setState(() {
                  draft.diveId = picked;
                  if (dive != null) draft.observedAt = defaultObservedAt(dive);
                });
              },
              child: Text(l10n.equipmentObservation_sheet_pickDive),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l10n.equipmentObservation_sheet_dateLabel),
          subtitle: Text(units.formatDateTime(draft.observedAt, l10n: l10n)),
        ),
        if (draft.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(l10n.equipmentObservation_sheet_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.onSave,
              child: Text(l10n.equipmentObservation_sheet_save),
            ),
          ],
        ),
      ],
    );
  }
}

class _ObservationTile extends ConsumerWidget {
  final EquipmentObservation observation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ObservationTile({
    required this.observation,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    final title = observation.isIssue
        ? observation.issueTags.map((t) => t.localizedName(l10n)).join(', ')
        : ObservationStatus.ok.localizedName(l10n);
    final when = units.formatDateTime(observation.observedAt, l10n: l10n);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        observation.isIssue ? Icons.warning_amber : Icons.check_circle_outline,
        color: observation.isIssue ? scheme.error : scheme.tertiary,
      ),
      title: Text(title),
      subtitle: Text(
        observation.note.isEmpty ? when : '${observation.note}\n$when',
      ),
      isThreeLine: observation.note.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.equipmentObservation_sheet_edit,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.equipmentObservation_sheet_delete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
```

The dive-picker subtitle shows the picked dive's number when the dive loads; replace `draft.diveId!` with a small `Consumer` that watches `diveProvider(draft.diveId!)` and prints `l10n.equipmentObservation_card_onDive(dive.diveNumber ?? 0)`; keep the raw id as the fallback while loading. Check `UnitFormatter.formatDateTime`'s exact signature (the memory says omitting `l10n:` ships English "at" to every locale) and `Dive.effectiveRuntime`'s type (`Duration?`).

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart`
Expected: all pass. Widget-test traps to expect: `find.text('Other')` may match twice if the status segment also says "Other" (it does not); `find.text('Delete')` matches both the tooltip and the button, hence `.last`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart
git add lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart test/features/equipment/presentation/widgets/equipment_observation_sheet_test.dart
git commit -m "feat(equipment): gear check-in sheet (condition phase 3a)"
```

---

### Task 8: Check-in chips on the dive's equipment and cylinder rows

**Files:**
- Create: `lib/features/equipment/presentation/widgets/observation_status_chip.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildEquipmentSection`, the trailing `Row` at line 4693)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (`_tankRow`)
- Test: `test/features/equipment/presentation/widgets/observation_status_chip_test.dart`
- Test: add cases to `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`

**Interfaces:**
- Produces:

```dart
/// The trailing chip on a dive's gear row: nothing recorded, checked OK,
/// or an issue. Tapping opens the check-in sheet for (item, dive).
class ObservationStatusChip extends ConsumerWidget {
  final EquipmentItem equipment;
  final Dive dive;
  const ObservationStatusChip({super.key, required this.equipment, required this.dive});
}
```

The chip reads `observationsForDiveProvider(dive.id)`, filters to `equipment.id`, and shows an `IconButton`: `Icons.check_circle` in `tertiary` when every observation is OK, `Icons.warning_amber` in `error` when any is an issue, `Icons.add_task` in `onSurfaceVariant` when none. Tooltips are the three `equipmentObservation_chip_` keys. `onPressed` calls `showEquipmentObservationSheet(context, equipment: equipment, dive: dive)`.

- [ ] **Step 1: Write the failing chip test**

```dart
// test/features/equipment/presentation/widgets/observation_status_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));

  EquipmentObservation obs(ObservationStatus status, {String item = 'reg'}) =>
      EquipmentObservation(
        id: 'o-${status.name}-$item',
        equipmentId: item,
        diveId: 'd1',
        observedAt: DateTime.utc(2026),
        status: status,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentObservation> observations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observationsForDiveProvider('d1').overrideWith(
            (ref) async => observations,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ObservationStatusChip(equipment: reg, dive: dive)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no observation shows the check-in affordance', (tester) async {
    await pump(tester, const []);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byTooltip('Check in'), findsOneWidget);
  });

  testWidgets('all OK shows a check', (tester) async {
    await pump(tester, [obs(ObservationStatus.ok)]);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('any issue shows a warning, other items do not count', (
    tester,
  ) async {
    await pump(tester, [obs(ObservationStatus.ok), obs(ObservationStatus.issue)]);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    await pump(tester, [obs(ObservationStatus.issue, item: 'fins')]);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/observation_status_chip_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the chip**

```dart
// lib/features/equipment/presentation/widgets/observation_status_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trailing chip on a dive's gear row: nothing recorded, checked OK,
/// or an issue. Tapping opens the check-in sheet for (item, dive).
class ObservationStatusChip extends ConsumerWidget {
  final EquipmentItem equipment;
  final Dive dive;

  const ObservationStatusChip({
    super.key,
    required this.equipment,
    required this.dive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final mine = [
      for (final o
          in ref.watch(observationsForDiveProvider(dive.id)).value ?? const [])
        if (o.equipmentId == equipment.id) o,
    ];
    final (icon, color, tooltip) = mine.isEmpty
        ? (Icons.add_task, scheme.onSurfaceVariant, l10n.equipmentObservation_chip_none)
        : mine.any((o) => o.isIssue)
        ? (Icons.warning_amber, scheme.error, l10n.equipmentObservation_chip_issue)
        : (Icons.check_circle, scheme.tertiary, l10n.equipmentObservation_chip_ok);
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () =>
          showEquipmentObservationSheet(context, equipment: equipment, dive: dive),
    );
  }
}
```

- [ ] **Step 4: Place it on the equipment rows**

In `dive_detail_page.dart` `_buildEquipmentSection`, inside the trailing `Row` before the type label, add:

```dart
                      ObservationStatusChip(equipment: item, dive: dive),
```

and the import `package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart`.

- [ ] **Step 5: Place it on the cylinder rows**

In `cylinders_card.dart` `_tankRow`, where the trailing widget is assembled, when `tank.equipmentId != null` wrap the existing trailing in a `Row(mainAxisSize: MainAxisSize.min)` that leads with a `Consumer` reading `equipmentItemProvider(tank.equipmentId!)` (`lib/features/equipment/presentation/providers/equipment_providers.dart`) and rendering `ObservationStatusChip(equipment: item, dive: dive)` when the item loads (`SizedBox.shrink()` otherwise). Read the current trailing construction first (the SAC block) and keep it as the second child.

- [ ] **Step 6: Add the page-level tests**

In `test/features/dive_log/presentation/pages/dive_detail_page_test.dart`, next to the existing pump helper (line 58), add two cases that pump a dive with one equipment item and one tank carrying `equipmentId: 'al80'`, override `observationsForDiveProvider(dive.id)` with `(ref) async => const []` and `equipmentItemProvider('al80')` with the tank item, expand the equipment section if it starts collapsed, and assert `find.byType(ObservationStatusChip)` finds two (one per row). Then tap the equipment row's chip and assert `find.text('Check-in: <item name>')` appears.

- [ ] **Step 7: Run the tests**

Run:

```bash
flutter test test/features/equipment/presentation/widgets/observation_status_chip_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
```

(Skip the cylinders test if the file does not exist; `ls test/features/dive_log/presentation/widgets | grep cylinder` finds it.) Expected: all pass. Existing detail-page tests that do not override `observationsForDiveProvider` still pass because the provider reads an empty in-memory table through `setUpTestDatabase`; if one pumps without a database, override the family in that test with an empty list.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/equipment/presentation/widgets/observation_status_chip.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/equipment/presentation/widgets/observation_status_chip_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart
git add lib/features/equipment/presentation/widgets/observation_status_chip.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/equipment/presentation/widgets/observation_status_chip_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart
git commit -m "feat(dive-log): check-in chips on the dive's gear and cylinder rows (condition phase 3a)"
```

---

### Task 9: Observations card on the item page

**Files:**
- Create: `lib/features/equipment/presentation/widgets/observations_card.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (after `ServiceClocksCard`, line 173)
- Modify: every test that pumps `EquipmentDetailPage` (find with `grep -rln "EquipmentDetailPage(" test`)
- Test: `test/features/equipment/presentation/widgets/observations_card_test.dart`

**Interfaces:**
- Produces: `class ObservationsCard extends ConsumerWidget { final EquipmentItem equipment; }` reading `observationsForEquipmentProvider(equipment.id)`; each row shows the status icon, tags or the OK label, the note, the date and `equipmentObservation_card_onDive(number)` (through `diveProvider(diveId)`) or `equipmentObservation_card_bench`; edit and delete icons reuse the sheet's tile behaviour; the header carries an add button that opens `showEquipmentObservationSheet(context, equipment: equipment)` (no dive, so the editor offers the dive picker).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/widgets/observations_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentObservation> observations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          observationsForEquipmentProvider('reg').overrideWith(
            (ref) async => observations,
          ),
          diveProvider('d1').overrideWith(
            (ref) async => Dive(id: 'd1', diveNumber: 42, dateTime: DateTime.utc(2026)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ObservationsCard(equipment: reg)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state names the item', (tester) async {
    await pump(tester, const []);
    expect(find.text('Check-ins'), findsOneWidget);
    expect(find.text('No check-ins recorded for this item.'), findsOneWidget);
  });

  testWidgets('rows show tags, the dive number and bench', (tester) async {
    await pump(tester, [
      EquipmentObservation(
        id: 'o1',
        equipmentId: 'reg',
        diveId: 'd1',
        observedAt: DateTime.utc(2026, 3, 1),
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.freeFlow, ObservationTag.leak],
        note: 'Cold water',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      EquipmentObservation(
        id: 'o2',
        equipmentId: 'reg',
        observedAt: DateTime.utc(2026, 2, 1),
        status: ObservationStatus.ok,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    expect(find.text('Free flow, Leak'), findsOneWidget);
    expect(find.textContaining('Dive #42'), findsOneWidget);
    expect(find.textContaining('Bench'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/observations_card_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the card**

Model it on `ComponentsCard` (`lib/features/equipment/presentation/widgets/components_card.dart`) for the `Card` shell and header row. Body: the empty text or a `Column` of `ListTile`s (leading icon, title tags or OK label, subtitle `note` then a second line of `date · Dive #n` or `date · Bench`, trailing edit and delete). Edit opens `showEquipmentObservationSheet(context, equipment: equipment)` and the sheet lists every observation of the item (the sheet already handles the no-dive mode); delete confirms and deletes through the repository. Keep the file under 250 lines; share nothing with the sheet except the display extension.

- [ ] **Step 4: Place it on the page and fix the page tests**

In `equipment_detail_page.dart` after the `ServiceClocksCard(...)` block add:

```dart
          const SizedBox(height: 24),
          ObservationsCard(equipment: equipment),
```

with the import. Then for each test file from `grep -rln "EquipmentDetailPage(" test`, add `observationsForEquipmentProvider('<id>').overrideWith((ref) async => const [])` to its overrides, next to the `equipmentComponentsProvider` override, using that test's equipment id.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/observations_card_test.dart test/features/equipment/presentation/pages`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/presentation/widgets/observations_card.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment
git add lib/features/equipment/presentation/widgets/observations_card.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/widgets/observations_card_test.dart
git add $(grep -rln "EquipmentDetailPage(" test)
git commit -m "feat(equipment): check-ins card on the item page (condition phase 3a)"
```

---

### Task 10: An incident names its item

**Files:**
- Modify: `lib/features/safety/domain/entities/incident.dart` (field, constructor, `copyWith` with `clearEquipmentId`, `props`)
- Modify: `lib/features/safety/data/repositories/incident_repository.dart` (`createIncident` gains `String? equipmentId`, `_toCompanion`, `_toDomain`, and add `Future<List<Incident>> getIncidentsForEquipment(String equipmentId)`)
- Modify: `lib/features/safety/presentation/pages/incident_edit_page.dart` (equipment picker)
- Modify: the 11 ARB files (four keys)
- Test: extend `test/features/safety/data/repositories/incident_repository_test.dart` and `test/features/safety/presentation/pages/incident_edit_page_test.dart`
- Test: extend `test/core/services/sync/equipment_condition_columns_sync_test.dart` with an `incidents.equipmentId` round trip

**Interfaces:**
- Produces: `Incident.equipmentId`; `IncidentRepository.getIncidentsForEquipment`; picker keys `incidentEdit_equipment`, `incidentEdit_equipment_none`, `incidentEdit_equipment_onThisDive`, `incidentEdit_equipment_allGear`.

Picker behaviour: a `DropdownMenu<String?>` (or a `ListTile` opening a simple selection dialog) listing "None", then, when the incident has a dive, that dive's gear under the "On this dive" header, then every active item under "All gear" (from `activeEquipmentProvider`), each labelled by name. Choosing an item while `_category` is still the untouched default sets `_category = IncidentCategory.equipment`; a `_categoryTouched` flag set by the category chips prevents overriding a deliberate choice.

- [ ] **Step 1: Write the failing tests**

Repository: create with `equipmentId: 'reg'`, read back, `getIncidentsForEquipment('reg')` returns it, update with `clearEquipmentId: true` clears it, and deleting the equipment row sets it null (FK `ON DELETE SET NULL`). Page: pump `IncidentEditPage(diveId: 'd1')` with `diveProvider('d1')` overridden to a dive carrying one gear item "Apeks XTX" and `activeEquipmentProvider` overridden to two items; assert "Apeks XTX" appears under "On this dive"; choose it; assert the Equipment category chip is selected; save and assert the repository received `equipmentId`. Sync: an `incidents` row with `equipmentId` upserts and fetches back with the key.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/safety test/core/services/sync/equipment_condition_columns_sync_test.dart`
Expected: the new cases fail (no `equipmentId`).

- [ ] **Step 3: Entity and repository**

Add `final String? equipmentId;` after `diveId` with the doc "v202: the item an equipment incident attributes to", thread it through the constructor, `copyWith({String? equipmentId, bool clearEquipmentId = false})`, `props`, `createIncident({... String? equipmentId})`, `_toCompanion` (`equipmentId: Value(incident.equipmentId)`) and `_toDomain` (`equipmentId: row.equipmentId`). Add:

```dart
  Future<List<Incident>> getIncidentsForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.incidents)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }
```

- [ ] **Step 4: ARB keys**

English, anchored after `incidentEdit_privacyNote` (check the exact neighbour with `grep -n '"incidentEdit_' lib/l10n/arb/app_en.arb`):

```json
  "incidentEdit_equipment": "Equipment involved",
  "incidentEdit_equipment_none": "None",
  "incidentEdit_equipment_onThisDive": "On this dive",
  "incidentEdit_equipment_allGear": "All gear",
```

Translations in the appendix. `flutter gen-l10n`.

- [ ] **Step 5: The picker on the form**

In `incident_edit_page.dart` add state `String? _equipmentId; bool _categoryTouched = false;`, seed `_equipmentId` from the loaded incident, set `_categoryTouched = true` in the category chip `onSelected`, and after the date `ListTile` insert a `ListTile(leading: Icon(Icons.backpack), title: Text(l10n.incidentEdit_equipment), subtitle: Text(selectedName ?? l10n.incidentEdit_equipment_none), onTap: _pickEquipment)`. `_pickEquipment` opens a `showDialog` with a `SimpleDialog` listing `None`, the dive's gear (from `ref.read(diveProvider(widget.diveId ?? _existing?.diveId ?? '').future)` when a dive id exists) under a header, then active gear under a header; on choice set `_equipmentId`, and when `!_categoryTouched` set `_category = IncidentCategory.equipment`. Pass `equipmentId: _equipmentId` to `createIncident` and `copyWith(equipmentId: _equipmentId, clearEquipmentId: _equipmentId == null)` to `updateIncident`.

- [ ] **Step 6: Run the tests, then commit**

Run: `flutter test test/features/safety test/core/services/sync/equipment_condition_columns_sync_test.dart test/l10n`

```bash
dart format lib/features/safety test/features/safety test/core/services/sync/equipment_condition_columns_sync_test.dart
git add lib/features/safety/domain/entities/incident.dart lib/features/safety/data/repositories/incident_repository.dart lib/features/safety/presentation/pages/incident_edit_page.dart test/features/safety/data/repositories/incident_repository_test.dart test/features/safety/presentation/pages/incident_edit_page_test.dart test/core/services/sync/equipment_condition_columns_sync_test.dart lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(safety): an incident can name the item involved (condition phase 3a)"
```

---

### Task 11: UDDF full export and import carry the parent link and observations

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData`: new `observations` parameter; inside each `<item>` write `<parentref>` and `<observations>`)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart` (thread `List<EquipmentObservation>? observations` through `_generateAllDataXml`, `exportAllDataToUddf` and `saveAllDataToFile`)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (load observations beside `allServiceRecords` at both call sites, lines 530 and 1141)
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (`parseEquipmentItem` reads `parentref` into `item['parentRef']` and `<observations>/<observation>` into `item['observations']`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_importEquipment` second pass for parents; `_DiveImportResult.diveIdBySourceUuid`; `_importObservations` after dives)
- Test: `test/core/services/export/uddf/uddf_observations_round_trip_test.dart`

XML shape, under `<item id="equip_X">` after `<notes>`:

```xml
<parentref>equip_P</parentref>
<observations>
  <observation id="obs_O">
    <date>2026-09-09T11:00:00.000Z</date>
    <diveref>dive_D</diveref>
    <status>issue</status>
    <tags><tag>freeFlow</tag><tag>other</tag></tags>
    <note>At 30 m</note>
  </observation>
</observations>
```

- [ ] **Step 1: Write the failing round-trip test**

Build an `EquipmentItem` parent and child (child `parentEquipmentId` = parent id), one dive, and two observations (one on the dive, one bench). Call `UddfExportBuilders.buildApplicationData` through the export service's `_generateAllDataXml` (or the public `exportAllDataToUddf` path used by `uddf_full_export_raw_data_test.dart`; copy that test's setup), parse the string with `XmlDocument.parse`, and assert the `parentref` text and the two `observation` elements with their `diveref`, `status`, `tags` and `note`. Then feed the XML to `UddfFullImportService` (copy the setup from `uddf_raw_data_round_trip_test.dart`), run the entity importer with everything selected, and assert: the child's `parentEquipmentId` equals the imported parent's new id; the observation repository holds two rows for the imported child, one with the imported dive's new id and one with null; tags and note survive.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/export/uddf/uddf_observations_round_trip_test.dart`
Expected: FAIL, no `parentref` element.

- [ ] **Step 3: Export**

In `buildApplicationData` add `List<EquipmentObservation>? observations` and include `(observations?.isNotEmpty ?? false)` in `hasData`. Inside the item loop, after the `notes` element:

```dart
                        if (item.parentEquipmentId != null) {
                          builder.element(
                            'parentref',
                            nest: 'equip_${item.parentEquipmentId}',
                          );
                        }
                        final mine = [
                          for (final o in observations ?? const <EquipmentObservation>[])
                            if (o.equipmentId == item.id) o,
                        ];
                        if (mine.isNotEmpty) {
                          builder.element(
                            'observations',
                            nest: () {
                              for (final o in mine) {
                                builder.element(
                                  'observation',
                                  attributes: {'id': 'obs_${o.id}'},
                                  nest: () {
                                    builder.element(
                                      'date',
                                      nest: o.observedAt.toIso8601String(),
                                    );
                                    if (o.diveId != null) {
                                      builder.element(
                                        'diveref',
                                        nest: 'dive_${o.diveId}',
                                      );
                                    }
                                    builder.element('status', nest: o.status.dbValue);
                                    if (o.issueTags.isNotEmpty) {
                                      builder.element(
                                        'tags',
                                        nest: () {
                                          for (final t in o.issueTags) {
                                            builder.element('tag', nest: t.dbValue);
                                          }
                                        },
                                      );
                                    }
                                    if (o.note.isNotEmpty) {
                                      builder.element('note', nest: o.note);
                                    }
                                  },
                                );
                              }
                            },
                          );
                        }
```

Thread `observations` through the three export service methods and pass it at the two `export_providers.dart` call sites, loading it with `_ref.read(equipmentObservationRepositoryProvider).getAll()` beside `allServiceRecords`.

- [ ] **Step 4: Import**

`parseEquipmentItem`: `item['parentRef'] = getElementText(itemElement, 'parentref');` and:

```dart
    final observationsElement = itemElement.findElements('observations').firstOrNull;
    if (observationsElement != null) {
      item['observations'] = [
        for (final o in observationsElement.findElements('observation'))
          {
            'observedAt': DateTime.tryParse(getElementText(o, 'date') ?? ''),
            'diveRef': getElementText(o, 'diveref'),
            'status': getElementText(o, 'status'),
            'tags': [
              for (final t in o.findElements('tags').expand((e) => e.findElements('tag')))
                t.innerText.trim(),
            ],
            'note': getElementText(o, 'note') ?? '',
          },
      ];
    }
```

Importer: in `_importEquipment`, after the loop that creates items, run a second pass over `items` where `parentRef` is set and both ids resolved in `idMapping`, calling `repository.updateEquipment(created.copyWith(parentEquipmentId: idMapping[parentRef]))` (fetch the created item by its new id first). In `_importDives`, when `diveData['sourceUuid']` is a string, record `diveIdBySourceUuid[sourceUuid] = diveId` and return it on `_DiveImportResult`. After `_importDives`, call a new `_importObservations(data.equipment, equipmentIdMapping, divesResult.diveIdBySourceUuid, repositories.equipmentObservationRepository, diverId, now)` that creates one row per parsed observation whose equipment resolved, resolving `diveRef` through the map (null when absent or unresolved), `status` through `ObservationStatus.fromDbValue`, tags through `ObservationTag.fromDbValue` dropping unknowns. Add `equipmentObservationRepository` to the importer's repositories record the same way `serviceRecordRepository` is provided (find its construction with `grep -rn "serviceRecordRepository:" lib`).

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/export/uddf test/features/dive_import`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/export/uddf lib/features/dive_import lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_observations_round_trip_test.dart
git add lib/core/services/export/uddf/uddf_export_builders.dart lib/core/services/export/uddf/uddf_full_export_service.dart lib/core/services/export/uddf/uddf_import_parsers.dart lib/core/services/export/uddf/uddf_full_import_service.dart lib/features/dive_import/data/services/uddf_entity_importer.dart lib/features/settings/presentation/providers/export_providers.dart test/core/services/export/uddf/uddf_observations_round_trip_test.dart
git add $(git status --short lib/features/dive_import | awk '{print $2}')
git commit -m "feat(export): parent links and check-ins in the UDDF full export and import (condition phase 3a)"
```

---

### Task 12: Excel sheet and CSV file

**Files:**
- Create: `lib/core/services/export/excel/observations_excel_export_service.dart`
- Modify: `lib/core/services/export/excel/excel_export_service.dart` (`observationRows` parameter beside `maintenanceRows`, sheet built when non-empty)
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (`generateObservationsCsvContent`, `exportObservationsToCsv`, `saveObservationsCsvToFile`)
- Modify: `lib/core/services/export/export_service.dart` (facade methods)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (`exportObservationsToCsv`, `saveObservationsCsvToFile`, and `observationRows` at the Excel call site)
- Modify: `lib/features/transfer/presentation/widgets/csv_export_dialog.dart` (`CsvExportType.observations`)
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart` (the arm)
- Modify: the 11 ARB files (`transfer_csvExport_typeObservations`, `transfer_csvExport_descriptionObservations`, `transfer_csvExport_optionObservationsTitle`, `settings_export_progress_observationsCsv`, `settings_export_progress_preparingObservationsCsv`, `settings_export_empty_observations`)
- Test: `test/core/services/export/excel/observations_excel_export_service_test.dart`
- Test: extend `test/core/services/export/csv/csv_export_service_test.dart`

**Interfaces:**
- Produces:

```dart
typedef ObservationExportRow = ({
  String equipmentName,
  String equipmentType,
  int? diveNumber,
  EquipmentObservation observation,
});

class ObservationsExcelExportService {
  static const observationsSheet = 'Observations';
  void buildSheet(xl.Excel excel, {required List<ObservationExportRow> rows, required DateFormatPreference dateFormat});
}

String generateObservationsCsvContent(List<ObservationExportRow> rows);
```

Columns (both formats): Equipment, Equipment Type, Date, Dive Number, Status, Tags (tag names joined by "; "), Note. Headers are English constants like the maintenance sheet.

- [ ] **Step 1: Write the failing tests**

Excel: build a workbook with two rows (one issue with two tags on dive 42, one bench OK), assert the sheet exists with the header row and the two data rows' cells. CSV: assert the header line and one data line for the same rows, and that a note containing a comma is quoted.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/export/excel/observations_excel_export_service_test.dart test/core/services/export/csv/csv_export_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Copy `maintenance_excel_export_service.dart`'s `buildSheet`, `_writeRow` and `_toCellValue` into the new service with the columns above; `generateBytes`/share/save are not needed (the sheet only rides in the whole-library workbook). Wire `observationRows` into `excel_export_service.dart` beside `maintenanceRows` with the same non-empty guard, and assemble the rows in `export_providers.dart` at the Excel call site (equipment by id from `allEquipment`, dive number from the loaded dives by id). CSV: add the three methods to `CsvExportService` mirroring the equipment trio (`generateEquipmentCsvContent`, `exportEquipmentToCsv`, `saveEquipmentCsvToFile`) with the file name `observations_export.csv`; facade and notifier methods mirror `exportEquipmentToCsv` / `saveEquipmentCsvToFile`, assembling rows the same way. Add `observations` to `CsvExportType` with `Icons.fact_check` and the three labels, and the transfer page arm.

- [ ] **Step 4: ARB keys**

English (anchor each beside its `Equipment` sibling):

```json
  "transfer_csvExport_typeObservations": "Gear check-ins",
  "transfer_csvExport_descriptionObservations": "Every OK check and reported issue, with its dive, tags and note",
  "transfer_csvExport_optionObservationsTitle": "Export gear check-ins",
  "settings_export_progress_observationsCsv": "Exporting gear check-ins...",
  "settings_export_progress_preparingObservationsCsv": "Preparing gear check-ins...",
  "settings_export_empty_observations": "No gear check-ins to export",
```

Copy the exact wording style of the equipment siblings (check them with `grep -n "Equipment" lib/l10n/arb/app_en.arb | grep -i "csv\|export_empty"`). Translations in the appendix. `flutter gen-l10n`.

- [ ] **Step 5: Run the tests and the transfer page tests**

Run: `flutter test test/core/services/export test/features/transfer test/features/settings/presentation/providers test/l10n`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/export lib/features/transfer lib/features/settings/presentation/providers/export_providers.dart test/core/services/export
git add lib/core/services/export/excel/observations_excel_export_service.dart lib/core/services/export/excel/excel_export_service.dart lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/export_service.dart lib/features/settings/presentation/providers/export_providers.dart lib/features/transfer/presentation/widgets/csv_export_dialog.dart lib/features/transfer/presentation/pages/transfer_page.dart test/core/services/export/excel/observations_excel_export_service_test.dart test/core/services/export/csv/csv_export_service_test.dart lib/l10n/arb/app_ar.arb lib/l10n/arb/app_de.arb lib/l10n/arb/app_en.arb lib/l10n/arb/app_es.arb lib/l10n/arb/app_fr.arb lib/l10n/arb/app_he.arb lib/l10n/arb/app_hu.arb lib/l10n/arb/app_it.arb lib/l10n/arb/app_nl.arb lib/l10n/arb/app_pt.arb lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations*.dart
git commit -m "feat(export): gear check-ins in the Excel workbook and as CSV (condition phase 3a)"
```

---

### Task 13: Wrap-up

- [ ] **Step 1:** `dart format .` then `flutter analyze` (expect `No issues found!`), then `flutter gen-l10n && git status --short lib/l10n` (expect no changes).
- [ ] **Step 2:** Run the full suite once (`flutter test > <scratchpad>/suite.log 2>&1; echo exit=$?`), not overlapping any other local run. Expect every test to pass.
- [ ] **Step 3:** Mutation checks: (a) remove the `parentRefs['equipmentObservations']` entry and confirm the completeness test fails, restore; (b) in the chip, swap the issue and OK branches and confirm "any issue shows a warning" fails, restore.
- [ ] **Step 4:** Push `ericgriffin/equipment-condition-phase3a-observations` and open a PR against the phase 2 branch (`--base ericgriffin/equipment-condition-phase2-sensor-summary`) titled `feat(equipment): gear check-ins, incident item link and observation exports (condition intelligence phase 3a)`. Body: what an observation is, the three entry points, sync as an aggregate root, the read-only tank gear link, exports and import, no schema change, the test files. No attribution lines.
- [ ] **Step 5:** Update the program memory with the branch, PR number and lessons.

---

## Translation Appendix

Insert after `"equipmentConditionSettings_rebuild_failed"` (Task 6 block), after the `incidentEdit_privacyNote` neighbour (Task 10 block) and beside the `Equipment` siblings (Task 12 block) in each file. `@` metadata entries are identical to English and omitted here.

### app_de.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Abblasen",
  "equipmentObservation_tag_hardBreathing": "Schwer atmend",
  "equipmentObservation_tag_wetBreathing": "Nass atmend",
  "equipmentObservation_tag_leak": "Leck",
  "equipmentObservation_tag_hoseDamage": "Schlauchschaden",
  "equipmentObservation_tag_inflatorStuck": "Inflator klemmt",
  "equipmentObservation_tag_inflatorSlow": "Inflator langsam",
  "equipmentObservation_tag_bladderLeak": "Blasenleck",
  "equipmentObservation_tag_dumpLeak": "Ablassventil undicht",
  "equipmentObservation_tag_leakNeck": "Halsmanschette undicht",
  "equipmentObservation_tag_leakWrist": "Armmanschette undicht",
  "equipmentObservation_tag_leakZip": "Reißverschluss undicht",
  "equipmentObservation_tag_leakBoot": "Füßling undicht",
  "equipmentObservation_tag_leakValve": "Ventil undicht",
  "equipmentObservation_tag_leakSeam": "Naht undicht",
  "equipmentObservation_tag_tear": "Riss",
  "equipmentObservation_tag_seamFailure": "Naht aufgegangen",
  "equipmentObservation_tag_dim": "Schwach",
  "equipmentObservation_tag_died": "Ausgefallen",
  "equipmentObservation_tag_flooded": "Geflutet",
  "equipmentObservation_tag_switchFault": "Schalterfehler",
  "equipmentObservation_tag_batteryLow": "Batterie schwach",
  "equipmentObservation_tag_screenFault": "Displayfehler",
  "equipmentObservation_tag_connectionFault": "Verbindungsfehler",
  "equipmentObservation_tag_dropout": "Aussetzer",
  "equipmentObservation_tag_cellWarning": "Zellenwarnung",
  "equipmentObservation_tag_loopLeak": "Kreislauf undicht",
  "equipmentObservation_tag_solenoidFault": "Magnetventilfehler",
  "equipmentObservation_tag_scrubberBreakthrough": "Scrubber-Durchbruch",
  "equipmentObservation_tag_slowResponse": "Träge Reaktion",
  "equipmentObservation_tag_erratic": "Sprunghaft",
  "equipmentObservation_tag_lowCapacity": "Geringe Kapazität",
  "equipmentObservation_tag_propFault": "Propellerfehler",
  "equipmentObservation_tag_strapBroke": "Band gerissen",
  "equipmentObservation_tag_other": "Sonstiges",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Problem",
  "equipmentObservation_sheet_title": "Check-in: {item}",
  "equipmentObservation_sheet_empty": "Noch keine Check-ins zu diesem Tauchgang.",
  "equipmentObservation_sheet_emptyBench": "Noch keine Check-ins.",
  "equipmentObservation_sheet_add": "Check-in hinzufügen",
  "equipmentObservation_sheet_edit": "Check-in bearbeiten",
  "equipmentObservation_sheet_delete": "Check-in löschen",
  "equipmentObservation_sheet_deleteConfirm": "Diesen Check-in löschen?",
  "equipmentObservation_sheet_noteLabel": "Notiz",
  "equipmentObservation_sheet_tagsLabel": "Was ist passiert",
  "equipmentObservation_sheet_dateLabel": "Beobachtet",
  "equipmentObservation_sheet_diveLabel": "Tauchgang",
  "equipmentObservation_sheet_noDive": "Kein Tauchgang (Werkbank)",
  "equipmentObservation_sheet_pickDive": "Tauchgang wählen",
  "equipmentObservation_sheet_save": "Speichern",
  "equipmentObservation_sheet_cancel": "Abbrechen",
  "equipmentObservation_sheet_tagRequired": "Wähle für ein Problem mindestens ein Schlagwort",
  "equipmentObservation_chip_ok": "Geprüft, OK",
  "equipmentObservation_chip_issue": "Problem gemeldet",
  "equipmentObservation_chip_none": "Einchecken",
  "equipmentObservation_card_title": "Check-ins",
  "equipmentObservation_card_empty": "Keine Check-ins zu diesem Teil erfasst.",
  "equipmentObservation_card_add": "Check-in hinzufügen",
  "equipmentObservation_card_onDive": "Tauchgang Nr. {number}",
  "equipmentObservation_card_bench": "Werkbank",
```

Task 10:

```json
  "incidentEdit_equipment": "Beteiligte Ausrüstung",
  "incidentEdit_equipment_none": "Keine",
  "incidentEdit_equipment_onThisDive": "Bei diesem Tauchgang",
  "incidentEdit_equipment_allGear": "Gesamte Ausrüstung",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Ausrüstungs-Check-ins",
  "transfer_csvExport_descriptionObservations": "Jede OK-Prüfung und jedes gemeldete Problem mit Tauchgang, Schlagwörtern und Notiz",
  "transfer_csvExport_optionObservationsTitle": "Ausrüstungs-Check-ins exportieren",
  "settings_export_progress_observationsCsv": "Ausrüstungs-Check-ins werden exportiert...",
  "settings_export_progress_preparingObservationsCsv": "Ausrüstungs-Check-ins werden vorbereitet...",
  "settings_export_empty_observations": "Keine Ausrüstungs-Check-ins zum Exportieren",
```

### app_es.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Flujo continuo",
  "equipmentObservation_tag_hardBreathing": "Respiración dura",
  "equipmentObservation_tag_wetBreathing": "Respiración húmeda",
  "equipmentObservation_tag_leak": "Fuga",
  "equipmentObservation_tag_hoseDamage": "Daño en latiguillo",
  "equipmentObservation_tag_inflatorStuck": "Inflador atascado",
  "equipmentObservation_tag_inflatorSlow": "Inflador lento",
  "equipmentObservation_tag_bladderLeak": "Fuga en la vejiga",
  "equipmentObservation_tag_dumpLeak": "Fuga en válvula de purga",
  "equipmentObservation_tag_leakNeck": "Fuga en el sello del cuello",
  "equipmentObservation_tag_leakWrist": "Fuga en el sello de muñeca",
  "equipmentObservation_tag_leakZip": "Fuga en la cremallera",
  "equipmentObservation_tag_leakBoot": "Fuga en el escarpín",
  "equipmentObservation_tag_leakValve": "Fuga en válvula",
  "equipmentObservation_tag_leakSeam": "Fuga en costura",
  "equipmentObservation_tag_tear": "Desgarro",
  "equipmentObservation_tag_seamFailure": "Costura abierta",
  "equipmentObservation_tag_dim": "Débil",
  "equipmentObservation_tag_died": "Se apagó",
  "equipmentObservation_tag_flooded": "Inundado",
  "equipmentObservation_tag_switchFault": "Fallo del interruptor",
  "equipmentObservation_tag_batteryLow": "Batería baja",
  "equipmentObservation_tag_screenFault": "Fallo de pantalla",
  "equipmentObservation_tag_connectionFault": "Fallo de conexión",
  "equipmentObservation_tag_dropout": "Pérdida de señal",
  "equipmentObservation_tag_cellWarning": "Aviso de célula",
  "equipmentObservation_tag_loopLeak": "Fuga en el circuito",
  "equipmentObservation_tag_solenoidFault": "Fallo del solenoide",
  "equipmentObservation_tag_scrubberBreakthrough": "Ruptura del absorbente",
  "equipmentObservation_tag_slowResponse": "Respuesta lenta",
  "equipmentObservation_tag_erratic": "Errático",
  "equipmentObservation_tag_lowCapacity": "Poca capacidad",
  "equipmentObservation_tag_propFault": "Fallo de hélice",
  "equipmentObservation_tag_strapBroke": "Correa rota",
  "equipmentObservation_tag_other": "Otro",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Problema",
  "equipmentObservation_sheet_title": "Revisión: {item}",
  "equipmentObservation_sheet_empty": "Aún no hay revisiones en esta inmersión.",
  "equipmentObservation_sheet_emptyBench": "Aún no hay revisiones.",
  "equipmentObservation_sheet_add": "Añadir revisión",
  "equipmentObservation_sheet_edit": "Editar revisión",
  "equipmentObservation_sheet_delete": "Eliminar revisión",
  "equipmentObservation_sheet_deleteConfirm": "¿Eliminar esta revisión?",
  "equipmentObservation_sheet_noteLabel": "Nota",
  "equipmentObservation_sheet_tagsLabel": "Qué ocurrió",
  "equipmentObservation_sheet_dateLabel": "Observado",
  "equipmentObservation_sheet_diveLabel": "Inmersión",
  "equipmentObservation_sheet_noDive": "Sin inmersión (en el taller)",
  "equipmentObservation_sheet_pickDive": "Elegir una inmersión",
  "equipmentObservation_sheet_save": "Guardar",
  "equipmentObservation_sheet_cancel": "Cancelar",
  "equipmentObservation_sheet_tagRequired": "Elige al menos una etiqueta para un problema",
  "equipmentObservation_chip_ok": "Revisado, OK",
  "equipmentObservation_chip_issue": "Problema notificado",
  "equipmentObservation_chip_none": "Revisar",
  "equipmentObservation_card_title": "Revisiones",
  "equipmentObservation_card_empty": "No hay revisiones registradas para este elemento.",
  "equipmentObservation_card_add": "Añadir revisión",
  "equipmentObservation_card_onDive": "Inmersión n.º {number}",
  "equipmentObservation_card_bench": "Taller",
```

Task 10:

```json
  "incidentEdit_equipment": "Equipo implicado",
  "incidentEdit_equipment_none": "Ninguno",
  "incidentEdit_equipment_onThisDive": "En esta inmersión",
  "incidentEdit_equipment_allGear": "Todo el equipo",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Revisiones de equipo",
  "transfer_csvExport_descriptionObservations": "Cada revisión OK y cada problema notificado, con su inmersión, etiquetas y nota",
  "transfer_csvExport_optionObservationsTitle": "CSV de revisiones de equipo",
  "settings_export_progress_observationsCsv": "Exportando revisiones de equipo a CSV...",
  "settings_export_progress_preparingObservationsCsv": "Preparando CSV de revisiones de equipo...",
  "settings_export_empty_observations": "No hay revisiones de equipo para exportar",
  "settings_export_success_observations": "Revisiones de equipo exportadas",
  "settings_export_saved_observationsCsv": "CSV de revisiones de equipo guardado",
```

### app_fr.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Débit continu",
  "equipmentObservation_tag_hardBreathing": "Respiration dure",
  "equipmentObservation_tag_wetBreathing": "Respiration humide",
  "equipmentObservation_tag_leak": "Fuite",
  "equipmentObservation_tag_hoseDamage": "Flexible endommagé",
  "equipmentObservation_tag_inflatorStuck": "Inflateur bloqué",
  "equipmentObservation_tag_inflatorSlow": "Inflateur lent",
  "equipmentObservation_tag_bladderLeak": "Fuite de la vessie",
  "equipmentObservation_tag_dumpLeak": "Fuite de purge",
  "equipmentObservation_tag_leakNeck": "Fuite au joint de cou",
  "equipmentObservation_tag_leakWrist": "Fuite au joint de poignet",
  "equipmentObservation_tag_leakZip": "Fuite à la fermeture",
  "equipmentObservation_tag_leakBoot": "Fuite au chausson",
  "equipmentObservation_tag_leakValve": "Fuite de valve",
  "equipmentObservation_tag_leakSeam": "Fuite de couture",
  "equipmentObservation_tag_tear": "Déchirure",
  "equipmentObservation_tag_seamFailure": "Couture ouverte",
  "equipmentObservation_tag_dim": "Faible",
  "equipmentObservation_tag_died": "En panne",
  "equipmentObservation_tag_flooded": "Inondé",
  "equipmentObservation_tag_switchFault": "Défaut d'interrupteur",
  "equipmentObservation_tag_batteryLow": "Batterie faible",
  "equipmentObservation_tag_screenFault": "Défaut d'écran",
  "equipmentObservation_tag_connectionFault": "Défaut de connexion",
  "equipmentObservation_tag_dropout": "Perte de signal",
  "equipmentObservation_tag_cellWarning": "Alerte cellule",
  "equipmentObservation_tag_loopLeak": "Fuite de boucle",
  "equipmentObservation_tag_solenoidFault": "Défaut de solénoïde",
  "equipmentObservation_tag_scrubberBreakthrough": "Percée de la chaux",
  "equipmentObservation_tag_slowResponse": "Réponse lente",
  "equipmentObservation_tag_erratic": "Erratique",
  "equipmentObservation_tag_lowCapacity": "Faible capacité",
  "equipmentObservation_tag_propFault": "Défaut d'hélice",
  "equipmentObservation_tag_strapBroke": "Sangle cassée",
  "equipmentObservation_tag_other": "Autre",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Problème",
  "equipmentObservation_sheet_title": "Bilan : {item}",
  "equipmentObservation_sheet_empty": "Aucun bilan sur cette plongée pour l'instant.",
  "equipmentObservation_sheet_emptyBench": "Aucun bilan pour l'instant.",
  "equipmentObservation_sheet_add": "Ajouter un bilan",
  "equipmentObservation_sheet_edit": "Modifier le bilan",
  "equipmentObservation_sheet_delete": "Supprimer le bilan",
  "equipmentObservation_sheet_deleteConfirm": "Supprimer ce bilan ?",
  "equipmentObservation_sheet_noteLabel": "Note",
  "equipmentObservation_sheet_tagsLabel": "Ce qui s'est passé",
  "equipmentObservation_sheet_dateLabel": "Observé",
  "equipmentObservation_sheet_diveLabel": "Plongée",
  "equipmentObservation_sheet_noDive": "Sans plongée (atelier)",
  "equipmentObservation_sheet_pickDive": "Choisir une plongée",
  "equipmentObservation_sheet_save": "Enregistrer",
  "equipmentObservation_sheet_cancel": "Annuler",
  "equipmentObservation_sheet_tagRequired": "Choisissez au moins une étiquette pour un problème",
  "equipmentObservation_chip_ok": "Vérifié, OK",
  "equipmentObservation_chip_issue": "Problème signalé",
  "equipmentObservation_chip_none": "Faire un bilan",
  "equipmentObservation_card_title": "Bilans",
  "equipmentObservation_card_empty": "Aucun bilan enregistré pour cet élément.",
  "equipmentObservation_card_add": "Ajouter un bilan",
  "equipmentObservation_card_onDive": "Plongée n° {number}",
  "equipmentObservation_card_bench": "Atelier",
```

Task 10:

```json
  "incidentEdit_equipment": "Équipement impliqué",
  "incidentEdit_equipment_none": "Aucun",
  "incidentEdit_equipment_onThisDive": "Sur cette plongée",
  "incidentEdit_equipment_allGear": "Tout l'équipement",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Bilans d'équipement",
  "transfer_csvExport_descriptionObservations": "Chaque vérification OK et chaque problème signalé, avec la plongée, les étiquettes et la note",
  "transfer_csvExport_optionObservationsTitle": "CSV des bilans d'équipement",
  "settings_export_progress_observationsCsv": "Export des bilans d'équipement en CSV...",
  "settings_export_progress_preparingObservationsCsv": "Préparation du CSV des bilans d'équipement...",
  "settings_export_empty_observations": "Aucun bilan d'équipement à exporter",
  "settings_export_success_observations": "Bilans d'équipement exportés",
  "settings_export_saved_observationsCsv": "CSV des bilans d'équipement enregistré",
```

### app_it.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Erogazione continua",
  "equipmentObservation_tag_hardBreathing": "Respirazione dura",
  "equipmentObservation_tag_wetBreathing": "Respirazione umida",
  "equipmentObservation_tag_leak": "Perdita",
  "equipmentObservation_tag_hoseDamage": "Frusta danneggiata",
  "equipmentObservation_tag_inflatorStuck": "Inflator bloccato",
  "equipmentObservation_tag_inflatorSlow": "Inflator lento",
  "equipmentObservation_tag_bladderLeak": "Perdita del sacco",
  "equipmentObservation_tag_dumpLeak": "Perdita dello scarico",
  "equipmentObservation_tag_leakNeck": "Perdita al collo",
  "equipmentObservation_tag_leakWrist": "Perdita al polso",
  "equipmentObservation_tag_leakZip": "Perdita alla cerniera",
  "equipmentObservation_tag_leakBoot": "Perdita al calzare",
  "equipmentObservation_tag_leakValve": "Perdita della valvola",
  "equipmentObservation_tag_leakSeam": "Perdita della cucitura",
  "equipmentObservation_tag_tear": "Strappo",
  "equipmentObservation_tag_seamFailure": "Cucitura aperta",
  "equipmentObservation_tag_dim": "Fioco",
  "equipmentObservation_tag_died": "Spento",
  "equipmentObservation_tag_flooded": "Allagato",
  "equipmentObservation_tag_switchFault": "Guasto interruttore",
  "equipmentObservation_tag_batteryLow": "Batteria scarica",
  "equipmentObservation_tag_screenFault": "Guasto schermo",
  "equipmentObservation_tag_connectionFault": "Guasto connessione",
  "equipmentObservation_tag_dropout": "Perdita di segnale",
  "equipmentObservation_tag_cellWarning": "Avviso cella",
  "equipmentObservation_tag_loopLeak": "Perdita del loop",
  "equipmentObservation_tag_solenoidFault": "Guasto solenoide",
  "equipmentObservation_tag_scrubberBreakthrough": "Esaurimento del filtro",
  "equipmentObservation_tag_slowResponse": "Risposta lenta",
  "equipmentObservation_tag_erratic": "Erratico",
  "equipmentObservation_tag_lowCapacity": "Capacità ridotta",
  "equipmentObservation_tag_propFault": "Guasto elica",
  "equipmentObservation_tag_strapBroke": "Cinghia rotta",
  "equipmentObservation_tag_other": "Altro",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Problema",
  "equipmentObservation_sheet_title": "Controllo: {item}",
  "equipmentObservation_sheet_empty": "Nessun controllo in questa immersione.",
  "equipmentObservation_sheet_emptyBench": "Nessun controllo.",
  "equipmentObservation_sheet_add": "Aggiungi controllo",
  "equipmentObservation_sheet_edit": "Modifica controllo",
  "equipmentObservation_sheet_delete": "Elimina controllo",
  "equipmentObservation_sheet_deleteConfirm": "Eliminare questo controllo?",
  "equipmentObservation_sheet_noteLabel": "Nota",
  "equipmentObservation_sheet_tagsLabel": "Cosa è successo",
  "equipmentObservation_sheet_dateLabel": "Osservato",
  "equipmentObservation_sheet_diveLabel": "Immersione",
  "equipmentObservation_sheet_noDive": "Nessuna immersione (banco)",
  "equipmentObservation_sheet_pickDive": "Scegli un'immersione",
  "equipmentObservation_sheet_save": "Salva",
  "equipmentObservation_sheet_cancel": "Annulla",
  "equipmentObservation_sheet_tagRequired": "Scegli almeno un'etichetta per un problema",
  "equipmentObservation_chip_ok": "Controllato, OK",
  "equipmentObservation_chip_issue": "Problema segnalato",
  "equipmentObservation_chip_none": "Controlla",
  "equipmentObservation_card_title": "Controlli",
  "equipmentObservation_card_empty": "Nessun controllo registrato per questo elemento.",
  "equipmentObservation_card_add": "Aggiungi controllo",
  "equipmentObservation_card_onDive": "Immersione n. {number}",
  "equipmentObservation_card_bench": "Banco",
```

Task 10:

```json
  "incidentEdit_equipment": "Attrezzatura coinvolta",
  "incidentEdit_equipment_none": "Nessuna",
  "incidentEdit_equipment_onThisDive": "In questa immersione",
  "incidentEdit_equipment_allGear": "Tutta l'attrezzatura",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Controlli attrezzatura",
  "transfer_csvExport_descriptionObservations": "Ogni controllo OK e ogni problema segnalato, con immersione, etichette e nota",
  "transfer_csvExport_optionObservationsTitle": "CSV dei controlli attrezzatura",
  "settings_export_progress_observationsCsv": "Esportazione dei controlli attrezzatura in CSV...",
  "settings_export_progress_preparingObservationsCsv": "Preparazione del CSV dei controlli attrezzatura...",
  "settings_export_empty_observations": "Nessun controllo attrezzatura da esportare",
  "settings_export_success_observations": "Controlli attrezzatura esportati",
  "settings_export_saved_observationsCsv": "CSV dei controlli attrezzatura salvato",
```

### app_nl.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Vrije flow",
  "equipmentObservation_tag_hardBreathing": "Zwaar ademen",
  "equipmentObservation_tag_wetBreathing": "Nat ademen",
  "equipmentObservation_tag_leak": "Lek",
  "equipmentObservation_tag_hoseDamage": "Slangschade",
  "equipmentObservation_tag_inflatorStuck": "Inflator zit vast",
  "equipmentObservation_tag_inflatorSlow": "Inflator traag",
  "equipmentObservation_tag_bladderLeak": "Blaaslek",
  "equipmentObservation_tag_dumpLeak": "Dumpventiel lekt",
  "equipmentObservation_tag_leakNeck": "Nekseal lekt",
  "equipmentObservation_tag_leakWrist": "Polsseal lekt",
  "equipmentObservation_tag_leakZip": "Rits lekt",
  "equipmentObservation_tag_leakBoot": "Laars lekt",
  "equipmentObservation_tag_leakValve": "Ventiel lekt",
  "equipmentObservation_tag_leakSeam": "Naad lekt",
  "equipmentObservation_tag_tear": "Scheur",
  "equipmentObservation_tag_seamFailure": "Naad losgelaten",
  "equipmentObservation_tag_dim": "Zwak",
  "equipmentObservation_tag_died": "Uitgevallen",
  "equipmentObservation_tag_flooded": "Ondergelopen",
  "equipmentObservation_tag_switchFault": "Schakelaarstoring",
  "equipmentObservation_tag_batteryLow": "Batterij bijna leeg",
  "equipmentObservation_tag_screenFault": "Schermstoring",
  "equipmentObservation_tag_connectionFault": "Verbindingsstoring",
  "equipmentObservation_tag_dropout": "Signaaluitval",
  "equipmentObservation_tag_cellWarning": "Celwaarschuwing",
  "equipmentObservation_tag_loopLeak": "Loop lekt",
  "equipmentObservation_tag_solenoidFault": "Solenoïdestoring",
  "equipmentObservation_tag_scrubberBreakthrough": "Scrubber doorgeslagen",
  "equipmentObservation_tag_slowResponse": "Trage reactie",
  "equipmentObservation_tag_erratic": "Grillig",
  "equipmentObservation_tag_lowCapacity": "Lage capaciteit",
  "equipmentObservation_tag_propFault": "Schroefstoring",
  "equipmentObservation_tag_strapBroke": "Band gebroken",
  "equipmentObservation_tag_other": "Overig",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Probleem",
  "equipmentObservation_sheet_title": "Check-in: {item}",
  "equipmentObservation_sheet_empty": "Nog geen check-ins bij deze duik.",
  "equipmentObservation_sheet_emptyBench": "Nog geen check-ins.",
  "equipmentObservation_sheet_add": "Check-in toevoegen",
  "equipmentObservation_sheet_edit": "Check-in bewerken",
  "equipmentObservation_sheet_delete": "Check-in verwijderen",
  "equipmentObservation_sheet_deleteConfirm": "Deze check-in verwijderen?",
  "equipmentObservation_sheet_noteLabel": "Notitie",
  "equipmentObservation_sheet_tagsLabel": "Wat er gebeurde",
  "equipmentObservation_sheet_dateLabel": "Waargenomen",
  "equipmentObservation_sheet_diveLabel": "Duik",
  "equipmentObservation_sheet_noDive": "Geen duik (werkbank)",
  "equipmentObservation_sheet_pickDive": "Kies een duik",
  "equipmentObservation_sheet_save": "Opslaan",
  "equipmentObservation_sheet_cancel": "Annuleren",
  "equipmentObservation_sheet_tagRequired": "Kies minstens één label voor een probleem",
  "equipmentObservation_chip_ok": "Gecontroleerd, OK",
  "equipmentObservation_chip_issue": "Probleem gemeld",
  "equipmentObservation_chip_none": "Inchecken",
  "equipmentObservation_card_title": "Check-ins",
  "equipmentObservation_card_empty": "Geen check-ins vastgelegd voor dit item.",
  "equipmentObservation_card_add": "Check-in toevoegen",
  "equipmentObservation_card_onDive": "Duik nr. {number}",
  "equipmentObservation_card_bench": "Werkbank",
```

Task 10:

```json
  "incidentEdit_equipment": "Betrokken uitrusting",
  "incidentEdit_equipment_none": "Geen",
  "incidentEdit_equipment_onThisDive": "Bij deze duik",
  "incidentEdit_equipment_allGear": "Alle uitrusting",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Uitrusting-check-ins",
  "transfer_csvExport_descriptionObservations": "Elke OK-controle en elk gemeld probleem, met duik, labels en notitie",
  "transfer_csvExport_optionObservationsTitle": "CSV van uitrusting-check-ins",
  "settings_export_progress_observationsCsv": "Uitrusting-check-ins exporteren naar CSV...",
  "settings_export_progress_preparingObservationsCsv": "CSV van uitrusting-check-ins voorbereiden...",
  "settings_export_empty_observations": "Geen uitrusting-check-ins om te exporteren",
  "settings_export_success_observations": "Uitrusting-check-ins geëxporteerd",
  "settings_export_saved_observationsCsv": "CSV van uitrusting-check-ins opgeslagen",
```

### app_pt.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Fluxo contínuo",
  "equipmentObservation_tag_hardBreathing": "Respiração dura",
  "equipmentObservation_tag_wetBreathing": "Respiração húmida",
  "equipmentObservation_tag_leak": "Fuga",
  "equipmentObservation_tag_hoseDamage": "Mangueira danificada",
  "equipmentObservation_tag_inflatorStuck": "Inflador preso",
  "equipmentObservation_tag_inflatorSlow": "Inflador lento",
  "equipmentObservation_tag_bladderLeak": "Fuga na bexiga",
  "equipmentObservation_tag_dumpLeak": "Fuga na válvula de purga",
  "equipmentObservation_tag_leakNeck": "Fuga no vedante do pescoço",
  "equipmentObservation_tag_leakWrist": "Fuga no vedante do pulso",
  "equipmentObservation_tag_leakZip": "Fuga no fecho",
  "equipmentObservation_tag_leakBoot": "Fuga na bota",
  "equipmentObservation_tag_leakValve": "Fuga na válvula",
  "equipmentObservation_tag_leakSeam": "Fuga na costura",
  "equipmentObservation_tag_tear": "Rasgo",
  "equipmentObservation_tag_seamFailure": "Costura aberta",
  "equipmentObservation_tag_dim": "Fraco",
  "equipmentObservation_tag_died": "Avariou",
  "equipmentObservation_tag_flooded": "Inundado",
  "equipmentObservation_tag_switchFault": "Falha do interruptor",
  "equipmentObservation_tag_batteryLow": "Bateria fraca",
  "equipmentObservation_tag_screenFault": "Falha do ecrã",
  "equipmentObservation_tag_connectionFault": "Falha de ligação",
  "equipmentObservation_tag_dropout": "Perda de sinal",
  "equipmentObservation_tag_cellWarning": "Aviso de célula",
  "equipmentObservation_tag_loopLeak": "Fuga no circuito",
  "equipmentObservation_tag_solenoidFault": "Falha do solenoide",
  "equipmentObservation_tag_scrubberBreakthrough": "Rutura do absorvente",
  "equipmentObservation_tag_slowResponse": "Resposta lenta",
  "equipmentObservation_tag_erratic": "Errático",
  "equipmentObservation_tag_lowCapacity": "Pouca capacidade",
  "equipmentObservation_tag_propFault": "Falha da hélice",
  "equipmentObservation_tag_strapBroke": "Fita partida",
  "equipmentObservation_tag_other": "Outro",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Problema",
  "equipmentObservation_sheet_title": "Verificação: {item}",
  "equipmentObservation_sheet_empty": "Ainda sem verificações neste mergulho.",
  "equipmentObservation_sheet_emptyBench": "Ainda sem verificações.",
  "equipmentObservation_sheet_add": "Adicionar verificação",
  "equipmentObservation_sheet_edit": "Editar verificação",
  "equipmentObservation_sheet_delete": "Eliminar verificação",
  "equipmentObservation_sheet_deleteConfirm": "Eliminar esta verificação?",
  "equipmentObservation_sheet_noteLabel": "Nota",
  "equipmentObservation_sheet_tagsLabel": "O que aconteceu",
  "equipmentObservation_sheet_dateLabel": "Observado",
  "equipmentObservation_sheet_diveLabel": "Mergulho",
  "equipmentObservation_sheet_noDive": "Sem mergulho (bancada)",
  "equipmentObservation_sheet_pickDive": "Escolher um mergulho",
  "equipmentObservation_sheet_save": "Guardar",
  "equipmentObservation_sheet_cancel": "Cancelar",
  "equipmentObservation_sheet_tagRequired": "Escolha pelo menos uma etiqueta para um problema",
  "equipmentObservation_chip_ok": "Verificado, OK",
  "equipmentObservation_chip_issue": "Problema reportado",
  "equipmentObservation_chip_none": "Verificar",
  "equipmentObservation_card_title": "Verificações",
  "equipmentObservation_card_empty": "Sem verificações registadas para este item.",
  "equipmentObservation_card_add": "Adicionar verificação",
  "equipmentObservation_card_onDive": "Mergulho n.º {number}",
  "equipmentObservation_card_bench": "Bancada",
```

Task 10:

```json
  "incidentEdit_equipment": "Equipamento envolvido",
  "incidentEdit_equipment_none": "Nenhum",
  "incidentEdit_equipment_onThisDive": "Neste mergulho",
  "incidentEdit_equipment_allGear": "Todo o equipamento",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Verificações de equipamento",
  "transfer_csvExport_descriptionObservations": "Cada verificação OK e cada problema reportado, com mergulho, etiquetas e nota",
  "transfer_csvExport_optionObservationsTitle": "CSV de verificações de equipamento",
  "settings_export_progress_observationsCsv": "A exportar verificações de equipamento para CSV...",
  "settings_export_progress_preparingObservationsCsv": "A preparar CSV de verificações de equipamento...",
  "settings_export_empty_observations": "Sem verificações de equipamento para exportar",
  "settings_export_success_observations": "Verificações de equipamento exportadas",
  "settings_export_saved_observationsCsv": "CSV de verificações de equipamento guardado",
```

### app_hu.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "Szabadáramlás",
  "equipmentObservation_tag_hardBreathing": "Nehéz légzés",
  "equipmentObservation_tag_wetBreathing": "Nedves légzés",
  "equipmentObservation_tag_leak": "Szivárgás",
  "equipmentObservation_tag_hoseDamage": "Tömlősérülés",
  "equipmentObservation_tag_inflatorStuck": "Inflátor beragadt",
  "equipmentObservation_tag_inflatorSlow": "Inflátor lassú",
  "equipmentObservation_tag_bladderLeak": "Hólyag szivárog",
  "equipmentObservation_tag_dumpLeak": "Leeresztő szelep szivárog",
  "equipmentObservation_tag_leakNeck": "Nyakmandzsetta szivárog",
  "equipmentObservation_tag_leakWrist": "Csuklómandzsetta szivárog",
  "equipmentObservation_tag_leakZip": "Cipzár szivárog",
  "equipmentObservation_tag_leakBoot": "Csizma szivárog",
  "equipmentObservation_tag_leakValve": "Szelep szivárog",
  "equipmentObservation_tag_leakSeam": "Varrás szivárog",
  "equipmentObservation_tag_tear": "Szakadás",
  "equipmentObservation_tag_seamFailure": "Varrás szétnyílt",
  "equipmentObservation_tag_dim": "Halvány",
  "equipmentObservation_tag_died": "Leállt",
  "equipmentObservation_tag_flooded": "Beázott",
  "equipmentObservation_tag_switchFault": "Kapcsolóhiba",
  "equipmentObservation_tag_batteryLow": "Alacsony akkumulátor",
  "equipmentObservation_tag_screenFault": "Kijelzőhiba",
  "equipmentObservation_tag_connectionFault": "Kapcsolati hiba",
  "equipmentObservation_tag_dropout": "Jelkimaradás",
  "equipmentObservation_tag_cellWarning": "Cellafigyelmeztetés",
  "equipmentObservation_tag_loopLeak": "Kör szivárog",
  "equipmentObservation_tag_solenoidFault": "Mágnesszelep-hiba",
  "equipmentObservation_tag_scrubberBreakthrough": "Szűrő áttörés",
  "equipmentObservation_tag_slowResponse": "Lassú válasz",
  "equipmentObservation_tag_erratic": "Ingadozó",
  "equipmentObservation_tag_lowCapacity": "Alacsony kapacitás",
  "equipmentObservation_tag_propFault": "Propellerhiba",
  "equipmentObservation_tag_strapBroke": "Pánt elszakadt",
  "equipmentObservation_tag_other": "Egyéb",
  "equipmentObservation_status_ok": "OK",
  "equipmentObservation_status_issue": "Probléma",
  "equipmentObservation_sheet_title": "Ellenőrzés: {item}",
  "equipmentObservation_sheet_empty": "Ehhez a merüléshez még nincs ellenőrzés.",
  "equipmentObservation_sheet_emptyBench": "Még nincs ellenőrzés.",
  "equipmentObservation_sheet_add": "Ellenőrzés hozzáadása",
  "equipmentObservation_sheet_edit": "Ellenőrzés szerkesztése",
  "equipmentObservation_sheet_delete": "Ellenőrzés törlése",
  "equipmentObservation_sheet_deleteConfirm": "Törli ezt az ellenőrzést?",
  "equipmentObservation_sheet_noteLabel": "Megjegyzés",
  "equipmentObservation_sheet_tagsLabel": "Mi történt",
  "equipmentObservation_sheet_dateLabel": "Megfigyelve",
  "equipmentObservation_sheet_diveLabel": "Merülés",
  "equipmentObservation_sheet_noDive": "Nincs merülés (műhely)",
  "equipmentObservation_sheet_pickDive": "Merülés választása",
  "equipmentObservation_sheet_save": "Mentés",
  "equipmentObservation_sheet_cancel": "Mégse",
  "equipmentObservation_sheet_tagRequired": "Problémához válasszon legalább egy címkét",
  "equipmentObservation_chip_ok": "Ellenőrizve, OK",
  "equipmentObservation_chip_issue": "Probléma jelentve",
  "equipmentObservation_chip_none": "Ellenőrzés",
  "equipmentObservation_card_title": "Ellenőrzések",
  "equipmentObservation_card_empty": "Ehhez az eszközhöz nincs rögzített ellenőrzés.",
  "equipmentObservation_card_add": "Ellenőrzés hozzáadása",
  "equipmentObservation_card_onDive": "{number}. merülés",
  "equipmentObservation_card_bench": "Műhely",
```

Task 10:

```json
  "incidentEdit_equipment": "Érintett felszerelés",
  "incidentEdit_equipment_none": "Nincs",
  "incidentEdit_equipment_onThisDive": "Ezen a merülésen",
  "incidentEdit_equipment_allGear": "Minden felszerelés",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "Felszerelés-ellenőrzések",
  "transfer_csvExport_descriptionObservations": "Minden OK ellenőrzés és jelentett probléma a merüléssel, címkékkel és megjegyzéssel",
  "transfer_csvExport_optionObservationsTitle": "Felszerelés-ellenőrzések CSV",
  "settings_export_progress_observationsCsv": "Felszerelés-ellenőrzések exportálása CSV-be...",
  "settings_export_progress_preparingObservationsCsv": "Felszerelés-ellenőrzések CSV előkészítése...",
  "settings_export_empty_observations": "Nincs exportálható felszerelés-ellenőrzés",
  "settings_export_success_observations": "Felszerelés-ellenőrzések exportálva",
  "settings_export_saved_observationsCsv": "Felszerelés-ellenőrzések CSV mentve",
```

### app_ar.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "تدفق حر",
  "equipmentObservation_tag_hardBreathing": "تنفس صعب",
  "equipmentObservation_tag_wetBreathing": "تنفس رطب",
  "equipmentObservation_tag_leak": "تسرب",
  "equipmentObservation_tag_hoseDamage": "تلف الخرطوم",
  "equipmentObservation_tag_inflatorStuck": "نافخ عالق",
  "equipmentObservation_tag_inflatorSlow": "نافخ بطيء",
  "equipmentObservation_tag_bladderLeak": "تسرب الكيس",
  "equipmentObservation_tag_dumpLeak": "تسرب صمام التفريغ",
  "equipmentObservation_tag_leakNeck": "تسرب عازل الرقبة",
  "equipmentObservation_tag_leakWrist": "تسرب عازل المعصم",
  "equipmentObservation_tag_leakZip": "تسرب السحّاب",
  "equipmentObservation_tag_leakBoot": "تسرب الحذاء",
  "equipmentObservation_tag_leakValve": "تسرب الصمام",
  "equipmentObservation_tag_leakSeam": "تسرب الدرزة",
  "equipmentObservation_tag_tear": "تمزق",
  "equipmentObservation_tag_seamFailure": "انفتاق الدرزة",
  "equipmentObservation_tag_dim": "خافت",
  "equipmentObservation_tag_died": "تعطل",
  "equipmentObservation_tag_flooded": "غمرته المياه",
  "equipmentObservation_tag_switchFault": "عطل المفتاح",
  "equipmentObservation_tag_batteryLow": "بطارية منخفضة",
  "equipmentObservation_tag_screenFault": "عطل الشاشة",
  "equipmentObservation_tag_connectionFault": "عطل الاتصال",
  "equipmentObservation_tag_dropout": "انقطاع",
  "equipmentObservation_tag_cellWarning": "تحذير الخلية",
  "equipmentObservation_tag_loopLeak": "تسرب الحلقة",
  "equipmentObservation_tag_solenoidFault": "عطل الملف اللولبي",
  "equipmentObservation_tag_scrubberBreakthrough": "اختراق المنظّف",
  "equipmentObservation_tag_slowResponse": "استجابة بطيئة",
  "equipmentObservation_tag_erratic": "غير منتظم",
  "equipmentObservation_tag_lowCapacity": "سعة منخفضة",
  "equipmentObservation_tag_propFault": "عطل المروحة",
  "equipmentObservation_tag_strapBroke": "انقطع الحزام",
  "equipmentObservation_tag_other": "أخرى",
  "equipmentObservation_status_ok": "سليم",
  "equipmentObservation_status_issue": "مشكلة",
  "equipmentObservation_sheet_title": "فحص: {item}",
  "equipmentObservation_sheet_empty": "لا فحوصات لهذه الغطسة بعد.",
  "equipmentObservation_sheet_emptyBench": "لا فحوصات بعد.",
  "equipmentObservation_sheet_add": "إضافة فحص",
  "equipmentObservation_sheet_edit": "تعديل الفحص",
  "equipmentObservation_sheet_delete": "حذف الفحص",
  "equipmentObservation_sheet_deleteConfirm": "هل تريد حذف هذا الفحص؟",
  "equipmentObservation_sheet_noteLabel": "ملاحظة",
  "equipmentObservation_sheet_tagsLabel": "ماذا حدث",
  "equipmentObservation_sheet_dateLabel": "لوحظ في",
  "equipmentObservation_sheet_diveLabel": "الغطسة",
  "equipmentObservation_sheet_noDive": "بدون غطسة (على الطاولة)",
  "equipmentObservation_sheet_pickDive": "اختر غطسة",
  "equipmentObservation_sheet_save": "حفظ",
  "equipmentObservation_sheet_cancel": "إلغاء",
  "equipmentObservation_sheet_tagRequired": "اختر وسمًا واحدًا على الأقل للمشكلة",
  "equipmentObservation_chip_ok": "تم الفحص، سليم",
  "equipmentObservation_chip_issue": "تم الإبلاغ عن مشكلة",
  "equipmentObservation_chip_none": "فحص",
  "equipmentObservation_card_title": "الفحوصات",
  "equipmentObservation_card_empty": "لا فحوصات مسجلة لهذه القطعة.",
  "equipmentObservation_card_add": "إضافة فحص",
  "equipmentObservation_card_onDive": "الغطسة رقم {number}",
  "equipmentObservation_card_bench": "على الطاولة",
```

Task 10:

```json
  "incidentEdit_equipment": "المعدات المعنية",
  "incidentEdit_equipment_none": "لا شيء",
  "incidentEdit_equipment_onThisDive": "في هذه الغطسة",
  "incidentEdit_equipment_allGear": "كل المعدات",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "فحوصات المعدات",
  "transfer_csvExport_descriptionObservations": "كل فحص سليم وكل مشكلة مُبلَّغ عنها مع الغطسة والوسوم والملاحظة",
  "transfer_csvExport_optionObservationsTitle": "ملف CSV لفحوصات المعدات",
  "settings_export_progress_observationsCsv": "جارٍ تصدير فحوصات المعدات إلى CSV...",
  "settings_export_progress_preparingObservationsCsv": "جارٍ تحضير ملف CSV لفحوصات المعدات...",
  "settings_export_empty_observations": "لا فحوصات معدات للتصدير",
  "settings_export_success_observations": "تم تصدير فحوصات المعدات",
  "settings_export_saved_observationsCsv": "تم حفظ ملف CSV لفحوصات المعدات",
```

### app_he.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "זרימה חופשית",
  "equipmentObservation_tag_hardBreathing": "נשימה קשה",
  "equipmentObservation_tag_wetBreathing": "נשימה רטובה",
  "equipmentObservation_tag_leak": "דליפה",
  "equipmentObservation_tag_hoseDamage": "נזק לצינור",
  "equipmentObservation_tag_inflatorStuck": "מנפח תקוע",
  "equipmentObservation_tag_inflatorSlow": "מנפח איטי",
  "equipmentObservation_tag_bladderLeak": "דליפה בשלפוחית",
  "equipmentObservation_tag_dumpLeak": "דליפה בשסתום פריקה",
  "equipmentObservation_tag_leakNeck": "דליפה באטם הצוואר",
  "equipmentObservation_tag_leakWrist": "דליפה באטם שורש כף היד",
  "equipmentObservation_tag_leakZip": "דליפה ברוכסן",
  "equipmentObservation_tag_leakBoot": "דליפה במגף",
  "equipmentObservation_tag_leakValve": "דליפה בשסתום",
  "equipmentObservation_tag_leakSeam": "דליפה בתפר",
  "equipmentObservation_tag_tear": "קרע",
  "equipmentObservation_tag_seamFailure": "תפר נפרם",
  "equipmentObservation_tag_dim": "עמום",
  "equipmentObservation_tag_died": "הפסיק לפעול",
  "equipmentObservation_tag_flooded": "הוצף",
  "equipmentObservation_tag_switchFault": "תקלת מתג",
  "equipmentObservation_tag_batteryLow": "סוללה חלשה",
  "equipmentObservation_tag_screenFault": "תקלת מסך",
  "equipmentObservation_tag_connectionFault": "תקלת חיבור",
  "equipmentObservation_tag_dropout": "נפילת אות",
  "equipmentObservation_tag_cellWarning": "אזהרת תא",
  "equipmentObservation_tag_loopLeak": "דליפה בלולאה",
  "equipmentObservation_tag_solenoidFault": "תקלת סולנואיד",
  "equipmentObservation_tag_scrubberBreakthrough": "פריצת סופג",
  "equipmentObservation_tag_slowResponse": "תגובה איטית",
  "equipmentObservation_tag_erratic": "לא יציב",
  "equipmentObservation_tag_lowCapacity": "קיבולת נמוכה",
  "equipmentObservation_tag_propFault": "תקלת מדחף",
  "equipmentObservation_tag_strapBroke": "רצועה נקרעה",
  "equipmentObservation_tag_other": "אחר",
  "equipmentObservation_status_ok": "תקין",
  "equipmentObservation_status_issue": "בעיה",
  "equipmentObservation_sheet_title": "בדיקה: {item}",
  "equipmentObservation_sheet_empty": "עדיין אין בדיקות בצלילה זו.",
  "equipmentObservation_sheet_emptyBench": "עדיין אין בדיקות.",
  "equipmentObservation_sheet_add": "הוספת בדיקה",
  "equipmentObservation_sheet_edit": "עריכת בדיקה",
  "equipmentObservation_sheet_delete": "מחיקת בדיקה",
  "equipmentObservation_sheet_deleteConfirm": "למחוק בדיקה זו?",
  "equipmentObservation_sheet_noteLabel": "הערה",
  "equipmentObservation_sheet_tagsLabel": "מה קרה",
  "equipmentObservation_sheet_dateLabel": "נצפה",
  "equipmentObservation_sheet_diveLabel": "צלילה",
  "equipmentObservation_sheet_noDive": "ללא צלילה (שולחן עבודה)",
  "equipmentObservation_sheet_pickDive": "בחירת צלילה",
  "equipmentObservation_sheet_save": "שמירה",
  "equipmentObservation_sheet_cancel": "ביטול",
  "equipmentObservation_sheet_tagRequired": "בחרו לפחות תגית אחת לבעיה",
  "equipmentObservation_chip_ok": "נבדק, תקין",
  "equipmentObservation_chip_issue": "דווחה בעיה",
  "equipmentObservation_chip_none": "בדיקה",
  "equipmentObservation_card_title": "בדיקות",
  "equipmentObservation_card_empty": "לא נרשמו בדיקות לפריט זה.",
  "equipmentObservation_card_add": "הוספת בדיקה",
  "equipmentObservation_card_onDive": "צלילה מס' {number}",
  "equipmentObservation_card_bench": "שולחן עבודה",
```

Task 10:

```json
  "incidentEdit_equipment": "ציוד מעורב",
  "incidentEdit_equipment_none": "ללא",
  "incidentEdit_equipment_onThisDive": "בצלילה זו",
  "incidentEdit_equipment_allGear": "כל הציוד",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "בדיקות ציוד",
  "transfer_csvExport_descriptionObservations": "כל בדיקה תקינה וכל בעיה שדווחה, עם הצלילה, התגיות וההערה",
  "transfer_csvExport_optionObservationsTitle": "CSV של בדיקות ציוד",
  "settings_export_progress_observationsCsv": "מייצא בדיקות ציוד ל-CSV...",
  "settings_export_progress_preparingObservationsCsv": "מכין CSV של בדיקות ציוד...",
  "settings_export_empty_observations": "אין בדיקות ציוד לייצוא",
  "settings_export_success_observations": "בדיקות הציוד יוצאו",
  "settings_export_saved_observationsCsv": "קובץ ה-CSV של בדיקות הציוד נשמר",
```

### app_zh.arb

Task 6:

```json
  "equipmentObservation_tag_freeFlow": "自由流",
  "equipmentObservation_tag_hardBreathing": "呼吸费力",
  "equipmentObservation_tag_wetBreathing": "呼吸进水",
  "equipmentObservation_tag_leak": "泄漏",
  "equipmentObservation_tag_hoseDamage": "软管损坏",
  "equipmentObservation_tag_inflatorStuck": "充气阀卡住",
  "equipmentObservation_tag_inflatorSlow": "充气阀迟缓",
  "equipmentObservation_tag_bladderLeak": "气囊泄漏",
  "equipmentObservation_tag_dumpLeak": "排气阀泄漏",
  "equipmentObservation_tag_leakNeck": "颈封泄漏",
  "equipmentObservation_tag_leakWrist": "腕封泄漏",
  "equipmentObservation_tag_leakZip": "拉链泄漏",
  "equipmentObservation_tag_leakBoot": "靴子泄漏",
  "equipmentObservation_tag_leakValve": "阀门泄漏",
  "equipmentObservation_tag_leakSeam": "接缝泄漏",
  "equipmentObservation_tag_tear": "撕裂",
  "equipmentObservation_tag_seamFailure": "接缝开裂",
  "equipmentObservation_tag_dim": "变暗",
  "equipmentObservation_tag_died": "失灵",
  "equipmentObservation_tag_flooded": "进水",
  "equipmentObservation_tag_switchFault": "开关故障",
  "equipmentObservation_tag_batteryLow": "电量低",
  "equipmentObservation_tag_screenFault": "屏幕故障",
  "equipmentObservation_tag_connectionFault": "连接故障",
  "equipmentObservation_tag_dropout": "信号中断",
  "equipmentObservation_tag_cellWarning": "传感器警告",
  "equipmentObservation_tag_loopLeak": "回路泄漏",
  "equipmentObservation_tag_solenoidFault": "电磁阀故障",
  "equipmentObservation_tag_scrubberBreakthrough": "吸收剂穿透",
  "equipmentObservation_tag_slowResponse": "响应迟缓",
  "equipmentObservation_tag_erratic": "读数不稳",
  "equipmentObservation_tag_lowCapacity": "容量偏低",
  "equipmentObservation_tag_propFault": "螺旋桨故障",
  "equipmentObservation_tag_strapBroke": "带子断裂",
  "equipmentObservation_tag_other": "其他",
  "equipmentObservation_status_ok": "正常",
  "equipmentObservation_status_issue": "问题",
  "equipmentObservation_sheet_title": "检查：{item}",
  "equipmentObservation_sheet_empty": "本次潜水还没有检查记录。",
  "equipmentObservation_sheet_emptyBench": "还没有检查记录。",
  "equipmentObservation_sheet_add": "添加检查",
  "equipmentObservation_sheet_edit": "编辑检查",
  "equipmentObservation_sheet_delete": "删除检查",
  "equipmentObservation_sheet_deleteConfirm": "删除这条检查记录？",
  "equipmentObservation_sheet_noteLabel": "备注",
  "equipmentObservation_sheet_tagsLabel": "发生了什么",
  "equipmentObservation_sheet_dateLabel": "观察时间",
  "equipmentObservation_sheet_diveLabel": "潜水",
  "equipmentObservation_sheet_noDive": "无潜水（台面）",
  "equipmentObservation_sheet_pickDive": "选择潜水",
  "equipmentObservation_sheet_save": "保存",
  "equipmentObservation_sheet_cancel": "取消",
  "equipmentObservation_sheet_tagRequired": "问题至少要选一个标签",
  "equipmentObservation_chip_ok": "已检查，正常",
  "equipmentObservation_chip_issue": "已报告问题",
  "equipmentObservation_chip_none": "检查",
  "equipmentObservation_card_title": "检查记录",
  "equipmentObservation_card_empty": "该装备没有检查记录。",
  "equipmentObservation_card_add": "添加检查",
  "equipmentObservation_card_onDive": "第 {number} 次潜水",
  "equipmentObservation_card_bench": "台面",
```

Task 10:

```json
  "incidentEdit_equipment": "涉及的装备",
  "incidentEdit_equipment_none": "无",
  "incidentEdit_equipment_onThisDive": "本次潜水",
  "incidentEdit_equipment_allGear": "全部装备",
```

Task 12:

```json
  "transfer_csvExport_typeObservations": "装备检查记录",
  "transfer_csvExport_descriptionObservations": "每条正常检查和报告的问题，含潜水、标签和备注",
  "transfer_csvExport_optionObservationsTitle": "装备检查记录 CSV",
  "settings_export_progress_observationsCsv": "正在将装备检查记录导出为 CSV...",
  "settings_export_progress_preparingObservationsCsv": "正在准备装备检查记录 CSV...",
  "settings_export_empty_observations": "没有可导出的装备检查记录",
  "settings_export_success_observations": "装备检查记录已导出",
  "settings_export_saved_observationsCsv": "装备检查记录 CSV 已保存",
```

The German block above and these nine were the strings that shipped; Task 12 grew two keys beyond the plan's list (`settings_export_success_observations`, `settings_export_saved_observationsCsv`) because the equipment CSV path reports success through its own two keys.
