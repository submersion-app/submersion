# Edit Form Chrome Redesign

**Date:** 2026-07-17
**Status:** Approved (design freeze)
**Mockup:** [assets/2026-07-17-edit-form-chrome-redesign-mockup.html](assets/2026-07-17-edit-form-chrome-redesign-mockup.html)
**Predecessor:** [2026-06-11-edit-form-redesign-design.md](2026-06-11-edit-form-redesign-design.md) (PR #317/#388 cluster)

## Problem

The June 2026 edit-form redesign left the dive edit and site edit pages
half-migrated and with structural chrome flaws. User-reported pains:

1. Section titles are small floating uppercase labels with too little
   contrast; sections are hard to discern, especially in light themes.
2. Collapsed sections render as plain data rows and do not look expandable.
3. The expand/collapse affordance moves between states: the chevron sits on
   the heading row when expanded but on the summary/data row when collapsed.
4. Two input languages coexist: dive core sections use flat `FormRow` rows
   while the entire site form and the dive Conditions/Weather interiors use
   outlined Material text fields with per-field icons.
5. The tank card is oversized (three hero stat cells for one tank), its
   gray name strip looks bolted on, and its hierarchy is inverted
   (numbers first, identity in a footnote).
6. Hero `StatStrip` cells (Conditions temps/visibility, site min/max depth)
   are visually louder than every other piece of data on the form.
7. Empty states are heavy (large icon plus two lines of text).
8. In-section actions use several styles (centered text button, toolbar
   buttons, pill button).
9. Sub-headers inside sections (Dive Mode, Equipment, Weight) have unclear
   hierarchy relative to section titles.

## User-validated decisions

- Collapsible sections stay; the chrome around them is rebuilt.
- Chrome model: **header-in-card** (chosen over amplified floating labels
  and a flat sectioned list).
- Input language: **flat `FormRow` rows everywhere** on both pages.
- Hero `StatStrip` cells are **flattened to rows** on both pages; the dive
  detail view remains the place for showcase stats.
- Tanks render at **row scale, identity first**.
- Scope: dive edit + site edit + the shared primitives they use. Other edit
  pages remain follow-up work, unchanged by this project.

## Design

### 1. `FormSection` v2 — header-in-card

Every section is a single tonal card whose first row is a permanent header.
The header keeps one anatomy in all states; only its trailing content varies.

Header anatomy, left to right:

- Leading icon, 18 px, tinted `primary` (tank for Gas & Gear, waves for
  Conditions, plane for Trip, people for Buddies, star for Experience,
  bookmark for Identity, pin for Location, info for Dive Info, shield for
  Access & Safety, book for Life & Notes, pulse for The Dive).
- Title, ~15.5 px semibold, full `onSurface` color.
- Trailing area by state:

| State | Trailing content | Body |
|---|---|---|
| Expanded | collapse chevron | rows below a hairline divider |
| Collapsed, has data | muted summary + chevron | none |
| Collapsed, empty | fainter invitation text + chevron | none |
| Collapsed, has errors | error-colored "N issues" + chevron; error-tinted card edge | none |

- Always-open sections (The Dive, Identity) render the identical header
  with no chevron and no tap handler.
- The whole header row is the toggle tap target and carries the semantics
  of a section control (announced as e.g. "Gas & Gear, collapsed, button").
- The floating uppercase label outside the card is removed.

Expansion motion: the header persists; only the body animates open/closed
beneath it (clipped `AnimatedSize`, ~200 ms). Because both states share the
header subtree, nothing jumps or swaps.

Card surface: tonal fill (`FormStyle.groupColor`) plus a hairline
`outlineVariant` border so sections separate cleanly in light themes.
Radius stays `FormStyle.groupRadius` (13).

API sketch: `FormSection` gains `icon`; `title` moves inside the card;
`summary`, `emptyInvitation`, `errorCount`, `expanded`, `onToggle` keep
their roles (`onToggle: null` = always open). Expansion state remains
page-owned.

### 2. One row language

The `FormRow` family becomes the only field primitive on both pages.

Site form migration (every field changes):

- Name, Description, Country, Region, City, Island, Body of water, access
  and safety text fields, notes: `FormRow.text`. Multi-line fields grow
  while editing. Per-field prefix icons are removed.
- Autocomplete suggestions (country/region/city, similar-site name hints)
  are preserved, rendered attached beneath the active row.
- Name keeps required validation, surfaced as an error line under the row
  and counted in the section error badge.
- Difficulty becomes a row: label left, choice chips right. Rating becomes
  a row with the shared 22 px stars (the 32 px site stars are removed).
- GPS: Latitude and Longitude become text rows; "Use my location" and
  "Pick from map" become one compact action row; Altitude is a row below.

Dive form completion:

- Conditions: Visibility, Water type, Current direction/strength, Swell,
  Entry/Exit method, Altitude, Surface pressure move to `FormRow.picker`
  (enums, reusing today's sheets/menus) or `FormRow.text` (numerics with
  unit suffix).
- Weather: Humidity, Wind, Cloud cover, Precipitation, Description move to
  rows; the fetch action docks to the Weather overline.
- Water temp, Air temp, Visibility, and site Min/Max depth become ordinary
  rows; `StatStrip` is removed from both pages.
- Dive-type multi-select chips stay chips, presented in row format.

Validation constraint: a collapsed `FormSection` un-mounts its body, so
`Form.validate()` cannot see fields inside collapsed sections. All
hard-required, validated fields must live in always-open sections (today
that is only site Name, in Identity). Collapsible sections may only carry
soft issues, surfaced through the header error badge.

Composite interiors (buddy list, marine-life sightings, tags, equipment
list) keep their existing widgets and flows, restyled to row scale where
they diverge: entries render as rows, list-append actions use the append
row pattern, and selection sheets/pickers open unchanged.

No behavior changes: picker sheets, suggestion providers, validators, save
paths, controllers, and state management are untouched. This is a re-skin
of the field layer.

### 3. Components

**Tanks.** Each tank is a two-line row: title "Tank 1 - Back Gas"
(identity first), muted subtitle "Air - 11 L - 200 -> 50 bar", trailing
chevron. Tapping the row opens the existing tank editor; the separate Edit
button is removed. `TankCard` is replaced by this row widget.

**Sub-headers.** Groups inside a section (Tanks, Equipment, Weight,
Weather) use one overline style: ~10.5 px bold, letter-spaced uppercase,
muted color. The site form's inner icon+title headers are deleted; its
fields are self-labeled rows. "Dive Mode" stops being a header and becomes
a row: label left, OC/CCR/SCR segmented control right.

**Actions — exactly two patterns.**

1. Overline-docked text actions: plain accent text buttons on a
   sub-header's trailing edge (Equipment: "Use set", "+ Add";
   Weather: "Fetch").
2. Append rows: full-width accent rows ("+ Add tank", "+ Add buddy",
   "+ Add: Training course - Custom fields").

The "Edit Profile" pill becomes a row ("Dive profile - 1,719 points >")
opening the same editor.

**Empty states.** One muted line ("No equipment yet"). No icon, no
instruction paragraph; the relevant actions are already visible on the
overline.

### 4. Scope and structure

- `lib/shared/widgets/forms/form_section.dart`: rewritten for v2 chrome.
- `lib/shared/widgets/forms/stat_strip.dart`: usage removed from both
  pages; delete the widget if nothing else uses it.
- `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart`:
  replaced by the tank row widget.
- `site_edit_page.dart` (~2,300 lines, sections inline): sections extracted
  into `lib/features/dive_sites/presentation/widgets/edit_sections/` files
  mirroring the dive form's structure.
- Dive Conditions/Weather slot builders move onto rows (and out of
  `dive_edit_page.dart` where practical).
- Site merge mode and dive bulk mode keep force-all-open behavior and
  their existing semantics.
- All six themes verified light + dark.
- New/changed strings localized in all locales; `dart format .` clean.

### 5. Testing

- `FormSection` widget tests rewritten for the new anatomy (header always
  present; body un-mounted when collapsed — the existing test trap where
  collapsed children are `findsNothing` still applies).
- `FormRow` tests extended for any new variants (suggestion attachment,
  chip/segmented rows) rather than duplicated.
- Page-level tests updated: expansion before interacting with section
  fields; tall viewports (~`Size(900, 3200)`) for lazy list builds.
- Migration-sensitive suites: site merge tests, bulk dive edit tests,
  dive edit coverage harness.

## Out of scope

- The other ~18 edit pages (migrate later onto the v2 primitives).
- Picker sheets, suggestion providers, save/validation logic, providers.
- Dive detail / site detail views (heroes live there intentionally).
- New fields or data model changes.

## Deviations (recorded during implementation, 2026-07-17)

- `FormRow.text` editing state also became row-shaped (label stays, bare
  inline field on the right) rather than only the resting state; rows with
  validators are therefore fully row-styled while staying mounted.
- Site rating: the 32px stars' per-star tooltips and the "Clear rating"
  text button were replaced by the shared 22px rating row with a small
  clear icon (`FormRow.rating.onClear`).
- Helper texts removed with the quiet design: GPS format helper, altitude
  helper, hazards helper, surface-pressure helper (+ its prefix icon),
  and the marine-life helper/merge-helper lines. The surface-pressure
  default remains as the row placeholder.
- Site min/max depth rows reuse the existing `diveSites_edit_depth_minLabel/
  maxLabel(symbol)` keys, so the unit appears in the label instead of as a
  suffix; the altitude row uses the plain `diveSites_edit_section_altitude`
  label with a unit suffix (the `altitude_label(symbol)` key is no longer
  referenced by this page).
- Merge mode's separate boxed depth-range editor was removed: min/max
  depth rows are identical in normal and merge modes, with per-field
  source caption + cycle button.
- The bulk form's `_bulkTanksEditor` also moved to `TankRow` (same
  parameter surface); bulk interiors otherwise keep their existing field
  styles and only inherit the v2 chrome, as scoped.
- `StatStrip` was retained as a widget (trip-story consumers); only its
  edit-form usage was removed. `FormStyle.labelStyle`/`labelGap` tokens
  were deleted (no remaining consumers).
- l10n bonus: the profile block's hardcoded English strings ("Dive
  Profile", "Edit Profile", "Draw Profile", the outlier chip) were
  replaced with new localized keys in all 11 locales.
