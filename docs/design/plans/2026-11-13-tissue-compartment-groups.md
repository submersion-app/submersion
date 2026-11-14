# Tissue Compartment Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell the diver what a tissue compartment number means: a speed group
label beside the selected compartment and in its tooltip, a fuller help sheet
entry, numbered bars, and compartment and time axes on the heat map.

**Architecture:** One small presentation file maps a compartment number to a
`CompartmentGroup` and its localized label; the detail row and the shared
tooltip text both read it. The bar chart gains a numbers row laid out with the
bars' own `Expanded` cells. The heat map axes live in a new widget file and are
composed around `TissueHeatMapStrip` in `CompactTissueLoadingCard`, which takes
a new optional `profileTimestamps` input from the dive details page.

**Tech Stack:** Flutter, Riverpod, gen-l10n ARB files, flutter_test.

**Spec:** `docs/design/specs/2026-11-13-tissue-compartment-groups-design.md`

## Global Constraints

- Groups by compartment number: 1-5 "Fast, blood-rich tissue", 6-10
  "Medium, muscle and skin", 11-16 "Slow, fat and bone".
- The labels must not read as an anatomical mapping; the help sheet says the
  tissue names are rough examples, not anatomy.
- Every new or changed string is translated into all 10 locales (ar, de, es,
  fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs last.
- Axis and bar-number text is at least 11 px and fits a 360 px phone width.
- No em-dashes in code, comments, strings or docs.
- Insert ARB lines by anchor key; never json round-trip an ARB file.

## Review Focus

- `profileTimestamps` length differs from `decoStatuses` (the dive details
  page retains an older analysis during a sync): the time axis is left out,
  no exception.
- A single sample, or `profileTimestamps` null (the current dive load page):
  no time axis, compartment axis still shown, no division by zero.
- Right-to-left locales: the heat map painter always runs time left to right,
  so the time axis and compartment axis are laid out left to right too; the
  bar numbers follow the bars, which reverse with the `Row`.
- Expanded card (`expandVisualization: true`): the compartment axis stretches
  with the strip, labels stay on rows 1, 8 and 16.
- Large text scale: bar numbers shrink to fit their cells rather than
  overflow (`FittedBox`).

---

### Task 1: Compartment group mapping and English strings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/compartment_group.dart`
- Modify: `lib/l10n/arb/app_en.arb` (after `diveLog_deco_compartmentOther`)
- Test: `test/features/dive_log/presentation/widgets/compartment_group_test.dart`

**Interfaces:**
- Produces: `enum CompartmentGroup { fast, medium, slow }` with
  `static CompartmentGroup ofNumber(int compartmentNumber)` and
  `String label(AppLocalizations l10n)`. ARB keys
  `diveLog_deco_groupFast`, `diveLog_deco_groupMedium`, `diveLog_deco_groupSlow`.

- [ ] **Step 1: Write the failing test**

```dart
test('groups compartments 1-5, 6-10 and 11-16', () {
  expect([for (var n = 1; n <= 16; n++) CompartmentGroup.ofNumber(n)], [
    ...List.filled(5, CompartmentGroup.fast),
    ...List.filled(5, CompartmentGroup.medium),
    ...List.filled(6, CompartmentGroup.slow),
  ]);
});
testWidgets('labels each group in English', ...);
// fast -> 'Fast, blood-rich tissue', medium -> 'Medium, muscle and skin',
// slow -> 'Slow, fat and bone'
```

- [ ] **Step 2: Run it, expect a compile failure.**
  `flutter test test/features/dive_log/presentation/widgets/compartment_group_test.dart`
- [ ] **Step 3: Add the three ARB keys (with `@` descriptions) and the enum.**
  `ofNumber`: `<= 5` fast, `<= 10` medium, else slow. Run `flutter gen-l10n`
  to compile (English only for now; Task 6 regenerates after translating).
- [ ] **Step 4: Run the test, expect PASS.**

### Task 2: Group line in the detail row and the tooltip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tissue_compartment_detail.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tissue_tooltip_text.dart`
- Test: `test/features/dive_log/presentation/widgets/compact_tissue_loading_card_test.dart`,
  `test/features/dive_log/presentation/widgets/tissue_tooltip_text_test.dart`

**Interfaces:** Consumes `CompartmentGroup.ofNumber(...).label(l10n)`.

- [ ] **Step 1: Failing tests.**
  - Card test `names the selected compartment's group on its own line under
    the number (issue #4503)`: with `_status` (compartment 1) the text
    `'Fast, blood-rich tissue'` is found once, its rect's top is below the
    bottom of `'Leading: #1'`, and the exchange badge text stays on the
    number's row (same vertical centre as `'Leading: #1'`).
  - Card test `fits the group line on a phone`: surface 334 px wide,
    `tester.takeException()` is null.
  - Tooltip test: the text for compartment 1 has `'Fast, blood-rich tissue'`
    as its second line, directly after `'Compartment 1'`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Detail row: a `Text` with the label style
  (`fontSize: 11`, `onSurfaceVariant`) after the number `Row`, `SizedBox(height: 2)`
  between. Tooltip: insert the label after the first line.
- [ ] **Step 4: Run both test files, expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): name the compartment's speed group beside its number`
  (with Task 1's files).

### Task 3: Help sheet rewrite (English)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` `info_term_tissueCompartment_body`
- Test: existing help sheet tests; add to `test/features/dive_log/presentation/info/`
  a check if a test file for `tissueLoadingInfo` exists there, else to the card test.

- [ ] **Step 1: Failing test** `the compartments entry names the three groups`:
  the term body contains `'1-5'`, `'6-10'`, `'11-16'` and
  `'rough examples, not anatomy'`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: New value:**
  "The model's 16 imaginary tissues, each taking up and releasing gas at its
  own speed. 1-5 are fast, like blood-rich tissue such as the brain and spinal
  cord, and limit short, deep dives. 6-10 are medium, like muscle and skin.
  11-16 are slow, like fat and bone, and limit long and repeat dives. The
  tissue names are rough examples, not anatomy."
- [ ] **Step 4: Run, expect PASS. Commit** `feat(dive-log): explain the compartment groups in the help sheet`.

### Task 4: Numbered bars

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart`
- Test: `test/features/dive_log/presentation/widgets/compact_tissue_loading_card_test.dart`

- [ ] **Step 1: Failing tests.**
  - `numbers every bar under its own bar (issue #4503)`: with a 16-compartment
    status from `BuhlmannAlgorithm().compartments`, texts `'1'` to `'16'` each
    found once under `TissuePressureBarChart`; for each n, the number's
    centre x is within 1 px of bar n's cell centre (the n-th `Expanded` in the
    bar `Row`), for `TextDirection.ltr` and `rtl`.
  - `keeps the numbers inside their cells at 2x text scale`: 334 px surface,
    `MediaQuery(textScaler: TextScaler.linear(2))`, no exception.
  - The numbers row is excluded from semantics (the chart's own label speaks).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** a `Row` of `Expanded` cells mirroring the bars'
  `Padding(horizontal: 0.5)`, each `ExcludeSemantics` > `FittedBox(scaleDown)` >
  `Text('${comp.compartmentNumber}', style: labelStyle)`, placed between the
  bar `SizedBox` and the Fast / Slow row, `SizedBox(height: 2)` above it.
- [ ] **Step 4: Run, expect PASS. Also run**
  `test/features/dive_log/presentation/widgets/deco_info_panel_tissue_chart_test.dart`.
- [ ] **Step 5: Commit** `feat(dive-log): number the tissue bars`.

### Task 5: Heat map axes and the time input

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/tissue_heat_map_axes.dart`
- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
  (heat map section, new field)
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_deco_sections.dart`
  (`buildTissueCard`)
- Test: `test/features/dive_log/presentation/widgets/tissue_heat_map_axes_test.dart`,
  card test

**Interfaces:**
- Produces: `CompactTissueLoadingCard({..., List<int>? profileTimestamps})`,
  seconds from dive start, one per `decoStatuses` entry.
- Produces: `class TissueHeatMapCompartmentAxis extends StatelessWidget`
  `({required int compartmentCount})`, labels the first, middle
  (`(count + 1) ~/ 2`, 8 for 16) and last compartment, each `Align`ed to
  its row centre (`y = (row + 0.5) / count * 2 - 1`), fixed width 18.
- Produces: `class TissueHeatMapTimeAxis extends StatelessWidget`
  `({required List<int> timestamps})`, three labels at 0, 0.5 and 1 of the
  width (start aligned, centred, end aligned), values
  `timestamps[i] - timestamps.first` in whole minutes for i = 0,
  `timestamps.length ~/ 2`, last, through `l10n.diveLog_deco_minutesValue`.
- Produces: `static bool TissueHeatMapTimeAxis.fits(List<int>? timestamps, int sampleCount)`:
  non-null, length equal to `sampleCount`, and `sampleCount >= 2`.

- [ ] **Step 1: Failing tests.**
  - Axes test `places 1, 8 and 16 on their rows`: 16 compartments, axis in a
    160 px tall box; centres of `'1'`, `'8'`, `'16'` at y 5, 75, 155 (+-1).
  - Axes test `reads start, middle and end in minutes`: timestamps
    `[0, 60, ..., 1920]` (33 samples) give `'0 min'`, `'16 min'`, `'32 min'`;
    left edge, centre, right edge order.
  - Axes test `fits`: false for null, for length mismatch, for one sample.
  - Card test `labels the heat map with compartments and dive time (issue #4503)`:
    with `profileTimestamps`, finds both axes and no `diveLog_deco_heatMapRows`
    caption; the strip and the time axis share left and right edges.
  - Card test `leaves the time axis out without matching timestamps`:
    null and a mismatched list each show `TissueHeatMapCompartmentAxis` and no
    `TissueHeatMapTimeAxis`.
  - Card test: both axes keep left-to-right order under `TextDirection.rtl`
    (`'0 min'` left of `'32 min'`, compartment axis left of the strip).
  - Update the existing `heatmap labels` tests: the caption assertion becomes
    `findsNothing`; the expanded-mode test checks the compartment axis
    stretches (label `'16'` near the strip's bottom).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** In the card's heat map section, wrap the strip and
  axes in `Directionality(textDirection: TextDirection.ltr)`: a `Row`
  (stretch) of the compartment axis and the strip (`Expanded`), then, when
  `fits`, the time axis indented by the axis width. Remove the
  `diveLog_deco_heatMapRows` caption; the legend keeps its own direction
  (outside the forced LTR). Axis text is `ExcludeSemantics`. Pass
  `profileTimestamps: [for (final p in chartProfile) p.timestamp]` from
  `buildTissueCard`.
- [ ] **Step 4: Run the axes, card and `test/features/dive_log/presentation/widgets/dive_detail/`
  tests, expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): add compartment and time axes to the heat map`.

### Task 6: Translations

**Files:** the 10 locale ARBs and generated `app_localizations_*.dart`.

- [ ] **Step 1:** Insert `diveLog_deco_groupFast/Medium/Slow` after each
  locale's `diveLog_deco_compartmentOther` line, and rewrite each locale's
  `info_term_tissueCompartment_body` with the same meaning, matching that
  locale's existing terms for compartment and tissue.
- [ ] **Step 2:** `flutter gen-l10n`; check `grep -A1 "get diveLog_deco_groupFast" lib/l10n/arb/app_localizations_de.dart`
  shows German; `git diff --numstat lib/l10n/arb/` rows are even across locales.
- [ ] **Step 3:** Remove `diveLog_deco_heatMapRows` from every ARB if no code
  references it any more (`grep -rn heatMapRows lib test`), regenerate.
- [ ] **Step 4: Commit** `i18n(dive-log): translate the compartment groups and help text`.

### Task 7: Checks and after screenshots

- [ ] `dart format .`, `flutter analyze` (whole repo, clean),
  `flutter test test/architecture/`, the touched test files.
- [ ] After screenshots with the throwaway harness (not committed), same
  three shots as before, plus the card at 334 px under `TextDirection.rtl`
  is checked for overflow in tests only.
