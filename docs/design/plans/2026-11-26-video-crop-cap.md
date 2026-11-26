# Video crop cap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session (never subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep at most 3 synced and 3 file crops per species on a video (plus claimed tracks), trim what is already stored, and let the crop sheet jump to every moment the species was seen.

**Architecture:** A pure ranking rule in `domain/services/video_crop_cap.dart` decides which crops of a video to drop. A small `VideoCropCapper` applies it through `IdentificationCropStore.delete` (tombstoned table rows plus files); the identification service calls it after each scan chunk, after a scan and after a video rename, and a launch step calls it for every video this device analysed. Readiness counts crops per group for tracks, and screens fall back to the largest kept crop of the group.

**Tech Stack:** Flutter, Riverpod 3, Drift, flutter_test.

**Spec:** `docs/design/specs/2026-11-26-video-crop-cap-design.md` (issue #5032)

## Global Constraints

- Cap: 3 named (synced) crops and 3 unnamed (file) crops per (video, group); claimed tracks always keep theirs and do not count.
- Videos only (`MediaIdentification.isTrack`); photos are untouched.
- Rows, decisions, playback labels and track boxes are never changed. Only crops go.
- Only the device that made the run (`MediaIdentificationRun.madeOn(me)`) deletes synced crops; deletes publish tombstones through the existing `IdentificationCropStore.delete`.
- Every user-visible string in all 12 ARB files under `lib/l10n/arb/`, then `flutter gen-l10n`.
- No em-dashes anywhere; files under 800 lines (`media_identification_service.dart` is 770, `video_identification_scan.dart` 768: new code goes in new files).
- Run only the test files you wrote or changed, by path. Never a folder.

## Review Focus

1. A video whose dropped crops make readiness call for a rescan at every opening: a video with 5 named undecided tracks of one species and 3 kept crops must be up to date (Task 4).
2. A group with 3 or fewer tracks, or a claimed track ranked 4th: nothing of theirs is deleted (Task 1).
3. A device that did not analyse the video must never delete or tombstone its synced crops (Task 3).
4. A crop sheet whose accepted tracks all lost their crops (renamed after a trim) still opens, on the group's largest kept crop (Task 6).
5. A long video and many stretches: times over an hour read "1:02:05", 15 chips wrap without overflow at 412 px (Task 7).

---

### Task 1: The ranking rule

**Files:**
- Create: `lib/features/species_id/domain/services/video_crop_cap.dart`
- Test: `test/features/species_id/domain/video_crop_cap_test.dart`

**Interfaces:**
- Produces:
  - `const int videoCropsKept = 3;`
  - `String cropGroupKey(MediaIdentification i, {List<TaggedSpecies> tags = const []})`: `'claim:<claimedSpeciesId>'` when claimed; for an accepted track whose top candidate does not `candidateMatches` the tag of its `decidedSpeciesId` (when that tag is in [tags]), `'species:<decidedSpeciesId>'`; else `'gbif:<top.candidate.gbifKey>'`; with no candidates, `'id:<id>'`.
  - `Set<String> videoCropsToDrop(List<MediaIdentification> rows, {List<TaggedSpecies> tags = const []})`: ids of tracks whose crop goes. Ignores non-tracks and `isPending` rows.
  - `MediaIdentification? keptStandIn(List<MediaIdentification> rows, MediaIdentification missing, Set<String> present, {List<TaggedSpecies> tags = const []})`: the track in `missing`'s group whose crop is in [present], largest box first; null when none.

Ranking inside a group, named tracks (`isNamed`): tier 0 accepted, tier 1 undecided and `suggestable`, tier 2 the rest; then `boxPixelWidth * boxPixelHeight` descending, then `detectorScore` descending, then `id` ascending. Unnamed tracks: box area, score, id. Claimed tracks are excluded from both rankings and never dropped.

- [ ] **Step 1: Write the failing tests** (use `ruleId` from `identification_rules_fixtures.dart`, extended locally with `startMs: 0` to make tracks; add a helper `track(id, {area, decision, suggestable, specific, claimed, gbif})`):
  - `keeps the 3 largest named tracks of one species and drops the rest`: 5 accepted tracks areas 500,400,300,200,100 → drop == {d, e}.
  - `ranks accepted before suggestable before specific-only`: accepted area 10, suggestable area 1000, specific-only area 5000, plus two more suggestable areas 900, 800 → kept {accepted, 1000, 900}, dropped {5000, 800}.
  - `caps unnamed tracks separately at 3`: 3 named + 5 unnamed of the same gbif key → drops only the 2 smallest unnamed.
  - `never drops a claimed track`: 4 accepted (areas 400..100) plus a claimed area 1 → drop == {the 100 one}.
  - `drops nothing for 3 or fewer tracks, for photos, or for pending tracks`.
  - `separate species are separate groups`: 4 + 4 tracks of two gbif keys → 1 dropped in each.
  - `an accepted track corrected to another species groups under that species`: top candidate parrotfish, decided `sp_grunt`, tags `[TaggedSpecies(speciesId: 'sp_grunt', scientificName: 'Haemulon flavolineatum')]` → `cropGroupKey == 'species:sp_grunt'`.
  - `ties break by detector score then id` (same area).
  - `keptStandIn picks the largest present crop of the group, or null`.
- [ ] **Step 2:** `flutter test test/features/species_id/domain/video_crop_cap_test.dart` → FAIL (file missing).
- [ ] **Step 3:** Implement the three functions and the constant.
- [ ] **Step 4:** Same command → PASS.
- [ ] **Step 5: Commit** `feat(species-id): rank which crops of a video to keep`

### Task 2: Crop presence and the trim candidates in the store

**Files:**
- Modify: `lib/features/species_id/data/services/identification_crop_store.dart`
- Modify: `lib/features/species_id/data/repositories/identification_crop_repository.dart`
- Test: `test/features/species_id/data/identification_crop_store_test.dart`

**Interfaces:**
- Produces:
  - `Future<Set<String>> IdentificationCropStore.presentAmong(String mediaId, List<String> identificationIds)`: ids with a file here or a synced crop.
  - `Future<List<String>> IdentificationCropRepository.mediaWithMoreThan(int count)`: media ids with more than [count] synced crops (`GROUP BY media_id HAVING COUNT(*) > count`).
  - `Future<List<String>> IdentificationCropStore.mediaWithMoreThan(int count)`: union of the table's and of the file folders holding more than [count] `.jpg` files (via `fileIds()`).
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests:** `presentAmong finds files and synced crops`, `presentAmong is empty for no ids`, `mediaWithMoreThan counts synced crops and files per media` (table: m1 with 4, m2 with 3; files: m3 with 4 → `{m1, m3}` for 3).
- [ ] **Step 2:** run the file → FAIL.
- [ ] **Step 3:** Implement (reuse `presentAmong` of the repository and `fileFor`).
- [ ] **Step 4:** run the file → PASS.
- [ ] **Step 5: Commit** `feat(species-id): read which crops a video still has`

### Task 3: Applying the cap

**Files:**
- Create: `lib/features/species_id/data/services/video_crop_capper.dart`
- Test: `test/features/species_id/data/video_crop_capper_test.dart`

**Interfaces:**
- Consumes: `videoCropsToDrop` (Task 1), `presentAmong` (Task 2), `IdentificationCropStore.delete`, `deleteFiles`, `MediaIdentificationRepository.forMediaIdsWithRuns(ids, withPaths: false)`.
- Produces: `class VideoCropCapper { VideoCropCapper({required MediaIdentificationRepository identifications, required IdentificationCropStore crops, required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies, required Future<String?> Function() deviceId}); Future<int> cap(String mediaId); Future<int> capAll(List<String> mediaIds, {int batch = 50}); }`. Returns how many crops it removed; never throws (logs at debug).

`cap`: read the run and rows; return 0 unless the run is a video (`videoDurationMs != null` or any row `isTrack`); compute drops over `visibleRows(run, rows)`; keep only ids in `presentAmong`; when `run.madeOn(me)` call `_crops.delete(mediaId, ids)` (tombstones synced ones, removes files), else `_crops.deleteFiles(mediaId, ids)` only.

- [ ] **Step 1: Write the failing tests** (in-memory `AppDatabase` and a temp support dir as `identification_crop_store_test.dart` does; seed tracks with `startMs`):
  - `removes the crops beyond 3 per species and tombstones the synced ones` (5 accepted with synced crops → 2 crops gone, 2 crop tombstones logged, 5 rows still there).
  - `removes unnamed file crops beyond 3` (5 unnamed with files → 2 files gone).
  - `on a device that did not analyse the video it removes no synced crop` (run `analysedBy: 'other'`, `deviceId: 'me'` → table unchanged, no tombstone).
  - `does nothing for a photo` and `is safe to run twice` (second `cap` returns 0).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** run → PASS.
- [ ] **Step 5: Commit** `feat(species-id): drop the crops a video does not keep`

### Task 4: Hooks in the service, and readiness

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (a `late final VideoCropCapper _capper` built from its own `_identifications`, `_crops`, `_taggedSpecies`, `_deviceId`)
- Modify: `lib/features/species_id/data/services/media_identification_video.dart` (after `await reconcile(job.item.id)` in the chunk loop, and once when `_scanVideo` returns, in a `finally`)
- Modify: `lib/features/species_id/data/services/media_identification_fresh.dart` (`_rename`: after `_promoteNamed`, `_capper.cap(run.mediaId)` when any renamed row `isTrack`)
- Modify: `lib/features/species_id/data/services/media_identification_readiness.dart` (`_cropsPresent`)
- Test: `test/features/species_id/data/media_identification_service_video_test.dart`, `test/features/species_id/data/media_identification_service_readiness_test.dart`

**Interfaces:**
- Consumes: `VideoCropCapper.cap` (Task 3), `cropGroupKey` (Task 1), `IdentificationCropStore.presentAmong` (Task 2).
- `_cropsPresent` new rule: photos as today. For tracks, group the named rows by `cropGroupKey`; every group holding an undecided named track needs at least one named track of that group with a crop present; the `wasAnalysedHere` clause stays as it is.

- [ ] **Step 1: Write the failing tests:**
  - video test `a scan keeps 3 crops of a species followed 5 times` (fake engine yields 5 tracks of one species; after the scan, 3 crops present).
  - readiness test `a video with 5 named tracks and 3 kept crops is up to date`.
  - readiness test `a video whose named tracks have no crop at all is not up to date`.
- [ ] **Step 2:** run both files → FAIL.
- [ ] **Step 3:** Implement the hooks and the rule.
- [ ] **Step 4:** run both files → PASS; also run `media_identification_service_fresh_test.dart` and `video_identification_scan_test.dart` (touched paths).
- [ ] **Step 5: Commit** `feat(species-id): cap a video's crops as it is scanned`

### Task 5: The launch trim

**Files:**
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (`trimVideoCropsAtLaunch(ProviderContainer)` called last in `runIdentificationLaunchSteps`, after `backfillNamedCropsAtLaunch`; gated on `marineLifeIdEnabled`)
- Test: `test/features/species_id/data/video_crop_capper_test.dart`

**Interfaces:**
- Consumes: `IdentificationCropStore.mediaWithMoreThan(videoCropsKept)` (Task 2), `VideoCropCapper.capAll` (Task 3). The capper's `taggedSpecies` is the same function the service provider passes; `deviceId` is `syncDeviceIdOrNull`.

- [ ] **Step 1: Write the failing test** `capAll trims every candidate video and leaves photos` (two videos over the cap, one photo with 5 crops).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Implement `capAll` batching and `trimVideoCropsAtLaunch`.
- [ ] **Step 4:** run → PASS.
- [ ] **Step 5: Commit** `feat(species-id): trim the crops already stored at launch`

### Task 6: Fallback to a kept crop

**Files:**
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (`identificationCropProvider`; new `presentCropIdsProvider`)
- Test: `test/features/species_id/presentation/providers/identification_crop_fallback_test.dart`

**Interfaces:**
- Produces: `final presentCropIdsProvider = FutureProvider.autoDispose.family<Set<String>, String>` (media id → ids with a crop; invalidated on `IdentificationCropStore.watchChanges` for that media). `identificationCropProvider((mediaId, id))`: when the crop is missing and the identification is a track, returns the crop of `keptStandIn(...)`, else null.
- Consumes: `keptStandIn` (Task 1), `presentAmong` (Task 2).

- [ ] **Step 1: Write the failing tests:** `a dropped track shows its group's largest kept crop`, `a photo's missing crop stays missing`, `a track with no kept crop in its group stays missing`.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** run → PASS.
- [ ] **Step 5: Commit** `feat(species-id): show a kept crop for a dropped one`

### Task 7: The crop sheet: kept crops, count and time chips

**Files:**
- Modify: `lib/features/species_id/domain/services/species_crops.dart` (`videoStretches`)
- Modify: `lib/features/species_id/presentation/widgets/species_crop_sheet.dart`
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart`, `lib/features/media/presentation/widgets/media_species_list_sheet.dart`, `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart`, `lib/features/media/presentation/pages/media_viewer_actions.dart`, `lib/features/media/presentation/pages/media_viewer_page.dart` (thread `onMoment`)
- Modify: all 12 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/species_id/domain/species_crops_test.dart`, `test/features/species_id/presentation/widgets/species_crop_sheet_test.dart`

**Interfaces:**
- Produces:
  - `List<({int startMs, int endMs})> videoStretches(List<MediaIdentification> tracks, {int gapMs = 1000})`: sorted, merging tracks that overlap or start within [gapMs] of the last end.
  - `openSpeciesCrops(..., ValueChanged<Duration>? onMoment)`: the sheet pops with a `Duration`; `onMoment` is called with it. Without `onMoment` (or on a photo) no chips show.
  - `speciesChipWidgets(..., ValueChanged<Duration>? onMoment)`, `MediaSpeciesChipsRow.onMoment`, `MediaSpeciesListSheet.onMoment`.
  - In the viewer, `_showMomentAt(MediaItem item, Duration at)` holds the body of today's `_showMoment` (pause, then seek; nothing when the controller is missing or failed); `_showMoment(item, tag)` calls it with `tag.videoPosition`.
- Strings (English; translate for the other 11):
  - `media_species_cropBestOfVideo`: `"{shown} best of {count} sightings"` (placeholders `shown`, `count` int), shown only when fewer crops than tracks; otherwise the existing `media_species_cropCountVideo`.
  - `media_species_seenAt`: `"Seen at"`.
  - `media_species_seenStretch`: `"{start} to {end}"` (String placeholders; one time alone when the stretch is under 1 s).
  - `media_species_playFrom`: `"Play from {time}"` (screen reader label of a chip).
- Sheet behaviour: crops shown = sheet tracks (`cropsOfSpecies`) whose id is in `presentCropIdsProvider`; when none, the one `keptStandIn` of the first sheet track; the count line uses all sheet tracks. Chips: `ActionChip` per stretch with `formatMoment` (from `face_box_geometry.dart`) labels, keys `species_crop_moment_<startMs>`, in a `Wrap`; tap pops the sheet with `Duration(milliseconds: startMs)`.

- [ ] **Step 1: Write the failing tests:**
  - domain: `videoStretches merges overlapping and near tracks`, `keeps far tracks apart`, `a track under a second is one time`.
  - widget: `a video shows the kept crops and 3 best of 5 sightings`; `tapping a time chip closes the sheet and reports the moment` (expects `onMoment` called with `Duration(milliseconds: 4000)`); `a photo shows no time chips`; `a sheet whose tracks lost their crops shows the group's kept crop`; `15 stretches wrap at 412 px without overflow`; `an hour-long video reads 1:02:05`.
- [ ] **Step 2:** run both files → FAIL.
- [ ] **Step 3:** Implement; add the strings to all 12 ARBs; `flutter gen-l10n`.
- [ ] **Step 4:** run both files, plus `test/features/media/presentation/widgets/media_species_chips_row_test.dart` and the viewer test files touched, by path → PASS.
- [ ] **Step 5: Commit** `feat(species-id): jump from a species' crops to where it was seen`

### Task 8: Finish

- [ ] `dart format .`, `flutter analyze` (whole repo, must be clean).
- [ ] Update `docs/design/specs/2026-11-26-video-crop-cap-design.md` status to "built" if anything changed in the build, and any user doc that describes the crop sheet (grep `docs/` for "crop").
- [ ] Commit `docs(species-id): note the video crop cap`.
