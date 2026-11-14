# Site catalogue: open-register expansion (slice 2)

Date: 2026-11-14
Status: approved 2026-11-14; first harvest shipped 20,932 records (see
"Result of the first harvest")
Program: `2026-11-13-site-catalogue-program.md`
Issue: #4514

## Intent

Slice 1 put built-in sites in the picker and moved them into a format and a
store that can hold tens of thousands of records. It shipped the same 3,667
sites as before. Off Dover the catalogue holds one site within 50 km, and off
Key Largo one.

This slice fills the catalogue from the open wreck and reef registers, so a
diver who names a charted wreck or a published artificial reef finds it with
its position and depth already there. It also cleans what is shipped today:
dive shops listed as sites, 356 sites with no position, sites in French
Polynesia filed under France, and region names in scripts most divers cannot
read.

The catalogue grows from 3,667 to about 21,400 records. The program
estimated 28,000 to 31,000. The difference is deliberate and is explained
under "What was decided".

Three terms are used throughout.

- A **dive site record** comes from a source that lists places people dive:
  OpenStreetMap's scuba tag, the curated list, the Florida Keys moorings,
  Wikidata's dive sites.
- A **register record** comes from a list of things on the seabed: a wreck
  register or a reef deployment list. The app treats the two kinds
  differently in the picker, in GPS matching and in search order.
- An **own-terms source** is one whose publisher allows reuse on terms that
  cannot be passed on under ODbL: non-commercial use only, or conditions
  that must travel with the data. Its records ship in the catalogue but are
  kept apart from the ODbL records.

## What was decided

These were chosen by the maintainer during the design conversation.

- **Defensible positions only.** A merge of every licence-clean, named,
  located record gives about 28,400. About 7,700 of those have a position or
  status that cannot be defended: wrecks that dry at low water, positions
  rounded to a whole minute from a reported sinking, positions the publisher
  itself grades low. They do not ship. The program's anti-goals ("positions
  nobody can trace or defend", "a wrong built-in position silently attached
  to a diver's real dive") outrank the headline number.
- **A section of their own in the picker.** Register records do not join
  "More sites near". They get a section below it, closed by default, that
  shows a count until the diver opens it.
- **Fetch per source, then merge offline.** One module per source downloads
  and normalises it into a local snapshot that is not committed. A separate
  merge step with no network applies the gates, the overlap rules and the
  place lookup and writes the catalogue.
- **A non-commercial term is acceptable.** Submersion is open source and
  takes no money, so a source that allows only non-commercial use is not
  excluded for that. This reverses the program's exclusion of the New Jersey
  and North Carolina reef programs, and brings in Hawaii and Texas.
- **Own-terms sources ship in the same file, kept apart.** New Jersey,
  Hawaii, North Carolina and Texas records are never blended with ODbL
  records and are not offered under ODbL (section 6).
- **North Carolina ships as published:** its 55 reef sites, unaltered.
- **States with no stated terms ship.** Alabama, South Carolina, Georgia,
  Louisiana, Mississippi, Delaware, Virginia and the small programs, about
  2,300 sites, merged into the ODbL catalogue.

## Goals

1. The catalogue holds every register record that passes the quality bar
   below, from every source the licence position allows.
2. No site appears twice because two sources list it.
3. Existing catalogue ids survive, so sites divers adopted keep their link.
4. Today's data is cleaned: businesses removed, missing positions filled,
   countries and territories correct, regions in English, more site types
   and water types.
5. Every record carries a country code where its position allows one,
   including wrecks well offshore.
6. Register records never crowd the diver's own sites or the dive site
   records in the picker.
7. The map overlay no longer reads the whole catalogue.
8. Every source is credited, and every source's own conditions are met, in
   the file, on the licence page and on a linked site's page.
9. A harvest can be rerun source by source, and its merge can be tested
   without the network, in CI.

## Non-goals

- AI-researched sites, the "not verified" badge and its matching rule
  (slice 3).
- Filling gaps in sites a diver already has (slice 4).
- Catalogue site pages, and the map showing catalogue sites by default
  (slice 5).
- Difficulty and entry type for register records. No register supplies
  them.
- Scheduled or automatic harvests. A harvest is run by hand, as today.
- Access and protection data as a structured field. A restriction a
  register states is carried as text (section 2); nothing more.
- Rebuilding the published demo package. Only a maintainer can, and the
  package already published keeps working.
- Any change to `assets/data/dive_centers.json` beyond what a re-harvest of
  OpenStreetMap writes.

## Anti-goals

- A register record preselected over a dive site record that is also close
  to the dive.
- A wreck that shows at low water, a wellhead or a patch of foul ground
  offered as a dive site.
- A site adopted before this slice losing its link because its record was
  merged into a neighbour or replaced by a better-surveyed duplicate.
- A harvest that needs every source reachable at once to produce anything.
- A row from a source the licence position excludes shipping because it
  arrived inside a file that is otherwise allowed.
- An own-terms record described anywhere as ODbL data, or a field copied
  between an own-terms record and an ODbL record.

## Constraints

- **Format.** The catalogue file stays format 2. This slice adds one
  optional per-record field and one optional per-source field (section 2).
  The app drops unknown names on read.
- **Local cache database.** Schema version 21 today. A new column needs a
  ladder step and the `beforeOpen` backstop, following the slice 1 tables.
  The data is derivable, so the step may drop and re-create the table.
- **Licence.** The program's position, as amended by this slice: the
  records that have been de-duplicated against OpenStreetMap are a
  derivative database and are ODbL. CC0, public domain, Open Government
  Licence, CC BY and unrestricted government sources merge into it. An
  own-terms source rides beside it as an independent collection. CC BY-SA
  sources, and sources that forbid redistribution, stay out.
- **Outside services.** Every request sends the client name
  `dive-site-harvester/1.0` and nothing that names a person, an address or
  the project. Today's scripts send "DiveSiteHarvester/1.0 (Submersion Dive
  Log App)"; that changes. If a service refuses the anonymous name, the
  fetch stops and says so; identifying details are never added to get past
  a refusal, and the merge can leave that source out (section 4).
- **CI.** The catalogue script tests run in CI under coverage with the
  standard library only (`.github/workflows/ci.yaml`, "Run Python guard
  tests with coverage"), and the harvester test runs after
  `pip install -r scripts/requirements.txt`. New script tests join the
  first list, with their modules in its coverage list. So everything the
  merge, the gates, the overlap rules and the place lookup need is standard
  library Python. A fetch module may use what `requirements.txt` already
  lists.
- **Units, localisation, guards, TDD, 800-line files, platform-agnostic
  paths, `dart format .`** as in slice 1. Every new string goes in all 11
  ARB files. Python is `python3.14` locally.

## Measured facts (2026-11-14)

Every source was downloaded and a throwaway merge was run. These replace the
estimates in the program's source survey. "Expected" is what the prototype
shipped from each source after its gate and after overlap.

| Source | Candidates | Expected | Notes |
|---|---|---|---|
| OpenStreetMap dive sites | 4,188 named of 4,770 | 3,400 | About 800 named objects are businesses |
| Curated | 55 | 55 | |
| UKHO Global Wrecks | 13,112 named, live, 60 m or shallower | 8,300 | 2,249 not always submerged; 2,133 coarse positions; 646 not wrecks; 1,429 in under 2 m |
| Florida FWC reefs | 4,548 deployments | 3,200 | Grouped by name into sites; 130 sites deeper than 60 m |
| Other states' reefs, federal file | 4,626 rows outside NJ, NC, FL, NY, HI, TX | 2,300 | Alabama is 1,937 of them |
| OpenStreetMap wrecks | 1,811 named, not scuba-tagged | 1,050 | 539 show at high tide or show hull or mast |
| Wikidata | 328 dive sites; 2,236 wrecks with a Wikipedia article | 1,170 | 275 dive sites; 935 of 1,830 wreck positions are whole minutes |
| New Jersey reefs | 3,828 deployments | 600 | Own terms |
| NOAA AWOIS | 2,376 with a real name | 560 | 1,734 graded Low or Poor; 150 reported removed |
| Ireland wreck inventory | 1,663 named with coordinates | 500 | 590 positions are from wrecksite.eu, 38 from uboat.net |
| Florida Keys moorings | 509 moorings | 92 | Grouped by reef or wreck name |
| North Carolina reefs | 55 sites | 55 | Own terms; as published |
| Hawaii, Texas reefs | 58 rows | 45 | Own terms |
| NOAA ENC wrecks | 17,871 | 0 | 95 distinct names in all |
| New York reefs | 16 rows | 0 | Terms forbid distribution |
| SHOM (France) | 4,787 | 0 | CC BY-SA 4.0 |

Expected total: about 21,400. Overlap removed by the prototype: about 1,400
records. About 3,800 are dive site records and 17,600 register records.

**The gates decide, not the counts.** A harvest runs against live sources and
will not reproduce these numbers exactly. When a source lands more than a
tenth away from its expected count, the PR says why. The asset test pins the
exact total only after the harvest is final.

### Result of the first harvest (2026-11-14)

The harvest wrote 20,932 records: 3,931 dive site records and 17,001
register records.

| Source | Expected | Written | Why it differs |
|---|---|---|---|
| OpenStreetMap dive sites | 3,400 | 3,471 | |
| Curated | 55 | 55 | |
| UKHO Global Wrecks | 8,300 | 8,133 | |
| Florida FWC reefs | 3,200 | 3,528 | The prototype matched names more loosely and merged more deployments |
| Other states' reefs, federal file | 2,300 | 2,297 | |
| OpenStreetMap wrecks | 1,050 | 840 | Wrecks that show at low tide are dropped too; 39 were named only "wreck" in another language; 109 lie on dry land |
| Wikidata | 1,170 | 998 | 34 wrecks lie on dry land; 34 share a point with two or more others |
| New Jersey reefs | 600 | 615 | |
| NOAA AWOIS | 560 | 464 | The register writes "Wreck - Visible"; 61 such rows and 87 reported removed are gated |
| Ireland wreck inventory | 500 | 349 | 140 are the same wreck as a UKHO record, which is kept; 90 positions are whole minutes written in decimals |
| Florida Keys moorings | 92 | 96 | |
| North Carolina reefs | 55 | 55 | |
| Hawaii, Texas reefs | 45 | 31 | 20 Hawaii rows are corner markers of a reef area, not structures |

Of the 3,667 ids shipped before, 331 are gone, all from OpenStreetMap: 257
are businesses, 71 are no longer in OpenStreetMap and 3 have lost their
name. No curated id is gone. 283 dive sites that had no position now have
one.

Rules the harvest added to the ones above, each found in the real data: a
register row that repeats an id ships once; a name of a single letter or
digit is a placeholder; the corner markers of a reef area are not
structures; and the word for a wreck alone, in any language OpenStreetMap is
mapped in ("Wrack", "Naufragio", "Épave"), is a placeholder.

Rules added after the whole-branch review: a wreck from OpenStreetMap or
Wikidata ships only when it does not lie on dry land by the offline
boundaries (inside a country, outside every lake, more than 5 km from any
coast, border or shore), which leaves out crashed aircraft on mountains
and hulls in museums, and with them wrecks in rivers the boundaries do not
draw; the hydrographic registers are not asked. An Irish position in whole
minutes is coarse whoever it is credited to (24 scuttled U-boats shared
one). No record ships at 0, 0 or outside the globe, whatever a register
writes.

And from the review's smaller findings: three or more wrecks that one
wreck register files on one exact point are an area, not three positions,
and are left out (64 records; reef programs are not asked, since they do
place several structures at one point). A UKHO depth of zero is no depth.
An AWOIS wire-drag clearance is not a depth. Folding also drops "HMHS",
spelled-out prefixes ("H.M.H.S."), the word for a wreck in German,
Spanish and Italian, and "No." before a hull number. A name with
"einstieg" in it is a way into the water, not the dive centre it is named
for. In section 5, a curated site that steps aside for OpenStreetMap gives
it nothing, and a survivor's own types stand. In section 10, a register
record is not picked on its own when a dive site lies within the
separation margin behind it, even outside the inner radius.

At 28,369 records (the larger, rejected set), on a desktop in a debug build:
import took 268 ms to parse and name seas and 269 ms to insert (72 ms and
86 ms for today's file); the local cache grew from 1.2 MB to 7.7 MB; `near`
at 50 km answered in under 5 ms and `search` in 2 to 13 ms. The file was
7.1 MB with one record per line, 10.2 MB indented, 0.8 MB compressed.

Register records within 50 km at the shipped bar: Dover 339, Scapa Flow 166.
The densest water is off Alabama, where one block of 150 km holds about
2,300 reef structures.

## Approaches considered

The fork was how the sources reach one file.

| | A. Fetch, then merge offline | B. The same, snapshots committed | C. Extend the one script |
|---|---|---|---|
| How | A module per source writes a normalised snapshot outside the repository; a merge step with no network writes the catalogue | As A, with the snapshots in the repository | Each register added to `dive_site_harvester.py` and its single run |
| For | A failed download costs one source; the merge reruns in seconds and is tested directly; each parser is tested on a few sample rows | Anyone rebuilds the shipped file with no network; a test can prove file equals merge | Least new structure |
| Against | A rebuild from nothing needs the network | About 6 MB more in the repository on every refresh; raw register rows in the repository | Every run needs every source; the script is 930 lines now; the merge rules are only testable through a full run |

**Chosen: A**, by the maintainer.

A second fork was how own-terms records travel: in the same file kept apart
(chosen), in a second asset file (a physical boundary, at the cost of a
second asset, sidecar and import path), or merged like any source (rejected:
the file would promise commercial reuse that Hawaii, North Carolina and
Texas did not grant).

## Design

### 1. Sources and their gates

A record needs a name that is not a placeholder (appendix B) and must pass
its source's gate. A register record also needs a position. Appendix A gives
each source's address, format and the fields behind every gate.

| Source key | What ships | Gate |
|---|---|---|
| `osm` (dive sites) | Objects tagged `sport=scuba_diving` | Not a business (section 3) |
| `osm` (wrecks) | Named objects tagged `historic=wreck`, `seamark:type=wreck` or `wreck:type`, not scuba-tagged | Not `wreck:visible_at_high_tide=yes`; seamark category not hull showing, hull visible or mast showing; `access` not `no` or `private`; not a car, jeep or van; a stated depth of 60 m or less when one is stated |
| `curated` | `scripts/dive_sites_curated.json` | As today |
| `ukho` | UKHO Wrecks and Obstructions text file | Status not dead, lifted or existence doubtful; always under water; a wreck category and no obstruction category; type not wellhead, crane, anchor or fisherman's fastener; position written to 0.01 minute or finer, or a stated fixing method; charted water depth 2 to 60 m; comments do not say diving is prohibited |
| `fwc` | Florida artificial reef deployments | Water depth 60 m or less |
| `noaa_reefs` | MarineCadastre Artificial Reefs | State not FL, NJ, NC, NY, HI or TX; water depth 60 m or less |
| `fknms` | Florida Keys buoys | Buoy type Mooring, Mooring Wreck or Mooring-LV |
| `awois` | AWOIS wrecks | Position quality High or Med; feature type not "Wreck, visible"; the last 600 characters of the history do not say removed, salvaged, refloated, disproved, not found or delete; a stated depth of 60 m or less when one is stated |
| `nms_ie` | Wreck Inventory of Ireland | Position source is stated and is not wrecksite.eu, uboat.net, Lloyd's List, BVLS or Parliamentary Papers; position written to three decimals or finer |
| `wikidata` (dive sites) | Instances of underwater diving site | None |
| `wikidata` (wrecks) | Shipwrecks and ships with a wrecking or scuttling event | Has a Wikipedia article in any language; coordinate precision finer than one arc-minute |
| `njdep` | New Jersey reef deployments, from the state's own layer | None beyond the name and position |
| `hi_dar`, `tpwd` | Hawaii and Texas rows of the MarineCadastre file | Water depth 60 m or less |
| `nc_dmf` | North Carolina's 55 reef sites, from the state's own reef guide | None |

Notes on particular sources:

- **The federal reef file** is a compilation of state data. Its Florida rows
  are FWC's records as of 2022 and are dropped for FWC's newer file. Its New
  Jersey rows are dropped for the state's own layer, which carries the
  agreement the data is distributed under. Its North Carolina rows (17,946)
  are unnamed and are dropped; the state's own reef guide supplies its 55
  sites. Its New York rows are dropped: New York's terms forbid
  distribution. A script test fails if a New York row, or a Florida, New
  Jersey or North Carolina row of the federal file, reaches the merge.
- **AWOIS** was retired by NOAA and its download host no longer answers.
  The harvester reads the Internet Archive's copy of NOAA's own file, and
  the record's `source_ref` says so. The data stopped changing in 2016.
- **NOAA ENC wrecks and SHOM** are not harvested.
- **Wikidata's dive sites** are 277 South African sites of 328, entered by
  one contributor whose Wikivoyage dive guide the program excludes as
  CC BY-SA. Wikidata publishes its structured data as CC0 and the program
  lists it as usable; this note records the connection.

### 2. Records

**New fields.**

| Where | Field | Notes |
|---|---|---|
| A record | `kind` | `register` for a register record. Left out for a dive site record. Any other value is read as a dive site record. |
| A `metadata.sources` entry | `own_terms` | A one-sentence statement of the publisher's terms, present only for an own-terms source. Read by the scripts and the tests; the app does not need it. |

Which records are register records: every `ukho`, `awois`, `fwc`,
`noaa_reefs`, `nms_ie`, `njdep`, `hi_dar`, `tpwd` and `nc_dmf` record; `osm`
records harvested as wrecks; `wikidata` wrecks. Everything else is a dive
site record. When a dive site record and a register record are the same site
(section 5) the survivor is a dive site record.

All records are `trust: verified`.

**Ids.** An id is built from the register's own identifier where it has one,
and never from another record's presence, so adding a record cannot rename
an existing one.

| Source | Id |
|---|---|
| OpenStreetMap, both kinds | `osm_<type>_<id>` (unchanged) |
| Curated | `curated_<...>` (unchanged) |
| UKHO | `ukho_<wreck_id>` |
| AWOIS | `awois_<RECRD>` |
| FWC | `fwc_<DeployID>`, the lowest-sorting id of the deployments grouped into the site |
| Federal reef file, any state | `usreef_<state>_<name slug>_<position rounded to 0.1 degree>` |
| New Jersey | `njreef_<UNIQUE_ID>`, the lowest of the deployments grouped into the site |
| North Carolina | `ncreef_<reef number>` |
| Florida Keys | `fknms_<location slug>` |
| Ireland | `ie_<Wreck No>` |
| Wikidata | `wikidata_<Q id>` |

A grouped site's id can still change when its register renumbers or a later
deployment sorts lower. To make that visible, the merge compares its output
with the catalogue file it is about to replace and reports the ids that
disappeared and the ids that are new, by source. The PR quotes that list.

**Names.**

- UKHO and AWOIS names are upper case. They are written in title case with
  ship prefixes and designations kept as written: "HMS EXETER" becomes "HMS
  Exeter", "U 11" stays "U 11", "TB. TECE-1" stays as written apart from
  case.
- UKHO's own doubt stays in the name, lower-cased: "Moravia (possibly)".
  It is the register's statement about the wreck's identity, not ours.
- A part of a wreck ("(BOW SECTION)", "(STERN SECTION)") folds into the one
  wreck (section 5).
- Ireland's type suffix ("Ardmore (SS)") is dropped.
- A Florida Keys location loses a leading "The".
- A New Jersey vessel is named by the vessel, with its reef site as the
  record's `locality` ("Cape May Reef"). Any other New Jersey deployment
  carries the reef site in its name ("Cape May Reef, subway cars").
- A North Carolina site keeps the state's name for it, or its reef number
  ("AR-130") when it has no name.

**Grouping.** A reef program lists deployments, not sites: "Rube Allyn Reef"
is 29 rows. Deployments of one name within 1 km of each other become one
record at their mean position, with the deepest stated water depth. This
applies to FWC, the federal file and New Jersey. The Florida Keys moorings
are grouped by location name, at the mean of the buoys. North Carolina's
sites are not grouped or moved.

**Depth.**

| Source | `max_depth_m` | `min_depth_m` |
|---|---|---|
| UKHO | Charted water depth | Least depth over the wreck, when it is less |
| AWOIS | The stated least depth, when above zero: a lone depth is the maximum, as in slice 1 | Not set |
| FWC | Water depth | Water depth less relief, when relief is stated and positive |
| Federal reef file | Water depth | Not set |
| Florida Keys | Deepest buoy | Shallowest buoy, when a site has more than one and they differ |
| OpenStreetMap wrecks | The stated depth | Not set |
| New Jersey, North Carolina, Ireland, Wikidata | Not set | Not set |

Feet and fathoms are converted. A depth of zero is no depth.

**Types.** UKHO, AWOIS, Ireland, OpenStreetMap wrecks and Wikidata wrecks
are `wreck`. Reef records are `artificial_reef`, and also `wreck` when the
material is a vessel. Keys moorings are `wreck` for a wreck mooring and
`reef` otherwise.

**Description.** A register record gets one short factual line built from
the register's own fields, in our words: the vessel type and the year lost
for a wreck ("Steam ship, lost 1916"), the material and the year placed for
a reef ("Concrete modules, placed 2014"). Nothing is written when the fields
are empty. The register's free text is not copied. North Carolina records
get no description.

**Restrictions a register states.** Among the UKHO records that pass the
gate, 62 say in their comments that the wreck lies in a restricted area, 61
that something is prohibited there, and 82 mention military remains.

- A record whose comments say diving itself is prohibited does not ship
  (the gate in section 1; 7 records, and the "no fishing, diving, anchoring"
  areas).
- Any other record whose comments state a restriction or a protection
  carries the register's own sentence as its `hazards`, in sentence case
  and cut to that sentence: "Restricted area 300 m radius. Fishing and
  anchoring prohibited." It is the source's statement, as OpenStreetMap's
  hazard tag is, and adoption copies it like any hazard. No fixed sentence
  of ours is written.
- The register's "dangerous wreck" is a term about surface navigation and
  is not a hazard.

**Source reference.** A link a person can follow to the record or its
publisher: the OpenStreetMap object, the Wikidata item, the UKHO data
portal, the FWC, MarineCadastre, New Jersey or North Carolina item, the
state program's own page for a federal-file record, the sanctuary's buoy
page, the inventory's data page, the archived AWOIS file.

### 3. Cleaning today's data

- **Businesses.** An OpenStreetMap object is a business, and is not a
  catalogue site, when it carries `amenity=dive_centre`, any `shop`, `club`
  or `office` tag, a `scuba_diving:courses`, `rental`, `filling` or `repair`
  tag, `tourism` of hotel, guest house, hostel or resort, or `leisure` of
  sports centre, fitness centre, pitch, swimming pool or resort; or when its
  name reads as a dive centre, shop, club or school. An object tagged
  `scuba_diving:divespot=yes` is a site whatever else it carries. Dive
  centres keep going to `dive_centers.json` as today.
- **Positions.** The 356 records with no position are ways and relations
  whose geometry the query did not return. The query asks for each object's
  centre. A dive site record that still has no position ships as today,
  found by search only.
- **Types and water.** OpenStreetMap's own tags fill `types` and
  `water_type` where they say something: `historic=wreck` (wreck),
  `natural=reef` (reef), `natural=cave_entrance` (cave), `natural=spring`
  (spring), a lake or quarry tag (lake, quarry, fresh water). Any record
  from any source whose position lies inside a Natural Earth lake is fresh
  water. This narrows slice 1's known gap (lakes near tidal water given a
  sea) and does not close it: a plain node in a small lake still carries
  nothing.
- **Countries, territories, regions** (section 7).
- **Removed ids.** A record that leaves the catalogue leaves any site
  adopted from it untouched. Its credit line stops showing, as slice 1
  designed for a record that no longer exists.

### 4. Harvester

Layout under `scripts/`, names left to the builder:

- **A fetch module per source.** It downloads the source, applies nothing
  but parsing and unit conversion, and writes a snapshot: the fetch date,
  the source URL, and one normalised working record per row, with the raw
  fields the gates need (status, water level, position precision, quality
  grade, coordinate source, state). Snapshots go in a cache folder that is
  ignored by git. Each module runs alone.
- **Geocoding belongs to the OpenStreetMap fetch.** That module asks the
  geocoder for each dive site's place through the existing cached resolver
  and stores the answer in its snapshot. Nothing else uses the geocoder.
  Curated entries are placed by the offline lookup in the merge, with the
  entry's own country as the fallback, so the merge needs no network at
  all.
- **A merge step.** It reads every snapshot present, applies the gates
  (section 1), cleaning (3), grouping and naming (2), overlap (5), the
  own-terms rules (6), country and region (7), and writes the catalogue and
  its sidecar through `write_catalogue`. It uses no network. It refuses to
  run when a snapshot is missing, unless told which sources to leave out.
- **An open-only switch.** The merge can write the catalogue without any
  own-terms source: the ODbL database alone, for anyone the ODbL offer
  reaches and for anyone redistributing commercially. The shipped file is
  the full one.
- **A report.** The merge prints, per source: rows read, rows dropped by
  each gate, records lost to overlap and to which source, records written;
  then the ids gone and new against the file it replaces. The PR
  description quotes it.
- `dive_site_harvester.py` keeps writing `dive_centers.json`, and its CI
  test keeps running. Its site half becomes the OpenStreetMap fetch module.
- `curated_sites.py` keeps its validation and its rule (section 5).
  `curated_sites_test.py`, `site_catalogue_format_test.py` and
  `site_country_resolver_test.py` stay green in CI through the refactor.

The file is written as plain JSON with the metadata on the first lines and
then one record per line, sorted by id, so a refresh shows in a diff as the
records that changed. It is not compressed: the installer compresses it for
download (0.7 MB), the app already ships 17 MB of tide grids, and a
compressed file cannot be reviewed.

### 5. Overlap

Two records are the same site when either holds:

1. **Same name, near.** Their folded names are equal and they lie within
   2 km. Folding lower-cases, strips accents, drops bracketed text, drops
   the ship prefixes and trailing words in appendix B. For a generic or
   very short folded name (appendix B, or under four letters) the distance
   is 200 m. A name that merely begins with another is a different site:
   the prototype's looser rule swallowed 179 New Jersey deployments into
   the reef they lie on.
2. **Two wrecks, one place.** Both are typed wreck, come from different
   sources, at least one is a register record, and they lie within 100 m,
   whatever their names.

**Dive site sources are never merged among themselves.** No OpenStreetMap
dive site is merged with another OpenStreetMap dive site, and no curated
site with another curated site. Slice 1 found 423 of them within 150 m of
another under a different name, and a looser rule would drop about 30 ids
divers may hold ("Portsea Pier" and "Portsea Pier West Reef"). One existing
rule stays exactly as it is: a curated entry steps aside when an
OpenStreetMap dive site of the same name (ignoring case) lies within 1 km.

**Which record survives**, first match wins:

1. OpenStreetMap dive sites
2. Curated
3. Florida Keys moorings
4. Wikidata dive sites
5. FWC reefs
6. Federal reef file
7. UKHO
8. AWOIS
9. Ireland
10. OpenStreetMap wrecks
11. Wikidata wrecks
12. Own-terms sources (section 6)

Within one source, the lower id.

The order puts records that are about diving first, then registers by how
well they fix a position. An OpenStreetMap dive site id never loses. A
curated id loses only to an OpenStreetMap dive site, as today.

**What the survivor takes.** It keeps its own id, name, position, source
and source reference. It takes from the record it replaced a maximum and
minimum depth, site types, a description and a hazards text, each only
where its own is empty. The prototype filled a depth this way on about 85
records. The credit shown for the site stays the survivor's; every source is
credited on the licence page. Own-terms records are the exception: nothing
is taken from them and they take nothing.

### 6. Own-terms sources

`njdep`, `hi_dar`, `tpwd` and `nc_dmf`. Their publishers' terms are in
"Licence findings".

- **Kept apart.** An own-terms record never gives a field to another record
  and never takes one. Where it is the same site as any other record by the
  rules of section 5, the own-terms record is left out whole and the other
  record ships unchanged. Two own-terms records of one source are grouped
  by that source's own rule (section 2) and otherwise left alone.
- **Marked.** Each own-terms source's `metadata.sources` entry carries
  `own_terms`, its licence and its credit. The file's notice says the ODbL
  covers the database except the records of those sources, names each with
  its terms, and says that the Hawaii, North Carolina and Texas records may
  not be used commercially.
- **Not in the ODbL offer.** The open-only switch (section 4) writes the
  ODbL database without them.
- **North Carolina is unaltered.** The record is the state's name or number
  and its published position. Nothing is regrouped, renamed, described or
  filled. The catalogue's own fields (country, region, kind, type) are
  added beside it.
- **New Jersey's metadata travels.** NJDEP's metadata document for the
  layer is committed beside the catalogue and ships in the app bundle, and
  the licence text points to it. Positions are used as the layer publishes
  them (NAD83 decimal degrees).
- **The app's licence does not cover them.** The README's licence section
  gains a short data notice: the bundled site catalogue is not under the
  GPL, most of it is ODbL, and the records of the own-terms sources stay
  under their publishers' terms, some of which forbid commercial use.
- In the app these are ordinary register records.

### 7. Country, territory, region and island

- **Register records and curated entries** are placed offline against
  Natural Earth 1:10m boundaries (public domain), downloaded by a fetch
  step into the cache. A point inside a unit takes that unit. A point at
  sea takes the nearest unit within 370 km (200 nautical miles); farther
  out it has no country. The prototype placed 13,112 positions in 2.6
  seconds with a geometry library; the standard-library version may take
  minutes and caches its answers. The same work through the geocoder would
  take about 7 hours and return nothing in open sea.
- **A territory with its own ISO 3166-1 code keeps that code**, for every
  source, as slice 1 decided for the Caribbean Netherlands. The unit layer
  is Natural Earth's map subunits, which holds territories apart from
  their parent states. So a wreck off Guernsey is `GG`, a reef off Puerto
  Rico is `PR`. A unit with no code of its own takes its parent's.
- **OpenStreetMap dive sites** keep the geocoder's answer, because the
  coarse offline boundaries misplace about 40 of today's sites near borders
  (Lake Constance, the Red Sea coast, the St Lawrence). Two corrections
  apply. Where the offline lookup puts the point inside a territory with
  its own code and the geocoder gave that territory's parent state, the
  territory wins. In today's file this moves 31 French Polynesia sites, 16
  in Guadeloupe, 4 in Martinique, 3 in New Caledonia, 2 each in Guam and
  Réunion, and 1 each in Mayotte and the Cocos Islands. Where the geocoder
  has no answer, the offline lookup is used: 36 located sites gain a
  country.
- **The English name** for a code must read back to that code through the
  app's `countryCodeFor`, as the asset test already demands. The merge
  fails, naming the country, when one does not.
- **Region** for every located record is the English name of the Natural
  Earth first-level unit it lies in, or the nearest one of its own country
  within 50 km. This replaces today's regions, many of which are in Thai,
  Arabic, Dhivehi or Japanese script. A curated entry's own region stands.
- **Island.** `SUBDIVISION_ISLANDS` stays, keyed by ISO 3166-2 code, and is
  fed by the offline unit's code as well as the geocoder's.
- **Sea names** are still written by the app at import and not stored in
  the file. Nothing about the sea table or the search text changes, so
  `kSiteCatalogueImportRevision` moves only if the builder changes how a
  record becomes a row in a way the file's own hash does not capture.

### 8. Catalogue storage and interface

- `site_catalogue` gains the record's kind. Local cache ladder 21 to 22
  with the `beforeOpen` backstop.
- `CatalogueSite` gains the kind.
- `SiteCatalogue.near` takes the kind to return: dive site records,
  register records, or both. The picker's existing section asks for dive
  site records. GPS matching asks for both.
- A count of the records of one kind within a radius, which reads no rows
  into objects.
- `SiteCatalogue.inBounds(bounds, limit)` replaces `allWithCoordinates()`,
  which is removed. Over the limit it returns dive site records first, then
  register records nearest the centre, and says that it was cut short.
- `SiteCatalogue.search` gains one tie-break: within each of its four
  groups (name match in the area, name match elsewhere, place match in the
  area, place match elsewhere), dive site records come before register
  records. A country or sea chip on the import page then lists that place's
  dive sites before its charted wrecks.

### 9. Picker

```
 YOUR SITES NEAR SCAPA FLOW
   Churchill Barriers   shore  12 m

 MORE SITES NEAR SCAPA FLOW
   Blockship Tabarka    boat   18 m  wreck  (i)
   Inganess Bay         shore   9 m         (i)
   Show all 11

 WRECKS AND REEFS NEAR SCAPA FLOW
   Show 166 charted wrecks and reefs   >

 (the diver's other sites, grouped by country)
```

- "More sites near" lists dive site records only, otherwise unchanged.
- Below it, a section for register records within the same 50 km of the
  same anchor. Closed, it is one row with the count. With no register
  record in range the section is absent.
- Opened, it lists the records in place: nearest first with distances for
  a measured anchor, by name for an inferred one, the same rule as the
  section above. It holds at most the 200 nearest the anchor; past that a
  caption says to search for the rest.
- The label follows the section above: "Wrecks and reefs near <place>" or
  "Wrecks and reefs nearby".
- The same two hiding rules apply (by link, by 150 m of an unlinked site of
  the diver's).
- Rows, the details card and adoption are the same as for any catalogue
  site.
- Search is one list as today. The planner, which passes no anchor, shows
  register records by search only.
- The filter picker and the media review picker still show no built-in
  sites.

### 10. GPS matching

Register records are matched like any verified record: offered within the
outer radius, and preselected when one stands alone inside the inner
radius. One rule is added to the existing order of preference: a diver's
own site inside the inner radius beats everything, as today; then a dive
site record inside the inner radius beats a register record there. Only
when no dive site record is inside the inner radius can a register record
be preselected.

### 11. Map overlay

- The built-in overlay loads the catalogue sites in the visible bounds,
  again after the map stops moving, through `inBounds`. It holds at most
  1,500 markers.
- When the bounds hold more, a caption on the map says to zoom in to see
  every built-in site.
- Markers, clustering, the info card and "Add to my sites" are unchanged.
  The overlay stays off by default and still resets each launch.
- The selected site's card reads its record by id, not by searching the
  loaded list.

### 12. Credits

`metadata.sources` gains a key per source. The `credit` is the short form
shown on a linked site's page and on the details card.

| Key | Name | Licence | Credit |
|---|---|---|---|
| `ukho` | UK Hydrographic Office Wrecks and Obstructions | OGL-UK-3.0 | UK Hydrographic Office |
| `awois` | NOAA Automated Wreck and Obstruction Information System | CC0-1.0 | NOAA Office of Coast Survey |
| `fwc` | Artificial Reefs in Florida | Public domain | Florida Fish and Wildlife Conservation Commission, FWRI |
| `noaa_reefs` | MarineCadastre Artificial Reefs | Public domain | NOAA Office for Coastal Management and BOEM |
| `fknms` | Florida Keys National Marine Sanctuary buoys | US Government work | NOAA Florida Keys National Marine Sanctuary |
| `nms_ie` | Wreck Inventory of Ireland Database | CC-BY-4.0 | National Monuments Service, Government of Ireland |
| `wikidata` | Wikidata | CC0-1.0 | Wikidata |
| `njdep` | Artificial Reef Deployments in New Jersey | NJDEP Data Distribution Agreement | New Jersey Department of Environmental Protection |
| `hi_dar` | Hawaii artificial reefs | Non-commercial use | Hawaii DLNR Division of Aquatic Resources |
| `tpwd` | Texas artificial reefs | Non-commercial use, with credit | Texas Parks and Wildlife Department |
| `nc_dmf` | North Carolina Artificial Reef Guide | Non-commercial use, unaltered, with citation | N.C. Division of Marine Fisheries |

- `metadata.notice` and the licence page entry "Dive site data" name every
  source with its licence and link, in one text block as the bathymetry
  entry does.
- For UKHO the text is the statement the publisher asks for: "Contains
  public sector information, licensed under the Open Government Licence
  v3.0, from the UK Hydrographic Office."
- For New Jersey the text carries the agreement's own credit and
  disclaimer, with "application" for the kind of product: "This application
  was developed using New Jersey Department of Environmental Protection
  Geographic Information System digital data, but this secondary product
  has not been verified by NJDEP and is not state-authorized or endorsed."
- For Hawaii, North Carolina and Texas the text says the records remain
  the state's, may not be used commercially, and (North Carolina) are
  reproduced without alteration from the Division of Marine Fisheries'
  reef guide.
- The notice says once, for all of it, that the data is not for navigation.
  UKHO, FWC, NOAA, the sanctuary and most states ask for this.
- FWC asks that its data not be presented as anyone else's and that its
  metadata travel with it: the licence text names FWC-FWRI as the producer
  of those records and links its metadata.
- A federal-file record's `source_ref` is its state program's page, so the
  state is credited beside NOAA and BOEM.
- Natural Earth is public domain and asks for no credit. The script's
  header names it.
- `docs/user/dive-sites.md` describes the register section and lists the
  sources.

### 13. Demo data generator

`tool/demo_data` picks trip sites from the catalogue by exact country code
and exact region string (`src/story/destinations.dart`), and this slice
rewrites both: the Guadeloupe destination is keyed `FR`, and seven
destinations name regions in Arabic, Dhivehi, Thai or Japanese script. So:

- It reads dive site records only. Demo trips stay on dive sites.
- Its destinations are re-keyed to the new codes and English regions, and
  to the destination's area circle alone where the offline boundaries have
  no matching first-level unit.
- Its own tests (`test/tool/demo_data/`, at least six sites per
  destination) stay green. The sites it picks may change.
- The 20 `curated_nj_*` ids it names stay in the catalogue; its tests fail
  if one steps aside.

## Licence findings

Checked on 2026-11-14 from each publisher's own pages.

**Own-terms sources.**

| Source | The operative words | Where | Reading |
|---|---|---|---|
| New Jersey (NJDEP) | "Digital data received from the NJDEP may not be reproduced or redistributed without all the metadata provided." Products must carry the credit and disclaimer quoted in section 12. "Any reproduction or manipulation of the above data must ensure that the coordinate reference system remains intact." | The layer's Data Distribution Agreement, `arcgis.com/sharing/rest/content/items/862307fcb54b4f70a6bdb9915d4c149f?f=json` | Redistribution allowed on conditions. Not a non-commercial term. |
| Hawaii | "Duplication or use of any content from this web site for commercial purposes ... is prohibited." Users agree not to "use for commercial purposes, or resell ... any of the data derived from these Services". | `portal.ehawaii.gov/page/terms-of-use/` | Commercial use forbidden. Nothing grants or forbids non-commercial copying; the footer reserves all rights. |
| North Carolina | The State "grants permission to copy and distribute non-image files, documents, and information for non-commercial use, provided they are copied and distributed without alteration and appropriately cite to the source." | `nc.gov/disclaimer-terms-use` | Non-commercial, and unaltered, with citation. The maintainer chose to carry the sites as published. |
| Texas | "No portion of this work may be sold, either by itself or as part of larger work, without the express written permission of the TPWD." Non-commercial or educational use is allowed where "the agency is given full credit". | `tpwd.texas.gov/site/policies/copyright-policy` | Non-commercial with credit. |

New Jersey's general notice (`nj.gov/nj/legal.shtml`) adds that anyone "may
view, copy or distribute State information found here without obligation to
the State" unless particular material says otherwise. The Fish and Wildlife
reef page itself returns nothing to an automated reader, so any further
wording on it is unverified.

**The app and "non-commercial".** Submersion is GPL-3.0 and is free on the
App Store and Google Play, with no advertising, purchases, subscription or
donations. Neither Hawaii nor North Carolina defines "commercial". Two
things follow from the GPL: anyone may sell a copy or a fork, so the data
notice (section 6) says the own-terms records are not covered by the app's
licence, and the open-only switch gives such a redistributor a clean file.
If the app ever takes money, this needs another look.

**Why they cannot simply be merged.** ODbL lets every recipient reuse the
database commercially, and requires nothing about metadata or disclaimers
beyond keeping notices. Hawaii, North Carolina and Texas did not grant
commercial reuse. OpenStreetMap's Collective Database Guideline treats
datasets kept independent as a collective database, where share-alike
"only applies to the parts containing or derived from OSM-data", and warns
that a list de-duplicated against OpenStreetMap "may be subject to the ODbL
share-alike terms". Section 6 follows from that.

**States with no stated terms** ship through the federal file, which NOAA
publishes as public domain: Alabama, South Carolina, Georgia, Louisiana and
Mississippi state no licence and no restriction, only liability and
navigation disclaimers. South Carolina asks that acknowledgment "would be
appreciated". Delaware's portal calls its data "public data". Maryland's
"can be freely distributed as long as the metadata entry is not modified or
deleted". California's state material is "considered in the public domain".
Alabama has no source citation in the federal metadata at all; the state's
own page publishes the same list with no terms.

**Stays out.** New York: "Any other use, including the reproduction,
modification, distribution, transmission, republication, display, or
performance is prohibited" beyond educational use
(`dec.ny.gov/about/website-usage-and-policies/website-content-usage`).
SHOM: CC BY-SA 4.0. wrecksite.eu, uboat.net and WannaDive: proprietary.
Diveboard was not re-checked.

## Calls the designer made

The maintainer decided the quality bar, the picker section, the harvester
shape, that a non-commercial term is acceptable, how own-terms records
travel, how North Carolina is carried, and which reef states ship.
Everything else is the designer's call. The ones most worth checking:

- The gates themselves, source by source (section 1): 0.01 minute as the
  line for a UKHO position, 2 m as its shallow limit, 60 m as the deep
  limit everywhere, one arc-minute for Wikidata.
- New Jersey is treated as an own-terms source although its terms are not
  non-commercial, because its metadata and disclaimer must travel with it.
- Hawaii and Texas come from the federal file's rows; New Jersey and North
  Carolina from the states' own layers.
- AWOIS is read from the Internet Archive's copy of NOAA's file.
- Alabama's 1,937 reef structures ship although most are named by
  inventory code ("Pmid 07-046"). Their positions are good and divers use
  the program's names; they live in the closed section.
- The overlap distances and the order of survivors (section 5), and the
  survivor taking a missing depth, type, description or hazard from the
  record it replaced while showing only its own credit.
- Dive site sources are never merged among themselves.
- Register records are preselected by GPS matching, behind dive site
  records (section 10).
- A one-line generated description, and UKHO's "(possibly)" kept in the
  name (section 2).
- A wreck where diving is prohibited does not ship; any other stated
  restriction ships with the register's own sentence as its hazard.
- A territory keeps its own code for register records too, so a search for
  "United Kingdom" does not list Guernsey's wrecks (section 7).
- The geocoder's answer stands for OpenStreetMap dive sites, with the
  offline lookup everywhere else.
- Regions are replaced with English names from the offline boundaries.
- The broad definition of a business (section 3), which removes about 800
  objects where a narrower tag list would remove about 520.
- The file is uncompressed, one record per line (section 4).
- The register section lists at most 200 rows, and the map overlay 1,500
  markers.
- The demo data generator ignores register records and its destinations
  are re-keyed; the published demo package is not rebuilt by this slice.
- Everything the merge needs is standard library Python, so its tests run
  in CI.

## Known gaps after the build

- No depth on New Jersey, North Carolina, Ireland and Wikidata wreck
  records and on most AWOIS records, so the 60 m limit cannot be applied to
  them. A notable wreck in deep water can be found by name.
- An own-terms record that is the same site as an ODbL record under a
  different name more than 100 m away ships beside it.
- Protected wrecks carry a warning only where UKHO's comments say so. A
  wreck protected by a law the register does not mention carries nothing.
- Register positions are the register's. A UKHO position passed the gate
  because it was written precisely or fixed by a stated method, which is
  evidence of a good position and not proof.
- Two registers that list one wreck under different names more than 100 m
  apart both ship.
- A record's credit names one source even when a depth came from another.
- Regions for offshore records are the nearest land's, which a diver may
  not think of as the wreck's region.
- The untyped small lake near tidal water (slice 1) is narrowed, not
  closed.
- The AWOIS data is as NOAA left it in 2016.
- New Jersey's reef page could not be read by an automated reader; its
  terms were taken from the layer's agreement and the State's notice.

## Left to the builder

- Script and module names, the snapshot format, the cache folder, and how
  a fetch resumes.
- The Wikidata queries, including how coordinate precision is read.
- The exact title-casing rules, within the examples given.
- How the standard-library place lookup is made fast enough.
- How the kind is stored and indexed, and whether the ladder step alters
  the table or re-creates it.
- How the count for the register section is computed.
- The strings, their keys, and the caption's wording.
- How the map knows its bounds have settled, and the debounce.
- Whether `kSiteCatalogueImportRevision` needs to move.
- The business name patterns beyond the tags listed, checked against the
  list of what they remove.
- Where New Jersey's metadata document lives in the repository and bundle.

## Acceptance

1. **Size and shape.** The shipped file holds about 21,400 records (the
   exact count is pinned once the harvest is final). Every record has an id,
   a name, a declared source and `verified` trust; every register record has
   a position; no id repeats.
2. **Exclusions.** No record's id starts `usreef_ny_`, `usreef_fl_`,
   `usreef_nj_` or `usreef_nc_`. No record comes from a source key the
   metadata does not declare. The script tests show a wrecksite.eu row from
   the Irish file and a New York row from the federal file being dropped.
3. **Existing links.** Every OpenStreetMap dive site id that is still a
   dive site upstream is in the new file. Every curated id is in it, apart
   from any the report names as having stepped aside for OpenStreetMap.
   "Salt Pier" keeps `osm_node_663869401` and is in the Caribbean
   Netherlands on Bonaire.
4. **Cleaning.** A site at Tahiti is in French Polynesia (`PF`). No region
   contains a character outside Latin script. A sample of dive centres named
   in today's file is absent.
5. **Overlap.** A wreck listed by UKHO and by OpenStreetMap as a dive site
   appears once, under its OpenStreetMap id, with UKHO's depth when its own
   was empty.
6. **Own terms.** Every record of `njdep`, `hi_dar`, `tpwd` and `nc_dmf`
   has its source's `own_terms` declared. A script test shows an own-terms
   record that matches a curated wreck being left out and the curated
   record unchanged. The open-only file holds none of them.
7. **Picker.** At a dive near Scapa Flow, "More sites near" lists dive site
   records only, and below it a closed section shows a count of register
   records. Opening it lists them. A diver far from any register record
   sees no such section.
8. **Search.** Typing a charted wreck's name finds it anywhere in the
   world. A country chip on the import page lists dive sites before register
   records.
9. **GPS matching.** A dive 60 m from a register record and 120 m from a
   dive site record is offered the dive site record first. A dive 60 m from
   a lone register record is offered that record.
10. **Map.** With the overlay on, moving the map loads the sites in view.
    Zoomed out over the North Sea the overlay shows at most 1,500 markers
    and the caption.
11. **Import.** The first launch after the update starts without waiting,
    and the larger catalogue appears when its import finishes.
12. **Credits.** The licence page names every source with its licence, the
    New Jersey disclaimer and the non-commercial notice. A site adopted
    from a UKHO record shows "UK Hydrographic Office" as its source.

## Testing

Tests first. At least:

- Each source module's parser against a few committed sample rows in that
  source's real format: every gate dropping what it should, units
  converted, ids formed, names cased.
- Grouping: deployments of one name within 1 km become one record; the same
  name 5 km apart stays two; North Carolina is never grouped.
- Overlap: both rules, the generic-name distance, a name that begins with
  another staying separate, dive site sources never merged among
  themselves, the curated rule unchanged, the order of survivors, and what
  a survivor takes.
- Own terms: nothing given or taken, left out whole on a match, the
  open-only file.
- The offline place lookup: inside a unit, at sea near one, beyond 370 km,
  a territory over its parent state, a lake.
- The merge: refuses a missing snapshot, drops the excluded states, writes
  records in id order one per line, its sidecar matches, and it reports ids
  gone and new.
- The new script tests run in CI, in the coverage step.
- The catalogue over a real local cache database: `near` by kind, the
  count, `inBounds` with its limit and order, the search tie-break.
- The ladder step and its backstop.
- Picker widget tests: the register section absent, closed with its count,
  opened, capped, ordered by distance and by name, and the dive site section
  free of register records.
- GPS matching: the new order of preference.
- The map overlay provider: loads by bounds, caps, reports the cap.
- The licence text names every declared source and carries each own-terms
  source's statement.
- The data file (`site_catalogue_asset_test.dart`): the pinned count,
  acceptance items 1 to 4 and 6, every register record's depth within its
  gate where one is stated, and the existing checks.
- The demo data generator's tests against the new file.
- `test/architecture/` and `test/shared/` after adding files.

## Appendix A: where each source is, and the fields behind the gates

The prototype that produced the measured facts is not in the repository.
This appendix is what a builder needs in its place.

| Source | Address | Format |
|---|---|---|
| UKHO | `datahub.admiralty.co.uk/portal/sharing/rest/content/items/60c0908526b844a68494c038a457e1a7/data` | Zip holding `Wrecks.txt`: tab-separated, every value quoted, Latin-1, CRLF, 50 columns, 103,244 rows |
| AWOIS | `web.archive.org/web/20240519095415id_/https://wrecks.nauticalcharts.noaa.gov/downloads/AWOIS_Wrecks.kml` | KML; each placemark's description is an HTML table of field and value |
| FWC | `gis.myfwc.com/mapping/rest/services/Open_Data/Artificial_Reef_Locations_in_Florida/MapServer/12` | ArcGIS query, GeoJSON, 2,000 rows a page |
| Federal reef file | `marinecadastre.gov/downloads/data/mc/ArtificialReef.zip` | Zip holding a GeoPackage (SQLite), 30,398 points |
| New Jersey | `mapsdep.nj.gov/arcgis/rest/services/Features/Environmental_admin/MapServer/42`; metadata at `arcgis.com/sharing/rest/content/items/862307fcb54b4f70a6bdb9915d4c149f/info/metadata/metadata.xml` | ArcGIS query, 3,828 rows, 2,000 a page |
| North Carolina | `services2.arcgis.com/kCu40SDxsCGcuUWO/arcgis/rest/services/DMF_ReefGuide/FeatureServer/0` | ArcGIS query, 55 points |
| Florida Keys | `services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/PubFKNMSBuoy2025/FeatureServer/0` | ArcGIS query, 807 points |
| Ireland | `arcgis.com/sharing/rest/content/items/d4b084c880b546fabe38345461b563d2/data` | CSV, UTF-8 with a byte order mark, 17,981 rows |
| Wikidata | `query.wikidata.org/sparql` | SPARQL JSON |
| OpenStreetMap | `overpass-api.de/api/interpreter` | Overpass JSON, `out center tags;` |
| Natural Earth | `raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/` files `ne_10m_admin_0_map_subunits`, `ne_10m_admin_1_states_provinces`, `ne_10m_lakes` | GeoJSON |

Field notes:

- **UKHO.** `name`; `latitude` and `longitude` as degrees and decimal
  minutes with a hemisphere letter ("51 20.55 N"), WGS84. Position
  precision is the number of decimals written in the minutes, the lower of
  the two. `status` is free text holding any of "dead", "lifted",
  "existence doubtful", "historic", "Not Fully Surveyed" (the last two
  pass). `water_level_effect` must begin "always under water".
  `wreck_category` must be filled and `obstruction_category` empty. `type`
  gives the excluded kinds and the description's vessel type.
  `position_method` is the fixing method. `water_depth` is the charted
  depth and `depth` the least depth over the wreck, both in metres.
  `date_sunk` is `YYYYMMDD` or `YYYY`. `general_comments` holds the
  restriction and protection notes.
- **AWOIS.** `RECRD`, `VESSLTERMS` (name), `FEATURE_TYPE`, `LATDEC`,
  `LONDEC` (NAD83), `GP_QUALITY` (High, Med, Low, Poor), `DEPTH` with its
  unit in `SOUNDING_TYPE` ("Feet and tenths", "Meters and tenths",
  "Fathoms and tenths", "Wire-drag clearance, feet"), `YEARSUNK`,
  `HISTORY`.
- **FWC.** `DeployID`, `Name`, `Depth` and `Relief` in feet, `MatCat`
  (Vessel marks a wreck), `MatDescrip`, `DeployDate`, `County`; position
  from the geometry.
- **Federal reef file.** `reefName`, `reefStructure`, `reefComposition`,
  `reefYear`, `stateAbbreviation`, `waterDepthFeet`, `latitudeDMS`,
  `longitudeDMS` (NAD83). The GeoPackage is read with the standard
  library's SQLite. Each state program's own page is in "Licence
  findings" and in the federal metadata (`fisheries.noaa.gov/inport/item/54191`).
- **New Jersey.** `UNIQUE_ID`, `REEF_SITE`, `NAME`, `MATERIAL`, `TYPE`,
  `YEAR_DEPLOYED`, `LATDD`, `LONDD`. No depth.
- **North Carolina.** `REEF_NAME` (often empty), `REEF__` (the reef
  number), position from the geometry. No depth.
- **Florida Keys.** `Location` (the site name), `BuoyType`, `Depth__ft_`,
  position from the geometry.
- **Ireland.** `Wreck Name`, `Wreck No`, `Classification`, `DD_Lat`,
  `DD_Long` (zero means none), `Source of Co-ordinate`,
  `Date_of_Loss_Year_Only`.
- **Wikidata.** Dive sites: instances of `Q26205080` or a subclass.
  Wrecks: instances of `Q852190`, and items whose significant event (`P793`)
  is `Q906512` or `Q1786766`. Coordinates `P625`, on Earth only. A
  Wikipedia article is any sitelink to a Wikipedia.
- **OpenStreetMap.** Dive sites: `nwr["sport"="scuba_diving"]`. Wrecks:
  named `nwr` with `historic=wreck`, `seamark:type=wreck` or any
  `wreck:type`. Depth keys in use: `wreck:depth`, `depth`,
  `seamark:wreck:depth`, `scuba_diving:depth`, `scuba_diving:maxdepth`.
- **Natural Earth.** Map subunits: `ISO_A2_EH` is the unit's code, with
  the parent's fields for a unit that has none. First-level units:
  `name_en`, `iso_3166_2`, `iso_a2`.

## Appendix B: word lists

- **Placeholder names:** unknown, unidentified, wreck, wrecks, obstruction,
  barge (alone), and anything beginning "unnamed" or "unknown".
- **Ship prefixes dropped in folding:** HMS, HMT, HMAS, HMCS, HMNZS, USS,
  USNS, USAT, USCGC, SS, MV, MT, FV, SV, RMS, RFA, MFV, TSS, SMS, "the",
  "wreck of", "wreck of the", and a leading "wreck", "épave" or "wrak".
- **Trailing words dropped in folding:** wreck, shipwreck, reef.
- **Generic names (200 m rule):** barge, tug, trawler, dredger, yacht,
  pontoon, lighter, landing craft, fishing vessel, boat.
- **UKHO comments that drop a record:** "no" followed by a list containing
  "diving"; "diving" followed by prohibited, not permitted, forbidden or
  restricted.
- **UKHO comments that become a hazard:** restrict, prohibit, protected,
  military remains, controlled site, historic wreck, heritage.
