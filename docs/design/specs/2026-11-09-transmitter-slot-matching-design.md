# Transmitters: match file-imported cylinders by computer slot

Issue: #4347 (reported in #3367). Builds on the transmitter registry
(`2026-09-08-transmitter-registry-design.md`).

## Intent

"Apply to existing dives" (Settings > Transmitters) fills cylinders whose
stored transmitter serial matches the entry's serial. Dives imported from a
Shearwater Cloud UDDF export carry no serial on any cylinder, so the button
finds none of them. A Shearwater diver's usual route into the app is to import
their history from Shearwater Cloud, then download new dives over Bluetooth.
Anyone who sets up transmitters after that has every older dive left unfilled,
and sidemount Left and Right can only be fixed one dive at a time today.

The Cloud file does say which transmitter slot each cylinder came from: its
samples label pressures `<tankpressure ref="T1">`, `ref="T2"` and so on. The
importer uses that label to route pressures and then discards it. This feature
recovers the label and lets the diver say which slot a transmitter sat in, so
Apply can fill those cylinders too.

## What the research established

- **UDDF import stores no slot.** `<tankdata>` carries only start and end
  pressure. Refs are mapped to cylinders in memory
  (`uddf_full_import_service.dart`, the `fallbackRefToIndex` path) and the
  ref text is never kept. Every cylinder is saved with `tank_order = 0`
  (`uddf_entity_importer.dart:3701`, `order: t['order'] as int? ?? 0`), and
  `source_tank_index` stays null. The resync path (`dive_reimport_service.dart`)
  uses the list position instead, so the two paths disagree.
- **A download's tank index is not the T slot.** libdivecomputer's Shearwater
  parser compacts its slots to the ones active on that dive. On a backmount
  dive with only T1 active, T1 is index 0. On a sidemount dive with T2 and T3
  active, T2 is index 0. The same index names different transmitters on
  different dives, and `TankInfo` carries no physical slot. So the app cannot
  learn "serial X sat in T2" from downloads.
- **The original file is still there.** Since #1627 (September 2026) every
  file import stores the original bytes in `imported_files` (zlib-compressed,
  synced), and each dive's primary `dive_data_sources` row names it through
  `importedFileId` and `sourceFileFormat`. `DiveResyncOrchestrator` already
  re-parses a stored file and finds the dive in it with `DiveMatcher`.
- **Computer attribution works.** A Cloud UDDF that carries the computer's
  serial attaches to the same `dive_computers` row as the Bluetooth downloads
  (Shearwater hex and decimal serials are treated as one). UDDF dives set
  `dives.computer_id`; their `dive_tanks.computer_id` stays null, and the
  registry's slot query already reads `d.computer_id`.
- **Other file sources have no slot.** Subsurface, MacDive and Oceanic+
  files list cylinders in file order with no per-computer slot label.

## Goals

1. When a diver applies a transmitter's setup to existing dives, they can also
   fill the cylinders that have no serial and came from the same dive
   computer's slot, by telling the app which slot (T1 to T4) the transmitter
   sat in.
2. Dives already imported work as they are. No re-import, no resync, no
   action beyond the Apply dialog.
3. The diver sees how many dives each route will change before anything is
   written.
4. New UDDF imports keep their cylinder order instead of storing every
   cylinder as order 0, and route each `T<n>` pressure series to the right
   cylinder even when a later transmitter reports first.
5. Channel-only registry entries stop matching file-imported cylinders by a
   position that is not their channel.

## Non-goals

- Filling future Cloud imports automatically. The slot is not stored in the
  registry; after a later Cloud import the diver presses Apply again. (Cloud
  history is normally a one-time import before switching to Bluetooth.) Moving
  the slot into transmitter setup can come later without changing this design.
- Inferring the slot from downloads. The compaction above makes any guess
  unreliable, and a wrong guess writes the wrong size and role onto many dives.
- Changing the libdivecomputer fork to report the physical slot.
- A date range or re-pairing detection. The diver's pick applies to every
  matching dive on that computer (see Risks).
- Slot matching from formats other than UDDF, or from the save SnackBar's
  "Apply", the data-quality repair executor, or agent writes. Those stay
  serial-only (and channel-only, as today).
- Undo. Apply stays fill-only, which already limits what a wrong pick can
  overwrite.

## Anti-goals (a failure even if it works)

- Any cylinder that carries a serial is changed by slot matching.
- Slot matching writes anything without the diver having picked a slot in the
  dialog and confirmed.
- A cylinder is matched by guessing (by position, by insert order, or by a
  download's index) rather than by the slot label in its own source file.
- The preview count and what Apply actually writes disagree.

## The design

### 1. The importer keeps the slot label in its parsed output

In `uddf_full_import_service.dart`, record on each parsed cylinder the slot a
`T<n>` ref names: a ref matching `^T(\d+)$` (case-insensitive, trimmed) gives
slot number `n` (T1 is 1). This is parsed data only: nothing new is written
to the database at import time.

The label must be tied to its cylinder by evidence, not by order. Cloud
`<tankdata>` entries have no `id`, so today unmatched refs are handed to the
kept cylinders in the order the refs first appear in the samples. That is
right in every fixture (each starts with T1), but a dive where T3 reports
before T2 would swap them. So:

- A `T<n>` ref is tied to the kept cylinder whose `tankpressurebegin` equals
  the ref's first sample pressure (both are Pascal integers from the same
  computer, and they are equal in every Cloud fixture). Exactly one cylinder
  must match; otherwise the ref gives no slot label.
- The importer's pressure routing for refs that match no `id` uses the same
  pairing first, and falls back to today's first-seen order only when the
  pairing finds no unique cylinder. This fixes swapped pressure graphs on such
  dives as well as the label.

### 2. UDDF cylinders get their list position as `tank_order`

`uddf_entity_importer.dart` uses the cylinder's position in the parsed list
when the file gives no `<tankorder>`, matching the resync path. This fixes the
display order of new imports. Existing dives are not rewritten.

Channel-only registry entries (computers that report no serial) match by
`COALESCE(source_tank_index, tank_order)`, a libdivecomputer download index.
A file-imported cylinder's position is not that index, and today every UDDF
cylinder (order 0) already matches channel 0. Channel matching therefore
stops matching cylinders that came from a file import: it applies to
cylinders from a download only. This covers `_tanksForEntry`, the import-time
`TransmitterMatcher` path if it can see file imports, and the rescan path. The
plan must confirm how a file-imported cylinder is recognised for dives
imported before #1627 (for example by the dive's data sources), and keep
pre-#1314 downloads, which have no `source_tank_index`, matching.

### 3. Finding slot candidates for a transmitter key

For a registry entry with a serial (channel-only entries are unchanged):

1. **Its computers:** the distinct computers of the cylinders that carry the
   serial (`dt.computer_id`, else `d.computer_id`), for the entry's diver.
2. **Candidate dives,** per computer: dives attributed to that computer
   (`d.computer_id` or any of its tanks' `computer_id`), of the same diver,
   that have at least one cylinder with no serial, whose primary data source
   has an `importedFileId` and a `sourceFileFormat` of UDDF, and none of whose
   cylinders already carries this entry's serial.
3. **The slot of each cylinder:** group candidate dives by stored file, read
   and parse each file once, and find each dive in it the way
   `DiveResyncOrchestrator` does (same `DiveMatcher` score and threshold, same
   `sourceDiverKey` filter, refused when ambiguous). Pair each parsed cylinder
   that has a slot with a stored cylinder of that dive that has no serial, by
   equal start pressure, end pressure, O2 and He (within a small tolerance for
   float round-tripping). A parsed cylinder that pairs with zero or more than
   one stored cylinder is skipped.
4. **Result:** for each computer, a map from slot number to the stored
   cylinder ids found in that slot.

A dive that cannot be resolved (no stored file, unsupported format, file
missing, no matching dive, ambiguous diver, no pairing) contributes nothing.
It is not guessed.

This step reuses the orchestrator's file read, parse and match code. It should
be factored so both call the same function rather than copied.

### 4. The Apply dialog

`applyTransmitterSetupToExistingDives` (the dialog behind Settings >
Transmitters "Apply to existing dives") changes:

- The serial preview works as today.
- If any of the transmitter's keys has candidate dives (step 3, items 1 and 2;
  cheap SQL), the dialog shows one row per computer: "Slot on <computer
  name>", with choices T1 to T4 and "Don't match by slot" (the default). The
  per-slot counts need the file parse, so the row shows a progress indicator
  until the parse finishes; the rest of the dialog is usable meanwhile.
- Each slot choice shows how many dives it would fill. A slot with nothing to
  fill is disabled.
- **Counts are what the write would change, not what matches.** The fill
  rules (which fields a cylinder would gain) become one pure function used by
  both the preview and the write. A cylinder counts only when that function
  yields at least one field. This applies to the serial count too, which today
  counts every matching cylinder while the write counts only changed ones.
  It also means a slot already applied drops to zero instead of offering "40
  by slot T2" forever, since slot-filled cylinders never gain the serial.
  When neither the serial preview nor the SQL candidate check finds
  anything, the "nothing to apply" SnackBar shows, worded so it is true for
  both "no cylinders carry it" and "every cylinder already has this setup".
  Once the files are read, a computer with no slot left to fill is hidden,
  and if no serial work remains either the dialog says in place that no
  cylinder needs the setup (the dialog is already open, so a SnackBar would
  arrive behind it).
- The serial sentence says how many cylinders carrying the transmitter
  "need its setup", since the count is what the fill would change.
- The summary line reflects the choice: for example "12 dives by serial, 40
  by slot T2 on your Perdix". With no slot chosen, it reads as today.
- If the serial preview finds nothing but slot candidates exist, the dialog
  opens anyway (today it shows "No cylinders carry this transmitter" and
  stops).
- Confirming applies the serial matches and the chosen slot's cylinders in
  one transaction, with the existing fill-only rules: size, working pressure,
  material, preset, gear link and name only where empty; the role only where
  it is the backGas default or derived from the transmitter name. Slot-matched
  cylinders do not gain the serial.
- The done SnackBar counts both groups.

The preview and the write use the same candidate list, so they cannot
disagree: the write takes the cylinder ids the preview resolved, re-checking
each is still serial-less, rather than recomputing.

### 5. Untouched paths

The save SnackBar's "Apply", `QualityRepairExecutor`, the agent write family
and import-time `TransmitterMatcher` keep calling the serial and channel
matching only (with channel matching limited to downloads, section 2). No
registry, schema or sync change.

## Constraints

- Units in any new text follow the active diver's settings (only counts and
  names are planned, so none expected).
- Every new string goes through ARB in all shipped locales.
- The dialog lives in `lib/features/transmitters/presentation/`, so the PR
  needs before and after screenshots.
- Parsing a several-hundred-dive Cloud file can take seconds; it runs once per
  file per dialog, never on the UI thread's critical path, and cancels with
  the dialog.
- File size limits (800 lines) apply; `transmitter_repository.dart` is 674
  lines, so the slot lookup goes in its own service file.

## Risks

- **A wrong pick writes the wrong size and role** onto every slot-matched
  dive. Mitigations: the per-slot counts make a wrong pick visible (picking T1
  for a sidemount transmitter shows the backmount dive count), Apply is
  fill-only, and the default is no slot matching.
- **Re-pairing:** a diver who moved a transmitter to another slot gets the new
  slot's dives filled with it. Accepted as rare; date limits are a non-goal.
- **Files imported before #1627** have no stored copy, so those dives are not
  offered. The dialog can only count what it found.

## Decisions made by the designer (not discussed with the maintainer)

- The slot is asked in the Apply dialog, not stored on the registry entry.
  (Discussed and agreed.)
- Cylinders are paired with the parsed file by pressures and gas, not by
  `tank_order`, because stored UDDF cylinders all have order 0.
- Slot numbering comes from the ref text (`T2` is slot 2), not the cylinder's
  position, since position is compacted the same way the download index is.
- One slot row per computer the serial was downloaded on, normally one.
- A slot label is tied to its cylinder by begin pressure, and the importer's
  pressure routing for id-less refs uses the same pairing (fixing swapped
  graphs when a later transmitter reports first). No real T2-and-T3-only
  Cloud export was available to confirm Cloud's ordering, so the design does
  not depend on it.
- Preview counts are what the fill would change, for the serial route too.
- Channel-only matching stops matching file-imported cylinders.

## Left to the builder

- Exact widget for the slot choice (dropdown or segmented control), and
  wording, within the app's existing dialog style.
- The pressure and gas tolerance used for pairing.
- How the shared parse-and-match code is factored out of
  `DiveResyncOrchestrator`.
- How the dialog's state is structured (stateful dialog or provider).
