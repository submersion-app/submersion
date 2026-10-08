# Liveaboard Tracking - Design Document

> **Date:** 2026-03-01
> **Status:** Approved
> **Phase:** v2.0
> **Feature Roadmap Reference:** Liveaboard tracking (Specialized trip type)

---

## Overview

Introduce a formal trip type system and comprehensive liveaboard tracking to Submersion. Liveaboard trips are multi-day voyages on a dive vessel with unique characteristics: vessel details, embark/disembark ports, daily itineraries alternating between dive days, sea days, and port days. This feature transforms the existing flat trip model into a type-aware system with specialized data, UI, and statistics for each trip type.

## Goals

1. Add a trip type enum (shore, liveaboard, resort, day trip) to the existing trip model
2. Create liveaboard-specific data tables for vessel details and daily itinerary
3. Provide a rich liveaboard trip experience: itinerary timeline, voyage map, enhanced stats
4. Migrate existing trips to the new type system seamlessly
5. Lay the groundwork for future type-specific features (resort details, day trip behavior)

## Architecture: Trip Type System with Detail Tables

### Approach

Add a `tripType` column to the existing `trips` table. Create type-specific detail tables linked 1:1 to trips. Each trip type determines which detail table is loaded and which UI sections are displayed.

This follows the existing pattern of related detail tables (e.g., `dive_tanks`, `dive_profiles` for dives) and keeps the core `trips` table lean.

---

## Data Model

### Trip Type Enum

```dart
enum TripType { shore, liveaboard, resort, dayTrip }
```text
Stored as text in the database. Defaults to `shore` for backward compatibility.

### Modified Table: `trips`

Add column:

- `trip_type` TEXT NOT NULL DEFAULT 'shore'

Existing `liveaboard_name` and `resort_name` columns are kept for backward compatibility during migration, then deprecated in the domain entity.

### New Table: `liveaboard_details`

1:1 relationship with `trips` (via `trip_id`).

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | TEXT | NO | UUID primary key |
| trip_id | TEXT FK | NO | References trips.id |
| vessel_name | TEXT | NO | Name of the liveaboard vessel |
| operator_name | TEXT | YES | Charter company / operator |
| vessel_type | TEXT | YES | Catamaran, Motor Yacht, Sailing Yacht, Other |
| cabin_type | TEXT | YES | Cabin assignment (e.g., "Deluxe Double") |
| capacity | INT | YES | Passenger capacity |
| embark_port | TEXT | YES | Departure port name |
| embark_latitude | REAL | YES | Departure port GPS latitude |
| embark_longitude | REAL | YES | Departure port GPS longitude |
| disembark_port | TEXT | YES | Arrival port name |
| disembark_latitude | REAL | YES | Arrival port GPS latitude |
| disembark_longitude | REAL | YES | Arrival port GPS longitude |
| created_at | INT | NO | Unix timestamp |
| updated_at | INT | NO | Unix timestamp |

### New Table: `trip_itinerary_days`

Many:1 relationship with `trips` (via `trip_id`).

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | TEXT | NO | UUID primary key |
| trip_id | TEXT FK | NO | References trips.id |
| day_number | INT | NO | 1-indexed day of trip |
| date | INT | NO | Unix timestamp for this day |
| day_type | TEXT | NO | "dive_day", "sea_day", "port_day", "embark", "disembark" |
| port_name | TEXT | YES | Port/anchorage name if applicable |
| latitude | REAL | YES | Location GPS for this day |
| longitude | REAL | YES | Location GPS for this day |
| notes | TEXT | NO | Free-text notes (default empty) |
| created_at | INT | NO | Unix timestamp |
| updated_at | INT | NO | Unix timestamp |

### New Domain Entities

**LiveaboardDetails:**

```dart
class LiveaboardDetails extends Equatable {
  final String id;
  final String tripId;
  final String vesselName;
  final String? operatorName;
  final String? vesselType;
  final String? cabinType;
  final int? capacity;
  final String? embarkPort;
  final double? embarkLatitude;
  final double? embarkLongitude;
  final String? disembarkPort;
  final double? disembarkLatitude;
  final double? disembarkLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... copyWith, props
}
```text
**ItineraryDay:**

```dart
enum DayType { diveDay, seaDay, portDay, embark, disembark }

class ItineraryDay extends Equatable {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final DayType dayType;
  final String? portName;
  final double? latitude;
  final double? longitude;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... copyWith, props
}
```text
**Updated Trip Entity:**

```dart
class Trip extends Equatable {
  // ... existing fields ...
  final TripType tripType;  // NEW
  final LiveaboardDetails? liveaboardDetails;  // NEW (loaded when type is liveaboard)
  final List<ItineraryDay> itineraryDays;  // NEW (loaded when present)
  // liveaboardName and resortName deprecated but still present for compat
}
```text
### Migration Strategy

1. Add `trip_type` column to `trips` with default `'shore'`
2. Create `liveaboard_details` and `trip_itinerary_days` tables
3. Migrate existing data:
   - Trips with `liveaboard_name IS NOT NULL` -> `trip_type = 'liveaboard'`, create `liveaboard_details` row with vessel name
   - Trips with `resort_name IS NOT NULL` (and no liveaboard) -> `trip_type = 'resort'`
   - All others -> `trip_type = 'shore'`

---

## UI/UX Design

### Trip Type Selector (Create/Edit Form)

Material 3 `SegmentedButton` at the top of the trip form:

```

[ Shore ] [ Liveaboard ] [ Resort ] [ Day Trip ]

```typescript
Type selection dynamically shows/hides form sections:

| Type | Visible Sections |
|------|-----------------|
| Shore | Name, Dates, Location, Notes |
| Liveaboard | Name, Dates, Vessel Details, Embark/Disembark, Location, Notes |
| Resort | Name, Dates, Resort Name, Location, Notes |
| Day Trip | Name, Date (single), Location, Notes |

### Liveaboard Form Sections

**Vessel Details card:**

- Vessel name (required when type is liveaboard)
- Operator / charter company (optional)
- Vessel type (dropdown: Catamaran, Motor Yacht, Sailing Yacht, Other)
- Cabin type (text field, optional)
- Passenger capacity (number, optional)

**Embark / Disembark card:**

- Embark port name + optional GPS map picker
- Disembark port name + optional GPS map picker
- Dates auto-filled from trip start/end

### Trip Detail Page — Liveaboard Tab Layout

For liveaboard trips, the detail page uses a tab bar:

```

[ Overview ] [ Itinerary ] [ Photos ] [ Dives ]

```typescript
Non-liveaboard trips retain the current scrollable layout.

### Itinerary Tab

Vertical timeline of days auto-generated from trip date range:

- Day 1 is auto-typed as "embark", last day as "disembark"
- Middle days default to "dive_day"
- User can change any day's type, add port name, add notes
- Dives are auto-grouped by date and shown under each day
- Each day shows: day number, date, type badge, port (if set), dive count, site names

### Voyage Map Card (Overview Tab)

Interactive `flutter_map` showing the liveaboard route:

1. Embark port marker (green) at start
2. Dive site markers (blue) connected by polyline in chronological order
3. Disembark port marker (red) at end
4. Missing GPS coordinates gracefully skipped

Uses existing `TileCacheService` for offline tile support.

### Enhanced Statistics (Overview Tab)

Liveaboard trips show expanded stats:

| Stat | Source |
|------|--------|
| Total Dives | Existing |
| Total Bottom Time | Existing |
| Max / Avg Depth | Existing |
| Dives Per Day | Dive count / dive day count |
| Dive Days | Count of itinerary days with type "dive_day" |
| Sea Days | Count of itinerary days with type "sea_day" |
| Sites Visited | Distinct dive site count |
| Species Seen | Unique species from marine_life_sightings |

### Daily Breakdown Section

Collapsible summary table below stats:

```text

Day  Type       Dives  Bottom Time  Sites
1    Embark     -      -            Hurghada
2    Dive Day   3      142m         Abu Nuhas, Sha'ab El Erg
3    Dive Day   4      186m         Thistlegorm, Ras Mohammed
4    Sea Day    -      -            Transit
...

```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Trip type changed after dives assigned | Allowed. Dives belong to the trip regardless of type. Itinerary days regenerated if switching to liveaboard. |
| Liveaboard with no vessel name | Form validation blocks save |
| Date range changed after itinerary edited | Warn user. Preserve notes for existing days within range. Delete days outside new range. Add new days with defaults. |
| GPS missing for embark/disembark | Voyage map skips points without coordinates |
| Existing trips migration | Automatic based on liveaboard_name/resort_name presence |

---

## Testing Strategy

| Layer | Target | What to Test |
|-------|--------|-------------|
| Unit | Entities | TripType enum serialization, LiveaboardDetails copyWith/equatable, ItineraryDay copyWith/equatable, DayType enum |
| Unit | Repository | CRUD for liveaboard_details, CRUD for trip_itinerary_days, migration logic, itinerary regeneration on date change |
| Unit | Providers | Trip type switching behavior, itinerary auto-generation from date range, voyage route computation, enhanced stats calculation |
| Integration | Trip lifecycle | Create liveaboard trip -> add vessel details -> generate itinerary -> log dives -> verify stats and itinerary grouping |
| Widget | Form | SegmentedButton shows/hides correct sections per type, validation rules per type, date range changes |
| Widget | Detail | Tab layout for liveaboard trips, itinerary timeline rendering, voyage map markers |

---

## Scope

### In Scope

- Trip type enum (shore, liveaboard, resort, day trip)
- `liveaboard_details` table, entity, repository
- `trip_itinerary_days` table, entity, repository
- Trip type selector (SegmentedButton) in create/edit form
- Liveaboard-specific form fields (vessel, cabin, embark/disembark)
- Itinerary tab with auto-generated days and dive grouping
- Voyage map with embark -> dive sites -> disembark route
- Enhanced statistics for liveaboard trips
- Daily breakdown summary
- Data migration for existing trips
- Sync support for new tables

### Out of Scope (Future)

- Resort-specific detail table (uses existing `resortName` for now)
- Day trip single-date behavior
- Trip templates (liveaboard, resort week, local weekend)
- Shared trip / group booking
- Crew/staff tracking
- Meal/activity scheduling

---

## Dependencies

- Existing: `flutter_map`, `latlong2`, `TileCacheService`, Drift ORM, Riverpod
- No new packages required
