# Fullscreen profile phone readout close-button clearance

Date: 2026-08-11
Branch: `codex/fix-phone-profile-readout-close`

## Problem

In the phone fullscreen dive-profile view, the draggable metric readout can
occupy the upper-left corner and cover the close button in the chart legend.
This happens for both automatic and persisted placement:

- `leastOccupiedReadoutCorner` deliberately selects the upper-left corner for
  common profiles whose descent leaves that corner relatively empty.
- A previously saved card position can also restore at `(0, 0)`.
- `DraggableReadoutCard` is painted after `DiveProfileChart` in the enclosing
  `Stack`, so its card and hit target sit above the legend's close button.

The result is a fullscreen view that can hide its primary exit control.

## Goals

- Keep the close button visible and tappable on phone fullscreen profiles.
- Apply the protection to automatic, persisted, and user-dragged readout
  positions.
- Preserve the readout's horizontal placement and the existing fractional
  position model.
- Keep desktop and tablet layout behavior unchanged.

## Non-goals

- Changing dive metric values, formatting, units, or readout contents.
- Changing how the least-occupied corner is selected.
- Moving the close button or adding a permanent header outside the chart.
- Changing the inline dive-profile chart or fullscreen transport behavior.

## Considered approaches

### Reserve the phone header area for controls (selected)

Give `DraggableReadoutCard` a configurable outer inset and pass a larger top
inset from `FullscreenProfilePage` on phones. The card remains draggable over
the chart but cannot enter the close/title row.

This handles automatic and saved `(0, 0)` positions without mutating stored
settings. It also prevents a later drag from recreating the overlap. The chart
keeps its current full-screen dimensions because only the floating card's
movement arena changes.

### Exclude upper-left from automatic corner selection

This is smaller but incomplete. Persisted upper-left positions would still
cover the close control, and users could drag the card back over it.

### Paint the close button above the readout

This keeps the button tappable but leaves the button and metric content
visually overlapping. It fixes z-order rather than the layout conflict.

## Design

### Readout placement contract

`DraggableReadoutCard` gains an optional `EdgeInsets` placement inset. Its
default remains the existing uniform 12 px inset, preserving every current
caller and widget test.

The inset defines the card's movement arena. Alignment and drag calculations
continue to use fractional coordinates within that arena:

- `(0, 0)` is the arena's top-left.
- `(1, 1)` is the arena's bottom-right.
- Out-of-range and non-finite positions retain their current sanitization.

`FullscreenProfilePage` passes
`EdgeInsets.fromLTRB(12, 56, 12, 12)` on phones. The 56 px top edge clears the
compact 40 px close/title row plus the chart's 4 px outer padding and leaves a
12 px gap. Desktop and tablet pass no override and therefore keep the uniform
12 px behavior.

Saved settings are not rewritten. A saved `(0, 0)` remains `(0, 0)`, but on a
phone it maps to the safe arena below the controls; on desktop it continues to
map to the historical 12 px top inset.

### Data flow and error handling

The change affects layout only. Tooltip rows continue to flow from
`DiveProfileChart.onTooltipData` into `DraggableReadoutCard`, and drag-end
fractions continue to persist through `SettingsNotifier`.

If the available height is unusually small, the existing constrained layout
and clamped drag math remain authoritative. No new storage migration, provider,
or asynchronous error path is introduced.

## Test plan

Use the existing phone `MediaQuery` convention in
`fullscreen_profile_page_test.dart`.

- Add a failing phone regression using the existing profile shape that
  automatically selects upper-left. Assert the readout's top is below the
  close button's bottom and that tapping close pops the page.
- Add a phone regression with a persisted `(0, 0)` position and assert the same
  clearance.
- Add focused `DraggableReadoutCard` coverage showing that a custom top inset
  changes the movement arena while the default 12 px behavior remains intact.
- Run the focused fullscreen/readout tests, formatting, analyzer, and the
  broader test suite appropriate to the changed files.

## Baseline note

The fresh worktree baseline completed with 17,285 passing tests and 17 skipped
tests. One unrelated architecture test already fails on `main` because
`speciesSightingCountsProvider` reads `sightingCountsBySpecies()` without a
change-tick subscription. This pre-existing failure is outside this fix's
scope and will be reported separately from the fullscreen verification.
