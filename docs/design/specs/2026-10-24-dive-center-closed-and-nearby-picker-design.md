# Permanently closed dive centers and a nearby-first picker

Issue: #3379 (Add "permanently closed" attribute to dive center)

## Why

Divers collect dive centers over years. Two things go wrong as the list grows.

1. Some centers go out of business. The diver still wants them in the log
   (old dives, trips and statistics point at them, and imports from other
   logbooks bring them in), but the dive center list is also where a diver
   looks for somewhere to get a fill or service on a future trip, so a closed
   center needs to be marked as closed. The reporter asked for a "permanently
   closed" attribute, visible in the list, in the spirit of equipment's
   sold and lost states.
2. A diver with twenty centers in different countries scrolls through all of
   them to find this week's center when logging a dive. A commenter asked for
   an "inactive" state that the diver switches on and off per trip.

The maintainer chose to solve the second problem without any manual switching:
the picker works out which centers are relevant by itself, from where the dive
was. The moment that matters most is choosing a center while logging a dive.

## Goals

- A dive center can be marked **Permanently closed** with a plain on/off
  switch. Nothing is deleted and no history changes.
- Closed centers are visibly marked in the dive center list, on the detail
  page, on the map and in the picker.
- When logging a dive, the dive center picker lists the centers near the
  dive's site first, nearest at the top, with their distance.

## Non-goals

- No "inactive" or per-trip state, and no manual on/off for picker
  visibility. Relevance comes from distance.
- No closure date, reason or other detail. A plain switch is enough.
- No new filter or "hide closed" toggle on the dive center list. Closed
  centers keep their normal sort position.
- No change to dive pages, trip pages or statistics. A past dive whose center
  later closed looks the same as before.
- No search box in the picker.

## Anti-goals

- Hiding a closed center so completely that an old dive cannot be given it.
  It must always remain selectable.
- Any migration or backfill that changes existing centers. Every existing
  center starts as open, and only the diver flips the switch.

## Design

### Data

- New column on `dive_centers`: `is_permanently_closed`, boolean, not null,
  default false. Added through a schema rung in the migration ladder
  (`lib/core/database/migrations/`), never in `database.dart`. The default
  applies to existing rows; nothing rewrites them.
- `DiveCenter` gains `isPermanentlyClosed` (default false) in the constructor,
  `copyWith` and `props`. The repository reads and writes it.
- The column syncs like every other dive center field. It is registered in the
  sync conflict field catalogue (`site_trip_fields.dart`, where the other dive
  center fields such as fill hours live) so a conflict on it is offered to the
  diver.
- Backup and export paths that already carry dive center fields carry this one
  too. Any format with no place for it (for example UDDF, if it has none) is
  left alone.

### Edit page

A **Permanently closed** switch on the dive center edit page, with a one-line
helper such as "Still kept for past dives; left out of nearby centers in the
picker." Placement in the form is the builder's call.

### Dive center list

Closed centers show a **Closed** tag next to the name and the row is greyed
out, in every list view mode (detailed, compact and table, plus the dense tile
fallback). In table mode (`EntityTableView`) the row is greyed and the tag sits
in the name cell; there is no separate "Closed" column (designer's call).
Sorting and filtering are unchanged.

### Detail page

A short "Permanently closed" note near the top of the detail page.

### Map page

Closed centers still appear on the dive center map, drawn faded.

### Picker

The picker (`DiveCenterPickerSheet`) used by the dive edit page:

- Receives a reference point for the dive, chosen in this order (decided by
  the maintainer): the selected site's coordinates; else the dive's entry GPS;
  else its exit GPS. These are the same sources the dive edit page already
  gathers in `_currentDivePoints()` for equipment geofencing. A brand-new dive
  has no entry or exit GPS until it is saved, so for a new dive the last
  fallback is the device location the page already captures for nearby site
  suggestions (designer's call, to meet the maintainer's intent). This lets a
  dive logged right after surfacing, before a site is picked, still get nearby
  centers.
- When there is a reference point, shows a nearby section first, headed
  **"Near <site name>"** when it came from the site and **"Near this dive"**
  when it came from the dive's GPS (heading wording is the designer's call):
  every open center with coordinates within **50 km** of the point, nearest
  first, each showing its distance formatted with the diver's distance unit
  (`UnitFormatter.formatGeoDistance`; distance from `distanceMeters` in
  `lib/core/utils/geo_math.dart`).
- Then an **"All dive centers"** section: every other center, alphabetical as
  today. A center appears in only one section.
- Closed centers never appear in the nearby section. They are greyed out with
  the **Closed** tag and placed at the bottom of the alphabetical section,
  still selectable.
- When there is no reference point (no site with coordinates and no dive GPS),
  there is nothing to measure from: the picker is one alphabetical list with
  no section headers, as today, except that closed centers sit greyed at the
  bottom.
- A center without coordinates can't be measured and always goes in the
  alphabetical section.
- The center already on the dive keeps its checkmark wherever it lands.
- If no center is within 50 km, there is no nearby section.

The trip cylinder fill sheet uses the same picker but has no single site or
dive, so it passes no reference point and gets the plain alphabetical list
(with closed centers at the bottom).

The ranking is a pure function from (centers, reference point) to the two
sections, so it can be tested without widgets.

### Mockup

Layout A in the brainstorming mockups (a nearby section, then everything
else) was chosen over a single distance-sorted list and a nearby-only list
with search.

## Decided by the builder (the designer's calls, not the maintainer's)

- The column and field names (`is_permanently_closed` / `isPermanentlyClosed`).
- A `closed` boolean field in the dive center query entity
  (`dive_center_query_entity.dart`), so a diver can already hide closed
  centers with a list query (`closed = false`) without a new toggle.
- Exact wording of the tag, helper text and detail note, and their styling,
  following the existing greyed-out treatment of retired or sold equipment.
- Whether the section headers use the existing list section header widget.
- New strings go into every ARB file per the repo's l10n process.

## Constraints

- Distances respect the active diver's unit settings.
- Schema changes go through the migration ladder; tables live in
  `lib/core/database/tables/`.
- Run `test/architecture/` and `test/shared/` after adding files under `lib/`.
- The PR is a UI change: before and after screenshots of the picker, list,
  detail and edit pages.
