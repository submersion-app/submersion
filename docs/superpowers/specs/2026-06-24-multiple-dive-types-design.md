# Multiple Dive Types Per Dive — Design

- **Issue:** [#414](https://github.com/submersion-app/submersion/issues/414) — "Allow multiple dive types for a single dive"
- **Date:** 2026-06-24
- **Status:** Approved (design); ready for implementation plan

## Summary

Today a dive has exactly one dive type, stored as a single text slug (e.g.
`recreational`) chosen from a single dropdown. Dive categories are not mutually
exclusive — a dive can be recreational *and* shore *and* photography at once.
This change lets a dive carry multiple types, with full consistency across the
editor, bulk editor, display, filtering, statistics, sync, and import/export.

## Product decisions (settled during brainstorming)

1. **Scope: full treatment.** Editor, display, filtering, and statistics all
   become multi-aware. No half-states.
2. **Invariant: at least one type.** New dives default to a single
   `recreational` type; the editor will not save a dive with zero types. This
   preserves today's invariant (every dive has always had a type), so there is
   no new "untyped" concept to handle in display/filter/stats.
3. **Editor UX: dropdown-collapses-to-chips.** A compact field shows the
   selected types as chips at rest and expands to a checkbox list for
   multi-selection, with an inline "Add custom type…" affordance.
4. **Display: chips,** mirroring the existing Tags section.
5. **Storage: junction table** mirroring the existing `DiveTags` pattern (see
   Architecture).
6. **Statistics counting:** a multi-type dive counts toward *each* of its types.
   Per-type counts therefore sum to more than the total dive count — expected
   for multi-label data.

## Architecture

### Storage model: junction table (`dive_dive_types`)

We add a many-to-many junction table linking dives to dive-type slugs, exactly
like `DiveTags` links dives to tags. The existing `dives.dive_type` column is
**retained as a denormalized "representative" slug** equal to the dive's first
selected type.

Why a junction table over a delimited string:

- Reuses a **proven pattern** already in this codebase (`DiveTags`), minimizing
  novel risk.
- Keeps statistics `GROUP BY` and filter SQL **clean** (JOIN / `EXISTS`) instead
  of fragile `LIKE`/split logic on a delimited column.
- Syncs **safely** as its own entity.
- Preserves the curated dive-type taxonomy (built-ins + custom types, the
  management page, and the per-type statistics breakdown).

Why keep the representative `dives.dive_type` column:

- **Graceful degradation over sync** for older app versions, which read the
  single column and continue to work (showing one representative type).
- **Single-value export formats** (CSV cell, a primary `<divetype>`, the PDF
  "training dive" heuristic) have a sensible representative to use.

### Sync-correctness constraint (load-bearing)

The junction table **must use a surrogate UUID primary key**, never a
`(diveId, diveTypeId)` composite. This is how `DiveTags` avoids the #347
data-loss bug, where a delete-all+reinsert changeset carries a live row *and* a
same-key tombstone and the clockless row loses, wiping membership on sync.
Because every reinserted row gets a fresh `uuid.v4()`, its id can never collide
with the tombstone of the row it replaced. The write path clones
`DiveRepositoryImpl.bulkReplaceTags` (delete → `logDeletion` per old id →
reinsert fresh UUIDs → `markRecordPending`) exactly.

## Detailed design

### 1. Schema & migration (v91 → v92)

New table in `lib/core/database/database.dart`, mirroring `DiveTags`:

```dart
/// Junction table for dive types (many-to-many)
class DiveDiveTypes extends Table {
  TextColumn get id => text()();                       // surrogate UUID
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveTypeId => text()();               // slug; references dive_types by convention
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- No `hlc`/`updatedAt` (matches `DiveTags`).
- Register in the schema entity list and bump `currentSchemaVersion` to **92**.
- **Migration v92:** for every existing dive, insert one `dive_dive_types` row
  from its current `dives.dive_type` value, each with a fresh UUID. Guarded /
  idempotent like the existing migration steps; tolerant of minimal-schema test
  databases.
- Keep `dives.dive_type` (the representative column) unchanged.

### 2. Domain entities

`lib/features/dive_log/domain/entities/dive.dart`:

- Add `final List<String> diveTypeIds;` with a **non-empty** invariant (defaults
  to `['recreational']`).
- Keep `String get diveTypeId => diveTypeIds.first;` as a getter so the ~dozen
  existing readers (field extractors, PDF template, etc.) keep compiling and now
  show the representative type.
- Add `List<String> get diveTypeNames` for multi display. The existing
  `diveTypeName` getter returns the first name.
- Update `copyWith`/`props`.

`lib/features/dive_log/domain/entities/dive_summary.dart`:

- Add `final List<String> diveTypeIds;` (loaded via `group_concat` in the
  summary query) so the in-memory filter and the table column see the full set.

### 3. Repository (`dive_repository_impl.dart`)

- New `bulkReplaceDiveTypes(diveIds, typeIds)` cloned from `bulkReplaceTags`
  (`:3684`): read existing → delete → `logDeletion` per old id → reinsert fresh
  UUIDs → `markRecordPending` → bump dive `updatedAt` and mark dive pending.
  Also writes `dives.dive_type = typeIds.first`. Enforces non-empty (coerce to
  `['recreational']` defensively).
- New `bulkAddDiveTypes` / `bulkRemoveDiveTypes`, cloned from `bulkAddTags`
  (`:4038`) / `bulkRemoveTags` (`:4082`). Each recomputes and writes the
  representative column to the dive's first remaining type, and never leaves a
  dive with zero types (a remove that would empty a dive falls back to
  `['recreational']`).
- `insertDive` / `updateDive`: write the junction set and the representative
  column together.
- Read mappers (`:2221`, `:2569`, and the `DiveSummary` mapper `:1388`):
  hydrate `diveTypeIds` from the junction; when a dive has **no** junction rows
  (a legacy/old-version dive), fall back to a single-element list from the
  `dives.dive_type` column.

### 4. Editor widget (new, shared)

`DiveTypeMultiSelectField` — a `FormField<List<String>>`:

- **At rest:** a FormRow-styled field showing the selected types as a `Wrap` of
  chips plus a dropdown caret.
- **On tap:** an anchored dropdown overlay (scrollable, height-constrained;
  modal bottom sheet fallback on narrow widths) containing a `CheckboxListTile`
  per available type from `diveTypeListNotifierProvider`, plus an **"Add custom
  type…"** tile that creates a `DiveTypeEntity` via the existing dive-types
  repository/provider and auto-checks it.
- Enforces the ≥1 invariant (the last checked item cannot be unchecked).
- Replaces the single dropdown at `dive_edit_page.dart:2933` and is reused by
  the bulk editor (below).

### 5. Bulk edit — move from the scalar lane to the collection lane

The bulk engine separates **scalar** fields (`BulkField` → one value into a
`DivesCompanion`) from **collections** (`BulkCollectionOp` sealed hierarchy →
`add` / `remove` / `replace` ops applied by `BulkDiveEditService`). Dive type is
a scalar today only because it was single-valued; multi-select moves it to the
collection lane, exactly like `TagsOp`.

- **Remove from the scalar lane** (`bulk_edit_field_set.dart`):
  `BulkField.diveType` (enum), `BulkScalarInputs.diveTypeId`, the
  `buildScalarCompanion` case (`:141-143`), the scalar `_bulkDiveTypeDropdown()`
  widget (`:740`), and its registration (`:801-804`).
- **Add the collection op** (`bulk_edit_request.dart`):
  ```dart
  class DiveTypesOp extends BulkCollectionOp {
    final BulkCollectionMode mode;       // add | remove | replace
    final List<String> diveTypeIds;
    const DiveTypesOp({required this.mode, required this.diveTypeIds});
  }
  ```
  and add `diveTypes` to `BulkCollectionType`.
- **Service** (`bulk_dive_edit_service.dart`): a new `case DiveTypesOp(...)` arm
  in `_applyOp` (`:196+`), dispatching to the three repo methods (mirror the
  `TagsOp` arm at `:198-206`). The sealed class makes the compiler enforce the
  new switch arm.
- **Undo:** add `priorDiveTypeIds` (`Map<diveId, List<String>>`) to
  `BulkEditSnapshot`, captured before apply, restored in `undo()` via
  `bulkReplaceDiveTypes([id], …)` (mirror the tags branch at `:149-154`). The
  scalar-row restore already brings the representative column back; both derive
  from the same snapshot, so they remain consistent.
- **UI:** a `_collectionEntry(type: BulkCollectionType.diveTypes, …)` with the
  Add/Remove/Replace mode selector and the shared `DiveTypeMultiSelectField`.
- **Providers** (`dive_providers.dart`): expose
  `bulkAddDiveTypes`/`bulkRemoveDiveTypes`/`bulkReplaceDiveTypes` on the relevant
  notifiers (mirror `bulkAddTags`/`bulkRemoveTags` at `:432/442/844/854`).

### 6. Display

- **Detail page** (`dive_detail_page.dart:2501`): replace the plain-text type
  row with a chip `Wrap` styled like `_buildTagsSection` (`:3317`).
- **Configurable table column** `diveTypeName` (`dive_field_extractor.dart`):
  render `diveTypeNames.join(', ')` for both `Dive` and `DiveSummary`.
- **List cards:** unchanged (type is not shown there today) — keeps scope tight.

### 7. Filter & search

- Repo SQL (`dive_repository_impl.dart:1495-1497`): replace `d.dive_type = ?`
  with `EXISTS (SELECT 1 FROM dive_dive_types ddt WHERE ddt.dive_id = d.id AND
  ddt.dive_type_id = ?)`.
- In-memory filter (`dive_filter_state.dart:186`): replace
  `dive.diveTypeId != x` with `!dive.diveTypeIds.contains(x)`.
- Filter UI stays single-select (filter *by a type*, now matching membership).
  Selecting multiple types to filter is a future enhancement (out of scope).
- The active-filter chip (`dive_list_content.dart:1286`) is unchanged.

### 8. Statistics (multi-aware)

- `statistics_repository.getDiveTypeDistribution()` (`:461-506`): JOIN through
  `dive_dive_types` and `GROUP BY dive_type_id` instead of grouping the
  `dives.dive_type` column. A multi-type dive counts toward each type.
- `dive_type_repository.getDiveTypeStatistics()` (`:293-348`): JOIN through the
  junction instead of `dives.dive_type = dt.id`.
- `dive_type_repository.isDiveTypeInUse(id)` (`:350-370`, gates deleting a custom
  type): `EXISTS` against the junction.
- Where there is a natural spot, add a one-line note that per-type counts can
  sum to more than the total dive count.

### 9. Sync

- Register a new `diveDiveTypes` entity everywhere `diveTags` is registered:
  - `sync_data_serializer.dart`: field (cf. `:219`), default (`:260`), `toJson`
    (`:302`), `fromJson` parse (`:345`), export call (`:588`) + a
    `_exportDiveDiveTypes`, and an import case using
    `insertOnConflictUpdate(DiveDiveType.fromJson(data))` (cf. `:1089-1092`).
  - `sync_service.dart`: `(type: 'diveDiveTypes', records: data.diveDiveTypes,
    hasUpdatedAt: false)` (cf. `:836`) and the registrations at `:1242`/`:1301`.
- Surrogate-UUID strategy keeps this clear of #347.
- The representative `dives.dive_type` column continues to sync via the generic
  column path.
- **Known transition-window limitation (documented, accepted):** while one
  device still runs an *older* app version, editing a dive's type there updates
  only the representative column, not the junction. Full multi-type consistency
  resumes once all devices are updated. A reconciliation rule is a possible
  future enhancement, out of scope.

### 10. Import / export

- **UDDF export** (`uddf_export_service.dart:233`, `uddf_export_builders.dart:243`):
  emit one `<divetype>` element per type.
- **UDDF import** (`uddf_full_import_service.dart:532`, `_parseDiveType:2027`):
  collect all `<divetype>` elements into a list, map each free-text value to a
  slug, dedupe, ensure ≥1.
- **MacDive import:** use the `List<String> diveTypes` the reader already parses
  (`macdive_xml_models.dart:105`, `macdive_xml_reader.dart:92`) instead of
  flattening to one slug — a clean win.
- **CSV** (`csv_export_service.dart:167`; `value_converter.dart` `parseDiveType`
  `:176`/`:370`): export joins the names with a delimiter; import splits and maps
  each.
- **Excel** (`excel_export_service.dart:215`, specialty counts `:599-609`): the
  per-dive cell joins names; specialty counts (night/drift/wreck) become
  membership checks across the set (more accurate).
- **PDF PADI** (`pdf_template_padi.dart:214-216`): "training dive" detection
  checks membership across the set (or `courseId`).
- **Garmin FIT:** unaffected (never sets a type slug).

### 11. Defaults & dead code

- New dives default to a single `['recreational']` type (preserves current
  behavior).
- **Remove** the dead `enum DiveType` (`enums.dart:4-22`) — it has zero runtime
  references and its name collides confusingly with the Drift-generated
  `DiveType` row class for the `dive_types` table.
- The `defaultDiveType` setting (`database.dart:782`) is currently dead (no UI,
  never read on dive creation). **Out of scope** — wiring it up is a separate
  concern, noted as a follow-up.

## Testing (TDD, ≥80% coverage)

- **Migration:** existing single-type dives produce exactly one junction row
  each; representative column unchanged.
- **Repository round-trip:** a dive with multiple types saves and reloads with
  the full set; the representative column stays equal to the first type.
- **Sync (#347 scenario, explicit):** replace a dive's type membership, run a
  sync export+import, assert no membership loss and no resurrection.
- **Filter:** a dive matches a single-type filter when that type is one of its
  several types (SQL and in-memory paths).
- **Statistics:** a multi-type dive counts in each of its type buckets.
- **Bulk edit:** add / remove / replace across multiple dives; the
  remove-to-empty edge falls back to `['recreational']`; an undo round-trip
  restores prior membership and the representative column.
- **Editor widget:** ≥1 enforcement (cannot uncheck the last type); "add custom
  type" creates and selects a new type.
- **Import/export:** UDDF, CSV, and MacDive round-trips preserve multiple types.

## Out of scope

- Selecting multiple types simultaneously in the *filter* UI.
- Type chips on dive list cards.
- Wiring up the `defaultDiveType` setting.
- Any user-facing "primary type" concept (the representative column is an
  internal denormalization only).

## Affected files (for planning)

- Schema/migration: `lib/core/database/database.dart`
- Entities: `dive.dart`, `dive_summary.dart`
- Repository: `dive_repository_impl.dart`; providers `dive_providers.dart`
- Editor widget: new `DiveTypeMultiSelectField`; `dive_edit_page.dart`
- Bulk edit: `bulk_edit_field_set.dart`, `bulk_edit_request.dart`,
  `bulk_dive_edit_service.dart` (+ snapshot)
- Display: `dive_detail_page.dart`, `dive_field_extractor.dart`
- Filter: `dive_repository_impl.dart`, `dive_filter_state.dart`,
  `dive_search_page.dart`, `dive_list_page.dart`
- Statistics: `statistics_repository.dart`, `dive_type_repository.dart`
- Sync: `sync_data_serializer.dart`, `sync_service.dart`
- Import/export: `uddf_export_service.dart`, `uddf_export_builders.dart`,
  `uddf_full_import_service.dart`, `uddf_entity_importer.dart`,
  `csv_export_service.dart`, `excel_export_service.dart`,
  `pdf_template_padi.dart`, `value_converter.dart`, MacDive mapper
- Cleanup: `enums.dart` (remove `enum DiveType`)
- Localization: new strings for the multi-select field, bulk mode labels, and
  any "counts can exceed total" note (all locales)
