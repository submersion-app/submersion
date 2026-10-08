# Trip Gas Logistics PR 3: Dive Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver say which trip cylinder each dive tank was breathed from: a "Trip cylinder" picker in the tank editor with a preselected suggestion, a "Log dive" shortcut on the board, and a slot line on the dive detail page.

**Architecture:** Pure helpers in the trips domain fill a tank from a slot, suggest slots for new tanks, and name the bottle a slot held at a given time. The tank editor gains a picker that reads `tripCylinderStatesProvider`; the dive edit page routes every trip change through one method that drops stale links and runs the suggestion; the new-dive route accepts `tripId` and `tripCylinderId` query parameters for the board's shortcut; the dive detail cylinders card shows the slot and the bottle in effect when the dive started. The link column, its validation on save and its sync already shipped in PR 1.

**Tech Stack:** Flutter, Riverpod (via `core/providers/provider.dart`), Drift (in-memory in tests), go_router, `flutter gen-l10n` (11 locales).

**Spec:** `docs/design/specs/2026-09-25-trip-gas-logistics-design.md` (sections "Phase 1 UI", "Deriving a slot's state", "Delivery" item 3).

## Global Constraints

- Branch: cut from `origin/main` AFTER PR 2 (#2451) merges; this PR's body carries `Part of #2325`.
- No em-dashes or en-dashes as punctuation anywhere (code, comments, strings, commits, PR text).
- No tool attribution of any kind (the contributor guide's Attribution section) in commits, PR text or review replies; no co-author trailer.
- Every new string in all 11 ARB files (ar, de, en, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- Anything showing a pressure or volume goes through `UnitFormatter` and respects the diver's unit settings.
- Linking is never automatic from a transmitter serial; the only automatic step is the preselected suggestion for tanks created in this editing session, which the diver can change or clear.
- A slot is picked with the tank editor's two habits from the spec: watch the provider with `.value` so a reload never flickers the link to None, and never lose the tank's current link while the diver edits other fields.
- Decided with the user (2026-09-28): picking a slot (by hand or by suggestion) sets the tank's gas mix and start pressure from the slot's current state, and its size, working pressure, material and preset from the slot when the slot has them; picking None clears only the link.
- Decided with the user (2026-09-28): the dive detail line shows the slot label and the bottle number from the fill in effect when the dive started.
- Status rule in force (decided 2026-09-28, #2451): a fill or reading is Full at 90% or more of working pressure, Empty at 50 bar or less; the suggestion only offers Full slots.
- Imports grouped dart, flutter, packages, local; `dart format .`; `dart analyze --fatal-infos <touched files>` prints "No issues found!" before each commit; files stay under 800 lines (`dive_edit_page.dart` is already far over: add to it only what cannot live elsewhere).
- TDD: every task starts with a failing test. Run tests with `TMPDIR=<scratchpad>/tmp flutter test <paths>`, never overlapping runs.

## Review Focus

1. A tank editor that is open when the page links its tank (a suggestion after the trip is chosen, or the log-dive shortcut) must show the slot's mix and pressures, not keep stale text that the next keystroke writes back over the fill. Pinned in Task 4, Step 1 ("an open editor picks up a link set by the page").
2. Changing or clearing the dive's trip leaves no tank linked to the old trip's cylinders on screen (the repository already drops them on save, but the picker would show None while the tank still reads as filled from a slot that is no longer offered). Pinned in Task 5, Step 1 ("clearing the trip drops every tank link").
3. Editing an existing dive never suggests or overwrites a link on its loaded tanks, even with the trip set and full slots available. Pinned in Task 5, Step 1 ("a loaded tank is never suggested").
4. Two tanks on one dive never get the same suggested slot, and a second tank with no other full slot stays unlinked. Pinned in Task 1, Step 1 ("siblings never share a suggestion") and Task 5, Step 1 ("an added tank takes the next full slot").
5. A diver who sets a suggested tank to None is not re-suggested when another tank is added. Pinned in Task 5, Step 1 ("None turns the suggestion down for good").

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/trips/domain/services/trip_cylinder_tank_link.dart` | Pure: fill a `DiveTank` from a slot; suggest slots for eligible tanks |
| Create `lib/features/trips/domain/services/trip_cylinder_labels.dart` | Pure: each slot's label and the bottle it held at a given instant |
| Modify `lib/features/trips/presentation/providers/trip_cylinder_providers.dart` | `tripCylinderLabelsAtProvider` |
| Modify `lib/features/trips/presentation/helpers/trip_cylinder_display.dart` | `tripCylinderPickerLabel`, `tripCylinderTankLine` |
| Modify all 11 `lib/l10n/arb/app_*.arb` + generated files | 4 new keys |
| Modify `lib/features/dive_log/presentation/widgets/tank_editor.dart` | Trip cylinder picker, resync on link change |
| Modify `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart` | Pass `tripId` and `suggested` through |
| Modify `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | `tripId`/`tripCylinderId` params, `_setTrip`, suggestions, loaded-tank tracking |
| Modify `lib/core/router/app_router.dart` | `newDive` route reads the two query parameters |
| Modify `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart` | "Log dive" menu action |
| Modify `lib/features/dive_log/presentation/widgets/cylinders_card.dart` | Slot line under a linked tank |

---

### Task 1: Pure link helpers

**Files:**
- Create: `lib/features/trips/domain/services/trip_cylinder_tank_link.dart`
- Test: `test/features/trips/domain/services/trip_cylinder_tank_link_test.dart`

**Interfaces:**
- Consumes: `suggestTripCylinder({required List<TripCylinderState> states, required GasMix tankMix, Set<String> excludedCylinderIds})` from `trip_cylinder_state_fold.dart`; `DiveTank.copyWith(... tripCylinderId, clearPresetName ...)` (uses `??` plus `clearX` flags).
- Produces:
  - `DiveTank tankFromTripCylinder(DiveTank tank, TripCylinderState slot)`
  - `({List<DiveTank> tanks, Set<String> suggested}) suggestTripCylindersForTanks({required List<DiveTank> tanks, required List<TripCylinderState> states, required Set<String> eligibleTankIds})`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9, 7);

  TripCylinder slot(
    String id, {
    int order = 0,
    double? volume = 11.1,
    double? workingPressure = 207,
    String? presetName = 'al80',
  }) => TripCylinder(
    id: id,
    tripId: 't1',
    label: 'Truck $id',
    volume: volume,
    workingPressure: workingPressure,
    material: TankMaterial.aluminum,
    presetName: presetName,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderState filled(
    TripCylinder c, {
    double pressure = 200,
    double o2 = 32,
    int minutes = 0,
  }) => foldCylinderState(
    cylinder: c,
    events: [
      TripCylinderEvent(
        id: 'f-${c.id}',
        tripCylinderId: c.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: t0.add(Duration(minutes: minutes)),
        pressure: pressure,
        o2Percent: o2,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
    uses: const [],
  );

  const air = DiveTank(
    id: 'k1',
    volume: 12,
    workingPressure: 232,
    startPressure: 200,
    endPressure: 50,
    presetName: 'steel12',
  );

  group('tankFromTripCylinder', () {
    test('links and fills mix, start pressure and specs from the slot', () {
      final t = tankFromTripCylinder(air, filled(slot('a'), pressure: 205));
      expect(t.tripCylinderId, 'a');
      expect(t.gasMix.o2, 32);
      expect(t.startPressure, 205);
      expect(t.volume, 11.1);
      expect(t.workingPressure, 207);
      expect(t.material, TankMaterial.aluminum);
      expect(t.presetName, 'al80');
      // The end pressure is the diver's to log.
      expect(t.endPressure, 50);
    });

    test('keeps the tank\'s own values where the slot knows nothing', () {
      final bare = foldCylinderState(
        cylinder: slot('b', volume: null, workingPressure: null, presetName: null),
        events: const [],
        uses: const [],
      );
      final t = tankFromTripCylinder(air, bare);
      expect(t.tripCylinderId, 'b');
      expect(t.gasMix, air.gasMix);
      expect(t.startPressure, 200);
      expect(t.volume, 12);
      expect(t.workingPressure, 232);
      expect(t.presetName, 'steel12');
    });

    test('a slot with specs but no preset clears the tank\'s preset', () {
      final t = tankFromTripCylinder(
        air,
        filled(slot('c', presetName: null)),
      );
      expect(t.volume, 11.1);
      expect(t.presetName, isNull);
    });
  });

  group('suggestTripCylindersForTanks', () {
    test('links each eligible tank to a full slot and reports it', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air.copyWith(gasMix: const GasMix(o2: 32))],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks.single.tripCylinderId, 'a');
      expect(r.suggested, {'k1'});
    });

    test('siblings never share a suggestion', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air, air.copyWith(id: 'k2')],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k1', 'k2'},
      );
      expect(r.tanks[0].tripCylinderId, 'a');
      expect(r.tanks[1].tripCylinderId, isNull);
      expect(r.suggested, {'k1'});
    });

    test('a slot another tank already holds is never offered', () {
      final r = suggestTripCylindersForTanks(
        tanks: [
          air.copyWith(id: 'k0', tripCylinderId: 'a'),
          air,
        ],
        states: [filled(slot('a')), filled(slot('b', order: 1), minutes: 5)],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks[1].tripCylinderId, 'b');
    });

    test('ineligible and already linked tanks are left alone', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air, air.copyWith(id: 'k2', tripCylinderId: 'x')],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k2'},
      );
      expect(r.tanks[0].tripCylinderId, isNull);
      expect(r.tanks[1].tripCylinderId, 'x');
      expect(r.suggested, isEmpty);
    });

    test('nothing full, nothing suggested', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air],
        states: [filled(slot('a'), pressure: 40)],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks.single.tripCylinderId, isNull);
      expect(r.suggested, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/trip_cylinder_tank_link_test.dart`
Expected: FAIL, "Target of URI doesn't exist: .../trip_cylinder_tank_link.dart".

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure. [tank] linked to [slot] and filled from it: the mix and start
/// pressure from the slot's current state, the size, working pressure,
/// material and preset from the slot when it has them (decided 2026-09-28).
/// Whatever the slot does not know keeps the tank's own value; the end
/// pressure is always the diver's to log.
DiveTank tankFromTripCylinder(DiveTank tank, TripCylinderState slot) {
  final c = slot.cylinder;
  final hasSpecs = c.volume != null || c.workingPressure != null;
  return tank.copyWith(
    tripCylinderId: c.id,
    gasMix: slot.mix,
    startPressure: slot.pressure,
    volume: c.volume,
    workingPressure: c.workingPressure,
    material: c.material,
    presetName: c.presetName,
    // Specs from the slot with no preset name must not keep the tank's old
    // preset, or the tank would claim a cylinder it is not.
    clearPresetName: hasSpecs && c.presetName == null,
  );
}

/// Pure. Links each tank in [eligibleTankIds] that has no link to the slot
/// [suggestTripCylinder] picks for it, filled by [tankFromTripCylinder].
/// Slots other tanks already hold, and slots given to an earlier tank in
/// this pass, are excluded, so two tanks never share one. Returns the tanks
/// in their order and the ids of the tanks it linked.
({List<DiveTank> tanks, Set<String> suggested}) suggestTripCylindersForTanks({
  required List<DiveTank> tanks,
  required List<TripCylinderState> states,
  required Set<String> eligibleTankIds,
}) {
  final byId = {for (final s in states) s.cylinder.id: s};
  var taken = {
    for (final t in tanks)
      if (t.tripCylinderId != null) t.tripCylinderId!,
  };
  var suggested = const <String>{};
  var out = const <DiveTank>[];
  for (final t in tanks) {
    final pick = eligibleTankIds.contains(t.id) && t.tripCylinderId == null
        ? suggestTripCylinder(
            states: states,
            tankMix: t.gasMix,
            excludedCylinderIds: taken,
          )
        : null;
    if (pick == null) {
      out = [...out, t];
      continue;
    }
    taken = {...taken, pick.id};
    suggested = {...suggested, t.id};
    out = [...out, tankFromTripCylinder(t, byId[pick.id]!)];
  }
  return (tanks: out, suggested: suggested);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/trip_cylinder_tank_link_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/trips test/features/trips
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/domain/services/trip_cylinder_tank_link.dart test/features/trips/domain/services/trip_cylinder_tank_link_test.dart
git commit -m "feat(trips): fill a dive tank from a trip cylinder, and suggest one (#2325)"
```

---

### Task 2: The bottle a slot held at a given time, and display helpers

**Files:**
- Create: `lib/features/trips/domain/services/trip_cylinder_labels.dart`
- Modify: `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`
- Modify: `lib/features/trips/presentation/helpers/trip_cylinder_display.dart`
- Test: `test/features/trips/domain/services/trip_cylinder_labels_test.dart`, `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart` (append)

**Interfaces:**
- Consumes: `TripCylinderRepository.getCylindersForTrip(String)`, `getEventsForTrip(String)` (returns `Map<String, List<TripCylinderEvent>>`, each list ascending by `occurredAt`), `watchLedgerChanges()`; `l10n.trips_cylinders_bottle(String)`, `tripCylinderMixLabel`, `tripCylinderStatusLabel`.
- Produces:
  - `typedef TripCylinderTankLabel = ({String label, String? bottle});`
  - `Map<String, TripCylinderTankLabel> tripCylinderLabelsAt({required List<TripCylinder> cylinders, required Map<String, List<TripCylinderEvent>> eventsBySlot, required int atMillis})`
  - `final tripCylinderLabelsAtProvider = FutureProvider.family<Map<String, TripCylinderTankLabel>, ({String tripId, int atMillis})>`
  - `String tripCylinderTankLine(AppLocalizations l10n, TripCylinderTankLabel label)` ("Truck 2 · Bottle 14", the bottle part left out when unknown or equal to the label)
  - `String tripCylinderPickerLabel(AppLocalizations l10n, UnitFormatter units, TripCylinderState state)` ("Truck 2 · Bottle 14 · EAN32 · 200 bar · Full")

- [ ] **Step 1: Write the failing tests**

`test/features/trips/domain/services/trip_cylinder_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9, 7);
  int at(int minutes) => t0.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
  final truck = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(int minutes, String bottle) => TripCylinderEvent(
    id: 'f$minutes',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: t0.add(Duration(minutes: minutes)),
    bottleLabel: bottle,
    createdAt: t0,
    updatedAt: t0,
  );

  final swapped = {
    'a': [fill(0, '14'), fill(600, '22')],
  };

  test('a dive before the swap reads the first bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(120),
    );
    expect(labels['a'], (label: 'Truck 1', bottle: '14'));
  });

  test('a dive after the swap reads the second bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(700),
    );
    expect(labels['a']!.bottle, '22');
  });

  test('a fill at the dive\'s own minute counts for that dive', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: swapped,
      atMillis: at(600),
    );
    expect(labels['a']!.bottle, '22');
  });

  test('no fill before the dive, or an adjustment, leaves no bottle', () {
    final labels = tripCylinderLabelsAt(
      cylinders: [truck],
      eventsBySlot: {
        'a': [
          TripCylinderEvent(
            id: 'x',
            tripCylinderId: 'a',
            kind: TripCylinderEventKind.adjustment,
            occurredAt: t0,
            createdAt: t0,
            updatedAt: t0,
          ),
          fill(600, '22'),
        ],
      },
      atMillis: at(60),
    );
    expect(labels['a'], (label: 'Truck 1', bottle: null));
  });
}
```

Append to `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart` (inside `main`, reusing its `l10n` and `units` setup; if the file lacks them, add `final l10n = AppLocalizationsEn();` and `const units = UnitFormatter(AppSettings());` at the top of `main`):

```dart
  group('tank line', () {
    test('names the slot and the bottle', () {
      expect(
        tripCylinderTankLine(l10n, (label: 'Truck 2', bottle: '14')),
        'Truck 2 · Bottle 14',
      );
    });

    test('leaves out an unknown or repeated bottle', () {
      expect(tripCylinderTankLine(l10n, (label: 'Truck 2', bottle: null)), 'Truck 2');
      expect(
        tripCylinderTankLine(l10n, (label: 'My HP100', bottle: 'My HP100')),
        'My HP100',
      );
    });
  });

  test('the picker label names bottle, mix, pressure and status', () {
    final t0 = DateTime.utc(2026, 3, 9);
    final state = foldCylinderState(
      cylinder: TripCylinder(
        id: 'a',
        tripId: 't1',
        label: 'Truck 2',
        workingPressure: 207,
        createdAt: t0,
        updatedAt: t0,
      ),
      events: [
        TripCylinderEvent(
          id: 'f',
          tripCylinderId: 'a',
          kind: TripCylinderEventKind.fill,
          occurredAt: t0,
          bottleLabel: '14',
          pressure: 200,
          o2Percent: 32,
          createdAt: t0,
          updatedAt: t0,
        ),
      ],
      uses: const [],
    );
    expect(
      tripCylinderPickerLabel(l10n, units, state),
      'Truck 2 · Bottle 14 · EAN32 · ${units.formatPressure(200)} · Full',
    );
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/domain/services/trip_cylinder_labels_test.dart test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: FAIL, the labels file and both helpers are undefined.

- [ ] **Step 3: Implement**

`lib/features/trips/domain/services/trip_cylinder_labels.dart`:

```dart
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// A slot as a dive tank names it: its label, and the bottle number of the
/// fill in effect at the dive (null when no fill before it named one).
typedef TripCylinderTankLabel = ({String label, String? bottle});

/// Pure. Each slot's label and the bottle it held at [atMillis]: the bottle
/// number of its last fill at or before that instant, the same ordering the
/// fold uses (a fill at the dive's own minute was for that dive). So a
/// bottle swapped later in the week does not rename an earlier dive's tank.
Map<String, TripCylinderTankLabel> tripCylinderLabelsAt({
  required List<TripCylinder> cylinders,
  required Map<String, List<TripCylinderEvent>> eventsBySlot,
  required int atMillis,
}) => {
  for (final c in cylinders)
    c.id: (
      label: c.label,
      bottle: (eventsBySlot[c.id] ?? const <TripCylinderEvent>[])
          .where(
            (e) =>
                e.kind == TripCylinderEventKind.fill &&
                e.occurredAt.millisecondsSinceEpoch <= atMillis,
          )
          .lastOrNull
          ?.bottleLabel,
    ),
};
```

Append to `trip_cylinder_providers.dart` (add the import of `trip_cylinder_labels.dart`):

```dart
/// Each slot's label and the bottle it held at a dive's start, for the dive
/// detail page. Keyed by trip and instant; refetches when the trip's slots
/// or ledger change.
final tripCylinderLabelsAtProvider =
    FutureProvider.family<
      Map<String, TripCylinderTankLabel>,
      ({String tripId, int atMillis})
    >((ref, key) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchLedgerChanges());
      final (cylinders, events) = await (
        repository.getCylindersForTrip(key.tripId),
        repository.getEventsForTrip(key.tripId),
      ).wait;
      return tripCylinderLabelsAt(
        cylinders: cylinders,
        eventsBySlot: events,
        atMillis: key.atMillis,
      );
    });
```

Append to `trip_cylinder_display.dart` (add the import of `trip_cylinder_labels.dart`):

```dart
/// A linked dive tank's slot in words: "Truck 2 · Bottle 14". The bottle is
/// left out when unknown or when it is the slot's own label (an owned
/// cylinder keeps its identifier as both).
String tripCylinderTankLine(
  AppLocalizations l10n,
  TripCylinderTankLabel label,
) {
  final bottle = label.bottle;
  return bottle == null || bottle == label.label
      ? label.label
      : '${label.label} · ${l10n.trips_cylinders_bottle(bottle)}';
}

/// A slot as the tank editor's picker lists it: label, the bottle in it
/// now, mix, pressure and status.
String tripCylinderPickerLabel(
  AppLocalizations l10n,
  UnitFormatter units,
  TripCylinderState state,
) => [
  tripCylinderTankLine(l10n, (
    label: state.cylinder.label,
    bottle: state.bottleLabel,
  )),
  state.mix == null ? '--' : tripCylinderMixLabel(l10n, state.mix!),
  state.pressure == null ? '--' : units.formatPressure(state.pressure),
  tripCylinderStatusLabel(l10n, state.status),
].join(' · ');
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2. Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/trips test/features/trips
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/domain/services/trip_cylinder_labels.dart lib/features/trips/presentation/providers/trip_cylinder_providers.dart lib/features/trips/presentation/helpers/trip_cylinder_display.dart test/features/trips/domain/services/trip_cylinder_labels_test.dart test/features/trips/presentation/helpers/trip_cylinder_display_test.dart
git commit -m "feat(trips): the bottle a slot held at a dive, and picker labels (#2325)"
```

---

### Task 3: Strings in every locale

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `diveLog_tank_tripCylinderLabel`, `diveLog_tank_tripCylinderNone`, `diveLog_tank_tripCylinderSuggested`, `trips_cylinders_action_logDive`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`:

```dart
  test('the dive link strings exist in English', () {
    expect(l10n.diveLog_tank_tripCylinderLabel, 'Trip cylinder');
    expect(l10n.diveLog_tank_tripCylinderNone, 'None');
    expect(
      l10n.diveLog_tank_tripCylinderSuggested,
      "Suggested from the trip's full cylinders",
    );
    expect(l10n.trips_cylinders_action_logDive, 'Log dive');
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: FAIL, the getters are undefined.

- [ ] **Step 3: Add the keys to all 11 ARB files and regenerate**

Insert the three `diveLog_tank_*` keys directly after `"diveLog_tank_regulatorNone"` and `trips_cylinders_action_logDive` directly after `"trips_cylinders_action_adjust"` in each file, preserving the file's line endings. Before writing, compare each locale's wording with its existing `trips_cylinders_title` and `diveLog_edit_group_trip` values and use the same word for "cylinder" and "trip"; adjust the values below to match where they differ.

| Locale | tripCylinderLabel | tripCylinderNone | tripCylinderSuggested | logDive |
| --- | --- | --- | --- | --- |
| en | Trip cylinder | None | Suggested from the trip's full cylinders | Log dive |
| ar | أسطوانة الرحلة | لا شيء | مقترحة من الأسطوانات الممتلئة في الرحلة | تسجيل غطسة |
| de | Flasche der Reise | Keine | Vorschlag aus den vollen Flaschen der Reise | Tauchgang eintragen |
| es | Botella del viaje | Ninguna | Sugerida entre las botellas llenas del viaje | Registrar inmersión |
| fr | Bloc du voyage | Aucun | Suggéré parmi les blocs pleins du voyage | Enregistrer une plongée |
| he | מכל הטיול | ללא | הוצע מתוך המכלים המלאים של הטיול | רישום צלילה |
| hu | Az út palackja | Nincs | Javaslat az út teli palackjai közül | Merülés rögzítése |
| it | Bombola del viaggio | Nessuna | Suggerita tra le bombole piene del viaggio | Registra immersione |
| nl | Fles van de reis | Geen | Voorgesteld uit de volle flessen van de reis | Duik vastleggen |
| pt | Cilindro da viagem | Nenhum | Sugerido entre os cilindros cheios da viagem | Registar mergulho |
| zh | 行程气瓶 | 无 | 从行程中已充满的气瓶建议 | 记录潜水 |

Then run `flutter gen-l10n` and confirm `git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'` lists all 12 generated files as modified.

- [ ] **Step 4: Run the test to verify it passes, then the l10n suite**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart test/l10n`
Expected: `All tests passed!` (the l10n suite checks placeholders, diacritics and parity).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb test/features/trips/presentation/helpers/trip_cylinder_display_test.dart
git commit -m "feat(trips): dive link strings in every locale (#2325)"
```

---

### Task 4: The trip cylinder picker in the tank editor

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart`
- Test: `test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart` (extend; it already has `_pump` and "an edit keeps the trip cylinder link")

**Interfaces:**
- Consumes: `tripCylinderStatesProvider(String tripId)` (FutureProvider.family), `tankFromTripCylinder` (Task 1), `tripCylinderPickerLabel` (Task 2), the Task 3 strings.
- Produces: `TankEditor({..., String? tripId, bool suggested = false})` and `TankRow({..., String? tripId, bool suggested = false})`. The picker has `Key('tank-trip-cylinder-picker')`. Picking reports the filled tank through `onChanged` once.

- [ ] **Step 1: Write the failing tests**

Extend `_pump` in `tank_editor_trip_cylinder_test.dart` with `String? tripId`, `bool suggested = false`, and `List<TripCylinderState> slots = const []` parameters; add to its overrides `if (tripId != null) tripCylinderStatesProvider(tripId).overrideWith((ref) async { if (ref.watch(_reload) > 0) await Completer<void>().future; return slots; })`, and pass `tripId: tripId, suggested: suggested` to `TankEditor`. Build slots with `foldCylinderState` as in Task 1 (a helper `filledSlot(String id, {double pressure = 200, double o2 = 32, String bottle = '14'})`). Then add:

```dart
  testWidgets('no trip, or a trip with no cylinders, shows no picker', (
    tester,
  ) async {
    await _pump(tester, equipment: const []);
    expect(find.byKey(const Key('tank-trip-cylinder-picker')), findsNothing);
    await _pump(tester, equipment: const [], tripId: 't1');
    expect(find.byKey(const Key('tank-trip-cylinder-picker')), findsNothing);
  });

  testWidgets('picking a slot links and fills the tank', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a', pressure: 205, o2: 32)],
      onChanged: (t) => changed = t,
    );
    await tester.ensureVisible(
      find.byKey(const Key('tank-trip-cylinder-picker')),
    );
    await tester.tap(find.byKey(const Key('tank-trip-cylinder-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Truck a').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, 'a');
    expect(changed!.gasMix.o2, 32);
    expect(changed!.startPressure, 205);
  });

  testWidgets('None clears the link and keeps the fields', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(
        id: 'tank-1',
        tripCylinderId: 'a',
        startPressure: 205,
        gasMix: GasMix(o2: 32),
      ),
      onChanged: (t) => changed = t,
    );
    await tester.ensureVisible(
      find.byKey(const Key('tank-trip-cylinder-picker')),
    );
    await tester.tap(find.byKey(const Key('tank-trip-cylinder-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, isNull);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.startPressure, 205);
  });

  testWidgets('a suggested link says so', (tester) async {
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'a'),
      suggested: true,
    );
    expect(find.text("Suggested from the trip's full cylinders"), findsOneWidget);
  });

  testWidgets('a reload keeps showing the linked slot', (tester) async {
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'a'),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(TankEditor)),
    ).read(_reload.notifier).state++;
    await tester.pump();
    expect(find.textContaining('Truck a'), findsOneWidget);
  });

  testWidgets('an open editor picks up a link set by the page', (
    tester,
  ) async {
    // The page fills a tank from a slot while its editor is open (a
    // suggestion, or the log-dive shortcut): the fields must show the fill,
    // or the next keystroke would write the old values back over it.
    final tank = ValueNotifier(const DiveTank(id: 'tank-1', startPressure: 180));
    DiveTank? changed;
    await _pumpHost(
      tester,
      tank: tank,
      tripId: 't1',
      slots: [filledSlot('a', pressure: 205)],
      onChanged: (t) => changed = t,
    );
    tank.value = tankFromTripCylinder(tank.value, filledSlot('a', pressure: 205));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'End Pressure'), '60');
    await tester.pump();
    expect(changed!.startPressure, 205);
    expect(changed!.tripCylinderId, 'a');
  });
```

`_pumpHost` is `_pump` with the `TankEditor` wrapped in `ValueListenableBuilder<DiveTank>(valueListenable: tank, builder: (_, t, _) => TankEditor(tank: t, tankNumber: 1, tripId: tripId, onChanged: onChanged, onRemove: () {}))`. If the pressure field's label differs from 'End Pressure' in this layout, find it by the key or label the existing `tank_editor_test.dart` uses for the end pressure field.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`
Expected: FAIL (`tripId`/`suggested` are not parameters of `TankEditor`).

- [ ] **Step 3: Implement**

In `tank_editor.dart`:

1. Add the parameters (after `onScanPending`), with doc comments:

```dart
  /// The dive's trip: when it has cylinders, a picker links this tank to
  /// one of them. Null hides the picker.
  final String? tripId;

  /// The link was preselected as a suggestion, so the picker says so until
  /// the diver changes it or the dive is saved.
  final bool suggested;
```

and `this.tripId, this.suggested = false,` in the constructor.

2. Extract controller disposal so a resync does not leak controllers. Replace the body of `dispose()` down to the focus node with a call:

```dart
  void _disposeControllers() {
    _volumeController.dispose();
    _workingPressureController.dispose();
    _startPressureController.dispose();
    _endPressureController.dispose();
    _o2Controller.dispose();
    _heController.dispose();
    _mndController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    _mndFocusNode.removeListener(_onMndFocusChanged);
    _mndFocusNode.dispose();
    super.dispose();
  }
```

3. Resync when the link changes from outside:

```dart
  @override
  void didUpdateWidget(TankEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new tank, or a link set by the page (a suggestion, the log-dive
    // shortcut, a trip change) that also filled the fields: re-read them,
    // or the next keystroke would write the old text back over the fill.
    if (oldWidget.tank.id != widget.tank.id ||
        oldWidget.tank.tripCylinderId != widget.tank.tripCylinderId) {
      _mndDriven = false;
      _disposeControllers();
      _initializeControllers();
    }
  }
```

4. Split `_notifyChange()` into a builder and a notifier, without changing what is built (the comment on `tripCylinderId` changes, since the picker now edits it):

```dart
  /// The tank as the fields describe it now.
  DiveTank _currentTank() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final specs = _metricSpecs();

    final startPressureDisplay = _startPressure.resolve(
      _startPressureController.text,
    );
    final endPressureDisplay = _endPressure.resolve(
      _endPressureController.text,
    );

    return DiveTank(
      id: widget.tank.id,
      name: widget.tank.name,
      volume: specs.volumeLiters,
      workingPressure: specs.workingPressureBar,
      startPressure: startPressureDisplay != null
          ? units.pressureToBar(startPressureDisplay)
          : null,
      endPressure: endPressureDisplay != null
          ? units.pressureToBar(endPressureDisplay)
          : null,
      gasMix: _currentGasMix(),
      role: _role,
      material: _material,
      order: widget.tank.order,
      presetName: _selectedPreset?.name,
      // Preserve source-computer attribution and transmitter identity
      // through edits; only consolidation/unlink flows may change them.
      computerId: widget.tank.computerId,
      transmitterSerial: widget.tank.transmitterSerial,
      regulatorEquipmentId: _regulatorEquipmentId,
      // Only the trip cylinder picker changes the link; every other edit
      // carries it, or updateDive would wipe it on the next save.
      tripCylinderId: widget.tank.tripCylinderId,
    );
  }

  void _notifyChange() => widget.onChanged(_currentTank());
```

5. Add the picker and its handler:

```dart
  Widget _buildTripCylinderPicker(String tripId) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    // `value`, not `valueOrNull`: it keeps the previous list while the
    // provider reloads, so the tank's slot does not flicker to None.
    final states =
        ref.watch(tripCylinderStatesProvider(tripId)).value ??
        const <TripCylinderState>[];
    if (states.isEmpty) return const SizedBox.shrink();
    final linked = widget.tank.tripCylinderId;
    final known = states.any((s) => s.cylinder.id == linked);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        key: const Key('tank-trip-cylinder-picker'),
        initialValue: known ? linked : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.diveLog_tank_tripCylinderLabel,
          helperText: widget.suggested && known
              ? l10n.diveLog_tank_tripCylinderSuggested
              : null,
          isDense: true,
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l10n.diveLog_tank_tripCylinderNone),
          ),
          for (final s in states)
            DropdownMenuItem<String?>(
              value: s.cylinder.id,
              child: Text(
                tripCylinderPickerLabel(l10n, units, s),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) => _pickTripCylinder(states, id),
      ),
    );
  }

  /// Links the tank to the slot [id] and fills it from that slot (decided
  /// 2026-09-28), or clears only the link for None. The page's new tank
  /// comes back through didUpdateWidget, which re-reads the fields.
  void _pickTripCylinder(List<TripCylinderState> states, String? id) {
    final current = _currentTank();
    final slot = states.where((s) => s.cylinder.id == id).firstOrNull;
    widget.onChanged(
      slot == null
          ? current.copyWith(clearTripCylinderId: true)
          : tankFromTripCylinder(current, slot),
    );
  }
```

6. In `build`, place `if (widget.tripId case final tripId?) _buildTripCylinderPicker(tripId),` immediately before `_buildRegulatorPicker()`.

7. Add imports: `trip_cylinder_state.dart` (entities), `trip_cylinder_tank_link.dart`, `trip_cylinder_display.dart`, `trip_cylinder_providers.dart`.

In `tank_row.dart`, add the same two fields (`final String? tripId; final bool suggested;`, constructor `this.tripId, this.suggested = false`) and pass `tripId: widget.tripId, suggested: widget.suggested` to its `TankEditor`.

- [ ] **Step 4: Run the tests to verify they pass, with the other tank editor suites**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart test/features/dive_log/presentation/widgets/tank_editor_test.dart test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/dive_log test/features/dive_log
dart analyze --fatal-infos lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets/tank_editor.dart lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart
git commit -m "feat(dive-log): pick the trip cylinder a tank was breathed from (#2325)"
```

---

### Task 5: The dive edit page: trip changes, suggestions and the log-dive parameters

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/core/router/app_router.dart` (`newDive` route, near line 383)
- Test: create `test/features/dive_log/presentation/pages/dive_edit_trip_cylinder_test.dart`

**Interfaces:**
- Consumes: `suggestTripCylindersForTanks`, `tankFromTripCylinder` (Task 1); `TankRow(tripId:, suggested:)` (Task 4); `tripCylinderStatesProvider`; `tripRepositoryProvider.getTripById`.
- Produces: `DiveEditPage({..., String? tripId, String? tripCylinderId})` (create mode only); the `newDive` route passes `state.uri.queryParameters['tripId']` and `['tripCylinderId']`.

- [ ] **Step 1: Write the failing tests**

Follow `dive_edit_prefill_test.dart`'s harness: `setUpTestDatabase()`, `getBaseOverrides()`, `DiveRepository`, a tall surface (800x2600), and `pump()` plus `pump(400ms)` instead of `pumpAndSettle` (the new-dive path starts a GPS capture timer). Seed a trip covering today and two slots `a` then `b`, both filled to 200 bar of EAN32 on a 207 bar working pressure, `a`'s fill an hour before `b`'s (so the oldest-fill-first suggestion picks `a`), through `TripRepository` and `TripCylinderRepository`. Add `DiveEditPage({... tripId, tripCylinderId})` to the pump helper. Read the tanks through the save path (`onSaved`, then `DiveRepository().getDiveById(id)`), or through `find.byType(TankRow)` widgets' `tank` fields.

```dart
  testWidgets('the log-dive shortcut links the first tank to its slot', (
    tester,
  ) async {
    await pumpEditPage(tester, tripId: trip.id, tripCylinderId: b.id);
    await settleTrip(tester); // pump until the async trip load lands
    final tank = tester.widget<TankRow>(find.byType(TankRow).first).tank;
    expect(tank.tripCylinderId, b.id);
    expect(tank.startPressure, 200);
    expect(tank.gasMix.o2, 32);
    // Chosen on the board, not suggested.
    expect(tester.widget<TankRow>(find.byType(TankRow).first).suggested, isFalse);
  });

  testWidgets('a trip with no slot named suggests one for the new tank', (
    tester,
  ) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    final row = tester.widget<TankRow>(find.byType(TankRow).first);
    expect(row.tank.tripCylinderId, a.id); // oldest fill first
    expect(row.suggested, isTrue);
  });

  testWidgets('an added tank takes the next full slot', (tester) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final rows = tester.widgetList<TankRow>(find.byType(TankRow)).toList();
    expect(rows[0].tank.tripCylinderId, a.id);
    expect(rows[1].tank.tripCylinderId, b.id);
  });

  testWidgets('None turns the suggestion down for good', (tester) async {
    await pumpEditPage(tester, tripId: trip.id);
    await settleTrip(tester);
    final first = tester.widget<TankRow>(find.byType(TankRow).first);
    first.onChanged(first.tank.copyWith(clearTripCylinderId: true));
    await tester.pump();
    await tester.tap(find.text('Add Tank'));
    await settleTrip(tester);
    final rows = tester.widgetList<TankRow>(find.byType(TankRow)).toList();
    expect(rows[0].tank.tripCylinderId, isNull);
    expect(rows[0].suggested, isFalse);
    expect(rows[1].tank.tripCylinderId, isNotNull);
  });

  testWidgets('clearing the trip drops every tank link', (tester) async {
    await pumpEditPage(tester, tripId: trip.id, tripCylinderId: b.id);
    await settleTrip(tester);
    await tester.tap(find.text('Trip')); // expand the trip section
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(TripSection),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pump();
    final tank = tester.widget<TankRow>(find.byType(TankRow).first).tank;
    expect(tank.tripCylinderId, isNull);
  });

  testWidgets('a loaded tank is never suggested', (tester) async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        dateTime: DateTime.now(),
        trip: trip,
        tanks: const [DiveTank(id: 'k1', startPressure: 200, endPressure: 60)],
      ),
    );
    await pumpEditPage(tester, diveId: dive.id);
    await settleTrip(tester);
    final row = tester.widget<TankRow>(find.byType(TankRow).first);
    expect(row.tank.tripCylinderId, isNull);
    expect(row.suggested, isFalse);
  });

  testWidgets('the link is saved with the dive', (tester) async {
    String? savedId;
    await pumpEditPage(
      tester,
      tripId: trip.id,
      tripCylinderId: b.id,
      onSaved: (id) => savedId = id,
    );
    await settleTrip(tester);
    await tester.tap(find.text('Save'));
    await settleTrip(tester);
    final saved = await DiveRepository().getDiveById(savedId!);
    expect(saved!.tanks.first.tripCylinderId, b.id);
  });
```

`settleTrip` is `for (var i = 0; i < 10; i++) { await tester.pump(const Duration(milliseconds: 100)); }` (the trip load, the states provider and the suggestion each take a microtask turn or two; `pumpAndSettle` never returns on this page). Match the `Dive(...)` constructor to the entity's required fields in `dive.dart`. If `find.text('Trip')` also matches another widget, tap `find.widgetWithText(InkWell, 'Trip').first` or the section header key `dive_edit_page_test.dart` uses.

Also add a router test in the same file: build `testAppRouter` (`test/helpers/test_app.dart`) with the real `/dives/new` route builder copied from `app_router.dart`, `go('/dives/new?tripId=${trip.id}&tripCylinderId=${b.id}')`, and assert `find.byType(DiveEditPage)` has `tripId == trip.id` and `tripCylinderId == b.id`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_log/presentation/pages/dive_edit_trip_cylinder_test.dart`
Expected: FAIL (`tripId`/`tripCylinderId` are not parameters of `DiveEditPage`).

- [ ] **Step 3: Implement**

In `DiveEditPage`, add after `prefill`:

```dart
  /// Create mode only: the trip to put the new dive on (the board's Log
  /// dive shortcut). Ignored when editing.
  final String? tripId;

  /// Create mode only, with [tripId]: the slot the first tank breathes
  /// from. Without it, the first tank gets the usual suggestion.
  final String? tripCylinderId;
```

and `this.tripId, this.tripCylinderId` in the constructor.

In `_DiveEditPageState`, next to `_tanks`:

```dart
  /// Tanks the dive had when it was loaded: never suggested a slot, since
  /// the suggestion is only for tanks added in this editing session.
  Set<String> _loadedTankIds = const {};

  /// Tanks whose slot link is a suggestion the diver has not confirmed.
  Set<String> _suggestedTankIds = const {};

  /// Tanks the diver set to None after a suggestion: never re-suggested.
  Set<String> _declinedTankIds = const {};
```

In `_loadExistingDive`, beside `_tanks = List.from(dive.tanks);`, add `_loadedTankIds = {for (final t in dive.tanks) t.id};`.

Add the two methods (near `_showTripPicker`):

```dart
  /// Every change of the dive's trip goes through here. Tank links point
  /// into one trip's cylinders, so a different trip (or none) drops them
  /// all at once, with their suggestion marks, and new tanks get a
  /// suggestion from the new trip.
  void _setTrip(Trip? trip, {bool markDirty = true}) {
    if (markDirty) _markDirty();
    final changed = trip?.id != _selectedTrip?.id;
    setState(() {
      _selectedTrip = trip;
      if (changed && _tanks.any((t) => t.tripCylinderId != null)) {
        _tanks = [
          for (final t in _tanks)
            t.tripCylinderId == null
                ? t
                : t.copyWith(clearTripCylinderId: true),
        ];
        _tanksDirty = true;
      }
      if (changed) {
        _suggestedTankIds = const {};
        _declinedTankIds = const {};
      }
    });
    if (changed) {
      logFailure(
        _suggestTripCylinders(),
        _DiveEditPageState,
        'suggest trip cylinders',
      );
    }
  }

  /// Suggests a full trip cylinder for each tank added in this editing
  /// session that has none and whose suggestion the diver has not turned
  /// down. Runs when the trip is set and when a tank is added.
  Future<void> _suggestTripCylinders() async {
    final tripId = _selectedTrip?.id;
    if (tripId == null || widget.isBulk) return;
    final states = await ref.read(tripCylinderStatesProvider(tripId).future);
    if (!mounted || _selectedTrip?.id != tripId) return;
    final result = suggestTripCylindersForTanks(
      tanks: _tanks,
      states: states,
      eligibleTankIds: {
        for (final t in _tanks)
          if (!_loadedTankIds.contains(t.id) &&
              !_declinedTankIds.contains(t.id))
            t.id,
      },
    );
    if (result.suggested.isEmpty) return;
    setState(() {
      _tanks = result.tanks;
      _suggestedTankIds = {..._suggestedTankIds, ...result.suggested};
      // Keeps _loadDefaultPreset from rebuilding the first tank over it.
      _tanksDirty = true;
    });
  }

  /// The board's Log dive shortcut: the new dive goes on [tripId], and its
  /// first tank breathes from [cylinderId], filled from that slot. The
  /// diver chose the slot, so it is not marked as a suggestion; any other
  /// new tank, or a slot that no longer exists, gets the usual suggestion.
  Future<void> _applyTripLink(String tripId, String? cylinderId) async {
    final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
    if (trip == null || !mounted) return;
    final states = await ref.read(tripCylinderStatesProvider(tripId).future);
    if (!mounted) return;
    final slot = states.where((s) => s.cylinder.id == cylinderId).firstOrNull;
    setState(() {
      _selectedTrip = trip;
      if (slot != null && _tanks.isNotEmpty) {
        _tanks = [tankFromTripCylinder(_tanks.first, slot), ..._tanks.skip(1)];
        _tanksDirty = true;
      }
    });
    await _suggestTripCylinders();
  }
```

Replace every direct `_selectedTrip = ...` assignment outside `_loadExistingDive` and `_applyTripLink` with `_setTrip`:
- `onClearTrip` (near line 643): `onClearTrip: () => _setTrip(null),`
- the bulk layout's `onClear` (near line 1225): `() => _setTrip(null)`
- the trip suggestion `InkWell.onTap` (near line 2685): `onTap: () => _setTrip(suggestedTrip),`
- its "Use" button (near line 2708): `onPressed: () => _setTrip(suggestedTrip),` (this also marks the form dirty, which the old code forgot)
- `TripPickerSheet.onTripSelected` (near line 2735): `Navigator.of(sheetContext).pop(); _setTrip(trip);`
- the new-trip flow (near line 2752): `if (trip != null && mounted) _setTrip(trip);`

Search once more with `grep -n "_selectedTrip = " lib/features/dive_log/presentation/pages/dive_edit_page.dart`: only `_loadExistingDive`, `_setTrip` and `_applyTripLink` may remain.

In `initState`'s new-dive branch, after `_applyPrefill();`:

```dart
      if (widget.tripId case final tripId?) {
        logFailure(
          _applyTripLink(tripId, widget.tripCylinderId),
          _DiveEditPageState,
          'apply trip link',
        );
      }
```

At the end of `_addTank()`, after its `setState`:

```dart
    logFailure(
      _suggestTripCylinders(),
      _DiveEditPageState,
      'suggest trip cylinders',
    );
```

In `_buildGasGearSection`'s `TankRow` (the single-dive loop only; the bulk editor's loop stays as it is), pass `tripId: _selectedTrip?.id, suggested: _suggestedTankIds.contains(_tanks[i].id),` and track the diver's link choices in `onChanged`:

```dart
          onChanged: (updatedTank) {
            final before = _tanks[i];
            setState(() {
              _markDirty();
              _tanksDirty = true;
              _tanks[i] = updatedTank;
              if (updatedTank.tripCylinderId != before.tripCylinderId) {
                // The diver chose: the link is no longer a suggestion, and
                // a None is not overruled by the next suggestion pass.
                _suggestedTankIds = {
                  for (final id in _suggestedTankIds)
                    if (id != updatedTank.id) id,
                };
                if (updatedTank.tripCylinderId == null) {
                  _declinedTankIds = {..._declinedTankIds, updatedTank.id};
                }
              }
            });
          },
```

Add imports for `trip_cylinder_providers.dart` and `trip_cylinder_tank_link.dart`.

In `app_router.dart`, the `newDive` route:

```dart
            GoRoute(
              path: 'new',
              name: 'newDive',
              builder: (context, state) => DiveEditPage(
                prefill: state.extra as DivePrefill?,
                tripId: state.uri.queryParameters['tripId'],
                tripCylinderId: state.uri.queryParameters['tripCylinderId'],
              ),
            ),
```

- [ ] **Step 4: Run the tests to verify they pass, with the other dive edit suites**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_log/presentation/pages/dive_edit_trip_cylinder_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart test/features/dive_log/data/repositories/dive_tank_trip_cylinder_link_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/dive_log lib/core/router test/features/dive_log
dart analyze --fatal-infos lib/features/dive_log lib/core/router test/features/dive_log
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/core/router/app_router.dart test/features/dive_log/presentation/pages/dive_edit_trip_cylinder_test.dart
git commit -m "feat(dive-log): suggest trip cylinders for new tanks, and open a dive on a slot (#2325)"
```

---

### Task 6: "Log dive" on the board

**Files:**
- Modify: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart`
- Test: `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart` (append)

**Interfaces:**
- Consumes: the `newDive` route's `tripId`/`tripCylinderId` query parameters (Task 5); `trips_cylinders_action_logDive` (Task 3).
- Produces: `_SlotAction.logDive`, pushing `/dives/new?tripId=<tripId>&tripCylinderId=<slotId>`.

- [ ] **Step 1: Write the failing test**

The board test hosts a plain `MaterialApp`; this test needs a router. Add:

```dart
  testWidgets('Log dive opens a new dive on that slot', (tester) async {
    final a = await slot('Truck 1', 0);
    String? pushed;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => TripCylinderBoardPage(tripId: tripId),
        ),
        GoRoute(
          path: '/dives/new',
          builder: (_, state) {
            pushed = state.uri.toString();
            return const Scaffold(body: Text('NEW DIVE'));
          },
        ),
      ],
    );
    await pumpBoardWithRouter(tester, router); // pumpBoard's overrides, MaterialApp.router

    await tester.tap(find.byKey(Key('slot-menu-${a.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log dive'));
    await tester.pumpAndSettle();

    expect(find.text('NEW DIVE'), findsOneWidget);
    final uri = Uri.parse(pushed!);
    expect(uri.queryParameters['tripId'], tripId);
    expect(uri.queryParameters['tripCylinderId'], a.id);
  });
```

`pumpBoardWithRouter` is `pumpBoard` with `MaterialApp.router(routerConfig: router, ...)` in place of `MaterialApp(home: ...)`; add it beside `pumpBoard` and import `package:go_router/go_router.dart`.

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: FAIL, no 'Log dive' menu item.

- [ ] **Step 3: Implement**

In `trip_cylinder_slot_card.dart`: `enum _SlotAction { fill, adjust, logDive, edit, delete }`; import `package:go_router/go_router.dart`; in `_act`:

```dart
      _SlotAction.logDive => context.push(
        Uri(
          path: '/dives/new',
          queryParameters: {'tripId': c.tripId, 'tripCylinderId': c.id},
        ).toString(),
      ),
```

and a menu item after Adjust:

```dart
            PopupMenuItem(
              value: _SlotAction.logDive,
              child: Text(l10n.trips_cylinders_action_logDive),
            ),
```

- [ ] **Step 4: Run it to verify it passes**

Run the Step 2 command. Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/trips test/features/trips
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart
git commit -m "feat(trips): log a dive on a cylinder from the board (#2325)"
```

---

### Task 7: The slot line on the dive detail page

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_test.dart` (append)

**Interfaces:**
- Consumes: `tripCylinderLabelsAtProvider` and `tripCylinderTankLine` (Task 2); `Dive.tripId`, `Dive.trip`, `Dive.effectiveEntryTime`.
- Produces: under a linked tank, a `Text` with `Key('tank-trip-cylinder-<tankId>')`.

- [ ] **Step 1: Write the failing tests**

Using `_buildCard`'s `extraOverrides`:

```dart
  testWidgets('a linked tank names its slot and bottle', (tester) async {
    final dive = testDive.copyWith(
      tripId: 't1',
      tanks: [testDive.tanks.first.copyWith(tripCylinderId: 'a')],
    );
    await tester.pumpWidget(
      _buildCard(
        dive,
        extraOverrides: [
          tripCylinderLabelsAtProvider((
            tripId: 't1',
            atMillis: dive.effectiveEntryTime.millisecondsSinceEpoch,
          )).overrideWith((ref) async => {'a': (label: 'Truck 2', bottle: '14')}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Truck 2 · Bottle 14'), findsOneWidget);
  });

  testWidgets('an unlinked tank shows no slot line', (tester) async {
    await tester.pumpWidget(_buildCard(testDive.copyWith(tripId: 't1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bottle'), findsNothing);
  });
```

Adapt `testDive` and `_buildCard` names to the helpers the file already defines; if `Dive.copyWith` has no `tripId`, build the dive with the constructor as the file's other tests do.

- [ ] **Step 2: Run them to verify they fail**

Run: `TMPDIR=<scratchpad>/tmp flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: FAIL, no slot line.

- [ ] **Step 3: Implement**

In `CylindersCard.build`, after `knownSerials`:

```dart
    // Linked tanks name their trip cylinder and the bottle it held when the
    // dive started (decided 2026-09-28). Only read when a tank is linked.
    final tripId = dive.tripId ?? dive.trip?.id;
    final slotLabels =
        tripId == null || !dive.tanks.any((t) => t.tripCylinderId != null)
        ? const <String, TripCylinderTankLabel>{}
        : ref
                  .watch(
                    tripCylinderLabelsAtProvider((
                      tripId: tripId,
                      atMillis: dive.effectiveEntryTime.millisecondsSinceEpoch,
                    )),
                  )
                  .value ??
              const <String, TripCylinderTankLabel>{};
```

Pass `slotLabel: slotLabels[entry.value.tripCylinderId]` to `_tankRow` (new named parameter `required TripCylinderTankLabel? slotLabel`). In `_tankRow`'s subtitle `Column`, after the MOD/MND `Text`:

```dart
          if (slotLabel != null)
            Text(
              tripCylinderTankLine(context.l10n, slotLabel),
              key: Key('tank-trip-cylinder-${tank.id}'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
```

and widen `isThreeLine` to `serial != null || consumptionRow != null || slotLabel != null`. Import `trip_cylinder_labels.dart`, `trip_cylinder_display.dart` and `trip_cylinder_providers.dart`.

- [ ] **Step 4: Run them to verify they pass**

Run the Step 2 command. Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
dart format lib/features/dive_log test/features/dive_log
dart analyze --fatal-infos lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git commit -m "feat(dive-log): name the trip cylinder under a linked tank (#2325)"
```

---

### Task 8: Whole-branch verification and the pull request

**Files:** none new.

- [ ] **Step 1: Analyze and check the generated localizations**

```bash
dart format .
flutter analyze --fatal-infos
flutter gen-l10n
git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'
```

Expected: `No issues found!` and no output from the last command.

- [ ] **Step 2: Run the affected suites, one at a time**

```bash
flutter test test/features/trips
flutter test test/features/dive_log
flutter test test/l10n
flutter test test/architecture
flutter test test/shared
flutter test test/core/services/sync
```

Expected: each ends `All tests passed!`.

- [ ] **Step 3: Run the full suite once, alone**

`flutter test` with nothing else testing in this worktree. A failure in a file this branch never touched: check `origin/main` first (the shard 3 theme hang of 2026-09-28 was main's).

- [ ] **Step 4: Scan the branch for forbidden text**

```bash
git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|\x{2013})"
```

Expected: no output. Scan the same diff for the two tool-attribution terms; expected: no output.

- [ ] **Step 5: Capture the screenshots**

This PR changes `lib/**/presentation/`. With a throwaway golden test (never committed; recipe in the program memory: real Roboto and MaterialIcons from the SDK, `assets/fonts/materialdesignicons-webfont.ttf` as 'Material Design Icons', the app theme via `AppThemeRegistry.resolveTheme`, a seeded in-memory database), capture in light and dark at phone (390x844) and desktop (1280x800), 2x:
1. The tank editor with the Trip cylinder picker open, and a suggested link with its helper text (new).
2. The board slot menu showing Log dive (after), and the same menu on main (before).
3. The dive detail cylinders card with a linked tank's slot line (after) and on main (before).

Send the images with `SendUserFile`, then delete the test and its `goldens/` folder.

- [ ] **Step 6: Push and open the pull request, only when the user asks**

Push with `-u`, then `unset GITHUB_TOKEN; gh pr create --repo submersion-app/submersion --base main ...` with a body whose first section is `Part of #2325`, following `.github/PULL_REQUEST_TEMPLATE.md`, its Screenshots section naming each image. Bind the PR in the desktop app; never poll CI.
