# Multiple checklists per trip (issue #3356)

> **Revision note:** the first version of this spec (below, UI section) was
> implemented, reviewed and hot-build-tested, then rejected by the maintainer:
> the entry point (a "+ Add checklist" name dialog, separate from "Apply
> template") did not match the existing, already-familiar workflow. The data
> model, migration and sync sections were kept as-is; the UI section below
> reflects the corrected, maintainer-specified design that replaced the
> original one in the same PR, after a walkthrough of the exact desired
> interaction. See "UI (final)" below.

## Problem

A trip currently supports only a single checklist. `TripChecklistItem` links
directly to `tripId`, and `TripChecklistSection` (issue #3360) groups items
within that one flat list. There is no way to keep "dive equipment",
"clothing" and "beach vacation" as independently named, independently
tracked lists.

## Goals

- A trip can have zero, one, or several named checklists.
- Each checklist keeps its own sections, items, progress, and its own
  "save as template" / "apply template" actions.
- Existing trips with a checklist today see no regression: exactly one
  checklist, automatically created by migration, with their existing
  sections and items intact.

## Non-goals

- Pre-dive checklist templates/sessions (`features/pre_dive`) are a separate
  feature family and are untouched.
- Excel export does not currently cover trip checklists; out of scope.

## Data model

New table `trip_checklists`:

- `id`, `tripId` (FK -> `trips`), `name`, `sortOrder`, `createdAt`,
  `updatedAt`, `hlc`.

`trip_checklist_sections` and `trip_checklist_items` drop their direct
`tripId` column and gain `checklistId` (FK -> `trip_checklists`, NOT NULL),
matching the issue's own suggested approach and the precedent set by issue
#3360 (sections as their own table, introduced via a backfilling migration
rung). As with every other FK in this family (`trip_checklist_sections.tripId`,
`trip_checklist_items.tripId` today), `checklistId` carries no SQL
`ON DELETE` action: children are always deleted explicitly in app code
before their parent, confirmed by the existing comment in
`diver_owned_rows.dart:113-115`. `TripChecklistsRepository.deleteChecklist`
follows the same order `TripChecklistSectionRepository.deleteSection`
already uses for items: delete items, then sections, then the checklist row.

### Migration

A new rung, schema version **v332** (current `currentSchemaVersion` is 331,
`database.dart:302`), follows the `checklist_section_migrations.dart` idiom:

1. Guard: `trip_checklists` doesn't exist yet -> create it.
2. For every trip that has at least one existing `trip_checklist_sections`
   or `trip_checklist_items` row, create one default checklist row (named
   literally "Checklist", not localized -- migrations run before any UI
   context exists; the diver can rename it like any other checklist,
   `sortOrder = 0`).
3. Backfill `checklist_id` on every existing section/item row to that
   trip's new default checklist.
4. Drop the old `trip_id` column from both tables.
5. Register the same idempotent backfill function in the before-open
   backstop, matching the existing self-healing pattern.

## Repository layer

- New checklist CRUD (create, rename, reorder, delete-with-cascade) mirrors
  `TripChecklistSectionRepository`'s shape, as a new `TripChecklistsRepository`
  to keep file sizes under the 800-line cap.
- Existing item/section methods switch their primary key parameter from
  `tripId` to `checklistId`.
- `TripRepository.deleteTrip` -> `TripChecklistsRepository.deleteAllForTrip`
  (`trip_repository.dart`) is the only place a trip's checklists are ever
  bulk-deleted. Diver delete goes through its own `diver_delete_steps.dart`
  sweep instead (a trip's checklists reference it via `trip_checklists`,
  not the trip directly, so that sweep's `_ofDiverTrips` where-clause gained
  one extra join hop, `_ofDiverTripChecklists`).
- `getProgressForTrips` (home screen badge) sums `(done, total)` across all
  of a trip's checklists. For today's single-checklist trips this is
  behaviourally identical; for multi-checklist trips the home badge shows
  the trip's combined progress rather than one arbitrary checklist's.
  Decided over picking/ranking one checklist: identical result for every
  existing trip, and "combined progress" is the more natural reading for a
  single dashboard tile than favouring one of several lists arbitrarily.
- `applyTemplate` / `saveAsTemplate` take a `checklistId` instead of a
  `Trip`. The `ChecklistTemplate` entity itself is already
  trip-independent and needs no change.
- `clearItems` ("Clear checklist" overflow action) scopes to one checklist
  instead of the whole trip.

## Sync

- Renaming a synced column is a breaking change by this codebase's own
  rule (`database.dart`'s `minimumCompatibleSchemaVersion` doc), so this
  raises the floor 308 -> 332. **Known gap**: the floor is one-directional
  (it stops THIS build's payload reaching an older reader), and unlike the
  v297 `category` rename, no receiving-side overlay exists yet to tolerate
  an older peer's still-`tripId`-shaped payload arriving here before that
  peer updates. Worth a follow-up before this ships broadly; low risk pre-
  release since no fleet currently carries pre-#3356 builds that would hit
  this during a real rollout.
- New entity type `tripChecklists` registered at every touch point
  `tripChecklistSections` currently appears in `sync_data_serializer.dart`
  (constructor fields, named params, toJson/fromJson, registry entry,
  `_safeExport`, the serialize/apply/insert/upsert/conflict-lookup/
  table-lookup switch-cases, and the raw `_db.select` helper).
- `conflict_reference.dart` gains parent-ref overrides for the new
  `checklistId` columns on `trip_checklist_sections` and
  `trip_checklist_items`.
- `TripChecklistsRepository.deleteAllForTrip` and the diver-delete sweep
  (`diver_delete_steps.dart`'s `diverTripAndSiteSteps`) both delete
  `trip_checklists` rows explicitly now, the same way they already delete
  sections and items; the sweep's checklist/section/item steps go through
  one extra join hop (`checklist_id -> trip_checklists.trip_id`) since
  those tables no longer carry `trip_id` directly.

## UI (original, superseded -- see revision note at the top)

- The trip detail screen's "Checklist" tab (`trip_detail_tabs.dart`) becomes
  a vertical list of expandable checklist blocks (accordion), not a nested
  tab bar. Each block's header shows the checklist's name and its own
  progress bar (done/total of that checklist only); expanding it reveals
  the existing `SectionListEditor`-based sections/items layout unchanged.
- Default expand state: the first checklist starts expanded, the rest
  collapsed.
- A "+" affordance adds a new checklist via a name dialog.
- The per-checklist overflow menu (apply template / save as template /
  clear / rename / delete) lives on that checklist's block header.

## UI (final)

Walked through with the maintainer trip by trip, replacing the "+ Add
checklist" name dialog above entirely:

- The Checklist tab keeps today's entry point unchanged in spirit: a
  three-dot overflow menu with "Apply template...". Picking a template there
  has always generated that trip's checklist content and shown its progress;
  this is preserved exactly, just no longer tied to a single, trip-wide
  checklist.
- Every checklist block (including a brand-new one) carries that same
  three-dot menu. A persistent "Add checklist" row always sits at the end of
  the list, with nothing but that menu on it -- selecting a template there
  **creates** a new checklist (named after the template, populated with its
  items) rather than acting on an existing one, with no name prompt: a
  template-created checklist's name always comes from the template that
  produced it.
- The placeholder's menu also carries "New checklist...", for a checklist
  with no template behind it: this one does prompt for a name
  (`ChecklistNameDialog`, shared with the rename dialog), then creates an
  empty checklist the diver fills in by hand through the existing manual
  "Add section"/"Add item" affordances, and can save as a template later
  through that checklist's own menu -- restoring a capability the
  template-only placeholder from the first UI pass had dropped (maintainer
  feedback after testing that pass).
- Picking the same template more than once is allowed and expected: each
  pick is a new, separate checklist, even if same-named as an earlier one --
  mirrors how two sections can already share a title today.
- Choosing "Apply template..." on an **existing**, already-populated
  checklist does not merge or append: after a destructive-replace
  confirmation naming both the checklist and the chosen template, the
  checklist's current items and sections are dropped and replaced wholesale
  by the new template's content. `TripChecklistRepository.replaceWithTemplate`
  implements this; it and `_addChecklistFromTemplate`'s create-then-apply
  sequence both run the delete/create step and the template-existence check
  in one transaction (or clean up the created checklist on failure), so a
  template deleted mid-flight cannot leave a checklist half-replaced or an
  orphaned empty one.
- Every checklist also keeps the per-checklist overflow menu's other
  entries: save as template, clear (items only), rename (local to this
  checklist instance, never touches the template file), delete.
  The manual "+ Add section" / "Add item" affordances inside an expanded
  checklist are unchanged from today.
- **All checklists start collapsed** when the trip is opened -- none are
  auto-expanded, even the first. Each block's progress line is always
  visible regardless of its expand state.
- Checklists are reorderable via up/down arrows on each block, next to its
  overflow menu -- the same up/down-arrow pattern `SectionListEditor`
  already uses for sections and items, now one level up.
  `TripChecklistsRepository.reorderChecklists` backs this.
- No new router route: the feature stays embedded inline in trip detail, as
  it is today.

## Risks / things this design deliberately addresses

- `homeTripChecklistProvider` and the "Clear checklist" action both
  silently assumed one checklist per trip; both are explicitly redesigned
  above (sum vs. per-checklist scope) rather than left to misbehave
  quietly once a trip has more than one.
- Several architecture/sync tests assert a flat one-table-per-concept
  shape (`sync_parent_refs_completeness_test.dart`,
  `diver_delete_owned_tables_test.dart`, `cross_version_roundtrip_test.dart`,
  migration tests under `test/core/database/`). These need explicit
  additions for the new table; the generic sync-serializer pattern makes
  a missed touch point a silent data-sync bug, not a compile error, so the
  implementation checks each one against this list rather than trusting a
  green test run alone.

## Decisions settled during the design stress test

- Home badge sums progress across all of a trip's checklists (see
  Repository layer above).
- A brand-new trip starts with zero checklists; the migration backfill is
  consistent with this (a trip with no existing items/sections gets no
  default checklist either), so old and new trips reach the same empty
  state the same way.
- UI is an accordion of per-checklist blocks with their own progress bar,
  not nested tabs (see UI above).
- `checklistId` carries no SQL `ON DELETE` action, matching every other FK
  in this table family; deletion is always explicit app code.
