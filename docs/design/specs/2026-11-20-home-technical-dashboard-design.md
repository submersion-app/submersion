# Home as a Technical Dashboard: Design

**Date:** 2026-11-20
**Status:** Approved
**Release:** v1.8.5
**Feature area:** `lib/features/dashboard/`, `lib/features/settings/`

## Why

Home is the least interesting page in the app. Its cards are arranged
awkwardly, rows leave blank space where no card sits, and the card content is
thin. The header (an animated ocean hero with a greeting) takes a large share
of the first screen and says little.

Home should instead look and read like a technical dashboard: dense, data
first, every row full, with a small header.

## Goals

- A technical-looking dashboard of bordered panels in a tight grid.
- No blank gaps at any width, with any combination of panels switched on.
- A slim header that keeps the logo and offers a diver switcher whenever more
  than one diver profile exists.
- Richer panel content: trend lines, charts, tables and service bars in place
  of text summaries.
- Several ready-made layouts, selectable in Settings, each of which the diver
  can then customise.

## Non-goals

- No change to the Insights page. Home panels summarise; they do not replace it.
- No per-panel size control (a diver cannot make a panel wider or taller).
- No new data collection and no database schema change.
- No change to the nav rail or bottom navigation bar.

## Anti-goals

- Home becoming a second Insights page. Each panel is a small summary that
  opens the full page when tapped.
- Home getting slower to open. Home may do no more sample decoding than it
  does today (one dive's profile, off the UI isolate, and only when its panel
  nears the screen).
- A safety alert (overdue gear, expired insurance, closed or conflicting
  flight window) becoming hideable.
- Numbers on Home changing because of a filter set on the Insights page.

## Decisions

Decided with the maintainer in conversation:

| Decision | Choice |
| --- | --- |
| Look | "Panels": bordered panels in a tight grid, like a monitoring console |
| Header | One slim bar: logo, status lights, actions, diver switcher |
| Ocean hero and greeting | Removed |
| Layout choice | Four presets in Settings, each customisable afterwards |
| Default preset | Balanced |
| Final appearance | As in the approved mockup (see Mockups) |
| Delivery | One pull request, no build switch; the old Home is removed in the same change |

Calls made by the author, for the maintainer to check:

| Call | Reason |
| --- | --- |
| The gauge strip becomes the header's status lights | Same information; frees a full row |
| Milestones, Year in Review and Quick Actions stop being cards | Key numbers and the header cover them |
| Swap with a buddy and Emergency card move to a "More" menu in the header | Quick Actions held six actions and the bar has room for two; these two have no other one-tap route |
| Insights and Tracks buttons are dropped | Both are already navigation destinations |
| Upgrading divers start on Balanced; panels they had hidden stay hidden where the panel still exists | The old card order cannot map onto a different set of panels |
| Layout choice stays per device | Matches today's card order; phone and desktop can differ |
| "Only when relevant" panels sit second in every preset | They are things waiting on the diver |
| The latest profile is a static chart of about 120 points, not the interactive one | Lighter to draw, and one tap opens the full chart |
| "Only when relevant" panels always form a row of their own | One arriving late then changes only its own row, not every row below |
| Small chart panels pair two across on a phone; small list panels go full width | Lists of named items are unreadable at half a phone's width |
| "All clear" counts the lights that exist and are fine; no light gains a new state | Most lights only exist when there is something to say |
| "Latest dive vs average" compares against the last 12 months, using maximum depth | A career average hides how the diver dives now |
| Phone calendar shows 6 months | 12 months of day cells are unreadable at phone width |
| A diver with no dives sees a single "Log or import your first dive" panel under the key numbers | Chart panels would all be empty |

## Approaches

Three ways of building the grid were considered.

1. **Ordered panel list with justified rows (chosen).** One ordered list of
   panels drives every width. Each panel declares a width class and a height
   class. A pure layout function packs the list into rows and stretches each
   row to the full width. Presets are just a named order plus a hidden set.
   This fits the existing model (`homeCardOrder`, `hiddenHomeCards`, a pure
   layout pass, a lazy sliver grid) and guarantees full rows for any
   combination.
2. **Hand-arranged layout per preset.** Each preset is a fixed arrangement.
   It allows finer tuning but cannot survive a diver hiding or moving a panel,
   so customisation would have to go. Rejected: it removes a feature divers
   have today.
3. **Free-form grid the diver drags and resizes.** The most flexible, and the
   most work (drag and resize on touch and desktop, collision handling, a
   stored geometry per device size). Rejected as far more than the problem
   needs.

## The page

`DashboardPage` keeps its shape: a `Scaffold` whose body is a
`RefreshIndicator` around a `CustomScrollView`. From the top:

1. `DemoModeDashboardCard` (unchanged; shows only in demo mode).
2. The header bar, pinned (it does not scroll away).
3. On a phone only, the status strip, directly under the bar.
4. The panel grid, as a lazy sliver.

Pull to refresh stays and invalidates every provider Home reads.

### Header bar

One row, about 36 logical pixels tall plus safe-area padding, in the theme's
surface colour with a hairline bottom border.

Left to right on desktop (800 px and wider):

- The app logo (`assets/icon/icon.png`, small) and the app name.
- The status lights (see below), in one line.
- A spacer.
- "Log dive" (filled) and "Plan" (outlined). Log dive opens the existing
  add-dive sheet; Plan opens the dive planner. Same destinations as today's
  Quick Actions.
- A "More" menu holding Swap with a buddy (hidden where swap is unavailable,
  as today) and Emergency card.
- The diver switcher: an avatar pill with the diver's short name. Rendered
  only when `diverCountProvider` reports two or more; opens
  `showDiverSwitcherSheet`. With one profile the pill is absent and nothing
  shifts.

On a phone the bar holds the logo, the app name, a "+" button (Log dive), the
"More" menu (which also holds Plan) and the avatar. Every tappable control has
a hit area of at least 44 by 44 even where it is drawn smaller.

### Status lights

The status lights are today's gauge chips (`HomeChipType`, 15 types) in a
compact form: a coloured dot and a short label. They read
`dashboardGaugesProvider` as the gauge strip does today.

- Colour: green for fine, amber for due soon, red for alert, neutral for
  informational. Colour is never the only signal; the label names the state.
- Order: alerts first, then warnings, then the rest in today's chip order.
- Each light opens the same destination as its chip does today, with
  `context.push`.
- Each can be hidden with the existing per-chip switches
  (`hiddenHomeChips`), except the three safety alerts, which are always shown.
  Because the header cannot be hidden, the rule that forced the gauge strip
  back on (`_hasSafetyAlert` in `dashboard_page.dart`) is no longer needed.
- Desktop: lights that do not fit the line scroll sideways.
- "All clear" never invents a state: the count is of the lights that
  currently exist and are fine or informational. A light that today appears
  only when there is something to say still appears only then.
- Phone: the strip under the bar shows every amber or red light with its
  label, then one pill counting the rest ("5 all clear"). With nothing amber
  or red it is a single "All clear" pill. Tapping the count pill opens a sheet
  listing every light.
- The loading and error states of the current gauge strip (including its
  retry) carry over.

## Panels

Every panel is a bordered box with a small capital title, optional summary
text at the right of the title, and its content. The whole panel is one tap
target that opens its full page. Panels use the theme's colours; no panel
hard-codes a colour. Every value respects the active diver's unit settings,
and every panel reads the active diver only.

Width classes: **S** (a third of a desktop row), **M** (half), **L** (two
thirds), **XL** (full row). S panels come in two kinds: **S chart** (Depth
mix, Dives per month, Gas mix, Dive types), which may sit two across on a
phone, and **S list** (every other S panel), which is full width on a phone. Height classes: **short** (about 96), **medium**
(about 180), **tall** (about 260), each scaled by the text scale factor.

| Panel | Width | Height | Shows | Opens |
| --- | --- | --- | --- | --- |
| Key numbers | XL | short | Up to 8 number tiles (below) | Per tile |
| Waiting for download * | S | short | Drafts awaiting a dive computer download | The draft |
| Pre-dive checklist * | S | short | Resume or start; resolved of total | The session |
| Active course * | S | short | Course name; requirements met of total | The course |
| Activity calendar | L | medium | One cell per day for the last 12 months, shaded by dive count; total dives and dive days | Dives list |
| Gear service | S | medium | A bar per item nearest its service interval (up to 5), with time or dives remaining; overdue first | Equipment with the service-due filter (`openEquipmentWithServiceDue`, as the gear chip uses) |
| Coming due | S | medium | The next expiries across gear, insurance, certifications and documents, soonest first | The item |
| Next trip * | S | medium | Trip name, dates, countdown, checklist progress, flight window | The trip |
| Latest profile | M | medium | Depth profile of the latest dive, about 120 points; site, depth, runtime, temperature | The dive |
| Latest dive vs average | S | medium | Latest dive's maximum depth, runtime and SAC as bars against the diver's averages over the last 12 months | The dive |
| Recent dives | M | medium | Table of the last 4 dives: site, date, depth, runtime, SAC | Row opens the dive |
| SAC trend | M | medium | Line of SAC over the last 30 dives that have one | Insights, gas |
| Depth mix | S | medium | Bars of dives per depth band, all dives | Insights, depth |
| Dives per month | S | medium | Bars for the last 12 months, empty months included | Insights, activity |
| Gas mix | S | medium | Share of dives on air, nitrox, trimix | Insights, gas |
| Dive types | S | medium | Share of dives by type, top 3 | Insights |
| Top sites | S | medium | Top 3 sites by dive count | Sites |
| Top buddies | S | medium | Top 3 buddies by dive count | Buddies |
| Species seen lately * | S | medium | Most-sighted species over recent dives; total species | Marine life |
| Recent photos * | S | medium | Grid of recent media | The media item |
| Recent sites * | S | medium | Map of recent dive sites | Sites map |
| On this day * | S | medium | A dive from this date in an earlier year | The dive |
| First dive | XL | medium | "Log or import your first dive" with both actions; shown only with no dives | Add-dive sheet, import |

Panels marked * appear only when they have something to show, as conditional
cards do today (resolved to content; loading and error both count as absent).
The others are always present when switched on and hold their own loading,
empty and error states inside the box.

Key number tiles, each with a value, a unit, a one-line comparison and, where
a series exists, a small trend line:

| Tile | Value | Comparison | On by default |
| --- | --- | --- | --- |
| Dives | Career dives (including the pre-app logbook count) | Dives this year | Yes |
| Time under | Career hours | Hours this year | Yes |
| Last dive | Days since the last dive | Site and date | Yes |
| Average SAC | Mean over the last 10 dives that have one | Change against the 10 before | Yes |
| Deepest this year | Deepest dive this calendar year | Its site | Yes |
| Next trip | Days to the next trip | Trip name, checklist progress | Yes |
| Average depth | Mean maximum depth this year | Change against last year | No |
| Species | Distinct species seen | New this year | No |

A tile with no value (no SAC data, no trip planned) is left out and the
remaining tiles share the row. While its data loads, the panel shows one
placeholder tile per enabled tile, so the row does not jump twice.

Key numbers is the one panel whose height is not a fixed class: it is one
tile row tall on desktop and grows by a tile row each time the tiles wrap, so
its height follows the width tier and the number of tiles shown. On desktop the tiles share one row equally; on
a tablet they wrap to rows of three or four; on a phone they sit two across.
The tiles are chosen on a sub-page of the Home settings page and stored as a
hidden set like the panels.

## Layout engine

A pure function replaces `buildDashboardEntries`: it takes the ordered list of
visible panels and a width tier and returns rows, each a list of panels with a
flex weight. `DashboardGrid` stays a lazy sliver and renders one row per item.

Width tiers follow `ResponsiveBreakpoints`:

| Tier | Width | Units per row | S chart | S list | M | L | XL |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Desktop | 1200 and up | 12 | 4 | 4 | 6 | 8 | 12 |
| Tablet | 800 to 1199 | 12 | 6 | 6 | 6 | 12 | 12 |
| Phone | under 800 | 12 | 6 | 12 | 12 | 12 | 12 |

Packing: walk the list in order, adding panels to the current row while their
units fit in 12. When the next panel does not fit, close the row. Each closed
row's panels are stretched in proportion to their units so the row fills the
width. The last row is stretched the same way, so a lone panel fills its row.
The diver's order is never changed to make rows fit.

One exception keeps the page steady while data arrives. A run of adjacent
"only when relevant" panels always forms a row of its own: the row before it
is closed, and the row after it starts fresh. A conditional panel that
resolves late therefore widens or narrows only its own row (or adds or
removes that one row) and leaves the membership of every other row alone.

Row height is the tallest height class in the row; every panel in the row is
given that height, so panels in a row always align top and bottom. Heights are
fixed per class (not measured from content), which keeps rows lazy and avoids
the intrinsic-height layout that previously broke the grid in an unbounded
scroll column. Panel content must fit its class at the largest supported text
scale by trimming rows or eliding text, never by overflowing.

Constraints carried over from the current grid and its tests:

- Rows are keyed by their first panel and kept alive, so a panel arriving late
  does not remount the rows below it.
- The sites map mounts on its row's first paint (`DeferUntilPainted`) and
  holds for the first photo result so it is not mounted twice.
- A hidden panel's provider is not watched (issue #4251).

## Presets and customisation

Four presets. Each is an ordered list of panels that are on; every other panel
is off and listed after them in the settings page.

| Preset | Panels, in order |
| --- | --- |
| Balanced (default) | Key numbers; Waiting for download; Pre-dive checklist; Active course; Activity calendar; Gear service; Latest profile; Recent dives; Depth mix; Dives per month; Gas mix; Recent photos; Recent sites; On this day |
| Ready | Key numbers; Waiting for download; Pre-dive checklist; Active course; Gear service; Next trip; Coming due; Recent dives; Recent photos; Recent sites |
| Trends | Key numbers; Waiting for download; Pre-dive checklist; Active course; Activity calendar; Dives per month; SAC trend; Depth mix; Gas mix; Top sites; Top buddies; Dive types |
| Logbook | Key numbers; Waiting for download; Pre-dive checklist; Active course; Latest profile; Latest dive vs average; Recent dives; Recent photos; Recent sites; Species seen lately; On this day |

The First dive panel is not in any list; it is inserted after Key numbers
whenever the diver has no dives and cannot be hidden or moved.

Settings > Appearance > Home (`HomeAppearancePage`) gains, above the existing
list:

- A "Layout" picker with one tile per preset. Each tile carries a small
  thumbnail drawn from that preset's own row widths, and its name.
- Choosing a preset replaces the panel order and hidden set with the preset's,
  after a confirmation when the current layout is Custom (the diver's own
  arrangement would be lost).
- The current preset is highlighted. Any reorder or show/hide makes the layout
  "Custom" and no tile is highlighted. "Reset to default" returns to Balanced.

Below the picker, the existing reorderable list with a switch per panel stays,
now listing the panels above. Key numbers is one row that opens a sub-page of
tile switches. The status-light switches stay at the bottom, unchanged.

When every panel is hidden, the existing all-hidden message with its link to
this page still shows under the header.

### Storage and upgrade

All per device, in SharedPreferences, alongside the existing keys:

- A new panel enum with new stored keys for order and hidden set, so the old
  keys (`home_card_order`, `hidden_home_cards`) are left untouched and never
  rewritten.
- No preset name is stored. The highlighted preset is worked out by comparing
  the visible panels with each preset, so it cannot go stale.
- The hidden key-number tiles.

On first run of the new Home (the new keys are absent): the layout is
Balanced. If the old hidden set names a panel that still exists (recent
dives, photos, sites map, on this day, active courses, pre-dive, waiting for
download), that panel starts hidden and the layout shows as Custom. Nothing
else carries over. `hiddenHomeChips` is read as it is today.

Unknown names in the stored order are dropped and panels added in later
versions are slotted in, as `reconcileHomeCardOrder` does today.

## Data

Home's providers call repositories directly with the current diver id and no
filter. They must not watch the Insights providers, which follow the Insights
page's filter. Repositories return metric values; panels convert for display
with `unitFormatterProvider`.

Already available and cheap (SQL aggregates, no sample decode): career totals,
this year against last year, days since last dive, depth distribution, top
sites, gas mix, dive types, top buddies, species count, gear service clocks,
next trip and checklist progress, recent media, recent sites, on this day,
active courses, drafts, and all status lights.

New work:

- **Activity calendar:** a query returning dives per local calendar day for
  the last 12 months.
- **Dives per month:** `DiveStatistics.divesByMonth` exists but skips empty
  months and labels months in English; Home fills the gaps and localises the
  labels.
- **SAC and depth series:** the per-dive series return every dive; Home needs
  only the most recent, so add a limit rather than loading all and trimming.
- **Gear service bars:** the service clocks give time and usage remaining but
  no "fraction used"; compute it from the clock's interval.
- **Latest profile:** the cached list-tile profile (about 20 points) is too
  coarse at this size. Read the one dive's profile off the UI isolate, as
  Home does today, and downsample it to about 120 points for a static chart.
- **Depth bands in imperial:** convert the band edges for display, as the
  Insights depth chart does; do not re-bucket.

## What is removed

`HeroHeader`, `HeroDiverAvatar` (its switcher behaviour moves to the header
pill), `GaugeStrip` as a card (its logic moves to the status lights),
`QuickActionsCard`, `MilestonesCard`, `YearInReviewCard`, the lead-and-side
and photo-pair layout rules, and any provider or translation string left
without a user.

## Accessibility and translations

- Every panel has a semantic label that states its title and its headline
  value, so a chart is never the only carrier of a number.
- Status is never shown by colour alone.
- All new strings go in all 11 ARB files.

## Testing

- Layout function: unit tests that every row's units fill the width for every
  preset at every tier, and for randomised subsets and orders of panels.
- Presets: each preset's list contains only known panels, with no duplicates.
- Upgrade: old hidden set carries over only for surviving panels; old keys are
  not written.
- Header: switcher absent with one diver and present with two; safety lights
  render even when their chip is hidden; every light is tappable and its
  destination resolves in the real router (extend the existing list in
  `app_router_test.dart`).
- Panels: each renders its loading, empty, error and data states at phone and
  desktop width without overflow, in metric and imperial.
- Page: no hidden panel's provider is read; the all-hidden state still shows.

## Left to the builder

- Exact pixel sizes, paddings and type roles, within the approved mockup.
- Which existing chart widgets to reuse and which to draw fresh at this size.
- File layout under `lib/features/dashboard/presentation/` (one file per
  panel is expected).
- The exact Insights destination for each trend panel.
- The order of work.

## Mockups

The approved mockups are kept, untracked, under `.superpowers/brainstorm/` in
the working tree used for this design (`home-final.html` is the final one).
Screenshots of the built page go in the pull request.
