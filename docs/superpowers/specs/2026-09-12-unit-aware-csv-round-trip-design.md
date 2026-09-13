# Unit-aware CSV export with a full re-import round trip

Date: 2026-09-12
Issue: #1813
Delivery: one PR

## Problem

Every CSV export (dives, sites, equipment) writes canonical metric values
regardless of the diver's unit settings. An imperial diver gets
`Max Depth (m)`, `Water Temp (°C)`, `Start Pressure (bar)` and has to convert
every cell. The equipment CSV writes `hose_length_m=0.5588` while the app
shows `22 in`. The Excel export already follows the diver's units; CSV is the
odd one out.

Investigation also found that no Submersion CSV re-imports today, metric or
not:

- The dives CSV is labelled "Submersion CSV" by `FormatDetector`, but no
  preset matches its headers (`submersion_native` expects camelCase names
  such as `maxDepth`), so the wizard opens Map Fields with nothing mapped.
  Map Fields has no target for Runtime, Name, weather, dive computer fields
  or custom fields, and its keyword auto-mapper lets later columns overwrite
  earlier ones (Site/Location, Bottom Time/Runtime, Visibility/Rating).
- The sites and equipment CSVs are detected as `ImportFormat.unknown` and the
  wizard cannot leave Confirm Source. `CsvTransformer` drops every row with
  no date, and `CsvCorrelator` only emits dives.
- `UnitDetector.parseHeaderUnit` only reads a trailing bracketed unit
  (`[ft]`), never Submersion's parenthesised `(ft)`, and knows no `°C`,
  `°F`, `m/s`, `km/h` or `kts`.
- `UddfEntityImporter` cannot store several exported fields: site
  `entryMethod` is never persisted and `waterType` only accepts the enum name;
  equipment attributes other than `size` are dropped and equipment types
  resolve by enum `.name` only, so "First Stage" becomes `other`; dive weather
  fields (`windSpeed`, `windDirection`, `cloudCover`, `precipitation`,
  `humidity`, `weatherDescription`) and custom fields are never read from a
  dive map.

## Goals

- The CSV export offers "My units" (default) and "Metric" at every entry
  point that writes a dives, sites or equipment CSV.
- Metric output is byte-for-byte identical to today's for all three exports.
- My units converts every unit-bearing column, names the unit in its header,
  and writes dates and times in the diver's formats with the format named in
  the header.
- No equipment attribute pair ever puts a converted value under a
  metric-suffixed key.
- A dives, sites or equipment CSV exported in either mode, by an imperial or
  a metric diver, re-imports through the import wizard with the same stored
  values, within the precision the file wrote.

## Non-goals

- Fields the export never wrote (equipment status, purchase price, site
  difficulty, second and later tanks, dive profiles) are not added. Adding
  columns would break Metric mode's byte-for-byte guarantee.
- The generic CSV pipeline (presets, Map Fields, `CsvTransformer`) is not
  reworked. A Submersion CSV whose columns were renamed in a spreadsheet
  falls back to the generic path as it does today.
- The observations CSV has no unit-bearing columns and is unchanged.

## Decisions

| Topic | Decision |
| --- | --- |
| Entry points | Transfer page CSV dialog, dive detail CSV, dive list bulk CSV |
| Default and memory | Starts at My units; the last choice is remembered per device |
| Attribute format (My units) | Catalog suffix dropped, display symbol on the value: `hose_length=22 in` |
| Imperial tank size | Rated capacity in cuft, plus a `Working Pressure` column in My units |
| Dates and times (My units) | Diver's date and time formats; the pattern is named in the header |
| Month names | Always English, so any device can parse them |
| Number format | Always `.` as the decimal separator, never the locale's |
| Importer approach | Three dedicated Submersion CSV formats with purpose-built parsers |
| New site from a dives CSV | Parse the Location column best-effort into region and country |

## Design

### 1. Column codec (shared by export and import)

A new `lib/core/services/export/csv/submersion_csv_codec.dart` (with small
siblings as needed to stay under 400 lines per file) owns the file format:

- **Header grammar.** A header is `Base` or `Base (suffix)`. The suffix is a
  unit symbol (`m`, `ft`, `°C`, `°F`, `bar`, `psi`, `L`, `cuft`, `kg`, `lbs`,
  `m/s`, `km/h`, `kts`, `min`, `%`) or a date/time format name
  (`MM/DD/YYYY`, `DD/MM/YYYY`, `YYYY-MM-DD`, `MMM D, YYYY`, `D MMM YYYY`,
  `DD.MM.YYYY`, `12-hour`, `24-hour`), taken from
  `DateFormatPreference.displayName` and `TimeFormat.displayName`.
  `splitHeader('Max Depth (ft)')` returns base `Max Depth`, suffix `ft`.
- **Column specs.** Each unit-bearing column is declared once: base name,
  quantity (depth, temperature, pressure, volume, tank capacity, weight, wind
  speed), and decimals per unit. The exporter asks the spec for the header and
  the formatted value; the importer asks it to parse the suffix and convert
  the value to canonical metric.
- **Units value.** `CsvExportUnits` carries the resolved units for one
  export: either `CsvExportUnits.metric` (today's symbols, today's
  formatting, ISO dates) or `CsvExportUnits.fromSettings(AppSettings)`.
- **Tank capacity pair.** `ratedCapacityCuft(volumeL, workingPressureBar)`
  and `volumeLitersFromCapacity(cuft, workingPressureBar)` are exact
  inverses: both consult `TankPresets` first (a new reverse lookup by rated
  capacity and working pressure) and fall back to ideal gas
  (`L x bar / 28.3168`), assuming 200 bar when the working pressure is blank,
  the same assumption `UnitFormatter.formatTankVolume` makes.

### 2. Export side

`CsvExportService.generateDivesCsvContent`, `generateSitesCsvContent` and
`generateEquipmentCsvContent` (and their share and save wrappers, and the
`ExportService` facade) take an optional `CsvExportUnits units`, defaulting
to `CsvExportUnits.metric`, so every existing caller and test keeps
byte-identical output.

In My units mode:

| Column | Metric user | Imperial user | Decimals |
| --- | --- | --- | --- |
| Max Depth, Avg Depth, Visibility, site Max Depth | m | ft | 1 |
| Water Temp, Air Temp | °C | °F | 0 |
| Start Pressure, End Pressure | bar | psi | bar 1, psi 0 |
| Tank Volume | L (physical volume) | cuft (rated capacity) | L 1, cuft 1 |
| Working Pressure (new column, after Tank Volume) | bar | psi | bar 1, psi 0 |
| Wind Speed | km/h or kts, per the diver's wind setting | same | 1 |
| Buoyancy, Dry Weight | kg | lbs | 2 |
| Date, Time, Purchase Date, Last Service, Next Service Due | diver's formats | diver's formats | n/a |

Durations (`min`), percentages, coordinates, ratings and free text are the
same in both modes. Every My units header carries its unit or format, for
example `Date (DD/MM/YYYY)`, `Time (12-hour)`, `Max Depth (ft)`,
`Water Temp (°F)`. Decimals were chosen so no My units value is rounded more
coarsely than its metric counterpart.

**Equipment `Attributes` column in My units.** A curated number attribute
whose catalog dimension carries a unit drops its metric key suffix (`_m`,
`_kg`, `_l`, `_bar`, `_mps`, `_h`) and carries the display symbol from
`attributeUnitSymbol`, with the value converted by
`attributeDisplayFromMetric` and rounded by the codec's attribute decimals
(1 for every unit except a cylinder's water volume in cuft, which needs 3
to round trip), trailing zeros trimmed, `.` decimal:
`hose_length=22 in`, `speed=30 ft/min`, `burn_time=90 min`,
`lift_capacity=40 lbs`, `volume=0.392 cuft`. Date attributes are written in
the file's date format. Text, choice, flag, `thickness_mm` and custom
attributes are written exactly as in Metric mode. Metric mode keeps today's
`key=valueNum` pairs.

**UI.**

- `CsvExportDialog` returns the data type and a `CsvUnitMode`
  (`myUnits`, `metric`), shown as a two-segment control under the data type.
  The control is hidden for the observations type.
- `showExportDestinationSheetWithOptions` gains `showCsvUnitsToggle` and
  returns the chosen mode on `ExportChoice`; the dive detail page and the
  dive list bulk export pass it for CSV.
- A `csvUnitModeProvider` notifier backed by `sharedPreferencesProvider`
  remembers the last choice on the device, defaulting to `myUnits`. The
  dialog and the sheet read it as their initial value and write the user's
  choice back.
- `ExportNotifier` builds `CsvExportUnits` from `settingsProvider` when the
  mode is `myUnits`.
- New strings are added to `app_en.arb` and translated in all 11 locales.

### 3. Detection

`ImportFormat` gains `submersionDivesCsv`, `submersionSitesCsv` and
`submersionEquipmentCsv`, each with a display name, `isSupported = true`, a
`parserForFormat` entry and a source-override option. `needsFieldMapping`
stays tied to `ImportFormat.csv`, so these formats parse straight after
Confirm Source, like UDDF.

`FormatDetector._detectCsv` checks the header's base names (suffixes
stripped by the codec) against each export's signature before the generic
app scorers run. A signature is the full set of that export's always-present
base names, so a CSV from another app cannot match by accident:

- Dives: Dive Number, Name, Date, Time, Site, Location, Max Depth,
  Avg Depth, Bottom Time, Runtime, Water Temp, Air Temp, Visibility,
  Visibility Rating, Dive Type, Buddy, Dive Master, Rating, Start Pressure,
  End Pressure, Tank Volume, O2 %, Dive Computer, Serial Number,
  Firmware Version, Notes, Wind Speed, Wind Direction, Cloud Cover,
  Precipitation, Humidity, Weather Description. `Working Pressure` and
  `custom:*` columns are allowed extras.
- Sites: Name, Country, Region, Latitude, Longitude, Max Depth, Water Type,
  Current, Entry Type, Rating, Description, Notes.
- Equipment: Name, Type, Brand, Model, Serial Number, Size, Thickness,
  Purchase Date, Last Service, Next Service Due, Buoyancy, Dry Weight,
  Attributes, Components, Active, Notes.

### 4. Parsers

A shared `SubmersionCsvReader` parses the file with the `csv` package,
indexes columns by base name, and resolves each unit-bearing column's suffix
through the codec. A missing suffix means metric and ISO, which is exactly
what a Metric-mode file contains. Each parser emits the map keys and Dart
types `UddfEntityImporter` already reads (strict casts noted).

**Dives (`SubmersionDivesCsvParser`).**

- `dateTime`: Date plus Time, parsed with the header's patterns (English
  month names), built as a UTC wall clock like every other importer.
- `diveNumber` (int, honoured only when the existing "Retain dive numbers"
  switch is on), `name`, `maxDepth`, `avgDepth`, `waterTemp`, `airTemp` as
  `double`.
- `duration` and `runtime` as `Duration` from the minute columns.
- `visibilityMeters` (`double`); `visibility` from Visibility Rating through a
  display-name lookup, only when there is no measured distance.
- `diveTypeIds` from the `; `-joined names via `DiveTypeEntity.generateSlug`;
  types that are not built in also go out as `diveTypes` entities
  (`{id, name, uddfId}`) so they are created.
- `buddy` and `diveMaster` as the legacy free-text fields, the same fields the
  export reads.
- `rating` (int), `notes`, `diveComputerModel`, `diveComputerSerial`,
  `diveComputerFirmware`.
- `tanks`: one tank map (`List<Map<String, dynamic>>`) with `volume`
  (`double`, from litres or from rated cuft through the capacity pair),
  `workingPressure`, `startPressure`, `endPressure`, and
  `gasMix: GasMix(o2: ..., he: 0)`. No tank when every tank cell is blank.
- Weather: `windSpeed` (m/s, converted from m/s, km/h or kts),
  `windDirection`, `cloudCover`, `precipitation` through display-name
  lookups, `humidity`, `weatherDescription`.
- `customFields` from `custom:<key>` columns, with the export's
  formula-injection `'` prefix removed from both key and value when it
  precedes one of the characters `sanitizeCsvField` guards.
- `site`: a sites entity per distinct Site name (`{uddfId, name}`), linked
  by `uddfId`. For a site that turns out to be new, the Location column
  (`[city or island · ]region, country`) is parsed best-effort: country is
  the text after the last comma, region the rest, any prefix before ` · `
  dropped. Existing sites matched by the duplicate checker are never changed.

**Sites (`SubmersionSitesCsvParser`).** `name`, `country`, `region`,
`latitude` and `longitude` as `double`, `maxDepth`, `rating` (`double`),
`description`, `notes`, `waterType` and `entryMethod` as enum `.name` values
through display-name lookups. The always-blank Current column is ignored.

**Equipment (`SubmersionEquipmentCsvParser`).** `name`, `type` (through a new
`EquipmentType` display-name lookup that also accepts `.name`), `brand`,
`model`, `serialNumber`, `size`, `purchaseDate`, `lastServiceDate`,
`serviceIntervalDays` (Next Service Due minus Last Service, in days, when
both are present), `isActive` (Yes/No), `notes`, and `attributes`:

- Thickness, Buoyancy and Dry Weight become curated attributes
  (`thickness_mm` text, `buoyancy_kg` and `dry_weight_kg` in kg).
- Each `Attributes` pair resolves against `EquipmentAttributeCatalog`: an
  exact curated key with a bare number is metric; a suffix-stripped base with
  a trailing symbol is matched to the catalog key whose stripped base it is
  and converted with `attributeMetricFromDisplay`; a date attribute is read
  as epoch milliseconds (Metric) or the file's date format (My units). Keys
  the catalog does not know become custom text attributes.
- `components`: each part name in the Components column resolves to another
  row of the same file by name, emitted as `{componentRef, role, sortOrder}`
  against that row's `uddfId`. An ambiguous or missing name adds a payload
  warning and is skipped.

### 5. Importer gaps closed

In `UddfEntityImporter` (and its helpers, split out where the file would
otherwise grow):

- Sites: persist `entryMethod`; accept `waterType` as enum `.name` (the
  parser already maps display names).
- Equipment: write every entry of an `attributes` list, not only `size`.
- Dives: read `windSpeed`, `windDirection`, `cloudCover`, `precipitation`,
  `humidity`, `weatherDescription` and `customFields` from the dive map.
  `createDive` already persists all of them.
- One generic display-name lookup (`enumByDisplayName`, falling back to
  `.name`) serves every enum the exports write by display name
  (`WaterType`, `EntryMethod`, `EquipmentType`, `Visibility`,
  `CurrentDirection`, `CloudCover`, `Precipitation`), instead of growing
  `enums.dart`. Their display names are constant English strings, so the
  lookup is exact.

Duplicate handling is unchanged: sites match by name then 100 m, equipment
by name and type, dives by time, depth and duration, and the review step
offers the existing choices.

## Testing

TDD throughout. The Metric-mode byte-identical fixtures are captured from
the current code before any exporter change.

- **Codec unit tests:** header split and format for every unit and every
  date and time format; value conversion both ways; the tank capacity pair
  as an exact inverse (preset and ideal-gas paths, blank working pressure).
- **Display-name lookups:** every enum value round trips through
  `displayName`, and `.name` is accepted.
- **Exporter tests:** Metric output identical to the captured fixtures for
  dives, sites and equipment; My units output for an imperial diver and a
  metric diver, including headers, attribute pairs, the Working Pressure
  column and date and time formats.
- **Detector tests:** each of the three exports, in both modes, for both unit
  systems, is detected as its format; generic, MacDive and Subsurface CSV
  fixtures are not.
- **Parser tests:** payload maps and Dart types for each parser, including
  strict-cast keys.
- **Round-trip integration tests:** export, detect, parse, and import through
  `UniversalAdapter` into an in-memory database, then read the entities back
  and compare with the originals within the precision the file wrote. Run
  for dives, sites and equipment, imperial and metric divers, both modes.
- **Widget tests:** the dialog's unit control (hidden for observations), the
  sheet's unit control, and the remembered choice.

## Risks

- **Spreadsheet edits.** A user who opens the CSV in a spreadsheet and saves
  it may get reformatted dates. The header still names the intended format;
  values that fail to parse add a per-row warning instead of aborting the
  import.
- **Custom attribute key collisions.** The export does not mark custom
  attributes, so a custom key equal to a curated key (or its stripped base)
  imports as the curated attribute. This matches how the Metric export
  already behaves.
- **File size.** `uddf_entity_importer.dart` and `enums.dart` are large;
  new helpers go into their own files.
