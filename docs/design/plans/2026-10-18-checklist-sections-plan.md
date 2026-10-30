# Checklist sections — implementation plan

Date: 2026-10-18
Status: draft, not yet stress-tested
Issue: #3360
Spec: [docs/design/specs/2026-10-14-checklist-sections-design.md](../specs/2026-10-14-checklist-sections-design.md)
Branch: `github-issue-3360-checklist-sections`

> Note (merges with upstream/main): upstream shipped its own v292
> (`shared_libraries.removals_json`, #3481) through v296 (media color
> correction, #3520) while this branch was in progress. The four rungs
> numbered v292-v295 below are v297-v300 in the implementation, and the
> floor ends at 300. The plan's shape and reasoning are otherwise
> unchanged.

Single PR, full scope: all four table groups (trip checklists, checklist
templates, pre-dive templates, pre-dive sessions), schema, backfill, sync
registration, and UI.

## Current state (as of this branch, schema v291)

- `TripChecklistItems.category`: `lib/core/database/tables/trip_tables.dart:307`
- `ChecklistTemplateItems.category`: `lib/core/database/tables/trip_tables.dart:283`
- `PreDiveChecklistTemplateItems.section`: `lib/core/database/tables/pre_dive_tables.dart:54`
- `PreDiveSessionItems.section`: `lib/core/database/tables/pre_dive_tables.dart:156`
- Grouping/case-folding to replicate exactly during backfill:
  `lib/features/checklists/presentation/widgets/trip_checklist_section.dart:197-264`
  (`_buildGroupedItems`, `_distinctCategories`) — key = `category.toLowerCase()`,
  label = first-seen original casing, unlabelled items sorted last via
  `LinkedHashMap` insertion order.
- Migration ladder: `lib/core/database/migrations/ladder/rungs_v231_onward.dart`,
  `currentSchemaVersion = 291` (`lib/core/database/database.dart:277`). Next
  free version: **292**.
- Precedent for a new child table + FK column in one rung:
  `_assertTripCylindersSchema` in
  `lib/core/database/migrations/helpers/trip_migrations.dart:67-92`, called
  from the ladder (`rungs_v231_onward.dart:20-25`) and from
  `lib/core/database/migrations/before_open_table_backstops.dart:24`.
- `sourceItemId`/`equipmentId` on `PreDiveChecklistTemplateItems` are
  deliberately not SQL FKs (`pre_dive_tables.dart:76-90`) because item
  tables are seeded independently in test fixtures. `section_id` on the
  three managed tables (trip checklist, checklist template, pre-dive
  template) does not have that constraint — sections and items are always
  created together in production and in tests — so those three get a real
  SQL FK. `pre_dive_session_items.section_id` follows the session items'
  existing `sourceItemId` style instead (no SQL FK; see Phase 4) since
  session rows already sync as independent HLC records.

## Migration safety and cross-version sync compatibility

This replaces a synced text column with a referenced row — a breaking
schema change, not an additive one. The project has already done this twice
and documented both the mechanism and the risks; this plan follows that
precedent rather than inventing a new one. Researched before writing this
section (not assumed):

- `AppDatabase.onUpgrade` is **not** wrapped in one SQLite transaction
  (confirmed against Drift's `db_base.dart`/`engines.dart`: `beforeOpen`
  runs the whole ladder, and `PRAGMA user_version` is only stamped *after*
  it completes — `database.dart:277` vs. the `setSchemaVersion` call that
  follows all rungs). A crash mid-ladder leaves already-executed DDL/DML
  committed but `user_version` unchanged, so the **entire** ladder reruns
  from `from` on next start, including rungs that already fully succeeded.
  Every rung in this plan must therefore be idempotent on rerun (PRAGMA
  `table_info`/`sqlite_master` guards before ADD/DROP COLUMN, deterministic
  ids with `INSERT ... ON CONFLICT DO NOTHING`/`DO UPDATE` instead of plain
  `INSERT`), exactly the pattern already used throughout
  `lib/core/database/migrations/helpers/`.
- There is a direct precedent for string-column-becomes-referenced-row:
  `buddies.certification_level/_agency` → `certifications` rows
  (`buddy_migrations.dart:71-99`, v109; safety-net re-copy + drop in
  `rungs_v096_to_v148.dart:325-356`, v110;
  `docs/design/specs/2026-08-08-buddy-professional-roles-fold-design.md`).
  That migration splits add+backfill from drop across two versions because
  of a **specific historical incident**: a branch/merge collision had
  already advanced some installs' `user_version` to 109 without the v109
  copy step ever running, so v110 had to re-run the copy as a genuine
  safety net against a bug that had already shipped. That rationale does
  not transfer to a migration written from scratch for a single PR/single
  release (confirmed with the user: this ships as one PR, "die scharfe
  Pull-Request-Variante" — no real time gap between an "add+backfill"
  release and a "drop" release, so splitting them would only add rungs and
  test files without adding safety). This plan therefore does **not** split
  into two stages; each table group gets exactly **one** rung that creates
  the section table, adds `section_id`, backfills, drops the old column,
  and raises the compatibility floor — all idempotent internally, because
  the real risk (a crash mid-ladder, see point above) is unaffected by
  whether that work sits in one rung or two: either way, a rerun replays
  every already-executed statement.
  - **v292-295**: one rung per table group (trip checklist, checklist
    template, pre-dive template, pre-dive session) — create section table,
    add `section_id`, backfill, drop `category`/`section`, raise
    `minimumCompatibleSchemaVersion` to the rung's own version.
  - **Deterministic section ids during backfill**: follow the project's
    existing hash-digest convention
    (`condition_input_fingerprint.dart:119-126`, `_digest()` — SHA-1 over a
    canonical string, truncated to 12 chars) rather than inventing a new
    one: `'section-${sha1(utf8.encode('$parentId|${title.toLowerCase()}')).toString().substring(0, 12)}'`.
    SHA-1 (not SHA-256) matches the codebase's own precedent for this exact
    purpose — a stable, order-independent, collision-resistant-enough id
    that two independent runs of the same backfill agree on, never a
    cryptographic guarantee. So that if the ladder reruns after a crash
    (point above) the backfill produces the same rows, not duplicates.
    Sections created afterwards through the UI still get random uuids,
    matching how `buddycert-<buddyId>` ids are deterministic only for the
    migration-born rows, not for rows created through normal app use.
  - **Idempotent backfill query shape**: `INSERT INTO ..._sections (id, ...)
    SELECT DISTINCT <deterministic id>, ... FROM ..._items WHERE category IS
    NOT NULL AND category != '' ... ON CONFLICT(id) DO NOTHING`, then
    `UPDATE ..._items SET section_id = <matching deterministic id> WHERE
    section_id IS NULL AND category IS NOT NULL AND category != ''`,
    **before** the `ALTER TABLE ... DROP COLUMN category` statement in the
    same rung. The `section_id IS NULL` guard on the UPDATE is what makes a
    partial rerun safe — already-pointed items are left alone, and since
    the column isn't dropped until after this guarded UPDATE, a crash
    between backfill and drop just means the drop (and the then-trivial,
    already-satisfied backfill) reruns on next start.
- **`minimumCompatibleSchemaVersion`** (`database.dart:277-380`, doc block
  with an explicit checklist of when to raise it): dropping a synced column
  is listed as a mandatory-raise case. Each v292-295 rung raises the floor
  to its own version (consistent with the project's one-bump-per-breaking-
  change history documented there). This does **not** block receiving an
  old peer's payloads — `changeset_reader.dart:254-275` only holds back
  *this* device's *outgoing* payloads from peers still below the new floor;
  an old peer's incoming payloads (still containing `category`/`section`,
  lacking `sectionId`) continue to be accepted.
- **Incoming legacy payloads must not clobber backfilled data — already
  solved by an existing, tested, general mechanism; verified by reading,
  not left as an assumption.** Unlike the `serviceType`→`serviceCategory`
  rename (`lib/core/services/sync/legacy_wire_keys.dart`, a same-type field
  rename handled by rewriting the wire key before decode),
  `category`→`section_id` is not a rename: the value changes shape (free
  text → a row reference), so `legacy_wire_keys.dart` is the wrong tool
  here. The actual safety net is the "#474 overlay" documented and tested
  in `test/core/services/sync/cross_version_roundtrip_test.dart:1-11`:
  "a peer on an older schema republishes rows WITHOUT the columns its build
  does not know ... the #474 overlay refills omitted keys from the local
  row." Its test `'old-peer edit applies AND the post-137 column
  survives'` (lines 150-180) proves exactly our scenario one column-drop
  earlier: an old peer's payload missing a newer column, merged with a
  legitimately-newer HLC (so the edit *should* win), still leaves the
  newer column's locally-held value untouched — the overlay refills it
  from the local row before the merge runs, so an absent key is never
  treated as an explicit null.
  This is a general mechanism, not something built per-column, so
  `category`→`section_id` gets it automatically once the column is
  dropped and the floor is raised. The file's own header is explicit about
  the remaining work: *"when a migration raises the floor, extend
  `postV137DiveKeys` and add the analogous projection for the new
  boundary"* — i.e. add a `postV29{1,2,3,4}...Keys` list (one per table
  whose floor-raising rung drops a column) and the matching test group,
  the same shape as the existing `v137`/`v160`/`v210`/`v240`/`v275` groups
  in that file. This is a mechanical extension of a proven pattern, not an
  open risk — downgrade accordingly from "must verify, might require a
  merge fix" to "extend the existing test file per its own documented
  convention," as part of Phase 5.
- **Resilience tests**, modeled directly on two existing precedents rather
  than written from scratch:
  - `test/core/database/migration_v183_rung_resilience_test.dart` — use its
    `TRIGGER ... RAISE(ABORT, ...)` technique to simulate a crash *within*
    one of our rungs, between the backfill UPDATE and the `DROP COLUMN`
    statement, asserting items keep their `category`/`section_id` data and
    the old column survives if the rung didn't finish.
  - `test/core/database/migration_v110_drop_buddy_cert_columns_test.dart` —
    use its "device reached the target `user_version` without the backfill
    step ever having run" scenario (the ladder-rerun risk from the first
    bullet above — relevant here even without a two-stage split, because
    *any* rung can be interrupted and rerun) and assert the idempotent
    backfill still recovers the data on rerun, before the drop proceeds.
- **Process-kill / OS-kill during migration** is already covered by the
  existing `pre_migration_backup_service.dart` + `startup_page.dart`
  pre-migration safety-copy flow — no new backup mechanism needed here,
  only confirming (in a resilience test, not just by reading the code) that
  these new rungs run through the normal foreground startup migration path
  and not inside a background isolate (`database_version_exception.dart`
  explains why the latter would be unsafe).

## Phase 1 — Schema, backfill, and column drop (one rung per table group)

One rung per table group, `from < N` guarded, mirroring
`_assertTripCylindersSchema` for the schema part. Each rung, in order:
creates the section table + its index; adds the nullable `section_id`
column via `_addColumnIfMissing`; backfills (idempotent, deterministic ids
— see migration-safety section); drops the old `category`/`section`
column; raises `minimumCompatibleSchemaVersion` to the rung's own version.
No separate "stage B" — this ships as one PR/one release, so splitting
add+backfill from drop across versions would only add rungs and test files
without adding real safety (see migration-safety section for why the
historical two-stage precedent doesn't transfer here).

- **v292** `trip_checklist_sections` + `trip_checklist_items.section_id`
  (FK `trip_checklist_sections.id`, `ON DELETE SET NULL`), backfill, drop
  `category`.
- **v293** `checklist_template_sections` + `checklist_template_items.section_id`,
  backfill, drop `category`.
- **v294** `pre_dive_checklist_template_sections` +
  `pre_dive_checklist_template_items.section_id`, backfill (including the
  built-in-template seed rewrite, Phase 2 below), drop `section`.
- **v295** `pre_dive_session_sections` (`ON DELETE CASCADE` from
  `pre_dive_sessions.id`, matching `pre_dive_session_items.session_id`) +
  `pre_dive_session_items.section_id` (nullable column, no SQL FK — see
  rationale above), backfill across all session statuses, drop `section`.
  Confirmed as a real table, not denormalized columns: consistent with the
  project's "one dedicated table per parent" schema style, and keeps the
  door open for any future per-section behaviour on sessions (a note, a
  cross-session rollup) without a second migration of this same shape. The
  extra sync-registration cost (Phase 5) is mechanical and covered by the
  project's own structural pinning tests, not a source of risk.

New file: `lib/core/database/migrations/helpers/checklist_section_migrations.dart`
with one `_assertAndBackfill<X>Sections()` function per table group (four
functions), each internally idempotent (PRAGMA guards, deterministic
backfill ids with `ON CONFLICT DO NOTHING`, `WHERE section_id IS NULL` guard
on the item UPDATE, column-exists guard before the DROP — see
migration-safety section). Register all four calls' schema-assertion part
(table/column creation, not the drop) in `before_open_table_backstops.dart`
too, matching `_assertTripCylindersSchema`'s re-assertion pattern.

Tests first (TDD): one `test/core/database/migration_v29{2,3,4,5}_<name>_test.dart`
per rung, following `migration_v232_trip_cylinders_test.dart`'s structure —
build a pre-migration fixture DB, open it with `AppDatabase`, assert the new
table exists, the FK/index are in place, the old column is gone, and that
backfill produced the right section rows with deterministic ids. Also add
the resilience cases from the migration-safety section (crash simulation
between backfill and drop within the same rung, rerun-without-having-
backfilled simulation) to the same test file.

## Phase 2 — Backfill logic and built-in template seeds

Backfill query shape (per table group, scoped to its own parent — trip,
template, or session; a case-insensitive match in one trip must never merge
into a section visible in another trip):

1. Group existing items by `category`/`section`, case-folded exactly like
   `_buildGroupedItems`/`_distinctCategories`
   (`trip_checklist_section.dart:197-264`): lowercase key, first-seen
   original casing as `title`, insertion order as `sort_order`.
2. Insert one section row per distinct non-null/non-empty value, with a
   **deterministic id** derived from parent id + lowercased title (see
   migration-safety section), `ON CONFLICT(id) DO NOTHING`.
3. Update every item's `section_id` via `WHERE section_id IS NULL AND
   category IS NOT NULL AND category != ''`, matching on the same
   deterministic id derivation. Items with null/empty value keep
   `section_id = null`.

For `pre_dive_checklist_template_items`, additionally rewrite
`kSeedBuiltInPreDiveTemplatesSql`/`kSeedBuiltInPreDiveTemplateItemsSql`
(`lib/core/database/tables/pre_dive_tables.dart:220-334`) to insert stable
section ids first (e.g. `builtin-predive-ccr-build-assembly`) and have item
rows reference them instead of inlining `'Assembly'` etc. Verify
`kRenumberCcrTailItemsSql`/`kRetireLegacyGueEdgeItemsSql`
(`pre_dive_tables.dart:366-384`) don't need equivalent updates (they touch
item ordering/retirement, not section text, but confirm no section string
literal is embedded there too).

Test per rung (same migration test file as Phase 1): shared category across
items merges into one section case-insensitively; distinct casings merge
with first-seen casing kept; empty/null stays unsectioned; a built-in
pre-dive template ends up with the same section structure as before, now
referenced; both a completed and an in-progress/aborted session backfill
correctly (explicitly test session status variants, since the spec flags
this as touching otherwise-immutable audit rows); rerunning the backfill
function a second time against already-migrated rows is a no-op (idempotency
test, directly motivated by the non-atomic-ladder finding above).

## Phase 3 — Domain entities + repositories

New entities (own files, per repo's many-small-files convention), each with
`id`, parent id, `title`, `sortOrder`, `createdAt`/`updatedAt`, `hlc`,
`copyWith` using the existing sentinel pattern
(`trip_checklist_item.dart:91` style):

- `lib/features/checklists/domain/entities/trip_checklist_section.dart` → `TripChecklistSection`
- `lib/features/checklists/domain/entities/checklist_template_section.dart` → `ChecklistTemplateSection`
- `lib/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart` → `PreDiveChecklistTemplateSection`
- `lib/features/pre_dive/domain/entities/pre_dive_session_section.dart` → `PreDiveSessionSection`

Existing item entities (`trip_checklist_item.dart`, `checklist_template.dart`
→ `ChecklistTemplateItem`, `pre_dive_checklist_template.dart` →
`PreDiveChecklistTemplateItem`, `pre_dive_session.dart` →
`PreDiveSessionItem`) lose `category`/`section` and gain `sectionId` (same
sentinel `copyWith` pattern already used for the field being replaced).

Repository changes:

- `TripChecklistRepository` (`trip_checklist_repository.dart`): add
  `createSection`, `renameSection`, `reorderSections`, `deleteSection`
  (sets `section_id = null` on its items, does not delete them); update
  `createItem`/`updateItem` to take `sectionId` instead of `category`.
- `ChecklistTemplateRepository` (`checklist_template_repository.dart`): same
  four section methods; `saveItems` (bulk replace, line 186+) updated for
  `sectionId`.
- `PreDiveTemplateRepository` (`pre_dive_template_repository.dart`): same
  four section methods; `saveItems` (207-286) and `cloneTemplate` (287-331)
  updated — cloning a template must remap section ids the same way
  `sourceItemId` is remapped today (new section ids minted, items
  re-pointed), not share the original template's section rows.
- `PreDiveSessionRepository` (`pre_dive_session_repository.dart`): **no**
  section management methods (read-only per spec); `startSession` (38-131)
  delegates section-row creation to `SessionItemComposer` (Phase 4below);
  `getItemsForSession`/`getSessionStats` read `sectionId` instead of
  `section` where they group/display.

TDD: entity `copyWith`/equality tests extend
`checklist_entities_test.dart`/`pre_dive_entities_test.dart`. Repository
tests extend `trip_checklist_repository_test.dart`,
`checklist_template_repository_test.dart`,
`pre_dive_template_repository_test.dart`,
`pre_dive_session_repository_test.dart` (+ their `_error_test.dart`
counterparts) with section CRUD, cascade-on-parent-delete, set-null-on-
section-delete, and clone-remaps-sections cases.

## Phase 4 — Pre-dive session composer

`lib/features/pre_dive/domain/services/session_item_composer.dart`:

- `compose()` (28-156) gains a `templateSections` parameter alongside
  `templateItems`.
- New `sessionIdByTemplateSectionId` map, minted up front exactly like
  `sessionIdByTemplateId` (53-55): `{for (final s in templateSections) s.id: _uuid.v4()}`.
- Emit one `PreDiveSessionSection` row per template section (copying
  `title`/`sortOrder`, new id, new `sessionId`).
- Each of the three `section:`-assignment sites (69, 90, 135) becomes
  `sectionId: t.sectionId == null ? null : sessionIdByTemplateSectionId[t.sectionId]`.
- `PreDiveSessionRepository.startSession` (38-131) persists the new session
  section rows in the same transaction as session items.

TDD: extend `checklist_session_engine_test.dart` with cases — a template
with sections produces matching session sections with remapped ids; an
unsectioned template item stays `sectionId: null`; the equipment-set branch
(multiple session items per gear, line 90) all point at the same remapped
section.

## Phase 5 — Sync registration

Four tables × the full touch-point list, each modelled directly on
`tripCylinders`'s existing entries (confirmed pattern, not `tripCylinderEvents`,
since every new table here is `updatedAt`-clocked like `tripCylinders`, not
ledger-style):

1. `lib/core/data/repositories/sync_repository.dart` — `hlcTargets`
   (45-186): add `tripChecklistSections`, `checklistTemplateSections`,
   `preDiveChecklistTemplateSections`, `preDiveSessionSections`.
2. `lib/core/services/sync/sync_data_serializer.dart`:
   - `SyncData` fields (304-312) + constructor defaults (435-443).
   - `toJson`/`fromJson` (556-564 / 684-694).
   - `_baseTables` (1085-1146) — `preDiveChecklistTemplateSections` needs the
     built-in-exclusion pattern already used for
     `preDiveChecklistTemplates`/`preDiveChecklistTemplateItems`
     (1118-1134): `table: null, full: () => _export...(null)`.
   - `_buildSyncData` export calls (2328-2361).
   - Case-switch pairs at 3134-3141, 3709-3716 (record ids / changeset
     routing), 4947-4958 (`upsertRecord`), 6056-6071 (`upsertRecords`),
     7129-7132 (`fetchRecord`/`fetchRecords`), 7614-7617 (`_syncTableFor`),
     8062-8069 (`deleteRecord` or equivalent — confirm exact method at
     implementation time).
   - Built-in filtering on delete/clear, mirroring 7427-7441, for
     `preDiveChecklistTemplateSections`.
   - New `_exportTripChecklistSections` etc. (mirroring 9112-9131 for the
     three unfiltered tables, mirroring the ~9170-9212 filtered style for
     the pre-dive template one).
3. `lib/core/services/sync/sync_service.dart`:
   - `mergeOrder` (1419-1496) — insert each new section entry **before**
     its item table, after its own parent: order becomes `checklistTemplates
     → checklistTemplateSections → checklistTemplateItems →
     tripChecklistSections → tripChecklistItems → preDiveChecklistTemplates →
     preDiveChecklistTemplateSections → preDiveChecklistTemplateItems →
     preDiveSessions → preDiveSessionSections → preDiveSessionItems`.
   - `entityHasUpdatedAt` (2671-2709+): add all four as `true`.
   - `parentRefs` (3225-3257): add the four section tables
     (`tripId`/`templateId`/`sessionId` parent, not nullable) and update the
     four item tables' existing entries to add `(field: 'sectionId', parent:
     '<itsSectionsKey>', nullable: true)`.
4. `lib/core/services/sync/conflict_reference.dart`: add `sectionId` to
   `_targetOverrides` (147-157) per owning item table — four separate
   overrides, since `sectionId` points at a different sections table per
   item table, the same reasoning already applied to `templateId`
   (153-156). New section tables' own `name`/`title` field is picked up
   automatically by `_nameFields` (163-176) if named `title`; confirm
   against the existing field list rather than assuming.

Structural/pinning tests catch missing entries by design
(`sync_hlc_target_registration_test.dart`,
`sync_parent_refs_completeness_test.dart`,
`sync_data_serializer_record_ids_test.dart`) — run these early and often
during this phase rather than only at the end; they are the actual
specification of "did I register everything."

Also extend: `checklist_sync_round_trip_test.dart`,
`sync_data_serializer_checklist_test.dart`, `sync_pre_dive_test.dart`,
`sync_pre_dive_serializer_records_test.dart` with section create/rename/
delete-sets-null round-trips, and a built-in pre-dive section exclusion
case.

## Phase 6 — UI

**Item editor** (`checklist_item_edit_sheet.dart`): replace the
`RawAutocomplete<String>` bound to `_categoryController` (155-179) with a
section picker: a dropdown/list of the parent's existing
`TripChecklistSection`/etc. rows plus an inline "new section" entry. On
submit, resolve to a `sectionId` (creating a new section row via the
repository if "new section" was chosen) instead of writing free text.
`_canonicalCategory()` (85-95) and `categorySuggestions` plumbing are
removed; callers (`trip_checklist_section.dart:62,243`,
`_distinctCategories`) switch from deriving suggestions out of item text to
reading the parent's actual section list.

**Section rendering** (`trip_checklist_section.dart` and its checklist
template / pre-dive template counterparts): replace
`_buildGroupedItems`/`_distinctCategories` text-grouping with a direct query
against the sections table (ordered by `sort_order`), joining items by
`sectionId`; unsectioned items render in a trailing group exactly as today.

**Section management** (trip checklists, checklist templates, pre-dive
templates only — not sessions): new UI for create-empty-section, rename,
reorder, delete-with-fallback-confirmation ("items will be moved to
'No section', not deleted"). Exact affordance (inline vs. a dedicated
sections-management view) is **not fixed by this plan** — the spec
explicitly deferred this, and it is a reasonable design decision to make
once the data layer exists; propose a concrete UI in a short follow-up
design note under `docs/design/specs/` once Phases 1-5 are in place, rather
than guessing it now.

Per `CLAUDE.md`: this touches
`lib/features/checklists/presentation/` /
`lib/features/pre_dive/presentation/` → PR description needs before/after
screenshots (light + dark, phone + desktop) once the UI design above is
finalized.

Widget tests (new/extended): section picker (existing sections, inline
create), empty-section rendering, rename/reorder, delete-with-fallback — per
the spec's testing section.

## Phase 7 — Cleanup and cross-cutting checks

- `dart format .` after every phase, not just at the end.
- Re-run `scripts/check_docs_links.py` mentally: this plan and the spec stay
  under `docs/design/plans/` and `docs/design/specs/` respectively, no
  `docs/plans/`/`docs/superpowers/` paths introduced.
- Hardening checklist pass (per user's global instructions): confirm the
  backfill queries handle empty item lists (a trip/template/session with
  zero items), confirm no `.first`/`.last` access on a possibly-empty
  grouped-items collection in the new UI code, confirm nullable `sectionId`
  is handled consistently (never force-unwrapped) in composer and
  repository code.
- `migration_ladder_completeness`-style tests (if present — check for a test
  asserting every version number from 1..currentSchemaVersion has a rung)
  must stay green for v292-295.

## Open questions carried over from the spec (still not resolved here)

- Exact section-management UI affordance (Phase 6 note).
- Whether `strictOrder` should extend to the section level — out of scope,
  not touched by this plan.

## Suggested commit sequence (one PR, staged commits)

**Revised after starting implementation**: Drift generates its
`Companion`/`Row` classes directly from the table definition, so a schema
change to `category`→`section_id` breaks compilation of the repository
(and any widget) that still constructs the old Companion field — not just
the migration SQL. Schema and the entity/repository layer are not cleanly
separable *per table group*, even though they are separable *across* table
groups. The commit boundary that actually compiles and tests cleanly on
its own is therefore **one commit per table group, end to end** (schema +
migration + domain entity + repository + the widgets that read/write the
field + their tests), not "schema for all four, then entities for all
four":

1. **Trip checklist** — schema/migration (v292) + `TripChecklistSection`
   entity + `TripChecklistItem.sectionId` + `TripChecklistRepository`
   section methods + `checklist_item_edit_sheet.dart`/
   `trip_checklist_section.dart` + all their tests.
2. **Checklist templates** — same shape, v293.
3. **Pre-dive templates** — same shape, v294, including the built-in seed
   rewrite (Phase 2) and `cloneTemplate`'s section remapping.
4. **Pre-dive sessions** — schema/migration (v295) + `PreDiveSessionSection`
   + the session composer's `sessionIdByTemplateSectionId` remapping
   (Phase 4) + `PreDiveSessionRepository` read paths + tests. No management
   UI commit needed here (read-only per spec).
5. Sync registration for all four new tables + sync tests, **including**
   the cross-version payload test from the migration-safety section (old
   peer's `category`-only payload must not null out a locally-backfilled
   `section_id`) — done once, after all four tables exist, since the sync
   touch points (Phase 5) are structured as one pass across every
   registered table anyway (`hlcTargets`, `mergeOrder`, `parentRefs`, …).
6. Section-management UI (create empty, rename, reorder, delete-with-
   fallback) for trip checklists, checklist templates and pre-dive
   templates (Phase 6) — kept separate from commits 1-3 because the exact
   affordance is an open design question (per the cross-examination),
   resolved once the data layer from commits 1-4 exists to build against.
7. Format, hardening pass, full local analyze (Phase 7).

Each commit should leave `flutter analyze` clean; tests run upstream/CI per
this project's "no local `flutter test`" convention — rely on the migration
and sync pinning tests' structure to self-check completeness before pushing.
