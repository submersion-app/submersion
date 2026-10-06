# Gas calculators, weather, and CNS: unit correctness and localization

Date: 2026-07-26
Branch: `worktree-gas-calc-weather-cns-units`
Status: approved

## Problem

A user reported against v1.7.0+117:

1. Weather and the CNS/O2 display are not localized and are metric-only.
2. Rock Bottom is "completely broken": minimum selectable consumption rate is
   15 cuft/min, minimum ascent rate is 20 ft/min, and a 100 ft dive with a 3 min
   safety stop yields a rock bottom of 18 cu ft (3 psi).
3. The Consumption calculator has similar nonsensical bounds and broken results.
4. Best Mix is really a MOD calculator, and recommends EAN32 for a 111 ft dive,
   which has no margin at ppO2 1.4.
5. Results are over-precise, which may cause overconfidence bias.

All five are confirmed. The reported digits reproduce exactly.

## Root causes

Every defect below is the same shape: a value crosses the presentation boundary
and a conversion mandated only by a doc comment is skipped. The edit forms
convert correctly in both directions; the read-only displays and the calculator
sliders do not.

### R1. SAC sliders never convert, and their range is off-scale

`rock_bottom_calculator.dart:164` and `:177` hardcode `min: 15, max: 35` and
`min: 15, max: 40` while labelling the value `'$volumeSymbol/min'`. Depth
(`:39`) and ascent rate (`:44`) do convert via `UnitFormatter`; SAC does not.
`gas_consumption_calculator.dart:119` has the same defect with `min: 8, max: 30`.

Two consequences, not one:

- An imperial diver reading "15 cuft/min" stores 15 L/min.
- 15 cuft/min is 425 L/min, roughly 28x a real stressed SAC. The canonical
  15-40 L/min range is 0.53-1.41 cuft/min, so **no valid imperial SAC was
  selectable anywhere on the slider**.

A third defect is latent behind the first: `_buildSliderSection:493` formats
with `toStringAsFixed(0)`. Adding conversion without adding per-axis decimals
would render every imperial SAC as `"1"`.

### R2. Tank chips store free-gas capacity as water capacity

`rockBottomTankSizeProvider` is documented as water capacity in liters
(`gas_calculators_providers.dart:105`), but the imperial chips are
`[63, 80, 100, 120]` -- cubic feet of **free gas** -- and `_buildTankChip`
(`rock_bottom_calculator.dart:541`, `gas_consumption_calculator.dart:409`)
pushes them through `volumeToLiters()`, storing ~2265 L for an AL80. Both
`totalBar` and `consumptionResultProvider` then divide by a number ~200x too
large.

`consumptionResultProvider:85` additionally hardcodes a 200 bar fill, which is
wrong for every imperial tank (AL80 is 207 bar, HP100/HP120 are 237 bar).

### R3. Ascent-rate bounds are metric-native and never snapped

`min: 6` m/min converts to 19.7 ft/min, displayed as the reported
"20 ft/min minimum". The bounds were never expressed on a sensible imperial
grid.

### R4. Best Mix buckets the result upward

`bestMixSuggestionProvider` (`gas_calculators_providers.dart:40-49`) maps the
exact result into a named mix using inclusive ranges that round **up**. At
111 ft / ppO2 1.4 the ideal is 31.94%, which falls in `>= 30 && <= 34` and
returns "EAN32". EAN32's own MOD at 1.4 is 33.75 m = 110.7 ft, **shallower than
the dive**. The calculator recommends a mix that is already exceeded at the
target depth.

### R5. Weather prose is English, metric, and persisted

Open-Meteo returns no text and has no language parameter (verified against the
Historical Weather API docs, 2026-07-26). The English prose is entirely ours:
`weather_mapper.dart:80-111` builds `"Clear, 24C, light breeze from North"`,
with `_windDescription` returning literal English (`:186-192`) and `:94`
hardcoding `'${airTempCelsius.round()}C'`. It is then written to
`dives.weather_description`, so it cannot be re-localized on read.

The raw WMO `weathercode` is read at `:130`, used only to classify
snow/sleet/hail in `mapPrecipitation`, then discarded.

Open-Meteo does accept `temperature_unit`, `wind_speed_unit`, and
`precipitation_unit`, and has **no** pressure unit parameter. We deliberately do
not use them: the response is persisted, so requesting imperial units would bake
a display preference into stored data and produce permanently mixed-unit rows
for any diver who switches units.

### R6. Read-only displays hardcode metric

- `dive_detail_page.dart:3028` -- surface pressure always `mbar`.
- `dive_detail_page.dart:3108` -- swell height always `m`. The edit page is
  correct in both directions (`:613` reads through `convertDepth`, `:1011` and
  `:4328` write through `depthToMeters`), so an imperial diver enters 3 ft,
  we correctly store 0.91 m, and the detail page shows "0.9m".
- `dive_edit_page.dart:1345` -- the phone-layout swell input has no
  `suffixText`, unlike its desktop twin at `:3531`.
- `o2_toxicity_card.dart:354` -- max ppO2 depth always `m`.

### R7. CNS/O2 card strings never went through ARB

`o2_toxicity_card.dart` hardcodes English at `:150`, `:215`, `:225`, `:238`,
`:258`, `:289-290`, `:747`, `:754`, `:762`, `:769`, `:801-803`, `:846`,
including `'This Dive'`, `'Daily'`, `'Weekly'`, `'Start:'`, `'Prior:'`,
`'+N this dive'`, and several Semantics labels.

## Decisions taken

| Question | Decision |
| --- | --- |
| Best Mix | Real best-mix planner: O2 rounded down, MOD + margin always shown, END-driven helium, gas-density readout |
| Precision | Round toward safety on a real-world grid, plus a caveat line per result card |
| Rock Bottom | Add problem-solving time at depth; drive all phases off the user's ascent rate |
| Weather text | Derive at display time, backfill old rows, and persist the WMO code |

## Design

### D1. Make the unit boundary structural

New: `lib/core/utils/unit_axis.dart`.

`UnitAxis` declares a slider's range **once, in canonical units**, and owns
conversion, symbol, decimals, and display-grid snapping. `UnitSlider` takes a
canonical value plus an axis and always hands back canonical values in
`onChanged`.

| Axis | Canonical | Metric display | Imperial display |
| --- | --- | --- | --- |
| Depth | 10-50 m | 10-50 m, step 1, 0 dp | 30-165 ft, step 5, 0 dp |
| Ascent rate | 3-18 m/min | 3-18, step 1, 0 dp | 10-60 ft/min, step 5, 0 dp |
| Stressed SAC | 15-40 L/min | 15-40, step 1, 0 dp | 0.50-1.40 cuft/min, step 0.05, 2 dp |
| Normal SAC | 8-30 L/min | 8-30, step 1, 0 dp | 0.30-1.05 cuft/min, step 0.05, 2 dp |
| Dive time | 5-90 min | same both | same both |

This makes R1 and R3 unrepresentable: a bound cannot be declared in display
units, and decimals travel with the axis rather than being fixed at 0.

### D2. Model tanks as water capacity plus working pressure

New: `TankSpec { waterVolumeLiters, workingPressureBar, ratedCapacityCuft?, label }`,
with `freeGasLiters` derived. Chips are built from the existing `TankPresets`
(which already carries all three fields), labelled via
`UnitFormatter.formatTankVolume`.

Replaces `rockBottomTankSizeProvider` and `consumptionTankSizeProvider`.
Reserve pressure becomes `requiredFreeGasLiters / waterVolumeLiters`, correct by
construction, and the hardcoded 200 bar fill is replaced by the selected tank's
own working pressure. Fixes R2.

### D3. Extract a pure, testable domain layer

New `lib/features/gas_calculators/domain/`:

- `gas_planning_inputs.dart` -- immutable input records in canonical units
- `rock_bottom.dart` -- `RockBottomResult computeRockBottom(RockBottomInputs)`
- `gas_consumption.dart` -- `ConsumptionResult computeConsumption(...)`
- `best_mix.dart` -- `BestMixResult computeBestMix(...)`

Providers become thin wrappers. Today none of this math is testable without a
widget tree, which is why it shipped broken.

### D4. Rock Bottom model

Four phases, all driven by the user's actual ascent rate. This replaces the
hardcoded `9.0` m/min final ascent (`:150`), the magic `1.5` and `1.25` ATA
constants (`:142`, `:151`), and the magic `3.56` minute total (`:161`).

| Phase | Gas |
| --- | --- |
| Problem-solving at depth (new, default 1 min) | `combinedSac * P(depth) * solveMin` |
| Ascent depth -> stop | `combinedSac * P((depth + stop) / 2) * (depth - stop) / ascentRate` |
| Safety stop | `combinedSac * P(stop) * stopMin` |
| Stop -> surface | `combinedSac * P(stop / 2) * stop / ascentRate` |

Each ascent phase is priced at the arithmetic mean depth of that phase, which is
exact for a constant-rate ascent. When the safety stop is disabled, `stop` is 0
and the last two phases vanish.

New provider `rockBottomSolveMinutesProvider` (default 1.0, range 0-3).

### D5. Best Mix planner

Rounds strictly toward safety and shows its work:

- **O2 rounded down** to whole percent -> deeper MOD -> safer.
- **He rounded up** to 5% -> shallower END -> safer. Uses the existing,
  already-tested `GasMix.heForMnd`.
- Always displays the recommended mix's own MOD, the margin below target depth,
  its END at depth, and gas density against the existing 5.2 / 6.2 g/L
  thresholds from `core/deco/gas_density.dart`.
- The named-mix suggestion becomes advisory and may only name a mix whose MOD
  still covers the target depth. The `>= 30 && <= 34 -> EAN32` bucketing is
  deleted outright.

END limit and O2-narcotic default from settings (`endLimit`, `o2Narcotic`),
matching the MND calculator's existing pattern of `ref.read` + `ref.invalidate`
on reset so user overrides survive unrelated settings changes.

### D6. Precision and caveats

| Result | Rounding |
| --- | --- |
| Rock bottom reserve | up, to 10 bar / 250 psi |
| Consumption pressure | up, to 10 bar / 100 psi |
| MOD | down, to whole m / whole ft |
| Best mix O2 | down, to whole percent |
| Best mix He | up, to 5 percent |

Each result card gains one caveat line: planning estimate, assumes a direct
ascent, verify against your training. This is a **single shared ARB key**
reused across all four calculators, not one key per calculator.

### D7. Weather

- Schema **v137**: add `dives.weather_code` (nullable int) via an idempotent
  `_assertWeatherCodeColumn()` called from both the `if (from < 137)` onUpgrade
  block and the `beforeOpen` backstop, mirroring the v135 accent-columns
  pattern.
- Migration also runs
  `UPDATE dives SET weather_description = NULL WHERE weather_source = 'openMeteo'`
  -- only rows we generated ourselves. Manual and imported text is untouched.
  Verified: `weatherSource` is persisted as `.name`
  (`dive_repository_impl.dart:1009`, `:1250`), so `'openMeteo'` is the literal
  stored string and the predicate is exact.
- `WeatherData` gains `weatherCode`. `WeatherMapper.mapApiResponse` keeps the
  code and **stops generating prose**: `description` is null for fetched
  weather. `buildDescription` is deleted.
- New `WeatherDescriptionBuilder` in the presentation layer renders from the WMO
  code when present, falling back to the bucketed enums, through
  `AppLocalizations` and `UnitFormatter`.
- Manual and imported descriptions still render verbatim.
- API request stays metric (see R5).

### D8. Read-only display fixes

- Surface pressure -> mbar/inHg, derived from depth unit, following the existing
  `_isMetricWind` precedent in `UnitFormatter`.
- Swell height -> `units.formatDistance(..., decimals: 1)`.
- Phone-layout swell input gains `suffixText: units.depthSymbol`.
- Max ppO2 depth -> `units.formatDepth`.
- **ppO2 stays in bar.** It is a physics unit, universal in diving regardless of
  unit preference; converting it to psi would be wrong.

### D9. CNS/O2 localization

ARB keys for every hardcoded string in R7, including Semantics labels and the
duration abbreviations in `_formatDuration` (`:425-429`, `:1046-1050`).

## Acceptance vectors

Computed with `python3`, not recalled. Implementers must report BLOCKED on a
mismatch rather than adjust a constant.

### Bug reproduction (must match the report before the fix)

Inputs: 100 ft, 20 ft/min, SAC 15 + 15 as displayed, 3 min safety stop, AL80.

```
stored SAC        15 + 15 L/min      (labels said cuft/min)
tank stored       2265 L             (free gas, should be 11.1 L water)
total             503.7 L = 17.8 cuft   -> report said "18 cu ft"
reserve           0.222 bar = 3.2 psi   -> report said "3 psi"
```

### Fixed behaviour

Case A -- same stored values (15 + 15 L/min), AL80 11.1 L @ 206.843 bar:

```
total    635.0 L = 22.4 cuft
reserve  57.2 bar / 830 psi   -> rounded up 60 bar / 1000 psi
```

Case B -- realistic imperial stressed SAC (1.0 + 1.0 cuft/min = 56.6 L/min):

```
solve  1.00 min @ 30.48 m    229.3 L
ascent 4.18 min              656.7 L
stop   3.00 min @  5.00 m    254.9 L
final  0.82 min               58.1 L
TOTAL                       1198.8 L = 42.3 cuft
reserve 108.0 bar / 1566 psi -> rounded up 110 bar / 1750 psi
```

Case C -- metric default (30 m, 9 m/min, 20 + 25 L/min, 12 L tank):

```
TOTAL 757.5 L -> 63.1 bar -> rounded up 70 bar
```

### Best Mix at 111 ft, ppO2 1.4

```
depth              33.83 m
ideal O2           31.94%
current (buggy)    EAN32, MOD 33.75 m = 110.7 ft   SHALLOWER than target
fixed              EAN31, MOD 35.16 m = 115.4 ft   margin 4.4 ft
density EAN31      5.33 g/L  (over the 5.2 warn threshold, flagged)
END (O2 narcotic)  111 ft
nearest standard covering mix  EAN30 (MOD 120.3 ft)
```

### Axis snapping

```
ascent rate canonical 3-18 m/min -> 9.8-59.1 ft/min -> snapped 10-60 step 5
old min 6 m/min -> 19.7 ft/min   (the reported "20 ft/min minimum")
SAC canonical 15-40 L/min -> 0.53-1.41 cuft/min -> snapped 0.50-1.40 step 0.05
```

## Test plan

TDD: tests first, per project convention.

**Domain (pure, fast):**
- `rock_bottom_test.dart` -- Cases A, B, C above; solve-minutes term; safety
  stop on/off; ascent rate drives all phases.
- `best_mix_test.dart` -- the 111 ft regression (recommended mix MOD must be
  >= target depth); O2 floors, never ceils; He rounds up; density and END
  thresholds.
- `gas_consumption_test.dart` -- tank working pressure used, not 200 bar.
- `unit_axis_test.dart` -- roundtrip canonical -> display -> canonical for every
  axis; snapped bounds; per-axis decimals.
- `tank_spec_test.dart` -- AL80 is 11.1 L water / 80 cuft free gas, not 2265 L.

**Migration:**
- `migration_v137_weather_code_test.dart` -- `greaterThanOrEqualTo(137)` +
  `contains(137)` from the start, per the superseded-tripwire convention. Assert
  both the upgrade path and a fresh in-memory DB (separate failure modes).
  Assert openMeteo descriptions are nulled and manual ones are not.
- Relax the existing v136 exact-latest tripwire at
  `migration_v136_media_stores_sweep_test.dart:58`
  (`expect(AppDatabase.currentSchemaVersion, 136)`) to
  `greaterThanOrEqualTo(136)`.

**Weather:**
- `weather_mapper_test.dart` -- weatherCode retained; description null for
  fetched weather. Existing `buildDescription` tests are removed with the method.
- `weather_description_builder_test.dart` -- WMO code path, enum fallback,
  locale and unit variation.

**Widget:**
- Rock bottom and consumption render sensible imperial bounds and 2-dp SAC.
- Detail page renders swell height and surface pressure in both unit systems.
- O2 card renders no hardcoded English.

## Out of scope

Deliberately excluded; each is tracked separately and would widen this PR past
reviewability:

- The ascent-rate sign inversion in `core/deco/ascent_rate_calculator.dart`
  (`:115` descent reported as ascent, `:284` zero-length violations). Separate
  subsystem, separate PR.
- GUE EDGE pre-dive seed data being 4 items instead of 7.
- Pre-dive checklist auto-attach on manual dive creation.
- Planner GF defaults, tide chart accuracy, surface-interval discontinuity.

## Risks

- **l10n volume.** Roughly 50 new keys across en plus 10 non-en locales,
  including ~28 WMO code names. Per project convention all locales are
  translated and regenerated, not just English. This is the bulk of the
  mechanical work.
- **Schema collision.** v137 is free as of main at `currentSchemaVersion = 136`
  (`database.dart:2849`), but parallel branches share this scalar. Re-grep
  current origin/main before merging and renumber if needed.
- **Breaking provider signatures.** `consumptionTankSizeProvider` and
  `rockBottomTankSizeProvider` change type from `double` to `TankSpec`. Both are
  private to the gas calculators feature; `resetGasCalculators` updates with them.
