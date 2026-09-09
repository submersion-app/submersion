# Equipment Assemblies: Components Within Equipment

Status: proposed
Date: 2026-09-09
Issue: #1487
Related: `2026-07-13-default-geofenced-equipment-sets-design.md`,
`2026-07-16-gear-service-ledger-design.md`,
`2026-07-16-equipment-attributes-design.md`,
`2026-07-20-equipment-service-clock-unification-design.md`,
`2026-08-26-dive-computer-gear-twin-design.md`

## Problem

A regulator is not one thing. It is a first stage, two second stages, four
or five hoses, a gauge and a transmitter, and a diver who swaps parts between
a DIN first stage for cold water and a yoke first stage for travel needs the
service history of each part tracked on its own. The same is true of a
backplate-and-wing rig, an exposure "suit" of hood, gloves and boots, and a
camera rig of housing, strobes and ports.

Today the only grouping is an equipment set, and a set is a kit template:
applying one to a dive expands its members into the flat `dive_equipment`
junction at five separate call sites, the dive never records which set was
applied, and a dive with a fully itemised regulator reads as ten unrelated
rows. The reporter's own attempt at this with sets produced "a long list of
components in the dive view which is hard to read and takes a lot of screen
space".

Three asks, all from the issue thread:

1. Build a piece of gear from components, attach it to a dive as one unit,
   and expand it on demand to see the parts.
2. Keep per-component dive counts and service clocks correct when parts move
   between assemblies, with a choice at swap time between "from now on" and
   "also fix past dives".
3. Show an assembly's service state as the worst of its parts, and let the
   assembly carry its own clocks when no part has one. Separately, remember
   which set was applied to a dive and show it collapsed, with nesting.

## Decisions taken during brainstorming

| Question | Decision |
| --- | --- |
| What is an assembly | An ordinary equipment item that has components. No new entity, no new type. |
| How past dives see composition changes | Snapshot: attaching an assembly writes one junction row per part. Swaps are "from now on" by default, with an explicit option to rewrite past dives. |
| Nesting | Recursive with a cycle guard. |
| New equipment types | First Stage, Second Stage, Hose, Backplate, Wing, Harness, Housing, Strobe. |
| Scope | Assemblies on dives, planner parity, and dives remembering the applied set. |
| Provenance storage | Two nullable columns on the existing dive and plan junctions. |
| Deleting an assembly | Its own rows cascade off past dives; its component rows stay as flat gear. |
| Equipment list | Stays flat, with count and "part of" chips. |
| Per-dive deviation | A single component row can be removed from one dive without touching the template. |

## Relationship to the installed-in link

The equipment condition intelligence program (spec
`2026-09-09-equipment-condition-intelligence-design.md`, landed as v202)
added `equipment.parent_equipment_id`: a single "installed in" parent for a
consumable such as an O2 cell in a rebreather or a battery in a computer.
That child inherits its parent's dives live from its install date, and
deleting the parent orphans the child. It answers "what is this consumable
inside right now".

Assemblies answer a different question, "what was this rig built from on
that dive", and the two deliberately stay separate:

- An assembly template is many-to-many. The reporter's second stage is
  listed under both the DIN reg and the yoke reg; a single parent column
  cannot express that.
- An assembly is snapshotted onto each dive, so a part's usage history is
  what it was actually on, not what it is installed in today.
- Roles and order belong to the template, not to the part.

In the UI the wording stays distinct: "Installed in" for the parent link,
"Part of" and "Components" for assemblies. A consumable can be both: a cell
installed in a rebreather that is itself a component of a CCR rig.

## Why an equipment item and not a separate entity

Eight tables hold a foreign key to `equipment`: the dive and plan junctions,
set membership, service schedules and records, attributes, scheduled
notifications and tanks. An assembly that is an equipment row participates
in every one of them with no schema change: it goes on a dive, into a set,
carries clocks and attributes, and is deleted with the same tombstone path.
A separate `assemblies` table would need a second foreign key or a
polymorphic reference in each relation that should accept it, and a second
code path in sync parent references, the deletion guard, UDDF export and the
statistics filter. The composition structure (which parts, in what role, in
what order) lives in a junction either way, so the separate entity buys
conceptual separation and costs connectivity.

The cost of the chosen shape is that some consumers must learn not to count
an assembly and its parts twice. Those are enumerated in the leaf-only rules
below.

## Design

### 1. Data model

**New table `equipment_components`** (Drift class `EquipmentComponents`,
data class `EquipmentComponentRow`). It is the assembly template and is
shaped as a clocked child of equipment, the same shape as
`equipment_attributes`, because role and order are mutable payload that
must merge on their own clock.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text | primary key |
| `parent_equipment_id` | text | references `equipment(id)` on delete cascade |
| `component_equipment_id` | text | references `equipment(id)` on delete cascade |
| `role` | text | default empty; free text such as "Primary second stage" |
| `sort_order` | int | default 0 |
| `created_at`, `updated_at` | datetime | |
| `hlc` | text nullable | |

Unique on `(parent_equipment_id, component_equipment_id)`. One index per
foreign key. The table is added to `_hlcTables` and to the performance
index list.

An item is an assembly when it has at least one component row. There is no
assembly type: "Bill's cold water DIN reg" is a Regulator that happens to
have parts, and a photo rig is a Camera. A component may belong to several
assemblies' templates at once (the same second stage listed under both the
DIN reg and the yoke reg), because the template describes what can be
assembled, and the dive snapshot records what was.

**Cycle guard.** The repository refuses a self-reference and any insert
whose component is an ancestor of the intended parent, found by walking
`parent_equipment_id` upward with a visited set. The picker hides the same
candidates so the impossible choice is simply absent; the repository check
is the invariant, the picker is the experience.

**Two nullable columns on `dive_equipment` and `dive_plan_equipment`.**

| Column | References | On delete | Meaning |
| --- | --- | --- | --- |
| `via_equipment_id` | `equipment(id)` | set null | the immediate parent assembly this row was attached through; null for a top-level row |
| `via_set_id` | `equipment_sets(id)` | set null | the equipment set that was applied; propagated to every row of the expanded subtree |

Both composite primary keys stay, so an item appears at most once per dive.
The set-null rule on `via_equipment_id` is the "keep components, drop the
grouping" decision: deleting an assembly cascades its own row off every
past dive, as the reporter asked, but the hoses and stages it brought stay
on those dives as flat gear so their dive counts and clocks keep their
history. Deleting a grouping must not erase what was physically in the
water.

**Entities.**

- `EquipmentComponent` (`lib/features/equipment/domain/entities/`): the
  junction row plus an optional hydrated `component` item.
- `DiveGearLink` (`lib/features/dive_log/domain/entities/`): `item`,
  `viaEquipmentId`, `viaSetId`. `Dive` gains `gear: List<DiveGearLink>` as
  the single source of truth. The existing `equipment` list becomes a getter
  over `gear`, so every current reader compiles unchanged. The constructor
  accepts either `gear` or the legacy `equipment` list (which builds links
  with null provenance); `copyWith(equipment:)` keeps provenance for ids
  that survive the replacement and nulls it for new ones.
- `DivePlanGearLink` (`lib/features/planner/domain/entities/`):
  `equipmentId`, `viaEquipmentId`, `viaSetId`. `DivePlan.gear` is the
  source of truth and `equipmentIds` becomes a getter, mirrored through
  `dive_plan_state_mapper.dart`.

`EquipmentItem` does not change. Whether an item is an assembly, and what
it belongs to, come from providers, because the entity is hydrated in too
many places to carry a derived collection.

**Migration v203.** One rung for everything. v200 is claimed by the
transmitter registry branch (`issue-1365-brainstorm-f1e2c7`); whichever
merges second renumbers, as usual.

- `_assertEquipmentComponentsTable()`: `CREATE TABLE IF NOT EXISTS` plus
  its two indexes.
- `_assertGearProvenanceColumns()`: PRAGMA-guarded `ALTER TABLE ... ADD
  COLUMN` for the four columns, following
  `_assertCertificationCredentialsColumn` (v199).
- `if (from < 203)` rung calling both, followed by `reportProgress()`.
- Both re-called from the `beforeOpen` backstop, because a database that
  arrives by restore or sync adopt never runs `onUpgrade`.
- `currentSchemaVersion` to 201, `migrationVersions` appended.
- `minimumCompatibleSchemaVersion` stays at 183. The change is additive.

No backfill: existing dives have flat gear and stay flat.

**Known cross-version behaviour.** The dive junction rides its parent
dive's clock. A peer that has not yet upgraded and resaves a dive writes
rows without provenance, and that dive's grouping degrades to flat on every
device. This is a display loss, not data loss (every item is still on the
dive), and does not justify raising the compatibility floor.

### 2. Building an assembly

**Home: a Components card on the equipment detail page.** It sits between
the service clocks card and the rebreather unit configuration card, in the
same `Card` + `Padding(16)` + title + `Divider` shape as its neighbours,
implemented as `ComponentsCard(equipmentId:)` in
`presentation/widgets/components_card.dart`. Cross-item edges (service
schedules, documents, unit configurations) are all edited from detail-page
cards today, never from the edit form, and a brand-new item has no id until
it is saved, so the edit page gets no components UI.

Each row shows the component's type icon, name, role as the subtitle, and a
service dot fed by that component's own worst clock. Tapping a row opens
the component's detail page. Row actions follow the Settings > Manage
convention (`dive_roles_page.dart`): an edit icon that opens a small role
dialog, and a remove icon. Rows reorder by drag (`ReorderableListView`),
writing `sort_order`. A retired or lost component stays listed with its
status badge as a prompt to swap it, and is skipped when the assembly is
expanded onto a new dive. The card's empty state is one line of copy and
the add button.

**Add component picker** (`component_picker_sheet.dart`): a bottom sheet
reusing the set-edit membership pattern (`equipment_set_edit_page.dart`,
active gear grouped by type, checkbox rows, multi-select then confirm). It
excludes the item itself, its current components, and every ancestor and
descendant. Roles are free text; the role dialog offers autocomplete from
roles already used across the diver's assemblies.

**Swap with history** (`assembly_history_dialog.dart`). When a component is
added to, removed from, or replaced on an assembly that already appears on
at least one dive, a dialog offers:

- Future dives only (default). The template changes; past dives keep their
  snapshot.
- Also update N past dives. The repository rewrites the rows on every dive
  where the assembly is present: insert the new part under the assembly,
  delete the removed part's row where its parent is the assembly, or
  re-key the row from the old part to the new one. If the new part is
  already on that dive, its existing row adopts the assembly as parent and
  the old part's row is deleted, so the composite key is never violated.
  Each touched dive is re-stamped so sync carries the change.

This is the reporter's second comment, surfaced at the moment it matters
instead of as a global setting. The repository method is
`DiveRepository.rewriteAssemblyOnPastDives(assemblyId, GearHistoryRewrite)`
and it runs in one transaction with sync bookkeeping after the commit.

**Equipment list stays flat.** The list builder, scroll-to-index, selection
pruning and the table adapter all assume one row per item. Instead, a new
`equipmentComponentsIndexProvider` exposes a forward and reverse adjacency
map, invalidated by the components table, and tiles read it by id the same
way they read the worst-clock map: an assembly tile shows a component-count
chip, a component tile shows a "part of <name>" chip (or a count when it
belongs to more than one), and table mode gains a `components` count field
in `EquipmentField` and `EquipmentFieldAdapter`.

**Sets need no change.** An assembly is picked into a set like any other
item and stored by id. The set detail page shows the same count chip on
assembly rows.

**New equipment types**, inserted into the enum's grouped declaration order:

| After | New values |
| --- | --- |
| `regulator` | `firstStage`, `secondStage`, `hose` |
| `bcd` | `backplate`, `wing`, `harness` |
| `camera` | `housing`, `strobe` |

Each value needs: an icon case in `equipment_type_icon.dart` (exhaustive,
compile error otherwise), a `enum_equipmentType_<name>` key in all 11 ARB
locales and the regenerated localizations, an entry in
`equipment_attribute_catalog.dart` (`attributesFor` silently returns only
universal attributes for a missing entry), and a substring rule in
`macdive_value_mapper.dart` so MacDive imports stop mapping them to
`other`. Catalog additions stay small: first stage reuses the regulator's
connection attribute, wing reuses lift capacity, backplate gets a material
choice (steel, aluminium, carbon fibre), hose gets a length stored in
metres and shown in the diver's length unit through the catalog's existing
length dimension, the same path an SMB or a reel line uses. Service kinds need nothing: `general-service` has an empty
type list, which means every type.

### 3. Attaching to dives and plans

**One expander.** `GearExpander` in
`lib/features/equipment/domain/services/gear_expander.dart` is pure. It
takes the additions (each an item with an optional set id), the adjacency
map, the dive's existing links, and the set of inactive ids, and returns
the new link list.

Rules:

1. An added item gets a top-level link carrying the set id if one applies.
2. Each active component of that item, in `sort_order`, gets a link whose
   parent is the item and whose set id is the same, recursively.
3. Retired and lost components are skipped.
4. An item already on the dive as a top-level row that is now being added
   beneath an assembly adopts that parent (and set). A row that already
   has a parent is left alone.
5. A visited set makes the walk terminate even if a cycle ever reached the
   data.

Two sibling helpers live beside it: `GearTree.build(links)` turns a flat
link list into set groups and parent-child nesting for rendering, and
`leafGear(links)` returns the items that have no child row on the same
dive (Section 5).

**Removal rules on a dive.** Removing a top-level row removes its subtree.
Removing a set group removes every row carrying that set id. Removing a
single component row removes only that row, so a dive can record "cold
water reg, but without the necklace hose today" without editing the
template.

**Every writer routes through the expander.** Today the edit page expands
sets in five places (add picker, set picker, geofence banner apply,
auto-apply on empty, site-change re-evaluation), the repository has three
bulk operations, the defaulter applies the best set on import and download,
the bulk-edit page has its own set action, and the weight planner's
`RigComposer` has add and use-set actions. All of them become calls into
`GearExpander`. The edit page's state changes from `List<EquipmentItem>` to
`List<DiveGearLink>` and reads adjacency from
`equipmentComponentsIndexProvider`; the repository reads the components
table directly.

Two writers currently rebuild junction rows from bare two-column
companions and would silently drop provenance: `DiveConsolidationService`
when it unions the secondary dive's gear into the target, and
`_repointGearLinks` in `dive_computer_merge_repository.dart`. Both switch
to copying the full row. Undo snapshots in `bulk_dive_edit_service.dart`
and `dive_merge_snapshot.dart` capture provenance so a restore is exact.
The dive-computer gear backfill's `INSERT OR IGNORE` on the two original
columns is unaffected because its column guard uses `containsAll`.

**Set memory falls out of the same path.** The four places that apply a
set on the edit page and `DiveEquipmentDefaulter` all know which set won;
they pass its id and every row in the expansion carries it. The defaulter
calls `bulkAddEquipment([diveId], ids, viaSetId: best.id)`. "Save as set"
from a dive stores only top-level rows, so the set holds the assembly
rather than its expansion.

**Ordering hazard, unchanged.** The defaulter bails when a dive has any
gear row at all, and the dive-computer gear linker must still run after it.
The expander makes this more important, not less: an early writer that
leaves even one component row would suppress a whole set. The existing
regression test for that ordering stays load-bearing.

**Two tidy-ups in the same code.**

- `createDive` starts calling `markRecordPending('diveEquipment', ...)`
  for each link. Today it never does, so a new dive's gear only reaches
  peers on a full base snapshot.
- `updateDive` moves from delete-all-then-reinsert to a diff by
  `equipmentId`: update rows whose provenance changed, insert added rows,
  delete removed rows, with tombstones and pending marks after the commit.
  This matches how `EquipmentSetRepository.updateSet` and
  `DivePlanRepository.updatePlan` already write and stops the same key
  being both live and tombstoned in one sync payload.

**Planner parity.** `DivePlan.gear` carries the links, `RigComposer` calls
the expander, and the plan repository's existing diff write carries the two
columns.

### 4. Rendering on dives

**Dive detail, Equipment section.** The section stays a
`CollapsibleCardSection`; its content is a `DiveGearTreeView` built from
`GearTree.build(dive.gear)`:

- Set groups first. A set header row (set icon, name, item count)
  introduces every row carrying that set id, and tapping it opens the set
  detail page. Rows with no set id follow as plain top-level rows.
- Assembly rows are collapsed by default: name, brand and model, a
  "N components" subtitle, and a trailing expand chevron. Expanding indents
  the component rows beneath it, each with its role as the subtitle and a
  tap that opens the component's detail page. A nested assembly expands
  the same way one level deeper.
- The card's collapsed summary counts top-level items, not rows.
- Expansion state is local widget state, not persisted.

A set deleted after the dive has already nulled its rows' set id through
the foreign key, so they render as top-level with no special case. A set
whose membership changed since the dive shows what was applied that day,
not the current template.

**Dive edit, Equipment section.** The same tree, editable in place, with
the Use Set and Add actions unchanged. A set header has a remove action
that drops the group; an assembly row has the expand chevron and a remove
that drops its subtree; a component row is indented with a remove that
drops only itself. Picking an assembly from the Add sheet inserts it
collapsed with its count. The picker keeps listing every active item flat
so a component can still be added on its own. The two pickers start
calling `_markDirty()`, which the set and item pickers currently omit.

**Bulk edit** keeps the tri-state membership list in
`BulkMembershipEditor`. Assembly rows get a count chip through the existing
`trailingBuilder` hook, and the add and remove operations expand or drop
subtrees on each selected dive.

**Planner rig composer** shows top-level chips with a count chip on
assemblies. Components are present in the plan's links and feed buoyancy
without a tree UI.

**PDF detailed logbook** (`pdf_template_detailed.dart`) switches from the
flat list to the grouped one, indenting component names under their
assembly with the role in parentheses.

Both dive pages build their rows from the same `GearTree`, so detail and
edit cannot disagree about grouping. The equipment-set stale-cache bug in
issue #819 was exactly two surfaces reading one entity from different
caches.

### 5. Maintenance rollup and leaf-only rules

**Rollup provider.** `equipmentRollupClockProvider` maps every active item
to a `RollupClock`: the worst `ServiceClockStatus` across the item and all
its active descendants, plus the id of the item that owns it. It derives
from `activeEquipmentClocksProvider` (which holds every active item's
statuses including `ok`, so "next due" can be answered) and
`equipmentComponentsIndexProvider`, walking descendants with a visited set.
Severity ranks `overdue`, `dueSoon`, `ok`; the earliest due date breaks
ties. It must not derive from `equipmentWorstClockProvider`, which drops
`ok` clocks.

**Readers.**

- The equipment detail header badge and warning banner, which today check
  only `serviceClockStatusesProvider(id)` for the item's own overdue
  clocks.
- `EquipmentListTile`, `DenseEquipmentListTile` and the table urgency
  column. When the worst clock belongs to a descendant, the badge names it
  ("Necklace hose overdue").
- The Components card shows each component's own worst clock.

**Non-readers, on purpose.** `dueClocksProvider` (dashboard), trip service
alerts and scheduled notifications stay per item, so a due hose nags once
as the hose, not once per assembly containing it. The reporter's second
scenario (no component has a clock, so the assembly carries its own) needs
no special case: the assembly is an item and the rollup includes itself.

**Invalidation.** The adjacency index follows an edge-only stream on
`equipment_components`, so a membership edit refreshes the index, the
rollup that derives from it, and every badge. The wider
`watchEquipmentChanges()` stays on the `equipment` table alone: every
clock evaluation hangs off it, and a membership edit changes no schedule
or record. `invalidateServiceClockProviders` gains nothing because the
rollup re-derives from providers that are already invalidated.

**Leaf-only rules.** `leafGear(links)` returns every item that has no child
row on the same dive or plan. `BuoyancyTwinAssembler.composeRigTerms` and
the two lead helpers (`_carriedLead`, `droppableLeadKg`, both over
`EquipmentLead`) filter through it before summing, so a BCD assembly with a
wing component declares lift once (the wing's) and a weighted backplate is
counted once. All three buoyancy consumers (dive detail and both planners)
pass through the composer, so this is one insertion point. The stated
consequence: attributes entered on an assembly count toward buoyancy only
when none of its components are on the dive.

**Additive on purpose.** Dive counts (`getDiveCountForEquipment`), usage
hours (`getUsageSamplesForEquipment`), the statistics equipment filter and
the most-used-gear aggregation all count rows. An assembly and its
components are all real items that were in the water, so each keeps its own
count with no code change.

### 6. Sync and interchange

**Sync.** `equipmentComponents` registers as a clocked child of equipment,
copied site for site from `equipmentAttributes`: `mergeOrder` after
`equipment` with `hasUpdatedAt: true`, `entityHasUpdatedAt`, `parentRefs`
with both foreign keys `nullable: false`, the serializer descriptor keyed on
the table with no custom exporter, `fetchRecord`, `fetchRecords`,
`upsertRecord`, `upsertRecords`, `recordIdsFor`, `tableFor`, the `SyncData`
field, constructor, `toJson` and `fromJson`, `hlcTargets` in
`sync_repository.dart`, and `_hlcTables`. The worked checklist is in
`docs/superpowers/plans/2026-07-16-equipment-attributes.md`.

The two provenance columns need only `parentRefs` entries for
`diveEquipment` and `divePlanEquipment`: `viaEquipmentId` with parent
`equipment` and `viaSetId` with parent `equipmentSets`, both
`nullable: true`, so a peer that has deleted the parent nulls the pointer
instead of aborting the commit. The junction rows already serialize whole
through `toJson`/`fromJson`, so no column list changes.

`deleteEquipment` writes tombstones for `equipment_components` rows where
the item is parent or component, because SQLite's cascade emits none, in
the same transaction shape it already uses for schedules and records.

`test/core/services/sync/sync_parent_refs_completeness_test.dart` gains
`'equipment_components': 'equipmentComponents'` and will fail if any
foreign key above lacks a guard.

**UDDF.** The standard `<equipmentused><equipmentref>` list stays flat so
third-party readers see nothing new. The private
`<applicationdata><submersion>` block gains:

- `<components>`: one element per `equipment_components` row (parent ref,
  component ref, role, order).
- `<gearlinks>` per dive: one element per row with provenance (item ref,
  via ref, set ref). Rows with no provenance are omitted; the standard list
  already carries them.

Import parses both, resolves references through the existing id map,
inserts components only after every equipment row exists (order: equipment,
components, sets, dives), applies provenance to the dive's links, and
rejects cycles through the repository guard.

**CSV and Excel.** The equipment CSV and the Excel equipment sheet gain a
`Components` column listing component names. Dive exports have no equipment
column today and gain none.

**Backup** is a raw database copy and needs nothing. MacDive and Subsurface
have no assembly concept, so their importers are untouched beyond the new
type substrings.

## Provenance

- Issue #1487 body and four comments (ogbillavista, schtibal), read
  2026-09-08.
- Equipment schema, sync shape, expansion call sites and buoyancy seams
  verified in the repository at commit `39a358b6865` on 2026-09-08 and
  2026-09-09.
- Schema claim: v199 on main, v200 on the transmitter registry branch, so
  this design claims v203.

## Testing

Written first, per task.

- Migration: `test/core/database/migration_v203_equipment_assemblies_test.dart`
  in the usual shape (fresh open, upgrade from the minimal fixture, backstop re-assert
  idempotent, all four columns and the table present).
- Components repository: create, unique constraint, cycle guard at depth
  one, two and three, self-reference, reorder, role update, tombstones on
  parent delete and on component delete.
- `GearExpander`: single level, nested, adoption of an existing top-level
  row, retired component skipped, set id propagation, visited set on a
  synthetic cycle. `GearTree.build` and `leafGear` on the same fixtures.
- Dive repository: diff save carries provenance and emits the right
  tombstones and pending marks, `createDive` marks links pending, bulk add
  expands, bulk remove drops subtrees, undo restores provenance exactly,
  consolidation and merge repointing carry provenance,
  `rewriteAssemblyOnPastDives` for add, remove and replace across several
  dives with each dive re-stamped.
- Sync: parent-reference completeness, serializer round trip for
  `equipmentComponents` and for the two columns, `deleteEquipment`
  tombstones in both directions.
- Providers: rollup with self-only clocks, a descendant overdue winning, a
  nested descendant, a retired descendant excluded; adjacency invalidation
  on a components-table tick (poll, not `pumpEventQueue`).
- Widgets: Components card add, role edit, remove and reorder; picker
  exclusions; dive detail set header, collapsed assembly, expansion and
  nested expansion; dive edit removal semantics for group, subtree and
  single row; list chips; bulk edit chip; equipment type dropdown order.
- Buoyancy: an assembly with a wing declaring lift, through
  `composeRigTerms`, counted once.
- UDDF: export then import of a logbook with a nested assembly on a dive
  applied from a set, provenance preserved.
- Localisation: every new key present in all 11 ARB files.

## Delivery

Three stacked pull requests, each green on its own:

1. Schema v203, entities, `EquipmentComponentRepository`, sync wiring, new
   types, Components card and picker, list chips, rollup provider and
   badges, `deleteEquipment` tombstones. Ships the provenance columns
   unused, which is harmless.
2. Dive side: `Dive.gear` and `DivePlan.gear`, `GearExpander`, every
   writer, detail and edit rendering, set memory, bulk edit, planner
   parity, the two sync tidy-ups, leaf-only buoyancy, PDF grouping.
3. History and interchange: swap-with-history dialog and
   `rewriteAssemblyOnPastDives`, UDDF blocks, CSV and Excel column.

## Out of scope

Each is worth its own issue:

- Fanning components into pre-dive checklists (`SessionItemComposer` reads
  the set, not the dive).
- A version history of set membership. The per-dive snapshot covers the
  practical need.
- A hide-components filter in the equipment list.
- Suggested roles per equipment type.
- Tank assemblies such as twinsets. Tanks attach through `dive_tanks`, not
  the gear junction.
- Rolling assemblies up into the dashboard due list.
- Importing assemblies from MacDive or Subsurface, whose formats have none.
