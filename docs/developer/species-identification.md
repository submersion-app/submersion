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

1. The fish detector's weights are cleared for redistribution. They have no
   stated licence; the authors' permission is needed.
2. The confidence bars in the pack come from measured accuracy. Every value
   under `naming` in a pack built today is marked `provisional`.

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
