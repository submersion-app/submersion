# Equipment Exposure Usage Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The gear item Exposure card shows Last dived, Dives and Hours as headline numbers and a dives-per-month (or per-year) bar chart ending today (issue #5074).

**Architecture:** A pure builder turns the item's existing exposure samples into monthly and yearly buckets plus a relative "last dived". A new provider feeds it from `equipmentExposureInputsProvider` (the same samples the service clocks read) and today's wall-clock date. `ExposureCard` renders tiles, a two-way switch and the shared `CategoryBarChart`, which gains a per-bar tooltip and label thinning.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.family`), `fl_chart` via `CategoryBarChart`, `package:clock`, ARB l10n.

**Spec:** `docs/design/specs/2026-11-27-equipment-exposure-usage-chart-design.md`

## Global Constraints

- No schema, storage or sync change. Read only `equipmentExposureInputsProvider`.
- Dive dates are wall-clock-as-UTC (`DateTime.utc` whose fields are the dive's local calendar). "Today" is `clock.now()`'s local date rebuilt as `DateTime.utc(y, m, d)`; bucket on `.year` / `.month` of both.
- Dives and hours per bucket come from `ExposureClassifier.contribution(sample, ExposureUnit.dives | hours)`, so a rebreather's loop-only hours match the Hours tile and the service clocks.
- Every new string goes in `app_en.arb` and all 11 locale ARBs (ar de es fr he hu it ja nl pt zh), inserted by anchor line, never by JSON round-trip. Arabic plurals carry `zero`/`two`/`few`/`many` as the guard requires. `=1` branches print `{count}`, never a literal 1. Run `flutter gen-l10n` only after every ARB is filled.
- No em-dashes anywhere. No emojis.
- Theme colours only (`colorScheme`), so light and dark both read.

## Review Focus

1. A diver with a dive later today or a clock behind the log: a sample dated after today must read "Today", never a negative "-1 days ago", and must still land in the current month's bar. (Task 1 test `future-dated sample reads as today`.)
2. An item whose first dive was 30+ years ago: one bar per year must not draw overlapping year labels at phone width. (Task 3 test `thins labels that still overflow after compaction`.)
3. A rebreather that also logged OC dives: bucket hours equal the Hours tile (loop time only). (Task 1 test `bucket hours follow the classifier`.)
4. An item idle for more than 12 months: the 12-month view still draws twelve zero bars and the caption says "No dives in the last 12 months". (Task 4 test `idle item shows twelve empty months and the idle caption`.)
5. Large counts: 15,000 dives in the Dives tile is grouped per locale and does not overflow a phone-width tile. (Task 4 test `large totals fit the tiles`.)

---

### Task 1: Usage history builder (domain)

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_usage_history.dart`
- Create: `lib/features/equipment/domain/services/equipment_usage_builder.dart`
- Test: `test/features/equipment/domain/services/equipment_usage_builder_test.dart`

**Interfaces:**
- Produces:
  - `class UsageBucket extends Equatable { final DateTime start; final int dives; final double hours; }` (start is `DateTime.utc` of the month's or year's first day).
  - `enum LastDivedUnit { today, days, months, years }` and `typedef LastDivedAgo = ({LastDivedUnit unit, int count});`
  - `class EquipmentUsageHistory extends Equatable { final List<UsageBucket> monthly; final List<UsageBucket> yearly; final int divesLast12Months; final DateTime? lastDive; final LastDivedAgo? lastDivedAgo; static const empty; }`
  - `EquipmentUsageHistory buildUsageHistory({required List<EquipmentExposureSample> samples, required ExposureClassifier classifier, required DateTime today})`
  - `LastDivedAgo lastDivedAgo({required DateTime lastDive, required DateTime today})`

- [ ] **Step 1: Write the failing tests**

```dart
final today = DateTime.utc(2026, 11, 27);
EquipmentExposureSample s(DateTime d, {int min = 60, DiveMode mode = DiveMode.oc}) =>
    EquipmentExposureSample(date: d, durationSeconds: min * 60, diveMode: mode);

test('monthly holds twelve buckets ending with the current month', ...);
  // monthly.length == 12, monthly.first.start == DateTime.utc(2025, 12),
  // monthly.last.start == DateTime.utc(2026, 11)
test('dives and hours land in their calendar month', ...);
  // samples on 2026-11-02 (60 min), 2026-11-20 (30 min), 2026-03-05 (60 min)
  // -> monthly.last == (dives 2, hours 1.5); March bucket dives 1; others 0
  // divesLast12Months == 3
test('a dive on the first day of the window counts, the day before does not', ...);
  // 2025-12-01 counts in monthly.first; 2025-11-30 is outside, divesLast12Months excludes it
test('yearly runs from the first dive year to the current year with empty years', ...);
  // samples in 2019 and 2026 -> yearly starts 2019, 8 buckets, 2020..2025 dives 0
test('no samples gives the empty history', ...);
  // buildUsageHistory(samples: [], ...) == EquipmentUsageHistory.empty
test('bucket hours follow the classifier', ...);
  // ExposureClassifier(loopTimeOnly: true); one ccr 60 min + one oc 60 min in Nov
  // -> monthly.last.dives == 2, monthly.last.hours == 1.0
test('future-dated sample reads as today and lands in the current month', ...);
  // sample 2026-11-29 with today 2026-11-27 -> lastDivedAgo == (unit: today, count: 0),
  // monthly.last.dives == 1
group('lastDivedAgo', ...)
  // same day -> (today, 0); 1 day -> (days, 1); 30 days -> (days, 30);
  // 2026-10-26 -> (months, 1); 2025-11-28 -> (months, 11);
  // 2024-11-28 -> (months, 23); 2024-11-27 -> (years, 2); 2014-02-03 -> (years, 12)
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/equipment/domain/services/equipment_usage_builder_test.dart`
Expected: FAIL, the builder does not exist.

- [ ] **Step 3: Implement the entity and the builder**

`lastDivedAgo` rules: days = whole days between the two calendar dates; days <= 0 is `today`; days <= 30 is `days`; otherwise months = `(ty*12+tm) - (ly*12+lm)`, minus 1 when `today.day < last.day`, at least 1; months < 24 is `months`; else `years` = months ~/ 12. `lastDive` is the latest sample date. The yearly list is empty when there are no samples; a first-dive year after today's year (a future-dated log) starts the list at today's year.

- [ ] **Step 4: Run to verify they pass**

Run: same command. Expected: PASS.

- [ ] **Step 5: Commit** `feat(equipment): build monthly and yearly usage from exposure samples`

### Task 2: Usage history provider

**Files:**
- Modify: `lib/features/equipment/presentation/providers/equipment_exposure_providers.dart` (append)
- Test: `test/features/equipment/presentation/providers/equipment_usage_history_provider_test.dart`

**Interfaces:**
- Consumes: `buildUsageHistory`, `EquipmentUsageHistory` (Task 1); `equipmentExposureInputsProvider`.
- Produces: `final equipmentUsageHistoryProvider = FutureProvider.family<EquipmentUsageHistory, String>`.

- [ ] **Step 1: Write the failing tests**

```dart
test('builds from the exposure inputs with today from the clock', ...);
  // override equipmentExposureInputsProvider('reg') with two samples;
  // withClock(Clock.fixed(DateTime(2026, 11, 27, 23, 30))) read the provider
  // -> monthly.last.start == DateTime.utc(2026, 11), divesLast12Months == 2
test('an unknown item reads as the empty history', ...);
  // inputs override returns null -> EquipmentUsageHistory.empty
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/equipment/presentation/providers/equipment_usage_history_provider_test.dart`
Expected: FAIL, provider undefined.

- [ ] **Step 3: Implement** the provider: await the inputs, take today from `clock.now()` as described in Global Constraints, and `ref.invalidateSelfWhen(localDayChanges())` so an app open past midnight moves "today".

- [ ] **Step 4: Run to verify they pass.** Expected: PASS.

- [ ] **Step 5: Commit** `feat(equipment): provide an item's usage history`

### Task 3: CategoryBarChart per-bar tooltip and label thinning

**Files:**
- Modify: `lib/features/insights/presentation/widgets/category_bar_chart.dart`
- Test: `test/features/insights/presentation/widgets/category_bar_chart_tooltip_and_thinning_test.dart`

**Interfaces:**
- Produces two optional parameters, both off by default so every existing caller is unchanged:
  - `final String Function(int index)? tooltipText;` replaces the tooltip body (`'${label}\n$value'`) and the selection strip's count text when set.
  - `final bool thinXLabelsToFit;` when true and the (possibly compacted) labels still overflow their slot, draw only every n-th label, n the smallest step whose labels fit `n` slots, counted back from the LAST bar so the current period is always labelled.

- [ ] **Step 1: Write the failing tests** (Ahem font: each glyph is a 12 px square in bodySmall)

```dart
testWidgets('tooltipText replaces the tooltip body', ...);
  // hover/tap bar 0 of a 3-bar chart with tooltipText: (i) => 'bar $i detail'
  // -> find.textContaining('bar 0 detail') findsOneWidget
testWidgets('thins labels that still overflow after compaction', ...);
  // 31 year labels '1996'..'2026', compact formatter to "'96", width 390,
  // thinXLabelsToFit: true -> find.text("'26") findsOneWidget,
  // find.text("'25") findsNothing, and no two drawn labels' rects overlap
testWidgets('labels that fit are all drawn even with thinning on', ...);
  // 3 labels at width 400 -> all three found
```

- [ ] **Step 2: Run to verify they fail.** Run: `flutter test test/features/insights/presentation/widgets/category_bar_chart_tooltip_and_thinning_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** both parameters; reuse `_labelsOverflow`'s measuring for the step.
- [ ] **Step 4: Run** the new test plus `category_bar_chart_compact_labels_test.dart` and `category_bar_chart_axis_scale_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(insights): per-bar tooltip text and label thinning in CategoryBarChart`

### Task 4: Exposure card redesign and strings

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/exposure_card.dart` (split the tiles and the chart into `exposure_usage_section.dart` beside it if the card passes ~250 lines)
- Modify: `lib/l10n/arb/app_*.arb` (12 files) and generated `app_localizations*.dart`
- Test: `test/features/equipment/presentation/widgets/exposure_card_test.dart` (update), new `test/features/equipment/presentation/widgets/exposure_usage_section_test.dart`

**Interfaces:**
- Consumes: `equipmentUsageHistoryProvider`, `equipmentExposureTotalsProvider`, `CategoryBarChart(tooltipText:, thinXLabelsToFit:, compactXLabelFormatter:, compactXLabelsToFit: true)`.
- Strings (en), keys beside `equipmentCondition_exposure_*`:
  - `equipmentCondition_exposure_lastDivedLabel` "Last dived", `_divesLabel` "Dives", `_hoursLabel` "Hours"
  - `_today` "Today"; `_daysAgo` / `_monthsAgo` / `_yearsAgo` "{count, plural, =1{{count} day ago} other{{count} days ago}}" (and months, years)
  - `_lastDivedSemantic` "Last dived {ago}, on {date}"
  - `_range12Months` "12 months", `_rangeAllYears` "All years"
  - `_last12Months` "{count, plural, =0{No dives in the last 12 months} =1{{count} dive in the last 12 months} other{{count} dives in the last 12 months}}"
  - `_barTooltip` "{period}\n{dives}, {hours}" (dives and hours from the existing `_dives` / `_hours` strings)
  - `info_equipment_exposure_summary` gains a second sentence: "The chart counts its dives per month or per year, up to today."

Layout, top to bottom under the title row: three tiles in a `Row` of `Expanded` (label in `bodySmall` `onSurfaceVariant`, value in `titleMedium`, `FittedBox` scale-down, `Semantics` label on Last dived with the formatted date); a `SegmentedButton<_Range>` (12 months default, held in widget state, not saved); `CategoryBarChart` height 160 with `barColor` primary; the caption (12-month view only, `bodySmall` muted); the remaining unit chips (dives and hours chips removed); the existing footer. Month labels from `UnitFormatter.formatMonthOnly`, compacted to the first character when crowded; year labels "2024" compacted to "'24"; tooltip period via `formatMonthYear` (months) or the year. Dives tile grouped per locale (`NumberFormat.decimalPattern`).

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('headline tiles show last dived, dives and hours', ...);
  // override equipmentUsageHistoryProvider + totals; withClock fixed 2026-11-27
  // -> 'Last dived', '5 months ago', 'Dives', '214', 'Hours', '181.4'
  // and no '214 dives' chip, no '181.4 hours' chip; '12 cold dives' chip remains
testWidgets('12-month view draws twelve bars and the caption', ...);
  // CategoryBarChart data.length == 12; '18 dives in the last 12 months'
testWidgets('switching to all years draws one bar per year', ...);
  // tap 'All years' -> data.length == yearly.length; caption gone
testWidgets('idle item shows twelve empty months and the idle caption', ...);
  // monthly all zero -> 12 bars, 'No dives in the last 12 months'
testWidgets('large totals fit the tiles', ...);
  // width 360, dives 15000, hours 12345.6 -> '15,000' found, no overflow exception
testWidgets('an item with no dives shows only the empty line', ...);
  // no CategoryBarChart, no 'Last dived'
```

Keep the existing card tests that still hold (info icon, error line, decimal separator, days chip) and update the chip test for the removed dives and hours chips.

- [ ] **Step 2: Run to verify they fail.** Run: `flutter test test/features/equipment/presentation/widgets/exposure_card_test.dart test/features/equipment/presentation/widgets/exposure_usage_section_test.dart`. Expected: FAIL.
- [ ] **Step 3: Add the en strings by anchor line**, then implement the card.
- [ ] **Step 4: Run** the two widget tests plus `test/features/gear_passports/` files that pump `ExposureCard` (find them with `grep -rl ExposureCard test/`). Expected: PASS.
- [ ] **Step 5: Translate** the new keys into all 11 locale ARBs by anchor line, run `flutter gen-l10n`, and confirm with `grep -A1 "lastDivedLabel" lib/l10n/arb/app_localizations_de.dart` that German is not English. Run `test/l10n/arabic_plural_categories_test.dart` and the info-sheet sentence-cap test (`grep -rl "info_.*summary" test/l10n`).
- [ ] **Step 6:** `dart format .`, `flutter analyze`.
- [ ] **Step 7: Commit** `feat(equipment): exposure card shows recency, totals and a usage chart` and, separately, `i18n(equipment): translate the exposure usage strings`.
