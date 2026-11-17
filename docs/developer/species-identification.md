# Species Identification

Marine life identification finds fish in a diver's photos and videos on the
device and suggests what they are (issues #4668 and #4675). The design is in
[the program overview](../design/specs/2026-11-17-marine-life-identification-program-design.md),
[the first piece](../design/specs/2026-11-17-marine-life-identification-1-photos-design.md)
(photos) and
[the second](../design/specs/2026-11-17-marine-life-identification-2-video-design.md)
(video).

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
Each track is one `media_identifications` row with its time range, the box at
each sample packed into `track_path`, and any species the diver gave it from
the frame (`claimed_species_id`).

On a 4K clip on an M-series Mac, pass 1 runs at about ten times real time.
Pass 2 costs about 85 ms a moment, so a dense school (about 500 moments in 50
seconds) takes most of the time. Neither has been measured on a phone.

What is checked by hand, since no automated test runs the real models:
labels sit on the fish in a landscape and a portrait clip, and a diver or a
hand in frame gets no dot.

