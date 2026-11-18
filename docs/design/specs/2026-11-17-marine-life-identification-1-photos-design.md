# Marine life identification, piece 1: photos on Apple devices

Issue: #4668.

Program overview, with the decisions that apply to every piece:
[2026-11-17-marine-life-identification-program-design.md](2026-11-17-marine-life-identification-program-design.md).
Read it first. This document does not repeat its reasoning.

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

Target release: v1.8.6, behind a feature flag. This piece is one pull request
**(decided)**.

## What this piece delivers

On an iPhone, iPad or Mac, once the diver has downloaded the model:

1. Opening a photo in the media viewer makes the app look for fish in it, in
   the background, once.
2. Species the app is reasonably sure of appear as suggestions beside the
   photo's species tags.
3. In the species sheet, each suggestion shows a cropped image of the animal,
   a name and a score. The diver adds it as a tag with one tap, or dismisses
   it.
4. Everything found is stored with its crop, including fish the app could not
   name, for later pieces to build on.

It also delivers the parts every later piece stands on: the engine plugin, the
model pack and its download, the naming rules, and the stored identifications.

The confidence bars in this piece are provisional. The feature flag is not
turned on for divers until a later piece has measured accuracy and set them
**(decided)**.

## What the diver sees

### Settings

A new page, **Marine life identification**, reached from Settings, Data,
Photos and videos **(decided)**.

```
Marine life identification

  Finds fish in your photos and suggests what they are.
  Runs on this device. Your photos never leave it.

  Model                         Not downloaded
  [ Download (660 MB) ]

  Identify fish when I open a photo        ( on )

  Suggestions kept on this device          214 (6.1 MB)
  [ Clear suggestions ]

  Credits and licences                              >
```

- **Download** shows the exact size from the pack and asks for confirmation
  before starting. Apple's review guidelines require this. While downloading
  it shows progress and a Cancel button. A failed or cancelled download
  resumes from where it stopped.
- Once installed the row reads "Installed" with the pack version, and the
  button becomes **Remove model**. When a newer pack is published it offers
  **Update**.
- Removing the model keeps existing suggestions and crops. They stay usable,
  because each stored suggestion carries its own names.
- **Clear suggestions** deletes every identification in the open logbook and
  every crop on the device, after a confirmation. It does not remove any
  species tag.
- The toggle is a per-device preference, on by default.
- On a device that cannot run the feature the page explains why and offers no
  download.

### The photo viewer

The row of species chips under a photo gains suggested chips after the tagged
ones. A suggested chip is outlined, not filled, and carries its score.

```
  [ Green Sea Turtle ]   [ + Queen Parrotfish 92% ]   [ + Blue Tang 71% ]
     tagged                 suggested                    suggested
```

- Tapping a tagged chip still opens that species' page.
- Tapping a suggested chip opens the species sheet, when the viewer currently
  allows edits. When it does not (a locked photo under unified editing), the
  chip is shown but does nothing.
- Nothing is shown when the app found nothing it can name. There is no
  "no fish found" message.
- Nothing is drawn over the photo itself in this piece.

### The species sheet

The sheet opened by the viewer's species action gains a **Suggested** section
at the top.

```
Species on this photo

  Suggested
  [crop]  Queen Parrotfish        92%        [ Add ]  [ x ]
  [crop]  Blue Tang  x3           71%        [ Add ]  [ x ]
                                             [ Add all ]

  Seen on this dive
  ( Green Sea Turtle )  ( Great Barracuda )

  Tagged on this photo
  ( Yellowtail Snapper  x )

  [ Other species ]
```

- One row per suggested species. Several animals of one species in a photo
  are one row with a count, showing the best crop.
- **Add** tags the photo with that species, exactly as picking it by hand
  does, so on a dive photo it also logs the sighting.
- **x** dismisses the suggestion. It does not come back for this photo.
- **Add all** adds every suggestion listed.
- Tapping a crop shows it larger, with up to three candidate names and their
  scores, each of which can be added.
- A crop that is missing from the device shows a placeholder.
- While the app is still analysing the photo, the section shows a small
  progress indicator.
- **Tagged on this photo** is new. Today a tag can only be removed if its
  species is among the dive's sightings, so a tag on a photo with no dive
  cannot be removed in the viewer at all. Suggestions make that easy to hit,
  so this piece lists the photo's other tags with a remove control
  **(proposed)**.

## Scope

In this piece:

- The engine plugin, with its Core ML implementation for iOS and macOS.
- The model pack format, download, verification, install, update and removal.
- The pack builder tool.
- The naming rules, with provisional bars.
- Stored identifications, embeddings and crops, with cleanup.
- Analysis of a photo when it is opened in the media viewer.
- Suggestions in the viewer's chip row and species sheet; add, dismiss, add
  all.
- The settings page and two storage usage categories.
- The feature flag.

Not in this piece:

- Video of any kind.
- Android, Windows, Linux. The web build compiles and the feature is absent.
- Measuring accuracy and setting the real bars.
- The auto-apply setting and the not-yet-validated state.
- Analysing photos the diver has not opened.
- Drawing dots, pills or boxes over a photo.
- Writing a position onto a species tag. The tag table's reserved box columns
  stay empty; Add works exactly as picking a species by hand does.
- The site media viewer, which has no species chips today.
- Syncing identifications or crops between devices.
- Translated names for candidate species that are not in the built-in
  catalogue. They are shown in English.
- Publishing a pack, and user documentation. Both wait for the flag to be
  turned on.

## How it works

```
viewer shows a photo
   -> wait a moment (the diver may be swiping past)
   -> already analysed, and nothing it depended on has changed?  yes: stop
   -> take the image the viewer is showing        unavailable: stop, retry later
   -> engine (native, off the main thread):
        decode, apply orientation, detect fish,
        cut each crop, embed each crop
        returns positions, scores, crop thumbnails, embeddings
   -> naming (Dart, off the UI isolate):
        embeddings x candidate table -> ranked species per crop,
        limited to species recorded near the photo
   -> store identifications, embeddings and crops; record the run
   -> the chip row and the sheet update
```

## The parts

### 1. Feature flag

A flag in `lib/core/constants/feature_flags.dart`, following
`lightroomUiEnabled`: a mutable top-level bool so tests can toggle it. Its
default comes from a build define, so a development build can turn it on
without a code change **(proposed)**:

```dart
bool marineLifeIdEnabled = const bool.fromEnvironment('MARINE_LIFE_ID');
```

When the flag is off the settings entry is hidden, the viewer starts no
analysis, and no suggestion is shown. Code, tables and the plugin remain.

### 2. Engine plugin: `packages/submersion_vision`

A local plugin package in the shape of `submersion_ocr`: `publish_to: none`,
a method channel named `submersion_vision`, and for this piece only the
`ios` and `macos` platforms with `sharedDarwinSource: true`. The podspec
targets iOS 15 and macOS 12, matching the app. Core ML is a system framework,
so the package adds no binary dependency.

The plugin knows nothing about species. It runs a detector and an embedding
model over an image.

Dart interface, defined in the app
(`lib/features/species_id/domain/services/vision_engine.dart`), with a channel
implementation in `data/` that is the only importer of the package:

```dart
abstract class VisionEngine {
  /// available, unsupportedPlatform, or deviceNotEligible.
  Future<VisionAvailability> availability();

  /// Loads the two models. Safe to call again; a no-op when already loaded
  /// with the same files.
  Future<void> load(VisionModels models);

  /// Detects, crops and embeds. Exactly one of [path] and [bytes] is set.
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes});

  /// Frees the models' memory.
  Future<void> unload();

  /// Marks a directory as not to be included in device backups.
  Future<void> excludeFromBackup(String directory);
}
```

- `VisionModels` carries the two model paths and the numbers the native side
  needs from the pack manifest: each model's input size, normalisation mean
  and standard deviation, the detector's score threshold and box limit, the
  crop padding, and the crop thumbnail size.
- `VisionAnalysis` carries the image's width and height after orientation is
  applied, and a list of detections. Each detection has a box normalised 0 to
  1 against that oriented image (the same convention as people tags), the
  detector's score, the size of the box in the analysed image's pixels, a JPEG
  thumbnail of the crop, and the crop's embedding as 32-bit floats.
- A missing plugin (web, or a platform not yet implemented) maps to
  `unsupportedPlatform`, as `ChannelNlEngine` does.
- The engine provider gates on `defaultTargetPlatform`, not `Platform`, so
  tests can override it. In this piece only iOS and macOS are supported.

Native behaviour:

- All work runs off the main thread.
- EXIF orientation is applied before detection, so boxes match what the
  viewer displays.
- The detector takes the image resized straight to its square input, with no
  letterboxing. Its raw output is 300 candidate boxes (centre, width and
  height, normalised) with one raw score each. The native side applies a
  sigmoid to the scores, applies the score threshold, and keeps the
  highest-scoring boxes up to the limit. This family of detector needs no
  overlap suppression.
- Crops are cut from the full-resolution analysed image, padded by the
  manifest's padding, then resized for the embedding model.
- The embedding model's memory is large. The native side releases both models
  on a memory warning, and the Dart side unloads them after a period with no
  analysis.

Both models, as converted in the spike, load on iOS 15 and macOS 12 (Core ML
specification version 6).

**Device eligibility (decided).** Macs: every Mac the app supports. iPhone and
iPad: devices with at least 6 GB of memory; others report `deviceNotEligible`.
The floor is a single constant.

### 3. Model pack

A pack is a manifest and a set of files, installed under
`<application support>/species_id/pack/<pack version>/`. Reach the directory
through `AppDirectories.support()`; `path_provider` may not be imported
directly.

Application Support is included in iCloud and computer device backups unless
a directory is excluded. The pack directory is excluded, through the plugin's
`excludeFromBackup`. It is large and can be downloaded again.

`manifest.json`, format version 1:

```json
{
  "formatVersion": 1,
  "packVersion": "2026.11.1",
  "detector":   { "id": "cfd-rfdetr-nano-640-20260706",
                  "inputSize": 640, "mean": [], "std": [],
                  "scoreThreshold": 0.3, "maxBoxes": 8, "cropPadding": 0.10 },
  "classifier": { "id": "bioclip-2-vitl14-2957b32",
                  "inputSize": 224, "mean": [], "std": [],
                  "embeddingSize": 768, "logitScale": 100.0 },
  "naming":     { "provisional": true,
                  "minCropSide": 64, "minOpenScore": 0.15,
                  "suggestScore": 0.50, "confidentScore": 0.70,
                  "suggestScoreNoLocation": 0.70,
                  "minAllowedCandidates": 200, "topK": 5 },
  "region":     { "cellDegrees": 5, "neighbourCells": 1 },
  "cropThumbnailSize": 320,
  "files": [
    { "name": "detector.coreml.zip",   "engine": "coreml", "size": 0, "sha256": "" },
    { "name": "classifier.coreml.zip", "engine": "coreml", "size": 0, "sha256": "" },
    { "name": "candidates.json",       "engine": "all",    "size": 0, "sha256": "" },
    { "name": "text_embeddings.f16",   "engine": "all",    "size": 0, "sha256": "" },
    { "name": "regions.bin",           "engine": "all",    "size": 0, "sha256": "" }
  ],
  "credits": [ { "name": "", "licence": "", "text": "" } ]
}
```

The numeric values shown are the spike's, and every value under `naming` is
provisional. The app treats the manifest as the only source of them.

- **Model ids.** `detector.id` and `classifier.id` change only when the model
  itself changes. The app uses them to tell a pack that needs photos analysed
  again from one that only needs them named again.
- **Candidates.** `candidates.json` is an ordered list with one entry per
  GBIF species key. Each entry has the key, the scientific name, an English
  common name, the app's species category, and the built-in catalogue id when
  the species is in the catalogue.
- **Text embeddings.** One row per candidate, in the same order, as 16-bit
  floats, already normalised to unit length.
- **Regions.** One bit per candidate per cell of a latitude and longitude
  grid, set when the species has been recorded in that cell.
- **Models.** Each Core ML model is a zipped model directory. Whether the
  pack carries compiled models or compiles them once at install is left to
  the builder; either way the diver sees it as part of installing.
- **Credits** are shown on the settings page's credits screen.

**Download.** Model the downloader on `DemoDownloader`
(`lib/features/demo_mode/data/demo_downloader.dart`): stream to a temporary
file, hash while streaming, check the exact size, rename only on success,
support cancel, use an injectable `package:http` client. Add what that
precedent lacks: resume with a `Range` request, falling back to starting the
file again when the server does not honour it.

- The manifest URL is a constant naming a release asset on the project's
  GitHub, overridable with a build define so a locally built pack can be
  served from a local web server during development.
- The app downloads the files whose `engine` is `all` or its own. The size it
  quotes to the diver is the sum of those.
- Files download into a staging directory and the pack becomes installed only
  when every file has verified. A partly downloaded pack is never loaded.
- The app ignores a manifest whose `formatVersion` it does not know, and says
  that an app update is needed.
- Installing a newer pack removes the older one after the new one verifies.
- Until a pack is published the manifest URL returns nothing, and the page
  says the model is not available yet.

### 4. Naming

Pure Dart, in `lib/features/species_id/domain/`, with no Flutter imports, so
that later engines share it unchanged.

For each detection:

1. Normalise the embedding to unit length.
2. Score it against every candidate: the dot product with the candidate's
   text embedding, times `logitScale`, then a softmax over the whole list.
   The highest of these is the detection's **open score**. It says whether
   the crop looks like anything in particular, before place is considered.
3. Work out which candidates are allowed. With a location, a candidate is
   allowed when its region bits include the photo's grid cell or a
   neighbouring one. If there is no location, or fewer than
   `minAllowedCandidates` are allowed, every candidate is allowed and the
   detection counts as having no location.
4. Rank the allowed candidates. A candidate's score is its share of the
   softmax taken over the allowed candidates only. Keep the top `topK`.
5. The detection is **suggestable** when all of these hold:
   - its box's shorter side is at least `minCropSide` pixels;
   - its open score is at least `minOpenScore`;
   - its top score is at least `suggestScore`, or
     `suggestScoreNoLocation` when it counts as having no location.

Why two scores. Limiting candidates to a place is right when the true species
is on the list: it removes look-alikes from other oceans. But it also raises
every remaining score, and in a thinly recorded cell it could lift a diver's
hand over the bar. The open score is taken before limiting, so it cannot be
inflated that way.

The photo's location is the first of these that exists: the media item's own
latitude and longitude; the dive's site location; the dive's entry location.

Run this off the UI isolate. With several thousand candidates it is a few
million multiplications per crop.

Grouping for display: suggestable detections are grouped by their top
candidate. A group's score is its highest, its count is its size, and its crop
is the one with the highest score.

### 5. Storage

**(decided)** Identifications and the diver's decisions live in the main
database, with the logbook they belong to. They are never synced. Embeddings
live in the device-local cache. Crops are files.

#### Main database, schema version 375

Two tables in a new `lib/core/database/tables/identification_tables.dart`.
Neither has an `hlc` column, so neither syncs. Follow
`docs/developer/database.md` and use version 362, `dive_deco_status`, as the
template: it is the most recent table that never syncs.

**`media_identification_runs`**, one row per analysed media item:

| Column | Meaning |
| --- | --- |
| `media_id` (primary key) | The media row analysed |
| `pack_version` | The pack that analysed or last named it |
| `detector_id`, `classifier_id` | The models that analysed it |
| `location_cell` | The grid cell naming used, or null for none |
| `analysed_at` | When |
| `image_width`, `image_height` | Size of the analysed image, oriented |
| `detection_count` | How many detections were stored, possibly zero |

**`media_identifications`**, one row per detection:

| Column | Meaning |
| --- | --- |
| `id` (primary key) | UUID |
| `media_id` | The media row; indexed |
| `box_x`, `box_y`, `box_width`, `box_height` | Normalised 0 to 1 |
| `box_pixel_width`, `box_pixel_height` | Size in the analysed image's pixels |
| `detector_score` | The detector's score |
| `open_score` | The open score from naming |
| `candidates_json` | Ranked candidates, each with GBIF key, scientific name, common name, category, catalogue id if any, and score |
| `location_limited` | Whether candidates were limited by place |
| `suggestable` | Whether it passed the bars when last named |
| `decision` | `undecided`, `accepted` or `rejected` |
| `decided_species_id` | The species tagged, when accepted |
| `decided_at` | When the decision was recorded |
| `created_at` | When |

Detections that are not suggestable are stored too. They are the unnamed fish
later pieces need.

`candidates_json` carries names, not just keys, so that a stored suggestion
can be shown and added after the model has been removed.

`media_id` is deliberately not a foreign key **(proposed)**. A delete held for
undo removes the media row and an undo puts it back; a cascade would destroy
the diver's decisions in between. `MediaRepairLog` is the precedent for a
media id held without a reference.

What a new main-database table that never syncs must be registered in, each
enforced by a test:

- `changeLogTables` in
  `lib/core/database/change_log/change_log_policy.dart`, as `excluded`.
- Exactly one of `kSqlDeniedTables` and `kSqlReadableExcludedTables` in
  `lib/features/agent_access/data/sql/sql_denied_set.dart`. Which one is the
  builder's call.
- The generated SQL column notes, by running
  `dart run tool/generate_sql_column_notes.dart`.
- `demoCoverageExclusions` in
  `tool/demo_data/src/checks/coverage_check.dart`.
- The exemptions in `test/architecture/agent_write_coverage_exempt.dart`, for
  the new repository's write methods.
- A backstop in
  `lib/core/database/migrations/before_open_table_backstops.dart`, not in
  `before_open.dart`, which is one line from its size limit.
- `lib/core/database/performance_indexes.dart`, for the index on `media_id`.

Avoid integer column names ending in `time`, `_since`, `_until` or `_on`; a
demo-mode guard treats those as dates to shift.

#### Device-local cache, schema version 25

One table in `LocalCacheDatabase`:

**`identification_embeddings`**: `identification_id` (primary key),
`classifier_id`, and `embedding` as 16-bit floats.

This is disposable, like the rest of that database. The existing
`LocalCacheSweep` already removes rows whose owner is missing from the open
logbook; extend it to these rows. Losing an embedding costs nothing but the
ability to name that fish again without analysing the photo.

#### Crops

JPEG files at
`<application support>/species_id/crops/<media id>/<identification id>.jpg`.
This is durable storage, not a cache the operating system may empty, and it is
left in device backups.

Crops are deleted only together with their identification, by the app's own
code. There is no sweep that deletes crop files for lacking a row: the
device's crops directory is shared by every logbook opened on the device,
including the demo logbook, so "no row in the open logbook" proves nothing.

A photo with an identification whose crop file is missing is analysed again
the next time it is opened, which restores the crops. This is what happens
after a restore onto a new device.

#### Decisions

A decision is recorded by reconciling identifications against the photo's
species tags, not at the moment of a tap. This one rule serves both editing
modes, and also counts a species the diver tagged by hand **(proposed)**.

After any change to a photo's species tags:

- A species now tagged on the photo accepts every undecided identification
  whose best name is that species. When no identification names it first, it
  accepts the one undecided identification that ranks it highest among its
  candidates, so a diver correcting the app's guess is still recorded. A
  neighbouring fish that only lists the species lower down keeps its own
  suggestion **(decided)**.
- An accepted identification whose species is no longer tagged becomes
  `rejected`.

A candidate matches a tagged species by catalogue id when it has one, and
otherwise by scientific name.

Dismissing a suggestion sets `rejected` directly.

A suggestion is shown when its identification is suggestable, undecided, and
its top candidate's species is not already tagged on the photo.

#### When a photo is analysed or named again

On opening a photo that already has a run, compare the run with the installed
pack and the photo's current location:

- **A crop file is missing, or `detector_id` or `classifier_id` differs:**
  analyse again. Undecided identifications from the old run are replaced.
  Decided ones are kept, and a new detection that overlaps a rejected one for
  the same species is stored as rejected, so a dismissed suggestion does not
  return.
- **Only `pack_version` or the location cell differs:** name again from the
  stored embeddings, with no engine and no original needed. Update each
  undecided identification's candidates, scores and `suggestable`. Where an
  embedding is missing, fall back to analysing again.
- **Nothing differs:** do nothing.

#### Cleanup

- `MediaDeletionCoordinator` reports deletions through `onDeleted`, with an
  `undoable` flag. On a delete that is **not** undoable, delete the media
  items' identifications, runs, embeddings and crops. On an undoable one, do
  nothing: an undo puts the media rows back, and the identifications must
  still be there.
- Deletions that arrive by sync bypass that coordinator, and an undoable
  delete that is never undone leaves rows behind. A sweep removes
  identifications and runs whose media row is gone, with their crops and
  embeddings. Both tables are in the same database as the media, so the check
  is safe whichever logbook is open. It must not run while a delete is held
  for undo; running it at app start satisfies that.

### 6. Analysis service

`MediaIdentificationService`, in `lib/features/species_id/data/services/`.
Model its queue on `ColorAnalysisService`
(`lib/features/media/data/services/color_analysis_service.dart`), the existing
per-photo pixel analysis.

- One analysis at a time, newest request first.
- A request for a photo that is no longer on screen is dropped before it
  starts.
- A request does nothing when: the flag is off; the toggle is off; no pack is
  installed; the engine is not available; or the item is not a photo.
- **The image analysed is the one the viewer is showing.** The viewer already
  resolves each photo, and may be showing a compressed copy from the media
  store when the original is on another device. Analyse that. Start no
  download the viewer would not have started. The run records the analysed
  image's size.
- When no image is available, nothing is recorded, so the photo is tried
  again next time.
- A failure in the engine records nothing and is logged. It never surfaces to
  the diver as an error on the photo.
- When a run is stored or an identification changes, a change signal fires so
  the chip row and the sheet rebuild. New providers that read a repository
  must follow the repository tick rule that
  `test/architecture/provider_change_tick_test.dart` enforces.

**Starting it from the viewer.** `MediaViewerPage` already starts background
work for the item on screen from a post-frame callback
(`_backfillEnrichment`). Use the same mechanism, with these differences:

- That work is remembered per dive. This must be remembered per media item.
- Only the item actually on screen triggers it. The gallery builds the
  neighbouring pages ahead of a swipe; those must not.
- It waits a short dwell first, so that swiping through photos does not
  analyse each one. The length is the builder's call; about 400 ms.

Comments in the viewer trace an app-wide freeze to analysis run on the UI
isolate for every item shown. Nothing here may do pixel work or the naming
arithmetic on the UI isolate.

### 7. Viewer

- **Chip row.** `MediaSpeciesChipsRow`
  (`lib/features/media/presentation/widgets/media_species_chips_row.dart`)
  shows suggested chips after the tagged ones.
- **Sheet.** `MediaSpeciesSheet`
  (`lib/features/media/presentation/widgets/media_species_sheet.dart`) gains
  the Suggested section and the Tagged on this photo section.

**Adding a suggestion** resolves the candidate to a species first: the
built-in catalogue id when the candidate has one; otherwise an existing
species with the same scientific name; otherwise a new species of the diver's
own, created from the candidate's names and category. This is the same order
the species picker uses when creating a species.

It then tags the photo through whichever path the viewer is in:

- **Unified editing off** (today's released behaviour): write at once through
  `SpeciesTaggingService.tagPhoto`.
- **Unified editing on and the photo unlocked:** hold the species in the
  sitting with `holdPickedSpecies`, as the picker does. The tag is written on
  Save. A species created for the suggestion stays created if the sitting is
  cancelled, as it does for the picker.
- **Unified editing on and the photo locked:** the sheet cannot be opened, so
  there is nothing to do. Suggested chips are visible and inert.

**Dismissing** writes at once in both modes **(proposed)**. A dismissal is the
app's bookkeeping about its own guess; it is not part of the photo's record
and does not appear in History. It is offered only where the sheet is, so
never on a locked photo.

**Add all** adds each listed suggestion in turn through the same path
**(proposed: every suggestion listed, not only those over the confident
bar)**.

### 8. Settings page

A page at `/settings/marine-life-identification`, listed in
`webUnavailableRoutePrefixes`, with its entry on the Photos and videos page.
The toggle is a SharedPreferences key in `SettingsKeys`, marked device-local.

### 9. Storage usage

Two new categories in `StorageInventory`, so the download and the crops are
visible in Settings, Storage usage: the identification model, and
identification crops. `test/core/services/storage/storage_inventory_test.dart`
pins the number of categories and must be updated.

### 10. Pack builder

A developer-run tool under `tool/species_pack/`, in Python, because model
conversion needs Python libraries. It is not run by the app build or CI. It:

1. Downloads the two published models from pinned URLs and checks their
   hashes. It opens the detector checkpoint with the safe loader only.
2. Converts both to Core ML at 16-bit precision, targeting iOS 15, and checks
   that each converted model's output matches the original's.
3. Builds the candidate list: every species in the built-in catalogue that
   has its own GBIF species key, plus species from GBIF within the catalogue's
   higher taxa that have enough observation records with images. The cut-off
   is the builder's call, aiming for 5,000 to 10,000 candidates.
4. Computes each candidate's text embedding with the classifier's text tower.
5. Builds the region table from GBIF occurrence data.
6. Writes the manifest, with sizes, hashes, the provisional bars and credits.

Notes for step 3:

- `assets/data/species_gbif_keys.json` has 679 keys for 685 catalogue
  species. Four pairs of catalogue species share a scientific name, and two
  have no species-rank key. A candidate is one GBIF key; where two catalogue
  species share a key, the builder picks one by a stated, repeatable rule.
  Catalogue species with no species-rank key are not candidates.
- The species category for each candidate must follow the same rules as
  `lib/features/marine_life/domain/services/species_category_mapper.dart`.
  How the two are kept in step is the builder's call.

The tool does not evaluate the bars. That is the measured accuracy piece.

A developer page, `docs/developer/species-identification.md`, describes
building a pack, serving it locally, and turning the flag on.

## Edge cases

- **The original is on another device.** The viewer may still be showing a
  compressed copy; that is analysed. If it is showing nothing, there is no
  analysis and nothing is recorded.
- **A photo with no location anywhere.** Candidates are not limited, and the
  higher bar applies.
- **A dive site in a thinly recorded area.** Fewer than
  `minAllowedCandidates` species are allowed, so it is treated as no
  location.
- **The photo later gains or changes its dive or site.** It is named again,
  from stored embeddings, the next time it is opened.
- **The same species several times in one photo.** One suggestion with a
  count.
- **The species is already tagged.** No suggestion; the identification is
  reconciled to accepted.
- **The diver removes a tag that came from a suggestion.** The identification
  becomes rejected and the suggestion does not return.
- **The model is removed.** Stored suggestions remain usable. No new analysis
  happens.
- **A backup is restored on another device.** Identifications and decisions
  arrive; crops do not. Each photo shows placeholders until it is opened with
  the model installed, when it is analysed again.
- **The demo logbook.** It has its own database, so identifications made
  there stay there and real ones are untouched.
- **The download is interrupted, or the app is closed during it.** It resumes
  when the diver presses Download again. It does not restart on its own.
- **Not enough free space.** The download refuses to start where the platform
  can tell, and otherwise fails cleanly with the partial files left for a
  resume.
- **The diver switches photos during analysis.** The running analysis
  finishes and is stored; queued requests for photos no longer shown are
  dropped.

## Testing

Tests are written first. Run only the test files written or changed, by path.

- **Naming:** both scores, the region limit and its neighbours, the fallback
  when too few candidates are allowed, each bar, the size floor, grouping.
  Test vectors are computed, not hand-typed.
- **Pack:** manifest parsing and rejection of unknown format versions; file
  selection by engine; verification failures.
- **Downloader:** success, checksum mismatch, size mismatch, cancel, resume
  with and without `Range` support, against a fake HTTP client.
- **Storage:** the main migration to version 375, following
  `test/core/database/migration_v362_dive_deco_status_test.dart`; the local
  cache migration to version 25; repository reads and writes; the reconcile
  rules; each branch of "analysed or named again"; both cleanup paths,
  including that an undoable delete purges nothing.
- **Service:** every skip condition; the queue's order and dropping; no image
  available; an engine failure. Uses a fake `VisionEngine`.
- **Channel engine:** the method channel contract, with the mock handler
  restored in teardown.
- **Widgets:** the chip row with and without suggestions; the sheet's two new
  sections; add, dismiss and add all in both editing modes; a missing crop;
  the settings page in each model state; everything hidden with the flag off.
- **Pack builder:** the pure parts (manifest writing, region grid arithmetic)
  have Python tests beside them. The grid arithmetic must agree with the Dart
  side on shared test vectors.

The Swift code is exercised by running the macOS app against a locally built
pack. No automated test runs the real models.

## Screenshots for the pull request

In light and dark, at phone and desktop widths where layout differs.

- **Before and after**, for screens that exist today: the viewer's chip row;
  the species sheet; the Photos and videos settings page, which gains an
  entry; Storage usage, which gains two categories. The before shots are
  taken before any code changes.
- **After only**, for what is new: the Marine life identification page (not
  downloaded, downloading, installed) and the larger crop view.

## Left to the builder

- Internal names, file layout within `lib/features/species_id/`, and provider
  shapes.
- Whether the pack carries compiled Core ML models or compiles at install.
- The dwell before analysis, and how long models stay loaded when idle.
- How the embedding crop is fitted to a square. The spike resized the shorter
  side and cropped the centre, which cuts the ends off long fish.
- How much two boxes must overlap to count as the same animal when a photo is
  analysed again.
- Whether the two new tables are readable through agent SQL.
- The candidate cut-off, the source of English common names, the rule for
  catalogue species sharing a key, and the exact GBIF queries.
- The free-space check.
- Exact wording of every string, in all 11 languages.

## Calls made by the designer, for the maintainer to check

1. Dismissing a suggestion writes at once, even under unified editing.
2. A decision is recorded by reconciling against tags, so tagging a species
   by hand also counts as accepting the app's matching guess.
3. "Add all" adds every suggestion listed, not only those above the confident
   bar.
4. The species sheet gains a "Tagged on this photo" section with a remove
   control, fixing an existing gap.
5. With no location, or too few recorded species nearby, the bar to suggest
   rises from 0.50 to 0.70.
6. A crop must also pass an open score, taken before candidates are limited
   by place.
7. The flag defaults from a build define, `MARINE_LIFE_ID`.
8. Removing the model keeps stored suggestions; clearing them is a separate
   action, and clearing removes every crop on the device.
9. The identification tables hold a media id without a foreign key, so that a
   delete held for undo does not destroy decisions.
10. The app analyses whatever image the viewer is showing, which may be a
    compressed copy, and never starts a download of its own.
11. Crops stay in device backups; the model does not.

## Risks specific to this piece

- **No pack can be published yet.** The detector's weights have no stated
  licence. The feature can be built and tried with a locally built pack, and
  stays behind its flag until that is settled.
- **The bars are provisional.** They were set by eye against 685 candidates
  with no region table. Against thousands of candidates the same fish will
  score lower, so this piece may suggest too little or too much until the
  measured accuracy piece replaces them.
- **Phone memory is not measured on a 6 GB phone.** The
  [phone memory findings](../findings/2026-11-17-marine-life-phone-memory.md)
  measured a Mac and an iPhone 17 Pro Max. On the iPhone the models run on
  the Neural Engine and iOS counts their 634 to 718 MiB, and identification
  peaked at 2.4 GiB with a 50 MP photo open, against a limit of 3,376 MiB.
  A 6 GB phone's limit may be lower and is unmeasured, so the 6 GB floor may
  still be too low.
- **First use is slow.** Loading a 608 MB model takes seconds. The first
  photo opened after launch will show suggestions noticeably later than the
  rest.
- **The viewer is mid-rework** under unified editing. This piece touches the
  chip row and the species sheet in both modes, and will conflict with work
  in flight there.
- **Sparse results on wide-angle footage.** On the spike library only 12% of
  photos produced a confident name. Divers who shoot close will see far more
  than divers who shoot wide.
- **It is a large pull request**: a Swift plugin, a Python tool, a schema
  change, and strings in 11 languages.

## Appendix: what the spike used

Recorded so the pack builder reproduces the spike and does not rediscover it.
The spike's scripts were throwaway and are not in the repository.

**Detector**

- Community Fish Detector, RF-DETR nano, 640 px, release `2026.07.06-release`:
  `https://github.com/filippovarini/community-fish-detector/releases/download/2026.07.06-release/cfd-rf-detr-nano-640-2026.02.02.cp-011.20260706-release.pth`
- SHA-256
  `e3eac301b778e251c3826eae247cc783e1f2dab3fd71a18de92bf3e8999c6f10`,
  122,056,633 bytes.
- The checkpoint loads with the safe loader (`weights_only=True`) and no
  allowlist: it holds only tensors and plain dictionaries.
- Loaded with the `rfdetr` package, version 1.12.1, through `from_checkpoint`.
- Input: the image resized to 640 by 640, scaled to 0 to 1, normalised with
  mean `[0.485, 0.456, 0.406]` and standard deviation
  `[0.229, 0.224, 0.225]`.
- Score threshold 0.3; the eight highest-scoring boxes kept per image.
- Converted with the package's own exporter
  (`export(format="coreml", coreml_precision="float16")`): 55 MB, input
  `[1, 3, 640, 640]`, outputs `[1, 300, 4]` boxes and `[1, 300, 1]` scores.

**Classifier**

- BioCLIP 2, `imageomics/bioclip-2` on Hugging Face, revision
  `2957b322090f9cb17ae72c71981c7218a28d81e0`, file
  `open_clip_model.safetensors`, loaded with `open_clip_torch` 4.2.2.
- Only the image tower is converted: 304 million parameters, 768-wide output.
- Input: the crop resized so its shorter side is 224 (bicubic), centre
  cropped to 224 by 224, normalised with mean
  `[0.48145466, 0.4578275, 0.40821073]` and standard deviation
  `[0.26862954, 0.26130258, 0.27577711]`.
- Crops were the detector's box padded by 10% on each side.
- `logit_scale` is 100.0.
- Converted by tracing the image tower and converting with `coremltools`
  (`mlprogram`, 16-bit, iOS 15 target): 608 MB. Cosine similarity with the
  original's output: 0.99999.

**Text embeddings**

For each candidate, three prompts were embedded with the text tower, each
normalised, averaged, and normalised again:

- `a photo of <scientific name>.`
- `a photo of <common name>.`
- `a photo of <scientific name> with common name <common name>.`

**Tools:** Python 3.14, torch 2.15.0, coremltools 9.1.dev1.
