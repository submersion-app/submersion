# Species map

## Why

A diver wants to know which species turn up where, for two reasons:

- **Looking back:** "Where have I seen mantas?" and "What have I seen at Blue
  Corner?" Today the answers are scattered: the Species page lists what was
  seen, a species' detail page lists its sightings as rows, and a site's page
  lists its spotted and expected species. Nothing puts them on a map.
- **Planning:** "Where could I see a manta?" and "What lives around the place
  I'm going?" A logbook only knows places the diver has already been, so this
  needs records from other people too.

The maintainer wants both directions (species to places, place to species) and
both sources (own logbook, public records).

## Goals

- A dedicated **Species Map** page that answers both directions from the
  diver's own logbook, with an optional public layer for planning.
- A small **"Where seen"** map on each species' detail page that opens the
  Species Map focused on that species.
- The diver's own data and public records are always visually distinct.
  "I logged it here 6 times" and "someone recorded it within 5 km once" must
  never look alike.
- The public layer is **off by default**. With it off, the feature sends
  nothing to any outside service.
- Works offline for the diver's own data (map tiles aside, which follow the
  app's existing offline map behaviour).

## Non-goals

- A month or season filter on the public layer. Considered and held back; a
  later change can add it (GBIF supports a `month` filter on occurrence
  searches and map tiles).
- Adding public species to the diver's catalog from the map. Public species
  that are not in the catalog are shown, not imported.
- Changes to how sightings or expected species are recorded.
- A schema change. Everything the map needs is already stored.
- Changing the site page's existing "nearby" tier. It keeps fetching as it
  does today; the map's public toggle governs the map only.
- iNaturalist as a public source. Its records are mostly CC BY-NC, which the
  app deliberately does not ship (see below).

## Anti-goals

- Public records that read as the diver's own sightings, or that inflate the
  diver's counts anywhere.
- Any request to GBIF from the species map while the public layer is off,
  including prefetching.
- Public records under a licence the app does not ship (anything other than
  CC0 1.0 and CC BY 4.0).
- Land animals in a diver's "nearby" list.
- A map that silently drops data. Sightings that cannot be placed (dive with no
  site, or a site with no coordinates) are counted and said so, not hidden.

## Data sources (already in the app)

- `sightings` (per dive, `species_id`, `count`) joined to `dives` (`site_id`,
  `diver_id`) joined to `dive_sites` (`latitude`, `longitude`, both nullable).
- `site_species`: "expected" species per site, curated by the diver or, for
  shared site library sites, by the library's members.
- `species`: the catalog (built-in and custom), with `scientific_name`
  (nullable).
- Scoping follows the Species page (`SeenSpeciesRepository`): the current
  diver's dives (`currentDiverIdProvider`), filtered by
  `DiveStatsScope.and(alias: 'd')`, and NOT by the Insights filter. Note that
  `SpeciesRepository.getSpeciesSpottedAtSite` is not diver-scoped; the map's
  queries must be.
- Table ticks: the same three as `seenSpeciesProvider` (`species`,
  `sightings`, `dives`), plus `site_species` for expected pins and
  `dive_sites` for a site moved or renamed.

## Public source: GBIF, reusing what the app already has (builder's call)

The site page already shows a "nearby" tier from GBIF
(`NearbySpeciesService`, `ReefRepository.speciesFor`,
`reefNearbySpeciesProvider`, drawn by `NearbySpeciesTier`). The map reuses it
rather than adding a second source, so a site never shows two different
"nearby" lists one tap apart. What it already does, and the map inherits:

- 5 km radius around the site (it measurably cuts land records against
  10 km).
- Licence filter: only CC0 1.0 and CC BY 4.0 records. About a quarter of reef
  records are CC BY-NC; shipping them would be a licensing violation. This is
  also why iNaturalist, whose records are mostly CC BY-NC, is not used.
- Aquatic taxon whitelist generated from the catalog
  (`assets/data/species_gbif_keys.json`, `SpeciesCatalogMatcher`), plus the
  terrestrial family drop list (issue #1036: foxes and badgers once showed up
  in a diver's list).
- Catalog matching: records that match a built-in species carry its id.
- A 30-day cache keyed by quantized coordinate (`ReefCacheDao`), so a site's
  nearby list works offline once fetched.

New for the map, species mode's public layer: GBIF map tiles for one taxon,
with the same licence filter:

`https://api.gbif.org/v2/map/occurrence/adhoc/{z}/{x}/{y}@1x.png?taxonKey=<key>&license=CC0_1_0&license=CC_BY_4_0&occurrenceStatus=PRESENT&hasGeospatialIssue=false&...`

(verified live: the `adhoc` endpoint honours `license`; the plain `density`
endpoint does not take it, so it must not be used). The builder picks the bin
and style (`bin=square` or `hex`, a `style` that reads over the app's map
styles).

Resolving a catalog species to a GBIF taxon key:

- Built-in species: from `species_gbif_keys.json` via `SpeciesCatalogMatcher`
  where the species has its own species-rank key.
- Otherwise (custom species, or a built-in without a species-rank key): GBIF
  `/v1/species/match?name=<scientific name>`, accepting only an exact or
  confident species-rank match, cached for the session.
- No scientific name, or no confident match: no public layer for that
  species, and the page says why.

Requests use the reef services' User-Agent and timeout. Failures and offline
show a short inline note on the public layer, never an error page; the
diver's own data still shows.

Attribution: while the public layer is on, the map shows "Records: GBIF.org"
beside the existing tile attribution, linked to the existing reef
attribution sheet (`reef_attribution_sheet.dart`) or GBIF's citation page.

## The Species Map page

Route: `/species/map` (a static path declared before `/species/:speciesId`),
with an optional `?species=<id>` to open with a species picked. Opened from a
new map icon button in the Species page's app bar.

Layout reuses `MapListScaffold`, like the Sites map: on master-detail widths a
list pane on the left and the map on the right; on narrower widths the map
only, with a search field in the app bar to pick a species.

### List pane / species picker

- Lists the species the diver has seen, with "N sightings, M sites", sorted
  like the Species page's default.
- Search covers the whole catalog, so a diver planning a trip can pick a
  species they have never seen. Unseen species show "Not seen yet".
- Selecting a species switches the map to **species mode**; clearing the
  selection returns to **places mode**.

### Places mode (nothing picked): "what lives here"

- One pin per site that has at least one placed sighting by this diver. The
  pin shows the number of distinct species logged there, and its size grows
  with that number. Pins cluster with the same cluster layer the Sites map
  uses (`WorldWrappedMarkerClusterLayer`).
- Tapping a pin opens the info card (bottom sheet on phone, card on desktop)
  for that site:
  - the site name, linking to the site's page;
  - species the diver has logged there, with sighting counts, most seen
    first, each linking to the species' page;
  - expected species not yet logged there, marked as expected;
  - with the public layer on: "Recorded nearby by others", the same GBIF
    result the site page's nearby tier shows (`reefNearbySpeciesProvider`
    for the site's location), rendered the same way: matched species as
    chips linking to the species, unmatched ones by scientific name only.
    The card does not offer the tier's "add to Expected" action (non-goal:
    no curation from the map).
- With the public layer on and no site tapped, nothing is fetched. Public
  "nearby" lists load only for the site the diver opens.

### Species mode (a species picked): "where does it turn up"

- **Solid pins** at sites where the diver logged it, labelled with the total
  sighting count at that site (sum of `sightings.count`).
- **Hollow pins** at sites where it is expected but not yet logged.
- **Public layer**, when on: GBIF's licence-filtered tiles for that taxon,
  drawn under the pins in a colour distinct from the pins.
- The camera fits the diver's pins (solid and hollow). With none, it fits the
  world, and the page suggests turning on the public layer when it is off.
- Tapping a solid pin shows that site's sightings of the species: date, dive
  number, count, with links to the dive and the site. Tapping a hollow pin
  shows the site and "Expected here".
- A line under the map, only when non-zero: "N sightings are on dives without
  a mapped site", so nothing is silently dropped.

### Layers control and the public toggle

- A layers button in the map corner controls (`MapCornerControls`) holds the
  "Public records (GBIF)" switch, with one line saying it sends the picked
  species, or the tapped site's location, to GBIF.
- Off by default. Once turned on, it stays on for this device until turned off
  (builder's call: a device preference, not a synced diver setting, because it
  governs what this device sends).
- A legend on the map names what each mark means: my sightings, expected,
  public records (the last only while on).

### Which sites' expected lists count (an option, decided in chat)

Expected species are not always the diver's own curation: a site from a
shared site library carries an expected list its members curate (issue
#2567). The maintainer chose to make the scope an option, in the same layers
control:

- **My sites** (default, builder's call): sites the current diver owns
  (`dive_sites.diver_id` is theirs) or has logged a dive at.
- **All sites I can see**: every site `VisibilityFilter.applyToDiveSites`
  shows the diver (own, shared, shared with them, and shared library sites,
  minus hidden ones).

It governs the hollow pins in species mode and the "expected, not yet logged"
entries in the places-mode card. It never affects the diver's own sightings
(solid pins), which always cover every site they logged. Remembered on this
device like the public toggle.

## "Where seen" on a species' detail page

- A new section on `SpeciesDetailPage`, above the existing Sightings section:
  a small non-interactive map (fixed height, about 160 px) with the diver's
  solid and hollow pins for that species, fitted to them.
- Under it, up to three sites by sighting count ("Manta Point (6), Crystal Bay
  (2)...") and an "Open full map" button to `/species/map?species=<id>`.
- When the diver has no placed sightings and no expected sites for it, the
  map is replaced by a short line and the same button, so the page can still
  reach the public layer.
- This section never shows the public layer and never calls GBIF.

## Units and language

- The "nearby" radius is the existing service's 5 km. Where the card states
  it, it is shown in the active diver's distance unit.
- All new strings go through the ARB files in every locale the app ships.
  Species names use the existing localized lookups
  (`localizedCommonName`).

## Left to the builder

- Pin sizes, colours and the public tile style, within the rule that own,
  expected and public marks are distinct in light and dark themes.
- How the repository queries are split (a new `SpeciesMapRepository` beside
  `SeenSpeciesRepository` is the expected shape, since `SpeciesRepository` is
  at the file-size cap).
- Whether the detail page's mini map reuses the full page's marker widgets.
- Empty states and loading states, following the Sites map.

## Testing

- Repository: per-site aggregates for places mode and per-species aggregates
  for species mode, diver scoping, `DiveStatsScope` exclusions, sightings on
  dives without a site or with an unmapped site counted as unplaced, expected
  pins that exclude sites already logged, and the expected-scope option
  (my sites versus all visible sites, hidden sites excluded).
- GBIF: tile URL building (licence filter always present, `adhoc` endpoint),
  taxon key resolution (matcher first, then a confident species-rank match,
  else none), session caching, failure handling, and a test that no request
  is made while the toggle is off.
- Widgets: the page in both modes, the toggle defaulting to off, the legend,
  the detail page section with and without placed data, the route with
  `?species=`.
