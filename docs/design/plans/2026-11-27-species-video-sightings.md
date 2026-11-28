# Species videos open at the sighting: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The viewer opened from a dive's sighting-row photo chip opens each video paused at the species' first sighting, marks every sighting on the scrub bar, and offers a Next sighting button when there are two or more.

**Architecture:** A per-video provider keyed on (video, species) turns the video's accepted identification tracks into sighting stretches. `MediaViewerPage` takes an optional `focusSpeciesId`; with it, the viewer seeks each new video player to its first stretch and hands the species to both `VideoControlsBar` call sites, which draw bands and the button from the same provider.

**Tech Stack:** Flutter, Riverpod (`core/providers/provider.dart`), video_player, flutter_test with fake `VideoPlayerPlatform`s.

**Spec:** `docs/design/specs/2026-11-27-species-video-sightings-design.md` (issue #5084)

## Global Constraints

- Sightings are `videoStretches(cropsOfSpecies(identifications, speciesId))` from `lib/features/species_id/domain/services/species_crops.dart`; no new stored data.
- Only the sighting chip's route (`DiveSpeciesPhotoViewerPage`) sets `focusSpeciesId`; every other viewer caller is unchanged.
- A video already playing, or moved off its start, is never seeked by the sighting lookup.
- `initialVideoPosition` wins over the first sighting for the initial item.
- Bands at least 3 px wide, drawn under the face-tag marks, ignoring pointer events.
- Button shows only for two or more stretches; seeks to the first stretch starting more than 500 ms after the position, wrapping to the first; keeps the play state.
- New copy "Next sighting" translated in every ARB locale (ARBs are feature-grouped: insert beside `media_species_seenAt`).
- Files stay under 800 lines: `media_viewer_page.dart` is at 776, so the seek logic goes in a new part file.
- No em-dashes anywhere; `dart format .` before each commit; run only the test files changed.

## Review Focus

- Paging away and back to a video: the player is released and recreated, so it seeks to the first sighting again (test in Task 3).
- The diver presses play before the lookup completes: no seek (test in Task 3).
- A video tagged only by hand (no tracks) or with only pending tracks: no seek, no bands, no button (tests in Tasks 1 and 2).
- Many sightings on a long clip (a school of fish): bands stay one row, a 0-length stretch still draws 3 px (test in Task 2).
- Position exactly at a stretch start: Next goes to the following stretch, not the same one (test in Task 1).

---

### Task 1: Sightings provider and next-stretch rule

**Files:**
- Modify: `lib/features/species_id/domain/services/species_crops.dart`
- Create: `lib/features/species_id/presentation/providers/video_sighting_providers.dart`
- Test: `test/features/species_id/domain/species_crops_test.dart`
- Test: `test/features/species_id/presentation/providers/video_sighting_providers_test.dart`

**Interfaces:**
- Produces: `typedef VideoStretch = ({int startMs, int endMs});` (use it as `videoStretches`'s element type too).
- Produces: `int? nextStretchStart(List<VideoStretch> stretches, int positionMs, {int leadMs = 500})`: null for an empty list; else the first `startMs > positionMs + leadMs`, else `stretches.first.startMs`.
- Produces: `typedef VideoSpeciesKey = ({String mediaId, String speciesId});` and `final videoSpeciesSightingsProvider = FutureProvider.family<List<VideoStretch>, VideoSpeciesKey>` reading `mediaIdentificationRepositoryProvider.forMedia(mediaId)`, invalidating on its `watchChanges()`.

- [ ] **Step 1: Write failing tests**
  - `species_crops_test.dart`, group `nextStretchStart`: stretches `[(0:10,0:20),(1:00,1:10),(2:00,2:05)]` in ms; position 0 gives 10000; position 10000 (at a start) gives 60000; position 59600 (within the 500 ms lead) gives 120000; position 130000 wraps to 10000; empty list gives null.
  - `video_sighting_providers_test.dart`: with a fake repository returning tracks (helper building `MediaIdentification` with `decision: accepted`, `decidedSpeciesId`, `startMs`, `endMs`, `bestMs`), the provider for (m1, s1) returns merged stretches in time order; tracks of another species are excluded; a pending track (`bestMs: null`) is excluded; no tracks gives `[]`; an emit on `watchChanges()` re-reads (second read sees a new track).
- [ ] **Step 2: Run** `flutter test test/features/species_id/domain/species_crops_test.dart test/features/species_id/presentation/providers/video_sighting_providers_test.dart`; expect failures for the missing names.
- [ ] **Step 3: Implement** `VideoStretch`, `nextStretchStart` in `species_crops.dart` and the provider file.
- [ ] **Step 4: Run** the same command; expect all pass.
- [ ] **Step 5: Commit** `feat(species-id): sighting stretches of a species on a video`.

### Task 2: Bands and the Next sighting button on the controls bar

**Files:**
- Create: `lib/features/species_id/presentation/widgets/video_sighting_marks.dart`
- Modify: `lib/features/media/presentation/widgets/video_controls_bar.dart`
- Modify: every `lib/l10n/arb/app_*.arb` (key `media_species_nextSighting`), then `flutter gen-l10n`
- Test: `test/features/media/presentation/widgets/video_controls_bar_sightings_test.dart`

**Interfaces:**
- Consumes: `videoSpeciesSightingsProvider`, `nextStretchStart` (Task 1).
- Produces: `VideoControlsBar({..., String? speciesId})`; `VideoSightingMarks({required String mediaId, required String speciesId, required Duration duration, required double width})`; `VideoControlsBar.nextSightingKey = ValueKey('videoControlsBar.nextSighting')`; `VideoSightingMarks` bands keyed `ValueKey('videoSightingMark_<startMs>')`.

- [ ] **Step 1: Write failing tests** (reuse `video_controls_bar_test_harness.dart`: `useBarPlatform`, `readyController`, `barApp`, `finishBar`; override `videoSpeciesSightingsProvider((mediaId: 'm1', speciesId: 's1'))` in a local `ProviderScope` wrapper or by extending `barApp` with an `overrides` parameter):
  - no `speciesId`: no `videoSightingMark_*`, no next button.
  - one stretch (3000 to 6000 of the 30 s clip): one band whose rect left is 10% and width 10% of the track (within 1 px); no next button.
  - a 0-length stretch at 15000: band width is 3.
  - two stretches (3000 to 6000, 20000 to 22000): next button present with tooltip "Next sighting"; tap at position 0 seeks to 3000 (`platform.seeks.last`); tap again seeks to 20000; tap again wraps to 3000.
  - playing video: after a tap, `platform.playing` is still true; paused video stays paused.
  - empty stretches (hand tag): no bands, no button.
- [ ] **Step 2: Run** `flutter test test/features/media/presentation/widgets/video_controls_bar_sightings_test.dart`; expect failures.
- [ ] **Step 3: Implement.** `VideoSightingMarks` is a `ConsumerWidget` in an `IgnorePointer`, one `Positioned` per stretch from `start/duration` to `end/duration` of `width`, `max(3, ...)` wide, 4 px tall on the track, colour `Colors.tealAccent` (legible on the black bar). In the bar's track `Stack`, place it after the progress track and before `tagMarks` (built once, outside the glide builder, like `analysed`). After the total time `SizedBox`, when `speciesId != null` and stretches length >= 2, an `IconButton` (`Icons.skip_next`, white, `visualDensity: compact`, tooltip `l10n.media_species_nextSighting`) whose press calls `_seekTo(Duration(milliseconds: nextStretchStart(stretches, _heading.inMilliseconds)!))`. Add the ARB key with `@media_species_nextSighting` description "Button on a video's controls that jumps to the next time the species was seen" in `app_en.arb` and a translation in every other locale.
- [ ] **Step 4: Run** the test file plus `test/features/media/presentation/widgets/video_controls_bar_test.dart`; expect all pass.
- [ ] **Step 5: Commit** `feat(media): sighting bands and Next sighting on the video bar`.

### Task 3: The viewer follows the species and seeks each video

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (field, part, call)
- Create: `lib/features/media/presentation/pages/media_viewer_sightings.dart` (part, `extension _ViewerSightings on _MediaViewerPageState`)
- Modify: `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart`, `media_viewer_gallery.dart`, `media_viewer_video_item.dart` (pass `speciesId` to both bars)
- Modify: `lib/features/media/presentation/pages/dive_species_photo_viewer_page.dart`
- Modify: `test/features/media/presentation/pages/video_viewer_test_harness.dart` (`focusSpeciesId` parameter, a second video item option if not present)
- Test: `test/features/media/presentation/pages/media_viewer_sightings_test.dart`
- Test: `test/features/media/presentation/pages/dive_species_photo_viewer_page_test.dart`

**Interfaces:**
- Consumes: `videoSpeciesSightingsProvider` (Task 1), `VideoControlsBar.speciesId` (Task 2).
- Produces: `MediaViewerPage({..., String? focusSpeciesId})`; `_PhotoGallery.focusSpeciesId` and `_VideoItem.focusSpeciesId` pass-throughs; `void _seekToFirstSighting(String mediaId, VideoPlayerController controller)` in the part.

- [ ] **Step 1: Write failing tests** (`_SeekRecorder` pattern from `media_viewer_start_position_test.dart`, with the provider overridden):
  - with `focusSpeciesId: 's1'` and stretches `[(4200, 9000), (15000, 16000)]` for the video, the player seeks once to 4200.
  - with `focusSpeciesId` and `[]` stretches: no seek.
  - without `focusSpeciesId`: no seek even with stretches present.
  - `initialVideoPosition: 1000` plus `focusSpeciesId`: seeks to 1000 only.
  - lookup held on a `Completer`; the test plays the video (platform `play`) before completing it: no seek.
  - two videos: paging to the second seeks it to its own first stretch; paging back seeks the first to its first stretch again.
  - the bar in the bottom panel receives `speciesId: 's1'` (find `VideoControlsBar` and read the widget's field).
  - `dive_species_photo_viewer_page_test.dart`: the pushed `MediaViewerPage` has `focusSpeciesId` equal to the page's `speciesId`.
- [ ] **Step 2: Run** `flutter test test/features/media/presentation/pages/media_viewer_sightings_test.dart test/features/media/presentation/pages/dive_species_photo_viewer_page_test.dart`; expect failures.
- [ ] **Step 3: Implement.** In `_onVideoControllerChanged`'s add branch, after the `initialVideoPosition` check, call `_seekToFirstSighting(mediaId, controller)` unless that check just applied to this item. The part reads `videoSpeciesSightingsProvider(key).future` (log and give up on error), then seeks to the first stretch's start only if `_videoControllers[mediaId]` is still this controller, it is initialized, not playing and its position is under 250 ms. Pass `focusSpeciesId` as `speciesId` to both bars, and from `DiveSpeciesPhotoViewerPage`.
- [ ] **Step 4: Run** the two files plus `media_viewer_start_position_test.dart` and `media_viewer_video_test.dart`; expect all pass. `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(media): open species videos at the sighting from the dive's sighting chip`.
