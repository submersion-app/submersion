# Per-Profile Trip and Site Sharing Design

Issue: #2151. Builds on the ownership and hide work of #2594 (PR #2675), whose
design is `docs/design/specs/2026-09-30-shared-trip-site-ownership-design.md`
and whose plan (`docs/design/plans/2026-09-30-shared-trip-site-ownership.md`)
lists every place a per-profile trip or site table has to be wired.

## Why

A family keeps several diver profiles on one device. A parent logs a dive trip,
and only some of the family went. Today a trip or dive site is either private
to its owner or shared with every profile (`is_shared`). Sharing a trip so a
son can attach his dives to it also puts it in a daughter's log, which is the
clutter the #2151 reporter wanted to avoid. Their workaround (deleting the
trips from the son's profile) deleted them everywhere; #2675 fixed that by
making only the owner able to delete, with "Remove from my profile" for
everyone else. What is still missing:

1. A way to share a trip or site with **chosen profiles**, not all of them.
2. The "Share all my trips" confirmation says "You can unshare individual
   trips later" without saying how.
3. The user docs never explain ownership, "Remove from my profile", or the
   "Hidden from this profile" page.

## Goals

- The owner of a trip or dive site can share it with **Everyone** (every
  profile, including profiles added later) or with **specific profiles**, and
  can change or clear that at any time.
- The usual family flow is: create the trip in your own profile, then share it
  afterwards with the people who were on it. Sharing is done after the trip
  exists (the user's choice); a new trip may also be shared from its edit page,
  as today.
- Bulk sharing: select trips (or sites) in the list, then **Share with...**.
  Settings > Shared data's "Share all my trips" and "Share all my sites" open
  the same picker, as "Share all my equipment..." does today.
- Clear wording about how to stop sharing, and user docs that explain the
  whole model.

## Non-goals

- Copying or linking another profile's dives onto a trip (the reporter's wish
  not to retype dive details). Each profile still logs or imports its own
  dives. That is a separate feature.
- Changing "Share new sites and trips by default": it keeps meaning Everyone.
- Any change to shared site libraries (#2567). A library site stays visible to
  its members regardless of the new sharing.
- Changing equipment sharing.

## Anti-goals

- Unsharing, unticking a profile, or any sharing change must never delete or
  unlink anyone's dives. A profile that loses sight of a trip keeps its dives
  linked to it; the dive page still shows the trip by id, as it does today for
  an unshared or hidden trip.
- A non-owner must never be able to change who an item is shared with. The
  repository refuses it, not only the UI (same rule as #2675).
- Existing data must not change meaning: every trip or site shared today stays
  visible to every profile.
- An older app version syncing the same data must never show an item to a
  profile it was not shared with.

## The model

| State | Stored as | Who sees it |
| --- | --- | --- |
| Not shared | `is_shared = 0`, no share rows | Owner only |
| Everyone | `is_shared = 1`, no share rows | Every profile, including later ones |
| Specific profiles | `is_shared = 0`, one share row per chosen profile | Owner plus those profiles |

- Two new synced tables, `trip_shares` and `site_shares`: `id`, `trip_id` /
  `site_id` (cascade on parent delete), `diver_id` (cascade on diver delete),
  `created_at`, `hlc`, unique on (`diver_id`, item id). Same shape as
  `trip_hides` / `site_hides` and `equipment_shares`.
- The two forms are mutually exclusive. Choosing Everyone sets `is_shared = 1`
  and deletes (tombstones) the item's share rows; choosing specific profiles
  sets `is_shared = 0` and writes exactly the chosen rows; choosing none
  clears both. A reader that meets both (possible after a sync race) treats
  the item as Everyone.
- Visibility for profile P becomes: owner is P, OR `is_shared`, OR a share row
  for P, OR (sites only) a library membership; AND not hidden by P. This goes
  into `VisibilityFilter.applyToTrips` / `applyToDiveSites` and the raw-SQL
  fragments (`ownerOrSharedSql`, `ownerOrSharedOrLibrarySql`, `sqlFragment`),
  so every list, search, map, picker, the query-language name index and trip
  auto-assignment follow it. Lookups by id stay unfiltered, as today.
- The owner rules from #2675 (`shared_item_policy.dart`) are unchanged: a
  profile a trip is shared with may edit its fields and attach its own dives,
  sees "Shared by {owner}", and gets "Remove from my profile" instead of
  delete.
- Sync compatibility: the tables are additive, so the sync floor does not
  move. An older peer ignores the share rows and sees a specifically shared
  item as private (`is_shared = 0`), so it never shows it to the wrong
  profile. Known risk, accepted: deleting the owner's profile on an older
  build treats such an item as private, deletes it and unlinks other
  profiles' dives, and the tombstones sync. Profile deletion is rare and the
  fix there is to update the app; this does not justify raising the floor.

## Behaviour details

- **Unticking a profile** removes its share row and leaves any hide that
  profile made in place, matching today's Everyone to Not shared path
  (`ProfileHidesRepository.hiddenItems` keeps a hide on an item the profile
  can no longer see, and the Hidden page leaves it out). A later re-share
  therefore keeps the item hidden for a profile that removed it. The Hidden
  page's query must count a share row as "can see", so it lists a hidden item
  that is shared with that profile specifically.
- **Site merge:** the share rows of the sites merged away are carried onto
  the surviving site (deduplicated, and dropped for the survivor's owner)
  unless the survivor is shared with Everyone, so a profile whose dives were
  at a duplicate still sees the site those dives now point to. The merge's
  undo snapshot records the moved rows and restores them.
- **Diver delete (user's decision):** a trip or site the deleted profile
  shared with specific profiles is handed over, not deleted. Its new owner is
  one of the profiles it was shared with: the one whose share row is oldest
  (`created_at`, then `id` as a tiebreak). That profile's own share row is
  removed and the other share rows stay, so every remaining recipient keeps
  access and every dive stays linked. Everyone items keep today's rule (first
  other profile). Share rows naming the deleted profile cascade with it. As
  today, the new owner's own hides of a handed-over item are cleared.
  `deleteDiverWithReassignment` currently selects only `is_shared = 1`; it
  must also select items with share rows, and its result counts include them.
- **Diver merge:** share rows are repointed to the surviving profile and
  deduplicated; a share row naming the item's owner is dropped.
- **Bulk share adds, never removes (user's decision).** From a list selection
  or from Settings, the picker starts empty and adds what is chosen to each
  item: ticked profiles gain a share row (an item already shared with
  Everyone stays Everyone and is left alone), and choosing Everyone makes
  each item Everyone. Choosing nothing does nothing. No bulk path takes an
  item away from anyone, so none needs the unshare confirmation; narrowing
  is done per item. Bulk share acts only on items the active profile owns;
  others are skipped and counted in the snackbar, as equipment bulk share
  does ("skipped N you do not own").

## UI

- **Trip detail page and site detail page:** a "Shared with" row, modelled on
  `equipment_sharing_row.dart`, showing "Not shared", "Everyone", or the
  profile names. For the owner it opens the picker; for others it is replaced
  by the existing "Shared by {owner}" line.
- **Picker ("Share with"):** an Everyone option at the top, then a checkbox
  per other profile. Everyone and the per-profile boxes are mutually
  exclusive: ticking Everyone clears the boxes, ticking a box clears
  Everyone. Body text in the spirit of `equipment_sharing_dialogBody`: who
  can do what, and that only the owner can change it. Shown only with two or
  more profiles, as sharing is today.
- **Trip and site edit pages:** the "Share with all dive profiles" switch
  becomes the same "Shared with" row and picker, also for a new trip or site.
  The existing unshare confirmation is shown when a save would take the item
  away from profiles that could see it.
- **Trip list and site list selection:** a "Share with..." action opening the
  picker for the selected items.
- **Settings > Shared data:** "Share all my trips" and "Share all my sites"
  become "Share all my trips..." and "Share all my sites..." and open the
  picker for every item the profile owns. Their confirmation text (today
  `settings_shareAllTrips_confirm` / `settings_shareAllSites_confirm`) says
  how to change one later: open it and change "Shared with".
- All new and changed strings in all 11 languages.

## User docs

- `docs/user/trips.md` and `docs/user/dive-sites.md`: sharing with Everyone or
  chosen profiles, who owns a shared item, what a profile it is shared with
  can and cannot do, "Remove from my profile", and how to stop sharing.
- `docs/user/diver-profile.md`: the family example from #2151 in a short
  paragraph, linking to the above.
- `docs/user/settings.md`: Shared data, including the "Share all..." pickers
  and "Hidden from this profile".

## Constraints

- Schema change through the ladder in `lib/core/database/migrations/` plus a
  `beforeOpen` backstop in a part file; never a new table or rung in
  `database.dart`. Tables live in `lib/core/database/tables/`.
- Both tables sync as parent-gated children of trips and sites, wired through
  the serializer, `SyncService` and `SyncRepository` like `trip_hides`.
- Backup/export and import must carry the new tables like the hides tables.
- TDD; files 200 to 400 lines, 800 max; `test/architecture/` and
  `test/shared/` guards must pass.

## Left to the builder

- Exact repository API shape (one `setSharing(itemId, everyone|profiles)`
  call versus separate calls), provider names and widget split.
- Whether the picker widget is shared with equipment's or a new one.
- String keys and wording, within the meaning above.
- Migration rung number (the next free one at build time).

## Calls made without asking

- Sites get per-profile sharing alongside trips, because both share one
  ownership policy, one hide model and the same UI flows.
- "Everyone" stays the `is_shared` flag rather than becoming a share row per
  profile, so existing data and older peers keep working unchanged.
- Unticking someone never unlinks their dives.
- "Share new sites and trips by default" stays Everyone.
- Unticking a profile keeps its hides, as unsharing does today.
- A site merge carries the merged-away sites' share rows onto the survivor.
- The older-build profile-delete risk is recorded, not guarded.
