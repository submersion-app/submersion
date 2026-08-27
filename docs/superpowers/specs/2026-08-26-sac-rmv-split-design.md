# SAC and RMV as Separate Quantities: Design

**Status:** design approved in chat 2026-08-26; spec awaiting review
**Discussions:** #354 (Splitting SAC Rate), #803 (Adapt the SAC/AMV label to
the selected unit)
**Branch:** `worktree-sac-rmv-split`
**Builds on:** PR #305 (multi-tank SAC aggregation), PR #1298 (RMV fallback
and the tank-volume hint). Both are merged and on `origin/main`.

## Problem

The app has one "SAC rate" value with a unit preference (Settings > Units >
SAC Rate) that switches between `L/min` and `bar/min`. The two are not the
same quantity in different units:

- **Pressure per minute** (bar/min, psi/min) is a tank-pressure drop rate. It
  depends on the cylinder's size, and on a multi-tank dive it is only
  meaningful for a single cylinder. MacDive and the wider industry call this
  **SAC**.
- **Volume per minute** (L/min, cuft/min) is the gas volume the diver breathes
  at the surface. It is a property of the diver, not the cylinder, and on a
  multi-tank dive it is correctly summed across every cylinder. MacDive calls
  this **RMV**.

Treating them as one value forced PR #305 into an asymmetric rule (volume sums
all tanks, pressure uses back gas only) that has to be explained rather than
seen, and forces the label to be wrong in one of the two modes: in pressure
mode the English UI prints "SAC 12 bar/min" (defensible) and the German UI
prints "AMV 12 bar/min", which labels a pressure rate with the German word for
breathing minute volume. Discussion #354 asks for the two to be represented
separately, the way MacDive gives each its own column. Discussion #803 asks for
the label to at least follow the unit.

This design makes SAC and RMV two named quantities, each with a fixed unit
family, and replaces the unit preference with a display preference that picks
which of them single-value surfaces show.

## Findings

Every claim below was verified against `origin/main` at 80f07e66f2f.

**F1. Both quantities are already computed, separately, on the fly.**
`Dive.sacFor(GasModel)` (`dive.dart:365`) returns L/min at the surface, summing
gas across every tank that has both pressures and a volume, using the active
gas model. `Dive.sacPressure` (`dive.dart:421`) returns bar/min at the surface
from one reference tank, chosen by `Dive.sacReferenceTank` (`dive.dart:422`,
from PR #1298): the sole tank, else the `backGas` role, else the first.
Neither value is stored. There is no `sac` column on `dives`; statistics
recompute in SQL, and `DiveSummary` carries no SAC, so list rows need the full
`Dive`.

**F2. `SacUnit` is a display selector, not a unit.** It is declared at
`lib/core/constants/units.dart:107` with two values, `litersPerMin` and
`pressurePerMin`, and roughly fifteen call sites fork on it to decide which
getter to read: the detail SAC row, the SAC-by-segment card, the cylinders
card, the range-stats panel, the profile chart (axis, legend, tooltip), the
dive table sort comparator and cell, the list card, the three statistics
providers, the settings tile, and the setup wizard.

**F3. The statistics layer already has both lanes.** `StatisticsRepository`
exposes `getSacVolumeTrend` / `getSacPressureTrend`,
`getSacVolumeRecords` / `getSacPressureRecords`, and
`getSacVolumeByTankRole` / `getSacPressureByTankRole`. The providers pick a
pair member by preference.

**F4. The dive table has one column slot, and layouts persist enum names.**
`DiveField.sacRate` (`dive_field.dart:65`) is the only consumption column.
`EntityTableViewConfig.fromJson` resolves column names through the adapter's
`fieldFromName`, which is `firstWhere` with no `orElse`, so an unknown name
throws during provider init. Layouts live as JSON in `view_configs.config_json`
(one row per diver and view mode, with an `hlc`), and that table is part of
the sync payload (`sync_data_serializer.dart:917`), so a layout written by an
older build can arrive after this device has migrated. `TripField` already
carries a `_legacyNames` alias map for exactly this case (PR #1115).

**F5. The default is inconsistent.** The `diver_settings.sac_unit` column
defaults to `'litersPerMin'`; `AppSettings` (`settings_providers.dart:473`)
and the repository parse fallback both default to `SacUnit.pressurePerMin`.
Because the repository writes the whole settings row on first save, a user who
never opened the picker has `pressurePerMin` stored and cannot be told apart
from one who chose it.

**F6. German already says AMV everywhere.** Every German label for the
quantity is `AMV` (Atemminutenvolumen, literally breathing minute volume, which
is the volume lane). `test/l10n/german_sac_terminology_test.dart` forbids the
string "SAC" anywhere in `app_de.arb` except the BSAC agency name.

**F7. Planning and calculators are volume-only and never read `SacUnit`.**
`DivePlan.sacBottom` / `sacDeco` / `sacStressed` (persisted columns and
plan-file keys), the dive planner's SAC slider, the gas-consumption and
rock-bottom calculators, `loggedAverageSacProvider` (which feeds the planner
from `getSacVolumeByTankRole`), the pSCR breathing config, and the
data-quality threshold are all L/min. Only their labels are wrong.

**F8. No exporter emits SAC** (CSV, PDF, UDDF, Excel, KML, GPX all build their
own field lists). The universal importer accepts a `sac` CSV target field, but
nothing consumes it because there is no column to store it in.

**F9. The profile chart has one consumption curve.** `ProfileRightAxisMetric.sac`
(`profile_metrics.dart:30`) is computed in bar/min by
`ProfileAnalysisService._calculateSacCurve` and converted to L/min for display
using the first tank with a volume. A legend toggle (`showSac`, defaulted by the
persisted `defaultShowSac` setting) shows or hides it.

**F10. Ten surfaces format the value by hand** instead of through
`UnitFormatter.convertSac` / `sacSymbol`: the detail row, the segment card, the
cylinders card, three sections of the statistics page, the settings tile, three
places in the profile chart, and the planner gas section. Each composes
`'${units.volumeSymbol}/min'` or its pressure twin itself.

**F11. PR #1298 already made the detail row two-lane.** Under L/min with no
tank volume it now renders the pressure value plus a tappable `SacVolumeHint`
(`sac_volume_hint.dart`) instead of hiding, and the segment card uses
`volumeForSegment` (an attributed segment converts by its own cylinder;
unattributed segments by `sacReferenceTank`). This design keeps that behavior.

## Design

### D1. Terminology and domain model

| Quantity | Meaning | Unit family | Getter | Tank rule |
| --- | --- | --- | --- | --- |
| **SAC** | surface air consumption as a tank-pressure drop rate | pressure/min, following the pressure unit (`bar/min`, `psi/min`) | `Dive.sac` | one reference tank via `sacReferenceTank` |
| **RMV** | respiratory minute volume, surface-referenced gas volume breathed | volume/min, following the volume unit (`L/min`, `cuft/min`) | `Dive.rmvFor(gasModel)` | sums every tank with both pressures and a volume |

This is MacDive's convention. Agencies disagree on the words, so the settings
picker says what each one measures rather than relying on the acronym alone.

The two are not unit conversions of each other on multi-tank dives, and no
surface implies they are. On a single-tank dive with a volume, RMV equals SAC
times cylinder size up to the real-gas correction, which is what most
recreational divers will see.

Availability, unchanged from today but now stated:

- SAC exists whenever the reference tank has a start and end pressure.
  Dive-computer downloads that carry pressure always qualify.
- RMV exists only when at least one pressure-bearing tank has a volume. When
  it does not, the RMV lane renders the `SacVolumeHint` from PR #1298 rather
  than disappearing.
- Per-cylinder (`CylinderSac.sacRate` bar/min, `CylinderSac.rmv` L/min) and
  per-segment (`SacSegment.sacRate` bar/min, converted by the segment's own
  cylinder volume) values keep their current semantics.

Code naming follows the lanes. Identifiers that are bar/min keep or gain
`sac`; identifiers that are L/min get `rmv`:

- `Dive.sacPressure` becomes `Dive.sac`; `Dive.sacFor(model)` becomes
  `Dive.rmvFor(model)`; `CylinderSac.sacVolume` becomes `CylinderSac.rmv`.
- `UnitAxis.normalSac` / `stressedSac` become `normalRmv` / `stressedRmv`
  (not persisted, free to rename).
- Persisted planner fields (`DivePlan.sacBottom`, `sacDeco`, `sacStressed`,
  their Drift columns and plan-file keys) and the calculator provider names
  are **not** renamed. Renaming them means a migration and a file-format
  change with no user-visible benefit. Their UI labels do change to RMV.

### D2. The preference

`SacUnit` is deleted. `lib/core/constants/units.dart` gains:

```dart
/// Which consumption lane a value belongs to.
enum GasConsumptionLane { sac, rmv }

/// Which lanes single-value surfaces show.
enum GasConsumptionDisplay {
  sac,
  rmv,
  both;

  bool get showsSac => this != rmv;
  bool get showsRmv => this != sac;

  /// Lanes in render order; SAC first when both are shown.
  List<GasConsumptionLane> get lanes => [
    if (showsSac) GasConsumptionLane.sac,
    if (showsRmv) GasConsumptionLane.rmv,
  ];
}
```

Surfaces ask `showsSac` / `showsRmv` and render each lane behind its own
boolean, so a surface that shows both has no three-way branch. Surfaces that
can show only one lane at a time (the segment card, the statistics page) hold a
`GasConsumptionLane` and seed it from `lanes.first`.

The default for new installs is `both`.

### D3. Settings state

- `AppSettings.sacUnit` becomes `gasConsumptionDisplay`, default `both`.
- `SettingsNotifier.setSacUnit` becomes `setGasConsumptionDisplay`.
- `sacUnitProvider` becomes `gasConsumptionDisplayProvider`.
- The unused `SettingsKeys.sacUnit` constant is deleted.
- `DiverSettingsRepository` reads and writes the new column; the parse
  fallback for an unknown stored string is `both`.

### D4. Schema migration

One migration at the next free rung of the schema ladder. As of 2026-08-26 that
is **v170** (main at 164; 165 through 168 are held by open PRs and 169 by the dive-computer-gear-twin worktree). The rung is
re-verified when the implementation branch is cut by scanning every open PR's
diff for `currentSchemaVersion`, not by grepping main, because the scalar
auto-merges without a conflict marker when two branches pick the same number.

The migration does three things, in order:

1. Renames `diver_settings.sac_unit` to `gas_consumption_display`
   (`Migrator.renameColumn`; `database.dart` already has five `RENAME COLUMN`
   precedents) and sets its default to `'both'`.
2. Rewrites stored values:

   ```sql
   UPDATE diver_settings SET gas_consumption_display = CASE gas_consumption_display
     WHEN 'litersPerMin' THEN 'rmv'
     WHEN 'pressurePerMin' THEN 'sac'
     ELSE 'both' END;
   ```

3. Rewrites persisted dive-table layouts so the column a user placed keeps
   showing the quantity they were seeing:

   ```sql
   UPDATE view_configs
     SET config_json = REPLACE(config_json, '"sacRate"', '"rmv"')
     WHERE config_json LIKE '%"sacRate"%'
       AND diver_id IN (SELECT diver_id FROM diver_settings
                        WHERE gas_consumption_display = 'rmv');
   UPDATE view_configs
     SET config_json = REPLACE(config_json, '"sacRate"', '"sac"')
     WHERE config_json LIKE '%"sacRate"%';
   ```

   The quoted token `"sacRate"` is exact: no field enum of any entity has
   another value containing `sacRate`, and the JSON only ever holds it as a
   quoted `field` or `sortField` value. Neither `updated_at` nor `hlc` is
   touched: every device runs the same deterministic migration on its own
   copy, so there is nothing to push, and bumping the HLC would push every
   layout on every device.

Existing users therefore land on the lane they were seeing (F5 means a user who
never chose is stored as `pressurePerMin` and lands on `sac`). Nobody's
display changes on upgrade; `both` reaches existing users through the picker
and the RMV hint. Migrating every existing user to `both` was considered and
rejected for this reason; it is listed under follow-ups in case the upgrade
experience argues otherwise.

### D5. Sync

- The schema-defaults replay in `sync_data_serializer.dart` changes
  `'sacUnit': 'litersPerMin'` to `'gasConsumptionDisplay': 'both'`, and
  `sync_schema_defaults_replay_test.dart` with it.
- Inbound diver-settings rows from an older build carry `sacUnit`. When a row
  has `sacUnit` and no `gasConsumptionDisplay`, the serializer applies the D4
  value mapping before insert. Outbound rows carry only the new key.
- Inbound layouts containing `sacRate` resolve through the parser alias in D9.
- How an older build treats the unknown outbound key is checked at plan time
  against the sync upgrade-path rules. The expected behavior is that it ignores
  the key and keeps its local `sac_unit`; if it would instead reject the row,
  the row falls under the existing cross-version gating and needs no special
  case here.

### D6. Settings UI and setup wizard

The tile stays in Settings > Units, where users already look for it, retitled
**Gas consumption**. Its value reads `SAC (bar/min)`, `RMV (L/min)` (with the
active pressure or volume symbol), or `Both`. The picker dialog offers three
rows:

- **SAC**, subtitle "Tank pressure drop per minute (bar/min). Works with any
  logged pressures."
- **RMV**, subtitle "Gas volume breathed per minute at the surface (L/min).
  Needs a tank volume."
- **Both**, subtitle "Show SAC and RMV side by side."

The subtitles substitute the active unit symbols. The setup wizard's units step
(`units_step.dart`) offers the same three choices, default Both, and
`setup_apply_service.dart` writes the new field.

### D7. Formatting layer

`UnitFormatter` (`lib/core/utils/unit_formatter.dart`) loses `sacUnit`,
`sacSymbol`, and `convertSac` and gains one member per lane:

| Member | Result |
| --- | --- |
| `sacSymbol` | `bar/min` or `psi/min` from the pressure unit |
| `rmvSymbol` | `L/min` or `cuft/min` from the volume unit |
| `convertSac(double barPerMin)` | `convertPressure` |
| `convertRmv(double litersPerMin)` | `convertVolume` |
| `formatSac(double barPerMin)` | value plus `sacSymbol`; one decimal for bar, zero for psi |
| `formatRmv(double litersPerMin)` | value plus `rmvSymbol`; one decimal for L, two for cuft |

The decimals rule exists because `toStringAsFixed(0)` renders every imperial
RMV as "1" (the `unit_axis` lesson). The ten hand-rolled formatters in F10 all
route through these; no surface composes a `/min` string itself afterward.
The stale doc comment on `convertSac` that references a `Dive.sac` L/min getter
goes with it.

### D8. Labels and l10n

Every existing l10n key that names the quantity splits into a `_sac` / `_rmv`
pair, with short and long forms where the original had them:

- `enum_diveField_sacRate` and `_short` become `enum_diveField_sac`,
  `enum_diveField_rmv`, and their `_short` twins.
- `diveLog_detail_label_sacRate` becomes `diveLog_detail_label_sac` and
  `diveLog_detail_label_rmv`.
- `diveLog_cylinderSac_noSac`, `diveLog_tooltip_sac`,
  `diveLog_legend_label_sacRate`, `enum_profileMetric_sacRate` and `_short`,
  `settings_appearance_metric_sacRate`: these name the chart's single bar/min
  curve and become plain SAC labels.
- Settings and wizard keys (`settings_units_sacRate`,
  `settings_units_dialog_sacRateUnit`, `settings_units_sac_*`,
  `setup_units_sac`) are replaced by `settings_units_gasConsumption`,
  `settings_units_dialog_gasConsumption`, and one title plus one subtitle key
  per picker row.
- Keys that name a feature rather than the quantity get lane-neutral wording:
  `diveLog_detail_section_sacRateBySegment` and
  `diveDetailSection_sacSegments_*` read "Gas consumption by segment";
  `statistics_gas_sacTrend_*`, `statistics_gas_sacRecords_*`, and
  `statistics_gas_sacByRole_*` read "Gas consumption trend", "Gas consumption
  records", "Gas consumption by tank role", with the record labels ("Best",
  "Highest") taking the lane label as a parameter.
- Planner, calculator, and data-quality keys (`divePlanner_label_sacRate`,
  `divePlanner_semantics_sacRate`, `plannerCanvas_sac_useLogged`,
  `gasCalculators_sacRate`, `gasCalculators_rockBottom_*Sac*`,
  `dataQuality_msg_sac`) are reworded to RMV. Their key names stay; only the
  values change. Renaming them would touch call sites in the relabel PR for no
  reader benefit.
- Three unused keys are deleted: `diveLog_rangeStats_label_sacRate`,
  `units_sac_litersPerMin`, `units_sac_pressurePerMin`.

Per locale:

- **English and the non-German locales** use the acronyms `SAC` and `RMV`,
  with long forms localized the way each locale already localizes "SAC Rate"
  (Arabic keeps its "معدل SAC" pattern, for example). All ten locales are
  updated in the same commit as the English keys.
- **German** keeps `AMV` for every RMV label (the existing German is correct
  for the volume lane) and uses **Druckverbrauch** for every SAC label
  (etlami's suggestion in #803). `german_sac_terminology_test.dart` is
  extended to assert `AMV` on every `_rmv` key, `Druckverbrauch` on every
  `_sac` key, and no "SAC" outside BSAC.

### D9. Surfaces

The rule for every surface: ask `showsSac` / `showsRmv`, render each lane
behind its own boolean, never print a null. A lane that cannot be computed is
omitted in single-lane mode; in Both or RMV mode a missing RMV renders the
`SacVolumeHint`.

| Surface | SAC only | RMV only | Both |
| --- | --- | --- | --- |
| Detail summary row | `SAC 14.2 bar/min` | `RMV 17.0 L/min`; falls back to the SAC row plus the hint when no volume (PR #1298 behavior, kept) | two rows, SAC then RMV, which the summary grid's side-by-side pairing places together on wide layouts; the RMV row becomes the hint when no volume |
| Segment card | bar/min per segment | converted per segment via `volumeForSegment`; hint when any rendered segment fell back | one lane at a time, chosen by a `SAC | RMV` chip in the card header held in `dive_detail_ui_providers`, seeded from `lanes.first`; two value columns per phase row is too tight on phone |
| Cylinders card, per cylinder | `SAC 14.2 bar/min` | `RMV 17.0 L/min`, omitted for a cylinder without volume | `SAC 14.2 bar/min · RMV 17.0 L/min`, RMV part omitted when that cylinder has no volume; the line wraps rather than overflows |
| Range stats panel | SAC | RMV | both values, RMV omitted when unavailable |
| Profile chart (`ProfileRightAxisMetric.sac`, legend toggle, tooltip) | bar/min axis, labeled SAC | converted as today, labeled RMV | the one curve shows the native lane, SAC |
| Dive list cards | SAC chip | RMV chip; no hint, the card is too small | SAC chip and RMV chip, RMV omitted when unavailable |
| Dive table | user-chosen columns; the preference does not drive the table | | |
| Statistics gas page (trend, by role, records) | pressure providers, labeled SAC | volume providers, labeled RMV | a `SAC | RMV` segmented control at the top drives all three sections, held in a page-level `GasConsumptionLane` provider seeded from `lanes.first` |
| Planner, dive planner, gas calculators, data quality | always RMV; labels change, sources do not (`loggedAverageSacProvider` keeps reading `getSacVolumeByTankRole`) | | |
| Appearance settings | the profile-metric name reads SAC; `defaultShowSac` unchanged | | |

A second chart metric for RMV is deliberately not added. It would mean a new
persisted `ProfileRightAxisMetric` value in the appearance settings and a
second axis path for a single line; the chart shows the lane it computes.

The statistics providers stop reading the settings and instead read the
page-level lane provider, so the page has one source of truth for which
repository pair member to call.

**Dive table.** `DiveField.sacRate` is replaced by `DiveField.sac` and
`DiveField.rmv`:

- both in the `tank` category, right-aligned, 80 px default and 60 px minimum
  width, sortable; `sac` sorts by `Dive.sac`, `rmv` by `Dive.rmvFor(gasModel)`;
  the comparator no longer takes the preference;
- `DiveFieldAdapter.fieldFromName` gains a `_legacyNames` map
  `{'sacRate': DiveField.sac}` consulted before `firstWhere`, following the
  `TripField` precedent. It is permanent, not a one-time migration, because
  layouts sync from older builds (F4);
- `extractFromDive` returns each lane separately; `DiveFieldFormatter` formats
  them through `formatSac` / `formatRmv`; `extractFromSummary` returns null for
  both;
- the default column set in `view_field_config.dart` contains both `sac` and
  `rmv`, mirroring the Both default. A user on the default layout gains one
  column on upgrade; a user with a saved layout is migrated to exactly the one
  they had (D4).

## Error handling

- **Null lanes** never reach a formatter. Each lane is guarded by its own
  null check; no surface returns `SizedBox.shrink()` for the whole row when only
  one lane is missing.
- **Migration.** The value rewrite uses `CASE ... ELSE 'both'`, so an unexpected
  stored string cannot fail it. The layout rewrite is scoped by `LIKE` and
  replaces an exact quoted token. The migration is covered by a schema test
  (see Testing) seeded with every old value plus an unknown one.
- **Cross-version sync.** Inbound `sacUnit` is translated (D5). An inbound
  layout with `sacRate` resolves to `sac` through the alias. The one imperfect
  case is an older build on L/min pushing a layout after this device migrated:
  the column shows SAC instead of RMV until the user picks the RMV column, and
  nothing throws.
- **Layout width.** Two detail rows fit the existing summary grid. The
  cylinders card's combined line wraps; the widget test asserts no overflow at
  the phone surface size the existing SAC-row tests use.
- **Gas model and reference tank** rules are unchanged.

## Testing

Tests first, per file, in the order the implementation lands.

- **Domain and formatting:** `GasConsumptionDisplay.showsSac` / `showsRmv` /
  `lanes`; `UnitFormatter` symbols, conversions, and decimals in metric and
  imperial; the renamed `Dive.sac` / `rmvFor` and `CylinderSac.rmv` (existing
  `dive_sac_fix_test.dart`, `dive_sac_gas_model_test.dart`,
  `cylinder_sac_volume_test.dart` renamed with assertions unchanged).
- **Fields and table:** `DiveField.sac` / `rmv` category, labels, sizing,
  sortability; `fieldFromName` legacy alias; extractor and formatter per lane;
  the default column set; table sort on each column.
- **Migration:** `migration_v170_gas_consumption_display_test.dart` (named
  for whichever rung D4's re-verification settles on) in the style of
  `migration_v155_gas_model_test.dart`: seeds `sac_unit` rows with
  each old value plus an unknown one and a dive layout containing `sacRate`,
  asserts the column rename, the value mapping, the per-diver JSON rewrite, the
  untouched `hlc`, and that the unknown value lands on `both`.
- **Settings and sync:** repository round trip; notifier setter; the
  schema-defaults replay test; a serializer test for inbound `sacUnit`
  translation.
- **Widgets:** settings tile and three-row picker; wizard units step; the
  detail row across three modes with and without volume (extending
  `dive_detail_sac_row_test.dart`); the segment-card chip under Both; the
  cylinders card combined line; the range-stats panel; the chart label per
  mode; list-card chips; the statistics page segmented control under Both and
  its labels in the other modes; planner and calculator labels; the
  data-quality message.
- **l10n:** `german_sac_terminology_test.dart` as described in D8. The ARB
  generator enforces that every locale defines every new key.
- One full-suite run before the PR; lone failures rerun in isolation.

## Sequencing

Two independent PRs, each in its own worktree:

1. **Relabel PR (small, first).** The surfaces that are already volume-only
   (planner, dive planner, gas calculators, data quality, the `UnitAxis`
   rename) switch their labels to RMV. Label-only, no schema change. It settles
   the terminology before the structural change and answers #803 directly.
2. **Split PR** (this worktree). D1 through D9, with commits ordered so each
   compiles: new l10n keys alongside the old; enum, settings, migration, and
   formatter; surfaces one at a time; removal of `SacUnit` and the old keys;
   release notes.

## Out of scope

- Exporters emit no SAC today and stay that way.
- The universal importer's `sac` CSV target field is a dead end with no column
  behind it and is left alone.
- Persisted planner field names (`sacBottom` and siblings) keep their names.
- A second profile-chart metric for RMV.

## Follow-ups

- CSV export of both lanes, once someone asks for it.
- Migrating every existing user to `both` instead of preserving their lane, if
  the upgrade experience argues for it.
- `ProfileRightAxisMetric.rmv` as a separate curve, if the single-curve rule
  in D9 proves confusing under Both.
- A general `orElse` in every `fieldFromName` that drops unknown columns
  instead of throwing (F4), which would make the legacy alias a nicety rather
  than a requirement.
