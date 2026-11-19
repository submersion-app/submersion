# Unified editing, phase 3, plan 8: equipment sets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An equipment set opens locked and edits in place, every card held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). That includes what the set page writes at once today: Show and Hide figure, and Set as default. The edit form stays until the switch-over plan; a new set and a clone are plan 11's.

**Architecture:** As plans 3 and 4: the page's state mixes in `RecordEditHost` and `RecordOpenUnlocked`, its cards are `EditCard`s keyed by `EquipmentSetCardId` (shipped by plan 1), and an `EquipmentSetEditSaveService` writes through `writeRecordSitting`. Every value of a set is a field on `EquipmentSet` (the set is read with its members, bundle lists and geofences already), so the sitting's working set drives the whole page: the figure, the item count and the bundle editor's own-gear list follow it. At Save the service writes the row, members and bundle lists through `EquipmentSetRepository.updateSet` (one transaction today), the default flag, the geofences, and then replays the change on the dives that carry the set, all inside the sitting's transaction. The "Update past dives?" question moves to the host's `beforeSave`, asked before the transaction as the form asks it before writing.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: equipment sets", "Design: rules every phase 3 type follows", "Values shown nowhere today" (auto-apply on computer import) and "Testing"; on top of plans 1 to 4 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md), [records-3](2026-11-19-unified-editing-records-3-buddies-centres-certifications.md), [records-4](2026-11-19-unified-editing-records-4-courses.md)).

## Where plan 8 meets plans 5 and 6

Plans 5 (tracks, PR #4776) and 6 (gear item cards, branch `ericgriffin/unified-editing-phase-3-6-gear-d275f5`) are built in parallel; neither is merged as this is written.

- **The set page links to gear items** (member rows) and to other sets (the Bundle card's included sets). Those rows keep opening the other record's page, locked or unlocked; the set's sitting stays as it is underneath. Plan 6 makes the gear item page lockable on its own. No code is shared.
- **`equipment_list_page.dart`**: plan 6 changes the gear items' master-detail and table mode builders; this plan changes only `_buildSetsMasterDetail` (it gains an `editBuilder`). Separate methods, so a merge should be clean.
- **`app_router.dart`**: plan 6 changes the `/equipment/:equipmentId` routes and adds `onExit: confirmLeaveRecordSitting` to `/equipment`; this plan changes only the `sets` routes and adds `onExit` to `sets` and `sets/:setId`. The sets pane lives under `/equipment?setSelected=`, so it also needs `/equipment`'s `onExit`: whichever of the two plans merges second keeps one copy of it. Set routing code goes in a new `equipment_set_edit_routes.dart`, not plan 6's `equipment_edit_routes.dart`.
- Nothing under `lib/shared/` changes, and nothing plan 5 touches but `app_router.dart` (different routes).

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Set as default and Show figure are held changes** (a call in the note). Both are stored on the set (`is_default`, and the synced `show_figure` column), and both write at once from the menu today. **Recommended:** with the switch on, both leave the menu: Default is a switch in the header block's editor, Show diver figure a switch in the Figure card's editor, each held until Save and written in the sitting's one History entry (with the switch off the menu is unchanged). The other way: keep them as one-tap menu items, outside the lock. (Task 2.)
2. **Which card each value is edited on** (a call in the note). **Recommended:** as the note's table: the header block holds name, description, default and auto-apply on computer import (shown as a row under the description when on, decision 7); the Figure card holds show figure; Members, Bundle and Geofences hold their lists. The item count stays a calculated row inside the header. The other way: default and auto-apply move to the Members card, since both are about applying the set's gear. (Tasks 1, 2.)
3. **Which empty cards the strip offers** (the note's "a card left out when empty is offered in the strip", for sets). Today the figure is left out when it is turned off or the set has no gear, and the bundle summary when the set includes no sets, weights or cylinders; Members and Geofences always show, with an empty message. **Recommended:** the strip offers Figure while show figure is off, and Bundle while all three of its lists are empty; Members and Geofences stay on the page as today. A set with no gear and the figure on offers no Figure card (there is nothing to draw until Members has gear). The other way: Geofences is also left out when empty and offered in the strip, so the locked page loses its "No geofences" line. (Task 2.)
4. **The figure, the member rows and the count while unlocked.** **Recommended:** they follow the sitting, so ticking a member in the Members editor redraws the Figure card and the count at once, as the form's live figure does; the Members card, closed, lists the held members with its changed dot. The other way: the page keeps the stored set until Save, and only the open Members editor shows the held ticks. (Task 3.)
5. **A dive replay that fails.** Today the form saves the set first and replays its change on the dives after, so a failed replay leaves the set saved and the dives not, and a failed default write still replays (two form tests pin this). In a sitting everything is one transaction (the note's anti-goal: "a held write ... that a failed Save leaves half written"). **Recommended:** a failure anywhere fails the whole Save: nothing is written, the page stays unlocked with "Save failed", and Save can be tried again. The other way: keep the set's own writes when the replay fails, which a sitting cannot do without a second History entry. (Task 4.)
6. **One pull request.** **Recommended:** one PR (this plan is smaller than plan 4). The other way: two, the dives question and hosts after the cards. (Task 6.)

## Calls made in this plan, for Eric to check

1. **Members and geofences keep rows another device added meanwhile.** Both are unordered, so at Save the sitting's additions and removals (by id; a geofence edit by id too) are applied to the set as stored then, not the whole list written back. The bundle's three lists are ordered (a reorder is a change), so a touched list is written as the diver left it, as the form does; each list is held on its own, so an untouched one keeps its stored value even when another list of the Bundle card changed.
2. **A member deleted underneath** (another device deleted the gear) is dropped at Save by `updateSet`, as today, and is not counted as the diver's change.
3. **The Members editor is new**, built from the form's own pieces (`SetEquipmentCheckboxRow`, `foldableTypeGroupRows`, `FoldableTypeGroupsState`, `assemblyPartsAmong`, the parts switch, `unsharedSetMembers`), with no figure or number badges of its own: the Figure card above it is the live figure (Question 4). The form is not changed.
4. **Turning Default off** leaves the diver with no default set, as the form's switch does. **Turning it on** demotes the diver's other default; that other set's row is written in this sitting, so the change is in this set's History entry, and reverting it restores both. The "set as default" snackbar goes with the menu item.
5. **"Update past dives?" is asked when Save is pressed**, through the host's `beforeSave`, comparing the set as the sitting opened with the sitting's set, counting included sets (as `saveSetWithHistory` does), and only when logged dives carry it. Cancel leaves the sitting open and unsaved. Inside the transaction the replay goes by what was actually written (re-read after the writes), as the form's does.
6. **The empty Members card's "Add Equipment" button** pushes the edit form today. With the switch on it goes: locked, the lock is next to it; unlocked, the card's pencil opens the Members editor. The empty message stays.
7. **A blank name is refused after trimming.** The form refused only an empty field, so a name of spaces saved as an empty name. (Plan 6 makes the same call for gear.)
8. **Clone stays on the menu and keeps opening the form**, working locked (clone as a prefilled new set is plan 11's). **Delete** becomes a whole-record operation: it needs the unlock, keeps its question, acts at once, and is disabled while the sitting has unsaved changes. History works locked.
9. **The sets pane keeps showing the full set page with its own bar**: the page has no embedded mode and gains none. The pane's new `editBuilder` shows the page unlocked (`&mode=edit`), and its Cancel or Save returns the pane to view.
10. **The page file is split** into `part` files (its read sections and its editing), so it stays under 800 lines.

## Global Constraints

- Plans 5 and 6 are built in parallel (see "Where plan 8 meets plans 5 and 6"). Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost` (`beforeSave`, `saveAndReport`, `followStored`, `lockButton`, `editPane`), `RecordOpenUnlocked`, `EditCard`, `RecordCardFrame`, `RecordCardFade`, `RecordCardPencil`, `AddStripEntry`, `EditSession` (`set`, `valueOf`, `applyTo`, `stored`, `working`, `changedCardIds`, `remember`, `recall`), `EditField`, `FieldTextBinding`, `writeRecordSitting`, `recordOperationRunnerOf`, `recordOperationBlockOf`, `confirmLeaveRecordSitting`, `EquipmentSetCardId` with `localizedDisplayName`, and the set helpers `setHistoryRewrites`, `askSetHistory`, `SetBundleResolver`, `unsharedSetMembers`, `SetBundleListValues`, `SetGeofencesEditor`, `SetBundleSections`.
- With `kUnlockRecordEditing` false (the default) the set page, the sets pane and the set routes look and behave exactly as today: no existing test changes its expectations. The page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap. History label: `record_edit:equipment_sets:<id>:<cards>`, source "manual". Writes to other rows in the sitting (members, includes, weight presets, cylinder configurations, geofences, the demoted default set, the rewritten and unlinked dives) are in that one entry.
- Only what changed is written: the sitting's changes are applied to the set as stored at Save, with a field census test. `EquipmentSet.copyWith` can set every edited field (none is nullable), so no private `_with` is needed.
- Rules move from the form unchanged: the name is required; text is trimmed; a member deleted underneath is dropped; members no longer shared stay and are listed without a checkbox; a set cannot include itself or a set that includes it (`SetBundleSections` already enforces it); the dives question only on an existing set with logged dives carrying it. Geofence radii follow the active diver's units, as `SetGeofencesEditor` already does.
- No new strings are expected: every label comes from the form or the read page (the auto-apply row reuses `equipment_setEdit_computerAutoApplySwitch_title`). A task that finds one missing names it, and it goes into all ARB files, translated, then `flutter gen-l10n`.
- `equipment_set_detail_page.dart` (596 lines) does not grow: editing goes in `part` files. `app_router.dart` gains only references: the import of `equipment_set_edit_routes.dart`, the edit route's redirect, `openUnlocked` on the detail route and the `onExit` hooks (11 lines as built). No file passes 800.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db`.

## Review Focus

1. **Default switched on, then Cancel; then Save.** With Cancel the other set stays the default and nothing is written. With Save this set is the default, the other is not, both in one entry, and reverting the entry makes the other the default again. Pinned in Task 1.
2. **A member removed and an included set added in one sitting, on a set whose dives are logged and planned, answered "Also update".** One entry holds the set, its lists and every rewritten dive (the set's own and those of a set that includes it); reverting it restores the dives' gear. With "From now on" the logged dives are unlinked from the set and keep their gear, the planned ones follow. Pinned in Task 4.
3. **A geofence added on another device during the sitting, while the diver edits a different geofence.** Save keeps both: the diver's edit and the other device's fence. Pinned in Task 1.
4. **Locked with the switch on, no tap writes**: the menu offers no Show figure or Set as default, Delete is disabled under "Unlock to use these", and member and included-set rows only navigate. Pinned in Task 2.
5. **The dives question answered Cancel.** Nothing is written, the page stays unlocked with every change still held, and a second Save asks again. Pinned in Task 4.

## Form test accounting

The form stays until the switch-over plan, so no test is deleted here. Each edit case gets its counterpart; cases about a new set or a clone go to plan 11. The read page's menu tests keep passing with the switch off; their switch-on counterparts are listed too, as those menu items go at the switch-over.

| Test (`test/features/equipment/presentation/pages/` unless noted) | Case | Counterpart |
| --- | --- | --- |
| `equipment_set_edit_page_test.dart` | identical items are told apart (#1549) | Task 3, `the Members editor tells identical items apart` |
| | toggles default and manages geofences before saving | Task 2, `default and a geofence in one sitting save as one entry` |
| | the app bar Save is the only save action; Save offered when editing | none needed: the bar is the shared `RecordEditBar` |
| | Save validates the form first | Task 2, `a blank name cannot be saved` |
| | the figure switch starts on and saves with the set | Task 2, `the Figure editor's switch is held and written at Save` |
| | saving survives a member deleted while the form is open | Task 1, `a member deleted underneath is dropped, not re-inserted` |
| | saving an edited set keeps its lists | Task 1, census (bundle lists) |
| | a weight preset added in the form is saved | Task 2, `a weight preset added in the Bundle editor is written at Save` |
| | a new set: default with a geofence; Save without scrolling; figure on | plan 11 |
| `equipment_set_edit_assembly_parts_test.dart` | parts wait behind a switch; stay listed when ticked; stay listed once unticked | Task 3, the same three names in `equipment_set_members_editor_test.dart` |
| `equipment_set_edit_discard_test.dart` | Back after typing a name, or a switch changed, asks first | Task 2, `Cancel with changes asks first` |
| | a change put back as it was is no change | Task 2, `a name typed and put back leaves Save disabled` |
| | a member deleted meanwhile is not taken for a change | Task 3, `a member deleted underneath is not the diver's change` |
| | a saved form, or nothing changed, leaves without asking | none needed: the shared leave guard |
| | Back with nothing entered (a new set) | plan 11 |
| `equipment_set_edit_figure_test.dart` | ticked items with a row are drawn and numbered; ticking redraws at once | Task 3, `ticking a member redraws the Figure card` |
| | the summary follows the name as typed | Task 3, `the Figure card's title follows the held name` |
| | a cleared name gives the figure the new set title | Task 3, `while the held name is blank the figure keeps the stored name` |
| | the switch shows and hides the figure | Task 2, `the Figure editor's switch is held and written at Save` |
| | no ticked items means no figure | Task 3, `untick every member and the Figure card goes` |
| | names line up; lazily built list; a tap flashes a row | none needed: the editor has no badges (Call 3); the read page's figure tests cover the flash |
| `equipment_set_edit_folds_test.dart` | groups holding members start open; folding keeps the ticks | Task 3, the same two names in `equipment_set_members_editor_test.dart` |
| `equipment_set_edit_history_test.dart` | also update rewrites the logged and the planned dive | Task 4, `Also update rewrites the logged and the planned dive in the entry` |
| | from now on saves and follows on planned dives | Task 4, `From now on unlinks the logged dive and rewrites the planned one` |
| | cancel saves nothing and keeps the editor open | Task 4, `Cancel in the question saves nothing and keeps the sitting` |
| | a failed replay still saves the rest; a failed default save still replays | Task 4, `a failed replay saves nothing and leaves the page unlocked` (Question 5) |
| | a save that leaves the members alone asks nothing | Task 4, `a name change alone asks nothing` |
| `equipment_set_edit_clone_test.dart` | all cases | plan 11 |
| `equipment_set_detail_default_test.dart` | offers "Set as default" only when not default | Task 2, `with the switch on the menu has no Set as default or Show figure` |
| `equipment_set_detail_geofence_test.dart` | "Set as default" promotes the set | Task 1, Review Focus 1 |
| `equipment_set_detail_show_figure_test.dart` | the menu turns the figure on and off; toggling keeps the members | Task 2, `the Figure editor's switch is held and written at Save`; Task 1, census |
| `test/features/equipment/presentation/helpers/equipment_set_form_values_test.dart`, `equipment_set_history_save_test.dart` | helpers only the form uses (`EquipmentSetFormValues`, `saveThenReplay`) | none: deleted with the form; `unsharedSetMembers` stays with its cases |

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the set page locked at phone and desktop width, for a set with gear, the figure on, an included set and a geofence, and the sets pane on desktop.

## File Structure

New (`lib/features/equipment/...`):

| File | Responsibility |
| --- | --- |
| `data/services/equipment_set_edit_save_service.dart` | `EquipmentSetEditSaveService`, provider |
| `presentation/editing/equipment_set_edit_fields.dart` | Fields, rebase rules, `setItemsInSitting` |
| `presentation/editing/equipment_set_card_editors.dart` | Header, Figure, Bundle, Geofences editors |
| `presentation/editing/equipment_set_members_editor.dart` | Members editor |
| `presentation/editing/equipment_set_edit_cards.dart` | `equipmentSetEditCards`, `equipmentSetOptionalCards` |
| `presentation/pages/equipment_set_detail_page_editing.dart` | `part`: the page's use of the host, `beforeSave` |
| `presentation/pages/equipment_set_detail_page_sections.dart` | `part`: the read sections moved out of the page |
| `presentation/pages/equipment_set_edit_routes.dart` | Redirect, pane |

Modified: `equipment_set_detail_page.dart`, `equipment_list_page.dart` (`_buildSetsMasterDetail` only), `app_router.dart` (set routes only), `test/architecture/markdown_notes_adoption_test.dart` (the description is a new Markdown editor; not run by hand).

---

### Task 1: The set save service and fields

**Files:**
- Create: `lib/features/equipment/data/services/equipment_set_edit_save_service.dart`, `lib/features/equipment/presentation/editing/equipment_set_edit_fields.dart`
- Test: `test/features/equipment/data/services/equipment_set_edit_save_service_test.dart`, `test/features/equipment/presentation/editing/equipment_set_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - Fields, card `header`: `setNameField` (`String`, trimmed), `setDescriptionField` (`String`, trimmed), `setDefaultField` (`bool`, `isDefault`), `setAutoApplyField` (`bool`, `autoApplyOnComputerImport`); card `figure`: `setShowFigureField` (`bool`); card `members`: `setMembersField` (`Set<String>` over `equipmentIds`, set equality); card `bundle`: `setIncludedSetsField`, `setWeightPresetsField`, `setCylinderConfigsField` (each `List<String>`, ordered, a field of its own so an untouched list keeps what another device wrote; `bundleListsOf` and `setBundleLists` read and hold the three for the Bundle editor); card `geofences`: `setGeofencesField` (`List<EquipmentSetGeofence>`, compared as `EquipmentSetFormValues` compares them: id, label, latitude, longitude, radius). `equipmentSetEditFields`: all of them.
  - Rules, pure: `bool setNameValid(String name)` (non-blank after trimming, Call 7); `List<String> rebasedSetMembers({required Iterable<String> atStart, required Iterable<String> held, required Iterable<String> atSave})` (atSave plus held less atStart, less atStart less held; atSave's order, additions after); `List<EquipmentSetGeofence> rebasedGeofences({required List<EquipmentSetGeofence> atStart, required List<EquipmentSetGeofence> held, required List<EquipmentSetGeofence> atSave})` (atSave less ids the sitting removed, with the sitting's edited fences replacing theirs by id, plus the sitting's new ones; an edit to a fence deleted underneath is dropped). As built: the members and geofences fields hold their value with its base (`SetMembersEdit`, `SetGeofencesEdit`: the list as stored when the sitting first changed it, and the diver's list), and each field's `write` applies the rebase, so `session.applyTo` alone writes only the diver's change (Call 1) and the base survives the session following the stored set; `membersTicked` and `geofencesEdited` make the values.
  - `class EquipmentSetEditSaveService { EquipmentSetEditSaveService(EquipmentSetRepository sets, DiveRepository dives); Future<({EquipmentSet before, EquipmentSet after})?> save({required String setId, required EquipmentSet Function(EquipmentSet stored) apply, required Iterable<String> changedCardIds, bool alsoLogged = false}) }`: `writeRecordSitting<EquipmentSet>(table: 'equipment_sets', read: () => getSetById(setId, includeGeofences: true), ...)`; its `write(stored, merged)` runs, in order: `updateSet(merged)` (row, members, bundle lists); `setAsDefault(id)` or `clearDefault(id)` when `isDefault` changed; the geofences' difference from `stored` (`removeGeofence`, `updateGeofence`, `addGeofence` with `setId`); then the replay: every set of the owner (`getAllSets(diverId: stored.diverId)`, with `stored` for this one), the set re-read, `setHistoryRewrites(before: stored, after: reread, allSets:)`, and per change `rewriteSetOnDives(change.setId, change.rewrites, alsoLogged:, notify: false)`, then `unlinkSetFromLoggedDives(change.setId)` unless `alsoLogged`. `equipmentSetEditSaveServiceProvider`.
- Consumes: `writeRecordSitting`, `setHistoryRewrites`.

- [ ] **Step 1: Write the failing tests** (test database; diver `d1`; set `s1` "Cold water" with drysuit `e1` and regulator `e2`, geofence `g1`, including set `s0` (fins `e3`), not default; set `s2` default; set `s3` includes `s1`; a logged dive and a planned dive carrying `s1`, a logged dive carrying `s3`):
  - Service: `writes a name change as one History entry` (label `record_edit:equipment_sets:s1:header`); census `a field the sitting did not touch keeps its newer value`, one assertion per value (name, description, auto-apply, show figure, default, members, each bundle list, geofences); `default on demotes s2 in the same entry, and reverting restores s2` (Review Focus 1); `default off leaves no default`; `a member deleted underneath is dropped, not re-inserted`; `removing e2 rewrites the planned dive and unlinks the logged ones from s1 and s3` (`alsoLogged` false); `with alsoLogged the logged dives of s1 and s3 lose e2 too, in the entry, and reverting restores them`; `a failure in the replay writes nothing, the set included` (Question 5; a dive repository fake that throws); `unchanged returns null`; `a set that has gone throws`.
  - Fields: `rebasedSetMembers keeps a member added underneath`; `it applies only the sitting's additions and removals`; `rebasedGeofences keeps a fence added underneath while another is edited` (Review Focus 3); `an edit to a fence deleted underneath is dropped`; `members untouched stay as stored`; `the base survives the stored set changing underneath`; `a name of spaces is invalid`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): save an equipment set's editing sitting as one History entry`.

### Task 2: The set page on the host, with its header, figure, bundle and geofence editors

**Files:**
- Create: `equipment_set_card_editors.dart`, `equipment_set_edit_cards.dart`, `equipment_set_detail_page_editing.dart` (part), `equipment_set_detail_page_sections.dart` (part)
- Modify: `equipment_set_detail_page.dart`, `test/architecture/markdown_notes_adoption_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_page_unlock_harness.dart`, `equipment_set_detail_page_unlock_test.dart`, `test/features/equipment/presentation/editing/equipment_set_card_editors_test.dart`

**Interfaces:**
- Produces:
  - `EquipmentSetHeaderEditor({required EditSession<EquipmentSet> session})`: name (`equipment_setEdit_nameLabel`, required, its error while blank), description (`MarkdownNotesField`, `equipment_setEdit_descriptionLabel`), the Default switch and the auto-apply switch with the form's titles and subtitles; the item count read only from the working set (Question 4).
  - `EquipmentSetFigureEditor({required EditSession<EquipmentSet> session})`: the Show diver figure switch with the form's title and subtitle.
  - `EquipmentSetBundleEditor({required EditSession<EquipmentSet> session})`: `SetBundleSections(setId:, diverId:, ownGearIds: <working members>, values:, onChanged:)` over the three bundle list fields (`bundleListsOf`, `setBundleLists`).
  - `EquipmentSetGeofencesEditor({required EditSession<EquipmentSet> session})`: `SetGeofencesEditor(fences:, setId:, onChanged:)` over `setGeofencesField`.
  - `equipmentSetEditCards` (`Map<EquipmentSetCardId, EditCard<EquipmentSet>>`): `header` (`isEmpty` false, `isValid`: `setNameValid`), `figure` (`isEmpty`: show figure off), `members` (`isEmpty` false; Task 3's editor), `bundle` (`isEmpty`: all three lists empty), `geofences` (`isEmpty` false). `equipmentSetOptionalCards`: figure, bundle (Question 3).
  - `class EquipmentSetDetailPage extends ConsumerStatefulWidget { const EquipmentSetDetailPage({required String setId, bool unlockEditing = kUnlockRecordEditing, bool openUnlocked = false, VoidCallback? onSittingEnded}) }` on `RecordEditHost<EquipmentSetDetailPage, EquipmentSet>` and `RecordOpenUnlocked`; `followStored(equipmentSetProvider(id))`; `editingTitle`: `recordEdit_editingTitle(set.name)`; `rereadStored` invalidates `equipmentSetProvider`; `saveSitting` calls Task 1's service with `apply: session.applyTo` and Task 4's answer, and refreshes the set lists after the commit without holding the Save. The bar takes `host.lockButton`. With the switch on: Show/Hide figure and Set as default leave the menu (Question 1); the header shows the auto-apply row (`equipment_setEdit_computerAutoApplySwitch_title`) when it is on; the empty Members card's Add Equipment button goes (Call 6); the read sections move into the sections part; each section is framed by `RecordCardFrame` with its pencil, the header block's count is the calculated row inside it.
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests**:
  - Editors: `each editor sets only its card's fields`; `the Default and auto-apply switches are held`; `the Bundle editor offers no set that includes this one`.
  - Page: `with the switch off there is no lock and the menu is unchanged`; `locked, no tap writes` (Review Focus 4: menu has no Show figure or Set as default, Delete disabled under "Unlock to use these", rows only navigate, a recording repository fake records nothing); `with the switch on the menu has no Set as default or Show figure`; `name and description in one sitting save as one entry and lock`; `default and a geofence in one sitting save as one entry`; `a blank name cannot be saved`; `the Figure editor's switch is held and written at Save`; `a weight preset added in the Bundle editor is written at Save`; `auto-apply on shows its row in the header`; `Figure is offered in the strip while the figure is off, Bundle while its lists are empty` (Question 3); `Members and Geofences show while empty`; `the empty Members card has no Add Equipment button with the switch on`; `Cancel with changes asks first`; `a name typed and put back leaves Save disabled`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement; add the description editor to the Markdown guard's list.
- [ ] **Step 4:** Run them, and unchanged `equipment_set_detail_clone_test.dart`, `equipment_set_detail_default_test.dart`, `equipment_set_detail_figure_test.dart`, `equipment_set_detail_geofence_test.dart`, `equipment_set_detail_labels_test.dart`, `equipment_set_detail_show_figure_test.dart`, `equipment_set_detail_unshared_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): unlock an equipment set page to edit it in place, behind a switch`.

### Task 3: Members held, with the figure and count following the sitting

**Files:**
- Create: `lib/features/equipment/presentation/editing/equipment_set_members_editor.dart`
- Modify: `equipment_set_edit_fields.dart`, `equipment_set_edit_cards.dart`, `equipment_set_detail_page_sections.dart`
- Test: `test/features/equipment/presentation/editing/equipment_set_members_editor_test.dart`, `equipment_set_edit_fields_test.dart`, `equipment_set_detail_page_unlock_test.dart`

**Interfaces:**
- Produces:
  - `List<EquipmentItem> setItemsInSitting(EquipmentSet working, {required List<EquipmentItem> storedItems, required List<EquipmentItem> everyItem, required List<EquipmentSet> allSets})`: the working set's effective gear (`SetBundleResolver.effectiveGearIds` over `allSets` with `working` in place of the stored set), each id mapped to `everyItem` first, then `storedItems` (a member no longer shared), ids found in neither left out.
  - `EquipmentSetMembersEditor({required EditSession<EquipmentSet> session})` (`ConsumerStatefulWidget` with `FoldableTypeGroupsState`): the active gear arranged and labelled as the form's picker, rows `SetEquipmentCheckboxRow` with no number or badge slot, the parts switch (`set-edit-show-assembly-parts`) with touched rows kept listed, members no longer shared listed without a checkbox; a tick sets `setMembersField` (Call 3).
  - The page's Members rows, Figure card and header count draw `setItemsInSitting(session.working, ...)` while a sitting is open, and the stored items otherwise (Question 4); the figure's title is the held name, or the stored one while the held name is blank.
- Consumes: Tasks 1 and 2.

- [ ] **Step 1: Write the failing tests**:
  - Fields: `setItemsInSitting includes an included set's gear`; `it keeps a member no longer shared from the stored items`; `it follows an included set added in the sitting`.
  - Editor: `the Members editor tells identical items apart`; `wait behind a switch`; `stay listed when ticked, so they can be unticked`; `stay listed once unticked, so the untick can be undone`; `groups holding members start open, others closed`; `folding keeps the ticks and says so`; `a member no longer shared is listed without a checkbox and kept`; `a member deleted underneath is not the diver's change`.
  - Page: `ticking a member redraws the Figure card and the count`; `the closed Members card lists the held members with its dot`; `the Figure card's title follows the held name`; `while the held name is blank the figure keeps the stored name`; `untick every member and the Figure card goes`; `a member row opens the gear item, and the sitting stays open on return`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_set_edit_assembly_parts_test.dart`, `equipment_set_edit_folds_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a set's members chosen on its page wait for Save`.

### Task 4: "Update past dives?" at Save

**Files:**
- Modify: `equipment_set_detail_page_editing.dart`
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_page_history_test.dart` (create; the form history test's dive setup)

**Interfaces:**
- Produces: `beforeSave` on the page: when the sitting's set differs from the set it opened on in effective gear (`setHistoryRewrites(before: session.stored, after: session.working, allSets: <equipmentSetsProvider, else [stored]>)` non-empty), asks `askSetHistory(context, ref, setId:, alsoSetIds: <the other sets in the changes>)`; null (Cancel) returns false; the answer is kept on the session (`session.remember('set.alsoLogged', ...)`) and `saveSitting` passes `alsoLogged` to Task 1's service. No changes in effective gear asks nothing and passes false (Call 5).
- Consumes: Tasks 1 to 3.

- [ ] **Step 1: Write the failing tests** (a logged and a planned dive carrying the set, a logged dive carrying a set that includes it): `Also update rewrites the logged and the planned dive in the entry` (Review Focus 2); `From now on unlinks the logged dive and rewrites the planned one`; `an included set added in the sitting asks, counting the outer set's dives`; `Cancel in the question saves nothing and keeps the sitting` (Review Focus 5; a second Save asks again); `a name change alone asks nothing`; `no logged dive carries it: nothing is asked and the planned dive follows`; `a failed replay saves nothing and leaves the page unlocked` (Question 5; "Save failed" shown).
- [ ] **Step 2:** Run it. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it, and unchanged `equipment_set_edit_history_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): a set's dives question is asked when its sitting is saved`.

### Task 5: Set routes, the sets pane and Delete

**Files:**
- Create: `lib/features/equipment/presentation/pages/equipment_set_edit_routes.dart`
- Modify: `equipment_set_detail_page.dart`, `equipment_set_detail_page_editing.dart`, `equipment_list_page.dart` (`_buildSetsMasterDetail` only), `app_router.dart` (set routes only)
- Test: `equipment_set_detail_page_unlock_test.dart`, `test/features/equipment/presentation/pages/equipment_list_page_sets_pane_test.dart` (create), `test/core/router/app_router_test.dart`

**Interfaces:**
- Produces: `String? equipmentSetEditLocation(String setId, {bool unlockEditing = kUnlockRecordEditing})` (`/equipment/sets/<id>?mode=edit`, else null); `String? equipmentSetEditRedirect(BuildContext, GoRouterState)` (on `sets/:setId/edit`); `Widget? equipmentSetEditPane(BuildContext, String id, void Function(String) onSaved, VoidCallback onCancel, {bool unlockEditing = kUnlockRecordEditing})` (the page unlocked with `onSittingEnded: onCancel` with the switch on; null otherwise, so the sets pane keeps having no `editBuilder` with the switch off). `_buildSetsMasterDetail` passes `editBuilder` only when the switch is on; `createBuilder` and `/equipment/sets/new` stay the form. The detail route passes `openUnlocked` from `?mode=edit`; `sets` and `sets/:setId` get `onExit: confirmLeaveRecordSitting`, and `/equipment` too unless plan 6 has merged it. Delete runs through `recordOperationRunnerOf`, then goes to `/equipment` as today; Clone and History work locked (Call 8).
- Consumes: Tasks 2 to 4.

- [ ] **Step 1: Write the failing tests**: `opened with mode=edit, the page is unlocked`; `the sets pane's edit opens the page unlocked, Cancel returns to view`; `the pane's Save updates the set and returns to view`; `the edit address redirects with the switch on, not off`; `locked, Delete is disabled under "Unlock to use these"`; `unlocked and clean, Delete asks and deletes`; `Clone works locked and opens the form`; `with the switch off the pane has no edit mode and Edit pushes the form`; `leaving the sets pane with changes asks first`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and unchanged `equipment_set_detail_clone_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(equipment): set edit addresses and the sets pane open the page unlocked; delete as a whole-record operation`.

### Task 6: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more (plans 5 and 6 may have landed: resolve `app_router.dart` and `equipment_list_page.dart` by keeping both sides, one `/equipment` `onExit`); whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first, shared code included; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the page locked (before and after) and unlocked, with the header editor open (Default and auto-apply), the Members editor with a held tick and the redrawn figure, the Bundle and Geofences editors, the strip offering Figure, and the dives question; light and dark for the unlocked bar; phone and desktop for the sets pane. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): equipment sets edit in place, behind a switch`, body with `Refs #4527` and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.
