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
`packages/submersion_vision/tool/check_floor.sh` in the Build iOS job.

The setting is Settings, Data, Photos and videos, Species identification,
under its own Species header (issue #4773). Where the model can run and none
is installed, the app also offers the download on a dive's Species card (for
dives with photos or videos), in the photo and video species sheet, and on
the Species page: `speciesDownloadPromptProvider` decides, without asking
the network. Its close button sets `species_id_download_prompt_dismissed` on
this device, and removing the model sets it too; to see the offer again,
clear that preference.

## How it fits together

| Part | Where |
| --- | --- |
| Native engine (Core ML) | `packages/submersion_vision/` (video passes in `VideoScanner.swift`) |
| Pack format, download, install | `lib/features/species_id/data/pack/` |
| Naming and decision rules (pure Dart) | `lib/features/species_id/domain/services/` |
| Analysis queue | `lib/features/species_id/data/services/media_identification_service.dart` |
| A video's scan, chunk by chunk | `lib/features/species_id/data/services/video_identification_scan.dart` (naming in `video_identification_scan_naming.dart`) |
| Tracking, scan order and labels (pure Dart) | `lib/features/species_id/domain/services/video_tracker.dart`, `video_scan_order.dart`, `video_identification_rules.dart`, `track_labels.dart` |
| Labels over a video | `lib/features/species_id/presentation/widgets/video_identification_layer.dart` |
| Where the diver is watching | `lib/features/species_id/presentation/widgets/video_playhead_reporter.dart` |
| Viewer trigger and suggestions | `lib/features/species_id/presentation/widgets/` |
| Settings page | `lib/features/species_id/presentation/pages/` |
| Pack builder | [submersion-app/species-pack](https://github.com/submersion-app/species-pack) |

What is stored:

- Identifications and the diver's decisions: the main database,
  `media_identification_runs` and `media_identifications`. Never synced.
- Crop embeddings: the device-local cache, `identification_embeddings`.
- Crops: `<application support>/species_id/crops/`.
- The installed pack: `<application support>/species_id/pack/`, excluded
  from device backups.

## Building a pack

The builder lives in its own repository,
[submersion-app/species-pack](https://github.com/submersion-app/species-pack)
(issue #4769). Clone it beside this one, as `species-pack`: every pack
command in this guide runs in that clone, and finds the app through
`SUBMERSION_APP` or, without it, the `submersion` clone beside it. Its work
folders go in its own `build/`. It needs Python 3.14 and about 3 GB for its
tools and models:

```bash
cd ../species-pack && python3.14 -m venv .venv-species-pack
```

```bash
.venv-species-pack/bin/pip install -r requirements.txt
```

```bash
.venv-species-pack/bin/python build_pack.py --out build/species_pack
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
the pack repository's `boxes.py` merges); then the classifier, naming bars,
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
The pack repository's `vision_cli/check_merge.sh` checks the Swift merge
against `boxes.py`'s cases on a Mac. This repository's CI runs it on macOS
(`.github/workflows/vision-merge-check.yml`) whenever the vision plugin
changes, and the pack repository's CI runs it against this repository's
main branch.

The pure parts have tests that the pack repository's CI runs. In the clone:

```bash
for test in *_test.py; do python3.14 -I "$test"; done
```

The region grid is written twice, in Python and in
`lib/features/species_id/domain/services/region_grid.dart`. Both are
checked against `region_vectors.json`: the pack repository writes it, and
this repository's tests read their copy in
`test/features/species_id/domain/fixtures/`. The pack repository's
`contract_test.py` fails while the two copies differ, so after a change to
the Python side, regenerate it there with
`python3.14 region_grid.py --write-vectors testdata/region_vectors.json`
and copy it here.

## Publishing a pack

The app reads the latest release of
[submersion-app/species-pack](https://github.com/submersion-app/species-pack):
`releases/latest/download/manifest.json` first, then every file it lists,
resolved next to the manifest. Each pack is a release of its own, tagged
with its version. Pack `2026.11.18.0356` (both detectors) is published there.
It moved from this repository's `species-pack` pre-release, which stays in
place for beta builds that still read it (#4769).

- **Draft first.** Create the release with `--draft`, upload every file
  and the manifest, check the sizes and digests, then publish it, which
  makes it the latest release. A diver never sees a manifest whose files
  are still uploading.
- **Trying a pack before divers get it:** publish it as a pre-release,
  which never becomes the latest, and point a development build at it
  with
  `--dart-define=SPECIES_PACK_MANIFEST_URL=https://github.com/submersion-app/species-pack/releases/download/<version>/manifest.json`.
- **Measured bars only.** Check the manifest says `"provisional": false`
  before it goes up. To change only credits or other manifest fields,
  regenerate the manifest over the measured files with
  `manifest.build_manifest` rather than rebuilding, which fetches GBIF
  again and can change the naming files by a byte.
- **Rolling back** means marking an older pack release latest:
  `gh release edit <version> --repo submersion-app/species-pack --latest`.

## Measuring accuracy

The naming bars in a pack come from a measurement, described in
[the measured accuracy design](../design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md)
and reported in `docs/design/findings/`. The test set is a list of openly
licensed iNaturalist and Wikimedia Commons photos, the pack repository's
`testdata/accuracy_set.csv`; the photos themselves are never committed. Everything below runs on a Mac, in the pack builder's venv
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
.venv-species-pack/bin/python -I fetch_testset.py photos-from-csv
```

```bash
.venv-species-pack/bin/python -I megalodon.py convert megalodon-2024 --check-image PHOTO
```

```bash
.venv-species-pack/bin/python -I score.py --pack build/species_pack
```

Drawing a new test set is longer, and replaces the list the findings were
measured on. Each stage caches in the work folder and resumes if stopped:

```bash
for stage in pool labels photos underwater review-sheets commons; do .venv-species-pack/bin/python -I fetch_testset.py $stage; done
```

The junk contact sheets run both detectors, each alone; Megalodon comes from
the pack when it carries it, otherwise convert it first (as above):

```bash
.venv-species-pack/bin/python -I fetch_testset.py junk-sheets --pack build/species_pack
```

Look over the review sheets and mark each out-of-water photo in
`underwater_overrides.json` in the work folder (`{"<observation id>":
false}`), and label each junk box in `junk_labels.json` as `person`,
`scenery`, `animal` or `unclear`, keyed `detector:photo:box`. Then write the
CSV, which needs `--force` because it replaces the committed one:

```bash
.venv-species-pack/bin/python -I fetch_testset.py write --force
```

The scorer runs the app's own Swift pipeline through a small command-line
tool (the pack repository's `vision_cli/`), once per detector set (the fish
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
`NAMING_MEASURED` in the pack repository's `manifest.py`. Each names its
detector ids in order, classifier, fitting and `contents` (the SHA-256 of
the pack's `candidates.json`, `text_embeddings.f16` and `regions.bin`); a
pack is written with those bars only when it is that exact pack.

The tool compiles a model package once and deletes it, so the scorer and
the junk sheets hand it a copy of Megalodon's converted package
(`<work>/models/megalodon-2024-tool/`), and the package itself stays for
building a pack.

The pure parts have tests that the pack repository's CI runs, beside the
others above:
`naming_test.py`, `bars_test.py`, `metrics_test.py`, `testset_test.py`,
`boxes_test.py`, `levels_test.py`, `report_test.py` (the report's "Naming
levels" section) and `score_test.py` (the measured entries for
`NAMING_MEASURED`). `naming.py` copies
`lib/features/species_id/domain/services/species_namer.dart`; both are
checked against `naming_vectors.json`, which
`python3.14 naming.py --write-vectors testdata/naming_vectors.json`
regenerates in the pack repository. Copy it to
`test/features/species_id/domain/fixtures/` here too: the pack
repository's `contract_test.py` fails while the two copies differ.

## Naming levels

The diver chooses how sure the app must be before it names a fish (issue
#4721), in Settings, Data, Photos and videos, Species identification.
The design is in
[the naming levels design](../design/specs/2026-11-18-marine-life-naming-levels-design.md).

| Level | Suggest bars |
| --- | --- |
| Surer (default) | the pack's own `suggestScore` and `suggestScoreNoLocation` |
| Balanced | measured for a 75% precision target |
| Eager | measured for a 65% precision target |

A level moves only the two suggest bars. The open-score floor, the
minimum box size and the confident bars are the pack's at every level, so
hands, divers and open water stay unnamed.

**Measuring.** `score.py` measures the levels with `levels.measure`, which
chooses each level's bars on the tune half after the pack's own
(`bars.level_bars`): among the bars meeting the target by the same
one-sided Wilson test, the ones naming the most animals right, ties to the
higher (as for the pack's own bars: a lower bar naming no more right adds
only wrong names), never above the level above them, and held to the
same 2% junk cap: while a level names too much junk, each bar that names
some (with a location or without) is raised 0.01 until it passes. A level
that ends at the bars above it, whose held-out interval lies wholly below
its target (`bars.level_gate`), that has no shown figure in (0, 1]
(nothing named, or nothing right, on the side that decides it), or that
shows a higher figure than the level above it is left out, so a pack can
carry one level or none. The
figure shown for a level, and for Surer, is the lower of its held-out
precisions with and without a location (`levels.shown_precision`), so the
settings line never overstates for photos named without a location, where
a level's lower no-location bar can make it less often right
([design](../design/specs/2026-11-19-marine-life-level-accuracy-without-location-design.md)).
The report's "Naming levels" table gives Surer's and each level's
held-out precision and coverage both ways, the shown figure and junk
named, and warns when a shown figure is set by a side naming fewer than
30 held-out crops (`report.SMALL_SIDE`). `results.json`'s `measured`
entries carry the shown figures as `naming.precision` and
`naming.levels` for `NAMING_MEASURED`. `manifest.level_problems` checks
them.

**Publishing.** The levels are optional manifest fields, so they need no
format change and an older app names at Surer. To add them to a published
pack without a new version, download its manifest from that pack's
release into a folder of its own and write the new one beside you:

```bash
gh release download <version> --repo submersion-app/species-pack -p manifest.json -D published
```

```bash
python3.14 relevel_manifest.py --in published/manifest.json --out manifest.json
```

It refuses a pack with no measured entry, or any change but
`naming.precision` and `naming.levels`. Upload only that manifest, to the
same pack's release, with
`gh release upload <version> --repo submersion-app/species-pack manifest.json --clobber`.

**In the app.** A device that has the pack takes a republished manifest of
the same version in place, with nothing downloaded, when its files are
byte for byte the installed ones and only the levels, their precision and
the credits differ (`SpeciesPackManifest.adoptableFrom`). The level is
applied when reading (`naming_levels.dart`, `applyNamingLevel`) to
identifications the installed pack named; the stored `suggestable` column
keeps the pack's own answer, and decisions never change with the level. A
level the installed pack does not carry falls back to the nearest surer
one, and the settings section is hidden when the pack carries none. The
diver's choice is kept through a fallback, so it returns with a pack that
carries it; meanwhile the section selects the level in force and says
which level is missing. Choosing the level in force replaces the stored
choice: its tile is `toggleable` only then, because a radio tile reports
no tap on the selected value otherwise.

## Trying a pack locally

Serve the pack folder and point the app at its manifest:

```bash
cd ../species-pack/build/species_pack && python3.14 -m http.server 8765
```

```bash
flutter run -d macos --dart-define=SPECIES_PACK_MANIFEST_URL=http://localhost:8765/manifest.json
```

Then open Settings, Data, Photos and videos, Species identification,
and download the model. Opening a photo in the viewer analyses it.

## Find species, auto-apply and review

Issue #4727, spec
[2026-11-18-marine-life-identification-4-auto-apply-design.md](../design/specs/2026-11-18-marine-life-identification-4-auto-apply-design.md).

- **Find species** (`DiveSpeciesRun`, `diveSpeciesRunProvider`) walks a
  dive's photos, then its videos, through `MediaIdentificationService`'s run
  lane (`requestFromRun`, in `media_identification_run_lane.dart`). The lane
  is served only when no viewer request waits, is never dropped by the
  viewer, ignores the identify-on-open toggle, and resolves media the way
  playing it would (`runVideoFileOf`), so it may download. Each item returns
  a `RunItemOutcome`; `tooHot` and `notForeground` pause the run.
- **Auto-apply** (`AutoApplier`) tags what `identificationsToApply` picks:
  undecided rows whose stored `confident` flag is set, on a video only once
  `run.scanComplete`. It runs from the service's `onItemSettled` hook for
  viewer requests (one automatic History entry per item) and once at the end
  of a run for all its items (`applyAllInScope`, one entry). The setting is
  disabled while the installed pack's confident bars are both above 1
  (`packCanApply`).
- **The marks** are three nullable columns on `media_species` (schema 378):
  `unconfirmed`, `created_sighting`, `created_species`. Null is the diver's
  own tag. They sync with the tag; a confirm clears them, and a strictly
  newer copy's explicit nulls land through the #2644 clear path
  (`SyncDataSerializer.clockGuardedClearTables`). The compatibility floor is
  378. `SpeciesTaggingService.applyAppTag`, `confirmTag` and `rejectTag`
  hold the sighting and species rules; the guards are pure
  (`app_tag_guards.dart`).
- **Species to review** (`/species/review`, `?dive=<id>` for one dive)
  reads `SpeciesReviewRepository.load`, groups with `buildReviewGroups`, and
  writes on Save through `SpeciesReviewSaver` (one History entry). It works
  where the feature is off, listing the app's tags with thumbnails and no
  suggestions.

To see auto-apply work before a pack has a reachable confident bar, edit the
local pack's `manifest.json` so `naming.confidentScore` is below 1 (for
example 0.6) and bump its `packVersion`, serve it as above, install it, and
turn the setting on. The new version is what makes media already analysed
be named again, which sets their stored `confident` flags; they are then
applied the next time they are opened or a run reaches them.

## Video

Opening a video in the viewer scans it, after the same dwell as a photo,
while it plays. The scan works in chunks: 2 seconds for the first one after
opening or a move, so the first labels come soon, then 10 seconds:

1. **Pass 1, native.** `detectVideo` decodes the chunk in order with
   `AVAssetReader`, frames at most 960 pixels on the longer side, and runs
   the detector four times a second. Boxes come back normalised to the
   video as the player shows it (the track's rotation applied).
2. **Tracking, Dart.** `VideoTracker` links each frame's boxes to the open
   tracks by overlap. A track missed for more than two samples closes; one
   seen once is dropped. Open tracks carry into the next chunk.
3. **Pass 2, native.** For the tracks to name, `embedMoments` seeks to each
   track's best moments (up to three, a second apart) at full size and crops
   and embeds them, exactly as a photo's boxes are.
4. **Naming, Dart.** A track is named from the average of its moments'
   embeddings, with the same rules as a photo crop. Whether it is confident
   and whether it looks specific enough for a dot are stored with it.

### Following the playhead (issue #4709)

The scan follows where the diver is watching. `VideoPlayheadReporter`, in
the viewer's video item, tells the service (`followPlayhead`) of a seek once
the playhead has settled for half a second (a jump of over 1.5 s forward or
0.25 s back between player updates, or, while paused, a move of over 0.25 s
from where the playhead rested, so a slow scrub counts too) and of a pause
once it has lasted half a second, so the pause a scrub starts with never
moves the scan; nothing during steady playback. The service keeps the
latest report per video and forgets it when the diver leaves the video. The
reporter is keyed in the video item's stack: the name labels beside it come
and go with tag mode, and a reporter rebuilt then would forget its report.
Before each chunk, `nextVideoChunk` (`video_scan_order.dart`) picks where to
go: the first unscanned point at or after a new report (a pause on scanned
video counts as none, except for a scan that has not run a chunk yet, which
starts from wherever the diver last was), otherwise on from where the last
chunk ended, and once the end is reached, the gaps from the start. During
playback the scan never chases the playhead, so a slow device scans the
same stretches in the same order. A report that points outside the running
chunk drops it (after pass 1, or between pass 2 batches): nothing of it is
stored, and it is scanned again later.

The stretches scanned are kept on the run (`scanned_ranges`, packed by
`scanned_ranges_codec.dart`). `scanned_ms` stays the end of the stretch that
starts at 0, and a run stored before v377 (no stretches) reads that mark as
one stretch from 0. The scan is complete when the stretches cover the video.

Consecutive chunks share one tracker. When the scan moves, the open tracks
are stored as at a stop and the stored tracks that end just before the new
point are taken up again, so a fish in view there stays one track.

- **Naming in view.** At each chunk's end a track still open and seen for
  at least a second is named and stored, with its path to the end of the
  chunk, so its pill shows while it is still in view. It is named again
  only when a moment seen since is worth 1.5 times the one it was named from
  (detector score times box area); otherwise its path just grows, as it
  does when none of the better view's moments can be cropped.
- **Renaming and decisions.** A renamed fish the diver accepted by a name
  match (accepted, no claim) goes back to undecided if its name changed, and
  the service, which reconciles after every chunk, decides it again under
  the current tags. A claim or a dismissal never changes. In a rescan, a
  fish named while in view can take over what the diver said on the
  previous scan's track of it at any later chunk while nothing is said on
  it yet: named early, it may only later reach far enough to match.
- **Seams.** A chunk that ends where a stretch scanned earlier starts joins
  each open track to a stored track that starts within the gap allowance and
  overlaps its last box, under the later row's id; the earlier row is
  deleted. Two parts the diver said different things about stay apart,
  checked again as the chunk is stored: a decision made while it was named
  undoes the join, and the earlier part keeps its path up to the seam.

Labels: while playing, every undecided fish the app could suggest a name for
shows its outlined pill, as when paused; dots stay paused only.

### Stopping and resuming

Each chunk is stored with the stretches scanned, so leaving the video, a
newer request, a pack change or the app going to the background stops the
scan between chunks and the next opening resumes it.
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
each chunk's pass 1 and pass 2, and after the models unload. A
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
