# CCR Gas Use Rates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show plain per-minute O2, diluent and loop rates for CCR dives on the Cylinders card and in gas statistics.

**Architecture:** One pure function, `ccrDiveUse`, turns a CCR dive's tanks, switches and pressure series into per-cylinder loop gas and per-dive O2 and diluent rates. `GasAnalysisService` uses it for the card and `InsightsRepository` uses it for the statistics, so one dive cannot read differently in the two places. Nothing is stored.

**Tech Stack:** Flutter, Riverpod, Drift, fl_chart, ARB localization.

**Spec:** `docs/design/specs/2026-11-02-ccr-gas-use-rates-design.md`

## Global Constraints

- Applies only when the dive mode is `ccr`. SCR and open-circuit dives change nowhere except that a by-role query now names `ccr`.
- Loop figures are never divided by depth.
- Minimum drop: a cylinder whose `ccrCylinderRole` is neither `oxygenSupply` nor `diluent` has no loop gas unless its loop drop exceeds 20 bar. Exactly 20 bar does not count.
- A switch at or before `startingSwitchGraceSeconds` (60) is ignored for the timeline.
- Volume units follow the diver's settings through `UnitFormatter.formatRmv`.
- Every new string goes in all 11 ARB files, then `flutter gen-l10n`.
- No em-dashes anywhere. No schema, sync or stored-value change.
- New SQL over `dives` uses `_diveFilter(..., gas: true)` (the census test enforces a scope).
- Before each commit: `dart format .`, `flutter analyze`, the task's tests, and `test/architecture/` if a file was added under `lib/`.
- Stage explicit paths. `test/tmp_shots/` is throwaway and never committed.

## Review Focus

- A pressure that rises over a loop period (sensor noise, a cylinder warming): that period counts as zero, never as negative gas.
- A bailout that runs to the end of the dive with a first switch early on: little or no loop time, no division by zero, no loop rate.
- A dive with no usable runtime: every cylinder still gets a row and its "Gas used" line, with no rate.
- A transmitter series that stops before the dive ends: uses the last reading through `pressureAtTime`, no crash, no invented drop.
- A logged end pressure above the start: no gas used and no rate.

---

### Task 1: The shared calculation

**Files:**
- Create: `lib/features/dive_log/domain/services/ccr_cylinder_use.dart`
- Modify: `lib/features/dive_log/domain/services/ccr_bailout_timeline.dart` (rename private `_withoutDropouts` to public `withoutDropouts`, update its one caller)
- Modify: `lib/features/dive_log/domain/services/tank_pressure_lookup.dart` (new `resolvedTankPressures`, the rule moved out of `CylindersCard._resolveTankPressures`)
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (`_resolveTankPressures` calls the helper)
- Test: `test/features/dive_log/domain/services/ccr_cylinder_use_test.dart`

**Interfaces:**
- Consumes: `classifyCcrGasChanges`, `ccrCylinderRole`, `tankUsageWindows`, `knownGasSwitches`, `resolveTankPressureSeries`, `pressureAtTime`, `consumptionVolume`, `gasVolume`, `startingSwitchGraceSeconds`.
- Produces:

```dart
/// Smallest loop drop, in bar, that counts on a cylinder not marked as loop gas.
const double kMinUnmarkedLoopDropBar = 20.0;

// tank_pressure_lookup.dart. Start and end in bar: the stored value, else the
// series' first or last reading. A negative reading counts as missing.
(double?, double?) resolvedTankPressures(
  DiveTank tank,
  List<TankPressurePoint>? points,
);

class CcrCylinderUse {
  const CcrCylinderUse({
    required this.tankId,
    this.loopLiters = 0,
    this.loopRate,
    this.bailoutStartBar,
    this.bailoutEndBar,
    this.bailoutWindows = const [],
  });
  final String tankId;
  final double loopLiters;              // surface litres, 0 when none
  final double? loopRate;               // L/min of loop time
  final double? bailoutStartBar;        // null when no bailout gas
  final double? bailoutEndBar;
  final List<TankUsageWindow> bailoutWindows; // when this cylinder was breathed on bailout
}

class CcrDiveUse {
  const CcrDiveUse({
    required this.cylinders,
    required this.loopSeconds,
    this.o2Rate,
    this.diluentRate,
  });
  final List<CcrCylinderUse> cylinders;
  final int loopSeconds;
  final double? o2Rate;      // L/min
  final double? diluentRate; // L/min
}

CcrDiveUse ccrDiveUse({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank>? gasSwitches,
  required Map<String, List<TankPressurePoint>>? tankPressures,
  required int diveEnd,
  required GasModel gasModel,
});
```

- [ ] **Step 1: Write the failing tests**

Fixture helpers: `_tank(id, role, {volume, start, end, o2})`, `_switchTo(tankId, t)` building a `GasSwitchWithTank`, `_series(tankId, [(t, bar), ...])`. All use `GasModel.ideal` and `diveEnd: 3600` unless stated, so litres are bar times volume.

```dart
test('the issue dive: sidemount cylinders and an O2 supply, no bailout', () {
  final use = ccrDiveUse(
    tanks: [
      _tank('left', TankRole.sidemountLeft, volume: 7, start: 221, end: 220),
      _tank('right', TankRole.sidemountRight, volume: 7, start: 216, end: 163),
      _tank('o2', TankRole.oxygenSupply, volume: 1.5, start: 174, end: 102, o2: 100),
    ],
    gasSwitches: null, tankPressures: null, diveEnd: 3600, gasModel: GasModel.ideal,
  );
  expect(use.loopSeconds, 3600);
  expect(_of(use, 'left').loopRate, isNull);            // 1 bar is under the minimum
  expect(_of(use, 'right').loopRate, closeTo(371 / 60, 1e-9));
  expect(_of(use, 'o2').loopRate, closeTo(108 / 60, 1e-9));
  expect(use.o2Rate, closeTo(1.8, 1e-9));
  expect(use.diluentRate, closeTo(371 / 60, 1e-9));
});

test('a shared cylinder with a series splits loop and bailout', () {
  // Bailed onto right at 3000 s to the end: 216 to 180 on the loop, 180 to 163 on bailout.
  final use = ccrDiveUse(
    tanks: [_tank('right', TankRole.sidemountRight, volume: 7, start: 216, end: 163)],
    gasSwitches: [_switchTo('right', 3000)],
    tankPressures: {'right': _series('right', [(0, 216), (3000, 180), (3600, 163)])},
    diveEnd: 3600, gasModel: GasModel.ideal,
  );
  expect(use.loopSeconds, 3000);
  expect(_of(use, 'right').loopRate, closeTo(36 * 7 / 50, 1e-9));
  expect(_of(use, 'right').bailoutStartBar, 180);
  expect(_of(use, 'right').bailoutEndBar, 163);
  expect(_of(use, 'right').bailoutWindows, [(start: 3000, end: 3600)]);
});
```

Also write, each with its own `test`, asserting the named outcome:

| Test | Setup | Expect |
| --- | --- | --- |
| `logged pressures only: the cylinder bailed onto is all bailout` | right 216 to 163, switch to right at 3000, no series | `loopRate` null, `bailoutStartBar` 216, `bailoutEndBar` 163 |
| `logged pressures only: a cylinder not bailed onto is all loop` | a Bailout-role `b` and a Stage-role `s`, both 200 to 160, switch to `b` at 3000 | `b` bailout, `s` `loopRate` `closeTo(40*7/50)` |
| `a matched pair sharing one switch both count as bailout` | left and right sidemount logged, switch to left only at 3000 | both have `bailoutWindows` non-empty and null `loopRate` |
| `a marked loop cylinder stays loop gas with logged pressures` | Diluent 200 to 150, a switch to a Bailout `b` at 3000 | diluent `loopRate` `closeTo(50*7/50)` |
| `an O2 supply with a series ignores its drop during a bailout` | O2 series (0,200),(3000,150),(3600,140), switch to `b` at 3000 | `loopRate` over 50 bar and 3000 s |
| `a return to the loop onto a Diluent cylinder ends the bailout` | switch to `b` at 1000, to diluent `d` at 1300 | `loopSeconds` 3300 |
| `a return onto a Sidemount cylinder stays bailout (known limit)` | switch to `b` at 1000, to sidemount `s` at 1300 | `loopSeconds` 1000 |
| `a switch in the first 60 seconds is ignored` | switch to sidemount `s` at 30 | `loopSeconds` 3600, `s` has a `loopRate` |
| `a switch at 61 seconds counts` | switch to `s` at 61 | `loopSeconds` 61 |
| `an unbreathed bailout that lost 13 bar has no loop gas` | Bailout 200 to 187 | `loopLiters` 0, `loopRate` null, `use.diluentRate` null |
| `exactly 20 bar does not count, 21 does` | Bailout 200 to 180, then 200 to 179 | null, then non-null |
| `a Diluent cylinder has no minimum` | Diluent 200 to 195 | `loopRate` non-null |
| `pure O2 in a Sidemount cylinder counts toward O2` | Sidemount o2: 100, 200 to 150, volume 3 | `o2Rate` non-null, `diluentRate` null |
| `an untagged pure O2 back gas is the O2 line` | backGas o2: 100, 200 to 190, volume 3 | `loopRate` non-null (no minimum), `o2Rate` non-null |
| `unknown volume gives no rate` | Diluent, volume null | `loopRate` null, `loopLiters` 0 |
| `a matched partner lends its volume` | sidemount left volume null, right volume 7, left 200 to 150 | left `loopRate` non-null |
| `a dropout in a series does not count as a drop` | series (0,200),(100,0),(200,199),(3600,190) on Diluent | `loopRate` `closeTo(10*V/60)` |
| `a flat series falls back to logged pressures` | series all 200, logged 200 to 150, Diluent | `loopRate` from 50 bar |
| `a rising period counts as zero` | series (0,200),(1800,180),(2000,185),(3600,185) with a switch to `b` at 1800 and back to diluent at 2000 | loop gas is the 20 bar drop only |
| `a series ending early uses its last reading` | Diluent series (0,200),(1800,170), logged null | `loopRate` from 30 bar over 60 min |
| `bailed out from early on leaves no loop rate` | switch to `b` at 61 | `loopSeconds` 61; a rate only if loop gas exists, no exception |
| `no runtime gives no rates` | `diveEnd: 0` | `loopSeconds` 0, every `loopRate` null, one entry per tank |
| `an end pressure above the start gives no gas` | Diluent 150 to 160 | `loopLiters` 0, `loopRate` null |
| `a switch naming a stale tank is ignored` | switch to `gone` at 1000 | `loopSeconds` 3600 |
| `the real gas model reads less than ideal at high pressure` | Diluent 300 to 200 under `GasModel.real` | `loopLiters` differs from `100 * volume` and equals the two `gasVolume` calls subtracted |

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/ccr_cylinder_use_test.dart > <scratchpad>/t1.log 2>&1; echo $?`
Expected: non-zero, `ccr_cylinder_use.dart` not found.

- [ ] **Step 3: Implement `ccrDiveUse`**

In order:
1. `known = knownGasSwitches(tanks, gasSwitches, before: diveEnd)`, then drop any with `timestamp <= startingSwitchGraceSeconds`. Drop them before `classifyCcrGasChanges`, whose `onLoop` state would otherwise start wrong.
2. Walk the changes: an `openCircuit` opens a period if none is open, a `diluent` closes it, the end of the dive closes the last. `loopSeconds = diveEnd - periods.breathedSeconds`. Loop periods are the gaps.
3. `resolveTankPressureSeries(tanks, tankPressures)`. For each tank, take the series through `withoutDropouts` (map `TankPressurePoint` to `TimelinePressure` and back). It is usable with two or more samples and a positive total drop across `[0, diveEnd]`.
4. Series path: per period, `from = pressureAtTime(start)`, `to = pressureAtTime(end)`; a period with `to >= from` counts nothing. Loop gas is the sum of `gasVolume(from) - gasVolume(to)` over loop periods. Bailout `bailoutStartBar` is the reading at the start of the first bailout period with a drop, `bailoutEndBar` is that minus the summed bailout drop.
5. Logged path: `start` and `end` from `resolvedTankPressures`. No gas when either is null or `end >= start`. `bailoutWindows` (step 6) non-empty and `ccrCylinderRole` not `oxygenSupply` or `diluent`: all bailout. Otherwise all loop.
6. `bailoutWindows` for a tank: `tankUsageWindows(tank:, gasSwitches: <the filtered switches>, diveStart: 0, diveEnd:, tanks:)`, each `.within(period.start, period.end)`.
7. Minimum drop: total loop drop in bar `<= kMinUnmarkedLoopDropBar` on a tank whose `ccrCylinderRole` is neither loop role sets loop gas to 0.
8. `loopRate = loopLiters / (loopSeconds / 60)` when both are positive. `consumptionVolume(tank, tanks)` null means 0 litres.
9. `o2Rate` sums `loopLiters` of tanks where `ccrCylinderRole(t) == TankRole.oxygenSupply || t.gasMix.o2 >= 99.0`; `diluentRate` sums the rest. Each is null when its sum is 0 or `loopSeconds` is 0.

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command. Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/services/ccr_cylinder_use.dart lib/features/dive_log/domain/services/ccr_bailout_timeline.dart lib/features/dive_log/domain/services/tank_pressure_lookup.dart lib/features/dive_log/presentation/widgets/cylinders_card.dart test/features/dive_log/domain/services/ccr_cylinder_use_test.dart
git commit -m "feat(dive-log): work out where a CCR dive's gas went"
```

### Task 2: The Cylinders card

**Files:**
- Modify: `lib/features/dive_log/domain/entities/cylinder_sac.dart` (new `loopRate`, in the constructor, `copyWith` and `props`)
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart`
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart`
- Modify: `lib/l10n/arb/app_*.arb` (key `diveLog_cylinders_loopUse`, after `diveLog_cylinders_gasUsed`)
- Test: `test/features/dive_log/data/services/gas_analysis_service_ccr_test.dart` (create), `test/features/dive_log/presentation/widgets/cylinders_card_ccr_test.dart` (create)

**Interfaces:**
- Consumes: `ccrDiveUse`, `CcrCylinderUse`.
- Produces: `CylinderSac.loopRate` (`double?`, L/min). L10n: `diveLog_cylinders_loopUse(String rate)` reading `Loop use {rate}`.

- [ ] **Step 1: Write the failing service tests**

```dart
test('a CCR dive gives every cylinder a row', () {
  final rows = const GasAnalysisService(gasModel: GasModel.ideal)
      .calculateCylinderSac(dive: _ccrDive(), profile: const []);
  expect(rows.map((r) => r.tankId), ['left', 'right', 'o2']);
});
test('loop figures carry no SAC and are not depth corrected', () {
  final o2 = _row('o2');
  expect(o2.loopRate, closeTo(1.8, 1e-9));
  expect(o2.sacRate, isNull);
  expect(o2.gasUsedLiters, closeTo(108, 1e-9));
});
test('a bailout reads as ordinary SAC and RMV over the bailout', () {
  // right bailed onto at 3000 s, 180 to 163 over 600 s at a flat 15 m profile.
  final row = _row('right', dive: _bailoutDive());
  expect(row.loopRate, closeTo(36 * 7 / 50, 1e-9));
  final ambient = _bailoutDive().environment.pressureAtDepth(15);
  expect(row.rmv, closeTo(17 * 7 / 10 / ambient, 1e-6));
});
test('a dive with no runtime still lists its cylinders', () { /* row per tank, no rates */ });
test('an open-circuit dive is unchanged', () { /* same result as before: an OC fixture with loopRate null on every row */ });
test('an SCR dive is unchanged', () { /* an SCR fixture with loopRate null */ });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/dive_log/data/services/gas_analysis_service_ccr_test.dart > <scratchpad>/t2.log 2>&1; echo $?`
Expected: non-zero, `loopRate` undefined.

- [ ] **Step 3: Implement the CCR branch**

At the top of `calculateCylinderSac`, when `dive.diveMode == DiveMode.ccr`, return a new private `_ccrCylinderSac(...)`. `diveEnd` stays the same expression, moved above the branch. For each tank, in tank order, one `CylinderSac` from `ccrDiveUse`:
- `loopRate` from the use; `startPressure` and `endPressure` from `resolvedTankPressures`, so "Gas used" shows when only the series has them.
- Bailout gas present and `bailoutWindows` non-empty: `sacRate` from `_zCorrectedSacRate` over `bailoutStartBar`, `bailoutEndBar`, `bailoutWindows.breathedSeconds / 60`, and ambient at `timeWeightedMeanAcross(profile, windows: bailoutWindows, ...) ?? dive.avgDepth`. With no volume, the pressure fallback the open-circuit path uses.
- `usageDuration`: bailout seconds when there are any, else `Duration(seconds: use.loopSeconds)`.

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: exit 0.

- [ ] **Step 5: Write the failing widget tests**

Harness from `cylinders_card_role_test.dart`, with `cylinderSacProvider` returning fixed rows.

```dart
testWidgets('shows Loop use on an O2 row', ...);
  // CylinderSac(tankId: 'o2', loopRate: 1.8, tankVolume: 1.5, start 174, end 102)
  expect(find.text('Loop use 1.8 L/min'), findsOneWidget);
  expect(find.textContaining('Gas used'), findsOneWidget);
testWidgets('Loop use shows under every display preference', ...);
  // for each of GasConsumptionDisplay.values: 'Loop use 1.8 L/min' found
testWidgets('a split cylinder shows Loop use and RMV', ...);
  // loopRate: 2.3, sacRate: 2, tankVolume: 7, display rmv
  // expect 'Loop use 2.3 L/min' and 'RMV 14.0 L/min'
testWidgets('no loop gas and no bailout gas shows no rate', ...);
  // the Left row: expect find.textContaining('Loop use') findsNothing, 'RMV' findsNothing,
  // and 'Gas used 7 L' found
testWidgets('Loop use follows imperial units', ...);
  // AppSettings with cubic feet: expect find.text('Loop use ${units.formatRmv(1.8)}')
```

Check the exact formatted strings against `UnitFormatter.formatRmv` when writing the test.

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_ccr_test.dart > <scratchpad>/t2b.log 2>&1; echo $?`
Expected: non-zero, `Loop use` not found.

- [ ] **Step 7: Add the string and the line**

ARB, in every locale, anchored after that locale's `diveLog_cylinders_gasUsed`, with its `{rate}` placeholder. Values: en `Loop use {rate}`, de `Loop-Verbrauch {rate}`, es `Uso en el circuito {rate}`, fr `Conso. sur boucle {rate}`, it `Uso sul loop {rate}`, nl `Loopverbruik {rate}`, pt `Uso no circuito {rate}`, hu `Hurokfogyasztás {rate}`, zh `回路用量 {rate}`, ar `استهلاك الحلقة {rate}`, he `צריכה בלולאה {rate}`. Then `flutter gen-l10n`.

In `_tankRow`, in the `DotJoinedWrap`, after the Gas used text: a `Text(l10n.diveLog_cylinders_loopUse(units.formatRmv(loopRate)))` when `cylinderSac?.loopRate != null`, keyed `Key('tank-loop-use-${tank.id}')`.

- [ ] **Step 8: Run both test files and the existing card tests**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_ccr_test.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart test/features/dive_log/presentation/widgets/cylinders_card_role_test.dart test/l10n > <scratchpad>/t2c.log 2>&1; echo $?`
Expected: exit 0.

- [ ] **Step 9: Commit**

```bash
git add <the files above, the 11 ARB files and the generated app_localizations*.dart>
git commit -m "feat(dive-log): show loop use on a CCR dive's cylinders"
```

### Task 3: The statistics data

**Files:**
- Create: `lib/features/insights/domain/ccr_gas_use_trend.dart`
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart`
- Create: `lib/features/insights/data/repositories/insights_repository_ccr_gas_use.dart` (a part file following `insights_repository_tank_configuration.dart`, since the main file is past the 800-line guideline)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (the `part` line, and both by-role queries)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart`
- Modify: `lib/core/database/dive_stats_scope.dart` (doc only)
- Test: `test/features/insights/data/repositories/insights_repository_ccr_gas_use_test.dart` (create), `test/features/insights/data/repositories/insights_repository_rebreather_sac_test.dart`

**Interfaces:**
- Consumes: `ccrDiveUse`.
- Produces:

```dart
class CcrGasUseTrend {
  const CcrGasUseTrend({required this.o2, required this.diluent});
  final List<TrendDataPoint> o2;
  final List<TrendDataPoint> diluent;
  bool get isEmpty => o2.isEmpty && diluent.isEmpty;
  double? get o2Average;      // mean of the points, null when none
  double? get diluentAverage;
}

// TankPressureRepository
Future<Map<String, Map<String, List<TankPressurePoint>>>>
    getDisplayedTankPressuresForDives(List<String> diveIds);

// InsightsRepository
Future<CcrGasUseTrend> getCcrGasUsePerDive({String? diverId, DiveFilterState filter});

// providers
final ccrGasUseTrendProvider = FutureProvider<CcrGasUseTrend>(...);
```

- [ ] **Step 1: Write the failing tests**

Fixture as in `insights_repository_rebreather_sac_test.dart`, on a real test database. Seed through the same inserts plus `gasSwitches` and tank pressure series rows.

```dart
test('a CCR dive gives one O2 and one diluent point', () async {
  final trend = await repository.getCcrGasUsePerDive();
  expect(trend.o2.single.diveId, 'ccr');
  expect(trend.o2.single.value, closeTo(/* 126 bar * 3 L / 42 min */ 9, 1e-6));
});
test('a Sidemount cylinder lands in Diluent', ...);
test('a dive ticked out of gas statistics stays out', ...);
test('open-circuit and SCR dives stay out', ...);
test('a gauge dive stays out', ...);
test('the view filter applies', ...);
test('the diver filter applies', ...);
test('no CCR dives gives an empty trend', ...);  // isEmpty true
test('a dive with a bailout uses its series', ...);
test('a two-source dive uses the primary series', ...);
test('one dive reads the same here as on the card', () async {
  final dive = await DiveRepository().getDiveById('ccr');
  final card = const GasAnalysisService().calculateCylinderSac(
    dive: dive!, profile: dive.profile,
    gasSwitches: await DiveRepository().getGasSwitchesForDive('ccr'),
    tankPressures: await TankPressureRepository().getTankPressuresForDive('ccr'),
  );
  final trend = await repository.getCcrGasUsePerDive();
  final o2Row = card.firstWhere((r) => r.role == TankRole.oxygenSupply);
  expect(trend.o2.single.value, closeTo(o2Row.loopRate!, 1e-9));
});
test('averages are the mean of the per-dive rates', ...);
```

In `insights_repository_rebreather_sac_test.dart`, replace the by-role expectation:

```dart
test('the by-role breakdown leaves CCR dives out and keeps SCR', () async {
  final byRole = await repository.getSacVolumeByTankRole();
  // SCR's fixture rows remain; a CCR-only fixture gives no rows.
});
```

Same for `getSacPressureByTankRole`. Rewrite the file's header comment to say CCR dives now read through the new card.

- [ ] **Step 2: Run them to verify they fail**

One file per run, logged to the scratchpad. Expected: non-zero.

- [ ] **Step 3: Implement**

`getDisplayedTankPressuresForDives`: call `getTankPressuresForDives`, and for each dive group `export.displayedSeries` with the existing `_groupByTank`.

`getCcrGasUsePerDive`: `SELECT d.id, d.dive_date_time FROM dives d WHERE d.dive_mode = 'ccr' $diverFilter ${df.clause}` with `_diveFilter(filter, alias: 'd', gas: true)`. Then `_diveRepository.getDivesByIdsWithoutSamples(ids)`, `_diveRepository.getGasSwitchesForDives(ids)`, and the new pressure read, then `ccrDiveUse` per dive with `diveEnd: dive.effectiveRuntime?.inSeconds ?? 0` and `gasModel`. A point with `diveId` for each non-null rate, date from the row as `getSacVolumePerDive` does, sorted by date.

`ccrGasUseTrendProvider` copies `sacTrendProvider`, without the lane.

By-role: add `AND d.dive_mode <> 'ccr'` to both queries, with a comment naming this issue, and rewrite both doc comments and the `consumptionRate` paragraph in `dive_stats_scope.dart`, which says the breakdown keeps these dives.

- [ ] **Step 4: Run the tests, the census test and the role tests**

Run, one file per run: the two test files above, `test/core/database/dive_stats_scope_census_test.dart`, `test/features/insights/data/repositories/insights_repository_multi_cylinder_sac_test.dart`, `test/features/insights/data/repositories/insights_repository_sac_test.dart`.
Expected: exit 0 each. Any other test asserting CCR by-role rows is updated to the new rule.

- [ ] **Step 5: Commit**

```bash
git add <the files above>
git commit -m "feat(statistics): compute O2 and diluent use per CCR dive"
```

### Task 4: The Rebreather gas use card

**Files:**
- Create: `lib/features/insights/presentation/widgets/ccr_gas_use_section.dart`
- Modify: `lib/features/insights/presentation/widgets/trend_chart_section.dart`
- Modify: `lib/features/insights/presentation/providers/trend_chart_settings_provider.dart`
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart`
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/features/insights/presentation/widgets/ccr_gas_use_section_test.dart` (create), `test/features/insights/presentation/pages/insights_gas_page_widget_test.dart`

**Interfaces:**
- Consumes: `ccrGasUseTrendProvider`, `CcrGasUseTrend`.
- Produces: `TrendChartSection` gains `secondarySeries` (`List<TrendSeries>`, default empty, passed to `DiveTrendChart`) and `header` (`Widget?`, drawn above the chart inside the card). `TrendChartIds.ccrGasUse = 'ccr-gas-use'`. `CcrGasUseSection`: a `ConsumerWidget`, no constructor arguments.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('hidden when there are no CCR dives', ...);
  // override ccrGasUseTrendProvider with an empty trend
  expect(find.text('Rebreather gas use'), findsNothing);
testWidgets('hidden while loading and on error', ...);
testWidgets('shows both averages and both series', ...);
  // o2 points 1.2 and 1.6, diluent point 3.0
  expect(find.text('1.4 L/min'), findsOneWidget);
  expect(find.text('3.0 L/min'), findsOneWidget);
  final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
  expect(chart.points, hasLength(2));
  expect(chart.secondarySeries.single.points, hasLength(1));
testWidgets('a diver with diluent data only still gets the card', ...);
  // o2 empty: no O2 tile, chart.points empty
testWidgets('tapping a point opens the dive', ...);  // onDiveSelected pushes /dives/<id>
testWidgets('follows imperial units', ...);
```

On the page test: the card sits above the records and below the by-role card, and is absent with the default empty database.

- [ ] **Step 2: Run them to verify they fail**

One file per run, logged to the scratchpad. Expected: non-zero.

- [ ] **Step 3: Implement**

ARB keys, in every locale, in the `insights_gas_` group after `insights_gas_sacByRole_title`:

| Key | en |
| --- | --- |
| `insights_gas_ccrUse_title` | `Rebreather gas use` |
| `insights_gas_ccrUse_subtitle` | `Per minute on the loop, leaving out bailout time` |
| `insights_gas_ccrUse_error` | `Failed to load rebreather gas use` |
| `insights_gas_ccrUse_o2Average` | `O₂ average` |
| `insights_gas_ccrUse_diluentAverage` | `Diluent average` |
| `insights_gas_ccrUse_o2Series` | `O₂` |
| `insights_gas_ccrUse_diluentSeries` | `Diluent` |

`CcrGasUseSection.build`: when the provider has no data, or `isEmpty`, return `SizedBox.shrink()`. Otherwise a `Padding(bottom: 16)` around `TrendChartSection` with `chartId: TrendChartIds.ccrGasUse`, `pointsAsync: AsyncData(trend.o2)`, `lineColor: Colors.blue`, the diluent series in `Colors.orange`, `valueFormatter: units.formatRmv`, `yAxisFormatter` and `yAxisLabel: units.rmvSymbol` as in `_buildSacTrendSection`, `rateFormatter: units.formatRmv`, `onDiveSelected` pushing `/dives/$diveId`. `header`: a `Row` of two tiles (`surfaceContainerHigh` fill, rounded 8), each with a small colour dot, the formatted average and the label, one tile when one line has data. The dots double as the legend.

Page: `const CcrGasUseSection()` between `_buildSacByRoleSection`'s `SizedBox` and `_buildSacRecordsSection`. The section owns its spacing, so an open-circuit diver sees no gap.

- [ ] **Step 4: Run the tests**

Run, one file per run: both test files, `test/features/insights/presentation/widgets/trend_chart_section_test.dart` if present, and `test/l10n`.
Expected: exit 0 each.

- [ ] **Step 5: Commit**

```bash
git add <the files above, the 11 ARB files and the generated app_localizations*.dart>
git commit -m "feat(statistics): add a rebreather gas use card"
```

### Task 5: After screenshots and the final checks

**Files:**
- Modify: `test/tmp_shots/ccr_rates_shots_test.dart` (throwaway, add a `ccrGasUseTrendProvider` override and drop the before-only rows)

- [ ] **Step 1: Capture the after screenshots**

Run: `flutter test test/tmp_shots/ccr_rates_shots_test.dart --update-goldens --dart-define=SHOT_PHASE=after > <scratchpad>/shots-after.log 2>&1; echo $?`
Expected: exit 0, and `test/tmp_shots/goldens/*-after*.png` written. Look at each one.

- [ ] **Step 2: Copy them out and delete the harness**

Copy the PNGs to the scratchpad, then remove `test/tmp_shots`. Run this as its own step, never chained after the capture.

- [ ] **Step 3: Run the repo-wide checks**

Run: `dart format .`, `flutter analyze` (whole repo), `flutter test test/architecture`, `flutter test test/shared`.
Expected: clean, exit 0. Commit any format change as `style: format`.
