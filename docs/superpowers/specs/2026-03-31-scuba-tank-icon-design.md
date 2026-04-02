# Scuba Tank Icon Replacement

**Issue:** [submersion-app/submersion#109](https://github.com/submersion-app/submersion/issues/109)
**Date:** 2026-03-31

## Problem

The current tank icon (`Icons.propane_tank`) resembles a BBQ propane tank rather
than a scuba tank. This is a cosmetic issue that affects the app's domain
authenticity for divers.

## Solution

Replace `Icons.propane_tank` with `MdiIcons.divingScubaTank` from the
`material_design_icons_flutter` package. This icon is designed in Material Design
style and depicts an actual scuba tank.

## Approach: MDI Community Package

The `material_design_icons_flutter` package is the community extension of
Google's Material Design icon set. It provides 7000+ icons following the same
design language. Flutter tree-shakes unused glyphs, so bundle size impact is
minimal.

## Changes

### 1. Add Dependency

Add `material_design_icons_flutter` to `pubspec.yaml` under `dependencies`.

### 2. Replace Icon References (~21 locations)

Replace all `Icons.propane_tank` references with `MdiIcons.divingScubaTank`.

**Affected files:**

| File | Context |
|------|---------|
| `lib/features/tank_presets/presentation/pages/tank_presets_page.dart` | Tank list icons (filled + outlined toggle) |
| `lib/features/statistics/presentation/pages/statistics_gas_page.dart` | Gas statistics section icons |
| `lib/features/dive_planner/presentation/widgets/plan_tank_list.dart` | Dive planner tank list |
| `lib/features/dive_planner/presentation/widgets/gas_results_panel.dart` | Gas results display |
| `lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart` | Per-cylinder SAC metrics |
| `lib/features/dive_log/presentation/pages/dive_search_page.dart` | Search filter icons |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Dive detail tank sections |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Dive edit tank sections |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | Equipment type icon mapping |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` | Equipment detail icon mapping |
| `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` | Equipment set detail icon mapping |
| `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` | Equipment set edit icon mapping |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Settings icon |
| `lib/features/settings/presentation/pages/settings_page.dart` | Settings icon |

### 3. Outlined Variant Handling

The tank presets page toggles between `Icons.propane_tank` and
`Icons.propane_tank_outlined` based on edit state. If MDI does not provide a
separate outlined variant of `divingScubaTank`, use the filled variant in both
states -- the edit/view state is already conveyed by other UI cues.

### 4. Event Icon String

Update the `eventIconName` string for `ProfileEventType.lowGas` in
`lib/core/constants/enums.dart` from `'propane_tank'` to `'diving_scuba_tank'`
for consistency. This string is used as a label reference on profile chart event
markers, not resolved to `IconData`.

## Out of Scope

- Replacing any other Material icons with MDI equivalents
- Creating custom icon variants (outlined, rounded, sharp)
- Adding additional dive-specific icons beyond the tank
