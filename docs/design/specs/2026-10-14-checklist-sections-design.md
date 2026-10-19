# Checklist sections

Date: 2026-10-14
Status: concept, analysis only, no implementation plan written yet
Issue: #3360

## Problem

Four checklist item tables group items into visual sections through a free
`category` (`trip_checklist_items`, `checklist_template_items`) or `section`
(`pre_dive_checklist_template_items`, `pre_dive_session_items`) text column.
The header shown in the UI is derived at read time by grouping items on this
string, case-insensitively, keeping the first-seen casing as the label
(`TripChecklistSection._buildGroupedItems`, `_distinctCategories`).

Two problems follow from a section being an attribute of an item rather than
a thing of its own:

- Adding several items to the same section means retyping (or re-selecting
  from an autocomplete) that section's name once per item. Five items, five
  repeats.
- A section cannot exist without at least one item. A diver who wants to lay
  out a checklist's structure before filling it in cannot create an empty
  section to fill in later.

## Decisions

- Scope: all four tables get a real section table, not only the trip
  checklist the request started from. Deferring the pre-dive side would
  leave the identical complaint unsolved for CCR builders and buddy checks,
  the heaviest users of multi-section templates today (compare the built-in
  CCR Build template's five sections).
- Identity: one dedicated section table per parent table, items reference it
  through a nullable `section_id` foreign key. No shared cross-feature
  section table; trip checklists, checklist templates, pre-dive templates
  and pre-dive sessions stay the independent entities they are today.
- Pre-dive sessions keep their snapshot principle. `pre_dive_session_items`
  is an immutable, independent copy of the template's items taken at session
  start (`pre_dive_tables.dart:103-104`). A session item must not reference a
  *template* section, or a later template edit or deletion would alter a
  past session's shape. `pre_dive_session_sections` is therefore its own
  table, populated at session start.
- This copy is not a straight field copy like the rest of
  `SessionItemComposer.compose()` today (`section: t.section` is a plain
  string assignment, `session_item_composer.dart:69,90,135`). Converting to
  an FK needs a new id-minting pass: a `sessionIdByTemplateSectionId` map
  built once per `compose()` call, exactly mirroring the existing
  `sessionIdByTemplateId` map used for cross-item references
  (`session_item_composer.dart:53-55`, the same pattern `sourceItemId`
  remapping already relies on for issue #986). `compose()` must additionally
  receive the template's section list, not just its items. This is real,
  non-trivial work specific to the pre-dive branch, with no counterpart on
  the trip-checklist or template side, where backfill and future writes stay
  plain inserts.
- Pre-dive session sections get no management UI. `PreDiveSessionRepository`
  only ever inserts a session and its items once, at start, and otherwise
  only deletes a whole session (`pre_dive_session_repository.dart:33-79,
  498`); nothing adds, removes or reorders items once a session exists, and
  the runner page has no such action either. A session's structure is
  frozen the moment `compose()` runs. Giving `pre_dive_session_sections` a
  rename/reorder/delete UI would be new capability with no existing anchor,
  and would cut against the audit-record immutability the table comment
  states outright. Session sections stay read-only and derived, exactly
  like session items today; only trip checklist sections, checklist
  template sections and pre-dive template sections get full management
  (rename, reorder, delete-with-fallback).
- Section order becomes independent of item order. Today a section's
  display position is an accident of its first item's `sortOrder`
  (`_buildGroupedItems` iterates a `LinkedHashMap` in first-seen order,
  `trip_checklist_section.dart:208-219`), so moving an item can silently
  reorder its section. A real `sort_order` column decouples the two: once
  backfilled in first-seen order (verified against the exact grouping rule
  above, not assumed), section order becomes stable and is changed only by
  an explicit reorder action. This is a deliberate, user-visible behaviour
  change worth calling out, not a side effect to discover later.
- Pre-dive built-in templates keep their seeding model. Built-in templates
  are inserted via idempotent `INSERT OR IGNORE` SQL
  (`kSeedBuiltInPreDiveTemplateItemsSql`), re-asserted on every app start, and
  excluded from sync export. The seed SQL is rewritten to insert section rows
  with stable ids first (for example `builtin-predive-ccr-build-assembly`),
  then item rows reference those ids instead of carrying the string
  `'Assembly'` inline.
- Deletion: `section_id` is nullable with `ON DELETE SET NULL`, matching the
  existing style for nullable parent references in this schema (for example
  `pre_dive_sessions.template_id`). Deleting a section does not delete or
  hide its items; they fall back to "no section," the same place items with
  no category sit today.
- Backfill is a real, one-time data migration: for every existing
  trip/template/session, group its items by the current text value
  case-insensitively, create one section row per distinct value using the
  first-seen casing as the title, point every item at the matching section,
  then drop the old text column. Items with an empty or null value get no
  section row and keep `section_id = null`. This is the first migration of
  this shape (string column replaced by a referenced row) in the codebase;
  the closest precedent in structure, a parent/child pair with FK sync
  wiring, is `trip_cylinders`/`trip_cylinder_events` (`2026-09-25-trip-gas-
  logistics-design.md`), which has no backfill step to borrow from.
- Backfilling `pre_dive_session_items`, including completed and aborted
  sessions, touches rows the repository otherwise treats as immutable audit
  records. That is accepted here as a deliberate, one-time exception: the
  migration changes how a session's structure is represented, not what it
  records or what the diver saw during the run.

## Data model

Four new tables, one per existing item table. All four carry `hlc` (every
existing item table being extended does), so sync registration is required
in full for each; there is no shortcut from a missing `hlc` column.

`trip_checklist_sections`:

| Column | Type | Meaning |
| --- | --- | --- |
| id | text, primary key | uuid |
| trip_id | text, FK trips.id, not null | the trip; children are deleted before the trip |
| title | text, not null | section label |
| sort_order | integer, not null, default 0 | section order |
| created_at, updated_at | datetime | row timestamps |
| hlc | text, nullable | sync clock |

`trip_checklist_items.section_id`: text, nullable, FK
`trip_checklist_sections.id`, `ON DELETE SET NULL`. Replaces `category`.

`checklist_template_sections`: same shape, `template_id` FK
`checklist_templates.id` in place of `trip_id`.

`checklist_template_items.section_id`: replaces `category`, same FK style.

`pre_dive_checklist_template_sections`: same shape, `template_id` FK
`pre_dive_checklist_templates.id`.

`pre_dive_checklist_template_items.section_id`: replaces `section`, same FK
style. Built-in rows get stable ids as described above.

`pre_dive_session_sections`: same shape, `session_id` FK
`pre_dive_sessions.id`, `ON DELETE CASCADE` (matching
`pre_dive_session_items.session_id` today, since a section only ever makes
sense inside its one session).

`pre_dive_session_items.section_id`: replaces `section`, FK
`pre_dive_session_sections.id`, `ON DELETE SET NULL`.

Domain entities: `TripChecklistSection`, `ChecklistTemplateSection`,
`PreDiveChecklistTemplateSection`, `PreDiveSessionSection`, each with `id`,
parent id, `title`, `sortOrder`, timestamps, `copyWith`. `TripChecklistItem`
and its three counterparts lose their category/section string field and gain
`sectionId`.

### Sync registration

Each of the four tables is an `updatedAt`-clocked child, registered exactly
like `tripDayWeather` or `tripCylinders`/`tripCylinderEvents`: an entry in
`SyncRepository.hlcTargets`; a `SyncData` field with `toJson`/`fromJson`;
`_baseTables`; the export in `_buildSyncData`; `fetchRecord`, `fetchRecords`,
`upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor`,
`deleteRecord`; then `SyncService.mergeOrder`, `entityHasUpdatedAt`,
`parentRefs`, and the FK labels in `conflict_reference.dart`. That is four
tables' worth of the roughly fifteen touch points `trip_cylinders` needed for
two, so this is the single largest mechanical cost of the concept.

Parent refs: each section table needs `(parentId, parentTable, not
nullable)`; each item table's new `sectionId` needs `(sectionId,
<itsSectionsTable>, nullable)`. Merge order puts sections after their parent
(trip, template or session) and item tables after their sections, the same
ordering discipline `trip_cylinders` uses ahead of `trip_cylinder_events`.

Pre-dive built-in templates are excluded from sync export today
(`pre_dive_tables.dart:19`); the new `pre_dive_checklist_template_sections`
rows for built-ins must be excluded the same way, or a built-in section
would sync as if it were diver-owned data.

## UI implications

The category/section field in the item editor
(`checklist_item_edit_sheet.dart`, `RawAutocomplete` bound to a free text
controller) becomes a picker over the parent's actual sections, with an
inline "new section" option, rather than free text matched against prior
item values. This is also what unlocks the original ask: a section can be
created once, independent of any item, and items added to it afterwards
without retyping its name.

Full section management ships from the start for trip checklists, checklist
templates and pre-dive templates: creating an empty section, renaming it
(today this means editing every item's category string one by one),
reordering sections, and deleting one (items fall back to "no section," not
deleted). Pre-dive session sections get none of this; see the snapshot
decision above. None of the three management interactions is designed in
detail here (exact reorder affordance, confirmation copy on delete); that is
scope for an implementation plan, not resolved in this concept.

## Edge cases

- Case folding during backfill must match the existing runtime grouping
  rule (`_buildGroupedItems`) exactly, or a backfilled section set would
  group differently than the one divers have been seeing: "Cells" and
  "cells" must become one section row, not two.
- Rows written before the `hlc` rollout have `hlc = null` and fall back to
  `updated_at` ordering; the new section tables inherit the same nullable
  `hlc` column and the same fallback, nothing special needed.
- Two devices adding items to the same newly created section: ordinary
  additive inserts with independent ids, no collision, both survive.
- One device deletes a section while another edits an item inside it: the
  item's `section_id` is set to null on merge (its parent section is
  tombstoned), the item itself survives. No cascading delete of items, by
  design.
- `pre_dive_checklist_template_items.source_item_id` (cell linearity items
  referencing the cell reading item they check against) is untouched by this
  change; it keys on item id, not on section, so rewriting sections does not
  touch it.
- Re-running the built-in seed SQL after this migration must stay idempotent
  (`INSERT OR IGNORE`); the rewritten seed inserts section rows with stable
  ids for exactly this reason.

## Testing

- A migration test per table, following the project's one-file-per-version
  convention (`test/core/database/migration_v<N>_*_test.dart`), each
  covering: items with a shared category merge into one section
  case-insensitively; items with no category get no section; built-in
  pre-dive templates end up with the same section structure as before
  (same titles, same grouping), just referenced rather than stringly typed;
  an in-progress and a completed/aborted pre-dive session both backfill
  correctly.
- Sync pinning tests updated for four new tables:
  `sync_hlc_target_registration_test`, `sync_parent_refs_completeness_test`,
  `sync_data_serializer_record_ids_test`, `entityHasUpdatedAt` coverage,
  cross-version roundtrip.
- Repository tests: section CRUD, item `sectionId` round-tripping through
  create/update/bulk edit, cascade behaviour on parent (trip/template/
  session) deletion, set-null behaviour on section deletion.
- Widget tests: section picker in the item editor (existing sections,
  inline create), empty-section rendering, rename/reorder, delete-with-
  fallback.

## Out of scope / open questions

- Exact schema rung numbers: determined per table group only once an
  implementation plan is written, by re-checking the migration ladder at
  that time (the project's own convention, see the gas logistics spec).
- Detailed reorder/rename interaction design for sections in the UI.
- Whether checklist templates should gain a `strictOrder`-style concept at
  the section level (pre-dive templates already have `strict_order` at the
  template level); not raised by the original request, not designed here.
- No GitHub issue exists yet for this work; one should be opened, sized per
  table group or as one umbrella issue with phased PRs, before any
  implementation plan is written (project convention: every PR links an
  issue).
