# One dive computer, several download connections (issue #3106)

## Problem

One physical dive computer that reaches Submersion by more than one path ends
up as several `dive_computers` records, or as one record whose single
connection flips between paths. Statistics, the dive computer filter and
multi-computer consolidation then treat one device as several, and the
computer list is confusing.

The issue asked whether this still happens on 1.8.1. It does. Current main has
three independent causes:

1. **Shearwater file import vs BLE/USB download.** The Shearwater Cloud and
   Desktop importer reads the serial from the log filename
   (`Perdix 2[A1B2C3D4]#...`) as hex. libdivecomputer hex-decodes the same
   ASCII serial into a uint32 (`shearwater_petrel.c`, `array_uint32_be`) and
   every platform bridge prints it in decimal (`2712847316`). No matcher
   converts between the two. The file row also has no manufacturer, and the
   download matcher (`findByHardwareIdentity`) requires an exact one.
2. **Garmin FIT file, then Garmin Connect.** FIT imports register the
   computer without a manufacturer. The Garmin Connect adapter looks up
   `manufacturer == 'Garmin'`, misses, and creates a second record. The other
   order converges, because the file matcher matches on serial alone.
3. **BLE on one device, USB on another.** These land on one record, but
   `connectionType` is a single synced column while `bluetoothAddress` is
   device-local. Each download flips the shared type, so a Ratio downloaded
   over BLE on a phone and over USB on a laptop reads "usb" on the phone with
   a BLE address under it, and the address lookup that supplies the
   incremental fingerprint misses.

The merge banner from #1453 compares serial strings after normalisation, so it
misses causes 1 and 2.

## Goals

- One record per physical device, whichever path it arrives by.
- Each record lists the connections it has been downloaded or imported
  through (BLE, Bluetooth Classic, USB, serial, infrared, a file format, a
  cloud provider), with when each was last used.
- Each device remembers its own transport and address for a computer, so two
  devices stop overwriting each other.
- Existing per-interface duplicates are offered for merge through the
  existing #1453 surfaces.

## Non-goals

- Automatic merging of existing duplicates. Merges are not undoable; the
  user confirms each one in the existing merge sheet.
- A new list-page duplicate banner.
- Rewriting the serial snapshots on dives (`dives.dive_computer_serial`) or on
  data sources (`dive_data_sources.computer_serial`). They are provenance
  records; matching treats both forms as one serial.
- Removing or editing individual connections by hand.
- Dropping the legacy `connectionType` / `bluetoothAddress` columns.

## 1. Identity

### Shared serial comparison

A new pure module, `computer_serial_identity.dart`, owns the rule for "are
these two serials the same device". Every matcher calls it:

- `matchImportedComputer` (file imports and the imported-computer backfill)
- `findByHardwareIdentity` (BLE/USB downloads, Garmin and Suunto cloud)
- `duplicateCandidatesFor` (merge banner and picker)
- `matchGearTwin`

Rules:

- **Normalisation:** trim, collapse internal whitespace, compare
  case-insensitively. Today `findByHardwareIdentity` is trim-only and
  case-sensitive.
- **Shearwater family:** the manufacturer is Shearwater, or the model is a
  known Shearwater model (Perdix, Petrel, Teric, Peregrine, Tern, NERD and
  their numbered and AI variants, matching `ShearwaterFilenameParser`'s
  table). For these, an 8-character hex serial and the decimal value it
  decodes to are the same serial. Matching builds a set of keys per serial
  (the normalised text, plus the other radix form when one exists) and two
  serials match when their key sets intersect.
- Non-Shearwater serials compare by normalised text only.

### Store hex from now on

- A Shearwater serial reported by libdivecomputer is converted to
  8-character uppercase hex at the point of download, before it reaches the
  computer record, the dive's serial snapshot or the data-source row. One
  helper does the conversion, keyed on the libdivecomputer vendor.
- Shearwater file serials are uppercased to match.

### Blank manufacturer or model is compatible

- The download and cloud lookups treat a blank manufacturer or blank model on
  either side as compatible, matching the existing merge rules (`_compatible`
  in `dive_computer_merge_rules.dart`). A non-blank pair must still agree
  after normalisation.
- Imports pass the manufacturer when they know it: FIT reads
  `file_id.manufacturer` (Garmin is manufacturer 1), and the Shearwater
  importer uses `ShearwaterFilenameParser.vendorProduct`.

Together with the shared serial comparison this fixes the Garmin
FIT-then-Connect case in both orders and the Shearwater file-then-BLE case.

### Rewriting existing Shearwater serials

A `beforeOpen` self-heal converts `dive_computers.serial_number` to
8-character uppercase hex when all of these hold:

- the row is Shearwater family (rule above);
- the serial is all digits and its value is at most `0xFFFFFFFF`;
- the row was created by a download: `connection_type` is one of the direct
  transports (bluetooth, ble, usb, infrared), or a `dive_data_sources` row with
  `source_format = 'dive_computer'` points at it.

The provenance condition matters: a filename serial such as `12345678` is
already hex even though it is all digits.

The heal is local-only and does not stamp the sync clock, the same pattern as
the #1064 `computer_id` backfill. Every device on the new version computes the
same value, so they converge without sync traffic, and no device pushes a
restamp that could override a rename made elsewhere. A 1.8.1 peer keeps
showing decimal until it upgrades; matching accepts both forms meanwhile.

## 2. Connections data model

### Table `dive_computer_connections`

| Column | Synced | Meaning |
| --- | --- | --- |
| `id` | yes | `Uuid().v5` of `computerId \| kind \| detail` |
| `computer_id` | yes | FK to `dive_computers`, cascade on delete |
| `kind` | yes | `ble`, `bluetoothClassic`, `usb`, `serial`, `infrared`, `file`, `cloud` |
| `detail` | yes | file format (`fit`, `shearwater`, `uddf`, `macdive`, ...) or cloud provider (`garminConnect`, `suuntoCloud`); null for direct transports |
| `first_used_at`, `last_used_at` | yes | library-wide; the detail page shows last used from these |
| `address` | device-local | this device's BLE identifier or USB/serial port |
| `local_last_used_at` | device-local | when this device last used it; picks the main Download transport |
| `created_at`, `updated_at`, `hlc` | yes | standard sync columns |

- Direct transports keep libdivecomputer's transport distinctions, because a
  re-download must reopen the same pipe: BLE and Bluetooth Classic, or USB and
  serial, are different code paths.
- The deterministic id means two devices recording `(Ratio, ble)` converge on
  one row. There is no unique index, deliberately: a unique constraint on a
  replicated table makes an inbound sync insert throw instead of merge.
- Two device-local columns are needed. `address` alone says "this device can
  reach it"; the main Download button needs "which one did this device use
  last". A synced `last_used_at` cannot answer that, because a laptop USB
  download would make the phone default to USB.

### Sync

- A new synced entity type. `address` and `localLastUsedAt` are added to
  `deviceLocalSyncColumns`, so export strips them, import keeps this device's
  values, and a save that changes only them stamps no sync clock.
- Merge and computer deletion write tombstones for the connection rows they
  remove.

### Legacy mirror

Every write path keeps updating `dive_computers.connection_type` and
`bluetooth_address` to the last direct connection, as today, so a 1.8.1 peer
keeps working. New code reads connections, and falls back to the legacy
columns only for a computer with no connection rows yet.

### Seeding existing data

A `beforeOpen` self-heal, local-only and deterministic, runs for every
computer with no connection rows:

- a direct connection from its `connection_type`, with this device's
  `bluetooth_address` as `address` and `last_download_timestamp` as both
  `last_used_at` and `local_last_used_at`;
- one `file` connection per distinct `dive_data_sources.source_file_format`
  among the dives attributed to it;
- a `cloud` connection when `connection_type = 'cloud'`, the provider taken
  from the manufacturer (Garmin gives `garminConnect`, Suunto gives
  `suuntoCloud`).

### Merge

`mergeComputers` re-keys the duplicates' connections onto the survivor (new
v5 ids), unions them by `(kind, detail)` keeping the earliest
`first_used_at`, the latest `last_used_at` and `local_last_used_at`, and any
local `address`, then tombstones the old rows. This runs inside the existing
merge transaction.

## 3. Write paths and downloading

### Recording

`DiveComputerConnectionRepository.recordConnection(computerId, kind, detail,
{address, usedAt})` upserts by deterministic id. Each call advances
`last_used_at`, and `local_last_used_at` / `address` when given. Callers, each
after a successful attribution:

| Path | Records |
| --- | --- |
| BLE/USB/serial/IR download (`DiveComputerAdapter`, `DownloadNotifier._persistDeviceInfo`) | its transport, with this device's address |
| File import (`UddfEntityImporter._registerImportedComputers`, `MissingComputerAttacher`) | `file` with the import format |
| Garmin Connect and Suunto cloud adapters | `cloud` with the provider |

### Recognising a saved computer

`DiveComputerAdapter.resolveKnownComputer` matches by this device's `address`
in connections for any direct transport, with the legacy `bluetooth_address`
as a fallback. A USB download to a known computer therefore gets the
incremental fingerprint, which it never had.

### Downloading a saved computer

- The main Download uses this device's direct connection with the newest
  `local_last_used_at`.
- With none (a computer downloaded only on another device, or only imported
  from files), the existing "no direct download" view stays.
- The download route gains an optional `?connection=<id>`. The wizard builds
  the `DiscoveredDevice` from that connection's transport and address instead
  of the single `connectionType`.
- The current fallback that treats an unknown `connectionType` (`cloud`,
  null) as BLE is removed.
- The #1423 address rebind updates the connection row's `address` as well as
  the legacy column.

## 4. UI

- **Detail page, Connections card** under the info card, in its own widget
  file (`device_detail_page.dart` is already over the 800-line limit). One row
  per connection: icon, label (Bluetooth, Bluetooth Classic, USB, Serial,
  Infrared, FIT file, Shearwater Cloud export, Garmin Connect, Suunto, and the
  other import formats by their display names), "Last used <date>" in the
  diver's date format, and a "This device" tag when this device holds an
  address. Direct connections on this device get a Download button (routed
  with `?connection=`). The info card's single Connection row is removed.
- **List page:** the icon comes from the connection with the newest
  `last_used_at`. `file` and `cloud` get their own icons instead of the
  generic watch.
- **Merge sheet:** each record's line also lists its connections.
- **l10n:** new keys in all 11 locales; hu stays ASCII by convention.

## 5. Testing

- **Unit:** serial identity (Shearwater hex and decimal both ways, the
  all-digit filename hex case, non-Shearwater untouched, case and whitespace);
  manufacturer and model compatibility; `duplicateCandidatesFor` over the
  three reported cases.
- **Repository:** `recordConnection` upsert and id determinism; seeding; the
  hex rewrite and its provenance guard; merge unioning connections.
- **Sync:** round trip strips `address` and `localLastUsedAt` and keeps this
  device's values on import; tombstones on merge and delete.
- **Adapters and import:** each path records its connection; FIT then Connect
  and Connect then FIT both yield one record; a Shearwater file import then a
  BLE download yield one record.
- **Widget:** Connections card, This device tag, Download via, list icon.
- **Guards:** `test/architecture/` and `test/shared/`.

## Related

#645, #1453 (merge), #1423 (address rebind), #1288 (imported computers),
#3045 (FIT model identity), #3055.
