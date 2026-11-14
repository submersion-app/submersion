# Site catalogue foundation and picker (slice 1)

Date: 2026-11-13
Status: draft for approval
Program: `2026-11-13-site-catalogue-program.md`

## Intent

A diver naming the site of a dive should rarely have to type more than a few
letters, and a site they pick should arrive with its details already filled
in. Today the app ships 3,667 built-in sites that the site picker never shows,
so a diver back from a trip creates every new site by hand even when the app
already knows it.

This slice puts built-in sites in the picker, makes picking one bring its full
details, and moves the built-in data into a format and a store that can grow
to tens of thousands of records in the next two slices. It ships the same
3,667 sites; the larger catalogue arrives in slices 2 and 3.

**What today's data can and cannot do.** Every record has a name, 3,311 have
coordinates and 3,290 a country, so this slice removes most of the typing.
The richer details are sparse: about 280 records have a depth, 323 an entry
type, 270 a feature list and 337 a description. "Salt Pier" in Bonaire, for
one, has a name and a position and nothing else. The adoption path built here
carries every detail a record has; most records gain those details in slices
2 and 3.

The words "catalogue" and "catalogue site" below mean the built-in data. "The
diver's sites" are rows in `dive_sites`. "Adopting" a catalogue site means
creating one of the diver's sites from it.

## Goals

1. Built-in sites appear in the site picker, by area without typing and by
   search worldwide.
2. Area memory: a dive with no GPS takes its area from the dives around it.
3. Tapping a catalogue site adopts it and assigns it in one tap.
4. An adopted site carries every detail the catalogue has, plus a stored link
   to its catalogue record.
5. One adoption path for the picker, GPS matching, the import page and the
   map.
6. The catalogue lives in the local cache database, loaded from a bundled file
   whenever that file changes.
7. A catalogue format that carries source, licence and trust level per record.
8. The app credits OpenStreetMap for this data.

## Non-goals

- New sites or new sources (slice 2), AI-researched sites and the "not
  verified" badge and matching rule (slice 3), filling gaps in existing sites
  or linking sites adopted before this slice (slice 4), catalogue site pages
  and the map showing catalogue sites by default (slice 5).
- Removing dive shops from the data, fixing the 356 records with no
  coordinates, and normalising region names. Slice 2 re-harvests.
- Loading map markers by viewport. The map overlay keeps loading every
  catalogue site with coordinates. This must change before slice 2's data
  ships and is planned there.
- A batch screen for naming a whole trip's sites.
- Carrying the link in shared site library documents.
- Any change to the filter picker or the media review picker.

## Anti-goals

- The picker waiting on the catalogue. It must open as fast as today and show
  built-in sites when they are ready.
- Built-in sites crowding out the diver's own. Their own sites always come
  first.
- Duplicate sites: a catalogue site offered again after the diver adopted it,
  or two taps creating two sites.
- Adoption writing boilerplate into fields the diver owns (notes,
  description).

## Constraints

- **Local cache database.** `lib/core/database/local_cache_database.dart`,
  schema version 20 today, its own ladder, runs on a worker isolate, also on
  the web build. Tables here are never synced or backed up. Parallel branches
  have collided on this ladder before, so new tables also get a
  `CREATE TABLE IF NOT EXISTS` backstop in `beforeOpen`, following the
  existing ones.
- **Main database.** Schema version 361 today. Tables live in
  `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`; never
  add either to `database.dart`. Renumber at merge time if main has moved.
- **Units.** Depths and distances shown anywhere follow the active diver's
  unit settings.
- **Localisation.** Every new string goes in all 11 ARB files.
- **Guards.** `test/architecture/` and `test/shared/` scan all of `lib/`. Known
  ones that bite here: no buttons or chips in `ListTile.trailing`; every new
  synced column needs a label in the conflict field catalogue; an
  indeterminate spinner in the picker hangs consumer tests that
  `pumpAndSettle`.
- **Licence.** The catalogue is treated as ODbL (see the program overview).
- **TDD**, files under 800 lines, platform-agnostic paths, `dart format .`.
- The PR needs an issue to link. None exists yet for this slice; open one
  before the PR.

## Approaches considered

The fork was where the catalogue lives on the device once it grows.

| | A. In memory | B. Local cache database | C. Ready-made database file |
|---|---|---|---|
| How | Parse the bundled file off the main thread on first use, hold it in memory with a grid index | A background job copies the bundled file into a table after each catalogue change; screens query it | The harvester ships a SQLite file opened read-only |
| For | Smallest change, one code path | Negligible memory, indexed lookups, same on web, scales past 100,000, later slices become queries | No import step |
| Against | Estimated 20 to 40 MB of memory at 50,000 sites and a re-parse every launch, both growing with the data | One-time import per catalogue change; about 10 to 15 MB more device storage at full size (estimated); a ladder step | Android needs a copy step anyway; the web build needs a separate route |

**Chosen: B**, by the maintainer. The catalogue is about to grow 8 times or
more; A gets worse with every site and B stays flat. C was dropped for
needing more machinery than B for the same result.

## Design

### 1. Catalogue file

`assets/data/site_catalogue.json` replaces `assets/data/dive_sites.json`.

```
{
  "metadata": {
    "format": 2,
    "generated_at": "...",
    "notice": "Contains information from OpenStreetMap, made available
               under the Open Database License (ODbL). ...",
    "sources": {
      "osm":     { "name": "OpenStreetMap", "licence": "ODbL-1.0",
                   "licence_url": "https://www.openstreetmap.org/copyright",
                   "credit": "OpenStreetMap contributors" },
      "curated": { "name": "Submersion", "licence": "ODbL-1.0", ... }
    }
  },
  "sites": [ { ...record... } ]
}
```

Each record:

| Field | Notes |
|---|---|
| `id` | Stable. Existing ids are kept unchanged (`osm_node_...`, `curated_...`). |
| `name` | Required. |
| `lat`, `lon` | Optional. A record without them is found by search only. |
| `country_code` | ISO 3166-1 alpha-2. |
| `country` | English name. |
| `region`, `locality`, `island`, `body_of_water` | Optional. `island` is written for a territory made of islands far apart (the Caribbean Netherlands: Bonaire, Saba, Sint Eustatius), from the geocoder's subdivision code. The file carries no `body_of_water`: the app names each site's sea when it imports the file (section on storage). |
| `water_type` | Optional; a `WaterType` name. |
| `min_depth_m`, `max_depth_m` | Optional, metres. |
| `types` | Built-in site type ids (`wreck`, `wall`, `reef`, `lake`, `cave`, `cavern`). |
| `entry` | `EntryMethod` names. |
| `features` | The source's remaining descriptive tags (drift, sharks, training). Kept for later slices; not copied on adoption. |
| `difficulty` | Optional; a `SiteDifficulty` name. No data yet. |
| `hazards`, `description`, `website` | Optional text. |
| `source` | A key into `metadata.sources`. |
| `source_ref` | The record's origin: an OpenStreetMap object URL, or the URL a curated position cites. |
| `trust` | `verified` or `researched`. Every record in this slice is `verified`. |

Mapping from source values to app names (`types`, `entry`, `water_type`)
happens in the scripts, so the app reads names it already knows. An unknown
name in the file is dropped on read, never an error.

A sidecar, `assets/data/site_catalogue.version`, holds a content hash of the
data file. The app compares it to decide whether to import, so it never parses
the large file just to check. A test fails when the sidecar does not match the
file.

The file stays plain JSON in this slice. Whether to compress it is decided in
slice 2, when its size is known.

### 2. Scripts and this slice's data

- `scripts/dive_site_harvester.py` and `scripts/curated_sites.py` write the new
  format, including the sidecar. Curated entries keep the source URL they
  cite, which is stripped today.
- This slice ships the existing 3,667 records converted to the new format,
  with country normalised to an ISO code and an English name (today's values
  include "Deutschland", "مصر" and "Schweiz/Suisse/Svizzera/Svizra").
- The country is resolved per record from its coordinates, not per distinct
  country string: all 64 Bonaire records say "Nederland" today, and a string
  lookup would file them under the Netherlands. A plain geocoder answer is
  not enough either: measured on 2026-11-13, Nominatim reports a Bonaire
  position as country code `nl`, "Netherlands", with the subdivision code
  `BQ-BO`. So the rule is: when the geocoder's ISO 3166-2 subdivision code
  begins with an ISO 3166-1 code other than the reported country code, that
  territory code wins, with its English name (Bonaire becomes `BQ`,
  "Caribbean Netherlands"). Every shipped `country` must resolve to its
  `country_code` through the app's own `countryCodeFor`, and a test checks
  it. A record without coordinates keeps its country only when the string
  resolves unambiguously, otherwise it has none. The lookup method (a rate
  limited geocoder run or an offline boundary set) is the builder's choice.
- **Depth.** The harvester fills `min_depth` from OpenStreetMap's
  `scuba_diving:depth`, which is the site's depth and not its shallowest
  point. Conversion rule: a lone depth becomes `max_depth_m`; equal values
  become `max_depth_m` only; when both exist and the minimum exceeds the
  maximum they are swapped.
- `assets/data/dive_centers.json` and its loader are untouched.
- **Demo data generator.** `tool/demo_data/` reads `dive_sites.json` and picks
  sites and centres by raw country strings
  (`tool/demo_data/src/story/catalog.dart`, `destinations.dart`). It is in
  scope: it reads the new file and field names, and a destination keys its
  sites by country code while its centres keep their existing strings. Its
  tests and README follow, and its output is regenerated as that README
  describes if the output is committed. `scripts/curated_sites_test.py` also
  names the old file.

### 3. Storage and import

Two tables in the local cache database (ladder 20 to 21, plus the `beforeOpen`
backstop):

- `site_catalogue`: one row per record, keyed by `id`. List fields are stored
  as text. A `search_text` column holds the folded text search runs against
  (name, country, region, locality, island, body of water), produced with
  the same folding the picker uses for the diver's sites. The folded name
  comes first and ends at a mark, so the column also gives the order of a
  list by name and tells a match in the name from a match in a place.
  Indexed for bounding-box lookups on latitude and longitude.
- Search order: sites whose own name holds every typed word come first,
  then sites matched only by a place or a sea; within each, sites in the
  dive's area lead, then by name. Added after the second review: a sea's
  name is made of common words ("sea", "north", "red") and holds hundreds
  of sites, which buried the sites actually named with those words.
- The body of water is filled at import, not in the file: a located record
  that names none takes the sea at its position from the bundled sea table
  (`assets/data/sea_areas.json`, the one the geocoder uses for the diver's
  own sites). A record the catalogue says is fresh water (its water type,
  or a lake, quarry, river, spring, cenote or pool type) is left without
  one, because the sea table reaches a few kilometres inland. Added after
  the review: without it a search for "Red Sea" found one site.
- A small meta record holding the imported version and format.

Import:

- Runs after the local cache database opens, on every platform. Startup does
  not wait for it.
- If the sidecar version equals the stored version, it does nothing.
- Otherwise it decodes the file off the UI isolate where the platform allows,
  then, in one transaction, deletes every catalogue row, inserts the new rows
  in batches and writes the new version. A reader sees the old catalogue or
  the new one, never part of one.
- On failure it logs, leaves the old rows in place and tries again next
  launch.
- The catalogue reports whether it is ready. Screens that show catalogue sites
  re-query when it becomes ready. While the very first import runs, built-in
  sites are simply absent; no spinner is shown.
- Because this data is derivable, a later format change may drop and re-create
  the table.

### 4. Catalogue interface

A `SiteCatalogue` interface in the dive sites feature, with one implementation
over the local cache database and a fake for tests:

- `near(point, radius, limit)`: sites within the radius, nearest first.
- `search(query, areaFirst, limit)`: sites whose `search_text` matches every
  word of the query, those within the area first, then by name. A query that
  names a country in any language ("Thaïlande", "Ägypten", or the start of
  such a name) also finds the sites carrying that country's code, ranked as
  place matches. This carries issue #4520's fix over from the bundled list
  the catalogue replaces, using the same `countryCodesMatching` recognizer
  as the search of the diver's own sites. The query is read as a country
  only as a whole: "blue hole égypte" names none.
- `byId(id)`.
- `allWithCoordinates()`: for the map overlay, until slice 2 replaces it.
- A readiness signal.

`CatalogueSite` is the domain entity for a record. `ExternalDiveSite` and
`DiveSiteApiService` are removed; their consumers move to this interface:
`SiteMatchingService`, `site_suggestion_providers.dart`,
`ExternalSiteSearchNotifier` and `SiteImportPage`, the map page and content,
`BuiltInSiteMarkerLayer`, `BuiltInSiteInfoCard`, `built_in_site_dedup.dart`
and `built_in_sites_providers.dart`.

One function decides which catalogue sites a diver is offered. It has two
rules:

- **By link.** A catalogue site is hidden when one of the diver's sites
  carries its id as a link. A linked site hides only its own record.
- **By position.** A catalogue site is hidden when one of the diver's
  *unlinked* sites lies within 150 m of it (today's map rule). This covers
  sites the diver made by hand or adopted before this slice.

Linked sites are left out of the position rule on purpose: 423 located records
lie within 150 m of another record, almost always under a different name
("Barracuda East" and "Barracuda West"), and adopting one must not hide its
neighbours.

Where each rule applies:

| Place | By link | By position |
|---|---|---|
| Picker, by-area section | yes | yes |
| Map overlay | yes | yes |
| Picker, search results | yes | no |
| Import page | shown as already in the diver's sites | no |

Search and the import page skip the position rule because a diver who looks a
site up by name should always be able to reach it. The import page's link
check replaces its session-only flag.

### 5. Picker

```
Dive 4 of 12  >  Site
+------------------------------------------+
| Search sites                             |
+------------------------------------------+
 YOUR SITES NEAR BONAIRE
   Salt Pier         shore  5-15 m   reef
   Hilma Hooker      shore  18-30 m  wreck

 MORE SITES NEAR BONAIRE
   1000 Steps        shore  6-30 m   reef   (i)
   Alice in Wonderl. shore  9-30 m   reef   (i)
   Bari Reef         shore  3-25 m   reef   (i)
   ...
   Show all 89

 (the diver's other sites, grouped by country, as today)
```

- **Where it shows.** `showSitePicker` gains a flag for built-in sites, off by
  default. `pickOrCreateSite` turns it on exactly when its `allowCreate` is
  true: the dive edit page, bulk edit and the track detail page. The track
  import review page passes `allowCreate: false` on purpose and so shows no
  built-in sites. The planner's picker turns the flag on explicitly. It stays
  off for the filter picker and the media review picker, where picking must
  not create a site.
- **Demo mode.** Built-in sites are offered in demo mode. Demo mode seals the
  import page as a file import route; creating a site and the map's "Add to
  my sites" are open there, and the picker matches them.
- **Order.** The diver's nearby sites, then the built-in section, then the
  diver's grouped list. The built-in section shows its first five rows and a
  "Show all N" row that expands it in place.
- **A diver with no sites** sees the built-in section, not only today's empty
  state.
- **Rows.** Name, then one line with the location, entry, depth range in the
  diver's units, and type, leaving out whatever is missing. Each row has an
  information affordance that opens a details card. It must satisfy the
  `ListTile.trailing` guard.
- **Tap.** Adopts the site (section 7), then closes the picker with it, exactly
  as tapping one of the diver's own sites does. A second tap while adoption
  runs does nothing. If adoption fails, the picker stays open and says so.
- **Details card.** `BuiltInSiteInfoCard` grows to show location, depth range,
  types, entry, hazards, description, website and the source credit, with one
  action: "Use this site" in the picker, "Add to my sites" on the map,
  "Import to My Sites" on the import page (added after the third review; the
  page had a sheet of its own that showed less). For a site the diver
  already has, the import page shows the action disabled.
- **Search.** With text in the field, the diver's matches show as today. Below
  all of them, nearby or not, a "Built-in sites" section shows up to 50
  catalogue matches from the whole world, in the order the storage section
  gives (name matches first, the current area leading). The catalogue query is
  debounced and needs at least two characters.
- **Section label.** "More sites near <place>", where the place is the anchor
  site's island, else region, else country. With no place name it reads "More
  sites nearby".

### 6. Area anchor

The picker measures "near" from one anchor, used for both the diver's nearby
sites and the built-in section. In order:

1. The dive's own entry or exit GPS (today's behaviour).
2. The site of the nearest dive in time that belongs to the same trip and has
   a site with coordinates.
3. The site of the nearest dive in time within 3 days either side that has a
   site with coordinates.
4. The device's location (today's fallback, including the fix the dive edit
   page already captures).

Steps 2 and 3 exclude the dive being edited, are scoped to the active
diver, and ignore planned dives: a plan says where the diver means to go, not
where a logged dive was. For a new dive not yet saved, the form's date, time and trip are used.
For a bulk edit, the earliest selected dive is used. The planner passes no
anchor, so there the built-in section appears on search only.

Radius: 50 km, the picker's existing nearby radius.

Ordering depends on how the anchor was found:

- Measured (steps 1 and 4): by distance, with the distance shown, as today.
- Inferred from another dive (steps 2 and 3): by name, with no distance, since
  distance from a neighbouring site says little about this dive.

The picker's header caption gains a wording for the inferred case.

The phone comes last deliberately: many divers log at home, where the device
location points at the wrong place.

### 7. Adoption

One function creates a diver's site from a catalogue site. The picker, GPS
matching (`SiteMatchingService`), the import page and the map's "Add to my
sites" all call it.

| Diver's site field | From the catalogue |
|---|---|
| name, description | `name`, `description` (no "Features:" line appended) |
| coordinates | `lat`, `lon` |
| min depth, max depth | `min_depth_m`, `max_depth_m` |
| country, country code, region, city, island, body of water | the matching fields |
| water type | `water_type` |
| hazards | `hazards` |
| entry methods | `entry` (exit methods are left unset) |
| site types | `types` |
| difficulty | `difficulty` |
| catalogue link | `id` |
| notes, rating, access notes, parking, mooring | left empty |
| altitude | left empty, then filled best-effort from the elevation service, as matching does today |

- The "Imported from Bundled dive site database" note is no longer written.
- If the diver already has a site linked to this catalogue id, adoption returns
  that site and creates nothing.
- GPS matching keeps its own existing guards (batch dedup, reuse of a diver's
  site within 100 m).
- **Logbook rules.** Adding a built-in site counts as creating a site by hand,
  and every existing path runs the diver's "after create" rules for it
  (`captureRulesAfterCreate`, as in `site_map_page.dart`). Those rules need
  page context, so they stay with each caller and not inside the adoption
  function. The picker runs them too, and waits for them before it returns
  the site, so the dive form copies the site's values as the rules left them.
- Assigning the adopted site to a dive goes through the dive edit page's
  existing `_assignSite`, which already copies the site's water type, entry
  and exit methods, dive types and altitude onto the dive. No change is needed
  there.
- If the diver then cancels the dive edit, the adopted site stays, as a site
  created through "New Dive Site" does today.

### 8. The link

- New nullable text column `dive_sites.catalogue_id` (main schema 363; planned
  as 362 and renumbered when main took that number),
  on the `DiveSite` entity with `copyWith` and in the row mapper.
- The repository writes it when a site is created and when a merge or its
  undo rewrites a site. The ordinary update path leaves the column alone, as
  it does the shared library id: the site edit page saves a `DiveSite` built
  fresh from its form, and an update that wrote the link would erase it on
  every edit.
- It syncs as an ordinary site column, with a label in the conflict field
  catalogue.
- It travels in the database backup. UDDF export writes it as a new element
  on the site, beside the app's other site elements (`sitealtitude`,
  `mooringnumber`), and UDDF import reads it back; a round-trip test covers
  it. A link cannot be re-derived from anything else in the file, and site
  attributes missing from UDDF have been treated as bugs here before (#2200,
  #2201). CSV does not carry it.
- Merging two sites keeps the survivor's link, or takes the other site's when
  the survivor has none.
- It is not editable. Editing or moving a linked site leaves the link in
  place: it records where the site came from.
- It is not written into shared site library documents in this slice.
- Sites adopted before this slice have no link. The 150 m rule still hides
  their catalogue twin. Slice 4 links them.

### 9. Source credit and website

- The site detail page shows a short credit for a linked site whose catalogue
  record still exists: that it was added from the built-in catalogue, the
  source's credit, and the website when the record has one. It is a caption,
  not a new configurable section.
- The website is read through the link and not copied onto the diver's site,
  so no new editable column is needed. It opens only as an http or https
  address: the value comes from a source anyone can edit.
- The OpenStreetMap credit required by ODbL is added where the app lists its
  other data credits: the licence page, reached from the About dialog, as the
  sea area and bathymetry data do. It names the data as ODbL with a link to
  openstreetmap.org/copyright. The notice also ships in the file's metadata.
- `docs/user/dive-sites.md` is updated for the picker and the credit.

## Calls the designer made

The maintainer decided the sources, the naming flow, the scope of "richer",
the slice order, the storage approach and adopt-on-tap. Everything else in the
design is the designer's call, shown to the maintainer in summary. The ones
most worth checking:

- The anchor order and the 3-day window (section 6).
- Sorting by name when the area is inferred.
- Which pickers show built-in sites.
- Dropping the "Imported from" note and the "Features:" line.
- The website shown through the link and not copied.
- Unmapped features (drift, sharks, training) are not copied on adoption.
- The trust level is stored now; its badge and matching rule arrive in
  slice 3.
- The link is left out of shared site library documents.
- The built-in section shows five rows before "Show all".
- The position rule skips linked sites and does not apply to search or the
  import page (section 4).
- A lone source depth is read as the maximum depth (section 2).
- The link is carried in UDDF as a new element (section 8).
- Built-in sites are offered in demo mode and not on the track import review
  page (section 5).
- The picker waits for the diver's "after create" rules before returning an
  adopted site (section 7).

## Known gaps after the build

- Merging two sites that were both adopted keeps one link (section 8), so
  the other site's catalogue record is offered again. Closing this needs a
  place to remember records a diver merged away; proposed for slice 4.
- Two devices that each adopt the same record before they sync end with two
  sites carrying the same link.
- An adopted site carries the catalogue's English country name even when the
  diver's place-name language is another one. Its sea is named in that
  language when it is adopted, as the geocoder names it for the diver's
  other sites; searching the catalogue by sea, region or island still takes
  the name the catalogue holds (English for seas). Only a country is found
  by its name in another language.
- A fresh-water site whose record carries no water type and no site type,
  and which lies within the sea table's 4 km shore allowance of tidal
  water, is given that sea: at least seven lakes beside the Elbe, the Weser
  and the Scheldt read "North Sea", roughly 10 to 30 of the 2,297 sites
  that get a sea. The app's geocoder names a diver's own site there the
  same way. Water types from the data clean-up (slice 2) close it.
- "Red Sea" finds the sites the sea table files under that name. The Gulf
  of Aqaba and the Gulf of Suez are seas of their own there, so Dahab and
  Eilat are found by "Aqaba", not by "Red Sea".

## Left to the builder

- File and class layout, provider names, the exact table and index
  definitions, batch sizes and the debounce interval.
- The lookup method behind the per-record country normalisation.
- How the picker row carries the information affordance within the guards.
- The exact strings and their keys.
- Where on the site detail page the credit caption sits.
- How the new column behaves between devices on different app versions: follow
  the project's existing rule for a new synced column.

## Acceptance

The scenarios use a fixture catalogue whose records carry full details. The
shipped record for "Salt Pier" has only a name and a position, so the real
data cannot show them.

1. **Search and adopt.** A dive with no GPS, no neighbouring dives and the
   phone far from any site: the picker opens as today. Typing "salt" lists the
   diver's matches, then built-in matches. Tapping "Salt Pier" closes the
   picker with a new site of the diver's that has the catalogue's depth, type
   and entry, an empty notes field and a link. The dive takes the site's entry
   method through the existing assignment.
2. **Area memory.** The next dive of the same trip, or one within 3 days,
   opens with "More sites near <place>" and no typing. "Salt Pier" is under
   the diver's own sites and not in the built-in section, while a catalogue
   site 100 m from it under another name is still offered.
3. **New diver.** A diver with no sites sees the built-in section.
4. **Unchanged pickers.** The filter picker and the media review picker show
   no built-in sites.
5. **Import.** On the first launch after the update the app starts without
   waiting. Built-in sites appear in the picker once the import finishes. A
   second launch imports nothing. A launch with a changed catalogue file
   replaces the rows.
6. **Other screens.** GPS matching, the import page and the map overlay offer
   the same sites as before and now adopt with full details and a link. The
   import page marks a site as already in the diver's sites when it is
   linked, across sessions.
7. **Sync.** On a second device the adopted site arrives with its link, and
   its catalogue twin is hidden there.
8. **Credit.** The OpenStreetMap credit is visible in the app's data credits,
   and a linked site's page shows its source.

## Testing

Tests first. At least:

- Anchor resolution: each of the four steps, the exclusions, the new-dive and
  bulk-edit cases.
- The catalogue over a real local cache database: `near`, `search` (every
  word, area first, folding), `byId`.
- Import: first import, no-op on the same version, atomic replace on a new
  version, old rows kept on failure, unknown names dropped.
- The hidden rules: by link; by 150 m of an unlinked site only; a linked site
  does not hide its neighbours; search and the import page skip the position
  rule.
- Adoption: the field mapping, the already-linked guard, no boilerplate, and
  the picker returning only after the "after create" rules ran.
- The script conversion: the depth rule, and country by coordinates (a Bonaire
  record does not become the Netherlands).
- The demo data generator's own tests against the new file.
- The link: migration, mapper round trip, sync round trip, merge, UDDF.
- Picker widget tests: sections and order, five rows then expand, zero-site
  diver, tap adopts once, flag off shows nothing, catalogue not ready.
- The data file: every record has `id`, `name`, `source` and `trust`; ids are
  unique; every `source` is declared; the sidecar matches.
- The script tests in `scripts/`.
- `test/architecture/` and `test/shared/` after adding files.
