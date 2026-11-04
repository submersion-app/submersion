# Bailout Worst-Case Marker on the Plan Chart - Design

**Issue:** #4211

## Goal

A loop plan (CCR, SCR, pSCR) has one instant at which an open-circuit
bailout would need the most gas: `BailoutOutcome.worstCase`. The results
sheet and the slate print it ("Worst case at 32′ · 45 m"), but the chart does
not. In the CCR view nothing marks it, and in the Bailout view it is only the
kink where the loop leg turns into the OC ascent.

The chart marks that instant in both views, with a marker that is always
visible and a card with its figures on demand.

## What the diver sees

- **Marker:** a hollow diamond round the point on the profile line at the
  worst-case runtime, a slanted leader up and to the left, and a pill at its
  end reading "Worst case". The diamond is hollow and wide enough (12 px half
  diagonal) to frame the waypoint handle that usually sits on the same point
  without covering it; the leader slants because a vertical one vanished into
  a steep ascent leaving the anchor (seen in the running app). The pill is
  what the diver points at.
- **Card:** hovering the pill (mouse) shows a card beside it; tapping or
  clicking the pill pins the card until the next tap anywhere else on the
  chart, or another tap on the pill. The card reads, with the strings the
  results sheet already uses:
  1. "Worst case at 32′ · 45 m" (bold)
  2. "Bailout TTS 12′"
  3. "Required 2'400 l · Available 3'000 l"
  4. only when short: "Bailout gas insufficient for the worst case", in the
     error colour.
- **Colour:** the secondary colour when the bailout gas suffices, the error
  colour when it does not (`BailoutOutcome.sufficient`, the rule the results
  sheet uses for its "Required" figure). The diamond and pill shape keep it
  apart from the warning triangles even when both are red.
- **Not current:** while a newer bailout result is being computed, the marker
  stays where the last one put it at half opacity, as the results sheet dims
  its figures. A failed result removes it.

## When there is no marker

- Open-circuit plans, and loop plans with no bailout cylinder
  (`planMayHaveBailoutProvider` false).
- No result for the open plan yet, a failed run, or a result for another plan
  (`planResultView` already returns no value for those).
- A gas gap (`BailoutOutcome.gasGap` set, #3961): every figure was sized on a
  gas past its MOD and must not be shown as a bailout plan; the Bailout view
  already draws no picture for it.

## Architecture

### Data: `planChartWorstCaseProvider`

New file `lib/features/planner/presentation/providers/plan_worst_case_provider.dart`.

```dart
class PlanChartWorstCase {
  final int runtimeSeconds;
  final double depthMeters;
  final int ttsSeconds;
  final double litersRequired;
  final double availableLiters;
  final bool sufficient;
  final bool stale; // PlanResultView.isMarked
}
```

Read from `planBailoutProvider` through `planResultView`, gated by
`planMayHaveBailoutProvider` first so removing the last bailout cylinder drops
the marker that frame (the same order `planChartBailoutProvider` uses). It does
not depend on `chartDisplayModeProvider`: both views mark the same instant.

A pure function `chartWorstCaseFrom(PlanResultView<BailoutOutcome?>)` does the
mapping, so the rules above are unit-tested without a widget.

The marker does not go into `PlanCanvasSeries`: the live series is computed
synchronously on every edit, the bailout result arrives later off the UI
isolate, and joining them would tie the profile to the slower result.

### Placement: `placeWorstCaseMarker`

New file `lib/features/planner/presentation/chart/plan_worst_case_marker_layer.dart`.

Pure function from the worst case, the chart geometry, the drawn series'
`depthAt` and the measured pill size to a `PlacedWorstCaseMarker`
(`anchor`, `pill`, `stemEnd`):

- **Anchor:** `geometry.toPixel(runtime, series.depthAt(runtime))`, on the line
  that is drawn (live plan or bailout picture), as the warning markers are.
  The card's depth figure comes from the result itself.
- **Pill:** above the anchor with its right edge 12 px left of the anchor's
  x, so it extends back over the bottom phase. Stop tags sit right of and below their
  stops, and gas flags sit at the plot top right of their stems, so up-left is
  the free side. The pill's bottom is 22 px above the anchor, clear of a
  warning sign (5 to 17 px above its anchor) at the same point.
- **Flip:** when the pill would reach into the top 24 px of the plot (gas flag
  row) it goes below the anchor instead, 22 px down.
- **Clamp:** always horizontally inside the plot.

### Drawing and accessibility: `PlanWorstCaseMarkerLayer`

Same file. A `StatelessWidget` like `PlanIssueMarkerLayer`: a `CustomPainter`
for diamond, stem and pill, a `Semantics(button: true)` target of at least
48 px over the pill whose label is the card's text and whose `onTap` toggles
the card, and the card itself when `active`. It takes no pointer input; the
chart's own `Listener` hit-tests it.

The card placement (`_PopupLayout` in `plan_issue_marker_layer.dart`) moves to
its own file as `PlanChartPopupLayout` and serves both layers, so both cards
sit beside their marker by the same rules.

### Interaction in `PlanProfileChart`

- **Hit test:** `hitTestWorstCasePill(placed, position, radius)`, the distance
  from the position to the pill rect, 4 px for a mouse and 16 px for touch
  (48 px target). Only the pill is a target, not the diamond: the worst case
  usually sits on the waypoint that ends the bottom segment, and that
  waypoint must stay draggable.
- **Precedence:** when a warning sign and the pill are both in reach, the
  closer one wins. A fixed "warnings first" rule would let a warning at the
  same instant swallow most of the pill on touch, where the warning's 24 px
  radius reaches 35 px above its anchor.
- **Pinned per plan:** the pinned card belongs to the plan it was pinned on
  (held by plan id), so moving to another dive of a series does not open the
  next dive's card unasked.
- **Press:** a press on the pill neither scrubs, selects a segment nor counts
  as half of a double-tap (as a press on a warning marker). If it ends where
  it began, it toggles the pinned card and clears a picked warning, so only
  one card shows. Tapping a warning marker unpins the card.
- **Hover:** over the pill the card shows and the scrub cursor clears.
- **Drag:** a waypoint being dragged hides the card; the marker describes the
  plan as it was before the drag.
- **One card at a time:** the warnings card wins when both are wanted.

`plan_profile_chart.dart` is 775 lines; the repo caps files at 800. The scrub
readout and bailout status column moves to its own widget file first, so the
chart stays under the cap with the new hooks.

### Strings

One new string, the pill label, `plannerCanvas_chart_worstCase`, in all 11 ARB
files ("Worst case", "Schlimmster Fall", ...). The card reuses
`plannerCanvas_bailout_worstCase`, `_tts`, `_required`, `_available` and
`_insufficient`. Volumes and depths go through `UnitFormatter`.

## Settled in review

- **Same timeline:** `BailoutSolver.solve` resolves its legs through the
  same diluent-switch and rate-split steps the live series does, and its
  points start at the dive's own zero, so `worstCase.runtimeSeconds` lands on
  the drawn live profile.
- **Always on the drawn line:** the solver samples the authored legs only,
  never the computed ascent, so the worst case lies inside the profile both
  views draw.
- **Logged dives:** a logged dive picked in the series bar is drawn by
  `LoggedDiveChart`, not `PlanProfileChart`, so a plan's marker never lands
  on a logged profile.
- **Fullscreen:** `PlanChartFullscreenPage` hosts the same `PlanProfileChart`
  and gets the marker without extra work.

## Testing

- `chartWorstCaseFrom`: current result, stale result, failed result, gas gap,
  no value, sufficient and short.
- `placeWorstCaseMarker`: pill above and left, flipped below near the top,
  clamped at the left edge, anchor on the drawn line.
- `hitTestWorstCasePill`: inside, within the radius, outside.
- `PlanProfileChart` widget tests with a held bailout runner (the pattern of
  `plan_chart_bailout_status_test.dart`): no marker before the result, marker
  in the CCR view and in the Bailout view, none for an OC plan, card on tap
  and gone on a second tap, card text, error colour when short.

## Out of scope

- A marker for the +depth/+time contingencies.
- The bailout gas need over the whole dive as a curve.
- The slate PDF, which already prints the worst case as text.
