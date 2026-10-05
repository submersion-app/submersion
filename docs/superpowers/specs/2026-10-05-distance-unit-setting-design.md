# Distance unit setting (issue #2030)

## Problem

Manage > Units lets a diver mix metric and imperial units one quantity at a
time, but there is no entry for distance. Every geographic distance in the app
(site distances in the site picker, GPS track length, tide source distance and
model resolution, recompression chamber distance, equipment geofence radius)
is rendered by `UnitFormatter.formatGeoDistance`, which picks kilometres or
miles from the **depth** unit. A diver who logs depth in feet cannot see
kilometres, and one who logs in metres cannot see miles.

Altitude has the same gap from the other side: it already has its own unit
(`AltitudeUnit`) and takes part in the metric / imperial presets, but only the
setup wizard can set it. Manage > Units has no Altitude tile.

## Decisions (approved)

| Question | Decision |
| --- | --- |
| Existing divers on upgrade | Backfill from depth unit: `feet` gives `miles`, anything else `kilometers`. Nobody's display changes on upgrade. Fresh databases default to kilometres. |
| Presets | Distance joins the Metric / Imperial presets, like altitude. Metric sets km, Imperial sets mi; a mismatch reads as Custom. The setup wizard's units step gets a Distance row. |
| Altitude tile | Added to Manage > Units in this PR (follow-up). |
| Short range in miles | Feet under one mile (today's behaviour), miles from there. Kilometres use metres under one kilometre. |

## Design

### 1. Domain

- `lib/core/constants/units.dart`: new enum
  `DistanceUnit { kilometers('km'), miles('mi') }` with `symbol` and
  `convert(double value, DistanceUnit to)` (1 mi = 1.609344 km), shaped like
  its siblings.
- `AppSettings` (`settings_providers.dart`): new field
  `final DistanceUnit distanceUnit`, default `DistanceUnit.kilometers`, carried
  by `copyWith`.
- `unitPreset`: metric requires `kilometers`, imperial requires `miles`.
- `setMetric()` / `setImperial()` set distance alongside the other units.
- `SettingsNotifier.setDistanceUnit(DistanceUnit)` persists through the usual
  `_saveSettings()` path.
- `SetupWizardDraft.applyingUnitPreset` sets distance in both presets, and
  `SetupApplyService` applies it with `setDistanceUnit`.

### 2. Persistence

- `diver_settings.distance_unit` (`diver_tables.dart`): `TextColumn`, default
  `'kilometers'`.
- Schema v263 (main shipped 261 with #2985; 262 is held by open PR #2991). The rung calls
  `_assertDistanceUnitColumn()` in `helpers/diver_migrations.dart`:
  - If the column is missing, add it, then in the same step run
    `UPDATE diver_settings SET distance_unit = 'miles' WHERE depth_unit = 'feet'`.
  - If the column exists, do nothing. The backfill can therefore run only on
    the open that creates the column, and a choice the diver makes afterwards
    is never rewritten.
  - The helper is self-guarding when `diver_settings` is absent, as the other
    diver_settings asserts are.
- The same assert is called from `beforeOpen` as the out-of-order backstop
  (a database that reached v263 before a lower rung merged). Because it is a
  no-op once the column exists, repeating it is safe.
- `DiverSettingsRepository` writes `distanceUnit` in both companion builders
  and parses it on read with a `_parseDistanceUnit` that falls back to
  `kilometers` for an unknown value.

### 3. Sync

A payload from an older peer has no `distanceUnit`. When this device already
holds the row, `_withLocalForOmitted` (#2553) fills the key from the local
row, so the diver's choice here survives. When the row is new to this device,
`_withSchemaDefaults` would fill the column's constant default, `'kilometers'`,
and a feet diver's settings would arrive in kilometres.

So for `diverSettings`, between `_withLocalForOmitted` and
`_withSchemaDefaults` (in both `upsertRecord` and the batch path), a missing
`distanceUnit` is derived from the same payload's `depthUnit`: `feet` gives
`miles`, otherwise `kilometers`. A present `distanceUnit` is never touched.

### 4. Formatting

- `UnitFormatter.formatGeoDistance` keys off `settings.distanceUnit`:
  - kilometres: `"850 m"` under 1 km, then `"1.2 km"` under 10 km, then
    `"12 km"`;
  - miles: `"800 ft"` under one mile, then `"1.2 mi"` under 10 mi, then
    `"12 mi"`.
  The numeric rules (rounding, one decimal under 10, locale-aware decimals via
  `formatFixedForDisplay`) are unchanged; only the selector changes. The doc
  comment is updated to name the distance unit.
- `formatDistance` (surface drift between entry and exit, m / ft) keeps the
  depth unit: it is a short span read alongside depths.
- Other depth-derived helpers (`heightIsMetric`, short length, wind) are out of
  scope.

### 5. UI

- Manage > Units > Individual units (`settings_page.dart`): two tiles after
  Weight, in the existing `_buildUnitTile` style:
  - **Altitude**, value `m` / `ft`, opening a picker with "Meters (m)" and
    "Feet (ft)";
  - **Distance**, value `km` / `mi`, opening a picker with
    "Kilometers (km)" and "Miles (mi)".
  The pickers follow the existing depth / weight picker dialogs. If adding
  them would push `settings_page.dart` further past the size guideline, the
  two pickers live in a new widget file under
  `lib/features/settings/presentation/widgets/`.
- Settings summary pane (`settings_summary_widget.dart`): Altitude and
  Distance rows after Weight, so the summary lists every unit the page lets
  the diver change.
- Setup wizard units step (`units_step.dart`): a Distance row after Altitude.
- New l10n keys in `app_en.arb` and every locale's ARB, with translations:
  `settings_units_altitude`, `settings_units_distance`,
  `settings_units_dialog_altitudeUnit`, `settings_units_dialog_distanceUnit`,
  `settings_units_altitude_meters`, `settings_units_altitude_feet`,
  `settings_units_distance_kilometers`, `settings_units_distance_miles`,
  `settings_summary_altitude`, `settings_summary_distance`, and
  `setup_units_distance` (the wizard row label, beside the existing
  `setup_units_altitude`). The altitude picker options say the same as
  `settings_units_depth_meters` / `settings_units_depth_feet` but get their
  own keys, so a translator can word altitude differently from depth.

### 6. Out of scope

- CSV export has no distance quantity today; nothing to change.
- The Explore query language has no distance unit; nothing to change.
- Distance inputs: the geofence radius slider stores metres and only its label
  is formatted, so it follows the new setting through `formatGeoDistance`.

## Testing (TDD)

- `DistanceUnit.convert` both ways and identity.
- `formatGeoDistance` in all four combinations of distance unit (km / mi) and
  depth unit (m / ft), covering the sub-unit threshold and the 10-unit
  decimal threshold, and under a comma-decimal locale.
- `AppSettings.unitPreset` with distance matching and mismatching each preset;
  `setMetric` / `setImperial` set distance.
- `SetupWizardDraft.applyingUnitPreset` sets distance.
- Repository round trip of `distanceUnit`, and the unknown-value fallback.
- Migration: a v261 database with one metres diver and one feet diver opens at
  v263 with `kilometers` and `miles`; changing the feet diver to kilometres and
  reopening keeps `kilometers` (no second backfill).
- Sync: a payload without `distanceUnit` and with `depthUnit: feet` hydrates
  to `miles`; with `meters` to `kilometers`; a payload carrying
  `distanceUnit` keeps it.
- Widget tests: the Altitude and Distance tiles show the current unit, their
  pickers change the setting; the summary pane shows both rows; the wizard
  step's Distance row updates the draft.
- `test/architecture/` after adding any file under `lib/`.
