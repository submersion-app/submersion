# Cylinders Tank Figure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Start / End / Used columns on the dive detail Cylinders card with an upright tank figure per cylinder that shows gas left (solid), gas used (tint) and short fill (empty), labelled with the three pressures.

**Architecture:** Pure geometry in `tank_fill_levels.dart` (fill fractions, label spreading, height by volume), a dumb `TankFigure` widget that paints the cylinder and positions pre-formatted labels, and a `CylinderBlock` that replaces `CylinderTableRow`. `CylindersCard` resolves pressures as today, builds the labels with l10n and the diver's units, and passes them down.

**Tech Stack:** Flutter, `CustomPainter`, Riverpod (unchanged providers), ARB l10n (11 locales).

**Spec:** [docs/design/specs/2026-10-28-cylinders-tank-figure-design.md](../specs/2026-10-28-cylinders-tank-figure-design.md). Issue #3773.

## Global Constraints

- Full height = rated working pressure (`tank.workingPressure`, else the preset's `workingPressureBar`), else start pressure; neither gives an empty outline.
- Solid zone colour = `GasColors.forGasMix(tank.gasMix)`; used zone = that colour alpha-blended over the card surface to an opaque value.
- Labels: "Start {pressure}", "End {pressure}", "Used {pressure}" with `pressure` from `units.formatPressure` (value plus unit); missing value shows "--". Used is bold.
- Every new string translated in all 11 ARB locales; column-label keys `diveLog_cylinders_column*` removed from all locales.
- No emojis, no em-dashes; files under 800 lines; `dart format .`.

## Review Focus

1. **Barely used tank (start 200, end 195):** labels must not overlap; pinned by `spreadLabels` tests and a widget test with that tank.
2. **Large text scale (2.0) at phone width (360):** no overflow; pinned by a card test at 360 px and `textScaler: TextScaler.linear(2)`.
3. **Imperial units:** labels read "Start 2900 psi" etc. while levels use bar; pinned by the existing imperial card test, updated.
4. **Overfill (start 220, rated 207):** figure full to the top, label still 220; pinned in `TankFillLevels` tests.
5. **End above start (sensor error):** outline only, no Used label; pinned in `TankFillLevels` and card tests.

---

### Task 1: Fill levels, label spreading, height by volume

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/tank_fill_levels.dart`
- Test: `test/features/dive_log/presentation/widgets/tank_fill_levels_test.dart`

**Interfaces:**
- Produces:
  - `class TankFillLevels { final double? end; final double? start; bool get hasFill; factory TankFillLevels.resolve({double? start, double? end, double? rated}); }` where `end` is the top of the solid zone and `start` the top of the used zone, both fractions of full height in [0, 1]; both null means empty outline.
  - `List<double> spreadLabels({required List<double> centres, required List<double> heights, required double extent, double gap = 2})` returning each label's top, in the given top-to-bottom order.
  - `double tankFigureHeight(double? volumeLiters)`: 64 at 5 L, 104 at 18 L, linear, clamped; null gives the 11.1 L height.

- [ ] **Step 1: Write the failing tests**

```dart
// TankFillLevels.resolve
expect(r(start: 200, end: 60, rated: 232), levels(end: 60 / 232, start: 200 / 232));
expect(r(start: 200, end: 60), levels(end: 60 / 200, start: 1.0));      // no rated: start is full
expect(r(start: 220, end: 100, rated: 207), levels(end: 100 / 207, start: 1.0)); // overfill clamps
expect(r(start: 200, end: 200, rated: 232), levels(end: 200 / 232, start: 200 / 232)); // not breathed
expect(r(start: 100, end: 150, rated: 232).hasFill, isFalse);            // end above start
expect(r(start: 200, rated: 232), levels(end: 200 / 232, start: 200 / 232)); // end missing: solid to start
expect(r(end: 60, rated: 232), levels(end: 60 / 232, start: 60 / 232));  // start missing, rated known
expect(r(end: 60).hasFill, isFalse);                                     // nothing to measure against
expect(r().hasFill, isFalse);
// spreadLabels
expect(spreadLabels(centres: [10, 50, 90], heights: [12, 12, 12], extent: 100), [4, 44, 84]);
final s = spreadLabels(centres: [20, 22, 24], heights: [12, 12, 12], extent: 100);
expect(s[1] >= s[0] + 14 && s[2] >= s[1] + 14, isTrue);                 // no overlap with gap 2
final b = spreadLabels(centres: [96, 98, 99], heights: [12, 12, 12], extent: 100);
expect(b.last + 12 <= 100 && b.first >= 0, isTrue);                      // kept in bounds
// tankFigureHeight
expect(tankFigureHeight(5), 64); expect(tankFigureHeight(18), 104);
expect(tankFigureHeight(2), 64); expect(tankFigureHeight(30), 104);
expect(tankFigureHeight(null), tankFigureHeight(11.1));
```

- [ ] **Step 2:** Run `flutter test test/features/dive_log/presentation/widgets/tank_fill_levels_test.dart`; expect compile failure.
- [ ] **Step 3: Implement** in `tank_fill_levels.dart`. `spreadLabels`: forward pass `top = max(centre - h/2, prevBottom + gap, 0)`, then backward pass pulling labels up so the last bottom is within `extent`. Callers guarantee `extent >= sum(heights) + gaps`.
- [ ] **Step 4:** Run the test; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): tank fill levels and label spreading for the cylinder figure`.

### Task 2: TankFigure widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/tank_figure.dart`
- Test: `test/features/dive_log/presentation/widgets/tank_figure_test.dart`

**Interfaces:**
- Consumes: `TankFillLevels`, `spreadLabels`, `tankFigureHeight` (Task 1).
- Produces: `TankFigure({Key? key, required TankFillLevels levels, required Color gasColor, required double? volumeLiters, required String startLabel, required String endLabel, String? usedLabel})`.

- [ ] **Step 1: Write the failing tests**
  - `shows the three labels`: pump with labels "Start 200 bar", "End 60 bar", "Used 140 bar"; each `findsOneWidget`.
  - `no used label when none is given`: `usedLabel: null`; `find.textContaining('Used')` `findsNothing`.
  - `reads the values as one node`: `tester.getSemantics(find.byType(TankFigure))` label equals `'Start 200 bar, End 60 bar, Used 140 bar'`.
  - `a barely used tank keeps its labels apart`: levels from start 200, end 195, rated 232; the three labels' `getRect` do not overlap.
  - `a bigger tank is drawn taller`: the `CustomPaint` inside a 5 L figure is shorter than in an 18 L one.
- [ ] **Step 2:** Run; expect compile failure.
- [ ] **Step 3: Implement.** Measure labels with `TextPainter` (bodySmall; used label w700; honour `MediaQuery.textScalerOf`). Extent = `max(valve + tankFigureHeight(volume), sum(label heights) + gaps)`; the cylinder is centred vertically in it. Width = body width (18 at 64 px to 28 at 104 px) + 12 + widest label. Paint body outline (`colorScheme.outline`), valve, clipped solid zone (`gasColor`), used zone (`Color.alphaBlend(gasColor.withValues(alpha: 0.35), surface)` where surface is `cardTheme.color ?? colorScheme.surfaceContainerLow`), a tick at each level and a bracket over the used zone; leader lines from a moved label to its level (`onSurfaceVariant`). A label with no level ("--") centres on the top (start) or bottom (end) of the body. Labels are `Positioned` `Text`s in a `Stack`; the whole is one `Semantics(container: true, excludeSemantics: true, label: ...)`.
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): tank figure with gas left, used and short fill`.

### Task 3: Cylinder block and card wiring, strings

**Files:**
- Rename: `lib/features/dive_log/presentation/widgets/cylinder_table.dart` to `cylinder_block.dart`: replace `CylinderTableHeader`, `CylinderTableRow` and `CylinderColumnLabels` with `CylinderBlock`; keep `DotJoinedWrap`.
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_test.dart`, `cylinders_card_role_test.dart`

**Interfaces:**
- Consumes: `TankFigure`, `TankFillLevels.resolve` (Tasks 1-2).
- Produces: `CylinderBlock({Key? key, required Widget figure, required IconData icon, required String title, List<Widget> subtitle = const [], required GasMix gasMix, List<Widget> details = const [], Widget? trailing})`.
- New ARB keys (placeholder `pressure`, String): `diveLog_cylinders_figureStart` "Start {pressure}", `diveLog_cylinders_figureEnd` "End {pressure}", `diveLog_cylinders_figureUsed` "Used {pressure}". Removed: `diveLog_cylinders_columnTank`, `columnGas`, `columnStart`, `columnEnd`, `columnUsed`.

- [ ] **Step 1: Update the failing tests** in `cylinders_card_test.dart`:
  - first test: no "Tank"/"Gas" headers; `find.text('Start 200 bar')`, `'End 50 bar'`, `'Used 150 bar'` each `findsOneWidget`; title, pill, MOD/MND as before.
  - missing pressure: `'Start --'`, `'End --'`, no Used label.
  - not breathed (200/200): `'Used 0 bar'`.
  - end above start (100/150): `'Start 100 bar'`, `'End 150 bar'`, no Used.
  - imperial: labels end in `psi`.
  - replace "pressure columns line up", "each pressure cell reads out its column", "the tank and gas cells read out their column", "a missing pressure is read out without a unit" with: the figure reads `'Start 200 bar, End 50 bar, Used 150 bar'`; a missing pressure reads `'Start --'`.
  - narrow group: add a 360 px pump at `TextScaler.linear(2)` with three tanks; `tester.takeException()` is null.
  - rated pressure: a tank with `presetName: 'al80'`, no `workingPressure`, start 190: the figure's levels come from 206.843 (assert via `TankFigure.levels.start` closeTo `190 / 206.843`).
  - Keep every other test's intent (SAC, RMV, serial, check-in, badges, reassign, role); adjust only finders that relied on the table.
- [ ] **Step 2:** Run both card test files; expect failures.
- [ ] **Step 3: Implement.** ARB keys in every locale next to `diveLog_cylinders_gasUsed` (feature-grouped), with translations; delete the column keys; `flutter gen-l10n`. `CylinderBlock`: `Row(figure, 12, Expanded(Column(Wrap(icon, title, pill), subtitle, details + trailing)))`. Card: drop the header and its `Divider`; per tank resolve rated (`tank.workingPressure ?? preset?.workingPressureBar`) and volume (`tank.volume ?? preset?.volumeLiters`), build labels via `units.formatPressure`, Used label only when used >= 0; the MOD note and its spacing stay as main has them.
- [ ] **Step 4:** Run both card files plus `test/l10n/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): draw each cylinder as a tank figure on the Cylinders card`.

### Task 4: Verification

- [ ] `dart format .`, `flutter analyze` (no issues), `flutter test test/features/dive_log test/architecture test/shared test/l10n`.
- [ ] After screenshots with the same throwaway harness as the before set; delete it and its goldens before committing anything else.
