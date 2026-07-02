# Dive Naming — Design (Issue #400)

**Date:** 2026-07-02
**Issue:** [#400 Dive naming](https://github.com/submersion-app/submersion/issues/400)
**Status:** Approved

## Summary

Let users give a dive an optional custom name (e.g. "Open water training Dive 1",
"Wreck penetration dive"). The name is opt-in as a list-tile title via the existing
`DiveField` mechanism, with the site name as the fallback for unnamed dives. The
dive detail header shows the name (site beneath it) when set. The name is
searchable and included in CSV and UDDF exports.

## Decisions

| Question | Decision |
| --- | --- |
| Display scope | Opt-in `DiveField.name` for list tiles/table; unnamed dives fall back to site name |
| Detail page | Name becomes the header title when set, site name shown beneath; unchanged when unset |
| Secondary surfaces | Search, CSV export, UDDF export, table view column — all in scope |
| Fallback location | Display layer (Approach A): `name ?? siteName` in `DiveField.extractFromSummary` and detail header |
| Storage | Nullable `TEXT` column; `null` means "never named" (unambiguous on the sync wire) |
| Bulk edit | Excluded — names are per-dive |
| Imports | No changes — UDDF import and dive computer downloads leave `name` null |

## 1. Data model & migration

- `Dives` table (`lib/core/database/database.dart`): add `name` as
  `text().nullable()()`, placed near `notes`.
- Schema bump 93 → 94: update `currentSchemaVersion`, append `94` to
  `migrationVersions`, add `if (from < 94)` block with
  `ALTER TABLE dives ADD COLUMN name TEXT` followed by the `reportProgress()`
  pattern used by prior blocks.
- `Dive` entity (`lib/features/dive_log/domain/entities/dive.dart`): add
  `final String? name` to field, constructor, `copyWith`, `props`. Follow the
  clear-sentinel convention the entity already uses for nullable `copyWith`
  fields, so a name can be explicitly cleared back to null.
- `DiveSummary` (`.../entities/dive_summary.dart`): add `name` so list tiles can
  project it; populate from `dive.name` where the summary is built.
- Repository (`.../data/repositories/dive_repository_impl.dart`): add
  `name: Value(dive.name)` to both companion write paths (~718, ~959) and
  `name: row.name` to both row→entity reads (~2258, ~2608).
- Sync: no manual work — dives serialize via Drift's generated `toJson()`;
  regenerate `.g.dart` and the column syncs automatically.

## 2. Display

- `DiveField` enum (`lib/core/constants/dive_field.dart`): add `DiveField.name`
  with cases in all four switches (label, `extractFromSummary`, `formatValue`,
  icon). `extractFromSummary` returns `summary.name ?? summary.siteName` — this
  is the single place the list/table fallback lives.
- List tiles and table view require no widget changes; they consume the enum.
- Detail page (`dive_detail_page.dart`, headers at ~659 and ~822): when
  `dive.name` is non-null, show it as the large title with the site name in a
  smaller secondary line; when null, render exactly as today.

## 3. Edit form

- New "Dive name" text row at the top of `TheDiveSection`
  (`.../widgets/edit_sections/the_dive_section.dart`), above dive number.
- `_nameController` in `dive_edit_page.dart` mirroring the `_notesController`
  lifecycle: declare, register, initialize from entity, dispose, read back.
- Empty/whitespace-only text saves as `null`, never `''`.

## 4. Search & export

- Search: add `name` to the LIKE clause in `dive_repository_impl.dart` (~1806),
  alongside notes/buddy/site.
- CSV (`csv_export_service.dart`): add a "Name" header and `dive.name ?? ''` cell.
- UDDF (`uddf_export_builders.dart`): emit the name inside each `<dive>` element;
  UDDF has no first-class dive-title element, so use the closest standard slot
  (`<informationbeforedive>`), matching the existing builder structure.
- Exports write the raw stored name only (blank when unset) — never the site
  fallback.

## 5. Localization & tests

- New ARB keys in `lib/l10n/arb/app_en.arb` with `@` metadata: edit-form label
  and hint, plus the `DiveField.name` display label. Translate into all 10
  non-English locales and regenerate localizations.
- Tests (TDD, written first):
  - Entity: `copyWith`/`props` round-trip including clearing the name.
  - Migration 93 → 94 adds the column; existing rows read back with null name.
  - Repository: insert/update/read round-trip of `name`; search matches by name.
  - `DiveField.name`: named summary returns name; unnamed returns site name.
  - Edit page: entering a name saves it; clearing saves null.
  - CSV and UDDF exports include the name.

## Out of scope

- Bulk edit of names.
- Auto-generating names from dive type or imports.
- Renaming the existing `notes` field or changing site naming.
