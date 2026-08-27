# MacDive Import Robustness — Design

**Status:** Draft
**Author:** Eric Griffin
**Created:** 2026-04-21
**Context:** Closes GitHub issues #178 (MacDive UDDF/XML not recognized and missing fields) and #179 (MacDive SQLite import), plus user complaints on ScubaBoard thread 667061 (posts #296, #297, #301, #304).

## Problem

MacDive users migrating to Submersion today can try three routes, none of which work well:

- **UDDF export** is partially supported. A dialect normalizer (PR #42 / `MacDiveDialect`) exists but leaves many fields on the floor — dive operator, boat info, weather, surface conditions, personal mode, site water type / difficulty / body of water, and `divenumberofday`. The UDDF export itself also *does not contain tags* (MacDive's UDDF exporter omits them), so there is nothing to import on that path.
- **Native XML export** (`macdive_logbook.dtd`) is not recognized by the format detector at all. This is the only MacDive export that carries tags.
- **SQLite database** is the complete source of truth (tags, critters, events, photos, service records, full relationship graph), but there is no code to read it.

Across these three formats, the user-visible failure modes are: tags never imported, gear sometimes missing, gas switches missing for deco dives, dive profile empty for some dives (now fixed), and "import parser does not recognize the format" for .xml files.

## Goals

1. Fix the known gaps in UDDF import so MacDive UDDF users recover everything their export contains.
2. Add MacDive native XML as a first-class import format so users who want tags can get them.
3. Add MacDive SQLite as a first-class import format so users get everything — tags, critters, events, service records, and full relationship integrity.
4. Add photo import so dive images from MacDive land in Submersion.
5. Do all of this within the existing unified-import wizard architecture, without forking the UI flow or the duplicate checker.

## Non-Goals

- Two-way sync with MacDive.
- Automatic polling of the MacDive database for incremental updates (single-shot import only in this iteration).
- Reading MacDive's iOS backup format or CloudKit sync data.
- Preserving MacDive UUIDs as the canonical Submersion identifier (we store them on the side for dedup, see below).

## User-reported issues (baseline to verify against)

| Source | Complaint | Resolved by |
|---|---|---|
| glazerama (post #296) | MacDive UDDF import missing tags | Milestone 2 (XML has tags; UDDF doesn't) or Milestone 3 (SQLite) |
| glazerama (post #296) | MacDive `.xml` not recognized | Milestone 2 |
| Josh the diver (post #297) | Gas switches for deco not imported from UDDF | Milestone 1 |
| Josh the diver (post #297) | Gear didn't import | Milestone 1 |
| GH #178 | UDDF/XML not recognized; UDDF importer gaps | Milestones 1 + 2 |
| GH #179 | Support MacDive SQLite | Milestone 3 |

## Architecture overview

The unified import pipeline already has the right shape. No flow changes are required.

```
[File picker | drag-drop]
    │
    ▼
UniversalImportNotifier.pickFile() / .loadFileFromBytes()
    │
    ▼
_detectFormat() ──► FormatDetector.detect()
    │                    ├─ binary: FIT, SQLite
    │                    ├─ XML root: UDDF, Subsurface, DivingLog, SML, [+ MacDive XML (new)]
    │                    └─ CSV headers: scored against preset signatures
    │
    ▼ (if SQLite: Shearwater check, [+ MacDive check (new)])
    │
    ▼
Step: Confirm Source  ──► user can override detected app/format
    │
    ▼
Step: Map Fields (CSV only)
    │
    ▼
_parseAndCheckDuplicates() → _parserFor(format) → ImportParser
    │                         ├─ csv, uddf, subsurfaceXml, fit, shearwaterDb
    │                         └─ [+ macdiveXml, macdiveSqlite (new)]
    │
    ▼
ImportPayload → ImportDuplicateChecker → Review → UddfEntityImporter → DB
```

**Additive changes only.** Each milestone adds enum values, a parser class, and (where applicable) a DB reader or XML helper. Duplicate checking, review UI, and import writer are untouched.

## Milestone 1 — UDDF gap-fill

### Scope

1. **Fix the `<link ref>` disambiguation in `informationbeforedive`**. MacDive emits `<link ref="UUID-1"/>` for the site and `<link ref="UUID-2"/>` for the buddy with no positional or attribute distinction. The current parser assumes positional order; verify and fix by resolving each UUID against the top-level `<divesite>` and `<diver>` sections and binding by ID class.
2. **Fix equipment ref resolution**. `<equipmentused><link ref="UUID"/></equipmentused>` references gear defined in the top-level `<diver><owner><equipment>` section. Verify refs are resolved and gear items attach to the dive.
3. **Fix gas switches**. MacDive emits `<switchmix ref="gas-UUID"/>` in waypoints (confirmed: 347 in the sample). Verify the existing waypoint parser at `uddf_full_import_service.dart:1452` correctly (a) resolves the ref to the right gas mix and (b) represents the switch as a dive-level gas change the consolidator can render.
4. **Handle `<surfaceintervalbeforedive><infinity/></surfaceintervalbeforedive>`**. MacDive uses this for first dives of a series. Current code runs `int.tryParse` on empty text and silently produces nothing; this is fine today but should be explicit: treat `<infinity/>` as "no prior dive" and leave surface interval null.
5. **Extend the dialect to rewrite MacDive-specific quirks that still cause data loss**, not just the three already handled. Specifically:
   - Normalize empty-content equipment `<link ref="(null)"/>` refs (MacDive writes `man-(null)` manufacturer IDs).
6. **Extend `UddfFullImportService` to extract the ignored fields**, storing them on the dive map so the adapter layer can persist them:
   - `divenumberofday` (int)
   - `diveoperator` (string)
   - `boatname`, `boatcaptain` (strings)
   - `weather`, `surfaceconditions` (strings, mapped to enum where possible)
   - `personalmode`, `altitudemode`, `signature` (strings)
   - Site: `watertype`, `bodyofwater`, `difficulty`, `flag` (strings, mapped to enum where our domain has one)
7. **Preserve the MacDive dive UUID** in the dive map (new key `sourceUuid`) so Milestone 3's SQLite import can deduplicate against it on re-import.
8. **Verify tank pressure unit handling**. MacDive writes Pascals (e.g. `13789514.18` Pa ≈ 2000 psi). Confirm the existing conversion to the Submersion canonical unit (bar) is correct.
9. **Store unmapped fields as warnings**, not silent drops, so the user sees what was ignored.

### Components touched

| File | Change |
|---|---|
| `lib/core/services/export/uddf/dialects/macdive_dialect.dart` | Add handling for `<infinity/>` surface interval; ensure idempotency for new normalizations. |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Extract ignored fields; fix ref disambiguation; preserve dive UUID. |
| `lib/core/services/export/uddf/uddf_import_parsers.dart` | Helper for `<link ref>` → entity-class resolution. |
| `lib/features/universal_import/data/parsers/uddf_import_parser.dart` | Pass through new dive-map keys. |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | Surface new fields in `_diveToEntityItem` subtitle where useful. |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Write new fields to DB. |
| Database schema | New columns on `dives` / `dive_sites` where we don't already have them (depends on what's missing; likely: `source_uuid`, `dive_number_of_day`, `weather`, `surface_conditions`, `personal_mode`, `dive_operator`, `boat_name`, `boat_captain`). |
| `test/core/services/export/uddf/uddf_macdive_import_test.dart` | New assertions for each new field and for ref disambiguation. |

### Data flow

`UDDF bytes → UddfNormalizer (MacDiveDialect) → XmlDocument → UddfFullImportService.importAllDataFromUddf → ImportPayload (via UddfImportParser) → unchanged downstream.`

### Error handling

- An unresolvable `<link ref>` produces an `ImportWarning` attached to the dive, and the field is left null. We do not fail the import.
- An unknown enum value (e.g. `watertype=freshwater-variant`) falls through to `null` with a warning citing the raw value.
- Invalid numeric parse continues to skip silently (existing behavior).

### Testing

- Fix existing test fixtures to exercise the `<infinity/>` and multi-link cases.
- Add a 3-dive hand-authored fixture that pairs with the 29MB real file to lock down each new field one at a time.
- Integration test: run the 29MB sample against the pipeline end-to-end and assert counts (540 dives, 373 sites, 33 buddies, etc.) against the SQLite truth.

---

## Milestone 2 — MacDive native XML

### Scope

Add a new import format for MacDive's proprietary XML (DOCTYPE `http://www.mac-dive.com/macdive_logbook.dtd`, root `<dives>`, per-dive structure). This is the only MacDive export that includes tags.

### Recognizing the format

**Shape of a MacDive XML file:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dives SYSTEM "http://www.mac-dive.com/macdive_logbook.dtd">
<dives>
    <units>Imperial</units>
    <schema>2.2.0</schema>
    <dive>
        <date>2026-03-11 14:09:18</date>
        <identifier>20260311140918-CB115EF0</identifier>
        <diveNumber>540</diveNumber>
        ...
        <site>
            <name>El Canon</name>
            <country>Mexico</country>
            ...
        </site>
        <tags><tag>Liveaboard</tag><tag>Socorro 2026</tag></tags>
        <gear><item><type>Regulator</type>...</item></gear>
        <gases><gas><pressureStart>3118</pressureStart>...</gas></gases>
        <samples><sample><time>0</time><depth>0</depth>...</sample></samples>
    </dive>
</dives>
```

Notable characteristics:
- Flat per-dive records (not repetition-group oriented like UDDF).
- `<units>` at root (`Imperial` or `Metric`) — must be respected for every numeric field.
- `<identifier>` is a stable dive ID derived from datetime + computer serial (`20260311140918-CB115EF0`).
- Each `<dive>` has inline `<site>`, `<gear>`, `<gases>`, `<samples>` — no external ID references.
- `<tags>` is what users care about most.

### Detection

`FormatDetector._detectXml` gets a new branch:

```dart
if (lower.contains('<!doctype dives') ||
    (lower.contains('<dives>') && lower.contains('<schema>'))) {
  return const DetectionResult(
    format: ImportFormat.macdiveXml,
    sourceApp: SourceApp.macdive,
    confidence: 0.95,
  );
}
```

The DOCTYPE check is the strongest signal; the `<dives>` + `<schema>` fallback catches files where the DOCTYPE was stripped. Placed before the generic UDDF check since both are XML.

### Components

| File | Purpose | Lines (est.) |
|---|---|---|
| `lib/features/universal_import/data/models/import_enums.dart` | Add `ImportFormat.macdiveXml`, add to `isSupported`, add `SourceOverrideOption` for MacDive XML. | +20 |
| `lib/features/universal_import/data/services/format_detector.dart` | New DOCTYPE/root detection branch. | +15 |
| `lib/features/universal_import/data/parsers/macdive_xml_parser.dart` | **New**. Implements `ImportParser` for `ImportFormat.macdiveXml`. Delegates to a reader service. | ~200 |
| `lib/features/universal_import/data/services/macdive_xml_reader.dart` | **New**. Parses `<dives>` root into typed Dart objects (`MacDiveXmlDive`, `MacDiveXmlSite`, `MacDiveXmlTag`). Handles unit conversion (Imperial↔metric) centrally. | ~350 |
| `lib/features/universal_import/data/services/macdive_value_mapper.dart` | **New**. Maps raw MacDive enum strings (`dive type`, `entry type`, `water type`, `weather`) to Submersion domain enums. | ~150 |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Add `macdiveXml → MacDiveXmlParser()` to `_parserFor` switch. | +2 |
| `test/features/universal_import/data/parsers/macdive_xml_parser_test.dart` | **New**. Unit tests with small hand-authored fixtures. | ~300 |
| `test/features/universal_import/data/services/macdive_xml_reader_test.dart` | **New**. Unit-conversion tests, tag extraction, multi-dive. | ~250 |
| `test/fixtures/macdive_xml/*.xml` | **New**. 3-4 small redacted fixtures: single dive, multi-dive, all fields populated, edge cases (missing optional fields, imperial, metric). | n/a |

### Data model

`MacDiveXmlReader` produces typed objects:

```dart
class MacDiveXmlLogbook {
  final UnitSystem units;           // Imperial | Metric
  final String schemaVersion;
  final List<MacDiveXmlDive> dives;
}

class MacDiveXmlDive {
  final String identifier;          // stable per-dive ID
  final DateTime date;
  final int? diveNumber;
  final int? repetitiveDive;
  final double? rating;             // 0.0 - 5.0
  final double? maxDepthRaw;        // unit depends on logbook.units
  final double? averageDepthRaw;
  final double? cns;
  final String? decoModel;
  final int? duration;              // seconds
  final int? surfaceInterval;       // minutes (per schema)
  final int? sampleInterval;        // seconds
  final String? gasModel;
  final double? airTempRaw;
  final double? tempHighRaw;
  final double? tempLowRaw;
  final String? visibility;
  final String? weight;
  final String? notes;
  final String? diveMaster;
  final String? diveOperator;
  final String? skipper;
  final String? boat;
  final String? weather;
  final String? current;
  final String? surfaceConditions;
  final String? entryType;
  final String? computer;
  final String? serial;
  final String? diver;
  final MacDiveXmlSite? site;
  final List<String> tags;
  final List<String> diveTypes;
  final List<String> buddies;
  final List<MacDiveXmlGearItem> gear;
  final List<MacDiveXmlGas> gases;
  final List<MacDiveXmlSample> samples;
}

class MacDiveXmlSite {
  final String? name;
  final String? country;
  final String? location;
  final String? bodyOfWater;
  final String? waterType;
  final String? difficulty;
  final double? altitude;
  final double? latitude;            // 0.0 means "not set" in MacDive
  final double? longitude;
}

// etc.
```

`MacDiveXmlParser` then maps this into the Submersion `ImportPayload` using the same conventions as `ShearwaterDiveMapper` (dive map keys match what `UddfEntityImporter` consumes, e.g. `dateTime`, `maxDepth`, `siteName`, `tags`, `gasMix`).

### Unit handling

`<units>Imperial</units>` means: depth in feet, temps in Fahrenheit, pressure in psi, weight in pounds. `<units>Metric</units>` means: meters, Celsius, bar, kilograms.

The reader converts everything to Submersion's canonical internal units (meters, Celsius, bar, kilograms) at the reader boundary. The parser and payload never see raw imperial values.

### Tag mapping

MacDive tags are strings like `"Liveaboard"`, `"Socorro 2026"`. Map to Submersion `Tag` entities. Emit each unique tag as a separate entity in `ImportEntityType.tags` and attach to each dive via `tagRefs` (the same mechanism UDDF import already uses).

### Photos

Out of scope for this milestone. MacDive XML does contain `<photos>` / `<photo>` elements with file paths but we defer photo handling to Milestone 4.

### Gas/tank mapping

`<gases><gas>` in MacDive XML is per-dive — no dedup across dives on MacDive's side, so we dedup on our side (gas mixes by O2+He%, tanks by name+size+WP). Multiple gases per dive become multiple `tanks` entries with `tankIndex` and `gasMix` — matches UDDF's multi-tank pattern.

Gas switches for deco are implicit in the samples (a sample's pressure drops suddenly when the diver switches tanks). MacDive's XML doesn't emit explicit switch events; we reconstruct them from pressure drops during profile parsing if needed, or (preferred) we rely on MacDive's supplyType + duration per gas to infer which gas was active at which time.

### Testing

- Unit tests with small synthetic fixtures covering: Imperial units, Metric units, all optional fields populated, minimal-fields dive, tags round-trip, site with zero coordinates (0,0 means "no GPS"), multi-dive with shared site name.
- Integration test: parse the user's 30MB sample, assert the dive count matches the UDDF sample's dive count, assert tags come through.

---

## Milestone 3 — MacDive SQLite

### Scope

Read the MacDive Core Data SQLite database directly. This is the most complete path: 540 dives, 373 sites, 33 buddies, 32 gear, 39 tags, 19 critters (marine life), 7 events, 261 dive images (paths to photos — Milestone 4), 26 tanks, 6 gases, 469 tank-and-gas joins, 4 certifications, 1 service record.

### Recognizing the format

SQLite is already detected as a binary format. The `_detectFormat()` branch currently checks for Shearwater. We add a parallel check for MacDive:

```dart
if (detection.format == ImportFormat.sqlite) {
  if (await ShearwaterDbReader.isShearwaterCloudDb(bytes)) {
    detection = ...shearwater...;
  } else if (await MacDiveDbReader.isMacDiveDb(bytes)) {
    detection = const DetectionResult(
      format: ImportFormat.macdiveSqlite,
      sourceApp: SourceApp.macdive,
      confidence: 0.95,
    );
  }
}
```

`MacDiveDbReader.isMacDiveDb` queries `sqlite_master` for presence of `ZDIVE`, `ZDIVESITE`, `ZGAS`, and `ZTANKANDGAS`. All four must exist.

### Schema primer

MacDive is Apple Core Data, so tables have a `Z_` prefix and `Z_PK`/`Z_ENT`/`Z_OPT` bookkeeping columns. Relationships use `Z_N…` junction tables. Key tables (via `PRAGMA table_info` on the user's sample):

| Table | Purpose | Relevant columns |
|---|---|---|
| `ZDIVE` | Per-dive record. | `ZDIVENUMBER`, `ZRAWDATE`, `ZMAXDEPTH`, `ZAVERAGEDEPTH`, `ZTEMPHIGH`, `ZTEMPLOW`, `ZAIRTEMP`, `ZRATING`, `ZCNS`, `ZSURFACEINTERVAL`, `ZSAMPLEINTERVAL`, `ZSETPOINTHIGH`, `ZSETPOINTLOW`, `ZDECOMODEL`, `ZGASMODEL`, `ZCOMPUTER`, `ZCOMPUTERSERIAL`, `ZNOTES`, `ZWEATHER`, `ZVISIBILITY`, `ZWEIGHT`, `ZCURRENT`, `ZSURFACECONDITIONS`, `ZENTRYTYPE`, `ZDIVEMASTER`, `ZDIVEOPERATOR`, `ZBOATCAPTAIN`, `ZBOATNAME`, `ZPERSONALMODE`, `ZALTITUDEMODE`, `ZSIGNATURE`, `ZIDENTIFIER`, `ZUUID`, `ZRELATIONSHIPDIVESITE`, `ZRELATIONSHIPDIVER`, `ZRELATIONSHIPCERTIFICATION`, `ZRAWDATA` (BLOB), `ZSAMPLES` (BLOB), `ZTIMEZONE` (BLOB) |
| `ZDIVESITE` | Per-site record. | `ZNAME`, `ZCOUNTRY`, `ZLOCATION`, `ZBODYOFWATER`, `ZWATERTYPE`, `ZDIFFICULTY`, `ZFLAG`, `ZGPSLAT`, `ZGPSLON`, `ZALTITUDE`, `ZNOTES`, `ZUUID`, `ZIMAGE` |
| `ZBUDDY` | Per-buddy record. | `ZNAME`, `ZUUID` |
| `Z_1RELATIONSHIPDIVE` | Dive↔buddy junction. | `Z_5RELATIONSHIPDIVE`, `Z_1RELATIONSHIPBUDDIES` |
| `ZTANK` | Tank definition. | `ZNAME`, `ZSIZE`, `ZWORKINGPRESSURE`, `ZTYPE`, `ZUUID` |
| `ZGAS` | Gas mix definition. | `ZOXYGEN`, `ZHELIUM`, `ZNAME`, `ZMAXPPO2`, `ZMINPPO2`, `ZUUID` |
| `ZTANKANDGAS` | Dive↔tank↔gas junction (per-dive tank pressures). | `ZRELATIONSHIPDIVE`, `ZRELATIONSHIPTANK`, `ZRELATIONSHIPGAS`, `ZAIRSTART`, `ZAIREND`, `ZDURATION`, `ZISDOUBLE`, `ZORDER`, `ZSUPPLYTYPE` |
| `ZGEARITEM` | Gear inventory. | `ZNAME`, `ZMANUFACTURER`, `ZMODEL`, `ZSERIAL`, `ZTYPE`, `ZWEIGHT`, `ZPRICE`, `ZDATEPURCHASE`, `ZDATENEXTSERVICE`, `ZWARRANTY`, `ZURL`, `ZNOTES`, `ZUUID` |
| `Z_5RELATIONSHIPGEARITEMS` | Dive↔gear junction. | `Z_5RELATIONSHIPGEARTODIVES`, `Z_14RELATIONSHIPGEARITEMS` |
| `ZTAG` | Tag definition. | `ZNAME`, `ZUUID`, `ZIMAGE` |
| `Z_5RELATIONSHIPTAGS` | Dive↔tag junction. | `Z_5RELATIONSHIPDIVES`, `Z_17RELATIONSHIPTAGS` |
| `ZDIVETYPE` | Dive type definition. | `ZNAME`, `ZUUID` |
| `Z_5RELATIONSHIPDIVETYPES` | Dive↔divetype junction. | `Z_5RELATIONSHIPTYPETODIVES`, `Z_10RELATIONSHIPDIVETYPES` |
| `ZCERTIFICATION` | Cert record. | `ZAGENCY`, `ZNAME`, `ZATTAINED`, `ZEXPIRY`, `ZINSTRUCTORNAME`, `ZCARDFRONT`, `ZCARDBACK`, `ZUUID` |
| `ZCRITTER` | Marine-life sighting. | `ZNAME`, `ZSPECIES`, `ZSIZE`, `ZNOTES`, `ZIMAGE`, `ZUUID` |
| `Z_3RELATIONSHIPCRITTERTODIVE` | Sighting↔dive junction. | `Z_3RELATIONSHIPDIVETOCRITTER`, `Z_5RELATIONSHIPCRITTERTODIVE` |
| `ZCRITTERCATEGORY` | Critter category (genus/family). | `ZNAME`, `ZUUID` |
| `ZEVENT` | Timestamped dive event. | `ZTYPE`, `ZTIME`, `ZDETAIL`, `ZRELATIONSHIPEVENTTODIVE`, `ZUUID` |
| `ZDIVEIMAGE` | Photo reference (Milestone 4). | `ZPATH`, `ZORIGINALPATH`, `ZCAPTION`, `ZRELATIONSHIPDIVE`, `ZPOSITION`, `ZUUID` |
| `ZSERVICERECORD` | Gear service history. | `ZSERVICEDATE`, `ZSERVICEDBY`, `ZNOTES`, `ZRELATIONSHIPGEARITEM`, `ZUUID` |
| `ZDIVER` | Diver profile. | `ZFIRSTNAME`, `ZLASTNAME`, `ZBIRTHDATE`, `ZEMAILADDRESS`, `ZBLOODTYPE`, `ZEMERGENCYCONTACT`, `ZINSURANCEDAN`, `ZPHOTO`, `ZADDRESS*` |

### BLOB decoding — the novel piece

`ZRAWDATA`, `ZSAMPLES`, and `ZTIMEZONE` are `bplist00`-encoded (Apple binary property list). Magic bytes `62 70 6C 69 73 74 30 30` = "bplist00".

**Two options:**
- **(A) Use a pub package** — `bplist_parser` or similar. Pros: trivially small integration; cons: audit surface, transitive deps.
- **(B) Hand-roll a minimal decoder** — bplist v00 is well-documented (CFBinaryPList.c from Apple open source). Our needs are narrow: we only need to decode dictionaries, arrays, strings, numbers, dates, and data blobs, and the specific `NSMutableArray` / `NSDate` / `NSData` patterns Core Data emits. Total: ~400 lines, well-tested.

**Recommendation: (B), hand-rolled.** Reasons: we don't need every bplist edge case; we can write focused unit tests using the user's actual BLOBs as golden inputs; we don't add a third-party dep for what is essentially a well-understood binary format; security-sensitive code stays in our tree. Place at `lib/core/utils/bplist/bplist_decoder.dart`, with a `BPlistObject` tagged union as the output.

**`ZSAMPLES` content**: a bplist dictionary of arrays keyed by sensor type. Schema (observed):
```
{
  "times": [0, 10, 20, 30, ...],         // seconds from dive start
  "depths": [0.0, 14.5, 20.3, 27.4, ...], // feet or meters depending on MacDive settings
  "pressures": [3118.0, 3118.0, 3110.0, ...],
  "temperatures": [80.0, 80.0, 79.0, ...],
  "ppo2s": [0.0, 0.46, 0.51, ...],
  "ndts": [0, 99, 99, 99, ...],
  // optional: "ceilings", "tts", "heartrates", "gradientFactors"
}
```
(Exact key names to be confirmed against the first decoded sample; we'll write a test that decodes one known BLOB from the user's DB and asserts the structure.)

**`ZTIMEZONE` content**: a bplist dict representing an `NSTimeZone`, with a `name` key (e.g. `"America/Los_Angeles"`) and a `data` key (the zoneinfo blob). We only need `name` to interpret `ZRAWDATE` (which is a Core Data NSDate-as-seconds-since-2001-reference-date) into a correct local DateTime.

**`ZRAWDATE`**: Core Data stores NSDate as seconds-since-2001-01-01-UTC. Our reader converts by adding `DateTime.utc(2001, 1, 1)` as the epoch offset.

### Components

| File | Purpose |
|---|---|
| `lib/features/universal_import/data/models/import_enums.dart` | Add `ImportFormat.macdiveSqlite`, source override entry, `isSupported`. |
| `lib/features/universal_import/data/services/macdive_db_reader.dart` | **New**. Mirror of `ShearwaterDbReader`. Validates schema, executes JOIN queries, returns typed raw rows (`MacDiveRawDive`, `MacDiveRawSite`, etc.). |
| `lib/features/universal_import/data/services/macdive_dive_mapper.dart` | **New**. Maps `MacDiveRawDive` → dive map. Handles unit conversion, tank/gas joining, tag references, buddy joining. |
| `lib/features/universal_import/data/services/macdive_value_mapper.dart` | **New (shared with Milestone 2)**. Raw MacDive strings → Submersion enums. |
| `lib/core/utils/bplist/bplist_decoder.dart` | **New**. Binary plist v00 decoder. Covers: dict, array, string, int, real, bool, null, data, date, UID. |
| `lib/core/utils/bplist/bplist_object.dart` | **New**. `BPlistObject` tagged union / sealed class. |
| `lib/features/universal_import/data/parsers/macdive_sqlite_parser.dart` | **New**. `ImportParser` implementation: validates, reads, maps, emits `ImportPayload`. |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Wire `macdiveSqlite → MacDiveSqliteParser()` in `_parserFor`; add MacDive check in `_detectFormat`. |
| `test/core/utils/bplist/bplist_decoder_test.dart` | **New**. Golden-value tests against bplist samples decoded independently with `plutil`. |
| `test/features/universal_import/data/services/macdive_db_reader_test.dart` | **New**. Fixture-based; synthesize a 3-dive MacDive-shaped SQLite and roundtrip. |
| `test/features/universal_import/data/parsers/macdive_sqlite_parser_test.dart` | **New**. End-to-end on the synthetic fixture. |
| `test/fixtures/macdive_sqlite/` | **New**. Tiny synthetic DB + BLOB samples. |

### Data flow

```
SQLite file bytes
    → MacDiveDbReader (validates, reads raw rows, decodes BLOBs via BPlistDecoder)
    → MacDiveRawDive[], MacDiveRawSite[], MacDiveRawBuddy[], ...
    → MacDiveDiveMapper (unit-convert, join tanks↔gases↔dives, resolve buddy junctions)
    → ImportPayload
```

### Deduplication

Each ZUUID is stored on the imported entity as `sourceUuid` (same key Milestone 1 introduces). If a user imports the SQLite and later re-imports UDDF (or vice versa), the duplicate checker matches by `sourceUuid` *before* falling back to datetime+depth content matching, so re-imports are safe.

`ImportDuplicateChecker` gets a new field-level check: if two dives share a non-null `sourceUuid`, they are a definite match.

### Unit handling

MacDive stores raw values in the user's preferred unit system (set in MacDive's UI) — not a per-file declaration. `ZMETADATA` has a key `SystemOfUnits` we read once per import to determine conversion. Falls back to heuristic (if `ZMAXDEPTH` > 100 for most dives, assume feet) if the metadata is missing.

### Critters / marine life

MacDive critters map to Submersion's `sightings` concept (already imported from UDDF, see `uddf_full_import_service.dart:699-720`). We reuse that entity path.

### Events

`ZEVENT` has a type enum (integer) we have to decode from MacDive source. Document the mapping inline in `macdive_value_mapper.dart` (e.g., type 1 = gas switch, type 2 = bookmark, type 3 = deco stop violation — to be confirmed against MacDive source or field observation).

### Certifications

`ZCERTIFICATION.ZCARDFRONT` / `ZCARDBACK` are filesystem paths to images. Defer to Milestone 4 alongside photos.

### Testing

- Golden bplist decode tests against the user's actual BLOBs (redacted).
- Synthetic SQLite fixture: 3 dives, 2 sites, 2 buddies, 2 gas mixes, 2 tanks, all relationship joins populated.
- Integration test: run user's 6.7MB sample end-to-end and assert table counts match (`540 ZDIVE → 540 payload dives`, `373 ZDIVESITE → ~373 payload sites after site dedup`, etc.).

---

## Milestone 4 — Photo import

### Scope

Support importing dive photos referenced by MacDive in all three formats. Add the underlying "imported photo from local file path" architecture, which doesn't currently exist.

### What MacDive gives us

- **SQLite**: `ZDIVEIMAGE` rows with `ZPATH` (current filesystem path), `ZORIGINALPATH` (path at import time into MacDive), `ZCAPTION`, and `ZRELATIONSHIPDIVE` (FK to `ZDIVE`). 261 such rows in the sample.
- **Native XML**: `<photos><photo><path>/…</path><caption>…</caption></photo></photos>` per dive.
- **UDDF**: `<diveimage>` elements with `<imagereference>` containing paths. Not emitted by MacDive UDDF according to current observations; skip unless evidence appears.

### Architectural gap

Submersion's existing photo pipeline expects photos to be added via file picker or camera, then copied into app media storage (`<AppSupport>/media/dive/<dive-id>/…`). There is no concept of "link to external path" and the import wizard has no path-resolution step.

**Two sub-problems:**

1. **Resolving paths.** MacDive's paths are absolute to the user's home directory (`/Users/<user>/Pictures/Diving/…`). On macOS, the app has Documents/Pictures access via entitlement; on iOS/Android, there's no filesystem-wide access. This milestone is therefore **macOS/Windows/Linux only**; iOS/Android get a "photos not yet supported" warning.
2. **Missing source files.** Paths can rot — MacDive users may have moved/renamed their photo library since the dive was logged. We need a UI to let the user re-root the import (pick "this is my photos folder now") and we need to try multiple resolution strategies.

### Resolution strategy

For each image path in the import:

1. **Direct match** — try the absolute path as-is (works if MacDive DB is on the same machine).
2. **Rebase match** — if the user has picked a "photos root" in the wizard, replace the common prefix of the MacDive path with the user's root.
3. **Filename match** — if direct + rebase fail, scan the user's photos root for a file with the same basename.
4. **Miss** — record as a warning with the original path, let the user resolve manually later.

### New wizard step: "Link Photos"

Added to the universal import adapter's `acquisitionSteps` *only when the payload contains image references*. Shows:

- Count of image references (e.g. "261 photo references found")
- Folder picker: "Where are your photos?"
- Live counter: "259 found, 2 missing"
- Options: "Copy photos into Submersion" (default) / "Link in place" (macOS only, security-scoped bookmark) / "Skip photos"
- For missing: a collapsible list with filename and original path

Since MacDive UDDF doesn't emit photo references, the step won't appear for UDDF imports — keeping Milestone 1 independent.

### Components

| File | Purpose |
|---|---|
| `lib/features/universal_import/data/models/import_payload.dart` | Add `imageRefs` entity type or a top-level `List<ImportImageRef>` field. |
| `lib/features/universal_import/data/models/import_image_ref.dart` | **New**. `{originalPath, caption, diveSourceUuid, optional position}`. |
| `lib/features/universal_import/data/services/photo_resolver.dart` | **New**. Takes `List<ImportImageRef>` + optional user-picked root, returns `List<ResolvedPhoto>` with file bytes or miss info. |
| `lib/features/universal_import/data/services/macdive_db_reader.dart` | Extended to read `ZDIVEIMAGE` rows. |
| `lib/features/universal_import/data/services/macdive_xml_reader.dart` | Extended to read `<photos>` elements. |
| `lib/features/universal_import/presentation/widgets/photo_linking_step.dart` | **New** wizard step widget. |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | Conditionally inject the photo-linking step when payload has image refs. |
| `lib/features/dive_log/data/services/imported_photo_storage.dart` | **New or extended**. Copies resolved photos into app media storage; handles collision naming. |
| `lib/features/dive_log/data/services/dive_photo_repository.dart` | Extended to accept "linked in place" path entries, if we support that mode. |
| `test/features/universal_import/data/services/photo_resolver_test.dart` | **New**. Path rebase, filename fallback, missing handling. |
| `test/features/universal_import/presentation/widgets/photo_linking_step_test.dart` | **New**. Widget tests. |

### Platform handling

- **macOS/Windows/Linux**: Full support. Use `file_picker` for folder selection; read bytes directly; copy into app storage.
- **iOS/Android**: The step appears but shows a "Photo import not supported on mobile" message with instructions to do the import from desktop.

### Testing

- Photo resolver unit tests with fake filesystem (using `file` package's `MemoryFileSystem`).
- End-to-end: import Milestone 3's synthetic SQLite + fake image files, verify photos land in app media storage linked to the right dive.

---

## Cross-cutting concerns

### Shared test fixtures

Create `test/fixtures/macdive/` with:
- `small.uddf` — hand-authored 3-dive UDDF exercising MacDive quirks.
- `small.xml` — hand-authored 3-dive native XML.
- `small.sqlite` — synthetic MacDive-schema DB built at test time (not checked in, generated by a `buildSyntheticMacDiveDb()` helper).
- `bplist_samples/` — redacted BLOBs pulled from the user's real DB.

The user's real files (29MB, 30MB, 6.7MB) stay in the ignored `submersion data/` folder and are run against as integration tests gated behind a `--tags=real-data` flag so CI isn't paying for them.

### Deduplication across formats

All milestones write `sourceUuid` on every imported entity (dive, site, buddy, gear, tag, cert, critter, tank, gas). `ImportDuplicateChecker` gains a first-pass UUID match before the fuzzy content match. This lets users import SQLite, then re-import UDDF, without duplicates.

Schema migration (Milestone 1 touches this first): add `source_uuid TEXT NULL` to: `dives`, `dive_sites`, `buddies`, `gear`, `tags`, `certifications`, `species` (for critters), `tanks`, `gas_mixes`, `trips`. Nullable because older imports won't have one.

### Error handling philosophy

- **Unrecoverable**: surfaced as `ImportWarning(severity: error)` that stops the per-entity import but not the batch. User sees the count of failures in the summary.
- **Recoverable / soft**: `ImportWarning(severity: warning)` with the specific field/value; entity is imported with the field set to null.
- **Info**: `ImportWarning(severity: info)` for things like "this MacDive field has no Submersion equivalent" — non-alarming.

### Rollout sequence

| Milestone | PR | Approx effort | Closes |
|---|---|---|---|
| 1 — UDDF gap-fill | #M1 | 1 week | #178 (partial), Josh's gear/gas switch complaints |
| 2 — MacDive XML | #M2 | 1 week | #178 (fully), glazerama's tag complaint |
| 3 — MacDive SQLite | #M3 | 2 weeks | #179 |
| 4 — Photo import | #M4 | 1 week | (new scope, no ticket yet) |

Total: ~5 weeks.

Each milestone ships independently; a user running any milestone's build gets the improvement it delivers. Milestone 2 benefits from Milestone 1's `sourceUuid` plumbing but doesn't require it.

## Open questions

- **bplist approach.** Hand-roll vs. library. Design leans toward hand-rolled; confirm before starting Milestone 3.
- **Event type mapping.** MacDive's `ZEVENT.ZTYPE` integer codes aren't publicly documented. Plan: decode a handful by observation, document inline, treat unknowns as "other".
- **MacDive UDDF equipment UUID(`null`) manufacturer refs.** Some items have `man-(null)` IDs — decide whether to import as "Unknown manufacturer" or skip. Lean toward import with manufacturer=null.
- **Units metadata in SQLite.** We need to confirm `ZMETADATA` holds the units preference; if it doesn't, the heuristic fallback kicks in.

## Appendix: files verified against for design

- `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad sync.uddf` (29 MB, 540 dives)
- `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad Mini sync.xml` (30 MB, schema 2.2.0)
- `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite` (6.7 MB, MacDive 2.16.3)
- ScubaBoard thread 667061, pages 1, 2, 25, 29, 30, 31, 35
- GitHub issues #28 (closed), #42 (PR, merged), #78, #178, #179
