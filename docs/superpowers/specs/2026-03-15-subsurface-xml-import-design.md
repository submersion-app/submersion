# Subsurface XML (.ssrf) Import Support

## Problem

The universal import wizard detects Subsurface XML files with 0.98 confidence
(`FormatDetector` matches `<divelog` + `"subsurface"`), but the parser routes
them to `UddfImportParser`, which calls `UddfFullImportService.importAllDataFromUddf()`.
That method requires a `<uddf>` root element and throws `FormatException` when it
encounters `<divelog>`. The error is caught and returned as an empty `ImportPayload`
with a warning -- the user sees no data imported.

Subsurface XML is structurally different from UDDF. It needs its own parser.

## Approach

Create a dedicated `SubsurfaceXmlParser` implementing `ImportParser`. It parses
the `<divelog program='subsurface'>` XML directly into `ImportPayload` maps using
the same key names that `UddfEntityImporter` already consumes. One wiring change
in `_parserFor()` routes `ImportFormat.subsurfaceXml` to the new parser.

### Why not transform to UDDF first?

Subsurface has fields UDDF does not model (SAC, OTU, CNS, current/surge/chill
ratings, weight system descriptions, suit). A transformation layer would be lossy,
fragile, and harder to debug than direct parsing.

## File Layout

| File | Purpose |
|------|---------|
| `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` | New parser (~350-450 lines) |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | 1-line wiring change |
| `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` | Tests (~400-500 lines) |

## Parser Structure

`SubsurfaceXmlParser implements ImportParser`:

- `supportedFormats` -> `[ImportFormat.subsurfaceXml]`
- `parse(Uint8List, {ImportOptions?})` decodes UTF-8, parses XML, delegates to private methods:
  - `_parseSites(XmlElement divesites)` -> site maps
  - `_parseDive(XmlElement dive, Map siteMap)` -> dive map
  - `_parseCylinders(XmlElement dive)` -> tank list
  - `_parseWeights(XmlElement dive)` -> weight list
  - `_parseProfile(XmlElement divecomputer)` -> profile point list
  - `_parseTrips(XmlElement dives)` -> trip list + assigns `tripRef` on dives

Single file since XML traversal logic is cohesive.

## Data Mapping

### Sites (`<divesites> / <site>`)

| Subsurface XML | Map Key | Notes |
|---|---|---|
| `<site uuid='..'>` | `uddfId` | Used for site-dive linking |
| `name` attr | `name` | |
| `gps='lat lon'` | `latitude`, `longitude` | Split space-separated string |
| `<geo cat='2'>` | `country` | cat=2 is country in Subsurface taxonomy |
| `<geo cat='3'>` | `region` | cat=3 is state/province |
| `<notes>` child | `notes` | Site-level notes |

### Dives (`<dives> / <dive>`)

| Subsurface XML | Map Key | Type |
|---|---|---|
| `date` + `time` attrs | `dateTime` | `DateTime` |
| `number` | `diveNumber` | `int` |
| `duration` (`'M:SS min'`) | `duration`, `runtime` | `Duration` |
| `<depth max>` | `maxDepth` | `double` (strip ` m`) |
| `<depth mean>` | `avgDepth` | `double` |
| `<temperature water>` | `waterTemp` | `double` (strip ` C`) |
| `<divetemperature air>` | `airTemp` | `double` |
| `visibility` attr | `visibility` | `Visibility` enum (1-5 scale) |
| `rating` attr | `rating` | `int` |
| `current` attr | `currentStrength` | `CurrentStrength` enum (1-5) |
| `sac` attr | appended to `notes` | Informational text |
| `tags` attr | `tagRefs` | Comma-separated, creates tag entities |
| `divesiteid` attr | `site` -> `{'uddfId': id}` | Links to parsed site |
| `<buddy>` | `buddy` | `String` |
| `<divemaster>` | `diveMaster` | `String` |
| `<notes>` | `notes` | `String` |
| `<suit>` | appended to `notes` | No suit field in Dive entity |
| `<divecomputer model>` | `diveComputerModel` | `String` |
| `watersalinity` attr | `waterType` | `WaterType` (>=1020 = salt) |

### Cylinders (`<cylinder>`)

| Subsurface XML | Map Key | Notes |
|---|---|---|
| `size` | `volume` | Strip ` l` |
| `workpressure` | `workingPressure` | Strip ` bar` |
| `description` | `name` | e.g. "AL80" |
| `o2` | `o2` | Percentage (absent = 21%) |
| `he` | `he` | Percentage (absent = 0%) |
| `start` | `startPressure` | Strip ` bar` |
| `end` | `endPressure` | Strip ` bar` |
| first/last sample `pressure0` | fallback pressures | When explicit attrs absent |

### Weights (`<weightsystem>`)

| Subsurface XML | Map Key | Notes |
|---|---|---|
| `weight` | `amount` | Strip ` kg` |
| `description` | `notes` | e.g. "belt" |

### Profile Samples (`<sample>`)

| Subsurface XML | Map Key | Notes |
|---|---|---|
| `time` (`'M:SS min'`) | `timestamp` | Total seconds as `int` |
| `depth` | `depth` | `double`, strip ` m` |
| `temp` | `temperature` | `double`, strip ` C` |
| `pressure0` | `pressure` | `double`, strip ` bar` |

### Trips (`<trip>` wrapper in `<dives>`)

| Subsurface XML | Map Key | Notes |
|---|---|---|
| `date` + `time` | `startDate`, `endDate` | endDate = last dive in trip |
| `location` | `name`, `location` | |
| `<notes>` | `notes` | |
| auto-generated id | `uddfId` | For dive-trip linking |

### Tags (from dive `tags` attribute)

Each unique comma-separated value becomes a tag entity map:
- `name`: tag string (e.g. "shore", "student")
- `uddfId`: tag name (for dedup/linking)

## Value Parsing Helpers

### Unit Stripping

Subsurface always saves SI units internally (`'2.41 m'`, `'196.9 bar'`, `'21.0 C'`,
`'6.35 kg'`). A single helper strips the suffix:

```dart
double? _parseDouble(String? value) {
  if (value == null) return null;
  return double.tryParse(value.split(' ').first);
}
```

### Duration Parsing

Format: `'M:SS min'` (e.g. `'68:12 min'`, `'0:42 min'`).
Convert to `Duration(minutes: M, seconds: SS)`.

### Sample Timestamps

Same `'M:SS min'` format, converted to total seconds as `int`.

## Edge Cases

| Case | Handling |
|------|----------|
| Empty `<cylinder />` elements | Skip cylinders with no `size` or `description` |
| Leading comma in buddy text | Trim leading/trailing commas and whitespace |
| Missing visibility/rating/current | Leave as `null` |
| Salinity -> WaterType | >= 1020 g/l = salt, < 1020 = fresh, absent = null |
| Tank pressure fallback | Use first/last sample `pressure0` when cylinder lacks start/end |
| Malformed XML | Catch `XmlException`, return empty payload with error warning |
| Missing `<divelog>` root | Return empty payload with error warning |
| Individual dive parse failure | Skip dive, add warning, continue with remaining dives |
| Visibility enum mapping | 1=poor, 2=fair, 3=good, 4=veryGood, 5=excellent |
| CurrentStrength mapping | 1=none, 2=mild, 3=moderate, 4=strong, 5=extreme |

## Wiring Change

In `universal_import_providers.dart`, method `_parserFor()`:

```dart
// Before:
ImportFormat.uddf || ImportFormat.subsurfaceXml => UddfImportParser(),

// After:
ImportFormat.uddf => UddfImportParser(),
ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
```

No changes to detection, import pipeline, UI, or database layers.

## Testing

### Unit Tests

Test groups using inline XML strings:

1. **Minimal dive** - date/time/duration/depth only
2. **Full dive** - all attributes including buddy, divemaster, notes, suit,
   visibility, rating, current, SAC, tags, cylinders, weights, profile samples
3. **Sites** - GPS parsing, geo taxonomy, site-dive linking
4. **Trips** - trip wrapper grouping, name/date, tripRef on child dives
5. **Tags** - comma-separated extraction, deduplication across dives
6. **Cylinders** - gas mix (air/nitrox/trimix), empty cylinder skip, pressure fallback
7. **Weights** - amount + description
8. **Profile samples** - timestamp/depth/temp/pressure, correct ordering
9. **Edge cases** - empty file, malformed XML, missing attrs, buddy cleanup
10. **Integration** - parse `subsurface_export.ssrf`, verify 16 dives, 5 sites

### No Existing Test Changes

Parser swap is a single wiring line. Existing tests remain untouched.
