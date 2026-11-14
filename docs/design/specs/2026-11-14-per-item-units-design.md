# Per-item units for equipment fields

Issue: #4534 (SPG gauge should have a unit field)

## Intent

Gear is sold and labelled in its own units, whatever units the diver has set
for themselves. A metric diver owns a psi gauge; a diver in Europe buys a
3442 psi steel cylinder or lead stamped in pounds; an imperial diver has a
12 L cylinder. Today every equipment number is typed and shown in the diver's
own units, so the diver converts by hand, and the item page then shows a
figure that is not the one printed on the gear (a 4000 psi gauge reads
"275.8 bar").

This feature lets each unit-bearing field on an equipment item carry its own
unit. The diver types the number printed on the gear in the unit printed on
the gear, and the item reads back the same way.

## Goals

- Every equipment number field whose dimension has an alternative unit gets
  a unit picker on the edit form: pressure, mass, volume, depth, length,
  short length and DPV speed.
- The pressure gauge range field also offers "Both" (a dual-scale dial).
- The item's chosen unit is used wherever that item's own spec is shown:
  the edit form, the detail page spec rows, the retype page, and the
  cylinder passport card.
- Cylinder volume in cubic feet means rated gas capacity at working
  pressure, everywhere, including for an imperial diver who has not picked a
  unit. This fixes an existing bug (below).

## Non-goals

- Dive log fields (tank pressures on a dive, weight carried on a dive) stay
  in the diver's units. They are readings the diver takes, not labels on gear.
- Thickness (always mm) and burn time (always minutes) get no picker; there
  is nothing to switch to.
- Aggregates keep the diver's units: the assembly weight total, the buoyancy
  prior, the diver figure, the DPV mission planner, the transmitter registry.
  They work on the stored metric values and are unchanged.
- The equipment CSV does not carry the per-item unit. Each column keeps one
  unit, as now (metric, or the diver's units in My units mode).
- The query language does not get a new field for the unit.

## Anti-goals

- Storage must stay canonical metric in `value_num`. A per-item unit that
  leaked into the stored number would silently break every sum and filter.
- An older app version, or an older sync peer, must never wipe a unit a newer
  device set, and must still show the value correctly (in the diver's units).
- Changing the unit must not convert the typed number (see Behaviour).

## Existing bug fixed along the way

The generic attribute path converts cylinder volume (`volume_l` on a tank) as
plain water volume. An imperial diver who types 80 (an AL80) has 80 cubic feet
of water saved, about 2265 L, and the detail page shows it back as "80 cuft"
only because the conversion is symmetric. The passport card and the dive tank
editor already treat cubic feet as rated gas capacity
(`UnitFormatter.formatTankVolume`, preset-aware, falling back to
volume x working pressure / 28.3168). This feature makes the generic path
agree with them.

## Approaches considered

- **A. Unit in the number row's unused `value_text`.** No schema change, syncs
  for free. Rejected by the maintainer in favour of B: it gives `value_text`
  a second meaning that every reader would have to learn.
- **B. New nullable `value_unit` column on `equipment_attributes`.** Chosen.
  Clear meaning, one row still carries value and unit together, so a sync
  update can never split them. Costs a schema rung, a sync guard for older
  peers, and doc updates for the agent.
- **C. A companion choice attribute per field** (`gauge_max_pressure_bar_unit`).
  Rejected: about 20 extra catalog entries that must be hidden everywhere, and
  value and unit on separate rows can be edited apart by two devices.

## Decisions (made with the maintainer)

1. Scope: every unit-bearing equipment field, not just the gauge.
2. "Both" exists only on the gauge range.
3. Changing the unit relabels the number; it does not convert it.
4. Storage: approach B.
5. Cylinder volume in cu ft means gas capacity, everywhere.
6. Cylinder volumes already saved as water cubic feet are repaired once, on
   upgrade (threshold 80 L).
7. A cylinder with no working pressure uses the app's existing 200 bar
   assumption everywhere (repair and form), replacing the 207 bar fallback
   and the blocked entry first proposed, so a typed 80 reads back as "~80".

## Data model

- New column `equipment_attributes.value_unit TEXT NULL`.
- `NULL` means "follow the diver's settings", exactly today's behaviour. Every
  existing row starts `NULL`. The only stored values that change on upgrade
  are the mis-saved cylinder volumes (see Repairing saved cylinder volumes).
- Non-null holds the name of the unit enum value for the field's dimension:

  | Dimension | Values |
  | --- | --- |
  | pressureBar | `PressureUnit` names (`bar`, `psi`); `dual` on the gauge range only |
  | massKg | `WeightUnit` names (`kilograms`, `pounds`) |
  | volumeL | `VolumeUnit` names (`liters`, `cubicFeet`) |
  | depthM, lengthM, shortLengthM, speedMps | `DepthUnit` names (`meters`, `feet`); short length then reads cm or in, speed m/min or ft/min, following the same metric/imperial switch the formatter already uses |

- An unknown or mismatched value (a future unit, a typo from the agent) reads
  as `NULL`.
- `EquipmentAttribute` gains `valueUnit` (in props and `copyWith`, with a
  clear flag). Custom fields never set it.
- A row with a unit and no number is legal: the diver picked psi before
  typing. It is kept, so the choice survives clearing the number. Anything
  that asks "does this attribute have a value" keeps asking about the value,
  not the unit; such a row is shown nowhere on the detail page.

## Behaviour

### Edit form

- Each eligible number field gets a compact unit picker as its suffix,
  showing the unit currently in force (the item's, or the diver's when unset).
  The label loses its "(bar)" suffix, since the picker shows it.
- Picking a unit stores it on the row, even when it matches the diver's
  settings, so a bar gauge stays bar if the diver later switches to imperial.
- Picking a unit relabels the typed figure: `300 | bar` becomes `300 | psi`
  and the stored metric value is recomputed from 300 psi.
- The gauge range picker offers bar, psi and Both. With Both the diver types
  in their own pressure unit.
- Cylinder volume in cubic feet: the typed figure is rated gas capacity. The
  stored litres are the inverse of `formatTankVolume` for the working pressure
  on the form, preset-aware, so the round trip reads back the figure typed
  (80 cu ft at 3000 psi matches the AL80 preset and stores 11.1 L). The pair
  is `ratedCapacityCuft` / `volumeLitersFromCapacity` in
  `lib/core/services/export/csv/codec/tank_capacity.dart`. Without a working
  pressure the app's existing assumption applies: 200 bar, shown with "~" as
  `formatTankVolume` already does. When the working pressure changes on the
  form, the stored litres are recomputed from the figure the diver typed,
  which stays on screen unchanged.
- The same cubic-feet rule applies to an imperial diver with no unit picked:
  the field shows and takes gas capacity.

### Detail page and other spec readers

- `formatAttributeValue` formats a number in the row's unit when set, else in
  the diver's. Dual shows the diver's unit first: "300 bar / 4,350 psi".
- Cylinder volume in cubic feet is shown through `formatTankVolume`.
- The cylinder passport card shows volume and working pressure in the
  item's units.
- Totals, the figure, the buoyancy prior, the DPV planner and the
  transmitter registry are unchanged.

## Migration and sync

- One schema rung adds the column (nullable, no backfill), following the
  split layout: table in `lib/core/database/tables/equipment_tables.dart`, the
  rung in `lib/core/database/migrations/`, and a `beforeOpen` backstop for a
  database that skipped the rung, in a part file rather than `before_open.dart`
  (it is at its line cap). Take the next free version at build time.
- Sync applies rows by `EquipmentAttributeRow.fromJson(...).toCompanion(false)`.
  A payload from a peer that predates the column has no `valueUnit` key, and
  would write `NULL` over a unit set on this device. The apply path must leave
  `value_unit` untouched when the key is absent, and write it (including an
  explicit null) when present.
- An older app version ignores the column and shows the value in the diver's
  units, which is still correct.

## Repairing saved cylinder volumes

Every tank `volume_l` an imperial diver typed into the equipment form (or
imported from a My units equipment CSV) was stored as water cubic feet: an
AL80 typed as 80 is about 2265 L. Those litres already feed the passport card
buoyancy, the blender cylinder picker and the planner saved tanks, and once
this feature reads cubic feet as gas capacity the AL80 would show as about
16,500 cu ft. The maintainer chose a one-time repair.

- **Which rows:** curated `volume_l` rows on items of type tank whose
  `value_num` is above 80 L. No scuba cylinder is that large, while the
  smallest real imperial figure stored this way (a 3 cu ft Spare Air) lands
  near 85 L. Gas banks (typically 50 L) stay below the line.
- **The repair:** `typedCuft = value_num / 28.3168` recovers what the diver
  typed; the new `value_num` is the gas-capacity inverse of that figure at the
  item's working pressure (the same preset-aware conversion the form uses,
  `volumeLitersFromCapacity`). An item with no working pressure uses the
  app's assumed 200 bar, so it reads back as the figure typed.
- **The unit:** the repaired row's `value_unit` is left `NULL`; the diver who
  typed it is imperial and sees cubic feet already.
- **Sync:** this rung rewrites stored values, so per the repo's rule it joins
  `changeLogRewrittenColumns` and the repair repeats after each sync apply,
  or an older peer, a restore or a new device brings the bad litres back. It
  is idempotent: a repaired row is under the threshold.
- **Guarding:** the rung checks the column exists before touching it, like
  the other value-rewriting rungs.
- **Skipped rung:** the beforeOpen backstop that adds a missing `value_unit`
  column also runs the repair, since a database stamped at the version by a
  colliding build skipped both.
- **Rows entered on purpose since v368** (decided at code review): a save of
  a cylinder volume above the line stamps `value_unit = liters`, and the
  repair only touches rows with no `value_unit`, so a large bank cylinder
  entered after the upgrade is never rewritten when the repair repeats after
  a sync apply.

## Agent access (MCP)

- Gear documents include `value_unit`.
- Equipment writes accept `value_unit` on curated number attributes and reject
  a value outside the field's set (and `dual` anywhere but the gauge range),
  and on custom fields. `value_num` stays metric, so an agent never converts.
- Column notes and schema docs describe the new column.

## Builder's calls (settled after the builder check)

These were settled by the designer, not the maintainer; each is open to
correction on review.

- **Rebreather cylinders** (`diluent_cylinder_l`, `o2_cylinder_l`) have no
  working pressure, so cubic feet cannot mean gas capacity there, and as water
  volume it reads as meaningless figures (0.1 cu ft). They get no picker and
  always show litres, which is how CCR cylinders are sold in every market.
  Bag `capacity_l` is a true volume and keeps L / cu ft as plain volume.
- **Equipment CSV, cylinder volume in My units mode** follows the gas-capacity
  rule like the dive-tank CSV (`tank_capacity.dart`), read back with the same
  row's working pressure. Its header marks it as gas capacity, distinct from
  today's water-volume `cuft` header, so a file exported before this change
  still imports as it was written.
- **Where the item's own unit shows**, beyond the form, detail page, retype
  page and passport card: the printed passport labels
  (`print_passport_labels.dart`), since they go on the cylinder itself.
  Everything that uses an item inside the diver's own planning keeps the
  diver's units: the planner saved-tanks bar, the twin-set link flow, the
  blender cylinder picker, the agent write confirm dialog. The foreign
  passport page keeps the diver's units too: the tag payload does not carry
  the owner's units, and changing that is a tag format change.
- **Agent writes and `value_unit`**: the attribute list is replaced whole,
  `value_unit` included, exactly as `value_text` and `value_num` are, so an
  attribute written without it clears it. (Revised during the build: the
  write codec cannot tell a left-out key from a null one, and the gear
  documents the agent reads already carry `value_unit` to echo back.) A
  curated number row may be written with `value_unit` and no number,
  matching what the form allows. The schema docs say so.

## Left to the builder

- The exact picker widget and its compact look, within the form's existing
  style.
- Where the per-dimension unit sets live (a helper next to
  `equipment_attribute_units.dart` is the natural home).
- Localised labels for "Both" in every ARB file per the repo's l10n rules.
- Test layout, following TDD.
