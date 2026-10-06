# Adaptive Dive Profile Legend Row - Design

Date: 2026-08-05
Status: Approved

## Problem

The legend row above the dive profile chart (`lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`) shows at most three toggles inline (Temperature, single-tank Pressure, Events) plus a "More" popover holding roughly 25 additional toggles. On wide layouts (desktop, tablet landscape, fullscreen profile) most of the row is empty while useful toggles hide behind the popover. On narrow layouts the current `Wrap` can flow to a second line, making the legend taller.

## Goal

Fill the available legend width with as many toggles as fit, on exactly one line, never wrapping. Toggles that do not fit remain reachable through the existing popover.

## Decisions

- Selection priority: active (checked) toggles claim inline space first; remaining width is filled with inactive toggles. Both groups are ordered internally by a canonical priority list.
- Display order: the visible row always renders in canonical priority order, regardless of active state, so checking or unchecking an item never makes it change position.
- Rich popover items (NDL, TTS, CNS, Deco Stops with DC/Calc source selectors; per-tank pressure toggles) are eligible for promotion but render inline as plain checkbox + swatch + label. Source selectors remain popover-only. Per-tank toggles promote individually with their tank label.
- The popover becomes the complete catalog: Temperature, Pressure, and Events are added to its Overlays section so every toggle stays reachable even when the row is too narrow to show any of them inline.
- The More button badge counts active toggles that are not currently visible inline (previously: all active secondary toggles).
- Inline selection is derived from available width on every build. No persistence; resizing reflows immediately.

## Canonical priority order

Existence-gated (a toggle only competes if its data exists for the dive):

1. Temperature
2. Pressure (single tank) or per-tank pressure toggles in tank order (multi-tank)
3. Events
4. Ceiling
5. Deco Stops
6. NDL
7. Gas Switches
8. SAC
9. Heart Rate
10. Ascent rate colors
11. Ascent rate line
12. Max depth marker
13. TTS
14. CNS
15. Mean depth
16. GF
17. Surface GF
18. ppO2
19. ppN2
20. ppHe
21. MOD
22. Gas density
23. OTU
24. Pressure thresholds
25. Photo markers
26. Gas timeline

Ranking rationale comes from the tech-diving domain skill: temperature, pressure, events, deco ceiling, and gas switches are the profile essentials; deco metrics matter to technical divers (and only appear when the data exists); per-gas partial pressures and density are deep-analysis tools.

## Architecture

All changes live in the dive_log feature; no provider, database, or l10n changes.

### Components

1. `_LegendCandidate` (private model in `dive_profile_legend.dart`): `id`, localized `label`, `color`, `isActive`, `onTap`, `priority`. A builder function derives the candidate list from `ProfileLegendConfig` + `ProfileLegendState`.
2. Width measurement: `TextPainter` measures each label at `labelSmall` with `MediaQuery.textScalerOf(context)`. Item width = fixed chrome (checkbox icon 14 + swatch 10 + internal gaps + tap padding + wrap spacing) + measured label width. The chrome constant is declared adjacent to `_buildMetricToggle` with a comment binding the two; a few pixels of safety margin absorb drift.
3. Greedy fit: inside the existing `Expanded`, a `LayoutBuilder` provides `maxWidth`. Budget = `maxWidth` minus the always-shown Depth label width, the More button width (32), and the safety margin. Candidates sorted active-first-then-priority are admitted while their cumulative width fits. Admitted candidates render in canonical priority order in a `Row` (replacing the current `Wrap`), followed by the More button.
4. Popover (`_ChartOptionsDialog`): gains Temperature, Pressure (single-tank), and Events entries at the top of the Overlays section, reusing existing l10n labels and toggle callbacks. Otherwise unchanged.
5. Badge: computed as active candidates minus those currently admitted inline. The admitted set is computed in the legend build and passed to `_MoreOptionsButton`.

### File organization

`dive_profile_legend.dart` is at 1,167 lines, above the 800-line cap. As part of this work, `_ChartOptionsDialog` (and its helpers) moves to a new `chart_options_dialog.dart` in the same directory. The legend file keeps the row, candidate selection, and zoom controls.

### Scope

`DiveProfileLegend` has one consumer, `dive_profile_chart.dart`, so the dive detail page and fullscreen profile page both pick up the behavior automatically. The comparison chart and planner legends are out of scope.

## Constraints

- Promoted inline toggles must remain visually homogeneous (checkbox + swatch + label built by `_buildMetricToggle`). The analytic width formula depends on this; heterogeneous inline children would require a dry-layout render object instead. In particular, the gas timeline toggle keeps its four-bar swatch only in the popover; inline it renders with the standard single-color swatch.
- The row must never exceed one line height at any width or text scale.

## Error handling

No I/O or async paths. The only failure mode is measurement drift causing horizontal overflow; the safety margin plus a `Row` (which clips rather than wraps) bounds the blast radius, and widget tests assert no overflow at multiple widths and text scales.

## Testing (TDD)

Widget tests in the existing legend test file, written before implementation:

- Narrow (~360 px): only highest-priority items fit; row height equals one line; no overflow errors.
- Wide (~1200 px): inactive fillers appear beyond the active set.
- Eviction: an active low-priority toggle wins space over an inactive high-priority one.
- Order: visible toggles render in canonical order even when activation order differs.
- Popover completeness: Temperature, Pressure, and Events entries appear in the popover.
- Badge: equals the count of active toggles not visible inline.
- Accessibility: large `textScaler` still yields a single line with fewer items admitted.

Run `dart format .` and `flutter analyze` before completion.
