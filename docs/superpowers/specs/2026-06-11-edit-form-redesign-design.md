# Edit Form Redesign — Design Spec

Date: 2026-06-11
Status: Approved pending user review
Companion mockup: `assets/2026-06-11-edit-form-redesign-mockup.html` (design-freeze visual)

## Problem

Submersion's edit forms are functional but unconsidered. The dive edit page is
4,909 lines rendering 18 flat Card sections in a single scroll; every dive gets
the full wall of sections regardless of relevance. The ~20 edit pages share no
form components, so each hand-rolls its own section chrome, date pickers, and
save flows, and their styles have drifted (Cards on some pages, plain text
headers on others). The user's stated pains, in priority order:

1. Bland visual styling (typography, spacing, section chrome, input look)
2. Poor grouping and ordering of fields
3. Overwhelming length — everything always visible

Explicitly *not* a pain: desktop multi-column layouts.

## Goals

- A shared form design system that makes the forms feel designed, organized,
  and short — and prevents future drift.
- Prove it on the two worst offenders: dive edit and site edit.
- Visual direction: Apple Health calm (inset groups, quiet chrome, tappable
  rows) combined with Strava/Garmin stat-forwardness (hero stat strips where
  numbers are the star).

## Non-Goals

- Migrating the other ~18 edit pages (follow-up phases reuse the primitives).
- Changing detail/view pages, navigation, or routing.
- Desktop multi-column form layouts (a simple max-width constraint is included;
  nothing more).
- Any state-management, database, or domain-model changes. No new dive fields.
- Changing picker sheet internals (site, species, equipment, date/time pickers
  keep their current behavior).

## Decisions (validated with user)

| Decision | Choice |
| --- | --- |
| Scope | Flagship-first: shared primitives + dive edit + site edit now; other pages in follow-up phases |
| Structure | Smart collapse: one scroll, collapsible groups, live summaries in collapsed headers |
| Visual treatment | Hybrid: calm inset chrome (borderless groups, label/value rows) + bold hero stat strips |
| Dive form grouping | 6 groups + rare: The Dive, Gas & Gear, Conditions, Trip, Buddies, Experience; Course + Custom fields behind "+ Add" |
| Site form grouping | Identity, Location, Dive info, Access & safety, Life & notes |

## Architecture

### Shared primitives — `lib/shared/widgets/forms/`

One file per primitive. All presentational: pages keep their existing
`ConsumerStatefulWidget` state, `TextEditingController`s, validators, and
repository save calls.

**`form_style.dart`** — design tokens: group corner radius, row padding, the
uppercase group-label text style, hero-number text style, spacing scale,
content max-width (~640dp, centered on wide windows). Initial values come from
the mockup; tune during implementation.

**`form_section.dart` — `FormSection`** — the collapsible group.

- Anatomy: small uppercase label *outside* the group; rounded tonal surface
  (`surfaceContainerLow`-family, no elevation shadow) containing an optional
  hero slot and the rows.
- Three resting states:
  - *Expanded*: hero + rows visible, collapse affordance in the label row.
  - *Collapsed with data*: single bar showing a live one-line summary
    (e.g. "Salt · 24°C · 15 m vis · mild current"); tap to expand.
  - *Empty invitation*: muted single bar ("Add conditions — water, visibility,
    weather") with a "+" affordance; tap to expand.
- Error state: when collapsed while containing invalid fields, shows a red
  inset edge and "n issues" badge; auto-expands on failed save.
- API sketch: `FormSection({label, isEmpty, summaryBuilder, emptyInvitation,
  hero, children, expanded, onToggle, errorCount})`. Expansion is controlled by
  the page (it owns the defaults logic); the widget stays stateless about it.

**`stat_strip.dart` — `StatStrip` / `StatCell`** — the hero numbers row.

- Big-number cells (value + small unit + uppercase micro-label), separated by
  hairline vertical dividers.
- Editable cells: tap swaps the cell to an in-place numeric editor (autofocus,
  select-all, unit shown per the diver's unit settings); commit on done or
  tap-away; standard validator messaging below the strip.
- Profile affordance: when the dive has profile data and the computed value
  differs, the cell shows a small sync glyph; tapping offers "Use {value} from
  profile". Replaces the per-field calculator suffix icons.
- Display-only cells supported (site form's depth range uses editable cells;
  summaries elsewhere may use display cells).

**`form_row.dart` — `FormRow` variants** — label-left / value-right rows with
hairline dividers between rows.

- `FormRow.text` — tap expands the row inline into a focused `TextFormField`
  (label floats); multiline variant for notes/description grows into a text
  area.
- `FormRow.picker` — formatted value + chevron; `onTap` opens the existing
  picker sheet. Empty state shows a muted placeholder ("Add site").
- `FormRow.display` — muted, non-tappable, for auto-computed values (surface
  interval, runtime-from-profile).
- `FormRow.toggle`, `FormRow.rating` (stars), `FormRow.chips` (tags,
  difficulty), `FormRow.segmented` (dive mode) — thin wrappers keeping the row
  geometry consistent.

**`unit_field.dart` — `UnitField`** — boxed numeric `TextFormField` with unit
suffix from `UnitFormatter`, for dense clusters inside expanded editors (tank
pressures/volumes, weights). Replaces today's scattered hand-built variants.

**`add_section_row.dart` — `AddSectionRow`** — the trailing muted row listing
unused rare sections ("+ Add: Course · Custom fields"); tapping one expands
that section into the form.

**`edit_form_scaffold.dart` — `EditFormScaffold`** — shared page shell.

- Full-page mode: AppBar with title + Save action (spinner while saving).
- Embedded mode (master-detail): compact header with icon, title, Cancel,
  Save — replaces the per-page copy-pasted `_buildEmbeddedHeader`.
- `PopScope` unsaved-changes guard with discard dialog; snackbar feedback on
  save success/failure; centers content at the max content width.
- API sketch: `EditFormScaffold({title, embedded, isSaving, hasUnsavedChanges,
  onSave, onCancel, child})`.

### Dive form regrouping (18 sections → 6 groups + rare)

| Current section | New group |
| --- | --- |
| Dive number | The Dive |
| Date/time (entry, exit, surface interval) | The Dive |
| Site | The Dive |
| Depth & duration (max/avg depth, bottom time, runtime) | The Dive (hero + rows) |
| Profile | The Dive |
| Dive mode | Gas & Gear (`FormRow.segmented`, first row) |
| Tanks | Gas & Gear (tank cards) |
| Equipment | Gas & Gear |
| Weight | Gas & Gear |
| Environment incl. weather | Conditions |
| Trip | Trip |
| Dive center | Trip |
| Buddy | Buddies |
| Rating | Experience |
| Marine life | Experience |
| Notes | Experience |
| Tags | Experience |
| Course | Rare ("+ Add") |
| Custom fields | Rare ("+ Add") |

Group order on the page: The Dive, Gas & Gear, Conditions, Trip, Buddies,
Experience, then any expanded rare sections, then the `AddSectionRow`.

Hero strips:

- The Dive: max depth · bottom time · avg depth (all editable; profile
  affordance when applicable)
- Conditions: water temp · visibility · air temp
- Tank card (one per tank, inside Gas & Gear): pressure start→end · mix ·
  volume, with an "edit" caption row that expands the card inline into the
  full (restyled) tank editor and collapses back to the card on done — no new
  sheets or navigation

CCR/SCR panels appear inside Gas & Gear when the mode requires, exactly as
today's gating logic, restyled with the primitives.

### Site form regrouping

| Current fields | New group |
| --- | --- |
| Name, country/region, description | Identity |
| GPS coordinates, locate/map actions, altitude | Location |
| Depth range, difficulty, rating | Dive info (min/max depth hero) |
| Access notes, parking, mooring, hazards | Access & safety |
| Species, notes, share toggle | Life & notes |

Merge mode keeps its current flow and controls, restyled to the new chrome.

## Interaction rules

**Initial expansion (recomputed on open; user toggles freely; no persistence):**

- New manual dive: The Dive + Gas & Gear expanded; other groups show empty
  invitations.
- Existing/downloaded dive: The Dive expanded; all other groups collapsed to
  live summaries. (Serves the post-download workflow: scan what the computer
  filled, tap Experience/Buddies to add the human parts.)
- Site edit: Identity + Dive info expanded for new sites; Identity only for
  existing.
- Rare sections stay behind `AddSectionRow` until they contain data.

**Validation:** field validators unchanged. On failed save: auto-expand groups
containing errors, scroll to the first invalid field, show the error badge on
any group the user re-collapses while still invalid. No errors are ever hidden
silently.

**Save/cancel:** behavior unchanged, relocated into `EditFormScaffold`.

**Accessibility:** rows and stat cells expose semantics (label, value,
"double-tap to edit" hint); tap targets ≥ 44px; expansion state announced;
focus order is top-to-bottom document order.

## Code organization

```
lib/shared/widgets/forms/            # primitives (one per file, ~100-300 lines)
lib/features/dive_log/presentation/
  pages/dive_edit_page.dart          # thin coordinator: state, controllers,
                                     # load/save, expansion defaults (<~500 lines)
  widgets/edit_sections/             # the_dive_section.dart, gas_gear_section.dart,
                                     # conditions_section.dart, trip_section.dart,
                                     # buddies_section.dart, experience_section.dart
  widgets/pickers/                   # extracted from dive_edit_page.dart:
                                     # site_picker_sheet.dart, species_picker_sheet.dart,
                                     # edit_sighting_sheet.dart, equipment_picker_sheet.dart,
                                     # equipment_set_picker_sheet.dart,
                                     # computer_source_sheet.dart (behavior unchanged)
lib/features/dive_sites/presentation/
  pages/site_edit_page.dart          # thin coordinator
  widgets/edit_sections/             # identity, location, dive_info,
                                     # access_safety, life_notes
```

Section widgets receive the controllers/values they need from the coordinator;
they own no business logic.

## Implementation order

1. **Primitives** — TDD: widget tests in `test/shared/widgets/forms/` for
   collapse states, summaries, empty invitations, error badge + auto-expand,
   stat-cell edit swap + profile affordance, row variants, scaffold guard.
2. **Dive edit rebuild** — extract pickers (mechanical), then rebuild group by
   group on the primitives; restyle tank editor and CCR/SCR panels; update
   `dive_edit_page_test.dart`.
3. **Site edit rebuild** — same pattern incl. merge mode; update
   `site_edit_page_test.dart` and `site_edit_merge_page_test.dart`.
4. *(Follow-up project, out of scope here)* — remaining edit pages adopt the
   primitives.

Each phase ends with `dart format`, full `flutter analyze`, targeted test runs,
and a manual pass on macOS at desktop and phone-sized windows.

## Cross-cutting requirements

- **Units:** every numeric display and input goes through `UnitFormatter`;
  stat cells and summaries show the active diver's units.
- **l10n:** all new strings (group labels, summaries, invitations, badges,
  "Use {value} from profile", add-row labels) land in `app_en.arb` *and all 10
  non-English locales*, with codegen rerun. No English fallbacks.
- **Theming:** tonal `colorScheme` surfaces only (no hard-coded colors); works
  in light and dark; existing `InputDecorationTheme` continues to style boxed
  inputs (`UnitField`, inline-expanded rows).
- **Formatting:** all code passes `dart format` unchanged.

## Risks and mitigations

- **Thin existing test coverage on the 4,909-line page.** Mitigate by building
  primitives test-first, extracting pickers without behavior change, and
  rebuilding one group at a time with manual verification per group.
- **Summary builders touching many fields** could become stale when fields
  change. Mitigate: summaries live next to their section widget and are
  covered by section widget tests.
- **Inline row editing on desktop** (mouse + keyboard) needs the same care as
  touch: ensure focus traversal and Enter/Escape commit/cancel work.

## Follow-up phases (recorded, not in scope)

Remaining pages to migrate later, roughly by size: diver, dive center, trip,
equipment (+ equipment set), buddy, certification, course, tank preset,
species, settings sub-pages (personal info, medical, insurance, emergency
contacts, notes), S3 config. Each becomes a small task once the primitives
exist.
