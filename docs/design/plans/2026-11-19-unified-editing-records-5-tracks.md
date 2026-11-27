# Unified editing, phase 3, plan 5: GPS tracks and underwater tracks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A GPS track and an underwater track each open locked and edit in place, every card held in one sitting written as one History entry, behind `kUnlockRecordEditing` (issue #4527, phase 3). That includes what each page writes at once today: a GPS track's trim and reset trim; an underwater track's rename, dive link, relink and unlink, site, device and the align page's correction. Neither type has a form, and neither gets a new-record page (tracks are created only by import).

**Architecture:** As plan 3: each page's state mixes in `RecordEditHost`, its cards are `EditCard`s keyed by the card ids plan 1 shipped (`GpsTrackCardId { header, trim }`, `NavTrackCardId { header, dive, site, device, correction }`), and each type gets a save service on `writeRecordSitting`. Both repositories gain one writer for the columns the pages edit, so a sitting writes only those. The underwater track's dive link is a field whose write goes through the repository's existing `link`, `relink` and `unlink` after the row, so linking keeps its owner, primary and inheritance rules and its writes to sibling routes land in the same History entry. The align page takes the track page's sitting when pushed during one (`pushRecordSatellite`), reads only otherwise, and hands its correction back with Done. The 3D views draw a held correction through a small preview registry, without writing it.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), drift, go_router, `flutter gen-l10n`.

**Spec:** [docs/design/specs/2026-11-18-unified-editing-phase-3-records-design.md](../specs/2026-11-18-unified-editing-phase-3-records-design.md), sections "Design: GPS tracks and underwater tracks", "Design: rules every phase 3 type follows", "Values shown nowhere today" (a GPS track's name), "Calls made in this note" and "Testing"; on top of plans 1 to 3 ([records-1](2026-11-19-unified-editing-records-1-shared.md), [records-2](2026-11-19-unified-editing-records-2-documents-species.md), [records-3](2026-11-19-unified-editing-records-3-buddies-centres-certifications.md)).

## Questions for Eric

The note's calls on these two types are not confirmed. The plan is written to the recommended answer of each; a different answer changes only the task named.

1. **The align page and the track's lock.** **Recommended:** it follows the track's lock, with no lock of its own, as the note says. Opened from a locked track page (or straight from its address), it reads only: the map and the current alignment show, every control is off, Save is gone, and its 3D button opens the saved alignment. Pushed during the track's sitting, Save becomes Done: Done hands the page's correction to the sitting as a change of Correction and goes back; the page's Cancel (and Back) discards what was tweaked on it, as today and as the buddy's certification dialog does. The other way: a lock of its own, like the passports, where Unlock on the align page starts the track's sitting there. (Task 7.)
2. **GPS trim.** **Recommended:** a held change, written at Save, as the note says. The Trim card's editor holds the scrubber and Reset trim; while unlocked the stats, the map and the dive pins show the held trim. The other way: trim keeps writing at once, since it never loses a fix. (Tasks 1, 2.)
3. **GPS split and underwater Update from file.** **Recommended:** whole-record operations, as the note says: they need the unlock, keep their warnings, act at once, and are off while the sitting has unsaved changes. Split ends the page (the track is replaced by two), as today. (Tasks 3, 6.)
4. **Delete on the GPS page.** **Recommended:** the menu gains Delete, a whole-record operation with the Tracks list's confirmation, as the underwater page already has. The other way: Delete stays on the Tracks list only. (Task 3.)
5. **The 3D views during a sitting.** The note says they show a held correction without writing it. Today the align page's 3D button saves first because the 3D views read the route from storage, and the seascape of a route at a site draws every route of that site from storage. **Recommended:** a preview registry (Task 8): while the sitting (or the align page in it) holds a correction the store does not, the track's 3D preview and its own seascape draw that correction; a route at a site opens its own seascape, not the site's, until the correction is saved. The other way, smaller: while a correction is held, the 3D buttons show the saved alignment with a line saying so ("Save to see this alignment in 3D"), and the align page's 3D button is off.

## Calls made in this plan, for Eric to check

1. **The dive another device moved meanwhile.** When the diver changes the track's dive in a sitting and another device has linked the track elsewhere since, Save moves it from wherever it is now to the diver's choice (the track's own field: the last choice wins). The dive page's route card does the opposite (it skips a route moved meanwhile and says so), because there the route is another record.
2. **Linking's inherited site shows after Save.** Linking a route with no site and no anchor gives it the dive's site and anchor; the repository does this at Save, as today. Until then the Site card shows the sitting's site. A site picked in the same sitting is written first, so linking inherits nothing over it.
3. **A site change that moves the anchor is a change of Correction too.** The anchor-follows-site rule (`navTrackAnchorChangeForSite`) runs when the site is picked, against the sitting's anchor and the sitting's old site, and sets the anchor in the sitting: both Site and Correction show their dots.
4. **Calculated parts show the sitting.** While unlocked, the GPS stats header, map and dive pins follow the held trim; the underwater map follows the held anchor and correction. The underwater stats and recorder card are unaffected by any edit.
5. **The trim scrubber sets the trim when a drag ends**, not on every frame (the stats header walks up to 20,000 points), and there is no Apply. Opening the Trim editor sets nothing, so an editor opened and closed untouched changes nothing (today's panel had to seed its values to avoid writing an empty trim).
6. **The align page's "same as start" suggestion** stays a starting suggestion on the page: it reaches the sitting only through Done.
7. **The GPS header block.** Locked, it shows the name when there is one and nothing otherwise; unlocked, it always shows (an unnamed track's name field empty), rather than waiting in the strip under the label "GPS track". The bar keeps its fixed title. A blank name stores null.
8. **The Trim card** shows the trim's start and end times when the track is trimmed, and is offered in the strip when it is not.
9. **The colour mode selector** stays in the locked bar; unlocked, it shows under the strip (`belowStrip`), since the editing bar has no bottom row.
10. **No edit address or `?mode=edit` for tracks**: nothing opens a track unlocked, and plan 11 makes no new tracks. The three track routes (GPS, underwater, align) get `onExit: confirmLeaveRecordSitting`.
11. **The delete confirmation** (`_DeleteTrackDialog` in `tracks_page.dart`) moves to a shared widget used by the list and both pages, and what the list does after a delete (deselect the map's pick, forget the opened track) becomes one helper both pages call too.
12. **Moving the align page and the 3D preview onto `pushRecordSatellite`** (a `MaterialPageRoute`) from the track page, so the sitting travels with them; their go_router addresses stay for links and read only.

## Global Constraints

- Plan 4 (courses, PR #4772) is open in parallel. **The one file both plans touch is `lib/core/router/app_router.dart`**: this plan changes only the three track routes there. This plan changes nothing under `lib/shared/` beyond what Task 8 adds outside it. Merge origin/main before each task with a merge (never a rebase or a force-push), adapt to any renamed names, and run a whole-repo `flutter analyze` after each merge.
- Built on the names already shipped: `RecordEditHost` (`joinedSitting`, `pushSatellite`, `editScaffold(unlockedActions:)`, `belowStrip`, `followStored`, `saveAndReport`), `pushRecordSatellite`, `RecordEditScope`, `EditSession` (`applyTo`, `holdChange`, `holdWrite`, `track`, `remember`, `recall`), `EditCard`, `RecordCardFrame`, `RecordCardPencil`, `RecordCardFade`, `AddStripEntry`, `recordOperationRunnerOf`, `recordOperationBlockOf`, `recordOperationReason`, `writeRecordSitting`, `confirmLeaveRecordSitting`, `GpsTrackCardId`, `NavTrackCardId`, the History labels for `gps_tracks` and `nav_tracks` (plan 1).
- With `kUnlockRecordEditing` false (the default) both pages, the align page, the 3D views and the Tracks list look and behave exactly as today: no existing test changes its expectations. Each page takes `unlockEditing` defaulting to the switch.
- A locked page writes nothing on any tap. History labels: `record_edit:gps_tracks:<id>:<cards>`, `record_edit:nav_tracks:<id>:<cards>`, source "manual". Writes to sibling routes (primary) in a sitting are in that one entry.
- Only what changed is written: each sitting's changes are applied to the record as stored at Save (`EditSession.applyTo`), and each type has a field census test. `GpsTrack.copyWith` and `NavTrack.copyWith` cannot clear a field, so each type's fields build the entity through one private `_with` that copies every field, as plan 3 did.
- Writes stamp `updatedAt` and call `markRecordPending` as the existing writers do (a GPS track's `updatedAt` alone does not replicate).
- Units follow the active diver's settings; times on the Trim card use the app's time format on the track's wall-clock-as-UTC values, as the scrubber does.
- New strings, if a task finds one missing (expected: at most the Trim card's two row labels and Task 8's alternative line), go into all eleven ARB files, translated, then `flutter gen-l10n`.
- `nav_track_detail_page.dart` (763 lines) does not pass 800: editing goes in a `part`, and the page's private card widgets move to `presentation/widgets/nav_track_detail_cards.dart`.
- Never use em-dashes, and never en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, commits or the PR. Commits, the PR and files follow the repository guide's Attribution section.
- Imports grouped dart, flutter, packages, local. `dart format` changed files before each commit. Anything acting after an `await` checks `mounted` and reads `ref` and `context` before its first `await`.
- Test runs: only the test FILES a task writes or changes, by path. Never a folder, never the whole suite, never `test/architecture/` or `test/shared/` by hand: the pre-push hook runs them.
- Never `--build-filter` build_runner. Never let a debug build open `~/Documents/Submersion/submersion.db` or Dropbox sync; screenshots come from headless widget goldens.

## Review Focus

1. **The dive changed in a sitting, then Cancel.** The route stays on its dive, its owner, link mode and primary unchanged, and no sibling route is promoted. Pinned in Task 5.
2. **A site picked and a dive linked in one sitting.** After Save the route keeps the picked site and its anchor; linking inherited nothing over them; one History entry holds both. Pinned in Task 4.
3. **The align page in a sitting: Done, then the track's Cancel.** The stored correction is unchanged; the align page's own Cancel leaves the sitting's correction as it was. Pinned in Task 7.
4. **A trim saved, then the map.** The map draws the trimmed track at once after Save, not the cached pre-trim polyline (the geometry cache is evicted after the commit, as `trimTrackProvider` does). Pinned in Task 2.
5. **Split from a clean sitting.** The two new tracks exist, the page pops with no "unsaved changes" prompt, and the deleted track's sitting leaves nothing behind. Pinned in Task 3.

## Preparation

- [ ] The worktree is initialised (`git submodule update --init --recursive`, `flutter pub get`); generate code unfiltered in the background if fresh: `dart run build_runner build --delete-conflicting-outputs`.
- [ ] `git fetch origin main`, merge it, and run `flutter analyze` on the whole repository. Expected: clean.
- [ ] Before any code changes, take the "before" goldens (headless widget tests, switch off): the GPS page with its trim panel open, the underwater page, the align page, at phone and desktop width.
- [ ] This plan is committed on the branch: `docs(editing): phase 3 plan 5, GPS and underwater tracks`.

## File Structure

New, GPS tracks (`lib/features/gps_log/...`):

| File | Responsibility |
| --- | --- |
| `data/services/gps_track_edit_save_service.dart` | `GpsTrackEditSaveService`, provider |
| `presentation/editing/gps_track_edit_fields.dart` | Name and trim fields |
| `presentation/editing/gps_track_edit_cards.dart` | `gpsTrackEditCards`, the header and Trim editors |
| `presentation/pages/gps_track_detail_page_editing.dart` | `part`: the page's use of the host |

New, underwater tracks (`lib/features/nav_track/...`):

| File | Responsibility |
| --- | --- |
| `data/services/nav_track_edit_save_service.dart` | `NavTrackEditSaveService`, provider |
| `presentation/editing/nav_track_edit_fields.dart` | Name, dive, site, device, anchor and correction fields; the site pick rule |
| `presentation/editing/nav_track_edit_cards.dart` | `navTrackEditCards` and the five editors |
| `presentation/widgets/nav_track_detail_cards.dart` | The page's title, stats, link, site and equipment cards, moved out of the page |
| `presentation/pages/nav_track_detail_page_editing.dart` | `part` |
| `presentation/providers/nav_track_preview_provider.dart` | The 3D preview registry (Task 8) |

New, tracks (`lib/features/tracks/presentation/`): `widgets/delete_track_dialog.dart` (the moved dialog and the after-delete helper).

Modified: `gps_track_detail_page.dart`, `gps_track_map_providers.dart` (the eviction made callable), `track_timeline_scrubber.dart` (`onChangeEnd`), `gps_track_repository.dart`, `nav_track_detail_page.dart`, `nav_track_align_page.dart`, `nav_track_align_controls_panel.dart`, `nav_track_correction_card.dart`, `nav_track_repository.dart`, `nav_track_3d_providers.dart`, `nav_track_scene_providers.dart`, `nav_track_seascape_page.dart`, `tracks_page.dart`, `app_router.dart`.

No form is replaced, so there is no form test accounting. The existing page tests (`gps_track_detail_page_test.dart`, `gps_track_edit_mode_test.dart`, `gps_track_export_menu_test.dart`, `gps_track_detail_markers_test.dart`, `nav_track_detail_page_test.dart`, `nav_track_align_page_test.dart`, `nav_track_3d_page_test.dart`, `nav_track_seascape_page_test.dart`, `nav_track_seascape_page_routing_test.dart`, `tracks_page_test.dart`) run with the switch off and keep every expectation; each task names the ones it must leave green.

---

### Task 1: The GPS save service and fields

**Files:**
- Create: `lib/features/gps_log/data/services/gps_track_edit_save_service.dart`, `lib/features/gps_log/presentation/editing/gps_track_edit_fields.dart`
- Modify: `lib/features/gps_log/data/repositories/gps_track_repository.dart`
- Test: `test/features/gps_log/data/services/gps_track_edit_save_service_test.dart`, `test/features/gps_log/presentation/editing/gps_track_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `GpsTrackRepository.writeEditedColumns(String id, {required String? name, required int? trimStartTime, required int? trimEndTime}) -> Future<void>`: writes those three, `updatedAt`, `markRecordPending`, `notifyLocalChange`; nothing else (points, window and source untouched).
  - `class GpsTrackEditSaveService { GpsTrackEditSaveService(GpsTrackRepository tracks); Future<({GpsTrack before, GpsTrack after})?> save({required String trackId, required GpsTrack Function(GpsTrack stored) apply, required Iterable<String> changedCardIds}) }` over `writeRecordSitting<GpsTrack>(table: 'gps_tracks', read: () => getTrack(id, includePoints: false), apply: <apply, but the stored instance itself when name and both trim bounds equal stored's>, write: (_, m) => writeEditedColumns(...))`. `GpsTrack` has no `==`; returning `stored` is how an unchanged Save writes nothing. `gpsTrackEditSaveServiceProvider`.
  - Fields: card `header`: `gpsTrackNameField` (`String?`, blank stores null); card `trim`: `gpsTrackTrimField` (`({int? startMs, int? endMs})`, one field so Reset trim is one change).
  - `final evictGpsTrackProvider = Provider((ref) => (String id) => _evictTrack(ref, id))` in `gps_track_map_providers.dart`, beside `trimTrackProvider`, so the page can drop the track's cached geometry after a Save.

- [ ] **Step 1: Write the failing tests** (test database; track `t1`, 100 fixes, name `Morning swim`, no trim):
  - Service: `writes a trim as one History entry` (one operation, label `record_edit:gps_tracks:t1:trim`, columns set, row pending for sync); `a rename and a trim are one entry`; census `a name changed underneath survives a trim` and `a trim changed underneath survives a rename`; `the points blob is untouched` (byte equal before and after); `unchanged returns null and writes nothing` (no operation, `updatedAt` unchanged); `a deleted track throws StateError`.
  - Fields: `a blank name stores null`; `Reset trim sets both bounds to null in one change`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `gps_track_trim_test.dart`, `gps_track_sync_pending_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(gps-log): save a GPS track's editing sitting as one History entry`.

### Task 2: The GPS page on the host

**Files:**
- Create: `gps_track_edit_cards.dart`, `lib/features/gps_log/presentation/pages/gps_track_detail_page_editing.dart` (part)
- Modify: `gps_track_detail_page.dart`, `track_timeline_scrubber.dart`, `app_router.dart` (the GPS route's `onExit` only)
- Test: `test/features/gps_log/presentation/pages/gps_track_detail_page_unlock_harness.dart`, `gps_track_detail_page_unlock_test.dart`, `test/features/gps_log/presentation/editing/gps_track_edit_cards_test.dart`, `test/features/gps_log/track_timeline_scrubber_test.dart` (existing; add a case)

**Interfaces:**
- Produces:
  - `TrackTimelineScrubber({..., void Function(int startMs, int endMs)? onChangeEnd})`, fired once when a drag ends.
  - `gpsTrackEditCards`: `header` (`GpsTrackHeaderCardEditor`: one text field; locked view a one-line card with the name, built only when named; never in the strip, Call 7); `trim` (`GpsTrackTrimCardEditor`: `TrackTimelineScrubber(mode: range)` over the raw span, starting at the sitting's bounds, setting `gpsTrackTrimField` on `onChangeEnd`, and Reset trim; locked view the trim's start and end times; `isEmpty`: no bounds, offered in the strip).
  - `GpsTrackDetailPage({required String trackId, bool unlockEditing = kUnlockRecordEditing})` on `RecordEditHost<GpsTrackDetailPage, GpsTrack>`: `followStored(gpsTrackDetailProvider(id))`; the header block and Trim card sit between the stats header and the map; the stats header, the map's fallback points and the dive pins read `shownRecord(stored)` (the held trim; pins from `GpsTrackMatcher.trackCovering` over `divesProvider`, Call 4), and while a trim is held the map draws the held track's `effectivePoints` (the unsimplified list it already draws while simplifying); the colour selector moves to `belowStrip` while unlocked (Call 9). `saveSitting` saves through Task 1, then calls `evictGpsTrackProvider`. With the switch on, the menu's Trim and Reset trim go; the GPS route gets `onExit: confirmLeaveRecordSitting`.
- Consumes: Task 1.

- [ ] **Step 1: Write the failing tests**: scrubber: `onChangeEnd fires once per drag`. Editors: `the trim editor sets nothing until a drag ends`; `Reset trim is a change of Trim`. Page: `with the switch off there is no lock and the menu offers Trim`; `locked, no tap writes`; `a rename and a trim in one sitting save as one entry and lock`; `while a trim is held the stats show the trimmed span`; `a saved trim redraws the map at once` (Review Focus 4: the geometry provider for the track is invalidated after Save, the drawn points are the trimmed ones); `an untrimmed track offers Trim in the strip`; `the header block shows unlocked even when unnamed`; `Cancel with changes asks first`; `leaving the route with changes asks first`.
- [ ] **Step 2:** Run the four files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `gps_track_detail_page_test.dart`, `gps_track_edit_mode_test.dart`, `gps_track_export_menu_test.dart`, `gps_track_detail_markers_test.dart`, `gps_track_geometry_refresh_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(gps-log): unlock a GPS track to rename and trim it in place, behind a switch`.

### Task 3: GPS split and delete as whole-record operations

**Files:**
- Create: `lib/features/tracks/presentation/widgets/delete_track_dialog.dart`
- Modify: `tracks_page.dart`, `gps_track_detail_page.dart`, `gps_track_detail_page_editing.dart`
- Test: `gps_track_detail_page_unlock_test.dart`, `test/features/tracks/presentation/widgets/delete_track_dialog_test.dart`, `test/features/tracks/presentation/pages/tracks_page_test.dart` (existing, unchanged)

**Interfaces:**
- Produces:
  - `Future<bool> confirmDeleteTrack(BuildContext context, TrackListItem item)` (today's `_DeleteTrackDialog`, moved) and `void forgetDeletedTrack(WidgetRef ref, TrackListItem item)` (deselect the map section's pick if it is this track, then `forgetOpenedTrack`); `tracks_page.dart` uses both.
  - With the switch on, the GPS menu shows Split and Delete under the operations caption (`recordOperationReason`): off while locked ("Unlock to use these") or while the sitting has unsaved changes. Split opens today's split panel; its confirm runs `splitTrackProvider` through `recordOperationRunnerOf` and pops. Delete asks `confirmDeleteTrack`, runs `deleteTrackProvider` through the runner, calls `forgetDeletedTrack`, and pops. Share and save as GPX or KML and History work locked.
- Consumes: Task 2.

- [ ] **Step 1: Write the failing tests**: dialog: `confirms and cancels` (moved from the list's cases, now on the widget). Page: `locked, Split and Delete are off under "Unlock to use these"`; `with unsaved changes they are off`; `split from a clean sitting creates two tracks and pops without asking` (Review Focus 5); `delete asks, deletes, forgets the track and pops`; `export works locked`.
- [ ] **Step 2:** Run the two new files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, `tracks_page_test.dart` and `gps_track_edit_mode_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(gps-log): split and delete a GPS track as whole-record operations`.

### Task 4: The underwater track save service and fields

**Files:**
- Create: `lib/features/nav_track/data/services/nav_track_edit_save_service.dart`, `lib/features/nav_track/presentation/editing/nav_track_edit_fields.dart`
- Modify: `nav_track_repository.dart`
- Test: `test/features/nav_track/data/services/nav_track_edit_save_service_test.dart`, `test/features/nav_track/presentation/editing/nav_track_edit_fields_test.dart`

**Interfaces:**
- Produces:
  - `NavTrackRepository.writeEditedColumns(String routeId, {required String? name, required String? siteId, required String? equipmentId, required String? deviceName, required NavTrackCorrection correction}) -> Future<void>`: those columns (the correction's as `updateCorrection` writes them), `updatedAt`, `_markPending`. Never the link columns.
  - `class NavTrackEditSaveService { NavTrackEditSaveService(NavTrackRepository routes); Future<({NavTrack before, NavTrack after})?> save({required String routeId, required NavTrack Function(NavTrack stored) apply, required Iterable<String> changedCardIds}) }` over `writeRecordSitting<NavTrack>(table: 'nav_tracks', read: () => getById(id, includePoints: false), write: (stored, merged) async { writeEditedColumns(...); <then, when merged.diveId != stored.diveId: unlink(id, onlyFromDiveId: stored.diveId) when merged's is null; link(id, merged.diveId!, linkMode: manual) when stored's is null; else relink(id, fromDiveId: stored.diveId!, toDiveId: merged.diveId!, linkMode: manual)> })`. Row first, so a site picked in the sitting is in place before `link` decides whether to inherit (Call 2). `navTrackEditSaveServiceProvider`.
  - Fields: card `header`: `navTrackNameField` (`String?`, blank null); card `dive`: `navTrackDiveField` (`String?`); card `site`: `navTrackSiteField` (`String?`); card `device`: `navTrackDeviceField` (`({String? equipmentId, String? deviceName})`, one field); card `correction`: `navTrackAnchorField` (`GeoPoint?`) and `navTrackCorrectionField` (the rest of `NavTrackCorrection`: end mode and point, trust, heading, scale). Two fields, so a site pick that moves only the anchor leaves a correction changed underneath alone.
  - `void pickNavTrackSite(EditSession<NavTrack> session, DiveSite site, {required GeoPoint? oldSiteLocation})`: sets the site field and, when `navTrackAnchorChangeForSite(sittingAnchor, oldSiteLocation, site.location).write`, the anchor field (Call 3). The rule functions stay where they are.
- Consumes: `writeRecordSitting`, the repository's `link`, `relink`, `unlink`.

- [ ] **Step 1: Write the failing tests** (test database; route `r1` linked to dive `d1` with sibling route `r2` not primary, site `s1` at a pin, anchor on that pin):
  - Service: `a rename is one History entry`; census, one assertion per column `writeEditedColumns` writes, and `the link columns are never written by a rename`; `unlinking promotes the sibling in the same entry` (`r2` becomes primary, one operation); `relinking moves the route to the new dive`; `a dive another device moved meanwhile goes to the diver's choice` (Call 1); `a site picked and a dive linked together keep the picked site` (Review Focus 2: route with no site, pick `s2`, link `d3` whose site is `s3`: site `s2`, one entry); `linking a route with no site inherits the dive's site and anchor`; `unchanged returns null`; `a deleted route throws`.
  - Fields: `a site pick moves an anchor that followed the old pin`; `a site pick leaves a hand-placed anchor`; `a site with no pin clears a following anchor`; `a blank name stores null`; `the device clears both values together`.
- [ ] **Step 2:** Run the two files. Expected: fail to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `nav_track_repository_test.dart`, `nav_track_repository_fold_links_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(nav-track): save an underwater track's editing sitting as one History entry`.

### Task 5: The underwater track page on the host

**Files:**
- Create: `nav_track_edit_cards.dart`, `lib/features/nav_track/presentation/widgets/nav_track_detail_cards.dart`, `lib/features/nav_track/presentation/pages/nav_track_detail_page_editing.dart` (part)
- Modify: `nav_track_detail_page.dart`, `nav_track_correction_card.dart`, `app_router.dart` (the underwater route's `onExit` only)
- Test: `test/features/nav_track/presentation/pages/nav_track_detail_page_unlock_harness.dart`, `nav_track_detail_page_unlock_test.dart`, `test/features/nav_track/presentation/editing/nav_track_edit_cards_test.dart`

**Interfaces:**
- Produces:
  - `nav_track_detail_cards.dart`: today's `_TitleCard`, `_StatsCard`, `_LinkCard`, `_SiteCard`, `_EquipmentCard`, `_ActionCard`, made public with an optional action (null: the card shows no action, its tap through to the dive, site or item stays). No behaviour change with the switch off.
  - `navTrackEditCards`: `header` (name field; locked view the title card), `dive` (editor: the linked dive's label, Choose or Change dive opening `showNavTrackDiveChoiceSheet` with today's preselection, and Unlink when one is set), `site` (Change or Choose site through `pickOrCreateSite`, then `pickNavTrackSite`; a site created there survives Cancel), `device` (`pickNavTrackEquipment`, chosen or cleared), `correction` (editor: the correction summary and Align, pushing the align page with the sitting, Task 7). No card is ever empty: each shows its "none" row, as today.
  - `NavTrackDetailPage` becomes a `ConsumerStatefulWidget({required String trackId, bool unlockEditing = kUnlockRecordEditing})` on `RecordEditHost<NavTrackDetailPage, NavTrack>`: `followStored(navTrackByIdProvider(id))` (not the markers provider, which Task 8 may preview through); the map reads `shownRecord` with the stored markers. Locked with the switch on, the cards show no actions. `unlockedActions`: Align, 3D preview, 3D seascape, the menu. The underwater route gets `onExit: confirmLeaveRecordSitting`.
- Consumes: Task 4.

- [ ] **Step 1: Write the failing tests**: editors: `choosing a dive sets only the dive field`; `unlink clears it`; `a site pick sets site and anchor` (Call 3). Page: `with the switch off there is no lock and Choose dive links at once`; `locked, no tap writes and no card offers an action`; `a rename, a site and a device in one sitting save as one entry and lock`; `the dive changed in a sitting, then Cancel` (Review Focus 1: link, owner, primary of `r1` and `r2` unchanged); `the map follows a held anchor`; `the stats card fades as calculated`; `Cancel with changes asks first`; `tapping the linked dive opens it while locked`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, and `nav_track_detail_page_test.dart`, `nav_track_recorder_card_test.dart` unchanged. Expected: all pass.
- [ ] **Step 5: Commit** `feat(nav-track): unlock an underwater track to edit it in place, behind a switch`.

### Task 6: The underwater track's menu and whole-record operations

**Files:**
- Modify: `nav_track_detail_page.dart`, `nav_track_detail_page_editing.dart`, `nav_track_file_actions.dart` (only if the runner needs its write separated from its questions)
- Test: `nav_track_detail_page_unlock_test.dart`

**Interfaces:**
- Produces: with the switch on, the menu loses Rename and Unlink (now on the Header and Dive cards); Update from file (ENC only) and Delete sit under the operations caption, off while locked or with unsaved changes, and run through `recordOperationRunnerOf`; Delete keeps its confirmation, then `forgetDeletedTrack` (Task 3) and pops; Update from file keeps its file pick, parse error and mismatch warning, and the page follows the rewritten points. History and Export CSV work locked; so do the two 3D buttons.
- Consumes: Tasks 3 and 5.

- [ ] **Step 1: Write the failing tests**: `the menu offers no Rename or Unlink with the switch on`; `locked, Update from file and Delete are off under "Unlock to use these"`; `with unsaved changes they are off`; `unlocked and clean, Delete asks, deletes, promotes the sibling and pops`; `unlocked and clean, Update from file replaces the points and keeps name, link, site and correction`; `Export CSV works locked`.
- [ ] **Step 2:** Run the file. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it and `nav_track_detail_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(nav-track): update from file and delete as whole-record operations`.

### Task 7: The align page follows the track's lock

**Files:**
- Modify: `nav_track_align_page.dart`, `nav_track_align_controls_panel.dart`, `nav_track_detail_page.dart` (the Align button), `nav_track_correction_card.dart` (its tap), `app_router.dart` (the align route's `onExit` only)
- Test: `test/features/nav_track/presentation/pages/nav_track_align_page_unlock_test.dart`, `nav_track_align_page_test.dart` (existing, unchanged)

**Interfaces:**
- Produces: `NavTrackAlignPage({required String routeId, RecordEditController<NavTrack>? joinedSitting, bool unlockEditing = kUnlockRecordEditing})`.
  - Switch off: as today.
  - Switch on, no sitting (from a locked page, or straight from its address): reads only. The map and current alignment show; the start, end, trust, rotation, scale and reset controls and the crosshair are off; Save is gone; the 3D button opens the saved alignment and writes nothing.
  - Switch on, joined: starts from the sitting's anchor and correction (not storage), so a second visit continues the first; "same as start" is proposed as today (Call 6). Done sets `navTrackAnchorField` and `navTrackCorrectionField` from the page's correction and pops; Cancel and Back pop and change nothing. While the sitting ends underneath (saved or cancelled from elsewhere) the page reads only. The 3D button previews the page's correction (Task 8) and writes nothing.
  - The track page's Align button and the Correction editor push it with `pushSatellite((joined) => NavTrackAlignPage(routeId:, joinedSitting: joined))`; locked, Align pushes it with none.
- Consumes: Tasks 4 and 5.

- [ ] **Step 1: Write the failing tests**: `locked, the controls are off and nothing is written`; `opened from its address with the switch on, it reads only`; `joined, it starts from the sitting's correction`; `Done hands the correction to the sitting and writes nothing`; `the align page in a sitting: Done, then the track's Cancel` (Review Focus 3: storage unchanged); `the align page's Cancel leaves the sitting's correction as it was`; `the 3D button writes nothing in a sitting`.
- [ ] **Step 2:** Run the new file. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it and `nav_track_align_page_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(nav-track): the align page joins the track's sitting and reads only when locked`.

### Task 8: The 3D views show a held correction

Written to Question 5's recommended answer. With the other answer, this task instead shows the saved alignment with the line "Save to see this alignment in 3D" while a correction is held, and turns the align page's 3D button off in a sitting.

**Files:**
- Create: `lib/features/nav_track/presentation/providers/nav_track_preview_provider.dart`
- Modify: `nav_track_3d_providers.dart`, `nav_track_scene_providers.dart`, `nav_track_seascape_page.dart`, `nav_track_detail_page.dart` (the two 3D buttons), `nav_track_align_page.dart` (its 3D button)
- Test: `test/features/nav_track/presentation/providers/nav_track_preview_provider_test.dart`, `nav_track_detail_page_unlock_test.dart`, `nav_track_align_page_unlock_test.dart`, `nav_track_3d_page_test.dart` and `nav_track_seascape_page_routing_test.dart` (existing, unchanged)

**Interfaces:**
- Produces:
  - `final navTrackPreviewProvider = NotifierProvider.autoDispose.family<NavTrackPreview, NavTrack?, String>(...)`: `show(NavTrack route)`, `clear()`. `Future<void> pushNavTrack3dWithPreview(BuildContext, WidgetRef, {required NavTrack route, required Widget page})`: registers `route` when its anchor or correction differs from storage, pushes `page`, clears when it pops.
  - `navTrack3dSceneDataProvider` and `navTrackSceneProvider` read `navTrackPreviewProvider(id) ?? navTrackWithMarkersProvider(id)` (markers taken from the stored route). Nothing else reads the registry: the host follows `navTrackByIdProvider`, so a preview never looks like a stored change.
  - `NavTrackSeascapePage` opens its own (standalone) view while a preview is registered, not the site's, since the site's view reads every route from storage.
  - The track page's 3D buttons pass `shownRecord(stored)`; the align page's passes its current correction on the route. Locked, they push as today.
- Consumes: Tasks 5 and 7.

- [ ] **Step 1: Write the failing tests**: provider: `a registered route is what the scene data reads`; `cleared on pop, the scene reads storage again`. Page: `with a held correction the 3D preview draws it and nothing is written`; `a route at a site opens its own seascape while a correction is held`; `without a held change the seascape opens the site's view as today`. Align: `the 3D button previews the page's correction`.
- [ ] **Step 2:** Run the three files. Expected: failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run them, `nav_track_3d_page_test.dart`, `nav_track_seascape_page_test.dart`, `nav_track_seascape_page_routing_test.dart`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(nav-track): the 3D views show a correction held in a sitting`.

### Task 9: Push, open the pull request, track it to green

- [ ] **Step 1:** Merge origin/main once more; whole-repo `flutter analyze`; `dart format` every changed file. Expected: clean.
- [ ] **Step 2:** Push in the background (`git push -u origin HEAD`), touching no `lib/` or `test/` file while it runs. Fix any hook failure in its own commit.
- [ ] **Step 3:** `/code-review xhigh --fix --max-findings all`; fix every valid finding test first; push again.
- [ ] **Step 4:** Screenshots from headless widget-test goldens with the switch on (never `flutter test ... -d macos`): the GPS page locked (before and after) and unlocked with the Trim editor open; the underwater page locked (before and after) and unlocked with the Dive editor open; the align page read only and joined (with Done); light and dark for the unlocked bars; phone and desktop for both pages. Attached through the project's current secret screenshot gist.
- [ ] **Step 5:** `gh pr create` from the template, title `feat(editing): GPS and underwater tracks edit in place, behind a switch`, body with `Refs #4527`, the file shared with plan 4 named, and the screenshots; bind it, turn Auto-fix on, and follow it until every check is green, fixing each failure and review comment as it comes.
