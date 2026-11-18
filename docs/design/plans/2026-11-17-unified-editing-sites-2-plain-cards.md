# Unified editing, sites, plan 2: the plain cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every site card that holds plain values editable in place: the header block (name, water type), Location (coordinates and place names, with their lookups), Altitude (with the found-elevation suggestion), Depth, Difficulty, Rating, Hazards and Access; fade the calculated cards; and pin with a census that a site sitting carries every column it does not change (issue #4527, phase 2). Still behind `kUnlockSiteEditing`.

**Architecture:** Plan 1 (PR #4686) put the site page on `RecordEditHost<_SiteDetailContent, DiveSite>` with `siteEditCards` holding Description and Notes. This plan adds an `EditField<DiveSite, V>` for each remaining plain column, one `EditCard<DiveSite>` per card, and their editors, built from the shared rows (`FieldTextBinding`, `RecordNumberRow`, `SuggestionFormRow`, `CoordinateFieldGroup`, `EnumMultiPickerRow`). The form's location and altitude rules move out of `SiteEditPage` widget state into functions of the sitting. The page frames every card in `siteEditCards`, builds an empty card while the sitting has it open, and offers empty cards in the Add strip, as the dive page does.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift (SQLite), `flutter gen-l10n` (one new string).

**Spec:** [docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md](../specs/2026-11-17-unified-editing-phase-2-sites-design.md), sections "The site page's cards", "Rules that span cards" and "What is held, and what is not".

## Global Constraints

- Built on plan 1's names (`RecordEditHost`, `SiteEditSaveService`, `siteEditCards`, `SiteMarkdownCardEditor`, `_SiteDetailPageEditing`, `SiteDetailSectionList(alsoShown, heldOpen, foldTrailing)`). This branch stacks on PR #4686; rebase onto `origin/main` once it merges, before the first push.
- With `kUnlockSiteEditing` false the site page looks and behaves exactly as today; no existing site test changes its expectations.
- Units in every editor follow the active diver's settings (`UnitFormatter`): depth with `convertDepth` / `depthToMeters` / `depthSymbol`, altitude with `convertAltitude` / `altitudeToMeters` / `altitudeSymbol`. Coordinates keep decimal-degree text in their controllers; the notation is only `CoordinateFieldGroup`'s display.
- Card ids are `SiteDetailSectionId` names, plus `siteHeaderCardId = 'header'`.
- Only what changed is written, on top of the site as stored at Save (plan 1's `SiteEditSaveService`).
- Two new strings, in every ARB file, then `flutter gen-l10n`: `diveSites_detail_section_header` ("Site"), the header block's card name in History, each locale's value that locale's existing `diveLog_edit_row_site`; and `diveSites_edit_altitude_foundTooltip` ("Found for these coordinates"), the altitude suggestion's tooltip, translated for each locale. Both are added in Task 3, the first task that uses either.
- Never use em-dashes or en-dashes as punctuation. Commits, the PR and files follow the repository guide's Attribution section.
- Test runs: only the test files a task writes or changes, by path, at most 15 per run. Never a folder, never the whole suite, never guards by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner.

## Review Focus

1. **Coordinates half typed** (a latitude with no longitude, or `91`). The card stays open, Save is refused and the field says why; nothing reaches the sitting until both read as a position. Pinned in Task 3.
2. **The altitude lookup answers after the diver typed an altitude.** The typed value stands; a late answer fills nothing. Pinned in Task 2.
3. **A lookup answers after the coordinates moved again.** Its place names are dropped, as the form drops them. Pinned in Task 2.
4. **The name emptied.** The header card stays open and Save is refused with the name's message; an untouched site whose stored name is somehow blank is not blocked from saving another card. Pinned in Task 3.
5. **A card emptied and closed** (all access fields cleared). It leaves the page and returns to the strip, and Save writes the clears. Pinned in Task 6.

## Preparation

- [ ] On branch `ericgriffin/unified-editing-sites-2-plain-cards` (cut from plan 1's head). Generate code unfiltered in the background if the worktree is fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `flutter analyze` on the whole repository is clean.
- [ ] Commit this plan: `git add docs/design/plans/2026-11-17-unified-editing-sites-2-plain-cards.md && git commit -m "docs(sites): unified editing phase 2 plan 2"`.

## File Structure

New (`lib/features/dive_sites/presentation/editing/`):

| File | Responsibility |
| --- | --- |
| `site_plain_fields.dart` | The `EditField`s of the header, Location, Altitude, Depth, Difficulty, Rating, Hazards and Access cards, and `siteHeaderCardId` |
| `site_location_rules.dart` | Place lookups and the altitude lookup as functions of the sitting |
| `site_header_card_editor.dart` | Name (required, similar-name hint), water type |
| `site_coordinate_rows.dart` | `SiteCoordinateRows`: the coordinate pair bound to `siteLocationField` |
| `site_location_card_editor.dart` | Coordinates, Use my location, Pick from map, Look up, place names |
| `site_measure_card_editors.dart` | Altitude (with the suggestion), Depth, Difficulty, Rating editors |
| `site_access_card_editors.dart` | Hazards and Access editors |

Modified:

| File | Change |
| --- | --- |
| `lib/features/dive_sites/domain/entities/dive_site.dart` | `copyWith(clearAltitude:)` |
| `presentation/editing/site_edit_cards.dart` | Every new card; `siteHeaderCard` |
| `presentation/pages/site_detail_page_editing.dart` | Strip offers empty cards; header frame; calculated fades |
| `presentation/pages/site_detail_page.dart` | Frames every card in `siteEditCards` and the header; builds an open empty card |
| `presentation/widgets/site_detail_header.dart` | `RecordCardPencil` at the end of the name row |
| `lib/features/change_log/presentation/change_log_labels.dart` | `dive_sites` + `header` names the header card |
| `lib/l10n/arb/*.arb` | `diveSites_detail_section_header`, `diveSites_edit_altitude_foundTooltip` |
| `test/architecture/markdown_notes_adoption_test.dart` | The Access editor, token `'markdown: true'` |

---

### Task 1: The fields, `clearAltitude`, and the census

**Files:**
- Create: `lib/features/dive_sites/presentation/editing/site_plain_fields.dart`
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart`
- Test: `test/features/dive_sites/presentation/editing/site_plain_fields_test.dart`, `test/features/dive_sites/data/services/site_edit_save_census_test.dart`

**Interfaces:**
- Produces, each `EditField<DiveSite, V>` with `id` the entity field name and the card it belongs to. A nullable field's `write` passes its `clear*` flag for null:
  - header (`siteHeaderCardId = 'header'`): `siteNameField` (String), `siteWaterTypeField` (WaterType?)
  - `location`: `siteLocationField` (GeoPoint?), `siteCountryField` (String?), `siteCountryCodeField` (String?), `siteRegionField`, `siteCityField`, `siteIslandField`, `siteBodyOfWaterField` (String?)
  - `altitude`: `siteAltitudeField` (double?, metres)
  - `depth`: `siteMinDepthField`, `siteMaxDepthField` (double?, metres)
  - `difficulty`: `siteDifficultyField` (SiteDifficulty?)
  - `rating`: `siteRatingField` (double?)
  - `hazards`: `siteHazardsField` (String?)
  - `access`: `siteParkingInfoField`, `siteAccessNotesField`, `siteMooringNumberField` (String?), `siteEntryMethodsField`, `siteExitMethodsField` (List<EntryMethod>, order-insensitive `equals`)
  - `siteSittingFields`: every field of plan 1 and this plan, in card order.
- `DiveSite.copyWith({..., bool clearAltitude = false})`.

- [ ] **Step 1: Write the failing tests.**
  - `site_plain_fields_test.dart`: for each field, `write(site, read(site))` equals `site`; writing null to a nullable field reads back null (`clearAltitude` among them); `siteEntryMethodsField.same([shore, boat], [boat, shore])` is true; every field's `cardId` is a `SiteDetailSectionId` name or `'header'`.
  - `site_edit_save_census_test.dart` (test database as plan 1's save service test):
    - `every editable column has a sitting field`: the names of `db.diveSites.$columns` minus a `notASittingValue` map (`id`, `diver_id`, `created_at`, `updated_at`, `catalogue_id`, `catalogue_answers`, `shared_library_id`, each with a reason; `is_shared` with the reason "sharing, plan 3") equal the columns `siteSittingFields` cover (a `columnOf` map in the test from field id to column name: `location` covers `latitude` and `longitude`, `entryMethods` covers `entry_method`, `exitMethods` covers `exit_method`).
    - `a sitting carries every column it does not change`: store a site with every column set; then set every column to a second value with raw SQL; save a sitting that changes only `notes` through `SiteEditSaveService`; every column but `notes`, `updated_at` and the sync bookkeeping holds its second value.
- [ ] **Step 2:** Run both test files. Expected: compile failure (no fields, no `clearAltitude`).
- [ ] **Step 3:** Add `clearAltitude` to `copyWith` and create `site_plain_fields.dart`.
- [ ] **Step 4:** Run both test files. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): sitting fields for every plain site column, with a census`.

### Task 2: The location and altitude rules as functions of the sitting

**Files:**
- Create: `presentation/editing/site_location_rules.dart`
- Test: `test/features/dive_sites/presentation/editing/site_location_rules_test.dart`

**Interfaces:**
- Consumes: `mergeLocationDetails`, `SiteLocationDetails` (`domain/services/site_location_merge.dart`), `PlaceLookup` (`core/services/geocoding/place_lookup.dart`).
- Produces:
  - `bool applyPlaceLookup(EditSession<DiveSite> session, PlaceLookup lookup, {required bool overwrite})`: the form's `_applyPlaceLookup` over the sitting's `siteCountryField`, `siteCountryCodeField`, `siteRegionField`, `siteCityField`, `siteBodyOfWaterField`; a written country keeps its code; returns whether any value changed.
  - `Map<String, String> differingPlaceValues(EditSession<DiveSite> session, PlaceLookup lookup, AppLocalizations l10n)`: the form's `_differingLookupValues`, by field label.
  - `void moveSiteTo(EditSession<DiveSite> session, GeoPoint point, {PlaceLookup? place})`: sets `siteLocationField`, then fills the empty place names from `place` (`overwrite: false`).
  - `void scheduleAltitudeAfterMove(EditSession<DiveSite> session, Future<double?> Function(GeoPoint) fetch, {Duration delay = const Duration(seconds: 1)})`: after `delay`, tracked (`session.track`), fetches the elevation for the sitting's position and sets `siteAltitudeField` when it is still empty and the position is unchanged; a later call replaces the pending one (key `'altitude.move'` in `session.remember`). Called by the Location editor when the diver changes the coordinates.
  - `Future<double?> foundAltitude(EditSession<DiveSite> session, Future<double?> Function(GeoPoint) fetch)`: for a site whose stored position is set and altitude empty, asks `fetch` once per sitting (`session.firstTime('altitude.found')`), keeps the answer (`remember('altitude.found.value')`), and returns it; null otherwise. Changes nothing in the sitting.
  - `Future<double?> fetchSiteElevation(ProviderContainer container, GeoPoint point)`: `elevationServiceProvider`'s `fetchElevation`, the one production `fetch`.

- [ ] **Step 1: Write the failing tests** (sessions over plain `DiveSite`s; `fetch` a fake with a `Completer`):
  - `applyPlaceLookup fills only empty names` and `overwrite replaces differing ones`; `a written country keeps its code`.
  - `differingPlaceValues lists only found values that differ`.
  - `moveSiteTo sets the position and fills empty names`; the location card is changed.
  - `the altitude fills after a move when empty`: `fakeAsync`, advance one second, answer 12; `siteAltitudeField` is 12 and the altitude card is changed.
  - `a typed altitude stands`: the diver sets 30 before the answer; it stays 30.
  - `a lookup for an old position is dropped`: move, move again before the answer of the first; only the second position's answer fills.
  - `the found altitude changes nothing`: `foundAltitude` returns 12; the sitting is not dirty; a second call does not fetch again.
- [ ] **Step 2:** Run the test file. Expected: compile failure.
- [ ] **Step 3:** Implement the functions in `site_location_rules.dart`.
- [ ] **Step 4:** Run the test file. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): the location and altitude rules as functions of the sitting`.

### Task 3: The header block and Location cards

**Files:**
- Create: `presentation/editing/site_header_card_editor.dart`, `presentation/editing/site_coordinate_rows.dart`, `presentation/editing/site_location_card_editor.dart`
- Modify: `presentation/editing/site_edit_cards.dart`, `presentation/widgets/site_detail_header.dart`, `presentation/pages/site_detail_page.dart` (frame the header), `lib/features/change_log/presentation/change_log_labels.dart`, `lib/l10n/arb/*.arb` (both new strings)
- Test: `test/features/dive_sites/presentation/editing/site_header_card_editor_test.dart`, `test/features/dive_sites/presentation/editing/site_location_card_editor_test.dart`, `test/features/change_log/presentation/change_log_labels_test.dart`

**Interfaces:**
- Consumes: Task 1 fields, Task 2 rules.
- Produces:
  - `siteHeaderCard = EditCard<DiveSite>(id: siteHeaderCardId, title: diveSites_detail_section_header, isEmpty: (_) => false, isValid: the sitting's name is not blank, or is the stored name unchanged (a stored blank name is not the diver's to fix before saving another card), editorBuilder: SiteHeaderCardEditor)`. The page wraps `SiteDetailHeader` in `RecordCardFrame<DiveSite>(card: siteHeaderCard)`; `SiteDetailHeader` ends its name row with `RecordCardPencil(cardTitle: ...)`.
  - `SiteHeaderCardEditor({required EditSession<DiveSite> session})`: name through `SuggestionFormRow` bound with `FieldTextBinding` (trimmed text; the error `diveSites_edit_field_siteName_validation` when blank, reported with `setFieldInvalid('header', 'name', ...)`), the `SimilarValueHint` the form shows under it, water type as the form's `ChoiceChip`s (tap the selected one to clear).
  - `SiteCoordinateRows({required EditSession<DiveSite> session, required CoordinateFormat format, ValueChanged<GeoPoint?>? onMoved})`: two decimal-text controllers in a `CoordinateFieldGroup`. Both blank sets null; both readable and in range sets a `GeoPoint`; otherwise the card's field `location` is unreadable (`setFieldInvalid('location', 'location', invalid: true)`). It follows a session change it did not make (a pick from the map). `onMoved` is called on the diver's own change.
  - `SiteLocationCardEditor({required EditSession<DiveSite> session})`: `SiteCoordinateRows` (its `onMoved` calls `scheduleAltitudeAfterMove`), Use my location and Pick from map (as the form's `_useMyLocation` and `_pickFromMap`, then `moveSiteTo` and the same snack bars), Look up from coordinates (`PlaceLookupRow`; fills empty names, asks with `diveSites_edit_lookupReplace_*` before replacing differing ones), and the five place names as `SuggestionFormRow`s with the form's suggestion lists. The country row's binding `apply`s a typed country with its code read afresh (`siteCountryCodeField` set to `countryCodeFor(text)`, null when it names no country), as `countryCodeOnSave` treats text the diver changed; a looked-up country keeps the geocoder's code (`applyPlaceLookup`).
  - `siteEditCards` gains `location` (`isEmpty: (_) => false`).
  - History: `'dive_sites'` with `'header'` names `diveSites_detail_section_header`.

- [ ] **Step 1: Write the failing tests.**
  - Header: `typing the name writes it`; `a blank name refuses Save and shows the message` (`isValid` false, `invalidCardIds` has `header`); `a stored blank name does not block saving another card` (`isValid` true while the name is unchanged); `tapping the selected water type clears it`.
  - Location: `a typed country carries its code` (type `Belize`: code `BZ`; type `Atlantis`: code null);
    `typed coordinates reach the sitting once both read`; `half-typed coordinates keep the card open and refuse Save`; `a pick from the map fills the coordinates and the empty names` (push faked through a `LocationPickerMap` result); `Look up asks before replacing differing names`; `typing new coordinates fills an empty altitude a second later` (fake elevation).
  - Labels: `record_edit:dive_sites:s1:header,notes` reads `Edited: Site, Notes`.
- [ ] **Step 2:** Run the three test files. Expected: failures.
- [ ] **Step 3:** Add the string to every ARB file, run `flutter gen-l10n`, and implement.
- [ ] **Step 4:** Run the three test files and plan 1's `site_detail_page_unlock_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): edit the header block and Location in place`.

### Task 4: Altitude, Depth, Difficulty and Rating

**Files:**
- Create: `presentation/editing/site_measure_card_editors.dart`
- Modify: `presentation/editing/site_edit_cards.dart`
- Test: `test/features/dive_sites/presentation/editing/site_measure_card_editors_test.dart`

**Interfaces:**
- Produces, each registered in `siteEditCards`:
  - `altitude`: `isEmpty: site.altitude == null`; editor `SiteAltitudeCardEditor`, a `RecordNumberRow<DiveSite>` on `siteAltitudeField` in the diver's altitude unit with `suggestion: ProfileSuggestion(value: <found, formatted>, onUse: set the field, tooltip: diveSites_edit_altitude_foundTooltip)` while `foundAltitude` has an answer and the field is empty.
  - `depth`: `isEmpty: (_) => false` (always shown today); `SiteDepthCardEditor`, two `RecordNumberRow`s in the diver's depth unit; `isValid`: min not above max.
  - `difficulty`: `isEmpty: site.difficulty == null`; the form's `ChoiceChip`s.
  - `rating`: `isEmpty: (_) => false`; `FormRow.rating` with clear.

- [ ] **Step 1: Write the failing tests.** `altitude shows in the diver's unit and writes metres` (feet setting: type 100, field is 30.48); `the found altitude is offered and used only on a tap` (sitting clean until tapped); `a minimum deeper than the maximum refuses Save`; `difficulty chips set and clear`; `rating sets and clears`.
- [ ] **Step 2:** Run. Expected: failures.
- [ ] **Step 3:** Implement and register.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): edit altitude, depth, difficulty and rating in place`.

### Task 5: Hazards and Access

**Files:**
- Create: `presentation/editing/site_access_card_editors.dart`
- Modify: `presentation/editing/site_edit_cards.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/dive_sites/presentation/editing/site_access_card_editors_test.dart`

**Interfaces:**
- Produces:
  - `hazards`: `isEmpty: hazards blank`; a `SuggestionFormRow` bound to `siteHazardsField`, as the form's row.
  - `access`: `isEmpty` as the page's `_hasAccessInfo`; parking and mooring as plain rows, access notes as `SuggestionFormRow(markdown: true)`, entry and exit methods as `EnumMultiPickerRow<EntryMethod>`, and the form's entry suggestion chip (from `siteEntryExitSuggestionProvider(session.stored.id)`, offered while both method lists are empty, filling both on a tap).
  - The guard lists `site_access_card_editors.dart` with `'markdown: true'`.

- [ ] **Step 1: Write the failing tests.** `hazards write through`; `access notes edit as Markdown`; `entry methods set and clear`; `the entry suggestion fills both methods on a tap and is gone once either is set`.
- [ ] **Step 2:** Run. Expected: failures.
- [ ] **Step 3:** Implement, register, add the guard entry.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): edit hazards and access in place`.

### Task 6: The page frames every editable card, offers empty ones, and fades calculated ones

**Files:**
- Modify: `presentation/pages/site_detail_page.dart`, `presentation/pages/site_detail_page_editing.dart`, `presentation/editing/site_edit_cards.dart`
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_unlock_cards_test.dart` (on plan 1's harness)

**Interfaces:**
- Consumes: plan 1's `_framed`, `_sectionsShownForSitting`, `addStripEntries`, `editController.layoutRecord`, `layoutAnswer`.
- Produces:
  - `_framed` frames any section with a card in `siteEditCards`; a section whose builder is null (nothing to show) gets an empty body while its card is open, so the frame shows the editor; closed it stays out.
  - `addStripEntries` offers each section with a card that is hidden, or empty for the page's layout record (`card.isEmptyDuring(editController.layoutRecord ?? working, session)`), not open and not added, in section order, as the dive's `addStripEntries` does.
  - `_framed` wraps `diveStatistics`, `divePhotos`, `tide`, `seascape`, `reefHealth` in `RecordCardFade<DiveSite>(reason: RecordCardFadeReason.calculated)` while the page hosts editing.
  - The cards are those Tasks 3 to 5 registered; this task adds no card.

- [ ] **Step 1: Write the failing tests:**
  - `an empty card is offered in the strip and opens in place`: a site with no hazards, unlocked; the strip has a `Hazards & Safety` chip (not dashed); tapping it shows the open card at its place in the order.
  - `a card emptied and closed returns to the strip and Save writes the clear`.
  - `calculated cards fade while unlocked`: the dive statistics card is wrapped in a `RecordCardFade` showing `RecordCardFadeReason.calculated`'s word; locked, no fade.
  - `no card comes or goes above an open editor`: with Notes open, clearing hazards in another open card does not remove its card until Notes closes (layout record held).
- [ ] **Step 2:** Run the test file. Expected: failures.
- [ ] **Step 3:** Implement as the Interfaces block says.
- [ ] **Step 4:** Run the test file and plan 1's `site_detail_page_unlock_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(sites): frame every editable card, offer empty ones, fade calculated ones`.

### Task 7: Push, review, screenshots, PR

- [ ] **Step 1:** `git fetch origin main`; if #4686 has merged, `git rebase origin/main` and run `flutter analyze` on the whole repository.
- [ ] **Step 2:** `dart format` changed files; whole-repo `flutter analyze` clean; push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file meanwhile; fix what the hook finds, each fix its own commit.
- [ ] **Step 3:** `/code-review` with `--max-findings all`; fix every valid finding; push.
- [ ] **Step 4:** Headless screenshots as plan 1 took them (switch on, throwaway golden test, deleted after): the header card open, Location open with coordinates and the place names, Altitude with the suggestion, Access open, the strip with empty cards, and a calculated card faded; phone and desktop widths, light mode. Attach through the project's current screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, `Refs #4527`, base `main` (after #4686 merges; until then base on plan 1's branch and say so); bind it and turn Auto-fix on.
