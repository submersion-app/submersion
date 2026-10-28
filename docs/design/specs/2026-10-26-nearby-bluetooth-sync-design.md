# Nearby sync: device-to-device sync over Bluetooth

Status: design in review 2026-10-26, release v1.8.4.

## Why

A diver on an island with a phone and a laptop and no Wi-Fi cannot get the
day's dives from one to the other. Every sync backend Submersion has today
(iCloud, Google Drive, Dropbox, S3, WebDAV, Git) needs a network between
the two devices and a server in the middle. The two devices are a metre
apart.

Nearby sync lets two of a diver's own Submersion devices sync their
logbooks directly over Bluetooth Low Energy, with no network, no account and
no server. It works whether the devices also share a cloud backend, only one
does, or neither does.

The Bluetooth part is built as a reusable **nearby link**: discovery,
connection, pairing and a small versioned message protocol. Logbook sync is
its first user. A later feature, the buddy card swap (exchange contact
details and certifications with a new buddy on the boat), will be its
second, and will need a short, unpaired exchange between strangers. This
design builds the link so that is possible, and builds nothing of the swap.

Success: the diver opens Submersion on the phone and on the laptop, and
within a minute the laptop shows the dives logged on the phone, with no
tap on either device after the one-time pairing.

## Goals

- Sync the whole logbook, in both directions, between two paired devices
  over Bluetooth LE alone: every table and row the cloud changeset carries,
  including the blobs stored in the database (dive profile samples, diver
  and buddy photos, media `imageData`, document page scans, nav tracks).
- Incremental: two devices that already have most of each other's data,
  through the cloud or an earlier nearby sync, exchange only what is
  missing.
- Automatic while both apps are open and the devices are in range, with a
  device-local switch to turn that off. Silent when it works.
- All five platforms: iOS, Android, macOS, Windows, Linux. Any pair of them
  can sync, except Linux to Linux (see Constraints).
- A first copy to a device that has nothing survives a dropped connection
  and resumes rather than starting over.
- Pairing is a one-time, code-on-both-screens confirmation, after which the
  two devices trust each other and every session between them is encrypted
  on the wire.
- The nearby link (not the sync protocol on top of it) also supports a
  session between two devices that are not paired, so the buddy swap can be
  built on it later.

## Non-goals

- The buddy card swap itself. No card, no stranger exchange UI, no message
  type for it. Only the link's ability to host an unpaired session.
- Moving media files (photos and videos kept outside the database). Nearby
  sync carries the same rows and blobs a cloud changeset carries and nothing
  else. Media files stay where the media program keeps them.
- Any carrier other than Bluetooth LE. No Wi-Fi Direct, no Multipeer
  Connectivity, no hotspot, no L2CAP channels, even where the platform
  offers them and they would be faster. The maintainer chose Bluetooth only.
- Background sync. A sync runs while the app is open on both devices.
- Advertising on Linux (a Linux device only scans). Tracked as a follow-up
  issue; see Constraints.
- Replacing cloud sync. Nearby sync runs beside the chosen cloud backend,
  never instead of it, and changes nothing about how the cloud backend
  works.
- Syncing between two different libraries, or helping a device join a
  library. Pairing refuses a device whose library is not this one.

## Anti-goals

- Anything the diver has to watch. No progress banner, no toast, no
  spinner on the dive list. The dives appear. The only interruptions are
  the pairing code the first time and, when a device cannot sync, one chip
  on the home screen.
- A second sync engine. Nearby sync reuses the changeset export, the merge
  rules and the peer cursor table of the existing engine. If the design
  needs a new way to decide which row wins, it is wrong.
- A nearby session that confuses the cloud backend's bookkeeping. The cloud
  backend's manifest and cursors are untouched by a nearby sync; its publish
  watermark moves in exactly one direction and for exactly one reason (it is
  pulled back so relayed rows reach the cloud, see Relay).
- Leaking the library to a stranger. An unpaired device that connects
  learns at most that this is a Submersion device and, in pairing mode, its
  display name. No rows ever cross before the pairing code is confirmed on
  both sides.

## Constraints

- **Bluetooth LE only.** Over GATT between phones expect roughly 10 to 30
  KB/s with default settings and 40 to 50 KB/s at best when an iPhone is on
  either end (Android to Android can be two to three times faster). A 10
  MB first copy is four to ten minutes. Every later sync is a few KB.
- **Package.** `universal_ble` (BSD-3, actively maintained): central on all
  five platforms, peripheral (advertise, host a GATT service, accept
  writes, send notifications) on iOS, Android, macOS and Windows. It is the
  app's first Bluetooth package; the existing Bluetooth is native scanning
  inside the libdivecomputer plugin and only ever talks to dive computers.
  Both stacks must coexist (each owns its own central manager; this is
  normal on every platform, but is on the manual test list).
- **Linux scans only.** No Flutter package hosts a GATT service on Linux
  (BlueZ supports it only through an unwrapped D-Bus API). A Linux device
  finds the other device, which must be advertising; two Linux devices
  cannot meet. The maintainer accepted this for the first version and asked
  for a follow-up issue, "Nearby sync: advertise on Linux", to be opened
  with the feature's issue.
- **Both apps open.** A backgrounded iPhone drops its name and service from
  its advertisement, so Android and desktops cannot see it; desktops do not
  run in the background at all. The design promises discovery and sync only
  while the app is in the foreground on both devices. The iOS
  `bluetooth-peripheral` background mode is not added in this version.
- **Permissions.** Android gains `BLUETOOTH_ADVERTISE` (runtime, Android
  12+; the diver sees a "Nearby devices" prompt the first time they pair).
  The existing iOS `NSBluetoothAlwaysUsageDescription` and
  `NSBluetoothPeripheralUsageDescription` strings change to mention nearby
  devices as well as dive computers. macOS already has the Bluetooth
  sandbox entitlement; Windows and Linux need no manifest change.
- **Schema.** One new device-local table and one rung on the migration
  ladder. Tables live under `lib/core/database/tables/`, rungs under
  `lib/core/database/migrations/ladder/`; nothing is added to
  `database.dart` itself.
- **Reuse.** The changeset export (`SyncDataSerializer.exportChangeset`,
  the streamed base export `exportBaseToTempFile`), the merge
  (`SyncService._applyRemotePayload`, `_applyRemoteBaseFile`), the peer
  cursor table (`SyncPeerCursors`), the clock (`SyncClock`), the device id
  (`SyncMetadata.deviceId`), the display name
  (`DeviceDisplayNameService`), AES-256-GCM and HKDF from the
  `cryptography` package and `EncryptionKeyStore`'s secure storage are all
  reused as they are. The merge gets a public entry point; nothing else in
  the engine changes shape.
- **Tests run on Linux CI with no Bluetooth.** Everything above the carrier
  must be testable with an in-memory link. Real-device tests are a manual
  checklist the maintainer runs.

## The design

### 1. Three layers

```
Nearby sync          what a session says: watermarks, changesets, acks
Nearby link          who is there, connecting, pairing, encrypted messages
Carrier              Bluetooth LE through universal_ble (fake in tests)
```

The sync layer knows nothing about Bluetooth. The link knows nothing about
dives. The carrier moves bytes.

### 2. Carrier

A `NearbyCarrier` interface with two roles: **advertise** (host the
Submersion GATT service and accept one connection at a time) and **scan**
(find advertisers and connect). Both roles can be active at once on a
device that supports both. Linux implements scan only and reports
`canAdvertise == false`.

The GATT service has one fixed Submersion service UUID and two
characteristics: **inbox** (the central writes to it, with response) and
**outbox** (the central reads it; the peripheral answers each read from a
queue of what it has to send). A notification on the outbox is only a
one-byte doorbell saying bytes are waiting, backed by a slow poll: a
Flutter peripheral has no flow control over notifications (Apple rejects
them once its queue is full, Android drops them), while reads and
acknowledged writes pace themselves on every platform. Each direction
carries a byte stream framed by the link layer; the carrier cuts it into
chunks that fit the negotiated MTU, never longer than the 512 bytes one
attribute value may hold, and a peripheral's send waits while 64 KiB are
queued. A peripheral cannot hang up on a central, so a closing one first
lets the central read what is still queued (a refusal, a `bye`), for up
to three seconds. Closing a session waits at most two seconds for its own
`bye` to get past what is queued ahead of it, so a stalled link never holds
an unpair or the move to the background.
Both sides ask for the largest MTU the platform allows and the fastest
connection priority Android offers. The advertisement carries the service
UUID and nothing else: no name, no identity. Who the device is comes out
only after connecting.

Tests use `InMemoryNearbyCarrier`: two ends of a pipe in one process, with
hooks to drop the link at a chosen byte for the resume tests.

### 3. Link: sessions, hello, pairing, encryption

**Hello.** The first message each way is plaintext and names neither
device: protocol version, intent (`sync` or `pair`), and key material. The
initiator commits to its ephemeral X25519 key (a hash) and reveals it only
after the responder's key arrives, so a device in the middle cannot search
for keys that make the two codes match. For a sync, the initiator sends one
anonymous tag per device it is paired with (an HMAC of that pair secret over
this session's commitment) and the responder answers with one tag for the
pairing it recognised; tags differ every session, so they say nothing to
anyone without the secret. After the key check, each side sends its
identity (device id, display name, app build, schema, floor, library epoch,
whether it holds dives) sealed.

**Pairing** (intent `pair`, started by the diver from Settings on either
device while the other is also on the pairing screen). Both sides derive
a six-digit code from the shared secret and both hellos (HKDF, then mod
1,000,000, zero padded). Because a man in the middle would produce two
different codes, matching codes confirm the two devices share a secret
with each other and no one else. Each diver confirms "Same code" on their
screen; the link waits for the other side's confirmation message, then
both re-key with a **pair secret** (HKDF of the shared secret with the pair
label), exchange their full identities, and store the secret under the
peer's device id in secure storage, and a row in the paired-devices table.
Until both confirm, each side sees only a preview: the other's display
name, whether it holds dives, a random per-pairing nonce, and an epoch tag
(an HMAC of its library epoch) that matches the other's only on the same
library, so two libraries are refused without either revealing its epoch.
"Not mine" or a timeout (two minutes) ends the session with nothing
stored.

**Encryption.** After hello, every message is AES-256-GCM under a session
key: for a paired peer, HKDF of the pair secret and both ephemeral public
keys; for an unpaired peer (future buddy swap), HKDF of the ephemeral
shared secret alone, which the code on screen authenticates in the same
way. The library's own encryption (SBE1 envelopes) is not involved:
changesets travel as plaintext inside the encrypted link, and a device on
an encrypted library applies them exactly as it applies decrypted cloud
changesets. Nonces are a per-direction counter; a nonce reuse ends the
session. Every frame after the key check is sealed, `error` and `bye`
included (the rest of the handshake as well as the session), so nobody in
range can end a session with a forged refusal, or leave a false reason on
a paired device's row. A bare one there is a protocol violation.

**Messages.** A message is a 4-byte length, a 1-byte type, and the
(encrypted) body. Types are a small enum: `hello`, `pairConfirm`,
`pairReject`, `watermarks`, `changeset`, `basePart`, `applied`, `error`,
`bye`. Unknown types after hello end the session with `error`. The
protocol version in hello is bumped whenever a type's body changes; a
device that sees a newer major version replies `error(newerApp)` and the
peer shows "Needs a newer app version" for it. The version is read before
the rest of the hello, so this holds for a newer hello this build cannot
parse.

**Library check.** The library epoch id (`LibraryEpochStore.lastAccepted`)
is today written only by the cloud flows, so a device that has never had a
backend has none, however many dives it holds. The rules:

- Both have one and they differ: refused. Pairing says "This device is on
  a different library"; a paired peer that later differs (it was
  replaced-and-joined elsewhere) is refused with `error(differentLibrary)`
  and its row shows "Not the same library".
- One has an epoch and the other has none: the one without adopts it at
  pairing, stored in `LibraryEpochStore.lastAccepted` like a cloud
  adoption. From then on that device belongs to this library: a cloud
  folder it sets up later inherits the epoch (the cloud gate's self-heal
  branch), and a folder of another library halts for adoption, both
  correct.
- Neither has one: pairing mints a fresh epoch on the initiator and both
  adopt it.

When both devices already hold dives and do not share an epoch, the pairing
page says so before the code: "Both devices have dives. Pairing merges them
into one logbook." Merging is what a diver pairing their own two devices
wants; the cloud's first-contact flow makes the same choice.

**Schema check.** As with cloud peers: a peer whose schema version is newer
than this build understands is held with "Needs a newer app version" (on
this device, pointing at this device's update); an older peer's rows apply
on the newer device through the same compatibility floor the cloud reader
uses (`minimumCompatibleSchemaVersion`). The newer device's rows do not
flow to the older one; its "last synced" stays put and it shows the chip.

**One session per peer at a time.** Both devices scan and (where able)
advertise. When both can see each other, the device with the lower device
id (string order) connects and the other declines a second connection, so
a pair never opens two sessions. When both connect at once anyway, each
keeps the session the lower device id started and closes the other. A
closed session stops at once and reads nothing more, frames still in
flight included, so the one replaced writes nothing more to the files and
the row its successor uses. A device in pairing mode accepts a
connection from any Submersion device; otherwise it accepts only a device
in its paired list and drops anything else after hello without replying
beyond `bye`.

### 4. Sync protocol

A session is one round trip, sender first, then the same in the other
direction. The initiator (the connecting device) sends first.

1. **Watermarks.** The receiver sends, for every originating device id it
   knows, the highest HLC it holds from that device (the `nodeId` inside
   each row's `hlc` identifies the writer, so this is one query over the
   synced tables plus the deletion log). A device with an empty library
   sends an empty map.
2. **Delta or full copy.** The sender compares the receiver's map with the
   set of writers it holds (the same query, run on its own rows). A
   **delta** is possible only when the receiver knows every writer the
   sender holds. Then it runs `exportChangeset` from the lowest receiver
   watermark among the writers the sender is ahead on (so an old writer with
   nothing new does not widen the window), with `childrenByOwnClock` so a
   child edit whose pending mark a cloud publish already cleared still
   travels, and drops each row and tombstone whose every clock (row clock
   and media fact clocks) is covered by the receiver's watermark for that
   clock's writer. Otherwise it sends a **full copy**. Rows with no clock
   (built-in reference rows, some older children) never travel in a delta,
   exactly as in cloud changesets; they cross in the first full copy and
   with their parents. A real library holds hundreds of them, so treating
   them as a reason for a full copy would make every sync a full copy. So the first sync between two
   populated devices that never shared a cloud is always a full copy, in
   both directions, and every later one is a delta. A full copy is applied
   with the merge rules like any payload; it never wipes the receiver.
3. **Size.** A delta whose blob bytes (`pendingSeriesBlobBytes` over the
   same watermark) are under the in-memory limit the cloud writer uses goes
   as one `changeset` message: the same JSON the cloud changeset uses
   (`SyncPayload`), gzipped. A larger delta, and every full copy, is
   streamed with `exportBaseToTempFile` and sent as numbered `basePart`
   messages of 256 KB, each with its index, count and checksum, in the
   format the cloud base reader already parses.
4. **Apply.** The receiver validates the checksum, then applies through a
   new public `SyncService.applyNearbyPayload` (a thin wrapper over
   `_applyRemotePayload`) or `applyNearbyBaseFile` (over
   `_applyRemoteBaseFile`), inside `SyncCoordinator.run` so it never
   overlaps a cloud sync. The wrapper passes the paired-devices row's
   `last_synced_at` as the merge's `lastSync`, so the pre-HLC two-sided
   edit conflict and the tombstone age guard work per peer exactly as they
   do per cloud backend. Last-writer-wins by HLC, the same as the cloud
   path; a conflict is recorded the same way and shows up in the Sync
   page's existing conflicts section.
5. **Ack and cursors.** The receiver records what it applied in
   `SyncPeerCursors` under provider id `nearby` and the sender's device id
   (`appliedHlcHigh` means "the highest clock I applied from this peer",
   the same direction the cloud cursor has; the seq fields stay 0). It then
   replies `applied` with that clock. The sender stores it on its
   paired-devices row as `peer_applied_hlc` ("what this peer has of mine")
   and both update `last_synced_at`. Then the roles swap.
6. **Resume.** The receiver writes base parts to a temp file as they
   arrive and keeps, per peer, the base id and the last complete part
   index. When a session reconnects within 24 hours and the sender offers
   the same base id, the receiver asks for parts from that index. The
   sender keeps its temp base file for the same 24 hours. A changeset
   message that is cut off is simply re-sent next session: the watermarks
   exchange makes every session idempotent.

**Relay.** Rows applied from a peer keep that peer's clock. When this
device next publishes to its cloud backend, `exportChangeset` over the cloud
watermark carries every row newer than that watermark, relayed rows
included. Rows older than it would be skipped, and in the island case that
is the common case: the laptop has no backend, and the phone has usually
published to iCloud since the laptop's edit. So after a nearby apply, for
each cloud backend state in `LocalPublishStates`, if the oldest clock
applied in this session is older than that backend's `publishedHlcHigh`,
the watermark is pulled back to that clock. The next cloud publish then
re-sends everything since it, children selected by their own clock too
(a relayed tank edit on an older dive is not pending on this device),
which the peers' merge rules treat as
no-ops for rows they already hold. The amount is bounded by the age of the
oldest relayed edit. This is the one way a nearby sync touches cloud
bookkeeping. (Decided by the maintainer.)

**Tombstone garbage collection.** The deletion log is pruned today at an
age floor plus the horizon of what every live cloud peer has applied.
Nearby peers join that horizon: `clearAcknowledgedDeletions` also reads
`peer_applied_hlc` from every paired-devices row, so a deleted dive's
tombstone stays until the laptop has it. The cloud path drops a peer from
the horizon only by retirement after a year of silence
(`SyncLiveness.retirementPeriodMillis`); nearby peers get the same rule,
keyed on `last_seen_at`. A peer silent that long stops holding tombstones
back; its next session is a full copy, and the per-peer `lastSync` guard
above keeps a stale row of its own from reviving the deleted record on the
newer device. Unpairing retires the peer from the horizon at once.

**Automatic sync.** With "Sync nearby automatically" on (the default), the
link scans and advertises whenever the app is in the foreground and the
Bluetooth radio is on. In the foreground means on screen, focused or not:
a desktop window behind another app, or Control Center pulled over the
app on iOS, keeps a transfer going; a hidden or minimised app ends it. A
running scan is restarted at most every ten seconds: real radios report
every advertisement anyway, and Android stops delivering results to an
app that starts five scans in 30 seconds. A session with a paired peer starts on discovery,
and again after a local change (`SyncEventBus.notifyLocalChange`, with the
same five-second debounce the cloud path uses) while the peer stays in
range, and otherwise not more than once every ten minutes per peer. With
the switch off, nothing scans or advertises; "Sync now" on a device's row
turns the radio on until that device is found (or 20 seconds pass) and
runs one session; with Bluetooth off or not allowed it says so at once.
It dials its device's known address at once, even just after a session,
and any address it cannot yet put a name to; another paired device seen
meanwhile keeps to its own rules, whether its address was known or the
handshake only now named it (then the link is closed before any data
moves). A dial made at a first sighting obeys the same rules once the
handshake says who answered. With the switch off, a paired device that
dials in while the radio is on (for pairing, or a Sync now looking for
another device) is turned away after the handshake too. Every wait (the cooldown, the spacing
between attempts, a stranger's backoff, the scan restart) counts a clock
set back as time passed, so none outlasts the change. An address that turns out to belong to no paired device
is left alone for a minute, doubling to half an hour, so a boat full of
Submersion users does not keep connecting to each other. A device's
address is learned only from a link this device opened: one the peer
opened arrives under its central's id, which on Bluetooth is not the
address it advertises. A paired peer that
refuses for a reason the diver has to fix (an update, another library, an
unpairing) waits out the same ten minutes as a synced one; a session cut
short by a lost link, like a transient refusal, is tried again at the
next sighting (no sooner than the spacing between attempts), so a full
copy resumes soon. That holds three times in a row; a fourth transient
failure waits out the cooldown, so a peer that fails the same way every
time (a full disk on either side) is not redialled every 30 seconds.
Unpairing a device ends a "Sync now" looking for it, or waiting on its
running session, and says it was unpaired. In pairing mode
a device that could not be paired with yet (its pairing page not open, or
the connection failed) is tried again when next seen: a scan-only device
has no other way to meet it. The switch is device-local, stored in `SyncPreferences`
(`sync_nearby_auto`), never synced.

**Errors.** Every session failure is recorded on the paired-devices row
(`lastError`, an enum: `newerApp`, `differentLibrary`, `bluetoothOff`,
`unreachable`, `applyFailed`). A row with an error that is not transient
(`newerApp`, `differentLibrary`, `applyFailed`) drives the home chip. A
transient one (`bluetoothOff`, `unreachable`) only shows on the row.
Refusals count: two paired devices on different libraries refuse each other
at once, so each records the refusal it made itself, the dialled device as
well as the dialling one; a refusal the peer gives no reason for reads as
`unreachable`. A copy that will not unpack or apply is an `applyFailed`:
it ends that direction only, and nothing of it is kept for a resume. Rows
the merge could not take make the session an `applyFailed` too, as a
failed record makes a cloud sync an error, though what did apply is
acknowledged. The
sender keeps a full copy for a resume only after a lost link; one the peer
refused is made afresh next time. A row
says `bluetoothOff` only while the radio is wanted; when nothing wants it,
whether Bluetooth is on says nothing about why a device is not syncing.

### 5. Storage

- **Table `nearby_peers`** (device-local, never synced, like
  `SyncPeerCursors`): `peer_device_id` (PK), `display_name`, `paired_at`,
  `last_synced_at`, `last_seen_at`, `peer_applied_hlc`, `last_error`,
  `resume_base_id`, `resume_part_index`.
  One rung on the migration ladder creates it. Unpairing deletes the row,
  this peer's `nearby` cursor and the copies kept for a resume with it,
  and keeps the pair secret aside as
  revoked: when the old peer next connects, this device recognises its
  tag, completes the key check and answers with a sealed "not paired", so
  the old peer can show the error on the right row.
- **Pair secrets** in secure storage under `nearby_pair_<peerDeviceId>`,
  beside the library key `EncryptionKeyStore` keeps. They never leave the
  device and are not in backups.
- **Cursors** in the existing `SyncPeerCursors` under provider `nearby`.
- **Settings** in `SyncPreferences`: `sync_nearby_auto` (bool, default
  true).

### 6. What the diver sees

Mockup: `docs/design/specs/assets/2026-10-26-nearby-bluetooth-sync-mockup.html`
(the Sync page option is the chosen one).

**Settings > Data > Sync** gains a **Nearby devices** block between the
"Keep in step" switch and the Advanced section:

- A switch, "Sync nearby automatically", subtitle "When a paired device is
  open nearby, over Bluetooth".
- The paired devices, one row each: a status dot (green: synced or
  syncing, grey: not seen lately, amber: needs attention), the device's
  display name, and a second line: "Synced 5 min ago", "Syncing: 1.2 of
  9.8 MB", "Not seen since Tuesday", or the error in plain words ("Needs a
  newer app version", "Not the same library"). Tapping a row opens a sheet:
  Rename, Sync now, Unpair.
- "Pair a device".

The block appears on every platform. On Linux the switch's subtitle adds
"This computer can be found by other devices only when they advertise";
in practice that means a Linux device pairs with and syncs to any
non-Linux device.

**Pairing.** "Pair a device" opens a page that scans and lists nearby
Submersion devices by display name ("Looking for devices…" with a hint to
open Submersion and tap Pair on the other device). Tapping one connects
and shows the six-digit code with "Same code" and "Not mine". The other
device, also on its pairing page, shows the same code when the connection
arrives. When both confirm, both pages close to the Sync page with the new
row, and the first sync starts at once. A diver who tapped "Same code" and
then left the page has still confirmed: the pairing finishes when the other
diver answers. Leaving rejects only the pairings this diver has not
answered. Reopening the page shows that pairing still waiting, keeps the
pairing nonce it was made under so the other device does not show it
twice, and a second tap confirms nothing twice. When the two devices
found each other from both sides, each keeps the pairing the lower nonce
started, even over one its diver already confirmed: the other device
cannot know that, and both must show the same code, so that diver
confirms the one left. Bluetooth permission is requested
the first time this page opens, with the OS prompt; if refused, the page
explains and offers the system settings.

**Home.** The gauge strip gets a `nearby` chip type, shown only when a
paired device has a non-transient error: "Nearby: Old iPad needs an
update" (one chip, naming the first such device; "and 1 more" when
several). Amber tone, tap opens the Sync page. It is hideable like the
other attention chips and is absent when every paired device is healthy
or there are none.

**Nothing else.** No banner, no snackbar, nothing on the dive list.

### 7. Buddy swap readiness

What this design leaves for the swap, so it needs no change to the link:

- A session intent other than `sync` and `pair` (the swap adds `card`), with
  the unpaired session key and the same on-screen code.
- Message types are an enum with room; a new type is a protocol minor
  version bump, which older builds reject cleanly with `error(newerApp)`.
- The pairing page's "nearby devices" list and the code screen are
  reusable widgets, not tied to the Sync page.

The swap decides later whether a swap leaves the two devices paired. This
design makes no such choice.

## Decisions the maintainer made

- Bluetooth LE only; no other carrier.
- All five platforms; Linux scans only, with a follow-up issue for Linux
  advertising.
- Sync works the same whether the devices share a backend, one does, or
  neither does.
- Pairing: a code shown on both screens.
- Automatic sync while both apps are open, with a Settings switch to turn
  it off.
- The entry point is a Nearby devices block inside Settings > Data > Sync.
- Nothing is shown while a sync runs; a device that cannot sync is surfaced
  as a chip on the home screen gauge strip.
- Just the changeset, including the blobs stored in the database; no media
  files.
- Relay: a nearby apply pulls the cloud publish watermark back so a
  backend-less device's edits reach the cloud through its paired device.

## Calls made in this design (not decided by the maintainer)

- `universal_ble` as the package.
- Lower device id connects when both sides can see each other.
- X25519 plus a six-digit short authentication string for pairing, and a
  stored pair secret per peer in secure storage.
- One sync direction at a time, initiator first.
- Base parts of 256 KB, each given five minutes to arrive (well under the
  slowest link expected, an iPhone serving reads at about 3 KB/s), resume
  kept for 24 hours.
- Automatic re-sync: on discovery, on local change, else every ten minutes.
- `nearby_peers` as a database table rather than a preferences blob.
- Transient errors stay on the row; only lasting ones raise the chip.
- Both platform permission strings now mention nearby devices.
- Library epochs: a device without one adopts the other's; two without
  mint one together; both populated means a merge, said on screen.
- The first sync between populated devices that never shared a cloud is a
  full copy in each direction; deltas only once every writer is known.
- Nearby peers hold tombstones back like cloud peers until unpaired or
  silent for the cloud path's retirement period. A session counts as
  contact from its start, not only its end (a full copy can run long), and
  a refused one counts too: a paired device that keeps refusing (it needs an update, or
  moved to another library) is still around and may sync again.
- The merge's `lastSync` is the per-peer `last_synced_at`.
- Demo mode (the sample logbook, #3729) seals nearby sync like cloud
  sync: the radio stays off and both applies refuse. The sample has its own
  database but shares secure storage with the real library, so the radio
  must not even start there: its empty paired-devices table would read as
  "every pair secret is an orphan" and the cleanup would delete them.
  Entering demo mode closes the gate before the app restarts, with the
  radio still on, so a session that would start in between is turned away
  too. A session already running is ended, and entering waits for it to
  finish before the sample logbook opens, so none reads or writes across
  the switch. Leaving needs no such step: no session runs in demo mode.

## Left to the builder

- Exact GATT UUIDs, MTU negotiation details and the chunk reassembly.
- The watermark query (max `hlc` per `nodeId` across the synced tables and
  the deletion log) and whether to cache it.
- How `exportChangeset` output is filtered per writer without a second
  pass over the database.
- The shape of the `applyNearbyPayload` and `applyNearbyBaseFile` wrappers
  and how they report conflicts and progress to the row.
- Where the scan and advertise lifecycle hooks into app foreground and
  background (the cloud path's resume hooks in `app.dart` are the model).
- Strings and their translations in every supported locale.
- Unit tests for framing, encryption, pairing (matching and mismatching
  codes), the watermark exchange, the size switch, resume after a drop at
  every message boundary, library and schema refusal, and the chip
  provider; widget tests for the Sync page block and the pairing page.

## Manual test checklist (real devices)

1. iPhone and Mac: pair, first full copy of a library over 5 MB, time it,
   kill the app on the Mac halfway, reopen, confirm it resumes.
2. The same pair, the Mac with no backend: add a dive on each, let the
   phone sync to iCloud in between, then open both nearby; confirm both
   dives appear on both without a tap, and that the Mac's dive reaches
   iCloud on the phone's next cloud sync (the watermark pull-back).
3. Android and iPhone, both ways.
4. Windows as advertiser with a phone, and Linux as scanner with a phone.
5. A device on another library: pairing refused with the right message.
6. A dive computer download over Bluetooth while nearby sync is on.
7. Bluetooth off on one side: row shows it, no chip.
8. Unpair on one side only: the other side's next attempt fails cleanly
   and its row shows it.
