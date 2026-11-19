# Unified Editing, Phase 2, Plan 7: The Site Switch-Over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn unlock-to-edit on for every build and make it the only way to edit one site: the build switch goes, the Edit buttons go, the old addresses open the site page unlocked, merge keeps working exactly as today from a page of its own, and the site edit form is deleted. This ends phase 2 of issue #4527.

**Architecture:** As phase 1's plan 11 did for dives. Merge moves out of `SiteEditPage` first, into `SiteMergePage`'s own state and part files, so the form can be deleted without touching it; the five section widgets it builds stay, now merge's alone. Then `kUnlockSiteEditing` is deleted and each of its readers keeps the branch it takes with the switch on; the `unlockEditing` parameters that only carried the switch go with it, and the site page always hosts editing. `/sites/:id/edit` (with or without `?suggest=1`) always redirects to `/sites/:id?mode=edit`. Last, `site_edit_page.dart`, the one section only it used, its strings and its tests are deleted, each test's behaviour first found pinned by a test of the card that owns it now.

**Tech Stack:** Flutter, Riverpod 3, go_router 17, drift (test database through `setUpTestDatabase`), `flutter gen-l10n` with 11 ARB locales.

**Spec:** `docs/design/specs/2026-11-17-unified-editing-phase-2-sites-design.md`: "Design: merge", "Design: what happens to the edit form", "Design: hosts and routes" and "Delivery" item 7. The model is phase 1's switch-over, `docs/design/plans/2026-11-17-unified-editing-11-switch-over.md`, and its "After the build". Plans 1 to 6 of phase 2 shipped every name used here; plan 6 is PR #4751.

## Questions for Eric

The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **Where the manual test runs.** *Eric chose the simulator on 2026-11-19 ("Yes, the simulator").* You asked for a real dev build with the switch on, against a copy of a database through `SUBMERSION_DB_PATH` with sync off. On your Mac account that is not safe: on 2026-11-19 (#4738) a dev build launched on a fresh, empty `SUBMERSION_DB_PATH` database, with automatic sync and cloud backup turned off in its prefs, still pulled your log from Dropbox and uploaded as a new device. The Dropbox credentials in the keychain drive sync, not the prefs, and a copy of your database also carries its sync identity. **Recommended:** I run it myself in the iOS Simulator, on a simulator that has never had Submersion installed (the "iPhone 17 Pro" for the phone layout, and an iPad simulator for the list's master-detail pane if one is installed): its keychain holds no Dropbox credentials, so nothing can reach your log. The data is a copy of your database placed inside that simulator's own app container. The other ways: a separate macOS user account with no Dropbox sign-in (the Mac layout and window chrome, but you set the account up), or you run the steps yourself on a build you choose. (Task 6.)
2. **The library reader's path by hand.** *Eric chose the recommended answer on 2026-11-19 ("Yes, both").* Suggesting a change needs a shared site library connected on the test device where the profile is a reader, and a fresh simulator has none. **Recommended:** the reader's path is left to plan 5's tests (`site_detail_page_reader_test.dart`, `site_reader_send_test.dart`) and marked "not tried by hand" in the PR, unless you have a throwaway library you can connect to the simulator as a reader. The other way: set one up for the test (a second profile as owner, a local folder as its store), which is more set-up than the rest of the test together. (Task 6.)
3. **A merge whose surviving site is a library site.** *Eric chose the recommended answer on 2026-11-19 ("Yes, both").* Today the form's save path checks the survivor's library role before merging, so merging into a library site you only read can turn into a suggestion and never merge (the merge survey found this; it looks unintended). **Recommended:** the merge page never sends a suggestion: a merge whose surviving site this profile may not edit is refused with today's "Only its owner can delete this site" style message (`sharedItems_notOwner_site`) and merges nothing, as the repository already refuses a duplicate the profile may not remove. The other way: carry the suggestion diversion over into the merge page unchanged. (Task 1.)

## Calls made in this plan, for Eric to check

Each follows phase 1's plan 11, which you confirmed for dives, or the phase 2 spec.

1. **`/sites/:id/edit` stays an address** and always redirects to `/sites/:id?mode=edit`, with or without `?suggest=1`: the page decides between an editor's and a reader's sitting from the role (plan 5). The route keeps no builder, as `editDive` has none.
2. **The Edit buttons go**: the pencil on the full page's locked bar and the one on the list pane's header, and `_openPaneEditMode` with them. The lock (or a reader's "Suggest changes") is the one way in. The old separate "Suggest changes" button, which pushed `?suggest=1`, goes too.
3. **The list pane's `&mode=edit` and the dive list's `site=<id>&mode=edit`** keep opening the site unlocked in the pane, as plan 4 made them with the switch on.
4. **Merge moves unchanged** (spec): the same sections, the cycle buttons, the confirmation, the undo snackbar on the list, the altitude filled from the elevation lookup, and the expected species written again after the merge. Two dead parts of the form's merge are not carried over: the embedded branches (no opener passes `embedded`) and the unused classification it computed. The species double write is left as is and noted for a follow-up.
5. **`/sites/merge` reached with fewer than two sites goes back to `/sites`**, as `/dives/bulk-edit` does with no dives; today it shows an empty new-site form titled "New Site".
6. **Strings only the deleted code used are removed** from all 11 ARB files, by the rule plan 11 used: a key goes only if `lib/` referenced it before the deletion and references it no more. The inventory expects about 22 of the form's own keys plus `diveSites_detail_editTooltip` and `diveSites_detail_editTooltipShort`; the merge page keeps the section, merge and location strings it uses.
7. **Every old form test is accounted for**: each case is found pinned by a test of the card, sitting or page that owns the behaviour now, or a case is added there (red against a mutation first) before the old file goes. The table is written into this plan's "After the build".

## Not in this plan

- Phase 3 (the other record types) and its switch, `kUnlockRecordEditing`.
- The merge page's own improvements: one transaction for the species write (call 4), edit-in-place merge. Follow-up issues.
- Plans 1 to 6's left-open minors.

## Global Constraints

- Merge (`/sites/merge`, the list's selection bar) builds and merges exactly as today: same fields and cycle buttons, same confirmation, same refusal for a site another profile owns, same `SiteMergeResult` returned, same undo on the list (Question 3 and call 5 aside).
- Every single-site edit is a sitting: one Save, one transaction, one change log operation, as plans 1 to 6 built. A new site and a duplicate are plan 6's page.
- No file over 800 lines. `site_detail_page.dart` (2,432), `app_router.dart` (2,749), `site_list_content.dart` (1,851) and `dive_list_page.dart` (1,234) are already over and must not grow. The merge page is split into part files, each under 800.
- **Shared files.** This plan changes nothing under `lib/shared/`. PR #4757 (phase 3, plan 2, open) changes `app_router.dart` too, in the documents and species routes; this plan changes only the site routes there, so whichever merges second takes main with a plain merge. If #4757 has merged when this starts, branch from the main that has it.
- Anything that acts after an `await` checks `mounted`, and reads `ref` and `context` before its first `await`.
- Every value shown or typed follows the active diver's units.
- Never an em-dash or en-dash as punctuation; nothing names the coding assistant or its maker.
- Test commands name test FILES by path, at most 15 per run, never a folder, `test/architecture/` or `test/shared/`. The pre-push hook runs format, the whole-repo analyze, the guards and the affected tests.
- `dart format` the changed files before each commit.

## Review Focus

1. **An old bookmark to a deleted site** (`/sites/<gone>/edit`): the redirect lands on the site page, which shows not found, stays locked and throws nothing. Test in Task 3.
2. **`/sites/<id>/edit?suggest=1` opened by an editor**: an editor's sitting, Save not Send; by a reader, a reader's sitting. Test in Task 3.
3. **A merge whose survivor this profile may not edit** (a library site it reads): refused with the message, nothing merged, the list unchanged. Test in Task 1.
4. **`/sites/merge` reached with one id or none**: back on `/sites`, nothing written. Test in Task 1.
5. **A site opened from the dive list's pane** (`/dives?selected=<dive>&site=<site>`): the lock, no pencil; unlocked, its back arrow to the dive asks first with changes. Test in Task 3.

## Preparation

- Worktree: `git submodule update --init --recursive`, `flutter pub get`, branch from `origin/main` (contains #4751).
- Before any code changes, take the "before" pictures by the widget-golden route (the route chosen on 2026-11-19 while Eric's sync is set up; see `project_macos_background_screenshots_window_resize` in memory): the site page's locked bar at phone and desktop width with its Edit pencil, the list pane's header with its pencil, the form the pencil opens, and the merge page.

## File Structure

| File | Change |
| --- | --- |
| `lib/features/dive_sites/presentation/pages/site_merge_page.dart` | Becomes the merge page: widget, fields, `initState`, `dispose`, `build` (Task 1) |
| `site_merge_page_fields.dart`, `site_merge_page_candidates.dart`, `site_merge_page_location.dart`, `site_merge_page_save.dart` (same folder, `part of`) | The moved merge code, grouped as Task 1 says, each under 800 lines |
| `lib/features/dive_sites/presentation/widgets/edit_sections/{identity,location,dive_info,access_safety,life_notes}_section.dart`, `merge_field_extras.dart` | Kept, now the merge page's; doc comments say so |
| `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart` | Deleted with its test (Task 4): only the form used it |
| `lib/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart` | Deleted (Task 2) |
| `lib/features/dive_sites/presentation/pages/site_edit_routes.dart` | `unlockEditing` parameters go; `siteEditLocation` always answers; the switch-off branches go (Tasks 2, 3) |
| `lib/features/dive_sites/presentation/pages/site_detail_page*.dart` | `unlockEditing` goes, `hostsEditing` is always true, the Edit pencils and `_openPaneEditMode` go (Tasks 2, 3) |
| `lib/core/router/app_router.dart` | `editSite` redirect only; `mergeSite` redirect for fewer than two ids |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Deleted (Task 4) |

---

### Task 1: Merge gets a page of its own

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_merge_page.dart`
- Create: the four `site_merge_page_*.dart` parts above
- Modify: `lib/core/router/app_router.dart` (the `mergeSite` route only)
- Test: `test/features/dive_sites/presentation/pages/site_merge_page_test.dart` (create), moving in the cases of `site_edit_merge_page_test.dart`, `site_edit_merge_entry_method_test.dart`, the merge group of `site_edit_page_test.dart` (`merge mode share toggle`) and the refused-merge case of `site_edit_page_sharing_test.dart`

**Interfaces:**
- Produces: `SiteMergePage({Key? key, required List<String> siteIds})`, a `ConsumerStatefulWidget` that pops `SiteMergeResult(survivorId:, snapshot:)` on a merge and `null` on Cancel, as today. Its state holds only what merge uses (survey: about 700 lines of merge code and 350 of location actions, validators, summaries and the species picker the form shared).
- Produces: `String? siteMergeRedirect(BuildContext context, GoRouterState state)` in `site_edit_routes.dart`: `/sites` when `state.extra` is not a list of at least two ids, else null.
- Parts: `_fields` the controllers, listeners and validators; `_candidates` the merge candidates and cycling (`_initializeFromMerge`, `_buildDistinctCandidates`, `_cycle*`, `_adoptMergeCountryCode`); `_location` Use my location, Pick from map, Look up and the altitude fill; `_save` the confirmation, `mergeSites`, the species write, the pop.

- [ ] **Step 1: Write the failing tests** in `site_merge_page_test.dart`: every case of the four sources above, pumping `SiteMergePage(siteIds: [...])` in place of `SiteEditPage(mergeSiteIds: ...)`, with their assertions unchanged. Add:
  - Review Focus 3: `a merge whose survivor this profile may not edit is refused`: the survivor a library site with the profile a reader; Save, Merge: the `sharedItems_notOwner_site` snackbar, the page stays, both sites still stored, no `SiteMergeResult`.
  - Review Focus 4: `the merge address with fewer than two sites goes back to the list`: `siteMergeRedirect` with `extra` `['s1']`, `[]` and `null` answers `/sites`; with `['s1', 's2']`, null.
  - `the merge page offers no suggestion`: a survivor in a library: no note field, the title "Merge Sites".
- [ ] **Step 2: Run** `flutter test test/features/dive_sites/presentation/pages/site_merge_page_test.dart`. Expected: compile failure (`SiteMergePage(siteIds:)` builds the form; `siteMergeRedirect` undefined).
- [ ] **Step 3: Implement** the page and its parts by moving the merge code out of `site_edit_page.dart` (survey line ranges: `_initializeFromMerge` 614-825, the merge build branch 861-924, the extras 1044-1097 and 1153-1190, 1551-1793, the save path's merge branch 2355-2372 and 2428-2471, the candidate classes 2651-2677), dropping the `isMerging` branching, the embedded branches and the unused classification (call 4). Question 3: before `mergeSites`, a survivor this profile may not edit (`LibraryEditStamper().mayEdit(survivorId, actingDiverId:)`) is refused with `sharedItems_notOwner_site`. The `mergeSite` route gets `redirect: siteMergeRedirect`. The form keeps its own merge code until Task 4 deletes it.
- [ ] **Step 4: Run** the same file, then `flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart test/features/dive_sites/presentation/widgets/site_list_content_sharing_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): merge gets a page of its own`.

### Task 2: The switch on

**Files:**
- Delete: `lib/features/dive_sites/presentation/editing/unlock_site_editing_flag.dart`
- Modify: `site_edit_routes.dart`, `site_detail_page.dart`, `site_detail_page_editing.dart`, `site_detail_page_fullscreen_scape.dart`, `site_detail_page_operations.dart`, `site_detail_page_creating.dart`, `site_list_page.dart` (only if an argument goes)
- Test: every test file that passes `unlockEditing:` to a site page or helper (survey: `site_detail_page_unlock_pane_test.dart`, `site_new_routes_test.dart`, `site_detail_page_operations_test.dart`, `site_detail_page_unlock_harness.dart` and the files that use the harness's `unlockEditing`)

**Interfaces:**
- Produces: `siteEditLocation(String siteId)`, `siteEditPane(context, id, onSaved, onCancel, {onDeleted})`, `siteInDivesPane(context, siteId, {onSaved, onCancel, onClose, onDeleted})`, `newSitePage(extra, {duplicateOfId})`, `newSitePane(context, onSaved, onCancel)`, `openNewSite(context)`, `unlockedSitePane(context, id, onCancel, {onDeleted})`: each without `unlockEditing`, each the branch it took with the switch on.
- Produces: `SiteDetailPage` without `unlockEditing`; `_SiteDetailPageEditing.hostsEditing => true`. Each `hostsEditing`/`widget.unlockEditing` reader keeps its switch-on value:

| Reader | Always |
| --- | --- |
| `site_detail_page.dart` desktop redirect (`widget.unlockEditing && widget.openUnlocked && firstBuild`) | `widget.openUnlocked && firstBuild` |
| `site_detail_page.dart` `attachmentLock: widget.unlockEditing` | `attachmentLock: true` |
| `site_detail_page.dart` `canSuggestOnLibrarySite(...) && !hostsEditing` (the old Suggest changes button) | The button goes (Task 3 deletes it with the pencils) |
| `site_detail_page.dart` feature layer `readOnly: hostsEditing` | `readOnly: true` |
| `site_detail_page_editing.dart` `if (!hostsEditing)` | The branch goes |
| `site_detail_page_fullscreen_scape.dart` `readOnly: hostsEditing && session == null` | `readOnly: session == null` |

- [ ] **Step 1: Change the tests first**: drop every `unlockEditing:` argument; delete the cases that pinned the switch off (`siteEditPane`/`siteInDivesPane`/`newSitePage`/`newSitePane` building `SiteEditPage`, the switch-off case of `site_detail_page_operations_test.dart`) where a switch-on case pins the same entry.
- [ ] **Step 2: Run** those files. Expected: compile failures for the removed parameter.
- [ ] **Step 3: Implement**: delete the flag file and each reader's switch-off branch as the table says.
- [ ] **Step 4: Run** `flutter test test/features/dive_sites/presentation/pages/site_detail_page_unlock_pane_test.dart test/features/dive_sites/presentation/pages/site_new_routes_test.dart test/features/dive_sites/presentation/pages/site_detail_page_operations_test.dart test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart test/features/dive_sites/presentation/pages/site_detail_page_new_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): unlock-to-edit for every build`.

### Task 3: No Edit pencils; the old addresses open the page unlocked

**Files:**
- Modify: `site_detail_page_bars.dart` (the two pencils, `_openPaneEditMode`), `site_detail_page.dart` (the old Suggest changes button), `site_edit_routes.dart`, `app_router.dart` (the `editSite` route)
- Test: `test/core/router/app_router_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_unlock_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_reader_test.dart`, `test/features/dive_log/presentation/pages/embedded_site_navigation_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_page_test.dart` (its `navigates to /sites/:id/edit` case)

**Interfaces:**
- Produces: the `editSite` route as `GoRoute(path: 'edit', name: 'editSite', redirect: siteEditRedirect)` with no builder; `siteEditRedirect` answers `/sites/<id>?mode=edit` always (call 1).

- [ ] **Step 1: Write the failing tests:**
  - `app_router_test.dart`: `the site edit address always opens the page unlocked`: `siteEditLocation('s1')` is `/sites/s1?mode=edit`; the `editSite` route has no builder.
  - `site_detail_page_unlock_test.dart`: `the locked bar has the lock and no Edit pencil` (full page and pane); Review Focus 1: `an old edit address for a deleted site shows not found, locked` (a router at `/sites/gone/edit`).
  - `site_detail_page_reader_test.dart`: Review Focus 2: `?suggest=1 opens an editor's sitting for an editor and a reader's for a reader`, through the router; `the page has no separate Suggest changes button` (only the unlock control reads it).
  - `embedded_site_navigation_test.dart`: rewritten for the lock: Review Focus 5: the site in the dive list's pane shows the lock and no pencil; unlocked with a change, its back arrow asks first; `&mode=edit` there opens unlocked.
  - `site_detail_page_test.dart`: the `navigates to /sites/:id/edit` case is deleted (the pencil it tapped is gone; the lock is pinned above).
- [ ] **Step 2: Run** those files. Expected: the new cases fail on the pencil and the builder.
- [ ] **Step 3: Implement**: remove both pencils and `_openPaneEditMode`, the old Suggest changes button, and the `editSite` builder.
- [ ] **Step 4: Run** the same files. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sites): the lock is the one way in; old edit addresses open the page unlocked`.

### Task 4: Delete the site edit form

**Files:**
- Delete: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`, `lib/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart`
- Delete: the form's tests (below), once Step 2 has found each case a home
- Modify: `test/architecture/number_parsing_single_source_test.dart` (its allowlist entry for the form's path; not run by hand: the hook runs it), the ARB files and `flutter gen-l10n` (call 6), `site_list_page_test.dart` (its three cases that expected the form now expect the site page), `site_delete_usage_dialog_test.dart` (its form delete case goes; the page's delete dialog is pinned by `site_detail_page_operations_test.dart`), `app_router_test.dart` (the duplicate group casts to `SiteDetailPage`)

**The old tests and where their behaviour lives now** (Step 2 confirms each case, adding one where none pins it):

| Old test | Pinned now by |
| --- | --- |
| `site_edit_page_test.dart` (35, merge group moved in Task 1) | Header, measure, access and location card editor tests; `site_sharing_sitting_test`; `site_detail_page_new_test` (new site, Save waits, name required); `site_edit_save_service_test` (save); `site_detail_page_unlock_pane_test` (embedded, discard) |
| `site_edit_page_sharing_test.dart` (17, refused merge moved in Task 1) | `site_detail_page_sharing_unlock_test`, `site_detail_page_operations_test` (remove, delete, hide, unhide) |
| `site_edit_duplicate_test.dart` (15) | `site_new_sitting_test`, `site_detail_page_new_test` |
| `site_edit_lookup_from_coordinates_test.dart` (15), `site_edit_fill_location_test.dart` (4), `site_edit_language_test.dart` (1), `site_edit_altitude_autofill_test.dart` (3) | Location card editor tests, `site_location_rules` tests |
| `site_edit_suggest_mode_test.dart` (7) | `site_detail_page_reader_test`, `site_reader_send_test` |
| `site_edit_seed_name_test.dart` (5), `site_edit_seed_location_test.dart` (2) | `site_new_sitting_test`, `site_detail_page_new_test` |
| `site_edit_entry_method_test.dart` (7), `site_edit_entry_suggestion_test.dart` (5) | Access card editor tests (Step 2 checks the entry suggestion chip has a card case) |
| `site_edit_locale_numbers_test.dart` (2) | Measure card editor tests |
| `site_edit_rules_test.dart` (2) | `site_detail_page_new_test` (rules after a create); a stored site's Save runs none by construction |
| `site_edit_type_tags_test.dart` (4) | Header card editor tests |
| `type_tags_section_test.dart` | Deleted with the widget |

- [ ] **Step 1: List** each old file's cases (`grep -n "test(\|testWidgets("`) into this plan's "After the build" table as you go.
- [ ] **Step 2: For each case**, find the passing case that pins it in the file named above. Where none does, write one there, watch it fail against a mutation of the behaviour, then pass. Run each touched file by path, at most 15 per run.
- [ ] **Step 3: Delete** the form, `type_tags_section.dart`, and the old tests; update the four test files named above.
- [ ] **Step 4: Remove the strings** only the deleted code used (call 6) from all 11 ARB files; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze` on the whole repo. Expected: no issues. Then the files of Steps 2 and 3, by path.
- [ ] **Step 6: Commit** `feat(sites): the site edit form is gone`.

### Task 5: Push through the hook and fix what it finds

- [ ] **Step 1: Merge `origin/main`**, then `flutter analyze` on the whole repo. Expected: no issues.
- [ ] **Step 2: Push** the branch (no pull request yet). The hook runs the affected tests: site tests that assumed the switch off fail here.
- [ ] **Step 3: For each failing file**, by path: a case that pinned a switch-off control (the pencil, the form, an immediate write on a locked page) is deleted where an unlock test pins the same control with the lock, otherwise rewritten to unlock first. Run the files fixed, at most 15 per run, then push again until the hook passes.
- [ ] **Step 4: Commit** each round as `test(sites): unlock first where tests assumed the switch off`.

### Task 6: Try every site path by hand

On the route Question 1 settles (recommended: a simulator that has never had Submersion installed, a copy of the database in its own container, nothing signed in to a cloud store). Never on the live database, and never a dev build on Eric's macOS account while his sync is set up. A failure found here gets a test that fails first, then the fix, before the pull request.

- [ ] **Open and look**: a site from the list, the map and a dive's site row: locked, no pencil, the lock in the bar (phone) and the pane header (iPad).
- [ ] **Unlock and edit each card**: the header (name, water type, types, sharing), Description, Location (type a point, Use my location, Pick from map, Look up), Altitude (the found altitude offered as a suggestion), Depth, Difficulty, Rating, Hazards, Access, Features on the fullscreen map, Expected species, Media (add, unlink), Documents (attach, open the PDF viewer's own lock), Tags, Notes.
- [ ] **Save** with several cards changed: one History entry; revert it from History and every value returns.
- [ ] **Cancel** with changes: asks; Discard writes nothing. Leave by the sidebar with changes: asks.
- [ ] **New site** from the list's Add (phone and iPad pane), the map, the empty list and a dive's site picker (the dive gets the site); Cancel untouched leaves without asking.
- [ ] **Duplicate** a site with types, tags, species and features: the copy opens prefilled, Save creates it with every row, the features in order.
- [ ] **Merge** two sites from the list's selection: cycle a field, Merge, the undo snackbar, Undo restores both.
- [ ] **Reader suggestion** (Question 2): if a library is connected as a reader, Suggest changes, a note, Send; otherwise noted as not tried by hand.
- [ ] **Old addresses**: `/sites/<id>/edit` and `/sites/<id>/edit?suggest=1` (through a deep link or the router's location bar on the iPad) open the page unlocked; `/sites/<gone>/edit` shows not found.
- [ ] **Record** each step's result in the pull request's Test Plan, and the database copy is deleted afterwards.

---

## Pull request

One. Title `feat(sites): unlock to edit a site, everywhere (Unified Editing, phase 2)`. The body says `Refs #4527`, and `Closes #N` for each open issue about the site edit form that this resolves (search open issues for the form, its pencil and merge before writing it). It touches `lib/**/presentation/`, so it carries the "before" pictures from Preparation and the same views after, by the widget-golden route: the site page locked at phone and desktop width (no pencil), the list pane header, `/sites/<id>/edit` landing unlocked, and the merge page unchanged. Attach them through the project's current secret screenshot gist (`PR screenshots: submersion-app/submersion` with the highest number), as `docs/contributing/pull-requests.md` describes. Then `/code-review` with `--max-findings all`, every valid finding fixed, and Auto-fix on.

---

## After the build

(Filled in while building: names that changed, decisions made, and the full table of old form test cases and the tests that pin each now.)
