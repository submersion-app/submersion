# Gas Calculators, Weather, and CNS Unit Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the unit-conversion and localization defects in the four gas
calculators, the weather display, and the CNS/O2 card, so every value respects
the diver's unit settings and locale and every calculation is arithmetically
correct.

**Architecture:** The root cause is uniform -- values cross the presentation
boundary and a conversion mandated only by a doc comment is skipped. The fix is
structural: a `UnitAxis` type that declares slider ranges once in canonical
units and owns conversion, and a `TankSpec` type that separates water capacity
from free-gas capacity. Calculator math moves into a pure, unit-tested domain
layer; providers become thin wrappers.

**Tech Stack:** Flutter 3.x, Riverpod (via `core/providers/provider.dart`
barrel), Drift ORM, `flutter gen-l10n` with ARB files.

**Spec:** `docs/superpowers/specs/2026-07-26-gas-calculators-weather-cns-units-design.md`

## Global Constraints

- Store metric internally, convert only for display. Never persist a
  display-unit value.
- All Dart must pass `dart format .` with no changes. Run it before every commit.
- No emojis in code, comments, or documentation.
- Anything displaying units must respect the active diver's unit settings.
- Riverpod imports come from the `package:submersion/core/providers/provider.dart`
  barrel, never `flutter_riverpod` directly.
- l10n: every new key goes into `lib/l10n/arb/app_en.arb` **and all 10 non-en
  locales** (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- ppO2 is always displayed in **bar**, never converted to psi.
- Schema version: **v137** is the next free value (`database.dart:2849` has
  `currentSchemaVersion = 136`). Re-grep current origin/main before merge.
- Migration tests use `greaterThanOrEqualTo(N)` + `contains(N)`, never an exact
  equality tripwire.
- Never use bare `git stash` / `git stash pop` -- the stash stack is shared
  across worktrees.
- Run `dart format .` and `flutter analyze` (never piped through `tail`) before
  each commit.

---

## File Structure

**Create:**
- `lib/core/utils/unit_axis.dart` -- `UnitAxis` value type + the five axis presets
- `lib/shared/widgets/forms/unit_slider.dart` -- `UnitSlider` widget
- `lib/features/gas_calculators/domain/tank_spec.dart` -- `TankSpec`
- `lib/features/gas_calculators/domain/rock_bottom.dart` -- pure rock-bottom math
- `lib/features/gas_calculators/domain/gas_consumption.dart` -- pure consumption math
- `lib/features/gas_calculators/domain/best_mix.dart` -- pure best-mix math
- `lib/features/weather/presentation/widgets/weather_description_builder.dart`

**Modify:**
- `lib/core/utils/unit_formatter.dart` -- add barometric mbar/inHg
- `lib/core/database/database.dart` -- `dives.weatherCode`, v137 migration
- `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart`
- `lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/best_mix_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/mod_calculator.dart`
- `lib/features/weather/domain/entities/weather_data.dart`
- `lib/features/weather/data/services/weather_mapper.dart`
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`
- `lib/l10n/arb/app_*.arb` (11 files)

---

### Task 1: UnitAxis

Declares a slider range once in canonical units and owns conversion, symbol,
decimals, and display-grid snapping. This is what makes the whole class of bug
unrepresentable.

**Files:**
- Create: `lib/core/utils/unit_axis.dart`
- Test: `test/core/utils/unit_axis_test.dart`

**Interfaces:**
- Consumes: `AppSettings` from
  `package:submersion/features/settings/presentation/providers/settings_providers.dart`,
  `UnitFormatter` from `package:submersion/core/utils/unit_formatter.dart`.
- Produces:
  - `class UnitAxis` with fields `min`, `max`, `step`, `decimals`, `symbol`
    (all display-space) and methods `double toDisplay(double canonical)`,
    `double toCanonical(double display)`, `int get divisions`,
    `String format(double display)`, `double clampCanonical(double canonical)`.
  - Factories: `UnitAxis.depth(UnitFormatter)`, `UnitAxis.ascentRate(UnitFormatter)`,
    `UnitAxis.stressedSac(UnitFormatter)`, `UnitAxis.normalSac(UnitFormatter)`,
    `UnitAxis.diveTime()`.

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/unit_axis_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

UnitFormatter _metric() => const UnitFormatter(AppSettings());

UnitFormatter _imperial() => const UnitFormatter(
  AppSettings(
    depthUnit: DepthUnit.feet,
    volumeUnit: VolumeUnit.cubicFeet,
    pressureUnit: PressureUnit.psi,
  ),
);

void main() {
  group('UnitAxis.stressedSac', () {
    test('metric exposes the canonical 15-40 L/min range', () {
      final axis = UnitAxis.stressedSac(_metric());
      expect(axis.min, 15);
      expect(axis.max, 40);
      expect(axis.decimals, 0);
      expect(axis.symbol, 'L/min');
    });

    test('imperial snaps to a selectable cuft/min range', () {
      final axis = UnitAxis.stressedSac(_imperial());
      // 15 L/min = 0.53 cuft/min, 40 L/min = 1.41 cuft/min.
      // The old slider offered 15-35 CUFT/min, which is 425-991 L/min.
      expect(axis.min, closeTo(0.50, 1e-9));
      expect(axis.max, closeTo(1.40, 1e-9));
      expect(axis.step, closeTo(0.05, 1e-9));
      expect(axis.decimals, 2);
      expect(axis.symbol, 'cuft/min');
    });

    test('imperial max is nowhere near the old off-scale minimum', () {
      final axis = UnitAxis.stressedSac(_imperial());
      expect(axis.max, lessThan(15.0));
    });

    test('roundtrips canonical -> display -> canonical', () {
      final axis = UnitAxis.stressedSac(_imperial());
      final display = axis.toDisplay(28.3);
      expect(axis.toCanonical(display), closeTo(28.3, 1e-6));
    });

    test('formats imperial with two decimals, not zero', () {
      final axis = UnitAxis.stressedSac(_imperial());
      expect(axis.format(0.75), '0.75');
      expect(UnitAxis.stressedSac(_metric()).format(20), '20');
    });
  });

  group('UnitAxis.ascentRate', () {
    test('metric is 3-18 m/min', () {
      final axis = UnitAxis.ascentRate(_metric());
      expect(axis.min, 3);
      expect(axis.max, 18);
      expect(axis.symbol, 'm/min');
    });

    test('imperial snaps to 10-60 ft/min on a 5 ft grid', () {
      final axis = UnitAxis.ascentRate(_imperial());
      // The old min of 6 m/min converted to 19.7 ft/min, which is what the
      // user saw as a "20 ft/min minimum".
      expect(axis.min, 10);
      expect(axis.max, 60);
      expect(axis.step, 5);
      expect(axis.symbol, 'ft/min');
    });

    test('divisions match the snapped grid', () {
      expect(UnitAxis.ascentRate(_imperial()).divisions, 10);
      expect(UnitAxis.ascentRate(_metric()).divisions, 15);
    });
  });

  group('UnitAxis.depth', () {
    test('imperial snaps to 30-165 ft', () {
      final axis = UnitAxis.depth(_imperial());
      expect(axis.min, 30);
      expect(axis.max, 165);
      expect(axis.step, 5);
    });
  });

  group('clampCanonical', () {
    test('keeps a canonical value inside the display-snapped range', () {
      final axis = UnitAxis.ascentRate(_imperial());
      // 100 m/min is far above the 60 ft/min ceiling.
      final clamped = axis.clampCanonical(100);
      expect(axis.toDisplay(clamped), closeTo(60, 1e-6));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/unit_axis_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'unit_axis'` /
"Target of URI doesn't exist: unit_axis.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/core/utils/unit_axis.dart`:

```dart
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// A slider range declared once in canonical units.
///
/// Canonical units are the app's storage units: meters for depth and ascent
/// rate, liters per minute for SAC, minutes for time. [min], [max], and [step]
/// are in DISPLAY space, derived from the canonical range and snapped to a
/// grid that reads naturally in the diver's units.
///
/// Every value handed to a widget is display-space; every value handed back
/// through [toCanonical] is canonical. Bounds cannot be expressed in display
/// units at the call site, which is what previously allowed a slider labelled
/// "cuft/min" to carry a 15-35 L/min range.
class UnitAxis {
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String symbol;

  final double Function(double canonical) _toDisplay;
  final double Function(double display) _toCanonical;

  const UnitAxis({
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.symbol,
    required double Function(double) toDisplayFn,
    required double Function(double) toCanonicalFn,
  }) : _toDisplay = toDisplayFn,
       _toCanonical = toCanonicalFn;

  double toDisplay(double canonical) => _toDisplay(canonical);

  double toCanonical(double display) => _toCanonical(display);

  /// Slider divisions implied by the snapped grid.
  int get divisions => ((max - min) / step).round();

  /// Format a DISPLAY-space value at this axis's precision.
  String format(double display) => display.toStringAsFixed(decimals);

  /// Clamp a canonical value so it cannot fall outside the display range.
  double clampCanonical(double canonical) {
    final display = toDisplay(canonical).clamp(min, max);
    return toCanonical(display);
  }

  /// Round [value] down to the nearest multiple of [grid].
  static double _floorTo(double value, double grid) =>
      (value / grid).floor() * grid;

  /// Round [value] up to the nearest multiple of [grid].
  static double _ceilTo(double value, double grid) =>
      (value / grid).ceil() * grid;

  /// Maximum depth, canonical 10-50 m.
  factory UnitAxis.depth(UnitFormatter units) {
    final metric = units.settings.depthUnit == DepthUnit.meters;
    return UnitAxis(
      min: metric ? 10 : _ceilTo(units.convertDepth(10), 5),
      max: metric ? 50 : _floorTo(units.convertDepth(50), 5),
      step: metric ? 1 : 5,
      decimals: 0,
      symbol: units.depthSymbol,
      toDisplayFn: units.convertDepth,
      toCanonicalFn: units.depthToMeters,
    );
  }

  /// Ascent rate, canonical 3-18 m/min.
  factory UnitAxis.ascentRate(UnitFormatter units) {
    final metric = units.settings.depthUnit == DepthUnit.meters;
    return UnitAxis(
      min: metric ? 3 : _ceilTo(units.convertDepth(3), 5),
      max: metric ? 18 : _floorTo(units.convertDepth(18), 5),
      step: metric ? 1 : 5,
      decimals: 0,
      symbol: '${units.depthSymbol}/min',
      toDisplayFn: units.convertDepth,
      toCanonicalFn: units.depthToMeters,
    );
  }

  /// Stressed SAC for emergency planning, canonical 15-40 L/min.
  factory UnitAxis.stressedSac(UnitFormatter units) =>
      _sac(units, 15, 40);

  /// Working SAC for consumption planning, canonical 8-30 L/min.
  factory UnitAxis.normalSac(UnitFormatter units) => _sac(units, 8, 30);

  static UnitAxis _sac(UnitFormatter units, double minL, double maxL) {
    final metric = units.settings.volumeUnit == VolumeUnit.liters;
    return UnitAxis(
      min: metric ? minL : _ceilTo(units.convertVolume(minL), 0.05),
      max: metric ? maxL : _floorTo(units.convertVolume(maxL), 0.05),
      step: metric ? 1 : 0.05,
      decimals: metric ? 0 : 2,
      symbol: '${units.volumeSymbol}/min',
      toDisplayFn: units.convertVolume,
      toCanonicalFn: units.volumeToLiters,
    );
  }

  /// Dive time in minutes -- identical in both unit systems.
  factory UnitAxis.diveTime() => UnitAxis(
    min: 5,
    max: 90,
    step: 1,
    decimals: 0,
    symbol: 'min',
    toDisplayFn: (v) => v,
    toCanonicalFn: (v) => v,
  );
}
```

Note: `_floorTo`/`_ceilTo` on a 0.05 grid can leave float dust (e.g.
`1.4000000000000001`). The tests use `closeTo`, so this is acceptable; do not
add rounding gymnastics to chase exactness.

- [ ] **Step 4: Expose `settings` on UnitFormatter if needed**

`UnitFormatter.settings` is already a public final field
(`unit_formatter.dart:11`). No change required. Verify with:

Run: `grep -n "final AppSettings settings" lib/core/utils/unit_formatter.dart`
Expected: one match at line 11.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/utils/unit_axis_test.dart`
Expected: PASS, all tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/utils/unit_axis.dart test/core/utils/unit_axis_test.dart
git commit -m "feat(units): add UnitAxis to declare slider ranges in canonical units"
```

---

### Task 2: UnitSlider widget

**Files:**
- Create: `lib/shared/widgets/forms/unit_slider.dart`
- Test: `test/shared/widgets/forms/unit_slider_test.dart`

**Interfaces:**
- Consumes: `UnitAxis` from Task 1.
- Produces: `UnitSlider` — a `StatelessWidget` with named parameters
  `{Key? key, required IconData icon, required String label,
  required double value /* canonical */, required UnitAxis axis,
  required ValueChanged<double> onChanged /* emits canonical */}`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/forms/unit_slider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

void main() {
  Widget host(UnitAxis axis, double value, ValueChanged<double> onChanged) {
    return MaterialApp(
      home: Scaffold(
        body: UnitSlider(
          icon: Icons.air,
          label: 'Your SAC',
          value: value,
          axis: axis,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('renders imperial SAC with two decimals', (tester) async {
    final axis = UnitAxis.stressedSac(
      const UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      ),
    );
    await tester.pumpWidget(host(axis, 28.3, (_) {}));
    // 28.3 L/min = 0.999 cuft/min. Rendering at 0 decimals would show "1".
    expect(find.text('1.00 cuft/min'), findsOneWidget);
  });

  testWidgets('emits canonical values from onChanged', (tester) async {
    double? emitted;
    final axis = UnitAxis.stressedSac(
      const UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      ),
    );
    await tester.pumpWidget(host(axis, 28.3, (v) => emitted = v));

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.40); // display-space cuft/min

    // 1.40 cuft/min back in canonical L/min is ~39.6, not 1.40.
    expect(emitted, isNotNull);
    expect(emitted, greaterThan(30));
  });

  testWidgets('metric SAC renders whole numbers', (tester) async {
    final axis = UnitAxis.stressedSac(const UnitFormatter(AppSettings()));
    await tester.pumpWidget(host(axis, 20, (_) {}));
    expect(find.text('20 L/min'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/forms/unit_slider_test.dart`
Expected: FAIL — "Target of URI doesn't exist: unit_slider.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/shared/widgets/forms/unit_slider.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_axis.dart';

/// A labelled slider bound to a [UnitAxis].
///
/// [value] and the value emitted by [onChanged] are always CANONICAL. The axis
/// owns every conversion, so a caller cannot accidentally mix display and
/// canonical values.
class UnitSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final UnitAxis axis;
  final ValueChanged<double> onChanged;

  const UnitSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.axis,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final display = axis.toDisplay(value).clamp(axis.min, axis.max);
    final readout = '${axis.format(display)} ${axis.symbol}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                readout,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Semantics(
            label: '$label: $readout',
            child: Slider(
              value: display.toDouble(),
              min: axis.min,
              max: axis.max,
              divisions: axis.divisions,
              onChanged: (v) => onChanged(axis.toCanonical(v)),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/forms/unit_slider_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/shared/widgets/forms/unit_slider.dart test/shared/widgets/forms/unit_slider_test.dart
git commit -m "feat(units): add UnitSlider bound to a canonical-unit axis"
```

---

### Task 3: TankSpec

Separates water capacity from free-gas capacity. This is the second of the two
bugs that produced "3 psi".

**Files:**
- Create: `lib/features/gas_calculators/domain/tank_spec.dart`
- Test: `test/features/gas_calculators/domain/tank_spec_test.dart`

**Interfaces:**
- Consumes: `TankPresets`, `TankPreset` from
  `package:submersion/core/constants/tank_presets.dart`.
- Produces:
  - `class TankSpec` with fields `waterVolumeLiters`, `workingPressureBar`,
    `ratedCapacityCuft` (nullable), `label`; getter `double get freeGasLiters`;
    `const TankSpec({required ...})`; `TankSpec.fromPreset(TankPreset)`.
  - `List<TankSpec> metricTankChoices()` and `List<TankSpec> imperialTankChoices()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/tank_spec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

void main() {
  group('TankSpec', () {
    test('AL80 is 11.1 L of water, not 2265 L', () {
      const al80 = TankSpec(
        waterVolumeLiters: 11.1,
        workingPressureBar: 206.843,
        ratedCapacityCuft: 80,
        label: 'AL80',
      );
      expect(al80.waterVolumeLiters, closeTo(11.1, 0.01));
      // The old code stored free gas here, which is ~200x larger.
      expect(al80.waterVolumeLiters, lessThan(20));
    });

    test('free gas is water volume times working pressure', () {
      const al80 = TankSpec(
        waterVolumeLiters: 11.1,
        workingPressureBar: 206.843,
        ratedCapacityCuft: 80,
        label: 'AL80',
      );
      // 11.1 L * 206.843 bar = 2296 L free gas = 81 cuft. Close to rated 80.
      expect(al80.freeGasLiters, closeTo(2296, 5));
      expect(al80.freeGasLiters * 0.0353147, closeTo(81, 1));
    });

    test('imperial choices are real tanks, not bare numbers', () {
      final choices = imperialTankChoices();
      expect(choices, isNotEmpty);
      for (final t in choices) {
        expect(t.waterVolumeLiters, lessThan(30));
        expect(t.workingPressureBar, greaterThan(150));
      }
    });

    test('imperial choices do not all assume a 200 bar fill', () {
      final pressures =
          imperialTankChoices().map((t) => t.workingPressureBar).toSet();
      expect(pressures.length, greaterThan(1));
    });

    test('metric choices are present and sane', () {
      final choices = metricTankChoices();
      expect(choices, isNotEmpty);
      for (final t in choices) {
        expect(t.waterVolumeLiters, inInclusiveRange(5, 30));
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/domain/tank_spec_test.dart`
Expected: FAIL — "Target of URI doesn't exist: tank_spec.dart".

- [ ] **Step 3: Inspect the available presets**

Run:
```bash
grep -n "static const TankPreset\|name:\|volumeLiters:\|workingPressureBar:\|ratedCapacityCuft:" lib/core/constants/tank_presets.dart | head -60
```
Use the real preset identifiers in the next step. Do not invent names.

- [ ] **Step 4: Write the implementation**

Create `lib/features/gas_calculators/domain/tank_spec.dart`:

```dart
import 'package:submersion/core/constants/tank_presets.dart';

/// A cylinder described the way gas planning needs it: water capacity plus a
/// working pressure.
///
/// The distinction matters. An AL80 holds 11.1 L of WATER at 206.8 bar, which
/// is roughly 2296 L (81 cuft) of FREE GAS at the surface. Storing free gas
/// where water capacity is expected inflates the divisor by ~200x and drives
/// reserve pressure to near zero -- the defect behind the reported "3 psi".
class TankSpec {
  /// Internal (water) volume in liters.
  final double waterVolumeLiters;

  /// Rated working pressure in bar.
  final double workingPressureBar;

  /// Manufacturer's rated free-gas capacity, when known.
  final double? ratedCapacityCuft;

  /// Short display label, e.g. "AL80" or "12 L".
  final String label;

  const TankSpec({
    required this.waterVolumeLiters,
    required this.workingPressureBar,
    required this.label,
    this.ratedCapacityCuft,
  });

  /// Free gas at the surface, in liters, at the rated working pressure.
  double get freeGasLiters => waterVolumeLiters * workingPressureBar;

  factory TankSpec.fromPreset(TankPreset preset) => TankSpec(
    waterVolumeLiters: preset.volumeLiters,
    workingPressureBar: preset.workingPressureBar,
    ratedCapacityCuft: preset.ratedCapacityCuft,
    label: preset.name,
  );
}

/// Cylinder choices offered to divers using liters.
List<TankSpec> metricTankChoices() => const [
  TankSpec(waterVolumeLiters: 10, workingPressureBar: 232, label: '10 L'),
  TankSpec(waterVolumeLiters: 12, workingPressureBar: 232, label: '12 L'),
  TankSpec(waterVolumeLiters: 15, workingPressureBar: 232, label: '15 L'),
  TankSpec(waterVolumeLiters: 18, workingPressureBar: 232, label: '18 L'),
];

/// Cylinder choices offered to divers using cubic feet.
///
/// Working pressures differ per tank; the previous code assumed a flat 200 bar
/// for all of them.
List<TankSpec> imperialTankChoices() => const [
  TankSpec(
    waterVolumeLiters: 8.7,
    workingPressureBar: 206.843,
    ratedCapacityCuft: 63,
    label: 'AL63',
  ),
  TankSpec(
    waterVolumeLiters: 11.1,
    workingPressureBar: 206.843,
    ratedCapacityCuft: 80,
    label: 'AL80',
  ),
  TankSpec(
    waterVolumeLiters: 12.2,
    workingPressureBar: 237.317,
    ratedCapacityCuft: 100,
    label: 'HP100',
  ),
  TankSpec(
    waterVolumeLiters: 14.6,
    workingPressureBar: 237.317,
    ratedCapacityCuft: 120,
    label: 'HP120',
  ),
];
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/domain/tank_spec_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/tank_spec.dart test/features/gas_calculators/domain/tank_spec_test.dart
git commit -m "feat(gas): add TankSpec separating water capacity from free gas"
```

---

### Task 4: Rock bottom domain math

**Files:**
- Create: `lib/features/gas_calculators/domain/rock_bottom.dart`
- Test: `test/features/gas_calculators/domain/rock_bottom_test.dart`

**Interfaces:**
- Consumes: `TankSpec` from Task 3.
- Produces:
  - `class RockBottomInputs` — `const` ctor, fields `depthMeters`,
    `ascentRateMetersPerMin`, `diverSacLitersPerMin`, `buddySacLitersPerMin`,
    `solveMinutes`, `includeSafetyStop`, `safetyStopDepthMeters` (default 5),
    `safetyStopMinutes` (default 3), `tank` (`TankSpec`).
  - `class RockBottomResult` — fields `solveGasLiters`, `ascentGasLiters`,
    `safetyStopGasLiters`, `finalAscentGasLiters`, `totalLiters`,
    `reserveBar`, `ascentMinutes`, `totalMinutes`.
  - `RockBottomResult computeRockBottom(RockBottomInputs inputs)`.
  - `double ambientPressureAtDepth(double depthMeters)`.

- [ ] **Step 1: Write the failing test**

Vectors computed with `python3` and reproduced in the spec. **If a vector does
not match, report BLOCKED — do not edit the constant.**

Create `test/features/gas_calculators/domain/rock_bottom_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

const _al80 = TankSpec(
  waterVolumeLiters: 11.1,
  workingPressureBar: 206.843,
  ratedCapacityCuft: 80,
  label: 'AL80',
);

void main() {
  test('ambient pressure is 1 bar at the surface, 4 bar at 30 m', () {
    expect(ambientPressureAtDepth(0), closeTo(1.0, 1e-9));
    expect(ambientPressureAtDepth(30), closeTo(4.0, 1e-9));
  });

  group('computeRockBottom', () {
    test('Case A: 100 ft, 20 ft/min, 15+15 L/min, AL80', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / 3.28084,
          ascentRateMetersPerMin: 20 / 3.28084,
          diverSacLitersPerMin: 15,
          buddySacLitersPerMin: 15,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      expect(r.totalLiters, closeTo(635.0, 1.0));
      expect(r.reserveBar, closeTo(57.2, 0.3));
    });

    test('Case B: realistic imperial stressed SAC 1.0+1.0 cuft/min', () {
      const sacL = 1.0 / 0.0353147; // 28.32 L/min
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / 3.28084,
          ascentRateMetersPerMin: 20 / 3.28084,
          diverSacLitersPerMin: sacL,
          buddySacLitersPerMin: sacL,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      expect(r.solveGasLiters, closeTo(229.3, 1.0));
      expect(r.ascentGasLiters, closeTo(656.7, 2.0));
      expect(r.safetyStopGasLiters, closeTo(254.9, 1.0));
      expect(r.finalAscentGasLiters, closeTo(58.1, 1.0));
      expect(r.totalLiters, closeTo(1198.8, 3.0));
      expect(r.reserveBar, closeTo(108.0, 0.5));
    });

    test('Case C: metric default 30 m, 9 m/min, 20+25 L/min, 12 L', () {
      final r = computeRockBottom(
        const RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 9,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      expect(r.totalLiters, closeTo(757.5, 2.0));
      expect(r.reserveBar, closeTo(63.1, 0.3));
    });

    test('solve time contributes gas proportional to depth pressure', () {
      RockBottomInputs at(double solve) => RockBottomInputs(
        depthMeters: 30,
        ascentRateMetersPerMin: 9,
        diverSacLitersPerMin: 20,
        buddySacLitersPerMin: 25,
        solveMinutes: solve,
        includeSafetyStop: true,
        tank: const TankSpec(
          waterVolumeLiters: 12,
          workingPressureBar: 232,
          label: '12 L',
        ),
      );
      final zero = computeRockBottom(at(0));
      final one = computeRockBottom(at(1));
      // 45 L/min combined at 4 bar for 1 min = 180 L.
      expect(one.totalLiters - zero.totalLiters, closeTo(180, 0.5));
      expect(zero.solveGasLiters, 0);
    });

    test('disabling the safety stop removes stop and final-ascent gas', () {
      final r = computeRockBottom(
        const RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 9,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: false,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      expect(r.safetyStopGasLiters, 0);
      expect(r.finalAscentGasLiters, 0);
    });

    test('a slower ascent rate needs more gas', () {
      RockBottomInputs at(double rate) => RockBottomInputs(
        depthMeters: 30,
        ascentRateMetersPerMin: rate,
        diverSacLitersPerMin: 20,
        buddySacLitersPerMin: 25,
        solveMinutes: 1,
        includeSafetyStop: true,
        tank: const TankSpec(
          waterVolumeLiters: 12,
          workingPressureBar: 232,
          label: '12 L',
        ),
      );
      expect(
        computeRockBottom(at(3)).totalLiters,
        greaterThan(computeRockBottom(at(18)).totalLiters),
      );
    });

    test('the final ascent uses the user rate, not a hardcoded 9 m/min', () {
      final slow = computeRockBottom(
        const RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 3,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 0,
          includeSafetyStop: true,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      // 5 m at 3 m/min = 1.667 min at 1.25 bar on 45 L/min = 93.75 L.
      expect(slow.finalAscentGasLiters, closeTo(93.75, 0.5));
    });

    test('reserve pressure divides by water capacity, not free gas', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / 3.28084,
          ascentRateMetersPerMin: 20 / 3.28084,
          diverSacLitersPerMin: 15,
          buddySacLitersPerMin: 15,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      // Dividing by free gas (2296 L) would give ~0.28 bar, the reported bug.
      expect(r.reserveBar, greaterThan(10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/domain/rock_bottom_test.dart`
Expected: FAIL — "Target of URI doesn't exist: rock_bottom.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/features/gas_calculators/domain/rock_bottom.dart`:

```dart
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

/// Ambient pressure in bar at [depthMeters] of seawater.
double ambientPressureAtDepth(double depthMeters) => depthMeters / 10.0 + 1.0;

/// Inputs to a minimum-gas (rock bottom) calculation. All values canonical:
/// meters, meters per minute, liters per minute, minutes.
class RockBottomInputs {
  final double depthMeters;
  final double ascentRateMetersPerMin;
  final double diverSacLitersPerMin;
  final double buddySacLitersPerMin;

  /// Time budgeted at depth to solve the problem before ascending. Standard
  /// minimum-gas practice (GUE/UTD) budgets this; omitting it understates the
  /// requirement.
  final double solveMinutes;

  final bool includeSafetyStop;
  final double safetyStopDepthMeters;
  final double safetyStopMinutes;
  final TankSpec tank;

  const RockBottomInputs({
    required this.depthMeters,
    required this.ascentRateMetersPerMin,
    required this.diverSacLitersPerMin,
    required this.buddySacLitersPerMin,
    required this.solveMinutes,
    required this.includeSafetyStop,
    required this.tank,
    this.safetyStopDepthMeters = 5.0,
    this.safetyStopMinutes = 3.0,
  });

  /// Both divers breathing from one cylinder during an air share.
  double get combinedSacLitersPerMin =>
      diverSacLitersPerMin + buddySacLitersPerMin;
}

class RockBottomResult {
  final double solveGasLiters;
  final double ascentGasLiters;
  final double safetyStopGasLiters;
  final double finalAscentGasLiters;
  final double totalLiters;

  /// Reserve expressed as a pressure in the given cylinder.
  final double reserveBar;

  final double ascentMinutes;
  final double totalMinutes;

  const RockBottomResult({
    required this.solveGasLiters,
    required this.ascentGasLiters,
    required this.safetyStopGasLiters,
    required this.finalAscentGasLiters,
    required this.totalLiters,
    required this.reserveBar,
    required this.ascentMinutes,
    required this.totalMinutes,
  });
}

/// Compute the minimum gas both divers need to reach the surface from depth.
///
/// Four phases, every one of them driven by the caller's ascent rate. Each
/// ascent phase is priced at the arithmetic mean depth of that phase, which is
/// exact for a constant-rate ascent.
RockBottomResult computeRockBottom(RockBottomInputs inputs) {
  final combined = inputs.combinedSacLitersPerMin;
  final rate = inputs.ascentRateMetersPerMin;
  final stopDepth = inputs.includeSafetyStop
      ? inputs.safetyStopDepthMeters
      : 0.0;

  // Phase 1: solve the problem at depth.
  final solveGas =
      combined *
      ambientPressureAtDepth(inputs.depthMeters) *
      inputs.solveMinutes;

  // Phase 2: ascend from depth to the stop (or the surface).
  final ascentDistance = (inputs.depthMeters - stopDepth).clamp(
    0.0,
    double.infinity,
  );
  final ascentMinutes = rate > 0 ? ascentDistance / rate : 0.0;
  final ascentGas =
      combined *
      ambientPressureAtDepth((inputs.depthMeters + stopDepth) / 2) *
      ascentMinutes;

  // Phase 3: hold the safety stop.
  final stopGas = inputs.includeSafetyStop
      ? combined *
            ambientPressureAtDepth(stopDepth) *
            inputs.safetyStopMinutes
      : 0.0;

  // Phase 4: ascend the last few meters at the same rate.
  final finalMinutes = inputs.includeSafetyStop && rate > 0
      ? stopDepth / rate
      : 0.0;
  final finalGas = inputs.includeSafetyStop
      ? combined * ambientPressureAtDepth(stopDepth / 2) * finalMinutes
      : 0.0;

  final total = solveGas + ascentGas + stopGas + finalGas;

  return RockBottomResult(
    solveGasLiters: solveGas,
    ascentGasLiters: ascentGas,
    safetyStopGasLiters: stopGas,
    finalAscentGasLiters: finalGas,
    totalLiters: total,
    reserveBar: inputs.tank.waterVolumeLiters > 0
        ? total / inputs.tank.waterVolumeLiters
        : 0.0,
    ascentMinutes: ascentMinutes,
    totalMinutes:
        inputs.solveMinutes +
        ascentMinutes +
        (inputs.includeSafetyStop ? inputs.safetyStopMinutes : 0.0) +
        finalMinutes,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/domain/rock_bottom_test.dart`
Expected: PASS, all 9 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/rock_bottom.dart test/features/gas_calculators/domain/rock_bottom_test.dart
git commit -m "feat(gas): pure rock-bottom math with problem-solving time at depth"
```

---

### Task 5: Consumption and rounding helpers

**Files:**
- Create: `lib/features/gas_calculators/domain/gas_consumption.dart`
- Test: `test/features/gas_calculators/domain/gas_consumption_test.dart`

**Interfaces:**
- Consumes: `TankSpec` (Task 3), `ambientPressureAtDepth` (Task 4).
- Produces:
  - `class ConsumptionInputs` — `avgDepthMeters`, `minutes`,
    `sacLitersPerMin`, `tank`.
  - `class ConsumptionResult` — `litersConsumed`, `barConsumed`,
    `litersRemaining`, `barRemaining`, `exceedsTank`, `gasAtDepthLitersPerMin`.
  - `ConsumptionResult computeConsumption(ConsumptionInputs)`.
  - `double roundUpTo(double value, double grid)`.
  - `double roundDownTo(double value, double grid)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/gas_consumption_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

const _al80 = TankSpec(
  waterVolumeLiters: 11.1,
  workingPressureBar: 206.843,
  ratedCapacityCuft: 80,
  label: 'AL80',
);

void main() {
  group('rounding helpers', () {
    test('roundUpTo rounds toward a larger reserve', () {
      expect(roundUpTo(57.2, 10), 60);
      expect(roundUpTo(60.0, 10), 60);
      expect(roundUpTo(1566, 250), 1750);
    });

    test('roundDownTo rounds toward a shallower limit', () {
      expect(roundDownTo(35.16, 1), 35);
      expect(roundDownTo(31.94, 1), 31);
    });
  });

  group('computeConsumption', () {
    test('20 m for 45 min at 15 L/min uses 1350 L', () {
      final r = computeConsumption(
        const ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      // 15 L/min * 3 bar * 45 min = 2025 L.
      expect(r.litersConsumed, closeTo(2025, 0.1));
      expect(r.gasAtDepthLitersPerMin, closeTo(45, 0.1));
      // 2025 L / 12 L = 168.75 bar.
      expect(r.barConsumed, closeTo(168.75, 0.1));
    });

    test('uses the tank working pressure, not a hardcoded 200 bar', () {
      final r = computeConsumption(
        const ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: _al80,
        ),
      );
      // AL80 is 206.843 bar, so remaining is 206.843 - consumed, not 200 -.
      expect(r.barRemaining, closeTo(206.843 - r.barConsumed, 0.01));
      expect(r.litersRemaining, closeTo(_al80.freeGasLiters - 2025, 1.0));
    });

    test('flags a plan that exceeds the cylinder', () {
      final r = computeConsumption(
        const ConsumptionInputs(
          avgDepthMeters: 40,
          minutes: 90,
          sacLitersPerMin: 25,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      expect(r.exceedsTank, isTrue);
    });

    test('a normal plan does not flag', () {
      final r = computeConsumption(
        const ConsumptionInputs(
          avgDepthMeters: 20,
          minutes: 45,
          sacLitersPerMin: 15,
          tank: TankSpec(
            waterVolumeLiters: 12,
            workingPressureBar: 232,
            label: '12 L',
          ),
        ),
      );
      expect(r.exceedsTank, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/domain/gas_consumption_test.dart`
Expected: FAIL — "Target of URI doesn't exist: gas_consumption.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/features/gas_calculators/domain/gas_consumption.dart`:

```dart
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

/// Round [value] up to the next multiple of [grid]. Used where rounding must
/// favour a larger reserve.
double roundUpTo(double value, double grid) => (value / grid).ceil() * grid;

/// Round [value] down to the previous multiple of [grid]. Used where rounding
/// must favour a shallower or leaner limit.
double roundDownTo(double value, double grid) => (value / grid).floor() * grid;

class ConsumptionInputs {
  final double avgDepthMeters;
  final int minutes;
  final double sacLitersPerMin;
  final TankSpec tank;

  const ConsumptionInputs({
    required this.avgDepthMeters,
    required this.minutes,
    required this.sacLitersPerMin,
    required this.tank,
  });
}

class ConsumptionResult {
  final double litersConsumed;
  final double barConsumed;
  final double litersRemaining;
  final double barRemaining;
  final bool exceedsTank;

  /// Surface-equivalent consumption rate at the planned depth.
  final double gasAtDepthLitersPerMin;

  const ConsumptionResult({
    required this.litersConsumed,
    required this.barConsumed,
    required this.litersRemaining,
    required this.barRemaining,
    required this.exceedsTank,
    required this.gasAtDepthLitersPerMin,
  });
}

/// Gas used over a square-profile dive segment.
ConsumptionResult computeConsumption(ConsumptionInputs inputs) {
  final pressure = ambientPressureAtDepth(inputs.avgDepthMeters);
  final atDepth = inputs.sacLitersPerMin * pressure;
  final consumed = atDepth * inputs.minutes;

  final water = inputs.tank.waterVolumeLiters;
  final barConsumed = water > 0 ? consumed / water : 0.0;

  return ConsumptionResult(
    litersConsumed: consumed,
    barConsumed: barConsumed,
    litersRemaining: inputs.tank.freeGasLiters - consumed,
    barRemaining: inputs.tank.workingPressureBar - barConsumed,
    exceedsTank: barConsumed > inputs.tank.workingPressureBar,
    gasAtDepthLitersPerMin: atDepth,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/domain/gas_consumption_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/gas_consumption.dart test/features/gas_calculators/domain/gas_consumption_test.dart
git commit -m "feat(gas): pure consumption math using the tank working pressure"
```

---

### Task 6: Best mix domain math

**Files:**
- Create: `lib/features/gas_calculators/domain/best_mix.dart`
- Test: `test/features/gas_calculators/domain/best_mix_test.dart`

**Interfaces:**
- Consumes: `GasMix` from `package:submersion/features/dive_log/domain/entities/dive.dart`
  (has `mod({double ppO2})`, `end(double depth, {bool o2Narcotic})`, `name`,
  and `static double heForMnd(double targetMnd, double o2, {double endLimit, bool o2Narcotic})`);
  `gasDensityGPerL({required double fO2, required double fHe, required double ambientPressureBar})`,
  `gasDensityWarnGPerL`, `gasDensityCriticalGPerL` from
  `package:submersion/core/deco/gas_density.dart`; `ambientPressureAtDepth`
  and `roundDownTo` from Tasks 4 and 5.
- Produces:
  - `class BestMixInputs` — `depthMeters`, `ppO2Limit`, `endLimitMeters`,
    `o2Narcotic`.
  - `class BestMixResult` — `mix` (`GasMix`), `idealO2Percent`,
    `modMeters`, `marginMeters`, `endMeters`, `densityGPerL`,
    `exceedsWarnDensity`, `exceedsCriticalDensity`,
    `nearestStandardMix` (`GasMix?`).
  - `BestMixResult computeBestMix(BestMixInputs)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/gas_calculators/domain/best_mix_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/best_mix.dart';

void main() {
  group('computeBestMix at 111 ft (the reported regression)', () {
    final r = computeBestMix(
      BestMixInputs(
        depthMeters: 111 / 3.28084,
        ppO2Limit: 1.4,
        endLimitMeters: 30,
        o2Narcotic: true,
      ),
    );

    test('ideal fraction is 31.94 percent', () {
      expect(r.idealO2Percent, closeTo(31.94, 0.05));
    });

    test('rounds DOWN to EAN31, never up to EAN32', () {
      expect(r.mix.roundedO2, 31);
      expect(r.mix.name, 'EAN31');
    });

    test('the recommended mix MOD is deeper than the target depth', () {
      expect(r.modMeters, greaterThan(111 / 3.28084));
      expect(r.modMeters, closeTo(35.16, 0.05));
      expect(r.marginMeters, greaterThan(0));
    });

    test('flags EAN31 at this depth as over the warn density', () {
      expect(r.densityGPerL, closeTo(5.33, 0.05));
      expect(r.exceedsWarnDensity, isTrue);
      expect(r.exceedsCriticalDensity, isFalse);
    });

    test('the advisory standard mix also covers the depth', () {
      expect(r.nearestStandardMix, isNotNull);
      expect(r.nearestStandardMix!.roundedO2, 30);
      expect(
        r.nearestStandardMix!.mod(ppO2: 1.4),
        greaterThanOrEqualTo(111 / 3.28084),
      );
    });
  });

  group('rounding direction is always toward safety', () {
    test('O2 never rounds up for any depth in the recreational range', () {
      for (var ft = 40; ft <= 180; ft += 1) {
        final depth = ft / 3.28084;
        final r = computeBestMix(
          BestMixInputs(
            depthMeters: depth,
            ppO2Limit: 1.4,
            endLimitMeters: 30,
            o2Narcotic: true,
          ),
        );
        expect(
          r.mix.mod(ppO2: 1.4),
          greaterThanOrEqualTo(depth - 1e-6),
          reason: 'recommended mix must be breathable at $ft ft',
        );
      }
    });
  });

  group('helium', () {
    test('adds no helium when the nitrox mix is within the END limit', () {
      final r = computeBestMix(
        BestMixInputs(
          depthMeters: 25,
          ppO2Limit: 1.4,
          endLimitMeters: 30,
          o2Narcotic: true,
        ),
      );
      expect(r.mix.he, 0);
    });

    test('adds helium when END would be exceeded, rounded up to 5 percent',
        () {
      final r = computeBestMix(
        BestMixInputs(
          depthMeters: 50,
          ppO2Limit: 1.4,
          endLimitMeters: 30,
          o2Narcotic: true,
        ),
      );
      expect(r.mix.he, greaterThan(0));
      expect(r.mix.he % 5, closeTo(0, 1e-9));
      expect(r.mix.isTrimix, isTrue);
      // Rounding He UP must bring END at or below the limit.
      expect(r.endMeters, lessThanOrEqualTo(30 + 1e-6));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/domain/best_mix_test.dart`
Expected: FAIL — "Target of URI doesn't exist: best_mix.dart".

- [ ] **Step 3: Write the implementation**

Create `lib/features/gas_calculators/domain/best_mix.dart`:

```dart
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundDownTo;
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;

/// Standard mixes a fill station is likely to have, richest first.
const List<double> _standardO2Percentages = [50, 40, 36, 32, 30, 28, 21];

class BestMixInputs {
  final double depthMeters;
  final double ppO2Limit;
  final double endLimitMeters;
  final bool o2Narcotic;

  const BestMixInputs({
    required this.depthMeters,
    required this.ppO2Limit,
    required this.endLimitMeters,
    required this.o2Narcotic,
  });
}

class BestMixResult {
  final GasMix mix;

  /// The exact, unrounded ideal O2 percentage.
  final double idealO2Percent;

  /// MOD of the RECOMMENDED mix (not of the ideal fraction).
  final double modMeters;

  /// How much deeper the recommended mix may be taken than the target depth.
  final double marginMeters;

  final double endMeters;
  final double densityGPerL;
  final bool exceedsWarnDensity;
  final bool exceedsCriticalDensity;

  /// Nearest commonly stocked mix whose MOD still covers the target depth.
  /// Advisory only.
  final GasMix? nearestStandardMix;

  const BestMixResult({
    required this.mix,
    required this.idealO2Percent,
    required this.modMeters,
    required this.marginMeters,
    required this.endMeters,
    required this.densityGPerL,
    required this.exceedsWarnDensity,
    required this.exceedsCriticalDensity,
    required this.nearestStandardMix,
  });
}

/// Compute the best breathing mix for a target depth.
///
/// Rounding is always toward safety: O2 DOWN to a whole percent, so the
/// recommended mix's MOD is at or beyond the target depth; helium UP to 5%, so
/// END lands at or inside the limit. The previous implementation bucketed the
/// ideal fraction UP into a named mix, which at 111 ft recommended EAN32 --
/// whose own MOD at ppO2 1.4 is 110.7 ft, shallower than the dive.
BestMixResult computeBestMix(BestMixInputs inputs) {
  final ambient = ambientPressureAtDepth(inputs.depthMeters);
  final ideal = inputs.ppO2Limit / ambient * 100;

  // Round DOWN so the resulting MOD is at or beyond the target depth.
  final o2 = roundDownTo(ideal, 1).clamp(1.0, 100.0);

  // Helium only if the nitrox mix would exceed the narcosis limit.
  final nitrox = GasMix(o2: o2);
  final nitroxEnd = nitrox.end(
    inputs.depthMeters,
    o2Narcotic: inputs.o2Narcotic,
  );

  var he = 0.0;
  if (nitroxEnd > inputs.endLimitMeters) {
    final needed = GasMix.heForMnd(
      inputs.depthMeters,
      o2,
      endLimit: inputs.endLimitMeters,
      o2Narcotic: inputs.o2Narcotic,
    );
    // Round UP to a 5% increment: more helium is less narcosis.
    he = (needed / 5).ceil() * 5.0;
    he = he.clamp(0.0, 100.0 - o2);
  }

  final mix = GasMix(o2: o2, he: he);
  final mod = mix.mod(ppO2: inputs.ppO2Limit);
  final density = gasDensityGPerL(
    fO2: o2 / 100,
    fHe: he / 100,
    ambientPressureBar: ambient,
  );

  GasMix? nearest;
  for (final candidate in _standardO2Percentages) {
    final standard = GasMix(o2: candidate);
    if (standard.mod(ppO2: inputs.ppO2Limit) >= inputs.depthMeters) {
      nearest = standard;
      break;
    }
  }

  return BestMixResult(
    mix: mix,
    idealO2Percent: ideal,
    modMeters: mod,
    marginMeters: mod - inputs.depthMeters,
    endMeters: mix.end(inputs.depthMeters, o2Narcotic: inputs.o2Narcotic),
    densityGPerL: density,
    exceedsWarnDensity: density > gasDensityWarnGPerL,
    exceedsCriticalDensity: density > gasDensityCriticalGPerL,
    nearestStandardMix: nearest,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/domain/best_mix_test.dart`
Expected: PASS. If the helium test fails because `heForMnd` returns a value
whose 5% ceiling still leaves END above the limit, report BLOCKED rather than
loosening the assertion — that would indicate a real rounding-direction bug.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/domain/best_mix.dart test/features/gas_calculators/domain/best_mix_test.dart
git commit -m "fix(gas): best mix rounds O2 down and reports its own MOD"
```

---

### Task 7: ARB keys for the gas calculators (English)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

**Interfaces:**
- Produces (available as `context.l10n.<key>` after `flutter gen-l10n`):
  `gasCalculators_planningCaveat`, `gasCalculators_rockBottom_solveTime`,
  `gasCalculators_rockBottom_solveTimeHint`,
  `gasCalculators_rockBottom_solveGas`,
  `gasCalculators_bestMix_recommendedMix`,
  `gasCalculators_bestMix_modLabel`, `gasCalculators_bestMix_marginLabel`,
  `gasCalculators_bestMix_endLabel`, `gasCalculators_bestMix_densityLabel`,
  `gasCalculators_bestMix_densityWarn`, `gasCalculators_bestMix_densityCritical`,
  `gasCalculators_bestMix_idealLabel`, `gasCalculators_bestMix_nearestStandard`,
  `gasCalculators_bestMix_endLimitLabel`.

- [ ] **Step 1: Add the keys**

Insert into `lib/l10n/arb/app_en.arb`, keeping the file valid JSON. Place each
key next to the existing `gasCalculators_*` block. The `@key` metadata entry is
required for any string containing a placeholder.

```json
  "gasCalculators_planningCaveat": "Planning estimate. Assumes a direct ascent. Verify against your training and add margin for conditions.",
  "gasCalculators_rockBottom_solveTime": "Problem-solving time",
  "gasCalculators_rockBottom_solveTimeHint": "Time spent at depth resolving the emergency before starting the ascent.",
  "gasCalculators_rockBottom_solveGas": "Problem-solving gas at {depth}{unit}",
  "@gasCalculators_rockBottom_solveGas": {
    "placeholders": { "depth": { "type": "Object" }, "unit": { "type": "Object" } }
  },
  "gasCalculators_bestMix_recommendedMix": "Recommended mix",
  "gasCalculators_bestMix_idealLabel": "Ideal fraction",
  "gasCalculators_bestMix_modLabel": "MOD at {ppO2} bar",
  "@gasCalculators_bestMix_modLabel": {
    "placeholders": { "ppO2": { "type": "Object" } }
  },
  "gasCalculators_bestMix_marginLabel": "Margin below MOD",
  "gasCalculators_bestMix_endLabel": "END at depth",
  "gasCalculators_bestMix_endLimitLabel": "END limit",
  "gasCalculators_bestMix_densityLabel": "Gas density at depth",
  "gasCalculators_bestMix_densityWarn": "Above the recommended {limit} g/L density limit.",
  "@gasCalculators_bestMix_densityWarn": {
    "placeholders": { "limit": { "type": "Object" } }
  },
  "gasCalculators_bestMix_densityCritical": "Above the {limit} g/L hard density ceiling.",
  "@gasCalculators_bestMix_densityCritical": {
    "placeholders": { "limit": { "type": "Object" } }
  },
  "gasCalculators_bestMix_nearestStandard": "Nearest standard mix that still covers this depth",
```

- [ ] **Step 2: Verify the ARB is valid JSON**

Run:
```bash
python3 -c "import json;d=json.load(open('lib/l10n/arb/app_en.arb'));print('keys:',len([k for k in d if not k.startswith('@')]))"
```
Expected: a key count 14 higher than the previous 6157, i.e. 6171.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes with no error. Missing translations in other locales are
reported as warnings and fall back to English; Task 15 fills them in.

- [ ] **Step 4: Verify the getters exist**

Run: `grep -c "gasCalculators_bestMix_modLabel\|gasCalculators_planningCaveat" lib/l10n/arb/app_localizations.dart`
Expected: at least 2.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "feat(l10n): add English keys for gas calculator results"
```

---

### Task 8: Rewire the Rock Bottom calculator

**Files:**
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart:90-165`
- Modify: `lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart`
- Test: `test/features/gas_calculators/rock_bottom_calculator_widget_test.dart`

**Interfaces:**
- Consumes: `UnitAxis` (Task 1), `UnitSlider` (Task 2), `TankSpec` +
  `metricTankChoices` + `imperialTankChoices` (Task 3), `computeRockBottom` +
  `RockBottomInputs` + `RockBottomResult` (Task 4), `roundUpTo` (Task 5), ARB
  keys (Task 7).
- Produces: `rockBottomSolveMinutesProvider` (`StateProvider<double>`,
  default 1.0); `rockBottomTankProvider` (`StateProvider<TankSpec>`, replacing
  `rockBottomTankSizeProvider`); `rockBottomResultProvider`
  (`Provider<RockBottomResult>`).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/gas_calculators/rock_bottom_calculator_widget_test.dart`.

The settings-override helper below is the **established pattern in this
codebase** (see `test/core/presentation/widgets/dive_comparison_card_test.dart:22-32`):
a `StateNotifier<AppSettings>` that `implements SettingsNotifier` and delegates
everything else through `noSuchMethod`. There is no `SettingsNotifier.forTest`
constructor — do not add one.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(AppSettings settings) : super(settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host({required AppSettings settings}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: RockBottomCalculator()),
    ),
  );
}

void main() {
  testWidgets('imperial SAC slider offers a selectable cuft/min range',
      (tester) async {
    await tester.pumpWidget(
      _host(
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          volumeUnit: VolumeUnit.cubicFeet,
          pressureUnit: PressureUnit.psi,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The old build showed "15 cuft/min" as the minimum, which is 425 L/min.
    expect(find.textContaining('15 cuft/min'), findsNothing);
    expect(find.textContaining('cuft/min'), findsWidgets);
  });

  testWidgets('metric build renders a plausible reserve, not near-zero',
      (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('bar'), findsWidgets);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/rock_bottom_calculator_widget_test.dart`
Expected: FAIL — the imperial slider still renders "15 cuft/min", and the
caveat text is absent.

- [ ] **Step 3: Replace the providers**

In `gas_calculators_providers.dart`, delete `rockBottomTankSizeProvider` and
the old `rockBottomResultProvider` (lines 104-165) and replace with:

```dart
/// Time spent at depth solving the problem before ascending (minutes).
final rockBottomSolveMinutesProvider = StateProvider<double>((ref) => 1.0);

/// Selected cylinder. Water capacity and working pressure travel together so
/// reserve pressure cannot be computed against a free-gas figure.
final rockBottomTankProvider = StateProvider<TankSpec>(
  (ref) => const TankSpec(
    waterVolumeLiters: 12,
    workingPressureBar: 232,
    label: '12 L',
  ),
);

/// Rock bottom result with per-phase breakdown.
final rockBottomResultProvider = Provider<RockBottomResult>((ref) {
  return computeRockBottom(
    RockBottomInputs(
      depthMeters: ref.watch(rockBottomDepthProvider),
      ascentRateMetersPerMin: ref.watch(rockBottomAscentRateProvider),
      diverSacLitersPerMin: ref.watch(rockBottomSacProvider),
      buddySacLitersPerMin: ref.watch(rockBottomBuddySacProvider),
      solveMinutes: ref.watch(rockBottomSolveMinutesProvider),
      includeSafetyStop: ref.watch(rockBottomSafetyStopProvider),
      tank: ref.watch(rockBottomTankProvider),
    ),
  );
});
```

Add these imports at the top of the file:

```dart
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
```

Update `resetGasCalculators` — replace the
`ref.read(rockBottomTankSizeProvider.notifier).state = 12.0;` line with:

```dart
  ref.read(rockBottomTankProvider.notifier).state = const TankSpec(
    waterVolumeLiters: 12,
    workingPressureBar: 232,
    label: '12 L',
  );
  ref.read(rockBottomSolveMinutesProvider.notifier).state = 1.0;
```

- [ ] **Step 4: Rewire the widget**

In `rock_bottom_calculator.dart`:

1. Replace the local `_buildSliderSection` calls for depth, ascent rate, your
   SAC, and buddy SAC with `UnitSlider`, and delete the now-unused
   `_buildSliderSection` method:

```dart
UnitSlider(
  icon: Icons.arrow_downward,
  label: context.l10n.gasCalculators_rockBottom_maximumDepth,
  value: depth,
  axis: UnitAxis.depth(units),
  onChanged: (v) =>
      ref.read(rockBottomDepthProvider.notifier).state = v,
),
```

```dart
UnitSlider(
  icon: Icons.arrow_upward,
  label: context.l10n.gasCalculators_rockBottom_ascentRate,
  value: ascentRate,
  axis: UnitAxis.ascentRate(units),
  onChanged: (v) =>
      ref.read(rockBottomAscentRateProvider.notifier).state = v,
),
```

```dart
UnitSlider(
  icon: Icons.person,
  label: context.l10n.gasCalculators_rockBottom_yourSac,
  value: sac,
  axis: UnitAxis.stressedSac(units),
  onChanged: (v) => ref.read(rockBottomSacProvider.notifier).state = v,
),
```

```dart
UnitSlider(
  icon: Icons.people,
  label: context.l10n.gasCalculators_rockBottom_buddySac,
  value: buddySac,
  axis: UnitAxis.stressedSac(units),
  onChanged: (v) =>
      ref.read(rockBottomBuddySacProvider.notifier).state = v,
),
```

2. Add a solve-time slider below the ascent rate:

```dart
UnitSlider(
  icon: Icons.build_outlined,
  label: context.l10n.gasCalculators_rockBottom_solveTime,
  value: solveMinutes,
  axis: UnitAxis(
    min: 0,
    max: 3,
    step: 1,
    decimals: 0,
    symbol: 'min',
    toDisplayFn: (v) => v,
    toCanonicalFn: (v) => v,
  ),
  onChanged: (v) =>
      ref.read(rockBottomSolveMinutesProvider.notifier).state = v,
),
```

3. Replace `_buildTankChip` so it stores a `TankSpec`:

```dart
  Widget _buildTankChip(
    BuildContext context,
    WidgetRef ref,
    TankSpec tank,
    bool isSelected,
    UnitFormatter units,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(
        units.formatTankVolume(
          tank.waterVolumeLiters,
          tank.workingPressureBar,
          ratedCapacityCuft: tank.ratedCapacityCuft,
        ),
      ),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(rockBottomTankProvider.notifier).state = tank,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
```

and drive it from the choice list:

```dart
final tankChoices =
    isMetricVolume ? metricTankChoices() : imperialTankChoices();
...
for (final choice in tankChoices)
  _buildTankChip(
    context,
    ref,
    choice,
    choice.label == tank.label,
    units,
  ),
```

4. Round the headline reserve up toward safety:

```dart
final pressureGrid = settings.pressureUnit == PressureUnit.bar ? 10.0 : 250.0;
final displayPressure = roundUpTo(
  units.convertPressure(result.reserveBar),
  pressureGrid,
);
```

5. Add the solve-gas breakdown row and the caveat line inside the result card:

```dart
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_rockBottom_solveGas(
    units.convertDepth(depth).toStringAsFixed(0),
    depthSymbol,
  ),
  '${units.convertVolume(result.solveGasLiters).toStringAsFixed(0)} $volumeSymbol',
),
```

```dart
Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Text(
    context.l10n.gasCalculators_planningCaveat,
    textAlign: TextAlign.center,
    style: textTheme.bodySmall?.copyWith(
      color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
    ),
  ),
),
```

6. Replace the breakdown's hand-rolled ascent time
   (`'${((depth - (includeSafetyStop ? 5 : 0)) / ascentRate).toStringAsFixed(1)} min'`)
   with `'${result.ascentMinutes.toStringAsFixed(1)} min'`.

Add imports:

```dart
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundUpTo;
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
flutter test test/features/gas_calculators/ test/core/utils/unit_axis_test.dart
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/ test/features/gas_calculators/
git commit -m "fix(gas): rock bottom converts SAC, uses water capacity, budgets solve time"
```

---

### Task 9: Rewire the Consumption calculator

**Files:**
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart:51-87`
- Modify: `lib/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart`
- Test: `test/features/gas_calculators/gas_consumption_calculator_widget_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-5 and 7.
- Produces: `consumptionTankProvider` (`StateProvider<TankSpec>`, replacing
  `consumptionTankSizeProvider`); `consumptionResultProvider`
  (`Provider<ConsumptionResult>`).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/gas_calculators/gas_consumption_calculator_widget_test.dart`,
using the same `_host` helper pattern confirmed in Task 8 Step 2:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(AppSettings settings) : super(settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host({required AppSettings settings}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: GasConsumptionCalculator()),
    ),
  );
}

void main() {
  testWidgets('imperial SAC slider is on a cuft/min scale', (tester) async {
    await tester.pumpWidget(
      _host(
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          volumeUnit: VolumeUnit.cubicFeet,
          pressureUnit: PressureUnit.psi,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The old slider ran 8-30 "cuft/min", i.e. 226-850 L/min.
    expect(find.textContaining('8 cuft/min'), findsNothing);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/gas_consumption_calculator_widget_test.dart`
Expected: FAIL.

- [ ] **Step 3: Replace the providers**

In `gas_calculators_providers.dart`, delete `consumptionTankSizeProvider` and
the old `consumptionResultProvider` (lines 63-87) and replace with:

```dart
/// Selected cylinder for consumption planning.
final consumptionTankProvider = StateProvider<TankSpec>(
  (ref) => const TankSpec(
    waterVolumeLiters: 12,
    workingPressureBar: 232,
    label: '12 L',
  ),
);

/// Gas used over the planned dive, plus what is left in the cylinder.
final consumptionResultProvider = Provider<ConsumptionResult>((ref) {
  return computeConsumption(
    ConsumptionInputs(
      avgDepthMeters: ref.watch(consumptionDepthProvider),
      minutes: ref.watch(consumptionTimeProvider),
      sacLitersPerMin: ref.watch(consumptionSacProvider),
      tank: ref.watch(consumptionTankProvider),
    ),
  );
});
```

Add the import:

```dart
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart';
```

Update `resetGasCalculators` — replace
`ref.read(consumptionTankSizeProvider.notifier).state = 12.0;` with:

```dart
  ref.read(consumptionTankProvider.notifier).state = const TankSpec(
    waterVolumeLiters: 12,
    workingPressureBar: 232,
    label: '12 L',
  );
```

- [ ] **Step 4: Rewire the widget**

In `gas_consumption_calculator.dart`, apply the same four changes as Task 8:

1. Depth, time, and SAC sliders become `UnitSlider` with `UnitAxis.depth`,
   `UnitAxis.diveTime()`, and `UnitAxis.normalSac`; delete
   `_buildSliderSection`.
2. Tank chips become `TankSpec` chips (copy the `_buildTankChip` body from
   Task 8 Step 5, changing the provider to `consumptionTankProvider`).
3. Every reference to the hardcoded `200` becomes the selected tank's working
   pressure. Specifically, replace:
   - `final maxFillPressure = units.convertPressure(200);` with
     `final maxFillPressure = units.convertPressure(tank.workingPressureBar);`
   - `'${units.convertVolume(tankSize * 200).toStringAsFixed(0)} $volumeSymbol'`
     with
     `'${units.convertVolume(tank.freeGasLiters).toStringAsFixed(0)} $volumeSymbol'`
   - the remaining-gas row with
     `'${units.convertVolume(result.litersRemaining).toStringAsFixed(0)} $volumeSymbol '
      '(${units.convertPressure(result.barRemaining).toStringAsFixed(0)} $pressureSymbol)'`
   - `result.liters` with `result.litersConsumed` and `result.bar` with
     `result.barConsumed` throughout.
   - the gas-at-depth row value with
     `'${units.convertVolume(result.gasAtDepthLitersPerMin).toStringAsFixed(1)} $volumeSymbol/min'`
4. Round the headline pressure up and add the caveat, exactly as in Task 8
   Steps 4 and 5 (grid: 10 bar / 100 psi for consumption).

Add the same four imports listed in Task 8 Step 5.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/ test/features/gas_calculators/
git commit -m "fix(gas): consumption converts SAC and uses the tank working pressure"
```

---

### Task 10: Rebuild the Best Mix calculator UI

**Files:**
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart:21-49`
- Modify: `lib/features/gas_calculators/presentation/widgets/best_mix_calculator.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/mod_calculator.dart`
- Test: `test/features/gas_calculators/best_mix_calculator_widget_test.dart`

**Interfaces:**
- Consumes: `computeBestMix`, `BestMixInputs`, `BestMixResult` (Task 6);
  `roundDownTo` (Task 5); ARB keys (Task 7).
- Produces: `bestMixEndLimitProvider` (`StateProvider<double>`, seeded from
  `settings.endLimit` via `ref.read`); `bestMixO2NarcoticProvider`
  (`StateProvider<bool>`, seeded from `settings.o2Narcotic`);
  `bestMixResultProvider` (`Provider<BestMixResult>`).
  `bestMixSuggestionProvider` is **deleted**.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/gas_calculators/best_mix_calculator_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(AppSettings settings) : super(settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host({required AppSettings settings}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: BestMixCalculator()),
    ),
  );
}

void main() {
  testWidgets('at 111 ft it recommends EAN31, never EAN32', (tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(
              const AppSettings(depthUnit: DepthUnit.feet),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const BestMixCalculator();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    captured.read(bestMixDepthProvider.notifier).state = 111 / 3.28084;
    await tester.pumpAndSettle();

    expect(find.textContaining('EAN31'), findsWidgets);
    expect(find.textContaining('EAN32'), findsNothing);
  });

  testWidgets('always shows the recommended mix MOD', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('MOD'), findsWidgets);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gas_calculators/best_mix_calculator_widget_test.dart`
Expected: FAIL — the current build renders "EAN32" for that depth.

- [ ] **Step 3: Replace the providers**

In `gas_calculators_providers.dart`, delete `bestMixResultProvider` and
`bestMixSuggestionProvider` (lines 30-49) and replace with:

```dart
/// END limit for best mix, initialized from settings. Uses ref.read so a user
/// override is not lost when unrelated settings change; reset re-reads.
final bestMixEndLimitProvider = StateProvider<double>((ref) {
  return ref.read(settingsProvider).endLimit;
});

/// Whether O2 counts as narcotic, initialized from settings.
final bestMixO2NarcoticProvider = StateProvider<bool>((ref) {
  return ref.read(settingsProvider).o2Narcotic;
});

/// Best mix for the target depth, rounded toward safety.
final bestMixResultProvider = Provider<BestMixResult>((ref) {
  return computeBestMix(
    BestMixInputs(
      depthMeters: ref.watch(bestMixDepthProvider),
      ppO2Limit: ref.watch(bestMixPpO2Provider),
      endLimitMeters: ref.watch(bestMixEndLimitProvider),
      o2Narcotic: ref.watch(bestMixO2NarcoticProvider),
    ),
  );
});
```

Add imports:

```dart
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

In `resetGasCalculators`, after the Best Mix lines add:

```dart
  ref.invalidate(bestMixEndLimitProvider);
  ref.invalidate(bestMixO2NarcoticProvider);
```

- [ ] **Step 4: Rebuild the widget body**

In `best_mix_calculator.dart`, replace the result card so it renders the
recommended mix and its own limits. The key requirement: **the MOD shown is the
MOD of the recommended mix, not of the ideal fraction.**

```dart
final result = ref.watch(bestMixResultProvider);
final depth = ref.watch(bestMixDepthProvider);
final ppO2 = ref.watch(bestMixPpO2Provider);
```

```dart
Text(
  result.mix.name,
  style: textTheme.displaySmall?.copyWith(
    fontWeight: FontWeight.bold,
    color: colorScheme.onPrimaryContainer,
  ),
),
const SizedBox(height: 16),
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_bestMix_idealLabel,
  '${result.idealO2Percent.toStringAsFixed(1)}%',
),
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_bestMix_modLabel(
    ppO2.toStringAsFixed(1),
  ),
  units.formatDepth(result.modMeters, decimals: 0),
),
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_bestMix_marginLabel,
  units.formatDepth(result.marginMeters, decimals: 0),
),
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_bestMix_endLabel,
  units.formatDepth(result.endMeters, decimals: 0),
),
_buildBreakdownRow(
  context,
  context.l10n.gasCalculators_bestMix_densityLabel,
  '${result.densityGPerL.toStringAsFixed(1)} g/L',
),
if (result.exceedsCriticalDensity)
  Text(
    context.l10n.gasCalculators_bestMix_densityCritical(
      gasDensityCriticalGPerL.toStringAsFixed(1),
    ),
    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
  )
else if (result.exceedsWarnDensity)
  Text(
    context.l10n.gasCalculators_bestMix_densityWarn(
      gasDensityWarnGPerL.toStringAsFixed(1),
    ),
    style: textTheme.bodySmall?.copyWith(color: colorScheme.tertiary),
  ),
if (result.nearestStandardMix != null)
  _buildBreakdownRow(
    context,
    context.l10n.gasCalculators_bestMix_nearestStandard,
    result.nearestStandardMix!.name,
  ),
Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Text(
    context.l10n.gasCalculators_planningCaveat,
    textAlign: TextAlign.center,
    style: textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
  ),
),
```

Replace the depth slider with `UnitSlider` + `UnitAxis.depth(units)`, matching
Task 8.

If `best_mix_calculator.dart` has no `_buildBreakdownRow`, copy the one from
`rock_bottom_calculator.dart:549-584` verbatim.

Add imports:

```dart
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';
```

- [ ] **Step 5: Round MOD down in the MOD calculator**

In `mod_calculator.dart`, find where the MOD result is converted for display
and wrap it so it rounds toward the shallower, safer value:

```dart
final modGrid = settings.depthUnit == DepthUnit.meters ? 1.0 : 1.0;
final displayMod = roundDownTo(units.convertDepth(modMeters), modGrid);
```

Add:

```dart
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundDownTo;
```

Add the caveat line to the MOD result card using
`context.l10n.gasCalculators_planningCaveat`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/gas_calculators/`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/gas_calculators/ test/features/gas_calculators/
git commit -m "fix(gas): best mix reports its own MOD, END, and density"
```

---

### Task 11: Schema v137 — persist the WMO weather code

**Files:**
- Modify: `lib/core/database/database.dart` (Dives table ~line 703,
  `currentSchemaVersion` line 2849, `migrationVersions` list, `onUpgrade`
  ~line 7062, `beforeOpen` ~line 7082)
- Modify: `test/core/database/migration_v136_media_stores_sweep_test.dart:58`
- Test: `test/core/database/migration_v137_weather_code_test.dart`

**Interfaces:**
- Produces: `dives.weatherCode` (`IntColumn`, nullable, SQL column
  `weather_code`); `AppDatabase._assertWeatherCodeColumn()`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v137_weather_code_test.dart`.

This uses the codebase's real in-memory pattern, `AppDatabase(NativeDatabase.memory())`
(see `migration_v136_media_stores_sweep_test.dart:7`). There is **no**
`AppDatabase.forTesting()` constructor — do not add one.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v137 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(137));
    expect(AppDatabase.migrationVersions, contains(137));
  });

  test('a fresh database has dives.weather_code', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('weather_code'));
  });

  test('generated openMeteo descriptions are cleared, manual ones kept',
      () async {
    // A database stranded at the pre-v137 dives shape. Only the columns this
    // migration touches are modelled; the beforeOpen backstop must still add
    // weather_code, and the clear must spare manually entered text.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            weather_source TEXT,
            weather_description TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO dives (id, weather_source, weather_description) "
          "VALUES ('a', 'openMeteo', 'Clear, 24C, light breeze from North')",
        );
        rawDb.execute(
          "INSERT INTO dives (id, weather_source, weather_description) "
          "VALUES ('b', 'manual', 'Glassy, no wind')",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Touch the database so beforeOpen runs.
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    expect(
      cols.map((c) => c.read<String>('name')).toSet(),
      contains('weather_code'),
    );

    await db.clearGeneratedWeatherDescriptionsForTesting();

    final rows = await db
        .customSelect('SELECT id, weather_description FROM dives ORDER BY id')
        .get();
    expect(rows[0].data['weather_description'], isNull);
    expect(rows[1].data['weather_description'], 'Glassy, no wind');
  });
}
```

If the minimal `dives` fixture trips a foreign-key or NOT NULL constraint when
`AppDatabase` opens it, add only the columns the open path actually demands —
do not weaken the assertions. See memory note `fk-off` for why minimal fixtures
can mask insert-order problems.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v137_weather_code_test.dart`
Expected: FAIL — `currentSchemaVersion` is 136 and `weather_code` is absent.

- [ ] **Step 3: Add the column to the table definition**

In `database.dart`, in the Dives table weather block (after
`weatherFetchedAt`, ~line 705):

```dart
  /// Raw WMO weather code from the forecast provider. Retained so the
  /// description can be rendered in the diver's locale and units at display
  /// time rather than frozen as English prose at fetch time.
  IntColumn get weatherCode => integer().nullable()();
```

- [ ] **Step 4: Bump the version and add the migration**

Change line 2849:

```dart
  static const int currentSchemaVersion = 137;
```

Append to `migrationVersions`:

```dart
    // v137: dives.weather_code, plus a one-time clear of the English weather
    // prose we generated ourselves so it can be re-rendered localized.
    137,
```

Add the idempotent helper next to `_assertMediaStoresLastSweepColumn`
(~line 3885):

```dart
  /// Idempotent DDL for the v137 weather code column. Called from the v137
  /// onUpgrade step and the beforeOpen backstop, matching the
  /// _assertMediaStoreSchema pattern so a schema-version collision cannot
  /// strand a database without it.
  Future<void> _assertWeatherCodeColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('weather_code')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN weather_code INTEGER',
      );
    }
  }

  /// One-time clear of weather descriptions this app generated itself.
  ///
  /// Only rows whose weather_source is 'openMeteo' are touched -- those are the
  /// English, metric strings built by WeatherMapper. Manually entered and
  /// imported descriptions are user data and are left verbatim.
  Future<void> _clearGeneratedWeatherDescriptions() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    await customStatement(
      "UPDATE dives SET weather_description = NULL "
      "WHERE weather_source = 'openMeteo'",
    );
  }

  /// Test-only wrapper. The column assert is exercised through beforeOpen, but
  /// the one-time clear only runs on upgrade, so it needs a direct handle.
  Future<void> clearGeneratedWeatherDescriptionsForTesting() =>
      _clearGeneratedWeatherDescriptions();
```

In `onUpgrade`, after the v136 block (~line 7065):

```dart
        // v137: dives.weather_code + clear self-generated English weather prose.
        if (from < 137) {
          await _assertWeatherCodeColumn();
          await _clearGeneratedWeatherDescriptions();
        }
        if (from < 137) await reportProgress();
```

In `beforeOpen`, after the v136 backstop (~line 7082):

```dart
        // v137 backstop: re-assert the weather code column.
        await _assertWeatherCodeColumn();
```

- [ ] **Step 5: Relax the superseded v136 tripwire**

In `test/core/database/migration_v136_media_stores_sweep_test.dart:58`, change:

```dart
    expect(AppDatabase.currentSchemaVersion, 136);
```

to:

```dart
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(136));
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `DiveData` gains a `weatherCode` field.

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
flutter test test/core/database/migration_v137_weather_code_test.dart test/core/database/migration_v136_media_stores_sweep_test.dart
```
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart test/core/database/
git commit -m "feat(db): v137 adds dives.weather_code and clears generated prose"
```

---

### Task 12: Weather entity, mapper, and repository plumbing

**Files:**
- Modify: `lib/features/weather/domain/entities/weather_data.dart`
- Modify: `lib/features/weather/data/services/weather_mapper.dart`
- Modify: `lib/features/weather/data/repositories/weather_repository.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (add `weatherCode`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Test: `test/features/weather/data/services/weather_mapper_test.dart` (modify)

**Interfaces:**
- Produces: `WeatherData.weatherCode` (`int?`); `Dive.weatherCode` (`int?`).
  `WeatherMapper.buildDescription` is **deleted**;
  `WeatherMapper.mapApiResponse` returns `description: null`.

- [ ] **Step 1: Update the mapper test**

In `test/features/weather/data/services/weather_mapper_test.dart`, delete every
`buildDescription` group and add:

```dart
  group('mapApiResponse weather code', () {
    test('retains the raw WMO code', () {
      final data = WeatherMapper.mapApiResponse(
        {
          'time': ['2026-07-26T12:00'],
          'temperature_2m': [24.0],
          'weathercode': [61],
          'wind_speed_10m': [10.0],
          'cloud_cover': [10.0],
        },
        targetHour: DateTime.parse('2026-07-26T12:00'),
      );
      expect(data.weatherCode, 61);
    });

    test('does not generate an English description', () {
      final data = WeatherMapper.mapApiResponse(
        {
          'time': ['2026-07-26T12:00'],
          'temperature_2m': [24.0],
          'weathercode': [0],
          'wind_speed_10m': [10.0],
          'cloud_cover': [10.0],
        },
        targetHour: DateTime.parse('2026-07-26T12:00'),
      );
      // Prose is rendered at display time so it follows locale and units.
      expect(data.description, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/weather/data/services/weather_mapper_test.dart`
Expected: FAIL — `weatherCode` is not a member of `WeatherData`.

- [ ] **Step 3: Add the field to WeatherData**

In `weather_data.dart`, add `final int? weatherCode;` alongside the other
fields, add `this.weatherCode,` to the constructor, and add `weatherCode` to
the `props` list.

- [ ] **Step 4: Update the mapper**

In `weather_mapper.dart`:
- Delete `buildDescription` (lines 77-111) and `_windDescription` (lines
  186-192) entirely.
- In `mapApiResponse`, change the returned `WeatherData` to pass
  `weatherCode: weatherCode` and `description: null`.

- [ ] **Step 5: Thread the field through the domain entity and repository**

Add `final int? weatherCode;` to `Dive` (next to `weatherDescription`),
including its constructor parameter, `copyWith`, and `props`. Then update
`dive_repository_impl.dart` at the two write sites (`:1009`, `:1250`) and the
two read sites (`:2999`, `:3370`) to carry `weatherCode`. Find them with:

Run: `grep -n "weatherDescription" lib/features/dive_log/data/repositories/dive_repository_impl.dart`

Mirror whatever the neighbouring `weatherDescription` line does at each site.

Also update `weather_repository.dart` to persist `weatherCode` wherever it
currently persists `description`.

- [ ] **Step 6: Regenerate and run tests**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/weather/ test/features/dive_log/domain/entities/dive_weather_test.dart
```
Expected: PASS. If `dive_weather_test.dart` asserts an exact `props` length,
increment it — that is an intentional change, not a regression.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/weather/ lib/features/dive_log/ test/features/weather/ test/features/dive_log/
git commit -m "feat(weather): keep the WMO code and stop generating English prose"
```

---

### Task 13: Localized weather description builder

**Files:**
- Create: `lib/features/weather/presentation/widgets/weather_description_builder.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/weather/presentation/weather_description_builder_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations`, `UnitFormatter`, `WeatherData`.
- Produces:
  `String? buildLocalizedWeatherDescription({required AppLocalizations l10n, required UnitFormatter units, int? weatherCode, CloudCover? cloudCover, double? airTempCelsius, double? windSpeedMs, CurrentDirection? windDirection, Precipitation? precipitation, String? storedDescription})`
  and `String? wmoCodeLabel(AppLocalizations l10n, int? code)`.

- [ ] **Step 1: Add the WMO ARB keys**

Add to `lib/l10n/arb/app_en.arb`. WMO codes collapse into these 15 groups:

```json
  "weather_wmo_clear": "Clear sky",
  "weather_wmo_mainlyClear": "Mainly clear",
  "weather_wmo_partlyCloudy": "Partly cloudy",
  "weather_wmo_overcast": "Overcast",
  "weather_wmo_fog": "Fog",
  "weather_wmo_drizzle": "Drizzle",
  "weather_wmo_freezingDrizzle": "Freezing drizzle",
  "weather_wmo_rain": "Rain",
  "weather_wmo_freezingRain": "Freezing rain",
  "weather_wmo_snow": "Snow",
  "weather_wmo_snowGrains": "Snow grains",
  "weather_wmo_rainShowers": "Rain showers",
  "weather_wmo_snowShowers": "Snow showers",
  "weather_wmo_thunderstorm": "Thunderstorm",
  "weather_wmo_thunderstormHail": "Thunderstorm with hail",
  "weather_wind_calm": "calm",
  "weather_wind_lightBreeze": "light breeze",
  "weather_wind_moderateBreeze": "moderate breeze",
  "weather_wind_strongBreeze": "strong breeze",
  "weather_wind_highWind": "high wind",
  "weather_windFromDirection": "{wind} from {direction}",
  "@weather_windFromDirection": {
    "placeholders": { "wind": { "type": "Object" }, "direction": { "type": "Object" } }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/weather/presentation/weather_description_builder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/widgets/weather_description_builder.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<AppLocalizations> _l10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('renders the WMO code label in English', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    expect(wmoCodeLabel(l10n, 0), 'Clear sky');
    expect(wmoCodeLabel(l10n, 61), 'Rain');
    expect(wmoCodeLabel(l10n, 95), 'Thunderstorm');
    expect(wmoCodeLabel(l10n, null), isNull);
  });

  testWidgets('converts temperature to the diver unit', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));

    final metric = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: const UnitFormatter(AppSettings()),
      weatherCode: 0,
      airTempCelsius: 24,
    );
    expect(metric, contains('24'));

    final imperial = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: const UnitFormatter(
        AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
      ),
      weatherCode: 0,
      airTempCelsius: 24,
    );
    // The old build hardcoded "24C" regardless of the diver's setting.
    expect(imperial, contains('75'));
    expect(imperial, isNot(contains('24C')));
  });

  testWidgets('a stored description wins over generated text', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: const UnitFormatter(AppSettings()),
      weatherCode: 0,
      storedDescription: 'Glassy, no wind',
    );
    expect(result, 'Glassy, no wind');
  });

  testWidgets('falls back to cloud cover when no code is present',
      (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    final result = buildLocalizedWeatherDescription(
      l10n: l10n,
      units: const UnitFormatter(AppSettings()),
      cloudCover: CloudCover.clear,
    );
    expect(result, isNotNull);
  });

  testWidgets('returns null when there is nothing to say', (tester) async {
    final l10n = await _l10n(tester, const Locale('en'));
    expect(
      buildLocalizedWeatherDescription(
        l10n: l10n,
        units: const UnitFormatter(AppSettings()),
      ),
      isNull,
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/weather/presentation/weather_description_builder_test.dart`
Expected: FAIL — "Target of URI doesn't exist".

- [ ] **Step 4: Write the implementation**

Create `lib/features/weather/presentation/widgets/weather_description_builder.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for a WMO weather code.
///
/// Open-Meteo returns only this numeric code -- it has no language parameter
/// and returns no prose. Mapping it here means the description follows the
/// diver's locale instead of being frozen in English at fetch time.
String? wmoCodeLabel(AppLocalizations l10n, int? code) {
  if (code == null) return null;
  if (code == 0) return l10n.weather_wmo_clear;
  if (code == 1) return l10n.weather_wmo_mainlyClear;
  if (code == 2) return l10n.weather_wmo_partlyCloudy;
  if (code == 3) return l10n.weather_wmo_overcast;
  if (code == 45 || code == 48) return l10n.weather_wmo_fog;
  if (code >= 51 && code <= 55) return l10n.weather_wmo_drizzle;
  if (code == 56 || code == 57) return l10n.weather_wmo_freezingDrizzle;
  if (code >= 61 && code <= 65) return l10n.weather_wmo_rain;
  if (code == 66 || code == 67) return l10n.weather_wmo_freezingRain;
  if (code >= 71 && code <= 75) return l10n.weather_wmo_snow;
  if (code == 77) return l10n.weather_wmo_snowGrains;
  if (code >= 80 && code <= 82) return l10n.weather_wmo_rainShowers;
  if (code == 85 || code == 86) return l10n.weather_wmo_snowShowers;
  if (code == 95) return l10n.weather_wmo_thunderstorm;
  if (code == 96 || code == 99) return l10n.weather_wmo_thunderstormHail;
  return null;
}

String _windLabel(AppLocalizations l10n, double ms) {
  if (ms < 0.5) return l10n.weather_wind_calm;
  if (ms < 3.4) return l10n.weather_wind_lightBreeze;
  if (ms < 8.0) return l10n.weather_wind_moderateBreeze;
  if (ms < 13.9) return l10n.weather_wind_strongBreeze;
  return l10n.weather_wind_highWind;
}

/// Build a weather description in the diver's locale and units.
///
/// A [storedDescription] -- text the diver typed or that arrived with an import
/// -- is user data and is returned verbatim. Everything else is rendered fresh
/// so it tracks the current locale and unit settings.
String? buildLocalizedWeatherDescription({
  required AppLocalizations l10n,
  required UnitFormatter units,
  int? weatherCode,
  CloudCover? cloudCover,
  double? airTempCelsius,
  double? windSpeedMs,
  CurrentDirection? windDirection,
  Precipitation? precipitation,
  String? storedDescription,
}) {
  if (storedDescription != null && storedDescription.isNotEmpty) {
    return storedDescription;
  }

  final parts = <String>[];

  final coded = wmoCodeLabel(l10n, weatherCode);
  if (coded != null) {
    parts.add(coded);
  } else if (cloudCover != null) {
    parts.add(cloudCover.localizedName(l10n));
  }

  if (airTempCelsius != null) {
    parts.add(units.formatTemperature(airTempCelsius));
  }

  if (windSpeedMs != null && windSpeedMs > 0) {
    final wind = _windLabel(l10n, windSpeedMs);
    if (windDirection != null && windDirection != CurrentDirection.none) {
      parts.add(
        l10n.weather_windFromDirection(
          wind,
          windDirection.localizedName(l10n),
        ),
      );
    } else {
      parts.add(wind);
    }
  }

  if (coded == null &&
      precipitation != null &&
      precipitation != Precipitation.none) {
    parts.add(precipitation.localizedName(l10n));
  }

  return parts.isEmpty ? null : parts.join(', ');
}
```

`CloudCover`, `Precipitation`, and `CurrentDirection` all expose
`String localizedName(AppLocalizations l10n)` via extensions in
`lib/features/dive_log/presentation/widgets/environment_enum_display.dart`
(verified). Import that file to bring the extensions into scope.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/weather/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/weather/ lib/l10n/arb/ test/features/weather/
git commit -m "feat(weather): render descriptions from the WMO code at display time"
```

---

### Task 14: Detail-page unit fixes and the localized description

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:3024-3066, 3105-3110`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart:1344`
- Test: `test/features/dive_log/presentation/dive_detail_weather_units_test.dart`

**Interfaces:**
- Produces: `UnitFormatter.formatSurfacePressure(double? bar)` and
  `UnitFormatter.surfacePressureSymbol`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/dive_detail_weather_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  group('formatSurfacePressure', () {
    test('metric renders mbar', () {
      const units = UnitFormatter(AppSettings());
      expect(units.formatSurfacePressure(1.013), '1013 mbar');
    });

    test('imperial renders inHg', () {
      const units = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
      // 1.013 bar = 29.91 inHg.
      final text = units.formatSurfacePressure(1.013);
      expect(text, contains('inHg'));
      expect(text, contains('29.9'));
    });

    test('null renders the placeholder', () {
      const units = UnitFormatter(AppSettings());
      expect(units.formatSurfacePressure(null), '--');
    });
  });

  group('swell height uses the depth unit', () {
    test('imperial converts meters to feet', () {
      const units = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
      // 0.91 m entered as 3 ft must read back as 3 ft, not "0.9m".
      expect(units.formatDepth(0.9144, decimals: 1), '3.0ft');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/dive_detail_weather_units_test.dart`
Expected: FAIL — `formatSurfacePressure` is not defined.

- [ ] **Step 3: Add the formatter**

In `unit_formatter.dart`, in the Altitude section next to
`formatBarometricPressureMbar`:

```dart
  /// Barometric pressure symbol. Metric divers expect mbar, imperial divers
  /// expect inHg. Derived from the depth unit, consistent with wind speed --
  /// the tank pressure unit (bar/psi) is a different quantity.
  String get surfacePressureSymbol =>
      settings.depthUnit == DepthUnit.meters ? 'mbar' : 'inHg';

  /// Inches of mercury per bar.
  static const double _inHgPerBar = 29.5300;

  /// Format a surface/barometric pressure stored in bar.
  String formatSurfacePressure(double? bar) {
    if (bar == null) return '--';
    if (settings.depthUnit == DepthUnit.meters) {
      return '${(bar * 1000).toStringAsFixed(0)} $surfacePressureSymbol';
    }
    return '${(bar * _inHgPerBar).toStringAsFixed(2)} $surfacePressureSymbol';
  }
```

- [ ] **Step 4: Fix the detail page**

In `dive_detail_page.dart`:

Replace line 3028:

```dart
                  '${(dive.surfacePressure! * 1000).toStringAsFixed(0)} mbar',
```

with:

```dart
                  units.formatSurfacePressure(dive.surfacePressure),
```

Replace the swell height value (~line 3108):

```dart
                  '${dive.swellHeight!.toStringAsFixed(1)}m',
```

with:

```dart
                  units.formatDepth(dive.swellHeight, decimals: 1),
```

Replace the weather description row (lines 3060-3066) so it renders localized:

```dart
              Builder(
                builder: (context) {
                  final description = buildLocalizedWeatherDescription(
                    l10n: context.l10n,
                    units: units,
                    weatherCode: dive.weatherCode,
                    cloudCover: dive.cloudCover,
                    airTempCelsius: dive.airTemp,
                    windSpeedMs: dive.windSpeed,
                    windDirection: dive.windDirection,
                    precipitation: dive.precipitation,
                    storedDescription:
                        dive.weatherSource == WeatherSource.openMeteo
                        ? null
                        : dive.weatherDescription,
                  );
                  if (description == null) return const SizedBox.shrink();
                  return _buildDetailRow(
                    context,
                    context.l10n.diveLog_detail_label_weatherDescription,
                    description,
                  );
                },
              ),
```

Add the import:

```dart
import 'package:submersion/features/weather/presentation/widgets/weather_description_builder.dart';
```

- [ ] **Step 5: Add the missing suffix on the phone swell input**

In `dive_edit_page.dart:1344`, add `suffixText: units.depthSymbol,` to the
`FormRow.text` for swell height, matching its desktop twin at `:3531`. If
`units` is not in scope in that builder, obtain it the same way the
neighbouring rows do.

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
flutter test test/features/dive_log/presentation/dive_detail_weather_units_test.dart test/core/utils/
```
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/utils/unit_formatter.dart lib/features/dive_log/ test/features/dive_log/
git commit -m "fix(units): surface pressure and swell height follow diver units"
```

---

### Task 15: Localize the CNS/O2 card

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`
- Test: `test/features/dive_log/presentation/widgets/o2_toxicity_card_l10n_test.dart`

**Interfaces:**
- Produces ARB keys: `o2Toxicity_thisDive`, `o2Toxicity_daily`,
  `o2Toxicity_weekly`, `o2Toxicity_start`, `o2Toxicity_prior`,
  `o2Toxicity_addedThisDive`, `o2Toxicity_cnsProgressSemantics`,
  `o2Toxicity_otuSemantics`, `o2Toxicity_maxPpO2Depth`,
  `formatter_duration_seconds`, `formatter_duration_minutes`,
  `formatter_duration_minutesSeconds`.

- [ ] **Step 1: Add the ARB keys**

```json
  "o2Toxicity_thisDive": "This Dive",
  "o2Toxicity_daily": "Daily",
  "o2Toxicity_weekly": "Weekly",
  "o2Toxicity_start": "Start: {value} OTU",
  "@o2Toxicity_start": {
    "placeholders": { "value": { "type": "Object" } }
  },
  "o2Toxicity_prior": "Prior: {value} OTU",
  "@o2Toxicity_prior": {
    "placeholders": { "value": { "type": "Object" } }
  },
  "o2Toxicity_addedThisDive": "+{value} this dive",
  "@o2Toxicity_addedThisDive": {
    "placeholders": { "value": { "type": "Object" } }
  },
  "o2Toxicity_cnsProgressSemantics": "CNS progress {percent} percent",
  "@o2Toxicity_cnsProgressSemantics": {
    "placeholders": { "percent": { "type": "Object" } }
  },
  "o2Toxicity_otuSemantics": "{label}: {value} of {limit} OTU, {percent} percent",
  "@o2Toxicity_otuSemantics": {
    "placeholders": { "label": { "type": "Object" }, "value": { "type": "Object" }, "limit": { "type": "Object" }, "percent": { "type": "Object" } }
  },
  "o2Toxicity_maxPpO2Depth": "Max ppO2 depth",
  "formatter_duration_seconds": "{seconds}s",
  "@formatter_duration_seconds": {
    "placeholders": { "seconds": { "type": "Object" } }
  },
  "formatter_duration_minutes": "{minutes}m",
  "@formatter_duration_minutes": {
    "placeholders": { "minutes": { "type": "Object" } }
  },
  "formatter_duration_minutesSeconds": "{minutes}m {seconds}s",
  "@formatter_duration_minutesSeconds": {
    "placeholders": { "minutes": { "type": "Object" }, "seconds": { "type": "Object" } }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/o2_toxicity_card_l10n_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the O2 toxicity card has no hardcoded English display strings', () {
    final source = File(
      'lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart',
    ).readAsStringSync();

    const banned = [
      "'This Dive'",
      "'Daily'",
      "'Weekly'",
      "'Start: ",
      "'Prior: ",
      "this dive'",
    ];
    for (final phrase in banned) {
      expect(
        source.contains(phrase),
        isFalse,
        reason: '$phrase must come from ARB, not a literal',
      );
    }
  });

  test('max ppO2 depth is not hardcoded to meters', () {
    final source = File(
      'lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart',
    ).readAsStringSync();
    expect(
      source.contains("maxPpO2Depth.toStringAsFixed(1)}m'"),
      isFalse,
      reason: 'depth must go through UnitFormatter.formatDepth',
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/o2_toxicity_card_l10n_test.dart`
Expected: FAIL on several banned phrases.

- [ ] **Step 4: Replace the literals**

In `o2_toxicity_card.dart`, replace each hardcoded string with its ARB getter.
Locate them with:

Run:
```bash
grep -nE "'(This Dive|Daily|Weekly)'|'Start: |'Prior: |this dive'|CNS progress " lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart
```

Replace, in order:
- `:150` -> `context.l10n.o2Toxicity_cnsProgressSemantics(exposure.cnsEnd.toStringAsFixed(0))`
- `:215`, `:747` -> `context.l10n.o2Toxicity_thisDive` / `context.l10n.o2Toxicity_daily`
- `:225`, `:238`, `:762` -> `context.l10n.o2Toxicity_daily` / `context.l10n.o2Toxicity_weekly`
- `:754` -> `context.l10n.o2Toxicity_start(exposure.otuStart.toStringAsFixed(0))`
- `:769` -> `context.l10n.o2Toxicity_prior(weeklyPrior.toStringAsFixed(0))`
- `:846` -> `context.l10n.o2Toxicity_addedThisDive(thisDive.toStringAsFixed(0))`
- `:289-290`, `:801-803` -> `context.l10n.o2Toxicity_otuSemantics(...)`

At `:354`, replace:

```dart
            '${exposure.maxPpO2Depth.toStringAsFixed(1)}m',
```

with:

```dart
            units.formatDepth(exposure.maxPpO2Depth, decimals: 1),
```

If a `UnitFormatter` is not already in scope there, obtain it the same way the
surrounding code does — check with
`grep -n "UnitFormatter\|settingsProvider" lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart | head`.

Update both `_formatDuration` implementations (`:425-429`, `:1046-1050`) to
take an `AppLocalizations` argument and use the three duration keys. Update
their call sites at `:1016` and `:1030`.

**Leave ppO2 in bar** at `:939` — that is a physics unit and is correct as is.

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
flutter test test/features/dive_log/presentation/widgets/o2_toxicity_card_l10n_test.dart test/features/dive_log/presentation/widgets/compact_o2_toxicity_panel_test.dart
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart lib/l10n/arb/ test/features/dive_log/
git commit -m "fix(l10n): localize the CNS/O2 card and convert max ppO2 depth"
```

---

### Task 16: Translate all locales and regenerate

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`,
  `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`,
  `app_zh.arb`
- Test: `test/l10n/arb_parity_test.dart`

**Interfaces:**
- Consumes: every key added in Tasks 7, 13, and 15.

- [ ] **Step 1: List the keys needing translation**

Run:
```bash
python3 - <<'PY'
import json, glob, os
en = json.load(open('lib/l10n/arb/app_en.arb'))
en_keys = {k for k in en if not k.startswith('@')}
for path in sorted(glob.glob('lib/l10n/arb/app_*.arb')):
    if path.endswith('app_en.arb'):
        continue
    d = json.load(open(path))
    missing = sorted(en_keys - {k for k in d if not k.startswith('@')})
    print(os.path.basename(path), len(missing))
    for k in missing:
        print('   ', k, '=>', json.dumps(en[k]))
PY
```

- [ ] **Step 2: Write the parity test**

Create `test/l10n/arb_parity_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale defines every English key', () {
    final dir = Directory('lib/l10n/arb');
    final en =
        jsonDecode(File('${dir.path}/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();

    final failures = <String>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb') || file.path.endsWith('app_en.arb')) {
        continue;
      }
      final data =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final keys = data.keys.where((k) => !k.startsWith('@')).toSet();
      final missing = enKeys.difference(keys);
      if (missing.isNotEmpty) {
        failures.add('${file.uri.pathSegments.last}: ${missing.length} missing');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/l10n/arb_parity_test.dart`
Expected: FAIL listing all 10 locales with their missing counts.

- [ ] **Step 4: Translate**

Add every missing key to each of the 10 locale files, translated into that
language. Keep placeholder names identical to English (`{depth}`, `{unit}`,
`{value}`, `{percent}`, `{limit}`, `{ppO2}`, `{wind}`, `{direction}`,
`{minutes}`, `{seconds}`, `{label}`). Do **not** copy `@key` metadata blocks
into non-English files — only `app_en.arb` carries them.

Unit symbols (`g/L`, `OTU`, `bar`, `min`, `mbar`, `inHg`) stay untranslated.

For `he` and `ar`, the text is right-to-left; placeholders keep their names but
may be reordered within the sentence as the language requires.

- [ ] **Step 5: Verify parity and regenerate**

Run:
```bash
flutter test test/l10n/arb_parity_test.dart
flutter gen-l10n
```
Expected: PASS, then generation completes with no missing-translation warnings.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/l10n/ test/l10n/
git commit -m "feat(l10n): translate gas calculator, weather, and CNS keys"
```

---

### Task 17: Full-suite verification

**Files:** none modified unless a regression surfaces.

- [ ] **Step 1: Run the whole suite**

Run: `flutter test`
Expected: PASS. The pre-change baseline on this worktree was
**14156 passed, 15 skipped, 0 failures** — anything below that is a regression
introduced by this branch.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: no issues. Never pipe this through `tail` — that masks the exit code.

- [ ] **Step 3: Confirm formatting is clean**

Run: `dart format --set-exit-if-changed .`
Expected: exit 0.

- [ ] **Step 4: Confirm the schema number is still free**

Run:
```bash
git fetch origin main --quiet
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```
Expected: 136. If main has advanced to 137 or beyond, renumber this branch's
migration above it and relax the newly superseded tripwire, per the
schema-ladder convention.

- [ ] **Step 5: Fix any regression and re-run**

If a test outside the touched areas fails, fix it before proceeding. Do not
weaken an assertion to make it pass — if a test's expectation is genuinely
obsolete because of an intentional change (for example a `props` length), update
it and say so in the commit message.

- [ ] **Step 6: Commit any fixes**

```bash
dart format .
git add -A
git commit -m "test: fix regressions surfaced by the full suite"
```

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Task |
| --- | --- |
| R1 SAC never converts / off-scale range | 1, 2, 8, 9 |
| R2 tank chips store free gas as water capacity | 3, 8, 9 |
| R2b hardcoded 200 bar fill | 5, 9 |
| R3 ascent-rate bounds metric-native | 1, 8 |
| R4 Best Mix buckets upward | 6, 10 |
| R5 weather prose English/metric/persisted | 11, 12, 13, 14 |
| R6 hardcoded metric displays | 14, 15 |
| R7 CNS card strings not in ARB | 15 |
| D1 UnitAxis | 1 |
| D2 TankSpec | 3 |
| D3 pure domain layer | 4, 5, 6 |
| D4 rock bottom four-phase model | 4, 8 |
| D5 best mix planner | 6, 10 |
| D6 precision and caveats | 5, 7, 8, 9, 10 |
| D7 weather schema v137 + builder | 11, 12, 13 |
| D8 read-only display fixes | 14 |
| D9 CNS localization | 15 |
| l10n all locales | 16 |

No gaps.

**2. Placeholder scan**

No "TBD", "TODO", or "similar to Task N" instructions. Every code step carries
real code.

Three earlier drafts of this plan asked the implementer to go verify a pattern.
All three were resolved against the codebase while writing, and two of them had
been guessed wrong:

- `SettingsNotifier.forTest(...)` **does not exist**. The real pattern is a
  `StateNotifier<AppSettings> implements SettingsNotifier` subclass with
  `noSuchMethod`, per `dive_comparison_card_test.dart:22-32`. Tasks 8, 9, and 10
  now carry that verbatim.
- `AppDatabase.forTesting()` **does not exist**. The real pattern is
  `AppDatabase(NativeDatabase.memory())`, with `NativeDatabase.memory(setup:)`
  for stranded-schema fixtures, per `migration_v136_media_stores_sweep_test.dart:7`.
  Task 11 now carries that.
- `localizedName(AppLocalizations l10n)` was confirmed correct as written.

Only Task 12 Step 5 still directs a `grep` before editing, and that is to locate
four call sites by line number rather than to discover an unknown API.

**3. Type consistency**

- `TankSpec` fields `waterVolumeLiters` / `workingPressureBar` /
  `ratedCapacityCuft` / `label` are used identically in Tasks 3, 4, 5, 8, 9.
- `RockBottomResult.reserveBar` (not `totalBar`) is used consistently in Tasks
  4 and 8. The old provider's `totalBar` name is gone.
- `ConsumptionResult.litersConsumed` / `barConsumed` (not `liters` / `bar`) are
  used consistently in Tasks 5 and 9; Task 9 Step 4 explicitly calls out the
  rename at the call sites.
- `roundUpTo` / `roundDownTo` are defined once in Task 5 and imported by Tasks
  6, 8, 9, 10.
- `ambientPressureAtDepth` is defined once in Task 4 and imported by Tasks 5
  and 6.
- `computeBestMix` returns `BestMixResult` with `mix`, `modMeters`,
  `marginMeters`, `endMeters`, `densityGPerL`, `nearestStandardMix` — all used
  under those exact names in Task 10.
- `GasMix.heForMnd(targetMnd, o2, {endLimit, o2Narcotic})` matches the real
  signature at `dive.dart:1119`.
- `gasDensityGPerL({fO2, fHe, ambientPressureBar})` matches the real signature
  at `gas_density.dart:25`.
