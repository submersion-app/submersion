# Equipment identity, sharing and transfer between diver profiles

Date: 2026-09-17
Issues: #1549, #2046

## Problem

A family of four logs dives in one Submersion library, one diver profile per
person. One of them is the "equipment manager": he entered every piece of gear
under his own profile so he could track servicing in one place. Two requests
came out of that setup.

**#1549, telling identical gear apart.** The family owns several identical
items (for example four pairs of "2x Palantic Drop-Bottom" weight pouches). The
gear lists give no way to tell them apart:

- The dive equipment picker (`equipment_picker_sheet.dart`) shows only
  `item.name` and the type. Brand, model and serial number never appear.
- The dive detail and dive edit lists (`DiveGearTreeView`) add "brand model"
  under the name, which is identical for identical items.

The family works around it by writing the owner into the name ("Cressi Blue -
Primary mask Bill"). That breaks when gear changes hands: `dive_equipment`
stores only the equipment id, so a dive always shows the item's current name,
and renaming "Light - Bill" to "Light - Mitchell" rewrites every past dive.
The reporter asked for a new field that shows in every list and "does not
change past instances".

**#2046, sharing gear.** Equipment is strictly per diver
(`equipment.diver_id`, filtered with `diver_id = ?`). The other three family
members see none of the gear, so they cannot attach any of it to their dives
without re-entering dozens of items. The reporter asked to share equipment
with other profiles, "ideally with the ability to select what to share with
whom", the way sites and trips can be shared.

The two requests are the same problem seen from both ends. A field that holds
"who has this now" would rewrite history exactly as the name does, because it
lives on the equipment row. But the history already exists: every dive carries
its own `diver_id`, so "who used the light on this dive" is answered by whose
dive it is. What is missing is a way for more than one profile to use an item,
a way to change its owner, and enough identity in a list row to pick the right
one of four identical pouches.

## Goals

- Any equipment type can carry a short identifier, and every gear list row
  shows enough (brand, model, identifier, and a differing field when rows
  would still collide) to tell identical items apart.
- An owner can share an item with chosen diver profiles, one item at a time or
  in bulk.
- A profile an item is shared with can do everything the owner can, except
  delete or transfer it.
- An item can be transferred to another profile. Past dives are untouched and
  keep showing the item.
- The same item on two divers' overlapping dives is surfaced as a warning and
  a data-quality finding, never blocked.
- Deleting or merging diver profiles never removes gear from a surviving
  diver's dives.

## Non-goals

- A dated custody history table. The dive's own diver already records who used
  an item and when.
- Snapshotting an item's name or label onto `dive_equipment`. A snapshot
  cannot be corrected later and would touch about seven gear writers, sync and
  UDDF.
- Assigning downloaded dives to the dive computer's owner, and a diver field
  on the dive edit page. Both get their own issues.
- An all-profiles `is_shared` flag on equipment. Sharing is per diver only.
- Access control. Anyone can switch profile; "owner-only" actions are a
  guard against accidents, not a security boundary.
- Exporting share rows in UDDF or CSV.
- Changing the equipment usage math. Overlapping dives both count.

## Design

### Model

An item has exactly one owner (`equipment.diver_id`, unchanged) and zero or
more shares. One rule drives everything:

> An item is **visible** to a profile if the profile owns it or holds a share
> row for it.

Visible means fully usable: add to dives, sets, plans and assemblies, edit,
log service records, edit service clocks, record check-ins, receive service
reminders. Only three actions stay with the owner: delete, transfer, and
managing the item's shares.

Null-owner equipment is not a supported state: the v64 migration removed it,
and the only known source today is a peer applying a diver deletion (#1957,
tracked separately). Such a row is visible to nobody, as today, because
`diver_id = ?` never matches NULL and a share row is the only other way in.
`validatedCurrentDiverIdProvider` is null only when no diver exists; with a
null diver id every query stays unfiltered, as today.

The kept-item handling under "Diver deletion and merge" runs on the deleting
device. It marks the transferred rows pending, so peers receive the new owner
before the `divers` tombstone removes the old one, and #1957's ownerless rows
are not made worse by this work.

### Data

**New table `equipment_shares`** (schema v219):

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | uuid |
| `equipment_id` | TEXT | FK `equipment.id`, ON DELETE CASCADE |
| `diver_id` | TEXT | FK `divers.id`, ON DELETE CASCADE |
| `created_at` | INTEGER | epoch ms |
| `hlc` | TEXT nullable | child clock |

Unique index on `(equipment_id, diver_id)`, plus an index on `diver_id` for
the visibility subquery. Both indexes are asserted in the migration helper and
in `performance_indexes.dart`.

The rung follows the ladder convention: an idempotent
`_assertEquipmentSharesTable()` (`CREATE TABLE IF NOT EXISTS` through
`createMigrator().createTable`), `if (from < 219)` in `onUpgrade`, the
`currentSchemaVersion` constant, the `migrationVersions` list, and the
`@DriftDatabase(tables: [...])` list. No backfill: no existing row changes.

An invariant the repository enforces, because SQLite cannot: a share row never
names the item's own owner.

**Sync.** `equipment_shares` registers as a parent-gated child of `equipment`,
copying `site_site_types` (v217):

- `sync_repository.dart` HLC target registry.
- `sync_service.dart`: merge order (after `equipment` and `divers`), the
  clocked-entity flag, `parentRefs` for both foreign keys (neither nullable).
- `sync_data_serializer.dart`: the `SyncData` field and all serializer arms
  (ctor, `toJson`, `fromJson`, hlc target, export, `fetchRecord(s)`,
  `upsertRecord(s)`, `recordIdsFor`, `_tableFor`, `deleteRecord`), plus
  `parentGatedChildEntities` and `parentGatedRecordId`.
- `conflict_reference.dart` foreign-key-name map.
- Tombstones: removing a share logs a deletion for `equipmentShares`.
  `deleteEquipment` selects the item's share rows before the delete and logs a
  deletion for each, as it does for `equipmentComponents`. Applying an
  `equipment` or `divers` tombstone on a peer drops the matching share rows, as
  a cascade would.
- Every write marks the row pending after any `_db.batch` closure, never
  inside it.

**Visibility filter.** `equipment_repository_impl.dart` repeats
`if (diverId != null) query.where((t) => t.diverId.equals(diverId))` in
`getActiveEquipment`, `getRetiredEquipment`, `getAllEquipment`,
`getEquipmentByStatus`, `getEquipmentWithServiceDates`, and as raw SQL in
`searchEquipment`. All six move to `lib/core/data/visibility/visibility_filter.dart`:

```dart
static void applyToEquipment(query, String? diverId)
// diver_id = ? OR EXISTS (SELECT 1 FROM equipment_shares s
//   WHERE s.equipment_id = equipment.id AND s.diver_id = ?)
static String equipmentSqlFragment(String alias, {String conjunction})
```

This single change carries visibility to every consumer that reads through
those methods: the dive equipment picker, set editing, the component picker,
the "installed in" dropdown (`_validParentIdFor`), dive search chips, weight
calibration, `activeEquipmentClocksProvider`, the notification scheduler, and
the equipment exports. Reminders therefore reach the owner and every sharee.

Owner-agnostic reads stay as they are: `getEquipmentById`,
`getEquipmentByIds`, `getChildEquipment`, the usage and exposure queries, and
the dive gear joins.

Two call sites carry their own owner check and change explicitly:

- `equipment_edit_page.dart` `_parentIdToSave`: `parent.diverId != diverId`
  becomes "parent is not visible to `diverId`", through a new
  `EquipmentRepository.isVisibleTo(equipmentId, diverId)`.
- `equipment_findings_pass.dart` `itemsById`: `item.diverId == diverId`
  becomes the same visibility test. Findings for a shared item are graded with
  the thresholds of whichever profile runs the pass.

**Gear on a dive carries its owner.** The batch and single-dive gear mappers
in `dive_repository_impl.dart` build `EquipmentItem` without `diverId`. Both
set it, so a gear row on a dive can show an owner chip.

**New repository** `EquipmentShareRepository`
(`lib/features/equipment/data/repositories/`):
`getSharesFor(equipmentId)`, `getSharesForItems(ids)`,
`setShares(equipmentId, diverIds)`, `shareMany(equipmentIds, diverIds)`,
`unshare(equipmentId, diverId)`, `shareAllForDiver(ownerId, diverIds)`. It
rejects a share to the owner and ignores an existing pair. Providers:
`equipmentSharesProvider(equipmentId)` and a `diverNamesByIdProvider` for
chips, both invalidated on share-table changes. The equipment list providers
also invalidate on share-table changes.

### Identity in lists (#1549)

**Identifier on every type.** `tank_identifier` moves from the
`EquipmentType.tank` list to `EquipmentAttributeCatalog.universal`. The stored
key stays `tank_identifier`: renaming it would rewrite attribute rows on every
peer and open a window where old and new builds write different keys. A
constant `EquipmentAttrKeys.identifier = 'tank_identifier'` and a getter
`String? get identifier => attrText(EquipmentAttrKeys.identifier)` hide the
name. The label stays "Identifier". Existing cylinder values keep working with
no migration.

**One label builder.** A pure function in
`lib/features/equipment/presentation/utils/equipment_row_label.dart`:

```dart
Map<String, EquipmentRowLabel> buildEquipmentRowLabels(
  Iterable<EquipmentItem> rows,
  EquipmentRowLabelStrings strings,
)
```

The map is keyed by item id. `EquipmentRowLabelStrings` carries the localized
wrappers ("ID {identifier}", "S/N {serial}", "Bought {date}") and the date
formatter, so the builder needs no `BuildContext`, provider or settings.
Widgets call `equipmentRowLabelsOf(context, ref, items)` in
`equipment_row_labels_of.dart`, which supplies them from the app's language
and the active diver's date format. That helper reads `settingsProvider`, so
a widget test that mounts any consumer must override it with
`MockSettingsNotifier`, or the real notifier starts a database load inside
the test.

Per row: title `item.name`; subtitle parts joined with " · ":
`fullName` when it differs from the name, then "ID <identifier>" when set.
When two or more rows in `rows` still produce the same title and
subtitle, each of them appends the first field, in this order, whose value
differs across the colliding group: serial number, size, purchase date. Rows
that still read the same after one field are regrouped and go on to the next,
so two of four identical pouches can be split by serial number and the other
two by purchase date. Size
is free text and shows as written; the date goes through the active diver's
date format. If nothing
differs, the rows stay identical; the builder never invents a counter, since
"#2" would not be stable across lists.

Collision detection is scoped to the rows of one list, so a row's text can
differ between the picker and a dive's gear list. That is accepted: the goal is
that no two rows in front of the user read the same.

Consumers: `DiveGearTreeView` (dive detail and dive edit), the
`EquipmentPickerSheet`, `equipment_list_content.dart`, the set detail and set
edit pages, and `component_picker_sheet.dart`. They replace their own
`fullName != name` subtitle logic. The picker gains brand and model, which it
has never shown.

**Owner chip.** Any row whose `item.diverId` is not the active diver shows a
small chip with the owner's name. Rows on a dive use the dive's diver, not the
active diver, as the reference, so Bill's old dive shows a "Mitchell" chip on
the transferred light.

**Picker order.** The active diver's own gear first, then a "Shared with me"
section grouped by owner, each keeping the existing type grouping.

### Sharing UI (#2046)

Everything in this section appears only when two or more diver profiles
exist, as the sites and trips sharing controls do.

- **Item detail page:** a "Shared with" row with one chip per sharee. The owner
  taps it to open a profile checklist sheet. A sharee sees "Owned by <name>"
  and the chips read-only.
- **Equipment list bulk actions:** "Share with..." (profile checklist, adds
  shares) and "Transfer to..." join retire and reactivate in `_bulkActions`,
  enabled only when every checked item is owned by the active diver.
- **Filter sheet:** an "Owner" chip group (Mine, Shared with me, All; default
  All). It is a client-side axis in `EquipmentFilterState.apply()`, like type.
- **Table mode:** an `owner` `EquipmentField`, appended last so persisted
  column layouts keep their order.
- **Settings > Shared data:** "Share all my equipment..." opens the profile
  checklist and calls `shareAllForDiver`, beside the sites and trips rows.
  There is no share-by-default setting for equipment.
- Delete, transfer and share management are hidden for a sharee. The
  repository also refuses them, so a bulk delete that includes a shared item
  skips it and reports how many were skipped.

### Transfer

`EquipmentTransferService.transfer({equipmentIds, toDiverId, keepAccess})`
runs in one transaction:

1. Expands each id to its moving unit: the item, its installed parts
   (`parentEquipmentId`), and its assembly components, recursively. A part
   cannot be transferred on its own while installed; the UI offers the whole
   unit.
2. Rewrites `diver_id` on every row of the unit.
3. Fixes shares: deletes the new owner's share row for each row of the unit,
   and when `keepAccess` is true (the default) adds a share row for the old
   owner.
4. Moves linked registry rows, after confirmation in the dialog: a
   `dive_computers` row whose `equipmentId` is in the unit, and a
   `transmitters` row whose `equipmentId` or `transmitterEquipmentId` is in
   the unit. Declined, they stay and keep working, because gear reads by id
   ignore the owner.
5. Marks every changed row pending after the transaction's batch work.

`EquipmentRepository.updateEquipment` still never writes `diverId`; the service
is the only writer of ownership.

Untouched by design: `dive_equipment` rows (past dives keep the gear), the old
owner's equipment sets (valid while they keep access), service records,
observations, findings, and service schedules. Service kinds are read
unfiltered for clock evaluation, but the diver-scoped `serviceKindsProvider`
cannot name another diver's custom kind. The detail page, history section and
record dialog resolve kind names through an unfiltered by-id lookup instead,
and the scheduler's `scheduleAll` loads all kinds, so a clock on a transferred
or shared item keeps its name and its reminder.

Sync: equipment merges last-writer-wins on the whole row, so an unrelated edit
with a later clock on another device can revert a transfer. This is the
existing behaviour for every equipment column and is accepted here.

### Overlapping use

Two dives overlap when their `[entryTime, exitTime]` intervals share more than
5 minutes. The tolerance absorbs unsynchronised dive computer clocks, so a
mask handed over between back-to-back dives is not reported. A dive without
both times never overlaps.

- **Inline warning.** `overlappingGearUseProvider(diveId)` returns, for the
  dive being edited, each equipment id that is also on another diver's
  overlapping dive, with that diver's name and entry time. The picker and the
  dive edit gear list show "Also on Bill's dive, 10:02" on those rows, with the
  time through the active diver's time format. Nothing is blocked: downloads,
  imports, the default-set step and the dive computer gear link all attach gear
  with no UI, clocks disagree, and items such as "2x pouches" or pooled weights
  can legitimately be on two divers at once.
- **Data-quality finding.** A `SharedGearOverlapDetector` in
  `lib/features/data_quality/domain/detectors/`, registered in the detector
  registry and toggles, reports each overlapping pair once. Repairs: remove the
  item from this dive, remove it from the other dive, or dismiss. Repairs are
  offered only when the repair service can perform them.
- Same-diver overlaps are out of scope; duplicate detection and consolidation
  already own them.
- Usage math is unchanged: both dives count toward the item's dive count,
  exposure and service clocks.

### Diver deletion and merge

**Deletion.** `deleteDiver` today runs `DELETE FROM equipment WHERE diver_id = ?`,
and `dive_equipment` cascades, which would strip a transferred or shared item
from surviving divers' dives. Before that statement, the delete finds the
diver's **kept items**: owned items that have a share row, or that appear in
`dive_equipment` or `dive_tanks` on another diver's dive. Each kept unit is
handed to `EquipmentTransferService` with `keepAccess: false`, to the earliest
sharee by `created_at`, or without a sharee to the diver of the most recent
such dive. Everything else is deleted as today. The deleted diver's own share
rows go with the `divers` cascade, and each logs a tombstone.

**Merge.** `DiverMergeRepository` repoints every table with a `diver_id`
column, so it will pick up `equipment_shares` and can create a share to the
item's own owner or a duplicate pair (a unique-index failure). The merge
handles `equipment_shares` explicitly: delete the duplicate's share rows that
would collide with the survivor's, repoint the rest, then delete rows where the
share's diver equals the item's owner. Each removed row logs a tombstone.

### Unsharing

Removing a share deletes the row and logs a tombstone. Dives already logged by
that profile keep the gear, since dive gear reads ignore visibility. The item
leaves that profile's pickers and lists. It stays in that profile's equipment
sets, where the set detail and edit pages already tolerate items the scoped
provider does not return; those rows show "No longer shared", and applying the
set skips them.

### Exports

`allEquipmentProvider` now returns visible items, so the full UDDF export
declares every item its dives reference and re-import no longer drops gear.
The equipment CSV and the check-ins export include shared items. Share rows
are not exported; an import stamps every item with the importing diver, as
today.

## Error handling

- Share, unshare and transfer run in transactions and surface failures through
  the existing snackbar pattern, keeping the dialog open on failure.
- Sharing to the owner, or to a profile that no longer exists, is rejected by
  the repository with a typed failure, not an exception the UI must parse.
- Bulk actions report partial results ("Shared 12 items, skipped 2 you do not
  own").
- A transfer whose target profile is deleted mid-flight fails on the foreign
  key and rolls back whole.

## Testing

Tests are written first.

- **Migration:** `migration_v219_equipment_shares_test.dart` (fresh create,
  upgrade from 218, idempotent re-run, indexes present); the v218 test relaxes
  its version assertion to `greaterThanOrEqualTo`.
- **Sync census:** `sync_parent_refs_completeness_test`,
  `sync_data_serializer_batch_coverage_test`,
  `sync_serializer_fetch_record_test`, `sync_builtin_reference_data_test`, plus
  a round trip of a share row and of its tombstone, and an equipment tombstone
  dropping shares on the peer.
- **Visibility filter:** each of the six repository methods returns owned and
  shared items, excludes others, and stays unfiltered for a null diver. A
  statement-count test on `getActiveEquipment` guards against a per-row
  subquery regression.
- **Shares repository:** reject self-share, ignore duplicate pair, bulk share,
  pending marks after the batch.
- **Transfer:** unit expansion (installed parts and components), share fix-up
  with and without `keepAccess`, registry rows moved or left, past
  `dive_equipment` rows unchanged, pending marks, rollback on a bad target.
- **Diver delete:** a kept item survives and lands on the right profile; the
  surviving diver's dive still lists it; unshared, unused gear is still
  deleted. **Merge:** no self-share and no duplicate pair afterwards.
- **Row labels:** identifier shown; collision appends serial, then size, then
  purchase date; identical rows stay identical; size respects units. Colliding
  rows are fed in an order the tie-break itself would not produce.
- **Widgets:** the picker shows brand, model, identifier, owner chip and the
  "Shared with me" section; owner-only actions are hidden for a sharee; the
  overlap note appears with the formatted time. `test/architecture/` runs after
  each new `lib/` file.
- **Detector:** overlap inside and outside the tolerance, missing times,
  same-diver pairs ignored, each repair.
- New strings are translated in all 11 locales.

## Delivery

Four pull requests, each based on `main` (a PR based on a branch gets no CI):

1. **Identity labels.** Universal identifier, the row label builder and its
   consumers, the picker's brand and model. No schema change. `Refs #1549`.
2. **Sharing.** v219, sync wiring, the visibility filter, the two explicit
   owner checks, gear `diverId` hydration, owner chips, picker sections, the
   sharing UI, service kind name resolution, exports. `Closes #2046`,
   `Refs #1549`.
3. **Transfer and safe deletion.** `EquipmentTransferService`, the transfer
   UI, diver delete and merge handling. `Closes #1549`.
4. **Overlap.** The inline warning and `SharedGearOverlapDetector`.
   `Refs #2046`.
