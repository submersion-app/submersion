# Unified Editing, Plan 5: Tanks, Equipment and Weights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive page's Cylinders (`tanks`), Equipment and Weights cards editable in place: dive mode and the rebreather settings, cylinders, apply configuration, trip slots, gas switches and the pressure series reassign on Tanks; gear, sets, scan and the location suggestion on Equipment; weights, presets and weighting feedback on Weights; with every rule that crosses these cards (issue #4527).

**Architecture:** Plans 1 to 4 gave the page an `EditSession<Dive>`, a `RecordEditController<Dive>`, field bindings, held writes and changes, notes and tracked work. Tanks, gear and weights are already columns or child rows that `updateDive` writes from the `Dive` (`dive_repository_impl.dart:2949-3109`), so each becomes one list field. Gas switches and the series reassign are not part of the `Dive`: they are held changes of the Tanks card, run after the dive is written in the same transaction. The dive form's validators do not run outside its `Form`, so the shared layer gains card checks over the sitting and a wrapper that reports the reused widgets' validators. The rules that cross cards (a set brings gear, weights and cylinders; a trip change relinks slots; a site picks a set; the dive center's last dive replaces weights and tanks) are functions of the sitting, called by the card that starts them. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read the Cards table, "Rules that span cards", "What is held, and what is not" and "What a locked dive page no longer shows". Plan 4 is `docs/design/plans/2026-11-15-unified-editing-4-header.md`; its "After the review" and "For plans 5 to 8" sections, and plan 3's "For plans 4 and 5", list what this plan picks up. This plan uses the names as built.

## What each card owns, shows and leaves alone

### Tanks (`DiveDetailSectionId.tanks`, card id `'tanks'`, title "Cylinders")

| Value | Field | Today's form |
| --- | --- | --- |
| Dive mode | `diveModeField`, `DiveMode`, `alsoShownOn: {'details', 'header'}` | `DiveModeSelector`, `dive_edit_page.dart:3967` |
| Setpoints low, high, deco | `diveSetpointLowField`, `diveSetpointHighField`, `diveSetpointDecoField`, `double?` bar | `CcrSettingsPanel` |
| Diluent (CCR) or supply gas (SCR) | `diveDiluentGasField`, `GasMix?` | both panels; SCR reads and writes `diluentGas` (`:1233`) |
| Scrubber | `diveScrubberField`, `ScrubberInfo?`; no type is no scrubber | both panels |
| Loop volume | `diveLoopVolumeField`, `double?` litres | `CcrSettingsPanel` |
| SCR type, injection rate, addition ratio, orifice, assumed VO2, loop O2 min, max, average | `diveScrTypeField`, `diveScrInjectionRateField`, `diveScrAdditionRatioField`, `diveScrOrificeSizeField`, `diveAssumedVo2Field`, `diveLoopO2MinField`, `diveLoopO2MaxField`, `diveLoopO2AvgField` | `ScrSettingsPanel` |
| Cylinders | `diveTanksField`, `List<DiveTank>`, compared in order with `listEquals` | `TankRow` per tank (`P:3993-4043`) |

Held as changes of this card, not fields: the gas switch list (Task 5) and the pressure series exchanges (Task 6).

### Equipment (`'equipment'`)

| Value | Field | Today's form |
| --- | --- | --- |
| Gear, with where each item came from | `diveGearField`, `List<GearLink>`, compared as a set of `(item.id, viaEquipmentId, viaSetId)` | `_selectedEquipment` and `_gearProvenance` (`P:438`, `:442`) |

The order of the list carries no meaning: `_writeGearDiff` keys by equipment id, and the read card arranges by the diver's global arrangement. An item's own details changing elsewhere is not a change of the dive.

### Weights (`'weights'`, title "Weight")

| Value | Field | Today's form |
| --- | --- | --- |
| Weights | `diveWeightsField`, `List<DiveWeight>`, compared ignoring order | `_weights` (`P:500`), `DiveWeightEntryRow` |
| Weighting feedback | `diveWeightingFeedbackField`, `WeightingFeedback?` | `SegmentedButton` (`P:6014`) |
| Feedback amount | `diveWeightingFeedbackKgField`, `double?` kg | `P:6059` |

A dive stored with the legacy single weight (`weightAmount`, `weightType`) and no rows reads as one row with an empty id, so opening the card changes nothing. Writing a list clears the two legacy columns, as the form's every save does (census exemption, `dive_edit_save_field_census_test.dart:26`).

### Shown, owned elsewhere

| Row | Where | What this plan does |
| --- | --- | --- |
| Dive mode | Details editor, header editor and hero badge | `alsoShownOn` redraws them (Task 3) |
| Air consumption, SAC segments, Buoyancy | Calculated from the stored dive (plan 4, Task 11) | Pairs draw the stored dive beside the editable half (Task 12) |
| The volume hint under air consumption, and on SAC segments | Details read card, SAC segments card | During a sitting it opens the Tanks card (Task 13) |

## Rules that cross these cards

| Change | Effect | Built in |
| --- | --- | --- |
| Dive mode | Gauge hides cylinders and gas switches (kept, not removed); entering CCR fills empty setpoints from settings; leaving CCR takes back what entering it filled; at Save, a sitting that changed the mode drops the rebreather values that do not fit it | Task 3 |
| Cylinders | A switch whose cylinder is gone goes with it, and the editor says how many | Task 5 |
| Bottom time, runtime, exit | Bound gas switch times, read from the sitting | Task 5 |
| Planned switch (header) | Hides gas switches | Task 5 |
| Trip (Details) | Clears every slot link and suggests slots again | Tasks 4 and 13 |
| A tank added | Gets a slot suggestion | Task 4 |
| Own cylinder scanned or picked on a tank row | Joins the dive's gear (Equipment gets its dot) | Task 9 |
| A set used | Its gear, its weights (with the add, replace or keep question) and its cylinders (with the overwrite question) | Task 9 |
| Site (header) | Re-checks location sets: with no gear, applies the best set; otherwise suggests the matching one | Task 10 |
| Dive center (Details) | "Last time at" card; applying it replaces weights and cylinders, asking first when either has any | Task 13 |

Each value set by a rule goes through its own field, so the owning card gets its dot and a closed card is redrawn.

## Where these cards differ from today's form, and why

1. **Rebreather values are dropped only when the sitting changed the mode.** The form drops values that do not fit the mode on every save (`P:6743-6768`). Here a dive stored as open circuit with leftover setpoints keeps them unless the diver changes its mode. Why: a value the diver did not change is never written.
2. **A CCR seed is taken back.** Entering CCR fills empty setpoints; leaving CCR in the same sitting gives back the stored ones, so OC, CCR, OC is no change. The form keeps the seeds until Save drops them.
3. **The series reassign is held.** On the read card it writes at once with an Undo snackbar (`tank_series_reassign_sheet.dart:37`). Here it is in the Tanks editor: the cylinders' start and end pressures and transmitter serials swap in the sitting at once, and the recorded readings move at Save. Why: the spec holds it until Save.
4. **Gas switch times are checked over the whole sitting.** A runtime shortened on the header can put a switch past the end of the dive while the Tanks card is closed. Save refuses, opens Tanks and shows the row's error, as the form's validator does for an open form.
5. **The location set follows the site, and is taken back.** A set the site applied to a dive with no gear is taken back (gear, weights and cylinders it set) when another site is picked, unless the diver changed them since: plan 4's rule for every site value. The form keeps it.
6. **The location suggestion waits for the editors to close.** On the closed Equipment card it appears only when no editor is open, as a card that gains something does, so it cannot push an open editor down.
7. **A trip change relinks slots in the sitting.** Plan 3 left the link to the writer's drop at Save; the cylinders now show the change before Save.
8. **The weighting feedback amount follows the feedback.** Correct or none clears it; over or under gives back the stored amount when the sitting has none. The form hides the field and drops its text at Save.
9. **One order.** The form puts mode, cylinders, gas switches and gear in one section (`GasGearSection`) and weights in another. Here each card holds its own, in the order its read card shows.

## Not in this plan

- The new dive, its starter set (Tanks is in it), the default tank and the default set for a new dive: plan 8. `newSittingTank` (Task 4) is what plan 8 seeds the starter tank with.
- The fade and "Calculated" label of SAC segments and Buoyancy.
- Logging the reassign in History: `tank_pressure_series` logs deletes only (`change_log_policy.dart:154`), so the exchanged readings are not in the sitting's History entry until plan 9 extends the policy. The cylinders' swapped columns are.
- Bulk edit. It keeps the form's own builders (`_bulkTanksEditor`, `_buildBulkRebreatherSection`, `_weightChild`); nothing it uses moves.
- The embedded list pane, which offers no editing yet.

## The form's own tests

The form and its tests stay until the last plan deletes the form. These cover what the three cards now own; read each at the start of the task named, and add to that task's tests any behaviour it pins that the list there does not.

| Form test (`test/features/dive_log/presentation/pages/`) | Replaced in |
| --- | --- |
| `dive_edit_ccr_setpoint_seed_test.dart`, `dive_edit_page_coverage_test.dart` (the CCR panel) | Tasks 3 and 7 |
| `dive_edit_trip_cylinder_test.dart` | Tasks 4 and 13 |
| `dive_edit_apply_cylinder_config_test.dart`, `dive_edit_tanks_vs_equipment_test.dart` | Tasks 4 and 7 |
| `dive_edit_gas_switches_test.dart`, `dive_edit_gas_switches_suit_test.dart`, `dive_edit_detected_gas_switches_test.dart` | Tasks 5 and 7 |
| `dive_edit_preserves_sac_widget_test.dart` | Task 14 |
| `dive_edit_scan_gear_test.dart`, `dive_edit_equipment_multi_select_test.dart`, `dive_edit_gear_tree_test.dart`, `dive_edit_shared_gear_note_test.dart`, `dive_edit_equipment_arrangement_test.dart`, `dive_edit_save_as_set_test.dart` | Tasks 9 and 11 |
| `dive_edit_set_bundle_test.dart` | Task 9 |
| `dive_edit_geofence_suggestion_test.dart` | Task 10 |
| `dive_edit_weight_feedback_test.dart`, `dive_edit_weight_preset_test.dart` | Task 8 |
| `dive_edit_rental_memory_test.dart`, `dive_edit_apply_last_dive_confirm_test.dart` | Task 13 |
| `dive_edit_equipment_default_test.dart`, `dive_edit_prefill_test.dart` | Plan 8 |
| `dive_edit_save_field_census_test.dart` | Unchanged; Task 1 adds no column |

## Calls made in this plan, for Eric to check

1. **Rebreather values are dropped at Save only when the sitting changed the mode** (difference 1).
2. **The pressure series reassign is held until Save**, as the spec says, with the pressures and serials swapping in the editor at once and the readings moving at Save. The read card's pressure lines and the profile follow at Save. Undo is Cancel, or the same exchange again.
3. **The gear check-in chip** (`ObservationStatusChip`, on Cylinders and Equipment rows) **shows state only on a locked page. During a sitting it opens the check-in sheet, which writes at once**: a check-in is a record of the gear's own, with photos and near-miss actions, like a buddy created from a picker. It survives Cancel. The alternative that keeps "Cancel means nothing happened" for it too is holding check-ins until Save, which means reworking a 621-line sheet; say if you want that instead.
4. **Rental gear notes** on the "Last time at" card (Details editor) **write at once** for the same reason: a note is the dive center's record. The card shows only during a sitting.
5. **"Assign transmitter"** on the Cylinders read card registers the serial and links it to this and other dives' cylinders (`registerTransmittersForDives`), which writes dive rows. **Locked, it is hidden. During a sitting it shows only while there are no unsaved changes, and acts at once**, as a whole-record operation does. Plan 7 gives it its menu caption.
6. **A site picked in a sitting applies the best location set to a dive with no gear**, as the form does, **and the next site takes it back** (difference 5).
7. **Sort on the Equipment card stays usable while locked**: it writes the diver's global arrangement, a display setting, never the dive.
8. **Gauge: the cylinders are kept, hidden, and Tanks is a chip in the strip**, as the spec says; its editor shows the mode selector alone. Saving a gauge dive keeps its cylinders, as the form does (`P:6665`).
9. **Weighting feedback stays off the read card**, as the spec says.
10. **A switch made out of range by another card stops Save** and opens Tanks (difference 4).
11. **One new string:** `diveLog_tank_reassignPending`, "The readings move to their new cylinders when you save." Card titles reuse the read cards' own (`diveLog_detail_section_cylinders`, `_equipment`, `_weight`).

## Global Constraints

- With `kUnlockEditing` false the dive page builds and behaves exactly as today.
- A card does not move on the page while its editor is open, whatever is typed or picked in it or in another card.
- Every value shown or typed follows the active diver's units (`unitFormatterProvider`): pressures, volumes, weights, depths. The session holds canonical values: bar, litres, kilograms, metres, seconds.
- A value the diver did not change is never written. Opening each card, tapping into every field (every tank row expanded, each panel field, each weight row) and closing it leaves the sitting clean, in metric and imperial.
- Typed numbers are read only through `readNumber`; the architecture guard forbids `tryParse` in presentation code.
- A text field that shows a value of the sitting gets it through `FieldTextBinding` or `replaceTextKeepingCaret`, never by assigning `text`. The reused widgets (`TankRow`, `DiveWeightEntryRow`, the panels, `GasSwitchesEditor`) keep their own controllers and are rebuilt with a new key when the sitting replaces their value from outside (a set, a configuration, a rental apply), as the form bumps `_tankRowGeneration`.
- Anything that writes to a sitting after an `await` (a picker, a dialog, a provider read, a scan) checks `mounted` where it has one, then `session.isDisposed` and `session.isFrozen`, and drops its result when the input it was asked about changed meanwhile. It reads what it needs from `ref` and `context` before the first `await`. Work a save must wait for (a tank scan, a slot suggestion, the site's set) is `session.track`ed.
- Any refresh or schedule after `service.save` returns is in a `try` of its own (`DiveSittingFollowUp._guarded`).
- `session.set(field, 10)` with a whole-number literal on a `double?` field fails at run time: tests spell `10.0`. Type list literals (`<DiveTank>[]`).
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 782 and `dive_edit_page.dart` is not to grow. New page code goes in `dive_detail_page_editing.dart` or a file of its own (a part file cannot import).
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects one (call 11).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`. Build repositories in `setUp`. `getBaseOverrides` already overrides shared preferences: set a preference after calling it.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **The mode changed and changed back.** OC, CCR, OC leaves the sitting clean; CCR to OC saved drops setpoints, diluent, scrubber and loop volume; to gauge and back keeps every cylinder and switch; an OC dive stored with setpoints, saved for its notes, keeps them. Pinned in Task 3.
2. **A cylinder removed under held work.** A switch pointing at it, and a held exchange naming it: Save writes neither against the gone row and does not fail on its foreign key. Pinned in Tasks 5, 6 and 14.
3. **A closed card made invalid by another.** The header's runtime shortened past a switch: Save refuses, Tanks opens and scrolls in with the row's error; fixing the time lets Save through. Unreadable O2 typed in an open tank row refuses Done and Save. Pinned in Tasks 2, 5 and 14.
4. **One action, three cards.** A set used, the last dive at a center applied, a site's location set: each card it touched gets its dot, Cancel undoes all of it, and Save is one History entry naming every card. Pinned in Tasks 9, 10, 13 and 14.
5. **Nothing writes on a locked page.** Reassign absent; check-in chips show state and do not open; Assign transmitter absent; Sort still opens its sheet. Pinned in Tasks 12 and 14.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 4 merged; head at or after `f856d24c669`).
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes: the Cylinders, Equipment and Weights read cards locked, light and dark, phone and desktop width, a CCR dive and a dive with gas switches, and the cards beside SAC segments and Buoyancy at desktop width.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `record_card_form.dart` | `RecordCardForm`: a `Form` around reused fields that carry their own validators, reporting to the controller |

New, dive (`lib/features/dive_log/presentation/widgets/dive_detail/editing/`):

| File | Responsibility |
| --- | --- |
| `dive_tanks_fields.dart` | The Tanks fields, `setDiveMode`, `fitRebreatherToMode`, `diveSittingApply` |
| `dive_tank_rules.dart` | `setTanks`, `newSittingTank`, `applyCylinderConfigInSitting`, the slot suggestion rules |
| `dive_gas_switch_sitting.dart` | Gas switches held in a sitting: load, edit, drop, limits, check |
| `dive_tank_series_exchange.dart` | The held reassign |
| `dive_tanks_card_editor.dart` | `DiveTanksCardEditor` |
| `dive_equipment_fields.dart` | `diveGearField`, `addGearToSitting`, the remove rules |
| `dive_set_use.dart` | `useSetInSitting`: a set's gear, weights and cylinders |
| `dive_gear_geofence.dart` | The site's location set and suggestion |
| `dive_equipment_card_editor.dart` | `DiveEquipmentCardEditor` |
| `dive_weights_fields.dart` | The Weights fields, `setWeightingFeedback`, `applyWeightPresetInSitting`, `applyLastDiveInSitting` |
| `dive_weights_card_editor.dart` | `DiveWeightsCardEditor` |

Modified: `dive.dart`, `edit_card.dart`, `record_edit_controller.dart`, `tank_pressure_repository.dart`, `rental_memory_resolver.dart` (gains `applyLastDiveNeedsConfirm`, moved from `dive_edit_page.dart:280`), `dive_edit_page.dart` (that import only), `dive_edit_cards.dart`, `dive_card_presence.dart`, `dive_detail_section_list.dart`, `cylinders_card.dart`, `tank_series_reassign_sheet.dart`, `dive_detail_equipment_section.dart`, `dive_detail_weight_section.dart`, `observation_status_chip.dart`, `dive_details_derived_rows.dart`, `dive_detail_sac_segments_section.dart`, `dive_details_trip_rows.dart`, `dive_details_card_editor.dart`, `dive_site_row.dart`, `dive_detail_page_editing.dart`, `dive_sitting_follow_up.dart`, the harness, the 11 ARB files.

---

### Task 1: `Dive.copyWith` can clear the values these cards edit

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`copyWith`, from line 842)
- Test: `test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart` (exists)

**Interfaces:**
- Produces: seventeen `bool` parameters on `Dive.copyWith`, each defaulting to false: `clearSetpointLow`, `clearSetpointHigh`, `clearSetpointDeco`, `clearScrType`, `clearScrInjectionRate`, `clearScrAdditionRatio`, `clearScrOrificeSize`, `clearAssumedVo2`, `clearLoopO2Min`, `clearLoopO2Max`, `clearLoopO2Avg`, `clearLoopVolume`, `clearScrubber`, `clearWeightingFeedback`, `clearWeightingFeedbackKg`, `clearWeightAmount`, `clearWeightType`. Each follows the existing form. `clearSetpoints` and `clearDiluentGas` stay as they are.

- [ ] **Step 1: Write the failing tests**

Add the seventeen to the file's `cases` table (one line each, a non-null value for each in `full`), so each is checked to clear itself and nothing else. Then:

```dart
test('clearSetpoints still clears low and high and leaves deco', () {
  final d = full.copyWith(clearSetpoints: true);
  expect((d.setpointLow, d.setpointHigh, d.setpointDeco), (null, null, full.setpointDeco));
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add the flags and their bodies**

- [ ] **Step 4: Run it and confirm it passes**

Run: the same command, then `flutter test test/features/dive_log/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart
git commit -m "feat(dive-log): let copyWith clear a dive's rebreather settings, weighting feedback and legacy weight"
```

---

### Task 2: A card's own check stops Save; reused form fields report their validators

The reused widgets validate inside a `Form` (`TankEditor._validateGasPercent`, `DiveWeightEntryRow`'s `numberValidator`, `GasSwitchesEditor._timeError`). A card editor has no `Form`, and a closed card has no widgets at all.

**Files:**
- Modify: `lib/shared/widgets/record_editing/edit_card.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart` (`save`, `closeCard`)
- Create: `lib/shared/widgets/record_editing/record_card_form.dart`
- Test: `test/shared/widgets/record_editing/record_edit_controller_cards_test.dart`, `test/shared/widgets/record_editing/record_card_form_test.dart`

**Interfaces:**
- Consumes: `setFieldInvalid`, `refusedForInvalidInput`, `_requestReveal` (plan 2).
- Produces:

```dart
// EditCard gains
/// Whether the sitting's values for this card can be saved, asked of
/// every card at Save whether it is open or not. Null is always.
final bool Function(EditSession<T> session)? isValid;

// RecordEditController gains a constructor parameter
/// The cards whose [EditCard.isValid] fails for [session], in page order.
final List<String> Function(EditSession<T> session)? invalidCards;

// record_card_form.dart
/// A [Form] around fields that carry their own validators. It validates
/// once when first built and after every change, and reports the result
/// to the page's controller as field [fieldId] of [cardId], so Done and
/// Save refuse while any field shows an error, as for unreadable input.
/// Disposed, it withdraws its report.
class RecordCardForm<T> extends StatefulWidget {
  const RecordCardForm({super.key, required this.cardId, this.fieldId = 'form', required this.child});
}
```

  `save()`, after the unreadable-input check: when `invalidCards` returns any id, it sets `refusedForInvalidInput`, opens the first such card if closed, asks for its reveal and returns false. `closeCard(id)` refuses, as it does for unreadable input, when that card's `isValid` fails. The page passes `invalidCards: (s) => [for (final c in diveEditCards.values) if (c.isValid?.call(s) == false) c.id]` (Task 7 is the first card to give one).

- [ ] **Step 1: Write the failing tests**

```dart
// record_edit_controller_cards_test.dart
test('save refuses while a closed card is invalid, opens it and asks for its reveal', ...);
test('save goes through once the card is valid again', ...);
test('Done refuses for a card whose own check fails', ...);
test('with no invalidCards, save is as before', ...);

// record_card_form_test.dart
testWidgets('a field failing its validator marks the card invalid; fixing it clears it', ...);
testWidgets('a field already failing when built is reported at once', ...);
testWidgets('disposed, the form withdraws its report', ...);
testWidgets('no controller in scope: nothing is reported and nothing throws', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/record_edit_controller_cards_test.dart test/shared/widgets/record_editing/record_card_form_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

`RecordCardForm` reports from a post-frame callback after `FormState.validate()`, through `RecordEditScope.maybeOf<T>`. `closeCard(id)` asks `invalidCards` whether `id` is among them.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): a card's own check stops Save, and reused form fields report their validators"
```

---

### Task 3: The Tanks fields and the dive mode rule

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting` applies `diveSittingApply`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields_test.dart`

**Interfaces:**
- Consumes: the clear flags (Task 1); `remember`, `recall` (plan 4).
- Produces: the fourteen fields named in "Tanks" above, all `cardId: DiveDetailSectionId.tanks.name`, each null writing its clear flag, plus `diveTanksField`. Then:

```dart
/// Sets the dive mode. Entering CCR fills the low and high setpoints the
/// sitting has empty with [seedLow] and [seedHigh] (the diver's defaults,
/// issue #2802) and notes what it filled; leaving CCR sets back what that
/// filled, unless the diver changed it since.
void setDiveMode(EditSession<Dive> session, DiveMode mode, {required double seedLow, required double seedHigh});

/// [dive] with the rebreather values its mode does not use cleared, as the
/// form's save does (`dive_edit_page.dart:6743`): setpoints and loop volume
/// for CCR only; diluent for CCR and SCR; scrubber for CCR and SCR; the SCR
/// values for SCR only.
Dive fitRebreatherToMode(Dive dive);

/// What Save applies to the dive as stored: the sitting's changes, then,
/// when the sitting changed the dive mode, [fitRebreatherToMode].
Dive diveSittingApply(EditSession<Dive> session, Dive stored);
```

  `_saveSitting` passes `apply: (stored) => diveSittingApply(session, stored)` in place of `session.applyTo`.

- [ ] **Step 1: Write the failing tests**

```dart
test('every field belongs to the tanks card, and ids are unique', ...);
test('the mode is also shown on details and the header', () {
  expect(diveModeField.alsoShownOn, {'details', 'header'});
});
test('no scrubber type is no scrubber', ...);
test('cylinders in another order are a change', ...);
group('setDiveMode', () {
  test('entering CCR fills empty setpoints only', ...);
  test('OC, CCR, OC leaves the sitting clean', ...);
  test('a seeded setpoint the diver changed is kept on leaving CCR', ...);
  test('to gauge and back keeps every cylinder', ...);
});
group('at Save', () {
  test('CCR to OC drops setpoints, diluent, scrubber and loop volume', ...);
  test('SCR to CCR drops the SCR values and keeps the gas as diluent', ...);
  test('a stored OC dive with setpoints, saved for another card, keeps them', ...);
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the fields, the rule and the save hook**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields_test.dart
git commit -m "feat(dive-log): dive mode and rebreather settings as fields of the sitting"
```

---

### Task 4: Cylinders in the sitting: add, remove, configurations and trip slots

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules_test.dart`

**Interfaces:**
- Consumes: `diveTanksField` (Task 3); `DiveTankConfigAdapter` (`cylinder_configs/domain/services/dive_tank_config_adapter.dart:17`); `suggestTripCylindersForTanks`, `tankFromTripCylinder` (`trip_cylinder_tank_link.dart`); `TankPresetEntity`.
- Produces:

```dart
/// Sets the cylinders, renumbering `order`. Switches whose cylinder is gone
/// are dropped with them ([dropGasSwitchesWithoutTank], Task 5).
void setTanks(EditSession<Dive> session, List<DiveTank> tanks);

/// A cylinder to add after [tanks], as the form's `_addTank` builds it
/// (`dive_edit_page.dart:4427`): [preset]'s size, or the settings volume;
/// the settings start pressure, end 50 bar, air, back gas when first and
/// stage after. A fresh id.
DiveTank newSittingTank({required List<DiveTank> tanks, required TankPresetEntity? preset, required double defaultVolume, required double defaultStartPressure});

/// The cylinders [config] gives the sitting, or null when it changes
/// nothing; [overwrite] as the form's confirm decides.
List<DiveTank>? cylindersFromConfig(List<DiveTank> tanks, List<CylinderConfigItem> items, {bool overwrite = false});

/// Suggests a trip slot for each cylinder added in this sitting that has
/// none and whose suggestion the diver has not declined. [readSlots] is
/// read for the sitting's trip and entry; the result is dropped when
/// either changed meanwhile. Tracked.
void suggestTankSlots(EditSession<Dive> session, {required Future<List<TripCylinderState>> Function(String tripId, DateTime at) readSlots});

/// The diver chose a slot on [tankId], or None: it is theirs, and a None
/// is not overruled by the next suggestion.
void tankSlotChosen(EditSession<Dive> session, String tankId, {required bool none});

/// After the trip changed: every slot link cleared, the notes of suggested
/// and declined cylinders reset, then [suggestTankSlots].
void tanksAfterTripChange(EditSession<Dive> session, {required Future<List<TripCylinderState>> Function(String tripId, DateTime at) readSlots});

/// Which cylinders carry a suggested link, for `TankRow.suggested`.
Set<String> suggestedTankIds(EditSession<Dive> session);
```

  A cylinder counts as added in this sitting when its id is not among `session.stored.tanks`. Suggested and declined ids are notes of the sitting.

- [ ] **Step 1: Write the failing tests**

```dart
test('a new cylinder is back gas when first, stage after, sized by the preset', ...);
test('removing a cylinder renumbers the rest', ...);
test('a configuration replaces the list; one that changes nothing gives null', ...);
test('an added cylinder on a trip is suggested a slot; a stored one is not', ...);
test('a declined suggestion is not made again', ...);
test('a trip change clears every link and suggests again', ...);
test('slots answering after the trip changed again are dropped', ...);
test('clearing the trip clears the links and suggests nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules_test.dart
git commit -m "feat(dive-log): cylinders in a sitting, with configurations and trip slots"
```

---

### Task 5: Gas switches held in a sitting

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting_test.dart`

**Interfaces:**
- Consumes: `holdChange`, `releaseWrite`, `remember`, `recall`, `firstTime`, `track` (plan 4); `diveRuntimeField`, `diveBottomTimeField`, `diveExitField`, `diveEntryField` (plan 4); `gasSwitchesEditable`, `GasSwitch.shownInEditor`, `profileTimeDomain`, `profileDepthAt`, `newGasSwitchTank`, `startingTankOf`, `detectedGasSwitchEdits` (the helpers `dive_edit_page_gas_switches.dart` uses); `DiverGasSwitchWriter`.
- Produces:

```dart
const String gasSwitchesKey = 'gasSwitches';   // the note and the held change

/// What the sitting holds for the gas switches once they are loaded.
@immutable
class SittingGasSwitches {
  final List<GasSwitch> loaded;      // in time order, as read
  final List<GasSwitch> current;
  final int floor;                   // the earliest loaded time, or 0
  final Set<String> depthTouched;
  final int removedWithTank;         // the editor's notice; reset by the next edit
}

SittingGasSwitches? sittingGasSwitches(EditSession<Dive> session);

/// Reads the switches the primary computer shows (`shownInEditor`), once
/// per sitting, and keeps the write the edits below hold: through [writer],
/// with the loaded ids, reading the note's current list and keeping only
/// switches whose cylinder is on the working dive when it runs. Tracked.
void loadGasSwitches(EditSession<Dive> session, {required Future<List<GasSwitch>> Function() read, required DiverGasSwitchWriter writer});

/// Replaces the current list. Equal to what was loaded, the held change is
/// released; otherwise the kept write is held as a change of the tanks
/// card, to run after the dive is written. Does nothing before the load.
void setGasSwitches(EditSession<Dive> session, List<GasSwitch> next, {int removedWithTank = 0});

/// Called by [setTanks]: switches whose cylinder is gone are dropped and
/// counted. Does nothing before the switches are loaded: the database
/// removes them with their cylinder.
void dropGasSwitchesWithoutTank(EditSession<Dive> session);

/// The earliest and latest second a switch may fall on: the stored
/// profile's span, else the sitting's runtime, bottom time, or exit minus
/// entry (`_gasSwitchMaxTimestamp`, `dive_edit_page_gas_switches.dart:42`).
({int min, int? max}) gasSwitchTimeLimits(EditSession<Dive> session);

/// Whether the editor shows the switches: two breathing cylinders or more,
/// not gauge, not planned, all from the sitting.
bool gasSwitchesShown(EditSession<Dive> session);

/// False when a shown switch falls outside [gasSwitchTimeLimits], shares a
/// second with another, or names a cylinder not on the dive. The tanks
/// card's `isValid`.
bool gasSwitchesValid(EditSession<Dive> session);

/// The editor's changes, as `_onGasSwitchChanged`, `_addGasSwitch`,
/// `_removeGasSwitch`, `_fillDetectedGasSwitches` and
/// `_onGasSwitchTimeSettled` make them today; a time sets the depth from
/// the stored profile unless the diver typed one.
void changeGasSwitch(EditSession<Dive> session, GasSwitch updated, GasSwitchField field);
void addGasSwitch(EditSession<Dive> session);
void removeGasSwitch(EditSession<Dive> session, String id);
void fillDetectedGasSwitches(EditSession<Dive> session, GasSwitchEdits edits);
void gasSwitchTimeSettled(EditSession<Dive> session, String id);
```

  `setTanks` (Task 4) calls `dropGasSwitchesWithoutTank` after setting the field.

- [ ] **Step 1: Write the failing tests**

The writer is a real `DiverGasSwitchWriter` over the test database (`setUpTestDatabase`), with a dive, two cylinders and a switch inserted.

```dart
test('loaded once per sitting; another computer\'s switches are not shown', ...);
test('an edit holds a change of the tanks card; editing it back releases it', ...);
test('a time sets the depth from the profile; a typed depth is kept', ...);
test('a removed cylinder takes its switches and the notice counts them', ...);
test('the held write keeps only switches whose cylinder was written', () async {
  // setGasSwitches with one on tank B; setTanks without B; runHeldWrites: no row on B, no error.
});
test('limits: the profile span, else runtime, else bottom time, else exit minus entry', ...);
test('a runtime shortened past a switch makes the sitting invalid', ...);
test('a duplicate second is invalid; hidden switches are not checked', ...);
test('shown only with two breathing cylinders, not gauge, not planned', ...);
test('a read answering after Cancel sets nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/data/services/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): gas switches held in a sitting, checked against its times"
```

---

### Task 6: The pressure series reassign is held until Save

**Files:**
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` (`exchangeTankSources`, :324)
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart` (`onExchange` may be passed in)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (`_canReassign` becomes public `canReassignTankSeries`)
- Test: `test/features/dive_log/data/repositories/tank_pressure_repository_exchange_test.dart` (find the file that tests `exchangeTankSources` and add a group there, or create this one)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange_test.dart`

**Interfaces:**
- Produces:

```dart
// TankPressureRepository.exchangeTankSources gains
bool includePressures = true,   // false: start and end pressure stay with their rows

// dive_tank_series_exchange.dart
const String tankSeriesExchangeKey = 'tankSeriesExchange';

/// Exchanges what [tankIdA] and [tankIdB] recorded, in the sitting: their
/// start and end pressures, transmitter serials and source indexes swap on
/// the working cylinders at once (`diveTanksField`), and the readings are
/// held as a change of the tanks card, moved at Save by [exchange] with
/// `includePressures: false` (the pressures are written with the
/// cylinders). The same pair exchanged again cancels the last exchange. A
/// pair naming a cylinder no longer on the dive is skipped at Save.
void exchangeTankSeries(EditSession<Dive> session, String tankIdA, String tankIdB, {required Future<void> Function(String a, String b) exchange});

/// The exchanges held, oldest first.
List<(String, String)> heldTankSeriesExchanges(EditSession<Dive> session);

// showTankSeriesReassignSheet gains
Future<void> Function(String tankIdA, String tankIdB)? onExchange,   // null: as today, at once
```

- [ ] **Step 1: Write the failing tests**

```dart
// repository
test('includePressures false swaps serial, source index and readings, not pressures', ...);
test('the default is unchanged', ...);

// sitting
test('an exchange swaps pressures and serials on the working cylinders and holds a change', ...);
test('the same exchange again leaves the sitting clean', ...);
test('at Save the readings move and the pressures are the swapped ones, once', () async {
  // test database: updateDive(applyTo(stored)) then runHeldWrites; stored rows: pressures swapped once, series swapped.
});
test('a pair whose cylinder was removed is skipped', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/data_quality/ test/features/dive_log/presentation/widgets/cylinders_card_test.dart` (or the file that tests the card).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): a series reassign made in a sitting moves the readings at Save"
```

---

### Task 7: The Tanks card editor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart` (the `tanks` entry)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`invalidCards`; the gauge rule in `_addStripEntries`)
- Modify: the 11 ARB files (`diveLog_tank_reassignPending`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_test.dart`

**Interfaces:**
- Consumes: Tasks 2 to 6; `DiveModeSelector`, `CcrSettingsPanel`, `ScrSettingsPanel`, `TankRow`, `ApplyConfigurationMenu`, `confirmCylinderOverwrites`, `GasSwitchesEditor`, `showGasSwitchTimeSheet`, `showTankSeriesReassignSheet`, `ccrSetpointLowProvider`, `ccrSetpointHighProvider`, `tripCylinderStatesAtProvider`, `detectedGasSwitchesProvider`, `cylinderBreathStartsProvider`, `tankPressuresProvider`.
- Produces: `DiveTanksCardEditor({required EditSession<Dive> session})` and the `diveEditCards[DiveDetailSectionId.tanks]` entry:
  - title `diveLog_detail_section_cylinders`, leading the read card's icon;
  - `isEmpty: (d) => d.isGauge || d.tanks.isEmpty`;
  - `isValid: gasSwitchesValid`.

  The editor, top to bottom: the mode selector; for CCR or SCR the panel bound to the fields, keyed by a generation that moves when `setDiveMode` seeds; unless gauge, one `TankRow` per cylinder (remove offered while more than one, as the form), Add cylinder, apply configuration, the gas switches when `gasSwitchesShown`, and Reassign when `canReassignTankSeries` holds for the stored readings, followed by `diveLog_tank_reassignPending` while an exchange is held. Everything below the mode selector sits in one `RecordCardForm` (card `'tanks'`). A tank scan in flight is `session.track`ed. `TankRow.onOwnCylinderUsed` is left unset until Task 9 wires it.

  In `_addStripEntries`, Tanks is no longer left out for a gauge dive: its `isEmpty` puts it in the strip.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('opening a CCR dive\'s card and tapping every field leaves the sitting clean, metric and imperial', ...);
testWidgets('every cylinder row expanded and tapped leaves the sitting clean', ...);
testWidgets('a gauge dive shows the mode selector alone', ...);
testWidgets('picking CCR shows the panel with the seeded setpoints', ...);
testWidgets('add, change and remove a cylinder', ...);
testWidgets('remove is not offered for the only cylinder', ...);
testWidgets('a configuration that overwrites asks first; declining changes nothing', ...);
testWidgets('O2 that cannot be read refuses Done', ...);
testWidgets('a switch added, timed on the profile and saved', ...);
testWidgets('switches hidden for a planned dive and for one breathing cylinder', ...);
testWidgets('Reassign exchanges in the sitting and says the readings move at Save', ...);
testWidgets('a scan in flight delays Save until it lands', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add the string, then implement**

Add `diveLog_tank_reassignPending` to all 11 ARB files beside `diveLog_tank_reassignSeries`, then `flutter gen-l10n`.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/architecture/ test/shared/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_test.dart
git commit -m "feat(dive-log): edit a dive's mode, cylinders and gas switches on its Cylinders card"
```

---

### Task 8: Weights and weighting feedback

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart`
- Modify: `dive_edit_cards.dart` (the `weights` entry)
- Modify: `lib/features/dive_centers/domain/services/rental_memory_resolver.dart` (gains `applyLastDiveNeedsConfirm`); `dive_edit_page.dart` (imports it from there)
- Test: `dive_weights_fields_test.dart`, `dive_weights_card_test.dart` (in `test/.../editing/`)

**Interfaces:**
- Consumes: Task 1's flags; `DiveWeightEntryRow`, `WeightPresetPickerSheet`, `weightPresetRepositoryProvider.createFromWeights`, `NamePromptDialog`, `LastDiveAtCenter.weightsForNewDive`, `.tanksForNewDive`; `setTanks` (Task 4).
- Produces:

```dart
final EditField<Dive, List<DiveWeight>> diveWeightsField;          // 'weights'; read: rows, else the legacy weight as one row with id ''; write clears weightAmount and weightType
final EditField<Dive, WeightingFeedback?> diveWeightingFeedbackField;
final EditField<Dive, double?> diveWeightingFeedbackKgField;       // kg

/// Correct or none clears the amount; over or under gives back the stored
/// amount when the sitting has none.
void setWeightingFeedback(EditSession<Dive> session, WeightingFeedback? feedback);

void applyWeightPresetInSitting(EditSession<Dive> session, WeightPreset preset);

/// The center's last dive's weights and cylinders replace the sitting's
/// ([setTanks], so switches on a gone cylinder go too).
void applyLastDiveInSitting(EditSession<Dive> session, LastDiveAtCenter last);
```

  The editor: the total in the title row as the read card shows it, one `DiveWeightEntryRow` per weight inside a `RecordCardForm` (card `'weights'`), Add weight, Use preset, Save as preset (at once, as today), the feedback buttons and, for over or under, its amount as a `RecordNumberRow` in the diver's weight unit. The entry: title `diveLog_detail_section_weight`, `isEmpty: (d) => !diveHasWeights(d)`.

- [ ] **Step 1: Write the failing tests**

```dart
// fields
test('a legacy weight reads as one row and is no change', ...);
test('a legacy weight edited is written as a row and the legacy columns clear', ...);
test('the same weights in another order are no change', ...);
test('feedback correct clears the amount; over again gives back the stored one', ...);
test('the last dive at a center replaces weights and cylinders, and drops their switches', ...);
// editor
testWidgets('opening and tapping every row leaves the sitting clean, metric and imperial', ...);
testWidgets('a weight added, changed and removed; the total follows', ...);
testWidgets('an amount that cannot be read refuses Done', ...);
testWidgets('a preset replaces the weights', ...);
testWidgets('Save as preset creates it at once, and it survives Cancel', ...);
testWidgets('feedback over with an amount, in pounds, saves kilograms', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement, moving `applyLastDiveNeedsConfirm` first**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/dive_log/presentation/pages/dive_edit_weight_feedback_test.dart test/features/dive_log/presentation/pages/dive_edit_weight_preset_test.dart test/features/dive_log/presentation/pages/dive_edit_apply_last_dive_confirm_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): edit a dive's weights and weighting feedback on its Weight card"
```

---

### Task 9: Gear and sets in the sitting

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart`
- Modify: `dive_tanks_card_editor.dart` (`TankRow.onOwnCylinderUsed` adds the cylinder to the gear with `addGearToSitting`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields_test.dart`, `dive_set_use_test.dart`, `dive_tanks_card_test.dart` (one case)

**Interfaces:**
- Consumes: `gearLinksFor`, `expandGearOnPage`, `EquipmentRepository.usableSetMemberIds`, `setBundleProvider`, `setBundleLoaderProvider`, `planSetWeights`, `showSetWeightsChoiceDialog`, `bringsMainSupply`, `confirmCylinderOverwrites`; `cylindersFromConfig`, `setTanks` (Task 4); `diveWeightsField` (Task 8).
- Produces:

```dart
final EditField<Dive, List<GearLink>> diveGearField;   // 'gear', card 'equipment', a set of (id, via, set)

/// Adds [items] as the form's `_addGearNow` does (`dive_edit_page.dart:4731`):
/// for a set, only the members the dive's diver may use
/// (`EquipmentRepository.usableSetMemberIds`); merged by id; assemblies
/// expanded with `expandGearOnPage(ref, ...)`. Adds run one at a time, in
/// the order asked, and are tracked. The result is dropped when the sitting
/// ended or is being saved, or [stillWanted] says no (the caller's widget
/// has gone).
Future<void> addGearToSitting(WidgetRef ref, EditSession<Dive> session, List<EquipmentItem> items, {String? viaSetId, required bool Function() stillWanted});

void removeGearRows(EditSession<Dive> session, Set<String> equipmentIds);
/// A set removed: its gear with it, or only its tag ([keepGear]).
void removeSetFromSitting(EditSession<Dive> session, String setId, {required bool keepGear});
void clearGear(EditSession<Dive> session);

/// Uses [set] on the sitting as `_useSet` does on the form
/// (`dive_edit_page_set_bundle.dart:10`): sets it includes absorbed, its
/// gear, then its weights and cylinders. [auto] asks nothing and
/// overwrites nothing. Returns what it changed, for the location take-back.
Future<SetUseResult?> useSetInSitting(BuildContext context, WidgetRef ref, EditSession<Dive> session, EquipmentSet set, List<EquipmentItem> items, {required bool auto});

@immutable
class SetUseResult { final ({List<GearLink> gear, List<DiveWeight> weights, List<DiveTank> tanks}) before, after; }
```

- [ ] **Step 1: Write the failing tests**

```dart
// fields
test('the same gear in another order, or with an item renamed, is no change', ...);
test('a set adds only usable members, expanded, merged by id', ...);
test('removing a set keeps or drops its gear', ...);
// set use
testWidgets('a set brings gear, weights and cylinders: three cards change', ...);
testWidgets('weights already on the dive ask add, replace or keep', ...);
testWidgets('cylinders it would overwrite ask; declining keeps gear and weights', ...);
testWidgets('auto asks nothing and overwrites nothing', ...);
testWidgets('a set included in one on the dive is absorbed', ...);
testWidgets('cancelled while the bundle loads: nothing is set', ...);
// dive_tanks_card_test.dart
testWidgets('an own cylinder scanned on a row joins the gear: Equipment gets its dot', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the two test files.
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the two test files, then `flutter test test/features/equipment/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): gear and equipment sets in a sitting"
```

---

### Task 10: A site picked in a sitting applies or suggests its location set

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart` (`readDiveSiteAssigner` calls it after `assignDiveSite`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence_test.dart`

**Interfaces:**
- Consumes: `EquipmentSetSelector.bestSetFor`, `.matchingGeofenceSet`, `equipmentSetSelectionInputsProvider`; `useSetInSitting` (Task 9). Plan 4's rule: call it from `assignDiveSite`'s caller, so the site rules stay free of gear.
- Produces:

```dart
/// The set the sitting suggests for its site, or null.
EquipmentSet? geofenceSuggestion(EditSession<Dive> session);

/// After the site changed: takes back what the previous site's set applied
/// (gear, weights, cylinders each only while still as it left them), drops
/// the suggestion, then for a dive with no gear applies the best set
/// ([useSetInSitting] auto), and otherwise suggests the matching set when it
/// is not dismissed and brings an item the dive lacks. Dropped when the
/// site changed again, the sitting ended or is being saved. Tracked.
void reevaluateGearForSite(BuildContext context, WidgetRef ref, EditSession<Dive> session);

void dismissGeofenceSuggestion(EditSession<Dive> session);   // not asked again this sitting
```

  `readDiveSiteAssigner` returns a function that runs `assignDiveSite` then `reevaluateGearForSite`; the suggestion card's Assign goes through it already.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a dive with no gear gets the best set, with its weights and cylinders', ...);
testWidgets('site A applied a set, then site B: A\'s gear, weights and cylinders go back', ...);
testWidgets('gear the diver changed after A\'s set is kept when B is picked', ...);
testWidgets('a dive with gear gets a suggestion, not a set', ...);
testWidgets('a dismissed set is not suggested again', ...);
testWidgets('A\'s inputs answering after B: nothing applied', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment_test.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): a site picked in a sitting applies or suggests its location set, and the next takes it back"
```

---

### Task 11: The Equipment card editor

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_editor.dart`
- Modify: `dive_edit_cards.dart` (the `equipment` entry), `dive_detail_equipment_section.dart` (the suggestion on the closed card)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_test.dart`

**Interfaces:**
- Consumes: Tasks 9 and 10; `DiveGearTreeView`, `EquipmentPickerSheet`, `EquipmentSetPickerSheet`, `scanOwnedItem`, `showEquipmentArrangeSheet`, `GeofenceSuggestionBanner`, `equipmentSetListNotifierProvider.notifier.addSet`, the form's Save-as-set dialog (`_saveEquipmentAsSet`, `dive_edit_page.dart:5336`: move its dialog into a function of its own file if the card needs it, and have the form call that).
- Produces: `DiveEquipmentCardEditor({required EditSession<Dive> session})`; the `diveEditCards[DiveDetailSectionId.equipment]` entry, `isEmpty: (d) => d.gear.isEmpty`, leading `Icons.backpack`. The editor: Use set, Add, Scan and Sort; the suggestion banner; the tanks-versus-gear caption (not for gauge); the gear tree with its remove actions; Save as set and Clear all. The closed card shows the suggestion banner at its top only while no editor is open.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('opening and closing leaves the sitting clean', ...);
testWidgets('add from the picker, several at once', ...);
testWidgets('a scanned item already on the dive is not added twice', ...);
testWidgets('a set removed asks keep or remove', ...);
testWidgets('Save as set creates the set at once, and it survives Cancel', ...);
testWidgets('a cylinder tag scan imports its fill at once, and it survives Cancel', ...);
testWidgets('the suggestion applied fills the gear; dismissed, it goes', ...);
testWidgets('the closed card shows the suggestion only once the editors close', ...);
testWidgets('the header actions fit at 360 px', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then every `test/features/dive_log/presentation/pages/dive_edit_*gear*`, `*equipment*` and `*set*` test file (the form must be unchanged), and `test/architecture/ test/shared/`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_card_test.dart
git commit -m "feat(dive-log): edit a dive's gear on its Equipment card"
```

---

### Task 12: The read cards gain their pencils, pair with the stored dive, and write nothing while locked

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (`visible`, `_sectionContent`, `_buildPairCards`)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (title row, Reassign, Assign)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_equipment_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_weight_section.dart`
- Modify: `lib/features/equipment/presentation/widgets/observation_status_chip.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_tanks_editing_test.dart` (new)

**Interfaces:**
- Consumes: `RecordCardPencil`, `RecordCardHeader` (plans 1 and 4); `RecordEditScope.maybeOf<Dive>`; `diveCardIsOnPage`.
- Produces:
  - `ObservationStatusChip` gains `bool readOnly = false`: drawn the same, with no tap and no button role.
  - With a `RecordEditScope` (editing offered), the Cylinders card shows no Reassign at any time (it is in the editor), and Assign transmitter only while unlocked with `!controller.isDirty`; check-in chips on Cylinders and Equipment rows are `readOnly` while locked. With no scope, both cards are as today.
  - Title rows: Cylinders gains a `RecordCardPencil` after its title; Equipment puts one beside Sort in its `trailing` (its own fold keeps toggling); Weights draws its title with `RecordCardHeader(trailing: total)`. None changes height on unlock.
  - In the section list, a section with no editor decides gauge hiding from `stored.isGauge`; Tanks decides from its `isEmpty` through `_onPage`. The `tanks` and `weights` pair cases draw `this.dive` for their editable half, count it present while open or on the page, and draw the stored dive for SAC segments and Buoyancy, as the `details` case does.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('editing off: the three cards and their pairs as before', ...);
testWidgets('locked: no Reassign, no Assign, check-in chips do not open; Sort opens', ...);
testWidgets('unlocked: a pencil on each title row, and no row changes height', ...);
testWidgets('Assign shows in a sitting with no changes only', ...);
testWidgets('a gauge mode picked in the sitting leaves deco, tissue and SAC segments until Save', ...);
testWidgets('the Tanks half of its pair opens in place beside SAC segments', ...);
testWidgets('a weight added shows on the Weights half after Done; Buoyancy keeps the stored dive', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_tanks_editing_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/ test/features/equipment/presentation/widgets/ test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart test/features/dive_log/presentation/pages/dive_detail_gear_tree_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features test/features
git commit -m "feat(dive-log): the Cylinders, Equipment and Weights cards gain pencils and write nothing while locked"
```

---

### Task 13: Other cards start the rules: trip slots, the dive center's last dive, the volume hints

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart` (`DiveTripRow` calls `tanksAfterTripChange`; `DiveCenterRow` shows `RentalMemoryCard`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart` (`_VolumeHint`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_sac_segments_section.dart` (its `SacVolumeHint`)
- Test: `dive_details_trip_rows_test.dart`, `dive_details_card_test.dart` (add cases), `test/features/dive_log/presentation/widgets/dive_detail/dive_volume_hint_test.dart` (new)

**Interfaces:**
- Consumes: `tanksAfterTripChange` (Task 4), `applyLastDiveInSitting` and `applyLastDiveNeedsConfirm` (Task 8), the form's confirm dialog for applying the last dive (`dive_edit_page.dart:6092`: move it to a function of its own file and have the form call that).
- Produces:
  - A trip picked, created or cleared on Details runs `tanksAfterTripChange` with the slot read from `tripCylinderStatesAtProvider` (held open while the read is in flight, as `_readTripCylinderStates` does).
  - Under a chosen dive center, the Details editor shows `RentalMemoryCard(center:, currentDiveId: session.stored.id, onApplyLastDive:)`; applying asks first when the sitting has weights or cylinders, then `applyLastDiveInSitting`.
  - Both volume hints, during a sitting, open the Tanks card where it is, or add it from the strip; locked they do as today.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a trip changed on Details clears slot links: Tanks gets its dot', ...);
testWidgets('the last dive at the center applied: Weights and Tanks get their dots', ...);
testWidgets('applying over weights asks; declining changes nothing', ...);
testWidgets('a rental note added writes at once and survives Cancel', ...);
testWidgets('the volume hint in a sitting opens the Tanks card', ...);
testWidgets('the hint on SAC segments does the same', ...);
testWidgets('locked, the hints lead where they did', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: the three test files.
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the three test files, then `flutter test test/features/dive_log/presentation/pages/dive_edit_rental_memory_test.dart test/features/dive_centers/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/features
git commit -m "feat(dive-log): a trip, a dive center and the volume hints reach the Cylinders and Weight cards"
```

---

### Task 14: The page, end to end

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting` passes the changed cards to the follow-up)
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (cylinders, gear, weights, a profile, gas switches, sets)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_test.dart` (new)

**Interfaces:**
- Produces: `DiveSittingFollowUp.run` gains `required Set<String> changedCardIds` and one guarded step: when it names `tanks`, `equipment` or `weights`, `scheduleDerivedMetricsRefresh([id])` and `scheduleSensorSummaryRefresh([id])`, as the form does after every save (`dive_edit_page.dart:6983`).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('each card has a pencil and opens where it sits', ...);
testWidgets('opening and closing all three in imperial units leaves the sitting clean', ...);
testWidgets('a set used: Save names Equipment, Weight and Cylinders in one entry', ...);
testWidgets('Cancel after a set, a reassign and a switch leaves every row as it was', ...);
testWidgets('a runtime shortened on the header past a switch: Save refuses and opens Cylinders', ...);
testWidgets('a cylinder removed with a switch and an exchange on it saves without error', ...);
testWidgets('a gauge dive: Tanks is in the strip; CCR picked and saved', ...);
testWidgets('pressures keep their cylinders after a save that changed another card', ...);   // dive_edit_preserves_sac_widget_test.dart, for the sitting
testWidgets('a refresh that throws after the write is not a failed save', ...);
testWidgets('a locked page makes no write on any tap in the three cards', ...);
// tap Reassign's place, every check-in chip, Assign's place, every gear row and the weight rows: no repository write; Sort opens its sheet.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_gear_test.dart`
Expected: the refresh test FAILs. Any other new test that passes at once is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Implement the follow-up step**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then every `test/features/dive_log/presentation/pages/dive_detail_page_unlock*_test.dart`.
Expected: PASS.

- [ ] **Step 5: Format, analyse, run the guards and the page tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database/`
Run: every `test/features/dive_log/presentation/pages/dive_detail*_test.dart`, `dive_edit_*_test.dart` and `bulk_*_test.dart` file, `test/features/dive_log/presentation/widgets/`, `test/features/dive_log/data/`, `test/features/dive_log/domain/`, `test/features/equipment/`, `test/features/dive_centers/`, `test/features/cylinder_configs/`, `test/features/data_quality/` and `test/features/change_log/`.
Expected: PASS.
Run: `wc -l` on every file this plan created or changed.
Expected: none over 800; `dive_detail_page.dart` at most 782.

- [ ] **Step 6: Look at it**

Render the page in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): the three cards locked and unlocked; each open, full and empty; a CCR and an SCR dive; a gauge dive with Tanks from the strip; gas switches with a profile; a set's weights question; the location suggestion; a reassign held; the pairs beside SAC segments and Buoyancy at desktop width. Light and dark, metric and imperial, phone and desktop width. Check by eye that no card moves or grows on unlock and that the open editors' rows line up. Fix what is wrong with a test first, and keep the pictures, with the "before" ones from Preparation, for the pull request.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages test/features/dive_log/presentation/pages
git commit -m "feat(dive-log): after a sitting that changed cylinders, gear or weights, refresh what they feed"
```

---

## Pull request

One, `Refs #4527`. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the "before" pictures from Preparation and the pictures from Task 14 Step 6, with a line saying the unlocked page is unreachable without the build switch. With the switch off nothing on the page looks different; say so. Pushing and opening it waits for Eric.

## For plans 6 to 8

- **Plan 6.** The profile's annotations read the same time limits: `gasSwitchTimeLimits` is the place to share them from. The fullscreen profile, opened during a sitting, shows the sitting's gas switches (`sittingGasSwitches`).
- **Plan 7.** Assign transmitter (call 5) and the reassign's old immediate path become listed whole-record operations. The check-in chip's sitting behaviour (call 3) is settled there if Eric wants it held.
- **Plan 8 (new dive).** Tanks is in the starter set: seed it with `newSittingTank` and the default preset (`_loadDefaultPreset`, `dive_edit_page.dart:851`). The default set applies through `useSetInSitting(auto: true)`. A prefilled tank and the trip board's slot shortcut go through `setTanks` and `tankSlotChosen`.
- **Plan 9.** `tank_pressure_series` exchanges join the sitting's History entry.
- **Any plan giving a card an editor:** add it to `diveEditCards`; a card whose values can be invalid without its widgets gives `isValid`.

---

## After the review

The plan was built as written in this session (Eric chose "Native"), then reviewed as a whole branch by a fresh reviewer. This is what differs from the task text above, for whoever writes plan 6.

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `setTanks(session, tanks)` renumbers | It does not: `removeSittingTank` renumbers, as the form does. `setTanks(..., replaced: true)` marks a change made from outside the rows and moves `tankRowsGeneration`, which keys the Cylinders editor's rows |
| `cylindersFromConfig` | Gone: the editor calls `DiveTankConfigAdapter` itself, as it needs the overwrites for the confirm |
| `loadGasSwitches(session, read:)` and edits taking a writer | `loadGasSwitches(session, read:, writer:)` takes a writer factory, kept for the held write; the edits take none. `loadDiveGasSwitches(session, read)` reads from the database, through `diveGasSwitchWriterProvider` |
| Switches load when the Cylinders card opens | They load as the sitting starts: `startDiveSitting(session, read)` in `dive_edit_cards.dart`, called through `RecordEditController(onStart:)` whichever way the page is unlocked. Save checks a card that was never opened |
| `addGearToSitting(session, items, reads:)` and `useSetInSitting(context, ref, ...)` | Both read providers through a `ProviderRead` (typedef in `gear_expansion.dart`, beside a new `expandGear(read, ...)`); the cards pass their `ProviderContainer`'s, so an add goes on after its card closes. `useSetInSitting(session, set, items, read:, questions:, auto:, stillWanted:)` asks through `SetUseQuestions.dialogs(context, units)`, so it holds no context across its awaits |
| `removeGearRows(session, ids)` | `keepGearRows(session, rows)`: the gear tree hands back the rows that stay |
| The reassign runs after the dive is written, skipping a removed cylinder | It is held with `beforeRecord: true` and runs before the dive (`EditSession.holdChange(beforeRecord:)`, `runHeldWrites(beforeRecord:)`, `DiveEditSaveService.save(writeFirst:)`), while both rows exist: a removed cylinder takes the readings moved onto it |
| `applyLastDiveInSitting(session, last)` | Takes `defaultStartPressure` |
| `DiveSittingFollowUp.run(..., changedCardIds:)` required | Required, as above; the refresh is `diveGearRefreshProvider` (quality scan, derived metrics, sensor summary) |
| The volume hint in two places | One widget, `DiveVolumeHint`: in a sitting it calls `addCard('tanks')` |
| Dialogs inside the form | `showSaveGearAsSetDialog(context, topLevelIds:)` and `confirmApplyLastDive` are files of their own, called by the form and the cards; the set dialog is a widget that owns its text fields and reads its own `ref` |
| Rows keyed by `tankRowsGeneration` alone | Also by `StoredFollow` (`shared/widgets/record_editing/stored_follow.dart`), which moves when a stored value the sitting follows changes underneath; the Weight editor keys its rows with it in place of a counter of its own |
| The site list refreshed for any held write | Only for a held write other than the dive's own rows (`diveOwnHeldWriteKeys` in `dive_edit_cards.dart`, read through `EditSession.heldKeys`) |
| `_inTimeOrder` in the form and the sitting | `gasSwitchesInTimeOrder` in `gas_switch_editing.dart`, for both |
| Test files | Read cards and the page end to end are in `dive_detail_page_unlock_gear_cards_test.dart` and `dive_detail_page_unlock_gear_test.dart`; the Details rules in `dive_details_gear_rules_test.dart` |

### Decided while building

- `RecordCardForm` checks its fields again whenever it is rebuilt, so a limit another card changes (the header's runtime bounding a switch) is reported both ways. It asks each field's `isValid`, which rebuilds nothing, and validates the form only when an error must appear or go. `RecordEditController.save` asks the card checks again after waiting for tracked work, and not at all for a sitting with nothing to write, which ends as before.
- Typing a switch's time back restores its own depth; with no profile the latest time is the runtime or bottom time in exact seconds.
- The Cylinders and Weight title rows are `RecordCardHeader`s (the Cylinders info button as the trailing widget), so the pencil adds no height. The hidden Assign button keeps its room, so the card does not grow on unlock.
- The read-only check-in chip is a disabled button that keeps its colour. A screen reader hears a check made as text, and nothing for a gear row with none.
- The location suggestion shows above the closed Equipment card once every editor has closed, and inside the open card only while no other card is open.
- The Equipment editor's "Save as set" and "Clear all" row wraps on a narrow phone.
- A gear add that finds the gear changed while it read the parts works itself out again on what is there, so it never puts back what the diver took off. A saved configuration or a set's cylinders confirmed over an overwrite are applied to the cylinders as they are after the answer.
- Location set lookups run one after another, each with its own token: one still putting its set on when the site changes again stops, what it put on is remembered and taken back by the next. Site A, B, A acts on the last lookup only. A value is taken back only when it is still as the set left it and has not been changed since (`EditSession.fieldRevisionOf`): gear, weights or cylinders changed and changed back are the diver's.
- A trip changed and changed back gives the stored cylinders their own slot links back.
- The reassign sheet in a sitting shows the readings after the held exchanges (`tankReadingsInSitting`), lists only cylinders the dive is stored with, and its Move to offers those, not the dive as stored. The switch time sheet and the breath-start chips read the readings the same way, and the detected switches are not offered while a reassign is held: they are found with the gas of the cylinder the readings are stored on.
- Save as preset that cannot be written logs it and says so.
- An open Cylinders or Weight row is built again when the dive changes underneath and the sitting follows it, so its next keystroke cannot write the old text back. A row the diver has changed is left alone.
- A Save refused after waiting for tracked work gives the sitting the record stored meanwhile, as a failed write does.
- The closed Cylinders card in a sitting draws each cylinder's series and cursor line where a held reassign has moved them.
- A check-in in a sitting is for gear and cylinders the dive is stored with; one only in the sitting shows its state, as the locked page does.
- With the mode as stored, a rebreather value typed under a mode picked and left again is not written: the values the mode does not use stay as stored.
- `DiveTank.copyWith` gained `clearStartPressure` and `clearEndPressure` for the exchange.
- Plan 3's test that the volume hint is a plain note during a sitting now pins that it opens the Cylinders card.

### Left open

- A stored switch already out of range blocks Done on an opened Cylinders card, and Save of a sitting that changed anything, as the form's validator does today. A sitting with nothing to write ends on Save.
- Exchanged readings are not in the sitting's History entry until plan 9.
- Tests not written: the gauge mode picked in a sitting leaving deco, tissue and SAC segments until Save; the pairs in a sitting; Save as set surviving Cancel; a set used across three cards at page level (it hangs on database reads in the fake clock).

### Cleared later (PR #4670)

- The four tests are written: `dive_detail_page_unlock_gear_pairs_test.dart` (the gauge mode and the pairs) and `dive_detail_page_unlock_gear_sets_test.dart` (Save as set, and a set used across three cards, which waits on the real clock for the set's reads). The stored switch out of range was fixed in #4623, and exchanged readings reach History through plan 9.
