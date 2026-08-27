# CCR as Equipment Type, Cylinder Configurations, and Rebreather Service

**Date:** 2026-08-05
**Issue:** [#804](https://github.com/submersion-app/submersion/issues/804)
**Status:** Approved design, pending implementation plan

## Motivation

Issue #804 reports that there is no way to record which rebreather was used on
a dive. Open-circuit gear is covered by the `regulator` equipment type, and CCR
gas is covered by tanks and tank roles, but the unit itself has no
representation. The reporter's workaround is to register the CCR controller as
a dive computer and infer the unit from it.

The issue makes three asks:

1. An equipment type for rebreathers, so a specific unit can be linked to a
   dive.
2. Reusable configurations per unit, because entering diluent and bailout
   setups by hand "can otherwise be quite involved."
3. Service-date tracking per unit.

All three are in scope, phased.

## Current state (survey findings)

The app already models more of CCR diving than the issue implies. What is
missing is a physical unit to attach it to.

- `DiveMode` (`lib/core/constants/enums.dart:318`) already has
  `oc` / `ccr` / `scr` / `gauge`; `dives.dive_mode` defaults to `'oc'`.
- `TankRole` (`enums.dart:292`) already includes `diluent`, `oxygenSupply`,
  and `bailout` alongside the OC roles.
- Dives already carry CCR setpoints, and `ScrType` (CMF / PASCR / ESCR)
  already exists.
- `EquipmentType` (`enums.dart:4`) is a hardcoded Dart enum of 19 values with
  no rebreather. Values persist as raw strings in `equipment.type`
  (`database.dart:872`), so adding a value is cheap but splitting one later
  would be a data migration.
- Everything type-specific about an equipment item lives in
  `EquipmentAttributeCatalog`
  (`lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`),
  a per-type map of typed attribute definitions stored as KV rows in
  `equipment_attributes` (v115, PR #608). Adding attributes for a new type
  requires no schema migration.
- Equipment type labels render from the enum's hardcoded English `displayName`
  (`equipment_edit_page.dart:207`) and are **not** localized. Attributes
  **are**, via `attrLabel_<key>` / `attrChoice_<key>_<option>` across 11
  locales.
- `ServiceSchedule` supports `intervalDays` / `intervalDives` /
  `intervalHours` per clock, and `ServiceDueEngine`
  (`domain/services/service_due_engine.dart:58`) already computes
  hours-since-anchor by summing dive durations for dives linked to the item,
  anchored on the last matching `ServiceRecord`.
- Built-in service kinds seed from `kSeedBuiltInServiceKindsSql`
  (`database.dart:2114`) with stable slug ids and `INSERT OR IGNORE`, so
  re-running is a no-op. Its SELECT list hardcodes `NULL` for
  `default_interval_hours` — no existing built-in uses an hours interval.
- Two adjacent concepts exist but neither carries a gas mix or a role:
  - `EquipmentSet` answers "what gear did I bring?" `EquipmentSetItems` is
    literally just `(set_id, equipment_id)`. Sets have geofences, a default
    flag, and are auto-applied to imported dives by `DiveEquipmentDefaulter`.
  - `TankPreset` answers "what kind of cylinder is this?" — a single-cylinder
    spec (volume, working pressure, material), diver-scoped, with seeded
    built-ins such as AL80.
  - Gas mix and role live only on per-dive `DiveTanks` rows. That absence is
    exactly the re-entry tedium the issue describes, and it is identical for a
    technical open-circuit diver entering doubles plus two deco stages.

## Design decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Type granularity | One `rebreather` type plus a `unit_type` choice attribute | Matches the existing pattern (`suit_style`, `bcd_style`). Serves SCR divers without a second type. "Show me all my rebreathers" stays a one-value query. Splitting later would be a data migration. |
| Configuration home | New generic entity, optionally owned by a unit | The tedium is identical for technical OC. A CCR-only table would be generalized later anyway. |
| Configuration payload | Cylinders only | Setpoints stay per-dive where they already live. A generic gas plan and a CCR config then share one shape with no always-null OC columns. |
| Apply flow | Manual, with smart merge | Never silently mutates gas data a dive computer already supplied. |
| Cylinder spec source | Inline snapshot, no FK to `tank_presets` | A config records what you actually dive, not a live pointer. |

## Phase 1 — `EquipmentType.rebreather`

One enum value plus one catalog entry. No schema migration.

```
EquipmentType.rebreather('Rebreather')
```

Catalog entry in `EquipmentAttributeCatalog._byType`:

| Key | Kind | Dimension | Choices |
| --- | --- | --- | --- |
| `unit_type` | choice | — | `eccr`, `mccr`, `hccr`, `scr_cmf`, `scr_pascr`, `scr_escr` |
| `mount_configuration` | choice | — | `back`, `chest`, `sidemount` |
| `scrubber_type` | choice | — | `axial`, `radial` |
| `scrubber_duration_h` | number | none | — |
| `o2_cell_count` | number | none | — |
| `diluent_cylinder_l` | number | volumeL | — |
| `o2_cylinder_l` | number | volumeL | — |
| `depth_rating_m` | number | depthM | — |

The universal attributes `buoyancy_kg` and `dry_weight_kg` are appended
automatically by `attributesFor`. This matters beyond bookkeeping: the weight
planner already reads those attribute keys, so a rebreather starts
contributing to weighting predictions with no additional wiring.

`scrubber_duration_h` is the unit's rated duration, a property of the unit and
its sorb. It is recorded here and deliberately not duplicated onto
configurations.

### Localization

The type label needs no ARB work (it renders from `displayName`). The
attributes add roughly 23 new keys — 8 `attrLabel_*` plus 15
`attrChoice_*` — across 11 locales, along with arms in the
`equipment_attribute_l10n.dart` resolver switch. This is the bulk of Phase 1's
diff.

## Phase 2 — Cylinder configurations (schema v139)

### Schema version

Main is at `currentSchemaVersion = 137`. PR #603 (divelogs) claims v138. This
work claims **v139**. Per project convention, re-grep `currentSchemaVersion` on
current `origin/main` before implementing and renumber above it if main has
advanced.

### Tables

```
cylinder_configs
  id            TEXT PK
  diver_id      TEXT NULL  -> divers(id)
  equipment_id  TEXT NULL  -> equipment(id)  ON DELETE SET NULL
  name          TEXT NOT NULL
  description   TEXT NOT NULL DEFAULT ''
  sort_order    INT NOT NULL DEFAULT 0
  created_at    INT NOT NULL
  updated_at    INT NOT NULL
  hlc           TEXT NULL

cylinder_config_items
  id                          TEXT PK
  config_id                   TEXT NOT NULL
                              -> cylinder_configs(id) ON DELETE CASCADE
  sort_order                  INT NOT NULL DEFAULT 0
  label                       TEXT NULL
  tank_role                   TEXT NOT NULL      -- TankRole.name
  volume_l                    REAL NULL
  working_pressure_bar        REAL NULL
  tank_material               TEXT NULL          -- TankMaterial.name
  o2_percent                  REAL NOT NULL DEFAULT 21
  he_percent                  REAL NOT NULL DEFAULT 0
  default_start_pressure_bar  REAL NULL
  created_at                  INT NOT NULL
  updated_at                  INT NOT NULL
  hlc                         TEXT NULL
```

`equipment_id` set means "a configuration for my JJ"; null means a generic gas
plan usable by any diver on any dive.

**No foreign key to `tank_presets`.** A preset picker populates `volume_l`,
`working_pressure_bar`, and `tank_material` at edit time and is then out of the
picture. This removes deleted presets breaking configs, a two-branch read path
at apply time, and preset edits silently rewriting the historical meaning of a
config.

**`ON DELETE SET NULL` on `equipment_id`.** Deleting a rebreather demotes its
configurations to generic gas plans rather than destroying them. Equipment
already supports a retired status (#636), so hard deletion is the rare path,
and losing a painstakingly entered bailout plan as a side effect of tidying
gear is the worse failure.

Migration follows the project's standard shape: an idempotent
`_assertCylinderConfigSchema()` (CREATE TABLE IF NOT EXISTS) called from both
the `if (from < 139)` `onUpgrade` block and the `beforeOpen` backstop, so a
database stranded at any lower version self-heals.

### The merge algorithm

Implemented as `CylinderConfigApplier`, a pure service taking existing tanks
plus config items and returning a list of operations. No database access, no
`DateTime.now()` — mirroring `ServiceDueEngine`.

```
match key = tank_role

for each config item, in sort_order:
    find FIRST UNCLAIMED existing DiveTank with the same tank_role
      found -> claim it. Fill ONLY columns that are NULL on it.
               Never touch o2_percent or he_percent.
      none  -> INSERT a new DiveTank; tank_order appended after
               the current maximum.

result: a summary — "Added 3 cylinders, kept 1"
```

Field mapping from `cylinder_config_items` to `dive_tanks`:

| Config item | Dive tank | Fillable on claim |
| --- | --- | --- |
| `tank_role` | `tank_role` | match key, never written |
| `volume_l` | `volume` | yes (nullable) |
| `working_pressure_bar` | `working_pressure` | yes (nullable) |
| `tank_material` | `tank_material` | yes (nullable) |
| `default_start_pressure_bar` | `start_pressure` | yes (nullable) |
| `label` | `tank_name` | yes (nullable) |
| `o2_percent` | `o2_percent` | **no** — insert only |
| `he_percent` | `he_percent` | **no** — insert only |

All five fillable columns are `.nullable()` on `DiveTanks`, so "is null" is a
real test for each. The two gas columns are the only ones carrying non-null
defaults, which is precisely why they are insert-only.

**Why gas mix is never overwritten.** `DiveTanks.o2Percent` is
`withDefault(const Constant(21.0))` and `hePercent` defaults to `0`. A tank
reading air is therefore indistinguishable from a tank nobody filled in: there
is no null to test against, so there is no honest way to detect "unset." Absent
gas on a dive is a nuisance; wrong gas on a dive is a safety-relevant falsehood
in a logbook divers plan future dives from.

**Why "first unclaimed."** A CCR diver routinely carries two `bailout`
cylinders, so `tank_role` is not unique. Claiming greedily in order makes
"config has 2 bailouts, dive already has 1" resolve to keep-one-add-one rather
than duplicating or clobbering.

### Structure

New feature directory `lib/features/cylinder_configs/`, laid out like the
existing `lib/features/tank_presets/`:

```
lib/features/cylinder_configs/
  data/repositories/cylinder_config_repository.dart
  domain/entities/cylinder_config.dart
  domain/entities/cylinder_config_item.dart
  domain/services/cylinder_config_applier.dart
  presentation/pages/cylinder_config_list_page.dart
  presentation/pages/cylinder_config_edit_page.dart
  presentation/providers/cylinder_config_providers.dart
  presentation/widgets/apply_configuration_menu.dart
  presentation/widgets/cylinder_config_item_editor.dart
```

It is its own feature rather than living under `equipment/` because a config
with a null `equipment_id` is not equipment, and `equipment/` is already large.

### UI surfaces

- **Dive edit, cylinders card** (`dive_log/presentation/widgets/cylinders_card.dart`):
  an "Apply configuration" menu. Configurations are grouped by owning unit,
  with generic ones under "Gas plans". Applying shows a summary snackbar.
  Note the known `SnackBar` action trap (#406): the action closure must not
  capture a `BuildContext` that may be disposed.
- **Rebreather detail page**: a "Configurations" card listing that unit's
  configurations with add / edit / reorder, following the structure of
  `service_clocks_card.dart`.
- **Configuration list and edit pages**, reached from the Equipment tab
  alongside Equipment Sets. The editor is a reorderable cylinder list; each row
  has role, gas mix, spec (with preset picker), optional start pressure, and
  label.

All displayed volumes, pressures, and depths route through the existing unit
formatter and respect the active diver's unit settings.

### Sync

- `cylinderConfigs` — a top-level HLC entity (own id and hlc).
- `cylinderConfigItems` — an HLC child modeled directly on `equipmentAttributes`
  and `equipmentSetGeofences`: serializer sites, `mergeOrder` placed after
  `equipment` and `tank_presets`, `entityHasUpdatedAt`, `parentRefs`,
  `_hlcTables`, `_hlcTargets`, per-row tombstones on child delete, and
  registration in the streaming base export (`_baseTables`).

## Phase 3 — Rebreather service kinds

Three new rows in `kSeedBuiltInServiceKindsSql`, plus one structural fix to
that SQL.

| Slug | Name | Applicable types | Interval | Auto-attach |
| --- | --- | --- | --- | --- |
| `scrubber-repack` | Scrubber repack | `["rebreather"]` | 3.0 hours | yes |
| `o2-cell-replacement` | O2 cell replacement | `["rebreather"]` | 365 days | yes |
| `rebreather-annual` | Rebreather annual service | `["rebreather"]` | 365 days | yes |

The seed's SELECT currently hardcodes `NULL` for `default_interval_hours`;
`scrubber-repack` is the first built-in that needs a real value, so the seed
gains an hours column. `INSERT OR IGNORE` on stable slugs keeps it idempotent,
matching the existing kinds' re-seed behavior.

`ServiceDueEngine` needs no changes. A scrubber clock is `intervalHours`
anchored on the last "Scrubber repack" record, which the engine already
computes.

**Documented caveat:** `hoursSince` sums dive *duration*, which approximates
loop time but is not identical — it excludes pre-breathe and surface loop
time. For a consumable whose manufacturer rating already carries a safety
margin this is acceptable, but it must be stated in the UI copy rather than
left for a diver to discover.

## Testing

Test-driven, applier first.

- `cylinder_config_applier_test.dart` (pure, written before the implementation):
  empty dive; partial role overlap; duplicate roles on both sides; downloaded
  gas mix preserved; null-only field fill; `tank_order` appending; ordering
  stability.
- Repository tests against an in-memory database with **foreign keys enabled** —
  fixtures that leave them off mask insert-order bugs.
- `migration_v139_cylinder_configs_test.dart` using
  `greaterThanOrEqualTo(139)` plus `contains(139)` from the start, not an
  exact-latest tripwire. Assert both the upgrade path and a fresh in-memory
  database, which are separate failure modes.
- Sync round-trip tests for both new entities, including child tombstones.
- Widget tests for the apply menu and the configuration editor.
- Equipment attribute tests extended for the `rebreather` type, including
  choice-key resolution.

Target 80% coverage on new code per project convention.

## Out of scope

- **Linking a rebreather to a dive computer entity.** The issue author's
  workaround registers the CCR controller as a dive computer. This design does
  not unify those: a Petrel used as a controller stays a `DiveComputer` and the
  unit becomes an `Equipment` row. A diver can keep doing both. Unifying them
  is a separate modeling question.
- **Auto-applying configurations to downloaded or imported dives.**
  `DiveEquipmentDefaulter` is untouched. A diver with several fills would
  otherwise get the wrong one applied silently.
- **Per-dive scrubber budget display.** Phase 3 tracks scrubber life as a
  service clock only.

## Phasing

Three PRs, in order:

1. **Phase 1** — `EquipmentType.rebreather`, catalog attributes, localization.
   No migration. Independently shippable and closes the issue's headline ask.
2. **Phase 3** — rebreather service kinds and the seed's hours column. Depends
   on Phase 1 for `applicable_types`. No migration beyond re-running the seed.
3. **Phase 2** — cylinder configurations, schema v139. The largest piece;
   depends on Phase 1 only for the optional owning-unit link.

Phase 3 lands before Phase 2 because it is small, mechanical, and gated on
Phase 1 alone, so it does not need to wait behind a schema migration.
