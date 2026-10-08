# Safety Findings Lane: Chart-Anchored Safety Review Presentation

**Date:** 2026-08-09
**Status:** Approved design, pending implementation plan
**Supersedes:** the interaction model of
`2026-08-07-safety-finding-chart-highlight-design.md` (the highlight rendering
it introduced is retained and extended; its selection/clearing model is
replaced).

## Problem

The safety review presentation has two usability failures, both rooted in the
same structural decision: selection state is written only by the
`SafetyReviewSection` card, which sits below the profile chart and the entire
Deco/O2 panel, one to two viewport heights away from where the selection
renders.

1. **Clearing is unintuitive and requires scrolling.** Tapping a finding tile
   selects it and auto-scrolls the page to the chart. The only clear
   affordances are tapping the same tile again or dismissing the finding, both
   of which require scrolling back down. The chart itself offers no clearing
   interaction (an explicit decision in the prior spec).
2. **Short findings are invisible on the chart.** Two of the five safety rules
   (`omittedSafetyStop`, `highSurfaceGf`) produce zero-width time ranges that
   render as a single 1.5 px dashed line, indistinguishable from the playback
   and hover cursor lines. `rapidAscent` and `missedDecoStop` findings can be
   as short as 10 seconds, rendering as roughly 1 px of 12%-alpha fill on a
   typical dive.

## Design summary

Make the chart a first-class selection surface. A findings lane under the
profile chart holds one tappable chip per finding; tapping a chip highlights
the finding on the chart and opens a callout with summary, Details, Dismiss,
and clear actions. All selection and clearing happens at the chart. The
existing safety section remains as the detailed view with two-way selection
sync. Highlight bands gain a minimum on-screen width so short and instant
findings are visible.

Decisions made during brainstorming (each chosen from mockup alternatives):

| Decision | Choice |
|---|---|
| Primary home of findings | Chart-anchored: findings lane under the plot |
| Marker geometry | Dedicated lane below the plot (GasTimelineStrip idiom), not in-plot badges or top-edge flags |
| Selected state | Callout bubble anchored to the tapped chip |
| Callout actions | Summary text, Details link, Dismiss action, and a clear button |
| Existing section | Kept as detail view with two-way selection sync |
| Fullscreen chart | Full parity: lane, callout, and clearing (reverses the prior spec's "no selection UI in fullscreen") |

## Components

### 1. SafetyFindingsLane (new widget)

A horizontal lane rendered directly below the profile chart plot area, aligned
with the chart's time axis.

- **Placement.** Follows the `GasTimelineStrip` pattern: positioned by
  mirroring the chart's axis reservations (`leftAxisSize()`,
  `rightAxisSize()`, bottom reservations) so chip x-positions map exactly to
  chart time coordinates, including under zoom and pan. Chips for findings
  outside the visible time window are hidden; chips partially in the window
  are clamped to the window edge.
- **Chips.** One chip per non-dismissed finding that has at least a start
  timestamp.
  - A finding whose time range is wide enough on screen gets a range-width
    chip (rounded rectangle spanning start to end) with a severity icon and a
    short rule label when the width allows.
  - Short and instant findings get an icon-only chip with a minimum visual
    width of 26 px. Every chip's hit target is at least 26 px wide and the
    full lane height.
  - Chip colors come from the existing `safetySeverityColor` mapping (muted
    palette; no alarm red), consistent with the safety feature's tone rules.
  - The selected chip shows a ring outline; unselected chips render at reduced
    opacity while any selection is active.
- **Overlap.** Chips whose on-screen extents would overlap cluster into a
  single group chip showing a count. Tapping a group chip cycles the selection
  through its members (each tap selects the next; after the last member, the
  next tap clears). The exact cycle affordance may be refined during
  implementation, but a group chip must never be un-tappable or ambiguous
  about which finding is selected (the callout identifies it).
- **Visibility.** The lane renders only when safety review is enabled
  (`safetyReviewEnabledProvider`) and the dive has at least one non-dismissed
  finding with a start timestamp. Otherwise it occupies no space.
- **Dismissed findings** never appear in the lane. Restoring a dismissed
  finding (via the section's "show dismissed" list) returns its chip.
- **Findings without timestamps** cannot be placed on a time axis; they appear
  only in the safety section, as today.

### 2. Selection state and callout

- **State.** The existing
  `selectedSafetyFindingProvider(diveId)` (`StateProvider.family`) remains the
  single source of truth. The lane becomes a second writer alongside the
  section tiles. No new state model.
- **Callout.** Selecting a chip opens a callout bubble anchored to it,
  implemented as a widget overlay (the `PhotoMarkerOverlay` precedent), not an
  fl_chart element, so it has real tap targets outside the chart's gesture
  arena. Contents:
  - Severity icon, localized rule name, and key numbers (for example "peak
    14 m/min for 10 s"), respecting the active diver's units.
  - **Details** link: scrolls the page to the finding's tile in the safety
    section (selection stays active).
  - **Dismiss** action: calls the existing
    `SafetyFindingsRepository.setDismissed`, which already bumps the parent
    dive's HLC for sync; clears the selection and removes the chip.
  - **Clear** button (close icon): clears the selection.
- **Clearing paths.** All co-located with the chart: tap the clear button, tap
  the selected chip again, tap a different chip (switches), or dismiss the
  finding. Selecting from a section tile still works and can still be cleared
  from the chart.

### 3. Chart highlight rendering changes

In `DiveProfileChart`:

- **Minimum band width.** `_buildHighlightRangeAnnotations` enforces a minimum
  on-screen band width of 12 px: a range narrower than 12 px renders as a
  12 px band centered on the range midpoint (clamped to the plot bounds).
- **Instant findings** (start equals end), which today draw only a dashed
  vertical line and no band, render the same minimum-width band centered on
  the timestamp. The dashed line is dropped; the band with edge lines is the
  single highlight vocabulary.
- **Edge lines.** True ranges keep their two edge hairlines. For
  minimum-width-inflated bands, edge lines sit at the inflated band edges.
- The minimum-width calculation depends on plot pixel width, so it lives where
  the chart already knows `availableWidth` and the visible window; the pure
  `visibleHighlightSpan` clamp helper remains pixel-agnostic.

### 4. Safety section integration (two-way sync)

`SafetyReviewSection` keeps its current content and layout. Behavior:

- Tile tap still toggles selection and auto-scrolls toward the chart on
  select, exactly as today (`_toggleSelected`). This flow is acceptable now
  because clearing no longer requires scrolling back.
- Tile selected styling, lane chip ring, chart highlight, and callout all
  derive from the same provider, so they can never disagree.
- Dismiss/restore stays in the section (trailing icon buttons and the "show
  dismissed" toggle), now duplicated by the callout's Dismiss action. Both go
  through the same repository method.

### 5. Fullscreen profile parity

`FullscreenProfilePage` mounts the same lane and callout with identical
behavior, replacing today's read-only highlight carry-over. Selection made in
fullscreen is visible on the detail page afterward and vice versa, since both
read the same provider.

## Data flow

```
SafetyReviewSection tile tap ──┐
SafetyFindingsLane chip tap ───┼──> selectedSafetyFindingProvider(diveId) ──> DiveProfileChart highlightRange
Callout clear / dismiss ───────┘         │                                    SafetyFindingsLane (ring state)
                                         │                                    SafetyReviewSection (tile state)
                                         └────────────────────────────────>   FullscreenProfilePage
Callout Dismiss ──> SafetyFindingsRepository.setDismissed ──> safetyReviewProvider invalidation ──> lane/section rebuild
```

No schema, sync, repository, or rules-engine changes. This is a
presentation-layer redesign over existing state and persistence.

## Error handling and edge cases

- **Finding with start but no end timestamp:** treat as instant at the start
  timestamp (minimum-width band, icon-only chip).
- **Zoomed window excluding the selection:** the chart already omits
  out-of-window highlights via `visibleHighlightSpan`; the lane hides the
  chip; the callout hides with its chip. Selection state persists, so zooming
  back restores both.
- **Selection of a finding that becomes dismissed elsewhere** (section button,
  sync from another device): `safetyReviewProvider` invalidation rebuilds the
  lane; the lane clears a selection whose finding is no longer present and
  closes the callout.
- **Very many findings:** clustering keeps the lane legible; a group chip's
  count communicates density.
- **Narrow layouts:** the callout clamps to the chart width and repositions
  its arrow; it must never overflow the screen.
- **Render caching:** any new chart series or annotation source must supply a
  cache signature; selection state stays excluded from the bars cache key, as
  today.

## Testing

- **Rewrite** the `finding selection` group in
  `safety_review_section_test.dart`: retap-to-clear and scroll-on-select
  survive; assertions about "no other clear affordance" do not.
- **Extend** `dive_profile_chart_highlight_test.dart`: minimum-width band for
  short ranges, band (not dashed line) for instant findings, unchanged
  rendering for wide ranges.
- **New** widget tests for `SafetyFindingsLane`: chip positioning against the
  time axis under zoom/pan, minimum chip width for short and instant findings,
  overlap clustering and cycle-tap behavior, visibility gating (disabled
  setting, no findings, all dismissed), and tap-to-toggle selection.
- **New** callout tests: content per rule with unit formatting, Details
  scrolls to the section, Dismiss calls the repository and clears selection,
  clear button clears selection.
- **Extend** `fullscreen_profile_page_test.dart`: lane renders, selection
  works, and state round-trips with the detail page.
- **Unchanged:** repository, provider, service, and migration tests.

## Non-goals

- No changes to the safety rules engine, finding generation, storage, or sync.
- No multi-select; one finding highlighted at a time, as today.
- No alarm-red styling or judgmental copy; the neutral tone rules from
  `2026-07-16-safety-features-design.md` still apply.
- No changes to the dive list safety badge.
