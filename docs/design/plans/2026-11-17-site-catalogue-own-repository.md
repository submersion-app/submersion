# Site catalogue own repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the site catalogue pipeline into its own public repository that publishes versioned releases, take those releases into the app by a bot PR behind a format gate, and add tiered AI research at scale.

**Architecture:** Three parts in one plan. Part A builds `submersion-app/site-catalogue` from the app repository's pipeline (history kept), adds the format contract, published snapshot sets, the monthly refresh and releases. Part B makes the app take releases through a PR checked by a contract test, and removes the moved files. Part C adds domain kinds, recorded machine checks, a second pass, auto-tier rules in the checker, run tooling and the research skill.

**Tech Stack:** Python 3.14 (stdlib only, as today), GitHub Actions with the built-in `GITHUB_TOKEN` (no App or personal token), `git filter-repo` for the extract, Flutter/Dart tests in the app.

**Spec:** `docs/design/specs/2026-11-17-site-catalogue-own-repository-design.md`

**Built 2026-11-17, with changes.** Where the build departed from this plan,
the code is right and the design's "Changes made while building" says why:
the catalogue is committed in the catalogue repository (`catalogue/`, not an
ignored `build/catalogue`), the app keeps its contract copy in
`test/features/dive_sites/data/catalogue/contract/` (not `assets/data/`),
releases are not dispatched to the app (its intake polls weekly), and the
intake refuses a release built before the shipped catalogue.

## Global Constraints

- Nothing written to either repository mentions the AI tool, its maker, or carries an attribution trailer or session link (both repositories' rules). The agent instructions file is `AGENTS.md`.
- No em-dash or en-dash used as punctuation anywhere written.
- Python runs as `python3.14`; any network request a script makes sends `User-Agent: dive-site-harvester/1.0` and nothing naming a person or the project.
- Code is GPL-3.0; the catalogue is ODbL 1.0, with `njdep`, `nc_dmf`, `tpwd`, `hi_dar` (`OWN_TERMS_SOURCES`) named apart and left out of the open-only build.
- No page text in the repository: evidence holds facts and addresses only.
- No figure from a lead list, a cite-only or a never domain ships.
- Lead lists are never written to disk outside a run's memory and never committed.
- Snapshot sets are release assets tagged `snapshots-YYYY-MM-DD`; catalogue releases are tagged `YYYY.MM.DD` (suffix `.2`, `.3` for a second release that day).
- Audit sample: 10 percent of a run's auto-tier entries, at least 5 (or all, if fewer), at most 30. Pause rule: more than 1 wrong in 20 sampled (error rate above 0.05) pauses the auto tier.
- Bot PRs are opened with the built-in `GITHUB_TOKEN`; the maintainer closes and reopens each app release PR to start its CI.
- Creating the public repository, pushing, opening PRs and cutting releases are outward actions: each needs the maintainer's explicit go-ahead at the time, except the commits inside this plan's tasks.

## Review Focus

1. **A fact edited after auto approval.** Someone changes an auto-approved entry's position or a source by hand. Expected: the checker refuses `"by": "auto"` because the second pass no longer covers the current facts (Task 12 records a facts hash; test there).
2. **A source that answers with a short or truncated snapshot** (an Overpass `remark`, a register with a tenth of its rows). Expected: the refresh treats it as failed, reuses the previous set's file, names it in the report (Task 6 test).
3. **The app adds a country alias the contract lacks.** Expected: nothing fails; only a contract country the app cannot resolve fails (Task 9 test asserts the subset direction).
4. **A rebuild asked for a snapshot set that does not exist.** Expected: the rebuild stops naming the missing tag and writes nothing (Task 5 test).
5. **A release whose record count collapses** (a source dropped silently upstream). Expected: the app's release PR fails its floor test (Task 9 test).

---

## Part A: the new repository

### Task 0: Preconditions (maintainer, no code)

- [ ] **Step 1:** Confirm PR #4650 is merged into `main` of `submersion-app/submersion` (`gh pr view 4650 --json state` shows `MERGED`). Everything below extracts from that `main`.
- [ ] **Step 2:** Ask the maintainer for the go-ahead to create the public repository `submersion-app/site-catalogue`. Do not create it before a yes.
- [ ] **Step 3:** Maintainer's go-ahead to create the repository: given 2026-11-17 ("Yes, create it").

### Task 1: Extract the pipeline with its history

**Files (new repository, created locally at `/Users/ericgriffin/repos/submersion-app/site-catalogue`):**
- From the app repository, kept with history and renamed:
  - `scripts/site_catalogue/*.py` and `scripts/site_catalogue/samples/` to `pipeline/`
  - `scripts/site_catalogue/research/` to `research/`
  - `scripts/site_catalogue_format.py`, `scripts/site_catalogue_format_test.py` to `pipeline/`
  - `scripts/site_country_resolver.py`, `scripts/site_country_resolver_test.py` to `pipeline/`
  - `scripts/curated_sites.py`, `scripts/curated_sites_test.py`, `scripts/dive_sites_curated.json` to `curated/`
- Copied without history (the app still generates its Dart country table with it): `scripts/geography/generate_country_names.py` to `pipeline/generate_country_names.py`
- Modify: every moved module's `sys.path` setup and `_REPO`/`_HERE` paths
- Create: `.gitignore` (`.cache/`, `build/`, `__pycache__/`)

**Interfaces:**
- Produces: `pipeline/merge.py` `main(argv=None, *, places=None, curated=None, research=None) -> int` unchanged; `merge.DEFAULT_OUT = REPO / "build" / "catalogue"`; `snapshots.CACHE_DIR = REPO / ".cache" / "snapshots"`.

- [ ] **Step 1:** In a scratch clone of the app repository, run `git filter-repo` with `--path` for each moved file and `--path-rename` to the new locations. Confirm `git log --follow research/sites.json` shows #4592 and #4650.
- [ ] **Step 2:** Run every moved test: `for t in pipeline/*_test.py research/*_test.py curated/*_test.py; do python3.14 "$t" || echo "FAIL $t"; done`. Expected: failures only on import paths and the Dart-file readers in `places.py` (fixed in Task 3; mark those tests `expectedFailure` with a note pointing at Task 3).
- [ ] **Step 3:** Fix the path setup so every other test passes. No behaviour change.
- [ ] **Step 4:** Rerun Step 2. Expected: all pass except the marked ones.
- [ ] **Step 5: Commit** `git add -A && git commit -m "chore: lay out the pipeline in its own repository"` (inside the new repository, which holds nothing else).

### Task 2: Repository documents and CI

**Files (new repository):**
- Create: `README.md` (what the catalogue is; how to build: fetch, then `python3.14 pipeline/merge.py`; how to rebuild a release from its snapshot set; how to use a release; the open-only build), `LICENSE` (GPL-3.0 text, as the app's), `LICENSE-DATA.md` (ODbL 1.0, the OpenStreetMap notice, the four own-terms sources named as outside the ODbL database), `AGENTS.md` (the attribution rule, no page text, the licence position, never force a failing entry, stage explicit paths)
- Create: `.github/workflows/ci.yml`, `pipeline/run_tests.py`

**Interfaces:**
- Produces: `python3.14 pipeline/run_tests.py` runs every `*_test.py` under `pipeline/`, `research/`, `curated/` and exits non-zero if any fails.

- [ ] **Step 1:** Write `pipeline/run_tests.py` (`main() -> int`, `unittest.defaultTestLoader.discover` per folder, pattern `*_test.py`).
- [ ] **Step 2:** Run it. Expected: same result as Task 1 Step 4.
- [ ] **Step 3:** Write `ci.yml`: on `push` to `main` and `pull_request`; Python 3.14; steps `python3.14 pipeline/run_tests.py`, `python3.14 research/check.py`, and a dash scan that fails if any tracked text file holds U+2014 or U+2013.
- [ ] **Step 4:** Write the four documents. README's open-only section names the release asset `site_catalogue_open.json`.
- [ ] **Step 5: Commit** `git add README.md LICENSE LICENSE-DATA.md AGENTS.md .github/workflows/ci.yml pipeline/run_tests.py && git commit -m "docs: licences, agent rules and CI"`.

### Task 3: The format contract and the country table

**Files (new repository):**
- Create: `pipeline/contract.py`, `pipeline/contract_test.py`, `contract/format.json`, `contract/countries.json`
- Modify: `pipeline/places.py` (`known_country_names()` reads `contract/countries.json`), `pipeline/places_test.py` (remove the `expectedFailure` marks), `.github/workflows/ci.yml`

**Interfaces:**
- Produces:
  - `build_contract() -> dict` with keys `format` (`site_catalogue_format.FORMAT`), `fields` (`{name: {"required": bool}}` for every record field the merge writes), `site_types` (`SITE_TYPE_IDS`), `entry_methods` (`ENTRY_METHODS`), `trust_levels` (`TRUST_LEVELS`), `position_from` (`["map"]`), `withdrawal_reasons` (`WITHDRAWAL_REASONS`), `hazard_codes` (sorted keys of `evidence.HAZARD_SENTENCES`), `kinds` (`KINDS`).
  - `contract/countries.json`: `{"names": {folded_name: code}}`, exactly what `known_country_names()` returned from the app's Dart files at the extract commit.
  - `write_contract(directory: Path) -> None` writes `format.json` sorted, 2-space indent, trailing newline.
  - `python3.14 pipeline/contract.py --check` exits 1 when `contract/format.json` differs from `build_contract()`.

- [ ] **Step 1: Write the failing tests** in `pipeline/contract_test.py`:

```python
def test_contract_matches_the_python_definitions(self):
    on_disk = json.loads((CONTRACT / "format.json").read_text("utf-8"))
    self.assertEqual(on_disk, contract.build_contract())

def test_vocabularies_are_the_formats_own(self):
    c = contract.build_contract()
    self.assertEqual(c["format"], fmt.FORMAT)
    self.assertEqual(c["site_types"], list(fmt.SITE_TYPE_IDS))
    self.assertEqual(c["entry_methods"], list(fmt.ENTRY_METHODS))
    self.assertEqual(c["position_from"], ["map"])
    self.assertTrue(c["fields"]["id"]["required"])
    self.assertFalse(c["fields"]["position_from"]["required"])

def test_country_table_resolves_as_the_app_did(self):
    known = places.known_country_names()
    self.assertEqual(known[places.fold_country("Bonaire")], "BQ")
    self.assertGreater(len(known), 400)
```

- [ ] **Step 2:** Run `python3.14 pipeline/contract_test.py`. Expected: FAIL (no module `contract`).
- [ ] **Step 3:** Generate `contract/countries.json` once from the app repository's current Dart files with the old `known_country_names()` logic (a one-off run, not committed), then implement `contract.py` and switch `places.known_country_names()` to read the JSON.
- [ ] **Step 4:** Run `python3.14 pipeline/run_tests.py`. Expected: all pass, the marks removed.
- [ ] **Step 5:** Add `python3.14 pipeline/contract.py --check` to `ci.yml`.
- [ ] **Step 6: Commit** `git add pipeline/contract.py pipeline/contract_test.py contract/ pipeline/places.py pipeline/places_test.py .github/workflows/ci.yml && git commit -m "feat: publish the catalogue's format contract and country table"`.

### Task 4: Research records cite the new repository

**Files (new repository):**
- Modify: `pipeline/src_research.py` (`_REPOSITORY_FILE`), `pipeline/src_research_test.py`, `research/README.md` (paths)

**Interfaces:**
- Produces: `source_ref(entry_id) -> "https://github.com/submersion-app/site-catalogue/blob/main/research/sites.json#:~:text=<id>"`.

- [ ] **Step 1:** Change `SourceRefTest.test_points_at_the_entry_in_the_repository` to expect the prefix `https://github.com/submersion-app/site-catalogue/blob/main/research/sites.json`.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Change `_REPOSITORY_FILE`; update the README's paths (`scripts/site_catalogue/research/` to `research/`, the `check.py` commands).
- [ ] **Step 4:** Run `python3.14 pipeline/run_tests.py`. Expected: PASS.
- [ ] **Step 5: Commit** `git add pipeline/src_research.py pipeline/src_research_test.py research/README.md && git commit -m "feat: researched records cite their evidence in this repository"`.

### Task 5: Snapshot sets: terms notes, packing and restoring

**Files (new repository):**
- Create: `pipeline/snapshot_sets.py`, `pipeline/snapshot_sets_test.py`

**Interfaces:**
- Consumes: `snapshots.CACHE_DIR`, `site_catalogue_format.SOURCES`, `OWN_TERMS_SOURCES`, `merge.NJDEP_METADATA_FILE`, `merge.MD_DNR_METADATA_FILE`.
- Produces:
  - `terms_note(key: str) -> str`: plain text naming the source, its licence and licence URL, its credit. Own-terms `nc_dmf`, `hi_dar`, `tpwd` add "Not part of the ODbL database; not for commercial use."; `njdep` adds "Redistributed with NJDEP's metadata, credit and disclaimer, coordinates as received."; `hi_dar` and `tpwd` say their rows sit in the MarineCadastre file, and `tpwd` repeats the TPWD credit line.
  - `pack(cache: Path, out: Path) -> list[Path]`: copies every `<key>.json` and metadata file from `cache` into `out`, writes `<key>.TERMS.txt` beside each snapshot and `SET.json` (`{"keys": [...], "fetched_at": {key: iso}}`); returns the written paths sorted.
  - `restore(tag: str, cache: Path, *, fetch=gh_release_download) -> None`: downloads the set's assets into `cache`; raises `MissingSnapshotSet(tag)` when the release does not exist, writing nothing.
  - CLI: `python3.14 pipeline/snapshot_sets.py pack --out DIR` and `restore TAG`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_every_snapshot_gets_a_terms_note(self):
    paths = snapshot_sets.pack(self.cache, self.out)
    for key in ("osm_sites", "ukho", "njdep", "nc_dmf"):
        self.assertIn(self.out / f"{key}.TERMS.txt", paths)

def test_own_terms_notes_stand_apart_from_odbl(self):
    self.assertIn("Not part of the ODbL database", snapshot_sets.terms_note("nc_dmf"))
    self.assertIn("NJDEP's metadata", snapshot_sets.terms_note("njdep"))
    self.assertIn("Information courtesy Texas Parks and Wildlife Department",
                  snapshot_sets.terms_note("tpwd"))

def test_new_jersey_ships_with_its_metadata(self):
    snapshot_sets.pack(self.cache, self.out)
    self.assertTrue((self.out / merge.NJDEP_METADATA_FILE).exists())

def test_a_missing_set_stops_and_writes_nothing(self):  # Review Focus 4
    with self.assertRaises(snapshot_sets.MissingSnapshotSet):
        snapshot_sets.restore("snapshots-1999-01-01", self.cache, fetch=_absent)
    self.assertEqual(list(self.cache.iterdir()), [])
```

- [ ] **Step 2:** Run. Expected: FAIL (no module).
- [ ] **Step 3:** Implement. `gh_release_download(tag, dest)` runs `gh release download TAG --dir DEST`; tests inject fakes.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `git add pipeline/snapshot_sets.py pipeline/snapshot_sets_test.py && git commit -m "feat: snapshot sets with each source's terms"`.

### Task 6: The monthly refresh

**Files (new repository):**
- Create: `pipeline/refresh.py`, `pipeline/refresh_test.py`, `.github/workflows/refresh.yml`

**Interfaces:**
- Consumes: each `src_*.py` module's fetch functions; `snapshot_sets.pack`, `restore`; `merge.main`.
- Produces:
  - `FETCHES: dict[str, Callable[[], object]]`: one entry per snapshot key (`src_osm.fetch_sites`, `src_osm.fetch_wrecks`; `src_reefs.fetch_fwc`, `fetch_federal`, `fetch_njdep`, `fetch_nc_dmf`, `fetch_fknms`; the other modules' `fetch`), plus `places.fetch_boundaries`.
  - `refresh(previous_tag: str | None, cache: Path, *, fetches=FETCHES, pause=60) -> RefreshResult`, where `RefreshResult(fetched: list[str], reused: dict[str, str], failed_without_fallback: list[str])`. Each fetch is tried, retried once after `pause` seconds on any exception; a key still failing is restored from `previous_tag` and listed in `reused` with the error's first line.
  - A fetched snapshot whose row count is below half of the previous set's count for that key counts as failed (Review Focus 2).
  - `pr_body(result: RefreshResult, merge_output: str) -> str`: the merge report in a fenced block, then a "Reused from the previous set" list, then `Refs #4514`.
  - Exit codes of `python3.14 pipeline/refresh.py --previous TAG`: 0 rebuilt; 2 the merge stopped on a departure (the workflow opens an issue with the merge output instead of a PR); 3 a source failed with no previous set.

- [ ] **Step 1: Write the failing tests:**

```python
def test_a_failing_source_is_reused_and_named(self):
    result = refresh.refresh("snapshots-2026-11-16", self.cache,
                             fetches={"ukho": _raises, "awois": _ok}, pause=0)
    self.assertEqual(result.fetched, ["awois"])
    self.assertIn("ukho", result.reused)

def test_a_collapsed_snapshot_counts_as_failed(self):
    result = refresh.refresh("snapshots-2026-11-16", self.cache,
                             fetches={"osm_sites": _writes_tenth}, pause=0)
    self.assertIn("osm_sites", result.reused)

def test_the_pr_body_names_what_was_reused(self):
    body = refresh.pr_body(refresh.RefreshResult(["awois"], {"ukho": "HTTP 500"}, []), "report")
    self.assertIn("ukho", body)
    self.assertIn("Refs #4514", body)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `refresh.py`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Write `refresh.yml`: `schedule: cron "0 6 1 * *"` and `workflow_dispatch`; run `refresh.py --previous <latest snapshots tag from gh release list>`, `snapshot_sets.py pack`, `gh release create snapshots-$(date +%F)` with the packed files and notes "Each file's terms are in its TERMS.txt; own-terms files are not part of the ODbL database.", then on exit 0 open a PR on branch `refresh/YYYY-MM-DD` with `GITHUB_TOKEN` (`permissions: contents: write, pull-requests: write, issues: write`), its body saying the workflow already ran the tests and the checker; on exit 2 open an issue.
- [ ] **Step 6: Commit** `git add pipeline/refresh.py pipeline/refresh_test.py .github/workflows/refresh.yml && git commit -m "feat: monthly register refresh opens a PR"`.

### Task 7: Releases

**Files (new repository):**
- Create: `pipeline/release.py`, `pipeline/release_test.py`, `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `merge.main`, `contract.write_contract`, `snapshot_sets.restore`.
- Produces:
  - `RELEASE_FILES = ("site_catalogue.json", "site_catalogue.version", "site_catalogue_njdep_metadata.xml", "site_catalogue_md_dnr_metadata.xml", "site_catalogue_open.json", "format.json", "countries.json")`.
  - `build_release(cache: Path, out: Path) -> list[Path]`: runs the merge into `out`, runs `merge.main(["--open-only", "--out", tmp])` and copies its catalogue to `out/site_catalogue_open.json`, writes `format.json` and copies `contract/countries.json`; returns `[out / name for name in RELEASE_FILES]`.
  - `release_notes(merge_output: str, snapshot_tag: str) -> str`: starts with `Built from <snapshot_tag>`.
  - `next_tag(existing: list[str], today: date) -> str`: `YYYY.MM.DD`, then `.2`, `.3`.

- [ ] **Step 1: Write the failing tests** (use the `samples/` snapshots as the set, as `merge_test.py` does):

```python
def test_the_same_set_builds_the_same_bytes(self):  # acceptance 2
    a = release.build_release(self.cache, self.out / "a")
    b = release.build_release(self.cache, self.out / "b")
    for x, y in zip(a, b):
        self.assertEqual(x.read_bytes(), y.read_bytes(), x.name)

def test_the_open_build_leaves_out_the_own_terms_sources(self):
    release.build_release(self.cache, self.out)
    doc = json.loads((self.out / "site_catalogue_open.json").read_text("utf-8"))
    self.assertFalse({s["source"] for s in doc["sites"]} & set(fmt.OWN_TERMS_SOURCES))

def test_a_release_holds_every_file(self):
    names = [p.name for p in release.build_release(self.cache, self.out)]
    self.assertEqual(names, list(release.RELEASE_FILES))

def test_tags(self):
    self.assertEqual(release.next_tag([], date(2026, 12, 1)), "2026.12.01")
    self.assertEqual(release.next_tag(["2026.12.01"], date(2026, 12, 1)), "2026.12.01.2")
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Write `release.yml`: `workflow_dispatch` with input `snapshots` (tag); restore that set, run the tests and the checker, `build_release`, `gh release create <next_tag>` with the files and notes (`GITHUB_TOKEN`, `contents: write`). Nothing is sent to the app repository: its intake polls (Task 10).
- [ ] **Step 6: Commit** `git add pipeline/release.py pipeline/release_test.py .github/workflows/release.yml && git commit -m "feat: date-tagged catalogue releases"`.

### Task 8: Publish the repository and its first release

- [ ] **Step 1:** With the maintainer's go-ahead (Task 0 Step 2), `gh repo create submersion-app/site-catalogue --public --source . --push`.
- [ ] **Step 2:** Confirm CI passes on `main` (`gh run list --limit 1` shows success).
- [ ] **Step 3:** Run `refresh.yml` by hand. Expected: a release `snapshots-<today>` with a TERMS.txt per source, and a refresh PR opened by `github-actions[bot]` whose body says the tests and checker passed in the workflow.
- [ ] **Step 4:** The maintainer merges the refresh PR; run `release.yml` with that snapshot tag. Expected: a release with the seven `RELEASE_FILES`.
- [ ] **Step 5:** Restore that snapshot set into an empty cache on this machine, run `build_release`, and confirm the catalogue's bytes equal the release asset's (acceptance 2).

## Part B: the app

Work in a new worktree of `submersion-app/submersion` from `origin/main` (after #4650), branch `ericgriffin/site-catalogue-release-intake`; run `git submodule update --init --recursive` and `flutter pub get` first.

### Task 9: The format gate and release-shaped pins

**Files (app repository):**
- Create: `assets/data/site_catalogue_format.json`, `assets/data/site_catalogue_countries.json` (copies of the first release's `format.json` and `countries.json`), `test/features/dive_sites/data/catalogue/site_catalogue_contract_test.dart`
- Modify: `lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart`, `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart` (pins)

**Interfaces:**
- Produces, in the parser file: `const int kSupportedCatalogueFormat = 2;` and `const Set<String> kParsedCatalogueFields` holding the record keys the parser reads: `id`, `name`, `lat`, `lon`, `country_code`, `country`, `region`, `locality`, `island`, `body_of_water`, `water_type`, `max_depth_m`, `min_depth_m`, `types`, `entry`, `difficulty`, `features`, `hazards`, `description`, `website`, `kind`, `source`, `source_ref`, `trust`, `position_from`.
- Consumes: `kBuiltInSiteTypes` (`lib/core/database/site_type_seed.dart`), `EntryMethod` (`lib/core/constants/app_enums.dart`), the app's folded country lookup (`countryLookupKey` and the table in `lib/core/geography/country_code.dart`).

- [ ] **Step 1: Write the failing contract tests:**

```dart
test('the catalogue format is one this app reads', () {
  expect(contract['format'] as int, lessThanOrEqualTo(kSupportedCatalogueFormat));
});
test('every site type in the contract is one the app seeds', () {
  final seeded = {for (final t in kBuiltInSiteTypes) t.id};
  expect(seeded, containsAll(contract['site_types'] as List));
});
test('every entry method in the contract is an EntryMethod', () {
  final names = EntryMethod.values.map((e) => e.name).toSet();
  expect(names, containsAll(contract['entry_methods'] as List));
});
test('every contract country resolves to its code in the app', () {  // Review Focus 3
  for (final MapEntry(:key, :value) in countries.entries) {
    expect(countryCodeFor(key), value, reason: key);
  }
});
test('every record field the contract lists is one the parser reads', () {
  expect(kParsedCatalogueFields, containsAll((contract['fields'] as Map).keys));
});
```

- [ ] **Step 2:** Run `flutter test test/features/dive_sites/data/catalogue/site_catalogue_contract_test.dart`. Expected: FAIL (missing constants and files).
- [ ] **Step 3:** Add the two constants and the two JSON files.
- [ ] **Step 4:** Replace the asset test's exact counts (`hasLength(20988)`, `16999`, `3989`) with: `metadata['total_count'] == sites.length`, and floors `sites.length >= 20000` and dive-site records `>= 3900` (Review Focus 5; the maintainer may raise them).
- [ ] **Step 5:** Run `flutter test test/features/dive_sites/data/catalogue`. Expected: PASS.
- [ ] **Step 6: Commit** `git add assets/data/site_catalogue_format.json assets/data/site_catalogue_countries.json lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart test/features/dive_sites/data/catalogue/site_catalogue_contract_test.dart test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart && git commit -m "feat(dive-sites): check each catalogue release against the format the app reads"`.

### Task 10: The release intake workflow

**Files (app repository):**
- Create: `scripts/site_catalogue_intake.py`, `scripts/site_catalogue_intake_test.py`, `.github/workflows/site-catalogue-release.yml`
- Modify: `.github/workflows/ci.yaml` (add the intake test to the script-tests list)

**Interfaces:**
- Produces:
  - `INTAKE_FILES = {"site_catalogue.json": "assets/data/site_catalogue.json", "site_catalogue.version": "assets/data/site_catalogue.version", "site_catalogue_njdep_metadata.xml": "assets/data/site_catalogue_njdep_metadata.xml", "site_catalogue_md_dnr_metadata.xml": "assets/data/site_catalogue_md_dnr_metadata.xml", "format.json": "assets/data/site_catalogue_format.json", "countries.json": "assets/data/site_catalogue_countries.json"}`.
  - `take(release_dir: Path, repo: Path) -> list[str]`: copies each file to its place and returns the repository paths changed; raises `ValueError` naming any missing release file before changing anything.
  - `pr_body(tag: str, notes: str) -> str`: the release notes, "This PR changes catalogue data only; no screen changes.", and `Refs #4514`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_takes_every_release_file_to_its_place(self):
    changed = intake.take(self.release, self.repo)
    self.assertIn("assets/data/site_catalogue_format.json", changed)
    self.assertEqual((self.repo / "assets/data/site_catalogue.json").read_bytes(),
                     (self.release / "site_catalogue.json").read_bytes())

def test_a_missing_file_changes_nothing(self):
    (self.release / "format.json").unlink()
    with self.assertRaises(ValueError):
        intake.take(self.release, self.repo)
    self.assertFalse((self.repo / "assets/data/site_catalogue.json").exists())
```

- [ ] **Step 2:** Run `python3.14 scripts/site_catalogue_intake_test.py`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Write `site-catalogue-release.yml`: on `schedule: cron "0 7 * * 1"` (weekly) and `workflow_dispatch` (input `tag`, default latest); find the newest release with `gh release list --repo submersion-app/site-catalogue`, stop when its `site_catalogue.version` equals `assets/data/site_catalogue.version` or a branch `site-catalogue/<tag>` already exists, else `gh release download`, run `take`, and open a PR on branch `site-catalogue/<tag>` with `GITHUB_TOKEN` (`contents: write`, `pull-requests: write`) and `pr_body`. `pr_body` ends with: "CI does not start on a PR opened by a workflow: close and reopen this PR to run it." (acceptance 4: the maintainer reopens, CI passes).
- [ ] **Step 6: Commit** `git add scripts/site_catalogue_intake.py scripts/site_catalogue_intake_test.py .github/workflows/site-catalogue-release.yml .github/workflows/ci.yaml && git commit -m "feat(dive-sites): take catalogue releases by a reviewed PR"`.

### Task 11: Remove the moved pipeline from the app

**Files (app repository):**
- Delete: `scripts/site_catalogue/` (all), `scripts/site_catalogue_format.py`, `scripts/site_catalogue_format_test.py`, `scripts/site_country_resolver.py`, `scripts/site_country_resolver_test.py`, `scripts/curated_sites.py`, `scripts/curated_sites_test.py`, `scripts/dive_sites_curated.json`
- Create: `scripts/site_catalogue/research/sites.json` as a pointer: `{"moved_to": "https://github.com/submersion-app/site-catalogue/blob/main/research/sites.json", "note": "The researched dive site evidence lives in the site catalogue repository."}`
- Modify: `.github/workflows/ci.yaml` (drop the moved tests from `script-tests` and the guard list, and the "Check researched dive site evidence" step), `.gitignore` (drop `scripts/.site_catalogue_cache/`), `README.md` (open-only section points to the release asset `site_catalogue_open.json`), `lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart` (repository and file paths: `https://github.com/submersion-app/site-catalogue`, `curated/dive_sites_curated.json`, `research/sites.json`) and its test, `test/tool/demo_data/destinations_test.dart` and `tool/demo_data/src/story/destinations.dart` (curated New Jersey depths from the asset's `curated_nj_*` records' `max_depth_m`), `scripts/dive_site_harvester.py` and `scripts/requirements.txt` (comments naming the new repository)

- [ ] **Step 1:** Update `site_catalogue_attribution_test.dart` to expect the new repository and paths, and `destinations_test.dart` to read `assets/data/site_catalogue.json`. Run both. Expected: FAIL.
- [ ] **Step 2:** Make the Dart and demo-data changes. Run both. Expected: PASS.
- [ ] **Step 3:** Delete the moved files, write the pointer, edit CI, `.gitignore`, README and the two comments.
- [ ] **Step 4:** Run `git grep -n "site_catalogue/\|site_catalogue_format\|dive_sites_curated\|curated_sites.py\|site_country_resolver"` and confirm every remaining hit is the pointer, a `docs/design/` record, or the new repository's URL (acceptance 8).
- [ ] **Step 5:** Run `flutter test test/features/dive_sites test/tool/demo_data test/architecture test/shared`, `flutter analyze`, `python3.14 scripts/check_docs_links.py`. Expected: all pass.
- [ ] **Step 6: Commit** with explicit paths (`git rm` the deleted ones, then `git add` the edited and created ones, chained with `&&`), message `chore(dive-sites): the site catalogue pipeline now lives in its own repository`. Check `git show --stat HEAD` lists every path.

## Part C: research at scale (catalogue repository)

### Task 12: Domain kinds, `review.by`, recorded checks and the auto-tier rule

**Files (catalogue repository):**
- Modify: `research/evidence.py` (`load_domains`, `DomainLists`), `research/check.py`, `research/domains.json`, `research/README.md`, `research/check_test.py`, `research/evidence_test.py`
- Create: `research/auto_tier.py`, `research/auto_tier_test.py`

**Interfaces:**
- Produces:
  - `DOMAIN_KINDS = ("official", "operator", "press", "club", "other")` in `evidence.py`.
  - `domains.json` counting entries become `{"kind": <DOMAIN_KINDS>, "reason": str}`; `cite_only` and `never` stay strings. `load_domains` raises `ValueError` for a counting entry without a valid `kind`.
  - `DomainLists.kind_for(url: str) -> str | None`: the counting kind of a page's domain, else None.
  - `ENTRY_FIELDS` gains `second_pass` and `checks`; `review` may hold `by` in `("auto", "maintainer")` (absent reads as maintainer); `named` may hold `osm` (`"node/<id>"`, `"way/<id>"` or `"relation/<id>"`).
  - `second_pass`: `{"date": iso, "agrees": bool, "facts": <sha256 hex>}`.
  - `checks`: `[{"name": "in_water" | "in_place" | "copied_point", "passed": bool, "date": iso, "osm": [str, ...]}]`.
  - `facts_hash(entry: dict) -> str` in `auto_tier.py`: sha256 of `json.dumps(..., sort_keys=True, separators=(",", ":"))` of the entry without `review`, `second_pass`, `checks` and `note`.
  - `auto_tier_problems(checked: CheckedEntry, domains: DomainLists) -> list[str]`: empty when every condition of spec section 6 holds: route `confirmed`, or `stated` from a source whose `kind_for` is `official` or `operator`; `second_pass.agrees` and `second_pass.facts == facts_hash(entry)`; all three checks present and passed; no `neighbour_near` flag.
  - `check.py`: an entry whose `review.by == "auto"` and whose `auto_tier_problems` is non-empty fails rule `auto_tier`, one finding per problem.

- [ ] **Step 1:** Write a one-off migration (not committed) that proposes each counting domain's kind from its reason's prefix (`official:` to `official`; `first-hand:` naming an operator, resort, liveaboard or charter to `operator`; `first-hand:` naming a club or school, and `club write-up:` to `club`; `dive press:` to `press`; anything else `other`), print the proposals, and have the maintainer confirm them before writing `domains.json`.
- [ ] **Step 2: Write the failing tests:**

```python
def test_auto_needs_an_official_or_operator_figure(self):
    entry = _stated_entry(domain_kind="press", by="auto")
    self.assertIn("auto_tier", _rules(check_one(entry)))

def test_auto_refuses_a_map_read_entry(self):  # acceptance 6
    self.assertIn("auto_tier", _rules(check_one(_map_entry(by="auto"))))

def test_auto_refuses_missing_checks_or_second_pass(self):
    self.assertIn("auto_tier", _rules(check_one(_stated_entry(by="auto", checks=None))))
    self.assertIn("auto_tier", _rules(check_one(_stated_entry(by="auto", second_pass=None))))

def test_auto_refuses_facts_edited_after_the_second_pass(self):  # Review Focus 1
    entry = _auto_entry()
    entry["position"]["sources"][0]["lat"] = -8.3
    self.assertIn("auto_tier", _rules(check_one(entry)))

def test_a_qualifying_entry_passes_as_auto(self):
    self.assertEqual(_rules(check_one(_auto_entry())), set())

def test_counting_domain_needs_a_kind(self):
    with self.assertRaises(ValueError):
        evidence.load_domains(_write({"counting": {"x.com": {"reason": "r"}}}))
```

- [ ] **Step 3:** Run `python3.14 pipeline/run_tests.py`. Expected: the new tests FAIL.
- [ ] **Step 4:** Implement; update the README's entry format and rules for `kind`, `review.by`, `second_pass`, `checks` and `named.osm`.
- [ ] **Step 5:** Run `python3.14 pipeline/run_tests.py` and `python3.14 research/check.py`. Expected: PASS; the 57 existing entries (no `by`, read as maintainer) still pass.
- [ ] **Step 6: Commit** `git add research/evidence.py research/check.py research/domains.json research/README.md research/auto_tier.py research/auto_tier_test.py research/check_test.py research/evidence_test.py && git commit -m "feat: domain kinds and an auto tier the checker enforces"`.

### Task 13: Machine checks

**Files (catalogue repository):**
- Create: `research/machine_checks.py`, `research/machine_checks_test.py`, `research/fixtures/` (small saved Overpass answers)

**Interfaces:**
- Produces:
  - `CheckResult(name: str, passed: bool, osm: list[str], detail: str)`; `as_fact(result: CheckResult, today: date) -> dict` in the `checks` shape of Task 12.
  - `in_water(lat, lon, *, shore: bool, overpass=query) -> CheckResult`: passes when the point is inside no land polygon (`natural=island`, `natural=islet`, `place=island`, or land closed by `natural=coastline`) within 2 km, or, when `shore`, lies within 100 m of a `natural=coastline` way.
  - `in_place(lat, lon, osm_ref: str, *, overpass=query) -> CheckResult`: passes when the point lies within the feature's bounding box grown by 2 km.
  - `copied_point(lat, lon, *, overpass=query) -> CheckResult`: fails when an OSM node tagged `tourism`, `amenity`, `place` or `shop` lies within 15 m; `osm` names it.
  - `query(ql: str) -> dict`: POST to `https://overpass-api.de/api/interpreter` with the harvester user agent, at most one request per second.

- [ ] **Step 1: Write the failing tests** against the fixtures: Sipadan's Barracuda Point passes `in_water`; a point on Pulau Sipadan's land fails it; a shore point 50 m off the Tulamben coastline passes with `shore=True`; Tulamben's Alam Batu figure fails `copied_point` naming the resort node; a Lembeh point passes `in_place` for the Lembeh Strait feature and fails for Sipadan's island way.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement with the injected `overpass`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** `git add research/machine_checks.py research/machine_checks_test.py research/fixtures && git commit -m "feat: water, place and copied-point checks for researched sites"`.

### Task 14: Run tooling: regions, tiers, audit, review page

**Files (catalogue repository):**
- Create: `research/runs.py`, `research/runs_test.py`, `research/regions.json` (well-known diving areas: name, lat, lon, radius km; seeded from slice 3's 101-area list in `slice3-measure.py`, which the maintainer's notes hold)
- Modify: `research/review.py`, `research/review_test.py`

**Interfaces:**
- Consumes: `check.check_entries`, `auto_tier.auto_tier_problems`.
- Produces:
  - `thin_regions(catalogue: dict, regions: list[dict], researched: set[str], limit: int) -> list[dict]`: regions ranked by dive-site records within their radius (fewest first), skipping names in `researched` (read from the headings of `research/runs/*/report.md`).
  - `tier(checked, domains) -> str`: `"waiting"` when any cited domain is on no list, else `"auto"` when `auto_tier_problems` is empty, else `"maintainer"`.
  - `audit_sample(auto_ids: list[str], seed: str) -> list[str]`: 10 percent, at least min(5, len), at most 30, drawn with `random.Random(seed)`; the seed is the run folder's name, so the sample is reproducible.
  - `pause_tripped(wrong: int, sampled: int) -> bool`: `wrong / sampled > 0.05`.
  - `split_run(entries, domains) -> RunSplit(auto: list, queue: list, waiting: list)`.
  - `review.render(checked, domains, *, audit: list[str] = ())` gains a "Sample audit" section listing the sampled auto entries before the maintainer tier.

- [ ] **Step 1: Write the failing tests:**

```python
def test_audit_sample_bounds(self):
    self.assertEqual(len(runs.audit_sample([f"e{i}" for i in range(3)], "r")), 3)
    self.assertEqual(len(runs.audit_sample([f"e{i}" for i in range(40)], "r")), 5)
    self.assertEqual(len(runs.audit_sample([f"e{i}" for i in range(200)], "r")), 20)
    self.assertEqual(len(runs.audit_sample([f"e{i}" for i in range(900)], "r")), 30)
    self.assertEqual(runs.audit_sample(["a", "b"], "r"), runs.audit_sample(["a", "b"], "r"))

def test_pause_rule(self):
    self.assertFalse(runs.pause_tripped(1, 20))
    self.assertTrue(runs.pause_tripped(2, 20))

def test_an_unruled_domain_waits(self):
    split = runs.split_run([_entry_citing("new.example")], _domains())
    self.assertEqual([e["id"] for e in split.waiting], ["research_xx_a"])
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement; add the review page's audit section.
- [ ] **Step 4:** Run `python3.14 pipeline/run_tests.py`. Expected: PASS.
- [ ] **Step 5: Commit** `git add research/runs.py research/runs_test.py research/regions.json research/review.py research/review_test.py && git commit -m "feat: research run tooling: thin regions, tiers and the audit sample"`.

### Task 15: The research skill

**Files (catalogue repository):**
- Create: `.agents/skills/research-sites/SKILL.md`, `.agents/skills/research-sites/region-brief.md` (from the first batch's brief, paths updated, lead and second-pass rules added), `.agents/skills/research-sites/second-pass.md`, `research/runs/.gitkeep`

**What the skill does, in order** (each step names what it calls):
1. Ask the maintainer for the scope (region count or names) and a token ceiling.
2. `runs.thin_regions` chooses regions; create `research/runs/<YYYY-MM-DD>-<n>/`.
3. Per region, one subagent with `region-brief.md`: gather leads in memory (never written to the repository), research, write entries to the run folder, and return its report as text (subagents cannot write report files; the skill writes `report.md`). Stop starting regions once reported usage passes the ceiling.
4. Per entry, run `machine_checks` and record `checks`.
5. One fresh subagent per batch of entries with `second-pass.md`, given only each entry's cited addresses and recorded facts; record `second_pass` with `facts_hash`.
6. `runs.split_run`; write `domains-queue.md` (each unruled domain, its terms URL, the agent's proposed list and kind, the reason in the agent's words).
7. `runs.audit_sample` and `review.render(..., audit=...)` into the run folder; with the maintainer's go-ahead, open the auto PR and the queue PR, each with the run's cost report (tokens per region and per passing site).
8. After the maintainer marks the sample: `pause_tripped`; if tripped, move every auto entry of the run into the queue PR and record the pause in the run's `report.md`.

- [ ] **Step 1:** Write the three files and `.gitkeep`.
- [ ] **Step 2:** Verification (acceptance 7): with the maintainer, run the skill on one region (suggested: Roatan, whose marine park publishes positions). Expected: entries in the run folder, `checks` and `second_pass` on each, a domain queue, a review page with the audit sample, and a cost report. Fix what the run shows before committing.
- [ ] **Step 3: Commit** `git add .agents/skills/research-sites research/runs/.gitkeep && git commit -m "feat: the research-sites skill"`; the run's evidence goes through its two PRs with the maintainer's decisions.
