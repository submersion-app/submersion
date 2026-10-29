# New trip from selected dives, and side trips

Issue: #3658. Release: v1.8.4.

## Intent

Today a trip is made first, with its dates typed up front, and dives are then
pulled in by date. Divers often know which dives belong together long before
they remember the exact dates. This feature lets them select dives on the dive
list and turn that selection into a new trip, with as much of the trip filled
in from the dives as the dives can supply.

The case that prompted it is splitting part of an existing trip into its own
trip: a four-day liveaboard inside a two-week Indonesia trip, a day of cave
dives inside a Florida trip. The new trip is a **side trip**: it overlaps the
larger trip, and the larger trip still counts the side trip's dives.

## Goals

1. A "New trip from selection" action on the dive list's selection bar that
   opens the new-trip form prefilled from the selected dives.
2. Saving that form creates the trip and moves exactly the selected dives into
   it.
3. A trip can be **part of** one larger trip (a side trip). The larger trip's
   counts, totals, map, story, Dives tab and Photos tab include its side
   trips' dives.
4. Side trips are visible as such: nested under their larger trip in the trip
   list, tagged on the larger trip's Dives tab, named with their parent in the
   dive list's trip groups and on dive detail.

## Non-goals

- A dive belonging to several trips. Each dive keeps exactly one trip (its
  home trip, which may be a side trip). This was weighed and rejected: almost
  150 files read or write a dive's trip.
- More than one level of nesting. A side trip cannot have side trips.
- Carrying the link through UDDF or CSV export or import. Those formats have no
  place for it. Submersion backups and sync do carry it, since they copy the
  table.
- Changing how a new dive is matched to a trip by date. Overlapping trips
  already resolve to the one that started last (`tripForDiveDate`,
  `TripRepository.findTripForDate`), which already favours a side trip over
  its parent.

## Anti-goals (would be a failure even if it works)

- **Silent edits to another trip.** Making or editing a side trip never changes
  the larger trip's dates or fields.
- **Double counting across trips.** Per-trip figures include side trips, but
  any total over all trips (overall statistics, "dives on trips", cross-trip
  sums) counts each dive once.
- **Losing dives from the larger trip.** Deleting a side trip returns its dives
  to the larger trip; they must not end up tripless.
- **A slower trip list.** Nesting and the inclusive counts must not add a query
  per trip.

## Decisions made with the maintainer

| Topic | Decision |
| --- | --- |
| Model | A side trip points to its parent: new nullable `trips.parent_trip_id`. One level deep. |
| Larger trip includes side-trip dives | Yes, in counts, map and story. |
| Trip list | Side trips nest under the larger trip, indented, like a folder (mockup option A). The larger trip shows its inclusive dive count and "N side trips". |
| Larger trip's Dives tab | One list in date order; each side-trip dive carries a small tag naming its side trip (mockup option A). |
| Creation flow | Selection bar action "New trip from selection" opens the normal new-trip form prefilled; the user reviews and saves. |
| On save | Exactly the selected dives move to the new trip. The post-save "dives in these dates" assignment prompt is skipped. |
| Part-of prefill | When every selected dive is on the same trip, that trip is prefilled as the parent; the user can clear it. |
| Deleting a side trip | Its dives return to the larger trip. |
| Tank links to the larger trip's cylinders | Kept: the parent's cylinders count as the side trip's own for links, and the parent's cylinder views include side-trip usage. |

## Behaviour in detail

### Creating a trip from a selection

1. On the dive list in selection mode, a new `BulkAction`, "New trip from
   selection", sits with Combine, Compare in 3D, Export and Edit
   (`_bulkActions` in `dive_list_content.dart`). It is enabled for one or more
   selected dives.
2. It opens the new-trip form (`TripEditPage`, create mode) with these fields
   prefilled. Each is a starting value the user can change:
   - **Start and end date:** the calendar day of the earliest and latest
     selected dive, read the way trips read dive days (wall clock in UTC
     components; see `trip_for_dive_date.dart`).
   - **Location:** the region the dive sites share, when every selected dive
     with a site shares one; otherwise the country they share; otherwise
     empty. *(Builder's call on exact wording, e.g. "Raja Ampat, Indonesia"
     when both region and country agree.)*
   - **Name:** the location from above plus the month and year of the start
     date ("Raja Ampat, Mar 2026"); when there is no location, a generic
     localized "Trip, Mar 2026" style name. Month formatting follows the app
     locale.
   - **Part of:** the trip every selected dive is on, when they are all on the
     same trip and that trip is not itself a side trip. If that trip is a
     side trip, prefill its parent instead. Otherwise empty.
   - **Trip type, resort name, liveaboard name:** when every selected dive has
     the same dive center, use its name as the resort name, leaving the type
     at its default. *(Maintainer accepted this as a guess; builder may skip
     the type inference entirely if no reliable signal exists.)* Otherwise
     defaults.
3. On Save, the trip is created and the selected dives (by id) are moved into
   it in one transaction, using the existing assignment path
   (`TripRepository.assignDivesToTrip` or equivalent) so dives are stamped and
   marked pending for sync. The candidate-dive scan and
   `showDiveAssignmentDialog` that normally follow a create are skipped.
4. Selected dives may come from several trips or none. They all move. Only the
   Part-of prefill depends on them sharing a trip.
5. Cancel discards everything; no dive changes.
6. After saving, the app opens the new trip (as a normal create does), and the
   dive list leaves selection mode.

### Linking by hand

The trip form gets a **Part of** field: a picker of trips that the active
profile can see, excluding the trip itself, excluding trips that are side
trips, and offering "None". The field is hidden on a trip that already has
side trips (it cannot become a side trip itself). Clearing it makes the trip
standalone.

### What the larger trip includes

"The dives of trip T" becomes T's own dives plus the dives of every trip whose
`parent_trip_id` is T. This applies to every per-trip figure and view:

- trip stats: dive count, total runtime, max and average depth
  (`getTripWithStats`, `getAllTripsWithStats`);
- the Dives tab (`trip_dives_tab.dart`), map and story providers;
- the Photos tab and media library filtered by trip
  (`media_library_repository.dart`);
- per-trip rankings and per-trip rates (insights "top trips",
  `trip_history_repository.dart`), and the query-language trip dive count
  (`trip_query_entity.dart`).

It does **not** apply to the larger trip's own itinerary days, gear,
cylinder slots, checklist, weather, liveaboard details or documents: those
stay per trip (cylinder usage is the exception, below). *(Builder: list each site you change or deliberately leave, with
the reason, in the plan. Per the anti-goal, totals across all trips must stay
once-per-dive.)*

A side trip's own figures and views are unchanged: just its dives.

### Trip list

- Side trips are nested beneath their larger trip, indented, ordered by start
  date. The larger trip sorts by its own fields as today.
- The larger trip's row shows the inclusive dive count and a short
  "N side trip(s)" note.
- This applies to all trip list tile styles (detailed, compact, dense).
- When search or a filter matches a side trip but not its parent, the side
  trip appears as a top-level row with a "Part of <parent>" note. *(Builder's
  call on exact presentation.)*
- A side trip whose parent the active profile cannot see is shown as a
  standalone trip.

### Larger trip's Dives tab

One list in date order of the inclusive dives. Each dive that belongs to a
side trip shows a small tag with the side trip's name. Tapping a dive opens it
as today.

### Side trip's own page

Shows "Part of <parent>" near the title, tappable to open the parent.

### Dive list and dive detail

- Dive list "Group by trip": a dive is grouped under its home trip. A side
  trip's group header names its parent ("Raja Ampat liveaboard, part of
  Indonesia 2026").
- Dive detail's trip line shows the side trip with its parent; both open on
  tap.

### Dates

A side trip's dates may run outside the parent's dates. Nothing is adjusted
automatically, and no warning is required.

### Deleting

- **Deleting a side trip:** its dives are moved to the parent trip (stamped
  and marked pending for sync), instead of having their trip cleared. The rest
  of the delete is unchanged.
- **Deleting a larger trip:** each side trip's `parent_trip_id` is cleared
  (stamped, pending for sync); side trips keep their dives and become
  standalone. Then the delete proceeds as today, clearing the larger trip's own
  dives' trip.
- The delete confirmation text for a trip with side trips mentions that they
  become standalone trips. *(Builder's call on wording.)*

### Statistics

A side trip still counts as one trip in "number of trips" figures. Totals over
all trips count each dive once.

### Tank links to the larger trip's cylinders (maintainer's decision)

A side trip's dives keep their tank links to the larger trip's tracked
cylinders. For a side trip, the larger trip's cylinders are not "another
trip's": `clearForeignTripCylinderLinks` treats a cylinder on the dive's trip
**or on that trip's parent** as its own, on every path that changes a dive's
trip (dive edit, bulk edit, rule undo, trip assignment, and the new
selection flow). The same rule widens wherever a side-trip dive's tank may be
linked or offered a cylinder (`tripCylinderIdsForTrip` and the tank editor's
cylinder choices): a side-trip dive may pick its own trip's cylinders or the
parent's.

The larger trip's cylinder views (cylinder board, gas record, fill forecast
inputs) count usage from side-trip dives linked to its cylinders. A side trip
can still track cylinders of its own (a liveaboard's tanks), and those stay on
the side trip.

When a side trip's link to its parent is cleared (by hand, or because the
parent is deleted), its dives' links to the former parent's cylinders become
foreign and are cleared, staged for sync, as any move off a trip clears them
today. When a side trip is deleted, its dives move to the parent and keep
their links to the parent's cylinders.

### Settled after the builder review (designer's calls)

- **Itinerary day cards.** The larger trip's itinerary day rows stay its own,
  but the dives shown on each day card come from the inclusive dive set, so a
  day spent on the liveaboard shows the liveaboard's dives. This follows from
  the story being inclusive; the dive provider is not forked.
- **Map and the dive list trip filter.** "Map" means both the story's day map
  and the trip page's map button. The dive list's trip filter
  (`DiveFilterState.tripId`) becomes inclusive: filtering by a larger trip
  returns its side trips' dives too; filtering by a side trip returns only its
  own.
- **Per-trip rates and rankings across trips.** Where several trips are
  compared or sampled (insights "top trips" ranking, the
  `trip_history_repository.dart` dives-per-day sample feeding the scrubber
  estimate), only top-level trips take part, each with its inclusive dives.
  Side trips are left out of those samples so no dive counts twice. A side
  trip's own page still shows its own figures.
- **Shared trips and profiles.** Setting or clearing Part of follows the same
  rule as editing any other trip field (`updateTrip`). The Part-of picker
  offers trips visible to the active profile. Deleting a larger trip clears the
  link on every side trip, whoever owns it. Deleting a side trip moves every
  profile's dives on it to the larger trip. Deleting a profile
  (`diver_delete_steps.dart`) applies the same two rules to the trips it
  removes.
- **Older app versions during sync.** Accepted limitation, no version gate. A
  device on an older version shows side trips as standalone, counts the larger
  trip without them, and deleting a side trip there leaves its dives tripless.
  The release notes mention that devices sharing a log should update together.

## Data and sync

- New column `trips.parent_trip_id`, nullable text referencing `trips.id`,
  added through the schema ladder in `lib/core/database/migrations/` (never in
  `database.dart` itself), at the next free schema version after checking open
  PRs (main is at 320 as of 2026-10-28). Fresh databases get it from the table
  definition in `lib/core/database/tables/trip_tables.dart`.
- An index on `parent_trip_id` so "side trips of T" and the inclusive dive
  queries stay cheap.
- `Trip` entity gains `parentTripId` with `copyWith` support.
- The trips sync serializer carries the field. A row arriving from a device
  that does not know the field leaves it unchanged per the existing
  omitted-field convention.
- **Dangling or invalid links** (parent deleted on another device, a parent
  that is itself a side trip after a merge, a link to self): treated as no
  parent when read. Writing code never creates them. *(Builder's call whether
  a repair pass also clears them on write or open.)*
- Sharing (per-profile trip sharing): the link is a property of the trip row.
  Visibility of the parent is checked when presenting, as above.

## Constraints

- Follow the repo's CLAUDE.md: TDD, small files (`trip_edit_page.dart` is
  already over 1,200 lines, so the prefill and selection-assignment logic go in
  new files), immutable entities, localized strings in the ARB files for every
  new label.
- Any unit shown (depths and durations on the Dives tab) respects the active
  diver's unit settings, as the existing tab already does.
- Per-profile visibility rules already applied to trips and dives must hold for
  the inclusive queries.
- `test/architecture/` guards run over any new `lib/` file.

## Left to the builder

- Exact prefill heuristics beyond the rules above, and their wording.
- How the prefilled draft and dive ids reach `TripEditPage` (constructor
  arguments, a route extra, or a provider), consistent with how the page is
  opened embedded and pushed today.
- Visual details of the nesting, tags and "Part of" lines, consistent with the
  existing trip tiles and theme.
- Whether "Part of" is a picker sheet or a dropdown.
- Query shape for inclusive dives (`trip_id = ? OR trip_id IN (SELECT id FROM
  trips WHERE parent_trip_id = ?)` or a join), as long as the trip list stays
  one query.
