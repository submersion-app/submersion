# Researched catalogue sites (slice 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a pilot of researched dive site records with cited evidence, a checker that enforces the research rules in CI, a "Not verified" mark on every surface where a diver chooses a built-in site, GPS matching that never preselects a researched record, and withdrawals that tell divers.

**Architecture:** Researched sites live as evidence entries in `scripts/site_catalogue/research/sites.json`. A standard-library checker enforces the rules; a source module turns approved entries into working records that the slice 2 merge places, overlaps and writes with `trust: researched`. The app reads the trust level it already stores, adds one shared label widget, one matcher rule, and a withdrawn list kept in the existing `site_catalogue_meta` table.

**Tech Stack:** Python 3 (standard library), Flutter/Dart, Riverpod, Drift (local cache), ARB localisation.

**Spec:** `docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md` (approved 2026-11-15). Read it with this plan; section numbers below are the spec's.

## Global Constraints

- No em-dash or en-dash used as punctuation anywhere (code, comments, docs, commits, PR text).
- No mention of Claude, Claude Code or Anthropic in any commit, PR, comment or file.
- Catalogue format stays 2; the only new metadata entry is `withdrawn`.
- No local cache schema change; the withdrawn list is the `site_catalogue_meta` key `withdrawn`.
- `kSiteCatalogueImportRevision` moves from 3 to 4.
- Checker, source module and review page: standard library Python only, offline; tests join the CI step "Run Python guard tests with coverage" with modules in its `guards=` coverage list.
- Any script fetch sends `dive-site-harvester/1.0` and nothing naming a person, address or the project.
- Every new string in all 11 ARB files (`lib/l10n/arb/app_*.arb`), then `flutter gen-l10n`.
- Files under 800 lines; `ListTile.trailing` guard; `dart format .` before each commit; `python3.14` locally.
- Values pinned by the spec: 150 m position agreement; precision finer than 0.001 degree, 0.1 minute or 1 second; depth spread rule "more than both 5 m and a quarter of the deepest"; ids `research_<cc>_<slug>`; source key `research`, name and credit "Submersion site research", licence `ODbL-1.0`; reasons `position`, `not_a_site`, `duplicate`, `other`.
- The label text is "Not verified"; the sentence is "Gathered from published dive guides, not from a survey. Check the position locally before you rely on it."
- No researched record ships without the maintainer's approval on the review page (Task 12 stops for it).
- Never run the whole Flutter suite locally: affected tests plus `test/architecture/`, `test/shared/`, `test/l10n/`.

## Review Focus

1. A position written with both a minus sign and a hemisphere letter ("-8 16.48 S"): the parser rejects it rather than flipping the sign twice. Test in Task 2.
2. A catalogue that lists an id as withdrawn and also ships a record with that id: `validate_catalogue` fails. Test in Task 1.
3. A diver's site linked to a withdrawn id on a device whose catalogue import has not finished: the header shows nothing and does not throw. Test in Task 9.
4. A dive 30 m from the diver's own site and 20 m from a researched record: the diver's own site is still the `AutoMatch` (existing precedence unchanged). Test in Task 6.
5. A picker row for a researched record with a long name at text scale 2.0 on a 320-wide screen: no overflow, the label stays visible. Test in Task 8.

---

### Task 1: Trust, the `research` source and the withdrawn list in the format

**Files:**
- Modify: `scripts/site_catalogue_format.py` (`SOURCES`, `to_catalogue_record`, `validate_catalogue`, `write_catalogue`)
- Test: `scripts/site_catalogue_format_test.py`

**Interfaces:**
- Produces: `to_catalogue_record(legacy, *, source, source_ref, country_code, country, kind="site", trust="verified") -> dict`; `RESEARCHED_SOURCES = ("curated", "research")`; `WITHDRAWAL_REASONS = ("position", "not_a_site", "duplicate", "other")`; `write_catalogue(directory, records, generated_at, *, open_only=False, withdrawn: dict[str, dict] | None = None)`. `withdrawn` maps id to `{"reason", "date", "replaced_by"?}` and is written as `metadata.withdrawn` (left out when empty).

- [ ] **Step 1: Write failing tests**: `test_trust_is_written_as_given` (`trust="researched"` lands in the record; default stays `verified`; any value outside `TRUST_LEVELS` raises `ValueError`); `test_research_source_declared` (`SOURCES["research"] == {"name": "Submersion site research", "licence": "ODbL-1.0", "licence_url": _ODBL, "credit": "Submersion site research"}`, not own-terms, named in `catalogue_notice()`); `test_withdrawn_written_to_metadata` (two ids round-trip; empty dict leaves the key out); `test_validate_rejects_withdrawn_id_still_shipped` (Review Focus 2); `test_validate_rejects_bad_withdrawal` (unknown reason, missing date, `replaced_by` naming an id not in the file); `test_validate_rejects_researched_trust_outside_researched_sources` (an `osm` record written `researched` fails; a `research` or `curated` record written `verified` fails).
- [ ] **Step 2: Run** `python3.14 scripts/site_catalogue_format_test.py`. Expected: the new tests fail.
- [ ] **Step 3: Implement** the four changes. The trust rule in `validate_catalogue`: a record's trust is `researched` exactly when its source is in `RESEARCHED_SOURCES`.
- [ ] **Step 4: Run** the format test, `scripts/curated_sites_test.py` and `scripts/site_catalogue/merge_test.py`. Expected: format tests pass; the merge test fails on the curated trust rule (fixed in Task 4, leave it).
- [ ] **Step 5: Commit** `feat(dive-sites): researched trust, the research source and withdrawals in the catalogue format`.

### Task 2: Evidence parsing (positions, depths, domains)

**Files:**
- Create: `scripts/site_catalogue/research/__init__.py` (empty), `scripts/site_catalogue/research/evidence.py`
- Test: `scripts/site_catalogue/research/evidence_test.py`

**Interfaces:**
- Produces:
  - `parse_coordinate(text: str | float, axis: str) -> tuple[float, float]`: returns (decimal degrees, precision in degrees). `axis` is `"lat"` or `"lon"`. Accepts a number, decimal degrees as text, `D M S H`, `D M.mmm H`, with or without degree, minute and second marks. Raises `ValueError` on a sign plus a hemisphere letter, out-of-range values, or a hemisphere letter of the wrong axis.
  - `registrable_domain(url: str) -> str`: lower-cased host without `www.`, reduced to its last two labels, or three when the second-last is one of `co, com, org, net, gov, ac, edu` and the last is two letters (`divers.co.uk` stays three labels).
  - `load_domains(path) -> DomainLists`: a dataclass with `counting`, `cite_only`, `never` (dicts of domain to reason) and `kind_of(url) -> str | None` returning `"counting"`, `"cite_only"`, `"never"` or None. A subdomain takes its parent's list.
  - `metres_between(lat1, lon1, lat2, lon2) -> float` (reuse `records.km` times 1000).
  - `HAZARD_SENTENCES: dict[str, str]`: the nine codes of spec section 3 in table order with the exact sentences.

- [ ] **Step 1: Write failing tests**: `test_decimal_degrees_precision` (`"-8.27391"` gives precision 0.00001); `test_dms` (`"8 16 28.80 S"` gives -8.274667 within 1e-6, precision 1/36000); `test_degrees_decimal_minutes` (`"4 06.9 N"` gives precision 0.1/60); `test_whole_minutes_precision` (`"4 6 N"` gives 1/60); `test_sign_and_letter_rejected` (Review Focus 1); `test_wrong_axis_letter_rejected` (`"115 35 E"` as lat raises); `test_registrable_domain` (`https://www.padi.com/ja/x` gives `padi.com`; `https://a.divers.co.uk/x` gives `divers.co.uk`); `test_domain_lists` (subdomain takes parent; a domain on two lists raises `ValueError` at load); `test_hazard_sentences_order` (keys in spec order, values exact).
- [ ] **Step 2: Run** `python3.14 scripts/site_catalogue/research/evidence_test.py`. Expected: import error.
- [ ] **Step 3: Implement** in `evidence.py`.
- [ ] **Step 4: Run** the test. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): read researched positions, domains and hazards`.

### Task 3: The checker

**Files:**
- Create: `scripts/site_catalogue/research/check.py`
- Test: `scripts/site_catalogue/research/check_test.py`

**Interfaces:**
- Consumes: Task 2's functions; `site_catalogue_format.SITE_TYPE_IDS`, `ENTRY_METHODS`.
- Produces:
  - `Finding(entry_id: str, rule: str, message: str, fatal: bool)`.
  - `CheckedEntry(entry: dict, findings: list[Finding], position: tuple[float, float] | None, min_depth: float | None, max_depth: float | None, types: list[str], entries: list[str], hazards: list[str], left_out: list[str])`; `ok` property is true when no fatal finding.
  - `check_entries(entries: list[dict], domains: DomainLists, *, today: date) -> list[CheckedEntry]`.
  - `main(argv) -> int`: `check.py [--file PATH] [--domains PATH] [--review OUT]`; prints the report of spec section 4; exits 1 on any fatal finding in any entry, whatever its review state.
  - Rule names (used by tests and the review page): `id_prefix`, `id_repeat`, `shape`, `vocabulary`, `read_date`, `unknown_domain`, `never_source`, `position_sources`, `position_domains`, `position_precision`, `position_spread`, `position_mean`, `depth_by_hand`, `depth_order`, `fact_unsourced`, `text_field`, `name_length`, `neighbour`.

- [ ] **Step 1: Write failing tests**, one per row of spec section 4 and its Testing list, each on a minimal in-memory entry built by a `_entry(**overrides)` helper that passes by default: `test_passing_entry`; `test_one_counting_source`; `test_two_sources_one_domain`; `test_whole_minute_figure_fails`; `test_counting_figures_200m_apart_fail`; `test_cite_only_2km_off_passes` (and is not used in the mean); `test_never_source_fails`; `test_unknown_domain_fails`; `test_mean_more_than_10m_off_fails`; `test_depth_spread` (32 and 40 give max 40; 8 and 15 give none and a non-fatal `left_out` note); `test_min_deeper_than_max_fails`; `test_depth_written_by_hand_fails` (an entry with a top-level `max_depth_m` number); `test_feet_converted` (`{"value": 100, "unit": "ft"}` gives 30.48); `test_contradicted_type_left_out` (a `contradicts: true` counting source removes the value, non-fatal); `test_value_without_counting_source_fails`; `test_free_text_field_fails` (a `quote` key on a source); `test_name_over_60_fails`; `test_id_prefix_and_repeat`; `test_future_read_date_fails`; `test_two_entries_within_150m_fail_without_note`; `test_withdrawn_entry_still_checked`.
- [ ] **Step 2: Run** `python3.14 scripts/site_catalogue/research/check_test.py`. Expected: import error.
- [ ] **Step 3: Implement** `check.py`. The shipped position is the mean of the counting figures; the depth rule exactly as spec section 4.
- [ ] **Step 4: Run** the test. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): a checker for researched site evidence`.

### Task 4: Researched records in the merge

**Files:**
- Create: `scripts/site_catalogue/src_research.py`
- Modify: `scripts/site_catalogue/merge.py` (`build`, `_catalogue_record`, `main`, `_print_report`), `scripts/site_catalogue/overlap.py` (`RANK`, `same_site`/`resolve` for `research`)
- Test: `scripts/site_catalogue/src_research_test.py`, `scripts/site_catalogue/merge_test.py`, `scripts/site_catalogue/overlap_test.py`

**Interfaces:**
- Consumes: Task 1 (`trust`, `withdrawn`), Task 3 (`check_entries`, `CheckedEntry`).
- Produces:
  - `src_research.RESEARCH_FILE` (`scripts/site_catalogue/research/sites.json`), `src_research.DOMAINS_FILE`.
  - `src_research.records(entries, domains, *, today) -> tuple[list[dict], Counter]`: working records for entries that are `review.state == "approved"`, not withdrawn and `ok`; the counter holds `failed`, `pending`, `rejected`, `withdrawn`.
  - `src_research.withdrawals(entries, curated_withdrawn: list[dict]) -> dict[str, dict]`.
  - `src_research.describe(entries: list[str], types: list[str], min_depth, max_depth) -> str | None`: the generated line ("Shore dive to a wreck, 5 to 30 m.", "Boat dive on a wall, to 40 m.", "Reef dive.").
  - `src_research.source_ref(entry_id) -> str`.
  - `merge.build(snapshots, curated, places, research=None, previous_ids=None)`: `research` is the loaded evidence document (`{"sites": [...], "withdrawn_curated": [...]}`); `previous_ids` the ids of the file being replaced.

- [ ] **Step 1: Write failing tests**:
  - `src_research_test`: only approved, ok, unwithdrawn entries form records; `source == "research"`, `kind == "site"`; hazards joined in table order; `describe` for the three spec examples and for nothing known (None); `source_ref` is a GitHub address naming the id; `withdrawals` cumulative over sites and curated.
  - `overlap_test`: `test_research_left_out_beside_dive_site_within_150m` (any source, any name); `test_research_left_out_same_name_within_2km`; `test_research_beside_register_150m_kept` (a register record 120 m off with another name); `test_research_gives_and_takes_nothing`; `test_curated_overlap_unchanged` (an existing curated case still takes a loser's depth).
  - `merge_test`: `test_curated_written_researched`; `test_research_written_researched`; `test_other_sources_verified`; `test_shipped_research_id_lost_to_overlap_fails` (previous ids hold it, now left out, no withdrawal: `build` raises naming id and winner); `test_withdrawn_research_id_lost_to_overlap_passes`; `test_country_mismatch_fails`; `test_unplaceable_point_takes_entry_code`; `test_withdrawn_curated_left_out_and_listed`; `test_report_research_line`; `test_withdrawn_in_metadata`.
- [ ] **Step 2: Run** the three test files. Expected: the new tests fail.
- [ ] **Step 3: Implement.** `research` ranks last in `RANK`; in `resolve`, a `research` record that meets any other record by `same_site`, or any `kind == "site"` record within 0.15 km, is the loser and passes nothing either way. `_catalogue_record` passes `trust="researched"` for `curated` and `research`. `main` loads the evidence file and domains every run (no `--without` for it) and reads `previous_ids` from the existing file.
- [ ] **Step 4: Run** all `scripts/site_catalogue/*_test.py`, `scripts/site_catalogue/research/*_test.py`, `scripts/site_catalogue_format_test.py`, `scripts/curated_sites_test.py`. Expected: all pass, including Task 1's leftover merge failure.
- [ ] **Step 5: Commit** `feat(dive-sites): the merge ships approved researched sites`.

### Task 5: The review page, the procedure and CI

**Files:**
- Create: `scripts/site_catalogue/research/review.py`, `scripts/site_catalogue/research/review_test.py`, `scripts/site_catalogue/research/README.md`, `scripts/site_catalogue/research/domains.json`, `scripts/site_catalogue/research/sites.json` (`{"sites": [], "withdrawn_curated": []}`)
- Modify: `.github/workflows/ci.yaml` (coverage `guards=` list and the test list in "Run Python guard tests with coverage"; one step that runs `python3 scripts/site_catalogue/research/check.py`)

**Interfaces:**
- Consumes: Task 3's `CheckedEntry`, `Finding`.
- Produces: `review.render(checked: list[CheckedEntry], domains: DomainLists) -> str` (one self-contained HTML document); `check.py --review OUT` writes it.

- [ ] **Step 1: Write failing tests**: `test_offline_html` (no `<script src`, no `http` in any `<link>` or `<img>`); `test_one_row_per_entry_grouped_by_area`; `test_failing_entry_shows_rule_and_no_approval_mark`; `test_source_distance_from_point` (a figure 1,520 m off shows "1,520 m" and "cite only"); `test_osm_map_link` (`https://www.openstreetmap.org/?mlat=..&mlon=..#map=17/..`); `test_ships_as_line`; `test_names_escaped` (`<b>` in a name is escaped).
- [ ] **Step 2: Run** `python3.14 scripts/site_catalogue/research/review_test.py`. Expected: import error.
- [ ] **Step 3: Implement** `review.py`; write `README.md` (the seven steps of spec section 1, the independence guidance, the page classes of decision 3, the withdrawal steps of section 6, "no page text in any field"); seed `domains.json` with the recon classes (`padi.com`, `ssi`'s `divessi.com`, `diveplannerpro.com`, `zentacle.com`, `divebuddy.com`, `yachtway.com`, `aroundus.com`, `sygic.com` cite-only; `wrecksite.eu`, `wannadive.net`, `wikivoyage.org`, `diveboard.com` never); wire CI.
- [ ] **Step 4: Run** the review test and `python3.14 scripts/site_catalogue/research/check.py`. Expected: pass; checker reports 0 entries and exits 0.
- [ ] **Step 5: Commit** `feat(dive-sites): research procedure, review page and CI check`.

### Task 6: GPS matching never preselects a researched record

**Files:**
- Modify: `lib/features/dive_sites/domain/matching/match_candidate.dart`, `lib/features/dive_sites/domain/matching/site_matcher.dart`, `lib/features/dive_sites/data/services/site_matching_service.dart:256-263`
- Test: `test/features/dive_sites/domain/matching/site_matcher_test.dart`, the service's existing test file

**Interfaces:**
- Produces: `MatchCandidate.isResearched` (bool, default false); `MatchCandidateView.isResearched` for the review page (Task 8).

- [ ] **Step 1: Write failing tests**: `lone researched record inside the inner radius is suggested, not matched` (40 m, nothing else); `verified dive site at 40 m beats researched at 400 m`; `researched record close behind a verified one blocks the automatic pick` (40 m and 60 m with a 50 m margin: `Suggested`); Review Focus 4; in the service test, a bundled record with `trust: researched` yields a candidate with `isResearched` true and a view with `isResearched` true.
- [ ] **Step 2: Run** `flutter test test/features/dive_sites/domain/matching/site_matcher_test.dart`. Expected: compile error on `isResearched`.
- [ ] **Step 3: Implement**: after choosing `nearest` from the pool, return `Suggested(inRange)` when `nearest.candidate.isResearched`.
- [ ] **Step 4: Run** the matcher and service tests. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): GPS matching offers researched sites but never picks one`.

### Task 7: The withdrawn list in the app

**Files:**
- Create: `lib/features/dive_sites/domain/entities/catalogue_withdrawal.dart`
- Modify: `site_catalogue_parser.dart` (`ParsedSiteCatalogue.withdrawn`), `site_catalogue_row_mapper.dart` (`SiteCatalogueRows.withdrawn`, `encodeCatalogueWithdrawals`, `decodeCatalogueWithdrawals`), `site_catalogue_importer.dart` (`kSiteCatalogueMetaWithdrawn = 'withdrawn'`, revision 4, write the key), the `SiteCatalogue` interface and `local_site_catalogue.dart`, every `SiteCatalogue` fake in `test/` (`withdrawal` answers null by default), `site_catalogue_providers.dart`
- Test: `site_catalogue_parser_test.dart`, `site_catalogue_importer_test.dart`, `local_site_catalogue_test.dart`

**Interfaces:**
- Produces: `enum CatalogueWithdrawalReason { position, notASite, duplicate, other }`; `class CatalogueWithdrawal extends Equatable { final CatalogueWithdrawalReason reason; final String date; final String? replacedBy; }` (an unknown reason string reads as `other`); `Future<CatalogueWithdrawal?> SiteCatalogue.withdrawal(String id)`; `catalogueWithdrawalProvider = FutureProvider.family<CatalogueWithdrawal?, String>` watching `siteCatalogueRevisionProvider` as `catalogueSiteProvider` does.

- [ ] **Step 1: Write failing tests**: parser reads two withdrawals and an unknown reason as `other`, and none from a file without the key; the importer writes `withdrawn` beside `sources` (an empty list for a file without it) and re-imports when only the revision changed; `withdrawal(id)` over a real local cache database answers the entry and null for an unlisted id and null when the database is not open.
- [ ] **Step 2: Run** the three tests. Expected: compile errors.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three tests and `flutter analyze`. Expected: pass, no issues.
- [ ] **Step 5: Commit** `feat(dive-sites): the app reads withdrawn built-in records`.

### Task 8: The "Not verified" label on every surface

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/not_verified_label.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (keys `diveSites_catalogue_notVerified` "Not verified", `diveSites_catalogue_notVerifiedExplanation` with the spec's sentence, `diveSites_catalogue_notVerifiedSemantics` "{name}, not verified"); `site_picker/catalogue_site_tile.dart`; `built_in_site_info_card.dart`; `catalogue_page/catalogue_site_header.dart`; `catalogue_page/catalogue_source_card.dart`; `catalogue_import_site_card.dart`; the gap-fill review row in `pages/catalogue_gap_review_page.dart` (or its row widget) and `catalogue_gap_comparison_sheet.dart`; the candidate row in `pages/site_match_review_page.dart`
- Test: one test per surface in its existing test file (`catalogue_site_tile_test`, `built_in_site_info_card_test`, `catalogue_source_card_test`, a new `catalogue_site_header_test`, a new `catalogue_import_site_card_test`, `catalogue_gap_review_page_test`, `catalogue_gap_comparison_sheet_test`, `site_match_review_page_test`), plus `not_verified_label_test.dart`

**Interfaces:**
- Consumes: `CatalogueSite.trust`, `MatchCandidateView.isResearched` (Task 6).
- Produces: `NotVerifiedLabel({Key? key})`: a small outlined chip, theme `colorScheme.outline` border and `onSurfaceVariant` text, `labelSmall`, no icon, excluded from semantics (the row's own semantics carry "not verified"); `bool isResearched(CatalogueSite site)`.

- [ ] **Step 1: Write failing tests**: per surface, `shows Not verified for a researched record` and `shows nothing for a verified record`; the sentence on the info card, the source card and the comparison only; the tile's semantics label reads "<name>, not verified"; Review Focus 5 on the tile; the label renders in light and dark themes.
- [ ] **Step 2: Run** the affected test files. Expected: fail.
- [ ] **Step 3: Implement**; add the strings to all 11 ARB files (translated), run `flutter gen-l10n`.
- [ ] **Step 4: Run** the affected tests, `test/l10n/`, `test/shared/`, `test/architecture/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): mark researched built-in sites "Not verified"`.

### Task 9: The withdrawal line on a diver's site

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_detail_header.dart` (`_CatalogueLine`), 11 ARB files (`diveSites_catalogue_withdrawn` "Built-in record withdrawn.", `diveSites_catalogue_withdrawnBecause` "Built-in record withdrawn: {reason}.", `diveSites_catalogue_withdrawnReasonPosition` "its position was wrong", `diveSites_catalogue_withdrawnReasonNotASite` "it is not a dive site", `diveSites_catalogue_withdrawnReasonDuplicate` "it listed a site twice", `diveSites_catalogue_withdrawnReplacement` "See the corrected record")
- Test: `test/features/dive_sites/presentation/widgets/site_detail_header_test.dart`

**Interfaces:**
- Consumes: `catalogueWithdrawalProvider` (Task 7).

- [ ] **Step 1: Write failing tests**: one per reason, with and without `replacedBy`; tapping the replacement link pushes `/sites/catalogue/<id>`; a removed record that is not withdrawn shows nothing; a record still present shows the credit as before; Review Focus 3 (catalogue not imported: nothing, no exception).
- [ ] **Step 2: Run** the header test. Expected: fail.
- [ ] **Step 3: Implement**; strings in all 11 ARB files.
- [ ] **Step 4: Run** the header test, `site_detail_page_header_test`, `test/l10n/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): a diver's site says when its built-in record was withdrawn`.

### Task 10: Credits

**Files:**
- Modify: `lib/features/dive_sites/data/catalogue/site_catalogue_attribution.dart`, `docs/user/dive-sites.md`
- Test: `test/features/dive_sites/data/catalogue/site_catalogue_attribution_test.dart`

- [ ] **Step 1: Write failing tests**: the licence text names "Submersion site research" and carries the spec section 7 sentence (researched and curated records gathered from published dive guides, marked "Not verified", researched records cite their pages in the repository).
- [ ] **Step 2: Run** the attribution test. Expected: fail.
- [ ] **Step 3: Implement**; describe the mark and withdrawals in `docs/user/dive-sites.md`.
- [ ] **Step 4: Run** the attribution test. Expected: pass.
- [ ] **Step 5: Commit** `docs(dive-sites): credit researched sites`.

### Task 11: Regenerate the catalogue with no research yet

**Files:**
- Modify: `assets/data/site_catalogue.json`, `assets/data/site_catalogue.version`, `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart`

- [ ] **Step 1: Copy snapshots** from `.claude/worktrees/video-scrubber-drag-83af51/scripts/.site_catalogue_cache` into this worktree's `scripts/.site_catalogue_cache` (git-ignored). Run the merge into a scratch directory and diff against the shipped file: the only differences must be the 55 curated records' trust, the `research` source not yet declared, and `generated_at`. Anything else stops the task; report it.
- [ ] **Step 2: Write failing asset tests**: every curated record is `researched`; every other record is `verified`; every `research` record (none yet) passes acceptance 2.
- [ ] **Step 3: Run** the merge into `assets/data`.
- [ ] **Step 4: Run** the asset test, the importer test, `test/tool/demo_data/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): curated sites are researched, not verified`.

### Task 12: Research the pilot batch (stops for the maintainer)

**Files:**
- Modify: `scripts/site_catalogue/research/sites.json`, `scripts/site_catalogue/research/domains.json`

- [ ] **Step 1: Research** Tulamben, Sipadan (with Mabul and Kapalai) and the Farne Islands by `README.md`, about ten candidates each, every entry `review.state: "pending"`. Swap a failing area per spec section 1; if a whole kind fails, keep what passed (decision 8).
- [ ] **Step 2: Run** `python3.14 scripts/site_catalogue/research/check.py --review <scratchpad>/review.html`. Expected: every entry offered for approval passes.
- [ ] **Step 3: Publish** the review page as a private artifact and **stop**: ask the maintainer to approve or reject each entry. Do not commit `sites.json` with any `approved` state before their answer.

> **Outcome:** no entry passed in any of the six areas researched (see the spec's Pilot result). The maintainer chose to ship the code with an empty `sites.json`; Task 13 was not run, and the PR refers to #4514 instead of closing it.

### Task 13: Ship the approved batch

**Files:**
- Modify: `scripts/site_catalogue/research/sites.json`, `assets/data/site_catalogue.json`, `assets/data/site_catalogue.version`, `test/features/dive_sites/data/catalogue/site_catalogue_asset_test.dart`

- [ ] **Step 1: Write** the maintainer's answers into `review` (date only).
- [ ] **Step 2: Write failing asset tests**: acceptance 1 (count of `research` records pinned to the approved number, areas named), acceptance 2 (each passes the checker's position rule against the evidence file), acceptance 3.
- [ ] **Step 3: Run** the checker and the merge into `assets/data`; quote the merge report in the commit body.
- [ ] **Step 4: Run** the asset, importer and attribution tests. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-sites): first researched sites: <areas>`.

### Task 14: Verify, review, PR

- [ ] **Step 1:** Whole-repo `flutter analyze`; `dart format .`; affected test folders one after another: `test/features/dive_sites`, `test/core/database`, `test/architecture`, `test/shared`, `test/l10n`, `test/tool/demo_data`; every `scripts/**/site_catalogue*` and `research` Python test.
- [ ] **Step 2:** Before and after screenshots (light and dark) of the picker row, details card, built-in page, Import result, gap-fill row and comparison, GPS match review and the withdrawal line, rendered as slice 5 did; phone and desktop widths for the picker and the page.
- [ ] **Step 3:** `/code-review high --max-findings all` over the branch; fix every finding with a test watched red first.
- [ ] **Step 4:** Push; open the PR to main with `Closes #4514`, the merge report, the areas and counts, and the screenshots through the project gist; bind it and read CI.
