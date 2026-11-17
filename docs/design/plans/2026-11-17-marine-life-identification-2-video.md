# Marine life identification on video: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scan a linked video for fish when it is opened in the viewer on an iPhone, iPad or Mac, and label the fish during playback with a name pill, a thin line and a dot, behind `marineLifeIdEnabled`.

**Architecture:** Swift runs the detector over a 10 second chunk of the video (pass 1) and returns boxes per sampled frame. Dart links boxes into tracks, picks each track's best moments, asks Swift to crop and embed just those (pass 2), and names the track with the existing `SpeciesNamer`. Tracks are stored as rows of piece 1's `media_identifications` table, with new columns for time, path, claim and label flags (schema 376). A label layer over the video draws pills and dots from pure Dart rules.

**Tech Stack:** Flutter, Riverpod, Drift, Core ML and AVFoundation through `packages/submersion_vision`.

**Spec:** `docs/design/specs/2026-11-17-marine-life-identification-2-video-design.md`. Issue #4675.

## Global Constraints

- Everything stays behind `marineLifeIdEnabled` (`lib/core/constants/feature_flags.dart`); with it off no scan starts and no label is drawn.
- Apple only: `ChannelVisionEngine` already reports `unsupportedPlatform` elsewhere; the web build must compile.
- Sampling: 4 frames a second (`sampleIntervalMs = 250`), chunks of 10 seconds (`chunkMs = 10000`).
- Labels: at most 6 at once, largest box first; a gap over 500 ms has no label; a dot needs `specific` and a track of at least 1000 ms.
- Main schema 376. Neither identification table gains an `hlc` column. Integer columns end in `_ms`.
- Never edit how `VisionPipeline.swift` fits a crop for embedding, `tool/species_pack/`, `SpeciesNamer`, or the naming bars (the measured accuracy piece owns them).
- No em-dashes in any text. No tool attribution anywhere (commits, PR text, comments, files).
- Strings in all 11 locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh. ARB files are feature-grouped: insert each new key beside its neighbours of the same group.
- `media_viewer_page.dart` is at 785 of 800 lines: put viewer changes in `media_viewer_video_item.dart` and `media_viewer_gallery.dart`.
- Run only the test files a task names, by path. Never a folder.

## Review Focus

1. **A pack change while a video scans.** `changePack` must run after the chunk in progress, not after the whole video. Test in Task 11.
2. **A video shorter than a chunk, or a reported length of 0.** The scan finishes after one chunk and never loops. Test in Task 11.
3. **The app leaves the foreground mid-scan (`not_foreground`).** Nothing from that chunk is lost, and the next request resumes from `scanned_ms`. Test in Task 11.
4. **A corrupt `track_path` blob.** The row loads with an empty path and draws no label; nothing throws. Tests in Tasks 2 and 3.
5. **A locked video under unified editing.** Pills and dots draw but taps do nothing, and the tap still plays or pauses the video. Test in Task 13.

---

### Task 1: Schema 376

**Files:**
- Modify: `lib/core/database/tables/identification_tables.dart`
- Modify: `lib/core/database/migrations/helpers/identification_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (after the v375 rung, line ~278)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (after the v375 backstop)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` 375 to 376; append 376 to `migrationVersions` with a comment)
- Regenerate: `dart run build_runner build --delete-conflicting-outputs` (background), then `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v376_identification_video_columns_test.dart`

**Interfaces:**
- Produces columns (Drift getter names in brackets):
  - `media_identification_runs`: `scanned_ms` (`scannedMs`), `video_duration_ms` (`videoDurationMs`), both `integer().nullable()`.
  - `media_identifications`: `start_ms` (`startMs`), `end_ms` (`endMs`), `best_ms` (`bestMs`), all `integer().nullable()`; `track_path` (`trackPath`, `blob().nullable()`); `claimed_species_id` (`claimedSpeciesId`, `text().nullable()`); `confident` and `specific` (`boolean().withDefault(const Constant(false))()`).
- Produces `Future<void> _assertIdentificationVideoColumns()` in `IdentificationMigrations`, using `_addColumnIfMissing` as `scr_flow_migrations.dart` does.

- [ ] **Step 1: Write the failing test**, modelled on `migration_v374_scr_flow_test.dart` and `migration_v375_media_identifications_test.dart`:
  - `'v376 is in the ladder'`: `currentSchemaVersion >= 376`, `migrationVersions` contains 376.
  - `'the floor does not move'`: `minimumCompatibleSchemaVersion < 376`.
  - `'a fresh database has the video columns'`: `PRAGMA table_info` of both tables contains every column above, and still no `hlc`.
  - `'upgrading from 375 adds them empty'`: a raw database at `user_version = 375` with both tables as v375 created them and one row in each; after opening, the new integer, blob and text columns read null and `confident`, `specific` read 0.
- [ ] **Step 2:** `flutter test test/core/database/migration_v376_identification_video_columns_test.dart`. Expected: FAIL (376 not in the ladder).
- [ ] **Step 3:** Add the columns, the helper, the rung `if (from < 376) await _assertIdentificationVideoColumns(); if (from < 376) await reportProgress();` with a comment naming issue #4675, the backstop call, and the version bump. Run build_runner in the background and wait for it, then the SQL column notes generator.
- [ ] **Step 4:** Run the test. Expected: PASS. Also run `test/core/database/migration_v375_media_identifications_test.dart` (unchanged, must still pass).
- [ ] **Step 5:** Commit `feat(species-id): schema 376, video columns on the identification tables`.

### Task 2: Entities and the track path codec

**Files:**
- Create: `lib/features/species_id/domain/entities/track_sample.dart`
- Create: `lib/features/species_id/domain/services/track_path_codec.dart`
- Modify: `lib/features/species_id/domain/entities/media_identification.dart`
- Test: `test/features/species_id/domain/track_path_codec_test.dart`, `test/features/species_id/domain/entity_copy_with_test.dart`

**Interfaces:**
- Produces `class TrackSample extends Equatable { const TrackSample({required int ms, required IdentificationBox box}); TrackSample copyWith({int? ms, IdentificationBox? box}); }`. `ms` is from the start of the video.
- Produces on `MediaIdentification` (all optional in the constructor, so photo code compiles unchanged): `int? startMs`, `int? endMs`, `int? bestMs`, `List<TrackSample> path` (default `const []`), `String? claimedSpeciesId`, `bool confident` (default false), `bool specific` (default false); `bool get isTrack => startMs != null`; `int get durationMs => isTrack ? endMs! - startMs! : 0`. `copyWith` gains the seven fields; `claimedSpeciesId` takes `String? Function()?` so it can be cleared.
- Produces on `MediaIdentificationRun`: `int? scannedMs`, `int? videoDurationMs`; `bool get scanComplete => videoDurationMs != null && (scannedMs ?? 0) >= videoDurationMs!`. `copyWith` gains `int? Function()? scannedMs`, `int? Function()? videoDurationMs`.
- Produces `Uint8List encodeTrackPath(int startMs, List<TrackSample> samples)` and `List<TrackSample> decodeTrackPath(int startMs, Uint8List bytes)`. Layout: byte 0 is version `1`; then per sample a little-endian uint32 offset from `startMs` and four uint16 values `x, y, width, height` each `round(v * 65535)`, clamped to 0..65535. Decoding throws `FormatException` on an unknown version or a length that is not `1 + 12n`.

- [ ] **Step 1: Write failing tests.**
  - `'round trip keeps times exactly and boxes within 1/65535'`: three samples at 1000, 1250, 1500 ms with `startMs` 1000.
  - `'an empty path encodes to the version byte alone'`.
  - `'an unknown version is rejected'` and `'a truncated blob is rejected'`: `throwsFormatException`.
  - `'boxes outside 0..1 are clamped'`: `x: -0.1` decodes as 0, `width: 1.2` as 1.
  - In `entity_copy_with_test.dart`, extend the `MediaIdentification` and `MediaIdentificationRun` cases to every new field, and add `TrackSample`.
- [ ] **Step 2:** Run both test files. Expected: FAIL (missing types).
- [ ] **Step 3:** Implement with `ByteData`.
- [ ] **Step 4:** Run both test files. Expected: PASS, plus `identification_rules_test.dart` unchanged and passing.
- [ ] **Step 5:** Commit `feat(species-id): track entities and their packed path`.

### Task 3: Repository mapping

**Files:**
- Modify: `lib/features/species_id/data/repositories/media_identification_repository.dart`
- Test: `test/features/species_id/data/media_identification_repository_test.dart`

**Interfaces:**
- Consumes Task 1's columns and Task 2's fields and codec.
- Produces: `_toCompanion` / `_fromRow` and `_runToCompanion` / `_runFromRow` carry every new field; `trackPath` is written only for tracks. A blob that fails to decode reads as an empty `path`, and the failure is logged at debug.
- Produces `Future<void> claim(String identificationId, String speciesId)`: sets `claimed_species_id` on that row only if the row still exists.

- [ ] **Step 1: Write failing tests:** `'a track round-trips with its time range, path, claim and flags'`; `'a run keeps scanned and duration'`; `'a photo row keeps null video fields'`; `'a corrupt path reads as no path'` (write the row, then overwrite `track_path` with `X'02'` through `customStatement`); `'claim on a missing row writes nothing'`.
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): store tracks and scan progress`.

### Task 4: Confident and specific, decided at naming

**Files:**
- Modify: `lib/features/species_id/domain/services/identification_rules.dart`
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (`_rename` and `_analyse` store the flags)
- Test: `test/features/species_id/domain/identification_rules_test.dart`, `test/features/species_id/data/media_identification_service_test.dart`

**Interfaces:**
- Produces `({bool confident, bool specific}) namingFlags(NamingResult result, NamingConfig config)`:
  - `specific = result.openScore >= config.minOpenScore`
  - `confident = result.suggestable && top score >= config.confidentScore`. A comment says the no-location bar becomes `config.confidentScoreNoLocation` when the measured accuracy piece adds that field; until then `confidentScore` serves both.

- [ ] **Step 1: Write failing tests** with `manifest_fixture.dart`'s config (0.15, 0.50, 0.70): suggestable with top 0.71 is confident; suggestable with top 0.69 is not; not suggestable with top 0.9 is not confident; open score 0.15 is specific, 0.149 is not. In the service test: `'a photo analysis stores the flags'`.
- [ ] **Step 2:** Run both files. Expected: FAIL.
- [ ] **Step 3:** Implement; set `confident` and `specific` wherever the service builds or renames an identification.
- [ ] **Step 4:** Run both files. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): keep whether a fish was confidently named`.

### Task 5: Decisions on a video

**Files:**
- Modify: `lib/features/species_id/domain/services/identification_rules.dart`
- Test: `test/features/species_id/domain/identification_rules_test.dart`

**Interfaces:**
- Changes `reconcileDecisions(all, tagged, now:)`:
  1. An undecided identification with `claimedSpeciesId` accepts when that species id is in `tagged`, before any other rule, with `decidedSpeciesId` = the claim. A claim whose species is not tagged leaves it undecided.
  2. In `_acceptingTags`, an identification with `isTrack` is matched by name (best name or the highest-ranking fallback) only when `suggestable`. Photos are unchanged.
- Produces `List<MediaIdentification> decisionsAsShown(List<MediaIdentification> stored, List<TaggedSpecies> shown, {required DateTime now})`: `stored` with `reconcileDecisions(stored, shown)` applied in memory, same order.

- [ ] **Step 1: Write failing tests:** `'a claim accepts its track when tagged'`; `'a claim outside the candidates still accepts'`; `'a claim with no tag stays undecided'`; `'a claim wins over a neighbour whose best name is the species'` (the neighbour suggestable, same top species, also accepted by the name rule; assert the claimed one carries the claim's species); `'on video, a weak best guess is not accepted by name'` (track not suggestable, top = tagged species: unchanged); `'on video, the fallback skips tracks that are not suggestable'`; `'photos still accept a non-suggestable best name'` (pins piece 1); `'decisionsAsShown applies held tags without writing'`.
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): a claimed fish takes its tag, and video tags match only suggestions`.

### Task 6: The tracker

**Files:**
- Create: `lib/features/species_id/domain/entities/video_detections.dart`
- Create: `lib/features/species_id/domain/services/video_tracker.dart`
- Test: `test/features/species_id/domain/video_tracker_test.dart`, `entity_copy_with_test.dart`

**Interfaces:**
- Produces in `video_detections.dart` (each with `copyWith` and Equatable):
  - `DetectedBox({required IdentificationBox box, required double score})`
  - `FrameDetections({required int ms, required List<DetectedBox> boxes})`
  - `VideoDetections({required int width, required int height, required int durationMs, required List<FrameDetections> frames})`: `width` and `height` are the display size after the track's transform.
  - `VisionMoment({required int ms, required IdentificationBox box})`
  - `VisionMomentCrop({required int pixelWidth, required int pixelHeight, required Uint8List cropJpeg, required Float32List embedding})`
- Produces in `video_tracker.dart`:
  - `class TrackedAnimal` with `List<({int ms, DetectedBox detection})> points`, `int get startMs`, `int get endMs`, `List<TrackSample> get samples`.
  - `class VideoTracker({double linkOverlap = 0.3, int maxGapSamples = 2})` with `List<TrackedAnimal> add(FrameDetections frame)` (returns the tracks this frame closed), `List<TrackedAnimal> closeAll()`, `int get openCount`.
  - `List<({int ms, DetectedBox detection})> bestMoments(TrackedAnimal track, {int max = 3, int minSpacingMs = 1000})`, ranked by `score * box.area`. When the spacing leaves fewer than `max`, the rest are filled with the next best regardless of spacing.
- Linking is greedy by descending IoU over all (open track's last box, new box) pairs at or above `linkOverlap`. An unmatched box opens a track. A track unmatched for more than `maxGapSamples` consecutive frames is closed. A closed track with one point is dropped, not returned.

- [ ] **Step 1: Write failing tests**, building frames with a helper `frame(int ms, List<IdentificationBox> boxes)`:
  - `'a box moving a little each frame is one track'`;
  - `'two separate fish are two tracks'`;
  - `'a gap of two frames is bridged, three is not'`;
  - `'a one-frame flicker is dropped'`;
  - `'the tracker carries open tracks across add calls'` (frames from two chunks);
  - `'closeAll returns the open tracks'`;
  - `'two fish crossing keep the higher-overlap pairing'`;
  - `'bestMoments ranks by score times area and keeps a second apart'`;
  - `'bestMoments of a short track returns what it has'`.
- [ ] **Step 2:** Run the files. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the files. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): link detections into tracks across a video`.

### Task 7: Label rules

**Files:**
- Create: `lib/features/species_id/domain/services/track_labels.dart`
- Test: `test/features/species_id/domain/track_labels_test.dart`

**Interfaces:**
- Produces `enum TrackLabelKind { confident, suggestion, accepted, dot }`.
- Produces `class TrackLabel` (Equatable, `copyWith`): `String identificationId`, `TrackLabelKind kind`, `IdentificationBox box`, `NamedCandidate? candidate` (confident and suggestion), `String? speciesId` (accepted).
- Produces `IdentificationBox? boxAt(MediaIdentification track, int ms, {int maxGapMs = 500})`: null outside `startMs..endMs`, null when the two samples around `ms` are more than `maxGapMs` apart, otherwise the linear interpolation of the two boxes.
- Produces `TrackLabelKind? labelKind(MediaIdentification shown, {required bool playing, int minDotMs = 1000})`:
  - accepted: `accepted` (playing and paused);
  - rejected: null;
  - undecided, `confident`: `confident`;
  - undecided, `suggestable`, paused: `suggestion`; playing: null;
  - undecided, paused, `specific` and `durationMs >= minDotMs`: `dot`; otherwise null.
- Produces `List<TrackLabel> labelsAt(List<MediaIdentification> shown, int ms, {required bool playing, int maxLabels = 6})`: tracks only, kinds from `labelKind`, positions from `boxAt`, at most `maxLabels`, largest box area first.

- [ ] **Step 1: Write failing tests:** every row of the `labelKind` table above; `boxAt` before, inside, after, at a sample, between samples, across a gap of 600 ms; `labelsAt` caps at 6 by area; a photo row (not a track) is ignored; an empty `path` gives no label.
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): what label each fish gets, and where`.

### Task 8: When a video is scanned or named again

**Files:**
- Create: `lib/features/species_id/domain/services/video_identification_rules.dart`
- Test: `test/features/species_id/domain/video_identification_rules_test.dart`

**Interfaces:**
- Produces `enum VideoRefreshAction { none, resume, rescan, rename }`.
- Produces `VideoRefreshAction decideVideoRefresh({required MediaIdentificationRun? run, required String packVersion, required String detectorId, required String classifierId, required int? cell, required bool cropsPresent, required bool embeddingsPresent})`:
  - null run, `!cropsPresent`, or a different detector or classifier: `rescan`;
  - else `!run.scanComplete`: `resume`;
  - else pack version or cell differs: `rename` when `embeddingsPresent`, else `rescan`;
  - else `none`.
  - A resume whose pack version or cell also differs renames the stored tracks first, then resumes; the service handles that order (Task 11), the rule reports `resume`.
- Produces `({List<MediaIdentification> insert, List<String> deleteIds}) carryTrackDecisions({required List<MediaIdentification> decided, required List<MediaIdentification> fresh})`: a fresh track takes the decision, decided species, decided time and claim of a decided track when their time ranges overlap by at least half of the shorter, and the mean IoU of `boxAt` at their shared sample times is at least `sameAnimalOverlap` (0.5). Each decided track is carried at most once; carried ones are in `deleteIds`.

- [ ] **Step 1: Write failing tests** for each branch of `decideVideoRefresh` and for `carryTrackDecisions`: overlap carried; too little time overlap not carried; same time, different place not carried; a decided track carried once only; a claim is carried.
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): rules for scanning a video again`.

### Task 9: Engine calls in Dart

**Files:**
- Modify: `lib/features/species_id/domain/services/vision_engine.dart`
- Modify: `lib/features/species_id/data/engines/channel_vision_engine.dart`
- Modify: `packages/submersion_vision/lib/submersion_vision.dart`
- Modify: `test/features/species_id/data/fake_vision_engine.dart`
- Test: `test/features/species_id/data/channel_vision_engine_test.dart`

**Interfaces:**
- Produces on `VisionEngine`:
  - `Future<VideoDetections> detectVideo({required String path, required int startMs, required int endMs, required int sampleIntervalMs})`
  - `Future<List<VisionMomentCrop?>> embedMoments({required String path, required List<VisionMoment> moments})`: same length and order as `moments`; null where that frame could not be read or the crop was too small.
  - Codes on `VisionEngineException`: `notForeground = 'not_foreground'`, `tooHot = 'too_hot'`.
- Channel contract (`SubmersionVision.detectVideo(Map)` and `SubmersionVision.embedMoments(Map)`, method names `detectVideo`, `embedMoments`):
  - `detectVideo` args `{path, startMs, endMs, sampleIntervalMs}`; reply `{width, height, durationMs, frames: [{ms, boxes: [{x, y, width, height, score}]}]}`.
  - `embedMoments` args `{path, moments: [{ms, x, y, width, height}]}`; reply a list, each `null` or `{pixelWidth, pixelHeight, crop (Uint8List), embedding (Float32List)}`.
- `FakeEngine` gains `Map<int, List<DetectedBox>> videoFrames` (by ms), `int videoDurationMs`, `Object? videoFailure` (thrown by the next `detectVideo`), recorded `detectCalls` as `(startMs, endMs)`, and `embedMoments` returning an embedding keyed by the moment's box x through `momentEmbeddings`.

- [ ] **Step 1: Write failing tests** with the mock handler restored in `addTearDown`: arguments sent for both calls; reply decoding, including a null entry; `PlatformException('not_foreground')` maps to `VisionEngineException(notForeground)`; `MissingPluginException` maps to `unsupported`.
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): engine calls to detect over a video and embed moments`.

### Task 10: Native video passes

**Files:**
- Modify: `packages/submersion_vision/darwin/Classes/VisionPipeline.swift`
- Create: `packages/submersion_vision/darwin/Classes/VideoScanner.swift`
- Modify: `packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift`

**Interfaces:**
- `VisionPipeline`, no AVFoundation import:
  - `func detectBoxes(in image: CGImage) throws -> [DetectedBoxOut]` (internal): the existing detector step, now callable on a decoded frame; `analyze` uses it.
  - `func cropAndEmbed(_ image: CGImage, x: Double, y: Double, w: Double, h: Double) throws -> [String: Any]?` (internal): the padding, crop, thumbnail and `embed` steps `analyze` performs per box today, moved unchanged; `analyze` calls it. Returns the reply map piece 1 sends per detection minus the box and score, or nil when the crop is under 2 px.
  - `static func decodeImage(...)` stays as it is.
- `VideoScanner(pipeline:)`:
  - `func detect(_ args: [String: Any], stillWanted: () -> Bool) throws -> [String: Any]`: `AVAssetReader` on the first video track, time range `startMs..<min(endMs, duration)`, output settings `kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA` with width and height scaled so the longer side is at most 960. Keeps the frame nearest each sample time, applies the track's `preferredTransform` (orient the `CGImage` before detection), runs `detectBoxes`, one autorelease pool per frame. Returns early with what it has when `stillWanted()` turns false. Reply as in Task 9, with `width` and `height` from `naturalSize.applying(preferredTransform)` (absolute values).
  - `func embed(_ args: [String: Any]) throws -> [Any]`: `AVAssetImageGenerator`, `appliesPreferredTrackTransform = true`, zero tolerances, `maximumSize` 4096 square; for each moment `cropAndEmbed`; `NSNull()` where a frame fails.
- `SubmersionVisionPlugin`:
  - New cases `detectVideo` and `embedMoments` through `run`.
  - On iOS, observe `UIApplication.willResignActiveNotification` and `didBecomeActiveNotification` into a lock-protected `isActive` flag; both calls throw `VisionError.notForeground` (code `not_foreground`) when inactive, and `detect` passes `{ self.isActive }` as `stillWanted`.
  - Both calls throw `VisionError.tooHot` (code `too_hot`) when `ProcessInfo.processInfo.thermalState` is `.serious` or `.critical`.

- [ ] **Step 1:** Make the `VisionPipeline` extraction and confirm the photo path is unchanged: `flutter build macos --debug` (background, `timeout -k 30 1200`), run the app against the local pack, open a photo, see the same suggestions as before.
- [ ] **Step 2:** Add `VideoScanner.swift` and the plugin cases. Build again. Expected: build succeeds with no new warnings in `submersion_vision`.
- [ ] **Step 3:** Check by hand once Task 13 is in: open the grunts clip and the rock beauty clip; labels sit on the fish. A portrait clip, if one is in the library, draws its labels upright.
- [ ] **Step 4:** Commit `feat(species-id): detect over a video and embed chosen moments on Apple devices`.

### Task 11: Scanning a video in the service

**Files:**
- Create: `lib/features/species_id/data/services/video_identification_scan.dart`
- Modify: `lib/features/species_id/data/services/media_identification_service.dart`
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart`
- Test: `test/features/species_id/data/video_identification_scan_test.dart`, `test/features/species_id/data/media_identification_service_test.dart`

**Interfaces:**
- Produces `typedef VideoFileReader = Future<T?> Function<T>(Future<T> Function(String path) read);`
- Produces `class VideoIdentificationScan` (one per running video job): constructor takes the engine, `LoadedPack`, repository, embeddings, crops, `MediaItem`, `int? cell`, `VideoFileReader reader`, `now`, `newId`, `databaseGeneration`, `chunkMs = 10000`, `sampleIntervalMs = 250`.
  - `Future<bool> runChunk()`: one pass 1 call for `[scannedMs, scannedMs + chunkMs)`, feeds the tracker, names and stores the tracks it closed (pass 2, `namingFlags`, crops, embeddings, `carryTrackDecisions` against decided tracks when rescanning), updates the run's `scannedMs` and `videoDurationMs`. Returns whether more remains. A `durationMs` of 0 or below stores the run as complete with no tracks.
  - `Future<void> finish()`: `closeAll`, then names and stores those tracks.
  - `double get progress`: `scannedMs / videoDurationMs`, 0 before the first chunk.
- Changes `MediaIdentificationService`:
  - Constructor gains `required Future<VideoFileReader?> Function(MediaItem item) resolveVideo`.
  - `_process` sends `MediaType.video` items to `_processVideo`, which applies `decideVideoRefresh`: `none` stops; `rename` renames tracks from embeddings as `_rename` does for photos; `rescan` deletes undecided tracks, keeps decided ones for carrying, and starts at 0; `resume` (after renaming stored tracks if pack or cell changed) starts at `scannedMs`.
  - Between chunks the job stops (calling `finish()`) when its request was cancelled, `_paused > 0`, a newer request is waiting, the service is disposed, or the generation moved. A stop by a newer request re-queues the video at the oldest end of `_waiting`, so it continues after.
  - `cancelPending(mediaId)` on the running video sets its cancel flag and returns true.
  - Engine failures: `not_loaded` reloads once and retries the chunk; any other `VisionEngineException` (including `not_foreground`, `too_hot`) calls `finish()` and ends the job.
  - Produces `double? progressOf(String mediaId)`: the running video's progress, else null.
- `species_id_providers.dart`: `resolveVideo` reads `videoPlaybackProvider(item)`; for `FilePlayback(path)` it returns a reader that calls `videoFileAccessProvider` with `path`, `item.bookmarkRef` and the given `read`; anything else returns null.

- [ ] **Step 1: Write failing tests** in `video_identification_scan_test.dart` (fake engine, in-memory repository as `media_identification_repository_test.dart` builds it):
  - `'a 25 second video is scanned in three chunks'` (detect calls `(0,10000) (10000,20000) (20000,30000)`, run complete at the end);
  - `'a track crossing a chunk boundary is one row'`;
  - `'each stored track has its range, path, best moment, crop, embedding and flags'`;
  - `'a video shorter than a chunk finishes in one'`; `'a reported length of 0 stores a complete run and stops'`;
  - `'finish stores the tracks still open'`.
  And in `media_identification_service_test.dart`:
  - `'leaving the video stops after the chunk in progress and resumes next time'`;
  - `'a pack change waits for one chunk, not the whole video'`;
  - `'a newer photo request runs between chunks and the video continues after'`;
  - `'not_foreground ends the scan and keeps what was stored'`, then a new request resumes from `scannedMs`;
  - `'another logbook opening mid-scan drops the chunk'`;
  - `'no file means nothing recorded'`;
  - `'progressOf reports the running video'`;
  - `'rescan carries a dismissal to the same fish'`.
- [ ] **Step 2:** Run both files. Expected: FAIL.
- [ ] **Step 3:** Implement. Keep `media_identification_service.dart` under 800 lines by putting the per-chunk work in `video_identification_scan.dart`.
- [ ] **Step 4:** Run both files, and `test/features/species_id/presentation/species_id_providers_test.dart`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): scan a video chunk by chunk, resuming where it stopped`.

### Task 12: Trigger, progress, chips and sheet, strings

**Files:**
- Modify: `lib/features/species_id/presentation/widgets/identification_trigger.dart` (`_applies` also for `MediaType.video`)
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (`mediaIdentificationProgressProvider`, `videoTracksProvider`)
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart` (progress chip)
- Modify: `lib/features/species_id/presentation/widgets/suggested_species_section.dart` (progress with percent for video; no count for video; extract `shownTaggedSpecies`)
- Modify: `lib/features/media/presentation/widgets/media_species_sheet.dart` (video title)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/species_id/presentation/identification_trigger_test.dart`, `test/features/species_id/presentation/species_id_providers_test.dart`, `test/features/media/presentation/widgets/media_species_chips_row_suggestions_test.dart`, `test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart`

**Interfaces:**
- Produces `final mediaIdentificationProgressProvider = StreamProvider.autoDispose.family<double?, String>`: yields `service.progressOf(mediaId)` now and on every activity tick.
- Produces `final videoTracksProvider = FutureProvider.autoDispose.family<List<MediaIdentification>, String>`: the media's rows with `isTrack`, re-read on `repository.watchChanges()`; empty when the flag is off.
- Produces `List<TaggedSpecies> shownTaggedSpecies(WidgetRef ref, String mediaId, EditSession<PhotoRecord>? sitting)`, extracted from `suggestionsShown`, which then uses it.
- New strings (English shown; translate for the other 10):
  - `media_species_sheetTitleVideo`: "Species in this video"
  - `media_species_scanProgress`: "Looking for fish, {percent}" (`percent` a String, formatted with `NumberFormat.percentPattern`)
  - `media_species_unnamedFish`: "Unnamed fish, tap to name"
  - Dismiss reuses the existing `media_species_dismiss`.
- Changed strings (all 11 locales):
  - `settings_speciesId_toggle`: "Identify fish when I open a photo or video"
  - `settings_speciesId_intro`: "Finds fish in your photos and videos and suggests what they are. Runs on this device. Your photos and videos never leave it."
  - `settings_speciesId_entrySubtitle`: "Find fish in your photos and videos and suggest what they are"

- [ ] **Step 1: Write failing tests:** the trigger asks for a video after the dwell and cancels it on swipe; the progress provider follows the service; the chips row shows a progress chip with "40%" for a running video and none when done; the sheet's title reads "Species in this video" for a video; a video suggestion with two tracks shows no count; the settings toggle reads the new text.
- [ ] **Step 2:** Run those four files and `test/features/species_id/presentation/marine_life_identification_page_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement and add the strings; run `flutter gen-l10n`.
- [ ] **Step 4:** Run the same files. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): scan videos on opening, with progress and video wording`.

### Task 13: The label layer and naming from the frame

**Files:**
- Create: `lib/features/species_id/presentation/widgets/video_identification_layer.dart`
- Create: `lib/features/species_id/presentation/widgets/track_label_painter.dart` (pill, line and dot drawing)
- Modify: `lib/features/species_id/presentation/widgets/suggested_species_section.dart` (`_CropView` becomes public `SuggestionCropView` with optional `trackId`, Dismiss and Other species when given one)
- Modify: `lib/features/media/presentation/widgets/media_species_sheet.dart` (extract `pickOtherSpecies`)
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` (`claim`)
- Modify: `lib/features/media/presentation/pages/media_viewer_video_item.dart` and `media_viewer_gallery.dart` (mount, pass `identificationsEditable` and `hideIdentifications`)
- Test: `test/features/species_id/presentation/video_identification_layer_test.dart`

**Interfaces:**
- Produces `Future<void> MediaIdentificationService.claim(String mediaId, String identificationId, String speciesId)`: never throws, writes nothing if the generation moved.
- Produces `Future<void> pickOtherSpecies(BuildContext context, WidgetRef ref, MediaItem item, EditSession<PhotoRecord>? sitting, {void Function(Species species)? onPicked})`: the species sheet's existing picker flow, calling `onPicked` before tagging or holding. `MediaSpeciesSheet` uses it.
- Produces `class VideoIdentificationLayer extends ConsumerWidget({required VideoPlayerController controller, required MediaItem item, EditSession<PhotoRecord>? sitting, required bool editable})`:
  - Listens to the controller; reads `videoTracksProvider(item.id)` and `shownTaggedSpecies`; draws `labelsAt(decisionsAsShown(tracks, shown, now: ...), position, playing: value.isPlaying)` placed with `containedImageRect(value.size, box)`.
  - Each pill sits above its box joined by a thin vertical line to a dot at the box centre; when the pill would leave the top of the video rect it goes below the box instead.
  - Pill text: `candidateDisplayName` for confident and suggestion, the localized species name for accepted (`localizedSpeciesName` with the species' stored name from `allSpeciesProvider`). Pill outlined for confident and suggestion, filled for accepted. Dot only for `dot`.
  - Hit targets of at least 44 by 44 around each pill and dot, only while paused and `editable`. Everything else is `IgnorePointer`, so the player's tap still toggles play.
  - Pill tap (confident or suggestion): `SuggestionCropView` for that track, where Add claims the track then adds the species, Other species opens `pickOtherSpecies` with `onPicked` claiming the track, and Dismiss calls `service.reject(item.id, [trackId])`. Accepted pill tap: `context.push('/species/<id>')`. Dot tap: `pickOtherSpecies` with `onPicked` claiming the track.
  - Semantics: a dot reads `media_species_unnamedFish`; a pill reads its name.
- Mounted in `_VideoItem`'s stack after `VideoPeopleLayer` when `marineLifeIdEnabled && !widget.people.active && !widget.hideIdentifications`.

- [ ] **Step 1: Write failing tests** with `FakeVideoPlatform` from `test/features/media/presentation/pages/video_viewer_test_harness.dart` (restored in teardown) and overridden `videoTracksProvider`:
  - `'playing shows only the confident pill'`;
  - `'paused shows suggestion pills and dots'`;
  - `'a dot needs a second and a specific crop'`;
  - `'an accepted track shows a filled pill with the tagged name'`;
  - `'held tags change the labels before Save, Cancel restores them'`;
  - `'tapping a dot opens the picker and claims the track'`;
  - `'tapping a pill opens the crop view with Other species and Dismiss'`;
  - `'a locked video draws labels but ignores taps, and the tap still pauses'`;
  - `'nothing is drawn with the flag off'`;
  - `'labels sit inside the contain-fitted video rect'` (a 16:9 video in a square box: a box at x 0..0.1 lands right of the top letterbox bar).
- [ ] **Step 2:** Run the file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the file, plus `test/features/media/presentation/widgets/media_species_sheet_test.dart`, `media_species_sheet_suggestions_test.dart`, and any test file touching `media_viewer_video_item.dart` found with `grep -rl "_VideoItem\|VideoPeopleLayer" test/`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(species-id): name pills and dots over a playing or paused video`.

### Task 14: Docs and finish

**Files:**
- Modify: `docs/developer/species-identification.md` (a "Video" section: how a scan runs, its storage, how to try it against a local pack, what is checked by hand)
- Modify: shared notes file for the parallel accuracy session (outside the repo), naming the `VisionPipeline.swift` extraction

- [ ] **Step 1:** Write the docs section.
- [ ] **Step 2:** `dart format .`, `flutter analyze` (whole repo, no issues), and every test file this plan created or changed, by path.
- [ ] **Step 3:** Commit `docs(species-id): video identification for developers`.
