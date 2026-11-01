# Equipment Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task, inline in one session. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** Two PDF exports on Transfer > Export (Equipment inventory, Service
report), two new sections on Insights > Equipment (Cost of ownership, Idle gear),
hours and the full list on Most used gear, and purchase price in the gear CSV.

**Architecture:** Pure builders under `lib/features/equipment/domain/reports/`
turn loaded gear, records and options into report models, so every rule is tested
without a PDF or a widget. PDF services render those models. Providers load the
inputs and feed the builders, and `ExportNotifier` and the Insights sections read
the providers.

**Tech Stack:** Flutter, Riverpod (`lib/core/providers/provider.dart`), Drift
custom SQL, `pdf` and `printing`, ARB l10n in 11 locales.

**Spec:** [2026-10-31-equipment-reports-design.md](../specs/2026-10-31-equipment-reports-design.md)

## Global Constraints

- No schema change. No new table, column or migration rung.
- Never add or convert across currencies. Totals are per currency, with a blank
  code falling back to `defaultCurrencyProvider` and codes upper-cased, as
  `sumByCurrency` does.
- Gear links come from `diveGearUsageSql()`. It returns duplicate pairs, so count
  `DISTINCT dive_id` and sum hours over distinct `(dive_id, equipment_id)` pairs.
- Hours per dive: first positive of `d.runtime` and `d.bottom_time`, the rule at
  `equipment_repository_impl.dart:1309`.
- Cost and Most used gear apply `DiveStatsScope`. Idle gear excludes planned dives
  only and carries a `stats-scope-exempt` comment.
- PDFs never read a `BuildContext`. Strings come from `PdfLocalization.l10n`,
  dates from `UnitFormatter.formatDate`, money from `formatMoney`.
- Every provider calling a repository has a direct `invalidateSelfWhen`
  (`test/architecture/provider_change_tick_test.dart`).
- An Insights section that fails shows its own error text, never its empty text.
- No em dashes in code, comments or strings. New files stay under 400 lines where
  practical, 800 at most. Run `dart format .` before each commit.
- Stage explicit paths. `test/tmp_shots/` is a throwaway harness and is never
  committed.

## Review Focus

Each line has a test in the task that owns the code.

1. **A locker of 300 items, or a very long name or serial.** The PDF flows onto
   more pages with the column headings repeated and never throws. (Tasks 6, 8)
2. **Legacy money rows: lowercase, padded or blank currency codes.** `usd`, ` USD`
   and blank (with default USD) land in one bucket, never three. (Tasks 2, 5)
3. **Dives with no recorded time.** An item with dives and zero hours does not
   divide by zero under Per hour; it sorts last and reads "no dives yet". (Task 2)
4. **No active diver.** A library with a null diver id treats all gear as owned, as
   the rest of the app does, rather than producing an empty report. (Task 1)
5. **Parent links that loop or point at an item outside the set.** Builders finish,
   each item prints once, and an orphan part prints as top level. (Tasks 1, 5)

---

### Task 1: Report strings and gear sets

**Files:**
- Modify: `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`, then generated
  `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/equipment/domain/reports/report_gear_sets.dart`
- Test: `test/features/equipment/domain/reports/report_gear_sets_test.dart`

**Interfaces:**
- Produces: `bool isOwnedByDiver(EquipmentItem, String? diverId)`,
  `bool isOwnedNow(item, diverId)`, `bool isServiceable(item)`,
  `bool isEverOwned(item, diverId)`, `bool isIdleCandidate(item, diverId)`.
- Produces: `List<ReportRow> arrangeAsTree(List<EquipmentItem> items)` where
  `typedef ReportRow = ({EquipmentItem item, int depth})`: parents followed by
  their parts, in the input order, each item once.
- Produces: `Set<String> withInstalledParts(String rootId, List<EquipmentItem> all)`.
- Produces: every key below.

- [ ] **Step 1: Add the keys to all 11 ARB files**

Insert with a python3.14 script anchored on a neighbouring key of the same group
(ARB files are feature-grouped), translating each string properly. Plurals use
`one{{count} ...}`, never a hardcoded digit. Anchors:
`transfer_export_maintenanceSubtitle` and `insights_equipment_findings_subtitleAllDives`.

| Group | Key: English |
| --- | --- |
| `transfer_export_` | `inventoryTitle`: Equipment Inventory; `inventorySubtitle`: PDF with serial numbers and what you paid; `serviceReportTitle`: Service Report; `serviceReportSubtitle`: PDF of what is due, with service history |
| `settings_export_` | `progress_inventory`: Building inventory...; `success_inventory`: Inventory exported; `saved_inventory`: Inventory saved; `progress_serviceReport`: Building service report...; `success_serviceReport`: Service report exported; `saved_serviceReport`: Service report saved |
| `equipmentReport_sheet_` | `continue`: Continue; `groupBy`: Group by; `groupByType`: Gear type; `groupByLocation`: Location; `location`: Location; `allLocations`: All locations; `showPrices`: Show prices; `showPricesHelp`: Turn off for a customs list; `gear`: Gear; `gearAll`: All gear; `gearTrip`: Packed for a trip; `gearItem`: One item; `trip`: Trip; `item`: Item; `history`: Service history; `showCosts`: Show costs |
| `equipmentReport_pdf_` | `inventoryTitle`: Equipment inventory; `serviceTitle`: Service report; `printedOn(date)`: Printed {date}; `items(count)`: plural item/items; `currencyTotal(currency)`: {currency} total; `noLocation`: No location set; `colItem`: Item; `colSerial`: Serial; `colBought`: Bought; `colPaid`: Paid; `pricesNote`: Prices are what was paid, not current value.; `noPrice(count)`: plural "{count} item has no price." / "{count} items have no price."; `overdue`: overdue; `dueSoon`: due soon; `upToDate`: up to date; `colService`: Service; `colDue`: Due; `colStatus`: Status; `statusOverdue`: Overdue; `statusDueSoon`: Due soon; `statusUpToDate`: Up to date; `allUpToDate`: Everything is up to date.; `noSchedule(count)`: plural "{count} item has no service schedule." / "{count} items have no service schedule."; `colDate`: Date; `colWork`: Work; `colShop`: Shop; `colCost`: Cost; `noHistory`: No service recorded; `dives(count)`: plural {count} dive/dives |
| `insights_equipment_cost_` | `title`: Cost of ownership; `subtitle`: Purchase plus service, across all your dives; `spentTotal`: Spent in total; `perDive`: Per dive; `byYear`: Spending by year; `metricPerDive`: Per dive; `metricPerHour`: Per hour; `metricTotal`: Total; `rowPerDive(amount)`: {amount} / dive; `rowPerHour(amount)`: {amount} / hour; `rowOverDives(amount, count)`: plural {amount} over {count} dive/dives; `rowOverHours(amount, count)`: plural {amount} over {count} hour/hours; `noDives`: no dives yet; `undated(count)`: plural "{count} purchase has no date" / "{count} purchases have no date"; `leftOut(count)`: plural "{count} item has no cost recorded" / "{count} items have no cost recorded"; `empty`: No purchase prices or service costs recorded yet; `error`: Could not load gear costs |
| `insights_equipment_idle_` | `title`: Idle gear; `subtitle`: Gear you own and have not dived lately, across all your dives; `over6Months`: Over 6 months; `over1Year`: Over 1 year; `over2Years`: Over 2 years; `neverDived`: Never dived; `years(count)`: plural {count} yr/yrs; `months(count)`: plural {count} mo; `empty`: All your gear has been dived recently; `error`: Could not load idle gear |
| `insights_equipment_` | `showAll`: Show all; `showLess`: Show less; `mostUsedGear_hours(count)`: plural {count} hour/hours |

- [ ] **Step 2: Generate and check**

Run: `flutter gen-l10n`
Expected: exit 0, all 12 generated files change.

- [ ] **Step 3: Write the failing gear set tests**

```dart
test('owned now keeps fitted gear and drops the rest', ...);
// active, spare, needsService, inService, loaned: true
// retired, sold, wanted, lost, isActive false: false
test('another profile\'s item is not owned now but is serviceable', ...);
test('ever owned keeps sold and retired, drops wanted', ...);
test('idle candidates drop spares and parts', ...);
test('a null diver owns everything', ...); // Review Focus 4
test('arrangeAsTree indents parts under their parent, deepest last', ...);
test('arrangeAsTree prints an orphan part at the top level', ...);
test('arrangeAsTree survives a parent loop, each item once', ...); // Focus 5
test('withInstalledParts walks every depth and survives a loop', ...);
```

- [ ] **Step 4: Run them to verify they fail**

Run: `flutter test test/features/equipment/domain/reports/report_gear_sets_test.dart`
Expected: FAIL, the library does not exist.

- [ ] **Step 5: Implement `report_gear_sets.dart`**

`isOwnedByDiver` is `diverId == null || item.diverId == null || item.diverId == diverId`.
`isOwnedNow` adds `item.isFitted && item.status != EquipmentStatus.lost`.
`isServiceable` is `item.isFitted && item.status != EquipmentStatus.lost`.
`isEverOwned` adds `!item.isWanted`. `isIdleCandidate` is `isOwnedNow`, not `spare`,
`parentEquipmentId == null`.

- [ ] **Step 6: Run the tests to verify they pass, then commit**

```bash
git add lib/l10n/arb lib/features/equipment/domain/reports/report_gear_sets.dart test/features/equipment/domain/reports/report_gear_sets_test.dart
git commit -m "feat(equipment): report strings and gear sets"
```

### Task 2: Cost of ownership and idle gear builders

**Files:**
- Create: `lib/features/equipment/domain/reports/cost_of_ownership.dart`
- Create: `lib/features/equipment/domain/reports/idle_gear.dart`
- Test: `test/features/equipment/domain/reports/cost_of_ownership_test.dart`
- Test: `test/features/equipment/domain/reports/idle_gear_test.dart`

**Interfaces:**
- Consumes: `isEverOwned`, `isIdleCandidate` from Task 1.
- Produces: `class GearUsageTotals { final int diveCount; final double hours; }`
- Produces: `CostOfOwnership buildCostOfOwnership({required List<EquipmentItem> items,
  required Map<String, List<ServiceRecord>> recordsByItem, required
  Map<String, GearUsageTotals> usage, required int totalDives, required String?
  diverId, required String fallbackCurrency})`.
- Produces: `class CostOfOwnership { List<CurrencyCost> byCurrency; int leftOutCount; }`,
  largest total first.
- Produces: `class CurrencyCost { String currency; double total; double? perDive;
  List<({int year, double amount})> byYear; int undatedPurchases; List<CostRow> rows; }`
- Produces: `class CostRow { EquipmentItem item; double cost; int diveCount; double hours;
  double? get perDive; double? get perHour; }`, with both getters null at zero usage.
- Produces: `enum CostMetric { perDive, perHour, total }` and
  `List<CostRow> sortCostRows(List<CostRow>, CostMetric)`.
- Produces: `enum IdlePeriod { sixMonths, oneYear, twoYears }`,
  `class IdleRow { EquipmentItem item; DateTime? lastDive; ({int years, int months})? since; }`,
  `List<IdleRow> buildIdleGear({items, lastDives, diverId, period, now})`.

- [ ] **Step 1: Write the failing cost tests**

```dart
test('item cost is price plus service costs, in each currency', ...);
test('a part rolls into its parent row, and the total is unchanged', ...);
test('a part whose parent is not ever owned keeps its own row', ...);
test('wishlist gear counts nowhere, sold gear counts', ...);
test('shared gear counts nowhere', ...);
test('price in USD and service in EUR gives a row under each', ...);
test('usd, " USD" and blank with default USD land in one bucket', ...); // Focus 2
test('years run first to last with a zero bar for an empty middle year', ...);
test('a price with no date is in the total, not the bars, and counted', ...);
test('headline per dive divides by total dives, null at zero dives', ...);
test('per dive sort puts no-dive rows last', ...);
test('dives with zero hours sort last under per hour, perHour is null', ...); // Focus 3
test('per dive ties keep a stable order by name', ...); // ties in reverse input
test('an item with no price and no service cost only adds to leftOutCount', ...);
test('parent loop finishes and counts each cost once', ...); // Focus 5
```

Use `SERVICE` records with a null cost to prove they add nothing, and assert
`expect(row.cost, 1565)` on a part roll-up of `1290 + 145 + 130`.

- [ ] **Step 2: Write the failing idle tests**

```dart
test('lists an item last dived before the cutoff, longest idle first', ...);
test('does not list an item dived inside the period', ...);
test('never-dived gear past the period reads null lastDive and sorts last', ...);
test('never-dived gear bought last week is not idle', ...);
test('falls back to createdAt with no purchase date', ...);
test('since is whole years and months between last dive and now', ...);
```

Cutoffs use `DateTime(now.year - 1, now.month, now.day)` rather than `Duration`,
so a daylight saving change cannot move them.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/equipment/domain/reports/cost_of_ownership_test.dart test/features/equipment/domain/reports/idle_gear_test.dart`
Expected: FAIL, the libraries do not exist.

- [ ] **Step 4: Implement both builders**

Roll up by walking `parentEquipmentId` to the highest ancestor inside the ever-owned
set, with a seen-set for loops. A row belongs to a currency once it has any cost in
it. Normalize currency the way `sumByCurrency` does.

- [ ] **Step 5: Run the tests to verify they pass, then commit**

```bash
git add lib/features/equipment/domain/reports test/features/equipment/domain/reports
git commit -m "feat(equipment): cost of ownership and idle gear builders"
```

### Task 3: Usage queries and Most used gear

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_usage_repository.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:2499`
- Modify: `test/core/database/dive_stats_scope_census_test.dart` (add the new file)
- Test: `test/features/equipment/data/repositories/equipment_usage_repository_test.dart`
- Test: existing Most used gear tests in `test/features/insights/`

**Interfaces:**
- Consumes: `GearUsageTotals` from Task 2.
- Produces: `class EquipmentUsageRepository` with
  `Future<Map<String, GearUsageTotals>> getUsageTotals({String? diverId})`,
  `Future<Map<String, DateTime>> getLastDiveDates({String? diverId})`,
  `Future<int> getStatsDiveCount({String? diverId})`,
  `Stream<void> watchChanges()`.
- Produces: `getMostUsedGear({String? diverId, int? limit, DiveFilterState filter})`,
  null limit meaning all, with `RankingItem.value` holding hours.

- [ ] **Step 1: Write the failing repository tests**

```dart
test('gear linked only through a tank counts one dive and its hours', ...);
test('a tank regulator and an extra regulator count', ...);
test('a registered transmitter serial counts', ...);
test('a dive linked three ways counts once, hours once', ...);
test('runtime wins, then bottom time, zero runtime falls through', ...);
test('excluded and planned dives are left out of totals', ...);
test('last dive keeps an excluded dive and drops a planned one', ...);
test('another diver\'s dives are left out', ...);
test('most used gear reports hours in value and honours a null limit', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_usage_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the repository**

```sql
SELECT u.equipment_id, COUNT(*) AS dive_count, SUM(h.seconds) AS seconds
FROM (SELECT DISTINCT dive_id, equipment_id FROM (<diveGearUsageSql()>)) u
JOIN dives d ON d.id = u.dive_id
WHERE 1 = 1 <diver filter> <DiveStatsScope.and(alias: 'd')>
GROUP BY u.equipment_id
```

`seconds` is the CASE at `equipment_repository_impl.dart:1309`. `getLastDiveDates`
reads `MAX(d.dive_date_time)` with `d.is_planned = 0` under a `stats-scope-exempt`
comment saying a dive left out of statistics still put the gear in the water.
Decode dates the way `getItemExposures` does (`dive_date_decode_single_source_test`).
`watchChanges` follows the dive detail tick.

- [ ] **Step 4: Move `getMostUsedGear` onto `diveGearUsageSql()`**

Add the same seconds sum, `value: hours`, make `limit` nullable and drop `LIMIT` when
null. Keep `_diveFilter`.

- [ ] **Step 5: Add the file to `_censusFiles`, run the tests, then commit**

Run: `flutter test test/features/equipment/data/repositories/equipment_usage_repository_test.dart test/core/database/dive_stats_scope_census_test.dart test/features/insights/`
Expected: PASS.

```bash
git add lib/features/equipment/data/repositories/equipment_usage_repository.dart lib/features/insights/data/repositories/insights_repository.dart test/core/database/dive_stats_scope_census_test.dart test/features/equipment/data/repositories/equipment_usage_repository_test.dart
git commit -m "feat(equipment): gear usage totals from every gear link"
```

### Task 4: Insights sections

**Files:**
- Create: `lib/features/insights/presentation/providers/equipment_report_insights_providers.dart`
- Create: `lib/features/insights/presentation/widgets/equipment/cost_of_ownership_section.dart`
- Create: `lib/features/insights/presentation/widgets/equipment/idle_gear_section.dart`
- Create: `lib/features/insights/presentation/widgets/equipment/most_used_gear_section.dart`
- Create: `lib/features/insights/presentation/widgets/equipment/gear_report_row.dart`
- Modify: `lib/features/insights/presentation/pages/insights_equipment_page.dart`
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart:657`
- Test: `test/features/insights/presentation/widgets/equipment/` (one file per section)
- Test: `test/features/insights/presentation/providers/equipment_report_insights_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 2 and 3.
- Produces: `equipmentUsageRepositoryProvider`, `costOfOwnershipProvider`
  (`FutureProvider<CostOfOwnership>`), `idleGearProvider`
  (`FutureProvider<List<IdleRow>>`, watching the period),
  `costMetricProvider` and `idlePeriodProvider`
  (`StateProvider`, like `exposureRankingUnitProvider`),
  `costCurrencyProvider` (`StateProvider<String?>`, null meaning the largest).
- Produces: `GearReportRow(title, trailing, subtitle, onTap)`, a plain `Row`, not a
  `ListTile`, and `showAllSlice<T>(items, expanded)`.

- [ ] **Step 1: Write the failing provider tests**

```dart
test('cost refreshes when gear, a service record or a dive changes', ...);
test('idle follows the chosen period', ...);
test('neither provider follows the Insights filter', ...);
```

- [ ] **Step 2: Write the failing widget tests**

```dart
testWidgets('cost shows headlines, bars and rows for one currency', ...);
testWidgets('the currency picker appears only with two currencies', ...);
testWidgets('switching currency swaps totals, bars and rows', ...);
testWidgets('per hour row reads the hourly value and hours subtitle', ...);
testWidgets('a row with no dives reads no dives yet', ...);
testWidgets('show all expands past ten and show less collapses', ...);
testWidgets('cost shows the undated and left out notes only when above zero', ...);
testWidgets('a failed cost load shows the error, not the empty text', ...);
testWidgets('idle row reads 2 yrs 4 mo, and Never dived', ...);
testWidgets('a failed idle load shows the error, not the empty text', ...);
testWidgets('most used shows hours on the subtitle and expands', ...);
testWidgets('rows open the item page', ...);
```

Money assertions use `formatMoney`, so the test does not fix a locale's symbol.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/insights/presentation/widgets/equipment/ test/features/insights/presentation/providers/equipment_report_insights_providers_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the providers**

`costOfOwnershipProvider` reads `getAllEquipment(diverId:)`,
`getRecordsForEquipmentIds`, `getUsageTotals`, `getStatsDiveCount` and
`defaultCurrencyProvider`, with direct `invalidateSelfWhen` on the equipment,
service record, share and usage streams. `mostUsedGearProvider` passes `limit: null`.

- [ ] **Step 5: Implement the sections and wire the page**

Order on the page: Most used gear, Cost of ownership, Idle gear, Exposure, Findings,
Issues, Weight trend. Spending bars use `CategoryBarChart` with
`valueFormatter` set to `formatMoney` and `compactXLabelFormatter` for two-digit
years. Dropdowns follow the Exposure section's `DropdownButton`. The Most used
subtitle appends hours to the existing brand and type, with the dive count staying
in the row's count label. Row taps call `context.push('/equipment/<id>')`.

- [ ] **Step 6: Run the tests, then commit**

Run: `flutter test test/features/insights/ test/architecture/provider_change_tick_test.dart`
Expected: PASS.

```bash
git add lib/features/insights test/features/insights
git commit -m "feat(insights): cost of ownership and idle gear sections"
```

### Task 5: Inventory report builder

**Files:**
- Create: `lib/features/equipment/domain/reports/inventory_report.dart`
- Test: `test/features/equipment/domain/reports/inventory_report_test.dart`

**Interfaces:**
- Consumes: `isOwnedNow`, `arrangeAsTree` from Task 1.
- Produces: `enum InventoryGrouping { type, location }`,
  `class InventoryReportOptions extends Equatable { InventoryGrouping grouping;
  String? locationId; bool showPrices; }`,
  `class InventoryReport { int itemCount; int unpricedCount;
  List<MapEntry<String, double>> totals; List<InventoryGroup> groups; }`,
  `class InventoryGroup { EquipmentType? type; EquipmentLocation? location;
  List<ReportRow> rows; List<MapEntry<String, double>> subtotals; }`,
  `InventoryReport buildInventoryReport({items, locations, options, diverId,
  fallbackCurrency})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('groups by type in enum order, with a subtotal per currency', ...);
test('groups by location with No location set last', ...);
test('a part stays under its parent even when its own place differs', ...);
test('a location filter keeps top-level items there and their parts', ...);
test('a part counts in the item count and its price in the totals', ...);
test('a parent price stays its own', ...);
test('an orphan part is a top-level row', ...); // Focus 5
test('unpriced count covers top-level rows only, not parts', ...);
test('mixed currency codes merge', ...); // Focus 2
test('an empty location gives an empty report', ...);
```

`unpricedCount` counts top-level rows, so a hose with no price does not inflate the
footer.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/domain/reports/inventory_report_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the builder, using `sumByCurrency` for totals and subtotals**

- [ ] **Step 4: Run the tests to verify they pass, then commit**

```bash
git add lib/features/equipment/domain/reports/inventory_report.dart test/features/equipment/domain/reports/inventory_report_test.dart
git commit -m "feat(equipment): inventory report builder"
```

### Task 6: Inventory PDF

**Files:**
- Create: `lib/core/services/export/pdf/equipment_report_pdf_parts.dart`
- Create: `lib/core/services/export/pdf/equipment_inventory_pdf_export_service.dart`
- Modify: `lib/core/services/export/export_service.dart`
- Test: `test/core/services/export/pdf/equipment_inventory_pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `InventoryReport` from Task 5.
- Produces: `pw.Widget reportHeader(title, diverName, printedLine, {detail})`,
  `pw.Widget summaryStrip(List<({String value, String label})>)`,
  `pw.Widget groupHeading(String left, String? right)`,
  `pw.Widget reportTable({headers, rows, columnWidths, numericColumns})`,
  `pw.Widget reportFootnote(String)`, `PdfColor` constants, shared by Task 8.
- Produces: `EquipmentInventoryPdfExportService({loadTheme})` with
  `Future<List<int>> generateBytes(report, {required InventoryReportOptions options,
  required String? diverName, required UnitFormatter units, required DateTime printedAt,
  PdfLocalization? localization})`,
  `exportToPdf(...)` returning the path, and `saveToFile(...)` returning `String?`.
- Produces: facade methods on `ExportService` with the same names, prefixed
  `exportEquipmentInventory` and `saveEquipmentInventoryToFile`.

- [ ] **Step 1: Write the failing tests**

Use a Helvetica `loadTheme` so text can be read back
(`pdf_export_set_names_test` shows how). Build reports by hand.

```dart
test('prints the title, diver, serial and total', ...);
test('show prices off leaves out every amount and the note', ...);
// assert no '1,290' and no 'Paid' and no 'Prices are what was paid'
test('300 items and a very long name flow onto several pages', ...); // Focus 1
test('the Paid column heading repeats on the second page', ...);
test('an Arabic localization uses a right-to-left page', ...);
test('a part row is indented under its parent', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/export/pdf/equipment_inventory_pdf_export_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the parts and the service**

Follow `PassportLabelPdfExportService`: injectable `loadTheme`, `_sharedTheme`,
`pw.MultiPage` on A4 with `loc.textDirection`. Use one `pw.Table` per group with
`repeatHeader: true`, so a group split across pages keeps its headings. The Item cell
puts brand and model on a second line, and a part indents 10 points per depth. File
name `submersion_equipment_inventory_<yyyy-MM-dd>.pdf`, shared through
`saveAndShareFileBytes`. `saveToFile` follows `PdfExportService.savePdfToFile`.

- [ ] **Step 4: Run the tests to verify they pass, then commit**

```bash
git add lib/core/services/export/pdf/equipment_report_pdf_parts.dart lib/core/services/export/pdf/equipment_inventory_pdf_export_service.dart lib/core/services/export/export_service.dart test/core/services/export/pdf/equipment_inventory_pdf_export_service_test.dart
git commit -m "feat(equipment): equipment inventory PDF"
```

### Task 7: Service report builder

**Files:**
- Create: `lib/features/equipment/domain/reports/service_report.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_trigger_text.dart`
- Test: `test/features/equipment/domain/reports/service_report_test.dart`
- Test: existing service trigger text tests

**Interfaces:**
- Consumes: `isServiceable`, `withInstalledParts` from Task 1,
  `gearOnTrip` from `trip_gear_scope.dart`, `ServiceClockStatus`.
- Produces: `enum ServiceReportScope { all, trip, item }`,
  `class ServiceReportOptions extends Equatable { scope; String? tripId; String? itemId;
  bool includeHistory; bool showCosts; }`.
- Produces: `class ServiceReport { String? scopeLabel; int overdue; int dueSoon; int upToDate;
  int noScheduleCount; List<ServiceDueRow> due; List<ServiceHistoryBlock> history; }`,
  `class ServiceDueRow { EquipmentItem item; ServiceClockStatus status;
  ServiceClockSeverity severity; }`,
  `class ServiceHistoryBlock { EquipmentItem item; int diveCount; List<ServiceHistoryRow> rows; }`,
  `class ServiceHistoryRow { ServiceRecord record; String workName; }`.
- Produces: `ServiceReport buildServiceReport({scope gear list, clocks, records,
  kindsById, diveCounts, options, tripEnd, scopeLabel})`.
- Produces: `List<String> serviceTriggerLinesFor(AppLocalizations l10n, {units, now,
  ...})`, with `formatServiceTriggerLines` delegating to it.

- [ ] **Step 1: Write the failing tests**

```dart
test('lists overdue then due soon, then by date, and leaves ok out', ...);
test('counts clocks, so the summary matches the rows', ...);
test('one item lists every clock, ok included', ...);
test('a clock due before the trip ends is due soon, an overdue one stays overdue', ...);
test('a usage clock is judged as of today, never forecast', ...);
test('a due soon usage clock is listed on a trip report', ...);
test('no-schedule count covers top-level items only', ...);
test('history is newest first and skips items with no records', ...);
test('history off gives no blocks', ...);
test('work falls back to the service category with no kind', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/domain/reports/service_report_test.dart`
Expected: FAIL.

- [ ] **Step 3: Split the trigger text, then implement the builder**

Move the body of `formatServiceTriggerLines` into `serviceTriggerLinesFor(l10n, ...)`,
leaving a one-line wrapper reading `context.l10n`. Existing tests stay green.

- [ ] **Step 4: Run the tests to verify they pass, then commit**

Run: `flutter test test/features/equipment/ --name "service"`
Expected: PASS.

```bash
git add lib/features/equipment/domain/reports/service_report.dart lib/features/equipment/presentation/widgets/service_trigger_text.dart test/features/equipment/domain/reports/service_report_test.dart
git commit -m "feat(equipment): service report builder"
```

### Task 8: Service report PDF

**Files:**
- Create: `lib/core/services/export/pdf/service_report_pdf_export_service.dart`
- Modify: `lib/core/services/export/export_service.dart`
- Test: `test/core/services/export/pdf/service_report_pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `ServiceReport` from Task 7, the parts from Task 6.
- Produces: `ServiceReportPdfExportService({loadTheme})` with `generateBytes(report,
  {options, diverName, units, printedAt, localization})`, `exportToPdf`, `saveToFile`,
  and matching `ExportService` facade methods.

- [ ] **Step 1: Write the failing tests**

```dart
test('page one has the summary, the due table and the trip name', ...);
test('nothing due prints Everything is up to date.', ...);
test('Due uses the shared trigger text: 12 of 300 dives, 12 left', ...);
test('history pages show date, work, shop and cost', ...);
test('show costs off removes the Cost column and every amount', ...);
test('one item with no records prints No service recorded', ...);
test('100 items of history flow onto several pages', ...); // Focus 1
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/export/pdf/service_report_pdf_export_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the service**

Same shape as Task 6. Status text is coloured with `PdfColors.red800` and
`PdfColors.orange800` and always carries the word, so it survives a black and white
printer. File name `submersion_service_report_<yyyy-MM-dd>.pdf`.

- [ ] **Step 4: Run the tests to verify they pass, then commit**

```bash
git add lib/core/services/export/pdf/service_report_pdf_export_service.dart lib/core/services/export/export_service.dart test/core/services/export/pdf/service_report_pdf_export_service_test.dart
git commit -m "feat(equipment): service report PDF"
```

### Task 9: Report loaders and export notifier

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_report_providers.dart`
- Modify: `lib/features/settings/presentation/providers/export_providers.dart`
- Test: `test/features/equipment/presentation/providers/equipment_report_providers_test.dart`
- Test: `test/features/settings/presentation/providers/export_equipment_reports_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 8.
- Produces: `inventoryReportProvider` and `serviceReportProvider`,
  `FutureProvider.autoDispose.family` keyed by their options.
- Produces: `ExportNotifier.exportEquipmentInventory(options, {required bool save})` and
  `ExportNotifier.exportServiceReport(options, {required bool save})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('inventory loads owned gear and current locations', ...);
test('service report on all gear includes shared gear and drops lost gear', ...);
test('trip scope keeps gear retired since the trip', ...);
test('trip scope brings a retired assembly\'s installed part', ...);
test('one item on an assembly brings its parts', ...);
test('one item offers a retired item', ...);
test('a shared item prints its service costs with show costs on', ...);
test('empty report reports the empty-data error, not a blank PDF', ...);
test('a cancelled save returns to idle, not success', ...);
test('a failure reports the export failed message', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/providers/equipment_report_providers_test.dart test/features/settings/presentation/providers/export_equipment_reports_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the providers**

Inventory reads `getAllEquipment`, `currentEquipmentLocationsProvider` and
`defaultCurrencyProvider`. Service report reads all visible gear, picks scope gear
(trip: `gearOnTrip(all except wishlist, tripGearIdsProvider(tripId))`; item:
`withInstalledParts`), then calls `evaluateServiceClocksForIds(ref, ids)`,
`getRecordsForEquipmentIds`, `allServiceKindsByIdProvider` and
`getDiveCountForEquipment` per history item, batched with `Future.wait`.

- [ ] **Step 4: Implement the notifier methods**

One private `_runReportExport` holds the state flow of `saveMaintenanceLogToFile`:
progress, empty check, choose location, null path is cancelled, catch. Read the
autoDispose provider with `_ref.listen(p.future, (_, _) {})`, await `sub.read()`, and
close it in `finally`, the `hold: false` pattern of `awaitServiceStatusIfRead`.
The PDF language is `PdfLocalization.forLanguageCode(_l10n.localeName)`, as the
passport labels do. Diver name comes from `currentDiverProvider`.

- [ ] **Step 5: Run the tests, then commit**

```bash
git add lib/features/equipment/presentation/providers/equipment_report_providers.dart lib/features/settings/presentation/providers/export_providers.dart test/features/equipment/presentation/providers/equipment_report_providers_test.dart test/features/settings/presentation/providers/export_equipment_reports_test.dart
git commit -m "feat(equipment): load and export equipment reports"
```

### Task 10: Options sheets and Transfer tiles

**Files:**
- Create: `lib/features/transfer/presentation/widgets/inventory_report_sheet.dart`
- Create: `lib/features/transfer/presentation/widgets/service_report_sheet.dart`
- Create: `lib/features/transfer/presentation/widgets/report_sheet_scaffold.dart`
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:405`
- Test: `test/features/transfer/presentation/widgets/inventory_report_sheet_test.dart`
- Test: `test/features/transfer/presentation/widgets/service_report_sheet_test.dart`
- Test: `test/features/transfer/presentation/pages/transfer_equipment_reports_test.dart`

**Interfaces:**
- Consumes: option classes from Tasks 5 and 7, `equipmentLocationsProvider`,
  `allTripsProvider`, notifier methods from Task 9.
- Produces: `static Future<InventoryReportOptions?> InventoryReportSheet.show(context)`
  and `static Future<ServiceReportOptions?> ServiceReportSheet.show(context)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('inventory defaults to gear type, all locations, prices on', ...);
testWidgets('turning prices off returns showPrices false', ...);
testWidgets('the location dropdown hides archived places', ...);
testWidgets('service defaults to all gear, history on, costs on', ...);
testWidgets('packed for a trip shows the trip picker, newest first', ...);
testWidgets('continue stays disabled until a trip or item is picked', ...);
testWidgets('one item lists retired gear and hides wishlist gear', ...);
testWidgets('the transfer page shows both tiles beside the maintenance log', ...);
testWidgets('dismissing the sheet exports nothing', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/transfer/presentation/widgets/inventory_report_sheet_test.dart test/features/transfer/presentation/widgets/service_report_sheet_test.dart test/features/transfer/presentation/pages/transfer_equipment_reports_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the sheets and tiles**

Sheets follow `PdfExportDialog.show`: `showModalBottomSheet`, scroll-controlled.
Tiles sit above the maintenance tile, separated by `Divider(height: 1)`. `onTap` awaits
the sheet, stops on null or an unmounted context, then calls `_showExportOptions` with
`(_) => notifier.exportEquipmentInventory(options, save: false)` and `save: true`.

- [ ] **Step 4: Run the tests, then commit**

```bash
git add lib/features/transfer test/features/transfer
git commit -m "feat(transfer): equipment report tiles and options"
```

### Task 11: Gear CSV

**Files:**
- Modify: `lib/core/services/export/csv/csv_equipment_writer.dart`
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart`
- Test: the writer and parser test files beside the existing equipment CSV tests

**Interfaces:**
- Consumes: `table.number(row, 'Purchase Price')` at `submersion_csv_table.dart:88`.

- [ ] **Step 1: Write the failing tests**

```dart
test('writes Purchase Price and Purchase Currency as the last two columns', ...);
test('a blank price writes empty cells', ...);
test('price and currency survive an export and import', ...);
test('a file without the columns imports as before', ...);
test('a price written under a decimal comma locale still reads back', ...);
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/export/csv test/features/universal_import/data/parsers/submersion_csv`
Expected: FAIL.

- [ ] **Step 3: Implement both directions**

The writer appends `item.purchasePrice?.toString()` and `item.purchaseCurrency`
through `sanitizeCsvField`, with a comment like the one on `Location`. The parser adds
`purchasePrice` and `purchaseCurrency` to the item map. `submersion_csv_signatures.dart`
stays unchanged, so old files are still recognised.

- [ ] **Step 4: Run the tests, then commit**

```bash
git add lib/core/services/export/csv/csv_equipment_writer.dart lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart test/core/services/export/csv test/features/universal_import/data/parsers/submersion_csv
git commit -m "feat(equipment): purchase price in the gear CSV"
```

### Task 12: Whole-feature checks and after screenshots

**Files:**
- Modify: `test/tmp_shots/equipment_reports_shots_test.dart` (throwaway)

- [ ] **Step 1: Run the full static and guard checks**

Run: `dart format .`, then `flutter analyze`, then
`flutter test test/architecture test/shared test/core/database/dive_stats_scope_census_test.dart`
Expected: no issues, all pass.

- [ ] **Step 2: Capture the after shots**

Add the new overrides to the harness and run it with `--dart-define=STAGE=after`.
Render page one of each PDF to PNG with `printing`'s `Printing.raster` or a throwaway
test, at a realistic data set.

- [ ] **Step 3: Delete the harness and confirm it is gone**

Run: `rm -rf test/tmp_shots && git status --short`
Expected: nothing from `test/tmp_shots` listed.
