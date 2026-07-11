# Dive Roles: Custom Roles and the Diver's Own Role

**Date:** 2026-07-10
**Issues:** [#551](https://github.com/submersion-app/submersion/issues/551) (custom/extensible buddy roles), [#547](https://github.com/submersion-app/submersion/issues/547) (record my own role on a dive)
**Status:** Approved design, pending implementation plan

## Problem

1. **#551** - The buddy role on a dive is a fixed six-value enum (Buddy, Dive Guide,
   Instructor, Student, Divemaster, Solo). Teams use roles outside this list, for
   example the Dutch "Hekkensluiter" (rear guard / sweeper: the last diver of the
   group, responsible for keeping the group together). Users need custom roles.
2. **#547** - There is no way to record the logged-in diver's own role on a dive
   (instructor, guide, buddy, rear guard). The `dives` table has no such field.

## Current state

- `dive_buddies.role` is already free TEXT (default `'buddy'`) storing the
  `BuddyRole` enum `.name` string. The enum constraint lives only in the Dart
  domain layer: `BuddyRole.values.firstWhere(..., orElse: () => BuddyRole.buddy)`
  silently coerces unknown strings to Buddy.
- `BuddyRoles` (credential rows: which professional roles a buddy holds) is a
  separate concern validated against `kProfessionalBuddyRoles`. It is NOT changed
  by this design.
- `DiveTypes` is the established precedent for built-in + custom reference data:
  slug id, nullable `diverId`, `name`, `isBuiltIn`, `sortOrder`, `hlc`, a
  management page at `/dive-types`, built-in re-seed guard in `beforeOpen`, and
  sync exporters that skip `isBuiltIn` rows.

## Decisions made during brainstorming

- Custom roles are a **managed list** (reusable, consistent), not free text.
- **New built-in defaults** are added alongside custom support: Rear Guard,
  Support Diver, Safety Diver.
- My own role (#547) lives **in the Buddies section** of the dive edit page as a
  pinned "Me" chip, sharing the same role vocabulary.
- Custom roles get **inline creation in the picker AND a Settings management
  screen** (like Dive Types).
- Architecture: **Approach A** - a `dive_roles` reference table mirroring
  `dive_types` (chosen over enum+overlay table, and over free text with
  autocomplete).

## Design

### 1. Data model & migration (v103)

New table `DiveRoles`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | Slug. Built-ins reuse the strings already stored in `dive_buddies.role`: `buddy`, `diveGuide`, `instructor`, `student`, `diveMaster`, `solo`, plus new `rearGuard`, `supportDiver`, `safetyDiver` |
| `diverId` | TEXT nullable -> Divers | null for built-ins |
| `name` | TEXT | English name for built-ins (fallback and export); user's text for custom roles |
| `isBuiltIn` | BOOL default false | |
| `sortOrder` | INT default 0 | |
| `createdAt` / `updatedAt` | INT | |
| `hlc` | TEXT nullable | HLC for cross-device conflict resolution |

- `dives` gains one nullable TEXT column `diver_role` (the active diver's own
  role, #547). No FK constraint, matching `dive_buddies.role`, to avoid
  sync-ordering FK failures. `null` = not recorded.
- `dive_buddies.role` is untouched. Existing values already equal the built-in
  slugs, so existing rows resolve with zero data migration. Unknown strings
  display as-is (synthetic role) instead of coercing to Buddy.
- Migration v103 creates the table, seeds built-ins, adds `dives.diver_role`.
  A `beforeOpen` guard re-seeds missing built-ins (dive-types adopt/wipe lesson).
- A custom role cannot be deleted while referenced by any `dive_buddies.role`
  or `dives.diver_role`.
- Custom roles are created with the active diver's `diverId` (same scoping as
  custom dive types); rows with `diverId` null are reserved for built-ins.
  Custom role ids are generated UUIDs, not name-derived slugs, so renames never
  break references.

Display names: built-ins resolve through l10n by slug
(`diveRole_builtin_<slug>`), falling back to the DB `name`; custom roles show
their stored name verbatim. Dutch translation of `rearGuard` is "Hekkensluiter".

### 2. Domain & repository layer

New feature folder `lib/features/dive_roles/` mirroring `dive_types`:

- `domain/entities/dive_role.dart` - `DiveRole` entity (`id`, `name`,
  `isBuiltIn`, `sortOrder`, `diverId`, `copyWith`) plus a `localizedName(l10n)`
  helper (translated string for built-in slugs, stored name for custom).
- `data/repositories/dive_role_repository.dart` - CRUD, change-watch stream,
  usage count for the delete guard, built-in re-seed guard.
- `presentation/providers/dive_role_providers.dart` - `allDiveRolesProvider`,
  an id->DiveRole map provider for cheap lookup, CRUD notifier.

Type change that ripples: `BuddyWithRole.role` changes from the `BuddyRole`
enum to a `DiveRole` entity. `buddy_repository` resolves the stored slug when
loading; unknown slugs produce a synthetic `DiveRole(id: slug, name: slug)`.
Writers store `role.id`. Consumers to update: buddy picker, dive edit/detail
pages, signature widgets (`buddy_signature_card`, `buddy_signature_request_sheet`),
PDF templates that print roles, UDDF export/import, buddy merge repository.

`Dive` entity gains `diverRoleId` (`String?`). The dive repository reads/writes
the new column; UI resolves display names via the roles map provider (no join
on dive list queries - the role only displays on detail/edit pages).

The `BuddyRole` enum survives only for `BuddyRoles` credential rows
(`kProfessionalBuddyRoles`). The picker's credentials-float-to-top behavior
matches credential slugs against `DiveRole.id`.

### 3. UI

- **Role picker** (both bottom sheets in `buddy_picker.dart`): replace
  `BuddyRole.values` with `allDiveRolesProvider` - built-ins first (by
  `sortOrder`), then custom. A final "Add custom role..." row opens a name
  dialog, saves, and immediately applies the new role. Credential-backed roles
  still float to the top.
- **"Me" chip (#547)** in the dive edit Buddies card: pinned first chip with
  the active diver's initials/name, primary-container styling, non-removable.
  Tapping opens the same role selector plus a "No role" entry (my role is
  optional). Unset state shows "Set my role" as the chip subtitle. Saved with
  the dive like other edit-page fields.
- **Dive detail page**: when `diverRoleId` is set, the Buddies section shows a
  "Me - <role>" row above buddy rows in the same list-tile style. When unset,
  nothing extra renders.
- **Management screen** at `/dive-roles`, cloned from `dive_types_page.dart`:
  built-in section (not deletable, localized names) and custom section with
  add (FAB), rename, delete. Delete blocked with a snackbar when the role is in
  use. A "Dive Roles" entry joins Settings -> Manage Data.

### 4. Sync, export & localization

- **Sync:** `dive_roles` becomes an HLC-synced entity in
  `sync_data_serializer` (base + incremental), using `.toCompanion(false)` like
  other HLC entities. Exporters skip `isBuiltIn` rows - built-ins are seeded
  locally on every device; only custom roles travel. Custom-role deletions get
  deletion-log tombstones. `dives.diver_role` rides along with existing
  dives-row sync; the consolidation scalar-adopt list (the #542 fix) gains
  `diver_role` so merging two computers' dives does not drop it.
- **Backup/restore:** custom roles and the new column are included in the full
  UDDF backup/restore path.
- **UDDF interchange export:** buddy-element bucketing keeps its mapping -
  leader slugs (`diveGuide`, `diveMaster`, `instructor`) map to leader; new
  built-ins and all custom roles fall into the plain buddy bucket. Import
  behavior unchanged.
- **Localization:** new keys for the 9 built-in role names
  (`diveRole_builtin_<slug>`), picker strings ("Add custom role...", "No role",
  "Set my role", "Me"), and the management screen set (cloned from
  `diveTypes_*`). Translated into all 10 non-English locales; Dutch `rearGuard`
  = "Hekkensluiter".

### 5. Testing

- **Migration:** v102 -> v103 creates and seeds `dive_roles`, adds
  `dives.diver_role`; existing `dive_buddies.role` strings resolve against
  seeds.
- **Repositories:** `DiveRoleRepository` CRUD, delete-blocked-when-used guard,
  re-seed guard; `buddy_repository` resolves known slugs and surfaces unknown
  slugs as synthetic roles (no more silent Buddy coercion).
- **Sync:** serializer round-trips custom roles, skips built-ins, tombstones
  custom-role deletion.
- **Widgets:** picker lists custom roles and the add-custom flow; Me chip
  set/clear round-trips through save; management page add/rename/delete-guard.
- **Export:** UDDF bucket mapping for custom roles and new built-ins.

## Out of scope

- Statistics/filtering by role (no changes to `DiveFilterSql` or stats).
- Changing the `BuddyRoles` credentials model.
- Retroactive normalization of any legacy free-text `dives.buddy` column.
