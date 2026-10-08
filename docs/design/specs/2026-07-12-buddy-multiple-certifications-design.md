# Buddy Multiple Certifications (Unified Certification Ownership)

- **Issue:** [#553](https://github.com/submersion-app/submersion/issues/553) - Ability to add multiple certifications to buddies or to myself
- **Date:** 2026-07-12
- **Status:** Approved

## Problem

A CMAS diver reports that a certification really has two parts: a *main* level
(1★D / 2★D / 3★D Diver) plus *extra* specialty certs (Nitrox, Advanced Nitrox,
Extended Range, Compressor Operator). A single certification value cannot hold
this.

The app is currently **asymmetric**:

- The **self-diver** already has a full multi-certification system - the
  `certifications` feature: a `Certifications` table (many rows per diver), a
  `Certification` entity with card number, issue/expiry dates, instructor link,
  front/back card photos, linked course, notes, and a routed UI at
  `/certifications` (list, detail, edit, e-card wallet). A CMAS diver can
  already record `2★ Diver`, `Nitrox`, and `Extended Range` as separate cert
  records here.
- A **buddy** carries only a single inline certification - two columns
  (`certificationLevel`, `certificationAgency`) on the `Buddies` table. No
  dates, no card, no second cert.

So the concrete gap in #553 is that **buddies max out at one certification**.

## Goals

- A buddy can hold **multiple** certifications, each with the same richness the
  self-diver's certs already support (agency, level, card number, dates,
  instructor, card photos, notes).
- Buddy and self-diver certifications share **one model, one repository, one
  editor** (no parallel cert concept).
- Compact buddy displays (chip, picker, list column, detail header) show a
  single **primary** certification, derived as the **highest by ladder**.
- No data loss for existing buddy certs; the existing self-diver cert
  experience is unchanged.
- Sync-correct: buddy-owned certs round-trip across devices, and deleting a
  buddy does not resurrect its certs on the next sync.

## Non-Goals

- A stored/explicit "primary" flag - the primary is **derived**, not persisted.
- A separate e-card *wallet route* for buddies (the buddy detail page shows a
  cert list; the swipeable wallet stays a self-diver feature).
- Cross-agency rank *normalization* (comparing a CMAS 2★ against a PADI Rescue
  precisely). "Highest ladder index wins, specialties rank last" is the rule.
- New agency ladders or level enum values (that was #546; this reuses
  `CertificationLevelCatalog`).
- Changes to the self-diver certification UI beyond making the shared editor
  owner-aware.

## Design

### 1. Data model - generalize certification ownership

Certifications become owned by **either a diver or a buddy** (never both).

**`Certifications` table** (`lib/core/database/database.dart`, ~line 1359) gains:

```dart
TextColumn get buddyId =>
    text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)();
```

- Invariant: **exactly one of `{diverId, buddyId}` is non-null.** Enforced in
  the repository on every write (self certs set `diverId`, buddy certs set
  `buddyId`). A `CHECK ((diver_id IS NULL) <> (buddy_id IS NULL))` constraint is
  optional hardening; the repository is the source of truth.
- Note: certs *already* reference buddies via `instructorId`
  (`onDelete: setNull`). `buddyId` is a distinct **owner** reference; the two
  are independent (a buddy can own a cert whose instructor is a different
  buddy).

**`Certification` entity**
(`lib/features/certifications/domain/entities/certification.dart`) gains a
nullable `buddyId`; `copyWith`, `clearPhotos`, `props`, and
`Certification.empty()` updated accordingly.

### 2. Buddy entity - derived (not stored) primary

The `buddies` table **drops** `certificationLevel` and `certificationAgency`.

The `Buddy` entity **keeps** `certificationLevel` / `certificationAgency`
fields, but they are now **derived transient values** the repository fills at
hydration = the primary certification computed from the buddy's `Certifications`
rows. Consequences:

- The ~14 read sites (`Buddy.displayName`, `Buddy.hasCertificationInfo`,
  `buddy_field.dart` table columns, `buddy_picker`, `dense_buddy_list_tile`,
  `buddy_summary_widget`, `buddy_detail_page` header, etc.) read
  `buddy.certificationLevel` unchanged - it is simply *computed* now, not
  *stored*.
- The buddy list's cert columns keep sorting/filtering: `EntityTable` sorts
  **in-memory** (`entity_table_view.dart` `_sortedEntities()`), so a derived
  value sorts fine - no SQL column required.
- Buddy write paths (`buddy_repository.dart` insert/update,
  `buddy_merge_repository.dart`) **stop writing** the two columns.

### 3. Primary-cert derivation ("highest by ladder")

A pure function (new helper, e.g. `certificationPrimary(List<Certification>)`
in the certifications domain, reusing `CertificationLevelCatalog`):

```
rank(cert) = index of cert.level in CertificationLevelCatalog.ladderFor(cert.agency)
             or -1 if level is null or not on that agency's ladder (a specialty)
primary    = the cert with the highest rank
tie-break  = latest issueDate, then most recently updated
empty list = null (compact displays fall back to just the name)
```

- Specialties (Nitrox, Extended Range, ...) rank below any core-ladder cert,
  matching the reporter's "main level vs extras" mental model.
- Known simplification: when certs span different agencies, raw ladder indices
  are compared directly (best effort). Acceptable per Non-Goals.

### 4. Repository & providers

**`CertificationRepository`**
(`lib/features/certifications/data/repositories/certification_repository.dart`):

- Add `getCertificationsByBuddy(String buddyId)` and a batch
  `getCertificationsForBuddies(List<String> buddyIds)`.
- `createCertification` / `updateCertification` accept an owner (diverId XOR
  buddyId) and enforce the invariant.
- `deleteCertification` already tombstones via
  `_syncRepository.logDeletion(entityType: 'certifications', ...)` - unchanged.
- `watchCertificationsChanges()` is table-wide, so buddy cert edits already
  notify.

**`BuddyRepository`** hydration loads certs to fill the derived primary:
`getAllBuddies` batch-loads `WHERE buddy_id IN (...)` and groups in Dart
(**O(1) queries, no N+1**); single-buddy reads load that buddy's certs.

**Providers:**
`buddyCertificationsProvider = FutureProvider.family<List<Certification>, String>`
for the detail/edit pages, invalidating on `watchCertificationsChanges()`.

### 5. UI

**Buddy detail** (`buddy_detail_page.dart`): `_buildCertificationSection`
becomes a **list of cert rows** (agency badge + name + expiry status, reusing
the self-diver `certification_list_content` row look), each tappable to the
cert detail. The name-header subtitle keeps showing the derived primary. Empty
state when the buddy has no certs.

**Buddy edit** (`buddy_edit_page.dart`): the two dropdowns become a
**"Certifications" section** - the buddy's certs listed with edit/remove, plus
**＋ Add certification**. Add/Edit opens the shared editor in embedded mode,
owner = this buddy.

**Shared editor** (`certification_edit_page.dart`) gains an **owner parameter**:
`diver(id)` (default; existing self flow unchanged) or `buddy(id)`. For the
buddy flow it also supports a **"return a `Certification`, do not persist"**
mode (see staging below).

**Staging & commit (decision C-i):** the buddy edit form holds a working cert
list in memory; **nothing persists until Save**. On Save the form upserts the
buddy, then within one transaction: assigns `buddyId` to new certs, upserts
edited certs, and routes removed certs through the tombstoning delete. This
matches the buddy form's existing "nothing saves until Save" model and handles
brand-new buddies (no id yet) cleanly.

### 6. Sync & deletion

- **Schema:** `certifications` gains `buddy_id`; it round-trips automatically
  through the existing `Certification.toJson/fromJson` sync serializer. Add one
  edge to the FK-dependency map in `sync_service.dart`:
  `(field: 'buddyId', parent: 'buddies', nullable: true)` under
  `certifications`. The map already declares `instructorId -> buddies`, and
  ordering is backed by **deferred foreign keys**, so "buddies before certs" is
  already satisfied; this edge is for documentation/completeness.
- **`buddies` drops two columns.** The migration does not advance any buddy
  row's HLC, so upgraded peers do not re-send buddy rows - a not-yet-upgraded
  peer keeps showing its own inline cert until it upgrades. The one real
  mixed-version wrinkle: an upgraded peer may sync a buddy-owned cert row to a
  not-yet-upgraded peer whose `certifications` table has no `buddy_id` column,
  leaving a temporarily invisible orphan row there. Because migrated cert ids
  are **deterministic** (see Migration), that peer's own migration upserts the
  same id rather than duplicating, so state converges to one correct row once
  both peers upgrade. No data loss.
- **Deletion (correctness-critical):** `deleteBuddy` and `bulkDeleteBuddies`
  (`buddy_repository.dart` / `buddy_merge_repository.dart`) currently do a raw
  delete and rely on FK `ON DELETE CASCADE`. **Cascade deletes do not write
  `deletion_log` tombstones**, so cascade-deleted certs would resurrect on the
  next sync. Fix: enumerate the buddy's certs and route each through the
  tombstoning delete *before* deleting the buddy row. This mirrors the existing
  parent/child tombstone pattern used elsewhere in the repo.

### 7. UDDF export / import

- **Export** (`uddf_full_export_service.dart`, ~line 194): iterate the buddy's
  cert rows and emit multiple `<certification>` elements instead of one from
  the (now removed) inline fields.
- **Import** (`uddf_import_parsers.dart`, `uddf_entity_importer.dart`): create
  buddy-owned `Certifications` rows; on full-backup restore, preserve ids (the
  dive-roles restore pattern).

### 8. Migration

New migration at the next available version in the ladder (**≥ v103**; assign at
implementation time to avoid the parallel-branch collision this repo has hit),
plus a matching `beforeOpen` re-assert (self-healing schema pattern):

1. `ALTER TABLE certifications ADD COLUMN buddy_id TEXT REFERENCES buddies(id) ON DELETE CASCADE`.
2. For every buddy with a non-null level **or** agency, **upsert** one
   buddy-owned `Certifications` row:
   - **The id is deterministic, derived from the buddy id** (a stable
     namespaced hash of `buddyId`), never a fresh random UUID. This is
     correctness-critical: the migration runs independently on each device, so
     random ids would produce two rows for the same logical cert that both
     survive sync as a **duplicate**. A deterministic id makes every device
     converge on one row.
   - `agency` = buddy agency, or `CertificationAgency.other` when null (the
     `Certifications.agency` column is non-null).
   - `level` = buddy level (may be null).
   - `name` = level's `displayName` if present, else the agency's `displayName`
     (the `name` column is non-null).
   - HLC stamped; timestamps = migration time.
   - **Upsert**, not plain insert, so that if the row already arrived via sync
     from an already-upgraded peer, its `buddy_id` is set rather than
     conflicting on the primary key.
3. `ALTER TABLE buddies DROP COLUMN certification_level` and
   `DROP COLUMN certification_agency` (SQLite bundled via
   `sqlite3_flutter_libs` supports `DROP COLUMN`).

## Compatibility

- **Level/agency storage** is unchanged enum-name text; existing self-diver
  certs are untouched.
- **Older app versions** reading a cert row with `buddy_id` set: the column is
  ignored by their schema; their self-cert queries filter by `diver_id`, so a
  buddy-owned cert simply does not appear as a self cert. Safe.
- **PDF templates / detail pages / list items** render via `displayName` /
  derived primary; no format changes.

## Testing (TDD)

**Unit** (`test/features/certifications/...`,
`test/features/buddies/...`):

- `certificationPrimary`: ladder rank ordering; specialties rank last; empty
  list -> null; tie-break by issueDate then updatedAt; cross-agency best-effort.
- Migration: a buddy with an inline cert yields exactly one buddy-owned cert
  row; derived primary equals the original inline value; columns dropped.
- Repository: buddy-owned create/read/delete; XOR-owner invariant rejected when
  violated; batch hydration issues O(1) queries (no N+1).

**Widget:**

- Buddy edit "Certifications" section: add, edit, remove; nothing persists
  until Save; Save commits certs with `buddyId` and tombstones removals.
- Buddy detail cert list and empty state.
- Respect repo widget-test traps: `themeAnimationDuration: zero`, wrap
  post-pump drift awaits in `tester.runAsync`, `ensureVisible` before tapping
  form fields, uppercased form-section labels.

**Sync:**

- A buddy-owned cert round-trips across two DBs.
- **Independent migration convergence:** two DBs each migrate the same buddy's
  inline cert, then sync -> exactly **one** buddy-owned cert row (deterministic
  id), not a duplicate.
- Deleting a buddy tombstones its certs -> no resurrection after a subsequent
  merge.
- Existing sync contract tests (`sync_base_streaming_parity_test`,
  `sync_builtin_reference_data_test`) still pass (certifications is already a
  registered HLC entity; only a column is added).

## Implementation Notes

- Work in a dedicated worktree (e.g. `worktree-issue-553-buddy-certs`); run
  `git submodule update --init --recursive` and `flutter pub get`, then
  `dart run build_runner build --delete-conflicting-outputs` after the schema
  change.
- New l10n strings (e.g. "Certifications", "Add certification") go into all 10
  non-en locales + regenerate.
- `dart format .` before committing.
