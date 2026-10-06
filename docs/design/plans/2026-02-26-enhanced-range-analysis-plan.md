# Enhanced Range Analysis Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Range Analysis min/max/avg table with a unified stat-chip grid showing derived dive metrics (elapsed time, depth delta, rates, gas consumption, SAC rate).

**Architecture:** Extend the existing `RangeStatsPanel` widget with an expanded `_RangeStats` model and a `Wrap`-based grid of stat chips. All calculations stay inline in the widget. The widget receives two new parameters (`tanks`, `sacUnit`) from the dive detail page.

**Tech Stack:** Flutter, Riverpod (ConsumerWidget), Material 3, l10n ARB files.

---

## Task 1: Add Localization Keys

**Files:**

- Modify: `lib/l10n/arb/app_en.arb` (near lines 1978-1986)
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`

**Step 1: Add new keys to English ARB**

Add these keys after the existing `diveLog_rangeStats_tooltip_close` entry in `app_en.arb`. Remove the old `diveLog_rangeStats_header_avg`, `diveLog_rangeStats_header_max`, `diveLog_rangeStats_header_min`, `diveLog_rangeStats_label_pressure` keys since they will no longer be used.

New keys to add:

```json
"diveLog_rangeStats_label_elapsed": "Elapsed",
"diveLog_rangeStats_label_depthDelta": "Depth Delta",
"diveLog_rangeStats_label_minDepth": "Min Depth",
"diveLog_rangeStats_label_maxDepth": "Max Depth",
"diveLog_rangeStats_label_avgDepth": "Avg Depth",
"diveLog_rangeStats_label_maxDescent": "Max Descent",
"diveLog_rangeStats_label_maxAscent": "Max Ascent",
"diveLog_rangeStats_label_avgVertSpeed": "Avg Vert Speed",
"diveLog_rangeStats_label_minTemp": "Min Temp",
"diveLog_rangeStats_label_maxTemp": "Max Temp",
"diveLog_rangeStats_label_gasConsumed": "Gas Consumed",
"diveLog_rangeStats_label_sacRate": "SAC Rate",
"diveLog_rangeStats_label_minHR": "Min HR",
"diveLog_rangeStats_label_maxHR": "Max HR"
```text
**Step 2: Add same keys (English values) to all other locale ARB files**

For each of the 9 non-English locale files, add the same keys with English values as placeholders. Remove the same old keys as from English.

**Step 3: Regenerate localizations**

Run: `flutter gen-l10n` or `dart run build_runner build --delete-conflicting-outputs`

Expected: All `app_localizations_*.dart` files regenerated with new getter methods.

**Step 4: Verify no analysis errors**

Run: `flutter analyze lib/l10n/`

Expected: No errors.

**Step 5: Commit**

```

feat: add localization keys for enhanced range analysis

```text
---

## Task 2: Expand _RangeStats Data Model and Calculation Logic

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/range_stats_panel.dart` (lines 259-365)

**Step 1: Replace `_RangeStats` class (lines 332-365)**

Replace the existing `_RangeStats` class with the expanded version:

```dart
/// Internal class to hold range statistics
class _RangeStats {
  final int elapsedSeconds;
  final double depthDelta;
  final double minDepth;
  final double maxDepth;
  final double avgDepth;
  final double maxDescentRate;
  final double maxAscentRate;
  final double avgVerticalSpeed;
  final double? minTemp;
  final double? maxTemp;
  final double? pressureConsumed;
  final double? consumptionRate;
  final double? sacRate;
  final double? sacVolume;
  final double? tankVolume;
  final int? minHR;
  final int? maxHR;

  const _RangeStats({
    required this.elapsedSeconds,
    required this.depthDelta,
    required this.minDepth,
    required this.maxDepth,
    required this.avgDepth,
    required this.maxDescentRate,
    required this.maxAscentRate,
    required this.avgVerticalSpeed,
    this.minTemp,
    this.maxTemp,
    this.pressureConsumed,
    this.consumptionRate,
    this.sacRate,
    this.sacVolume,
    this.tankVolume,
    this.minHR,
    this.maxHR,
  });

  bool get hasTemperature => minTemp != null;
  bool get hasPressure => pressureConsumed != null;
  bool get hasHeartRate => minHR != null;
  bool get hasTankVolume => tankVolume != null && tankVolume! > 0;
}
```text
**Step 2: Rewrite `_calculateRangeStats` method (lines 259-329)**

The method now takes `List<DiveTank> tanks` as an additional parameter.
Replace the entire method body:

```dart
_RangeStats _calculateRangeStats(
  RangeSelectionState rangeState,
  List<DiveTank> tanks,
) {
  final rangePoints = profile
      .where(
        (p) =>
            p.timestamp >= rangeState.startTimestamp! &&
            p.timestamp <= rangeState.endTimestamp!,
      )
      .toList();

  if (rangePoints.isEmpty) {
    return const _RangeStats(
      elapsedSeconds: 0,
      depthDelta: 0,
      minDepth: 0,
      maxDepth: 0,
      avgDepth: 0,
      maxDescentRate: 0,
      maxAscentRate: 0,
      avgVerticalSpeed: 0,
    );
  }

  // Elapsed time
  final elapsedSeconds =
      rangePoints.last.timestamp - rangePoints.first.timestamp;
  final elapsedMinutes = elapsedSeconds > 0 ? elapsedSeconds / 60.0 : 1.0;

  // Depth stats
  final depths = rangePoints.map((p) => p.depth).toList();
  final minDepth = depths.reduce(math.min);
  final maxDepth = depths.reduce(math.max);
  final avgDepth = depths.reduce((a, b) => a + b) / depths.length;

  // Depth delta (signed: positive = deeper)
  final depthDelta = rangePoints.last.depth - rangePoints.first.depth;

  // Average vertical speed (m/min, signed)
  final avgVerticalSpeed = depthDelta / elapsedMinutes;

  // Max descent and ascent rates from consecutive point pairs
  double maxDescentRate = 0;
  double maxAscentRate = 0;
  for (int i = 0; i < rangePoints.length - 1; i++) {
    final dt = rangePoints[i + 1].timestamp - rangePoints[i].timestamp;
    if (dt <= 0) continue;
    final dd = rangePoints[i + 1].depth - rangePoints[i].depth;
    final rate = dd / (dt / 60.0); // m/min
    if (rate > 0 && rate > maxDescentRate) {
      maxDescentRate = rate;
    } else if (rate < 0 && rate.abs() > maxAscentRate) {
      maxAscentRate = rate.abs();
    }
  }

  // Temperature stats
  final temps = rangePoints
      .where((p) => p.temperature != null)
      .map((p) => p.temperature!)
      .toList();
  double? minTemp, maxTemp;
  if (temps.isNotEmpty) {
    minTemp = temps.reduce(math.min);
    maxTemp = temps.reduce(math.max);
  }

  // Pressure / gas consumption stats
  final pressurePoints = rangePoints
      .where((p) => p.pressure != null)
      .toList();
  double? pressureConsumed, consumptionRate, sacRate, sacVolume;
  double? primaryTankVolume;

  if (pressurePoints.length >= 2) {
    final firstPressure = pressurePoints.first.pressure!;
    final lastPressure = pressurePoints.last.pressure!;
    pressureConsumed = firstPressure - lastPressure;
    consumptionRate = pressureConsumed / elapsedMinutes;

    // SAC = consumption_rate / avg_ambient_pressure
    final avgAmbientPressure = 1.0 + (avgDepth / 10.0);
    if (avgAmbientPressure > 0) {
      sacRate = consumptionRate / avgAmbientPressure;
    }

    // SAC volume (L/min) if tank volume is known
    if (tanks.isNotEmpty && tanks.first.volume != null) {
      primaryTankVolume = tanks.first.volume;
      if (sacRate != null && primaryTankVolume! > 0) {
        sacVolume = sacRate * primaryTankVolume!;
      }
    }
  }

  // Heart rate stats
  final heartRates = rangePoints
      .where((p) => p.heartRate != null)
      .map((p) => p.heartRate!)
      .toList();
  int? minHR, maxHR;
  if (heartRates.isNotEmpty) {
    minHR = heartRates.reduce(math.min);
    maxHR = heartRates.reduce(math.max);
  }

  return _RangeStats(
    elapsedSeconds: elapsedSeconds,
    depthDelta: depthDelta,
    minDepth: minDepth,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    maxDescentRate: maxDescentRate,
    maxAscentRate: maxAscentRate,
    avgVerticalSpeed: avgVerticalSpeed,
    minTemp: minTemp,
    maxTemp: maxTemp,
    pressureConsumed: pressureConsumed,
    consumptionRate: consumptionRate,
    sacRate: sacRate,
    sacVolume: sacVolume,
    tankVolume: primaryTankVolume,
    minHR: minHR,
    maxHR: maxHR,
  );
}
```text
**Step 3: Verify file compiles**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/range_stats_panel.dart`

Expected: Will have errors because the `build` method still calls old signatures. This is expected; we fix it in Task 3.

**Step 4: Commit**

```

refactor: expand _RangeStats model with derived dive metrics

```dart
---

## Task 3: Rewrite Widget Constructor and UI Layout

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/range_stats_panel.dart` (lines 1-257)

**Step 1: Update imports and constructor**

Add to imports:

```dart
import 'package:submersion/core/constants/units.dart';
```text
Add two new required fields to `RangeStatsPanel`:

```dart
/// The dive's tanks (for SAC calculation)
final List<DiveTank> tanks;

/// SAC unit preference from settings
final SacUnit sacUnit;
```text
Update constructor:

```dart
const RangeStatsPanel({
  super.key,
  required this.diveId,
  required this.profile,
  required this.units,
  required this.tanks,
  required this.sacUnit,
  this.onClose,
});
```text
**Step 2: Update `build` method call to `_calculateRangeStats`**

Change line 45 from:

```dart
final stats = _calculateRangeStats(rangeState);
```yaml
to:

```dart
final stats = _calculateRangeStats(rangeState, tanks);
```text
**Step 3: Replace `_buildStatsTable` call with `_buildStatsGrid`**

Change line 113 from:

```dart
_buildStatsTable(context, stats),
```yaml
to:

```dart
_buildStatsGrid(context, stats),
```text
**Step 4: Remove old `_buildStatsTable` and `_buildStatRow` methods (lines 120-257)**

Replace them with the new grid builder and chip builder:

```dart
Widget _buildStatsGrid(BuildContext context, _RangeStats stats) {
  final colorScheme = Theme.of(context).colorScheme;

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      // Row 1: Elapsed time + Depth delta
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_elapsed,
        _formatElapsed(stats.elapsedSeconds),
        Icons.timer_outlined,
        colorScheme.primary,
      ),
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_depthDelta,
        _formatSignedDepth(stats.depthDelta),
        Icons.swap_vert,
        colorScheme.primary,
      ),
      // Row 2: Min depth + Max depth
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_minDepth,
        units.formatDepth(stats.minDepth),
        Icons.arrow_upward,
        colorScheme.primary,
      ),
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_maxDepth,
        units.formatDepth(stats.maxDepth),
        Icons.arrow_downward,
        colorScheme.primary,
      ),
      // Row 3: Avg depth + Avg vertical speed
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_avgDepth,
        units.formatDepth(stats.avgDepth),
        Icons.straighten,
        colorScheme.primary,
      ),
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_avgVertSpeed,
        _formatSignedRate(stats.avgVerticalSpeed),
        Icons.speed,
        colorScheme.secondary,
      ),
      // Row 4: Max descent + Max ascent
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_maxDescent,
        _formatRate(stats.maxDescentRate),
        Icons.trending_down,
        Colors.orange,
      ),
      _buildStatChip(
        context,
        context.l10n.diveLog_rangeStats_label_maxAscent,
        _formatRate(stats.maxAscentRate),
        Icons.trending_up,
        Colors.orange,
      ),
      // Row 5: Temp (if available)
      if (stats.hasTemperature) ...[
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_minTemp,
          units.formatTemperature(stats.minTemp!),
          Icons.thermostat,
          colorScheme.tertiary,
        ),
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_maxTemp,
          units.formatTemperature(stats.maxTemp!),
          Icons.thermostat,
          colorScheme.tertiary,
        ),
      ],
      // Row 6: Gas consumed + SAC (if available)
      if (stats.hasPressure) ...[
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_gasConsumed,
          units.formatPressure(stats.pressureConsumed!),
          Icons.local_gas_station,
          Colors.orange,
        ),
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_sacRate,
          _formatSacValue(stats),
          Icons.air,
          Colors.orange,
        ),
      ],
      // Row 7: Heart rate (if available)
      if (stats.hasHeartRate) ...[
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_minHR,
          '${stats.minHR} bpm',
          Icons.favorite,
          Colors.red,
        ),
        _buildStatChip(
          context,
          context.l10n.diveLog_rangeStats_label_maxHR,
          '${stats.maxHR} bpm',
          Icons.favorite,
          Colors.red,
        ),
      ],
    ],
  );
}
```text
**Step 5: Add `_buildStatChip` helper**

```dart
Widget _buildStatChip(
  BuildContext context,
  String label,
  String value,
  IconData icon,
  Color color,
) {
  final colorScheme = Theme.of(context).colorScheme;

  return SizedBox(
    width: (MediaQuery.of(context).size.width - 56) / 2,
    child: Row(
      children: [
        ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```text
**Step 6: Add formatting helpers**

```dart
String _formatElapsed(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatSignedDepth(double delta) {
  final converted = units.convertDepth(delta);
  final sign = converted >= 0 ? '+' : '';
  return '$sign${converted.toStringAsFixed(1)}${units.depthSymbol}';
}

String _formatRate(double rate) {
  final converted = units.convertDepth(rate);
  return '${converted.toStringAsFixed(1)} ${units.depthSymbol}/min';
}

String _formatSignedRate(double rate) {
  final converted = units.convertDepth(rate);
  final sign = converted >= 0 ? '+' : '';
  return '$sign${converted.toStringAsFixed(1)} ${units.depthSymbol}/min';
}

/// Format SAC value respecting user's SAC unit preference.
/// Falls back to pressure/min if volume/min is selected but no tank volume.
String _formatSacValue(_RangeStats stats) {
  if (sacUnit == SacUnit.litersPerMin &&
      stats.sacVolume != null &&
      stats.hasTankVolume) {
    final value = units.convertVolume(stats.sacVolume!);
    return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
  } else if (stats.sacRate != null) {
    final value = units.convertPressure(stats.sacRate!);
    return '${value.toStringAsFixed(1)} ${units.pressureSymbol}/min';
  }
  return '--';
}
```text
**Step 7: Verify file compiles**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/range_stats_panel.dart`

Expected: Errors about the call site in `dive_detail_page.dart` (missing `tanks` and `sacUnit` args). We fix that next.

**Step 8: Commit**

```

feat: rewrite range stats panel with unified grid layout

```text
---

## Task 4: Update Dive Detail Page Call Site

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (near lines 1045-1049)

**Step 1: Pass `tanks` and `sacUnit` to `RangeStatsPanel`**

Find the `RangeStatsPanel` constructor call (around line 1045) and update it:

```dart
RangeStatsPanel(
  diveId: dive.id,
  profile: dive.profile,
  units: units,
  tanks: dive.tanks,
  sacUnit: ref.watch(sacUnitProvider),
),
```typescript
The `sacUnitProvider` import should already be available via the existing `settings_providers.dart` import (line 25).

**Step 2: Verify full build**

Run: `flutter analyze`

Expected: No errors.

**Step 3: Format code**

Run: `dart format lib/features/dive_log/presentation/widgets/range_stats_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart`

Expected: No changes (or formatting applied cleanly).

**Step 4: Commit**

```

feat: wire enhanced range analysis into dive detail page

```text
---

## Task 5: Clean Up Unused L10n Keys

**Files:**

- Modify: All `app_*.arb` files (10 files)
- Modify: `lib/l10n/arb/app_localizations.dart` and locale-specific files

**Step 1: Remove unused keys from all ARB files**

Remove these keys which are no longer referenced by the new grid layout:

- `diveLog_rangeStats_header_avg`
- `diveLog_rangeStats_header_max`
- `diveLog_rangeStats_header_min`
- `diveLog_rangeStats_label_pressure`

Keep these keys which ARE still used:

- `diveLog_rangeStats_label_depth` (still used? No - replaced by minDepth/maxDepth/avgDepth. REMOVE.)
- `diveLog_rangeStats_label_temp` (still used? No - replaced by minTemp/maxTemp. REMOVE.)
- `diveLog_rangeStats_label_heartRate` (still used? No - replaced by minHR/maxHR. REMOVE.)
- `diveLog_rangeStats_title` (YES - still used in header)
- `diveLog_rangeStats_tooltip_close` (YES - still used in close button)

So remove a total of 7 keys from all 10 ARB files:

1. `diveLog_rangeStats_header_avg`
2. `diveLog_rangeStats_header_max`
3. `diveLog_rangeStats_header_min`
4. `diveLog_rangeStats_label_depth`
5. `diveLog_rangeStats_label_pressure`
6. `diveLog_rangeStats_label_temp`
7. `diveLog_rangeStats_label_heartRate`

**Step 2: Regenerate localizations**

Run: `flutter gen-l10n` or `dart run build_runner build --delete-conflicting-outputs`

**Step 3: Verify no analysis errors**

Run: `flutter analyze`

Expected: No errors. No references to removed keys anywhere.

**Step 4: Commit**

```

chore: remove unused range stats localization keys

```diff
---

## Task 6: Run Tests and Format

**Step 1: Run all tests**

Run: `flutter test`

Expected: All tests pass. If any test references the old `RangeStatsPanel` constructor (without `tanks`/`sacUnit`), update those test call sites.

**Step 2: Search for test files referencing RangeStatsPanel**

Run: `grep -r "RangeStatsPanel" test/`

If found, update those tests to pass the new required `tanks` and `sacUnit` parameters.

**Step 3: Format all changed files**

Run: `dart format lib/ test/`

Expected: No changes or clean formatting.

**Step 4: Run analyze**

Run: `flutter analyze`

Expected: No issues.

**Step 5: Commit (if any test fixes)**

```text

fix: update range stats panel tests for new constructor

```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add l10n keys | 10 ARB files |
| 2 | Expand `_RangeStats` model + calculation | `range_stats_panel.dart` |
| 3 | Rewrite UI to unified grid | `range_stats_panel.dart` |
| 4 | Update dive detail page call site | `dive_detail_page.dart` |
| 5 | Remove unused l10n keys | 10 ARB files |
| 6 | Run tests, format, analyze | All changed files |
