# Marine Life Naming Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> (inline, in this session) to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Train one row per candidate on iNaturalist photos, ship the rows in
a derived pack's `text_embeddings.f16`, and prove with `score.py` and a new
gate that it names more right and earns a confident bar.

**Architecture:** A stdlib module chooses the training photos
(`training_set.py`); a fetcher stages, downloads and embeds them through the
app's own vision pipeline (`fetch_training.py`); a trainer fits the rows and
derives a pack from pack 2026.11.18.0356 (`train_naming.py`); the scorer
writes per-photo results so a gate (`gate.py`) can compare packs and run the
rare-species check.

**Tech Stack:** Python 3.14, standard library for selection, manifest and
gate logic; numpy and torch (already in `tool/species_pack/requirements.txt`)
for training; `tool/species_pack/vision_cli` for embeddings.

**Spec:** `docs/design/specs/2026-11-18-marine-life-naming-layer-design.md`
(issue #4724). The app confident-rule fix is #4725, a separate PR.

## Global Constraints

- Training licences exactly `cc0`, `cc-by`, `cc-by-nc` (no share-alike, no ND,
  no all rights reserved).
- Research grade, `captive=false`; one photo per observation (its first).
- Leak guard: drop every test observation, and every observation created on or
  after `testset.CUTOFF` ("2024-07-01") by an observer in `accuracy_set.csv`.
- Validation: about 10% of observers with post-cutoff records, by hash with a
  fixed seed; their post-cutoff records validate; none of their records train.
- Cap: 50 per species, 5 per observer per species, post-cutoff first.
- iNaturalist API at most one request a second and under 10,000 a day; photo
  downloads under 20 GB a day; the `large` size.
- Downloads live in their own folder; Python that reads them runs with `-I`.
- `logitScale` stays 100; rows carry sharpness. Rows are little-endian f16,
  finite, within f16 range, shape (9,151, 768).
- The trained file is CC BY-NC 4.0; credit list one row per training photo.
- Gate on the pair at `centreCrop`; McNemar p < 0.05; junk at most 2%;
  rare-species wrong confident names at most 2% of the held-back photos.
- Nothing is published. No em-dashes anywhere. No mention of AI tools.
- Run only the test files written or changed, by path.

## Review Focus

1. A taxon name that GBIF matches to another species (a synonym, a
   subspecies) must count for the candidate whose `gbifKey` it resolves to,
   and never for the queried candidate when it resolves elsewhere.
2. A training photo with no box, or a largest box under 64 px, must be skipped
   and not counted toward the species' cap.
3. A fetch stopped part way must resume without downloading or embedding a
   photo twice, and without a half-written file being read as complete.
4. Rows that hold a NaN or overflow f16 must be refused, never written.
5. The check layer must have no training photo of a held-back species,
   including those recorded at subspecies rank.

---

### Task 1: Choosing the training photos (`training_set.py`)

**Files:**
- Create: `tool/species_pack/training_set.py`
- Test: `tool/species_pack/training_set_test.py`

**Interfaces:**
- Consumes: `testset.CUTOFF`, `testset.species_name`, `testset._hash` style
  (sha256 hex of a string).
- Produces:
  - `LICENCES = ("cc0", "cc-by", "cc-by-nc")`, `PER_SPECIES = 50`,
    `PER_OBSERVER = 5`, `VALIDATION_FRACTION = 0.10`,
    `SEED = "naming-layer-2026-11"`, `HELD_BACK = 100`.
  - `observation_record(o: dict, candidate: int, gbif_key: int) -> dict | None`:
    an iNaturalist v2 observation (fields as `fetch_testset.FIELDS`) as
    `{"id", "uri", "created", "observer", "candidate", "gbif_key", "lat",
    "lon", "photo_url", "licence", "attribution"}`; None when the first photo's
    licence is not in `LICENCES` or there is no photo. `lat`/`lon` None when
    hidden. `photo_url` is the `large` size.
  - `guard(records, test_ids: set[str], test_observers: set[str]) -> list`
  - `validation_observers(records) -> set[str]`
  - `split(records, val_observers) -> tuple[list, list]` (train, validation)
  - `cap(records) -> list`
  - `held_back_species(test_rows: list[dict]) -> list[int]` (gbif keys)
  - `without_species(records, keys: set[int]) -> list`
  - `write_credits(path, records)`: CSV with columns `id, uri, licence,
    attribution`, sorted by id.

- [ ] **Step 1: Write the failing tests** (`unittest`, loading the module as
  `testset_test.py` does):
  - `test_record_keeps_open_and_nc_licences`: cc0, cc-by, cc-by-nc kept;
    cc-by-sa, cc-by-nc-sa, cc-by-nd, None return None.
  - `test_record_uses_large_photo_and_hidden_place`: `square` URL becomes
    `large`; `obscured` gives `lat is None`.
  - `test_guard_drops_test_ids_and_post_cutoff_test_observers`: a test id
    dropped; a test observer's record created "2024-06-30T23:00:00Z" kept,
    "2024-07-01T00:00:00Z" dropped; another observer's post-cutoff kept.
  - `test_validation_observers_are_post_cutoff_only_and_stable`: an observer
    with only pre-cutoff records is never chosen; same input gives same set;
    1,000 observers give between 70 and 130.
  - `test_split_keeps_validation_observers_out_of_training`: a validation
    observer's pre-cutoff record is in neither list; their post-cutoff record
    is in validation only.
  - `test_cap_prefers_post_cutoff_then_newest`: 60 records of one species
    give 50; every post-cutoff record kept before any pre-cutoff one.
  - `test_cap_limits_each_observer_per_species`: 8 records by one observer of
    one species give 5; the same observer's records of another species are
    capped separately.
  - `test_held_back_species_is_seeded_and_from_underwater_inat_rows`: 100 keys,
    the same on a second call, none from `commons` rows or `underwater != yes`.
  - `test_without_species_drops_every_record_of_a_key`.
  - `test_write_credits_sorted_one_row_per_record`.

- [ ] **Step 2: Run to verify they fail**

Run: `python3.14 tool/species_pack/training_set_test.py`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement the module** with the signatures above. Dates
  compare on the first ten characters of `created` against `CUTOFF`.
  `validation_observers` keeps an observer when
  `int(sha256(SEED + observer), 16) % 1000 < 100`. `cap` sorts by
  (post-cutoff first, `created` descending, id) then keeps per observer then
  per species. `held_back_species` orders distinct gbif keys by
  sha256(SEED + key) and takes `HELD_BACK`.

- [ ] **Step 4: Run to verify they pass**

Run: `python3.14 tool/species_pack/training_set_test.py`
Expected: OK.

- [ ] **Step 5: Commit** `feat(species-id): choose the naming layer's training photos`

### Task 2: Scorer pieces the training and gate reuse (`score.py`)

**Files:**
- Modify: `tool/species_pack/score.py` (`Runner.run`, `main`)

**Interfaces:**
- Produces:
  - `Runner.analyze(name: str, fit: str, photos: list[str], out: str) -> None`:
    runs the vision tool over `photos` into the JSONL file `out` (written to
    `out + ".partial"` then renamed), no caching. `Runner.run` calls it.
  - `main` also writes `per_photo.json` to `--work`:
    `{"<set> <fit>": {"named_right": {id: bool}, "confident_right": {id:
    bool}, "confident_wrong": {id: bool}, "group": {id: str}}}` for held-out
    natural photos, at the gated bars, and the same three maps for every
    natural and top-up photo under `"all"` (the rare-species check needs both
    halves).
  - `--per-photo-only` is not added; the file is always written.

- [ ] **Step 1: Refactor `Runner.run` to call `Runner.analyze`**, no
  behaviour change.
- [ ] **Step 2: Add the `per_photo.json` output** from the existing
  `_correct_at_bars` and `bar_search.named(..., confident=True)` results.
- [ ] **Step 3: Verify** on pack 2026.11.18.0356 with its cached runs:

Run: `.venv-species-pack/bin/python -I tool/species_pack/score.py --pack <0356> --work <work>`
Expected: `results.json` "named right per detector" unchanged from the
findings (pair 304 of 1,076); `per_photo.json` present; for the pair, the sum
of `named_right` equals 304.

- [ ] **Step 4: Commit** `feat(species-id): write per-photo results from the accuracy scorer`

### Task 3: Fetching and embedding (`fetch_training.py`)

**Files:**
- Create: `tool/species_pack/fetch_training.py`
- Test: `tool/species_pack/fetch_training_test.py` (pure helpers only)

**Interfaces:**
- Consumes: Task 1; `fetch_testset._get`, `_download`, `_load`, `_save`,
  `_gbif_key`, `INAT`, `FIELDS`; `score.Runner.analyze`; `score._largest`.
- Produces (in `--work`, default `build/naming_training`):
  - `lists/<gbifKey>.json`: records for one candidate (stage `lists`).
  - `selected.json`: `{"train": [...], "validation": [...]}` (stage `select`).
  - `embeddings/<batch>.npy` (float32, n x 768) and
    `embeddings/<batch>.jsonl` (one record per row, plus `side`) (stage
    `embed`); photos under `photos/<batch>/`, deleted after the batch.
  - `labelled_crop(result: dict, min_side: int) -> dict | None`: the largest
    detection when its shorter side is at least `min_side`, else None.
  - `batch_of(records, size=2000) -> list[list]`: stable batches by id.
  - CLI: `fetch_training.py --pack PACK --set accuracy_set.csv --work W
    {lists,select,embed,all} [--limit N]`.

- [ ] **Step 1: Write the failing tests:**
  `test_labelled_crop_skips_small_and_empty` (no detections gives None; a
  63 px shorter side gives None; the largest of two is chosen at 64 px),
  `test_batches_are_stable_and_complete`.
- [ ] **Step 2: Run to verify they fail**
  (`python3.14 tool/species_pack/fetch_training_test.py`).
- [ ] **Step 3: Implement the stages.**
  - `lists`: per candidate, one request to `INAT` with `taxon_name`, 
    `quality_grade=research`, `captive=false`, `photo_license=cc0,cc-by,cc-by-nc`,
    `per_page=200`, `order_by=created_at`, `order=desc`, `fields=FIELDS`,
    then `time.sleep(1.0)`. Each observation's taxon goes through
    `testset.species_name` and `_gbif_key` (cached by name in
    `gbif_names.json`); only observations resolving to the candidate's key are
    kept. A candidate whose file exists is skipped (resume). Stops for the
    day after 9,000 requests and says so.
  - `select`: reads every list, runs `guard`, `validation_observers`,
    `split`, `cap` on each side, writes `selected.json` and prints counts.
  - `embed`: per batch with no `.npy` yet, downloads its photos (8 threads),
    keeps a running byte total in `downloads.json` by UTC day and stops for
    the day at 20 GB, runs `Runner.analyze("both", "centreCrop", ...)`, keeps
    `labelled_crop`, writes `.npy` then `.jsonl` (the `.jsonl` last marks the
    batch complete), deletes the batch's photos.
- [ ] **Step 4: Run tests to verify they pass.**
- [ ] **Step 5: Dry run** `--limit 3` on three candidates; check a list, a
  selection and one embedded batch by eye.
- [ ] **Step 6: Commit** `feat(species-id): fetch and embed the naming layer's training photos`

### Task 4: Credits and derived manifests (`manifest.py`)

**Files:**
- Modify: `tool/species_pack/manifest.py`
- Test: `tool/species_pack/manifest_test.py`

**Interfaces:**
- Produces:
  - `training_credit(photos: int, list_url: str) -> dict` with `name`
    "iNaturalist photos", `licence` "CC BY-NC 4.0", and text naming the
    count, the three photo licences, "not for commercial use", and the URL.
  - `derive_manifest(base: dict, files: list, *, pack_version: str, credits:
    list) -> dict`: a copy of `base` with `packVersion`, `files` and `credits`
    replaced and `naming` from `naming_for(base detector ids, classifier id,
    cropFit, contents_of(files))`.

- [ ] **Step 1: Failing tests:** `test_training_credit_names_licence_and_list`;
  `test_derived_manifest_is_provisional_for_new_rows` (a changed
  `text_embeddings.f16` hash gives `NAMING_PROVISIONAL`);
  `test_derived_manifest_matches_a_measured_entry` (a `measured` list with the
  new contents gives that entry's naming); `test_derived_manifest_keeps_detectors_and_region`.
- [ ] **Step 2: Run to verify they fail**
  (`python3.14 tool/species_pack/manifest_test.py`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit** `feat(species-id): credit and derive a pack with trained rows`

### Task 5: Training the rows (`train_naming.py`)

**Files:**
- Create: `tool/species_pack/train_naming.py`
- Test: `tool/species_pack/train_naming_test.py` (skips the torch tests when
  torch is missing)

**Interfaces:**
- Consumes: Task 1 (`without_species`, `write_credits`), Task 3 outputs,
  Task 4.
- Produces:
  - `load(folder, *, exclude: set[int] = frozenset()) -> tuple[ndarray,
    ndarray, list]`: unit-length embeddings, candidate indices, records.
  - `train(name_rows, x, y, *, anchor: float, epochs: int, lr: float, seed:
    int) -> ndarray`: rows start at `name_rows`; loss is cross-entropy of
    `unit(x) @ rows.T * 100` over every candidate plus
    `anchor * sum((rows - name_rows) ** 2)`; rows of candidates absent from
    `y` stay exactly `name_rows`.
  - `finish(trained, name_rows, *, blend: float, sharpness: float) ->
    ndarray`: `sharpness * (blend * trained + (1 - blend) * name_rows)`.
  - `validation_loss(rows, x, y) -> float` (mean cross-entropy at scale 100).
  - `f16_bytes(rows) -> bytes`: refuses (ValueError) a non-finite value or one
    above 65,504 in magnitude.
  - CLI: `train_naming.py --base PACK --training W --out PACK2 [--exclude-held-back
    accuracy_set.csv] [--version V] [--list-url URL]`. Searches `anchor` in
    {1e-4, 1e-3, 1e-2}, `blend` in {0.25, 0.5, 0.75, 1.0}, `sharpness` in
    {0.75, 1.0, 1.5, 2.0}, epochs by early stopping on validation loss; writes
    the chosen settings and seed to `PACK2/training.json` (not in the
    manifest's files), `training_photos.csv` beside it, the rows, and the
    derived manifest.

- [ ] **Step 1: Failing tests:** `test_f16_refuses_nan_and_overflow`;
  `test_untrained_rows_are_unchanged`; `test_training_separates_two_toy_species`
  (two clusters whose name rows point the wrong way end with each cluster's
  top candidate right); `test_finish_blends_and_scales`;
  `test_load_excludes_held_back_species`.
- [ ] **Step 2: Run to verify they fail**
  (`.venv-species-pack/bin/python -I tool/species_pack/train_naming_test.py`).
- [ ] **Step 3: Implement** with torch (MPS when available, else CPU), Adam,
  full candidate softmax, minibatches of 4,096.
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit** `feat(species-id): train the naming rows and derive a pack`

### Task 6: The gate (`gate.py`)

**Files:**
- Create: `tool/species_pack/gate.py`
- Test: `tool/species_pack/gate_test.py` (stdlib)

**Interfaces:**
- Consumes: two `per_photo.json` files (Task 2); `bars.mcnemar_p`,
  `bars.wilson`; the trained pack's `results.json`.
- Produces:
  - `verdict(baseline: dict, trained: dict, trained_results: dict,
    rare: dict, *, set_key: str) -> dict` with one entry per gate item
    (`more_named_right`, `confident_bar`, `no_group_worse`, `junk`,
    `rare_species`), each `{"pass": bool, ...numbers}`, and `"ship": bool`.
  - `rare_check(check_per_photo: dict, held_back_ids: set[str]) -> dict`:
    count, wrong confident, right confident, rate, Wilson interval; pass at
    rate <= 0.02.
  - CLI: `gate.py --baseline W0 --trained W1 --check W2 --set accuracy_set.csv`
    prints and writes `gate.json`.
  - The check layer is scored by running `score.py` on the check pack with its
    manifest's `naming` replaced by the shipped pack's measured bars
    (`score.py --naming-from PACK`, added here: it skips bar choice and uses
    the given bars).

- [ ] **Step 1: Failing tests:** `test_more_named_right_needs_significance`;
  `test_confident_bar_never_fails`; `test_one_group_significantly_worse_fails`;
  `test_junk_over_two_percent_fails`; `test_rare_check_at_two_percent`
  (4 of 240 passes, 5 of 240 fails); `test_ship_only_when_all_pass`.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement `gate.py` and `score.py --naming-from`.**
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit** `feat(species-id): gate a trained pack against the baseline`

### Task 7: Run it, record it

Carried out step by step in the runbook,
`docs/design/plans/2026-11-18-marine-life-naming-layer-runbook.md`, which also adds
the fetcher's `--wait` mode and the checkpoints before anything is pushed.

**Files:**
- Create: `docs/design/findings/2026-11-<dd>-marine-life-naming-layer.md`
- Modify: `tool/species_pack/manifest.py` (`NAMING_MEASURED`, only if the gate
  passes), `docs/developer/species-identification.md` ("Training the naming
  layer"), `docs/design/specs/2026-11-17-marine-life-identification-program-design.md`
  (a pointer under "Training later").

- [ ] **Step 1:** `fetch_training.py ... all` in the background; resume daily
  until every batch is embedded.
- [ ] **Step 2:** train the shipped layer and the check layer (with
  `--exclude-held-back`).
- [ ] **Step 3:** score the baseline, the trained pack, and the check pack
  (`--naming-from` the trained pack); run `gate.py`.
- [ ] **Step 4:** write the findings (data counts, settings, seed, every gate
  number, the rare-species check). If the gate passes, add the pair's
  `measured` entry with its own `contents`, and confirm
  `build_manifest`/`derive_manifest` on the trained files gives
  `"provisional": false`.
- [ ] **Step 5:** developer guide section: how to fetch, train, score, gate;
  the file's CC BY-NC 4.0 licence; `build_pack.py` builds the untrained
  alternative; publishing uploads `training_photos.csv` as an unlisted release
  file (by Eric only).
- [ ] **Step 6: Commit** `docs(species-id): record the naming layer's training and gate`
