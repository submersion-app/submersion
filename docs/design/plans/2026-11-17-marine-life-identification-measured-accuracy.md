# Marine life identification: measured accuracy, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in one session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure how often a model pack names marine animals correctly with
each candidate detector, set the pack's naming bars and crop fitting from
that measurement, and recommend a detector.

**Architecture:** A test set of openly licensed iNaturalist and Wikimedia
Commons photos is described by a committed CSV and downloaded into a
gitignored work folder. A small macOS command-line tool, compiled from the
app's own `VisionPipeline.swift`, detects and embeds every photo with each
detector (the Community Fish Detector, Megalodon 2024 and 2023). Python then
names each crop with a mirror of `species_namer.dart`, chooses bars on a tune
half, gates them on a held-out half, and writes a report.

**Tech Stack:** Python 3 standard library for every tested module; numpy,
open_clip and Pillow (from `tool/species_pack/requirements.txt`) for the
orchestration scripts; Swift and Core ML for the command-line tool; Dart for
the manifest field and the naming parity test.

**Spec:**
[docs/design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md](../specs/2026-11-17-marine-life-identification-measured-accuracy-design.md)

## Global Constraints

- Targets: suggested names right at least **0.85**, confident names at least
  **0.95**, judged on the one-sided 95% Wilson lower bound on the tune half.
- Junk crops: at most **0.02** named, point estimate on the tune half.
- A bar that no value meets is **never = 1.01**.
- Grids: `minOpenScore` 0.00 to 0.50 by 0.01; score bars 0.20 to 0.99 by 0.01.
- iNaturalist observations created on or after **2024-07-01**; photo licence
  `cc0`, `cc-by` or `cc-by-sa`; research grade; not captive; open geoprivacy.
- Groups (iNaturalist taxa): fish 47178, sharks and rays 47273, octopus
  47458, crabs 121639, sea snails and nudibranchs 47114, sea stars 47668,
  coral 47532. No habitat filter on sampling.
- About **450** observations per region, seven regions, natural mix; each
  group other than fish topped up to **150** photos. Top-ups never set or
  gate a bar.
- Megalodon in the scorer: letterbox (grey 114), input 640, mean 0, std 1,
  score threshold **0.25**, suppression IoU **0.7**, at most 8 boxes.
  Detector merge: IoU **0.5**.
- Pre-cutoff region check: GBIF records dated before 2024-07-01.
- Measured bars apply only with the same detector id, the same classifier id
  and a candidate count within **10%** of the measured one. The bars written
  to `manifest.py` are the Community Fish Detector's.
- Modules run by CI use the standard library only.
- No photos, embeddings or work files in git; the work folder defaults to
  `build/species_accuracy_work`.
- No em-dashes anywhere. No mention of the tool that wrote this in any repo
  or GitHub text. Run only changed test files, by path.

## Review Focus

1. **Ties between candidates.** Equal logits must rank the lower index first
   on both sides, or the parity test passes by luck. Pinned by a tied case
   in the naming vectors (Task 1).
2. **A cell at the antimeridian.** The pre-cutoff GBIF query for a
   neighbourhood that wraps longitude must ask two boxes, not one box running
   the wrong way round the world. Pinned in Task 4.
3. **An empty group.** A region, split or bucket with no suggested crops must
   not divide by zero and must count as not meeting a target. Pinned in Task 2.
4. **A GBIF synonym.** An iNaturalist name that GBIF matches as a synonym must
   take the accepted key, or an in-pack fish is graded out-of-pack. Pinned in
   Task 4.
5. **A dev pack labelled measured.** Building the 1,495-candidate pack must
   still write provisional bars. Pinned in Task 5; a pack with another
   detector, in Task 7.
6. **A YOLO box off by the letterbox.** A Megalodon box mapped back without
   removing the padding lands beside the animal and its crop names the
   background. Checked against `ultralytics` in Task 8.

---

## File structure

| File | Responsibility |
| --- | --- |
| `tool/species_pack/region_grid.py` (modify) | Add the reader for `regions.bin`. |
| `tool/species_pack/naming.py` (create) | Mirror of `species_namer.dart` from logits; writes `testdata/naming_vectors.json`. |
| `tool/species_pack/bars.py` (create) | Wilson bounds, the bar search, the junk raise, the held-out gate, McNemar. |
| `tool/species_pack/metrics.py` (create) | Top-k accuracy, coverage and precision, breakdowns for the report. |
| `tool/species_pack/testset.py` (create) | Pure test set rules: names, filters, sampling, split, CSV, licences, query boxes, GBIF match reading. |
| `tool/species_pack/fetch_testset.py` (create) | Network and model work that builds the CSV and downloads photos. Not run in CI. |
| `tool/species_pack/score.py` (create) | Runs the Swift tool, names crops, chooses bars, writes the report. Not run in CI. |
| `tool/species_pack/vision_cli/` (create) | `main.swift`, `FlutterShim.swift`, `build.sh`. |
| `tool/species_pack/manifest.py` (modify) | `NAMING_MEASURED`, `naming_for`. |
| `tool/species_pack/build_pack.py` (modify) | Passes the candidate count to `build_manifest`. |
| `packages/submersion_vision/darwin/Classes/VisionPipeline.swift` (modify) | `canImport`, `VisionError`, `cropFit`. |
| `packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift` (modify) | `VisionError` moved out. |
| `lib/features/species_id/domain/entities/species_pack_manifest.dart` (modify) | `confidentScoreNoLocation`. |
| `test/features/species_id/domain/species_namer_vectors_test.dart` (create) | Dart side of the naming parity. |
| `.github/workflows/ci.yaml` (modify) | New Python tests and coverage list. |
| `tool/species_pack/boxes.py` (create) | Intersection over union and merging two detectors' boxes. |
| `tool/species_pack/megalodon.py` (create) | Fetches the pinned Megalodon checkpoints and converts them to Core ML. Not run in CI. |

Each `<module>_test.py` sits beside its module and follows `manifest_test.py`
(`unittest`, modules loaded by path).

---

### Task 1: Naming mirror and parity vectors

**Files:**
- Modify: `tool/species_pack/region_grid.py`, `tool/species_pack/region_grid_test.py`
- Create: `tool/species_pack/naming.py`, `tool/species_pack/naming_test.py`,
  `tool/species_pack/testdata/naming_vectors.json`,
  `test/features/species_id/domain/species_namer_vectors_test.dart`
- Modify: `.github/workflows/ci.yaml` (add `naming_test.py`; add `naming.py`
  to the guards list)

**Interfaces:**
- Produces, in `region_grid.py`:
  `allowed_mask(bits: bytes, candidate_count: int, cells: Iterable[int], cell_degrees: int) -> list[bool]`
- Produces, in `naming.py`:
  - `unit(vector: Sequence[float]) -> list[float] | None`: None when empty,
    zero or not finite.
  - `logits(unit_vector: Sequence[float], text_rows: Sequence[Sequence[float]], scale: float) -> list[float]`
  - `allowed_for(cell: int | None, bits: bytes, candidate_count: int, *, cell_degrees: int, rings: int, min_allowed: int, overrides: Mapping[int, bool] = {}) -> list[bool] | None`:
    overrides are applied to the mask before the count, so a test photo's
    label species can be set from the pre-cutoff check.
  - `@dataclass(frozen=True) class Naming: open_score: float; ranked: tuple[tuple[int, float], ...]; location_limited: bool`
    (`ranked` is `(candidate index, limited score)`, best first, at most `top_k`).
  - `name(logit_row: Sequence[float], allowed: Sequence[bool] | None, top_k: int) -> Naming | None`
  - `suggestable(naming: Naming, shorter_side: int, *, min_crop_side: int, min_open_score: float, suggest_score: float, suggest_score_no_location: float) -> bool`
  - `vectors() -> dict` and `main(argv)` with `--write-vectors PATH`.

- [ ] **Step 1: Write failing Python tests.** In `region_grid_test.py`:
  `test_allowed_mask_reads_packed_bits` (round trip with `pack_bits` for three
  candidates and two cells). In `naming_test.py`:
  - `test_open_score_ignores_the_region_limit`: logits `[2, 1, 0]`, allowed
    `[False, True, True]`; `open_score == 1/(1+e^-1+e^-2)`, `ranked[0] == (1, 1/(1+e^-1))`, `location_limited` true.
  - `test_ties_keep_the_lower_index_first`: logits `[1, 1, 0]` ranks index 0
    before 1.
  - `test_top_k_cuts_the_ranking`.
  - `test_fallback_below_min_allowed`: `allowed_for` returns None when fewer
    than `min_allowed` are allowed, and when the cell is None or out of range.
  - `test_override_counts_before_the_floor`: an override that switches the
    only allowed species off drops below the floor and returns None.
  - `test_unusable_embeddings`: `unit([])`, `unit([0, 0])`, `unit([nan, 1])` are None.
  - `test_suggestable_uses_the_no_location_bar_when_not_limited`.
  - `test_written_vectors_match_vectors()`: the committed JSON equals `vectors()`.
- [ ] **Step 2: Run** `python3 tool/species_pack/naming_test.py` and
  `python3 tool/species_pack/region_grid_test.py`. Expected: import errors and
  failures.
- [ ] **Step 3: Implement** `allowed_mask` and `naming.py`. The ranking is the
  Dart insertion loop: a candidate moves ahead only of strictly lower logits.
  Softmax subtracts the max logit, as Dart does. `vectors()` uses
  `cellDegrees` 30, embedding size 4, `logitScale` 10.0, six candidates, and
  text and embedding values that are multiples of 1/16, so float32 holds them
  exactly. It includes a tied case, a limited case, a fallback case, and one
  below `minCropSide`, each with the expected open score, ranking, limited
  scores, `locationLimited` and `suggestable`.
- [ ] **Step 4: Write the vectors** with
  `python3 tool/species_pack/naming.py --write-vectors tool/species_pack/testdata/naming_vectors.json`
  and run both Python tests. Expected: OK.
- [ ] **Step 5: Write the Dart test.** `species_namer_vectors_test.dart` builds
  a `SpeciesNamer` from the vectors (as `region_grid_test.dart` reads its
  file) and, per case, expects `openScore` and every candidate score
  `closeTo(expected, 1e-9)`, the same `gbifKey` order, `locationLimited` and
  `suggestable`.
- [ ] **Step 6: Run**
  `flutter test test/features/species_id/domain/species_namer_vectors_test.dart`.
  Expected: all pass. (A failure here is a real mismatch; fix `naming.py`,
  never the Dart namer.)
- [ ] **Step 7: Add the CI lines and commit**
  `feat(species-id): mirror the species namer in the pack tools`.

### Task 2: Bar search and statistics

**Files:** Create `tool/species_pack/bars.py`, `tool/species_pack/bars_test.py`;
modify `ci.yaml`.

**Interfaces:**
- Consumes: nothing from Task 1 (it works on scores).
- Produces, in `bars.py`:
  - `NEVER = 1.01`, `OPEN_GRID` (0.00 to 0.50), `BAR_GRID` (0.20 to 0.99),
    `Z_ONE_SIDED = 1.6448536269514722`, `Z_TWO_SIDED = 1.959963984540054`.
  - `wilson(correct: int, total: int, z: float) -> tuple[float, float]`:
    `(0.0, 1.0)` when `total == 0`.
  - `@dataclass(frozen=True) class Scored: open_score: float; top_score: float; correct: bool; shorter_side: int; limited: bool`
    (one naming of one crop under one condition; junk is never correct).
  - `@dataclass(frozen=True) class Bars: min_open: float; suggest: float; suggest_no_location: float; confident: float; confident_no_location: float`
  - `meets(scored, *, min_open, bar, min_side, target) -> tuple[bool, int]`:
    (lower bound of precision at or above target, number correctly suggested);
    nothing suggested does not meet.
  - `choose_bars(with_location, no_location, junk_with, junk_without, *, min_side, suggest_target=0.85, confident_target=0.95, max_junk_rate=0.02) -> Bars`
  - `named(scored, bars, *, min_side, confident=False) -> list[bool]`: the
    app's rule (limited uses `suggest`, otherwise `suggest_no_location`; the
    confident pair likewise).
  - `held_out_gate(bars, with_location, no_location, *, min_side, suggest_target=0.85, confident_target=0.95) -> tuple[Bars, list[str]]`:
    a bar whose two-sided 95% interval lies wholly below its target becomes
    `NEVER`; the list names the bars switched off.
  - `mcnemar_p(only_a: int, only_b: int) -> float`: exact two-sided binomial.

`choose_bars` follows the spec's order:

```text
1. (min_open, suggest): over with_location crops where limited, the pair
   meeting suggest_target with the most correct; ties to the higher min_open.
   No pair: (0.0, NEVER).
2. suggest_no_location: lowest bar meeting suggest_target over no_location.
3. confident, confident_no_location: lowest bar >= the matching suggest bar
   meeting confident_target, over limited with_location / no_location.
   A NEVER suggest bar gives a NEVER confident bar.
4. Junk: if the share of junk crops named (by `named`, either condition) on
   junk_with + junk_without exceeds max_junk_rate, take the lowest min_open
   on OPEN_GRID above the current one that brings it under, and redo
   steps 2 and 3 with that min_open fixed, and step 1's suggest bar chosen
   again with it fixed. No such min_open: every bar NEVER.
```

- [ ] **Step 1: Write failing tests** in `bars_test.py`:
  `test_wilson_known_values` (10 of 10 at z 1.96 gives lower 0.7225 to 4
  places), `test_wilson_empty_is_unknown`, `test_meets_needs_a_suggestion`,
  `test_choose_picks_the_lowest_passing_bar` (hand-built scores where 0.60
  passes and 0.59 does not), `test_open_score_tie_goes_higher`,
  `test_no_passing_value_is_never`, `test_confident_never_below_suggest`,
  `test_junk_raises_min_open` (junk at open 0.10 to 0.30 forces min_open
  above 0.30), `test_junk_impossible_turns_everything_off`,
  `test_gate_switches_off_a_failing_bar`, `test_gate_keeps_a_bar_whose_interval_reaches_target`,
  `test_mcnemar_symmetric_and_exact` (`mcnemar_p(0, 6) == 2 * 0.5**6`).
- [ ] **Step 2: Run** `python3 tool/species_pack/bars_test.py`. Expected: fail.
- [ ] **Step 3: Implement** `bars.py`.
- [ ] **Step 4: Run** it again. Expected: OK.
- [ ] **Step 5: Add to CI and commit** `feat(species-id): choose naming bars from scored crops`.

### Task 3: Report metrics

**Files:** Create `tool/species_pack/metrics.py`, `tool/species_pack/metrics_test.py`;
modify `ci.yaml`.

**Interfaces:**
- Consumes: `bars.wilson`, `bars.Z_TWO_SIDED`.
- Produces:
  - `size_bucket(shorter_side: int) -> str`: `"under 64"`, `"64-127"`,
    `"128-255"`, `"256+"`.
  - `top_k(ranks: Sequence[int | None], k: int) -> float`: share whose label
    rank (0-based) is below k; empty gives 0.0.
  - `@dataclass(frozen=True) class Rate: n: int; hits: int; value: float; low: float; high: float`
  - `rate(hits: int, n: int) -> Rate` (two-sided Wilson; n 0 gives value 0.0).
  - `coverage_precision(named: Sequence[bool], correct: Sequence[bool]) -> tuple[Rate, Rate]`:
    coverage over all crops, precision over named ones.
  - `breakdown(items: Sequence[T], key: Callable[[T], str], measure: Callable[[Sequence[T]], dict]) -> dict[str, dict]`,
    keys sorted.

- [ ] **Step 1: Write failing tests**: bucket edges at 63, 64, 127, 128, 255,
  256; `top_k` with None ranks; `coverage_precision` with nothing named gives
  precision n 0; `breakdown` groups and sorts.
- [ ] **Step 2: Run, see failures. Step 3: Implement. Step 4: Run, OK.**
- [ ] **Step 5: Add to CI and commit** `feat(species-id): accuracy report metrics`.

### Task 4: Test set rules

**Files:** Create `tool/species_pack/testset.py`, `tool/species_pack/testset_test.py`;
modify `ci.yaml`.

**Interfaces:**
- Consumes: `region_grid.neighbourhood`, `region_grid.rows`, `region_grid.columns`.
- Produces:
  - `CUTOFF = "2024-07-01"`, `LICENCES = ("cc0", "cc-by", "cc-by-sa")`,
    `TAXA = (47178, 47273)`, `PER_REGION = 450`,
    `REGIONS: dict[str, tuple[float, float, float, float]]` (south, west,
    north, east) for `caribbean`, `red-sea`, `coral-triangle`, `hawaii`,
    `great-barrier-reef`, `mediterranean`, `california`.
  - `FIELDS`: the CSV columns, in order: `source, id, box, photo_url, licence,
    attribution, page_url, region, lat, lon, created, observer, label_name,
    gbif_key, label_source, habitat, recorded_before_cutoff, underwater`.
    `box` is blank for fish (the largest box) and the detection index for junk.
  - `species_name(name: str, rank: str) -> str | None`: species, subspecies,
    variety and form give the first two words; anything else None.
  - `accepted_key(match: dict) -> int | None`: from a GBIF `species/match`
    reply; None unless matched at species rank or below; a synonym gives
    `acceptedUsageKey`; below species gives `speciesKey`.
  - `sample(pool: Sequence[dict], n: int, seed: str) -> list[dict]`: order by
    `sha256(seed + id)`, keep the first observation per (observer, observed
    day), take n.
  - `tune_ids(rows: Sequence[dict]) -> set[str]`: within each region, sort by
    `sha256(id)` and take the first half (rounded up) as tune.
  - `commons_licence(short_name: str) -> str | None`: `cc0`, `pd`, `cc-by`,
    `cc-by-sa` (any version), else None.
  - `query_boxes(cell: int, rings: int, cell_degrees: int) -> list[tuple[float, float, float, float]]`:
    the neighbourhood as one or two (south, west, north, east) boxes; two when
    it wraps longitude.
  - `underwater(scores: Mapping[str, float]) -> bool`: summed probability of
    `UNDERWATER_PROMPTS` at least that of `DRY_PROMPTS`.
  - `write_rows(path: str, rows: Sequence[dict]) -> None`, `read_rows(path: str) -> list[dict]`.

- [ ] **Step 1: Write failing tests**: subspecies to binomial and genus to
  None; a synonym match takes `acceptedUsageKey`; a `NONE` match is None;
  `sample` is repeatable and keeps one per observer-day; `tune_ids` is
  repeatable and splits each region within one; `commons_licence` for
  "CC BY-SA 4.0", "CC0", "Public domain", "CC BY-NC 2.0" (None);
  `query_boxes` for an interior cell (one box) and a cell at longitude 177.5
  (two boxes, one of them starting at -180); CSV round trip keeps every field.
- [ ] **Step 2: Run, see failures. Step 3: Implement. Step 4: Run, OK.**
- [ ] **Step 5: Add to CI and commit** `feat(species-id): rules for the accuracy test set`.

### Task 5: Measured bars in the manifest, and the new confident bar

**Files:** Modify `tool/species_pack/manifest.py`, `manifest_test.py`,
`build_pack.py`, `lib/features/species_id/domain/entities/species_pack_manifest.dart`,
`test/features/species_id/domain/species_pack_manifest_test.dart`.

**Interfaces:**
- Produces, in `manifest.py`:
  - `NAMING_PROVISIONAL` gains `"confidentScoreNoLocation": 0.70`.
  - `NAMING_MEASURED: dict | None`, `None` until Task 9 fills it, with keys
    `naming` (the manifest block, `provisional: false`), `classifierId`,
    `candidates`, `findings`.
  - `naming_for(classifier_id: str, candidate_count: int, measured: dict | None = NAMING_MEASURED) -> dict`.
  - `build_manifest(..., candidate_count: int)`: `naming` defaults to
    `naming_for(classifier_id, candidate_count)`.
- Produces, in Dart: `NamingConfig.confidentScoreNoLocation` (a required
  field built from an optional constructor argument that defaults to
  `confidentScore`), in `copyWith` and `props`; the parser reads it when
  present and otherwise uses `confidentScore`; a present value that is not a
  number is malformed.

- [ ] **Step 1: Write failing tests.** Python: `naming_for` returns the
  measured block for the same classifier and 7,646 within 10%, and the
  provisional one for 1,495, for another classifier, and when `measured` is
  None. Dart: a manifest without the key reads `confidentScoreNoLocation ==
  confidentScore`; one with 1.01 reads 1.01; one with `"x"` is malformed.
- [ ] **Step 2: Run** `python3 tool/species_pack/manifest_test.py` and
  `flutter test test/features/species_id/domain/species_pack_manifest_test.dart`.
  Expected: fail.
- [ ] **Step 3: Implement**, and pass `len(rows)` from `build_pack.py`.
- [ ] **Step 4: Run both. Expected: pass.** Then `dart format` the Dart file
  and `flutter analyze` it.
- [ ] **Step 5: Commit** `feat(species-id): measured naming bars and a confident bar without location`.

### Task 6: The Swift pipeline as a command-line tool, with crop fitting

**Files:** Modify `VisionPipeline.swift`, `SubmersionVisionPlugin.swift`;
create `tool/species_pack/vision_cli/main.swift`, `FlutterShim.swift`,
`build.sh`.

**Interfaces:**
- `VisionModelSettings` gains `cropFit: CropFit` (`enum CropFit: String { case padSquare, centreCrop }`),
  read from an optional `"cropFit"` key; absent means `padSquare`; any other
  value throws `badArguments("cropFit")`.
- `static func fitRect(width: Int, height: Int, size: Int, fit: CropFit) -> CGRect`
  on `VisionPipeline`: `min` scale for `padSquare`, `max` for `centreCrop`,
  centred either way. `embed` uses it.
- `build.sh OUT`: `swiftc -O` over `main.swift`, `FlutterShim.swift` and the
  package's `VisionPipeline.swift` (by relative path), writing the binary to
  `OUT`.
- CLI: `species_vision --manifest M --detector D --classifier C --crop-fit F`
  reads image paths one per line on stdin and writes one JSON line per image:
  `{"path", "width", "height", "detections": [{"x","y","w","h","score","pixelWidth","pixelHeight","embedding": [768 floats]}]}`,
  or `{"path", "error"}` for an unreadable image. Crop thumbnails are not
  written.

- [ ] **Step 1:** Change the imports to `#if canImport(Flutter)` /
  `#elseif canImport(FlutterMacOS)`, move `VisionError` (with `code` and
  `message`) into `VisionPipeline.swift`, add `CropFit` and `fitRect`.
- [ ] **Step 2:** Write the three tool files.
- [ ] **Step 3: Build and run the tool** on three photos from
  `build/species_accuracy_work` (or the spike's photos) against the
  development pack, with both fittings. Expected: JSON lines with the same
  boxes for both fittings and different embeddings.
- [ ] **Step 4: Check the app still builds:** `flutter build macos --debug`
  in the background. Expected: success.
- [ ] **Step 5: Commit** `feat(species-id): run the vision pipeline from the command line`.

### Task 7: Pure parts for the detector comparison

**Files:** Modify `tool/species_pack/testset.py`, `testset_test.py`,
`manifest.py`, `manifest_test.py`; create `tool/species_pack/boxes.py`,
`boxes_test.py`; modify `ci.yaml`.

**Interfaces:**
- `testset.GROUPS: dict[str, int]` (group name to iNaturalist taxon id, in
  the Global Constraints' order); `testset.TOP_UP = 150`.
- `testset.group_of(taxon_id: int, ancestor_ids: Sequence[int]) -> str | None`:
  the first group whose id is the taxon or one of its ancestors.
- `testset.top_ups(pool: Sequence[dict], natural: Sequence[dict], seed: str) -> list[dict]`:
  per group other than fish, observations from `pool` not in `natural`,
  ordered as `sample` orders them, enough to bring the group to `TOP_UP`.
- `testset.FIELDS` gains `group`, `sample` (`natural` or `top-up`) and
  `detector` (blank for animals; the detector id whose box a junk row labels).
- `UNDERWATER_PROMPTS` and `DRY_PROMPTS` speak of animals, and the dry ones
  add a beach, land, and an empty shell.
- `boxes.iou(a: Sequence[float], b: Sequence[float]) -> float` on
  `(x, y, w, h)` normalised boxes.
- `boxes.merge(runs: Sequence[Sequence[dict]], *, iou_threshold: float = 0.5, max_boxes: int = 8) -> list[dict]`:
  each dict has `x, y, w, h, score` (and whatever else rides along); pooled,
  best score first, a box dropped when it overlaps a kept one at or above the
  threshold.
- `manifest.naming_for(detector_id, classifier_id, candidate_count, measured)`:
  the detector id is checked too. `build_manifest` passes `detector_id`.

- [ ] **Step 1: Write failing tests**: `group_of` for a nudibranch (its
  ancestors include 47114) and for a land mammal (None); `top_ups` brings a
  short group to 150 without repeating natural ones and leaves fish and full
  groups alone; the new fields round trip; `iou` for identical, disjoint and
  half-overlapping boxes; `merge` keeps the higher of two overlapping boxes
  from different runs, keeps both when they do not overlap, and stops at
  `max_boxes`; `naming_for` returns provisional bars for another detector.
- [ ] **Step 2: Run** `python3 tool/species_pack/testset_test.py`,
  `boxes_test.py` and `manifest_test.py`. Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run all three. Expected: OK.**
- [ ] **Step 5: Add `boxes` to CI and commit** `feat(species-id): pure parts for comparing detectors`.

### Task 8: Megalodon through the app's pipeline

**Files:** Create `tool/species_pack/megalodon.py`; modify
`VisionPipeline.swift`, `vision_cli/main.swift`.

**Interfaces:**
- `megalodon.CHECKPOINTS: dict[str, dict]`: `megalodon-2024` and
  `megalodon-2023`, each with Hugging Face repo, revision, file name and
  SHA-256 (pinned at fetch time).
- `megalodon.convert(name: str, work: str) -> str`: fetches, checks the
  hash, traces the PyTorch model with a `[1, 3, 640, 640]` tensor input,
  converts at 16-bit precision for iOS 15, saves `<name>.mlpackage`, and
  checks it against the PyTorch output on the test scene.
- `megalodon.check(name: str, tool: str, photos: Sequence[str]) -> float`:
  the share of `ultralytics` boxes (score 0.25 and over) that the tool's
  boxes overlap at IoU 0.9 or more.
- Swift: `enum DetectorFormat: String { case rfdetr, yolo }`; optional
  `"detectorFormat"` in `VisionModelSettings` (absent means `rfdetr`, any
  other value throws `badArguments`); the YOLO path letterboxes, suppresses
  at IoU 0.7 and maps boxes back. The tool takes `--detector-format`,
  `--detector-input`, `--detector-mean`, `--detector-std`,
  `--score-threshold` overrides, and reports `detectMs` per image and
  `embedMs` per detection.

- [ ] **Step 1:** Make a venv in the scratchpad that reads the spike venv's
  packages through a `.pth` file and add `ultralytics` to it, leaving the
  spike venv untouched.
- [ ] **Step 2:** Write `megalodon.py`; convert both checkpoints. Expected:
  each converted model's scores and boxes match the PyTorch output on the
  test scene (best box IoU 0.9 or more).
- [ ] **Step 3:** Add the Swift YOLO path and the tool options; rebuild the
  tool.
- [ ] **Step 4:** `megalodon.check` on 20 test photos for each checkpoint.
  Expected: 0.9 or more.
- [ ] **Step 5:** `flutter build macos --debug`. Expected: success.
- [ ] **Step 6: Commit** `feat(species-id): run Megalodon through the vision pipeline for measuring`.

### Task 9: Fetch the test set

**Files:** Create `tool/species_pack/fetch_testset.py`. Produces
`tool/species_pack/testdata/accuracy_set.csv`. Eric approved the downloads
(about 4,000 iNaturalist photos, 150 Commons photos, the API queries).

**Interfaces:** consumes everything in `testset.py`; `models._classifier()` for
the underwater filter; `region_grid.cell_of`.

Steps, each cached in `--work` so a rerun resumes:

- [ ] **Step 1: Pool.** For each region, page through
  `api.inaturalist.org/v2/observations` with the Global Constraints' filters
  and `created_d1=2024-07-01`, over all seven groups, ordered by id, `fields`
  limited to what the CSV needs plus `taxon.id` and `taxon.ancestor_ids`. At
  most one request a second.
- [ ] **Step 2: Sample** `PER_REGION` per region with `testset.sample`, seed
  `"accuracy-2026-11"`, after dropping taxa `species_name` rejects; then
  `testset.top_ups` across all regions.
- [ ] **Step 3: Labels and habitat.** GBIF `species/match` per distinct name
  (`accepted_key`); GBIF species profiles for habitat (`marine`, `brackish`
  or `freshwater` only, blank when unknown). Drop and count unmatched.
- [ ] **Step 4: Pre-cutoff records.** For each observation, GBIF
  `occurrence/search` counts over `query_boxes(cell_of(lat, lon, 5), 1, 5)`
  with `eventDate` before 2024-07-01 and `limit=0`; any hit sets
  `recorded_before_cutoff`.
- [ ] **Step 5: Photos.** Download each `large` photo into `--work/photos/`.
- [ ] **Step 6: Underwater filter.** Score each photo with BioCLIP 2 against
  `UNDERWATER_PROMPTS + DRY_PROMPTS`; record `underwater`. Write contact
  sheets of kept and dropped photos to `--work/sheets/`; look at a sample of
  100 of each, and record the error counts for the findings.
- [ ] **Step 7: Junk.** Fetch about 150 Commons files from the underwater
  diver categories with `commons_licence`; run the Swift tool (pad-square)
  with each detector; write contact sheets of every box; label each box by
  eye in `--work/junk_labels.json` as person, scenery, animal or unclear;
  add one CSV row per person or scenery box, naming its detector, with
  `label_source` `by eye (builder)`.
- [ ] **Step 8: Write the CSV**, run `testset_test.py`, and commit
  `feat(species-id): the accuracy test set` (the CSV and the script).

### Task 10: Score

**Files:** Create `tool/species_pack/score.py`.

**Interfaces:** consumes `naming`, `bars`, `metrics`, `testset`; writes
`--work/report_<fit>.md`, `--work/results.json`.

- [ ] **Step 1:** Unzip the pack's models into `--work/models/<packVersion>/`
  (the pipeline deletes a package once compiled, so never point it at the
  pack itself), build the Swift tool, and run it per detector and fitting
  over every photo, caching JSONL per detector, fitting and pack version,
  under `/usr/bin/time -l` for peak memory.
- [ ] **Step 2:** Name each fish row's largest box with location (overriding
  the label species' bit with `recorded_before_cutoff` when it is in the
  pack) and without; name each junk box with no location and with the cell
  of the fish row picked by `sha256(junk id) % len(fish rows)`. Logits come
  from numpy; check the first 20 against `naming.logits` to 1e-6.
- [ ] **Step 3:** For each detector (and the merged pair, from
  `boxes.merge` over the two runs), choose bars per fitting on the natural
  tune half; gate on the natural held-out half; compare fittings, and then
  detectors, with `mcnemar_p` on correct suggestions at each one's own
  bars. Apply the spec's recommendation rule.
- [ ] **Step 4:** Write the report: every item in the spec's "The report"
  and "What is measured per detector", plus the precision and coverage
  curve.
- [ ] **Step 5:** Run against the development pack first (expect weak
  numbers; this checks the plumbing), then against the full pack (7,646
  candidates).
- [ ] **Step 6: Commit** `feat(species-id): score a pack against the accuracy test set`.

### Task 11: Apply the result

**Files:** Modify `manifest.py`; create
`docs/design/findings/2026-11-17-marine-life-measured-accuracy.md`; modify
`docs/developer/species-identification.md`; and, only if centre crop wins,
the Dart manifest's `cropFit`, `VisionModels`, the channel arguments and
their tests.

- [ ] **Step 1:** Fill `NAMING_MEASURED` from the Community Fish Detector's
  chosen and gated bars on the full pack; set `CLASSIFIER_SETTINGS["cropFit"]`. Update the
  `manifest_test.py` expectations; run it.
- [ ] **Step 2:** Write the findings: method, test set make-up (by region,
  group, in-pack share, habitat, filter error counts, detector misses), every
  report table, the bars per detector, what was switched off, the fitting
  decision with its p-value, the detector comparison and recommendation, the
  licence notes, and the limits the spec lists.
- [ ] **Step 3:** Add "Measuring accuracy" to the developer page.
- [ ] **Step 4:** If centre crop won, wire `cropFit` through Dart with TDD.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, the changed test files
  by path, and commit `feat(species-id): set the naming bars from measured accuracy`.
