# Marine life identification: one or two detectors per pack

Part of the marine life identification program
([program design](2026-11-17-marine-life-identification-program-design.md)).
Refs #4668. Release v1.8.5. Everything stays behind `MARINE_LIFE_ID` (off).

## Why

"It's important that it understand coral and crabs etc." (Eric, 2026-11-17).

The namer (BioCLIP 2) knows corals and invertebrates, and the candidate list
carries them, but it only names what the detector boxes. The Community Fish
Detector boxes fish well and little else. Held-out results from the
measured accuracy findings
([findings](../findings/2026-11-17-marine-life-measured-accuracy.md)),
share of photos with any box, then share whose largest box was named right:

| Group | Fish detector | Megalodon | Both |
| --- | --- | --- | --- |
| fish | 95%, 53% | 80%, 42% | 98%, 55% |
| octopus | 62%, 22% | 79%, 40% | 90%, 47% |
| crabs | 50%, 19% | 65%, 38% | 77%, 42% |
| snails and nudibranchs | 60%, 23% | 90%, 50% | 95%, 51% |
| sea stars | 68%, 32% | 84%, 61% | 91%, 66% |
| coral | 40%, 5% | 83%, 35% | 92%, 44% |

The app can run only one detector of the RF-DETR kind today. Letting a pack
carry one or two detectors, each in its own model format, means the
deferred licence decision (the fish detector's weights carry no licence;
Megalodon's are CC BY 4.0 but trained with AGPL code) becomes only a choice
of which pack to publish: fish detector alone, Megalodon alone, or both.

## Goals

- A pack declares one or two detectors, each with its own model format
  (`rfdetr` or `yolo`), model file and settings.
- The app runs every detector a pack declares on each photo and on each
  video pass 1 frame, and merges the boxes exactly as the scorer did, so
  the measured bars hold.
- The pack tools build a pack with either detector or both, with the right
  credits and crop fitting, and pin measured bars to each exact pack.
- The scorer's detector recommendation stops being fish-weighted.
- A pack with both detectors is built locally and scored; its bars go into
  `manifest.py`; the findings are updated; memory and video pass 1 speed
  are measured with the command-line harness.

## Non-goals

- Publishing a pack, turning the flag on, or settling either licence.
  Contacting model authors.
- More than two detectors. Detectors chosen per photo, per region or per
  diver. A user setting of any kind.
- Training or fine-tuning a detector.
- Android or other engines (the manifest stays engine-keyed, as today).

## Anti-goals

- A pair pack whose boxes in the app differ from the boxes the scorer
  measured. That would make its bars meaningless.
- A one-detector pack whose boxes change from today's (its bars were
  measured without any merging).
- An older app loading a pack it cannot run correctly (for example running
  only the first of two detectors under the pair's bars).

## Decisions

Eric's, in the order asked:

1. **Manifest shape: a `detectors` list** of one or two entries, each with
   its own id, format, file and settings, plus a shared `boxes` block for
   merging and crop padding. Format version 2.
2. **Recommendation rule: a per-group floor.** A detector set is eligible
   only if it returns a box in at least 70% of held-out photos in every
   group; among eligible sets, today's rule applies.
3. **Video: both detectors on every pass 1 frame.** If pass 1 more than
   doubles in time on the 4K test clip, stop and ask before going further.
4. **Release v1.8.5.**
5. **Merging happens in the Swift pipeline**, before crops are embedded.
6. **Memory: report only.** No stop point; the harness numbers go in the
   findings and the real iPhone test decides later.

## Approaches considered (where the merge happens)

1. **Swift pipeline (chosen).** `detect` runs each detector in its own
   format and merges before cropping. One decode per image, at most
   `boxes.maxBoxes` embeds; photos and video pass 1 both get merged boxes
   with no other change.
2. **Dart, one plugin call per detector.** Every photo and every video
   frame decoded twice; decoding is where the measured memory peaks come
   from. Ruled out.
3. **Swift returns each detector's boxes, Dart merges.** Easy to unit test
   in Dart, but the photo call crops and embeds in the same call, so it
   would embed up to twice the boxes and drop half, or need the call
   split in two. Not worth it.

## Manifest, format 2

```json
{
  "formatVersion": 2,
  "packVersion": "2026.11.18.1200",
  "detectors": [
    {
      "id": "cfd-rfdetr-nano-640-20260706",
      "format": "rfdetr",
      "file": "detector",
      "inputSize": 640,
      "mean": [0.485, 0.456, 0.406],
      "std": [0.229, 0.224, 0.225],
      "scoreThreshold": 0.3,
      "maxBoxes": 8
    },
    {
      "id": "megalodon-yolo11x-403704d",
      "format": "yolo",
      "file": "detector-megalodon",
      "inputSize": 640,
      "mean": [0.0, 0.0, 0.0],
      "std": [1.0, 1.0, 1.0],
      "scoreThreshold": 0.25,
      "maxBoxes": 8
    }
  ],
  "boxes": { "mergeIoU": 0.5, "maxBoxes": 8, "cropPadding": 0.10 },
  "classifier": { "...": "unchanged" },
  "naming": { "...": "unchanged" },
  "region": { "...": "unchanged" },
  "cropThumbnailSize": 320,
  "files": [
    { "name": "detector.coreml.zip", "engine": "coreml", "...": "" },
    { "name": "detector-megalodon.coreml.zip", "engine": "coreml", "...": "" },
    { "name": "classifier.coreml.zip", "engine": "coreml", "...": "" }
  ],
  "credits": []
}
```

- `detectors` holds one or two entries; none or more than two is
  malformed. `format` is `rfdetr` or `yolo`; an unknown format is
  malformed (it cannot be run, and running it as another format would
  give wrong boxes). `file` is a safe file-name stem, unique among the
  detectors, and not `classifier`; the model for an engine is
  `<file>.<engine>.zip` and installs into the folder `<file>/`.
- `boxes.mergeIoU` and `boxes.maxBoxes` apply only when there are two
  detectors. `boxes.cropPadding` applies to every box (it was the
  detector's in format 1 and is 0.10 for both detectors).
- `supportsEngine` requires every detector's file for that engine.
- **Format 1 stays readable.** The app reads a format 1 manifest as one
  `rfdetr` detector with file `detector`, and `boxes` taken from its
  `detector` block (`maxBoxes`, `cropPadding`, `mergeIoU` 0.5 unused).
  So a pack installed by an earlier build keeps working. An app that
  reads format 2 rejects format 3 and above with "needs a newer version",
  as today.
- An older app (format 1 only) shows "needs a newer version" for a
  format 2 pack, so it never runs a pair pack as a single detector.
- **Stored detector id.** Each identification run stores a detector id,
  and a changed id makes a stored photo detect again. One detector: its
  id, unchanged from today, so photos analysed under a format 1 pack with
  the same fish detector are not redone. Two: the ids joined with `+` in
  manifest order.

## The app

- `VisionModels` (Dart) and `VisionModelSettings` (Swift) carry a list of
  detectors (path, format, input size, mean, std, threshold, max boxes)
  and the shared `mergeIoU`, `maxBoxes` and `cropPadding`. The channel
  sends the list; the plugin is only called by this app, so the flat
  single-detector keys go.
- `VisionPipeline` loads one `MLModel` per detector. `detect` runs each in
  its own format exactly as today (`rfdetr`: straight resize, threshold,
  top `maxBoxes`, no suppression; `yolo`: letterbox, threshold,
  suppression at 0.7, top `maxBoxes`).
- **One detector:** its boxes are returned as today, no merge.
- **Two detectors:** the merge from `tool/species_pack/boxes.py`
  `merge(runs, iou_threshold, max_boxes)`: pool both runs' boxes, sort by
  score best first, keeping pool order (first detector's boxes, then the
  second's, each in its own order) on equal scores as Python's stable
  sort does; keep a box only if its intersection over union with every
  kept box is below `mergeIoU`; stop at `maxBoxes`. Scores from the two
  models are compared as they are, as the scorer did.
- Video pass 1 calls the same `detect`, so it runs both and merges on
  every sampled frame. Pass 2 crops the tracked boxes as today.
- The pack store unpacks every detector's zip into its own folder;
  `InstalledPack` holds one model path per detector. The install's load
  check loads every model.

## Pack tools

- `build_pack.py --detectors cfd|megalodon|both` (default `cfd`, as
  today). Megalodon's model comes from `megalodon.py`'s converted
  `detector.mlpackage` in the work folder (convert is a separate step, as
  today). Credits follow the detectors: BioCLIP 2 and GBIF always; the
  Community Fish Detector and RF-DETR with `cfd`; FathomNet Megalodon
  (MBARI, CC BY 4.0) with `megalodon`, its text noting it was trained
  with Ultralytics' code.
- **Crop fitting per detector set**, the measured choices: centre crop for
  the fish detector and for the pair, pad-to-square for Megalodon alone.
- **Measured bars per exact pack.** `NAMING_MEASURED` becomes a list of
  entries, each pinned to its detector ids (in order), classifier id, crop
  fitting and naming-file hashes. Any other pack gets the provisional
  bars. The scorer's run on the pair pack supplies entries for all three
  sets on the same naming files.
- `manifest.py` writes format 2.

## Scorer

- Measures the same three sets as today (fish detector, Megalodon, both).
  Detector models come from the pack when it carries them, otherwise from
  the converted Megalodon in the work folder, as today.
- **The pair is run through the app's own pipeline** with a two-detector
  manifest, so its numbers are of the boxes the app makes. For that run
  the command-line tool also prints each detector's own boxes before the
  merge, and the scorer merges exactly those boxes with `boxes.py`. Every
  photo must agree; a photo that does not is a bug to fix before the run
  is trusted. (Comparing against the separate single-detector runs would
  not be fair: GPU runs need not repeat scores bit for bit, and a tiny
  score change can flip a tie or an overlap near 0.5. The scorer reports
  how closely the pair run's per-detector boxes match the single runs,
  for information only.)
- **Recommendation rule:** a set is eligible if its junk rate is within
  target (today) and, in every group, it returns a box in at least 70% of
  held-out photos (natural and top-up). Among eligible sets, today's rule
  (most named right, a simpler or explicitly licensed set first when not
  significantly worse). When no set is eligible, no recommendation, and
  the report names the groups below the floor for each set.

## Measurements

- **Memory**, with the command-line harness of the memory findings
  (#4685: the app's own Swift, no Flutter, database or network, 20 ms
  footprint sampling) on the same 50 MP photo and 27 s 4K clip, for the
  fish detector pack and the pair pack, GPU path (`.all`). Reported in
  the findings only, with no stop point (Eric): the open iPhone test
  decides whether the pair fits a phone. The pipeline keeps every model
  loaded, as today.
- **Video pass 1 speed** on the same 4K clip, both packs. If the pair more
  than doubles pass 1's time, stop and ask Eric.

## Findings and docs

- The measured accuracy findings gain a "Two detectors in one pack"
  section: the floor's verdict per set, the pair pack's bars, memory and
  pass 1 speed, and that the pair's app boxes match the scorer's merge.
- `docs/developer/species-identification.md`: building a pack with
  `--detectors`, and the format 2 manifest.

## Left to the builder

- Swift and Dart type names, how the channel encodes the list, and how
  the Swift merge is checked (a check program built like `vision_cli`
  over `boxes_test.py`'s cases, plus the scorer's agreement count).
- Where the per-set crop fitting table lives in `manifest.py`.

## Calls made in writing this (not asked)

- With no set over the floor, no recommendation rather than falling back
  to today's rule.
- Unknown detector format is malformed rather than "needs a newer
  version": a new format arrives with a format version bump anyway.
- `build_pack.py` defaults to the fish detector alone, as today.
- Format 1 manifests stay readable so an installed pack keeps working.
- The app-against-scorer box check compares the pair run with a Python
  merge of that same run's per-detector boxes, as a hard gate.
- Build order: the Swift pipeline and the pass 1 timing come first, so
  the speed stop is reached before the tools work.
