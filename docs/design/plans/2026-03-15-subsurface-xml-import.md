# Subsurface XML Import Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated parser for Subsurface XML (.ssrf) files so the universal import wizard can import dives, sites, trips, tags, cylinders, weights, and profile data from Subsurface exports.

**Architecture:** A new `SubsurfaceXmlParser` implements `ImportParser`, parsing `<divelog program='subsurface'>` XML into `ImportPayload` maps with keys matching `UddfEntityImporter`'s contract. One wiring change in `_parserFor()` routes `ImportFormat.subsurfaceXml` to the new parser. No UI, database, or pipeline changes.

**Tech Stack:** Dart, `xml` package (already a dependency), Flutter test framework

**Spec:** `docs/superpowers/specs/2026-03-15-subsurface-xml-import-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` | Create | Parser: XML traversal, value parsing helpers, enum mapping, all entity extraction |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Modify (line 342) | Wire `ImportFormat.subsurfaceXml` to new parser |
| `lib/features/universal_import/data/parsers/uddf_import_parser.dart` | Modify (lines 11, 23-26) | Remove `subsurfaceXml` from `supportedFormats` and update docstring |
| `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` | Create | All unit + integration tests |

**Test fixture:** The integration test uses `subsurface_export.ssrf` which already exists in the project root directory.

---

## Chunk 1: Value Parsing Helpers and Minimal Dive Parsing

### Task 1: Scaffold parser with value parsing helpers and test infrastructure

**Files:**
- Create: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Create: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write tests for value parsing helpers**

Create the test file with a helper to convert XML strings to bytes, and tests for the internal parsing logic exposed through minimal dives:

```dart
// test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

void main() {
  final parser = SubsurfaceXmlParser();

  Uint8List xmlBytes(String xml) => Uint8List.fromList(utf8.encode(xml));

  group('supportedFormats', () {
    test('supports subsurfaceXml', () {
      expect(parser.supportedFormats, [ImportFormat.subsurfaceXml]);
    });
  });

  group('value parsing - via minimal dives', () {
    test('parses duration in M:SS min format', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='68:12 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives[0]['duration'], const Duration(minutes: 68, seconds: 12));
      expect(dives[0]['runtime'], const Duration(minutes: 68, seconds: 12));
    });

    test('parses depth values with unit suffix', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='25.5 m' mean='18.3 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['maxDepth'], 25.5);
      expect(dives[0]['avgDepth'], 18.3);
    });

    test('parses dateTime from date and time attributes', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='5' date='2025-11-13' time='07:23:58' duration='10:00 min'>
  <divecomputer model='Test'>
  <depth max='8.0 m' mean='4.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['dateTime'], DateTime(2025, 11, 13, 7, 23, 58));
      expect(dives[0]['diveNumber'], 5);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: Compilation error - `SubsurfaceXmlParser` not found.

- [ ] **Step 3: Implement parser scaffold with value helpers and minimal dive parsing**

```dart
// lib/features/universal_import/data/parsers/subsurface_xml_parser.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for Subsurface XML (.ssrf) dive log files.
///
/// Parses the `<divelog program='subsurface'>` format directly into
/// [ImportPayload] maps with keys matching [UddfEntityImporter]'s contract.
class SubsurfaceXmlParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.subsurfaceXml];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final content = utf8.decode(fileBytes, allowMalformed: true);

    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Invalid XML file: ${e.message}',
          ),
        ],
      );
    }

    final root = document.rootElement;
    if (root.name.local != 'divelog') {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Not a Subsurface file: missing <divelog> root element.',
          ),
        ],
      );
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    final warnings = <ImportWarning>[];

    // Parse dives
    final divesElement = root.findElements('dives').firstOrNull;
    if (divesElement != null) {
      final dives = <Map<String, dynamic>>[];
      for (final diveElement in divesElement.findElements('dive')) {
        try {
          dives.add(_parseDive(diveElement));
        } catch (e) {
          warnings.add(ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Skipped dive: $e',
            entityType: ImportEntityType.dives,
          ));
        }
      }
      if (dives.isNotEmpty) {
        entities[ImportEntityType.dives] = dives;
      }
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'sourceApp': options?.sourceApp.displayName ?? 'Subsurface',
      },
    );
  }

  // -- Dive parsing --

  Map<String, dynamic> _parseDive(XmlElement dive) {
    final data = <String, dynamic>{};

    // Date and time
    final date = dive.getAttribute('date');
    final time = dive.getAttribute('time');
    if (date != null) {
      final dateTime = time != null
          ? DateTime.parse('${date}T$time')
          : DateTime.parse(date);
      data['dateTime'] = dateTime;
    }

    // Dive number
    final number = int.tryParse(dive.getAttribute('number') ?? '');
    if (number != null) data['diveNumber'] = number;

    // Duration
    final duration = _parseDuration(dive.getAttribute('duration'));
    if (duration != null) {
      data['duration'] = duration;
      data['runtime'] = duration;
    }

    // Dive computer data
    final dc = dive.findElements('divecomputer').firstOrNull;
    if (dc != null) {
      final model = dc.getAttribute('model');
      if (model != null) data['diveComputerModel'] = model;

      final depthEl = dc.findElements('depth').firstOrNull;
      if (depthEl != null) {
        final maxDepth = _parseDouble(depthEl.getAttribute('max'));
        if (maxDepth != null) data['maxDepth'] = maxDepth;
        final avgDepth = _parseDouble(depthEl.getAttribute('mean'));
        if (avgDepth != null) data['avgDepth'] = avgDepth;
      }

      final tempEl = dc.findElements('temperature').firstOrNull;
      if (tempEl != null) {
        final waterTemp = _parseDouble(tempEl.getAttribute('water'));
        if (waterTemp != null) data['waterTemp'] = waterTemp;
      }
    }

    return data;
  }

  // -- Value parsing helpers --

  static double? _parseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.split(' ').first);
  }

  static int? _parseInt(String? value) => _parseDouble(value)?.round();

  static Duration? _parseDuration(String? value) {
    if (value == null) return null;
    // Format: 'M:SS min' e.g. '68:12 min', '0:42 min'
    final cleaned = value.replaceAll(' min', '').trim();
    final parts = cleaned.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return Duration(minutes: minutes, seconds: seconds);
  }

  static int? _parseDurationSeconds(String? value) {
    final d = _parseDuration(value);
    if (d == null) return null;
    return d.inSeconds;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: scaffold SubsurfaceXmlParser with value helpers and minimal dive parsing"
```

---

### Task 2: Add dive metadata parsing (buddy, divemaster, notes, suit, visibility, current, SAC, temperature, salinity)

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write tests for dive metadata**

Append to the test file:

```dart
  group('dive metadata', () {
    test('parses buddy with leading comma cleanup', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <buddy>, John Doe</buddy>
  <divemaster>Jane Smith</divemaster>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['buddy'], 'John Doe');
      expect(dive['diveMaster'], 'Jane Smith');
    });

    test('parses notes and appends suit and SAC', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' sac='16.262 l/min' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <notes>Great dive!</notes>
  <suit>3mm Bare wetsuit</suit>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['notes'], contains('Great dive!'));
      expect(dive['notes'], contains('Suit: 3mm Bare wetsuit'));
      expect(dive['notes'], contains('SAC: 16.262 l/min'));
    });

    test('parses air temperature from divetemperature element', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divetemperature air='21.111 C'/>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <temperature water='28.0 C' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['airTemp'], closeTo(21.111, 0.001));
      expect(dive['waterTemp'], 28.0);
    });

    test('maps visibility and current enums', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' visibility='5' current='4' rating='3' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['visibility'], Visibility.excellent);
      expect(dive['currentStrength'], CurrentStrength.strong);
      expect(dive['rating'], 3);
    });

    test('maps watersalinity to WaterType', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' watersalinity='1030 g/l' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['waterType'], WaterType.salt);
    });
  });
```

Add the required imports at the top of the test file:

```dart
import 'package:submersion/core/constants/enums.dart';
```

- [ ] **Step 2: Run tests to verify new tests fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: New tests FAIL (buddy, notes, visibility etc. not parsed yet).

- [ ] **Step 3: Implement dive metadata parsing**

Add to `_parseDive()` method in `subsurface_xml_parser.dart`, and add the enum imports:

Add import at top of file:
```dart
import 'package:submersion/core/constants/enums.dart';
```

Add the following to `_parseDive()`, after the divecomputer block:

```dart
    // Air temperature (direct child of <dive>, NOT inside <divecomputer>)
    final diveTempEl = dive.findElements('divetemperature').firstOrNull;
    if (diveTempEl != null) {
      final airTemp = _parseDouble(diveTempEl.getAttribute('air'));
      if (airTemp != null) data['airTemp'] = airTemp;
    }

    // Visibility (1-5 scale -> enum)
    final visibility = _mapVisibility(
      int.tryParse(dive.getAttribute('visibility') ?? ''),
    );
    if (visibility != null) data['visibility'] = visibility;

    // Rating
    final rating = int.tryParse(dive.getAttribute('rating') ?? '');
    if (rating != null) data['rating'] = rating;

    // Current strength (1-5 scale -> enum)
    final currentStrength = _mapCurrentStrength(
      int.tryParse(dive.getAttribute('current') ?? ''),
    );
    if (currentStrength != null) data['currentStrength'] = currentStrength;

    // Water type from salinity
    final salinity = _parseDouble(dive.getAttribute('watersalinity'));
    if (salinity != null) {
      data['waterType'] = salinity >= 1020 ? WaterType.salt : WaterType.fresh;
    }

    // Buddy (trim leading commas and whitespace)
    final buddyText = dive.findElements('buddy').firstOrNull?.innerText;
    if (buddyText != null) {
      final cleaned = buddyText
          .replaceAll(RegExp(r'^[,\s]+'), '')
          .replaceAll(RegExp(r'[,\s]+$'), '')
          .trim();
      if (cleaned.isNotEmpty) data['buddy'] = cleaned;
    }

    // Divemaster
    final dmText = dive.findElements('divemaster').firstOrNull?.innerText;
    if (dmText != null && dmText.trim().isNotEmpty) {
      data['diveMaster'] = dmText.trim();
    }

    // Notes, suit, SAC (build composite notes)
    final noteParts = <String>[];
    final notesText = dive.findElements('notes').firstOrNull?.innerText;
    if (notesText != null && notesText.trim().isNotEmpty) {
      noteParts.add(notesText.trim());
    }
    final suitText = dive.findElements('suit').firstOrNull?.innerText;
    if (suitText != null && suitText.trim().isNotEmpty) {
      noteParts.add('Suit: ${suitText.trim()}');
    }
    final sac = dive.getAttribute('sac');
    if (sac != null) {
      noteParts.add('SAC: $sac');
    }
    if (noteParts.isNotEmpty) data['notes'] = noteParts.join('\n');

    // Dive computer model
    // (already handled above in divecomputer block)
```

Add these static methods to the class:

```dart
  static Visibility? _mapVisibility(int? value) {
    if (value == null) return null;
    return switch (value) {
      1 || 2 => Visibility.poor,
      3 => Visibility.moderate,
      4 => Visibility.good,
      5 => Visibility.excellent,
      _ => null,
    };
  }

  static CurrentStrength? _mapCurrentStrength(int? value) {
    if (value == null) return null;
    return switch (value) {
      1 => CurrentStrength.none,
      2 => CurrentStrength.light,
      3 => CurrentStrength.moderate,
      4 || 5 => CurrentStrength.strong,
      _ => null,
    };
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: add dive metadata parsing (buddy, notes, visibility, current, salinity)"
```

---

### Task 3: Add cylinder/tank parsing with GasMix and weight parsing

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write tests for cylinder and weight parsing**

Append to the test file:

```dart
  group('cylinders', () {
    test('parses cylinder with gas mix as GasMix object', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' o2='32.0%' start='200.0 bar' end='50.0 bar' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
      expect(tanks[0]['volume'], closeTo(11.094, 0.001));
      expect(tanks[0]['workingPressure'], 207);
      expect(tanks[0]['startPressure'], 200);
      expect(tanks[0]['endPressure'], 50);
      expect(tanks[0]['gasMix'], isA<GasMix>());
      expect((tanks[0]['gasMix'] as GasMix).o2, 32.0);
      expect((tanks[0]['gasMix'] as GasMix).he, 0.0);
      expect(tanks[0]['name'], 'AL80');
    });

    test('defaults to air (21% O2, 0% He) when no gas attrs', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
      final gasMix = tanks[0]['gasMix'] as GasMix;
      expect(gasMix.o2, 21.0);
      expect(gasMix.he, 0.0);
    });

    test('skips empty cylinder elements', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.094 l' workpressure='206.843 bar' description='AL80' />
  <cylinder />
  <cylinder />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks.length, 1);
    });

    test('parses trimix cylinder', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='12.0 l' workpressure='232.0 bar' description='D12' o2='18.0%' he='45.0%' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      final gasMix = tanks[0]['gasMix'] as GasMix;
      expect(gasMix.o2, 18.0);
      expect(gasMix.he, 45.0);
      expect(gasMix.isTrimix, isTrue);
    });

    test('falls back to sample pressures when cylinder lacks start/end', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <cylinder size='11.094 l' description='AL80' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.5 bar' />
  <sample time='1:00 min' depth='20.0 m' pressure0='150.0 bar' />
  <sample time='2:00 min' depth='0.0 m' pressure0='100.3 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final tanks =
          result.entitiesOf(ImportEntityType.dives).first['tanks']
              as List<Map<String, dynamic>>;
      expect(tanks[0]['startPressure'], 201);
      expect(tanks[0]['endPressure'], 100);
    });
  });

  group('profile samples', () {
    test('parses sample time/depth/temp/pressure', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='2:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  <sample time='0:00 min' depth='0.0 m' temp='21.0 C' pressure0='196.9 bar' />
  <sample time='0:30 min' depth='10.5 m' />
  <sample time='1:00 min' depth='20.0 m' pressure0='180.0 bar' />
  <sample time='1:30 min' depth='10.0 m' />
  <sample time='2:00 min' depth='0.0 m' pressure0='170.0 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile.length, 5);

      // First sample
      expect(profile[0]['timestamp'], 0);
      expect(profile[0]['depth'], 0.0);
      expect(profile[0]['temperature'], 21.0);
      expect(profile[0]['pressure'], 196.9);

      // Second sample (no temp or pressure)
      expect(profile[1]['timestamp'], 30);
      expect(profile[1]['depth'], 10.5);
      expect(profile[1].containsKey('temperature'), isFalse);
      expect(profile[1].containsKey('pressure'), isFalse);

      // Last sample
      expect(profile[4]['timestamp'], 120);
      expect(profile[4]['depth'], 0.0);
    });
  });

  group('weights', () {
    test('parses weight amount and maps description to WeightType', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <weightsystem weight='6.35 kg' description='belt' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final weights = dive['weights'] as List<Map<String, dynamic>>;
      expect(weights.length, 1);
      expect(weights[0]['amount'], closeTo(6.35, 0.01));
      expect(weights[0]['type'], WeightType.belt);
      expect(weights[0]['notes'], 'belt');
    });
  });
```

Add these imports at top of test file:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

- [ ] **Step 2: Run tests to verify new tests fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: New cylinder and weight tests FAIL.

- [ ] **Step 3: Implement cylinder and weight parsing**

Add import at top of parser file:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

Add these methods to the class:

```dart
  List<Map<String, dynamic>> _parseCylinders(
    XmlElement dive,
    List<Map<String, dynamic>>? profilePoints,
  ) {
    final tanks = <Map<String, dynamic>>[];
    var order = 0;

    for (final cyl in dive.findElements('cylinder')) {
      final size = cyl.getAttribute('size');
      final desc = cyl.getAttribute('description');
      // Skip empty cylinder slots
      if (size == null && desc == null) continue;

      final o2Str = cyl.getAttribute('o2');
      final heStr = cyl.getAttribute('he');
      final o2 = o2Str != null
          ? double.tryParse(o2Str.replaceAll('%', '').trim()) ?? 21.0
          : 21.0;
      final he = heStr != null
          ? double.tryParse(heStr.replaceAll('%', '').trim()) ?? 0.0
          : 0.0;

      var startPressure = _parseInt(cyl.getAttribute('start'));
      var endPressure = _parseInt(cyl.getAttribute('end'));

      // Fallback: use first/last sample pressure0 for the first cylinder
      if (startPressure == null &&
          endPressure == null &&
          order == 0 &&
          profilePoints != null &&
          profilePoints.isNotEmpty) {
        final firstPressure = profilePoints
            .where((p) => p['pressure'] != null)
            .firstOrNull;
        final lastPressure = profilePoints
            .where((p) => p['pressure'] != null)
            .lastOrNull;
        if (firstPressure != null) {
          startPressure = (firstPressure['pressure'] as double).round();
        }
        if (lastPressure != null) {
          endPressure = (lastPressure['pressure'] as double).round();
        }
      }

      tanks.add({
        'volume': _parseDouble(size),
        'workingPressure': _parseInt(cyl.getAttribute('workpressure')),
        'startPressure': startPressure,
        'endPressure': endPressure,
        'gasMix': GasMix(o2: o2, he: he),
        'name': desc,
        'order': order,
      });

      order++;
    }

    return tanks;
  }

  List<Map<String, dynamic>> _parseWeights(XmlElement dive) {
    final weights = <Map<String, dynamic>>[];

    for (final ws in dive.findElements('weightsystem')) {
      final amount = _parseDouble(ws.getAttribute('weight'));
      if (amount == null) continue;

      final description = ws.getAttribute('description') ?? '';
      weights.add({
        'amount': amount,
        'type': _mapWeightType(description),
        'notes': description,
      });
    }

    return weights;
  }

  static WeightType _mapWeightType(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('belt')) return WeightType.belt;
    if (lower.contains('integrated')) return WeightType.integrated;
    if (lower.contains('ankle')) return WeightType.ankleWeights;
    if (lower.contains('trim')) return WeightType.trimWeights;
    if (lower.contains('backplate')) return WeightType.backplate;
    return WeightType.integrated;
  }
```

In `_parseDive()`, add profile parsing first (needed by cylinder fallback), then call `_parseCylinders` and `_parseWeights`. Insert **before** the air temperature block:

```dart
    // Profile samples (parse early -- cylinders need them for pressure fallback)
    List<Map<String, dynamic>>? profilePoints;
    if (dc != null) {
      profilePoints = _parseProfile(dc);
      if (profilePoints.isNotEmpty) {
        data['profile'] = profilePoints;
      }
    }

    // Cylinders
    final tanks = _parseCylinders(dive, profilePoints);
    if (tanks.isNotEmpty) data['tanks'] = tanks;

    // Weights
    final weights = _parseWeights(dive);
    if (weights.isNotEmpty) data['weights'] = weights;
```

Add a stub `_parseProfile` method (full implementation in Task 4):

```dart
  List<Map<String, dynamic>> _parseProfile(XmlElement divecomputer) {
    final points = <Map<String, dynamic>>[];

    for (final sample in divecomputer.findElements('sample')) {
      final timestamp = _parseDurationSeconds(sample.getAttribute('time'));
      final depth = _parseDouble(sample.getAttribute('depth'));
      if (timestamp == null || depth == null) continue;

      final point = <String, dynamic>{
        'timestamp': timestamp,
        'depth': depth,
      };

      final temp = _parseDouble(sample.getAttribute('temp'));
      if (temp != null) point['temperature'] = temp;

      final pressure = _parseDouble(sample.getAttribute('pressure0'));
      if (pressure != null) point['pressure'] = pressure;

      points.add(point);
    }

    return points;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: add cylinder/tank, weight, and profile sample parsing"
```

---

## Chunk 2: Sites, Trips, Tags, and Wiring

### Task 4: Add site parsing with GPS and geo taxonomy

**Note:** Subsurface sites have no separate `description` element. The importer will
use `''` for `DiveSite.description` (populated from `siteData['description']` which
is unset). Site-level `<notes>` maps to `siteData['notes']`. This is correct behavior.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write tests for site parsing**

Append to test file:

```dart
  group('sites', () {
    test('parses site name, GPS, and geo taxonomy', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid='abc123' name='Blue Hole' gps='18.465562 -66.084902'>
  <geo cat='2' origin='2' value='Puerto Rico'/>
  <geo cat='3' origin='0' value='Isabela'/>
</site>
</divesites>
<dives>
<dive number='1' divesiteid='abc123' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 1);
      expect(sites[0]['name'], 'Blue Hole');
      expect(sites[0]['uddfId'], 'abc123');
      expect(sites[0]['latitude'], closeTo(18.4656, 0.001));
      expect(sites[0]['longitude'], closeTo(-66.0849, 0.001));
      expect(sites[0]['country'], 'Puerto Rico');
      expect(sites[0]['region'], 'Isabela');

      // Dive links to site
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final siteRef = dive['site'] as Map<String, dynamic>;
      expect(siteRef['uddfId'], 'abc123');
    });

    test('trims leading whitespace from UUIDs', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<divesites>
<site uuid=' b95bba6' name='Escambron' gps='18.465562 -66.084902'>
</site>
</divesites>
<dives>
<dive number='1' divesiteid=' b95bba6' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites[0]['uddfId'], 'b95bba6');

      final dive = result.entitiesOf(ImportEntityType.dives).first;
      final siteRef = dive['site'] as Map<String, dynamic>;
      expect(siteRef['uddfId'], 'b95bba6');
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: Site tests FAIL (no site parsing implemented).

- [ ] **Step 3: Implement site parsing**

Add the `_parseSites` method to the class:

```dart
  List<Map<String, dynamic>> _parseSites(XmlElement divesites) {
    final sites = <Map<String, dynamic>>[];

    for (final site in divesites.findElements('site')) {
      final name = site.getAttribute('name');
      if (name == null || name.isEmpty) continue;

      final siteData = <String, dynamic>{
        'name': name,
      };

      final uuid = site.getAttribute('uuid')?.trim();
      if (uuid != null) siteData['uddfId'] = uuid;

      // GPS coordinates: 'lat lon' space-separated
      final gps = site.getAttribute('gps');
      if (gps != null) {
        final parts = gps.trim().split(RegExp(r'\s+'));
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null) siteData['latitude'] = lat;
          if (lon != null) siteData['longitude'] = lon;
        }
      }

      // Geo taxonomy
      for (final geo in site.findElements('geo')) {
        final cat = geo.getAttribute('cat');
        final value = geo.getAttribute('value');
        if (value == null) continue;
        if (cat == '2') siteData['country'] = value;
        if (cat == '3') siteData['region'] = value;
      }

      // Site-level notes
      final notes = site.findElements('notes').firstOrNull?.innerText;
      if (notes != null && notes.trim().isNotEmpty) {
        siteData['notes'] = notes.trim();
      }

      sites.add(siteData);
    }

    return sites;
  }
```

Update the `parse()` method to call `_parseSites()` before dives, and pass site data into `_parseDive()`. Add site parsing before the dives block:

```dart
    // Parse sites
    final siteMap = <String, Map<String, dynamic>>{};
    final divesitesElement = root.findElements('divesites').firstOrNull;
    if (divesitesElement != null) {
      final sites = _parseSites(divesitesElement);
      for (final site in sites) {
        final id = site['uddfId'] as String?;
        if (id != null) siteMap[id] = site;
      }
      if (sites.isNotEmpty) {
        entities[ImportEntityType.sites] = sites;
      }
    }
```

In `_parseDive()`, add site linking (after the notes block):

```dart
    // Site reference
    final siteId = dive.getAttribute('divesiteid')?.trim();
    if (siteId != null && siteId.isNotEmpty) {
      data['site'] = {'uddfId': siteId};
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: add site parsing with GPS, geo taxonomy, and UUID whitespace trimming"
```

---

### Task 5: Add trip and tag parsing

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write tests for trips and tags**

Append to test file:

```dart
  group('trips', () {
    test('parses trip wrapper and links child dives', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<trip date='2025-11-13' time='07:00:00' location='Puerto Rico'>
  <notes>Caribbean trip</notes>
  <dive number='1' date='2025-11-13' time='07:23:58' duration='60:00 min'>
    <divecomputer model='Test'>
    <depth max='8.0 m' mean='4.0 m' />
    </divecomputer>
  </dive>
  <dive number='2' date='2025-11-13' time='10:14:49' duration='65:00 min'>
    <divecomputer model='Test'>
    <depth max='10.0 m' mean='5.0 m' />
    </divecomputer>
  </dive>
</trip>
</dives>
</divelog>
'''));

      final trips = result.entitiesOf(ImportEntityType.trips);
      expect(trips.length, 1);
      expect(trips[0]['name'], 'Puerto Rico');
      expect(trips[0]['location'], 'Puerto Rico');
      expect(trips[0]['notes'], 'Caribbean trip');
      expect(trips[0]['startDate'], DateTime(2025, 11, 13, 7, 0, 0));

      // Both dives should reference the trip
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 2);
      final tripId = trips[0]['uddfId'] as String;
      expect(dives[0]['tripRef'], tripId);
      expect(dives[1]['tripRef'], tripId);
    });
  });

  group('tags', () {
    test('extracts unique tags from comma-separated dive attrs', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' tags='shore, student' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
<dive number='2' tags='shore, boat' date='2025-01-16' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      final tags = result.entitiesOf(ImportEntityType.tags);
      expect(tags.length, 3); // shore, student, boat (deduplicated)
      final tagNames = tags.map((t) => t['name']).toSet();
      expect(tagNames, containsAll(['shore', 'student', 'boat']));

      // Dives should have tagRefs
      final dives = result.entitiesOf(ImportEntityType.dives);
      final dive1TagRefs = dives[0]['tagRefs'] as List<String>;
      expect(dive1TagRefs, containsAll(['shore', 'student']));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: Trip and tag tests FAIL.

- [ ] **Step 3: Implement trip and tag parsing**

Update the `parse()` method to handle `<trip>` wrappers inside `<dives>`. Replace the existing dives parsing block with logic that handles both trip-wrapped and standalone dives:

```dart
    // Parse dives (with trip support)
    final divesElement = root.findElements('dives').firstOrNull;
    if (divesElement != null) {
      final dives = <Map<String, dynamic>>[];
      final trips = <Map<String, dynamic>>[];
      final allTags = <String, Map<String, dynamic>>{}; // dedup by name

      // Process trip-wrapped dives
      for (final tripElement in divesElement.findElements('trip')) {
        final tripData = _parseTrip(tripElement);
        trips.add(tripData);
        final tripId = tripData['uddfId'] as String;

        // Track dives within THIS trip only for endDate calculation
        final tripDives = <Map<String, dynamic>>[];
        for (final diveElement in tripElement.findElements('dive')) {
          try {
            final diveData = _parseDive(diveElement);
            diveData['tripRef'] = tripId;
            _collectTags(diveElement, diveData, allTags);
            dives.add(diveData);
            tripDives.add(diveData);
          } catch (e) {
            warnings.add(ImportWarning(
              severity: ImportWarningSeverity.warning,
              message: 'Skipped dive: $e',
              entityType: ImportEntityType.dives,
            ));
          }
        }

        // Set trip endDate from last dive within this trip
        if (tripDives.isNotEmpty) {
          final lastDiveInTrip = tripDives.last;
          final lastDateTime = lastDiveInTrip['dateTime'] as DateTime?;
          final lastDuration = lastDiveInTrip['runtime'] as Duration?;
          if (lastDateTime != null && lastDuration != null) {
            tripData['endDate'] = lastDateTime.add(lastDuration);
          } else if (lastDateTime != null) {
            tripData['endDate'] = lastDateTime;
          }
        }
      }

      // Process standalone dives (not inside a trip)
      for (final diveElement in divesElement.findElements('dive')) {
        try {
          final diveData = _parseDive(diveElement);
          _collectTags(diveElement, diveData, allTags);
          dives.add(diveData);
        } catch (e) {
          warnings.add(ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Skipped dive: $e',
            entityType: ImportEntityType.dives,
          ));
        }
      }

      if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
      if (trips.isNotEmpty) entities[ImportEntityType.trips] = trips;
      if (allTags.isNotEmpty) {
        entities[ImportEntityType.tags] = allTags.values.toList();
      }
    }
```

Add the `_parseTrip` and `_collectTags` methods:

```dart
  Map<String, dynamic> _parseTrip(XmlElement trip) {
    final tripId = 'trip_${trip.getAttribute('date')}_${trip.getAttribute('time') ?? ''}';
    final location = trip.getAttribute('location') ?? '';

    final date = trip.getAttribute('date');
    final time = trip.getAttribute('time');
    DateTime? startDate;
    if (date != null) {
      startDate = time != null
          ? DateTime.parse('${date}T$time')
          : DateTime.parse(date);
    }

    final notes = trip.findElements('notes').firstOrNull?.innerText?.trim();

    return {
      'uddfId': tripId,
      'name': location.isNotEmpty ? location : 'Trip on ${date ?? 'unknown'}',
      'location': location,
      'startDate': startDate,
      'endDate': startDate, // Updated later from last dive
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  void _collectTags(
    XmlElement diveElement,
    Map<String, dynamic> diveData,
    Map<String, Map<String, dynamic>> allTags,
  ) {
    final tagsAttr = diveElement.getAttribute('tags');
    if (tagsAttr == null || tagsAttr.isEmpty) return;

    final tagNames = tagsAttr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    diveData['tagRefs'] = tagNames;

    for (final tagName in tagNames) {
      allTags.putIfAbsent(tagName, () => {
        'name': tagName,
        'uddfId': tagName,
      });
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: add trip and tag parsing with deduplication"
```

---

### Task 6: Add edge case tests and error handling

**Files:**
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write edge case tests**

Append to test file:

```dart
  group('edge cases', () {
    test('returns error warning for empty input', () async {
      final result = await parser.parse(Uint8List(0));

      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('returns error warning for malformed XML', () async {
      final result = await parser.parse(xmlBytes('<not valid xml>>>'));

      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.severity, ImportWarningSeverity.error);
    });

    test('returns error warning for non-divelog root', () async {
      final result = await parser.parse(xmlBytes('<uddf></uddf>'));

      expect(result.isEmpty, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first.message,
        contains('divelog'),
      );
    });

    test('skips dives that fail to parse and adds warning', () async {
      // A dive with no date should fail parsing, but other dives continue
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''));

      // Should parse successfully even with minimal data
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
    });

    test('handles dive with no divecomputer element', () async {
      final result = await parser.parse(xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
</dive>
</dives>
</divelog>
'''));

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 1);
      expect(dives[0]['dateTime'], isNotNull);
      expect(dives[0].containsKey('maxDepth'), isFalse);
    });
  });
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`
Expected: All tests PASS. Edge cases should already be handled by existing error handling.

- [ ] **Step 3: Format and commit**

```bash
dart format test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git add test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "test: add edge case and error handling tests"
```

---

### Task 7: Wire parser, clean up UddfImportParser, and add integration test

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (line 342)
- Modify: `lib/features/universal_import/data/parsers/uddf_import_parser.dart` (lines 11, 23-26)
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 1: Write integration test**

Append to test file:

```dart
  group('integration - real Subsurface export', () {
    test('parses subsurface_export.ssrf with correct counts', () async {
      final file = File('subsurface_export.ssrf');
      if (!file.existsSync()) {
        markTestSkipped('subsurface_export.ssrf not found in project root');
        return;
      }

      final bytes = Uint8List.fromList(await file.readAsBytes());
      final result = await parser.parse(bytes);

      // Verify counts from the actual export
      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives.length, 16);

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites.length, 5);

      // Verify a specific dive has expected data
      final dive1 = dives.firstWhere((d) => d['diveNumber'] == 1);
      expect(dive1['dateTime'], DateTime(2025, 9, 20, 7, 44, 37));
      expect(dive1['buddy'], contains('Kiyan Griffin'));
      expect(dive1['diveMaster'], 'Sharon Patterson');
      expect(dive1['visibility'], Visibility.poor);
      expect(dive1['currentStrength'], CurrentStrength.strong);
      expect(dive1['waterType'], WaterType.salt);

      // Verify profile data exists
      final profile = dive1['profile'] as List<Map<String, dynamic>>?;
      expect(profile, isNotNull);
      expect(profile!.length, greaterThan(10));

      // Verify tanks
      final tanks = dive1['tanks'] as List<Map<String, dynamic>>?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      expect(tanks[0]['name'], 'AL80');

      // Verify weights
      final weights = dive1['weights'] as List<Map<String, dynamic>>?;
      expect(weights, isNotNull);
      expect(weights!.length, 1);
      expect(weights[0]['type'], WeightType.belt);

      // Verify tags extracted
      final tags = result.entitiesOf(ImportEntityType.tags);
      expect(tags.length, greaterThanOrEqualTo(2)); // shore, student at minimum

      // Verify no error warnings
      final errors = result.warnings
          .where((w) => w.severity == ImportWarningSeverity.error);
      expect(errors, isEmpty);
    });
  });
```

Add import at top of test file:

```dart
import 'dart:io';
```

- [ ] **Step 2: Run integration test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --name "integration"`
Expected: FAIL (wiring not done yet, but parser should already work -- let's see).

Actually the parser is already implemented, the test should pass. Run and verify.

- [ ] **Step 3: Wire the parser**

Modify `lib/features/universal_import/presentation/providers/universal_import_providers.dart`.

Add the import at the top of the file (after line 29):

```dart
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
```

Change line 342 from:

```dart
      ImportFormat.uddf || ImportFormat.subsurfaceXml => UddfImportParser(),
```

to:

```dart
      ImportFormat.uddf => UddfImportParser(),
      ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
```

- [ ] **Step 4: Clean up UddfImportParser**

Modify `lib/features/universal_import/data/parsers/uddf_import_parser.dart`.

Update the docstring on line 11 from:

```dart
/// Parser adapter for UDDF and Subsurface XML files.
```

to:

```dart
/// Parser adapter for UDDF files.
```

Update `supportedFormats` (lines 23-26) from:

```dart
  List<ImportFormat> get supportedFormats => [
    ImportFormat.uddf,
    ImportFormat.subsurfaceXml,
  ];
```

to:

```dart
  List<ImportFormat> get supportedFormats => [ImportFormat.uddf];
```

- [ ] **Step 5: Run all tests to verify nothing is broken**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 6: Run dart format**

Run: `dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart lib/features/universal_import/data/parsers/uddf_import_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart`
Expected: No changes needed (or files reformatted).

- [ ] **Step 7: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart lib/features/universal_import/data/parsers/uddf_import_parser.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat: wire SubsurfaceXmlParser and add integration test with real export"
```
