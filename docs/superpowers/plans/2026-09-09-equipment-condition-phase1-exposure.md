# Equipment Condition Intelligence, Phase 1: Exposure Ledger and Clocks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the runtime-only usage sample behind service clocks with a per-dive exposure sample (mode, depth, temperature, water type, O2 contact), let a schedule express its interval in salt hours, cold dives, high-O2 hours, deep cycles or battery cycles, add the schema every later phase needs, and push usage-driven clocks as notifications.

**Architecture:** Exposure is derived on read: one SQL union over `dive_equipment`, `dive_tanks.equipment_id`, the new `dive_tanks.regulator_equipment_id` and the new parent link, left-joined to the (still empty in this phase) `dive_sensor_summaries` table. A pure `ExposureClassifier` applies the diver's thresholds to each sample, and `ServiceDueEngine` reads intervals per `ExposureUnit`. Nothing about the anchor chain, the severity rule or the existing clock UI changes shape; the legacy dives and hours fields become getters over a per-unit map.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Data model, Exposure and service clocks, Sync, migration, export; this plan is phase 1 of four).

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings). Rewrite the sentence instead.
- No tool or vendor attribution in any commit, comment, file or PR body.
- Run `dart format .` before every commit. The pre-push hook runs format, analyze, l10n staleness and tests.
- TDD: write the failing test first, run it, watch it fail, then implement.
- Every user-facing string goes through `context.l10n` and is added to all 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`). Only `app_en.arb` is alphabetical; in the other ten files insert each key next to the same neighbouring key it sits beside in English. Regenerate with `flutter gen-l10n` after editing ARB files.
- Anything displaying units respects the active diver's unit settings (`UnitFormatter`).
- Schema rung: this plan writes **v202**. Task 0 verified on 2026-09-09: PR #1677 merged (main is v200) and three open sibling branches claim 201, so this branch takes 202. If 202 is claimed by execution time, renumber every `202` in this plan and in the migration test.
- Stored values are metric (Celsius, metres, O2 fraction 0 to 1). Conversion happens at the edges only.
- The word `build` alone in a Bash command can be refused by the harness's read-deny rule. If `dart run build_runner build --delete-conflicting-outputs` is refused, write it into a script under the scratchpad directory and run that script.
- Commit after every task with the message given in the task. Never `git add -A`; stage the listed paths.

## File structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/equipment/domain/entities/exposure_unit.dart` | `ExposureUnit` enum plus JSON codec for the `exposure_intervals` map |
| `lib/features/equipment/domain/entities/exposure_thresholds.dart` | `ExposureThresholds` value object with the built-in defaults |
| `lib/features/equipment/domain/services/exposure_classifier.dart` | Pure per-sample contributions and totals per unit |
| `lib/features/equipment/presentation/providers/exposure_thresholds_provider.dart` | Thresholds from `AppSettings`, shared by providers and the scheduler |
| `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart` | Threshold editing in the diver's units |
| `test/features/equipment/domain/entities/exposure_unit_test.dart` | Codec tests |
| `test/features/equipment/domain/services/exposure_classifier_test.dart` | Boundary tests |
| `test/core/database/migration_v202_equipment_condition_test.dart` | Rung test |
| `test/core/services/sync/equipment_condition_columns_sync_test.dart` | Round-trip of the new columns |
| `test/features/equipment/data/exposure_samples_query_test.dart` | Union query and statement count |
| `test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart` | Threshold page |

Modified files (by task): `lib/core/constants/enums.dart`, `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`, `lib/features/equipment/presentation/utils/equipment_enum_display.dart`, `lib/features/equipment/presentation/utils/equipment_type_icon.dart`, `lib/features/equipment/domain/entities/service_clock_status.dart`, `lib/features/equipment/domain/services/service_due_engine.dart`, `lib/features/equipment/domain/entities/service_kind.dart`, `lib/features/equipment/domain/entities/service_schedule.dart`, `lib/features/equipment/domain/entities/equipment_item.dart`, `lib/core/database/database.dart`, `lib/features/equipment/data/repositories/{service_kind_repository,service_schedule_repository,equipment_repository_impl}.dart`, `lib/features/dive_log/domain/entities/dive.dart`, `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`, `lib/features/dive_log/presentation/widgets/tank_editor.dart`, `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/features/equipment/presentation/providers/equipment_providers.dart`, `lib/features/notifications/data/services/notification_scheduler.dart`, `lib/features/notifications/data/repositories/scheduled_notification_repository.dart`, `lib/features/equipment/presentation/widgets/{service_schedule_dialogs,service_trigger_text,service_clocks_card}.dart`, `lib/features/equipment/presentation/pages/{equipment_edit_page,service_kind_list_page}.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/settings/presentation/widgets/settings_list_content.dart`, `lib/core/router/app_router.dart`, the 11 ARB files.

---

### Task 0: Worktree preflight and rung check

**Files:** none modified.

- [ ] **Step 1: Initialise the worktree**

```bash
git submodule update --init --recursive && flutter pub get
```

- [ ] **Step 2: Confirm the baseline is green for analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Confirm v202 is free**

```bash
grep -n "currentSchemaVersion = " lib/core/database/database.dart
gh pr list --state open --json number,headRefName,title --limit 50
```

Expected: local is `200`. For every open PR branch run `git fetch origin <headRefName> && git show origin/<headRefName>:lib/core/database/database.dart | grep -n "currentSchemaVersion = "`. PR #1677 shows `200`. If any branch shows `202`, pick the next unclaimed number and replace every `202` in this plan and in Task 6 before continuing.

- [ ] **Step 4: Confirm the branch**

Run: `git branch --show-current`
Expected: `ericgriffin/equipment-condition-intelligence-e9b61e`

---

### Task 1: New equipment types, attribute catalog entries, display and icon

**Files:**
- Modify: `lib/core/constants/enums.dart:37-38` (inside `EquipmentType`, before `other`)
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (`EquipmentAttrKeys`, `_byType`)
- Modify: `lib/features/equipment/presentation/utils/equipment_enum_display.dart:41-42`
- Modify: `lib/features/equipment/presentation/utils/equipment_type_icon.dart:95-100`
- Modify: all 11 ARB files (keys listed in Step 3)
- Test: `test/features/equipment/domain/constants/equipment_attribute_catalog_children_test.dart`

**Interfaces:**
- Produces: `EquipmentType.o2Cell`, `EquipmentType.battery`; `EquipmentAttrKeys.cellSlot` (`'cell_slot'`), `EquipmentAttrKeys.installedDate` (`'installed_date'`), `EquipmentAttrKeys.rechargeable` (`'rechargeable'`); catalog entries for both types.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/constants/equipment_attribute_catalog_children_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('o2Cell carries a slot and an install date', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.o2Cell,
    ).map((d) => d.key).toList();
    expect(keys, containsAll(['cell_slot', 'installed_date']));
    expect(
      EquipmentAttributeCatalog.defFor('cell_slot')!.kind,
      AttributeKind.number,
    );
    expect(
      EquipmentAttributeCatalog.defFor('installed_date')!.kind,
      AttributeKind.date,
    );
  });

  test('battery carries install date, chemistry and rechargeable flag', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.battery,
    ).map((d) => d.key).toList();
    expect(keys, containsAll(['installed_date', 'battery_type', 'rechargeable']));
    expect(
      EquipmentAttributeCatalog.defFor('battery_type')!.choiceKeys,
      containsAll(['lithium_ion', 'nimh', 'lead_acid', 'alkaline', 'lithium_primary']),
    );
  });

  test('the new types have localized names', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(EquipmentType.o2Cell.localizedName(l10n), 'O2 cell');
    expect(EquipmentType.battery.localizedName(l10n), 'Battery');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/constants/equipment_attribute_catalog_children_test.dart`
Expected: compile error, `o2Cell` is not a member of `EquipmentType`.

- [ ] **Step 3: Add the enum values, catalog entries, display cases, icon cases and ARB keys**

In `lib/core/constants/enums.dart`, inside `EquipmentType`, after `dpv('DPV'),` and before `other('Other');`:

```dart
  // Consumable parts that live inside another item (spec: equipment
  // condition intelligence). Both are children of a parent item and inherit
  // its dives from their install date.
  o2Cell('O2 Cell'),
  battery('Battery'),
```

In `equipment_attribute_catalog.dart`, add to `EquipmentAttrKeys`:

```dart
  // Child items (o2Cell, battery).
  static const cellSlot = 'cell_slot';
  static const installedDate = 'installed_date';
  static const rechargeable = 'rechargeable';
```

Replace the DPV `battery_type` definition's `choiceKeys` with the five-value list so the key stays one definition:

```dart
      EquipmentAttributeDef(
        key: 'battery_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'lithium_ion',
          'nimh',
          'lead_acid',
          'alkaline',
          'lithium_primary',
        ],
      ),
```

Add two entries to `_byType` before `EquipmentType.other: [],`:

```dart
    EquipmentType.o2Cell: [
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.cellSlot,
        kind: AttributeKind.number,
      ),
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.installedDate,
        kind: AttributeKind.date,
      ),
    ],
    EquipmentType.battery: [
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.installedDate,
        kind: AttributeKind.date,
      ),
      EquipmentAttributeDef(
        key: 'battery_type',
        kind: AttributeKind.choice,
        choiceKeys: [
          'lithium_ion',
          'nimh',
          'lead_acid',
          'alkaline',
          'lithium_primary',
        ],
      ),
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.rechargeable,
        kind: AttributeKind.flag,
      ),
    ],
```

`_byKey` is a non-const map literal, so a key defined under two types keeps the last definition; both `battery_type` and `installed_date` definitions are identical, so `defFor` is correct either way.

In `equipment_enum_display.dart`, before `EquipmentType.other => l10n.enum_equipmentType_other,`:

```dart
    EquipmentType.o2Cell => l10n.enum_equipmentType_o2Cell,
    EquipmentType.battery => l10n.enum_equipmentType_battery,
```

In `equipment_type_icon.dart`, before `case EquipmentType.other:`:

```dart
    case EquipmentType.o2Cell:
      return Icons.sensors;
    case EquipmentType.battery:
      return Icons.battery_full;
```

ARB keys (English; the other ten locales are in the Translation Appendix at the end of this plan). Insert `enum_equipmentType_o2Cell` and `enum_equipmentType_battery` next to `enum_equipmentType_dpv`; `attrLabel_cell_slot`, `attrLabel_installed_date`, `attrLabel_rechargeable` next to `attrLabel_burn_time_h`; `attrChoice_battery_type_alkaline`, `attrChoice_battery_type_lithium_primary` next to `attrChoice_battery_type_lead_acid`.

```json
  "enum_equipmentType_o2Cell": "O2 cell",
  "enum_equipmentType_battery": "Battery",
  "attrLabel_cell_slot": "Cell slot",
  "attrLabel_installed_date": "Installed",
  "attrLabel_rechargeable": "Rechargeable",
  "attrChoice_battery_type_alkaline": "Alkaline",
  "attrChoice_battery_type_lithium_primary": "Lithium (non-rechargeable)",
```

Run `flutter gen-l10n`.

- [ ] **Step 4: Run the test and the two neighbours**

Run: `flutter test test/features/equipment/domain/constants/ test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart`
Expected: all pass. The picker test counts `EquipmentType.values.length`, so it adapts.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/constants/enums.dart lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/presentation/utils/equipment_enum_display.dart lib/features/equipment/presentation/utils/equipment_type_icon.dart lib/l10n test/features/equipment/domain/constants/equipment_attribute_catalog_children_test.dart
git commit -m "feat(equipment): add O2 cell and battery item types"
```

---

### Task 2: ExposureUnit, ExposureThresholds, exposure sample and per-unit clock usage

**Files:**
- Create: `lib/features/equipment/domain/entities/exposure_unit.dart`
- Create: `lib/features/equipment/domain/entities/exposure_thresholds.dart`
- Modify: `lib/features/equipment/domain/entities/service_clock_status.dart`
- Test: `test/features/equipment/domain/entities/exposure_unit_test.dart`, `test/features/equipment/domain/entities/service_clock_status_test.dart`

**Interfaces:**
- Produces: `enum ExposureUnit { days, dives, hours, saltHours, coldDives, o2Hours, deepCycles, cycles }` with `dbValue`, `fromDbValue`, `static const mapUnits`, `bool get isFractional`; `Map<ExposureUnit, double> decodeExposureIntervals(String json)`; `String encodeExposureIntervals(Map<ExposureUnit, double> m)`; `class ExposureThresholds({coldWaterC = 10, deepDiveM = 30, highO2Fraction = 0.40})`; `class EquipmentExposureSample({date, durationSeconds, diveMode = DiveMode.oc, maxDepth, minTemperature, waterType, contactO2Fraction})`; `typedef DiveUsageSample = EquipmentExposureSample`; `class ClockUsage({interval, since})` with `remaining`; `ServiceClockStatus.usageByUnit`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/domain/entities/exposure_unit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

void main() {
  test('decode reads known units and ignores unknown keys', () {
    final m = decodeExposureIntervals('{"coldDives": 50, "o2Hours": 12.5, "bogus": 1}');
    expect(m, {ExposureUnit.coldDives: 50.0, ExposureUnit.o2Hours: 12.5});
  });

  test('decode tolerates an empty, blank or corrupt column', () {
    expect(decodeExposureIntervals('{}'), isEmpty);
    expect(decodeExposureIntervals(''), isEmpty);
    expect(decodeExposureIntervals('not json'), isEmpty);
  });

  test('encode writes sorted keys and drops non-positive values', () {
    final json = encodeExposureIntervals({
      ExposureUnit.saltHours: 200,
      ExposureUnit.coldDives: 50,
      ExposureUnit.cycles: 0,
    });
    expect(json, '{"coldDives":50.0,"saltHours":200.0}');
  });

  test('mapUnits excludes the three legacy column units', () {
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.days)));
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.dives)));
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.hours)));
    expect(ExposureUnit.mapUnits, hasLength(5));
  });
}
```

```dart
// test/features/equipment/domain/entities/service_clock_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  final schedule = ServiceSchedule(
    id: 's',
    equipmentId: 'e',
    serviceKindId: 'k',
    createdAt: t0,
    updatedAt: t0,
  );
  final kind = ServiceKind(id: 'k', name: 'K', createdAt: t0, updatedAt: t0);

  test('legacy dives and hours arguments populate usageByUnit', () {
    final s = ServiceClockStatus(
      schedule: schedule,
      kind: kind,
      anchor: t0,
      divesSinceAnchor: 40,
      divesRemaining: 60,
      hoursSinceAnchor: 2.5,
      hoursRemaining: 0.5,
      severity: ServiceClockSeverity.ok,
      now: t0,
    );
    expect(s.usageByUnit[ExposureUnit.dives], const ClockUsage(interval: 100, since: 40));
    expect(s.usageByUnit[ExposureUnit.hours], const ClockUsage(interval: 3.0, since: 2.5));
    expect(s.divesRemaining, 60);
    expect(s.hoursRemaining, closeTo(0.5, 1e-9));
  });

  test('usageByUnit drives the legacy getters', () {
    final s = ServiceClockStatus(
      schedule: schedule,
      kind: kind,
      anchor: t0,
      usageByUnit: const {
        ExposureUnit.dives: ClockUsage(interval: 10, since: 12),
        ExposureUnit.coldDives: ClockUsage(interval: 50, since: 3),
      },
      severity: ServiceClockSeverity.overdue,
      now: t0,
    );
    expect(s.divesSinceAnchor, 12);
    expect(s.divesRemaining, -2);
    expect(s.hoursRemaining, isNull);
    expect(s.usageByUnit[ExposureUnit.coldDives]!.remaining, 47);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/entities/exposure_unit_test.dart test/features/equipment/domain/entities/service_clock_status_test.dart`
Expected: compile errors (`exposure_unit.dart` missing, `usageByUnit` undefined).

- [ ] **Step 3: Create the two new files and rewrite the clock status**

```dart
// lib/features/equipment/domain/entities/exposure_unit.dart
import 'dart:convert';

/// What a service clock counts. [days], [dives] and [hours] live in their
/// own columns on service_kinds and service_schedules (v122); every other
/// unit lives in the `exposure_intervals` JSON map, keyed by [name].
enum ExposureUnit {
  days,
  dives,
  hours,
  saltHours,
  coldDives,
  o2Hours,
  deepCycles,
  cycles;

  String get dbValue => name;

  static ExposureUnit? fromDbValue(String value) {
    for (final u in ExposureUnit.values) {
      if (u.name == value) return u;
    }
    return null;
  }

  /// Units stored in the JSON map (the legacy three keep their columns).
  static const List<ExposureUnit> mapUnits = [
    saltHours,
    coldDives,
    o2Hours,
    deepCycles,
    cycles,
  ];

  /// Whether a value in this unit is a real number (hours) or a count.
  bool get isFractional =>
      this == hours || this == saltHours || this == o2Hours;
}

/// Reads an `exposure_intervals` column. Unknown keys and unreadable JSON
/// yield nothing rather than throwing: a newer peer may sync a unit this
/// build does not know, and a corrupt column must not take the clock down.
Map<ExposureUnit, double> decodeExposureIntervals(String json) {
  if (json.trim().isEmpty) return const {};
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  final out = <ExposureUnit, double>{};
  for (final entry in decoded.entries) {
    final unit = ExposureUnit.fromDbValue(entry.key.toString());
    final value = entry.value;
    if (unit == null || value is! num) continue;
    out[unit] = value.toDouble();
  }
  return out;
}

/// Writes the map with sorted keys so two devices encoding the same map
/// produce byte-identical columns. Non-positive values are dropped: they
/// mean "no trigger", and "no key" already says that.
String encodeExposureIntervals(Map<ExposureUnit, double> intervals) {
  final entries = intervals.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => a.key.name.compareTo(b.key.name));
  return jsonEncode({for (final e in entries) e.key.name: e.value});
}
```

```dart
// lib/features/equipment/domain/entities/exposure_thresholds.dart
import 'package:equatable/equatable.dart';

/// The lines that classify a dive as cold, deep or high-O2 for exposure
/// clocks. Stored metric; the settings page converts at the edge.
class ExposureThresholds extends Equatable {
  /// Dives with a minimum water temperature below this count as cold.
  /// 10 C is the EN 250 cold-water line.
  final double coldWaterC;

  /// Dives reaching this depth count as a deep cycle.
  final double deepDiveM;

  /// Contact with a mix above this O2 fraction counts as high-O2 service.
  final double highO2Fraction;

  const ExposureThresholds({
    this.coldWaterC = 10.0,
    this.deepDiveM = 30.0,
    this.highO2Fraction = 0.40,
  });

  static const defaults = ExposureThresholds();

  @override
  List<Object?> get props => [coldWaterC, deepDiveM, highO2Fraction];
}
```

Replace the whole of `lib/features/equipment/domain/entities/service_clock_status.dart` with:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

enum ServiceClockSeverity { ok, dueSoon, overdue }

/// One dive's contribution to usage-based clocks: what the item was exposed
/// to, in storage units. Everything beyond date and duration is optional so
/// a dive logged without a profile or water type still counts a dive and
/// its hours.
class EquipmentExposureSample extends Equatable {
  final DateTime date;
  final int durationSeconds;
  final DiveMode diveMode;

  /// Metres, from the profile when available, else the dive header.
  final double? maxDepth;

  /// Celsius, the profile minimum when available, else the dive header.
  final double? minTemperature;
  final WaterType? waterType;

  /// The highest O2 fraction (0 to 1) this item was in contact with on the
  /// dive, or null when the link path carries no gas (a mask, a fin).
  final double? contactO2Fraction;

  const EquipmentExposureSample({
    required this.date,
    required this.durationSeconds,
    this.diveMode = DiveMode.oc,
    this.maxDepth,
    this.minTemperature,
    this.waterType,
    this.contactO2Fraction,
  });

  double get durationHours => durationSeconds / 3600.0;

  @override
  List<Object?> get props => [
    date,
    durationSeconds,
    diveMode,
    maxDepth,
    minTemperature,
    waterType,
    contactO2Fraction,
  ];
}

/// The v122 name. Every field beyond date and duration is optional, so
/// existing call sites and tests keep compiling.
typedef DiveUsageSample = EquipmentExposureSample;

/// One unit's progress on a clock: the configured interval and the amount
/// accrued since the anchor, both in that unit.
class ClockUsage extends Equatable {
  final double interval;
  final double since;

  const ClockUsage({required this.interval, required this.since});

  double get remaining => interval - since;

  @override
  List<Object?> get props => [interval, since];
}

/// The evaluated state of one service clock at a point in time.
class ServiceClockStatus extends Equatable {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final DateTime anchor;
  final DateTime? dueDate;

  /// Progress per configured usage unit. Units with no interval are absent.
  final Map<ExposureUnit, ClockUsage> usageByUnit;
  final ServiceClockSeverity severity;
  final DateTime now;

  /// [divesSinceAnchor], [divesRemaining], [hoursSinceAnchor] and
  /// [hoursRemaining] are the v122 spelling; they fold into [usageByUnit].
  /// Pass either form, not both for the same unit.
  ServiceClockStatus({
    required this.schedule,
    required this.kind,
    required this.anchor,
    this.dueDate,
    int? divesSinceAnchor,
    int? divesRemaining,
    double? hoursSinceAnchor,
    double? hoursRemaining,
    Map<ExposureUnit, ClockUsage> usageByUnit = const {},
    required this.severity,
    required this.now,
  }) : usageByUnit = _fold(
         usageByUnit,
         divesSinceAnchor: divesSinceAnchor,
         divesRemaining: divesRemaining,
         hoursSinceAnchor: hoursSinceAnchor,
         hoursRemaining: hoursRemaining,
       );

  static Map<ExposureUnit, ClockUsage> _fold(
    Map<ExposureUnit, ClockUsage> given, {
    int? divesSinceAnchor,
    int? divesRemaining,
    double? hoursSinceAnchor,
    double? hoursRemaining,
  }) {
    final out = Map<ExposureUnit, ClockUsage>.from(given);
    if (divesSinceAnchor != null && divesRemaining != null) {
      out.putIfAbsent(
        ExposureUnit.dives,
        () => ClockUsage(
          interval: (divesSinceAnchor + divesRemaining).toDouble(),
          since: divesSinceAnchor.toDouble(),
        ),
      );
    }
    if (hoursSinceAnchor != null && hoursRemaining != null) {
      out.putIfAbsent(
        ExposureUnit.hours,
        () => ClockUsage(
          interval: hoursSinceAnchor + hoursRemaining,
          since: hoursSinceAnchor,
        ),
      );
    }
    return Map.unmodifiable(out);
  }

  int? get divesSinceAnchor => usageByUnit[ExposureUnit.dives]?.since.round();
  int? get divesRemaining =>
      usageByUnit[ExposureUnit.dives]?.remaining.round();
  double? get hoursSinceAnchor => usageByUnit[ExposureUnit.hours]?.since;
  double? get hoursRemaining => usageByUnit[ExposureUnit.hours]?.remaining;

  /// Days until the date trigger fires; negative when past, null when the
  /// clock has no date trigger.
  int? get daysUntilDue => dueDate?.difference(now).inDays;

  @override
  List<Object?> get props => [
    schedule,
    kind,
    anchor,
    dueDate,
    usageByUnit,
    severity,
    now,
  ];
}
```

- [ ] **Step 4: Run the tests plus every existing consumer**

Run: `flutter test test/features/equipment/domain/entities/ test/features/equipment/domain/services/service_due_engine_test.dart test/features/pre_dive test/features/dashboard test/features/trips`
Expected: all pass. Nothing else changed yet, so the engine still fills the legacy arguments.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/entities/exposure_unit.dart lib/features/equipment/domain/entities/exposure_thresholds.dart lib/features/equipment/domain/entities/service_clock_status.dart test/features/equipment/domain/entities/exposure_unit_test.dart test/features/equipment/domain/entities/service_clock_status_test.dart
git commit -m "feat(equipment): exposure units, thresholds and per-unit clock usage"
```

---

### Task 3: ExposureClassifier

**Files:**
- Create: `lib/features/equipment/domain/services/exposure_classifier.dart`
- Test: `test/features/equipment/domain/services/exposure_classifier_test.dart`

**Interfaces:**
- Consumes: `ExposureUnit`, `ExposureThresholds`, `EquipmentExposureSample` (Task 2).
- Produces: `class ExposureClassifier({thresholds = ExposureThresholds.defaults, loopTimeOnly = false, hasBatteryChild = false})` with `double contribution(EquipmentExposureSample s, ExposureUnit unit)` and `Map<ExposureUnit, double> totals(Iterable<EquipmentExposureSample> samples)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/services/exposure_classifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

void main() {
  final d = DateTime(2026, 6, 1);
  EquipmentExposureSample sample({
    int seconds = 3600,
    DiveMode mode = DiveMode.oc,
    double? depth,
    double? temp,
    WaterType? water,
    double? o2,
  }) => EquipmentExposureSample(
    date: d,
    durationSeconds: seconds,
    diveMode: mode,
    maxDepth: depth,
    minTemperature: temp,
    waterType: water,
    contactO2Fraction: o2,
  );
  const c = ExposureClassifier();

  test('dives and cycles count one per sample; hours are duration', () {
    final s = sample(seconds: 5400);
    expect(c.contribution(s, ExposureUnit.dives), 1);
    expect(c.contribution(s, ExposureUnit.cycles), 1);
    expect(c.contribution(s, ExposureUnit.hours), closeTo(1.5, 1e-9));
    expect(c.contribution(s, ExposureUnit.days), 0);
  });

  test('salt hours count salt and brackish, not fresh or unknown', () {
    expect(c.contribution(sample(water: WaterType.salt), ExposureUnit.saltHours), 1);
    expect(c.contribution(sample(water: WaterType.brackish), ExposureUnit.saltHours), 1);
    expect(c.contribution(sample(water: WaterType.fresh), ExposureUnit.saltHours), 0);
    expect(c.contribution(sample(), ExposureUnit.saltHours), 0);
  });

  test('cold is strictly below the line; unknown temperature is not cold', () {
    expect(c.contribution(sample(temp: 9.9), ExposureUnit.coldDives), 1);
    expect(c.contribution(sample(temp: 10.0), ExposureUnit.coldDives), 0);
    expect(c.contribution(sample(), ExposureUnit.coldDives), 0);
  });

  test('deep is at or beyond the line', () {
    expect(c.contribution(sample(depth: 30.0), ExposureUnit.deepCycles), 1);
    expect(c.contribution(sample(depth: 29.9), ExposureUnit.deepCycles), 0);
    expect(c.contribution(sample(), ExposureUnit.deepCycles), 0);
  });

  test('O2 hours need contact strictly above the line', () {
    expect(c.contribution(sample(o2: 0.40), ExposureUnit.o2Hours), 0);
    expect(c.contribution(sample(o2: 0.41), ExposureUnit.o2Hours), 1);
    expect(c.contribution(sample(), ExposureUnit.o2Hours), 0);
  });

  test('custom thresholds move every line', () {
    const cold = ExposureClassifier(
      thresholds: ExposureThresholds(coldWaterC: 15, deepDiveM: 20, highO2Fraction: 0.30),
    );
    expect(cold.contribution(sample(temp: 14), ExposureUnit.coldDives), 1);
    expect(cold.contribution(sample(depth: 20), ExposureUnit.deepCycles), 1);
    expect(cold.contribution(sample(o2: 0.32), ExposureUnit.o2Hours), 1);
  });

  test('a rebreather counts loop hours only, but salt hours regardless', () {
    const loop = ExposureClassifier(loopTimeOnly: true);
    expect(loop.contribution(sample(mode: DiveMode.oc), ExposureUnit.hours), 0);
    expect(loop.contribution(sample(mode: DiveMode.gauge), ExposureUnit.hours), 0);
    expect(loop.contribution(sample(mode: DiveMode.ccr), ExposureUnit.hours), 1);
    expect(loop.contribution(sample(mode: DiveMode.scr), ExposureUnit.hours), 1);
    expect(
      loop.contribution(sample(mode: DiveMode.oc, water: WaterType.salt), ExposureUnit.saltHours),
      1,
    );
  });

  test('a parent with a battery child accrues no cycles', () {
    const parent = ExposureClassifier(hasBatteryChild: true);
    expect(parent.contribution(sample(), ExposureUnit.cycles), 0);
    expect(parent.contribution(sample(), ExposureUnit.dives), 1);
  });

  test('totals sum every unit over the samples', () {
    final totals = c.totals([
      sample(seconds: 3600, water: WaterType.salt, temp: 5, depth: 35, o2: 0.5),
      sample(seconds: 1800, water: WaterType.fresh, temp: 20, depth: 10),
    ]);
    expect(totals[ExposureUnit.dives], 2);
    expect(totals[ExposureUnit.hours], closeTo(1.5, 1e-9));
    expect(totals[ExposureUnit.saltHours], closeTo(1.0, 1e-9));
    expect(totals[ExposureUnit.coldDives], 1);
    expect(totals[ExposureUnit.deepCycles], 1);
    expect(totals[ExposureUnit.o2Hours], closeTo(1.0, 1e-9));
    expect(totals[ExposureUnit.cycles], 2);
    expect(totals[ExposureUnit.days], 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/services/exposure_classifier_test.dart`
Expected: compile error, `exposure_classifier.dart` not found.

- [ ] **Step 3: Implement the classifier**

```dart
// lib/features/equipment/domain/services/exposure_classifier.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// Turns exposure samples into per-unit amounts. Pure and threshold-driven,
/// so a changed setting changes every total on the next read with nothing
/// to rebuild.
///
/// Two item-level rules ride on the classifier because they depend on what
/// the item is, not on the dive:
/// - [loopTimeOnly]: rebreathers (and their children) accrue [ExposureUnit.hours]
///   on CCR and SCR mode dives only. Salt hours still count every dive: the
///   unit was wet whatever the loop did.
/// - [hasBatteryChild]: a parent whose battery is modelled as a child item
///   accrues no [ExposureUnit.cycles]; the child does.
class ExposureClassifier {
  final ExposureThresholds thresholds;
  final bool loopTimeOnly;
  final bool hasBatteryChild;

  const ExposureClassifier({
    this.thresholds = ExposureThresholds.defaults,
    this.loopTimeOnly = false,
    this.hasBatteryChild = false,
  });

  double contribution(EquipmentExposureSample s, ExposureUnit unit) {
    switch (unit) {
      case ExposureUnit.days:
        return 0; // The date trigger is evaluated from the anchor, not usage.
      case ExposureUnit.dives:
        return 1;
      case ExposureUnit.hours:
        if (loopTimeOnly &&
            s.diveMode != DiveMode.ccr &&
            s.diveMode != DiveMode.scr) {
          return 0;
        }
        return s.durationHours;
      case ExposureUnit.saltHours:
        return s.waterType == WaterType.salt ||
                s.waterType == WaterType.brackish
            ? s.durationHours
            : 0;
      case ExposureUnit.coldDives:
        final t = s.minTemperature;
        return t != null && t < thresholds.coldWaterC ? 1 : 0;
      case ExposureUnit.o2Hours:
        final o2 = s.contactO2Fraction;
        return o2 != null && o2 > thresholds.highO2Fraction
            ? s.durationHours
            : 0;
      case ExposureUnit.deepCycles:
        final depth = s.maxDepth;
        return depth != null && depth >= thresholds.deepDiveM ? 1 : 0;
      case ExposureUnit.cycles:
        return hasBatteryChild ? 0 : 1;
    }
  }

  Map<ExposureUnit, double> totals(Iterable<EquipmentExposureSample> samples) {
    final out = {for (final u in ExposureUnit.values) u: 0.0};
    for (final s in samples) {
      for (final u in ExposureUnit.values) {
        out[u] = out[u]! + contribution(s, u);
      }
    }
    return out;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/equipment/domain/services/exposure_classifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/services/exposure_classifier.dart test/features/equipment/domain/services/exposure_classifier_test.dart
git commit -m "feat(equipment): exposure classifier"
```

---

### Task 4: Service kind and schedule carry an exposure interval map

**Files:**
- Modify: `lib/features/equipment/domain/entities/service_kind.dart`
- Modify: `lib/features/equipment/domain/entities/service_schedule.dart`
- Test: `test/features/equipment/domain/entities/service_interval_map_test.dart`

**Interfaces:**
- Produces: `ServiceKind.exposureIntervals` and `ServiceSchedule.exposureIntervals` (`Map<ExposureUnit, double>`, default `const {}`), both in the constructor, `copyWith` and `props`; `double? ServiceSchedule.intervalFor(ExposureUnit unit, ServiceKind kind)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/domain/entities/service_interval_map_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  final kind = ServiceKind(
    id: 'regulator-service',
    name: 'Reg',
    defaultIntervalDays: 365,
    defaultIntervalDives: 100,
    exposureIntervals: const {ExposureUnit.coldDives: 50},
    createdAt: t0,
    updatedAt: t0,
  );

  test('a schedule inherits the kind map key by key', () {
    final s = ServiceSchedule(
      id: 's',
      equipmentId: 'e',
      serviceKindId: kind.id,
      exposureIntervals: const {ExposureUnit.saltHours: 120},
      createdAt: t0,
      updatedAt: t0,
    );
    expect(s.intervalFor(ExposureUnit.coldDives, kind), 50);
    expect(s.intervalFor(ExposureUnit.saltHours, kind), 120);
    expect(s.intervalFor(ExposureUnit.o2Hours, kind), isNull);
  });

  test('the legacy columns answer for days, dives and hours', () {
    final s = ServiceSchedule(
      id: 's',
      equipmentId: 'e',
      serviceKindId: kind.id,
      intervalDives: 80,
      createdAt: t0,
      updatedAt: t0,
    );
    expect(s.intervalFor(ExposureUnit.days, kind), 365);
    expect(s.intervalFor(ExposureUnit.dives, kind), 80);
    expect(s.intervalFor(ExposureUnit.hours, kind), isNull);
  });

  test('copyWith can replace the map', () {
    final k2 = kind.copyWith(exposureIntervals: const {ExposureUnit.o2Hours: 50});
    expect(k2.exposureIntervals, const {ExposureUnit.o2Hours: 50});
    expect(kind.exposureIntervals, const {ExposureUnit.coldDives: 50});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/service_interval_map_test.dart`
Expected: compile error, `exposureIntervals` is not a named parameter.

- [ ] **Step 3: Add the field to both entities**

In `service_kind.dart`, add the import and the field after `defaultIntervalHours`:

```dart
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
```

```dart
  /// Default intervals for the exposure units that have no column of their
  /// own (salt hours, cold dives, high-O2 hours, deep cycles, cycles).
  final Map<ExposureUnit, double> exposureIntervals;
```

Constructor: `this.exposureIntervals = const {},` after `this.defaultIntervalHours,`. `copyWith`: parameter `Map<ExposureUnit, double>? exposureIntervals,` and assignment `exposureIntervals: exposureIntervals ?? this.exposureIntervals,`. Add `exposureIntervals,` to `props` after `defaultIntervalHours,`.

In `service_schedule.dart`, the same three edits (field after `intervalHours`, constructor default `const {}`, `copyWith` parameter and assignment, `props`), plus the import of `exposure_unit.dart`, the import of `service_kind.dart`, and this method after `copyWith`:

```dart
  /// The effective interval for [unit]: this schedule's override, else the
  /// kind's default. The three v122 units read their columns; the rest read
  /// the map. Null means the unit does not trigger this clock.
  double? intervalFor(ExposureUnit unit, ServiceKind kind) {
    switch (unit) {
      case ExposureUnit.days:
        return (intervalDays ?? kind.defaultIntervalDays)?.toDouble();
      case ExposureUnit.dives:
        return (intervalDives ?? kind.defaultIntervalDives)?.toDouble();
      case ExposureUnit.hours:
        return intervalHours ?? kind.defaultIntervalHours;
      case ExposureUnit.saltHours:
      case ExposureUnit.coldDives:
      case ExposureUnit.o2Hours:
      case ExposureUnit.deepCycles:
      case ExposureUnit.cycles:
        return exposureIntervals[unit] ?? kind.exposureIntervals[unit];
    }
  }
```

Update the schedule class doc comment's "a clock with all three intervals null never fires" to "a clock with no interval in any unit never fires".

- [ ] **Step 4: Run the test and the equipment domain tests**

Run: `flutter test test/features/equipment/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/entities/service_kind.dart lib/features/equipment/domain/entities/service_schedule.dart test/features/equipment/domain/entities/service_interval_map_test.dart
git commit -m "feat(equipment): exposure interval map on service kinds and schedules"
```

---

### Task 5: ServiceDueEngine evaluates every unit

**Files:**
- Modify: `lib/features/equipment/domain/services/service_due_engine.dart`
- Test: `test/features/equipment/domain/services/service_due_engine_test.dart` (append a group)

**Interfaces:**
- Consumes: Tasks 2 to 4.
- Produces: `ServiceDueEngine.evaluate({..., required List<EquipmentExposureSample> usage, ExposureClassifier classifier = const ExposureClassifier(), ...})`; statuses carry `usageByUnit` for every configured unit except `days`.

- [ ] **Step 1: Append the failing tests**

Add this group at the end of `main()` in the existing engine test (the file already defines `engine`, `t0`, `now`, `sched`, `record` and `run`; add `import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';` and `import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';` at the top):

```dart
  group('exposure units', () {
    ServiceKind regWithCold() => ServiceKind(
      id: 'regulator-service',
      name: 'Reg service',
      defaultIntervalDays: 365,
      exposureIntervals: const {ExposureUnit.coldDives: 3},
      applicableTypes: const [EquipmentType.regulator],
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    EquipmentExposureSample cold(int daysAfterT0) => EquipmentExposureSample(
      date: t0.add(Duration(days: daysAfterT0)),
      durationSeconds: 3600,
      minTemperature: 4,
    );
    EquipmentExposureSample warm(int daysAfterT0) => EquipmentExposureSample(
      date: t0.add(Duration(days: daysAfterT0)),
      durationSeconds: 3600,
      minTemperature: 24,
    );

    test('a kind-level cold-dive interval counts only cold dives', () {
      final statuses = engine.evaluate(
        schedules: [sched('regulator-service')],
        kindsById: {'regulator-service': regWithCold()},
        records: const [],
        usage: [cold(10), warm(20), cold(30)],
        purchaseDate: t0,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: t0.add(const Duration(days: 40)),
      );
      final usage = statuses.single.usageByUnit[ExposureUnit.coldDives]!;
      expect(usage.interval, 3);
      expect(usage.since, 2);
      expect(usage.remaining, 1);
      expect(statuses.single.severity, ServiceClockSeverity.dueSoon);
    });

    test('a schedule override beats the kind default and can go overdue', () {
      final schedule = sched('regulator-service').copyWith(
        exposureIntervals: const {ExposureUnit.coldDives: 2},
      );
      final statuses = engine.evaluate(
        schedules: [schedule],
        kindsById: {'regulator-service': regWithCold()},
        records: const [],
        usage: [cold(10), cold(20)],
        purchaseDate: t0,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: t0.add(const Duration(days: 40)),
      );
      expect(statuses.single.usageByUnit[ExposureUnit.coldDives]!.remaining, 0);
      expect(statuses.single.severity, ServiceClockSeverity.overdue);
    });

    test('a service record resets every unit', () {
      final statuses = engine.evaluate(
        schedules: [sched('regulator-service')],
        kindsById: {'regulator-service': regWithCold()},
        records: [record('regulator-service', t0.add(const Duration(days: 25)))],
        usage: [cold(10), cold(20), cold(30)],
        purchaseDate: t0,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: t0.add(const Duration(days: 40)),
      );
      expect(statuses.single.usageByUnit[ExposureUnit.coldDives]!.since, 1);
    });

    test('the classifier is injectable', () {
      final statuses = engine.evaluate(
        schedules: [sched('regulator-service')],
        kindsById: {'regulator-service': regWithCold()},
        records: const [],
        usage: [warm(10)],
        classifier: const ExposureClassifier(
          thresholds: ExposureThresholds(coldWaterC: 25),
        ),
        purchaseDate: t0,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: t0.add(const Duration(days: 40)),
      );
      expect(statuses.single.usageByUnit[ExposureUnit.coldDives]!.since, 1);
    });

    test('legacy dives and hours still evaluate through the map', () {
      final statuses = engine.evaluate(
        schedules: [sched('regulator-service', dives: 10, hours: 5)],
        kindsById: {'regulator-service': regWithCold()},
        records: const [],
        usage: [cold(10), warm(20)],
        purchaseDate: t0,
        equipmentCreatedAt: t0,
        dueSoonWindowDays: 30,
        now: t0.add(const Duration(days: 40)),
      );
      final s = statuses.single;
      expect(s.divesSinceAnchor, 2);
      expect(s.divesRemaining, 8);
      expect(s.hoursSinceAnchor, closeTo(2, 1e-9));
      expect(s.hoursRemaining, closeTo(3, 1e-9));
    });
  });
```

Also add `import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/domain/services/service_due_engine_test.dart`
Expected: compile error, `classifier` is not a named parameter (and `usageByUnit[coldDives]` is null in the first test once it compiles).

- [ ] **Step 3: Rewrite `evaluate`**

Replace the body of `ServiceDueEngine.evaluate` and `_severity` with:

```dart
  List<ServiceClockStatus> evaluate({
    required List<ServiceSchedule> schedules,
    required Map<String, ServiceKind> kindsById,
    required List<ServiceRecord> records,
    required List<EquipmentExposureSample> usage,
    ExposureClassifier classifier = const ExposureClassifier(),
    DateTime? purchaseDate,
    required DateTime equipmentCreatedAt,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    final statuses = <ServiceClockStatus>[];

    for (final schedule in schedules) {
      if (!schedule.enabled) continue;
      final kind = kindsById[schedule.serviceKindId];
      if (kind == null) continue;

      final intervals = <ExposureUnit, double>{
        for (final unit in ExposureUnit.values)
          if (schedule.intervalFor(unit, kind) case final v? when v > 0)
            unit: v,
      };
      if (intervals.isEmpty) continue; // no triggers configured

      final anchor = _anchorFor(
        schedule: schedule,
        records: records,
        purchaseDate: purchaseDate,
        equipmentCreatedAt: equipmentCreatedAt,
      );

      final intervalDays = intervals[ExposureUnit.days];
      final dueDate = intervalDays != null
          ? anchor.add(Duration(days: intervalDays.round()))
          : null;

      final usageSince = usage.where((u) => u.date.isAfter(anchor)).toList();
      final usageByUnit = <ExposureUnit, ClockUsage>{
        for (final entry in intervals.entries)
          if (entry.key != ExposureUnit.days)
            entry.key: ClockUsage(
              interval: entry.value,
              since: usageSince.fold<double>(
                0,
                (sum, u) => sum + classifier.contribution(u, entry.key),
              ),
            ),
      };

      statuses.add(
        ServiceClockStatus(
          schedule: schedule,
          kind: kind,
          anchor: anchor,
          dueDate: dueDate,
          usageByUnit: usageByUnit,
          severity: _severity(
            dueDate: dueDate,
            usageByUnit: usageByUnit,
            dueSoonWindowDays: dueSoonWindowDays,
            now: now,
          ),
          now: now,
        ),
      );
    }

    statuses.sort((a, b) {
      if (a.severity != b.severity) {
        return b.severity.index.compareTo(a.severity.index);
      }
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return statuses;
  }
```

```dart
  ServiceClockSeverity _severity({
    required DateTime? dueDate,
    required Map<ExposureUnit, ClockUsage> usageByUnit,
    required int dueSoonWindowDays,
    required DateTime now,
  }) {
    // Date trigger becomes overdue strictly after the due date, matching the
    // legacy single-clock EquipmentItem.isServiceDue (now.isAfter(dueDate)).
    // At exactly the due instant the clock reads dueSoon, not overdue.
    if (dueDate != null && now.isAfter(dueDate)) {
      return ServiceClockSeverity.overdue;
    }
    for (final u in usageByUnit.values) {
      if (u.remaining <= 0) return ServiceClockSeverity.overdue;
    }
    if (dueDate != null &&
        dueDate.difference(now).inDays <= dueSoonWindowDays) {
      return ServiceClockSeverity.dueSoon;
    }
    for (final entry in usageByUnit.entries) {
      final u = entry.value;
      // Counts round the 10 percent band up (the v122 dives rule); hours
      // and other fractional units compare directly.
      final band = entry.key.isFractional
          ? u.interval * 0.1
          : (u.interval * 0.1).ceilToDouble();
      if (u.remaining <= band) return ServiceClockSeverity.dueSoon;
    }
    return ServiceClockSeverity.ok;
  }
```

Add the imports `exposure_unit.dart` and `exposure_classifier.dart`. Keep `_anchorFor` unchanged.

- [ ] **Step 4: Run the engine test and every clock consumer**

Run: `flutter test test/features/equipment test/features/pre_dive test/features/dashboard test/features/trips test/features/notifications`
Expected: PASS. If a pre-existing test pinned the dueSoon band for dives, the rounding above reproduces `(intervalDives * 0.1).ceil()` exactly.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/domain/services/service_due_engine.dart test/features/equipment/domain/services/service_due_engine_test.dart
git commit -m "feat(equipment): service due engine evaluates exposure units"
```

---

### Task 6: Schema rung v202

**Files:**
- Modify: `lib/core/database/database.dart` (tables `Equipment`, `DiveTanks`, `Incidents`, `Trips`, `ServiceKinds`, `ServiceSchedules`, `DiverSettings`; four new tables; `currentSchemaVersion`; `migrationVersions`; `onUpgrade`; `beforeOpen`; `_assertServiceLedgerSchema`; `kSeedBuiltInServiceKindsSql`)
- Test: `test/core/database/migration_v202_equipment_condition_test.dart`
- Test: `test/core/database/migration_v160_service_category_test.dart` (unchanged, must still pass)

**Interfaces:**
- Produces: columns `equipment.parent_equipment_id`, `dive_tanks.regulator_equipment_id`, `incidents.equipment_id`, `trips.expected_dives`, `trips.expected_runtime_minutes`, `service_kinds.exposure_intervals`, `service_schedules.exposure_intervals`, `diver_settings.cold_water_threshold_c`, `diver_settings.deep_dive_threshold_m`, `diver_settings.high_o2_threshold_percent`; tables `dive_sensor_summaries` (row class `DiveSensorSummaryRow`), `equipment_observations` (`EquipmentObservationRow`), `equipment_findings` (`EquipmentFindingRow`), `equipment_condition_reviews` (`EquipmentConditionReviewRow`); Drift getters named in camelCase after each column.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/migration_v202_equipment_condition_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

/// v202: equipment condition intelligence, phase 1. Additive columns on six
/// tables, four new tables, and a one-time backfill of exposure defaults on
/// the built-in service kinds.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Every table the v202 block or the beforeOpen seed touches, as a v200
/// database would carry them.
void _createV200Fixture(dynamic rawDb) {
  rawDb.execute('PRAGMA user_version = 200');
  rawDb.execute('''
    CREATE TABLE divers (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
  ''');
  rawDb.execute('''
    CREATE TABLE equipment (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      purchase_currency TEXT NOT NULL DEFAULT 'USD',
      notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE dive_tanks (
      id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, equipment_id TEXT,
      o2_percent REAL NOT NULL DEFAULT 21.0, he_percent REAL NOT NULL DEFAULT 0.0,
      tank_order INTEGER NOT NULL DEFAULT 0,
      tank_role TEXT NOT NULL DEFAULT 'backGas', transmitter_serial TEXT,
      computer_id TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE incidents (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, dive_id TEXT,
      occurred_at INTEGER NOT NULL, category TEXT NOT NULL,
      severity TEXT NOT NULL, narrative TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE trips (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      start_date INTEGER NOT NULL, end_date INTEGER NOT NULL,
      trip_type TEXT NOT NULL DEFAULT 'shore', notes TEXT NOT NULL DEFAULT '',
      is_shared INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE service_kinds (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
      applicable_types TEXT NOT NULL DEFAULT '[]',
      default_interval_days INTEGER, default_interval_dives INTEGER,
      default_interval_hours REAL, default_cost REAL, default_currency TEXT,
      default_category TEXT, auto_attach INTEGER NOT NULL DEFAULT 0,
      is_built_in INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE service_schedules (
      id TEXT NOT NULL PRIMARY KEY, equipment_id TEXT NOT NULL,
      service_kind_id TEXT NOT NULL, interval_days INTEGER,
      interval_dives INTEGER, interval_hours REAL, default_cost REAL,
      default_currency TEXT, anchor_date INTEGER,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
  ''');
  rawDb.execute('''
    CREATE TABLE diver_settings (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
  ''');
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, default_interval_dives, is_built_in, "
    "created_at, updated_at) VALUES ('regulator-service', 'Regulator service', "
    "'[\"regulator\"]', 365, 100, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, is_built_in, created_at, updated_at) VALUES "
    "('o2-clean', 'O2 clean', '[\"tank\"]', 365, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, applicable_types, "
    "default_interval_days, is_built_in, created_at, updated_at) VALUES "
    "('transmitter-battery', 'Transmitter battery', '[\"transmitter\"]', "
    "365, 1, 1, 1)",
  );
  rawDb.execute(
    "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
    "updated_at) VALUES ('disinfect', 'Disinfect', 0, 1, 1)",
  );
}

void main() {
  test('v202 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 202);
    expect(AppDatabase.migrationVersions, contains(202));
  });

  test('a fresh database has every v202 column and table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columns(db, 'equipment'), contains('parent_equipment_id'));
    expect(
      await _columns(db, 'dive_tanks'),
      contains('regulator_equipment_id'),
    );
    expect(await _columns(db, 'incidents'), contains('equipment_id'));
    expect(
      await _columns(db, 'trips'),
      containsAll(['expected_dives', 'expected_runtime_minutes']),
    );
    expect(await _columns(db, 'service_kinds'), contains('exposure_intervals'));
    expect(
      await _columns(db, 'service_schedules'),
      contains('exposure_intervals'),
    );
    expect(
      await _columns(db, 'diver_settings'),
      containsAll([
        'cold_water_threshold_c',
        'deep_dive_threshold_m',
        'high_o2_threshold_percent',
      ]),
    );
    for (final table in [
      'dive_sensor_summaries',
      'equipment_observations',
      'equipment_findings',
      'equipment_condition_reviews',
    ]) {
      expect(await _tableExists(db, table), isTrue, reason: table);
    }
  });

  test('a fresh database seeds exposure defaults on built-in kinds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    Future<String> col(String id, String column) async => (await db
            .customSelect(
              'SELECT $column AS v FROM service_kinds WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle())
        .read<String>('v');

    expect(
      decodeExposureIntervals(await col('regulator-service', 'exposure_intervals')),
      {ExposureUnit.coldDives: 50.0},
    );
    expect(
      decodeExposureIntervals(await col('o2-clean', 'exposure_intervals')),
      {ExposureUnit.o2Hours: 50.0},
    );
    expect(
      decodeExposureIntervals(await col('drysuit-seals', 'exposure_intervals')),
      {ExposureUnit.saltHours: 200.0},
    );
    expect(await col('o2-clean', 'applicable_types'), '["tank","regulator"]');
    expect(
      await col('computer-battery', 'applicable_types'),
      '["computer","battery"]',
    );
    expect(
      await col('transmitter-battery', 'applicable_types'),
      '["transmitter","battery"]',
    );
    expect(
      await col('o2-cell-replacement', 'applicable_types'),
      '["rebreather","o2Cell"]',
    );
    final hours = await db
        .customSelect(
          "SELECT default_interval_hours AS h FROM service_kinds "
          "WHERE id = 'transmitter-battery'",
        )
        .getSingle();
    expect(hours.read<double>('h'), 250.0);
  });

  test('a database stranded before v202 gains the columns and the backfill',
      () async {
    final db = AppDatabase(NativeDatabase.memory(setup: _createV200Fixture));
    addTearDown(db.close);

    expect(await _columns(db, 'equipment'), contains('parent_equipment_id'));
    expect(await _columns(db, 'service_kinds'), contains('exposure_intervals'));
    expect(await _tableExists(db, 'equipment_findings'), isTrue);

    Future<String> col(String id, String column) async => (await db
            .customSelect(
              'SELECT $column AS v FROM service_kinds WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingle())
        .read<String>('v');

    expect(
      decodeExposureIntervals(await col('regulator-service', 'exposure_intervals')),
      {ExposureUnit.coldDives: 50.0},
    );
    expect(await col('o2-clean', 'applicable_types'), '["tank","regulator"]');
    expect(
      await col('transmitter-battery', 'applicable_types'),
      '["transmitter","battery"]',
    );
    expect(
      decodeExposureIntervals(await col('disinfect', 'exposure_intervals')),
      isEmpty,
      reason: 'a custom kind gets no defaults',
    );
    // The built-in regulator row keeps its own calendar and dive intervals.
    final reg = await db
        .customSelect(
          "SELECT default_interval_days AS d, default_interval_dives AS n "
          "FROM service_kinds WHERE id = 'regulator-service'",
        )
        .getSingle();
    expect(reg.read<int>('d'), 365);
    expect(reg.read<int>('n'), 100);
  });

  test('exposure thresholds default on a settings row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'A', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO diver_settings (id, diver_id, created_at, updated_at) "
      "VALUES ('s1', 'd1', 1, 1)",
    );
    final row = await db
        .customSelect(
          'SELECT cold_water_threshold_c AS c, deep_dive_threshold_m AS d, '
          "high_o2_threshold_percent AS o FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<double>('c'), 10.0);
    expect(row.read<double>('d'), 30.0);
    expect(row.read<double>('o'), 40.0);
  });
}
```

Note the fixture's `diver_settings` table is minimal; the settings backstops are PRAGMA-guarded and add their own columns, which is exactly what they do on a real stranded database.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v202_equipment_condition_test.dart`
Expected: the version test fails with `199`; the column tests fail.

- [ ] **Step 3: Add the columns and tables**

In `class Equipment` after `customReminderDays`:

```dart
  /// v202: the item this one is installed in (an O2 cell in a rebreather, a
  /// battery in a computer). A child inherits the parent's dive links from
  /// its `installed_date` attribute. Deleting the parent orphans the child
  /// rather than deleting its history.
  TextColumn get parentEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
```

In `class DiveTanks` after `transmitterSerial`:

```dart
  /// v202: the regulator breathed from this cylinder, so high-O2 exposure
  /// reaches the regulator's service clocks. User-authored; downloads and
  /// re-parses never write it.
  TextColumn get regulatorEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
```

In `class Incidents` after `diveId`:

```dart
  /// v202: the item an equipment incident attributes to.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
```

In `class Trips` after `returnFlightAt`:

```dart
  /// v202: overrides for the scrubber trip-margin estimate (phase 4).
  IntColumn get expectedDives => integer().nullable()();
  IntColumn get expectedRuntimeMinutes => integer().nullable()();
```

In `class ServiceKinds` after `defaultIntervalHours` and in `class ServiceSchedules` after `intervalHours`:

```dart
  /// v202: JSON object of ExposureUnit name to interval for the units that
  /// have no column of their own ({"coldDives": 50}). '{}' means none.
  TextColumn get exposureIntervals =>
      text().withDefault(const Constant('{}'))();
```

In `class DiverSettings` after `noFlyPreset`:

```dart
  // v202: exposure thresholds for service clocks. Stored metric.
  RealColumn get coldWaterThresholdC =>
      real().withDefault(const Constant(10.0))();
  RealColumn get deepDiveThresholdM =>
      real().withDefault(const Constant(30.0))();
  RealColumn get highO2ThresholdPercent =>
      real().withDefault(const Constant(40.0))();
```

Four new tables, placed after `class Incidents`:

```dart
/// v202: what only a profile-blob decode can produce, computed once per dive
/// version by the sensor summary service (phase 2). Device-local, never
/// synced; a restore rebuilds it by sweep.
@DataClassName('DiveSensorSummaryRow')
class DiveSensorSummaries extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get sourceUpdatedAt => integer()();
  IntColumn get computedAt => integer()();
  RealColumn get minTemperature => real().nullable()();
  RealColumn get maxDepth => real().nullable()();
  RealColumn get scrubberConsumedMinutes => real().nullable()();
  TextColumn get cellMetrics => text().withDefault(const Constant('[]'))();
  TextColumn get transmitterGaps => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// v202: a diver's post-dive gear check-in (phase 3). Synced aggregate root.
@DataClassName('EquipmentObservationRow')
class EquipmentObservations extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  IntColumn get observedAt => integer()();
  TextColumn get status => text()(); // 'ok' | 'issue'
  TextColumn get issueTags => text().withDefault(const Constant('[]'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// v202: one condition finding per (item, rule, slot) (phase 3). Synced the
/// way dive_safety_findings is: write-once except dismissed_at.
@DataClassName('EquipmentFindingRow')
class EquipmentFindings extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  TextColumn get severity => text()();
  RealColumn get value => real().nullable()();
  TextColumn get evidence => text().withDefault(const Constant('{}'))();
  TextColumn get evidenceFingerprint => text()();
  IntColumn get engineVersion => integer()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// v202: per-item marker that the condition engine has run over the current
/// inputs (phase 3). Device-local.
@DataClassName('EquipmentConditionReviewRow')
class EquipmentConditionReviews extends Table {
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  TextColumn get inputFingerprint => text()();
  IntColumn get reviewedAt => integer()();

  @override
  Set<Column> get primaryKey => {equipmentId};
}
```

Register the four tables in the `@DriftDatabase(tables: [...])` list.

- [ ] **Step 4: Bump the version, add the block, the backstop and the helpers**

`currentSchemaVersion = 202`; append `202` to `migrationVersions`.

After the `if (from < 200) await reportProgress();` line in `onUpgrade`:

```dart
        // v202: equipment condition intelligence, phase 1. Additive columns
        // on six tables, the four condition tables, and a ONE-TIME backfill
        // of exposure defaults on the built-in kinds. The backfill is not in
        // the backstop: a diver may clear a default later.
        if (from < 202) {
          await _assertEquipmentConditionSchema();
          await _backfillBuiltInExposureDefaults();
        }
        if (from < 202) await reportProgress();
```

In `beforeOpen`, after the v200 backstop calls (`_assertTransmitterTables` and `_assertDiveTankSourceIndexColumn`):

```dart
        // v202 backstop: re-assert the condition columns and tables.
        await _assertEquipmentConditionSchema();
```

Helpers, placed after `_assertCertificationCredentialsColumn`:

```dart
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String ddl,
  ) async {
    final cols = await customSelect("PRAGMA table_info('$table')").get();
    if (cols.isEmpty) return; // partial fixture database: table absent
    if (cols.any((c) => c.read<String>('name') == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $ddl');
  }

  /// v202: the exposure_intervals map on both service ledger tables. Split
  /// out because the v122 seed (which runs in older rungs' blocks and in
  /// the backstop) names the column and must be able to assert it first.
  Future<void> _assertExposureIntervalColumns() async {
    await _addColumnIfMissing(
      'service_kinds',
      'exposure_intervals',
      "TEXT NOT NULL DEFAULT '{}'",
    );
    await _addColumnIfMissing(
      'service_schedules',
      'exposure_intervals',
      "TEXT NOT NULL DEFAULT '{}'",
    );
  }

  /// v202: equipment condition intelligence, phase 1. Idempotent; called
  /// from the v202 onUpgrade block and the beforeOpen backstop.
  Future<void> _assertEquipmentConditionSchema() async {
    await _addColumnIfMissing(
      'equipment',
      'parent_equipment_id',
      'TEXT REFERENCES equipment(id) ON DELETE SET NULL',
    );
    await _addColumnIfMissing(
      'dive_tanks',
      'regulator_equipment_id',
      'TEXT REFERENCES equipment(id) ON DELETE SET NULL',
    );
    await _addColumnIfMissing(
      'incidents',
      'equipment_id',
      'TEXT REFERENCES equipment(id) ON DELETE SET NULL',
    );
    await _addColumnIfMissing('trips', 'expected_dives', 'INTEGER');
    await _addColumnIfMissing('trips', 'expected_runtime_minutes', 'INTEGER');
    await _assertExposureIntervalColumns();
    await _addColumnIfMissing(
      'diver_settings',
      'cold_water_threshold_c',
      'REAL NOT NULL DEFAULT 10.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'deep_dive_threshold_m',
      'REAL NOT NULL DEFAULT 30.0',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'high_o2_threshold_percent',
      'REAL NOT NULL DEFAULT 40.0',
    );
    final m = createMigrator();
    await m.createTable(diveSensorSummaries);
    await m.createTable(equipmentObservations);
    await m.createTable(equipmentFindings);
    await m.createTable(equipmentConditionReviews);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_parent '
      'ON equipment(parent_equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_tanks_regulator '
      'ON dive_tanks(regulator_equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_observations_equipment '
      'ON equipment_observations(equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_observations_dive '
      'ON equipment_observations(dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_findings_equipment '
      'ON equipment_findings(equipment_id)',
    );
  }

  /// v202 one-time backfill. Keyed on built-in ids and gated on
  /// is_built_in, so a custom kind is never touched. Runs from the v202
  /// onUpgrade block ONLY (fresh installs get the same values from the seed).
  Future<void> _backfillBuiltInExposureDefaults() async {
    final cols = await customSelect(
      "PRAGMA table_info('service_kinds')",
    ).get();
    if (cols.isEmpty) return;
    await customStatement(kBackfillBuiltInExposureDefaultsSql);
  }
```

Add this constant next to `kSeedBuiltInServiceKindsSql`:

```dart
/// v202: exposure defaults for the built-in kinds on existing installs.
/// Starting points, not manufacturer figures; a schedule overrides them.
/// Held in step with the seed SQL by migration_v202_equipment_condition_test.
const String kBackfillBuiltInExposureDefaultsSql = '''
  UPDATE service_kinds SET
    exposure_intervals = CASE id
      WHEN 'regulator-service' THEN '{"coldDives":50}'
      WHEN 'o2-clean' THEN '{"o2Hours":50}'
      WHEN 'drysuit-seals' THEN '{"saltHours":200}'
      ELSE exposure_intervals END,
    applicable_types = CASE id
      WHEN 'o2-clean' THEN '["tank","regulator"]'
      WHEN 'computer-battery' THEN '["computer","battery"]'
      WHEN 'transmitter-battery' THEN '["transmitter","battery"]'
      WHEN 'o2-cell-replacement' THEN '["rebreather","o2Cell"]'
      ELSE applicable_types END,
    default_interval_hours = CASE id
      WHEN 'transmitter-battery' THEN 250.0
      ELSE default_interval_hours END
  WHERE is_built_in = 1
''';
```

Replace `kSeedBuiltInServiceKindsSql` with the version that carries the column (same slugs, same categories, so the v160 test still pins both):

```dart
const String kSeedBuiltInServiceKindsSql = '''
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     default_category, exposure_intervals, is_built_in, created_at,
     updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, t.hours, t.auto,
         t.category, t.exposure, 1, n.now_ms, n.now_ms
  FROM (
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, NULL AS hours, 1 AS auto,
           'inspection' AS category, '{}' AS exposure
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, NULL, 1, 'inspection', '{}'
    -- v202: O2 cleaning applies to regulators too now that a cylinder can
    -- name the regulator breathed from it; 50 high-O2 hours is a starting
    -- point, not a manufacturer figure.
    UNION ALL SELECT 'o2-clean', 'O2 clean', '["tank","regulator"]', 365,
           NULL, NULL, 0, 'cleaning', '{"o2Hours":50}'
    UNION ALL SELECT 'regulator-service', 'Regulator service',
           '["regulator"]', 365, 100, NULL, 1, 'annual', '{"coldDives":50}'
    UNION ALL SELECT 'computer-battery', 'Computer battery',
           '["computer","battery"]', 730, NULL, NULL, 1, 'replacement', '{}'
    -- v202: 250 h sits below the roughly 300 h published for common
    -- transmitters.
    UNION ALL SELECT 'transmitter-battery', 'Transmitter battery',
           '["transmitter","battery"]', 365, NULL, 250.0, 1, 'replacement',
           '{}'
    UNION ALL SELECT 'bcd-inspection', 'BCD/wing inspection', '["bcd"]',
           365, NULL, NULL, 1, 'inspection', '{}'
    UNION ALL SELECT 'drysuit-seals', 'Drysuit seals', '["drysuit"]',
           730, NULL, NULL, 0, 'repair', '{"saltHours":200}'
    -- A scrubber is consumed by loop time, not by the calendar, so this is
    -- the only built-in with an hours-only clock. 3.0 h is conservative
    -- across the 2-6 h range real units are rated for; the diver overrides
    -- it per unit via ServiceSchedule.intervalHours.
    UNION ALL SELECT 'scrubber-repack', 'Scrubber repack', '["rebreather"]',
           NULL, NULL, 3.0, 1, 'replacement', '{}'
    UNION ALL SELECT 'o2-cell-replacement', 'O2 cell replacement',
           '["rebreather","o2Cell"]', 365, NULL, NULL, 1, 'replacement', '{}'
    UNION ALL SELECT 'rebreather-annual', 'Rebreather annual service',
           '["rebreather"]', 365, NULL, NULL, 1, 'annual', '{}'
    UNION ALL SELECT 'general-service', 'General service', '[]',
           NULL, NULL, NULL, 0, 'annual', '{}'
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
```

In `_assertServiceLedgerSchema`, immediately before the `// Seed built-ins only when the divers FK parent exists` comment, add:

```dart
    // v202: the seed names exposure_intervals, so the column must exist
    // before it runs, including on the v122 rung of an old database.
    await _assertExposureIntervalColumns();
```

- [ ] **Step 5: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs` (via a scratchpad script if the harness refuses the bare command).
Expected: `database.g.dart` regenerated without errors.

- [ ] **Step 6: Run the rung tests and the ledger tests**

Run: `flutter test test/core/database/migration_v202_equipment_condition_test.dart test/core/database/migration_v160_service_category_test.dart test/core/database/migration_v122_service_ledger_test.dart test/features/equipment/data`
Expected: PASS. (If `migration_v122_service_ledger_test.dart` does not exist, run `flutter test test/core/database` instead.)

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v202_equipment_condition_test.dart
git commit -m "feat(db): v202 equipment condition schema and exposure defaults"
```

---

### Task 7: Repository mappers for the interval map and the parent link

**Files:**
- Modify: `lib/features/equipment/data/repositories/service_kind_repository.dart` (`createKind`, `updateKind`, `_mapRow`)
- Modify: `lib/features/equipment/data/repositories/service_schedule_repository.dart` (`createSchedule`, `updateSchedule`, `_mapRow`)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (create companion at line 227, update companion at 358, raw mapper at 611, typed mapper at 824)
- Test: `test/features/equipment/data/exposure_interval_persistence_test.dart`

**Interfaces:**
- Produces: `EquipmentItem.parentEquipmentId` (`String?`, constructor, `copyWith`, `props`); `EquipmentItem.installedDate` (`DateTime?` from the `installed_date` attribute); `EquipmentRepository.getChildEquipment(String parentId)` returning active children.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/exposure_interval_persistence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('a custom kind round-trips its exposure map', () async {
    final repo = ServiceKindRepository();
    final now = DateTime.now();
    final created = await repo.createKind(
      ServiceKind(
        id: '',
        name: 'Seal check',
        exposureIntervals: const {ExposureUnit.saltHours: 120},
        createdAt: now,
        updatedAt: now,
      ),
    );
    final loaded = await repo.getKindById(created.id);
    expect(loaded!.exposureIntervals, {ExposureUnit.saltHours: 120.0});

    await repo.updateKind(
      loaded.copyWith(exposureIntervals: const {ExposureUnit.coldDives: 10}),
    );
    final updated = await repo.getKindById(created.id);
    expect(updated!.exposureIntervals, {ExposureUnit.coldDives: 10.0});
  });

  test('built-in kinds surface their seeded defaults', () async {
    final reg = await ServiceKindRepository().getKindById('regulator-service');
    expect(reg!.exposureIntervals, {ExposureUnit.coldDives: 50.0});
    expect(reg.applicableTypes, [EquipmentType.regulator]);
    final o2 = await ServiceKindRepository().getKindById('o2-clean');
    expect(o2!.applicableTypes, [EquipmentType.tank, EquipmentType.regulator]);
  });

  test('a schedule round-trips its exposure map', () async {
    final equipmentRepo = EquipmentRepository();
    final reg = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final schedules = await scheduleRepo.getSchedulesForEquipment(reg.id);
    final regService = schedules.firstWhere(
      (s) => s.serviceKindId == 'regulator-service',
    );
    expect(regService.exposureIntervals, isEmpty);
    await scheduleRepo.updateSchedule(
      regService.copyWith(
        exposureIntervals: const {ExposureUnit.coldDives: 25},
      ),
    );
    final reloaded = await scheduleRepo.getSchedulesForEquipment(reg.id);
    expect(
      reloaded
          .firstWhere((s) => s.serviceKindId == 'regulator-service')
          .exposureIntervals,
      {ExposureUnit.coldDives: 25.0},
    );
  });

  test('a child item keeps its parent link and install date', () async {
    final repo = EquipmentRepository();
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    final installed = DateTime(2026, 3, 1);
    final cell = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Cell 1',
        type: EquipmentType.o2Cell,
        parentEquipmentId: unit.id,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'installed_date',
            valueNum: installed.millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
    );
    final loaded = await repo.getEquipmentById(cell.id);
    expect(loaded!.parentEquipmentId, unit.id);
    expect(loaded.installedDate, installed);

    final children = await repo.getChildEquipment(unit.id);
    expect(children.map((c) => c.id), [cell.id]);

    await repo.updateEquipment(loaded.copyWith(clearParentEquipmentId: true));
    expect((await repo.getEquipmentById(cell.id))!.parentEquipmentId, isNull);
  });
}
```

If `saveAttributes` rewrites the attribute's `equipmentId` from the created id, the empty `equipmentId: ''` above is fine; if the test fails on that, build the attribute after creation with `EquipmentAttribute.curated(equipmentId: cell.id, ...)` and call `repo.updateEquipment`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/exposure_interval_persistence_test.dart`
Expected: compile errors (`parentEquipmentId`, `getChildEquipment`), then map assertions fail.

- [ ] **Step 3: Implement the mappers**

`service_kind_repository.dart`: import `exposure_unit.dart`; in both `ServiceKindsCompanion(` builders add `exposureIntervals: Value(encodeExposureIntervals(kind.exposureIntervals)),` after `defaultIntervalHours`; in `_mapRow` add `exposureIntervals: decodeExposureIntervals(row.exposureIntervals),`.

`service_schedule_repository.dart`: the same three edits with `schedule.exposureIntervals` and `row.exposureIntervals`.

`equipment_item.dart`: add the field, constructor parameter, `copyWith` handling with a clear flag, `props` entry and the getter:

```dart
  /// The item this one is installed in (v202). Null for a standalone item.
  final String? parentEquipmentId;
```

Constructor: `this.parentEquipmentId,` after `this.customReminderDays,`. In `copyWith` add parameters `String? parentEquipmentId,` and `bool clearParentEquipmentId = false,` and the assignment `parentEquipmentId: clearParentEquipmentId ? null : (parentEquipmentId ?? this.parentEquipmentId),`. Add `parentEquipmentId,` to `props`. Getter next to `weightKg`:

```dart
  /// When a child item was installed in its parent; the parent's dives on or
  /// after this date count for the child.
  DateTime? get installedDate {
    final ms = attrNum(EquipmentAttrKeys.installedDate);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms.round());
  }
```

`equipment_repository_impl.dart`: in the create companion (line 227 block) add `parentEquipmentId: Value(equipment.parentEquipmentId),`; in the update companion (line 358 block) the same; in the raw-row mapper (line 611 block) add `parentEquipmentId: row.data['parent_equipment_id'] as String?,`; in `_mapRowToEquipment` add `parentEquipmentId: row.parentEquipmentId,`. Add the method after `getEquipmentById`:

```dart
  /// Active items installed in [parentId] (O2 cells, batteries).
  Future<List<EquipmentItem>> getChildEquipment(String parentId) async {
    final rows =
        await (_db.select(_db.equipment)
              ..where(
                (t) =>
                    t.parentEquipmentId.equals(parentId) &
                    t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return _mapRowsWithAttributes(rows);
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/equipment/data`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/data/repositories/service_kind_repository.dart lib/features/equipment/data/repositories/service_schedule_repository.dart lib/features/equipment/domain/entities/equipment_item.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart test/features/equipment/data/exposure_interval_persistence_test.dart
git commit -m "feat(equipment): persist exposure intervals and the parent link"
```

---

### Task 8: A dive tank names the regulator it was breathed from

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`DiveTank`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (companions at ~1414, ~1656, ~1688, ~5831; mappers at ~3578, ~3973)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart:364`
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart:310` (preserve through edits)
- Test: `test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart`

**Interfaces:**
- Produces: `DiveTank.regulatorEquipmentId` (`String?`), `copyWith(regulatorEquipmentId:, clearRegulatorEquipmentId:)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('the regulator link survives create, read and update', () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    final repo = DiveRepository();
    final dive = createTestDiveWithBottomTime(id: 'd1').copyWith(
      tanks: [
        DiveTank(id: 't1', gasMix: const GasMix(o2: 50), regulatorEquipmentId: reg.id),
      ],
    );
    await repo.createDive(dive);

    final loaded = await repo.getDiveById('d1');
    expect(loaded!.tanks.single.regulatorEquipmentId, reg.id);

    // An edit that rebuilds the tank keeps the link.
    await repo.updateDive(
      loaded.copyWith(
        tanks: [loaded.tanks.single.copyWith(startPressure: 200)],
      ),
    );
    expect(
      (await repo.getDiveById('d1'))!.tanks.single.regulatorEquipmentId,
      reg.id,
    );

    // And an explicit clear removes it.
    final cleared = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      cleared.copyWith(
        tanks: [cleared.tanks.single.copyWith(clearRegulatorEquipmentId: true)],
      ),
    );
    expect(
      (await repo.getDiveById('d1'))!.tanks.single.regulatorEquipmentId,
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart`
Expected: compile error, `regulatorEquipmentId` is not a named parameter.

- [ ] **Step 3: Thread the field through**

`dive.dart`, in `DiveTank`, after `transmitterSerial`:

```dart
  /// The regulator this cylinder was breathed through (v202), so high-O2
  /// contact reaches the regulator's service clocks. User-authored: the
  /// tank editor sets it and downloads never touch it.
  final String? regulatorEquipmentId;
```

Constructor: `this.regulatorEquipmentId,` after `this.transmitterSerial,`. `copyWith`: parameters `String? regulatorEquipmentId,` and `bool clearRegulatorEquipmentId = false,`; assignment `regulatorEquipmentId: clearRegulatorEquipmentId ? null : (regulatorEquipmentId ?? this.regulatorEquipmentId),`. Add `regulatorEquipmentId,` to `props`.

`dive_repository_impl.dart`: in every `DiveTanksCompanion(` that writes `transmitterSerial: Value(tank.transmitterSerial),` (the create insert near line 1414, the new-tank insert near 1688, the helper near 5831) add `regulatorEquipmentId: Value(tank.regulatorEquipmentId),`. In the update companion near line 1656 (the one whose comment says computerId and transmitterSerial are deliberately not written) add `regulatorEquipmentId: Value(tank.regulatorEquipmentId),` with the comment `// User-authored, unlike the two above, so an edit does write it.`. In both row-to-entity mappers (near 3578 and 3973) add `regulatorEquipmentId: t.regulatorEquipmentId,`.

`bulk_dive_edit_service.dart:364`: add `regulatorEquipmentId: r.regulatorEquipmentId,` after `transmitterSerial: r.transmitterSerial,`.

`tank_editor.dart`, in `_notifyChange` after `transmitterSerial: widget.tank.transmitterSerial,`: add `regulatorEquipmentId: widget.tank.regulatorEquipmentId,` (Task 14 replaces this with the picker's value).

Search for any other `DiveTank(` constructor call that copies `transmitterSerial` field by field (`grep -rn "transmitterSerial: " lib --include='*.dart'`) and add the new field beside it where the source object carries one; the UDDF importers and the download path do not, and stay as they are.

- [ ] **Step 4: Run the test and the dive log data tests**

Run: `flutter test test/features/dive_log/data test/features/dive_log/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart lib/features/dive_log/presentation/widgets/tank_editor.dart test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart
git commit -m "feat(dive-log): dive tanks name the regulator breathed from them"
```

---

### Task 9: One exposure query replaces the usage query

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (replace `getUsageSamplesForEquipment`)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart:635-637`
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart:109-111`
- Modify: `test/features/equipment/data/service_schedule_repository_test.dart:119,173,175` (rename the call)
- Test: `test/features/equipment/data/exposure_samples_query_test.dart`

**Interfaces:**
- Produces: `Future<List<EquipmentExposureSample>> getExposureSamplesForEquipment(String equipmentId, {String? parentEquipmentId, DateTime? installedSince, bool rebreatherContact = false, DateTime? since})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/data/exposure_samples_query_test.dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    required int dateMs,
    int runtime = 3600,
    String mode = 'oc',
    String? waterType,
    double? maxDepth,
    double? waterTemp,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: dateMs,
        ).copyWith(
          runtime: Value(runtime),
          diveMode: Value(mode),
          waterType: Value(waterType),
          maxDepth: Value(maxDepth),
          waterTemp: Value(waterTemp),
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  Future<void> tank(
    String id,
    String diveId, {
    double o2 = 21,
    String role = 'backGas',
    String? equipmentId,
    String? regulatorId,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          o2Percent: Value(o2),
          tankRole: Value(role),
          equipmentId: Value(equipmentId),
          regulatorEquipmentId: Value(regulatorId),
        ),
      );

  final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
  final t2 = DateTime.utc(2026, 2, 10).millisecondsSinceEpoch;
  final t3 = DateTime.utc(2026, 3, 10).millisecondsSinceEpoch;

  test('dive header fields ride on the sample', () async {
    final mask = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Mask', type: EquipmentType.mask),
    );
    await insertDive(
      'd1',
      dateMs: t1,
      runtime: 2700,
      mode: 'ccr',
      waterType: 'salt',
      maxDepth: 42.5,
      waterTemp: 7.0,
    );
    await link('d1', mask.id);

    final s = (await repo.getExposureSamplesForEquipment(mask.id)).single;
    expect(s.date, DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true));
    expect(s.durationSeconds, 2700);
    expect(s.diveMode, DiveMode.ccr);
    expect(s.waterType, WaterType.salt);
    expect(s.maxDepth, 42.5);
    expect(s.minTemperature, 7.0);
    expect(s.contactO2Fraction, isNull, reason: 'a mask touches no gas');
  });

  test('a tank item, a regulator and a rebreather each see their gas', () async {
    final cylinder = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
    );
    final reg = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    await insertDive('d1', dateMs: t1, mode: 'ccr');
    await tank('t-back', 'd1', o2: 21, equipmentId: cylinder.id, regulatorId: reg.id);
    await tank('t-deco', 'd1', o2: 80, regulatorId: reg.id);
    await tank('t-dil', 'd1', o2: 18, role: 'diluent');
    await tank('t-o2', 'd1', o2: 100, role: 'oxygenSupply');
    await link('d1', unit.id);

    expect(
      (await repo.getExposureSamplesForEquipment(cylinder.id)).single.contactO2Fraction,
      closeTo(0.21, 1e-9),
    );
    expect(
      (await repo.getExposureSamplesForEquipment(reg.id)).single.contactO2Fraction,
      closeTo(0.80, 1e-9),
      reason: 'the regulator takes the max over the cylinders naming it',
    );
    expect(
      (await repo.getExposureSamplesForEquipment(unit.id, rebreatherContact: true))
          .single
          .contactO2Fraction,
      closeTo(1.0, 1e-9),
    );
  });

  test('a CCR dive with no supply cylinders still counts as O2 contact', () async {
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    await insertDive('d1', dateMs: t1, mode: 'ccr');
    await link('d1', unit.id);
    expect(
      (await repo.getExposureSamplesForEquipment(unit.id, rebreatherContact: true))
          .single
          .contactO2Fraction,
      1.0,
    );
    await insertDive('d2', dateMs: t2, mode: 'oc');
    await link('d2', unit.id);
    final byDate = await repo.getExposureSamplesForEquipment(unit.id, rebreatherContact: true);
    expect(byDate.last.contactO2Fraction, isNull);
  });

  test('a child inherits the parent dives from its install date', () async {
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    await insertDive('d1', dateMs: t1);
    await insertDive('d2', dateMs: t2);
    await insertDive('d3', dateMs: t3);
    for (final d in ['d1', 'd2', 'd3']) {
      await link(d, unit.id);
    }
    final samples = await repo.getExposureSamplesForEquipment(
      'cell-1',
      parentEquipmentId: unit.id,
      installedSince: DateTime.fromMillisecondsSinceEpoch(t2, isUtc: true),
    );
    expect(samples.map((s) => s.date.millisecondsSinceEpoch), [t2, t3]);
  });

  test('a dive linked three ways is one sample', () async {
    final cylinder = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
    );
    await insertDive('d1', dateMs: t1);
    await link('d1', cylinder.id);
    await tank('t1', 'd1', o2: 32, equipmentId: cylinder.id);
    await tank('t2', 'd1', o2: 36, regulatorId: cylinder.id);
    final samples = await repo.getExposureSamplesForEquipment(cylinder.id);
    expect(samples, hasLength(1));
    expect(samples.single.contactO2Fraction, closeTo(0.36, 1e-9));
  });

  test('the samples come from exactly one statement', () async {
    await tearDownTestDatabase();
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
    DatabaseService.instance.setTestDatabase(db);
    repo = EquipmentRepository();
    final reg = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await insertDive('d1', dateMs: t1);
    await tank('t1', 'd1', regulatorId: reg.id);

    final logged = <String>[];
    await runZoned(
      () => repo.getExposureSamplesForEquipment(
        reg.id,
        parentEquipmentId: 'none',
        rebreatherContact: true,
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    expect(logged.where((l) => l.contains('SELECT')), hasLength(1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/exposure_samples_query_test.dart`
Expected: compile error, `getExposureSamplesForEquipment` undefined.

- [ ] **Step 3: Replace the query**

Replace `getUsageSamplesForEquipment` in `equipment_repository_impl.dart` with:

```dart
  /// Every dive this item was on, with what it was exposed to. One SQL union
  /// over the four link paths (junction, cylinder, regulator, parent),
  /// left-joined to the sensor summary so profile extremes win over the dive
  /// header when a summary exists.
  ///
  /// [parentEquipmentId] and [installedSince] make a child inherit its
  /// parent's dives from its install date. [rebreatherContact] enables the
  /// diluent and oxygen-supply cylinder path and the CCR fallback (a CCR
  /// dive with no supply cylinder recorded is still 100 percent O2 contact
  /// for the unit).
  ///
  /// Deliberately does NOT apply DiveStatsScope. A dive the diver excluded
  /// from statistics still physically happened: it cycled this gear and put
  /// hours on it. Suppressing it here would push a real service interval
  /// later than it should be, a safety-relevant error rather than a cosmetic
  /// one. Do not "fix" this.
  // stats-scope-exempt: gear wear is physical, not descriptive
  Future<List<EquipmentExposureSample>> getExposureSamplesForEquipment(
    String equipmentId, {
    String? parentEquipmentId,
    DateTime? installedSince,
    bool rebreatherContact = false,
    DateTime? since,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT d.dive_date_time AS date_ms,
               COALESCE(d.runtime, d.bottom_time, 0) AS duration_sec,
               d.dive_mode AS dive_mode,
               d.water_type AS water_type,
               COALESCE(s.max_depth, d.max_depth) AS max_depth,
               COALESCE(s.min_temperature, d.water_temp) AS min_temp,
               MAX(je.contact_o2) AS contact_o2
        FROM (
          SELECT dive_id, NULL AS contact_o2, 0 AS via_parent
            FROM dive_equipment WHERE equipment_id = ?1
          UNION ALL
          SELECT dive_id, o2_percent, 0 FROM dive_tanks
            WHERE equipment_id = ?1 OR regulator_equipment_id = ?1
          UNION ALL
          SELECT de.dive_id, t.o2_percent, 0
            FROM dive_equipment de
            JOIN dive_tanks t ON t.dive_id = de.dive_id
              AND t.tank_role IN ('diluent', 'oxygenSupply')
            WHERE de.equipment_id = ?1 AND ?5 = 1
          UNION ALL
          SELECT dive_id, NULL, 1 FROM dive_equipment WHERE equipment_id = ?2
          UNION ALL
          SELECT dive_id, o2_percent, 1 FROM dive_tanks
            WHERE equipment_id = ?2 OR regulator_equipment_id = ?2
          UNION ALL
          SELECT de.dive_id, t.o2_percent, 1
            FROM dive_equipment de
            JOIN dive_tanks t ON t.dive_id = de.dive_id
              AND t.tank_role IN ('diluent', 'oxygenSupply')
            WHERE de.equipment_id = ?2 AND ?5 = 1
        ) je
        JOIN dives d ON d.id = je.dive_id
        LEFT JOIN dive_sensor_summaries s ON s.dive_id = d.id
        WHERE (je.via_parent = 0 OR ?3 IS NULL OR d.dive_date_time >= ?3)
          AND (?4 IS NULL OR d.dive_date_time >= ?4)
        GROUP BY d.id
        ORDER BY d.dive_date_time
      ''',
            variables: [
              Variable.withString(equipmentId),
              // An empty string never matches an id, so "no parent" needs
              // no second query shape.
              Variable.withString(parentEquipmentId ?? ''),
              Variable(installedSince?.millisecondsSinceEpoch),
              Variable(since?.millisecondsSinceEpoch),
              Variable.withInt(rebreatherContact ? 1 : 0),
            ],
          )
          .get();
      return rows.map((r) {
        final mode = DiveMode.values.firstWhere(
          (m) => m.name == r.data['dive_mode'],
          orElse: () => DiveMode.oc,
        );
        final waterName = r.data['water_type'] as String?;
        final water = waterName == null
            ? null
            : WaterType.values
                  .where((w) => w.name == waterName)
                  .firstOrNull;
        final o2Percent = (r.data['contact_o2'] as num?)?.toDouble();
        final contact = o2Percent != null
            ? o2Percent / 100.0
            : (rebreatherContact && mode == DiveMode.ccr ? 1.0 : null);
        return EquipmentExposureSample(
          // dives.dive_date_time is epoch millis with wall-clock-as-UTC
          // semantics (see dive_filter_sql.dart); decode with isUtc: true
          // like the other dive-date mappers so the engine's
          // date.isAfter(anchor) usage comparison is not shifted by the
          // local offset around day boundaries.
          date: DateTime.fromMillisecondsSinceEpoch(
            r.data['date_ms'] as int,
            isUtc: true,
          ),
          durationSeconds: (r.data['duration_sec'] as num).toInt(),
          diveMode: mode,
          maxDepth: (r.data['max_depth'] as num?)?.toDouble(),
          minTemperature: (r.data['min_temp'] as num?)?.toDouble(),
          waterType: water,
          contactO2Fraction: contact,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get exposure samples for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Imports: `package:submersion/core/constants/enums.dart` is already imported (it provides `EquipmentType`); `firstOrNull` needs `package:collection/collection.dart` unless the project's Dart SDK exposes it on `Iterable` (Dart 3 does; if the analyzer complains, add the collection import).

Update the two callers to the new name (`getExposureSamplesForEquipment(item.id)`; Task 11 adds the extra arguments) and rename the three calls in `service_schedule_repository_test.dart`. Delete the old method.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/equipment test/features/notifications`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/notifications/data/services/notification_scheduler.dart test/features/equipment/data/service_schedule_repository_test.dart test/features/equipment/data/exposure_samples_query_test.dart
git commit -m "feat(equipment): one exposure query over every link path"
```

---

### Task 10: Exposure thresholds in diver settings

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` fields near line 233, defaults near 546, `copyWith` near 715 and 857, setters near 1578)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (three mapping sites near lines 122, 292, 512)
- Modify: `lib/core/services/sync/sync_data_serializer.dart:6454` (defaults map)
- Create: `lib/features/equipment/presentation/providers/exposure_thresholds_provider.dart`
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier` implements `SettingsNotifier`, so it must gain the three setters or every widget test stops compiling)
- Test: `test/features/settings/data/repositories/diver_settings_repository_exposure_test.dart`, `test/features/equipment/presentation/providers/exposure_thresholds_provider_test.dart`

**Interfaces:**
- Produces: `AppSettings.coldWaterThresholdC` (double, 10.0), `AppSettings.deepDiveThresholdM` (30.0), `AppSettings.highO2ThresholdPercent` (40.0); `SettingsNotifier.setColdWaterThresholdC(double)`, `setDeepDiveThresholdM(double)`, `setHighO2ThresholdPercent(double)`; `ExposureThresholds exposureThresholdsFromSettings(AppSettings)`; `exposureThresholdsProvider` (`Provider<ExposureThresholds>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/data/repositories/diver_settings_repository_exposure_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiverSettingsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverSettingsRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  test('defaults are 10 C, 30 m and 40 percent', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.coldWaterThresholdC, 10.0);
    expect(loaded.deepDiveThresholdM, 30.0);
    expect(loaded.highO2ThresholdPercent, 40.0);
  });

  test('thresholds round-trip through update', () async {
    await repository.createSettingsForDiver('d1');
    await repository.updateSettingsForDiver(
      'd1',
      const AppSettings(
        coldWaterThresholdC: 12.5,
        deepDiveThresholdM: 40,
        highO2ThresholdPercent: 32,
      ),
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.coldWaterThresholdC, 12.5);
    expect(loaded.deepDiveThresholdM, 40.0);
    expect(loaded.highO2ThresholdPercent, 32.0);
  });
}
```

```dart
// test/features/equipment/presentation/providers/exposure_thresholds_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('settings map to thresholds with O2 as a fraction', () {
    const settings = AppSettings(
      coldWaterThresholdC: 8,
      deepDiveThresholdM: 25,
      highO2ThresholdPercent: 32,
    );
    expect(
      exposureThresholdsFromSettings(settings),
      const ExposureThresholds(coldWaterC: 8, deepDiveM: 25, highO2Fraction: 0.32),
    );
  });

  test('default settings give the built-in thresholds', () {
    expect(
      exposureThresholdsFromSettings(const AppSettings()),
      ExposureThresholds.defaults,
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_exposure_test.dart test/features/equipment/presentation/providers/exposure_thresholds_provider_test.dart`
Expected: compile errors on the new named parameters and the missing provider file.

- [ ] **Step 3: Add the settings fields, persistence and provider**

`settings_providers.dart`, `AppSettings`: after `final NoFlyPreset noFlyPreset;` add

```dart
  /// Exposure thresholds for service clocks (v202), stored metric.
  final double coldWaterThresholdC;
  final double deepDiveThresholdM;
  final double highO2ThresholdPercent;
```

Constructor defaults after `this.noFlyPreset = NoFlyPreset.standard,`:

```dart
    this.coldWaterThresholdC = 10.0,
    this.deepDiveThresholdM = 30.0,
    this.highO2ThresholdPercent = 40.0,
```

`copyWith` parameters after `NoFlyPreset? noFlyPreset,`:

```dart
    double? coldWaterThresholdC,
    double? deepDiveThresholdM,
    double? highO2ThresholdPercent,
```

and assignments after `noFlyPreset: noFlyPreset ?? this.noFlyPreset,`:

```dart
      coldWaterThresholdC: coldWaterThresholdC ?? this.coldWaterThresholdC,
      deepDiveThresholdM: deepDiveThresholdM ?? this.deepDiveThresholdM,
      highO2ThresholdPercent:
          highO2ThresholdPercent ?? this.highO2ThresholdPercent,
```

Setters in `SettingsNotifier` after `setSafetyReviewEnabled`:

```dart
  Future<void> setColdWaterThresholdC(double value) async {
    state = state.copyWith(coldWaterThresholdC: value);
    await _saveSettings();
  }

  Future<void> setDeepDiveThresholdM(double value) async {
    state = state.copyWith(deepDiveThresholdM: value);
    await _saveSettings();
  }

  Future<void> setHighO2ThresholdPercent(double value) async {
    state = state.copyWith(highO2ThresholdPercent: value);
    await _saveSettings();
  }
```

`test/helpers/mock_providers.dart`, in `MockSettingsNotifier` after `setSafetyReviewEnabled`:

```dart
  @override
  Future<void> setColdWaterThresholdC(double value) async =>
      state = state.copyWith(coldWaterThresholdC: value);
  @override
  Future<void> setDeepDiveThresholdM(double value) async =>
      state = state.copyWith(deepDiveThresholdM: value);
  @override
  Future<void> setHighO2ThresholdPercent(double value) async =>
      state = state.copyWith(highO2ThresholdPercent: value);
```

`diver_settings_repository.dart`: at the create mapping (near line 122, after `noFlyPreset: Value(s.noFlyPreset.dbValue),`) add

```dart
              coldWaterThresholdC: Value(s.coldWaterThresholdC),
              deepDiveThresholdM: Value(s.deepDiveThresholdM),
              highO2ThresholdPercent: Value(s.highO2ThresholdPercent),
```

the same three lines with `settings.` at the update mapping (near 292), and at the row-to-settings mapping (near 512, after `noFlyPreset: NoFlyPreset.fromDbValue(row.noFlyPreset),`):

```dart
      coldWaterThresholdC: row.coldWaterThresholdC,
      deepDiveThresholdM: row.deepDiveThresholdM,
      highO2ThresholdPercent: row.highO2ThresholdPercent,
```

`sync_data_serializer.dart:6454`, after `'noFlyPreset': 'standard',`:

```dart
      // v202: non-nullable; seed them so payloads predating the columns
      // hydrate instead of throwing in DiverSetting.fromJson.
      'coldWaterThresholdC': 10.0,
      'deepDiveThresholdM': 30.0,
      'highO2ThresholdPercent': 40.0,
```

New provider file:

```dart
// lib/features/equipment/presentation/providers/exposure_thresholds_provider.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's exposure thresholds, in storage units. Shared by the clock
/// providers and the notification scheduler so both classify alike.
ExposureThresholds exposureThresholdsFromSettings(AppSettings s) =>
    ExposureThresholds(
      coldWaterC: s.coldWaterThresholdC,
      deepDiveM: s.deepDiveThresholdM,
      highO2Fraction: s.highO2ThresholdPercent / 100.0,
    );

final exposureThresholdsProvider = Provider<ExposureThresholds>((ref) {
  // A record selector keeps the provider from rebuilding on unrelated
  // settings writes.
  final (cold, deep, o2) = ref.watch(
    settingsProvider.select(
      (s) => (
        s.coldWaterThresholdC,
        s.deepDiveThresholdM,
        s.highO2ThresholdPercent,
      ),
    ),
  );
  return ExposureThresholds(
    coldWaterC: cold,
    deepDiveM: deep,
    highO2Fraction: o2 / 100.0,
  );
});
```

- [ ] **Step 4: Run the tests plus the settings suite**

Run: `flutter test test/features/settings test/features/equipment/presentation/providers/exposure_thresholds_provider_test.dart test/core/services/sync`
Expected: PASS. A settings census test that counts `AppSettings` fields, if one exists, lists the three new names.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/features/equipment/presentation/providers/exposure_thresholds_provider.dart test/helpers/mock_providers.dart test/features/settings/data/repositories/diver_settings_repository_exposure_test.dart test/features/equipment/presentation/providers/exposure_thresholds_provider_test.dart
git commit -m "feat(settings): exposure thresholds for service clocks"
```

---

### Task 11: Clock providers and the scheduler classify with the diver's thresholds

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (`_evaluateClocksFor`, `activeEquipmentClocksProvider`)
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart` (`_evaluateClocks`)
- Test: `test/features/equipment/presentation/providers/exposure_clock_providers_test.dart`

**Interfaces:**
- Consumes: `getExposureSamplesForEquipment`, `getChildEquipment`, `exposureThresholdsProvider`, `ExposureClassifier`.
- Produces: `_evaluateClocksFor(Ref ref, EquipmentItem item, {List<ServiceKind>? kinds, List<EquipmentItem>? siblings})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/providers/exposure_clock_providers_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  var diveIndex = 0;
  Future<void> coldDive(String id, String equipmentId, double temp) async {
    final ms = DateTime.utc(2026, 1, 1 + diveIndex++).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600), waterTemp: Value(temp)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
  }

  test('the built-in regulator clock counts cold dives', () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final schedule = (await scheduleRepo.getSchedulesForEquipment(reg.id))
        .firstWhere((s) => s.serviceKindId == 'regulator-service');
    await scheduleRepo.updateSchedule(
      schedule.copyWith(exposureIntervals: const {ExposureUnit.coldDives: 2}),
    );
    await coldDive('d1', reg.id, 4);
    await coldDive('d2', reg.id, 24);
    await coldDive('d3', reg.id, 9.5);

    final statuses = await container.read(
      serviceClockStatusesProvider(reg.id).future,
    );
    final status = statuses.firstWhere(
      (s) => s.schedule.serviceKindId == 'regulator-service',
    );
    expect(status.usageByUnit[ExposureUnit.coldDives]!.since, 2);
    expect(status.severity, ServiceClockSeverity.overdue);
  });

  test('changing the cold threshold changes the count on the next read',
      () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await coldDive('d1', reg.id, 12);
    await container.read(settingsProvider.notifier).setColdWaterThresholdC(15);
    container.invalidate(serviceClockStatusesProvider(reg.id));
    final statuses = await container.read(
      serviceClockStatusesProvider(reg.id).future,
    );
    final status = statuses.firstWhere(
      (s) => s.schedule.serviceKindId == 'regulator-service',
    );
    expect(status.usageByUnit[ExposureUnit.coldDives]!.since, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/exposure_clock_providers_test.dart`
Expected: the first test fails, `usageByUnit[coldDives]` is present (the built-in default of 50 makes the map non-null) but `since` is 0 because the provider still passes no classifier. If it passes outright, check that the query in Task 9 is in use; the threshold test must fail because no classifier reads settings yet.

- [ ] **Step 3: Wire the classifier**

In `equipment_providers.dart` add imports for `exposure_classifier.dart` and `exposure_thresholds_provider.dart`, and replace `_evaluateClocksFor` with:

```dart
/// Evaluates every enabled clock on [item] at this moment. [siblings] is the
/// active gear list when the caller already has it, so the children lookup
/// costs no query per item.
Future<List<ServiceClockStatus>> _evaluateClocksFor(
  Ref ref,
  EquipmentItem item, {
  List<ServiceKind>? kinds,
  List<EquipmentItem>? siblings,
}) async {
  final schedules = await ref
      .watch(serviceScheduleRepositoryProvider)
      .getSchedulesForEquipment(item.id);
  if (schedules.isEmpty) return const [];
  final allKinds =
      kinds ?? await ref.watch(serviceKindRepositoryProvider).getAllKinds();
  final records = await ref
      .watch(serviceRecordRepositoryProvider)
      .getRecordsForEquipment(item.id);
  final repository = ref.watch(equipmentRepositoryProvider);
  final parentId = item.parentEquipmentId;
  final parent = parentId == null
      ? null
      : siblings?.where((s) => s.id == parentId).firstOrNull ??
            await repository.getEquipmentById(parentId);
  final children = siblings != null
      ? siblings.where((s) => s.parentEquipmentId == item.id).toList()
      : await repository.getChildEquipment(item.id);
  final isRebreather =
      item.type == EquipmentType.rebreather ||
      parent?.type == EquipmentType.rebreather;
  final usage = await repository.getExposureSamplesForEquipment(
    item.id,
    parentEquipmentId: parentId,
    installedSince: item.installedDate,
    rebreatherContact: isRebreather,
  );
  final classifier = ExposureClassifier(
    thresholds: ref.watch(exposureThresholdsProvider),
    loopTimeOnly: isRebreather,
    hasBatteryChild: children.any((c) => c.type == EquipmentType.battery),
  );
  final window = await ref.watch(serviceDueSoonWindowDaysProvider.future);
  return const ServiceDueEngine().evaluate(
    schedules: schedules,
    kindsById: {for (final k in allKinds) k.id: k},
    records: records,
    usage: usage,
    classifier: classifier,
    purchaseDate: item.purchaseDate,
    equipmentCreatedAt: item.createdAt ?? DateTime.now(),
    dueSoonWindowDays: window,
    now: DateTime.now(),
  );
}
```

In `activeEquipmentClocksProvider` pass `siblings: items` to `_evaluateClocksFor`, and in `tripServiceAlertsProvider` likewise. `serviceClockStatusesProvider` keeps calling without siblings.

In `notification_scheduler.dart`, add the imports for `exposure_classifier.dart` and `exposure_thresholds_provider.dart` and replace the usage lines in `_evaluateClocks` with:

```dart
    final parentId = item.parentEquipmentId;
    final parent = parentId == null
        ? null
        : await _equipmentRepository.getEquipmentById(parentId);
    final children = await _equipmentRepository.getChildEquipment(item.id);
    final isRebreather =
        item.type == EquipmentType.rebreather ||
        parent?.type == EquipmentType.rebreather;
    final usage = await _equipmentRepository.getExposureSamplesForEquipment(
      item.id,
      parentEquipmentId: parentId,
      installedSince: item.installedDate,
      rebreatherContact: isRebreather,
    );
    final classifier = ExposureClassifier(
      thresholds: exposureThresholdsFromSettings(settings),
      loopTimeOnly: isRebreather,
      hasBatteryChild: children.any((c) => c.type == EquipmentType.battery),
    );
```

and pass `classifier: classifier,` to `evaluate`. Import `package:submersion/core/constants/enums.dart` if not already present.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/equipment/presentation/providers test/features/notifications test/features/trips test/features/dashboard`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/notifications/data/services/notification_scheduler.dart test/features/equipment/presentation/providers/exposure_clock_providers_test.dart
git commit -m "feat(equipment): clocks classify exposure with the diver's thresholds"
```

---

### Task 12: Exposure intervals in the schedule dialog, kind dialog and clock text

**Files:**
- Create: `lib/features/equipment/presentation/utils/exposure_unit_display.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_trigger_text.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_clocks_card.dart:39-52`
- Modify: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart` (`_ScheduleOverrideDialogState`)
- Modify: `lib/features/equipment/presentation/pages/service_kind_list_page.dart` (`_ServiceKindEditDialogState`)
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/widgets/service_trigger_text_exposure_test.dart`, `test/features/equipment/presentation/widgets/service_schedule_dialog_exposure_test.dart`

**Interfaces:**
- Produces: `extension ExposureUnitDisplay on ExposureUnit { String intervalLabel(AppLocalizations); String leftText(AppLocalizations, {required String remaining, required String total}); }`; `formatServiceTriggerText(..., Map<ExposureUnit, ClockUsage> usageByUnit = const {})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/presentation/widgets/service_trigger_text_exposure_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<String> format(
    WidgetTester tester, {
    required Map<ExposureUnit, ClockUsage> usageByUnit,
  }) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = formatServiceTriggerText(
              context,
              units: UnitFormatter(const AppSettings()),
              now: DateTime(2026, 7, 16),
              usageByUnit: usageByUnit,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('count units render whole numbers', (tester) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.coldDives: ClockUsage(interval: 50, since: 12),
      },
    );
    expect(text, '38 of 50 cold dives left');
  });

  testWidgets('hour units render one decimal and clamp at zero', (tester) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.saltHours: ClockUsage(interval: 200, since: 210.25),
      },
    );
    expect(text, '0.0 of 200.0 salt-water hours left');
  });

  testWidgets('legacy dives and map units join in unit order', (tester) async {
    final text = await format(
      tester,
      usageByUnit: const {
        ExposureUnit.deepCycles: ClockUsage(interval: 20, since: 5),
        ExposureUnit.dives: ClockUsage(interval: 100, since: 40),
      },
    );
    expect(text, '60 of 100 dives left · 15 of 20 deep dives left');
  });
}
```

```dart
// test/features/equipment/presentation/widgets/service_schedule_dialog_exposure_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingScheduleRepository implements ServiceScheduleRepository {
  final void Function(ServiceSchedule) onSaved;
  _RecordingScheduleRepository(this.onSaved);

  @override
  Future<void> updateSchedule(ServiceSchedule schedule) async =>
      onSaved(schedule);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('the dialog shows kind defaults as hints and saves overrides',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 3000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    ServiceSchedule? saved;
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'regulator-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'regulator-service',
      name: 'Regulator service',
      exposureIntervals: const {ExposureUnit.coldDives: 50},
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceScheduleRepositoryProvider.overrideWithValue(
            _RecordingScheduleRepository((s) => saved = s),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showScheduleOverrideDialog(
                    context,
                    ref,
                    schedule: schedule,
                    kind: kind,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Interval (cold dives)'), findsOneWidget);
    expect(find.text('Default: 50'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('service-schedule-exposure-coldDives')),
      '25',
    );
    await tester.enterText(
      find.byKey(const Key('service-schedule-exposure-saltHours')),
      '150.5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.exposureIntervals, {
      ExposureUnit.coldDives: 25.0,
      ExposureUnit.saltHours: 150.5,
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/service_trigger_text_exposure_test.dart test/features/equipment/presentation/widgets/service_schedule_dialog_exposure_test.dart`
Expected: compile error (`usageByUnit` is not a named parameter), then missing keys.

- [ ] **Step 3: Add the ARB keys**

English (insert `equipment_scheduleDialog_interval*` after `equipment_scheduleDialog_intervalHours`, and `equipment_serviceClocks_*Left` after `equipment_serviceClocks_hoursLeft` with the same String placeholder metadata as `hoursLeft`):

```json
  "equipment_scheduleDialog_intervalSaltHours": "Interval (salt-water hours)",
  "equipment_scheduleDialog_intervalColdDives": "Interval (cold dives)",
  "equipment_scheduleDialog_intervalO2Hours": "Interval (high-O2 hours)",
  "equipment_scheduleDialog_intervalDeepCycles": "Interval (deep dives)",
  "equipment_scheduleDialog_intervalCycles": "Interval (battery cycles)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} of {total} salt-water hours left",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} of {total} cold dives left",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} of {total} high-O2 hours left",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} of {total} deep dives left",
  "equipment_serviceClocks_cyclesLeft": "{remaining} of {total} battery cycles left",
```

Each `*Left` key gets a metadata block:

```json
  "@equipment_serviceClocks_saltHoursLeft": {
    "placeholders": {
      "remaining": { "type": "String" },
      "total": { "type": "String" }
    }
  },
```

Other locales: Translation Appendix. Run `flutter gen-l10n`.

- [ ] **Step 4: Create the display extension and extend the trigger text**

```dart
// lib/features/equipment/presentation/utils/exposure_unit_display.dart
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for exposure units. Both switches are exhaustive, so a
/// new unit is a compile error until its keys exist.
extension ExposureUnitDisplay on ExposureUnit {
  String intervalLabel(AppLocalizations l10n) => switch (this) {
    ExposureUnit.days => l10n.equipment_scheduleDialog_intervalDays,
    ExposureUnit.dives => l10n.equipment_scheduleDialog_intervalDives,
    ExposureUnit.hours => l10n.equipment_scheduleDialog_intervalHours,
    ExposureUnit.saltHours => l10n.equipment_scheduleDialog_intervalSaltHours,
    ExposureUnit.coldDives => l10n.equipment_scheduleDialog_intervalColdDives,
    ExposureUnit.o2Hours => l10n.equipment_scheduleDialog_intervalO2Hours,
    ExposureUnit.deepCycles =>
      l10n.equipment_scheduleDialog_intervalDeepCycles,
    ExposureUnit.cycles => l10n.equipment_scheduleDialog_intervalCycles,
  };

  /// "N of M <unit> left" for the clock line. [days] has no usage line.
  String leftText(
    AppLocalizations l10n, {
    required String remaining,
    required String total,
  }) => switch (this) {
    ExposureUnit.days => '',
    ExposureUnit.dives => l10n.equipment_serviceClocks_divesLeft(
      int.parse(remaining),
      int.parse(total),
    ),
    ExposureUnit.hours => l10n.equipment_serviceClocks_hoursLeft(
      remaining,
      total,
    ),
    ExposureUnit.saltHours => l10n.equipment_serviceClocks_saltHoursLeft(
      remaining,
      total,
    ),
    ExposureUnit.coldDives => l10n.equipment_serviceClocks_coldDivesLeft(
      remaining,
      total,
    ),
    ExposureUnit.o2Hours => l10n.equipment_serviceClocks_o2HoursLeft(
      remaining,
      total,
    ),
    ExposureUnit.deepCycles => l10n.equipment_serviceClocks_deepCyclesLeft(
      remaining,
      total,
    ),
    ExposureUnit.cycles => l10n.equipment_serviceClocks_cyclesLeft(
      remaining,
      total,
    ),
  };
}
```

(`equipment_serviceClocks_divesLeft` takes ints today; keep its signature and parse.)

Replace `formatServiceTriggerText` with:

```dart
String formatServiceTriggerText(
  BuildContext context, {
  required UnitFormatter units,
  required DateTime now,
  DateTime? dueDate,
  int? divesSinceAnchor,
  int? divesRemaining,
  double? hoursSinceAnchor,
  double? hoursRemaining,
  Map<ExposureUnit, ClockUsage> usageByUnit = const {},
}) {
  final l10n = context.l10n;
  final parts = <String>[];
  if (dueDate != null) {
    final formatted = units.formatDate(dueDate);
    parts.add(
      // Strict isAfter: at the exact due instant (now == dueDate) the engine
      // treats the date trigger as due-soon, not overdue, so render "Due
      // {date}" until now is strictly past dueDate. Matches the engine's
      // now.isAfter(dueDate) boundary.
      now.isAfter(dueDate)
          ? l10n.equipment_serviceClocks_overdueSince(formatted)
          : l10n.equipment_serviceClocks_dueOn(formatted),
    );
  }
  // The legacy arguments and the map say the same thing; fold them so a
  // caller passing either form renders one line per unit.
  final usage = <ExposureUnit, ClockUsage>{...usageByUnit};
  if (divesRemaining != null && divesSinceAnchor != null) {
    usage.putIfAbsent(
      ExposureUnit.dives,
      () => ClockUsage(
        interval: (divesSinceAnchor + divesRemaining).toDouble(),
        since: divesSinceAnchor.toDouble(),
      ),
    );
  }
  if (hoursRemaining != null && hoursSinceAnchor != null) {
    usage.putIfAbsent(
      ExposureUnit.hours,
      () => ClockUsage(
        interval: hoursSinceAnchor + hoursRemaining,
        since: hoursSinceAnchor,
      ),
    );
  }
  for (final unit in ExposureUnit.values) {
    final u = usage[unit];
    if (u == null || unit == ExposureUnit.days) continue;
    final remaining = u.remaining < 0 ? 0.0 : u.remaining;
    parts.add(
      unit.isFractional
          ? unit.leftText(
              l10n,
              remaining: remaining.toStringAsFixed(1),
              total: u.interval.toStringAsFixed(1),
            )
          : unit.leftText(
              l10n,
              remaining: remaining.round().toString(),
              total: u.interval.round().toString(),
            ),
    );
  }
  return parts.join(' · ');
}
```

Add the imports for `exposure_unit.dart`, `service_clock_status.dart` and `exposure_unit_display.dart`.

In `service_clocks_card.dart`, `_triggerText` passes `usageByUnit: status.usageByUnit,` and drops the four legacy arguments. The "Counted from logged dive time" note condition becomes `if (status.usageByUnit.keys.any((u) => u.isFractional))`.

- [ ] **Step 5: Add the fields to both dialogs**

`service_schedule_dialogs.dart`, `_ScheduleOverrideDialogState`: add

```dart
  late final Map<ExposureUnit, TextEditingController> _exposure;
```

In `initState` after `_anchorDate = s.anchorDate;`:

```dart
    _exposure = {
      for (final unit in ExposureUnit.mapUnits)
        unit: TextEditingController(
          text: switch (s.exposureIntervals[unit]) {
            null => '',
            final v when unit.isFractional => formatDecimalForInput(v),
            final v => v.round().toString(),
          },
        ),
    };
```

In `dispose`, before `super.dispose()`: `for (final c in _exposure.values) { c.dispose(); }`.

After the hours `TextField` (before the default cost field), insert:

```dart
              for (final unit in ExposureUnit.mapUnits) ...[
                const SizedBox(height: 12),
                TextField(
                  key: Key('service-schedule-exposure-${unit.name}'),
                  controller: _exposure[unit],
                  keyboardType: unit.isFractional
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  decoration: InputDecoration(
                    labelText: unit.intervalLabel(l10n),
                    hintText: switch (kind.exposureIntervals[unit]) {
                      null => null,
                      final v when unit.isFractional =>
                        l10n.equipment_scheduleDialog_inheritHint(
                          formatDecimalForInput(v),
                        ),
                      final v => l10n.equipment_scheduleDialog_inheritHint(
                        v.round().toString(),
                      ),
                    },
                  ),
                ),
              ],
```

In the save handler, build the map and pass it:

```dart
              exposureIntervals: {
                for (final e in _exposure.entries)
                  if (parseUserDecimal(e.value.text) case final v?
                      when v > 0)
                    e.key: v,
              },
```

Imports: `exposure_unit.dart` and `utils/exposure_unit_display.dart`.

`service_kind_list_page.dart`, `_ServiceKindEditDialogState`: the same controller map (seeded from `k?.exposureIntervals[unit]`), the same fields after the hours field (key prefix `service-kind-exposure-`), disposal, and `exposureIntervals:` in both the `createKind` and `updateKind` constructions. The summary line near line 50 that lists a kind's default intervals gains one entry per map unit using `unit.leftText`-style labels is out of scope; leave it.

- [ ] **Step 6: Run the tests and the widget neighbours**

Run: `flutter test test/features/equipment/presentation/widgets test/features/equipment/presentation/pages test/features/pre_dive`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/utils/exposure_unit_display.dart lib/features/equipment/presentation/widgets/service_trigger_text.dart lib/features/equipment/presentation/widgets/service_clocks_card.dart lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart lib/features/equipment/presentation/pages/service_kind_list_page.dart lib/l10n test/features/equipment/presentation/widgets/service_trigger_text_exposure_test.dart test/features/equipment/presentation/widgets/service_schedule_dialog_exposure_test.dart
git commit -m "feat(equipment): edit and display exposure intervals on clocks"
```

---

### Task 13: Child items pick their parent in the equipment editor

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (state near line 53, load near 141, the dropdown block near 229, save near 859)
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart`

**Interfaces:**
- Consumes: `activeEquipmentProvider`, `EquipmentItem.parentEquipmentId`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(WidgetTester tester, String? equipmentId) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an O2 cell offers rebreathers as its parent and saves it',
      (tester) async {
    final unit = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'JJ-CCR', type: EquipmentType.rebreather),
    );
    await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    final cell = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Cell 1', type: EquipmentType.o2Cell),
    );
    await pumpEditor(tester, cell.id);

    expect(find.text('Installed in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('equipment-parent-picker')));
    await tester.pumpAndSettle();
    expect(find.text('JJ-CCR').hitTestable(), findsOneWidget);
    expect(find.text('Apeks').hitTestable(), findsNothing);
    await tester.tap(find.text('JJ-CCR').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repository.getEquipmentById(cell.id))!.parentEquipmentId, unit.id);
  });

  testWidgets('a regulator shows no parent picker', (tester) async {
    final reg = await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Apeks', type: EquipmentType.regulator),
    );
    await pumpEditor(tester, reg.id);
    expect(find.text('Installed in'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart`
Expected: fails, `Installed in` not found.

- [ ] **Step 3: Add the picker**

ARB (English; insert after `equipment_edit_statusLabel`):

```json
  "equipment_edit_parentLabel": "Installed in",
  "equipment_edit_parentNone": "Not installed in anything",
```

`equipment_edit_page.dart`: state field `String? _parentEquipmentId;` next to `_purchaseDate`; in the load block add `_parentEquipmentId = equipment.parentEquipmentId;`. A static helper in the state class:

```dart
  /// Which item types can hold a child of [type]. Empty means the type is
  /// not a child type and the picker is hidden.
  static Set<EquipmentType> _parentTypesFor(EquipmentType type) =>
      switch (type) {
        EquipmentType.o2Cell => const {EquipmentType.rebreather},
        EquipmentType.battery => const {
          EquipmentType.computer,
          EquipmentType.transmitter,
          EquipmentType.light,
          EquipmentType.dpv,
          EquipmentType.rebreather,
        },
        _ => const {},
      };
```

After the status dropdown's trailing `const SizedBox(height: 16),`, add:

```dart
          if (_parentTypesFor(_selectedType).isNotEmpty) ...[
            Builder(
              builder: (context) {
                final candidates =
                    (ref.watch(activeEquipmentProvider).valueOrNull ??
                            const <EquipmentItem>[])
                        .where(
                          (e) =>
                              e.id != widget.equipmentId &&
                              _parentTypesFor(_selectedType).contains(e.type),
                        )
                        .toList();
                final known = candidates.any((e) => e.id == _parentEquipmentId);
                return DropdownButtonFormField<String?>(
                  key: const Key('equipment-parent-picker'),
                  initialValue: known ? _parentEquipmentId : null,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_edit_parentLabel,
                    prefixIcon: const Icon(Icons.account_tree_outlined),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(context.l10n.equipment_edit_parentNone),
                    ),
                    for (final e in candidates)
                      DropdownMenuItem<String?>(value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _parentEquipmentId = value;
                    _hasChanges = true;
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
```

In the save block, add to the `EquipmentItem(` construction:

```dart
        parentEquipmentId: _parentTypesFor(_selectedType).isEmpty
            ? null
            : _parentEquipmentId,
```

`valueOrNull` is the project extension in `core/providers/async_value_extensions.dart`; import it.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/equipment/presentation/pages`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart lib/l10n test/features/equipment/presentation/pages/equipment_edit_parent_picker_test.dart
git commit -m "feat(equipment): child items pick their parent in the editor"
```

---

### Task 14: The tank editor names the regulator, prefilled from the last pairing

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (add `getLastRegulatorForPreset`)
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (state, `_initializeControllers`, `_applyPreset`, `_notifyChange`, `build`)
- Modify: all 11 ARB files
- Test: `test/features/equipment/data/last_regulator_lookup_test.dart`, `test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart`

**Interfaces:**
- Produces: `Future<String?> EquipmentRepository.getLastRegulatorForPreset(String presetName)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/data/last_regulator_lookup_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('returns the regulator from the newest dive using the preset', () async {
    Future<void> dive(String id, int ms, String preset, String? reg) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-$id', diveId: id).copyWith(
              presetName: Value(preset),
              regulatorEquipmentId: Value(reg),
            ),
          );
    }

    await dive('old', 1000, 'al80', 'reg-a');
    await dive('new', 2000, 'al80', 'reg-b');
    await dive('newest-unset', 3000, 'al80', null);
    await dive('other', 4000, 'hp100', 'reg-c');

    final repo = EquipmentRepository();
    expect(await repo.getLastRegulatorForPreset('al80'), 'reg-b');
    expect(await repo.getLastRegulatorForPreset('hp100'), 'reg-c');
    expect(await repo.getLastRegulatorForPreset('lp85'), isNull);
  });
}
```

```dart
// test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'tank_editor_test.dart' show MockTankPresetListNotifier;

void main() {
  testWidgets('choosing a regulator reports it on the tank', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final builtInPresets = TankPresets.all
        .map((p) => TankPresetEntity.fromBuiltIn(p))
        .toList();
    const regs = [
      EquipmentItem(id: 'reg-a', name: 'Apeks XTX', type: EquipmentType.regulator),
      EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
    ];
    DiveTank? changed;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tankPresetListNotifierProvider.overrideWith(
            (ref) => MockTankPresetListNotifier(builtInPresets),
          ),
          tankPresetsProvider.overrideWith(
            (ref) => Future.value(builtInPresets),
          ),
          activeEquipmentProvider.overrideWith((ref) async => regs),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TankEditor(
                tank: const DiveTank(id: 'tank-1'),
                tankNumber: 1,
                onChanged: (t) => changed = t,
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tank-regulator-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Mask').hitTestable(), findsNothing);
    await tester.tap(find.text('Apeks XTX').hitTestable());
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
  });
}
```

`tank_editor_test.dart` declares `_MockTankPresetListNotifier` privately; rename it there to `MockTankPresetListNotifier` (public) so this test can import it, or copy its body into this file if it is only a few lines. Keep the existing test compiling.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/data/last_regulator_lookup_test.dart test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart`
Expected: compile error (`getLastRegulatorForPreset`), and the picker key not found.

- [ ] **Step 3: Implement the lookup and the picker**

ARB (English; insert after `diveLog_tank_tooltip_remove`):

```json
  "diveLog_tank_regulatorLabel": "Regulator",
  "diveLog_tank_regulatorNone": "None",
```

Repository method (after `getExposureSamplesForEquipment`):

```dart
  /// The regulator last paired with a cylinder preset, for prefilling the
  /// tank editor: the newest dive whose tank of that preset names one.
  Future<String?> getLastRegulatorForPreset(String presetName) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT t.regulator_equipment_id AS reg
      FROM dive_tanks t
      JOIN dives d ON d.id = t.dive_id
      WHERE t.preset_name = ?1 AND t.regulator_equipment_id IS NOT NULL
      ORDER BY d.dive_date_time DESC
      LIMIT 1
    ''',
          variables: [Variable.withString(presetName)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data['reg'] as String?;
  }
```

`tank_editor.dart`: state `String? _regulatorEquipmentId;` set in `_initializeControllers` from `widget.tank.regulatorEquipmentId`. In `_notifyChange` replace the preserved value with `regulatorEquipmentId: _regulatorEquipmentId,`. In `_applyPreset`, after `_selectedPreset = preset;` inside `setState`, nothing; after the `setState` block add:

```dart
    // Prefill the regulator from the last dive that paired one with this
    // preset, but never overwrite a choice already made on this tank.
    if (_regulatorEquipmentId == null) {
      ref
          .read(equipmentRepositoryProvider)
          .getLastRegulatorForPreset(preset.name)
          .then((reg) {
            if (!mounted || reg == null || _regulatorEquipmentId != null) {
              return;
            }
            setState(() => _regulatorEquipmentId = reg);
            _notifyChange();
          });
    }
```

In `build`, after the material dropdown (or the role dropdown if there is no material one; place it with the other identity fields), add:

```dart
            Builder(
              builder: (context) {
                final regs =
                    (ref.watch(activeEquipmentProvider).valueOrNull ??
                            const <EquipmentItem>[])
                        .where((e) => e.type == EquipmentType.regulator)
                        .toList();
                final known = regs.any((r) => r.id == _regulatorEquipmentId);
                return DropdownButtonFormField<String?>(
                  key: const Key('tank-regulator-picker'),
                  initialValue: known ? _regulatorEquipmentId : null,
                  decoration: InputDecoration(
                    labelText: context.l10n.diveLog_tank_regulatorLabel,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(context.l10n.diveLog_tank_regulatorNone),
                    ),
                    for (final r in regs)
                      DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _regulatorEquipmentId = value);
                    _notifyChange();
                  },
                );
              },
            ),
```

Imports: `equipment_providers.dart`, `equipment_item.dart`, `async_value_extensions.dart`.

- [ ] **Step 4: Run the tests and the dive edit suite**

Run: `flutter test test/features/dive_log/presentation/widgets test/features/equipment/data`
Expected: PASS. The bulk tank spec editor also hosts `TankEditor`; its test must still pass (it overrides `activeEquipmentProvider` or tolerates the loading state, since `valueOrNull` yields an empty list).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/equipment/data/repositories/equipment_repository_impl.dart lib/features/dive_log/presentation/widgets/tank_editor.dart lib/l10n test/features/equipment/data/last_regulator_lookup_test.dart test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart test/features/dive_log/presentation/widgets/tank_editor_test.dart
git commit -m "feat(dive-log): pick the regulator on a tank, prefilled from the last pairing"
```

---

### Task 15: Usage-driven clocks get a notification

**Files:**
- Modify: `lib/features/notifications/data/repositories/scheduled_notification_repository.dart` (`deleteExpired`, add `hasUsageReminder`)
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart` (`_scheduleForClock`)
- Test: `test/features/notifications/usage_clock_reminder_test.dart`

**Interfaces:**
- Produces: `const int kUsageReminderDaysBefore = -1;` (in the repository file); `Future<bool> ScheduledNotificationRepository.hasUsageReminder({required String scheduleId, required DateTime since})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notifications/usage_clock_reminder_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> linkDive(String id, String equipmentId) async {
    final ms = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: ms,
            createdAt: ms,
            updatedAt: ms,
          ).copyWith(runtime: const Value(3600)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
  }

  test('an overdue dives clock schedules one reminder per anchor', () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final scheduleRepo = ServiceScheduleRepository();
    final regService = (await scheduleRepo.getSchedulesForEquipment(reg.id))
        .firstWhere((s) => s.serviceKindId == 'regulator-service');
    // Days trigger far away, dives trigger overdue.
    await scheduleRepo.updateSchedule(
      regService.copyWith(intervalDays: 3650, intervalDives: 1),
    );
    await linkDive('d1', reg.id);
    await linkDive('d2', reg.id);

    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    var rows = await db.select(db.scheduledNotifications).get();
    final usage = rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore);
    expect(usage, hasLength(1));
    expect(usage.single.scheduleId, regService.id);

    // Idempotent across runs and across the expiry sweep.
    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    await ScheduledNotificationRepository().deleteExpired();
    rows = await db.select(db.scheduledNotifications).get();
    expect(
      rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore),
      hasLength(1),
    );
  });

  test('an ok usage clock schedules nothing', () async {
    final reg = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await linkDive('d1', reg.id);
    await NotificationScheduler().scheduleAll(settings: const AppSettings());
    final rows = await db.select(db.scheduledNotifications).get();
    expect(
      rows.where((r) => r.reminderDaysBefore == kUsageReminderDaysBefore),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/usage_clock_reminder_test.dart`
Expected: compile error, `kUsageReminderDaysBefore` undefined.

- [ ] **Step 3: Implement**

`scheduled_notification_repository.dart`, top level:

```dart
/// reminder_days_before value that marks a usage-clock reminder (v202).
/// Date reminders use the positive days-before values from settings.
const int kUsageReminderDaysBefore = -1;
```

Add the method after `isScheduled`:

```dart
  /// Whether a usage-clock reminder for [scheduleId] has been recorded
  /// since [since] (the clock's anchor). One reminder per anchor: logging a
  /// service record moves the anchor and re-arms it.
  Future<bool> hasUsageReminder({
    required String scheduleId,
    required DateTime since,
  }) async {
    final row =
        await (_db.select(_db.scheduledNotifications)
              ..where((t) => t.scheduleId.equals(scheduleId))
              ..where(
                (t) => t.reminderDaysBefore.equals(kUsageReminderDaysBefore),
              )
              ..where(
                (t) => t.createdAt.isBiggerOrEqualValue(
                  since.millisecondsSinceEpoch,
                ),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
```

In `deleteExpired`, keep usage rows (they are the dedupe record, and the equipment-level cancel paths delete them):

```dart
      await (_db.delete(_db.scheduledNotifications)..where(
            (t) =>
                t.scheduledDate.isSmallerThanValue(now) &
                t.reminderDaysBefore.isBiggerOrEqualValue(0),
          ))
          .go();
```

`notification_scheduler.dart`, in `_scheduleForClock`, replace `if (dueDate == null) return;` with:

```dart
    if (dueDate == null) {
      await _scheduleUsageReminder(
        item: item,
        status: status,
        globalSettings: globalSettings,
      );
      return;
    }
```

and add the method:

```dart
  /// One local notification when a usage-only clock reaches due-soon or
  /// overdue, deduplicated per (schedule, anchor). Fires at the next
  /// reminder time. Rescheduling everything (settings change) re-arms it
  /// once, which is acceptable for a clock that is still due.
  Future<void> _scheduleUsageReminder({
    required EquipmentItem item,
    required ServiceClockStatus status,
    required AppSettings globalSettings,
  }) async {
    if (status.severity == ServiceClockSeverity.ok) return;
    if (item.customReminderEnabled == false) return;
    final already = await _scheduledNotificationRepository.hasUsageReminder(
      scheduleId: status.schedule.id,
      since: status.anchor,
    );
    if (already) return;

    final now = DateTime.now();
    var fireAt = DateTime(
      now.year,
      now.month,
      now.day,
      globalSettings.reminderTime.hour,
      globalSettings.reminderTime.minute,
    );
    if (!fireAt.isAfter(now)) fireAt = fireAt.add(const Duration(days: 1));

    final brandModel = item.brand != null || item.model != null
        ? '${item.brand ?? ''} ${item.model ?? ''}'.trim()
        : null;
    final notificationId = await _notificationService.scheduleServiceReminder(
      scheduleId: status.schedule.id,
      equipmentId: item.id,
      equipmentName: item.name,
      kindName: status.kind.name,
      brandModel: brandModel,
      scheduledDate: fireAt,
      daysBefore: kUsageReminderDaysBefore,
    );
    await _scheduledNotificationRepository.recordScheduled(
      equipmentId: item.id,
      scheduledDate: fireAt,
      reminderDaysBefore: kUsageReminderDaysBefore,
      notificationId: notificationId,
      scheduleId: status.schedule.id,
    );
  }
```

`NotificationService.serviceReminderBody` already renders `daysBefore <= 0` as "is due today", and the platform id derives from `'$scheduleId#-1'`, which no date reminder uses.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/notifications`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/notifications/data/repositories/scheduled_notification_repository.dart lib/features/notifications/data/services/notification_scheduler.dart test/features/notifications/usage_clock_reminder_test.dart
git commit -m "feat(notifications): remind once when a usage clock comes due"
```

---

### Task 16: Equipment condition settings section

**Files:**
- Create: `lib/features/settings/presentation/pages/equipment_condition_settings_page.dart`
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart` (section list, after `safety`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (both content switches near lines 165 and 319, `settingsSectionDedicatedRoutes`, title and subtitle switches near 399 and 417)
- Modify: `lib/core/router/app_router.dart:1121` (route after `safety`)
- Modify: all 11 ARB files
- Test: `test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_condition_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _build(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: EquipmentConditionSettingsPage(),
  ),
);

void main() {
  testWidgets('shows the defaults in metric and saves a new cold line',
      (tester) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_build(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Equipment condition'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '40'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('threshold-cold')), '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(notifier.state.coldWaterThresholdC, 8.0);
  });

  testWidgets('imperial divers edit in their units and store metric',
      (tester) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(
        temperatureUnit: TemperatureUnit.fahrenheit,
        depthUnit: DepthUnit.feet,
      ),
    );
    await tester.pumpWidget(_build(notifier));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '50'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '98.4'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('threshold-deep')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(notifier.state.deepDiveThresholdM, closeTo(30.48, 0.01));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart`
Expected: compile error, page not found.

- [ ] **Step 3: Add the page, the section and the route**

The mock settings notifier already carries the three threshold setters from Task 10.

ARB (English; `settings_section_equipmentCondition_*` after `settings_section_safety_subtitle`; the page keys after them):

```json
  "settings_section_equipmentCondition_title": "Equipment condition",
  "settings_section_equipmentCondition_subtitle": "Exposure thresholds for service clocks",
  "equipmentConditionSettings_title": "Equipment condition",
  "equipmentConditionSettings_thresholdsHeader": "Exposure thresholds",
  "equipmentConditionSettings_thresholdsHelp": "A dive counts as cold, deep or high-O2 for service clocks when it crosses these lines.",
  "equipmentConditionSettings_coldLabel": "Cold water below",
  "equipmentConditionSettings_deepLabel": "Deep dive at or beyond",
  "equipmentConditionSettings_o2Label": "High-O2 mix above (% O2)",
  "equipmentConditionSettings_invalid": "Enter a number",
```

The page:

```dart
// lib/features/settings/presentation/pages/equipment_condition_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Exposure thresholds for service clocks, edited in the diver's units and
/// stored metric. Phase 3 adds the condition engine toggles here.
class EquipmentConditionSettingsPage extends ConsumerWidget {
  const EquipmentConditionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipmentConditionSettings_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.equipmentConditionSettings_thresholdsHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.equipmentConditionSettings_thresholdsHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _ThresholdField(
            key: const Key('threshold-cold'),
            label: l10n.equipmentConditionSettings_coldLabel,
            suffix: units.temperatureSymbol,
            // Re-seed when the stored value or the unit changes.
            seedKey: '${settings.coldWaterThresholdC}-${settings.temperatureUnit}',
            displayValue: units.convertTemperature(settings.coldWaterThresholdC),
            onSubmit: (v) =>
                notifier.setColdWaterThresholdC(units.temperatureToCelsius(v)),
          ),
          const SizedBox(height: 12),
          _ThresholdField(
            key: const Key('threshold-deep'),
            label: l10n.equipmentConditionSettings_deepLabel,
            suffix: units.depthSymbol,
            seedKey: '${settings.deepDiveThresholdM}-${settings.depthUnit}',
            displayValue: units.convertDepth(settings.deepDiveThresholdM),
            onSubmit: (v) => notifier.setDeepDiveThresholdM(units.depthToMeters(v)),
          ),
          const SizedBox(height: 12),
          _ThresholdField(
            key: const Key('threshold-o2'),
            label: l10n.equipmentConditionSettings_o2Label,
            suffix: '%',
            seedKey: '${settings.highO2ThresholdPercent}',
            displayValue: settings.highO2ThresholdPercent,
            onSubmit: notifier.setHighO2ThresholdPercent,
          ),
        ],
      ),
    );
  }
}

class _ThresholdField extends StatefulWidget {
  final String label;
  final String suffix;
  final String seedKey;
  final double displayValue;
  final Future<void> Function(double) onSubmit;

  const _ThresholdField({
    super.key,
    required this.label,
    required this.suffix,
    required this.seedKey,
    required this.displayValue,
    required this.onSubmit,
  });

  @override
  State<_ThresholdField> createState() => _ThresholdFieldState();
}

class _ThresholdFieldState extends State<_ThresholdField> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _seed());
  }

  @override
  void didUpdateWidget(_ThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedKey != widget.seedKey) _controller.text = _seed();
  }

  /// One decimal, then the diver's decimal separator; a whole number reads
  /// as "10", not "10.0" (formatDecimalForInput strips the trailing zero).
  String _seed() =>
      formatDecimalForInput((widget.displayValue * 10).round() / 10);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = parseUserDecimal(_controller.text);
    if (parsed == null) {
      setState(() => _error = context.l10n.equipmentConditionSettings_invalid);
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        errorText: _error,
      ),
      onFieldSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
    );
  }
}
```

Section: in `settings_list_content.dart` after the `safety` entry:

```dart
  SettingsSection(
    id: 'equipmentCondition',
    icon: Icons.build_circle_outlined,
    title: 'Equipment condition',
    subtitle: 'Exposure thresholds for service clocks',
  ),
```

In `settings_page.dart`: both content switches gain `case 'equipmentCondition': return const EquipmentConditionSettingsPage();`; the title switch gains `'equipmentCondition' => context.l10n.settings_section_equipmentCondition_title,`; the subtitle switch gains `'equipmentCondition' => context.l10n.settings_section_equipmentCondition_subtitle,`; `settingsSectionDedicatedRoutes` gains `'equipmentCondition': '/settings/equipment-condition',`. Import the page.

`app_router.dart`, after the `safety` route:

```dart
              GoRoute(
                path: 'equipment-condition',
                name: 'equipmentConditionSettings',
                builder: (context, state) =>
                    const EquipmentConditionSettingsPage(),
              ),
```

- [ ] **Step 4: Run the tests and the settings page suite**

Run: `flutter test test/features/settings`
Expected: PASS. If `settings_page_test.dart` pins the section count or order, update that expectation for the new section.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/settings/presentation/pages/equipment_condition_settings_page.dart lib/features/settings/presentation/widgets/settings_list_content.dart lib/features/settings/presentation/pages/settings_page.dart lib/core/router/app_router.dart lib/l10n test/features/settings/presentation/pages/equipment_condition_settings_page_test.dart
git commit -m "feat(settings): equipment condition thresholds page"
```

---

### Task 17: The new columns round-trip through sync

**Files:**
- Test: `test/core/services/sync/equipment_condition_columns_sync_test.dart`

No production change is expected: every table involved serializes whole rows through Drift's `toJson` and `fromJson`. The test proves it and pins the behaviour for an older peer that omits the keys.

- [ ] **Step 1: Write the test**

```dart
// test/core/services/sync/equipment_condition_columns_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> equipment(String id, {String? parent}) => {
    'id': id,
    'name': id,
    'type': 'o2Cell',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
    if (parent != null) 'parentEquipmentId': parent,
  };

  test('equipment.parentEquipmentId round-trips and tolerates omission',
      () async {
    await serializer.upsertRecord('equipment', equipment('unit'));
    await serializer.upsertRecord('equipment', equipment('cell', parent: 'unit'));
    final row = await serializer.fetchRecord('equipment', 'cell');
    expect(row!['parentEquipmentId'], 'unit');

    // An older peer republishes the row without the key: it applies, and
    // the overlay merge keeps the local value.
    await serializer.upsertRecord('equipment', equipment('orphan'));
    expect((await serializer.fetchRecord('equipment', 'orphan'))!['parentEquipmentId'], isNull);
  });

  test('service ledger rows carry exposureIntervals', () async {
    final reg = await serializer.fetchRecord('serviceKinds', 'regulator-service');
    expect(reg!['exposureIntervals'], '{"coldDives":50}');

    await serializer.upsertRecord('equipment', equipment('r1'));
    await serializer.upsertRecord('serviceSchedules', {
      'id': 's1',
      'equipmentId': 'r1',
      'serviceKindId': 'regulator-service',
      'exposureIntervals': '{"coldDives":25.0}',
      'enabled': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    expect(
      (await serializer.fetchRecord('serviceSchedules', 's1'))!['exposureIntervals'],
      '{"coldDives":25.0}',
    );
  });

  test('dive tanks carry regulatorEquipmentId', () async {
    await serializer.upsertRecord('equipment', equipment('reg'));
    await serializer.upsertRecord('dives', {
      'id': 'd1',
      'diveDateTime': 1000,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('diveTanks', {
      'id': 't1',
      'diveId': 'd1',
      'o2Percent': 32.0,
      'hePercent': 0.0,
      'tankOrder': 0,
      'tankRole': 'backGas',
      'regulatorEquipmentId': 'reg',
    });
    expect(
      (await serializer.fetchRecord('diveTanks', 't1'))!['regulatorEquipmentId'],
      'reg',
    );
  });
}
```

If `upsertRecord('dives', ...)` needs more non-null columns than listed, copy the minimal dive JSON from `test/core/services/sync/cross_version_roundtrip_test.dart`'s helpers rather than guessing.

- [ ] **Step 2: Run the test**

Run: `flutter test test/core/services/sync/equipment_condition_columns_sync_test.dart`
Expected: PASS on the first run (the columns already exist). If a key is missing from the fetched JSON, the table's row class was not regenerated; re-run the Drift codegen from Task 6.

- [ ] **Step 3: Commit**

```bash
dart format test
git add test/core/services/sync/equipment_condition_columns_sync_test.dart
git commit -m "test(sync): pin the v202 equipment columns through the serializer"
```

---

### Task 18: Wrap-up

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format . && flutter analyze
```

Expected: no changes from format, `No issues found!`. Infos count as failures in CI.

- [ ] **Step 2: Check the localization gate**

```bash
flutter gen-l10n && git status --short lib/l10n
```

Expected: no unstaged generated changes. Every key added in Tasks 1, 12, 13, 14 and 16 exists in all 11 ARB files (`for f in lib/l10n/arb/app_*.arb; do echo "$f $(grep -c 'equipmentConditionSettings_title' $f)"; done` prints 1 for each).

- [ ] **Step 3: Run the full suite once**

```bash
flutter test
```

Expected: all pass. Do not pipe the output through grep; the exit code is the result.

- [ ] **Step 4: Scan for forbidden characters**

```bash
git diff main --name-only | xargs grep -l $'\xe2\x80\x94' || echo "no em-dashes"
```

Expected: `no em-dashes`.

- [ ] **Step 5: Commit any formatting fallout and push**

```bash
git add -u lib test
git commit -m "chore: format after phase 1" || true
git push -u origin ericgriffin/equipment-condition-intelligence-e9b61e
```

Then open the PR with the summary below as its body. No attribution lines.

PR summary: Phase 1 of the equipment condition intelligence spec. Service clocks now read a per-dive exposure sample and can count salt-water hours, cold dives, high-O2 hours, deep cycles and battery cycles, with thresholds per diver. Adds O2 cell and battery child items, a regulator link on dive tanks, the v202 schema every later phase needs, seeded exposure defaults on built-in kinds, and a notification when a usage clock comes due.

---

## Translation Appendix

Every key added by this plan, in the ten non-English locales. Insert each key beside the same neighbour it has in `app_en.arb`. Keys with `{remaining}` and `{total}` placeholders take the same `@key` metadata block as `equipment_serviceClocks_hoursLeft` in that file.

### de

```json
  "enum_equipmentType_o2Cell": "O2-Zelle",
  "enum_equipmentType_battery": "Batterie",
  "attrLabel_cell_slot": "Zellenplatz",
  "attrLabel_installed_date": "Eingebaut am",
  "attrLabel_rechargeable": "Wiederaufladbar",
  "attrChoice_battery_type_alkaline": "Alkali",
  "attrChoice_battery_type_lithium_primary": "Lithium (nicht wiederaufladbar)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervall (Salzwasserstunden)",
  "equipment_scheduleDialog_intervalColdDives": "Intervall (Kaltwassertauchgänge)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervall (Stunden mit hohem O2)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervall (tiefe Tauchgänge)",
  "equipment_scheduleDialog_intervalCycles": "Intervall (Batteriezyklen)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} von {total} Salzwasserstunden übrig",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} von {total} Kaltwassertauchgängen übrig",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} von {total} Stunden mit hohem O2 übrig",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} von {total} tiefen Tauchgängen übrig",
  "equipment_serviceClocks_cyclesLeft": "{remaining} von {total} Batteriezyklen übrig",
  "equipment_edit_parentLabel": "Eingebaut in",
  "equipment_edit_parentNone": "Nirgends eingebaut",
  "diveLog_tank_regulatorLabel": "Atemregler",
  "diveLog_tank_regulatorNone": "Keiner",
  "settings_section_equipmentCondition_title": "Ausrüstungszustand",
  "settings_section_equipmentCondition_subtitle": "Belastungsgrenzen für Wartungsuhren",
  "equipmentConditionSettings_title": "Ausrüstungszustand",
  "equipmentConditionSettings_thresholdsHeader": "Belastungsgrenzen",
  "equipmentConditionSettings_thresholdsHelp": "Ein Tauchgang zählt für Wartungsuhren als kalt, tief oder O2-reich, wenn er diese Grenzen überschreitet.",
  "equipmentConditionSettings_coldLabel": "Kaltwasser unter",
  "equipmentConditionSettings_deepLabel": "Tiefer Tauchgang ab",
  "equipmentConditionSettings_o2Label": "O2-reiches Gemisch über (% O2)",
  "equipmentConditionSettings_invalid": "Bitte eine Zahl eingeben",
```

### es

```json
  "enum_equipmentType_o2Cell": "Célula de O2",
  "enum_equipmentType_battery": "Batería",
  "attrLabel_cell_slot": "Posición de la célula",
  "attrLabel_installed_date": "Instalada el",
  "attrLabel_rechargeable": "Recargable",
  "attrChoice_battery_type_alkaline": "Alcalina",
  "attrChoice_battery_type_lithium_primary": "Litio (no recargable)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervalo (horas en agua salada)",
  "equipment_scheduleDialog_intervalColdDives": "Intervalo (inmersiones en agua fría)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervalo (horas con alto O2)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervalo (inmersiones profundas)",
  "equipment_scheduleDialog_intervalCycles": "Intervalo (ciclos de batería)",
  "equipment_serviceClocks_saltHoursLeft": "Quedan {remaining} de {total} horas en agua salada",
  "equipment_serviceClocks_coldDivesLeft": "Quedan {remaining} de {total} inmersiones en agua fría",
  "equipment_serviceClocks_o2HoursLeft": "Quedan {remaining} de {total} horas con alto O2",
  "equipment_serviceClocks_deepCyclesLeft": "Quedan {remaining} de {total} inmersiones profundas",
  "equipment_serviceClocks_cyclesLeft": "Quedan {remaining} de {total} ciclos de batería",
  "equipment_edit_parentLabel": "Instalado en",
  "equipment_edit_parentNone": "No instalado en nada",
  "diveLog_tank_regulatorLabel": "Regulador",
  "diveLog_tank_regulatorNone": "Ninguno",
  "settings_section_equipmentCondition_title": "Estado del equipo",
  "settings_section_equipmentCondition_subtitle": "Umbrales de exposición para los relojes de mantenimiento",
  "equipmentConditionSettings_title": "Estado del equipo",
  "equipmentConditionSettings_thresholdsHeader": "Umbrales de exposición",
  "equipmentConditionSettings_thresholdsHelp": "Una inmersión cuenta como fría, profunda o con alto O2 para los relojes de mantenimiento cuando cruza estos límites.",
  "equipmentConditionSettings_coldLabel": "Agua fría por debajo de",
  "equipmentConditionSettings_deepLabel": "Inmersión profunda a partir de",
  "equipmentConditionSettings_o2Label": "Mezcla con alto O2 por encima de (% O2)",
  "equipmentConditionSettings_invalid": "Introduce un número",
```

### fr

```json
  "enum_equipmentType_o2Cell": "Cellule O2",
  "enum_equipmentType_battery": "Batterie",
  "attrLabel_cell_slot": "Emplacement de la cellule",
  "attrLabel_installed_date": "Installée le",
  "attrLabel_rechargeable": "Rechargeable",
  "attrChoice_battery_type_alkaline": "Alcaline",
  "attrChoice_battery_type_lithium_primary": "Lithium (non rechargeable)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervalle (heures en eau salée)",
  "equipment_scheduleDialog_intervalColdDives": "Intervalle (plongées en eau froide)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervalle (heures à haut O2)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervalle (plongées profondes)",
  "equipment_scheduleDialog_intervalCycles": "Intervalle (cycles de batterie)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} sur {total} heures en eau salée restantes",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} sur {total} plongées en eau froide restantes",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} sur {total} heures à haut O2 restantes",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} sur {total} plongées profondes restantes",
  "equipment_serviceClocks_cyclesLeft": "{remaining} sur {total} cycles de batterie restants",
  "equipment_edit_parentLabel": "Installé dans",
  "equipment_edit_parentNone": "Installé nulle part",
  "diveLog_tank_regulatorLabel": "Détendeur",
  "diveLog_tank_regulatorNone": "Aucun",
  "settings_section_equipmentCondition_title": "État du matériel",
  "settings_section_equipmentCondition_subtitle": "Seuils d'exposition pour les compteurs d'entretien",
  "equipmentConditionSettings_title": "État du matériel",
  "equipmentConditionSettings_thresholdsHeader": "Seuils d'exposition",
  "equipmentConditionSettings_thresholdsHelp": "Une plongée compte comme froide, profonde ou à haut O2 pour les compteurs d'entretien lorsqu'elle franchit ces seuils.",
  "equipmentConditionSettings_coldLabel": "Eau froide en dessous de",
  "equipmentConditionSettings_deepLabel": "Plongée profonde à partir de",
  "equipmentConditionSettings_o2Label": "Mélange à haut O2 au-dessus de (% O2)",
  "equipmentConditionSettings_invalid": "Saisissez un nombre",
```

### it

```json
  "enum_equipmentType_o2Cell": "Cella O2",
  "enum_equipmentType_battery": "Batteria",
  "attrLabel_cell_slot": "Posizione della cella",
  "attrLabel_installed_date": "Installata il",
  "attrLabel_rechargeable": "Ricaricabile",
  "attrChoice_battery_type_alkaline": "Alcalina",
  "attrChoice_battery_type_lithium_primary": "Litio (non ricaricabile)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervallo (ore in acqua salata)",
  "equipment_scheduleDialog_intervalColdDives": "Intervallo (immersioni in acqua fredda)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervallo (ore ad alto O2)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervallo (immersioni profonde)",
  "equipment_scheduleDialog_intervalCycles": "Intervallo (cicli di batteria)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} di {total} ore in acqua salata rimanenti",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} di {total} immersioni in acqua fredda rimanenti",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} di {total} ore ad alto O2 rimanenti",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} di {total} immersioni profonde rimanenti",
  "equipment_serviceClocks_cyclesLeft": "{remaining} di {total} cicli di batteria rimanenti",
  "equipment_edit_parentLabel": "Installato in",
  "equipment_edit_parentNone": "Non installato",
  "diveLog_tank_regulatorLabel": "Erogatore",
  "diveLog_tank_regulatorNone": "Nessuno",
  "settings_section_equipmentCondition_title": "Stato dell'attrezzatura",
  "settings_section_equipmentCondition_subtitle": "Soglie di esposizione per i contatori di manutenzione",
  "equipmentConditionSettings_title": "Stato dell'attrezzatura",
  "equipmentConditionSettings_thresholdsHeader": "Soglie di esposizione",
  "equipmentConditionSettings_thresholdsHelp": "Un'immersione conta come fredda, profonda o ad alto O2 per i contatori di manutenzione quando supera queste soglie.",
  "equipmentConditionSettings_coldLabel": "Acqua fredda sotto",
  "equipmentConditionSettings_deepLabel": "Immersione profonda da",
  "equipmentConditionSettings_o2Label": "Miscela ad alto O2 oltre (% O2)",
  "equipmentConditionSettings_invalid": "Inserisci un numero",
```

### nl

```json
  "enum_equipmentType_o2Cell": "O2-cel",
  "enum_equipmentType_battery": "Batterij",
  "attrLabel_cell_slot": "Celpositie",
  "attrLabel_installed_date": "Geplaatst op",
  "attrLabel_rechargeable": "Oplaadbaar",
  "attrChoice_battery_type_alkaline": "Alkaline",
  "attrChoice_battery_type_lithium_primary": "Lithium (niet oplaadbaar)",
  "equipment_scheduleDialog_intervalSaltHours": "Interval (uren in zout water)",
  "equipment_scheduleDialog_intervalColdDives": "Interval (koudwaterduiken)",
  "equipment_scheduleDialog_intervalO2Hours": "Interval (uren met hoog O2)",
  "equipment_scheduleDialog_intervalDeepCycles": "Interval (diepe duiken)",
  "equipment_scheduleDialog_intervalCycles": "Interval (batterijcycli)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} van {total} uren in zout water over",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} van {total} koudwaterduiken over",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} van {total} uren met hoog O2 over",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} van {total} diepe duiken over",
  "equipment_serviceClocks_cyclesLeft": "{remaining} van {total} batterijcycli over",
  "equipment_edit_parentLabel": "Geplaatst in",
  "equipment_edit_parentNone": "Nergens geplaatst",
  "diveLog_tank_regulatorLabel": "Ademautomaat",
  "diveLog_tank_regulatorNone": "Geen",
  "settings_section_equipmentCondition_title": "Staat van uitrusting",
  "settings_section_equipmentCondition_subtitle": "Blootstellingsdrempels voor onderhoudsklokken",
  "equipmentConditionSettings_title": "Staat van uitrusting",
  "equipmentConditionSettings_thresholdsHeader": "Blootstellingsdrempels",
  "equipmentConditionSettings_thresholdsHelp": "Een duik telt voor onderhoudsklokken als koud, diep of met hoog O2 wanneer hij deze grenzen overschrijdt.",
  "equipmentConditionSettings_coldLabel": "Koud water onder",
  "equipmentConditionSettings_deepLabel": "Diepe duik vanaf",
  "equipmentConditionSettings_o2Label": "Mengsel met hoog O2 boven (% O2)",
  "equipmentConditionSettings_invalid": "Voer een getal in",
```

### pt

```json
  "enum_equipmentType_o2Cell": "Célula de O2",
  "enum_equipmentType_battery": "Bateria",
  "attrLabel_cell_slot": "Posição da célula",
  "attrLabel_installed_date": "Instalada em",
  "attrLabel_rechargeable": "Recarregável",
  "attrChoice_battery_type_alkaline": "Alcalina",
  "attrChoice_battery_type_lithium_primary": "Lítio (não recarregável)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervalo (horas em água salgada)",
  "equipment_scheduleDialog_intervalColdDives": "Intervalo (mergulhos em água fria)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervalo (horas com O2 elevado)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervalo (mergulhos profundos)",
  "equipment_scheduleDialog_intervalCycles": "Intervalo (ciclos de bateria)",
  "equipment_serviceClocks_saltHoursLeft": "Restam {remaining} de {total} horas em água salgada",
  "equipment_serviceClocks_coldDivesLeft": "Restam {remaining} de {total} mergulhos em água fria",
  "equipment_serviceClocks_o2HoursLeft": "Restam {remaining} de {total} horas com O2 elevado",
  "equipment_serviceClocks_deepCyclesLeft": "Restam {remaining} de {total} mergulhos profundos",
  "equipment_serviceClocks_cyclesLeft": "Restam {remaining} de {total} ciclos de bateria",
  "equipment_edit_parentLabel": "Instalado em",
  "equipment_edit_parentNone": "Não instalado",
  "diveLog_tank_regulatorLabel": "Regulador",
  "diveLog_tank_regulatorNone": "Nenhum",
  "settings_section_equipmentCondition_title": "Estado do equipamento",
  "settings_section_equipmentCondition_subtitle": "Limites de exposição para os relógios de manutenção",
  "equipmentConditionSettings_title": "Estado do equipamento",
  "equipmentConditionSettings_thresholdsHeader": "Limites de exposição",
  "equipmentConditionSettings_thresholdsHelp": "Um mergulho conta como frio, profundo ou com O2 elevado para os relógios de manutenção quando ultrapassa estes limites.",
  "equipmentConditionSettings_coldLabel": "Água fria abaixo de",
  "equipmentConditionSettings_deepLabel": "Mergulho profundo a partir de",
  "equipmentConditionSettings_o2Label": "Mistura com O2 elevado acima de (% O2)",
  "equipmentConditionSettings_invalid": "Introduza um número",
```

### hu

```json
  "enum_equipmentType_o2Cell": "O2-cella",
  "enum_equipmentType_battery": "Akkumulátor",
  "attrLabel_cell_slot": "Cellahely",
  "attrLabel_installed_date": "Beszerelve",
  "attrLabel_rechargeable": "Újratölthető",
  "attrChoice_battery_type_alkaline": "Alkáli",
  "attrChoice_battery_type_lithium_primary": "Lítium (nem újratölthető)",
  "equipment_scheduleDialog_intervalSaltHours": "Intervallum (sós vízi órák)",
  "equipment_scheduleDialog_intervalColdDives": "Intervallum (hideg vízi merülések)",
  "equipment_scheduleDialog_intervalO2Hours": "Intervallum (magas O2-tartalmú órák)",
  "equipment_scheduleDialog_intervalDeepCycles": "Intervallum (mély merülések)",
  "equipment_scheduleDialog_intervalCycles": "Intervallum (akkumulátorciklusok)",
  "equipment_serviceClocks_saltHoursLeft": "{remaining} / {total} sós vízi óra van hátra",
  "equipment_serviceClocks_coldDivesLeft": "{remaining} / {total} hideg vízi merülés van hátra",
  "equipment_serviceClocks_o2HoursLeft": "{remaining} / {total} magas O2-tartalmú óra van hátra",
  "equipment_serviceClocks_deepCyclesLeft": "{remaining} / {total} mély merülés van hátra",
  "equipment_serviceClocks_cyclesLeft": "{remaining} / {total} akkumulátorciklus van hátra",
  "equipment_edit_parentLabel": "Beszerelve ebbe",
  "equipment_edit_parentNone": "Nincs beszerelve",
  "diveLog_tank_regulatorLabel": "Reduktor",
  "diveLog_tank_regulatorNone": "Nincs",
  "settings_section_equipmentCondition_title": "Felszerelés állapota",
  "settings_section_equipmentCondition_subtitle": "Terhelési küszöbök a szervizórákhoz",
  "equipmentConditionSettings_title": "Felszerelés állapota",
  "equipmentConditionSettings_thresholdsHeader": "Terhelési küszöbök",
  "equipmentConditionSettings_thresholdsHelp": "Egy merülés akkor számít hidegnek, mélynek vagy magas O2-tartalmúnak a szervizórák számára, ha átlépi ezeket a határokat.",
  "equipmentConditionSettings_coldLabel": "Hideg víz ez alatt",
  "equipmentConditionSettings_deepLabel": "Mély merülés ettől",
  "equipmentConditionSettings_o2Label": "Magas O2-tartalmú keverék e felett (% O2)",
  "equipmentConditionSettings_invalid": "Adjon meg egy számot",
```

### ar

```json
  "enum_equipmentType_o2Cell": "خلية أكسجين",
  "enum_equipmentType_battery": "بطارية",
  "attrLabel_cell_slot": "موضع الخلية",
  "attrLabel_installed_date": "تاريخ التركيب",
  "attrLabel_rechargeable": "قابلة لإعادة الشحن",
  "attrChoice_battery_type_alkaline": "قلوية",
  "attrChoice_battery_type_lithium_primary": "ليثيوم (غير قابلة لإعادة الشحن)",
  "equipment_scheduleDialog_intervalSaltHours": "الفاصل (ساعات في الماء المالح)",
  "equipment_scheduleDialog_intervalColdDives": "الفاصل (غطسات في الماء البارد)",
  "equipment_scheduleDialog_intervalO2Hours": "الفاصل (ساعات بأكسجين مرتفع)",
  "equipment_scheduleDialog_intervalDeepCycles": "الفاصل (غطسات عميقة)",
  "equipment_scheduleDialog_intervalCycles": "الفاصل (دورات البطارية)",
  "equipment_serviceClocks_saltHoursLeft": "تبقى {remaining} من {total} ساعة في الماء المالح",
  "equipment_serviceClocks_coldDivesLeft": "تبقى {remaining} من {total} غطسة في الماء البارد",
  "equipment_serviceClocks_o2HoursLeft": "تبقى {remaining} من {total} ساعة بأكسجين مرتفع",
  "equipment_serviceClocks_deepCyclesLeft": "تبقى {remaining} من {total} غطسة عميقة",
  "equipment_serviceClocks_cyclesLeft": "تبقى {remaining} من {total} دورة بطارية",
  "equipment_edit_parentLabel": "مركّب في",
  "equipment_edit_parentNone": "غير مركّب في أي شيء",
  "diveLog_tank_regulatorLabel": "منظم التنفس",
  "diveLog_tank_regulatorNone": "لا شيء",
  "settings_section_equipmentCondition_title": "حالة المعدات",
  "settings_section_equipmentCondition_subtitle": "حدود التعرض لساعات الصيانة",
  "equipmentConditionSettings_title": "حالة المعدات",
  "equipmentConditionSettings_thresholdsHeader": "حدود التعرض",
  "equipmentConditionSettings_thresholdsHelp": "تُحتسب الغطسة باردة أو عميقة أو بأكسجين مرتفع لساعات الصيانة عندما تتجاوز هذه الحدود.",
  "equipmentConditionSettings_coldLabel": "ماء بارد تحت",
  "equipmentConditionSettings_deepLabel": "غطسة عميقة من",
  "equipmentConditionSettings_o2Label": "خليط بأكسجين مرتفع فوق (% O2)",
  "equipmentConditionSettings_invalid": "أدخل رقمًا",
```

### he

```json
  "enum_equipmentType_o2Cell": "תא חמצן",
  "enum_equipmentType_battery": "סוללה",
  "attrLabel_cell_slot": "מיקום התא",
  "attrLabel_installed_date": "תאריך התקנה",
  "attrLabel_rechargeable": "נטענת",
  "attrChoice_battery_type_alkaline": "אלקליין",
  "attrChoice_battery_type_lithium_primary": "ליתיום (לא נטענת)",
  "equipment_scheduleDialog_intervalSaltHours": "מרווח (שעות במים מלוחים)",
  "equipment_scheduleDialog_intervalColdDives": "מרווח (צלילות במים קרים)",
  "equipment_scheduleDialog_intervalO2Hours": "מרווח (שעות בחמצן גבוה)",
  "equipment_scheduleDialog_intervalDeepCycles": "מרווח (צלילות עמוקות)",
  "equipment_scheduleDialog_intervalCycles": "מרווח (מחזורי סוללה)",
  "equipment_serviceClocks_saltHoursLeft": "נותרו {remaining} מתוך {total} שעות במים מלוחים",
  "equipment_serviceClocks_coldDivesLeft": "נותרו {remaining} מתוך {total} צלילות במים קרים",
  "equipment_serviceClocks_o2HoursLeft": "נותרו {remaining} מתוך {total} שעות בחמצן גבוה",
  "equipment_serviceClocks_deepCyclesLeft": "נותרו {remaining} מתוך {total} צלילות עמוקות",
  "equipment_serviceClocks_cyclesLeft": "נותרו {remaining} מתוך {total} מחזורי סוללה",
  "equipment_edit_parentLabel": "מותקן ב",
  "equipment_edit_parentNone": "לא מותקן בשום פריט",
  "diveLog_tank_regulatorLabel": "וסת",
  "diveLog_tank_regulatorNone": "ללא",
  "settings_section_equipmentCondition_title": "מצב הציוד",
  "settings_section_equipmentCondition_subtitle": "ספי חשיפה לשעוני תחזוקה",
  "equipmentConditionSettings_title": "מצב הציוד",
  "equipmentConditionSettings_thresholdsHeader": "ספי חשיפה",
  "equipmentConditionSettings_thresholdsHelp": "צלילה נחשבת קרה, עמוקה או בחמצן גבוה לשעוני התחזוקה כאשר היא חוצה ספים אלה.",
  "equipmentConditionSettings_coldLabel": "מים קרים מתחת ל",
  "equipmentConditionSettings_deepLabel": "צלילה עמוקה החל מ",
  "equipmentConditionSettings_o2Label": "תערובת בחמצן גבוה מעל (% O2)",
  "equipmentConditionSettings_invalid": "יש להזין מספר",
```

### zh

```json
  "enum_equipmentType_o2Cell": "氧电池",
  "enum_equipmentType_battery": "电池",
  "attrLabel_cell_slot": "电池槽位",
  "attrLabel_installed_date": "安装日期",
  "attrLabel_rechargeable": "可充电",
  "attrChoice_battery_type_alkaline": "碱性",
  "attrChoice_battery_type_lithium_primary": "锂（不可充电）",
  "equipment_scheduleDialog_intervalSaltHours": "间隔（海水小时数）",
  "equipment_scheduleDialog_intervalColdDives": "间隔（冷水潜水次数）",
  "equipment_scheduleDialog_intervalO2Hours": "间隔（高氧小时数）",
  "equipment_scheduleDialog_intervalDeepCycles": "间隔（深潜次数）",
  "equipment_scheduleDialog_intervalCycles": "间隔（电池循环次数）",
  "equipment_serviceClocks_saltHoursLeft": "海水小时数剩余 {remaining} / {total}",
  "equipment_serviceClocks_coldDivesLeft": "冷水潜水剩余 {remaining} / {total} 次",
  "equipment_serviceClocks_o2HoursLeft": "高氧小时数剩余 {remaining} / {total}",
  "equipment_serviceClocks_deepCyclesLeft": "深潜剩余 {remaining} / {total} 次",
  "equipment_serviceClocks_cyclesLeft": "电池循环剩余 {remaining} / {total} 次",
  "equipment_edit_parentLabel": "安装于",
  "equipment_edit_parentNone": "未安装",
  "diveLog_tank_regulatorLabel": "调节器",
  "diveLog_tank_regulatorNone": "无",
  "settings_section_equipmentCondition_title": "装备状况",
  "settings_section_equipmentCondition_subtitle": "保养计时的暴露阈值",
  "equipmentConditionSettings_title": "装备状况",
  "equipmentConditionSettings_thresholdsHeader": "暴露阈值",
  "equipmentConditionSettings_thresholdsHelp": "潜水越过这些界线时，保养计时将其计为冷水、深潜或高氧。",
  "equipmentConditionSettings_coldLabel": "冷水低于",
  "equipmentConditionSettings_deepLabel": "深潜达到或超过",
  "equipmentConditionSettings_o2Label": "高氧混合气高于（% O2）",
  "equipmentConditionSettings_invalid": "请输入数字",
```
