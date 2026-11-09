# Transmitter slot matching for file-imported tanks (issue #4347)

## Intent

"Apply to existing dives" (Settings > Transmitters) finds only tanks whose
stored transmitter serial matches the entry. Dives imported from a Shearwater
Cloud UDDF export carry no serial on any tank, so the button finds none of
them. A Shearwater diver's usual route into the app is to import their history
from Shearwater Cloud and then download new dives over Bluetooth, so anyone who
sets up transmitters afterwards hits this for every older dive (#3367).

Shearwater Cloud's UDDF has no serial to read, but it does name the
transmitter slot: samples carry `<tankpressure ref="T1">` to `T4`. Bluetooth
downloads from the same computer show which serial sat in which slot. This
feature records the slot on both kinds of tank and matches file-imported tanks
to registry entries by computer, slot and date.

## What the code does today (verified 2026-11-09)

- **UDDF import loses the slot.** Shearwater Cloud `<tankdata>` has no `id` and
  no `<tankorder>`. `UddfFullImportService` drops zero-pressure placeholder
  tanks and resolves `ref="T1"`, `ref="T2"` to list positions in first-appearance
  order. `UddfEntityImporter._buildTanks` then writes `order: t['order'] ?? 0`,
  so every tank is stored at `tank_order` 0 with a null `source_tank_index`. The
  `T1`/`T2` names are discarded. Probe on
  `test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf`: two tanks, neither
  with an order.
- **Bluetooth downloads lose the slot too.** libdivecomputer's Shearwater
  parser (`shearwater_predator_parser.c`) numbers only active transmitters:
  `tankidx[i] = ntanks++`. A sidemount dive on T2 and T3 stores them as tank 0
  and 1, the same numbers T1 gets on a backmount dive.
- **Computer attribution matches.** `findOrRegisterImportedComputer` matches a
  UDDF `<divecomputer>` to an existing record by model and serial, so a
  Shearwater Cloud dive lands on the same record as its Bluetooth downloads.
- **Other UDDF sources** (the Oceanic fixture, Submersion's own export) give
  `<tankdata>` an `id` and point refs at it. Bare `T1` to `T4` refs are a
  Shearwater Cloud behaviour.
- **Raw bytes are kept.** Downloaded dives keep `raw_data` on their data source
  (what Reparse uses), so slots can be learned for dives already downloaded.
- **The registry already allows serial plus channel** on one entry, but
  `TransmitterRepository._tanksForEntry` returns on the serial branch and never
  runs the channel branch for such an entry.

## Goals

1. Every tank records the physical transmitter slot it came from, when the
   source knows it: Bluetooth downloads (and re-parses) from Shearwater
   computers, Shearwater Cloud UDDF imports, and Shearwater Cloud `.db`
   imports.
2. "Apply to existing dives" also offers file-imported tanks that have no
   serial, matched by computer, slot and dive date to the entry's serial.
3. The diver sees, before anything is written, how many dives matched by serial
   and how many by slot, and how many of the slot matches rest on the
   assumption that the pairing has not changed since before the first download.
4. Dives already downloaded learn their slots from stored raw bytes, with no
   fresh download.
5. Dives already imported from Shearwater Cloud (UDDF or `.db`) learn their
   slots, and for `.db` their serials, from the original file the app stored at
   import (`imported_files`, kept since #478 / PR #1627, 12 Sep 2026), with no
   action from the diver.
6. `.db` imports carry the transmitter serial libdivecomputer reports, so those
   dives match by serial outright.

## Non-goals

- Slots for brands other than Shearwater. Other parsers report "unknown". The
  native field is generic so another backend can fill it later.
- Inferring slots for downloaded dives that have no raw bytes, or for
  file-imported dives with no stored file (imported before #478). The dialog
  counts these; they stay unmatched.
- Changing the import wizard's duplicate actions. Re-importing a file is not
  the repair path.
- Writing the entry's serial onto tanks matched by slot (decided: the serial
  stays something only a computer or its own log reported).
- HP CCR pressure sensors (Shearwater parser indices 4 and 5): they are not
  transmitter slots and report "unknown".
- Changing the existing channel matcher (`channelIndex`, entries with no
  serial), which keeps its compacted-index meaning.
- A free date-range picker in the Apply dialog.
- Changing `tank_order`, or how tanks are ordered or displayed.
- Changing which tanks the serial match finds, or the fill-only rules.

## Anti-goals (a failure even if it technically works)

- Writing a role or size onto a tank whose slot was held by a different serial
  around that dive's date.
- Any slot-matched write without the diver confirming the counts first.
- Touching a tank that carries a different serial, or overwriting a value the
  diver set.
- Matching plain gas tanks that no transmitter fed.

## Design (decided)

### 1. Native: report the physical slot

A new patch on our libdivecomputer fork, following
`0009-tank-transmitter-serial.patch` exactly (commit on the fork's
`submersion-patches` branch, a matching `patches/0010-...patch` file, submodule
bump):

- `dc_tank_t` gains a slot field. "Unknown" must be the zero-initialised value,
  as with `serial`, so every backend that does not set it reports unknown (the
  serial patch had a follow-up to keep the field defined for every backend; do
  not repeat that bug).
- The Shearwater parser sets it to the physical slot index `i` (T1 = 0 to T4 =
  3) for each active tank, before compaction. Indices 4 and 5 (HP CCR
  diluent and oxygen sensors) report unknown.
- The value flows through `libdc_tank_t` (`libdc_wrapper.h`,
  `libdc_download.c`), the Linux `dive_converter.c`, Android JNI and Kotlin,
  Darwin Swift and Windows, into Pigeon `TankInfo` as `transmitterSlot`
  (nullable int, 0 based), then onto the downloaded tank and, through
  `parsed_tank_resolver.dart`, onto `DiveTank.transmitterSlot`.
- A native C test pins it, as `test/native/test_tank_transmitter_serial.c`
  does for the serial.

### 2. Storage

- New nullable `dive_tanks.transmitter_slot` integer (0 based). Schema bump
  with its rung in `migrations/ladder/rungs_v340_onward.dart` and the column in
  `lib/core/database/tables/dive_tables.dart`, never in `database.dart`.
- Computer-owned, like `computer_id` and `source_tank_index`: written by
  downloads, re-parse, the consolidation fold and import; never by the tank
  editor. Edits and copies preserve it.
- Synced: it travels in the dive tank sync payload and survives a round trip.
- `DiveTank` gains `transmitterSlot` with `copyWith`.

### 3. UDDF import

When a dive's `<tankdata>` elements have no `id` and a `<tankpressure ref>`
matches `T1` to `T4` (case-insensitive, trimmed), the tank that ref resolves to
gets `transmitterSlot = n - 1`. Any other ref shape leaves the slot null.

### 3a. Shearwater Cloud `.db` import

`ShearwaterDiveMapper` already runs `parseRawDiveData` on each dive's raw log,
but `mapTanks` builds tanks from the export's `TankData` JSON and drops the
serial. With the native patch, each mapped tank also takes the serial and slot
of the libdivecomputer tank it corresponds to. Both lists hold only active
transmitters in slot order (`DiveTransmitter.IsOn`, and libdivecomputer's
compaction), which is the expected pairing; the builder confirms it against a
fixture and leaves both fields null when the two lists disagree in length.

### 4. Backfill for existing dives

All backfills write only `transmitter_slot` (and, for `.db` dives, the serial),
stage each changed row for sync, and never touch another field.

- **Downloaded dives:** tanks that have a serial but no slot, on a data source
  with raw bytes, get the slot by parsing those bytes and matching the parsed
  tank to the stored row (by `source_tank_index`, the parsed tank index).
- **Shearwater Cloud UDDF dives:** tanks with no serial and no slot, on a dive
  whose stored original file (`imported_files`) is a UDDF, get the slot by
  re-reading that file through the same parse path as section 3 and matching
  the parsed tank to the stored row. Every Cloud tank sits at `tank_order` 0,
  so the match is by insertion order within the dive, which is the order the
  import wrote them (`DiveReimportService` already relies on this); the
  builder confirms it with a test and skips the dive if counts disagree.
- **Shearwater Cloud `.db` dives:** as for UDDF, from the stored `.db`, giving
  serial and slot.
- Dives with no raw bytes or no stored file stay as they are and add nothing to
  the timeline.
- A dive whose parse yields no slot is remembered locally so it is not parsed
  again on every open (a local, unsynced marker; the column stays a plain
  nullable int). Where the native parser is unavailable (web, a missing
  plugin), backfill is skipped and the dialog previews from the slots already
  stored, including those synced from other devices.

### 5. Slot timeline and matching

For a registry entry with serial S:

- **By serial:** as today.
- **By slot:** the timeline for computer C and slot N is every tank on C's
  dives that has both a serial and a slot N, as (dive date, serial). A
  candidate tank has no serial, a slot N, a pressure series, and belongs to a
  dive on computer C (`dt.computer_id` or `d.computer_id`, as the channel
  matcher already does). For its dive date D:
  - downloads before and after D show the same serial: that serial;
  - downloads before and after D show different serials: the slot changed hands
    in that gap, so the tank is **skipped** and counted as such;
  - D is after every download: the latest pairing;
  - D is before every download: the earliest pairing, and the tank is flagged
    **older than the first download** that showed it.
  The candidate is S's when the resolved serial is S.
- Only tanks that have both a serial and a slot form the timeline. Apply never
  writes a serial, so a slot match never feeds the timeline.
- A tank found by serial is never also counted by slot, and the existing
  channel branch stays as it is for entries with no serial.

### 6. Apply dialog

`previewApplyToExistingDives` reports dives by serial, dives by slot, how many
of the slot dives are older than the first download (with that date per
computer), and how many were skipped because the slot changed hands. The dialog
(`applyTransmitterSetupToExistingDives`) shows these, for example "40 dives by
slot on your Petrel 3, 31 of them before your first download (12 Mar 2026)",
with a switch to leave out the older dives. The switch is on by default,
updates the counts in place, and Apply writes exactly what the dialog shows.

When the entry's computers have file-imported tanks with a pressure series but
no serial and no slot even after backfill (no stored file), the dialog says how
many dives that is, as information. It offers no action.

Fill-only rules, the role rules and `BailoutMixFixer` are unchanged and apply
to slot matches exactly as to serial matches.

## Left to the builder

- Field and column names, and the native "unknown" encoding (zero-initialised
  is required; 1-based-with-0-unknown in C is fine if Dart sees 0-based).
- When the backfill runs (on demand when the dialog opens, scoped to the
  entry's computers with progress shown, or a background worker), provided it
  never blocks launch and, where the parser is available, the dialog never
  previews before the computers it counts are backfilled.
- The form of the local "parsed, no slot" marker.
- The snackbar "Apply" offered after saving in `transmitter_edit_page.dart`
  writes with no preview today. It may keep serial-only behaviour or route
  through the dialog, but it must never write slot matches unconfirmed.
- The agent-access transmitter rules (`transmitter_rules.dart`) read the
  preview: keep their counts truthful with the new breakdown.
- Exact wording of new strings (all locales in `lib/l10n/arb/`), and dates
  formatted with the app's locale-aware date formatting.
- How "has a pressure series" is checked, as long as it is one query and not
  per tank.
