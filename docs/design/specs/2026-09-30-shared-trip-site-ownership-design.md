# Shared trip and site ownership: owner deletes, others hide

Issue: #2594 (split out of #2151). Related, out of scope: #2501, #2567.

## Problem

Trips and dive sites carry a nullable `diver_id` (the owning profile) and an
`is_shared` flag. `VisibilityFilter` shows a row to a profile when
`diver_id = me OR is_shared = 1`. Nothing anywhere compares the row's owner
with the active profile, so every profile that can see a shared trip or site
can also destroy it for every other profile.

In #2151 a parent shared their trips, switched to their son's profile and
deleted the trips the son was not on, expecting a per-profile removal. The
trips were deleted for every profile and had to be restored from a backup.

What the code actually does today:

- `TripRepository.deleteTrip` hard-deletes the trip and its children, and runs
  `UPDATE dives SET trip_id = NULL WHERE trip_id = ?` for every diver's dives.
  No dive is deleted, but every profile's dives lose their trip. That update
  does not stamp `updated_at` or mark the dives pending, so the unlink never
  reaches sync peers.
- `SiteRepository.deleteSite` / `bulkDeleteSites` hard-delete the site and
  null `site_id` on every diver's dives (stamped and marked pending).
- `SiteRepository.mergeSites` hard-deletes the duplicates, with no owner
  check, so a non-owner can merge away another profile's shared site.
- The Share toggle on the trip and site edit pages is open to non-owners.
  Switching it off keeps the original owner, so a non-owner's "unshare" makes
  the item private to the owner and removes it from every other profile.
- The "shared, deleting removes it for everyone" warning appears only on the
  two detail pages. The site edit page's delete, the trip list's bulk delete
  and the site list's bulk delete use generic wording.

## Decisions

1. **Referenced model.** A shared trip or site is owned by its `diver_id` and
   referenced by every other profile. Only the owner destroys it or changes
   its sharing. Any profile that sees it may edit its fields (family
   collaboration stays as it is today).
2. **A non-owner hides instead of deleting.** Hiding is per profile, synced,
   reversible, and never changes what any other profile sees.
3. **Hides are rows in two new synced tables**, `trip_hides` and `site_hides`,
   each with real foreign keys. A single polymorphic table was considered and
   rejected: sync's parent-gating FK map and SQLite's `ON DELETE CASCADE` both
   need a fixed parent table.
4. **Owner-only actions:** delete, the Share toggle, and being merged away as a
   duplicate site.
5. **Hiding keeps the hiding profile's own dive links.** The hidden item leaves
   that profile's lists, pickers, map and search, but its dives still show the
   trip or site on the dive page.
6. **The owner's delete stays global**, but every delete path shows the shared
   warning with the count of other profiles' dives that will lose the link.
7. **Hidden items are managed in Settings > Shared data**, with Undo on the
   snackbar right after a hide.

## Data model

### Tables (schema v250)

Declared in `lib/core/database/tables/trip_tables.dart` and
`lib/core/database/tables/site_tables.dart` respectively, registered in the
`@DriftDatabase` table list, never defined in `database.dart`.

```dart
/// A shared trip one diver profile has hidden from itself (v250, issue
/// #2594). The trip stays in its owner's log and every other profile.
@DataClassName('TripHideRow')
class TripHides extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`SiteHides` is identical with `siteId` referencing `DiveSites`.

Indexes, created by the rung and the backstop:

- `idx_trip_hides_unique` UNIQUE on `trip_hides(diver_id, trip_id)`
- `idx_site_hides_unique` UNIQUE on `site_hides(diver_id, site_id)`

The unique index leads with `diver_id` because every read is "this profile's
hidden ids". A surrogate uuid key with a unique index follows
`equipment_shares`, so a hide's tombstone has a stable record id.

### Migration

Follows the v248 `trip_equipment` rung (PR #2585):

- `lib/core/database/migrations/helpers/`: `_assertProfileHidesSchema()`,
  which returns early when a parent table is missing (partial migration-test
  fixtures), then creates both tables and both unique indexes idempotently.
- `migrations/ladder/rungs_v231_onward.dart`: `if (from < 250)` calls it, then
  `reportProgress()`. Table-only rung with no backfill, so the sync floor does
  not move.
- `migrations/before_open.dart`: the same helper as the v250 backstop.
- `database.dart`: `currentSchemaVersion = 250`, and 250 appended to the
  rung-claim list with a comment. At the time of writing, open PRs #2562 and
  #2409 hold stale claims (248 and 246) below main's 249 and will renumber
  past whichever lands first. Re-check the claim before pushing.

### Sync

Both tables sync as parent-gated children, like `equipment_shares` and
`trip_equipment`:

- `SyncRepository` entity map: `'tripHides': (table: 'trip_hides', pk: 'id')`,
  `'siteHides': (table: 'site_hides', pk: 'id')`.
- `SyncService` apply order: after `trips`, `diveSites` and `divers`, with
  `hasUpdatedAt: false`.
- `SyncService` parent map:
  - `'tripHides'`: `tripId` to `trips` and `diverId` to `divers`, both non-null.
  - `'siteHides'`: `siteId` to `diveSites` and `diverId` to `divers`, both non-null.
- `SyncDataSerializer`: export and apply arms, and membership in
  `parentGatedChildEntities`.
- Unhide deletes the row and calls `logDeletion`.

### Deletes that cascade to hides

- Deleting a trip or site: the hide rows go by FK cascade locally. The
  repository first reads their ids and tombstones them in the same
  transaction, so peers drop them too.
- Deleting a diver: `diver_delete_steps.dart` gains two steps. The first
  removes the diver's own hides (`diver_id = ?1`). The second removes hides of
  the diver's trips and sites, placed before the `trips` and `dive_sites`
  steps.

## Rules

A new pure-function file,
`lib/core/data/visibility/shared_item_policy.dart`, is modelled on
`equipment_ownership.dart`. Every caller asks it, so each rule lives in one
place:

```dart
/// The active profile may delete, merge away or re-share the item.
/// An ownerless item and a library with no active diver behave as they
/// did before sharing existed.
bool canDestroySharedItem({required String? ownerId, required String? activeDiverId}) =>
    activeDiverId == null || ownerId == null || ownerId == activeDiverId;

/// The active profile sees the item only because another profile shared it.
bool canHideSharedItem({
  required String? ownerId,
  required bool isShared,
  required String? activeDiverId,
}) =>
    activeDiverId != null && isShared && ownerId != null && ownerId != activeDiverId;
```

For any shared item with an owner, exactly one of the two is true, so the UI
always offers exactly one action: Delete or Remove from my profile.

## Visibility

`VisibilityFilter` becomes owner-or-shared **and not hidden by me**:

- `applyToTrips(query, diverId)`: adds
  `AND id NOT IN (SELECT trip_id FROM trip_hides WHERE diver_id = ?)`.
- `applyToDiveSites(query, diverId)`: the same predicate over `site_hides`.
- `sqlFragment(...)` gains a required `entity` parameter (trip or site), so the
  raw fragment can name the right hides table. All four callers are updated:
  - `trip_repository.dart`, three call sites
  - `site_type_repository.dart`
- `lib/features/query/data/query_name_index.dart` builds its own
  `t.is_shared = 1` clause. It gets the same exclusion, so hidden items leave
  query-language name completion.

A null `diverId` stays a no-op. Lookups by id (`getTripById`, `getSiteById`)
never apply the filter, so a hidden trip still resolves on the hiding
profile's own dive page, as decision 5 requires.

Because `findTripForDate` goes through the filter, import no longer
auto-assigns a new dive to a trip the importing profile has hidden.

## Repositories

### `ProfileHidesRepository` (new)

File: `lib/core/data/repositories/profile_hides_repository.dart`. One API over
both tables:

- `hideTrip(tripId, diverId)` / `hideSite(siteId, diverId)`. Idempotent
  (insert-or-ignore on the unique index), marks the row pending, notifies
  `SyncEventBus`.
- `unhideTrip` / `unhideSite`. Delete plus `logDeletion`.
- `hiddenTripIds(diverId)` / `hiddenSiteIds(diverId)`.
- `hiddenTrips(diverId)` / `hiddenSites(diverId)`. Names and dates for the
  Settings list, joined to the parent rows.
- `tombstoneForTrips(ids)` / `tombstoneForSites(ids)`. Called inside the
  owner's delete transaction.

The repository refuses to write a hide that `canHideSharedItem` rejects, so a
bad caller cannot hide its own item.

### Trip and site repositories

- `deleteTrip(id, {required String? actingDiverId})` returns `bool`: false,
  with nothing changed, when `canDestroySharedItem` rejects. Inside the
  transaction:
  - the dive unlink moves to a new
    `clearDiveTripLinks(db, syncRepository, ids, now:)` in
    `dive_parent_links.dart`, which stamps and marks each dive (this fixes the
    sync gap);
  - the trip's hides are tombstoned.
- `deleteSite` and `bulkDeleteSites` take `actingDiverId`.
  `bulkDeleteSites` returns `({List<String> deleted, List<String> skipped})`.
  Site hides are tombstoned inside `_deleteSiteRows`.
- `mergeSites(..., {required String? actingDiverId})` refuses when any
  duplicate fails `canDestroySharedItem`. The survivor may be any visible site,
  since keeping it destroys nothing.
- `setShared`, `updateTrip` and `updateSite` refuse an `is_shared` change by a
  non-owner. The edit pages already keep the original owner. The guard stops
  a non-owner's save from flipping the flag.
- `countOtherProfilesDivesOnTrip(tripId, ownerId)` and
  `countOtherProfilesDivesAtSite(siteId, ownerId)` feed the owner's delete
  dialog. Both count dives whose `diver_id` is not `ownerId`, excluded dives
  included, since those links are cleared too.

The presentation notifiers (`TripListNotifier.deleteTrip`,
`SiteListNotifier.deleteSite` / `bulkDeleteSites` / `mergeSites`) pass the
validated current diver id and surface the result. They also gain `hide` and
`unhide` methods that refresh the list.

## UI

Every string below is a new ARB key in `app_en.arb`, translated into all 11
locales. The English text is indicative; final copy can be tuned in review.

### Non-owner on a shared trip or site

- **Detail pages** (trip and site): a subtitle line, "Shared by {owner}". The
  overflow item "Delete" is replaced by **"Remove from my profile"**. Its
  confirmation reads:

  > Remove '{name}' from your profile?
  > It stays in {owner}'s log and in every other profile; it is only hidden
  > here. {count, plural, =0{} other{{count} of your dives stay linked to it.}}
  > You can bring it back from Settings > Shared data.

  After confirming, the page pops and a snackbar shows "Removed from your
  profile" with **Undo**, which unhides.
- **Site edit page**: the AppBar delete icon follows the same switch, Delete
  for the owner and Remove from my profile otherwise.
- **Edit pages**: the Share switch is disabled for non-owners, with the
  subtitle "Only {owner} can change sharing". Field editing is unchanged.
- **Site merge**: a site the active profile cannot destroy is not offered as a
  duplicate. The merge pickers filter with `canDestroySharedItem`.

### Owner

Every delete path (trip detail, site detail, site edit page, trip bulk
delete, site bulk delete) shows the shared warning when the item is shared and
two or more profiles exist. The body gains the count when it is above zero:

> '{name}' is shared with other dive profiles. Deleting it here removes it for
> everyone. {count, plural, =0{} other{{count} dives in other profiles will
> lose this trip.}}

### Bulk delete with a mixed selection

The trip and site list bulk-delete dialogs split the selection with the policy:

- owned or ownerless items are deleted;
- shared items owned by another profile are hidden.

With both kinds present, the dialog states both counts: "Delete {n} trips and
remove {m} shared trips from your profile?" With only one kind, it uses that
kind's single wording. The site list's five-second Undo restores the deleted
sites (existing `restoreSites`) and unhides the hidden ones. The trip list has
no Undo today, and this change does not add one for its deletes. The hidden
half is reversible from Settings.

### Settings > Shared data

`SharedDataSectionContent` gains a row, "Hidden from this profile" with the
count, shown only when the count is above zero. It opens a page listing
hidden trips (name, dates) and hidden sites (name, location) in two groups,
each item with an **Unhide** button. The page watches a provider built on
`ProfileHidesRepository.hiddenTrips/hiddenSites` for the validated current
diver, and the trip and site list providers are invalidated after an unhide.

## Error handling

- A refused repository call (not owner) returns false or the skipped ids, and
  never throws. The UI only offers allowed actions, so reaching a refusal
  means stale state. The notifier refreshes and shows the existing
  "Only its owner can..." style snackbar with a new trip/site key.
- Hide and unhide failures are logged and rethrown by the repository. The
  caller shows the generic error snackbar, as the other list actions do.

## Testing (written first)

Repository and data (`test/features/...` and `test/core/...`):

- Hide round trip:
  - hiding a shared trip removes it from `getAllTrips(diverId: me)` and
    `getAllTripsWithStats`;
  - the owner and a third profile still see it;
  - unhiding brings it back.
  - The same for sites across `getAllSites`, search and the site-type count.
- `findTripForDate` skips a trip the profile has hidden.
- `hideTrip` refuses an owned or unshared trip.
- `deleteTrip` by a non-owner returns false and leaves the trip, its children
  and every dive link intact. By the owner, it deletes the trip, tombstones
  its hides, and stamps and marks every unlinked dive pending.
- `bulkDeleteSites` with a mixed selection deletes the owned sites, skips the
  others and reports them.
- `mergeSites` refuses a non-owned duplicate and accepts a non-owned survivor.
- A non-owner's `updateTrip` / `updateSite` cannot change `is_shared`.
- `countOtherProfilesDives*` counts only other profiles' dives, excluded
  dives included.
- Diver delete removes the diver's hides and the hides of its trips and sites
  (tombstoned).
- Sync: the serializer round-trips `tripHides` and `siteHides`, applies their
  tombstones, and holds a hide whose parent trip has not arrived.
- Migration: the v250 rung from 249 creates both tables and indexes; the
  backstop is idempotent; the ladder claim list is contiguous.
- `shared_item_policy_test.dart`: the truth table for both functions, and
  exactly one of the two holds for any owned shared item.

Widget:

- Trip and site detail pages: the owner sees Delete with the shared warning
  and the count; a non-owner sees "Shared by" and Remove from my profile; the
  hide snackbar's Undo unhides.
- Site edit page: the delete icon follows the switch.
- Trip and site edit pages: the Share switch is disabled for a non-owner.
- Trip and site lists: the mixed bulk-delete dialog shows both counts and
  calls delete and hide for the right halves.
- Settings: the hidden row shows only when the count is above zero; its page
  unhides an item.

Existing suites that change with the new `actingDiverId` argument and the
`sqlFragment` entity parameter are updated rather than duplicated, including
`trip_repository_test`, `site_repository_test`,
`site_repository_reference_links_test`, the detail and edit page tests,
`settings_page_shared_data_test` and `visibility_filter_test`. The
`test/architecture/` guards run after the change.

## Out of scope

- Per-profile selective sharing (#2501). This design keeps `is_shared` as the
  sharing switch; a later move to per-profile share rows can keep the
  owner/reference rules and the hides tables unchanged.
- A private shared site library (#2567).
- Transferring ownership of a shared trip or site between living profiles.
  Diver delete already reassigns shared rows to a surviving profile.
- An Undo for the trip list's bulk delete.

## Pull request

- Body: `Closes #2594` and `Refs #2151`.
- Screenshots, light and dark:
  - the non-owner detail page and its dialog;
  - the owner's shared delete dialog with the count;
  - the mixed bulk-delete dialog;
  - the Settings row and the hidden-items page.
