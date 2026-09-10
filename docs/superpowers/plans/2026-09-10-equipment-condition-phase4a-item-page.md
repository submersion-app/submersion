# Equipment Condition Intelligence, Phase 4a: Item Page Condition Section

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the condition intelligence in front of the diver on the equipment detail page: an exposure card (totals per unit, dive count, date range), a findings list with composed sentences, dismissal and evidence dives, a trend chart per item type with the tapped finding's window shaded, and a children card with a one-tap replace.

**Architecture:** Everything reads what phases 1 to 3b already store. Finding sentences are composed at render time from `FindingEvidence` through localized templates with values in the diver's units (`condition_finding_text.dart`, mirroring `safety_finding_text.dart`). Exposure totals and trend series are derived on read by two new `FutureProvider.family` providers over the same exposure samples and sensor summaries the engine uses. `DiveTrendChart` gains an optional list of secondary series drawn on the same axes and an optional shaded highlight range; the statistics charts are untouched. The children card's replace is one repository method that retires the old child and creates its successor under the same parent and slot. Each card is its own file and its own test, wired into the page last.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, fl_chart 1.x, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Condition findings: Evidence and wording, Dismissal; Surfaces: Equipment detail: condition section). Phase 4b (badges, trip margin, pre-dive snapshot, statistics) stacks on this branch.

**Decisions (asked and answered 2026-09-10):** phase 4 ships as 4a (this plan, item page) then 4b (elsewhere), stacked; the trend chart is `DiveTrendChart` extended with secondary series plus a shaded highlight range (chosen after three mockups); replace creates the successor inline after a confirm dialog, same type and name and slot, installed today, serial and notes empty; list badges (4b) raise on caution and significant findings only.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings, this plan). Rewrite the sentence instead.
- No mention of Claude, Claude Code or Anthropic in any commit, comment, file or PR body.
- Run `dart format .` before every commit. The pre-push hook runs format, analyze, l10n staleness and tests; push with `SKIP_TESTS=1` after a local full run.
- TDD: write the failing test first, run it, watch it fail for the right reason, then implement.
- Every user-facing string goes through `context.l10n` and is added to all 11 ARB files (`app_en.arb` alphabetical within its prefix block, the other ten anchored on the same neighbouring key). Regenerate with `flutter gen-l10n`; the generated `lib/l10n/arb/app_localizations*.dart` files are tracked and are staged with the ARB edits. Record every shipped translation in this plan's appendix.
- Anything that shows a unit goes through `UnitFormatter` (temperature, depth, dates via `formatDate` and `formatDateRange(start, end, l10n: l10n)`).
- No new schema rung: nothing in 4a touches the database shape.
- No sentence template contains a date prediction, a remaining life or a probability; the word "predict" appears nowhere.
- Every `EquipmentDetailPage` test (`grep -rln "EquipmentDetailPage(" test`, four files) overrides `equipmentComponentsProvider(<id>)` in one exact three-line shape; every new provider the page watches gets a sibling override at every site (Task 7).
- Tests importing both `drift` and `flutter_test` must `hide isNull, isNotNull` on the drift import; a `ProviderScope` that reaches `currentDiverIdProvider` needs `MockCurrentDiverIdNotifier`; the settings double is `MockSettingsNotifier` from `test/helpers/mock_providers.dart`.
- Commit after every task with the message given in the task. Never `git add -A`; stage the listed paths.

## File structure

Create:

- `lib/features/equipment/presentation/utils/condition_finding_text.dart`: `conditionFindingTitle`, `conditionFindingShortLabel`, `conditionSeverityColor`.
- `lib/features/equipment/domain/entities/equipment_exposure_totals.dart`: `EquipmentExposureTotals`.
- `lib/features/equipment/presentation/providers/equipment_exposure_providers.dart`: `equipmentExposureInputsProvider`, `equipmentExposureTotalsProvider`.
- `lib/features/equipment/presentation/widgets/exposure_card.dart`: `ExposureCard`.
- `lib/features/equipment/domain/entities/condition_trend.dart`: `ConditionTrendKind`, `ConditionTrendSeries`, `ConditionTrend`.
- `lib/features/equipment/domain/services/condition_trend_builder.dart`: pure `buildConditionTrend`.
- `lib/features/equipment/presentation/providers/condition_trend_providers.dart`: `equipmentConditionTrendProvider`, `selectedConditionFindingProvider`.
- `lib/features/equipment/presentation/widgets/condition_trend_card.dart`: `ConditionTrendCard`.
- `lib/features/equipment/presentation/widgets/condition_findings_card.dart`: `ConditionFindingsCard`, `hasVisibleConditionFindings`.
- `lib/features/equipment/presentation/widgets/condition_evidence_sheet.dart`: `showConditionEvidenceSheet`.
- `lib/features/equipment/presentation/providers/condition_evidence_providers.dart`: `conditionEvidenceDivesProvider`.
- `lib/features/equipment/presentation/widgets/children_card.dart`: `ChildrenCard`, `childHostTypes`.
- Tests beside each, under `test/features/equipment/...` and `test/features/statistics/presentation/widgets/dive_trend_chart_series_test.dart`.

Modify:

- `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`: `TrendSeries` (lives here, not in `trend_aggregation.dart`, which imports no Flutter), `secondarySeries`, `highlightRange`.
- `lib/features/equipment/data/repositories/equipment_repository_impl.dart`: `replaceChild`.
- `lib/features/equipment/presentation/pages/equipment_detail_page.dart`: the four cards.
- The 11 ARB files and their generated Dart.
- The four detail page test files.

---

### Task 0: Branch and plan

- [ ] `git checkout -b ericgriffin/equipment-condition-phase4a-item-page ericgriffin/equipment-condition-phase3b-engine` (done at plan time).
- [ ] Commit this plan: `git add docs/superpowers/plans/2026-09-10-equipment-condition-phase4a-item-page.md && git commit -m "docs(equipment): phase 4a plan, item page condition section"`.

---

### Task 1: Finding sentences

**Files:**
- Create: `lib/features/equipment/presentation/utils/condition_finding_text.dart`
- Test: `test/features/equipment/presentation/utils/condition_finding_text_test.dart`
- Modify: the 11 ARB files (keys below), generated l10n.

**Interfaces:**
- Consumes: `EquipmentFinding`, `FindingEvidence` (`n`, `windowStart`, `windowEnd`, `values`, `tag`, `slot`), `ConditionRuleId`, `ConditionSeverity`, `ObservationTag.fromDbValue` and `ObservationTag.localizedName(l10n)` (`observation_tag_display.dart`), `UnitFormatter` (`formatTemperature`, `formatDepth`, `formatDate`), `ExposureThresholds`.
- Produces:

```dart
String conditionFindingTitle(
  EquipmentFinding finding,
  AppLocalizations l10n,
  UnitFormatter units, {
  required ExposureThresholds thresholds,
});
String conditionFindingShortLabel(ConditionRuleId rule, AppLocalizations l10n);
String conditionFindingWindow(EquipmentFinding finding, AppLocalizations l10n, UnitFormatter units);
Color conditionSeverityColor(ConditionSeverity severity, ColorScheme scheme);
```

The engine's evidence keys (from `equipment_condition_engine.dart`): `cellOutputDeclining` `{recentMedian, baselineMedian}` with `value` the percent drop; `cellOutputLow` `{recentMedian}`; `cellDivergent` `{worstP95, count}`; `cellCurrentLimited` `{worstFraction, count}`; `transmitterDropoutRising` `{recentMean, priorMean}`; `transmitterDropoutHigh` `{recentMean, count}`; `issueRecurring` `{count}` plus `tag`; `issueColdCorrelated` `{coldIssueDives, coldDives, warmIssueDives, warmDives}`; `issueDeepCorrelated` `{deepIssueDives, deepDives, shallowIssueDives, shallowDives}`; `incidentLinked` `{count}`. Slot rules carry `slot`.

ARB keys, prefix `equipmentCondition_finding_`, anchored after `equipmentConditionSettings_title` in every file, including `app_en.arb` (the `equipmentConditionSettings_` block itself is not alphabetical, and `_` sorts after `S` in ASCII, so appending keeps the whole `equipmentCondition` block together):

| Key | English |
| --- | --- |
| `equipmentCondition_finding_cellOutputDeclining` | `Cell {slot} output fell {percent} percent across {n} dives since {since}` (placeholders slot int, percent String, n int, since String) |
| `equipmentCondition_finding_cellOutputLow` | `Cell {slot} output is {gain} mV per bar over the last {n} dives` |
| `equipmentCondition_finding_cellDivergent` | `Cell {slot} disagreed with its peers by up to {bar} bar on {count} of the last {n} dives` |
| `equipmentCondition_finding_cellCurrentLimited` | `Cell {slot} read low at high ppO2 on {count} of the last {n} dives, up to {percent} percent of samples` |
| `equipmentCondition_finding_transmitterDropoutRising` | `Pressure dropped out for {recent} percent of the last 5 dives, up from {prior} percent over the {priorCount} before` |
| `equipmentCondition_finding_transmitterDropoutHigh` | `Pressure dropped out for {recent} percent of the last {n} dives on average, {count} of them above 10 percent` |
| `equipmentCondition_finding_issueRecurring` | `{tag} reported {count} times in the last {n} dives` |
| `equipmentCondition_finding_issueColdCorrelated` | `{insideIssue} of {totalIssue} issue reports were on dives colder than {threshold}, over {n} dives with this item` |
| `equipmentCondition_finding_issueDeepCorrelated` | `{insideIssue} of {totalIssue} issue reports were on dives beyond {threshold}, over {n} dives with this item` |
| `equipmentCondition_finding_incidentLinked` | `{count, plural, =1{1 incident names this item} other{{count} incidents name this item}}` |
| `equipmentCondition_finding_window` | `{n, plural, =1{1 dive} other{{n} dives}}, {range}` |

Percentages are whole numbers (`(x * 100).round()` for fractions, `value.round()` for the decline). Gain and bar use one decimal through `toStringAsFixed(1)` (mV per bar and bar are not diver-configurable units). `since` is `units.formatDate(evidence.windowStart)`; `threshold` is `units.formatTemperature(thresholds.coldWaterC, decimals: 0)` or `units.formatDepth(thresholds.deepDiveM, decimals: 0)`; `range` is `units.formatDateRange(windowStart, windowEnd, l10n: l10n)`. A missing value key renders `--` for that slot of the sentence, never a fabricated 0 (same rule as the safety text). `conditionFindingShortLabel` reuses the ten `equipmentConditionSettings_rule_*` strings. `conditionSeverityColor`: info `scheme.onSurfaceVariant`, caution `scheme.tertiary`, significant `scheme.error` (the same three the service clock dots use, so one palette across the page).

- [ ] **Step 1: Write the failing test** covering: the decline sentence with slot, percent, n and date (`MockSettingsNotifier` settings, metric); the cold correlation sentence in Fahrenheit (`temperatureUnit: TemperatureUnit.fahrenheit` shows `50 °F` for the 10 C default); the recurring sentence uses the tag's localized name; the incident plural for 1 and 3; a finding with an empty `values` map renders `--` and does not throw; `conditionFindingWindow` for a one-dive window.
- [ ] **Step 2: Run** `flutter test test/features/equipment/presentation/utils/condition_finding_text_test.dart`, expect compile failure on the missing file.
- [ ] **Step 3: Add the 11 keys to the 11 ARB files** (script it like phase 3b Task 11: insert after the anchor, assert JSON still parses, no em-dash), `flutter gen-l10n`.
- [ ] **Step 4: Implement** the switch over `ConditionRuleId` with a local `num? v(String key) => finding.evidence.values[key]` and `String pct(num? x)`, `String one(num? x)` helpers.
- [ ] **Step 5: Run the test**, expect PASS. `flutter analyze` the two files.
- [ ] **Step 6: Commit** `feat(equipment): compose condition finding sentences in the diver's units (condition phase 4a)`; stage the util, the test, the 11 ARB files and `lib/l10n/arb/app_localizations*.dart`.

---

### Task 2: Exposure totals provider and card

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_exposure_totals.dart`, `lib/features/equipment/presentation/providers/equipment_exposure_providers.dart`, `lib/features/equipment/presentation/widgets/exposure_card.dart`
- Test: `test/features/equipment/presentation/providers/equipment_exposure_providers_test.dart`, `test/features/equipment/presentation/widgets/exposure_card_test.dart`
- Modify: ARB (keys below).

**Interfaces:**
- Consumes: `EquipmentRepository.getExposureSamplesForEquipment(id, parentEquipmentId:, installedSince:, rebreatherContact:)`, `getChildEquipment`, `ExposureClassifier(thresholds:, loopTimeOnly:, hasBatteryChild:).contribution(sample, unit)`, `exposureThresholdsProvider`, `ExposureUnitDisplay.intervalLabel(l10n)`.
- Produces:

```dart
class EquipmentExposureTotals extends Equatable {
  final Map<ExposureUnit, double> byUnit; // every unit except days
  final int diveCount;
  final DateTime? firstDive;
  final DateTime? lastDive;
  const EquipmentExposureTotals({required this.byUnit, required this.diveCount, this.firstDive, this.lastDive});
  static const empty = EquipmentExposureTotals(byUnit: {}, diveCount: 0);
}

/// (samples, classifier) for one item, the exact wiring `_evaluateClocksFor`
/// uses; shared by the totals and the trend providers.
typedef ExposureInputs = ({List<EquipmentExposureSample> samples, ExposureClassifier classifier, EquipmentItem item, List<EquipmentItem> children});
final equipmentExposureInputsProvider = FutureProvider.family<ExposureInputs?, String>(...); // null for an unknown item; invalidateSelfWhen equipment changes and dive detail changes
final equipmentExposureTotalsProvider = FutureProvider.family<EquipmentExposureTotals, String>(...);
```

`ExposureCard({required String equipmentId})`: a `Card` in the ServiceClocksCard style (icon `Icons.waves`, title `equipmentCondition_exposure_title`), then a `Wrap` of chips, one per unit with a non-zero total, labelled `intervalLabel` plus the number (hours one decimal, counts whole), and a footer line `equipmentCondition_exposure_footer` (`{n, plural, =1{1 dive} other{{n} dives}}, {range}`). Empty state `equipmentCondition_exposure_empty` ("No dives with this item yet"). The card renders for every type; it is the item's exposure, not a finding.

ARB keys (anchor after `equipmentCondition_finding_window`): `equipmentCondition_exposure_title` "Exposure", `equipmentCondition_exposure_footer`, `equipmentCondition_exposure_empty`.

- [ ] **Step 1: Provider test (red)**: in-memory DB via `setUpTestDatabase`, one regulator, three dives (one cold at 5 C, one deep at 35 m, one plain) linked through `dive_equipment`, `MockSettingsNotifier` for thresholds; assert `byUnit[coldDives] == 1`, `[deepCycles] == 1`, `[dives] == 3`, `[hours]` equals the runtime sum in hours, `diveCount == 3`, `firstDive`/`lastDive` are the oldest and newest; an unknown id returns `empty`; lowering the cold threshold to 4 through the mock drops `coldDives` to 0 after `container.invalidate`.
- [ ] **Step 2: Run red.** Expect the missing-file compile error.
- [ ] **Step 3: Implement** the entity and both providers. The inputs provider copies the parent/children/isRebreather block from `_evaluateClocksFor` (equipment_providers.dart lines 700 to 722); do not refactor `_evaluateClocksFor` itself in this PR.
- [ ] **Step 4: Run green.**
- [ ] **Step 5: Card test (red)**: override `equipmentExposureTotalsProvider('reg')` with fixed totals, `settingsProvider` with `MockSettingsNotifier`; expect the "Cold dives" chip text, the footer with `3 dives`, and the empty state when `empty`.
- [ ] **Step 6: Add the three keys to 11 ARB files**, `flutter gen-l10n`, implement the card, run green.
- [ ] **Step 7: Commit** `feat(equipment): exposure totals provider and card (condition phase 4a)`.

---

### Task 3: DiveTrendChart secondary series and highlight range

**Files:**
- Modify: `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`
- Test: `test/features/statistics/presentation/widgets/dive_trend_chart_series_test.dart`

**Interfaces:**
- Produces:

```dart
/// A named series drawn beside the primary points on the same axes.
class TrendSeries {
  final String label;
  final List<TrendDataPoint> points;
  final Color color;
  const TrendSeries({required this.label, required this.points, required this.color});
}

// DiveTrendChart gains:
final List<TrendSeries> secondarySeries; // default const []
final ({DateTime start, DateTime end})? highlightRange; // default null
```

Behaviour: secondary series are aggregated with the same `aggregate(points, aggregation)` call and drawn exactly like the primary (dots only in raw mode, stroke when aggregated) in their own colour, appended to `_bars` AFTER the primary, its band bounds, the rolling mean and the fit, so `barIndex 0` stays the primary and the tap-through logic is unchanged. Their labels join `_seriesLabels` in the same order so the tooltip names them. The y axis includes their values (`ChartAxis.forTrend` gets their min and max too). `highlightRange` becomes one `VerticalRangeAnnotation` from `_x(start)` to `_x(end)` in `colorScheme.tertiary.withValues(alpha: 0.18)` through `LineChartData.rangeAnnotations` (fl_chart 1.x, the same class `dive_profile_chart.dart` uses at line 6717). The chart's empty check stays on the primary points: a chart with an empty primary and non-empty secondaries still draws (the cell chart has no primary), so change the guard to `widget.points.isEmpty && widget.secondarySeries.every((s) => s.points.isEmpty)`. With an empty primary, `buckets` is empty; take the x range and `_drawnBuckets` from the first non-empty series instead (helper `_anchorPoints()` returning the primary when non-empty else the first non-empty secondary).

- [ ] **Step 1: Test (red)**: two secondary series of 6 points each with an empty primary: `lineBarsData` has 2 bars, colours match, `minX`/`maxX` span the series; with a primary plus one secondary in raw mode the secondary bar has `barWidth 0` and dots; with `aggregation: monthly` the secondary bar has `barWidth 2`; `highlightRange` set gives one `verticalRangeAnnotations` entry with `x1`/`x2` equal to the epoch millis; the tooltip label list (assert through `readData(tester).lineTouchData.touchTooltipData.getTooltipItems` on a synthetic spot list, as `dive_trend_chart_test.dart` does for its own tooltip) includes the series label; the y axis max is at least the secondary's max.
- [ ] **Step 2: Run red** (named parameter missing).
- [ ] **Step 3: Implement**, then run the whole `test/features/statistics/presentation/widgets/` folder to prove the existing chart tests still pass.
- [ ] **Step 4: Commit** `feat(statistics): DiveTrendChart secondary series and highlight range (condition phase 4a)`.

---

### Task 4: Condition trend provider and card

**Files:**
- Create: `lib/features/equipment/domain/entities/condition_trend.dart`, `lib/features/equipment/domain/services/condition_trend_builder.dart`, `lib/features/equipment/presentation/providers/condition_trend_providers.dart`, `lib/features/equipment/presentation/widgets/condition_trend_card.dart`
- Test: `test/features/equipment/domain/services/condition_trend_builder_test.dart`, `test/features/equipment/presentation/widgets/condition_trend_card_test.dart`
- Modify: ARB.

**Interfaces:**

```dart
enum ConditionTrendKind { cellGain, transmitterGapFraction, scrubberMinutes, minTemperature }

class ConditionTrendSeries extends Equatable {
  final String key;            // 'slot1', 'serial:ABC', 'scrubber', 'temp', 'issues'
  final int? slot;             // cell series only
  final List<TrendDataPoint> points;
}

class ConditionTrend extends Equatable {
  final ConditionTrendKind kind;
  final List<ConditionTrendSeries> series;
  static const empty = ConditionTrend(kind: ConditionTrendKind.minTemperature, series: []);
}

/// Pure. Which kind an item gets and its series, from the same inputs the
/// engine reads. Returns null for a type with no trend (mask, fins, tank).
ConditionTrend? buildConditionTrend({
  required EquipmentItem item,
  required EquipmentItem? parent,
  required List<EquipmentExposureSample> samples,       // date order
  required Map<String, DiveSensorSummary> summariesByDive,
  required List<EquipmentObservation> observations,
  required Set<String> transmitterSerials,
});

final equipmentConditionTrendProvider = FutureProvider.family<ConditionTrend?, String>(...);
/// The finding whose window the chart shades; toggled by the findings card.
final selectedConditionFindingProvider = StateProvider.family<EquipmentFinding?, String>((ref, id) => null);
```

Kind by type: `o2Cell` gives `cellGain` with one series for its `cellSlot` (from the parent's dives, which the exposure query already scopes); `rebreather` gives `cellGain` with one series per slot present in the summaries (1 to 6, sorted) and, when any summary carries `scrubberConsumedMinutes`, a SECOND trend `scrubberMinutes` (the provider returns the cell trend; the card asks the builder twice, once per kind, through an optional `kind:` argument, so the rebreather page shows two charts); `transmitter` gives `transmitterGapFraction` (gap seconds over dive seconds, per dive, for gaps whose serial is in `transmitterSerials`; several tanks on one dive average); `regulator`, `bcd`, `drysuit`, `light` give `minTemperature` (sample `minTemperature`, in Celsius; the card converts) plus an `issues` series holding only the dives that carry an issue observation for this item, so they draw as a second colour on the same axis; everything else null. `TrendDataPoint.diveId` is always set so a tap opens the dive.

`ConditionTrendCard({required EquipmentItem equipment})`: watches the trend provider, `selectedConditionFindingProvider(id)` for the highlight range, `settingsProvider` for `dateFormat`, and draws `DiveTrendChart(points: const [], secondarySeries: ..., highlightRange: ..., yAxisLabel: ..., valueFormatter: ..., height: 180, chartId: 'condition-<kind>', onDiveSelected: (id) => context.push('/dives/$id'))`. Series colours: slots 1 to 6 from a fixed six-colour list built from the theme (`primary`, `tertiary`, `secondary`, then their containers), the `issues` series in `colorScheme.error`. A legend row under the chart: one dot and label per series (`equipmentCondition_trend_cell` "Cell {slot}", `equipmentCondition_trend_issues` "Dives with an issue", `equipmentCondition_trend_scrubber`, `equipmentCondition_trend_gap`, `equipmentCondition_trend_temperature`). Card title per kind: `equipmentCondition_trend_title_cellGain` "Cell output per dive", `_gap` "Transmitter dropouts per dive", `_scrubber` "Scrubber use per dive", `_temperature` "Minimum temperature per dive". Y axis label per kind: `mV/bar`, `%`, minutes (`equipmentCondition_trend_axis_minutes` "min"), `units.temperatureSymbol`; the temperature value formatter converts through `units.convertTemperature`. Empty (null trend or every series empty): render nothing (`SizedBox.shrink`), the page adds no gap for it (Task 7 wraps the card in the same `if` the page uses for `UnitConfigurationsCard`).

ARB keys (anchor after `equipmentCondition_exposure_title`): the nine above.

- [ ] **Step 1: Builder test (red)**: pure, no DB. A rebreather with summaries for slots 1 and 2 on three dives yields two series of three points each with `diveId` set and gains in date order; an `o2Cell` child with `cellSlot 2` yields the slot-2 series only; a transmitter with serial `S1` and two gaps (`S1` 60 s of 600, `S2` ignored) yields one point at 0.1; a regulator with two dives, one with an issue observation, yields a `temp` series of two and an `issues` series of one; a mask yields null; a rebreather asked for `kind: scrubberMinutes` yields the scrubber series.
- [ ] **Step 2: Run red**, implement the entity and builder, run green.
- [ ] **Step 3: Card test (red)**: override `equipmentConditionTrendProvider('r1')` with a two-slot cell trend and `settingsProvider`; expect the title "Cell output per dive", a `DiveTrendChart` whose `secondarySeries` has length 2, the legend texts "Cell 1" and "Cell 2"; set `selectedConditionFindingProvider('r1')` to a finding whose window is the two middle dives and expect `highlightRange` non-null on the chart; a null trend renders no `Card`.
- [ ] **Step 4: Add the keys, gen-l10n, implement the provider and card**, run green.
- [ ] **Step 5: Commit** `feat(equipment): condition trend provider and chart card (condition phase 4a)`.

---

### Task 5: Findings card with dismissal and evidence dives

**Files:**
- Create: `lib/features/equipment/presentation/widgets/condition_findings_card.dart`, `lib/features/equipment/presentation/widgets/condition_evidence_sheet.dart`, `lib/features/equipment/presentation/providers/condition_evidence_providers.dart`
- Test: `test/features/equipment/presentation/widgets/condition_findings_card_test.dart`, `test/features/equipment/presentation/widgets/condition_evidence_sheet_test.dart`
- Modify: ARB.

**Interfaces:**
- Consumes: `equipmentConditionProvider(id)`, `conditionEngineEnabledProvider`, `conditionDisabledRulesProvider`, `setConditionFindingDismissed(ref, finding:, dismissed:)`, `selectedConditionFindingProvider(id)` (Task 4), `conditionFindingTitle` (Task 1), `DiveRepository.getSummariesByIds` (most recent first), `DiveSummary`.
- Produces:

```dart
bool hasVisibleConditionFindings(AppSettings settings, List<EquipmentFinding>? findings);
class ConditionFindingsCard extends ConsumerStatefulWidget { final EquipmentItem equipment; }
/// Keyed by the finding id; reads the finding's dive ids through the
/// findings provider so the family key stays a plain string.
final conditionEvidenceDivesProvider = FutureProvider.family<List<DiveSummary>, ({String equipmentId, String findingId})>(...);
Future<void> showConditionEvidenceSheet(BuildContext context, {required EquipmentItem equipment, required EquipmentFinding finding});
```

Card layout mirrors `SafetyReviewSection` minus the bulk action: `Card` with icon `Icons.insights_outlined` and title `equipmentCondition_findings_title` "Condition findings", trailing count; active findings as dense `ListTile`s (leading severity icon in `conditionSeverityColor`, title the sentence, subtitle `conditionFindingWindow`, trailing dismiss or restore `IconButton`); tapping a tile toggles `selectedConditionFindingProvider(id)` (which shades the chart, Task 4); a small `TextButton.icon` "Evidence dives" (`equipmentCondition_findings_evidence`) per tile opens the sheet; footer `TextButton` "Show {n} dismissed" (`equipmentCondition_findings_showDismissed`, plural) reveals the dismissed at 0.6 opacity. The card renders nothing when the master toggle is off or no finding survives the disabled-rule filter (`hasVisibleConditionFindings`), and the whole card hides while `equipmentConditionProvider` is loading for the first time (`.value == null`), so the page never shows a spinner for a rule engine.

The sheet: a `DraggableScrollableSheet`-free `showModalBottomSheet` with a title (`equipmentCondition_evidence_title` "Evidence dives"), the sentence, and one `ListTile` per `DiveSummary` (dive number and date on the title, depth and duration in the diver's units on the subtitle) that `context.push('/dives/<id>')` and pops. Evidence dive ids that no longer resolve are skipped silently (a deleted dive is not an error).

ARB keys (anchor after `equipmentCondition_findings_...` block start; place after `equipmentCondition_exposure_title`): `equipmentCondition_findings_title`, `equipmentCondition_findings_count` (`{count, plural, =1{1 finding} other{{count} findings}}`), `equipmentCondition_findings_evidence` "Evidence dives", `equipmentCondition_findings_dismiss` "Dismiss", `equipmentCondition_findings_restore` "Restore", `equipmentCondition_findings_showDismissed` (`{count, plural, =1{Show 1 dismissed} other{Show {count} dismissed}}`), `equipmentCondition_evidence_title`, `equipmentCondition_evidence_dive` (`Dive {number}`), `equipmentCondition_evidence_unnumbered` "Dive".

- [ ] **Step 1: Card test (red)**: overrides `equipmentConditionProvider('reg')` with three findings (info incidentLinked, caution issueRecurring, dismissed significant cellOutputLow on slot 1), `settingsProvider` with `MockSettingsNotifier`, `exposureThresholdsProvider` not needed (it derives from settings). Expect: two active tiles and the "Show 1 dismissed" button; tapping it reveals the third; with `conditionDisabledRules: {'issueRecurring'}` the recurring tile is absent and the count reads 1; with `conditionEngineEnabled: false` no `Card`; tapping a tile sets `selectedConditionFindingProvider('reg')` to that finding and tapping again clears it; the dismiss button calls the findings repository (override `equipmentFindingsRepositoryProvider` with a recording fake that `implements EquipmentFindingsRepository` and records `setDismissed` calls).
- [ ] **Step 2: Sheet test (red)**: override `conditionEvidenceDivesProvider((equipmentId: 'reg', findingId: 'f1'))` with two summaries; expect two tiles with the dive numbers and metric depths; imperial settings show feet.
- [ ] **Step 3: Run red, add keys, gen-l10n, implement**, run green.
- [ ] **Step 4: Mutation check**: invert the disabled-rule filter (`contains` to `!contains`) and confirm the card test fails; restore.
- [ ] **Step 5: Commit** `feat(equipment): condition findings card with dismissal and evidence dives (condition phase 4a)`.

---

### Task 6: Children card with replace

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`replaceChild`)
- Create: `lib/features/equipment/presentation/widgets/children_card.dart`
- Test: `test/features/equipment/data/repositories/equipment_replace_child_test.dart`, `test/features/equipment/presentation/widgets/children_card_test.dart`
- Modify: ARB.

**Interfaces:**

```dart
/// Retires [old] today and creates its successor: same diver, type, name,
/// brand, model and parent, the same `cell_slot` attribute when present,
/// `installed_date` set to [now], serial and notes empty, status active.
/// Both rows are marked pending for sync. Returns the new item.
Future<EquipmentItem> replaceChild(EquipmentItem old, {DateTime? now});

/// Types whose detail page shows the children card.
const childHostTypes = {EquipmentType.rebreather, EquipmentType.computer, EquipmentType.transmitter, EquipmentType.light, EquipmentType.dpv};
class ChildrenCard extends ConsumerWidget { final EquipmentItem equipment; }
final childEquipmentProvider = FutureProvider.family<List<EquipmentItem>, String>(...); // active children of a parent, cells sorted by slot then batteries by name; invalidateSelfWhen equipment changes
```

Card: title `equipmentCondition_children_title` "Installed parts", one `ListTile` per child: leading the type icon, title the child name (with `equipmentCondition_children_slot` "Slot {slot}" prefixed for cells), subtitle `equipmentCondition_children_installed` ("Installed {date}, {age}") where `age` is `equipmentCondition_children_age` (`{days, plural, =0{today} =1{1 day ago} other{{days} days ago}}`; over 60 days switch to `equipmentCondition_children_ageMonths` `{months} months ago`), trailing a worst-clock dot (from `equipmentWorstClockProvider`, the same map `ComponentsCard` reads) and a `PopupMenuButton` with "Replace" (`equipmentCondition_children_replace`) and "Open" (`equipmentCondition_children_open`, navigates to `/equipment/<childId>`). Replace shows an `AlertDialog` (`equipmentCondition_children_replaceTitle` "Replace {name}?", body `equipmentCondition_children_replaceBody` "{name} is retired today and a new {type} takes its place in the same slot. Serial and notes start empty.", actions cancel and `equipmentCondition_children_replaceConfirm` "Replace"), then calls `replaceChild`, invalidates `childEquipmentProvider(parentId)` and `equipmentConditionProvider(parentId)`, and shows a snackbar `equipmentCondition_children_replaced` "{name} replaced". Empty state `equipmentCondition_children_empty` "No cells or batteries recorded" with an "Add" `TextButton.icon` that pushes `/equipment/new` (the edit page's parent picker offers this parent; no query parameter exists, and adding one is out of scope).

- [ ] **Step 1: Repository test (red)**: in-memory DB; a rebreather `r1` with a cell child `c1` (cellSlot 2, serial `X`, installed 2026-01-01); `replaceChild(c1, now: 2026-09-10)` returns an item with a new id, `parentEquipmentId r1`, `cellSlot 2`, `installedDate 2026-09-10`, `serialNumber null`, `notes ''`; the old row has `isActive false` and `status retired`; both ids are pending in `sync_pending_records` (check through `SyncRepository` the way `equipment_repository_test.dart` does).
- [ ] **Step 2: Run red, implement**, run green.
- [ ] **Step 3: Card test (red)**: override `childEquipmentProvider('r1')` with a cell in slot 1 installed 40 days ago and a battery; `equipmentWorstClockProvider` with an overdue clock on the battery; `equipmentRepositoryProvider` with a fake recording `replaceChild`; expect "Slot 1" in the cell tile, "40 days ago", an error-coloured dot on the battery, and that choosing Replace then Confirm calls the fake once with the cell and shows "Cell 1 replaced"; a non-host type renders nothing.
- [ ] **Step 4: Add keys, gen-l10n, implement**, run green.
- [ ] **Step 5: Commit** `feat(equipment): children card with one-tap replace (condition phase 4a)`.

---

### Task 7: Wire the cards into the detail page

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- Modify tests: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`, `equipment_detail_rollup_test.dart`, `equipment_detail_service_test.dart`, `equipment_service_currency_test.dart`

Order after `ServiceClocksCard`: `ExposureCard`, `ConditionFindingsCard`, `ConditionTrendCard` (no gap when it renders nothing: give the card an `EdgeInsets` top margin inside itself instead of a page `SizedBox`), `ChildrenCard` (only for `childHostTypes`), then the existing `ObservationsCard`.

Every page test site overrides `equipmentComponentsProvider(equipment.id)` in the exact three-line shape; add siblings with the same regex-with-captured-indent approach phase 3a used:

```dart
              equipmentExposureTotalsProvider(
                equipment.id,
              ).overrideWith((ref) async => EquipmentExposureTotals.empty),
              equipmentConditionProvider(
                equipment.id,
              ).overrideWith((ref) async => const []),
              equipmentConditionTrendProvider(
                equipment.id,
              ).overrideWith((ref) async => null),
              childEquipmentProvider(
                equipment.id,
              ).overrideWith((ref) async => const []),
```

- [ ] **Step 1: Page test (red)**: add to `equipment_detail_page_test.dart` one case that overrides the four providers with real content (totals with 3 dives, one finding, a null trend, one child on a rebreather) and expects "Exposure", "Condition findings" and "Installed parts" on the page; and one for a mask that expects no "Installed parts".
- [ ] **Step 2: Run red, wire the page, add the overrides at every site**, run the four page test files green.
- [ ] **Step 3: Commit** `feat(equipment): condition section on the equipment detail page (condition phase 4a)`.

---

### Task 8: Wrap-up

- [ ] `dart format .`, `flutter analyze` (whole project, zero infos), `flutter gen-l10n && git status --short lib/l10n` (clean), em-dash scan over `lib/features/equipment lib/features/statistics test docs/superpowers/plans/2026-09-10-*`.
- [ ] Full suite once: `flutter test > <scratchpad>/full_4a.log 2>&1`.
- [ ] Mutation checks: (a) in `conditionFindingTitle` swap `recentMedian` and `baselineMedian` and confirm the decline sentence test fails; (b) in `buildConditionTrend` drop the serial filter and confirm the transmitter builder test fails; (c) in `replaceChild` skip the `cellSlot` copy and confirm the repository test fails. Restore each from a scratchpad backup, never with `git checkout`.
- [ ] Fill the Translation Appendix below with every shipped string per locale.
- [ ] Push `SKIP_TESTS=1 git push -u origin ericgriffin/equipment-condition-phase4a-item-page`; open the PR against `ericgriffin/equipment-condition-phase3b-engine` titled `feat(equipment): item page condition section (condition intelligence phase 4a)` with the repository template (Summary, Changes, Test Plan) and the test count.
- [ ] Update the program memory file with the PR number, the shapes phase 4b needs (`selectedConditionFindingProvider`, `EquipmentExposureTotals`, `childEquipmentProvider`, `TrendSeries`) and the execution lessons.

## Translation Appendix

Filled in at Task 8 with the strings that shipped, per locale, like the phase 3b plan.
