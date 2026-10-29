# Buddy card swap: exchange details with a dive buddy, offline

Status: design in review 2026-10-28, release v1.8.4. Issue #3728.

## Why

On the boat ride back after a dive, swapping details with a new buddy means
typing names, numbers and certification levels into each other's phones by
hand, usually with no signal. Submersion should let two divers swap buddy
profiles in a tap or a scan, offline, with each diver choosing what they
share.

Success: two divers who have just met open "Swap with a buddy", one taps the
other's name, the other taps Swap, and a few seconds later each phone has the
other as a buddy, with certifications and dive experience, after one look at
a preview.

## Goals

- Swap a **buddy card** (a diver's chosen details) between two phones with no
  network, by any of six methods, every one carrying the same card format
  into the same import preview.
- Per-field share choices, remembered between swaps, so a swap on the boat is
  one tap, not a form.
- A received card creates a buddy or updates the right existing one, never
  silently, and never touches what the receiver wrote themselves.
- Experience figures from the card (dive count, diving since, last dive)
  become real buddy fields, stamped with the day the card arrived.
- All six methods ship in one PR (maintainer's decision).

## Non-goals

- Swapping dives. Logging a shared dive into a buddy's logbook is #2366.
- Pairing or syncing. A swap never pairs the two devices: pairing merges two
  logbooks into one, which two strangers' phones must never do.
- Showing the card's contents on the web. The `/b` page (section 9) never
  reads or displays the card.
- Live cards. A card is a snapshot; nothing updates a buddy later except a
  new swap.
- Cave, tech or instructor credential verification. A card says what the
  sender claims.

## Anti-goals

- Sending anything the diver did not choose. Medical notes, allergies,
  medications, insurance and emergency contacts are never offered.
- A received card writing to the database without the receiver confirming.
- Leaking a diver's identity to anyone in Bluetooth range who is not on the
  swap screen. A phone not on the swap screen answers no card session.
- Duplicate buddies from a second swap with the same person.

## Constraints

- **iPhones cannot be NFC tags.** Apple does not let third-party apps emulate
  a tag, and Android Beam was removed in Android 10. Phone-to-phone tap works
  only with an Android phone as the tag; an iPhone can only read.
- **An Android phone cannot read and be read at once.** NFC reader mode turns
  card emulation off.
- **iOS reads NFC only after a user tap**, which shows Apple's "Ready to Scan"
  sheet.
- **QR codes hold about 2-3 KB** (byte mode, error correction M), and NFC
  stickers hold 504 bytes (NTAG215) to 888 bytes (NTAG216). Neither carries a
  photo.
- **The BLE carrier accepts one connection at a time as a peripheral**
  (`NearbyCarrier`, nearby sync spec section 2). Listing several nearby
  divers cannot hold one session open per diver.
- **Multipeer Connectivity is Apple-only** (iOS, iPadOS, macOS) and needs
  `NSLocalNetworkUsageDescription` and `NSBonjourServices` in Info.plist.
  Ultra-wideband ranging (Nearby Interaction) needs an iPhone 11 or later.
- The nearby link (merged in #3737, spec
  `docs/design/specs/2026-10-26-nearby-bluetooth-sync-design.md`) left room
  for this feature: a session intent beyond `sync` and `pair`, an unpaired
  session key, message types as an extensible enum (`NearbyMessageType`) with
  a protocol minor-version bump, and reusable nearby-list widgets.
- New synced buddy columns follow the repo's schema rules: tables in
  `lib/core/database/tables/`, a migration rung in `migrations/` (never in
  `database.dart`), sync serializer entries, and the guard tests in
  `test/architecture/` and `test/core/database`. The schema is at 320 today.
- Units and dates follow the active diver's settings.

## The design

### 1. The buddy card

One format, built by a pure-Dart codec in a new
`lib/features/buddies/domain/services/buddy_card_codec.dart`, with a domain
entity `BuddyCard`.

Fields:

| Field | Notes |
| --- | --- |
| `v` | Format version. A newer version is read for every known key; the preview says some details need a newer app. |
| `id` | Stable sender id: the sending diver's id. Lets a receiver recognise the same person next time. |
| `name` | Required. |
| `phone`, `email` | Optional. |
| `social` | Optional social handle (new diver field, see section 5). |
| `certs` | List of `{agency, name, level}` as display names, never the sender's custom-row ids, highest first. Card numbers and issue dates only when "Card details" is on. |
| `dives` | Total dive count: logged dives plus the diver's prior dive count. |
| `since` | "Diving since" date (`Diver.divingSince`). |
| `last` | Date of the most recent logged dive. |
| `photo` | JPEG thumbnail, at most 160 px and 12 KB. Only on the nearby, tap and file methods. |

Two encodings of the same entity:

- **Compact**: the fields minus `photo`, CBOR or compact JSON then
  base64url, inside a link `https://submersion.app/b#<payload>`. Used by QR
  and NFC (tap and sticker). The payload sits in the URL **fragment**, not
  the query string: a card describes a person, and a fragment never reaches
  the web server when the link opens in a browser. (Passport links keep
  their query string; only `/b` reads the fragment.) The codec drops fields in a fixed order
  (social, then `last`, then lower certifications) until it fits the target
  size, and the preview says when something was dropped. Modelled on the
  cylinder passport codec (`passport_payload_codec.dart`, `ndef_fit.dart`).
- **Full**: the fields with `photo`, as JSON. Used inside nearby sessions and
  as the share-sheet file.

### 2. Share choices

What the diver sends, stored per diver profile so each profile on a shared
device has its own. The swap screen's "Sharing: ..." line opens a sheet of
switches.

| Default | Fields |
| --- | --- |
| On | Name (always, cannot be switched off), photo, phone, email |
| On | Certifications (agency, name, level), total dive count, diving since, last dive date |
| Off | Card details (card numbers, issue dates), social handle |
| Never offered | Medical notes, allergies, medications, insurance, emergency contacts |

A field the diver has not filled in is left out of the sheet. Choices are
remembered between swaps.

### 3. The swap screen (layout B, chosen by the maintainer)

Opened from a new "Swap with a buddy" action on the Buddies list app bar.
Mockup: `docs/design/specs/assets/2026-10-28-buddy-card-swap-mockup.html`.

Top to bottom:

1. **Divers nearby with Submersion open.** The screen starts looking when it
   opens, over Bluetooth on every phone and over Multipeer between Apple
   devices. Each diver found shows as a row: photo (when it arrived), name,
   and "Tap to swap". A diver found on both carriers shows once, using
   Multipeer. "Looking for more..." sits under the list.
2. **"Sharing: name, phone, AOW + Nitrox, 342 dives · Change".**
3. **Fallbacks**, as buttons: Show my code, Scan code, Send file, Open card
   file, Write NFC sticker. On iPhone, "Tap an Android phone" too. On Android, "Receive by
   tap" too.

While the screen is open:

- An Android phone with NFC acts as a tag holding the compact card (method
  2), unless the diver turned on "Receive by tap".
- The phone is discoverable for card swaps, and only then.

First open asks for Bluetooth permission (and, on Apple devices, local
network permission for Multipeer). If refused, the nearby list is replaced by
one line saying why and a button to the system settings; every fallback still
works. Methods a platform cannot do are hidden there (a desktop without a
camera shows no Scan code; Linux cannot be found over Bluetooth but can find
others, as in nearby sync).

### 4. The six methods

All six end in the same import preview (section 6).

1. **QR code.** "Show my code" shows the compact card link as a QR code.
   "Scan code" opens the camera scanner. A Submersion card link scanned with
   the phone's own camera opens the app through the existing `submersion.app`
   app links, routed by a new `/b` path alongside the passport `/c` and `/g`
   paths.
2. **Android tap.** A new native Kotlin `HostApduService` (Type 4 NDEF tag
   emulation, AID `D2760000850101`) serves an NDEF message holding the
   compact card link while the swap screen is open. Any phone running
   Submersion reads it with the existing NFC reading service
   (`nfc_tag_service.dart`): an iPhone through "Tap an Android phone", an
   Android phone through "Receive by tap" (which turns its own emulation off
   for as long as it is on). One tap moves one card; the return trip is a
   second tap with roles flipped, or another method.
3. **Share-sheet file.** "Send file" writes the full card to a temporary
   `<name>.subbuddy` file and opens the system share sheet (AirDrop, Quick
   Share, Messages, email). The app registers the type: an exported UTI on
   Apple platforms (`app.submersion.buddy-card`, extension `subbuddy`) and
   an intent filter on Android. Windows and Linux register no file types
   today (not even UDDF), so there a card file opens by dropping it on the
   app or through an "Open card file" button on the swap screen. Opening the
   file lands in the preview.
4. **iPhone nearby swap (Multipeer).** A new native Swift plugin wraps
   `MCNearbyServiceAdvertiser` and `MCNearbyServiceBrowser` with a
   Submersion service type, used only while the swap screen is open. It
   implements the nearby link's carrier interface, so the card session
   (section 5's protocol) runs over it unchanged. On iPhone 11 and later,
   Nearby Interaction ranging, started after the two phones exchange
   discovery tokens over Multipeer, moves a diver closer than about 20 cm
   to the top of the list and sends them the swap request, as if their row
   had been tapped. The receiver still taps Swap.
5. **Bluetooth swap.** The card session over the existing BLE carrier.
6. **NFC sticker.** "Write NFC sticker" writes the compact card link to a
   blank or Submersion sticker with the existing NFC write path. Anyone taps
   it with their phone; it reads like method 2. The sticker is a snapshot:
   the screen says to rewrite it when details change.

### 5. The card session on the nearby link

- A new intent `card` in `NearbyIntent`. Card hellos carry protocol version
  2 (`NearbyHello.currentProtocolVersion` is a single integer, 1 today);
  `sync` and `pair` hellos stay at 1 so nearby sync with 1.8.3 builds keeps
  working. An older build refuses a version-2 hello with `error(newerApp)`.
- **Who is listed.** Only devices that answer the card hello with a card
  summary. A device not on its swap screen refuses with a new
  `NearbyErrorCode.notSwapping` (appended, so older builds read it as
  `protocol`), and an older build refuses with `newerApp`; neither is
  listed. A stranger's phone that is only advertising for its own sync
  never appears. Under the list, a hint: "Don't see your buddy? Both of you
  need this screen open and Submersion 1.8.4 or later." The link's existing
  stranger backoff keeps the swap screen from redialling refusers.
- The session uses the link's unpaired session key (HKDF of the ephemeral
  shared secret). **No code comparison** (maintainer's decision): one tap to
  accept, then the preview on both phones. The link must allow an unpaired
  `card` session without the short authentication string.
- A device accepts `card` sessions only while its swap screen is open, and
  `sync` and `pair` sessions keep their own rules.
- Listing: because a peripheral holds one connection at a time, discovery is
  connect, exchange hellos, exchange a **card summary** (name and photo
  thumbnail), and disconnect. The summary is cached for the screen's life
  and refreshed when the diver is sighted again after a while.
- Swapping: tapping a row reconnects and sends a **swap request**. The other
  phone shows "Sam Rivera wants to swap cards", with what it will send,
  and Decline or Swap. On Swap, both send their full cards in one exchange,
  then close. Decline, or no answer in 60 seconds, ends the session with
  nothing sent beyond the summary.
- New message types: `cardSummary`, `cardRequest`, `cardAccept`,
  `cardDecline`, `card`.
- Both phones on the swap screen see each other; the lower device id dials,
  as in sync. A request from both sides at once becomes one swap.

### 6. Receiving: the import preview

Every card, however it arrived, opens one preview page:

- **Recognised buddy.** A buddy whose stored `cardId` matches the card's
  `id`: "Update Sam Rivera", listing what changes.
- **Possible match.** No `cardId` match, but a buddy with the same name,
  phone or email: "Update Sam Rivera" or "Add as new buddy".
- **New.** "Add Sam Rivera as a buddy".
- Buttons: the primary action, and Discard.

What saving does:

- Writes the card's fields onto the buddy: name, phone, email, social
  handle, photo, headline certification (the card's highest), and the
  experience fields with `cardReceivedAt` set to now. Stores `cardId`.
- Only fields the card carries change. The receiver's notes, favourite flag,
  linked profile and shared dives are never touched. A field the sender
  switched off is left as it was, not cleared.
- Each certification on the card becomes a buddy certification (the
  `certifications` table already has `buddyId`), marked with the card's id
  in a new `card_id` column so card-made rows are told apart from rows the
  receiver typed. On an update, a card certification matching an existing
  card-made row (same agency and name) refreshes it; a new one is added; a
  card-made row missing from the new card is **kept** (the sender may have
  switched certifications off, or a QR card dropped it to fit). Rows the
  receiver added by hand are never touched.
- Agency and level arrive as display names. A name matching a built-in
  agency or level maps to it. Anything else is stored with agency Other and
  the sender's full title as the certification name, so no custom agency or
  level rows appear in the receiver's own pickers.

### 7. Storage

New nullable synced columns on `buddies` (schema 321):

| Column | Type |
| --- | --- |
| `card_id` | text |
| `social_handle` | text |
| `card_dive_count` | integer |
| `card_diving_since` | integer (date) |
| `card_last_dive` | integer (date) |
| `card_received_at` | integer (timestamp) |

New on `certifications`: `card_id` (text, nullable, synced), the id of the
card that created the row; null for rows entered by hand.

New on `divers`: `social_handle` (text, nullable, synced). Entities, mappers
and `copyWith` follow. The share choices live on the diver's own row in
`buddy_card_share`, a JSON text column (null means the defaults), so they
are per diver profile and sync with it.

### 8. What else the diver sees

- **Buddy detail page.** A "From Sam's card" block: "118 dives · diving
  since 2016 · last dive 3 Oct · from their card, 28 Oct". Shown only when
  any card field is set. Social handle joins the contact rows.
- **Buddy edit page.** The social handle field. The card fields are not
  editable; they come only from cards.
- **Diver profile edit.** A social handle field.

### 9. Companion website PR (submersion-website)

The site's `.well-known/apple-app-site-association` lists only `/c`, `/g`
and `/f`, so without a change an iPhone that scans a card QR with its own
Camera app, or reads a sticker in the background, opens Safari instead of
Submersion. A separate small PR in the `submersion-website` repository:

- Adds `{ "/": "/b", "comment": "Buddy cards" }` (and `/b/*`) to the
  `components` list.
- Adds a minimal static `/b` page for people without the app: "This is a
  Submersion buddy card. Open it in Submersion, or get the app", with the
  store links. The page has no script that reads the fragment, so the card
  never leaves the phone and is never shown.
- Checks that Android's `assetlinks.json` already covers the whole domain
  (App Links paths are declared in the app's manifest, which this feature's
  app PR extends with `/b`).

It merges before or with the app PR. It is opened from a session working in
that repository, since this worktree cannot write there.

## Decisions the maintainer made

- Per-field share choices with the defaults in section 2, remembered between
  swaps; medical, insurance and emergency contacts never offered.
- Six methods: QR, Android tap, share-sheet file, iPhone nearby swap
  (Multipeer, with ultra-wideband hold-together), Bluetooth swap, NFC
  stickers. All in one PR.
- Bluetooth device-to-device sync built first (#3731, merged as #3737), and
  the swap rides its nearby link.
- Swap screen layout B: nearby divers first, fallbacks below.
- A nearby swap request is one tap to accept, then the preview on both
  phones. No code.
- Dive count, diving since and last dive date are real buddy fields with a
  received date.
- A companion PR in `submersion-website` adds `/b` to the app-links file
  and a minimal `/b` page for people without the app.

## Calls made in this design (not decided by the maintainer)

- A swap never pairs the two devices.
- The card's `id` is the sender's diver id; recognition by `cardId`, then a
  name, phone or email match offered as a choice.
- An update never clears a field the sender switched off, and never touches
  the receiver's own notes, favourite flag, links or hand-added
  certifications.
- No photo in QR or sticker; a 160 px, 12 KB thumbnail elsewhere.
- Compact cards drop fields in a fixed order to fit, and say so.
- The entry point is an app bar action on the Buddies list.
- Discovery connects, swaps summaries and disconnects, because of the
  one-connection peripheral.
- A 60-second answer window for a swap request.
- Hold-together on iPhone 11 and later sends the request automatically; the
  receiver still accepts.
- Share choices are per diver profile, stored as JSON on the diver's row.
- No Windows or Linux file association; card files open there by drop or
  an "Open card file" button.
- File extension `.subbuddy`, link path `/b`, card payload in the URL
  fragment.
- Certification provenance in a `card_id` column; card-made certifications
  missing from a newer card are kept, not removed.
- Non-built-in agencies and levels arrive as Other plus the full title; no
  custom rows are created on the receiver.
- Card hellos use protocol version 2 while sync and pair stay at 1; only
  devices on their swap screen running 1.8.4 or later are listed, with a
  `notSwapping` refusal code for the rest.

## Left to the builder

- CBOR versus compact JSON for the compact encoding, and the exact field
  keys.
- The Kotlin `HostApduService` details (APDU handling, the NDEF file layout,
  `apduservice.xml`) and how Flutter starts and stops it with the screen.
- The Swift Multipeer plugin's channel API, its service type string, and how
  it maps onto `NearbyCarrier` and `NearbyEndpoint`.
- Nearby Interaction token exchange and the distance threshold tuning.
- How "highest certification" is ranked across agencies (reuse the buddy
  certification level ordering).
- Strings and their translations in every supported locale.
- Unit tests for the codec (round trip, fit-to-size, newer version, bad
  input), share choices, the match rules, the merge rules, the card session
  protocol over `InMemoryNearbyCarrier` (accept, decline, timeout, both
  request, older peer); widget tests for the swap screen, the share sheet,
  the request sheet and the preview; migration tests for schema 321.

## Manual test checklist (real devices)

- Android to Android: nearby swap, tap both ways, QR, file via Quick Share,
  sticker write and read.
- iPhone to iPhone: Multipeer swap with hold-together (iPhone 11+), an older
  iPhone picking from the list, AirDrop file, QR, sticker read.
- iPhone and Android: Bluetooth swap, Android tap to iPhone, QR both ways.
- A desktop (macOS or Windows) and a phone: Bluetooth swap, file.
- Second swap with the same person updates, not duplicates.
- Bluetooth permission refused: fallbacks still work.
- An older app version on one side: "Needs a newer app version".
