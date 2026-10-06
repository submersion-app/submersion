# MND (Maximum Narcotic Depth) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add MND calculation to GasMix, display it in tank editor and gas calculators, with configurable O2 narcotic and END limit settings.

**Architecture:** Extend `GasMix` class with `mnd()`, `heForMnd()`, and update `end()` to support an `o2Narcotic` flag. Add two new diver settings (`o2Narcotic`, `endLimit`) persisted via Drift. Wire into tank editor (bidirectional) and a new MND/END calculator tab.

**Tech Stack:** Flutter, Drift ORM, Riverpod, go_router, l10n ARB files

---

## Task 1: Add `mnd()` and update `end()` on GasMix

**Files:**

- Modify: `lib/features/dive_log/domain/entities/dive.dart:848-882`
- Test: `test/features/dive_log/domain/entities/gas_mix_test.dart` (create)

**Step 1: Write failing tests for `mnd()` and updated `end()`**

Create `test/features/dive_log/domain/entities/gas_mix_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('GasMix.mnd', () {
    test('air with O2 narcotic returns depth equal to END limit', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      // For air (no He), MND = endLimit when O2 is narcotic
      // narcoticFraction = (100 - 0) / 100 = 1.0
      // targetPressure = (30 / 10) + 1 = 4.0
      // maxPressure = 4.0 / 1.0 = 4.0
      // MND = (4.0 - 1) * 10 = 30.0
      expect(air.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('trimix Tx 21/35 with O2 narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      // narcoticFraction = (100 - 35) / 100 = 0.65
      // targetPressure = (30 / 10) + 1 = 4.0
      // maxPressure = 4.0 / 0.65 = 6.1538
      // MND = (6.1538 - 1) * 10 = 51.5
      expect(tx2135.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(51.5, 0.5));
    });

    test('trimix Tx 21/35 with O2 NOT narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      // n2 = 100 - 21 - 35 = 44, n2Fraction = 0.44
      // targetPressure = (30 / 10) + 1 = 4.0
      // maxPressure = 4.0 * 0.79 / 0.44 = 7.1818
      // MND = (7.1818 - 1) * 10 = 61.8
      expect(
        tx2135.mnd(endLimit: 30.0, o2Narcotic: false),
        closeTo(61.8, 0.5),
      );
    });

    test('EAN32 with O2 narcotic', () {
      const ean32 = GasMix(o2: 32.0, he: 0.0);
      // narcoticFraction = 1.0 (no He)
      // MND = endLimit = 30.0
      expect(ean32.mnd(endLimit: 30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('EAN32 with O2 NOT narcotic', () {
      const ean32 = GasMix(o2: 32.0, he: 0.0);
      // n2 = 68, n2Fraction = 0.68
      // targetPressure = 4.0
      // maxPressure = 4.0 * 0.79 / 0.68 = 4.647
      // MND = (4.647 - 1) * 10 = 36.5
      expect(
        ean32.mnd(endLimit: 30.0, o2Narcotic: false),
        closeTo(36.5, 0.5),
      );
    });

    test('pure O2/He mix with O2 NOT narcotic returns infinity', () {
      const heliox = GasMix(o2: 21.0, he: 79.0);
      // n2 = 0 -> infinite MND
      expect(
        heliox.mnd(endLimit: 30.0, o2Narcotic: false),
        double.infinity,
      );
    });

    test('defaults to endLimit 30 and o2Narcotic true', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      expect(air.mnd(), closeTo(30.0, 0.1));
    });
  });

  group('GasMix.end with o2Narcotic flag', () {
    test('air at 30m with O2 narcotic', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      // narcoticFraction = 1.0, ambient = 4.0
      // END = (4.0 * 1.0 - 1) * 10 = 30.0
      expect(air.end(30.0, o2Narcotic: true), closeTo(30.0, 0.1));
    });

    test('trimix Tx 21/35 at 60m with O2 narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      // narcoticFraction = 0.65, ambient = 7.0
      // END = (7.0 * 0.65 - 1) * 10 = 35.5
      expect(tx2135.end(60.0, o2Narcotic: true), closeTo(35.5, 0.5));
    });

    test('trimix Tx 21/35 at 60m with O2 NOT narcotic', () {
      const tx2135 = GasMix(o2: 21.0, he: 35.0);
      // n2Fraction = 0.44, ambient = 7.0
      // END = (7.0 * 0.44 / 0.79 - 1) * 10 = 28.99
      expect(tx2135.end(60.0, o2Narcotic: false), closeTo(29.0, 0.5));
    });

    test('backward compatible - defaults to o2Narcotic true', () {
      const air = GasMix(o2: 21.0, he: 0.0);
      // Same as current behavior
      expect(air.end(30.0), closeTo(30.0, 0.1));
    });
  });

  group('GasMix.heForMnd', () {
    test('calculates He needed for MND 50m with O2 21% (O2 narcotic)', () {
      // targetMnd = 50, o2 = 21
      // targetPressure = (30 / 10) + 1 = 4.0 (default endLimit 30)
      // maxPressure = (50 / 10) + 1 = 6.0
      // narcoticFraction = targetPressure / maxPressure = 4.0 / 6.0 = 0.667
      // he = (1 - 0.667) * 100 = 33.3
      final he = GasMix.heForMnd(50.0, 21.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, closeTo(33.3, 0.5));
    });

    test('returns 0 when target MND <= END limit (no He needed)', () {
      final he = GasMix.heForMnd(25.0, 21.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, 0.0);
    });

    test('clamps to max He when target unreachable', () {
      // Very deep MND with high O2 -> He can't exceed (100 - O2)
      final he = GasMix.heForMnd(200.0, 50.0, endLimit: 30.0, o2Narcotic: true);
      expect(he, 50.0); // max = 100 - 50
    });
  });
}
```text
**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/entities/gas_mix_test.dart`
Expected: FAIL (methods don't exist yet)

**Step 3: Implement `mnd()`, update `end()`, add `heForMnd()`**

In `lib/features/dive_log/domain/entities/dive.dart`, replace the existing `end()` method (lines 873-878) and add new methods to `GasMix`:

```dart
/// Equivalent Narcotic Depth at given depth.
///
/// When [o2Narcotic] is true, all gases except He are narcotic.
/// When false, only N2 is narcotic (compared against air baseline 0.79).
double end(double depth, {bool o2Narcotic = true}) {
  final ambientPressure = (depth / 10) + 1;
  if (o2Narcotic) {
    final narcoticFraction = (100.0 - he) / 100.0;
    return ((ambientPressure * narcoticFraction) - 1) * 10;
  } else {
    final n2Fraction = n2 / 100.0;
    return ((ambientPressure * n2Fraction / 0.79) - 1) * 10;
  }
}

/// Maximum Narcotic Depth for this gas at a given END limit.
///
/// Returns the deepest depth where the narcotic effect stays
/// at or below [endLimit] meters equivalent.
double mnd({double endLimit = 30.0, bool o2Narcotic = true}) {
  final targetPressure = (endLimit / 10) + 1;
  if (o2Narcotic) {
    final narcoticFraction = (100.0 - he) / 100.0;
    if (narcoticFraction <= 0) return double.infinity;
    final maxPressure = targetPressure / narcoticFraction;
    return (maxPressure - 1) * 10;
  } else {
    final n2Fraction = n2 / 100.0;
    if (n2Fraction <= 0) return double.infinity;
    final maxPressure = targetPressure * 0.79 / n2Fraction;
    return (maxPressure - 1) * 10;
  }
}

/// Calculate He% needed to achieve a target MND at a given O2%.
///
/// Returns He percentage (0-100), clamped to valid range.
static double heForMnd(
  double targetMnd,
  double o2, {
  double endLimit = 30.0,
  bool o2Narcotic = true,
}) {
  final targetPressure = (endLimit / 10) + 1;
  final maxPressure = (targetMnd / 10) + 1;

  double he;
  if (o2Narcotic) {
    // narcoticFraction = targetPressure / maxPressure
    // he = (1 - narcoticFraction) * 100
    final narcoticFraction = targetPressure / maxPressure;
    he = (1 - narcoticFraction) * 100;
  } else {
    // n2Fraction = targetPressure * 0.79 / maxPressure
    // he = 100 - o2 - (n2Fraction * 100)
    final n2Fraction = targetPressure * 0.79 / maxPressure;
    he = 100 - o2 - (n2Fraction * 100);
  }

  final maxHe = 100 - o2;
  if (he < 0) return 0.0;
  if (he > maxHe) return maxHe;
  return he;
}
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/entities/gas_mix_test.dart`
Expected: ALL PASS

**Step 5: Run analyzer**

Run: `flutter analyze lib/features/dive_log/domain/entities/dive.dart`
Expected: No issues

**Step 6: Commit**

```bash
git add test/features/dive_log/domain/entities/gas_mix_test.dart lib/features/dive_log/domain/entities/dive.dart
git commit -m "feat: add MND calculation and o2Narcotic flag to GasMix"
```text
---

## Task 2: Add `o2Narcotic` and `endLimit` settings (database + AppSettings + repository)

**Files:**

- Modify: `lib/core/database/database.dart` (DiverSettings table, ~line 566)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (AppSettings class, SettingsNotifier)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`

**Step 1: Add database columns**

In `lib/core/database/database.dart`, in the `DiverSettings` table class, after `decoStopIncrement` (line 567):

```dart
BoolColumn get o2Narcotic => boolean().withDefault(const Constant(true))();
RealColumn get endLimit => real().withDefault(const Constant(30.0))();
```text
**Step 2: Add fields to AppSettings**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

a) Add fields after `decoStopIncrement` (around line 108):

```dart
/// Whether O2 is considered narcotic (true = more conservative)
final bool o2Narcotic;

/// END limit in meters for MND calculations (typically 30)
final double endLimit;
```text
b) Add defaults in constructor (after `this.decoStopIncrement = 3.0,` around line 237):

```dart
this.o2Narcotic = true,
this.endLimit = 30.0,
```text
c) Add to `copyWith()` method (after `decoStopIncrement` entries):

Parameters:

```dart
bool? o2Narcotic,
double? endLimit,
```text
Body:

```dart
o2Narcotic: o2Narcotic ?? this.o2Narcotic,
endLimit: endLimit ?? this.endLimit,
```text
d) Add setter methods to `SettingsNotifier` (after `setDecoStopIncrement`, around line 715):

```dart
Future<void> setO2Narcotic(bool value) async {
  state = state.copyWith(o2Narcotic: value);
  await _saveSettings();
}

Future<void> setEndLimit(double value) async {
  final clamped = value.clamp(20.0, 50.0);
  state = state.copyWith(endLimit: clamped);
  await _saveSettings();
}
```text
**Step 3: Map fields in repository**

In `lib/features/settings/data/repositories/diver_settings_repository.dart`:

a) In `createSettingsForDiver` (the `DiverSettingsCompanion` construction, after `decoStopIncrement`):

```dart
o2Narcotic: Value(s.o2Narcotic),
endLimit: Value(s.endLimit),
```text
b) In `updateSettingsForDiver` (the companion update, after `decoStopIncrement`):

```dart
o2Narcotic: Value(settings.o2Narcotic),
endLimit: Value(settings.endLimit),
```text
c) In `_mapRowToAppSettings` (after `decoStopIncrement`):

```dart
o2Narcotic: row.o2Narcotic,
endLimit: row.endLimit,
```text
**Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift generates updated schema code without errors.

**Step 5: Run analyzer and tests**

Run: `flutter analyze && flutter test`
Expected: No analysis issues, all existing tests still pass.

**Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart
git commit -m "feat: add o2Narcotic and endLimit settings for MND calculation"
```text
---

## Task 3: Add Narcosis section to Decompression settings UI

**Files:**

- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (~line 835, `_DecompressionSectionContent`)
- Modify: `lib/l10n/arb/app_en.arb` (add l10n keys)

**Step 1: Add l10n keys to `lib/l10n/arb/app_en.arb`**

After the existing decompression keys, add:

```json
"settings_decompression_header_narcosis": "Narcosis",
"settings_decompression_o2Narcotic": "O2 is narcotic",
"settings_decompression_o2Narcotic_subtitle": "When enabled, both O2 and N2 are considered narcotic (more conservative). When disabled, only N2 contributes to narcosis.",
"settings_decompression_endLimit": "END Limit",
"settings_decompression_endLimit_subtitle": "Maximum equivalent narcotic depth used for MND calculations",
"settings_decompression_endLimit_dialog_title": "END Limit",
```text
**Step 2: Add Narcosis card to `_DecompressionSectionContent.build()`**

In `lib/features/settings/presentation/pages/settings_page.dart`, inside the `_DecompressionSectionContent` build method, after the Data Source Preferences card (before the closing `],` of the Column around line 835), add:

```dart
const SizedBox(height: 24),
_buildSectionHeader(context, context.l10n.settings_decompression_header_narcosis),
const SizedBox(height: 8),
Card(
  child: Column(
    children: [
      SwitchListTile(
        secondary: const Icon(Icons.air),
        title: Text(context.l10n.settings_decompression_o2Narcotic),
        subtitle: Text(context.l10n.settings_decompression_o2Narcotic_subtitle),
        value: settings.o2Narcotic,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).setO2Narcotic(value);
        },
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.vertical_align_bottom),
        title: Text(context.l10n.settings_decompression_endLimit),
        subtitle: Text(context.l10n.settings_decompression_endLimit_subtitle),
        trailing: Text(
          units.formatDepth(settings.endLimit, decimals: 0),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () => _showEndLimitDialog(context, ref, settings),
      ),
    ],
  ),
),
```dart
Note: The `_DecompressionSectionContent` will need a `UnitFormatter` -- add `final units = UnitFormatter(settings);` at the top of the `build` method.

**Step 3: Add `_showEndLimitDialog` method to `_DecompressionSectionContent`**

```dart
void _showEndLimitDialog(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  final units = UnitFormatter(settings);
  var currentValue = settings.endLimit;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(context.l10n.settings_decompression_endLimit_dialog_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              units.formatDepth(currentValue, decimals: 0),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Slider(
              value: currentValue,
              min: 20.0,
              max: 50.0,
              divisions: 30,
              label: units.formatDepth(currentValue, decimals: 0),
              onChanged: (value) {
                setDialogState(() => currentValue = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setEndLimit(currentValue);
              Navigator.pop(dialogContext);
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    ),
  );
}
```text
**Step 4: Regenerate l10n**

Run: `flutter gen-l10n` (or `dart run build_runner build --delete-conflicting-outputs` if l10n is generated via build_runner)

**Step 5: Run analyzer and format**

Run: `dart format lib/features/settings/presentation/pages/settings_page.dart && flutter analyze lib/features/settings/presentation/pages/settings_page.dart`
Expected: No issues

**Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/l10n/
git commit -m "feat: add narcosis settings (O2 narcotic, END limit) to decompression UI"
```text
---

## Task 4: Add MND display to tank editor

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (~line 224, 565-591)
- Modify: `lib/l10n/arb/app_en.arb` (add l10n key)

**Step 1: Add l10n key**

In `lib/l10n/arb/app_en.arb`:

```json
"diveLog_tank_modMndInfo": "MOD: {mod} (ppO2 1.4) | MND: {mnd}",
"diveLog_tank_mndInfo": "MND: {depth}",
```text
**Step 2: Update `_buildModInfo` to include MND**

The tank editor is a `ConsumerStatefulWidget` with access to `ref`. Read the settings to get `o2Narcotic` and `endLimit`.

Replace the `_buildModInfo` method (lines 565-591) with:

```dart
Widget _buildModInfo(GasMix gasMix, UnitFormatter units) {
  final settings = ref.watch(settingsProvider);
  final modDepth = units.formatDepth(gasMix.mod(), decimals: 0);
  final mndValue = gasMix.mnd(
    endLimit: settings.endLimit,
    o2Narcotic: settings.o2Narcotic,
  );
  final mndDepth = mndValue.isFinite
      ? units.formatDepth(mndValue, decimals: 0)
      : '--';

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.warning_amber,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Semantics(
            label: 'Maximum operating depth: $modDepth. '
                'Maximum narcotic depth: $mndDepth',
            child: Text(
              'MOD: $modDepth (ppO\u2082 1.4) | MND: $mndDepth',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
```text
**Step 3: Run analyzer and format**

Run: `dart format lib/features/dive_log/presentation/widgets/tank_editor.dart && flutter analyze lib/features/dive_log/presentation/widgets/tank_editor.dart`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/tank_editor.dart lib/l10n/
git commit -m "feat: display MND alongside MOD in tank editor"
```text
---

## Task 5: Add bidirectional MND input to tank editor

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart`

**Step 1: Add MND text field controller and state**

In the `_TankEditorCardState` class, add a controller and a flag:

```dart
late TextEditingController _mndController;
bool _mndDriven = false; // true when user is editing MND to derive He%
```text
Initialize in `initState()` and dispose in `dispose()`.

**Step 2: Add MND input field below the gas mix section**

In the `build()` method, after `_buildGasMixSection()` (line 217) and before `_buildPressureRow`, when the gas is trimix or when the user has entered He > 0, add:

```dart
// MND input for trimix planning
if (gasMix.isTrimix || gasMix.he > 0) ...[
  const SizedBox(height: 8),
  _buildMndInput(gasMix, units),
],
```text
**Step 3: Implement `_buildMndInput`**

```dart
Widget _buildMndInput(GasMix gasMix, UnitFormatter units) {
  final settings = ref.watch(settingsProvider);
  final currentMnd = gasMix.mnd(
    endLimit: settings.endLimit,
    o2Narcotic: settings.o2Narcotic,
  );

  // Sync controller if not actively editing
  if (!_mndDriven) {
    final displayValue = currentMnd.isFinite
        ? units.convertDepth(currentMnd).round().toString()
        : '';
    if (_mndController.text != displayValue) {
      _mndController.text = displayValue;
    }
  }

  return Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: _mndController,
          decoration: InputDecoration(
            labelText: 'MND',
            suffixText: units.depthSymbol,
            isDense: true,
            helperText: 'Set to auto-calculate He%',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed > 0) {
              _mndDriven = true;
              final mndMeters = settings.depthUnit == DepthUnit.meters
                  ? parsed
                  : parsed / 3.28084;
              final newHe = GasMix.heForMnd(
                mndMeters,
                gasMix.o2,
                endLimit: settings.endLimit,
                o2Narcotic: settings.o2Narcotic,
              );
              // Update the He% controller
              _heController.text = newHe.round().toString();
              _notifyChange();
            } else {
              _mndDriven = false;
            }
          },
        ),
      ),
    ],
  );
}
```text
Note: The exact controller names (`_heController`) and the `_notifyChange()` pattern should match the existing code in tank_editor.dart. Read the file to confirm exact names before implementing.

**Step 4: Run analyzer and format**

Run: `dart format lib/features/dive_log/presentation/widgets/tank_editor.dart && flutter analyze lib/features/dive_log/presentation/widgets/tank_editor.dart`

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/tank_editor.dart
git commit -m "feat: add bidirectional MND input to tank editor"
```text
---

## Task 6: Create MND/END calculator providers

**Files:**

- Create: `lib/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart`
- Modify: `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart` (add reset)

**Step 1: Create provider file**

Create `lib/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

// =========================================================================
// MND/END Calculator State
// =========================================================================

/// O2% for MND calculation (21-100%)
final mndO2Provider = StateProvider<double>((ref) => 21.0);

/// He% for MND calculation (0-79%)
final mndHeProvider = StateProvider<double>((ref) => 35.0);

/// END limit for MND calculation (meters), initialized from settings
final mndEndLimitProvider = StateProvider<double>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.endLimit;
});

/// Whether O2 is narcotic, initialized from settings
final mndO2NarcoticProvider = StateProvider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.o2Narcotic;
});

/// Computed gas mix from O2/He inputs
final mndGasMixProvider = Provider<GasMix>((ref) {
  final o2 = ref.watch(mndO2Provider);
  final he = ref.watch(mndHeProvider);
  return GasMix(o2: o2, he: he.clamp(0, 100 - o2));
});

/// Computed MND result in meters
final mndResultProvider = Provider<double>((ref) {
  final gasMix = ref.watch(mndGasMixProvider);
  final endLimit = ref.watch(mndEndLimitProvider);
  final o2Narcotic = ref.watch(mndO2NarcoticProvider);
  return gasMix.mnd(endLimit: endLimit, o2Narcotic: o2Narcotic);
});

/// Depth input for END-at-depth calculation (meters)
final mndDepthProvider = StateProvider<double>((ref) => 40.0);

/// Computed END at the given depth
final mndEndAtDepthProvider = Provider<double>((ref) {
  final gasMix = ref.watch(mndGasMixProvider);
  final depth = ref.watch(mndDepthProvider);
  final o2Narcotic = ref.watch(mndO2NarcoticProvider);
  return gasMix.end(depth, o2Narcotic: o2Narcotic);
});

/// Reset MND calculator providers to defaults
void resetMndCalculator(WidgetRef ref) {
  ref.read(mndO2Provider.notifier).state = 21.0;
  ref.read(mndHeProvider.notifier).state = 35.0;
  ref.read(mndDepthProvider.notifier).state = 40.0;
  // endLimit and o2Narcotic reset to settings values automatically
  ref.invalidate(mndEndLimitProvider);
  ref.invalidate(mndO2NarcoticProvider);
}
```typescript
**Step 2: Add MND reset to `resetGasCalculators`**

In `lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart`, import the new file and call `resetMndCalculator(ref)` at the end of `resetGasCalculators()`.

**Step 3: Run analyzer**

Run: `flutter analyze lib/features/gas_calculators/`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/features/gas_calculators/presentation/providers/mnd_calculator_providers.dart lib/features/gas_calculators/presentation/providers/gas_calculators_providers.dart
git commit -m "feat: add MND/END calculator Riverpod providers"
```text
---

## Task 7: Create MND/END calculator widget

**Files:**

- Create: `lib/features/gas_calculators/presentation/widgets/mnd_calculator.dart`
- Modify: `lib/l10n/arb/app_en.arb` (add l10n keys)

**Step 1: Add l10n keys**

In `lib/l10n/arb/app_en.arb`:

```json
"gasCalculators_tab_mnd": "MND/END",
"gasCalculators_mnd_inputParameters": "Gas Mix & Narcosis Settings",
"gasCalculators_mnd_o2Percent": "O2 %",
"gasCalculators_mnd_hePercent": "He %",
"gasCalculators_mnd_endLimit": "END Limit",
"gasCalculators_mnd_o2Narcotic": "O2 is narcotic",
"gasCalculators_mnd_resultTitle": "Maximum Narcotic Depth",
"gasCalculators_mnd_endAtDepthTitle": "END at Depth",
"gasCalculators_mnd_depthInput": "Depth",
"gasCalculators_mnd_infoTitle": "About MND/END",
"gasCalculators_mnd_infoContent": "Maximum Narcotic Depth (MND) is the deepest you can go before narcosis exceeds your END limit. Equivalent Narcotic Depth (END) tells you the narcotic effect of your gas at a given depth.\n\nWhen 'O2 is narcotic' is enabled, both oxygen and nitrogen contribute to narcosis (more conservative). When disabled, only nitrogen is considered narcotic."
```dart
**Step 2: Create widget file**

Create `lib/features/gas_calculators/presentation/widgets/mnd_calculator.dart` following the exact pattern of `mod_calculator.dart`:

- Input card with O2 slider, He slider, END limit input, O2 narcotic toggle
- MND result card showing depth in both units
- END at depth card with depth slider and result
- Info card explaining MND/END

The widget is a `ConsumerWidget` using the providers from Task 6. Follow the same layout patterns as `ModCalculator`: `SingleChildScrollView` > `Center` > `ConstrainedBox(maxWidth: 700)` > `Column` with `Card` children.

**Step 3: Run analyzer and format**

Run: `dart format lib/features/gas_calculators/presentation/widgets/mnd_calculator.dart && flutter analyze lib/features/gas_calculators/`

**Step 4: Commit**

```bash
git add lib/features/gas_calculators/presentation/widgets/mnd_calculator.dart lib/l10n/
git commit -m "feat: create MND/END calculator widget"
```text
---

## Task 8: Add MND/END tab to gas calculators page

**Files:**

- Modify: `lib/features/gas_calculators/presentation/pages/gas_calculators_page.dart`

**Step 1: Update tab count and add tab**

In `gas_calculators_page.dart`:

a) Change `TabController(length: 4, ...)` to `TabController(length: 5, ...)` (line 32)

b) Add new tab after the Rock Bottom tab (after line 77):

```dart
Tab(
  icon: const Icon(Icons.psychology),
  text: context.l10n.gasCalculators_tab_mnd,
),
```text
c) Add `MndCalculator()` to `TabBarView.children` (after line 90):

```dart
const MndCalculator(),
```typescript
d) Add import at top:

```dart
import 'package:submersion/features/gas_calculators/presentation/widgets/mnd_calculator.dart';
```text
**Step 2: Run analyzer and format**

Run: `dart format lib/features/gas_calculators/presentation/pages/gas_calculators_page.dart && flutter analyze lib/features/gas_calculators/`

**Step 3: Commit**

```bash
git add lib/features/gas_calculators/presentation/pages/gas_calculators_page.dart
git commit -m "feat: add MND/END tab to gas calculators page"
```text
---

## Task 9: Update existing END calculations for consistency

**Files:**

- Modify: `lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart` (~line 54)
- Modify: `lib/core/deco/o2_toxicity_calculator.dart` (~line 52)

**Step 1: Update `calcENDProvider` to use `o2Narcotic` setting**

In `lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart`, change `calcENDProvider` (lines 53-58):

```dart
/// Equivalent Narcotic Depth at current depth
final calcENDProvider = Provider<double>((ref) {
  final depth = ref.watch(calcDepthProvider);
  final gasMix = ref.watch(calcGasMixProvider);
  final settings = ref.watch(settingsProvider);
  return gasMix.end(depth, o2Narcotic: settings.o2Narcotic);
});
```typescript
Add import for `settingsProvider` if not already imported.

**Step 2: Update `O2ToxicityCalculator.calculateEnd()`**

In `lib/core/deco/o2_toxicity_calculator.dart`, update the signature to accept `o2Narcotic`:

```dart
static double calculateEnd(
  double depthMeters,
  double n2Fraction, {
  double heFraction = 0.0,
  bool o2Narcotic = false,
}) {
  final ambientPressure = 1.0 + (depthMeters / 10.0);
  if (o2Narcotic) {
    final narcoticFraction = 1.0 - heFraction;
    return ((ambientPressure * narcoticFraction) - 1.0) * 10.0;
  } else {
    final n2Pressure = ambientPressure * n2Fraction;
    return (n2Pressure / 0.79 - 1.0) * 10.0;
  }
}
```text
Note: Keep default `o2Narcotic: false` here to maintain backward compatibility with existing callers.

**Step 3: Check for other callers of `calculateEnd`**

Search for `calculateEnd` across the codebase and verify no callers break.

Run: `grep -rn "calculateEnd" lib/`

**Step 4: Run all tests**

Run: `flutter test`
Expected: All pass

**Step 5: Commit**

```bash
git add lib/features/deco_calculator/presentation/providers/deco_calculator_providers.dart lib/core/deco/o2_toxicity_calculator.dart
git commit -m "feat: update existing END calculations to respect o2Narcotic setting"
```diff
---

## Task 10: Final integration test and cleanup

**Step 1: Run full test suite**

Run: `flutter test`
Expected: All pass

**Step 2: Run analyzer on full project**

Run: `flutter analyze`
Expected: No issues

**Step 3: Format all changed files**

Run: `dart format lib/ test/`

**Step 4: Manual smoke test checklist**

- [ ] Settings > Decompression shows Narcosis card with O2 narcotic toggle and END limit
- [ ] Changing O2 narcotic toggle updates MND in tank editor
- [ ] Tank editor shows MND alongside MOD for non-air gases
- [ ] Editing MND on a trimix tank auto-updates He%
- [ ] Gas Calculators shows 5 tabs including MND/END
- [ ] MND calculator produces correct results for air, nitrox, and trimix
- [ ] END at depth shows correct narcotic equivalent
- [ ] Toggling O2 narcotic in calculator updates both MND and END results
- [ ] Reset button clears MND calculator to defaults
- [ ] Deco calculator END warnings use the o2Narcotic setting

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for MND calculation feature"
```
