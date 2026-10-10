# Best Mix Rec / OC-Tec / CCR-Tec modes (issue #3112)

Date: 2026-10-08
Issue: [#3112](https://github.com/submersion-app/submersion/issues/3112)
Related: [issue #2342](https://github.com/submersion-app/submersion/issues/2342) (MOD calculator Rec/OC-Tec/CCR-Tec modes, merged as PR #2387)

## Summary

The Best Mix calculator (`lib/features/gas_calculators/domain/best_mix.dart`)
currently has one mode: given a target depth and a ppO2 limit, it suggests the
richest nitrox whose own MOD still covers the depth, adding helium only when
the diver's END limit forces it. This mirrors the MOD calculator before issue
#2342, which split that calculator into three modes (Rec, OC-Tec, CCR-Tec)
with mode-appropriate ppO2 limits, water type and density.

This issue carries the same split over to Best Mix:

- **Rec**: today's behaviour, unchanged.
- **OC-Tec**: Best Mix against the diver's working ppO2 limit (profile, with
  per-diver override), trimix, water type, EAD and END shown together.
- **CCR-Tec**: a second choice of which ppO2 limit the suggestion is built
  against:
  - **Diluent**: the diluent's own flush ppO2 (`ccrDiluentModPpO2`), the same
    limit the MOD calculator's CCR-Tec mode uses for the diluent MOD.
  - **Bailout**: the OC working ppO2 limit (`ppO2MaxWorking`), because a
    bailout cylinder is breathed open circuit.

Additionally, both Tec modes gain an optional density-aware helium
requirement: when switched on, the suggested mix adds enough helium to also
keep the gas density at or below the critical limit at the target depth, not
only to satisfy the END limit as today.

## Decisions taken

| Question | Decision |
| --- | --- |
| Modes | SegmentedButton Rec / OC-Tec / CCR-Tec, exactly the MOD calculator's three; no Rec-CCR |
| CCR ppO2 source | SegmentedButton Diluent / Bailout, CCR-Tec only |
| Density toggle | Tec modes only (Rec never shows it, same as the MOD calculator) |
| Density effect | Actively raises the suggested helium, not just an advisory flag |
| Density/narcosis combination | Independent checks, each rounds its own way, then take the richer (more helium) result; the UI names which check drove it |
| Helium rounding | END-driven helium stays rounded UP to 5% (unchanged); density-driven helium rounds UP to 1% only |
| Density formula | `computeGasDensity`/`gasDensityFromPartialPressures` (the MOD calculator's and the density calculator's formula) in both Tec modes, not the simpler `gasDensityGPerL` Best Mix uses today |
| Temperature & water type | Both freely selectable in Tec modes (0 C/20 C, salt/fresh), as in the standalone density calculator — not fixed like the MOD calculator's hardcoded 0 C |
| Ambient pressure model | Rec keeps the flat 1 bar/10 m model; Tec modes use `DiveEnvironment` for the chosen water type, the same split the MOD calculator made (accepted trade-off: same gas, slightly different numbers between Rec and Tec) |
| ppO2 profile overrides | Reuses `ModProfileLimits`/`ModLimitOverrides`/`resolveModLimits` from `mod_limit_overrides.dart` rather than a parallel copy |
| Persistence | Own `AppSettingsRepository` blob, same debounced-save pattern as `ModCalculatorNotifier`, not the current ephemeral `StateProvider`s |
| Target depth, EAD/END | Tec modes show both EAD and END together, not just one selected by the O2-narcotic setting |

## 1. Domain model

File: `lib/features/gas_calculators/domain/best_mix.dart`

```dart
enum BestMixMode { rec, ocTec, ccrTec }

enum CcrGasSource { diluent, bailout }
```

`BestMixInputs` gains:

```dart
final BestMixMode mode;
final CcrGasSource ccrSource;      // read only when mode == ccrTec
final WaterType waterType;          // Tec modes only; Rec ignores it
final bool densityAware;            // the optional switch, Tec modes only
final GasDensityTemperature temperature; // Tec modes only
```

The ppO2 limit the suggestion is computed against collapses to one rule:

```dart
double _limitPpO2(BestMixInputs inputs) => switch (inputs.mode) {
  BestMixMode.rec => inputs.ppO2Limit,
  BestMixMode.ocTec => inputs.ppO2Limit,       // resolved working ppO2
  BestMixMode.ccrTec => switch (inputs.ccrSource) {
    CcrGasSource.diluent => inputs.flushPpO2,
    CcrGasSource.bailout => inputs.ppO2Limit,  // resolved working ppO2
  },
};
```

CCR-Tec in Best Mix is deliberately **not** a loop model: it does not take a
setpoint or compute loop partial pressures the way the MOD calculator's
CCR-Tec does. "Diluent" and "Bailout" each just pick which ppO2 limit the
open-circuit-style suggestion is built against, per the user's own framing
("Diluent greift auf den ppO2 vom Diluent zu, Bailout auf den OC-Maximalwert").
This keeps Best Mix a single computation path for all three modes, with the
ppO2 limit and the ambient-pressure model as the only mode-dependent inputs.

### Density-driven helium

`_assess` already computes density through `gasDensityGPerL` (the simple
fixed-weight formula at a flat 1 bar/10 m). Tec modes switch this to
`computeGasDensity`/`gasDensityFromPartialPressures` at the chosen water type
and temperature, consistent with the decisions table.

A new function, analogous to the existing `GasMix.heForMnd`:

```dart
/// Helium percent needed to bring [o2]'s density at [depthMeters] down to
/// [gasDensityCriticalGPerL], at [temperature] and [waterType]. Returns 0
/// when the nitrox mix is already within the limit.
double heForDensityLimit(
  double depthMeters,
  double o2, {
  required GasDensityTemperature temperature,
  required WaterType waterType,
});
```

Density is affine in the helium fraction at fixed O2 and depth (He displaces
N2 only), so this is a closed-form solve, not a search:

```
density(fHe) = ambient/(R*T) * [fO2*Mo2 + (1-fO2)*Mn2 + fHe*(Mhe - Mn2)]
```

Solving `density(fHe) = gasDensityCriticalGPerL` for `fHe` gives the exact
helium fraction at which density sits exactly on the critical limit; negative
or past `100 - o2` clamps to 0 or `100 - o2`.

`computeBestMix` combines the two helium requirements:

```dart
final heForEnd = nitrox.exceedsEndLimit
    ? ceilToStep(GasMix.heForMnd(...), 5)
    : 0.0;
final heForDensity = inputs.densityAware
    ? ceilToStep(heForDensityLimit(inputs.depthMeters, o2, ...), 1)
    : 0.0;
final he = math.max(heForEnd, heForDensity);
```

`BestMixResult` gains a field recording which check (or both) drove the
helium, so the UI can say "Helium wegen Betäubungslimit" / "wegen Gasdichte" /
both, rather than just showing the number:

```dart
enum HeliumDriver { none, endLimit, density, both }
```

## 2. Profile limits and overrides

New dependency on the existing `lib/features/gas_calculators/domain/mod_limit_overrides.dart`:
`ModProfileLimits`, `ModLimitOverrides`, `resolveModLimits`. Best Mix reads
`workingPpO2` and `flushPpO2` from the same resolved limits the MOD calculator
uses; `decoPpO2` and `setpointBar` are present in the shared type but unused
here, same as the MOD calculator leaves `setpointBar` unused outside CCR-Tec.

No rename of the `Mod`-prefixed types: they already describe "the calculator
ppO2 limits", not specifically the MOD calculator, and a rename only
churns the MOD calculator's files for no behavioural change. This is called
out explicitly here since it is a deliberate choice, not an oversight.

Per-diver overrides are stored the same way: keyed by diver id in the
preferences blob, resolved against the active diver's profile on every read.

## 3. Persisted preferences

New file: `lib/features/gas_calculators/domain/best_mix_calculator_preferences.dart`,
mirroring `mod_calculator_preferences.dart`:

```dart
class BestMixModeInputs {
  final double depthMeters;
  final bool densityAware;
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

`ppO2Limit` itself is not stored per mode: Rec keeps its existing three
fixed chips (1.2/1.4/1.6); Tec modes take the resolved working/flush ppO2 from
the profile/override, like the MOD calculator.

Stored under a new `AppSettingsRepository` key,
`gas_best_mix_calculator_prefs`, through the identical debounced
`StateNotifier` pattern as `ModCalculatorNotifier`
(`mod_calculator_providers.dart` lines 30-214): `reload()` on creation and on
every settings tick, a 500 ms debounced `_save()`, a pending save flushed on
`dispose()`.

This replaces the current ephemeral `StateProvider`s in
`gas_calculators_providers.dart` (`bestMixDepthProvider`,
`bestMixPpO2Provider`, `bestMixEndLimitProvider`,
`bestMixO2NarcoticProvider`), which do not survive an app restart today. The
END limit and O2-narcotic setting remain read live from `AppSettings`
(`settings.endLimit`, `settings.o2Narcotic`), not duplicated into the new
preferences blob, same as the MOD calculator reads them.

## 4. Providers

New file: `lib/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart`,
structured like `mod_calculator_providers.dart`:

- `bestMixCalculatorNotifierProvider` (`StateNotifierProvider`)
- `bestMixCalculatorLimitsProvider` (resolved ppO2 limits, `ModResolvedLimits`)
- `bestMixCalculatorInputsProvider` (assembles `BestMixInputs`)
- `bestMixCalculatorResultProvider` (`computeBestMix`)

`gas_calculators_providers.dart`'s `resetGasCalculators` keeps resetting Best
Mix by calling the new notifier's `reset()`, the same re-export pattern
`gas_blender_providers.dart` already uses for the blender.

## 5. User interface

`best_mix_calculator.dart` is 520 lines today (CLAUDE.md's 800-line ceiling)
and would grow past it with three modes plus the CCR source toggle and the
density switch. It becomes a composing shell over a new
`presentation/widgets/best_mix/` directory, the same restructuring the
trimix blender optimisation did:

| Card | File | Contents |
| --- | --- | --- |
| 1 | `best_mix_input_card.dart` | Mode SegmentedButton, target depth slider, ppO2 chips (Rec) or resolved working/flush ppO2 display (Tec), CCR source toggle |
| 2 | `best_mix_density_card.dart` | Density-aware switch, temperature + water type SegmentedButtons; Tec modes only, card omitted in Rec |
| 3 | `best_mix_result_card.dart` | Recommended mix, ideal O2, MOD, margin, EAD + END (Tec) or END only (Rec, unchanged), density, helium-driver note |
| 4 | `best_mix_alternative_card.dart` | Helium-free alternative, shown when helium was added (existing `_buildAlternativeCard`, unchanged logic) |
| 5 | `best_mix_common_mixes_card.dart` | Standard mixes reference (existing `_buildMixRow`/nearest-standard block, unchanged) |

The CCR source toggle (Diluent/Bailout) sits in card 1, visible only when
`mode == ccrTec`, directly below the mode SegmentedButton — the same
placement the MOD calculator uses for its water-type/min-ppO2 row.

### Helium-driver note

Card 3 adds one line, shown only when helium was added, replacing the current
unconditional "helium added because of your END limit" caption:

- `HeliumDriver.endLimit`: today's existing caption, unchanged wording.
- `HeliumDriver.density`: "Helium added to keep density within limits at this
  depth."
- `HeliumDriver.both`: both sentences, END first (matches the existing
  caption's priority).

### EAD and END together (Tec modes)

Rec keeps today's single EAD row (`gasCalculators_bestMix_...`, label depends
on `o2Narcotic`). Tec modes show both:

```
EAD (N2 only):  xx m
END (N2 + O2):  xx m
```

independent of the `o2Narcotic` setting, which in Tec modes only selects
which of the two the END-limit check and the helium-for-narcosis calculation
use — the display shows both regardless, as confirmed with the user.

## 6. Localisation

New strings follow the existing `gasCalculators_bestMix_*` prefix, added to
`lib/l10n/arb/app_en.arb` and every translated locale file, matching how
issue #2342 extended `gasCalculators_mod_*`.

## 7. Testing

Test-driven, domain first, following the existing `best_mix_test.dart`
pattern (hand-computed or Python-verified vectors, "do not edit the
constant").

| File | Coverage |
| --- | --- |
| `test/features/gas_calculators/domain/best_mix_test.dart` | Existing Rec vectors must pass unmodified (regression gate); new groups for OC-Tec (working ppO2, trimix) and CCR-Tec (both Diluent and Bailout ppO2 sources) |
| (same file, new group) | `heForDensityLimit` closed-form against `computeGasDensity` swept over a helium range (the closed form must agree with the general formula to a tight tolerance); zero at an already-compliant mix |
| (same file, new group) | Combined helium: END-only, density-only, both, neither; 5% vs 1% rounding on each path independently |
| `test/features/gas_calculators/domain/best_mix_calculator_preferences_test.dart` | JSON round-trip; per-diver overrides; malformed fields falling back per field, matching `blender_preferences_test.dart`'s shape |
| `test/features/gas_calculators/best_mix_calculator_widget_test.dart` | Mode switch changes the visible cards; CCR source toggle changes the ppO2 limit used; density switch appears only in Tec modes; EAD+END both shown in Tec |
| `test/features/gas_calculators/gas_calculators_page_test.dart` | Existing navigation/reset tests updated for the new provider names |

Coverage target: the project's 80% patch-coverage minimum on all new/changed
domain files.

## 8. Out of scope

- A CCR loop model for Best Mix (setpoint, loop partial pressures). CCR-Tec
  here only switches which ppO2 limit is used, not how the gas is breathed.
- Changing the MOD calculator's CCR-Tec behaviour or its hardcoded 0 C
  density temperature.
- A combined Rec-CCR mode.
- Moving the END-limit helium rounding to 1% to match the density path; it
  stays at 5% as today, per the user's decision.

## 9. Risks

| Risk | Mitigation |
| --- | --- |
| Moving from `StateProvider` to a persisted, debounced notifier changes behaviour other tests rely on (e.g. instant provider updates in widget tests) | Existing widget tests are the regression gate; `pumpAndSettle` already used where debounced saves matter in the blender/MOD tests gives the pattern to follow |
| `heForDensityLimit`'s closed form has a sign error given He lowers density | Swept numeric cross-check against `computeGasDensity` in the test matrix, not just hand-picked points |
| Two independent rounding steps (5% vs 1%) combined by `max` could read as arbitrary in the UI | The helium-driver note states explicitly which check is binding |
| Reusing `Mod`-prefixed shared types across two calculators without renaming reads as an oversight to a later reviewer | Called out explicitly in section 2 as a deliberate choice |

## Open items

- No GitHub issue filed yet for this work. Needed before a PR, per this
  repo's PR-issue-link check.
