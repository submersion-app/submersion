# SAC Trend by Cylinder Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Gas page's "Gas consumption by tank role" averages list with a per-role consumption trend (Bottom gas, Stage, Deco, Pony, Bailout) whose points use each cylinder's own breathing windows and depth, and feed the planner's logged default SAC from the same figures.

**Architecture:** `GasAnalysisService.calculateCylinderSac` (the dive detail's per-cylinder SAC) gains the windows, timing source and ambient pressure behind each rate. A pure function, `roleConsumptionForDive`, folds those rows into one figure per role group per dive. A new `InsightsRepository` part runs that over every dive in scope, in chunks, with 120-point profile summaries for depth. The Gas page card, the per-role averages and the planner all read the result. Nothing is stored.

**Tech Stack:** Flutter, Riverpod, Drift, fl_chart (through `TrendChartSection`), ARB localization.

**Spec:** `docs/design/specs/2026-11-07-sac-trend-by-cylinder-role-design.md`

## Global Constraints

- Before Task 1, initialize the worktree: `git submodule update --init --recursive`, `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` (never with `--build-filter`).
- No em-dashes anywhere (code, comments, ARB, docs, commits). No mention of Claude or Anthropic in commits or the PR.
- No schema change, migration, sync change or stored-value change.
- `lib/features/insights/data/repositories/insights_repository.dart` must not grow beyond the one `part` line and the removals in Task 5.
- New SQL over `dives` goes through `_diveFilter(...)`: `consumptionRate: true` for open-circuit groups, `gas: true` plus `d.dive_mode = 'ccr'` for CCR bailout.
- Units follow the active diver's settings through `UnitFormatter` (`formatRmv`, `formatSac`, `convertRmv`, `convertSac`, `rmvDecimals`, `sacDecimals`).
- Every new string goes in all 11 ARB files in `lib/l10n/arb/`, then `flutter gen-l10n`.
- Before each commit: `dart format .`, `flutter analyze` (whole repo), the task's tests, and `test/architecture/` plus `test/shared/` when a file was added under `lib/`.
- Stage explicit paths only (never `git add -A` or `-u`); check `git show --stat` after each commit.
- CI runs tests under `TZ=Australia/Sydney`; build dive dates with `DateTime.utc`.

## Review Focus

- A gas switch naming a stale tank id (#110): it says nothing, so a deco cylinder that lost gas with only such a switch makes the dive left out, never a whole-dive deco rate. Test in Task 2.
- A dive with no profile (manual entry, back gas only): its Bottom gas point uses the stored average depth, matching the dive detail. Test in Task 3.
- A cylinder whose logged end pressure is above its start: ignored, never negative gas, never a reason to leave the dive out. Test in Task 2.
- A dive with no usable runtime and no profile: no point and no exception. Test in Task 3.
- A group whose union of windows has zero length (a switch onto deco at the dive's last second): no point, no division by zero, no infinity on the chart. Test in Task 2.

---

### Task 1: Per-cylinder rows carry their windows, timing source and ambient pressure

**Files:**
- Modify: `lib/features/dive_log/domain/entities/cylinder_sac.dart` (constructor, fields, `copyWith`, `props`)
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart` (`calculateCylinderSac` OC path, around lines 336-495)
- Modify: `lib/features/dive_log/data/services/gas_analysis_service_ccr.dart` (`_ccrCylinderSac`)
- Modify: `lib/features/dive_log/domain/services/tank_usage_range.dart` (add `unionOfWindows`)
- Test: `test/features/dive_log/data/services/gas_analysis_service_usage_windows_test.dart`
- Test: `test/features/dive_log/domain/services/tank_usage_range_union_test.dart`

**Interfaces:**
- Produces on `CylinderSac` (all optional, defaults shown, all in `props` and `copyWith`):
  - `final List<TankUsageWindow> usageWindows;` default `const []`: the windows the rate covers (OC: from `tankUsageWindows`, or `[(start: 0, end: diveEnd)]` on the recorded-duration path; CCR: `cylinder.bailoutWindows`).
  - `final bool usageFromRecordedDuration;` default `false`: true when the time came from `tank.usageDuration` because no switch was known.
  - `final double? rateAmbientBar;` default `null`: the ambient pressure, in bar, the `sacRate` was divided by (the depth of whichever path produced it: time series `avgDepthDuringUse ?? dive.avgDepth ?? 10.0`, basic `avgDepthDuringUse ?? dive.avgDepth`, CCR `avgDepthOnBailout ?? dive.avgDepth`). Null when `sacRate` is null.
- Produces in `tank_usage_range.dart`: `List<TankUsageWindow> unionOfWindows(Iterable<TankUsageWindow> windows)`: sorted by start, overlapping or touching windows merged, zero-length windows dropped.

- [ ] **Step 1: Write the failing tests**

`tank_usage_range_union_test.dart`:
```dart
test('merges overlapping and touching windows', () {
  expect(
    unionOfWindows([(start: 600, end: 900), (start: 0, end: 300), (start: 300, end: 400), (start: 850, end: 1000)]),
    [(start: 0, end: 400), (start: 600, end: 1000)],
  );
});
test('drops zero-length windows', () {
  expect(unionOfWindows([(start: 5, end: 5)]), isEmpty);
});
```

`gas_analysis_service_usage_windows_test.dart` (hand-built `Dive`, back gas 12 L 21% plus deco 7 L 50%, switch to deco at 3000 s, `diveEnd` 3600 s, flat profile 25 m to 3000 s then 6 m):
```dart
test('a switched cylinder carries its windows and ambient pressure', () {
  final rows = const GasAnalysisService(gasModel: GasModel.ideal).calculateCylinderSac(dive: dive, profile: profile, gasSwitches: switches);
  final deco = rows.singleWhere((r) => r.role == TankRole.deco);
  expect(deco.usageWindows, [(start: 3000, end: 3600)]);
  expect(deco.usageFromRecordedDuration, isFalse);
  expect(deco.rateAmbientBar, closeTo(dive.environment.pressureAtDepth(deco.avgDepthDuringUse!), 1e-9));
});
test('a recorded duration without switches is flagged', () { /* stage with usageDuration 10 min, no switches */
  expect(stage.usageFromRecordedDuration, isTrue);
  expect(stage.usageWindows, [(start: 0, end: 3600)]);
});
test('a CCR bailout row carries its bailout windows', () { /* CCR dive, diluent + bailout, switch to bailout at 2400 s */
  expect(bailout.usageWindows, [(start: 2400, end: 3600)]);
  expect(bailout.rateAmbientBar, isNotNull);
});
test('a row without a rate has no ambient pressure', () { /* cylinder start == end */
  expect(row.sacRate, isNull);
  expect(row.rateAmbientBar, isNull);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/tank_usage_range_union_test.dart test/features/dive_log/data/services/gas_analysis_service_usage_windows_test.dart`
Expected: compile errors (`unionOfWindows`, `usageWindows`, `usageFromRecordedDuration`, `rateAmbientBar` undefined).

- [ ] **Step 3: Implement**

Add the three fields and `unionOfWindows`. In `calculateCylinderSac` set them from values the method already has (`usageWindows`, `hasRecordedUsage`, the depth each path used). The time-series path needs the ambient it used, so compute `environment.pressureAtDepth(avgDepthDuringUse ?? dive.avgDepth ?? 10.0)` beside the call rather than changing `_calculateSacFromTimeSeries`. In `_ccrCylinderSac` set `usageWindows: windows` and the ambient `_bailoutSacRate` used. No existing output changes.

- [ ] **Step 4: Run the new tests and the existing gas analysis suites**

Run: `flutter test test/features/dive_log/domain/services/tank_usage_range_union_test.dart test/features/dive_log/data/services/ test/features/dive_log/domain/entities/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/cylinder_sac.dart lib/features/dive_log/data/services/gas_analysis_service.dart lib/features/dive_log/data/services/gas_analysis_service_ccr.dart lib/features/dive_log/domain/services/tank_usage_range.dart test/features/dive_log/domain/services/tank_usage_range_union_test.dart test/features/dive_log/data/services/gas_analysis_service_usage_windows_test.dart
git commit -m "feat(dive-log): keep each cylinder's breathing windows on its SAC row"
```

---

### Task 2: Fold one dive's rows into role group figures

**Files:**
- Create: `lib/features/insights/domain/role_consumption.dart`
- Test: `test/features/insights/domain/role_consumption_test.dart`

**Interfaces:**
- Consumes: Task 1's `CylinderSac.usageWindows`, `usageFromRecordedDuration`, `rateAmbientBar`, `unionOfWindows`; existing `isMatchedPair`, `resolveTankPressureSeries`, `resolvedTankPressures`, `timeWeightedMeanAcross`, `DiveEnvironment.pressureAtDepth`.
- Produces:
  - `enum ConsumptionRoleGroup { bottomGas, stage, deco, pony, bailout }` (declaration order is the chart's series order).
  - `ConsumptionRoleGroup? consumptionRoleGroupOf(TankRole role)`: `backGas`, `twinSet`, `sidemountLeft`, `sidemountRight` to `bottomGas`; `stage`, `deco`, `pony`, `bailout` to their own; `diluent`, `oxygenSupply` to null.
  - `class DiveRoleConsumption { const DiveRoleConsumption({this.rmv = const {}, this.sac = const {}, this.leftOut = false}); final Map<ConsumptionRoleGroup, double> rmv; final Map<ConsumptionRoleGroup, double> sac; final bool leftOut; }` (RMV in L/min, SAC in bar/min; a group without a figure is absent).
  - `DiveRoleConsumption roleConsumptionForDive({required Dive dive, required List<CylinderSac> cylinders, required List<DiveProfilePoint> profile, Map<String, List<TankPressurePoint>>? tankPressures, bool Function(DiveTank tank)? counted})`

The rules, in order (the spec's "Which cylinders count", "When a dive leaves every group" and "The figure"):

1. Only tanks where `counted?.call(tank) ?? true`, and only rows of those tanks.
2. Open-circuit dive with more than one tank: if any counted tank whose group is `stage`, `deco`, `pony` or `bailout` lost gas (`resolvedTankPressures` start above end, using `resolveTankPressureSeries(dive.tanks, tankPressures)`) and has no row or a row with `usageFromRecordedDuration`, return `DiveRoleConsumption(leftOut: true)`.
3. Rows with a non-null `sacRate` join a group: on a CCR dive every such row joins `bailout`; otherwise `consumptionRoleGroupOf(row.role)`, and null-group rows are dropped.
4. Per group and lane, the counting rows: RMV needs `rmv != null`. SAC takes the group's first row by `order` as reference; another row counts when both it and the reference have a `tankVolume`, or its tank and the reference's tank are `isMatchedPair`.
5. Per counting row, its contribution: `litres = rmv * minutes * rateAmbientBar` (RMV); for SAC, `litres / reference.tankVolume` when both volumes are known, else `sacRate * minutes * rateAmbientBar` (bar one to one). `minutes = usageDuration.inSeconds / 60`.
6. Time: if any counting row has `usageFromRecordedDuration`, cluster the rows by `isMatchedPair` on their tanks, take each cluster's longest `usageDuration`, add the clusters, and use the reference row's `rateAmbientBar`. Otherwise `union = unionOfWindows(all counting rows' usageWindows)`, seconds `union.breathedSeconds`, ambient `dive.environment.pressureAtDepth(mean)` where `mean = timeWeightedMeanAcross(profile, windows: union, ...)`, falling back to the first counting row's `rateAmbientBar` when the mean is null.
7. Figure = sum of contributions / (seconds / 60) / ambient; no figure when seconds is 0 or ambient is null.

- [ ] **Step 1: Write the failing tests**

Each test builds a `Dive`, runs `const GasAnalysisService(gasModel: GasModel.real).calculateCylinderSac(...)` on it, then `roleConsumptionForDive` on the rows. Fixture: 60 minute dive, profile 25 m to 50 min then 6 m.

```dart
test('a one-cylinder group equals the dive detail row', () {
  // back gas 12 L only, with and without a pressure series, with and without a profile
  expect(result.rmv[ConsumptionRoleGroup.bottomGas], closeTo(row.rmv!, 1e-9));
  expect(result.sac[ConsumptionRoleGroup.bottomGas], closeTo(row.sacRate!, 1e-9));
});
test('back gas and deco each use their own window', () {
  // switch to deco at 3000 s
  expect(result.rmv[ConsumptionRoleGroup.deco], closeTo(decoRow.rmv!, 1e-9));
  expect(result.rmv[ConsumptionRoleGroup.bottomGas], closeTo(backRow.rmv!, 1e-9));
  expect(backRow.usageWindows, [(start: 0, end: 3000)]);
});
test('a deco cylinder that lost gas with no switch leaves the dive out', () {
  expect(result.leftOut, isTrue);
  expect(result.rmv, isEmpty);
});
test('a deco cylinder with a recorded duration and no switch leaves the dive out', () { expect(result.leftOut, isTrue); });
test('a deco switch naming a stale tank id leaves the dive out', () { expect(result.leftOut, isTrue); });
test('a stage that did not lose gas leaves nothing out', () { expect(result.leftOut, isFalse); expect(result.rmv.keys, [ConsumptionRoleGroup.bottomGas]); });
test('a stage with end above start is ignored', () { expect(result.leftOut, isFalse); expect(result.rmv.containsKey(ConsumptionRoleGroup.stage), isFalse); });
test('a stage of unknown size drops out alone', () {
  // switches present; stage volume null and no partner
  expect(result.leftOut, isFalse);
  expect(result.rmv.containsKey(ConsumptionRoleGroup.stage), isFalse);
  expect(result.rmv[ConsumptionRoleGroup.bottomGas], closeTo(backRow.rmv!, 1e-9));
});
test('a sidemount pair on a shared window counts its time once', () {
  // left and right 11 L each, both 200 to 100 bar, no switches
  expect(result.rmv[ConsumptionRoleGroup.bottomGas], closeTo(left.rmv! + right.rmv!, 1e-9));
});
test('a sidemount pair timed by recorded durations takes the longer', () {
  // 50 and 55 minutes recorded: time is 55 minutes, not 105
});
test('two stages breathed one after the other add their time', () {
  // stage A 600-1200 s, stage B 1200-1800 s: rmv == (litresA + litresB) / 20 min / ambient over 600-1800
});
test('SAC lane at real gas follows sacRate, not the raw bar drop', () {
  expect(result.sac[ConsumptionRoleGroup.bottomGas], closeTo(row.sacRate!, 1e-9));
  expect(result.sac[ConsumptionRoleGroup.bottomGas], isNot(closeTo(rawBarPerMinute, 1e-3)));
});
test('a CCR dive puts only its bailout gas in bailout', () {
  // diluent, O2, bailout 11 L switched to at 2400 s
  expect(result.rmv.keys, [ConsumptionRoleGroup.bailout]);
  expect(result.rmv[ConsumptionRoleGroup.bailout], closeTo(bailoutRow.rmv!, 1e-9));
});
test('a CCR dive with no bailout has no figures', () { expect(result.rmv, isEmpty); expect(result.leftOut, isFalse); });
test('a tank not counted is ignored', () { /* counted: (t) => t.id != 'copy' with a duplicated back gas */ });
test('a switch at the last second gives no deco figure', () {
  // switch to deco at diveEnd: deco window has zero length
  expect(result.rmv.containsKey(ConsumptionRoleGroup.deco), isFalse);
  expect(result.rmv.values.every((v) => v.isFinite), isTrue);
});
test('diluent and oxygen roles on an open-circuit dive join no group', () { expect(result.rmv.keys, [ConsumptionRoleGroup.bottomGas]); });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/insights/domain/role_consumption_test.dart`
Expected: compile error, `role_consumption.dart` does not exist.

- [ ] **Step 3: Implement `roleConsumptionForDive` and the types in `lib/features/insights/domain/role_consumption.dart`**

Pure Dart, no database. Follow the seven rules above.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/insights/domain/role_consumption_test.dart`
Expected: all pass.

- [ ] **Step 5: Run the architecture and shared guards**

Run: `flutter test test/architecture/ test/shared/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/domain/role_consumption.dart test/features/insights/domain/role_consumption_test.dart
git commit -m "feat(insights): fold a dive's cylinder rates into role group figures"
```

---

### Task 3: The per-dive trend from the database

**Files:**
- Create: `lib/features/insights/domain/role_consumption_trend.dart`
- Create: `lib/features/insights/data/repositories/insights_repository_role_consumption.dart` (a `part of 'insights_repository.dart'`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (one `part` line only)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart` (add the provider beside `ccrGasUseTrendProvider`)
- Test: `test/features/insights/domain/role_consumption_trend_test.dart`
- Test: `test/features/insights/data/repositories/insights_repository_role_consumption_test.dart`

**Interfaces:**
- Consumes: Task 2's `ConsumptionRoleGroup`, `roleConsumptionForDive`, `DiveRoleConsumption`; existing `_diveFilter`, `_diveChunks`, `_diveRepository.getDivesByIdsWithoutSamples`, `getGasSwitchesForDives`, `getBatchProfileSummaries`, `_tankPressureRepository.getDisplayedTankPressuresForDives`, `tankOwnedByPrimary`, `gasModel`.
- Produces:
  - `class RoleConsumptionTrend { const RoleConsumptionTrend({this.rmv = const {}, this.sac = const {}, this.leftOutDives = 0}); final Map<ConsumptionRoleGroup, List<TrendDataPoint>> rmv; final Map<ConsumptionRoleGroup, List<TrendDataPoint>> sac; final int leftOutDives; Map<ConsumptionRoleGroup, List<TrendDataPoint>> forLane(GasConsumptionLane lane); double? average(GasConsumptionLane lane, ConsumptionRoleGroup group); bool isEmptyFor(GasConsumptionLane lane); }` (groups with no points are absent; points in date order; `average` is the mean of a group's per-dive values, null when absent).
  - `extension InsightsRepositoryRoleConsumption on InsightsRepository { Future<RoleConsumptionTrend> getRoleConsumptionPerDive({String? diverId, DiveFilterState filter = const DiveFilterState()}); }`
  - `final roleConsumptionTrendProvider = FutureProvider<RoleConsumptionTrend>(...)`: `_keepAliveWithExpiry(ref)`, watches `insightsRepositoryProvider`, `currentDiverIdProvider`, `insightsFilterProvider` (not the lane: both lanes come back at once, so the toggle needs no reload).

`getRoleConsumptionPerDive`:
- Two id queries, each selecting `d.id, d.dive_date_time` and the primary source and computer subselects exactly as `getCcrGasUsePerDive` does, with `EXISTS (SELECT 1 FROM dive_tanks t WHERE t.dive_id = d.id)`: one with `_diveFilter(filter, alias: 'd', consumptionRate: true)`, one with `_diveFilter(filter, alias: 'd', gas: true)` and `d.dive_mode = 'ccr'`. Merge, keeping date order.
- Per chunk of `_diveChunks`: read dives without samples, switches, displayed pressures and `getBatchProfileSummaries(ids)` (default 120 samples). Per dive run `GasAnalysisService(gasModel: gasModel).calculateCylinderSac(dive: dive, profile: profiles[id] ?? const [], gasSwitches: switches[id], tankPressures: pressures[id])` with every tank, then `roleConsumptionForDive(..., counted: (tank) => tankOwnedByPrimary(tank, ...))`.
- A `leftOut` dive adds 1 to `leftOutDives` and no points. Wrap the body in `PerfTimer.measure('roleConsumptionPerDive', ...)` and the same try/catch/log/rethrow as `getCcrGasUsePerDive`.

- [ ] **Step 1: Write the failing trend tests**

```dart
test('average is the mean of the per-dive values', () { expect(trend.average(GasConsumptionLane.rmv, ConsumptionRoleGroup.bottomGas), 15); });
test('a group with no points has no average', () { expect(trend.average(GasConsumptionLane.rmv, ConsumptionRoleGroup.deco), isNull); });
test('forLane and isEmptyFor follow the lane', () { /* rmv has data, sac empty */ });
```

- [ ] **Step 2: Write the failing repository tests**

Seeding follows `insights_repository_ccr_gas_use_test.dart` (`insertDive`, `insertTank`, `insertSwitch`, `ProfileSeriesRepository().insertSeries`).

```dart
test('one dive reads the same as the dive detail', () async {
  // back gas + deco with a switch and a 1-sample-per-10-s profile
  final dive = (await DiveRepository().getDiveById('tech'))!;
  final rows = GasAnalysisService(gasModel: GasModel.real).calculateCylinderSac(dive: dive, profile: dive.profile, gasSwitches: await DiveRepository().getGasSwitchesForDive('tech'));
  final trend = await InsightsRepository(gasModel: GasModel.real).getRoleConsumptionPerDive();
  expect(trend.rmv[ConsumptionRoleGroup.deco]!.single.value, closeTo(decoRow.rmv!, decoRow.rmv! * 0.02));
});
test('the 120-point summary stays within 2% of full samples on a deco dive', () async {
  // 1 s samples for 70 min, deco switch at 60 min with a 5 min window at 6 m
});
test('a profileless back gas dive uses the stored average depth', () async { /* no series inserted, avg_depth 20 */ });
test('a dive with no runtime and no profile adds no point', () async { expect(trend.rmv, isEmpty); });
test('CCR, SCR and gauge dives add nothing to open-circuit groups', () async {});
test('a CCR dive with a recorded bailout adds a bailout point', () async {});
test('Exclude from gas statistics leaves a dive out of every group, bailout included', () async {});
test("another diver's dives are left out", () async {});
test('a deco dive without switches counts in leftOutDives', () async { expect(trend.leftOutDives, 1); expect(trend.rmv, isEmpty); });
test('a consolidated dive counts only the primary source cylinders', () async {});
```

Add `'getRoleConsumptionPerDive': (r) => r.getRoleConsumptionPerDive()` to the map in `test/features/insights/data/repositories/insights_repository_error_test.dart`.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/insights/domain/role_consumption_trend_test.dart test/features/insights/data/repositories/insights_repository_role_consumption_test.dart test/features/insights/data/repositories/insights_repository_error_test.dart`
Expected: compile errors for the missing types and method.

- [ ] **Step 4: Implement the trend type, the repository part, the `part` line and the provider**

- [ ] **Step 5: Run them to verify they pass, then the stats scope census**

Run: `flutter test test/features/insights/ test/core/database/`
Expected: all pass, including the scope census.

- [ ] **Step 6: Measure**

Seed 2000 open-circuit dives (a quarter of them with a deco switch and a 1-sample-per-4-s profile) in a throwaway test under `test/tmp_bench/` (never committed). This stands in for the spec's "largest local logbook": a debug build run against the live database migrates it, so do not point anything at `~/Documents/Submersion`. Time `getRoleConsumptionPerDive()` against the old `getSacVolumeByTankRole()` and `getCcrGasUsePerDive()`, three runs each. Record the medians in `docs/design/findings/2026-11-07-role-consumption-load-time.md`. If the new call takes more than 2 seconds, stop and report before Task 4.

- [ ] **Step 7: Commit**

```bash
git add lib/features/insights/domain/role_consumption_trend.dart lib/features/insights/data/repositories/insights_repository_role_consumption.dart lib/features/insights/data/repositories/insights_repository.dart lib/features/insights/presentation/providers/insights_providers.dart test/features/insights/domain/role_consumption_trend_test.dart test/features/insights/data/repositories/insights_repository_role_consumption_test.dart test/features/insights/data/repositories/insights_repository_error_test.dart docs/design/findings/2026-11-07-role-consumption-load-time.md
git commit -m "feat(insights): consumption by cylinder role for every dive in scope"
```

---

### Task 4: The Consumption by cylinder role card

**Files:**
- Create: `lib/features/insights/presentation/widgets/role_consumption_section.dart`
- Create: `lib/features/insights/presentation/widgets/rate_average_tile.dart` (move `_AverageTile` out of `ccr_gas_use_section.dart` as public `RateAverageTile`, same constructor)
- Modify: `lib/features/insights/presentation/widgets/ccr_gas_use_section.dart` (use `RateAverageTile`)
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart` (replace `_buildSacByRoleSection` with `const RoleConsumptionSection()`, delete the method)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart` (delete `sacByTankRoleProvider`)
- Modify: `lib/features/insights/presentation/providers/trend_chart_settings_provider.dart` (`static const roleConsumption = 'role-consumption';`)
- Modify: `lib/l10n/arb/app_*.arb` (11 files) and the generated `app_localizations*.dart`
- Test: `test/features/insights/presentation/widgets/role_consumption_section_test.dart`
- Modify tests: `test/features/insights/presentation/pages/insights_gas_page_widget_test.dart`, `insights_chart_links_test.dart`, `test/features/insights/presentation/providers/insights_providers_all_test.dart` (replace `sacByTankRoleProvider` with `roleConsumptionTrendProvider`)

**Interfaces:**
- Consumes: Task 3's `roleConsumptionTrendProvider`, `RoleConsumptionTrend`; `insightsGasLaneProvider`; `TrendChartSection` (`header`, `pointLabel`, `secondarySeries`, `footer`, `onDiveSelected`).
- Produces: `class RoleConsumptionSection extends ConsumerWidget`, `class RateAverageTile extends StatelessWidget`.

Behaviour:
- Loading: `TrendChartSection` with `pointsAsync: const AsyncLoading()`. Error: `AsyncError` with `insights_gas_roleUse_error`. No group in the current lane: `StatSectionCard` with the title, subtitle and `StatEmptyState(icon: MdiIcons.divingScubaTank, message: insights_gas_roleUse_empty)`.
- Primary series: `bottomGas` if present, else the first group present in enum order; the rest go to `secondarySeries` in enum order. `pointLabel` and the header labels: `bottomGas` uses `insights_gas_roleGroup_bottomGas`; `stage`, `deco`, `pony`, `bailout` reuse `insights_gas_tankRole_stage`, `_deco`, `_pony`, `_bailout`.
- Colours: `bottomGas` `Colors.indigo`, `stage` `Colors.purple`, `deco` `Colors.pink`, `pony` `Colors.brown`, `bailout` `Colors.red`.
- Header: a `Wrap` (spacing 8, run spacing 8) of `RateAverageTile`, one per present group, with `trend.average(lane, group)`. Not a `Row`: five tiles do not fit a phone.
- Footer: when `leftOutDives > 0`, `Text(l10n.insights_gas_roleUse_leftOut(trend.leftOutDives))` in `bodySmall`, `onSurfaceVariant`.
- Formatting by lane exactly as `_buildSacTrendSection` does (symbol, value, axis decimals). `chartId: TrendChartIds.roleConsumption`; `onDiveSelected: (id) => context.push('/dives/$id')`.

ARB: add after `insights_gas_sacByRole_title`'s position, then delete the four `insights_gas_sacByRole_*` keys from all 11 files. Values (first pass; non-English not reviewed by native speakers):

| key | en | de | es | fr | it | nl | pt | hu | zh | ar | he |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `insights_gas_roleUse_title` | Consumption by cylinder role | Verbrauch nach Flaschenrolle | Consumo por función de botella | Consommation par rôle de bouteille | Consumo per ruolo della bombola | Verbruik per flesrol | Consumo por função do cilindro | Fogyasztás palackszerep szerint | 按气瓶用途的耗气量 | الاستهلاك حسب دور الأسطوانة | צריכה לפי תפקיד המיכל |
| `insights_gas_roleUse_subtitle` | Each role over the time it was breathed | Jede Rolle über die Zeit, in der sie geatmet wurde | Cada función durante el tiempo en que se respiró | Chaque rôle sur le temps où il a été respiré | Ogni ruolo nel tempo in cui è stato respirato | Elke rol over de tijd dat eruit geademd werd | Cada função no tempo em que foi respirada | Minden szerep a belélegzés ideje alatt | 按各用途实际呼吸的时间计算 | كل دور خلال الوقت الذي تم التنفس منه | כל תפקיד לאורך הזמן שנשמו ממנו |
| `insights_gas_roleUse_empty` | No cylinder role rates yet | Noch keine Werte nach Flaschenrolle | Aún no hay valores por función de botella | Pas encore de valeurs par rôle de bouteille | Ancora nessun valore per ruolo della bombola | Nog geen waarden per flesrol | Ainda não há valores por função do cilindro | Még nincs érték palackszerep szerint | 暂无按气瓶用途的数据 | لا توجد قيم حسب دور الأسطوانة بعد | אין עדיין ערכים לפי תפקיד מיכל |
| `insights_gas_roleUse_error` | Failed to load consumption by cylinder role | Verbrauch nach Flaschenrolle konnte nicht geladen werden | No se pudo cargar el consumo por función de botella | Impossible de charger la consommation par rôle de bouteille | Impossibile caricare il consumo per ruolo della bombola | Verbruik per flesrol kon niet worden geladen | Não foi possível carregar o consumo por função do cilindro | Nem sikerült betölteni a palackszerep szerinti fogyasztást | 无法加载按气瓶用途的耗气量 | تعذر تحميل الاستهلاك حسب دور الأسطوانة | טעינת הצריכה לפי תפקיד מיכל נכשלה |
| `insights_gas_roleGroup_bottomGas` | Bottom gas | Grundgas | Gas de fondo | Gaz fond | Gas di fondo | Bodemgas | Gás de fundo | Fenékgáz | 底部气体 | غاز القاع | גז תחתית |

`insights_gas_roleUse_leftOut`, placeholder `count` (int), plural:
- en: `{count, plural, =1{1 dive with a stage or deco cylinder has no gas switches, so it is left out} other{{count} dives with a stage or deco cylinder have no gas switches, so they are left out}}`
- de: `{count, plural, =1{1 Tauchgang mit Stage- oder Dekoflasche hat keine Gaswechsel und wird ausgelassen} other{{count} Tauchgänge mit Stage- oder Dekoflasche haben keine Gaswechsel und werden ausgelassen}}`
- es: `{count, plural, =1{1 inmersión con botella de etapa o descompresión no tiene cambios de gas, así que se omite} other{{count} inmersiones con botella de etapa o descompresión no tienen cambios de gas, así que se omiten}}`
- fr: `{count, plural, =1{1 plongée avec un relais ou une bouteille de déco n’a pas de changement de gaz, elle est donc exclue} other{{count} plongées avec un relais ou une bouteille de déco n’ont pas de changement de gaz, elles sont donc exclues}}` (typographic apostrophe)
- it: `{count, plural, =1{1 immersione con bombola stage o deco non ha cambi gas, quindi è esclusa} other{{count} immersioni con bombola stage o deco non hanno cambi gas, quindi sono escluse}}`
- nl: `{count, plural, =1{1 duik met een stage- of decofles heeft geen gaswissels en is weggelaten} other{{count} duiken met een stage- of decofles hebben geen gaswissels en zijn weggelaten}}`
- pt: `{count, plural, =1{1 mergulho com cilindro de stage ou descompressão não tem trocas de gás, por isso ficou de fora} other{{count} mergulhos com cilindro de stage ou descompressão não têm trocas de gás, por isso ficaram de fora}}`
- hu: `{count, plural, =1{1 merülésnél a stage- vagy dekópalackhoz nincs gázváltás, ezért kimarad} other{{count} merülésnél a stage- vagy dekópalackhoz nincs gázváltás, ezért kimaradnak}}`
- zh: `{count, plural, other{{count} 次潜水的阶段瓶或减压瓶没有换气记录，因此未计入}}`
- ar: `{count, plural, =1{غطسة واحدة بأسطوانة مرحلية أو تخفيف ضغط بلا تبديل غاز، لذا تم استبعادها} other{{count} غطسات بأسطوانة مرحلية أو تخفيف ضغط بلا تبديل غاز، لذا تم استبعادها}}`
- he: `{count, plural, =1{צלילה אחת עם מיכל סטייג׳ או דקו בלי החלפות גז, לכן לא נכללה} other{{count} צלילות עם מיכל סטייג׳ או דקו בלי החלפות גז, לכן לא נכללו}}` (geresh U+05F3, not an apostrophe)

- [ ] **Step 1: Write the failing widget tests** (override `roleConsumptionTrendProvider` and `insightsGasLaneOverrideProvider`)

```dart
testWidgets('a single-group diver sees one line and one tile', (tester) async {
  expect(find.byType(RateAverageTile), findsOneWidget);
  expect(chart.secondarySeries, isEmpty);
});
testWidgets('a technical diver sees a line per group and the left-out note', (tester) async {
  // bottomGas, deco, stage; leftOutDives: 3
  expect(find.byType(RateAverageTile), findsNWidgets(3));
  expect(find.textContaining('3 dives with a stage or deco cylinder'), findsOneWidget);
});
testWidgets('with no bottom gas the first group present is primary', (tester) async {});
testWidgets('tapping a dot opens the dive', (tester) async { /* expect pushed route '/dives/d1' */ });
testWidgets('the lane toggle switches the units', (tester) async { /* RMV shows units.rmvSymbol, SAC units.sacSymbol */ });
testWidgets('no data shows the empty state', (tester) async { expect(find.text('No cylinder role rates yet'), findsOneWidget); });
testWidgets('five tiles fit a 360 px wide screen', (tester) async { /* no overflow exception */ });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/insights/presentation/widgets/role_consumption_section_test.dart`
Expected: compile error, `RoleConsumptionSection` undefined.

- [ ] **Step 3: Implement the tile move, the section, the page swap, the chart id, the ARB keys; delete `sacByTankRoleProvider`; run `flutter gen-l10n`**

- [ ] **Step 4: Run the insights presentation suites**

Run: `flutter test test/features/insights/presentation/ test/architecture/ test/shared/`
Expected: all pass, after replacing `sacByTankRoleProvider` in the three test files listed above.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/presentation/widgets/role_consumption_section.dart lib/features/insights/presentation/widgets/rate_average_tile.dart lib/features/insights/presentation/widgets/ccr_gas_use_section.dart lib/features/insights/presentation/pages/insights_gas_page.dart lib/features/insights/presentation/providers/insights_providers.dart lib/features/insights/presentation/providers/trend_chart_settings_provider.dart lib/l10n/arb/ lib/l10n/ test/features/insights/presentation/
git commit -m "feat(insights): chart consumption by cylinder role over time"
```

---

### Task 5: The planner reads the new Bottom gas figure; the old by-role queries go

**Files:**
- Modify: `lib/features/planner/presentation/providers/plan_canvas_providers.dart:132-151` (`loggedAverageSacProvider`, drop `_backmountSacKey`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (delete `getSacVolumeByTankRole` and `getSacPressureByTankRole`, about lines 759-910)
- Modify tests: `test/features/planner/presentation/providers/logged_average_sac_provider_test.dart`, `test/features/insights/data/repositories/insights_repository_multi_cylinder_sac_test.dart`, `insights_repository_rebreather_sac_test.dart`, `insights_repository_sac_environment_test.dart`, `insights_repository_sac_test.dart`, `insights_repository_error_test.dart`, `test/features/dive_log/data/repositories/measured_runtime_reports_test.dart`

**Interfaces:**
- Consumes: Task 3's `getRoleConsumptionPerDive`, `RoleConsumptionTrend.average`.
- Produces: `loggedAverageSacProvider` unchanged in type (`FutureProvider<double?>`), now `(await repository.getRoleConsumptionPerDive(diverId: diverId)).average(GasConsumptionLane.rmv, ConsumptionRoleGroup.bottomGas)`; `ref.invalidateSelfWhen(repository.watchInsightsChanges())` stays.

- [ ] **Step 1: Rewrite the planner tests against the new figure**

In `logged_average_sac_provider_test.dart`, keep every existing case (twin set only, back gas and twin set together, another diver, a stage alone) reading the provider, and add:
```dart
test('a deco dive with switches gives the back gas rate over its own window', () async {
  // 60 min dive, back gas 0-50 min at 25 m, deco 50-60 min at 6 m
  expect(await container.read(loggedAverageSacProvider.future), closeTo(backRow.rmv!, 1e-6));
});
test('a deco dive without switches is not in the default', () async { expect(await container.read(loggedAverageSacProvider.future), isNull); });
test('sidemount counts as bottom gas', () async {});
```

- [ ] **Step 2: Run them to verify the new cases fail**

Run: `flutter test test/features/planner/presentation/providers/logged_average_sac_provider_test.dart`
Expected: the deco and sidemount cases fail.

- [ ] **Step 3: Switch the provider; delete the two repository methods; move each deleted method's still-meaningful cases into `insights_repository_role_consumption_test.dart` or delete them where Task 3 already covers them (rebreather by-role, SCR by-role, measured runtime by-role, environment by-role); drop the two entries from the error test map**

- [ ] **Step 4: Run the affected suites and a whole-repo analyze**

Run: `flutter analyze && flutter test test/features/planner/ test/features/insights/ test/features/dive_log/data/repositories/measured_runtime_reports_test.dart test/features/dive_planner/ test/features/dive_lab/ test/architecture/`
Expected: no analyzer issues, all pass. `grep -rn 'getSacVolumeByTankRole\|getSacPressureByTankRole\|sacByTankRoleProvider' lib test` prints nothing.

- [ ] **Step 5: Commit**

```bash
git add lib/features/planner/presentation/providers/plan_canvas_providers.dart lib/features/insights/data/repositories/insights_repository.dart test/features/planner/presentation/providers/logged_average_sac_provider_test.dart test/features/insights/data/repositories/ test/features/dive_log/data/repositories/measured_runtime_reports_test.dart
git commit -m "feat(planner): default SAC from bottom gas over its own breathing time"
```

---

### Task 6: User docs and the whole-branch check

**Files:**
- Modify: `docs/user/statistics.md` (line 66, line 130, the Insights note around line 151, plus a short section for the new card)

- [ ] **Step 1: Update the docs**

Say: the card shows one line per cylinder role over time, with each role's average; sidemount counts as bottom gas; a dive with a stage or deco cylinder needs gas switches to count, and the card says how many were left out; rebreather dives feed only the Bailout line here (O2 and diluent stay on the Rebreather gas use card); SCR dives are not in this card; the card's SAC can differ by a few percent from the main SAC trend because it follows the dive detail's gas model; dots open dives. Line 66 no longer lists the by-role card among charts that do not open dives; line 151 no longer says SCR dives count toward consumption by tank role.

- [ ] **Step 2: Check docs links**

Run: `python3.14 scripts/check_docs_links.py`
Expected: exit 0.

- [ ] **Step 3: Full verification**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: exit 0 for all three; `grep -rn "$(printf '\342\200\224')" docs/design/specs/2026-11-07-sac-trend-by-cylinder-role-design.md docs/design/plans/2026-11-07-sac-trend-by-cylinder-role.md docs/user/statistics.md lib/features/insights/ lib/l10n/arb/` shows no new em-dash (U+2014).

- [ ] **Step 4: Commit**

```bash
git add docs/user/statistics.md
git commit -m "docs(insights): describe consumption by cylinder role"
```

The PR (after the user asks for one) says `Closes #771`, lists the planner default change with the before and after on the local logbook, the SCR change, the load time from Task 3, and carries before and after screenshots of the Gas page in light and dark at phone and desktop widths, attached through the project's screenshot gist.
