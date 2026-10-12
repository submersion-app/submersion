# Nav shortcuts: deep-linked pages on the main nav

Issue: #2936

## Problem

Pages a diver uses often can sit two or three hops below a top-level nav
destination. Reaching the Trimix blender takes Planning, then Gas
calculators, then Blender (plus a More hop on phone when Planning is not in
the bottom bar). The diver wants that page on the main nav itself: the left
rail on wide windows, the bottom bar or its More sheet on phone.

## What exists

Settings > Appearance > Navigation (`NavCustomizationPage`,
`NavOrderEditor`) arranges two independent orders, one per surface:

- `nav_primary_ids` (phone): the first N ids are bottom-bar slots, the rest
  is the More sheet.
- `nav_rail_ids` (desktop rail): the whole list, below the pinned Home.

Each order is the complete list of the 16 movable built-in destinations
(`kNavDestinations`). `normalizeNavOrder` guarantees every built-in appears
exactly once, so built-ins can be reordered but never removed. Both orders
are device-local since #2947.

## Decisions

| Question | Decision |
| --- | --- |
| How a diver picks a shortcut | A curated catalog in Navigation settings, not "pin this page" |
| Catalog scope | Planning tools, Insights pages, in-section views, settings and utilities |
| Surfaces | Per surface: adding on the Phone tab does not touch the Desktop rail |
| Where a new shortcut lands | Right after Home (phone: first bar slot) |
| Highlight | The most specific match on the surface wins |
| Back from a shortcut's page | Top level: no back arrow, system Back goes to the dashboard |
| Mechanism | An alias route, `/shortcut/:id`, that builds the page as a one-page stack |

## Catalog

`lib/shared/widgets/nav/nav_shortcuts.dart` holds `NavShortcut` metadata:

- `id`: stable kebab-case id, unique across the catalog.
- `group`: `planning`, `insights`, `views` or `settingsAndTools`.
- `icon`, `selectedIcon`.
- `label`: the page's localized name, as the picker lists it ("Trimix
  blender").
- `navLabel`: a shorter localized name for the nav itself ("Blender"), set on
  the 14 entries whose `label` is wider than the widest built-in nav label
  ("Certifications"), so no shortcut wraps in a bottom-bar slot. The rail,
  the bar, the More sheet and the editor rows (which preview the nav) use it;
  the picker keeps the full name with the parent beneath it.
- `parentLabel`: the localized label of the page's immediate parent, shown
  as a subtitle ("Gas Calculators" for the blender, "Planning" for the deco
  calculator). A single existing label needs no separator, so right-to-left
  locales need nothing special.
- `canonicalPath`: the page's real location, for highlight.
- `selection`: optional desktop selection form, a path plus one query
  parameter (`/planning/gas-calculators` with `calc=blender`), for highlight.
- `isPlanning`: whether the page sits behind the Planning disclaimer gate.

Page builders live router-side in `lib/core/router/nav_shortcut_pages.dart`,
a map from shortcut id to a builder. The metadata file then imports no
feature pages, and builders can reach router-private widgets such as the
import wizard route. A test asserts the two key sets are equal.

Entries (39):

| Group | Id | Canonical path | Desktop selection |
| --- | --- | --- | --- |
| Planning | `dive-planner` | `/planning/dive-planner` | none (always full page) |
| Planning | `deco-calculator` | `/planning/deco-calculator` | `/planning?tool=deco-calculator` |
| Planning | `gas-calculators` | `/planning/gas-calculators` | none (always full page) |
| Planning | `weight-calculator` | `/planning/weight-calculator` | `/planning?tool=weight-calculator` |
| Planning | `surface-interval` | `/planning/surface-interval` | `/planning?tool=surface-interval` |
| Planning | `no-fly` | `/planning/no-fly` | `/planning?tool=no-fly` |
| Planning | `cns-otu` | `/planning/cns-otu` | `/planning?tool=cns-otu` |
| Planning | `gas-mod`, `gas-best-mix`, `gas-consumption`, `gas-rock-bottom`, `gas-mnd`, `gas-icd`, `gas-density`, `gas-blender` | `/planning/gas-calculators/<calc>` | `/planning/gas-calculators?calc=<calc>` |
| Insights | `insights-overview`, `insights-gas`, `insights-progression`, `insights-conditions`, `insights-social`, `insights-geographic`, `insights-marine-life`, `insights-time-patterns`, `insights-equipment`, `insights-profile`, `insights-observations` | `/insights/<page>` | `/insights?selected=<page>` |
| Insights | `records` | `/records` | none |
| Insights | `connections` | `/insights/connections` | none |
| Views | `sites-map` | `/sites/map` | none |
| Views | `dive-activity-map` | `/dives/activity` | none |
| Views | `dive-centers-map` | `/dive-centers/map` | none |
| Views | `equipment-sets` | `/equipment/sets` | none |
| Views | `certification-wallet` | `/certifications/wallet` | none |
| Settings and tools | `emergency-card` | `/settings/diver-profile/emergency-card` | none |
| Settings and tools | `diver-profile` | `/settings/diver-profile` | none |
| Settings and tools | `cloud-sync` | `/settings/cloud-sync` | none |
| Settings and tools | `backup` | `/settings/backup` | none |
| Settings and tools | `offline-maps` | `/settings/offline-maps` | none |
| Settings and tools | `import-wizard` | `/transfer/import-wizard` | none |

Dives "Explore" and Insights "Focus" are left out: the first is a retired
redirect, and the second needs a finding to show.

Labels reuse existing localized strings wherever one already names the page
(calculator tab titles, Insights page titles, settings tile titles). New
strings: the group headers, "Add shortcut", the picker title and search hint,
and the remove tooltip.

## Storage

Shortcuts live inside the existing per-surface order lists as prefixed ids:
`shortcut:gas-blender`. One list keeps a shortcut's position handled exactly
like a built-in's, so the reorder editor and the bar/More split need no
second list.

`normalizeNavOrder` changes:

- A stored `shortcut:<id>` is kept, in stored position, when the catalog
  knows `<id>`. Unknown shortcut ids are dropped. Duplicates keep their first
  position.
- Missing shortcuts are never appended. Built-ins are still all guaranteed.

Compatibility: the orders do not sync, so only this device reads them. An
older build reading a list with `shortcut:` ids drops them as unknown, which
loses the shortcuts after a downgrade and leaves the built-in nav intact.
`withLegacyNavIds` passes shortcut ids through unchanged.

## Settings UI

On each surface's editor in `NavOrderEditor`:

- **Add shortcut** button beside Reset. It opens a picker: a bottom sheet on
  phone, a dialog on wide windows. The picker has a search field (matching
  label and parent label) and the catalog grouped under headers: Planning,
  Insights, Views, Settings and tools. Entries already on this surface show a
  check and are disabled. Choosing one inserts it at index 0 of the movable
  list (right after Home) and closes the picker.
- **Shortcut rows** look like built-in rows (icon, label, up and down arrows,
  drag handle) with the parent label as subtitle and an extra remove button.
  Built-in rows stay non-removable.
- **Reset to defaults** restores the canonical order and removes the
  surface's shortcuts. It is enabled whenever the list differs from the
  default, which includes having any shortcut.
- Add and remove use the editor's existing optimistic update, rollback and
  save-error snackbar.

## Routing

A new shell route, `/shortcut/:id`, inside the main `ShellRoute`:

- Builds the entry's full-page widget from `nav_shortcut_pages.dart`, inside
  `PlanningDisclaimerGate` when `isPlanning` is true, as a `NoTransitionPage`
  like the other top-level destinations.
- Redirects an unknown id to `/dashboard`.

The route has no parent route, so go_router builds a one-page stack: the
page's app bar shows no back arrow. `resolveUpLocation` maps any
`/shortcut/...` location (and its drill-down query parameters, which unwind
first as today) to the dashboard, as for every other top-level tab.

Hub entries keep their own navigation on the alias. `MasterDetailScaffold`
builds its links from the current path, so the Gas calculators hub at
`/shortcut/gas-calculators` selects a calculator as
`/shortcut/gas-calculators?calc=mod`.

## Rendering

`navShortcutDestination(NavShortcut)` turns an entry into a `NavDestination`
whose route is `/shortcut/<id>` and whose label, icons and subtitle come from
the entry. The phone primary/overflow providers and the rail provider resolve
`shortcut:` ids through it, so the rail, the bottom bar and the More sheet
render shortcuts with their existing widgets. The More sheet shows the
parent label as the subtitle.

## Highlight

Each `NavDestination` gets a match score for a location (0 means no match):

- Built-ins: the route as a segment-aware path prefix (`/dives` matches
  `/dives/42` but not `/dives-x`). Score is the matched segment count.
- Shortcuts: the alias path, the canonical path as a segment-aware prefix,
  and the desktop selection form (path equal and query parameter equal).
  Each match scores above any built-in match of the same section, so a
  shortcut beats its section.

`MainScaffold._calculateSelectedIndex` scores the whole surface: the rail on
wide windows, the bar plus the overflow on phone. The best score wins. On
phone, a winner in the overflow selects More. With no match, the rail selects
Home and the bar selects More, as today.

## Error handling

- A stored shortcut the catalog no longer knows is dropped by normalization.
- `/shortcut/<unknown>` (a stale bookmark or hand-edited URL) redirects to
  the dashboard.
- A failed save while adding, removing or resetting rolls the editor back
  and shows the existing save-error snackbar.

## Testing

- Unit: `normalizeNavOrder` with known, unknown and duplicate shortcut ids and
  no appending; `withLegacyNavIds` pass-through; match scoring (segment-aware
  prefixes, shortcut beats section, selection form); `resolveUpLocation` for
  `/shortcut/...`.
- Catalog: unique ids, metadata and builder key sets equal, every builder
  returns its canonical page (checked by type, without pumping pages that
  need the database).
- Widget, editor: Add shortcut inserts after Home, the picker disables
  entries already added and filters by search, remove works, Reset clears
  shortcuts.
- Widget, scaffold: a shortcut in the bar highlights on its alias and
  canonical locations; one in More highlights More; tapping a shortcut leaves
  a one-page stack with no back arrow.

## Out of scope

- Pinning arbitrary pages or specific records (a given trip or site).
- Hiding built-in destinations.
- Syncing shortcuts across devices (the orders are device-local by design).
