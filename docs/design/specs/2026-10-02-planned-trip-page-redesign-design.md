# Planned Trip Page Redesign

Date: 2026-10-02
Status: approved design, implementation plan pending
Branch: ericgriffin/planned-trip-ui-redesign-d5453d
Issue: #2845 (the PR body must say `Closes #2845`, and `Closes #2658` for
the rest-day follow-up)
Release: v1.8.1

## Problem

An upcoming trip has no page of its own. It is the past-trip story page with
a few cards switched on by `Trip.isUpcoming`, and three programs added a card
each to the same header: the gear alerts panel (#2469), the Cylinders card
(trip gas, #2451) and the Gear card (cylinder passports phase 4, #2585).

Twelve days before a Bonaire trip with six cylinder slots, seven packed items,
one service alert and a four-item checklist, the phone shows:

- The header (alert, Cylinders, Gear) filling the top half of the screen,
  the Gear card below the fold inside a nested scroll, the checklist at the
  very bottom of the story.
- Below the header, the past-trip story: an empty map band, "0 Total Dives,
  0m Total Runtime", then the hero. None of it helps before the trip.
- A Cylinders card talking about the live trip ("Full 3, Partial 0, Empty 0,
  Not filled yet 3", "Enough full cylinders through tomorrow") when nothing
  has been filled, and "Truck 4 · -- · --" chips.
- Gear as a wall of chips with "Use set" and "Add gear", while Cylinders says
  "Set up cylinders": two cards, two vocabularies, no hint that an owned
  cylinder is gear too.

Only liveaboards have tabs (Overview, Itinerary, Photos, Dives, Checklist) and
only liveaboards can plan an itinerary, although a resort week is planned day
by day as much as a boat week.

The story page itself pins a band (docked day plus map) at the top; the map
shows the whole trip's route and its pins name days, not dives.

## Decisions

Taken during brainstorming on 2026-10-02 and fixed for this spec.

- Gear and cylinders are one section, "What I'll dive with", with one Add.
  The live cylinder board (fills, forecast, ledger, record) appears only once
  the trip starts.
- Every trip type, at every width, gets the same six tabs: Overview,
  Itinerary, Gear, Checklist, Dives, Photos. The tab row scrolls on a phone.
- The itinerary is editable for every trip type. `DayType` gains Travel and
  Rest; Embark, Disembark, Sea day and Port day stay for liveaboards.
- Overview has two modes chosen by date: Prepare before the start date, Story
  from the first day on.
- The story is one plain scrolling column: no pinned band, no docked day, no
  trip-level map. Each day chapter carries its own map showing only that
  day's pins, with a fullscreen mode. Tapping a pin highlights the dive row.
- The hero and the stat strip stay at the top of the story as ordinary
  scrolling content.
- The cylinder board page (`/trips/:id/cylinders`) and the fill forecast
  rules are not changed.

## Page structure

`TripDetailPage` renders, for every trip type and both widths:

1. The app bar (phone) or the embedded header strip (desktop master-detail),
   unchanged, with the same actions and menu.
2. `SharedByBanner`, unchanged.
3. A scrolling `TabBar` with six tabs in this order: Overview, Itinerary,
   Gear, Checklist, Dives, Photos.
4. The `TabBarView`.

The `_buildStandardLayout` and `_buildLiveaboardLayout` split goes; one
layout remains. `TripHeaderCards` and everything it held are removed (see
Removals).

### Phases

| Phase | Rule | Overview mode |
| --- | --- | --- |
| Before departure | today's date is before `trip.startDate` | Prepare |
| In progress | `trip.isInProgress` | Story, with the Cylinders summary card |
| Past | `trip.endsBefore(today)` | Story |

"Today" is the device's local calendar date, as the hero's countdown already
computes it.

## Overview: Prepare mode

A single scrolling column:

1. `TripStoryHero`, unchanged: name, dates, location, "N days until
   departure", the checklist progress card when the list has items. Its
   Generate itinerary button is removed (it moves to the Itinerary tab).
2. `TripOverviewSummaryCard`: one card with four rows. Each row is a
   `ListTile` with an icon, a label, a trailing summary and a chevron, and
   switches the page to that tab (the Plan row opens the edit page instead).

| Row | Summary text | Opens |
| --- | --- | --- |
| Checklist | "1 of 4 done", plus "· 1 due in 7 d" in the warning colour when an open item is due within 7 days, or "· 1 overdue" in the error colour | Checklist tab |
| Gear | "7 packed · 6 cylinders", plus "· 1 service alert" tinted by the worst severity | Gear tab |
| Itinerary | "8 days · 18 dives planned", or "Not planned yet" | Itinerary tab |
| Plan | "3 dives/day · 2 share cylinders"; "Not set" when both are unset | Edit page |

   Counts come from the existing providers: `tripChecklistProgressProvider`,
   `tripChecklistProvider` (for due dates), `tripGearProvider`,
   `tripCylinderStatesProvider`, `tripServiceAlertsProvider`,
   `numberedItineraryDaysProvider`. A row whose provider has not loaded shows
   its label with no summary rather than a zero.

3. The Notes card, when the trip has notes.

No map, no stat strip, no empty-story illustration.

## Overview: Story mode

`TripStoryView` becomes one `CustomScrollView` of ordinary slivers:

1. `TripStoryHero`, unchanged.
2. `TripStatStrip`, unchanged.
3. `TripCylindersSummaryCard`, only while the trip is in progress and only
   when it has slots: the Full/Partial/Empty counts line, the fill forecast
   lines (`TripFillForecastText`), a chevron. Tap opens the board page. This
   is the counts half of today's `TripCylindersCard` without the chips.
4. `TripFlightCountdownCard`, as today.
5. `TripVesselSection`, liveaboards only, as today.
6. One chapter per day: `TripStoryDayHeader` (date, day type, weather),
   then `TripStoryDayCard`.
7. The Notes card.

Removed from the story: the pinned band, the docked day, the scroll-position
resolver and its throttle, and the trailing checklist card. The today divider
between chapters stays.

### The day map

`TripStoryDayCard` opens with `TripDayMap` when the day has at least one
mappable point; a day with none shows no map and no filler.

- Height 180 logical pixels, the card's rounded corners clipped, placed above
  the day's summary band.
- Points: the itinerary day's location, if it has coordinates, drawn as a
  flag pin; one pin per dive with a site location, drawn as the scuba dot
  with the dive number inside. Two dives at the same site are offset by a
  few pixels along the x axis so both can be hit.
- Camera: fitted to the day's points with padding; a single point is centred
  at zoom 13. Pan and zoom as the other embedded maps; no rotation.
- An expand `IconButton` in the top-end corner (tooltip "View fullscreen
  map") pushes `TripDayMapPage`.

Geometry: `TripStoryMapPoint` gains an optional `diveId`. The builder keeps
one point per itinerary location and emits one point per dive with a site
location (today it emits one per site per day). `TripStoryMapGeometry.
pointsForDay` is the per-day source; `nearestPointForDay` is no longer used
and is deleted.

### Pin to row

Tapping a dive pin sets the card's highlighted dive id. The matching
`DiveListItem` renders with `isHighlighted: true` and is scrolled into view
with `Scrollable.ensureVisible` when it is off screen. The highlight clears
when the same pin is tapped again, when another pin is tapped, or when the
row is opened. The itinerary flag pin is not tappable.

### Fullscreen

`TripDayMapPage` is pushed with a `MaterialPageRoute`, the pattern the dive
site and dive centre pages use. It shows:

- An app bar titled "Day 3 · Oct 16" (the day label the header uses), with
  the usual back button.
- The same `TripDayMap` filling the body, no expand button.
- Tapping a dive pin docks that dive's `DiveListItem` at the bottom of the
  screen; tapping the row opens the dive; tapping the pin again or the map
  background undocks it.

Returning pops back to the story at the same scroll position.

### Shared animator

The story's private `MapCameraAnimator` in `trip_story_map_header.dart` is
deleted; `TripDayMap` uses the one in
`lib/features/maps/presentation/widgets/map_camera_animator.dart`.

## Gear tab: What I'll dive with

### Add

A "+ Add" `FilledButton.tonal` in the tab's top-end corner, and in the empty
state, opens `TripGearAddSheet`, a bottom sheet with three `ListTile`s:

| Row | Opens | Result |
| --- | --- | --- |
| From my equipment | `EquipmentPickerSheet` (existing) | A cylinder item becomes a slot linked to the item (`TripCylinderRepository.createCylinders` with `equipmentId`, as the Cylinders sheet's "From my equipment" tab does). Any other item is packed (`TripEquipmentRepository.pack`). |
| An equipment set | `EquipmentSetPickerSheet` (existing) | Members packed with the same share filter and "Packed N items from X" snackbar as today's Use set. A cylinder member becomes a slot. |
| Rental cylinders | The Rental form of today's `AddTripCylindersSheet` | Slots with no equipment link. |

The add sheet is a chooser only; the three sheets it opens are the existing
ones, unchanged except that `AddTripCylindersSheet` exposes its Rental tab on
its own.

### The list

A `ListView` with two groups, each with a section header:

**Packed.** One `TripPackedItemRow` per item from `tripGearProvider`, in the
order the provider returns: the equipment glyph, the name, the type as the
subtitle. When the item has a trip alert the subtitle is replaced by its state
line:

- "Service due in 7 d · Annual service" in the warning colour (the item's
  worst `DueClock` from `tripServiceAlertsProvider`).
- "Overdue · Annual service" in the error colour.
- "Scrubber margin 4 of 6 dives" from `tripScrubberMarginsProvider` on a
  rebreather; in the error colour when `caution`.

Tap opens the equipment item page. A trailing overflow menu offers Unpack
(the same `unpack` call and error snackbar as today).

**Cylinders.** One `TripCylinderSlotRow` per slot from
`tripCylinderStatesProvider`, in board order. Before departure the row shows
the label, the size and working pressure when known, and "Rental" or the
owned item's name as the subtitle. From the first day on it shows the status
dot, the bottle label, the mix and the pressure, as today's chips do, with the
same colours (`tripCylinderStatusColor`) and semantics labels. Tap opens the
board page. The section header carries an "Open board" text button from the
first day on, and the fill forecast line (`TripFillForecastText`) while the
trip is in progress.

An owned cylinder appears once, under Cylinders. `tripGearIdsProvider`
already unions packed items with slot equipment, so service alerts on owned
cylinders keep working.

### Empty and past

With nothing packed and no slots, an upcoming trip shows the hint "Nothing
packed yet. Add the gear you'll bring and the cylinders you'll dive from."
with the Add button. A past trip with nothing shows "Nothing was packed for
this trip." and no button. A past trip with items shows them read-only apart
from Unpack, as today.

### Shared trips

A trip shared from another profile keeps today's rules: whatever is read-only
today stays read-only. The tabs change where things sit, not who may edit.

## Itinerary tab

### Day types

`DayType` gains `travel` ("Travel") and `rest` ("Rest"). The enum's stored
form is the name in a text column, so no schema rung and no migration; an
older peer reading an unknown name already falls back to `diveDay` in
`DayType.fromName`.

The day sheet's dropdown offers Travel, Dive day, Rest to every trip and adds
Embark, Disembark, Sea day, Port day on a liveaboard. A maritime row on a
non-liveaboard trip (from before this change, or from a type change) keeps
its value and label; the dropdown then lists that value too so the sheet can
save without silently retyping it.

`DayTypeL10n.localizedName`, the tab's `_dayTypeIcon` and `_dayTypeColor`
switches gain the two cases: Travel uses `Icons.flight_takeoff` in the
tertiary colour, Rest uses `Icons.beach_access` in `onSurfaceVariant`.

### Generate

`ItineraryDay.generateForTrip` takes a `TripType`. A liveaboard gets Embark,
Dive days, Disembark as today; every other type gets Travel, Dive days,
Travel. A non-liveaboard trip of one or two days gets Dive days only, since
there is no middle to travel around; a liveaboard keeps today's rule at every
length (a two-day one is Embark then Disembark).

The button moves from the story hero to the tab:

- Empty tab: "No itinerary yet. Generate one from the trip dates, or add days
  as you go." with a Generate button.
- Some dates missing (`coversTrip` false): a "Fill in missing days" button
  above the list, which adds only the missing dates with the per-type types
  above and leaves existing rows untouched.
- All dates present: no button.

`regenerateForTrip` keeps having no caller.

### The day sheet

`ItineraryDayEditSheet` gains a Planned dives field (a `readNumber` integer,
blank for "derive it", 0 allowed) saved through the existing `plannedDives`
column. The location field's label is "Location" on a non-liveaboard and
"Port / Anchorage" on a liveaboard. Saving a day as Rest sets planned dives to
0; saving as Dive day with 0 keeps the type.

### The list

As today (date, day number, type, location, that day's dives) plus a
"N dives planned" line on days ahead whose `plannedDives` is set. The
`trips_itinerary_noDives` empty state is replaced by the Generate empty state.

### Rest day follow-up (#2658)

`TripStoryDay` treats a `DayType.rest` row as a rest day, alongside today's
rule for a Dive day planned at 0. `ItineraryDayRepository.setPlannedDives`
types a new row Rest when the saved count is 0 and Dive day otherwise, and
retypes an existing Dive-day row to Rest when 0 is saved on it. This closes
#2658.

## Checklist, Dives and Photos tabs

- **Checklist:** the liveaboard tab as it is today, for every trip: the
  "Pre-dive checklist" button, then `TripChecklistSection`.
- **Dives:** the existing `_buildDivesTab`, extracted to `TripDivesTab`.
- **Photos:** the existing `_buildPhotosTab`, extracted to `TripPhotosTab`.

## Removals

Deleted with their tests:

- `trip_header_cards.dart`, `trip_gear_alerts_panel.dart`,
  `trip_cylinders_card.dart`, `trip_gear_card.dart`.
- `story/trip_story_band.dart`, `story/trip_story_band_extents.dart`,
  `story/trip_story_docked_day.dart`, `story/trip_story_map_header.dart`.
- The hero's `_GenerateItineraryButton`.
- The story view's `_onScroll`, `_resolveDockedDay`, `_headingTop`,
  `_bandExtents`, `_dayKeys`, `_activeDayIndex`.
- `TripStoryMapGeometry.nearestPointForDay`.
- The l10n keys those widgets alone used, in all 11 ARB files.

`TripServiceAlertList` and `TripScrubberMarginDetails` stay: the rows reuse
their line formatting helpers (`tripServiceAlertItemCount`,
`tripScrubberMarginSummary`) and the equipment page still shows the lists.

## New files

All under `lib/features/trips/presentation/` unless noted; each under 300
lines.

| File | Holds |
| --- | --- |
| `widgets/overview/trip_prepare_overview.dart` | Prepare mode column |
| `widgets/overview/trip_overview_summary_card.dart` | the four rows |
| `widgets/trip_cylinders_summary_card.dart` | the in-progress card |
| `widgets/gear/trip_gear_tab.dart` | the tab, groups, empty states |
| `widgets/gear/trip_gear_add_sheet.dart` | the three-row chooser |
| `widgets/gear/trip_packed_item_row.dart` | one packed item |
| `widgets/gear/trip_cylinder_slot_row.dart` | one slot |
| `widgets/story/trip_day_map.dart` | the per-day map and its pins |
| `pages/trip_day_map_page.dart` | fullscreen |
| `widgets/trip_dives_tab.dart`, `widgets/trip_photos_tab.dart` | extracted tabs |
| `widgets/trip_detail_tabs.dart` | the tab row and view, shared by both widths |

## Localization

Every new string lands in all 11 ARB files in the register each locale uses
(informal in de, es, it as decided on #2630; es avoids "tú"). New keys use
the `trips_overview_*`, `trips_gear_*`, `trips_itinerary_*`,
`trips_dayType_*` and `trips_story_dayMap_*` prefixes.

## Testing

Widget tests, written first:

- `trip_detail_page_test.dart`: the six tabs on a shore, resort, day and
  liveaboard trip, phone and desktop; Overview is Prepare before the start
  date and Story on it and after; no header cards.
- `trip_prepare_overview_test.dart`: each summary row's text for loaded,
  loading and empty providers; each row opens its tab; Plan opens the edit
  page.
- `trip_gear_tab_test.dart`: both groups; an owned cylinder once; the service
  and scrubber subtitles and colours; Add chooser routes; Unpack; the two
  empty states; slot rows before and after departure.
- `trip_cylinders_summary_card_test.dart`: shown only in progress with slots.
- `trip_itinerary_tab_test.dart`: Generate per trip type; Fill in missing
  days adds only missing dates; the sheet saves planned dives and the Rest
  retype; the dropdown's values per type; label per type.
- `trip_story_view_test.dart`: one scroll, no band; chapters in order; the
  checklist card gone.
- `trip_day_map_test.dart`: pins only for that day; dive pins carry the
  number; same-site offset; tap highlights the row and clears on the second
  tap; the itinerary pin is not tappable.
- `trip_day_map_page_test.dart`: title, docked row on tap, opens the dive.
- `trip_story_day_test.dart`: Rest typed day is a rest day (#2658).
- `day_type_l10n_test.dart`: every `DayType` value has a label in every
  locale.
- `test/architecture/` after the new files.

Screenshots for the PR: before (captured 2026-10-02, phone light and dark,
desktop light) and after of the Overview in both modes, the Gear tab, the
Itinerary tab and a day map, at phone and desktop widths, light and dark.

## Out of scope

- The cylinder board page's internals, the fill forecast rules, the fill
  sheets.
- The trip list page and its upcoming banner.
- The edit page: it is not changed.
- Sync of the new day types beyond the name fallback.
- A map on the Prepare overview.
