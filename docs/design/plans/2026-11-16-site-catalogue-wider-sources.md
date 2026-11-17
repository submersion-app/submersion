# Site catalogue wider sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let researched dive sites ship when two counting pages name them and one counting page places them (a stated figure or a point read off its own map), and keep map-placed records from blocking automatic matching.

**Architecture:** The slice 3 research pipeline (evidence file, `check.py`, `review.py`, `src_research.py`) learns a second route to a position and an existence check. A researched record placed from a map carries `"position_from": "map"` through the merge into the catalogue file; the app stores it in a new local cache column and the matcher gives such a candidate a 2 km reach and no say in the automatic pick.

**Tech Stack:** Python 3.14 (scripts, `unittest`), Dart/Flutter with Drift (local cache database), `flutter_test`.

**Spec:** `docs/design/specs/2026-11-16-site-catalogue-wider-sources-design.md` (builds on `docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md`)

## Global Constraints

- Never write the em-dash character in code, comments, docs or commit messages; no en-dash as punctuation.
- No tool or model attribution in any commit, comment or PR text.
- Files stay at 800 lines or fewer. `lib/core/database/local_cache_database.dart` is at 792: its new rung and backstop calls must fit, so the column helper lives in `lib/core/database/local_cache_site_catalogue_tables.dart`.
- Python runs as `python3.14`. Each script test file runs directly (`python3.14 path/to/x_test.py`), as CI does.
- Never run the whole flutter suite locally; run the named test files plus `test/architecture/`.
- Never run build_runner with `--build-filter`; run it unfiltered after changing a Drift table.
- Stage explicit paths; never `git add -A`.
- `FORMAT` in `scripts/site_catalogue_format.py` stays `2`.
- Distances: stated agreement 150 m (`AGREE_M`), coarse agreement 2,000 m, map-placed reach 2,000 m, review flag 500 m, shipped point within 10 m of the computed one (`MEAN_M`).
- The only allowed value of `position_from` is `"map"`, and only on `trust: researched` records.
- No new app strings or labels.

## Review Focus

1. A map-placed record near the antimeridian (Fiji, Tonga): its mean longitude must not average to 0. Pinned in Task 2 (`test_map_mean_across_the_antimeridian`).
2. `distinct_from` written on one side only, or naming an id that does not exist: the pair within 150 m must still fail. Pinned in Task 3 (`test_distinct_from_one_sided_still_fails`).
3. A slice 3 entry with two confirmed stated figures and no `named` fact must keep passing unchanged. Pinned in Task 1 (`test_confirmed_position_proves_existence`).
4. The Strict sensitivity (outer radius 500 m) must still offer a map-placed record 1.5 km away. Pinned in Task 8 (`map-placed reach is never below 2 km`).
5. Catalogue rows stored before the new column read as not map-placed. Pinned in Task 7 (v24 migration test).

---

### Task 1: Evidence shape and the existence check

**Files:**
- Modify: `scripts/site_catalogue/research/check.py` (`ENTRY_FIELDS`, `SOURCE_FIELDS`, `_all_sources`, `CheckedEntry`, new `_check_named`, `check_entries`)
- Test: `scripts/site_catalogue/research/check_test.py`

**Interfaces:**
- Produces: `CheckedEntry.route: str | None` (`"confirmed"`, `"stated"` or `"map"`, set by Task 2); `CheckedEntry.flag(rule: str, message: str) -> None` (a non-fatal finding that is not added to `left_out`); `CheckedEntry.flags -> list[Finding]` (non-fatal findings made by `flag`).
- Produces: entry fields `named` (`{"place": str, "sources": [source]}`) and `distinct_from` (list of ids); source fields `method` (`"stated"` default, or `"map"`) and `map` (address string).

- [ ] **Step 1: Write the failing tests**

Add to `check_test.py` a helper `_named(*urls)` returning `{"place": "Tulamben Bay", "sources": [{"url": u, "read": "2026-11-16"} for u in urls]}`, then:

```python
def test_named_by_two_counting_domains_passes_existence(self):
    entry = _entry(named=_named("https://opa.com/sites", "https://pressb.org/y"))
    self.assertNotIn("named_sources", _rules(_one(entry)))

def test_named_by_one_counting_domain_fails(self):
    one = _with(["position", "sources"], [dict(_A)])
    one["named"] = _named("https://opa.com/sites")
    self.assertIn("named_sources", _rules(_one(one)))

def test_named_twice_on_one_domain_fails(self):
    one = _with(["position", "sources"], [dict(_A)])
    one["named"] = _named("https://opa.com/a", "https://opa.com/b")
    self.assertIn("named_sources", _rules(_one(one)))

def test_confirmed_position_proves_existence(self):
    # Slice 3's passing entry has no `named` fact and still passes.
    self.assertTrue(_one(_entry()).ok)

def test_new_fields_are_not_free_text(self):
    entry = _entry(named=_named("https://opa.com/s", "https://pressb.org/y"),
                   distinct_from=["research_id_other"])
    entry["position"]["sources"][0].update({"method": "map", "map": "https://opa.com/m.jpg"})
    self.assertNotIn("text_field", _rules(_one(entry)))

def test_named_sources_need_read_dates(self):
    entry = _entry(named={"place": "x", "sources": [{"url": "https://opa.com/s"}]})
    self.assertIn("read_date", _rules(_one(entry)))
```

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/site_catalogue/research/check_test.py`
Expected: failures on `named_sources` not raised and `text_field` raised for `named`, `distinct_from`, `method`, `map`.

- [ ] **Step 3: Implement**

Add `"named"` and `"distinct_from"` to `ENTRY_FIELDS`; `"method"` and `"map"` to `SOURCE_FIELDS`; include `"named"` in the keys `_all_sources` walks. Add `route` and `flag()`/`flags` to `CheckedEntry`. Add `_check_named(checked, domains) -> None`, called in `check_entries` after `_check_position`: when `checked.route == "confirmed"` it passes; otherwise the `named` sources on counting domains must span at least two registrable domains (`evidence.registrable_domain`), else `checked.fail("named_sources", "two counting pages on different domains name the site")`.

- [ ] **Step 4: Run them to see them pass**

Run: `python3.14 scripts/site_catalogue/research/check_test.py`
Expected: the new tests pass. Tests that fail now because Task 2 has not changed the position rule are expected until Task 2; none other.

- [ ] **Step 5: Commit**

```bash
git add scripts/site_catalogue/research/check.py scripts/site_catalogue/research/check_test.py
git commit -m "feat(dive-sites): researched sites can prove existence by two naming pages"
```

### Task 2: Three routes to a position

**Files:**
- Modify: `scripts/site_catalogue/research/check.py` (`_check_position`; new constant `AGREE_COARSE_M = 2000.0`)
- Test: `scripts/site_catalogue/research/check_test.py`

**Interfaces:**
- Consumes: `CheckedEntry.route` (Task 1).
- Produces: `checked.route` and `checked.position` per the rules below; `checked.map_read -> bool` (`route == "map"`).

Rules (spec section 2): parse every source; only counting-domain figures count. A `method: "map"` figure must carry `map` and be on a counting domain, else `fail("position_domains", ...)`. A counting figure is *fine* when `method` is `stated` and its precision is no coarser than `COARSEST_DEG`; every other counting figure is *map-grade*. Route `confirmed`: at least two fine figures on two or more domains, all pairwise within `AGREE_M`; shipped point is their mean. Route `stated`: exactly one fine figure; shipped point is that figure. Route `map`: anything else with at least one counting figure; shipped point is the mean of every counting figure (`_mean_longitude` for longitude). No counting figure: `fail("position_sources", "a counting page places the site")`. Every counting figure must lie within `AGREE_COARSE_M` of the shipped point, else `fail("position_spread", ...)`. `position.lat/lon` must lie within `MEAN_M` of the shipped point (`position_mean`, as now). The `position_precision` failure is removed.

- [ ] **Step 1: Rewrite the slice 3 position tests that this rule changes, and add the new ones**

Change, keeping their names' intent:
- `test_one_counting_source` becomes `test_one_counting_source_is_route_stated`: one fine counting figure plus `named` by two domains, `route == "stated"`, passes.
- `test_two_sources_one_domain`: two fine figures on one domain within 150 m now give `route == "map"` (not `confirmed`).
- `test_whole_minute_figure_fails` becomes `test_whole_minute_figure_is_map_grade`: `route == "map"` when it is the only counting figure.
- `test_two_decimal_figure_fails` becomes `test_two_decimal_figure_is_map_grade`.
- `test_counting_figures_200m_apart_fail` becomes `test_counting_figures_600m_apart_are_map_read_at_their_mean`: `route == "map"`, `position` equals their mean.

Add:

```python
def test_map_figure_alone_is_route_map(self):  # with named by two domains
    self.assertEqual(_one(map_entry).route, "map")
    self.assertTrue(_one(map_entry).ok)

def test_map_figure_on_cite_only_domain_fails(self):
    self.assertIn("position_domains", _rules(_one(entry_with_dir_map)))

def test_map_figure_without_map_address_fails(self):
    self.assertIn("position_domains", _rules(_one(entry_without_map_field)))

def test_stated_and_map_3km_apart_fail_spread(self):
    self.assertIn("position_spread", _rules(_one(entry_3km)))

def test_confirmed_with_a_map_figure_1km_off_stays_confirmed(self):
    self.assertEqual(_one(entry).route, "confirmed")

def test_map_mean_across_the_antimeridian(self):
    # Map figures at 179.999 and -179.999: shipped longitude is +/-180, not 0.
    self.assertAlmostEqual(abs(_one(entry).position[1]), 180.0, places=3)
```

Each fixture is built with `_with`/`_named` from the passing entry; map sources carry `"method": "map", "map": "https://opa.com/m.jpg"` and decimal `lat`/`lon`.

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/site_catalogue/research/check_test.py`
Expected: the rewritten and new position tests fail; the Task 1 tests pass.

- [ ] **Step 3: Implement `_check_position(checked: CheckedEntry, domains) -> None` per the rules above**

- [ ] **Step 4: Run every research test**

Run: `for f in scripts/site_catalogue/research/*_test.py; do python3.14 $f || echo "FAIL $f"; done`
Expected: all pass (the review and evidence tests included).

- [ ] **Step 5: Commit**

```bash
git add scripts/site_catalogue/research/check.py scripts/site_catalogue/research/check_test.py
git commit -m "feat(dive-sites): place researched sites by a stated figure or a counting page's map"
```

### Task 3: Neighbours

**Files:**
- Modify: `scripts/site_catalogue/research/check.py` (`_check_neighbours`; new constant `FLAG_M = 500.0`)
- Test: `scripts/site_catalogue/research/check_test.py`

**Interfaces:**
- Consumes: `CheckedEntry.flag`, `CheckedEntry.map_read`.

Rules: two standing entries within `AGREE_M` fail `neighbour` unless each lists the other's id in `distinct_from`; a `note` no longer excuses them. A standing map-read entry within `FLAG_M` of another standing entry gets `flag("neighbour_near", f"{metres:.0f} m from {other_id}")`, always.

- [ ] **Step 1: Rewrite and add tests**

Rewrite `test_a_note_lets_both_stand` as `test_a_note_no_longer_lets_both_stand` (expects `neighbour`). Add `test_distinct_from_on_both_lets_both_stand`, `test_distinct_from_one_sided_still_fails`, `test_distinct_from_naming_no_entry_still_fails`, `test_map_read_entry_300m_from_another_is_flagged_not_failed` (`neighbour_near` in `_rules(checked, fatal=False)`, entry `ok`), `test_a_flag_is_not_left_out` (`checked.left_out == []`).

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/site_catalogue/research/check_test.py`
Expected: the five new or rewritten tests fail.

- [ ] **Step 3: Implement `_check_neighbours(results: list[CheckedEntry]) -> None` per the rules above**

- [ ] **Step 4: Run every research test**

Run: `for f in scripts/site_catalogue/research/*_test.py; do python3.14 $f || echo "FAIL $f"; done`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/site_catalogue/research/check.py scripts/site_catalogue/research/check_test.py
git commit -m "feat(dive-sites): name a close neighbour with distinct_from; flag map-read sites within 500 m"
```

### Task 4: `position_from` through the merge into the catalogue

**Files:**
- Modify: `scripts/site_catalogue/src_research.py` (`working_record`, `records`)
- Modify: `scripts/site_catalogue_format.py` (`to_catalogue_record`, `validate_catalogue`)
- Modify: `scripts/site_catalogue/merge.py` (`_catalogue_record`)
- Test: `scripts/site_catalogue/src_research_test.py`, `scripts/site_catalogue_format_test.py`, `scripts/site_catalogue/merge_research_test.py`

**Interfaces:**
- Consumes: `CheckedEntry.map_read` (Task 2).
- Produces: `working_record(..., position_from: str | None = None) -> dict` puts `record["position_from"]` when given; `to_catalogue_record(..., position_from: str | None = None) -> dict` writes `"position_from"` after `"trust"` when given; `validate_catalogue` reports `"{id}: position_from {value!r}"` for any value but `"map"` and `"{id}: position_from on a record that is not researched"`.

- [ ] **Step 1: Write the failing tests**

- `src_research_test.py`: `test_a_map_read_entry_forms_a_record_placed_from_a_map` (`records(...)` gives `position_from == "map"`); `test_a_stated_entry_forms_a_record_with_no_position_from` (key absent).
- `site_catalogue_format_test.py`: `test_position_from_map_on_a_researched_record_validates`; `test_position_from_on_a_verified_record_fails`; `test_position_from_with_another_value_fails`; `test_position_from_is_written_after_trust` (`list(record)[-1] == "position_from"`).
- `merge_research_test.py`: `test_a_map_read_record_keeps_position_from_in_the_catalogue` (an approved map-read entry merged; the written record has `"position_from": "map"`).

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/site_catalogue/src_research_test.py; python3.14 scripts/site_catalogue_format_test.py; python3.14 scripts/site_catalogue/merge_research_test.py`
Expected: the seven new tests fail.

- [ ] **Step 3: Implement**

`records()` passes `position_from="map" if checked.map_read else None`. `_catalogue_record` passes `position_from=record.get("position_from")` to `to_catalogue_record`.

- [ ] **Step 4: Run every catalogue script test**

Run: `for f in $(git ls-files 'scripts/site_catalogue/*_test.py' 'scripts/site_catalogue/**/*_test.py') scripts/site_catalogue_format_test.py; do python3.14 $f >/dev/null 2>&1 || echo "FAIL $f"; done`
Expected: no FAIL lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/site_catalogue/src_research.py scripts/site_catalogue/src_research_test.py scripts/site_catalogue_format.py scripts/site_catalogue_format_test.py scripts/site_catalogue/merge.py scripts/site_catalogue/merge_research_test.py
git commit -m "feat(dive-sites): carry a map-read position into the catalogue as position_from"
```

### Task 5: Review page

**Files:**
- Modify: `scripts/site_catalogue/research/review.py` (`_position_rows`, `_entry_html`)
- Test: `scripts/site_catalogue/research/review_test.py`

**Interfaces:**
- Consumes: `CheckedEntry.route`, `CheckedEntry.flags` (Tasks 1 to 3).

- [ ] **Step 1: Write the failing tests**

`test_a_map_read_entry_shows_its_map_link` (the rendered HTML contains the source's `map` address as a link); `test_the_route_is_shown` (contains `Placed by` and `map`); `test_a_flag_is_shown_and_does_not_block_approval` (contains `neighbour_near` and `Approve or reject`); `test_the_openstreetmap_link_is_at_the_shipped_point` (contains `mlat=` with the shipped latitude to 6 places).

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/site_catalogue/research/review_test.py`
Expected: the map link, route and flag tests fail; the OpenStreetMap test passes already (the link exists).

- [ ] **Step 3: Implement**

A `Placed by` row naming the route; for each `method: "map"` source a `map image` link beside the page link; each flag as a row in a non-failing style.

- [ ] **Step 4: Run it to see it pass**

Run: `python3.14 scripts/site_catalogue/research/review_test.py`
Expected: OK.

- [ ] **Step 5: Commit**

```bash
git add scripts/site_catalogue/research/review.py scripts/site_catalogue/research/review_test.py
git commit -m "feat(dive-sites): the review page shows how each researched site was placed"
```

### Task 6: Domains, procedure and the slice 3 amendment

**Files:**
- Modify: `scripts/site_catalogue/research/domains.json` (each `cite_only` reason records the directory's terms, from the spec's Constraints table; add `scubaspotadvisor.com` and `waypoints.ph` to `cite_only`)
- Modify: `scripts/site_catalogue/research/README.md` (the procedure: naming pages, the three routes, how to read a map, the terms check before a domain joins `counting`, `distinct_from`; remove "research the next thin area" for this batch)
- Modify: `docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md` (a note under decision 4 and under "No position is placed from a description" pointing to the new spec, as spec section 8 says)
- Add: `docs/design/specs/2026-11-16-site-catalogue-wider-sources-design.md` (already written; committed here)

- [ ] **Step 1: Make the edits**
- [ ] **Step 2: Verify**

Run: `python3.14 scripts/site_catalogue/research/check.py && python3.14 scripts/check_docs_links.py`
Expected: the checker passes on the (still empty) evidence file and loads `domains.json`; the docs link check passes.

- [ ] **Step 3: Commit**

```bash
git add scripts/site_catalogue/research/domains.json scripts/site_catalogue/research/README.md docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md docs/design/specs/2026-11-16-site-catalogue-wider-sources-design.md docs/design/plans/2026-11-16-site-catalogue-wider-sources.md
git commit -m "docs(dive-sites): wider sources for researched sites: design, procedure and directory terms"
```

### Task 7: The app reads and stores `position_from`

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/catalogue_site.dart` (field `positionFromMap`, constructor default `false`, `copyWith`, equality)
- Modify: `lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart` (`_site` reads `raw['position_from'] == 'map'`)
- Modify: `lib/core/database/local_cache_site_catalogue_tables.dart` (column `TextColumn get positionFrom => text().nullable()();`, the raw create SQL gains `position_from TEXT NULL`, new `kAddSiteCataloguePositionFromSql` and a top-level `Future<void> addSiteCataloguePositionFrom(GeneratedDatabase db)` that adds the column only when `pragma_table_info('site_catalogue')` lacks it)
- Modify: `lib/core/database/local_cache_database.dart` (`schemaVersion` 23 to 24; rung `if (from < 24) await addSiteCataloguePositionFrom(this);`; the same call in `beforeOpen`. To stay at 800 lines, move `_addSiteCatalogueKind` into the tables file as `addSiteCatalogueKind(GeneratedDatabase db)` in the same commit)
- Modify: `lib/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart` (write `Value(site.positionFromMap ? 'map' : null)`, read `row.positionFrom == 'map'`)
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart`, `test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart`, new `test/core/database/local_cache_migration_v24_site_catalogue_position_from_test.dart` (modelled on the v22 test)

**Interfaces:**
- Produces: `CatalogueSite.positionFromMap` (bool).

- [ ] **Step 1: Write the failing tests**

Parser: `a researched record placed from a map is read as such` (`positionFromMap` true for `"position_from": "map"`); `any other value or none reads as not placed from a map`. Storage: `positionFromMap survives a write and a read of the cache`. Migration: `v23 to v24 adds position_from and keeps the rows` (a v23 database with one catalogue row opens at v24; the row reads `positionFromMap == false`); `the column is added again by the open backstop when a colliding branch stamped v24 first`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart test/core/database/local_cache_migration_v24_site_catalogue_position_from_test.dart`
Expected: compile errors or failures naming `positionFromMap` and `position_from`.

- [ ] **Step 3: Implement, then regenerate**

Run: `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background), then confirm `wc -l lib/core/database/local_cache_database.dart` is at most 800.

- [ ] **Step 4: Run them to see them pass**

Run: the Step 2 command, then `flutter test test/core/database/ test/architecture/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/entities/catalogue_site.dart lib/features/dive_sites/data/catalogue/site_catalogue_parser.dart lib/core/database/local_cache_site_catalogue_tables.dart lib/core/database/local_cache_database.dart lib/core/database/local_cache_database.g.dart lib/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart test/features/dive_sites/data/catalogue/site_catalogue_parser_test.dart test/features/dive_sites/data/catalogue/local_site_catalogue_test.dart test/core/database/local_cache_migration_v24_site_catalogue_position_from_test.dart
git commit -m "feat(dive-sites): store whether a researched site's position was read from a map"
```

### Task 8: Matching

**Files:**
- Modify: `lib/features/dive_sites/domain/matching/match_candidate.dart` (field `isMapPlaced`, default `false`)
- Modify: `lib/features/dive_sites/domain/matching/site_matcher.dart` (`kMapPlacedReachMeters = 2000.0`; `double reachMeters(MatchCandidate candidate, MatchThresholds thresholds)` returning `max(outerRadiusMeters, kMapPlacedReachMeters)` for a map-placed candidate and `outerRadiusMeters` otherwise; `matchRanked` per the rules below)
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart` (query `near` with `max(outerRadiusMeters, kMapPlacedReachMeters)`; build candidates with `isMapPlaced: b.isResearched && b.positionFromMap`; filter `views` with `reachMeters` instead of `outerRadiusMeters`. The auto-match, bare-site and suggested lists are all built from `views`, so this one filter gives each the 2 km reach)
- Test: `test/features/dive_sites/domain/matching/site_matcher_test.dart`, `test/features/dive_sites/domain/matching/site_matching_service_test.dart`

**Interfaces:**
- Consumes: `CatalogueSite.positionFromMap` (Task 7).

Rules for `matchRanked`: `inRange` keeps a candidate within `reachMeters(candidate, thresholds)`. Map-placed candidates are left out of `innerExisting`, `innerAny` and `innerSites` (so never in the pool or the runner-up rule) and out of the `siteCloseBehind` check. An empty pool with anything in range is `Suggested(inRange)`, as today.

- [ ] **Step 1: Write the failing tests**

In `site_matcher_test.dart`, at `SiteMatchSensitivity.balanced.thresholds`:
- `a lone map-placed record 1.5 km away is suggested` (`Suggested` containing it).
- `a verified site 100 m away is auto-matched past a map-placed record 120 m away`.
- `a verified site 140 m away is auto-matched past a map-placed record 80 m away`.
- `a stated researched record 80 m away still blocks a verified site 140 m away` (`Suggested`, as today).
- `a map-placed record does not count as a dive site close behind a register record`.
- `map-placed reach is never below 2 km` (at `strict`, a lone map-placed record 1.5 km away is `Suggested`).

In `site_matching_service_test.dart`: `a dive auto-matched to a verified site lists a map-placed record 1.5 km away among its candidates`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_sites/domain/matching/site_matcher_test.dart test/features/dive_sites/domain/matching/site_matching_service_test.dart`
Expected: the seven new tests fail.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run the matching tests and the dive site layer**

Run: `flutter test test/features/dive_sites/ test/architecture/` and `flutter analyze lib/features/dive_sites test/features/dive_sites lib/core/database`
Expected: all pass, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/matching/match_candidate.dart lib/features/dive_sites/domain/matching/site_matcher.dart lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/domain/matching/site_matcher_test.dart test/features/dive_sites/domain/matching/site_matching_service_test.dart
git commit -m "feat(dive-sites): a map-placed researched site is offered from 2 km and never blocks an automatic match"
```

### Task 9: Whole-branch check

- [ ] **Step 1:** `dart format .` and confirm no change; `flutter analyze` on the whole repository (a scoped analyze misses cross-file breaks).
- [ ] **Step 2:** every catalogue script test (Task 4 Step 4 command) and `python3.14 scripts/site_catalogue/research/check.py`.
- [ ] **Step 3:** `flutter test test/features/dive_sites/ test/core/database/ test/architecture/ test/shared/`.
- [ ] **Step 4:** `grep -rnP "\x{2014}" $(git diff --name-only origin/main)` returns nothing (no em-dash in any changed file).
