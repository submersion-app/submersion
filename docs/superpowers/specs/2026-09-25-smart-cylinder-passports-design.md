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
| Trust model | Ed25519, self-certifying station identity, trust on first use, keyed on the public key (deferred 2026-09-28, section 18) |
| Producer | The diver's own app writes fills to the tag, plus a documented open format for third parties; station mode deferred (2026-09-28, section 18) |
| Trip assignment | An explicit synced `trip_equipment` link |
| Architecture | The tag carries an identity plus a spec snapshot; fill history and trip links live in the database; an NFC tag also carries the newest fill |
| Fill handoff (revised 2026-09-28) | Phase 3 starts simple: the diver's own app writes the newest fill into the tag's passport link, unsigned, and every tap picks it up. Signing, trust pins and station mode are deferred (section 18); the format reserves a signature field so they can follow without breaking tags |

## 3. Goals

- A cylinder can carry a passport id, printed as a QR label or written to an
  NFC tag, and a scan on any supported platform opens its passport.
- The passport reads each fact from the system that owns it: spec from
  attributes, test status from the service clocks, mix from the newest fill,
  buoyancy from the tank physics, MOD and END from the gas model and the
  diver's ppO2 limits. It never contradicts the reminders or the dive log.
- A fill can be logged by hand, or from the trimix blender's result, and
  written onto the cylinder's NFC tag; any phone that taps the tag sees it,
  labelled for what it is (from the tag, who filled it, analyse before
  diving).
- The tag format is documented so analyzer vendors and shop software can
  write it with off-the-shelf libraries.
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
- Turning a gas blender result into a signed record (signing waits, section
  18). An unsigned fill logged from the blender is in phase 3 (section 11).
- UDDF export of fills. CSV joins in PR 5; the `.db` backup is a byte copy
  and already carries every table.

  Decided 2026-09-29 (PR 5): there is no multi-file CSV "bundle" in the
  code. The app has three self-describing Submersion CSVs (dives, sites,
  equipment), each with a header signature and a parser, plus an
  export-only gear check-ins CSV. Fills get their own fourth Submersion
  CSV, one row per fill: an entry in the CSV export sheet
  (`CsvExportType.fills`), a header signature (`SubmersionCsvKind.fills`),
  a format (`ImportFormat.submersionFillsCsv`), a parser and a Fills group
  in the import wizard. A fills file imports on its own and also batches
  with the equipment CSV.
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
| `fi` | newest fill: its id, a UUID, the dedupe key | `3f0c2b8e-...` |
| `ft` | fill time, RFC 3339 UTC to the second | `2026-09-28T09:30:00Z` |
| `fo` | fill O2, percent | `32.1` |
| `fh` | fill He, percent, default 0 | `0` |
| `fp` | fill pressure, bar | `232` |
| `fc` | gas temperature at the reading, C | `24.5` |
| `fb` | filled by (a person or a station), at most 40 characters | `Blue+Hole` |
| `fa` | analyzer, at most 40 characters | `Divesoft` |
| `fs` | reserved for a future signature; ignored | |

The `f`-prefixed fill keys (decided 2026-09-28) carry the cylinder's newest
fill on an NFC tag only: a printed label never has them, because the fill
changes every time the cylinder is filled. They sit in the passport link
itself, not a second record, because iOS and Android hand an app only the
first link of a tapped tag. A fill is present when `fi`, `ft` and `fo` are
all valid (a UUID, an RFC 3339 time, an O2 above 0 with O2 plus He at most
100); anything less drops the whole fill, never the tag.

A full payload without a fill is at most 160 characters, a version 9 QR (53 modules) at
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
this fixed order until the record fits: the fill's `fa`, `fb` and `fc`,
then the whole fill, then `n`, `sn`, `vi`, `h`, `oc`, `vt`, `m`, `wp`, `v`.
It never drops `f`, `p` or `w`. A 144-byte NTAG213 gets identity only;
NTAG215 and NTAG216 get everything, a fill included (about 270 bytes).

On a phone the capacity is the NDEF message size the platform reports for
the tag (`Ndef.maxSize`), which already excludes the Type 2 TLV wrapper
that `NdefFit.fit` counts for a bare tag (decided 2026-09-27).

The NDEF message holds, in order: the identity URI record (with the newest
fill in it, section 11); when room allows, an Android Application Record for
`app.submersion` so Android opens this app rather than asking. The reader
processes URI records in order and ignores records it does not know.

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
4. `/f` fill record links are deferred (section 18).

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

From the tank editor a hit copies the spec, prefills the gas mix from the
newest fill, and adds the cylinder to the dive's gear list. It never writes
`dive_tanks.equipment_id`, which the transmitter registry owns (decided
2026-09-26). A miss prefills the spec from the snapshot and the mix from any
fill record that arrived with it.

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
| Current fill | mix name, analyzed O2 and He, pressure, temperature, date, who filled it and, for a fill read from a tag, a From tag chip; MOD at `ppO2MaxWorking` and at `ppO2MaxDeco`; END at the working MOD for helium mixes; Log a fill; Scan a fill record | newest `cylinder_fills` row, `GasMix`, settings |
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
  re-linked (section 10.8). Because of that re-link, it refuses, creating
  nothing, when a cylinder anywhere in the library that is still in service
  holds the id, not only one visible to the diver; a retired or sold holder
  does not block (decided 2026-09-26).

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
| `station_key` | TEXT nullable | reserved for signed records (section 18); unused |
| `signed_record` | TEXT nullable | reserved for signed records (section 18); unused |
| `source` | TEXT | `manual`, `qr`, `nfc`, `file`, `link`, `issued` |
| `notes` | TEXT | default `''` |
| `created_at`, `updated_at` | INTEGER | epoch ms |
| `hlc` | TEXT nullable | own clock |

Indexes: `(passport_id, filled_at)` and `(equipment_id)`.

Invariants the repository enforces:

- When signing ships (section 18) and `signed_record` is present, `o2_percent`, `he_percent`,
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

Decided 2026-09-29 (PR 5, the fills CSV):

- Columns: everything except the reserved `station_key` and
  `signed_record`. That is the fill id, the passport id, the linked
  cylinder's name and serial (display only, ignored on import), date and
  time, O2 %, He %, pressure and temperature in the export's units (the unit
  in the header, like the other sheets), filled by (`station_name`),
  analyzer, source and notes.
- Identity: import KEEPS the fill id, unlike the other CSVs, which mint
  ids. A row whose id already exists here, or was deleted here (deletion
  log), is skipped, the same rule `TagFillImporter` applies to a fill read
  from a tag. A row without an id is a hand-added one and is given a fresh
  id.
- Linking: a fill is linked to the importing diver's cylinder that holds
  its passport id (`CylinderPassportRepository.findEquipmentIdByPassportId`
  scoped to the diver); otherwise `equipment_id` stays null and the fill
  is relinked when a cylinder gets that id. `diver_id` is the importing
  diver. `source` is kept as written (`FillSource.fromName`, unknown text
  reads as `manual`).
- Export scope: every fill the diver can see under section 10.8 (linked to
  a cylinder the diver owns or has been shared, or unlinked and logged by
  the diver), newest first.

### 10.3 `fill_stations`

Deferred with signing (section 18, decided 2026-09-28); kept here as the
design to start from. The trust-on-first-use pins. A top-level clocked
entity.

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
is a label. The pin rule moves with signing to section 18.

### 10.4 `trip_equipment`

A parent-gated child of `trips`, modelled on `equipment_shares` (v234).

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

Decided 2026-09-29: a cylinder's passport Trip card also lists the trips
where the cylinder is a trip gas slot (`trip_cylinders.equipment_id`), so
it reads "Packed for <trip>" either way. Assign and Unassign on the card
touch `trip_equipment` only; a slot stays the cylinder board's business.
The trip page's Gear card sits right after the Cylinders card. Schema
v248 (246 and 247 were held by open PRs).

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

`cylinder_fills` (and `fill_stations`, when signing ships) register as top-level clocked entities,
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

## 11. The newest fill on the tag

Decided 2026-09-28, replacing the signed fill record and station mode, which
move to section 18.

- **Writing.** Log a fill (section 8) gains, on a phone with NFC, a "Write
  it to the tank's tag?" step after Save. The Tag card's Write NFC tag and
  Rewrite always include the cylinder's newest fill. The fill keys carry
  the fill row's own id, so reading the tag back never duplicates it.
- **Reading.** Every tag the app opens, whether by a tap with the app closed,
  a link, or an in-app scan, is checked for a fill:
  - an own cylinder (`OwnCylinder`) stores it in `cylinder_fills` with
    source `nfc`, unless a fill with that id exists or was deleted (a
    tombstone), and says so ("Fill from the tag added");
  - a foreign cylinder shows it on the foreign passport and uses its mix
    for Use on a dive, without storing it: a buddy's or a rental's fill is
    not the diver's history.
- **Labelling.** A fill that came from a tag shows a "From tag" chip, who
  filled it (`fb`) and "Analyse before you dive". Nothing is signed, so
  nothing is called verified.
- **Trimix blender.** The Cylinder card gains Choose cylinder (the diver's
  tanks, or Scan tag), which fills in the cylinder's size and its newest
  fill's mix as what is already in it. The Fill procedure gains Log this
  fill, which asks which cylinder, then opens Log a fill prefilled with the
  target mix (with "enter your analysed values"), the target pressure and
  the settled temperature, and ends with the same Write to tag step.
- **Deferred** (section 18): station mode and a station log, the on-screen
  QR, `.sfr` files and `/f` links, signing and trust pins, and the website's
  `/f` page.

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
- Links arrive through the `app_links` package; Flutter's own deep linking is
  off on iOS (`FlutterDeepLinkingEnabled` false) and Android
  (`flutter_deeplinking_enabled` false), because it passes only path, query
  and fragment and so dropped the `submersion://c` host (decided 2026-09-26).
  A dispatcher accepts passport tags only, drops a repeat of the same link
  within two seconds, and holds a link that arrives before any diver exists
  until setup finishes.
- Whether each carrier hands the fragment through intact is verified on
  device (the 1b device checklist). If any carrier strips it, the writer uses
  the query for that carrier and section 6.1 records the exception.

### 13.3 NFC

- iOS: `NFCReaderUsageDescription`; entitlement
  `com.apple.developer.nfc.readersession.formats` with `TAG` only
  (`nfc_manager` 4 reads and writes through `NFCTagReaderSession`, which
  needs `TAG`; decided 2026-09-27). `NDEF` must not be listed: App Store
  Connect rejects an upload whose entitlement still names it (ITMS-90778,
  "NDEF is disallowed"; decided 2026-09-28). With the associated domain verified,
  background tag reading opens the app on a tap with nothing running.
  NFC Tag Reading must be enabled for the app id in the Apple developer
  portal before a signed build.
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

Passport links do not open the app on Windows or Linux: neither installer
registers the `submersion` protocol or the https app link, so the app does
not listen for links there, and a label read on those machines goes through
Paste link (decided 2026-09-27).

### 13.6 Website deliverable

Outside this repository, on submersion.app, and live before the release that
carries PR 1b:

- `/.well-known/apple-app-site-association`: the app id and the paths `/c`,
  `/c/*`, `/f`, `/f/*`.
- `/.well-known/assetlinks.json`: package `app.submersion` with the release
  and debug signing certificate fingerprints.
- Static `/c` and `/f` pages: parse the fragment in the browser, render the
  spec, show Open in Submersion and the store links. No analytics, no server
  processing, no form. The `/c` page shows a tag's fill keys (section 6.2);
  a full `/f` page, and verifying signed records with WebCrypto Ed25519,
  wait for the carriers and signing in section 18.

Until they are live, in-app scanning and the custom scheme work; a phone
without the app scanning a printed label reaches a 404.

## 14. Documentation deliverable

Two pages in `docs/import-formats/`: the tag page lands with PR 1a, the
record page with PR 3:

- `cylinder-passport-tag.md`: the URL forms, the payload table, parsing
  rules, the small-tag drop order, the NDEF layout, a worked example.
- The tag page gains the fill keys (section 6.2) and their drop order.
  `fill-record.md` (the signed record) waits for signing (section 18).

## 15. Error handling

- A tag that fails to parse is reported with the reason and never stored.
- A tag whose fill keys are invalid opens normally without the fill; the
  fill is dropped, never the tag. (Signed-token errors wait for signing.)
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
- **Fill on the tag.** Codec round trips with and without a fill; a fill
  missing `fi`, `ft` or `fo`, or with O2 plus He over 100, is dropped and
  the tag still opens; the drop order against NTAG213, 215 and 216; reading
  an own tag stores the fill once (a second read, a synced copy and a
  deleted fill are all no-ops); a foreign tag's fill is shown, not stored.
  (Crypto vectors and the pin-rule state table wait for signing.)
- **Routing.** `/c` with fragment and query on both URL forms;
  cold-start queueing through the setup redirect.
- **Widgets.** The passport page in every state (no fills, a fill from a
  tag, O2 warning, stale tag); the foreign passport with and without a fill;
  Log a fill's Write to tag step; the blender's Choose cylinder and Log this
  fill; imperial units on every value;
  badge colours across every theme preset in both brightnesses; the label
  PDF renders a scannable QR (decode the rendered bitmap with the `qr`
  decoder in the test).
- **Guards.** `test/architecture/` after any new file under `lib/`; the l10n
  gate across all 11 locales.
- **Hardware checklist.** A document like
  `2026-09-18-media-sync-manual-test-checklist.md` covering: NFC read and
  write on iPhone and Android, background launch from a tap with the app
  closed, camera scan on all three platforms, printed label scan at 25 mm,
  writing a fill to a tag and reading it on a second phone (app open and
  closed), the blender's Log this fill to a tag, and the website fallback
  on a phone without the app. None of this runs in CI.

## 17. Delivery

Six PRs, each based on main, each with its own plan written only after the
previous one merges, each closing its own issue and referencing the umbrella #2333.

| PR | Issue | Scope | Rung | Needs |
| --- | --- | --- | --- | --- |
| 1a Passport core | #2334 | `passport_id` attribute, `AttributeGroup.system`, index; `PassportPayloadCodec` and `NdefFit`; `cylinder_fills` table, repository, sync; `LogFillSheet`; `PassportPage` and `PassportEntryCard` (spec, buoyancy, service, O2 warning, current fill, history, tag card); on-screen QR; `PassportLabelPdfService` with the multi-label sheet; Link an existing tag; `cylinder-passport-tag.md` | yes | main |
| 1b Scan and links | #2335 | `/c` and custom-scheme routes and queueing; iOS and Android link plumbing; `mobile_scanner` with `PassportScanSheet` and Paste link; `PassportResolver`; `ForeignPassportPage` with Use on a dive and Add to my gear; tank editor Scan | no | 1a |
| 2 NFC | #2336 | `nfc_manager`, `NfcTagService`; read, background launch filters; write with capacity and read-back; staleness hint with Rewrite and Reprint | no | 1b |
| 3 Fill on the tag | #2337 | Fill keys in the tag codec and `NdefFit`; reading them on every tag open (store for an own cylinder, show for a foreign one); Write to tag after Log a fill; the newest fill in every NFC write; the trimix blender's Choose cylinder and Log this fill; tag doc update; hardware checklist (rescoped 2026-09-28) | no | 2 |
| 4 Trip assignment | #2338 | `trip_equipment` table, repository, sync; passport Trip card; trip page Gear section | yes | 1a |
| 5 CSV round trip | #2339 | a fourth Submersion CSV for fills (decided 2026-09-29, section 4): writer, export sheet entry, signature, format, parser, wizard Fills group, id-keeping importer, round-trip test in three unit modes | no | 1a |

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
- Deferred from phase 3 (decided 2026-09-28), in the order they build on
  each other:
  - Station mode: a Fill station screen for filling other people's
    cylinders (tap their tag, enter the analysis, write it), and a
    device-local station log that never enters the owner's fill history.
  - More carriers: an on-screen QR of the fill for printed-label cylinders,
    `.sfr` files and `/f` links (share sheet, Open with, drop), and the
    website's `/f` page.
  - Signing: an Ed25519 JWS over the fill (the reserved `fs` key), with
    trust-on-first-use pins (`fill_stations`, section 10.3), badges reading
    "Signed" rather than "Verified" (a signature proves consistency of
    origin, not identity), and Key changed with Trust and Block.

## 19. Assumptions verified at plan time

- Flutter delivers the URL fragment to go_router on iOS universal links and
  Android app links (13.2). Fallback documented.
- `nfc_manager` exposes tag capacity before writing on both platforms; if
  not, `NdefFit` writes the full record and falls back through the drop
  order on a size error.
- `mobile_scanner` builds and scans on macOS with the current Flutter SDK
  pin; otherwise macOS joins the desktop Paste-link tier for PR 1b and
  camera scanning on macOS becomes a follow-up.
- (Deferred with the on-screen QR.) The `barcode` package's QR encoder
  handles a 600-character signed `/f` URL at medium error correction: a
  version 19 code, measured 2026-09-28.
- `VisibilityFilter` offers an equipment clause the resolver can reuse; if
  it is still `diver_id = ?` on main, the resolver uses that and the sharing
  program's PR 2 swaps it.
- Schema version numbers, checked against main when each plan is written.
