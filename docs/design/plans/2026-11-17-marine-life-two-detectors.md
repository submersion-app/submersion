# One or two detectors per pack: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A species pack declares one or two detectors in their own model
formats; the app runs them all and merges two runs' boxes exactly as the
scorer did; the tools build, score and pin bars for any of the three sets.

**Architecture:** Manifest format 2 carries a `detectors` list and a
shared `boxes` block (format 1 still parses into the same types). The Swift
`VisionPipeline` holds one `MLModel` per detector and merges in `detect`,
so photos and video pass 1 share it. Python tools gain `--detectors`, a
per-group recommendation floor, and a hard check that the app's merged
boxes equal `boxes.py` on the same run.

**Tech Stack:** Dart/Flutter (Riverpod, equatable), Swift with Core ML,
Python 3.14 tools (standard library for CI-tested modules).

**Spec:** `docs/design/specs/2026-11-17-marine-life-two-detectors-design.md`
(issue #4691)

## Global Constraints

- Format version 2; the app parses formats 1 and 2 and rejects others as
  `unsupportedFormat`.
- `detectors`: 1 or 2 entries; format `rfdetr` or `yolo`; `file` matches
  the safe file-name pattern, unique, not `classifier`. Otherwise
  `malformed`.
- Merge only with two detectors: `mergeIoU` 0.5, `maxBoxes` 8, pooled in
  manifest order, score descending, equal scores keep pool order.
- `cropPadding` 0.10, shared. Fish detector: threshold 0.3, max 8,
  mean/std ImageNet. Megalodon: threshold 0.25, max 8, mean 0, std 1,
  `yolo`, id `megalodon-yolo11x-403704d`.
- Stored detector id: the single id, or ids joined with `+` in manifest
  order.
- Crop fitting per set: `cfd` centreCrop, `megalodon` padSquare, `both`
  centreCrop.
- Recommendation floor: a box in at least 70% of held-out photos in every
  group; none eligible means no recommendation.
- Flag `MARINE_LIFE_ID` stays off; no pack is published.
- No em-dashes; no tool attribution in repo or GitHub text.
- Tests run by file path only, never folders.

## Review Focus

1. A format 1 pack already installed on a device: must still load and run
   as one fish detector, with unchanged boxes and stored detector id.
   Test in Task 3 (parse) and Task 4 (store reads a format 1 install).
2. Two boxes with exactly equal scores from different detectors: the first
   detector's wins, as Python's stable sort. Test in Task 1 merge check.
3. A pair manifest whose second detector's zip is missing for the engine:
   `supportsEngine` false, so the download is refused rather than a
   half-installed pair. Test in Task 3.
4. A second detector entry reusing the first's `file`: malformed, or both
   would unpack into one folder. Test in Task 3.
5. A photo where one detector finds nothing: the pair returns the other's
   boxes merged among themselves at `mergeIoU` (as `boxes.py` does) and
   capped. Test in Task 1 merge check.

---

### Task 1: Swift pipeline runs one or two detectors and merges

**Files:**
- Modify: `packages/submersion_vision/darwin/Classes/VisionPipeline.swift`
- Modify: `tool/species_pack/vision_cli/main.swift`
- Create: `tool/species_pack/vision_cli/merge_check.swift`,
  `tool/species_pack/vision_cli/check_merge.sh`

**Interfaces:**
- Produces (channel `load` args): `detectors: [{path, format, inputSize,
  mean, std, scoreThreshold, maxBoxes}]`, `mergeIoU`, `maxBoxes`,
  `cropPadding`, plus the classifier keys unchanged.
- Produces (Swift): `struct DetectorSettings: Equatable { path; format:
  DetectorFormat; inputSize; mean; std; scoreThreshold; maxBoxes }`;
  `VisionModelSettings.detectors: [DetectorSettings]`, `.mergeIoU: Double`,
  `.maxBoxes: Int`, `.cropPadding: Double`;
  `static func merge(_ runs: [[Box]], iou: Double, limit: Int) -> [Box]`;
  `func detectEach(in: CGImage) throws -> [[Box]]`;
  `detectBoxes(in:)` returns the single run or the merge.
- Produces (CLI): `species_vision --manifest M --detector D [--detector D2]
  --classifier C --crop-fit F [--detector-boxes]`; the manifest may be
  format 1 or 2; `--detector` paths in manifest order; with
  `--detector-boxes` each line also has `"detectorBoxes": [[{x,y,w,h,
  score}], ...]` (pre-merge, per detector).

- [ ] Write `merge_check.swift`: cases mirroring `boxes_test.py` plus
  Review Focus 2 and 5: equal scores across detectors keep the first
  detector's box; one empty run returns the other's top `limit`; overlap
  exactly 0.5 is dropped, 0.49 kept; `limit` caps the total. Exits 1 on
  any failure.
- [ ] Run `check_merge.sh` (swiftc the check with `VisionPipeline.swift`
  and `FlutterShim.swift`); expect a compile failure (no `merge`).
- [ ] Implement settings parsing, per-detector load (one `MLModel` each,
  `load` short-circuits on equal settings), `detectEach`, `merge` (stable:
  sort indices by score descending then pool index), and the photo
  `analyze` using `detectBoxes`; `cropAndEmbed` uses the shared
  `cropPadding`. Pass `withDetectorBoxes` through `analyze` args for the
  CLI only.
- [ ] Run `check_merge.sh`: all cases pass.
- [ ] Update `main.swift` for format 1/2 manifests and repeated
  `--detector`; build with `build.sh`; run it on one test photo with a
  format 1 manifest and compare to the run stored in the accuracy work
  folder (same boxes).
- [ ] Commit `feat(species-id): run one or two detectors in the vision pipeline`.

### Task 2: Pass 1 speed gate

**Files:** none in the repo (scratchpad harness from #4685's memcli,
updated to the Task 1 settings).

- [ ] Copy the memcli harness, point it at this branch's
  `VisionPipeline.swift`/`VideoScanner.swift`, build it.
- [ ] Time pass 1 on `reef_wall_4k.mp4` (27 s 4K60 HEVC) with the fish
  detector alone and with both (converted Megalodon from the accuracy
  work folder), 3 runs each, GPU path.
- [ ] If the pair's median pass 1 time is more than 2x the fish
  detector's: stop and ask Eric. Otherwise record both numbers.

### Task 3: Dart manifest format 2

**Files:**
- Modify: `lib/features/species_id/domain/entities/species_pack_manifest.dart`
- Test: `test/features/species_id/domain/species_pack_manifest_test.dart`,
  `test/features/species_id/domain/manifest_fixture.dart`,
  `test/features/species_id/domain/entity_copy_with_test.dart`

**Interfaces:**
- Produces: `enum DetectorFormat { rfdetr, yolo }`;
  `DetectorConfig { id, format, file, inputSize, mean, std,
  scoreThreshold, maxBoxes }` (cropPadding leaves it);
  `BoxesConfig { mergeIoU, maxBoxes, cropPadding }`;
  `SpeciesPackManifest.detectors: List<DetectorConfig>`, `.boxes:
  BoxesConfig`, `String get detectorSetId` (ids joined with `+`);
  `static const supportedFormatVersions = {1, 2}`;
  `static String modelFile(String stem, String engine) =>
  '$stem.$engine.zip'`; `supportsEngine` checks every detector's file.
  `detector` and `detectorFile` go.

- [ ] Add `manifestV2Map()`/`manifestV2Json()` to the fixture (the
  spec's pair example) and tests: parses both detectors and `boxes`;
  `detectorSetId` is `cfd-...+megalodon-...`; format 1 parses to one
  `rfdetr` detector with file `detector` and `boxes` from its block, and
  `detectorSetId` equals the bare id; format 3 is `unsupportedFormat`;
  zero or three detectors, unknown format, unsafe or duplicate or
  `classifier` file are `malformed`; `supportsEngine('coreml')` false when
  `detector-megalodon.coreml.zip` is missing; copyWith covers the new
  types.
- [ ] Run the two test files; expect failures.
- [ ] Implement; replace `manifest.detector.id` uses in
  `media_identification_service.dart`, `media_identification_video.dart`,
  `video_identification_scan.dart` with `detectorSetId`.
- [ ] Run the test files and `flutter analyze`; pass.
- [ ] Commit `feat(species-id): manifest format 2 with one or two detectors`.

### Task 4: Install, settings and channel for N detectors

**Files:**
- Modify: `lib/features/species_id/data/pack/species_pack_store.dart`,
  `lib/features/species_id/domain/entities/vision_analysis.dart`,
  `lib/features/species_id/presentation/providers/species_pack_controller.dart`,
  `lib/features/species_id/data/services/media_identification_service.dart`
- Test: `test/features/species_id/data/species_pack_store_test.dart`,
  `test/features/species_id/data/channel_vision_engine_test.dart`,
  `test/features/species_id/data/pack_fixture.dart`,
  `test/features/species_id/data/media_identification_service_fixtures.dart`,
  `test/features/species_id/presentation/species_pack_controller_test.dart`

**Interfaces:**
- Produces: `InstalledPack.detectorPaths: List<String>` (manifest order);
  `VisionDetector { path, format, inputSize, mean, std, scoreThreshold,
  maxBoxes }`; `VisionModels { detectors: List<VisionDetector>,
  classifierPath, mergeIoU, maxBoxes, cropPadding, classifier fields,
  cropFit }`; `VisionModels.fromManifest(manifest, {required
  List<String> detectorPaths, required String classifierPath})`;
  `toChannel()` emits the Task 1 keys.

- [ ] Tests: a pair pack unpacks `detector/` and `detector-megalodon/`
  and reports both paths in order; a format 1 install on disk still reads
  (Review Focus 1); a pair pack missing its second model folder is not
  installed; `toChannel()` for a pair sends both detectors with formats
  and the `boxes` values.
- [ ] Run them; expect failures.
- [ ] Implement; update fixtures and callers.
- [ ] Run the five test files and `flutter analyze`; pass.
- [ ] Commit `feat(species-id): install and load every detector a pack carries`.

### Task 5: Pack tools build any detector set

**Files:**
- Modify: `tool/species_pack/manifest.py`, `tool/species_pack/build_pack.py`,
  `tool/species_pack/megalodon.py`
- Test: `tool/species_pack/manifest_test.py`

**Interfaces:**
- Produces: `FORMAT_VERSION = 2`; `DETECTORS = {"cfd": {...}, "megalodon":
  {...}}` (id, format, file, settings); `DETECTOR_SETS = {"cfd": ("cfd",),
  "megalodon": ("megalodon",), "both": ("cfd", "megalodon")}`;
  `CROP_FIT = {"cfd": "centreCrop", "megalodon": "padSquare", "both":
  "centreCrop"}`; `BOXES = {"mergeIoU": 0.5, "maxBoxes": 8, "cropPadding":
  0.10}`; `NAMING_MEASURED`: list of `{naming, detectorIds (list),
  classifierId, cropFit, packVersion, contents, findings}`;
  `naming_for(detector_ids, classifier_id, crop_fit, contents,
  measured=NAMING_MEASURED)`; `build_manifest(*, pack_version, detector_set,
  classifier_id, embedding_size, files, credits, naming=None)`;
  `build_pack.credits_for(detector_set)`; `megalodon.manifest_for` writes
  a format 2 single-Megalodon manifest.

- [ ] Tests: format 2 manifest per set with the right detectors, files
  stems and crop fit; measured bars only for the exact detector ids in
  order (a reversed pair gets provisional); existing measured fish
  detector entry still matches the 0030 pack; credits include Megalodon
  (CC BY 4.0) only with it, the fish detector and RF-DETR only with it.
- [ ] Run `python3.14 -m unittest tool/species_pack/manifest_test.py`;
  expect failures.
- [ ] Implement; `build_pack.py --detectors cfd|megalodon|both` zips each
  detector as `<file>.coreml.zip`, Megalodon from
  `megalodon.converted_dir`'s `detector.mlpackage`.
- [ ] Run the test; pass.
- [ ] Commit `feat(species-pack): build packs with either detector or both`.

### Task 6: Scorer floor and app-pipeline pair run

**Files:**
- Modify: `tool/species_pack/metrics.py`, `tool/species_pack/score.py`
- Test: `tool/species_pack/metrics_test.py`

**Interfaces:**
- Produces: `metrics.groups_below_floor(any_box_by_group: dict[str,
  float], floor=0.70) -> list[str]`; `score.py` results gain `"groups below
  floor"` per set and `"pair agreement": {"photos", "agreeing"}`.

- [ ] Tests: `groups_below_floor` on the findings' numbers (fish detector
  -> `["coral", "crabs", "octopus", ...]` below 0.70; pair -> `[]`);
  `recommend` with floor-ineligible sets passed as not eligible returns
  the pair; none eligible -> None.
- [ ] Run `python3.14 -m unittest tool/species_pack/metrics_test.py`;
  expect failures.
- [ ] Implement; `score.py` takes detectors from the pack when present
  (else converted Megalodon), runs the pair through `species_vision` with
  a format 2 manifest and `--detector-boxes`, re-merges with
  `boxes.merge` and fails the run unless every photo agrees; eligibility =
  junk ok and no group below the floor; the report lists groups below the
  floor per set.
- [ ] Run the test; pass.
- [ ] Commit `feat(species-pack): per-group floor and checked pair runs in the scorer`.

### Task 7: Build and score the pair pack, pin bars

- [ ] Convert Megalodon to `detector.mlpackage` with `megalodon.py
  convert` (layered venv) unless a package already exists.
- [ ] Build `--detectors both` from the candidate session's work folder
  caches; check `candidates.json`, `text_embeddings.f16`, `regions.bin`
  hashes equal pack `2026.11.18.0030`'s.
- [ ] Run `score.py` on it; agreement must be all photos.
- [ ] Add measured entries for all three sets to `NAMING_MEASURED` from
  `results.json`; update tests that pin them; run `manifest_test.py`.
- [ ] Commit `feat(species-pack): measured bars for each detector set`.

### Task 8: Memory, findings and docs

**Files:**
- Modify: `docs/design/findings/2026-11-17-marine-life-measured-accuracy.md`,
  `docs/developer/species-identification.md`,
  `docs/design/specs/2026-11-17-marine-life-identification-program-design.md`
  (Open risks: detector choice is now a pack choice)

- [ ] Run the harness (photo, pass 1, pass 2, unload) for the fish
  detector pack and the pair pack, GPU path; record peaks.
- [ ] Findings: new "Two detectors in one pack" section (floor verdicts,
  pair bars, agreement, pass 1 speed, memory); developer doc: format 2
  and `--detectors`.
- [ ] `python3 scripts/check_docs_links.py`; commit
  `docs(species-id): two detectors in one pack, measured`.
