# Safety Finding → Profile Chart Highlight

Date: 2026-08-07
Status: Approved

## Problem

Selecting a safety review item on the dive detail page gives no visual
connection to the dive profile chart. The finding tile shows a time range
(e.g. "12:40 – 14:05"), but the user has to read the timestamps and mentally
locate that window on the chart. Tapping a finding should highlight the
affected region directly on the profile chart.

## Goals

- Tapping a safety finding highlights its time range on the profile chart
  and scrolls the chart into view.
- The highlight carries into the fullscreen profile view.
- No schema, entity, or analyzer changes: `SafetyFinding` already stores
  `startTimestamp` / `endTimestamp` in seconds from dive start, the same
  unit as the chart x-axis.

## Non-goals

- Selecting findings from within the fullscreen profile view (read-only
  carry-over only).
- Persisting the selection across app restarts or syncing it.
- Highlighting multiple findings at once (single selection).

## Design

### 1. State

New provider alongside the existing safety review providers
(`lib/features/dive_log/presentation/providers/safety_review_providers.dart`):

```dart
final selectedSafetyFindingProvider =
    StateProvider.family<SafetyFinding?, String>((ref, diveId) => null);
```

Keyed by diveId like `profileTrackingIndexProvider` and
`rangeSelectionProvider`. It stores the whole `SafetyFinding` (id,
severity, timestamps) so consumers never re-derive data from
`safetyReviewProvider`, keeping the chart pipeline independent of the
analysis `FutureProvider`.

Selection semantics:

- Tap an unselected finding → it becomes selected.
- Tap the selected finding again → selection cleared.
- Tap a different finding → selection replaced.
- Dismiss the selected finding → selection cleared.
- State is per-dive session state; no persistence.

### 2. Finding tile interaction

`_FindingTile` in
`lib/features/dive_log/presentation/widgets/safety_review_section.dart`:

- Gains `onTap` (toggle semantics above) and `selected:` styling via
  Material `ListTile.selected` with a severity-tinted `selectedTileColor`.
- Findings with null timestamps get no `onTap`. (All five current rules
  set both timestamps, but the entity fields are nullable.)
- On selection, the page animates the existing `DetailScrollController`
  to offset 0, bringing the header and the chart (the fixed second
  section) into view.

### 3. Chart rendering

`DiveProfileChart`
(`lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`)
gains one new optional constructor param, a value class:

```dart
class ProfileHighlightRange {
  final int startTimestamp; // dive-seconds
  final int endTimestamp;   // dive-seconds; == start for instant findings
  final Color color;        // severity color, already resolved by caller
}
```

Rendering inside the chart:

- **Range findings** (`start != end`): a fl_chart
  `VerticalRangeAnnotation` (`LineChartData.rangeAnnotations`) filled
  with `color` at ~15% opacity, plus two edge `VerticalLine`s in the
  severity color added to the existing `ExtraLinesData` composition
  (playback cursor, highlight cursor, event lines).
- **Instant findings** (`start == end` — omitted safety stop, high
  surface GF): no band; a single severity-colored dashed `VerticalLine`
  in the same composition, styled like the existing highlight cursor.
- **Zoom/pan correctness**: annotation x-values are clamped to the
  chart's current `visibleMinX` / `visibleMaxX` before building
  (fl_chart throws on out-of-bounds annotations). A range partially
  outside the window is clipped; one fully outside is omitted. This
  clamp/omit logic is a pure function with unit tests.

The chart stays provider-free: pages read the provider, resolve
severity → color using the existing severity color mapping from the
safety review section, and pass the value in — the same boundary used
by `GasTimelineStrip` and `PhotoMarkerOverlay`.

### 4. Fullscreen profile

`fullscreen_profile_page.dart` reads
`selectedSafetyFindingProvider(diveId)` and passes the same
`ProfileHighlightRange` to its chart instance. A finding selected on
the detail page is already highlighted when fullscreen opens. No
selection UI in fullscreen.

### 5. Edge cases

- Sawtooth findings span most of the dive; the wide translucent band is
  acceptable by design (low opacity).
- Chart interaction (tap, tracking cursor, playback) does not clear the
  selection; the band coexists with the cursors.
- Navigating between dives naturally scopes selection via the family
  key.

## Testing (TDD)

- Provider unit tests: toggle, replace, clear-on-dismiss semantics.
- Widget tests, safety section: tap sets provider; tile shows selected
  state; second tap clears; null-timestamp finding is not tappable.
- Widget tests, detail page wiring: selected finding → chart receives
  the expected `ProfileHighlightRange`; severity → color mapping;
  instant vs range findings produce cursor vs band.
- Unit tests: clamp/omit visibility function across in-window,
  partially-visible, and fully-outside ranges.
