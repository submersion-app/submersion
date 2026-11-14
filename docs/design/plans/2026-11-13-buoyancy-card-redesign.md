# Buoyancy Card Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in one session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the dive detail Buoyancy card so it shows what buoyancy did
through the dive, what was pulling down and holding up at any moment, and how
much lead the model suggests.

**Architecture:** A pure helper in `lib/core/buoyancy/` turns a twin result
plus a moment into signed balance parts. Four small widgets (through-the-dive
section, balance bar, lead block, safety rows) replace the body of
`BuoyancySection`, which keeps its header, breakdown and hints. No model,
database or provider change.

**Tech Stack:** Flutter, Riverpod, fl_chart 1.1, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-13-buoyancy-card-redesign-design.md`

## Global Constraints

- Every figure appears once on the card. At rest the readout is
  `verdict.netKg`, the same value `idealLeadKg` is derived from.
- Neutral threshold: `net.abs() <= 0.5` kg. Negligible part or note: under
  0.05 kg.
- Every weight, depth and volume goes through `UnitFormatter`.
- New strings exist in all eleven ARB files with real translations. Run
  `flutter gen-l10n` only after every ARB has the keys. Insert lines by
  anchor key; never JSON round-trip an ARB.
- The Dive Planner, Weight Planner, `TwinSummaryRows` and the Adjust sheet do
  not change. `buoyancy_verdictBuoyant`, `buoyancy_verdictHeavy` and
  `buoyancy_verdictNeutral` stay (they are still used there).
- No file over 800 lines; new widgets one per file. No emojis, no em-dashes.
- Tests pin `locale: Locale('en')`. Never run the whole suite locally.

## Review Focus

1. Imperial diver: every figure on the card reads in lb and ft (Task 4 test).
2. A tank that floats when empty: the Tanks part changes side while
   scrubbing (Task 2 test).
3. Half-width card (300 px): no overflow; segment labels that do not fit move
   to the legend (Task 3 and Task 8 tests).
4. Non-finite samples dropped by the chart: the readout and bar resolve the
   cursor against the same plottable list (Task 5 test).
5. Right-to-left locale: the card lays out without overflow and the captions
   stay over their own halves (Task 3 test under `Locale('ar')`).

---

### Task 1: Strings in all eleven locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten `app_<locale>.arb` files
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces (all placeholders `String`, in this map order):

| Key | English | Placeholders |
| --- | --- | --- |
| `buoyancy_readoutHeavy` | `{amount} heavy` | amount |
| `buoyancy_readoutBuoyant` | `{amount} buoyant` | amount |
| `buoyancy_readoutNeutral` | `Close to neutral` | |
| `buoyancy_readoutAtFinalStop` | `at your final stop, about {depth}` | depth |
| `buoyancy_readoutConvention` | `estimated at the {depth} safety-stop convention` | depth |
| `buoyancy_readoutAtMoment` | `at {depth}, {time}` | depth, time |
| `buoyancy_pullingDown` | `Pulling you down` | |
| `buoyancy_holdingUp` | `Holding you up` | |
| `buoyancy_partGear` | `Gear` | |
| `buoyancy_partBody` | `Body` | |
| `buoyancy_partLabel` | `{name} {amount}` | name, amount |
| `buoyancy_markerStart` | `Start` | |
| `buoyancy_markerDeepest` | `Deepest` | |
| `buoyancy_markerFinalStop` | `Final stop` | |
| `buoyancy_causeSuit` | `Suit squeeze cost {amount} of lift at {depth}` | amount, depth |
| `buoyancy_causeGas` | `Gas breathed left the tanks {amount} lighter` | amount |
| `buoyancy_leadTitle` | `Lead for next time` | |
| `buoyancy_leadCarried` | `You carried` | |
| `buoyancy_leadSuggested` | `Model suggests` | |
| `buoyancy_leadNotRecorded` | `Not recorded` | |
| `buoyancy_statusWell` | `Well weighted` | |
| `buoyancy_peakLiftWithin` | `within your wing's {amount}` | amount |
| `buoyancy_peakLiftExceeds` | `exceeds your wing's {amount}` | amount |
| `buoyancy_ditchCovered` | `you can ditch {amount}` | amount |
| `buoyancy_ditchShort` | `you can ditch only {amount}` | amount |

- Changed values: `diveDetailSection_buoyancy_description` becomes
  `Buoyancy through the dive, lead for next time, ditchable weight`;
  `info_diveLog_buoyancy_howToUse` becomes `Move across the chart to see what
  was pulling you down and holding you up at that moment. Adjust opens a
  sheet that tries a different amount of lead or suit buoyancy against this
  dive.` (two sentences; the cap is four).
- Reused, unchanged: `buoyancy_leadTerm`, `buoyancy_suitTerm`,
  `diveDetailSection_tanks_name`, `diveLog_edit_weightFeedback_over`,
  `diveLog_edit_weightFeedback_under`, `buoyancy_peakLift`,
  `buoyancy_minDitchable`, `buoyancy_drysuitGas`.

- [ ] **Step 1:** Insert the 25 keys after `"buoyancy_adjust"` in every ARB
  (a key present in all eleven), with `@meta` placeholder blocks in
  `app_en.arb` only. Translate each into ar, de, es, fr, he, hu, it, nl, pt,
  zh, matching the nouns the neighbouring buoyancy keys already use.
- [ ] **Step 2:** Rewrite the two changed values in all eleven files.
- [ ] **Step 3:** `json.loads` every ARB; `git diff --numstat -- lib/l10n/arb/*.arb`
  shows the same added and removed counts for all ten locale files.
- [ ] **Step 4:** Run `flutter gen-l10n`. Expected: no new "untranslated"
  count for these keys. Spot-check
  `grep -A1 "get buoyancy_leadTitle" lib/l10n/arb/app_localizations_de.dart`
  is German.
- [ ] **Step 5:** Run `flutter test test/l10n/`. Expected: PASS.
- [ ] **Step 6:** Commit `i18n(dive-log): strings for the buoyancy card redesign`.

### Task 2: Balance model

**Files:**
- Create: `lib/core/buoyancy/twin_balance.dart`
- Test: `test/core/buoyancy/twin_balance_test.dart`

**Interfaces:**
- Consumes: `BuoyancyTwinResult`, `TwinSample`, `TwinVerdict`,
  `TwinStaticTerm`, `TwinSuitKind`, `BodyComposition.termLabel`.
- Produces:

```dart
enum TwinBalancePartKind { lead, tanks, gear, suit, body }

class TwinBalancePart {
  final TwinBalancePartKind kind;
  final double kg; // signed: negative pulls down, positive holds up
}

class TwinBalance {
  static const double negligibleKg = 0.05;
  final List<TwinBalancePart> parts; // negligible parts already removed
  final double netKg;
  List<TwinBalancePart> get down; // kg < 0, in kind order
  List<TwinBalancePart> get up; // kg > 0, in kind order
  double get downTotalKg; // positive magnitude
  double get upTotalKg;

  factory TwinBalance.atRest(BuoyancyTwinResult result, TwinVerdict verdict);
  factory TwinBalance.atSample(BuoyancyTwinResult result, TwinSample sample);

  /// Largest side total across every sample and the rest state.
  static double scaleKg(BuoyancyTwinResult result, TwinVerdict verdict);
}

class TwinMoments {
  final TwinSample? start; // first sample deeper than kSurfaceDepthM
  final TwinSample? deepest;
  final int? finalStopSeconds; // null for the convention anchor
  final double? suitSqueezeKg; // wetsuit only, null under negligibleKg
  final double? gasLighterKg; // null under negligibleKg
  factory TwinMoments.of(BuoyancyTwinResult result, TwinVerdict verdict);
}
```

Body terms are static terms labelled `personal`, `water` or
`BodyComposition.termLabel`; every other static term is gear. At rest: suit
is the verdict term labelled `suit` (0 when absent) and tanks is
`verdict.netKg - suit - sum(staticTerms) + leadKg`.

- [ ] **Step 1: Write failing tests**, each building a `BuoyancyTwinResult`
  by hand:
  - `atSample parts sum to the sample net` (within 1e-9).
  - `atRest parts sum to verdict.netKg`.
  - `lead is always down; a positive tanks term is up, a negative one down`
    (two samples, `tanksKg: -2.0` then `tanksKg: 0.4`).
  - `a part under 0.05 kg is dropped` (`suitKg: 0.02`).
  - `gear and body terms are grouped` (static terms `personal 5.0`,
    `water 0.3`, `Backplate -2.5`, `Regulator -0.8` give body 5.3 and gear
    -3.3).
  - `scaleKg is the largest side total over the dive`.
  - `moments: start is the first in-water sample, deepest the max depth`.
  - `finalStopSeconds is null for the convention anchor`.
  - `suitSqueezeKg is null for a drysuit and for no suit`.
  - `gasLighterKg is last tanks minus first, null when under 0.05`.
- [ ] **Step 2:** Run `flutter test test/core/buoyancy/twin_balance_test.dart`.
  Expected: FAIL, file not found.
- [ ] **Step 3:** Implement `twin_balance.dart` to the interface above.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5:** Commit `feat(buoyancy): balance parts for a moment of the dive`.

### Task 3: Balance bar widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_balance_bar.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_balance_bar_test.dart`

**Interfaces:**
- Consumes: `TwinBalance`, `TwinBalancePartKind` (Task 2); strings (Task 1).
- Produces: `BuoyancyBalanceBar({required TwinBalance balance, required
  double scaleKg, required UnitFormatter units})`. Each segment carries
  `ValueKey('balance-<kind name>')`. Segment height 34.

Layout: a caption row (`buoyancy_pullingDown` start, `buoyancy_holdingUp`
end), then two equal halves meeting at a 2 px centre rule. Down segments grow
from the centre toward the start edge, up segments toward the end edge. A
segment's width is `kg.abs() / scaleKg` of its half, minimum 2 px. Colours:
down `tertiaryContainer` / `onTertiaryContainer`, up `primaryContainer` /
`onPrimaryContainer`. A segment shows `buoyancy_partLabel(name, amount)` when
a `TextPainter` measure fits inside it with 8 px padding each side; labels
that do not fit are listed in a `Wrap` legend under the bar, each with a
colour swatch. Every segment is wrapped in a `Tooltip` and a `Semantics`
label carrying the same text.

- [ ] **Step 1: Write failing tests** (800 px wide unless noted):
  - `down parts sit on the start side, up parts on the end side` (compare
    each keyed segment's centre x with the bar's centre).
  - `segment width follows kg over scale` (lead 6 kg at scale 12 is half of
    its half, within 1 px).
  - `a wide segment carries its label` (`find.text('Lead 6.0 kg')`).
  - `at 300 px a narrow segment's label moves to the legend and nothing
    overflows` (`tester.takeException()` is null; the label text is found
    outside the segment).
  - `under Locale('ar') it lays out without overflow and the down caption is
    over the down half`.
  - `imperial settings format the labels in lb`.
- [ ] **Step 2:** Run the test file. Expected: FAIL.
- [ ] **Step 3:** Implement the widget.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-log): balance bar of what pulls down and holds up`.

### Task 4: Chart markers, rest cursor, no tooltip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_chart.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_chart_test.dart`

**Interfaces:**
- Produces:

```dart
class BuoyancyChartMarker {
  final int seconds;
  final String label;
  final bool optional; // dropped when its label would collide
}

// New BuoyancyChart parameters:
final List<BuoyancyChartMarker> markers; // default const []
final int? restSeconds; // where the cursor line sits with no cursor

/// Indices of [markers] whose labels fit. Required markers always stay.
static Set<int> labelledMarkers({
  required List<double> xPx, // each marker's x within the plot
  required List<double> labelWidthPx,
  required List<bool> optional,
  double gapPx = 6,
});
```

Each marker draws a dot on the line (`FlDotData.checkToShowDot`) and a 1 px
dashed `VerticalLine` in `outlineVariant` with a `VerticalLineLabel` at the
top of the plot. `maxY` gains headroom of 15 percent of the range so the
labels clear the line. The cursor line is drawn at
`cursorSeconds ?? restSeconds`. The tooltip is suppressed by returning null
items from `getTooltipItems`; the touch callback is unchanged.

- [ ] **Step 1: Write failing tests:**
  - `labelledMarkers keeps required labels and drops a colliding optional one`.
  - `labelledMarkers keeps an optional label that has room`.
  - `markers add one dashed vertical line each` (read `LineChartData`).
  - `the cursor line rests on restSeconds when cursorSeconds is null`.
  - `cursorSeconds wins over restSeconds`.
  - `the touch tooltip produces no items`.
  - `the y axis title carries lb under imperial settings`.
- [ ] **Step 2:** Run the test file. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement. Update or delete the existing tooltip-content
  tests in this file to match.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-log): mark start, deepest and final stop on the buoyancy chart`.

### Task 5: Through-the-dive section

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_through_dive.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_through_dive_test.dart`

**Interfaces:**
- Consumes: `TwinBalance`, `TwinMoments` (Task 2), `BuoyancyBalanceBar`
  (Task 3), `BuoyancyChart` markers and `restSeconds` (Task 4).
- Produces: `BuoyancyThroughDive({required BuoyancyTwinOutcome outcome,
  required UnitFormatter units, int? cursorSeconds, ValueChanged<int?>?
  onCursorSeconds})`. A `StatefulWidget`: when `onCursorSeconds` is null it
  keeps the chart's touch position itself.

Order: readout, chart, balance bar, cause notes. The cursor resolves to the
plottable sample (`BuoyancyChart.plottableSamples`) with the nearest
timestamp. Readout figure style `headlineSmall`; qualifier `bodyMedium` in
`onSurfaceVariant`. Depth in the qualifier uses `formatDepth(decimals: 0)`;
time is `m:ss`. Cause notes are `bodySmall` with a leading 16 px icon
(`Icons.compress` for the suit, `Icons.air` for gas).

- [ ] **Step 1: Write failing tests** (extend `buoyancy_outcome_fixture.dart`
  with a `samples:` parameter and an `anchor:` parameter as needed):
  - `at rest the readout is the verdict net at the final stop`
    (`1.8 kg buoyant`, `at your final stop, about 5 m`).
  - `a negative net reads heavy; within 0.5 kg reads Close to neutral`.
  - `the convention anchor reads estimated at the 5 m safety-stop convention`.
  - `a cursor shows that sample` (`at 18 m, 2:00`) and the bar's parts are
    that sample's.
  - `with a dropped non-finite sample the cursor still resolves to the
    right sample`.
  - `fewer than two samples: no chart, readout and bar still shown`.
  - `without onCursorSeconds a chart touch moves the readout` (call the
    chart's callback, pump, read the text).
  - `suit note only for a wetsuit; gas note only when tanks lightened`.
  - `imperial settings: readout and notes read in lb and ft`.
- [ ] **Step 2:** Run the test file. Expected: FAIL.
- [ ] **Step 3:** Implement the widget.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-log): readout, chart and balance as one section`.

### Task 6: Lead block

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_lead_block.dart`
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_history_strip.dart`
  (drop its title; review removed the `showTitle` switch first planned here,
  since this block is the only user of the strip)
- Test: `test/features/dive_log/presentation/widgets/buoyancy_lead_block_test.dart`

**Interfaces:**
- Produces: `BuoyancyLeadBlock({required String diveId, required
  BuoyancyTwinOutcome outcome, required UnitFormatter units})`.

Title row: `buoyancy_leadTitle` plus a chip. Chip text: `buoyancy_statusWell`
when `verdict.netKg.abs() <= 0.5`, `diveLog_edit_weightFeedback_over` when
net is negative, `diveLog_edit_weightFeedback_under` when positive. Chip
colours: well uses `primaryContainer`, the others `tertiaryContainer`.
Figures: `buoyancy_leadCarried` over `formatWeight(input.leadKg)`, an arrow
icon, `buoyancy_leadSuggested` over `formatWeight(outputs.idealLeadKg)`,
figures in `titleLarge`. When `input.leadKg <= 0`: the carried figure is
`buoyancy_leadNotRecorded` and there is no chip. The history strip
sits in a `Wrap` after the figures, so it drops below
them on a narrow card.

- [ ] **Step 1: Write failing tests:**
  - `shows carried and suggested lead` (`6.0 kg`, `7.8 kg` from the fixture).
  - `chip reads Underweighted when buoyant, Overweighted when heavy, Well
    weighted within 0.5 kg`.
  - `no lead recorded: Not recorded, no chip`.
  - `the history strip has no title here` (override
    `buoyancyHistoryProvider` with two entries; `WEIGHTING HISTORY` absent,
    legend present).
  - `300 px wide: no overflow`.
- [ ] **Step 2:** Run the test file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-log): lead carried and suggested on the buoyancy card`.

### Task 7: Safety rows

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/buoyancy_safety_rows.dart`
- Test: `test/features/dive_log/presentation/widgets/buoyancy_safety_rows_test.dart`

**Interfaces:**
- Produces: `BuoyancySafetyRows({required TwinOutputs outputs, required
  UnitFormatter units, double? wingLiftCapacityKg})`.

Each row: a 16 px icon, the label and figure in `bodyMedium`, a qualifier in
`bodySmall` `onSurfaceVariant`, in a `Wrap` so the qualifier drops below on a
narrow card. Pass icon `Icons.check_circle_outline` in `primary`; warn icon
`Icons.warning_amber_rounded` in `error`; neutral icon `Icons.info_outline`
in `outline`. A wing lift of zero or less counts as not recorded.

| Row | Qualifier and state |
| --- | --- |
| `buoyancy_peakLift` + peak lift | wing recorded and demand within it: `buoyancy_peakLiftWithin(wing)`, pass. Demand above it: `buoyancy_peakLiftExceeds(wing)`, warn. No wing: no qualifier, neutral. |
| `buoyancy_minDitchable` + min ditchable | `droppableLeadKg >= minDitchableKg`: `buoyancy_ditchCovered(droppable)`, pass. Otherwise `buoyancy_ditchShort(droppable)`, warn. |
| `buoyancy_drysuitGas` + volume | only when `drysuitGasLiters > 0`; neutral. |

- [ ] **Step 1: Write failing tests**, one per cell of the table above, plus
  `a non-positive wing lift is treated as not recorded` and `300 px wide: no
  overflow`.
- [ ] **Step 2:** Run the test file. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-log): pass or warn rows for lift and ditchable weight`.

### Task 8: Compose the card

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart`
- Modify: `lib/features/dive_log/presentation/info/buoyancy_info.dart`
  (remove `DiveTerm.buoyancySwing`)
- Modify: `lib/core/constants/dive_detail_sections.dart:115` (the English
  fallback description, to match Task 1)
- Modify: all eleven ARB files (delete `buoyancy_verdictConvention`), then
  regenerate
- Test: `test/features/dive_log/presentation/widgets/buoyancy_section_test.dart`

**Interfaces:**
- Consumes: `BuoyancyThroughDive` (Task 5), `BuoyancyLeadBlock` (Task 6),
  `BuoyancySafetyRows` (Task 7).

Card body order: header (unchanged), `BuoyancyThroughDive`, the existing
breakdown `ExpansionTile`, a divider, `BuoyancyLeadBlock`, a divider,
`BuoyancySafetyRows`, hints (unchanged). `_verdict`, the convention line and
the `TwinSummaryRows` and `BuoyancyHistoryStrip` calls leave this file. The
profile-cursor `Consumer` now wraps `BuoyancyThroughDive` and passes
`cursorSeconds` and `onCursorSeconds` to it.

- [ ] **Step 1: Update and add tests:**
  - Existing cursor-sync tests read `BuoyancyChart` as before and still pass.
  - Replace `without a dive there is no sync` with `without a dive the card
    keeps its own cursor` (the chart has a callback; the profile provider is
    not written).
  - `the heavy or buoyant figure appears once at rest` (`find.textContaining
    ('1.8 kg')` finds exactly one widget).
  - `the swing, start and end tiles are gone` (`Buoyancy swing`, `Start of
    dive`, `End of dive` absent).
  - `the info sheet no longer lists Buoyancy swing`.
  - Existing ditch warning, hints, header and narrow-card tests still pass.
  - `at 300 px and at 366 px (half of 732) nothing overflows`.
- [ ] **Step 2:** Run the test file. Expected: the new tests FAIL.
- [ ] **Step 3:** Implement the composition; delete
  `buoyancy_verdictConvention` from every ARB by exact line; run
  `flutter gen-l10n`.
- [ ] **Step 4:** Run `flutter test test/features/dive_log/presentation/widgets/
  test/core/buoyancy/ test/l10n/ test/architecture/ test/shared/`. Expected: PASS.
- [ ] **Step 5:** `dart format .` then `flutter analyze` (whole repo).
  Expected: no issues.
- [ ] **Step 6:** Commit `feat(dive-log): rebuild the buoyancy card around the dive and the lead`.

### Task 9: Screenshots and visual check

- [ ] **Step 1:** Launch the app on a dive with a wetsuit, tanks and lead.
  Capture the card in light and dark, at desktop width and at the paired
  half width. Compare with the before shots.
- [ ] **Step 2:** Check the balance colours against the card surface in both
  modes. If either container pair reads poorly, adjust in
  `buoyancy_balance_bar.dart` and re-run its tests.
- [ ] **Step 3:** Commit any adjustment as `fix(dive-log): ...`.
