# Marine Life Identification, Piece 1: Photos on Apple Devices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is executed inline with superpowers:executing-plans.

**Goal:** On iPhone, iPad and Mac, opening a photo finds the fish in it on the device and shows suggested species the diver can add as tags or dismiss, behind a feature flag.

**Architecture:** A new plugin package runs a detector and an embedding model through Core ML and returns boxes, crop thumbnails and embeddings. Pure Dart turns each embedding into ranked species using a candidate table, text embeddings and a region table that ship in a downloadable model pack. Identifications and the diver's decisions are stored in two main-database tables that never sync; embeddings go in the device-local cache and crops are files.

**Tech Stack:** Flutter, Riverpod, drift (SQLite), Swift with Core ML, `package:http`, `package:crypto`, `package:archive`, Python (pack builder only).

**Spec:** `docs/design/specs/2026-11-17-marine-life-identification-1-photos-design.md`, with the program overview `docs/design/specs/2026-11-17-marine-life-identification-program-design.md`. Read both. Issue #4668. Release v1.8.6.

## Calls made in this plan, for Eric to check

1. The feature folder is `lib/features/species_id/`, and commits use the scope `species-id`.
2. A box from a new analysis counts as the same animal as a stored one when they overlap by half or more (intersection over union 0.5) and share a top candidate.
3. The two new tables are readable through agent SQL (`kSqlReadableExcludedTables`), since they hold nothing private that the media table does not.
4. The memory floor is tested as 5 GiB of physical memory, because devices sold as 6 GB report about 5.5 GiB.
5. The native side caps the decoded image at 4096 px on its longer side before detecting, to bound memory on very large photos. Boxes stay normalised, so nothing downstream changes.
6. Analysis takes a file path when the photo has a local path that exists, and otherwise the bytes from `mediaBytesProvider`, which is how the app already reads a photo's original.
7. Reconciling decisions against tags runs when a photo is shown and whenever its tag chips change while it is on screen, not as an app-wide listener.
8. The dwell before analysis is 400 ms; models unload after 60 s with no analysis.
9. The embedding crop is padded to a square before resizing, so long fish are not cut. The pack builder notes this in the manifest for the later accuracy piece.
10. The pack's two pure Python modules get tests in CI; nothing else in the pack builder runs there.

## Not in this plan

Everything the spec lists under "Not in this piece". Also: publishing a pack; user documentation; turning the flag on.

## Global Constraints

- Apple only: the engine supports iOS 15 and macOS 12. Every other platform, and the web build, reports `unsupportedPlatform`. The web build must still compile.
- Flag off means no settings entry, no analysis and no suggestion. The flag defaults to `const bool.fromEnvironment('MARINE_LIFE_ID')`.
- Every value under the manifest's `naming` block is read from the manifest. No bar is hard-coded in app code.
- Naming code lives in `lib/features/species_id/domain/` and imports no Flutter library.
- No pixel work and no naming arithmetic on the UI isolate.
- Reach application support through `AppDirectories.support()`. Do not import `path_provider`.
- Build every path with `p.join`. Temporary space comes from `Directory.systemTemp`.
- Per-media provider families are `autoDispose`.
- A provider that reads a repository calls `ref.invalidateSelfWhen(repo.watch...Changes())`.
- A test that sets a channel mock or other global state restores it in `addTearDown`.
- Every new string exists in all 11 ARB files with a real translation, then `flutter gen-l10n`.
- Files stay under 800 lines; 200 to 400 is typical. Entities are immutable with `copyWith`.
- No em-dashes, no emojis, and no mention of any authoring tool, in code, comments, docs or commit messages.
- Run only the test files written or changed, by path, at most 15 at a time. Never a folder.
- Before each commit: `dart format .` and `flutter analyze`.
- Commit messages: `feat(species-id): <summary>`, or `test`, `docs`, `chore` with the same scope.

## Review Focus

Inputs the spec implies but does not spell out. Each has a test in the task named.

1. **A very large photo** (48 megapixels and up). The app must not be closed for memory. The native side caps the decoded size (Task 8, manual check in Task 14).
2. **An unusable embedding**: all zeros, a NaN, or the wrong length for the pack. Naming returns "not suggestable" and never throws (Task 3).
3. **A location on the edge of the grid**: the poles, and longitude 180 where neighbours wrap. Neighbouring cells are correct and never out of range (Task 2).
4. **A candidate whose catalogue species is gone** from this diver's catalogue. Adding falls back to the scientific name, then creates the species (Task 11).
5. **The disk fills, or the pack has no files for this engine.** The download fails cleanly with its partial file kept; the page says the model is not available for this device (Task 9, Task 12).

## Preparation

- [ ] **Capture the before screenshots**, before any task that changes a screen. Run the macOS app from this branch as it is now, against its own copy of a database, and capture, in light and dark: the media viewer on a photo with species chips showing; the species sheet open on that photo; Settings, Data, Photos and videos; Settings, Storage usage. Save them in the scratchpad as `<nn>-<screen>-before[-dark].png`.

## File Structure

New, under `lib/features/species_id/`:

| File | Responsibility |
| --- | --- |
| `domain/entities/vision_analysis.dart` | `VisionAvailability`, `VisionModels`, `VisionDetection`, `VisionAnalysis` |
| `domain/services/vision_engine.dart` | The `VisionEngine` interface |
| `domain/entities/species_pack_manifest.dart` | The manifest and its nested config types; parsing |
| `domain/entities/pack_candidate.dart` | `PackCandidate`, `NamedCandidate` |
| `domain/entities/media_identification.dart` | `MediaIdentification`, `MediaIdentificationRun`, `IdentificationDecision`, `SpeciesSuggestion`, `TaggedSpecies` |
| `domain/services/float16.dart` | 16-bit float encode and decode |
| `domain/services/region_grid.dart` | `RegionGrid`, `RegionTable` |
| `domain/services/species_namer.dart` | `SpeciesNamer`, `NamingResult` |
| `domain/services/identification_rules.dart` | `reconcileDecisions`, `groupSuggestions`, `decideRefresh`, `carryDecisions` |
| `data/engines/channel_vision_engine.dart` | The only importer of `submersion_vision` |
| `data/pack/species_pack_store.dart` | Installed pack on disk: install, load, remove |
| `data/pack/species_pack_downloader.dart` | Manifest client and resumable verified download |
| `data/repositories/media_identification_repository.dart` | Main-database reads and writes |
| `data/repositories/identification_embedding_repository.dart` | Device-local embeddings |
| `data/services/identification_crop_store.dart` | Crop files |
| `data/services/identification_cleanup.dart` | Purge on delete, orphan sweep, clear all |
| `data/services/media_identification_service.dart` | The queue and the analyse and rename flows |
| `data/services/suggestion_acceptor.dart` | Candidate to `Species` |
| `presentation/providers/species_id_providers.dart` | Engine, repositories, service, suggestions, toggle |
| `presentation/providers/species_pack_controller.dart` | Download state for the settings page |
| `presentation/pages/marine_life_identification_page.dart` | The settings page |
| `presentation/widgets/suggested_species_section.dart` | The sheet's Suggested section and crop view |
| `presentation/widgets/tagged_on_photo_section.dart` | The sheet's Tagged on this photo section |

New elsewhere: `packages/submersion_vision/` (plugin), `tool/species_pack/` (pack builder), `lib/core/database/tables/identification_tables.dart`, `lib/core/database/local_cache_identification_table.dart`, `lib/core/database/migrations/helpers/identification_migrations.dart`, `lib/features/media/presentation/pages/media_viewer_identification.dart` (a part of the viewer page), `docs/developer/species-identification.md`.

Modified: `lib/core/constants/feature_flags.dart`; the database registration files named in Task 5 and Task 6; `media_species_chips_row.dart`; `media_species_sheet.dart`; `media_viewer_page.dart`; `media_viewer_bottom_metadata.dart`; `media_store_providers.dart`; `local_cache_sweep.dart`; the storage inventory files; `settings_providers.dart`; `app_router.dart`; `web_unavailable_routes.dart`; `photos_videos_page.dart`; all 11 ARB files; `pubspec.yaml`; `.github/workflows/ci.yaml`.

Tests mirror `lib/` under `test/features/species_id/`, plus the database tests named in their tasks.

---

### Task 1: Manifest, candidates and 16-bit floats

**Files:**
- Create: `lib/features/species_id/domain/entities/species_pack_manifest.dart`, `lib/features/species_id/domain/entities/pack_candidate.dart`, `lib/features/species_id/domain/services/float16.dart`
- Test: `test/features/species_id/domain/species_pack_manifest_test.dart`, `test/features/species_id/domain/float16_test.dart`

**Interfaces:**
- Produces:

```dart
enum PackManifestFailure { malformed, unsupportedFormat }
class PackManifestException implements Exception { final PackManifestFailure reason; final String? detail; }

class DetectorConfig { final String id; final int inputSize; final List<double> mean, std;
  final double scoreThreshold; final int maxBoxes; final double cropPadding; }
class ClassifierConfig { final String id; final int inputSize; final List<double> mean, std;
  final int embeddingSize; final double logitScale; }
class NamingConfig { final bool provisional; final int minCropSide; final double minOpenScore,
  suggestScore, confidentScore, suggestScoreNoLocation; final int minAllowedCandidates, topK; }
class RegionConfig { final int cellDegrees; final int neighbourCells; }
class PackFile { final String name; final String engine; final int size; final String sha256; }
class PackCredit { final String name, licence, text; }

class SpeciesPackManifest extends Equatable {
  static const int supportedFormatVersion = 1;
  static const String candidatesFile = 'candidates.json';
  static const String textEmbeddingsFile = 'text_embeddings.f16';
  static const String regionsFile = 'regions.bin';
  static String detectorFile(String engine) => 'detector.$engine.zip';
  static String classifierFile(String engine) => 'classifier.$engine.zip';
  // formatVersion, packVersion, detector, classifier, naming, region,
  // cropThumbnailSize, files, credits
  static SpeciesPackManifest parse(String source);   // throws PackManifestException
  List<PackFile> filesFor(String engine);            // engine == 'all' or the given one
  int downloadBytesFor(String engine);
  bool supportsEngine(String engine);                // all five files present for it
}

class PackCandidate extends Equatable { final int gbifKey; final String scientificName,
  commonName; final SpeciesCategory category; final String? catalogId;
  factory PackCandidate.fromJson(Map<String, Object?> json); Map<String, Object?> toJson(); }
class NamedCandidate extends Equatable { final PackCandidate candidate; final double score;
  factory NamedCandidate.fromJson(Map<String, Object?> json); Map<String, Object?> toJson(); }
List<PackCandidate> parseCandidates(String source);

Float32List decodeFloat16(Uint8List littleEndianBytes);
Uint8List encodeFloat16(Float32List values);
```

`SpeciesCategory` is the enum in `lib/core/constants/app_enums.dart`; a category name the app does not know parses as `SpeciesCategory.other`.

- [ ] **Step 1: Write the failing tests.** In `species_pack_manifest_test.dart`, with the spec's example manifest as a fixture string (sizes and hashes filled in):

```dart
test('parses the spec manifest', () {
  final m = SpeciesPackManifest.parse(fixture);
  expect(m.packVersion, '2026.11.1');
  expect(m.detector.inputSize, 640);
  expect(m.naming.minOpenScore, 0.15);
  expect(m.naming.minAllowedCandidates, 200);
  expect(m.naming.provisional, isTrue);
  expect(m.region.cellDegrees, 5);
});
test('an unknown format version is refused', () {
  expect(() => SpeciesPackManifest.parse(fixture.replaceFirst('"formatVersion": 1', '"formatVersion": 2')),
      throwsA(isA<PackManifestException>().having((e) => e.reason, 'reason', PackManifestFailure.unsupportedFormat)));
});
test('files for an engine are its own and the shared ones', () {
  expect(m.filesFor('coreml').map((f) => f.name), unorderedEquals([
    'detector.coreml.zip', 'classifier.coreml.zip', 'candidates.json', 'text_embeddings.f16', 'regions.bin']));
  expect(m.downloadBytesFor('coreml'), /* the fixture's sum */);
  expect(m.supportsEngine('coreml'), isTrue);
  expect(m.supportsEngine('onnx'), isFalse);   // Review Focus 5
});
test('a bad hash, a zero size or a missing block is malformed', () { /* three cases */ });
test('a candidate with an unknown category is other', () { /* ... */ });
```

In `float16_test.dart`: `decodeFloat16(encodeFloat16(v))` equals `v` within `1e-3` for `[0, 1, -1, 0.5, 0.001953125, 65504]`, and the bytes for `1.0` are `[0x00, 0x3C]`.

- [ ] **Step 2: Run them and see them fail.** `flutter test test/features/species_id/domain/species_pack_manifest_test.dart test/features/species_id/domain/float16_test.dart`. Expected: compile errors, the types do not exist.
- [ ] **Step 3: Implement the three files.** A SHA-256 is 64 lower-case hex characters, as `DemoPackage.fromJson` checks. `float16.dart` uses only 16-bit and 32-bit views (the JS integer guard forbids shifts of 32 or more).
- [ ] **Step 4: Run the tests and see them pass.**
- [ ] **Step 5: Commit.** `feat(species-id): model pack manifest and candidates`

### Task 2: Region grid and table

**Files:**
- Create: `lib/features/species_id/domain/services/region_grid.dart`, `tool/species_pack/region_grid.py`, `tool/species_pack/region_grid_test.py`, `tool/species_pack/testdata/region_vectors.json`
- Test: `test/features/species_id/domain/region_grid_test.dart`

**Interfaces:**
- Produces:

```dart
class RegionGrid {
  const RegionGrid({required this.cellDegrees});
  int get columns;  // 360 ~/ cellDegrees
  int get rows;     // 180 ~/ cellDegrees
  int get cellCount;
  /// Row-major from latitude -90, longitude -180. Latitude 90 falls in the
  /// last row; longitude 180 is longitude -180.
  int cellOf(double latitude, double longitude);
  /// [cell] and every cell within [rings] steps. Longitude wraps; latitude
  /// stops at the poles.
  Set<int> neighbourhood(int cell, {required int rings});
}
class RegionTable {
  /// [bits]: one row per candidate, each `(cellCount + 7) ~/ 8` bytes, cell
  /// `c` at byte `c ~/ 8`, bit `c % 8`.
  RegionTable({required this.grid, required Uint8List bits, required this.candidateCount});
  bool recorded(int candidateIndex, int cell);
  /// One entry per candidate: recorded in any of [cells].
  List<bool> allowedMask(Set<int> cells);
}
```

Python mirrors `cell_of(lat, lon, cell_degrees)`, `neighbourhood(cell, rings, cell_degrees)` and `pack_bits(rows_of_cells, cell_degrees) -> bytes`.

- [ ] **Step 1: Write `region_grid.py` and its test first**, then generate the shared vectors: `python3.14 tool/species_pack/region_grid.py --write-vectors tool/species_pack/testdata/region_vectors.json`. The file holds, for `cell_degrees` 5: `cellOf` cases including `(0, 0)`, `(-90, -180)`, `(90, 180)`, `(89.99, 179.99)`, `(12.1, -68.3)`, `(-33.9, 151.2)`; `neighbourhood` cases with `rings` 1 for an interior cell, a cell on the longitude seam, and a cell in the top row (Review Focus 3); and one `pack_bits` case with its bytes in hex.
- [ ] **Step 2: Write the failing Dart test.** It reads the JSON by a path built with `p.join('tool', 'species_pack', 'testdata', 'region_vectors.json')` and asserts every vector, plus: every neighbourhood member is in `0..cellCount - 1`; a seam cell's neighbourhood has 9 members; a top-row cell's has 6; `RegionTable.allowedMask` over the `pack_bits` case matches.
- [ ] **Step 3: Run it and see it fail.** `flutter test test/features/species_id/domain/region_grid_test.dart`
- [ ] **Step 4: Implement `region_grid.dart`.**
- [ ] **Step 5: Run both suites.** The Dart test above, and `python3.14 tool/species_pack/region_grid_test.py`. Both pass.
- [ ] **Step 6: Commit.** `feat(species-id): region grid shared by the app and the pack builder`

### Task 3: The namer

**Files:**
- Create: `lib/features/species_id/domain/services/species_namer.dart`
- Test: `test/features/species_id/domain/species_namer_test.dart`

**Interfaces:**
- Consumes: Task 1 (`PackCandidate`, `NamedCandidate`, `NamingConfig`), Task 2 (`RegionTable`).
- Produces:

```dart
class NamingResult extends Equatable {
  final double openScore; final List<NamedCandidate> candidates;
  final bool locationLimited; final bool suggestable;
  static const unusable = NamingResult(openScore: 0, candidates: [], locationLimited: false, suggestable: false);
}
class SpeciesNamer {
  SpeciesNamer({required List<PackCandidate> candidates, required Float32List textEmbeddings,
    required int embeddingSize, required double logitScale, required NamingConfig config,
    required RegionTable regions, required int neighbourCells});
  /// [cell] is the photo's grid cell, or null when it has no location.
  NamingResult name({required Float32List embedding, required int boxShorterSide, int? cell});
}
```

The algorithm is the spec's section 4, steps 1 to 5, exactly. Softmax is computed with the maximum logit subtracted first, so `logitScale` 100 cannot overflow.

- [ ] **Step 1: Write the failing tests.** Use four candidates with 3-wide unit text embeddings along the axes and a diagonal, `logitScale` 10, and compute every expected score in the test from the definition (`exp(a) / sum`), never typed in. A helper builds a `RegionTable` from a list of cell sets.

```dart
test('open score is the top share over every candidate', ...);
test('with a location, candidates not recorded nearby are dropped and scores renormalised', ...);
test('a neighbouring cell counts as nearby', ...);
test('fewer allowed than minAllowedCandidates falls back to every candidate and the higher bar', () {
  // locationLimited is false; suggestable needs suggestScoreNoLocation
});
test('no location uses every candidate and the higher bar', ...);
test('not suggestable below minCropSide', ...);
test('not suggestable below minOpenScore even when the limited score is high', () {
  // the case the two scores exist for: two allowed candidates, a diffuse embedding
});
test('keeps at most topK, best first', ...);
test('a zero, NaN or wrong-length embedding is unusable and does not throw', () {   // Review Focus 2
  expect(namer.name(embedding: Float32List(3), boxShorterSide: 200), NamingResult.unusable);
  expect(namer.name(embedding: Float32List.fromList([double.nan, 0, 1]), boxShorterSide: 200), NamingResult.unusable);
  expect(namer.name(embedding: Float32List(5), boxShorterSide: 200), NamingResult.unusable);
});
```

- [ ] **Step 2: Run and see them fail.** `flutter test test/features/species_id/domain/species_namer_test.dart`
- [ ] **Step 3: Implement `SpeciesNamer`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit.** `feat(species-id): name a crop from its embedding`

### Task 4: Identification entities and rules

**Files:**
- Create: `lib/features/species_id/domain/entities/media_identification.dart`, `lib/features/species_id/domain/services/identification_rules.dart`
- Test: `test/features/species_id/domain/identification_rules_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:

```dart
enum IdentificationDecision { undecided, accepted, rejected }
class IdentificationBox extends Equatable { final double x, y, width, height; double iou(IdentificationBox other); }
class MediaIdentification extends Equatable { final String id, mediaId; final IdentificationBox box;
  final int boxPixelWidth, boxPixelHeight; final double detectorScore, openScore;
  final List<NamedCandidate> candidates; final bool locationLimited, suggestable;
  final IdentificationDecision decision; final String? decidedSpeciesId;
  final DateTime? decidedAt; final DateTime createdAt; MediaIdentification copyWith({...}); }
class MediaIdentificationRun extends Equatable { final String mediaId, packVersion, detectorId, classifierId;
  final int? locationCell; final DateTime analysedAt; final int imageWidth, imageHeight, detectionCount; }
class TaggedSpecies extends Equatable { final String speciesId; final String? scientificName; }
class SpeciesSuggestion extends Equatable { final NamedCandidate top; final double score; final int count;
  final String cropIdentificationId; final List<String> identificationIds;
  final List<NamedCandidate> alternatives; }   // the best crop's candidates, at most 3

bool candidateMatches(PackCandidate candidate, TaggedSpecies tagged);
/// The identifications whose decision changes. Unchanged ones are omitted.
List<MediaIdentification> reconcileDecisions(List<MediaIdentification> all, List<TaggedSpecies> tagged, {required DateTime now});
/// Suggestable, undecided, top candidate not tagged; grouped by top candidate; best score first.
List<SpeciesSuggestion> groupSuggestions(List<MediaIdentification> all, List<TaggedSpecies> tagged);

enum RefreshAction { none, rename, analyse }
RefreshAction decideRefresh({required MediaIdentificationRun? run, required String packVersion,
  required String detectorId, required String classifierId, required int? cell,
  required bool cropsPresent, required bool embeddingsPresent});
/// What to store after analysing again: every decided row of [previous] is kept,
/// and a [fresh] detection that overlaps a kept row (IoU >= 0.5) with the same
/// top candidate is dropped. Returns (keep, insert, deleteIds).
({List<MediaIdentification> keep, List<MediaIdentification> insert, List<String> deleteIds})
    carryDecisions({required List<MediaIdentification> previous, required List<MediaIdentification> fresh});
```

`candidateMatches`: the catalogue id equals the species id; otherwise scientific names are equal ignoring case and surrounding space. A candidate with a catalogue id still matches by scientific name.

`decideRefresh`: no run gives `analyse`; a missing crop, or a different detector or classifier id, gives `analyse`; a different pack version or cell gives `rename` when embeddings are present and `analyse` when they are not; otherwise `none`.

- [ ] **Step 1: Write the failing tests**, one per rule: undecided becomes accepted with the matching species, by catalogue id and by scientific name; a lower-ranked candidate matching still accepts; accepted with its species untagged becomes rejected; rejected is never changed; grouping merges three detections of one species into one suggestion with `count` 3 and the best crop; a tagged species is not suggested; a not-suggestable detection is not suggested; each branch of `decideRefresh`; `carryDecisions` keeps a rejected row and drops the overlapping fresh one, keeps a non-overlapping fresh one, and deletes old undecided rows.
- [ ] **Step 2: Run and see them fail.** `flutter test test/features/species_id/domain/identification_rules_test.dart`
- [ ] **Step 3: Implement both files.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit.** `feat(species-id): identification decisions, grouping and refresh rules`

### Task 5: Main database tables, schema version 374 (shipped as 375: main took 374 for #4660)

**Files:**
- Create: `lib/core/database/tables/identification_tables.dart`, `lib/core/database/migrations/helpers/identification_migrations.dart`
- Modify: `lib/core/database/database.dart` (import, export, `@DriftDatabase` list, `currentSchemaVersion` 373 to 374, a `migrationVersions` entry), `lib/core/database/migrations/app_database_migrations.dart` (the `part` line), `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (the rung), `lib/core/database/migrations/before_open_table_backstops.dart` (the backstop), `lib/core/database/performance_indexes.dart`, `lib/core/database/change_log/change_log_policy.dart`, `lib/features/agent_access/data/sql/sql_denied_set.dart`, `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` (regenerated), `tool/demo_data/src/checks/coverage_check.dart`, `docs/developer/database.md` (table count)
- Test: `test/core/database/migration_v375_media_identifications_test.dart`

**Interfaces:**
- Produces: drift tables `MediaIdentificationRuns` (`@DataClassName('MediaIdentificationRunRow')`) and `MediaIdentifications` (`@DataClassName('MediaIdentificationRow')`), with the columns in the spec's section 5. Timestamps are integer epoch milliseconds. `decision` is text. `candidatesJson` is text. Neither table has `hlc`. `mediaId` carries no `references`.
- Produces: `_assertMediaIdentificationTables()` on `AppDatabase`, idempotent.
- Produces: performance index `idx_media_identifications_media` on `media_identifications(media_id)`.

Template: version 362, `dive_deco_status`. Copy the shape of `tables/dive_deco_status_tables.dart`, `helpers/deco_status_migrations.dart`, its rung, its backstop line, and `test/core/database/migration_v362_dive_deco_status_test.dart`.

- [ ] **Step 1: Write the failing migration test**, following the v362 test: 374 is in `migrationVersions`; a fresh database has both tables, neither with an `hlc` column; a database already at the current `user_version` that lacks them gains them through the backstop; the index exists on a fresh database.
- [ ] **Step 2: Run and see it fail.** `flutter test test/core/database/migration_v375_media_identifications_test.dart`
- [ ] **Step 3: Add the tables, the helper, the rung, the backstop and the index.** The rung and `migrationVersions` comments say the tables never sync, so the floor does not move.
- [ ] **Step 4: Register the tables.** `changeLogTables`: both as `ChangeLogClass.excluded`. `kSqlReadableExcludedTables`: both. `demoCoverageExclusions`: both, with a reason.
- [ ] **Step 5: Regenerate.** `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background; never `--build-filter`), then `dart run tool/generate_sql_column_notes.dart`.
- [ ] **Step 6: Run the tests.** The new test, plus `test/core/database/change_log/change_log_policy_test.dart`, `test/features/agent_access/data/sql/sql_denied_set_test.dart`, `test/features/agent_access/data/resources/schema_resource_test.dart`, `test/tool/demo_data/coverage_check_test.dart`, `test/core/database/database_table_libraries_test.dart`, `test/core/database/performance_indexes_test.dart`. All pass.
- [ ] **Step 7: Commit.** `feat(species-id): tables for identifications and their runs (schema 374)`

### Task 6: Device-local embeddings, local cache version 25

**Files:**
- Create: `lib/core/database/local_cache_identification_table.dart`
- Modify: `lib/core/database/local_cache_database.dart` (import, export, table list, `schemaVersion` 24 to 25, `if (from < 25) await m.createTable(identificationEmbeddings);`, and the matching `beforeOpen` backstop), `lib/core/services/storage/local_cache_sweep.dart`
- Test: `test/core/database/local_cache_migration_v25_identification_embeddings_test.dart`, and `test/core/services/storage/local_cache_sweep_test.dart` extended

**Interfaces:**
- Produces: `IdentificationEmbeddings` with `identificationId` (text, primary key), `classifierId` (text), `embedding` (blob, 16-bit floats).
- Produces: `LocalCacheSweep.run` also deletes embeddings whose identification is gone from the open library, through the existing `_sweepOrphans` with `libraryTable: _library.mediaIdentifications`.

- [ ] **Step 1: Write the failing tests**, following `local_cache_migration_v24_site_catalogue_position_from_test.dart`, plus a sweep test: an embedding with no identification row is removed, one with a row is kept.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, then regenerate with build_runner as in Task 5.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit.** `feat(species-id): device-local store for crop embeddings`

### Task 7: Repositories, crop files and cleanup

**Files:**
- Create: `lib/features/species_id/data/repositories/media_identification_repository.dart`, `lib/features/species_id/data/repositories/identification_embedding_repository.dart`, `lib/features/species_id/data/services/identification_crop_store.dart`, `lib/features/species_id/data/services/identification_cleanup.dart`, `lib/features/species_id/presentation/providers/species_id_providers.dart` (with only `mediaIdentificationRepositoryProvider`, `identificationEmbeddingRepositoryProvider`, `identificationCropStoreProvider` and `identificationCleanupProvider`; Task 10 adds the rest)
- Modify: `test/architecture/agent_write_coverage_exempt.dart` (exempt both repositories: the rows are derived by the app, not written by the diver), `lib/features/media_store/presentation/providers/media_store_providers.dart` (the `onDeleted` hook)
- Test: `test/features/species_id/data/media_identification_repository_test.dart`, `test/features/species_id/data/identification_crop_store_test.dart`, `test/features/species_id/data/identification_cleanup_test.dart`

**Interfaces:**
- Consumes: Task 4 entities, Task 5 and Task 6 tables.
- Produces:

```dart
class MediaIdentificationRepository {
  MediaIdentificationRepository(AppDatabase db);
  Stream<void> watchChanges();                       // tableUpdates on both tables
  Future<MediaIdentificationRun?> runFor(String mediaId);
  Future<List<MediaIdentification>> forMedia(String mediaId);
  /// One transaction: upsert [run], delete [deleteIds], insert [insert].
  Future<void> storeRun(MediaIdentificationRun run,
      {required List<MediaIdentification> insert, required List<String> deleteIds});
  Future<void> updateIdentifications(List<MediaIdentification> changed, {MediaIdentificationRun? run});
  Future<List<String>> deleteForMedia(List<String> mediaIds);   // the identification ids removed
  /// Media ids that have a run or an identification but no media row.
  Future<List<String>> orphanMediaIds();
  Future<int> count();
  Future<List<String>> deleteAll();
}
class IdentificationEmbeddingRepository {
  IdentificationEmbeddingRepository(LocalCacheDatabase db);
  Future<void> put(Map<String, Float32List> byIdentificationId, {required String classifierId});
  Future<Map<String, Float32List>> get(List<String> ids, {required String classifierId});
  Future<void> delete(List<String> ids);
  Future<void> deleteAll();
}
class IdentificationCropStore {
  IdentificationCropStore({required Future<String> Function() supportPath});
  Future<Directory> root();                          // <support>/species_id/crops
  Future<File> fileFor(String mediaId, String identificationId);
  Future<void> write(String mediaId, String identificationId, Uint8List jpeg);
  Future<bool> allPresent(String mediaId, List<String> identificationIds);
  Future<void> deleteMedia(List<String> mediaIds);
  Future<void> delete(String mediaId, List<String> identificationIds);
  Future<void> deleteAll();
  Future<int> sizeBytes();
}
class IdentificationCleanup {
  IdentificationCleanup({required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings, required IdentificationCropStore crops});
  /// Called from the deletion coordinator. Does nothing when [undoable].
  Future<void> onMediaDeleted(List<String> mediaIds, {required bool undoable});
  /// Rows whose media is gone, with their crops and embeddings. Run at app start.
  Future<int> sweepOrphans();
  /// Every identification in the open library and every crop on the device.
  Future<void> clearAll();
}
```

None of these throws out of `onMediaDeleted` or `sweepOrphans`; they log and carry on, as `purgeMediaCaches` does.

- [ ] **Step 1: Write the failing tests.** Repository: round trip of every column including `candidates_json`; `storeRun` is atomic; `orphanMediaIds` finds a run whose media row is absent and ignores one whose row exists. Crop store, in a `Directory.systemTemp.createTemp` directory: write then `allPresent`; a missing file makes `allPresent` false; `deleteMedia` removes the media's folder. Cleanup: `onMediaDeleted(undoable: true)` removes nothing; `undoable: false` removes rows, embeddings and crops; `sweepOrphans` removes the orphan and its files and leaves the rest; `clearAll` empties all three.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement the four files.**
- [ ] **Step 4: Wire the hook.** In `media_store_providers.dart`, the `onDeleted` closure also calls `ref.read(identificationCleanupProvider).onMediaDeleted([for (final i in items) i.id], undoable: undoable)`, after `purgeMediaCaches`.
- [ ] **Step 5: Run the tests**, plus `test/architecture/agent_write_coverage_test.dart`. All pass.
- [ ] **Step 6: Commit.** `feat(species-id): store identifications, embeddings and crops`

### Task 8: The engine plugin and the feature flag

**Files:**
- Create: `packages/submersion_vision/pubspec.yaml`, `packages/submersion_vision/lib/submersion_vision.dart`, `packages/submersion_vision/darwin/submersion_vision.podspec`, `packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift`, `packages/submersion_vision/darwin/Classes/VisionPipeline.swift`, `lib/features/species_id/domain/entities/vision_analysis.dart`, `lib/features/species_id/domain/services/vision_engine.dart`, `lib/features/species_id/data/engines/channel_vision_engine.dart`
- Modify: `pubspec.yaml` (`submersion_vision: path: packages/submersion_vision`), `lib/core/constants/feature_flags.dart`, and the generated `ios/Podfile.lock`, `macos/Podfile.lock`, `pubspec.lock`
- Test: `test/features/species_id/data/channel_vision_engine_test.dart`

**Interfaces:**
- Produces, in `feature_flags.dart`: `bool marineLifeIdEnabled = const bool.fromEnvironment('MARINE_LIFE_ID');` with a doc comment in the style of `lightroomUiEnabled`, naming the two conditions for turning it on.
- Produces:

```dart
enum VisionAvailability { available, unsupportedPlatform, deviceNotEligible }
class VisionModels extends Equatable { final String detectorPath, classifierPath;
  final int detectorInputSize; final List<double> detectorMean, detectorStd;
  final double scoreThreshold; final int maxBoxes; final double cropPadding;
  final int classifierInputSize; final List<double> classifierMean, classifierStd;
  final int embeddingSize, cropThumbnailSize;
  factory VisionModels.fromManifest(SpeciesPackManifest m, {required String detectorPath, required String classifierPath}); }
class VisionDetection extends Equatable { final double x, y, width, height, score;
  final int pixelWidth, pixelHeight; final Uint8List cropJpeg; final Float32List embedding; }
class VisionAnalysis extends Equatable { final int imageWidth, imageHeight; final List<VisionDetection> detections; }

abstract class VisionEngine {
  static const String coreMlEngine = 'coreml';
  String? get engineName;                       // 'coreml' on Apple, null when unsupported
  Future<VisionAvailability> availability();
  Future<void> load(VisionModels models);
  Future<VisionAnalysis> analyze({String? path, Uint8List? bytes});
  Future<void> unload();
  Future<void> excludeFromBackup(String directory);
}
class VisionEngineException implements Exception { final String code; final String? message; }
class ChannelVisionEngine implements VisionEngine { ChannelVisionEngine({TargetPlatform? platform}); }
```

- Channel `submersion_vision`, methods: `availability` returning a string; `load` taking the `VisionModels` fields as a map; `analyze` taking `{path}` or `{bytes}` and returning `{imageWidth, imageHeight, detections: [{x, y, width, height, score, pixelWidth, pixelHeight, crop, embedding}]}` with `crop` as bytes and `embedding` as a float32 typed list; `unload`; `excludeFromBackup` taking `{path}`.
- `ChannelVisionEngine.availability` returns `unsupportedPlatform` without calling the channel unless the platform is iOS or macOS, and on `MissingPluginException`. A `PlatformException` from `load` or `analyze` becomes `VisionEngineException`.

**Native behaviour** (`VisionPipeline.swift`), all on a private serial background queue:
- Podspec: iOS 15.0, macOS 12.0, Swift 5.9, `s.frameworks = 'CoreML', 'ImageIO', 'CoreGraphics', 'Accelerate'`.
- `availability`: on iOS, `deviceNotEligible` when `ProcessInfo.processInfo.physicalMemory` is under 5 GiB; otherwise `available`.
- `load`: accept a compiled model directory (`.mlmodelc`) or a model package (`.mlpackage`); a package is compiled with `MLModel.compileModel(at:)` and the result moved beside it, once. `MLModelConfiguration.computeUnits = .all`.
- `analyze`: decode with ImageIO applying EXIF orientation, with `kCGImageSourceThumbnailMaxPixelSize` 4096 so a very large photo is bounded (Review Focus 1). Report that oriented size as `imageWidth` and `imageHeight`.
- Detector: resize straight to `detectorInputSize` square, no letterbox; scale to 0 to 1; normalise; channel order RGB; shape `[1, 3, S, S]`. Outputs: one array `[1, 300, 4]` of centre x, centre y, width, height, normalised; one `[1, 300, 1]` of raw scores. Find them by shape, not by name. Apply a sigmoid, drop below `scoreThreshold`, keep the best `maxBoxes`, convert to top-left boxes clamped to 0 to 1.
- For each box: pad by `cropPadding` on each side and clamp to the image; `pixelWidth` and `pixelHeight` are the unpadded box in oriented pixels; the thumbnail is the padded crop fitted inside `cropThumbnailSize`, JPEG quality 0.85.
- Classifier: the padded crop is padded to a square with the mean colour, resized to `classifierInputSize` (bicubic), normalised, `[1, 3, 224, 224]`. The single output is the embedding, returned unnormalised.
- A memory warning on iOS unloads both models.
- `excludeFromBackup`: set `isExcludedFromBackup` on the directory URL.
- Errors come back as `FlutterError` with code `not_loaded`, `decode_failed` or `inference_failed`.

- [ ] **Step 1: Write the failing channel test**, mocking the channel with `setMockMethodCallHandler` and restoring it in `addTearDown`: on a macOS platform `availability` maps each string; on Android it returns `unsupportedPlatform` and the handler is never called; `MissingPluginException` maps to `unsupportedPlatform`; `analyze` decodes a two-detection reply into typed values; a `PlatformException` becomes `VisionEngineException`; `load` sends every `VisionModels` field.
- [ ] **Step 2: Run and see it fail.** `flutter test test/features/species_id/data/channel_vision_engine_test.dart`
- [ ] **Step 3: Create the package and the Dart side**, add the dependency, run `flutter pub get`.
- [ ] **Step 4: Write the Swift.** Build it: `flutter build macos --debug` (in the background). It compiles with no warnings from the new files.
- [ ] **Step 5: Run the channel test and see it pass.** Also run `test/architecture/test_global_state_restored_test.dart` and `test/architecture/host_platform_single_source_test.dart`.
- [ ] **Step 6: Commit.** `feat(species-id): on-device vision engine plugin for Apple platforms`

### Task 9: Pack store, manifest client and downloader

**Files:**
- Create: `lib/features/species_id/data/pack/species_pack_store.dart`, `lib/features/species_id/data/pack/species_pack_downloader.dart`
- Test: `test/features/species_id/data/species_pack_store_test.dart`, `test/features/species_id/data/species_pack_downloader_test.dart`

**Interfaces:**
- Consumes: Task 1, Task 2, Task 8 (`VisionEngine.excludeFromBackup`).
- Produces:

```dart
const String kSpeciesPackManifestUrl = String.fromEnvironment('SPECIES_PACK_MANIFEST_URL',
    defaultValue: 'https://github.com/submersion-app/submersion/releases/download/species-pack/manifest.json');

class SpeciesPackManifestClient {
  SpeciesPackManifestClient({http.Client? client, Uri? url, Duration timeout = const Duration(seconds: 30)});
  /// Null when nothing is published there (HTTP 404). Throws PackDownloadException otherwise.
  Future<SpeciesPackManifest?> fetch();
  Uri fileUrl(PackFile file);                    // beside the manifest
}
enum PackDownloadFailure { network, httpStatus, checksumMismatch, sizeMismatch, cancelled, storage, unsupportedFormat }
class PackDownloadException implements Exception { final PackDownloadFailure reason; final String? detail; }
class SpeciesPackDownloader {
  SpeciesPackDownloader({http.Client? client, Duration connectTimeout = const Duration(seconds: 30),
    Duration idleTimeout = const Duration(seconds: 30)});
  /// Resumes from `<dest>.part` with a Range request. A 200 reply restarts the file.
  /// The whole file is hashed and its size checked before the rename.
  Future<void> downloadFile({required Uri url, required PackFile file, required File dest,
    void Function(int receivedForThisFile)? onProgress, bool Function()? isCancelled});
}
class InstalledPack extends Equatable { final SpeciesPackManifest manifest; final String directory;
  final String detectorPath, classifierPath; }
class LoadedPack { final InstalledPack pack; final List<PackCandidate> candidates;
  final Float32List textEmbeddings; final RegionTable regions; }
class SpeciesPackStore {
  SpeciesPackStore({required Future<String> Function() supportPath, required String engine,
    Future<void> Function(String directory)? excludeFromBackup});
  Future<Directory> root();                      // <support>/species_id/pack
  Future<InstalledPack?> installed();
  Future<Directory> staging(String packVersion); // <root>/<version>.staging
  /// Every file for the engine is present in staging and verified by the caller.
  /// Unzips the two models, moves staging to <root>/<version>, removes older packs.
  Future<InstalledPack> install(SpeciesPackManifest manifest);
  Future<LoadedPack> load(InstalledPack pack);
  Future<void> remove();
  Future<int> sizeBytes();
}
```

- The `.part` file is kept on `network`, `httpStatus`, `cancelled` and `storage`, and deleted on `checksumMismatch` and `sizeMismatch`. A resumed download hashes the bytes already on disk first.
- A failed write (disk full) is `storage` (Review Focus 5).
- Unzip with `package:archive`'s file streams (`InputFileStream`, `extractArchiveToDisk` or the equivalent), never by reading a 600 MB archive into memory.
- `installed()` returns null when the directory, the manifest or either model is missing, and when the manifest's format is not supported.
- `install` calls `excludeFromBackup` on the pack root.
- `load` checks that the text embeddings hold `candidates.length * embeddingSize` values and the region bits `candidates.length * ((cellCount + 7) ~/ 8)` bytes, and throws `PackManifestException(malformed)` otherwise.

- [ ] **Step 1: Write the failing tests.** Downloader, with a fake `http.Client` and a temp directory: a clean download verifies and renames; a `.part` of 100 bytes sends `Range: bytes=100-` and a 206 reply completes it with the right hash; a 200 reply to a Range request starts over; a wrong hash throws `checksumMismatch` and leaves no `.part`; too many bytes throws `sizeMismatch`; `isCancelled` true throws `cancelled` and keeps the `.part`; a stream error throws `network` and keeps it; a destination that cannot be written throws `storage`. Manifest client: 404 gives null; 500 throws `httpStatus`; an unknown format throws `unsupportedFormat`. Store, with small real zip files built in the test: `install` then `installed()` returns paths that exist; a second version removes the first; `remove` clears it; `load` returns the candidates, a decoded embedding matrix and a working `RegionTable`; a short embeddings file throws; `excludeFromBackup` was called with the root.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement both files.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit.** `feat(species-id): install and download the model pack`

### Task 10: The analysis service and its providers

**Files:**
- Create: `lib/features/species_id/data/services/media_identification_service.dart`
- Modify: `lib/features/species_id/presentation/providers/species_id_providers.dart` (the providers below that Task 7 did not add), `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys.identifyFishOnOpen = 'species_id_identify_on_open'`, commented "Device-local:")
- Test: `test/features/species_id/data/media_identification_service_test.dart`, `test/features/species_id/presentation/species_id_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 4, 7, 8, 9.
- Produces:

```dart
class IdentificationImage { const IdentificationImage.path(String path); const IdentificationImage.bytes(Uint8List bytes); }
class MediaIdentificationService {
  MediaIdentificationService({required VisionEngine engine, required SpeciesPackStore packs,
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings, required IdentificationCropStore crops,
    required Future<IdentificationImage?> Function(MediaItem item) resolveImage,
    required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies,
    required bool Function() enabled,            // flag and toggle
    DateTime Function() now = DateTime.now, String Function()? newId,
    Duration idleUnload = const Duration(seconds: 60)});
  /// Queues the photo. One at a time, newest first. Never throws.
  Future<void> request(MediaItem item, {GeoPoint? location});
  /// Drops a queued request that has not started.
  void cancelPending(String mediaId);
  /// Records accepted and rejected decisions against the photo's current tags.
  Future<void> reconcile(String mediaId);
  Future<void> reject(List<String> identificationIds);
  bool isBusy(String mediaId);
  Stream<void> watchActivity();
  /// Called when the pack changes or is removed.
  Future<void> packChanged();
  Future<void> dispose();
}

final visionEngineProvider = Provider<VisionEngine>(...);
final visionAvailabilityProvider = FutureProvider<VisionAvailability>(...);
final speciesPackStoreProvider = Provider<SpeciesPackStore>(...);
final installedSpeciesPackProvider = FutureProvider<InstalledPack?>(...);
final identifyFishOnOpenProvider = StateNotifierProvider<..., bool>(...);   // default true
final mediaIdentificationRepositoryProvider, identificationEmbeddingRepositoryProvider,
      identificationCropStoreProvider, identificationCleanupProvider;
final mediaIdentificationServiceProvider = Provider<MediaIdentificationService>(...);
/// Empty when the flag is off.
final mediaSuggestionsProvider = FutureProvider.autoDispose.family<List<SpeciesSuggestion>, String>(...);
final mediaIdentificationBusyProvider = StreamProvider.autoDispose.family<bool, String>(...);
```

`request` does this, in order:
1. Return when `enabled()` is false, the item is not a photo, the engine is not `available`, or no pack is installed.
2. Work out the cell from `location` and the pack's grid; null without a location.
3. `decideRefresh`. `none`: reconcile and return.
4. `rename`: load the stored embeddings; name each undecided identification again; `updateIdentifications` with the run's new pack version and cell; reconcile.
5. `analyse`: `resolveImage`; null means return and record nothing. `engine.load` if needed, `engine.analyze`. Name each detection off the UI isolate. Give each an id. `carryDecisions` against what is stored. Write the crops, the embeddings, then `storeRun`. Reconcile.
6. Any exception is logged and swallowed; nothing is recorded.

Naming runs through `compute` (or `Isolate.run` where the web build allows it) with the embeddings and the loaded pack's arrays; the loaded pack is cached in the service and dropped by `packChanged`.

`mediaSuggestionsProvider` reads `forMedia` and the photo's tags (species id and scientific name), returns `groupSuggestions`, and invalidates on `repository.watchChanges()`, `mediaSpeciesRepository.watchTagChanges()` and `speciesRepository.watchSpeciesChanges()`.

- [ ] **Step 1: Write the failing service tests**, with a fake `VisionEngine`, a real in-memory `AppDatabase` and `LocalCacheDatabase`, and a temp crop directory: each skip condition records nothing; a first analysis stores a run, the identifications, the embeddings and the crops; a photo with no detections stores a run with `detection_count` 0 and is not analysed twice; no image records nothing and is tried again on the next request; an engine failure records nothing and does not throw; a second request with nothing changed does not call the engine; a new pack version with the same model ids renames without calling the engine; a changed cell renames; a changed classifier id analyses again; a missing crop file analyses again; a rejected identification survives analysing again and the overlapping new detection is not stored; requests run one at a time and newest first; `cancelPending` drops a queued request; the engine is unloaded after `idleUnload` (with `fakeAsync`); `reconcile` writes accepted and rejected.
- [ ] **Step 2: Write the failing provider tests:** `mediaSuggestionsProvider` is empty with the flag off; it returns stored suggestions when no pack is installed; it rebuilds when an identification is stored and when a tag is added; `visionEngineProvider` is the unsupported engine on Android.
- [ ] **Step 3: Run and see them fail.**
- [ ] **Step 4: Implement.** `resolveImage` in the provider: the item's `localPath` when that file exists, otherwise `mediaBytesProvider(item)`'s bytes when available, otherwise null.
- [ ] **Step 5: Run the tests**, plus `test/architecture/provider_change_tick_test.dart`, `test/architecture/media_provider_disposal_test.dart` and `test/architecture/settings_setters_wait_for_load_test.dart`. All pass.
- [ ] **Step 6: Commit.** `feat(species-id): analyse a photo and keep what was found`

### Task 11: Suggestions in the viewer

**Files:**
- Create: `lib/features/species_id/data/services/suggestion_acceptor.dart`, `lib/features/species_id/presentation/widgets/suggested_species_section.dart`, `lib/features/species_id/presentation/widgets/tagged_on_photo_section.dart`, `lib/features/media/presentation/pages/media_viewer_identification.dart` (a `part of 'media_viewer_page.dart'`)
- Modify: `lib/features/media/presentation/widgets/media_species_chips_row.dart`, `lib/features/media/presentation/widgets/media_species_sheet.dart`, `lib/features/media/presentation/pages/media_viewer_page.dart`, `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart`, all 11 files under `lib/l10n/arb/`
- Test: `test/features/species_id/data/suggestion_acceptor_test.dart`, `test/features/species_id/presentation/suggested_species_section_test.dart`, `test/features/media/presentation/widgets/media_species_chips_row_suggestions_test.dart`, `test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart`, `test/features/media/presentation/pages/media_viewer_identification_test.dart`

**Interfaces:**
- Consumes: Task 10 providers and service.
- Produces:

```dart
class SuggestionAcceptor {
  SuggestionAcceptor({required SpeciesRepository species});
  /// The catalogue species when the id exists; else one with the same scientific
  /// name; else a new species of the diver's own.
  Future<Species> resolve(PackCandidate candidate);
}
final suggestionAcceptorProvider = Provider<SuggestionAcceptor>(...);

class MediaSpeciesChipsRow { ..., this.onSuggestionTap });   // VoidCallback?; null means inert
class SuggestedSpeciesSection extends ConsumerWidget {
  const SuggestedSpeciesSection({super.key, required this.item, this.sitting});
}
class TaggedOnPhotoSection extends ConsumerWidget {
  const TaggedOnPhotoSection({super.key, required this.item, this.sitting});
}
extension _ViewerIdentification on _MediaViewerPageState {
  void requestIdentification(MediaItem item, Dive? dive);
  void identificationItemChanged(String? previousMediaId);
}
```

Widget keys: `media_suggested_chip_<gbifKey>`, `media_suggested_row_<gbifKey>`, `media_suggested_add_<gbifKey>`, `media_suggested_dismiss_<gbifKey>`, `media_suggested_addAll`, `media_suggested_crop_<gbifKey>`, `media_suggested_candidate_<gbifKey>` (in the crop view), `media_tagged_remove_<speciesId>`.

New strings (English; translate each into the other 10 locales):

| Key | English |
| --- | --- |
| `media_species_suggested` | Suggested |
| `media_species_suggestedChip` | `{name} {percent}%` |
| `media_species_suggestedCount` | `{name} ({count})` |
| `media_species_add` | Add |
| `media_species_addAll` | Add all |
| `media_species_dismiss` | Dismiss suggestion |
| `media_species_identifying` | Looking for fish... |
| `media_species_possibleMatches` | Possible matches |
| `media_species_cropUnavailable` | Image not on this device |
| `media_species_taggedOnPhoto` | Tagged on this photo |
| `media_species_removeTag` | `Remove {name}` |

A candidate's shown name is `localizedSpeciesName(l10n, catalogId, commonName)` when it has a catalogue id, and its `commonName` otherwise.

Behaviour:
- **Chip row:** after the tagged chips, one outlined `ActionChip` per suggestion (transparent background, a side border, an `Icons.add` avatar), labelled with `media_species_suggestedChip`. `onPressed` is `onSuggestionTap`. `_BottomMetadataOverlay` passes a callback that opens the species sheet only when the toolbar's write controls are offered (the same `writeControls` test the toolbar uses); otherwise null.
- **Sheet:** `SuggestedSpeciesSection` sits above the existing content and renders nothing with no suggestions and no analysis in flight. `TaggedOnPhotoSection` sits above the "Other species" button and lists the photo's shown species chips that are not among the dive's sightings, each with a delete control; it renders nothing when there are none.
- **Add:** `suggestionAcceptor.resolve(candidate)`, then with no sitting `speciesTaggingService.tagPhoto(mediaId:, speciesId:)`, and with a sitting `holdPickedSpecies(session, species)`. Both are in a `try`; a failure shows the `common_error_tryAgain` snackbar as `_pickOther` does.
- **Dismiss:** `mediaIdentificationService.reject(suggestion.identificationIds)`, at once in both modes.
- **Add all:** Add for each listed suggestion in turn.
- **Crop view:** a bottom sheet with the crop (a placeholder and `media_species_cropUnavailable` when the file is missing) and up to three candidates, each addable. It passes `useSafeArea`.
- **Remove a tag:** with no sitting `speciesTaggingService.untagPhoto`; with a sitting the same `toggled(chip, tagged: false, ...)` call `_holdToggle` makes.
- **Trigger** (`media_viewer_identification.dart`): called from `build` beside `_backfillEnrichment`, for the current item only. It returns at once unless `marineLifeIdEnabled` and the item is a photo. It remembers requested media ids in a `Set<String>` for the viewer session. From a post-frame callback it starts a 400 ms timer; when the timer fires and the item is still current and the state is mounted, it calls `service.request(item, location: ...)`. The location is the item's own latitude and longitude, else `dive?.site?.location`, else `dive?.entryLocation`. When the current item changes, the timer is cancelled and `service.cancelPending(previousId)` is called. It also listens to `mediaTagChipsProvider(item.id)` for the current item and calls `service.reconcile(item.id)` when the chips change.

- [ ] **Step 1: Write the failing tests.** Acceptor: a catalogue id that exists returns that species; a catalogue id that no longer exists falls back to the scientific name (Review Focus 4); no match creates a species with the candidate's names and category. Chip row: no suggestions leaves it as it is today; suggestions appear after tagged chips with their percentages; a tap calls the callback; a null callback is inert; the flag off shows none. Sheet: the Suggested section lists grouped rows with counts; Add tags at once with no sitting and holds with one; Dismiss calls `reject`; Add all adds each; a missing crop shows the placeholder; the progress indicator shows while busy; Tagged on this photo lists only tags that are not dive sightings and removes one in both modes. Viewer trigger (`fakeAsync`): the request fires after 400 ms for the current photo; swiping away within 400 ms fires nothing for the first photo; a neighbouring page built ahead does not fire; a video does not fire; the same photo is requested once per viewer session; the flag off fires nothing.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Add the strings to all 11 ARB files and run `flutter gen-l10n`.**
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run the tests**, plus the existing chip row and sheet test files, `test/l10n/arb_parity_test.dart`, `test/l10n/untranslated_english_values_test.dart`, `test/architecture/bottom_sheet_safe_area_test.dart` and `test/architecture/snack_bar_action_times_out_test.dart`. All pass.
- [ ] **Step 6: Commit.** `feat(species-id): suggested species in the photo viewer`

### Task 12: Settings page and storage usage

**Files:**
- Create: `lib/features/species_id/presentation/providers/species_pack_controller.dart`, `lib/features/species_id/presentation/pages/marine_life_identification_page.dart`
- Modify: `lib/core/router/app_router.dart` (a `marine-life-identification` route under `/settings`), `lib/core/router/web_unavailable_routes.dart`, `lib/features/media_store/presentation/pages/photos_videos_page.dart` (the entry, hidden when the flag is off), `lib/core/services/storage/storage_category.dart`, `lib/core/services/storage/storage_inventory.dart`, `lib/features/settings/presentation/providers/storage_usage_providers.dart`, `lib/features/settings/presentation/pages/storage_usage_page.dart`, all 11 ARB files
- Test: `test/features/species_id/presentation/species_pack_controller_test.dart`, `test/features/species_id/presentation/marine_life_identification_page_test.dart`, and the existing `test/core/services/storage/storage_inventory_test.dart` (fifteen becomes seventeen)

**Interfaces:**
- Consumes: Tasks 8, 9, 10.
- Produces:

```dart
sealed class SpeciesPackState {}
class PackUnsupported extends SpeciesPackState { final VisionAvailability reason; }   // unsupportedPlatform, deviceNotEligible
class PackNotPublished extends SpeciesPackState {}
class PackNotForThisDevice extends SpeciesPackState {}       // manifest has no files for the engine
class PackNeedsAppUpdate extends SpeciesPackState {}
class PackNotInstalled extends SpeciesPackState { final int bytes; final bool resumable; }
class PackDownloading extends SpeciesPackState { final int received, total; }
class PackInstalled extends SpeciesPackState { final String version; final int bytes; final int? updateBytes; }
class PackFailed extends SpeciesPackState { final PackDownloadFailure reason; final int bytes; }

class SpeciesPackController extends Notifier<SpeciesPackState> {
  Future<void> refresh();     // availability, installed pack, published manifest
  Future<void> download();    // every file for the engine, in manifest order, then install
  void cancel();
  Future<void> remove();
}
final speciesPackControllerProvider = NotifierProvider<SpeciesPackController, SpeciesPackState>(...);
```

`StorageCategoryId.identificationModel` in `StorageGroup.appData` (the pack root), and `StorageCategoryId.identificationCrops` in `StorageGroup.appData` (the crops root).

Page keys: `species_id_download`, `species_id_cancel`, `species_id_remove`, `species_id_update`, `species_id_toggle`, `species_id_clear`, `species_id_credits`.

New strings (English):

| Key | English |
| --- | --- |
| `settings_speciesId_title` | Marine life identification |
| `settings_speciesId_entrySubtitle` | Find fish in your photos and suggest what they are |
| `settings_speciesId_intro` | Finds fish in your photos and suggests what they are. Runs on this device. Your photos never leave it. |
| `settings_speciesId_model` | Model |
| `settings_speciesId_modelNotDownloaded` | Not downloaded |
| `settings_speciesId_modelNotAvailable` | Not available yet |
| `settings_speciesId_modelNotForDevice` | Not available for this device |
| `settings_speciesId_modelInstalled` | `Installed ({version})` |
| `settings_speciesId_download` | `Download ({size})` |
| `settings_speciesId_resume` | `Continue download ({size})` |
| `settings_speciesId_update` | `Update ({size})` |
| `settings_speciesId_remove` | Remove model |
| `settings_speciesId_downloading` | `Downloading {percent}%` |
| `settings_speciesId_downloadConfirmTitle` | Download the model? |
| `settings_speciesId_downloadConfirmBody` | `This downloads {size} and keeps it on this device. You can remove it at any time.` |
| `settings_speciesId_downloadFailed` | The download did not finish. Try again to continue where it stopped. |
| `settings_speciesId_downloadNoSpace` | There is not enough free space on this device. |
| `settings_speciesId_needsAppUpdate` | This model needs a newer version of Submersion. |
| `settings_speciesId_toggle` | Identify fish when I open a photo |
| `settings_speciesId_kept` | Suggestions kept on this device |
| `settings_speciesId_keptValue` | `{count} ({size})` |
| `settings_speciesId_clear` | Clear suggestions |
| `settings_speciesId_clearConfirmTitle` | Clear all suggestions? |
| `settings_speciesId_clearConfirmBody` | This removes every suggestion and its cropped image. Species you have tagged are not affected. |
| `settings_speciesId_credits` | Credits and licences |
| `settings_speciesId_unsupported` | Marine life identification is not available on this device yet. |
| `settings_speciesId_notEligible` | This device does not have enough memory to run the model. |
| `settings_storageUsage_category_identificationModel` | Identification model |
| `settings_storageUsage_category_identificationCrops` | Identification crops |

Sizes are formatted with the app's existing byte formatter, the one Storage usage uses. The existing cancel string is reused.

The credits row opens a screen listing each entry of the manifest's `credits` (the installed pack's, or the published one's when none is installed): name, licence and text. The row is hidden when there is no manifest.

- [ ] **Step 1: Write the failing tests.** Controller, with fake manifest client, downloader and store: each state is reached from the right inputs, including `PackNotPublished` on a null manifest, `PackNotForThisDevice` when `supportsEngine` is false, and `PackNeedsAppUpdate` on `unsupportedFormat`; `download` reports progress across files and ends `PackInstalled`; a failure ends `PackFailed` and a later `refresh` shows `PackNotInstalled(resumable: true)`; `storage` maps to the no-space message; `cancel` stops it; `remove` returns to `PackNotInstalled`; after install and remove the service's `packChanged` is called. Page: each state shows the right row and button; Download asks for confirmation with the size before starting; the toggle writes the preference; Clear asks, then calls `clearAll`; the kept row shows the count and size; the entry on the Photos and videos page is absent with the flag off.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Add the strings and run `flutter gen-l10n`.**
- [ ] **Step 4: Implement.** `IdentificationCleanup.sweepOrphans` is started once after launch from the same place the storage sweeps are started, when the flag is on.
- [ ] **Step 5: Run the tests**, plus `test/l10n/arb_parity_test.dart`, `test/l10n/untranslated_english_values_test.dart`, `test/architecture/list_tile_trailing_width_test.dart`, `test/architecture/settings_whole_watch_test.dart` and `test/architecture/web_compile_seams_test.dart`. All pass.
- [ ] **Step 6: Commit.** `feat(species-id): settings page for the model and its suggestions`

### Task 13: The pack builder

**Files:**
- Create: `tool/species_pack/requirements.txt`, `tool/species_pack/manifest.py`, `tool/species_pack/manifest_test.py`, `tool/species_pack/models.py`, `tool/species_pack/candidates.py`, `tool/species_pack/regions.py`, `tool/species_pack/build_pack.py`, `docs/developer/species-identification.md`
- Modify: `.github/workflows/ci.yaml` (run `tool/species_pack/region_grid_test.py` and `tool/species_pack/manifest_test.py` with the other Python tests), `docs/developer/README.md` (link the new page)

**Interfaces:**
- Consumes: the spec's appendix (model sources, hashes, preparation, prompts), Task 2's `region_grid.py`.
- Produces: `python3.14 tool/species_pack/build_pack.py --out <dir> [--work <dir>] [--max-candidates N] [--skip-models]`, which writes a pack directory the app can install: `manifest.json` and the five files for `coreml`.
- `manifest.py`: `build_manifest(pack_version, files, naming, ...) -> dict` and `file_entry(path, engine) -> dict` (size and SHA-256). The manifest carries a `classifier.cropFit: "padSquare"` note.
- `models.py`: download by pinned URL and hash; load the detector with the safe loader only; convert both models as the appendix records; assert the converted classifier's output has cosine similarity of at least 0.999 with the original's on a fixed input; zip each compiled model.
- `candidates.py`: the candidate list as the spec's section 10, step 3, and its notes; one candidate per GBIF key; a catalogue species sharing a key with an earlier one in catalogue order is skipped; English names from GBIF vernacular names, falling back to the scientific name; categories by the rules in `species_category_mapper.dart`, with a table of the classes it maps and a comment naming that file.
- `regions.py`: per candidate, the 5 degree cells with at least one GBIF occurrence, packed with `region_grid.pack_bits`.
- Text embeddings use the appendix's three prompts.
- `requirements.txt` pins the versions the spike used.

- [ ] **Step 1: Write `manifest_test.py` first**, standard library only: a built manifest has format version 1, every `naming` value from the spec with `provisional` true, sizes and hashes that match the files on disk, and parses back. Run it and see it fail.
- [ ] **Step 2: Implement `manifest.py`; the test passes.**
- [ ] **Step 3: Implement the rest.** Network and heavy libraries are imported inside the functions that need them, so the two test modules import nothing beyond the standard library.
- [ ] **Step 4: Build a pack on this Mac.** Expect the GBIF steps to take a long while; run in the background, logging to a `.txt` file. Check: the output directory holds the manifest and five files; the manifest's sizes and hashes match; the candidate count is between 5,000 and 10,000, or whatever `--max-candidates` asked for.
- [ ] **Step 5: Write `docs/developer/species-identification.md`:** what the feature is; the flag and its build define; building a pack; serving it locally (`python3.14 -m http.server` in the pack directory) and pointing the app at it with `--dart-define=SPECIES_PACK_MANIFEST_URL=`; where things are stored; what must be true before the flag is turned on.
- [ ] **Step 6: Add the two tests to CI, run `python3.14 scripts/check_docs_links.py`, commit.** `feat(species-id): tool that builds a model pack`

### Task 14: End to end on macOS, and the pull request

- [ ] **Step 1: Run the app against the locally built pack.** Serve the pack directory; run the macOS app with `--dart-define=MARINE_LIFE_ID=true --dart-define=SPECIES_PACK_MANIFEST_URL=http://localhost:<port>/manifest.json` and its own copy of a database with linked photos.
- [ ] **Step 2: Walk the feature and note what happens:** the settings page shows the size; the download completes and survives a cancel and resume; opening a photo with close fish shows suggestions within a few seconds; Add tags the photo and logs the sighting; Dismiss does not come back after reopening; Add all works; a photo with no fish shows nothing; Remove model leaves stored suggestions usable; Clear suggestions empties them; Storage usage shows both categories; the largest photo in the library does not exhaust memory (Review Focus 1); a corrupt or unsupported file leaves the photo with no suggestions and no error. Fix what fails, with a test where one can catch it.
- [ ] **Step 3: Capture the after screenshots** of the screens in the spec's list, light and dark, named `<nn>-<screen>-after[-dark].png`.
- [ ] **Step 4: Final checks.** `dart format .`; `flutter analyze` (whole repository); the test files this plan wrote or changed, by path, in batches of at most 15.
- [ ] **Step 5: Push and open the pull request** from the repository template. The description says `Closes #4668`, links both specs and this plan, lists the calls above, and carries the screenshots.

## Self-review notes

- Spec coverage: section 1 is Task 8; 2 is Task 8; 3 is Tasks 1 and 9; 4 is Tasks 2 and 3; 5 is Tasks 4 to 7; 6 is Task 10; 7 is Task 11; 8 and 9 are Task 12; 10 is Task 13. Edge cases map to tests in Tasks 3, 4, 7, 9, 10 and 11, and to the walk-through in Task 14.
- The spec's "Tagged on this photo" section is Task 11. Its "analysed or named again" branches are `decideRefresh` in Task 4 and the service tests in Task 10.
- The demo logbook needs no code: it has its own database.
