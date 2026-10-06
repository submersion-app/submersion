# Reef Data for Dive Sites

Date: 2026-07-25
Status: Approved, ready for implementation planning
Branch: `worktree-reef-data`

## Overview

Given a dive site's coordinates, fetch and display four kinds of reef information
from free online sources: reef habitat, reef health, nearby marine species, and
protected-area status. Data is fetched automatically when a site is viewed,
cached locally per provider, and never synced between devices.

The feature also attaches historical reef health to individual dives, showing
the thermal stress that was present on the date each dive was logged.

## Goals

- Answer "what is the reef like here?" for any dive site that has coordinates.
- Use only keyless, commercially licensed data sources.
- Add no cost to the synced database schema or the CRDT sync layer.
- Degrade gracefully: one provider failing must not affect the other three.
- Never present unverified regulatory information to a diver.

## Non-goals

- Bulk prefetching reef data for the whole site list.
- Editing or contributing reef data back to any source.
- Rendering protected-area activity permissions (see Decision 7).
- Benthic composition and geomorphic zonation. The only source for these is the
  Allen Coral Atlas, which is excluded on licensing grounds.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Cover all four data kinds | Habitat, health, species, and protection together answer the question a diver actually asks. |
| 2 | Build all four at once | Single spec, single implementation effort; the site page lands feature-complete. |
| 3 | Auto-fetch when a site is viewed | Zero friction, matching the existing tide section. Coordinates already leave the device for map tiles, geocoding, and weather. |
| 4 | Species are read-only with opt-in add | Keeps the curated Expected list clean while letting a diver promote individual species into it. |
| 5 | Keyless sources only | No secrets to ship, no signup friction, no extractable embedded credentials. |
| 6 | Species shown as catalog match plus filtered remainder | Matching against the 511 bundled species removes bird and plankton noise for free and yields rich rendering; a filtered tail preserves regional coverage. |
| 7 | Protected areas show identity and level, with a link out | ProtectedSeas' activity codes have no published codebook. Misreading them would put false regulatory information in front of a diver. |
| 8 | Coordinate-keyed cache with per-provider TTL | The four providers' refresh rates differ by four orders of magnitude, from daily to never. |
| 9 | Reef health attaches to past dives as well as sites | NOAA supports date queries back to 1985; historical values are immutable and cache permanently. |

## Data sources

All four were verified live during research: keyless, CORS-enabled, and licensed
for commercial use.

| Capability | Source | Licence | Measured latency |
|---|---|---|---|
| Reef habitat | WRI Reefs at Risk Revisited 2011 | CC BY 3.0 | 0.48s |
| Reef health | NOAA Coral Reef Watch via PacIOOS ERDDAP | Public domain | <1s |
| Nearby species | GBIF occurrence facets | CC0 and CC BY only, filtered | 0.45s |
| Protected areas | ProtectedSeas Navigator | CC BY 4.0 | 0.42s |

### Reef habitat: WRI Reefs at Risk Revisited 2011

Endpoint, 63,369 polygons:

```
https://data-gis.unep-wcmc.org/server/rest/services/Hosted/WRI002_ReefsAtRiskRevisited2011/FeatureServer/0/query
  ?geometry=<lon>,<lat>
  &geometryType=esriGeometryPoint
  &inSR=4326
  &spatialRel=esriSpatialRelIntersects
  &where=1=1
  &returnGeometry=false
  &f=json
```

Returns reef presence and an integrated threat classification. Verified at Ras
Mohammed (`threat_txt: "High"`) and Molokini (`"Medium"`).

This answers "is there a reef here, and how threatened is it" — not benthic
composition or geomorphic zone.

### Reef health: NOAA Coral Reef Watch

Server `pae-paha.pacioos.hawaii.edu`, dataset `dhw_5km`. This is the only NOAA
server that sends `Access-Control-Allow-Origin: *`, and the only one carrying
all five products in a single dataset.

```
https://pae-paha.pacioos.hawaii.edu/erddap/griddap/dhw_5km.json
  ?CRW_SST[(<time>)][(<lat>)][(<lon>)]
  ,CRW_SSTANOMALY[(<time>)][(<lat>)][(<lon>)]
  ,CRW_HOTSPOT[(<time>)][(<lat>)][(<lon>)]
  ,CRW_DHW[(<time>)][(<lat>)][(<lon>)]
  ,CRW_DHW_mask[(<time>)][(<lat>)][(<lon>)]
```

Each variable must repeat its own constraint block. `<time>` is `(last)` for
current conditions or a `yyyy-MM-dd` date for a past dive. Brackets are
percent-encoded as `%5B` and `%5D`.

Do not use `coastwatch.pfeg.noaa.gov/erddap/griddap/NOAA_DHW` even though NOAA's
own documentation cites it. It 302-redirects to PacIOOS without a CORS header,
which works on mobile and desktop and fails only on web — an easy bug to ship.

Data is daily, timestamped `T12:00:00Z`, and runs 1–5 days behind. The UI shows
"as of <returned date>", never "today".

### Nearby species: GBIF

```
https://api.gbif.org/v1/occurrence/search
  ?geoDistance=<lat>,<lon>,5km
  &license=CC0_1_0&license=CC_BY_4_0
  &occurrenceStatus=PRESENT
  &hasGeospatialIssue=false
  &taxonKey=<k1>&taxonKey=<k2>...   // catalog-derived, see Species pipeline
  &facet=speciesKey
  &facetLimit=300
  &limit=0
```

The licence filter is mandatory, not optional. 28% of occurrence records near
Bonaire are CC BY-NC; omitting the filter ships a licensing violation.

The taxon filter is also mandatory. Without it, a 5 km radius around Bonaire
returns 202,801 occurrences of which 156,474 (77%) are birds, because eBird is a
GBIF publisher. Birds would then dominate the 300 facet slots and crowd out reef
species entirely.

A 5 km radius is used rather than 10 km, which measurably reduces land bleed at
coastal sites.

`User-Agent` is set to identify the app, which GBIF explicitly asks integrators
to do.

### Protected areas: ProtectedSeas Navigator

```
https://services9.arcgis.com/lm7wE8a9YA9rKfzy/arcgis/rest/services/
  Navigator_AllSites_010925_attributes/FeatureServer/0/query
  ?geometry=<lon>,<lat>
  &geometryType=esriGeometryPoint
  &inSR=4326
  &spatialRel=esriSpatialRelIntersects
  &where=category_name='Marine Protected Area'
  &outFields=site_name,country,wdpa_id,iucn_cat,lfp,navigator_link
  &returnGeometry=false
  &f=json
```

The `category_name` filter is required. Unfiltered queries also return exclusive
economic zones and tuna-treaty areas, which are not dive-relevant.

Verified at Molokini, Molasses Reef, Flynn Reef, Ras Mohammed, and Blue Corner.

### Coordinate parameter order

The three provider families disagree on coordinate order, which is an easy source
of silent, plausible-looking wrong answers:

| Provider | Parameter | Order |
|---|---|---|
| ArcGIS (habitat, protection) | `geometry` | `lon,lat` |
| GBIF | `geoDistance` | `lat,lon,radius` |
| ERDDAP | constraint blocks | `[(time)][(lat)][(lon)]` |

Each service takes a typed `GeoPoint` and formats it internally. No caller ever
assembles a coordinate string.

## Excluded sources

Three widely-cited datasets are deliberately excluded on licensing grounds. All
three carry the UNEP-WCMC general licence or an equivalent:

> Neither the Data nor any work derived from or based upon it may be put to
> Commercial Use without the prior written permission of the Director of
> UNEP-WCMC.

and

> You may not redistribute the Data in whole or in part by any means including
> electronic formats such as web downloads, through web services, through
> interactive web maps that grant users download access, KML Files or through
> file transfer protocols.

The second clause names web services and mobile applications explicitly, so
proxying through our own backend is named conduct rather than a workaround.

- **Allen Coral Atlas** — non-commercial Terms of Use, plus a prohibition on
  reproducing the global dataset without written ASU consent. Its documented
  WMS/WFS endpoints have additionally been timing out since approximately May
  2026, and its coral habitat product has not been updated since 2022.
- **UNEP-WCMC WCMC008 Global Distribution of Coral Reefs** — non-commercial.
  A keyless point-in-polygon endpoint does exist and works, but the licence bars
  use regardless.
- **Protected Planet / WDPA** — non-commercial, requires a token, and has no
  point-in-polygon endpoint. A keyless ArcGIS mirror exists but the licence
  still applies.

**OpenStreetMap Overpass** is excluded for a different reason: marine protected
area coverage is patchy. It missed Bonaire's Yarari Sanctuary entirely and
returned 1 of 4 areas at Molasses Reef. The `maritime=yes` tag appears on only
717 features globally against WDPA's 28,090 marine areas. Overpass also throttled
repeatedly under test, making it unsuitable for a synchronous call. It remains a
viable fallback for reef presence only (`natural=reef`, ODbL, attribution-only
for display) should the WRI licence question resolve unfavourably.

## Architecture

New feature directory following the existing domain/data/presentation split:

```
lib/features/reef/
  domain/
    entities/
      reef_habitat.dart          reef presence and threat classification
      reef_health.dart           SST, anomaly, DHW, hotspot, derived alert level
      reef_protection.dart       MPA identity, designation, IUCN, no-take
      nearby_species.dart        matched and unmatched species records
      reef_snapshot.dart         aggregate of the four, each independently statused
    services/
      bleaching_alert_level.dart derive alert level 0-7 from DHW and HotSpot
      species_catalog_matcher.dart match GBIF keys to the bundled 511
      coordinate_key.dart        quantization
  data/
    services/
      arcgis_feature_query.dart  shared ArcGIS request builder and parser
      reef_habitat_service.dart
      reef_health_service.dart
      reef_protection_service.dart
      nearby_species_service.dart
    repositories/
      reef_repository.dart       cache-aside orchestration
  presentation/
    providers/reef_providers.dart
    widgets/
      reef_section.dart
      reef_habitat_card.dart
      reef_health_card.dart
      reef_protection_card.dart
      nearby_species_tier.dart
      reef_attribution_sheet.dart
```

Habitat and protection are both ArcGIS FeatureServer queries with identical
request and response shapes, so `arcgis_feature_query.dart` holds that logic once
and each service describes only its endpoint, filter, and output fields.

Each file stays within the 200–400 line guideline.

## Storage

One new table in the existing local-only cache database
(`lib/core/database/local_cache_database.dart`, schema v6 to v7). The main
database stays at v136 and requires no migration.

```dart
/// Cached third-party reef data, keyed by quantized coordinate. Never synced,
/// never backed up: any device can re-derive this from a site's coordinates.
class ReefDataCache extends Table {
  TextColumn get provider => text()();   // habitat | health | protection | species
  TextColumn get coordKey => text()();   // quantized, e.g. "12.160,-68.280"
  TextColumn get variant => text().withDefault(const Constant(''))();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()();     // ok | empty | unavailable
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {provider, coordKey, variant};
}
```

`variant` carries the dive date (`yyyy-MM-dd`) for historical reef health and is
empty for everything else.

Choosing the local cache database rather than the main database avoids a schema
version bump, HLC timestamps, tombstones, merge rules, and backup inclusion. It
also means a restored database re-fetches rather than carrying another device's
stale reef data.

### Coordinate quantization

Coordinates are rounded to three decimal places, approximately 110 m, for both
the cache key and the outbound query. A cached entry is therefore exactly what
its key describes.

This is finer than every provider's own resolution: NOAA works on a 5 km grid,
GBIF on a 5 km radius, and the reef polygons are buffered to 300 m. Nearby sites
share entries, and editing a site's location misses the cache automatically.
Deleting a site leaves harmless rows that age out.

### Expiry

| Provider | TTL | Reason |
|---|---|---|
| habitat | none | Frozen 2011 dataset |
| protection | 90 days | Designations change yearly at most |
| species | 30 days | Occurrence records accrue slowly |
| health, current | 1 day | Updated daily by NOAA |
| health, historical | none | Immutable once the date has passed |

Negative results (`empty`) are cached under the normal TTL so a site that is
genuinely not on a reef is not re-queried on every view. Failures
(`unavailable`) are cached for one hour so a provider outage is not hammered.

## Data flow

`ReefRepository.snapshotFor(GeoPoint, {DateTime? date})` returns a `ReefSnapshot`
holding four independently statused parts. Providers run concurrently with
individually captured failures, so one outage never blocks the other three.
Concurrent callers for the same `(provider, coordKey, variant)` are deduplicated
to a single in-flight request.

Fetching happens when a site detail page is viewed, and only then. There is no
bulk prefetch and no background sweep.

### Species pipeline

A naive implementation is unusably slow. GBIF's facet query returns bare numeric
species keys, so resolving 300 keys to names would mean 300 follow-up requests at
roughly 0.4s each.

Instead, a build-time script resolves the 511 bundled species to their GBIF keys
once via `/v1/species/match?name=<scientificName>`, and the result ships as
`assets/data/species_gbif_keys.json`. Matching is then a set intersection against
the facet keys, costing zero extra requests.

The same script emits a second artefact: **the distinct set of GBIF order keys
across all 511 catalog species**, which becomes the query's taxon whitelist. This
is complete by construction — every catalog species' order is included, so no
catalog species can ever be filtered out — while excluding birds, insects, and
terrestrial plants, none of which appear in the catalog.

Deriving the whitelist rather than hand-writing it matters. A hand-written
"marine classes" list of invertebrates, corals, sponges, and sharks plus
order-level keys for bony fish would silently drop the catalog's 25 marine
mammals and 7 sea turtles. It would also hit a GBIF quirk: the backbone taxonomy
has no class rank for ray-finned fishes, so `classKey` filtering returns zero
fish while `taxonKey=587` (Perciformes) returns 14,864 occurrences at the same
site. Working at order level throughout avoids both traps.

Only the unmatched tail needs live name resolution via `/v1/species/{key}`,
capped at 25 entries and cached permanently, since a species key's name never
changes.

Matched species render with their common name, category icon, and category
colour from the existing `species_category_icon.dart` and
`species_category_color.dart` helpers, and each carries a one-tap action adding
it to the synced Expected list. Unmatched species render as scientific names
only.

The catalog contains no birds, no plankton, and no mangroves, so the matched tier
is inherently noise-free. The unmatched tier inherits the catalog-derived order
whitelist from the query itself, so it surfaces the regional long tail — species
in the same orders as catalog species but absent from it — without reintroducing
noise.

## Error handling

Three outcomes are distinguished, because collapsing them produces a misleading
UI:

- `ok` — data returned.
- `empty` — a definitive negative. This site is genuinely not on a reef, or
  genuinely not inside a protected area.
- `unavailable` — network or service failure.

"Not in a protected area" and "Couldn't check right now" must never render
identically.

Provider-specific failure modes, all observed during research:

- ERDDAP returns **HTTP 404 with a non-JSON body** for out-of-range coordinates
  or a future date. The status code is checked before parsing.
- ERDDAP returns **HTTP 200 with `null` values** for land, ice, and missing
  pixels. `CRW_DHW_mask` is requested alongside to distinguish them: 0 is valid
  water, 1 is land, 2 is missing, 4 is ice. A site landing on a land pixel falls
  back to a box query spanning approximately 0.075 degrees and selects the
  nearest pixel with `mask == 0`.
- ArcGIS returns **HTTP 200 wrapping a 400 error** when `where` is omitted, so a
  `where` clause is always sent.
- GBIF returns **HTTP 429** under rate limiting.

Services follow the existing `WeatherService` precedent: log and return a typed
failure, never throw into the UI.

### Bleaching alert level derivation

NOAA's `CRW_BAA` field is documented as 0–7 but the data caps at 4. During the
2023 Florida Keys event the API returned `BAA=4` where the official scale said
Level 5–6. **The raw code is never rendered.** The alert level is derived from
Degree Heating Weeks and HotSpot using the official table:

| Level | Label | Criteria |
|---|---|---|
| 0 | No Stress | `HotSpot <= 0` |
| 1 | Bleaching Watch | `0 < HotSpot < 1` |
| 2 | Bleaching Warning | `HotSpot >= 1` and `0 < DHW < 4` |
| 3 | Alert Level 1 | `HotSpot >= 1` and `4 <= DHW < 8` |
| 4 | Alert Level 2 | `HotSpot >= 1` and `8 <= DHW < 12` |
| 5 | Alert Level 3 | `HotSpot >= 1` and `12 <= DHW < 16` |
| 6 | Alert Level 4 | `HotSpot >= 1` and `16 <= DHW < 20` |
| 7 | Alert Level 5 | `HotSpot >= 1` and `DHW >= 20` |

The alert level is instantaneous while the damage is cumulative. On 2023-09-01
the API reported `BAA=1` — "Bleaching Watch" — while Degree Heating Weeks sat at
15.6, deep into mass-mortality territory, because HotSpot had briefly dipped
below 1°C. **Degree Heating Weeks is therefore always displayed alongside the
alert level, never behind a tap.**

### Date restriction

Health queries are restricted to dates from 2002-01-01 onward. NOAA's product
splices in UK Met Office OSTIA reanalysis for 1985–2002, and that segment carries
an academic-use-only clause; from 2002 the data is explicitly free and open under
GHRSST. Dives before 2002 show "not available".

## User interface

### Site detail page

A new `ReefSection` card, placed after the existing `TideSection` and before
`SiteMarineLifeSection`, with a row per capability:

- **Habitat** — reef presence and threat classification.
- **Health** — derived alert level, Degree Heating Weeks, sea surface
  temperature, and the observation date.
- **Protection** — area name, designation, IUCN category, no-take status, and a
  "View regulations" link to the ProtectedSeas page.

ProtectedSeas' `diving`, `entry`, `anchoring`, and `spear_fishing` fields are
**not rendered**. They are integer codes 0–3 with no published codebook, and
guessing wrong would put false regulatory information in front of someone
deciding whether to enter the water. The link-out sends divers to the
authoritative source instead.

The section is hidden entirely for sites without coordinates.

### Marine life

`SiteMarineLifeSection` gains a third tier beneath Spotted and Expected:
**"Recorded nearby"**. Catalog-matched species appear first with icon and
category colour and a one-tap add action; unmatched species follow as scientific
names, capped at 25.

### Dive detail

A new `reefHealth` entry in `DiveDetailSectionId`
(`lib/core/constants/dive_detail_sections.dart`), showing thermal stress on that
dive's date. It inherits the existing per-section show/hide and reorder settings
automatically.

### Units and localization

Sea surface temperature is stored in Celsius and converted for display according
to the active diver's unit settings. Degree Heating Weeks remains in °C-weeks in
every locale, since NOAA publishes no imperial equivalent, and is labelled as
such.

All strings are localized across the ten non-English locales, with generated
localizations regenerated.

### Attribution

CC BY 3.0 and CC BY 4.0 require attribution, and NOAA requests credit as a
courtesy. Each card carries an inline source label, and a `reef_attribution_sheet`
reachable from the section header names all four sources with links.

## Testing

Response fixtures are captured from the live endpoints during implementation and
committed, so tests never touch the network.

**Unit tests**

- Bleaching alert level derivation, including the verified Florida Keys 2023
  vectors: `DHW=13.95, HotSpot=1.69` yields Level 5, and `DHW=15.64,
  HotSpot=0.91` yields Level 1 with a catastrophic DHW that the UI must surface.
- Coordinate quantization, including sign handling and the antimeridian.
- Species catalog matching against the bundled key map.
- A guard test asserting the generated order whitelist covers every one of the
  511 catalog species. This is the regression that would otherwise silently drop
  marine mammals and sea turtles from results.
- Each parser's null, land-pixel, ice-pixel, and HTTP-404-non-JSON paths.
- ArcGIS empty-result parsing (a definitive `empty`, not an error).

**Repository tests**

Cache hit, miss, expiry per provider, negative caching, error caching, and
in-flight deduplication, against a fake clock and a mocked `http.Client`.

**Widget tests**

Every card in its `ok`, `empty`, `unavailable`, and loading states, plus the
species add action writing through to the Expected list.

Coverage target is the project standard of 80%.

## Items to confirm before shipping

1. **WRI Reefs at Risk licence.** The dataset is hosted on a UNEP-WCMC server
   whose general licence is non-commercial, but the data itself is WRI's under
   CC BY 3.0. The habitat capability rests entirely on that reading and needs
   written confirmation before the habitat card ships. If it does not hold,
   habitat degrades to an OpenStreetMap `natural=reef` lookup under ODbL, which
   requires attribution only for display.

2. **ProtectedSeas activity codebook.** Not required by this design, since those
   fields are not rendered. Worth requesting from ProtectedSeas now, because
   confirming it would unlock the richest part of that provider in a follow-up.
