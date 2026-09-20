# Rental Gear Memory

Date: 2026-09-18
Status: approved design, implementation plan pending
Branch: ericgriffin/rental-gear-memory-2db80e
Issue: #2075 (the PR body must say `Closes #2075`)

## Problem

A diver who rents gear from an operator learns things that matter on the
next trip and forgets them by then: the operator's size-L wetsuit ran small,
its "AL80" cylinders actually held a different volume, its BCD needed 2 kg
more lead than usual, and regulator number 14 breathed poorly. Submersion
already records the dive center, the lead used, the weighting feedback and
the tank volumes of every dive, but never connects them back to the operator
on a return visit, and has no place to keep the judgements ("ran small",
"avoid").

## Decisions

These were taken during brainstorming and are fixed for this spec.

- Surfaces: the dive edit form (a "Last time here" card under the dive
  center row) and the dive center detail page (a "Rental gear" section).
- Anchor: the existing `DiveCenters` entity through `dives.diveCenterId`
  only. Trips, liveaboard records and the legacy free-text `dives.diveOperator`
  column are ignored.
- Representation: a separate per-center notes table. Rental items are never
  `equipment` rows, so the owned-gear list, service reminders, the condition
  engine and the weight prediction engine are untouched.
- Capture: notes are written from both surfaces through one shared sheet.
- Note shape: typed fields (gear type, label, size, verdict, optional lead
  adjustment, optional tank volume) plus a free-text note and an optional
  link to the dive it was noted on. Verdict is a two-way "worked" or "avoid".
- Derived facts: the card also shows the most recent dive at the center
  (lead breakdown, weighting feedback, tanks) computed on demand, and an
  "Apply last dive" action copies that dive's weights and tanks into the
  form. Nothing derived is stored.

## Data model

One new table, `dive_center_gear_notes`, entity type `diveCenterGearNotes`,
a child of `dive_centers`.

| Column | Type | Meaning |
| --- | --- | --- |
| id | text, primary key | uuid |
| dive_center_id | text, FK dive_centers.id, cascade | the operator |
| gear_type | text | `EquipmentType.name` (regulator, bcd, wetsuit, tank, weights...) |
| label | text, nullable | the operator's mark: "14", "AL80" |
| size | text, nullable | "L", "42" |
| verdict | text | `worked` or `avoid` |
| lead_adjustment_kg | real, nullable | signed, "needed 2 kg more" is +2.0 |
| volume_liters | real, nullable | the cylinder's true capacity, tank notes only |
| note | text, not null, default '' | free text |
| dive_id | text, FK dives.id, set null, nullable | the dive it was noted on |
| noted_at | datetime | when the diver made the observation |
| created_at, updated_at | datetime | row timestamps |
| hlc | text, nullable | sync clock |

Two explicit numeric columns rather than one polymorphic value column, so
display and units never depend on the type. Both are stored metric and shown
in the active diver's weight and volume units.

Domain entity `DiveCenterGearNote` in
`lib/features/dive_centers/domain/entities/dive_center_gear_note.dart` with
`copyWith`, a `RentalVerdict { worked, avoid }` enum, and a `gearType`
typed as `EquipmentType`. Unknown stored type names (from a newer peer)
map to `EquipmentType.other` on read rather than throwing.

No `diver_id` column: the center already carries `diver_id`, and the note
is meaningless without its center, matching `dive_weights` and
`weight_preset_entries`.

### Schema rung

Main is at 219. Three open PRs (#2040, #1980, #1978) each claim 220, so
this feature claims **221** and re-checks the ladder (open PR diffs and
bodies, plus main) right before the plan is written and again before push.
The migration is an inline `if (from < 221)` block in `database.dart`
creating the table, followed by `reportProgress()`, with the version added
to `migrationVersions`. There is no `migrations/` directory; the two docs
that describe one are stale.

### Sync registration

The table is a parent-gated child of `diveCenters`. Every one of these
must be touched, and the existing pinning tests fail until they are:

- `SyncRepository.hlcTargets`: `'diveCenterGearNotes': (table: 'dive_center_gear_notes', pk: 'id')`.
- `SyncDataSerializer.parentGatedChildEntities` and `parentGatedTables`;
  the record id is the plain `id`, so no key-column entry.
- Serializer payload field, `toJson` and `fromJson`, the export table list,
  and each `case 'diveCenterGearNotes':` switch.
- `SyncService` merge dispatch and FK gating:
  `(field: 'diveCenterId', parent: 'diveCenters', nullable: false)` and
  `(field: 'diveId', parent: 'dives', nullable: true)`.
- `conflict_reference.dart` FK-to-entity labels.
- The repository calls `markRecordPending` after every insert or update
  (outside any `batch` closure) and `logDeletion` on delete.

## Derived facts

`RentalMemoryResolver` in
`lib/features/dive_centers/domain/services/rental_memory_resolver.dart` is
pure Dart. Input: a list of hydrated dives at the center and the id of the
dive being edited (nullable). Output `LastDiveAtCenter?`: the most recent
dive by `diveDateTime` that is not the current dive, with its date, typed
weights, `weightingFeedback` and `weightingFeedbackKg`, and tanks (volume,
working pressure, preset name, material, gas mix, role). Null when there is
no other dive.

The repository gains `latestDiveIdAtCenter(centerId, {excludingDiveId})`
returning at most one id by `ORDER BY diveDateTime DESC LIMIT 1`, and the
provider hydrates it through the full `getDiveById` path. The lean analysis
path leaves weights empty and must not be used here (the buoyancy twin was
bitten by exactly this).

## Dive edit form

`TripSection` gains an optional `centerChild` slot rendered under the dive
center caption, mirroring the existing `tripSuggestion` slot.

The slot holds `RentalMemoryCard`, given the selected center id and the
current dive id:

- Header: "Last time at {center}" with the derived dive's date, or the
  center name alone when there is no derived dive.
- Derived rows (when a derived dive exists): lead per weight type and the
  total, a weighting feedback chip ("Felt correct", "2 kg over",
  "1 kg under"), and one line per tank ("AL80, 11.1 L at 207 bar").
- Notes list: gear icon by type, label and size, verdict chip, lead
  adjustment or volume when present, note text. Tapping a note opens the
  sheet in edit mode.
- "Add rental note" opens the sheet in create mode with the center id and,
  when editing a saved dive, that dive's id. A new dive has no id yet, so
  the note saves with `dive_id` null.
- "Apply last dive" (only when a derived dive exists) replaces the form's
  `_weights` and `_tanks` with copies carrying fresh ids. Weight copies keep
  type, amount and notes. Tank copies keep volume, working pressure, preset
  name, material, gas mix, role and order, and take the same default start
  and end pressures a newly added tank gets. The form is marked dirty and
  `_tanksDirty` set, then a snackbar confirms. When the form already holds
  any weights or tanks, a confirm dialog precedes the replace.
- With no center selected the slot renders nothing. With a center but no
  derived dive and no notes, only the "Add rental note" button shows.

Notes save immediately to the center, independent of the dive's own save,
because the note belongs to the operator and must survive a discarded dive.
The card watches the notes provider so a save is reflected at once.

## Dive center detail page

A new `_RentalGearSection` card sits between the Notes card and the Dives
card. It lists the center's notes grouped by gear type in the equipment
display order, each row showing label, size, verdict chip and numbers, with
the note text beneath. An add icon button in the card header opens the sheet
in create mode; tapping a row opens it in edit mode, where a delete action
is available. When the center has no notes the card collapses to a single
compact row holding the add button.

The center delete-usage text is unchanged; notes cascade with the center.

## The note sheet

`RentalGearNoteSheet` is a modal bottom sheet shared by both surfaces.
Fields, top to bottom:

- Gear type dropdown in the equipment display order, default `other`.
- Label and size text fields.
- Verdict as a two-way segmented control, default `worked`.
- Lead adjustment, a signed number in the diver's weight unit, optional.
- Tank volume in the diver's volume unit, optional, shown only when the
  type is `tank`.
- Note, multi-line.
- Save; Delete when editing, behind a confirm dialog.

Numbers are parsed with the app's locale-aware input helpers and converted
to metric on save. Empty numeric fields save null.

## Files

New, all under `lib/features/dive_centers/`:

- `domain/entities/dive_center_gear_note.dart`
- `domain/services/rental_memory_resolver.dart`
- `data/repositories/dive_center_gear_note_repository.dart`
- `presentation/providers/dive_center_gear_note_providers.dart` (notes by
  center, last dive at center)
- `presentation/widgets/rental_gear_note_sheet.dart`
- `presentation/widgets/rental_memory_card.dart`
- `presentation/widgets/rental_gear_section.dart`

Touched:

- `lib/core/database/database.dart` (table, rung, version list) and the
  regenerated `database.g.dart`
- `lib/core/data/repositories/sync_repository.dart`,
  `lib/core/services/sync/sync_data_serializer.dart`,
  `lib/core/services/sync/sync_service.dart`,
  `lib/core/services/sync/conflict_reference.dart`
- `lib/features/dive_centers/data/repositories/dive_center_repository.dart`
  (latest dive at center)
- `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart`
  (slot)
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (slot
  wiring and apply, roughly sixty lines)
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`
- all eleven ARB files under `lib/l10n/arb/` and the regenerated
  localizations

## Testing

Tests are written before the code they cover.

- Repository: create, update, delete, list by center ordered by `noted_at`
  descending, cascade on center delete, `dive_id` set null on dive delete,
  pending mark after write, deletion log on delete.
- Resolver: picks the latest dive, excludes the current dive, returns null
  for an empty center, tolerates a dive with no weights or tanks.
- Sync: the HLC target and parent-gated registration pin tests, a
  serializer round trip of a note, a merge whose center is missing is
  deferred not dropped.
- Migration: a v221 test asserting the table and its columns, and the
  latest-version tripwire moved to 221.
- Widgets: the card renders derived rows and notes; apply replaces weights
  and tanks with fresh ids and default pressures and marks the form dirty;
  the confirm dialog appears only when the form is non-empty; the sheet
  shows the volume field only for tanks and converts imperial input to
  metric; the detail section groups by type and opens the sheet.
- The architecture guard suite (`test/architecture/`) runs once after the
  new lib files exist, because affected-directory runs never include it.
- Widget tests pin `Locale('en')`.

## Out of scope

- Rental items as `equipment` rows, and any ownership flag on equipment.
- Trips or liveaboard records as an anchor.
- Matching the legacy free-text `dives.diveOperator` to centers.
- Feeding notes into the weight prediction engine or the condition engine.
- Import and export of notes (UDDF, CSV, backup formats beyond the sync
  changeset).
