# Best Mix Rec / OC-Tec / CCR-Tec Modes Implementation Plan

**Goal:** Split the Best Mix calculator into Rec / OC-Tec / CCR-Tec modes,
mirroring the MOD calculator (issue #2342), with a CCR-Tec Diluent/Bailout
ppO2 source choice and an optional density-aware helium requirement in the Tec
modes.

**Architecture:** `best_mix.dart` gains a mode-aware ambient-pressure model
(flat for Rec, `DiveEnvironment` for Tec) and a second, independent helium
requirement driven by gas density, combined with the existing END-driven
requirement by taking the richer of the two. Profile ppO2 limits and their
per-diver overrides are not duplicated: Best Mix depends on the MOD
calculator's existing `mod_limit_overrides.dart` types. Persistence and
provider structure mirror `mod_calculator_providers.dart` exactly. The UI
splits into a `presentation/widgets/best_mix/` card directory, the same
restructuring the blender and MOD calculator went through.

**Spec:** `docs/design/specs/2026-10-08-best-mix-tec-modes-design.md`

## Global constraints

- No em-dashes, no emojis, in any output.
- `dart format .` clean, `flutter analyze` clean (infos are fatal in CI).
- Every user-facing string in `lib/l10n/arb/app_en.arb` and all ten
  translated ARBs; run `flutter gen-l10n` last.
- Files stay under 800 lines, 200-400 typical.
- Depths in metres, pressures in bar, temperatures in Celsius internally;
  display converts through `UnitFormatter`.
- Never run two `flutter test` invocations concurrently.
- TDD: write the failing test before the implementation, per task.

## Self-answered open items from the design doc

These were called out as open in the design doc or arose while planning; each
is answered here from the existing codebase rather than left for a later
question, with the reasoning that resolved it.

1. **Does Best Mix need its own `WaterType`/`DiveEnvironment` ambient model
   for Tec, or can it keep the flat model and only change the density
   formula?** Needs the full `DiveEnvironment` model. The decision (density
   decisions table, "ambient pressure model") was explicit that Tec modes
   follow `DiveEnvironment` like the MOD calculator; the density closed form
   derived below depends on the same ambient pressure the EAD/END figures
   use, so a split between "flat EAD/END, DiveEnvironment density" would show
   two different ambient pressures for the same depth in the same card. One
   ambient model per mode, as MOD already does.
2. **Where does `heForDensityLimit` live?** In `best_mix.dart` itself, not a
   new file: it is used nowhere else, it is one closed-form function plus a
   handful of constants already public in `gas_density.dart`, and MOD's
   analogous narcosis solve (`GasMix.heForMnd`) lives beside its caller too.
3. **Does the EAD/END pair replace or sit beside the single `endMeters` field
   already on `MixAssessment`?** Beside it. Rec keeps using `endMeters`
   exactly as today (one row, label depends on `o2Narcotic`); the Tec EAD/END
   pair is additive, on a `MixAssessment` field that is null in Rec, so
   `best_mix_test.dart`'s existing Rec assertions do not move.
4. **Does `CcrGasSource` need to exist as a value in Rec and OC-Tec
   preferences too, or only CCR-Tec's?** Only CCR-Tec stores it in its own
   mode slot (`BestMixModeInputs` is per-mode already), consistent with how
   `ModCalculatorPreferences.ccrTec` is the only slot touched by CCR-only
   settings.
5. **Does the density closed form need the general `computeGasDensity`
   machinery (loop/setpoint), or the plain partial-pressure formula?** Plain
   partial pressures. Per the design doc's domain section, CCR-Tec in Best
   Mix is not a loop model; "Diluent" and "Bailout" only pick which ppO2
   limit is used, so the gas is always treated as breathed open circuit (the
   diluent on a flush, or the bailout cylinder). `computeGasDensity`'s
   setpoint branch is never exercised and is not needed as a dependency.

## Task 1: Mode-aware ambient model and EAD/END pair in `best_mix.dart`

Pure domain change, additive. No mode switching UI yet; the new fields on
`BestMixInputs` default to Rec-equivalent values so nothing calling the
function with today's four fields changes behaviour. (The actual provider
switch-over happens in Task 3; this task only makes the domain function
capable of it, test-first.)

**Files:**
- Modify: `lib/features/gas_calculators/domain/best_mix.dart`
- Modify: `test/features/gas_calculators/domain/best_mix_test.dart` (append
  groups; existing groups and their Python-verified constants are not
  touched)

**Interfaces added:**

```dart
enum BestMixMode { rec, ocTec, ccrTec }
enum CcrGasSource { diluent, bailout }
enum HeliumDriver { none, endLimit, density, both }

class BestMixInputs {
  // existing: depthMeters, ppO2Limit, endLimitMeters, o2Narcotic (all still required)
  final BestMixMode mode;              // default BestMixMode.rec
  final CcrGasSource ccrSource;        // default CcrGasSource.diluent, read only in ccrTec
  final double flushPpO2;              // default 0, read only in ccrTec + diluent
  final WaterType waterType;           // default WaterType.salt, read only outside rec
  final bool densityAware;             // default false; read only outside rec
  final GasDensityTemperature temperature; // default zeroC; read only outside rec
}
```

Every new field defaults to a Rec-equivalent, unused value. This is
deliberate so the existing call site in
`gas_calculators_providers.dart:40-48` (`bestMixResultProvider`, four named
arguments, no `mode`) keeps compiling unchanged until Task 3 replaces it;
without defaults, Task 1 alone would not compile against the current
provider and the "every task leaves the tree green" rule in Step 4/Step 6
of later tasks would be broken from the start.

`ppO2Limit` keeps its current meaning for Rec and OC-Tec/Bailout (the
resolved working ppO2 or the Rec chip value, chosen by the caller before
constructing `BestMixInputs`, exactly as it is chosen today). Only the
CCR-Tec + Diluent case substitutes `flushPpO2` for it internally:

```dart
double _limitPpO2(BestMixInputs i) =>
    i.mode == BestMixMode.ccrTec && i.ccrSource == CcrGasSource.diluent
        ? i.flushPpO2
        : i.ppO2Limit;
```

This keeps the provider layer (Task 3) responsible for resolving profile
overrides into plain numbers, the same split `GasLimitsInputs` already uses
(it takes `workingPpO2`/`decoPpO2`/`flushPpO2` as resolved numbers, not
overrides).

`MixAssessment` gains:

```dart
/// Equivalent air depth (N2 only narcotic), computed alongside [endMeters]
/// (N2 and O2 narcotic) in the Tec modes so both are visible regardless of
/// the O2-narcotic setting. Null in Rec, where only the single row the
/// O2-narcotic setting selects is shown, unchanged from today.
final double? eadMeters;
```

**Ambient model:**

```dart
bool _isTec(BestMixMode mode) => mode != BestMixMode.rec;

DiveEnvironment? _environmentFor(BestMixInputs inputs) =>
    _isTec(inputs.mode)
        ? DiveEnvironment.forConditions(waterType: inputs.waterType)
        : null;
```

`_assess` branches on whether an environment was resolved:

```dart
MixAssessment _assess(GasMix mix, BestMixInputs inputs) {
  final environment = _environmentFor(inputs);
  final double ambient;
  final double end;
  double? ead;
  double density;

  if (environment == null) {
    // Rec: today's flat model, byte-identical to the current function.
    ambient = ambientPressureAtDepth(inputs.depthMeters);
    end = mix.end(inputs.depthMeters, o2Narcotic: inputs.o2Narcotic);
    density = gasDensityGPerL(
      fO2: mix.o2 / 100,
      fHe: mix.he / 100,
      ambientPressureBar: ambient,
    );
  } else {
    ambient = environment.pressureAtDepth(inputs.depthMeters);
    final fO2 = mix.o2 / 100;
    final fHe = mix.he / 100;
    final fN2 = 1.0 - fO2 - fHe;
    final pO2 = fO2 * ambient;
    final pN2 = fN2 * ambient;
    final pHe = fHe * ambient;
    double depthAt(double bar) =>
        math.max(environment.depthAtPressure(bar), 0.0);
    final endMeters = depthAt(pN2 + pO2);
    final eadMeters = depthAt(pN2 / airN2Fraction);
    end = inputs.o2Narcotic ? endMeters : eadMeters;
    ead = eadMeters;
    density = gasDensityFromPartialPressures(
      pO2Bar: pO2,
      pN2Bar: pN2,
      pHeBar: pHe,
      temperatureC: inputs.temperature.celsius,
    );
    // _assess always reports the N2+O2 END too via the separate `end`
    // field below, independent of o2Narcotic, so the UI's exceedsEndLimit
    // check keeps using the setting-selected value while the display can
    // show both.
  }

  // MOD/margin must use the same ambient model as END/EAD/density above:
  // `mix.mod()` alone is always the flat model, which would silently give
  // Tec a flat MOD next to a DiveEnvironment-based END in the same card.
  final mod = maxOperatingDepthMeters(
    mix.o2 / 100,
    maxPpO2: _limitPpO2(inputs),
    environment: environment,
  );

  return MixAssessment(
    mix: mix,
    modMeters: mod,
    marginMeters: mod - inputs.depthMeters,
    endMeters: end,
    eadMeters: ead,
    exceedsEndLimit: end > inputs.endLimitMeters + 1e-9,
    densityGPerL: density,
    exceedsWarnDensity: density > gasDensityWarnGPerL,
    exceedsCriticalDensity: density > gasDensityCriticalGPerL,
  );
}
```

Needs `import 'dart:math' as math';`, `DiveEnvironment` from
`core/deco/entities/dive_environment.dart`, `WaterType` from
`core/constants/enums.dart`, `airN2Fraction` and `gasDensityFromPartialPressures`
from `core/deco/gas_density.dart`, `GasDensityTemperature` from
`gas_density_calculator.dart`.

- [ ] **Step 1:** Append a test group to `best_mix_test.dart` for the Tec
  ambient model, pinned against a hand-computed vector (salt water,
  `DiveEnvironment` default surface pressure 1.0 bar, 10 msw per bar):

  ```dart
  group('Tec ambient model (OC-Tec, salt water, 0 C)', () {
    // DiveEnvironment's salt water (1025 kg/m3) is close to but not
    // identical to the flat 1 bar/10 m model (barPerMeter is about 0.10052,
    // not 0.1), so this is a same-mode sanity check, not a cross-check
    // against the Rec path.
    final r = computeBestMix(
      BestMixInputs(
        depthMeters: 30,
        ppO2Limit: 1.4,
        endLimitMeters: 30,
        o2Narcotic: true,
        mode: BestMixMode.ocTec,
        waterType: WaterType.salt,
        temperature: GasDensityTemperature.zeroC,
      ),
    );

    test('EAD and END are both populated', () {
      expect(r.recommended.eadMeters, isNotNull);
      expect(r.recommended.endMeters, greaterThanOrEqualTo(0));
    });

    test('EAD matches END for a helium-free mix', () {
      // No helium: O2-narcotic or not makes no difference to the narcotic
      // fraction actually breathed, only to which baseline it is read
      // against, so for a pure nitrox EAD and END coincide.
      expect(r.recommended.eadMeters, closeTo(r.recommended.endMeters, 0.05));
    });
  });
  ```

- [ ] **Step 2:** Run, expect compile failure (`mode` named parameter does
  not exist).
- [ ] **Step 3:** Implement as above.
- [ ] **Step 4:** Run `flutter test test/features/gas_calculators/domain/best_mix_test.dart`;
  all existing and new tests pass. Existing Rec vectors (111 ft regression
  group) are the regression gate and must pass with their constants
  untouched.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, commit:
  `feat(gas-calculators): mode-aware ambient model in best mix` with
  `Refs #3112`.

## Task 2: Density-driven helium requirement

**Files:**
- Modify: `lib/features/gas_calculators/domain/best_mix.dart`
- Modify: `test/features/gas_calculators/domain/best_mix_test.dart`

**Closed form.** At fixed `o2Percent` and depth, density is affine in the
helium fraction (helium displaces nitrogen only):

```
density(fHe) = ambient/(R*T) * [fO2*Mo2 + (1-fO2)*Mn2 + fHe*(Mhe - Mn2)]
```

Solving `density(fHe) = gasDensityCriticalGPerL` for `fHe` gives the helium
fraction at which density sits exactly on the critical limit. Since
`Mhe < Mn2`, the coefficient of `fHe` is negative, i.e. density strictly
decreases as helium increases, so the mix is compliant for every `fHe` at or
above the solution.

```dart
/// Helium percent needed to bring the density of [o2Percent] nitrox/trimix
/// down to [gasDensityCriticalGPerL] at [depthMeters], [temperature] and
/// [waterType]. Zero when the nitrox mix alone is already compliant.
///
/// Closed form, not a search: density is affine in the helium fraction at
/// fixed O2 and depth, since helium only displaces nitrogen.
double heForDensityLimit(
  double depthMeters,
  double o2Percent, {
  required GasDensityTemperature temperature,
  required WaterType waterType,
}) {
  final fO2 = o2Percent.clamp(0.0, 100.0) / 100;
  final ambient = DiveEnvironment.forConditions(waterType: waterType)
      .pressureAtDepth(math.max(depthMeters, 0.0));
  final kelvin = temperature.celsius + 273.15;
  final a = ambient / (gasConstantLBarPerMolK * kelvin);
  final base = fO2 * o2MolarMassGPerMol + (1 - fO2) * n2MolarMassGPerMol;
  final slope = heMolarMassGPerMol - n2MolarMassGPerMol; // negative
  final fHe = (gasDensityCriticalGPerL / a - base) / slope;
  return (fHe * 100).clamp(0.0, 100.0 - o2Percent);
}
```

`computeBestMix` combines the two requirements. The existing END-driven
helium keeps its 5% rounding; density-driven helium rounds to 1%:

```dart
double _ceilToStep(double value, double step) => (value / step).ceil() * step;
```

**Correction found during cross-examination:** `GasMix.heForMnd` always
solves against the flat 1 bar/10 m model. Calling it directly for the Tec
modes would compute a narcosis-driven helium requirement against a
different ambient pressure than the one `_assess` actually checks the
result against (`DiveEnvironment`, fresh water in particular departs from
the flat model by more than salt water does). The recommended mix could
then pass its own `exceedsEndLimit` check only by accident. A
environment-aware sibling, same algebra as `GasMix.heForMnd`, with
`environment == null` delegating to it unchanged for Rec:

```dart
double _heForNarcosisLimit({
  required double targetDepthMeters,
  required double o2,
  required double endLimit,
  required bool o2Narcotic,
  required DiveEnvironment? environment,
}) {
  if (environment == null) {
    return GasMix.heForMnd(
      targetDepthMeters,
      o2,
      endLimit: endLimit,
      o2Narcotic: o2Narcotic,
    );
  }
  final targetPressure = environment.pressureAtDepth(endLimit);
  final maxPressure = environment.pressureAtDepth(targetDepthMeters);
  final he = o2Narcotic
      ? (1 - targetPressure / maxPressure) * 100
      : 100 - o2 - (targetPressure * airN2Fraction / maxPressure * 100);
  return he.clamp(0.0, 100.0 - o2);
}
```

```dart
var recommended = nitrox;
MixAssessment? alternative;
var driver = HeliumDriver.none;

final heForEnd = nitrox.exceedsEndLimit
    ? _ceilToStep(
        _heForNarcosisLimit(
          targetDepthMeters: inputs.depthMeters,
          o2: o2,
          endLimit: inputs.endLimitMeters,
          o2Narcotic: inputs.o2Narcotic,
          environment: _environmentFor(inputs),
        ),
        5,
      ).clamp(0.0, 100.0 - o2)
    : 0.0;

final heForDensity = inputs.densityAware && _isTec(inputs.mode)
    ? _ceilToStep(
        heForDensityLimit(
          inputs.depthMeters,
          o2,
          temperature: inputs.temperature,
          waterType: inputs.waterType,
        ),
        1,
      ).clamp(0.0, 100.0 - o2)
    : 0.0;

final he = math.max(heForEnd, heForDensity);
if (he > 0) {
  recommended = _assess(GasMix(o2: o2, he: he), inputs);
  alternative = nitrox;
  driver = switch ((heForEnd > 0, heForDensity > 0)) {
    (true, true) => HeliumDriver.both,
    (true, false) => HeliumDriver.endLimit,
    (false, true) => HeliumDriver.density,
    (false, false) => HeliumDriver.none, // unreachable, he > 0 implies one
  };
}
```

`BestMixResult` gains `final HeliumDriver heliumDriver;`.

- [ ] **Step 1:** Append tests:

  ```dart
  group('heForDensityLimit', () {
    test('zero when the nitrox mix is already compliant', () {
      expect(
        heForDensityLimit(20, 32,
            temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt),
        0,
      );
    });

    test('closed form agrees with the general partial-pressure formula', () {
      // Cross-check, not a hand-derived constant: solve for fHe, then feed
      // that mix back through gasDensityFromPartialPressures and confirm it
      // lands on the critical limit.
      const depth = 60.0;
      const o2 = 18.0;
      final he = heForDensityLimit(depth, o2,
          temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt);
      final ambient = DiveEnvironment.forConditions(waterType: WaterType.salt)
          .pressureAtDepth(depth);
      final fO2 = o2 / 100;
      final fHe = he / 100;
      final fN2 = 1 - fO2 - fHe;
      final density = gasDensityFromPartialPressures(
        pO2Bar: fO2 * ambient,
        pN2Bar: fN2 * ambient,
        pHeBar: fHe * ambient,
        temperatureC: 0,
      );
      expect(density, closeTo(gasDensityCriticalGPerL, 0.01));
    });

    test('more helium at the same depth cannot be required for a richer nitrox', () {
      final at32 = heForDensityLimit(70, 32,
          temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt);
      final at21 = heForDensityLimit(70, 21,
          temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt);
      expect(at32, lessThanOrEqualTo(at21));
    });

    test('warmer gas is less dense and needs less helium', () {
      final cold = heForDensityLimit(70, 21,
          temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt);
      final warm = heForDensityLimit(70, 21,
          temperature: GasDensityTemperature.twentyC, waterType: WaterType.salt);
      expect(warm, lessThanOrEqualTo(cold));
    });
  });

  group('computeBestMix density-aware helium', () {
    test('density switch off: behaves exactly as narcosis-only (regression)', () {
      final r = computeBestMix(BestMixInputs(
        depthMeters: 70, ppO2Limit: 1.4, endLimitMeters: 30, o2Narcotic: true,
        mode: BestMixMode.ocTec, waterType: WaterType.salt,
        densityAware: false,
      ));
      expect(r.heliumDriver, r.recommended.mix.isTrimix
          ? HeliumDriver.endLimit : HeliumDriver.none);
    });

    test('density switch on: adds helium beyond the narcosis-only amount when density binds', () {
      final withoutDensity = computeBestMix(BestMixInputs(
        depthMeters: 70, ppO2Limit: 1.4, endLimitMeters: 45, // loose END limit
        o2Narcotic: true, mode: BestMixMode.ocTec, waterType: WaterType.salt,
        densityAware: false,
      ));
      final withDensity = computeBestMix(BestMixInputs(
        depthMeters: 70, ppO2Limit: 1.4, endLimitMeters: 45,
        o2Narcotic: true, mode: BestMixMode.ocTec, waterType: WaterType.salt,
        densityAware: true,
      ));
      expect(withDensity.recommended.mix.he,
          greaterThan(withoutDensity.recommended.mix.he));
      expect(withDensity.heliumDriver, HeliumDriver.density);
    });

    test('density-driven helium rounds up to 1%, not 5%', () {
      final r = computeBestMix(BestMixInputs(
        depthMeters: 70, ppO2Limit: 1.4, endLimitMeters: 45,
        o2Narcotic: true, mode: BestMixMode.ocTec, waterType: WaterType.salt,
        densityAware: true,
      ));
      // Not necessarily a multiple of 5; must be a multiple of 1 (every
      // double is), so assert against the un-rounded requirement directly:
      // rounding up by at most 1 percentage point.
      final raw = heForDensityLimit(70, r.recommended.mix.o2,
          temperature: GasDensityTemperature.zeroC, waterType: WaterType.salt);
      expect(r.recommended.mix.he - raw, lessThan(1.0));
      expect(r.recommended.mix.he, greaterThanOrEqualTo(raw));
    });

    test('both checks binding reports HeliumDriver.both', () {
      // A deep target with both a tight END limit and density active; both
      // paths need helium, and the max of the two happens to be the END
      // path's 5% step while density still contributed.
      final r = computeBestMix(BestMixInputs(
        depthMeters: 90, ppO2Limit: 1.4, endLimitMeters: 30,
        o2Narcotic: true, mode: BestMixMode.ocTec, waterType: WaterType.salt,
        densityAware: true,
      ));
      expect(r.heliumDriver, anyOf(HeliumDriver.both, HeliumDriver.endLimit,
          HeliumDriver.density));
      // At minimum, both individual requirements are non-zero at this depth.
      expect(r.recommended.mix.isTrimix, isTrue);
    });
  });
  ```

  The last test deliberately asserts a weaker, direction-only property
  (`anyOf`) because which path dominates depends on the exact depth; tighten
  it once the real numbers are known after Step 4, replacing `anyOf(...)`
  with the actual expected driver and adding the two individual non-zero
  assertions (`heForEnd`/`heForDensity` are private, so assert via
  `heliumDriver` plus the known-binding `endLimitMeters`/density flags on
  `nitroxAlternative`).

- [ ] **Step 2:** Run, expect compile/assertion failures.
- [ ] **Step 3:** Implement as above.
- [ ] **Step 4:** Run the full file; tighten the weakened assertion from
  Step 1 once real numbers are observed.
- [ ] **Step 5:** `dart format .`, `flutter analyze`, commit:
  `feat(gas-calculators): density-aware helium in best mix` with
  `Refs #3112`.

## Task 3: Persisted preferences and providers

**Files:**
- Create: `lib/features/gas_calculators/domain/best_mix_calculator_preferences.dart`
- Create: `lib/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart`
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart`
  (remove the four `bestMix*` `StateProvider`s and the `BestMix` block in
  `resetGasCalculators`; call the new notifier's `reset()` instead, same
  pattern as the `modCalculatorNotifierProvider` line already there)
- Test: `test/features/gas_calculators/domain/best_mix_calculator_preferences_test.dart`
- Modify: `test/features/gas_calculators/gas_calculators_page_test.dart` (any
  assertion reading the removed providers directly)

**`BestMixCalculatorPreferences`**, mirroring `mod_calculator_preferences.dart`:

```dart
class BestMixModeInputs {
  final double depthMeters;
  final bool densityAware;      // ignored/false in rec
}

class BestMixCalculatorPreferences {
  final BestMixMode mode;
  final BestMixModeInputs rec;
  final BestMixModeInputs ocTec;
  final BestMixModeInputs ccrTec;
  final CcrGasSource ccrSource;
  final WaterType? waterType;              // null follows the planner default
  final GasDensityTemperature temperature;
  final Map<String, ModLimitOverrides> overridesByDiver;
}
```

Rec's ppO2 stays the existing three fixed chips (1.2/1.4/1.6), stored as a
plain `double ppO2Limit` field on `rec` only (the Tec slots do not need it,
since Tec ppO2 comes from the resolved profile limits). JSON shape, defaults,
and malformed-field fallback follow `ModCalculatorPreferences.fromJson`'s
per-field pattern exactly (one try per field, never discard the whole blob).

Defaults: `mode: rec`, `rec: (depthMeters: 30, densityAware: false, ppO2Limit: 1.4)`,
`ocTec`/`ccrTec`: `(depthMeters: 50, densityAware: false)`, `ccrSource: diluent`,
`waterType: null`, `temperature: zeroC` (the MOD calculator's conservative
default, kept here too even though both are selectable, per the design doc's
"defaults" convention), `overridesByDiver: {}`.

**Provider notifier**, byte-for-byte the `ModCalculatorNotifier` pattern:
`AppSettingsRepository` key `gas_best_mix_calculator_prefs`, `reload()` on
creation and on every settings tick, 500 ms debounced `_save()`, pending save
flushed on `dispose()`.

```dart
final bestMixCalculatorNotifierProvider =
    StateNotifierProvider<BestMixCalculatorNotifier, BestMixCalculatorPreferences>(...);

final bestMixCalculatorLimitsProvider = Provider<ModResolvedLimits>((ref) {
  final prefs = ref.watch(bestMixCalculatorNotifierProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final settings = ref.watch(settingsProvider);
  return resolveModLimits(prefs.overridesFor(diverId), modProfileLimits(settings));
});

final bestMixCalculatorInputsProvider = Provider<BestMixInputs>((ref) {
  final prefs = ref.watch(bestMixCalculatorNotifierProvider);
  final settings = ref.watch(settingsProvider);
  final limits = ref.watch(bestMixCalculatorLimitsProvider);
  final mode = prefs.inputsFor(prefs.mode);
  return BestMixInputs(
    depthMeters: mode.depthMeters,
    mode: prefs.mode,
    ccrSource: prefs.ccrSource,
    ppO2Limit: prefs.mode == BestMixMode.rec ? prefs.rec.ppO2Limit : limits.workingPpO2,
    flushPpO2: limits.flushPpO2,
    endLimitMeters: settings.endLimit,
    o2Narcotic: settings.o2Narcotic,
    waterType: modCalculatorWaterType(prefs, settings), // see note below
    densityAware: mode.densityAware,
    temperature: prefs.temperature,
  );
});

final bestMixCalculatorResultProvider = Provider<BestMixResult>(
  (ref) => computeBestMix(ref.watch(bestMixCalculatorInputsProvider)),
);
```

Note: `modCalculatorWaterType` takes a `ModCalculatorPreferences`; it needs a
same-shaped overload (or a small shared free function taking `WaterType?` and
`AppSettings` directly, which both calculators then call) rather than a
second copy of the fallback logic. Prefer extracting
`WaterType resolveWaterType(WaterType? stored, AppSettings settings)` into
`mod_limit_overrides.dart` (or a new tiny shared file) and having both
`modCalculatorWaterType` and the Best Mix equivalent call it, so the fallback
rule (planner default, custom maps to salt) stays in one place.

`modProfileLimits`/`resolveModLimits`/`ModLimitOverrides`/`ModProfileLimits`
are imported from `mod_limit_overrides.dart` and `mod_calculator_providers.dart`
unchanged; Best Mix does not redefine them (per spec decision).

- [ ] **Step 1:** Write `best_mix_calculator_preferences_test.dart`: JSON
  round-trip (every field, including a non-default `CcrGasSource.bailout`
  and `GasDensityTemperature.twentyC`), per-diver overrides stored and
  resolved independently of the MOD calculator's own overrides (the two
  calculators use the same `ModLimitOverrides` type but separate storage
  keys and separate `overridesByDiver` maps, so setting one never touches
  the other), malformed fields falling back per field, an emptied/default
  state round-tripping.
- [ ] **Step 2:** Run, expect failure (file does not exist).
- [ ] **Step 3:** Implement preferences class.
- [ ] **Step 4:** Run, expect pass.
- [ ] **Step 5:** Implement providers; update `gas_calculators_providers.dart`
  (remove old providers and reset block, add
  `ref.read(bestMixCalculatorNotifierProvider.notifier).reset();`).
- [ ] **Step 6:** Run `flutter analyze` across `lib/features/gas_calculators`
  and `flutter test test/features/gas_calculators/gas_calculators_page_test.dart`;
  fix any reference to the removed providers.
- [ ] **Step 7:** `dart format .`, commit:
  `feat(gas-calculators): persist best mix preferences per mode` with
  `Refs #3112`.

## Task 4: User interface

**Files:**
- Create: `lib/features/gas_calculators/presentation/widgets/best_mix/best_mix_input_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/best_mix/best_mix_density_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/best_mix/best_mix_result_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/best_mix/best_mix_alternative_card.dart`
- Create: `lib/features/gas_calculators/presentation/widgets/best_mix/best_mix_common_mixes_card.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/best_mix_calculator.dart`
  (becomes the five-card composing shell, `ConsumerWidget` to
  `StatelessWidget` since no card reads `ref` directly at the top level
  anymore)
- Test: `test/features/gas_calculators/best_mix_calculator_widget_test.dart`
  (existing file; extend rather than replace, since the five existing
  `testWidgets` blocks exercise behaviour that is unchanged in Rec)

**Card contents**, matching the design doc's UI section:

1. **Input card:** mode `SegmentedButton<BestMixMode>`; mode hint text
   (follow the MOD calculator's three-hint pattern); target depth
   `UnitSlider`; Rec: ppO2 chips (existing `_buildPpO2Chip`, moved here
   unchanged); Tec: resolved working/flush ppO2 shown as a read-only
   breakdown row (Best Mix does not expose an override slider here, since
   that already exists on the MOD calculator and both read/write the same
   profile, only the per-diver override map differs by calculator); CCR
   source `SegmentedButton<CcrGasSource>`, visible only when
   `mode == ccrTec`, placed directly under the mode selector.
2. **Density card:** omitted entirely in Rec (the whole card, not just its
   contents, per the design doc's "Rec never shows it"). `SwitchListTile`
   for `densityAware`; `GasDensityTemperature` and `WaterType`
   `SegmentedButton`s in a `Wrap`, matching `density_input_card.dart`'s
   layout exactly.
3. **Result card:** existing content (`_buildBreakdownRow` calls) plus,
   in Tec modes, an EAD row alongside the existing END row (both labelled,
   neither replacing the other); the helium-driver note
   (`HeliumDriver.endLimit`/`density`/`both`) replacing the current
   unconditional caption at the `isTrimix` branch.
4. **Alternative card:** existing `_buildAlternativeCard`, unchanged logic,
   moved verbatim.
5. **Common mixes card:** existing `_buildMixRow`/nearest-standard block,
   unchanged logic, moved verbatim.

- [ ] **Step 1:** Add new l10n keys to `app_en.arb` (and stub the same keys
  into the other nine ARBs with an English placeholder, matching the
  existing pattern where a string is added everywhere before translation
  lands separately): `gasCalculators_bestMix_mode`, `_modeRec`, `_modeOcTec`,
  `_modeCcrTec`, `_modeRecHint`, `_modeOcTecHint`, `_modeCcrTecHint`,
  `_ccrSource`, `_ccrSourceDiluent`, `_ccrSourceBailout`, `_densityAware`,
  `_eadLabel` (distinct from the existing `_endLabel`), `_heliumEndLimit`
  (existing caption, kept), `_heliumDensity`, `_heliumBoth`.
- [ ] **Step 2:** Write widget tests first (TDD at the widget layer): mode
  switch shows/hides the density card and the CCR source toggle; selecting
  `CcrGasSource.bailout` changes the displayed MOD (cross-check against a
  known working-vs-flush ppO2 difference fixture); density switch toggles
  the extra helium note; EAD row present only outside Rec.
- [ ] **Step 3:** Run, expect failure.
- [ ] **Step 4:** Build the five cards and the shell.
- [ ] **Step 5:** Run `flutter test test/features/gas_calculators/`; fix
  regressions.
- [ ] **Step 6:** `flutter gen-l10n`, `dart format .`, `flutter analyze`.
- [ ] **Step 7:** Commit: `feat(gas-calculators): best mix Rec/OC-Tec/CCR-Tec UI`
  with `Refs #3112`.

## Task 5: Full regression pass

- [ ] `flutter test test/features/gas_calculators/` (whole directory).
- [ ] `flutter analyze` (whole project).
- [ ] `dart format .` (no changes).
- [ ] Patch coverage check per the user's global CLAUDE.md sharded-coverage
  procedure before opening the PR.
- [ ] `/code-review` on the full diff.
- [ ] `/flutter-windows-hotrun` for manual verification; hot-restart (`R`)
  after each further change, full restart only after `pubspec.yaml`/native
  changes (none expected here).

## Out of scope (unchanged from the design doc)

- A CCR loop model for Best Mix.
- Changing the MOD calculator's own behaviour.
- A combined Rec-CCR mode.
- Moving the END-limit helium rounding to 1%.
