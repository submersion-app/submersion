# Site catalogue: browse before diving (slice 5)

Date: 2026-11-14
Status: approved 2026-11-14
Program: `2026-11-13-site-catalogue-program.md`
Issue: #4514

## Intent

Slices 1, 2 and 4 put the built-in catalogue where a diver logs: the site
picker offers it, GPS matching uses it, and sites the diver already has can
take its details. All of that happens after a dive. Before one, the
catalogue is hard to look at. Its sites are on the Sites map only after the
diver finds a switch that is off and forgets itself at every launch, and
all a record can show is a small card with one button.

This slice lets a diver look around the catalogue ahead of a trip. Built-in
dive sites are on the Sites map without being asked for, every catalogue
record has a page of its own that can be read without adding the site, and
a site known by name can be found from the Sites search. A diver who has
read about a site and added it before the trip then finds it already in
their logbook when they log the dive, which is the program's "less typing"
goal reached from the other side.

Terms. A **record** is one row of the built-in catalogue. A **dive site
record** comes from a source that lists places people dive; a **register
record** comes from a wreck register or a reef deployment list
(`CatalogueKind.site` and `CatalogueKind.register`). A record is **yours**
when one of the diver's sites claims it: by its `catalogueId`, or through
`catalogueAnswers.also` after a merge (`linkedCatalogueIds`). The
**built-in page** is the new read-only page for a record that is not
yours.

## What exists today

Slice 2 delivered part of "catalogue sites on the map", so this slice
starts from the following.

- **Map overlay.** Both Sites maps (`site_map_page.dart` on a phone,
  `site_map_content.dart` in the split pane) draw built-in records as
  hollow grey pins under the diver's own, read only the records in view
  through `SiteCatalogue.inBounds`, and stop at 1,500 markers with a note
  to zoom in. A record that is yours, or that lies within 150 m of one of
  the diver's unlinked sites, is not drawn.
- **Its switch.** `showBuiltInSitesProvider` is a `StateProvider<bool>`
  that starts false and is held in memory, so the overlay is off at every
  launch. Dive site records and register records share the one switch and
  the one pin.
- **A record without adopting it.** One card, `BuiltInSiteInfoCard`: name,
  place line, chips for type, entry and depth, hazards, description, the
  source's credit, a website button, and one action. It is shown on the
  map for a tapped pin, and in a bottom sheet from the picker's
  information button and from an Import result.
- **Not shown anywhere:** the record's position (no coordinates, and no
  map in the sheet), its sea, its water type, the source's full name and
  licence, a link to the source's own record, whether it is a dive site or
  a register record, and what lies near it. There is no route to a record,
  so nothing can link to one.
- **Search.** The Import page (Sites list, overflow menu, Import) searches
  the whole catalogue by name, place or sea. The Sites list's own search
  field searches only the diver's sites.

## What was decided

Chosen by the maintainer on 2026-11-14.

- **A page of its own.** A record gets a read-only page with a route, not
  a larger card and not the diver's own site page in a preview mode (see
  "Approaches").
- **A record that is yours opens your own site page,** never the built-in
  page.
- **On the map by default: dive site records only.** Register records are
  a second layer with its own switch, which starts off. This is the split
  the picker makes with its closed "Wrecks and reefs" section.
- **Every diver gets the default,** existing ones included: nothing about
  the overlay was ever stored, so there is no earlier choice to respect.
- **The two switches are remembered on this device only.** No database
  column and no sync.
- **Register records get their own glyph** on the map, in the same grey,
  so the two layers can be told apart when both are on.
- **By name: the Import page, and one row in the Sites search.** An Import
  result opens the built-in page. Under the Sites list's search field, a
  row offers to search built-in sites for the typed words and opens the
  Import page with that search run. No built-in rows are mixed into the
  diver's list.
- **Adding from the page opens the diver's own new site page,** replacing
  the built-in page.
- **Wide windows** show the same page, pushed over the map or the list,
  with its content held to a readable column.
- **The page carries the tide and reef cards** the diver's own site page
  has, which need only a position. The 3D seascape card is left out.

## Goals

1. Built-in dive site records are drawn on both Sites maps without the
   diver doing anything.
2. The diver can turn dive site records off, turn register records on,
   and find both choices kept at the next launch on that device.
3. Register records on the map are told apart from dive site records at a
   glance.
4. Every record has a page that shows everything the catalogue holds for
   it, its position on a map, its source with licence, what is near it,
   and tides and reef for its position.
5. The page is reached from a map pin, from an Import result and from the
   Sites search.
6. The page adds the site through the one adoption path and then shows
   the diver's own site.
7. A record that is yours never shows the built-in page.

## Non-goals

- AI-researched records, their "not verified" mark and its rules
  (slice 3). The page shows a record's trust level nowhere in this slice.
- Built-in records on any other map (the dive map, the trip maps, the
  home page's recent sites card, the location picker).
- The 3D seascape, marine life, photos or notes on a built-in page. Those
  cards belong to a saved site.
- Built-in rows inside the Sites list, its table or its counts.
- A link from the picker's details sheet to the built-in page. A diver in
  the picker is naming a dive they have done, and the sheet already
  carries the record's facts.
- Syncing or backing up the map switches.
- Changing the 150 m rule or the 1,500 marker limit.
- Showing the catalogue's loose source tags ("drift", "sharks", "ooze").
  Only 256 records have them and they are raw untranslated words.
- Planning a dive at a built-in site without adding it.

## Anti-goals

- The Sites map opening noticeably slower, or stuttering as it moves,
  because the overlay is now on for everyone.
- A map where the diver's own sites are hard to pick out from built-in
  ones.
- A built-in page mistaken for one of the diver's own sites.
- A second site for a place the diver already has, made because the page
  offered "Add to my sites" without saying their site is there.
- A register position read as a dive guide.
- A preference that silently comes back after the diver turned it off.

## Constraints

- **No schema change.** Nothing in this slice touches the main database or
  the local cache ladder.
- **File size.** `site_map_page.dart` is 658 lines and
  `site_map_content.dart` 681; `site_detail_page.dart` is 2,535 and is not
  extended. The built-in page and its cards are new files, 800 lines at
  most each. The two maps duplicate their built-in handling today; what
  this slice adds to both goes into shared widgets, not into each file
  twice.
- **Units.** Depths and distances follow the active diver's unit settings,
  coordinates their coordinate format (`UnitFormatter`).
- **Localisation.** Every new string goes in all 11 ARB files. Every ARB
  is grouped by feature: a new key is inserted beside a neighbouring key
  of the same group.
- **Guards.** `test/architecture/` and `test/shared/` scan all of `lib/`.
  Known ones that bite here: no buttons or chips in `ListTile.trailing`;
  an indeterminate spinner hangs consumer tests that `pumpAndSettle`; a
  test that replaces process-wide state (`SharedPreferences` mock values)
  puts it back.
- **Device preferences.** The pattern is
  `viewer_fullscreen_mode_provider.dart`: a `StateNotifier` seeded
  synchronously from `SharedPreferences`, a provider that defaults to an
  unstored notifier so widget tests need no storage, and the stored one
  swapped in by `rootProviderOverrides`.
- **The map must not rebuild on a switch.** The Sites maps `listen` to the
  overlay switch and do not `watch` it, because a rebuild recreates the
  `FlutterMap` and loses the camera. The new layer state keeps that shape.
- **Reads never throw.** `SiteCatalogue` answers as an empty catalogue
  until the import finishes; the page and the overlay must be correct when
  a record or a list arrives late or not at all.
- **Offline.** The catalogue is local. The tide and reef cards fetch as
  they do on a diver's own site and show their own states without a
  connection; nothing else on the page needs the network except map tiles.
- **Demo mode.** `/sites/import` is sealed in demo mode as a file import
  route (`demo_sealed_routes.dart`, matched by prefix, so with a query
  too). The map's "Add to my sites" is open there, and so is the built-in
  page.
- **TDD**, platform-agnostic paths, `dart format .`.
- The PR description says `Part of #4514` (slice 3 is not merged), and
  carries before and after screenshots.

## Measured facts (2026-11-14)

The shipped catalogue holds 20,931 records: 3,931 dive site records and
17,000 register records.

What a dive site record carries beyond a name and a position: a
description on 427 (11%), a depth on 680 (17%), a site type on 1,171, a
website on 870, an entry method on 370, hazards on 6, a difficulty on
none. Register records: a one-line description on 13,724, a depth on
14,256, hazards on 202. Register types are `wreck` (10,474),
`artificial_reef` (5,749) or both (777).

So a page that only laid out a record's fields would be a name and a pin
for about nine dive site records in ten. That is why the page carries what
the app can work out from a position.

Records in some typical map views:

| View | Dive site records | Register records |
|---|---|---|
| World | 3,931 | 17,000 |
| British Isles | 83 | 4,495 |
| Florida | 143 | 5,188 |
| Mediterranean | 408 | 707 |
| Red Sea | 319 | 58 |
| Caribbean | 374 | 933 |
| Scapa Flow | 11 | 96 |
| Bonaire | 65 | 0 |

With dive site records alone, a view has to take in all of Europe to
reach the 1,500 marker limit: Europe holds 1,569 of them (955 between the
Alps and the North Sea), and no other continent holds 1,000. With register
records on, a view of Britain or of Florida passes the limit on register
records alone.

**Corrected during the build (2026-11-14).** This paragraph first said
that only a view wider than a continent reaches the limit. A view of the
whole of Europe does, by 69 records.

Measured during the build, on the shipped catalogue in a debug VM on a
desktop Mac: the overlay's read for a view of the whole world takes about
6 ms with dive site records only and the same with both kinds (both stop
at 1,500 rows); for a view of Britain, 0.3 ms with dive site records only
(83 rows) and about 8 ms with register records on (1,500 rows). A phone
was not measured.

Every catalogue id matches `[A-Za-z0-9_-]+`, so an id is safe as a path
segment.

A record's `source_ref` is the record's own page only for OpenStreetMap
(4,311), Wikidata (997) and the 55 curated records. The other 15,568
records share one page per source (per state for the federal reef file):
UKHO's opens the Admiralty portal's item list, AWOIS's is a KML file on
the Internet Archive, and for `fwc` and `njdep` it is the same address as
the licence link.

The water type is `fresh` on 308 records and absent on every other; no
record says salt.

Four sources (`njdep`, `hi_dar`, `tpwd`, `nc_dmf`) carry an `own_terms`
sentence in the file's metadata. The app does not read it:
`CatalogueSource` has no field for it and the parser drops it. Their
licence names already say the condition ("Non-commercial use, with
credit"), and the licences page carries each publisher's full text.

## Approaches considered

For the record's page:

| | A. Grow the card | B. A page of its own | C. The diver's site page in a preview mode |
|---|---|---|---|
| How | `BuiltInSiteInfoCard` and its sheet gain a small map, coordinates, the kind and the licence. No route. | A new read-only page at its own route, built from new small cards and the two existing cards that need only a position. | `SiteDetailPage` renders a record mapped to an unsaved `DiveSite` with a read-only switch. |
| For | Smallest; no new screen. | Linkable; room for tides, reef and nearby; no existing page changes behaviour. | Full parity, including the seascape and the diver's section order. |
| Against | Nothing can link to a record; no room for tides or reef; a sheet is a poor place to read. | A new page to build and translate. | That page is 2,535 lines and most of its cards read a saved site by id (types, media, tags, features, statistics); the switch would thread through all of them. |

**Chosen: B**, by the maintainer.

For the map default:

| | A. Flip the one switch | B. Dive sites on, registers a second switch | C. Both on, registers only when zoomed in |
|---|---|---|---|
| For | One line of behaviour. | The default map stays readable where registers are dense; matches the picker. | No second switch. |
| Against | Britain and Florida sit at the marker limit on every open, and the diver's sites are lost among wreck clusters. | A two-line menu in place of a button. | A wreck diver's wide view looks empty until they zoom, and needs a note to say why. |

**Chosen: B**, by the maintainer.

## Design

### 1. Map layers and their memory

- Two layers: **built-in dive sites**, on by default, and **charted wrecks
  and reefs**, off by default.
- Their state is one value with two booleans, held by a notifier stored in
  `SharedPreferences` under two keys and seeded synchronously at start,
  following `ViewerFullscreenModeNotifier`. The provider defaults to an
  unstored notifier holding the defaults; `rootProviderOverrides` swaps in
  the stored one.
- A missing key reads as the default. Only a change the diver makes is
  written, so a later change of default still reaches devices where the
  diver never touched the switch.
- `showBuiltInSitesProvider` is removed. Everything that read it (the
  bounds reporter, the caption, both maps) reads the new state: "the
  overlay is on" becomes "either layer is on".
- Not per diver: a device with two profiles shares the choice. It is a
  property of the screen, as the fullscreen mode is.

### 2. Reading the catalogue for the layers

- `SiteCatalogue.inBounds` gains the kinds to return (a set of
  `CatalogueKind`). With both it behaves as today: dive site records
  first, then register records, each nearest the middle. With one, it
  reads only that kind, and `truncated` speaks of that kind alone. With
  none it reads nothing and returns an empty, untruncated result.
- The overlay's provider passes the layers that are on, inside its
  existing re-read loop, so the marker limit stays a limit of markers
  drawn after the diver's own are left out.
- With both layers off the bounds reporter reports nothing and the
  catalogue is not read, as with the overlay off today.
- The 1,500 limit, the 150 m rule and the link rule are unchanged.

### 3. The layer control

- The globe button on both maps (`BuiltInSitesToggleButton`) becomes a
  button that opens a menu of two checkable rows, each with its glyph:

  ```
  [o]  Built-in dive sites             (tick)
  [a]  Charted wrecks and reefs
  ```

- The menu stays open while rows are ticked, so both can be changed in one
  visit. The button shows its "on" colour and icon when either layer is
  on. Its tooltip and semantics say "Built-in sites on the map".
- Turning off the layer a selected pin belongs to clears that selection,
  so a card cannot outlive its pin.

### 4. Pins

- A dive site record keeps today's hollow grey pin.
- A register record gets its own glyph in the same grey and the same size:
  an anchor. Selected, either takes the primary colour and grows, as
  today.
- Both kinds stay in the one built-in cluster layer beneath the diver's
  own, so a cluster's number counts both.
- A pin's semantics label names its kind: "Built-in dive site: <name>" or
  "Charted wreck or reef: <name>".
- The diver's own markers are unchanged.

### 5. First view and the empty state

- The map opens as today: framed on the diver's sites, or on the default
  ocean view when they have none.
- The "No sites with locations" card that covers the map for a diver with
  no located sites is shown only when both layers are off. With a layer
  on, that diver sees built-in pins, which is the point of the default.
- The zoom-in caption is unchanged and still shows only when the view
  holds more than it marks.

### 6. The card on the map gains "Details"

- `BuiltInSiteInfoCard` gains an optional details action. Where it is
  given, the card shows a "Details" text button that opens the built-in
  page for the record. Both maps give it. The picker's sheet does not.
- "Add to my sites" stays on the card, unchanged.
- A map's selection is cleared once its record is the diver's, however
  that came about. Today only the map's own add clears it, and the card
  falls back to reading the record by id, so a site added from the page
  would leave its card on the map, still offering "Add to my sites".

### 7. The built-in page

Route: `/sites/catalogue/:catalogueId`, declared before `/sites/:siteId`.
It is always opened by a push, so back returns to the map, the Import
results or wherever it came from.

```
 <  Blockship Tabarka                    [+ Add]
+----------------------------------------------+
|  map strip, locked, with the depth overlay   |
|               (the record's glyph)      [[]] |
+----------------------------------------------+
 Blockship Tabarka
 Scapa Flow, Orkney, Scotland, United Kingdom
 Charted wreck · Not in your sites
 Your site "Tabarka" is 40 m from here   >

 ABOUT      wreck · boat · 12 to 18 m
            (description)
 HAZARDS    (only when the record has any)
 LOCATION   country, region, city, island, sea,
            coordinates (tap to copy)
 TIDES      as on the diver's own site
 REEF       as on the diver's own site
 NEARBY     YOUR SITES
              Churchill Barriers   3 dives   1.2 km
            BUILT-IN SITES
              [o] Inganess Bay               0.8 km
              [a] SMS Karlsruhe              2.1 km
 SOURCE     UK Hydrographic Office Wrecks and Obstructions
            Credit: UK Hydrographic Office
            Licence: OGL-UK-3.0   >
            Source · Website
            A charted position, not a dive guide. Not for
            navigation.

 [ Add to my sites ]
```

Top to bottom:

- **App bar.** The record's name, and an "Add to my sites" action.
- **Map strip.** The locked 200-high preview the diver's own site page
  has (locked for the reason given in issue #3156), with the bathymetry
  depth overlay and the record's own glyph at its position. A fullscreen
  button opens an interactive map of the same position with the same
  glyph, the depth overlay and the map style control. A record without
  coordinates has no strip.
- **Header.** The name; the place line (`catalogueLocationLine`); and a
  line that says what this is: "Built-in dive site", "Charted wreck" (a
  register record typed `wreck`) or "Charted reef" (any other register
  record), followed by "Not in your sites".
- **Your site here.** When one of the diver's unlinked sites lies within
  150 m, a line names the nearest and its distance and opens that site's
  page. This is the record the map hides, reached by name.
- **About.** Chips for types, entry methods, depth range and, for a
  fresh-water record, the water type, then the description. The card is
  absent when the record has none of them.
- **Hazards.** As on the card today, only when the record has any.
- **Location.** Country, region, city, island, sea and coordinates, each
  row only when the record has it. Coordinates copy on tap, as on the
  diver's own page. The sea is named in the diver's place-name language,
  as the adopted site's would be (`catalogueSeaInDiversLanguage`); the
  other place names are the catalogue's.
- **Tides.** `TideSection` for the position, unless the record's water
  type is fresh. Absent without coordinates.
- **Reef.** `ReefSection` for the position and water type. Absent without
  coordinates.
- **Nearby.** Two short lists, each absent when empty, the card absent
  when both are:
  - *Your sites*: the diver's sites within 10 km, nearest first, at most
    5, each with its dive count and distance, opening the diver's site
    page.
  - *Built-in sites*: records within 10 km other than this one and other
    than the diver's own, at most 6: dive site records first, then
    register records, each nearest first, with glyph and distance,
    opening that record's built-in page. The same two hiding rules as the
    map apply.
- **Source.** The source's full name, its credit (the text the card
  shows today), its licence by name, linked to the licence's own page
  when the source has one, a "Source" link and a "Website" link to the
  record's website. Links open only as http or https addresses, through
  `catalogueWebsiteUri`. A register record adds one sentence: a charted
  position, not a dive guide, and not for navigation.
  - The "Source" link opens `sourceRef`: the record's own page for
    OpenStreetMap, Wikidata and curated records, the dataset's page for
    the rest. It is left out when it is the same address as the licence
    link, and when it points at a file to download and not a page (its
    path ends in a data file extension such as `.kml`).
  - The page shows no more of a source's terms than its licence name. An
    own-terms source's full text stays on the licences page, as slice 2
    left it.
- **Add to my sites**, repeated as a full-width button at the foot of the
  page.

Sections are in this fixed order. The page has no section settings: it is
not one of the diver's pages to arrange.

**Wide windows.** The same page, with its scrolling content centred and
held to a maximum width (720 logical pixels). It never moves itself into
the Sites split pane.

**States.**

- *Loading*: the record is read by id; the page shows its app bar and a
  progress indicator until it arrives.
- *Not found*: an id the catalogue does not hold (a record a later
  catalogue dropped, or a catalogue not imported yet) shows "This
  built-in site is no longer available" with no action.
- *Yours*: when the record is the diver's, the page replaces itself with
  that site's page (`/sites/<id>`). The check uses the diver's sites as
  the rest of the feature does (`linkedCatalogueIds`, so a record a merge
  folded into a site counts). It runs when the page opens and again
  whenever the diver's sites change, so a site adopted elsewhere while
  the page is open also moves it on.

### 8. Adding from the page

- "Add to my sites" goes through `adoptCatalogueSite`, the one adoption
  path, with the diver's "after create" rules captured before the write
  and run only when `CatalogueAdoption.created` is true, as the map does.
- While it runs both buttons are disabled.
- On success the diver's sites are refreshed, a short message says the
  site was added, and the page is replaced by the new site's page. The
  refresh also trips the "Yours" rule of section 7; the page is replaced
  once, whichever of the two gets there first.
- On failure the page stays and says the site could not be added, with
  the map's existing wording.

### 9. Finding a record by name

- **Import results open the page.** Tapping an Import result opens the
  built-in page in place of the details sheet. A result that is already
  the diver's opens their own site page. The result's Import button and
  its "Already Imported" mark are unchanged.
- **The Import page takes a search to start with.** `/sites/import?q=` runs
  that search on entry and shows the text in the field.
- **One row in the Sites search.** `EntitySearchHeader` already shows
  "Search everything for ..." under a focused field with text in it. The
  Sites list adds a second row beneath it, "Search built-in sites for
  ...", which opens the Import page with the typed text. It shows only
  when the text is plain words: the field's text parses, and parses to
  text alone with no field condition, which the catalogue search would
  not understand. Text that does not parse yet ("depth>" half typed)
  shows no row. The header gains a slot for such a row; no other list
  uses it.
- **Demo mode.** The row is not shown in demo mode, where the Import page
  is sealed.
- The picker's sheet and its rows are unchanged.

### 10. Documentation

`docs/user/dive-sites.md`: the map section describes the two layers, their
defaults and that the choice is kept on the device; a new short section
describes the built-in page and how to reach it; the Import section says
a result opens the page; the Sites search row is mentioned where list
search is described.

## Calls the designer made

The maintainer decided everything under "What was decided". The rest is
the designer's call. The ones most worth checking:

- The anchor as the register glyph, and one glyph for wrecks and reefs
  alike.
- Both kinds share one cluster layer.
- A missing preference reads as the default and only a diver's own change
  is written.
- The switches are per device, not per diver profile on the device.
- The "No sites with locations" card gives way to built-in pins.
- The line under the name, and "Charted reef" for every register record
  that is not typed a wreck.
- "Your site is here" on the page, with "Add to my sites" still offered.
- Nearby: 10 km, 5 of the diver's sites and 6 records, dive site records
  before register records.
- The fullscreen map from the strip shows the one position; it is not the
  Sites map.
- The page's content width on a wide window.
- The Sites search row shows for plain words only.
- The page re-checks whether the record is the diver's whenever their
  sites change.
- The loose source tags are left off the page although the Import result
  card lists them.
- The "Source" link's label and the two cases where it is left out.
- The page shows a source's name, credit and licence name, and leaves an
  own-terms source's full text on the licences page.
- The sea is shown in the diver's place-name language.
- A map's selection is cleared when its record becomes the diver's.
- The Sites search row is hidden in demo mode, not the Import page
  unsealed.

## Known gaps after the build

- A dive site record with nothing but a name and a position still shows
  little that is specific to it: a map, tides, reef and neighbours. Slice
  3's researched details are what fill the About card.
- The switches do not follow the diver to another device.
- The Sites search row is not offered for a query with a field condition,
  even one the catalogue could answer ("country:egypt").
- From an Import result there is no way to see the record among its
  neighbours on the Sites map; the page's fullscreen map shows the
  position alone.
- A diver who has turned register records on sees them at the marker
  limit around Britain and Florida, as today.
- The picker's sheet shows less than the page and does not link to it.
- In demo mode a built-in page is reached from the map only: the Import
  page is sealed there.
- For three records in four the "Source" link opens the dataset's page,
  not the record.

## Left to the builder

- File, class and provider names; the preference keys; the route's exact
  spelling.
- The menu widget for the layer control, within the guards, and how it
  stays open while rows are ticked.
- The exact anchor icon and how the selected state is drawn.
- How the nearby lists are read (one `near` read ordered in Dart, or one
  per kind) and how the diver's own nearby sites are found.
- How the page is composed so no file passes 800 lines, and what is
  shared with `BuiltInSiteInfoCard` (the chips, the hazards row).
- How the page's replace-with-own-site step avoids a visible flash of the
  built-in page when the record is already the diver's.
- The strings and their keys in all 11 ARB files.
- Where in `EntitySearchHeader` the row slot sits, and its key for tests.
- Timing the overlay's read on the shipped catalogue (the world view with
  dive site records only) and recording the figure in the PR. If it is
  not comfortably inside one frame's work off the UI thread, say so
  before changing any limit.

## Rulings made during the build

Where the build settled something this record left open, or does
something other than what the text above says. The text above is the
design as approved; these are the corrections to read with it.

- **Coordinates are copied by a button or a long press, not a tap.**
  Section 7's sketch and its Location paragraph say "tap to copy". The
  page uses the shared copyable detail row (`DetailRow.text(copyable:)`),
  the row the dive, equipment and certification pages copy from, and
  that row copies from its copy button or a long press anywhere on it.
  The diver's own site page still copies its coordinates its own way.
- **The Tides card is also left out where the position has no tide
  data.** The design leaves it out for a record typed fresh water only.
  Only 308 of 20,931 records carry a water type, so an inland lake or
  quarry with none would show a card saying nothing but that there is no
  tide data. The page asks `hasTideDataProvider` for the position and
  leaves the card out on a "no", under the same rule as every other card
  with nothing to show. The card holds its place while that is being
  found out. The build made this call and the maintainer confirmed it
  on 2026-11-15.
- **The page replaces itself only while it is the page on top.** The
  router replaces whichever page is on top, so a built-in page with a
  sheet, a dialog or another page over it waits, and hands over to the
  diver's own site page when it is on top again.
- **A record the catalogue does not hold is "not found" only once the
  bundled catalogue has finished importing.** Until then the page shows
  the loading state (`siteCatalogueImportingProvider`): on a first launch
  the record may only not be there yet.
- **A record's id is encoded in the page's path.**
  `catalogueSitePath` percent-encodes the id, so an id with a `/`, `?` or
  `#` in it still names one route segment.
- **One adoption flow for the page and both maps.**
  `adoptBuiltInSite` holds the steps (adopt, refresh the diver's sites,
  say "Added to your sites", run the "after create" rules when a site
  was created, report a failure). The confirmation is shown through the
  app's messenger, so it still appears when the diver has left the page
  before the add finishes.
- **An Import result that is the diver's opens their site directly.**
  A result that was adopted, or that a merge folded into one of the
  diver's sites (`catalogueOwnerSiteId`), pushes `/sites/<id>` instead of
  going through the built-in page and its redirect.
- **A map's card is cleared when its record stops being offered.** That
  is the link rule and the 150 m rule together
  (`offerableCatalogueSites` with `byPosition`), not the link rule
  alone: a site the diver creates on the record's spot hides the pin,
  and the card goes with it. The card also goes when a new catalogue no
  longer holds its record. A record that is only out of view, or still
  being read, keeps its card.
- **The strip is drawn at zoom 12**, with the map locked; the fullscreen
  map from its corner button is the one that moves.
- **Nearby is read once per kind**, 60 records each (ten times the six
  shown), so a coast crowded with register records cannot push the dive
  site records out of the list.
- **Layer choices are stored in the order they were made.** The writes
  are sent one after another and a failed write is logged, not thrown: a
  layer ticked and unticked quickly cannot have its older value stored
  last.
- **The layer provider is `builtInMapLayersNotifierProvider`**, after
  the project's naming rule for mutable state.
- **The Sites search row reads the typed text each time it is drawn.**
  Whether the text is plain words is worked out from the text itself,
  not kept in a second piece of state that an outside change to the
  query could leave stale.
- **The map card's bottom row is an `OverflowBar`**: links at the start
  and the actions at the end, falling to end-aligned lines on a narrow
  phone.
- **Two strings were retired**: `diveSites_import_detail_alreadyImported`
  and `diveSites_import_detail_importToMySites` belonged to the Import
  page's details sheet, which the built-in page replaced.

## Acceptance

The scenarios use a fixture catalogue with dive site and register records.

1. **Default.** On a fresh install the Sites map shows built-in dive site
   pins and no register pins, on a phone and in the split pane. A diver
   with no sites sees pins, not the "No sites with locations" card.
2. **Second layer.** Turning on "Charted wrecks and reefs" adds anchor
   pins. Turning off "Built-in dive sites" leaves only the anchors.
3. **Memory.** With dive sites off and wrecks on, the app is restarted:
   the map opens with the same two choices. A device where the diver
   never touched the menu keeps the defaults.
4. **Both off.** No built-in pins, no caption, and the catalogue is not
   read as the map moves.
5. **Selection.** A selected register pin's card disappears when the
   register layer is turned off.
6. **Card to page.** Tapping a pin shows the card; "Details" opens the
   built-in page for that record; back returns to the map with the pin
   still selected.
7. **Page contents.** A record with full details shows the strip, the
   header with "Built-in dive site · Not in your sites", About, Hazards,
   Location with coordinates in the diver's format, Tides, Reef, Nearby
   and Source with name, credit, licence and both links. Depths and distances are in
   the diver's units.
8. **Thin record.** A record with only a name and a position shows the
   strip, the header, Location, Tides, Reef and Source, and no empty
   cards.
9. **Fresh water.** A record typed fresh water shows no Tides card.
10. **Register record.** Its line reads "Charted wreck", its glyph is the
    anchor on the strip and in Nearby rows, and Source carries the "not a
    dive guide" sentence.
11. **Add.** "Add to my sites" creates the site once (a second tap while
    it runs does nothing), runs the diver's "after create" rules, and
    shows the diver's own site page; back does not return to the built-in
    page. Back on the map the pin and its card are gone.
12. **Yours.** Opening the route for a record the diver has adopted shows
    their own site page. So does a record a merge folded into one of
    their sites.
13. **Your site here.** A record 40 m from the diver's unlinked "Tabarka"
    shows the line naming it and its distance; tapping opens "Tabarka".
14. **Not found.** An unknown id shows the "no longer available" state.
    A record whose `sourceRef` equals its licence address, or ends in
    `.kml`, shows no "Source" link.
15. **Nearby.** The diver's sites within 10 km are listed nearest first
    with dive counts; built-in records list dive site records before
    register records; a row opens the right kind of page; this record and
    the diver's own are not among them.
16. **Import.** Tapping an Import result opens the built-in page; a result
    marked "Already Imported" opens the diver's site page.
17. **Sites search.** Typing "thistlegorm" in the Sites search shows
    "Search built-in sites for thistlegorm" under "Search everything";
    tapping it opens the Import page with the results for that text.
    Typing "depth>20" or a half-typed "depth>" shows no such row, and
    demo mode shows none.
18. **Wide window.** At 1,400 px the page's content is centred and no
    wider than its maximum.
19. **Picker.** The picker and its details sheet behave exactly as
    before.

## Testing

Tests first. At least:

- The layer state: defaults with nothing stored; each stored combination
  read back; a change written under the right key; nothing written at
  start; the unstored notifier for tests.
- `inBounds` by kind over a real local cache database: one kind, both,
  none; `truncated` per kind; the order unchanged with both.
- The overlay provider: passes the layers; reads nothing with both off;
  the marker limit still applied after the diver's own are left out, for
  one kind and for both.
- The marker layer: glyph by kind; semantics label by kind; selection.
- The layer control: two rows, ticks follow the state, the menu stays
  open, the button's on state.
- Both maps: default pins; the empty card's condition; the card's
  Details action pushes the route; selection cleared when its layer goes
  off.
- The page: every card present and absent as acceptance 7 to 10 say;
  units and coordinate format; the three states; the redirect for a
  linked record and for an `also` id, at open and when the sites change;
  the "your site here" line; Nearby's lists, order, limits and targets;
  links refused when not http or https; the content width at a wide size.
- Adding from the page: one adoption for two taps; rules run only when
  created; replaced by the site page; the failure message.
- The Import page: a result opens the page; an imported one opens the
  site; the `q` parameter runs the search.
- The search header: the row's condition (focused, plain words), its
  target, and that the other lists show no such row.
- The route: declared so `/sites/catalogue/x` is not read as a site id.
- `test/architecture/` and `test/shared/` after adding files.
