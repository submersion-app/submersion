# Built-in site catalogue: program overview

Date: 2026-11-13
Status: draft for approval

## Why

Other dive log apps advertise large built-in site databases (73,000, 21,000
and 3,900 sites in the four ScubaBoard threads that prompted this). Submersion
ships 3,667 sites harvested from OpenStreetMap in February 2026, and most of a
diver's contact with site data never touches them: the site picker on the dive
edit page lists only the diver's own sites, and file imports ignore the
built-in data entirely.

The maintainer wants three things:

1. A much larger built-in catalogue.
2. A richer experience around site information.
3. Less typing about sites when logging dives.

## What was decided

These were chosen by the maintainer during the design conversation.

- **Sources:** open, traceable sources plus AI-researched sites. The whole
  catalogue ships inside the app and works offline. No contributions from
  divers and no online lookups.
- **Naming flow:** built-in sites appear in the existing site picker, with
  "area memory" so that after the first site of a trip the picker leads with
  built-in sites in the same area. No new screen.
- **Richer means all four of:** fuller details when a site is adopted; filling
  gaps in sites the diver already has; a stored link from an adopted site to
  its catalogue record; browsing built-in sites before diving them.
- **Organisation:** five slices in the order below, each with its own spec,
  plan and PR.
- **Storage:** the catalogue is loaded into the local cache database
  (`submersion_local.db`), which is never synced or backed up.

## The five slices

| # | Slice | What it delivers | Status |
|---|---|---|---|
| 1 | Catalogue foundation and picker | New catalogue format and storage, picker with area memory, one adoption path with fuller details and a stored link, OpenStreetMap credit | Design: `2026-11-13-site-catalogue-picker-design.md` |
| 2 | Open-register expansion | Harvester pulls the open registers below and removes overlap; cleans the existing data | Design: `2026-11-14-site-catalogue-register-expansion-design.md` |
| 3 | AI-researched sites | The research process, what each site must cite, checks before one ships, the "not verified" badge and its matching rule | Not designed |
| 4 | Fill gaps in existing sites | A review list offering catalogue details for sites the diver already has; links sites adopted before slice 1 | Not designed |
| 5 | Browse before diving | Catalogue site pages, catalogue sites on the map by default | Not designed |

Slices 2 and 3 are mostly scripts and data and write to the format slice 1
fixes. Slices 4 and 5 depend on the link and the storage from slice 1.

## Proposals carried into later slices

These are the designer's proposals. The maintainer saw them and did not
object; each is confirmed when its slice is designed.

- **Trust levels.** Every catalogue record carries a trust level. Records from
  registers are `verified`. AI-researched records are `researched`: they show
  a "not verified" mark, and GPS matching offers them but never preselects
  them. Once a diver adopts one it is an ordinary site of theirs.
- **Wrecks and artificial reefs go in,** typed as wreck or reef. They surface
  in the picker only by search or when the diver is in that area.
- **Dive Vibe's community data stays out.** Its code is MIT but its data is
  under ODbL with mixed origins, including coordinates from WannaDive (all
  rights reserved).

## Source survey (2026-11-13)

Counts are measured unless marked estimated. "Named" means the record has a
usable name.

| Source | Usable records | Licence | Use it? | Notes |
|---|---|---|---|---|
| OpenStreetMap `sport=scuba_diving` | 2,986 named, excluding shops and clubs | ODbL 1.0 | Yes (current source) | Depth on 609, entry on 444, difficulty on 169 |
| OpenStreetMap wrecks | 1,820 named and not already scuba-tagged | ODbL 1.0 | Yes | Depth on 1,566 of 9,001 |
| UK Hydrographic Office Global Wrecks | 12,571 named, live, 60 m or shallower | Open Government Licence v3 | Yes | Depth on almost every row; "not for navigation"; many positions are old reported fixes |
| NOAA ENC and AWOIS wrecks | 3,000 to 4,000 named (estimated) | CC0 | Yes | AWOIS frozen in 2016 |
| NOAA artificial reefs and Florida FWC | about 6,300 distinct named reefs | Public domain or citation requested | Yes | Depth on nearly all |
| Ireland wreck inventory | 1,662 named with coordinates | CC BY 4.0 | Yes | No depth; overlaps UKHO; some positions originate from wrecksite.eu |
| Wikidata | 328 dive sites, about 1,400 notable wrecks | CC0 | Yes | Most other Wikidata wrecks are UK loss records, not dive sites |
| Florida Keys mooring buoys | 496 | NOAA, citation requested | Yes | Location names and depth |
| SHOM (France) wrecks | 2,197 named | Unclear | Only after the licence is confirmed | |
| Wikivoyage dive guides | 700 to 1,000 sites (estimated) | CC BY-SA 4.0 | No | Cannot be merged into an ODbL table |
| Dive Vibe community repo | 4,076 | ODbL, mixed origins | No | See above |
| New Jersey, North Carolina reef programs | 3,828 deployments and 55 sites | Conditions on redistribution; non-commercial and unaltered | Yes, kept apart (decided 2026-11-14) | Own-terms sources; see the slice 2 spec |
| wrecksite.eu, WannaDive, Diveboard | n/a | Proprietary or non-commercial | No | |

**Corrected on 2026-11-14.** Slice 2 downloaded and measured every source;
its spec holds the figures that replace this table. In short: NOAA's ENC
wrecks are unnamed and drop out; AWOIS has 2,376 named wrecks, 646 of them
with a good position, and survives only as an archive copy; the federal reef
file is a compilation of state data, each with its own terms; 590 Irish
positions come from wrecksite.eu; SHOM is CC BY-SA and is out.

Realistic total after removing overlap (estimated): 28,000 to 31,000 named
points, about 8 times today's catalogue. Measured: about 28,400, of which
about 21,400 have a position that can be defended; slice 2 ships those. Of those, 4,500 to 5,000 are
recreational dive sites, 17,000 to 20,000 are wrecks and about 6,000 are US
artificial reefs. None of the open sources supplies difficulty or entry type,
so recognisable reef and shore sites and richer details depend on slice 3.

## Licence position

- OpenStreetMap data is under ODbL. Once OpenStreetMap records are
  deduplicated against other records in one table, the merged table is a
  derivative database and is treated as ODbL in full.
- That requires a visible credit ("OpenStreetMap", with the data identified as
  ODbL and a link to openstreetmap.org/copyright), a notice shipped with the
  data, and the database offered to anyone who asks. The harvester and the
  data file live in this public repository, which satisfies the offer.
- CC0, public domain, Open Government Licence and CC BY sources can be merged
  in. CC BY-SA sources cannot.
- **Amended on 2026-11-14.** A non-commercial term does not exclude a source:
  Submersion is open source and takes no money. Such a source cannot be
  offered under ODbL, which allows commercial reuse, so its records ship as
  an own-terms collection beside the ODbL database: never de-duplicated into
  it, marked with their own terms, and left out of the ODbL offer. A source
  that forbids redistribution stays out. The slice 2 spec has the rules.
- Every record carries its source and licence so each source's credit can be
  shown.
- The app carries no OpenStreetMap credit for this data today. Slice 1 adds
  it.

## Anti-goals for the whole program

- A site count reached by shipping positions nobody can trace or defend.
- A wrong built-in position silently attached to a diver's real dive.
- Built-in data overwriting anything a diver typed.
- A bigger catalogue that costs every diver memory or launch time.
