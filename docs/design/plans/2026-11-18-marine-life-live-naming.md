# Marine life live naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the video scan follow the playhead, name fish while they are in view, and show suggestions while a video plays (issue #4709).

**Architecture:** The run row records scanned stretches instead of one prefix mark. A pure function picks each next chunk from the stretches, where the last chunk ended and the latest playhead report; the viewer reports settled seeks and pauses to the service. The scan names open tracks at every chunk's end, renames on a clearly better view, joins tracks where stretches meet, and drops its running chunk when a report moves it. No Swift changes.

**Tech Stack:** Flutter, Dart, Drift, Riverpod, `video_player`.

**Spec:** `docs/design/specs/2026-11-18-marine-life-identification-5-live-naming-design.md`

## Global Constraints

- Ships under `marineLifeIdEnabled`; no new flag, switch or setting.
- No Swift changes; `detectVideo` and `embedMoments` are used as they are.
- Schema: the next free version, 377 at the time of writing; renumber if main takes it first.
- `media_identification_runs` and `media_identifications` never sync; no sync registration.
- No em-dashes anywhere, in code, comments or docs. No emojis.
- No new user-facing strings.
- Run only the test files written or changed, by path. Never a folder.
- `dart format .` before each commit.
- First chunk after opening or a playhead move: 2000 ms of video. Later chunks: 10000 ms.
- Early naming: an open track seen for at least 1000 ms (`endMs - startMs`).
- Better view: a new moment worth at least 1.5 times the moment the track was last named from, worth = detector score times box area.
- Seek detection: a position change over 1500 ms between two player updates, or any backward change over 250 ms; report once the position has settled for 500 ms.

## Review Focus

1. A playhead report beyond the video's real length (the length is unknown until the first pass 1): the chunk is clamped, the scan fills from the start and ends; no loop.
2. A pause report at a position already scanned moves nothing and drops nothing.
3. A run stored at v376 (`scanned_ranges` null, `scanned_ms` partial or complete) resumes from its mark or reads complete; a photo's run (both null) never reads as a video.
4. A seek that lands inside the running chunk does not drop it.
5. The stretches become complete while a report is pending: `nextVideoChunk` returns null and the scan ends cleanly.

---

### Task 1: Scanned stretches and their codec

**Files:**
- Create: `lib/features/species_id/domain/entities/scanned_ranges.dart`
- Create: `lib/features/species_id/domain/services/scanned_ranges_codec.dart`
- Test: `test/features/species_id/domain/scanned_ranges_test.dart`

**Interfaces:**
- Produces:
  - `typedef ScannedStretch = ({int startMs, int endMs});`
  - `class ScannedRanges extends Equatable` with `const ScannedRanges([List<ScannedStretch> stretches = const []])`, `factory ScannedRanges.prefix(int endMs)` (empty for `endMs <= 0`), `List<ScannedStretch> stretches` (sorted, merged, no empty stretch), `ScannedRanges add(int startMs, int endMs)`, `bool covers(int ms)` (`start <= ms < end`), `bool coversRange(int startMs, int endMs)`, `int coveredMs(int durationMs)` (clipped to `durationMs`), `int? firstGapAtOrAfter(int ms, {int? durationMs})` (null when covered to `durationMs`; `durationMs` null means unbounded), `int? stretchStartAfter(int ms)` (the start of the first stretch with `start > ms`), `int get prefixEndMs` (end of a stretch starting at 0, else 0), `bool isComplete(int durationMs)`.
  - `Uint8List encodeScannedRanges(ScannedRanges ranges)` and `ScannedRanges decodeScannedRanges(Uint8List bytes)`: byte 0 is version 1, then each stretch as little-endian uint32 start and uint32 end; decode throws `FormatException` for an unknown version, a length that is not whole stretches, or `end <= start`.

- [ ] **Step 1: Write the failing tests** in `scanned_ranges_test.dart`:
  - `add merges touching and overlapping stretches`: `ScannedRanges().add(0, 10000).add(10000, 12000).add(30000, 40000).add(35000, 50000)` has stretches `[(0, 12000), (30000, 50000)]`.
  - `prefix(0) is empty and prefix(25000) is one stretch`.
  - `firstGapAtOrAfter`: with `[(0, 12000), (30000, 50000)]`, `5000 -> 12000`, `20000 -> 20000`, `30000 -> 50000`, `45000` with `durationMs: 50000` -> null.
  - `stretchStartAfter(12000) == 30000`, `stretchStartAfter(30000) == null`.
  - `coveredMs(40000) == 22000`; `isComplete(50000)` false; `ScannedRanges.prefix(25000).isComplete(25000)` true.
  - `covers(11999)` true, `covers(12000)` false; `coversRange(1000, 12000)` true, `coversRange(1000, 13000)` false.
  - codec round trip of the two-stretch value; `decodeScannedRanges(Uint8List.fromList([2]))` throws `FormatException`; a 6-byte blob throws; a stretch with end equal to start throws.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/species_id/domain/scanned_ranges_test.dart`
Expected: compile errors, `ScannedRanges` not found.

- [ ] **Step 3: Implement `ScannedRanges` and the codec.** `add` builds a new sorted, merged list (immutable value). The codec follows `track_path_codec.dart`'s style.

- [ ] **Step 4: Run the tests to see them pass** (same command). Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/species_id/domain/entities/scanned_ranges.dart lib/features/species_id/domain/services/scanned_ranges_codec.dart test/features/species_id/domain/scanned_ranges_test.dart
git commit -m "feat(species-id): scanned stretches of a video and their packing"
```

### Task 2: Schema step for `scanned_ranges`

**Files:**
- Modify: `lib/core/database/tables/identification_tables.dart` (runs table, after `videoDurationMs`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/identification_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart`
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart`
- Modify: `lib/features/species_id/domain/entities/media_identification.dart` (`MediaIdentificationRun`)
- Modify: `lib/features/species_id/data/repositories/media_identification_repository.dart` (`_runFromRow`, `_runToCompanion`)
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` and the Drift outputs
- Test: `test/core/database/migration_v377_identification_scanned_ranges_test.dart` (create), `test/features/species_id/data/media_identification_repository_test.dart`, `test/features/species_id/domain/entity_copy_with_test.dart`

**Interfaces:**
- Consumes: Task 1's `ScannedRanges`, codec.
- Produces:
  - Table: `BlobColumn get scannedRanges => blob().nullable()();` with a doc comment: "Video only: the stretches scanned, packed (scanned_ranges_codec.dart). Null for a photo and for a video scanned before v377, whose scanned_ms is then one stretch from 0."
  - `MediaIdentificationRun.scannedRanges` (`ScannedRanges?`), `ScannedRanges get scanned` (`scannedRanges ?? ScannedRanges.prefix(scannedMs ?? 0)`), `scanComplete` now `videoDurationMs != null && scanned.isComplete(videoDurationMs!)`; `copyWith(ScannedRanges? Function()? scannedRanges)`; in `props`.
  - Helper `_assertIdentificationScannedRanges()` adding `scanned_ranges BLOB` with `_addColumnIfMissing`.
  - Repository: reads decode inside try/catch (a bad blob reads as null, so the prefix mark applies); writes encode, null stays null.

- [ ] **Step 1: Write the failing tests**
  - `migration_v377_identification_scanned_ranges_test.dart`, modelled on `migration_v376_identification_video_columns_test.dart`: `v377 is in the ladder`; `the floor does not move` (`minimumCompatibleSchemaVersion < 377`); a fresh database has `scanned_ranges`; a v376 database with a run row (`scanned_ms` 12000, `video_duration_ms` 30000) gains the column, null, and the row is otherwise unchanged.
  - Repository test `a run's scanned stretches round trip`: store a run with `scannedRanges: ScannedRanges().add(0, 12000).add(30000, 40000)`, read it back equal; and `a run stored without stretches reads its mark as one stretch` (`scanned.stretches == [(startMs: 0, endMs: 12000)]`); and a bad blob written with a raw update reads `scannedRanges` null.
  - Entity copyWith test: `scannedRanges` set and cleared through `copyWith`; `scanComplete` true for `ScannedRanges().add(0, 30000)` with `videoDurationMs: 30000` and false with a gap.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/database/migration_v377_identification_scanned_ranges_test.dart test/features/species_id/data/media_identification_repository_test.dart test/features/species_id/domain/entity_copy_with_test.dart`
Expected: failures on the missing column and field.

- [ ] **Step 3: Implement.** Bump to 377 with a `migrationVersions` note in the style of 376 ("v377: media_identification_runs.scanned_ranges, the stretches of a video scanned (issue #4709). A column on a table that never syncs, no backfill; the floor does not move."). Append `if (from < 377) await _assertIdentificationScannedRanges(); if (from < 377) await reportProgress();`. Add the backstop after the v376 one. Then run Drift codegen unfiltered in the background (`dart run build_runner build --delete-conflicting-outputs`) and `dart run tool/generate_sql_column_notes.dart`.

- [ ] **Step 4: Run the tests to see them pass** (same command), then `flutter analyze`.

- [ ] **Step 5: Commit** the tables, migration files, entity, repository, generated notes and the three tests: `feat(species-id): store the stretches of a video already scanned`.

### Task 3: Choosing the next chunk

**Files:**
- Create: `lib/features/species_id/domain/services/video_scan_order.dart`
- Test: `test/features/species_id/domain/video_scan_order_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `class PlayheadReport extends Equatable { const PlayheadReport({required int ms, required bool seek, required int sequence}); }` (`seek` false means a pause).
  - `typedef VideoChunk = ({int startMs, int endMs});`
  - `VideoChunk? nextVideoChunk({required ScannedRanges scanned, required int? durationMs, required int? runEndMs, required PlayheadReport? report, int chunkMs = 10000, int firstChunkMs = 2000})`
  - `bool reportMovesScan(PlayheadReport report, {required ScannedRanges scanned, required int? durationMs, required VideoChunk running})`

Rules (`nextVideoChunk`), in order:
1. A pause report at a covered position counts as no report.
2. With a report: start at `firstGapAtOrAfter(report.ms)`; if found, length is `chunkMs` when the start equals `runEndMs`, else `firstChunkMs`.
3. Else with `runEndMs`: start at `firstGapAtOrAfter(runEndMs)`, length `chunkMs`.
4. Else start at `firstGapAtOrAfter(0)`, length `firstChunkMs` when `runEndMs` is null (opening), else `chunkMs`.
5. The end is the least of start plus length, `stretchStartAfter(start)` and `durationMs`. Null when no gap is left.

`reportMovesScan`: false for a pause at a covered position; otherwise true when `firstGapAtOrAfter(report.ms)` is non-null and outside `[running.startMs, running.endMs)`.

- [ ] **Step 1: Write the failing tests**, one per line:
  - opening an unscanned 60 s video gives `(0, 2000)`;
  - continuing gives `(2000, 12000)` with `runEndMs: 2000`;
  - a seek report to 30000 with `runEndMs: 12000` gives `(30000, 32000)`;
  - a seek into `[(0, 20000)]` at 5000 gives `(20000, 22000)`, and with `runEndMs: 20000` gives `(20000, 30000)`;
  - a chunk stops at the next stretch: `[(30000, 40000)]`, `runEndMs: 25000` gives `(25000, 30000)`;
  - at the end of a gapped video (`[(0, 10000), (30000, 60000)]`, `runEndMs: 60000`, duration 60000) it fills from `(10000, 20000)`;
  - a pause report at a covered 5000 is ignored; a pause at an uncovered 45000 gives `(45000, 47000)`;
  - a report beyond a known duration of 60000 at 90000 with everything scanned from 0 to 40000 fills `(40000, 50000)`;
  - duration unknown (`durationMs: null`) with a report at 90000 gives `(90000, 92000)`;
  - complete gives null, even with a pending report;
  - `reportMovesScan`: a seek inside the running `(30000, 40000)` at 35000 is false; at 10000 (uncovered) is true; a pause at a covered position is false; a seek whose first gap is the running chunk's start is false.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/species_id/domain/video_scan_order_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement** the two functions as ruled above.

- [ ] **Step 4: Run the tests to see them pass.**

- [ ] **Step 5: Commit** `feat(species-id): choose a video's next chunk from where the diver is watching`.

### Task 4: Track rules for early naming, renaming and seams

**Files:**
- Modify: `lib/features/species_id/domain/services/video_tracker.dart`
- Modify: `lib/features/species_id/domain/services/video_identification_rules.dart`
- Test: `test/features/species_id/domain/video_tracker_test.dart`, `test/features/species_id/domain/video_identification_rules_test.dart`

**Interfaces:**
- Produces, in `video_tracker.dart`:
  - `double momentWorth(DetectedBox d)` (score times box area); `bestMoments` uses it.
  - `TrackedAnimal` gains `final double? namedWorth` (constructor parameter; carried by its copy): the worth of the moment it was last named from, null when never named.
  - `VideoTracker.markStored(TrackedAnimal animal, {required String storedId, required double? namedWorth})`: the open track that is `animal` is replaced by one with that `storedId`, `storedLength == points.length` and that `namedWorth`.
  - `List<TrackedAnimal> get openTracks` (the open animals, oldest first).
- Produces, in `video_identification_rules.dart`:
  - `const int earlyNamingMs = 1000;` and `const double betterViewMargin = 1.5;`
  - `bool namesNow(TrackedAnimal track)`: true when never named (`namedWorth == null` or no `storedId`), or when some new point (index at or after `storedLength`) has `momentWorth >= betterViewMargin * namedWorth`.
  - `MediaIdentification keepDecisionOnRename({required MediaIdentification before, required MediaIdentification renamed})`: `renamed` with `before`'s decision, decided species, decided time and claim; except that an accepted row with no claim whose top candidate's scientific name differs (case-insensitive) from `renamed`'s goes back to undecided with no decided species or time.
  - `List<({TrackedAnimal open, MediaIdentification later})> seamJoins({required List<TrackedAnimal> open, required Map<String, MediaIdentification> openRows, required List<MediaIdentification> stored, required int seamMs, int maxGapMs = 750, double linkOverlap = 0.3})`: pairs an open track with a stored track starting within `[seamMs, seamMs + maxGapMs]` whose first box has at least `linkOverlap` IoU with the open track's last box, highest overlap first, each used once; a pair is left out when both carry the diver's say (a non-undecided decision or a claim, the open one read from `openRows[open.storedId]`) and the two differ (different decision, decided species or claim).

- [ ] **Step 1: Write the failing tests**
  - tracker: `markStored keeps the track open and counts its points as stored` (`hasNewPoints` false after, true after one more matched frame); `openTracks lists the open animals`.
  - rules: `namesNow` true for a never-named track; false when the new points are worth 1.4 times; true at 1.5 times.
  - `keepDecisionOnRename`: accepted with no claim and a changed top goes undecided; same top stays accepted; a claim and a dismissal are kept whatever the name; an undecided row stays undecided.
  - `seamJoins`: a fish crossing a seam at 30000 (open last box at 29750, stored first at 30000, same box) is paired; a stored track starting at 31000 is not; an accepted open part and a dismissed later part are not paired; an accepted open part and an undecided later part are paired.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/species_id/domain/video_tracker_test.dart test/features/species_id/domain/video_identification_rules_test.dart`

- [ ] **Step 3: Implement** as specified.

- [ ] **Step 4: Run the tests to see them pass.**

- [ ] **Step 5: Commit** `feat(species-id): rules for naming a fish in view, renaming it and joining it across a seam`.

### Task 5: Suggestions while playing

**Files:**
- Modify: `lib/features/species_id/domain/services/track_labels.dart` (`labelKind`)
- Test: `test/features/species_id/domain/track_labels_test.dart`, `test/features/species_id/presentation/video_identification_layer_test.dart`

**Interfaces:**
- Produces: `labelKind` returns `suggestion` for an undecided, suggestable, not confident track whether playing or paused; dots stay paused only.

- [ ] **Step 1: Change the tests first**: the existing case asserting no label for a suggestable track while playing now expects `TrackLabelKind.suggestion`; add `a dot is still paused only`. In the layer test, the playing case shows the suggestion pill's name.
- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/species_id/domain/track_labels_test.dart test/features/species_id/presentation/video_identification_layer_test.dart`

- [ ] **Step 3: Implement**: in the undecided branch, return `confident`, then `suggestion` when suggestable, then `null` when playing, then the dot rule. Update the doc comments on `TrackLabelKind.suggestion` and on `VideoIdentificationLayer` ("Playing, a fish gets a pill when the app could suggest a name or the diver tagged it").
- [ ] **Step 4: Run the tests to see them pass.**
- [ ] **Step 5: Commit** `feat(species-id): show suggested names while a video plays`.

### Task 6: The scan follows the playhead and names fish in view

**Files:**
- Modify: `lib/features/species_id/data/services/video_identification_scan.dart`
- Create: `lib/features/species_id/data/services/video_identification_scan_naming.dart` (`part of 'video_identification_scan.dart'`): `_nameTracks`, `_identification`, `_unnamed`, `_averaged` move here as an extension on `VideoIdentificationScan`, keeping the scan file under 800 lines.
- Test: `test/features/species_id/data/video_identification_scan_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4.
- Produces, on `VideoIdentificationScan`:
  - Constructor: removes `stored`; adds `PlayheadReport? Function()? playhead` and `this.firstChunkMs = 2000`. `chunkMs` stays 10000.
  - `double get progress`: `scanned.coveredMs(duration) / duration`.
  - `Future<bool> runChunk()`: returns whether more remains; a dropped chunk returns true having stored nothing.
  - `finish({bool naming = true})` unchanged in meaning.

Behaviour to build, in `runChunk`:
1. Take the latest report whose `sequence` is above the last honoured one; pick the chunk with `nextVideoChunk(scanned:, durationMs:, runEndMs:, report:, chunkMs:, firstChunkMs:)`; none: store nothing, return false.
2. When the chunk does not start at the current run's end: end the run (store its open tracks as `finish` does, without moving the stretches), then start a run: read the video's rows from the repository and resume (as the constructor does today, measured from the chunk's start) the stored tracks that end within the gap allowance before it. Mark the report honoured.
3. Pass 1. If a newer report now `reportMovesScan`, restore the tracker and return true (dropped).
4. Feed the frames. At the video's end close all tracks. When the chunk ends at a later stretch's start (a seam): read that stretch's stored tracks, apply `seamJoins`, merge each pair into the later row's id (path, start and the open track's points first; delete the earlier row when the open track had one), then close all tracks; the run ends there.
5. Name: closed tracks and open tracks with `endMs - startMs >= earlyNamingMs`, each only when `namesNow` (a closed or open track that does not name now keeps its name and gains its path, as `_unnamed` does for a named row). Between pass 2 batches, stop on `keepGoing` false (as today) and drop on a moving report (restore the tracker, return true).
6. Store as today, applying `keepDecisionOnRename(before: current row, renamed: new row)` to every renamed row that already had a stored row; `markStored` every open track that was stored; add the chunk to the stretches; write `scannedRanges` and `scannedMs: scanned.prefixEndMs`.

- [ ] **Step 1: Adjust the test factory and write the failing tests.** The factory passes `firstChunkMs: 10000` by default so today's chunk-boundary tests keep their expectations, and takes `playhead` and `firstChunkMs` overrides. New tests:
  - `the first chunk is short when asked`: `firstChunkMs: 2000` on a 25 s video gives detect calls `[(0, 2000), (2000, 12000), (12000, 22000), (22000, 25000)]`.
  - `a seek report moves the next chunk`: after the first chunk, a seek report at 40000 on a 60 s video makes the next call `(40000, 42000)`; the run's stretches then hold `(0, 10000)` and `(40000, 42000)`.
  - `the scan fills what it skipped`: run to the end after a seek to 40000; the calls fill `10000` to `40000` last and `scanComplete` is true.
  - `a fish still in view at a chunk's end is stored named`: `_fish(5000, 25000)` with 10 s chunks has a named row after the first chunk with `endMs == 9750`.
  - `a fish is not named again without a better view`: same fish, constant box: one `embedMoments` call batch for it across three chunks; its row's `endMs` reaches 24750.
  - `a fish is renamed on a better view`: a fish whose box doubles in area in the second chunk is embedded again, and a changed name is stored.
  - `a renamed fish accepted by a name match goes back to undecided`: accept the row (no claim) between chunks; rename to a different candidate; the row is undecided.
  - `a fish crossing a seam is one row`: scan `(30000, 60000)` first (seek), then fill `(0, 30000)`; `_fish(25000, 35000)` ends as one row from 25000 to 34750.
  - `a seek after pass 1 drops the chunk`: the fake engine's detect hook posts a report at 50000; the chunk stores nothing and the next call is `(50000, 52000)`.
  - `a seek inside the running chunk does not drop it`.
  - `a pause on scanned video moves nothing`.
  - `a v376 run resumes from its mark`: `resumeFrom` with `scannedMs: 12000`, no stretches; the first call starts at 12000.
- [ ] **Step 2: Run the file to see the new tests fail**

Run: `flutter test test/features/species_id/data/video_identification_scan_test.dart`

- [ ] **Step 3: Implement** the behaviour above; split the naming helpers into the part file first, with no behaviour change, and run the file to confirm today's tests still pass before changing behaviour.
- [ ] **Step 4: Run the file to see every test pass**, then `flutter analyze`.
- [ ] **Step 5: Commit** `feat(species-id): scan a video from where the diver is watching and name fish in view`.

### Task 7: The service takes playhead reports

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (`followPlayhead`, `cancelPending`, fields)
- Modify: `lib/features/species_id/data/services/media_identification_video.dart` (`_refreshVideo`, `_scanVideo`)
- Test: `test/features/species_id/data/media_identification_service_video_test.dart`

**Interfaces:**
- Consumes: Task 3's `PlayheadReport`, Task 6's scan.
- Produces: `void followPlayhead(String mediaId, int positionMs, {required bool seek})` on `MediaIdentificationService`: keeps the latest report per media id with a rising sequence; `cancelPending(mediaId)` forgets it.

Changes: `_scanVideo` passes `playhead: () => _playheads[job.item.id]` and no `stored`; after each `runChunk` it calls `reconcile(job.item.id)` before reporting progress; the resume branch's `ahead` keeps rows the diver spoke for that `!from.scanned.coversRange(startMs, endMs)`.

- [ ] **Step 1: Write the failing tests**:
  - `a seek reported while a video is scanned moves its next chunk` (the fake engine's detect calls show the jump);
  - `a report made before the scan starts is used for its first chunk`;
  - `leaving the video forgets its report` (a later request starts at the first gap from 0);
  - `a report for another video changes nothing`;
  - `a tag accepts a fish named mid-scan before the scan ends` (reconcile after each chunk).
- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/species_id/data/media_identification_service_video_test.dart`

- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file to see every test pass.**
- [ ] **Step 5: Commit** `feat(species-id): the scan hears where the diver seeks`.

### Task 8: The viewer reports the playhead

**Files:**
- Create: `lib/features/species_id/presentation/widgets/video_playhead_reporter.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_video_item.dart` (mount it beside `VideoIdentificationLayer`)
- Test: `test/features/species_id/presentation/video_playhead_reporter_test.dart`

**Interfaces:**
- Consumes: Task 7's `followPlayhead`.
- Produces: `class VideoPlayheadReporter extends ConsumerStatefulWidget { const VideoPlayheadReporter({super.key, required ValueListenable<VideoPlayerValue> playback, required MediaItem item, Duration settle = const Duration(milliseconds: 500), int jumpMs = 1500, int backMs = 250}); }`. Draws nothing.

Behaviour: on each player value, compare with the previous position; a forward change over `jumpMs` or a backward change over `backMs` (re)starts a `settle` timer, which reports `followPlayhead(id, position, seek: true)` with the position when it fires. A change from playing to paused reports `seek: false` at once. Nothing is reported during steady playback. Not reported with the flag off.

Mounted in `media_viewer_video_item.dart` when `marineLifeIdEnabled && widget.isCurrent`, independent of tag mode and white-point picking (the scan follows the playhead even while labels are hidden).

- [ ] **Step 1: Write the failing widget tests** with a `ValueNotifier<VideoPlayerValue>` and a fake service recording calls (extend `species_id_fakes.dart`):
  - steady playback in 500 ms steps reports nothing;
  - a jump from 5000 to 60000 reports `(60000, seek: true)` 500 ms later, once;
  - a scrub through 60000, 61000, 65000 within 500 ms reports only 65000;
  - pausing reports `seek: false` at the paused position;
  - nothing with `marineLifeIdEnabled` false (restored in `addTearDown`).
- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/species_id/presentation/video_playhead_reporter_test.dart`

- [ ] **Step 3: Implement and mount.**
- [ ] **Step 4: Run the test file and `test/features/species_id/presentation/video_identification_layer_test.dart` to see them pass**, then `flutter analyze`.
- [ ] **Step 5: Commit** `feat(species-id): the video viewer tells the scan where the diver is watching`.

### Task 9: Documents

**Files:**
- Modify: `docs/design/specs/2026-11-17-marine-life-identification-program-design.md` ("How labels look on video": suggestions while playing; "Video analysis" and "The pieces, in order": live naming is the scan following the playhead on every device, issue #4709)
- Modify: `docs/developer/species-identification.md` (scan order, early naming, renaming and decisions, `scanned_ranges`, label rule)

- [ ] **Step 1: Edit both documents.** No em-dashes.
- [ ] **Step 2: Run** `python3.14 scripts/check_docs_links.py`. Expected: passes.
- [ ] **Step 3: Commit** `docs(species-id): live naming in the program overview and developer guide`.

### Task 10: Real check and screenshots

- [ ] **Step 1:** Build the macOS debug app, run it on a fresh empty database inside the container with sync off, the published pack installed and a real dive video linked, seek ahead of the scan while playing, and confirm suggestion pills appear there within a few seconds.
- [ ] **Step 2:** Capture the after screenshots matching the before ones, light and dark.
