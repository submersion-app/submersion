# Dive Computer Gear Twin: Design

**Status:** approved 2026-08-26
**Issue:** none yet. Related to #1020 (equipment set keyed on the downloading
computer), which this does not implement and does not block.
**Branch:** `worktree-dive-computer-gear-twin`
**Schema:** claims v175.

## Problem

A dive computer that downloaded a dive should appear as a piece of equipment on
that dive.

Today it does not, because Submersion models a dive computer twice in two
tables that have never been connected:

* `dive_computers`, the device registry: BLE address, firmware, download
  fingerprint, dive counters. Rows are created by BLE/USB download, by manual
  add, and (since #1288) by file import.
* `equipment` rows of `EquipmentType.computer`, the gear item: purchase date,
  service intervals, curated attributes.

A downloaded dive gets `dives.computer_id` stamped and shows its computer in the
Details card, but its Equipment section stays empty unless a default equipment
set happened to apply. The computer earns no service tracking, never appears in
gear statistics, and cannot be filtered on.

## Findings

Every claim below was verified on this branch at `80f07e66f2f`.

**F1. There is no bridge in either direction, and no serial matching between
the two tables.** `DiveComputers` (`database.dart:2425`) has no `equipmentId`
column; `Equipment` (`database.dart:936`) has no `diveComputerId`.
`grep -rn "DiveComputer" lib/features/equipment/` and
`grep -rn "Equipment" lib/features/dive_computer/` both return zero hits. The
only identity matching that exists (`dive_computer_repository_impl.dart:176`
`findByHardwareIdentity`, `:1602` `findOrCreateComputer`) is registry to
registry.

Two importers already mint `EquipmentType.computer` gear rows with no link back
to the registry: `uddf_full_import_service.dart:2228` and
`macdive_value_mapper.dart:105-108`. Those rows are exactly the pre-existing
items the resolution order in D3 must adopt rather than duplicate.

**F2. `dive_data_sources.computer_id` is the authoritative attribution, not
`dives.computer_id`.** The scalar holds only the primary computer, and
`_backfillDiveComputerIds` (`database.dart:4488`) derives it *from*
`dive_data_sources`, which is the richer table. A multi-source dive logged on
two computers has two source rows and one scalar. Attribution rides the FK, never
the `dive_computer_serial` / `dive_computer_model` snapshot columns, which are
nullable, duplicate across devices, and arrive from file imports with no
registered computer behind them (#1064).

**F3. `createComputer` is a chokepoint for three registration seams, but it is
not the only creation site.** `ensureComputer:280` (BLE/USB download), manual
add, and `findOrRegisterImportedComputer:1735` (file import) all funnel into
`DiveComputerRepository.createComputer` (`:216`). The `beforeOpen` self-heal
does not: `imported_computer_backfill.dart:124` writes registry rows with a raw
`INSERT OR IGNORE INTO dive_computers`, bypassing the repository entirely. Any
mint hook needs both sites.

**F4. `DiveEquipmentDefaulter` bails when the dive already has equipment.**
`dive_equipment_defaulter.dart:47` returns false if any `dive_equipment` row
exists. Anything that attaches gear *before* the defaulter silently suppresses
the user's default and geofenced equipment sets.

**F5. Three services already run together at four non-interactive creation
seams.** `DiveEquipmentDefaulter`, `ChecklistDiveLinker` and
`DiveAltitudeEnricher` are applied as a trio at
`dive_computer_repository_impl.dart:1204` (download, inside `importProfile`'s
new-dive branch, guarded by `isNewDive` at `:1116`),
`uddf_entity_importer.dart:1602`, `dive_import_providers.dart:396`, and
`healthkit_adapter.dart:283`.

**F6. Consolidation carries equipment across for free.**
`dive_consolidation_service.dart:457-477` unions `dive_equipment` from the
secondary dive into the target by `equipmentId` and marks each row pending.
`DiveComputerAdapter._consolidateDive:703` runs `importSingleDiveAsNew` before
`_consolidationService.apply:712`, so the snapshot already contains whatever the
temporary dive was given. No separate handling is required on this path.

**F7. The replaceSource path attaches nothing.** A re-download that replaces a
source on an existing dive takes `importProfile`'s `isNewDive == false` branch,
so the trio at `:1204` never runs. That computer did log that dive.

**F8. `EquipmentType.computer` enters the buoyancy model with a 0.5 kg
fallthrough.** `gear_feature_mapper.dart:21-23` returns null only for
`weights` and `tank`, so a computer becomes a `GearFeature`.
`gear_feature.dart` has no `computer` case in `_attributePrior` (`:115-163`,
falls to `default: return null`), `_typeDefault` (`:214-222`, falls to
`_ => 0.0`) or `_typeDryMass` (`:224-228`, falls to `_ => 0.5`). Both buoyancy
consumers go through that mapper: `buoyancy_twin_assembler.dart:293-294` and
`weight_planner_providers.dart:19-20`. Auto-creating gear rows would move every
downloaded dive's rig by 0.5 kg per computer.

**F9. The dive detail Equipment section is hidden when empty, and the computer
already appears elsewhere on the page.** `dive_detail_page.dart:482-488`
returns nothing when `dive.equipment.isEmpty`; there is no empty state.
`_buildEquipmentSection:4478` renders `dive.equipment` as plain tiles routing to
`/equipment/<id>`. Separately, `_buildLinkedComputerRow` (called from `:3124`)
renders a Details-card row routing to `/dive-computers/<id>`.

**F10. `getMostUsedGear` applies no type exclusion.**
`statistics_repository.dart:2063-2110` joins `equipment` to `dive_equipment` and
ranks by dive count with no `WHERE e.type` filter, so computers will rank as
ordinary gear.

**F11. `onUpgrade` is guaranteed on restore; sync adopt bypasses the ladder
entirely.** `DatabaseService.restore:736` copies the file into place and calls
`initialize()` at `:838`, and `_openDatabase:248-282` runs the ladder whenever
the stored `user_version` is below current; `backup_service.dart:659-677`
rejects newer-than-app backups while explicitly allowing older ones. The
recurring comment that a restored database never runs `onUpgrade`
(`database.dart:8774`, `:8804`, `:8973`) means only that a file arriving already
stamped at or above current enters no ladder block.

Sync adopt is different: `SyncService.adoptReplacedLibrary:3104` applies cloud
base and changeset payloads into the already-open database and never replaces
the file, so rows arriving by sync bypass the ladder. With
`minimumCompatibleSchemaVersion = 160` (`database.dart:3210`), a peer still on
v164 can sync new dives to an already-migrated device.

**F12. The house style puts full-table backfills in the ladder, not
`beforeOpen`.** Precedents: v132 `_backfillBottomTimeFromProfile` (`:8387`),
v158 `_backfillProfileSourceIds` (`:8584`, two set-based `UPDATE`s, documented
as belonging "to the ladder, not to every open"), v102
`_relinkStrandedTankPressures`, v122 `_backfillLegacyServiceSchedules`. The
inverse rule is stated repeatedly: a backfill that could resurrect user-deleted
rows must be `onUpgrade`-only (`:4334-4339`, `:3662-3664`, `:8829-8836`). Only
three data backfills live in `beforeOpen`, all local-only, HLC-neutral, and
cheap no-ops once healed.

If a per-dive loop is unavoidable in a migration, v132 documents why it must
yield: the executor is a synchronous main-isolate `NativeDatabase`, drift's
awaits resolve in microtasks, and an unbroken microtask chain never reaches the
vsync queue, freezing the migration spinner (`database.dart:3696-3726`, fixed
with `if (processed++ % 25 == 24) await Future<void>.delayed(Duration.zero);`).

**F13. The schema claim has moved twice; it is now v175.** Main is at v164
(`database.dart:3183`). A loop over open PR diffs returns v165 (#1290), v166
(#1300), v167 (#1276) and v168 (#1237); v138 (#603) is stale. Grepping main
alone would have said v165 was free and walked into a silent auto-merge.

**Renumbered twice.** v168 -> v169 during implementation, then v169 -> v175 when
main was merged in on 2026-08-27 and #1322 (v170) and others had landed. The
scalar, the ladder entry, the assert docstring, the `if (from < N)` guard and its
`reportProgress` twin, the beforeOpen backstop comment, and the migration test
filename with its assertions all move together; verified after the second
renumber that the ladder is monotonic, unique, and that the scalar equals its
maximum.

**Originally renumbered from v168 during implementation.** The first scan saw #1237 at
v161. That PR was renumbered to v168 and pushed while this design was being
written, so the claim was invisible to both the main grep and the open-PR scan
at the moment they ran. Two branches writing the same scalar auto-merge with no
conflict marker, so the collision would have surfaced only as a database
silently skipping a rung. Re-run the scan immediately before opening the PR.

**F14. #1297 is a working template for find-or-create with deterministic ids.**
`findOrRegisterImportedComputer:1666` matches identity in Dart (not SQL, because
stored text may carry whitespace from an older import), orders candidates
`updated_at DESC, id` so two devices pick the same row, then derives a
deterministic id and, critically, adopts the row already holding that id before
inserting. Its comment states the trap directly: the identity match reads the
row's current text while the id derives from the file's text, so renaming a
registered computer makes the match miss while the id still collides, and the
insert throws `SqliteException(1555)`.

The deterministic id convention is `course_requirement_repository.dart:39-43`:
a static factory returning `Uuid().v5(Namespace.url.value,
'submersion:<kind>:<parts>')` with a doc comment explaining convergence.
`dive_computers` deliberately has no unique index, because a unique constraint
on a replicated table makes an inbound sync insert throw instead of merge.

## Design

### D1. Bridge column on the registry

Add to `DiveComputers` (`database.dart:2425`):

```dart
/// The equipment row representing this device as gear. Seeded once at
/// registration, then owned by the user: renaming or retiring the gear item
/// never writes back here, and renaming the computer never overwrites it.
/// setNull, not cascade: deleting the gear item leaves the device registered.
TextColumn get equipmentId => text().nullable().references(
  Equipment,
  #id,
  onDelete: KeyAction.setNull,
)();
```

The registry side owns the link because it is tiny (a handful of rows per
diver), so the column is dense rather than mostly null, and because a device
pointing at its representation reads correctly while a gear item claiming a
device does not.

Unlike the neighbouring `bluetoothAddress`, which is explicitly device-local
and must not synchronize, `equipmentId` **does** synchronize: equipment ids are
fleet-stable, and a peer receiving a `dive_computers` row whose `equipmentId`
points at nothing would hold a dangling reference.

The `onDelete: setNull` is load-bearing. It is the mechanism, not a
convenience: it implements half of the deletion semantics in D6.

**Correction, found in review.** Declaring it on the table class alone is not
enough. A fresh database gets the FK from that declaration through `onCreate`,
but an upgraded one gets whatever the migration's `ALTER TABLE` says, and a bare
`ADD COLUMN equipment_id TEXT` carries no constraint. That would have left
`setNull` true only for new installs while existing users, the population this
feature exists for, kept `equipment_id` pointing at deleted rows. The assert
helper must spell out `REFERENCES equipment(id) ON DELETE SET NULL`, matching
the v158 `_assertProfileSourceIdColumn` precedent.

A second trap sits behind the first: SQLite accepts a reference to a table that
does not exist at `ALTER` time, then fails *every subsequent write* to
`dive_computers` with `no such table: main.equipment` once foreign keys are on.
The v66 migration test, whose fixture has no `equipment` table, is what surfaced
this. So the clause is added only when `equipment` is present. Every real
database has it, so production always takes the FK branch; where the bare
fallback applies there are no gear rows for the FK to act on anyway.

### D2. Deterministic twin id

```dart
/// Deterministic gear-twin id: every device derives the same equipment row for
/// a given registered computer, so two devices registering the same computer
/// converge to one row under sync upsert instead of duplicating. A minted
/// backfill row cannot use v4 for exactly this reason.
static String gearTwinIdFor(String computerId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:dive-computer-gear:$computerId',
);
```

It derives from `dive_computers.id`, which is itself stable and synced, rather
than from model or serial text, which a user can rename.

Placement mirrors #1297: the id helper and the candidate-matching predicate live
in a plain-Dart file importable by both the repository and the migration, so the
ladder and the runtime path cannot drift apart.

### D3. Resolution order

`resolveGearTwin(computer)` returns an equipment id, applying these steps in
order. The order is the design; it is where the F14 rename trap lives.

1. `computer.equipmentId` is set and that equipment row still exists. Return it.
2. An equipment row already holds `gearTwinIdFor(computer.id)`. Adopt it. This
   is the branch that prevents `SqliteException(1555)` when a user has renamed
   the computer, because the derived id still collides while text matching has
   stopped agreeing.
3. Exactly one `equipment` row with `is_active = 1` (the `status` column is
   independent and is not consulted, so a computer marked `needsService` still
   matches) has `type == 'computer'`, the same
   `diverId`, and matches on serial when the computer's serial is non-null, or
   on normalized brand plus model when it is null. Adopt it. This is what picks
   up gear the user created by hand, and the rows F1 notes that UDDF and MacDive
   imports already mint. Zero or several candidates fall through: guessing
   between two identical computers is worse than creating a second row. Matching
   is done in Dart with the same normalization as `matchImportedComputer`,
   because stored text may carry whitespace from an older import.
4. Mint at `gearTwinIdFor(computer.id)`.

Then stamp `equipmentId` back onto the registry row.

Minted rows carry `diverId`, `name` from the computer's name, `type: computer`,
`brand` from `manufacturer`, `model`, and `serialNumber`. Purchase and service
fields stay null. Filling those in is the user's job, and is the point of
seeding once.

Serial matching in step 3 is deliberately conditional: libdivecomputer leaves
the serial null for many devices (#1064), so a serial-only rule would be dead
for a large share of users.

### D4. Two mint sites

Per F3:

* `DiveComputerRepository.createComputer` (`:216`), covering BLE/USB download,
  manual add, and file-import registration.
* `imported_computer_backfill.dart`, alongside its raw
  `INSERT OR IGNORE INTO dive_computers` at `:124`.

**Mint only where the computer row was genuinely inserted.** In the heal, if
`INSERT OR IGNORE` no-ops because the computer already exists, the twin mint is
not reached. This single rule satisfies the F12 resurrection constraint without
any tombstone lookup: a user-deleted twin cannot reappear on the next app open,
because the only path that would recreate it runs only when the computer itself
is new.

### D5. The linker links, it never creates

New `DiveComputerGearLinker` in
`lib/features/equipment/data/services/`, a fourth member of the F5 trio and
shaped like `ChecklistDiveLinker`:

```dart
Future<bool> linkComputerGearForDive({
  required String diveId,
  required String? diverId,
});
```

It resolves the dive's computers from the union of `dive_data_sources.computer_id`
and `dives.computer_id` (per F2, so a multi-source dive links every computer that
logged it), takes each computer's `equipmentId` **as stored**, and attaches the
non-null ones via `bulkAddEquipment`.

**Correction, found in implementation.** An earlier draft of this section said to
reuse `DiveComputerRepository.getComputerIdsForDive`. That method reads
`dive_profiles`, not `dive_data_sources`, so it sees only dives carrying profile
samples. A file-imported dive registered by #1288 can have `computer_id` stamped
and a data-source row while having no samples at all, and reusing the helper
would have silently failed to link exactly the file-import case this feature was
extended to cover. The linker owns a private query applying the same union the
v175 backfill uses, so the migration and the runtime path cannot disagree.

It performs no resolution and no minting. That is what makes deletion permanent:
creation happens once at registration, linking happens per dive, and a cleared
`equipmentId` simply produces no link.

Like the defaulter, it is best-effort and swallows its own failures. Equipment
linking must never abort a download that has already persisted a dive.

Unlike the defaulter, it is **not** gated on the dive having no equipment.

### D6. Deletion semantics

| Action | Result |
|---|---|
| User deletes the gear twin | `dive_equipment` rows cascade away (FK on `Equipment.id`); `dive_computers.equipment_id` becomes NULL via `setNull`; no later download re-mints, because `ensureComputer:234` early-returns for an already-registered computer and never reaches `createComputer` |
| User deletes the registry computer | The gear item survives untouched. It is real gear they still own, with their service history on it |
| User renames either side | Nothing propagates. Step 2 of D3 keeps resolution correct anyway |

### D7. Seams and ordering

The linker runs **strictly after** `DiveEquipmentDefaulter` at every seam. Per
F4, running it first would suppress the user's default and geofenced equipment
sets entirely. This ordering gets a regression test, not a comment.

| Seam | Behaviour |
|---|---|
| `dive_computer_repository_impl.dart:1204` (download, new dive) | link after defaulter |
| `uddf_entity_importer.dart:1602` | link after defaulter |
| `dive_import_providers.dart:396` | link after defaulter |
| `healthkit_adapter.dart:283` | no-op (no registry computer); included so the trio stays uniform |
| Consolidation | covered for free, per F6 |
| `importProfile` replaceSource branch (`isNewDive == false`) | new, per F7; idempotent through `insertOnConflictUpdate` |

### D8. Migration v175

Two passes in the `if (from < 175)` block, both PRAGMA-guarded like every
neighbouring helper.

**Pass 1** resolves every existing `dive_computers` row through D3 and stamps
`equipment_id`. Bounded by device count, a handful of rows, so no event-loop
yield is needed.

**Pass 2** is a single set-based insert over the union of both attribution
sources (F2):

```sql
INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id)
SELECT s.dive_id, c.equipment_id
  FROM dive_data_sources s
  JOIN dive_computers c ON c.id = s.computer_id
 WHERE c.equipment_id IS NOT NULL
UNION
SELECT d.id, c.equipment_id
  FROM dives d
  JOIN dive_computers c ON c.id = d.computer_id
 WHERE c.equipment_id IS NOT NULL;
```

Being set-based, it sidesteps the F12 spinner-freeze problem entirely rather
than needing v132's `% 25` yield, and mirrors how v158 did its two `UPDATE`s.

Ordering within the ladder: pass 2 must follow pass 1, since it reads the column
pass 1 writes.

The claim touches six places, all of which must move together if the number is
renumbered before merge: the `currentSchemaVersion` scalar, the
`migrationVersions` ladder entry, the `_assert*` helper docstring, the
`if (from < 175)` guard and its `reportProgress` twin, the `beforeOpen` backstop
comment, and the migration test filename with its version assertions. The ladder
is monotonic and unique but **not** contiguous by design (162 is permanently
skipped, and 165 through 168 are reserved by open PRs); the audit must not
"fix" that.

A `beforeOpen` column assert is still required, per the F11 rule that a database
arriving already stamped at or above v175 enters no ladder block. That assert is
schema-only. It adds the column if missing; it does not backfill.

### D9. Sync

**Corrected in review. The original D9 said the opposite and was wrong on both
of its stated reasons.**

The runtime paths mark pending and replicate: the resolver when it mints a twin,
`createComputer` when it stamps `equipment_id`, and `bulkAddEquipment` for every
link the linker adds.

The **v175 backfill is local-only and HLC-neutral**, like `_backfillDiveComputerIds`.
It stamps no HLC and marks nothing pending, so its writes never go out on an
incremental sync. This is correct rather than an oversight: every input is
already synced (`dive_computers`, `dives`, `dive_data_sources`) and the twin id
is derived, so every device produces identical rows independently when its own
ladder runs. Marking them pending would push one record per computer plus one
per (dive, computer) pair from every device in the fleet, to make peers agree on
rows they will each derive anyway. That fleet-wide re-sync is precisely the cost
F12 cites as the reason the #1064 heal stayed local-only.

The original reasoning claimed two things that do not hold:

1. *"A peer can receive a `dive_computers` row whose `equipment_id` points at a
   twin it never minted."* It cannot. A peer still on the previous schema has no
   `equipment_id` column, so the field is dropped on apply; a peer at v175 has
   run its own ladder and derived the same twin.
2. *"Sync adopt bypasses the ladder, so the rows must replicate."* A base or full
   export passes `hlcSince == null` and therefore carries every row regardless of
   HLC, so a device adopting the cloud base receives the backfilled twins.

**Known limitation, accepted.** A dive downloaded by a peer still on the previous
schema and synced to an already-migrated device is not linked on that device: its
ladder has run, the runtime linker fires only at local creation seams, and the
peer's own later backfill is HLC-neutral so it does not push. That is a missing
join row on one device during the rollout window, not divergence in the twin
itself, and it resolves the moment anyone edits that dive's gear. Closing it
would require either a fleet-wide re-sync or a link step on the sync-apply path,
and neither is worth that cost.

`dive_computer_gear_backfill_test.dart` asserts the HLC-neutrality directly, so
the choice cannot be silently reversed.

### D10. Buoyancy

Add an explicit `computer` case to both `_typeDefault` and `_typeDryMass` in
`gear_feature.dart`, each returning `0.0`, leaving the `buoyancy_kg` and
`dry_weight_kg` attribute path live so a tech diver can still model a canister
or console as real mass.

This also changes existing users who added a computer as gear by hand: they lose
0.5 kg of rig dry mass. That is a move toward correctness, since 0.5 kg was
never a considered value for computers but the `_ => 0.5` fallthrough, and it
belongs in the release notes.

### D11. UI

**No change needed on the dive detail page.** `_buildEquipmentSection` renders
whatever is in `dive.equipment`, so the twin arrives as an ordinary tile with
the `Icons.watch` avatar and a "Dive Computer" trailing label.

Two consequences are accepted deliberately rather than worked around:

* Per F9, the Equipment section stops being conditionally hidden on downloaded
  dives, because they now always have at least one item.
* The computer appears twice on the page, as a Details-card row and as a gear
  tile. Both are kept: they route to different destinations answering different
  questions (`/dive-computers/<id>` for firmware and download history,
  `/equipment/<id>` for service and purchase). Deduplicating would remove the
  device page's only entry point from a dive.

**One row added** to the dive computer detail page showing its linked gear item.
The column is local, and this is the only place that explains where the new
equipment came from. Needs one new string translated across all locales.

Per F10, computers will now rank in "Most Used Gear", usually at the top. That
is honest rather than wrong, and is left alone; it belongs in the release notes.

## Error handling

The linker is best-effort and swallows its own failures, matching
`DiveEquipmentDefaulter`. A download that has already persisted a dive must
never be aborted by equipment linking.

Resolution failures inside `createComputer` are logged and swallowed: a computer
that fails to get a twin is still a correctly registered computer, and the next
migration or a manual add can heal it. Registration itself must not fail because
gear seeding did.

The migration follows the ladder's idempotency contract, since a crash mid-ladder
leaves `user_version` unchanged and re-runs every step from the top on a fresh
connection. Pass 1 is idempotent through D3 step 1; pass 2 through
`INSERT OR IGNORE` on the composite key.

## Testing

Tests first, per the project guide.

**Resolution order** (`resolveGearTwin`)
* derived-id adoption after a rename, the `1555` case from F14
* unambiguous identity match adopts a hand-created gear item
* two identical candidates mint instead of guessing
* null-serial computers match on brand plus model
* a computer whose twin was deleted resolves to nothing and does not re-mint

**Migration v175**
* stranded-database fixture at v168 with computers, dives, and data sources
* twins minted, `equipment_id` stamped, join rows inserted
* a multi-source dive links **both** computers (the F2 case)
* idempotent across a re-run
* ladder audit: monotonic, unique, scalar equals max, not asserted contiguous

**Ordering**
* a downloaded dive receives its default equipment set **and** its computer,
  proving the F4 suppression does not occur

**Deletion**
* deleting the twin nulls `equipment_id`, cascades the joins, and the next
  download does not re-mint
* the `beforeOpen` heal does not re-mint a deleted twin for an existing computer

**Sync**
* two devices converge on one twin, no duplicates

**Buoyancy**
* a computer contributes 0.0 to the buoyancy twin and the weight planner

## Out of scope

* **#1020**, choosing an equipment *set* based on which computer downloaded the
  dive. Related, separately valuable, not blocked by this.
* Mirroring identity fields between the two rows. Explicitly rejected: it would
  overwrite a user's chosen gear name and HLC-bump the fleet on every firmware
  correction.
* A reverse badge on the equipment detail page, and any "recreate deleted twin"
  action. Both additive later.
* Transmitters. `EquipmentType.transmitter` exists and #1223 is separately
  tracking transmitter to tank mapping; nothing here touches it.
* Filtering computers out of gear statistics.

## Follow-ups

* Release notes must call out three user-visible changes: new gear items
  appearing for registered computers, computers ranking in "Most Used Gear", and
  the 0.5 kg buoyancy shift for anyone who had added a computer as gear by hand.
* If the "Most Used Gear" ranking proves unpopular, the cheapest fix is a type
  exclusion in `getMostUsedGear`, not a change to the data model.
