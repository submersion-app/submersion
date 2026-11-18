# Site catalogue: its own repository, AI research at scale

Date: 2026-11-17
Status: draft, for the maintainer's approval
Program: `2026-11-13-site-catalogue-program.md`
Builds on: `2026-11-15-site-catalogue-researched-sites-design.md` (slice 3),
`2026-11-16-site-catalogue-wider-sources-design.md`
Issue: #4514

## Intent

Divers log dives at sites the built-in catalogue does not hold, and other
dive log apps advertise far bigger catalogues. The catalogue needs to grow
much faster than a hand-run batch of six areas allows, and it needs to stay
current with its registers without anyone rebuilding it by hand.

Building the first researched batch (PR #4650) showed what holds that back:

- No machine had the source snapshots, so a rebuild meant fetching every
  register again: more than an hour, with one source timing out and one
  answering an error, and every upstream change mixed into a data PR.
- Research was one session's agents, briefed by hand, with the maintainer
  approving each of 57 entries. That does not reach thousands.
- Pipeline tests leaned on data committed beside them (`merge_test.py`
  read the real evidence file until it went red).

This design moves the catalogue into a repository of its own, which
publishes versioned releases the app takes through a reviewed PR. In that
repository the registers refresh on a schedule, and AI research runs on
demand through one procedure, with approval tiered so the maintainer's
attention goes where the evidence is weakest.

## What was decided

Chosen by the maintainer in the design conversation (2026-11-16 and 17):

1. **A separate repository.** The catalogue pipeline, its research
   evidence and its format contract move out of the app repository. The
   app uses the repository's published output.
2. **Success is both:** a diver logging a dive finds their site among those
   offered, and the catalogue's size compares with other apps'. Research
   therefore aims at the reefs, walls and shore sites of places people
   dive; wrecks are already well covered by the registers.
3. **Tiered approval.** Researched sites with strong evidence ship after
   machine checks without a person approving each one; weaker evidence
   comes to the maintainer entry by entry.
4. **Sources: web research now.** The repository is built for AI research
   of published pages under the existing rules. Diver submissions are left
   for later. Permission agreements stay a documented path (a source module
   with its grant recorded), with no agreement pursued now; in particular
   no request to Divers Atlas.
5. **The split way of running.** The register refresh (no AI) runs on a
   schedule in the cloud and opens a PR. AI research runs on demand, started
   by the maintainer, through a skill in the new repository.
6. **Releases reach the app by a bot PR.** A workflow in the app repository
   opens a PR copying a catalogue release into `assets/data/`, where the
   app's own tests check it.
7. **Other community projects (assessed 2026-11-17):** Divers Atlas allows
   personal, educational or nonprofit use only and no redistribution without
   its board's permission; Dive Vibe's data beyond OpenStreetMap keeps its
   original rights (Wannadive, DiveAdvisor and others); DiveCodex forbids
   scraping and AI use. None ships. Dive Vibe and the directories may serve
   as lead lists only (section 5).
8. **One public repository.** No private companion: raw snapshots are
   published under each source's own terms, and lead lists are never
   stored.
9. **No GitHub App or personal token.** Workflows use GitHub's built-in
   token; the maintainer closes and reopens each release PR in the app
   repository to start its CI (section 4).

## Goals

- A rebuild of any release is reproducible from stored snapshots.
- Register changes reach the app every month with no manual step but a
  review of the PR.
- A research run covers many regions in one go, and most of what passes
  ships without the maintainer reading each entry.
- The maintainer's queue holds only what needs judgement: weaker evidence,
  flagged entries, new domains and a sample audit.
- Every shipped researched record still traces to the pages behind it.
- The app's build is unchanged: the catalogue is a file in `assets/data/`.

## Non-goals

- Diver submissions, permission agreements, and updates pushed to the app
  between releases. Each is a later design (Later).
- Scheduled AI research. The skill can be scheduled later; this design runs
  it on demand.
- Any change to what the app does with the catalogue: matching, the
  "Not verified" mark, withdrawals and the picker stay as they are.
- New site facts (difficulty, species, photos).

## Anti-goals

- A figure from a page whose terms forbid reuse, or from a directory or lead
  list, in a shipped record. Scale does not relax the licence position.
- Page text in the repository: no quotation, no close paraphrase, at any
  volume.
- An auto-tier record shipping without the second, independent pass
  agreeing with it.
- The auto tier running on with nobody measuring its error rate.
- A link a diver already holds (`source_ref` on an adopted site) breaking
  because of the move.
- A catalogue release the app cannot read reaching a build.

## Constraints

**Licence position (program spec, "Licence position").** The catalogue is
an ODbL database because it holds OpenStreetMap data. Own-terms sources
(New Jersey, North Carolina, Texas, Hawaii) ship beside it and are left
out of the `--open-only` build. A source whose terms forbid redistribution
contributes nothing. These hold whatever volume research reaches.

**Where coordinates are.** Directories hold most written coordinates and
their terms forbid reuse or grant nothing (wider sources design,
Constraints). Research at scale reads them to find sites, never to place
one. The richest permitted seams are park and reserve authorities that
publish mooring or site positions (the Roatan Marine Park was named on
ScubaBoard as one) and operators' own interactive maps.

**The app has no server.** Sync goes to each diver's own storage, so
nothing flows from the app to the catalogue. This design needs none.

**Ties in the app repository today** (all must be handled by the move):

| Tie | Where | What the move does |
|---|---|---|
| The asset and its sidecars | `assets/data/site_catalogue.json`, `.version`, the NJDEP and Maryland metadata files | Stay; replaced by each release PR |
| Format vocabularies mirrored from Dart | `site_catalogue_format.py` (`SITE_TYPE_IDS` from `site_type_seed.dart`, `ENTRY_METHODS` from `app_enums.dart`) | Become the published contract (section 3) |
| Licence text naming every source | `site_catalogue_attribution.dart` and its test | Stays in the app; its test reads the source list from the asset's metadata, not from the format script |
| Researched records' `source_ref` | `src_research.py`, `_REPOSITORY_FILE`, a URL into this repository's `main` | New records cite the new repository; the old path keeps a pointer file (section 7) |
| Demo data reads the curated file | `test/tool/demo_data/destinations_test.dart`, `tool/demo_data/src/story/destinations.dart` | Read the curated records from the asset instead (they ship in it with `source: curated`) |
| CI runs the pipeline's Python tests and the checker | `.github/workflows/ci.yaml` | Removed from the app's CI; the new repository runs them |
| README's open-only instructions | `README.md` | Point to the new repository's open-only release asset |
| The OSM dive centre harvester | `scripts/dive_site_harvester.py` | Not part of the catalogue; stays |
| Country lookup | `scripts/site_country_resolver.py` (used by `places.py`, `src_osm.py`) | Moves with the pipeline |
| The app's country tables | `places.py` reads `lib/core/geography/country_names.generated.dart` and `country_code.dart`, and imports `scripts/geography/generate_country_names.py` | Become part of the contract (section 3): a vendored table the app's tests check against its own |

## Approaches

**Where the catalogue lives.**

| | A. Stay, hardened | B. Own repository (chosen) | C. B plus updates fetched by the app |
|---|---|---|---|
| For | One PR changes format, app and data together; one CI | Data churn and research leave the app's history and CI; a natural home for the ODbL offer; contributors need no Flutter | Withdrawals and batches reach divers between app releases |
| Against | App history grows with every rebuild; Python CI on every app PR | Format changes become two coordinated PRs | Hosting, signing, privacy, the web build, a second import path |

The maintainer chose B. C stays a later design.

**How the app takes a release.**

| | 1. Bot PR copies the release (chosen) | 2. Download at build time | 3. Git submodule |
|---|---|---|---|
| For | Build unchanged; each release reviewed and tested by the app's tests; a natural format gate | No catalogue data in the app's history | Pins an exact commit |
| Against | App history still grows by each release's diff | Every workflow, the hook and each worktree need the fetch and a network | Every checkout carries the whole pipeline and its history; worktrees need extra setup |

**How research runs.** On demand (no infrastructure, growth stops when
runs stop), scheduled in the cloud (grows on its own, needs a key and a
standing bill), or split (chosen): the refresh is scheduled, research is
on demand through a skill that can be scheduled later.

**How a researched site is approved.** Every entry by the maintainer
(highest quality, caps growth at a few hundred a month), automatic with a
sampled audit (scales, some errors reach divers first), or tiered (chosen):
strong evidence automatic, weaker evidence to the maintainer.

## Design

### 1. The new repository

`submersion-app/site-catalogue`, public.

```
site-catalogue/
  README.md            what it is, the licence, how to build, how to use a release
  LICENSE              code: GPL-3.0, as the app
  LICENSE-DATA.md      the catalogue: ODbL 1.0 with the own-terms sources named apart
  contract/
    format.json        the published format contract (section 3)
  pipeline/            today's scripts/site_catalogue/*.py and tests
  research/            today's research/ (evidence, domains, checker, review)
    runs/              one folder per research run: brief, report, queue
  curated/             today's dive_sites_curated.json and curated_sites.py
  .agents/skills/      the research skill (section 5)
  .github/workflows/   ci, refresh, release
```

There is one repository (maintainer, 2026-11-17). It must be public:
researched records link to their evidence in it, divers keep those links on
adopted sites, and it is the ODbL database's public home. Raw snapshots are
published in it too (section 2), each under its source's own terms; lead
lists are never stored (section 5).

The layout is a proposal; the builder may rename folders. What moves:
everything under `scripts/site_catalogue/`, `scripts/site_catalogue_format.py`,
`scripts/curated_sites.py`, `scripts/dive_sites_curated.json`,
`scripts/site_country_resolver.py`, and their tests. Their history moves
with them (a history-preserving extract such as `git filter-repo`), so
blame on an evidence entry still shows who added it and in which PR.

The repository has its own instructions file for AI agents, carrying the rules that matter there: the attribution rule, no page text,
the licence position, never forcing a failing entry.

### 2. Snapshots and the register refresh

Each fetch writes a dated snapshot. Snapshots are stored as assets of a
GitHub release tagged `snapshots-YYYY-MM-DD` in the repository, never in
git (UKHO alone is 37 MB). Release assets do not expire, unlike workflow
artifacts (90 days at most), so every catalogue release stays rebuildable.

Every source's terms allow its raw download to be published on conditions
(register expansion spec, the terms table), so a snapshot release carries,
beside each source's file, a terms note naming its licence and credit:

- **ODbL, OGL, CC0, CC BY, public domain and US government sources**
  (OpenStreetMap, UKHO, NOAA AWOIS, MarineCadastre, Florida, the Florida
  Keys buoys, Ireland, Wikidata): published with their attribution.
- **New Jersey:** published with NJDEP's metadata file beside it and its
  credit and disclaimer, coordinates as received, as its Data Distribution
  Agreement requires.
- **North Carolina:** published unaltered from the fetch, with its citation,
  marked non-commercial.
- **Texas and Hawaii:** their rows sit inside NOAA's MarineCadastre file,
  which states no restriction; the terms note names the states'
  non-commercial terms and Texas's credit line for those rows.

The snapshot release's notes say that the own-terms files are not part of
the ODbL database and may not be used commercially, as the catalogue's own
notice says of their records. The merge reads snapshots from the cache as today; a script
downloads a named snapshot set into the cache, so any release can be
rebuilt byte for byte.

The `refresh` workflow runs monthly and can be started by hand:

1. Fetch every source, retrying a refused or failed request once after a
   pause (as the OpenStreetMap fetch does today). A source that still fails
   is reused from the previous snapshot set and named in the report; the
   run never silently drops a source.
2. Store the snapshot set as a release.
3. Run the merge and the checker.
4. Open a PR with the rebuilt catalogue and the merge report as its
   description: per source what was read, dropped and written; ids gone and
   new; records changed; departures held (a researched or curated record
   that would leave without a withdrawal stops the merge, as today, and the
   workflow opens an issue naming it instead of a PR).

A refresh PR carries register changes only. Research arrives in its own
PRs, so the two are reviewed apart.

### 3. The format contract and releases

`contract/format.json` is the single statement of the catalogue's shape:
the format version, the record fields and which are required, and the
closed vocabularies (site types, entry methods, trust levels,
`position_from` values, withdrawal reasons, hazard codes), and the country
table the merge writes names from (code and English name, today read from
the app's `country_names.generated.dart` and `country_code.dart`). The
vocabularies are generated from the pipeline's Python definitions, and a
test fails when the two disagree. The country table is vendored from the
app: the app's tests check its copy of the contract's table against its own
generated names, so a catalogue can never write a country name the app
cannot resolve back to its code, and a rebuild uses the table pinned in the
contract, not whatever the app holds that day.

A **release** is a GitHub release tagged by date (`YYYY.MM.DD`, with a
suffix for a second release on one day), carrying:

- `site_catalogue.json` and `site_catalogue.version`,
- the NJDEP and Maryland metadata files,
- `site_catalogue_open.json`, the `--open-only` build (the ODbL database
  alone),
- `format.json`, and release notes generated from the merge report.

A release is cut by the `release` workflow from a merged commit on `main`,
after the checker and every test pass.

**Format gate in the app.** The app repository holds a copy of the
contract it was built against (`assets/data/site_catalogue_format.json`, or
a test fixture; the builder chooses). A test checks the app's own
vocabularies (`kBuiltInSiteTypes`, `EntryMethod`, the parser's known
fields) against that copy. The release PR replaces the copy; when the
release's format version is newer than the parser reads, or its
vocabularies hold a value the app lacks, the app's tests fail in that PR
and it cannot merge. A format change therefore lands in the app first (the
parser learns the field), then the catalogue release that uses it.

### 4. The release PR in the app repository

**Who opens bot PRs** (maintainer, 2026-11-17: the built-in token, no
GitHub App or personal token). Every workflow uses GitHub's built-in
`GITHUB_TOKEN`. Two consequences follow, both accepted:

- A PR opened with that token starts no other workflow. In the catalogue
  repository this costs nothing: the refresh workflow runs the tests and
  the checker itself before it opens its PR, and says so in the PR body.
  In the app repository, `main` requires the "CI Success" check, so the
  maintainer closes and reopens each release PR once; a reopen by a person
  starts CI as usual. At one release a month that is the whole cost.
- Nothing crosses repositories with a credential. Releases are public, so
  the app's intake workflow runs on a weekly schedule (and by hand), checks
  whether a release newer than the copy in `assets/data/` exists, and
  downloads it without authentication.

PRs opened this way are authored by `github-actions[bot]`, so the app's PR
Issue Link check exempts them; they still name the issue they relate to.
A personal token or a GitHub App can be added later to start CI
automatically without changing anything else.

A workflow in the app repository (`site-catalogue-release.yml`), started by
hand or on a schedule after each release:

1. Downloads the newest release.
2. Replaces `assets/data/site_catalogue.json`, its `.version`, both
   metadata files and the contract copy.
3. Opens a PR with the release notes as its description, `Refs #4514`
   (or the issue the release names), and the "No visible UI change" box
   explained: the PR changes data, not screens.

The app's tests run on that PR as on any other. The asset test's pinned
counts (`site_catalogue_asset_test.dart`) change in every release, so the
pins become checks against the release's own metadata (its `total_count`
and per-kind counts) plus floors that catch a collapse (a release with far
fewer records than the one it replaces fails). The builder sets the floor.

### 5. AI research at scale: the research skill

A skill in the new repository runs a research run end to end. The
maintainer starts it with a scope (a number of regions, or named regions)
and a budget (a token or cost ceiling the run stops at).

**Where it runs.** In the maintainer's own interactive agent session on
their machine and plan, as this batch ran: the skill dispatches one
subagent per region and per second pass. Its token figures come from each
subagent's reported usage; the budget is a token ceiling the skill checks
before starting each region. The skill is written so a headless runner
with an API key could run it later (Later, scheduled research).

**Stage 1: pick regions.** A coverage measure (as slice 3's
`slice3-measure.py`: well-known diving areas with few dive site records
within 50 km) ranks regions by thinness. The skill takes the thinnest the
scope allows, and skips a region a previous run covered unless the
maintainer names it again.

**Stage 2: leads.** For each region, candidate site names come from lead
lists: the directories (cite-only), Dive Vibe's community data, and pages
found by search. Leads are gathered fresh by each run and never stored,
in the repository or anywhere else: they come from pages whose terms
forbid reuse. Within a run a lead holds only a site name, the region, and
the address where the name was seen; never a position or any other fact.
They say where to look, not where a site is. Stage 1's "a previous run
covered it" therefore reads the run folders' reports (which regions were
researched, which candidates failed and why), not stored leads.

**Stage 3: research.** One agent per region follows the procedure of the
research README, as this batch's agents did: find two counting pages on
different domains that name each site, take its position from a counting
page's stated figure, interactive map pin or map image, record facts and
links only, and run the checker. Its output is the region's entries and a
report: domains read with their terms finding, candidates that failed and
why, doubts.

**Stage 4: domain queue.** A domain on no list blocks every entry that
cites it. The agent proposes a list (counting, cite-only or never) with
its terms finding. Proposals collect in the run's queue for the maintainer,
who rules on each once. Entries waiting on a domain stay pending.

**Stage 5: second pass.** A fresh subagent, given only each entry's cited
addresses and recorded facts (not the first agent's notes, report or
reasoning), re-reads every page an entry cites and states what each page
says about the recorded facts: does it name the site in that place, does it
state that figure, does its map show that point, do its terms allow reuse.
An entry passes only when the second pass agrees with every fact. A
disagreement sends the entry to the maintainer's queue with both readings.

**Stage 6: machine checks** beyond today's checker:

- the point lies in water, or within 100 m of the coastline for a shore
  entry, using OpenStreetMap coastline data;
- the point lies within the place `named.place` describes (inside the named
  island's, bay's or reef's bounds, from OpenStreetMap, with a margin);
- a figure that equals an OpenStreetMap point of a hotel, village or other
  non-dive feature (this batch found operators copying them) is flagged.

The skill runs these checks with live OpenStreetMap queries and records
each result in the entry, as a `checks` fact: each check's name, pass or
fail, the date, and the OpenStreetMap element ids it used (the coastline
way, the island or bay feature). For the place check, `named` gains an
optional `osm` reference to the feature the place names. CI does not
recompute them: the checker refuses an auto-tier entry whose `checks` are
missing or not all passed. Recomputing would need a stored coastline and
point-of-interest dataset in the repository; recording keeps CI offline as
today, the ids let anyone re-run a check, and the audit sample measures
whether recorded checks can be trusted.

**Stage 7: tiering and PRs.** Each passing entry gets a tier (section 6).
The run ends with two PRs and a review page:

- **The auto PR** holds the auto-tier entries, marked approved by auto.
  Its review page shows the audit sample. It merges only after the
  maintainer has checked the sample and the pause rule has not tripped;
  checking 5 to 30 entries is the whole cost of shipping the rest.
- **The queue PR** holds the maintainer-tier entries, pending, and the
  domain rulings the run asks for. The maintainer decides each, and it
  merges when every entry in it is approved or rejected.

An entry citing an unruled domain is in neither PR: it waits in the run's
folder until the domain is ruled, then joins the next queue PR. So `main`
never holds an entry citing an unruled domain, and the checker keeps its
current rule.

**Cost.** This batch used about 27,000 agent tokens per passing site. The
run reports tokens per region and per passing site, so the maintainer can
see what scale costs before deciding to schedule research. The builder
chooses models per stage; reading pages can use a cheaper model than the
second pass and the map readings.

### 6. Tiered approval

**Auto tier.** An entry is approved without the maintainer reading it when
all hold:

- two counting pages on different domains name it in the same place;
- its position route is `confirmed`, or `stated` from a page on a domain
  whose `kind` is `official` or `operator` (below);
- every cited domain is already ruled;
- the second pass agrees with every fact;
- every machine check passes, and no flag is raised (no neighbour within
  500 m, no copied map point).

**Domain kind.** A counting domain gains a `kind` the maintainer sets when
ruling it: `official` (park, reserve, government, heritage or harbour
body), `operator` (a dive operator or liveaboard that runs dives in the
area), `press`, `club` or `other`. `domains.json` changes shape from a
reason string to `{"kind": ..., "reason": ...}` per counting domain, and
the move converts the existing rulings (their reasons already begin with
these words). Only `official` and `operator` stated figures qualify for
the auto tier; a magazine's or club's figure still counts for the rules
but sends the entry to the maintainer. Whether the operator runs that
particular dive is not checked per entry: the operator's own page naming
the site in its area is taken as enough.

**Maintainer tier.** Everything else that passes the checker: map-read
positions, positions resting on one operator's figures when the second pass
or a check raises any doubt, second-pass disagreements, flagged entries.
These come to the review page entry by entry, as today.

**Sample audit.** Each research PR also puts a random sample of its
auto-tier entries on the review page: 10 percent of them, at least 5 and at
most 30 (the maintainer may change these). The maintainer checks each
sampled entry as they would a maintainer-tier one. If more than one in
twenty sampled entries is wrong, the auto tier is paused: every entry of
that run moves to the maintainer tier, and the next run may not auto-approve
until the cause is found and fixed.

**Recording it.** `review` gains who approved: `{"state": "approved",
"by": "auto" | "maintainer", "date": ...}`, and an auto-approved entry
records the second pass's verdict (a `second_pass` fact holding its date
and agreement, never page text). The checker refuses `"by": "auto"` on an
entry that does not meet the auto tier, so the tier is enforced in CI, not
only by the skill. A sampled entry the maintainer approved records
`"by": "maintainer"`.

Mistakes in the auto tier are corrected by withdrawal, as any researched
record is. The app is unchanged: auto and maintainer records ship alike,
marked "Not verified" and never auto-matched.

### 7. The move

In order:

1. Merge PR #4650 in the app repository.
2. Create the new repository with the history-preserving extract, add the
   workflows, the contract and the README. Its first CI run must pass.
3. Fetch a snapshot set, build, and confirm the build matches the app's
   current asset byte for byte when built from the same snapshots (if no
   such snapshots exist, the first release is a fresh refresh and its PR in
   the app is reviewed as one).
4. Change `source_ref` for researched records to the new repository's
   `research/sites.json`. Records already shipped change their reference
   in the next release; a diver who adopted a site keeps the old link, so
   the app repository keeps `scripts/site_catalogue/research/sites.json` as
   a small pointer file naming the new address (a JSON file holding only
   that address and a note), not the evidence.
5. Add the release workflow and the format gate to the app repository, and
   take the first release through it.
6. Remove the moved files and their CI from the app repository, and update
   its README, `site_catalogue_attribution.dart`'s comments and test, and
   the demo data tests (Constraints table).
7. Run the first research run through the skill on a small scope (one or
   two regions) before any larger one.

## Acceptance

1. The new repository's CI runs every moved test and the checker on its
   evidence, and passes.
2. A release built from a stored snapshot set rebuilds byte for byte from
   that set.
3. The refresh workflow, run by hand, opens a PR whose description is the
   merge report; a source made to fail is reused from the last set and
   named.
4. The app's release workflow opens a PR that replaces the asset, its
   sidecars and the contract copy; the app's tests pass on it.
5. A release whose contract adds a site type the app lacks fails the app's
   tests in its PR.
6. The checker refuses `"by": "auto"` on an entry outside the auto tier
   (a map-read entry, an entry citing an unruled domain, one without a
   second pass).
7. A research run on one region produces entries, a domain queue, a review
   page with the maintainer tier and the audit sample, and a cost report.
8. The old `sites.json` address in the app repository leads to the new
   repository.
9. Nothing from a lead list or a cite-only or never domain appears as a
   figure in a shipped record (the checker already enforces this for
   positions; facts too).

## Later

- **Diver submissions:** a diver shares a site of theirs from the app; needs
  a small hosted intake, a share sheet stating the ODbL grant, and corroboration
  rules. Its own design.
- **Permission agreements:** a granted source becomes a pipeline module with
  the grant recorded; own-terms handling when the grant is non-commercial.
  Divers Atlas is the strongest candidate when the maintainer wants one.
- **Updates fetched by the app** between releases (approach C).
- **Scheduled research:** the skill on a schedule, once cost per site and
  the auto tier's audit record are known.

## Known gaps

- The second pass reduces but does not remove shared mistakes: two agents
  reading one wrong page agree with each other. The audit sample is the
  measure of what gets through.
- Two operators who copied one map or survey still look independent.
- Coverage measured by record counts says nothing about whether the
  records are where divers dive; a region can look covered by wrecks
  nobody dives.
- A format change needs two PRs in order (app first). The format gate makes
  a wrong order fail loudly rather than silently.

## Changes made while building (2026-11-17)

Found by the build and settled there; each is in the code and its tests.

- **The catalogue is committed in the catalogue repository** (`catalogue/`).
  The merge's guard against a researched or curated record leaving without
  a withdrawal compares against the catalogue in its output folder; an
  ignored build folder would be empty in CI and the guard would never fire,
  and a refresh PR would hold nothing to review. `catalogue/SNAPSHOTS`
  names the snapshot set the committed catalogue was built from, and a
  release rebuilds from that set and stops unless the bytes match.
- **Snapshot sets carry the Natural Earth boundaries** the merge places
  countries with (public domain), and a `SET.json` manifest, since release
  assets have no folders. Texas and Hawaii have no snapshot of their own
  (their rows sit in the federal file), so their terms are in
  `noaa_reefs.TERMS.txt`.
- **The app keeps its contract copy beside the test that reads it**
  (`test/features/dive_sites/data/catalogue/contract/`), not in
  `assets/data/`, which the app bundles.
- **A test wrote into the real snapshot cache.** The federal fetch test
  faked the download as a zipped GeoPackage, and the fetch's Maryland
  metadata save wrote that zip over the cached metadata on every run. The
  test now stubs the save; `pack` refuses a metadata file that is not XML.
- **The first snapshot set is the one that built the catalogue of
  2026-11-16** (`snapshots-2026-11-16`), and the first release
  (`2026.11.17`) was rebuilt from it by the release workflow and matched
  byte for byte.

## Calls the designer made

Settled by the designer; the maintainer saw the shape in conversation and
approves them with this document:

- Repository name, public visibility, GPL-3.0 for code and ODbL for data.
- The app's intake polls weekly for a newer release instead of being
  triggered by the catalogue repository.
- History carried across with a history-preserving extract.
- Snapshots stored as release assets, not in git.
- A failed source in a refresh is reused from the last snapshot set and
  named, never dropped.
- Date-tagged releases carrying the open-only build and the contract.
- Count pins in the app become checks against release metadata plus a floor.
- The auto tier's conditions, the 10 percent (5 to 30) audit sample and the
  one-in-twenty pause rule.
- `review.by` and a recorded second-pass verdict, enforced by the checker.
- Water, place-bounds and copied-point machine checks, run by the skill and
  recorded in the entry; CI checks they are present and passed, not
  recomputed.
- The pointer file at the old `sites.json` address.
- Demo data reads curated records from the asset.
- Raw snapshots published as release assets of the one public repository,
  each with a terms note; own-terms files marked outside the ODbL database.
- Leads never stored; within a run they hold a name, a region and an
  address, never a position.
- The country table joins the contract, vendored from the app and checked
  by the app's tests.
- Research runs in the maintainer's own session; budget is a token ceiling
  from subagent usage; the second pass sees only addresses and facts.
- Two PRs per run: the auto PR merges after the audit sample; the queue PR
  after the maintainer's decisions; unruled-domain entries wait outside both.
- A per-domain `kind`; only `official` and `operator` figures reach the auto
  tier; club and press figures go to the maintainer.

## Left to the builder

- Folder and workflow names, and how the contract is generated.
- Where the app keeps its contract copy, and the count floor.
- Model choice per research stage, and how the run enforces its budget.
- How the skill splits regions among agents and how many run at once.
- How lead lists are stored and refreshed.
- The review page's layout for tiers and the audit sample.
