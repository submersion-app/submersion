# Equipment Type-Specific Attributes — Design

**Date:** 2026-07-16
**Status:** Approved pending review
**Schema version:** next free at implementation time — verify `currentSchemaVersion` on main AND unmerged branches before claiming. As of 2026-07-16: main is at v112 (`equipment.thickness`); open PR #600 (tombstone GC) claims v113 after renumber; open PR #601 (course requirements) claims v114 — so this feature is nominally **v115**. Referred to as **vNext** below.

## Problem

Equipment attributes today are flat columns on the `equipment` table (`size`,
`thickness` (v112), `buoyancyKg`, `weightKg` (v104)) shown unconditionally for
all 18 equipment types — a dive knife gets a "thickness (mm)" field. Every new
type-specific attribute costs a schema migration, widens the table for all
types, and adds sync/export wiring. There is no way for users to record
attributes the app did not anticipate.

## Goals

1. App-curated, type-specific attribute sets for all 18 `EquipmentType` values,
   rendered conditionally in the edit form.
2. User-defined free-form custom fields on any equipment item (parity with the
   existing `DiveCustomFields` feature for dives).
3. Full stats integration: attributes are filterable and groupable in the
   statistics tab via `DiveFilterSql`.
4. One-time migration of the four legacy columns into the new system; the app
   reads/writes only the new store afterward.
5. Correct multi-device sync semantics (per-attribute HLC merge, tombstoned
   deletes, convergent migration).

## Non-goals

- Per-dive attribute overrides (attributes describe the item, not its use on a
  specific dive).
- Auto-updating tank inspection dates from service records (future
  enhancement; see Open follow-ups).
- UDDF export of attributes (UDDF's equipment schema has no home for them).
- Removing the legacy columns from the schema (kept frozen for sync
  back-compat with older app versions).

## Architecture overview

A single typed key-value table (`equipment_attributes`) stores both curated
and custom values. The per-type schema lives in Dart as a data-driven catalog
(`EquipmentAttributeCatalog`), following the `CertificationLevelCatalog`
pattern (#546). The only difference between curated and custom fields is
whether `attrKey` resolves in the catalog — storage, sync, tombstones, and
exporters treat them identically.

Rejected alternatives:

- **JSON column on `equipment`** — whole-map row-level sync conflicts, no
  indexable join path for stats.
- **Per-type satellite tables** — 18 tables of migration/HLC/serializer/export
  wiring; adding one attribute to one type is a schema migration forever.

## 1. Schema (vNext)

New table `equipment_attributes` in `lib/core/database/database.dart`:

| Column        | Type              | Notes                                              |
| ------------- | ----------------- | -------------------------------------------------- |
| `id`          | TEXT PK           | Curated: deterministic `attr_<equipmentId>_<attrKey>`; custom: random UUID |
| `equipmentId` | TEXT FK, cascade  | → `equipment.id`                                   |
| `attrKey`     | TEXT              | Catalog key, or the user's label for custom fields |
| `isCustom`    | BOOL default false| Prevents collision between a user field named "thickness" and a future catalog key |
| `valueText`   | TEXT nullable     | Text values, choice-option keys, thickness designations |
| `valueNum`    | REAL nullable     | Canonical metric numbers; flags 0/1; dates as unix milliseconds |
| `sortOrder`   | INT default 0     | Display order for custom fields                    |
| `createdAt`   | INT               |                                                    |
| `updatedAt`   | INT               |                                                    |
| `hlc`         | TEXT nullable     | Per-row HLC for field-level sync merge             |

Constraints and indexes:

- `UNIQUE(equipmentId, attrKey, isCustom)`
- Index on `equipmentId`
- Index on `(attrKey, valueNum)` for the stats join path

Indexes are created in both the migration and the fresh-`onCreate` path so
fresh and restored databases are never missing them (large-DB-perf lesson).

**Deterministic IDs.** Two devices running the vNext migration independently
both materialize rows for the same logical attribute. With
`attr_<equipmentId>_<attrKey>` both generate the same primary key, so HLC
conflict resolution converges to one row instead of duplicating. The same
guarantee applies post-migration when two devices set the same attribute for
the first time.

**"Unset" is "no row".** Clearing a field deletes the row and writes a
per-row tombstone (#466 lesson) — never an empty-string write.

### Migration (vNext)

Idempotent, PRAGMA-guarded, run from `onUpgrade` with a
`_assertEquipmentAttributesTable` beforeOpen backstop (v111/v112 pattern):

1. Create table + indexes.
2. Copy legacy columns into rows (fresh HLC each):
   - `size` → `size` (valueText)
   - `thickness` → `thickness_mm` (parse leading number from `"5"` / `"6mm"` /
     `"5/4/3"` into valueNum; full designation into valueText; unparseable
     values land in valueText only so nothing is lost)
   - `buoyancyKg` → `buoyancy_kg` (valueNum)
   - `weightKg` → `dry_weight_kg` (valueNum)
3. Legacy columns remain in the schema but the app stops reading and writing
   them. Older-version devices will not see attribute edits made on vNext
   devices until they upgrade — the same trade as every prior schema bump.

## 2. Attribute catalog (Dart-side schema)

New file
`lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` —
pure data, no I/O.

```dart
enum AttributeKind { text, number, thickness, choice, flag, date }

enum AttributeDimension { none, thicknessMm, volumeL, pressureBar, massKg, lengthM, depthM }

class EquipmentAttributeDef {
  final String key;                   // stable, never translated: 'thickness_mm'
  final AttributeKind kind;
  final AttributeDimension dimension; // number attrs only — drives unit conversion
  final List<String> choiceKeys;      // choice attrs only: 'din', 'yoke', ...
  // labels resolved via l10n: attrLabel_<key>, attrChoice_<key>_<option>
}
```

`EquipmentAttributeCatalog.attributesFor(EquipmentType)` returns universal
attributes plus type-specific ones.

**Value semantics by kind:**

- `text` — valueText.
- `number` — valueNum in canonical metric; displayed in diver's units per
  `dimension` (L↔cuft, bar↔psi, kg↔lb, m↔ft). `thicknessMm` always displays
  in mm (industry convention in imperial markets too).
- `thickness` — multi-panel designations: valueText holds the designation as
  written (`"5/4/3"`), valueNum holds the parsed primary (thickest) panel
  (`5.0`) for stats sorting/grouping. Form input accepts `5`, `5/4`, `5/4/3`
  (validator `\d+(/\d+)*`).
- `choice` — valueText holds the stable option key (`'back_inflate'`), never
  the display string; l10n relabels freely, sync compares
  language-independent values, stats GROUP BY is bucket-safe.
- `flag` — valueNum 0/1.
- `date` — valueNum unix milliseconds (codebase convention); locale-formatted
  at display.

**Universal (every type):** `buoyancy_kg`, `dry_weight_kg` (number, massKg).
These replace the v104 columns; the weight-prediction planner must switch its
reads to attribute rows.

**Per-type catalog (v1):**

| Type      | Attributes |
| --------- | ---------- |
| wetsuit   | size (text), thickness_mm (thickness), suit_style (full / shorty / two_piece / semi_dry) |
| drysuit   | size, shell_material (trilaminate / neoprene / crushed_neoprene / vulcanized_rubber), seal_type (latex / silicone / neoprene) |
| tank      | volume_l (number), working_pressure_bar (number), tank_material (aluminum / steel / carbon_composite), valve_type (din / yoke / convertible), tank_identifier (text), last_visual_inspection (date), last_hydro_test (date) |
| regulator | connection (din / yoke), cold_water_rated (flag) |
| bcd       | size, bcd_style (jacket / back_inflate / wing / sidemount), lift_capacity_kg (number) |
| fins      | size, heel_type (open_heel / full_foot), blade_style (paddle / split / vented) |
| computer  | mount (wrist / console / hud), connectivity (ble / usb / infrared / none) |
| mask      | lens_config (single / twin / frameless), prescription (flag) |
| weights   | weight_style (belt / integrated / trim / ankle) |
| light     | lumens (number, none), beam_type (spot / flood / adjustable) |
| camera    | depth_rating_m (number, depthM) |
| smb       | smb_type (open / closed), length_m (number) |
| reel      | reel_type (spool / ratchet), line_length_m (number) |
| knife     | blade_material (stainless / titanium), tip_type (pointed / blunt / line_cutter) |
| hood      | size, thickness_mm (thickness) |
| gloves    | size, thickness_mm (thickness), glove_type (five_finger / mitt / dry) |
| boots     | size, thickness_mm (thickness), sole_type (hard / soft) |
| other     | (custom fields only) |

`tank_identifier` is the owner marking / rental number ("T1", "AL80 #3") —
distinct from the generic `serialNumber` column, which stays for the stamped
cylinder serial.

**L10n:** every label and choice option gets ARB entries in English plus all
10 other locales in the same PR (~60 label keys + ~50 option keys).

## 3. Domain layer, repository, UI

**Entity** —
`lib/features/equipment/domain/entities/equipment_attribute.dart`:
`EquipmentAttribute` (Equatable): id, equipmentId, key, isCustom, valueText,
valueNum, sortOrder; `copyWith`; factory `.curated(equipmentId, key, ...)`
builds the deterministic id. `EquipmentItem` gains optional
`attributes: List<EquipmentAttribute>` hydrated by detail/edit queries only —
list queries do not pay for the join.

**Repository** (extends the existing equipment repository):

- `getAttributes(equipmentId)` / `watchAttributes(equipmentId)`
- `saveAttributes(equipmentId, List<EquipmentAttribute> desired)` — runs in
  the same transaction as the equipment save. Diff against DB: insert/update
  changed rows (fresh HLC each); rows in DB but absent from `desired` are
  deleted with a per-row tombstone. The UI never touches HLC or tombstones —
  it submits the desired end state.

**Providers:**
`equipmentAttributesProvider = FutureProvider.family<List<EquipmentAttribute>, String>`
for the detail page; edit page copies into local form state on load.

**Edit page.** `equipment_edit_page.dart` is at 973 lines (past the 800-line
cap), so new UI lands as extracted widgets:

- `equipment_attribute_form_section.dart` — renders one input per catalog def
  for the selected type: text → TextFormField; number → numeric field with
  unit suffix in diver's units (converted to metric on save); thickness →
  validated text field; choice → dropdown of translated labels; flag →
  switch; date → date picker.
- `equipment_custom_fields_section.dart` — label/value rows with add/remove,
  mirroring the dive custom-fields editor.
- Legacy always-visible size/thickness/buoyancy/dry-weight controllers are
  removed; those fields appear only where the catalog says so.

**On type change:** the section rebuilds from the new type's catalog; values
whose keys are not in the new catalog are dropped at save time. The form is
the source of truth — no invisible retained state.

**Detail page:** an attributes card listing only set attributes (curated
first in catalog order, then custom by sortOrder), formatted per kind —
numbers unit-converted, dates locale-formatted, choice keys translated.

## 4. Stats integration

Join path: `dives ← dive_equipment ← equipment ← equipment_attributes`.

1. **`DiveFilterSql` attribute predicates** — compiled as an `EXISTS`
   subquery: dives where linked equipment of type T has attrKey K matching a
   numeric range / choice key / flag. Because `DiveFilterSql` feeds the whole
   statistics tab (#453), every existing chart respects attribute filters once
   the predicate exists. Bind parameters as explicit `Variable<double>` /
   `Variable<String>` — never through a heterogeneous `addAll` (reified
   Variable crash).
2. **New chart: "Dives by suit thickness"** — groups on `valueNum` of
   `thickness_mm` for dive-linked wetsuit/drysuit gear (a 5/4 suit buckets
   with 5 mm). Proof-of-concept for attribute grouping; further group-bys
   (tank material, BCD style) are follow-ups on the established query shape.

## 5. Sync, backup, export

- **Sync:** `sync_data_serializer.dart` gains an `equipmentAttributes`
  payload field (export/parse/import), copied from the `diveCustomFields`
  precedent. As an HLC entity it uses `.toCompanion(false)` (#474 rule) so
  cleared nullable fields actually clear on the remote. Deletions ride the
  existing tombstone pipeline. Older clients ignore the unknown payload field.
- **Backup/restore:** no change needed — backups are a raw SQLite `.db` file
  copy (see `backup_database_adapter.dart`), so the new table rides along
  automatically, including in encrypted `.sbe` backups. Cascade delete from
  equipment covers orphaning.
- **CSV export:** `generateEquipmentCsvContent` keeps its existing `size` /
  `thickness` / `buoyancyKg` / `weightKg` headers for spreadsheet back-compat
  but sources them from attribute rows, and appends an `attributes` column
  serializing the rest as `key=value; ...` pairs.
- **UDDF:** unchanged (non-goal).

## 6. Testing plan (TDD order)

| Layer      | Key cases |
| ---------- | --------- |
| Catalog    | every type returns defs; keys globally unique; choice kinds have ≥2 options; every label/option key exists in all 11 ARB files |
| Migration  | pre-vNext→vNext copies all four legacy columns; thickness parse (`"5"`, `"6mm"`, `"5/4/3"`, garbage→valueText); deterministic IDs; idempotent re-run (beforeOpen backstop) |
| Repository | diff-save insert/update/delete; clear-field writes tombstone; type-change drops out-of-catalog keys; same-transaction with equipment save |
| Sync       | serializer round-trip; tombstone deletion propagates; two devices migrating independently converge to single rows (deterministic-ID guarantee) |
| Widgets    | form renders correct fields per type; rebuild on type switch; thickness validator; unit suffix follows diver settings (FormSection gotchas: uppercased labels, ensureVisible before tap) |
| Stats      | EXISTS predicate returns correct dive sets; thickness grouping buckets 5/4 with 5 mm |

The two-device migration convergence test is the highest-value case — the
duplicate-row failure it guards against would surface only weeks after
release on multi-device accounts.

## Touched surfaces checklist

- `lib/core/database/database.dart` — table, migration vNext, beforeOpen guard
- `lib/core/constants/enums.dart` — none (EquipmentType unchanged)
- `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` — new
- `lib/features/equipment/domain/entities/equipment_attribute.dart` — new
- Equipment repository + providers — attribute CRUD
- `equipment_edit_page.dart` + two new widget files — form
- `equipment_detail_page.dart` — attributes card
- Weight-prediction planner — read buoyancy/dry-weight from attribute rows
- `DiveFilterSql` + statistics tab — predicate + one chart
- `sync_data_serializer.dart` — payload field
- Backup manifest — table entry
- `csv_export_service.dart` — sourcing + attributes column
- ARB files ×11 — labels and choice options

## Open follow-ups (out of scope)

- Service records of type visual/hydro auto-updating tank inspection dates
  and feeding the service-reminder system.
- Staleness hints on inspection dates (>1 y visual, >5 y hydro).
- Additional attribute group-by charts (tank material, BCD style).
- Attribute columns in the equipment list/table view (`EquipmentField`).
