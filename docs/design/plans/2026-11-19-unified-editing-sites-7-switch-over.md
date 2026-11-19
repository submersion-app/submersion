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

Built in the order 2, 3, 1, 4, then the push and the manual test (the ledger's first ruling): with the switch on and the pencils gone, merge was the form's only user, so the merge page came after them and the form could go straight after it.

**Names.** `SiteMergePage` is its own page in five files: `site_merge_page.dart` and the parts `_fields`, `_candidates`, `_location`, `_save` (the largest is 404 lines). `site_edit_routes.dart` gained `siteMergeIds(extra)` beside `siteMergeRedirect`, so the route's builder and its redirect read the handed ids the same way. `siteInDivesPane` lost its unused `onSaved`. The editing record `_editingInBuild` hands to `build` lost its `hosts` field, and `_lockedBar` and `_siteMenu` their `hosts` parameter: with the switch gone they were always true.

**Decisions made while building.**

- The merge page is a pruned copy of the form's merge code into new parts, not a `git mv` of the form, so the form's own 17 test files kept building until this task deleted them.
- Question 3 runs after the confirmation, right before `mergeSites`, as the plan's test reads (Save, Merge, then the refusal). A survivor in a library not connected here is still refused as before, with "not connected".
- Nine strings went, not the 24 the inventory expected: the card editors reuse the rest. Removed: `diveSites_detail_editTooltip`, `diveSites_detail_editTooltipShort`, `diveSites_edit_appBar_deleteSiteTooltip`, `diveSites_edit_appBar_editSite`, `diveSites_edit_group_typeTags`, `diveSites_edit_snackbar_errorDeleting`, `diveSites_edit_snackbar_featuresNotCopied`, `diveSites_edit_snackbar_siteAdded`, `diveSites_edit_snackbar_siteUpdated`.
- Task 2 left eleven cases red in four test files no brief named (`site_detail_page_sharing_test`, `site_detail_library_actions_test`, `site_detail_page_section_config_test`, `dive_list_embedded_site_test`): they ran record actions from the locked menu, or tapped the old Edit button. They unlock first now, in a commit of their own. One case ("the owner sees no Shared with row on the page", issue #3766) said the opposite of today's page and went; `site_detail_page_sharing_unlock_test` pins the line it shows.
- The site page's pane header overflows at 390 px when it also holds a library's buttons. The list pane is never that narrow (it shows only at desktop widths), so the test that met it uses a pane width; it is a follow-up, not a fix here.

**The old form's tests and where each lives now.** 130 cases: 67 were already pinned by the site page, its cards and its sittings; 52 had no counterpart and got one (each watched failing against a mutation of the behaviour for the lookup cases, and passing against today's code for the rest); 11 belonged only to the form. The four merge test sources moved whole in Task 1 and are not listed.

| Old file | Old case | Now | Where |
| --- | --- | --- | --- |
| `site_edit_page_test` | share toggle: hides the toggle when only one diver exists | Pinned | `editing/site_header_card_editor_test.dart` 'not offered with one diver' (sharing group) |
| `site_edit_page_test` | share toggle: shows toggle reflecting AppSettings default with 2+ divers | Pinned | `editing/site_header_card_editor_test.dart` 'offered with two or more divers'; `editing/site_new_sitting_test.dart` 'a seed is the active diver's, shared by default, with nothing else'; `editing/site_sharing_sitting_test.dart` 'a new site's sharing is the seed's, read from nowhere' (an isShared seed reads as everyone) |
| `site_edit_page_test` | a new site shared with one profile saves its share | Pinned | `editing/site_new_sitting_test.dart` 'is created with every copied row, features in order' (create stores profile ids {'other'}); `editing/site_sharing_sitting_test.dart` 'a new site's sharing is the seed's, read from nowhere' (the choice is held on the header) and 'choosing other profiles holds the change and dots the header' (nothing stored before Save) |
| `site_edit_page_test` | unshare confirmation: un-share on existing shared site shows confirmation dialog | Added | added: `editing/site_header_card_editor_test` "taking a profile off asks first" |
| `site_edit_page_test` | new site basics: shows app bar title and save button | Pinned | `pages/site_detail_page_new_test.dart` 'a new site opens unlocked with the header and starter cards open' (New Site title, RecordEditBar) and 'Save waits for the first entry' (the Save action) |
| `site_edit_page_test` | new site basics: validation fails when site name is empty | Pinned | `editing/site_header_card_editor_test.dart` 'a blank name refuses Save and shows the message'; `pages/site_detail_page_new_test.dart` 'Save waits for the first entry'; `pages/site_detail_page_unlock_cards_test.dart` 'a name emptied outside its editor refuses Save' |
| `site_edit_page_test` | new site basics: an unreadable max depth blocks save and says why (#1900) | Pinned | SiteDepthCardEditor uses RecordNumberRow: `shared/widgets/record_editing/record_number_row_test.dart` 'typing unreadable text marks the card and shows the message' and 'a refused Save scrolls the row into view' (save() is false) |
| `site_edit_page_test` | new site basics: an unreadable depth in a section collapsed before Save still blocks the save (#1900 review) | Pinned | `shared/widgets/record_editing/record_number_row_test.dart` 'a refused Done scrolls the row into view' (a card with unreadable input refuses to close, so it cannot be hidden) and 'a refused Save scrolls the row into view' |
| `site_edit_page_test` | new site basics: renders depth/difficulty/rating/gps/altitude sections | Pinned | `pages/site_detail_page_new_test.dart` 'a new site opens unlocked with the header and starter cards open' (header, location, depth, notes open) and 'cards outside the starter set wait in the strip' (rating and the others are offered); `editing/site_new_sitting_test.dart` 'the starter cards, and Altitude for a point' |
| `site_edit_page_test` | new site basics: tapping a rating star updates rating | Pinned | `editing/site_measure_card_editors_test.dart` 'rating sets and clears' |
| `site_edit_page_test` | new site basics: selecting a difficulty chip updates state | Pinned | `editing/site_measure_card_editors_test.dart` 'difficulty chips set and clear' |
| `site_edit_page_test` | new site basics: selecting a water type chip updates state | Pinned | `editing/site_header_card_editor_test.dart` 'tapping the selected water type clears it' (sets and clears) |
| `site_edit_page_test` | edit existing site: loads existing site data into form fields | Pinned | `pages/site_detail_page_unlock_test.dart` 'unlocking titles the bar and marks the editable cards' (title 'Editing Blue Hole'); `editing/site_markdown_card_editor_test.dart` 'shows the sitting's value'; `pages/site_detail_page_operations_test.dart` 'the full page menu offers Delete to the owner' |
| `site_edit_page_test` | edit existing site: loading state shows progress indicator | Pinned | `pages/site_detail_page_test.dart` 'shows loading indicator in non-embedded mode' |
| `site_edit_page_test` | edit existing site: null site shows not-found state | Pinned | `pages/site_detail_page_test.dart` 'shows not-found state when site is null (non-embedded)'; `pages/site_detail_page_unlock_test.dart` 'an old edit address for a deleted site shows not found, locked' |
| `site_edit_page_test` | edit existing site: error state shows error text | Pinned | `pages/site_detail_page_test.dart` 'shows error state in non-embedded mode' |
| `site_edit_page_test` | edit existing site: delete icon shows confirmation dialog with cancel/delete options | Pinned | `pages/site_detail_page_operations_test.dart` 'a cancelled Delete keeps the open card open'; `pages/site_detail_page_test.dart` 'embedded delete calls onDeleted callback' (shows 'Delete Site'; Cancel deletes nothing) |
| `site_edit_page_test` | embedded layout: renders embedded header with Save and Cancel | Pinned | `pages/site_detail_page_new_test.dart` 'in the pane, Save hands the new id over'; `pages/site_new_routes_test.dart` 'the pane's new site is the page'. The add_location avatar was form chrome only. |
| `site_edit_page_test` | embedded layout: embedded Cancel with no changes calls onCancel | Added | added: `pages/site_detail_page_new_test` "in the pane, Cancel on an untouched new site leaves at once" |
| `site_edit_page_test` | embedded layout: embedded Cancel with changes shows discard dialog | Added | added: `pages/site_detail_page_new_test` "in the pane, Cancel with an entry asks first" |
| `site_edit_page_test` | embedded layout: embedded edit shows edit icon in header avatar | Form only | The form's embedded header avatar. The pane's unlocked title is pinned by `pages/site_detail_page_unlock_pane_test.dart` 'the pane unlocks under the shared pane header'. |
| `site_edit_page_test` | embedded layout: confirming a standalone delete returns to the site list | Pinned | `pages/site_detail_page_operations_test.dart` 'unlocked with nothing to save, Delete asks, deletes and leaves' |
| `site_edit_page_test` | embedded layout: embedded edit offers delete when the host handles it | Pinned | `pages/site_detail_page_test.dart` 'embedded delete calls onDeleted callback' (Delete in the pane menu opens the dialog) |
| `site_edit_page_test` | embedded layout: embedded edit hides delete when no host handles it | Form only | Only the form hid Delete when embedded with no onDeleted. The page always offers Delete to the owner and calls onDeleted only if one is given. |
| `site_edit_page_test` | embedded layout: confirming an embedded delete removes the site and calls onDeleted | Added | added: `pages/site_detail_page_sharing_test` "the owner's confirmed delete removes the site and closes the pane" |
| `site_edit_page_test` | save flow: save new site shows snackbar after save | Pinned | `pages/site_detail_page_new_test.dart` 'Save creates the site and leaves with its id' and 'through go_router, Save leaves with the new id' (the old case asserted nothing) |
| `site_edit_page_test` | save flow: embedded save calls onSaved callback | Pinned | `pages/site_detail_page_new_test.dart` 'in the pane, Save hands the new id over' |
| `site_edit_page_test` | location fields: renders City, Island, and Body of Water fields | Added | added: `editing/site_location_card_editor_test` "city, island and body of water are rows the diver types in" |
| `site_edit_page_test` | location fields: persists entered City, Island, Body of Water on save | Added | added: `editing/site_location_card_editor_test` "city, island and body of water are rows the diver types in" |
| `site_edit_page_test` | location auto-fill: clearing Region on a site with coordinates persists empty, not a geocoded value | Added | added: `editing/site_location_card_editor_test` "clearing a name on a placed site holds it empty and asks the geocoder nothing" |
| `site_edit_page_test` | location auto-fill: clearing Country on a site with coordinates persists empty, not a geocoded value | Added | added: `editing/site_location_card_editor_test` "clearing a name on a placed site holds it empty and asks the geocoder nothing" |
| `site_edit_page_test` | location auto-fill: Use my location fills empty Country/Region (the suggestion path is preserved) | Pinned | `editing/site_location_card_editor_test.dart` 'Use my location fills the position and the empty names' |
| `site_edit_page_test` | locationServiceProvider: defaults to the LocationService singleton | Added | added: `core/providers/location_service_provider_test` "locationServiceProvider defaults to the LocationService singleton" |
| `site_edit_page_sharing_test` | another profile gets Remove, not Delete | Pinned | `pages/site_detail_page_sharing_test.dart` 'another profile sees Shared by and removes it from itself' (see caveat) |
| `site_edit_page_sharing_test` | while a profile switch re-reads the profile, offers neither Delete nor Remove (issue #2677 review) | Pinned | `pages/site_detail_page_sharing_test.dart` 'while a profile switch re-reads the profile, the menu offers neither Delete nor Remove (issue #2677 review)' |
| `site_edit_page_sharing_test` | an unreadable profile offers neither action and locks sharing | Added | added: `editing/site_header_card_editor_test` "an unreadable profile locks sharing" |
| `site_edit_page_sharing_test` | another profile cannot change sharing | Added | added: `editing/site_header_card_editor_test` "another profile cannot change sharing" |
| `site_edit_page_sharing_test` | the owner deletes, warned about other profiles' dives | Pinned | `pages/site_detail_page_sharing_test.dart` 'the owner deletes it, warned about other profiles' dives' |
| `site_edit_page_sharing_test` | a shared site library site offers no Remove to a profile outside the library (issue #2151) | Added | added: `pages/site_detail_page_sharing_test` "a library site offers no Remove to a profile outside the library" |
| `site_edit_page_sharing_test` | a delete before the share rows load still warns about a site shared by name (issue #2151) | Added | added: `pages/site_detail_page_sharing_test` "a site shared by name only warns on delete as a shared site" |
| `site_edit_page_sharing_test` | the sharing field stays locked until the share rows are read (issue #2151) | Added | added: `editing/site_header_card_editor_test` "waits for the share rows, and locks when they cannot be read" |
| `site_edit_page_sharing_test` | the owner can change sharing | Added | added: `editing/site_header_card_editor_test` "the owner can change sharing" |
| `site_edit_page_sharing_test` | a sharing change the repository refuses says who may change it | Pinned | `editing/site_sharing_sitting_test.dart` 'a refused share fails the Save with the sharing message' (refused for the acting profile, nothing written); `shared/widgets/record_editing/record_edit_host_test.dart` 'a refused held write shows its own message'. By design the whole Save now fails; the form saved the site and refused only the share. |
| `site_edit_page_sharing_test` | on the full page, a refused sharing change closes the page and says who may change it instead of Site updated | Form only | Closing on Save and the 'Site updated' snackbar were the form's. A refused Save on the page keeps it unlocked with the message (`pages/site_detail_page_unlock_test.dart` 'a failed save stays unlocked and says so', plus the refusal above). |
| `site_edit_page_sharing_test` | removing hides it for this profile, closes, and Undo restores | Added | added: `pages/site_detail_page_sharing_test` "another profile sees Shared by and removes it from itself (now ends with Undo)" |
| `site_edit_page_sharing_test` | a failed remove stays on the page and says to try again | Pinned | `pages/site_detail_page_sharing_test.dart` 'a failed remove stays on the page and says to try again' |
| `site_edit_page_sharing_test` | a failed Undo keeps the hide, says to try again and offers Undo again | Pinned | `pages/site_detail_page_sharing_test.dart` 'a failed Undo says to try again'. The shared removeSharedItemFromProfile flow is pinned for a trip by `features/trips/presentation/pages/trip_detail_page_sharing_test.dart` 'a failed Undo says to try again and offers Undo again'. |
| `site_edit_page_sharing_test` | a site already hidden here offers Unhide, not Remove (#2679) | Pinned | `pages/site_detail_page_sharing_test.dart` 'a site already hidden here offers Unhide, not Remove (#2679)' |
| `site_edit_page_sharing_test` | an owner whose site changed hands meanwhile is refused | Added | added: `pages/site_detail_page_sharing_test` "an owner whose site changed hands meanwhile is refused" |
| `site_edit_duplicate_test` | saving writes a new site carrying every field of the original | Pinned | editing/site_new_sitting_test.dart "is created with every copied row, features in order" (copy reaches the database) and "its lists are set once the loads settle, and Save waits for them"; pages/site_detail_page_new_test.dart "Save on a duplicate at once creates it with the copy" (name, description, notes). Every field is copied by the `siteSittingFields` loop, whose completeness is pinned by features/dive_sites/data/services/site_edit_save_census_test.dart "every editable column has a sitting field" and editing/site_plain_fields_test.dart "every field writes back what it reads". |
| `site_edit_duplicate_test` | the copy gets the original's types, tags and species | Pinned | editing/site_new_sitting_test.dart "is created with every copied row, features in order" (types, tags, species rows on n1). |
| `site_edit_duplicate_test` | another profile's shared site copies only my own types and tags | Added | added: `editing/site_new_sitting_test` "of another profile's site copies only my own types (tags: its lists are set once the loads settle)" |
| `site_edit_duplicate_test` | a Save before the types load still copies them | Pinned | editing/site_new_sitting_test.dart "its lists are set once the loads settle, and Save waits for them" (session not settled until the prefill is done); editing/site_sitting_start_test.dart "takes a duplicate's lists whole". |
| `site_edit_duplicate_test` | tags that fail to load still let the copy save | Form only | The new page reads the whole source up front (`readSiteDuplicate`); a failed read shows the error instead of a partial copy, pinned by pages/site_detail_page_new_test.dart "a duplicate whose site cannot be read says why". The session lists never read for a copy (`loadNone`), so there is no late tag load to fail. |
| `site_edit_duplicate_test` | the copy gets the original's seascape features | Pinned | editing/site_new_sitting_test.dart "is created with every copied row, features in order". |
| `site_edit_duplicate_test` | the original is left as it was | Added | added: `editing/site_new_sitting_test` "leaves the original as it was" |
| `site_edit_duplicate_test` | cancelling writes nothing and asks nothing | Form only | The "asks nothing" part is reversed by design: a duplicate's copy is put on the sitting as changes, so Cancel asks (pages/site_detail_page_new_test.dart "a duplicate's source goes with its page" taps Cancel then Discard). The "writes nothing" part is pinned for the new-site page by "a seeded name asks before leaving, and nothing is written". |
| `site_edit_duplicate_test` | the copy keeps the original's sharing | Added | added: `editing/site_new_sitting_test` "of my site shared with everyone is shared with everyone" |
| `site_edit_duplicate_test` | my own site's copy is shared with the same profiles by name (issue #2151) | Pinned | editing/site_new_sitting_test.dart "of the diver's own site keeps its sharing with named profiles" and "is created with every copied row, features in order" (stored profile ids {other} on n1). |
| `site_edit_duplicate_test` | another profile's shared site copies as a new site is shared, not as its owner chose | Pinned | editing/site_new_sitting_test.dart "of another profile's or a library site is shared as a new site is". |
| `site_edit_duplicate_test` | a shared library site duplicates as a personal site | Pinned | editing/site_new_sitting_test.dart "of another profile's or a library site is shared as a new site is" (`sharedLibraryId` null, `diverId` me). Name pinned by pages/site_detail_page_new_test.dart "a duplicate opens titled Duplicate, prefilled as changes". |
| `site_edit_duplicate_test` | the page is titled Duplicate Site | Pinned | pages/site_detail_page_new_test.dart "a duplicate opens titled Duplicate, prefilled as changes". |
| `site_edit_duplicate_test` | saving the full-page form returns the copy to its opener | Pinned | pages/site_detail_page_new_test.dart "through go_router, Save leaves with the new id" and "Save creates the site and leaves with its id"; the opener side by pages/site_detail_duplicate_test.dart "on a phone the saved copy opens over the original". The old "Site added" snack bar has no counterpart (the opener opens the copy instead). |
| `site_edit_duplicate_test` | features that fail to copy still return the saved copy, and say so | Form only | Create is now one transaction with the copied rows as held writes, so a failed feature copy leaves nothing rather than a half copy: features/dive_sites/data/services/site_edit_save_service_test.dart "a held write that throws leaves nothing" and pages/site_detail_page_new_test.dart "a Save that fails keeps everything". |
| `site_edit_seed_name_test` | initialName fills the site name field | Added | added: `editing/site_new_sitting_test` "a seed's name is a change of the header block (now asserts the name)" |
| `site_edit_seed_name_test` | a seeded name alone does not prompt to discard on cancel | Form only | Reversed by design (a seed is a change): pages/site_detail_page_new_test.dart "a seeded name asks before leaving, and nothing is written" pins the opposite. |
| `site_edit_seed_name_test` | editing the seeded name still prompts to discard | Pinned | pages/site_detail_page_new_test.dart "a seeded name asks before leaving, and nothing is written" and "through go_router, Cancel with an entry asks, then leaves with nothing". |
| `site_edit_seed_name_test` | fromNewSiteExtra seeds both the name and the location | Pinned | features/dive_sites/domain/models/new_site_seed_test.dart "passes a NewSiteSeed through unchanged"; pages/site_new_routes_test.dart "the new site address opens the page" (seed reaches `SiteDetailPage.newSite`); editing/site_new_sitting_test.dart "a seed's name is a change of the header block" and "a seed's point fills empty place names and the altitude, as changes". |
| `site_edit_seed_name_test` | fromNewSiteExtra still accepts a bare GeoPoint | Pinned | features/dive_sites/domain/models/new_site_seed_test.dart "reads a bare GeoPoint as a location-only seed". |
| `site_edit_seed_location_test` | seeds coordinates and fires geocoding from initialLocation | Added | added: `pages/site_detail_page_new_test` "a seeded point is looked up in the place name language" |
| `site_edit_seed_location_test` | /sites/new maps a GeoPoint extra into initialLocation | Pinned | features/dive_sites/domain/models/new_site_seed_test.dart "reads a bare GeoPoint as a location-only seed" with pages/site_new_routes_test.dart "the new site address opens the page" (`newSitePage(extra)` reads the extra through `NewSiteSeed.fromRouteExtra`, which app_router uses). |
| `site_edit_rules_test` | a new site saved by hand gets the rule's tag | Pinned | pages/site_detail_page_new_test.dart "a pane taken away during Save still runs the rules" (rules run on the created id) and "Back waits while the created site is handed on"; the tag itself by features/rules/presentation/run_rules_after_create_test.dart "a site created by hand gets the site rule's tag". |
| `site_edit_rules_test` | editing an existing site runs no rules | Added | added: `pages/site_detail_page_unlock_test` "saving a stored site runs no rules" |
| `site_edit_suggest_mode_test` | suggest mode shows the note field and Send, never writes the site | Pinned | pages/site_detail_page_reader_test.dart "the reader's bar is titled Suggest changes and saves with Send" and "Send asks for a note when something goes to the owner" (note and proposal, `save.calls` empty); editing/site_reader_send_test.dart "a shared field and notes: the notes are written and the field proposed, the site's field untouched". |
| `site_edit_suggest_mode_test` | sending a suggestion leaves without asking to discard | Added | added: `pages/site_detail_page_reader_test` "Send asks for a note when something goes to the owner (now asserts the sitting ends)" |
| `site_edit_suggest_mode_test` | a library site hides the Share with all profiles toggle | Pinned | editing/site_header_card_editor_test.dart "not offered for a library site"; the role-gated library delete by pages/site_detail_library_actions_test.dart "an editor gets Edit and a library delete dialog". |
| `site_edit_suggest_mode_test` | a reader reaching the plain edit route still only suggests | Pinned | pages/site_detail_page_reader_test.dart "?suggest=1 opens the sitting a reader may have" (the edit redirect drops the query, so plain and ?suggest=1 land the same) with pages/site_detail_page_unlock_test.dart "an old edit address opens the site unlocked". |
| `site_edit_suggest_mode_test` | a reader keeps their own notes without suggesting them | Pinned | pages/site_detail_page_reader_test.dart "Send with only notes asks nothing and says saved privately"; editing/site_reader_send_test.dart "notes only: saved privately, nothing proposed". |
| `site_edit_suggest_mode_test` | an editor reaching the edit route edits the site | Pinned | pages/site_detail_page_reader_test.dart "?suggest=1 opens the sitting a editor may have" and "an editor sees the lock". |
| `site_edit_suggest_mode_test` | without the library on this device nothing is queued | Pinned | pages/site_detail_page_reader_test.dart "a library not connected here offers no unlock" and "a library gone from the store at Send saves nothing". |
| `site_edit_type_tags_test` | an existing site shows its types selected | Pinned | editing/site_collection_card_editors_test.dart "tapping a type chip holds it and dots the header" (the stored type is in the held selection alongside the new pick; chip `selected` derives from that set). |
| `site_edit_type_tags_test` | a pick made before the stored types load is kept | Form only | The header holds the chips back until the types are read (`sittingListPending`), so no pick can precede the load: editing/site_sitting_load_on_open_test.dart "a list not read yet holds the editor back, and a failed read offers to read again". |
| `site_edit_type_tags_test` | saving writes the chosen types | Pinned | editing/site_classification_sitting_test.dart "types write only the difference"; editing/site_collection_card_editors_test.dart "tapping a type chip holds it and dots the header". |
| `site_edit_type_tags_test` | a hidden type the site has stays offered, even once unticked (#401) | Added | added: `editing/site_collection_card_editors_test` "a hidden type the site has stays offered, even once unticked" |
| `type_tags_section_test` | shows every type, built-ins translated, custom by name | Pinned | features/site_types/presentation/site_type_display_test.dart "every built-in slug has a translated name" and "a custom type shows its own name, even with a built-in slug" (chips use `localizedName`); editing/site_collection_card_editors_test.dart "tapping a type chip holds it and dots the header" (custom chips offered). |
| `type_tags_section_test` | toggling a type chip reports the new selection | Added | added: `features/dive_sites/presentation/widgets/edit_sections/site_type_chips_test` "ticking and unticking a chip reports the new selection" |
| `type_tags_section_test` | the manage link appears when a handler is given | Added | added: `features/dive_sites/presentation/widgets/edit_sections/site_type_chips_test` "the manage link shows only with a handler, and runs it" |
| `type_tags_section_test` | Browse picks from the site tags, as dive edit does | Added | added: `editing/site_collection_card_editors_test` "the card picks from the site tags" |
| `type_tags_section_test` | types and tags are two rows, with one divider between | Form only | The Type & Tags FormSection is gone: types sit in the header block and tags in their own card. |
| `type_tags_section_test` | both sub-headers use the section overline style | Added | added: `features/dive_sites/presentation/widgets/edit_sections/site_type_chips_test` "the manage link rides the types overline, not the chips" |
| `type_tags_section_test` | chips and the tag field are inset from the card edge | Form only | The FormSection card edge is gone. The tag field's own inset (14, 14, 12) stays pinned by features/tags/presentation/widgets/tag_form_block_test.dart "heads the tag field with an overline carrying Browse". |
| `type_tags_section_test` | hidden built-in types leave the chips | Added | added: `features/dive_sites/presentation/widgets/edit_sections/site_type_chips_test` "hidden built-in types leave the chips" |
| `type_tags_section_test` | a hidden type the site had stays after it is unticked | Added | added: `features/dive_sites/presentation/widgets/edit_sections/site_type_chips_test` "a hidden type the site had stays after it is unticked" |
| `site_edit_lookup_from_coordinates_test` | sits with the place fields while Location is collapsed | Form only | Pins the old form's layout: Location group collapsed and the button parked in IdentitySection (#4084). The new Location card editor renders PlaceLookupRow inside the same card as the coordinates and place names, so there is no collapsed group to escape. |
| `site_edit_lookup_from_coordinates_test` | the button is disabled and says why without coordinates | Added | added: `editing/site_location_lookup_test` "Look up waits for coordinates and says why" |
| `site_edit_lookup_from_coordinates_test` | typed coordinates enable the button on an edited form | Added | added: `editing/site_location_lookup_test` "Look up waits for coordinates and says why" |
| `site_edit_lookup_from_coordinates_test` | shows progress on the button while the lookup runs | Added | added: `editing/site_location_lookup_test` "a running lookup shows its progress, then fills the names" |
| `site_edit_lookup_from_coordinates_test` | drops the answer when the coordinates changed meanwhile | Added | added: `editing/site_location_lookup_test` "an answer for a position the site has left is dropped" |
| `site_edit_lookup_from_coordinates_test` | fills the empty fields and saves them | Pinned | loc card "Look up asks before replacing differing names" (empty country filled from the lookup) plus rules "fill only empty names" (country, city, body of water filled). The write of those fields is pinned by test/features/dive_sites/presentation/editing/site_plain_fields_test.dart "every field writes back what it reads". |
| `site_edit_lookup_from_coordinates_test` | a geocoded country saves the geocoder code | Pinned | rules "a written country keeps its code" (applyPlaceLookup sets siteCountryCodeField to BZ); siteCountryCodeField round trip in site_plain_fields_test.dart "every field writes back what it reads". |
| `site_edit_lookup_from_coordinates_test` | a hand edit after the lookup re-reads the text | Pinned | loc card "a typed country carries its code" and "a country that names none carries no code". |
| `site_edit_lookup_from_coordinates_test` | offers to replace when nothing was empty and values differ | Pinned | loc card "Look up asks before replacing differing names" (dialog l.diveSites_edit_lookupReplace_title shows; Replace writes the found region) plus rules "differingPlaceValues lists only found values that differ" (identical values are not listed). |
| `site_edit_lookup_from_coordinates_test` | Keep leaves the fields alone | Added | added: `editing/site_location_lookup_test` "one press fills the blanks and asks only about the names that differ" |
| `site_edit_lookup_from_coordinates_test` | one press fills blanks and offers replacements together | Added | added: `editing/site_location_lookup_test` "one press fills the blanks and asks only about the names that differ" |
| `site_edit_lookup_from_coordinates_test` | Keep holds the differing value but not the filled blanks | Added | added: `editing/site_location_lookup_test` "one press fills the blanks and asks only about the names that differ" |
| `site_edit_lookup_from_coordinates_test` | says so when every detail already matches | Added | added: `editing/site_location_lookup_test` "says so when every name already matches" |
| `site_edit_lookup_from_coordinates_test` | says so when nothing was found | Added | added: `editing/site_location_lookup_test` "says so when nothing was found" |
| `site_edit_lookup_from_coordinates_test` | reports an unreachable geocoder | Added | added: `editing/site_location_lookup_test` "says so when the geocoder is unreachable" |
| `site_edit_fill_location_test` | Use my location fills town and body of water | Pinned | loc card "Use my location fills the position and the empty names" (position and country) plus rules "moveSiteTo sets the position and fills empty names" and "fill only empty names" (city and body of water filled). |
| `site_edit_fill_location_test` | Use my location never overwrites a filled field | Pinned | rules "fill only empty names" (a set region stays) with moveSiteTo using overwrite: false, pinned by rules "moveSiteTo sets the position and fills empty names". |
| `site_edit_fill_location_test` | seeding from a dive fills town and body of water | Pinned | new sitting "a seed's point fills empty place names and the altitude, as changes" (seeded point fills the empty names through applyPlaceLookup) and "a typed country survives a late lookup, and Save waits for it". |
| `site_edit_fill_location_test` | Use my location reports an unreachable geocoder | Added | added: `editing/site_location_lookup_test` "Use my location with the geocoder unreachable keeps the position and says why the names stay empty" |
| `site_edit_language_test` | seeding a new site geocodes in the place name language | Added | added: `pages/site_detail_page_new_test` "a seeded point is looked up in the place name language" |
| `site_edit_altitude_autofill_test` | seeded coordinates fill an empty altitude field | Pinned | new sitting "a seed's point fills empty place names and the altitude, as changes" (altitude card changed for 120 m) plus rules "fills an empty altitude a second later" (the one-second wait) and test/features/dive_sites/presentation/editing/site_new_sitting_test.dart "the starter cards, and Altitude for a point". |
| `site_edit_altitude_autofill_test` | a failed lookup leaves altitude empty | Added | added: `editing/site_location_rules_test` "a failed lookup leaves the altitude empty and the card clean" |
| `site_edit_altitude_autofill_test` | no coordinates means no lookup | Pinned | rules "is not asked for a site with an altitude or no position" (foundAltitude makes no request without a position, which is what the Altitude card asks on open). |
| `site_edit_entry_method_test` | the access section shows entry and exit method rows | Added | added: `editing/site_access_card_editors_test` "the card shows the entry and exit method rows" |
| `site_edit_entry_method_test` | an existing site seeds both pickers | Added | added: `editing/site_access_card_editors_test` "a site's every entry and exit method shows on its row" |
| `site_edit_entry_method_test` | ticking two entry methods shows both on the row (#2054) | Pinned | test/shared/widgets/forms/enum_multi_picker_row_test.dart "ticking reports the selection in declaration order" and "a selection shows the names joined in order" (the row the access card uses). The card's onChanged to session wiring is covered by the GAP row for "saving stores every ticked method". |
| `site_edit_entry_method_test` | ticking exit methods shows them on the exit row | Pinned | Same as above: enum_multi_picker_row_test.dart "ticking reports the selection in declaration order" and "a selection shows the names joined in order". |
| `site_edit_entry_method_test` | an existing site seeds every listed method | Added | added: `editing/site_access_card_editors_test` "a site's every entry and exit method shows on its row" |
| `site_edit_entry_method_test` | saving stores every ticked method | Added | added: `editing/site_access_card_editors_test` "ticking methods holds every one, in the list's order" |
| `site_edit_entry_method_test` | a site with only an entry method still summarises | Pinned | test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart "the access card renders when entry method is the only field" plus site_plain_fields_test.dart "hasAccessInfo is any of the access values". |
| `site_edit_entry_suggestion_test` | the chip appears when both fields are empty | Pinned | access card "the entry suggestion fills both methods on a tap" (finds and taps the ActionChip on an empty site). Its pair label text is not asserted; see the entry-only GAP row. |
| `site_edit_entry_suggestion_test` | the chip is absent when entry method is already set | Pinned | access card "no entry suggestion once a method is set". |
| `site_edit_entry_suggestion_test` | the chip is absent when there is no suggestion | Added | added: `editing/site_access_card_editors_test` "no suggestion offers no chip" |
| `site_edit_entry_suggestion_test` | tapping the chip fills both fields | Pinned | access card "the entry suggestion fills both methods on a tap" (both fields set, chip gone). |
| `site_edit_entry_suggestion_test` | an exit-less suggestion uses the entry-only phrasing | Added | added: `editing/site_access_card_editors_test` "a suggestion with no exit names the entry alone" |
| `site_edit_locale_numbers_test` | comma decimals typed into the depth fields are stored (fr) | Added | added: `editing/site_measure_card_editors_test` "comma decimals typed into the depth rows are held (fr)" |
| `site_edit_locale_numbers_test` | saving an untouched site under a grouping-dot locale changes nothing (de) | Added | added: `editing/site_measure_card_editors_test` "opening and leaving the rows changes nothing (de)" |

