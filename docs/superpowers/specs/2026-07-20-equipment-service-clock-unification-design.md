# Equipment service: unify on clocks and fix add-timer

- Date: 2026-07-20
- Status: Approved (design)
- Branch: `worktree-fix+equipment-service-timers`

## Problem

The equipment feature carries two parallel, unreconciled notions of "service
due":

1. Legacy single clock: `EquipmentItem.serviceIntervalDays` + `lastServiceDate`
   feeding the `nextServiceDue` / `isServiceDue` / `daysUntilService` getters.
   Edited in the edit form's "Service Settings" section, reset by the detail
   page "Mark as serviced" action, and still the sole driver of the detail-page
   header banner and the pre-dive checklist; a fallback for list badges.
2. New multi-clock ledger: `ServiceKind` + `ServiceSchedule` + `ServiceRecord`
   evaluated by `ServiceDueEngine`. Managed by `ServiceClocksCard` on the detail
   page. Drives the dashboard due list, trip alerts, and is the primary source
   for list badges.

Editing the "Service interval (days)" field changes `isServiceDue` (header,
list) but never touches a clock, so the two surfaces contradict each other.
That is user-reported issue 1 ("inconsistency in the notion of service timers
and the service field in edit").

Separately, `ServiceDueEngine.evaluate` skips any enabled schedule whose
effective interval is entirely unset (no schedule override and no kind default),
so it produces no status and renders nowhere. The built-in `general-service`
kind has null defaults and is the only kind that applies to every equipment
type, so for gear such as fins/mask/wetsuit it is the only pickable timer and
adding it appears to do nothing. That is user-reported issue 2 ("add new service
timer doesn't work").

## Root causes (confirmed)

- Issue 2: `lib/features/equipment/domain/services/service_due_engine.dart:32-36`
  drops interval-less enabled schedules. `ServiceClocksCard` only renders
  evaluated statuses and paused (disabled) schedules, so an enabled but
  unconfigured schedule appears in neither list. The engine behaviour is
  correct in isolation (an interval-less clock cannot be "due"); the defect is
  that the card gives the user no way to see or configure such a clock.
- Issue 1: the legacy fields and the clocks are independent stores that only
  ever met once, at the v122 `_backfillLegacyServiceSchedules` migration, which
  copied each item's legacy interval into a `legacy-svc-<id>` "General service"
  clock. Any later edit to the legacy field diverges from the clock.

## Decisions (from brainstorming)

- Unify on clocks: clocks become the only "is service due?" signal in the UI.
  The legacy columns are frozen (retained for export/import and for the
  record-driven "Last service" value) and are no longer user-editable.
- Remove the detail page "Mark as serviced" menu action (it wrote a frozen
  column and reset no clock). Service is logged per clock ("Log service") or via
  the Service History "Add" button.
- Keep both service sorts: keep "Last service date" and add a clock-based
  "Service due" sort/column.

## Source-of-truth model

- `lastServiceDate` stays live: `ServiceRecordRepository` rewrites it on every
  record create/update/delete to the newest record's date. It backs the "Last
  service" column/sort.
- `serviceIntervalDays` becomes frozen legacy data (kept for export/import; no
  longer editable in the app).
- Every "is service due?" read in the UI is derived from
  `ServiceDueEngine` output (`serviceClockStatusesProvider` for a single item,
  `equipmentWorstClockProvider` for cross-item lists).

## Design

### Part A: Fix add-timer (presentation only, engine unchanged)

Keeping `ServiceDueEngine` pure preserves `dueClocksProvider`/dashboard
semantics (an unconfigured clock never nags globally). The fix is confined to
the detail-page card and the add flow.

1. `ServiceClocksCard`
   (`lib/features/equipment/presentation/widgets/service_clocks_card.dart`):
   in addition to evaluated statuses and paused schedules, render enabled
   schedules that produced no status ("unconfigured") as a distinct row:
   neutral dot, kind name, subtitle "No interval set - tap to configure",
   tapping opens the interval dialog. Compute the set as enabled schedules whose
   `id` is absent from the evaluated statuses (both `serviceSchedulesForEquipment`
   and `serviceClockStatuses` are already watched here).
2. Add-picker (`service_schedule_dialogs.dart` `showServiceKindPicker`): when the
   tapped kind has no default interval (`defaultIntervalDays`,
   `defaultIntervalDives`, `defaultIntervalHours` all null), create the schedule
   and then immediately open the interval dialog so the clock is born with a
   trigger. Kinds with a default keep the current one-tap behaviour.
3. `showScheduleOverrideDialog` (`service_schedule_dialogs.dart`): generalize to
   accept a `ServiceSchedule` + `ServiceKind` rather than only a full
   `ServiceClockStatus`, so it serves brand-new and unconfigured clocks. Existing
   "edit" callers pass `status.schedule` + `status.kind`.

### Part B: Unify the service-due signal

| Surface | File | Change |
| --- | --- | --- |
| Edit form "Service Settings" | `equipment_edit_page.dart` | Remove the section, `_buildServiceSection`, `_selectLastServiceDate`, `_serviceIntervalController`, `_lastServiceDate`, and the `initState`/`dispose`/`_initializeFromEquipment` wiring. In `_saveEquipment`, preserve existing legacy values via `serviceIntervalDays: existingEquipment?.serviceIntervalDays`, `lastServiceDate: existingEquipment?.lastServiceDate` (new items were already null). |
| Detail header banner + avatar | `equipment_detail_page.dart` | In `_EquipmentDetailContent.build`, watch `serviceClockStatusesProvider(equipmentId)`; `isOverdue = statuses.value?.any((s) => s.severity == ServiceClockSeverity.overdue) ?? false`. Pass this bool into `_buildHeaderSection` and `_buildEmbeddedHeader` in place of `equipment.isServiceDue`. |
| Detail "Mark as serviced" | `equipment_detail_page.dart` | Remove the `service` menu item from `_buildMenuItems` and its `_handleMenuAction` case. |
| List badge + avatar | `equipment_list_content.dart`, `dense_equipment_list_tile.dart` | Drop the `item.isServiceDue` / `item.daysUntilService` legacy fallback branches; rely solely on `equipmentWorstClockProvider`. |
| Pre-dive checklist | `session_item_composer.dart`, `start_session_sheet.dart` | Add `Set<String> overdueEquipmentIds = const {}` to `SessionItemComposer.compose`; use `overdueEquipmentIds.contains(gear.id)` instead of `gear.isServiceDue` (composer stays pure). `start_session_sheet` computes the set from `equipmentWorstClockProvider` (overdue severity) and passes it in. |

`EquipmentItem.isServiceDue` / `nextServiceDue` / `daysUntilService` getters and
the DB columns remain (exports and the frozen-interval column read them
directly), but no UI reads the getters after this change.

### Part C: Sorts and columns (keep both)

- List (card) sort: add `EquipmentSortField.serviceDue`
  (`lib/core/constants/sort_options.dart`). `applyEquipmentSorting`
  (`equipment_providers.dart`) gains a `Map<String, DueClock> worstClocks`
  parameter; ascending `serviceDue` means most urgent first: overdue first (by
  severity), then soonest due date ascending, then items with no clock last;
  descending reverses that ordering (items with no clock first). Both call sites
  in `equipment_list_content.dart` pass
  `ref.watch(equipmentWorstClockProvider).value ?? const {}`.
- Table: `EquipmentFieldAdapter`
  (`lib/features/equipment/domain/constants/equipment_field.dart`) gains a public
  constructor `EquipmentFieldAdapter({Map<String, DueClock> worstClocks = const {}})`
  storing the map; `.instance` (empty map) stays for config deserialization
  (`fieldFromName`). `extractValue` redirects the service-forecast fields to
  clocks: `nextServiceDue -> worstClocks[entity.id]?.status.dueDate`,
  `daysUntilService -> worstClocks[entity.id]?.status.daysUntilDue`. This fixes
  their current legacy inconsistency and makes the existing "Next Service Due"
  column clock-based and sortable (the table sorts via `extractValue`).
  `equipment_list_content._buildTableView` constructs the adapter with the
  current worst-clock map. `lastServiceDate` column stays record-driven;
  `serviceIntervalDays` column keeps reading the frozen column (kept to avoid
  breaking persisted table configs that reference it by name).

### Part D: Migration (v131, one-time)

Bump `currentSchemaVersion` 130 -> 131. Add an onUpgrade `if (from < 131)` block
(never in `beforeOpen`) that reconciles the edge case where a legacy interval was
set via the edit form after the v122 backfill ran, so such an item keeps a due
signal once the field is removed:

```sql
INSERT OR IGNORE INTO service_schedules
  (id, equipment_id, service_kind_id, interval_days, anchor_date,
   enabled, created_at, updated_at)
SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
       e.service_interval_days, e.last_service_date, 1, n.now_ms, n.now_ms
FROM equipment e
CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
WHERE e.service_interval_days IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM service_schedules s WHERE s.id = 'legacy-svc-' || e.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM deletion_log d
    WHERE d.entity_type = 'serviceSchedules'
      AND d.record_id = 'legacy-svc-' || e.id
  );
```

(`entity_type` / `record_id` are the snake_case column names Drift generates for
`DeletionLog.entityType` / `recordId`.)

The deletion-log guard ensures a clock the user deliberately removed is never
resurrected. Deterministic id + `INSERT OR IGNORE` keep independent per-device
migrations convergent under sync. Self-guard for partial fixture databases: skip
unless `equipment` has the `service_interval_days` / `last_service_date` columns
(mirror `_backfillLegacyServiceSchedules`).

## Testing (TDD, failing test first)

- Add-timer (issue 2 repro): widget test that adding a `general-service` clock
  shows a "tap to configure" row in `ServiceClocksCard`; test that the picker
  opens the interval dialog for a no-default kind and one-taps for a
  default-bearing kind.
- Override dialog: unit/widget test that it accepts a bare schedule + kind and
  saves an interval onto a previously unconfigured schedule.
- Unify: detail header overdue derives from clocks; list badge/avatar no longer
  reads `isServiceDue`; `SessionItemComposer` flags overdue from the passed set.
- Sorts: `applyEquipmentSorting` with `serviceDue` orders overdue/soonest/none;
  table adapter sorts `nextServiceDue` by clock date.
- Migration v131: item with post-v122 legacy interval and no clock gets a
  `legacy-svc-` clock; item with a tombstoned `legacy-svc-` id does not.
- Update existing legacy-badge/service tests:
  `equipment_tile_service_badge_test`, `dense_equipment_list_tile_test`,
  `equipment_list_content_test`, `session_item_composer_test`,
  `service_due_engine_test`, `equipment_providers_test`,
  `equipment_repository_test`, `equipment_field_test` (and any others surfaced
  by `flutter test`).

## Risks and edge cases

- Items with `last_service_date` set but no interval never had an
  `isServiceDue` signal (needs both) and get no clock; correct, no regression.
- Removing the "Mark as serviced" action is a deliberate behaviour change
  (approved). `markAsServiced` stays in repository/notifier for now (unused by
  UI) to limit churn.
- Retaining the `serviceIntervalDays` `EquipmentField` avoids crashing
  `fieldFromName` for users whose persisted table config references it.

## Out of scope

- Removing the legacy DB columns.
- Export/import format changes (UDDF, Excel, CSV keep reading the columns).
- Dashboard and trip-alert cards (already clock-based).
- Sort/column redesign beyond adding the clock-based service-due sort.
