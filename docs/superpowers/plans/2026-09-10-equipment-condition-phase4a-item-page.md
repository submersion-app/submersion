# Equipment Condition Intelligence, Phase 4a: Item Page Condition Section

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the condition intelligence in front of the diver on the equipment detail page: an exposure card (totals per unit, dive count, date range), a findings list with composed sentences, dismissal and evidence dives, a trend chart per item type with the tapped finding's window shaded, and a children card with a one-tap replace.

**Architecture:** Everything reads what phases 1 to 3b already store. Finding sentences are composed at render time from `FindingEvidence` through localized templates with values in the diver's units (`condition_finding_text.dart`, mirroring `safety_finding_text.dart`). Exposure totals and trend series are derived on read by two new `FutureProvider.family` providers over the same exposure samples and sensor summaries the engine uses. `DiveTrendChart` gains an optional list of secondary series drawn on the same axes and an optional shaded highlight range; the statistics charts are untouched. The children card's replace is one repository method that retires the old child and creates its successor under the same parent and slot. Each card is its own file and its own test, wired into the page last.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, fl_chart 1.x, flutter_localizations with ARB files (11 locales), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-condition-intelligence-design.md` (sections Condition findings: Evidence and wording, Dismissal; Surfaces: Equipment detail: condition section). Phase 4b (badges, trip margin, pre-dive snapshot, statistics) stacks on this branch.

**Decisions (asked and answered 2026-09-10):** phase 4 ships as 4a (this plan, item page) then 4b (elsewhere), stacked; the trend chart is `DiveTrendChart` extended with secondary series plus a shaded highlight range (chosen after three mockups); replace creates the successor inline after a confirm dialog, same type and name and slot, installed today, serial and notes empty; list badges (4b) raise on caution and significant findings only.

## Global Constraints

- No em-dashes anywhere (code, comments, commit messages, ARB strings, this plan). Rewrite the sentence instead.
- No tool or vendor attribution in any commit, comment, file or PR body.
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

Kind by type: `o2Cell` gives `cellGain` with one series for its `cellSlot` (from the parent's dives, which the exposure query already scopes); `rebreather` gives `cellGain` with one series per slot present in the summaries (1 to 6, sorted) and, when any summary carries `scrubberConsumedMinutes`, a SECOND trend `scrubberMinutes` (the provider returns the cell trend; the card asks the builder twice, once per kind, through an optional `kind:` argument, so the rebreather page shows two charts); `transmitter` gives `transmitterGapFraction` (gap seconds over dive seconds, per dive, for gaps whose serial is in `transmitterSerials`; several matched tanks on one dive plot the worst of them, the same per-dive reading the dropout rules take, so the chart never shows a smaller number than the one a finding was raised on); `regulator`, `bcd`, `drysuit`, `light` give `minTemperature` (sample `minTemperature`, in Celsius; the card converts) plus an `issues` series holding only the dives that carry an issue observation for this item, so they draw as a second colour on the same axis; everything else null. `TrendDataPoint.diveId` is always set so a tap opens the dive.

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

Generated at Task 8 from the ARB files: every `equipmentCondition_` key this phase added (finding sentences, exposure card, trend card, findings card, evidence sheet, children card), per locale.

### en

- `equipmentCondition_children_title`: Installed parts
- `equipmentCondition_children_slot`: Slot {slot}
- `equipmentCondition_children_installed`: Installed {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{today} =1{1 day ago} other{{days} days ago}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{1 month ago} other{{months} months ago}}
- `equipmentCondition_children_replace`: Replace
- `equipmentCondition_children_open`: Open
- `equipmentCondition_children_replaceTitle`: Replace {name}?
- `equipmentCondition_children_replaceBody`: {name} is retired today and a new {type} takes its place in the same slot. Serial and notes start empty.
- `equipmentCondition_children_replaceConfirm`: Replace
- `equipmentCondition_children_replaceCancel`: Cancel
- `equipmentCondition_children_replaced`: {name} replaced
- `equipmentCondition_children_empty`: No cells or batteries recorded
- `equipmentCondition_children_add`: Add
- `equipmentCondition_findings_title`: Condition findings
- `equipmentCondition_findings_count`: {count, plural, =1{1 finding} other{{count} findings}}
- `equipmentCondition_findings_evidence`: Evidence dives
- `equipmentCondition_findings_dismiss`: Dismiss
- `equipmentCondition_findings_restore`: Restore
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Show 1 dismissed} other{Show {count} dismissed}}
- `equipmentCondition_evidence_title`: Evidence dives
- `equipmentCondition_evidence_dive`: Dive {number}
- `equipmentCondition_evidence_unnumbered`: Dive
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Cell output per dive
- `equipmentCondition_trend_title_gap`: Transmitter dropouts per dive
- `equipmentCondition_trend_title_scrubber`: Scrubber use per dive
- `equipmentCondition_trend_title_temperature`: Minimum temperature per dive
- `equipmentCondition_trend_cell`: Cell {slot}
- `equipmentCondition_trend_issues`: Dives with an issue
- `equipmentCondition_trend_scrubber`: Scrubber minutes
- `equipmentCondition_trend_gap`: Dropout share
- `equipmentCondition_trend_temperature`: Minimum temperature
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Exposure
- `equipmentCondition_exposure_empty`: No dives with this item yet
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 dive} other{{n} dives}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 dive} other{{n} dives}}
- `equipmentCondition_exposure_hours`: {n} hours
- `equipmentCondition_exposure_saltHours`: {n} salt-water hours
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 cold dive} other{{n} cold dives}}
- `equipmentCondition_exposure_o2Hours`: {n} high-O2 hours
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 deep dive} other{{n} deep dives}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 battery cycle} other{{n} battery cycles}}
- `equipmentCondition_finding_cellOutputDeclining`: Cell {slot} output fell {percent} percent across {n} dives since {since}
- `equipmentCondition_finding_cellOutputLow`: Cell {slot} output is {gain} mV per bar over the last {n} dives
- `equipmentCondition_finding_cellDivergent`: Cell {slot} disagreed with its peers by up to {bar} bar on {count} of the last {n} dives
- `equipmentCondition_finding_cellCurrentLimited`: Cell {slot} read low at high ppO2 on {count} of the last {n} dives, up to {percent} percent of samples
- `equipmentCondition_finding_transmitterDropoutRising`: Pressure dropped out for {recent} percent of the last 5 dives, up from {prior} percent over the {priorCount} before
- `equipmentCondition_finding_transmitterDropoutHigh`: Pressure dropped out for {recent} percent of the last {n} dives on average, {count} of them above 10 percent
- `equipmentCondition_finding_issueRecurring`: {tag} reported {count} times in the last {n} dives
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} of {totalIssue} issue reports were on dives colder than {threshold}, over {n} dives with this item
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} of {totalIssue} issue reports were on dives beyond {threshold}, over {n} dives with this item
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incident names this item} other{{count} incidents name this item}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 dive} other{{n} dives}}, {range}

### es

- `equipmentCondition_children_title`: Piezas instaladas
- `equipmentCondition_children_slot`: Ranura {slot}
- `equipmentCondition_children_installed`: Instalado el {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{hoy} =1{hace 1 día} other{hace {days} días}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{hace 1 mes} other{hace {months} meses}}
- `equipmentCondition_children_replace`: Sustituir
- `equipmentCondition_children_open`: Abrir
- `equipmentCondition_children_replaceTitle`: ¿Sustituir {name}?
- `equipmentCondition_children_replaceBody`: {name} se retira hoy y un nuevo {type} ocupa su lugar en la misma ranura. El número de serie y las notas empiezan vacíos.
- `equipmentCondition_children_replaceConfirm`: Sustituir
- `equipmentCondition_children_replaceCancel`: Cancelar
- `equipmentCondition_children_replaced`: {name} sustituido
- `equipmentCondition_children_empty`: No hay celdas ni baterías registradas
- `equipmentCondition_children_add`: Añadir
- `equipmentCondition_findings_title`: Hallazgos de estado
- `equipmentCondition_findings_count`: {count, plural, =1{1 hallazgo} other{{count} hallazgos}}
- `equipmentCondition_findings_evidence`: Inmersiones de evidencia
- `equipmentCondition_findings_dismiss`: Descartar
- `equipmentCondition_findings_restore`: Restaurar
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Mostrar 1 descartado} other{Mostrar {count} descartados}}
- `equipmentCondition_evidence_title`: Inmersiones de evidencia
- `equipmentCondition_evidence_dive`: Inmersión {number}
- `equipmentCondition_evidence_unnumbered`: Inmersión
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Salida de las celdas por inmersión
- `equipmentCondition_trend_title_gap`: Pérdidas de señal del transmisor por inmersión
- `equipmentCondition_trend_title_scrubber`: Uso del absorbente por inmersión
- `equipmentCondition_trend_title_temperature`: Temperatura mínima por inmersión
- `equipmentCondition_trend_cell`: Celda {slot}
- `equipmentCondition_trend_issues`: Inmersiones con un problema
- `equipmentCondition_trend_scrubber`: Minutos de absorbente
- `equipmentCondition_trend_gap`: Proporción de pérdidas
- `equipmentCondition_trend_temperature`: Temperatura mínima
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Exposición
- `equipmentCondition_exposure_empty`: Aún no hay inmersiones con este artículo
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 inmersión} other{{n} inmersiones}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 inmersión} other{{n} inmersiones}}
- `equipmentCondition_exposure_hours`: {n} horas
- `equipmentCondition_exposure_saltHours`: {n} horas en agua salada
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 inmersión fría} other{{n} inmersiones frías}}
- `equipmentCondition_exposure_o2Hours`: {n} horas con O2 alto
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 inmersión profunda} other{{n} inmersiones profundas}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 ciclo de batería} other{{n} ciclos de batería}}
- `equipmentCondition_finding_cellOutputDeclining`: La salida de la celda {slot} cayó un {percent} por ciento en {n} inmersiones desde el {since}
- `equipmentCondition_finding_cellOutputLow`: La salida de la celda {slot} es de {gain} mV por bar en las últimas {n} inmersiones
- `equipmentCondition_finding_cellDivergent`: La celda {slot} discrepó de sus pares hasta {bar} bar en {count} de las últimas {n} inmersiones
- `equipmentCondition_finding_cellCurrentLimited`: La celda {slot} leyó bajo a ppO2 alta en {count} de las últimas {n} inmersiones, hasta un {percent} por ciento de las muestras
- `equipmentCondition_finding_transmitterDropoutRising`: La presión se perdió durante el {recent} por ciento de las últimas 5 inmersiones, frente al {prior} por ciento en las {priorCount} anteriores
- `equipmentCondition_finding_transmitterDropoutHigh`: La presión se perdió durante el {recent} por ciento de las últimas {n} inmersiones de media, {count} de ellas por encima del 10 por ciento
- `equipmentCondition_finding_issueRecurring`: {tag} registrado {count} veces en las últimas {n} inmersiones
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} de {totalIssue} problemas registrados fueron en inmersiones más frías que {threshold}, en {n} inmersiones con este artículo
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} de {totalIssue} problemas registrados fueron en inmersiones más allá de {threshold}, en {n} inmersiones con este artículo
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incidente menciona este artículo} other{{count} incidentes mencionan este artículo}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 inmersión} other{{n} inmersiones}}, {range}

### de

- `equipmentCondition_children_title`: Eingebaute Teile
- `equipmentCondition_children_slot`: Steckplatz {slot}
- `equipmentCondition_children_installed`: Eingebaut am {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{heute} =1{vor 1 Tag} other{vor {days} Tagen}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{vor 1 Monat} other{vor {months} Monaten}}
- `equipmentCondition_children_replace`: Ersetzen
- `equipmentCondition_children_open`: Öffnen
- `equipmentCondition_children_replaceTitle`: {name} ersetzen?
- `equipmentCondition_children_replaceBody`: {name} wird heute stillgelegt und ein neues Teil vom Typ {type} übernimmt denselben Steckplatz. Seriennummer und Notizen beginnen leer.
- `equipmentCondition_children_replaceConfirm`: Ersetzen
- `equipmentCondition_children_replaceCancel`: Abbrechen
- `equipmentCondition_children_replaced`: {name} ersetzt
- `equipmentCondition_children_empty`: Keine Zellen oder Akkus erfasst
- `equipmentCondition_children_add`: Hinzufügen
- `equipmentCondition_findings_title`: Zustandsbefunde
- `equipmentCondition_findings_count`: {count, plural, =1{1 Befund} other{{count} Befunde}}
- `equipmentCondition_findings_evidence`: Belegtauchgänge
- `equipmentCondition_findings_dismiss`: Verwerfen
- `equipmentCondition_findings_restore`: Wiederherstellen
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{1 verworfenen anzeigen} other{{count} verworfene anzeigen}}
- `equipmentCondition_evidence_title`: Belegtauchgänge
- `equipmentCondition_evidence_dive`: Tauchgang {number}
- `equipmentCondition_evidence_unnumbered`: Tauchgang
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Zellenausgang je Tauchgang
- `equipmentCondition_trend_title_gap`: Senderaussetzer je Tauchgang
- `equipmentCondition_trend_title_scrubber`: Atemkalkverbrauch je Tauchgang
- `equipmentCondition_trend_title_temperature`: Mindesttemperatur je Tauchgang
- `equipmentCondition_trend_cell`: Zelle {slot}
- `equipmentCondition_trend_issues`: Tauchgänge mit Problem
- `equipmentCondition_trend_scrubber`: Atemkalkminuten
- `equipmentCondition_trend_gap`: Aussetzeranteil
- `equipmentCondition_trend_temperature`: Mindesttemperatur
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Belastung
- `equipmentCondition_exposure_empty`: Noch keine Tauchgänge mit diesem Teil
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 Tauchgang} other{{n} Tauchgänge}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 Tauchgang} other{{n} Tauchgänge}}
- `equipmentCondition_exposure_hours`: {n} Stunden
- `equipmentCondition_exposure_saltHours`: {n} Salzwasserstunden
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 kalter Tauchgang} other{{n} kalte Tauchgänge}}
- `equipmentCondition_exposure_o2Hours`: {n} Stunden mit hohem O2
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 tiefer Tauchgang} other{{n} tiefe Tauchgänge}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 Akkuzyklus} other{{n} Akkuzyklen}}
- `equipmentCondition_finding_cellOutputDeclining`: Der Ausgang von Zelle {slot} fiel über {n} Tauchgänge seit dem {since} um {percent} Prozent
- `equipmentCondition_finding_cellOutputLow`: Der Ausgang von Zelle {slot} liegt in den letzten {n} Tauchgängen bei {gain} mV pro bar
- `equipmentCondition_finding_cellDivergent`: Zelle {slot} wich bei {count} der letzten {n} Tauchgänge um bis zu {bar} bar von den anderen ab
- `equipmentCondition_finding_cellCurrentLimited`: Zelle {slot} las bei hohem ppO2 in {count} der letzten {n} Tauchgänge zu niedrig, bei bis zu {percent} Prozent der Messwerte
- `equipmentCondition_finding_transmitterDropoutRising`: Der Druck fiel bei {recent} Prozent der letzten 5 Tauchgänge aus, zuvor bei {prior} Prozent der {priorCount} davor
- `equipmentCondition_finding_transmitterDropoutHigh`: Der Druck fiel im Schnitt bei {recent} Prozent der letzten {n} Tauchgänge aus, bei {count} davon über 10 Prozent
- `equipmentCondition_finding_issueRecurring`: {tag} in den letzten {n} Tauchgängen {count}-mal gemeldet
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} von {totalIssue} gemeldeten Problemen traten bei Tauchgängen kälter als {threshold} auf, über {n} Tauchgänge mit diesem Teil
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} von {totalIssue} gemeldeten Problemen traten bei Tauchgängen tiefer als {threshold} auf, über {n} Tauchgänge mit diesem Teil
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 Vorfall nennt dieses Teil} other{{count} Vorfälle nennen dieses Teil}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 Tauchgang} other{{n} Tauchgänge}}, {range}

### fr

- `equipmentCondition_children_title`: Pièces installées
- `equipmentCondition_children_slot`: Emplacement {slot}
- `equipmentCondition_children_installed`: Installé le {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{aujourd'hui} =1{il y a 1 jour} other{il y a {days} jours}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{il y a 1 mois} other{il y a {months} mois}}
- `equipmentCondition_children_replace`: Remplacer
- `equipmentCondition_children_open`: Ouvrir
- `equipmentCondition_children_replaceTitle`: Remplacer {name} ?
- `equipmentCondition_children_replaceBody`: {name} est retiré aujourd'hui et un nouvel élément de type {type} prend sa place dans le même emplacement. Le numéro de série et les notes démarrent vides.
- `equipmentCondition_children_replaceConfirm`: Remplacer
- `equipmentCondition_children_replaceCancel`: Annuler
- `equipmentCondition_children_replaced`: {name} remplacé
- `equipmentCondition_children_empty`: Aucune cellule ni batterie enregistrée
- `equipmentCondition_children_add`: Ajouter
- `equipmentCondition_findings_title`: Constats d'état
- `equipmentCondition_findings_count`: {count, plural, =1{1 constat} other{{count} constats}}
- `equipmentCondition_findings_evidence`: Plongées à l'appui
- `equipmentCondition_findings_dismiss`: Ignorer
- `equipmentCondition_findings_restore`: Rétablir
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Afficher 1 ignoré} other{Afficher {count} ignorés}}
- `equipmentCondition_evidence_title`: Plongées à l'appui
- `equipmentCondition_evidence_dive`: Plongée {number}
- `equipmentCondition_evidence_unnumbered`: Plongée
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Sortie des cellules par plongée
- `equipmentCondition_trend_title_gap`: Pertes de signal de l'émetteur par plongée
- `equipmentCondition_trend_title_scrubber`: Usage de la chaux par plongée
- `equipmentCondition_trend_title_temperature`: Température minimale par plongée
- `equipmentCondition_trend_cell`: Cellule {slot}
- `equipmentCondition_trend_issues`: Plongées avec un problème
- `equipmentCondition_trend_scrubber`: Minutes de chaux
- `equipmentCondition_trend_gap`: Part des pertes
- `equipmentCondition_trend_temperature`: Température minimale
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Exposition
- `equipmentCondition_exposure_empty`: Aucune plongée avec cet équipement pour l'instant
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 plongée} other{{n} plongées}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 plongée} other{{n} plongées}}
- `equipmentCondition_exposure_hours`: {n} heures
- `equipmentCondition_exposure_saltHours`: {n} heures en eau salée
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 plongée froide} other{{n} plongées froides}}
- `equipmentCondition_exposure_o2Hours`: {n} heures à O2 élevé
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 plongée profonde} other{{n} plongées profondes}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 cycle de batterie} other{{n} cycles de batterie}}
- `equipmentCondition_finding_cellOutputDeclining`: La sortie de la cellule {slot} a chuté de {percent} pour cent sur {n} plongées depuis le {since}
- `equipmentCondition_finding_cellOutputLow`: La sortie de la cellule {slot} est de {gain} mV par bar sur les {n} dernières plongées
- `equipmentCondition_finding_cellDivergent`: La cellule {slot} a divergé des autres jusqu'à {bar} bar sur {count} des {n} dernières plongées
- `equipmentCondition_finding_cellCurrentLimited`: La cellule {slot} a lu trop bas à ppO2 élevée sur {count} des {n} dernières plongées, jusqu'à {percent} pour cent des mesures
- `equipmentCondition_finding_transmitterDropoutRising`: La pression a été perdue pendant {recent} pour cent des 5 dernières plongées, contre {prior} pour cent sur les {priorCount} précédentes
- `equipmentCondition_finding_transmitterDropoutHigh`: La pression a été perdue pendant {recent} pour cent des {n} dernières plongées en moyenne, dont {count} au-dessus de 10 pour cent
- `equipmentCondition_finding_issueRecurring`: {tag} signalé {count} fois sur les {n} dernières plongées
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} des {totalIssue} problèmes signalés concernaient des plongées plus froides que {threshold}, sur {n} plongées avec cet équipement
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} des {totalIssue} problèmes signalés concernaient des plongées au-delà de {threshold}, sur {n} plongées avec cet équipement
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incident mentionne cet équipement} other{{count} incidents mentionnent cet équipement}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 plongée} other{{n} plongées}}, {range}

### it

- `equipmentCondition_children_title`: Parti installate
- `equipmentCondition_children_slot`: Slot {slot}
- `equipmentCondition_children_installed`: Installato il {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{oggi} =1{1 giorno fa} other{{days} giorni fa}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{1 mese fa} other{{months} mesi fa}}
- `equipmentCondition_children_replace`: Sostituisci
- `equipmentCondition_children_open`: Apri
- `equipmentCondition_children_replaceTitle`: Sostituire {name}?
- `equipmentCondition_children_replaceBody`: {name} viene ritirato oggi e un nuovo elemento di tipo {type} ne prende il posto nello stesso slot. Numero di serie e note partono vuoti.
- `equipmentCondition_children_replaceConfirm`: Sostituisci
- `equipmentCondition_children_replaceCancel`: Annulla
- `equipmentCondition_children_replaced`: {name} sostituito
- `equipmentCondition_children_empty`: Nessuna cella o batteria registrata
- `equipmentCondition_children_add`: Aggiungi
- `equipmentCondition_findings_title`: Rilievi sullo stato
- `equipmentCondition_findings_count`: {count, plural, =1{1 rilievo} other{{count} rilievi}}
- `equipmentCondition_findings_evidence`: Immersioni a supporto
- `equipmentCondition_findings_dismiss`: Ignora
- `equipmentCondition_findings_restore`: Ripristina
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Mostra 1 ignorato} other{Mostra {count} ignorati}}
- `equipmentCondition_evidence_title`: Immersioni a supporto
- `equipmentCondition_evidence_dive`: Immersione {number}
- `equipmentCondition_evidence_unnumbered`: Immersione
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Uscita delle celle per immersione
- `equipmentCondition_trend_title_gap`: Perdite di segnale del trasmettitore per immersione
- `equipmentCondition_trend_title_scrubber`: Uso della calce per immersione
- `equipmentCondition_trend_title_temperature`: Temperatura minima per immersione
- `equipmentCondition_trend_cell`: Cella {slot}
- `equipmentCondition_trend_issues`: Immersioni con un problema
- `equipmentCondition_trend_scrubber`: Minuti di calce
- `equipmentCondition_trend_gap`: Quota di perdite
- `equipmentCondition_trend_temperature`: Temperatura minima
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Esposizione
- `equipmentCondition_exposure_empty`: Ancora nessuna immersione con questo articolo
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 immersione} other{{n} immersioni}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 immersione} other{{n} immersioni}}
- `equipmentCondition_exposure_hours`: {n} ore
- `equipmentCondition_exposure_saltHours`: {n} ore in acqua salata
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 immersione fredda} other{{n} immersioni fredde}}
- `equipmentCondition_exposure_o2Hours`: {n} ore ad alto O2
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 immersione profonda} other{{n} immersioni profonde}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 ciclo batteria} other{{n} cicli batteria}}
- `equipmentCondition_finding_cellOutputDeclining`: L'uscita della cella {slot} è calata del {percent} per cento in {n} immersioni dal {since}
- `equipmentCondition_finding_cellOutputLow`: L'uscita della cella {slot} è di {gain} mV per bar nelle ultime {n} immersioni
- `equipmentCondition_finding_cellDivergent`: La cella {slot} ha discordato dalle altre fino a {bar} bar in {count} delle ultime {n} immersioni
- `equipmentCondition_finding_cellCurrentLimited`: La cella {slot} ha letto basso ad alta ppO2 in {count} delle ultime {n} immersioni, fino al {percent} per cento dei campioni
- `equipmentCondition_finding_transmitterDropoutRising`: La pressione è mancata per il {recent} per cento delle ultime 5 immersioni, contro il {prior} per cento nelle {priorCount} precedenti
- `equipmentCondition_finding_transmitterDropoutHigh`: La pressione è mancata in media per il {recent} per cento delle ultime {n} immersioni, {count} delle quali oltre il 10 per cento
- `equipmentCondition_finding_issueRecurring`: {tag} segnalato {count} volte nelle ultime {n} immersioni
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} di {totalIssue} problemi segnalati riguardavano immersioni più fredde di {threshold}, su {n} immersioni con questo articolo
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} di {totalIssue} problemi segnalati riguardavano immersioni oltre {threshold}, su {n} immersioni con questo articolo
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incidente cita questo articolo} other{{count} incidenti citano questo articolo}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 immersione} other{{n} immersioni}}, {range}

### pt

- `equipmentCondition_children_title`: Peças instaladas
- `equipmentCondition_children_slot`: Ranhura {slot}
- `equipmentCondition_children_installed`: Instalado a {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{hoje} =1{há 1 dia} other{há {days} dias}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{há 1 mês} other{há {months} meses}}
- `equipmentCondition_children_replace`: Substituir
- `equipmentCondition_children_open`: Abrir
- `equipmentCondition_children_replaceTitle`: Substituir {name}?
- `equipmentCondition_children_replaceBody`: {name} é retirado hoje e um novo {type} ocupa o seu lugar na mesma ranhura. O número de série e as notas começam vazios.
- `equipmentCondition_children_replaceConfirm`: Substituir
- `equipmentCondition_children_replaceCancel`: Cancelar
- `equipmentCondition_children_replaced`: {name} substituído
- `equipmentCondition_children_empty`: Sem células ou baterias registadas
- `equipmentCondition_children_add`: Adicionar
- `equipmentCondition_findings_title`: Constatações de estado
- `equipmentCondition_findings_count`: {count, plural, =1{1 constatação} other{{count} constatações}}
- `equipmentCondition_findings_evidence`: Mergulhos de evidência
- `equipmentCondition_findings_dismiss`: Dispensar
- `equipmentCondition_findings_restore`: Repor
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Mostrar 1 dispensada} other{Mostrar {count} dispensadas}}
- `equipmentCondition_evidence_title`: Mergulhos de evidência
- `equipmentCondition_evidence_dive`: Mergulho {number}
- `equipmentCondition_evidence_unnumbered`: Mergulho
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Saída das células por mergulho
- `equipmentCondition_trend_title_gap`: Falhas de sinal do transmissor por mergulho
- `equipmentCondition_trend_title_scrubber`: Uso do absorvente por mergulho
- `equipmentCondition_trend_title_temperature`: Temperatura mínima por mergulho
- `equipmentCondition_trend_cell`: Célula {slot}
- `equipmentCondition_trend_issues`: Mergulhos com um problema
- `equipmentCondition_trend_scrubber`: Minutos de absorvente
- `equipmentCondition_trend_gap`: Percentagem de falhas
- `equipmentCondition_trend_temperature`: Temperatura mínima
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Exposição
- `equipmentCondition_exposure_empty`: Ainda não há mergulhos com este item
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 mergulho} other{{n} mergulhos}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 mergulho} other{{n} mergulhos}}
- `equipmentCondition_exposure_hours`: {n} horas
- `equipmentCondition_exposure_saltHours`: {n} horas em água salgada
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 mergulho frio} other{{n} mergulhos frios}}
- `equipmentCondition_exposure_o2Hours`: {n} horas com O2 elevado
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 mergulho profundo} other{{n} mergulhos profundos}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 ciclo de bateria} other{{n} ciclos de bateria}}
- `equipmentCondition_finding_cellOutputDeclining`: A saída da célula {slot} caiu {percent} por cento em {n} mergulhos desde {since}
- `equipmentCondition_finding_cellOutputLow`: A saída da célula {slot} é de {gain} mV por bar nos últimos {n} mergulhos
- `equipmentCondition_finding_cellDivergent`: A célula {slot} discordou das outras até {bar} bar em {count} dos últimos {n} mergulhos
- `equipmentCondition_finding_cellCurrentLimited`: A célula {slot} leu baixo a ppO2 alta em {count} dos últimos {n} mergulhos, até {percent} por cento das amostras
- `equipmentCondition_finding_transmitterDropoutRising`: A pressão falhou durante {recent} por cento dos últimos 5 mergulhos, contra {prior} por cento nos {priorCount} anteriores
- `equipmentCondition_finding_transmitterDropoutHigh`: A pressão falhou em média durante {recent} por cento dos últimos {n} mergulhos, {count} deles acima de 10 por cento
- `equipmentCondition_finding_issueRecurring`: {tag} registado {count} vezes nos últimos {n} mergulhos
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} de {totalIssue} problemas registados foram em mergulhos mais frios do que {threshold}, em {n} mergulhos com este item
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} de {totalIssue} problemas registados foram em mergulhos além de {threshold}, em {n} mergulhos com este item
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incidente refere este item} other{{count} incidentes referem este item}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 mergulho} other{{n} mergulhos}}, {range}

### nl

- `equipmentCondition_children_title`: Geplaatste onderdelen
- `equipmentCondition_children_slot`: Slot {slot}
- `equipmentCondition_children_installed`: Geplaatst op {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{vandaag} =1{1 dag geleden} other{{days} dagen geleden}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{1 maand geleden} other{{months} maanden geleden}}
- `equipmentCondition_children_replace`: Vervangen
- `equipmentCondition_children_open`: Openen
- `equipmentCondition_children_replaceTitle`: {name} vervangen?
- `equipmentCondition_children_replaceBody`: {name} wordt vandaag buiten gebruik gesteld en een nieuwe {type} neemt dezelfde slot in. Serienummer en notities beginnen leeg.
- `equipmentCondition_children_replaceConfirm`: Vervangen
- `equipmentCondition_children_replaceCancel`: Annuleren
- `equipmentCondition_children_replaced`: {name} vervangen
- `equipmentCondition_children_empty`: Geen cellen of batterijen vastgelegd
- `equipmentCondition_children_add`: Toevoegen
- `equipmentCondition_findings_title`: Conditiebevindingen
- `equipmentCondition_findings_count`: {count, plural, =1{1 bevinding} other{{count} bevindingen}}
- `equipmentCondition_findings_evidence`: Bewijsduiken
- `equipmentCondition_findings_dismiss`: Negeren
- `equipmentCondition_findings_restore`: Herstellen
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{Toon 1 genegeerde} other{Toon {count} genegeerde}}
- `equipmentCondition_evidence_title`: Bewijsduiken
- `equipmentCondition_evidence_dive`: Duik {number}
- `equipmentCondition_evidence_unnumbered`: Duik
- `equipmentCondition_evidence_minutes`: {n} min
- `equipmentCondition_trend_title_cellGain`: Celuitvoer per duik
- `equipmentCondition_trend_title_gap`: Zenderuitval per duik
- `equipmentCondition_trend_title_scrubber`: Scrubbergebruik per duik
- `equipmentCondition_trend_title_temperature`: Minimumtemperatuur per duik
- `equipmentCondition_trend_cell`: Cel {slot}
- `equipmentCondition_trend_issues`: Duiken met een probleem
- `equipmentCondition_trend_scrubber`: Scrubberminuten
- `equipmentCondition_trend_gap`: Aandeel uitval
- `equipmentCondition_trend_temperature`: Minimumtemperatuur
- `equipmentCondition_trend_axis_minutes`: min
- `equipmentCondition_exposure_title`: Blootstelling
- `equipmentCondition_exposure_empty`: Nog geen duiken met dit item
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 duik} other{{n} duiken}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 duik} other{{n} duiken}}
- `equipmentCondition_exposure_hours`: {n} uur
- `equipmentCondition_exposure_saltHours`: {n} uur in zout water
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 koude duik} other{{n} koude duiken}}
- `equipmentCondition_exposure_o2Hours`: {n} uur met hoog O2
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 diepe duik} other{{n} diepe duiken}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 batterijcyclus} other{{n} batterijcycli}}
- `equipmentCondition_finding_cellOutputDeclining`: De uitvoer van cel {slot} daalde {percent} procent over {n} duiken sinds {since}
- `equipmentCondition_finding_cellOutputLow`: De uitvoer van cel {slot} is {gain} mV per bar over de laatste {n} duiken
- `equipmentCondition_finding_cellDivergent`: Cel {slot} week bij {count} van de laatste {n} duiken tot {bar} bar af van de andere
- `equipmentCondition_finding_cellCurrentLimited`: Cel {slot} las bij hoge ppO2 te laag bij {count} van de laatste {n} duiken, tot {percent} procent van de metingen
- `equipmentCondition_finding_transmitterDropoutRising`: De druk viel weg tijdens {recent} procent van de laatste 5 duiken, tegen {prior} procent over de {priorCount} daarvoor
- `equipmentCondition_finding_transmitterDropoutHigh`: De druk viel gemiddeld weg tijdens {recent} procent van de laatste {n} duiken, bij {count} ervan boven 10 procent
- `equipmentCondition_finding_issueRecurring`: {tag} {count} keer gemeld in de laatste {n} duiken
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} van {totalIssue} gemelde problemen waren op duiken kouder dan {threshold}, over {n} duiken met dit item
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} van {totalIssue} gemelde problemen waren op duiken dieper dan {threshold}, over {n} duiken met dit item
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 incident noemt dit item} other{{count} incidenten noemen dit item}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 duik} other{{n} duiken}}, {range}

### hu

- `equipmentCondition_children_title`: Beépített alkatrészek
- `equipmentCondition_children_slot`: {slot}. hely
- `equipmentCondition_children_installed`: Beépítve: {date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{ma} =1{1 napja} other{{days} napja}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{1 hónapja} other{{months} hónapja}}
- `equipmentCondition_children_replace`: Csere
- `equipmentCondition_children_open`: Megnyitás
- `equipmentCondition_children_replaceTitle`: Cseréli: {name}?
- `equipmentCondition_children_replaceBody`: A(z) {name} ma kivonásra kerül, és egy új {type} veszi át a helyét ugyanazon a helyen. A sorozatszám és a megjegyzések üresen indulnak.
- `equipmentCondition_children_replaceConfirm`: Csere
- `equipmentCondition_children_replaceCancel`: Mégse
- `equipmentCondition_children_replaced`: {name} kicserélve
- `equipmentCondition_children_empty`: Nincs rögzített cella vagy akkumulátor
- `equipmentCondition_children_add`: Hozzáadás
- `equipmentCondition_findings_title`: Állapotmegállapítások
- `equipmentCondition_findings_count`: {count, plural, =1{1 megállapítás} other{{count} megállapítás}}
- `equipmentCondition_findings_evidence`: Bizonyító merülések
- `equipmentCondition_findings_dismiss`: Elvetés
- `equipmentCondition_findings_restore`: Visszaállítás
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{1 elvetett mutatása} other{{count} elvetett mutatása}}
- `equipmentCondition_evidence_title`: Bizonyító merülések
- `equipmentCondition_evidence_dive`: {number}. merülés
- `equipmentCondition_evidence_unnumbered`: Merülés
- `equipmentCondition_evidence_minutes`: {n} perc
- `equipmentCondition_trend_title_cellGain`: Cellakimenet merülésenként
- `equipmentCondition_trend_title_gap`: Adókimaradás merülésenként
- `equipmentCondition_trend_title_scrubber`: Szűrőhasználat merülésenként
- `equipmentCondition_trend_title_temperature`: Legalacsonyabb hőmérséklet merülésenként
- `equipmentCondition_trend_cell`: {slot}. cella
- `equipmentCondition_trend_issues`: Merülések problémával
- `equipmentCondition_trend_scrubber`: Szűrőpercek
- `equipmentCondition_trend_gap`: Kimaradási arány
- `equipmentCondition_trend_temperature`: Legalacsonyabb hőmérséklet
- `equipmentCondition_trend_axis_minutes`: perc
- `equipmentCondition_exposure_title`: Igénybevétel
- `equipmentCondition_exposure_empty`: Még nincs merülés ezzel az eszközzel
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 merülés} other{{n} merülés}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 merülés} other{{n} merülés}}
- `equipmentCondition_exposure_hours`: {n} óra
- `equipmentCondition_exposure_saltHours`: {n} sósvízi óra
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 hideg merülés} other{{n} hideg merülés}}
- `equipmentCondition_exposure_o2Hours`: {n} óra magas O2-vel
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 mély merülés} other{{n} mély merülés}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 akkumulátorciklus} other{{n} akkumulátorciklus}}
- `equipmentCondition_finding_cellOutputDeclining`: A(z) {slot}. cella kimenete {percent} százalékkal csökkent {n} merülés alatt {since} óta
- `equipmentCondition_finding_cellOutputLow`: A(z) {slot}. cella kimenete {gain} mV/bar az utolsó {n} merülésen
- `equipmentCondition_finding_cellDivergent`: A(z) {slot}. cella az utolsó {n} merülésből {count} alkalommal akár {bar} bar-ral eltért a többitől
- `equipmentCondition_finding_cellCurrentLimited`: A(z) {slot}. cella magas ppO2-nél az utolsó {n} merülésből {count} alkalommal alacsonyat mért, a minták akár {percent} százalékánál
- `equipmentCondition_finding_transmitterDropoutRising`: A nyomásadat az utolsó 5 merülés {recent} százalékában kimaradt, az azt megelőző {priorCount} merülésen mért {prior} százalékhoz képest
- `equipmentCondition_finding_transmitterDropoutHigh`: A nyomásadat az utolsó {n} merülés átlagosan {recent} százalékában kimaradt, ebből {count} merülésen 10 százalék felett
- `equipmentCondition_finding_issueRecurring`: {tag}: {count} alkalommal jelentve az utolsó {n} merülésen
- `equipmentCondition_finding_issueColdCorrelated`: {totalIssue} jelentett problémából {insideIssue} a(z) {threshold} alatti hőmérsékletű merüléseken történt, {n} merülés alapján ezzel az eszközzel
- `equipmentCondition_finding_issueDeepCorrelated`: {totalIssue} jelentett problémából {insideIssue} a(z) {threshold} mélységen túli merüléseken történt, {n} merülés alapján ezzel az eszközzel
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 esemény említi ezt az eszközt} other{{count} esemény említi ezt az eszközt}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 merülés} other{{n} merülés}}, {range}

### ar

- `equipmentCondition_children_title`: الأجزاء المركّبة
- `equipmentCondition_children_slot`: الفتحة {slot}
- `equipmentCondition_children_installed`: رُكّب في {date}، {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{اليوم} =1{قبل يوم واحد} other{قبل {days} أيام}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{قبل شهر واحد} other{قبل {months} أشهر}}
- `equipmentCondition_children_replace`: استبدال
- `equipmentCondition_children_open`: فتح
- `equipmentCondition_children_replaceTitle`: هل تريد استبدال {name}؟
- `equipmentCondition_children_replaceBody`: سيُسحب {name} اليوم ويحل محله {type} جديد في الفتحة نفسها. يبدأ الرقم التسلسلي والملاحظات فارغين.
- `equipmentCondition_children_replaceConfirm`: استبدال
- `equipmentCondition_children_replaceCancel`: إلغاء
- `equipmentCondition_children_replaced`: تم استبدال {name}
- `equipmentCondition_children_empty`: لا توجد خلايا أو بطاريات مسجّلة
- `equipmentCondition_children_add`: إضافة
- `equipmentCondition_findings_title`: نتائج الحالة
- `equipmentCondition_findings_count`: {count, plural, =1{نتيجة واحدة} other{{count} نتائج}}
- `equipmentCondition_findings_evidence`: غطسات الدليل
- `equipmentCondition_findings_dismiss`: تجاهل
- `equipmentCondition_findings_restore`: استعادة
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{إظهار نتيجة متجاهلة واحدة} other{إظهار {count} نتائج متجاهلة}}
- `equipmentCondition_evidence_title`: غطسات الدليل
- `equipmentCondition_evidence_dive`: الغطسة {number}
- `equipmentCondition_evidence_unnumbered`: غطسة
- `equipmentCondition_evidence_minutes`: {n} دقيقة
- `equipmentCondition_trend_title_cellGain`: خرج الخلايا لكل غطسة
- `equipmentCondition_trend_title_gap`: انقطاعات جهاز الإرسال لكل غطسة
- `equipmentCondition_trend_title_scrubber`: استهلاك المنظّف لكل غطسة
- `equipmentCondition_trend_title_temperature`: أدنى درجة حرارة لكل غطسة
- `equipmentCondition_trend_cell`: الخلية {slot}
- `equipmentCondition_trend_issues`: غطسات بها مشكلة
- `equipmentCondition_trend_scrubber`: دقائق المنظّف
- `equipmentCondition_trend_gap`: نسبة الانقطاع
- `equipmentCondition_trend_temperature`: أدنى درجة حرارة
- `equipmentCondition_trend_axis_minutes`: دقيقة
- `equipmentCondition_exposure_title`: التعرّض
- `equipmentCondition_exposure_empty`: لا توجد غطسات بهذه القطعة بعد
- `equipmentCondition_exposure_footer`: {n, plural, =1{غطسة واحدة} other{{n} غطسات}}، {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{غطسة واحدة} other{{n} غطسات}}
- `equipmentCondition_exposure_hours`: {n} ساعات
- `equipmentCondition_exposure_saltHours`: {n} ساعات في المياه المالحة
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{غطسة باردة واحدة} other{{n} غطسات باردة}}
- `equipmentCondition_exposure_o2Hours`: {n} ساعات بأكسجين مرتفع
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{غطسة عميقة واحدة} other{{n} غطسات عميقة}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{دورة بطارية واحدة} other{{n} دورات بطارية}}
- `equipmentCondition_finding_cellOutputDeclining`: انخفض خرج الخلية {slot} بنسبة {percent} بالمئة عبر {n} غطسة منذ {since}
- `equipmentCondition_finding_cellOutputLow`: خرج الخلية {slot} هو {gain} مللي فولت لكل بار خلال آخر {n} غطسة
- `equipmentCondition_finding_cellDivergent`: اختلفت الخلية {slot} عن نظيراتها بما يصل إلى {bar} بار في {count} من آخر {n} غطسة
- `equipmentCondition_finding_cellCurrentLimited`: قرأت الخلية {slot} قيمة منخفضة عند ppO2 مرتفع في {count} من آخر {n} غطسة، بما يصل إلى {percent} بالمئة من العينات
- `equipmentCondition_finding_transmitterDropoutRising`: انقطعت قراءة الضغط في {recent} بالمئة من آخر 5 غطسات، مقارنة بنسبة {prior} بالمئة في الغطسات {priorCount} السابقة
- `equipmentCondition_finding_transmitterDropoutHigh`: انقطعت قراءة الضغط في المتوسط في {recent} بالمئة من آخر {n} غطسة، منها {count} فوق 10 بالمئة
- `equipmentCondition_finding_issueRecurring`: تم الإبلاغ عن {tag} {count} مرات في آخر {n} غطسة
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} من {totalIssue} بلاغات مشكلات كانت في غطسات أبرد من {threshold}، على مدى {n} غطسة بهذه القطعة
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} من {totalIssue} بلاغات مشكلات كانت في غطسات أعمق من {threshold}، على مدى {n} غطسة بهذه القطعة
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{حادث واحد يذكر هذه القطعة} other{{count} حوادث تذكر هذه القطعة}}
- `equipmentCondition_finding_window`: {n, plural, =1{غطسة واحدة} other{{n} غطسات}}، {range}

### he

- `equipmentCondition_children_title`: חלקים מותקנים
- `equipmentCondition_children_slot`: חריץ {slot}
- `equipmentCondition_children_installed`: הותקן ב-{date}, {age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{היום} =1{לפני יום} other{לפני {days} ימים}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{לפני חודש} other{לפני {months} חודשים}}
- `equipmentCondition_children_replace`: החלפה
- `equipmentCondition_children_open`: פתיחה
- `equipmentCondition_children_replaceTitle`: להחליף את {name}?
- `equipmentCondition_children_replaceBody`: {name} יוצא משימוש היום ו{type} חדש תופס את מקומו באותו חריץ. המספר הסידורי וההערות מתחילים ריקים.
- `equipmentCondition_children_replaceConfirm`: החלפה
- `equipmentCondition_children_replaceCancel`: ביטול
- `equipmentCondition_children_replaced`: {name} הוחלף
- `equipmentCondition_children_empty`: לא נרשמו תאים או סוללות
- `equipmentCondition_children_add`: הוספה
- `equipmentCondition_findings_title`: ממצאי מצב
- `equipmentCondition_findings_count`: {count, plural, =1{ממצא אחד} other{{count} ממצאים}}
- `equipmentCondition_findings_evidence`: צלילות הראיה
- `equipmentCondition_findings_dismiss`: התעלמות
- `equipmentCondition_findings_restore`: שחזור
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{הצג ממצא אחד שהוסתר} other{הצג {count} ממצאים שהוסתרו}}
- `equipmentCondition_evidence_title`: צלילות הראיה
- `equipmentCondition_evidence_dive`: צלילה {number}
- `equipmentCondition_evidence_unnumbered`: צלילה
- `equipmentCondition_evidence_minutes`: {n} דק'
- `equipmentCondition_trend_title_cellGain`: פלט התאים לכל צלילה
- `equipmentCondition_trend_title_gap`: נפילות המשדר לכל צלילה
- `equipmentCondition_trend_title_scrubber`: שימוש בסופג לכל צלילה
- `equipmentCondition_trend_title_temperature`: טמפרטורה מזערית לכל צלילה
- `equipmentCondition_trend_cell`: תא {slot}
- `equipmentCondition_trend_issues`: צלילות עם תקלה
- `equipmentCondition_trend_scrubber`: דקות סופג
- `equipmentCondition_trend_gap`: שיעור הנפילות
- `equipmentCondition_trend_temperature`: טמפרטורה מזערית
- `equipmentCondition_trend_axis_minutes`: דק'
- `equipmentCondition_exposure_title`: חשיפה
- `equipmentCondition_exposure_empty`: אין עדיין צלילות עם פריט זה
- `equipmentCondition_exposure_footer`: {n, plural, =1{צלילה אחת} other{{n} צלילות}}, {range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{צלילה אחת} other{{n} צלילות}}
- `equipmentCondition_exposure_hours`: {n} שעות
- `equipmentCondition_exposure_saltHours`: {n} שעות במים מלוחים
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{צלילה קרה אחת} other{{n} צלילות קרות}}
- `equipmentCondition_exposure_o2Hours`: {n} שעות ב-O2 גבוה
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{צלילה עמוקה אחת} other{{n} צלילות עמוקות}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{מחזור סוללה אחד} other{{n} מחזורי סוללה}}
- `equipmentCondition_finding_cellOutputDeclining`: פלט תא {slot} ירד ב-{percent} אחוזים לאורך {n} צלילות מאז {since}
- `equipmentCondition_finding_cellOutputLow`: פלט תא {slot} הוא {gain} mV לבר ב-{n} הצלילות האחרונות
- `equipmentCondition_finding_cellDivergent`: תא {slot} חרג מהאחרים בעד {bar} בר ב-{count} מתוך {n} הצלילות האחרונות
- `equipmentCondition_finding_cellCurrentLimited`: תא {slot} קרא נמוך ב-ppO2 גבוה ב-{count} מתוך {n} הצלילות האחרונות, עד {percent} אחוזים מהדגימות
- `equipmentCondition_finding_transmitterDropoutRising`: קריאת הלחץ נפלה ב-{recent} אחוזים מ-5 הצלילות האחרונות, לעומת {prior} אחוזים ב-{priorCount} שלפניהן
- `equipmentCondition_finding_transmitterDropoutHigh`: קריאת הלחץ נפלה בממוצע ב-{recent} אחוזים מ-{n} הצלילות האחרונות, {count} מהן מעל 10 אחוזים
- `equipmentCondition_finding_issueRecurring`: {tag} דווח {count} פעמים ב-{n} הצלילות האחרונות
- `equipmentCondition_finding_issueColdCorrelated`: {insideIssue} מתוך {totalIssue} דיווחי תקלה היו בצלילות קרות מ-{threshold}, מתוך {n} צלילות עם פריט זה
- `equipmentCondition_finding_issueDeepCorrelated`: {insideIssue} מתוך {totalIssue} דיווחי תקלה היו בצלילות עמוקות מ-{threshold}, מתוך {n} צלילות עם פריט זה
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{אירוע אחד מזכיר פריט זה} other{{count} אירועים מזכירים פריט זה}}
- `equipmentCondition_finding_window`: {n, plural, =1{צלילה אחת} other{{n} צלילות}}, {range}

### zh

- `equipmentCondition_children_title`: 已安装部件
- `equipmentCondition_children_slot`: 插槽 {slot}
- `equipmentCondition_children_installed`: 安装于 {date}，{age}
- `equipmentCondition_children_ageDays`: {days, plural, =0{今天} =1{1 天前} other{{days} 天前}}
- `equipmentCondition_children_ageMonths`: {months, plural, =1{1 个月前} other{{months} 个月前}}
- `equipmentCondition_children_replace`: 更换
- `equipmentCondition_children_open`: 打开
- `equipmentCondition_children_replaceTitle`: 更换 {name}？
- `equipmentCondition_children_replaceBody`: {name} 将于今天退役，新的{type}将在同一插槽中取代它。序列号和备注将从空白开始。
- `equipmentCondition_children_replaceConfirm`: 更换
- `equipmentCondition_children_replaceCancel`: 取消
- `equipmentCondition_children_replaced`: 已更换 {name}
- `equipmentCondition_children_empty`: 未记录任何电池或电芯
- `equipmentCondition_children_add`: 添加
- `equipmentCondition_findings_title`: 状态发现
- `equipmentCondition_findings_count`: {count, plural, =1{1 项发现} other{{count} 项发现}}
- `equipmentCondition_findings_evidence`: 证据潜水
- `equipmentCondition_findings_dismiss`: 忽略
- `equipmentCondition_findings_restore`: 恢复
- `equipmentCondition_findings_showDismissed`: {count, plural, =1{显示 1 项已忽略} other{显示 {count} 项已忽略}}
- `equipmentCondition_evidence_title`: 证据潜水
- `equipmentCondition_evidence_dive`: 第 {number} 次潜水
- `equipmentCondition_evidence_unnumbered`: 潜水
- `equipmentCondition_evidence_minutes`: {n} 分钟
- `equipmentCondition_trend_title_cellGain`: 每次潜水的电池输出
- `equipmentCondition_trend_title_gap`: 每次潜水的发射器断连
- `equipmentCondition_trend_title_scrubber`: 每次潜水的吸收剂用量
- `equipmentCondition_trend_title_temperature`: 每次潜水的最低温度
- `equipmentCondition_trend_cell`: 电池 {slot}
- `equipmentCondition_trend_issues`: 有问题的潜水
- `equipmentCondition_trend_scrubber`: 吸收剂分钟数
- `equipmentCondition_trend_gap`: 断连占比
- `equipmentCondition_trend_temperature`: 最低温度
- `equipmentCondition_trend_axis_minutes`: 分钟
- `equipmentCondition_exposure_title`: 使用暴露
- `equipmentCondition_exposure_empty`: 尚无使用此装备的潜水
- `equipmentCondition_exposure_footer`: {n, plural, =1{1 次潜水} other{{n} 次潜水}}，{range}
- `equipmentCondition_exposure_dives`: {n, plural, =1{1 次潜水} other{{n} 次潜水}}
- `equipmentCondition_exposure_hours`: {n} 小时
- `equipmentCondition_exposure_saltHours`: {n} 小时盐水
- `equipmentCondition_exposure_coldDives`: {n, plural, =1{1 次冷水潜水} other{{n} 次冷水潜水}}
- `equipmentCondition_exposure_o2Hours`: {n} 小时高氧
- `equipmentCondition_exposure_deepCycles`: {n, plural, =1{1 次深潜} other{{n} 次深潜}}
- `equipmentCondition_exposure_cycles`: {n, plural, =1{1 次电池循环} other{{n} 次电池循环}}
- `equipmentCondition_finding_cellOutputDeclining`: 自 {since} 起，{n} 次潜水中电池 {slot} 的输出下降了 {percent}%
- `equipmentCondition_finding_cellOutputLow`: 最近 {n} 次潜水中电池 {slot} 的输出为 {gain} mV/bar
- `equipmentCondition_finding_cellDivergent`: 最近 {n} 次潜水中有 {count} 次电池 {slot} 与其他电池的偏差达 {bar} bar
- `equipmentCondition_finding_cellCurrentLimited`: 最近 {n} 次潜水中有 {count} 次电池 {slot} 在高 ppO2 下读数偏低，最多占样本的 {percent}%
- `equipmentCondition_finding_transmitterDropoutRising`: 最近 5 次潜水中压力信号中断占 {recent}%，此前 {priorCount} 次为 {prior}%
- `equipmentCondition_finding_transmitterDropoutHigh`: 最近 {n} 次潜水中压力信号中断平均占 {recent}%，其中 {count} 次超过 10%
- `equipmentCondition_finding_issueRecurring`: 最近 {n} 次潜水中 {tag} 被记录了 {count} 次
- `equipmentCondition_finding_issueColdCorrelated`: {totalIssue} 条问题记录中有 {insideIssue} 条发生在低于 {threshold} 的潜水中，基于使用此装备的 {n} 次潜水
- `equipmentCondition_finding_issueDeepCorrelated`: {totalIssue} 条问题记录中有 {insideIssue} 条发生在超过 {threshold} 的潜水中，基于使用此装备的 {n} 次潜水
- `equipmentCondition_finding_incidentLinked`: {count, plural, =1{1 起事件涉及此装备} other{{count} 起事件涉及此装备}}
- `equipmentCondition_finding_window`: {n, plural, =1{1 次潜水} other{{n} 次潜水}}，{range}

