# Unified Editing, Plan 11: The Switch-Over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn unlock-to-edit on for every build and make it the only way to edit one dive: the build switch goes, the Edit buttons go, the old addresses open the dive page unlocked, the single-dive edit form is deleted, and bulk edit keeps working exactly as today from a page of its own. This ends phase 1 of issue #4527 and closes #1906 and #1570.

**Architecture:** Bulk edit is moved out of `DiveEditPage` first, into `BulkDiveEditPage`'s own state, so the single-dive form can be deleted without touching it. Then `kUnlockEditing` is deleted and each of its readers keeps the branch it took with the switch on; the `unlockEditing` parameters that only carried the switch go with it. `/dives/:id/edit` redirects to `/dives/:id?mode=edit`, and both that and the list pane's `&mode=edit` build the dive page with `openUnlocked: true`. The paths plan 7 kept for a page without the lock (`operations == null`, the optional `operationReason`, the dive page's `offerUndo`) become required inputs. Last, `dive_edit_page.dart`, its parts, the files only it used, and its tests are deleted.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router 17, drift (SQLite), `flutter gen-l10n`.

**Spec:** `docs/design/specs/2026-11-14-unified-editing-pattern-design.md`. Read "What happens to the edit page", "What a locked dive page no longer shows" and "Delivery". The names used here are the ones plans 1 to 10 built: read "For plan 11", "For plans 8 and 11", "For plans 7, 9 and 11" and "After the review" in each `docs/design/plans/2026-11-1*-unified-editing-*.md`. Plan 8's PR is #4672; the left-open items were cleared in #4670.

## What turning the switch on changes

Each reader of `kUnlockEditing` (`lib/shared/widgets/record_editing/unlock_editing_flag.dart`) keeps the value it has with the switch on:

| Reader | With the switch on, always |
| --- | --- |
| `DiveDetailPage.unlockEditing` and `_DiveDetailPageEditing.editingOffered` | The page offers the lock; every `!editingOffered` branch in `dive_detail_page*.dart` is deleted |
| `newDivePaneBuilder`, `newDiveRoutePage` (`dive_create_builder.dart`) | A new dive is `DiveDetailPage.newDive`; the `DiveEditPage` branches go |
| `MediaViewerPage`, `SiteMediaViewerPage`, `PhotoViewerPage` `.unlockEditing`; `DiveMediaSection`'s `unlockEditing:` | The viewers have their own lock; `photoLocked` is `!photoUnlocked`, `colorLockOffered` is true, `editingOffered` keeps only its capability test |
| `media_viewer_actions.dart:88` (`if (unlockEditingRequested) return;`) | Always returns: the code after it is deleted |
| `MediaLibraryGrid`, `MediaStatusBadge` info sheet `readOnly: kUnlockEditing` | `readOnly: true`: the info sheet outside the viewer reads only |
| `RecentDiveProfilePreview` fullscreen `readOnly: kUnlockEditing` | `readOnly: true`: the dashboard has no lock |
| `DiveLabPage.linkOffered` | No Link plan / Unlink plan in its menu; the Compare card holds the link |
| `importDroppedMedia(lockable:)`, `diveDropAnswer(lockable:)` | A drop on a dive goes through its open sitting or is refused with the hint |
| `RecordEditShortcuts.listInHelp` | Unlock and Save are always listed in the shortcuts help |

## Calls made in this plan, for Eric to check

Eric's standing choices apply: a locked record allows no change; one Save per unlock; no release has two ways to edit a dive. Where a case could go either way the stricter, uniform option is written first.

**Confirmed by Eric on 2026-11-17 while the plan was written:** call 3 (the outlier entry beside Edit profile) and call 4 (locked notes read only).

1. **`/dives/:id/edit` stays an address and redirects to `/dives/:id?mode=edit`.** The dive page reads `mode=edit` and opens unlocked once the dive has loaded, once per page: Save or Cancel locks it as usual, and a rebuild does not unlock it again. A dive that cannot be read shows the page's usual not-found state, locked. The other way: keep `/dives/:id/edit` as its own page on top of `/dives/:id`, which a deep link would stack over a second copy of the same dive.
2. **The list pane's `&mode=edit` shows the dive page unlocked inside the pane's edit mode**, as a new dive's `?mode=new` does (plan 8): the add button hides and Tab stays in the pane while the sitting lasts; when the sitting ends (Save, Cancel, a lock) the pane returns to `?selected=<id>`, locked. Table mode's pane does the same. `&mode=edit&site=<id>` still opens the site's edit form (phase 2).
3. **The outlier entry sits beside Edit profile on the Profile card** (Eric's choice). It is a warning icon with the count as a badge (`Icons.warning_amber` in a `Badge`), its tooltip the form's `diveLog_edit_profile_outliers` ("N outliers"), so no new string. It is the same whole-record operation as Edit profile, opening the editor in Outlier mode: shown whenever outliers are found, disabled while locked ("Unlock to use this") and while the sitting has changes ("Save or cancel your changes first"). The other way: the form's `ActionChip`, which is taller than the row of icon buttons it would join.
4. **On a locked page the SAC volume hint and the altitude mismatch note read only** (Eric's choice, as the spec says): no tap, and the note loses its edit icon. Unlocked they already open the Tanks and Altitude cards.
5. **The trip cylinder sheet's unlinked tank still pushes `/dives/<id>/edit`**, which now opens that dive's page unlocked (call 1), so linking the tank is one tap away as today.
6. **The data quality inbox keeps Remove source's Undo.** It has no lock, so `removeSourceWithUndo(offerUndo:)` keeps its parameter and its default for the inbox; only the dive page's `offerUndo: !editingOffered` goes (the page always passes `false`: History reverts it).
7. **Bulk edit moves, unchanged**, to `BulkDiveEditPage`'s own state and part files: same scaffold, same rows, same save. That includes the weighting feedback row its Weights editor shows but `_saveBulk` never sends (today's behaviour, left as is and noted for a follow-up).
8. **Strings only the deleted code used are removed** from all 11 ARB files. A key is removed only if lib/ referenced it before the deletion and references it no more, so keys that were already unused are left alone.
9. **The cards' and viewers' `sitting == null` / `scope == null` branches stay in this PR.** Plan 10 asked for the viewer ones to go "only where nothing else calls them"; deciding that needs each widget's other callers (the media library, the dive lab, the site page) traced one by one, and the dive page always has a scope now, so the branches are dead there but harmless. A follow-up issue lists them. The other way: a ninth task here that traces and removes them.

## Not in this plan

- Phases 2 to 4 (sites and the other record types); `&mode=edit&site=` keeps the site's form.
- The `sitting == null` branches (call 9) and bulk's unsent weighting feedback (call 7): follow-up issues.
- Plan 2 to 4's left-open minors in the shared notes' leftovers audit.

## Global Constraints

- Bulk edit (`/dives/bulk-edit`, the list's selection bar) builds and saves exactly as today: same rows, same gates, same summary, same snackbar, same return.
- Every single-dive edit is a sitting: one Save, one transaction, one change log operation, as plans 1 to 9 built.
- No file over 800 lines. `dive_detail_page.dart` is at 723, `dive_detail_page_editing.dart` at 484, `dive_detail_profile_section.dart` at 557: new page code goes in part files. `dive_list_page.dart` (1,258) and `app_router.dart` (2,720) are already over and must not grow.
- Anything that acts after an `await` checks `mounted`, and reads `ref` and `context` before its first `await`.
- Every value shown or typed follows the active diver's units.
- Every new string goes in all 11 ARB files with a real translation, then `flutter gen-l10n`. This plan expects none (call 3).
- Test runs: only the test files a task writes or changes, by path, at most 15 per run. Never a folder and never the whole suite; the pre-push hook runs format, the whole-repo analyze, the guards and the affected tests (Task 9).
- No em-dash characters anywhere; no emojis; no mention of any AI tool in code, commits or pull requests.

## Review Focus

1. **An old bookmark to a deleted dive** (`/dives/<gone>/edit`): the redirect lands on the dive page, which shows not found, stays locked, and throws nothing. Test in Task 5.
2. **A page opened unlocked, saved, then rebuilt** (a resize, a sync landing): it stays locked; `mode=edit` is read once per page. Test in Task 5.
3. **`mode=edit` arriving on a dive page already showing that dive locked** (the same route, a `go` with the query): it unlocks then, as `openUnlocked` changes. Test in Task 5.
4. **A profile too short or still loading**: no outlier button, and no flicker of a disabled one. Test in Task 2.
5. **A browser, which cannot unlock a photo**: the viewer reads only, with no write control, now that the switch no longer decides. Pinned by `media_viewer_browser_lock_test.dart`, run in Task 4 after its `unlockEditing` arguments go.

## Preparation

- Worktree: `git submodule update --init --recursive`, `flutter pub get`, branch from `origin/main` (contains #4672 and #4670).
- Before any code changes, take the "before" pictures from a `main` build by the macOS window route (`project_macos_background_screenshots_window_resize` in memory; read it first, use a `SUBMERSION_DB_PATH` copy): the dive page at desktop and phone width with its Edit button, the list pane's header with its Edit button, and the form the Edit button opens.

## File Structure

| File | Change |
| --- | --- |
| `lib/features/dive_log/presentation/pages/bulk_dive_edit_page.dart` | Becomes the bulk page: widget, fields, `initState`, `dispose`, `build` |
| `bulk_dive_edit_page_form.dart`, `_collections.dart`, `_rows.dart`, `_save.dart` (same folder, `part of`) | The moved bulk code, grouped as Task 1 says, each under 800 lines |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` and its four `dive_edit_page_*.dart` parts | Bulk removed (Task 1), then deleted (Task 7) |
| `lib/shared/widgets/record_editing/unlock_editing_flag.dart` | Deleted (Task 3) |
| `lib/features/dive_log/presentation/pages/dive_detail_page*.dart` | `unlockEditing` and `editingOffered` go; `openUnlocked`, `onSittingEnded` arrive; Edit button goes; outlier operation |
| `lib/features/dive_log/presentation/pages/dive_detail_page_unlock_open.dart` (new part) | Opening unlocked and telling the pane the sitting ended |
| `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart` | `onEditOutliers`, `_OutliersButton` |
| `lib/core/router/app_router.dart`, `lib/features/dive_log/presentation/pages/dive_list_page.dart` | The `edit` redirect; the panes' `editBuilder`s |
| The media viewers, `dive_lab_page.dart`, `media_drop_import.dart`, `open_dive_sitting_provider.dart`, `record_edit_shortcuts.dart`, `recent_dive_profile_preview.dart`, `media_library_grid.dart`, `media_status_badge.dart`, `dive_media_section.dart` | The switch's readers (Tasks 3 and 4) |
| `dive_detail_overflow_menu.dart`, the banners, `data_sources_section.dart`, `source_bar.dart`, `tank_gear_menu.dart`, `observation_status_chip.dart`, `dive_detail_page_actions.dart` | Switch-off paths (Task 6) |

---

### Task 1: Bulk edit gets a page of its own

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/bulk_dive_edit_page.dart`
- Create: `lib/features/dive_log/presentation/pages/bulk_dive_edit_page_form.dart`, `bulk_dive_edit_page_collections.dart`, `bulk_dive_edit_page_rows.dart`, `bulk_dive_edit_page_save.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (bulk removed)
- Test: `bulk_dive_edit_form_test.dart`, `bulk_dive_edit_page_test.dart`, `bulk_dive_edit_site_test.dart`, `bulk_edit_return_test.dart`, `bulk_edit_snackbar_test.dart`, `bulk_gear_arrangement_test.dart`, `bulk_membership_wiring_test.dart` (all in `test/features/dive_log/presentation/pages/`); `dive_edit_site_picker_area_test.dart` renamed `bulk_dive_edit_site_picker_area_test.dart`; the bulk cases of `dive_edit_new_trip_prefill_test.dart` (L157) and `dive_edit_route_links_test.dart` (L318) moved into `bulk_dive_edit_form_test.dart`; `test/architecture/markdown_notes_adoption_test.dart`

**Interfaces:**
- Produces: `BulkDiveEditPage({Key? key, required List<String> diveIds, bool popOnSave = false, bool embedded = false, void Function(String)? onSaved, VoidCallback? onCancel})`, a `ConsumerStatefulWidget` whose `_BulkDiveEditPageState` holds every member the mapping below calls bulk-only or shared. `DiveEditPage` loses `bulkDiveIds`, `bulkPopOnSave` and `isBulk`.

What moves (line numbers in `dive_edit_page.dart` at `d877c0a6faa`):
- Bulk-only: the block L1460 to L2885 (`_buildBulkScaffold` to the end of `_saveBulk`), L4870 to L5306 (`_loadBulkMembers` to `_rolesForBuddy`), `_showTagPickerFor` (L3787), `_bulkExcludedFromStats`, `_bulkExcludedFromGasStats`, `_bulkNumberControllers`, and the bulk fields L1479 to L1565.
- Copied (still used by the single form until Task 7), with each `isBulk` branch reduced to its bulk side: `_loadDefaultPreset`, `_markDirty`, `_showDiveCenterPicker`, `_showTripPicker`, `_setTrip`, `_newTripFacts`, `_areaAnchor`, `_openingSitePicker`, `_visibilityInput`, `_visibilityMetersInput`, `_visibilityScale`, `_rememberVisibilityMode`, `_addTank`, `_removeTank`, `_weightChild` with `_applyWeightPreset`, `_saveWeightsAsPreset`, `_replaceWeight` and `_gearRows`, `_sightingsChild`, the sentinels, `_savedNumber`, the `double?.map` extension, and the fields and controllers bulk reads. `_suggestTripCylinders` returns at once in bulk, so the copy of `_setTrip` drops the call; `_dropGasSwitchesWithoutTank` is a no-op in bulk, so `_removeTank`'s copy drops it.
- Parts: `_form` holds the scaffold, `_gatedRow`, `_buildBulkForm` and the section builders; `_collections` the collections section, member loaders and `_bulkAdd*`; `_rows` the copied shared rows and pickers; `_save` `_collectScalarInputs`, `_collectCollectionOps`, `_saveBulk`.

- [ ] **Step 1: Point the bulk tests at the new page.** Replace every `DiveEditPage(bulkDiveIds: ids, ...)` with `BulkDiveEditPage(diveIds: ids, ...)` (`bulkPopOnSave:` becomes `popOnSave:`). Rename the site picker area test; move the two bulk cases into `bulk_dive_edit_form_test.dart` with their helpers. In `markdown_notes_adoption_test.dart`, point the "bulk notes field" entry at the part that builds the bulk notes `MarkdownNotesField` (`bulk_dive_edit_page_form.dart`).

- [ ] **Step 2: Run them to see them fail.** Run: `flutter test` with the nine bulk test files and the adoption test, by path. Expected: compile errors (`embedded`, `onSaved`, `onCancel` not defined on `BulkDiveEditPage`).

- [ ] **Step 3: Move the code** as listed above. `build` keeps today's `_isLoading` check order and returns the bulk scaffold. Remove the bulk members and the `isBulk` branches from `dive_edit_page.dart`, keeping their single-dive side; `DiveEditPage`'s assert on `diveId`/`bulkDiveIds` goes.

- [ ] **Step 4: Run the same files.** Expected: all pass, with no test changed beyond Step 1. Then `flutter analyze` on the touched lib files: no issues.

- [ ] **Step 5: Commit** `refactor(dive-log): give bulk edit a page of its own, ahead of the edit form's removal`.

### Task 2: Outliers beside Edit profile

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_operations.dart`, `dive_detail_page.dart` (the wiring at L442 and wherever `onEditProfile` is passed: the card and the pinned copy)
- Modify: `lib/features/dive_log/presentation/providers/outlier_suggestion_provider.dart` (doc comment only: "Used by the Profile card's outliers button")
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_outliers_test.dart` (new)

**Interfaces:**
- Consumes: `outlierSuggestionProvider(String diveId)`; `openProfileEditor(context, ref, diveId, {String? initialMode})` returning `ProfileEditorResult`; `recordOperationReason`, `recordOperationBlockOf`.
- Produces: `DiveDetailProfileSection` gains `VoidCallback? onEditOutliers` (passed through the same constructors as `onEditProfile`); `_OutliersButton({required String diveId, required RecordEditController<Dive>? scope, required VoidCallback onPressed})`, a `ConsumerWidget` placed right after `_EditProfileButton`; the page's `Future<bool> _editOutliers()` in the operations part.

- [ ] **Step 1: Write the failing tests.** Mirror `dive_detail_page_unlock_edit_profile_test.dart`'s setup (its stored dive, its `editProfile` route capturing the pushed uri). The stored dive has a 20-point profile with one spike (for example 10 m throughout and 45 m at index 10); `setUp` asserts `ProfileEditingService().detectOutliers(profile)` is not empty, so the fixture cannot pass vacuously.
  - `locked, the outliers button is shown and disabled`: tooltip `Unlock to use this`, `onPressed` null, badge text `1`.
  - `unlocked with nothing changed, it opens the editor in Outlier mode`: tap; the captured uri's `mode` query is `outlier`.
  - `with unsaved changes it is disabled`: type in Notes; tooltip `Save or cancel your changes first`.
  - `a profile of nine points shows no outliers button`.
  - `while the outliers are being found nothing is shown`: the provider overridden with a never-completing future; no button, no disabled placeholder.

- [ ] **Step 2: Run** the new file. Expected: FAIL, no outliers button found.

- [ ] **Step 3: Implement.** `_OutliersButton` watches `outlierSuggestionProvider(diveId)` in its own build (so the section does not rebuild with it), returns `SizedBox.shrink()` for loading, error and an empty list, else an `IconButton(icon: Badge(label: Text('${outliers.length}'), child: Icon(Icons.warning_amber)), tooltip: reason ?? l10n.diveLog_edit_profile_outliers(outliers.length), onPressed: reason == null ? onPressed : null, visualDensity: VisualDensity.compact)`, the reason computed as `_EditProfileButton` does. `_editOutliers` is `(await openProfileEditor(context, ref, diveId, initialMode: 'outlier')).saved`; the page passes `onEditOutliers: () => _runOperation(_editOutliers)` everywhere it passes `onEditProfile`.

- [ ] **Step 4: Run** the new file and `dive_detail_page_unlock_edit_profile_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(dive-log): find a profile's outliers from the Profile card, beside Edit profile`.

### Task 3: The switch on: the dive page and a new dive

**Files:**
- Delete: `lib/shared/widgets/record_editing/unlock_editing_flag.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `dive_detail_page_bars.dart`, `dive_detail_page_editing.dart`, `dive_detail_page_creating.dart`, `dive_detail_page_operations.dart`, `dive_detail_page_actions.dart`, `dive_create_builder.dart`
- Modify: `lib/shared/widgets/record_editing/record_edit_shortcuts.dart`, `lib/features/media/presentation/helpers/media_drop_import.dart`, `lib/features/dive_log/presentation/providers/open_dive_sitting_provider.dart`
- Test: `test/shared/widgets/record_editing/record_edit_controller_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart`, the dive page tests that pass `unlockEditing` (`dive_detail_page_unlock_operations_test`, `_unlock_edit_profile_test`, `_unlock_menu_test`, `_unlock_test`, `_unlock_annotation_link_test`, `_unlock_header_block_test`, `_unlock_pane_test`, `_unlock_gear_cards_test`, and every other file `grep -l "unlockEditing" test/features/dive_log` lists), `test/core/router/new_dive_route_test.dart`, `test/features/dive_log/presentation/pages/dive_list_page_test.dart` (L1071), `test/shared/widgets/record_editing/record_edit_shortcuts_test.dart`, `test/features/media/presentation/helpers/media_drop_import_test.dart`, `test/features/dive_log/presentation/providers/open_dive_sitting_provider_test.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_switch_on_test.dart` (new)

**Interfaces:**
- Produces: `DiveDetailPage({Key? key, required String diveId, bool embedded = false, String? embeddedSiteId, VoidCallback? onCloseEmbeddedSite, VoidCallback? onDeleted})` (no `unlockEditing`); `newDivePaneBuilder()` and `newDiveRoutePage({DivePrefill? prefill, String? tripId, String? tripCylinderId})` (no `unlockEditing`); `RecordEditShortcuts({Key? key, required Widget child})`; `importDroppedMedia(context, ref, destination, paths)`; `diveDropAnswer({required OpenDiveSitting? open, required String diveId})`, its `asToday` value deleted if nothing else returns it. The harness's `pumpPage` loses `unlockEditing`.

- [ ] **Step 1: Write the failing test** `dive_detail_page_switch_on_test.dart`: `a dive page built with only its id offers the lock`: pump `DiveDetailPage(diveId: dive.id)` through `pumpPage`'s overrides; the lock button (the finder `dive_detail_page_unlock_test.dart` uses) is present and the bar has no favourite toggle. And `the new dive route always opens the dive page`: `newDiveRoutePage()` is a `DiveDetailPage` whose `newDiveRequest` is not null.

- [ ] **Step 2: Run** it. Expected: FAIL (no lock button; the route page is a `DiveEditPage`).

- [ ] **Step 3: Delete the switch and its dive page readers.** Remove `unlockEditing` from `DiveDetailPage` and its `.newDive`, delete `editingOffered` and every `!editingOffered` branch in the parts named above (each `if (editingOffered)` keeps its body), the `DiveEditPage` branches of `dive_create_builder.dart`, `listInHelp` (always listing), and `lockable`. Delete the flag file and its import everywhere.

- [ ] **Step 4: Fix the tests the change touches.** Drop every `unlockEditing: true` argument. A test case that passes `unlockEditing: false` pinned the switch-off page: delete it when an `_unlock_` test pins the same control with the lock, otherwise rewrite it to unlock first (`unlock(tester)`). Delete `record_edit_controller_test.dart`'s `kUnlockEditing` expectation, `new_dive_route_test.dart`'s two old-form cases, and the `listInHelp: false` and `lockable: false` cases. `dive_list_page_test.dart`'s create pane expects `DiveDetailPage`.

- [ ] **Step 5: Run** the new file and each test file this task changed, by path, at most 15 per run. Expected: PASS. Then `flutter analyze`: no issues.

- [ ] **Step 6: Commit** `feat(dive-log): turn unlock-to-edit on for the dive page and a new dive`.

### Task 4: The switch on: the photo viewers and the read-only views

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart`, `site_media_viewer_page.dart`, `photo_viewer_page.dart`, `media_viewer_actions.dart`, `lib/features/media/presentation/editing/photo_viewer_editing.dart`, `lib/features/media/presentation/widgets/dive_media_section.dart`, `media_library_grid.dart`, `media_status_badge.dart`
- Modify: `lib/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart`, `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`
- Test: every test file `grep -l "unlockEditing" test/features/media` lists (among them `media_viewer_unlock_test`, `media_viewer_unlock_harness`, `site_media_viewer_unlock_test`, `media_viewer_browser_lock_test`, `dive_media_section_test`); `dive_lab_page_test.dart` and any `dive_lab_page_*_test.dart` that opens Link plan or Unlink plan; `recent_dive_profile_preview_test.dart`; `media_library_grid_test.dart`; `media_status_badge_test.dart`

**Interfaces:**
- Produces: the three viewers without `unlockEditing`; `PhotoViewerEditing` without `unlockEditingRequested` (`editingOffered` keeps its capability and stored-row tests; `photoLocked => !photoUnlocked`); `colorLockOffered => true` in both viewers; `DiveLabPage({Key? key, required String diveId, String? scenarioId})`.

- [ ] **Step 1: Write the failing tests.** In `media_viewer_unlock_test.dart`: `a viewer built with no switch argument opens locked`: `MediaViewerPage` built with only its required arguments shows Unlock and no write control (the finders the file already uses). The same in `site_media_viewer_unlock_test.dart`. In `dive_lab_page_test.dart`: `the menu offers no plan link`: no Link plan or Unlink plan item.

- [ ] **Step 2: Run** those three files. Expected: FAIL.

- [ ] **Step 3: Implement** the table under "What turning the switch on changes" for these readers: delete the parameters and getters, the code after `media_viewer_actions.dart:88`'s return, the dive lab menu's link items and whatever only they used (`linkOffered` at L357), `DiveMediaSection`'s `unlockEditing:` argument, and pass `readOnly: true` to the info sheet and the dashboard's fullscreen profile.

- [ ] **Step 4: Fix the tests the change touches**, as Task 3 Step 4 does: drop `unlockEditing: true`; a `unlockEditing: false` case is deleted where an unlock test pins the same control, otherwise rewritten to unlock first.

- [ ] **Step 5: Run** each test file this task changed, by path, at most 15 per run. Expected: PASS, `media_viewer_browser_lock_test.dart` among them. `flutter analyze`: no issues.

- [ ] **Step 6: Commit** `feat(media): the photo viewers always have their lock`.

### Task 5: No Edit button; the old addresses open the page unlocked

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_detail_page_unlock_open.dart` (part of `dive_detail_page.dart`)
- Modify: `dive_detail_page.dart`, `dive_detail_page_bars.dart`, `dive_detail_page_editing.dart` (`_onEditChanged` calls the new part)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart` (L171 to L180, the Edit button)
- Modify: `lib/core/router/app_router.dart` (the `edit` route L642 to L647; the `diveDetail` builder)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (both `editBuilder`s, L240 and L435)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_volume_hint.dart`, `dive_detail_altitude_section.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_page_unlock_open_test.dart` (new), `dive_detail_page_unlock_harness.dart` (`pumpPage` gains `openUnlocked`), `test/core/router/app_router_test.dart`, `test/features/dive_log/presentation/pages/dive_list_page_test.dart`, the volume hint and altitude section tests (`ls test/features/dive_log/presentation/widgets/dive_detail/`; create `dive_volume_hint_test.dart` if there is none)

**Interfaces:**
- Produces: `DiveDetailPage` gains `bool openUnlocked = false` and `VoidCallback? onSittingEnded`. The part holds `void _openUnlockedOnce(Dive stored)` (unlocks after the frame when `openUnlocked` is on, the page is locked and has not opened unlocked before; sets `_openedUnlocked`), `didUpdateWidget` handling `openUnlocked` turning on, and `_noteSittingEnded()` (called from `_onEditChanged`; calls `onSittingEnded` once when a sitting this page opened unlocked ends). `_openUnlockedOnce` is called where the page first has the stored dive (where `shownDive(stored)` is computed).
- Route: `GoRoute(path: 'edit', name: 'editDive', redirect: (_, state) => '/dives/${state.pathParameters['diveId']}?mode=edit')`; `diveDetail` builds `DiveDetailPage(diveId: ..., openUnlocked: state.uri.queryParameters['mode'] == 'edit')`.
- Panes: each dive `editBuilder` (the site branch untouched) returns `DiveDetailPage(diveId: id, embedded: true, openUnlocked: true, onSittingEnded: onCancel, onDeleted: <the detail builder's onDeleted>)`.

- [ ] **Step 1: Write the failing tests** in `dive_detail_page_unlock_open_test.dart`:
  - `opened unlocked, the page shows Cancel and Save`: `pumpPage(openUnlocked: true)`; `action(tester, 'Save')` and `action(tester, 'Cancel')` found, the lock not.
  - `saved, then rebuilt, it stays locked`: open unlocked, type in Notes, Save; resize the view; the lock is shown and Save is not.
  - `a dive that cannot be read stays locked and throws nothing`: `pumpPage(openUnlocked: true, extra: [diveProvider(dive.id).overrideWith((ref) async => null)])`; the not-found state shows, `tester.takeException()` is null, and no Save action.
  - `openUnlocked turning on for a page already showing the dive unlocks it`: pump with `openUnlocked: false`, then rebuild the same route with `true`; Save found.
  - `onSittingEnded fires once when Cancel ends the opened sitting`: a counter; Cancel; counter is 1; another rebuild leaves it 1.
  - `neither bar has an Edit button`: full page and `embedded: true`: `find.byTooltip('Edit dive')` and `find.byTooltip('Edit')` find nothing.
  - In `app_router_test.dart`, beside the bulk route test: `/dives/<id>/edit redirects to /dives/<id>?mode=edit`.
  - In `dive_list_page_test.dart`: `?selected=<id>&mode=edit shows the dive page unlocked, and Cancel returns to ?selected=<id>`.
  - Volume hint: `locked, the hint has no tap` (its `onTap` null). Altitude: `locked, the mismatch note has no tap and no edit icon`.

- [ ] **Step 2: Run** the new file and the four changed test files. Expected: FAIL.

- [ ] **Step 3: Implement** the interfaces above; delete the Edit `IconButton` in `dive_detail_page_bars.dart` (L71 to L75) and in the embedded header; `DiveVolumeHint` passes `onTap: null` when not unlocked; the altitude note's `onTap` is `RecordCardFrameScope.maybeOf(context)?.onOpen` alone and its trailing icon shows only with it.

- [ ] **Step 4: Run** the same files. Expected: PASS. `flutter analyze`: no issues.

- [ ] **Step 5: Commit** `feat(dive-log): open the dive page unlocked from the old edit addresses, and drop the Edit buttons`.

### Task 6: The switch-off paths go

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart` (L102 to L140, the `operations == null` list from L238)
- Modify: `planned_dive_banner.dart`, `draft_dive_banner.dart`, `data_sources_section.dart` (the section and its two inner widgets), `source_bar.dart` (the bar and its chip), `tank_gear_menu.dart` (all in `lib/features/dive_log/presentation/widgets/`), `lib/features/equipment/presentation/widgets/observation_status_chip.dart`, `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` (L784)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page_actions.dart` (`_confirmAndRemoveSource`), `dive_detail_page.dart` (L400)
- Test: `dive_detail_overflow_menu_draft_test.dart`, `_health_test.dart`, `_operations_test.dart`, `_web_test.dart`, and every test file `flutter analyze` flags for a missing `operationReason` or `operations` after Step 3

**Interfaces:**
- Produces: `DiveDetailOverflowMenu` takes `required RecordOperationBlock operations` (not nullable). `operationReason` becomes `required String? operationReason` on each widget listed; the fullscreen profile's `SourceBar` passes `operationReason: null` (it has no Set as primary). `_confirmAndRemoveSource(dive, sourceId, sourceName)` has no `offerUndo` and always passes `offerUndo: false`; `removeSourceWithUndo(offerUndo:)` keeps its parameter and default for the inbox (call 6).

- [ ] **Step 1: Pin what stays.** In `dive_detail_overflow_menu_operations_test.dart` add `operations none lists every operation enabled` (built with `operations: RecordOperationBlock.none`; every operation item present and enabled, no caption) and `the remove source flow on the dive page offers no Undo` in `dive_detail_page_unlock_operations_test.dart` (Remove source run from the unlocked page; no `SnackBarAction` labelled Undo). Delete the menu cases built without `operations`: they pinned the switch-off list.

- [ ] **Step 2: Run** both files. Expected: PASS. This is a refactor, so the pins pass before and after; the red comes from the compiler in Step 3.

- [ ] **Step 3: Implement**: make `operations` required and non-nullable, delete the `operations == null` list and the `== null ||` and `!= null &&` checks; make each `operationReason` required; remove `offerUndo` from `_confirmAndRemoveSource` and L400. `flutter analyze` now names every caller that relied on a default.

- [ ] **Step 4: Fix the callers `flutter analyze` names** (lib and test) by passing the reason or block they mean; a test that relied on the default gets `operationReason: null` or `RecordOperationBlock.none`.

- [ ] **Step 5: Run** each test file this task changed, by path, at most 15 per run. Expected: PASS. `flutter analyze`: no issues.

- [ ] **Step 6: Commit** `refactor(dive-log): every whole-record operation asks the page's lock`.

### Task 7: Delete the single-dive edit form

**Files:**
- Delete: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `dive_edit_page_annotations.dart`, `dive_edit_page_gas_switches.dart`, `dive_edit_page_linked_times.dart`, `dive_edit_page_set_bundle.dart`
- Delete (only the form imported them): `lib/features/dive_log/presentation/widgets/edit_sections/buddies_section.dart`, `conditions_section.dart`, `experience_section.dart`, `gas_gear_section.dart`, `rare_sections.dart`, `statistics_section.dart`, `the_dive_section.dart`, `trip_section.dart`; `lib/features/dive_log/presentation/helpers/linked_dive_times.dart`; `lib/features/dive_log/presentation/widgets/flight_window_warning_banner.dart`; `lib/shared/widgets/forms/add_section_row.dart`
- Delete tests: the single-dive `test/features/dive_log/presentation/pages/dive_edit_*_test.dart` files (49, every one but `dive_edit_apply_last_dive_confirm_test.dart`, which does not build the form; the two mixed files lost their bulk cases in Task 1), `dive_edit_save_field_census_test.dart`, and the orphans' tests: `edit_sections/{trip,the_dive,gas_gear,experience,conditions}_section_test.dart`, `the_dive_section_name_test.dart`, `dive_exclusion_toggles_test.dart`, `helpers/linked_dive_times_test.dart`, `test/shared/widgets/forms/add_section_row_test.dart`, `flight_window_warning_banner_test.dart`
- Modify: `lib/features/dive_log/domain/entities/dive_prefill.dart` (doc comment: "Initial values for a new dive's page"), `test/architecture/markdown_notes_adoption_test.dart` (the `experience_section.dart` entry goes), the 11 ARB files and their generated localizations

- [ ] **Step 1: Record the strings lib/ uses now.** A scratchpad script (python3.14) lists every key in `lib/l10n/arb/app_en.arb` referenced in `lib/` outside `lib/l10n/`, to `keys_before.txt`.

- [ ] **Step 2: Check the five old tests no plan named.** For `dive_edit_boat_fields_test`, `dive_edit_entry_exit_mirror_test`, `dive_edit_rules_test`, `dive_edit_tag_picker_test` and `dive_edit_weight_gear_note_test`: name each behaviour a case pins, then find the card or page test that pins it (grep the cards' tests in `test/features/dive_log/presentation/widgets/dive_detail/editing/` and the `dive_detail_page_unlock_*` files by file name, not by folder run). A behaviour with no pin gets a test in the owning card's test file, written and run red against a mutation, then green. Record the mapping in the plan's "After the build".

- [ ] **Step 3: Run** each card test file Step 2 changed. Expected: PASS.

- [ ] **Step 4: Delete** the files listed. `grep -rn "DiveEditPage\|dive_edit_page" lib test` finds nothing but the plans.

- [ ] **Step 5: Remove the strings that went with them.** Run the script again to `keys_after.txt`; each key in `keys_before` and not in `keys_after` is removed from all 11 ARB files; `flutter gen-l10n`.

- [ ] **Step 6: Verify.** `flutter analyze`: no issues. Run `test/architecture/markdown_notes_adoption_test.dart` and `test/architecture/dive_provider_disposal_test.dart` by path (both name files this task touched). Expected: PASS.

- [ ] **Step 7: Commit** `feat(dive-log): delete the single-dive edit form`.

### Task 8: Follow-up issues and the record

**Files:**
- Modify: `docs/design/plans/2026-11-17-unified-editing-11-switch-over.md` ("After the build")

- [ ] **Step 1: Open the follow-up issues** (Type set over REST, as the issue-type memory says): "Remove the `sitting == null` paths no caller reaches" (call 9, with the file list from `grep -rn "sitting == null\|session == null\|scope == null"` over the media and dive card widgets), and "Bulk edit shows a weighting feedback row it never saves" (call 7). Each body says `Refs #4527`.

- [ ] **Step 2: Write "After the build"** in this plan: what differs from the task text, the Task 7 Step 2 mapping, the issue numbers.

- [ ] **Step 3: Commit** `docs(design): record how plan 11 was built`.

### Task 9: Push through the hook and fix what it finds

- [ ] **Step 1: Merge `origin/main`**, then `flutter analyze` on the whole repo. Expected: no issues.

- [ ] **Step 2: Push** the branch (no pull request yet). The pre-push hook runs the affected tests: the dive page, viewer and pane tests that assumed the switch off fail here.

- [ ] **Step 3: For each failing file**, by path: a case that pinned a switch-off control (the Edit button, the favourite toggle in the bar, an immediate write on the locked page) is deleted where an `_unlock_` test pins the same control with the lock, otherwise rewritten to unlock first. Run the files fixed, at most 15 per run, then push again. Repeat until the hook passes.

- [ ] **Step 4: Commit** each round as `test(dive-log): unlock first where tests assumed the switch off`.

---

## Pull request

One. Title `feat(dive-log): unlock to edit a dive, everywhere (Unified Editing, phase 1)`. The body says `Closes #1906, closes #1570` and `Refs #4527`. It touches `lib/**/presentation/` and `lib/shared/widgets/`, so it carries the "before" pictures from Preparation and the same views after, taken by the macOS window route: the dive page locked and unlocked at desktop and phone width (no Edit button), the list pane locked and unlocked, `/dives/<id>/edit` landing unlocked, the outliers button beside Edit profile, and bulk edit unchanged. Attach them through the current secret screenshot gist as `~/.claude/CLAUDE.md` describes. Then `/code-review` with `--max-findings all`, every valid finding fixed, and Auto-fix on.

---

## After the build

The plan was built as written in one session (Eric chose "Native"), task by task with a failing test first. This is what differs from the task text above.

### Moved between tasks

- `unlock_editing_flag.dart` was deleted in Task 4, not Task 3: the viewers still read it until then, and every commit builds.
- The two mixed form tests were not split in Task 1. Task 7 trimmed each to its bulk case and renamed it: `bulk_dive_edit_new_trip_prefill_test.dart` and `bulk_dive_edit_route_links_test.dart` (the Nav track card still has the route row, so "bulk edit has no route row" still pins something).

### Names that changed, or were added

| Above | Now |
| --- | --- |
| `unlockedDivePane` in `dive_list_page.dart` | In `dive_create_builder.dart`, beside `newDivePaneBuilder`, so the over-cap list page shrinks (1,258 to 1,248) |
| `DiveVolumeHint(diveId:, volumeSymbol:)` | `DiveVolumeHint(volumeSymbol:)`; `DiveAltitudeMismatchNote()` lost its `dive`: both only built the old address |
| The bulk page's `_existingDive`, `_currentLocation` | Gone: always null in bulk edit. The dive center picker ranks by the chosen site alone |
| `bulk_dive_edit_page_test.dart` | Deleted: it asserted the wrapper built `DiveEditPage` |

### Decided while building

- **The dive lab's menu is hidden on a dive that cannot branch.** Without the plan link items it would open empty.
- **Set time in the photo viewer only ever holds.** Its switch-off write path is gone; a sitting that ended while the dialog was open writes nothing, as before.
- **The dive page's no-marker annotation link does nothing** on every page (its switch-off branch opened the time sheet at once).
- **The favourite toggle went from the standalone bar and the overflow menu** with the switch-off branches: favourite is a field of the header card.
- **The pane's edit mode passes `onDeleted`** (back to the list) as well as `onSittingEnded`.
- **42 strings were removed** from all 11 ARB files: the 40 only the deleted form used, and `diveLog_detail_tooltip_editDive` and `diveLog_detail_tooltip_edit`, which Task 5 left unused. `ocr_import_strings_test.dart` checks `ocrImport_newDive_photoHoldFailed` in place of the removed string.
- **Doc comments that cited `dive_edit_page.dart` lines** now describe the behaviour ("as the old dive form did").
- **No page-level test that Remove source offers no Undo:** `remove_source_flow_test.dart` pins `offerUndo: false` at the flow, and the page has passed `false` since Task 3.

### The five old tests no earlier plan named (Task 7 Step 2)

| Old test | Pinned now by |
| --- | --- |
| `dive_edit_boat_fields_test` | `dive_details_fields_test` (blank clears, trimmed), `dive_environment_fields_test` (surface conditions), and a new `dive_details_card_test` case: each row suggests from its own field on earlier dives (red against a mutation, then green). Saving only changed fields is the sitting's general rule |
| `dive_edit_entry_exit_mirror_test` | `dive_environment_fields_test`, the exit-follows-entry group |
| `dive_edit_rules_test` | `new_dive_after_create_test`; a stored dive's Save runs no rules by construction (only `NewDiveAfterCreate` and Mark as logged or complete call them) |
| `dive_edit_tag_picker_test` | `tag_form_block_test` (Browse), the block the Tags card uses |
| `dive_edit_weight_gear_note_test` | `dive_weight_gear_lead_test` |

### Follow-up issues

- #4673: remove the immediate-write branches no caller reaches (call 9).
- #4674: bulk edit shows a weighting feedback row it never saves (call 7).
