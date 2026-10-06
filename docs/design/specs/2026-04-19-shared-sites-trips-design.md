# Shared Sites and Trips Across Dive Profiles

## Problem

The app supports multiple local dive profiles per install (family use case). Today, every site and every trip is owned by exactly one diver via the `diver_id` foreign key, and list/search queries filter by the active diver. Families with multiple profiles must therefore re-enter identical trip and site data once per family member.

Reported by a scubaboard user who is tracking three family divers on one install and was frustrated that after completing trip and site entry for the first diver, the same data had to be re-entered from scratch for the other two.

## Goal

Let users mark individual sites and trips as visible to all local dive profiles, with a global Settings toggle controlling the default for newly created records. Existing data is not changed on upgrade; users opt in explicitly per record, via the default toggle, or via a one-click bulk action.

## Scope

- `trips` and `dive_sites` tables gain an `is_shared` boolean.
- `settings` table gains a `share_new_records_by_default` key.
- `TripRepository` and `DiveSiteRepository` queries become visibility-aware.
- Trip edit page and site edit page get a "Share with all dive profiles" toggle.
- Settings page gets the default toggle plus two bulk-share buttons.
- Trip list and site list get a small "shared" badge, hidden for single-diver installs.
- A centralized `VisibilityFilter` helper encodes the predicate for Drift builder queries and raw SQL.

## Out of Scope

- Cross-device or cross-install sharing. "Shared" means visible to all dive profiles *in the same app install*.
- Sharing of dives themselves. Dives remain strictly per-diver. Sharing applies only to the container entities (trips, sites).
- ACLs / per-diver access lists. Any local diver can see, edit, or delete a shared record.
- Household-aggregate statistics. Trip stats remain per-diver (only the active diver's dives are counted). A "household view" can be added later if requested.
- Separate flags on `liveaboard_detail_records` or `trip_itinerary_days`. These inherit their parent trip's visibility.
- New sync conflict semantics. `is_shared` syncs as an ordinary column under existing last-write-wins rules.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Granularity | Per-record boolean `is_shared` on `trips` and `dive_sites` | Matches user intent ("this trip is shared, that one isn't"); smallest schema change; grep-able. |
| Default for new records | Controlled by global Settings key, defaulting to `false` | Solo/existing users see zero behavioral change. Multi-profile users can flip one switch to change the default without touching individual records. |
| Existing data on upgrade | Untouched | Most conservative; avoids any surprise visibility changes. Explicit opt-in via per-record toggle or bulk-share action. |
| Ownership model | `diver_id` retained, re-interpreted as "created by / owner" | Preserves all existing FKs and sync semantics; no data migration needed beyond adding the new column. |
| Edit/delete on shared records | Any diver can edit or delete | Family trust model. ACLs would be over-engineering for a local-only feature. |
| Trip children (itinerary, liveaboard details) | Inherit parent trip visibility via join, no separate flag | Prevents nonsensical states (shared trip with invisible itinerary); zero user-facing complexity. |
| Dives in shared trips | Remain per-diver | Each diver logs their own dives, optionally assigned to the shared trip. Preserves existing dive privacy model. |
| Stats on shared trips | Active diver's dives only | Matches current behavior; avoids surprising aggregation. |
| Central filter abstraction | `VisibilityFilter` helper with two entry points (Drift builder + SQL fragment) | Repositories mix idioms; one helper covers both. Prevents forgotten filter sites from leaking private records. |
| Settings toggle location | Global `settings` table (key `share_new_records_by_default`) | The default is household-level, not per-diver. Per-diver defaults would let profiles disagree and create confusing mixed state. |
| UI affordance suppression | Sharing UI hidden when only 1 diver exists | Solo users never see sharing chrome until a second profile is created. |
| Bulk-share action | "Share all my sites" / "Share all my trips" buttons in Settings → single UPDATE per table | Minimal, reversible; matches the mental model of "I already have this data, make it visible to my family." |

## Data Model

### Schema changes (v68 → v69)

```dart
class Trips extends Table {
  // ...existing columns...
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
}

class DiveSites extends Table {
  // ...existing columns...
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
}
```

Migration (additive):

```dart
if (from < 69) {
  await m.addColumn(trips, trips.isShared);
  await m.addColumn(diveSites, diveSites.isShared);
}
```

`currentSchemaVersion` increments from 68 to 69. No backfill required — the default is `false`, which matches current per-diver behavior.

### Settings key

One new row in the existing `settings` key-value table:

| Key | Value | Default behavior |
|---|---|---|
| `share_new_records_by_default` | `"true"` or `"false"` (string) | Absent → treated as `"false"`. |

## Architecture

### Visibility semantics

For any query scoped to a given `diverId`, the visibility predicate is:

```
(diver_id = :diverId) OR (is_shared = 1)
```

The special case `diverId == null` (already supported on existing repository methods to mean "no filter / all divers") remains a pass-through — the filter is skipped entirely. This preserves every current unfiltered call site.

`get<Entity>ById` methods are *not* filtered. If a caller already has the ID, it arrived via a filtered list or an explicit user action; re-filtering would add cost without benefit and would break legitimate cross-scope lookups (e.g., sync worker reading by ID).

### `VisibilityFilter` helper

New file: `lib/core/data/visibility/visibility_filter.dart`.

```dart
/// Applies the "owner-or-shared" visibility predicate to queries
/// on tables that have a nullable diver_id and an is_shared column.
class VisibilityFilter {
  /// Adds the predicate to a Drift builder query on trips.
  /// No-op when diverId is null.
  static void applyToTrips(
    SimpleSelectStatement<$TripsTable, Trip> query,
    String? diverId,
  );

  /// Same, for dive_sites.
  static void applyToDiveSites(
    SimpleSelectStatement<$DiveSitesTable, DiveSite> query,
    String? diverId,
  );

  /// Returns a SQL fragment and its variables for raw-SQL composition.
  /// - tableAlias: e.g., "t" or "trips", used to qualify columns.
  /// - conjunction: "AND" or "WHERE", chosen by the caller based on
  ///   whether preceding clauses already opened a WHERE.
  /// When diverId is null, returns an empty fragment (no WHERE text,
  /// no variables), so callers can concatenate unconditionally.
  static SqlFragment sqlFragment({
    required String tableAlias,
    required String? diverId,
    required String conjunction,
  });
}

class SqlFragment {
  final String whereClause; // e.g., "AND (t.diver_id = ? OR t.is_shared = 1)"
  final List<Variable<Object>> variables;
  bool get isEmpty => whereClause.isEmpty;
}
```

Two entry points (Drift and raw SQL) reflect the two idioms used across the repositories. One helper, two shapes; callers pick whichever matches the surrounding query style.

### Repository integration

**`lib/features/trips/data/repositories/trip_repository.dart`** — apply the filter at every diver-scoped query site:

- `getAllTrips({String? diverId})` — replace the inline `diverId` branch with `VisibilityFilter.applyToTrips(query, diverId)`.
- `searchTrips(query, {String? diverId})` — splice `VisibilityFilter.sqlFragment(tableAlias: 'trips', diverId: diverId, conjunction: 'AND')` into the WHERE.
- `findTripForDate(date, {String? diverId})` — same pattern.
- `getAllTripsWithStats({String? diverId})` — same pattern. Note the `LEFT JOIN dives` is unaffected; dives are still filtered by `trip_id` only, but the visible-trips subset is now controlled by the fragment.
- `findCandidateDivesForTrip(...)` — unchanged. This already filters by `d.diver_id = ?` on dives, which is correct and unrelated to site/trip visibility.

**Trip child repositories** (`itinerary_day_repository.dart`, `liveaboard_details_repository.dart`) — unchanged. All their access patterns are keyed by `tripId` (`getByTripId`, `deleteByTripId`, `saveAll` for a known trip). There is no "list all itinerary days" query. Filtering the parent `trips` query is therefore sufficient: if a diver cannot see the trip, they cannot reach its children. No visibility-filter plumbing is needed on these repos.

New methods on `TripRepository`:

```dart
/// Mark all trips owned by diverId as shared. Returns count updated.
/// Marks every affected row as pending for sync.
Future<int> shareAllForDiver(String diverId);

/// Set is_shared on a single trip.
Future<void> setShared(String tripId, bool isShared);
```

**`lib/features/dive_sites/data/repositories/site_repository_impl.dart`** — same shape of changes. Any method that accepts `diverId` (list, search, by-coordinates, etc.) routes through `VisibilityFilter.applyToDiveSites` or `sqlFragment` with `tableAlias: 'dive_sites'`. New methods `shareAllForDiver(String)` and `setShared(String, bool)` mirror the trip repository.

### Settings repository integration

New file: `lib/features/settings/data/repositories/app_settings_repository.dart`.

The existing `DiverSettingsRepository` is keyed by `diver_id` and is the wrong fit (this default is household-level). The only current consumer of the global `settings` key-value table is `DiverRepository` (for `active_diver_id`). A new, narrowly-scoped repository gives us a dedicated home for global app settings.

```dart
class AppSettingsRepository {
  static const _shareByDefaultKey = 'share_new_records_by_default';

  Future<bool> getShareByDefault();   // false if missing
  Future<void> setShareByDefault(bool value);
}
```

Trip and site edit pages read `getShareByDefault()` when opening the create form to pre-state the toggle. On edit of an existing record, the toggle reflects `is_shared` from the record itself (not the default).

## UI Changes

| Screen | Change |
|---|---|
| `lib/features/trips/presentation/pages/trip_edit_page.dart` | New `SwitchListTile` labeled **"Share with all dive profiles"**. Initial value: for a new trip, read from `AppSettingsRepository.getShareByDefault()`; for an existing trip, read `trip.isShared`. Persists into `Trip.isShared` on save. Switch is hidden when the app has only one diver. |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Same switch, same logic. |
| `lib/features/trips/presentation/widgets/trip_list_content.dart` | Small leading or trailing icon (e.g., `Icons.people_outline`) on tiles where `trip.isShared == true`. Hidden when only one diver exists. |
| `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | Same icon on shared site tiles, same suppression rule. |
| `lib/features/settings/presentation/pages/settings_page.dart` | New section (or row under an existing "Divers" section): (a) `SwitchListTile` "Share new sites and trips by default" bound to `AppSettingsRepository`. (b) Two `ListTile`s: "Share all my sites" and "Share all my trips", each tapping through a confirmation dialog to `repository.shareAllForDiver(activeDiverId)`. Whole section hidden when only one diver exists. |

Domain entity updates:

- `Trip` gains `final bool isShared;` with default `false`, propagated through the constructor, `copyWith`, and `props`.
- `DiveSite` gains the same field.
- Repository `_mapRowToTrip` / `_mapRowToDiveSite` read and write the new column.

## Migration & Bulk-Share

### Schema migration

Pure additive: two column additions with `FALSE` default. No data backfill. Passes the project's existing `db-backup-before-migration` flow (CLAUDE.md requires no special handling for additive migrations).

### Bulk-share action

UI entry point: Settings → "Share all my sites" (or trips).

Flow:

1. Show confirmation dialog: *"This will make all N sites owned by [diver name] visible to every dive profile in this app. You can unshare individual sites later. Continue?"* Count (N) read via a quick `SELECT COUNT(*) WHERE diver_id = ? AND is_shared = 0`.
2. On confirm, call `repository.shareAllForDiver(diverId)`:

   ```sql
   UPDATE trips SET is_shared = 1, updated_at = ? WHERE diver_id = ? AND is_shared = 0
   ```

3. For each updated ID, call `SyncRepository.markRecordPending('trips', id, updatedAt)`.
4. Fire `SyncEventBus.notifyLocalChange()`.
5. Snackbar: "Shared N sites with all dive profiles."

Wrapped in a `_db.transaction` to keep the UPDATE + pending marks atomic.

## Sync Considerations

`is_shared` is a normal synced field. Changes flow through the existing `markRecordPending` → sync queue path. Two scenarios worth naming explicitly:

- **Diver A shares trip on device 1, Diver B edits it on device 2 before sync.** Last-write-wins resolves by `updatedAt` exactly as today. No new conflict logic needed.
- **Diver A deletes a shared trip.** Deletion is logged via `SyncRepository.logDeletion` and propagates normally. After sync, all devices see the trip gone. Any child dives (on any diver) lose their `trip_id`, which is already the existing cascade behavior and matches user expectation.

No changes to sync payload formats beyond the extra `is_shared` field being serialized/deserialized like any other column.

## Testing

### Unit

- `VisibilityFilter.applyToTrips` — with `diverId = null`, query is unchanged. With non-null `diverId`, the predicate matches rows where `diver_id == diverId` **or** `isShared == true`.
- `VisibilityFilter.applyToDiveSites` — mirror.
- `VisibilityFilter.sqlFragment` — null `diverId` returns empty fragment; non-null returns expected `"(alias.diver_id = ? OR alias.is_shared = 1)"` with a single variable, properly prefixed with the requested conjunction (`AND` or `WHERE`).
- `TripRepository.shareAllForDiver` — creates N private trips owned by diver A, calls `shareAllForDiver('A')`, asserts all are now `is_shared == true` and all are marked pending in the sync queue.
- `TripRepository.setShared` — single-row toggle updates the field and `updatedAt`.
- Analogous tests on `SiteRepositoryImpl`.
- `AppSettingsRepository.getShareByDefault` — returns `false` when key absent, returns stored value otherwise.

### Integration

- Create trip owned by Diver A with `is_shared = false`; switch active diver to B; assert `getAllTrips(diverB.id)` does *not* include it.
- Create trip owned by Diver A with `is_shared = true`; switch to Diver B; assert it **is** returned.
- Same pair for sites.
- Migration: seed a v68 database with trips and sites; run `onUpgrade`; assert schema is v69 and all existing rows have `is_shared == false`.
- Settings toggle flow: set `share_new_records_by_default = true`, open trip create form, assert the "Share with all dive profiles" toggle is pre-checked; save trip; assert `trip.isShared == true`.

### UI / widget

- Trip edit page shows the share switch when 2+ divers exist, hides it when only 1.
- Site edit page same.
- Trip list tile renders the shared badge when `trip.isShared && diverCount > 1`.
- Settings page renders the bulk-share buttons only when 2+ divers exist.

Coverage target 80% per CLAUDE.md. The `VisibilityFilter` module should be at or near 100% since its output is trivially testable.

## Rollout

- No feature flag. The feature is inert for single-diver installs (zero visible change) and opt-in for multi-diver installs (Settings toggle defaults off; existing records stay private until the user acts).
- Single schema migration (additive, reversible via revert + manual column drop if ever needed).
- No third-party dependencies added.
- User-facing change is documented in release notes under "Multi-profile support" or similar.
