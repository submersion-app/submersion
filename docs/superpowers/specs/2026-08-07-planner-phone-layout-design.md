# Planner Phone Layout Rebalance — Design

Date: 2026-08-07
Status: Approved (brainstorming session, option B of 3 mockups)
Branch: worktree-planner-phone-layout

## Problem

On phones (< 760 px width), the dive planner body (`_buildPhone` in
`lib/features/planner/presentation/pages/plan_canvas_page.dart`) is a fixed
stack: the profile chart is pinned at 40% of the body height, followed by two
`Wrap` chip rows (status chips: runtime/NDL-or-TTS/deco/CNS/issues/following;
contingency selectors: Base/+depth/+time/both), then the Plan/Tanks/Setup/
Results segmented button. Only the leftover `Expanded` at the bottom scrolls.
On a 6.1 inch phone with a deco plan the scrollable deck can drop to ~180 px;
on SE-class phones below 150 px. The deck content — segment editing, tank
list, setup accordion, and results text — is effectively hidden. The squeeze
applies to all four tabs equally.

## Decisions from brainstorming

- The chart must stay visible while working in the deck (live canvas feedback
  is the point of the planner).
- Both chip rows leave the phone flow entirely; their information moves onto
  the chart as dive-computer-style instrument readouts.
- Of three mockups (A: chart keeps 40%; B: chart drops to ~30%; C: draggable
  split), the user chose B — rebalanced 30/70.
- Contingency selection lives on the chart's bottom edge, next to the ghost
  overlay it controls.
- Mockups persisted at `.superpowers/brainstorm/37921-1786132686/content/`
  (phone-layout-v2.html).

## Design

### 1. Scope and structure

Only the phone branch (`_buildPhone`, width < 760 px) changes. The body
becomes three blocks:

1. Chart block: height `(bodyHeight * 0.30).clamp(160.0, 260.0)` (replaces
   the hard `maxHeight * 0.40`), rendered in the existing `Stack` with the
   overlays described below.
2. The existing Plan/Tanks/Setup/Results `SegmentedButton`.
3. The deck (`Expanded`), receiving everything else.

The two chip-row `Padding`s (`PlanStatusChips`, `ContingencyChips`) are
removed from the phone flow. Desktop and tablet layouts (>= 760 px) keep the
chips below the chart exactly as today. The fullscreen chart page
(`/planning/dive-planner/chart`) is untouched. On a 6.1 inch phone the deck
grows from roughly 180 px to about 330 px; the clamp floor keeps the chart
usable on short viewports and the ceiling stops it dominating tall ones.

### 2. Instrument readouts: `PlanChartReadouts`

New widget `lib/features/planner/presentation/widgets/plan_chart_readouts.dart`,
overlaid on the chart inside the existing `Stack` — plain widgets, no changes
to the chart painters.

- Top-left: large runtime value with a small label beneath, and, when the
  plan follows a logged dive (`sourceDiveId != null`), a compact following
  pill tucked under the runtime block (tap clears, reusing the clear action
  of today's `FollowingChip`).
- Top-right column: TTS when in deco (`ndlAtBottom < 0`) or NDL otherwise;
  DECO only when `totalDecoSeconds > 0`; CNS, tinted orange at or above
  `cnsWarningThresholdProvider`; and a severity-tinted issues pill (only when
  issues exist) that switches the phone tab to Results on tap.
- Logic and data sources are identical to today's `PlanStatusChips`:
  `planOutcomeProvider`, `cnsWarningThresholdProvider`,
  `planIssueSeverityColor`, and the existing l10n keys. No new ARB strings.
- Passive readouts render inside an `IgnorePointer` with a text shadow/scrim
  for legibility over the grid; only the issues pill and following pill are
  hit-testable. Chart edit gestures pass through everywhere else.

### 3. Contingency pills on the chart

`ContingencyChips` gains an `overlay` flag (default false). When set, it
renders the same four selectors (Base / +depth / +time / both, driven by
`selectedDeviationProvider`) as a compact single-row pill strip styled for
the chart backdrop (scrim background, smaller padding, no wrapping),
positioned along the chart's bottom-left edge. Hidden when the plan has no
segments, as today. The fullscreen button stays bottom-right. Desktop
continues to use the default (non-overlay) rendering below the chart.

### 4. Behavior and edge cases

- Issues-pill tap and `_focusSetup` keep the current tab-switching behavior
  (tab indices unchanged).
- App-bar GF/altitude chips are out of scope (they already self-hide below
  560 px width).
- No schema, sync, or l10n changes.
- Readouts degrade gracefully for an empty plan (runtime 0, no deco, no
  issues) — same as the chips do today.

### 5. Testing

- Update existing phone-layout widget tests that expect the chip rows between
  chart and tab bar.
- New widget tests: TTS-vs-NDL readout switching; DECO readout only when
  deco time exists; CNS tint at threshold; issues pill visibility, severity
  tint, and tap selecting the Results tab; contingency pill selection driving
  `selectedDeviationProvider`; overlay pills hidden with no segments;
  following pill visibility and tap-to-clear; no overflow at SE-class logical
  dimensions (320 x 568) with a deco-heavy plan.
- Existing planner test harness patterns (provider overrides via
  `settingsProvider`, no new provider dependencies in shared widgets) apply.

## Out of scope

- Desktop/tablet (>= 760 px) layouts.
- The fullscreen chart page.
- Landscape-phone handling beyond what the clamp floor provides (a landscape
  phone at >= 760 px width uses the desktop layout, as today).
- Draggable chart/deck split (mockup option C) — revisit only if the fixed
  30% split proves wrong in use.

## Acceptance criteria

1. On a phone-sized surface, no chip rows render between the chart and the
   tab bar; the chart block height equals `(body * 0.30).clamp(160, 260)`.
2. All readout values, visibility rules, tints, and tap behaviors listed in
   section 2 hold.
3. Contingency pills behave per section 3.
4. Desktop layout snapshot is unchanged (chips still below chart).
5. `flutter analyze` clean, `dart format` clean, full planner test suites
   green.
