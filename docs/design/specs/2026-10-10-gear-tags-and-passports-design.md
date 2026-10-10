# Gear tags and passports

Date: 2026-10-10
Issue: #2652 (follows the cylinder passport program, #2333)
Release: v1.8.2

## 1. Problem

Cylinders can carry a QR label or an NFC tag that opens their passport
(`2026-09-25-smart-cylinder-passports-design.md`). Every other piece of gear
cannot. A diver with two regulators, three computers and a club's worth of
BCDs has no way to go from the object in their hand to its record: when it
was last serviced, what is due, how many dives it has done since, and which
trip it is packed for. The cylinder spec listed this as a non-goal (section 4)
and a follow-up (section 18).

## 2. Decisions

Made during the brainstorming session on 2026-10-10. Do not reopen without a
reason.

| Question | Decision |
| --- | --- |
| What a tap on own gear opens | A gear passport page, a compact page per item |
| What a tap on someone else's gear opens | A read-only snapshot from the tag, with Add to my gear |
| Cards on the gear passport | Header, service status, recent service history, usage (exposure totals), location and trip, tag |
| Carriers | NFC tags and printed QR labels, the same link on both |
| Tag spelling | A new path, `https://submersion.app/g#<payload>`; cylinders keep `/c` |
| Scan points | The equipment list (opens the passport), the dive edit Equipment section (adds the item to the dive), the trip Gear tab (packs the item) |

The new path was chosen over a type key on `/c` because every released app
would read a gear tag on `/c` as a cylinder, and its Add to my gear would
create a tank from a regulator's tag. On `/g`, an older app ignores the tag.

## 3. Goals

- Any equipment item that is not a tank can carry a passport id, printed as a
  QR label or written to an NFC tag. A scan on any supported platform opens
  its gear passport.
- The gear passport reads every fact from the system that owns it: identity
  from the equipment row, service state from the service clocks, history from
  the service records, usage from the exposure totals, location from the
  location card, trips from `trip_equipment`. It never contradicts the detail
  page or the reminders.
- A scan in the dive editor adds the item to the dive's gear; a scan on a
  trip's Gear tab packs it. Cylinder tags work in both places too.
- Gear the diver does not hold opens a read-only snapshot, which can become
  equipment when the diver now owns it.
- The tag format is documented so others can write it.
- Nothing new needs a schema rung, and everything syncs and respects the
  owner-or-sharee visibility rule through what already exists.

## 4. Non-goals

- A `/g` tag on a tank. A tank keeps the cylinder tag, page and label.
- Changes to the cylinder tag format, the cylinder passport page, fills, or
  the cylinder-only scan points (the dive tank editor and the gas blender's
  cylinder picker).
- Writing service records from a tag. A tag's last service date becomes a
  schedule baseline on Add to my gear, never a fabricated record.
- Lending, checkout or rental tracking for a fleet of tagged gear.
- Tag-specific settings or a tag inventory page.

## 5. What exists today

- `passport_id` is a curated equipment attribute
  (`EquipmentAttrKeys.passportId`) in the tank list of
  `equipment_attribute_catalog.dart`, in `AttributeGroup.system`, which the
  edit form does not render. `CylinderPassportRepository` mints it as a UUID
  v5 of the equipment id under `kCylinderPassportNamespace`, and its lookup
  `findEquipmentIdByPassportId` filters on `type == tank`. A retyped item
  keeps its id; `_nonTankCarriers` releases such leftovers when a cylinder
  links the id.
- `PassportPayloadCodec` decodes `/c` links and `submersion://c` links, total
  and never throwing. `NdefFit` and `planPassportMessage` fit a payload to a
  tag's capacity and add an Android Application Record when room remains.
- `NfcTagService` (`nfc_manager`) reads and writes NDEF on phones;
  `firstPassportUri` picks the first `/c` URI record from a message.
- `PassportLinkDispatcher` takes incoming links from `app_links` on iOS,
  Android and macOS, keeps only passport tags, drops a repeat within two
  seconds, and queues a link until a diver exists.
- `PassportScanSheet` offers camera QR (iOS, Android, macOS), NFC (phones)
  and Paste link (everywhere) and returns the scanned text.
  `openScannedTag` resolves and navigates; `scanTagMenuEntries` puts Scan on
  the equipment list.
- `printPassportLabels` builds a label PDF for selected cylinders through
  `PassportLabelPdfExportService`; other types are skipped.
- The detail page shows `PassportEntryCard` for tanks, and reusable cards for
  every type: `ServiceClocksCard`, `ExposureCard`, `EquipmentLocationCard`,
  `ServiceHistorySection`. `PassportTripCard` shows the trips an item is
  packed for.
- The dive editor adds gear through `_addGear`, which expands components; the
  trip Gear tab's `showTripGearAddSheet` applies picked items through
  `_apply`, slotting tanks on the cylinder board and packing the rest.
- The Android manifest has `/c` in an autoVerify app-link filter and an
  `NDEF_DISCOVERED` filter, and a custom-scheme filter for host `c`. iOS
  registers the `submersion` scheme and `applinks:submersion.app`, neither of
  which names a path.

## 6. The gear tag

### 6.1 URL forms

Written as `https://submersion.app/g#<payload>`. Also accepted:
`submersion://g?<payload>`, the payload in the fragment or the query of either
form, `http`, a `www.` host, and any case in scheme and host, as for `/c`.
The path must be exactly `/g` (or `/g/`). The custom scheme is never written.

### 6.2 Payload

A query string of short keys, values encoded with `Uri.encodeQueryComponent`,
keys emitted in table order so two devices produce the same string for the
same item. Only `f`, `p` and `t` are required on read.

| Key | Meaning | Example | Small-tag drop order |
| --- | --- | --- | --- |
| `f` | format version | `1` | never |
| `p` | passport id, a UUID, lower case | `8f3a5c1e-...` | never |
| `w` | date written, `YYYY-MM-DD` | `2026-10-10` | never |
| `t` | equipment type, `EquipmentType.name` | `firstStage` | never |
| `n` | name, at most 40 characters | `Apeks+XTX50` | 5th (last) |
| `b` | brand, at most 24 characters | `Apeks` | 3rd |
| `mo` | model, at most 24 characters | `XTX50` | 2nd |
| `sn` | serial, at most 24 characters | `AB12345` | 4th |
| `ls` | last service date, `YYYY-MM-DD` | `2026-03-02` | 1st |

`ls` is the date of the newest service record of any kind on the item, or
absent when there is none. A full payload is about 150 characters.

### 6.3 Parsing rules

`GearTagCodec` is total, like the cylinder codec:

- Unknown keys are ignored; `f` greater than 1 opens with the "written by a
  newer Submersion" note and the keys this version knows.
- A missing or malformed `p` rejects the tag with a reason.
- A missing `t` rejects the tag (`missingType`). An unknown `t` keeps the raw
  string; the page labels it as plain gear and Add to my gear uses
  `EquipmentType.other`.
- `t == tank` rejects the tag (`notGear`): a tank's tag is a `/c` tag.
- Text values are capped on write and on read, counting code points; an
  unparseable date is dropped.

### 6.4 Fitting

`GearTagFit` drops keys in the order above until the URI record fits the
capacity the phone reports, then adds the Android Application Record when
room remains, as `planPassportMessage` does. It never drops `f`, `p`, `w` or
`t`. An NTAG213 (144 bytes) keeps the identity, type and name and usually the
serial; NTAG215 and NTAG216 keep everything. The label payload is the full
payload.

### 6.5 Staleness

When a scan opens the gear passport, the Tag card compares the scanned tag
with the row. A service record dated after `w`, or a name, brand, model or
serial that differs from the tag, shows "Tag out of date" with Rewrite (NFC)
and Reprint (QR), as the cylinder Tag card does.

## 7. Identity and data

No schema rung, no new table.

- The `passport_id` definition moves from the tank list to
  `EquipmentAttributeCatalog.universal`, still in `AttributeGroup.system`, so
  every type holds it and the edit form never renders it.
- Minting is unchanged: a UUID v5 of the equipment id under
  `kCylinderPassportNamespace`, on the first passport open, label print or
  NFC write. A tank keeps exactly its current id.
- `CylinderPassportRepository` keeps its name (decided at plan time:
  renaming it, the namespace constant and the label printer churns about
  twenty files for no behaviour). `findEquipmentIdByPassportId` drops the
  `type == tank` filter and searches every item the diver can see, with an
  optional `type` that narrows it; `findHolderByPassportId` also returns the
  holder's type. The holder ordering (in service first, then oldest, then
  id) is unchanged. The cylinder-only scan points and the fills CSV import
  pass `type: tank`.
- `assignPassportId` treats a holder of any type alike: one still in service
  refuses the link with its name (`PassportIdInUse`); one that is not gives
  the id up. `_nonTankCarriers` and its release step are removed, since a
  retyped item is now an ordinary holder. Fills are relinked only when the
  item being linked is a tank.
- The attribute already syncs with the row and follows `VisibilityFilter`.
- The clone form seed (#3184) leaves system attributes out, so a clone
  starts untagged. Before this change it copied a tank's passport id, giving
  two cylinders one tag (follow-up found at plan time).

## 8. Reading a tag

### 8.1 Decoding

`TagLinkCodec.decode(text)` returns a sealed result: `CylinderTagLink`
(the existing `CylinderPassportPayload`), `GearTagLink` (a new
`GearTagPayload`), or `TagLinkRejected(reason)`. The path picks the codec;
a bare query string is tried as a cylinder payload, as today.

### 8.2 Resolution

`TagResolver` (domain, no Flutter) replaces `PassportResolver`:

| Result | When |
| --- | --- |
| `OwnItem(equipmentId, type, tag)` | the passport id is held by an item the diver can see, any type |
| `ForeignCylinder(tag)` | a `/c` tag with no visible holder |
| `ForeignGear(tag)` | a `/g` tag with no visible holder |
| `NotATag(reason)` | anything the codec rejects |

An own hit opens the page for the holder's current type: the cylinder
passport for a tank, the gear passport for anything else. A cylinder tag's
fill keys are imported for an own tank, as today, whichever scan point read
it.

### 8.3 Links and NFC

- `PassportLinkDispatcher` keeps any link `TagLinkCodec` accepts.
- `firstPassportUri` returns the first `/c` or `/g` URI record.
- `RecentPassportTags`, which suppresses the re-dispatch of a tag the app just
  read or wrote, covers both.

### 8.4 Scan points

| Where | Own tag | Foreign tag |
| --- | --- | --- |
| Equipment list, Scan | opens the item's passport (cylinder or gear) | opens the foreign cylinder or foreign gear page |
| Dive edit, Equipment section, new Scan action | the item joins the dive's gear through `_addGear` (components expand as with the picker); snack bar "Added <name>", or "already on this dive" | snack bar "Not in your gear" with View, which opens the foreign page |
| Trip Gear tab, Add chooser, new "Scan a tag" | the item goes through `_apply`: a tank becomes a slot on the cylinder board, anything else is packed | snack bar "Not in your gear" with View |
| Dive tank editor, blender cylinder picker | unchanged (cylinders only) | unchanged; a gear tag says the tag is not a cylinder |

Each scan point uses `PassportScanSheet`, whose title becomes the generic
"Scan a tag" everywhere. Phones get camera and NFC,
macOS the camera, and Windows and Linux Paste link. A wishlist item scanned
in the dive or trip flow is refused with "On your wishlist", as the pickers
hide wishlist items.

## 9. The gear passport page

`GearPassportPage` at `/equipment/:equipmentId/gear-passport`, in
`lib/features/gear_passports/presentation/pages/`. A tank id on this route
redirects to the cylinder passport. Every value with a unit goes through
`UnitFormatter`.

| Card | Shows | Source |
| --- | --- | --- |
| Header | name, type icon and label, brand, model, serial, owner chip when shared | `EquipmentItem` |
| Service status | every service clock, with Log service | `ServiceClocksCard` |
| Recent service | the newest three service records (date, kind, who), See all opens the detail page | `serviceRecordsForEquipmentProvider` |
| Usage | exposure totals (dives, hours) and the date range they cover | `ExposureCard` |
| Location | where the item is stored | `EquipmentLocationCard` |
| Trip | trips the item is packed for; Assign, Unassign | `PassportTripCard`, generalised to any type |
| Tag | QR of the current link, Print label, Write NFC tag, Link an existing tag, stale hint | `GearTagCard` |

The page mints the passport id on open, as the cylinder page does, for any
non-tank item that is not on the wishlist. Wishlist items have no Tag card.

The detail page shows `GearPassportEntryCard` for every non-tank item that is
not on the wishlist, where tanks show `PassportEntryCard`: a QR thumbnail once
the id exists, the last service date, and Open passport.

## 10. The foreign gear page

`ForeignGearPage` at `/equipment/gear-tag?t=<payload>`, beside the
foreign cylinder route `/equipment/tag`, opened on a `ForeignGear`
result. It shows the type, name, brand, model and serial, and the last
service date with "as written on the tag on <w>".

Add to my gear (`GearAdoptionService`), in one transaction:

1. Refuse, creating nothing, when an item anywhere in the library that is
   still in service holds the passport id; a retired or sold holder does not
   block (the cylinder rule of 2026-09-26).
2. Create an item of the tag's type (`other` when unknown) with its name
   (the type label when absent), brand, model and serial, through the normal
   create path so the type's default schedules attach.
3. Assign the passport id.
4. When `ls` is present, set it as the baseline of every attached schedule
   (`withBaseline(ls, now:, picked: true)`). No service record is created.

The new item opens on its gear passport.

## 11. Labels

`printPassportLabels` keeps its name and takes any selection.
Wishlist items are skipped.
Cylinders keep their label; other gear gets a gear label with the QR, name,
type, brand and model, and serial. Both kinds go in one PDF, in selection
order. Multi-select Print labels on the equipment list enables for any
selection; the gear passport Tag card prints one label.

## 12. Platform

- Android manifest: `/g` joins the autoVerify app-link filter and the
  `NDEF_DISCOVERED` filter; `g` joins the custom-scheme hosts.
- iOS and macOS: no change in this repository.
- Website, outside this repository, live before v1.8.2: the
  `apple-app-site-association` file gains `/g` and `/g/*`; a static `/g`
  page parses the fragment in the browser and shows the gear with Open in
  Submersion and the store links. Until it is live, in-app scanning and
  Android work, and an iPhone background tap on a gear tag reaches a 404.
  Recorded on #2652.

## 13. Documentation

- `docs/import-formats/gear-tag.md`: URL forms, payload table, parsing rules,
  drop order, NDEF layout, a worked example.
- `docs/design/specs/2026-10-10-gear-tags-device-checklist.md`: NFC write and
  read on iPhone and Android for a regulator; background launch from a tap;
  camera scan of a printed gear label; the dive edit and trip scans; an older
  app ignoring a `/g` tag.

## 14. Error handling

- A tag that fails to parse is reported with its reason and never stored.
- A passport id collision on link or Add to my gear is refused with the
  holder's name; Add to my gear rolls back whole.
- An NFC write that fails read-back reports the tag as not written and
  offers Retry, as for cylinders.
- Camera and NFC failures fall back to the other carriers.
- A link that arrives during setup is queued, never dropped.

## 15. Testing

Tests first throughout.

- **Codec.** Round trips over every key; both URL forms with fragment and
  query; `http`, `www.` and upper case; `/g/` and longer paths; missing and
  unknown keys; `f` of 2; missing and malformed `p`; missing, unknown and
  `tank` `t`; caps on non-ASCII text; bad dates.
- **Fit.** The drop order against NTAG213, 215 and 216 capacities; long
  names; the Android record added only when it fits.
- **Decoder and resolver.** `/c`, `/g` and bare payloads; the four outcomes;
  owner, sharee and stranger.
- **Repository.** Minting for a non-tank; the same id a tank had before;
  cross-type lookup; a retyped item still resolving; refusal by an in-service
  holder of another type; release by a retired one; fills relinked only for
  tanks.
- **Adoption.** Type, fields, unknown type, schedule baselines from `ls`,
  refusal and rollback.
- **Links and NFC.** The dispatcher keeps `/g` links; `firstPassportUri`
  finds a `/g` record; re-dispatch suppression.
- **Widgets.** The gear passport in its states (no service history, history,
  stale tag, wishlist); the entry card; the foreign page with and without
  `ls`; the dive edit Scan (own, already added, foreign, wishlist, cylinder
  tag); the trip Scan (own gear packed, own tank slotted, foreign); imperial
  units on dates and usage where shown.
- **Labels.** A mixed selection gives one PDF with both label kinds, and the
  gear label's QR decodes to the link.
- **Guards.** `test/architecture/` and `test/shared/` after new files under
  `lib/`; the l10n gate across every locale.

## 16. Delivery

One PR closing #2652, with the website change tracked on the issue.
