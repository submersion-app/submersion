# Unified Editing, Plan 4: The Header Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive page's header block editable in place: name, number, site (with the site suggestion), entry and exit, runtime, bottom time, max and average depth, water temperature, rating, favourite and the planned switch, with the four "from profile" suggestions and every rule a site choice sets off on the other cards (issue #4527).

**Architecture:** Plans 1 to 3 gave the page an `EditSession<Dive>`, a `RecordEditController<Dive>`, field bindings, number rows, held writes and a layout that holds still while a card is open. This plan frames the header block as one more card (`'header'`, not a section), adds its fields and the linked-time rules as functions of the sitting, and moves the site rules out of the dive form into one function that knows which card owns each value it sets and what the previous site set. The sitting learns three things it could not do: a held write that is a change of its own (a dismissed suggestion, a location added to a site), releasing a held write, and per-sitting notes that are not record values (which dive types a site added). Still behind `kUnlockEditing`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read the Cards table, "Rules that span cards", "What is held, and what is not" and "What a locked dive page no longer shows". Plans 2 and 3 are `docs/design/plans/2026-11-14-unified-editing-2-altitude-environment.md` and `docs/design/plans/2026-11-14-unified-editing-3-details.md`; their "After the review" sections list the names as built, and plan 3's "For plans 4 and 5" lists what this plan must pick up. This plan uses those names.

## What the header block owns, shows and leaves alone

### Owns: edited on this card

All fields have `cardId: diveHeaderCardId` (`'header'`).

| Value | Field | Editor row | Today's form |
| --- | --- | --- | --- |
| Name | `diveNameField`, `String?`, trimmed | `FieldTextBinding` text row | `TheDiveSection`, `the_dive_section.dart:98` |
| Number | `diveNumberField`, `double?` (whole) | `RecordNumberRow(integer: true)` | `:103`; `_suggestNextDiveNumber`, `dive_edit_page.dart:1029` |
| Site | `diveSiteField`, `DiveSite?`, same id | `DiveSiteRow` (new): picker, location caption, clear | `:184`; `_showSitePicker`, `:3263` |
| Entry | `diveEntryField`, `DateTime` (writes `entryTime` and `dateTime`) | `DiveTimeRow` (new): date then time | `_editEntry`, `dive_edit_page_linked_times.dart:7` |
| Exit | `diveExitField`, `DateTime?` | `DiveTimeRow`, the estimate as hint | `_editExit`, `:19` |
| Runtime | `diveRuntimeField`, `double?` seconds | `RecordNumberRow`, shown in whole minutes | `:167`; `_followRuntime`, `linked_times.dart:55` |
| Bottom time | `diveBottomTimeField`, `double?` seconds | the same | `:152` |
| Max depth | `diveMaxDepthField`, `double?` metres | `RecordNumberRow`, one decimal | `:130` |
| Average depth | `diveAvgDepthField`, `double?` metres, `alsoShownOn: {'details'}` | the same | `:141` |
| Water temperature | `diveWaterTempField`, `double?` Celsius | `RecordNumberRow`, `trimZeros` | `ConditionsSection`, `conditions_section.dart:57` |
| Rating | `diveRatingField`, `int?` (0 is none) | `FormRow.rating` | `ExperienceSection`, `experience_section.dart:53` |
| Favourite | `diveFavoriteField`, `bool` | `FormRow.toggle` | none: the form copies it through (`dive_edit_page.dart:6705`); the bar toggles it at once |
| Planned | `divePlannedField`, `bool` | `FormRow.toggle`, key `dive_edit_planned_switch` | `SwitchListTile`, `dive_edit_page.dart:1405` |

Not fields, and held as changes of this card (Task 2): a dismissed site suggestion, and a location added to the dive's site from the suggestion.

### Shows, owned elsewhere

These rows stay in the open editor as rows that cannot be typed in, so nothing the header showed disappears when it opens.

| Row | Owner | What this plan does |
| --- | --- | --- |
| Dive mode | Tanks card (plan 5) | Nothing; plan 5 adds `'header'` to its field's `alsoShownOn` |
| Dive types | Details (`diveTypeIdsField`) | Adds `'header'` to its `alsoShownOn`, now that the header draws the sitting's dive (Task 10) |
| The site's location line, the data quality chip | Nobody edits them | Nothing |

### Values a site choice sets on other cards

| Value | Owning card | Field | Rule (Task 6) |
| --- | --- | --- | --- |
| Water type | Details | `diveWaterTypeField` | `waterTypeAfterSiteAssign` |
| Entry method, exit method | Environment | `diveEntryMethodField`, `diveExitMethodField` | `entryExitAfterSiteAssign` |
| Altitude | Altitude | `diveAltitudeField` | `fillAltitudeIfEmpty`, and the take-back below |
| Dive types | Details | `diveTypeIdsField` | `diveTypesAfterSiteAssign` |

Each change goes through its own field, so the owning card gets the changed dot and a closed card is redrawn (plan 2's revision mechanism). What else reads the site: the weather fetch (Environment reads `session.working.site`, already), the dive center picker's order (plan 3, already), Tide and the satellite block (Task 11 hands them the stored dive), species suggestions and geofenced gear (plans 6 and 5).

### The site rules, worked out

The form applies today's pure rules to whatever the form holds and never takes back what one site set when the diver picks another, except for dive types. In a sitting there is one principle for all of them:

**What a site set, the next site, or clearing it, takes back, unless the diver changed it since. A value the dive had before the sitting is never taken back.**

For each scalar value the site set, the sitting keeps a note of the value before the site set it and the value it set. On the next assignment the rule starts from the "before" value when the current value is still the one the site set, and from the current value otherwise. Then today's rule runs on it, unchanged:

- **Water type.** A site with a water type sets it, over the dive's own value and over one the diver picked in this sitting (today's rule: the later act wins). A site with none keeps it. Site A (salt) then site B (none) gives back the dive's own value; today's form keeps salt.
- **Entry and exit method.** The entry follows the site's single entry method. The exit follows while it still mirrors the entry. Whether it mirrors is no longer worked out from the two values alone: the Environment editor notes the diver's direct edit of the exit in the sitting (Task 6), so an exit the diver set equal to the entry stays theirs. Today's form loses that flag after any assignment.
- **Altitude.** Never replaced when stored or typed. When the sitting's altitude is the one a lookup filled in this sitting, a change of site takes it back to the stored altitude, **releases** the held write that would have copied it to the old site, and looks up again for the new site. Today's form keeps site A's altitude for site B and has already written it to site A.
- **Dive types.** Today's rule and its note of the types the site added, kept in the sitting. The Details editor's manual edit narrows the note, as the form's does (`siteAddedAfterManualEdit`).

The dive types need a database read and the altitude a network lookup. Both drop their result when the sitting ended, is being saved, or the dive's site changed meanwhile, as `fillAltitudeIfEmpty` and the weather fetch do. Save waits for the dive types read (the form does, `dive_edit_page.dart:6536`), not for the altitude.

### Held writes when the site changes

| Held write | Key | On a change of site |
| --- | --- | --- |
| The site's looked-up altitude (plan 2) | `siteAltitudeWriteKey(siteId)` | Released when the altitude is taken back. Its own check at Save stays |
| A location added to the site from the suggestion | `siteLocationChangeKey(siteId)` | Released |
| The suggestion dismissed | `siteSuggestionDismissKey` | Kept: it is about the dive, not the site |

## Where the header differs from today's form, and why

1. **No value is rewritten that the diver did not change.** The form saves max depth, average depth and water temperature as the rounded numbers it shows, and stores a bottom time worked out from the profile when the dive has none (`seeded_dive_times.dart:57`). Here the number already on show stands for the value behind it, and a bottom time the dive does not have is offered as a suggestion, not stored. Why: the program's rule; opening a card leaves the sitting clean.
2. **The times are the dive's own values; the estimated exit is a hint.** The form keeps a whole-minute copy of the times beside the exact ones (`SeededDiveTimes`) so a save cannot round them. Here the sitting holds the exact times; a picker that reads back the minute on show keeps the exact value, and a dive with no exit shows its estimate as the exit row's hint, which nothing can store. Why: the sitting holds values, not widget state.
3. **Every site rule takes back what the previous site set**, not only dive types (see above). Why: picking the wrong site and then the right one must not leave the wrong one's values behind.
4. **A looked-up altitude is copied to the site with the sitting, and released when the site changes.** The form writes it to the site at once, whether or not the dive is saved.
5. **The site suggestion acts on the sitting.** Assign, add location, create and dismiss are held; a catalogue site or a new site is created at once, as every record made from a picker is. "Choose nearby" opens the site picker instead of the batch review page. Locked, the suggestion keeps its place and its buttons are disabled.
6. **A planned dive is promoted with "Mark as logged", not with the switch.** The form promotes a plan when its switch is turned off and saved (`dive_edit_page.dart:6787`). Promotion numbers the dive and runs the logbook rules; the spec makes "Mark logged" a whole-record operation (plan 7). Here the switch is offered only for a dive stored as logged; a stored plan shows "Planned dive" as a row that cannot be changed.
7. **Favourite is a field of the header editor.** The bar's toggle and the menu item are gone while editing is offered; the locked bar shows the state.
8. **Clearing the exit is allowed.** The form has no way to remove a recorded exit.
9. **Blank runtime clears the runtime.** In the form it puts the times back as they last settled. Here blank is no value, as everywhere in the sitting, and the exit stays where it is.
10. **One order.** The form spreads these values over three groups (The Dive, Conditions, Experience) and the switch above them. Here they follow the header's reading order.

## Not in this plan

- Banners and their buttons ("Mark as logged", "Surfaced", "Mark as complete"): whole-record operations, plan 7. Locked, they still act as today.
- The new dive, its starter set and the number suggestion for it (`getNextDiveNumber` is wired here for the planned switch only): plan 8.
- Hiding the route row and gas switches for a planned dive, and not saving route links for one: plans 5 and 6 read `session.working.isPlanned`.
- Re-checking geofenced gear after a site change: plan 5, which owns equipment. Species suggestions for the new site: plan 6.
- The fade and "Calculated" label of calculated cards. Task 11 only hands them the stored dive.
- The embedded list pane (`DiveDetailEmbeddedHeader`), which offers no editing yet.
- The tide record and the quality scan after a saved sitting, as after plans 1 to 3.

## The form's own tests

The form and its tests stay until the last plan deletes the form. These cover what the header now owns; read each at the start of the task named, and add to that task's tests any behaviour it pins that the list there does not.

| Form test (`test/features/dive_log/presentation/pages/`) | Replaced in |
| --- | --- |
| `dive_edit_linked_times_test.dart`, `dive_edit_preserves_dive_times_test.dart` | Tasks 5 and 9 |
| `dive_edit_page_test.dart` (bottom time and estimated exit) | Tasks 5 and 9 |
| `dive_edit_next_number_diver_test.dart`, `dive_edit_planned_switch_test.dart` | Tasks 5 and 9; the new-dive half in plan 8 |
| `dive_edit_rating_clear_test.dart`, `dive_edit_locale_number_input_test.dart` | Task 9 |
| `dive_edit_site_water_type_test.dart`, `dive_edit_site_entry_method_test.dart`, `dive_edit_site_dive_types_test.dart`, `dive_edit_altitude_autofill_test.dart` | Task 6 |
| `dive_edit_site_gps_test.dart`, `dive_edit_site_picker_area_test.dart` | Task 9 |
| `dive_edit_profile_source_test.dart` | Task 9 (the suggestions); the profile editor itself is plan 6 |
| `dive_edit_geofence_suggestion_test.dart`, `dive_edit_site_species_suggestions_test.dart` | Plans 5 and 6 |
| `test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart` | Kept, with the switch off; Task 8 adds the locked and sitting cases |

## Calls made in this plan, for Eric to check

1. **Every site rule takes back what the previous site in the sitting set** (difference 3), not only dive types.
2. **Picking a site looks the altitude up when the sitting has none**, as today's form does on assign, and a site change takes back an altitude the sitting looked up and releases its site write.
3. **Locked, the site suggestion keeps its place with every button disabled**, dismiss included. Hiding it would move the page on unlock; leaving it live would be a control that writes.
4. **Dismissing the suggestion is held until Save**, as a change of the header card.
5. **"Choose nearby" opens the site picker during a sitting**, not the batch review page, which writes at once.
6. **Assigning a catalogue site from the suggestion creates the diver's copy at once**; only the dive's link to it is held. Creating a site from the suggestion is the same.
7. **The planned switch can mark a logged dive as planned; it does not promote a plan** (difference 6).
8. **Favourite: with editing offered, the locked bar shows the state and the menu loses its favourite item.** Without the switch, nothing changes.
9. **The exit row shows the estimated exit as its hint, and the exit can be cleared.** A runtime of zero moves nothing; a blank runtime clears it (differences 2, 8, 9).
10. **Cards with no editor show the stored dive for the whole sitting.** The spec says this of calculated cards; Task 11 applies it to every card that has no editor yet (Tide, Deco, Tissue, Cylinders and the rest), so a site, date or depth typed in the header does not rework them before Save. Each card follows the sitting once its own plan gives it an editor.
11. **The header follows the viewed data source only for values the sitting has not changed.** A changed max depth shows the diver's value after Done, whichever source is viewed.
12. **Save waits for the dive types a site adds**, as the form does, and not for the altitude lookup.
13. **One new string:** `diveLog_detail_section_header`, "Dive", the open card's title and its name in History. The mockup calls the card "Dive".
14. **The planned switch shows its subtitle** ("Awaiting dive computer data...") as the form does, and turning it off gives back the stored number. A dive stored as logged with no number gets the next number suggested.

## Global Constraints

- With `kUnlockEditing` false the dive page builds and behaves exactly as today. The header block is drawn by a new widget, with the same children in the same order and the stored dive.
- A card does not move on the page while its editor is open, whatever is typed or picked in it, the header included.
- Every value shown or typed follows the active diver's units (`unitFormatterProvider`): depths in the depth unit, temperature in the temperature unit, dates and times through `UnitFormatter` only (`formatDateTimeBullet`, `formatDate`, `formatTime`). The session holds canonical values: metres, Celsius, `Duration` seconds held as `double`, UTC wall-clock instants.
- A value the diver did not change is never written. Opening the header editor, tapping into every field, opening and dismissing each picker, and closing it leaves the sitting clean, in metric and imperial, for a dive whose times carry seconds and whose depths carry more decimals than are shown.
- Emptying a field clears the stored value. Entry cannot be emptied.
- Typed numbers are read only through `readNumber`; the architecture guard forbids `tryParse` in presentation code.
- Number tests type digit by digit (one `enterText` per growing prefix) and step through values that round alike (12.41 m shows as 40.7 ft, as does 12.40 m; 43 min 27 s and 43 min 40 s both show as 43).
- A text field that shows a value of the sitting gets it through `FieldTextBinding` or `replaceTextKeepingCaret`, never by assigning `text`.
- Anything that writes to a sitting after an `await` (a picker closing, a page returning, a lookup) checks `mounted` where it has one, then `session.isDisposed` and `session.isFrozen`, and drops its result when the dive's inputs it was asked about changed meanwhile (the site, the entry time), as `fillAltitudeIfEmpty` and the weather fetch do. It reads what it needs from `ref` and `context` before the first `await`.
- Any refresh, message or preference written after `service.save` returns is in a `try` of its own (`DiveSittingFollowUp._guarded`). A failure there is logged and never reported as a failed save.
- `session.set(field, 10)` with a whole-number literal on a `double?` field fails at run time: tests spell `10.0`. Type list literals (`<String>[]`).
- Settings are read with `settingsProvider.select(...)`.
- No file over 800 lines. `dive_detail_page.dart` is at 787: it loses the header block to a widget of its own (Task 10) and must end at or under 787. New page code goes in `dive_detail_page_editing.dart` or a file of its own (a part file cannot import).
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects one (call 13).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests. Do not join two parts of a label with a spaced hyphen.
- Tests restore global state: `tester.view` via `addTearDown`, the test database via `tearDownTestDatabase()`. Build repositories in `setUp`, never once for the file. `getBaseOverrides` already overrides shared preferences: set a preference after calling it.
- Before each commit: `dart format .`, `flutter analyze`, the affected test files, plus `flutter test test/architecture/ test/shared/` when files under `lib/` were added. Never the whole suite. Do not pipe `flutter test` into `grep` or `tail` to judge the result.
- Do not push or open a pull request; that waits for Eric.

## Review Focus

1. **A site picked, then another, then cleared.** Water type, entry and exit, altitude and dive types the first site set come back out; the diver's own values, and values stored before the sitting, stay; site A's altitude write is released and never runs. Picking the dive's stored site back after two others leaves only what that site's own rules set. Pinned in Task 6.
2. **A lookup that answers late.** The dive types read or the altitude lookup for site A lands after site B was picked, after Cancel, or while saving. Nothing is set, nothing is held, nothing throws. A Save made while the types are still being read waits for them. Pinned in Tasks 2 and 6.
3. **Times put back.** The stored exit picked again at its own minute, the stored runtime typed back, an entry moved and moved back: each leaves the sitting clean and keeps the stored seconds. An estimated exit is never stored unless the diver picks it. Pinned in Tasks 5, 9 and 12.
4. **The suggestion during a sitting.** Assign, add location and dismiss leave the stored dive and site alone until Save, and Cancel leaves them as they were; a catalogue site adopted, or a site created, survives Cancel. With the header open, the suggestion card does not leave the page under the editor. Pinned in Tasks 7, 8 and 12.
5. **Nothing writes on a locked page.** The favourite state in the bar, the suggestion's buttons and its close button, a tap on the hero: none writes. Pinned in Tasks 8, 10 and 12.
6. **The header open while the site changes the other cards.** The Altitude card, absent before, does not appear above or below the open header editor until it closes; Details and Environment get their dots while closed. Pinned in Task 12.

## Preparation

- [ ] Work on a branch cut from current `origin/main` (plans 1 to 3 and #4566 are merged). Check that `lib/shared/widgets/record_editing/add_strip_layout.dart` and `lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart` exist.
- [ ] In a fresh worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` with no build filter.
- [ ] `flutter analyze` on the whole repository is clean before any change.
- [ ] Take the pull request's "before" pictures now, before any code changes: the dive page's top, locked, light and dark, phone and desktop width, with a site suggestion showing, and the bar's favourite button.

## File Structure

New, shared (`lib/shared/widgets/record_editing/`):

| File | Responsibility |
| --- | --- |
| `record_card_pencil.dart` | `RecordCardPencil`: the dot and pencil of a closed card, for a card whose title row is not a `RecordCardHeader` |

New, dive (`lib/features/dive_log/presentation/widgets/dive_detail/`):

| File | Responsibility |
| --- | --- |
| `dive_detail_header_block.dart` | `DiveDetailHeaderBlock`: banners, the site suggestion and the framed hero, moved out of the page |
| `editing/dive_header_fields.dart` | The header's fields, `diveHeaderCardId`, the linked-time rules, the planned rule |
| `editing/dive_site_assignment.dart` | `assignDiveSite`, the site's take-back notes, the held write keys |
| `editing/dive_header_time_rows.dart` | `DiveTimeRow`: an entry or exit picked as a date then a time |
| `editing/dive_site_row.dart` | `DiveSiteRow` and `pickSiteForSitting` |
| `editing/dive_header_card_editor.dart` | `DiveHeaderCardEditor` and `diveHeaderCard` |

Modified: `dive.dart`, `edit_session.dart`, `record_edit_controller.dart`, `record_number_row.dart`, `record_card_header.dart`, `dive_edit_save_service.dart`, `dive_altitude_fields.dart`, `dive_environment_card_editor.dart`, `dive_details_card_editor.dart`, `dive_details_fields.dart`, `site_matching_service.dart`, `site_suggestion_actions.dart`, `site_suggestion_card.dart`, `site_suggestion_banner.dart`, `dive_hero_header.dart`, `dive_detail_hero_section.dart`, `dive_detail_section_list.dart`, `change_log_labels.dart`, `dive_detail_page.dart`, `dive_detail_page_editing.dart`, `dive_sitting_follow_up.dart`, the harness `dive_detail_page_unlock_harness.dart`, the 11 ARB files.

---

### Task 1: `Dive.copyWith` can clear the values the header edits

`copyWith` keeps the old value when passed null. `clearName`, `clearSite`, `clearExitTime` and `clearRuntime` exist; six more are needed.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`copyWith`, from line 842)
- Test: `test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart` (exists)

**Interfaces:**
- Produces: six `bool` parameters on `Dive.copyWith`, each defaulting to false: `clearDiveNumber`, `clearBottomTime`, `clearMaxDepth`, `clearAvgDepth`, `clearWaterTemp`, `clearRating`. Each follows the existing form: `rating: clearRating ? null : (rating ?? this.rating)`.

- [ ] **Step 1: Write the failing tests**

Add the six to the file's `cases` table (one line each, a non-null value for each in `full`), so each is checked to clear itself and nothing else. Then:

```dart
test('a clear flag wins over a value passed with it', () {
  expect(full.copyWith(maxDepth: 30.0, clearMaxDepth: true).maxDepth, isNull);
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart`
Expected: FAIL to compile, the flags do not exist.

- [ ] **Step 3: Add the six flags and their bodies**

- [ ] **Step 4: Run it and confirm it passes**

Run: the same command, then `flutter test test/features/dive_log/domain/ test/core/database/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive.dart test/features/dive_log/domain/entities/dive_copy_with_clear_test.dart
git commit -m "feat(dive-log): let copyWith clear a dive's number, depths, times, temperature and rating"
```

---

### Task 2: A sitting can hold a change to another record, release a held write, keep notes, and wait for its own work

**Files:**
- Modify: `lib/shared/widgets/record_editing/edit_session.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_controller.dart` (`save`)
- Test: `test/shared/widgets/record_editing/edit_session_test.dart`
- Test: `test/shared/widgets/record_editing/record_edit_controller_test.dart`

**Interfaces:**
- Consumes: `holdWrite`, `runHeldWrites`, `hasHeldWrites`, `firstTime` (plan 2).
- Produces:

```dart
// EditSession
/// Holds [write] as a change of [cardId] in its own right: a write to
/// another table that is the diver's change, with no record value behind it
/// (a dismissed suggestion, a location added to a site). Unlike [holdWrite]
/// it makes the session dirty, puts [cardId] in [changedCardIds] and
/// notifies. A second call with the same [key] replaces the first. Does
/// nothing while frozen or disposed.
void holdChange(String key, {required String cardId, required Future<void> Function() write});

/// Whether a write or change is held under [key].
bool isHeld(String key);

/// Whether any held entry is a change ([holdChange]).
bool get hasHeldChanges;

/// Drops what is held under [key], write or change. Notifies when it was a
/// change. Does nothing while frozen.
void releaseWrite(String key);

/// A note kept for the sitting and dropped with it: not a value of the
/// record, never written, never a change (which dive types a site added).
void remember(String key, Object? value);
V? recall<V>(String key);

/// Work the sitting started that a save must wait for, such as the dive
/// types a picked site adds. Errors are the work's own to handle.
void track(Future<void> work);

/// Completes when every tracked piece of work has.
Future<void> settled();
```

  `isDirty` is `_pending.isNotEmpty || hasHeldChanges`. `changedCardIds` adds the cards of held changes. `holdChange` and `releaseWrite` bump `revisionOf(cardId)` like `set` does, so a closed card is redrawn. `runHeldWrites` runs writes and changes together, in the order first held.

  `RecordEditController.save`: after the invalid-input check and the clean check, it sets `_isSaving`, notifies, then `await session.settled()` before `session.freeze()`. While it waits the leave guard already refuses input (it reads `isSaving`). If the sitting was ended meanwhile (`!identical(_session, session)`), it returns false.

- [ ] **Step 1: Write the failing tests**

```dart
// edit_session_test.dart
test('a held change makes the session dirty and names its card', () {
  final s = EditSession(dive)..holdChange('k', cardId: 'header', write: () async {});
  expect(s.isDirty, isTrue);
  expect(s.changedCardIds, {'header'});
  expect(s.isHeld('k'), isTrue);
});
test('releasing a held change leaves the session clean, and notifies', ...);
test('releasing a held write runs nothing for it at save', () async {
  // holdWrite('a', ...), holdWrite('b', ...), releaseWrite('a'); runHeldWrites: only b ran.
});
test('writes and changes run in the order first held', ...);
test('frozen, holdChange and releaseWrite do nothing', ...);
test('a note is recalled, is not a change, and does not notify', ...);
test('settled waits for tracked work, and an error in it does not escape', () async {
  // track(a completer's future); settled() not complete; complete it; settled() completes.
  // track(Future.error(StateError('x'))..ignore()): settled() completes normally.
});

// record_edit_controller_test.dart
test('save waits for tracked work before freezing', () async {
  // unlock; session.set(notes, 'x'); track(gate.future) whose completion sets another field.
  // save() is pending; release the gate; the onSave sees both values.
});
test('save of a sitting whose only change is held calls onSave', ...);
test('a sitting ended while save waits is not saved', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/edit_session_test.dart test/shared/widgets/record_editing/record_edit_controller_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

`settled` waits with `Future.wait(..., eagerError: false)` over the tracked futures, each wrapped so an error is swallowed (the work logs its own); tracked futures are removed as they complete.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/shared/ test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): a sitting can hold a change to another record, release a held write and keep notes"
```

---

### Task 3: A save whose only change is held still writes it

`DiveEditSaveService.save` returns null, and runs nothing, when `apply` changed no dive value. A sitting whose only change is a dismissed suggestion or a location added to the site must still be written.

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_edit_save_service.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart` (`_saveSitting`)
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (`FakeSave`)
- Test: `test/features/dive_log/data/services/dive_edit_save_service_test.dart`

**Interfaces:**
- Produces: `save` gains `bool alsoWriteIsAChange = false`. When `merged == stored` and `alsoWriteIsAChange`, it runs `alsoWrite` inside the transaction and returns `(before: stored, after: stored, tripDateStretches: const [])`. Otherwise unchanged. `_saveSitting` passes `alsoWriteIsAChange: session.hasHeldChanges`, and reads `siteListNotifierProvider` when `session.hasHeldWrites` as now. `FakeSave` records the flag.

- [ ] **Step 1: Write the failing tests**

```dart
test('a held change with no dive change is written, in one History entry', () async {
  final result = await service.save(diveId: 'dive', apply: (d) => d, changedCardIds: ['header'],
      alsoWrite: () => repo.setSiteSuggestionDismissed('dive', true), alsoWriteIsAChange: true);
  expect(result, isNotNull);
  // the dismissal is stored; one operation, labelled record_edit:dives:header.
});
test('with no change of any kind nothing runs', ...);   // alsoWriteIsAChange false: alsoWrite not called
test('a held change that throws rolls the dive back with it', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/data/services/dive_edit_save_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement, and pass the flag from `_saveSitting`**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/dive_edit_save_service.dart lib/features/dive_log/presentation/pages/dive_detail_page_editing.dart test/features/dive_log/data/services/dive_edit_save_service_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart
git commit -m "feat(dive-log): save a sitting whose only change is a held write"
```

---

### Task 4: The number row can move other values and offer a profile suggestion; a pencil for a card with its own title row

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_number_row.dart`
- Create: `lib/shared/widgets/record_editing/record_card_pencil.dart`
- Modify: `lib/shared/widgets/record_editing/record_card_header.dart` (uses `RecordCardPencil`)
- Test: `test/shared/widgets/record_editing/record_number_row_test.dart`
- Test: `test/shared/widgets/record_editing/record_card_pencil_test.dart`
- Test: `test/shared/widgets/record_editing/record_card_frame_test.dart` (unchanged, must still pass)

**Interfaces:**
- Consumes: `ProfileSuggestion` (`lib/shared/widgets/forms/form_row.dart:14`), `RecordCardFrameScope`, `RecordChangedDot` (plan 1).
- Produces:

```dart
// RecordNumberRow gains
/// Writes a value the diver typed, in the stored unit. Null is
/// `session.set(field, value)`. For a value that moves others: a runtime
/// moves the exit.
final void Function(double? value)? apply;

/// Offered beside the row while it differs from the row's text, as the
/// form's rows offer a value worked out from the profile. Its value is
/// already formatted in the diver's unit.
final ProfileSuggestion? suggestion;

// record_card_pencil.dart
/// The changed dot and the pencil of a closed card whose title row is drawn
/// by the card itself. Locked, or with no frame, it draws nothing and takes
/// no room. The pencil opens the card; it is announced as a button named
/// with [cardTitle].
class RecordCardPencil extends StatelessWidget {
  const RecordCardPencil({super.key, required this.cardTitle});
  final String cardTitle;
}
```

  `RecordCardHeader` draws its dot and pencil through `RecordCardPencil` pieces, so the two cannot drift; its row and behaviour are unchanged. `RecordCardPencil` keeps the dot's place while there is none, as the header does, and draws nothing while the card is open (the open card has its own header).

- [ ] **Step 1: Write the failing tests**

```dart
// record_number_row_test.dart
testWidgets('apply is called in place of set, with the stored value', ...);
// apply records values; type '4' then '45' with fromDisplay x60: apply got 240.0 then 2700.0; the session unchanged.
testWidgets('the number on show typed back is handed to apply as the value behind it', ...);
// stored 2607.0 s shown as '43': type '4', '43': apply's last value is 2607.0.
testWidgets('a suggestion that differs from the text is offered, and using it calls its onUse', ...);
testWidgets('a suggestion equal to the text is not offered', ...);

// record_card_pencil_test.dart
testWidgets('locked: nothing, and no room taken', ...);         // size zero
testWidgets('unlocked and closed: a pencil that opens the card', ...);
testWidgets('changed: the dot', ...);
testWidgets('open: nothing', ...);
testWidgets('announced as a button named for the card', ...);   // recordEdit_editCardTooltip(title)
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/shared/widgets/record_editing/record_number_row_test.dart test/shared/widgets/record_editing/record_card_pencil_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Where the row calls `session.set(field, value)` today it calls `widget.apply` instead when one is given; everything else (marks, reveal, the number on show) is unchanged. `suggestion` is passed to the `FormRow.text` the row builds (`profileSuggestion:`).

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/shared/ test/features/dive_log/presentation/widgets/dive_detail/editing/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/record_editing test/shared/widgets/record_editing
git commit -m "feat(shared): a number row that moves other values, offers a suggestion, and a pencil for any title row"
```

---

### Task 5: The header's fields and its linked-time and planned rules

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields_test.dart`

**Interfaces:**
- Consumes: the clear flags (Task 1); `EditField`, `EditSession` (plans 1 and 2); `trimmedOrNull`; `wholeMinute` (`seeded_dive_times.dart:145`).
- Produces:

```dart
/// The header block's card id. Not a section: the header is fixed above them.
const String diveHeaderCardId = 'header';

final EditField<Dive, String?> diveNameField;        // 'name', trimmed, blank is null
final EditField<Dive, double?> diveNumberField;      // 'diveNumber'; write rounds
final EditField<Dive, DiveSite?> diveSiteField;      // 'site', equals: same id; null writes clearSite
final EditField<Dive, DateTime> diveEntryField;      // 'entryTime': read effectiveEntryTime; write sets entryTime and dateTime
final EditField<Dive, DateTime?> diveExitField;      // 'exitTime'
final EditField<Dive, double?> diveRuntimeField;     // 'runtime', seconds
final EditField<Dive, double?> diveBottomTimeField;  // 'bottomTime', seconds
final EditField<Dive, double?> diveMaxDepthField;    // 'maxDepth', metres
final EditField<Dive, double?> diveAvgDepthField;    // 'avgDepth', metres, alsoShownOn {'details'}
final EditField<Dive, double?> diveWaterTempField;   // 'waterTemp', Celsius
final EditField<Dive, int?> diveRatingField;         // 'rating'; 0 and null are the same, stored as null
final EditField<Dive, bool> diveFavoriteField;       // 'isFavorite'
final EditField<Dive, bool> divePlannedField;        // 'isPlanned'

/// The instant a picker's [picked] minute stands for: [current] when it
/// shows as that minute, so the stored seconds are kept; else [picked].
DateTime pickedInstant(DateTime picked, DateTime? current);

/// Moves the entry, and a recorded exit with it, so the dive keeps its
/// length (issue #241). The runtime is left as it is.
void setEntryTime(EditSession<Dive> session, DateTime entry);

/// Sets the exit. A changed exit sets the runtime to exit minus entry, or
/// clears it when the exit is before the entry. An exit cleared leaves the
/// runtime alone.
void setExitTime(EditSession<Dive> session, DateTime? exit);

/// Sets the runtime. A positive runtime moves a recorded exit to entry plus
/// the runtime; back to the stored runtime with the stored entry, the exit
/// goes back to the stored exit. A dive with no exit keeps none. Zero or
/// null moves nothing.
void setRuntime(EditSession<Dive> session, Duration? runtime);

/// Where a dive with no exit is shown to end: entry plus its runtime, or
/// failing that its bottom time. A hint only; never stored.
DateTime? estimatedExit(Dive dive);

/// Marks the dive planned or not (issue #2002). Planned clears the number.
/// Not planned gives back the stored number when the sitting has none, or
/// failing that asks [nextNumber] and sets it if the number is still empty
/// and the dive still not planned when it answers. The ask is tracked.
void setPlanned(EditSession<Dive> session, bool planned, {required Future<int?> Function() nextNumber});

/// Whether the header editor offers the planned switch: a dive stored as
/// logged, with no primary data source, that is not a draft.
bool plannedSwitchOffered(Dive stored, {required bool hasPrimarySource});
```

  Durations are held as `double?` seconds so the number row's rule (the number on show stands for the value behind it) keeps a stored 43 min 27 s when 43 is typed back.

- [ ] **Step 1: Write the failing tests**

```dart
test('every field belongs to the header card, and ids are unique', ...);
test('the entry writes entryTime and dateTime together', () {
  final d = diveEntryField.write(dive, t);
  expect((d.entryTime, d.dateTime), (t, t));
});
test('a dive stored with dateTime only reads its entry and is not changed by it', ...);
test('a rating of 0 is no rating, and clears a stored one', ...);
test('the number rounds, and null clears it', ...);
test('name is trimmed; blank is null', ...);
test('the same site with other details is not a change', ...);   // same id, other name

group('pickedInstant', () {
  test('the stored minute keeps the stored seconds', () {
    expect(pickedInstant(DateTime.utc(2026, 3, 9, 9, 42), DateTime.utc(2026, 3, 9, 9, 42, 27)),
        DateTime.utc(2026, 3, 9, 9, 42, 27));
  });
  test('another minute is taken as picked', ...);
});

group('linked times', () {
  // stored: entry 09:42:27, exit 10:34:51, runtime 52 min 24 s.
  test('moving the entry moves the exit by as much, and keeps the runtime', ...);
  test('moving the entry back leaves the sitting clean', ...);
  test('a dive with no exit keeps none when the entry moves', ...);
  test('a new exit sets the runtime to exit minus entry', ...);
  test('an exit before the entry clears the runtime', ...);
  test('the stored exit picked at its own minute changes nothing', ...);
  test('clearing the exit leaves the runtime', ...);
  test('a runtime moves a recorded exit', ...);                // 60 min: exit 10:42:27
  test('the stored runtime typed back puts the stored exit back, and the sitting is clean', ...);
  test('a runtime on a dive with no exit stores no exit', ...);
  test('zero or no runtime moves nothing', ...);
  test('the estimate is entry plus runtime, else bottom time, else none', ...);
});

group('planned', () {
  test('planned clears the number', ...);
  test('back to logged gives the stored number back and the sitting is clean', ...);
  test('a logged dive with no number is offered the next one', () async {
    // nextNumber answers 215; await session.settled(): number 215.0.
  });
  test('the next number is dropped if the diver typed one, or planned again, meanwhile', ...);
  test('the switch is offered only for a logged dive with no source that is not a draft', ...);
});
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the fields and rules**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields_test.dart
git commit -m "feat(dive-log): the header's values as fields of the sitting, with linked times"
```

---

### Task 6: Picking a site applies its rules to the other cards, and takes back what the previous site set

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart` (`fillAltitudeIfEmpty` notes what it filled; the key function)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart` and `dive_environment_card_editor.dart` (the exit's direct edit is a note of the sitting)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart` (the dive types' manual edit narrows the site's note)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment_test.dart`
- Test: `dive_altitude_fields_test.dart`, `dive_environment_card_test.dart`, `dive_details_card_test.dart` (add cases)

**Interfaces:**
- Consumes: `diveSiteField` (Task 5); `holdWrite`, `releaseWrite`, `remember`, `recall`, `track` (Task 2); `waterTypeAfterSiteAssign`, `entryExitAfterSiteAssign`, `diveTypesAfterSiteAssign`, `siteAddedAfterManualEdit` (`lib/features/dive_log/presentation/utils/`); `diveWaterTypeField`, `diveTypeIdsField` (plan 3); `diveEntryMethodField`, `diveExitMethodField`, `exitFollowsEntry` (plan 2); `fillAltitudeIfEmpty`, `diveAltitudeField` (plan 2).
- Produces:

```dart
// dive_site_assignment.dart
String siteLocationChangeKey(String siteId);   // 'siteLocation:<id>'
const String siteSuggestionDismissKey = 'siteSuggestionDismissed';

/// Puts [site] on the dive in [session] and applies the site's rules to the
/// values other cards own: water type (Details), entry and exit method
/// (Environment), altitude (Altitude) and dive types (Details).
///
/// What the previous site set in this sitting is taken back first, unless
/// the diver changed it since; values the dive had before the sitting are
/// never taken. An altitude a lookup filled for the previous site goes back
/// to the stored one and its site write is released, as is a location held
/// for that site.
///
/// [siteDiveTypeIds] and [resolveAltitude] run after; each drops its result
/// if the sitting ended, is being saved, or has another site by then. The
/// dive types read is tracked, so a save waits for it; the altitude lookup
/// is not.
void assignDiveSite(
  EditSession<Dive> session,
  DiveSite? site, {
  required Future<List<String>> Function(String siteId) siteDiveTypeIds,
  required AltitudeResolver resolver,
  required Future<void> Function(String siteId, double altitudeMeters) writeSiteAltitude,
});

/// Whether the exit method follows the entry method in [session]: it did
/// when the sitting began ([exitFollowsEntry] of the stored dive) and the
/// diver has not edited the exit directly since.
bool exitFollows(EditSession<Dive> session);

/// Call when the diver edits the exit method directly.
void exitEditedDirectly(EditSession<Dive> session);

/// Call when the diver sets the dive types by hand: a type the site added
/// that the diver unticks is theirs from then on (`siteAddedAfterManualEdit`).
void diveTypesEditedByHand(EditSession<Dive> session, List<String> typeIds);

// dive_altitude_fields.dart
String siteAltitudeWriteKey(String siteId);   // 'siteAltitude:<id>', used by fillAltitudeIfEmpty
const String altitudeFillNoteKey = 'altitudeFill';
```

  The notes, all private to `dive_site_assignment.dart` except where named:
  - `_snapNoteKey(fieldId)`: `({Object? before, Object? after})` for water type, entry and exit. On assignment each starts from `before` when `valueOf(field) == after`, else from `valueOf(field)`, and records the new pair.
  - `_siteAddedTypesKey`: the `Set<String>` `diveTypesAfterSiteAssign` returns as `siteAddedIds`.
  - `altitudeFillNoteKey` (public, in `dive_altitude_fields.dart` beside `siteAltitudeWriteKey`, written by `fillAltitudeIfEmpty`): `({String? siteId, double meters})` of the altitude it set.
  - `_exitEditedKey`: true once the exit was edited directly.

  `assignDiveSite` does nothing when the site is the same one. Otherwise, in order: release `siteAltitudeWriteKey(old)` and `siteLocationChangeKey(old)` for the old site; set `diveSiteField`; water type; entry and exit (with `currentLinked: exitFollows(session)`, then `exitEditedDirectly` is not set); altitude: when `valueOf(diveAltitudeField)` equals the noted fill, set it back to `session.stored.altitude` and drop the note; then, when the sitting has no altitude, start `fillAltitudeIfEmpty` (not tracked, `stillWanted` true); dive types: `track` the read, then apply `diveTypesAfterSiteAssign(currentTypeIds: valueOf(diveTypeIdsField), previousSiteAddedIds: <note>, siteDiveTypeIds: <read, or const [] for no site>)` when the sitting still has this site, and note `siteAddedIds`. A failed read leaves the types and the note alone and logs a warning.

  The Environment editor's `_exitFollows` is replaced by `exitFollows(session)`, and its exit row calls `exitEditedDirectly(session)` before `set`. The Details editor's dive types row calls `diveTypesEditedByHand(session, ids)` before `set`.

- [ ] **Step 1: Write the failing tests**

Fakes: an `AltitudeResolver` over a fake `ElevationService` (as `dive_altitude_fields_test.dart` has), a gated `siteDiveTypeIds`, a counting `writeSiteAltitude`.

```dart
group('water type', () {
  test('a site with a water type sets it', ...);
  test('a site with none keeps the dive\'s', ...);
  test('one the diver picked is replaced by a site that has one', ...);
  test('site A then site B with none gives back the dive\'s own', ...);
  test('site A then cleared gives back the dive\'s own, and the sitting holds no water type change', ...);
  test('one the diver picked after site A is kept by site B with none', ...);
});
group('entry and exit', () {
  test('a site\'s single entry and exit fill both', ...);
  test('an exit edited directly is kept, even when equal to the entry', ...);
  test('site A then site B with no methods gives back the dive\'s own', ...);
});
group('altitude', () {
  test('a site with an altitude fills an empty one, and holds no site write', ...);
  test('a site looked up holds the site write', ...);
  test('site A looked up, then site B: A\'s altitude is taken back, A\'s write released, B looked up', () async {
    // isHeld(siteAltitudeWriteKey('a')) false; runHeldWrites writes only B's.
  });
  test('a stored altitude is never replaced', ...);
  test('one the diver typed is never replaced or taken back', ...);
  test('A\'s lookup answering after B was picked sets nothing', ...);
});
group('dive types', () {
  test('a wreck site adds wreck', ...);
  test('clearing takes back what it added', ...);
  test('a type re-ticked by hand survives the next site', ...);   // via diveTypesEditedByHand
  test('a failed read leaves the types alone', ...);
  test('A\'s types answering after B was picked are dropped', ...);
  test('save waits for the types', () async {
    // gate the read; assignDiveSite; settled() not complete; release; settled() completes with wreck added.
  });
});
test('a location held for site A is released when B is picked', ...);
test('the dismissal is kept when the site changes', ...);
test('picking the same site again does nothing', ...);
test('cancelled or frozen before the lookups answer: nothing set, nothing thrown', ...);
test('each value lands on its own card', () {
  // after a site with salt, a shore entry and a wreck type: changedCardIds == {'header', 'details', 'environment'}.
});

// dive_environment_card_test.dart
testWidgets('an exit picked equal to the entry stays the diver\'s after a reopen', ...);
// dive_details_card_test.dart
testWidgets('unticking a type the site added makes it the diver\'s', ...);
// dive_altitude_fields_test.dart
test('a fill notes what it set and holds its write under siteAltitudeWriteKey', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/`
Expected: the new tests FAIL; plans 2 and 3's tests pass.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/utils/ test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/editing test/features/dive_log/presentation/widgets/dive_detail/editing
git commit -m "feat(dive-log): a site picked in a sitting sets the other cards' values and takes back the last site's"
```

---

### Task 7: The site suggestion can resolve a site without linking it

Every suggestion action writes the dive's link at once today (`SiteMatchingService.applyConfirmed`, `createAndLink`). A sitting needs the site, and nothing else written but what creating it needs.

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart`
- Test: `test/features/dive_sites/data/services/site_matching_service_test.dart` (find the existing file; add a group)
- Test: `test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart`

**Interfaces:**
- Produces:

```dart
// SiteMatchingService
/// The site [candidateId] stands for, for [diveId], without linking the
/// dive: an existing site, or a catalogue site adopted as the diver's (the
/// same dedup, adoption lookup and coincidence guard as [applyConfirmed]).
/// An adopted site is created at once, in a transaction, and its altitude
/// filled best effort after it.
Future<({DiveSite site, List<String> createdSiteIds})> resolveCandidate(String diveId, String candidateId);

/// Creates [site] for this diver, with no link, and fills its altitude
/// best effort.
Future<DiveSite> createSite(DiveSite site);

// SiteSuggestionActions
Future<({DiveSite site, List<String> createdSiteIds})> resolve(String candidateId);
Future<DiveSite> createUnlinked(DiveSite site);
```

  `_applyOne` is split: a private `_siteFor(diveId, ref)` returns the site id and the outcome, and `_applyOne` links it; `resolveCandidate` uses `_siteFor` and links nothing. `applyConfirmed` and `createAndLink` behave as before.

- [ ] **Step 1: Write the failing tests**

```dart
test('an existing candidate resolves to it and links nothing', ...);
test('a catalogue candidate is adopted, reported as created, and nothing is linked', ...);
test('a catalogue candidate near a site of the diver\'s resolves to that site', ...);   // coincidence guard
test('a catalogue site already adopted resolves to the adopted one', ...);
test('createSite creates and links nothing', ...);
test('applyConfirmed still links', ...);          // unchanged behaviour
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_sites/data/services/ test/features/dive_log/presentation/helpers/site_suggestion_actions_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_sites/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/data/services/site_matching_service.dart lib/features/dive_log/presentation/helpers/site_suggestion_actions.dart test/features/dive_sites test/features/dive_log/presentation/helpers
git commit -m "feat(dive-sites): resolve a suggested site without linking the dive"
```

---

### Task 8: The site suggestion card, locked and during a sitting

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/site_suggestion_banner.dart` (`onDismiss` nullable)
- Modify: `lib/features/dive_log/presentation/widgets/site_suggestion_card.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart` (`pickSiteForSitting` only in this task; the row in Task 9)
- Test: `test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart`

**Interfaces:**
- Consumes: `resolve`, `createUnlinked` (Task 7); `diveHeaderCardId` (Task 5); `assignDiveSite`, `siteLocationChangeKey`, `siteSuggestionDismissKey` (Task 6); `holdChange`, `isHeld` (Task 2); `pickOrCreateSite` (`site_picker_sheet.dart:120`); `siteAreaAnchorRepositoryProvider`; `captureRulesAfterCreate`.
- Produces:

```dart
// site_suggestion_card.dart
const SiteSuggestionCard({
  super.key,
  required this.diveId,
  required this.currentSite,
  this.onSiteChanged,
  this.refreshLists,
  this.editing = const SiteSuggestionNoEditing(),
});

/// How the card's page edits the dive.
sealed class SiteSuggestionEditing {
  const SiteSuggestionEditing();
}

/// No unlock on this page: the card writes at once, as before.
final class SiteSuggestionNoEditing extends SiteSuggestionEditing {
  const SiteSuggestionNoEditing();
}

/// Locked: the card keeps its place; every button and its close are disabled.
final class SiteSuggestionLocked extends SiteSuggestionEditing {
  const SiteSuggestionLocked();
}

/// A sitting: the card's actions go to [session], held until Save. [layout]
/// is the dive the page lays itself out from (the controller's
/// `layoutRecord`, else the working dive).
final class SiteSuggestionSitting extends SiteSuggestionEditing {
  const SiteSuggestionSitting(this.session, {required this.layout});
  final EditSession<Dive> session;
  final Dive layout;
}

// dive_site_row.dart
/// Opens the site picker for the dive the sitting holds, on its GPS or the
/// area of the dives around it, and assigns the site picked or created.
Future<void> pickSiteForSitting(BuildContext context, WidgetRef ref, EditSession<Dive> session);
```

  In a sitting:
  - Whether the card shows is decided from `layout` (the controller's `layoutRecord`, or the working dive when no editor is open), so it never leaves the page under an open editor.
  - Its buttons are live only while the working dive still has the site the suggestion is about, that site has no location in the sitting, and neither `siteLocationChangeKey(site)` nor `siteSuggestionDismissKey` is held. Otherwise they are disabled.
  - **Assign:** `resolve(recommended.id)`, the logbook rules for `createdSiteIds`, then `assignDiveSite`. **Create:** the dialog, `createUnlinked`, the rules, then `assignDiveSite`. **Add location:** `holdChange(siteLocationChangeKey(site.id), cardId: diveHeaderCardId, write: () => sites.updateSiteCoordinates(site.id, point))`. **Dismiss:** `holdChange(siteSuggestionDismissKey, cardId: diveHeaderCardId, write: () => dives.setSiteSuggestionDismissed(diveId, true))`. **Choose nearby:** `pickSiteForSitting`.
  - After every `await`, nothing is set unless the session is neither disposed nor frozen and the working dive still has the site the action was for. A created or adopted site stays when the sitting is cancelled. A failure shows `siteMatchReview_applyError` and sets nothing.
  - No list refresh and no `diveProvider` invalidation in a sitting: nothing about the dive was written.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('locked: the card is shown, every button and the close are disabled', ...);
testWidgets('locked: the card has the same height as with editing off', ...);
group('in a sitting', () {
  testWidgets('assign puts the site in the sitting and writes no link', ...);
  // FakeDiveRepository.setSite never called; session.valueOf(diveSiteField)!.id is the site.
  testWidgets('assigning a catalogue site adopts it at once and runs its rules', ...);
  testWidgets('add location is held as a change of the header, and the site is not written', ...);
  testWidgets('dismiss is held, and the dive is not written', ...);
  testWidgets('choose nearby opens the site picker, not the review page', ...);
  testWidgets('create makes the site at once and holds the link', ...);
  testWidgets('with the header open, an assigned suggestion stays, disabled', ...);
  testWidgets('a write that answers after Cancel sets nothing and throws nothing', ...);
  testWidgets('a failure says so and sets nothing', ...);
});
testWidgets('with editing off it writes at once as before', ...);   // the existing tests, unchanged
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart test/features/dive_log/presentation/widgets/site_suggestion_banner_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 3: Implement**

`pickSiteForSitting` follows the form's `_showSitePicker` (`dive_edit_page.dart:3263`): one sheet at a time, the dive's entry or exit GPS as `diveLocation`, else the area anchor (`siteAreaAnchorRepository.forDive(at: working.effectiveEntryTime, tripId: working.tripId ?? working.trip?.id, diverId:, excludeDiveIds: [working.id])`), `newSiteSeedLocation` the dive's GPS. It reads its repositories and providers before the first `await`, and calls `assignDiveSite` with readers built from `siteTypesForSiteProvider`, `diveTypesProvider` (`diveTypeIdsForSiteTypes`), `elevationServiceProvider` and `siteRepositoryProvider`.

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_site_suggestion_placement_test.dart test/architecture/ test/shared/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets test/features/dive_log/presentation/widgets/site_suggestion_card_test.dart
git commit -m "feat(dive-log): the site suggestion is disabled while locked and held during a sitting"
```

---

### Task 9: The header editor, and its card

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart` (`DiveSiteRow`)
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_editor.dart`
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`_recordEditLabel` names `'header'`)
- Modify: the 11 ARB files (`diveLog_detail_section_header`), then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows_test.dart`
- Test: `test/features/change_log/presentation/change_log_labels_test.dart` (find the existing file; add a case)

**Interfaces:**
- Consumes: Tasks 4, 5, 6 and 8; `RecordNumberRow`, `FieldTextBinding` (plan 2); `showAppDatePicker` (`lib/shared/widgets/app_date_picker.dart:22`), `showTimePicker`; `FormRow.picker`, `.display`, `.rating`, `.toggle`; `diveModeLabel`, `DiveTypeBadgeRow`; `diveRepositoryProvider.getNextDiveNumber`, `validatedCurrentDiverIdProvider`; `hasPrimaryDataSource` as the form reads it (`dive_edit_page.dart:1096`); `Dive.calculateMaxDepthFromProfile`, `calculateAvgDepthFromProfile`, `calculateBottomTimeFromProfile`, `calculateRuntimeFromProfile` (`dive.dart:788-830`).
- Produces:

```dart
/// An entry or exit row: tapping it picks a date, then a time. The minute
/// on show stands for the stored instant ([pickedInstant]).
class DiveTimeRow extends StatelessWidget {
  const DiveTimeRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.hint,
    this.onClear,
    required this.firstDate,
    required this.lastDate,
  });
  final String label;
  final DateTime? value;
  /// The estimated exit, shown muted when there is no value.
  final DateTime? hint;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback? onClear;
  final DateTime firstDate;
  final DateTime lastDate;
}

/// The site row: the site's name, its location under it, a clear button.
class DiveSiteRow extends ConsumerWidget {
  const DiveSiteRow({super.key, required this.session});
  final EditSession<Dive> session;
}

class DiveHeaderCardEditor extends ConsumerStatefulWidget {
  const DiveHeaderCardEditor({super.key, required this.session});
  final EditSession<Dive> session;
}

/// The header block as a card of the dive page.
final EditCard<Dive> diveHeaderCard;   // id diveHeaderCardId; title l10n.diveLog_detail_section_header; isEmpty: (_) => false
```

  `DiveTimeRow` shows its value with `units.formatDateTimeBullet`. A date picked and then a time cancelled keeps the old time on the new date; the date alone cancelled changes nothing. Entry: `firstDate` 1950, `lastDate` tomorrow, as the form. Exit: from the earlier of the entry's and the exit's date to the entry's date plus one day, as the form (`dive_edit_page.dart:6477`); its pickers start from the exit, else the estimate, else the entry. A picked minute goes through `pickedInstant(picked, value ?? hint)`, so an estimate confirmed at its own minute stores its exact instant.

  The editor, in the hero's reading order, inside a `ListenableBuilder` on the session:
  1. Number: `RecordNumberRow(field: diveNumberField, label: diveLog_edit_label_diveNumber, integer: true, allowNegative: false, placeholder: diveLog_edit_row_notSet)`, left out while the working dive is planned or a draft.
  2. Name: a text row bound with `FieldTextBinding<Dive, String?>` (`format: (v) => v ?? ''`, `parse: (t) => FieldValue(trimmedOrNull(t))`), placeholder `diveLog_edit_diveNamePlaceholder`.
  3. `DiveSiteRow`: `FormRow.picker(label: diveLog_edit_row_site, value: site?.name, placeholder: diveLog_edit_row_addSite, onTap: pickSiteForSitting, onClear: <null with no site, else assignDiveSite(session, null, ...)>)`, and the site's `locationString` under it in the form's caption style.
  4. Entry and exit: `DiveTimeRow` with `setEntryTime` and `setExitTime`; the exit's `hint` is `estimatedExit(working)` and its `onClear` sets null.
  5. Rating: `FormRow.rating`, `0` as none.
  6. Dive mode and dive types: `FormRow.display(label: diveLog_diveMode_title, value: diveModeLabel(...))`, and the types as the hero draws them, read-only.
  7. Max depth, then average depth: `RecordNumberRow` in the depth unit at one decimal, `allowNegative: false`, each with its profile suggestion.
  8. Runtime, then bottom time: `RecordNumberRow` with `toDisplay: (s) => s / 60`, `fromDisplay: (m) => m * 60`, `integer: true`, `allowNegative: false`, suffix `min`; runtime's `apply` is `setRuntime`; each with its profile suggestion, and runtime's suggestion goes through `setRuntime` so it moves the exit.
  9. Water temperature: `RecordNumberRow` in the temperature unit, `fractionDigits: 1`, `trimZeros: true`.
  10. Favourite: `FormRow.toggle(label: diveLog_bulkEdit_fieldFavorite, ...)`.
  11. Planned: when `plannedSwitchOffered(session.stored, hasPrimarySource:)`, `FormRow.toggle(label: diveLog_edit_planned_switch, help: diveLog_edit_planned_switchSubtitle, key: Key('dive_edit_planned_switch'))` calling `setPlanned` with `nextNumber` from `getNextDiveNumber(diverId: <validated current diver>)`; for a dive stored as planned, `FormRow.display(label: diveLog_edit_planned_switch, value: diveLog_edit_planned_switchSubtitle)`.

  Profile suggestions exist only when `session.stored` has a profile, and are computed from it (a sitting does not edit the profile). Each is a `ProfileSuggestion(value: <formatted in the row's unit and decimals>, onUse: <set through the row's apply>, tooltip: diveLog_edit_tooltip_calculateFromProfile)`.

  `diveEditCards` is keyed by section and the header is not one, so `diveHeaderCard` stands alone; the Add strip never offers it.

  The new string: `"diveLog_detail_section_header": "Dive"`, with a description, translated in all 11 ARB files. `_recordEditLabel` names `'header'` with it for the `dives` table.

- [ ] **Step 1: Write the failing tests**

```dart
// dive_header_card_test.dart
testWidgets('rows show in the hero\'s order', ...);    // compare dy of each label, for a dive with every value
testWidgets('opening it and touching nothing leaves the sitting clean', ...);
// metric and imperial; a dive with seconds in its times and 12.47 m max depth; tap into every text row,
// open and dismiss each picker.
testWidgets('imperial: depths that show alike are told apart', ...);
// stored 12.41 m shows '40.7'. Type '4', '40', '40.', '40.8': closeTo(12.436).
// Then '40.', '40.7': exactly 12.41 again, and the sitting is clean.
testWidgets('a runtime typed digit by digit moves the exit; typed back, the exit is back', ...);
testWidgets('the runtime suggestion moves the exit', ...);
testWidgets('bottom time from the profile is offered, not stored', ...);
testWidgets('the number is hidden while planned, and the switch gives the stored number back', ...);
testWidgets('a stored plan shows a row that cannot be changed', ...);
testWidgets('a dive with a primary source or a draft has no switch', ...);
testWidgets('rating: tapping the current star clears it', ...);
testWidgets('favourite toggles', ...);
testWidgets('the site row clears the site and its rules take back what it set', ...);
testWidgets('the picker opens on the dive\'s GPS, else the area of the dives around it, once per tap', ...);
testWidgets('a decimal comma is read; unreadable text marks the card', ...);
testWidgets('a value arriving underneath is followed, and the caret stays put', ...);

// dive_header_time_rows_test.dart
testWidgets('the stored minute picked again changes nothing', ...);
testWidgets('a date with the time cancelled keeps the old time on the new date', ...);
testWidgets('a dive with no exit shows the estimate as a hint', ...);
testWidgets('the estimate picked at its own minute is stored exactly', ...);
testWidgets('the exit range is the form\'s', ...);

// change_log_labels_test.dart
test('a sitting that changed the header is named Dive', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_test.dart test/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement, add the string to all 11 ARB files, run `flutter gen-l10n`**

Keep `dive_header_card_editor.dart` under 400 lines; the time rows and the site row are their own files.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/change_log/ test/architecture/ test/shared/ test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail lib/features/change_log lib/l10n test/features/dive_log/presentation/widgets/dive_detail test/features/change_log
git commit -m "feat(dive-log): edit the dive page's header block in place"
```

---

### Task 10: The header block reads the sitting, has its pencil, and writes nothing while locked

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_header_block.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_hero_header.dart` (a `titleTrailing` slot)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart` (`diveTypeIdsField.alsoShownOn`)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (the header block; favourite in the bar and the menu)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_header_block_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_hero_header_test.dart` (add cases)

**Interfaces:**
- Consumes: `RecordCardPencil` (Task 4); `SiteSuggestionEditing` (Task 8); `diveHeaderCard` (Task 9).
- Produces:

```dart
/// The fixed block above the sections: the planned and draft banners, the
/// site suggestion and the hero card. Framed as the header card when the
/// page offers editing.
class DiveDetailHeaderBlock extends ConsumerWidget {
  const DiveDetailHeaderBlock({
    super.key,
    required this.stored,
    required this.shown,
    required this.embedded,
    required this.onMarkLogged,
    required this.onDownloadDraft,
    required this.onSurfaceDraft,
  });
  /// The dive as stored: the banners and their whole-record operations.
  final Dive stored;
  /// The dive the page shows: the sitting's during one.
  final Dive shown;
  final bool embedded;
  final VoidCallback onMarkLogged;
  final VoidCallback onDownloadDraft;
  final VoidCallback onSurfaceDraft;
}

// DiveHeroHeader gains
final Widget? titleTrailing;   // drawn at the end of the title row
```

  `DiveDetailHeaderBlock` builds exactly the page's lines 529-545 today: banners from `stored` (when not embedded), `SiteSuggestionCard(diveId:, currentSite: stored.site, editing:)`, where `editing` is `SiteSuggestionNoEditing()` with no `RecordEditScope` above, `SiteSuggestionLocked()` while its controller is locked, and `SiteSuggestionSitting(session, layout: controller.layoutRecord ?? session.working)` while unlocked, then `DiveDetailHeroSection(dive: shown, ...)`. With a `RecordEditScope` above it, the hero is wrapped in `RecordCardFrame<Dive>(card: diveHeaderCard, ...)` and given `titleTrailing: RecordCardPencil(cardTitle: <the card's title>)`. The page calls it with `stored: dive, shown: shown`.

  `DiveDetailHeroSection` during a sitting: a stat whose field the sitting changed (`!field.same(session.valueOf(field), field.read(session.stored))`) shows the dive's value; an untouched one follows the viewed source as today (call 11). The hero's own site tap and the data quality chip keep working while unlocked.

  `diveTypeIdsField.alsoShownOn` becomes `{diveHeaderCardId}`.

  The page, when `editingOffered`: the bar's favourite is an `Icon` (filled or outlined, `semanticLabel` the favourite state) with no button, and the overflow menu's `toggleFavorite` item is left out (`showFavorite: false`). Without editing offered, both as today.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('editing off: the same widgets in the same order as before', ...);
// PlannedDiveBanner, DraftDiveBanner, SiteSuggestionCard, DiveDetailHeroSection; no RecordCardFrame.
testWidgets('locked: no pencil, and the hero is the same height as with editing off', ...);
testWidgets('unlocked: a pencil in the title row, and the hero keeps its height', ...);
testWidgets('the pencil opens the header card where it sits', ...);
testWidgets('a tap on the hero still opens the site while unlocked', ...);
testWidgets('after Done the hero shows the sitting\'s name, site, times and stats', ...);
testWidgets('a changed max depth shows over the viewed source; an untouched one follows it', ...);
testWidgets('dive types changed on Details redraw the closed header', ...);
testWidgets('the banners follow the stored dive during a sitting', ...);
// the page:
testWidgets('editing offered: the bar shows favourite as a state, with no button and no menu item', ...);
testWidgets('editing off: the bar toggles favourite as before', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_header_block_test.dart test/features/dive_log/presentation/widgets/dive_hero_header_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then every `test/features/dive_log/presentation/pages/dive_detail*_test.dart` file and `test/architecture/ test/shared/`
Expected: PASS. `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart` is at most 787.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "feat(dive-log): the dive page's header block is a card, and shows favourite as a state while locked"
```

---

### Task 11: Cards with no editor show the stored dive through a sitting

The section list hands every card the dive the page shows, which during a sitting is the working copy. With the site, the times and the depths now editable, Tide would fetch for a site not yet saved, the deco and tissue cards would rework a dive not yet saved, and cards would come and go as they do. The spec says a calculated card keeps showing the stored values until the sitting is saved. Plan 3 handed three readers the held layout by name and left the general rule to this plan.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart` (`_sectionContent`, `_buildPairCards`)
- Test: `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_stored_test.dart`

**Interfaces:**
- Consumes: `RecordEditScope.maybeOf<Dive>`, `session.stored`; `diveEditCards`.
- Produces: no new names. The rule for later plans: a section with an entry in `diveEditCards` draws the working dive and decides its presence from the held layout; a section with none draws `edit?.session?.stored ?? dive` and decides its presence from the same. A calculated block inside a card that can be edited (Environment's satellite lines) reads the stored dive too. When a plan gives a card an editor, it moves to the first group by being added to `diveEditCards`.

- [ ] **Step 1: Write the failing tests**

Tide data and satellite conditions supplied the way `dive_detail_section_list_details_editing_test.dart` supplies them.

```dart
testWidgets('a site picked in the header leaves Tide on the stored site until Save', ...);
testWidgets('fresh water picked on Details leaves the Tide card in place after Done', ...);   // was: until Done
testWidgets('an entry moved leaves the deco card as stored', ...);
testWidgets('the Environment card\'s satellite lines follow the stored site', ...);
testWidgets('after Save the cards follow the saved dive', ...);
testWidgets('locked, every card draws the dive as before', ...);
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_stored_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Replace the per-card `presence` hand-offs plan 3 made for Tide, Signatures, the two pairs and the satellite block with the one rule. Update plan 3's tests in `dive_detail_section_list_details_editing_test.dart` whose expectation was "until Done" to "until Save", and say so in the commit body.

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_detail/ test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart test/features/dive_log/presentation/widgets/dive_detail
git commit -m "feat(dive-log): cards with no editor keep the stored dive until a sitting is saved"
```

---

### Task 12: The page, end to end

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart` (a site, a profile, a fake `ElevationService`, site types)
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_header_test.dart` (new)

**Interfaces:**
- Consumes: everything above; `siteSpottedSpeciesProvider(siteId)`, which the form invalidates for the dive's site after a save (`dive_edit_page.dart:6882`).
- Produces: one more guarded step in `DiveSittingFollowUp.run`: when `before.site?.id != after.site?.id`, `siteSpottedSpeciesProvider` is invalidated for each of the two sites, through the container as the course step does. A dive moved between sites changes what both have seen.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the header has a pencil; its editor opens where the hero was', ...);
testWidgets('opening and closing the header in imperial units leaves the sitting clean', ...);
testWidgets('a site picked in the header: Details, Environment and Altitude get their dots, and Save names all four', ...);
// FakeSave.changedCardIds == {'header', 'details', 'environment', 'altitude'}.
testWidgets('the Altitude card a site brings does not appear until the header closes', ...);
testWidgets('site A, then site B: Save writes B\'s altitude to B only', ...);
testWidgets('Cancel after picking a site leaves the dive and the sites as they were', ...);
testWidgets('the suggestion dismissed and saved alone is one save', ...);
testWidgets('a location added from the suggestion is written to the site with the save', ...);
testWidgets('times moved and a runtime typed are saved exactly', ...);
testWidgets('a planned switch turned on saves a plan with no number', ...);
testWidgets('favourite set in the editor is saved, and the locked bar then shows it', ...);
testWidgets('the trip stretches when the entry moves the dive outside it', ...);
testWidgets('a species refresh that throws is not a failed save', ...);
testWidgets('a locked page makes no write on any tap in the header block', ...);
// tap the hero, the favourite state, every suggestion button and its close: no repository write.
```

- [ ] **Step 2: Run and confirm they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_header_test.dart`
Expected: the species refresh test FAILs. Any other new test that passes at once is checked by breaking the code it pins and seeing it fail, then restored.

- [ ] **Step 3: Implement the follow-up step**

- [ ] **Step 4: Run and confirm they pass**

Run: the Step 2 command, then `flutter test test/features/dive_log/presentation/pages/dive_detail_page_unlock_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_details_test.dart test/features/dive_log/presentation/pages/dive_detail_page_unlock_cards_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyse, run the guards and the page tests**

Run: `dart format .`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database/`
Run: every `test/features/dive_log/presentation/pages/dive_detail*_test.dart` and `dive_edit_*_test.dart` file, `test/features/dive_log/presentation/widgets/`, `test/features/dive_log/data/services/`, `test/features/dive_log/domain/`, `test/features/dive_sites/` and `test/features/change_log/`.
Expected: PASS.
Run: `wc -l lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: at most 787.

- [ ] **Step 6: Look at it**

Render the page in a throwaway widget test (real fonts from the SDK's `material_fonts` folder, deleted afterwards): the top of the page locked with a suggestion (buttons disabled) and the favourite state; unlocked with the pencil; the header open with every value set, and with none; the exit's estimate; the planned switch; the suggestion in a sitting with the header open. Light and dark, metric and imperial, phone and desktop width. Check by eye that the hero does not move or grow on unlock and that the open editor's rows line up. Fix what is wrong with a test first, and keep the pictures, with the "before" ones from Preparation, for the pull request.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_sitting_follow_up.dart test/features/dive_log/presentation/pages
git commit -m "feat(dive-log): after a sitting that moved the dive's site, refresh its species"
```

---

## Pull request

One, `Refs #4527`. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the "before" pictures from Preparation and the pictures from Task 12 Step 6, with a line saying the unlocked page is unreachable without the build switch. With the switch off nothing on the page looks different; say so. Pushing and opening it waits for Eric.

## For plans 5 to 8

- **Plan 5 (Tanks, Equipment, Weights).** The dive mode field names `'details'` and `'header'` in `alsoShownOn`. A site change re-checks geofenced gear (`_reevaluateGeofenceForSite`, `dive_edit_page.dart:4504`): call it from `assignDiveSite`'s caller, not from inside it, so the site rules stay free of gear. Gas switches hide while `session.working.isPlanned`. Bottom time and runtime limit gas-switch times: read them from the sitting.
- **Plan 6.** The route row hides, and route links are not saved, for a planned dive. Species suggestions follow `session.working.site`.
- **Plan 7.** "Mark as logged", "Surfaced" and "Mark as complete" on the banners become whole-record operations; they read the stored dive already (`DiveDetailHeaderBlock.stored`).
- **Plan 8 (new dive).** The header card is the essential card. `setPlanned`'s `nextNumber` is the same suggestion the new dive needs when it is not planned; a prefilled site goes through `assignDiveSite`.
- **Any plan giving a card an editor:** add it to `diveEditCards`; Task 11's rule then hands it the working dive.

---

## After the review

The plan was built as written in this session, then reviewed as a whole branch by a fresh reviewer. This is what differs from the task text above, for whoever writes plan 5.

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `RecordEditController.save` awaits `session.settled()` | Only when work is tracked: `EditSession.isSettled`. With nothing tracked the write starts at once, as before |
| `RecordNumberRow.apply` | Also on `FieldTextBinding.apply`, through which the row writes |
| `RecordCardPencil` | And `RecordPencilIcon`, the pencil both it and `RecordCardHeader` draw |
| `exitFollows(session)` reads the stored dive | Settled the first time the sitting asks, from the dive as it then is, and settled again by a site from what it set; false for the rest of the sitting once the exit is edited directly |
| `pickedInstant(picked, current)` | `pickedInstant(picked, current, stored:)`: the stored instant first, so a time moved and moved back is no change; a new day at the same time of day keeps the seconds |
| `DiveTimeRow` is a `StatelessWidget` | A `ConsumerWidget` (it formats its own value), with `stored:` |
| `SiteSuggestionSitting(session, layout: layoutRecord ?? working)` | `layout` is the controller's `layoutRecord`, null while no card is open |
| `readDiveSiteAssigner(ref)` | `readDiveSiteAssigner(context)`: built from the provider container, as its reads can answer after the widget has gone |
| `diveCardIsOnPage(ref, id, layout:, working:)` | Gains `stored:`; the section list and the Add strip both pass it, and what a card works out (satellite conditions) is asked of it |
| The header block tests in `widgets/dive_detail/` | `dive_detail_page_unlock_header_block_test.dart`, through the unlock harness, which gained `sources:` |
| Task 11's tests in a new file | In `dive_detail_section_list_details_editing_test.dart`, where plan 3's "until Done" tests now read "until Save" |
| `resolveCandidate` tests in `site_matching_service_test.dart` | `site_matching_service_resolve_test.dart`, so neither file passes 800 lines |

### Decided while building

- The locked bar shows a filled heart on a favourite dive and nothing on any other, at every width. (Built first without it at phone width, which left a phone no place showing the state; the pull request's review caught it.)
- Unlocking still moves the hero down by the Add strip's height on a page that fits, as #4566 left it; the spec says unlocking moves nothing.
- `setRuntime` notes the exit before a typed runtime first moved it; a runtime emptied or zero gives that exit back, unless the diver picked an exit since.
- The site suggestion keeps its place, disabled, while a sitting is saved.
- A code review of the pull request added: Save waits at most ten seconds for tracked work, and tells the page once the sitting is frozen; the open card reads runtime and bottom time in whole minutes cut, as the hero and the form do; the stored runtime typed back on a dive stored with no exit moves the exit the diver picked instead of clearing it; the suggestion's Assign and Create in a sitting are tracked (Save waits for them) and run one at a time, and `resolveCandidate` and `createSite` answer before their altitude lookup.
- The planned switch waits for the dive's data sources: while they load the editor offers no switch, so a downloaded dive cannot be marked as planned before its source is known (pull request review).

### Left open

- A location added from the suggestion during a sitting is written without the altitude lookup the immediate path runs after it.
- The altitude take-back restores the stored altitude, not the value before the lookup: a stored altitude the diver cleared comes back.
- The estimated exit, shown as the exit row's placeholder, reads much like a recorded exit.
- Tests not written: the site picker opening on the dive's GPS or area, once per tap; a held location actually written by Save; a species refresh that throws; the hero's site tap while unlocked; the stored site picked back after two others.

### Cleared later (PR #4670)

- A location added from the suggestion has the site's altitude looked up, after the save commits (the held write notes the site; `sitesLocatedInSave`).
- Taking back a looked-up altitude restores none, as before the lookup, so one the diver cleared stays cleared.
- The five tests are written (`dive_detail_page_unlock_site_test.dart`); the species refresh, which only invalidates and cannot throw, is tested through the read after it.
- Still open, needing a decision: the estimated exit placeholder's wording.
