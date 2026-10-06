# Tissue Heat Map Visualization Redesign - Design Document

## Problem

The current tissue loading heat map uses Subsurface's 8-phase HSV color scale (cyan -> blue -> purple -> magenta -> black -> green -> yellow -> orange -> red -> white). This is unintuitive for most users: too many color phases, a non-monotonic brightness curve with black in the middle, and unexpected colors like purple/magenta in what should read as a heat map.

Additionally, the 2D grid is the only way to visualize tissue loading over time. Other representations could better serve different analytical questions divers have.

## Goals

1. Replace the default color scheme with something intuitive
2. Keep the Subsurface scheme as a legacy option
3. Offer multiple visualization modes for different analytical needs
4. Add expandable compact/detailed views
5. Maintain all existing interaction behaviors (tooltips, crosshair sync, compartment highlighting)

## Non-Goals

- Changing the underlying decompression algorithm or data model
- Modifying the tissue pressure bar chart or compartment detail panel
- Adding new data sources (e.g., heart rate overlay)

---

## Design

### Part 1: Color Palette System

Three selectable color schemes, each emphasizing a different signal. Stored as a user preference.

#### Scheme 1: Thermal (new default)

Emphasizes **danger proximity** — how close each tissue is to its M-value limit. Simple cool-to-warm gradient with 4 phases using `Color.lerp` for smooth transitions.

| Range | Colors | Meaning |
|-------|--------|---------|
| 0-50% | Blue (#1565C0) -> Cyan (#00ACC1) | Ongassing, tissue below ambient |
| 50-80% | Green (#66BB6A) -> Yellow (#FFEE58) | Mild to moderate offgassing |
| 80-100% | Yellow (#FFEE58) -> Red (#EF5350) | Approaching M-value |
| 100%+ | Red (#EF5350) -> White (#FFFFFF) | M-value exceeded |

#### Scheme 2: Diverging

Emphasizes **on/off-gassing state** — a two-tone scale centered on the equilibrium boundary (50%).

| Range | Colors | Meaning |
|-------|--------|---------|
| 0-50% | Deep Blue -> Light Blue -> near-White | Ongassing (intensity = distance below ambient) |
| 50% | Near-white center | At equilibrium |
| 50-100% | Light Orange -> Deep Orange -> Red | Offgassing (intensity = proximity to M-value) |
| 100%+ | Red -> White | M-value exceeded |

#### Scheme 3: Subsurface Classic

The existing 8-phase HSV algorithm, unchanged. For users familiar with Subsurface's desktop software.

#### Color Scheme Abstraction

```dart
typedef TissueColorFn = Color Function(double percentage);
```dart
Three implementations: `thermalColor()`, `divergingColor()`, `subsurfaceHeatColor()` (existing). The active function is selected by preference and passed to all visualization widgets.

---

### Part 2: Visualization Modes

Three visualization modes, all using the selected color palette. Each starts compact (72px) and expands on tap.

#### Mode 1: Heat Map Grid (existing, improved)

The current 2D grid (time x compartments) with the new color scheme applied.

- **Compact (72px):** Same as today but with selected color scheme
- **Expanded (144px):** Taller cells for better compartment readability. Adds thin horizontal divider lines between rows and a subtle vertical marker at the maximum depth point

#### Mode 2: Stacked Area Chart

Time-series chart showing tissue loading curves for all 16 compartments as layered, semi-transparent filled areas.

- **Compact (72px):** Shows just the aggregate envelope — leading compartment's loading curve + M-value reference line. A simplified "how close to danger" view.
- **Expanded (180px):** All 16 compartments as individual translucent filled curves. Faster compartments (1-4) drawn on top. M-value threshold line at 100% loading. Leading compartment gets a thicker/opaque stroke.

Key behaviors:

- Y-axis: 0-120% loading
- X-axis: time (matches dive profile)
- Rising curves = ongassing, falling = offgassing
- Colors driven by selected palette (each area tinted by its loading level)
- Tap/drag: same crosshair sync as heat map

#### Mode 3: Compartment Sparklines

16 individual mini-line-charts, one per compartment, stacked vertically.

- **Compact (72px):** Each sparkline ~4px tall. Loading curve as a colored line, like an equalizer display. Line color reflects loading level from selected palette.
- **Expanded (192px):** Each sparkline ~12px tall with M-value reference line at 100%. Compartment numbers visible on left margin. Hovering highlights that compartment and shows tooltip.

Key behaviors:

- Each sparkline Y-axis: 0-120% loading
- Leading compartment gets bolder stroke
- Tap/drag: same crosshair sync

---

### Part 3: Widget Architecture

```

CompactTissueLoadingCard (existing, modified)
+-- Header Row
|   +-- "Tissue Loading" title
|   +-- Viz Mode Toggle (new: 3 icon buttons)
|   +-- Color Scheme Selector (new: paint-drop icon -> popup menu)
|   +-- Expand/Collapse chevron (new)
+-- Visualization Area (switched by mode)
|   +-- TissueHeatMapStrip (existing, refactored for color fn)
|   +-- TissueAreaChart (new widget)
|   +-- TissueSparklines (new widget)
+-- Legend (adapts to color scheme)
+-- Compartment Detail Panel (existing, unchanged)

```dart
#### New Files

| Widget | File | Responsibility |
|--------|------|---------------|
| `TissueAreaChart` | `tissue_area_chart.dart` | Stacked area using CustomPainter |
| `TissueSparklines` | `tissue_sparklines.dart` | 16 sparklines using CustomPainter |

Both follow the same pattern as `TissueHeatMapStrip`: accept `decoStatuses`, `selectedIndex`, `colorFn`, `height`; support `onHoverIndexChanged` and `onCompartmentHoverChanged`; use `CustomPainter` with `shouldRepaint`.

#### Modified Files

| File | Changes |
|------|---------|
| `tissue_heat_map.dart` | Add `thermalColor()`, `divergingColor()` functions. Refactor `TissueHeatMapStrip` to accept `TissueColorFn`. Update legend to accept color fn. |
| `compact_tissue_loading_card.dart` | Add mode toggle, color scheme selector, expand/collapse. Switch visualization widget based on mode. |
| Database/preferences | Add `tissueColorScheme` and `tissueVizMode` preference fields |
| Providers | Add `tissueColorSchemeProvider` and `tissueVizModeProvider` |

---

### Part 4: Settings & Preferences

#### New Enums

```dart
enum TissueColorScheme { thermal, diverging, classic }
enum TissueVizMode { heatMap, stackedArea, sparklines }
```dart
#### Storage

Stored via the existing diver preferences system as Riverpod providers. Persisted to the database.

#### Defaults

- Color scheme: `thermal` (new intuitive default)
- Visualization mode: `heatMap` (preserves current behavior)
- Expanded state: `false` (compact by default, not persisted across restarts)

---

### Part 5: Legend & Interaction

#### Legend Adapts to Color Scheme

- **Thermal:** Gradient bar blue -> cyan -> green -> yellow -> red -> white, labeled "Safe" / "Danger"
- **Diverging:** Two-tone gradient blue -> white -> orange -> red, labeled "On-gassing" / "Off-gassing"
- **Classic:** Current gradient bar with "On-gassing" / "Off-gassing" (unchanged)

All visualization modes (heat map, area, sparklines) use the same legend since their colors come from the same palette function.

#### Expand/Collapse

- Tap visualization area or chevron icon to toggle
- AnimatedContainer with ~200ms transition
- Expanded heights: Heat Map 144px, Stacked Area 180px, Sparklines 192px
- State local to session (not persisted)

#### Interaction (all modes)

- Tap/drag: tooltip + crosshair sync with dive profile chart
- Compartment hover: syncs with tissue bar chart
- Same callbacks: `onHoverIndexChanged`, `onCompartmentHoverChanged`

---

### Part 6: Header Layout

```text

[Tissue Loading]  [grid|area|lines]  [palette-icon]  [chevron]

```

- **Mode toggle:** 3 small icon buttons (outlined inactive, filled active). Icons: grid, area chart, sparkline
- **Palette selector:** Paint-drop icon -> popup menu listing 3 scheme names with color preview swatches
- **Chevron:** Expand/collapse indicator, rotates on toggle

---

## Implementation Order

1. Color palette system (new color functions + refactor heat map to accept color fn)
2. Settings/preferences (enums, providers, DB migration)
3. UI controls in card header (mode toggle, palette selector, expand/collapse)
4. Stacked area chart widget
5. Sparklines widget
6. Legend updates
7. Final verification and testing
