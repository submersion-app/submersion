# Pinned Profile Strip Styling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pinned profile strip an NDL line, deco stop and ceiling bands, and a max-depth marker, and move its values from a fixed row into a compact floating tooltip.

**Architecture:** `PinnedStripPainter` gains the new layers, fed from the same analysis curves the full chart draws and sampled once per curve through an `Expando` cache, as the depth curve already is. The values row and hint leave `PinnedProfileStrip`; a new compact tooltip widget renders through an `OverlayPortal` anchored to the strip with a `LayerLink`, so no ancestor clip cuts it off. The strip shrinks from 56 to 44 px.

**Tech Stack:** Flutter, Riverpod, `CustomPainter`, `OverlayPortal` / `CompositedTransformFollower`, ARB l10n.

**Spec:** [docs/design/specs/2026-11-13-pinned-profile-strip-styling-design.md](../specs/2026-11-13-pinned-profile-strip-styling-design.md)

**As built:** the spec's "As built" section records where the build departed from this plan (palette colours, ppO2 with its unit, NDL read from the NDL curve, tooltip semantics), and its design sections now carry the later changes: the NDL line only where it dips below the top, no max-depth label, and every layer condensing at full strength like the depth line.

## Global Constraints

- Depth line and fill unchanged: 1 px (`kProfileDepthLineWidth`), `GasColors.gradientColors(ProfileMetricColors.depth)`.
- Background stays `colorScheme.surfaceContainerLow`; no tint, no divider.
- Strip height `kPinnedStripHeight = 44`, all curve, 4 px pad above and below.
- NDL: `ProfileMetricColors.ndl`, 1.5 px, round joins, scale `ProfileMetricBands.ndl` (0 s at the curve area's bottom, `fixedMax` 3600 s at its top, longer clamped), drawn only where NDL dips below the top and is above zero, reaching out to the at-the-top sample either side, never bridging a deco gap.
- Stop band: `decoStopBandColor` at `decoStopFillAlpha` plus a 1 px step edge; ceiling band: `ProfileMetricColors.ceiling` at `ceilingFillAlpha` plus a 1 px line; both from the surface (curve area top) down; the stop band steps square and holds each stop until the next sample (never past the curve's end).
- Max-depth marker: 3.5 px radius dot, `ProfileMetricColors.maxDepth`, 1 px ring in the surface colour; no depth label.
- New layers travel through the condense at full strength, like the depth line, and only cross-fade with the strip's surface.
- Tooltip: background `tooltipBackgroundColor`, text `tooltipTextColor`, 6 px bullets, labels at 70% alpha, values w600, 11 px tabular figures, radius 6, padding 7 x 5; 4 px below the strip, left edge 10 px right of the cursor, flipped to 10 px left of it when it would pass 8 px from the strip's right edge, clamped to 8 px from both edges; ignores pointers; shown only while the cursor is set and the strip is fully condensed.
- Units through `UnitFormatter`; every string through l10n. No em-dashes anywhere.

## Review Focus

- Dive with no analysis yet (analysis still loading, or null): strip draws the depth line and max-depth marker only, tooltip shows Time, Depth and ppO2 with `--` for missing values. Pinned in Task 2 and Task 3.
- Analysis curves shorter than the chart profile (a source switch mid-load): no layer reads past a curve's end. Pinned in Task 1.
- An NDL held at the top for the whole dive: no NDL line at all. Pinned in Task 1.
- An NDL of 999 min at the surface or a negative NDL in deco: clamped to the top, or treated as no line. Pinned in Task 1.
- Cursor at the very right edge of a narrow window: tooltip stays fully on screen. Pinned in Task 2.

---

### Task 1: Painter layers

> **Superseded in part.** Task 1 was built as written, then changed on review and request: the max-depth label and `maxDepthLabelOffset` were removed, the NDL line shows only below the top, the layers no longer fade with `morph`, and the cursor moved to `PinnedStripCursorPainter`. The steps below record the original build; the Global Constraints above and the spec describe what shipped.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart:3-4`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers_test.dart` (new)
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter_test.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry_test.dart`, `pinned_profile_overlay_test.dart` (replace literal `56` with `kPinnedStripHeight`)

**Interfaces:**
- Produces, in `pinned_strip_layers.dart`:
  - `class StripSeriesPoint { final int index; final double value; }` (const, immutable)
  - `List<List<StripSeriesPoint>> pinnedNdlRuns(List<int> ndlCurve)`: runs of samples with NDL > 0, each decimated with `decimateSeriesIndices` to at most `kPinnedStripPointBudget`, values clamped to `ProfileMetricBands.ndl.fixedMax`; cached per list in an `Expando`.
  - `List<List<StripSeriesPoint>> pinnedDepthRuns(List<double> curve, {bool stepped = false})`: runs where the value is > 0; `stepped: true` keeps only transitions (the sample before and at each change) so stop steps stay square; otherwise decimated as above; cached per list and mode.
  - `Offset maxDepthLabelOffset({required Offset dot, required Size label, required Size area, List<Offset> avoid = const []})`: top-left for the label, 6 px right of the dot, its bottom 2 px below the dot's centre; left of the dot instead when the right placement passes `area.width` or any `avoid` point lies in the right rect inflated by 2; clamped inside `area`.
  - `PinnedStripCurve` gains `final DiveProfilePoint? deepest`.
- Produces, on `PinnedStripPainter` (new optional parameters): `List<int>? ndlCurve`, `List<double>? ceilingCurve`, `List<double>? decoStopCurve`, `String? maxDepthLabel`, `Color maxDepthLabelColor`, `Color surfaceColor`. Curves index into `profile`. `kPinnedStripRowHeight` is removed.

- [ ] **Step 1: Write the failing layer tests** in `pinned_strip_layers_test.dart`:
  - `ndl runs break where NDL is spent`: curve `[600, 300, 0, -1, 0, 120]` gives two runs, indices `[0, 1]` and `[5]`.
  - `ndl clamps past an hour`: `[59940]` gives value `3600`.
  - `stepped depth runs keep only the steps`: `[0, 6, 6, 6, 3, 3, 0]` gives one run with indices `[1, 3, 4, 5]` and values `[6, 6, 3, 3]`.
  - `runs are worked out once per list`: `identical(pinnedNdlRuns(c), pinnedNdlRuns(c))`.
  - `label sits right of the dot`: dot `(100, 30)`, label `Size(30, 12)`, area `Size(400, 44)` gives `Offset(106, 20)`.
  - `label flips left at the right edge`: dot `(390, 30)` gives `dx == 390 - 6 - 30`.
  - `label flips left of an NDL point in the way`: dot `(100, 30)`, avoid `[Offset(115, 25)]` gives `dx == 64`.
- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers_test.dart`. Expected: FAIL, file not found.
- [ ] **Step 3: Implement `pinned_strip_layers.dart`** with the interfaces above.
- [ ] **Step 4: Run it again.** Expected: PASS.
- [ ] **Step 5: Write the failing painter tests** in `pinned_strip_painter_test.dart`. Change existing expectations of `kPinnedStripHeight - 16` to `kPinnedStripHeight` (the curve area is now the whole strip). Add:
  - `kPinnedStripHeight is 44`.
  - `draws the NDL line in the NDL colour`: with `ndlCurve: [3600, 1800, 0]`, `paints` includes a stroke `path(color: ProfileMetricColors.ndl, strokeWidth: 1.5)`.
  - `NDL at an hour sits at the top of the curve area, zero at the bottom`: through a new `@visibleForTesting Offset ndlPointFor(Size size, int index, double ndlSeconds)` on the painter, `ndlPointFor(Size(400, 44), 0, 3600).dy == 4` and `ndlPointFor(.., 0, 0).dy == 40`.
  - `shades stop and ceiling bands only with an obligation`: with all-zero `decoStopCurve`, no path in `decoStopBandColor`; with `[0, 6, 0]`, a fill path in `decoStopBandColor.withValues(alpha: decoStopFillAlpha)`.
  - `draws the max-depth dot at the deepest sample`: `paints..circle(x: <deepest x>, y: <deepest y>, radius: 3.5, color: ProfileMetricColors.maxDepth)`.
  - `new layers fade with the condense`: at `morph: 0.5` the NDL stroke colour's alpha is `0.5`.
  - `curves shorter than the profile draw no further`: `ndlCurve: [3600]` against the 3-point profile paints without throwing.
- [ ] **Step 6: Run** the painter test file. Expected: FAIL on the new tests.
- [ ] **Step 7: Implement.** In `pinned_strip_geometry.dart` set `kPinnedStripHeight = 44` and update its doc comment. In the painter, make `_curveAreaHeight` the whole `kPinnedStripHeight`, drop `kPinnedStripRowHeight`, add the parameters, and paint in this order: depth fill, stop band and edge, ceiling band and line, depth line, NDL line, max-depth dot and label (a `TextPainter`, `fontSize: 10`, `FontWeight.w600`, placed by `maxDepthLabelOffset` with the NDL line's projected points as `avoid`), cursor. Extend `shouldRepaint` with every new field.
- [ ] **Step 8: Update** `pinned_strip_geometry_test.dart` and `pinned_profile_overlay_test.dart`, replacing the literal `56` with `kPinnedStripHeight`, then run the whole `test/features/dive_log/presentation/widgets/pinned_profile/` folder. Expected: PASS.
- [ ] **Step 9: Commit** `feat(dive-log): draw NDL, deco and max depth on the pinned strip`.

### Task 2: Compact tooltip

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip_test.dart` (new)
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values_test.dart`

**Interfaces:**
- Consumes: `PinnedStripValues`, `DecoSlot` (existing).
- Produces:
  - `PinnedStripValues` gains `final double? ceilingMeters`, read by `pinnedStripValuesAt` from `analysis.ceilingCurve` at the index (null past its end).
  - `List<TooltipRow> pinnedStripTooltipRows(PinnedStripValues values, UnitFormatter units, AppLocalizations l10n)`, replacing `formatPinnedStripValues`. Rows: `diveLog_tooltip_time` (`formatMinutesSeconds`, grey bullet `Colors.grey`), `diveLog_tooltip_depth` (`formatDepth`, `ProfileMetricColors.depth`), `diveLog_tooltip_ppO2` (2 decimals, `Colors.teal`), then for `NdlSlot` `diveLog_tooltip_ndl` with `diveLog_deco_minutesValue` (`'>99'` past 99 minutes) and `ProfileMetricColors.ndl`; for `StopSlot` `diveLog_tooltip_decoStop` with `'<depth, 0 decimals> · <diveLog_deco_minutesValue(ceil minutes)>'` and `decoStopBandColor`, then `diveLog_tooltip_ceiling` with `formatDepth(ceilingMeters)` and `ProfileMetricColors.ceiling`; for `UnknownDecoSlot` an NDL row reading `--`. A missing value reads `--`.
  - `double pinnedTooltipLeft({required double cursorX, required double tooltipWidth, required double stripWidth})` per the Global Constraints rule.
  - `class PinnedStripTooltip extends StatelessWidget { const PinnedStripTooltip({required List<TooltipRow> rows}); }`: the compact box.

- [ ] **Step 1: Write the failing tests.** In `pinned_strip_values_test.dart`, replace the `formatPinnedStripValues` group with `pinnedStripTooltipRows`, keeping every case it had (metric, sign before the start, `>99`, exactly 99, stop rounded up, imperial, missing as `--`) as row values, and add:
  - `in deco: Deco stop and Ceiling rows, no NDL row`: labels `['Time', 'Depth', 'ppO2', 'Deco stop', 'Ceiling']`, stop value `'6m · 4 min'`, ceiling `'5.1m'`.
  - `reads the ceiling at the index`, and `a ceiling curve shorter than the index gives null`.
  In `pinned_strip_tooltip_test.dart`:
  - `left of the box is 10 px right of the cursor`: `pinnedTooltipLeft(cursorX: 100, tooltipWidth: 120, stripWidth: 390) == 110`.
  - `flips left near the right edge`: cursorX `300` gives `170`.
  - `stays on screen at the right edge`: cursorX `389` gives `<= 390 - 8 - 120`, `>= 8`.
  - `stays on screen when wider than the room either side`: cursorX `100`, width `300`, strip `320` gives `8`.
  - `renders a row's label and value with its bullet colour` (widget test).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** the interfaces above.
- [ ] **Step 4: Run** both files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): add the pinned strip's compact tooltip`.

### Task 3: Wire the strip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip_test.dart`

**Interfaces:**
- Consumes: Task 1 painter parameters, Task 2 `pinnedStripTooltipRows`, `pinnedTooltipLeft`, `PinnedStripTooltip`.

- [ ] **Step 1: Write the failing widget tests**, replacing the three hint tests and `shows four values when the cursor is set`:
  - `no tooltip and no hint with no cursor`: `find.byType(PinnedStripTooltip)` and `find.text('Drag to scrub')` find nothing.
  - `shows the tooltip below the strip when the cursor is set`: cursor `75` shows `12:30`, `30.0m`, `1.12`, `14 min`; the tooltip's top is `strip.bottom + 4`.
  - `the tooltip is not clipped by the strip`: the tooltip lies wholly below the strip's rect.
  - `the tooltip goes when the cursor clears` (mouse exit).
  - `no tooltip mid-condense` (`condense: 0.5`, cursor set).
  - `semantics value reads the tooltip rows while scrubbing`: semantics value contains `Time 12:30` and `NDL 14 min`.
  - `passes the analysis curves to the painter`: the `PinnedStripPainter` found under the strip has `ndlCurve` identical to the analysis's.
  - Replace `mid-condense the curve fills the height and the row fades in` with `mid-condense the curve fills the height`.
- [ ] **Step 2: Run** the strip test file. Expected: FAIL.
- [ ] **Step 3: Implement.** Remove `_Hint`, `_ValuesRow`, `_touch`, `_noteKind` and the `Listener` around the `MouseRegion`, plus the values-row `Positioned`. Wrap the strip in a `CompositedTransformTarget` with a `LayerLink`, and an `OverlayPortal` whose child is that target and whose `overlayChildBuilder` places `CompositedTransformFollower(link, targetAnchor: Alignment.bottomLeft, offset: Offset(0, 4), showWhenUnlinked: false)` inside an `Align(alignment: Alignment.topLeft)`. The follower's child is a `SizedBox(width: <strip width>, height: 240)` holding an `IgnorePointer` and a `CustomSingleChildLayout` whose delegate places `PinnedStripTooltip(rows)` at `x = pinnedTooltipLeft(cursorX, childSize.width, stripWidth)`, `y = 0`, so the box's real width decides the flip. Show the portal (`controller.show()`) after the frame when the rows are non-empty and `condense >= 1`, and hide it otherwise. Feed the painter `analysis?.ndlCurve`, `ceilingCurve`, `decoStopCurve`, the max-depth label `units.formatDepth(pinnedStripCurve(profile).deepest?.depth)`, `maxDepthLabelColor` per brightness, and `surfaceColor: colors.surfaceContainerLow`. Give the `Semantics` a `value` of the rows as `'<label> <value>'` joined with `', '` while the cursor is set.
- [ ] **Step 4: Run** the whole `test/features/dive_log/presentation/widgets/pinned_profile/` folder and `test/features/dive_log/presentation/pages/` tests that mention `Pinned`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): float the pinned strip's values in a tooltip`.

### Task 4: Retire the old strings

**Files:**
- Modify: every `lib/l10n/arb/app_*.arb` holding `diveLog_pinnedStrip_ndl`, `_stop`, `_ppO2`, `_hintDrag`, `_hintHover` (and their `@` entries)
- Modify: `test/l10n/kept_english_values.dart` (drop those keys' entries)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: Confirm nothing uses them:** `grep -rn "pinnedStrip_\(ndl\|stop\|ppO2\|hint\)" lib test --include='*.dart' | grep -v app_localizations`. Expected: only `kept_english_values.dart`.
- [ ] **Step 2: Remove the keys** from every ARB with a short `python3.14` script that parses each file as JSON and writes it back with the same key order and indentation, then drop the entries from `kept_english_values.dart`.
- [ ] **Step 3: Regenerate** with `flutter gen-l10n`; run `flutter analyze` and `test/l10n/`. Expected: no issues, PASS.
- [ ] **Step 4: Commit** `refactor(dive-log): drop the pinned strip's unused strings`.

### Task 5: Finish

- [ ] **Step 1:** `dart format .`, `flutter analyze` (whole repo), `test/architecture/`, the pinned profile test folder. Expected: clean, PASS.
- [ ] **Step 2:** After screenshots of the strip (light and dark, no-deco and deco dive, idle and scrubbing, phone and desktop width), matching the before shots.
