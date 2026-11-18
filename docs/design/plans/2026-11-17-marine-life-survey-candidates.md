# Marine life survey candidates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Species that divers survey often but rarely photograph join the species pack's candidate list, and the naming bars are measured again on the rebuilt pack.

**Architecture:** `candidates.py` gains a second GBIF species facet (present, 0 to 40 m human observations) beside the photo facet, and a pure function that merges the two rankings under the cap, photographed species first. `build_pack.py` wires it in with a new flag and a higher default cap. The pack is rebuilt and scored with the existing `score.py`; the new bars go into `NAMING_MEASURED`.

**Tech Stack:** Python 3.14 standard library (`unittest`), GBIF occurrence API, the existing pack builder venv for the rebuild and scorer.

**Spec:** `docs/design/specs/2026-11-17-marine-life-survey-candidates-design.md` (issue #4683)

## Global Constraints

- Survey filters: `basis_of_record=HUMAN_OBSERVATION`, `occurrence_status=PRESENT`, `depth=0,40`, faceted by `speciesKey`, within the same order keys as the photo route.
- `--min-survey-records` defaults to 50; `--max-candidates` defaults to 10000 (was 8000); `--min-images` stays 50.
- Order: catalogue species, then photographed species in rank order, then surveyed species not already chosen, in rank order; survey-only species are the ones cut when the cap binds.
- The photo query's filters and the shape of `candidates.json` do not change. (The review later found GBIF's facet paging skips species; each facet became one request under new cache names, the photo one included. See the design's "Decided during review".)
- No pack is published and the feature flag stays off.
- Local tests: only the changed test files, by path.
- No em-dashes, en-dashes as punctuation, or spaced hyphens as prose punctuation in code, comments or docs.

## Review Focus

- A species in both rankings must be listed once, at its photographed position.
- A cap smaller than the catalogue plus the photographed species must leave out every survey-only species and never go negative.
- The survey query must not count absence rows or records deeper than 40 m; a regression here brings back the fishery and deep-sea species.
- The survey facet's cache must not be answered from the photo facet's cache (same taxa and same minimum), nor from an earlier survey query with other filters.
- A species GBIF lists twice (photo and survey facets returning the same key with different counts) must not shift the photographed order.

---

### Task 1: The survey facet and the merge, in `candidates.py`

**Files:**
- Modify: `tool/species_pack/candidates.py` (the facet query at `fetch_photographed_species`, about lines 128-156; new constants and functions beside it)
- Test: `tool/species_pack/manifest_test.py` (new classes after `ExpansionTests`)

> **Revised in review.** This task first paged the facet with
> `facetOffset` and kept the photo cache's old name. GBIF's paging repeats
> and skips species at page boundaries, so the task below now describes
> the shipped one-request facet. Do not bring the paging back; see the
> design's "Decided during review".

**Interfaces:**
- Produces:
  - `SURVEY_FILTERS: list[tuple[str, str]]`, the extra query parameters of the survey facet: `[("basis_of_record", "HUMAN_OBSERVATION"), ("occurrence_status", "PRESENT"), ("depth", "0,40")]`.
  - `PHOTO_FILTERS: list[tuple[str, str]]`: `[("media_type", "StillImage"), ("basis_of_record", "HUMAN_OBSERVATION")]` (today's).
  - `facet_cache_path(work: str, route: str, taxon_keys, filters, min_count: int, limit: int) -> str`: `facets/<route>_<sha256(sorted keys + filters)[:12]>_<min>_<limit>.json` for every route, so no name matches an earlier build's paged `species_*` files.
  - `fetch_surveyed_species(taxon_keys, work, *, min_records, limit=20000) -> list[tuple[int, int]]`, most recorded first.
  - `fetch_photographed_species(taxon_keys, work, *, min_images, limit=20000)`: same output as before, from one request (its `page` argument is gone).
  - `wanted_keys(photographed, surveyed, have, room) -> list[int]`: `photographed` and `surveyed` are `(key, count)` lists in rank order, `have` the keys already on the list, `room` how many may be added. Returns photographed keys not in `have`, then surveyed keys in neither, de-duplicated, truncated to `max(0, room)`.

- [ ] **Step 1: Write the failing tests**

```python
class SurveyQueryTests(unittest.TestCase):
    def test_survey_counts_only_present_shallow_human_observations(self):
        f = dict(candidates.SURVEY_FILTERS)
        self.assertEqual(f["basis_of_record"], "HUMAN_OBSERVATION")
        self.assertEqual(f["occurrence_status"], "PRESENT")
        self.assertEqual(f["depth"], "0,40")
        self.assertNotIn("media_type", f)

    def test_photo_query_is_unchanged(self):
        self.assertEqual(candidates.PHOTO_FILTERS, [("media_type", "StillImage"), ("basis_of_record", "HUMAN_OBSERVATION")])

    def test_photo_cache_is_not_an_earlier_paged_page(self):
        path = candidates.facet_cache_path("w", "photographed", [3, 1], candidates.PHOTO_FILTERS, 50, 20000)
        digest = hashlib.sha256(b"1,3").hexdigest()[:12]
        self.assertNotEqual(path, os.path.join("w", "facets", f"species_{digest}_50_0.json"))

    def test_survey_cache_differs_from_the_photo_cache(self):
        photo = candidates.facet_cache_path("w", "photographed", [1], candidates.PHOTO_FILTERS, 50, 20000)
        survey = candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 20000)
        self.assertNotEqual(photo, survey)

    def test_cache_changes_with_filters_taxa_floor_and_limit(self):
        base = candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 20000)
        for other in (
            candidates.facet_cache_path("w", "surveyed", [1], [("depth", "0,30")], 50, 20000),
            candidates.facet_cache_path("w", "surveyed", [1, 2], candidates.SURVEY_FILTERS, 50, 20000),
            candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 25, 20000),
            candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 1000),
        ):
            self.assertNotEqual(base, other)


# SpeciesFacetTests (in manifest_test.py) stubs candidates._get_json and
# pins one request per route (no facetOffset, facetLimit=limit), each
# route's filters and cache prefix, and the warning when GBIF returns
# `limit` species.


class WantedKeysTests(unittest.TestCase):
    def test_photographed_first_then_surveyed(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(3, 900), (4, 50)], set(), 10), [1, 2, 3, 4])

    def test_a_species_in_both_is_listed_once_at_its_photographed_place(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(2, 5000), (3, 60)], set(), 10), [1, 2, 3])

    def test_species_already_on_the_list_are_skipped(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(3, 60)], {1, 3}, 10), [2])

    def test_survey_only_species_are_cut_first(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(3, 900)], set(), 2), [1, 2])

    def test_no_room_adds_nothing(self):
        self.assertEqual(candidates.wanted_keys([(1, 90)], [(3, 900)], set(), 0), [])
        self.assertEqual(candidates.wanted_keys([(1, 90)], [(3, 900)], set(), -5), [])

    def test_a_key_repeated_within_a_ranking_counts_once(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (1, 90)], [(3, 9), (3, 9)], set(), 10), [1, 3])
```

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: errors, `module 'candidates' has no attribute 'SURVEY_FILTERS'` (and the like).

- [ ] **Step 3: Implement in `candidates.py`**

Replace the paging loop of `fetch_photographed_species` with a private `_species_facet(taxon_keys, work, route, filters, min_count, limit)` that makes one request: `taxon_key` params, `filters`, `limit=0`, `facet=speciesKey`, `facetMincount`, and `facetLimit=limit`, with no `facetOffset`, read and written through `facet_cache_path`. If GBIF returns `limit` species it prints a warning to stderr that species beyond it are missing. `fetch_photographed_species` calls it with `"photographed"` and `PHOTO_FILTERS`; `fetch_surveyed_species` with `"surveyed"` and `SURVEY_FILTERS`. Update the module docstring (the list is now catalogue, photographed, then surveyed). A comment on `SURVEY_FILTERS` says why each filter is there: absence rows from monitoring programmes, and fishery and deep ROV records below diving depth.

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/candidates.py tool/species_pack/manifest_test.py
git commit -m "feat(species-id): count dive survey records toward the candidate list"
```

### Task 2: Wire it into `build_pack.py`, and document the options

**Files:**
- Modify: `tool/species_pack/build_pack.py` (argument parsing and step 3, about lines 59-103)
- Modify: `docs/developer/species-identification.md` (the "Useful options" list, about lines 84-92, and the paragraph above it)
- Test: `tool/species_pack/manifest_test.py` (`PackVersionTests` neighbour)

**Interfaces:**
- Consumes: `cand.fetch_surveyed_species`, `cand.wanted_keys` (Task 1).
- Produces: `build_pack.parse_args(argv) -> argparse.Namespace` with `max_candidates` (default 10000), `min_images` (50), `min_survey_records` (50); `main(argv)` calls it.

- [ ] **Step 1: Write the failing test**

```python
class BuildOptionsTests(unittest.TestCase):
    def test_defaults(self):
        args = build_pack.parse_args(["--out", "x"])
        self.assertEqual(args.max_candidates, 10000)
        self.assertEqual(args.min_images, 50)
        self.assertEqual(args.min_survey_records, 50)

    def test_survey_floor_is_its_own_option(self):
        self.assertEqual(build_pack.parse_args(["--out", "x", "--min-survey-records", "25"]).min_survey_records, 25)
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: `AttributeError: module 'build_pack' has no attribute 'parse_args'`.

- [ ] **Step 3: Implement**

Extract `parse_args` from `main`. In step 3, fetch both rankings within the same `orders`, then `wanted = cand.wanted_keys(photographed, surveyed, have, args.max_candidates - len(rows))`. Print the photographed and surveyed counts, and how many of the final candidates came only from surveys, so a build log shows the split. In the developer guide, say the list also takes species divers record often in surveys, list `--min-survey-records N` (default 50: present human observations at 0 to 40 m), and change the `--max-candidates` default to 10000.

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/build_pack.py tool/species_pack/manifest_test.py docs/developer/species-identification.md
git commit -m "feat(species-id): build the pack with surveyed species, cap 10,000"
```

### Task 3: Rebuild the full pack

Developer run, nothing committed. Work in the session scratchpad (`$S`), with the GBIF and model caches copied from the previous full build (`$S/work`), so only new species are fetched.

- [ ] **Step 1: Build**

Run (background, with the pack venv's interpreter `$PY`): `$PY -I tool/species_pack/build_pack.py --out $S/pack_survey --work $S/work --skip-models`
Expected: `candidates:` about 9,000; the survey-only count about 1,365; `pack <version>: ... candidates`.

- [ ] **Step 2: Check it**

Creole Wrasse (5209750) is in `$S/pack_survey/candidates.json` with a non-empty region row; every gbifKey of the old pack (`pack_full/candidates.json`, 7,646) is still present; the detector and classifier zips hash the same as the old pack's.

### Task 4: Score the new pack and apply its bars

**Files:**
- Modify: `tool/species_pack/manifest.py` (`NAMING_MEASURED`, about lines 51-80)
- Test: `tool/species_pack/manifest_test.py` (`MeasuredBarsTests`)

- [ ] **Step 1: Fetch the test photos and the Megalodon model**

Run: `$PY -I tool/species_pack/fetch_testset.py photos-from-csv --work $S/accuracy` then `$PY -I tool/species_pack/megalodon.py convert megalodon-2024 --check-image <a photo> --work $S/accuracy` (or copy the converted model from the measured accuracy session's work folder if its options allow).
Expected: every photo the CSV names is present; the Megalodon check passes.

- [ ] **Step 2: Score**

Run (background): `$PY -I tool/species_pack/score.py --pack $S/pack_survey --work $S/accuracy`
Expected: `results.json` and `report.md` in `$S/accuracy`, with `contents` hashes and the chosen bars for the Community Fish Detector at its chosen fitting.

- [ ] **Step 3: Update the pinned test to the new pack (fails first)**

In `MeasuredBarsTests`, set `MEASURED_PACK` to the new `contents` hashes and the asserted bars to the new values from `results.json`.
Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: FAIL on `test_the_measured_pack_gets_the_measured_bars`.

- [ ] **Step 4: Replace `NAMING_MEASURED`**

New `naming` values, `packVersion`, `contents`, and `cropFit` from `results.json`; the comment says which pack and findings section they come from.
Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/manifest.py tool/species_pack/manifest_test.py
git commit -m "feat(species-id): measured bars for the pack with surveyed species"
```

### Task 5: Findings

**Files:**
- Modify: `docs/design/findings/2026-11-17-marine-life-measured-accuracy.md`

- [ ] **Step 1: Update the findings**

The header names the new pack and its candidate count. "The answers" and the results tables carry the new pack's numbers. A new section, "The candidate list with surveyed species", compares the two packs: candidates, held-out precision at the bars, share suggested, bars, and the 12 test photos whose labels entered. The last Limits bullet says the list now includes surveyed species, that about a quarter of them come mostly from catch surveys, and that records without a depth do not count. Links resolve (`python3.14 scripts/check_docs_links.py`).

- [ ] **Step 2: Commit**

```bash
git add docs/design/findings/2026-11-17-marine-life-measured-accuracy.md
git commit -m "docs(species-id): findings for the pack with surveyed species"
```
