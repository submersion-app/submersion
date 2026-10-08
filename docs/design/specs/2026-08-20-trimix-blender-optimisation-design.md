# Trimix Blender Optimisation (issue #1100)

Date: 2026-08-20
Issue: [#1100](https://github.com/submersion-app/submersion/issues/1100)
Base feature: [#936](https://github.com/submersion-app/submersion/issues/936)
Branch: `worktree-issue-1100-trimix-blender`

## Summary

The partial-pressure gas blender shipped in #936 computes correct fill
procedures but presents them the way a logbook presents a gas, not the way a
fill station needs them. Issue #1100 asks for six changes: readable precision,
fill amounts in bar rather than litres, reusable target-mix templates, a fill
temperature, a selectable equation of state, and a billing section.

Two of these are physics, not presentation. The current solver conserves a
surface-equivalent volume that has no temperature term, so a temperature input
has nothing to attach to. This design replaces that conserved quantity with
molar density, which is temperature-aware and still linear in mixing, and puts
a three-model equation of state behind it.

The governing constraint throughout: with both temperatures left at their 20 °C
default, output must be identical to what the blender produces today.

## Decisions taken

| Question | Decision |
| --- | --- |
| Temperature semantics | Two fields: fill temperature and settled temperature |
| Gas model | Blender-local three-way picker, global `GasModel` setting untouched |
| Persistence | Single JSON blob in the `settings` KV table, no schema version |
| Billing basis | Always ideal `V x dP`, independent of the selected gas model |

## 1. Equation of state

New file: `lib/features/gas_calculators/domain/blending/equation_of_state.dart`

```dart
enum BlendGasModel { ideal, vanDerWaals, zFactor }

/// Moles per litre of cylinder held at [bar] of [mix] at [kelvin].
double molarDensity(BlendGasModel model, double bar, GasMix mix, double kelvin);

/// The pressure at which [mix] holds [density] mol/L at [kelvin].
double pressureAt(BlendGasModel model, double density, GasMix mix, double kelvin);
```

`R = 0.083144626` L bar / (mol K).

| Model | Forward (p to rho) | Inverse (rho to p) |
| --- | --- | --- |
| `ideal` | `rho = p / (R T)` | `p = rho R T` |
| `vanDerWaals` | bisection on `rho` in `(0, 1/b)` | `p = rho R T / (1 - b rho) - a rho^2` |
| `zFactor` | `rho = p / (Z(p, mix) R T)` | fixed-point iteration |

`Z(p, mix)` is the existing virial function already in `gas_blender.dart`,
moved into this file unchanged.

Van der Waals constants, in L^2 bar / mol^2 and L / mol:

| Component | a | b |
| --- | --- | --- |
| O2 | 1.382 | 0.03186 |
| N2 | 1.370 | 0.0387 |
| He | 0.0346 | 0.0238 |

Mixing rules are the standard one-fluid van der Waals forms:
`a_mix = (sum x_i sqrt(a_i))^2` and `b_mix = sum x_i b_i`, with `x_i` the mole
fractions taken from the `GasMix` percentages.

### Documented approximation

The virial coefficients are a fit at approximately 20 °C. The `zFactor` model
therefore treats Z as a function of pressure and composition only, and carries
temperature solely through the ideal `R T` factor. This is stated in a doc
comment on the function. `vanDerWaals` is the model with genuine temperature
dependence in its own constants, which is the reason it earns a place in the
picker rather than being decoration.

### Numerical notes

- Van der Waals bisection brackets `rho` on `(0, 0.95 / b_mix)` and runs a
  fixed 80 iterations, matching the convergence style already used by
  `pressureAfterConsuming` in `core/utils/gas_compressibility.dart`.
- The `zFactor` inverse keeps the existing fixed-point loop and its 0.0001
  tolerance, since it converges in a handful of passes across the cylinder
  pressure range.
- All three forward functions return 0 for a non-positive pressure.

## 2. Blender solver changes

File: `lib/features/gas_calculators/domain/gas_blender.dart`

The linear algebra is unchanged. `_solveTops` keeps its three-gas determinant,
its two-gas nitrox branch, and the `_largestFeasibleStartVolume` bisection that
produces drain guidance. Only the conserved quantity changes, from
`normalVolume(p, mix)` to `molarDensity(model, p, mix, kelvin)`.

`GasBlenderInputs` gains three fields:

```dart
final BlendGasModel model;      // default BlendGasModel.zFactor
final double fillTempC;         // default 20
final double settledTempC;      // default 20
```

Temperature enters only at the conversion boundaries:

| Quantity | Temperature it is quoted at | Rationale |
| --- | --- | --- |
| Start pressure | fill | It is the gauge in front of the blender |
| Target pressure | settled | It is the reading the diver can later verify |
| Every step pressure | fill | It is the gauge you stop the fill at |
| Closing settled line | settled | What the cylinder reads once it equalises |

`BlendStep` gains `addedBar`, the difference between this step's pressure and
the previous step's, both at the fill temperature. `BlendResult` gains
`settledPressureBar`, which is the requested target verbatim.

### Behaviour that changes

The current code overrides the final step's pressure with the requested target
verbatim, on the grounds that the requested pressure is what the blender fills
to. With two temperatures the final fill pressure genuinely differs from the
settled target, so that override is removed. The final step's pressure is
computed from the exact target molar density at the fill temperature, and the
requested pressure is reported on the settled line instead.

The `targetNotReached` guard is retained and still compares the achieved mix
against the requested one within 0.01 percentage points.

### Volume tolerance

`_volumeTolerance` is currently 0.01 surface litres per litre of cylinder. In
molar terms the equivalent at 20 °C is approximately `0.01 / (R * 293.15)`,
about 4.1e-4 mol/L. The constant is restated in mol/L with a comment recording
that it is the same physical threshold, so the "gas the blend does not need is
left out" behaviour is preserved exactly at default temperatures.

## 3. Persisted preferences

New file: `lib/features/gas_calculators/domain/blending/blender_preferences.dart`

```dart
class MixTemplate {
  final double o2;
  final double he;
}

class BlenderPreferences {
  final List<MixTemplate> templates;
  final List<double?> gasPrices;      // one per fill-gas slot, per 100 volume units
  final String? currencyCode;         // null inherits the diver's defaultCurrency
  final double fillTempC;
  final double settledTempC;
  final double cylinderWaterLiters;
  final BlendGasModel model;
}
```

Stored as one JSON object under the `settings` KV key `gas_blender_prefs`, via
a `getBlenderPreferences` / `setBlenderPreferences` pair added to
`AppSettingsRepository`. That pair follows the existing
`getNavPrimaryIdsRaw` / `setNavPrimaryIds` shape exactly, including
`markRecordPending(entityType: 'settings', recordId: 'gas_blender_prefs', ...)`
and `SyncEventBus.notifyLocalChange()`, so the value syncs across devices with
no schema change and no sync-serializer edit.

Reads are non-throwing and degrade to defaults, matching the contract the rest
of `AppSettingsRepository` keeps. Writes rethrow so a failed save is visible.

### First-run seeding

When the key is absent, `templates` seeds to the five mixes named in #1100:
7/75, 10/70, 12/60, 15/55, 18/35. Seeding is keyed on absence of the whole
blob, not on an empty list, so a user who deletes every template keeps an empty
list across restarts.

Other defaults: `gasPrices` all null, `currencyCode` null, both temperatures
20 °C, `cylinderWaterLiters` from the diver's `defaultTankVolume` setting,
`model` `zFactor`.

### Malformed input

Any field that fails to parse falls back to its default rather than discarding
the whole blob. A template with `o2 + he > 100` is dropped on read.

## 4. Provider restructuring

New file: `lib/features/gas_calculators/presentation/providers/gas_blender_providers.dart`

The blender providers move out of `gas_calculators_providers.dart`, which is
already about 250 lines carrying five calculators. `resetGasBlender` is
re-exported so `resetGasCalculators` is unchanged.

Providers added: `blenderFillTempProvider`, `blenderSettledTempProvider`,
`blenderGasModelProvider`, `blenderGasPriceProviders` (three),
`blenderCurrencyProvider`, `blenderCylinderVolumeProvider`,
`blenderTemplatesProvider`, and a `blenderPreferencesProvider` that hydrates the
rest once from the repository.

Provider removed: `blenderTankProvider`, along with the `TankSpec` FilterChip
row. The reporter is correct that partial-pressure mixing is driven by pressure
alone and needs no cylinder. The cylinder reappears in the billing section as a
plain number.

Writes to the persisted providers are debounced into a single
`setBlenderPreferences` call so typing a price does not produce one database
write per keystroke.

## 5. Billing

New file: `lib/features/gas_calculators/domain/blending/blend_billing.dart`

```dart
class GasCostLine {
  final GasMix gas;
  final double addedBar;          // delta at the fill temperature
  final double freeGasLiters;     // waterLiters * addedBar, ideal by design
  final double? unitPricePer100;  // null when the user has not priced this gas
  final double? cost;
}

class BillingResult {
  final List<GasCostLine> lines;
  final double? total;            // null when any priced line is missing a price
}

BillingResult computeBlendCost({
  required BlendResult blend,
  required double waterLiters,
  required List<double?> pricesPer100,
});
```

The volume is deliberately the ideal `V x dP` figure regardless of which gas
model the blender is running. A fill station meters by gauge pressure drop and
charges for the pressure it delivered, so the ideal figure is the commercial
truth even where it is not the physical one. Every line prints its delta in bar
so the arithmetic can be checked by hand against the shop's invoice, and a note
under the total states the basis.

Both worked examples in the issues are test vectors that must reproduce
exactly:

- #936, 3 L cylinder: O2 7.3 bar at 2.00 gives 0.438; He 19.8 bar at 10.00
  gives 5.94; air 48.1 bar at 0.10 gives 0.1443; total 6.52.
- #1100, 3 L cylinder: helium 50 bar at 7.99 gives 11.99.

### Units

All storage is litres and bar. Display converts through `UnitFormatter`:

| Element | Metric | Imperial |
| --- | --- | --- |
| Cylinder field | water capacity in L | water capacity in cu ft |
| Volume column | L | cu ft, `L_water * dBar / 28.3168` |
| Price basis | per 100 L | per 100 cu ft |

An imperial diver entering water capacity in cubic feet (an AL80 is 0.39) is
not a figure anyone quotes, so the field ships with a preset button that fills
it from `imperialTankChoices()` / `metricTankChoices()`. This keeps the
CLAUDE.md unit rule intact without forcing an unnatural entry.

### Currency

Reuses `kCommonCurrencyCodes`, `currencyCodesWith`, `currencySymbol` and
`formatMoney` from `core/utils/currency.dart`, defaulting to the diver's
`defaultCurrency`. No second currency concept is introduced.

## 6. User interface

`gas_blender_calculator.dart` is 502 lines today and would land near 900 with
this issue, past the 800-line ceiling in CLAUDE.md. It becomes a composing
shell over a new `presentation/widgets/blender/` directory.

| Card | File | Contents |
| --- | --- | --- |
| 1 | `blender_cylinder_card.dart` | Start fill, target fill, templates menu |
| 2 | `blender_fill_gases_card.dart` | Three O2/He rows |
| 3 | `blender_conditions_card.dart` | Fill temp, settled temp, gas model |
| 4 | `blender_procedure_card.dart` | Result steps with delta bar |
| 5 | `blender_about_card.dart` | Safety note |
| 6 | `blender_billing_card.dart` | Cylinder, prices, cost lines, total |

Plus `blender/mix_template_menu.dart` and `blender/mix_template_dialog.dart`.

Billing is card 6, after the safety note, as #1100 requests.

### Precision fixes

Four distinct defects sit behind "not all values are displayed clearly or are
obscured", each with its own fix:

1. **Rounded gas labels.** `GasMix.name` renders through `roundedO2` and
   `roundedHe`, so the reporter's `Tx 8.3/73.4` prints as `Tx 8/73`. A
   blender-local `formatPreciseMix` renders one decimal with a trailing `.0`
   trimmed. `GasMix.name` is left alone for the rest of the app, where rounding
   a logbook label is correct.
2. **Lossy seeding.** `initState` seeds pressure with `toStringAsFixed(0)`, so
   207.6 bar becomes `208` whenever the controllers re-seed, which now happens
   on every pressure-unit change. Replaced with `formatDecimalForInput`, which
   is also locale-correct and pairs with the `parseUserDecimal` already used for
   reads.
3. **Rounded output.** Step pressures render through
   `formatPressure(decimals: 1)`.
4. **Cramped fields.** The unit moves from `suffixText` into the field label
   (`Pressure (bar)`, `O2 (%)`, `He (%)`), returning roughly 30dp per field, and
   a `LayoutBuilder` breakpoint drops the pressure field onto its own line below
   about 420dp of available width rather than squeezing three fields into one
   row on a phone.

### Procedure output

```
1. Start        80.0 bar    Tx 8.3/73.4
2. Add O2     + 7.8 bar  ->  87.8 bar   Tx 16.6/67.0
3. Add He    + 96.7 bar  -> 184.5 bar   Tx  8.5/49.0
4. Add air   + 35.5 bar  -> 220.0 bar   Tx 18.0/41.0

Settles to 220.0 bar at 20 C
```

The separate "amounts in litres" line is deleted. Its information now appears
as the delta column here and as litres in the billing table.

### Temperature control

A dropdown rather than a free text field, since #1100 asks for fixed
increments. The ladder is defined in the display unit so both audiences get
round numbers, and converted to Celsius for storage:

- Celsius: 0, 5, 10, 15, 20, 25, 30, 35
- Fahrenheit: 30, 40, 50, 60, 70, 80, 90, 100

Both default to 20 °C, which is what keeps today's output unchanged out of the
box.

### Templates

A menu button beside the target fill section lists saved mixes as `10/70`,
selecting one writing both O2 and He into the target fields. The menu ends with
"Save current mix" and "Manage templates", the latter opening a dialog with a
reorderable list, a delete action, and an add row taking O2 and He.

Templates carry a mix only, not a pressure, matching how the reporter describes
them.

### Localisation

Every new string goes into `lib/l10n/arb/app_en.arb` and all translated locale
files, following the existing `gasCalculators_blender_*` key prefix.

## 7. Testing

Test-driven, domain first.

| File | Coverage |
| --- | --- |
| `test/features/gas_calculators/domain/equation_of_state_test.dart` | Ideal against the closed form; Van der Waals against published molar volumes; `zFactor` reproducing the current `normalVolume` at 20 °C; forward and inverse round-trip for all three models across 1 to 300 bar |
| `test/features/gas_calculators/domain/gas_blender_test.dart` | The existing 394 lines must pass unmodified with default temperatures. This is the regression gate on the molar-density rewrite |
| (same file, new group) | A cylinder chilled to 5 °C stops at a lower gauge reading and settles on target; a 35 °C fill stops higher; drain guidance still returned when the start fill is too rich |
| `test/features/gas_calculators/domain/blend_billing_test.dart` | Both issue worked examples to the cent; an imperial case; a null price yielding a null total rather than a wrong one |
| `test/features/gas_calculators/domain/blender_preferences_test.dart` | JSON round-trip; first-run seeding; an emptied template list persisting; malformed fields falling back per field |
| `test/features/gas_calculators/gas_blender_calculator_widget_test.dart` | Decimals surviving a pressure-unit change (the 207.6 defect); template menu applying a mix; billing total rendering; narrow-width layout not overflowing |

Coverage target is the project's 80% minimum on all new domain files.

## 8. Out of scope

- A bank-cylinder model answering "does my helium bank have enough pressure".
- A fill log or history of past blends.
- A dedicated Nitrox-32 top-off control. Fill gas 3 is already user-editable,
  so setting it to 32/0 tops off with EAN32 today. This is noted in the About
  card rather than given a control.
- Any change to the app-wide `GasModel` setting or its consumers in statistics,
  the planner, SAC, or rock bottom.

## 9. Risks

| Risk | Mitigation |
| --- | --- |
| The molar-density rewrite shifts existing results | The unmodified existing test file is the gate; any change to it is a defect, not a test update |
| Van der Waals mixing rules disagree with arcusblender.org | Test against published molar volumes first; if the reporter's cross-check still differs, the discrepancy is in the constants, not the structure, and is a one-line fix |
| The KV blob grows unbounded through templates | Templates are capped at 50 entries, enforced on write |
| Billing on ideal volume reads as a bug to a physics-minded user | The basis note under the total states it explicitly, and every line shows its delta bar |
