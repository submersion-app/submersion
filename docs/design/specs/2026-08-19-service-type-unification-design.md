# Service Type Unification

**Date:** 2026-08-19
**Status:** Approved design, pending implementation plan
**Branch/worktree:** `worktree-service-type-unification` at
`.claude/worktrees/service-type-unification`, branched from `origin/main`
(schema 157) after PR #1158 merged.

## Problem

Two unrelated concepts are both called "service type" in the UI, and the one
that is actually the catalog is labelled something else entirely.

- `ServiceType` (`lib/core/constants/enums.dart:240`) is a fixed enum of ten
  hardcoded English values (annual, repair, inspection, overhaul, replacement,
  cleaning, calibration, warranty, recall, other). It is stored on
  `service_records.service_type`, drives the history row icon, and appears in
  the Excel maintenance log and the UDDF export. In the record dialog it is
  labelled **"Service Type"**.
- `ServiceKind` (the `service_kinds` table: twelve built-ins plus user
  customs) is the catalog that service clocks hang off. Its management page
  is `ServiceKindListPage`, routed at `/equipment/service-types`, route name
  `manageServiceTypes`, page title **"Service types"**. In the record dialog
  the same concept is labelled **"Applies to clock"**.

So when logging a service record the diver picks from a dropdown named
"Service Type" that has nothing to do with the screen named "Service types",
and the field that *is* that screen's contents is named after clocks. Two
reported symptoms follow:

1. The catalog management screen is reachable only from the add-a-service-clock
   flow. There is no entry in Settings > Manage, where every other catalog
   (dive types, dive roles, tank presets, checklist templates, species, tags)
   lives.
2. When adding a service record, the difference between "Service Type" and the
   clock kinds is unclear.

PR #1158 (merged 2026-08-19) already fixed the worst downstream consequence:
history rows are now titled by their `ServiceKind` rather than by the enum. It
deliberately left the two concepts orthogonal, which is correct as a model but
leaves the naming collision in place.

## Decisions

| Decision | Choice |
| --- | --- |
| What the record form asks for | One required catalog pick, plus an optional category |
| Which concept owns the name "service type" | The catalog (`ServiceKind`) |
| Legacy records with no catalog entry | Left alone, no data migration |
| Where the category prefill comes from | A `defaultCategory` column on the catalog entry |
| Code-level rename | Full rename, `ServiceType` becomes `ServiceCategory` |
| Sync wire key | Renamed, with the compatibility floor raised to 160 |

### 1. Naming

The catalog owns "service type" everywhere. The enum becomes "category".

| Surface | Before | After |
| --- | --- | --- |
| Record dialog, catalog dropdown | "Applies to clock" | "Service type" |
| Record dialog, enum dropdown | "Service Type" | "Category" |
| Manage page title | "Service types" | unchanged |
| Excel maintenance log headers | "Task" / "Category" | "Service Type" / "Category" |
| Dart enum | `ServiceType` | `ServiceCategory` |
| Dart field, column, JSON key | `serviceType` / `service_type` | `serviceCategory` / `service_category` |

The catalog dropdown gains helper text explaining that logging a record against
a service type resets that type's clock, which is the one piece of behaviour
the old "Applies to clock" label did convey and the new name does not.

### 2. Record form

- The catalog picker moves to the top of the dialog and becomes **required on
  create**. It is currently second and optional.
- Category sits directly below it, visually secondary, with helper text
  "Used for filtering and export". It stays inline rather than behind a
  disclosure: the dialog already carries cost, currency, provider and notes
  inline, so a lone collapsible for one dropdown would read as an anomaly.
- The picker is **not** required on edit. Requiring it there would mean that
  opening a pre-existing record to correct a typo forces a catalog assignment,
  and assigning a kind moves a clock anchor (see below). On edit the picker
  offers "Not set" and saving with it is legal.

### 3. Legacy records: no migration

Records written before the `service_kinds` catalog existed, and every record
arriving through UDDF or MacDive import, carry a category but no
`serviceKindId`. They stay that way. `ServiceHistorySection` already falls
back to the category for the row title, so they read correctly.

This is a deliberate refusal of a tempting backfill. `ServiceDueEngine`
computes next-due by anchoring on **the newest `ServiceRecord` carrying that
kind id**, falling back to `schedule.anchorDate`, then `purchaseDate`, then
`createdAt`. Retroactively attaching catalog entries to old records is
therefore not a cosmetic relabelling: it moves clock anchors, so a hydro clock
could jump by years and an overdue badge could appear or vanish on upgrade. A
diver who wants an old record to count against a clock can attach one by
editing that record, deliberately, one at a time.

### 4. Schema v160

Two changes, neither touching `service_records` rows.

**`service_kinds.default_category`**, TEXT nullable, holding a
`ServiceCategory.name`. `ServiceKind` gains `defaultCategory`, using the
`_undefined` sentinel `copyWith` the entity already uses for its other
nullable fields, plus a `props` entry.

**`service_records.service_type` renames to `service_category`.**

The migration:

1. Adds `default_category` to `service_kinds`.
2. Runs one `UPDATE` seeding categories for built-in slugs only:
   `hydro`, `vip` and `bcd-inspection` to inspection; `o2-clean` to cleaning;
   `regulator-service`, `rebreather-annual` and `general-service` to annual;
   `computer-battery`, `transmitter-battery`, `scrubber-repack` and
   `o2-cell-replacement` to replacement; `drysuit-seals` to repair. Custom
   kinds start null.
3. Renames the `service_records` column.

`kSeedBuiltInServiceKindsSql` (`database.dart:2267`) gains the column so fresh
installs match. That constant is `INSERT OR IGNORE` and runs in `beforeOpen`,
so it cannot update rows that already exist, which is why step 2 is a separate
explicit `UPDATE`. Step 2 uses `UPDATE` rather than upsert precisely so it
cannot resurrect a built-in the diver deleted, per the v109 rule.

The migration must self-guard on table existence. Minimal migration fixtures
ride the whole ladder from early versions and omit tables that did not exist
yet; a migration that assumes `service_kinds` is present crashes the entire
ladder for those fixtures.

### 5. The rename, layer by layer

Roughly 169 Dart references across `lib/` and `test/`.

- **Identifiers.** `ServiceType` to `ServiceCategory`; `serviceType` to
  `serviceCategory` in `ServiceRecord`, `MaintenanceHistoryFilter`,
  `ExportServiceRecord`, the repository, the dialog, the history section, the
  Excel service, the UDDF builders and parsers, and the MacDive mapper.
  `presentation/utils/service_type_label.dart` becomes
  `service_category_label.dart`, and `serviceTypeLabel(l10n)` becomes
  `serviceCategoryLabel(l10n)`. `displayName` stays English, as #1158
  established, because Excel export wants English.
- **Excel headers.** #1158 already writes `Task` and `Category` rather than
  the old single "Service Type" column, so the category column is correct
  as-is. The `Task` header becomes `Service Type`, to match the vocabulary
  this design settles on, along with the class docstring that explains the
  pair. The workbook is an analysis target that someone may script against,
  so the header change is called out in the release notes.
- **SQL column.** Renamed by the migration. One raw-SQL read at
  `service_record_repository.dart:312` reads `row.data['service_type']` and
  updates with it.
- **UDDF.** The `<servicetype>` element becomes `<servicecategory>`. The
  importer accepts **both** spellings, so files exported by older Submersion
  builds still read. This is a file format that users hold on disk
  indefinitely; unlike the sync wire, there is no version handshake that could
  ever tell us which spelling to expect.
- **Sync and backup wire key.** Renamed. This is the layer with a cost, below.

### 6. Cross-version sync

The sync layer serialises rows through Drift's generated `row.toJson()`
(`sync_data_serializer.dart:1677` and the parallel apply paths), and Drift
keys that JSON on the **Dart getter name**. Renaming the column getter
therefore renames the sync and backup wire key, which the shipped #1089
contract classifies as breaking: the bump rules on
`AppDatabase.minimumCompatibleSchemaVersion` say to raise the floor when a
migration "drops, renames, or retypes an existing synced column."

**The floor goes 137 to 160.** Consequences, accepted deliberately:

- Every peer publishing from a schema below 160 is held by updated readers
  until it updates. Per #1089's own figures that is the entire App Store fleet
  (schema 137 at the time of writing) and GitHub-channel devices below 160.
- The hold is per-peer, non-destructive, and self-heals when the peer updates.
- #1089's channel-aware banner already tells store users the truth rather than
  "update this device", so the messaging for this window exists.
- The cost is stated plainly in the PR body and the release notes rather than
  left for users to discover.

**The floor is not sufficient on its own.** The gate at
`changeset_reader.dart:162` is `peerSchema > localSchemaVersion`, which is the
reader's check on the writer's floor. It is one-directional. Raising our floor
stops old devices applying our payloads; it does nothing about old devices'
payloads arriving here, because their floor (137) is not greater than our
schema (160), so we accept them. Those payloads are keyed `serviceType`, and
`sync_data_serializer.dart:2549` runs
`ServiceRecord.fromJson(data).toCompanion(false)` against a NOT NULL
`serviceCategory` column. Drift's generated `fromJson` throws when the key is
absent, so every service record created on a not-yet-updated device would fail
to apply on an updated one. The same apply path serves restore, so older
backups would fail the same way.

**Read-side normaliser.** One small function rewrites an incoming
`serviceType` key to `serviceCategory` for the `serviceRecords` entity,
applied wherever an incoming record map reaches the apply path: the
`insertOnConflictUpdate` case, the streaming adopt path, and
`_overlayOntoLocal`. It carries a comment naming the floor version after which
it can be deleted.

Note on what actually syncs: `_exportServiceKinds` filters to
`isBuiltIn = false`, so built-in kinds are local reference data re-seeded per
device and their `default_category` never crosses the wire at all. The known
#1144 gap, where new columns on these tables do not reach a second device
incrementally, therefore applies only to `default_category` on **custom**
kinds. It is inherited, not introduced here, and is called out in the PR body
exactly as #1158 did for `defaultCost`.

### 7. Category prefill

A pure resolver, `resolveDefaultServiceCategory({serviceKindId, kinds})`,
placed beside `resolveDefaultServiceCost` in
`domain/services/default_service_cost_resolver.dart`. It is a plain lookup
rather than the two-level chain cost uses, because `ServiceSchedule` carries no
category: a category describes what kind of work a service type is, which does
not vary per item the way a price does.

The dialog mirrors the shipped cost pattern: prefill runs in `build`, not
`initState`, because kinds are `FutureProvider`s unresolved at first build; it
is guarded by `isEditing` so editing never re-prefills; and a `_categoryTouched`
flag means a category the diver chose is never overwritten when they change the
service type.

### 8. Surfaces

- **Settings > Manage** gains a "Service types" tile with subtitle, routed to
  the existing `manageServiceTypes` route, beside Tank presets and Checklist
  templates. New l10n keys `settings_manage_serviceTypes` and
  `settings_manage_serviceTypes_subtitle`.
- **`ServiceKindListPage`** gains a Category dropdown in its add/edit dialog,
  and shows the category in each row's summary line next to the interval
  summary.
- **The record dialog** gains a "Manage service types" text action beside the
  picker, so the catalog is reachable at the point of confusion rather than
  only from the add-clock flow.
- The existing entry point from `ServiceClocksCard` stays.

## Testing

- Migration test for v160, self-guarding on table existence, asserting the
  column rename and the built-in category seeding, and asserting that a
  deleted built-in stays deleted.
- Unit tests for `resolveDefaultServiceCategory`, including a custom kind with
  no default and an unknown kind id.
- Extension of `test/core/services/sync/cross_version_roundtrip_test.dart`
  pinning both spellings through the normaliser: a payload keyed `serviceType`
  applies, and a payload keyed `serviceCategory` applies.
- Restore test: a backup written with the old key restores.
- UDDF round-trip test: both element spellings import.
- Widget tests for the dialog: prefill on picking a service type, prefill
  suppressed once the category is touched, required on create, not required on
  edit. These need a tall viewport (`physicalSize = Size(800, 4000)`), because
  the dialog is a lazy scroll view and an absence assertion against an
  off-screen child false-passes.
- Widget test for the Settings > Manage tile navigating to the catalog.
- l10n keys added and translated across all 11 locales.

## Risks

- **The compatibility floor bump is the dominant risk** and is a chosen cost,
  not an oversight. It should ship in a release whose store submission is
  already queued, so the hold window is as short as Apple review allows.
- **Schema renumbering.** Claimed v160 after 158 went to #1149 and 159 to
  #1177 during implementation, in which case the migration, its test, and every docstring
  renumber together.
- **Rename breadth.** Roughly 169 references, several inside export and import
  paths that carry their own fixtures. The rename is mechanical but wide, and
  a missed test fixture surfaces as an import producing the wrong category
  rather than as a compile error.

## Out of scope

- Backfilling `serviceKindId` on legacy records, and any bulk-assignment
  assistant for doing so.
- Fixing the #1144 incremental-sync gap for new columns.
- Making `ServiceCategory` user-extensible. It stays a fixed enum; the
  user-extensible axis is the catalog.
