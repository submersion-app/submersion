# DiveMate database (.ddb) import

Status: approved design
Issue: #3110 (DDB part; the CSV and phone-flow parts stay open)
Builds on: PR #3172 (merged), which taught the Diving Log reader DiveMate's
equipment names, transmitter pressures, site country text, average depth,
dive type, discarded dives and free-text buddies.

## Problem

DiveMate (ConfiTek, Android, no longer maintained) stores its logbook as a
SQLite `.ddb` file in Diving Log 5's schema. Submersion detects it as a
Diving Log logbook and imports it through `DivingLogDbReader`. After #3172
the dives arrive, but a real logbook (619 rows, donated for this work, kept
off the repo) still loses or misstates a lot:

- It is labelled "Diving Log" in detection and the source picker.
- Water type, rating, visibility, current, waves, weather, entry type, boat
  and surface interval are never read (forum posts #53, #59, #62 single out
  water type).
- Cylinders lose their name, material, sidemount and stage/deco role and
  breathing time; 116 of 619 tank rows are sidemount.
- Equipment types are guessed from German names and mostly land on
  `other`; DiveMate's `TypeID` and `Category` say what each item is.
- 339 dives with `PlaceID` 0 raise "339 dives referred to a dive site the
  file does not describe"; 0 is DiveMate's "no site", so the warning is
  false.
- The logbook holds 186 duplicate pairs (same date and time, depth and
  duration, different dive numbers; 103 have byte-identical profiles).
  DiveMate's own UDDF and XML exports include both copies. Today both
  import silently.

## Facts established from the real file

| Column | Meaning | Evidence |
| --- | --- | --- |
| `DBInfo.PrgName` | `DiveMate` | the file |
| `Logbook.Status` | 2 = discarded, NULL/0/1 = kept | DiveMate's UDDF and XML exports hold exactly the 545 non-2 rows |
| `Logbook.PlaceID` | 0 = no site | 339 rows, no place text |
| `Logbook.Water`, `Place.Water` | 1 salt, 2 fresh, 0 unset | divetracx code table; German lakes are 2 |
| `Logbook.Entry` | 1 shore, 2 boat, 0 unset | divetracx code table |
| `Logbook.Rating` | 1 to 5, 0 unset | the file |
| `Logbook.VisHor`, `UWCurrent`, `Waves`, `Weather` | free text in the app language (`gut`, `leichte Strömung`, `klar`) | the file |
| `Logbook.Surfint` | `H:MM`; `0:0-1` and `0:00` mean unknown | the file |
| `Tank.Tanktype` | 1 aluminium, 2 steel, 0 and 3 unknown | cylinder names `80cuft Alu`, `12er Faber` (steel) |
| `Tank.SupplyType` | 4 sidemount, 1 open circuit, 0 unset | DiveMate's XML export labels the same rows `Sidemount` and `OC` |
| `Tank.DivePhase` | 3 deco, 4 stage, 0/NULL bottom | XML export labels `Deco` and `Stage` |
| `Tank.Name` | the cylinder's gear name | matches `Equipment.Name` |
| `Tank.BreathingTime` | seconds breathed | divetracx |
| `Equipment.TypeID` | 9 set, 11 cylinder, 12 weight, 17 computer, 0 by category | the file |
| `Equipment.Val1`, `Val3` | cylinder volume (L), material (1 alu, 2 steel) | `15er Alu` = 15/1, `12er Stahl` = 12/2 |
| `Pictures.Path` | Android paths under the DiveMate app folder; no embedded images | 311 rows |

## Design

### 1. Its own format

- `ImportFormat.diveMateDdb`, detected in `_detectFormat` when the SQLite
  probe finds a `Logbook` table and `DBInfo.PrgName` is `DiveMate`. Checked
  before Diving Log. A DiveMate file without `DBInfo` still matches through
  the `TypeOfDive` column, the marker #3172 used.
- `SourceApp.diveMate` with a new override option "DiveMate (database)"
  beside "DiveMate (CSV)".
- `DiveMateDdbParser` reuses `DivingLogDbReader` and `DivingLogDiveMapper`
  through the shared `parseDivingLogFamily`. The reader attaches DiveMate's
  extra columns to each raw dive and cylinder, and `DivingLogDiveMapper`
  hands them to `DiveMateDiveFields`, which writes the extra payload keys.
  The parser's messages say DiveMate, and the payload metadata source is
  `divemate_ddb`.
- Detection and the reader share one test, `DiveMateSchema.matches`
  (`DBInfo.PrgName` when the file names its program, else the `TypeOfDive`
  column), so the DiveMate-only
  rules (discard flag, transmitter pressures, extra columns) follow the file
  whichever parser reads it, and a file shown as DiveMate is always read as
  one. Diving Log schema notes that describe tables and columns DiveMate
  never has are not reported for a DiveMate file.

### 2. Fields

Dive (`DiveMateDiveFields` and `DiveMateValues`, new files):

| DiveMate | Payload key | Rule |
| --- | --- | --- |
| `Water` (dive, else site) | `waterType` | 1 salt, 2 fresh |
| `Rating` | `rating` | 1 to 5 |
| `VisHor` | `visibility` / `visibilityMeters` | `gut`/`good` etc. to the level; a number with `m` to metres; other text to notes |
| `UWCurrent` | `currentStrength` | none/light/moderate/strong from German or English words; other text to notes |
| `Waves`, `Weather` | `surfaceConditions`, `weatherDescription` | text kept as written |
| `Entry` | `entryMethod` | 1 shore, 2 boat |
| `Boat` | `boatName` | text |
| `Surfint` | `surfaceInterval` | `H:MM` when positive |

Site: `Place.Water` to `waterType`.

Cylinders: `Tank.Name` to `name`, `Tanktype` to `material`,
`BreathingTime` to `usageDuration`, and `role` from `DivePhase` (3 deco,
4 stage) then `SupplyType` 4 (sidemount; the first sidemount cylinder is
left, the second right, matching DiveMate's F1/F2 order).

Equipment: type from `TypeID` (11 cylinder, 12 weight, 17 computer), then
from the German category (`Flaschen`, `Blei`, `Wing`, `Anzug` and
`Tauchanzüge` read through the suit classifier, with `Trocki` as drysuit),
then from the name as today. Cylinder gear gets `volume_l` and
`tank_material` attributes from `Val1` and `Val3`.

Not mapped, on purpose: `UTCoffset` (always 0 in the file, semantics
unconfirmed), `MaxPPO2` and `Deco` (Submersion derives both), heart-rate
and skin-temperature columns (empty in the file), `Personal` (the diver is
chosen in the wizard), and `Pictures` beyond today's links (photos are
links only; the Android paths resolve only on the phone that took them).

### 3. No-site dives

`PlaceID` 0 (or negative) reads as no site, so the false "refers to a site
the file does not describe" warning goes away. Applies to Diving Log too,
where 0 has the same meaning.

### 4. Duplicates inside one file (review, not fold)

The import wizard already compares dives within a payload, but only for
multi-file batches (`checkIntraBatch = batchFileCount > 1` in
`universal_adapter.dart` and `universal_import_providers.dart`), and its
review card for such a pair shows text only.

- Run a within-file pass for single files, with a stricter rule than the
  batch pass: starts less than a minute apart (elapsed time, so copies
  either side of a minute boundary still pair) and a matcher score of at
  least 0.95
  (depth and duration inside the full-credit bands). On the donated logbook
  it flags exactly the 186 pairs, and keeps the fuller copy of each.
- The review card shows the other copy side by side (date, number, depth,
  duration, site, buddies, profile presence) instead of the text-only line.
- Choosing which copy to keep is symmetric: keeping the flagged copy
  deselects its partner, skipping it reselects the partner.
- Default: copies of one dive form a cluster (three copies are one
  cluster), and the copy carrying the most data (site, buddies, notes,
  profile and the like) stays selected; every other copy is flagged against
  it. In this file that is the unnumbered-status copy for every pair where
  they differ.

This touches `lib/features/import_wizard/presentation/`, so the PR needs
before and after screenshots per the repo's PR rules.

## Testing

- A synthetic DiveMate fixture built in the test (no donated data in the
  repo) covering every mapped column, codes 0 and unknown, `PlaceID` 0,
  sidemount pairs, deco and stage cylinders, and a duplicate pair whose
  profiles differ.
- Detection: DiveMate by `DBInfo`, by `TypeOfDive` fallback, Diving Log
  unchanged.
- Wizard: a single-file payload with a duplicate pair is flagged; the keep
  choice is symmetric; two dives 6 minutes apart are not flagged.
- A local, uncommitted probe against the donated logbook to compare counts
  before and after.

## Out of scope

The CSV import stopping at dive 111 and the phone duplicate-deselect flow
(#3110; no CSV in the donated files), sync reliability, the duplicate
Shearwater computer, and course assignment (forum topics with their own
issues).
