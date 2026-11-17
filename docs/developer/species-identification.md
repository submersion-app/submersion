# Species Identification

Marine life identification finds fish in a diver's photos on the device and
suggests what they are (issue #4668). The design is in
[the program overview](../design/specs/2026-11-17-marine-life-identification-program-design.md)
and [the first piece](../design/specs/2026-11-17-marine-life-identification-1-photos-design.md).

The feature is behind a flag and off for divers. This page is for working on
it.

## Turning it on

The flag is `marineLifeIdEnabled` in `lib/core/constants/feature_flags.dart`.
A development build turns it on with a build define:

```bash
flutter run -d macos --dart-define=MARINE_LIFE_ID=true
```

Two things must hold before its default changes:

1. A detector is chosen whose terms allow shipping it. The Community Fish
   Detector's authors leave the terms of its weights to the user;
   FathomNet's Megalodon is CC BY 4.0 but was trained with AGPL code. The
   [measured accuracy findings](../design/findings/2026-11-17-marine-life-measured-accuracy.md)
   compare the two and recommend one.
2. The confidence bars in the pack come from measured accuracy. A full pack
   (about 7,600 candidates) with the Community Fish Detector is now written
   with measured bars; a smaller development pack, or one with another
   detector, is still marked `provisional`.

Only iPhone, iPad and Mac can run it so far. Phones and tablets need at
least 6 GB of memory.

## How it fits together

| Part | Where |
| --- | --- |
| Native engine (Core ML) | `packages/submersion_vision/` |
| Pack format, download, install | `lib/features/species_id/data/pack/` |
| Naming and decision rules (pure Dart) | `lib/features/species_id/domain/services/` |
| Analysis queue | `lib/features/species_id/data/services/media_identification_service.dart` |
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

It downloads the two models from pinned sources and checks their hashes,
converts them to Core ML, builds the candidate list from the catalogue and
GBIF, embeds every candidate's name, and maps where each species has been
recorded from GBIF's density maps. GBIF responses and converted models are
kept in `build/species_pack_work`, so a second run is quick.

Useful options:

- `--max-candidates N` (default 8000) caps the candidate list. A small
  number makes a quick pack for development.
- `--min-images N` (default 50) is how many photographed observations a
  species needs on GBIF to be a candidate.
- `--skip-models` reuses the converted models in the work folder.
- `--version` names the pack; it defaults to the UTC date and time, so two
  builds on one day are two versions.

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

Fetch the test set. Each stage caches in the work folder
(`build/species_accuracy_work` by default, `--work` to change it) and
resumes if stopped:

```bash
for stage in pool labels photos underwater commons; do .venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py $stage; done
```

Convert Megalodon, checking it against PyTorch on any photo with an animal
in it, then draw contact sheets of every box both detectors put on the
diver photos:

```bash
.venv-species-pack/bin/python -I tool/species_pack/megalodon.py convert megalodon-2024 --check-image PHOTO
```

```bash
.venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py junk-sheets --pack build/species_pack
```

Label each box in `junk_labels.json` in the work folder as `person`,
`scenery`, `animal` or `unclear`, keyed `detector:photo:box`, then write the
CSV and score the pack:

```bash
.venv-species-pack/bin/python -I tool/species_pack/fetch_testset.py write
```

```bash
.venv-species-pack/bin/python -I tool/species_pack/score.py --pack build/species_pack
```

The scorer runs the app's own Swift pipeline through a small command-line
tool (`tool/species_pack/vision_cli/`), once per detector and crop fitting,
names every crop with `naming.py`, chooses bars on the tune half and checks
them on the held-out half, and writes `report.md` and `results.json` to the
work folder. Copy the chosen bars into `NAMING_MEASURED` in
`tool/species_pack/manifest.py`; a pack is written with them only when its
detector, classifier and candidate count match.

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
flutter run -d macos --dart-define=MARINE_LIFE_ID=true --dart-define=SPECIES_PACK_MANIFEST_URL=http://localhost:8765/manifest.json
```

Then open Settings, Data, Photos and videos, Marine life identification,
and download the model. Opening a photo in the viewer analyses it.
