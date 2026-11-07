# Equipment sets in rules and bulk edit (#4284)

## Goal

A logbook rule can add an equipment set to the dives it matches, or remove
one, and bulk edit can do the same across selected dives. Gear that arrives
through a set carries the set's provenance (`dive_equipment.via_set_id`), as
it does on the dive edit page.

## Decisions (agreed on #4284)

1. A rule stores the set id; each run resolves the set's current items.
2. Added gear carries `via_set_id` of the set it came through.
3. Removing a set removes the rows with that `via_set_id` and what hangs off
   them (`GearExpander.removeSet`). Gear added by hand stays.
4. A deleted set is skipped and reported through
   `rules_preview_skippedActions`, like deleted gear. An empty set adds
   nothing, silently.
5. Overlap follows `GearExpander`: a row that already has a set keeps it
   (first set wins); a hand-added row with no set takes the set's.
6. Rules and bulk edit ship together.
7. Replace: the bulk edit page has no replace mode for gear (it edits a
   per-item add/remove delta), so there is nothing to change there. A swap
   is "remove set A" then "add set B".

## Repository (`dive_repository_gear_sets.dart`, a `part` of the repository)

An extension on `DiveRepository`, beside `DiveGearPreview`:

- `equipmentIdsInSets(setIds)`: each set's item ids, read from
  `equipment_set_items` directly (the repository stays free of sibling
  repositories, as `_loadComponentsIndex` does).
- `bulkAddEquipmentSets(diveIds, setIds)`: one `GearExpander.expand` per
  dive with every set's items as additions, in set order, each tagged with
  its set id. One expansion, so the first set wins on overlap.
- `bulkRemoveEquipmentSets(diveIds, setIds)`: every row carrying one of the
  sets comes off with its subtree, so a part attached through it follows
  and no row is left pointing at a removed parent.

Both return the ids of the dives whose rows changed and write and bump only
those: the rule applier records exactly these, with no guess up front. No
notify, no transaction, as the sibling bulk methods. The rule preview runs
the real writes and rolls them back, so it gets the same answer.

## Rules

- `DiveCollection.equipmentSets` (new value; no JSON version bump, older
  versions keep it as `UnknownRuleAction`).
- `DiveRuleApplier`:
  - `refTable` -> `db.equipmentSets`, so a deleted set is a missing ref.
  - The snapshot (`members`) and the recorded change use the dive's gear
    rows, under the field `equipment`: a set action changes gear, so the
    history, change list and undo treat it as a gear change.
  - The dives changed are the ones the repository reports.
- `RuleUndoService`: gear undo also puts back the provenance a run changed
  on a row that stayed (a hand-added row that took on a set), also when
  that is the only change.
- Labels, picker, summary: `rules_collection_equipmentSets`, mapped to
  `QuerySubject.equipmentSets`.
- `NameIndexLoader.refSubjects` gains `equipmentSets`, so the multi-picker
  lists sets and summaries name them. Per-subject lookups only; no query
  relation points at sets, so no sentence can resolve to one.
- Agent access: `rule_writes` maps the collection to `equipment_sets`.

## Bulk edit

- `EquipmentOp` gains `viaSetId`; the service passes it to
  `bulkAddEquipment`.
- New `EquipmentSetsOp(mode, setIds)` (add | remove), snapshotting gear like
  `EquipmentOp`, applied before the per-item gear ops so a set removed and
  another added in one edit cannot lose shared gear.
- Page:
  - "Use set" remembers which set switched each item on. When the edit is
    applied, the item adds are grouped by that set into `EquipmentOp`s with
    `viaSetId`; items the diver picked by hand stay unmarked.
  - A new "Remove set" button beside "Use set" stages sets to remove, shown
    as chips under the equipment rows. The confirm dialog lists them under
    removing.
  - The new pieces live in their own widget file; the page is already far
    past the size limit.
  - Known limit: "Use set" on an item every selected dive already has
    produces no add for it, so it is not marked. Marking needs a change.

## Strings and docs

New keys in all 11 locales, then `flutter gen-l10n`. A short "Sets in rules
and bulk edit" note in `docs/user/equipment.md`.

## Tests (first)

- Repository: add (provenance, parts, overlap, hand-added row takes the
  set), remove (by provenance only, parts follow, hand-added stays).
- JSON round trip of the new collection.
- Applier: add/remove record gear changes; deleted set skipped with notice;
  empty set changes nothing; unchanged dives not written.
- Undo: restores rows and provenance.
- Bulk service: `viaSetId` honoured; `EquipmentSetsOp` add/remove, undo.
- Widgets: picker offers the set actions; bulk page stages and removes sets.

## Out of scope

Site rules; a replace mode for rules; changing the `GearExpander` overlap
rule.
