# Unified Editing, Plan 3: Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive page's Details card editable in place: dive types, trip, dive center, operator, boat, captain, training courses, visibility, water type and the two statistics switches (issue #4527).

**Architecture:** Plans 1 and 2 gave the page an `EditSession<Dive>`, a `RecordEditController<Dive>`, field bindings, held writes and a layout that holds still while a card is open. This plan adds eleven fields owned by the `details` card, an editor built from the dive form's own pickers, and one rule that runs at save time (a dive put on a trip stretches that trip's dates) inside the save service's transaction. Two small pieces are lifted out of `RecordNumberRow` so that a row which is not a plain number can follow the same rules. Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read the Cards table and its notes, "Rules that span cards" and "What is held, and what is not". Plan 2 is `docs/design/plans/2026-11-14-unified-editing-2-altitude-environment.md`; its last section, "After the review", lists the names as built. This plan uses those names.

## What the Details card owns, shows and leaves alone

### Owns: edited on this card

| Value | Field (all `cardId: 'details'`) | Editor row | Today's form |
| --- | --- | --- | --- |
| Dive types | `diveTypeIdsField`, `List<String>` | `DiveTypeMultiSelectField` | `_diveTypesRow`, `dive_edit_page.dart:3015` |
| Trip | `diveTripField`, `Trip?` | Picker row, date caption, suggestion | `_buildTripGroupSection`, `:3291` |
| Dive center | `diveCenterField`, `DiveCenter?` | Picker row, location caption | the same section |
| Operator, boat, captain | `diveOperatorField`, `diveBoatNameField`, `diveBoatCaptainField`, `String?` | `SuggestedTextRow` | `_logisticsRows`, `:3346` |
| Training courses | `diveCourseIdsField`, `List<String>` | `CourseMultiSelectField` | `_buildCourseGroupSection`, `:3633` |
| Visibility | `diveVisibilityField`, `StoredVisibility` | `DiveVisibilityRow` (new) | `_visibilityInput`, `:5510` |
| Water type | `diveWaterTypeField`, `WaterType?` | `EnumPickerRow` | `_environmentRows`, `:5598` |
| Excluded from statistics | `diveExcludedFromStatsField`, `bool` | `FormRow.toggle` | `_buildStatisticsSection`, `:3692` |
| Excluded from gas statistics | `diveExcludedFromGasStatsField`, `bool` | `FormRow.toggle` | the same section |

### Shows, owned elsewhere

These rows stay in the open editor, in the read card's order, as rows that cannot be typed in, so nothing the card showed disappears when it opens.

| Row | Owner | What the owning plan must do |
| --- | --- | --- |
| Dive mode | Tanks card (plan 5) | Give its field `alsoShownOn: {'details'}` |
| Average depth | Header block (plan 4) | Give its field `alsoShownOn: {'details'}` |
| Buddy and dive master as imported text | Nobody edits them: the dive form carries them through untouched (`dive_edit_page.dart:6714`), and they show only while the dive has no buddies | Nothing |
| Air consumption (SAC, RMV), gradient factors, dive computer, surface interval | Calculated or imported | Nothing |

### Other cards that read a value Details owns

| Value | Read by | What this plan does |
| --- | --- | --- |
| Water type | Environment (satellite conditions are left out for a freshwater dive), Tide (no tides in fresh water), the Surface GPS and Tide pair | Tide, its pair and the Environment card's satellite block are laid out from `presence` (Task 9, and the review: see "After the review") |
| Training courses | Signatures (the training signature shows for a dive with a course), the Buddies and Signatures pair | Signatures and its pair are laid out from `presence` (Task 9) |
| Trip | The Cylinders card, through each tank's link to a trip cylinder | See "Rules that span cards" below |

### Rules that span cards

| Rule (from the spec's table) | After this plan |
| --- | --- |
| A dive put on a trip, or moved to another day on one, stretches the trip's dates | Built here, in `DiveEditSaveService`, inside the transaction (Task 4). Plan 4's date change gets it for nothing |
| Trip: clears tank slot links and suggests slots again | Not built here. Tanks are not in the sitting until plan 5. Until then the writer drops, at Save, any link that points into another trip's cylinders (`validTripCylinderLink`, `dive_repository_impl.dart:3010`); Task 4 pins that |
| Dive center: applying rental memory replaces weights and tanks | Not built here. The "last time here" card is left out of the editor until plan 5, which owns both collections |
| Site: snaps water type and dive types; orders the dive center picker | The snaps are plan 4's, written through this plan's fields. The picker already reads `session.working.site` |

## Where the card differs from today's form, and why

1. **Water type is the dive's own value.** The form loads the site's water type into the picker when the dive has none, and saving then stores it on the dive (`dive_edit_page.dart:1159`). Here the picker holds the dive's own value and shows the site's as its hint, as the Environment card does for the entry method. Why: a value the diver did not change is never written, and opening a card must leave the sitting clean.
2. **Visibility: the switch chooses an input, the sitting holds the value.** In the form only the active mode counts at save, so a number typed in Precise is thrown away by switching to Range. Here whatever was last set is what is saved, whichever input is showing. Why: the sitting holds values, not widget state, and the read card shows the value after Done.
3. **Visibility: emptying the number means "no measurement".** In the form, typing a number and deleting it erases a stored range or bucket. Here the dive goes back to the range or bucket it has stored, and the card is clean again. A stored measurement that is emptied is cleared. A range or bucket is cleared by turning its chip off in Range. Why: typing a change and typing it back must leave the sitting clean.
4. **Visibility: a negative number is refused.** The form saves `-5` as "no visibility". Here it is unreadable input, like `1.2.3`. Why: one rule for text that is not a value.
5. **The number already on show stands for the value behind it.** A visibility stored as 12 m shows as 39 ft; typing 39 back is no change. The form would store 11.89 m. Why: plan 2's number rule, applied here.
6. **No "last time here" card.** See the rules table.
7. **The trip's dates move with the save, or not at all.** The form saves the dive, then stretches the trip, and says so if the stretch failed. Here the stretch is in the transaction and the History entry, as the spec's "Written with the sitting" list says. A stretch that fails fails the save.
8. **The trip suggestion's button is the only tap target.** The form wraps the whole line in a second button with an English-only screen reader label (`dive_edit_page.dart:3378`). Here the line is text and "Use" is the button.
9. **One card, one order.** The form spreads these values over four groups (The Dive, Conditions, Trip, and two rare groups). Here they follow the read card's order.

## Not in this plan

- The header block, and so the site and everything a site sets. Plan 4.
- Dive mode, the rental memory card, clearing and suggesting tank slot links when the trip changes. Plan 5.
- The link under the air consumption rows that leads to the edit page to add a tank volume (`dive_detail_details_section.dart:269`). It needs the Tanks card: plan 5.
- Which dive types the site added (`_siteAddedDiveTypeIds`, `dive_edit_page.dart:398`). It is form state that only a site assignment reads: plan 4.
- Calculated cards fading back and keeping their stored values during a sitting. This plan only keeps Tide and Signatures from moving the page.
- The embedded list pane, whole-record operations.

## The form's own tests

The spec says no `dive_edit_*` test is dropped without a replacement. The form and its tests stay until the last plan deletes it; these are the ones that cover what Details now owns, and where their replacement is written. Read each file at the start of the task named, and add to that task's tests any behaviour it pins that the list there does not.

| Form test (`test/features/dive_log/presentation/pages/`) | Replaced in |
| --- | --- |
| `dive_edit_visibility_field_test.dart` | Task 6 |
| `dive_edit_trip_stretch_test.dart` | Tasks 4 and 10 |
| `dive_edit_new_trip_prefill_test.dart`, `dive_edit_dive_center_nearby_test.dart` | Task 7 |
| `dive_edit_statistics_section_test.dart`, `dive_edit_dive_type_placement_test.dart` | Tasks 5 and 8 |
| `dive_edit_site_water_type_test.dart`, `dive_edit_site_dive_types_test.dart` | Plan 4, where a site is chosen. Task 8 covers the water type hint |
| `dive_edit_trip_cylinder_test.dart` | Plan 5 |

## Calls made in this plan, for Eric to check

1. **The statistics row shows on the locked page for everyone once this merges.** The spec gives the read card a row when a statistics switch is on. It is not behind the build switch: "Statistics: Excluded" or "Statistics: Gas excluded", at the end of the card. The other choice is to hold it back until the switch-over.
2. **Water type: the picker holds the dive's own value and hints the site's** (difference 1). Saving an edit no longer copies the site's water type onto the dive.
3. **Visibility behaves as differences 2 to 5 describe.**
4. **Rental memory waits for plan 5** (difference 6).
5. **A changed trip leaves the Cylinders card showing its old trip cylinder until Save.** The stored result is right, because the writer drops the link. The card catches up in plan 5.
6. **A failed trip stretch fails the save** (difference 7).
7. **Dive mode, average depth and the calculated rows stay in the open editor as rows that cannot be typed in.** Dive mode and average depth are edited on the Tanks card and the header block.
8. **The imported buddy and dive master text is read-only.** The form does not edit it either.
9. **A reorder of dive types is a change; a reorder of courses is not.** The first dive type is the representative, and their order is stored. Courses are stored as a set, and the writer picks the representative course itself (the earliest to start), so their order is nothing the diver can save.
10. **After a save that set a new visibility, the device remembers that input mode for the next new dive**, as the form does.
11. **No new strings.** Every label is one the form or the read card already has. The statistics row reuses `diveLog_edit_group_statistics`, `diveLog_edit_summary_excluded` and `diveLog_edit_summary_gasExcluded`.
12. **Tide, Signatures and the Environment card's satellite lines follow the layout record.** Adding a first course, or switching to fresh water, changes those cards when the last editor closes, not while Details is open.

## Global Constraints

- With `kUnlockEditing` false the dive page builds and behaves exactly as today, with two named exceptions on the Details read card: its title is drawn by `RecordCardHeader`, and call 1 above.
- A card does not move on the page while its editor is open, whatever is typed or picked in it.
- Every value shown or typed follows the active diver's units (`unitFormatterProvider`). Visibility is typed in the diver's depth unit. The session holds canonical values: metres.
- A value the diver did not change is never written. Opening the card and leaving it alone must leave the sitting clean, in every unit setting and for every stored shape of visibility.
- Emptying a field clears the stored value.
- Typed numbers are read only through `readNumber` (`lib/shared/widgets/forms/number_input_validation.dart`); the architecture guard forbids `tryParse` in presentation code.
- A text field that shows a value of the sitting gets it through `FieldTextBinding` or `replaceTextKeepingCaret` (`text_keeping_caret.dart`), never by assigning `text`.
- Number tests type digit by digit (one `enterText` per growing prefix) and step through values that round alike. One `enterText` with the final text hid a real bug in plan 2.
- Anything that writes to a sitting after an `await` (a picker closing, a page returning, a lookup) checks `mounted`, `session.isDisposed` and `session.isFrozen` first, and reads what it needs from `ref` and `context` before the `await`.
- Any refresh, message or preference written after `service.save` returns is in a `try` of its own. A failure there is logged and never reported as a failed save.
- `session.set(field, const [])` with an untyped literal fails at run time: type the literal (`<String>[]`).
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 785 and gains nothing here: page code goes in `dive_detail_page_editing.dart`.
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects none (call 11).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`. Build repositories in `setUp`, never once for the file.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **Clearing the trip stores no trip.** A loaded dive carries both `trip` and `tripId`, and the writer saves `dive.tripId ?? dive.trip?.id` (`dive_repository_impl.dart:2869`). Clearing only `trip` would put the old trip back. Pinned in Tasks 1, 3 and 4.
2. **A visibility the diver did not change is not rewritten.** Stored as 12 m and shown as 39 ft, typed back digit by digit; stored as a range under a scale the diver has since changed; stored as an old bucket. Opening, focusing, switching input and closing must all leave the sitting clean. Pinned in Tasks 6 and 10.
3. **Opening the card on a dive whose site has a water type stores nothing.** The dive keeps no water type of its own, and the read card goes on showing the site's. Pinned in Tasks 8 and 10.
4. **A picker or a new-record page that answers late.** The trip or dive center arrives after the card closed, the sitting was cancelled, or Save began. Nothing is set and nothing throws. Pinned in Task 7.
5. **The first course, or fresh water, with Details open.** No card appears or goes above the editor, and no pair forms or splits, until the last editor closes. Pinned in Task 9.
6. **The trip's dates follow the sitting.** If Save fails the trip keeps its dates. A dive whose trip was not touched does not stretch it, even when it sits outside it. Pinned in Task 4.

## Preparation

- [ ] Work on branch `ericgriffin/unified-editing-3-details`, cut from plan 2's branch `ericgriffin/unified-editing-2-altitude-environment` at `23b06be2a19` while pull request #4550 is open. Check that `lib/shared/widgets/record_editing/text_keeping_caret.dart` exists.
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] If #4550 merges before this is finished: this repository squash-merges, so merge #4550's real head commit into this branch first (`gh pr view 4550 --json headRefOid`), then take main with that head as the merge base (`git merge-tree --write-tree --merge-base=<head> HEAD origin/main`, then `git commit-tree` with both parents and `git merge --ff-only`). Afterwards read #4550's last review fixes and check this plan's code against each rule they set.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `record_field_marks.dart` | `RecordFieldMarks`: a text row's unreadable mark and its answer to a reveal request |

New, dive (`lib/features/dive_log/presentation/widgets/dive_detail/`):

| File | Responsibility |
| --- | --- |
| `dive_details_derived_rows.dart` | The Details rows nothing edits, shared by the read card and the editor; the statistics row's wording |
| `editing/dive_details_fields.dart` | The eleven fields and the pure visibility helpers |
| `editing/dive_visibility_row.dart` | `DiveVisibilityRow`: the Range and Precise input bound to the sitting |
| `editing/dive_details_trip_rows.dart` | `DiveTripRow` and `DiveCenterRow`: picker rows, captions, the trip suggestion, creating a trip or a center |
| `editing/dive_details_card_editor.dart` | `DiveDetailsCardEditor`: the card's rows in order |

Modified: `dive.dart`, `record_number_row.dart`, `dive_edit_save_service.dart`, `dive_edit_save_provider.dart`, `dive_course_rows.dart`, `dive_detail_details_section.dart`, `dive_edit_cards.dart`, `dive_detail_section_list.dart`, `dive_detail_page_editing.dart`, and the test harness `dive_detail_page_unlock_harness.dart`.

---

### Task 1: `Dive.copyWith` can clear the values Details edits

`copyWith` keeps the old value when passed null. Plan 2 added clear flags for the Altitude and Environment values (`dive.dart:873-976`). Details needs the same for its own.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`copyWith`, from line 842)
- Test: `test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart` (exists)

**Interfaces:**
- Produces: eleven `bool` parameters on `Dive.copyWith`, each defaulting to false: `clearDiveCenter`, `clearTrip`, `clearTripId`, `clearVisibility`, `clearVisibilityMeters`, `clearVisibilityMinMeters`, `clearVisibilityMaxMeters`, `clearDiveOperator`, `clearBoatName`, `clearBoatCaptain`, `clearWaterType`. Each follows the existing form: `waterType: clearWaterType ? null : (waterType ?? this.waterType)`.

- [ ] **Step 1: Write the failing tests**

Add the eleven to the file's existing `cases` table (one line each, and a non-null value for each in `full`), so each is checked to clear itself and nothing else. Then:

```dart
test('clearing the trip needs both flags', () {
  final onTrip = full.copyWith(trip: trip, tripId: trip.id);
  final cleared = onTrip.copyWith(clearTrip: true, clearTripId: true);
  expect(cleared.trip, isNull);
  expect(cleared.tripId, isNull);
  // The trap: the writer saves `tripId ?? trip?.id`.
  expect(onTrip.copyWith(clearTrip: true).tripId, trip.id);
});
test('a clear flag wins over a value passed with it', () {
  expect(full.copyWith(waterType: WaterType.fresh, clearWaterType: true).waterType, isNull);
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart`
Expected: FAIL to compile, the flags do not exist.

- [ ] **Step 3: Add the eleven flags and their bodies**

- [ ] **Step 4: Run it and confirm it passes**

Run: the same command, then `flutter test test/features/dive_log/domain/`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart
git commit -m "feat(dive-log): let copyWith clear a dive's trip, dive center, visibility and logistics"
```

---

### Task 2: A row that is not a plain number can follow the number row's rules

`RecordNumberRow` keeps three behaviours to itself: the number already on show stands for the value behind it (`_parse`), a row with unreadable text marks its card (`_report`, `_clearMark`), and a row asked to show itself scrolls into view (`_answerReveal`). The visibility input needs all three and cannot be a `RecordNumberRow`: its value is one of three shapes, not a `double?`. Lift them out; `RecordNumberRow` then uses them and behaves as before.

**Files:**
- Create: `lib/shared/widgets/record_editing/record_field_marks.dart`
- Modify: `lib/shared/widgets/record_editing/record_number_row.dart`
- Test: `test/shared/widgets/record_editing/record_field_marks_test.dart`
- Test: `test/shared/widgets/record_editing/record_number_row_test.dart` (unchanged, must still pass)

**Interfaces:**
- Consumes: `RecordEditScope.maybeOf<T>`, `RecordEditController.setFieldInvalid`, `revealRequest`, `revealHandled` (plan 2).
- Produces:

```dart
// record_number_row.dart, top level
/// The stored value a number typed into a row stands for. The number the row
/// already shows stands for the value behind it, which may carry more than
/// the row can show: [current] (the sitting's) first, then [stored]. Any
/// other number is [fromDisplay] of what was typed.
double storedValueOfTyped(
  double typed, {
  required double? current,
  required double? stored,
  required double? Function(double value) shownNumber,
  required double Function(double typed) fromDisplay,
});

// record_field_marks.dart
/// For the State of a row that edits one field of a sitting as text.
mixin RecordFieldMarks<T, W extends StatefulWidget> on State<W> {
  /// The field this row edits, as the page's controller knows it.
  String get markCardId;
  String get markFieldId;

  /// Tells the controller whether this row's text cannot be read.
  @protected
  void reportUnreadable(bool unreadable);

  /// Withdraws a mark this row made. Called by the mixin on dispose; call it
  /// with the old ids when the row is given another field.
  @protected
  void withdrawMark({String? cardId, String? fieldId});
}
```

  The mixin overrides `didChangeDependencies` (keeps the controller; answers a reveal request that names its card and field, once per serial, with `Scrollable.ensureVisible(context, alignment: 0.3, duration: const Duration(milliseconds: 200))` after the frame, then `revealHandled`) and `dispose` (withdraws its mark). It marks only while unlocked, as `setFieldInvalid` already requires.

- [ ] **Step 1: Write the failing tests**

```dart
// record_field_marks_test.dart
group('storedValueOfTyped', () {
  double? shown(double v) => v.roundToDouble();          // a row with no decimals
  test('the number shown for the sitting value stands for it', () {
    expect(storedValueOfTyped(12, current: 12.4, stored: 9.0, shownNumber: shown, fromDisplay: (t) => t), 12.4);
  });
  test('else the number shown for the stored value stands for that', () {
    expect(storedValueOfTyped(9, current: 12.4, stored: 9.3, shownNumber: shown, fromDisplay: (t) => t), 9.3);
  });
  test('any other number is converted as typed', () {
    expect(storedValueOfTyped(40, current: 12.0, stored: 12.0, shownNumber: shown, fromDisplay: (t) => t * 0.3048), closeTo(12.192, 1e-9));
  });
  test('with nothing in the sitting or stored, it is converted as typed', ...);
});

// A test row: a TextField in a State that mixes in RecordFieldMarks and reports
// text containing 'x' as unreadable. Pumped under RecordEditScope with a real controller.
testWidgets('unreadable text marks the card; readable text clears it', ...);
testWidgets('disposed while unreadable: the mark is cleared', ...);
testWidgets('a reveal request naming its field scrolls it into view and is withdrawn', ...);
// the row sits below the fold of a 300 px scroll view; controller.closeCard(card) with the
// row marked: after pumpAndSettle the row is inside the viewport and revealRequest is null.
testWidgets('a request naming another field is left for that field', ...);
testWidgets('locked, a report marks nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/record_field_marks_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement, and move `RecordNumberRow` onto both**

`_RecordNumberRowState` mixes in `RecordFieldMarks<T, RecordNumberRow<T>>` and loses `_controller`, `_answeredSerial`, `_answerReveal` and `_clearMark`. Its `_parse` calls `storedValueOfTyped`. `didUpdateWidget` calls `withdrawMark(cardId: old.field.cardId, fieldId: old.field.id)` where it called `_clearMark(oldWidget)`.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/widgets/record_editing/` then `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/ test/architecture/ test/shared/`
Expected: PASS, every plan 2 number row and card test included.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "refactor(shared): share the number row's typed-number rule and unreadable marks"
```

---

### Task 3: The Details fields

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields_test.dart`

**Interfaces:**
- Consumes: the clear flags (Task 1); `EditField`, `EditSession` (plan 1); `StoredVisibility` (`widgets/visibility_input/visibility_entry.dart:14`); `VisibilityScale.rangeFor`, `VisibilityBand` (`lib/core/domain/visibility/visibility_scale.dart`); `trimmedOrNull` (`lib/core/text/blank_text.dart`); `listEquals`.
- Produces:

```dart
// All have cardId DiveDetailSectionId.details.name.
final EditField<Dive, List<String>> diveTypeIdsField;        // 'diveTypeIds', equals: listEquals
final EditField<Dive, Trip?> diveTripField;                  // 'trip', equals: same id
final EditField<Dive, DiveCenter?> diveCenterField;          // 'diveCenter', equals: same id
final EditField<Dive, String?> diveOperatorField;            // 'diveOperator'
final EditField<Dive, String?> diveBoatNameField;            // 'boatName'
final EditField<Dive, String?> diveBoatCaptainField;         // 'boatCaptain'
final EditField<Dive, List<String>> diveCourseIdsField;      // 'courseIds', equals: the same set
final EditField<Dive, StoredVisibility> diveVisibilityField; // 'visibility'
final EditField<Dive, WaterType?> diveWaterTypeField;        // 'waterType'
final EditField<Dive, bool> diveExcludedFromStatsField;      // 'excludedFromStats'
final EditField<Dive, bool> diveExcludedFromGasStatsField;   // 'excludedFromGasStats'

/// What an emptied Precise input means: no measurement. A dive stored with a
/// range or a bucket goes back to it; one stored with a measurement has none.
StoredVisibility visibilityWithNoMeasurement(StoredVisibility stored);

/// What picking [band] in Range means on [scale]; null (the chip turned off)
/// is no visibility.
StoredVisibility visibilityForBand(VisibilityBand? band, VisibilityScale scale);

/// The day the trip suggestion is asked for: the dive's own, read from the
/// wall-clock components of its entry time.
DateTime diveTripSuggestionDay(Dive dive);
```

  The writes that are not the obvious `copyWith` with its clear flag:
  - `diveTripField.write`: null gives `copyWith(clearTrip: true, clearTripId: true)`; a trip gives `copyWith(trip: trip, tripId: trip.id)`. Its `read` is `dive.trip`.
  - `diveCenterField.write`: null gives `clearDiveCenter: true`.
  - The three text fields store `trimmedOrNull(value)`, and compare trimmed, as `diveSurfaceConditionsField` does (`dive_environment_fields.dart:138`).
  - `diveVisibilityField.read` is `StoredVisibility.of`. Its `write` sets all four columns from the value: `visibility: v.legacy`, `visibilityMeters: v.meters`, `visibilityMinMeters: v.range?.minM`, `visibilityMaxMeters: v.range?.maxM`, each with its clear flag when null.
  - The two list fields copy the list they are given (`List.unmodifiable`).

- [ ] **Step 1: Write the failing tests**

```dart
test('every field belongs to the Details card', ...);          // cardId == 'details', ids unique
test('every nullable field clears with null', ...);            // trip, center, three texts, water type
test('writing a trip sets the trip and its id', () {
  final d = diveTripField.write(dive, tripA);
  expect((d.trip?.id, d.tripId), ('a', 'a'));
});
test('writing no trip clears the trip and its id', () {
  final d = diveTripField.write(dive.copyWith(trip: tripA, tripId: 'a'), null);
  expect((d.trip, d.tripId), (null, null));
});
test('the same trip with other dates is not a change', () {
  // tripA and tripA.copyWith(endDate: later): diveTripField.same is true.
});
test('a pending trip is dropped when the stored dive catches up', () {
  final s = EditSession(dive)..set(diveTripField, tripA);
  s.rebase(dive.copyWith(trip: tripA.copyWith(endDate: later), tripId: 'a'));
  expect(s.isDirty, isFalse);
});
test('operator, boat and captain are trimmed, and blank is null', ...);
test('dive types: the same ids in the same order are not a change; another order is', () {
  final s = EditSession(dive.copyWith(diveTypeIds: ['wreck', 'night']));
  s.set(diveTypeIdsField, <String>['wreck', 'night']);
  expect(s.isDirty, isFalse);
  s.set(diveTypeIdsField, <String>['night', 'wreck']);
  expect(s.isDirty, isTrue);
});
test('courses compare as a set: another order is not a change', ...);

group('visibility', () {
  test('reads a measurement, a range and a bucket', ...);
  test('a stale range beside a measurement reads as measured', ...);
  test('writing a measurement clears the range and the bucket', ...);
  test('writing a range clears the measurement and the bucket', ...);
  test('writing none clears all four columns', ...);
  test('an untouched dive with a stale range is not a change', () {
    // visibilityMeters 12 and a range both stored: set(field, StoredVisibility.of(dive)) leaves it clean.
  });
  test('no measurement goes back to a stored range or bucket', () {
    expect(visibilityWithNoMeasurement(StoredVisibility(range: r)), StoredVisibility(range: r));
    expect(visibilityWithNoMeasurement(const StoredVisibility(legacy: Visibility.good)).legacy, Visibility.good);
    expect(visibilityWithNoMeasurement(const StoredVisibility(meters: 12)), StoredVisibility.none);
  });
  test('a band is its range on the scale; no band is none', ...);
});

test('the two statistics switches are independent', () {
  // master on then off leaves a gas-only choice as it was.
});
test('the suggestion day is the entry time\'s own day', () {
  // entryTime DateTime.utc(2026, 3, 9, 23, 30): DateTime(2026, 3, 9), in any time zone.
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the fields and the three helpers**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields_test.dart
git commit -m "feat(dive-log): the values the Details card edits, as fields of the sitting"
```

---

### Task 4: Saving a sitting stretches the trip, in the same transaction

The form stretches the trip after the dive is saved, in a `try` that never undoes the save (`dive_edit_page.dart:6997`). The spec puts the stretch in the sitting's transaction and History entry. The rule is "did this save touch the trip", which needs the dive as stored and as merged; both exist only inside `DiveEditSaveService.save`, so the rule goes there.

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_edit_save_provider.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (`FakeSave`)
- Test: `test/features/dive_log/data/services/dive_edit_save_service_test.dart`

**Interfaces:**
- Consumes: `diveSaveTouchesTrip` and `TripDateStretch` (`lib/features/trips/domain/services/trip_date_stretch.dart`); `TripRepository.stretchToCoverDives(List<String> diveIds)` (`trip_repository.dart:667`), which opens a transaction of its own that nests; `tripRepositoryProvider` (`trip_providers.dart:90`); the fields (Task 3).
- Produces:

```dart
DiveEditSaveService(this._diveRepo, this._tripRepo);

Future<({Dive before, Dive after, List<TripDateStretch> tripDateStretches})?> save({
  required String diveId,
  required Dive Function(Dive stored) apply,
  required Iterable<String> changedCardIds,
  Future<void> Function()? alsoWrite,
});
```

  Inside the transaction, after `updateDive(merged)` and before `alsoWrite`: when `diveSaveTouchesTrip(tripId: merged.tripId ?? merged.trip?.id, previousTripId: stored.tripId ?? stored.trip?.id, date: merged.effectiveEntryTime, previousDate: stored.effectiveEntryTime)`, `tripDateStretches` is `await _tripRepo.stretchToCoverDives([diveId])`; otherwise it is empty. `FakeSave` gains a settable `tripDateStretches` and returns it.

- [ ] **Step 1: Write the failing tests**

Seed trips with `TripRepository().createTrip(...)`, built in `setUp`; `test/features/dive_log/presentation/pages/dive_edit_trip_stretch_test.dart` shows a trip that a dive falls outside of.

```dart
test('a cleared trip is stored with no trip', () async {
  // the stored dive is on trip A.
  await service.save(diveId: 'dive', apply: (d) => diveTripField.write(d, null), changedCardIds: ['details']);
  final after = await stored();
  expect((after.trip, after.tripId), (null, null));
});
test('a dive put on a trip stretches it, in the one History entry', () async {
  // trip A runs 1 to 3 March; the dive is on 9 March and on no trip.
  final result = await service.save(diveId: 'dive', apply: (d) => diveTripField.write(d, tripA), changedCardIds: ['details']);
  expect(result!.tripDateStretches.single.tripId, 'a');
  expect((await trips.getTripById('a'))!.endDate, <9 March>);
  // One operation, counted as the file's 'one sitting is one operation' test counts it,
  // and [for (final e in await logEvents(db)) e['table_name']] holds 'dives' and 'trips'.
});
test('a dive whose trip was not touched does not stretch it', () async {
  // the stored dive is already on trip A and outside its dates.
  final result = await service.save(diveId: 'dive', apply: (d) => d.copyWith(notes: 'x'), changedCardIds: ['notes']);
  expect(result!.tripDateStretches, isEmpty);
  expect((await trips.getTripById('a'))!.endDate, <3 March>);
});
test('a failing alsoWrite rolls the stretch back with the dive', () async {
  await expectLater(
    service.save(diveId: 'dive', apply: (d) => diveTripField.write(d, tripA),
        changedCardIds: ['details'], alsoWrite: () async => throw StateError('no')),
    throwsStateError);
  expect((await trips.getTripById('a'))!.endDate, <3 March>);
  expect((await stored()).trip, isNull);
});
test('a tank linked to the old trip\'s cylinder loses the link when the trip changes', () async {
  // the stored dive is on trip A with a tank whose tripCylinderId is one of A's.
  await service.save(diveId: 'dive', apply: (d) => diveTripField.write(d, tripB), changedCardIds: ['details']);
  expect((await stored()).tanks.single.tripCylinderId, isNull);
});
test('dive types and courses are written with the dive', () async {
  // apply sets diveTypeIds ['wreck', 'night']: read back in that order. courseIds ['c2', 'c1']
  // are read back as the writer orders them (by start date, then name).
});
test('a cleared visibility, water type, dive center and operator are stored as null', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: the stretch tests FAIL (the constructor and the result do not have the new parts). A test that passes at once (the tank link, the cleared values) is checked by breaking what it pins and seeing it fail, then restored.

- [ ] **Step 3: Implement, and update the provider and `FakeSave`**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/dive_edit_save_service.dart lib/features/dive_log/presentation/providers/dive_edit_save_provider.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart
git commit -m "feat(dive-log): stretch a trip's dates inside the sitting that put the dive on it"
```

---

### Task 5: The Details read card

Three things the read card needs before it can have an editor. Its title must be the shared header, or it gets no pencil. Its courses are read from a provider by dive id (`DiveCourseRows`, `dive_course_rows.dart:22`), so after Done the card would show the stored courses, not the sitting's. And the rows nothing edits are needed by the editor too.

Take the pictures for the pull request's "before" first: the Details read card, light and dark, for a dive with a trip, a course and an exclusion.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_course_rows.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_read_card_test.dart`

**Interfaces:**
- Consumes: `RecordCardHeader` (plan 1), `HeaderInfoButton` (`lib/shared/widgets/info_sheet/info_button.dart:50`), as `DiveAltitudeSection` uses them (`dive_detail_altitude_section.dart:66`).
- Produces:

```dart
// dive_details_derived_rows.dart
/// The rows of the Details card that nothing on the card edits, in the
/// card's order: the imported buddy and dive master text, air consumption,
/// gradient factors, the dive computer and the surface interval.
class DiveDetailsDerivedRows extends ConsumerWidget {
  const DiveDetailsDerivedRows({super.key, required this.dive});
  final Dive dive;
}

/// What the Details card says about a dive left out of statistics, or null
/// for a dive that is counted. The master switch wins: it implies the other.
String? diveStatisticsExclusion(AppLocalizations l10n, Dive dive);

// dive_course_rows.dart
/// [courseIds], when given, are the courses to show, in that order: the
/// dive as the page holds it, which during a sitting is ahead of what is stored.
const DiveCourseRows({super.key, required this.diveId, this.courseIds});
```

  `DiveCourseRows` resolves each id from `coursesForDiveProvider(diveId)` first and watches `courseListNotifierProvider` only when an id is missing there; an id neither knows is left out.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the title is the shared header, with its info button and no pencil', ...);
// DiveDetailsSection alone: one RecordCardHeader, one HeaderInfoButton, no Icons.edit_outlined.
testWidgets('inside an unlocked frame the header gains its pencil', ...);
// RecordEditScope(unlocked controller) > RecordCardFrame(card: <a Details EditCard>) > DiveDetailsSection.
testWidgets('a counted dive has no statistics row', ...);
testWidgets('an excluded dive says so', ...);
// excludedFromStats: the row's label is diveLog_edit_group_statistics and its value diveLog_edit_summary_excluded.
testWidgets('a gas-only exclusion says that', ...);        // diveLog_edit_summary_gasExcluded
testWidgets('with both on, the master one is named', ...);
testWidgets('courses are drawn from the dive, in its order', ...);
// coursesForDiveProvider gives [c1]; courseListNotifierProvider holds c1 and c2;
// the dive has courseIds ['c2', 'c1']: two rows, c2's name above c1's.
testWidgets('a dive with no courses draws none, whatever is stored', ...);
testWidgets('the rows nothing edits keep their order', ...);
// buddy text, SAC, gradient factors, computer, surface interval: compare dy of each label.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_read_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`DiveDetailsSection`: the `InfoTitleRow` becomes `RecordCardHeader(title: l10n.diveLog_detail_section_details, trailing: HeaderInfoButton(title: <the same>, content: <the builder it has today>))`. `DiveCourseRows` is given `courseIds: dive.courseIds`. Everything from the legacy buddy rows down to the surface interval moves, unchanged, into `DiveDetailsDerivedRows` with the helpers it uses (`_buildGasConsumptionRows` and the three computer row builders). `_linkRowContent` is used on both sides of the split (the trip and center rows stay, the linked computer row moves), so it becomes a small widget, `DiveDetailLinkRow({required label, required title, subtitle})`, in `dive_details_derived_rows.dart`, and both files use it. After the derived rows: `if (diveStatisticsExclusion(l10n, dive) case final text?) DiveDetailRow(label: l10n.diveLog_edit_group_statistics, value: text)`.

The read card is otherwise untouched: same rows, same order, same providers.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then every `test/features/dive_log/presentation/pages/dive_detail*_test.dart` file, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_read_card_test.dart
git commit -m "feat(dive-log): the Details card shows an exclusion from statistics, and its courses from the dive"
```

---

### Task 6: The visibility row

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row_test.dart`

**Interfaces:**
- Consumes: `diveVisibilityField`, `visibilityWithNoMeasurement`, `visibilityForBand` (Task 3); `storedValueOfTyped`, `RecordFieldMarks` (Task 2); `FieldTextBinding`, `FieldValue`, `FieldUnreadable` (plan 2); `VisibilityInput` (`widgets/visibility_input/visibility_input.dart`), `visibilityEntryCaption`, `VisibilityInputMode` (`visibility_entry.dart`); `visibilityInputModeProvider`; `readNumber`, `numberValidator`; `formatFixedForInput`; `UnitFormatter.convertDepth`, `depthToMeters`, `depthSymbol`.
- Produces:

```dart
/// The visibility input of the Details card: a band or a measured distance,
/// bound to the sitting.
class DiveVisibilityRow extends ConsumerStatefulWidget {
  const DiveVisibilityRow({super.key, required this.session});
  final EditSession<Dive> session;
}
```

  What it does:
  - **Mode** is view state. It starts as `session.valueOf(diveVisibilityField).naturalMode ?? ref.read(visibilityInputModeProvider)`. Changing it sets nothing in the sitting.
  - **Precise** is a `FieldTextBinding<Dive, StoredVisibility>`. `format` is the measurement in the diver's depth unit with no decimals (`formatFixedForInput(units.convertDepth(m), 0)`), and empty when there is none. `parse` reads the text with `readNumber(text, allowNegative: false)`: blank is the sitting's value when that holds no measurement (an empty field is then no change), and otherwise `visibilityWithNoMeasurement(StoredVisibility.of(session.stored))`; unreadable is `FieldUnreadable()`; a number is `FieldValue(StoredVisibility(meters: storedValueOfTyped(typed, current: <the sitting's meters>, stored: <the stored meters>, shownNumber: <the number `format` shows for a value>, fromDisplay: units.depthToMeters)))`.
  - **Range**: the selected chip is `scale.bandMatching(value.range)` for the sitting's value, so no touched flags are kept. A chip tapped sets `visibilityForBand(band, scale)`.
  - **Caption**: `visibilityEntryCaption(mode:, preciseMeters: value.meters, band: <the selected chip>, preciseTouched: false, rangeTouched: false, original: value, scale:, l10n:, units:)`, with `value` the sitting's. That names the band a measurement falls in, the range a chip stands for, or the range or bucket the dive holds that the showing input cannot show.
  - **Unreadable text** is reported with `reportUnreadable`, under field id `'visibility'`. Switching to Range while the text is unreadable puts the sitting's value back in the text (`replaceTextKeepingCaret(format(value))`), which clears the mark: the text was never a value, and its row is no longer on screen to be fixed.
  - It rebuilds on the session, the units and `settingsProvider.select((s) => s.visibilityScale)`, and calls the binding's `resync()` when the units change.

- [ ] **Step 1: Write the failing tests**

Pumped under `ProviderScope` (settings overridden for metric or imperial, and for the visibility scale) and `RecordEditScope` with a real unlocked controller. `type(tester, '40')` enters `'4'` then `'40'`, pumping between.

```dart
group('precise', () {
  testWidgets('opens on a measured dive showing it, and leaves the sitting clean', ...);
  // metric, 12.4 m: the field shows '12'; tap it; controller.isDirty false.
  testWidgets('metric: the number shown, typed back, is no change', (tester) async {
    // 12.4 m. type '1' -> 1 m, dirty. type '12' -> 12.4 m again, clean.
  });
  testWidgets('imperial: values that show alike are told apart', (tester) async {
    // 12 m shows '39'. type '40' -> closeTo(12.192). type '39' -> exactly 12, clean.
  });
  testWidgets('a finer value than the one shown is a change', ...);   // '12.6' over 12.4 m -> 12.6
  testWidgets('a decimal comma is read', ...);                        // '12,5' -> 12.5 m
  testWidgets('emptying a measurement clears it', ...);               // 12 m, '' -> StoredVisibility.none
  testWidgets('typing and emptying over a stored range goes back to the range', (tester) async {
    // stored range, Precise showing: type '15' -> 15 m; '' -> the stored range, clean.
  });
  testWidgets('typing and emptying over a stored bucket goes back to the bucket', ...);
  testWidgets('unreadable text marks the card and leaves the sitting alone', ...);
  // '1.2.3': controller.invalidCardIds == {'details'}; isDirty false; the row shows numberInput_invalidNumber.
  testWidgets('a negative number is unreadable', ...);                // '-5'
  testWidgets('switching to Range drops unreadable text and its mark', (tester) async {
    // '1.2.3', tap Range: invalidCardIds empty. Tap Precise: the field shows the sitting's value.
  });
  testWidgets('dropping unreadable text keeps a range picked in this sitting', (tester) async {
    // stored 12 m. Tap Range, tap Good, tap Precise (the field is empty), type '1.2.3',
    // tap Range: the sitting still holds Good's range.
  });
  testWidgets('a refused Done scrolls the row into view', ...);
});

group('range', () {
  testWidgets('a stored range on this scale selects its chip, and the sitting is clean', ...);
  testWidgets('turning the chip off clears the visibility; on again is clean', ...);
  testWidgets('a range stored under another scale selects no chip and is kept', ...);
  // the caption is that range formatted; nothing tapped: clean.
  testWidgets('a stored bucket shows as the caption and is kept until a chip is tapped', ...);
  testWidgets('a chip replaces a measurement', ...);                  // 12 m, tap Good -> the range, meters null
});

group('the switch', () {
  testWidgets('a dive with a measurement opens in Precise, one with a range or bucket in Range', ...);
  testWidgets('a dive with none opens in the remembered mode', ...);
  testWidgets('switching alone changes nothing', ...);
  testWidgets('a number typed in Precise survives a look at Range', (tester) async {
    // type '12', tap Range: session value is 12 m still, no chip selected.
  });
});

testWidgets('a change of units reshows the value and stays clean', ...);
testWidgets('a rebase to another visibility is followed while untouched', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

The State mixes in `RecordFieldMarks<Dive, DiveVisibilityRow>` and builds `VisibilityInput(mode:, onModeChanged:, controller: binding.controller, depthSymbol: units.depthSymbol, inputValidator: numberValidator(context, allowNegative: false), onPreciseChanged: (_) {}, band:, onBandChanged:, caption:)` inside a `ListenableBuilder` on the session. The binding listens to its controller itself, so `onPreciseChanged` has nothing to do.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row_test.dart
git commit -m "feat(dive-log): a visibility input bound to the sitting"
```

---

### Task 7: The trip and dive center rows

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows_test.dart`

**Interfaces:**
- Consumes: `diveTripField`, `diveCenterField`, `diveTripSuggestionDay` (Task 3); `FormRow.picker`; `TripPickerSheet` (`trip_picker.dart:161`); `newTripForDiveEdit` and `SelectionDiveFacts` (`new_trip_from_selection.dart:37`, `trip_draft.dart:7`); `tripRepositoryProvider`, `tripForDateProvider` (`trip_providers.dart:392`); `DiveCenterPickerSheet` (`dive_center_picker.dart:17`); `resolveDiveCenterPickerReference` (`dive_center_picker_ranking.dart:44`); `diveCenterRepositoryProvider`; `UnitFormatter.formatDateRange`.
- Produces:

```dart
/// The trip row of the Details card: the trip, its dates under it, and, for
/// a dive on no trip, the trip its day falls in as a suggestion.
class DiveTripRow extends ConsumerStatefulWidget {
  const DiveTripRow({super.key, required this.session});
  final EditSession<Dive> session;
}

/// The dive center row of the Details card, with where the center is.
class DiveCenterRow extends ConsumerStatefulWidget {
  const DiveCenterRow({super.key, required this.session});
  final EditSession<Dive> session;
}
```

  Both follow the form (`dive_edit_page.dart:3291-3619`), with these values fixed:
  - Rows: `FormRow.picker(label: l10n.diveLog_edit_row_trip` or `_row_diveCenter, value: <name>, placeholder: l10n.diveLog_edit_row_notSet, onTap: <open the sheet>, onClear: <null when nothing is set, else set null>)`.
  - Trip caption: `units.formatDateRange(trip.startDate, trip.endDate, l10n: l10n)`. Center caption: `center.displayLocation`. Both in the form's caption style and padding (`trip_section.dart:58`).
  - Suggestion, only while the sitting has no trip: `ref.watch(tripForDateProvider(diveTripSuggestionDay(session.working)))`; when it has a trip, the line `l10n.diveLog_edit_tripSuggested(name)` and a `TextButton` `l10n.diveLog_edit_tripUse` that sets it. Nothing while it loads or fails.
  - Sheets open with `showModalBottomSheet<String>` in a `DraggableScrollableSheet` (0.7, 0.5, 0.9), as the form's.
  - New trip: `newTripForDiveEdit(context, ref, <facts>)`, then `getTripById`, then set. The facts are one `SelectionDiveFacts(diveId: '', diveDateTime: DateTime.utc(e.year, e.month, e.day), tripId: <the sitting's>, siteRegion: working.site?.region, siteCountry: working.site?.country, diveCenterName: working.diveCenter?.name)`, with `e` the working dive's `effectiveEntryTime`.
  - New center: `context.push<String>('/dive-centers/new')`, then `getDiveCenterById`, then set.
  - A trip or a center made this way exists at once and outlives a cancelled sitting, as the spec says of every record made from a picker. Only the dive's link to it is held.
  - Center picker reference: `resolveDiveCenterPickerReference(site: working.site, entryLocation: working.entryLocation, exitLocation: working.exitLocation)`.
  - After every `await`: nothing is set unless `mounted`, and the session is neither disposed nor frozen. Repositories are read before the first `await`.

- [ ] **Step 1: Write the failing tests**

Pumped under a `GoRouter` whose `/trips/new` and `/dive-centers/new` are stub pages with a button that pops an id, with `allTripsProvider`, `tripForDateProvider`, `allDiveCentersProvider` and the two repositories overridden by fakes.

```dart
testWidgets('a dive on a trip shows its name and its dates', ...);
testWidgets('clearing the trip sets none, and the row says Not set', ...);
// session.working.trip and .tripId both null.
testWidgets('picking a trip in the sheet sets it and closes the sheet', ...);
testWidgets('a dive on no trip is offered the trip its day falls in', ...);
// tripForDateProvider is asked for diveTripSuggestionDay(dive); 'Use' sets it; the suggestion goes.
testWidgets('a dive on a trip is offered none', ...);
testWidgets('a new trip made from the sheet is set when its page returns', ...);
testWidgets('a new trip that returns after the sitting was cancelled sets nothing', (tester) async {
  // open the new-trip page; controller.lock(); pop with an id; pump.
  expect(tester.takeException(), isNull);
});
testWidgets('a new trip that returns while the sitting is saved sets nothing', ...);
// session.freeze() before the pop: valueOf(diveTripField) unchanged.
testWidgets('the row gone before its lookup answers sets nothing', ...);
// gate getTripById; replace the row with SizedBox; release: no exception, session clean.

testWidgets('a dive center shows its name and where it is', ...);
testWidgets('clearing the center sets none', ...);
testWidgets('picking a center sets it', ...);
testWidgets('the picker is given the site as its reference', ...);
// a dive with a site that has coordinates: the sheet's reference.source is DiveCenterReferenceSource.site.
testWidgets('a new center made from the sheet is set when its page returns', ...);
testWidgets('a new center that returns after the sitting ended sets nothing', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows_test.dart
git commit -m "feat(dive-log): pick a dive's trip and dive center in the sitting"
```

---

### Task 8: The Details editor, and its card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6 and 7; `DiveTypeMultiSelectField` (`widgets/dive_type_multi_select_field.dart:23`); `CourseMultiSelectField` (`lib/features/courses/presentation/widgets/course_picker.dart:16`); `SuggestedTextRow` and `DiveTextSuggestionField`; `EnumPickerRow(hint:)`; `FormRow.display`, `FormRow.toggle`; `FormOverline`; `diveModeLabel`.
- Produces:

```dart
class DiveDetailsCardEditor extends ConsumerStatefulWidget {
  const DiveDetailsCardEditor({super.key, required this.session});
  final EditSession<Dive> session;
}
```

  `diveEditCards[details]`: title `l10n.diveLog_detail_section_details`; `isEmpty: (_) => false` (the card is always on the page); no `leading`; editor `DiveDetailsCardEditor`.

- [ ] **Step 1: Write the failing tests**

```dart
// dive_edit_cards_test.dart
test('are Notes, Tags, Altitude, Environment and Details', ...);
test('Details is never left out', ...);

// dive_details_card_test.dart, pumped as the Environment editor's tests are, with the
// providers the pickers watch overridden (dive types, courses, trips, centers, suggestions).
testWidgets('rows show in the order of the read card', ...);
// dive types, dive mode, trip, dive center, operator, boat, captain, courses, visibility,
// average depth, water type, then the rows nothing edits, then Statistics and its two
// switches. Compare dy of each label, for a dive that has every one of them.
testWidgets('opening it and touching nothing leaves the sitting clean', ...);
// a dive with every value set, then one with none; metric and imperial.
testWidgets('dive mode and average depth cannot be typed in', ...);
// diveModeLabel and units.formatDepth(avgDepth) are found; no TextField holds either.
testWidgets('a dive with no average depth has no such row', ...);
testWidgets('the dive types picker is offered the stored types', ...);
// DiveTypeMultiSelectField.keepTypeIds == session.stored.diveTypeIds.
testWidgets('changing the dive types sets them in order', ...);
testWidgets('typing an operator sets it trimmed; emptying it clears it', ...);
testWidgets('boat and captain do the same', ...);
testWidgets('choosing courses sets them', ...);
testWidgets('water type shows the dive\'s own value', ...);
testWidgets('with none of its own, the row hints the site\'s and the sitting has none', ...);
// site.waterType salt, dive.waterType null: the salt name shows as the hint;
// session.valueOf(diveWaterTypeField) is null; isDirty false.
testWidgets('picking a water type sets it; clearing it goes back to the hint', ...);
testWidgets('the gas switch shows on and cannot be changed while the master switch is on', ...);
testWidgets('turning the master switch off brings back a gas-only choice', ...);
testWidgets('a value arriving underneath is followed, and the caret stays put', ...);
// focus the operator field with the caret at 2; controller.storedChanged(dive with another
// operator): the text is the new one and the selection is still at 2.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_test.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`DiveDetailsCardEditor` builds inside a `ListenableBuilder` on the session, and keeps three `FieldTextBinding<Dive, String?>` for operator, boat and captain (`format: (v) => v ?? ''`, `parse: (t) => FieldValue(trimmedOrNull(t))`), rebuilt in `didUpdateWidget` when the session changes and disposed with the State, as `DiveEnvironmentCardEditor` does. In order:

1. `DiveTypeMultiSelectField(selectedTypeIds: session.valueOf(diveTypeIdsField), keepTypeIds: session.stored.diveTypeIds, onChanged: (ids) => session.set(diveTypeIdsField, ids))`, in the form's padding (`EdgeInsets.fromLTRB(14, 10, 14, 10)`).
2. `FormRow.display(label: l10n.diveLog_diveMode_title, value: diveModeLabel(l10n, working.diveMode))`.
3. `DiveTripRow(session: session)`.
4. `DiveCenterRow(session: session)`.
5. Three `SuggestedTextRow`: `diveLog_edit_row_diveOperator` with `DiveTextSuggestionField.diveOperator`, `_row_boatName` with `.boatName`, `_row_boatCaptain` with `.boatCaptain`.
6. `CourseMultiSelectField(selectedCourseIds: session.valueOf(diveCourseIdsField), labelText: l10n.diveLog_edit_section_trainingCourses, onChanged: (ids) => session.set(diveCourseIdsField, ids))`, in the same padding as the dive types.
7. `DiveVisibilityRow(session: session)`.
8. When the working dive has an average depth: `FormRow.display(label: l10n.diveLog_detail_label_avgDepth, value: units.formatDepth(working.avgDepth))`.
9. `EnumPickerRow<WaterType>(label: l10n.diveLog_edit_label_waterType, value: session.valueOf(diveWaterTypeField), values: WaterType.values, displayName: (v) => v.localizedName(l10n), hint: working.site?.waterType?.localizedName(l10n), onChanged: (v) => session.set(diveWaterTypeField, v))`.
10. `DiveDetailsDerivedRows(dive: working)`, inset by the form rows' 14 px so its labels line up with theirs.
11. `FormOverline(label: l10n.diveLog_edit_group_statistics)`, then the two `FormRow.toggle` exactly as `StatisticsSection` builds them (`statistics_section.dart:61`): the same labels, help texts and keys, the gas one showing `excludedFromStats || excludedFromGasStats` and `enabled: !excludedFromStats`.

Keep the file under 400 lines; the trip and center rows are already their own file.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): edit the Details card in place"
```

---

### Task 9: Nothing moves while Details is open

Plan 2 made the section list decide which cards are present from `presence` (the controller's `layoutRecord`) for the cards that can be edited. Two cards with no editor decide for themselves from values Details now edits, and so do two pairs:

- Tide reads the water type (`diveTideRequest`, `dive_detail_section_gates.dart:118`): fresh water has no tides. The Surface GPS and Tide pair asks `watchHasTide(ref, dive)` (`dive_detail_section_list.dart:535`).
- Signatures shows its training signature for a dive with a course (`dive_detail_signature_section.dart:26`), and the Buddies and Signatures pair forms on `dive.courseIds` (`dive_detail_section_list.dart:566`).

With Details open, switching to fresh water or adding a first course would bring a card in, take one out, or form a pair, above the editor.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (`_sectionContent` cases `tide` and `signatures`; `_buildPairCards` cases `surfaceGps` and `buddies`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart`

**Interfaces:**
- Consumes: `presence` as `_sectionContent` and `_buildPairCards` already receive it; the Details card (Task 8).
- Produces: no new names. The rule for later plans: a card with no editor that decides for itself whether it shows is handed `presence` as its dive.

- [ ] **Step 1: Write the failing tests**

Tide data is supplied the way `test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart` supplies it. `tester.view` is restored with `addTearDown`.

```dart
testWidgets('unlocked, Details has a pencil and opens where it sits', ...);
testWidgets('at 1200 px Details opens in its slot beside Environment', ...);
// same dy as Environment, smaller dx, before and after opening.
testWidgets('hidden by the diver, Details is a dashed chip and opens at its place', ...);
testWidgets('in the folding layout the pencil opens it and the row does not fold it', ...);
testWidgets('switching to fresh water keeps the Tide card until Done', (tester) async {
  // sections: tide above details; a salt-water dive with tide data. Open Details; note the
  // editor's top. session.set(diveWaterTypeField, WaterType.fresh); pump: DiveTideSection is
  // still there and the editor's top has not moved. Done: the Tide card is gone.
});
testWidgets('the Surface GPS and Tide pair does not split while Details is open', ...);
testWidgets('adding a first course keeps Signatures as it was until Done', (tester) async {
  // sections: signatures above details; a dive with a buddy and no course. Open Details;
  // session.set(diveCourseIdsField, <String>['c1']); pump: no training signature card, the
  // editor's top has not moved. Done: the training signature card is there.
});
testWidgets('the Buddies and Signatures pair does not form while Details is open', ...);
// a dive with no buddies and no course at 1200 px.
testWidgets('picking a type, a trip and a center does not rebuild the editor', ...);
// tester.state(find.byType(DiveDetailsCardEditor)) is identical after each.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart`
Expected: the Tide, Signatures and two pair tests FAIL. The others pin what Task 8 and plan 2 already give; check each by breaking what it pins.

- [ ] **Step 3: Implement**

`DiveTideSection(dive: presence, ...)` and `DiveSignaturesSection(dive: presence)` in both the single path and the pairs; `watchHasTide(ref, presence)`; `presence.courseIds.isEmpty`. `diveHasLocationMap(dive)` stays as it is: nothing in this plan changes a location.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_editing_test.dart
git commit -m "fix(dive-log): keep Tide and Signatures where they are while a card is edited"
```

---

### Task 10: The page, end to end

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting`)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_details_test.dart` (new; it uses `dive_detail_page_unlock_harness.dart`, and `dive_detail_page_unlock_test.dart` is already long)

**Interfaces:**
- Consumes: everything above; `tripDateStretchMessage` (`lib/features/trips/presentation/helpers/trip_date_stretch_message.dart`); `coursesForDiveProvider`, `courseDivesProvider`, `courseDiveCountProvider` (`course_providers.dart`); `visibilityInputModeProvider` and `StoredVisibility.modeToRemember`.
- Produces: no new names.

  After `service.save` returns a result, and after the two refreshes plan 2 left there, `_saveSitting` does three more things, each in a `try` of its own that logs and goes on:
  1. **The trip message.** `tripDateStretchMessage(l10n, units, result.tripDateStretches)`; when not null, a snackbar. The messenger, `l10n` and `units` are read before the first `await`.
  2. **The courses.** When `result.before.courseIds` and `result.after.courseIds` differ and the page is still mounted: invalidate `coursesForDiveProvider(diveId)`, and `courseDivesProvider` and `courseDiveCountProvider` for every course in either list, as the form does (`dive_edit_page.dart:6941`).
  3. **The input mode.** When `StoredVisibility.of(result.after)` differs from `StoredVisibility.of(result.before)` and has a `modeToRemember`, `remember` it. The notifier is read before the first `await`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Details has a pencil, and its chip when the diver has hidden it', ...);
testWidgets('opening and closing Details in imperial units leaves the sitting clean', ...);
// stored: 12 m visibility, a trip (trip and tripId), a center, a site with a water type and
// none on the dive, two types, a course. Unlock, open, tap each field, Done: Save is disabled.
testWidgets('a visibility typed digit by digit is saved, and one typed back is not', ...);
// imperial, 12 m: type '4' then '40', Save: merged.visibilityMeters closeTo(12.192).
// Unlock again and open Details: the field shows '40'. Type '4' then '40': Save is disabled.
testWidgets('unreadable visibility: Done and Save refuse and the row is shown', ...);
testWidgets('clearing the trip saves a dive with no trip and no trip id', ...);
testWidgets('the site\'s water type is not saved by editing something else', ...);
// change the operator only: merged.waterType isNull, cards ['details'].
testWidgets('a trip that was stretched is named after the save', ...);
// FakeSave.tripDateStretches = [stretch of trip A]: the snackbar is tripDateStretchMessage's text.
testWidgets('a trip message that cannot be shown is not a failed save', ...);
testWidgets('changing courses refreshes the dive\'s courses', ...);
// a counting override of coursesForDiveProvider is read again after the save.
testWidgets('a course refresh that throws is not a failed save', ...);
// the page is locked, no recordEdit_saveFailed, the dive list was refreshed.
testWidgets('a new visibility is remembered as the input mode; an unchanged one is not', ...);
testWidgets('an exclusion switched on shows on the closed card and after the save', ...);
testWidgets('two cards changed in one sitting are one save naming both', ...);
// Details and Notes: one FakeSave call, cards ['details', 'notes'].
testWidgets('Cancel after picking a trip leaves the dive as it was', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_details_test.dart`
Expected: the trip message, course refresh and input mode tests FAIL. Any other new test that passes at once is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Implement the three steps in `_saveSitting`**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyse, run the guards and the page tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/`
Run: every `test/features/dive_log/presentation/pages/dive_detail*_test.dart` file, `test/features/dive_log/presentation/widgets/dive_detail/`, `test/features/dive_log/data/services/` and `test/features/dive_log/domain/`.
Expected: PASS.
Run: `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: 785, unchanged.

- [ ] **Step 6: Look at it**

Render the page in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): the Details read card with the statistics row; the card open with every value set; open with none; the visibility row in Range and in Precise, and with unreadable text; the trip suggestion; Details open beside Environment at 1200 px. Light and dark, metric and imperial for the visibility row. Check each picture by eye: the rows that cannot be typed in must read as part of the card, and the derived rows must line up with the form rows above them. Fix what is wrong with a test first, and keep the pictures, with the "before" ones from Task 5, for the pull request.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_details_test.dart
git commit -m "feat(dive-log): after a sitting, name a stretched trip and refresh what Details changed"
```

---

## Pull request

One, `Refs #4527`, stacked on plan 2's pull request #4550 until that merges. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the pictures from Task 5 and Task 10 Step 6: before and after for the read card (its header, and the statistics row, which is the one change a locked page shows with the switch off), and the unlocked pictures with a line saying they are unreachable without the build switch. Pushing and opening it waits for Eric.

## For plans 4 and 5

- **Plan 4 (header block).** A site choice writes `diveWaterTypeField` (with `waterTypeAfterSiteAssign` over the dive's own value, which here is never the site's standing in) and `diveTypeIdsField` (with `diveTypesAfterSiteAssign`). The set of types the site added has to live where both the site picker and the Details editor's `onChanged` can reach it while either card is closed; the session holds only record values today. The average depth field names `'details'` in `alsoShownOn`. A date change already stretches the trip (Task 4). The header block does draw the dive's types and its mode badge, as the spec says (`DiveHeroHeader`, `dive_hero_header.dart:94` and `:227`, built by `DiveDetailHeroSection`). It is handed the stored dive today (`dive_detail_page.dart:544`), so during a sitting it goes on showing the stored types. When plan 4 hands it the working dive, it adds the header's card id to `diveTypeIdsField.alsoShownOn`, and plan 5 does the same for the dive mode field.
- **Plan 5 (Tanks, Equipment, Weights).** The dive mode field names `'details'` in `alsoShownOn`. A trip change clears tank slot links and suggests slots again (`_setTrip`, `dive_edit_page.dart:3418`); until then the writer's drop at Save is the only guard. The rental memory card joins the dive center row (`RentalMemoryCard`, `_applyLastDiveAtCenter`). The link under the air consumption rows opens the Tanks card when unlocked.
- **Either.** A held write still cannot be withdrawn (plan 2, "Left open"). This plan did not need one: the trip stretch reads the dive as it was just written.

---

## After the review

The plan was built as written, then reviewed as a whole branch. This is what differs from the task text above, for whoever writes plans 4 and 5.

### Where the plan was wrong

| Above | Now |
| --- | --- |
| A reorder of courses is a change; `diveCourseIdsField` compares with `listEquals` | A dive's courses are a set. The writer stores the set and picks the representative course itself, by start date (`dive_course_links.dart:67` and `:112`), so the field compares as a set. Dive types are ordered, as planned |
| `DiveCourseRows` reads the diver's course list when an id is missing from the dive's own courses | Only once the dive's own courses have loaded and an id is still missing. Before that every id looks missing, and the list was read on every dive page |
| `diveWaterTypeField.alsoShownOn = {'environment'}` | No field of the card names another card. The Environment card's satellite block is worked out from `presence` (`DiveEnvironmentSection.satelliteFor`); redrawn live, it emptied that card when fresh water was picked and, in the folding layout, moved the open editor |
| The header block draws neither dive types nor dive mode | It draws both. See "For plans 4 and 5" |

### Added, or placed elsewhere

- **`DiveSittingFollowUp`** (`lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart`). The three steps after a committed save are a class of their own, read before the write and run after it, because a part file cannot import. It invalidates through the provider container, so the course providers are refreshed even when the page has gone. `dive_detail_page.dart` gained one import line (786).
- **`DiveDetailLinkRow`** in `dive_details_derived_rows.dart`: the Details row that leads somewhere, used by the read card and the derived rows.
- **Task 9's tests** are in `dive_detail_section_list_details_editing_test.dart`, with a harness that supplies tide data, satellite conditions and shared preferences.
- **The rule that came out of the review:** a calculated block inside a card that can be edited is laid out from `presence`, like a card with no editor that decides for itself whether it shows.

### When the base's last review fixes were merged in

Plan 2's pull request (#4550) gained two fix commits while this was being built. Merging them changed three things here:

- **`storedValueOfTyped(typed, onShow:, stored:, ...)`.** The base narrowed the number rule: only a number the row put on show itself stands for the value behind it; a number the diver typed stands for itself. The parameter that was `current` (the sitting's value) is `onShow` (the value the row last showed). `DiveVisibilityRow` follows it, so 39.4 ft typed over a 12 m visibility and cut back to 39 is no change.
- **`RecordFieldMarks` is `on RevealAnswering`.** The base gave the card frame and the number row one shared answer to a reveal request (`reveal_answering.dart`). A row mixes in `RevealAnswering<W>` first, then `RecordFieldMarks<T, W>`.
- **`diveCardIsShown(ref, id, dive, satelliteFor:)`.** The base's one question for the section list and the Add strip, `diveCardIsOnPage`, asks whether the dive as it is now still has something for a card. For the Environment card's satellite conditions that is asked of the held layout, or fresh water picked on Details would take the card off the page under the open editor.

### Tests the plan listed that were not written

- "A course refresh that throws" and "a trip message that cannot be shown": neither can be made to throw from a test. The guard is pinned by "a mode that cannot be remembered is not a failed save"; all three steps go through the one guarded helper.

### From the code review of the pull request

- **A new trip or dive center that cannot be read back** is caught: the dive is left as it was and the diver is told to try again (`common_error_tryAgain`). The record exists and can be picked from the list.
- **In Range, a measured distance the sitting holds is named in the caption.** No chip can show it, and it is what Save writes. This is the case of `1.2.3` typed in Precise and Range tapped.
- **A row or editor that goes before it has built makes no text binding on the way out.** The bindings are made on first use and disposed only if made.
- **The clear buttons of the trip and dive center rows are named** (`common_action_remove`).
- **The calculated rows in the open editor share one label column**, as on the read card.
- **What a picker or a new-record page brings back goes to the sitting it was opened in**, not to whichever sitting the row holds by then (from the pull request's review).
- **During a sitting the cylinder volume hint is a plain note.** As a link it opened the old edit form as a second editor over the diver's unsaved changes. Plan 5 makes it open the Tanks card.
- Tests added: a trip stretch that throws fails the save and leaves the dive as it was; reverting the sitting puts the trip's dates back; a cleared dive center is stored as null; a look at the other visibility input changes nothing for a bucket, a range under another scale, or no visibility.

### Left open

- In the open editor the calculated rows keep the read card's layout, the value beside its label, while the form rows put the value at the right edge.
- After a look at Range, the Precise row comes back open for typing, not resting: both inputs share one form row.
- A dive with a `tripId` whose trip did not load reads as "Not set" and offers no clear.
- After a saved sitting the quality scan and the tide record are not run, as after plans 1 and 2.
- `diveSaveTouchesTrip` compares entry times while the stretch reads the dive's date column. It matters once plan 4 makes dates editable.
- Tide, Signatures and the Environment card's satellite block are each handed the held layout by name. Once the site and the date can be edited (plan 4), more readers will need it; the general form is the spec's rule that a calculated card keeps its stored values during a sitting.

### Cleared later (PR #4670)

- Precise visibility comes back resting after a look at Range.
- A `tripId` whose trip did not load reads "Trip not found" and offers the clear.
- A saved sitting records the tide (when the site, time or water type moved, or the save gave the site its location; cleared for a dive with no sea site), and a header change refreshes the quality scan and derived metrics.
- Still open, each needing a decision: calculated rows keeping the read card's layout, and the held layout handed to Tide, Signatures and the satellite block by name. The two unwritten tests stay unwritten: the shared guard is pinned instead.
