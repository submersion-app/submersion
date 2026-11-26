# Species section revamp

Date: 2026-11-25. Release: v1.8.7. One PR.

## Intent

The Species section (`/species` and a species' own page) is a plain text list
today. Eric wants to browse the species he has seen, see cropped photos of
each animal taken from his own media, open that media, and see on a map where
he saw them, and he wants new ways to look at and play with the data. The
models are iNaturalist's life list grid (photo tiles) and Merlin's bird page
(big photo, range map, seasonality bar).

Success: opening Species feels like opening a field guide of your own dives,
for a diver with 3 species and no photos as much as for one with 600 species
and thousands of photos.

## Goals

1. A photo-first life list with a header, rarity badges and grouping.
2. A Merlin-style species page with a sharp hero, a crop strip that opens the
   media, the map, depth and season charts and a sightings timeline.
3. Choose a cover crop per species.
4. A nudge toward species with no photo.
5. ID practice from your own crops that remembers what you miss.

## Non-goals

- Changing how species are identified, tagged or reviewed (species_id).
- Changing the species map page itself, the catalog manager, or the query
  language.
- Storing bigger crops or any copy of an original photo (media stays links
  only; the 320 px identification crops are the existing, narrow exception).
- Public data (GBIF) on the list or the species page; it stays on the full
  map behind its existing toggle.

## Anti-goals

- A page that only looks good with photos. Every surface has a designed
  no-crop and no-photo state.
- Freezing built-in species: nothing in this work writes to the `species`
  row (see Covers).
- Charts that lie: depth must say what it measures, and no chart invents
  precision from one or two dives.

## Constraints and facts found

- `SeenSpecies` holds only species with at least one sighting, from one
  `GROUP BY` in `SeenSpeciesRepository.getSeenSpecies`, scoped to the current
  diver and `DiveStatsScope`.
- Identification crops (`IdentificationCropStore`, `IdentificationCrop`
  widget) are JPEGs at most 320 px on the longer side (`cropThumbnailSize` in
  the pack manifest). Crops of named identifications sync since #4876.
- `MediaIdentification.box` is normalised 0 to 1 against the analysed image
  after orientation; video identifications carry `bestMs`.
- Hand-applied tags (`media_species`) have no box: the `bbox*` columns are
  reserved and never filled.
- `MediaItem.depthMeters` is the depth at capture, matched from the profile.
- The catalog upgrade treats a built-in species row with a non-null `hlc` as
  edited and stops updating it (`SpeciesRepository._seedRows`). Species rows
  have no `diver_id`; they are shared by every diver in the logbook.
- `MediaViewerPage(mediaList, initialMediaId)` has no start position for a
  video.
- The species page edits in place (#4527); that must keep working.
- Species is a top-level nav destination that pushes the species page (no
  master-detail); that stays.

## Approaches considered

| | Approach | Trade-off |
| --- | --- | --- |
| A | Stored 320 px crops everywhere | Simplest, works on every synced device and the web; the hero is soft |
| B (chosen) | Stored crops for cards, strip and practice; the hero shows the original photo zoomed to the identification box, falling back to the stored crop | Sharp where it is biggest; one extra widget maps a box onto the full image |
| C | Store larger (about 1024 px) crops | Sharp everywhere, but doubles storage, needs a backfill job, and stretches "links only". Dropped |

Eric chose B. Delivery: the new pages replace today's in place, with no
settings switch (my call: this is read-mostly UI; the editing switch in #4757
guarded writes).

## Which picture belongs to a species

A **crop** belongs to species S when an identification on a media item is
`accepted` with `decidedSpeciesId == S` and a `media_species` tag for (that
media, S) exists, confirmed or not. Dismissing the tag removes the crop from
the species. Video identifications count; their crop is the `bestMs` frame.

A **tagged photo without a crop** (a hand tag, or a photo never analysed) is
shown as the photo's thumbnail, centre-cropped.

The **best crop** (my call): the identification with the largest shorter box
side, `min(box_pixel_width, box_pixel_height)` worked out in SQL
(`boxShorterSide` is a getter, not a column), newest media on a tie. The
**cover** overrides it.

**One crop per photo** (my call): `reconcileDecisions` accepts every animal
whose best name is the tagged species, so a school of 20 fish gives 20 accepted
crops on one photo. Wherever crops are listed or counted, a media item
contributes one crop per species: its largest box. The cover may still name any
identification on that media.

**Scope** (my call): pictures follow the media library's rule, as the species
page's Photos section does today (`m.dive_id IS NULL OR d.diver_id = ?`): card
images, the hero, the strip and covers. Everything that counts or selects
species follows the life list's rule (the diver's dives under
`DiveStatsScope`): the header figures, the "<n> without a photo" count (life
list species with no picture by the library rule), and the practice pool
(life list species that have a confirmed-tag crop). Depth dots use tagged
media on dives inside the life list's scope.

Order of preference everywhere a single image stands for a species: cover,
best crop, newest tagged photo, category tile (category colour and icon, as
`colorForSpeciesCategory` and `iconForSpeciesCategory` give today).

## 1. The list page (`/species`)

Top to bottom:

1. The review banner and the model download prompt, unchanged.
2. **Life list header**: species total, "New in <year>" (first seen this
   calendar year), and a growth line of cumulative species by first-seen date.
3. **Controls row** (revised after review): the count line, a compact
   "<n> without a photo" chip when n > 0 or its filter is on (the no-photo
   nudge, part 1), the sort menu, the **Group by** control (None, Category,
   First seen, Trip, Site; **Category by default**) and the grid or list
   switch. A category chosen from See all shows under it as a chip that
   clears it.
4. The cards.

The app bar holds search (`EntitySearchAction`: the search row opens from
its icon and closes when empty, as on every other list), the query filter
(`QueryFilterAction`, `QueryChipsFrame`), Practice (see 4), the species map,
and a menu with Manage catalog. There is no row of category chips: the
Category shelves and the filter cover it.

**Cards** (a grid): the image fills the card; below it the localized name, the
dive count, and at most one rarity badge. 2 columns on a phone, growing to 5
or 6 on desktop (builder picks breakpoints from the app's existing grid
conventions). A **compact list** toggle shows today's `SeenSpeciesTile` rows
instead, for dense scanning; grouping still applies to it.

**Rarity badges** (my calls, one per card, first match wins):

| Badge | Rule |
| --- | --- |
| New | first seen within the last 90 days |
| Seen once | exactly one dive |
| Not seen lately | last seen more than 2 years ago |
| Mastered | practice box 5 (see 4), shown only when none of the above applies |

**Grouping layouts** (Eric chose the mix):

- **Category**: shelves. One horizontally scrolling row per category in
  `SpeciesCategory` order, header "<Category> · <count>" with "See all", which
  shows that category as one flat grid for the visit, without changing the
  saved grouping.
- **First seen**: stacked sections, one per year, newest first, sticky and
  collapsible headers. Each species appears once.
- **Trip**: stacked sections, one per trip that has a sighting, newest trip
  first, then "No trip". A species appears under every trip it was seen on.
  The card keeps its whole-log figures; a small "First seen here" marker shows
  when the species' first sighting was on that trip.
- **Site**: as Trip, per site, sections ordered by most species, then name;
  then "No site".

The sort applies inside every group. Group by and the grid/list toggle are
remembered per device in local preferences (not synced).

The header (my call) always describes the whole life list: search, category
and query filters change the cards, not the header's figures, because it is
"your life list", not "these results". The filtered count stays visible as
today's count line above the cards.

Empty and edge states: no species keeps today's empty state; a query or
filter that hides everything keeps `QueryNoMatchState`; a header with zero
"new this year" still shows the zero.

## 2. The species page (`/species/:id`)

Top to bottom, Merlin style. On desktop widths it becomes two columns: hero,
strip, facts and description on the left; map, charts and sightings on the
right.

1. **Hero**: the picture by the order of preference above, large, with the
   name, scientific name and category over a legibility fade. When the
   picture is a crop and the original media is a photo the device can read,
   the hero shows the original zoomed to the box (approach B), with a little
   margin around the box; otherwise the stored crop. "Can read" (my call)
   means whatever `MediaItemView` can load at a hero-sized target (longer side
   bounded at about 1600 px), for every source kind, so a remote album
   delivers a sized rendition, not the full original; any load failure falls
   back to the stored crop. A species with no
   picture gets the category tile and, when the dives it was logged on have
   any photos, a **Find photos** button that opens the existing
   `SpeciesTagPickerPage` (the no-photo nudge, part 2). The button is hidden
   when those dives have no photos.
2. **Crop strip**: every crop of the species, cover first, then newest first,
   then the tagged photos without a crop. Lazily built (a species can have
   hundreds). Tap opens `MediaViewerPage` on that media within the species'
   media; a video starts at the identification's `bestMs` (the viewer gains an
   optional start position). Long-press (and a context menu on desktop) offers
   "Use as cover" / "Remove cover".
3. **Facts row**: dives, sites, first seen, last seen, and the rarity badge.
   Replaces today's statistics cards; dates through the unit formatter.
4. **Description**, as today, editable in place.
5. **Where seen**: today's `SpeciesWhereSeenSection` (locked map, top sites,
   open the full species map), moved up to here.
6. **Depth and season**:
   - Depth: a vertical band. Dots are photo capture depths
     (`MediaItem.depthMeters`) of this species' tagged media. Where the
     species has no photo depths, the band shows the range of dive maximum
     depths, labelled "Dive max depth". In the diver's depth unit.
   - Season: a 12-month bar of the number of dives that saw the species each
     calendar month, across all years (Eric chose raw counts over an
     encounter rate).
7. **Sightings**: a timeline with a dot per dive across the years (tap opens
   the dive), above today's `SpeciesSightingsSection` list.
8. **Photos**: today's `SpeciesPhotosSection` (justified full-frame rows),
   unchanged.

In-place editing (#4527) keeps working: the header and description cards stay
framed for editing; the new sections are calculated (read-only) like today's
statistics.

## 3. Covers

A new synced table, keyed by (diver, species): the media id, and the
identification id when the cover is a crop. Not a column on `species`,
because writing to a built-in row stamps its `hlc` and freezes its catalog
text forever. Per diver because species are shared and photos are not.

A cover whose media, identification or tag goes away is ignored (the page
falls back to the best crop) and is cleared when next written. It takes part
in sync like other diver-owned rows (HLC, serializer arm, deletes and
tombstones), in the change log as the diver's edit, and goes with the diver
when the diver is deleted. Its row id is derived from (diver, species), so two
devices choosing a cover offline converge on one row instead of creating
twins.

Export (my call): covers and practice memory are app state, not dive data, so
UDDF and CSV exports leave them out; the `.db` backup and sync carry them. Any
repo guard that classifies tables for export or agent access gets them listed
as deliberately excluded.

## 4. ID practice (`/species/practice`)

- Entry: the "Practice" action on the list page. Offered when the diver has 4
  or more species with at least one confirmed-tag crop; otherwise the action
  explains what is needed.
- Pool: those species. Only crops whose tag is confirmed, so practice never
  teaches an unreviewed guess.
- A session is 10 rounds (fewer if the pool is smaller). Each round shows one
  crop and four names: the answer and three distractors, from the same
  category where it has enough species, else any. A switch chooses common or
  scientific names.
- After an answer: right or wrong, the correct name, and Next.
- Summary: the score, and the missed species, each opening its page.
- **Memory** (Eric chose to remember results): a second synced table keyed
  by (diver, species) holding a Leitner box 1 to 5, the next due date, and
  right and wrong counts. A right answer moves the species up a box and sets
  the next due date 1, 3, 7 or 21 days ahead (box 2 to 5); a miss sends it to
  box 1, due now. A session takes due species first, lowest box first, then
  species never practised, then the rest at random. Box 5 is "Mastered" on
  the card. Same sync, change log and diver-delete treatment as covers.
- **Sync** (Eric chose last write wins over an append-only answer log): one
  row per (diver, species), id derived from the pair. Practising the same
  species on two devices between syncs keeps the later write and loses the
  other device's box move and counts; accepted as rare.
- Each round uses one crop of the species, chosen at random among its
  confirmed-tag crops (one per photo), so repeated sessions show different
  shots.

## Range to check before calling it done

- 0, 1, 3 and 600 seen species; a species with 0, 1 and 500 crops.
- A diver with no identification model (no crops at all, only tagged photos
  or none).
- Long localized names, long scientific names, and RTL.
- Phone and desktop width, light and dark.
- A synced device that has the crops but not the original media (hero falls
  back to the crop).
- Trip and Site grouping with dives that have no trip or no site.

## Left to the builder

- Grid breakpoints and card aspect ratio.
- Query shapes, provided the list stays one round of queries for 600 species
  (no per-card query) and the crop strip loads lazily.
- File and widget split within the 800-line cap; `species_page.dart` and
  `species_detail_page.dart` will need new part files or widgets.
- Chart drawing (the app's existing chart approach).
- Localized strings in every ARB file the repo maintains.

## Calls I made (Eric to check)

- Best crop is the largest box; New = 90 days; Not seen lately = 2 years.
- Trip and Site groups list a species under each place, with whole-log card
  figures and a "First seen here" marker.
- Group by and the view toggle are per-device preferences, not synced.
- Practice uses confirmed-tag crops only; 10 rounds; Leitner steps 1, 3, 7,
  21 days.
- No settings switch; the new pages replace the old.
- One crop per photo per species (the largest box).
- Pictures follow the media library's scope; counts, the no-photo count and
  the practice pool follow the life list's scope.
- The hero loads a sized rendition (about 1600 px) from any source kind,
  falling back to the stored crop.
- The header always describes the whole life list, not the filtered set.
- Covers and practice memory are left out of UDDF and CSV exports.
