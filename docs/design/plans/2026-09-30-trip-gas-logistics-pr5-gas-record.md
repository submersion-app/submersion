# Trip Gas Logistics PR 5: Gas Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A trip's gas record: a Record tab on the cylinder board listing every dive tank breathed from a trip cylinder (with the bottle, analysis and fill in effect when the dive started), totals (fills, dives and litres per slot, cost by currency), a list of dive tanks not linked to any cylinder, and a CSV export of the rows.

**Architecture:** No schema. Two lean repository queries feed a pure `buildTripGasRecord`, which attributes each tank to its fill by reusing the state fold (`foldCylinderState` over the slot's events up to the dive's entry), so the record and the board can never disagree about a bottle. `tripGasRecordProvider` gathers the inputs; a `TripCylinderRecordView` renders them as the board's third segment; a `CsvTripGasRecordWriter` follows the unit-aware CSV convention of the fills export (#2631) behind the `ExportService` facade.

**Tech Stack:** Flutter, Riverpod (via `core/providers/provider.dart`), Drift (in-memory in tests), `package:csv`, `flutter gen-l10n` (11 locales).

**Spec:** `docs/design/specs/2026-09-25-trip-gas-logistics-design.md` (sections "Phase 3" (no schema), "Deriving a slot's state", "Phase 3 gas record", "Delivery" item 5).

## Global Constraints

- Branch `ericgriffin/trip-gas-record`, cut from `origin/main` after PR 4 (#2630) merged. The PR body carries `Closes #2325` (the last PR of the program).
- No schema change, no new sync registration.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, strings, commits, PR text).
- No tool attribution of any kind (the contributor guide's Attribution section) in commits, PR text or review replies; no co-author trailer.
- Every new string in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`. German, Spanish and Italian use the informal register the neighbouring trip cylinder strings use; a Spanish string must not add "tú" (the diacritics guard pairs it with the possessive "tu").
- Pressures, volumes, dates and times go through `UnitFormatter` on screen and `CsvExportUnits` in the CSV.
- Gas quantities use `gasVolume` from `lib/core/utils/gas_compressibility.dart` with the diver's `gasModelProvider`.
- Imports grouped dart, flutter, packages, local; `dart format .`; `dart analyze --fatal-infos <touched files>` prints "No issues found!" before each commit; new files stay under 400 lines.
- TDD: every task starts with a failing test. Run tests with `TMPDIR=<scratchpad>/tmp flutter test <paths>`, never overlapping runs.
- A provider that reads a table subscribes to its change tick (architecture guard `provider_change_tick_test.dart`).

### Decided with the user (2026-09-30)

- **Every diver's tanks.** The record lists every linked tank on the trip's dives, whoever logged it, with the diver's name on each row when the trip has more than one diver, so its totals match the board.
- **The CSV holds the dive rows only.** One line per linked tank; totals stay on screen.
- **Gaps open a list.** Tapping the gaps line opens a list of the unlinked dive tanks; each opens its dive's editor.
- **No size, no litres.** A tank with no volume shows "--" for gas breathed; a slot's total adds only the tanks with a figure and says how many it left out. No fallback to the slot's size.

### Rulings in this plan (for the user's review)

- **R1, attribution by reuse.** A tank's bottle, fill and analysis come from `foldCylinderState(cylinder, events at or before the tank's entry, uses: [])`: `lastFill` is the fill in effect, `bottleLabel` carries a bottle through refills that name none. This is the rule `tripCylinderLabelsAt` (the dive detail line) already uses, so the record and the dive page agree.
- **R2, fill pressure.** The fill's pressure, else the slot's working pressure (the fold's rule for a fill with no reading); blank when no fill precedes the dive.
- **R3, left out.** Any row with no gas figure (no tank volume, or a missing start or end pressure) shows "--" and counts as "left out" in its slot's total, not only a missing size. A negative figure (end above start) counts as 0 L.
- **R4, gaps.** A gap is a tank on a non-planned trip dive whose `trip_cylinder_id` is null or names a slot of another trip. Planned dives are left out (no gas was breathed). A multi-computer dive's per-computer tank rows each count, as the dive editor shows each.
- **R5, CSV columns.** Always a Diver column (a stable layout for spreadsheets), the ordered and analyzed mix as separate O2/He columns, fill, start and end pressure, gas breathed and the fill station's name. File name `gas_record_<trip name>_<yyyy-MM-dd>.csv`, the trip name reduced to letters, digits and underscores.
- **R6, export entry.** An "Export CSV" button in the Record view's header, through `showExportDestinationSheetWithOptions` with the CSV units toggle (share or save), like the other CSV exports.

## Review Focus

1. A bottle swapped mid-week is credited correctly on both sides of the swap, including a fill at the dive's own minute (it counts for that dive). Pinned in Task 1 ("a swap credits each dive to its own bottle", "a fill at the dive's minute counts for it").
2. A shared trip with two diver profiles lists both divers' tanks with names, and a single-diver trip shows no names. Pinned in Task 1 ("more than one diver") and Task 6 ("names show only with more than one diver").
3. Costs never add different currencies, a fill with no currency is the diver's default, and package fills are counted, not summed. Pinned in Task 1 ("cost by currency, packages counted").
4. The CSV converts to the diver's units in My units mode and stays canonical in Metric mode, and a formula-looking site name cannot execute in a spreadsheet. Pinned in Task 5 ("imperial mode converts", "a formula-looking name is neutralised").
5. A tank on a planned dive, or linked to another trip's slot, is handled as R4 says. Pinned in Task 2 ("unlinked tanks skip planned dives, include foreign links").

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/trips/domain/entities/trip_gas_record.dart` | Record input rows, output rows, slot totals, the record |
| Create `lib/features/trips/domain/services/trip_gas_record_builder.dart` | Pure `buildTripGasRecord` |
| Modify `lib/features/trips/data/repositories/trip_cylinder_repository.dart` | `getGasRecordTanksForTrip`, `getUnlinkedTanksForTrip` |
| Create `lib/features/trips/presentation/providers/trip_gas_record_providers.dart` | `tripGasRecordProvider` |
| Modify all 11 `lib/l10n/arb/app_*.arb` + generated files | 10 new keys |
| Modify `lib/core/services/export/csv/codec/csv_column.dart` | Two record columns |
| Create `lib/core/services/export/csv/csv_trip_gas_record_writer.dart` | The CSV rows |
| Modify `lib/core/services/export/csv/csv_export_service.dart`, `lib/core/services/export/export_service.dart` | Share and save the record CSV |
| Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart` | The Record segment: totals, gaps, rows, export |
| Modify `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart` | Three segments |

---

### Task 1: The pure record

**Files:**
- Create: `lib/features/trips/domain/entities/trip_gas_record.dart`
- Create: `lib/features/trips/domain/services/trip_gas_record_builder.dart`
- Test: `test/features/trips/domain/services/trip_gas_record_builder_test.dart`

**Interfaces:**
- Consumes: `foldCylinderState` (trip_cylinder_state_fold.dart), `gasVolume` (core/utils/gas_compressibility.dart), `GasModel` (core/constants/gas_model.dart), `sumByCurrency` (core/utils/currency.dart), `TripCylinder`, `TripCylinderEvent`, `GasMix`.
- Produces:
  - `class TripGasRecordTank { tankId, diveId, DateTime entryTime, String? diverId, String? diverName, String? siteName, int tankOrder, double? volume, double? startPressure, double? endPressure, GasMix gasMix, String tripCylinderId }`
  - `class TripUnlinkedTank { tankId, diveId, DateTime entryTime, String? diverId, String? diverName, String? siteName, int tankOrder }`
  - `class TripGasRecordRow { TripGasRecordTank tank; TripCylinder cylinder; String bottleLabel; TripCylinderEvent? fill; double? fillPressure; double? litres }` with getters `orderedMix`, `analyzedMix`, `diveCenterId`
  - `class TripGasRecordSlotTotal { TripCylinder cylinder; int dives; double litres; int leftOut }`
  - `class TripGasRecord { List<TripGasRecordRow> rows; List<TripGasRecordSlotTotal> slots; int fillsLogged; List<MapEntry<String, double>> costs; int packageFills; List<TripUnlinkedTank> unlinked; bool multipleDivers }`
  - `TripGasRecord buildTripGasRecord({required List<TripCylinder> cylinders, required Map<String, List<TripCylinderEvent>> eventsBySlot, required List<TripGasRecordTank> tanks, List<TripUnlinkedTank> unlinked = const [], required GasModel gasModel, required String defaultCurrency})`

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/domain/services/trip_gas_record_builder_test.dart`. Every figure is worked by hand in its comment.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_gas_record_builder.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, day, hour, minute);

  TripCylinder slot(String id, String label, int order) => TripCylinder(
    id: id,
    tripId: 't1',
    label: label,
    volume: 11.1,
    workingPressure: 207,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(
    String id,
    String slotId,
    DateTime when, {
    String? bottle,
    double? pressure,
    double o2 = 32,
    double? analyzedO2,
    String? center,
    double? cost,
    String? currency,
    bool package = false,
  }) => TripCylinderEvent(
    id: id,
    tripCylinderId: slotId,
    kind: TripCylinderEventKind.fill,
    occurredAt: when,
    bottleLabel: bottle,
    pressure: pressure,
    o2Percent: o2,
    analyzedO2: analyzedO2,
    diveCenterId: center,
    cost: cost,
    currency: currency,
    isPackage: package,
    createdAt: when,
    updatedAt: when,
  );

  TripGasRecordTank tank(
    String id,
    String diveId,
    String slotId,
    DateTime when, {
    int order = 0,
    double? volume = 11.1,
    double? start,
    double? end,
    double o2 = 32,
    String? diver,
  }) => TripGasRecordTank(
    tankId: id,
    diveId: diveId,
    entryTime: when,
    diverId: diver,
    diverName: diver == null ? null : 'Diver $diver',
    siteName: 'Salt Pier',
    tankOrder: order,
    volume: volume,
    startPressure: start,
    endPressure: end,
    gasMix: GasMix(o2: o2),
    tripCylinderId: slotId,
  );

  final a = slot('a', 'Truck 1', 0);
  final b = slot('b', 'Truck 2', 1);
  // Truck 1: bottle 14 on Mar 9, swapped for bottle 22 on Mar 11 (a fill
  // with no reading, so the working pressure); a correction that evening.
  // Truck 2: one package fill, no bottle named.
  final events = {
    'a': [
      fill(
        'f1',
        'a',
        at(9, 7),
        bottle: '14',
        pressure: 200,
        analyzedO2: 31.8,
        center: 'c1',
        cost: 10,
        currency: 'USD',
      ),
      fill('f2', 'a', at(11, 7), bottle: '22', cost: 12),
      TripCylinderEvent(
        id: 'x1',
        tripCylinderId: 'a',
        kind: TripCylinderEventKind.adjustment,
        occurredAt: at(11, 18),
        pressure: 60,
        createdAt: at(11, 18),
        updatedAt: at(11, 18),
      ),
    ],
    'b': [
      fill('g1', 'b', at(9, 7, 30), pressure: 210, o2: 21, cost: 8, package: true),
    ],
  };

  TripGasRecord record({
    List<TripGasRecordTank>? tanks,
    GasModel model = GasModel.ideal,
    String currency = 'USD',
    List<TripUnlinkedTank> unlinked = const [],
  }) => buildTripGasRecord(
    cylinders: [a, b],
    eventsBySlot: events,
    tanks:
        tanks ??
        [
          tank('t2', 'd2', 'a', at(11, 9), volume: null, start: 207, end: 50),
          tank('t3', 'd1', 'b', at(9, 9), order: 1, start: 210, end: 100, o2: 21),
          tank('t1', 'd1', 'a', at(9, 9), start: 200, end: 60),
        ],
    unlinked: unlinked,
    gasModel: model,
    defaultCurrency: currency,
  );

  test('rows come in dive order, then tank order', () {
    expect(record().rows.map((r) => r.tank.tankId), ['t1', 't3', 't2']);
  });

  test('a swap credits each dive to its own bottle', () {
    final rows = {for (final r in record().rows) r.tank.tankId: r};
    // Mar 9 dive: bottle 14, filled to 200 at c1, analyzed 31.8.
    expect(rows['t1']!.bottleLabel, '14');
    expect(rows['t1']!.fill!.id, 'f1');
    expect(rows['t1']!.fillPressure, 200);
    expect(rows['t1']!.diveCenterId, 'c1');
    expect(rows['t1']!.analyzedMix!.o2, 31.8);
    expect(rows['t1']!.orderedMix!.o2, 32);
    // Mar 11 dive: bottle 22, a fill with no reading, so 207 (working).
    expect(rows['t2']!.bottleLabel, '22');
    expect(rows['t2']!.fill!.id, 'f2');
    expect(rows['t2']!.fillPressure, 207);
    expect(rows['t2']!.analyzedMix, isNull);
    // Truck 2 never named a bottle: the slot's own label.
    expect(rows['t3']!.bottleLabel, 'Truck 2');
  });

  test('a fill at the dive\'s minute counts for it', () {
    final r = record(
      tanks: [tank('t9', 'd9', 'a', at(11, 7), start: 207, end: 80)],
    );
    expect(r.rows.single.fill!.id, 'f2');
  });

  test('a dive before any fill has no fill and no fill pressure', () {
    final r = record(
      tanks: [tank('t0', 'd0', 'a', at(8, 9), start: 200, end: 50)],
    );
    expect(r.rows.single.fill, isNull);
    expect(r.rows.single.fillPressure, isNull);
    expect(r.rows.single.bottleLabel, 'Truck 1');
  });

  test('litres breathed, ideal gas', () {
    final rows = {for (final r in record().rows) r.tank.tankId: r};
    // 11.1 L x (200 - 60) bar = 1554 L.
    expect(rows['t1']!.litres, closeTo(1554, 0.001));
    // 11.1 L x (210 - 100) bar = 1221 L.
    expect(rows['t3']!.litres, closeTo(1221, 0.001));
    // No tank volume: no figure (decided 2026-09-30).
    expect(rows['t2']!.litres, isNull);
  });

  test('a real gas carries fewer litres than an ideal one at 200 bar', () {
    final rows = {
      for (final r in record(model: GasModel.real).rows) r.tank.tankId: r,
    };
    expect(rows['t1']!.litres, lessThan(1554));
    expect(rows['t1']!.litres, greaterThan(1400));
  });

  test('a missing pressure leaves the row out; end above start is 0 L', () {
    final r = record(
      tanks: [
        tank('u1', 'd5', 'a', at(9, 9), start: null, end: 60),
        tank('u2', 'd6', 'a', at(9, 11), start: 50, end: 60),
      ],
    );
    expect(r.rows.first.litres, isNull);
    expect(r.rows.last.litres, 0);
  });

  test('slot totals: dives, litres, and how many were left out', () {
    final totals = {for (final s in record().slots) s.cylinder.id: s};
    // Truck 1: two dives, 1554 L from t1, t2 left out (no size).
    expect(totals['a']!.dives, 2);
    expect(totals['a']!.litres, closeTo(1554, 0.001));
    expect(totals['a']!.leftOut, 1);
    // Truck 2: one dive, 1221 L.
    expect(totals['b']!.dives, 1);
    expect(totals['b']!.leftOut, 0);
    // Board order.
    expect(record().slots.map((s) => s.cylinder.id), ['a', 'b']);
  });

  test('fills logged counts every fill on the trip', () {
    expect(record().fillsLogged, 3);
  });

  test('cost by currency, packages counted', () {
    // USD 10, and 12 with no currency, which is the diver's default (USD):
    // 22 USD. The package fill (8) is counted, not summed.
    final usd = record();
    expect(usd.costs, hasLength(1));
    expect(usd.costs.single.key, 'USD');
    expect(usd.costs.single.value, 22);
    expect(usd.packageFills, 1);
    // With a EUR default the 12 is EUR: EUR 12 then USD 10 (largest first).
    final eur = record(currency: 'EUR');
    expect([for (final c in eur.costs) '${c.key} ${c.value}'], [
      'EUR 12.0',
      'USD 10.0',
    ]);
  });

  test('more than one diver', () {
    expect(record().multipleDivers, isFalse);
    final shared = record(
      tanks: [
        tank('t1', 'd1', 'a', at(9, 9), start: 200, end: 60, diver: 'x'),
        tank('t4', 'd4', 'a', at(9, 9), start: 200, end: 70, diver: 'y'),
      ],
    );
    expect(shared.multipleDivers, isTrue);
  });

  test('unlinked tanks pass through in dive order', () {
    final r = record(
      unlinked: [
        TripUnlinkedTank(
          tankId: 'n2',
          diveId: 'd8',
          entryTime: at(12, 9),
          tankOrder: 0,
        ),
        TripUnlinkedTank(
          tankId: 'n1',
          diveId: 'd7',
          entryTime: at(10, 9),
          tankOrder: 0,
        ),
      ],
    );
    expect(r.unlinked.map((u) => u.tankId), ['n1', 'n2']);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/trip_gas_record_builder_test.dart`
Expected: FAIL to compile: `trip_gas_record.dart` does not exist.

- [ ] **Step 3: The entities**

Create `lib/features/trips/domain/entities/trip_gas_record.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// A dive tank breathed from one of the trip's slots, as the record reads
/// it: the lean facts plus the diver, the site and the tank's size.
/// [entryTime] is wall-clock-as-UTC, the frame every dive time uses.
class TripGasRecordTank extends Equatable {
  const TripGasRecordTank({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.diverId,
    this.diverName,
    this.siteName,
    this.tankOrder = 0,
    this.volume,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
    required this.tripCylinderId,
  });

  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final String? diverId;
  final String? diverName;
  final String? siteName;
  final int tankOrder;

  /// Water volume in litres.
  final double? volume;
  final double? startPressure;
  final double? endPressure;
  final GasMix gasMix;
  final String tripCylinderId;

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    diverId,
    diverName,
    siteName,
    tankOrder,
    volume,
    startPressure,
    endPressure,
    gasMix,
    tripCylinderId,
  ];
}

/// A tank on one of the trip's dives that breathes from no slot of the
/// trip: the record's gaps.
class TripUnlinkedTank extends Equatable {
  const TripUnlinkedTank({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.diverId,
    this.diverName,
    this.siteName,
    this.tankOrder = 0,
  });

  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final String? diverId;
  final String? diverName;
  final String? siteName;
  final int tankOrder;

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    diverId,
    diverName,
    siteName,
    tankOrder,
  ];
}

/// One row of the record: a tank, its slot, and the fill in effect when the
/// dive started.
class TripGasRecordRow extends Equatable {
  const TripGasRecordRow({
    required this.tank,
    required this.cylinder,
    required this.bottleLabel,
    this.fill,
    this.fillPressure,
    this.litres,
  });

  final TripGasRecordTank tank;
  final TripCylinder cylinder;

  /// The bottle the slot held (the slot's own label when no fill named one).
  final String bottleLabel;
  final TripCylinderEvent? fill;

  /// The fill's reading, else the slot's working pressure; null with no
  /// fill before the dive.
  final double? fillPressure;

  /// Gas breathed in free litres; null when the tank has no volume or a
  /// pressure is missing.
  final double? litres;

  GasMix? get orderedMix => fill?.orderedMix;
  GasMix? get analyzedMix => fill?.analyzedMix;
  String? get diveCenterId => fill?.diveCenterId;

  @override
  List<Object?> get props => [
    tank,
    cylinder,
    bottleLabel,
    fill,
    fillPressure,
    litres,
  ];
}

/// One slot's totals.
class TripGasRecordSlotTotal extends Equatable {
  const TripGasRecordSlotTotal({
    required this.cylinder,
    required this.dives,
    required this.litres,
    required this.leftOut,
  });

  final TripCylinder cylinder;

  /// Distinct dives that breathed from the slot.
  final int dives;

  /// Litres over the rows that have a figure.
  final double litres;

  /// Rows with no figure, left out of [litres].
  final int leftOut;

  @override
  List<Object?> get props => [cylinder, dives, litres, leftOut];
}

/// The trip's gas record (spec "Phase 3 gas record").
class TripGasRecord extends Equatable {
  const TripGasRecord({
    required this.rows,
    required this.slots,
    required this.fillsLogged,
    required this.costs,
    required this.packageFills,
    required this.unlinked,
    required this.multipleDivers,
  });

  final List<TripGasRecordRow> rows;
  final List<TripGasRecordSlotTotal> slots;
  final int fillsLogged;

  /// Non-package fill costs by currency, largest first.
  final List<MapEntry<String, double>> costs;
  final int packageFills;
  final List<TripUnlinkedTank> unlinked;

  /// More than one diver logged the tanks, so each row names its diver.
  final bool multipleDivers;

  @override
  List<Object?> get props => [
    rows,
    slots,
    fillsLogged,
    [for (final c in costs) '${c.key}:${c.value}'],
    packageFills,
    unlinked,
    multipleDivers,
  ];
}
```

- [ ] **Step 4: The builder**

Create `lib/features/trips/domain/services/trip_gas_record_builder.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure. The trip's gas record. Each tank's bottle, fill and analysis come
/// from the state fold over the slot's events up to the dive's entry (a
/// fill at the dive's own minute was for that dive), the rule the dive
/// detail line uses, so a bottle swapped mid-week is credited correctly on
/// both sides of the swap. Rows run in dive order, then tank order.
TripGasRecord buildTripGasRecord({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required List<TripGasRecordTank> tanks,
  List<TripUnlinkedTank> unlinked = const [],
  required GasModel gasModel,
  required String defaultCurrency,
}) {
  final bySlot = {for (final c in cylinders) c.id: c};
  final ordered = [...tanks]..sort(_byDive);
  final rows = [
    for (final t in ordered)
      if (bySlot[t.tripCylinderId] case final cylinder?)
        _row(t, cylinder, eventsBySlot[cylinder.id] ?? const [], gasModel),
  ];

  final slots = [
    for (final c in cylinders)
      () {
        final mine = rows.where((r) => r.cylinder.id == c.id).toList();
        return TripGasRecordSlotTotal(
          cylinder: c,
          dives: {for (final r in mine) r.tank.diveId}.length,
          litres: mine.fold(0.0, (sum, r) => sum + (r.litres ?? 0)),
          leftOut: mine.where((r) => r.litres == null).length,
        );
      }(),
  ];

  final fills = [
    for (final list in eventsBySlot.values)
      for (final e in list)
        if (e.kind == TripCylinderEventKind.fill) e,
  ];
  final divers = {
    for (final t in tanks) ?t.diverId,
    for (final u in unlinked) ?u.diverId,
  };

  return TripGasRecord(
    rows: rows,
    slots: slots,
    fillsLogged: fills.length,
    costs: sumByCurrency(
      fills,
      amountOf: (e) => e.isPackage ? null : e.cost,
      currencyOf: (e) => e.currency ?? '',
      fallbackCode: defaultCurrency,
    ),
    packageFills: fills.where((e) => e.isPackage).length,
    unlinked: [...unlinked]..sort(_byUnlinked),
    multipleDivers: divers.length > 1,
  );
}

TripGasRecordRow _row(
  TripGasRecordTank t,
  TripCylinder cylinder,
  List<TripCylinderEvent> events,
  GasModel gasModel,
) {
  final atMillis = t.entryTime.millisecondsSinceEpoch;
  final state = foldCylinderState(
    cylinder: cylinder,
    events: [
      for (final e in events)
        if (e.occurredAt.millisecondsSinceEpoch <= atMillis) e,
    ],
    uses: const [],
  );
  final fill = state.lastFill;
  return TripGasRecordRow(
    tank: t,
    cylinder: cylinder,
    bottleLabel: state.bottleLabel,
    fill: fill,
    fillPressure: fill == null
        ? null
        : fill.pressure ?? cylinder.workingPressure,
    litres: _litres(t, gasModel),
  );
}

/// Free litres breathed from [t]: the gas at its start pressure less the
/// gas at its end, at the tank's mix. Null without a volume or either
/// pressure; an end above the start is 0.
double? _litres(TripGasRecordTank t, GasModel model) {
  final volume = t.volume;
  final start = t.startPressure;
  final end = t.endPressure;
  if (volume == null || start == null || end == null) return null;
  double at(double bar) => gasVolume(
    tankSizeLiters: volume,
    pressureBar: bar,
    o2Percent: t.gasMix.o2,
    hePercent: t.gasMix.he,
    model: model,
  );
  return math.max(0, at(start) - at(end));
}

int _byDive(TripGasRecordTank a, TripGasRecordTank b) {
  final byTime = a.entryTime.compareTo(b.entryTime);
  if (byTime != 0) return byTime;
  final byDive = a.diveId.compareTo(b.diveId);
  return byDive != 0 ? byDive : a.tankOrder.compareTo(b.tankOrder);
}

int _byUnlinked(TripUnlinkedTank a, TripUnlinkedTank b) {
  final byTime = a.entryTime.compareTo(b.entryTime);
  if (byTime != 0) return byTime;
  final byDive = a.diveId.compareTo(b.diveId);
  return byDive != 0 ? byDive : a.tankOrder.compareTo(b.tankOrder);
}
```

- [ ] **Step 5: Run the tests, then the trips domain suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/domain/entities/trip_gas_record.dart lib/features/trips/domain/services/trip_gas_record_builder.dart test/features/trips/domain/services/trip_gas_record_builder_test.dart
git commit -m "feat(trips): the pure gas record (#2325)"
```

---

### Task 2: The record's queries

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_cylinder_repository.dart` (after `getTankUsesForTrip`)
- Test: `test/features/trips/data/repositories/trip_gas_record_queries_test.dart`

**Interfaces:**
- Consumes: `TripGasRecordTank`, `TripUnlinkedTank` (Task 1).
- Produces:
  - `Future<List<TripGasRecordTank>> TripCylinderRepository.getGasRecordTanksForTrip(String tripId)`
  - `Future<List<TripUnlinkedTank>> TripCylinderRepository.getUnlinkedTanksForTrip(String tripId)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/data/repositories/trip_gas_record_queries_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repository;
  late String tripId;
  late String otherTripId;
  late TripCylinder slot;
  late TripCylinder foreignSlot;

  final at = DateTime.utc(2026, 3, 9, 9);

  Future<String> trip(String name) async => (await TripRepository().createTrip(
    Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  )).id;

  Future<TripCylinder> cylinder(String trip, String label) =>
      repository.createCylinder(
        TripCylinder(
          id: '',
          tripId: trip,
          label: label,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<void> dive(
    String id,
    int hour, {
    String? trip,
    String? diver,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: DateTime.utc(2026, 3, 9, hour).millisecondsSinceEpoch,
          tripId: Value(trip ?? tripId),
          diverId: Value(diver),
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(isPlanned: Value(planned)),
      );

  Future<void> tankOn(
    String id,
    String diveId, {
    String? slotId,
    int order = 0,
    double? volume,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          tripCylinderId: Value(slotId),
          tankOrder: Value(order),
          volume: Value(volume),
          startPressure: const Value(200),
          endPressure: const Value(60),
          o2Percent: const Value(32),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripCylinderRepository();
    tripId = await trip('Bonaire');
    otherTripId = await trip('Curacao');
    slot = await cylinder(tripId, 'Truck 1');
    foreignSlot = await cylinder(otherTripId, 'Reef 1');
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Diver $id',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('record tanks carry the diver, size and mix, in dive order', () async {
    await dive('d2', 11, diver: 'b');
    await dive('d1', 9, diver: 'a');
    await tankOn('t2', 'd2', slotId: slot.id, volume: 11.1);
    await tankOn('t1', 'd1', slotId: slot.id, volume: 12);
    await tankOn('t0', 'd1'); // unlinked: not a record tank
    final tanks = await repository.getGasRecordTanksForTrip(tripId);
    expect(tanks.map((t) => t.tankId), ['t1', 't2']);
    expect(tanks.first.diverName, 'Diver a');
    expect(tanks.first.volume, 12);
    expect(tanks.first.startPressure, 200);
    expect(tanks.first.gasMix.o2, 32);
    expect(tanks.first.entryTime, DateTime.utc(2026, 3, 9, 9));
    expect(tanks.first.tripCylinderId, slot.id);
  });

  test('unlinked tanks skip planned dives, include foreign links', () async {
    await dive('d1', 9, diver: 'a');
    await dive('d3', 13, planned: true);
    await dive('d4', 15, trip: otherTripId);
    await tankOn('t1', 'd1', slotId: slot.id);
    await tankOn('t2', 'd1', order: 1); // no link: a gap
    await tankOn('t3', 'd1', order: 2, slotId: foreignSlot.id); // other trip
    await tankOn('t4', 'd3'); // planned dive: not a gap
    await tankOn('t5', 'd4'); // another trip's dive: not ours
    final gaps = await repository.getUnlinkedTanksForTrip(tripId);
    expect(gaps.map((g) => g.tankId), ['t2', 't3']);
    expect(gaps.first.diverName, 'Diver a');
    expect(gaps.first.diveId, 'd1');
  });

  test('a trip with no dives has an empty record', () async {
    expect(await repository.getGasRecordTanksForTrip(tripId), isEmpty);
    expect(await repository.getUnlinkedTanksForTrip(tripId), isEmpty);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/data/repositories/trip_gas_record_queries_test.dart`
Expected: FAIL to compile: the two methods are undefined.

- [ ] **Step 3: Write the queries**

In `trip_cylinder_repository.dart` (import `trip_gas_record.dart`), after `getTankUsesForTrip`:

```dart

  /// The trip's linked dive tanks for the gas record: the lean facts the
  /// fold reads plus the diver, the site and the tank's size. Every diver's
  /// tanks (decided 2026-09-30), in dive order, then tank order.
  Future<List<TripGasRecordTank>> getGasRecordTanksForTrip(
    String tripId,
  ) async {
    final rows = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the record counts every dive on the trip,
          -- as the board does
          SELECT t.id AS tank_id, t.dive_id,
                 COALESCE(d.entry_time, d.dive_date_time) AS entry_ms,
                 d.diver_id, v.name AS diver_name, s.name AS site_name,
                 t.tank_order, t.volume, t.start_pressure, t.end_pressure,
                 t.o2_percent, t.he_percent, t.trip_cylinder_id
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          LEFT JOIN divers v ON v.id = d.diver_id
          LEFT JOIN dive_sites s ON s.id = d.site_id
          WHERE d.trip_id = ?1
            AND t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?1)
          ORDER BY entry_ms ASC, t.dive_id ASC, t.tank_order ASC
          ''',
          variables: [Variable.withString(tripId)],
          readsFrom: {
            _db.diveTanks,
            _db.dives,
            _db.divers,
            _db.diveSites,
            _db.tripCylinders,
          },
        )
        .get();
    return [
      for (final r in rows)
        TripGasRecordTank(
          tankId: r.read<String>('tank_id'),
          diveId: r.read<String>('dive_id'),
          entryTime: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('entry_ms'),
            isUtc: true,
          ),
          diverId: r.readNullable<String>('diver_id'),
          diverName: r.readNullable<String>('diver_name'),
          siteName: r.readNullable<String>('site_name'),
          tankOrder: r.read<int>('tank_order'),
          volume: r.readNullable<double>('volume'),
          startPressure: r.readNullable<double>('start_pressure'),
          endPressure: r.readNullable<double>('end_pressure'),
          gasMix: GasMix(
            o2: r.read<double>('o2_percent'),
            he: r.read<double>('he_percent'),
          ),
          tripCylinderId: r.read<String>('trip_cylinder_id'),
        ),
    ];
  }

  /// Tanks on the trip's dives that breathe from no slot of the trip: no
  /// link, or a link to another trip's slot. Planned dives are left out:
  /// no gas was breathed on them.
  Future<List<TripUnlinkedTank>> getUnlinkedTanksForTrip(String tripId) async {
    final rows = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the gaps count every dive on the trip, as
          -- the board does
          SELECT t.id AS tank_id, t.dive_id,
                 COALESCE(d.entry_time, d.dive_date_time) AS entry_ms,
                 d.diver_id, v.name AS diver_name, s.name AS site_name,
                 t.tank_order
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          LEFT JOIN divers v ON v.id = d.diver_id
          LEFT JOIN dive_sites s ON s.id = d.site_id
          WHERE d.trip_id = ?1
            AND d.is_planned = 0
            AND (t.trip_cylinder_id IS NULL
                 OR t.trip_cylinder_id NOT IN
                    (SELECT id FROM trip_cylinders WHERE trip_id = ?1))
          ORDER BY entry_ms ASC, t.dive_id ASC, t.tank_order ASC
          ''',
          variables: [Variable.withString(tripId)],
          readsFrom: {
            _db.diveTanks,
            _db.dives,
            _db.divers,
            _db.diveSites,
            _db.tripCylinders,
          },
        )
        .get();
    return [
      for (final r in rows)
        TripUnlinkedTank(
          tankId: r.read<String>('tank_id'),
          diveId: r.read<String>('dive_id'),
          entryTime: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('entry_ms'),
            isUtc: true,
          ),
          diverId: r.readNullable<String>('diver_id'),
          diverName: r.readNullable<String>('diver_name'),
          siteName: r.readNullable<String>('site_name'),
          tankOrder: r.read<int>('tank_order'),
        ),
    ];
  }
```

- [ ] **Step 4: Run the tests, then the trips data suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/data test/core/database/dive_stats_scope_census_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/data/repositories/trip_cylinder_repository.dart test/features/trips/data/repositories/trip_gas_record_queries_test.dart
git commit -m "feat(trips): the gas record's queries (#2325)"
```

---

### Task 3: The record provider

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_gas_record_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_gas_record_providers_test.dart`

**Interfaces:**
- Consumes: `buildTripGasRecord` (Task 1), the Task 2 queries, `tripCylinderRepositoryProvider`, `gasModelProvider`, `defaultCurrencyProvider`.
- Produces: `final tripGasRecordProvider = FutureProvider.autoDispose.family<TripGasRecord, String>`

- [ ] **Step 1: Write the failing test**

Create `test/features/trips/presentation/providers/trip_gas_record_providers_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository cylinders;
  late String tripId;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        gasModelProvider.overrideWithValue(GasModel.ideal),
        defaultCurrencyProvider.overrideWithValue('USD'),
      ],
    );
    addTearDown(container.dispose);
    cylinders = TripCylinderRepository();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  test('gathers slots, fills, tanks and gaps into the record', () async {
    final at = DateTime.utc(2026, 3, 9, 7);
    final slot = await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await cylinders.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: slot.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: at,
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        cost: 10,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 3, 9, 9).millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, link) in [('t1', slot.id), ('t2', null)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: id, diveId: 'd1').copyWith(
              tripCylinderId: Value(link),
              volume: const Value(11.1),
              startPressure: const Value(200),
              endPressure: const Value(60),
              o2Percent: const Value(32),
            ),
          );
    }

    final record = await container.read(tripGasRecordProvider(tripId).future);
    expect(record.rows.single.bottleLabel, '14');
    // 11.1 L x 140 bar, ideal gas.
    expect(record.rows.single.litres, closeTo(1554, 0.001));
    expect(record.fillsLogged, 1);
    expect(record.costs.single.key, 'USD');
    expect(record.unlinked.single.tankId, 't2');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/providers/trip_gas_record_providers_test.dart`
Expected: FAIL to compile: the provider file does not exist.

- [ ] **Step 3: Write the provider**

Create `lib/features/trips/presentation/providers/trip_gas_record_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_gas_record_builder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

/// The trip's gas record (spec "Phase 3 gas record"). Rebuilds when the
/// trip's slots, fills, dives, tanks or sites change, and when the diver's
/// gas model or default currency does. Auto-disposed: only the Record tab
/// reads it.
final tripGasRecordProvider = FutureProvider.autoDispose
    .family<TripGasRecord, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
      final gasModel = ref.watch(gasModelProvider);
      final currency = ref.watch(defaultCurrencyProvider);
      final (cylinders, events, tanks, unlinked) = await (
        repository.getCylindersForTrip(tripId),
        repository.getEventsForTrip(tripId),
        repository.getGasRecordTanksForTrip(tripId),
        repository.getUnlinkedTanksForTrip(tripId),
      ).wait;
      return buildTripGasRecord(
        cylinders: cylinders,
        eventsBySlot: events,
        tanks: tanks,
        unlinked: unlinked,
        gasModel: gasModel,
        defaultCurrency: currency,
      );
    });
```

- [ ] **Step 4: Run the test, the trips suite and the architecture guards**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips test/architecture`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/providers/trip_gas_record_providers.dart test/features/trips/presentation/providers/trip_gas_record_providers_test.dart
git commit -m "feat(trips): the gas record provider (#2325)"
```

---

### Task 4: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`

**Interfaces:**
- Produces: `trips_cylinders_segment_record`, `trips_cylinders_recordEmpty`, `trips_cylinders_record_fillsLogged(int count)`, `trips_cylinders_record_leftOut(int count)`, `trips_cylinders_record_packageFills(int count)`, `trips_cylinders_record_unlinked(int count)`, `trips_cylinders_record_unlinkedTitle`, `trips_cylinders_record_tank(int number)`, `trips_cylinders_record_filled(String pressure)`, `trips_cylinders_record_analyzed(String mix)`.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `trip_cylinder_display_test.dart`:

```dart

  test('the gas record strings exist in English', () {
    expect(l10n.trips_cylinders_segment_record, 'Record');
    expect(
      l10n.trips_cylinders_recordEmpty,
      'No dives breathed from these cylinders yet.',
    );
    expect(l10n.trips_cylinders_record_fillsLogged(1), '1 fill logged');
    expect(l10n.trips_cylinders_record_fillsLogged(3), '3 fills logged');
    expect(l10n.trips_cylinders_record_leftOut(1), '1 dive left out');
    expect(l10n.trips_cylinders_record_packageFills(2), '2 package fills');
    expect(
      l10n.trips_cylinders_record_unlinked(3),
      '3 dive tanks not linked to a cylinder',
    );
    expect(l10n.trips_cylinders_record_tank(2), 'Tank 2');
    expect(l10n.trips_cylinders_record_filled('200 bar'), 'Filled to 200 bar');
    expect(l10n.trips_cylinders_record_analyzed('31.8%'), 'Analyzed 31.8%');
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: FAIL, the getters are undefined.

- [ ] **Step 3: Add the keys to all 11 ARB files and regenerate**

Save as `<scratchpad>/add_record_strings.py` and run it from the worktree root with `python3.14`. Each key goes directly before `"trips_cylinders_title"`; keys with placeholders get their "@" block in every locale, as the existing keys do. The plural forms follow `trips_cylinders_linkedDives` (the fr and pt "one" branch interpolates the count).

```python
import io
import json
import sys

ARB = 'lib/l10n/arb'
LOCALES = ['ar', 'de', 'en', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']
A = 'trips_cylinders_title'


def plural(one, other):
    return '{count, plural, one{' + one + '} other{' + other + '}}'


STRINGS = [
    (A, 'trips_cylinders_segment_record', {}, {
        'en': 'Record', 'ar': 'السجل', 'de': 'Protokoll', 'es': 'Registro',
        'fr': 'Relevé', 'he': 'רישום', 'hu': 'Napló', 'it': 'Registro',
        'nl': 'Overzicht', 'pt': 'Registo', 'zh': '记录',
    }),
    (A, 'trips_cylinders_recordEmpty', {}, {
        'en': 'No dives breathed from these cylinders yet.',
        'ar': 'لا توجد غطسات من هذه الأسطوانات بعد.',
        'de': 'Noch keine Tauchgänge mit diesen Flaschen.',
        'es': 'Aún no hay inmersiones con estas botellas.',
        'fr': 'Aucune plongée avec ces blocs pour l’instant.',
        'he': 'עדיין אין צלילות מהמכלים האלה.',
        'hu': 'Még nincs merülés ezekből a palackokból.',
        'it': 'Ancora nessuna immersione con queste bombole.',
        'nl': 'Nog geen duiken met deze flessen.',
        'pt': 'Ainda não há mergulhos com estes cilindros.',
        'zh': '还没有使用这些气瓶的潜水。',
    }),
    (A, 'trips_cylinders_record_fillsLogged', {'count': 'int'}, {
        'en': plural('{count} fill logged', '{count} fills logged'),
        'ar': plural('{count} تعبئة مسجلة', '{count} تعبئات مسجلة'),
        'de': plural('{count} Füllung erfasst', '{count} Füllungen erfasst'),
        'es': plural('{count} carga registrada', '{count} cargas registradas'),
        'fr': plural('{count} remplissage noté', '{count} remplissages notés'),
        'he': plural('{count} מילוי נרשם', '{count} מילויים נרשמו'),
        'hu': plural('{count} töltés rögzítve', '{count} töltés rögzítve'),
        'it': plural('{count} ricarica registrata', '{count} ricariche registrate'),
        'nl': plural('{count} vulling vastgelegd', '{count} vullingen vastgelegd'),
        'pt': plural('{count} enchimento registado', '{count} enchimentos registados'),
        'zh': '{count, plural, other{已记录 {count} 次充气}}',
    }),
    (A, 'trips_cylinders_record_leftOut', {'count': 'int'}, {
        'en': plural('{count} dive left out', '{count} dives left out'),
        'ar': plural('{count} غطسة غير محسوبة', '{count} غطسات غير محسوبة'),
        'de': plural('{count} Tauchgang nicht gezählt', '{count} Tauchgänge nicht gezählt'),
        'es': plural('{count} inmersión sin contar', '{count} inmersiones sin contar'),
        'fr': plural('{count} plongée non comptée', '{count} plongées non comptées'),
        'he': plural('{count} צלילה לא נספרה', '{count} צלילות לא נספרו'),
        'hu': plural('{count} merülés kimaradt', '{count} merülés kimaradt'),
        'it': plural('{count} immersione esclusa', '{count} immersioni escluse'),
        'nl': plural('{count} duik niet meegeteld', '{count} duiken niet meegeteld'),
        'pt': plural('{count} mergulho não contado', '{count} mergulhos não contados'),
        'zh': '{count, plural, other{{count} 次潜水未计入}}',
    }),
    (A, 'trips_cylinders_record_packageFills', {'count': 'int'}, {
        'en': plural('{count} package fill', '{count} package fills'),
        'ar': plural('{count} تعبئة ضمن باقة', '{count} تعبئات ضمن باقة'),
        'de': plural('{count} Füllung im Paket', '{count} Füllungen im Paket'),
        'es': plural('{count} carga en paquete', '{count} cargas en paquete'),
        'fr': plural('{count} remplissage forfaitaire', '{count} remplissages forfaitaires'),
        'he': plural('{count} מילוי בחבילה', '{count} מילויים בחבילה'),
        'hu': plural('{count} csomagos töltés', '{count} csomagos töltés'),
        'it': plural('{count} ricarica nel pacchetto', '{count} ricariche nel pacchetto'),
        'nl': plural('{count} vulling in pakket', '{count} vullingen in pakket'),
        'pt': plural('{count} enchimento em pacote', '{count} enchimentos em pacote'),
        'zh': '{count, plural, other{{count} 次套餐充气}}',
    }),
    (A, 'trips_cylinders_record_unlinked', {'count': 'int'}, {
        'en': plural('{count} dive tank not linked to a cylinder',
                     '{count} dive tanks not linked to a cylinder'),
        'ar': plural('{count} أسطوانة غطس غير مرتبطة بأسطوانة رحلة',
                     '{count} أسطوانات غطس غير مرتبطة بأسطوانة رحلة'),
        'de': plural('{count} Tauchgangsflasche ohne Reiseflasche',
                     '{count} Tauchgangsflaschen ohne Reiseflasche'),
        'es': plural('{count} botella de inmersión sin enlazar',
                     '{count} botellas de inmersión sin enlazar'),
        'fr': plural('{count} bloc de plongée non relié',
                     '{count} blocs de plongée non reliés'),
        'he': plural('{count} מכל צלילה לא מקושר', '{count} מכלי צלילה לא מקושרים'),
        'hu': plural('{count} merülési palack nincs hozzárendelve',
                     '{count} merülési palack nincs hozzárendelve'),
        'it': plural('{count} bombola di immersione non collegata',
                     '{count} bombole di immersione non collegate'),
        'nl': plural('{count} duikfles niet gekoppeld',
                     '{count} duikflessen niet gekoppeld'),
        'pt': plural('{count} cilindro de mergulho não ligado',
                     '{count} cilindros de mergulho não ligados'),
        'zh': '{count, plural, other{{count} 个潜水气瓶未关联行程气瓶}}',
    }),
    (A, 'trips_cylinders_record_unlinkedTitle', {}, {
        'en': 'Not linked to a cylinder',
        'ar': 'غير مرتبطة بأسطوانة',
        'de': 'Keiner Flasche zugeordnet',
        'es': 'Sin enlazar a una botella',
        'fr': 'Non reliés à un bloc',
        'he': 'לא מקושרים למכל',
        'hu': 'Nincs palackhoz rendelve',
        'it': 'Non collegate a una bombola',
        'nl': 'Niet aan een fles gekoppeld',
        'pt': 'Não ligados a um cilindro',
        'zh': '未关联气瓶',
    }),
    (A, 'trips_cylinders_record_tank', {'number': 'int'}, {
        'en': 'Tank {number}', 'ar': 'الأسطوانة {number}',
        'de': 'Flasche {number}', 'es': 'Botella {number}',
        'fr': 'Bloc {number}', 'he': 'מכל {number}', 'hu': '{number}. palack',
        'it': 'Bombola {number}', 'nl': 'Fles {number}',
        'pt': 'Cilindro {number}', 'zh': '气瓶 {number}',
    }),
    (A, 'trips_cylinders_record_filled', {'pressure': 'String'}, {
        'en': 'Filled to {pressure}', 'ar': 'مُلئت إلى {pressure}',
        'de': 'Gefüllt auf {pressure}', 'es': 'Cargada a {pressure}',
        'fr': 'Rempli à {pressure}', 'he': 'מולא ל־{pressure}',
        'hu': 'Töltve: {pressure}', 'it': 'Ricaricata a {pressure}',
        'nl': 'Gevuld tot {pressure}', 'pt': 'Enchido a {pressure}',
        'zh': '充至 {pressure}',
    }),
    (A, 'trips_cylinders_record_analyzed', {'mix': 'String'}, {
        'en': 'Analyzed {mix}', 'ar': 'التحليل {mix}',
        'de': 'Analysiert {mix}', 'es': 'Analizado {mix}',
        'fr': 'Analysé {mix}', 'he': 'נותח {mix}', 'hu': 'Mért: {mix}',
        'it': 'Analizzato {mix}', 'nl': 'Geanalyseerd {mix}',
        'pt': 'Analisado {mix}', 'zh': '分析 {mix}',
    }),
]

for loc in LOCALES:
    path = f'{ARB}/app_{loc}.arb'
    raw = io.open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    lines = raw.split(nl)
    for anchor, key, placeholders, values in STRINGS:
        if any(line.startswith(f'  "{key}":') for line in lines):
            sys.exit(f'{key} is already in {path}')
        idx = next(i for i, line in enumerate(lines) if line.startswith(f'  "{anchor}":'))
        block = [f'  "{key}": {json.dumps(values[loc], ensure_ascii=False)},']
        if placeholders:
            block += [f'  "@{key}": {{', '    "placeholders": {']
            items = list(placeholders.items())
            for n, (name, kind) in enumerate(items):
                block += [f'      "{name}": {{', f'        "type": "{kind}"',
                          '      }' + (',' if n < len(items) - 1 else '')]
            block += ['    }', '  },']
        lines[idx:idx] = block
    io.open(path, 'w', encoding='utf-8', newline='').write(nl.join(lines))
print('ok')
```

Before running, compare each locale's terms with its existing `trips_cylinders_*` strings (cylinder, fill, dive) and adjust where the locale already uses a different word. Then run `flutter gen-l10n` and confirm `git status --porcelain -- 'lib/l10n/arb/'` lists 23 files.

- [ ] **Step 4: Run the test, then the l10n suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart test/l10n`
Expected: `All tests passed!` (parity, placeholders, plural zero, singular interpolation, diacritics).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb test/features/trips/presentation/helpers/trip_cylinder_display_test.dart
git commit -m "feat(trips): gas record strings in every locale (#2325)"
```

---

### Task 5: The CSV

**Files:**
- Modify: `lib/core/services/export/csv/codec/csv_column.dart` (append two columns to `CsvColumns`)
- Create: `lib/core/services/export/csv/csv_trip_gas_record_writer.dart`
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (after the fills section)
- Modify: `lib/core/services/export/export_service.dart` (after the fills facade methods)
- Test: `test/core/services/export/csv/csv_trip_gas_record_writer_test.dart`

**Interfaces:**
- Consumes: `TripGasRecord`, `TripGasRecordRow` (Task 1), `CsvExportUnits`, `sanitizeCsvField`, `trimFixed`.
- Produces:
  - `CsvColumns.recordFillPressure`, `CsvColumns.gasBreathed`
  - `class CsvTripGasRecordWriter { CsvTripGasRecordWriter(CsvExportUnits units); String write(TripGasRecord record, {Map<String, String> centerNames}) }`
  - `String tripGasRecordFileName(String tripName, DateTime date)`
  - `ExportService.exportTripGasRecordToCsv(TripGasRecord record, {required String tripName, Map<String, String> centerNames, CsvExportUnits units})` returns `Future<String>`
  - `ExportService.saveTripGasRecordCsvToFile(TripGasRecord record, {required String tripName, Map<String, String> centerNames, required String dialogTitle, CsvExportUnits units})` returns `Future<String?>`

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/export/csv/csv_trip_gas_record_writer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_trip_gas_record_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;

void main() {
  final at = DateTime.utc(2026, 3, 9, 9, 5);
  final slot = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );
  final fill = TripCylinderEvent(
    id: 'f1',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    bottleLabel: '14',
    pressure: 200,
    o2Percent: 32,
    analyzedO2: 31.8,
    diveCenterId: 'c1',
    createdAt: at,
    updatedAt: at,
  );

  TripGasRecord recordOf(List<TripGasRecordRow> rows) => TripGasRecord(
    rows: rows,
    slots: const [],
    fillsLogged: 1,
    costs: const [],
    packageFills: 0,
    unlinked: const [],
    multipleDivers: false,
  );

  TripGasRecordRow row({
    String site = 'Salt Pier',
    TripCylinderEvent? withFill,
    double? litres = 1554,
  }) => TripGasRecordRow(
    tank: TripGasRecordTank(
      tankId: 't1',
      diveId: 'd1',
      entryTime: at,
      diverName: 'Ana',
      siteName: site,
      startPressure: 200,
      endPressure: 60,
      gasMix: const GasMix(o2: 32),
      tripCylinderId: 'a',
    ),
    cylinder: slot,
    bottleLabel: withFill == null ? 'Truck 1' : '14',
    fill: withFill,
    fillPressure: withFill == null ? null : 200,
    litres: litres,
  );

  test('metric mode writes canonical values and ISO date and time', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.metric,
    ).write(recordOf([row(withFill: fill)]), centerNames: {'c1': 'Dive Friends'});
    expect(
      csv.split('\r\n').first,
      'Date,Time,Diver,Site,Cylinder,Bottle,O2 %,He %,Analyzed O2 %,'
      'Analyzed He %,Fill Pressure (bar),Start Pressure (bar),'
      'End Pressure (bar),Gas Breathed (L),Fill Station',
    );
    final r = rowOf(csv, 1);
    expect(r['Date'], '2026-03-09');
    expect(r['Time'], '09:05');
    expect(r['Diver'], 'Ana');
    expect(r['Site'], 'Salt Pier');
    expect(r['Cylinder'], 'Truck 1');
    expect(r['Bottle'], '14');
    expect(r['O2 %'], '32');
    expect(r['He %'], '0');
    expect(r['Analyzed O2 %'], '31.8');
    expect(r['Analyzed He %'], '');
    expect(r['Fill Pressure (bar)'], '200.0');
    expect(r['Start Pressure (bar)'], '200.0');
    expect(r['End Pressure (bar)'], '60.0');
    expect(r['Gas Breathed (L)'], '1554');
    expect(r['Fill Station'], 'Dive Friends');
  });

  test('imperial mode converts and names the formats', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.fromSettings(imperial),
    ).write(recordOf([row(withFill: fill)]));
    final r = rowOf(csv, 1);
    expect(r['Date (MM/DD/YYYY)'], '03/09/2026');
    expect(r['Time (12-hour)'], '9:05 AM');
    expect(r['Fill Pressure (psi)'], '2901');
    // 1554 L of free gas is 54.9 cuft.
    expect(r['Gas Breathed (cuft)'], '54.9');
  });

  test('no fill and no figure leave empty cells, not "null"', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.metric,
    ).write(recordOf([row(litres: null)]));
    final r = rowOf(csv, 1);
    expect(r['Bottle'], 'Truck 1');
    expect(r['O2 %'], '');
    expect(r['Fill Pressure (bar)'], '');
    expect(r['Gas Breathed (L)'], '');
    expect(r['Fill Station'], '');
  });

  test('a formula-looking name is neutralised', () {
    final csv = CsvTripGasRecordWriter(
      CsvExportUnits.metric,
    ).write(recordOf([row(site: '=cmd')]));
    expect(rowOf(csv, 1)['Site'], "'=cmd");
  });

  test('the file is named after the trip and the date', () {
    expect(
      tripGasRecordFileName('Bonaire 2026!', DateTime(2026, 3, 15)),
      'gas_record_Bonaire_2026__2026-03-15.csv',
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/core/services/export/csv/csv_trip_gas_record_writer_test.dart`
Expected: FAIL to compile: the writer does not exist.

- [ ] **Step 3: The columns and the writer**

Append inside `abstract final class CsvColumns` in `csv_column.dart`:

```dart

  /// Trip gas record (issue #2325): the fill in effect at the dive.
  static const recordFillPressure = CsvColumn(
    'Fill Pressure',
    CsvQuantity.pressure,
    metricDecimals: 1,
  );

  /// Trip gas record: free gas breathed from the tank.
  static const gasBreathed = CsvColumn(
    'Gas Breathed',
    CsvQuantity.volume,
    metricDecimals: 0,
  );
```

Create `lib/core/services/export/csv/csv_trip_gas_record_writer.dart`:

```dart
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

/// The trip gas record as a CSV: one line per dive tank breathed from a
/// trip cylinder (decided 2026-09-30: rows only, totals stay on screen).
/// Always a Diver column, so the layout is the same for every trip.
class CsvTripGasRecordWriter {
  CsvTripGasRecordWriter(this.units);

  final CsvExportUnits units;

  String write(
    TripGasRecord record, {
    Map<String, String> centerNames = const {},
  }) {
    String percent(double? v) => v == null ? '' : trimFixed(v, 1);
    final rows = <List<dynamic>>[
      [
        units.dateHeader('Date'),
        units.timeHeader('Time'),
        'Diver',
        'Site',
        'Cylinder',
        'Bottle',
        'O2 %',
        'He %',
        'Analyzed O2 %',
        'Analyzed He %',
        units.header(CsvColumns.recordFillPressure),
        units.header(CsvColumns.startPressure),
        units.header(CsvColumns.endPressure),
        units.header(CsvColumns.gasBreathed),
        'Fill Station',
      ],
    ];
    for (final r in record.rows) {
      final ordered = r.orderedMix;
      final analyzed = r.analyzedMix;
      rows.add([
        units.date(r.tank.entryTime),
        units.time(r.tank.entryTime),
        sanitizeCsvField(r.tank.diverName),
        sanitizeCsvField(r.tank.siteName),
        sanitizeCsvField(r.cylinder.label),
        sanitizeCsvField(r.bottleLabel),
        percent(ordered?.o2),
        percent(ordered?.he),
        percent(analyzed?.o2),
        analyzed == null || analyzed.he == 0 ? '' : percent(analyzed.he),
        units.value(CsvColumns.recordFillPressure, r.fillPressure),
        units.value(CsvColumns.startPressure, r.tank.startPressure),
        units.value(CsvColumns.endPressure, r.tank.endPressure),
        units.value(CsvColumns.gasBreathed, r.litres),
        sanitizeCsvField(centerNames[r.diveCenterId]),
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }
}

/// `gas_record_<trip>_<yyyy-MM-dd>.csv`, the trip name reduced to letters,
/// digits and underscores so every platform accepts it.
String tripGasRecordFileName(String tripName, DateTime date) =>
    'gas_record_${tripName.replaceAll(RegExp(r'[^\w]'), '_')}_'
    '${DateFormat('yyyy-MM-dd').format(date)}.csv';
```

- [ ] **Step 4: Share and save through the facade**

In `csv_export_service.dart` (import the writer and `trip_gas_record.dart`), after `saveFillsCsvToFile`:

```dart

  // ==================== Trip gas record (issue #2325) ====================

  /// Generate the trip gas record CSV (without sharing).
  String generateTripGasRecordCsvContent(
    TripGasRecord record, {
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvTripGasRecordWriter(units).write(record, centerNames: centerNames);

  /// Export the trip gas record to CSV and share via the system sheet.
  Future<String> exportTripGasRecordToCsv(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => saveAndShareFile(
    generateTripGasRecordCsvContent(
      record,
      centerNames: centerNames,
      units: units,
    ),
    tripGasRecordFileName(tripName, DateTime.now()),
    'text/csv',
  );

  /// Save the trip gas record CSV to a location the diver picks.
  Future<String?> saveTripGasRecordCsvToFile(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: tripGasRecordFileName(tripName, DateTime.now()),
      type: FileType.custom,
      bytes: Uint8List.fromList(
        utf8.encode(
          generateTripGasRecordCsvContent(
            record,
            centerNames: centerNames,
            units: units,
          ),
        ),
      ),
      mimeType: 'text/csv',
    );
    if (result == null) return null;
    return savedFileLocation(result);
  }
```

In `export_service.dart` (import `trip_gas_record.dart`), after the fills facade methods:

```dart

  Future<String> exportTripGasRecordToCsv(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.exportTripGasRecordToCsv(
    record,
    tripName: tripName,
    centerNames: centerNames,
    units: units,
  );

  Future<String?> saveTripGasRecordCsvToFile(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) => _csv.saveTripGasRecordCsvToFile(
    record,
    tripName: tripName,
    centerNames: centerNames,
    dialogTitle: dialogTitle,
    units: units,
  );
```

- [ ] **Step 5: Run the tests, then the CSV suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/core/services/export/csv`
Expected: `All tests passed!` If a column-registry test in that folder enumerates `CsvColumns` (for example an importer round-trip over every column), add the two new columns where it lists them and record that in the ledger.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/export/csv/codec/csv_column.dart lib/core/services/export/csv/csv_trip_gas_record_writer.dart lib/core/services/export/csv/csv_export_service.dart lib/core/services/export/export_service.dart test/core/services/export/csv/csv_trip_gas_record_writer_test.dart
git commit -m "feat(trips): the gas record as a CSV (#2325)"
```

---

### Task 6: The Record segment

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart`
- Modify: `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart` (segment state and body)
- Test: `test/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view_test.dart`

**Interfaces:**
- Consumes: `tripGasRecordProvider` (Task 3), the Task 4 strings, `tripCylinderMixLabel`, `tripCylinderTankLine`, `trips_cylinders_linkedDives`, `formatMoney`, `UnitFormatter`.
- Produces: `class TripCylinderRecordView extends ConsumerWidget { String tripId; String tripName; Map<String, String> centerNames; }` (keys `record-totals`, `record-gaps`, `record-row-<tankId>`, `record-empty`, `record-export`); `Future<void> showUnlinkedTanksSheet(BuildContext context, List<TripUnlinkedTank> tanks, {required UnitFormatter units, required bool showDivers})`; the board's `SegmentedButton<_BoardView>` with `board`, `ledger`, `record`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 9, 5);
  final slot = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );
  final fill = TripCylinderEvent(
    id: 'f1',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    bottleLabel: '14',
    pressure: 200,
    o2Percent: 32,
    analyzedO2: 31.8,
    diveCenterId: 'c1',
    createdAt: at,
    updatedAt: at,
  );

  TripGasRecordRow row(String tankId, {String? diver, double? litres}) =>
      TripGasRecordRow(
        tank: TripGasRecordTank(
          tankId: tankId,
          diveId: 'd-$tankId',
          entryTime: at,
          diverId: diver,
          diverName: diver == null ? null : 'Diver $diver',
          siteName: 'Salt Pier',
          startPressure: 200,
          endPressure: 60,
          volume: 11.1,
          gasMix: const GasMix(o2: 32),
          tripCylinderId: 'a',
        ),
        cylinder: slot,
        bottleLabel: '14',
        fill: fill,
        fillPressure: 200,
        litres: litres,
      );

  TripGasRecord recordOf({
    List<TripGasRecordRow>? rows,
    List<TripUnlinkedTank> unlinked = const [],
    bool multipleDivers = false,
  }) => TripGasRecord(
    rows: rows ?? [row('t1', litres: 1554)],
    slots: [
      TripGasRecordSlotTotal(cylinder: slot, dives: 2, litres: 1554, leftOut: 1),
    ],
    fillsLogged: 3,
    costs: const [MapEntry('USD', 22.0)],
    packageFills: 1,
    unlinked: unlinked,
    multipleDivers: multipleDivers,
  );

  Future<void> pump(WidgetTester tester, TripGasRecord record) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: TripCylinderRecordView(
              tripId: 't1',
              tripName: 'Bonaire',
              centerNames: {'c1': 'Dive Friends'},
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:diveId/edit',
          builder: (_, _) => const Scaffold(body: Text('EDIT DIVE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripGasRecordProvider('t1').overrideWith((ref) async => record),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('totals: fills, per slot litres and left out, cost', (
    tester,
  ) async {
    await pump(tester, recordOf());
    final totals = find.byKey(const Key('record-totals'));
    expect(
      find.descendant(of: totals, matching: find.text('3 fills logged')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: totals,
        matching: find.textContaining('1 dive left out'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: totals, matching: find.textContaining(r'$22.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: totals,
        matching: find.textContaining('1 package fill'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a row names its bottle, analysis, fill and station', (
    tester,
  ) async {
    await pump(tester, recordOf());
    final r = find.byKey(const Key('record-row-t1'));
    expect(
      find.descendant(of: r, matching: find.textContaining('Truck 1 · Bottle 14')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: r, matching: find.textContaining('Analyzed')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: r, matching: find.textContaining('Dive Friends')),
      findsOneWidget,
    );
  });

  testWidgets('a single-diver trip names no diver', (tester) async {
    await pump(tester, recordOf(rows: [row('t1', diver: 'x', litres: 1)]));
    expect(find.textContaining('Diver x'), findsNothing);
  });

  testWidgets('names show only with more than one diver', (tester) async {
    await pump(
      tester,
      recordOf(rows: [row('t1', diver: 'x', litres: 1)], multipleDivers: true),
    );
    expect(find.textContaining('Diver x'), findsOneWidget);
  });

  testWidgets('a row with no figure shows "--" for litres', (tester) async {
    await pump(tester, recordOf(rows: [row('t1')]));
    expect(
      find.descendant(
        of: find.byKey(const Key('record-row-t1')),
        matching: find.textContaining('--'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the gaps line lists unlinked tanks and opens the editor', (
    tester,
  ) async {
    await pump(
      tester,
      recordOf(
        unlinked: [
          TripUnlinkedTank(
            tankId: 'n1',
            diveId: 'd7',
            entryTime: at,
            siteName: 'Klein Bonaire',
            tankOrder: 1,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('record-gaps')));
    await tester.pumpAndSettle();
    expect(find.text('Not linked to a cylinder'), findsOneWidget);
    await tester.tap(find.textContaining('Klein Bonaire'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT DIVE'), findsOneWidget);
  });

  testWidgets('no gaps, no gaps line; no rows, the empty text', (
    tester,
  ) async {
    await pump(tester, recordOf(rows: const []));
    expect(find.byKey(const Key('record-gaps')), findsNothing);
    expect(find.byKey(const Key('record-empty')), findsOneWidget);
  });
}
```

Append to `main()` in `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart` (add `import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';` and `import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';`, and give `pumpBoard` a `TripGasRecord? record` parameter that, when given, adds `tripGasRecordProvider(tripId).overrideWith((ref) async => record)`):

```dart

  testWidgets('the board has a Record segment', (tester) async {
    final a = await slot('Truck 1', 0);
    await fill(a.id);
    await pumpBoard(
      tester,
      record: const TripGasRecord(
        rows: [],
        slots: [],
        fillsLogged: 1,
        costs: [],
        packageFills: 0,
        unlinked: [],
        multipleDivers: false,
      ),
    );
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-empty')), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view_test.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: FAIL to compile: the record view does not exist.

- [ ] **Step 3: The view**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The board's Record segment: the totals, the gaps line, then one row per
/// dive tank breathed from a trip cylinder, in dive order.
class TripCylinderRecordView extends ConsumerWidget {
  const TripCylinderRecordView({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.centerNames,
  });

  final String tripId;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(tripGasRecordProvider(tripId));
    final record = async.value;
    if (record == null) {
      return Center(
        child: async.hasError
            ? Text(l10n.common_label_error)
            : const CircularProgressIndicator(),
      );
    }
    final units = UnitFormatter(ref.watch(settingsProvider));
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Totals(
          record: record,
          units: units,
          trailing: TripGasRecordExportButton(
            record: record,
            tripName: tripName,
            centerNames: centerNames,
          ),
        ),
        if (record.unlinked.isNotEmpty)
          ListTile(
            key: const Key('record-gaps'),
            leading: const Icon(Icons.link_off),
            title: Text(
              l10n.trips_cylinders_record_unlinked(record.unlinked.length),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showUnlinkedTanksSheet(
              context,
              record.unlinked,
              units: units,
              showDivers: record.multipleDivers,
            ),
          ),
        const Divider(height: 1),
        if (record.rows.isEmpty)
          Padding(
            key: const Key('record-empty'),
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(l10n.trips_cylinders_recordEmpty)),
          )
        else
          for (final r in record.rows)
            _RecordRow(
              row: r,
              units: units,
              centerName: centerNames[r.diveCenterId],
              showDiver: record.multipleDivers,
            ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.record,
    required this.units,
    required this.trailing,
  });

  final TripGasRecord record;
  final UnitFormatter units;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cost = [
      for (final c in record.costs) formatMoney(c.value, c.key),
      if (record.packageFills > 0)
        l10n.trips_cylinders_record_packageFills(record.packageFills),
    ];
    return Padding(
      key: const Key('record-totals'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.trips_cylinders_record_fillsLogged(record.fillsLogged),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              trailing,
            ],
          ),
          for (final s in record.slots)
            Text(
              [
                s.cylinder.label,
                l10n.trips_cylinders_linkedDives(s.dives),
                units.formatVolume(s.litres),
                if (s.leftOut > 0) l10n.trips_cylinders_record_leftOut(s.leftOut),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          if (cost.isNotEmpty)
            Text(
              '${l10n.trips_cylinders_fill_cost}: ${cost.join(' · ')}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.row,
    required this.units,
    required this.centerName,
    required this.showDiver,
  });

  final TripGasRecordRow row;
  final UnitFormatter units;
  final String? centerName;
  final bool showDiver;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tank = row.tank;
    final title = [
      units.formatDateTime(tank.entryTime, l10n: l10n),
      ?tank.siteName,
      if (showDiver) ?tank.diverName,
    ].join(' · ');
    final slotLine = [
      tripCylinderTankLine(l10n, (
        label: row.cylinder.label,
        bottle: row.bottleLabel,
      )),
      if (row.orderedMix case final mix?) tripCylinderMixLabel(l10n, mix),
      if (row.analyzedMix case final mix?)
        l10n.trips_cylinders_record_analyzed(_percent(mix.o2, mix.he)),
    ].join(' · ');
    final gasLine = [
      if (row.fillPressure case final p?)
        l10n.trips_cylinders_record_filled(units.formatPressure(p)),
      ?centerName,
      '${units.formatPressure(tank.startPressure)} → '
          '${units.formatPressure(tank.endPressure)}',
      row.litres == null ? '--' : units.formatVolume(row.litres),
    ].join(' · ');
    return ListTile(
      key: Key('record-row-${tank.tankId}'),
      title: Text(title),
      subtitle: Text('$slotLine\n$gasLine'),
      isThreeLine: true,
    );
  }
}

/// "31.8%" or "18/45%" for an analyzed mix.
String _percent(double o2, double he) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return he > 0 ? '${n(o2)}/${n(he)}%' : '${n(o2)}%';
}

/// The dive tanks that breathe from no trip cylinder; each opens its
/// dive's editor (decided 2026-09-30: a list, not only the first).
Future<void> showUnlinkedTanksSheet(
  BuildContext context,
  List<TripUnlinkedTank> tanks, {
  required UnitFormatter units,
  required bool showDivers,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.trips_cylinders_record_unlinkedTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final t in tanks)
                    ListTile(
                      key: Key('unlinked-${t.tankId}'),
                      title: Text(
                        [
                          units.formatDateTime(t.entryTime, l10n: l10n),
                          ?t.siteName,
                          if (showDivers) ?t.diverName,
                        ].join(' · '),
                      ),
                      subtitle: Text(
                        l10n.trips_cylinders_record_tank(t.tankOrder + 1),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/dives/${t.diveId}/edit');
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

Also create a stub export button so the view compiles now; Task 7 fills it in. `lib/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

/// The Record header's export action (Task 7 wires the share and save).
class TripGasRecordExportButton extends StatelessWidget {
  const TripGasRecordExportButton({
    super.key,
    required this.record,
    required this.tripName,
    required this.centerNames,
  });

  final TripGasRecord record;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 4: Three segments on the board**

In `trip_cylinder_board_page.dart` (import the record view and `trip_providers.dart` for `tripByIdProvider`), add above the page class:

```dart
enum _BoardView { board, ledger, record }
```

replace `bool _showLedger = false;` with `_BoardView _view = _BoardView.board;`, and replace the `SegmentedButton<bool>` and the `Expanded` after it with:

```dart
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<_BoardView>(
                key: const Key('board-segment'),
                segments: [
                  ButtonSegment(
                    value: _BoardView.board,
                    label: Text(l10n.trips_cylinders_segment_board),
                  ),
                  ButtonSegment(
                    value: _BoardView.ledger,
                    label: Text(l10n.trips_cylinders_segment_ledger),
                  ),
                  ButtonSegment(
                    value: _BoardView.record,
                    label: Text(l10n.trips_cylinders_segment_record),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
            Expanded(
              child: switch (_view) {
                _BoardView.board => TripCylinderBoardList(
                  states: states,
                  centerNames: centerNames,
                ),
                _BoardView.ledger => TripCylinderLedgerView(
                  tripId: tripId,
                  states: states,
                  centerNames: centerNames,
                ),
                _BoardView.record => TripCylinderRecordView(
                  tripId: tripId,
                  tripName: ref.watch(tripByIdProvider(tripId)).value?.name ?? '',
                  centerNames: centerNames,
                ),
              },
            ),
```

- [ ] **Step 5: Run the tests, then the trips presentation suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation test/architecture`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart lib/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart lib/features/trips/presentation/pages/trip_cylinder_board_page.dart test/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view_test.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart
git commit -m "feat(trips): the Record segment on the board (#2325)"
```

---

### Task 7: Export from the Record

**Files:**
- Modify: `lib/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart`
- Test: `test/features/trips/presentation/widgets/cylinders/trip_gas_record_export_test.dart`

**Interfaces:**
- Consumes: `ExportService.exportTripGasRecordToCsv`, `saveTripGasRecordCsvToFile` (Task 5), `exportServiceProvider` (`lib/features/settings/presentation/providers/export_providers.dart`), `showExportDestinationSheetWithOptions`, `CsvExportUnits.forMode`.
- Produces: the working `TripGasRecordExportButton` (key `record-export`).

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_gas_record_export_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Records the record exports without touching the file system.
class _FakeExportService implements ExportService {
  String? sharedTrip;
  String? savedTrip;
  CsvExportUnits? units;

  @override
  Future<String> exportTripGasRecordToCsv(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    sharedTrip = tripName;
    this.units = units;
    return 'shared.csv';
  }

  @override
  Future<String?> saveTripGasRecordCsvToFile(
    TripGasRecord record, {
    required String tripName,
    Map<String, String> centerNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    savedTrip = tripName;
    return 'saved.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const record = TripGasRecord(
    rows: [],
    slots: [],
    fillsLogged: 0,
    costs: [],
    packageFills: 0,
    unlinked: [],
    multipleDivers: false,
  );

  Future<_FakeExportService> pump(WidgetTester tester) async {
    final fake = _FakeExportService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          exportServiceProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TripGasRecordExportButton(
              record: record,
              tripName: 'Bonaire',
              centerNames: {},
            ),
          ),
        ),
      ),
    );
    return fake;
  }

  testWidgets('share sends the record through the facade', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(fake.sharedTrip, 'Bonaire');
    expect(fake.units, isNotNull);
  });

  testWidgets('save to file goes through the facade', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const Key('record-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(fake.savedTrip, 'Bonaire');
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/widgets/cylinders/trip_gas_record_export_test.dart`
Expected: FAIL: no widget with key `record-export` (the stub renders nothing).

- [ ] **Step 3: The button**

Replace `trip_gas_record_export.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// The Record header's export: the destination sheet (share or save, with
/// the CSV units toggle), then the record's rows as a CSV through the
/// export facade, so tests can override it like every export surface.
class TripGasRecordExportButton extends ConsumerWidget {
  const TripGasRecordExportButton({
    super.key,
    required this.record,
    required this.tripName,
    required this.centerNames,
  });

  final TripGasRecord record;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return TextButton.icon(
        key: const Key('record-export'),
        icon: const Icon(Icons.ios_share),
        label: Text(l10n.transfer_csvExport_exportButton),
        onPressed: () async {
          final choice = await showExportDestinationSheetWithOptions(
            context,
            title: l10n.transfer_csvExport_dialogTitle,
            showCsvUnitsToggle: true,
          );
          if (choice == null || !context.mounted) return;
          final units = CsvExportUnits.forMode(
            choice.csvUnitMode,
            ref.read(settingsProvider),
          );
          final service = ref.read(exportServiceProvider);
          // No progress dialog around the save path: the native save panel
          // must not open while a modal route is up.
          if (choice.destination == ExportDestination.share) {
            await service.exportTripGasRecordToCsv(
              record,
              tripName: tripName,
              centerNames: centerNames,
              units: units,
            );
          } else {
            await service.saveTripGasRecordCsvToFile(
              record,
              tripName: tripName,
              centerNames: centerNames,
              dialogTitle: l10n.transfer_csvExport_dialogTitle,
              units: units,
            );
          }
        },
    );
  }
}
```

No iPad share anchor, as the other CSV share exports (`exportFillsToCsv`) pass none; `dart format` settles the indentation.

- [ ] **Step 4: Run the tests, then the trips presentation suite and the guards**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation test/architecture`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart test/features/trips/presentation/widgets/cylinders/trip_gas_record_export_test.dart
git commit -m "feat(trips): export the gas record as a CSV (#2325)"
```

---

### Task 8: Verification and screenshots

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze --fatal-infos`
Expected: no files changed; "No issues found!".

- [ ] **Step 2: Run the full suite once**

Run: `flutter test > <scratchpad>/full.log 2>&1; tail -3 <scratchpad>/full.log` (the default TMPDIR: a long scratchpad TMPDIR breaks a media-store test).
Expected: `All tests passed!`. A failure outside the touched features goes to the report by name, with whether it also fails on `origin/main`.

- [ ] **Step 3: Screenshots for the PR**

With a throwaway golden harness in the scratchpad (never committed), 2x, light and dark, phone (390x844) and desktop (1280x800): the board's segment row before (main) and after; the Record segment with totals, a gaps line and rows (new); the unlinked tanks sheet (new); the export destination sheet from the Record (new). Send the images to the user.

- [ ] **Step 4: Memory**

Record in the program memory note that PR 5 is implemented and what remains (the PR and its review).
