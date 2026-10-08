# Tissue Heat Map Visualization Redesign - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the unintuitive 8-phase Subsurface color scale with selectable color schemes, add two new visualization modes (stacked area chart and sparklines), and add expandable compact/detailed views.

**Architecture:** Three layers of change: (1) color palette system with `TissueColorFn` typedef and two new color functions, (2) settings persistence through the existing `AppSettings`/`DiverSettings` pipeline, (3) two new CustomPainter-based visualization widgets (`TissueAreaChart`, `TissueSparklines`) integrated into the existing `CompactTissueLoadingCard` with a mode toggle and expand/collapse. All visualizations share the same interaction model (tap/drag hover with crosshair sync).

**Tech Stack:** Flutter, CustomPainter, Riverpod, Drift ORM, fl_chart (existing dependency, not used in new widgets)

---

### Task 1: Define Enums and Color Functions

Add the two new enums (`TissueColorScheme`, `TissueVizMode`) and the two new color functions (`thermalColor`, `divergingColor`) alongside the existing `subsurfaceHeatColor`.

**Files:**

- Create: `lib/features/dive_log/presentation/widgets/tissue_color_schemes.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tissue_heat_map.dart:381,306` (use `TissueColorFn` instead of hard-coded call)

**Step 1: Create `tissue_color_schemes.dart`**

This file defines the enums, the `TissueColorFn` typedef, and the two new color functions. The existing `subsurfaceHeatColor` stays in `tissue_heat_map.dart` (it's tightly coupled to the `_subsurfacePercentage` function there).

```dart
import 'dart:ui';

/// How a tissue loading percentage (0-120+) maps to a display color.
typedef TissueColorFn = Color Function(double percentage);

/// User-selectable color scheme for the tissue loading heat map.
enum TissueColorScheme {
  thermal('Thermal'),
  diverging('Diverging'),
  classic('Subsurface');

  final String displayName;
  const TissueColorScheme(this.displayName);

  static TissueColorScheme fromName(String name) {
    return TissueColorScheme.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TissueColorScheme.thermal,
    );
  }
}

/// User-selectable visualization mode for the tissue loading display.
enum TissueVizMode {
  heatMap('Heat Map'),
  stackedArea('Area Chart'),
  sparklines('Sparklines');

  final String displayName;
  const TissueVizMode(this.displayName);

  static TissueVizMode fromName(String name) {
    return TissueVizMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TissueVizMode.heatMap,
    );
  }
}

/// Thermal color scheme: 4-phase cool-to-warm gradient.
///
/// Emphasizes danger proximity (distance to M-value).
/// Blue -> Cyan -> Green -> Yellow -> Red -> White
Color thermalColor(double percentage) {
  const blue = Color(0xFF1565C0);
  const cyan = Color(0xFF00ACC1);
  const green = Color(0xFF66BB6A);
  const yellow = Color(0xFFFFEE58);
  const red = Color(0xFFEF5350);
  const white = Color(0xFFFFFFFF);

  if (percentage <= 0) return blue;

  if (percentage < 50.0) {
    return Color.lerp(blue, cyan, percentage / 50.0)!;
  }

  if (percentage < 80.0) {
    return Color.lerp(green, yellow, (percentage - 50.0) / 30.0)!;
  }

  if (percentage < 100.0) {
    return Color.lerp(yellow, red, (percentage - 80.0) / 20.0)!;
  }

  if (percentage < 120.0) {
    return Color.lerp(red, white, (percentage - 100.0) / 20.0)!;
  }

  return white;
}

/// Diverging color scheme: two-tone scale centered at 50% (equilibrium).
///
/// Emphasizes on/off-gassing direction. Blue for ongassing, orange for
/// offgassing, with a near-white center at equilibrium.
Color divergingColor(double percentage) {
  const deepBlue = Color(0xFF1565C0);
  const lightBlue = Color(0xFF90CAF9);
  const center = Color(0xFFE8EAF6);
  const lightOrange = Color(0xFFFFCC80);
  const deepOrange = Color(0xFFE65100);
  const red = Color(0xFFEF5350);
  const white = Color(0xFFFFFFFF);

  if (percentage <= 0) return deepBlue;

  if (percentage < 25.0) {
    return Color.lerp(deepBlue, lightBlue, percentage / 25.0)!;
  }

  if (percentage < 50.0) {
    return Color.lerp(lightBlue, center, (percentage - 25.0) / 25.0)!;
  }

  if (percentage < 75.0) {
    return Color.lerp(center, lightOrange, (percentage - 50.0) / 25.0)!;
  }

  if (percentage < 100.0) {
    return Color.lerp(lightOrange, deepOrange, (percentage - 75.0) / 25.0)!;
  }

  if (percentage < 120.0) {
    return Color.lerp(red, white, (percentage - 100.0) / 20.0)!;
  }

  return white;
}

/// Returns the color function for the given scheme.
TissueColorFn colorFnForScheme(TissueColorScheme scheme) {
  switch (scheme) {
    case TissueColorScheme.thermal:
      return thermalColor;
    case TissueColorScheme.diverging:
      return divergingColor;
    case TissueColorScheme.classic:
      // Import from tissue_heat_map.dart
      return _classicFallback;
  }
}
```dart
Note: The `colorFnForScheme` function needs access to `subsurfaceHeatColor` from `tissue_heat_map.dart`. To avoid circular imports, either:

- Move `subsurfaceHeatColor` into `tissue_color_schemes.dart`, or
- Have `colorFnForScheme` live elsewhere, or
- Pass the classic function in at the call site.

The cleanest approach: move `subsurfaceHeatColor` (and its helper `_subsurfacePercentage`) into `tissue_color_schemes.dart` since that's where all color functions live. Then `tissue_heat_map.dart` imports from `tissue_color_schemes.dart`.

**Step 2: Move `subsurfaceHeatColor` to `tissue_color_schemes.dart`**

Cut lines 445-512 from `tissue_heat_map.dart` (`subsurfaceHeatColor` function) and paste into `tissue_color_schemes.dart`. Remove the `_classicFallback` placeholder and use `subsurfaceHeatColor` directly in `colorFnForScheme`.

Note: `_subsurfacePercentage` (lines 428-443) is a private function used only by `_TissueHeatMapPainter`. It stays in `tissue_heat_map.dart`. It does NOT depend on `subsurfaceHeatColor` — it calculates a percentage that is then passed to whatever color function is active.

Update `tissue_heat_map.dart`:

- Add `import 'tissue_color_schemes.dart';` at the top (after existing imports)
- Remove the `subsurfaceHeatColor` function (lines 445-512)
- The two call sites (line 306 in legend, line 381 in painter) will be updated in Task 3 to use the configurable color function

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/tissue_color_schemes.dart lib/features/dive_log/presentation/widgets/tissue_heat_map.dart`
Expected: No analysis issues

**Step 4: Commit**

```

feat: add tissue color scheme enums and color functions

Introduces TissueColorScheme (thermal, diverging, classic) and
TissueVizMode (heatMap, stackedArea, sparklines) enums with
thermalColor() and divergingColor() functions. Moves existing
subsurfaceHeatColor() into the new tissue_color_schemes.dart file.

```sql
---

### Task 2: Add Settings Persistence

Wire the new enums into the settings pipeline: database column, AppSettings field, repository read/write, notifier setter, and convenience provider.

**Files:**

- Modify: `lib/core/database/database.dart:581-582` (add two columns after `cardColorGradientEnd`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:56-282` (AppSettings fields + constructor + copyWith)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:570-670` (SettingsNotifier setters)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:45-120` (create insert)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:146-252` (update write)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:297-360` (read mapping)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:363-430` (add parsers)

**Step 1: Add database columns**

In `database.dart`, inside the `DiverSettings` table class, add after the `cardColorGradientEnd` column (line 586):

```dart
// Tissue visualization settings
TextColumn get tissueColorScheme =>
    text().withDefault(const Constant('thermal'))();
TextColumn get tissueVizMode =>
    text().withDefault(const Constant('heatMap'))();
```text
**Step 2: Bump schema version and add migration**

In `database.dart`, change `schemaVersion` from `44` to `45` (line 1117).

In the `onUpgrade` method, add a migration block:

```dart
if (from < 45) {
  await customStatement(
    "ALTER TABLE diver_settings ADD COLUMN tissue_color_scheme TEXT NOT NULL DEFAULT 'thermal'",
  );
  await customStatement(
    "ALTER TABLE diver_settings ADD COLUMN tissue_viz_mode TEXT NOT NULL DEFAULT 'heatMap'",
  );
}
```text
**Step 3: Add fields to AppSettings**

In `settings_providers.dart`, add to the `AppSettings` class:

1. Fields (after `cardColorGradientEnd` field, around line 139):

```dart
/// Color scheme for tissue loading heat map
final TissueColorScheme tissueColorScheme;

/// Visualization mode for tissue loading display
final TissueVizMode tissueVizMode;
```text
1. Constructor defaults (after `cardColorGradientEnd` in constructor, around line 254):

```dart
this.tissueColorScheme = TissueColorScheme.thermal,
this.tissueVizMode = TissueVizMode.heatMap,
```text
1. `copyWith` parameters (after `clearCardColorGradientEnd` parameter, around line 356):

```dart
TissueColorScheme? tissueColorScheme,
TissueVizMode? tissueVizMode,
```text
1. `copyWith` body (after `cardColorGradientEnd` assignment, around line 424):

```dart
tissueColorScheme: tissueColorScheme ?? this.tissueColorScheme,
tissueVizMode: tissueVizMode ?? this.tissueVizMode,
```typescript
1. Add import at top of `settings_providers.dart`:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
```text
**Step 4: Add convenience providers**

In `settings_providers.dart`, after the existing convenience providers (around line 974):

```dart
final tissueColorSchemeProvider = Provider<TissueColorScheme>((ref) {
  return ref.watch(settingsProvider).tissueColorScheme;
});

final tissueVizModeProvider = Provider<TissueVizMode>((ref) {
  return ref.watch(settingsProvider).tissueVizMode;
});
```text
**Step 5: Add setter methods to SettingsNotifier**

In `settings_providers.dart`, in the `SettingsNotifier` class (after `setCardColorGradientEnd` or similar, around line 830):

```dart
Future<void> setTissueColorScheme(TissueColorScheme scheme) async {
  state = state.copyWith(tissueColorScheme: scheme);
  await _saveSettings();
}

Future<void> setTissueVizMode(TissueVizMode mode) async {
  state = state.copyWith(tissueVizMode: mode);
  await _saveSettings();
}
```text
**Step 6: Update repository - create method**

In `diver_settings_repository.dart`, in `createSettingsForDiver`, add to the `DiverSettingsCompanion` (after `cardColorGradientEnd`, around line 88):

```dart
tissueColorScheme: Value(s.tissueColorScheme.name),
tissueVizMode: Value(s.tissueVizMode.name),
```text
**Step 7: Update repository - update method**

In `diver_settings_repository.dart`, in `updateSettingsForDiver`, add to the `DiverSettingsCompanion` (after `cardColorGradientEnd`, around line 194):

```dart
tissueColorScheme: Value(settings.tissueColorScheme.name),
tissueVizMode: Value(settings.tissueVizMode.name),
```text
**Step 8: Update repository - read mapping**

In `diver_settings_repository.dart`, in `_mapRowToAppSettings`, add (after `cardColorGradientEnd`, around line 335):

```dart
tissueColorScheme: TissueColorScheme.fromName(row.tissueColorScheme),
tissueVizMode: TissueVizMode.fromName(row.tissueVizMode),
```text
**Step 9: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated Drift code for the new columns

**Step 10: Verify compilation**

Run: `flutter analyze`
Expected: No analysis issues

**Step 11: Commit**

```

feat: add tissue color scheme and viz mode settings

Adds tissueColorScheme (thermal/diverging/classic) and tissueVizMode
(heatMap/stackedArea/sparklines) to DiverSettings table, AppSettings,
repository, and providers. Schema version 44 -> 45.

```text
---

### Task 3: Refactor Heat Map to Accept Color Function

Update `TissueHeatMapStrip`, `TissueHeatMapLegend`, and `_TissueHeatMapPainter` to accept a `TissueColorFn` parameter instead of hard-coding `subsurfaceHeatColor`. Also update `CompactTissueLoadingCard` to read the color scheme setting and pass the correct function.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/tissue_heat_map.dart` (strip, legend, painter)
- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart` (pass color fn)

**Step 1: Add `colorFn` parameter to `TissueHeatMapLegend`**

In `tissue_heat_map.dart`, update the `TissueHeatMapLegend` class:

```dart
class TissueHeatMapLegend extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final TissueColorFn colorFn;
  final String leftLabel;
  final String rightLabel;

  const TissueHeatMapLegend({
    super.key,
    required this.colorScheme,
    required this.textTheme,
    required this.colorFn,
    this.leftLabel = 'On-gassing',
    this.rightLabel = 'Off-gassing',
  });
```text
Update the `build` method to use `colorFn` instead of `subsurfaceHeatColor`:

```dart
colors.add(colorFn(pct));
```text
Update the label `Text` widgets to use `leftLabel` and `rightLabel` instead of hard-coded strings.

**Step 2: Add `colorFn` parameter to `TissueHeatMapStrip`**

Add to constructor:

```dart
final TissueColorFn colorFn;
```text
Pass it through to `_TissueHeatMapPainter` in `build()`.

**Step 3: Add `colorFn` to `_TissueHeatMapPainter`**

Add field and constructor param:

```dart
final TissueColorFn colorFn;
```text
Update `paint()` line 381 to use it:

```dart
paint.color = colorFn(percentage);  // was: subsurfaceHeatColor(percentage)
```text
Update `shouldRepaint` to include `colorFn`:

```dart
@override
bool shouldRepaint(_TissueHeatMapPainter oldDelegate) {
  return oldDelegate.decoStatuses != decoStatuses ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.colorFn != colorFn;
}
```typescript
**Step 4: Add import to `tissue_heat_map.dart`**

```dart
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
```typescript
**Step 5: Update `CompactTissueLoadingCard` to pass color function**

Convert `CompactTissueLoadingCard` from `StatefulWidget` to `ConsumerStatefulWidget` (so it can read providers).

In `compact_tissue_loading_card.dart`:

1. Change the import and class declaration:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```dart
1. Change `StatefulWidget` to `ConsumerStatefulWidget`, `State<...>` to `ConsumerState<...>`.

2. In `_buildHeatMapSection`, read the color scheme and pass the color function:

```dart
Widget _buildHeatMapSection(
  BuildContext context,
  ColorScheme colorScheme,
  TextTheme textTheme,
) {
  final tissueScheme = ref.watch(tissueColorSchemeProvider);
  final colorFn = colorFnForScheme(tissueScheme);

  // Legend labels differ by scheme
  final leftLabel = tissueScheme == TissueColorScheme.thermal ? 'Safe' : 'On-gassing';
  final rightLabel = tissueScheme == TissueColorScheme.thermal ? 'Danger' : 'Off-gassing';
  // ... rest of method, passing colorFn to TissueHeatMapLegend and TissueHeatMapStrip
```text
1. Update the `TissueHeatMapLegend` instantiation:

```dart
TissueHeatMapLegend(
  colorScheme: colorScheme,
  textTheme: textTheme,
  colorFn: colorFn,
  leftLabel: leftLabel,
  rightLabel: rightLabel,
),
```text
1. Update the `TissueHeatMapStrip` instantiation:

```dart
TissueHeatMapStrip(
  decoStatuses: widget.decoStatuses!,
  selectedIndex: widget.selectedIndex,
  height: 72,
  colorFn: colorFn,
  onHoverIndexChanged: widget.onHeatMapHover,
  // ... rest unchanged
),
```text
**Step 6: Update `TissueHeatMap` wrapper widget**

The top-level `TissueHeatMap` widget (lines 16-87) also needs updating. Add a `colorFn` parameter with a default:

```dart
final TissueColorFn colorFn;

const TissueHeatMap({
  // ... existing params ...
  this.colorFn = thermalColor,
});
```text
Update its `build()` to pass `colorFn` to both `TissueHeatMapLegend` and `TissueHeatMapStrip`.

**Step 7: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/tissue_heat_map.dart lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
Expected: No analysis issues

**Step 8: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 9: Commit**

```

refactor: parameterize tissue heat map color function

TissueHeatMapStrip, TissueHeatMapLegend, and the painter now accept
a TissueColorFn parameter instead of hard-coding subsurfaceHeatColor.
CompactTissueLoadingCard reads the tissueColorScheme setting and
passes the appropriate color function.

```text
---

### Task 4: Add Expand/Collapse to Tissue Card

Add an expand/collapse toggle to the `CompactTissueLoadingCard` header. When expanded, the heat map strip grows taller.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`

**Step 1: Add expanded state**

In `_CompactTissueLoadingCardState`, add:

```dart
bool _isExpanded = false;
```text
**Step 2: Add chevron button to header**

In the header `Row` (line 68), after the M-value legend block, add a chevron icon button:

```dart
const SizedBox(width: 4),
GestureDetector(
  onTap: () => setState(() => _isExpanded = !_isExpanded),
  child: AnimatedRotation(
    turns: _isExpanded ? 0.5 : 0.0,
    duration: const Duration(milliseconds: 200),
    child: Icon(
      Icons.expand_more,
      size: 18,
      color: colorScheme.onSurfaceVariant,
    ),
  ),
),
```text
**Step 3: Animate heat map height**

In `_buildHeatMapSection`, replace the hard-coded `height: 72` with:

```dart
height: _isExpanded ? 144 : 72,
```text
Wrap the `TissueHeatMapStrip` in an `AnimatedContainer`:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  height: _isExpanded ? 144 : 72,
  child: TissueHeatMapStrip(
    // ... existing params, but remove height param since parent constrains it
  ),
),
```text
Actually, `TissueHeatMapStrip` uses `SizedBox(height: widget.height)` internally. So pass the animated height directly:

```dart
TissueHeatMapStrip(
  decoStatuses: widget.decoStatuses!,
  selectedIndex: widget.selectedIndex,
  height: _isExpanded ? 144 : 72,
  colorFn: colorFn,
  // ... callbacks
),
```text
Also update the `SizedBox(height: 44)` spacer between Fast/Slow labels to animate:

```dart
SizedBox(height: _isExpanded ? 116 : 44),
```text
**Step 4: Verify compilation and test**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
Expected: No analysis issues

**Step 5: Commit**

```

feat: add expand/collapse toggle to tissue loading card

Adds a chevron button to the tissue card header. Tapping toggles the
heat map strip between compact (72px) and expanded (144px) heights
with animated transitions.

```text
---

### Task 5: Add Visualization Mode Toggle UI

Add the 3-icon mode toggle to the card header, and wire it to the `tissueVizMode` setting. For now, only the heat map mode renders content — the other two modes show placeholder widgets.

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`

**Step 1: Read viz mode from settings**

In `_buildHeatMapSection` (or better, in `build()`), read the viz mode:

```dart
final vizMode = ref.watch(tissueVizModeProvider);
```text
**Step 2: Add mode toggle to header**

In the header `Row`, between the subtitle and the Spacer, add a `SegmentedButton` or a row of `IconButton`s:

```dart
const SizedBox(width: 8),
_buildVizModeToggle(colorScheme, vizMode),
```text
The toggle widget:

```dart
Widget _buildVizModeToggle(ColorScheme colorScheme, TissueVizMode currentMode) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _modeIcon(Icons.grid_on, TissueVizMode.heatMap, currentMode, colorScheme),
      _modeIcon(Icons.area_chart, TissueVizMode.stackedArea, currentMode, colorScheme),
      _modeIcon(Icons.show_chart, TissueVizMode.sparklines, currentMode, colorScheme),
    ],
  );
}

Widget _modeIcon(
  IconData icon,
  TissueVizMode mode,
  TissueVizMode currentMode,
  ColorScheme colorScheme,
) {
  final isActive = mode == currentMode;
  return GestureDetector(
    onTap: () => ref.read(settingsProvider.notifier).setTissueVizMode(mode),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        icon,
        size: 16,
        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    ),
  );
}
```text
**Step 3: Add color scheme selector**

Add a palette icon that opens a popup menu:

```dart
PopupMenuButton<TissueColorScheme>(
  icon: Icon(Icons.palette_outlined, size: 16, color: colorScheme.onSurfaceVariant),
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(),
  itemBuilder: (context) => TissueColorScheme.values.map((scheme) {
    return PopupMenuItem<TissueColorScheme>(
      value: scheme,
      child: Text(scheme.displayName),
    );
  }).toList(),
  onSelected: (scheme) {
    ref.read(settingsProvider.notifier).setTissueColorScheme(scheme);
  },
),
```text
**Step 4: Switch visualization by mode**

In `build()`, replace the `_buildHeatMapSection` call with a mode switch:

```dart
if (widget.decoStatuses != null && widget.decoStatuses!.isNotEmpty) ...[
  switch (vizMode) {
    TissueVizMode.heatMap => _buildHeatMapSection(context, colorScheme, textTheme),
    TissueVizMode.stackedArea => _buildPlaceholder('Area Chart', colorScheme),
    TissueVizMode.sparklines => _buildPlaceholder('Sparklines', colorScheme),
  },
  const SizedBox(height: 6),
],
```text
Add a temporary placeholder widget:

```dart
Widget _buildPlaceholder(String label, ColorScheme colorScheme) {
  return Container(
    height: _isExpanded ? 180 : 72,
    width: double.infinity,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    ),
    alignment: Alignment.center,
    child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
  );
}
```text
**Step 5: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
Expected: No analysis issues

**Step 6: Commit**

```

feat: add viz mode toggle and color scheme selector to tissue card

Header now shows a 3-icon mode toggle (grid, area, lines) and a
palette popup menu for color scheme selection. Both are wired to
persisted settings. Area chart and sparklines modes show placeholders.

```text
---

### Task 6: Build Stacked Area Chart Widget

Create the `TissueAreaChart` widget — a CustomPainter-based stacked area chart showing tissue loading curves over time.

**Files:**

- Create: `lib/features/dive_log/presentation/widgets/tissue_area_chart.dart`
- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart` (replace placeholder)

**Step 1: Create `tissue_area_chart.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// Stacked area chart showing tissue loading curves over time.
///
/// Compact mode shows only the leading compartment's loading curve.
/// Expanded mode shows all 16 compartments as semi-transparent filled areas.
class TissueAreaChart extends StatefulWidget {
  final List<DecoStatus> decoStatuses;
  final int? selectedIndex;
  final double height;
  final bool isExpanded;
  final TissueColorFn colorFn;
  final ValueChanged<int?>? onHoverIndexChanged;
  final ValueChanged<int?>? onCompartmentHoverChanged;

  const TissueAreaChart({
    super.key,
    required this.decoStatuses,
    this.selectedIndex,
    this.height = 72,
    this.isExpanded = false,
    required this.colorFn,
    this.onHoverIndexChanged,
    this.onCompartmentHoverChanged,
  });

  @override
  State<TissueAreaChart> createState() => _TissueAreaChartState();
}
```typescript
The state class should implement:

- Touch/hover handling (same pattern as `TissueHeatMapStrip` using `GestureDetector` + `MouseRegion`)
- Convert local position to time index: `timeIdx = (localPosition.dx / size.width * numTimePoints).floor()`
- Fire `onHoverIndexChanged` and `onCompartmentHoverChanged`

The painter (`_TissueAreaChartPainter`) should:

1. Pre-compute percentage values per (time, compartment) using `_subsurfacePercentage` (copy the formula or import it)
2. Draw a horizontal reference line at y=100% (M-value line) with `colorScheme.error`
3. **Compact mode:** Draw only the leading compartment's percentage curve as a filled area
4. **Expanded mode:** Draw all 16 compartments as filled areas with 0.15 alpha, sorted so fast compartments (low index) draw on top. The leading compartment at each time step gets a thicker opaque stroke.
5. Y-axis: 0-120% loading, mapped to canvas height
6. X-axis: time index 0 to numTimePoints, mapped to canvas width
7. Draw cursor line at `selectedIndex` (same pattern as heat map painter)

Use column sampling for performance (same pattern as `_TissueHeatMapPainter`): target ~1 column per logical pixel.

Color each area's fill using `colorFn(averagePercentage)` for that compartment's median loading value.

**Step 2: Add `_subsurfacePercentage` helper**

Either make `_subsurfacePercentage` from `tissue_heat_map.dart` a public function (rename to `subsurfacePercentage`) and import it, or duplicate it in the area chart file. Making it public and shared is cleaner:

In `tissue_color_schemes.dart`, add:

```dart
/// Two-phase tissue percentage normalization relative to ambient pressure.
double subsurfacePercentage(TissueCompartment comp, double ambientPressure) {
  final tension = comp.totalInertGas;
  if (ambientPressure <= 0) return 50.0;
  if (tension < ambientPressure) {
    return (tension / ambientPressure) * 50.0;
  } else {
    final mValue = comp.blendedA + ambientPressure / comp.blendedB;
    if (mValue <= ambientPressure) return 50.0;
    final gf = (tension - ambientPressure) / (mValue - ambientPressure);
    return 50.0 + gf * 50.0;
  }
}
```typescript
Then update `tissue_heat_map.dart` to import and use this shared version instead of the private `_subsurfacePercentage`.

**Step 3: Wire into CompactTissueLoadingCard**

In `compact_tissue_loading_card.dart`, replace the `_buildPlaceholder('Area Chart', ...)` with:

```dart
TissueVizMode.stackedArea => _buildAreaChartSection(context, colorScheme, textTheme),
```text
Implement `_buildAreaChartSection`:

```dart
Widget _buildAreaChartSection(
  BuildContext context,
  ColorScheme colorScheme,
  TextTheme textTheme,
) {
  final tissueScheme = ref.watch(tissueColorSchemeProvider);
  final colorFn = colorFnForScheme(tissueScheme);

  return TissueAreaChart(
    decoStatuses: widget.decoStatuses!,
    selectedIndex: widget.selectedIndex,
    height: _isExpanded ? 180 : 72,
    isExpanded: _isExpanded,
    colorFn: colorFn,
    onHoverIndexChanged: widget.onHeatMapHover,
    onCompartmentHoverChanged: (compIdx) {
      if (compIdx != null) {
        _setHoveredCompartment(compIdx);
      } else {
        _clearHoveredCompartment();
      }
    },
  );
}
```text
**Step 4: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/tissue_area_chart.dart lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
Expected: No analysis issues

**Step 5: Commit**

```

feat: add stacked area chart visualization for tissue loading

New TissueAreaChart widget shows tissue loading curves over time.
Compact mode shows leading compartment only. Expanded mode shows
all 16 compartments as semi-transparent filled areas with M-value
reference line. Shares subsurfacePercentage() with heat map.

```text
---

### Task 7: Build Sparklines Widget

Create the `TissueSparklines` widget — 16 individual mini-line-charts stacked vertically.

**Files:**

- Create: `lib/features/dive_log/presentation/widgets/tissue_sparklines.dart`
- Modify: `lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart` (replace placeholder)

**Step 1: Create `tissue_sparklines.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// 16 sparkline charts stacked vertically, one per tissue compartment.
///
/// Compact mode: each sparkline ~4px tall, no labels.
/// Expanded mode: each sparkline ~12px tall, compartment numbers on left,
/// M-value reference line at 100%.
class TissueSparklines extends StatefulWidget {
  final List<DecoStatus> decoStatuses;
  final int? selectedIndex;
  final double height;
  final bool isExpanded;
  final TissueColorFn colorFn;
  final ValueChanged<int?>? onHoverIndexChanged;
  final ValueChanged<int?>? onCompartmentHoverChanged;

  const TissueSparklines({
    super.key,
    required this.decoStatuses,
    this.selectedIndex,
    this.height = 72,
    this.isExpanded = false,
    required this.colorFn,
    this.onHoverIndexChanged,
    this.onCompartmentHoverChanged,
  });

  @override
  State<TissueSparklines> createState() => _TissueSparlinesState();
}
```text
The painter (`_TissueSparklinesPainter`) should:

1. Divide canvas height into 16 equal rows
2. For each compartment row:
   - Draw a thin loading-percentage line across time
   - Line color = `colorFn(percentage)` at each point (or use median loading for constant color)
   - In expanded mode: draw a thin dotted horizontal line at y=100% loading within each row
   - In expanded mode: draw compartment number (1-16) on the left margin
3. The leading compartment gets a bolder stroke width (2px vs 1px)
4. Draw cursor line at `selectedIndex`
5. Use column sampling for performance

Touch/hover handling follows the same pattern as the area chart.

**Step 2: Wire into CompactTissueLoadingCard**

Replace the sparklines placeholder:

```dart
TissueVizMode.sparklines => _buildSparklinesSection(context, colorScheme, textTheme),
```text
Implement `_buildSparklinesSection` (same pattern as area chart section but with `TissueSparklines`).

Height: `_isExpanded ? 192 : 72`.

**Step 3: Verify compilation**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/tissue_sparklines.dart lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart`
Expected: No analysis issues

**Step 4: Commit**

```text

feat: add sparklines visualization for tissue loading

New TissueSparklines widget shows 16 mini-line-charts stacked
vertically. Compact mode shows thin colored lines per compartment.
Expanded mode adds compartment labels and M-value reference lines.
Leading compartment gets a bolder stroke.

```

---

### Task 8: Final Verification

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No issues

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Format code**

Run: `dart format lib/features/dive_log/presentation/widgets/tissue_color_schemes.dart lib/features/dive_log/presentation/widgets/tissue_heat_map.dart lib/features/dive_log/presentation/widgets/tissue_area_chart.dart lib/features/dive_log/presentation/widgets/tissue_sparklines.dart lib/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart lib/features/settings/presentation/providers/settings_providers.dart lib/features/settings/data/repositories/diver_settings_repository.dart lib/core/database/database.dart`

**Step 4: Manual device testing**

Test on iPhone:

- Open a dive with profile data → scroll to Tissue Loading card
- Default should show heat map with Thermal color scheme (blue → cyan → green → yellow → red)
- Tap palette icon → switch to Diverging (blue → white → orange) → colors update immediately
- Tap palette icon → switch to Subsurface Classic → original 8-phase colors appear
- Tap grid/area/lines icons → visualization switches between modes
- Tap chevron → card expands with smooth animation
- Tap again → card collapses
- In expanded heat map mode: cells should be larger and more readable
- In area chart mode (compact): leading compartment curve visible with M-value line
- In area chart mode (expanded): all 16 compartment areas visible, translucent
- In sparklines mode (compact): 16 thin colored lines
- In sparklines mode (expanded): taller lines with compartment numbers
- Drag across any visualization: cursor syncs with dive profile chart
- Hover on tissue bar chart: compartment detail panel updates
- Settings persist: close and reopen dive → same scheme and mode
- Test with both small (~500 point) and large (~5,000 point) dives for performance
