# Site catalogue: wider sources for researched sites

Date: 2026-11-16
Status: draft, for the maintainer's approval
Program: `2026-11-13-site-catalogue-program.md`
Builds on: `2026-11-15-site-catalogue-researched-sites-design.md` (slice 3)
Issue: #4514

## Intent

Slice 3 built everything a researched dive site needs (the evidence file,
the checker, the review page, the "Not verified" mark, the matching rule and
withdrawals) and shipped no sites. Its pilot found that no site in six areas
had two counting pages stating a position within 150 m. Operators, marine
parks and clubs describe their sites in words or show them on map images;
written coordinates appear almost only in directories, which never count.

Researched sites are the only route to the reefs, walls and shore dives the
open registers never list, the sites other dive log apps advertise. This
design widens what may place a researched site so that sites ship, while
every position still traces to a page whose publisher knows the site and
whose terms allow it.

## What was decided

Chosen by the maintainer in the design conversation (2026-11-16):

1. **A researched position is good enough to name the dive.** When a diver
   logs a dive, the right site should be among those offered nearby. It
   does not need to put a boat on the mooring. "Good enough" is within
   about 2 km. The slice 3 safeguards stay: the "Not verified" mark, never
   preselected, withdrawable, and "not for navigation".
2. **Existence and position are proved separately.** Two counting pages on
   different domains name the site and place it in the same bay, island or
   reef system; words are enough for that. The position then needs one
   source.
3. **Positions come from counting pages, never from directories.** A
   position is a coordinate a counting page states, or a point read off a
   counting page's own map image. Directory coordinates were first accepted
   and then set aside once their terms were read (Constraints).
4. **A map-read position never blocks automatic matching.** A researched
   record placed from a map is offered from up to 2 km away, and it never
   stops a verified site from being picked automatically.
5. **Approach A:** one pipeline. The evidence file, checker and review page
   of slice 3 learn a second route to a position, and a catalogue record
   carries one optional field saying its position was read from a map.
6. **The first batch is the six areas the pilot searched:** Tulamben and
   Lembeh (Indonesia), Sipadan with Mabul and Kapalai (Malaysia),
   Tubbataha (Philippines), the Farne Islands and St Abbs (United
   Kingdom), aiming at 30 to 60 sites.
7. **A counting page must not forbid reuse.** A counting domain whose terms
   explicitly forbid copying or reuse is not used as a source at all. A
   bare copyright line, or no terms, is fine: the page gives one fact
   about its own site, restated in our own words and cited, as slice 3
   already allowed. Directories are different: they are compilations, and
   stay cite-only whatever their terms say.

## Goals

- Researched sites ship in the six pilot areas, each traceable to the
  counting pages that name it and the page that placed it.
- A map-read position cannot make automatic matching on verified sites
  worse than it is today.
- The maintainer can check every map reading at a glance before approving.

## Non-goals

- Positions good enough to navigate by. The catalogue stays "not for
  navigation".
- Re-checking the 55 curated records, or adding researched details to
  register records. Both stay later batches with their own designs.
- Any new label or wording in the app. The existing mark and sentence
  ("Gathered from published sources, not from a survey. Check the position
  locally before you rely on it.") already say what a map-read position
  needs said.
- Areas beyond the six. Later batches are data-only PRs under this rule.

## Anti-goals

- A position taken from a page whose terms forbid reuse, or from a
  directory whatever its terms.
- A position placed from words alone ("off the north tip of the island").
- A map-read record attached to a dive without the diver choosing it.
- Verified matching made worse: a dive at a verified site left for the
  diver to pick because a map-read record sits nearby.

## Constraints

**Directory terms (checked 2026-11-16).** Directories hold most written
coordinates, and none of them clearly allows reuse in an ODbL database:

| Directory | Terms on reuse |
|---|---|
| padi.com, scubaspotadvisor.com, divebuddy.com, zentacle.com, diveplannerpro.com, sygic.com | Forbid copying or limit use to personal use |
| waypoints.ph | No terms; a bare copyright line grants nothing |
| divessi.com | No terms of use; German operator, so the EU database right likely applies |
| aroundus.com | CC BY-SA 3.0, which cannot join an ODbL database |
| yachtway.com | Silent, and holds no dive coordinates |

The program's licence position (program overview, "Licence position") lets
nothing into the ODbL database from a source that forbids redistribution,
and it has held states to their own terms (New York, Massachusetts). So
directories stay cite-only: a researcher may read them to find a site, and
cite them, but no figure from them ships. waypoints.ph and SSI could be
asked for written permission later; that is not part of this design.

**Counting pages.** The slice 3 definition is unchanged: official pages
(marine park authorities, government notices, harbour or heritage bodies)
and first-hand pages (local operators who run the dive, dive press, club
write-ups). Guidebooks, paid apps and the sources the program excludes are
never used. A counting page's map is a fact about where the publisher puts
the site; reading one point off it copies nothing of the map.

Before a domain joins the counting list, the researcher reads its terms
(decision 7). A domain whose terms forbid copying or reuse goes on the
`never` list with that reason instead.

## Approaches

| | A. One pipeline, a field for where the position came from (chosen) | B. A separate "approximate" kind of record |
|---|---|---|
| For | Reuses the evidence file, checker, review page and matching rule that passed review; the app needs one optional field and one branch in matching | Leaves the slice 3 rule and records untouched |
| Against | The checker gains a second route to a position | A third trust level every surface must handle, a second checker and source key; slice 3 turned down this kind of split twice |

A third option, changing only the checker and leaving matching alone, was
dropped: map-read records would block automatic matching and go unseen
beyond 1 km at the default setting, against decision 4.

## Design

### 1. Evidence (`scripts/site_catalogue/research/sites.json`)

An entry gains a `named` fact and a second kind of position source:

```json
{
  "id": "research_id_coral_garden_tulamben",
  "name": "Coral Garden",
  "area": "Tulamben",
  "country_code": "ID",
  "named": {
    "place": "Tulamben Bay",
    "sources": [
      {"url": "https://operator-one.example/sites", "read": "2026-11-17"},
      {"url": "https://operator-two.example/dive-sites", "read": "2026-11-17"}
    ]
  },
  "position": {
    "lat": -8.2759,
    "lon": 115.5937,
    "sources": [
      {
        "url": "https://operator-one.example/sites",
        "read": "2026-11-17",
        "method": "map",
        "map": "https://operator-one.example/img/tulamben-map.jpg",
        "lat": -8.2759,
        "lon": 115.5937
      }
    ]
  },
  "note": "Read at the marked buoy, 250 m south of the Liberty along the shore.",
  "review": {"state": "pending", "date": null}
}
```

- **named.place**: the researcher's words for the bay, island or reef
  system the counting pages put the site in. Not shipped.
- **named.sources**: the pages that name the site in that place. Words are
  enough; no figure is recorded.
- **position.sources[].method**: `"stated"` (the default, as in slice 3)
  for a figure the page writes, or `"map"` for a point read off the page's
  map image. A map source carries `map`, the address of the image (or of
  the page, when the map is drawn on it), and the figure as read, in
  decimal degrees. A pin on the publisher's own embedded interactive map
  (Google My Maps, Leaflet, a KML layer the page loads) is `stated`: the
  publisher placed it, and its coordinate is read exactly. The source's
  `map` field then holds the address of the map layer.
- **distinct_from**: a list of other entries' ids, for two genuinely
  separate sites closer than 150 m (section 2). Optional.
- **note**: the researcher's own words. For a map reading it says which
  landmarks placed the point. Nothing from a page's text is kept, as in
  slice 3.

**How a map is read.** The researcher matches the map's coastline, reef
edges or named landmarks against OpenStreetMap, places the site's marker on
the matching spot, and takes that point. A map with a printed grid or
graticule is read from the grid. A map that cannot be matched to two or
more landmarks is not used.

### 2. Checker (`check.py`)

The slice 3 rules for depths, facts, shape, domains, ids and neighbours are
unchanged. Position and existence change:

- **Existence (`named`).** At least two `named` sources on counting domains,
  on different domains. Otherwise the entry fails `named_sources`. An
  entry with two counting `stated` positions within 150 m passes existence
  through those pages too, so slice 3's rule remains one way to pass.
- **Position, in order:**
  1. **Confirmed:** two counting `stated` figures on different domains
     within 150 m, each to a tenth of a minute or finer (slice 3's rule).
     The shipped point is their mean, as now. The record is not map-read.
  2. **Stated once:** exactly one counting `stated` figure to a tenth of a
     minute or finer, and no counting `map` figure beside it (a coarser
     stated figure beside it is fine; see Agreement). The shipped point is
     that figure. The record is not map-read.
  3. **Map-grade:** anything else that passes agreement (below): counting
     `map` figures only; or two or more counting `stated` figures more
     than 150 m apart (they disagree, so the position is only
     approximate); or a mix. The shipped point is the mean of every
     counting figure. The record is map-read.
  Otherwise the entry fails `position_sources`.
- **Agreement.** Every counting position figure (stated or map) lies within
  2 km of the shipped point, or the entry fails `position_spread`. A
  coarser stated figure than a tenth of a minute (a whole-minute
  directory-style figure on a counting page) may still serve as a map-grade
  figure: it counts as `map` for agreement and makes the record map-read
  when nothing finer exists.
- **Map sources** must name `map` and come from a counting domain; a `map`
  figure on a cite-only or never domain fails `position_domains`.
- **Neighbours.** Two standing entries within 150 m fail unless each names
  the other in `distinct_from`. A `note` no longer excuses the pair (in
  slice 3 it did; map readings almost always carry a note, which would
  switch the rule off). A map-read entry within 500 m of another standing
  entry is always flagged on the review page (not fatal): two sites that
  close may be one site read twice.

The checker reports, per entry, which route placed it (`confirmed`,
`stated`, `map`).

### 3. Domains (`domains.json`)

Unchanged in shape. The counting list grows as the batch is researched,
each domain with its one-line reason, as in slice 3. Directories stay in
`cite_only`. The directory terms above are recorded beside each cite-only
domain's reason (for example "agency directory; terms forbid copying").

### 4. Catalogue format

A researched record placed from a map carries `"position_from": "map"`.
Every other record leaves the field out. Validation in
`site_catalogue_format.py` rejects the field on any record that is not
`trust: researched`, and any value other than `"map"`. `FORMAT` stays 2:
the field is optional, the asset ships with the app that reads it, and a
new version hash already makes installs reload the catalogue.

The merge carries the field through from the evidence entry. Overlap is
unchanged: a researched record still ranks last and stands aside for the
same site from any other source.

### 5. App

- **Parser and storage.** `site_catalogue_parser.dart` reads
  `position_from`. `CatalogueSite` gains `positionFromMap` (bool, false
  when absent). The local cache's catalogue table gains a nullable column
  for it.
- **Candidates.** `MatchCandidate` gains `isMapPlaced`, true only for a
  researched record with `positionFromMap`.
- **Reach.** The matching service asks the catalogue for records within
  `max(outerRadiusMeters, 2000)`. A map-placed candidate is in range within
  2,000 m; every other candidate keeps the sensitivity's outer radius.
- **Matching (`matchRanked`).** A map-placed candidate:
  - is never in the pool the automatic pick is made from;
  - is never a competitor: it does not count for the runner-up separation
    rule or for "a dive site close behind" a register record;
  - is listed in every `Suggested` outcome while within 2,000 m;
  - when it is the only candidate in range, the outcome is `Suggested`
    with it, never `NoMatch` and never `AutoMatch`.
  - **Every list matching shows uses the 2 km reach for it**: the nearby
    candidates listed beside an `AutoMatch`, and the list for a dive whose
    site has no position, as well as `Suggested`. Otherwise a diver whose
    dive was auto-matched to a verified neighbour would never see the
    map-placed site.
  Stated-position researched records keep slice 3's rule (never an
  automatic pick, still a competitor).
- **Everywhere else** (picker, map, site page, gap fill, search) the record
  behaves as any researched record does today: the same mark, the same
  sentence, no new wording.

### 6. Review page (`review.py`)

For each map-read entry the page shows, beside the evidence it already
lists: a link to the map image, a link to OpenStreetMap at the shipped
point (`https://www.openstreetmap.org/?mlat=<lat>&mlon=<lon>#map=15/<lat>/<lon>`),
the researcher's note on landmarks, and the distance between figures when
there are two. The maintainer approves or rejects each entry, as now.

### 7. The batch

The session that builds this researches the six areas by the procedure
above: find the counting pages that name each area's sites, record two per
site, then take each position from a counting page's stated figure or map.
Sites already in the catalogue (the USAT Liberty is an OpenStreetMap
record) are left out, as slice 3's overlap would drop them anyway. The
pilot's near misses (the Mawali wreck, Black Rock, the Britannia) are
researched first.

Code and batch ship as two PRs: the code PR first (tests, empty evidence
file still valid), then a data PR carrying the approved batch, so the
maintainer reviews the batch on its own. If an area yields fewer than 5
sites that pass, the data PR says which and why; no replacement areas are
added in this batch.

### 8. Amendments to the slice 3 design

The slice 3 spec gains a note pointing here, and two of its decisions are
amended:

- Decision 4 ("A position ships only when two counting sources agree
  within 150 m") becomes one of three routes (section 2).
- "No position is placed from a description" stays, with the addition that
  a counting page's map is evidence of position and words alone are not.

## Acceptance

1. **Checker.** Each of these is a test: an entry named by two counting
   domains with one map figure passes as map-read; named by one counting
   domain fails `named_sources`; two named sources on one domain fail; a
   map figure on a cite-only domain fails; a stated figure and a map figure
   3 km apart fail `position_spread`; one stated counting figure to a tenth
   of a minute passes as `stated` and is not map-read; slice 3's confirmed
   entry still passes unchanged; a map-read entry 300 m from another is
   flagged, not failed; two stated counting figures 600 m apart pass as
   map-read at their mean; two entries 100 m apart fail unless each names
   the other in `distinct_from`, and a `note` alone no longer excuses them;
   a source on a domain in `never` fails.
2. **Format.** `position_from: "map"` on a researched record validates; on
   a verified record, or with another value, it fails.
3. **Matching.** At the Balanced setting (inner 150 m, outer 1 km):
   a dive 1.5 km from a lone map-placed record is `Suggested` with it;
   a dive 100 m from a verified site and 120 m from a map-placed record is
   an `AutoMatch` on the verified site; a dive 80 m from a map-placed
   record and 140 m from a verified site is an `AutoMatch` on the verified
   site, with nothing else in range; a dive 80 m from a stated-position
   researched record and 140 m from a verified site is `Suggested`, as
   today; a dive auto-matched to a verified site 100 m away also lists a
   map-placed record 1.5 km away among its nearby candidates.
4. **Storage.** The parsed flag survives a reload of the local cache.
5. **Review page.** A map-read entry shows the map link and the
   OpenStreetMap link at its point.
6. **Batch.** The data PR's entries all pass the checker and are approved
   on the review page before it merges.

## Known gaps

- A map reading is only as good as the operator's map, and a long site has
  one point. The 2 km target and the mark cover this; the review page is
  the only check.
- Two operators who copied one map look independent. The review page shows
  both links so a person can judge.
- Sites known only from guidebooks or charts (the Farnes, likely) may still
  not pass.
- A map-placed record auto-matching away from a verified site is excluded
  on purpose; a diver at the map-placed site whose dive was auto-matched to
  a verified neighbour changes it by hand.

## Calls the designer made

Settled by the designer after the builder check; the maintainer saw them
with the draft:

- An embedded interactive map's pin is a `stated` figure (section 1).
- Two stated figures 150 m to 2 km apart ship as their mean, map-read
  (section 2).
- `distinct_from` replaces the note's exemption from the neighbour rule
  (section 2).
- The 2 km reach covers every list matching shows (section 5).
- A whole-minute figure on a counting page counts as map-grade (section 2).
- A map-read entry within 500 m of another is flagged, not failed
  (section 2).
- Code and batch ship as two PRs, with no replacement areas (section 7).
- No new label or wording in the app (Non-goals).

## Left to the builder

- Function and field names in the checker and the Dart code beyond those
  named here, and how the local cache column is added.
- How the checker reports routes, and the review page's styling.
- Whether the matching service makes one catalogue query at the wider
  radius or two.
