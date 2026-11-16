# Researched dive sites

The registers the harvest reads list wrecks and artificial reefs. None of
them lists reefs, walls or shore sites, so the famous ones are missing
from the built-in catalogue. This folder holds sites found by research
instead: a person, or an AI session following these steps, reads
published pages about a dive area and records the facts they state, each
fact with the pages behind it.

A researched record ships marked "Not verified", GPS matching never picks
one for the diver, and nothing ships until the maintainer has seen and
approved it. The rules come from
`docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md`,
widened by `docs/design/specs/2026-11-16-site-catalogue-wider-sources-design.md`.

| File | What it holds |
|---|---|
| `sites.json` | The evidence: one entry per researched site, and `withdrawn_curated` |
| `domains.json` | Which domains count, which may only be cited, which are never used |
| `evidence.py` | Reads positions, depths and domains; the hazard sentences |
| `check.py` | The rules; CI runs it on the committed file |
| `review.py` | The page a batch is approved from |

## The rules in short

- **Pages that count:** official pages (marine park authorities,
  government notices, harbour or heritage bodies) and first-hand pages
  (the local operators who run the dive, dive press and club write-ups by
  people who dived it). Before a domain joins the counting list, read its
  terms: a domain whose terms forbid copying or reuse goes on the `never`
  list instead. A bare copyright line, or no terms, is fine.
- **Pages that may be cited but never confirm anything:** directories and
  aggregators: agency site pages (PADI, SSI), Scuba Spot Advisor,
  waypoints.ph, diveplannerpro, zentacle, divebuddy, yachtway, travel apps
  and their mirrors. They copy each other, so agreeing with each other
  proves nothing, and their terms forbid reuse or grant nothing, so no
  figure of theirs ever ships.
- **Pages never used:** guidebooks, paid apps, wrecksite.eu, WannaDive,
  Wikivoyage, Diveboard. A set of positions from one guidebook or chart is
  protected as a database in the UK and EU even where each fact is free.
- **Existence:** two counting pages on different domains name the site
  and place it in the same bay, island or reef system (`named`). Words are
  enough. Two counting positions that confirm each other (below) prove it
  too.
- **Position:** one of three routes. *Confirmed:* two stated counting
  figures on different domains, each to a tenth of a minute (three
  decimals of a degree, a whole second) or finer, within 150 m of each
  other; the shipped point is their mean. *Stated:* exactly one such
  figure; the shipped point is that figure. *Map:* anything else from
  counting pages: a point read off a counting page's own map, a figure
  coarser than a tenth of a minute, or stated figures that disagree; the
  shipped point is the mean of every counting figure, and the record is
  offered from up to 2 km but never blocks an automatic match. Every
  counting figure lies within 2 km of the shipped point. No point is
  placed from words alone.
- **Depth:** the deepest counting figure, and the shallowest counting
  minimum. Both are left out when the counting maxima spread by more than
  5 m and by more than a quarter of the deepest.
- **Entry, type, hazards:** kept when a counting page states them and none
  contradicts them.
- **No text from any page,** anywhere. Not a sentence, not a close
  paraphrase. The record's description is one line the merge writes from
  its own fields; hazards are fixed sentences of ours.

## A research run

One area at a time.

1. **Pick candidates.** List the sites pages name again and again in the
   area. Leave out any site a built-in record already covers (search the
   catalogue by name, and look at the Sites map); the merge leaves a
   researched record out beside any dive site record within 150 m anyway.
2. **Read pages.** For each candidate find two counting pages that name
   it (`named`), then note only the facts each page states: position,
   depth, entry, site type, hazards. A pin on the publisher's own
   interactive map (Google My Maps, Leaflet, a KML layer the page loads)
   is a stated figure, read exactly. When a page shows its sites only on
   a map image, read the point off the image: match its coastline, reef
   edges or named landmarks against OpenStreetMap, place the site's
   marker on the matching spot and take that point. A map with a printed
   grid is read from the grid. A map you cannot match to two or more
   landmarks is not used. Say in the entry's `note` which landmarks
   placed the point.
   Note the address and the date it was read. Any request a script makes
   sends `dive-site-harvester/1.0` and nothing that names a person or the
   project.
3. **Prefer pages that are plainly independent.** The checker can tell
   two domains apart but not two operators who copied one survey. Prefer
   figures written differently (another precision, another point on the
   site, a datum note), and say in the entry's `note` why the pages are
   independent when it is not obvious.
4. **Write the entry** in `sites.json` (below), in the closed
   vocabularies. A page on a domain that is on no list fails the checker:
   add the domain to `domains.json` with its reason first. That is a
   decision a person makes once per domain.
5. **Run the checker:** `python3 scripts/site_catalogue/research/check.py`.
   An entry that fails is fixed or dropped, never forced.
6. **Make the review page:**
   `python3 scripts/site_catalogue/research/check.py --review review.html`
   (anywhere outside the repository), and hand it to the maintainer.
7. **Write the maintainer's decision** into each entry's `review`:
   `{"state": "approved", "date": "YYYY-MM-DD"}`, or `rejected` with a
   `reason`. A rejected entry stays in the file so a later run does not
   research it again blind.
8. **Run the merge** (`python3 scripts/site_catalogue/merge.py`). Only
   approved, sound, unwithdrawn entries reach the catalogue.

If an area yields fewer than 5 entries that pass, say which and why in
the batch's PR. The first wider sources batch adds no replacement areas.

## An entry

```json
{
  "id": "research_id_usat_liberty",
  "name": "USAT Liberty",
  "area": "Tulamben",
  "country_code": "ID",
  "named": {
    "place": "Tulamben Bay",
    "sources": [
      {"url": "https://...", "read": "2026-11-16"},
      {"url": "https://...", "read": "2026-11-16"}
    ]
  },
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
  "review": {"state": "pending"},
  "withdrawn": null
}
```

- **id:** `research_<country code, lower case>_<name slug>`, formed once
  and never changed, never reused.
- **named:** `place` is your words for the bay, island or reef system;
  `sources` are the pages that name the site there.
- **position:** every page that states one, each figure as the page wrote
  it (decimal degrees, or degrees and minutes, or degrees, minutes and
  seconds, with N, S, E or W). A point read off a map image carries
  `"method": "map"`, `"map"` (the image's address) and the point in
  decimal degrees; an interactive map's pin is stated and its `map` is
  the layer's address. `lat` and `lon` are the shipped point of the route
  the checker finds; it says when they are not.
- **distinct_from:** for two separate sites closer than 150 m, each
  entry lists the other's id. A `note` no longer lets both stand.
- **Depths:** each page's figure; add `"unit": "ft"` for feet. The shipped
  depth is worked out by the checker, never written by hand.
- **entry, types:** the app's names (`shore`, `boat`, `giantStride`;
  `reef`, `wall`, `wreck`, `muck`), as `scripts/site_catalogue_format.py`
  lists them.
- **hazards:** `strong_current`, `surge`, `boat_traffic`, `overhead`,
  `entanglement`, `cold`, `low_visibility`, `permit`, `depth`.
- A page that disagrees with a fact is listed under it with
  `"contradicts": true`; the fact is then left out.
- Any source may carry `"archive"`: an archive.org copy of the page.
- `note` is for your own words (why a figure was set aside, which point on
  a long site was chosen). It does not ship. There is no field for a
  quotation, and the checker fails any field it does not know.

## Withdrawing a record

When a researched record proves wrong, give its entry
`"withdrawn": {"reason": ..., "date": ..., "replaced_by": ...}`. The
reason is `position`, `not_a_site`, `duplicate` or `other`;
`replaced_by` is optional, the id of the record that corrects it. A
correction is a withdrawal plus a new entry with a new id.

A withdrawn record leaves the catalogue, and every later catalogue lists
it as withdrawn. A diver whose site came from it sees on that site's page
that it was withdrawn and why; nothing about their site changes.

A curated record (`scripts/dive_sites_curated.json`) is withdrawn the same
way, by an item in `withdrawn_curated`:
`{"id": "curated_...", "reason": ..., "date": ...}`. Its entry stays in
the curated file: the merge refuses a withdrawal that names no curated
entry, which is how a mistyped id is caught.

When a correction is itself withdrawn later, the catalogue sends each
earlier withdrawal on to the record that still ships; a loop of
replacements stops the merge.

The merge stops when a researched or curated record the shipped catalogue
holds would leave it without a withdrawal: because the entry was deleted
or rejected, or because a new OpenStreetMap dive site now lies within
150 m of a researched record (1 km of a curated one with its name). It
names the record and what replaced it; write the withdrawal, with that
record as `replaced_by`, and run it again.
