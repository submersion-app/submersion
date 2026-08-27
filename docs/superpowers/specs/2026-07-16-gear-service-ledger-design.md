# Gear Service Ledger — Design

Date: 2026-07-16
Status: Approved (brainstorm complete)
Branch: worktree-gear-service-ledger

## Summary

Extend equipment service tracking from a single clock per item to N concurrent
service clocks per item. Cylinders get hydro / VIP / O2-clean schedules,
regulators get "annual or 100 dives, whichever comes first," computers and
transmitters get battery clocks. Reminders surface proactively — before an
upcoming trip, on the gear tab, on the home dashboard, and via local push
notifications — instead of the diver discovering an expired hydro at the fill
station.

## Motivation

Today `Equipment` carries one clock (`lastServiceDate` + `serviceIntervalDays`)
that drives the service-due badge, `markAsServiced`, and the notification
pipeline. One clock cannot express a cylinder that needs hydro every 5 years
AND VIP annually AND O2-clean annually, or a regulator serviced annually OR
every 100 dives. `ServiceRecords` already exists as a history ledger but its
`nextServiceDue` is never read by the reminder engine.

## Decisions (from brainstorm)

1. Clock triggers: date-based, dive-count-based, and hours-based; a clock may
   set any subset; earliest satisfied trigger wins ("whichever comes first").
2. Service kinds: built-in curated catalog plus user-defined custom kinds.
3. Nag surfaces: trip-aware banner, gear tab indicators, local push
   notifications, and a home dashboard card (all four).
4. Trip scope: all active (non-retired) gear; no trip-gear linkage schema.
5. Data model: dedicated schedule + catalog tables (Approach A), not
   records-derived clocks or a JSON column.

## Section 1 — Data model and migration (schema v113)

### New table: ServiceKinds (synced)

| Column | Type | Notes |
|---|---|---|
| id | text PK | |
| diverId | text, nullable, FK Divers | null for built-ins; set for custom kinds |
| name | text | e.g. "Hydrostatic test" |
| applicableTypes | text (JSON array) | equipment type names this kind suggests for, e.g. `["tank"]` |
| defaultIntervalDays | int, nullable | |
| defaultIntervalDives | int, nullable | |
| defaultIntervalHours | real, nullable | accumulated dive hours |
| autoAttach | bool | auto-create a schedule when matching equipment is created |
| isBuiltIn | bool | protected from deletion; exporters skip; beforeOpen re-seeds |
| createdAt / updatedAt | int | |
| hlc | text, nullable | sync clock |

Seeded built-ins:

| Kind | Types | Interval | Auto-attach |
|---|---|---|---|
| Hydrostatic test | tank | 1825 d | yes |
| Visual inspection (VIP) | tank | 365 d | yes |
| O2 clean | tank | 365 d | no (only O2-service cylinders) |
| Regulator service | regulator | 365 d OR 100 dives | yes |
| Computer battery | computer | 730 d | yes |
| Transmitter battery | transmitter | 365 d | yes |
| BCD/wing inspection | bcd | 365 d | yes |
| Drysuit seals | drysuit | 730 d | no |
| General service | (any) | none | no (migration target for legacy intervals) |

`EquipmentType` enum gains `transmitter` (string-backed; no table change).

### New table: ServiceSchedules (synced)

| Column | Type | Notes |
|---|---|---|
| id | text PK | |
| equipmentId | text FK Equipment, cascade | |
| serviceKindId | text FK ServiceKinds | |
| intervalDays / intervalDives / intervalHours | nullable | null = inherit kind default; per-item override |
| anchorDate | int, nullable | baseline when no ServiceRecord of this kind exists (e.g. last hydro before app adoption, or manufacture date) |
| enabled | bool, default true | pause a clock without deleting it |
| createdAt / updatedAt | int | |
| hlc | text, nullable | |

### ServiceRecords change

Add nullable `serviceKindId` FK. Existing `serviceType` string stays for
display and back-compat. Logging a record of kind X resets clock X because
next-due derives from the newest record of that kind.

### Next-due is computed, never stored

Anchor = newest ServiceRecord of the schedule's kind, else `anchorDate`, else
`Equipment.purchaseDate`, else `Equipment.createdAt`. Date trigger = anchor +
intervalDays. Usage triggers count dives / sum durations linked via
`DiveEquipment` (plus `DiveTanks.equipmentId` for cylinders, unioned and
deduplicated) since the anchor. Effective due = earliest satisfied trigger.
Storing due dates would require HLC-stamped rewrites every time a dive is
logged; deriving costs a query, not a sync row.

### Legacy single clock

`Equipment.lastServiceDate` / `serviceIntervalDays` columns remain (older
synced devices read them, and `_updateEquipmentLastServiceDate` keeps writing
`lastServiceDate`). Migration inserts a "General service" schedule for each
item with a legacy interval (interval = legacy days, anchor =
`lastServiceDate`). All new UI and reminders read schedules only.

### Migration v113 steps

1. Create `service_kinds` and `service_schedules` (with indexes, also asserted
   for fresh installs — indexes must not live only in onUpgrade).
2. Add `service_records.service_kind_id`.
3. Seed built-in kinds (also re-asserted in beforeOpen).
4. Backfill "General service" schedules from legacy intervals.
5. Add `scheduled_notifications.schedule_id` (device-local table, not synced).

## Section 2 — Due-computation engine and reminders

### ServiceDueEngine (pure domain service)

`lib/features/equipment/domain/services/service_due_engine.dart`. Input: an
item's schedules, service records, usage stats. Output: `ServiceClockStatus`
per enabled schedule — resolved intervals (override ?? kind default), each
trigger's state, effective due date, severity `ok` / `dueSoon` (within
reminder window) / `overdue`. Item-level severity = worst clock; this is what
list badges read.

### Usage stats query

Repository method returns, per equipment item, the (date, duration) pairs of
linked dives since the oldest anchor among the item's clocks; the engine
counts per clock in Dart. One round-trip per item; one grouped query for the
all-gear dashboard.

### Providers (Riverpod)

- `serviceClockStatusesProvider(equipmentId)` — detail page.
- `dueClocksProvider` — dashboard card and gear list badges.
- `tripServiceAlertsProvider(tripId)` — trip banner.

All watch relevant table streams so logging a dive or service record updates
badges reactively.

### Trip alert rule

A clock alerts for a trip when its date trigger falls before `trip.endDate`,
or any trigger is already due/overdue at trip start. Future usage triggers are
not forecast — dive cadence on the trip is unknowable and false alarms erode
trust.

### Notifications

`NotificationScheduler` iterates schedules instead of equipment rows. Platform
notification ID becomes `scheduleId.hashCode + daysBefore` (the old
`equipmentId.hashCode + daysBefore` cannot represent two clocks on one item —
flutter_local_notifications silently replaces on ID collision).
`ScheduledNotifications` gains `scheduleId`. Existing global reminder days
(`[7, 14, 30]`) and per-item custom reminder settings gate when nags fire, per
clock. Additionally one notification per upcoming trip with service alerts
("3 items need service before <trip>") scheduled at trip start minus the trip
lead time (setting, default 14 days). Push remains mobile-only; desktop is
covered by in-app surfaces.

## Section 3 — UI surfaces

- **Equipment detail**: the single-interval service section becomes a Service
  clocks card — one row per schedule: kind, status chip, binding trigger
  ("due 12 Mar 2027" / "8 of 100 dives left"). Row actions: log service
  (pre-filled add-service dialog), edit overrides (interval, anchor),
  pause/enable. "Add clock" opens a kind picker filtered by
  `applicableTypes`, with "Manage service types" linking to a CRUD page for
  custom kinds (built-ins read-only).
- **Equipment edit**: single service-interval field removed for new items;
  auto-attach populates clocks at the repository layer on create.
- **Service history**: records show a kind chip; add-service dialog gains a
  kind dropdown (defaulting from context).
- **Gear list**: badge severity = worst clock; subtitle names the culprit
  ("Hydro overdue").
- **Trip banner**: trip detail and upcoming-trip banner show a service line
  when alerts exist; tap opens a bottom sheet listing item, kind, due date vs
  trip start. Works on all platforms.
- **Home dashboard**: "Service due" card — overdue first, then due-soon;
  tap-through to the item; hidden when empty.
- **Settings**: one addition to notification settings — trip lead time
  (default 14 days).
- **L10n**: all new strings translated into all 10 non-English locales;
  interval and date display respect locale and diver unit settings.

## Section 4 — Sync and testing

### Sync

- Both new tables carry `hlc`, register in `sync_data_serializer.dart`
  `_baseTables` (keys `serviceKinds`, `serviceSchedules`), with matching
  `SyncData` fields.
- Repos stamp `markRecordPending` + `SyncEventBus.notifyLocalChange()` on
  writes.
- Deletions write per-row tombstones, including schedule rows cascaded by an
  equipment delete (children need explicit tombstones).
- Built-in kinds: exporters skip `isBuiltIn`; beforeOpen re-seeds.
- Sync import uses `.toCompanion(false)` for these HLC entities.

### Testing (TDD)

- Migration test v112 -> v113 with legacy-interval fixtures (schedule
  backfill, seeds, fresh-install parity including indexes).
- `ServiceDueEngine` unit tests: each trigger type, whichever-comes-first,
  anchor fallback chain, disabled clocks, override vs kind default.
- Usage query: junction + `DiveTanks` union dedup.
- Trip alerts: date-trigger-before-trip-end, already-overdue at start,
  no-forecast of usage triggers.
- Notification IDs unique across two clocks on one item.
- Sync round-trip for both tables including tombstones and built-in skip.

## Out of scope

- Forecasting usage triggers across a trip's expected dives.
- Trip-gear linkage schema.
- CCR scrubber/cell hour tracking UI presets beyond what custom kinds allow
  (a custom kind with an hours interval covers it).
- Dropping the legacy `lastServiceDate` / `serviceIntervalDays` columns.
