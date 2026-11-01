# Gear lent to buddies

Issue: #3790. Release: v1.8.4.

## Why

A diver who manages gear for a family, a club or students wants to record who
has a piece of gear. Today they can move an item to a Person place and mark it
Loaned Out, with the date and a note in the move history. But a Person place is
only a typed name. The same person can exist as a buddy and, separately, as a
place, and a buddy's page cannot answer "what of mine does Anna have?"

So a Person place can point at a buddy, lending starts from either the item or
the buddy, and the buddy's page lists the gear with them and takes it back.

The issue also proposed an optional "Used by" field. That is left out: a family
member's everyday gear sits at their Person place with its status left Active,
which covers the need without a second person concept beside location.

## How often this happens

Only for divers who look after gear for other people. The request comes from
one forum post by a new user. Most divers never lend anything, and most buddies
in a logbook will never hold gear. That is why this reuses the place and move
machinery, adds one column, and shows a section only on buddies who hold
something.

## Goals

- A Person place can link to a buddy. The link is optional, and can be added or
  removed later by editing the place.
- Gear can be lent from the item, through the existing Move flow, and from the
  buddy's page. Both pick up that buddy's place, or create one.
- A buddy's page lists the gear with them now, and takes it back.
- An item's page says which buddy has it, and opens that buddy.

## Non-goals

- A "Used by" field, or any permanent-user concept separate from location.
- Loan due dates, overdue reminders or notifications.
- A list of past loans on the buddy page. The item's move history keeps them.
- A loans report. The status filter, location filter and group by location
  already give "what is on loan" and "what does this person have".
- Matching existing Person places to buddies by name. A diver links one by
  hand from the place's edit dialog.
- New CSV or UDDF fields. Import and export keep using the place name.
- Changes to the demo data seeder.

## Anti-goals

- A diver losing a place, or a place's move history, because a buddy was
  deleted, merged away, or edited on an older device.
- A status changing by itself. Moves only ever offer a status.
- An empty section or row on a buddy who holds no gear.
- Gear coming back from a loan still reading Loaned Out because no prompt
  appeared.

## Decided by the maintainer

| Decision | Choice |
| --- | --- |
| Scope | Buddy link and buddy page section. No "Used by" field |
| Where lending starts | From the item and from the buddy page |
| The Loaned Out prompt | Stays on every lend, from both places |
| Family gear | Lent the same way, answering No to the prompt, so it stays Active |
| Loaned Out gear moved to No location or an Other place | Offered Active, for every item, linked to a buddy or not |

## Behaviour

Choices marked *(call)* are the designer's and are open to change in review.

### Lending from the item

`equipment_location_picker_sheet.dart` gains a row, **Lend to a buddy**, between
New place and No location. It shows only when the picker is opened from the Move
sheet, which covers the item's Move button, bulk Move from the Equipment list and
Move all on a place page. The picker's other two callers, the new item form
(`equipment_location_field.dart`) and editing a past move
(`location_move_edit_dialog.dart`), hide it *(call)*: neither runs the status
prompt, and the maintainer decided that prompt stays on every lend.

Tapping it opens a single-select list of the diver's buddies, the same list
`allBuddiesProvider` gives the dive buddy picker, with the existing Add New
Buddy button (`/buddies/new`). This is how a student who is not a buddy yet gets
one *(call)*.

Picking a buddy closes the picker with that buddy as its pick. The Move sheet
shows their name and continues as today: date, note, the parts prompt, the status
prompt. The buddy resolves to a place when the Move sheet is confirmed, so
cancelling at any point leaves nothing behind. The resolve rule, shared with the
buddy page:

1. The diver's non-archived Person place linked to this buddy. If several, the
   most recently updated.
2. Otherwise a new place: kind Person, name copied from the buddy, linked to the
   buddy. An archived linked place is left alone *(call)*.

### Lending from the buddy page

**Lend gear** appears in the buddy page's actions menu, in both the full page
and the embedded master-detail header, so it is reachable when the buddy holds
nothing. It also appears in the header of the gear section when that shows
*(call)*.

It opens `EquipmentPickerSheet` in multi-select mode, leaving out Retired, Sold
and Wanted gear and gear already at a place linked to this buddy. On confirm it
opens the same Move sheet with the buddy already chosen: date and note, then the
parts prompt and the status prompt.

### The Loaned Out prompt

Unchanged. Moving to a Person place offers Loaned Out, and the diver confirms.
Answering No is how a family member's gear stays Active.

### Coming back through Move

`offeredStatusAfterMove` gains one rule: an item that is Loaned Out and moves to
No location or an Other place is offered Active. Any other status still gets no
offer for those targets. This applies to every Loaned Out item, whether or not a
buddy is linked, and needs no knowledge of where the item came from. It reaches
the item page's Move, bulk Move and a place page's Move all through
`EquipmentMoveFlow`. The diver confirms, as with every offer, so gear moved while
still out can answer No.

### New place and edit dialog

`equipment_location_edit_dialog.dart` follows the dive center field. When Type
is Person, a Buddy field appears under it, showing "None" or the buddy's name,
with a way to clear it.

- Picking a buddy fills Name when Name is blank, or still holds the name the
  last pick filled in. A name the diver typed belongs to them.
- Changing Type away from Person hides the field and clears the link on save.
  Only a change of type does, as for dive centers.
- Saving a Person place with no buddy is allowed, and stays the normal case for
  someone who is not a buddy.
- Several places may link to one buddy *(call)*. This also happens after a merge.
- Renaming a buddy does not rename the place *(call)*.

### Item page

`equipment_location_card.dart`: when the current place links to a buddy
available on this device, the title reads "With {buddy name}", using the buddy's
current name, and the row opens the buddy. The "Since {date}" line and the note
are unchanged. History rows keep showing the place name.

### Place page

`equipment_location_detail_page.dart` gains a Buddy row under the kind row,
showing the buddy's name and opening their page. No row when the place is
unlinked, or when the buddy is not available on this device.

### Buddy page

`buddy_detail_page.dart` gains a section titled **Gear with {name}**, between the
stats section and Notes *(call)*, in a Card like the page's other sections. It is
not built at all when the list is empty, its surrounding spacing included.

- It lists gear whose current place links to this buddy, from `itemsAtPlaces`
  and `currentEquipmentLocationsProvider`, sorted by name. Archived places count:
  the gear is still with them.
- Each row shows the item's name, its localized type, and "Since {date}" from
  the current move. An item whose status is Loaned Out also shows that status.
  Other statuses show nothing, so family gear reads plainly. The place name is
  added only when the listed gear sits at more than one place.
- Tapping a row opens the item.
- Each row has a **Returned** action. The section header has **All returned**
  when there are two or more rows *(call)*.

### Returning gear

**Returned** and **All returned** are one flow over a list of items.

A short sheet asks for the date, default today, and an optional note, and says
where the gear is going: the place name when all items share one, otherwise
wording that each goes back where it was *(call)*. To send gear somewhere else,
the diver uses Move as usual.

Each item goes back to its previous place: walking its moves newest first, the
first move not at a place linked to this buddy.

- If that move has a null location, or there is no such move, the item goes to
  No location.
- If that place was archived or deleted since, the item goes to No location
  *(call)*.

The sheet has no time row, so the move time comes from `resolveMovedAt`, which
makes an earlier day local noon. An item's current place is its newest move, so a
return logged for the day of the loan could land before it and leave the item
with the buddy. For each item, a return's time is never earlier than that item's
current move *(call)*. An equal `moved_at` still ranks newer, because moves tie
break on `created_at`. This applies per item, so **All returned** works across
mixed loan dates.

Parts are not asked about separately when they are in the list. For a single
**Returned** on an item whose parts are at the same buddy, the parts prompt
appears as usual, and each part goes back to its own previous place, which is
normally the parent's because they moved together.

After the moves, items that are Loaned Out are offered Active, once, whichever
place they went to. This differs from `offeredStatusAfterMove`, which offers In
Service for a Service shop and nothing for another Person place; the return flow
must not use it. Items with any other status are left alone, with no prompt. One
return shows one prompt, however many destinations it covers.

### Deleting a buddy

The place stays, with its name, type, notes and history. Only the link clears.
The gear stays at that place, so it now shows on the place page and on no buddy
page.

### Merging buddies

Places linked to a merged-away buddy move to the survivor, keeping their names.
The survivor can end up with several places, which the section handles. Undo
restores each place's original link.

## Data

`equipment_locations.buddy_id`: text, nullable, foreign key to `buddies(id)`,
`ON DELETE SET NULL`.

- Schema v334 at time of writing: open PRs #4080 and #4028 already claim v333.
  Renumber if another PR ships that version first. Rung in `migrations/ladder/rungs_v231_onward.dart`, an idempotent column
  assert in `migrations/helpers/equipment_location_migrations.dart`, re-asserted
  from `before_open_child_columns.dart`. Never in `database.dart`.
- No backfill, and no existing place changes.
- The Drift table in `tables/equipment_location_tables.dart` gains the column,
  referencing `Buddies` from `tables/buddy_tables.dart`.
- `EquipmentLocation` gains `buddyId`, with `copyWith` able to clear it to null.
  `props` includes it.
- `EquipmentLocationRepository.createLocation` and `updateLocation` carry it.

The buddy page reads the link alone, so a place an older device retyped keeps
showing its gear.

## Sync

- The column travels in the row's `toJson`.
- **Older devices.** A record from an older build has no `buddyId` key, and that
  must not read as an unlink. `_withLocalForOmitted` (#2553) already keeps the
  local value for an omitted key, and treats a key present with a null value as
  a real unlink. No new code is needed; tests pin it for this column.
- Add `(field: 'buddyId', parent: 'buddies', nullable: true)` to the
  `equipmentLocations` entry in the parent table in `sync_service.dart`, so a
  place whose buddy is gone arrives with the link cleared rather than skipped.
  `buddies` already applies before `equipmentLocations`.
- `conflict_reference.dart` already maps `buddyId` to `buddies`. Add a conflict
  label if the catalogue's guard tests require one.

## Unlink paths

`ON DELETE SET NULL` protects the delete, but a local SET NULL reaches no peer.
Each path below clears the link explicitly, stamps `updated_at`, and marks the
place pending, in the caller's transaction, before the buddy is deleted. One
helper serves them, following `clearEquipmentLocationCenterLinks`:

- `BuddyRepository.deleteBuddy`.
- `BuddyMergeRepository.bulkDeleteBuddies`.
- `_deleteIfUnlinked` in `buddy_conversion_repository.dart`.
- Diver deletion in `diver_repository.dart`, next to the existing
  `clearEquipmentLocationCenterLinks` call and after
  `retireDiverEquipmentLocations`, for places that survive their diver.
  `diverLibrarySteps` deletes the diver's buddies after that point.

Buddy merge is a repoint, not an unlink. `_mergeBuddiesInner` updates each place
linked to a duplicate, stamped and marked pending, inside its transaction, and
`BuddyMergeSnapshot` records each place's original buddy. `_undoMergeInner`
restores them the same way.

Diver merge moves buddies and places together by `diver_id` and drops no buddy,
so it needs no change.

## Localization

New strings in every ARB file (11 locales), translated, not English copies: Lend
to a buddy, the Buddy field and its None value, With {name}, Lend gear, Gear with
{name}, Returned, All returned, and the return sheet's wording.

## Documentation

`docs/user/equipment.md`, Locations section, and the buddies user doc: lending to
a buddy, the buddy page section, returning gear, and recording a family member's
gear by answering No to the Loaned Out prompt.

## Tests

- Repository: create, update and clear the link.
- Migration: column added, idempotent, existing places unchanged.
- Sync: record with the key, with a null value, and with no key at all, through
  both apply paths; a buddy missing on arrival clears the link.
- Unlink: each path keeps the place and marks it pending.
- Merge: links move to the survivor, marked pending; undo restores them.
- The resolve rule: reuses a linked place, skips archived, creates otherwise, and
  creates nothing when the Move sheet is cancelled.
- The previous-place rule: skips this buddy's places, null, archived and no prior
  move all give No location.
- `offeredStatusAfterMove`: Loaned Out to No location or Other offers Active,
  every other status still offers nothing there.
- Return flow: Loaned Out is offered Active for every destination kind, other
  statuses get no prompt, one prompt across several destinations, a return dated
  before the loan still lands after it.
- Picker: the Lend to a buddy row shows from the Move sheet and is hidden on the
  new item form and when editing a past move.
- Picker: the row reaches the buddy list and returns a place.
- Buddy page: section lists linked gear, hides when empty, Lend gear reachable
  when empty, status shown only for Loaned Out, place named only when several
  link to the buddy.
- Item card and place page: buddy shown and opens the buddy, absent when unlinked
  or unavailable.
- Dialog: field appears only for Person, name fills only when blank, type change
  clears the link, saving with no buddy works.

## Left to the builder

- Exact widget split and file names, with `buddy_detail_page.dart` at 685 lines
  and the 800 line limit in mind.
- Provider shape for "gear with this buddy" and for each item's current move
  date, which `currentEquipmentLocationsProvider` does not carry.
- Wording of the strings, within the labels above.
