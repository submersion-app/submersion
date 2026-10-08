# Default Tank Preset for New and Imported Dives

## Summary

Add the ability for users to set a default tank preset (e.g., AL80) that is automatically applied when creating new dives and optionally used as a per-field fallback for imported dives with incomplete tank data.

## Goals

- Let users select a default tank preset so new dives start with their typical tank configuration
- Provide an opt-in setting to apply the default preset as a fallback for imported dives missing tank fields
- Default to AL80 for new divers

## Non-Goals

- Full tank template (gas mix, start pressure, role) -- only physical tank attributes from the preset (volume, working pressure, material)
- Overriding import data that already has valid tank information

## Design

### Data Layer

**DiverSettings table** -- add two columns:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `defaultTankPreset` | text (nullable) | `'al80'` | Preset name string (e.g., `'al80'`, `'hp100'`, or a custom preset name) |
| `applyDefaultTankToImports` | bool | `false` | Whether to fill missing tank fields from default preset during import |

**Database migration:** Increment `currentSchemaVersion` and add migration block with `ALTER TABLE diver_settings ADD COLUMN` for both new columns, following the existing migration pattern in `database.dart`.

**Legacy fields:** The existing `defaultTankVolume` and `defaultStartPressure` fields in `DiverSettings` remain as read-only fallbacks. They are not updated when a preset is selected, and they are not exposed in the UI. They serve only as fallback values when `defaultTankPreset` is null or resolution fails. The preset takes precedence when set.

**AppSettings** -- add matching fields:

- `String? defaultTankPreset` (default: `'al80'`)
- `bool applyDefaultTankToImports` (default: `false`)

**SettingsNotifier** -- add setter methods:

- `setDefaultTankPreset(String? presetName)`
- `setApplyDefaultTankToImports(bool value)`

**DiverSettingsRepository** -- update three methods:

- `_mapRowToAppSettings()` -- read new columns into `AppSettings`
- `createSettingsForDiver()` -- include default values for new columns
- `updateSettingsForDiver()` -- persist new column values

**Preset resolution** -- a utility function that resolves a preset name to a `TankPresetEntity?`:

1. Check built-in presets via `TankPresets.byName(name)`, wrapping with `TankPresetEntity.fromBuiltIn()` if found
2. Check custom presets via `TankPresetRepository` (per-diver)
3. Return `null` if not found (stale reference) -- caller falls back to legacy `defaultTankVolume` (12L) and `defaultStartPressure` (200 bar)

The return type is always `TankPresetEntity?` for a uniform API, since `TankPresetEntity.fromBuiltIn()` already bridges the built-in `TankPreset` type.

### New Dive Tank Creation

The `_addTank()` method in `dive_edit_page.dart` (line 1823) currently hard-codes `volume: 12.0` and `startPressure: 200`.

**Important distinction:** A tank preset provides the physical tank attributes -- `volumeLiters` (water volume) and `workingPressureBar` (rated pressure) and `material`. The `startPressure` (actual fill pressure for a specific dive) is a separate concept and comes from `defaultStartPressure` in settings, not from the preset.

Updated behavior:

1. Read current `AppSettings` to get `defaultTankPreset` and `defaultStartPressure`
2. If a preset is set, resolve it to get `volumeLiters`, `workingPressureBar`, and `material`
3. Create `DiveTank` with:
   - `volume` from preset's `volumeLiters`
   - `workingPressure` from preset's `workingPressureBar`
   - `material` from preset's `material`
   - `startPressure` from `defaultStartPressure` setting (independent of preset)
   - `presetName` set to the preset's `name`
4. If no preset is set (or resolution fails), fall back to legacy `defaultTankVolume` / `defaultStartPressure`

**Async consideration:** Resolving custom presets requires a database query via `TankPresetRepository`, making resolution async. To avoid making `_addTank()` async, the resolved default preset should be pre-fetched when the `DiveEditPage` loads (in `initState` or via a Riverpod provider) and cached as widget state. The `_addTank()` method then reads from the cached value synchronously.

Unchanged: gas mix stays as `GasMix()` (air), role logic stays the same (first = backGas, subsequent = stage).

### Import Fallback Behavior

**Gated by** `applyDefaultTankToImports` setting (default: off).

When enabled and dives are imported with incomplete tank data, missing fields are filled from the default preset on a **per-field** basis:

1. After parsing tank data from the source format, check each field:
   - If `volume` is missing/zero -- fill from default preset's `volumeLiters`
   - If `workingPressure` is missing/zero -- fill from default preset's `workingPressureBar`
   - If `material` is missing/null -- fill from default preset's `material`
2. If `startPressure` is missing/zero -- fill from `defaultStartPressure` setting (independent of preset)
3. Fields that **do** have values in the import data are left untouched
4. If no default preset is configured or resolution fails, fall back to existing hard-coded defaults

When the setting is disabled (default), imports behave exactly as they do today.

**Centralized utility:** A shared function handles the per-field fallback logic. All import paths call this utility after initial parsing rather than duplicating the logic. Current parsers: UDDF (`uddf_import_parser.dart`), CSV (`csv_import_parser.dart`), FIT (`fit_import_parser.dart`), Subsurface XML (`subsurface_xml_parser.dart`). The placeholder parser does not need modification. Any future parsers should also call this utility.

### Settings UI

**Tank Presets page** (`tank_presets_page.dart`) -- two additions:

1. **Default preset indicator and selector** -- each preset in the list gets a trailing icon button (e.g., filled/outlined star) indicating whether it is the current default. Tapping the star on a non-default preset sets it as the new default. The current default preset is visually distinguished (e.g., filled star icon). AL80 is the default out of the box. Both built-in and custom presets can be set as the default.
2. **"Apply default tank to imported dives" toggle** -- a `SwitchListTile` at the top of the page (or in a header section) controlling the `applyDefaultTankToImports` setting. Placed on this page so all tank preset configuration lives in one place.

**No changes to the main Settings page** -- all tank preset settings are managed from Settings > Manage > Tank Presets.

### Custom Preset Deletion

When a user deletes a custom preset that is currently set as the default:

- Show a confirmation dialog that mentions the preset is the current default
- If confirmed, delete the preset and reset `defaultTankPreset` to `'al80'` (the built-in default)
- Built-in presets cannot be deleted, so this only applies to custom presets

### Default for New Divers

- `defaultTankPreset`: `'al80'`
- `applyDefaultTankToImports`: `false`

## Testing Strategy

- **Unit tests:** Preset resolution logic -- valid built-in preset, custom preset, stale/deleted preset fallback, null preset
- **Unit tests:** Per-field import fallback -- each combination of present/missing fields, with toggle on and off
- **Unit tests:** Custom preset deletion resets default to AL80
- **Widget tests:** Tank Presets page shows default indicator (star), allows changing default
- **Widget tests:** Toggle for "Apply default tank to imported dives" persists correctly
- **Widget tests:** Deletion of default custom preset shows warning and resets to AL80
- **Integration tests:** `_addTank()` creates tank with correct preset values (volume, workingPressure, material from preset; startPressure from settings)
- **Integration tests:** Import paths apply/skip defaults based on the toggle setting

## Key Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add `defaultTankPreset` and `applyDefaultTankToImports` columns to `DiverSettings`; increment schema version; add migration block |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add fields to `AppSettings`, setters to `SettingsNotifier` |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Update `_mapRowToAppSettings()`, `createSettingsForDiver()`, `updateSettingsForDiver()` |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Pre-fetch resolved preset on load; update `_addTank()` to use cached preset values |
| `lib/features/tank_presets/presentation/pages/tank_presets_page.dart` | Default indicator (star icon), selector, import toggle, deletion warning for default preset |
| `lib/features/tank_presets/presentation/providers/tank_preset_providers.dart` | Expose default preset state |
| `lib/features/universal_import/data/parsers/uddf_import_parser.dart` | Call shared fallback utility |
| `lib/features/universal_import/data/parsers/csv_import_parser.dart` | Call shared fallback utility |
| `lib/features/universal_import/data/parsers/fit_import_parser.dart` | Call shared fallback utility |
| `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` | Call shared fallback utility |
| New: shared import tank fallback utility | Centralized per-field fallback logic, returns `TankPresetEntity?` |
