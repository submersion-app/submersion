# Site catalogue: researched sites (slice 3)

Date: 2026-11-15
Status: approved 2026-11-15
Program: `2026-11-13-site-catalogue-program.md`
Issue: #4514 (the program's last slice)
Amended: 2026-11-16 by `2026-11-16-site-catalogue-wider-sources-design.md`
(decision 4 and the description rule below)

## Intent

The registers of slice 2 filled the catalogue with wrecks and artificial
reefs. They supply no reefs, walls or shore sites, and none of the open
sources lists the famous ones. Measured on the shipped catalogue (20,931
records, 3,931 dive site records), 48 of 101 well-known diving areas hold
fewer than 5 dive site records within 50 km, and Sipadan, Tulamben,
Tubbataha, Kona, Ningaloo, Port Douglas, Cocos, Socorro, Rangiroa, Aliwal
Shoal, Tofo and the Farne Islands hold none. A diver logging a dive there
types every site by hand.

This slice adds sites found by research: a person or an AI session reads
published pages about a dive area and records the facts they state, each
fact with the pages behind it. Because those facts were not taken from a
survey or a register, every such record carries a "not verified" mark
wherever a diver chooses it, and GPS matching never picks one on the
diver's behalf.

It also delivers the process by which later batches are researched,
checked, reviewed by the maintainer and shipped, and the means to withdraw
a researched record that proves wrong and tell any diver who adopted it.

The first batch is a pilot of about 30 records in three areas, there to
test the rules on three different kinds of site before anything larger.

## What was decided

These were chosen by the maintainer during the design conversation
(2026-11-15).

1. **New sites first.** Research adds new records in areas the catalogue
   lacks. Adding researched details (depth, entry, type) to existing
   verified records is a later batch with its own design, since one record
   would then mix verified and researched facts.
2. **Pilot of about 30 records in three areas**, one of each kind: a shore
   area (Tulamben, Bali), an offshore reef area (Sipadan and its
   neighbours, Sabah) and a cold-water area (Farne Islands, England).
3. **Which pages count.** Official pages (marine park authorities,
   government notices, harbour or heritage bodies) and first-hand pages
   (the local operators who run the dive, dive press and club write-ups by
   people who dived it) count as sources. Directories and aggregators (PADI
   and SSI site pages, diveplannerpro, zentacle, divebuddy, yachtway,
   travel apps and their mirrors) may be cited but never count. Guidebooks,
   paid apps and the sources the program excludes (wrecksite.eu, WannaDive,
   Wikivoyage, Diveboard) are never used.
4. **A position ships only when two counting sources agree within 150 m.**
   Otherwise the record does not ship. No record ships without a position,
   and no position is placed from a description.
   *Amended 2026-11-16 (wider sources design, section 2):* this is now one
   of three routes. Two counting pages naming the site prove it exists,
   and one counting page may place it, by a stated figure or a point read
   off its own map, every counting figure within 2 km. A counting page's
   map is evidence of position; words alone still are not.
5. **The mark is a label and a sentence.** A short "Not verified" label on
   every surface that shows a built-in record to choose, and one sentence
   where there is room: "Gathered from published dive guides, not from a
   survey. Check the position locally before you rely on it." Map markers
   are unchanged.
6. **Withdrawals are listed and divers are told.** The catalogue file
   carries the ids of withdrawn researched records with a reason. A diver's
   site linked to one shows a line saying so. Nothing about the site
   changes on its own.
7. **The 55 curated records become researched.** They show the mark and
   follow the matching rules below. They are not re-checked in this slice;
   re-checking them under these rules is a later batch.
8. **When a kind of site yields nothing, ship what passed.** If an area
   and every replacement of its kind fail, the pilot ships the areas that
   passed (two areas, at least 15 records), and the batch review says which
   kind found nothing and why. That is itself a finding about where
   research on open pages cannot reach.

Designer's calls the maintainer saw during the conversation and did not
object to (each is restated where it applies):

- Depth is the deepest figure a counting source gives, left empty when the
  counting sources disagree too widely; a hazard named by one counting
  source is kept; entry and type are kept when one counting source states
  them and none contradicts; anything unconfirmed is left empty.
- Every fact stores its pages and the date they were read. A researched
  record holds no wording from any page; its description is one line
  generated from its own fields.
- A source key of its own (`research`), under ODbL; the existing
  `trust: researched` marks the records, so the format does not change.
- Evidence lives in the repository; the record's source link points to its
  evidence entry.
- GPS matching offers a researched record and never preselects it; the
  picker lists it in "More sites near" in the usual order with its label;
  gap-fill already never ticks it; once adopted it is an ordinary site.
- A written procedure, a checking script that fails CI on a breach, and a
  generated review page; the maintainer's approval is written into the
  evidence file and only approved entries ship.
- An area that yields fewer than 5 records that pass is swapped for the
  next thin area of the same kind, named in the batch review.

## Goals

1. About 30 researched dive site records in three thin areas, each with a
   position two counting sources agree on.
2. Every fact of every researched record traceable to the pages it came
   from, in the repository, and no wording from those pages anywhere.
3. A diver can tell a researched record from a verified one everywhere
   they choose a built-in site.
4. GPS matching never attaches a researched record to a dive without the
   diver choosing it.
5. A researched record that proves wrong can be withdrawn, and a diver who
   adopted it is told why.
6. A later batch can be researched, checked and reviewed by following the
   written procedure, with no change to code.

## Non-goals

- Researched details added to existing verified records (decision 1).
- Re-checking the 55 curated records (decision 7).
- Positions placed from a description against a map (decision 4).
- Any change to a diver's site from built-in data, including offering a
  corrected position (decision 6).
- A distinct map marker for researched records (decision 5).
- Translating catalogue text. Record names, generated descriptions and
  hazards stay in English, as every catalogue record's are today.
- Automatic or scheduled research. A batch is run by hand.
- Checking in CI that a cited page still answers. The checker is offline.

## Anti-goals

- A researched position attached to a dive without the diver choosing it.
- A position resting on one page, or on two pages that copy one dataset.
- A sentence, or a close paraphrase of one, from any page in the catalogue
  or the evidence.
- A set of positions taken from one guidebook, chart or paid app (in the
  UK and EU a collection of facts can be protected as a database even when
  each fact is free).
- A researched record shipped that the maintainer has not seen and
  approved.
- A researched record shown anywhere a diver chooses a site without its
  label.
- A withdrawn record that leaves a diver's site silent about it.
- A researched record merged with, giving a field to, or taking one from a
  verified record.

## Constraints

- **Format.** The catalogue stays format 2. This slice adds one optional
  metadata entry (`withdrawn`, section 6). The app drops unknown names on
  read.
- **Local cache database.** No schema change: the withdrawn list is stored
  in the existing key and value table `site_catalogue_meta`.
- **Licence.** Researched records are facts stated in our own words,
  compiled by the project, and join the ODbL database. Each fact names its
  pages so the compilation can be audited. No page's text is stored.
- **Outside services.** Research reads public pages through the research
  session's own search and fetch tools. Any script that fetches sends
  `dive-site-harvester/1.0` and nothing that names a person, an address or
  the project. The checker, the review page and the merge use no network.
- **CI.** The checker and its tests are standard library Python and join
  the "Run Python guard tests with coverage" step with their modules in its
  coverage list, as slice 2's scripts did.
- **Units, localisation, guards, TDD, 800-line files, platform-agnostic
  paths, `dart format .`** as in the earlier slices. Every new string goes
  in all 11 ARB files. Python is `python3.14` locally.

## Approaches considered

| | A. One more harvest source (chosen) | B. Extend the curated file | C. A separate asset |
|---|---|---|---|
| How | An evidence file, a checker, and the slice 2 merge reading approved entries as source `research` | Researched sites written as curated entries with an evidence sidecar | A second asset file, sidecar, import path and table for researched records |
| For | Reuses the merge's placing, overlap and writing; one file, one import; the trust column already exists | No new source | A physical boundary between trust levels |
| Against | A new source module and a checker to write | Curated entries have their own overlap rules (they step aside for an OpenStreetMap dive site of the same name within 1 km, outrank every other source, and take a loser's empty fields) and no place for evidence; the two kinds blur | A second import path for records the existing table already holds with a trust column; slice 2 turned down the same split for own-terms records |

**Chosen: A.** The maintainer approved this approach on 2026-11-15.

## Design

### 1. The research run

A run covers one area at a time and follows the procedure in
`scripts/site_catalogue/research/README.md` (written in this slice). In
outline:

1. **Pick candidates.** List the area's sites that pages name repeatedly.
   Leave out any site a verified record already covers (the checker
   reports these too, section 4).
2. **Read pages.** For each candidate, find counting pages (decision 3) and
   note from each one only the facts it states: position, depth, entry,
   site type, hazards. Note the page's address and the date it was read.
   Cite-only pages may be noted for completeness; they never confirm.
3. **Write the entry** in the evidence file (section 2), in the closed
   vocabularies the file allows. No sentence is copied; no field holds free
   text from a page.
4. **Run the checker** (section 4). An entry that fails is fixed or
   dropped, never forced.
5. **Generate the review page** (section 5) and hand it to the maintainer.
6. **Record the maintainer's decision** on each entry (section 2,
   `review`). Rejected entries stay in the file with their reason, so a
   later run does not research them again blind.
7. **Run the merge.** Only approved entries reach the catalogue.

Classifying a page's domain is part of the run: a domain the domain list
(section 3) does not hold fails the checker until a person adds it to one
of its three lists. So every new kind of page meets a human decision once.

**Independence.** Two counting pages confirm a position only when they are
on different registrable domains. The checker cannot know whether two
operators copied each other; the procedure tells the researcher to prefer
pages whose figures are written differently (another precision, another
datum note, a different point on the site) and the review page shows each
figure so the maintainer can judge.

**The three pilot areas.** Tulamben (Bali, Indonesia), Sipadan with Mabul
and Kapalai (Sabah, Malaysia), Farne Islands (Northumberland, England),
about ten records each. If an area yields fewer than 5 records that pass,
it is replaced by the next thin area of the same kind from the measured
list (shore: Kona, Aliwal Shoal, Tofo; offshore reef: Tubbataha, Port
Douglas, Rangiroa; cold water: Gulen, Lysekil, Azores), and the batch
review says so. Recon on 2026-11-15 found Sipadan's published positions
mostly in whole minutes and the Farnes' only in a guidebook and on charts,
so both may be replaced. If every area of one kind fails, the pilot ships
the areas that passed (decision 8).

**Who researches and where approval happens.** The session that builds
this slice researches the pilot by following the procedure. The
maintainer approves on the review page before the batch is committed, and
one PR carries the code and the approved batch. Later batches are PRs of
data alone.

### 2. The evidence file

`scripts/site_catalogue/research/sites.json`, committed. A JSON list, one
entry per researched site, sorted by id, written one entry per block so a
batch shows in a diff as the entries it adds.

```json
{
  "id": "research_id_usat_liberty",
  "name": "USAT Liberty",
  "area": "Tulamben",
  "country_code": "ID",
  "position": {
    "lat": -8.27394,
    "lon": 115.59287,
    "sources": [
      {"url": "https://...", "read": "2026-11-16", "lat": -8.27391, "lon": 115.59261},
      {"url": "https://...", "read": "2026-11-16", "lat": "8 16 28.80 S", "lon": "115 35 34.77 E"}
    ]
  },
  "max_depth_m": {"sources": [{"url": "https://...", "read": "2026-11-16", "value": 30}]},
  "min_depth_m": {"sources": [{"url": "https://...", "read": "2026-11-16", "value": 5}]},
  "entry": {"value": ["shore"], "sources": [{"url": "https://...", "read": "2026-11-16"}]},
  "types": {"value": ["wreck"], "sources": [{"url": "https://...", "read": "2026-11-16"}]},
  "hazards": {"value": ["boat_traffic"], "sources": [{"url": "https://...", "read": "2026-11-16"}]},
  "review": {"state": "approved", "date": "2026-11-17"},
  "withdrawn": null
}
```

- **id**: `research_<country code, lower case>_<name slug>`. Formed once
  from the name when the entry is written and never recomputed, so a later
  rename does not rename the record. Unique across the catalogue.
- **name**: the name divers use for the site, as the counting pages write
  it, in Latin script.
- **area**: the pilot area or later batch area it was researched under.
  Used by the review page and the report; not shipped.
- **country_code**: the researcher's statement, checked against the merge's
  offline place lookup (section 7).
- **position.sources**: every page that states a position, each with the
  figure as the page writes it (decimal degrees, or degrees, minutes and
  seconds, or degrees and decimal minutes, with hemisphere letters). The
  checker parses each figure. **position.lat/lon**: the shipped point, the
  mean of the counting figures (section 4 checks it).
- **max_depth_m, min_depth_m**: each source's stated figure in metres (the
  researcher converts feet and notes `"unit": "ft"` with the figure as
  written; the checker converts). The shipped value is computed (section 4),
  not written by hand.
- **entry, types**: values from the catalogue's own vocabularies
  (`ENTRY_METHODS`, `SITE_TYPE_IDS` in `site_catalogue_format.py`).
- **hazards**: codes from a closed list (section 3), each written into the
  catalogue as our own short sentence.
- **review**: `pending`, `approved` or `rejected` with a reason, and the
  date. Written by the person who records the maintainer's decision. Only
  `approved` ships.
- **withdrawn**: null, or `{"reason": ..., "date": ..., "replaced_by": ...}`
  (section 6). A withdrawn entry no longer ships and its id joins the
  file's withdrawn list.

Every `sources` item may carry `"archive"`: an archive.org address of the
page as read. Optional; recommended where one exists.

Nothing in the file holds a page's text. There is no field for a quotation
or a note copied from a page. A free `note` field on an entry is allowed
for the researcher's own words (why a figure was set aside, which point on
a long site was chosen); it is not shipped.

### 3. Vocabularies and lists

`scripts/site_catalogue/research/domains.json`, committed:

```json
{
  "counting": {"tulambenwreckdivers.com": "first-hand: local operator", ...},
  "cite_only": {"padi.com": "directory", "diveplannerpro.com": "mirror of directory pages", ...},
  "never": {"wrecksite.eu": "proprietary", "wikivoyage.org": "CC BY-SA", ...}
}
```

Each domain is a registrable domain with a short reason. A page on a
subdomain takes its parent's list. A domain on two lists, or a source on a
domain on none, fails the checker. The procedure seeds the lists with the
recon findings and the program's exclusions.

**Hazard codes** and the sentence each writes (English, ours):

| Code | Written as |
|---|---|
| `strong_current` | Strong currents. |
| `surge` | Surge in shallow water. |
| `boat_traffic` | Boat traffic overhead. |
| `overhead` | Overhead environment; penetration needs training. |
| `entanglement` | Lines and nets. |
| `cold` | Cold water. |
| `low_visibility` | Visibility often low. |
| `permit` | Protected area; a permit or fee may be needed. |
| `depth` | Depth beyond recreational limits nearby. |

Several codes join in table order into one `hazards` text. Adding a code is
a change to this table and the checker, reviewed like any code.

### 4. The checker

`scripts/site_catalogue/research/check.py` (name left to the builder),
standard library only, runs in CI against the committed file and offline.
It fails, naming the entry and the rule, when any of these holds:

**Shape**
- An id does not start `research_`, repeats, or is used by another source.
- A field is outside the shapes of section 2; a type, entry or hazard code
  is outside its vocabulary; a `read` date is missing or in the future.
- A source's domain is on no list, or on two.
- An entry uses a source on the `never` list for any fact.

**Position** (every entry, whatever its review state)
- Fewer than two counting sources state a position.
- The counting sources are fewer than two distinct registrable domains.
- A counting figure is written coarser than 0.001 degree, 0.1 minute or
  1 second. Whole-minute positions cannot confirm anything at 150 m.
- Any two counting figures lie more than 150 m apart. A counting page that
  disagrees blocks the record; it is not outvoted. Cite-only figures are
  shown on the review page and never block or count.
- The entry's `lat`/`lon` is not within 10 m of the mean of the counting
  figures.

**Depth**
- The shipped maximum is the deepest counting figure and the minimum the
  shallowest counting minimum. Both are left out when the counting
  maximums spread by more than both 5 m and a quarter of the deepest
  figure (so 32 and 40 m ship 40 m; 8 and 15 m ship nothing). An entry
  that writes a shipped depth by hand fails.
- A minimum deeper than the maximum fails.

**Entry, types, hazards**
- A value with no counting source fails. A value that another counting
  source contradicts (the procedure records a contradiction as a source
  with `"contradicts": true`) is left out, not failed, and the review page
  shows it struck through.

**Text**
- No field other than `name` and `note` holds text. `name` is at most 60
  characters.

It also prints a report: entries by area and review state, every rule an
entry was saved from (a depth left empty, a type left out), and every
entry the merge would leave out for overlap (section 7).

### 5. The review page

The checker, given `--review OUT`, writes one self-contained HTML file
(no network, no scripts from elsewhere) with one row per pending entry
and, below, the approved and rejected ones folded:

```
 TULAMBEN (11 entries: 9 pass, 2 fail)

 USAT Liberty                  research_id_usat_liberty     pending
   Position  -8.27394, 115.59287   [map]
             tulambenwreckdivers.com  -8.27391, 115.59261   12 m   counting
             alertdiver.eu            8 16 28.80 S ...        31 m   counting
             yachtway.com             8 16 19 S ...        1,520 m   cite only
   Depth     5 - 30 m  (alertdiver.eu 30, tulambenwreckdivers.com 29)
   Entry     shore     (2 counting)
   Type      wreck     (3 counting)
   Hazards   Boat traffic overhead.  (1 counting)
   Ships as  "Shore dive to a wreck, 5 to 30 m."
```

- `[map]` is an OpenStreetMap link to the point at street zoom, so the
  maintainer can see the spot against the coast.
- Each source shows its distance from the shipped point.
- Failing entries are listed with the rule that failed and are not offered
  for approval.

The maintainer reads the page and answers per entry (approve, or reject
with a reason). The person running the batch writes the answers into
`review`. The page itself writes nothing.

### 6. Withdrawal

When a researched record proves wrong (a diver reports it, a later batch
finds better evidence), its evidence entry gains `withdrawn` with:

- `reason`: one of `position` (its position was wrong), `not_a_site`
  (it is not a place people dive), `duplicate` (it is a site another record
  already lists), `other`.
- `date`.
- `replaced_by`: optional, the id of the record that corrects it.

A correction is a withdrawal plus a new entry with a new id. An id is never
reused.

The merge writes `metadata.withdrawn` into the catalogue:

```json
"withdrawn": {
  "research_my_south_point": {"reason": "position", "date": "2026-12-02",
                              "replaced_by": "research_my_south_point_2"}
}
```

Withdrawals are cumulative: an id stays listed in every later catalogue.
The curated records (decision 7) can be withdrawn the same way, by an
entry in a small `withdrawn_curated` list in the same evidence file
(`{"id": "curated_...", "reason": ..., "date": ...}`); the merge then
leaves that curated entry out and lists it.

**In the app**

- The importer stores `metadata.withdrawn` as JSON under a new
  `site_catalogue_meta` key, beside `sources`. A file without it stores an
  empty list. `kSiteCatalogueImportRevision` moves, so a device holding the
  current file re-imports and gains the (empty) key.
- `SiteCatalogue` gains `withdrawal(String id)`, answering a
  `CatalogueWithdrawal` (`reason`, `date`, `replacedBy`) or null.
- On a diver's site page, the catalogue line under the header
  (`_CatalogueLine` in `site_detail_header.dart`) today shows nothing when
  the linked record is gone. When the record is gone and a withdrawal is
  listed for it, it shows one line instead:

  ```
  Built-in record withdrawn: its position was wrong.  See the corrected record >
  ```

  The second part appears only with `replaced_by` and opens the built-in
  page of that record (`/sites/catalogue/<id>`). Reasons map to fixed
  translated phrases: "its position was wrong", "it is not a dive site",
  "it listed a site twice", and for `other` the line ends after
  "withdrawn".
- The site's own fields, its link and its dives are not changed. The link
  stays (it is what lets the line appear).
- Gap-fill, the picker and the map do nothing new: a withdrawn record is
  simply absent from the catalogue, as a removed record is today.

### 7. Merge

- A new source module (`src_research.py`, name left to the builder) reads
  `research/sites.json` with no network, runs the checker's rules, and
  forms a working record from each `approved` entry that is not withdrawn:
  `source: "research"`, `kind: "site"`, name, position, computed depths,
  types, entry, the hazard sentences, the generated description, and
  `source_ref` set to the entry's address in the public repository
  (`https://github.com/submersion-app/submersion/blob/main/scripts/site_catalogue/research/sites.json`
  with a `#` fragment of the id; the builder picks a form a browser lands
  on).
- It is not a snapshot. The merge reads it from the repository on every
  run, as it reads the curated file, so `--without` does not apply and a
  merge never runs without it.
- **Overlap.** A researched record is left out whole, and the other record
  ships unchanged, when it is the same site as any other record by slice
  2's rules (same folded name within 2 km, 200 m for a generic name; two
  wrecks within 100 m), or when any dive site record (`kind: site`, any
  source) lies within 150 m of it. It never gives or takes a field. Two
  researched records are never merged; the checker fails on two entries
  within 150 m of each other unless one carries a `note` saying why both
  stand. Researched records rank last in `RANK`.
- **A shipped record never leaves silently.** When a research id that is in
  the catalogue file being replaced would now be left out for overlap (say
  OpenStreetMap has since mapped a dive site 100 m away), the merge fails,
  naming the id and the record it lost to, until the evidence entry carries
  a withdrawal (`duplicate`, with that record as `replaced_by`). The merge
  never writes a withdrawal itself.
- **Curated records keep their overlap rules.** Their rank, the 1 km
  same-name rule and the fields they take from a record they replace are
  unchanged; only their trust level moves (decision 7). The rule that a
  researched record never gives or takes a field applies to the `research`
  source.
- **Place.** Country, region and island come from the offline lookup, as
  for curated entries. A lookup answer that differs from the entry's
  `country_code` fails the merge, naming the entry (a sign of a wrong
  hemisphere or a swapped coordinate). A point the lookup cannot place
  (far offshore) takes the entry's own `country_code`, as a curated wreck
  takes its entry's country.
- **Trust.** `to_catalogue_record` takes the trust level instead of always
  writing `verified`. Research records and curated records are written
  `researched`; every other source stays `verified`.
- **Description.** One line generated from the record's own fields, in our
  words, built from entry and type and depth when present: "Shore dive to a
  wreck, 5 to 30 m.", "Boat dive on a wall, to 40 m.", "Reef dive." Nothing
  when none of the three is known. Curated descriptions are not changed.
- **Report.** The merge's report gains a `research` line (read, failed,
  pending, rejected, withdrawn, left out for overlap and to which record,
  written) and lists the withdrawn ids.
- **Metadata.** `metadata.sources.research`:

  | Key | Name | Licence | Credit |
  |---|---|---|---|
  | `research` | Submersion site research | ODbL-1.0 | Submersion site research |

  The notice names it with the others. The licence page entry "Dive site
  data" lists it and adds one sentence: researched records and the curated
  records are gathered from published dive guides and are marked "Not
  verified"; researched records cite their pages in the project's
  repository. (Curated records cite one page each, some of them
  directories, until their re-check batch.)

### 8. The mark in the app

`CatalogueSite.trust == researched` drives every item below. One shared
widget draws the label (a small outlined chip with the text "Not
verified", in the theme's warning-free secondary colour, no icon) so every
surface looks the same, and one shared string holds the sentence.

| Surface | Where today | Label | Sentence |
|---|---|---|---|
| Picker row | `site_picker/catalogue_site_tile.dart` | After the depth | No |
| Picker details card and the map's info card | `built_in_site_info_card.dart` | Beside the name | Yes, above the source line |
| Built-in site page | `catalogue_page/catalogue_site_header.dart` (kind line) and `catalogue_source_card.dart` | On the kind line | Yes, in the source card |
| Import page result | `catalogue_import_site_card.dart` | Beside the name | No |
| Gap-fill review row and comparison | `catalogue_gap_review_page` rows and `catalogue_gap_comparison_sheet.dart` | Beside the record's name | Yes, in the comparison |
| GPS match review | `site_match_review_page.dart` candidate rows | Beside the candidate's name | No |

- Map markers are unchanged (decision 5).
- The label is read by a screen reader as part of the row ("USAT Liberty,
  not verified"), not as a separate button.
- A diver's own site adopted from a researched record shows no label: it
  is theirs (program proposal). Its catalogue line shows the credit as for
  any linked site.
- A row's `ListTile.trailing` guard and the 800-line guard apply to every
  touched file.

### 9. GPS matching

`MatchCandidate` gains `isResearched`. In `matchRanked`:

- A researched candidate is never the outcome of an `AutoMatch`. When the
  nearest in the chosen pool is researched, the outcome is `Suggested`
  with every in-range candidate.
- Researched candidates still count as competitors: a verified candidate
  with a researched one inside the separation margin is not picked on its
  own (the existing rule, unchanged).
- Pools are otherwise unchanged. A researched record is a dive site
  record, so it joins the dive site pool, not the register pool.

The 55 curated records lose automatic preselection by this rule (decision
7). A dive matched to one before this slice keeps its site.

### 10. Picker, map, gap-fill, search

- **Picker.** A researched record lists in "More sites near" with verified
  dive site records, in the usual order, with its label. No other change.
- **Map.** Researched records are `kind: site` and so in the default
  built-in layer (slice 5), with the usual marker.
- **Gap-fill.** Already never ticks a researched record (slice 4). The
  label is added (section 8). No rule changes.
- **Search and the Import page.** No change to order; the label is added.

## Acceptance

1. **Pilot.** The shipped file holds between 15 and 35 `research` records
   in three areas (two when a kind found nothing, decision 8), each
   approved in `sites.json`; the PR names any area that was swapped or
   left empty and why.
2. **Every position confirmed.** For every shipped research record the
   checker passes: two counting sources on distinct domains within 150 m,
   written finer than 0.001 degree.
3. **No copied text.** No research record has a description other than the
   generated line, and the evidence file has no free text outside `name`
   and `note`.
4. **Curated.** All 55 curated records ship `trust: researched`. Every
   other source's records ship `verified`.
5. **Label.** Each surface in section 8 shows "Not verified" for a
   researched record and nothing for a verified one; the details card, the
   built-in page and the comparison show the sentence.
6. **Matching.** A dive 40 m from a lone researched record, with nothing
   else in range, is offered that record and nothing is preselected. A dive
   40 m from a verified dive site and 400 m from a researched one
   preselects the verified one.
7. **Withdrawal.** With a catalogue that lists a withdrawn id with
   `replaced_by`, a diver's site linked to that id shows the withdrawal
   line with the reason and a link that opens the replacement's built-in
   page; the site's fields are unchanged. A site linked to a removed but
   not withdrawn id shows nothing, as today.
8. **Checker in CI.** Each checker rule has a test that fails on a
   breaching entry; the checker runs on the committed file in CI.
9. **Credits.** The licence page names "Submersion site research" and
   carries the sentence of section 7.

## Testing

Tests first. At least:

- The checker, rule by rule, against small hand-written evidence files: a
  passing entry; one counting source; two on one domain; a whole-minute
  figure; two counting figures 200 m apart; a cite-only figure 2 km off
  (passes); a never-list source; an unknown domain; the depth spread rule
  both sides of its line; a contradicted type left out; a hand-written
  shipped depth; free text in a field; an id clash; two entries within
  150 m.
- Position parsing: decimal degrees, degrees minutes seconds, degrees and
  decimal minutes, hemisphere letters, and the precision each is written
  to.
- The source module and the merge: only approved, not withdrawn entries
  form records; overlap leaves a researched record out beside a verified
  dive site within 150 m and beside a same-named record within 2 km;
  nothing is given or taken; a shipped research id newly left out for
  overlap fails the merge until withdrawn; country mismatch fails and an
  unplaceable point takes the entry's code; curated overlap unchanged;
  trust written
  `researched` for research and curated; the generated description; the
  withdrawn list cumulative and in the metadata; the report line.
- The review page: written offline, one row per entry, failing entries not
  offered, distances shown.
- The importer stores the withdrawn list and an empty list for a file
  without one; `withdrawal(id)` over a real local cache database.
- The site header: the withdrawal line for each reason, with and without
  `replaced_by`; nothing for a removed record that is not withdrawn.
- Each surface of section 8: label present for researched, absent for
  verified; sentence where listed; screen reader text.
- `matchRanked`: the two cases of acceptance 6, a researched record as the
  lone inner candidate, a verified candidate with a researched one inside
  the separation margin.
- The data file (`site_catalogue_asset_test.dart`): acceptance 1, 2, 4.
- `test/architecture/`, `test/shared/` and the l10n tests after adding
  files and strings.

## Pilot result (2026-11-15)

The pilot shipped no records. Research under the rule covered the three
pilot areas and one replacement of each kind (Tulamben and Lembeh,
Sipadan with Mabul and Kapalai and Tubbataha, the Farne Islands and St
Abbs): no site had two counting pages with a written position. Local
operators, marine reserves and dive clubs describe their sites in words or
show them on map images; written coordinates appear almost only in
directories (waypoints.ph, scubaspotadvisor, agency pages), which never
count. The nearest misses had one counting position each: the Mawali
wreck in Lembeh, Black Rock at Tubbataha, the Britannia at the Farnes.

The maintainer kept the rule and shipped the code with an empty evidence
file: the mark (on the 55 curated records), the matching rule,
withdrawals and the checker in CI. Acceptance 1 is therefore not met by
this slice and waits for a batch under wider sources, which needs its own
decision on what may confirm a position. The near misses are written up
in the slice's ledger for that batch.

**Wording, after review (maintainer, 2026-11-15).** With no researched
batch, the marked records are the 55 curated ones, and ten of those come
from NOAA's wreck register or Wikipedia, not from dive guides. The
sentence (decision 5) and the licence text now say "published sources":
"Gathered from published sources, not from a survey. Check the position
locally before you rely on it."

## Known gaps after the build

- Two operators who copied one survey look independent to the checker. The
  review page shows each figure so a person can judge; nothing proves it.
- Positions are where published pages put a site, often a mooring or an
  entry point, not the whole site. A long wall or a drift has one point.
- Sites known only from guidebooks or charts (the Farnes, likely) cannot
  pass, and stay missing.
- The 55 curated records keep their single-page positions until a re-check
  batch.
- A withdrawal reaches a diver only when they open the site's page. There
  is no notice elsewhere.
- Hazard sentences cover a closed list. A hazard the list lacks is not
  recorded.

## Left to the builder

- Module, function and file names within `scripts/site_catalogue/research/`.
- The exact JSON layout of the evidence file beyond the fields of
  section 2, and how the checker reports.
- The review page's styling.
- How the label widget is themed in light and dark, within "small, outlined,
  no warning colour".
- String keys and the exact wording of the label's screen reader text.
- How `source_ref` addresses one entry in the repository.
- Whether `withdrawal` reads the meta row per call or caches it per
  catalogue revision.
