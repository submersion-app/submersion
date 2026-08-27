# MacDive Native XML Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add MacDive's native XML format (DOCTYPE `macdive_logbook.dtd`, root `<dives>`) as a first-class import source in the unified import wizard. This is the only MacDive export that carries dive tags.

**Architecture:** New `ImportFormat.macdiveXml` enum value; new detector branch in `FormatDetector`; new typed reader (`MacDiveXmlReader`) that produces Dart objects from the XML; shared value mapper (`MacDiveValueMapper`) for enum strings; new parser (`MacDiveXmlParser`) that implements `ImportParser` and produces an `ImportPayload`. All plugs into the existing wizard, duplicate checker, and importer.

**Tech Stack:** Flutter, Dart 3, `xml` package, Riverpod, `flutter_test`.

**Dependencies:** Milestone 1 (UDDF gap-fill) must be merged first; this milestone relies on `sourceUuid` columns and the `IncomingDiveData` fields added there.

**Sample data:** `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad Mini sync.xml` (30 MB, schema 2.2.0).

---

## Milestone 2 Status — COMPLETE

- All 11 tasks landed. 10 implementation commits + 1 commit that cherry-picked
  the MacDiveValueMapper onto this branch after it originally landed on main
  by mistake.
- New `ImportFormat.macdiveXml` with source override and format-detector
  recognition (DOCTYPE + `<dives>`/`<schema>` fallback).
- `MacDiveXmlReader` produces typed `MacDiveXmlLogbook` from XML with SI
  canonical units at the boundary. Imperial↔Metric verified via an explicit
  imperial fixture.
- `MacDiveXmlParser` implements `ImportParser`, dedups sites/buddies/tags/gear
  inline, routes raw MacDive strings through `MacDiveValueMapper` so
  `waterType`/`entryType` resolve to Submersion enums.
- Gated real-sample test (`@Tags(['real-data'])`) asserts 540 dives, tag
  preservation (20+ unique tags), site dedup, unit-conversion sanity.
- Full test suite passes (7000+ tests).

Next: M3 (MacDive SQLite) builds on top of this. Key shared assets —
`MacDiveValueMapper`, `MacDiveUnitConverter` — are reused by M3's SQLite
parser.

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/features/universal_import/data/models/import_enums.dart` | Add `ImportFormat.macdiveXml`, add to `isSupported`, add `SourceOverrideOption` entry. | Modified |
| `lib/features/universal_import/data/services/format_detector.dart` | New branch matching `<!DOCTYPE dives` or `<dives>` + `<schema>`. | Modified |
| `lib/features/universal_import/data/services/macdive_xml_reader.dart` | Parses `<dives>` root into typed Dart objects. Handles imperial↔metric conversion at the boundary. | Created |
| `lib/features/universal_import/data/services/macdive_xml_models.dart` | Typed value classes: `MacDiveXmlLogbook`, `MacDiveXmlDive`, `MacDiveXmlSite`, `MacDiveXmlGas`, `MacDiveXmlTank`, `MacDiveXmlGearItem`, `MacDiveXmlSample`. | Created |
| `lib/features/universal_import/data/services/macdive_value_mapper.dart` | Static mappings from MacDive raw strings to Submersion enums (water type, entry type, weather, dive type). Shared with Milestone 3. | Created |
| `lib/features/universal_import/data/parsers/macdive_xml_parser.dart` | Implements `ImportParser`. Orchestrates reader + mapper → `ImportPayload`. | Created |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Wire `macdiveXml → MacDiveXmlParser()` in `_parserFor`. | Modified |
| `test/features/universal_import/data/services/macdive_xml_reader_test.dart` | Unit tests for the reader: units, tags, missing fields, multi-dive. | Created |
| `test/features/universal_import/data/services/macdive_value_mapper_test.dart` | Unit tests for enum mapping. | Created |
| `test/features/universal_import/data/parsers/macdive_xml_parser_test.dart` | End-to-end parser tests with hand-authored XML fixtures. | Created |
| `test/features/universal_import/data/services/format_detector_test.dart` | Extend with positive and negative detection cases for MacDive XML. | Modified |
| `test/fixtures/macdive_xml/metric_small.xml` | 3-dive metric fixture. | Created |
| `test/fixtures/macdive_xml/imperial_small.xml` | 3-dive imperial fixture. | Created |
| `test/fixtures/macdive_xml/tags_and_critters.xml` | Fixture with tags, buddies, gear, gases. | Created |

---

## Task 1: Add `ImportFormat.macdiveXml` and source override

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/universal_import/data/models/import_enums_test.dart` (create if absent):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  test('ImportFormat.macdiveXml is supported and has display name', () {
    expect(ImportFormat.macdiveXml.displayName, 'MacDive XML');
    expect(ImportFormat.macdiveXml.isSupported, isTrue);
  });

  test('SourceOverrideOption includes MacDive (XML) entry', () {
    final matches = SourceOverrideOption.supported.where(
      (o) => o.sourceApp == SourceApp.macdive && o.format == ImportFormat.macdiveXml,
    );
    expect(matches.length, 1);
    expect(matches.first.displayName, 'MacDive (XML)');
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/universal_import/data/models/import_enums_test.dart`
Expected: FAIL — `macdiveXml not defined`.

- [ ] **Step 3: Modify the enum**

In `lib/features/universal_import/data/models/import_enums.dart`:

```dart
enum ImportFormat {
  csv,
  uddf,
  macdiveXml,               // <-- NEW
  subsurfaceXml,
  divingLogXml,
  suuntoSml,
  suuntoDm5,
  fit,
  shearwaterDb,
  scubapro,
  danDl7,
  sqlite,
  unknown;
```

Add to `displayName`:
```dart
    macdiveXml => 'MacDive XML',
```

Add to `isSupported`:
```dart
  bool get isSupported => switch (this) {
    csv || uddf || subsurfaceXml || fit || shearwaterDb || macdiveXml => true,
    _ => false,
  };
```

Add to `SourceOverrideOption.supported` (immediately after the existing MacDive CSV entry):

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.macdive,
      format: ImportFormat.macdiveXml,
      displayName: 'MacDive (XML)',
    ),
```

- [ ] **Step 4: Run — expect PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/models/import_enums.dart test/features/universal_import/data/models/import_enums_test.dart
git commit -m "feat(import): add ImportFormat.macdiveXml + source override"
```

---

## Task 2: Format detector recognizes MacDive XML

**Files:**
- Modify: `lib/features/universal_import/data/services/format_detector.dart`
- Modify: `test/features/universal_import/data/services/format_detector_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to the XML detection group in `format_detector_test.dart`:

```dart
test('detects MacDive XML via DOCTYPE', () {
  const xml = '''<?xml version="1.0"?>
<!DOCTYPE dives SYSTEM "http://www.mac-dive.com/macdive_logbook.dtd">
<dives><schema>2.2.0</schema><dive/></dives>''';
  final result = const FormatDetector().detect(Uint8List.fromList(utf8.encode(xml)));
  expect(result.format, ImportFormat.macdiveXml);
  expect(result.sourceApp, SourceApp.macdive);
  expect(result.confidence, greaterThanOrEqualTo(0.9));
});

test('detects MacDive XML via root+schema when DOCTYPE missing', () {
  const xml = '<?xml version="1.0"?><dives><schema>2.2.0</schema><dive/></dives>';
  final result = const FormatDetector().detect(Uint8List.fromList(utf8.encode(xml)));
  expect(result.format, ImportFormat.macdiveXml);
});

test('does not match plain UDDF as MacDive XML', () {
  const xml = '<?xml version="1.0"?><uddf><profiledata/></uddf>';
  final result = const FormatDetector().detect(Uint8List.fromList(utf8.encode(xml)));
  expect(result.format, ImportFormat.uddf);
});
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/universal_import/data/services/format_detector_test.dart --plain-name "MacDive XML"`
Expected: FAIL.

- [ ] **Step 3: Add the detection branch**

In `lib/features/universal_import/data/services/format_detector.dart`, inside `_detectXml`, *before* the generic UDDF branch:

```dart
    // MacDive native XML: root <dives>, DOCTYPE macdive_logbook.dtd, <schema>.
    if (lower.contains('mac-dive.com/macdive_logbook.dtd') ||
        (lower.contains('<dives>') && lower.contains('<schema>'))) {
      return const DetectionResult(
        format: ImportFormat.macdiveXml,
        sourceApp: SourceApp.macdive,
        confidence: 0.95,
      );
    }
```

- [ ] **Step 4: Run — expect PASS**

Expected: PASS for all three tests.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): detect MacDive native XML format"
```

---

## Task 3: Typed value classes

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_xml_models.dart`

- [ ] **Step 1: Define the models**

```dart
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

/// Unit system declared at the top of a MacDive XML document.
enum MacDiveUnitSystem {
  imperial,   // feet, °F, psi, lb
  metric,     // meters, °C, bar, kg
  unknown;

  static MacDiveUnitSystem fromXml(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'imperial': return MacDiveUnitSystem.imperial;
      case 'metric': return MacDiveUnitSystem.metric;
      default: return MacDiveUnitSystem.unknown;
    }
  }
}

class MacDiveXmlLogbook {
  final MacDiveUnitSystem units;
  final String? schemaVersion;
  final List<MacDiveXmlDive> dives;

  const MacDiveXmlLogbook({
    required this.units,
    required this.schemaVersion,
    required this.dives,
  });
}

class MacDiveXmlDive {
  /// Stable MacDive identifier, e.g. "20260311140918-CB115EF0".
  final String? identifier;
  final DateTime? date;
  final int? diveNumber;
  final int? repetitiveDive;
  final double? rating;           // 0.0 – 5.0
  final double? maxDepthMeters;
  final double? avgDepthMeters;
  final double? cns;
  final String? decoModel;
  final Duration? duration;
  final Duration? surfaceInterval;
  final Duration? sampleInterval;
  final String? gasModel;
  final double? airTempCelsius;
  final double? tempHighCelsius;
  final double? tempLowCelsius;
  final String? visibility;
  final double? weightKg;
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

  const MacDiveXmlDive({
    this.identifier,
    this.date,
    this.diveNumber,
    this.repetitiveDive,
    this.rating,
    this.maxDepthMeters,
    this.avgDepthMeters,
    this.cns,
    this.decoModel,
    this.duration,
    this.surfaceInterval,
    this.sampleInterval,
    this.gasModel,
    this.airTempCelsius,
    this.tempHighCelsius,
    this.tempLowCelsius,
    this.visibility,
    this.weightKg,
    this.notes,
    this.diveMaster,
    this.diveOperator,
    this.skipper,
    this.boat,
    this.weather,
    this.current,
    this.surfaceConditions,
    this.entryType,
    this.computer,
    this.serial,
    this.diver,
    this.site,
    this.tags = const [],
    this.diveTypes = const [],
    this.buddies = const [],
    this.gear = const [],
    this.gases = const [],
    this.samples = const [],
  });
}

class MacDiveXmlSite {
  final String? name;
  final String? country;
  final String? location;
  final String? bodyOfWater;
  final String? waterType;
  final String? difficulty;
  final double? altitudeMeters;
  final double? latitude;   // null if MacDive wrote 0.0 / 0.0 (means "not set")
  final double? longitude;

  const MacDiveXmlSite({
    this.name,
    this.country,
    this.location,
    this.bodyOfWater,
    this.waterType,
    this.difficulty,
    this.altitudeMeters,
    this.latitude,
    this.longitude,
  });
}

class MacDiveXmlGearItem {
  final String? type;
  final String? manufacturer;
  final String? name;
  final String? serial;

  const MacDiveXmlGearItem({this.type, this.manufacturer, this.name, this.serial});
}

class MacDiveXmlGas {
  final double? pressureStartBar;
  final double? pressureEndBar;
  final double? oxygenPercent;
  final double? heliumPercent;
  final bool? doubleTank;
  final double? tankSizeLiters;
  final double? workingPressureBar;
  final String? supplyType;
  final Duration? duration;
  final String? tankName;

  const MacDiveXmlGas({
    this.pressureStartBar,
    this.pressureEndBar,
    this.oxygenPercent,
    this.heliumPercent,
    this.doubleTank,
    this.tankSizeLiters,
    this.workingPressureBar,
    this.supplyType,
    this.duration,
    this.tankName,
  });
}

class MacDiveXmlSample {
  final Duration time;
  final double? depthMeters;
  final double? pressureBar;
  final double? temperatureCelsius;
  final double? ppO2;
  final int? ndtSeconds;

  const MacDiveXmlSample({
    required this.time,
    this.depthMeters,
    this.pressureBar,
    this.temperatureCelsius,
    this.ppO2,
    this.ndtSeconds,
  });
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/features/universal_import/data/services/macdive_xml_models.dart`
Expected: clean (or only unused-import warning if the mapper import is stubbed).

If the `macdive_value_mapper.dart` import is red, delete it for now — we'll add it back in Task 4.

- [ ] **Step 3: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_xml_models.dart
git commit -m "feat(import): add MacDive XML typed value classes"
```

---

## Task 4: `MacDiveValueMapper` — raw strings to Submersion enums

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_value_mapper.dart`
- Create: `test/features/universal_import/data/services/macdive_value_mapper_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

void main() {
  group('MacDiveValueMapper.waterType', () {
    test('maps saltwater strings', () {
      expect(MacDiveValueMapper.waterType('saltwater'), WaterType.salt);
      expect(MacDiveValueMapper.waterType('Salt'), WaterType.salt);
      expect(MacDiveValueMapper.waterType('sea'), WaterType.salt);
    });
    test('maps freshwater strings', () {
      expect(MacDiveValueMapper.waterType('freshwater'), WaterType.fresh);
      expect(MacDiveValueMapper.waterType('fresh'), WaterType.fresh);
      expect(MacDiveValueMapper.waterType('lake'), WaterType.fresh);
    });
    test('returns null for unknown', () {
      expect(MacDiveValueMapper.waterType('brackish'), isNull);
      expect(MacDiveValueMapper.waterType(null), isNull);
      expect(MacDiveValueMapper.waterType(''), isNull);
    });
  });

  group('MacDiveValueMapper.entryType', () {
    test('maps boat', () {
      expect(MacDiveValueMapper.entryType('boat'), EntryMethod.boat);
      expect(MacDiveValueMapper.entryType('Boat'), EntryMethod.boat);
    });
    test('maps shore', () {
      expect(MacDiveValueMapper.entryType('shore'), EntryMethod.shore);
      expect(MacDiveValueMapper.entryType('beach'), EntryMethod.shore);
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Expected: FAIL — `MacDiveValueMapper not defined`.

- [ ] **Step 3: Implement the mapper**

```dart
import 'package:submersion/core/constants/enums.dart';

/// Static mappings from MacDive's raw string values to Submersion domain
/// enums. Used by both the MacDive XML parser (Milestone 2) and the MacDive
/// SQLite parser (Milestone 3).
class MacDiveValueMapper {
  const MacDiveValueMapper._();

  /// Maps MacDive water-type strings. Returns null for unknown or empty input.
  static WaterType? waterType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.contains('salt') || s == 'sea' || s == 'ocean') return WaterType.salt;
    if (s.contains('fresh') || s == 'lake' || s == 'river' || s == 'quarry') {
      return WaterType.fresh;
    }
    return null;
  }

  static EntryMethod? entryType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.contains('boat') || s.contains('liveaboard')) return EntryMethod.boat;
    if (s.contains('shore') || s.contains('beach')) return EntryMethod.shore;
    if (s.contains('pool')) return EntryMethod.shore; // closest match
    return null;
  }

  /// Maps MacDive dive-type strings (e.g. "Recreational", "Training",
  /// "Night") to Submersion dive-type names. Unknown values pass through
  /// as a literal tag name so the importer can create it on demand.
  static String normalizeDiveType(String raw) => raw.trim();

  /// Maps a MacDive rating (0.0-5.0) to the Submersion rating scale (0-5).
  static int? rating(double? raw) {
    if (raw == null) return null;
    final clamped = raw.clamp(0.0, 5.0);
    return clamped.round();
  }
}
```

(Adjust `WaterType`, `EntryMethod` imports to match the exact names used in `lib/core/constants/enums.dart` — verify with `grep -n "enum WaterType" lib/core/constants/enums.dart`.)

- [ ] **Step 4: Run — expect PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_value_mapper.dart test/features/universal_import/data/services/macdive_value_mapper_test.dart
git commit -m "feat(import): MacDive value mapper for water type / entry type / rating"
```

---

## Task 5: Unit-conversion helper

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_unit_converter.dart`
- Create: `test/features/universal_import/data/services/macdive_unit_converter_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

void main() {
  final metric = MacDiveUnitConverter(MacDiveUnitSystem.metric);
  final imperial = MacDiveUnitConverter(MacDiveUnitSystem.imperial);

  group('depth', () {
    test('metric passes through', () {
      expect(metric.depthToMeters(20.0), 20.0);
    });
    test('imperial converts feet → meters', () {
      expect(imperial.depthToMeters(100.0), closeTo(30.48, 0.01));
    });
    test('null passes through', () {
      expect(imperial.depthToMeters(null), isNull);
    });
  });

  group('temperature', () {
    test('imperial F → C', () {
      expect(imperial.tempToCelsius(80.0), closeTo(26.67, 0.01));
    });
    test('metric passes through', () {
      expect(metric.tempToCelsius(25.0), 25.0);
    });
  });

  group('pressure', () {
    test('imperial psi → bar', () {
      expect(imperial.pressureToBar(3000.0), closeTo(206.84, 0.1));
    });
    test('metric passes through', () {
      expect(metric.pressureToBar(200.0), 200.0);
    });
  });

  group('weight', () {
    test('imperial lb → kg', () {
      expect(imperial.weightToKg(10.0), closeTo(4.536, 0.01));
    });
    test('metric passes through', () {
      expect(metric.weightToKg(5.0), 5.0);
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

/// Converts MacDive-raw numeric values (in the document's unit system) to
/// Submersion's canonical units: meters, Celsius, bar, kilograms.
class MacDiveUnitConverter {
  final MacDiveUnitSystem units;
  const MacDiveUnitConverter(this.units);

  bool get _isImperial => units == MacDiveUnitSystem.imperial;

  double? depthToMeters(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.3048 : raw;
  }

  double? tempToCelsius(double? raw) {
    if (raw == null) return null;
    return _isImperial ? (raw - 32.0) * 5.0 / 9.0 : raw;
  }

  double? pressureToBar(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.0689476 : raw;
  }

  double? weightToKg(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.453592 : raw;
  }

  /// Tank size: MacDive imperial expresses in cubic feet @ working pressure.
  /// This is not a simple scalar — conversion depends on working pressure.
  /// Callers should use [tankSizeLiters] which takes both values.
  double? tankSizeLiters(double? rawSize, double? rawWorkingPressure) {
    if (rawSize == null) return null;
    if (!_isImperial) return rawSize;
    if (rawWorkingPressure == null || rawWorkingPressure <= 0) return null;
    // Liters = (cft * 28.3168) / (workingPressureBar * some conversion).
    // For the common imperial case (e.g. AL80 = 77.4 cft @ 3000 psi = 11.1 L):
    //   litresAtSurface = cft * 28.3168
    //   waterCapacity   = litresAtSurface / (workingPressurePsi / 14.5038)
    final litresAtSurface = rawSize * 28.3168;
    final workingPressureBar = rawWorkingPressure * 0.0689476;
    return litresAtSurface / workingPressureBar;
  }
}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): MacDive unit converter (imperial ↔ metric)"
```

---

## Task 6: `MacDiveXmlReader` — parse XML to typed objects

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_xml_reader.dart`
- Create: `test/features/universal_import/data/services/macdive_xml_reader_test.dart`
- Create: `test/fixtures/macdive_xml/metric_small.xml`

- [ ] **Step 1: Create the metric fixture**

File: `test/fixtures/macdive_xml/metric_small.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dives SYSTEM "http://www.mac-dive.com/macdive_logbook.dtd">
<dives>
    <units>Metric</units>
    <schema>2.2.0</schema>
    <dive>
        <date>2024-06-01 09:00:00</date>
        <identifier>20240601090000-ABC123</identifier>
        <diveNumber>42</diveNumber>
        <rating>4</rating>
        <maxDepth>25.40</maxDepth>
        <averageDepth>18.00</averageDepth>
        <duration>2400</duration>
        <sampleInterval>10</sampleInterval>
        <tempHigh>26.5</tempHigh>
        <tempLow>20.0</tempLow>
        <weight>5</weight>
        <notes><![CDATA[Nice reef dive]]></notes>
        <diveOperator>Test Operator</diveOperator>
        <boat>MV Test</boat>
        <weather>Sunny</weather>
        <site>
            <country>Mexico</country>
            <location>Baja California</location>
            <name>Test Reef</name>
            <waterType>saltwater</waterType>
            <lat>24.12345</lat>
            <lon>-110.54321</lon>
        </site>
        <tags>
            <tag>Reef</tag>
            <tag>Photography</tag>
        </tags>
        <buddies>
            <buddy>Alice</buddy>
        </buddies>
        <gear>
            <item><type>BCD</type><manufacturer>Test</manufacturer><name>BCD1</name></item>
        </gear>
        <gases>
            <gas>
                <pressureStart>200</pressureStart>
                <pressureEnd>60</pressureEnd>
                <oxygen>32</oxygen>
                <helium>0</helium>
                <double>0</double>
                <tankSize>12</tankSize>
                <workingPressure>232</workingPressure>
                <supplyType>Open Circuit</supplyType>
                <duration>2400</duration>
                <tankName>AL80</tankName>
            </gas>
        </gases>
        <samples>
            <sample><time>0</time><depth>0</depth><pressure>200</pressure><temperature>26.5</temperature></sample>
            <sample><time>60</time><depth>10</depth><pressure>195</pressure><temperature>24</temperature></sample>
            <sample><time>2400</time><depth>5</depth><pressure>60</pressure><temperature>23</temperature></sample>
        </samples>
    </dive>
</dives>
```

- [ ] **Step 2: Write failing tests**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_reader.dart';

void main() {
  group('MacDiveXmlReader', () {
    test('parses metric fixture dive count and units', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final logbook = MacDiveXmlReader.parse(content);
      expect(logbook.units, MacDiveUnitSystem.metric);
      expect(logbook.schemaVersion, '2.2.0');
      expect(logbook.dives.length, 1);
    });

    test('parses dive identifier and date', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.identifier, '20240601090000-ABC123');
      expect(dive.date, DateTime(2024, 6, 1, 9, 0, 0));
      expect(dive.diveNumber, 42);
    });

    test('parses depths and temps in canonical units (already metric)', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.maxDepthMeters, 25.4);
      expect(dive.avgDepthMeters, 18.0);
      expect(dive.tempHighCelsius, 26.5);
      expect(dive.tempLowCelsius, 20.0);
      expect(dive.weightKg, 5.0);
    });

    test('parses tags', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.tags, ['Reef', 'Photography']);
    });

    test('parses site with lat/lon', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.site?.name, 'Test Reef');
      expect(dive.site?.country, 'Mexico');
      expect(dive.site?.latitude, closeTo(24.12345, 0.00001));
      expect(dive.site?.longitude, closeTo(-110.54321, 0.00001));
      expect(dive.site?.waterType, 'saltwater');
    });

    test('treats lat=0 lon=0 as no-GPS', () {
      const xml = '''<?xml version="1.0"?>
<dives><units>Metric</units><schema>2.2.0</schema>
  <dive><date>2024-01-01 00:00:00</date>
    <site><lat>0</lat><lon>0</lon><name>X</name></site>
    <samples/></dive></dives>''';
      final dive = MacDiveXmlReader.parse(xml).dives.first;
      expect(dive.site?.latitude, isNull);
      expect(dive.site?.longitude, isNull);
    });

    test('parses gases with pressures, O2 percent, supply type', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.gases.length, 1);
      expect(dive.gases.first.pressureStartBar, 200);
      expect(dive.gases.first.pressureEndBar, 60);
      expect(dive.gases.first.oxygenPercent, 32);
      expect(dive.gases.first.supplyType, 'Open Circuit');
    });

    test('parses samples with time as Duration', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final dive = MacDiveXmlReader.parse(content).dives.first;
      expect(dive.samples.length, 3);
      expect(dive.samples.first.time, Duration.zero);
      expect(dive.samples[1].time, const Duration(seconds: 60));
      expect(dive.samples.last.time, const Duration(seconds: 2400));
    });
  });
}
```

- [ ] **Step 3: Run — expect FAIL**

Expected: FAIL — `MacDiveXmlReader not defined`.

- [ ] **Step 4: Implement the reader**

```dart
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

/// Parses a MacDive native XML document into typed value objects.
/// All numeric values are normalized to Submersion canonical units
/// (meters, Celsius, bar, kilograms) at the reader boundary.
class MacDiveXmlReader {
  const MacDiveXmlReader._();

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  static MacDiveXmlLogbook parse(String content) {
    final doc = XmlDocument.parse(content);
    final root = doc.rootElement;
    final units = MacDiveUnitSystem.fromXml(
      root.findElements('units').firstOrNull?.innerText,
    );
    final converter = MacDiveUnitConverter(units);
    final schemaVersion = root.findElements('schema').firstOrNull?.innerText;

    final dives = root.findElements('dive').map((e) => _parseDive(e, converter)).toList();

    return MacDiveXmlLogbook(
      units: units,
      schemaVersion: schemaVersion,
      dives: dives,
    );
  }

  static MacDiveXmlDive _parseDive(XmlElement el, MacDiveUnitConverter c) {
    String? text(String name) {
      final s = el.findElements(name).firstOrNull?.innerText.trim();
      return (s == null || s.isEmpty) ? null : s;
    }
    double? dbl(String name) => double.tryParse(text(name) ?? '');
    int? integer(String name) => int.tryParse(text(name) ?? '');

    return MacDiveXmlDive(
      identifier: text('identifier'),
      date: _parseDate(text('date')),
      diveNumber: integer('diveNumber'),
      repetitiveDive: integer('repetitiveDive'),
      rating: dbl('rating'),
      maxDepthMeters: c.depthToMeters(dbl('maxDepth')),
      avgDepthMeters: c.depthToMeters(dbl('averageDepth')),
      cns: dbl('cns'),
      decoModel: text('decoModel'),
      duration: _secs(integer('duration')),
      surfaceInterval: _secs(integer('surfaceInterval') == null ? null : integer('surfaceInterval')! * 60),
      sampleInterval: _secs(integer('sampleInterval')),
      gasModel: text('gasModel'),
      airTempCelsius: c.tempToCelsius(dbl('tempAir')),
      tempHighCelsius: c.tempToCelsius(dbl('tempHigh')),
      tempLowCelsius: c.tempToCelsius(dbl('tempLow')),
      visibility: text('visibility'),
      weightKg: c.weightToKg(dbl('weight')),
      notes: text('notes'),
      diveMaster: text('diveMaster'),
      diveOperator: text('diveOperator'),
      skipper: text('skipper'),
      boat: text('boat'),
      weather: text('weather'),
      current: text('current'),
      surfaceConditions: text('surfaceConditions'),
      entryType: text('entryType'),
      computer: text('computer'),
      serial: text('serial'),
      diver: text('diver'),
      site: _parseSite(el.findElements('site').firstOrNull, c),
      tags: _parseList(el, 'tags', 'tag'),
      diveTypes: _parseList(el, 'types', 'type'),
      buddies: _parseList(el, 'buddies', 'buddy'),
      gear: _parseGear(el),
      gases: _parseGases(el, c),
      samples: _parseSamples(el, c),
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return _dateFmt.parseStrict(raw);
    } catch (_) {
      // Fall back to ISO-ish parsing.
      return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    }
  }

  static Duration? _secs(int? s) => s == null ? null : Duration(seconds: s);

  static MacDiveXmlSite? _parseSite(XmlElement? el, MacDiveUnitConverter c) {
    if (el == null) return null;
    String? text(String name) {
      final s = el.findElements(name).firstOrNull?.innerText.trim();
      return (s == null || s.isEmpty) ? null : s;
    }
    double? dbl(String name) => double.tryParse(text(name) ?? '');
    final lat = dbl('lat');
    final lon = dbl('lon');
    // MacDive writes 0.0/0.0 for "no GPS set" — treat as missing.
    final hasGps = lat != null && lon != null && !(lat == 0.0 && lon == 0.0);
    return MacDiveXmlSite(
      name: text('name'),
      country: text('country'),
      location: text('location'),
      bodyOfWater: text('bodyOfWater'),
      waterType: text('waterType'),
      difficulty: text('difficulty'),
      altitudeMeters: c.depthToMeters(dbl('altitude')),
      latitude: hasGps ? lat : null,
      longitude: hasGps ? lon : null,
    );
  }

  static List<String> _parseList(XmlElement dive, String group, String item) {
    final g = dive.findElements(group).firstOrNull;
    if (g == null) return const [];
    return g.findElements(item)
        .map((e) => e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<MacDiveXmlGearItem> _parseGear(XmlElement dive) {
    final g = dive.findElements('gear').firstOrNull;
    if (g == null) return const [];
    return g.findElements('item').map((it) {
      String? text(String n) {
        final s = it.findElements(n).firstOrNull?.innerText.trim();
        return (s == null || s.isEmpty) ? null : s;
      }
      return MacDiveXmlGearItem(
        type: text('type'),
        manufacturer: text('manufacturer'),
        name: text('name'),
        serial: text('serial'),
      );
    }).toList();
  }

  static List<MacDiveXmlGas> _parseGases(XmlElement dive, MacDiveUnitConverter c) {
    final g = dive.findElements('gases').firstOrNull;
    if (g == null) return const [];
    return g.findElements('gas').map((gas) {
      String? text(String n) {
        final s = gas.findElements(n).firstOrNull?.innerText.trim();
        return (s == null || s.isEmpty) ? null : s;
      }
      double? dbl(String n) => double.tryParse(text(n) ?? '');
      int? integer(String n) => int.tryParse(text(n) ?? '');
      return MacDiveXmlGas(
        pressureStartBar: c.pressureToBar(dbl('pressureStart')),
        pressureEndBar: c.pressureToBar(dbl('pressureEnd')),
        oxygenPercent: dbl('oxygen'),
        heliumPercent: dbl('helium'),
        doubleTank: (integer('double') ?? 0) != 0,
        tankSizeLiters: c.tankSizeLiters(dbl('tankSize'), dbl('workingPressure')),
        workingPressureBar: c.pressureToBar(dbl('workingPressure')),
        supplyType: text('supplyType'),
        duration: _secs(integer('duration')),
        tankName: text('tankName'),
      );
    }).toList();
  }

  static List<MacDiveXmlSample> _parseSamples(XmlElement dive, MacDiveUnitConverter c) {
    final g = dive.findElements('samples').firstOrNull;
    if (g == null) return const [];
    return g.findElements('sample').map((s) {
      String? text(String n) {
        final v = s.findElements(n).firstOrNull?.innerText.trim();
        return (v == null || v.isEmpty) ? null : v;
      }
      double? dbl(String n) => double.tryParse(text(n) ?? '');
      int? integer(String n) => int.tryParse(text(n) ?? '');
      return MacDiveXmlSample(
        time: Duration(seconds: integer('time') ?? 0),
        depthMeters: c.depthToMeters(dbl('depth')),
        pressureBar: c.pressureToBar(dbl('pressure')),
        temperatureCelsius: c.tempToCelsius(dbl('temperature')),
        ppO2: dbl('ppo2'),
        ndtSeconds: integer('ndt') == null ? null : integer('ndt')! * 60,
      );
    }).toList();
  }
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/features/universal_import/data/services/macdive_xml_reader_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git commit -am "feat(import): MacDive XML reader with typed output"
```

---

## Task 7: Imperial fixture + imperial tests

**Files:**
- Create: `test/fixtures/macdive_xml/imperial_small.xml`
- Modify: `test/features/universal_import/data/services/macdive_xml_reader_test.dart`

- [ ] **Step 1: Create imperial fixture**

File: `test/fixtures/macdive_xml/imperial_small.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dives SYSTEM "http://www.mac-dive.com/macdive_logbook.dtd">
<dives>
    <units>Imperial</units>
    <schema>2.2.0</schema>
    <dive>
        <date>2024-06-01 09:00:00</date>
        <identifier>20240601090000-IMP</identifier>
        <maxDepth>100</maxDepth>
        <averageDepth>60</averageDepth>
        <duration>2400</duration>
        <tempHigh>80</tempHigh>
        <tempLow>70</tempLow>
        <weight>10</weight>
        <samples>
            <sample><time>0</time><depth>0</depth><pressure>3000</pressure><temperature>80</temperature></sample>
            <sample><time>600</time><depth>100</depth><pressure>2000</pressure><temperature>72</temperature></sample>
        </samples>
    </dive>
</dives>
```

- [ ] **Step 2: Write failing tests**

Append:

```dart
test('imperial values are converted to SI at reader boundary', () async {
  final content = await File('test/fixtures/macdive_xml/imperial_small.xml').readAsString();
  final dive = MacDiveXmlReader.parse(content).dives.first;
  expect(dive.maxDepthMeters, closeTo(30.48, 0.01));
  expect(dive.avgDepthMeters, closeTo(18.29, 0.01));
  expect(dive.tempHighCelsius, closeTo(26.67, 0.01));
  expect(dive.tempLowCelsius, closeTo(21.11, 0.01));
  expect(dive.weightKg, closeTo(4.54, 0.01));
  expect(dive.samples.last.pressureBar, closeTo(137.9, 0.1));
  expect(dive.samples.last.depthMeters, closeTo(30.48, 0.01));
});
```

- [ ] **Step 3: Run — expect PASS** (the reader already calls the converter)

If it fails, the converter or reader has an error. Fix before proceeding.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/macdive_xml/imperial_small.xml test/features/universal_import/data/services/macdive_xml_reader_test.dart
git commit -m "test(import): imperial-unit fixture for MacDive XML reader"
```

---

## Task 8: `MacDiveXmlParser` — produce `ImportPayload`

**Files:**
- Create: `lib/features/universal_import/data/parsers/macdive_xml_parser.dart`
- Create: `test/features/universal_import/data/parsers/macdive_xml_parser_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

void main() {
  group('MacDiveXmlParser', () {
    test('produces dives, sites, buddies, equipment, tags entities', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final payload = await MacDiveXmlParser().parse(bytes);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 1);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 1);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 1);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 1);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
    });

    test('dive carries sourceUuid from <identifier>', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final payload = await MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      expect(dive['sourceUuid'], '20240601090000-ABC123');
    });

    test('tag entity names match dive tagRefs', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final payload = await MacDiveXmlParser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).first;
      final tagRefs = dive['tagRefs'] as List?;
      expect(tagRefs, containsAll(['Reef', 'Photography']));
      final tagNames = payload.entitiesOf(ImportEntityType.tags)
          .map((t) => t['name']).toSet();
      expect(tagNames, containsAll(['Reef', 'Photography']));
    });

    test('site data in payload matches reader', () async {
      final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final payload = await MacDiveXmlParser().parse(bytes);
      final site = payload.entitiesOf(ImportEntityType.sites).first;
      expect(site['name'], 'Test Reef');
      expect(site['country'], 'Mexico');
      expect(site['waterType'], 'saltwater');
      expect(site['latitude'], closeTo(24.12345, 0.00001));
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Expected: FAIL — `MacDiveXmlParser not defined`.

- [ ] **Step 3: Implement the parser**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_reader.dart';

/// Parses MacDive native XML (`<dives>` root, `macdive_logbook.dtd`) into
/// an [ImportPayload].
class MacDiveXmlParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.macdiveXml];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final String content;
    try {
      content = utf8.decode(fileBytes, allowMalformed: true);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Could not decode file as UTF-8: $e',
          ),
        ],
      );
    }

    final MacDiveXmlLogbook logbook;
    try {
      logbook = MacDiveXmlReader.parse(content);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to parse MacDive XML: $e',
          ),
        ],
      );
    }

    final warnings = <ImportWarning>[];
    final diveMaps = <Map<String, dynamic>>[];
    final siteMaps = <String, Map<String, dynamic>>{};  // name → map (dedup)
    final buddyMaps = <String, Map<String, dynamic>>{}; // name → map
    final gearMaps = <String, Map<String, dynamic>>{};  // key → map
    final tagMaps = <String, Map<String, dynamic>>{};   // name → map

    for (final dive in logbook.dives) {
      final diveMap = _mapDive(dive);
      diveMaps.add(diveMap);

      // Site dedup by name.
      if (dive.site?.name != null && dive.site!.name!.isNotEmpty) {
        final name = dive.site!.name!;
        siteMaps.putIfAbsent(name, () => _mapSite(dive.site!));
        diveMap['siteName'] = name;
      }

      // Buddies.
      for (final name in dive.buddies) {
        buddyMaps.putIfAbsent(name, () => {'name': name});
      }

      // Gear dedup by manufacturer+name+serial.
      for (final g in dive.gear) {
        final key = '${g.manufacturer ?? ''}|${g.name ?? ''}|${g.serial ?? ''}';
        gearMaps.putIfAbsent(key, () => _mapGear(g));
      }

      // Tags.
      for (final tag in dive.tags) {
        tagMaps.putIfAbsent(tag, () => {'name': tag});
      }
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveMaps.isNotEmpty) entities[ImportEntityType.dives] = diveMaps;
    if (siteMaps.isNotEmpty) entities[ImportEntityType.sites] = siteMaps.values.toList();
    if (buddyMaps.isNotEmpty) entities[ImportEntityType.buddies] = buddyMaps.values.toList();
    if (gearMaps.isNotEmpty) entities[ImportEntityType.equipment] = gearMaps.values.toList();
    if (tagMaps.isNotEmpty) entities[ImportEntityType.tags] = tagMaps.values.toList();

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {'source': 'macdive_xml', 'diveCount': logbook.dives.length},
    );
  }

  Map<String, dynamic> _mapDive(MacDiveXmlDive d) {
    final map = <String, dynamic>{};
    if (d.identifier != null) map['sourceUuid'] = d.identifier;
    if (d.date != null) map['dateTime'] = d.date;
    if (d.diveNumber != null) map['diveNumber'] = d.diveNumber;
    if (d.repetitiveDive != null) map['diveNumberOfDay'] = d.repetitiveDive;
    if (d.maxDepthMeters != null) map['maxDepth'] = d.maxDepthMeters;
    if (d.avgDepthMeters != null) map['avgDepth'] = d.avgDepthMeters;
    if (d.duration != null) map['runtime'] = d.duration;
    if (d.surfaceInterval != null) map['surfaceInterval'] = d.surfaceInterval;
    if (d.tempLowCelsius != null) map['waterTemp'] = d.tempLowCelsius;
    if (d.airTempCelsius != null) map['airTemp'] = d.airTempCelsius;
    if (d.cns != null) map['cns'] = d.cns;
    if (d.decoModel != null) map['decoModel'] = d.decoModel;
    if (d.gasModel != null) map['gasModel'] = d.gasModel;
    if (d.visibility != null) map['visibility'] = d.visibility;
    if (d.weightKg != null) map['weightUsed'] = d.weightKg;
    if (d.notes != null) map['notes'] = d.notes;
    if (d.diveMaster != null) map['diveMaster'] = d.diveMaster;
    if (d.diveOperator != null) map['diveOperator'] = d.diveOperator;
    if (d.skipper != null) map['boatCaptain'] = d.skipper;
    if (d.boat != null) map['boatName'] = d.boat;
    if (d.weather != null) map['weather'] = d.weather;
    if (d.current != null) map['currentDirection'] = d.current;
    if (d.surfaceConditions != null) map['surfaceConditions'] = d.surfaceConditions;
    if (d.entryType != null) map['entryMethod'] = d.entryType;
    if (d.computer != null) map['diveComputerModel'] = d.computer;
    if (d.serial != null) map['diveComputerSerial'] = d.serial;
    if (d.rating != null) map['rating'] = d.rating!.round();
    if (d.tags.isNotEmpty) map['tagRefs'] = List<String>.from(d.tags);

    final tanks = <Map<String, dynamic>>[];
    for (var i = 0; i < d.gases.length; i++) {
      final g = d.gases[i];
      tanks.add({
        'index': i,
        if (g.pressureStartBar != null) 'startPressure': g.pressureStartBar,
        if (g.pressureEndBar != null) 'endPressure': g.pressureEndBar,
        if (g.tankSizeLiters != null) 'volumeL': g.tankSizeLiters,
        if (g.workingPressureBar != null) 'workingPressureBar': g.workingPressureBar,
        if (g.tankName != null) 'name': g.tankName,
        if (g.supplyType != null) 'supplyType': g.supplyType,
        if (g.duration != null) 'runtime': g.duration,
        'gasMix': {
          if (g.oxygenPercent != null) 'o2': g.oxygenPercent! / 100.0,
          if (g.heliumPercent != null) 'he': g.heliumPercent! / 100.0,
        },
      });
    }
    if (tanks.isNotEmpty) map['tanks'] = tanks;

    final profile = <Map<String, dynamic>>[];
    for (final s in d.samples) {
      profile.add({
        'timestamp': s.time.inSeconds,
        if (s.depthMeters != null) 'depth': s.depthMeters,
        if (s.pressureBar != null) 'pressure': s.pressureBar,
        if (s.temperatureCelsius != null) 'temperature': s.temperatureCelsius,
        if (s.ppO2 != null) 'ppO2': s.ppO2,
        if (s.ndtSeconds != null) 'ndl': s.ndtSeconds,
      });
    }
    if (profile.isNotEmpty) map['profile'] = profile;

    return map;
  }

  Map<String, dynamic> _mapSite(MacDiveXmlSite s) {
    final map = <String, dynamic>{};
    if (s.name != null) map['name'] = s.name;
    if (s.country != null) map['country'] = s.country;
    if (s.location != null) map['region'] = s.location;
    if (s.bodyOfWater != null) map['bodyOfWater'] = s.bodyOfWater;
    if (s.waterType != null) map['waterType'] = s.waterType;
    if (s.difficulty != null) map['difficulty'] = s.difficulty;
    if (s.altitudeMeters != null) map['altitude'] = s.altitudeMeters;
    if (s.latitude != null) map['latitude'] = s.latitude;
    if (s.longitude != null) map['longitude'] = s.longitude;
    return map;
  }

  Map<String, dynamic> _mapGear(MacDiveXmlGearItem g) {
    final map = <String, dynamic>{};
    if (g.name != null) map['name'] = g.name;
    if (g.manufacturer != null) map['manufacturer'] = g.manufacturer;
    if (g.type != null) map['type'] = g.type;
    if (g.serial != null) map['serialNumber'] = g.serial;
    return map;
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/features/universal_import/data/parsers/macdive_xml_parser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/parsers/macdive_xml_parser.dart test/features/universal_import/data/parsers/macdive_xml_parser_test.dart
git commit -m "feat(import): MacDiveXmlParser producing unified ImportPayload"
```

---

## Task 9: Wire into `_parserFor`

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`:

```dart
test('pickFile with MacDive XML advances to review and produces payload', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = container.read(universalImportNotifierProvider.notifier);

  final content = await File('test/fixtures/macdive_xml/metric_small.xml').readAsString();
  await notifier.loadFileFromBytes(
    Uint8List.fromList(utf8.encode(content)),
    'metric_small.xml',
  );
  await notifier.confirmSource();

  final state = container.read(universalImportNotifierProvider);
  expect(state.payload, isNotNull);
  expect(state.payload!.entitiesOf(ImportEntityType.dives).length, 1);
});
```

- [ ] **Step 2: Run — expect FAIL**

Expected: FAIL — parser unavailable.

- [ ] **Step 3: Add the switch case**

In `lib/features/universal_import/presentation/providers/universal_import_providers.dart`, in `_parserFor`:

```dart
  ImportParser _parserFor(ImportFormat format, {PresetRegistry? registry}) {
    return switch (format) {
      ImportFormat.csv => CsvImportParser(
        customMapping: state.fieldMapping,
        pipeline: registry != null ? CsvPipeline(registry: registry) : null,
      ),
      ImportFormat.uddf => UddfImportParser(),
      ImportFormat.macdiveXml => MacDiveXmlParser(),  // <-- NEW
      ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
      ImportFormat.fit => const FitImportParser(),
      ImportFormat.shearwaterDb => ShearwaterCloudParser(),
      _ => const PlaceholderParser(),
    };
  }
```

Add the import at the top:

```dart
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';
```

- [ ] **Step 4: Run — expect PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): wire MacDiveXmlParser into universal import pipeline"
```

---

## Task 10: Real-sample regression test

**Files:**
- Create: `test/features/universal_import/data/parsers/macdive_xml_real_sample_test.dart`

- [ ] **Step 1: Write gated integration test**

```dart
@Tags(['real-data'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';

const _realSamplePath =
  '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/Apr 4 no iPad Mini sync.xml';

void main() {
  test('imports MacDive XML 30MB sample without throwing, produces 540 dives',
      () async {
    final file = File(_realSamplePath);
    if (!file.existsSync()) {
      markTestSkipped('Real sample not available in this environment');
      return;
    }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final payload = await MacDiveXmlParser().parse(bytes);
    expect(payload.entitiesOf(ImportEntityType.dives).length, 540);
    // Tags should be present (unlike MacDive UDDF).
    expect(payload.entitiesOf(ImportEntityType.tags), isNotEmpty);
  });
}
```

- [ ] **Step 2: Run — expect PASS**

Run: `flutter test --tags=real-data test/features/universal_import/data/parsers/macdive_xml_real_sample_test.dart`
Expected: PASS. If FAIL, examine `payload.warnings` and iterate.

- [ ] **Step 3: Commit**

```bash
git commit -am "test(import): MacDive XML real-sample regression"
```

---

## Task 11: Release notes

- [ ] **Step 1: Update CHANGELOG**

Add under Unreleased:

```markdown
### Added
- Support for MacDive native XML import (`.xml` exported via MacDive
  → File → Export → MacDive XML). Imports tags, gear, buddies, dive
  sites, and per-dive gas/profile data. Works in both Imperial and
  Metric unit modes.
```

- [ ] **Step 2: Final checks**

```bash
dart format lib/ test/
flutter analyze
flutter test
```
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: changelog for MacDive XML import"
```

---

## Self-Review Checklist

- [x] Spec requirement "recognize `<!DOCTYPE dives>`" → Task 2.
- [x] Spec requirement "tag import via MacDive XML" → Task 8 (tagRefs, Task 10 (real-sample).
- [x] Spec requirement "imperial↔metric at the boundary" → Task 5 + Task 7.
- [x] Spec requirement "lat=0,lon=0 is no-GPS" → Task 6 test.
- [x] No placeholders: each test step has real assertions; each implementation step has real code.
- [x] Deferred scope: `<photos>` is *not* handled here — Milestone 4 will extend `MacDiveXmlReader` and the parser payload.

## Notes for the executor

- The fixture files in `test/fixtures/macdive_xml/` are small enough to check in (< 2 KB each).
- If `WaterType`/`EntryMethod` enum names don't match the ones used here, update `MacDiveValueMapper` — don't rename the core enums.
- When you add the MacDive XML parser to the `_parserFor` switch, the import at the top of `universal_import_providers.dart` must be added in the same commit to avoid an analyzer error.
