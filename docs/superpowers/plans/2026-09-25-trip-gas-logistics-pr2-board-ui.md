# Trip Gas Logistics PR 2: Board UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a trip a visible, editable cylinder board: a compact card in the trip story, a board page with the slots and their state, sheets to add slots, record fills and adjustments and edit slots, and a ledger of every event.

**Architecture:** Everything reads the PR 1 providers (`tripCylinderStatesProvider`, the repository) and writes through `TripCylinderRepository`; no widget computes state itself, it renders `TripCylinderState` from the pure fold. Sheets follow the rental gear note sheet's shape (a `show...Sheet` helper, a `ConsumerStatefulWidget`, manual validation, `parseUserDecimal`, unit conversion on save). Display text is built by small pure helpers so it is unit-tested once and reused by the card, the board and the ledger.

**Tech Stack:** Flutter, Dart, Riverpod (through `core/providers/provider.dart`), go_router, Drift (via the PR 1 repository), `flutter gen-l10n`, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-25-trip-gas-logistics-design.md` (sections Phase 1 UI, Deriving a slot's state, Edge cases, Testing, Delivery item 2). PR 1 plan for the data layer names: `docs/superpowers/plans/2026-09-25-trip-gas-logistics-pr1-data-sync.md`.

## Global Constraints

- Starts only after PR 1 (#2331) is merged. Create a fresh worktree from `origin/main` containing that merge, then run `git submodule update --init --recursive`, `flutter pub get`, and codegen (`grep build_runner scripts/setup.sh | sh`; a bare `build` token is refused in a Bash command). Copy this plan into the new worktree's `docs/superpowers/plans/` if it is not already on main.
- No schema change in this PR. If a task seems to need one, stop: it belongs to PR 4.
- Out of scope, PR 3: the tank editor's trip cylinder picker, the per-slot "Log dive" action and the new-dive shortcut, and the slot line on dive detail. The spec lists "Log dive" among the board's slot actions; it arrives with PR 3, which owns the dive side.
- Every displayed pressure goes through `UnitFormatter.formatPressure` (metric bar in); every cylinder size through `formatTankVolume(liters, workingPressureBar)`; every typed pressure converts with `pressureToBar`; money through `formatMoney` from `lib/core/utils/currency.dart`; a stored `currency` of null means `defaultCurrencyProvider`.
- Event times are the wall clock stamped UTC (`tripCylinderWallClock`); display them with `units.formatDateTime(dt, l10n: l10n)` (never without `l10n:`, which ships an English "at").
- Every user-visible string is an ARB key present in all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh). A plural's singular branch interpolates its count placeholder, never a literal 1 (French and Portuguese put zero in the one category). After any ARB edit run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` files in the same commit.
- Imports grouped dart, flutter, packages, local; widgets reach Riverpod through `package:submersion/core/providers/provider.dart` or `flutter_riverpod`, as the neighbouring file does.
- Tests that import `package:submersion/core/database/database.dart` narrow it with `show` (the Drift `Trip` and `DiveTank` data classes clash with the domain names).
- No em-dashes or en-dashes as punctuation anywhere, no emojis, no tool or model attribution in code, comments, commits or the PR.
- `dart format .` after every task; gate commits on `dart analyze --fatal-infos <files>` printing `No issues found!` (never pipe the analyzer through `tail` and then commit on its exit status).
- Run tests unpiped and one run at a time. One commit per task. PR body carries `Part of #2325`.

## Review Focus

1. An imperial diver types a fill pressure in psi: the stored event holds bar, and the board shows psi again. Pinned in Task 6.
2. A multi-slot fill where the diver types a bottle number for a slot and then unchecks it: that slot gets no event. Pinned in Task 6.
3. Analyzed O2 plus He over 100 (or O2 below 1) is refused with the mix error and nothing is saved, for any selected slot. Pinned in Task 6.
4. Deleting a slot that dives used names the dive count, and the dive keeps its tank data after the delete. Pinned in Task 8.
5. A past trip with slots still shows its card (a record), and a past trip without slots shows nothing, while an upcoming or current trip without slots offers "Set up cylinders". Pinned in Task 9.

## File Structure

Create:
- `lib/features/trips/presentation/helpers/trip_cylinder_display.dart`: mix label, status label and colour, counts, last-item sentence. Pure.
- `lib/features/trips/presentation/helpers/trip_cylinder_specs_input.dart`: cylinder size and working pressure to and from the diver's units. Pure.
- `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart`: edit one slot.
- `lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart`: add rental slots or owned cylinders.
- `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart`: record or edit a fill, one or several slots.
- `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart`: record or edit an adjustment.
- `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart`: one slot on the board, with its menu and the delete confirmation.
- `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart`: the ledger segment.
- `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart`: the board page.
- `lib/features/trips/presentation/widgets/trip_cylinders_card.dart`: the story card.
- Tests mirroring each file under `test/features/trips/...`.

Modify:
- `lib/features/trips/domain/entities/trip_cylinder_state.dart`, `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`, `lib/features/trips/data/repositories/trip_cylinder_repository.dart`: the two deferred review minors, the last item, the site name, reorder.
- `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`: the ledger provider (Task 10).
- `lib/core/router/app_router.dart`: the `cylinders` route.
- `lib/features/trips/presentation/pages/trip_detail_page.dart`: the card in both layouts.
- `lib/l10n/arb/app_*.arb` and the generated localizations.

---

### Task 1: Data follow-ups from the PR 1 review

**Files:**
- Modify: `lib/features/trips/domain/entities/trip_cylinder_state.dart`
- Modify: `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`
- Modify: `lib/features/trips/data/repositories/trip_cylinder_repository.dart`
- Test: `test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`
- Test: `test/features/trips/data/repositories/trip_cylinder_repository_test.dart`

**Interfaces:**
- Consumes: PR 1's `TripCylinderTankUse`, `TripCylinderState`, `foldCylinderState`, `TripCylinderRepository`.
- Produces: `TripCylinderTankUse.siteName` (`String?`); `TripCylinderState.lastEvent` (`TripCylinderEvent?`) and `TripCylinderState.lastUse` (`TripCylinderTankUse?`), exactly one non-null when the slot has any timeline item; `TripCylinderRepository.reorderCylinders(List<String> orderedIds)` returning `Future<void>`.

- [ ] **Step 1: Write the failing fold tests**

Append inside `main()` of `test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`, after the existing `group('foldCylinderState', ...)`:

```dart
  group('determinism and the last item', () {
    test('two fills on one instant resolve by id, whatever the input order', () {
      // Two devices filling the same slot at the same millisecond.
      final x = fill(0, id: 'x', pressure: 200);
      final y = fill(0, id: 'y', pressure: 180);
      expect(fold(events: [x, y]).pressure, 180);
      expect(fold(events: [y, x]).pressure, 180);
    });

    test('two tanks on one instant resolve by tank id', () {
      final a = dive(60, tankId: 'a', end: 100);
      final b = dive(60, tankId: 'b', end: 90);
      expect(fold(events: [fill(0)], uses: [a, b]).pressure, 90);
      expect(fold(events: [fill(0)], uses: [b, a]).pressure, 90);
    });

    test('the last item is the event when an event came last', () {
      final f = fill(120, label: '14');
      final s = fold(events: [f], uses: [dive(60)]);
      expect(s.lastEvent, f);
      expect(s.lastUse, isNull);
    });

    test('the last item is the tank use when a dive came last', () {
      final d = dive(60);
      final s = fold(events: [fill(0)], uses: [d]);
      expect(s.lastUse, d);
      expect(s.lastEvent, isNull);
    });

    test('an untouched slot has no last item', () {
      final s = fold();
      expect(s.lastEvent, isNull);
      expect(s.lastUse, isNull);
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`
Expected: FAIL to compile: `lastEvent` and `lastUse` are not defined on `TripCylinderState`.

- [ ] **Step 3: Extend the state entities**

In `lib/features/trips/domain/entities/trip_cylinder_state.dart`:

In `TripCylinderTankUse`, after `final GasMix gasMix;` add:

```dart

  /// The dive's site name, for the board's "Dived at ..." line; null when
  /// the dive has no site.
  final String? siteName;
```

In its constructor after `this.gasMix = const GasMix(),` add `this.siteName,`, and in its `props` after `gasMix,` add `siteName,`.

In `TripCylinderState`, after `final int linkedDiveCount;` add:

```dart

  /// The last timeline item when it was a fill or an adjustment.
  final TripCylinderEvent? lastEvent;

  /// The last timeline item when it was a dive. Exactly one of [lastEvent]
  /// and [lastUse] is set when the slot has any history.
  final TripCylinderTankUse? lastUse;
```

In its constructor after `this.linkedDiveCount = 0,` add `this.lastEvent,` and `this.lastUse,`; in its `props` after `linkedDiveCount,` add `lastEvent,` and `lastUse,`.

- [ ] **Step 4: Make the fold deterministic and report the last item**

In `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`, in `class _Item`, after the constructor add:

```dart

  /// Breaks a tie on instant and rank so the order never depends on input
  /// order or on the sort's stability.
  String get tieKey => event?.id ?? use!.tankId;
```

Replace the sort comparator body

```dart
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.rank.compareTo(b.rank);
```

with

```dart
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.tieKey.compareTo(b.tieKey);
```

In the returned `TripCylinderState(...)`, after `linkedDiveCount: ...,` add:

```dart
    lastEvent: last?.event,
    lastUse: last?.use,
```

- [ ] **Step 5: Run the fold tests to verify they pass**

Run: `flutter test test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`
Expected: PASS, 31 tests.

- [ ] **Step 6: Write the failing repository tests**

In `test/features/trips/data/repositories/trip_cylinder_repository_test.dart`, widen the database import's `show` to `AppDatabase, DiveSitesCompanion, DivesCompanion, DiveTanksCompanion` and append inside `main()`:

```dart
  group('board follow-ups', () {
    test('a linked tank on a dive of another trip is not counted', () async {
      // A cross-device race: one device links the tank, the other moves the
      // dive to another trip. The board must count only this trip's dives.
      final a = await repository.createCylinder(slot(label: 'A'));
      await insertDiveWithTank(
        diveId: 'd1',
        tankId: 't1',
        entryMillis: at.millisecondsSinceEpoch,
        cylinderId: a.id,
      );
      await db.customUpdate(
        'UPDATE dives SET trip_id = ? WHERE id = ?',
        variables: [Variable<String>(otherTripId), Variable<String>('d1')],
      );

      expect(await repository.getTankUsesForTrip(tripId), isEmpty);
    });

    test('a tank use carries its dive site name', () async {
      final a = await repository.createCylinder(slot(label: 'A'));
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 's1',
              name: 'Salt Pier',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await insertDiveWithTank(
        diveId: 'd1',
        tankId: 't1',
        entryMillis: at.millisecondsSinceEpoch,
        cylinderId: a.id,
      );
      await db.customUpdate(
        "UPDATE dives SET site_id = 's1' WHERE id = 'd1'",
      );

      final uses = await repository.getTankUsesForTrip(tripId);
      expect(uses[a.id]!.single.siteName, 'Salt Pier');
    });

    test('reorder rewrites board order and stages only moved rows', () async {
      final a = await repository.createCylinder(slot(label: 'A'));
      final b = await repository.createCylinder(slot(label: 'B', sortOrder: 1));
      final c = await repository.createCylinder(slot(label: 'C', sortOrder: 2));
      await db.customStatement("DELETE FROM sync_records");

      await repository.reorderCylinders([c.id, a.id, b.id]);

      final listed = await repository.getCylindersForTrip(tripId);
      expect(listed.map((x) => x.label), ['C', 'A', 'B']);
      expect(await pendingCountFor('tripCylinders', c.id), 1);
      expect(await pendingCountFor('tripCylinders', a.id), 1);
      expect(await pendingCountFor('tripCylinders', b.id), 1);

      await db.customStatement("DELETE FROM sync_records");
      await repository.reorderCylinders([c.id, a.id, b.id]);
      expect(await pendingCountFor('tripCylinders', a.id), 0);
    });
  });
```

- [ ] **Step 7: Run them to verify they fail**

Run: `flutter test test/features/trips/data/repositories/trip_cylinder_repository_test.dart`
Expected: FAIL to compile: `siteName` and `reorderCylinders` are not defined.

- [ ] **Step 8: Filter on the dive's trip, read the site, add reorder**

In `lib/features/trips/data/repositories/trip_cylinder_repository.dart`, in `getTankUsesForTrip`, replace the SQL body

```sql
          SELECT t.id AS tank_id, t.dive_id, d.dive_date_time,
                 t.start_pressure, t.end_pressure, t.o2_percent, t.he_percent,
                 t.trip_cylinder_id
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          WHERE t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?)
          ORDER BY d.dive_date_time ASC, t.tank_order ASC
```

with

```sql
          SELECT t.id AS tank_id, t.dive_id, d.dive_date_time,
                 t.start_pressure, t.end_pressure, t.o2_percent, t.he_percent,
                 t.trip_cylinder_id, s.name AS site_name
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          LEFT JOIN dive_sites s ON s.id = d.site_id
          WHERE d.trip_id = ?1
            AND t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?1)
          ORDER BY d.dive_date_time ASC, t.tank_order ASC
```

change its `readsFrom` to `{_db.diveTanks, _db.dives, _db.tripCylinders, _db.diveSites}`, and in the `TripCylinderTankUse(...)` it builds add `siteName: r.readNullable<String>('site_name'),` after `gasMix: ...`.

After `deleteByTripId`, add:

```dart

  /// Rewrites board order to match [orderedIds]. Only rows whose position
  /// changed are written and staged, so a no-op reorder syncs nothing.
  Future<void> reorderCylinders(List<String> orderedIds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          final id = orderedIds[i];
          final changed =
              await (_db.update(_db.tripCylinders)..where(
                    (t) => t.id.equals(id) & t.sortOrder.equals(i).not(),
                  ))
                  .write(
                    TripCylindersCompanion(
                      sortOrder: Value(i),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed > 0) {
            await _syncRepository.markRecordPending(
              entityType: 'tripCylinders',
              recordId: id,
              localUpdatedAt: now,
            );
          }
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reorder cylinders',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 9: Run the repository and fold tests to verify they pass**

Run: `flutter test test/features/trips/data/repositories/trip_cylinder_repository_test.dart test/features/trips/domain/services/trip_cylinder_state_fold_test.dart test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: PASS.

- [ ] **Step 10: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/domain/entities/trip_cylinder_state.dart lib/features/trips/domain/services/trip_cylinder_state_fold.dart lib/features/trips/data/repositories/trip_cylinder_repository.dart test/features/trips/domain/services/trip_cylinder_state_fold_test.dart test/features/trips/data/repositories/trip_cylinder_repository_test.dart
git commit -m "feat(trips): deterministic cylinder fold, last item, site names and reorder (#2325)"
```

---

### Task 2: Strings in every locale and the display helpers

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/trips/presentation/helpers/trip_cylinder_display.dart`
- Test: `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`

**Interfaces:**
- Consumes: Task 1's `TripCylinderState.lastEvent` / `lastUse`, `TripCylinderTankUse.siteName`; `GasMix.isAir` and `GasMix.name` from `dive.dart`.
- Produces: the `trips_cylinders_*` localization getters listed in Step 1 (later tasks call them by these exact names and placeholder orders); `String tripCylinderMixLabel(AppLocalizations l10n, GasMix mix)`; `String tripCylinderStatusLabel(AppLocalizations l10n, TripCylinderStatus status)`; `Color tripCylinderStatusColor(ColorScheme scheme, TripCylinderStatus status)`; `typedef TripCylinderCounts = ({int full, int partial, int empty, int unknown})`; `TripCylinderCounts tripCylinderCounts(Iterable<TripCylinderState> states)`; `String? tripCylinderLastItemText(AppLocalizations l10n, UnitFormatter units, TripCylinderState state, {Map<String, String> centerNames = const {}})`.

- [ ] **Step 1: Add the keys to all 11 ARB files**

Save this script as `<scratchpad>/add_trip_cylinder_keys.py` and run it with `python3.14` from the worktree root. It inserts the block right after the `@trips_scrubber_bannerCount` metadata in each file (the non-English files are grouped by feature, so the anchor is a neighbouring key, not alphabetical order), writes the placeholder metadata in every locale as the existing files do, and refuses to run twice.

```python
import io, json, re, sys

PH = {  # key -> [(placeholder, type)] in the order the English text uses them
    "trips_cylinders_summary": [("full", "int"), ("partial", "int"), ("empty", "int")],
    "trips_cylinders_summaryUnfilled": [("count", "int")],
    "trips_cylinders_bottle": [("label", "String")],
    "trips_cylinders_linkedDives": [("count", "int")],
    "trips_cylinders_last_fillAt": [("place", "String"), ("when", "String")],
    "trips_cylinders_last_fill": [("when", "String")],
    "trips_cylinders_last_adjustment": [("when", "String")],
    "trips_cylinders_last_diveAt": [("site", "String"), ("when", "String")],
    "trips_cylinders_last_dive": [("when", "String")],
    "trips_cylinders_deleteConfirmUsed": [("count", "int")],
    "trips_cylinders_fill_pressure": [("unit", "String")],
    "trips_cylinders_adjust_pressure": [("unit", "String")],
    "trips_cylinders_edit_volume": [("unit", "String")],
    "trips_cylinders_edit_workingPressure": [("unit", "String")],
}

KEYS = [
 "title","summary","summaryUnfilled","setUp","setUpHint","status_full","status_partial","status_empty","status_unknown","mixAir",
 "segment_board","segment_ledger","action_add","action_fill","action_fillSeveral","action_adjust","bottle","linkedDives",
 "last_fillAt","last_fill","last_adjustment","last_diveAt","last_dive","boardEmpty","ledgerEmpty","kind_fill","kind_adjustment",
 "deleteConfirmUnused","deleteConfirmUsed","deleteEventConfirm","add_tabRental","add_tabOwned","add_count","add_preset","add_prefix",
 "add_prefixDefault","add_noOwned","add_errorCount","fill_titleEdit","fill_when","fill_where","fill_whereNone","fill_pressure",
 "fill_o2","fill_he","fill_analyzedO2","fill_analyzedHe","fill_bottle","fill_cost","fill_currency","fill_package","fill_slots",
 "fill_errorMix","fill_errorNoSlot","note","adjust_titleEdit","adjust_pressure","adjust_markEmpty","edit_title","edit_label",
 "edit_volume","edit_workingPressure","edit_presetCustom",
]

T = {
"en": ["Cylinders","Full {full} · Partial {partial} · Empty {empty}","Not filled yet {count}","Set up cylinders","Track the cylinders you hold on this trip: fills, mixes and what is left in each.","Full","Partial","Empty","Not filled yet","Air",
 "Board","Ledger","Add cylinders","Fill","Fill several","Adjust","Bottle {label}","{count, plural, one{{count} dive} other{{count} dives}}",
 "Filled at {place}, {when}","Filled {when}","Adjusted {when}","Dived at {site}, {when}","Dived {when}","No cylinders on this trip yet","No fills or adjustments yet","Fill","Adjustment",
 "Delete this cylinder and its fills?","{count, plural, one{Delete this cylinder and its fills? {count} dive used it. That dive keeps its tank; only the link is removed.} other{Delete this cylinder and its fills? {count} dives used it. Those dives keep their tanks; only the link is removed.}}","Delete this entry?","Rental","From my equipment","How many","Cylinder type","Label prefix",
 "Truck","No cylinders in your equipment are left to add.","Enter a number from 1 to 20.","Edit fill","When","Fill station","Not set","Fill pressure ({unit})",
 "O2 ordered (%)","He ordered (%)","O2 analyzed (%)","He analyzed (%)","Bottle number","Cost","Currency","Covered by a package","Cylinders to fill",
 "Oxygen must be 1 to 100 percent, helium 0 to 99, and together at most 100.","Pick at least one cylinder.","Note","Edit adjustment","Pressure ({unit})","Mark empty","Edit cylinder","Label",
 "Size ({unit})","Working pressure ({unit})","Custom"],
"de": ["Flaschen","Voll {full} · Teilweise {partial} · Leer {empty}","Noch nicht gefüllt {count}","Flaschen einrichten","Verfolge die Flaschen, die du auf dieser Reise hast: Füllungen, Gemische und was in jeder übrig ist.","Voll","Teilweise","Leer","Noch nicht gefüllt","Luft",
 "Übersicht","Verlauf","Flaschen hinzufügen","Füllen","Mehrere füllen","Anpassen","Flasche {label}","{count, plural, one{{count} Tauchgang} other{{count} Tauchgänge}}",
 "Gefüllt bei {place}, {when}","Gefüllt {when}","Angepasst {when}","Getaucht bei {site}, {when}","Getaucht {when}","Noch keine Flaschen auf dieser Reise","Noch keine Füllungen oder Anpassungen","Füllung","Anpassung",
 "Diese Flasche und ihre Füllungen löschen?","{count, plural, one{Diese Flasche und ihre Füllungen löschen? {count} Tauchgang hat sie benutzt. Er behält seine Flasche; nur die Verknüpfung wird entfernt.} other{Diese Flasche und ihre Füllungen löschen? {count} Tauchgänge haben sie benutzt. Sie behalten ihre Flaschen; nur die Verknüpfung wird entfernt.}}","Diesen Eintrag löschen?","Leihflaschen","Aus meiner Ausrüstung","Anzahl","Flaschentyp","Namenspräfix",
 "Pick-up","In deiner Ausrüstung sind keine Flaschen mehr zum Hinzufügen.","Gib eine Zahl von 1 bis 20 ein.","Füllung bearbeiten","Wann","Füllstation","Nicht festgelegt","Fülldruck ({unit})",
 "O2 bestellt (%)","He bestellt (%)","O2 analysiert (%)","He analysiert (%)","Flaschennummer","Kosten","Währung","Im Paket enthalten","Zu füllende Flaschen",
 "Sauerstoff muss 1 bis 100 Prozent sein, Helium 0 bis 99, zusammen höchstens 100.","Wähle mindestens eine Flasche.","Notiz","Anpassung bearbeiten","Druck ({unit})","Als leer markieren","Flasche bearbeiten","Bezeichnung",
 "Größe ({unit})","Betriebsdruck ({unit})","Benutzerdefiniert"],
"es": ["Botellas","Llenas {full} · Parciales {partial} · Vacías {empty}","Sin llenar {count}","Configurar botellas","Controla las botellas que tienes en este viaje: cargas, mezclas y lo que queda en cada una.","Llena","Parcial","Vacía","Sin llenar","Aire",
 "Tablero","Registro","Añadir botellas","Cargar","Cargar varias","Ajustar","Botella {label}","{count, plural, one{{count} inmersión} other{{count} inmersiones}}",
 "Cargada en {place}, {when}","Cargada {when}","Ajustada {when}","Buceo en {site}, {when}","Buceo {when}","Aún no hay botellas en este viaje","Aún no hay cargas ni ajustes","Carga","Ajuste",
 "¿Eliminar esta botella y sus cargas?","{count, plural, one{¿Eliminar esta botella y sus cargas? {count} inmersión la usó. Esa inmersión conserva su botella; solo se quita el vínculo.} other{¿Eliminar esta botella y sus cargas? {count} inmersiones la usaron. Esas inmersiones conservan sus botellas; solo se quita el vínculo.}}","¿Eliminar esta entrada?","Alquiler","De mi equipo","Cuántas","Tipo de botella","Prefijo de la etiqueta",
 "Camioneta","No quedan botellas de tu equipo por añadir.","Introduce un número del 1 al 20.","Editar carga","Cuándo","Estación de carga","Sin definir","Presión de carga ({unit})",
 "O2 pedido (%)","He pedido (%)","O2 analizado (%)","He analizado (%)","Número de botella","Coste","Moneda","Incluida en un paquete","Botellas a cargar",
 "El oxígeno debe estar entre 1 y 100 por ciento, el helio entre 0 y 99, y juntos como máximo 100.","Elige al menos una botella.","Nota","Editar ajuste","Presión ({unit})","Marcar como vacía","Editar botella","Etiqueta",
 "Tamaño ({unit})","Presión de trabajo ({unit})","Personalizada"],
"fr": ["Blocs","Pleins {full} · Entamés {partial} · Vides {empty}","Pas encore gonflés {count}","Configurer les blocs","Suivez les blocs que vous avez sur ce voyage : gonflages, mélanges et ce qu'il reste dans chacun.","Plein","Entamé","Vide","Pas encore gonflé","Air",
 "Tableau","Journal","Ajouter des blocs","Gonfler","Gonfler plusieurs","Ajuster","Bloc {label}","{count, plural, one{{count} plongée} other{{count} plongées}}",
 "Gonflé chez {place}, {when}","Gonflé {when}","Ajusté {when}","Plongée à {site}, {when}","Plongée {when}","Aucun bloc sur ce voyage pour l'instant","Aucun gonflage ni ajustement pour l'instant","Gonflage","Ajustement",
 "Supprimer ce bloc et ses gonflages ?","{count, plural, one{Supprimer ce bloc et ses gonflages ? {count} plongée l'a utilisé. Elle garde son bloc ; seul le lien est retiré.} other{Supprimer ce bloc et ses gonflages ? {count} plongées l'ont utilisé. Elles gardent leurs blocs ; seul le lien est retiré.}}","Supprimer cette entrée ?","Location","Mon équipement","Combien","Type de bloc","Préfixe du nom",
 "Pick-up","Il ne reste aucun bloc de votre équipement à ajouter.","Saisissez un nombre de 1 à 20.","Modifier le gonflage","Quand","Station de gonflage","Non défini","Pression de gonflage ({unit})",
 "O2 demandé (%)","He demandé (%)","O2 analysé (%)","He analysé (%)","Numéro du bloc","Coût","Devise","Inclus dans un forfait","Blocs à gonfler",
 "L'oxygène doit être entre 1 et 100 pour cent, l'hélium entre 0 et 99, et les deux ensemble au plus 100.","Choisissez au moins un bloc.","Note","Modifier l'ajustement","Pression ({unit})","Marquer vide","Modifier le bloc","Nom",
 "Taille ({unit})","Pression de service ({unit})","Personnalisé"],
"it": ["Bombole","Piene {full} · Parziali {partial} · Vuote {empty}","Non ancora caricate {count}","Configura le bombole","Tieni traccia delle bombole che hai in questo viaggio: ricariche, miscele e quanto resta in ciascuna.","Piena","Parziale","Vuota","Non ancora caricata","Aria",
 "Quadro","Registro","Aggiungi bombole","Ricarica","Ricarica più bombole","Correggi","Bombola {label}","{count, plural, one{{count} immersione} other{{count} immersioni}}",
 "Ricaricata da {place}, {when}","Ricaricata {when}","Corretta {when}","Immersione a {site}, {when}","Immersione {when}","Ancora nessuna bombola in questo viaggio","Ancora nessuna ricarica o correzione","Ricarica","Correzione",
 "Eliminare questa bombola e le sue ricariche?","{count, plural, one{Eliminare questa bombola e le sue ricariche? {count} immersione l'ha usata. L'immersione conserva la sua bombola; viene rimosso solo il collegamento.} other{Eliminare questa bombola e le sue ricariche? {count} immersioni l'hanno usata. Le immersioni conservano le loro bombole; viene rimosso solo il collegamento.}}","Eliminare questa voce?","Noleggio","Dalla mia attrezzatura","Quante","Tipo di bombola","Prefisso del nome",
 "Pick-up","Non restano bombole della tua attrezzatura da aggiungere.","Inserisci un numero da 1 a 20.","Modifica ricarica","Quando","Stazione di ricarica","Non impostata","Pressione di ricarica ({unit})",
 "O2 richiesto (%)","He richiesto (%)","O2 analizzato (%)","He analizzato (%)","Numero della bombola","Costo","Valuta","Incluso in un pacchetto","Bombole da ricaricare",
 "L'ossigeno deve essere tra 1 e 100 per cento, l'elio tra 0 e 99, e insieme al massimo 100.","Scegli almeno una bombola.","Nota","Modifica correzione","Pressione ({unit})","Segna come vuota","Modifica bombola","Nome",
 "Dimensione ({unit})","Pressione di esercizio ({unit})","Personalizzata"],
"nl": ["Flessen","Vol {full} · Deels {partial} · Leeg {empty}","Nog niet gevuld {count}","Flessen instellen","Houd de flessen bij die je op deze reis hebt: vullingen, mengsels en wat er in elke fles over is.","Vol","Deels vol","Leeg","Nog niet gevuld","Lucht",
 "Overzicht","Logboek","Flessen toevoegen","Vullen","Meerdere vullen","Bijwerken","Fles {label}","{count, plural, one{{count} duik} other{{count} duiken}}",
 "Gevuld bij {place}, {when}","Gevuld {when}","Bijgewerkt {when}","Gedoken bij {site}, {when}","Gedoken {when}","Nog geen flessen op deze reis","Nog geen vullingen of correcties","Vulling","Correctie",
 "Deze fles en haar vullingen verwijderen?","{count, plural, one{Deze fles en haar vullingen verwijderen? {count} duik gebruikte haar. Die duik houdt zijn fles; alleen de koppeling verdwijnt.} other{Deze fles en haar vullingen verwijderen? {count} duiken gebruikten haar. Die duiken houden hun flessen; alleen de koppeling verdwijnt.}}","Dit item verwijderen?","Huur","Uit mijn uitrusting","Aantal","Flestype","Voorvoegsel voor de naam",
 "Pick-up","Er zijn geen flessen uit je uitrusting meer om toe te voegen.","Voer een getal van 1 tot 20 in.","Vulling bewerken","Wanneer","Vulstation","Niet ingesteld","Vuldruk ({unit})",
 "O2 besteld (%)","He besteld (%)","O2 geanalyseerd (%)","He geanalyseerd (%)","Flesnummer","Kosten","Valuta","Inbegrepen in een pakket","Te vullen flessen",
 "Zuurstof moet tussen 1 en 100 procent liggen, helium tussen 0 en 99, en samen hoogstens 100.","Kies minstens één fles.","Notitie","Correctie bewerken","Druk ({unit})","Als leeg markeren","Fles bewerken","Naam",
 "Grootte ({unit})","Werkdruk ({unit})","Aangepast"],
"pt": ["Cilindros","Cheios {full} · Parciais {partial} · Vazios {empty}","Ainda não enchidos {count}","Configurar cilindros","Acompanhe os cilindros que tem nesta viagem: enchimentos, misturas e o que resta em cada um.","Cheio","Parcial","Vazio","Ainda não enchido","Ar",
 "Quadro","Registo","Adicionar cilindros","Encher","Encher vários","Ajustar","Cilindro {label}","{count, plural, one{{count} mergulho} other{{count} mergulhos}}",
 "Enchido em {place}, {when}","Enchido {when}","Ajustado {when}","Mergulho em {site}, {when}","Mergulho {when}","Ainda não há cilindros nesta viagem","Ainda não há enchimentos nem ajustes","Enchimento","Ajuste",
 "Eliminar este cilindro e os seus enchimentos?","{count, plural, one{Eliminar este cilindro e os seus enchimentos? {count} mergulho usou-o. Esse mergulho mantém o seu cilindro; só a ligação é removida.} other{Eliminar este cilindro e os seus enchimentos? {count} mergulhos usaram-no. Esses mergulhos mantêm os seus cilindros; só a ligação é removida.}}","Eliminar esta entrada?","Aluguer","Do meu equipamento","Quantos","Tipo de cilindro","Prefixo do nome",
 "Carrinha","Não restam cilindros do seu equipamento para adicionar.","Introduza um número de 1 a 20.","Editar enchimento","Quando","Posto de enchimento","Não definido","Pressão de enchimento ({unit})",
 "O2 pedido (%)","He pedido (%)","O2 analisado (%)","He analisado (%)","Número do cilindro","Custo","Moeda","Incluído num pacote","Cilindros a encher",
 "O oxigénio tem de estar entre 1 e 100 por cento, o hélio entre 0 e 99, e juntos no máximo 100.","Escolha pelo menos um cilindro.","Nota","Editar ajuste","Pressão ({unit})","Marcar como vazio","Editar cilindro","Nome",
 "Tamanho ({unit})","Pressão de serviço ({unit})","Personalizado"],
"hu": ["Palackok","Tele {full} · Részben {partial} · Üres {empty}","Még nincs töltve {count}","Palackok beállítása","Kövesd az úton nálad lévő palackokat: töltések, keverékek és hogy mennyi maradt mindegyikben.","Tele","Részben","Üres","Még nincs töltve","Levegő",
 "Áttekintés","Napló","Palackok hozzáadása","Töltés","Több töltése","Módosítás","Palack {label}","{count, plural, one{{count} merülés} other{{count} merülés}}",
 "Töltve: {place}, {when}","Töltve: {when}","Módosítva: {when}","Merülés: {site}, {when}","Merülés: {when}","Ezen az úton még nincsenek palackok","Még nincs töltés vagy módosítás","Töltés","Módosítás",
 "Törlöd ezt a palackot és a töltéseit?","{count, plural, one{Törlöd ezt a palackot és a töltéseit? {count} merülés használta. A merülés megtartja a palackját, csak a kapcsolat törlődik.} other{Törlöd ezt a palackot és a töltéseit? {count} merülés használta. A merülések megtartják a palackjukat, csak a kapcsolat törlődik.}}","Törlöd ezt a bejegyzést?","Bérelt","A felszerelésemből","Darabszám","Palacktípus","Név előtagja",
 "Pickup","A felszerelésedben nincs több hozzáadható palack.","Adj meg egy számot 1 és 20 között.","Töltés szerkesztése","Mikor","Töltőállomás","Nincs megadva","Töltési nyomás ({unit})",
 "Kért O2 (%)","Kért He (%)","Mért O2 (%)","Mért He (%)","Palackszám","Költség","Pénznem","A csomag része","Töltendő palackok",
 "Az oxigén 1 és 100 százalék között, a hélium 0 és 99 között lehet, együtt legfeljebb 100.","Válassz legalább egy palackot.","Megjegyzés","Módosítás szerkesztése","Nyomás ({unit})","Megjelölés üresként","Palack szerkesztése","Név",
 "Méret ({unit})","Üzemi nyomás ({unit})","Egyéni"],
"zh": ["气瓶","满瓶 {full} · 部分 {partial} · 空瓶 {empty}","尚未充气 {count}","设置气瓶","记录本次行程中你持有的气瓶：充气、混合气以及每瓶剩余多少。","满","部分","空","尚未充气","空气",
 "看板","记录","添加气瓶","充气","批量充气","调整","瓶号 {label}","{count, plural, other{{count} 次潜水}}",
 "于 {place} 充气，{when}","已充气，{when}","已调整，{when}","在 {site} 潜水，{when}","已潜水，{when}","本次行程还没有气瓶","还没有充气或调整记录","充气","调整",
 "删除这个气瓶及其充气记录？","{count, plural, other{删除这个气瓶及其充气记录？有 {count} 次潜水使用过它。这些潜水保留各自的气瓶，只移除关联。}}","删除这条记录？","租用","我的装备","数量","气瓶类型","名称前缀",
 "车","你的装备中没有可添加的气瓶了。","请输入 1 到 20 之间的数字。","编辑充气","时间","充气站","未设置","充气压力（{unit}）",
 "订购 O2（%）","订购 He（%）","分析 O2（%）","分析 He（%）","瓶号","费用","货币","包含在套餐中","要充气的气瓶",
 "氧气须为 1 到 100%，氦气为 0 到 99%，两者合计不超过 100。","请至少选择一个气瓶。","备注","编辑调整","压力（{unit}）","标记为空","编辑气瓶","名称",
 "尺寸（{unit}）","工作压力（{unit}）","自定义"],
"ar": ["الأسطوانات","ممتلئة {full} · جزئية {partial} · فارغة {empty}","لم تُعبّأ بعد {count}","إعداد الأسطوانات","تتبّع الأسطوانات التي معك في هذه الرحلة: التعبئات والخلطات وما تبقّى في كل منها.","ممتلئة","جزئية","فارغة","لم تُعبّأ بعد","هواء",
 "اللوحة","السجل","إضافة أسطوانات","تعبئة","تعبئة عدة أسطوانات","تعديل","الأسطوانة {label}","{count, plural, one{{count} غطسة} other{{count} غطسات}}",
 "عُبّئت في {place}، {when}","عُبّئت {when}","عُدّلت {when}","غطسة في {site}، {when}","غطسة {when}","لا توجد أسطوانات في هذه الرحلة بعد","لا توجد تعبئات أو تعديلات بعد","تعبئة","تعديل",
 "حذف هذه الأسطوانة وتعبئاتها؟","{count, plural, one{حذف هذه الأسطوانة وتعبئاتها؟ استخدمتها {count} غطسة. تحتفظ الغطسة بأسطوانتها ويُزال الربط فقط.} other{حذف هذه الأسطوانة وتعبئاتها؟ استخدمتها {count} غطسات. تحتفظ الغطسات بأسطواناتها ويُزال الربط فقط.}}","حذف هذا الإدخال؟","مستأجرة","من معداتي","العدد","نوع الأسطوانة","بادئة الاسم",
 "الشاحنة","لم تعد هناك أسطوانات في معداتك لإضافتها.","أدخل رقمًا من 1 إلى 20.","تعديل التعبئة","متى","محطة التعبئة","غير محددة","ضغط التعبئة ({unit})",
 "O2 المطلوب (%)","He المطلوب (%)","O2 المقاس (%)","He المقاس (%)","رقم الأسطوانة","التكلفة","العملة","ضمن باقة","الأسطوانات المراد تعبئتها",
 "يجب أن يكون الأكسجين بين 1 و100 بالمئة، والهيليوم بين 0 و99، ومجموعهما 100 على الأكثر.","اختر أسطوانة واحدة على الأقل.","ملاحظة","تعديل التصحيح","الضغط ({unit})","تعليم كفارغة","تعديل الأسطوانة","الاسم",
 "الحجم ({unit})","ضغط العمل ({unit})","مخصص"],
"he": ["מכלים","מלאים {full} · חלקיים {partial} · ריקים {empty}","טרם מולאו {count}","הגדרת מכלים","עקבו אחר המכלים שיש לכם בטיול הזה: מילויים, תערובות וכמה נשאר בכל אחד.","מלא","חלקי","ריק","טרם מולא","אוויר",
 "לוח","יומן","הוספת מכלים","מילוי","מילוי כמה מכלים","תיקון","מכל {label}","{count, plural, one{{count} צלילה} other{{count} צלילות}}",
 "מולא אצל {place}, {when}","מולא {when}","תוקן {when}","צלילה באתר {site}, {when}","צלילה {when}","עדיין אין מכלים בטיול הזה","עדיין אין מילויים או תיקונים","מילוי","תיקון",
 "למחוק את המכל הזה ואת המילויים שלו?","{count, plural, one{למחוק את המכל הזה ואת המילויים שלו? {count} צלילה השתמשה בו. הצלילה שומרת את המכל שלה; רק הקישור מוסר.} other{למחוק את המכל הזה ואת המילויים שלו? {count} צלילות השתמשו בו. הצלילות שומרות את המכלים שלהן; רק הקישור מוסר.}}","למחוק את הרשומה הזו?","שכור","מהציוד שלי","כמה","סוג מכל","קידומת לשם",
 "טנדר","לא נותרו מכלים בציוד שלך להוספה.","הזינו מספר בין 1 ל-20.","עריכת מילוי","מתי","תחנת מילוי","לא הוגדר","לחץ מילוי ({unit})",
 "O2 שהוזמן (%)","He שהוזמן (%)","O2 שנמדד (%)","He שנמדד (%)","מספר מכל","עלות","מטבע","כלול בחבילה","מכלים למילוי",
 "החמצן חייב להיות בין 1 ל-100 אחוז, ההליום בין 0 ל-99, ויחד לכל היותר 100.","בחרו לפחות מכל אחד.","הערה","עריכת תיקון","לחץ ({unit})","סימון כריק","עריכת מכל","שם",
 "גודל ({unit})","לחץ עבודה ({unit})","מותאם אישית"],
}

def entry(key, value):
    lines = [f'  "{key}": {json.dumps(value, ensure_ascii=False)},\n']
    if key in PH:
        body = {"placeholders": {n: {"type": t} for n, t in PH[key]}}
        meta = json.dumps(body, ensure_ascii=False, indent=2).replace("\n", "\n  ")
        lines.append(f'  "@{key}": {meta},\n')
    return "".join(lines)

for loc, values in T.items():
    assert len(values) == len(KEYS), (loc, len(values))
    path = f"lib/l10n/arb/app_{loc}.arb"
    s = io.open(path, encoding="utf-8").read()
    if '"trips_cylinders_title"' in s:
        sys.exit(f"{loc}: keys already present")
    start = s.index('"@trips_scrubber_bannerCount": {')
    end = s.index("\n  },\n", start) + len("\n  },\n")
    block = "".join(entry(f"trips_cylinders_{k}", v) for k, v in zip(KEYS, values))
    io.open(path, "w", encoding="utf-8").write(s[:end] + block + s[end:])
    print(loc, "ok")
```

- [ ] **Step 2: Regenerate and check the ARB guards**

Run:
```bash
flutter gen-l10n
flutter test test/l10n
```
Expected: `gen-l10n` exits 0 and the whole `test/l10n` folder passes (parity, placeholders, duplicate keys, diacritics, and the two plural guards).

- [ ] **Step 3: Write the failing display helper tests**

Create `test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());
  final at = DateTime.utc(2026, 3, 9, 8, 15);
  final slot = TripCylinder(
    id: 'c1',
    tripId: 't1',
    label: 'Truck 1',
    createdAt: at,
    updatedAt: at,
  );

  TripCylinderState state({
    TripCylinderStatus status = TripCylinderStatus.full,
    TripCylinderEvent? lastEvent,
    TripCylinderTankUse? lastUse,
  }) => TripCylinderState(
    cylinder: slot,
    bottleLabel: 'Truck 1',
    status: status,
    lastEventAt: lastEvent?.occurredAt ?? lastUse?.entryTime,
    lastEvent: lastEvent,
    lastUse: lastUse,
  );

  TripCylinderEvent event(TripCylinderEventKind kind, {String? center}) =>
      TripCylinderEvent(
        id: 'e1',
        tripCylinderId: 'c1',
        kind: kind,
        occurredAt: at,
        diveCenterId: center,
        createdAt: at,
        updatedAt: at,
      );

  final when = units.formatDateTime(at, l10n: l10n);

  test('air reads as the localized word, other mixes by their notation', () {
    expect(tripCylinderMixLabel(l10n, const GasMix()), 'Air');
    expect(tripCylinderMixLabel(l10n, const GasMix(o2: 32)), 'EAN32');
    expect(tripCylinderMixLabel(l10n, const GasMix(o2: 21, he: 35)), 'Tx 21/35');
  });

  test('each status has a label and a distinct colour', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final labels = {
      for (final s in TripCylinderStatus.values) tripCylinderStatusLabel(l10n, s),
    };
    final colours = {
      for (final s in TripCylinderStatus.values)
        tripCylinderStatusColor(scheme, s),
    };
    expect(labels, {'Full', 'Partial', 'Empty', 'Not filled yet'});
    expect(colours, hasLength(4));
  });

  test('counts every status', () {
    final counts = tripCylinderCounts([
      state(),
      state(),
      state(status: TripCylinderStatus.partial),
      state(status: TripCylinderStatus.unknown),
    ]);
    expect(counts, (full: 2, partial: 1, empty: 0, unknown: 1));
  });

  group('last item sentence', () {
    test('a fill names its station when it has one', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.fill, center: 'dc1')),
          centerNames: const {'dc1': 'Dive Friends'},
        ),
        'Filled at Dive Friends, $when',
      );
    });

    test('a fill with no known station says when only', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.fill, center: 'gone')),
        ),
        'Filled $when',
      );
    });

    test('an adjustment says when', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.adjustment)),
        ),
        'Adjusted $when',
      );
    });

    test('a dive names its site when it has one', () {
      final use = TripCylinderTankUse(
        tankId: 'k1',
        diveId: 'd1',
        entryTime: at,
        siteName: 'Salt Pier',
      );
      expect(
        tripCylinderLastItemText(l10n, units, state(lastUse: use)),
        'Dived at Salt Pier, $when',
      );
      final bare = TripCylinderTankUse(tankId: 'k1', diveId: 'd1', entryTime: at);
      expect(
        tripCylinderLastItemText(l10n, units, state(lastUse: bare)),
        'Dived $when',
      );
    });

    test('an untouched slot has no sentence', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(status: TripCylinderStatus.unknown),
        ),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: FAIL to compile: `trip_cylinder_display.dart` does not exist.

- [ ] **Step 5: Write the helpers**

Create `lib/features/trips/presentation/helpers/trip_cylinder_display.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A mix as the board shows it. Air is a word and is translated; nitrox and
/// trimix keep their international notation (EAN32, Tx 21/35).
String tripCylinderMixLabel(AppLocalizations l10n, GasMix mix) =>
    mix.isAir ? l10n.trips_cylinders_mixAir : mix.name;

String tripCylinderStatusLabel(
  AppLocalizations l10n,
  TripCylinderStatus status,
) => switch (status) {
  TripCylinderStatus.full => l10n.trips_cylinders_status_full,
  TripCylinderStatus.partial => l10n.trips_cylinders_status_partial,
  TripCylinderStatus.empty => l10n.trips_cylinders_status_empty,
  TripCylinderStatus.unknown => l10n.trips_cylinders_status_unknown,
};

/// The status dot's colour. Always shown beside the status word, never
/// alone, so the colour is a cue and not the only signal.
Color tripCylinderStatusColor(ColorScheme scheme, TripCylinderStatus status) =>
    switch (status) {
      TripCylinderStatus.full => scheme.primary,
      TripCylinderStatus.partial => scheme.tertiary,
      TripCylinderStatus.empty => scheme.error,
      TripCylinderStatus.unknown => scheme.outline,
    };

typedef TripCylinderCounts = ({int full, int partial, int empty, int unknown});

TripCylinderCounts tripCylinderCounts(Iterable<TripCylinderState> states) {
  var full = 0, partial = 0, empty = 0, unknown = 0;
  for (final s in states) {
    switch (s.status) {
      case TripCylinderStatus.full:
        full++;
      case TripCylinderStatus.partial:
        partial++;
      case TripCylinderStatus.empty:
        empty++;
      case TripCylinderStatus.unknown:
        unknown++;
    }
  }
  return (full: full, partial: partial, empty: empty, unknown: unknown);
}

/// The slot's last timeline item in words: where it was filled, when it
/// was adjusted, or where it was dived. [centerNames] maps dive center ids
/// to names; a center that is gone or unknown reads as no station. Null for
/// a slot with no history.
String? tripCylinderLastItemText(
  AppLocalizations l10n,
  UnitFormatter units,
  TripCylinderState state, {
  Map<String, String> centerNames = const {},
}) {
  final at = state.lastEventAt;
  if (at == null) return null;
  final when = units.formatDateTime(at, l10n: l10n);
  final use = state.lastUse;
  if (use != null) {
    final site = use.siteName;
    return site == null || site.isEmpty
        ? l10n.trips_cylinders_last_dive(when)
        : l10n.trips_cylinders_last_diveAt(site, when);
  }
  final event = state.lastEvent;
  if (event == null) return null;
  switch (event.kind) {
    case TripCylinderEventKind.fill:
      final place = centerNames[event.diveCenterId];
      return place == null
          ? l10n.trips_cylinders_last_fill(when)
          : l10n.trips_cylinders_last_fillAt(place, when);
    case TripCylinderEventKind.adjustment:
      return l10n.trips_cylinders_last_adjustment(when);
  }
}
```

- [ ] **Step 6: Run the helper tests to verify they pass**

Run: `flutter test test/features/trips/presentation/helpers/trip_cylinder_display_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/helpers test/features/trips/presentation/helpers
git add lib/l10n/arb lib/features/trips/presentation/helpers/trip_cylinder_display.dart test/features/trips/presentation/helpers/trip_cylinder_display_test.dart
git commit -m "feat(trips): trip cylinder strings in every locale and display helpers (#2325)"
```

---

### Task 3: Cylinder size and working pressure in the diver's units

**Files:**
- Create: `lib/features/trips/presentation/helpers/trip_cylinder_specs_input.dart`
- Test: `test/features/trips/presentation/helpers/trip_cylinder_specs_input_test.dart`

**Interfaces:**
- Consumes: `UnitFormatter` (`settings.volumeUnit`, `convertPressure`, `pressureToBar`), `VolumeUnit` from `lib/core/constants/units.dart`, `parseUserDecimal` and `formatRoundedForInput` from `lib/core/utils/number_input.dart`, `TankPresetEntity`.
- Produces: `String cylinderWorkingPressureForInput(UnitFormatter units, double? bar)`; `String cylinderSizeForInput(UnitFormatter units, {double? liters, double? workingPressureBar, double? ratedCuft})`; `({double? volumeLiters, double? workingPressureBar, bool invalid}) cylinderSpecsFromInput(UnitFormatter units, {required String sizeText, required String workingPressureText, TankPresetEntity? preset})`.

The rule is the tank editor's (`tank_editor.dart` `_metricSpecs`): metric sizes are liters of water; an imperial size is rated gas capacity in cuft, which converts back through the working pressure, except that a chosen preset's water volume is authoritative because a rated cuft figure cannot be reversed exactly.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/helpers/trip_cylinder_specs_input_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_specs_input.dart';

void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
    ),
  );
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);

  group('for input', () {
    test('metric shows liters and bar', () {
      expect(
        cylinderSizeForInput(metric, liters: 11.1, workingPressureBar: 207),
        '11.1',
      );
      expect(cylinderWorkingPressureForInput(metric, 207), '207');
    });

    test('imperial shows rated capacity and psi', () {
      // 11.1 L at 207 bar is 81.1 cuft by the ideal gas rule.
      expect(
        cylinderSizeForInput(imperial, liters: 11.1, workingPressureBar: 207),
        '81',
      );
      expect(
        cylinderSizeForInput(
          imperial,
          liters: 11.1,
          workingPressureBar: 207,
          ratedCuft: 77,
        ),
        '77',
      );
      expect(
        cylinderWorkingPressureForInput(imperial, 207),
        imperial.convertPressure(207).round().toString(),
      );
    });

    test('nothing known shows empty fields', () {
      expect(cylinderSizeForInput(metric), '');
      expect(cylinderSizeForInput(imperial, liters: 11.1), '');
      expect(cylinderWorkingPressureForInput(metric, null), '');
    });
  });

  group('from input', () {
    test('metric reads liters and bar', () {
      final r = cylinderSpecsFromInput(
        metric,
        sizeText: '11.1',
        workingPressureText: '207',
      );
      expect(r.invalid, isFalse);
      expect(r.volumeLiters, 11.1);
      expect(r.workingPressureBar, 207);
    });

    test('imperial converts capacity back through the working pressure', () {
      final r = cylinderSpecsFromInput(
        imperial,
        sizeText: '80',
        workingPressureText: '3000',
      );
      final bar = imperial.pressureToBar(3000);
      expect(r.workingPressureBar, closeTo(bar, 1e-9));
      expect(r.volumeLiters, closeTo(80 * 28.3168 / bar, 1e-9));
    });

    test('imperial with a preset takes the preset water volume', () {
      final r = cylinderSpecsFromInput(
        imperial,
        sizeText: '77',
        workingPressureText: '3000',
        preset: al80,
      );
      expect(r.volumeLiters, al80.volumeLiters);
    });

    test('blank fields are unknown, not invalid', () {
      final r = cylinderSpecsFromInput(
        metric,
        sizeText: ' ',
        workingPressureText: '',
      );
      expect(r.invalid, isFalse);
      expect(r.volumeLiters, isNull);
      expect(r.workingPressureBar, isNull);
    });

    test('unreadable or non-positive numbers are invalid', () {
      expect(
        cylinderSpecsFromInput(
          metric,
          sizeText: 'abc',
          workingPressureText: '207',
        ).invalid,
        isTrue,
      );
      expect(
        cylinderSpecsFromInput(
          metric,
          sizeText: '11.1',
          workingPressureText: '0',
        ).invalid,
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/helpers/trip_cylinder_specs_input_test.dart`
Expected: FAIL to compile: the helper file does not exist. If `TankPresets.byName` or `TankPresetEntity.fromBuiltIn` has a different name, check `lib/core/constants/tank_presets.dart:195` and `tank_preset_entity.dart` and use the real one; ledger it as a ruling.

- [ ] **Step 3: Write the helper**

Create `lib/features/trips/presentation/helpers/trip_cylinder_specs_input.dart`:

```dart
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Liters of gas in one cubic foot, the ideal gas figure the tank editor
/// uses to turn a rated capacity back into water volume.
const double _litersPerCuft = 28.3168;

bool _imperialSize(UnitFormatter units) =>
    units.settings.volumeUnit == VolumeUnit.cubicFeet;

/// A working pressure for a text field in the diver's pressure unit.
String cylinderWorkingPressureForInput(UnitFormatter units, double? bar) =>
    bar == null ? '' : formatRoundedForInput(units.convertPressure(bar), 0);

/// A cylinder size for a text field: liters of water in metric, rated gas
/// capacity in cuft in imperial ([ratedCuft] when the preset names one,
/// else the ideal gas figure from the working pressure). Empty when the
/// size cannot be stated in the diver's unit.
String cylinderSizeForInput(
  UnitFormatter units, {
  double? liters,
  double? workingPressureBar,
  double? ratedCuft,
}) {
  if (liters == null) return '';
  if (!_imperialSize(units)) return formatRoundedForInput(liters, 1);
  if (ratedCuft != null) return formatRoundedForInput(ratedCuft, 0);
  if (workingPressureBar == null || workingPressureBar <= 0) return '';
  return formatRoundedForInput(
    liters * workingPressureBar / _litersPerCuft,
    0,
  );
}

/// Reads a size and a working pressure typed in the diver's units back to
/// liters and bar. Blank fields are unknown; unreadable or non-positive
/// numbers set [invalid]. In imperial a chosen [preset] supplies the water
/// volume, because a rated cuft figure cannot be reversed exactly.
({double? volumeLiters, double? workingPressureBar, bool invalid})
cylinderSpecsFromInput(
  UnitFormatter units, {
  required String sizeText,
  required String workingPressureText,
  TankPresetEntity? preset,
}) {
  final sizeTrim = sizeText.trim();
  final wpTrim = workingPressureText.trim();
  final size = sizeTrim.isEmpty ? null : parseUserDecimal(sizeTrim);
  final wpDisplay = wpTrim.isEmpty ? null : parseUserDecimal(wpTrim);
  final badSize = sizeTrim.isNotEmpty && (size == null || size <= 0);
  final badWp = wpTrim.isNotEmpty && (wpDisplay == null || wpDisplay <= 0);
  if (badSize || badWp) {
    return (volumeLiters: null, workingPressureBar: null, invalid: true);
  }
  final wpBar = wpDisplay == null ? null : units.pressureToBar(wpDisplay);
  double? liters;
  if (size != null) {
    if (!_imperialSize(units)) {
      liters = size;
    } else if (preset != null) {
      liters = preset.volumeLiters;
    } else if (wpBar != null) {
      liters = size * _litersPerCuft / wpBar;
    }
  }
  return (volumeLiters: liters, workingPressureBar: wpBar, invalid: false);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/helpers/trip_cylinder_specs_input_test.dart`
Expected: PASS, 8 tests. If `formatRoundedForInput(207.0, 0)` prints `207.0` instead of `207`, read `number_input.dart:148` and use the helper that trims, ledgering the ruling.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/helpers test/features/trips/presentation/helpers
git add lib/features/trips/presentation/helpers/trip_cylinder_specs_input.dart test/features/trips/presentation/helpers/trip_cylinder_specs_input_test.dart
git commit -m "feat(trips): cylinder size and pressure in the diver's units (#2325)"
```

---

### Task 4: The slot edit sheet

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart`
- Test: `test/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet_test.dart`

**Interfaces:**
- Consumes: Task 3 helpers; `tripCylinderRepositoryProvider` (PR 1); `tankPresetsProvider`; Task 2 strings `trips_cylinders_edit_*`, `trips_cylinders_add_preset`, `trips_cylinders_note`.
- Produces: `Future<void> showTripCylinderEditSheet(BuildContext context, {required TripCylinder cylinder})`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late TripCylinder slot;
  final presets = [
    TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!),
    TankPresetEntity.fromBuiltIn(TankPresets.byName('steel12')!),
  ];

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    );
    slot = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: trip.id,
        label: 'Truck 1',
        volume: 11.1,
        workingPressure: 207,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
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
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTripCylinderEditSheet(context, cylinder: slot),
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

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('saves a renamed slot with a custom metric size', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    expect(find.text('Edit cylinder'), findsOneWidget);

    await tester.enterText(field('Label'), 'Truck A');
    await tester.enterText(field('Size (L)'), '10.8');
    await tester.enterText(field('Note'), 'sticky valve');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.label, 'Truck A');
    expect(stored.volume, 10.8);
    expect(stored.workingPressure, 207);
    // Typing a size makes it a custom cylinder.
    expect(stored.presetName, isNull);
    expect(stored.notes, 'sticky valve');
    expect(find.text('Edit cylinder'), findsNothing);
  });

  testWidgets('picking a preset fills and stores its specs', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text(presets.first.displayName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(presets.last.displayName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.presetName, presets.last.name);
    expect(stored.volume, presets.last.volumeLiters);
    expect(stored.workingPressure, presets.last.workingPressureBar);
    expect(stored.material, presets.last.material);
  });

  testWidgets('imperial capacity converts back to liters on save', (
    tester,
  ) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);

    await tester.enterText(field('Working pressure (psi)'), '3000');
    await tester.enterText(field('Size (cuft)'), '80');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getCylinderById(slot.id))!;
    expect(stored.workingPressure, closeTo(206.84, 0.01));
    expect(stored.volume, closeTo(80 * 28.3168 / stored.workingPressure!, 1e-6));
  });

  testWidgets('refuses an unreadable size and keeps the sheet open', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('Size (L)'), 'big');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid number'), findsOneWidget);
    expect((await repo.getCylinderById(slot.id))!.volume, 11.1);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet_test.dart`
Expected: FAIL to compile: the sheet does not exist.

- [ ] **Step 3: Write the sheet**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_specs_input.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the editor for one trip cylinder slot: its label, size, working
/// pressure and note. Picking a preset fills the size and pressure; typing
/// a size makes the slot a custom cylinder.
Future<void> showTripCylinderEditSheet(
  BuildContext context, {
  required TripCylinder cylinder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TripCylinderEditSheet(cylinder: cylinder),
  );
}

class _TripCylinderEditSheet extends ConsumerStatefulWidget {
  final TripCylinder cylinder;

  const _TripCylinderEditSheet({required this.cylinder});

  @override
  ConsumerState<_TripCylinderEditSheet> createState() =>
      _TripCylinderEditSheetState();
}

class _TripCylinderEditSheetState
    extends ConsumerState<_TripCylinderEditSheet> {
  late final TextEditingController _label;
  late final TextEditingController _size;
  late final TextEditingController _workingPressure;
  late final TextEditingController _notes;
  String? _presetName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.cylinder;
    final units = UnitFormatter(ref.read(settingsProvider));
    final preset = _presetNamed(c.presetName);
    _presetName = c.presetName;
    _label = TextEditingController(text: c.label);
    _size = TextEditingController(
      text: cylinderSizeForInput(
        units,
        liters: c.volume,
        workingPressureBar: c.workingPressure,
        ratedCuft: preset?.ratedCapacityCuft,
      ),
    );
    _workingPressure = TextEditingController(
      text: cylinderWorkingPressureForInput(units, c.workingPressure),
    );
    _notes = TextEditingController(text: c.notes);
  }

  @override
  void dispose() {
    _label.dispose();
    _size.dispose();
    _workingPressure.dispose();
    _notes.dispose();
    super.dispose();
  }

  TankPresetEntity? _presetNamed(String? name) {
    if (name == null) return null;
    final presets = ref.read(tankPresetsProvider).value ?? const [];
    for (final p in presets) {
      if (p.name == name) return p;
    }
    return null;
  }

  void _pickPreset(String? name) {
    final units = UnitFormatter(ref.read(settingsProvider));
    final preset = _presetNamed(name);
    setState(() {
      _presetName = name;
      if (preset != null) {
        _size.text = cylinderSizeForInput(
          units,
          liters: preset.volumeLiters,
          workingPressureBar: preset.workingPressureBar,
          ratedCuft: preset.ratedCapacityCuft,
        );
        _workingPressure.text = cylinderWorkingPressureForInput(
          units,
          preset.workingPressureBar,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final preset = _presetNamed(_presetName);
    final specs = cylinderSpecsFromInput(
      units,
      sizeText: _size.text,
      workingPressureText: _workingPressure.text,
      preset: preset,
    );
    if (specs.invalid) {
      setState(() => _error = l10n.numberInput_invalidValue);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = widget.cylinder;
      await ref
          .read(tripCylinderRepositoryProvider)
          .updateCylinder(
            c.copyWith(
              label: _label.text.trim(),
              volume: specs.volumeLiters,
              workingPressure: specs.workingPressureBar,
              material: preset?.material ?? c.material,
              presetName: preset?.name,
              notes: _notes.text,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A sync can delete the slot while the sheet is open.
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presets = ref.watch(tankPresetsProvider).value ?? const [];
    final known = presets.any((p) => p.name == _presetName);
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
              l10n.trips_cylinders_edit_title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_label,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('trip-cylinder-preset'),
              initialValue: known ? _presetName : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_add_preset,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.trips_cylinders_edit_presetCustom),
                ),
                for (final p in presets)
                  DropdownMenuItem<String?>(
                    value: p.name,
                    child: Text(p.displayName),
                  ),
              ],
              onChanged: _pickPreset,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _size,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_volume(units.volumeSymbol),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // A typed size is no longer the preset's.
              onChanged: (_) {
                if (_presetName != null) setState(() => _presetName = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workingPressure,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_workingPressure(
                  units.pressureSymbol,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_note,
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

Note on the metric size label: `units.volumeSymbol` is `L` in metric, so the field reads "Size (L)"; in imperial it is `cuft` and the field holds rated capacity, which is what `cylinderSpecsFromInput` expects.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet_test.dart`
Expected: PASS, 4 tests. If the preset test cannot find the dropdown's displayed item, tap `find.byKey(const Key('trip-cylinder-preset'))` to open it instead of the first preset's text, and ledger the change.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/widgets/cylinders test/features/trips/presentation/widgets/cylinders
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart test/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet_test.dart
git commit -m "feat(trips): edit a trip cylinder slot (#2325)"
```

---

### Task 5: The add cylinders sheet

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart`
- Test: `test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart`

**Interfaces:**
- Consumes: `tripCylinderRepositoryProvider`; `tankPresetsProvider`; `activeEquipmentProvider` (`FutureProvider<List<EquipmentItem>>`); `EquipmentItem.volumeL`, `workingPressureBar`, `tankMaterial`, `identifier`; Task 2 strings `trips_cylinders_add_*`, `trips_cylinders_action_add`, `trips_cylinders_fill_errorNoSlot`.
- Produces: `Future<void> showAddTripCylindersSheet(BuildContext context, {required String tripId, required List<TripCylinder> existing})`. New rental slots are numbered after the slots already on the trip ("Truck 5" follows four), and sort after them.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late String tripId;
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    List<TripCylinder> existing = const [],
    List<EquipmentItem> equipment = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tankPresetsProvider.overrideWith((ref) => Future.value([al80])),
          activeEquipmentProvider.overrideWith((ref) async => equipment),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAddTripCylindersSheet(
                  context,
                  tripId: tripId,
                  existing: existing,
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

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('adds numbered rental slots with the preset specs', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('How many'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final slots = await repo.getCylindersForTrip(tripId);
    expect(slots.map((s) => s.label), ['Truck 1', 'Truck 2', 'Truck 3']);
    expect(slots.first.volume, al80.volumeLiters);
    expect(slots.first.workingPressure, al80.workingPressureBar);
    expect(slots.first.material, al80.material);
    expect(slots.first.presetName, 'al80');
    expect(slots.map((s) => s.sortOrder), [0, 1, 2]);
  });

  testWidgets('numbering continues after the slots already on the trip', (
    tester,
  ) async {
    final now = DateTime.now();
    final first = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(tester, existing: [first]);
    await tester.enterText(field('How many'), '2');
    await tester.enterText(field('Label prefix'), 'Car');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final labels = (await repo.getCylindersForTrip(tripId)).map((s) => s.label);
    expect(labels, ['Truck 1', 'Car 2', 'Car 3']);
  });

  testWidgets('refuses a count outside 1 to 20', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('How many'), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number from 1 to 20.'), findsOneWidget);
    expect(await repo.getCylindersForTrip(tripId), isEmpty);
  });

  testWidgets('adds an owned cylinder and hides the ones already added', (
    tester,
  ) async {
    final equipmentRepo = EquipmentRepository();
    final mine = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    );
    final taken = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'Old AL80', type: EquipmentType.tank),
    );
    final now = DateTime.now();
    final existing = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        equipmentId: taken.id,
        label: 'Old AL80',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(
      tester,
      existing: [existing],
      equipment: [mine, taken],
    );

    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('owned-${taken.id}')), findsNothing);
    await tester.tap(find.byKey(Key('owned-${mine.id}')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final slots = await repo.getCylindersForTrip(tripId);
    expect(slots.map((s) => s.label), ['Old AL80', 'My HP100']);
    expect(slots.last.equipmentId, mine.id);
  });

  testWidgets('refuses an owned save with nothing picked', (tester) async {
    final mine = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    );
    await pumpAndOpen(tester, equipment: [mine]);
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one cylinder.'), findsOneWidget);
    expect(await repo.getCylindersForTrip(tripId), isEmpty);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart`
Expected: FAIL to compile: the sheet does not exist. If `EquipmentRepository` lives under another name, use the class `test/features/dive_log/data/repositories/dive_tank_regulator_link_test.dart` imports from `equipment_repository_impl.dart`.

- [ ] **Step 3: Write the sheet**

Create `lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the sheet that adds cylinder slots to a trip: a number of rental
/// slots of one preset, or cylinders from the diver's own equipment that
/// are not on the trip yet. [existing] is the trip's current slots, so new
/// rental labels and board positions continue after them.
Future<void> showAddTripCylindersSheet(
  BuildContext context, {
  required String tripId,
  required List<TripCylinder> existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddTripCylindersSheet(tripId: tripId, existing: existing),
  );
}

enum _AddMode { rental, owned }

/// The largest batch one save adds: a truck, not a fill station's stock.
const int _maxRentalCount = 20;

class _AddTripCylindersSheet extends ConsumerStatefulWidget {
  final String tripId;
  final List<TripCylinder> existing;

  const _AddTripCylindersSheet({required this.tripId, required this.existing});

  @override
  ConsumerState<_AddTripCylindersSheet> createState() =>
      _AddTripCylindersSheetState();
}

class _AddTripCylindersSheetState
    extends ConsumerState<_AddTripCylindersSheet> {
  _AddMode _mode = _AddMode.rental;
  final _count = TextEditingController(text: '4');
  final _prefix = TextEditingController();
  bool _prefixSeeded = false;
  String? _presetName = 'al80';
  final Set<String> _owned = {};
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The default prefix is a translated word, so it waits for context.
    if (!_prefixSeeded) {
      _prefix.text = context.l10n.trips_cylinders_add_prefixDefault;
      _prefixSeeded = true;
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _prefix.dispose();
    super.dispose();
  }

  List<EquipmentItem> _ownedCandidates(List<EquipmentItem> equipment) {
    final taken = {
      for (final c in widget.existing)
        if (c.equipmentId != null) c.equipmentId!,
    };
    return [
      for (final e in equipment)
        if (e.type == EquipmentType.tank && !taken.contains(e.id)) e,
    ];
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final start = widget.existing.length;
    final now = DateTime.now().toUtc();
    final drafts = <TripCylinder>[];
    if (_mode == _AddMode.rental) {
      final count = int.tryParse(_count.text.trim());
      if (count == null || count < 1 || count > _maxRentalCount) {
        setState(() => _error = l10n.trips_cylinders_add_errorCount);
        return;
      }
      final presets = ref.read(tankPresetsProvider).value ?? const [];
      final preset = presets.where((p) => p.name == _presetName).firstOrNull;
      final prefix = _prefix.text.trim();
      for (var i = 0; i < count; i++) {
        final n = start + i + 1;
        drafts.add(
          TripCylinder(
            id: '',
            tripId: widget.tripId,
            label: prefix.isEmpty ? '$n' : '$prefix $n',
            volume: preset?.volumeLiters,
            workingPressure: preset?.workingPressureBar,
            material: preset?.material,
            presetName: preset?.name,
            sortOrder: start + i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    } else {
      final equipment = ref.read(activeEquipmentProvider).value ?? const [];
      final picks = _ownedCandidates(
        equipment,
      ).where((e) => _owned.contains(e.id)).toList();
      if (picks.isEmpty) {
        setState(() => _error = l10n.trips_cylinders_fill_errorNoSlot);
        return;
      }
      for (var i = 0; i < picks.length; i++) {
        final e = picks[i];
        final mark = e.identifier?.trim() ?? '';
        drafts.add(
          TripCylinder(
            id: '',
            tripId: widget.tripId,
            equipmentId: e.id,
            label: mark.isEmpty ? e.name : mark,
            volume: e.volumeL,
            workingPressure: e.workingPressureBar,
            material: e.tankMaterial,
            sortOrder: start + i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tripCylinderRepositoryProvider);
      for (final draft in drafts) {
        await repo.createCylinder(draft);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presets = ref.watch(tankPresetsProvider).value ?? const [];
    final candidates = _ownedCandidates(
      ref.watch(activeEquipmentProvider).value ?? const [],
    );
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
              l10n.trips_cylinders_action_add,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<_AddMode>(
              segments: [
                ButtonSegment(
                  value: _AddMode.rental,
                  label: Text(l10n.trips_cylinders_add_tabRental),
                ),
                ButtonSegment(
                  value: _AddMode.owned,
                  label: Text(l10n.trips_cylinders_add_tabOwned),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_mode == _AddMode.rental) ...[
              TextField(
                controller: _count,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_count,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: presets.any((p) => p.name == _presetName)
                    ? _presetName
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_preset,
                ),
                items: [
                  for (final p in presets)
                    DropdownMenuItem<String?>(
                      value: p.name,
                      child: Text(p.displayName),
                    ),
                ],
                onChanged: (v) => setState(() => _presetName = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prefix,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_prefix,
                ),
              ),
            ] else if (candidates.isEmpty)
              Text(l10n.trips_cylinders_add_noOwned)
            else
              for (final e in candidates)
                CheckboxListTile(
                  key: Key('owned-${e.id}'),
                  value: _owned.contains(e.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: e.volumeL == null
                      ? null
                      : Text(
                          units.formatTankVolume(
                            e.volumeL,
                            e.workingPressureBar,
                          ),
                        ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _owned.add(e.id);
                    } else {
                      _owned.remove(e.id);
                    }
                  }),
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

`firstOrNull` on an `Iterable` needs `package:collection/collection.dart`; add that import if the analyzer asks.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/widgets/cylinders test/features/trips/presentation/widgets/cylinders
git add lib/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart test/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet_test.dart
git commit -m "feat(trips): add rental or owned cylinders to a trip (#2325)"
```

---

### Task 6: The fill sheet

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart`
- Test: `test/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet_test.dart`

**Interfaces:**
- Consumes: `tripCylinderRepositoryProvider`; `TripCylinderState` list (the board's states); `tripCylinderWallClock`; `allDiveCentersProvider`; `DiveCenterPickerSheet`; `defaultCurrencyProvider`; `currencyCodesWith`; Task 2 display helper `tripCylinderMixLabel` and strings `trips_cylinders_fill_*`, `trips_cylinders_action_fill`, `trips_cylinders_action_fillSeveral`, `trips_cylinders_mixAir`, `trips_cylinders_note`.
- Produces: `Future<void> showTripCylinderFillSheet(BuildContext context, {required List<TripCylinderState> slots, Set<String> preselected = const {}, bool several = false, TripCylinderEvent? editing})`; `Future<DateTime?> pickTripCylinderWhen(BuildContext context, DateTime current)`; `bool tripCylinderMixIsValid(double o2, double he)`; `String? lastTripFillCenter(List<TripCylinderState> slots)`. Field keys used by later tests: `fill-pressure`, `fill-o2`, `fill-he`, `fill-cost`, `fill-slot-<id>`, `fill-bottle-<id>`, `fill-aO2-<id>`, `fill-aHe-<id>`.

Behaviour fixed here from the spec: the shared fields (when, station, pressure, ordered mix, cost, currency, package, note) appear once; each selected slot gets its own row for bottle number and analyzed O2 and He; each selected slot gets its own event. "Fill several" lists every slot with a checkbox; a plain fill shows only its slot. A blank pressure is stored as null (the fold reads it as the working pressure); a blank ordered O2 is air. The station defaults to the most recent station used on the trip. Currency is stored only with a cost.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late List<TripCylinder> cylinders;
  late List<TripCylinderState> states;

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    );
    cylinders = [
      for (var i = 1; i <= 3; i++)
        await repo.createCylinder(
          TripCylinder(
            id: '',
            tripId: trip.id,
            label: 'Truck $i',
            workingPressure: 207,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
        ),
    ];
    states = [
      for (final c in cylinders)
        foldCylinderState(cylinder: c, events: const [], uses: const []),
    ];
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    Set<String>? preselected,
    bool several = false,
    TripCylinderEvent? editing,
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                settings ??
                MockSettingsNotifier(const AppSettings(defaultCurrency: 'EUR')),
          ),
          allDiveCentersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTripCylinderFillSheet(
                  context,
                  slots: states,
                  preselected: preselected ?? {cylinders.first.id},
                  several: several,
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

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  testWidgets('records one fill with analysis, bottle and cost', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await type(tester, 'fill-pressure', '200');
    await type(tester, 'fill-o2', '32');
    await type(tester, 'fill-aO2-$id', '31.6');
    await type(tester, 'fill-bottle-$id', '14');
    await type(tester, 'fill-cost', '12.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.kind, TripCylinderEventKind.fill);
    expect(e.pressure, 200);
    expect(e.o2Percent, 32);
    expect(e.analyzedO2, 31.6);
    expect(e.bottleLabel, '14');
    expect(e.cost, 12.5);
    expect(e.currency, 'EUR');
    expect(e.occurredAt.isUtc, isTrue);
  });

  testWidgets('a blank pressure and no cost store nulls', (tester) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.pressure, isNull);
    expect(e.o2Percent, 21);
    expect(e.cost, isNull);
    expect(e.currency, isNull);
  });

  testWidgets('an imperial fill pressure is stored in bar', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    final id = cylinders.first.id;
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('Fill pressure (psi)'), findsOneWidget);
    await type(tester, 'fill-pressure', '3000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    const units = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));
    final e = (await repo.getEventsForCylinder(id)).single;
    expect(e.pressure, closeTo(units.pressureToBar(3000), 1e-9));
  });

  testWidgets('fill several writes one event per checked slot only', (
    tester,
  ) async {
    final [a, b, c] = cylinders;
    await pumpAndOpen(
      tester,
      several: true,
      preselected: {a.id, b.id, c.id},
    );
    expect(find.text('Cylinders to fill'), findsOneWidget);
    await type(tester, 'fill-bottle-${a.id}', '7');
    await type(tester, 'fill-bottle-${b.id}', '8');
    await type(tester, 'fill-bottle-${c.id}', '9');
    // Typed, then unchecked: the slot gets nothing.
    await tester.tap(find.byKey(Key('fill-slot-${b.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repo.getEventsForCylinder(a.id)).single.bottleLabel, '7');
    expect(await repo.getEventsForCylinder(b.id), isEmpty);
    expect((await repo.getEventsForCylinder(c.id)).single.bottleLabel, '9');
  });

  testWidgets('refuses an analyzed mix over 100 percent and saves nothing', (
    tester,
  ) async {
    final id = cylinders.first.id;
    await pumpAndOpen(tester);
    await type(tester, 'fill-aO2-$id', '32');
    await type(tester, 'fill-aHe-$id', '70');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Oxygen must be 1 to 100 percent, helium 0 to 99, and together at most 100.',
      ),
      findsOneWidget,
    );
    expect(await repo.getEventsForCylinder(id), isEmpty);
  });

  testWidgets('refuses a fill with no slot picked', (tester) async {
    await pumpAndOpen(tester, several: true, preselected: {});
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one cylinder.'), findsOneWidget);
  });

  testWidgets('edits an existing fill in place', (tester) async {
    final id = cylinders.first.id;
    final now = DateTime.now().toUtc();
    final existing = await repo.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: DateTime.utc(2026, 3, 9, 8),
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    expect(find.text('Edit fill'), findsOneWidget);
    await type(tester, 'fill-bottle-$id', '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final events = await repo.getEventsForCylinder(id);
    expect(events, hasLength(1));
    expect(events.single.bottleLabel, '15');
    expect(events.single.occurredAt, DateTime.utc(2026, 3, 9, 8));
  });

  group('pure rules', () {
    test('mix validity', () {
      expect(tripCylinderMixIsValid(21, 0), isTrue);
      expect(tripCylinderMixIsValid(100, 0), isTrue);
      expect(tripCylinderMixIsValid(18, 45), isTrue);
      expect(tripCylinderMixIsValid(0.5, 0), isFalse);
      expect(tripCylinderMixIsValid(32, 70), isFalse);
      expect(tripCylinderMixIsValid(1, 100), isFalse);
    });

    test('the default station is the latest one used on the trip', () {
      TripCylinderState withFill(int hour, String? center) {
        final at = DateTime.utc(2026, 3, 9, hour);
        final fill = TripCylinderEvent(
          id: 'f$hour',
          tripCylinderId: cylinders.first.id,
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          diveCenterId: center,
          createdAt: at,
          updatedAt: at,
        );
        return foldCylinderState(
          cylinder: cylinders.first,
          events: [fill],
          uses: const [],
        );
      }

      expect(
        lastTripFillCenter([withFill(8, 'a'), withFill(10, 'b'), withFill(12, null)]),
        'b',
      );
      expect(lastTripFillCenter(states), isNull);
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet_test.dart`
Expected: FAIL to compile: the sheet does not exist.

- [ ] **Step 3: Write the sheet**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// True when a cylinder can hold the mix: O2 1 to 100 percent, He 0 to 99,
/// together at most 100.
bool tripCylinderMixIsValid(double o2, double he) =>
    o2 >= 1 && o2 <= 100 && he >= 0 && he <= 99 && o2 + he <= 100;

/// The fill station the trip used last, for the sheet's default: the Bonaire
/// ritual is the same drive-through every morning.
String? lastTripFillCenter(List<TripCylinderState> slots) {
  TripCylinderEvent? latest;
  for (final s in slots) {
    final fill = s.lastFill;
    if (fill == null || fill.diveCenterId == null) continue;
    if (latest == null || fill.occurredAt.isAfter(latest.occurredAt)) {
      latest = fill;
    }
  }
  return latest?.diveCenterId;
}

/// Asks for a date, then a time, starting from [current]. Returns the
/// picked wall clock stamped UTC, the frame every dive time uses, or null
/// when the diver cancels either picker. Shared by the fill and adjust
/// sheets.
Future<DateTime?> pickTripCylinderWhen(
  BuildContext context,
  DateTime current,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(current.year, current.month, current.day),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
  );
  if (time == null) return null;
  return DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);
}

/// Opens the fill sheet. With [several] every slot is listed with a
/// checkbox ([preselected] checked); otherwise only the preselected slot is
/// shown. With [editing] the sheet edits that fill in place.
Future<void> showTripCylinderFillSheet(
  BuildContext context, {
  required List<TripCylinderState> slots,
  Set<String> preselected = const {},
  bool several = false,
  TripCylinderEvent? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FillSheet(
      slots: slots,
      preselected: preselected,
      several: several && editing == null,
      editing: editing,
    ),
  );
}

class _FillSheet extends ConsumerStatefulWidget {
  final List<TripCylinderState> slots;
  final Set<String> preselected;
  final bool several;
  final TripCylinderEvent? editing;

  const _FillSheet({
    required this.slots,
    required this.preselected,
    required this.several,
    required this.editing,
  });

  @override
  ConsumerState<_FillSheet> createState() => _FillSheetState();
}

typedef _Analysis = ({double? o2, double? he});

class _FillSheetState extends ConsumerState<_FillSheet> {
  late Set<String> _selected;
  late DateTime _when;
  String? _centerId;
  late final TextEditingController _pressure;
  late final TextEditingController _o2;
  late final TextEditingController _he;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  final _bottle = <String, TextEditingController>{};
  final _analyzedO2 = <String, TextEditingController>{};
  final _analyzedHe = <String, TextEditingController>{};
  late String _currency;
  bool _package = false;
  bool _saving = false;
  String? _error;

  static String _num(double? v, int digits) =>
      v == null ? '' : formatRoundedForInput(v, digits);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _selected = e != null ? {e.tripCylinderId} : {...widget.preselected};
    _when = e?.occurredAt ?? tripCylinderWallClock(DateTime.now());
    _centerId = e != null ? e.diveCenterId : lastTripFillCenter(widget.slots);
    GasMix? firstMix;
    for (final s in widget.slots) {
      if (_selected.contains(s.cylinder.id)) {
        firstMix = s.mix;
        break;
      }
    }
    final he = e?.hePercent ?? firstMix?.he;
    _pressure = TextEditingController(
      text: e?.pressure == null
          ? ''
          : _num(units.convertPressure(e!.pressure!), 0),
    );
    _o2 = TextEditingController(
      text: _num(e?.o2Percent ?? firstMix?.o2 ?? 21, 1),
    );
    _he = TextEditingController(text: he == null || he == 0 ? '' : _num(he, 1));
    for (final s in widget.slots) {
      final id = s.cylinder.id;
      final mine = e != null && e.tripCylinderId == id;
      _bottle[id] = TextEditingController(
        text: mine ? (e.bottleLabel ?? '') : '',
      );
      _analyzedO2[id] = TextEditingController(
        text: mine ? _num(e.analyzedO2, 1) : '',
      );
      _analyzedHe[id] = TextEditingController(
        text: mine ? _num(e.analyzedHe, 1) : '',
      );
    }
    _cost = TextEditingController(text: _num(e?.cost, 2));
    final code = (e?.currency ?? ref.read(defaultCurrencyProvider))
        .trim()
        .toUpperCase();
    _currency = code.isEmpty ? 'USD' : code;
    _package = e?.isPackage ?? false;
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _pressure,
      _o2,
      _he,
      _cost,
      _note,
      ..._bottle.values,
      ..._analyzedO2.values,
      ..._analyzedHe.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Null for a blank field; NaN for text that is not a number.
  static double? _read(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return parseUserDecimal(t) ?? double.nan;
  }

  static String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickWhen() async {
    final picked = await pickTripCylinderWhen(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  Future<void> _pickCenter(List<DiveCenter> centers) async {
    final current = centers.where((c) => c.id == _centerId).firstOrNull;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => DiveCenterPickerSheet(
          scrollController: scrollController,
          selectedCenter: current,
          onCenterSelected: (center) {
            Navigator.of(sheetContext).pop();
            setState(() => _centerId = center.id);
          },
          // Creating a center is the dive editor's flow; here the picker
          // only chooses among existing ones.
          onCreateNewCenter: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final ids = [
      for (final s in widget.slots)
        if (_selected.contains(s.cylinder.id)) s.cylinder.id,
    ];
    if (ids.isEmpty) {
      setState(() => _error = l10n.trips_cylinders_fill_errorNoSlot);
      return;
    }
    final pressure = _read(_pressure);
    final o2 = _read(_o2);
    final he = _read(_he);
    final cost = _read(_cost);
    final analysis = <String, _Analysis>{
      for (final id in ids)
        id: (o2: _read(_analyzedO2[id]!), he: _read(_analyzedHe[id]!)),
    };
    final numbers = <double?>[
      pressure,
      o2,
      he,
      cost,
      for (final a in analysis.values) ...[a.o2, a.he],
    ];
    if (numbers.any((v) => v != null && (v.isNaN || v < 0))) {
      setState(() => _error = l10n.numberInput_invalidValue);
      return;
    }
    final orderedO2 = o2 ?? 21.0;
    final orderedHe = he ?? 0.0;
    bool badAnalysis(_Analysis a) => a.o2 == null
        ? a.he != null
        : !tripCylinderMixIsValid(a.o2!, a.he ?? 0);
    if (!tripCylinderMixIsValid(orderedO2, orderedHe) ||
        analysis.values.any(badAnalysis)) {
      setState(() => _error = l10n.trips_cylinders_fill_errorMix);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tripCylinderRepositoryProvider);
      final bar = pressure == null ? null : units.pressureToBar(pressure);
      final currency = cost == null ? null : _currency;
      final e = widget.editing;
      if (e != null) {
        final a = analysis[e.tripCylinderId]!;
        await repo.updateEvent(
          e.copyWith(
            occurredAt: _when,
            bottleLabel: _text(_bottle[e.tripCylinderId]!),
            pressure: bar,
            o2Percent: orderedO2,
            hePercent: orderedHe,
            analyzedO2: a.o2,
            analyzedHe: a.he,
            diveCenterId: _centerId,
            cost: cost,
            currency: currency,
            isPackage: _package,
            note: _note.text,
          ),
        );
      } else {
        final now = DateTime.now().toUtc();
        for (final id in ids) {
          final a = analysis[id]!;
          await repo.createEvent(
            TripCylinderEvent(
              id: '',
              tripCylinderId: id,
              kind: TripCylinderEventKind.fill,
              occurredAt: _when,
              bottleLabel: _text(_bottle[id]!),
              pressure: bar,
              o2Percent: orderedO2,
              hePercent: orderedHe,
              analyzedO2: a.o2,
              analyzedHe: a.he,
              diveCenterId: _centerId,
              cost: cost,
              currency: currency,
              isPackage: _package,
              note: _note.text,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _slotFields(String id) {
    final l10n = context.l10n;
    InputDecoration dense(String label) =>
        InputDecoration(labelText: label, isDense: true);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: Key('fill-bottle-$id'),
              controller: _bottle[id],
              decoration: dense(l10n.trips_cylinders_fill_bottle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('fill-aO2-$id'),
              controller: _analyzedO2[id],
              decoration: dense(l10n.trips_cylinders_fill_analyzedO2),
              keyboardType: decimal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('fill-aHe-$id'),
              controller: _analyzedHe[id],
              decoration: dense(l10n.trips_cylinders_fill_analyzedHe),
              keyboardType: decimal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerName = centers
        .where((c) => c.id == _centerId)
        .firstOrNull
        ?.name;
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final title = widget.editing != null
        ? l10n.trips_cylinders_fill_titleEdit
        : widget.several
        ? l10n.trips_cylinders_action_fillSeveral
        : l10n.trips_cylinders_action_fill;
    final quickMixes = <(String, double)>[
      (tripCylinderMixLabel(l10n, const GasMix()), 21),
      ('EAN32', 32),
      ('EAN36', 36),
    ];
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
            Text(title, style: theme.textTheme.titleMedium),
            ListTile(
              key: const Key('fill-when'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_when),
              subtitle: Text(units.formatDateTime(_when, l10n: l10n)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickWhen,
            ),
            ListTile(
              key: const Key('fill-where'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_where),
              subtitle: Text(centerName ?? l10n.trips_cylinders_fill_whereNone),
              trailing: _centerId == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.common_action_remove,
                      onPressed: () => setState(() => _centerId = null),
                    ),
              onTap: () => _pickCenter(centers),
            ),
            TextField(
              key: const Key('fill-pressure'),
              controller: _pressure,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_fill_pressure(
                  units.pressureSymbol,
                ),
              ),
              keyboardType: decimal,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fill-o2'),
                    controller: _o2,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_o2,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('fill-he'),
                    controller: _he,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_he,
                    ),
                    keyboardType: decimal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, o2) in quickMixes)
                  ActionChip(
                    label: Text(label),
                    onPressed: () => setState(() {
                      _o2.text = _num(o2, 1);
                      _he.text = '';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.several)
              Text(
                l10n.trips_cylinders_fill_slots,
                style: theme.textTheme.titleSmall,
              ),
            for (final s in widget.slots)
              if (widget.several) ...[
                CheckboxListTile(
                  key: Key('fill-slot-${s.cylinder.id}'),
                  value: _selected.contains(s.cylinder.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.cylinder.label),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(s.cylinder.id);
                    } else {
                      _selected.remove(s.cylinder.id);
                    }
                  }),
                ),
                if (_selected.contains(s.cylinder.id))
                  _slotFields(s.cylinder.id),
              ] else if (_selected.contains(s.cylinder.id)) ...[
                Text(s.cylinder.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                _slotFields(s.cylinder.id),
              ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fill-cost'),
                    controller: _cost,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_cost,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    key: const Key('fill-currency'),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_currency,
                    ),
                    items: [
                      for (final code in currencyCodesWith(_currency))
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('fill-package'),
              contentPadding: EdgeInsets.zero,
              value: _package,
              title: Text(l10n.trips_cylinders_fill_package),
              onChanged: (v) => setState(() => _package = v),
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_note,
              ),
              maxLines: 2,
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

`firstOrNull` on an `Iterable` needs `package:collection/collection.dart`; add that import if the analyzer asks.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet_test.dart`
Expected: PASS, 9 tests. If a tap misses because the field is below the fold, raise the test view height; do not shrink the sheet.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/widgets/cylinders test/features/trips/presentation/widgets/cylinders
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart test/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet_test.dart
git commit -m "feat(trips): record a cylinder fill, one slot or several (#2325)"
```

---

### Task 7: The adjust sheet

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart`
- Test: `test/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet_test.dart`

**Interfaces:**
- Consumes: Task 6's `pickTripCylinderWhen` and `tripCylinderMixIsValid`; `tripCylinderRepositoryProvider`; Task 2 strings `trips_cylinders_action_adjust`, `trips_cylinders_adjust_*`, `trips_cylinders_fill_when`, `trips_cylinders_fill_analyzedO2`, `trips_cylinders_fill_analyzedHe`, `trips_cylinders_fill_errorMix`, `trips_cylinders_note`.
- Produces: `Future<void> showTripCylinderAdjustSheet(BuildContext context, {required TripCylinder cylinder, TripCylinderEvent? editing})`. Keys: `adjust-pressure`, `adjust-mark-empty`, `adjust-o2`, `adjust-he`.

An adjustment is a correction: a gauge reading, "mark empty", or a re-analyzed mix. Its mix fields are optional and use the analyzed labels; a blank pressure leaves the pressure as it was (the fold rule).

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late TripCylinder slot;

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    );
    slot = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: trip.id,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    TripCylinderEvent? editing,
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
                onPressed: () => showTripCylinderAdjustSheet(
                  context,
                  cylinder: slot,
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

  testWidgets('records a gauge reading', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Adjust'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjust-pressure')), '120');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.kind, TripCylinderEventKind.adjustment);
    expect(e.pressure, 120);
    expect(e.o2Percent, isNull);
  });

  testWidgets('mark empty records zero, in psi too', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('Pressure (psi)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adjust-mark-empty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.pressure, 0);
  });

  testWidgets('a re-analyzed mix is stored with helium defaulting to 0', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('adjust-o2')), '31');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = (await repo.getEventsForCylinder(slot.id)).single;
    expect(e.o2Percent, 31);
    expect(e.hePercent, 0);
    expect(e.pressure, isNull);
  });

  testWidgets('helium without oxygen is refused', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('adjust-he')), '35');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Oxygen must be 1 to 100 percent, helium 0 to 99, and together at most 100.',
      ),
      findsOneWidget,
    );
    expect(await repo.getEventsForCylinder(slot.id), isEmpty);
  });

  testWidgets('edits an adjustment in place, converting its pressure', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = await repo.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: slot.id,
        kind: TripCylinderEventKind.adjustment,
        occurredAt: DateTime.utc(2026, 3, 9, 14),
        pressure: 100,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, editing: existing, settings: imperial);
    expect(find.text('Edit adjustment'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjust-pressure')), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    const psi = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));
    final events = await repo.getEventsForCylinder(slot.id);
    expect(events, hasLength(1));
    expect(events.single.pressure, closeTo(psi.pressureToBar(1000), 1e-9));
    expect(events.single.occurredAt, DateTime.utc(2026, 3, 9, 14));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet_test.dart`
Expected: FAIL to compile: the sheet does not exist.

- [ ] **Step 3: Write the sheet**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the adjustment sheet for one slot: a gauge reading, "mark empty",
/// or a re-analyzed mix. With [editing] it edits that adjustment in place.
Future<void> showTripCylinderAdjustSheet(
  BuildContext context, {
  required TripCylinder cylinder,
  TripCylinderEvent? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AdjustSheet(cylinder: cylinder, editing: editing),
  );
}

class _AdjustSheet extends ConsumerStatefulWidget {
  final TripCylinder cylinder;
  final TripCylinderEvent? editing;

  const _AdjustSheet({required this.cylinder, required this.editing});

  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends ConsumerState<_AdjustSheet> {
  late DateTime _when;
  late final TextEditingController _pressure;
  late final TextEditingController _o2;
  late final TextEditingController _he;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;

  static String _num(double? v, int digits) =>
      v == null ? '' : formatRoundedForInput(v, digits);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _when = e?.occurredAt ?? tripCylinderWallClock(DateTime.now());
    _pressure = TextEditingController(
      text: e?.pressure == null
          ? ''
          : _num(units.convertPressure(e!.pressure!), 0),
    );
    _o2 = TextEditingController(text: _num(e?.o2Percent, 1));
    final he = e?.hePercent;
    _he = TextEditingController(text: he == null || he == 0 ? '' : _num(he, 1));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _pressure.dispose();
    _o2.dispose();
    _he.dispose();
    _note.dispose();
    super.dispose();
  }

  static double? _read(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return parseUserDecimal(t) ?? double.nan;
  }

  Future<void> _pickWhen() async {
    final picked = await pickTripCylinderWhen(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final pressure = _read(_pressure);
    final o2 = _read(_o2);
    final he = _read(_he);
    if ([pressure, o2, he].any((v) => v != null && (v.isNaN || v < 0))) {
      setState(() => _error = l10n.numberInput_invalidValue);
      return;
    }
    final badMix = o2 == null
        ? he != null
        : !tripCylinderMixIsValid(o2, he ?? 0);
    if (badMix) {
      setState(() => _error = l10n.trips_cylinders_fill_errorMix);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tripCylinderRepositoryProvider);
      final bar = pressure == null ? null : units.pressureToBar(pressure);
      final hePercent = o2 == null ? null : (he ?? 0.0);
      final e = widget.editing;
      if (e != null) {
        await repo.updateEvent(
          e.copyWith(
            occurredAt: _when,
            pressure: bar,
            o2Percent: o2,
            hePercent: hePercent,
            note: _note.text,
          ),
        );
      } else {
        final now = DateTime.now().toUtc();
        await repo.createEvent(
          TripCylinderEvent(
            id: '',
            tripCylinderId: widget.cylinder.id,
            kind: TripCylinderEventKind.adjustment,
            occurredAt: _when,
            pressure: bar,
            o2Percent: o2,
            hePercent: hePercent,
            note: _note.text,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    const decimal = TextInputType.numberWithOptions(decimal: true);
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
                  ? l10n.trips_cylinders_action_adjust
                  : l10n.trips_cylinders_adjust_titleEdit,
              style: theme.textTheme.titleMedium,
            ),
            Text(widget.cylinder.label, style: theme.textTheme.bodyMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_when),
              subtitle: Text(units.formatDateTime(_when, l10n: l10n)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickWhen,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('adjust-pressure'),
                    controller: _pressure,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_adjust_pressure(
                        units.pressureSymbol,
                      ),
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('adjust-mark-empty'),
                  onPressed: () => setState(() => _pressure.text = '0'),
                  child: Text(l10n.trips_cylinders_adjust_markEmpty),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('adjust-o2'),
                    controller: _o2,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_analyzedO2,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('adjust-he'),
                    controller: _he,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_analyzedHe,
                    ),
                    keyboardType: decimal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_note,
              ),
              maxLines: 2,
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

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips/presentation/widgets/cylinders test/features/trips/presentation/widgets/cylinders
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart test/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet_test.dart
git commit -m "feat(trips): record a cylinder adjustment (#2325)"
```

---

### Task 8: The board page, slot cards and route

**Files:**
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart`
- Create: `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart`
- Modify: `lib/core/router/app_router.dart:831-838` (after the `gallery` route) and its imports
- Test: `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 4, 5, 6, 7; `tripCylinderStatesProvider`, `tripCylinderRepositoryProvider` (`countLinkedDives`, `deleteCylinder`, `reorderCylinders`); `allDiveCentersProvider`.
- Produces: `class TripCylinderBoardPage extends ConsumerWidget` with `const TripCylinderBoardPage({super.key, required String tripId})`; `class TripCylinderBoardList extends ConsumerWidget` with `const TripCylinderBoardList({super.key, required List<TripCylinderState> states, required Map<String, String> centerNames})`; `class TripCylinderSlotCard extends ConsumerWidget` with `({super.key, required TripCylinderState state, required List<TripCylinderState> allStates, required Map<String, String> centerNames})`; `Future<bool> confirmDeleteTripCylinder(BuildContext context, WidgetRef ref, TripCylinder cylinder)`; `List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex)`; route name `tripCylinders` at `/trips/:tripId/cylinders`. Keys: `board-add`, `board-fill-several`, `slot-menu-<id>`.

"Fill several" preselects every slot that is not full, which is the drive-through case: swap the empties, keep the fulls. Reorder is always available through the list's drag handles; there is no separate reorder mode.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`:

```dart
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repo;
  late String tripId;
  final at = DateTime.utc(2026, 3, 9, 8, 15);
  const units = UnitFormatter(AppSettings());

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<TripCylinder> slot(String label, int order) => repo.createCylinder(
    TripCylinder(
      id: '',
      tripId: tripId,
      label: label,
      volume: 11.1,
      workingPressure: 207,
      sortOrder: order,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> fill(String cylinderId) => repo.createEvent(
    TripCylinderEvent(
      id: '',
      tripCylinderId: cylinderId,
      kind: TripCylinderEventKind.fill,
      occurredAt: at,
      bottleLabel: '14',
      pressure: 200,
      o2Percent: 32,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> pumpBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiveCentersProvider.overrideWith((ref) async => const []),
          activeEquipmentProvider.overrideWith((ref) async => const []),
          tankPresetsProvider.overrideWith(
            (ref) => Future.value([
              TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!),
            ]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCylinderBoardPage(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty board offers to add cylinders', (tester) async {
    await pumpBoard(tester);
    expect(find.text('No cylinders on this trip yet'), findsOneWidget);
    final fillSeveral = tester.widget<IconButton>(
      find.byKey(const Key('board-fill-several')),
    );
    expect(fillSeveral.onPressed, isNull);

    await tester.tap(find.byKey(const Key('board-add')));
    await tester.pumpAndSettle();
    expect(find.text('Rental'), findsOneWidget);
  });

  testWidgets('each slot shows its mix, pressure, status and history', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await slot('Truck 2', 1);
    await fill(a.id);
    await pumpBoard(tester);

    expect(find.text('Truck 1'), findsOneWidget);
    expect(
      find.text('EAN32 · ${units.formatPressure(200)} · Full'),
      findsOneWidget,
    );
    expect(find.text('Bottle 14'), findsOneWidget);
    expect(
      find.text('Filled ${units.formatDateTime(at, l10n: AppLocalizationsEn())}'),
      findsOneWidget,
    );
    expect(find.text('Truck 2'), findsOneWidget);
    expect(find.textContaining('Not filled yet'), findsOneWidget);
  });

  testWidgets('deleting a used slot names the dive count and keeps the dive', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: at.millisecondsSinceEpoch + 3600000,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 't1', diveId: 'd1').copyWith(
            tripCylinderId: Value(a.id),
            endPressure: const Value(60.0),
          ),
        );
    await pumpBoard(tester);

    await tester.tap(find.byKey(Key('slot-menu-${a.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Delete this cylinder and its fills? 1 dive used it. That dive keeps its tank; only the link is removed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Truck 1'), findsNothing);
    final tank = await db
        .customSelect(
          'SELECT end_pressure, trip_cylinder_id FROM dive_tanks WHERE id = ?',
          variables: [Variable<String>('t1')],
        )
        .getSingle();
    expect(tank.read<double>('end_pressure'), 60);
    expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
  });

  testWidgets('fill several preselects the slots that are not full', (
    tester,
  ) async {
    final a = await slot('Truck 1', 0);
    final b = await slot('Truck 2', 1);
    await fill(a.id);
    await pumpBoard(tester);

    await tester.tap(find.byKey(const Key('board-fill-several')));
    await tester.pumpAndSettle();
    final full = tester.widget<CheckboxListTile>(
      find.byKey(Key('fill-slot-${a.id}')),
    );
    final notFull = tester.widget<CheckboxListTile>(
      find.byKey(Key('fill-slot-${b.id}')),
    );
    expect(full.value, isFalse);
    expect(notFull.value, isTrue);
  });

  test('reorderedIds moves one id and keeps the rest in order', () {
    expect(reorderedIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(reorderedIds(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(reorderedIds(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
  });
}
```


- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: FAIL to compile: the page does not exist.

- [ ] **Step 3: Write the slot card**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_edit_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before deleting [cylinder], naming how many dives used it, then
/// deletes it. The dives keep their tanks; only the link goes. Returns true
/// when the slot is gone.
Future<bool> confirmDeleteTripCylinder(
  BuildContext context,
  WidgetRef ref,
  TripCylinder cylinder,
) async {
  final l10n = context.l10n;
  final repo = ref.read(tripCylinderRepositoryProvider);
  final used = await repo.countLinkedDives(cylinder.id);
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(
        used == 0
            ? l10n.trips_cylinders_deleteConfirmUnused
            : l10n.trips_cylinders_deleteConfirmUsed(used),
      ),
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
  await repo.deleteCylinder(cylinder.id);
  return true;
}

enum _SlotAction { fill, adjust, edit, delete }

/// One slot on the board: its status dot and word, mix, pressure, the
/// bottle now in it, its size, the last thing that happened to it and how
/// many dives used it, with a menu to fill, adjust, edit or delete it.
class TripCylinderSlotCard extends ConsumerWidget {
  final TripCylinderState state;

  /// Every slot on the trip, so a fill started here can default its
  /// station from the trip's last fill.
  final List<TripCylinderState> allStates;
  final Map<String, String> centerNames;

  const TripCylinderSlotCard({
    super.key,
    required this.state,
    required this.allStates,
    required this.centerNames,
  });

  Future<void> _act(BuildContext context, WidgetRef ref, _SlotAction action) {
    final c = state.cylinder;
    return switch (action) {
      _SlotAction.fill => showTripCylinderFillSheet(
        context,
        slots: allStates,
        preselected: {c.id},
      ),
      _SlotAction.adjust => showTripCylinderAdjustSheet(context, cylinder: c),
      _SlotAction.edit => showTripCylinderEditSheet(context, cylinder: c),
      _SlotAction.delete => confirmDeleteTripCylinder(context, ref, c),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final c = state.cylinder;
    final mix = state.mix == null ? '--' : tripCylinderMixLabel(l10n, state.mix!);
    final pressure = state.pressure == null
        ? '--'
        : units.formatPressure(state.pressure);
    final status = tripCylinderStatusLabel(l10n, state.status);
    final last = tripCylinderLastItemText(
      l10n,
      units,
      state,
      centerNames: centerNames,
    );
    final small = theme.textTheme.bodySmall;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.circle,
          size: 14,
          color: tripCylinderStatusColor(theme.colorScheme, state.status),
          semanticLabel: status,
        ),
        title: Text(c.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$mix · $pressure · $status'),
            if (state.bottleLabel != c.label)
              Text(l10n.trips_cylinders_bottle(state.bottleLabel)),
            if (c.volume != null)
              Text(
                units.formatTankVolume(c.volume, c.workingPressure),
                style: small,
              ),
            if (last != null) Text(last, style: small),
            if (state.linkedDiveCount > 0)
              Text(
                l10n.trips_cylinders_linkedDives(state.linkedDiveCount),
                style: small,
              ),
          ],
        ),
        trailing: PopupMenuButton<_SlotAction>(
          key: Key('slot-menu-${c.id}'),
          onSelected: (action) => _act(context, ref, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _SlotAction.fill,
              child: Text(l10n.trips_cylinders_action_fill),
            ),
            PopupMenuItem(
              value: _SlotAction.adjust,
              child: Text(l10n.trips_cylinders_action_adjust),
            ),
            PopupMenuItem(
              value: _SlotAction.edit,
              child: Text(l10n.common_action_edit),
            ),
            PopupMenuItem(
              value: _SlotAction.delete,
              child: Text(l10n.common_action_delete),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write the board page**

Create `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [ids] with the one at [oldIndex] moved to [newIndex], the index
/// ReorderableListView's onReorderItem reports (already adjusted for the
/// removal).
List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  final moved = next.removeAt(oldIndex);
  next.insert(newIndex, moved);
  return next;
}

/// The trip's cylinder board: every slot with its state, reorderable, with
/// actions to add slots and to fill several at once.
class TripCylinderBoardPage extends ConsumerWidget {
  final String tripId;

  const TripCylinderBoardPage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statesAsync = ref.watch(tripCylinderStatesProvider(tripId));
    final states = statesAsync.value ?? const <TripCylinderState>[];
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerNames = {for (final c in centers) c.id: c.name};

    final Widget body;
    if (!statesAsync.hasValue && statesAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!statesAsync.hasValue && statesAsync.hasError) {
      body = Center(child: Text(l10n.common_label_error));
    } else if (states.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.trips_cylinders_boardEmpty),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.trips_cylinders_action_add),
              onPressed: () => showAddTripCylindersSheet(
                context,
                tripId: tripId,
                existing: const [],
              ),
            ),
          ],
        ),
      );
    } else {
      body = TripCylinderBoardList(states: states, centerNames: centerNames);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trips_cylinders_title),
        actions: [
          IconButton(
            key: const Key('board-fill-several'),
            tooltip: l10n.trips_cylinders_action_fillSeveral,
            icon: const Icon(Icons.local_gas_station_outlined),
            onPressed: states.isEmpty
                ? null
                : () => showTripCylinderFillSheet(
                    context,
                    slots: states,
                    several: true,
                    preselected: {
                      for (final s in states)
                        if (s.status != TripCylinderStatus.full) s.cylinder.id,
                    },
                  ),
          ),
          IconButton(
            key: const Key('board-add'),
            tooltip: l10n.trips_cylinders_action_add,
            icon: const Icon(Icons.add),
            onPressed: () => showAddTripCylindersSheet(
              context,
              tripId: tripId,
              existing: [for (final s in states) s.cylinder],
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// The reorderable list of slot cards. Dragging a card writes the new board
/// order through the repository; the list redraws from the provider.
class TripCylinderBoardList extends ConsumerWidget {
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderBoardList({
    super.key,
    required this.states,
    required this.centerNames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: states.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final s in states) s.cylinder.id];
        ref
            .read(tripCylinderRepositoryProvider)
            .reorderCylinders(reorderedIds(ids, oldIndex, newIndex));
      },
      itemBuilder: (context, i) => TripCylinderSlotCard(
        key: ValueKey(states[i].cylinder.id),
        state: states[i],
        allStates: states,
        centerNames: centerNames,
      ),
    );
  }
}
```

- [ ] **Step 5: Add the route**

In `lib/core/router/app_router.dart`, add the import next to the other trips pages:

```dart
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
```

and after the `gallery` `GoRoute` (lines 831-838) add:

```dart
                  GoRoute(
                    path: 'cylinders',
                    name: 'tripCylinders',
                    builder: (context, state) => TripCylinderBoardPage(
                      tripId: state.pathParameters['tripId']!,
                    ),
                  ),
```

Verify it is registered: `grep -n "name: 'tripCylinders'" lib/core/router/app_router.dart` prints one line.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart`
Expected: PASS, 5 tests. If `onReorderItem` is not a parameter of `ReorderableListView.builder` in this Flutter version, use `onReorder` with the manual `if (newIndex > oldIndex) newIndex -= 1;` adjustment before calling `reorderedIds`, and ledger the change.

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips lib/core/router/app_router.dart test/features/trips/presentation/pages
git add lib/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart lib/features/trips/presentation/pages/trip_cylinder_board_page.dart lib/core/router/app_router.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart
git commit -m "feat(trips): the trip cylinder board page (#2325)"
```

---

### Task 9: The story card in both trip layouts

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_cylinders_card.dart`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (imports; the four `TripScrubberMarginCard(trip: trip),` lines at 123, 137, 205, 219)
- Test: `test/features/trips/presentation/widgets/trip_cylinders_card_test.dart`

**Interfaces:**
- Consumes: `tripCylinderStatesProvider`; Task 2 helpers; `Trip.isUpcoming` (true for a trip that has not ended, the one in progress included); `MdiIcons.divingScubaTank` from `lib/core/icons/mdi_icons.dart`; the Task 8 route `/trips/:tripId/cylinders`.
- Produces: `class TripCylindersCard extends ConsumerWidget` with `const TripCylindersCard({super.key, required Trip trip})`. Keys: `trip-cylinders-card`, `cylinders-set-up`, `cylinder-chip-<id>`.

Visibility, from the spec: slots present, always shown (a past trip keeps its record); no slots and the trip upcoming or underway, shown as "Set up cylinders"; no slots on a past trip, nothing.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/presentation/widgets/trip_cylinders_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 8);

  Trip trip({bool past = false}) {
    final start = past
        ? DateTime(2025, 3, 1)
        : DateTime.now().add(const Duration(days: 10));
    return Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: start,
      endDate: start.add(const Duration(days: 6)),
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
  }

  TripCylinder cylinder(String id, String label) => TripCylinder(
    id: id,
    tripId: 't1',
    label: label,
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );

  List<TripCylinderState> states() => [
    foldCylinderState(
      cylinder: cylinder('c1', 'Truck 1'),
      events: [
        TripCylinderEvent(
          id: 'f1',
          tripCylinderId: 'c1',
          kind: TripCylinderEventKind.fill,
          occurredAt: at,
          bottleLabel: '14',
          pressure: 200,
          o2Percent: 32,
          createdAt: at,
          updatedAt: at,
        ),
      ],
      uses: const [],
    ),
    foldCylinderState(
      cylinder: cylinder('c2', 'Truck 2'),
      events: const [],
      uses: const [],
    ),
  ];

  Widget host(
    List<TripCylinderState> slots, {
    bool past = false,
    MockSettingsNotifier? settings,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: TripCylindersCard(trip: trip(past: past))),
        ),
        GoRoute(
          path: '/trips/:tripId/cylinders',
          builder: (_, _) => const Scaffold(body: Text('BOARD')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => settings ?? MockSettingsNotifier(),
        ),
        tripCylinderStatesProvider('t1').overrideWith((ref) async => slots),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('an upcoming trip with no slots offers set-up', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.byKey(const Key('cylinders-set-up')), findsOneWidget);
  });

  testWidgets('a past trip with no slots shows nothing', (tester) async {
    await tester.pumpWidget(host(const [], past: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-cylinders-card')), findsNothing);
  });

  testWidgets('a past trip with slots keeps its record', (tester) async {
    await tester.pumpWidget(host(states(), past: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-cylinders-card')), findsOneWidget);
  });

  testWidgets('summarizes the slots and shows a chip for each', (
    tester,
  ) async {
    await tester.pumpWidget(host(states()));
    await tester.pumpAndSettle();
    const units = UnitFormatter(AppSettings());
    expect(
      find.text('Full 1 · Partial 0 · Empty 0 · Not filled yet 1'),
      findsOneWidget,
    );
    expect(
      find.text('14 · EAN32 · ${units.formatPressure(200)}'),
      findsOneWidget,
    );
    expect(find.text('Truck 2 · -- · --'), findsOneWidget);
  });

  testWidgets('an imperial diver sees psi on the chips', (tester) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await tester.pumpWidget(host(states(), settings: imperial));
    await tester.pumpAndSettle();
    expect(find.textContaining('psi'), findsOneWidget);
  });

  testWidgets('tapping the card opens the board', (tester) async {
    await tester.pumpWidget(host(states()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-cylinders-card')));
    await tester.pumpAndSettle();
    expect(find.text('BOARD'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/trip_cylinders_card_test.dart`
Expected: FAIL to compile: the card does not exist.

- [ ] **Step 3: Write the card**

Create `lib/features/trips/presentation/widgets/trip_cylinders_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The cylinders card in the trip story: a count of full, partial and
/// empty slots and a chip per slot (bottle, mix, pressure). Tapping it
/// opens the board. An upcoming or current trip with no slots offers to set
/// them up; a past trip with none shows nothing.
class TripCylindersCard extends ConsumerWidget {
  final Trip trip;

  const TripCylindersCard({super.key, required this.trip});

  /// The most of the window the card may take before it scrolls, below the
  /// scrubber card's share so both fit above the story on a phone.
  static const maxHeightFraction = 0.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states =
        ref.watch(tripCylinderStatesProvider(trip.id)).value ??
        const <TripCylinderState>[];
    if (states.isEmpty && !trip.isUpcoming) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    void open() => context.push('/trips/${trip.id}/cylinders');

    final List<Widget> content;
    if (states.isEmpty) {
      content = [
        Text(l10n.trips_cylinders_setUpHint, style: theme.textTheme.bodyMedium),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('cylinders-set-up'),
            onPressed: open,
            child: Text(l10n.trips_cylinders_setUp),
          ),
        ),
      ];
    } else {
      final counts = tripCylinderCounts(states);
      final summary = l10n.trips_cylinders_summary(
        counts.full,
        counts.partial,
        counts.empty,
      );
      content = [
        Text(
          counts.unknown == 0
              ? summary
              : '$summary · '
                    '${l10n.trips_cylinders_summaryUnfilled(counts.unknown)}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in states)
              Chip(
                key: Key('cylinder-chip-${s.cylinder.id}'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: tripCylinderStatusColor(theme.colorScheme, s.status),
                  semanticLabel: tripCylinderStatusLabel(l10n, s.status),
                ),
                label: Text(
                  '${s.bottleLabel} · '
                  '${s.mix == null ? '--' : tripCylinderMixLabel(l10n, s.mix!)} · '
                  '${s.pressure == null ? '--' : units.formatPressure(s.pressure)}',
                ),
              ),
          ],
        ),
      ];
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('trip-cylinders-card'),
          onTap: open,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      MdiIcons.divingScubaTank,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.trips_cylinders_title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                ...content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

If the class in `mdi_icons.dart` is not named `MdiIcons`, use its real name (the file's line 20 declares `divingScubaTank`).

- [ ] **Step 4: Run the card tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/trip_cylinders_card_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Place the card in both layouts**

In `lib/features/trips/presentation/pages/trip_detail_page.dart` add the import after the scrubber card's:

```dart
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_card.dart';
```

and directly after each of the four `TripScrubberMarginCard(trip: trip),` lines (123, 137, 205, 219) add, at the same indentation:

```dart
TripCylindersCard(trip: trip),
```

Verify: `grep -c "TripCylindersCard(trip: trip)," lib/features/trips/presentation/pages/trip_detail_page.dart` prints `4`.

- [ ] **Step 6: Run the trip detail page tests**

Run: `flutter test test/features/trips/presentation/pages/trip_detail_page_test.dart`
Expected: PASS. If a test now fails because the card reached the database (no test database there) or because a new set-up card changed a count it asserts, add `tripCylinderStatesProvider('<that test's trip id>').overrideWith((ref) async => const [])` to that test's overrides; if it asserts a widget count the card legitimately adds, update the count and say why in a comment. Ledger each change.

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/presentation/widgets/trip_cylinders_card.dart lib/features/trips/presentation/pages/trip_detail_page.dart test/features/trips/presentation/widgets/trip_cylinders_card_test.dart test/features/trips/presentation/pages/trip_detail_page_test.dart
git commit -m "feat(trips): the cylinders card in the trip story (#2325)"
```

---

### Task 10: The ledger segment

**Files:**
- Modify: `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`
- Create: `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart`
- Modify: `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart` (the page becomes stateful for the segment)
- Test: `test/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart`
- Test: `test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`

**Interfaces:**
- Consumes: `TripCylinderRepository.getEventsForTrip` and `deleteEvent`; Tasks 2, 6, 7, 8.
- Produces: `tripCylinderLedgerProvider` (`FutureProvider.family<List<TripCylinderEvent>, String>`, newest first, ties broken by id descending); `class TripCylinderLedgerView extends ConsumerWidget` with `({super.key, required String tripId, required List<TripCylinderState> states, required Map<String, String> centerNames})`. Keys: `ledger-<eventId>`, `ledger-delete-<eventId>`, `board-segment`.

- [ ] **Step 1: Write the failing provider test**

Append inside `main()` of `test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`:

```dart
  test('the ledger lists every event on the trip, newest first', () async {
    final a = await slot('A');
    final b = await slot('B', sortOrder: 1);
    await repository.createEvent(
      TripCylinderEvent(
        id: 'e-old',
        tripCylinderId: a.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: at,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await repository.createEvent(
      TripCylinderEvent(
        id: 'e-new',
        tripCylinderId: b.id,
        kind: TripCylinderEventKind.adjustment,
        occurredAt: at.add(const Duration(hours: 3)),
        pressure: 0,
        createdAt: at,
        updatedAt: at,
      ),
    );

    final ledger = await container.read(
      tripCylinderLedgerProvider(tripId).future,
    );
    expect(ledger.map((e) => e.id), ['e-new', 'e-old']);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: FAIL to compile: `tripCylinderLedgerProvider` is not defined.

- [ ] **Step 3: Add the ledger provider**

In `lib/features/trips/presentation/providers/trip_cylinder_providers.dart` add the import `import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';` and append:

```dart

/// Every fill and adjustment on a trip, newest first (ties by id, newest
/// id first, so the order never depends on the query), for the ledger.
final tripCylinderLedgerProvider =
    FutureProvider.family<List<TripCylinderEvent>, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
      final bySlot = await repository.getEventsForTrip(tripId);
      final events = [for (final list in bySlot.values) ...list]
        ..sort((a, b) {
          final byTime = b.occurredAt.compareTo(a.occurredAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });
      return events;
    });
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing ledger view tests**

Create `test/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/pages/trip_cylinder_board_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late String tripId;
  late TripCylinder slot;
  final at = DateTime.utc(2026, 3, 9, 8);
  const units = UnitFormatter(AppSettings(defaultCurrency: 'EUR'));

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    slot = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<TripCylinderEvent> event(
    String id,
    TripCylinderEventKind kind, {
    required int hour,
    double? pressure,
    double? o2,
    double? cost,
  }) => repo.createEvent(
    TripCylinderEvent(
      id: id,
      tripCylinderId: slot.id,
      kind: kind,
      occurredAt: DateTime.utc(2026, 3, 9, hour),
      pressure: pressure,
      o2Percent: o2,
      cost: cost,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> pumpLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) =>
                MockSettingsNotifier(const AppSettings(defaultCurrency: 'EUR')),
          ),
          allDiveCentersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCylinderBoardPage(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty ledger says so', (tester) async {
    await pumpLedger(tester);
    expect(find.text('No fills or adjustments yet'), findsOneWidget);
  });

  testWidgets('lists events newest first with their details', (
    tester,
  ) async {
    await event(
      'e1',
      TripCylinderEventKind.fill,
      hour: 8,
      pressure: 200,
      o2: 32,
      cost: 12.5,
    );
    await event('e2', TripCylinderEventKind.adjustment, hour: 14, pressure: 0);
    await pumpLedger(tester);

    final newest = tester.getTopLeft(find.byKey(const Key('ledger-e2')));
    final oldest = tester.getTopLeft(find.byKey(const Key('ledger-e1')));
    expect(newest.dy, lessThan(oldest.dy));
    expect(
      find.textContaining(
        'EAN32 · ${units.formatPressure(200)} · ${formatMoney(12.5, 'EUR')}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Adjustment ·'), findsOneWidget);
  });

  testWidgets('deleting an entry asks first, then removes it', (
    tester,
  ) async {
    await event('e1', TripCylinderEventKind.fill, hour: 8, pressure: 200);
    await pumpLedger(tester);

    await tester.tap(find.byKey(const Key('ledger-delete-e1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ledger-e1')), findsNothing);
    expect(await repo.getEventsForCylinder(slot.id), isEmpty);
  });

  testWidgets('tapping a fill opens it for editing', (tester) async {
    await event('e1', TripCylinderEventKind.fill, hour: 8, pressure: 200);
    await pumpLedger(tester);

    await tester.tap(find.byKey(const Key('ledger-e1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit fill'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart`
Expected: FAIL: no "Ledger" segment exists on the board page yet.

- [ ] **Step 7: Write the ledger view**

Create `lib/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every fill and adjustment on the trip, newest first. Tapping one opens
/// it for editing; the bin deletes it after a confirmation.
class TripCylinderLedgerView extends ConsumerWidget {
  final String tripId;
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderLedgerView({
    super.key,
    required this.tripId,
    required this.states,
    required this.centerNames,
  });

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripCylinderEvent event,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.trips_cylinders_deleteEventConfirm),
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
    if (confirmed != true || !context.mounted) return;
    await ref.read(tripCylinderRepositoryProvider).deleteEvent(event.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final fallbackCurrency = ref.watch(defaultCurrencyProvider);
    final events =
        ref.watch(tripCylinderLedgerProvider(tripId)).value ??
        const <TripCylinderEvent>[];
    if (events.isEmpty) {
      return Center(child: Text(l10n.trips_cylinders_ledgerEmpty));
    }
    final byId = {for (final s in states) s.cylinder.id: s};
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        final slot = byId[e.tripCylinderId];
        final isFill = e.kind == TripCylinderEventKind.fill;
        final kind = isFill
            ? l10n.trips_cylinders_kind_fill
            : l10n.trips_cylinders_kind_adjustment;
        final when = units.formatDateTime(e.occurredAt, l10n: l10n);
        final mix = e.effectiveMix;
        final details = [
          if (mix != null) tripCylinderMixLabel(l10n, mix),
          if (e.pressure != null) units.formatPressure(e.pressure),
          if (e.bottleLabel case final bottle?)
            l10n.trips_cylinders_bottle(bottle),
          if (centerNames[e.diveCenterId] case final center?) center,
          if (e.cost case final cost?)
            formatMoney(cost, e.currency ?? fallbackCurrency),
          if (e.isPackage) l10n.trips_cylinders_fill_package,
        ].join(' · ');
        return ListTile(
          key: Key('ledger-${e.id}'),
          title: Text(slot?.cylinder.label ?? ''),
          subtitle: Text(
            details.isEmpty ? '$kind · $when' : '$kind · $when\n$details',
          ),
          isThreeLine: details.isNotEmpty,
          onTap: slot == null
              ? null
              : () => isFill
                    ? showTripCylinderFillSheet(
                        context,
                        slots: states,
                        editing: e,
                      )
                    : showTripCylinderAdjustSheet(
                        context,
                        cylinder: slot.cylinder,
                        editing: e,
                      ),
          trailing: IconButton(
            key: Key('ledger-delete-${e.id}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.common_action_delete,
            onPressed: () => _confirmDelete(context, ref, e),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 8: Put the segment on the board page**

Replace `lib/features/trips/presentation/pages/trip_cylinder_board_page.dart` with the stateful version (the helper `reorderedIds` and `TripCylinderBoardList` are unchanged; they are repeated here so the file is whole):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_slot_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [ids] with the one at [oldIndex] moved to [newIndex], the index
/// ReorderableListView's onReorderItem reports (already adjusted for the
/// removal).
List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  final moved = next.removeAt(oldIndex);
  next.insert(newIndex, moved);
  return next;
}

/// The trip's cylinder board: every slot with its state (reorderable) or
/// the ledger of every fill and adjustment, with actions to add slots and
/// to fill several at once.
class TripCylinderBoardPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripCylinderBoardPage({super.key, required this.tripId});

  @override
  ConsumerState<TripCylinderBoardPage> createState() =>
      _TripCylinderBoardPageState();
}

class _TripCylinderBoardPageState extends ConsumerState<TripCylinderBoardPage> {
  bool _showLedger = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripId = widget.tripId;
    final statesAsync = ref.watch(tripCylinderStatesProvider(tripId));
    final states = statesAsync.value ?? const <TripCylinderState>[];
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerNames = {for (final c in centers) c.id: c.name};

    final Widget body;
    if (!statesAsync.hasValue && statesAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!statesAsync.hasValue && statesAsync.hasError) {
      body = Center(child: Text(l10n.common_label_error));
    } else if (states.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.trips_cylinders_boardEmpty),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.trips_cylinders_action_add),
              onPressed: () => showAddTripCylindersSheet(
                context,
                tripId: tripId,
                existing: const [],
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              key: const Key('board-segment'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.trips_cylinders_segment_board),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.trips_cylinders_segment_ledger),
                ),
              ],
              selected: {_showLedger},
              onSelectionChanged: (s) => setState(() => _showLedger = s.first),
            ),
          ),
          Expanded(
            child: _showLedger
                ? TripCylinderLedgerView(
                    tripId: tripId,
                    states: states,
                    centerNames: centerNames,
                  )
                : TripCylinderBoardList(
                    states: states,
                    centerNames: centerNames,
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trips_cylinders_title),
        actions: [
          IconButton(
            key: const Key('board-fill-several'),
            tooltip: l10n.trips_cylinders_action_fillSeveral,
            icon: const Icon(Icons.local_gas_station_outlined),
            onPressed: states.isEmpty
                ? null
                : () => showTripCylinderFillSheet(
                    context,
                    slots: states,
                    several: true,
                    preselected: {
                      for (final s in states)
                        if (s.status != TripCylinderStatus.full) s.cylinder.id,
                    },
                  ),
          ),
          IconButton(
            key: const Key('board-add'),
            tooltip: l10n.trips_cylinders_action_add,
            icon: const Icon(Icons.add),
            onPressed: () => showAddTripCylindersSheet(
              context,
              tripId: tripId,
              existing: [for (final s in states) s.cylinder],
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// The reorderable list of slot cards. Dragging a card writes the new board
/// order through the repository; the list redraws from the provider.
class TripCylinderBoardList extends ConsumerWidget {
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderBoardList({
    super.key,
    required this.states,
    required this.centerNames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: states.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final s in states) s.cylinder.id];
        ref
            .read(tripCylinderRepositoryProvider)
            .reorderCylinders(reorderedIds(ids, oldIndex, newIndex));
      },
      itemBuilder: (context, i) => TripCylinderSlotCard(
        key: ValueKey(states[i].cylinder.id),
        state: states[i],
        allStates: states,
        centerNames: centerNames,
      ),
    );
  }
}
```

The ledger segment only appears once the trip has slots: an event always belongs to a slot, so an empty board has no ledger to show.

- [ ] **Step 9: Run the ledger, board and provider tests**

Run: `flutter test test/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart test/features/trips/presentation/pages/trip_cylinder_board_page_test.dart test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: PASS. The first ledger test ("an empty ledger says so") needs the segment, which only appears with slots; the setup creates one slot, so it holds.

- [ ] **Step 10: Run the architecture guards**

Run: `flutter test test/architecture`
Expected: PASS. `provider_change_tick_test` accepts the ledger provider because it calls `ref.invalidateSelfWhen`.

- [ ] **Step 11: Format, analyze and commit**

```bash
dart format .
dart analyze --fatal-infos lib/features/trips test/features/trips
git add lib/features/trips/presentation/providers/trip_cylinder_providers.dart lib/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view.dart lib/features/trips/presentation/pages/trip_cylinder_board_page.dart test/features/trips/presentation/widgets/cylinders/trip_cylinder_ledger_view_test.dart test/features/trips/presentation/providers/trip_cylinder_providers_test.dart
git commit -m "feat(trips): the trip cylinder ledger (#2325)"
```

---

### Task 11: Whole-branch verification and the pull request

**Files:** none new.

- [ ] **Step 1: Analyze and check the generated localizations**

Run:
```bash
dart format .
flutter analyze --fatal-infos
flutter gen-l10n
git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'
```
Expected: `No issues found!`, and the last command prints nothing (the committed generated files match the ARB files).

- [ ] **Step 2: Run the affected suites, one at a time**

```bash
flutter test test/features/trips
flutter test test/l10n
flutter test test/architecture
flutter test test/core/services/sync
```
Expected: each ends `All tests passed!`.

- [ ] **Step 3: Run the full suite once, alone**

Run `flutter test` with nothing else testing in this worktree (a pre-push hook or a sibling run in the same worktree deletes the native SQLite library mid-run and fails unrelated repository tests). Expected: `All tests passed!`. A failure in a file this branch never touched: check `origin/main` first.

- [ ] **Step 4: Scan the branch for forbidden text**

```bash
git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|\x{2013})"
```
Expected: no output. Then scan the same diff for the two tool-attribution terms the contributor guide's Attribution section forbids; expected: no output.

- [ ] **Step 5: Push and open the pull request, only when the user asks**

Pushing and opening a PR are outward actions; wait for the user's go-ahead. Then push with `-u`, and create the PR in one Bash call with `unset GITHUB_TOKEN; gh pr create --repo submersion-app/submersion --base main ...` and a body whose first line is `Part of #2325`, summarizing: the story card, the board page and route, the four sheets, the ledger, the strings in all 11 locales, and the two PR 1 review follow-ups (the board counts only the trip's own dives; the fold breaks every tie deterministically). Bind the PR in the desktop app and read CI through it; never poll.
