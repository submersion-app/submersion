# Deeper Buddy/Instructor Integration — Design

**Issue:** [#395](https://github.com/submersion-app/submersion/issues/395)
**Date:** 2026-07-02
**Status:** Approved

## Problem

Tracking training dives and certifications requires manually re-entering
instructor information every time. Buddies cannot carry professional
credentials (instructor number, agency), and certifications have no
structured link to a buddy — only free-text `instructorName` /
`instructorNumber` fields. Courses already solve half of this
(`courses.instructorId` FK plus text fallback); certifications and the
buddy model itself have not caught up.

## Goals

- A buddy can hold professional roles (instructor, divemaster, dive
  guide), each with its own credential number and agency.
- When logging a certification (or course), the user picks a preexisting
  buddy as instructor and the instructor fields autofill.
- Certifications remain historically accurate documents: picked
  instructor data is snapshotted into the existing text fields, which
  stay independently editable (certifying instructor may differ from the
  dive instructor).
- Training dives surface credentials: the dive buddy picker shows a
  buddy's professional credentials and pre-selects the instructor role
  for credentialed buddies.

## Non-Goals

- No changes to the `dive_buddies` schema — the `role` column and
  `BuddyRole.instructor` already cover buddy-as-instructor on dives.
- No migration of existing free-text instructor names into buddy
  records (no retroactive matching/backfill).
- No removal of manual text entry anywhere; it keeps working as today.

## Data Model (schema v99)

### New table: `buddy_roles`

Professional credentials held by a buddy.

| Column              | Type | Notes                                        |
| ------------------- | ---- | -------------------------------------------- |
| `id`                | TEXT | PK (uuid)                                    |
| `buddy_id`          | TEXT | FK → `buddies(id)`, `ON DELETE CASCADE`      |
| `role`              | TEXT | Stores existing `BuddyRole` enum `.name`     |
| `credential_number` | TEXT | nullable — e.g. instructor number            |
| `agency`            | TEXT | nullable — e.g. PADI, SSI                    |
| `notes`             | TEXT | default `''`                                 |
| `created_at`        | INT  |                                              |
| `updated_at`        | INT  |                                              |
| `hlc`               | TEXT | nullable — registered in `_hlcTables`        |

Design decisions:

- **Reuse the `BuddyRole` enum** (`lib/core/constants/enums.dart`)
  rather than introducing a parallel enum. The UI offers only the
  professional subset: `instructor`, `diveMaster`, `diveGuide`. A
  credential's `role` compares directly against a `dive_buddies.role`
  value with no mapping layer.
- **Single-column `id` PK + `hlc`**, not a composite (buddy_id, role)
  key: the sync merge layer resolves conflicts per-row via HLC, and
  composite-key junctions have previously lost rows during merge
  (issue #347). The repository enforces logical uniqueness by upserting
  on (buddy_id, role).
- **Cascade delete**: a credential is meaningless without its buddy.

### Modified table: `certifications`

Add `instructor_id TEXT` (nullable), referencing `buddies(id)` with
set-null-on-delete semantics — mirroring `courses.instructorId`
(`database.dart:1534`). Existing `instructor_name` / `instructor_number`
text columns are unchanged and carry the snapshot.

### Migration v99

- PRAGMA-guarded `ALTER TABLE certifications ADD COLUMN instructor_id`
  (idempotent, v87/v90/v91 pattern).
- `m.createTable(buddyRoles)` (v92 pattern).
- Bump `currentSchemaVersion` to 99; append `99` to `migrationVersions`.
- Test: `test/core/database/migration_v99_buddy_roles_test.dart`.

## Sync

- `certifications.instructor_id` flows automatically — serialization
  uses drift-generated `toJson`/`fromJson`, which pick up new nullable
  columns without serializer edits.
- `buddy_roles` requires full registration in
  `lib/core/services/sync/sync_data_serializer.dart` (~10 sites: the
  `SyncData` field, `_baseTables` descriptor, upsert/export/columns/
  table-lookup switches, and a dedicated `_exportBuddyRoles`), modeled
  directly on the existing `diveBuddies` sites.
- `buddy_roles` is added to `_hlcTables` in `database.dart` for
  conflict resolution.
- Older app versions ignore unknown tables/columns, same as every prior
  additive migration.

## Domain & Data Layers

- New entity `BuddyRoleCredential`
  (`lib/features/buddies/domain/entities/buddy_role_credential.dart`):
  `id`, `buddyId`, `role` (BuddyRole), `credentialNumber`, `agency`,
  `notes`, timestamps; immutable with `copyWith`.
- `BuddyRepository` gains credential CRUD:
  `getRolesForBuddy(buddyId)`, `upsertRole(credential)` (upsert keyed
  on buddy_id + role), `deleteRole(id)`. New providers:
  `buddyRolesProvider(buddyId)`, plus an
  `instructorCredentialsProvider` that maps buddyId → instructor
  credential for picker grouping/autofill.
- `Certification` entity gains `instructorId` (nullable). The
  certification repository's raw `customSelect` read-mapper adds
  `row.data['instructor_id']`; both `CertificationsCompanion` write
  paths (insert, update) add the column — following the course repo's
  existing `instructorId` wiring.
- Buddy merge repository (`buddy_merge_repository.dart`) must move
  `buddy_roles` rows and re-point `certifications.instructor_id` when
  merging duplicate buddies, deduplicating credentials on (role).

## UI

### Shared widget: `InstructorPickerField`

One picker used by both certification and course edit pages
(`lib/features/buddies/presentation/widgets/instructor_picker_field.dart`):

- Dropdown of all buddies; buddies holding an instructor credential are
  grouped first and rendered with their credential
  (`Alice — PADI #12345`). Non-credentialed buddies remain selectable
  (autofill name only). First option: `None (manual entry)`.
- On pick: emits the buddy + optional instructor credential; the host
  page sets `instructorId` and snapshots name / credential number into
  its text controllers.
- Clearing back to `None` clears `instructorId` but leaves text fields
  untouched (no destructive wipe). Later text edits do not clear the
  link.

### Buddy edit page

New "Professional Roles" section (existing FormRow section patterns):
list of credential entries, each with role dropdown
(Instructor / Divemaster / Dive Guide), agency input (same
control/choices as the buddy's existing certification-agency field),
credential-number text field, remove button; "Add role" affordance. Duplicate role selection
edits the existing entry (upsert semantics).

### Buddy detail page

Read-only "Professional Roles" card (`Instructor — PADI #12345`).
Hidden when the buddy has no credentials.

### Certification edit page

Instructor section gains the `InstructorPickerField` above the existing
name/number text fields (which remain editable). Save persists
`instructorId` alongside the text fields.

### Certification detail page

Instructor line becomes tappable when `instructorId` resolves to a
live buddy, navigating to that buddy. Falls back to plain text when the
link is null or the buddy is missing.

### Course edit page

Replace the inline dropdown (`course_edit_page.dart:214-262`) with
`InstructorPickerField`: instructor-credential-first grouping replaces
the `certificationLevel != null` heuristic, and picking now also
autofills the instructor number from the credential.

### Dive BuddyPicker

- Buddies with credentials show a subtitle
  (`Instructor — PADI #12345`).
- Adding a buddy who holds an instructor credential pre-selects the
  `instructor` role instead of the default `buddy`.
- No schema change; `dive_buddies.role` already exists.

## Error Handling & Edge Cases

- **Buddy deleted after linking**: `instructor_id` → NULL at the DB
  layer; snapshot text remains; detail pages render text-only.
- **Dangling `instructor_id` via sync** (cert arrives before its
  buddy): nullable FK avoids violations (existing 3-layer FK guard
  applies); UI resolves via `buddyByIdProvider` and falls back to text.
- **Duplicate roles**: repository upserts on (buddy_id, role); adding
  "Instructor" twice edits the existing entry.
- **Empty credential fields**: a role with no number/agency is valid;
  autofill fills only what exists.

## Testing (TDD)

- `migration_v99_buddy_roles_test.dart`: table creation, column add,
  idempotency on re-run.
- Repository tests **with foreign keys ON**: buddy_roles CRUD, upsert
  dedup, cascade on buddy delete, certification set-null on buddy
  delete (FK-OFF suites have previously masked ordering bugs).
- Sync serializer round-trip for `buddy_roles` (model: diveBuddies
  serializer tests).
- Buddy merge test: credentials move and certifications re-point.
- Widget tests: cert-edit autofill on pick, snapshot survives buddy
  edit, no-wipe on clearing picker, course-edit number autofill,
  BuddyPicker credential subtitle and instructor-role preselection,
  buddy edit add/edit/remove roles.

## Rollout / Compatibility

Purely additive. Existing certifications, courses, and buddies are
untouched; manual text entry continues to work everywhere. No backfill.
