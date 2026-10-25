# One entry per device: dive computers and transmitters as Equipment

Release: v1.8.3. Status: design agreed in chat, 2026-10-25.

## Intent

A diver's dive computer and each air-integration transmitter should exist once
in Submersion, as an Equipment item, and that one item should carry every
control the app has for the device. Today each has two entries with the
controls split between them:

- A dive computer has a registration (`dive_computers`, managed on
  `/dive-computers/:id`) and a gear twin (`equipment` of type `computer`,
  managed on `/equipment/:id`). Download, re-import, reparse, connections,
  clock sync, favourite, merge and stats live on the first; service, batteries,
  purchase, photos, documents, location, passport, clone and transfer live on
  the second. The computer page links to the gear item; nothing links back.
  A rename on one side never reaches the other, and deleting the gear item
  silently and permanently unlinks it.
- A transmitter has a registry entry (`transmitters`, managed under
  Settings > Manage > Transmitters) and, optionally, a gear item of type
  `transmitter` that nothing creates automatically.

Discovering a new dive computer already creates its gear item (the v175 gear
twin, issue #1320). The user wants the same for transmitters, and wants the
gear item to become the only entry for both.

## Decisions made by the user

1. **The Dive Computers list stays,** and its rows are Equipment items. It lists
   every Equipment item of type `computer`, including one added by hand that has
   never connected (a backup computer used in gauge mode, for example).
2. **The Transmitters list stays the same way:** it lists every Equipment item of
   type `transmitter`, and the equipment entry is the only entry.
3. **A new transmitter seen in a download creates its Transmitter item
   automatically,** as discovering a dive computer creates its item.
4. **The nudge stays.** A transmitter item with no cylinder set up still raises
   the post-download notice and the data-quality finding, and the finding's fix
   opens that item.
5. **Upgrade of a computer whose gear twin was deleted:** use the same matching
   discovery uses. If exactly one existing `computer` item matches, link the
   computer to it; otherwise create a new Active item for it. Nothing special
   (no review prompt, no guessed Retired status) for what is expected to be a
   small group of divers.
6. **Matching falls back to brand and model** when the device has a serial and
   no item has that serial: the one item with the same brand and model and a
   **blank** serial is adopted, and the device's serial is written onto it. Any
   status except Wanted is a candidate (today only Active items are). This
   applies to discovery and the upgrade alike.
7. **Transmitter items go on dives' gear lists,** as dive computer items
   already do: every dive carrying a transmitter's key gets the item in its
   gear, from downloads going forward and from the upgrade for past dives.

## Goals

- Tapping a dive computer or a transmitter anywhere (its list, a dive's gear
  list, the equipment list) lands on one page: its Equipment detail page.
- That page has every control the old pages had.
- Every registered computer and every registry entry is linked to exactly one
  Equipment item, at all times, including right after upgrade and right after
  sync applies a peer's rows.
- One name: the item's name is the computer's name and the transmitter's label.
- One delete: deleting the item removes the device record too, after a warning
  that says so.

## Non-goals

- Folding the `dive_computers` or `transmitters` table into `equipment`. Dives,
  data sources, profile series, tanks and gas switches all reference
  `dive_computers.id`; rewriting those references on every synced device is a
  large, risky migration the screens do not need. The two tables stay as device
  records behind the item; the user sees only the item. (Builder's call,
  recorded here so it is not re-litigated: the user was told and did not object.)
- An equipment-merge feature (see Merge below).
- Changing what a download, reparse or re-import writes to a dive's tanks for a
  transmitter the diver has not set up (see "Set up" below). Adding the
  transmitter item to the dive's gear (decision 7) is the one intended change.

## Anti-goals

- A second item appearing for a device the diver already has as gear.
- A computer or transmitter, with its dives and history, that no screen reaches.
- A guessed cylinder size, role or tank name written onto a transmitter, and
  from there onto dives by the registry matcher or "Apply to existing dives".
- The unknown-transmitter nudge going silent because every serial is now
  registered automatically.

## The design

### Data model

- `dive_computers.equipment_id` becomes a required link in practice (the column
  stays nullable in SQLite; the invariant is enforced in code and by the
  upgrade). Every write path that can leave a computer without an item must
  resolve one: registration (already does), sync apply of a computer row whose
  item is missing (`SyncService.parentRefs` clears the reference today; it must
  instead resolve or mint an item after apply, see Ids below), and the upgrade.
- `transmitters.transmitter_equipment_id` (the transmitter's own gear item)
  becomes required the same way. `transmitters.equipment_id` keeps its current
  meaning, the cylinder the transmitter feeds, and stays optional.
- **"Set up" marker.** `transmitters` gains a boolean, set false on rows the app
  creates automatically and true on every row the diver saves from the
  Transmitter section (and on every existing row at upgrade: those were all
  made by hand). The registry matcher (`applyTransmitterRegistry`) and "Apply
  to existing dives" use only set-up rows, so an auto-created row never stamps
  its placeholder label as a tank name or overrides the computer's reported role
  (#2595). Auto-created rows still count as known for the gear link (decision
  7) and for the item's dive count. Builder's call on the column name; it syncs.
- **Cardinality.** One item can stand behind more than one device record, and
  that is the normal shape for a single physical device:
  - A computer registered twice (two rows, same serial) shows as one item. The
    item page acts on the most recently downloaded row, and the existing
    duplicate-serial banner and Merge action on that page resolve the
    duplicate.
  - One transmitter can have several registry keys: a serial, or a
    (computer, channel) pair per computer that reports channels only. All keys
    naming the item are shown on its Transmitter section.
- **Role and cylinder are per item.** The Transmitter section shows one role,
  one cylinder link and one cylinder spec; saving writes them to every registry
  row of the item. Where an item's rows already disagree at upgrade, nothing is
  rewritten; the section shows the most recently updated row's values and the
  first save aligns them.
- **Serial number.** For a transmitter item, the registry key's serial is
  authoritative for matching. When an item is created from a serial, its
  `serial_number` is set to it. On upgrade, an item with a blank serial gets the
  key's serial; an item whose serial disagrees with its key is left alone, and
  the existing gear-serial mismatch finding (#3367) surfaces it.

### Matching

`matchGearTwin` (`lib/core/database/dive_computer_gear_identity.dart`) today:
with a serial, serial only (Shearwater hex and decimal agree); without one,
exact brand and model, then the looser `computerNamesAgree`; same diver;
adopt only on exactly one match. `resolveGearTwin` passes only Active items.

Changes (decision 6):

- When the device has a serial and no candidate matches it, fall back to the
  brand-and-model tiers, restricted to candidates whose serial is blank. A
  candidate with a different non-blank serial is never adopted.
- Candidates are every status except Wanted (`EquipmentStatus.wanted`,
  #2025), not only Active.
- On adoption through the fallback, the device's serial is written onto the
  item.
- The item's `name` column is still not a matching input.

### Ids

The deterministic `diveComputerGearId` (UUIDv5 of the computer id) can have a
deletion record: every twin a diver deleted since v175 left one. Any re-mint
must avoid it, or a peer applying the tombstone deletes the new item again.

- A re-minted computer item's id is derived (UUIDv5, a new namespace) from the
  computer id **and** the id of the item it replaces (the tombstoned or missing
  one). Every device in a fleet derives the same id for the same generation,
  and a later deletion of that item leads to a different id next time.
- Transmitter items: derived from diver id plus normalized serial for a new
  serial key; from the registry row id plus the replaced item id for a re-mint.
- Sync apply, the upgrade and runtime registration all use these rules.
  An older peer may keep deleting twins (it still believes that only unlinks);
  on a current device that tombstone triggers a re-mint by the rule above, not a
  delete of the computer.

### Creating items

- **Dive computers:** `DiveComputerRepository.createComputer` and the other
  registration paths keep resolving through `DiveComputerGearResolver`, with
  the matching changes above.
- **Connecting a hand-added computer item.** A `computer` item with no
  registration shows a "Connect and download" action. It runs the normal
  discovery flow and binds the discovered device to *this* item: the new
  `dive_computers` row is created with `equipment_id` already set to the item,
  so the resolver neither mints nor matches. If the discovered device is already
  registered to a different item, say so and offer to open that item instead;
  do not rebind silently.
- **Transmitters:** every path that runs `applyTransmitterRegistry` (download in
  `DiveComputerAdapter`, reparse) creates, after the dives are written, a
  Transmitter item plus a not-set-up registry row for each **serial** that
  matched nothing (the existing unmatched-serial tracking). Channel-only tank
  slots never auto-create: nothing in a download says a serial-less slot is a
  transmitter, and a multi-gas dive on a computer without air integration would
  mint one item per gas. Channel-only transmitters are still added by hand.
  - Name: "Transmitter" plus the serial (for example "Transmitter 4A21F"), a
    localized string.
  - Role: the role the computer reported for that tank, else `backGas`.
    (`lastRoleForEquipment` is keyed by cylinder, so it has nothing to offer a
    new item with no cylinder.)
  - No cylinder link and no cylinder spec. Nothing is guessed.
  - Owned by the importing diver, like registry entries today.
  - Matching first: if exactly one existing `transmitter` item (any status
    except Wanted) has the same serial, the new key attaches to it instead of
    minting one.
  - The item is added to the gear of each dive that carries the serial, through
    the same `dive_equipment` path computer twins use (`DiveComputerGearLinker`
    or a sibling of it), after `DiveEquipmentDefaulter`.
  - The builder should also check the file-import paths (UDDF, universal
    import) that write `dive_tanks.transmitter_serial`; the upgrade pass below
    is the safety net for any it misses.

### Upgrade (one ladder rung)

Runs once, in the ladder only (never in a `beforeOpen` backstop, for the same
reason as v175: a rerun would resurrect what the diver deleted after it). The
rung cannot call `DiveComputerGearResolver` or `SyncRepository` (they reach
`DatabaseService.instance`); it applies the same matching and id rules in SQL or
in a database-scoped helper, as `dive_computer_gear_backfill.dart` does for
v175.

1. **Computers.** For each `dive_computers` row with no `equipment_id`, or
   whose item no longer exists: match (with the changes above), else mint a new
   Active item; link it. Link a re-minted item to the computer's dives in
   `dive_equipment` (the union of `dive_data_sources.computer_id` and
   `dives.computer_id`, as the v175 backfill does).
2. **Name and notes.** For each computer and its item: the name of whichever
   row was updated later wins and is written to both. Notes: if the item's notes
   are blank, it takes the computer's; if both have text and differ, the
   computer's notes are appended below the item's; if equal, nothing changes.
   (v175 seeded twins with blank notes, so "item wins" would erase what divers
   typed in the old computer edit dialog.)
3. **Registry rows.** For each `transmitters` row with no
   `transmitter_equipment_id`, or whose item no longer exists: match a
   `transmitter` item by serial (exactly one, any status except Wanted),
   else mint one; link it. Mark every existing row set up.
4. **Unassigned serials.** For each serial currently reported by
   `getUnassignedSerials` (seen on downloaded tanks, in no registry entry):
   create the item and a not-set-up registry row as a download would. The
   "Unassigned" list then has nothing left in it and is removed.
5. **Transmitter gear on past dives.** For every registry row with a serial,
   add its item to the gear of each dive whose tanks carry that serial.

Whether the rung's writes are HLC-neutral like v175 or staged for sync is the
builder's call, provided every device converges on the same rows. Steps 4 and 5
depend only on synced inputs; steps 1 to 3 depend on which items exist locally,
which a peer on an older schema could differ on, so staging those writes is the
safer default.

### Screens

- **Dive Computers list** (`/dive-computers`, `DeviceListPage`): reads Equipment
  items of type `computer` for the active diver, joined to their registration
  when there is one. A row shows the item's name and status; when registered,
  also the dive count and last download, and the download shortcut, as today.
  "Add computer" keeps opening discovery; adding one by hand is available from
  the same place (opens `/equipment/new` with type `computer`). Selection mode,
  bulk delete and merge keep working, acting on the registrations behind the
  selected items. Tapping a row opens `/equipment/:id`.
- **Transmitters list** (`/transmitters`): reads Equipment items of type
  `transmitter`, showing name, the key (serial or computer plus channel), role,
  and the cylinder it feeds or a "No cylinder set up" hint. The Unassigned
  section is removed. "Add" opens `/equipment/new` with type `transmitter`.
  Tapping a row opens `/equipment/:id`.
- **Equipment detail page** gains, gated on type:
  - **Dive computer section** (type `computer`), holding what
    `DeviceDetailPage` has today: favourite, download, the connections card,
    re-import all, reparse all, discard raw data, the clock-sync card, stats
    (dives imported, last download), device info (manufacturer, model, serial,
    firmware), the transmitters row, and the duplicate-serial banner with
    Merge. For an unregistered item it shows only "Connect and download".
  - **Transmitter section** (type `transmitter`): its keys (serial or computer
    plus channel), role, the cylinder it feeds with that cylinder's size,
    working pressure, material and preset, and "Apply to existing dives". The
    fields and validation of `TransmitterEditPage` move here, editable in place
    or through an edit sheet (builder's call). Saving marks the item's rows set
    up.
  - Both sections are new widget files; `equipment_detail_page.dart` (1163
    lines) and `device_detail_page.dart` (1055) are already past the 800-line
    guard, so nothing is added inline to either.
- **Old routes.** `/dive-computers/:computerId` (pushed from 4 places:
  `transfer_page.dart:770`, `dive_detail_page.dart:4384`,
  `device_list_page.dart:300`, `device_detail_page.dart:850`) opens the item's
  `/equipment/:id` instead; deep links and back stacks must keep working. Its
  child route `:computerId/download` must keep reaching the download wizard,
  so the redirect cannot sit on the parent route as it is; restructure the
  routes (for example make the detail path a redirect-only sibling) so only the
  bare detail path redirects. `/transmitters/new` and `/transmitters/:id/edit`
  redirect to the equipment equivalents. `/dive-computers/discover` and the
  download route are unchanged: they are flows, not entries. `DeviceDetailPage`
  and `TransmitterEditPage` are removed once nothing reaches them.
- **Edit.** The old computer edit dialog (name and notes) goes away; the
  equipment edit page already has both. After the upgrade aligns them once, the
  item's name and notes are the copy the diver edits; every item save writes
  them to the computer row too, so anything that still reads
  `dive_computers.name`, such as a data-source label, shows the same name.

### Delete

- Deleting a `computer` item deletes its registration(s) through
  `DiveComputerRepository.deleteComputer` (dives, profiles and data sources are
  kept, as today), then the item. The confirmation says that the download
  history and the "only new dives" marker go with it, and that connecting the
  device again will create it again.
- Deleting a computer registration (by item delete or by merge) also handles
  its channel-only registry keys, whose `dive_computer_id` is ON DELETE SET
  NULL and would otherwise become unmatchable `(null, channel)` rows:
  - on merge, the keys move to the survivor (skipping any that would collide
    with a key the survivor already has, which are deleted);
  - on delete, the keys are deleted and tombstoned; the transmitter item stays
    as gear, and if it has no keys left it is simply a hand-added transmitter.
- Deleting a `transmitter` item deletes its registry keys, then the item. The
  confirmation says a later download carrying the serial will create it again,
  and suggests Retired as the way to keep it out of the way.
- Deleting from the Dive Computers or Transmitters list does the same as
  deleting the item.

### Merge

Merging duplicate computers keeps today's behaviour: dives, sources and gear
links move to the survivor, and the duplicate's gear item is left in place
because it may carry service history. Under the new rules that leftover is an
unregistered `computer` item in the Dive Computers list, so the merge
confirmation says so and the diver can delete it. Channel keys move as above.
Merging is rare; no equipment-merge feature is built.

### Nudge

- A transmitter is **set up** when its registry row is marked set up and it has
  a cylinder link or a cylinder spec (a volume). A diver who chose a preset
  without linking a cylinder item counts as set up, as today.
- The import summary notice (`ImportNoticeKind.unknownTransmitter`) counts dives
  carrying a transmitter that is not set up, newly created or not.
- `unknown_transmitter_detector.dart` changes its test from "serial not in the
  registry" to "the matching registry row is not set up". Its message,
  "Transmitter {serial} is not assigned to a cylinder", stays. Its repair opens
  the item's Transmitter section instead of the Assign flow.

## Constraints

- Schema 314 today. The rung body goes in
  `lib/core/database/migrations/ladder/`; the version bump touches only
  `currentSchemaVersion` and `migrationVersions` in `database.dart` (no table or
  rung code there).
- Every write is staged for sync where the existing code stages it (see the
  `deleteComputer` and `unlinkFromDeletedEquipment` comments for why FK cascades
  are not enough).
- `test/architecture/` and `test/shared/` guards scan all of `lib/`.
- New strings go through the ARB files.
- Screenshots of every changed screen, before and after, for the PR.

## Left to the builder

- Exact strings, layout of the two new sections, and whether the Transmitter
  section edits in place or in a sheet.
- How the Dive Computers list provider joins items and registrations.
- Whether the upgrade rung's writes are staged or HLC-neutral, within the
  convergence rule above.
- The new UUIDv5 namespaces and the set-up column's name.
- How to restructure the `/dive-computers/:computerId` routes.
- Fixing the misplaced `_LinkedGearRow` doc comment wherever that code lands.

## Calls made during design review (not the user's; check them)

- Auto-created registry rows are "not set up" and ignored by the registry
  matcher and "Apply to existing dives" until the diver saves them.
- Auto-creation is serial-only; channel-only transmitters are added by hand.
- Name at upgrade: the later-updated row wins. Notes: merged, never dropped.
- "Set up" means a cylinder link or a cylinder spec, not only a link.
- Role and cylinder are per item; a save writes all of the item's rows.
- Re-minted ids are derived per generation (device plus replaced item), so a
  tombstone never deletes the replacement, including tombstones from older
  peers.
- Channel keys move to the survivor on merge and are deleted with their
  computer on delete.
