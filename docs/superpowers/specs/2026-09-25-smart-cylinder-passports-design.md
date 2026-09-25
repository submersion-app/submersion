# Smart cylinder passports

Date: 2026-09-25
Issues: #2333 (umbrella); #2334, #2335, #2336, #2337, #2338, #2339 (one per PR, section 17)
Branch: `ericgriffin/smart-cylinder-passports-60ca56`

## 1. Problem

A cylinder is the one piece of gear whose state changes between every dive
and whose paperwork has legal weight: what is in it, at what pressure, when it
was last hydro tested and visually inspected, and whether it is oxygen clean.
Today that state is scattered. The spec lives in equipment attributes, the
test dates live in service clocks, the mix lives on whichever dive last used
the tank, and the fill itself, the moment a station analysed the gas and
wrote a number on a strip of tape, is not recorded anywhere.

Nothing ties the physical object to its record. A diver with six identical
steel 12s tells them apart by tape; a rental diver handed a tank knows nothing
about it; a fill station that analysed a mix has no way to hand that analysis
to the diver's log except the tape.

The idea: put a QR or NFC tag on each cylinder. Scanning it opens a passport
showing volume, working pressure, material, buoyancy, hydro and VIP dates, O2
clean status, the current analyzed mix and its MOD, fill history and trip
assignment. A fill station hands Submersion a signed analysis record without
an account or a cloud service.

## 2. Decisions

Made during the brainstorming session on 2026-09-25. Do not reopen without a
reason.

| Question | Decision |
| --- | --- |
| Primary use | The diver's own cylinders first; the tag must also work for a rental or club fleet |
| Tag technology | QR labels and NFC read and write, both in phase 1 |
| Tag string | An https universal link; the custom scheme is also accepted but never written |
| Trust model | Ed25519, self-certifying station identity, trust on first use, keyed on the public key |
| Producer | Station mode inside the app, plus a documented open format for third parties |
| Trip assignment | An explicit synced `trip_equipment` link |
| Architecture | The tag carries an identity plus a spec snapshot; fill history, trip links and station pins live in the database; a roomy NFC tag also carries the newest signed record |

## 3. Goals

- A cylinder can carry a passport id, printed as a QR label or written to an
  NFC tag, and a scan on any supported platform opens its passport.
- The passport reads each fact from the system that owns it: spec from
  attributes, test status from the service clocks, mix from the newest fill,
  buoyancy from the tank physics, MOD and END from the gas model and the
  diver's ppO2 limits. It never contradicts the reminders or the dive log.
- A fill can be logged by hand or received as a signed record, and the
  record's origin is shown honestly: verified, first seen, key changed,
  blocked, or unsigned.
- Any Submersion install can act as a fill station and hand a record to a
  phone by QR, NFC or file, offline.
- The record and tag formats are documented so analyzer vendors and shop
  software can produce them with off-the-shelf libraries.
- A tank the diver has never seen opens a read-only passport from the tag
  alone and can be used on a dive without becoming equipment.
- Everything new syncs between the diver's devices and respects the equipment
  visibility rules (owner or sharee).

## 4. Non-goals

- A registry of fill stations, a server, an account, or any network call.
  The website's part is three static files.
- Putting the gas mix on the label. It changes every fill and lives in the
  newest fill record.
- Exporting a station's private key or moving a station identity between
  devices.
- A passport id on `dive_tanks`, "you have used this cylinder before", and
  rental memory across seasons. That is the fleet phase, filed separately.
- Turning a gas blender result into a signed record. Filed as a follow-up.
- UDDF export of fills. CSV joins in PR 5; the `.db` backup is a byte copy
  and already carries every table.
- Tags on gear other than cylinders. `trip_equipment` accepts any type, but
  the passport, labels and scanning are cylinder features.

## 5. What exists today

- Cylinders are `equipment` rows of type `tank` with attributes in the
  entity-attribute-value store `equipment_attributes`, keyed by
  `EquipmentAttrKeys`: `volume_l`, `working_pressure_bar`, `tank_material`,
  `valve_type`, `last_visual_inspection`, `last_hydro_test`, and the universal
  `tank_identifier`. The catalog (`equipment_attribute_catalog.dart`) defines
  them; adding a key needs no schema rung.
- Hydro, VIP and O2 clean are built-in `service_kinds` (`hydro`, `vip`,
  `o2-clean`) with clocks, reminders and a rollup shown on every gear surface
  through `ServiceStatusIndicator` (spec of 2026-09-22). The clocks, not the
  date attributes, are the truth about test status. A clock's baseline is
  `ServiceSchedule.anchorDate` with `anchorSetAt`, resolved by
  `clockAnchorFromServices` (v213 rule: a baseline set later outranks records).
- The transmitter registry made a physical serial the identity of a cylinder
  and `dive_tanks.equipment_id` links a dive's tank to its gear row.
- `DiveTankConfigAdapter.tankFromItem` builds a `DiveTank` snapshot from a
  cylinder configuration item; `TankPresets.matchBySpecs` matches a
  volume and pressure to a preset; `BuoyancyPhysics.tankTermKg` and
  `tankDryMassKg` give empty buoyancy and dry mass; `GasMix.mod`, `end` and
  `mnd` give the gas limits; `settings.ppO2MaxWorking` and `ppO2MaxDeco` are
  the diver's limits; `ExposureThresholds.highO2Fraction` is the high-O2
  threshold the exposure clocks use.
- Incoming files arrive through `FileShareHandler` (share sheet and Open
  with, mobile), `GlobalDropTarget` and `IncomingFileHandler` (desktop), and
  are sniffed by the universal import `FormatDetector`.
- `VisibilityFilter` (`lib/core/data/visibility/`) is the shared "owner or
  sharee" rule for equipment from the sharing program.
- The `cryptography` package is already a dependency (sync encryption,
  database key store) and provides Ed25519. The `barcode` and `qr` packages
  are already resolved through `pdf`.
- There is no QR scanner, no NFC dependency, no custom URL scheme, and the
  iOS Info.plist does not enable Flutter deep linking, so no URL reaches the
  router today.
- The router has a top-level `redirect` that gates on setup, and the app
  already queues an incoming file at cold start until the shell is ready.

## 6. The tag string

One payload, carried three ways: printed as a QR, written as an NFC NDEF URI
record, and pasted or typed as a link.

### 6.1 URL forms

The written form is always

```
https://submersion.app/c#<payload>
```

The app also accepts `submersion://c?<payload>`, and the payload in either the
fragment or the query of both forms. The custom scheme is never written to a
tag. The payload sits in the fragment so that a browser loading the static
page (when the app is not installed) never sends it to the server.

### 6.2 Payload

A query string of short keys, values percent-encoded with
`Uri.encodeQueryComponent`, keys emitted in the table order so two devices
produce the same string for the same cylinder. All values are metric; the app
converts for display. Everything but `f` and `p` is optional.

| Key | Meaning | Example |
| --- | --- | --- |
| `f` | format version | `1` |
| `p` | passport id, a UUID (Submersion mints v5), lower case | `8f3a5c1e-...` |
| `w` | date the tag was written, `YYYY-MM-DD` | `2026-09-25` |
| `n` | name or identifier, at most 40 characters | `Steel+12+L` |
| `sn` | stamped serial | `AB12345` |
| `v` | volume, litres, up to one decimal | `12` |
| `wp` | working pressure, bar, integer | `232` |
| `m` | material: `al`, `st`, `cf` | `st` |
| `vt` | valve: `din`, `yoke`, `conv` | `din` |
| `h` | last hydro test, `YYYY-MM-DD` | `2024-06-14` |
| `vi` | last visual inspection, `YYYY-MM-DD` | `2026-03-02` |
| `oc` | `1` when O2 clean at write time | `1` |

A full payload is at most 160 characters, a version 9 QR (53 modules) at
medium error correction, about half a millimetre per module on a 26 mm label.

`h`, `vi` and `oc` are written from the clocks: the newest `hydro` and `vip`
service record dates (or the schedule's baseline when it outranks them), and
`oc` when the `o2-clean` clock exists and is not overdue.

### 6.3 Parsing rules

The codec (`PassportPayloadCodec`) is total: it never throws on a tag.

- Unknown keys are ignored, so a future format still opens in an older app.
- `f` greater than 1 opens with a "written by a newer Submersion" note and
  only the keys this version knows.
- A missing or malformed `p` (not a UUID) is a rejected tag with a message.
- Out-of-range numbers are dropped, not trusted: volume outside 0.5 to 50 L,
  pressure outside 50 to 400 bar, an unparseable date.
- `n` is truncated to 40 characters on write and on read.

### 6.4 Fitting small NFC tags

The writer (`NdefFit`) knows the tag's capacity and drops optional keys in
this fixed order until the record fits: `n`, `sn`, `vi`, `h`, `oc`, `vt`,
`m`, `wp`, `v`. It never drops `f`, `p` or `w`. A 144-byte NTAG213 gets
identity only; NTAG215 and NTAG216 get everything.

The NDEF message holds, in order: the identity URI record; when room allows,
the newest signed fill record as a second URI record
(`https://submersion.app/f#<token>`, section 11); when room still allows, an
Android Application Record for `app.submersion` so Android opens this app
rather than asking. The reader processes URI records in order and ignores
records it does not know.

### 6.5 The passport id

Stored as the tank attribute `passport_id` (`EquipmentAttrKeys.passportId`),
minted as a UUID v5 of the equipment id (`kCylinderPassportNamespace`) the
first time the diver opens the passport, so two devices that mint before they
sync agree.
It syncs with the row, survives edits and a profile transfer, and needs no
schema rung. The catalog entry carries a new `AttributeGroup.system` group,
which the edit form does not render, so the id is never a text field a user
can mangle. The unique key `(equipment_id, attr_key, is_custom)` already
guarantees one id per item; `CylinderFillRepository.assignPassportId`
refuses an id already held by another cylinder visible to the diver.

"Link an existing tag" (Tag card) scans or pastes a tag and assigns its id to
this cylinder, so a recreated row keeps working with labels already on the
metal. It also re-links orphaned fills (section 10.8).

### 6.6 Staleness

Because `w` is on the tag, the passport compares it with the row: a `hydro` or
`vip` record dated after `w`, or a spec value that differs from the tag,
shows "Tag out of date" on the Tag card with Rewrite (NFC) and Reprint (QR).

## 7. Scanning and resolution

### 7.1 Entry points

1. A universal link, app link or NFC background tap lands on the `/c` route.
2. The Equipment list app bar gains Scan: camera QR on iOS, Android and
   macOS; an NFC tap sheet on phones; Paste link everywhere. The sheet is
   `PassportScanSheet`.
3. The dive edit tank editor (`tank_editor.dart`, beside its equipment pick)
   gains the same Scan action.
4. `/f` receives fill records (section 11).

### 7.2 Resolution

`PassportResolver` (domain service, no Flutter imports):

1. Parse with `PassportPayloadCodec`.
2. Look the passport id up among equipment visible to the active diver
   (`VisibilityFilter`), through the `(attr_key, value_text)` index.
3. Hit: `PassportResolution.own(equipmentId, payload)`. The caller navigates
   to `/equipment/:equipmentId/passport` and passes the payload for the
   staleness check.
4. Miss: `PassportResolution.foreign(payload)`. The caller opens the foreign
   passport (section 9).
5. A rejected tag: `PassportResolution.invalid(reason)`, shown as a snack bar
   with the reason and a Paste link retry.

From the tank editor a hit sets the tank's `equipmentId`, copies the spec and
prefills the gas mix from the newest fill; a miss prefills the spec from the
snapshot and the mix from any fill record that arrived with it.

## 8. The passport page

`PassportPage` at `/equipment/:equipmentId/passport`, in
`lib/features/cylinder_passports/presentation/pages/`. The tank's detail page
gets `PassportEntryCard`: QR thumbnail, newest mix, and Open passport. Every
card names its source of truth. Every value with a unit goes through
`UnitFormatter`.

| Card | Shows | Source |
| --- | --- | --- |
| Header | name, identifier, brand and model, serial, material chip, owner when shared | `EquipmentItem` and attributes |
| Spec | volume, working pressure, material, valve; free gas at working pressure; empty and full buoyancy | attributes; the diver's gas model via `gas_compressibility`; `BuoyancyPhysics.tankTermKg` minus the gas mass |
| Service | hydro, VIP, O2 clean: last date, due date, severity | `ServiceStatusIndicator` in `full` density per clock, the rollup provider; O2 clean untracked shows "Track O2 cleaning", which attaches the built-in `o2-clean` schedule |
| O2 warning | banner when the newest fill's O2 fraction exceeds `ExposureThresholds.highO2Fraction` and the O2 clean clock is untracked or overdue | fills and clocks |
| Current fill | mix name, analyzed O2 and He, pressure, temperature, date, station and verification badge; MOD at `ppO2MaxWorking` and at `ppO2MaxDeco`; END at the working MOD for helium mixes; Log a fill; Scan a fill record | newest `cylinder_fills` row, `GasMix`, settings |
| Fill history | newest first, badge per row, count since the last hydro, delete | `cylinder_fills` |
| Trip | "Packed for <trip>" chip, nearest upcoming or in-progress first, "+N" for the rest; Assign, Unassign | `trip_equipment` |
| Tag | QR preview of the current payload; Print label; Print labels for selected (from the list's multi-select); Write NFC tag; Link an existing tag; staleness hint | codec, `PassportLabelPdfService`, `NfcTagService` |

Log a fill is `LogFillSheet`: date and time, O2, He, pressure, temperature,
station name (free text, recent names suggested), analyzer (remembered),
notes. Source `manual`.

## 9. The foreign passport

`ForeignPassportPage`, opened on a resolver miss, shows the snapshot with "as
written on the tag on <w>" beside every date, the O2 clean flag, and any fill
record that arrived on the same tag or a following scan. Two actions:

- **Use on a dive.** Opens the dive edit flow (a new dive, or the dive being
  edited when the scan came from the tank editor) with a `DiveTank` prefilled
  from the snapshot: name from `n`, volume, working pressure, material,
  `presetName` from `TankPresets.matchBySpecs`, and the mix from the fill
  record when present. No equipment row is created, consistent with the
  rental gear memory decision that rental gear is not equipment.
- **Add to my gear.** For a cylinder the diver really owns (bought used, or a
  club tank they now manage). Creates a `tank` equipment row with the spec
  attributes and the passport id, attaches the `hydro` and `vip` schedules
  and sets their `anchorDate` from `h` and `vi` with `anchorSetAt` now, and
  attaches `o2-clean` when `oc` is set. It never fabricates `ServiceRecord`
  rows from a sticker. Fills already stored under that passport id are
  re-linked (section 10.8).

## 10. Data

### 10.1 `passport_id` attribute

Section 6.5. New index in `performance_indexes.dart`:

```
CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_text
  ON equipment_attributes(attr_key, value_text)
```

### 10.2 `cylinder_fills`

A top-level clocked entity, modelled on `transmitters` (v200).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | uuid |
| `diver_id` | TEXT nullable | FK `divers.id`, same convention as `transmitters` |
| `passport_id` | TEXT | the physical cylinder; text, not a foreign key |
| `equipment_id` | TEXT nullable | FK `equipment.id`, ON DELETE SET NULL |
| `filled_at` | INTEGER | epoch ms |
| `o2_percent` | REAL | analyzed |
| `he_percent` | REAL | analyzed, default 0 |
| `pressure_bar` | REAL nullable | |
| `temperature_c` | REAL nullable | gas temperature at the reading |
| `analyzer` | TEXT nullable | |
| `station_name` | TEXT nullable | as entered, or as signed |
| `station_key` | TEXT nullable | base64url Ed25519 public key from the record |
| `signed_record` | TEXT nullable | the JWS token verbatim |
| `source` | TEXT | `manual`, `qr`, `nfc`, `file`, `link`, `issued` |
| `notes` | TEXT | default `''` |
| `created_at`, `updated_at` | INTEGER | epoch ms |
| `hlc` | TEXT nullable | own clock |

Indexes: `(passport_id, filled_at)` and `(equipment_id)`.

Invariants the repository enforces:

- When `signed_record` is present, `o2_percent`, `he_percent`,
  `pressure_bar`, `temperature_c`, `analyzer`, `station_name` and
  `station_key` are copies of the verified payload, denormalised for queries.
  The token is the truth; a mismatch on read is reported as corruption.
- A token whose signature does not verify against its own embedded key is
  refused (integrity). A token from an unknown or blocked station is stored
  (attribution is decided at read time).
- Verification state is never stored. `FillTrustEvaluator` computes it at
  read time from the token and `fill_stations`, so a later Trust or Block
  re-colours the whole history without a migration.
- `equipment_id` is resolved from `passport_id` on write and re-resolved by
  "Link an existing tag" and "Add to my gear".

### 10.3 `fill_stations`

The trust-on-first-use pins. A top-level clocked entity.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | uuid |
| `diver_id` | TEXT nullable | FK `divers.id` |
| `public_key` | TEXT | base64url Ed25519; unique per diver |
| `name` | TEXT | as first seen; editable |
| `trust` | TEXT | `trusted` or `blocked` |
| `first_seen_at`, `last_seen_at` | INTEGER | epoch ms |
| `notes` | TEXT | default `''` |
| `created_at`, `updated_at` | INTEGER | |
| `hlc` | TEXT nullable | |

Unique index on `(diver_id, public_key)`. The key is the identity; the name
is a label. The pin rule is in section 11.2.

### 10.4 `trip_equipment`

A parent-gated child of `trips`, modelled on `equipment_shares` (v219).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | uuid |
| `trip_id` | TEXT | FK `trips.id`, ON DELETE CASCADE |
| `equipment_id` | TEXT | FK `equipment.id`, ON DELETE CASCADE |
| `created_at` | INTEGER | |
| `hlc` | TEXT nullable | |

Unique index on `(trip_id, equipment_id)`, index on `equipment_id`. Any
equipment type may be packed. Phase 1 exposes it from the passport's Trip
card and a Gear section on `trip_detail_page.dart` that uses
`EquipmentPickerSheet`.

### 10.5 Station identity

Not a table. The Ed25519 private key lives in `flutter_secure_storage` under
a fixed key and never syncs. The public key (base64url) and the station
display name are device-local settings (`shared_preferences`), not diver
settings, because the station is the device. A shop with two tablets is two
keys under one name, which the pin rule accepts.

### 10.6 Schema rungs

One rung per PR that adds a table (1a, 3, 4), each following the ladder
convention: an idempotent `_assertXTable()` through
`createMigrator().createTable`, `if (from < N)` in `onUpgrade`, the
`currentSchemaVersion` constant, the `migrationVersions` list, the
`@DriftDatabase(tables: [...])` list, and every index asserted both in the
migration helper and in `performance_indexes.dart`. No backfill: no existing
row changes. Version numbers are assigned when each plan is written, because
other PRs are in flight (226 was current on 2026-09-25).

### 10.7 Sync

`cylinder_fills` and `fill_stations` register as top-level clocked entities,
copying `transmitters`; `trip_equipment` registers as a parent-gated child,
copying `equipment_shares`:

- `sync_repository.dart` HLC target registry.
- `sync_service.dart`: `mergeOrder` (fills after `equipment` and `divers`;
  stations after `divers`; trip rows after `trips` and `equipment`), the
  clocked-entity flag, `parentRefs` (`cylinder_fills.equipment_id` nullable
  with set-null semantics; both `trip_equipment` keys required).
- `sync_data_serializer.dart`: the `SyncData` field and every arm (ctor,
  `toJson`, `fromJson`, hlc target, export, `fetchRecord(s)`,
  `upsertRecord(s)`, `recordIdsFor`, `_tableFor`, `deleteRecord`), plus
  `parentGatedChildEntities` and `parentGatedRecordId` for `trip_equipment`.
- `conflict_reference.dart` foreign-key-name map.
- Tombstones: deleting a fill, a pin or a trip row logs a deletion;
  `deleteEquipment` selects the item's `trip_equipment` rows before the
  delete and logs one each, as it does for `equipmentComponents`.
- `markRecordPending` runs after the batch closure, never inside it.
- The serializer batch coverage test and the streaming parity tests gain
  entries for each entity.

### 10.8 Visibility and deletion

- Fills and trip rows are read through their equipment's visibility (owner or
  sharee). A fill with no `equipment_id` is visible to the diver who logged
  it (`diver_id`).
- Deleting a cylinder nulls `equipment_id` on its fills and keeps
  `passport_id`; "Link an existing tag" and "Add to my gear" re-link every
  fill under that id to the new row.
- Deleting a trip cascades its `trip_equipment` rows. Deleting equipment
  cascades them too.
- Diver deletion follows the `transmitters` convention for `diver_id`.

## 11. The signed fill record

### 11.1 Format

A fill record is a JWS in compact serialization (RFC 7515) signed with
Ed25519 (EdDSA, RFC 8037). `FillRecordCodec` lives in
`lib/core/services/fill_record/` because the consumer and the producer both
use it.

Protected header:

```json
{"alg":"EdDSA","typ":"sfr+json","jwk":{"kty":"OKP","crv":"Ed25519","x":"<base64url public key>"}}
```

Payload, all metric:

| Field | Meaning | Required |
| --- | --- | --- |
| `v` | record format version, `1` | yes |
| `id` | record UUID, the dedupe key | yes |
| `cyl` | passport id | no |
| `t` | analysis time, RFC 3339, UTC | yes |
| `o2` | analyzed O2, percent | yes |
| `he` | analyzed He, percent | yes |
| `p` | fill pressure, bar | no |
| `tc` | gas temperature, C | no |
| `an` | analyzer | no |
| `op` | operator | no |
| `st` | station display name | yes |
| `n` | note, at most 140 characters | no |

Encoding: `base64url(header) . base64url(payload) . base64url(signature)`,
the signature over the ASCII of the first two parts joined by `.`, exactly as
JWS specifies. The receiver verifies against the header's `jwk` first, parses
second, then applies the pin rule. Because the signature covers the bytes as
transmitted there is no JSON canonicalisation.

Rejected outright, with a message: any `alg` other than `EdDSA`; a missing
`jwk`, or one that is not `OKP`/`Ed25519`; a bad signature; a payload that
is not JSON or lacks a required field; `v` with an unknown major version.
Unknown payload fields are ignored. A `t` more than 24 hours in the future
is stored with a "clock ahead" note, not rejected. A repeated `id` is a
no-op, so two phones scanning one screen, or one phone scanning twice, never
double-log.

A record without `cyl` asks which cylinder it belongs to (visible cylinders,
newest-used first) or offers Use on a dive.

### 11.2 Verification and the pin rule

`FillTrustEvaluator` takes a token, the pins, and now, and returns a
`FillVerification`:

| Result | When | Badge |
| --- | --- | --- |
| `verified` | key K is pinned `trusted` | Verified, station name from the pin, "(signs as N)" when the signed name differs |
| `firstSeen` | K unknown, no pin named N | pins K as N `trusted`, Verified with "first seen <date>" |
| `keyChanged` | K unknown, a pin named N exists | stored; badge Key changed with Trust (pin K as N too) and Block |
| `blocked` | K pinned `blocked` | Blocked, greyed, warning icon |
| `unsigned` | no token | Unsigned |

Invalid tokens are never stored; the import reports why. Badge colours come
from `StatusColors` (`ok`, `warn`, `alert`) and each badge carries text and
semantics, never colour alone. Because theme presets collapse secondary
roles, the badge widget is tested across every preset in both brightnesses.

### 11.3 Carriers

- URL: `https://submersion.app/f#<token>`, shown as a QR on the station
  screen, written as the second NDEF record on a roomy tag, or sent as a
  link. `submersion://f?<token>` is accepted, never written.
- File: `<station>-<date>-<mix>.sfr`, content is the token as text. Shared
  through `share_plus`, received through the existing share-sheet, Open with,
  drop-target and incoming-file paths.

### 11.4 Import paths

- `/f` route: verify, evaluate, store, then open the passport of `cyl` (own),
  the foreign passport (unknown `cyl`), or the cylinder picker (no `cyl`).
- `FormatDetector` learns the JWS shape (`typ` of `sfr+json` in a decoded
  header) and routes the file to the fill importer instead of the dive
  wizard.
- The NFC reader hands a second URI record to the same importer.
- Scan a fill record on the passport page opens the scan sheet expecting
  `/f`; a `/c` tag scanned there is resolved normally instead.

## 12. Station mode

`FillStationPage` at `/planning/fill-station`, beside the gas calculators,
in `lib/features/fill_station/`.

- **First run.** Name the station; `StationIdentityService` generates the
  keypair. The identity card shows the name and a short fingerprint (the first
  eight base32 characters of the SHA-256 of the public key, grouped in fours)
  so a diver can compare it with the pin in their passport.
- **Issue a record.** Scan the cylinder tag or Skip; enter O2 and He (the
  analyzer and operator are remembered), pressure, temperature; Sign. The
  result screen is a high-contrast full-screen QR of the `/f` URL with Write
  to tag (phones) and Share file beneath it. Next cylinder keeps the station
  fields and clears the mix and pressure.
- **Station log.** Every issued record is saved to `cylinder_fills` with
  source `issued`, `passport_id` from the scanned tag (or empty when skipped),
  `equipment_id` resolved when the station owns the cylinder. The page lists
  today's issued records.
- **Reset station identity** is behind a confirmation and explains that
  returning customers will see Key changed once. Private keys are never
  exported.

## 13. Platform plumbing

### 13.1 Dependencies

Two new packages: `mobile_scanner` (camera QR on iOS, Android, macOS) and
`nfc_manager` (iOS, Android). QR generation uses the already-resolved
`barcode` and `qr` packages: an on-screen `CustomPainter` over the same
encoder, and `pw.BarcodeWidget` in the PDF label.

### 13.2 Universal links and routes

- iOS `Info.plist`: `FlutterDeepLinkingEnabled` true (absent today);
  `CFBundleURLTypes` gains the `submersion` scheme.
- `Runner.entitlements`: `com.apple.developer.associated-domains` with
  `applinks:submersion.app`.
- Android manifest: an intent filter with `android:autoVerify="true"` for
  `https` on `submersion.app` with `pathPrefix` `/c` and `/f`, and a filter
  for the `submersion` scheme.
- go_router: top-level `/c` and `/f` routes that read `state.uri.fragment`,
  falling back to `state.uri.query`. The existing top-level `redirect` gates
  on setup; an incoming link before the shell is ready is queued and replayed
  the same way an incoming file is.
- Whether Flutter hands the fragment through intact on both platforms is
  verified on device in PR 1b. If any carrier strips it, the writer uses the
  query for that carrier and section 6.1 records the exception.

### 13.3 NFC

- iOS: `NFCReaderUsageDescription`; entitlement
  `com.apple.developer.nfc.readersession.formats` with `NDEF`. With the
  associated domain verified, background tag reading opens the app on a tap
  with nothing running.
- Android: `android.permission.NFC`; `<uses-feature android:name=
  "android.hardware.nfc" android:required="false"/>`; an
  `NDEF_DISCOVERED` filter on the host and `/c` path so a tap launches the
  app.
- `NfcTagService` wraps `nfc_manager`: read (NDEF message to URI records),
  write (capacity, `NdefFit`, identity record, optional second record and
  AAR, then read back to confirm). The sheet reports the tag type, capacity
  and which fields fit. Docs recommend NTAG215 or NTAG216.
- Desktop and iPads without NFC show the NFC actions disabled with a reason.

### 13.4 Camera

- The iOS `NSCameraUsageDescription` gains "and to scan cylinder labels";
  App Review reads it.
- macOS `DebugProfile.entitlements` and `Release.entitlements` gain
  `com.apple.security.device.camera`.
- A denied permission drops the scan sheet to Paste link and, on phones, the
  NFC option; the sheet links to the system settings.

### 13.5 Desktop

Windows and Linux: no camera scanning (`mobile_scanner` does not support
them). They get Paste link, `.sfr` files through `GlobalDropTarget` and
`IncomingFileHandler`, label printing, and station mode, which matters
because a shop PC at the fill panel is the likeliest station. macOS gets
everything except NFC.

### 13.6 Website deliverable

Outside this repository, on submersion.app, and live before the release that
carries PR 1b:

- `/.well-known/apple-app-site-association`: the app id and the paths `/c`,
  `/c/*`, `/f`, `/f/*`.
- `/.well-known/assetlinks.json`: package `app.submersion` with the release
  and debug signing certificate fingerprints.
- Static `/c` and `/f` pages: parse the fragment in the browser, render the
  spec or the record's payload (verifying with WebCrypto Ed25519 where the
  browser supports it, otherwise labelled "not verified here"), show Open in
  Submersion and the store links. No analytics, no server processing, no
  form.

Until they are live, in-app scanning and the custom scheme work; a phone
without the app scanning a printed label reaches a 404.

## 14. Documentation deliverable

Two pages in `docs/import-formats/`: the tag page lands with PR 1a, the
record page with PR 3:

- `cylinder-passport-tag.md`: the URL forms, the payload table, parsing
  rules, the small-tag drop order, the NDEF layout, a worked example.
- `fill-record.md`: the JWS profile, the payload table, rejection rules, the
  pin rule, the carriers, a worked example, and a test vector (key, token,
  expected payload) computed with an independent implementation, with the
  implementation named.

## 15. Error handling

- A tag that fails to parse is reported with the reason and never stored.
- A token that fails verification is reported with the reason and never
  stored; a token from a blocked station is stored and shown Blocked.
- An NFC write that fails read-back reports the tag as not written and
  offers Retry; a partial write is retried from the start (NDEF messages are
  written whole).
- Camera and NFC permission failures degrade to the other carriers, with a
  link to system settings.
- A passport id collision on assign or link is refused with the other
  cylinder's name.
- Universal link arrival during setup is queued, never dropped.
- Corrupt denormalised columns beside a valid token are reported as a
  data-quality finding, and the token wins on display.

## 16. Testing

Tests first throughout, per the project rule.

- **Codec.** Round trips over every key; missing and unknown keys; `f` of 2;
  malformed and missing `p`; out-of-range numbers; names with spaces, `&`,
  `#` and non-ASCII; the drop order against NTAG213, 215 and 216 capacities;
  both URL forms with fragment and query.
- **Resolver.** Hit, miss, invalid; owner, sharee, stranger; duplicate id
  refusal on assign and link.
- **Repositories.** In-memory Drift: fills CRUD, newest fill per passport,
  orphan re-link on Add to my gear and Link, delete semantics, denormalised
  copy invariant; pins CRUD and the unique key; trip rows and cascades.
- **Schema.** A ladder test per rung; index assertions; the
  `migrationVersions` and `currentSchemaVersion` literals.
- **Sync.** Serializer batch coverage and streaming parity entries per
  entity; tombstones; parent gating for `trip_equipment`; pending marks
  after the batch.
- **Crypto and trust.** Sign and verify against vectors computed with an
  independent implementation (OpenSSL or PyNaCl, named in the vector file),
  never invented. Tampered payload, tampered header, wrong key, wrong `alg`,
  missing `jwk`, future `t`, duplicate `id`. The pin rule as a state table
  with three or more stations, two of them sharing a name, since two-row
  tests hid a bug in the identity label work.
- **Routing.** `/c` and `/f` with fragment and query on both URL forms;
  cold-start queueing through the setup redirect.
- **Widgets.** The passport page in every state (no fills, unsigned,
  verified, first seen, key changed, blocked, O2 warning, stale tag); the
  foreign passport; the station mode flow; imperial units on every value;
  badge colours across every theme preset in both brightnesses; the label
  PDF renders a scannable QR (decode the rendered bitmap with the `qr`
  decoder in the test).
- **Guards.** `test/architecture/` after any new file under `lib/`; the l10n
  gate across all 11 locales.
- **Hardware checklist.** A document like
  `2026-09-18-media-sync-manual-test-checklist.md` covering: NFC read and
  write on iPhone and Android, background launch from a tap with the app
  closed, camera scan on all three platforms, printed label scan at 25 mm,
  station QR to phone handoff, `.sfr` over AirDrop and email, and the
  website fallback on a phone without the app. None of this runs in CI.

## 17. Delivery

Six PRs, each based on main, each with its own plan written only after the
previous one merges, each closing its own issue and referencing the umbrella #2333.

| PR | Issue | Scope | Rung | Needs |
| --- | --- | --- | --- | --- |
| 1a Passport core | #2334 | `passport_id` attribute, `AttributeGroup.system`, index; `PassportPayloadCodec` and `NdefFit`; `cylinder_fills` table, repository, sync; `LogFillSheet`; `PassportPage` and `PassportEntryCard` (spec, buoyancy, service, O2 warning, current fill, history, tag card); on-screen QR; `PassportLabelPdfService` with the multi-label sheet; Link an existing tag; `cylinder-passport-tag.md` | yes | main |
| 1b Scan and links | #2335 | `/c` and custom-scheme routes and queueing; iOS and Android link plumbing; `mobile_scanner` with `PassportScanSheet` and Paste link; `PassportResolver`; `ForeignPassportPage` with Use on a dive and Add to my gear; tank editor Scan | no | 1a |
| 2 NFC | #2336 | `nfc_manager`, `NfcTagService`; read, background launch filters; write with capacity and read-back; staleness hint with Rewrite and Reprint | no | 1b |
| 3 Signed records | #2337 | `FillRecordCodec` with vectors; `StationIdentityService`; `FillStationPage`; `/f` route; `FormatDetector` and `.sfr` share; `fill_stations` table, repository, sync; `FillTrustEvaluator` and badges with Trust and Block; second NDEF record write and read; `fill-record.md`; hardware checklist | yes | 2 |
| 4 Trip assignment | #2338 | `trip_equipment` table, repository, sync; passport Trip card; trip page Gear section | yes | 1a |
| 5 CSV round trip | #2339 | fills in the Submersion CSV bundle: writer, signature, parser, round-trip test | no | 1a |

PRs 4 and 5 can run in parallel with 1b onward. The website deliverable
(13.6) is tracked on #2333 and must be live before the release
that carries 1b.

## 18. Out of scope and follow-ups

Filed as their own issues, not part of this program:

- Fleet phase: `dive_tanks.passport_id` (with the `_tankCompanion` and
  bulk-undo `_tanksFromRows` paths and sync), "you have used this cylinder N
  times", rental memory across seasons.
- A signed record from a gas blender result, and linking a fill to a billed
  fill in the blender's invoice archive.
- UDDF export of fills.
- Explicit station key exchange (scanning a station identity QR before its
  records count). The fingerprint on the identity card is the manual form.
- Tags and passports for gear other than cylinders.

## 19. Assumptions verified at plan time

- Flutter delivers the URL fragment to go_router on iOS universal links and
  Android app links (13.2). Fallback documented.
- `nfc_manager` exposes tag capacity before writing on both platforms; if
  not, `NdefFit` writes the full record and falls back through the drop
  order on a size error.
- `mobile_scanner` builds and scans on macOS with the current Flutter SDK
  pin; otherwise macOS joins the desktop Paste-link tier for PR 1b and
  camera scanning on macOS becomes a follow-up.
- The `barcode` package's QR encoder handles a 450-character `/f` URL at
  medium error correction (it should reach version 20 or so); otherwise the
  station QR drops to low error correction.
- `VisibilityFilter` offers an equipment clause the resolver can reuse; if
  it is still `diver_id = ?` on main, the resolver uses that and the sharing
  program's PR 2 swaps it.
- Schema version numbers, checked against main when each plan is written.
