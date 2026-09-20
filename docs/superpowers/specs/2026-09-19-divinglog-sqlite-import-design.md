# Diving Log / DiveLogDT SQLite Import

Date: 2026-09-19
Status: approved design, implementation plan pending
Branch: ericgriffin/github-issue-2144-5c6603
Issue: #2187 (a phase 1 PR must say `Refs #2187`; only the phase 2 PR closes it)
Source: discussion #2144

## Problem

A diver with about 500 dives in DiveLogDT tried to migrate to Submersion.
The only interchange route they found was DiveLogDT's DL7 export, and the
import landed the dives but dropped every dive site, buddy, equipment item,
weight, tank and trip.

This is not a defect in the DL7 parser. DL7 was written by DAN to collect
depth and time profiles for decompression research and carries almost no
logbook data. The vendor says so on its own export page: DL7 is "not the
best format to communicate general information about a dive for logbook
purposes and is actually lacking in much information desired by logbook
users." `Dl7Reader` skips every segment outside FSH, ZRH, ZAR, ZDH, ZDP and
ZDT by design, and the only rich data the parser can recover arrives through
one vendor dialect, `AqualungZarDialect`, which DiveLogDT does not write.
No amount of work on the DL7 path recovers data the file never held.

DiveLogDT's actual logbook is a SQLite database it exports directly, and it
is the same format Diving Log uses on Windows: "The same logbook format is
used with Dive Log for iOS and Diving Log 5.0 on the PC." That file does
hold the sites, buddies, equipment, weights, tanks and trips. Importing it
is the migration path, and it serves Diving Log's own users at the same
time. Submersion has `ImportFormat.divingLogXml` and `ImportFormat.sqlite`
declared today with no parser behind either, so both fall through to
`PlaceholderParser`.

## Decisions

Taken during brainstorming and fixed for this spec.

- Build a native SQLite importer for the Diving Log 5.0 / DiveLogDT logbook.
  Do not extend the DL7 parser: the ceiling is the format, not the code.
- The reader probes the schema rather than hard-coding a column list. A
  missing table skips one entity with a warning; a missing column degrades
  to null. A file from a newer Diving Log or a drifted DiveLogDT build must
  still import its dives rather than throw.
- Do not convert to UDDF and reuse `UddfFullImportService`. The wizard
  flattens `UddfImportResult` and keeps only the entity lists, so per-dive
  data would have to ride on the dive map regardless. That route is a
  SQLite reader plus a UDDF writer plus a lossy hand-off, to reuse a mapper
  we would have to bend anyway.
- Follow the existing three-file shape: reader, mapper, parser, matching
  `MacDiveDbReader` / `MacDiveDiveMapper` / `MacDiveSqliteParser`.
- Ship in two phases. Phase 1 maps everything the `Logbook` and `Tank`
  tables give us, which is known from a verified reference. Phase 2 maps the
  relational tables (buddies, equipment, trips, shops) once a real file is
  in hand. Phase 1 does not guess at column names it has not seen.

## Format facts

These are verified, not assumed. The dive and profile column names come
from Subsurface's `core/import-divinglog.cpp`, which imports this format.
Only the schema, meaning facts about a third-party file layout, is taken
from it. No code is copied.

### Units

The database stores metric throughout. Diving Log's own documentation
states that its raw table editor "supports only metric units when it is in
edit mode" precisely because that is how the data sits on disk. There is no
unit header to read and no imperial branch, which removes the class of bug
the DL7 parser carries (see its note about the ZRH model code and the bogus
ZDT minimum temperature).

Two different scales are in play and must not be confused. The `Logbook`
scalar columns are plain metric: `Depth` in metres, `Divetime` in minutes,
`Airtemp` and `Watertemp` in degrees Celsius, `Weight` in kilograms,
`TankSize` in litres, `PresS`/`PresE`/`PresW` in bar. The packed profile
columns use fixed-point integers instead: depth in centimetres, pressure in
tenths of a bar, temperature in tenths of a degree. Only the profile codec
applies those divisors.

Display of these values still follows the active diver's unit settings, as
everywhere else in the app. Storage is metric; that is all this section
fixes.

### Dive rows

Table `Logbook`, excluding rows whose `UUID` appears in `DeletedRecords`.

| Column | Meaning |
| --- | --- |
| ID | primary key, joined by `Tank.LogID` |
| UUID | row identity, and the `DeletedRecords` join key |
| Number | the diver's dive number |
| Divedate, Entrytime | date and entry time, combined for the start |
| Country, City, Place | dive site as free text |
| Buddy | buddy names as free text |
| Divemaster | dive guide as free text |
| Comments | dive notes |
| Depth | maximum depth |
| Divetime | duration |
| Airtemp, Watertemp | temperatures |
| Weight | lead carried |
| Divesuit | exposure suit as free text |
| Computer | dive computer as free text |
| Visibility | visibility |
| SupplyType | gas supply kind |
| ProfileInt | sample interval in seconds |
| Profile..Profile5 | the sample series, see below |
| TankSize, PresS, PresE, PresW, O2, He, DblTank | cylinder zero |

`DblTank` set means the cylinder is a twinset and `TankSize` is per
cylinder, so the imported volume doubles.

Table `Tank`, keyed `LogID`, holds the per-dive cylinders for multi-tank
dives: `TankID, TankSize, PresS, PresE, PresW, O2, He, DblTank`. The
`Logbook` cylinder columns are the fallback when `Tank` is absent or has no
row for the dive.

### Profile encoding

Samples are fixed-width ASCII, not a binary blob, spread across five
parallel columns. Each column is consumed one stride at a time with its own
length counter, because the columns are independently optional and can run
out at different points.

- `Profile`, stride 12, `DDDDDCRASWEE`: depth in centimetres (5), deco flag
  (1), RBT warning, ascent warning, decostop ignored, work warning, two
  characters of computer-specific extra. Worked example `004500010000` is
  4.5 m with an ascent warning and nothing else set.
- `Profile2`, stride 11, `TTTFFFFIRRR`: temperature in tenths of a degree
  (3), tank pressure in tenths of a bar (4), tank id (1), RBT in minutes
  (3). Worked example `25518051099` is 25.5 C, 180.5 bar, tank 1, 99 min.
- `Profile3`, stride 14: heart rate at offset 8, width 3.
- `Profile4`, stride 9: no-decompression limit in minutes when not in deco,
  or time to surface when in deco (3), stop time in minutes (3), stop depth
  in metres (3).
- `Profile5`, stride 19, `AAABBBCCCOOOONNNNSS`: three measured ppO2 cells in
  hundredths of a bar, OTU in tenths, CNS in tenths of a percent, setpoint
  in tenths of a bar. Worked example `1121131141548026411` is 1.12, 1.13 and
  1.14 bar, OTU 154.8, CNS 26.4, setpoint 1.1.

The tank id at offset 7 of `Profile2` is the gas-switch signal. A change in
that id from one sample to the next is a switch to the cylinder with that
index, which is how switches are recovered without an event table.

Sample timestamps are `index * ProfileInt` seconds from the dive start.

## Architecture

Three new files, mirroring the MacDive SQLite path, plus a fourth for the
decoder because it is the highest-risk code here and earns its own test.

| File | Responsibility |
| --- | --- |
| `lib/features/universal_import/data/services/divinglog_db_reader.dart` | Open the bytes, probe the schema, return a typed `DivingLogLogbook`. Knows SQLite, knows nothing about Submersion. |
| `lib/features/universal_import/data/services/divinglog_profile_codec.dart` | Decode the five fixed-width sample columns into typed samples. Pure, no I/O. |
| `lib/features/universal_import/data/services/divinglog_dive_mapper.dart` | `DivingLogLogbook` to `ImportPayload`. Knows Submersion, never touches SQLite. |
| `lib/features/universal_import/data/parsers/divinglog_sqlite_parser.dart` | Orchestration and error handling, the shape of `MacDiveSqliteParser`. |

The reader/mapper split is what makes the mapper testable against
hand-built `DivingLogLogbook` values with no database in the test at all,
and the codec testable against the two documented worked examples.

Existing files touched:

- `import_enums.dart`: add `ImportFormat.divingLogSqlite` with display name
  "Diving Log", add it to `isSupported`, add a `SourceOverrideOption` for
  `SourceApp.divingLog`, and replace `SourceApp.divingLog.exportInstructions`
  (currently null) with instructions to export the logbook rather than DL7.
- `parser_registry.dart`: route the new format.
- `universal_import_providers.dart`: `_detectFormat` is where SQLite
  flavours are actually resolved. It probes the table set once via
  `ShearwaterDbReader.probeSqliteTableNames` and then asks each reader's
  synchronous `matchesTables`. Add a `DivingLogDbReader.matchesTables`
  branch there. `format_detector.dart` is deliberately left alone: it works
  on raw bytes and its own comment says it cannot query tables, so it
  correctly returns the generic `ImportFormat.sqlite` that `_detectFormat`
  then refines.

### Opening the file

`sqlite3.open` needs a path, so the reader writes the bytes to a temp file,
opens read-only, and deletes the temp file on exit, exactly as
`MacDiveDbReader` does today, including on the error path.

### Data flow

    Uint8List
      -> temp file, sqlite3.open read-only
      -> probe sqlite_master and pragma table_info
      -> DivingLogCapabilities (which tables and columns exist)
      -> one SELECT per entity, narrowed to existing columns
      -> DivingLogLogbook (typed rows)
      -> DivingLogDiveMapper.toPayload
      -> ImportPayload

## Phase 1 mapping

Payload reference keys come from `payload_ref_keys.dart`, so `PayloadMerger`
and `PayloadDiverExpander` resolve them with no new plumbing.

| Source | Payload destination |
| --- | --- |
| `Divedate` + `Entrytime` | `dateTime`, a wall clock stored UTC-flagged per the house convention |
| `Number` | `diveNumber` |
| `Depth`, `Divetime` | `maxDepth`, `duration` |
| `Airtemp`, `Watertemp` | `airTemp`, `waterTemp` |
| `Comments` | dive notes |
| `Visibility` | `visibility`, mapping the source's 1/2/3 to `Visibility.good`/`moderate`/`poor`; 0 means unset and is omitted |
| `Weight` | `weightUsed`, the key `MacDiveDiveMapper` already uses |
| `Country`, `City`, `Place` | a `sites` entity, `uddfId` keyed on the whole triple, referenced from the dive by a nested `site` map |
| `Buddy` | split into `buddies` entities, referenced by `buddyRefs` |
| `Divemaster` | a `buddies` entity referenced by `diveGuideRefs` |
| `Divesuit` | phase 1 puts this in notes, not equipment, for the reason below |
| `Computer` | `diveComputerModel` |
| `SupplyType` | a tag via `tagRefs` |
| `Tank` rows, else `Logbook` cylinder zero | `tanks`, with `DblTank` doubling the volume |
| `Profile..Profile5` | `profile` samples and gas-switch events |
| `UUID` | `sourceUuid`, so re-imports deduplicate |

Site identity is keyed on country, city and place together, so 500 dives at
a handful of sites collapse to a handful of site records rather than 500.

`Divesuit` goes to notes rather than equipment deliberately. Memory records
that the CSV gear path is unsafe for exactly this: the `exposure_suit` type
plus a name-and-type dedupe that never matches produced duplicate gear, and
the fix in the CSV importer was to route the suit to notes. Equipment
arrives properly in phase 2 from the equipment table, where it has real
identity.

### Profile samples

`DiveProfilePoint` has homes for depth, temperature, heartRate, setpoint,
ppO2, o2Sensor1 through o2Sensor3, cns, ndl, ceiling, rbt, decoType and
tts, so nearly everything maps directly. `Profile4`'s stop depth maps to
`ceiling`. The deco flag sets `decoType` to 2.

`Profile5`'s OTU has no destination. Neither `DiveProfilePoint` nor `Dive`
carries an OTU field. Phase 1 drops it and records one diagnostic warning
per file saying so, rather than dropping it silently. Adding per-sample OTU
is out of scope here and belongs in its own issue.

## Error handling

Three tiers. The middle tier is the reason for the probing reader.

1. Fatal, an `ImportWarning.error` and an empty payload: the bytes are not
   SQLite, or there is no `Logbook` table, or `Logbook` holds no rows. The
   message names what was expected, as `MacDiveSqliteParser` does.
2. Degraded, a warning and a partial import: a table we wanted is missing,
   so that entity is skipped and the warning names the table. A file from a
   Diving Log version that renamed `Shop` still imports every dive.
3. Recorded, no summary noise: a column we wanted is missing, so the field
   is null and the absence is noted once in payload metadata. This is how we
   learn about schema drift from real files without burying the user.

A dive that throws mid-parse uses `ImportWarningCode.divesSkipped` with its
`itemIndex`, so the summary's count of dives that could not be read stays
truthful. Memory records that #2152 went wrong in exactly this way: skipped
dives vanished from the summary instead of being counted.

Dives with no readable start time cannot be placed in the log and are
skipped with that code, matching the DL7 parser's behaviour.

## Testing

Tests first, per the repo's TDD rule.

- `divinglog_profile_codec_test.dart`: the two documented worked examples
  (`004500010000` and `25518051099`) as literal vectors, plus columns of
  mismatched lengths, plus a `Profile2` tank id change asserting exactly one
  gas switch, plus an empty profile.
- `divinglog_db_reader_test.dart`: builds synthetic SQLite files in the
  test. A full-schema file, a file missing the `Tank` table, a file whose
  `Logbook` lacks several columns, a file with rows in `DeletedRecords`
  asserting they stay out, and a non-SQLite byte string.
- `divinglog_dive_mapper_test.dart`: hand-built `DivingLogLogbook` values,
  no database. Asserts site collapsing across repeated dives, `Divemaster`
  landing in `diveGuideRefs` and not `buddyRefs`, `DblTank` doubling the
  volume, `weightUsed` in kilograms, and the OTU warning being raised.
- Detection: assert `DivingLogDbReader.matchesTables` accepts a Diving Log
  table set and rejects a MacDive and a Shearwater one, so the three
  SQLite flavours cannot claim each other's files.
- `divinglog_real_sample_test.dart`: added when a real file arrives,
  mirroring `dan_dl7_real_sample_test.dart`.

Architecture guard tests scan all of `lib/`, so they run after the new
files land rather than relying on an affected-directory run.

## Verified against a real logbook

A 444-dive DiveLogDT logbook was supplied by the reporter of discussion
#2144 on 2026-09-19. It is personal data and is not committed to this
repository; the facts below are what it established.

Confirmed: `Logbook.Depth` is metres, `Weight` is kilograms, `Divedate` is
`YYYY-MM-DD` with `Entrytime` as `HH:MM`, `Visibility` codes are 1, 2 and 3
with null for unset, and `ProfileInt` is 5 for most dives and 1 for one.
The 41 dives with `ProfileInt` of 0 carry no profile at all, so the codec's
fallback interval never distorts real samples.

Two defects it exposed, both now fixed and covered by tests:

- **Column matching must ignore case.** The file spells the column
  `Tanksize`; phase 1 asked for `TankSize`. The exact-case miss dropped it
  from the SELECT and every dive kept its cylinder while silently losing
  its volume, and with it gas consumption and SAC. 396 dives were affected.
  Table and column lookups now resolve the file's own spelling.
- **`Divetime` is fractional minutes, not whole ones.** 393 of the 444
  dives have a non-integer value, so truncating cost nearly every dive up
  to 59 seconds. Durations are now rounded to whole seconds.

Full-file result after the fixes: 444 dives, 403 with profiles, 283,384
samples, 262 sites, parsed in about 0.5 seconds.

The file also settles phase 2's schema. The relational tables are `Buddy`,
`Place`, `City`, `Country`, `Equipment`, `Trip`, `Shop`, `Divetype`,
`Pictures`, `Fish` with `FishRel`, and `Brevets` for certifications. More
usefully, `Logbook` carries real foreign keys that phase 1 ignores in
favour of the free-text columns: `PlaceID`, `CityID`, `CountryID`,
`BuddyIDs`, `ShopID`, `TripID` and `UsedEquip`. Phase 2 should prefer those
over splitting text, which is why phase 1 produced 68 buddies from a
`Buddy` table holding 16 people. `Place` also carries `Lat` and `Lon`, so
sites gain coordinates that the text path cannot supply.

## Out of scope

- Phase 2: the buddy, equipment, trip and shop tables. Gated on a real
  file, because guessing column names produces a mapper that silently
  imports nothing, which is the failure the reporter already hit.
  Phase 2 must upgrade the records phase 1 derived from text rather than
  add a second set beside them: a buddy named in the `Buddy` column and the
  same buddy in the buddy table are one person. The phase 2 mapper keys its
  buddy and site `uddfId` values on the same normalised name phase 1 uses,
  so `PayloadMerger` folds them together instead of duplicating. This is the
  first thing to verify against a real file.
- Per-sample OTU support in `DiveProfilePoint`.
- Diving Log's XML export. `ImportFormat.divingLogXml` stays unimplemented.
- The `divelogxml` site-sharing files DiveLogDT writes.
- Photos. DiveLogDT stores media outside the logbook database.
- Any change to the DL7 parser.

## Risks

- The schema reference is Diving Log 5.0 as Subsurface reads it. DiveLogDT
  on macOS and iOS has evolved separately and Diving Log is now at 6.0. The
  probing reader is the mitigation: drift degrades to warnings rather than
  a failed import, and real files tell us what actually changed.
- Phase 1 alone does not close the reporter's complaint. It returns tanks,
  weights, sites, buddies and profiles. Equipment and trips need phase 2.
  The issue stays open until both ship.
- 500 dives with full profiles is the real workload. The reader must stream
  rather than build the entire sample set in memory at once, and the import
  should be measured at that size before shipping rather than assumed fine.
