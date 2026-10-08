# Enhanced Range Analysis Design

## Summary

Improve the Range Analysis panel on the dive detail page from a simple min/max/avg table to a comprehensive unified grid of stat chips showing derived metrics: elapsed time, depth delta, max descent/ascent rates, average vertical speed, gas consumed, and SAC rate.

## Current State

The `RangeStatsPanel` widget displays a 4-column table (Label | Min | Max | Avg) for:

- Depth (always shown)
- Temperature (when profile has temp data)
- Pressure (when profile has pressure data) - currently shows min/max/avg
- Heart Rate (when profile has HR data)

Stats are computed inline in `_calculateRangeStats()` from filtered profile points.

## Requirements

1. Replace the table layout with a unified grid of stat chips (2 per row)
2. Add these new metrics:
   - **Elapsed time**: duration of selected range
   - **Depth delta**: signed (end_depth - start_depth), positive = deeper
   - **Max descent rate**: fastest descent in range (m/min)
   - **Max ascent rate**: fastest ascent in range (m/min)
   - **Average vertical speed**: signed, positive = descending (m/min)
   - **Gas consumed**: pressure drop over range (bar delta, not min/max/avg)
   - **SAC rate**: respects user's SAC unit preference (L/min or bar/min)
3. Remove pressure min/max/avg (replaced by gas consumed + SAC)
4. Keep depth min/max/avg, temperature min/max, heart rate min/max
5. SAC unit respects `sacUnitProvider` from Settings > Units > SAC Rate
6. When SAC unit is volume/min but no tank volume exists, fall back to pressure/min

## Approach

Compute all metrics inline in the widget (Approach A). No new providers or services needed. The calculations are simple arithmetic over filtered profile points.

## Data Model

Expanded `_RangeStats` class:

| Field | Type | Description |
|-------|------|-------------|
| `elapsedSeconds` | `int` | endTimestamp - startTimestamp |
| `depthDelta` | `double` | endDepth - startDepth (signed: + = deeper) |
| `minDepth` | `double` | Minimum depth in range |
| `maxDepth` | `double` | Maximum depth in range |
| `avgDepth` | `double` | Average depth in range |
| `maxDescentRate` | `double` | Max descent rate (m/min, positive value) |
| `maxAscentRate` | `double` | Max ascent rate (m/min, positive value) |
| `avgVerticalSpeed` | `double` | depthDelta / elapsed minutes (m/min, signed) |
| `minTemp` | `double?` | Min temperature in range |
| `maxTemp` | `double?` | Max temperature in range |
| `pressureConsumed` | `double?` | startPressure - endPressure (bar) |
| `consumptionRate` | `double?` | pressureConsumed / elapsed minutes (bar/min) |
| `sacRate` | `double?` | SAC at surface (bar/min normalized) |
| `sacVolume` | `double?` | SAC as volume (L/min, requires tank volume) |
| `tankVolume` | `double?` | Primary tank volume (liters) |
| `minHR` | `int?` | Min heart rate in range |
| `maxHR` | `int?` | Max heart rate in range |

## UI Layout

Unified grid using `Wrap` widget with stat chips:

```text
+---- Range Analysis --------+
| 05:30 - 18:45    13:15     |
|                             |
| [Elapsed]   [Depth Delta]  |
|  13:15       +16.4 m       |
|                             |
| [Min Depth]  [Max Depth]   |
|  12.3 m       28.7 m      |
|                             |
| [Avg Depth] [Avg Vert Spd] |
|  20.1 m      +1.2 m/min   |
|                             |
| [Max Desc]   [Max Asc]    |
|  22.3 m/min   11.2 m/min  |
|                             |
| [Min Temp]   [Max Temp]   |
|  18.2 C       19.5 C      |
|                             |
| [Gas Used]   [SAC Rate]   |
|  85 bar       14.2 L/min  |
|                             |
| [Min HR]     [Max HR]     |
|  72 bpm       98 bpm      |
+-----------------------------+
```

## Calculation Logic

```text
elapsedSeconds = endTimestamp - startTimestamp
depthDelta = lastPoint.depth - firstPoint.depth  (signed)
avgVerticalSpeed = depthDelta / (elapsedSeconds / 60)  (m/min, signed)

For each consecutive pair of points in range:
  rate = (depth[i+1] - depth[i]) / ((time[i+1] - time[i]) / 60)
  maxDescentRate = max of positive rates
  maxAscentRate = abs(min of negative rates)

pressureConsumed = firstPressure - lastPressure
consumptionRate = pressureConsumed / (elapsedSeconds / 60)  (bar/min)
avgAmbientPressure = 1 + (avgDepth / 10)
sacRate = consumptionRate / avgAmbientPressure  (bar/min at surface)
sacVolume = sacRate * tankVolume  (L/min at surface, only if volume known)
```

## SAC Display Logic

1. If `sacUnit == SacUnit.litersPerMin` AND primary tank has `volume`:
   Show as `X.X {volumeSymbol}/min` using `sacVolume`
2. If `sacUnit == SacUnit.litersPerMin` but no tank volume:
   Fall back to `X.X {pressureSymbol}/min` using `sacRate`
3. If `sacUnit == SacUnit.pressurePerMin`:
   Show as `X.X {pressureSymbol}/min` using `sacRate`

This mirrors `CylinderSacCard._formatSacValue()`.

## Files Changed

| File | Change |
|------|--------|
| `range_stats_panel.dart` | Major rewrite: expanded `_RangeStats`, grid layout, SAC calc |
| `dive_detail_page.dart` | Pass `tanks` and `sacUnit` to `RangeStatsPanel` |
| `app_en.arb` + all locale files | New l10n strings for stat chip labels |

## Localization Keys

New strings needed:

- `diveLog_rangeStats_label_elapsed` - "Elapsed"
- `diveLog_rangeStats_label_depthDelta` - "Depth Delta"
- `diveLog_rangeStats_label_maxDescent` - "Max Descent"
- `diveLog_rangeStats_label_maxAscent` - "Max Ascent"
- `diveLog_rangeStats_label_avgVertSpeed` - "Avg Vert Speed"
- `diveLog_rangeStats_label_gasConsumed` - "Gas Consumed"
- `diveLog_rangeStats_label_sacRate` - "SAC Rate"
- `diveLog_rangeStats_label_minDepth` - "Min Depth"
- `diveLog_rangeStats_label_maxDepth` - "Max Depth"
- `diveLog_rangeStats_label_avgDepth` - "Avg Depth"
- `diveLog_rangeStats_label_minTemp` - "Min Temp"
- `diveLog_rangeStats_label_maxTemp` - "Max Temp"
- `diveLog_rangeStats_label_minHR` - "Min HR"
- `diveLog_rangeStats_label_maxHR` - "Max HR"
