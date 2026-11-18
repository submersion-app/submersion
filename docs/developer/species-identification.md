# Species Identification

Marine life identification finds fish and other animals in a diver's
photos and videos on the device and suggests what they are (issues #4668,
#4675 and #4691). The design is in
[the program overview](../design/specs/2026-11-17-marine-life-identification-program-design.md),
[the first piece](../design/specs/2026-11-17-marine-life-identification-1-photos-design.md)
(photos) and
[the second](../design/specs/2026-11-17-marine-life-identification-2-video-design.md)
(video), with packs of one or two detectors in
[the two detectors design](../design/specs/2026-11-17-marine-life-two-detectors-design.md).

The feature is on for divers on iPhone, iPad and Mac. This page is for
working on it.

## Where it is on

The flag is `marineLifeIdEnabled` in `lib/core/constants/feature_flags.dart`.
It is on by default wherever the engine runs (iPhone, iPad and Mac, asked of
`visionEngineRuns`) and hidden on the web, Android, Windows and Linux, which
no build define can turn on until they have an engine. A build turns it off
everywhere with:

```bash
flutter run -d macos --dart-define=MARINE_LIFE_ID=false
```

The [release gate design](../design/specs/2026-11-18-marine-life-release-gate-design.md)
records why it is on: the first published pack carries both detectors (the
Community Fish Detector, whose authors leave the terms of its weights to the
user, and FathomNet's Megalodon, CC BY 4.0 but trained with AGPL code), and
its confidence bars come from measured accuracy. Each detector set measured
on the 9,151-candidate list (packs `2026.11.18.0030` and `2026.11.18.0356`)
is written with its bars; any other pack, a rebuilt candidate list included,
is marked `provisional` until the scorer is run on it, so a pack to publish
is checked for `"provisional": false` first.

Phones and tablets need 8 GB of memory at launch: the floor is `MemoryFloor`
in `MemoryReading.swift`, 6.5 GiB as the device reports it, checked by
`tool/species_pack/vision_cli/check_floor.sh` in the Build iOS job.

## How it fits together

| Part | Where |
| --- | --- |
| Native engine (Core ML) | `packages/submersion_vision/` (video passes in `VideoScanner.swift`) |
| Pack format, download, install | `lib/features/species_id/data/pack/` |
| Naming and decision rules (pure Dart) | `lib/features/species_id/domain/services/` |
| Analysis queue | `lib/features/species_id/data/services/media_identification_service.dart` |
| A video's scan, chunk by chunk | `lib/features/species_id/data/services/video_identification_scan.dart` |
| Tracking and labels (pure Dart) | `lib/features/species_id/domain/services/video_tracker.dart`, `track_labels.dart` |
| Labels over a video | `lib/features/species_id/presentation/widgets/video_identification_layer.dart` |
| Viewer trigger and suggestions | `lib/features/species_id/presentation/widgets/` |
| Settings page | `lib/features/species_id/presentation/pages/` |
| Pack builder | `tool/species_pack/` |

What is stored:

- Identifications and the diver's decisions: the main database,
  `media_identification_runs` and `media_identifications`. Never synced.
- Crop embeddings: the device-local cache, `identification_embeddings`.
- Crops: `<application support>/species_id/crops/`.
- The installed pack: `<application support>/species_id/pack/`, excluded
  from device backups.

## Building a pack

The builder needs Python 3.14 and about 3 GB for its tools and models:

```bash
python3.14 -m venv .venv-species-pack
```

```bash
.venv-species-pack/bin/pip install -r tool/species_pack/requirements.txt
```

```bash
.venv-species-pack/bin/python tool/species_pack/build_pack.py --out build/species_pack
```

It downloads the models from pinned sources and checks their hashes,
converts them to Core ML, builds the candidate list from the catalogue and
GBIF (the species most photographed there, then the species divers record
most in shallow surveys, which BioCLIP 2 names from their names alone, so
they need no photos), embeds every candidate's name, and maps where each
species has been recorded from GBIF's density maps. GBIF responses and
converted models are kept in `build/species_pack_work`, so a second run is
quick.

Useful options:

- `--max-candidates N` (default 10000) caps the candidate list. A small
  number makes a quick pack for development. Photographed species fill it
  first, so a small pack leaves out the species that come only from
  surveys.
- `--min-images N` (default 50) is how many photographed observations a
  species needs on GBIF to be a candidate.
- `--min-survey-records N` (default 50) is the other way in: how many
  human observations at 0 to 40 m a species needs, photographed or not.
  Only sightings count (monitoring programmes also publish a row for every
  species not seen), and records without a depth do not.
- `--detectors cfd|megalodon|both` (default `cfd`) chooses the detectors
  the pack carries: the Community Fish Detector, FathomNet's Megalodon, or
  both, whose boxes the app merges (issue #4691). Megalodon must be
  converted first with `megalodon.py convert` (see "Measuring accuracy");
  `--megalodon-work` names the work folder it was converted in. The pack
  credits only the detectors it carries, and fits crops as they were
  measured: centre crop with the fish detector or both, pad-to-square with
  Megalodon alone.
- `--skip-models` reuses the converted models in the work folder.
- `--version` names the pack; it defaults to the UTC date and time, so two
  builds on one day are two versions.

### The manifest

`manifest.json` is format 2: a `detectors` list of one or two entries, each
with its `id`, `format` (`rfdetr` or `yolo`), `file` (the model is
`<file>.<engine>.zip`, unpacked into `<file>/`) and input settings; a
`boxes` block with the crop padding and, for two detectors, how their boxes
merge (`mergeIoU` 0.5, at most `maxBoxes` 8, exactly as
`tool/species_pack/boxes.py` merges); then the classifier, naming bars,
region grid and files. The app still reads a format 1 manifest (one
`detector` block, the fish detector) and refuses any later format with "This
model needs a newer version". A pack that needs app code an older app lacks
must raise the format, so a downloaded pack changes data, never features.

With two detectors the native pipeline runs each in its own format, then
pools their boxes in the manifest's order, best score first, and keeps a box
only if it overlaps every kept one by less than `mergeIoU`. A pack with one
detector returns that detector's boxes as they are. Each stored
identification records its detector set: one detector's own id, or both
joined with `+`, so a photo is detected again when the set changes. Only
the ids are compared, so a detector's id must change with any of its
settings (or the shared `boxes`); `manifest_test.py` pins each detector's
settings to its id and fails when one changes alone.
`tool/species_pack/vision_cli/check_merge.sh` checks the Swift merge against
`boxes.py`'s cases on a Mac, and CI runs it on macOS
(`.github/workflows/vision-merge-check.yml`) whenever the vision plugin or
its tools change.

The pure parts have tests that CI runs:

```bash
python3.14 tool/species_pack/manifest_test.py
```

```bash
python3.14 tool/species_pack/region_grid_test.py
```

The region grid is written twice, in Python and in
`lib/features/species_id/domain/services/region_grid.dart`. Both are
checked against `tool/species_pack/testdata/region_vectors.json`; after a
change to the Python side, regenerate it with
`python3.14 tool/species_pack/region_grid.py --write-vectors tool/species_pack/testdata/region_vectors.json`.

## Publishing a pack

The app reads the pack from the `species-pack` release: `manifest.json`
first, then every file it lists, resolved next to the manifest. Pack
`2026.11.18.0356` (both detectors) was published there on 2026-11-18.

- **Always a pre-release.** The app's update check and the macOS appcast
  read GitHub's `releases/latest`. A pack release marked latest would
  replace the newest app version there for every user. Keep it a
  pre-release and pass `--latest=false`.
- **Draft first.** Create the release with `--draft`, upload every file
  and the manifest, check the sizes, then publish with
  `gh release edit species-pack --draft=false --prerelease --latest=false`.
  A diver never sees a manifest whose files are still uploading.
- **Measured bars only.** Check the manifest says `"provisional": false`
  before it goes up. To change only credits or other manifest fields,
  regenerate the manifest over the measured files with
  `manifest.build_manifest` rather than rebuilding, which fetches GBIF
  again and can change the naming files by a byte.
- **Replacing a pack** means uploading the new files with
  `gh release upload species-pack --clobber`, the manifest last.

## Measuring accuracy

The naming bars in a pack come from a measurement, described in
[the measured accuracy design](../design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md)
and reported in `docs/design/findings/`. The test set is a list of openly
licensed iNaturalist and Wikimedia Commons photos,
`tool/species_pack/testdata/accuracy_set.csv`; the photos themselves are
never committed. Everything below runs on a Mac, in the pack builder's venv
with `ultralytics` added for Megalodon:

```bash
.venv-species-pack/bin/pip install ultralytics
```

To measure again on the same photos (after a candidate list change, say),
fetch what the committed list names into the work folder
(`build/species_accuracy_work` by default, `--work` to change it), convert
Megalodon, checking it against PyTorch on any photo with an animal in it,
and score the pack:

```bash
.venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py photos-from-csv
```

```bash
.venv-species-pack/bin/python -I tool/species_pack/megalodon.py convert megalodon-2024 --check-image PHOTO
```

```bash
.venv-species-pack/bin/python -I tool/species_pack/score.py --pack build/species_pack
```

Drawing a new test set is longer, and replaces the list the findings were
measured on. Each stage caches in the work folder and resumes if stopped:

```bash
for stage in pool labels photos underwater review-sheets commons; do .venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py $stage; done
```

The junk contact sheets run both detectors, each alone; Megalodon comes from
the pack when it carries it, otherwise convert it first (as above):

```bash
.venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py junk-sheets --pack build/species_pack
```

Look over the review sheets and mark each out-of-water photo in
`underwater_overrides.json` in the work folder (`{"<observation id>":
false}`), and label each junk box in `junk_labels.json` as `person`,
`scenery`, `animal` or `unclear`, keyed `detector:photo:box`. Then write the
CSV, which needs `--force` because it replaces the committed one:

```bash
.venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py write --force
```

The scorer runs the app's own Swift pipeline through a small command-line
tool (`tool/species_pack/vision_cli/`), once per detector set (the fish
detector, Megalodon, both) and crop fitting. The pack must carry the fish
detector; Megalodon comes from the pack, or from its converted model when
the pack has none. The pair runs through the pipeline's own merge, and the
run stops unless every photo's merged boxes equal `boxes.py`'s merge of that
run's per-detector boxes. The scorer names every crop with `naming.py`,
chooses bars on the tune half and checks them on the held-out half, and
writes `report.md` and `results.json` to the work folder. It recommends a
detector set only if the set returns a box in at least 70% of held-out
photos in every animal group. `results.json` holds a `measured` entry for
each set at its chosen fitting: copy the ones for packs you will build into
`NAMING_MEASURED` in `tool/species_pack/manifest.py`. Each names its
detector ids in order, classifier, fitting and `contents` (the SHA-256 of
the pack's `candidates.json`, `text_embeddings.f16` and `regions.bin`); a
pack is written with those bars only when it is that exact pack.

The tool compiles a model package once and deletes it, so the scorer and
the junk sheets hand it a copy of Megalodon's converted package
(`<work>/models/megalodon-2024-tool/`), and the package itself stays for
building a pack.

The pure parts have tests that CI runs, beside the others above:
`naming_test.py`, `bars_test.py`, `metrics_test.py`, `testset_test.py` and
`boxes_test.py`. `naming.py` copies
`lib/features/species_id/domain/services/species_namer.dart`; both are
checked against `tool/species_pack/testdata/naming_vectors.json`, which
`python3.14 tool/species_pack/naming.py --write-vectors tool/species_pack/testdata/naming_vectors.json`
regenerates.

## Trying a pack locally

Serve the pack folder and point the app at its manifest:

```bash
cd build/species_pack && python3.14 -m http.server 8765
```

```bash
flutter run -d macos --dart-define=SPECIES_PACK_MANIFEST_URL=http://localhost:8765/manifest.json
```

Then open Settings, Data, Photos and videos, Marine life identification,
and download the model. Opening a photo in the viewer analyses it.

## Video

Opening a video in the viewer scans it, after the same dwell as a photo,
while it plays. The scan works in 10 second chunks:

1. **Pass 1, native.** `detectVideo` decodes the chunk in order with
   `AVAssetReader`, frames at most 960 pixels on the longer side, and runs
   the detector four times a second. Boxes come back normalised to the
   video as the player shows it (the track's rotation applied).
2. **Tracking, Dart.** `VideoTracker` links each frame's boxes to the open
   tracks by overlap. A track missed for more than two samples closes; one
   seen once is dropped. Open tracks carry into the next chunk.
3. **Pass 2, native.** For the tracks a chunk closed, `embedMoments` seeks to
   each track's best moments (up to three, a second apart) at full size and
   crops and embeds them, exactly as a photo's boxes are.
4. **Naming, Dart.** A track is named once, from the average of its moments'
   embeddings, with the same rules as a photo crop. Whether it is confident
   and whether it looks specific enough for a dot are stored with it.

Each chunk is stored with how far the scan got (`scanned_ms` on the run), so
leaving the video, a newer request, a pack change or the app going to the
background stops the scan between chunks and the next opening resumes it.
The tracks still open at a stop are stored too. As many as one batch of
moments (12) are named, the fish with no name yet first, so stopping stays
quick. The rest keep their path with no best moment, crop or name (a pending
row: `best_ms` is null), show no label, and are named when the scan resumes.
A stop or a failure part-way through a chunk's pass 2 stores nothing of that
chunk: the tracks go back to where it began and are all kept unnamed.
Each track is one `media_identifications` row with its time range, the box at
each sample packed into `track_path`, and any species the diver gave it from
the frame (`claimed_species_id`).

On a 4K clip on an M-series Mac, pass 1 runs at about ten times real time.
Pass 2 costs about 85 ms a moment, so a dense school (about 500 moments in 50
seconds) takes most of the time. Neither has been measured on a phone.

What is checked by hand, since no automated test runs the real models:
labels sit on the fish in a landscape and a portrait clip, and a diver or a
hand in frame gets no dot.

## Memory readout

For measuring memory on a phone, the app logs its memory after each
identification stage while debug mode is on (tap the version line in
Settings, About, five times). Read the lines in Settings, About, View log,
where they can be copied or shared. With debug mode off, or with no log
file to write to, nothing is read.

Each stage writes one line: after the models load, after a photo, after
each 10 second chunk's pass 1 and pass 2, and after the models unload. A
chunk with no fish to name runs no pass 2 and so has no pass 2 line. The
reading is taken without holding up identification. A line from an iPhone
17 Pro Max:

```text
Memory after pass 2 (0:00 to 0:10): 1891 MiB left, footprint 1485 MiB (peak 2708 MiB), 668 MiB left at the peak, Neural Engine 0 MiB not counted (peak 0 MiB), 718 MiB counted
```

Figures are in MiB (1,048,576 bytes), as in the findings.

- **Left:** how much more the app may use before iOS stops it
  (`os_proc_available_memory()`). On a phone, 0 means none is left or the
  app is over its limit. macOS, the iOS Simulator and an iPhone build
  running on a Mac have no such limit, so their lines leave it out.
- **Footprint:** the memory iOS compares with that limit, and its highest
  point since the app started. A peak set while the app started up hides a
  smaller one during a scan; the footprint on each line still shows the
  trend.
- **Left at the peak:** how close the app came to the limit at that peak,
  worked out against the limit as it is now (iOS can change it). With
  nothing left the limit is unknown, so the line leaves this out.
- **Neural Engine:** the models' memory on the Neural Engine, split into
  what counts toward the footprint and what the system keeps out of it.
  An iPhone counts it; a Mac keeps it out. The not-counted peak needs iOS
  18 or macOS 15; earlier versions report the figure without it. On an
  iPhone the unload line shows it all freed; on a Mac it may still show
  some, freed a moment later.

Use a profile or release build for figures that stand for a diver's phone:
a debug build carries over 1 GB of debug-only memory. The Mac and iPhone
measurements are in
[the phone memory findings](../design/findings/2026-11-17-marine-life-phone-memory.md).
