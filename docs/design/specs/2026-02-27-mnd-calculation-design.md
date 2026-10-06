# MND (Maximum Narcotic Depth) Calculation

Date: 2026-02-27

## Overview

Add Maximum Narcotic Depth (MND) calculation for tanks, matching Subsurface's approach. MND answers: "At what depth will this gas mix reach a given narcotic END limit?" Displayed in both the tank editing UI (bidirectional) and as a new Gas Calculators tab.

## Decisions

- **Approach:** Add `mnd()` method to `GasMix` class (Approach A -- consistent with existing `mod()` and `end()`)
- **O2 narcotic:** User-configurable setting (default: true / O2 is narcotic)
- **END limit:** User-configurable setting (default: 30m)
- **Tank UI:** Bidirectional -- user can set MND to auto-calculate He%, or set gas mix to see MND
- **Gas calculator:** New MND/END tab (5th tab) with both MND result and END-at-depth

## 1. Core Calculation (`GasMix`)

File: `lib/features/dive_log/domain/entities/dive.dart`

### New method: `mnd()`

```dart
double mnd({double endLimit = 30.0, bool o2Narcotic = true})
```text
**O2 narcotic mode** (narcotic gas = everything except He):

```

narcoticFraction = (100 - he) / 100
targetPressure = (endLimit / 10) + 1
maxPressure = targetPressure / narcoticFraction
MND = (maxPressure - 1) * 10

```text
**N2-only narcotic mode:**

```

n2Fraction = n2 / 100
targetPressure = (endLimit / 10) + 1
maxPressure = targetPressure *0.79 / n2Fraction
MND = (maxPressure - 1)* 10

```text
If N2 is 0, MND is effectively infinite (return a large sentinel or double.infinity).

This matches Subsurface's `gas_mnd()` from `core/dive.cpp`.

### Updated method: `end()`

Add `o2Narcotic` parameter (default `true` for backward compatibility):

```dart
double end(double depth, {bool o2Narcotic = true})
```text
- O2 narcotic: `narcoticFraction = (100 - he) / 100`, compare against ambient
- N2-only: `narcoticFraction = n2 / 100`, compare against air baseline (0.79)

### New static helper: `heForMnd()`

```dart
static double heForMnd(double targetMnd, double o2, {bool o2Narcotic = true})
```text
Inverse calculation: given a target MND and O2%, calculate the He% needed. Used by the bidirectional tank editor.

Edge cases:

- Calculated He < 0: clamp to 0
- Calculated He > (100 - O2): unreachable, return (100 - O2) and signal warning

## 2. New Settings

### Database (`DiverSettings` table in `database.dart`)

```dart
BoolColumn get o2Narcotic => boolean().withDefault(const Constant(true))();
RealColumn get endLimit => real().withDefault(const Constant(30.0))();
```

### AppSettings class (`settings_providers.dart`)

New fields: `o2Narcotic` (bool, default true), `endLimit` (double, default 30.0).

New setter methods: `setO2Narcotic()`, `setEndLimit()`.

### Repository (`diver_settings_repository.dart`)

Map new fields in create, update, and read operations.

### Settings UI (`settings_page.dart` -- Decompression section)

New "Narcosis" card with:

- `SwitchListTile`: "O2 is narcotic" toggle with explanatory subtitle
- `ListTile`: "END Limit" showing current value in diver's depth unit, tap to edit via slider dialog (range: 20-50m / 66-165ft)

## 3. Tank Editing UI

File: `lib/features/dive_log/presentation/widgets/tank_editor.dart`

### MND display

Extend `_buildModInfo` row to show MND alongside MOD:

- Format: "MOD: 33m | MND: 51m"
- Only shown when gas is not air (same condition as MOD)
- If MND is infinite (no N2, no narcotic gas), display "--"

### Bidirectional MND input

- Add MND text field, visible when trimix (he > 0) or when user wants to plan trimix
- Editing O2% or He% -> MND auto-recalculates
- Editing MND field -> He% auto-recalculates via `GasMix.heForMnd()`, O2% stays fixed
- If target MND unreachable with current O2%, show warning
- Clearing MND field reverts to display-only mode

## 4. Gas Calculators -- MND/END Tab

New 5th tab in `gas_calculators_page.dart`.

### Providers (`mnd_calculator_providers.dart`)

- `mndO2Provider` -- O2% state
- `mndHeProvider` -- He% state
- `mndEndLimitProvider` -- END limit (initialized from settings)
- `mndO2NarcoticProvider` -- O2 narcotic toggle (initialized from settings)
- `mndResultProvider` -- computed MND
- `mndDepthProvider` -- depth input for END-at-depth
- `mndEndAtDepthProvider` -- computed END at given depth

### Widget (`mnd_calculator.dart`)

**Input Card:** O2% slider, He% slider, END limit input, O2 narcotic toggle

**Results Card:**

- MND result with formatted depth (metric + imperial)
- END at depth with depth input field

**Info Card:** Brief explanation of MND/END and the O2 narcotic toggle

## 5. Existing END Consistency Updates

### `GasMix.end()` (dive.dart)

Update to accept `o2Narcotic` parameter. Default `true` preserves current behavior.

### `O2ToxicityCalculator.calculateEnd()` (o2_toxicity_calculator.dart)

Currently uses N2-only. Update to accept `o2Narcotic` flag, or deprecate in favor of `GasMix.end()`.

### Deco Calculator providers (deco_calculator_providers.dart)

`calcENDProvider` reads the `o2Narcotic` setting and passes it to `GasMix.end()`.

### Gas Warnings (gas_warnings_display.dart)

No changes to thresholds (>30m warning, >40m danger). The END value they compare against will now correctly reflect the `o2Narcotic` setting.

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart` | Riverpod providers for MND/END calculator |
| `lib/features/gas_calculators/presentation/widgets/mnd_calculator.dart` | MND/END calculator tab widget |

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/dive_log/domain/entities/dive.dart` | Add `mnd()`, `heForMnd()`, update `end()` on GasMix |
| `lib/core/database/database.dart` | Add `o2Narcotic`, `endLimit` columns |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add fields, setters to AppSettings/SettingsNotifier |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Map new fields |
| `lib/features/settings/presentation/pages/settings_page.dart` | Add Narcosis card to Decompression section |
| `lib/features/dive_log/presentation/widgets/tank_editor.dart` | Add MND display + bidirectional input |
| `lib/features/gas_calculators/presentation/pages/gas_calculators_page.dart` | Add 5th MND/END tab |
| `lib/core/deco/o2_toxicity_calculator.dart` | Update or deprecate `calculateEnd()` |
| `lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart` | Pass `o2Narcotic` to END calc |
