# Design: Expanded Standard Table Preset

**Date:** 2026-04-09
**Status:** Draft

## Summary

Expand the built-in "Standard" table preset from 6 columns to 22, providing a
more comprehensive default view of dive data. The new preset groups columns by
category (core, gas/tank, environment, people, metadata) so related data is
scannable without hunting.

## Motivation

The current 6-column Standard preset (Dive #, Site, Date, Max Depth, Bottom
Time, Water Temp) is minimal. Divers frequently want to see gas data, buddy
info, ratings, and environmental conditions without manually adding columns.
A richer default reduces first-use friction and showcases the table's
capabilities.

## Changes

### File: `lib/features/dive_log/domain/entities/view_field_config.dart`

Two locations need the same column list update:

#### 1. `TableViewConfig.defaultConfig()` (line ~59)

Replace the 6-column default with the 22-column list below.

#### 2. `builtInTablePresets()` > `standard` variable (line ~259)

Replace the 6-column Standard preset with the same 22-column list.

### New Standard Column List (ordered)

| # | DiveField enum value | Pinned | Category |
|---|----------------------|--------|----------|
| 1 | `diveNumber` | Yes | Core |
| 2 | `siteName` | Yes | Core |
| 3 | `dateTime` | No | Core |
| 4 | `diveTypeName` | No | Core |
| 5 | `maxDepth` | No | Core |
| 6 | `avgDepth` | No | Core |
| 7 | `runtime` | No | Core |
| 8 | `surfaceInterval` | No | Core |
| 9 | `primaryGas` | No | Gas/Tank |
| 10 | `startPressure` | No | Gas/Tank |
| 11 | `endPressure` | No | Gas/Tank |
| 12 | `sacRate` | No | Gas/Tank |
| 13 | `waterTemp` | No | Environment |
| 14 | `visibility` | No | Environment |
| 15 | `currentStrength` | No | Environment |
| 16 | `entryMethod` | No | Environment |
| 17 | `buddy` | No | People |
| 18 | `diveMaster` | No | People |
| 19 | `tripName` | No | Metadata |
| 20 | `ratingStars` | No | Metadata |
| 21 | `tags` | No | Metadata |
| 22 | `notes` | No | Metadata |

### Removed from previous Standard preset

- `bottomTime` -- redundant with `runtime`, which captures the full dive
  duration including ascent/deco phases.

### Not changed

- **Technical preset** -- remains unchanged (9 columns focused on gas/deco).
- **Planning preset** -- remains unchanged (7 columns focused on logistics).
- **Column widths** -- each field already has a default width defined in
  `dive_field_column_sizing.dart`; no width overrides needed.
- **Existing user configs** -- users who have already customized their table
  view keep their saved configuration. Only new divers or users who reset to
  the Standard preset are affected.

## Testing

- Verify the Standard preset renders all 22 columns with correct headers.
- Verify horizontal scrolling works with the wider column set.
- Verify "Reset to Standard" applies the new 22-column layout.
- Verify the Technical and Planning presets are unaffected.
- Update the `defaultConfig()` doc comment from "6 standard columns" to
  "22 standard columns".
