# Trip Auto-Add Dives from Date Range - Design Document

> **Date:** 2026-03-04
> **Status:** Approved
> **Phase:** v2.0
> **Feature Roadmap Reference:** Trip auto-add dives from trip time range

---

## Overview

When a trip is created or its date range is edited, automatically scan for dives that fall within that range and offer to associate them with the trip. A manual "Find matching dives" button on the trip detail page provides the same functionality on demand.

## Goals

1. Reduce manual effort when associating dives with trips
2. Surface both unassigned dives and dives on other trips as candidates
3. Keep the user in control via a confirmation dialog with per-dive selection
4. Follow existing codebase patterns (media scanner dialog, batch operations)

## Architecture: Repository-Level Scan + UI Dialog

### Approach

Add a `findCandidateDivesForTrip()` query to `TripRepository` that finds dives in a date range. A shared `TripDiveScanner` service wraps the query logic. Both trigger points (post-save and manual button) call the scanner and present results in a `DiveAssignmentDialog`.

This follows the existing `TripMediaScanner` / `ScanResultsDialog` pattern.

---

## Data Model

### DiveCandidate

Lightweight wrapper for scan results:

```dart
class DiveCandidate extends Equatable {
  final Dive dive;
  final String? currentTripId;
  final String? currentTripName;

  // currentTripId == null means unassigned
  bool get isUnassigned => currentTripId == null;
}
```

No new database tables or columns required. This feature operates entirely on existing `dives.trip_id` and `dives.dive_date_time` columns.

---

## Repository Layer

### New method on TripRepository

```dart
Future<List<DiveCandidate>> findCandidateDivesForTrip({
  required String tripId,
  required DateTime startDate,
  required DateTime endDate,
  required String diverId,
}) async { ... }
```

SQL query:

```sql
SELECT d.*, t.name as current_trip_name
FROM dives d
LEFT JOIN trips t ON d.trip_id = t.id AND d.trip_id != ?  -- tripId
WHERE d.dive_date_time >= ? AND d.dive_date_time <= ?     -- startDate, endDate
  AND d.diver_id = ?                                       -- diverId
  AND (d.trip_id IS NULL OR d.trip_id != ?)                -- exclude already-assigned
ORDER BY d.dive_date_time ASC
```

Returns `DiveCandidate` with:
- Full `Dive` object (using existing `_mapRowToDive`)
- `currentTripId` and `currentTripName` from the LEFT JOIN

### Batch assignment

```dart
Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {
  await _db.transaction(() async {
    await _db.batch((b) {
      for (final diveId in diveIds) {
        b.update(
          _db.dives,
          DivesCompanion(tripId: Value(tripId)),
          where: (t) => t.id.equals(diveId),
        );
      }
    });
  });
}
```

All-or-nothing via transaction.

---

## Service Layer

### TripDiveScanner

```dart
// lib/features/trips/data/services/trip_dive_scanner.dart

class TripDiveScanner {
  final TripRepository _tripRepository;

  Future<List<DiveCandidate>> scan({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    return _tripRepository.findCandidateDivesForTrip(
      tripId: tripId,
      startDate: startDate,
      endDate: endDate,
      diverId: diverId,
    );
  }
}
```

Thin wrapper now, but provides an extension point if matching logic becomes more complex.

---

## UI: DiveAssignmentDialog

### File

`lib/features/trips/presentation/widgets/dive_assignment_dialog.dart`

### Layout

Modal bottom sheet with two groups:

1. **Unassigned dives** (pre-checked) -- dives with no trip
2. **On other trips** (unchecked) -- dives currently on a different trip, showing "Currently on: Trip Name" subtitle

### Behavior

- Group headers with select-all/none toggles
- Each row: dive number, site name, date, max depth
- Other-trip dives show subtitle with current trip name
- "Add N Dives" button with dynamic count
- Cancel button returns without changes

### Empty state

If zero candidates found, dialog is not shown. A snackbar says "No matching dives found" (manual trigger only; post-save silently skips).

---

## Trigger Points

### Trigger 1: After trip save

In `_saveTrip()` in `trip_edit_page.dart`:

1. After successful save, compare dates (for edits: skip if unchanged)
2. Call `TripDiveScanner.scan()`
3. If candidates found, show `DiveAssignmentDialog` before `context.pop()`
4. If user confirms, batch-assign, then pop
5. If user cancels or no candidates, pop normally

Flow:

```
Save trip -> scan -> candidates? -> show dialog -> assign -> pop
                  -> no candidates? -> pop
```

### Trigger 2: Manual button on trip detail page

In `trip_overview_tab.dart`, add an icon button in the dives section header row:

```dart
IconButton(
  icon: Icon(Icons.playlist_add),
  tooltip: 'Find matching dives',
  onPressed: () => _scanAndShowDialog(context, ref, trip),
)
```

On completion, invalidate relevant providers to refresh the dive list.

---

## Provider Invalidation

After batch assignment, invalidate:

- `divesForTripProvider(tripId)` -- refresh dive list on detail page
- `tripWithStatsProvider(tripId)` -- update dive count in stats
- `tripListNotifierProvider` -- update list view counts
- For reassigned dives: also invalidate providers for the old trip

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No dives found in range | Skip dialog. Manual trigger: snackbar "No matching dives found". Post-save: silent skip |
| All in-range dives already on this trip | Skip dialog, no message |
| User cancels dialog | No changes, continue normal flow |
| Dive reassigned from other trip | Update trip_id. Invalidate providers for both old and new trip |
| Trip save fails | Scan never reached (existing error handling) |
| Batch assign fails | Transaction rollback. Show error snackbar |
| Date range unchanged on edit | Skip scan entirely |
| Trip has no diverId | Skip scan |

---

## Testing Strategy

| Layer | What to Test |
|-------|-------------|
| Unit -- Repository | `findCandidateDivesForTrip` returns unassigned + other-trip dives, excludes same-trip dives. `assignDivesToTrip` updates all IDs atomically, rolls back on failure |
| Unit -- Scanner | Delegates to repository, handles empty results |
| Unit -- DiveCandidate | Model equality, `isUnassigned` logic |
| Widget -- Dialog | Unassigned pre-checked, other-trip unchecked, count updates dynamically, group select-all toggles, empty state not shown |
| Integration -- Save flow | Create trip with dives in range -> dialog appears -> assign -> verify trip_id. Edit dates -> re-scan triggers |
| Integration -- Manual button | Button visible, triggers scan, dialog shows, assignment works |

---

## Scope

### In Scope

- `DiveCandidate` model
- `findCandidateDivesForTrip()` repository method
- `assignDivesToTrip()` batch repository method
- `TripDiveScanner` service
- `DiveAssignmentDialog` widget
- Post-save trigger in trip edit page
- Manual button on trip detail overview tab
- Provider invalidation for affected trips
- Localization strings

### Out of Scope

- Automatic removal of dives when trip date range shrinks
- Background scanning on app startup
- Push notifications for unmatched dives
- Dive site proximity matching (GPS-based)

---

## Dependencies

- Existing: Drift ORM, Riverpod, `DiveRepository._mapRowToDive`
- No new packages required

---

## Files to Create/Modify

| Action | File |
|--------|------|
| Create | `lib/features/trips/domain/entities/dive_candidate.dart` |
| Create | `lib/features/trips/data/services/trip_dive_scanner.dart` |
| Create | `lib/features/trips/presentation/widgets/dive_assignment_dialog.dart` |
| Modify | `lib/features/trips/data/repositories/trip_repository.dart` |
| Modify | `lib/features/trips/presentation/pages/trip_edit_page.dart` |
| Modify | `lib/features/trips/presentation/widgets/trip_overview_tab.dart` |
| Modify | `lib/features/trips/presentation/providers/trip_providers.dart` |
| Create | `test/features/trips/data/repositories/trip_repository_dive_scan_test.dart` |
| Create | `test/features/trips/presentation/widgets/dive_assignment_dialog_test.dart` |
