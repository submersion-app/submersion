# Standardizing Item Selection

Date: 2026-08-11
Status: Approved design, ready for implementation planning

## Problem

Entering multi-select requires a long-press on almost every list in the app. Nothing
on screen suggests it, so the bulk actions behind it are effectively undiscoverable.
Dives has the richest bulk vocabulary in the app -- combine, compare in 3D, export,
bulk edit, delete, select by date range -- and long-press is the only way to reach
any of it.

The inconsistency runs deeper than the entry point. Five surfaces support
multi-select; each re-implements the same state machine in local `setState`, and the
implementations have drifted:

| Surface | File | Enter | Bulk actions |
| --- | --- | --- | --- |
| Dives | `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | long-press only | combine, compare 3D, export, bulk edit, delete, by date range |
| Sites | `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | long-press or overflow "Select" | merge, delete |
| Buddies | `lib/features/buddies/presentation/widgets/buddy_list_content.dart` | long-press only | merge, delete |
| Tags | `lib/features/tags/presentation/pages/tag_manage_page.dart` | long-press only | merge, delete (no select-all at all) |
| Dive media | `lib/features/media/presentation/widgets/dive_media_section.dart` | long-press | unlink |

Roughly ten further list surfaces have no multi-select at all, including Trips and
Equipment. Courses and Certifications hard-code `selectedIds: const {}` and
`isSelectionMode: false` into their table views, so the plumbing exists and is
switched off.

### Specific defects the current state produces

- No Escape binding. `lib/core/accessibility/app_shortcuts.dart` lists
  "Close / Cancel -- Esc" in the shortcuts help dialog, but `globalBindings()`
  never binds it.
- No `PopScope` on any selection surface, so Android back pops the route instead of
  leaving selection mode.
- `dive_list_content.dart:1308` passes an empty list to `_buildSelectionBar`, so in
  dive table mode the select-all icon silently disappears and select-by-date-range
  selects nothing.
- Sites enters selection mode from its overflow menu with zero items checked, then
  auto-exits at zero selection, so the explicit entry point immediately undoes
  itself.
- `isSelected` means the checkbox on dive tiles and the master-detail highlight on
  `SiteListTile` / `BuddyListTile`, while compact and dense site/buddy tiles use
  `isSelected` for the checkbox and `isHighlighted` for the highlight.
- Merge is drawn with `Icons.merge_type` on sites and buddies, `Icons.merge` on
  tags, and `Icons.call_merge` for dive combine -- three icons, one concept.
- Selection keys are `Set<String>` of IDs everywhere except dive media and
  `DragSelectGridView`, which use `Set<int>` of indices, forcing index/ID
  conversion in `photo_picker_page.dart`.
- `TableModeLayout` declares a complete selection API (`isSelectionMode`,
  `selectedIds`, `onSelectionChanged`, `selectionAppBar`) that no caller passes.
- `codemaps/frontend.md:234` describes `lib/shared/providers/selection_providers.dart`
  as "Selection state for multi-select operations". It is single-selection only.
- `DenseDiveListTile` is referenced only by tests; `DiveListItem` routes
  `ListViewMode.dense` to `DiveListTile`.

## Goals

Make selection discoverable and identical across every list and grid in the
application, and collapse the duplicated implementations into one shared component
set.

Non-goals: per-row swipe actions, per-row context menus, and drag-to-select in
list (as opposed to grid) views. The existing `DragSelectGridView` grid behavior is
retained as-is.

## Interaction contract

This contract applies to every selectable surface without exception.

### Pointer and keyboard

| Input | Not in selection mode | In selection mode |
| --- | --- | --- |
| Tap | Open the item (list modes); highlight, with double-tap to open (table mode). Unchanged from today. | Toggle checked |
| `Select` icon button | Enter mode, nothing checked | n/a (button is replaced by the contextual bar) |
| Long-press | Enter mode, check that row | Toggle checked |
| Ctrl/Cmd-click | Enter mode, check that row | Toggle checked |
| Shift-click | Enter mode, check the range from the highlighted row to the clicked row; if no row is highlighted, check only the clicked row and make it the anchor | Extend the range from the anchor to the clicked row |
| Escape | no-op | Exit selection mode |
| Ctrl/Cmd-A | Enter mode, check all | Check all |
| Android back | Pop the route | Exit selection mode without popping |

Shift-click anchoring follows Finder and Explorer: the anchor is the currently
highlighted row when one exists, which in master-detail layouts is nearly always
the row open in the detail pane.

### Mode entry and exit

Entry is either **explicit** (the `Select` button, Ctrl/Cmd-A) or **implicit**
(long-press, Ctrl/Cmd-click, Shift-click).

- Implicit entry auto-exits when the last item is unchecked.
- Explicit entry persists at "0 selected" until the user exits deliberately.

The controller records which kind of entry occurred. This resolves the sites bug
where an explicit "Select" is immediately undone by the zero-selection auto-exit.

### The `Select` affordance

A dedicated icon button in the surface header, immediately to the left of the
overflow menu. It is not an overflow menu item: discoverability is the point of
this work, and burying the entry point in `...` only half-solves it.

### Pruning to what is visible

When the visible (filtered, searched, sorted) item set changes, any checked IDs no
longer present are dropped from the selection. The count therefore always matches
what is on screen, and a bulk delete can never act on a record the user cannot see.

Search and filter controls remain visible below the contextual bar during selection,
so narrowing the list mid-selection is a supported workflow rather than a hazard.

Selection does not survive leaving the surface.

### Non-selectable rows

Some rows cannot be acted on: built-in reference species, cylinder configurations
referenced by a dive, service kinds referenced by a ledger entry. Each surface
supplies a predicate identifying them. Non-selectable rows keep their leading
element, render no checkbox, and are excluded from select-all and from range
extension.

This mirrors `disabledIndices` in the existing `DragSelectGridView`.

## Visual design

### Selection chrome placement

The surface header transforms in place into a contextual bar carrying the exit
control, the count, and the actions.

In master-detail layouts the **pane header** transforms, not the window chrome. The
detail pane keeps its own app bar and remains interactive throughout.

"Surface header" means whichever header the selectable collection already owns. For
a full-screen list that is its `AppBar`; for a master-detail list it is the pane
header; for an embedded collection such as the dive media section it is that
section's own header row, which transforms in place while the surrounding dive
detail page is left untouched.

Rejected alternatives: a docked bottom action bar (phones already carry a persistent
`NavigationBar` from `main_scaffold.dart:295` plus a FAB, so this produces four
stacked bands and splits selection state between the top and bottom of the screen),
and a floating action pill (occludes list rows, requires bottom scroll padding on
every surface, and is not a Material 3 idiom).

### Checked row appearance

In selection mode the row's leading element -- dive number badge, site or buddy
avatar, gear icon -- is replaced by a checkbox. The swap is animated with an
`AnimatedSwitcher` so entering and leaving the mode does not jolt the list.

### Two independent visual channels

Checked and highlighted are distinct states that can apply to the same row
simultaneously, and must render on different channels:

- **Checked**: background fill tint plus the leading checkbox. Means "in my bulk
  selection."
- **Highlighted**: leading edge stripe. Means "showing in the detail pane."

The shared tile API replaces the overloaded `isSelected` with `isChecked` and
`isHighlighted`. Migrating every existing tile to the new names is expected to
surface places where the wrong state is currently passed.

## Bulk action vocabulary

Every selectable surface gets a guaranteed baseline, in a fixed order and position,
injected by the shared app bar itself:

1. Select all
2. Deselect all
3. Delete

Each surface then declares opt-in extras, which render in a standard slot:

| Surface | Extras |
| --- | --- |
| Dives | merge (combine), export, bulk edit, compare in 3D, select by date range |
| Sites | merge, export |
| Buddies | merge |
| Tags | merge |
| Dive media | unlink |
| All others | baseline only |

There is exactly one icon and one localization key per concept across the app. The
three merge icons collapse to one; dive "combine" adopts the shared merge icon.

Actions render as icons up to the available width, with the remainder in an
overflow menu. Which actions overflow is width-driven and may therefore differ
between the full-width and pane-width shells, but the action *set* and its
*ordering* are computed once and are identical in both -- unlike today, where the
dives pane variant hard-codes a different, smaller set that permanently demotes
combine, compare, and export regardless of available width.

## Architecture

New package: `lib/shared/selection/`

| File | Responsibility |
| --- | --- |
| `selection_state.dart` | Immutable state: `checkedIds`, `isActive`, `enteredExplicitly`, `anchorId` |
| `selection_controller.dart` | `ValueNotifier<SelectionState>` exposing `enterExplicit`, `enterImplicit`, `toggle`, `extendTo`, `selectAll`, `deselectAll`, `exit`, `pruneTo` |
| `bulk_action.dart` | `BulkAction`: id, icon, label, `minCount`, `isDestructive`, `invoke` |
| `selection_app_bar.dart` | One content builder, two shells: `AppBar` when the surface owns the window chrome, a pane `Container` otherwise |
| `selection_leading.dart` | `AnimatedSwitcher` between the leading element and a `Checkbox` |
| `selectable_list_scope.dart` | `Shortcuts`/`Actions` for Escape and Ctrl/Cmd-A, `PopScope` for Android back, and prune wiring |

### Why a `ValueNotifier` rather than Riverpod

Selection prunes to the visible set and does not survive navigation, which makes it
ephemeral view state rather than application state. A `ValueNotifier` is testable
without a `ProviderContainer` and avoids introducing a provider family whose only
job is to be disposed. The codebase supports both readings today -- five surfaces
use `setState`, the photo picker uses a Riverpod notifier -- so this is a
deliberate choice of the simpler one.

### How the duplication collapses

Every selection surface currently maintains two hand-written bar builders selected
by a `showAppBar` boolean -- ten near-duplicate builders across five pages. A single
content builder rendered into one of two shells removes that branch, and with it the
drift between the two variants.

Selection keys are `Set<String>` of entity IDs on every surface. Grid surfaces
convert at their boundary rather than propagating index-based selection.

## Rollout

| Phase | Scope |
| --- | --- |
| 1 | Build `lib/shared/selection/` and its tests. No existing page modified. |
| 2 | Convert Dives. Richest action set, so it proves the API. Fixes the empty-list defect at `dive_list_content.dart:1308`. |
| 3 | Convert Sites, Buddies, Tags, Dive media. Largely deletion of duplicated code. |
| 4 | Extend to Trips, Equipment, Courses, Certifications, Dive centers. Table plumbing exists; needs wiring plus a delete action. |
| 5 | Extend to Devices, Service kinds, Cylinder configs, Species, Media storage. Baseline actions only; exercises the non-selectable predicate. |
| 6 | Cleanup, detailed below. |

Phases 4 and 5 cover ten surfaces of largely mechanical work. If the implementation
plan becomes unwieldy, they are to be split into a second plan rather than padding
the first.

### Phase 6 cleanup

- Wire or delete the unused selection API on `TableModeLayout`.
- Delete `DenseDiveListTile` and its tests (dead code; `DiveListItem` routes dense
  to `DiveListTile`).
- Correct `codemaps/frontend.md:234`, which mislabels `selection_providers.dart`.
- Add the missing Escape binding to `globalBindings()` in
  `lib/core/accessibility/app_shortcuts.dart` so the shortcuts help dialog stops
  advertising a binding that does not exist.

## Error handling

Bulk delete confirms with an exact count before acting.

Where the repository supports it, deletion offers snackbar undo. Sites and buddies
already do this for merge; the pattern extends to delete on surfaces whose
repository can restore.

Partial failures report which items survived rather than a blanket failure message,
and the failed IDs remain checked so the user can retry without rebuilding the
selection.

Destructive actions render disabled, not hidden, when the current selection contains
only non-deletable rows.

## Testing

Unit tests against `SelectionController` cover the state machine directly:

- implicit entry auto-exits at zero; explicit entry does not
- range extension across an anchor, in both directions
- `pruneTo` drops checked IDs that leave the visible set
- select-all excludes non-selectable rows
- anchor selection when no row is highlighted

A shared **selection contract test** -- one reusable `testWidgets` helper -- asserts
the full interaction contract against a surface: the `Select` button is present,
tapping it enters the mode, checkboxes render in the leading slot, the count
updates, select-all and deselect-all work, Escape exits, Android back exits,
and changing the filter prunes the selection.

Every selectable surface invokes this helper. One contract, fifteen call sites, so a
regression on any page fails loudly, and adding a sixteenth list costs two lines of
test.

New user-facing strings are added to all 11 ARB locales in `lib/l10n/arb/`.
