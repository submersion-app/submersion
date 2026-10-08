# Default Visibility for the Gas Timeline Strip

## Summary

Add an appearance setting that controls whether the gas-usage timeline strip
(the "Gases" line below the dive profile chart) is shown by default. Today every
other dive-profile legend toggle hydrates its initial value from a persisted
`settings.defaultShow…` field, but the gas strip is the lone toggle without one,
so it always starts visible via a hard-coded constructor default. This feature
fills that gap with a `defaultShowGasTimeline` setting, defaulting to **on** to
preserve current behavior.

## Goals

- Let users choose whether the gas timeline strip starts visible on the dive
  profile, configurable from Appearance > Dives > Dive Profile.
- Persist the choice per-diver in the `DiverSettings` table, consistent with the
  other `defaultShow…` profile toggles.
- Default to visible for new and existing divers (no behavior change unless the
  user opts out).

## Non-Goals

- No change to the per-dive legend toggle UX. The setting only seeds the initial
  session value; the user can still flip the gas strip on/off per dive via the
  existing legend control (`toggleGas()`), and that override stays session-only.
- No change to when gas data is *available*. The strip still renders only when
  the dive actually has gas segments and a valid duration (existing `_hasGasStrip`
  guard in `dive_profile_chart.dart`).
- No new localization translations beyond the English template; other locales
  fall back to English following the project's current practice for new keys.

## Design

### Data Layer

**DiverSettings table** -- add one column:

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `defaultShowGasTimeline` | bool | `true` | Initial visibility of the gas-usage timeline strip on the dive profile |

**Database migration:** Increment `currentSchemaVersion` from 74 to 75, append
`75` to the `migrationVersions` list, and add an `if (from < 75)` block running:

```sql
ALTER TABLE diver_settings ADD COLUMN default_show_gas_timeline INTEGER NOT NULL DEFAULT 1
```

This follows the existing settings-column migration pattern in `database.dart`
(boolean stored as `INTEGER`, default `1` = true), e.g. `show_data_source_badges`.

**AppSettings** -- add matching field:

- `bool defaultShowGasTimeline` (default: `true`), included in the constructor
  default and in `copyWith`.

**SettingsNotifier** -- add setter method:

- `setDefaultShowGasTimeline(bool value)`

**DiverSettingsRepository** -- update three methods, mirroring
`defaultShowGasSwitchMarkers`:

- `_mapRowToAppSettings()` -- read the new column into `AppSettings`
- `createSettingsForDiver()` -- include the default value for the new column
- `updateSettingsForDiver()` -- persist the new column value

### Behavior Wiring

`ProfileLegend.build()` in `profile_legend_provider.dart` already initializes
each toggle from settings. Add the single missing line so the gas strip hydrates
from the new setting instead of the constructor default:

```dart
showGas: settings.defaultShowGasTimeline,
```

The constructor default (`showGas = true`) and `toggleGas()` are unchanged. Because
`build()` watches `settingsProvider`, changing the setting re-seeds the session
state -- identical to how every sibling toggle already behaves.

### Settings UI

In `section_appearance_page.dart`, add a `SwitchListTile` to the Dive Profile
section, placed immediately after the existing **Gas Switch Markers** toggle so the
gas-related options are grouped:

```dart
SwitchListTile(
  title: Text(context.l10n.settings_appearance_gasTimeline),
  subtitle: Text(context.l10n.settings_appearance_gasTimeline_subtitle),
  secondary: const Icon(Icons.timeline),
  value: settings.defaultShowGasTimeline,
  onChanged: (value) {
    ref.read(settingsProvider.notifier).setDefaultShowGasTimeline(value);
  },
),
```

**Localization** -- add to `lib/l10n/arb/app_en.arb`:

- `settings_appearance_gasTimeline`: `"Gas timeline"`
- `settings_appearance_gasTimeline_subtitle`: `"Show the gas-usage strip below the dive profile by default"`

(Wording aligns with the legend's "Gases" line; the secondary icon mirrors the
strip's purpose. Final icon/wording can be adjusted during implementation.)

### Default for New and Existing Divers

- `defaultShowGasTimeline`: `true` (existing divers' migrated rows default to `1`,
  so the gas strip continues to appear exactly as it does today).

## Testing Strategy

- **Migration test** (`test/core/database/migration_v75_gas_timeline_test.dart`,
  mirroring `migration_v74_datasource_gps_test.dart`): open a v74 database, run the
  upgrade, and assert `default_show_gas_timeline` exists and resolves to `true` for
  pre-existing rows.
- **Provider test:** `ProfileLegend.build()` yields `showGas == false` when
  `defaultShowGasTimeline` is `false`, and `true` when it is `true`.
- **Repository round-trip test:** persisting `defaultShowGasTimeline = false` via
  `updateSettingsForDiver()` and reading it back returns `false` (alongside the
  existing `defaultShow…` field coverage, if present).
- **Widget test:** the Dive Profile settings section renders the new toggle,
  reflects the persisted value, and calls `setDefaultShowGasTimeline` on tap.

## Key Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add `defaultShowGasTimeline` column to `DiverSettings`; bump `currentSchemaVersion` to 75; append `75` to `migrationVersions`; add `if (from < 75)` migration block |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add `defaultShowGasTimeline` field + default to `AppSettings` and `copyWith`; add `setDefaultShowGasTimeline` to `SettingsNotifier` |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | Map the new column in `_mapRowToAppSettings()`, `createSettingsForDiver()`, `updateSettingsForDiver()` |
| `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` | Add `showGas: settings.defaultShowGasTimeline` to `build()` |
| `lib/features/settings/presentation/pages/section_appearance_page.dart` | Add `SwitchListTile` for the gas timeline default, after Gas Switch Markers |
| `lib/l10n/arb/app_en.arb` | Add `settings_appearance_gasTimeline` and `_subtitle` keys |
| New: `test/core/database/migration_v75_gas_timeline_test.dart` | Migration test for the new column |
| `test/features/dive_log/presentation/providers/profile_legend_provider_test.dart` (or existing equivalent) | Assert `showGas` hydrates from the setting |

## Build / Format

After editing the Drift table and providers, run
`dart run build_runner build --delete-conflicting-outputs` (regenerates
`database.g.dart`, `profile_legend_provider.g.dart`, and the localization
delegates) and `dart format .` before committing.
