# Equipment transfer, safe profile deletion and overlapping gear use

Date: 2026-10-03
Builds on: `docs/design/specs/2026-09-17-equipment-sharing-transfer-identity-design.md`
(the "original spec"). This document replaces its "Transfer", "Diver deletion
and merge" and "Overlapping use" sections and items 3 and 4 of its Delivery
section. Everything else in the original spec still stands.

## Where things stand

PR 1 (identity labels, #2052) and PR 2 (sharing and history, #2411) are merged.
What remains of the original plan:

- **Transfer.** No way exists to change an item's owner. The History card
  already renders a `transferred` event, and `equipment_ownership_events`
  accepts the kind, but nothing writes one.
- **Safe deletion.** Deleting a profile hands its shared trips and sites to a
  surviving profile, but deletes all of its gear
  (`diverGearSteps`, `lib/features/divers/data/repositories/diver_delete_steps.dart`).
  `dive_equipment.equipment_id` cascades, so a shared item disappears from every
  other profile's dives with it.
- **Overlapping use.** Nothing warns when the same item is on two profiles'
  dives at the same time.

## Corrections to the original spec

Checked against the code on 2026-10-03:

1. **Assemblies are a graph, not a tree.** A part can sit under several
   assemblies (`ComponentsIndex.rootsOf`), and an item can be a component of an
   assembly another profile owns. Expanding a transfer unit must walk up as
   well as down.
2. **Deletion order.** Step 1b of `deleteDiverWithReassignment` already deletes
   the profile's transmitters (`deleteDiverOwnedRows`) and Step 1 clears other
   profiles' dive links to its dive computers, both before the gear step. Kept
   gear must be handed over before Step 0, not "before the equipment DELETE".
3. **Transmitter serials are unique per profile** (`TransmitterRepository._checkConflicts`).
   Moving a transmitter with a raw `diver_id` rewrite can give the new owner
   two transmitters on one serial.
4. **Shares sync insert-only** (`_applyEquipmentShareRecord` uses
   `DoNothing`). A share fix-up deletes, tombstones and inserts a new row; it
   never updates `diver_id` in place (as the merge does, #2670).
5. **Merge is done.** `DiverMergeRepository` already handles
   `equipment_shares` and repoints ownership events. PR 3 does not touch merge.
6. **No typed failures exist.** `EquipmentShareRepository` reports counts
   (`EquipmentShareResult`). Transfer follows that pattern.
7. **Quality findings sync, and their category is parsed with `byName`**
   (`QualityFindingsRepository._fromRow`), which throws on an unknown name. A
   new `QualityCategory` value would break every older app version that
   receives a synced finding, so overlap findings use an existing category.

## Decisions

Made with the maintainer on 2026-10-03:

| Question | Decision |
| --- | --- |
| Who receives kept gear when its owner's profile is deleted | The profile that uses it: the earliest sharee, else the profile whose dive used it most recently |
| Dive computers and transmitters linked to transferred gear | Offered in the transfer dialog, moved by default; a serial clash keeps that transmitter with the old owner |
| Dive times for overlap | Derived times: entry (or dive date) plus effective runtime |
| Which gear links count for overlap | Everything: gear list, tank cylinder, tank regulator, transmitter serial, and parts inherited from an installed host |

# PR 3: Transfer and safe deletion

## Transfer unit

A transfer moves a **unit**, never a lone installed part. Given an item:

1. Walk **up** through both links, `equipment.parent_equipment_id` (installed
   on a host) and `equipment_components.component_equipment_id` (component of
   an assembly), while the ancestor has the same owner. The topmost such items
   are the unit's roots.
2. Walk **down** from each root through both links, collecting every item with
   the same owner.

An item owned by someone else is a boundary in both directions: a component
shared into the assembly stays with its owner, and an assembly another profile
owns is not moved because one of its parts was picked. Cycles cannot occur in
`parent_equipment_id`, but the walk keeps a visited set for both links anyway.

The expansion is a pure function over in-memory rows
(`lib/features/equipment/domain/services/transfer_unit.dart`), so it is tested
without a database; the service loads the owner's equipment and component edges
once and passes them in.

## `EquipmentTransferService`

`lib/features/equipment/data/services/equipment_transfer_service.dart`. It is
the only writer of `equipment.diver_id` after creation, apart from diver merge
and sync apply.

```dart
Future<EquipmentTransferPreview> preview({
  required List<String> equipmentIds,
  required String actingDiverId,
  String? toDiverId,
});

Future<EquipmentTransferResult> transfer({
  required List<String> equipmentIds,
  required String toDiverId,
  required String actingDiverId,
  bool keepAccess = true,
  bool moveRegistry = true,
});
```

- `preview` returns the expanded unit, the items skipped because the acting
  profile does not own them, the linked dive computers and transmitters, and,
  when `toDiverId` is given, the transmitters whose serial clashes with one the
  target already has. The dialog calls it again when the target changes.
- `transfer` re-derives everything inside its transaction rather than trusting
  the preview.
- Deletion calls an internal `transferUnitInTransaction` with the deleted
  profile as the acting owner, `keepAccess: false` and `moveRegistry: true`.

`transfer` runs in one `_db.transaction`:

1. Expand the unit. Items the acting profile does not own are skipped and
   counted; a transfer to the current owner is a no-op.
2. `UPDATE equipment SET diver_id = :to, updated_at = :now` for every item of
   the unit; `markRecordPending('equipment', id, now)` per item.
3. Share fix-up, per item: delete the target's share row (it becomes the
   owner) with a tombstone. When `keepAccess` is true, insert a share row for
   the old owner with a new id. Other sharees' rows are untouched. The fix-up
   writes no `shared` or `unshared` events.
4. Registry rows, when `moveRegistry` is true:
   - `dive_computers` whose `equipment_id` is in the unit: `diver_id` moves to
     the target, pending as `diveComputers`.
   - `transmitters` whose `equipment_id` or `transmitter_equipment_id` is in
     the unit: moved unless its serial clashes with one of the target's
     transmitters (the same rule as `_checkConflicts`); a clashing transmitter
     stays and is reported. A moved transmitter queues the dive rescan
     `TransmitterRepository` already runs after an update.
5. One `transferred` event per item of the unit (from the old owner, to the
   target), pending as `equipmentOwnershipEvents`.
6. `SyncEventBus.notifyLocalChange()` after the commit.

`EquipmentTransferResult` carries `itemsMoved`, `skippedNotOwned`,
`computersMoved`, `transmittersMoved` and `transmittersKept`. A target profile
deleted mid-transfer fails on the foreign key and rolls the whole transfer
back; the UI shows the existing "try again" snackbar.

Left alone by design: `dive_equipment` and `dive_tanks` (past dives keep the
gear), the old owner's equipment sets (a member shows "No longer shared" when
the old owner kept no access, as PR 2 already renders), service records,
schedules, observations and findings. Service kind names already resolve
across profiles (PR 2).

## Transfer UI

Shown only when two or more profiles exist, and only to the owner
(`canShareEquipment`, which excludes ownerless items).

- **Item page:** "Transfer to..." in the overflow menu, beside Delete
  (`equipment_detail_page.dart`, both menu copies).
- **Equipment list:** a "Transfer to..." bulk action after "Share with...",
  enabled when every checked item is owned by the active profile.
- **Dialog** (`lib/features/equipment/presentation/widgets/equipment_transfer_dialog.dart`):
  - A single-choice list of the other profiles.
  - When the unit is larger than the selection: "Also moves:" and the extra
    items' row labels.
  - "Keep access for me" switch, on by default.
  - When linked registry rows exist: "Also move {name}" per dive computer and
    transmitter, a single switch on by default, and a note under any
    transmitter whose serial clashes with the chosen profile's.
  - Transfer and Cancel. Transfer is disabled until a profile is chosen.
- **After:** a snackbar, "Transferred 3 items to Anna", with a "skipped N you
  do not own" variant as bulk share has. No Undo: undoing is a transfer back,
  which the owner can do from the same menu. The item page, now viewed by the
  old owner, shows "Owned by Anna" (or leaves the page if access was not
  kept, as after a delete).
- **History** already shows "Transferred from Bill to Anna".

## Safe profile deletion

**Kept items.** An item the deleted profile owns is kept when any of these
holds: it has a share row; it is on another profile's dive through
`dive_equipment`, `dive_tanks.equipment_id` or `dive_tanks.regulator_equipment_id`;
or it is in the same transfer unit as such an item. Everything else is deleted
as today.

**Heir, per unit:**

1. the profile holding the unit's earliest share row (`equipment_shares.created_at`);
2. otherwise, the profile owning the most recent dive (by effective entry time)
   that uses any item of the unit through the links above.

**Order inside `deleteDiverWithReassignment`'s transaction.** A new Step 0a
runs first, before the trips and sites handover: find the kept units and pass
each to `transferUnitInTransaction` with `keepAccess: false`. Every later step
selects by `diver_id = :deleted`, so none of them sees a moved row:

- Step 1 no longer clears other profiles' dive links to a moved dive computer.
- Step 1b no longer deletes a moved transmitter. A transmitter whose serial
  clashes with the heir's stays with the deleted profile and is deleted as
  today.
- The gear step's `equipment_components` and `equipment_shares` deletes only
  touch the remaining gear.
- `retireDiverServiceKinds` already keeps kinds that surviving gear's
  schedules use.

The moved rows are marked pending in the same transaction, so a peer receives
the new owner in the same push as the `divers` tombstone. Ownership events keep
the deleted profile as their `from` side until the `divers` row goes, when
`ON DELETE SET NULL` turns it into "a deleted profile", which History already
renders.

**What the user sees:**

- The type-to-confirm `DeleteDiverDialog` gains a line when kept gear exists:
  "{count} pieces of gear in use by other profiles will be kept and handed to
  them." The count comes from a read-only `keptEquipmentForDiver(diverId)` on
  the service.
- `DeleteDiverResult` gains `keptEquipmentCount` and `keptEquipmentHeirNames`.
  The snackbar adds "{count} pieces of gear handed to {names}." The trips and
  sites sentence is unchanged; the two are joined when both apply.

**Unchanged:** diver merge, unused and unshared gear (deleted), and ownerless
gear (#1957).

# PR 4: Overlapping use

## Definition

Two dives by **different** profiles overlap when their intervals share more
than `QualityThresholds.sharedGearOverlapTolerance` (5 minutes). Each interval
is `[effective entry, effective entry + effective runtime]`, the same
derivation `QualityContextBuilder` uses for neighbours: `entry_time` else
`dive_date_time`, and `exit_time` else entry plus `runtime` else plus
`bottom_time`. A dive with no derivable duration is never compared.
Same-profile overlaps stay with the clock and duplicate checks.

## Gear on a dive

One SQL builder, `lib/features/equipment/data/repositories/dive_gear_usage_sql.dart`,
yields `(dive_id, equipment_id, link_kind, host_equipment_id)` for every path
by which an item is on a dive:

| `link_kind` | Source |
| --- | --- |
| `gearList` | `dive_equipment` |
| `tankCylinder` | `dive_tanks.equipment_id` |
| `tankRegulator` | `dive_tanks.regulator_equipment_id` |
| `transmitter` | `dive_tanks.transmitter_serial` matched to `transmitters.transmitter_serial` with a `transmitter_equipment_id` |
| `inherited` | an item installed on a host (`parent_equipment_id`) that is on the dive by any other kind, from the item's `installed_date` attribute on |

It generalizes the joins `getExposureSamplesForEquipment` runs for one item;
that method is not rewritten. The detector's context query and the inline
warning provider both use the builder, so they cannot disagree.

## Detector

`lib/features/data_quality/domain/detectors/shared_gear_overlap_detector.dart`,
id `sharedGearOverlap`, version 1, category `QualityCategory.time` (see
correction 7), severity `info`.

- **Context.** `DiveQualityContext` gains `sharedGearOverlaps`: for the scanned
  dive, each other-profile dive that overlaps it and shares an item, with that
  dive's id, diver id, effective entry time, and the shared items with their
  link kind on each side and their host. `QualityContextBuilder` loads it with
  one query bounded by the existing `neighborWindow`, so the detector stays
  pure.
- **Collapse.** Within one pair of dives, an item whose host is also shared on
  the same pair is folded into the host's finding. One finding per topmost
  item per pair, built with `makePair` and discriminator = that item's id, so
  scanning either dive writes the same row.
- **Params:** `equipmentId`, `partIds`, `otherDiverId`, `otherEntryTime`,
  `thisLinkKind`, `otherLinkKind`. Names are resolved when rendering.
- **Message:** "{item} is also on {diver}'s dive at {time}", plus "with
  {n} installed parts" when `partIds` is non-empty. The time goes through
  `UnitFormatter.formatTime`, so it follows the 12/24-hour setting; a
  profile that no longer exists reads "another profile".
- **Registration:** `kQualityDetectors`, its version map, the Settings toggle
  list (which lists every registered detector), a
  `QualityPrefilters.candidatesByDetector` entry (dives with any gear on an
  other-profile dive inside the neighbour window), and the detector-count
  assertions in `quality_prefilters_test.dart` and
  `data_quality_settings_page_test.dart`.
- **Category parsing.** `QualityFindingsRepository._fromRow` and the finding
  stream that maps through it skip a row whose category, severity or status this build does not know, and
  log it, instead of throwing. That makes a future category safe; it cannot
  protect versions already released, which is why this detector uses `time`.

## Repairs

`repairOptionsFor` offers, for this detector:

- "Remove from this dive" when `thisLinkKind == gearList`.
- "Remove from {diver}'s dive" when `otherLinkKind == gearList`.
- Dismiss, always.

A new `RemoveGearFromDive` action runs in `QualityRepairExecutor`: snapshot the
dive's gear rows, `DiveRepository.bulkRemoveEquipment([diveId], [equipmentId])`
(which removes the item's subtree), notify, resolve and rescan both dives.
Undo writes the snapshot back through `replaceGearRows`. Tank, regulator,
transmitter and inherited links get no remove repair: removing them from here
would change the dive's gas or sensor data.

## Rescans

Scanning either dive refreshes or retires the pair, because
`applyScanResults` scopes by `dive_id` or `related_dive_id`. Gear writers that
attach gear without queuing a scan are checked one by one; each that is not
already followed by its caller's scan gets `scheduleQualityScan`:
`dive_computer_gear_linker.dart`, `dive_equipment_defaulter.dart`,
`equipment_set_for_computer_linker.dart`, and
`DiveRepository.rewriteAssemblyOnPastDives`.

## Inline warning

- `sharedGearOverlapProvider(SharedGearOverlapQuery)`, where the query is
  `(diveId?, diverId, entry, exit, equipmentIds)`, returns, per equipment id,
  the other profile's name and that dive's entry time. It uses the edit page's
  unsaved times (`_currentEntryTime`, `_currentDiveEndTime`), so it works on a
  new dive and follows time edits. It refreshes on `watchDiveDetailChanges`.
- **Dive edit gear list** (`DiveGearTreeView` as used by the edit page): an
  extra subtitle line, "Also on Anna's dive, 10:02", with a small info icon,
  in the row's secondary text style (no new theme colour).
- **Dive edit equipment picker** (`equipment_picker_sheet.dart`): optional
  `overlapQuery` parameter; only the dive edit page passes it, so the planner,
  trip, weight, transmitter and own-cylinder pickers are unchanged. The same
  line goes into the row's subtitle column under the owner chip.
- Nothing is blocked. With one profile the provider returns nothing without
  querying.

# Strings

All new strings go into the 11 locales: the transfer menu item, bulk action,
dialog title, body, switches, clash note and snackbars; the delete dialog line
and snackbar sentence; the detector title, message, parts suffix and two
repair labels; the inline warning.

# Testing

Tests are written first.

**PR 3**

- `transfer_unit` expansion: installed parts, assembly components, a part
  shared into another profile's assembly (boundary), an item under two
  assemblies, a picked part expanding to its host's unit, visited-set
  protection.
- Service: owner rewrite and pending marks; share fix-up with and without
  `keepAccess` (delete plus tombstone plus new id, never an in-place update);
  other sharees untouched; registry rows moved, left when `moveRegistry` is
  false, and a clashing transmitter kept; one `transferred` event per item;
  `skippedNotOwned`; no-op to the current owner; rollback on a missing target
  leaves no event and no change.
- Sync: a transferred item and its share fix-up round-trip to a peer, and the
  peer converges on one share row.
- Deletion: a shared item lands on the earliest sharee; an unshared item on
  another profile's dive lands on that profile; the heir's dives still list
  it; other sharees keep access; unused, unshared gear is deleted; a moved dive
  computer keeps its links on other profiles' dives; a moved transmitter
  survives and a clashing one is deleted; events read "a deleted profile"
  afterwards; `DeleteDiverResult` counts and names.
- Widgets: the menu item and bulk action are hidden for a sharee and with one
  profile; the dialog's unit line, switches and clash note; the delete dialog
  line; snackbar text.

**PR 4**

- Detector: overlap of 4, 5 and 6 minutes; missing duration; same-profile pair
  ignored; each link kind; host and parts collapse into one finding; the same
  finding id from either side.
- Context builder: the new query returns other-profile overlapping dives with
  shared items and nothing else.
- Repairs: both directions with Undo; withheld for non-gear-list links.
- Parsing: an unknown category, severity or status is skipped, not thrown.
- Registration and toggle counts; prefilter selects the right dives.
- Widgets: the warning line and its time format (12 and 24 hour); absent with
  one profile and in the planner's picker.

# Delivery

Two pull requests, each based on `main` and each with its own issue:

1. **PR 3: transfer and safe deletion.** Everything under "PR 3" above.
2. **PR 4: overlapping use.** Everything under "PR 4" above. It does not depend
   on PR 3 and can be reviewed in parallel.

# Non-goals

- Undo for a transfer.
- Choosing the heir in the delete dialog.
- Moving a dive between profiles (#2051).
- Changing the usage math: overlapping dives both count toward an item's
  dives, exposure and service clocks.
- Exporting ownership events or shares.
