# Equipment seller: buddy, dive centre or typed name

Source: discussion #4118, suggestion 2 ("Equipment purchased from private
individuals"). Release v1.8.7.

## Intent

Divers buy a lot of second-hand gear directly from other divers. The gear
purchase record today has a free-text **Retailer** field (issue #1517, an
`equipment_attributes` row with key `retailer`), which reads as a shop and
cannot point at anyone already in the app. The diver wants to record who sold
an item, a shop or a private person, picking a buddy (or a saved dive centre)
instead of retyping the name, so the purchase and ownership history stays
accurate without duplicate contacts.

## Goals

- One **Seller** field in the gear item's Purchase Information that holds one
  of: a linked buddy, a linked dive centre, or a typed name.
- Picking a buddy or a centre is done from suggestions while typing.
- The gear page shows the seller; a linked seller opens that buddy or centre.
- A buddy's page lists gear bought from that buddy; a dive centre's page lists
  gear bought there.
- History survives: deleting a linked buddy or centre keeps the seller's name.

## Non-goals

- No resale or ownership chain ("sold to Lars"). One seller per item.
- No new contact type: a stranger stays a typed name; no "create buddy from
  seller" action.
- No change to the diver-profile ownership log (`equipment_ownership_events`,
  issue #2046), which records share and transfer between profiles.
- No change to how loans and places link buddies (issue #3790).

## Anti-goals

- A typed seller that used to read fine must never go blank or change.
- A deleted buddy or centre must never erase the seller from an item.
- No duplicate buddy is created anywhere in this flow.

## Decisions (made with the maintainer)

1. **Seller kinds:** buddy, dive centre, or typed name. Shops that are not
   saved dive centres stay typed names.
2. **Editor:** the Retailer text field becomes **Seller**, a text field with
   suggestions (option A of three mockups). Typing shows matching buddies and
   dive centres, each marked with its kind, plus "keep as typed". Picking one
   turns the field into a chip (icon, name, clear button); clearing the chip
   returns an empty text field.
3. **Reverse view:** the buddy page shows "Bought from <name>"; the dive centre
   page shows "Bought here". Each is hidden when empty, like the existing
   "Your gear here" (`GearHereSection`) and the buddy's lent gear
   (`BuddyGearSection`).
4. **Storage (approach 1):** two nullable link columns on `equipment`,
   beside the existing `retailer` attribute row, which keeps the seller's name.

## Approaches considered

| | Approach | Trade-off | Outcome |
|---|---|---|---|
| 1 | `equipment.seller_buddy_id` and `equipment.seller_dive_center_id`, SET NULL, `retailer` text keeps the name | Mirrors `equipment_locations.buddy_id` / `dive_center_id` exactly: one rung, same sync rules, cheap reverse lookups. "At most one link" is held by the app, not the schema. | **Chosen** |
| 2 | A generic reference column on `equipment_attributes` | More general than needed; sync FK repair would have to learn attribute rows. Encoding the id in the text value would hide it from sync entirely. | Dropped |
| 3 | A new seller or purchase table, one per item | Room for a future ownership chain nobody asked for; a new synced child entity for the same screen. | Dropped |

## Design

### Data

- New columns on `Equipment` (`lib/core/database/tables/equipment_tables.dart`):
  - `sellerBuddyId` text, nullable, references `Buddies.id`, `onDelete: setNull`.
  - `sellerDiveCenterId` text, nullable, references `DiveCenters.id`,
    `onDelete: setNull`.
- One migration rung adding both columns (next free schema version at build
  time; re-check on every merge from main, since parallel PRs take numbers).
  Rungs go in `lib/core/database/migrations/`, never in `database.dart`. No
  backfill: existing rows have no link and keep their `retailer` text.
- Invariant, held in the domain and repository: at most one of the two link
  columns is set. When either is set, the `retailer` attribute holds that
  buddy's or centre's display name at the time of the write (the "name
  snapshot"). When neither is set, `retailer` is the typed seller, as today.
- `EquipmentItem` gains `sellerBuddyId` and `sellerDiveCenterId` (with
  `copyWith`, equality, mapping both ways). The existing `retailer` getter
  stays.

### Reading the seller

A small domain value (for example `EquipmentSeller`: buddy, dive centre or
typed, with id and name) resolved from the item plus the buddy and centre
lists:

- Linked and the target exists: show the target's **current** name and kind.
- Linked but the target is not on this device (not synced yet, or a dangling
  id): show the `retailer` snapshot as plain text.
- Not linked: show the `retailer` text; nothing when blank.

### Writing the seller

- Picking a buddy sets `sellerBuddyId`, clears `sellerDiveCenterId`, and writes
  the buddy's name into `retailer`. Same for a centre, the other way round.
- Typing a name, or clearing a chip, clears both links; `retailer` is the text.
- A typed name that happens to equal a buddy's name stays typed (no silent
  linking).
- Saved through the existing gear editing session (`gear_item_edit_fields.dart`,
  `gear_item_details_editor.dart`), so the item's normal save, change log and
  sync staging apply.

### Delete, merge and conversion paths

The links follow every path that already handles
`equipment_locations.buddy_id` / `dive_center_id`, because SET NULL reaches no
peer:

- **Buddy delete** (and diver delete removing their buddies): before the buddy
  goes, write the buddy's current name into each linked item's `retailer`,
  clear `sellerBuddyId`, stage the items for sync. Mirrors
  `clearEquipmentLocationBuddyLinks`.
- **Dive centre delete** (and diver delete removing their centres): the same
  for `sellerDiveCenterId`. Mirrors `clearEquipmentLocationCenterLinks`.
- **Buddy merge:** repoint `sellerBuddyId` from the duplicates to the
  survivor, refresh the snapshot to the survivor's name, and restore the
  previous links on undo. Mirrors `repointEquipmentLocationBuddyLinks` /
  `restoreEquipmentLocationBuddyLinks`.
- **Buddy conversion** (`buddy_conversion_repository.dart`): whatever it does
  with location links, the seller link does the same.

### Sync

- The columns travel with the equipment row (`SyncDataSerializer` maps for
  `equipment`).
- Add both to the FK reference map in `sync_service.dart` under `'equipment'`
  as `nullable: true` (cleared, not skipped), beside `parentEquipmentId`.
- Conflict screen: label both fields in
  `lib/features/settings/presentation/conflicts/catalogue/equipment_fields.dart`
  and resolve them to names via `conflict_reference.dart`, as other id fields
  do.

### Gear page

`equipment_detail_page_sections.dart`: the `retailer` row in the purchase block
becomes the **Seller** row, showing the resolved seller. A linked buddy or
centre shows a small kind icon and is tappable, opening that buddy or centre.

### Buddy and dive centre pages

- Buddy page: a read-only "Bought from <name>" block near the existing gear
  block. Rows: item name and purchase date (or no date), tap opens the gear
  item; retired items included and marked as retired.
- Dive centre page: the same block titled "Bought here", near
  `GearHereSection`.
- Order: newest purchase first, items without a date last.
- Both hidden when empty. With many items (a shop that sold 80), show the
  first 5 with a "Show all (n)" that expands in place.

### Labels

- `attrLabel_retailer` becomes "Seller" in English; every other locale is
  updated to its word for seller.
- New strings for the two block titles, "Show all (n)", the suggestion kind
  labels (Buddy, Dive centre), and "keep as typed".

### Profiles, sharing and transfer (builder's call, settled in the design)

Buddies and dive centres belong to one diver profile; gear can be shared with
another profile (`equipment_shares`) or transferred to one
(`EquipmentTransferService`).

- The editor suggests from the **current** diver's buddies and centres.
- A link resolves only against the viewing diver's own lists. Anywhere else
  (a shared item seen by another profile, an item after a transfer) it shows
  the `retailer` name snapshot as plain text.
- A transfer leaves the link as it is; no new step in the transfer service.
  Transferring back makes it resolve again.
- The reverse blocks list the items the current diver can see (own and shared
  with them) whose link names that buddy or centre.

### Wishlist and status (builder's call, settled in the design)

- Wishlist items (`EquipmentStatus.wanted`) keep the Seller field, as they
  keep Retailer today: it reads as where the diver means to buy.
- The reverse blocks leave wishlist items out: nothing has been bought yet.
- "Mark as purchased" keeps the seller as it is.
- In the reverse blocks, an item that has left the kit (retired, sold, lost)
  shows its status label; other statuses show none.

### Other writers of `retailer` (builder's call, settled in the design)

- The repository refuses an item with both links set.
- Whoever sets a link writes the name snapshot with it: the Seller field,
  buddy merge, and the delete paths.
- A write that changes `retailer` from outside the Seller field (an agent's
  attribute write, an import updating an existing item) is a typed seller:
  that writer clears both links. A write that leaves `retailer` unchanged
  leaves the links alone.

### Unchanged on purpose

Exports and imports (CSV, UDDF, PDF inventory, Diving Log `purchaseShop`)
keep reading and writing the `retailer` text, which always holds a name. A
renamed buddy shows its new name in the app at once; the snapshot an export
reads is refreshed on the item's next save, merge or seller delete.

## Left to the builder

- The domain type's exact name and where the resolver lives.
- Placement of the reverse blocks within each page's existing cards.
- Whether suggestions show permanently closed centres (leaning yes: the
  purchase may predate the closure).
- Agent access (`lib/features/agent_access/`): the seller name is readable
  wherever `retailer` is today; links are not agent-writable unless that falls
  out naturally of the existing rules.
- Tests: rung test, repository invariant, delete/merge/undo paths, sync map,
  resolver cases, editor suggestion and chip behaviour, the two reverse blocks
  at 0, 1 and many items.
