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
`docs/design/specs/2026-11-15-site-catalogue-researched-sites-design.md`.

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
  people who dived it).
- **Pages that may be cited but never confirm anything:** directories and
  aggregators: agency site pages (PADI, SSI), diveplannerpro, zentacle,
  divebuddy, yachtway, travel apps and their mirrors. They copy each
  other, so agreeing with each other proves nothing.
- **Pages never used:** guidebooks, paid apps, wrecksite.eu, WannaDive,
  Wikivoyage, Diveboard. A set of positions from one guidebook or chart is
  protected as a database in the UK and EU even where each fact is free.
- **Position:** two counting pages on different domains, each written to
  a tenth of a minute, three decimals of a degree or a whole second or
  finer, no two counting figures more than 150 m apart. The shipped point
  is their mean. Otherwise the site does not ship. No point is placed from
  a description.
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
2. **Read pages.** For each candidate find counting pages and note only
   the facts each one states: position, depth, entry, site type, hazards.
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

If an area yields fewer than 5 entries that pass, research the next thin
area of the same kind instead, and say so in the batch's PR.

## An entry

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
  "review": {"state": "pending"},
  "withdrawn": null
}
```

- **id:** `research_<country code, lower case>_<name slug>`, formed once
  and never changed, never reused.
- **position:** every page that states one, each figure as the page wrote
  it (decimal degrees, or degrees and minutes, or degrees, minutes and
  seconds, with N, S, E or W). `lat` and `lon` are the mean of the
  counting figures; the checker says when they are not.
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
`{"id": "curated_...", "reason": ..., "date": ...}`.

The merge stops when a researched record the shipped catalogue holds would
leave it without a withdrawal (because the entry was deleted or rejected,
or because a new OpenStreetMap dive site now lies within 150 m of it). It
names the record and what replaced it; write the withdrawal and run it
again.
