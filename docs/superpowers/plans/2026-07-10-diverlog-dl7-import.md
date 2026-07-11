# DiverLog+ / DAN DL7 Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import dive data exported from Aqualung DiverLog+ / DiverLog by parsing DAN DL7 (`.zxu`/`.zxl`) files — including the proprietary `ZAR{<AQUALUNG>...}` block — and by ingesting DiveCloud export ZIPs with automatic photo attachment.

**Architecture:** A new `DanDl7Parser` implements the existing `ImportParser` interface and emits `ImportPayload` maps whose keys match what `UddfEntityImporter` already consumes, so persistence, duplicate detection, review UI, and site matching all come for free. A `ZipExpansionService` at the file-intake layer fans a DiveCloud ZIP out into the existing bulk (#501) pipeline and indexes bundled photos, which `UniversalAdapter` attaches post-commit via the existing `MediaImportService.importLocalFileForDive`.

**Tech Stack:** Dart/Flutter, `archive: ^3.6.1` (promote from transitive), flutter_test. No new native code.

**Spec:** `docs/superpowers/specs/2026-07-10-diverlog-import-design.md`

## Global Constraints

- All work happens in the worktree at `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import` (branch `worktree-diverlog-import`). Subagents start in the MAIN checkout — always `cd` to the worktree path first and use worktree-absolute paths.
- All parser output uses SI units: meters, Celsius, bar, liters — matching what `SubsurfaceXmlParser` emits.
- Timestamps are wall-clock-as-UTC: always `DateTime.utc(...)`, never local time. Ignore any timezone suffix in DL7 timestamps.
- No emojis anywhere. Immutability: never mutate shared state.
- Before every commit: run `dart format .` from the worktree root (whole repo, not just changed files) and include any files it reformats.
- Never pipe `flutter analyze` through `head`/`tail` — run it whole-project and read the full output.
- Run tests per-file (`flutter test <path>`), not the whole suite (whole-suite runs time out in this repo).
- Commit messages: conventional-commit style (`feat(import): ...`, `test(import): ...`, `docs: ...`). Do NOT add a Co-Authored-By trailer.
- The `danDl7` enum value, `SourceApp.dan`, and DL7 XML-marker detection already exist as scaffolding. This plan makes them real; do not rename them.
- DL7 quick reference (verified against a real DiverLog+ i330R export):
  - Pipe-delimited segments, one per line (tolerate CR, CRLF, LF): `FSH` file header, `ZRH` record header (units), `ZAR{...}` application block, then per dive `ZDH` header, `ZDP{ |rows| }` profile, `ZDT` trailer.
  - After `split('|')` a segment keeps its tag at index 0, so spec field N = list index N.
  - ZDP rows start with `|`; after dropping the leading empty token, spec column N = index N-1. Columns: 1 time, 2 depth, 3 gas switch (`1`=air, `2.xy`=nitrox xy% O2), 4 PO2, 5 ascent-violation T/F, 6 deco-violation T/F, 7 ceiling, 8 temperature (sparse), 9 warnings, 10 main tank pressure, 13 CNS.
  - ZDP time: if ANY time token in the dive contains `.`, all are decimal minutes (`0.50` = 30 s); otherwise all are integer seconds.
  - Never trust: ZDH field 4 recording interval (real files lie), ZDT field 5 min temp (real files write `0.000000`), ZRH field 2 model code (often empty; the model lives in ZAR `PDC_MODEL`).

---

### Task 1: Dl7Reader + Dl7Document (segment scanner)

**Files:**
- Create: `lib/features/universal_import/data/parsers/dl7/dl7_document.dart`
- Create: `lib/features/universal_import/data/parsers/dl7/dl7_reader.dart`
- Test: `test/features/universal_import/data/parsers/dl7/dl7_reader_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart).
- Produces: `Dl7Document { List<String> fshFields, List<String> zrhFields, String zarContent, List<Dl7DiveRecord> dives, List<String> readerWarnings }` and `Dl7DiveRecord { List<String> zdhFields, List<List<String>> zdpRows, List<String> zdtFields }`. `const Dl7Reader()` with `Dl7Document read(String content)`. Segment field lists keep the tag at index 0 (spec field N = index N). `zdpRows` entries have the leading empty token removed (spec column N = index N-1). Tasks 4 and 5 depend on these exact names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_reader.dart';

const _multiLineZar = '''
FSH|^~<>{}|OCI201^^|ZXU|20220604000837|
ZRH|^~<>{}||13960|MSWG|ThM|C|BAR|L|
ZAR{
<AQUALUNG>
<APP>DiverLog+</APP>
<DUID>7168_13960_20220224130600_1</DUID>
</AQUALUNG>
}
ZDH|1|1|I|Q1S|20220224130600|27.2||FO2|
ZDP{
|0.00|0.00|1.00|
|0.50|1.52||||||27.2|||
|1.00|5.49|||||||||
ZDP}
ZDT|1|1|15.54|20220224140300|0.000000|0|
''';

const _multiDiveNoZar = '''
FSH|^~\\&{}|ANST01^12X456^A|ZXU|20180106163705+02:00|
ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|
ZDH|1|1|M|QS|20240301100000|22|||
ZDT|1|1|12.0|20240301102500|21||
ZDH|2|2|I|V|20240302110000|24|||
ZDP{
|0|1|1||||
|60|15|||||
|1800|0|||||
ZDP}
ZDT|1|2|15.0|20240302113000|21||
''';

void main() {
  const reader = Dl7Reader();

  group('Dl7Reader', () {
    test('parses header segments with tag at index 0', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.fshFields[0], 'FSH');
      expect(doc.fshFields[3], 'ZXU');
      expect(doc.zrhFields[0], 'ZRH');
      expect(doc.zrhFields[3], '13960');
      expect(doc.zrhFields[4], 'MSWG');
      expect(doc.zrhFields[7], 'BAR');
    });

    test('captures multi-line ZAR content between braces', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.zarContent, contains('<AQUALUNG>'));
      expect(doc.zarContent, contains('<DUID>7168_13960_20220224130600_1</DUID>'));
      expect(doc.zarContent, isNot(contains('ZDH')));
    });

    test('captures single-line ZAR content', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXU|20240501120000|\n'
        'ZAR{More Mobile Software, DiveLogDT, version 4.144}\n'
        'ZDH|1|1|I|Q1M|20240501100000|25|||\n'
        'ZDT|1|1|10.0|20240501100200|24||\n',
      );
      expect(doc.zarContent, 'More Mobile Software, DiveLogDT, version 4.144');
      expect(doc.dives, hasLength(1));
    });

    test('groups ZDH + ZDP rows + ZDT into one dive record', () {
      final doc = reader.read(_multiLineZar);
      expect(doc.dives, hasLength(1));
      final dive = doc.dives.first;
      expect(dive.zdhFields[5], '20220224130600');
      expect(dive.zdtFields[3], '15.54');
      expect(dive.zdpRows, hasLength(3));
      // Leading empty token removed: column 1 (time) is index 0.
      expect(dive.zdpRows[1][0], '0.50');
      expect(dive.zdpRows[1][1], '1.52');
      expect(dive.zdpRows[1][7], '27.2');
    });

    test('parses multiple dives, including profile-less dives', () {
      final doc = reader.read(_multiDiveNoZar);
      expect(doc.zarContent, isEmpty);
      expect(doc.dives, hasLength(2));
      expect(doc.dives[0].zdpRows, isEmpty);
      expect(doc.dives[0].zdtFields[3], '12.0');
      expect(doc.dives[1].zdpRows, hasLength(3));
      expect(doc.dives[1].zdpRows[1][0], '60');
    });

    test('tolerates CR-only line endings and a UTF-8 BOM', () {
      final crContent = _multiDiveNoZar.replaceAll('\n', '\r');
      final doc = reader.read('﻿$crContent');
      expect(doc.dives, hasLength(2));
    });

    test('emits a warning and keeps the dive when ZDT is missing at EOF', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXU|20240501120000|\n'
        'ZDH|1|1|I|Q1S|20240501100000|25|||\n'
        'ZDP{\n'
        '|0.00|0.00|1.00|\n'
        'ZDP}\n',
      );
      expect(doc.dives, hasLength(1));
      expect(doc.dives.first.zdtFields, isEmpty);
      expect(doc.readerWarnings, isNotEmpty);
    });

    test('ignores unknown segments (ZXL demographics) without error', () {
      final doc = reader.read(
        'FSH|^~<>{}|X^^|ZXL|20240501120000|\n'
        'ZPD|1|Jane Diver|\n'
        'ZDH|1|1|I|Q1S|20240501100000|25|||\n'
        'ZDT|1|1|9.0|20240501100500|24||\n',
      );
      expect(doc.dives, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/dl7/dl7_reader_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... dl7_reader.dart` (file does not exist yet).

- [ ] **Step 3: Write the implementation**

`lib/features/universal_import/data/parsers/dl7/dl7_document.dart`:

```dart
/// Typed model of a scanned DAN DL7 document.
///
/// Segment field lists keep the tag at index 0 so spec field numbering maps
/// directly to list indices (spec field N = index N). Profile rows have the
/// leading empty token (from the row's leading pipe) removed, so spec
/// column N = index N-1.
class Dl7Document {
  /// FSH file-header fields, empty when the segment is missing.
  final List<String> fshFields;

  /// ZRH record-header fields (units live here), empty when missing.
  final List<String> zrhFields;

  /// Raw text inside the first ZAR{...} block, empty string when absent.
  final String zarContent;

  /// One record per ZDH/ZDP/ZDT group, in file order.
  final List<Dl7DiveRecord> dives;

  /// Structural anomalies observed while scanning (missing ZDT, orphan
  /// segments). These become import warnings, not errors.
  final List<String> readerWarnings;

  const Dl7Document({
    this.fshFields = const [],
    this.zrhFields = const [],
    this.zarContent = '',
    this.dives = const [],
    this.readerWarnings = const [],
  });
}

/// One dive's segments: ZDH fields, profile rows, ZDT fields.
class Dl7DiveRecord {
  final List<String> zdhFields;
  final List<List<String>> zdpRows;

  /// Empty when the file ended before the dive's ZDT.
  final List<String> zdtFields;

  const Dl7DiveRecord({
    required this.zdhFields,
    this.zdpRows = const [],
    this.zdtFields = const [],
  });
}
```

`lib/features/universal_import/data/parsers/dl7/dl7_reader.dart`:

```dart
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_document.dart';

/// Scans DAN DL7 text into segments.
///
/// Tolerates CR, CRLF, and LF line endings (the 2006 spec mandates bare CR;
/// real exporters disagree), a UTF-8 BOM, single-line and multi-line ZAR
/// blocks, and unknown segments (ZXL demographics), which are skipped.
class Dl7Reader {
  const Dl7Reader();

  Dl7Document read(String content) {
    final warnings = <String>[];
    var fsh = const <String>[];
    var zrh = const <String>[];
    final zarLines = <String>[];
    final dives = <Dl7DiveRecord>[];

    List<String>? currentZdh;
    List<List<String>>? currentZdpRows;
    var inZdp = false;
    var inZar = false;

    void closeDive(List<String> zdtFields) {
      if (currentZdh == null) {
        warnings.add('ZDT segment without a preceding ZDH; ignored');
        return;
      }
      dives.add(
        Dl7DiveRecord(
          zdhFields: currentZdh!,
          zdpRows: currentZdpRows ?? const [],
          zdtFields: zdtFields,
        ),
      );
      currentZdh = null;
      currentZdpRows = null;
    }

    final stripped = content.startsWith('﻿') ? content.substring(1) : content;
    final lines = stripped.split(RegExp(r'\r\n|\r|\n'));

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (inZar) {
        if (line.trim() == '}') {
          inZar = false;
        } else {
          zarLines.add(line);
        }
        continue;
      }
      if (inZdp) {
        if (line.startsWith('ZDP}')) {
          inZdp = false;
        } else if (line.startsWith('|')) {
          // Drop the leading empty token so spec column N = index N-1.
          currentZdpRows?.add(line.split('|').sublist(1));
        }
        continue;
      }
      if (line.isEmpty) continue;

      if (line.startsWith('ZAR{')) {
        final rest = line.substring('ZAR{'.length);
        if (rest.endsWith('}')) {
          final inner = rest.substring(0, rest.length - 1);
          if (inner.isNotEmpty) zarLines.add(inner);
        } else {
          if (rest.isNotEmpty) zarLines.add(rest);
          inZar = true;
        }
      } else if (line.startsWith('ZDP{')) {
        if (currentZdh == null) {
          warnings.add('ZDP block without a preceding ZDH; ignored');
        } else {
          currentZdpRows ??= [];
          inZdp = true;
        }
      } else if (line.startsWith('FSH|')) {
        fsh = line.split('|');
      } else if (line.startsWith('ZRH|')) {
        zrh = line.split('|');
      } else if (line.startsWith('ZDH|')) {
        if (currentZdh != null) {
          warnings.add('ZDH without closing ZDT for the previous dive');
          closeDive(const []);
        }
        currentZdh = line.split('|');
        currentZdpRows = [];
      } else if (line.startsWith('ZDT|')) {
        closeDive(line.split('|'));
      }
      // Unknown segments (ZPD, ZPA, ZDD, ZSR, ...) are skipped by design.
    }

    if (currentZdh != null) {
      warnings.add('File ended before the last dive\'s ZDT segment');
      closeDive(const []);
    }

    return Dl7Document(
      fshFields: fsh,
      zrhFields: zrh,
      zarContent: zarLines.join('\n'),
      dives: dives,
      readerWarnings: warnings,
    );
  }
}
```

Note the `closeDive(const [])` call inside the missing-ZDT branch reuses `currentZdpRows` — the warning test asserts `zdtFields` is empty while the dive and its rows survive.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/dl7/dl7_reader_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/data/parsers/dl7/ test/features/universal_import/data/parsers/dl7/
git commit -m "feat(import): add DAN DL7 segment reader"
```

---

### Task 2: Dl7Units (ZRH unit conversions)

**Files:**
- Create: `lib/features/universal_import/data/parsers/dl7/dl7_units.dart`
- Test: `test/features/universal_import/data/parsers/dl7/dl7_units_test.dart`

**Interfaces:**
- Consumes: `zrhFields` from Task 1 (tag at index 0; field 4 depth unit, 6 temp, 7 pressure, 8 volume).
- Produces: `Dl7Units { bool depthIsFeet, tempIsFahrenheit, pressureIsPsi, volumeIsCubicFeet }` with `const Dl7Units({...})`, `factory Dl7Units.fromZrh(List<String> zrhFields)`, instance methods `double depthToMeters(double v)`, `double tempToCelsius(double v)`, `double pressureToBar(double v)`, and static consts `feetToMeters = 0.3048`, `psiToBar = 0.0689476`, `cubicFeetToLiters = 28.3168`. Tasks 3 and 4 depend on these exact names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

void main() {
  group('Dl7Units.fromZrh', () {
    test('parses a metric ZRH (real DiverLog+ header)', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~<>{}||13960|MSWG|ThM|C|BAR|L|'.split('|'),
      );
      expect(units.depthIsFeet, isFalse);
      expect(units.tempIsFahrenheit, isFalse);
      expect(units.pressureIsPsi, isFalse);
      expect(units.volumeIsCubicFeet, isFalse);
    });

    test('parses an imperial ZRH (spec-style header)', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~<>{}|NEM001|SC02201|FSWG|ThFt|F|PSIA|CF|'.split('|'),
      );
      expect(units.depthIsFeet, isTrue);
      expect(units.tempIsFahrenheit, isTrue);
      expect(units.pressureIsPsi, isTrue);
      expect(units.volumeIsCubicFeet, isTrue);
    });

    test('treats MFWG as metric and lowercase bar as bar', () {
      final units = Dl7Units.fromZrh(
        'ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|'.split('|'),
      );
      expect(units.depthIsFeet, isFalse);
      expect(units.pressureIsPsi, isFalse);
    });

    test('defaults to metric when ZRH is missing or short', () {
      final units = Dl7Units.fromZrh(const []);
      expect(units.depthIsFeet, isFalse);
      expect(units.tempIsFahrenheit, isFalse);
      expect(units.pressureIsPsi, isFalse);
      expect(units.volumeIsCubicFeet, isFalse);
    });
  });

  group('conversions', () {
    const imperial = Dl7Units(
      depthIsFeet: true,
      tempIsFahrenheit: true,
      pressureIsPsi: true,
      volumeIsCubicFeet: true,
    );
    const metric = Dl7Units();

    test('depth feet to meters', () {
      expect(imperial.depthToMeters(60), closeTo(18.288, 0.001));
      expect(metric.depthToMeters(18.3), 18.3);
    });

    test('temperature fahrenheit to celsius', () {
      expect(imperial.tempToCelsius(80), closeTo(26.667, 0.001));
      expect(imperial.tempToCelsius(32), closeTo(0.0, 0.0001));
      expect(metric.tempToCelsius(27.2), 27.2);
    });

    test('pressure psi to bar', () {
      expect(imperial.pressureToBar(3000), closeTo(206.843, 0.001));
      expect(metric.pressureToBar(200), 200);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/dl7/dl7_units_test.dart`
Expected: FAIL — package resolution error for `dl7_units.dart`.

- [ ] **Step 3: Write the implementation**

```dart
/// Unit declarations from a DL7 ZRH record header, with SI conversions.
///
/// ZRH fields (tag at index 0): 4 depth unit (MSWG/MFWG metric,
/// FSWG/FFWG feet), 6 temperature (C/F), 7 tank pressure (BAR/PSI/PSIA),
/// 8 tank volume (L/CF). Matching is case-insensitive and prefix-based
/// because real exporters vary the spelling (MSWG vs MFWG, BAR vs bar).
class Dl7Units {
  static const feetToMeters = 0.3048;
  static const psiToBar = 0.0689476;
  static const cubicFeetToLiters = 28.3168;

  final bool depthIsFeet;
  final bool tempIsFahrenheit;
  final bool pressureIsPsi;
  final bool volumeIsCubicFeet;

  const Dl7Units({
    this.depthIsFeet = false,
    this.tempIsFahrenheit = false,
    this.pressureIsPsi = false,
    this.volumeIsCubicFeet = false,
  });

  factory Dl7Units.fromZrh(List<String> zrhFields) {
    String field(int index) =>
        index < zrhFields.length ? zrhFields[index].trim().toUpperCase() : '';
    return Dl7Units(
      depthIsFeet: field(4).startsWith('F'),
      tempIsFahrenheit: field(6) == 'F',
      pressureIsPsi: field(7).startsWith('PSI'),
      volumeIsCubicFeet: field(8) == 'CF',
    );
  }

  double depthToMeters(double value) =>
      depthIsFeet ? value * feetToMeters : value;

  double tempToCelsius(double value) =>
      tempIsFahrenheit ? (value - 32) * 5 / 9 : value;

  double pressureToBar(double value) =>
      pressureIsPsi ? value * psiToBar : value;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/dl7/dl7_units_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/data/parsers/dl7/dl7_units.dart test/features/universal_import/data/parsers/dl7/dl7_units_test.dart
git commit -m "feat(import): add DL7 unit conversions"
```

---

### Task 3: AqualungZarDialect (DiverLog+ ZAR block)

**Files:**
- Create: `lib/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart`
- Test: `test/features/universal_import/data/parsers/dl7/aqualung_zar_dialect_test.dart`

**Interfaces:**
- Consumes: `zarContent` string from Task 1; `Dl7Units` from Task 2.
- Produces: `AqualungZarData` with nullable fields `String? app, duid, title, pdcModel, pdcSerial, pdcFirmware, locationName, city, stateProvince, country`, `int? rating, diveNumber, diveMode`, `double? latitude, longitude, maxDepthMeters, minTempCelsius, avgDepthMeters`, `Duration? elapsedDiveTime, surfaceInterval`, `List<AqualungZarTank> tanks`, `List<int> decoTimePerSample`; `AqualungZarTank { String? name; double? o2Percent, startPressureBar, endPressureBar, workingPressureBar, volumeLiters; }`. Entry point: `static AqualungZarData? AqualungZarDialect.parse(String zarContent, {Dl7Units units})` returning null when the block is not an `<AQUALUNG>` dialect. Task 4 depends on these exact names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

// Structure mirrors a real DiverLog+/DiveCloud export (values synthetic).
const _aqualungZar = '''
<AQUALUNG>
<APP>DiverLog+</APP>
<DUID>4321_98765_20240612093000_42</DUID>
<TITLE>Morning Reef Drift</TITLE>
<DIVE_DT>20240612093000</DIVE_DT>
<DIVE_MODE>0</DIVE_MODE>
<PDC_MODEL>I330R</PDC_MODEL>
<PDC_SERIAL>98765</PDC_SERIAL>
<MANUFACTURER>AQUALUNG</MANUFACTURER>
<PDC_FIRMWARE>1.003.000</PDC_FIRMWARE>
<DIVER_NAME>LASTNAME=[Test¶Diver]</DIVER_NAME>
<LOCATION>GPS=[20.877432,-156.679867],LOCNAME=[Molokini Crater],CITY=[Kihei],STATE/PROVINCE=[Hawaii],COUNTRY=[United States],MINTEMP=26.5</LOCATION>
<GEAR>GEAR_UNITS=0</GEAR>
<RATING>4</RATING>
<DIVESTATS>DIVENO=42,DATATYPE=8,DECO=N,VIOL=N,MODE=0,MANUALDIVE=0,EDT=000600,SI=010000,MAXDEPTH=18.2880,MAXO2=1,PO2=0.53,MINTEMP=26.5</DIVESTATS>
<TANK>NUMBER=1,TID=0,ON=N,CYLNAME=[AL80],CYLSIZE=80.0CU FT,WORKINGPRESSURE=3000PSI,STARTPRESSURE=3000,ENDPRESSURE=1800,FO2=32,AVGDEPTH=12.2,DIVETIME=6,SAC=0</TANK>
<DECOTIME>0,0,0,0,2,0,0,0,0,0,0,0</DECOTIME>
</AQUALUNG>''';

void main() {
  group('AqualungZarDialect.parse', () {
    test('returns null for a non-Aqualung ZAR block', () {
      expect(
        AqualungZarDialect.parse(
          'More Mobile Software, DiveLogDT, version 4.144',
        ),
        isNull,
      );
      expect(AqualungZarDialect.parse(''), isNull);
    });

    test('extracts identity, rating, title, and DUID', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.app, 'DiverLog+');
      expect(zar.duid, '4321_98765_20240612093000_42');
      expect(zar.title, 'Morning Reef Drift');
      expect(zar.rating, 4);
      expect(zar.diveMode, 0);
      expect(zar.pdcModel, 'I330R');
      expect(zar.pdcSerial, '98765');
      expect(zar.pdcFirmware, '1.003.000');
    });

    test('extracts location with bracket-aware GPS parsing', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.latitude, closeTo(20.877432, 1e-6));
      expect(zar.longitude, closeTo(-156.679867, 1e-6));
      expect(zar.locationName, 'Molokini Crater');
      expect(zar.city, 'Kihei');
      expect(zar.stateProvince, 'Hawaii');
      expect(zar.country, 'United States');
    });

    test('extracts dive stats with hhmmss durations', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.diveNumber, 42);
      expect(zar.elapsedDiveTime, const Duration(minutes: 6));
      expect(zar.surfaceInterval, const Duration(hours: 1));
      expect(zar.maxDepthMeters, closeTo(18.288, 0.001));
      expect(zar.minTempCelsius, closeTo(26.5, 0.001));
    });

    test('converts TANK pressures from PSI when GEAR_UNITS is imperial', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.tanks, hasLength(1));
      final tank = zar.tanks.first;
      expect(tank.name, 'AL80');
      expect(tank.o2Percent, 32.0);
      expect(tank.startPressureBar, closeTo(206.84, 0.01));
      expect(tank.endPressureBar, closeTo(124.11, 0.01));
      expect(tank.workingPressureBar, closeTo(206.84, 0.01));
      // 80 cu ft free gas at 206.84 bar working pressure ~= 10.95 L water
      // capacity (cuft * 28.3168 / workingPressureBar).
      expect(tank.volumeLiters, closeTo(10.95, 0.01));
    });

    test('treats zero tank pressures and sizes as absent', () {
      final zar = AqualungZarDialect.parse('''
<AQUALUNG>
<TANK>NUMBER=1,TID=0,ON=N,CYLNAME=[],CYLSIZE=0.0CU FT,WORKINGPRESSURE=0PSI,STARTPRESSURE=0,ENDPRESSURE=0,FO2=20,AVGDEPTH=9.1,DIVETIME=57,SAC=0</TANK>
</AQUALUNG>''')!;
      final tank = zar.tanks.first;
      expect(tank.o2Percent, 20.0);
      expect(tank.startPressureBar, isNull);
      expect(tank.endPressureBar, isNull);
      expect(tank.workingPressureBar, isNull);
      expect(tank.volumeLiters, isNull);
    });

    test('parses DECOTIME sample array', () {
      final zar = AqualungZarDialect.parse(_aqualungZar)!;
      expect(zar.decoTimePerSample, hasLength(12));
      expect(zar.decoTimePerSample[4], 2);
    });

    test('applies imperial ZRH units to depth and temperature stats', () {
      const imperialUnits = Dl7Units(depthIsFeet: true, tempIsFahrenheit: true);
      final zar = AqualungZarDialect.parse(
        '''
<AQUALUNG>
<DIVESTATS>DIVENO=7,EDT=001000,MAXDEPTH=60.0,MINTEMP=80.0</DIVESTATS>
</AQUALUNG>''',
        units: imperialUnits,
      )!;
      expect(zar.maxDepthMeters, closeTo(18.288, 0.001));
      expect(zar.minTempCelsius, closeTo(26.667, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/dl7/aqualung_zar_dialect_test.dart`
Expected: FAIL — package resolution error for `aqualung_zar_dialect.dart`.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';

/// One `<TANK>` entry from an Aqualung ZAR block, converted to SI.
class AqualungZarTank {
  final String? name;
  final double? o2Percent;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? workingPressureBar;
  final double? volumeLiters;

  const AqualungZarTank({
    this.name,
    this.o2Percent,
    this.startPressureBar,
    this.endPressureBar,
    this.workingPressureBar,
    this.volumeLiters,
  });
}

/// Structured data extracted from a `ZAR{<AQUALUNG>...}` block.
class AqualungZarData {
  final String? app;
  final String? duid;
  final String? title;
  final String? pdcModel;
  final String? pdcSerial;
  final String? pdcFirmware;
  final int? rating;
  final int? diveMode;
  final int? diveNumber;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? city;
  final String? stateProvince;
  final String? country;
  final Duration? elapsedDiveTime;
  final Duration? surfaceInterval;
  final double? maxDepthMeters;
  final double? minTempCelsius;
  final double? avgDepthMeters;
  final List<AqualungZarTank> tanks;
  final List<int> decoTimePerSample;

  const AqualungZarData({
    this.app,
    this.duid,
    this.title,
    this.pdcModel,
    this.pdcSerial,
    this.pdcFirmware,
    this.rating,
    this.diveMode,
    this.diveNumber,
    this.latitude,
    this.longitude,
    this.locationName,
    this.city,
    this.stateProvince,
    this.country,
    this.elapsedDiveTime,
    this.surfaceInterval,
    this.maxDepthMeters,
    this.minTempCelsius,
    this.avgDepthMeters,
    this.tanks = const [],
    this.decoTimePerSample = const [],
  });
}

/// Parses the DiverLog+/DiveCloud `<AQUALUNG>` ZAR dialect.
///
/// The block is pseudo-XML: `<TAG>payload</TAG>` lines where payloads are
/// comma-separated `KEY=value` pairs and values may be wrapped in square
/// brackets to escape embedded commas (`GPS=[lat,lon]`). Not parsed with an
/// XML parser on purpose — site names may contain unescaped ampersands.
/// Every field is optional; exporters drift (COUNTRY vs DIVESITE presence).
class AqualungZarDialect {
  AqualungZarDialect._();

  static final _tagPattern = RegExp(
    r'<([A-Z0-9_]+)>(.*?)</\1>',
    dotAll: true,
  );

  static AqualungZarData? parse(
    String zarContent, {
    Dl7Units units = const Dl7Units(),
  }) {
    if (!zarContent.contains('<AQUALUNG>')) return null;

    final tags = <String, List<String>>{};
    for (final match in _tagPattern.allMatches(zarContent)) {
      final name = match.group(1)!;
      if (name == 'AQUALUNG') continue;
      (tags[name] ??= []).add(match.group(2)!.trim());
    }

    String? text(String tag) {
      final value = tags[tag]?.first.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final gearUnitsImperial = _gearUnitsImperial(text('GEAR'));

    // LOCATION: GPS=[lat,lon],LOCNAME=[..],CITY=[..],STATE/PROVINCE=[..],...
    final location = parseKeyValues(text('LOCATION') ?? '');
    double? latitude;
    double? longitude;
    final gps = location['GPS'];
    if (gps != null) {
      final parts = gps.split(',');
      if (parts.length == 2) {
        latitude = double.tryParse(parts[0].trim());
        longitude = double.tryParse(parts[1].trim());
      }
    }

    final stats = parseKeyValues(text('DIVESTATS') ?? '');
    final statMaxDepth = double.tryParse(stats['MAXDEPTH'] ?? '');
    final statMinTemp =
        double.tryParse(stats['MINTEMP'] ?? '') ??
        double.tryParse(location['MINTEMP'] ?? '');
    final statAvgDepth = double.tryParse(stats['AVGDEPTH'] ?? '');

    final tanks = <AqualungZarTank>[];
    for (final tankText in tags['TANK'] ?? const <String>[]) {
      tanks.add(_parseTank(tankText, gearUnitsImperial: gearUnitsImperial));
    }

    return AqualungZarData(
      app: text('APP'),
      duid: text('DUID'),
      title: text('TITLE'),
      pdcModel: text('PDC_MODEL'),
      pdcSerial: text('PDC_SERIAL'),
      pdcFirmware: text('PDC_FIRMWARE'),
      rating: int.tryParse(text('RATING') ?? ''),
      diveMode: int.tryParse(text('DIVE_MODE') ?? ''),
      diveNumber: int.tryParse(stats['DIVENO'] ?? ''),
      latitude: latitude,
      longitude: longitude,
      locationName: _nonEmpty(location['LOCNAME'] ?? location['DIVESITE']),
      city: _nonEmpty(location['CITY']),
      stateProvince: _nonEmpty(location['STATE/PROVINCE']),
      country: _nonEmpty(location['COUNTRY']),
      elapsedDiveTime: _parseHhmmss(stats['EDT']),
      surfaceInterval: _parseHhmmss(stats['SI']),
      maxDepthMeters:
          statMaxDepth != null ? units.depthToMeters(statMaxDepth) : null,
      minTempCelsius:
          statMinTemp != null ? units.tempToCelsius(statMinTemp) : null,
      avgDepthMeters:
          statAvgDepth != null ? units.depthToMeters(statAvgDepth) : null,
      tanks: tanks,
      decoTimePerSample: _parseIntArray(text('DECOTIME')),
    );
  }

  /// Splits `KEY=value,KEY=value` where a value wrapped in `[...]` may
  /// contain commas. Bracket wrapping is stripped from returned values.
  static Map<String, String> parseKeyValues(String input) {
    final result = <String, String>{};
    if (input.isEmpty) return result;
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '[') {
        depth++;
      } else if (char == ']') {
        if (depth > 0) depth--;
      } else if (char == ',' && depth == 0) {
        parts.add(input.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(input.substring(start));
    for (final part in parts) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq).trim();
      var value = part.substring(eq + 1).trim();
      if (value.startsWith('[') && value.endsWith(']')) {
        value = value.substring(1, value.length - 1).trim();
      }
      result[key] = value;
    }
    return result;
  }

  static bool _gearUnitsImperial(String? gearText) {
    if (gearText == null) return false;
    final gear = parseKeyValues(gearText);
    // GEAR_UNITS=0 means imperial in DiverLog+ exports.
    return gear['GEAR_UNITS'] == '0';
  }

  static AqualungZarTank _parseTank(
    String tankText, {
    required bool gearUnitsImperial,
  }) {
    final kv = parseKeyValues(tankText);

    double? positiveOrNull(double? value) =>
        (value == null || value <= 0) ? null : value;

    // WORKINGPRESSURE/CYLSIZE carry their own unit suffix ('3000PSI',
    // '80.0CU FT'); STARTPRESSURE/ENDPRESSURE are bare numbers whose unit
    // follows GEAR_UNITS (0 = PSI, 1 = bar).
    final working = _numberWithSuffix(kv['WORKINGPRESSURE']);
    final workingIsPsi = working?.suffixContains('PSI') ?? gearUnitsImperial;
    final workingBar = positiveOrNull(
      working == null
          ? null
          : (workingIsPsi
                ? working.value * Dl7Units.psiToBar
                : working.value),
    );

    double? barePressureToBar(String? raw) {
      final value = positiveOrNull(double.tryParse(raw ?? ''));
      if (value == null) return null;
      return gearUnitsImperial ? value * Dl7Units.psiToBar : value;
    }

    final size = _numberWithSuffix(kv['CYLSIZE']);
    final sizeIsCuFt = size?.suffixContains('CU') ?? gearUnitsImperial;
    double? volumeLiters;
    final sizeValue = positiveOrNull(size?.value);
    if (sizeValue != null) {
      if (sizeIsCuFt) {
        // Cubic-foot cylinder sizes are free-gas capacity at working
        // pressure; water capacity needs the working pressure to convert.
        if (workingBar != null) {
          volumeLiters = sizeValue * Dl7Units.cubicFeetToLiters / workingBar;
        }
      } else {
        volumeLiters = sizeValue;
      }
    }

    return AqualungZarTank(
      name: _nonEmpty(kv['CYLNAME']),
      o2Percent: positiveOrNull(double.tryParse(kv['FO2'] ?? '')),
      startPressureBar: barePressureToBar(kv['STARTPRESSURE']),
      endPressureBar: barePressureToBar(kv['ENDPRESSURE']),
      workingPressureBar: workingBar,
      volumeLiters: volumeLiters,
    );
  }

  static ({double value, String suffix})? _numberWithSuffix(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*(.*)$').firstMatch(raw);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return (value: value, suffix: match.group(2)!.trim().toUpperCase());
  }

  static Duration? _parseHhmmss(String? raw) {
    final digits = raw?.trim();
    if (digits == null || !RegExp(r'^\d{6}$').hasMatch(digits)) return null;
    final result = Duration(
      hours: int.parse(digits.substring(0, 2)),
      minutes: int.parse(digits.substring(2, 4)),
      seconds: int.parse(digits.substring(4, 6)),
    );
    return result == Duration.zero ? null : result;
  }

  static List<int> _parseIntArray(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [
      for (final part in raw.split(','))
        if (int.tryParse(part.trim()) case final value?) value,
    ];
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
```

Add an extension for the record suffix check at the bottom of the same file:

```dart
extension on ({double value, String suffix}) {
  bool suffixContains(String needle) => suffix.contains(needle);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/dl7/aqualung_zar_dialect_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart test/features/universal_import/data/parsers/dl7/aqualung_zar_dialect_test.dart
git commit -m "feat(import): parse the DiverLog+ AQUALUNG ZAR dialect"
```

---

### Task 4: DanDl7Parser + synthetic fixtures

**Files:**
- Create: `lib/features/universal_import/data/parsers/dan_dl7_import_parser.dart`
- Create: `test/features/universal_import/data/parsers/fixtures/dl7/diverlog_plus_synthetic.zxu`
- Create: `test/features/universal_import/data/parsers/fixtures/dl7/dl7_multi_dive_seconds.zxu`
- Create: `test/features/universal_import/data/parsers/fixtures/dl7/dl7_imperial.zxu`
- Create: `test/features/universal_import/data/parsers/fixtures/dl7/divelogdt_zar.zxu`
- Test: `test/features/universal_import/data/parsers/dan_dl7_import_parser_test.dart`

**Interfaces:**
- Consumes: `Dl7Reader`/`Dl7Document` (Task 1), `Dl7Units` (Task 2), `AqualungZarDialect`/`AqualungZarData` (Task 3), and the existing `ImportParser`, `ImportPayload`, `ImportOptions`, `ImportWarning`, `ImportEntityType`, `GasMix` types.
- Produces: `class DanDl7Parser implements ImportParser` with `const DanDl7Parser()`, `supportedFormats => [ImportFormat.danDl7]`. Emits dive maps with the `UddfEntityImporter` keys: `dateTime` (DateTime), `runtime`/`duration` (Duration), `maxDepth`/`avgDepth`/`waterTemp`/`airTemp` (double, SI), `surfaceInterval` (Duration), `diveNumber`/`rating` (int), `name`/`notes` (String), `sourceUuid`, `diveComputerModel`/`diveComputerSerial`/`diveComputerFirmware` (String), `diveMode` (String 'oc'), `latitude`/`longitude` (double), `site` (`{'uddfId': ...}`), `profile` (list of point maps: `timestamp` int seconds, `depth`, `temperature?`, `ceiling?`, `cns?`, `decoType?`, `allTankPressures?`), `tanks` (list: `gasMix` GasMix, `startPressure?`, `endPressure?`, `workingPressure?`, `volume?`, `name?`, `order`, `uddfTankId`), `gasSwitches` (list: `timestamp`, `tankRef`), `events` (list: `eventType`, `timestamp`). Site entities: `uddfId`, `name`, `latitude?`, `longitude?`, `country?`, `region?`, `notes?`. Tasks 5–6 depend on the class name and file path; Task 12 depends on the fixture paths.

**Fixture note:** research artifacts (a real i330R export, the DL7 spec text, reference parsers) sit UNTRACKED under `test/features/universal_import/data/parsers/fixtures/dl7/` (`diverlog_real.zxu`, `DL7.zxu`, `pydl7_sample.zxu`, `research/`). Do NOT `git add` them — provenance/licensing is unverified (sources: vche/divelog_convert, Subsurface, PyDL7 — URLs in the spec's References). The four fixtures below are synthetic, written by us, and safe to commit. `git add` the four new fixture files EXPLICITLY BY NAME, never the fixtures directory.

- [ ] **Step 1: Write the four fixture files**

`test/features/universal_import/data/parsers/fixtures/dl7/diverlog_plus_synthetic.zxu` — DiverLog+/DiveCloud shape: metric, decimal-minute times at 30 s spacing (ZDH falsely declares Q1S), sparse temps, one ascent violation, bogus ZDT min temp, full AQUALUNG ZAR:

```
FSH|^~<>{}|OCI201^^|ZXU|20240613080000|
ZRH|^~<>{}||98765|MSWG|ThM|C|BAR|L|
ZAR{
<AQUALUNG>
<APP>DiverLog+</APP>
<DUID>4321_98765_20240612093000_42</DUID>
<TITLE>Morning Reef Drift</TITLE>
<DIVE_DT>20240612093000</DIVE_DT>
<FILE_DT>2024-06-13 08:00:00</FILE_DT>
<DIVE_MODE>0</DIVE_MODE>
<PDC_MODEL>I330R</PDC_MODEL>
<PDC_SERIAL>98765</PDC_SERIAL>
<MANUFACTURER>AQUALUNG</MANUFACTURER>
<PDC_FIRMWARE>1.003.000</PDC_FIRMWARE>
<DIVER_NAME>LASTNAME=[Test¶Diver]</DIVER_NAME>
<LOCATION>GPS=[20.877432,-156.679867],LOCNAME=[Molokini Crater],CITY=[Kihei],STATE/PROVINCE=[Hawaii],COUNTRY=[United States],MINTEMP=26.5</LOCATION>
<GEAR>GEAR_UNITS=0</GEAR>
<RATING>4</RATING>
<DIVESTATS>DIVENO=42,DATATYPE=8,DECO=N,VIOL=N,MODE=0,MANUALDIVE=0,EDT=000600,SI=010000,MAXDEPTH=18.2880,MAXO2=1,PO2=0.53,MINTEMP=26.5</DIVESTATS>
<TANK>NUMBER=1,TID=0,ON=N,CYLNAME=[AL80],CYLSIZE=80.0CU FT,WORKINGPRESSURE=3000PSI,STARTPRESSURE=3000,ENDPRESSURE=1800,FO2=32,AVGDEPTH=12.2,DIVETIME=6,SAC=0</TANK>
<DECOTIME>0,0,0,0,2,0,0,0,0,0,0,0</DECOTIME>
</AQUALUNG>
}
ZDH|1|1|I|Q1S|20240612093000|28.0||FO2|
ZDP{
|0.00|0.00|1.00|
|0.50|5.2|||||||||
|1.00|9.8||||||27.0|||
|1.50|14.6|||||||||
|2.00|18.3|||||||||
|2.50|17.9|||||||||
|3.00|16.2|||||||||
|3.50|12.4||||||26.5|||
|4.00|9.1|||||||||
|4.50|6.0|||T||||||
|5.00|3.2|||||||||
|5.50|1.0|||||||||
ZDP}
ZDT|1|1|18.29|20240612093600|0.000000|0|
```

`test/features/universal_import/data/parsers/fixtures/dl7/dl7_multi_dive_seconds.zxu` — three dives, integer-second times, `^~\&{}` encoding chars, `MFWG` depth unit, dives 1 and 3 profile-less (dive 1 manually logged):

```
FSH|^~\&{}|ANST01^12X456^A|ZXU|20240310120000|
ZRH|^~\&{}|||MFWG|ThM|C|bar|L|
ZDH|1|1|M|QS|20240301100000|22|||
ZDT|1|1|12.0|20240301102500|21||
ZDH|2|2|I|V|20240302110000|24|||
ZDP{
|0|0|1||||
|60|15|||||
|1500|15|||||
|1800|0|||||
ZDP}
ZDT|1|2|15.0|20240302113000|21||
ZDH|3|3|I|QS|20240303090000|23|||
ZDT|1|3|8.5|20240303091000|22||
```

`test/features/universal_import/data/parsers/fixtures/dl7/dl7_imperial.zxu` — imperial units throughout (FSWG/ThFt/F/PSIA/CF), temperature and tank pressure columns in the profile, no ZAR:

```
FSH|^~<>{}|OCI201^^|ZXU|20240402090000|
ZRH|^~<>{}|NEM001|SC02201|FSWG|ThFt|F|PSIA|CF|
ZDH|1|7|I|Q1M|20240401140000|85|||
ZDP{
|0.00|0.0|1.00|
|1.00|30.0||||||||2800|
|2.00|60.0||||||80||2750|
|3.00|45.0||||||||2500|
ZDP}
ZDT|1|7|60.0|20240401140300|75||
```

`test/features/universal_import/data/parsers/fixtures/dl7/divelogdt_zar.zxu` — single-line non-Aqualung ZAR (DiveLogDT style):

```
FSH|^~\&{}|DLDT01^^|ZXU|20240501120000|
ZRH|^~\&{}||SN123|MSWG|ThM|C|BAR|L|
ZAR{More Mobile Software, DiveLogDT, version 4.144}
ZDH|1|1|I|Q1M|20240501100000|25|||
ZDP{
|0.00|0.0|1.00|
|1.00|10.0||||||24.0|||
|2.00|0.5|||||||||
ZDP}
ZDT|1|1|10.0|20240501100200|24||
```

- [ ] **Step 2: Write the failing test**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

const _fixtureDir = 'test/features/universal_import/data/parsers/fixtures/dl7';

Future<List<int>> _fixture(String name) =>
    File('$_fixtureDir/$name').readAsBytes();

void main() {
  const parser = DanDl7Parser();

  group('DanDl7Parser — DiverLog+ synthetic (metric, AQUALUNG ZAR)', () {
    late Map<String, dynamic> dive;
    late List<Map<String, dynamic>> sites;

    setUpAll(() async {
      final bytes = await _fixture('diverlog_plus_synthetic.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dives = payload.entitiesOf(ImportEntityType.dives);
      sites = payload.entitiesOf(ImportEntityType.sites);
      expect(dives, hasLength(1));
      dive = dives.first;
    });

    test('core dive fields from ZDH/ZAR', () {
      expect(dive['dateTime'], DateTime.utc(2024, 6, 12, 9, 30));
      expect(dive['runtime'], const Duration(minutes: 6));
      expect(dive['maxDepth'], closeTo(18.288, 0.001));
      expect(dive['airTemp'], closeTo(28.0, 0.001));
      expect(dive['surfaceInterval'], const Duration(hours: 1));
      expect(dive['diveNumber'], 42);
      expect(dive['rating'], 4);
      expect(dive['name'], 'Morning Reef Drift');
      expect(dive['diveMode'], 'oc');
    });

    test('DUID becomes sourceUuid; PDC identity mapped', () {
      expect(dive['sourceUuid'], '4321_98765_20240612093000_42');
      expect(dive['diveComputerModel'], 'I330R');
      expect(dive['diveComputerSerial'], '98765');
      expect(dive['diveComputerFirmware'], '1.003.000');
    });

    test('min temp comes from ZAR, never the bogus ZDT field', () {
      expect(dive['waterTemp'], closeTo(26.5, 0.001));
    });

    test('profile: interval derived from decimal-minute time column', () {
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile, hasLength(12));
      expect(profile[0]['timestamp'], 0);
      expect(profile[1]['timestamp'], 30);
      expect(profile[11]['timestamp'], 330);
      expect(profile[1]['depth'], closeTo(5.2, 0.001));
      expect(profile[2]['temperature'], closeTo(27.0, 0.001));
      expect(profile[3]['temperature'], isNull);
      expect(profile[4]['decoType'], 2);
    });

    test('ascent violation column becomes an event', () {
      final events = dive['events'] as List<Map<String, dynamic>>;
      expect(
        events,
        contains(
          predicate<Map<String, dynamic>>(
            (e) =>
                e['eventType'] == 'ascentRateWarning' && e['timestamp'] == 270,
          ),
        ),
      );
    });

    test('ZAR tank with PSI pressures converts to bar', () {
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      final tank = tanks.first;
      expect((tank['gasMix'] as GasMix).o2, 32.0);
      expect(tank['startPressure'], closeTo(206.84, 0.01));
      expect(tank['endPressure'], closeTo(124.11, 0.01));
      expect(tank['workingPressure'], closeTo(206.84, 0.01));
      expect(tank['volume'], closeTo(10.95, 0.01));
      expect(tank['name'], 'AL80');
    });

    test('site entity carries GPS and geography; dive links to it', () {
      expect(sites, hasLength(1));
      final site = sites.first;
      expect(site['name'], 'Molokini Crater');
      expect(site['latitude'], closeTo(20.877432, 1e-6));
      expect(site['longitude'], closeTo(-156.679867, 1e-6));
      expect(site['country'], 'United States');
      expect(site['region'], 'Hawaii');
      expect(
        (dive['site'] as Map<String, dynamic>)['uddfId'],
        site['uddfId'],
      );
      expect(dive['latitude'], closeTo(20.877432, 1e-6));
      expect(dive['longitude'], closeTo(-156.679867, 1e-6));
    });
  });

  group('DanDl7Parser — multi-dive seconds fixture', () {
    test('parses three dives; integer time column read as seconds', () async {
      final bytes = await _fixture('dl7_multi_dive_seconds.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(3));

      final manual = dives[0];
      expect(manual['dateTime'], DateTime.utc(2024, 3, 1, 10));
      expect(manual['profile'], isNull);
      // Runtime falls back to the ZDT surface timestamp delta.
      expect(manual['runtime'], const Duration(minutes: 25));
      expect(manual['duration'], const Duration(minutes: 25));
      expect(manual['maxDepth'], closeTo(12.0, 0.001));
      // With no ZAR and no profile, a positive ZDT min temp is used.
      expect(manual['waterTemp'], closeTo(21.0, 0.001));

      final profiled = dives[1];
      final profile = profiled['profile'] as List<Map<String, dynamic>>;
      expect(profile, hasLength(4));
      expect(profile[1]['timestamp'], 60);
      expect(profile[2]['timestamp'], 1500);
      expect(profile[1]['depth'], closeTo(15.0, 0.001));
      // Dives with a profile leave 'duration' unset so bottom time is
      // derived from the profile by the entity importer.
      expect(profiled['duration'], isNull);
      expect(profiled['runtime'], const Duration(minutes: 30));
    });
  });

  group('DanDl7Parser — imperial fixture', () {
    test('converts feet, fahrenheit, and PSIA to SI', () async {
      final bytes = await _fixture('dl7_imperial.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dive = payload.entitiesOf(ImportEntityType.dives).single;

      expect(dive['maxDepth'], closeTo(18.288, 0.001));
      expect(dive['airTemp'], closeTo(29.444, 0.001));

      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[1]['timestamp'], 60);
      expect(profile[2]['depth'], closeTo(18.288, 0.001));
      expect(profile[2]['temperature'], closeTo(26.667, 0.001));
      // Water temp = profile minimum when ZAR is absent.
      expect(dive['waterTemp'], closeTo(26.667, 0.001));

      final pressures =
          profile[1]['allTankPressures'] as List<Map<String, dynamic>>;
      expect(pressures.single['pressure'], closeTo(193.05, 0.01));
      expect(pressures.single['tankIndex'], 0);

      // No ZAR: one tank synthesized from the profile's gas column (air).
      final tanks = dive['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      expect((tanks.first['gasMix'] as GasMix).o2, 21.0);
      expect(tanks.first.containsKey('startPressure'), isFalse);
    });
  });

  group('DanDl7Parser — non-Aqualung ZAR', () {
    test('imports standard segments and ignores the foreign ZAR', () async {
      final bytes = await _fixture('divelogdt_zar.zxu');
      final payload = await parser.parse(Uint8List.fromList(bytes));
      final dive = payload.entitiesOf(ImportEntityType.dives).single;
      expect(dive['sourceUuid'], isNull);
      expect(dive.containsKey('site'), isFalse);
      expect(dive['maxDepth'], closeTo(10.0, 0.001));
      expect((dive['profile'] as List), hasLength(3));
    });
  });

  group('DanDl7Parser — error handling', () {
    test('empty file produces an error warning, no entities', () async {
      final payload = await parser.parse(Uint8List(0));
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });

    test('file with no dives produces an error warning', () async {
      final payload = await parser.parse(
        Uint8List.fromList('FSH|^~<>{}|X^^|ZXU|20240501120000|\n'.codeUnits),
      );
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/dan_dl7_import_parser_test.dart`
Expected: FAIL — package resolution error for `dan_dl7_import_parser.dart`.

- [ ] **Step 4: Write the implementation**

Write `lib/features/universal_import/data/parsers/dan_dl7_import_parser.dart` as the following complete listing:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/aqualung_zar_dialect.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_document.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_reader.dart';
import 'package:submersion/features/universal_import/data/parsers/dl7/dl7_units.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for DAN DL7 (.zxu/.zxl) dive log files.
///
/// Handles any spec-conformant DL7 file via the standard segments and
/// enriches the result with the proprietary `ZAR{<AQUALUNG>...}` block that
/// DiverLog+/DiveCloud exports carry (site, GPS, tanks, dive stats, rating,
/// computer identity). Foreign ZAR dialects are ignored.
///
/// Known real-file quirks handled here: the ZDH recording-interval field
/// lies (interval is derived from the time column), the ZDT min-temperature
/// field is written as 0.000000 (min temp comes from ZAR stats or the
/// profile), and the ZRH model code is often empty (model comes from ZAR).
class DanDl7Parser implements ImportParser {
  const DanDl7Parser();

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.danDl7];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final warnings = <ImportWarning>[];
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};

    if (fileBytes.isEmpty) {
      return ImportPayload(
        entities: entities,
        warnings: const [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
        metadata: const {'source': 'dan_dl7'},
      );
    }

    final content = utf8.decode(fileBytes, allowMalformed: true);
    final doc = const Dl7Reader().read(content);

    for (final readerWarning in doc.readerWarnings) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: readerWarning,
        ),
      );
    }

    if (doc.dives.isEmpty) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'No dives found in DL7 file',
        ),
      );
      return ImportPayload(
        entities: entities,
        warnings: warnings,
        metadata: const {'source': 'dan_dl7'},
      );
    }

    final units = Dl7Units.fromZrh(doc.zrhFields);
    final zar = AqualungZarDialect.parse(doc.zarContent, units: units);

    final dives = <Map<String, dynamic>>[];
    final sitesByUddfId = <String, Map<String, dynamic>>{};

    for (var i = 0; i < doc.dives.length; i++) {
      try {
        final dive = _parseDive(
          doc.dives[i],
          units: units,
          // A ZAR block describes the dive it was exported with. DiveCloud
          // files are single-dive; for multi-dive files only apply ZAR
          // enrichment when the file holds exactly one dive.
          zar: doc.dives.length == 1 ? zar : null,
          zrhFields: doc.zrhFields,
          sitesByUddfId: sitesByUddfId,
        );
        if (dive != null) dives.add(dive);
      } catch (e) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Skipped dive ${i + 1}: $e',
            entityType: ImportEntityType.dives,
            itemIndex: i,
          ),
        );
      }
    }

    if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
    if (sitesByUddfId.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByUddfId.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {'source': 'dan_dl7', if (zar?.app != null) 'app': zar!.app},
    );
  }

  Map<String, dynamic>? _parseDive(
    Dl7DiveRecord record, {
    required Dl7Units units,
    required AqualungZarData? zar,
    required List<String> zrhFields,
    required Map<String, Map<String, dynamic>> sitesByUddfId,
  }) {
    String? zdh(int field) =>
        field < record.zdhFields.length && record.zdhFields[field].trim().isNotEmpty
            ? record.zdhFields[field].trim()
            : null;
    String? zdt(int field) =>
        field < record.zdtFields.length && record.zdtFields[field].trim().isNotEmpty
            ? record.zdtFields[field].trim()
            : null;
    String? zrh(int field) =>
        field < zrhFields.length && zrhFields[field].trim().isNotEmpty
            ? zrhFields[field].trim()
            : null;

    final start = _parseDl7Timestamp(zdh(5));
    if (start == null) return null;

    final result = <String, dynamic>{'dateTime': start};

    final airTemp = double.tryParse(zdh(6) ?? '');
    if (airTemp != null) result['airTemp'] = units.tempToCelsius(airTemp);

    final profile = _parseProfile(record.zdpRows, units, zar);
    if (profile.isNotEmpty) result['profile'] = profile;

    final events = _parseViolationEvents(record.zdpRows, profile);
    if (events.isNotEmpty) result['events'] = events;

    final end = _parseDl7Timestamp(zdt(4));
    Duration? runtime = zar?.elapsedDiveTime;
    if (runtime == null && end != null && end.isAfter(start)) {
      runtime = end.difference(start);
    }
    if (runtime == null && profile.isNotEmpty) {
      runtime = Duration(seconds: profile.last['timestamp'] as int);
    }
    if (runtime != null) {
      result['runtime'] = runtime;
      if (profile.isEmpty) result['duration'] = runtime;
    }

    final zdtMaxDepth = double.tryParse(zdt(3) ?? '');
    final maxDepth =
        zar?.maxDepthMeters ??
        (zdtMaxDepth != null ? units.depthToMeters(zdtMaxDepth) : null);
    if (maxDepth != null) result['maxDepth'] = maxDepth;
    if (zar?.avgDepthMeters != null) result['avgDepth'] = zar!.avgDepthMeters;

    // Water temp preference: ZAR stats, profile minimum, positive ZDT value.
    double? waterTemp = zar?.minTempCelsius;
    if (waterTemp == null && profile.isNotEmpty) {
      for (final point in profile) {
        final temp = point['temperature'] as double?;
        if (temp != null && (waterTemp == null || temp < waterTemp)) {
          waterTemp = temp;
        }
      }
    }
    if (waterTemp == null) {
      final zdtMinTemp = double.tryParse(zdt(5) ?? '');
      if (zdtMinTemp != null && zdtMinTemp > 0) {
        waterTemp = units.tempToCelsius(zdtMinTemp);
      }
    }
    if (waterTemp != null) result['waterTemp'] = waterTemp;

    final diveNumber = zar?.diveNumber ?? int.tryParse(zdh(2) ?? '');
    if (diveNumber != null) result['diveNumber'] = diveNumber;

    final tanks = _buildTanks(record.zdpRows, zar);
    if (tanks.isNotEmpty) result['tanks'] = tanks;
    final gasSwitches = _parseGasSwitches(record.zdpRows, profile, tanks);
    if (gasSwitches.isNotEmpty) result['gasSwitches'] = gasSwitches;

    if (zar != null) {
      if (zar.duid != null) result['sourceUuid'] = zar.duid;
      if (zar.rating != null) result['rating'] = zar.rating;
      if (zar.surfaceInterval != null) {
        result['surfaceInterval'] = zar.surfaceInterval;
      }
      final title = zar.title?.trim();
      if (title != null && title.isNotEmpty) result['name'] = title;
      if (zar.diveMode == 0) result['diveMode'] = 'oc';
      if (zar.latitude != null && zar.longitude != null) {
        result['latitude'] = zar.latitude;
        result['longitude'] = zar.longitude;
      }
      final siteName = zar.locationName;
      if (siteName != null) {
        final siteId = 'dl7_site_${siteName.toLowerCase()}';
        sitesByUddfId.putIfAbsent(siteId, () {
          final site = <String, dynamic>{'uddfId': siteId, 'name': siteName};
          if (zar.latitude != null) site['latitude'] = zar.latitude;
          if (zar.longitude != null) site['longitude'] = zar.longitude;
          if (zar.country != null) site['country'] = zar.country;
          if (zar.stateProvince != null) site['region'] = zar.stateProvince;
          if (zar.city != null) site['notes'] = 'City: ${zar.city}';
          return site;
        });
        result['site'] = {'uddfId': siteId};
      }
    }

    // Computer identity: ZAR wins, ZRH header fields are the fallback
    // (field 2 model code, field 3 serial).
    final model = zar?.pdcModel ?? zrh(2);
    if (model != null) result['diveComputerModel'] = model;
    final serial = zar?.pdcSerial ?? zrh(3);
    if (serial != null) result['diveComputerSerial'] = serial;
    if (zar?.pdcFirmware != null) {
      result['diveComputerFirmware'] = zar!.pdcFirmware;
    }

    return result;
  }

  /// ZDP columns after the reader drops the leading empty token:
  /// index 0 time, 1 depth, 2 gas switch, 3 PO2, 4 ascent-violation,
  /// 5 deco-violation, 6 ceiling, 7 temperature, 8 warnings,
  /// 9 main tank pressure, 12 CNS.
  List<Map<String, dynamic>> _parseProfile(
    List<List<String>> rows,
    Dl7Units units,
    AqualungZarData? zar,
  ) {
    if (rows.isEmpty) return const [];
    final timesAreDecimalMinutes = rows.any(
      (row) => row.isNotEmpty && row[0].contains('.'),
    );

    final points = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      String? cell(int index) =>
          index < row.length && row[index].trim().isNotEmpty
              ? row[index].trim()
              : null;

      final rawTime = double.tryParse(cell(0) ?? '');
      final rawDepth = double.tryParse(cell(1) ?? '');
      if (rawTime == null || rawDepth == null) continue;

      final timestamp = timesAreDecimalMinutes
          ? (rawTime * 60).round()
          : rawTime.round();
      final point = <String, dynamic>{
        'timestamp': timestamp,
        'depth': units.depthToMeters(rawDepth),
      };

      final temp = double.tryParse(cell(7) ?? '');
      if (temp != null) point['temperature'] = units.tempToCelsius(temp);

      final ceiling = double.tryParse(cell(6) ?? '');
      if (ceiling != null) point['ceiling'] = units.depthToMeters(ceiling);

      final cns = double.tryParse(cell(12) ?? '');
      if (cns != null) point['cns'] = cns;

      final pressure = double.tryParse(cell(9) ?? '');
      if (pressure != null) {
        point['allTankPressures'] = [
          {'pressure': units.pressureToBar(pressure), 'tankIndex': 0},
        ];
      }

      // ZAR DECOTIME array is index-aligned with ZDP samples; a positive
      // value means the diver is in deco at that sample.
      final decoTimes = zar?.decoTimePerSample ?? const [];
      if (i < decoTimes.length && decoTimes[i] > 0) point['decoType'] = 2;

      points.add(point);
    }
    return points;
  }

  /// Column 4 ascent-violation and column 5 deco-violation flags ('T')
  /// become profile events at the sample's timestamp.
  List<Map<String, dynamic>> _parseViolationEvents(
    List<List<String>> rows,
    List<Map<String, dynamic>> profile,
  ) {
    if (rows.isEmpty || profile.isEmpty) return const [];
    final events = <Map<String, dynamic>>[];
    var pointIndex = 0;
    for (final row in rows) {
      final rawTime = row.isNotEmpty ? double.tryParse(row[0].trim()) : null;
      final rawDepth = row.length > 1 ? double.tryParse(row[1].trim()) : null;
      if (rawTime == null || rawDepth == null) continue;
      final timestamp = profile[pointIndex]['timestamp'] as int;
      String flag(int index) =>
          index < row.length ? row[index].trim().toUpperCase() : '';
      if (flag(4) == 'T') {
        events.add({'eventType': 'ascentRateWarning', 'timestamp': timestamp});
      }
      if (flag(5) == 'T') {
        events.add({'eventType': 'decoViolation', 'timestamp': timestamp});
      }
      pointIndex++;
    }
    return events;
  }

  /// Tanks come from the ZAR TANK entries when present; otherwise one tank
  /// is synthesized per distinct gas value in ZDP column 3 (`1` = air,
  /// `2.xy` = nitrox with xy% O2).
  List<Map<String, dynamic>> _buildTanks(
    List<List<String>> rows,
    AqualungZarData? zar,
  ) {
    if (zar != null && zar.tanks.isNotEmpty) {
      final tanks = <Map<String, dynamic>>[];
      for (var i = 0; i < zar.tanks.length; i++) {
        final zarTank = zar.tanks[i];
        final o2 = zarTank.o2Percent ?? 21.0;
        final tank = <String, dynamic>{
          'gasMix': GasMix(o2: o2, he: 0.0),
          'order': i,
          'uddfTankId': _tankRef(i, o2),
        };
        if (zarTank.name != null) tank['name'] = zarTank.name;
        if (zarTank.startPressureBar != null) {
          tank['startPressure'] = zarTank.startPressureBar;
        }
        if (zarTank.endPressureBar != null) {
          tank['endPressure'] = zarTank.endPressureBar;
        }
        if (zarTank.workingPressureBar != null) {
          tank['workingPressure'] = zarTank.workingPressureBar;
        }
        if (zarTank.volumeLiters != null) {
          tank['volume'] = zarTank.volumeLiters;
        }
        tanks.add(tank);
      }
      return tanks;
    }

    final o2Values = <double>[];
    for (final row in rows) {
      final o2 = _gasCellToO2Percent(row.length > 2 ? row[2].trim() : '');
      if (o2 != null && !o2Values.contains(o2)) o2Values.add(o2);
    }
    return [
      for (var i = 0; i < o2Values.length; i++)
        {
          'gasMix': GasMix(o2: o2Values[i], he: 0.0),
          'order': i,
          'uddfTankId': _tankRef(i, o2Values[i]),
        },
    ];
  }

  /// Gas-switch events: a non-empty gas cell after t=0 that differs from the
  /// previous gas becomes a switch referencing the matching tank.
  List<Map<String, dynamic>> _parseGasSwitches(
    List<List<String>> rows,
    List<Map<String, dynamic>> profile,
    List<Map<String, dynamic>> tanks,
  ) {
    if (rows.isEmpty || profile.isEmpty || tanks.isEmpty) return const [];
    final switches = <Map<String, dynamic>>[];
    double? currentO2;
    var pointIndex = 0;
    for (final row in rows) {
      final rawTime = row.isNotEmpty ? double.tryParse(row[0].trim()) : null;
      final rawDepth = row.length > 1 ? double.tryParse(row[1].trim()) : null;
      if (rawTime == null || rawDepth == null) continue;
      final o2 = _gasCellToO2Percent(row.length > 2 ? row[2].trim() : '');
      if (o2 != null) {
        final timestamp = profile[pointIndex]['timestamp'] as int;
        if (currentO2 != null && o2 != currentO2 && timestamp > 0) {
          final tankIndex = tanks.indexWhere(
            (t) => (t['gasMix'] as GasMix).o2 == o2,
          );
          if (tankIndex >= 0) {
            switches.add({
              'timestamp': timestamp,
              'tankRef': tanks[tankIndex]['uddfTankId'],
            });
          }
        }
        currentO2 = o2;
      }
      pointIndex++;
    }
    return switches;
  }

  static String _tankRef(int index, double o2) =>
      'dl7:$index:o2_${o2.round()}';

  /// `1` (or `1.00`) = air (21% O2); `2.xy` = nitrox with xy% O2.
  static double? _gasCellToO2Percent(String cell) {
    if (cell.isEmpty) return null;
    final value = double.tryParse(cell);
    if (value == null) return null;
    if (value >= 1.0 && value < 2.0) return 21.0;
    if (value >= 2.0 && value < 3.0) {
      final o2 = ((value - 2.0) * 100).round().toDouble();
      return o2 > 0 ? o2 : 21.0;
    }
    return null;
  }

  /// Parses YYYYMMDDHHMMSS (seconds optional) as wall-clock UTC, ignoring
  /// any timezone suffix per the house dive-time convention.
  static DateTime? _parseDl7Timestamp(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 12) return null;
    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));
    final hour = int.tryParse(digits.substring(8, 10));
    final minute = int.tryParse(digits.substring(10, 12));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    final second = digits.length >= 14
        ? int.tryParse(digits.substring(12, 14)) ?? 0
        : 0;
    return DateTime.utc(year, month, day, hour, minute, second);
  }
}
```

(Only the second, complete listing goes in the file. The first fragment above documents the parsing flow and must not be pasted.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/dan_dl7_import_parser_test.dart`
Expected: PASS (all groups). If the multi-dive fixture's dive 2 runtime assertion fails, check that `_parseDl7Timestamp` handles the ZDT end timestamp `20240302113000` (30 minutes after start).

- [ ] **Step 6: Format and commit (fixtures added BY NAME — untracked research files must not be committed)**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/data/parsers/dan_dl7_import_parser.dart \
  test/features/universal_import/data/parsers/dan_dl7_import_parser_test.dart \
  test/features/universal_import/data/parsers/fixtures/dl7/diverlog_plus_synthetic.zxu \
  test/features/universal_import/data/parsers/fixtures/dl7/dl7_multi_dive_seconds.zxu \
  test/features/universal_import/data/parsers/fixtures/dl7/dl7_imperial.zxu \
  test/features/universal_import/data/parsers/fixtures/dl7/divelogdt_zar.zxu
git status --short   # verify diverlog_real.zxu, DL7.zxu, pydl7_sample.zxu, research/ remain untracked
git commit -m "feat(import): DAN DL7 parser with Aqualung ZAR enrichment"
```

---

### Task 5: Format wiring (enum, detector, registry, folder scan)

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart`
- Modify: `lib/features/universal_import/data/services/format_detector.dart`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Modify: `lib/features/universal_import/data/services/batch_parse_service.dart` (importableExtensions)
- Test: `test/features/universal_import/data/services/format_detector_test.dart` (extend)
- Test: `test/features/universal_import/data/models/import_enums_test.dart` (extend/update)

**Interfaces:**
- Consumes: `DanDl7Parser` (Task 4).
- Produces: `ImportFormat.danDl7.isSupported == true`; `SourceApp.diverLog` (displayName `'DiverLog+'`, non-null `exportInstructions`); detector returns `danDl7` for `FSH|`-prefixed text with `SourceApp.diverLog` when `<AQUALUNG>` is present, `SourceApp.dan` otherwise; `parserForFormat(ImportFormat.danDl7)` returns `DanDl7Parser`. Tasks 8 and 12 depend on detection working end-to-end.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/universal_import/data/services/format_detector_test.dart` (inside `main()`, as a new group; match the file's existing style of constructing `FormatDetector` and byte arrays):

```dart
  group('DAN DL7 detection', () {
    const detector = FormatDetector();

    test('detects DiverLog+ export (FSH prefix + AQUALUNG ZAR)', () {
      final content =
          'FSH|^~<>{}|OCI201^^|ZXU|20220604000837|\n'
          'ZRH|^~<>{}||13960|MSWG|ThM|C|BAR|L|\n'
          'ZAR{\n<AQUALUNG>\n<APP>DiverLog+</APP>\n</AQUALUNG>\n}\n'
          'ZDH|1|1|I|Q1S|20220224130600|27.2||FO2|\n';
      final result = detector.detect(
        Uint8List.fromList(utf8.encode(content)),
      );
      expect(result.format, ImportFormat.danDl7);
      expect(result.sourceApp, SourceApp.diverLog);
      expect(result.confidence, greaterThanOrEqualTo(0.85));
    });

    test('detects generic DL7 (FSH prefix, no AQUALUNG) as DAN', () {
      final content =
          'FSH|^~\\&{}|ANST01^12X456^A|ZXU|20180106163705+02:00|\n'
          'ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|\n'
          'ZDH|1|1|I|QS|20180101101000|27|11|FO2|||\n';
      final result = detector.detect(
        Uint8List.fromList(utf8.encode(content)),
      );
      expect(result.format, ImportFormat.danDl7);
      expect(result.sourceApp, SourceApp.dan);
    });

    test('a BOM before FSH still detects', () {
      final result = detector.detect(
        Uint8List.fromList(utf8.encode('﻿FSH|^~<>{}|X^^|ZXU|20240101|\n')),
      );
      expect(result.format, ImportFormat.danDl7);
    });

    test('pipe-delimited text without FSH prefix is not DL7', () {
      final result = detector.detect(
        Uint8List.fromList(utf8.encode('name|depth|time\nreef|18|45\n')),
      );
      expect(result.format, isNot(ImportFormat.danDl7));
    });
  });
```

Append to `test/features/universal_import/data/models/import_enums_test.dart`:

```dart
  group('DiverLog+ / DL7 wiring', () {
    test('danDl7 is a supported format', () {
      expect(ImportFormat.danDl7.isSupported, isTrue);
    });

    test('SourceApp.diverLog has DiveCloud export instructions', () {
      expect(SourceApp.diverLog.displayName, 'DiverLog+');
      expect(SourceApp.diverLog.exportInstructions, contains('DiveCloud'));
      expect(SourceApp.diverLog.exportInstructions, contains('.zxu'));
    });

    test('source override dropdown offers DiverLog+ and DAN DL7', () {
      expect(
        SourceOverrideOption.supported,
        contains(
          predicate<SourceOverrideOption>(
            (o) =>
                o.sourceApp == SourceApp.diverLog &&
                o.format == ImportFormat.danDl7,
          ),
        ),
      );
      expect(
        SourceOverrideOption.supported,
        contains(
          predicate<SourceOverrideOption>(
            (o) =>
                o.sourceApp == SourceApp.dan &&
                o.format == ImportFormat.danDl7,
          ),
        ),
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/format_detector_test.dart test/features/universal_import/data/models/import_enums_test.dart`
Expected: FAIL — `SourceApp.diverLog` does not exist (compile error), detector returns unknown for DL7 text.

- [ ] **Step 3: Implement the wiring**

In `import_enums.dart`:

1. `isSupported` — add `danDl7` to the true branch:

```dart
  bool get isSupported => switch (this) {
    csv ||
    uddf ||
    subsurfaceXml ||
    fit ||
    shearwaterDb ||
    macdiveXml ||
    macdiveSqlite ||
    danDl7 => true,
    _ => false,
  };
```

2. `SourceApp` — add `diverLog` to the value list (after `dan`), its display name, and instructions; update `dan`'s stale "planned" text:

```dart
enum SourceApp {
  submersion,
  subsurface,
  macdive,
  divingLog,
  diveMate,
  shearwater,
  suunto,
  garminConnect,
  scubapro,
  ssiMyDiveGuide,
  dan,
  diverLog,
  generic;
```

In `displayName`: `diverLog => 'DiverLog+',`

In `exportInstructions`, replace the `dan` case and add `diverLog`:

```dart
    dan =>
      'Export your dives as DAN DL7 (.zxu) files and import them directly '
          'into Submersion.',
    diverLog =>
      'In DiverLog+, sync your dives to DiveCloud. Then sign in at '
          'divecloud.net in a browser, select your dives, and choose Export '
          'to download a ZIP of DL7 (.zxu) files with photos. Import that '
          'ZIP directly into Submersion. Desktop DiverLog Full can also '
          'export .zxu files via Export Dive Data.',
```

3. `SourceOverrideOption.supported` — append two entries before the closing `]`:

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.diverLog,
      format: ImportFormat.danDl7,
      displayName: 'DiverLog+ (DL7)',
    ),
    SourceOverrideOption(
      sourceApp: SourceApp.dan,
      format: ImportFormat.danDl7,
      displayName: 'DAN (DL7)',
    ),
```

In `format_detector.dart`, add a plain-text DL7 branch in `detect()` between the XML step and the CSV step (DL7 text is not XML so order vs XML does not matter functionally, but keep it before CSV so pipe-delimited files never reach the CSV scorer):

```dart
    // 2. XML detection
    final xmlResult = _detectXml(textContent);
    if (xmlResult != null) return xmlResult;

    // 2b. DAN DL7 pipe-segment detection (plain text, not XML)
    final dl7Result = _detectDl7(textContent);
    if (dl7Result != null) return dl7Result;

    // 3. CSV detection
```

And the method (place after `_detectXml`/`_hasDiveKeywords`):

```dart
  // ======================== DL7 Detection ========================

  /// DAN DL7 (.zxu/.zxl) files are pipe-delimited HL7-style text starting
  /// with an FSH file-header segment. DiverLog+/DiveCloud exports embed an
  /// `<AQUALUNG>` block in the ZAR segment, which identifies the source app.
  ///
  /// The UTF-8 BOM decodes to U+FEFF, which Dart's trimLeft() does NOT
  /// remove (it is not Unicode White_Space), so it is stripped explicitly.
  DetectionResult? _detectDl7(String content) {
    var trimmed = content.trimLeft();
    if (trimmed.startsWith('﻿')) {
      trimmed = trimmed.substring(1).trimLeft();
    }
    if (!trimmed.startsWith('FSH|')) return null;
    final isDiverLog = trimmed.contains('<AQUALUNG>');
    return DetectionResult(
      format: ImportFormat.danDl7,
      sourceApp: isDiverLog ? SourceApp.diverLog : SourceApp.dan,
      confidence: 0.95,
    );
  }
```

BOM ordering caveat: the BOM must be stripped before `trimLeft()` can see `FSH|` — the code above handles BOM-then-whitespace and whitespace-then-BOM both. The same U+FEFF fact is why `Dl7Reader.read` strips it explicitly too (Task 1).

In `parser_registry.dart`, add the import and the case:

```dart
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';
```

```dart
    ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
    ImportFormat.danDl7 => const DanDl7Parser(),
    ImportFormat.fit => const FitImportParser(),
```

In `batch_parse_service.dart`, extend the folder-scan extension set:

```dart
  static const importableExtensions = {
    'fit',
    'uddf',
    'xml',
    'ssrf',
    'db',
    'sqlite',
    'zxu',
    'zxl',
    'zip', // DiveCloud export archives, expanded at intake
    'csv', // included so CSVs surface in triage as "import individually"
  };
```

- [ ] **Step 4: Run the tests and the existing suites that assert enum/detector behavior**

Run: `flutter test test/features/universal_import/data/services/format_detector_test.dart test/features/universal_import/data/models/import_enums_test.dart test/features/universal_import/data/parsers/placeholder_parser_test.dart`
Expected: PASS. If any pre-existing expectation asserts `danDl7.isSupported == false` or routes `danDl7` to `PlaceholderParser`, update that expectation to the new behavior (it is scaffolding-era).

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/data/models/import_enums.dart \
  lib/features/universal_import/data/services/format_detector.dart \
  lib/features/universal_import/data/parsers/parser_registry.dart \
  lib/features/universal_import/data/services/batch_parse_service.dart \
  test/features/universal_import/data/services/format_detector_test.dart \
  test/features/universal_import/data/models/import_enums_test.dart
git commit -m "feat(import): wire DAN DL7 into detection, registry, and source apps"
```

---

### Task 6: Real-sample gated regression suite

**Files:**
- Create: `test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart`

**Interfaces:**
- Consumes: `DanDl7Parser` (Task 4). Follows the house pattern from `macdive_xml_real_sample_test.dart`: `@Tags(['real-data'])`, gated on a `--dart-define` env var, skips cleanly when absent.
- Produces: an opt-in regression suite for the untracked real i330R export.

- [ ] **Step 1: Write the suite (no failing-test cycle — it must skip cleanly by default)**

```dart
/// DAN DL7 real-sample regression suite.
///
/// Exercises a real DiverLog+ export that is not checked into the
/// repository (provenance/licensing unverified; see the design spec's
/// References). A copy sits untracked at
/// test/features/universal_import/data/parsers/fixtures/dl7/diverlog_real.zxu
/// on machines that have run the research setup. To run:
///
///   flutter test \
///     --dart-define=DL7_ZXU_SAMPLE=test/features/universal_import/data/parsers/fixtures/dl7/diverlog_real.zxu \
///     --run-skipped --tags=real-data \
///     test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart
///
/// Without the env var (or when the file is missing), every test skips so
/// CI and fresh clones stay green.
@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/dan_dl7_import_parser.dart';

const _realSamplePathEnvVar = String.fromEnvironment('DL7_ZXU_SAMPLE');

void main() {
  group('DAN DL7 real-sample regression', () {
    late Uint8List bytes;
    var hasFixture = false;

    setUpAll(() async {
      if (_realSamplePathEnvVar.isEmpty) return;
      final file = File(_realSamplePathEnvVar);
      if (!file.existsSync()) return;
      bytes = await file.readAsBytes();
      hasFixture = true;
    });

    bool skipIfNoFixture() {
      if (hasFixture) return false;
      markTestSkipped(
        'Real sample not available. Set DL7_ZXU_SAMPLE via --dart-define '
        'and pass --run-skipped --tags=real-data to run.',
      );
      return true;
    }

    test('parses the i330R DiveCloud export with full ZAR data', () async {
      if (skipIfNoFixture()) return;
      final payload = await const DanDl7Parser().parse(bytes);
      final dive = payload.entitiesOf(ImportEntityType.dives).single;

      expect(dive['sourceUuid'], '7168_13960_20220224130600_1');
      expect(dive['dateTime'], DateTime.utc(2022, 2, 24, 13, 6));
      expect(dive['maxDepth'], closeTo(15.5448, 0.001));
      expect(dive['runtime'], const Duration(minutes: 57));
      expect(dive['surfaceInterval'], const Duration(hours: 1, minutes: 1));
      expect(dive['waterTemp'], closeTo(27.2, 0.1));
      expect(dive['diveComputerModel'], 'I330R');
      expect(dive['diveComputerSerial'], '13960');
      expect(dive['latitude'], closeTo(15.859509, 1e-5));
      expect(dive['longitude'], closeTo(-61.626858, 1e-5));

      // 30-second interval derived from the time column despite the
      // header's false Q1S declaration.
      final profile = dive['profile'] as List<Map<String, dynamic>>;
      expect(profile[1]['timestamp'] - profile[0]['timestamp'], 30);

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites.single['name'], 'Grande Anse');
    });
  });
}
```

- [ ] **Step 2: Verify it skips by default and passes with the sample**

Run: `flutter test test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart`
Expected: suite reports skipped (0 failures).

Run (real validation, sample present in this worktree):
```bash
flutter test \
  --dart-define=DL7_ZXU_SAMPLE=test/features/universal_import/data/parsers/fixtures/dl7/diverlog_real.zxu \
  --run-skipped --tags=real-data \
  test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart
```
Expected: PASS. If an assertion fails here but the synthetic-fixture tests pass, the real file has revealed a genuine parser gap — fix the parser (not the assertion) unless the assertion itself mis-transcribed the real file's values.

- [ ] **Step 3: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add test/features/universal_import/data/parsers/dan_dl7_real_sample_test.dart
git commit -m "test(import): env-gated real-sample regression suite for DL7"
```

---

### Task 7: ZipExpansionService

**Files:**
- Modify: `pubspec.yaml` (promote `archive` to a direct dependency)
- Create: `lib/features/universal_import/data/services/zip_expansion_service.dart`
- Test: `test/features/universal_import/data/services/zip_expansion_service_test.dart`

**Interfaces:**
- Consumes: `package:archive` 3.x (`ZipDecoder().decodeBytes`, `ArchiveFile.isFile/.name/.content`).
- Produces:
  - `class ArchiveExpansion { List<String> filePaths; Map<String, List<String>> photoPathsByBaseName; List<String> unmatchedPhotoPaths; int skippedEntryCount; }`
  - `class ZipExpansionService { const ZipExpansionService(); static bool isZipBytes(Uint8List bytes); Future<ArchiveExpansion> expandAll(List<String> paths); Future<ArchiveExpansion> expandZipBytes(Uint8List bytes, String archiveName); }`
  - `expandAll` passes non-ZIP paths through unchanged in `filePaths` and expands each ZIP into extracted member paths. Photo keys are the dive file's basename without extension. Tasks 8–10 depend on these exact names.

- [ ] **Step 1: Promote the dependency**

In `pubspec.yaml`, add under `dependencies:` next to the other utility packages (it currently resolves transitively at 3.6.1, so the lockfile will not change):

```yaml
  archive: ^3.6.1
```

Run: `flutter pub get`
Expected: `Got dependencies!` with no version changes.

- [ ] **Step 2: Write the failing test**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/universal_import/data/services/zip_expansion_service.dart';

Uint8List _buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

List<int> _zxu(String duid) =>
    ('FSH|^~<>{}|OCI201^^|ZXU|20240613080000|\n'
            'ZDH|1|1|I|Q1S|20240612093000|28.0||FO2|\n'
            'ZDT|1|1|18.29|20240612093600|0.000000|0|\n')
        .codeUnits;

void main() {
  const service = ZipExpansionService();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zip_expansion_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> writeZip(String name, Map<String, List<int>> entries) async {
    final path = p.join(tmp.path, name);
    await File(path).writeAsBytes(_buildZip(entries));
    return path;
  }

  group('isZipBytes', () {
    test('recognizes the PK magic and rejects other content', () {
      expect(ZipExpansionService.isZipBytes(_buildZip({'a.zxu': _zxu('a')})),
          isTrue);
      expect(
        ZipExpansionService.isZipBytes(
          Uint8List.fromList('FSH|^~<>{}|'.codeUnits),
        ),
        isFalse,
      );
      expect(ZipExpansionService.isZipBytes(Uint8List(0)), isFalse);
    });
  });

  group('expandAll', () {
    test('passes non-zip paths through unchanged', () async {
      final plain = p.join(tmp.path, 'dive.zxu');
      await File(plain).writeAsBytes(_zxu('x'));
      final expansion = await service.expandAll([plain]);
      expect(expansion.filePaths, [plain]);
      expect(expansion.photoPathsByBaseName, isEmpty);
    });

    test('expands a DiveCloud-style zip: dive files + prefixed photos',
        () async {
      final zipPath = await writeZip('divecloud_export.zip', {
        '7168_13960_20220224130600_1.zxu': _zxu('1'),
        '7168_13960_20220224130600_1_photo1.jpg': [1, 2, 3],
        '7168_13960_20220225100000_2.zxu': _zxu('2'),
        'README.txt': [65],
        '__MACOSX/._junk': [0],
      });

      final expansion = await service.expandAll([zipPath]);

      expect(expansion.filePaths, hasLength(2));
      expect(
        expansion.filePaths.map(p.basename),
        containsAll([
          '7168_13960_20220224130600_1.zxu',
          '7168_13960_20220225100000_2.zxu',
        ]),
      );
      for (final path in expansion.filePaths) {
        expect(File(path).existsSync(), isTrue);
      }
      expect(
        expansion.photoPathsByBaseName['7168_13960_20220224130600_1'],
        hasLength(1),
      );
      expect(expansion.unmatchedPhotoPaths, isEmpty);
      // README.txt and the __MACOSX entry were skipped.
      expect(expansion.skippedEntryCount, 2);
    });

    test('matches photos placed in a per-dive folder', () async {
      final zipPath = await writeZip('folders.zip', {
        '7168_13960_20220224130600_1.zxu': _zxu('1'),
        '7168_13960_20220224130600_1/reef.jpg': [1],
        '7168_13960_20220224130600_1/turtle.png': [2],
      });
      final expansion = await service.expandAll([zipPath]);
      expect(
        expansion.photoPathsByBaseName['7168_13960_20220224130600_1'],
        hasLength(2),
      );
    });

    test('reports photos that match no dive file as unmatched', () async {
      final zipPath = await writeZip('orphan.zip', {
        'dive_a.zxu': _zxu('a'),
        'unrelated_photo.jpg': [9],
      });
      final expansion = await service.expandAll([zipPath]);
      expect(expansion.unmatchedPhotoPaths, hasLength(1));
      expect(expansion.photoPathsByBaseName, isEmpty);
    });

    test('mixed selection: zip members join plain files', () async {
      final plain = p.join(tmp.path, 'other.zxu');
      await File(plain).writeAsBytes(_zxu('p'));
      final zipPath = await writeZip('one.zip', {'inner.zxu': _zxu('i')});
      final expansion = await service.expandAll([plain, zipPath]);
      expect(expansion.filePaths, hasLength(2));
      expect(expansion.filePaths.first, plain);
    });

    test('throws FormatException for an unreadable archive', () async {
      final bad = p.join(tmp.path, 'corrupt.zip');
      await File(bad).writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]);
      expect(
        () => service.expandAll([bad]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('expandZipBytes', () {
    test('expands raw zip bytes (share-intent path)', () async {
      final bytes = _buildZip({'dive.zxu': _zxu('d'), 'dive_pic.jpeg': [7]});
      final expansion = await service.expandZipBytes(bytes, 'shared.zip');
      expect(expansion.filePaths, hasLength(1));
      expect(expansion.photoPathsByBaseName['dive'], hasLength(1));
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/services/zip_expansion_service_test.dart`
Expected: FAIL — package resolution error for `zip_expansion_service.dart`.

- [ ] **Step 4: Write the implementation**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Result of expanding a file selection that may contain ZIP archives.
class ArchiveExpansion {
  /// Importable file paths: original non-ZIP paths plus extracted members.
  final List<String> filePaths;

  /// Extracted photo paths keyed by the dive file's basename (without
  /// extension) they belong to. DiveCloud exports name photos with the
  /// dive's DUID prefix or place them in a folder named after the DUID.
  final Map<String, List<String>> photoPathsByBaseName;

  /// Photos in the archive that matched no dive file.
  final List<String> unmatchedPhotoPaths;

  /// Archive entries skipped as junk (hidden files, unsupported types).
  final int skippedEntryCount;

  const ArchiveExpansion({
    required this.filePaths,
    this.photoPathsByBaseName = const {},
    this.unmatchedPhotoPaths = const [],
    this.skippedEntryCount = 0,
  });
}

/// Expands ZIP archives at file-intake time so their members flow through
/// the normal detection/parse pipeline (a DiveCloud export ZIP becomes a
/// bulk batch of .zxu files plus a photo index).
class ZipExpansionService {
  const ZipExpansionService();

  /// Total uncompressed size cap: guards against zip bombs.
  static const maxUncompressedBytes = 500 * 1024 * 1024;

  static const _diveFileExtensions = {'.zxu', '.zxl'};
  static const _photoExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.heif'};

  static bool isZipBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  /// Expands any ZIPs in [paths]; non-ZIP paths pass through unchanged and
  /// keep their position. Results from multiple ZIPs are merged.
  Future<ArchiveExpansion> expandAll(List<String> paths) async {
    final filePaths = <String>[];
    final photos = <String, List<String>>{};
    final unmatched = <String>[];
    var skipped = 0;

    for (final path in paths) {
      final file = File(path);
      Uint8List? header;
      try {
        final raf = await file.open();
        header = await raf.read(4);
        await raf.close();
      } catch (_) {
        filePaths.add(path); // unreadable: let downstream report the error
        continue;
      }
      if (!isZipBytes(Uint8List.fromList(header))) {
        filePaths.add(path);
        continue;
      }
      final expansion = await expandZipBytes(
        await file.readAsBytes(),
        p.basename(path),
      );
      filePaths.addAll(expansion.filePaths);
      expansion.photoPathsByBaseName.forEach(
        (key, value) => (photos[key] ??= []).addAll(value),
      );
      unmatched.addAll(expansion.unmatchedPhotoPaths);
      skipped += expansion.skippedEntryCount;
    }

    return ArchiveExpansion(
      filePaths: filePaths,
      photoPathsByBaseName: photos,
      unmatchedPhotoPaths: unmatched,
      skippedEntryCount: skipped,
    );
  }

  /// Extracts [bytes] (a ZIP archive) to a temp directory and classifies
  /// members into dive files and photos.
  ///
  /// Throws [FormatException] when the archive cannot be read (corrupt or
  /// password-protected) or exceeds [maxUncompressedBytes].
  Future<ArchiveExpansion> expandZipBytes(
    Uint8List bytes,
    String archiveName,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw FormatException(
        'Could not read archive "$archiveName" '
        '(corrupt or password-protected): $e',
      );
    }

    var totalSize = 0;
    for (final entry in archive) {
      if (entry.isFile) totalSize += entry.size;
    }
    if (totalSize > maxUncompressedBytes) {
      throw FormatException(
        'Archive "$archiveName" is too large to expand '
        '(${totalSize ~/ (1024 * 1024)} MB uncompressed)',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('submersion_zip_');
    final diveFiles = <String, String>{}; // baseName -> extracted path
    final photoEntries = <({String entryName, String extractedPath})>[];
    var skipped = 0;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final segments = p.split(name);
      if (segments.any((s) => s.startsWith('.') || s == '__MACOSX')) {
        skipped++;
        continue;
      }
      final ext = p.extension(name).toLowerCase();
      final isDiveFile = _diveFileExtensions.contains(ext);
      final isPhoto = _photoExtensions.contains(ext);
      if (!isDiveFile && !isPhoto) {
        skipped++;
        continue;
      }
      // Flatten to the basename; disambiguate collisions with a counter.
      var outName = p.basename(name);
      var outPath = p.join(tempDir.path, outName);
      var counter = 1;
      while (File(outPath).existsSync()) {
        outName =
            '${p.basenameWithoutExtension(name)}_${counter++}${p.extension(name)}';
        outPath = p.join(tempDir.path, outName);
      }
      await File(outPath).writeAsBytes(entry.content as List<int>);

      if (isDiveFile) {
        diveFiles[p.basenameWithoutExtension(outName)] = outPath;
      } else {
        photoEntries.add((entryName: name, extractedPath: outPath));
      }
    }

    // Match photos to dive files: parent-folder name first, then longest
    // dive-file basename that prefixes the photo's own basename.
    final photos = <String, List<String>>{};
    final unmatched = <String>[];
    final baseNames = diveFiles.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final photo in photoEntries) {
      final parentName = p.basename(p.dirname(photo.entryName));
      final photoBase = p.basenameWithoutExtension(photo.entryName);
      String? match;
      if (diveFiles.containsKey(parentName)) {
        match = parentName;
      } else {
        for (final base in baseNames) {
          if (photoBase.startsWith(base)) {
            match = base;
            break;
          }
        }
      }
      if (match != null) {
        (photos[match] ??= []).add(photo.extractedPath);
      } else {
        unmatched.add(photo.extractedPath);
      }
    }

    return ArchiveExpansion(
      filePaths: diveFiles.values.toList(),
      photoPathsByBaseName: photos,
      unmatchedPhotoPaths: unmatched,
      skippedEntryCount: skipped,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/services/zip_expansion_service_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add pubspec.yaml pubspec.lock lib/features/universal_import/data/services/zip_expansion_service.dart test/features/universal_import/data/services/zip_expansion_service_test.dart
git commit -m "feat(import): ZIP expansion service for DiveCloud archives"
```

---

### Task 8: Notifier + state integration (ZIP intake)

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_state.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Test: `test/features/universal_import/presentation/providers/universal_import_batch_test.dart` (extend)

**Interfaces:**
- Consumes: `ZipExpansionService`/`ArchiveExpansion` (Task 7), DL7 detection (Task 5).
- Produces: `UniversalImportState.photoPathsByBaseName` (`Map<String, List<String>>`, default `{}`) and `UniversalImportState.unmatchedPhotoCount` (`int`, default `0`), both threaded through `copyWith`; `UniversalImportNotifier` constructor parameter `ZipExpansionService zipExpansionService = const ZipExpansionService()`; ZIPs expand in `pickFiles`, `loadFilesFromPaths`, and `loadFileFromBytes`. Task 9 reads `photoPathsByBaseName` from the notifier state.

- [ ] **Step 1: Write the failing test**

Append to `test/features/universal_import/presentation/providers/universal_import_batch_test.dart`, inside `main()` after the existing groups (the file already provides `container`, `notifier`, `picker`, `tmp`, and DL7-free UDDF fixtures; reuse its helpers):

```dart
  group('ZIP intake', () {
    Uint8List buildZip(Map<String, List<int>> entries) {
      final archive = Archive();
      for (final entry in entries.entries) {
        archive.addFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    List<int> zxuBytes(String start) =>
        ('FSH|^~<>{}|OCI201^^|ZXU|20240613080000|\n'
                'ZRH|^~<>{}||98765|MSWG|ThM|C|BAR|L|\n'
                'ZDH|1|1|I|Q1S|$start|28.0||FO2|\n'
                'ZDP{\n|0.00|0.0|1.00|\n|1.00|10.0|||||||||\n|2.00|0.5|||||||||\nZDP}\n'
                'ZDT|1|1|10.0|||\n')
            .codeUnits;

    test('a dropped DiveCloud zip fans out into a batch with photos indexed',
        () async {
      final zipPath = p.join(tmp.path, 'divecloud_export.zip');
      await File(zipPath).writeAsBytes(
        buildZip({
          'a_20240612093000_1.zxu': zxuBytes('20240612093000'),
          'a_20240612093000_1_photo.jpg': [1, 2, 3],
          'b_20240613100000_2.zxu': zxuBytes('20240613100000'),
        }),
      );

      await notifier.loadFilesFromPaths([zipPath]);

      final state = container.read(universalImportNotifierProvider);
      expect(state.files, hasLength(2));
      expect(
        state.files.every(
          (f) => f.detection.format == ImportFormat.danDl7,
        ),
        isTrue,
      );
      expect(
        state.photoPathsByBaseName['a_20240612093000_1'],
        hasLength(1),
      );
      expect(state.wasLoadedExternally, isTrue);
    });

    test('a zip with a single dive file routes to the single-file flow',
        () async {
      final zipPath = p.join(tmp.path, 'single.zip');
      await File(zipPath).writeAsBytes(
        buildZip({'only_dive.zxu': zxuBytes('20240612093000')}),
      );

      await notifier.loadFilesFromPaths([zipPath]);

      final state = container.read(universalImportNotifierProvider);
      expect(state.files, hasLength(1));
      expect(state.isBatch, isFalse);
      // Single-file flow keeps bytes in memory for the parse step.
      expect(state.fileBytes, isNotNull);
      expect(state.detectionResult?.format, ImportFormat.danDl7);
    });

    test('loadFileFromBytes expands zip bytes from a share intent', () async {
      final bytes = buildZip({
        'x_1.zxu': zxuBytes('20240612093000'),
        'y_2.zxu': zxuBytes('20240613100000'),
      });

      final detection =
          await notifier.loadFileFromBytes(bytes, 'shared_export.zip');

      final state = container.read(universalImportNotifierProvider);
      expect(state.files, hasLength(2));
      expect(detection.format, ImportFormat.danDl7);
      expect(state.wasLoadedExternally, isTrue);
    });

    test('a zip with nothing importable reports an error', () async {
      final bytes = buildZip({'readme.txt': [65, 66]});
      final detection =
          await notifier.loadFileFromBytes(bytes, 'junk.zip');
      final state = container.read(universalImportNotifierProvider);
      expect(detection.format, ImportFormat.unknown);
      expect(state.error, contains('No importable files'));
    });
  });
```

Add the needed imports at the top of the test file if not already present:

```dart
import 'dart:typed_data';

import 'package:archive/archive.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_batch_test.dart`
Expected: FAIL — `photoPathsByBaseName` is not defined on state; ZIP paths flow to detection as unsupported files.

- [ ] **Step 3: Extend the state**

In `universal_import_state.dart`, add the two fields (constructor defaults, final declarations near `files`, and `copyWith` threading):

Constructor parameters:
```dart
    this.photoPathsByBaseName = const {},
    this.unmatchedPhotoCount = 0,
```

Field declarations (place after `files`):
```dart
  /// Photos extracted from an imported ZIP, keyed by the dive file's
  /// basename (without extension) they belong to. Consumed post-commit by
  /// the adapter to attach photos to the created dives.
  final Map<String, List<String>> photoPathsByBaseName;

  /// Photos in an imported ZIP that matched no dive file (surfaced as an
  /// import warning count).
  final int unmatchedPhotoCount;
```

`copyWith` parameters and wiring:
```dart
    Map<String, List<String>>? photoPathsByBaseName,
    int? unmatchedPhotoCount,
```
```dart
      photoPathsByBaseName: photoPathsByBaseName ?? this.photoPathsByBaseName,
      unmatchedPhotoCount: unmatchedPhotoCount ?? this.unmatchedPhotoCount,
```

- [ ] **Step 4: Extend the notifier**

In `universal_import_providers.dart`:

1. Import the service:
```dart
import 'package:submersion/features/universal_import/data/services/zip_expansion_service.dart';
```

2. Constructor injection (mirror the `BatchParseService` pattern):
```dart
  UniversalImportNotifier(
    this._ref, {
    BatchParseService batchParseService = const BatchParseService(),
    ZipExpansionService zipExpansionService = const ZipExpansionService(),
  }) : _batchParseService = batchParseService,
       _zipExpansion = zipExpansionService,
       super(const UniversalImportState());
```
with field `final ZipExpansionService _zipExpansion;`.

3. Add two private helpers after `_detectFormat`:

```dart
  /// Stores photo/skip bookkeeping from a ZIP expansion into state.
  void _applyExpansionExtras(ArchiveExpansion expansion) {
    if (expansion.photoPathsByBaseName.isEmpty &&
        expansion.unmatchedPhotoPaths.isEmpty) {
      return;
    }
    state = state.copyWith(
      photoPathsByBaseName: expansion.photoPathsByBaseName,
      unmatchedPhotoCount: expansion.unmatchedPhotoPaths.length,
    );
  }

  /// Single-file load by path (used when a ZIP expands to exactly one
  /// member and by the classic picker path).
  Future<void> _loadSingleFromFilePath(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final detection = await _detectFormat(bytes);
    state = state.copyWith(
      isLoading: false,
      files: [
        PickedImportFile(
          name: p.basename(filePath),
          path: filePath,
          bytes: bytes,
          detection: detection,
          status: ImportFileStatus.pending,
        ),
      ],
      detectionResult: detection,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }
```

4. Rework `pickFiles` to expand before the single/batch split (replace the body from the `if (result == null ...)` check onward):

```dart
      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final pickedPaths = [
        for (final f in result.files)
          if (f.path != null) f.path!,
      ];
      final expansion = await _zipExpansion.expandAll(pickedPaths);
      _applyExpansionExtras(expansion);

      if (expansion.filePaths.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No importable files found in archive',
        );
        return;
      }
      if (expansion.filePaths.length == 1) {
        await _loadSingleFromFilePath(expansion.filePaths.first);
        return;
      }
      await _loadBatchFromPaths(expansion.filePaths);
```

`_loadSingleFromPath(PlatformFile)` becomes unused by `pickFiles`; delete it and its call site (its null-path error handling is covered by the picker returning paths, and `_loadSingleFromFilePath` covers the read).

5. Rework `loadFilesFromPaths`:

```dart
  Future<void> loadFilesFromPaths(List<String> paths) async {
    state = const UniversalImportState().copyWith(isLoading: true);
    final expansion = await _zipExpansion.expandAll(paths);
    _applyExpansionExtras(expansion);
    if (expansion.filePaths.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'No importable files found in archive',
      );
      return;
    }
    if (expansion.filePaths.length == 1) {
      await _loadSingleFromFilePath(expansion.filePaths.first);
    } else {
      await _loadBatchFromPaths(expansion.filePaths);
    }
    state = state.copyWith(wasLoadedExternally: true);
  }
```

6. `pickFolder` must expand too — Task 5 added `zip` to `importableExtensions`, so folder scans now surface ZIPs. Immediately after the `scanFolderForImportableFiles` call and its empty-check, insert:

```dart
      final expansion = await _zipExpansion.expandAll(paths);
      _applyExpansionExtras(expansion);
      final expandedPaths = expansion.filePaths;
```

then use `expandedPaths` in place of `paths` for the rest of the method (the `isEmpty` error branch, the `length == 1` single-hit branch — which becomes `await _loadSingleFromFilePath(expandedPaths.first); return;` — and the `_loadBatchFromPaths(expandedPaths)` call).

7. Add the ZIP branch to `loadFileFromBytes`, immediately after the state reset inside the `try`:

```dart
    try {
      if (ZipExpansionService.isZipBytes(bytes)) {
        final expansion = await _zipExpansion.expandZipBytes(bytes, fileName);
        _applyExpansionExtras(expansion);
        if (expansion.filePaths.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            error: 'No importable files found in archive',
          );
          return const DetectionResult(
            format: ImportFormat.unknown,
            confidence: 0.0,
            warnings: ['No importable files found in archive'],
          );
        }
        if (expansion.filePaths.length == 1) {
          await _loadSingleFromFilePath(expansion.filePaths.first);
        } else {
          await _loadBatchFromPaths(expansion.filePaths);
        }
        state = state.copyWith(wasLoadedExternally: true);
        return state.detectionResult ??
            const DetectionResult(format: ImportFormat.unknown, confidence: 0);
      }

      final detection = await _detectFormat(bytes);
      // ... existing non-ZIP body unchanged
```

Note `_applyExpansionExtras` runs BEFORE `_loadSingleFromFilePath`/`_loadBatchFromPaths`, and those methods' `copyWith` calls preserve the photo fields.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/universal_import/presentation/providers/universal_import_batch_test.dart test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`
Expected: PASS — new ZIP group green, existing notifier tests unaffected. If a notifier test constructed the notifier with positional expectations around `_loadSingleFromPath`, update it to the new path-based flow.

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/universal_import/presentation/providers/ test/features/universal_import/presentation/providers/
git commit -m "feat(import): expand ZIP archives at file intake"
```

---

### Task 9: Adapter photo attachment

**Files:**
- Modify: `lib/features/import_wizard/domain/models/unified_import_result.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart` (new)

**Interfaces:**
- Consumes: `UniversalImportState.photoPathsByBaseName` (Task 8), `UddfEntityImportResult.diveIdByIndex` (existing), `MediaImportService.importLocalFileForDive({required File sourceFile, required String diveId, DateTime? takenAt})` via the existing `mediaImportServiceProvider` (`lib/features/media/presentation/providers/photo_picker_providers.dart:238`), payload dive stamps `_sourceFileId` (`'f<index>'`, from `BatchParseService`) and `state.fileName` for the single-file flow.
- Produces: `UnifiedImportResult.attachedPhotoCount` (`int`, default 0); photos attach after commit and consolidation, only for files that produced exactly one imported dive. Task 10 renders the count.

- [ ] **Step 1: Add the result fields**

In `unified_import_result.dart` add:

```dart
  /// Number of photos attached to imported dives (ZIP imports only).
  final int attachedPhotoCount;

  /// Photos in an imported archive that matched no dive file — surfaced in
  /// the summary so photos are never silently dropped.
  final int unmatchedPhotoCount;
```

and to the constructor: `this.attachedPhotoCount = 0,` and `this.unmatchedPhotoCount = 0,`.

- [ ] **Step 2: Write the failing test**

The attachment logic is a pure mapping plus a service call; extract it as a static, injectable method so it is testable without the full wizard. Create `test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

PickedImportFile _file(String name) => PickedImportFile(
      name: name,
      detection: const DetectionResult(
        format: ImportFormat.danDl7,
        confidence: 1,
      ),
      status: ImportFileStatus.parsed,
    );

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('photo_attach_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> photo(String name) async {
    final path = p.join(tmp.path, name);
    await File(path).writeAsBytes([1, 2, 3]);
    return path;
  }

  test('attaches photos to the single dive of each source file', () async {
    final photoA = await photo('a_pic.jpg');
    final attached = <(String diveId, String path)>[];

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'dive_a': [photoA],
      },
      diveIdByIndex: const {0: 'dive-id-a', 1: 'dive-id-b'},
      removedDiveIds: const {},
      dives: const [
        {'_sourceFileId': 'f0', 'dateTime': null},
        {'_sourceFileId': 'f1'},
      ],
      files: [_file('dive_a.zxu'), _file('dive_b.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async {
        attached.add((diveId, file.path));
      },
    );

    expect(count, 1);
    expect(attached.single.$1, 'dive-id-a');
    expect(attached.single.$2, photoA);
  });

  test('single-file flow maps photos via the state file name', () async {
    final photoA = await photo('solo_pic.jpg');
    final attached = <String>[];

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'solo': [photoA],
      },
      diveIdByIndex: const {0: 'dive-id-solo'},
      removedDiveIds: const {},
      dives: const [
        {'name': 'no source stamp on single-file payloads'},
      ],
      files: [_file('solo.zxu')],
      singleFileName: 'solo.zxu',
      attach: (file, diveId, takenAt) async => attached.add(diveId),
    );

    expect(count, 1);
    expect(attached.single, 'dive-id-solo');
  });

  test('skips consolidated-away dives and multi-dive files', () async {
    final photoA = await photo('a.jpg');
    final photoB = await photo('b.jpg');
    var calls = 0;

    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'removed': [photoA],
        'multi': [photoB],
      },
      diveIdByIndex: const {0: 'gone', 1: 'm1', 2: 'm2'},
      removedDiveIds: const {'gone'},
      dives: const [
        {'_sourceFileId': 'f0'},
        {'_sourceFileId': 'f1'},
        {'_sourceFileId': 'f1'},
      ],
      files: [_file('removed.zxu'), _file('multi.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async => calls++,
    );

    expect(count, 0);
    expect(calls, 0);
  });

  test('a failing attach is swallowed and not counted', () async {
    final photoA = await photo('x.jpg');
    final count = await UniversalAdapter.attachImportedPhotos(
      photoPathsByBaseName: {
        'x': [photoA],
      },
      diveIdByIndex: const {0: 'dive-x'},
      removedDiveIds: const {},
      dives: const [
        {'_sourceFileId': 'f0'},
      ],
      files: [_file('x.zxu')],
      singleFileName: null,
      attach: (file, diveId, takenAt) async =>
          throw Exception('disk full'),
    );
    expect(count, 0);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart`
Expected: FAIL — `attachImportedPhotos` is not defined.

- [ ] **Step 4: Implement**

In `universal_adapter.dart`:

1. Add imports:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
```

2. Add the static helper to `UniversalAdapter` (near the other import helpers):

```dart
  /// Attaches ZIP-bundled photos to newly created dives.
  ///
  /// Photos are keyed by their source file's basename; a file's photos are
  /// attached only when that file produced exactly one imported dive (the
  /// DiveCloud shape) so a multi-dive file never duplicates photos across
  /// its dives. Attach failures are swallowed: the dive import already
  /// succeeded and a failed photo copy must not fail the wizard.
  ///
  /// Returns the number of photos attached.
  static Future<int> attachImportedPhotos({
    required Map<String, List<String>> photoPathsByBaseName,
    required Map<int, String> diveIdByIndex,
    required Set<String> removedDiveIds,
    required List<Map<String, dynamic>> dives,
    required List<PickedImportFile> files,
    required String? singleFileName,
    required Future<void> Function(File file, String diveId, DateTime? takenAt)
        attach,
  }) async {
    if (photoPathsByBaseName.isEmpty || diveIdByIndex.isEmpty) return 0;

    String? baseNameForIndex(int index) {
      if (index < 0 || index >= dives.length) return null;
      final sourceId = dives[index]['_sourceFileId'] as String?;
      if (sourceId == null) {
        // Single-file flow: payloads carry no source stamp.
        return singleFileName == null
            ? null
            : p.basenameWithoutExtension(singleFileName);
      }
      final fileIndex = int.tryParse(sourceId.substring(1));
      if (fileIndex == null || fileIndex < 0 || fileIndex >= files.length) {
        return null;
      }
      return p.basenameWithoutExtension(files[fileIndex].name);
    }

    // Group surviving imported dives by their source file's base name.
    final divesByBase = <String, List<MapEntry<int, String>>>{};
    for (final entry in diveIdByIndex.entries) {
      if (removedDiveIds.contains(entry.value)) continue;
      final base = baseNameForIndex(entry.key);
      if (base == null) continue;
      (divesByBase[base] ??= []).add(entry);
    }

    var attachedCount = 0;
    for (final entry in divesByBase.entries) {
      final photos = photoPathsByBaseName[entry.key];
      if (photos == null || entry.value.length != 1) continue;
      final diveIndex = entry.value.single.key;
      final diveId = entry.value.single.value;
      final takenAt = dives[diveIndex]['dateTime'] as DateTime?;
      for (final photoPath in photos) {
        try {
          await attach(File(photoPath), diveId, takenAt);
          attachedCount++;
        } catch (_) {
          // Best-effort: see doc comment.
        }
      }
    }
    return attachedCount;
  }
```

3. Call it inside `performImport`, after the consolidation block and before `_convertImportCounts` (the `cleanedUpFailures` line), and thread the count into the result:

```dart
    final attachedPhotos = await attachImportedPhotos(
      photoPathsByBaseName: notifierState.photoPathsByBaseName,
      diveIdByIndex: result.diveIdByIndex,
      removedDiveIds: removedDiveIds,
      dives: payload.entitiesOf(ui.ImportEntityType.dives),
      files: notifierState.files,
      singleFileName: notifierState.fileName,
      attach: (file, diveId, takenAt) async {
        await _ref.read(mediaImportServiceProvider).importLocalFileForDive(
              sourceFile: file,
              diveId: diveId,
              takenAt: takenAt,
            );
      },
    );
```

and in the returned `UnifiedImportResult`:

```dart
      attachedPhotoCount: attachedPhotos,
      unmatchedPhotoCount: notifierState.unmatchedPhotoCount,
```

Note `performImport` already declares `final pickedFiles = notifierState.files;` further down — leave it; the helper receives `notifierState.files` directly.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_photo_test.dart test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/import_wizard/ test/features/import_wizard/
git commit -m "feat(import): attach DiveCloud photos to imported dives"
```

---

### Task 10: Summary row + l10n

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other locales (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`)
- Test: `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart` (extend if it exists; create the assertion in whichever widget test file covers the summary — check with `ls test/features/import_wizard/presentation/widgets/`)

**Interfaces:**
- Consumes: `UnifiedImportResult.attachedPhotoCount` (Task 9).
- Produces: a `_CountRow` in the summary when photos were attached, localized in all 11 locales as `universalImport_label_photosAttached`.

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/arb/app_en.arb`, next to the other `universalImport_label_*` keys:

```json
  "universalImport_label_photosAttached": "Photos attached",
  "universalImport_label_photosUnmatched": "Photos not matched to a dive",
```

Translations (match each file's existing style; no description blocks unless neighboring keys have them):

| File | photosAttached | photosUnmatched |
| --- | --- | --- |
| app_ar.arb | "الصور المرفقة" | "صور لم تطابق أي غوصة" |
| app_de.arb | "Fotos angehängt" | "Fotos keinem Tauchgang zugeordnet" |
| app_es.arb | "Fotos adjuntadas" | "Fotos sin coincidencia con una inmersión" |
| app_fr.arb | "Photos jointes" | "Photos sans plongée correspondante" |
| app_he.arb | "תמונות שצורפו" | "תמונות ללא צלילה תואמת" |
| app_hu.arb | "Csatolt fényképek" | "Merüléshez nem társított fényképek" |
| app_it.arb | "Foto allegate" | "Foto senza immersione corrispondente" |
| app_nl.arb | "Foto's bijgevoegd" | "Foto's niet aan een duik gekoppeld" |
| app_pt.arb | "Fotos anexadas" | "Fotos sem mergulho correspondente" |
| app_zh.arb | "已附加照片" | "未匹配到潜水的照片" |

Regenerate: `flutter gen-l10n` (if the repo instead regenerates l10n via `flutter pub get`/build, run `flutter pub get` — check `l10n.yaml` at the repo root; whichever command the repo uses must leave `flutter analyze` clean on the new getter).

- [ ] **Step 2: Thread the count through the summary widget**

In `import_summary_step.dart`:

1. `ImportSummaryStep.build` — pass the new field:

```dart
    return _SuccessView(
      importedCounts: result.importedCounts,
      consolidatedCount: result.consolidatedCount,
      updatedCount: result.updatedCount,
      skippedCount: result.skippedCount,
      attachedPhotoCount: result.attachedPhotoCount,
      unmatchedPhotoCount: result.unmatchedPhotoCount,
      importedDiveIds: result.importedDiveIds,
      fileOutcomes: result.fileOutcomes,
      onDone: onDone,
      onViewDives: onViewDives,
    );
```

2. `_SuccessView` — add `final int attachedPhotoCount;` and `final int unmatchedPhotoCount;` with constructor parameters `this.attachedPhotoCount = 0,` / `this.unmatchedPhotoCount = 0,`, and render after the consolidated row:

```dart
            if (attachedPhotoCount > 0)
              _CountRow(
                icon: Icons.photo_library_outlined,
                label: l10n.universalImport_label_photosAttached,
                count: attachedPhotoCount,
                key: const Key('import_summary_photos_row'),
              ),
            if (unmatchedPhotoCount > 0)
              _CountRow(
                icon: Icons.hide_image_outlined,
                label: l10n.universalImport_label_photosUnmatched,
                count: unmatchedPhotoCount,
                key: const Key('import_summary_unmatched_photos_row'),
              ),
```

- [ ] **Step 3: Write/extend the widget test**

If `test/features/import_wizard/presentation/widgets/` has a summary-step test, add a case asserting `find.byKey(const Key('import_summary_photos_row'))` appears when the result has `attachedPhotoCount: 2` and is absent when 0, following that file's existing pump harness (widget tests in this repo pump with `themeAnimationDuration: Duration.zero` and localizations delegates — copy the neighboring test's `MaterialApp` setup exactly). If no summary widget test exists, create one following `test/features/import_wizard/presentation/widgets/` conventions.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/import_wizard/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add lib/features/import_wizard/presentation/widgets/import_summary_step.dart lib/l10n/
git add test/features/import_wizard/
git commit -m "feat(import): show attached photo count in import summary"
```

---

### Task 11: Platform file associations + docs

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `macos/Runner/Info.plist`
- Modify: `docs/guide/import-export.md`

**Interfaces:**
- Consumes: nothing new. Registers `.zxu`/`.zxl` so share-to-Submersion works; ZIP is deliberately NOT associated (too generic).
- Produces: OS-level document-type registration and user documentation.

- [ ] **Step 1: iOS document types**

In `ios/Runner/Info.plist`, add to the `CFBundleDocumentTypes` array (next to the existing UDDF entry, matching its structure exactly):

```xml
		<dict>
			<key>CFBundleTypeName</key>
			<string>DAN DL7 Dive Log</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>app.submersion.dl7</string>
			</array>
		</dict>
```

And to the `UTImportedTypeDeclarations` array (next to the UDDF/FIT declarations):

```xml
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.data</string>
			</array>
			<key>UTTypeDescription</key>
			<string>DAN DL7 Dive Log</string>
			<key>UTTypeIdentifier</key>
			<string>app.submersion.dl7</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>zxu</string>
					<string>zxl</string>
				</array>
			</dict>
		</dict>
```

- [ ] **Step 2: macOS document types**

Open `macos/Runner/Info.plist`, locate its existing UDDF `CFBundleDocumentTypes` entry and `UTImportedTypeDeclarations` (the drag-drop feature added them), and clone the same two blocks as Step 1, adjusted to the macOS file's exact existing key style (some macOS entries use `CFBundleTypeExtensions` instead of `LSItemContentTypes` — mirror whichever the adjacent UDDF entry uses; if it uses `LSItemContentTypes`, the Step 1 blocks apply verbatim).

- [ ] **Step 3: Docs**

In `docs/guide/import-export.md`, add a subsection to the import formats section (match the page's existing heading level and voice):

```markdown
### Aqualung DiverLog+ / DiverLog (DAN DL7)

Submersion imports DAN DL7 (`.zxu` / `.zxl`) files, including the extended
dive data DiverLog+ embeds in them: dive site and GPS, city/state/country,
tank pressures and gas mixes, ratings, dive stats, and dive computer
identity.

**Getting your data out of DiverLog+ (mobile):** the mobile app has no file
export. Sync your dives to DiveCloud from within DiverLog+, then sign in at
divecloud.net in a browser, select your dives, and choose Export. This
downloads a ZIP of per-dive `.zxu` files plus any attached photos.

**Importing:** drop the DiveCloud ZIP (or individual `.zxu` files) onto
Submersion, or use Transfer > File Import. Every dive in the archive is
imported in one pass, photos are attached to their dives automatically, and
dives you already downloaded from the same dive computer are flagged as
duplicates with consolidation offered.

**Desktop DiverLog:** the discontinued Full version can export `.zxu` files
directly (Export Dive Data > DL7 Standard); the Lite versions cannot export.
Lite users should Wi-Fi-sync to the mobile app and use the DiveCloud path.
```

- [ ] **Step 4: Verify the app still builds and analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!` (plists are not analyzed, but the l10n/adapters from earlier tasks must be clean).

Run: `plutil -lint ios/Runner/Info.plist && plutil -lint macos/Runner/Info.plist`
Expected: both print `OK`.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
dart format .
git add ios/Runner/Info.plist macos/Runner/Info.plist docs/guide/import-export.md
git commit -m "feat(import): register .zxu/.zxl document types and document DiverLog migration"
```

---

### Task 12: End-to-end verification

**Files:**
- Test: `test/features/universal_import/bulk_import_integration_test.dart` (extend) OR a focused new integration test if extending is disruptive — follow the existing file's harness.

**Interfaces:**
- Consumes: everything above.
- Produces: one integration test proving `.zxu` files flow through batch parse, merge, and dedup; a final clean gate.

- [ ] **Step 1: Add a DL7 batch integration test**

Open `test/features/universal_import/bulk_import_integration_test.dart`, copy its harness pattern (it drives `BatchParseService.parseAll` + `PayloadMerger` + `ImportDuplicateChecker` over fixture files), and add a group that:

1. Builds two `PickedImportFile` entries pointing at `test/features/universal_import/data/parsers/fixtures/dl7/diverlog_plus_synthetic.zxu` and `.../dl7_imperial.zxu` with `ImportFormat.danDl7` detections and `ImportFileStatus.pending`.
2. Runs `BatchParseService().parseAll(...)`, asserts both files come back `ImportFileStatus.parsed` with `diveCount` 1 each.
3. Merges with `const PayloadMerger().merge(result.parsed)` and asserts: 2 dives; the DiverLog dive's `sourceUuid` is `'4321_98765_20240612093000_42'`; site `uddfId` carries the `f0:` namespace prefix; `metadata['batchFileCount'] == 2`.
4. Runs the merged payload through `const ImportDuplicateChecker().check(...)` twice — the second run passing `existingSourceUuidByDiveId: {'existing-dive': '4321_98765_20240612093000_42'}` — and asserts the DiverLog dive is matched as a duplicate with score 1.0 the second time (exact key names per the existing tests in `test/features/universal_import/data/services/import_duplicate_checker_test.dart`).

- [ ] **Step 2: Run the integration test**

Run: `flutter test test/features/universal_import/bulk_import_integration_test.dart`
Expected: PASS.

- [ ] **Step 3: Full gate — every suite this feature touched, then analyze/format**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/diverlog-import
flutter test \
  test/features/universal_import/ \
  test/features/import_wizard/ \
  test/features/dive_import/domain/services/dive_matcher_test.dart
flutter analyze
dart format .
git status --short
```
Expected: all tests pass, `No issues found!`, no unformatted files, and the only untracked entries are the research artifacts (`fixtures/dl7/diverlog_real.zxu`, `DL7.zxu`, `pydl7_sample.zxu`, `research/`).

- [ ] **Step 4: Commit any stragglers**

```bash
git add -u
git commit -m "test(import): DL7 end-to-end batch integration coverage" --allow-empty-message || true
```
(Skip the commit entirely if `git status` is clean.)

---

## Deferred / follow-up (not in this plan)

- Validate `DiveCloudZipReader` heuristics against a REAL DiveCloud ZIP once Eric obtains DiveCloud access (spec's open risk). If the real layout differs, only `ZipExpansionService`'s matching rules change.
- Wiki user-guide page (GitHub wiki is the user-guide source of truth; the repo docs page from Task 11 is the docsify mirror) — sync manually after merge.
- `.zxl` demographic segment extraction (certs, buddy names) — parse-leniently is done; mapping is YAGNI until a real `.zxl` sample exists.
