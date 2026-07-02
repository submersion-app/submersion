# Upcoming Trips with To-Do Lists — Design

- **Issue:** [#164](https://github.com/submersion-app/submersion/issues/164)
- **Date:** 2026-07-02
- **Status:** Approved

## Summary

Add trip-planning support: reusable checklist templates, per-trip to-do lists
with due dates, and an Upcoming section on the trips list. Trips are already
future-datable; upcoming/completed state is derived from dates, never stored.

## Decisions

| Question | Decision |
| --- | --- |
| Checklist scope | Full template system: user-managed reusable templates plus per-trip lists |
| Trip status | Derived from dates (`endDate` today or later = upcoming); no stored status column |
| Item shape | Title, done state, optional category, optional due date, notes |
| Trip list UI | Upcoming section pinned above past trips with countdown and checklist progress |
| Template management | Settings page entry, following the Tank Presets pattern |
| Data model | Copy-on-apply: applying a template copies items into the trip as independent rows |

## Data Model (schema v94 → v95)

All tables follow the house pattern: text UUID primary key, unix-timestamp
`createdAt`/`updatedAt`, nullable `hlc` column for cross-device merge.

### `checklist_templates`

| Column | Type | Notes |
| --- | --- | --- |
| id | text PK | UUID |
| diver_id | text, nullable | FK → divers (matches trips) |
| name | text | required |
| description | text | default '' |
| created_at / updated_at | int | unix timestamps |
| hlc | text, nullable | sync clock |

### `checklist_template_items`

| Column | Type | Notes |
| --- | --- | --- |
| id | text PK | UUID |
| template_id | text | FK → checklist_templates |
| title | text | required, non-empty |
| category | text, nullable | free-text grouping (Gear, Documents, ...) |
| notes | text | default '' |
| due_offset_days | int, nullable | days before trip start (14 = "two weeks out") |
| sort_order | int | manual ordering |
| created_at / updated_at / hlc | | as above |

### `trip_checklist_items`

| Column | Type | Notes |
| --- | --- | --- |
| id | text PK | UUID |
| trip_id | text | FK → trips |
| title | text | required, non-empty |
| category | text, nullable | |
| notes | text | default '' |
| due_date | int, nullable | absolute unix timestamp, resolved at apply time |
| is_done | bool | default false |
| completed_at | int, nullable | set when checked |
| sort_order | int | |
| created_at / updated_at / hlc | | as above |

### Apply-template semantics

- Copy-on-apply: template items are copied into `trip_checklist_items`;
  no back-reference to the template afterward.
- `due_offset_days` resolves to `due_date = trip.startDate - offsetDays` at
  apply time. Due dates are frozen afterward: editing trip dates does not
  shift them (predictability over freshness; a "recalculate" affordance can
  come later if needed).
- Applying a second template appends, skipping items whose title and category
  match an existing trip item (idempotent re-apply). The confirm sheet reports
  add vs. skip counts.
- Apply runs in a single transaction that reads template items fresh; if the
  template was deleted, show "template no longer exists" and write nothing.

### Trip status (derived, no schema change to trips)

- `Trip.isUpcoming` — true when `endDate` is today or later, using a
  date-only comparison (same normalization as `Trip.containsDate`).
- `Trip.daysUntilStart` — for countdown display; a trip whose start has passed
  but end has not is "in progress".
- The issue's "transition to completed after dates pass" therefore happens
  automatically; no stored state, no sync conflicts, no staleness.

### Sync / infra registration

- Add all three tables to `_hlcTables` in `database.dart`.
- Add three entries to the entity registry in `sync_repository.dart`
  (pattern: `'itineraryDays': (table: 'trip_itinerary_days', pk: 'id')`).
- Migration v95: create tables + indexes on `trip_checklist_items(trip_id)`
  and `checklist_template_items(template_id)`.
- Deletion cascades are application-level (matching itinerary days): deleting
  a trip deletes its checklist items in the same transaction; deleting a
  template deletes its items. Per-child tombstones are written so sync does
  not resurrect rows.

## Feature Structure

New module `lib/features/checklists/`:

```
checklists/
  domain/entities/
    checklist_template.dart        # ChecklistTemplate + ChecklistTemplateItem
    trip_checklist_item.dart       # TripChecklistItem
  data/repositories/
    checklist_template_repository.dart
    trip_checklist_repository.dart # CRUD, watchByTrip, progress, applyTemplate
  presentation/
    providers/checklist_providers.dart
    pages/checklist_templates_page.dart       # Settings > Checklist Templates
    pages/checklist_template_edit_page.dart
    widgets/trip_checklist_section.dart       # embeddable checklist UI
    widgets/checklist_item_tile.dart
    widgets/apply_template_sheet.dart
```

- Entities: Equatable, `copyWith` with undefined-sentinel for nullable fields
  (matches `Trip`).
- Repositories mirror `itinerary_day_repository.dart` /
  `tank_preset_repository.dart`.
- Providers: `FutureProvider.family` by tripId; checklist providers
  self-invalidate on table change streams so sync updates render live
  (established pattern from dive detail providers).

## UI

### Trip list page

- Partition `tripsProvider` results: upcoming trips (soonest-first) pinned in
  an "Upcoming" section above past trips (unchanged, newest-first).
- Upcoming tiles: countdown ("In 24 days" / "In progress"), accent-tinted
  highlight, checklist progress line ("5 of 12 to-dos done", hidden when the
  trip has no checklist).
- Works in both detailed and compact list view modes (`tripListViewMode`).

### Trip detail page

- Liveaboard (tabbed) trips: fifth **Checklist** tab.
- Simple trips (overview-only): a Checklist card in the overview — summary
  header + progress bar, expandable to the full list.
- Checklist UI: items grouped by category; checkbox toggles `isDone` and
  `completedAt`; overdue chip (warning color) when
  `dueDate < today && !isDone && trip.isUpcoming` — past trips never nag;
  swipe/menu to edit or delete; inline "Add item"; overflow menu with
  **Apply template…** and **Save as template…**.
- Empty states: upcoming trip → "Plan your trip — add to-dos or apply a
  template" with both actions; past trip → plain empty state.

### Templates (Settings)

- New "Checklist Templates" entry in Settings, list → edit-page flow copied
  from Tank Presets.
- Template editor: name, description, reorderable items grouped by category;
  item editor with title / category / notes / due-offset ("days before trip
  start") fields.
- Category field is free text with autocomplete from categories already used
  in the current checklist or template.
- "Save as template…" on a trip checklist is the reverse copy (absolute due
  dates convert back to offsets from trip start; dateless items stay dateless).

## Edge Cases

- Trip dates edited after apply: due dates stay frozen; chips reflect stored
  dates.
- Template deleted mid-apply: transactional read; snackbar; no partial writes.
- Duplicate apply: append with same-title+category skip.
- Trip deletion: checklist items deleted in the same transaction with
  per-row tombstones (junction sync-loss history makes this explicit).
- Empty titles rejected at the form level.

## Testing

- Repository tests: CRUD for both repositories; `applyTemplate` offset
  resolution, append/skip, atomicity; cascade delete writes tombstones;
  FK-ON round-trip (FK-OFF test configs mask insert-order bugs in this repo).
- Entity tests: `isUpcoming` / `daysUntilStart` boundaries (ends today =
  upcoming; starts today = in progress).
- Migration test: v94 → v95 tables + indexes.
- Widget tests: list partitioning and countdown, item tile toggle, progress
  line visibility, templates page list/edit.
- Sync round-trip test: three tables registered; changeset export/import
  preserves rows.

## Localization

All new strings in `app_en.arb` and translated into all 10 other locales,
then regenerate. Countdown strings use proper plural forms.

## Out of Scope (deliberate)

- Notifications/reminders for due items
- Weather or flight integrations
- Shared checklists between divers
- Recalculate-due-dates affordance after trip date edits
- Home-page upcoming-trip tile
