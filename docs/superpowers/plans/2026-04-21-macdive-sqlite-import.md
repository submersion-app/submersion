# MacDive SQLite Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import directly from MacDive's Core Data SQLite database (`MacDive.sqlite`). Rich METADATA path — tags, critters, events, service records, full relationship graph, certifications, gear inventory.

**Scope adjustment (discovered during Task 4):** `ZDIVE.ZSAMPLES` is NOT bplist — MacDive uses a proprietary binary format (entropy 7.85 bits/byte, all 256 byte values present — either bit-packed+delta-encoded or compressed with a non-standard algorithm). Tried zlib/gzip/lzma at offsets 0/4/8/12 — nothing works. Reverse-engineering MacDive's sample format is out of M3 scope.

**Consequence:** M3 imports dive metadata only. `profile: []` is emitted for every dive. Users who want profile time-series data can use M1's UDDF import instead (which decodes profiles correctly from MacDive UDDF exports). SQLite import becomes the "rich metadata" path; UDDF remains the "sample data" path.

`ZDIVE.ZTIMEZONE` IS bplist (NSKeyedArchiver format with UID markers) — handled correctly by the bplist decoder from Tasks 1-3.

**Architecture:** Hand-rolled `BPlistDecoder` (binary plist v00) for decoding MacDive's BLOB columns (`ZRAWDATA`, `ZSAMPLES`, `ZTIMEZONE`). New `MacDiveDbReader` modeled on `ShearwaterDbReader` validates the schema and produces typed raw rows. New `MacDiveDiveMapper` joins the rows (dive ↔ site, dive ↔ buddy, dive ↔ tank ↔ gas, dive ↔ tag, dive ↔ critter) and maps them to a unified `ImportPayload`. Pipeline wiring mirrors Shearwater Cloud.

**Tech Stack:** Flutter, Dart 3, `sqlite3` package, `xml` (not needed for this plan), Riverpod, `flutter_test`.

**Dependencies:** Milestone 1 merged first (for `sourceUuid` schema and `IncomingDiveData` fields). Milestone 2 merged for `MacDiveValueMapper` and `MacDiveUnitConverter`.

**Sample data:** `/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite` (6.7 MB, 540 dives, full relationship graph).

---

## Milestone 3 Status — COMPLETE

- All 14 tasks landed; bplist decoder (Tasks 1-4) shipped with UID
  support after real-sample probing revealed NSKeyedArchiver format
  in ZTIMEZONE.
- ZSAMPLES profile-sample decoding **descoped** — MacDive uses a
  proprietary binary format (entropy 7.85 bits/byte; not bplist; not
  zlib/gzip/lzma at any reasonable offset). Users wanting profile
  samples should use M1's UDDF import. M3 is the "rich metadata"
  path; UDDF remains the "sample data" path.
- New `ImportFormat.macdiveSqlite` + source override. Detector
  chain: SQLite magic → Shearwater check → MacDive check → generic.
- `MacDiveDbReader` validates schema (ZDIVE + ZDIVESITE + ZGAS +
  ZTANKANDGAS) and returns typed row graph keyed by PK; junctions
  as dive_pk → related_pks maps. Filters null-FK tombstones in
  ZTANKANDGAS discovered on real data.
- `MacDiveDiveMapper` reuses M2's `MacDiveUnitConverter` and
  `MacDiveValueMapper`. Dive map keys match M2's `MacDiveXmlParser`
  exactly so the same `UddfEntityImporter` downstream consumes
  both sources uniformly.
- `ImportDuplicateChecker` now short-circuits on `source_uuid`
  when incoming dives match existing `dive_data_sources.source_uuid`.
  Separate parameter map keeps the `Dive` entity unchanged
  (multi-source-per-dive semantics preserved).
- Gated `@Tags(['real-data'])` test asserts against user's real
  6.7MB DB: 540 dives, 373 sites, 33 buddies, 39 tags, 32 gear —
  all with sourceUuid populated. Profile always empty per descope.
- Full test suite passes.

Next: M4 (Photos) extends M2's XML parser and M3's SQLite reader
to emit `imageRefs` on payloads and adds a photo-linking wizard
step.

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/core/utils/bplist/bplist_object.dart` | Sealed `BPlistObject` type: dict, array, string, int, real, bool, date, data, null. | Created |
| `lib/core/utils/bplist/bplist_decoder.dart` | Binary plist v00 decoder. Handles object tables, offset tables, trailer, CF-style dictionary/array layouts. | Created |
| `lib/features/universal_import/data/models/import_enums.dart` | Add `ImportFormat.macdiveSqlite`, `SourceOverrideOption`, `isSupported`. | Modified |
| `lib/features/universal_import/data/services/format_detector.dart` | No change (SQLite detection already exists at the binary layer; app discrimination happens in `_detectFormat`). | - |
| `lib/features/universal_import/data/services/macdive_db_reader.dart` | Validates schema, executes joined queries, decodes BLOBs, returns typed raw row lists. | Created |
| `lib/features/universal_import/data/services/macdive_raw_types.dart` | Typed raw row classes: `MacDiveRawDive`, `MacDiveRawSite`, `MacDiveRawBuddy`, `MacDiveRawTankAndGas`, `MacDiveRawTag`, `MacDiveRawGear`, `MacDiveRawCritter`, `MacDiveRawCertification`, `MacDiveRawServiceRecord`, `MacDiveRawEvent`. | Created |
| `lib/features/universal_import/data/services/macdive_dive_mapper.dart` | Joins raw rows and maps to `ImportPayload`-shaped maps. | Created |
| `lib/features/universal_import/data/parsers/macdive_sqlite_parser.dart` | Implements `ImportParser` for `ImportFormat.macdiveSqlite`. | Created |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Extend `_detectFormat` with MacDive check after Shearwater; add switch case to `_parserFor`. | Modified |
| `lib/features/universal_import/data/services/import_duplicate_checker.dart` | Add a first-pass `sourceUuid` match before content fuzzy match. | Modified |
| `test/core/utils/bplist/bplist_decoder_test.dart` | Golden-value decoding tests. | Created |
| `test/features/universal_import/data/services/macdive_db_reader_test.dart` | Synthesizes a 3-dive MacDive-shaped SQLite, round-trips. | Created |
| `test/features/universal_import/data/services/macdive_dive_mapper_test.dart` | Row-to-payload mapping tests. | Created |
| `test/features/universal_import/data/parsers/macdive_sqlite_parser_test.dart` | End-to-end tests with the synthetic fixture. | Created |
| `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart` | Gated integration test against user's 6.7MB sample. | Created |
| `test/fixtures/macdive_sqlite/build_synthetic_db.dart` | Helper that creates a tiny MacDive-shaped SQLite at test time. | Created |
| `test/fixtures/macdive_sqlite/bplist_samples/` | Checked-in redacted bplist BLOBs for golden tests. | Created |

---

## Task 1: `BPlistObject` type

**Files:**
- Create: `lib/core/utils/bplist/bplist_object.dart`

- [ ] **Step 1: Define the sealed class**

```dart
/// A decoded binary plist (v00) node. Core Data stores a small subset of
/// these forms: null, bool, int, real, string, data, date, dict, array.
sealed class BPlistObject {
  const BPlistObject();
}

class BPlistNull extends BPlistObject { const BPlistNull(); }
class BPlistBool extends BPlistObject { final bool value; const BPlistBool(this.value); }
class BPlistInt extends BPlistObject { final int value; const BPlistInt(this.value); }
class BPlistReal extends BPlistObject { final double value; const BPlistReal(this.value); }
class BPlistString extends BPlistObject { final String value; const BPlistString(this.value); }
class BPlistData extends BPlistObject {
  final List<int> value;
  const BPlistData(this.value);
}
class BPlistDate extends BPlistObject {
  /// NSDate reference: seconds since 2001-01-01 00:00:00 UTC.
  final double secondsSinceReference;
  const BPlistDate(this.secondsSinceReference);
  DateTime toDateTime() =>
      DateTime.utc(2001).add(Duration(microseconds: (secondsSinceReference * 1e6).round()));
}
class BPlistArray extends BPlistObject {
  final List<BPlistObject> value;
  const BPlistArray(this.value);
}
class BPlistDict extends BPlistObject {
  final Map<String, BPlistObject> value;
  const BPlistDict(this.value);
}

extension BPlistObjectConvenience on BPlistObject {
  String? get asString => this is BPlistString ? (this as BPlistString).value : null;
  int? get asInt => switch (this) {
    BPlistInt(:var value) => value,
    BPlistBool(:var value) => value ? 1 : 0,
    _ => null,
  };
  double? get asDouble => switch (this) {
    BPlistReal(:var value) => value,
    BPlistInt(:var value) => value.toDouble(),
    _ => null,
  };
  Map<String, BPlistObject>? get asMap =>
      this is BPlistDict ? (this as BPlistDict).value : null;
  List<BPlistObject>? get asList =>
      this is BPlistArray ? (this as BPlistArray).value : null;
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/core/utils/bplist/bplist_object.dart`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/core/utils/bplist/bplist_object.dart
git commit -m "feat(bplist): add BPlistObject tagged union"
```

---

## Task 2: `BPlistDecoder` — basic types

**Files:**
- Create: `lib/core/utils/bplist/bplist_decoder.dart`
- Create: `test/core/utils/bplist/bplist_decoder_test.dart`

Reference: <https://opensource.apple.com/source/CF/CF-550/CFBinaryPList.c>. Format is little-known but stable for v00. Layout: 8-byte magic `bplist00`, object table (variable), offset table, trailer (32 bytes, fixed).

- [ ] **Step 1: Write failing tests for magic validation**

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/bplist/bplist_decoder.dart';
import 'package:submersion/core/utils/bplist/bplist_object.dart';

void main() {
  test('throws on non-bplist input', () {
    expect(() => BPlistDecoder.decode(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<FormatException>()));
  });

  test('throws on wrong version', () {
    final bytes = Uint8List.fromList([
      0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x39, 0x39, // "bplist99"
    ]);
    expect(() => BPlistDecoder.decode(bytes), throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (decoder undefined).

- [ ] **Step 3: Skeleton**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/utils/bplist/bplist_object.dart';

/// Decoder for Apple binary property list v00 ("bplist00"). Supports the
/// subset of types observed in MacDive Core Data BLOBs: null, bool, int,
/// real, string (ASCII + UTF-16BE), data, date, dict, array. Sets and
/// UIDs are not supported — they throw FormatException.
class BPlistDecoder {
  final Uint8List _bytes;
  final int _trailerOffset;
  final int _offsetIntSize;
  final int _objectRefSize;
  final int _numObjects;
  final int _topObjectIndex;
  final int _offsetTableOffset;

  BPlistDecoder._(
    this._bytes, {
    required this.trailerOffset,
    required this.offsetIntSize,
    required this.objectRefSize,
    required this.numObjects,
    required this.topObjectIndex,
    required this.offsetTableOffset,
  })
      : _trailerOffset = trailerOffset,
        _offsetIntSize = offsetIntSize,
        _objectRefSize = objectRefSize,
        _numObjects = numObjects,
        _topObjectIndex = topObjectIndex,
        _offsetTableOffset = offsetTableOffset;

  final int trailerOffset, offsetIntSize, objectRefSize, numObjects,
      topObjectIndex, offsetTableOffset;

  /// Top-level decode: parses trailer, then returns the root object.
  static BPlistObject decode(Uint8List bytes) {
    if (bytes.length < 32 + 8) {
      throw const FormatException('File too small to be bplist');
    }
    // Magic: "bplist00"
    const magic = [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30];
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != magic[i]) {
        throw const FormatException('Not a bplist00 stream');
      }
    }
    final trailerOffset = bytes.length - 32;
    final offsetIntSize = bytes[trailerOffset + 6];
    final objectRefSize = bytes[trailerOffset + 7];
    final numObjects = _readBigEndianInt(bytes, trailerOffset + 8, 8);
    final topObjectIndex = _readBigEndianInt(bytes, trailerOffset + 16, 8);
    final offsetTableOffset = _readBigEndianInt(bytes, trailerOffset + 24, 8);

    final decoder = BPlistDecoder._(bytes,
      trailerOffset: trailerOffset,
      offsetIntSize: offsetIntSize,
      objectRefSize: objectRefSize,
      numObjects: numObjects,
      topObjectIndex: topObjectIndex,
      offsetTableOffset: offsetTableOffset,
    );
    return decoder._readObject(topObjectIndex);
  }

  int _offsetOfObject(int index) {
    final pos = _offsetTableOffset + index * _offsetIntSize;
    return _readBigEndianInt(_bytes, pos, _offsetIntSize);
  }

  BPlistObject _readObject(int index) {
    final offset = _offsetOfObject(index);
    final marker = _bytes[offset];
    final type = marker >> 4;
    final info = marker & 0x0F;

    switch (type) {
      case 0x0: // singletons
        switch (info) {
          case 0x0: return const BPlistNull();
          case 0x8: return const BPlistBool(false);
          case 0x9: return const BPlistBool(true);
          default: throw FormatException('Unknown marker 0x${marker.toRadixString(16)}');
        }
      case 0x1: // int
        final size = 1 << info; // 1, 2, 4, 8, 16
        return BPlistInt(_readBigEndianInt(_bytes, offset + 1, size));
      case 0x2: // real
        final size = 1 << info;
        return BPlistReal(_readBigEndianReal(_bytes, offset + 1, size));
      case 0x3: // date (8-byte big-endian double, seconds since 2001)
        return BPlistDate(_readBigEndianReal(_bytes, offset + 1, 8));
      case 0x4: // data
        final lenInfo = _readLenAndStart(offset, info);
        return BPlistData(_bytes.sublist(lenInfo.start, lenInfo.start + lenInfo.len));
      case 0x5: // ASCII string
        final li = _readLenAndStart(offset, info);
        return BPlistString(ascii.decode(
          _bytes.sublist(li.start, li.start + li.len),
          allowInvalid: true,
        ));
      case 0x6: // UTF-16BE string (len is char count)
        final li = _readLenAndStart(offset, info);
        final byteLen = li.len * 2;
        return BPlistString(_decodeUtf16Be(_bytes, li.start, byteLen));
      case 0xA: // array
        final li = _readLenAndStart(offset, info);
        final refs = <int>[];
        for (var i = 0; i < li.len; i++) {
          refs.add(_readBigEndianInt(
            _bytes, li.start + i * _objectRefSize, _objectRefSize,
          ));
        }
        return BPlistArray(refs.map(_readObject).toList(growable: false));
      case 0xD: // dictionary
        final li = _readLenAndStart(offset, info);
        final keys = <int>[];
        final values = <int>[];
        for (var i = 0; i < li.len; i++) {
          keys.add(_readBigEndianInt(
            _bytes, li.start + i * _objectRefSize, _objectRefSize,
          ));
        }
        for (var i = 0; i < li.len; i++) {
          values.add(_readBigEndianInt(
            _bytes, li.start + (li.len + i) * _objectRefSize, _objectRefSize,
          ));
        }
        final map = <String, BPlistObject>{};
        for (var i = 0; i < li.len; i++) {
          final key = _readObject(keys[i]);
          if (key is! BPlistString) {
            throw FormatException('Non-string dict key at object index $i');
          }
          map[key.value] = _readObject(values[i]);
        }
        return BPlistDict(map);
      default:
        throw FormatException(
          'Unsupported bplist type 0x${type.toRadixString(16)}',
        );
    }
  }

  _LenAndStart _readLenAndStart(int markerOffset, int info) {
    if (info != 0x0F) return _LenAndStart(info, markerOffset + 1);
    // Next byte is 0x1_ marker followed by N-byte big-endian length.
    final intMarker = _bytes[markerOffset + 1];
    final intSize = 1 << (intMarker & 0x0F);
    final len = _readBigEndianInt(_bytes, markerOffset + 2, intSize);
    return _LenAndStart(len, markerOffset + 2 + intSize);
  }

  static int _readBigEndianInt(Uint8List bytes, int offset, int size) {
    var value = 0;
    for (var i = 0; i < size; i++) {
      value = (value << 8) | bytes[offset + i];
    }
    return value;
  }

  static double _readBigEndianReal(Uint8List bytes, int offset, int size) {
    final bd = ByteData.sublistView(bytes, offset, offset + size);
    if (size == 4) return bd.getFloat32(0, Endian.big);
    if (size == 8) return bd.getFloat64(0, Endian.big);
    throw FormatException('Unsupported real size: $size');
  }

  static String _decodeUtf16Be(Uint8List bytes, int start, int byteLen) {
    final units = <int>[];
    for (var i = 0; i < byteLen; i += 2) {
      units.add((bytes[start + i] << 8) | bytes[start + i + 1]);
    }
    return String.fromCharCodes(units);
  }
}

class _LenAndStart {
  final int len;
  final int start;
  const _LenAndStart(this.len, this.start);
}
```

- [ ] **Step 4: Run tests for magic validation — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/bplist/bplist_decoder.dart test/core/utils/bplist/bplist_decoder_test.dart
git commit -m "feat(bplist): v00 decoder skeleton with trailer parsing"
```

---

## Task 3: Golden-value bplist tests

**Files:**
- Create: `test/fixtures/macdive_sqlite/bplist_samples/small_dict.bplist` (3-entry dict with int, string, date)
- Create: `test/fixtures/macdive_sqlite/bplist_samples/sample_array.bplist` (array of ints)
- Modify: `test/core/utils/bplist/bplist_decoder_test.dart`

- [ ] **Step 1: Create fixtures with Python**

Use Python's `plistlib` to generate known-good bplists (run these manually outside the test harness, then commit the resulting files):

```bash
python3 -c "
import plistlib
with open('test/fixtures/macdive_sqlite/bplist_samples/small_dict.bplist', 'wb') as f:
    plistlib.dump({'name': 'Perdix', 'count': 42, 'when': __import__('datetime').datetime(2024, 6, 1, 9, 0)}, f, fmt=plistlib.FMT_BINARY)
"

python3 -c "
import plistlib
with open('test/fixtures/macdive_sqlite/bplist_samples/sample_array.bplist', 'wb') as f:
    plistlib.dump([0.0, 10.5, 20.3, 30.1], f, fmt=plistlib.FMT_BINARY)
"
```

- [ ] **Step 2: Write failing tests**

```dart
test('decodes dict with string, int, date', () async {
  final bytes = await File('test/fixtures/macdive_sqlite/bplist_samples/small_dict.bplist').readAsBytes();
  final obj = BPlistDecoder.decode(Uint8List.fromList(bytes));
  expect(obj, isA<BPlistDict>());
  final dict = (obj as BPlistDict).value;
  expect(dict['name']?.asString, 'Perdix');
  expect(dict['count']?.asInt, 42);
  expect(dict['when'], isA<BPlistDate>());
  expect((dict['when'] as BPlistDate).toDateTime(),
      DateTime.utc(2024, 6, 1, 9, 0));
});

test('decodes array of reals', () async {
  final bytes = await File('test/fixtures/macdive_sqlite/bplist_samples/sample_array.bplist').readAsBytes();
  final obj = BPlistDecoder.decode(Uint8List.fromList(bytes));
  expect(obj, isA<BPlistArray>());
  final arr = (obj as BPlistArray).value;
  expect(arr.length, 4);
  expect(arr[0].asDouble, 0.0);
  expect(arr[1].asDouble, 10.5);
  expect(arr[3].asDouble, closeTo(30.1, 1e-6));
});
```

- [ ] **Step 3: Run — expect PASS**

If FAIL, debug against Python's output (hex-dump the file). Common gotchas: sign-extension of ints > 64 bits; offset-size variation (1, 2, 4, or 8 bytes).

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/macdive_sqlite/bplist_samples/ test/core/utils/bplist/bplist_decoder_test.dart
git commit -m "test(bplist): golden-value decode tests"
```

---

## Task 4: Decode real MacDive samples BLOB

**Files:**
- Add fixture: `test/fixtures/macdive_sqlite/bplist_samples/macdive_zsamples.bplist` — pulled from the user's real DB via:
  ```
  sqlite3 "/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite" \
    "SELECT writefile('/tmp/zsamples.bplist', ZSAMPLES) FROM ZDIVE WHERE ZSAMPLES IS NOT NULL LIMIT 1"
  cp /tmp/zsamples.bplist test/fixtures/macdive_sqlite/bplist_samples/macdive_zsamples.bplist
  ```
- Modify: `test/core/utils/bplist/bplist_decoder_test.dart`

- [ ] **Step 1: Write failing test**

```dart
test('decodes real MacDive ZSAMPLES BLOB into dict of arrays', () async {
  final bytes = await File('test/fixtures/macdive_sqlite/bplist_samples/macdive_zsamples.bplist').readAsBytes();
  final obj = BPlistDecoder.decode(Uint8List.fromList(bytes));
  expect(obj, isA<BPlistDict>());
  final dict = (obj as BPlistDict).value;
  // Keys to be confirmed by observation:
  expect(dict.keys, contains('times'));
  expect(dict['times'], isA<BPlistArray>());
  final times = (dict['times'] as BPlistArray).value;
  expect(times.length, greaterThan(10));
});
```

- [ ] **Step 2: Run**

Run: `flutter test test/core/utils/bplist/bplist_decoder_test.dart`
If the key isn't `times` — inspect: temporarily add `print(dict.keys)` to discover actual keys and update the assertion. Typical MacDive keys (to be confirmed): `"times"`, `"depths"`, `"pressures"`, `"temperatures"`, `"ppo2s"`, `"ndts"`.

- [ ] **Step 3: Document the observed schema**

Update the class-level doc comment on `BPlistDecoder` with the schema you discovered.

- [ ] **Step 4: Commit**

```bash
git commit -am "test(bplist): golden test for real MacDive ZSAMPLES BLOB"
```

---

## Task 5: Add `ImportFormat.macdiveSqlite`

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart`

- [ ] **Step 1: Write failing test**

Append to `import_enums_test.dart`:

```dart
test('MacDive SQLite is supported and has display name', () {
  expect(ImportFormat.macdiveSqlite.displayName, 'MacDive SQLite');
  expect(ImportFormat.macdiveSqlite.isSupported, isTrue);
});

test('SourceOverrideOption has MacDive (SQLite) entry', () {
  final match = SourceOverrideOption.supported.firstWhere(
    (o) => o.sourceApp == SourceApp.macdive && o.format == ImportFormat.macdiveSqlite,
  );
  expect(match.displayName, 'MacDive (SQLite)');
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Add enum + entry**

```dart
enum ImportFormat {
  csv, uddf, macdiveXml, macdiveSqlite, subsurfaceXml, divingLogXml, …
```

```dart
    macdiveSqlite => 'MacDive SQLite',
```

```dart
  bool get isSupported => switch (this) {
    csv || uddf || subsurfaceXml || fit || shearwaterDb ||
    macdiveXml || macdiveSqlite => true,
    _ => false,
  };
```

Add to `SourceOverrideOption.supported`:

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.macdive,
      format: ImportFormat.macdiveSqlite,
      displayName: 'MacDive (SQLite)',
    ),
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): add ImportFormat.macdiveSqlite enum + source override"
```

---

## Task 6: Raw row types

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_raw_types.dart`

- [ ] **Step 1: Define the types**

```dart
import 'dart:typed_data';

class MacDiveRawDive {
  final int pk;
  final String uuid;
  final String? identifier;
  final DateTime? rawDate;           // NSDate-derived UTC DateTime
  final Uint8List? timezoneBplist;   // NSTimeZone bplist
  final double? maxDepth;            // raw unit per DB metadata
  final double? averageDepth;
  final int? diveNumber;
  final int? repetitiveDiveNumber;
  final double? rating;
  final double? airTemp;
  final double? tempHigh;
  final double? tempLow;
  final double? cns;
  final double? surfaceInterval;
  final double? sampleInterval;
  final double? totalDuration;
  final double? setpointHigh;
  final double? setpointLow;
  final String? decoModel;
  final String? gasModel;
  final String? computer;
  final String? computerSerial;
  final String? notes;
  final String? weather;
  final String? surfaceConditions;
  final String? current;
  final String? entryType;
  final String? diveMaster;
  final String? diveOperator;
  final String? boatName;
  final String? boatCaptain;
  final String? personalMode;
  final String? altitudeMode;
  final String? signature;
  final String? visibility;
  final String? weight;
  final int? diveSiteFk;
  final int? certificationFk;
  final Uint8List? samplesBplist;
  final Uint8List? rawDataBplist;

  const MacDiveRawDive({
    required this.pk,
    required this.uuid,
    this.identifier,
    this.rawDate,
    this.timezoneBplist,
    this.maxDepth,
    this.averageDepth,
    this.diveNumber,
    this.repetitiveDiveNumber,
    this.rating,
    this.airTemp,
    this.tempHigh,
    this.tempLow,
    this.cns,
    this.surfaceInterval,
    this.sampleInterval,
    this.totalDuration,
    this.setpointHigh,
    this.setpointLow,
    this.decoModel,
    this.gasModel,
    this.computer,
    this.computerSerial,
    this.notes,
    this.weather,
    this.surfaceConditions,
    this.current,
    this.entryType,
    this.diveMaster,
    this.diveOperator,
    this.boatName,
    this.boatCaptain,
    this.personalMode,
    this.altitudeMode,
    this.signature,
    this.visibility,
    this.weight,
    this.diveSiteFk,
    this.certificationFk,
    this.samplesBplist,
    this.rawDataBplist,
  });
}

class MacDiveRawSite {
  final int pk;
  final String uuid;
  final String? name;
  final String? country;
  final String? location;
  final String? bodyOfWater;
  final String? waterType;
  final String? difficulty;
  final String? flag;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final String? notes;

  const MacDiveRawSite({
    required this.pk,
    required this.uuid,
    this.name, this.country, this.location, this.bodyOfWater,
    this.waterType, this.difficulty, this.flag,
    this.latitude, this.longitude, this.altitude, this.notes,
  });
}

class MacDiveRawBuddy {
  final int pk;
  final String uuid;
  final String? name;
  const MacDiveRawBuddy({required this.pk, required this.uuid, this.name});
}

class MacDiveRawTag {
  final int pk;
  final String uuid;
  final String? name;
  const MacDiveRawTag({required this.pk, required this.uuid, this.name});
}

class MacDiveRawGear {
  final int pk;
  final String uuid;
  final String? name;
  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? type;
  final double? weight;
  final double? price;
  final DateTime? datePurchase;
  final DateTime? dateNextService;
  final String? notes;
  final String? url;
  final String? warranty;

  const MacDiveRawGear({
    required this.pk,
    required this.uuid,
    this.name, this.manufacturer, this.model, this.serial, this.type,
    this.weight, this.price, this.datePurchase, this.dateNextService,
    this.notes, this.url, this.warranty,
  });
}

class MacDiveRawTank {
  final int pk;
  final String uuid;
  final String? name;
  final double? size;
  final double? workingPressure;
  final String? type;
  const MacDiveRawTank({required this.pk, required this.uuid,
    this.name, this.size, this.workingPressure, this.type});
}

class MacDiveRawGas {
  final int pk;
  final String uuid;
  final String? name;
  final double? oxygen;
  final double? helium;
  final double? maxPpO2;
  final double? minPpO2;
  const MacDiveRawGas({required this.pk, required this.uuid,
    this.name, this.oxygen, this.helium, this.maxPpO2, this.minPpO2});
}

class MacDiveRawTankAndGas {
  final int diveFk;
  final int tankFk;
  final int gasFk;
  final double? airStart;
  final double? airEnd;
  final double? duration;
  final bool isDouble;
  final int order;
  final String? supplyType;
  const MacDiveRawTankAndGas({
    required this.diveFk, required this.tankFk, required this.gasFk,
    this.airStart, this.airEnd, this.duration,
    this.isDouble = false, this.order = 0, this.supplyType,
  });
}

class MacDiveRawCritter {
  final int pk;
  final String uuid;
  final String? name;
  final String? species;
  final double? size;
  final String? notes;
  final String? imagePath;
  const MacDiveRawCritter({
    required this.pk, required this.uuid,
    this.name, this.species, this.size, this.notes, this.imagePath,
  });
}

class MacDiveRawCertification {
  final int pk;
  final String uuid;
  final String? name;
  final String? agency;
  final DateTime? attained;
  final DateTime? expiry;
  final String? instructorName;
  final String? instructorNumber;
  final String? cardFrontPath;
  final String? cardBackPath;
  const MacDiveRawCertification({
    required this.pk, required this.uuid,
    this.name, this.agency, this.attained, this.expiry,
    this.instructorName, this.instructorNumber,
    this.cardFrontPath, this.cardBackPath,
  });
}

class MacDiveRawServiceRecord {
  final int pk;
  final String uuid;
  final int gearFk;
  final DateTime? serviceDate;
  final String? servicedBy;
  final String? notes;
  const MacDiveRawServiceRecord({
    required this.pk, required this.uuid, required this.gearFk,
    this.serviceDate, this.servicedBy, this.notes,
  });
}

class MacDiveRawEvent {
  final int pk;
  final String uuid;
  final int? diveFk;
  final int? type;
  final double? time;
  final String? detail;
  const MacDiveRawEvent({
    required this.pk, required this.uuid,
    this.diveFk, this.type, this.time, this.detail,
  });
}

/// Root result of [MacDiveDbReader.readAll].
class MacDiveRawLogbook {
  final List<MacDiveRawDive> dives;
  final Map<int, MacDiveRawSite> sitesByPk;
  final Map<int, MacDiveRawBuddy> buddiesByPk;
  final Map<int, MacDiveRawTag> tagsByPk;
  final Map<int, MacDiveRawGear> gearByPk;
  final Map<int, MacDiveRawTank> tanksByPk;
  final Map<int, MacDiveRawGas> gasesByPk;
  final List<MacDiveRawTankAndGas> tankAndGases;
  final Map<int, MacDiveRawCritter> crittersByPk;
  final List<MacDiveRawCertification> certifications;
  final List<MacDiveRawServiceRecord> serviceRecords;
  final List<MacDiveRawEvent> events;
  final Map<int, List<int>> diveToBuddyPks;
  final Map<int, List<int>> diveToTagPks;
  final Map<int, List<int>> diveToGearPks;
  final Map<int, List<int>> diveToCritterPks;
  final String? unitsPreference;    // 'Imperial' or 'Metric' or null

  const MacDiveRawLogbook({
    required this.dives,
    required this.sitesByPk,
    required this.buddiesByPk,
    required this.tagsByPk,
    required this.gearByPk,
    required this.tanksByPk,
    required this.gasesByPk,
    required this.tankAndGases,
    required this.crittersByPk,
    required this.certifications,
    required this.serviceRecords,
    required this.events,
    required this.diveToBuddyPks,
    required this.diveToTagPks,
    required this.diveToGearPks,
    required this.diveToCritterPks,
    required this.unitsPreference,
  });
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/universal_import/data/services/macdive_raw_types.dart`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_raw_types.dart
git commit -m "feat(import): MacDive raw row types"
```

---

## Task 7: Synthetic DB builder

**Files:**
- Create: `test/fixtures/macdive_sqlite/build_synthetic_db.dart`

- [ ] **Step 1: Write the builder**

```dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

/// Creates a minimal MacDive-shaped SQLite database at [path], returning
/// the file. Populates 3 dives, 2 sites, 2 buddies, 2 gas mixes, 2 tanks,
/// 2 tags, and the relationship rows. ZRAWDATA/ZSAMPLES/ZTIMEZONE blobs
/// are NOT populated — tests that need them use the real-sample fixture.
File buildSyntheticMacDiveDb(String path) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final db = sqlite3.open(path);

  db.execute('''
    CREATE TABLE ZDIVE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZDIVENUMBER INTEGER, ZREPETITIVEDIVENUMBER INTEGER,
      ZRELATIONSHIPDIVESITE INTEGER,
      ZMAXDEPTH FLOAT, ZAVERAGEDEPTH FLOAT, ZTEMPHIGH FLOAT, ZTEMPLOW FLOAT,
      ZAIRTEMP FLOAT, ZCNS FLOAT, ZSURFACEINTERVAL FLOAT, ZSAMPLEINTERVAL FLOAT,
      ZTOTALDURATION FLOAT, ZRATING FLOAT,
      ZRAWDATE TIMESTAMP, ZUUID VARCHAR, ZIDENTIFIER VARCHAR,
      ZNOTES VARCHAR, ZWEATHER VARCHAR, ZSURFACECONDITIONS VARCHAR,
      ZCURRENT VARCHAR, ZENTRYTYPE VARCHAR, ZDIVEMASTER VARCHAR,
      ZDIVEOPERATOR VARCHAR, ZBOATNAME VARCHAR, ZBOATCAPTAIN VARCHAR,
      ZPERSONALMODE VARCHAR, ZALTITUDEMODE VARCHAR, ZSIGNATURE VARCHAR,
      ZVISIBILITY VARCHAR, ZWEIGHT VARCHAR, ZDECOMODEL VARCHAR,
      ZGASMODEL VARCHAR, ZCOMPUTER VARCHAR, ZCOMPUTERSERIAL VARCHAR,
      ZRAWDATA BLOB, ZSAMPLES BLOB, ZTIMEZONE BLOB );
    CREATE TABLE ZDIVESITE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZCOUNTRY VARCHAR, ZLOCATION VARCHAR,
      ZBODYOFWATER VARCHAR, ZWATERTYPE VARCHAR, ZDIFFICULTY VARCHAR,
      ZFLAG VARCHAR, ZNOTES VARCHAR, ZUUID VARCHAR,
      ZGPSLAT FLOAT, ZGPSLON FLOAT, ZALTITUDE FLOAT );
    CREATE TABLE ZBUDDY ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZUUID VARCHAR );
    CREATE TABLE Z_1RELATIONSHIPDIVE ( Z_1RELATIONSHIPBUDDIES INTEGER, Z_5RELATIONSHIPDIVE INTEGER );
    CREATE TABLE ZTAG ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZUUID VARCHAR, ZIMAGE VARCHAR );
    CREATE TABLE Z_5RELATIONSHIPTAGS ( Z_5RELATIONSHIPDIVES INTEGER, Z_17RELATIONSHIPTAGS INTEGER );
    CREATE TABLE ZGEARITEM ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZMANUFACTURER VARCHAR, ZMODEL VARCHAR, ZSERIAL VARCHAR,
      ZTYPE VARCHAR, ZWEIGHT FLOAT, ZPRICE FLOAT,
      ZDATEPURCHASE TIMESTAMP, ZDATENEXTSERVICE TIMESTAMP,
      ZNOTES VARCHAR, ZURL VARCHAR, ZWARRANTY VARCHAR, ZUUID VARCHAR );
    CREATE TABLE Z_5RELATIONSHIPGEARITEMS ( Z_5RELATIONSHIPGEARTODIVES INTEGER, Z_14RELATIONSHIPGEARITEMS INTEGER );
    CREATE TABLE ZGAS ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZOXYGEN FLOAT, ZHELIUM FLOAT, ZMAXPPO2 FLOAT, ZMINPPO2 FLOAT, ZUUID VARCHAR );
    CREATE TABLE ZTANK ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZNAME VARCHAR, ZSIZE FLOAT, ZWORKINGPRESSURE FLOAT, ZTYPE VARCHAR, ZUUID VARCHAR );
    CREATE TABLE ZTANKANDGAS ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
      ZRELATIONSHIPDIVE INTEGER, ZRELATIONSHIPTANK INTEGER, ZRELATIONSHIPGAS INTEGER,
      ZAIRSTART FLOAT, ZAIREND FLOAT, ZDURATION FLOAT, ZISDOUBLE INTEGER, ZORDER INTEGER, ZSUPPLYTYPE VARCHAR );
    CREATE TABLE ZMETADATA ( Z_PK INTEGER PRIMARY KEY, ZIDENTIFIER VARCHAR, ZALL VARCHAR );
  ''');

  // Insert 2 sites.
  db.execute('''INSERT INTO ZDIVESITE (Z_PK, ZNAME, ZCOUNTRY, ZLOCATION, ZWATERTYPE, ZGPSLAT, ZGPSLON, ZUUID) VALUES
    (1, 'Test Reef', 'Mexico', 'Baja California', 'saltwater', 24.12345, -110.54321, 'site-uuid-1'),
    (2, 'Freshwater Springs', 'USA', 'Florida', 'freshwater', 0.0, 0.0, 'site-uuid-2');''');

  // 2 buddies.
  db.execute('''INSERT INTO ZBUDDY (Z_PK, ZNAME, ZUUID) VALUES
    (1, 'Alice', 'buddy-uuid-1'),
    (2, 'Bob', 'buddy-uuid-2');''');

  // 2 tags.
  db.execute('''INSERT INTO ZTAG (Z_PK, ZNAME, ZUUID) VALUES
    (1, 'Reef', 'tag-uuid-1'),
    (2, 'Photography', 'tag-uuid-2');''');

  // 2 gas, 2 tanks.
  db.execute('''INSERT INTO ZGAS (Z_PK, ZNAME, ZOXYGEN, ZHELIUM, ZUUID) VALUES
    (1, 'EAN32', 0.32, 0, 'gas-uuid-1'),
    (2, 'EAN80', 0.80, 0, 'gas-uuid-2');''');
  db.execute('''INSERT INTO ZTANK (Z_PK, ZNAME, ZSIZE, ZWORKINGPRESSURE, ZUUID) VALUES
    (1, 'AL80', 77.4, 3000, 'tank-uuid-1'),
    (2, 'Steel 72', 72, 2400, 'tank-uuid-2');''');

  // 1 gear item.
  db.execute('''INSERT INTO ZGEARITEM (Z_PK, ZNAME, ZMANUFACTURER, ZMODEL, ZTYPE, ZUUID) VALUES
    (1, 'Hydros Pro', 'Scubapro', 'Hydros Pro', 'BCD', 'gear-uuid-1');''');

  // 3 dives, ZRAWDATE = NSDate seconds since 2001-01-01 UTC. Use 2024-06-01 09:00:00 UTC.
  const nsDateBase = 757420800.0; // rough, accept fuzz in tests
  db.execute('''INSERT INTO ZDIVE (Z_PK, ZDIVENUMBER, ZRELATIONSHIPDIVESITE,
      ZMAXDEPTH, ZTEMPHIGH, ZTEMPLOW, ZTOTALDURATION, ZRAWDATE, ZUUID, ZIDENTIFIER,
      ZNOTES, ZWEATHER, ZDIVEOPERATOR, ZBOATNAME) VALUES
    (1, 42, 1, 25.4, 26.5, 20.0, 2400, $nsDateBase, 'dive-uuid-1', '20240601090000-ABC',
       'Nice reef', 'Sunny', 'Test Operator', 'MV Test'),
    (2, 43, 1, 18.0, 25.0, 19.0, 1800, ${nsDateBase + 3600}, 'dive-uuid-2', '20240601100000-ABC',
       NULL, 'Sunny', 'Test Operator', 'MV Test'),
    (3, 44, 2, 12.0, 24.0, 22.0, 2100, ${nsDateBase + 86400}, 'dive-uuid-3', '20240602090000-ABC',
       'Springs', NULL, NULL, NULL);''');

  // Junctions: dive 1 + buddy 1; dive 2 + buddies 1,2; dive 3 + no buddy.
  db.execute('''INSERT INTO Z_1RELATIONSHIPDIVE VALUES (1, 1), (1, 2), (2, 2);''');
  // Dive-tag junctions.
  db.execute('''INSERT INTO Z_5RELATIONSHIPTAGS VALUES (1, 1), (1, 2), (2, 1);''');
  // Dive-gear junctions.
  db.execute('''INSERT INTO Z_5RELATIONSHIPGEARITEMS VALUES (1, 1);''');

  // TankAndGas.
  db.execute('''INSERT INTO ZTANKANDGAS (Z_PK, ZRELATIONSHIPDIVE, ZRELATIONSHIPTANK, ZRELATIONSHIPGAS,
      ZAIRSTART, ZAIREND, ZORDER, ZSUPPLYTYPE) VALUES
    (1, 1, 1, 1, 3000, 1000, 0, 'Open Circuit'),
    (2, 2, 1, 1, 3000, 900, 0, 'Open Circuit'),
    (3, 3, 2, 2, 2400, 500, 0, 'Open Circuit');''');

  // Units preference.
  db.execute('''INSERT INTO ZMETADATA (Z_PK, ZIDENTIFIER, ZALL) VALUES (1, 'SystemOfUnits', 'Metric');''');

  db.dispose();
  return f;
}
```

- [ ] **Step 2: Commit**

```bash
git add test/fixtures/macdive_sqlite/build_synthetic_db.dart
git commit -m "test(import): synthetic MacDive-shaped SQLite builder"
```

---

## Task 8: `MacDiveDbReader`

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_db_reader.dart`
- Create: `test/features/universal_import/data/services/macdive_db_reader_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';

import '../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late List<int> bytes;

  setUpAll(() async {
    final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/macdive_syn_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    bytes = await f.readAsBytes();
  });

  test('isMacDiveDb returns true for synthetic db', () async {
    expect(await MacDiveDbReader.isMacDiveDb(Uint8List.fromList(bytes)), isTrue);
  });

  test('isMacDiveDb returns false for non-MacDive SQLite', () async {
    // Build a minimal SQLite with unrelated tables.
    final tmp = File('${Directory.systemTemp.path}/not_macdive.sqlite');
    if (tmp.existsSync()) tmp.deleteSync();
    final db = sqlite3.open(tmp.path);
    db.execute('CREATE TABLE foo(id INTEGER);');
    db.dispose();
    final other = await tmp.readAsBytes();
    expect(await MacDiveDbReader.isMacDiveDb(Uint8List.fromList(other)), isFalse);
  });

  test('readAll returns 3 dives, 2 sites, 2 buddies, 2 tags, 1 gear', () async {
    final logbook = await MacDiveDbReader.readAll(Uint8List.fromList(bytes));
    expect(logbook.dives.length, 3);
    expect(logbook.sitesByPk.length, 2);
    expect(logbook.buddiesByPk.length, 2);
    expect(logbook.tagsByPk.length, 2);
    expect(logbook.gearByPk.length, 1);
    expect(logbook.tankAndGases.length, 3);
  });

  test('dive 1 has two buddies, dive 3 has none', () async {
    final logbook = await MacDiveDbReader.readAll(Uint8List.fromList(bytes));
    expect(logbook.diveToBuddyPks[1], containsAll([1, 2]));
    expect(logbook.diveToBuddyPks[3] ?? const [], isEmpty);
  });

  test('units preference read from ZMETADATA', () async {
    final logbook = await MacDiveDbReader.readAll(Uint8List.fromList(bytes));
    expect(logbook.unitsPreference, 'Metric');
  });

  test('NSDate-seconds-since-2001 is converted to UTC DateTime', () async {
    final logbook = await MacDiveDbReader.readAll(Uint8List.fromList(bytes));
    final dive = logbook.dives.first;
    expect(dive.rawDate, isNotNull);
    // 757420800 seconds after 2001-01-01 UTC = 2025-01-01-ish; check not-null.
    expect(dive.rawDate!.year, greaterThanOrEqualTo(2023));
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement the reader**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

class MacDiveDbReader {
  static const _requiredTables = ['ZDIVE', 'ZDIVESITE', 'ZGAS', 'ZTANKANDGAS'];

  static Future<bool> isMacDiveDb(Uint8List bytes) async {
    final tmp = _tmpPath();
    final file = File(tmp);
    try {
      await file.writeAsBytes(bytes);
      final db = sqlite3.open(tmp, mode: OpenMode.readOnly);
      try {
        final rows = db.select("SELECT name FROM sqlite_master WHERE type='table'");
        final tables = rows.map<String>((r) => r['name'] as String).toSet();
        return _requiredTables.every(tables.contains);
      } finally {
        db.dispose();
      }
    } catch (_) {
      return false;
    } finally {
      _delete(file);
    }
  }

  static Future<MacDiveRawLogbook> readAll(Uint8List bytes) async {
    final tmp = _tmpPath();
    final file = File(tmp);
    try {
      await file.writeAsBytes(bytes);
      final db = sqlite3.open(tmp, mode: OpenMode.readOnly);
      try {
        final units = _readUnitsPreference(db);
        final sites = _readSites(db);
        final buddies = _readBuddies(db);
        final tags = _readTags(db);
        final gear = _readGear(db);
        final tanks = _readTanks(db);
        final gases = _readGases(db);
        final critters = _readCritters(db);
        final certifications = _readCertifications(db);
        final serviceRecords = _readServiceRecords(db);
        final events = _readEvents(db);
        final tankAndGases = _readTankAndGases(db);
        final dives = _readDives(db);
        final buddyJunc = _readJunction(db, 'Z_1RELATIONSHIPDIVE', 'Z_5RELATIONSHIPDIVE', 'Z_1RELATIONSHIPBUDDIES');
        final tagJunc = _readJunction(db, 'Z_5RELATIONSHIPTAGS', 'Z_5RELATIONSHIPDIVES', 'Z_17RELATIONSHIPTAGS');
        final gearJunc = _readJunction(db, 'Z_5RELATIONSHIPGEARITEMS', 'Z_5RELATIONSHIPGEARTODIVES', 'Z_14RELATIONSHIPGEARITEMS');
        final critterJunc = _readJunction(db, 'Z_3RELATIONSHIPCRITTERTODIVE', 'Z_3RELATIONSHIPDIVETOCRITTER', 'Z_5RELATIONSHIPCRITTERTODIVE');

        return MacDiveRawLogbook(
          dives: dives,
          sitesByPk: {for (final s in sites) s.pk: s},
          buddiesByPk: {for (final b in buddies) b.pk: b},
          tagsByPk: {for (final t in tags) t.pk: t},
          gearByPk: {for (final g in gear) g.pk: g},
          tanksByPk: {for (final t in tanks) t.pk: t},
          gasesByPk: {for (final g in gases) g.pk: g},
          tankAndGases: tankAndGases,
          crittersByPk: {for (final c in critters) c.pk: c},
          certifications: certifications,
          serviceRecords: serviceRecords,
          events: events,
          diveToBuddyPks: buddyJunc,
          diveToTagPks: tagJunc,
          diveToGearPks: gearJunc,
          diveToCritterPks: critterJunc,
          unitsPreference: units,
        );
      } finally {
        db.dispose();
      }
    } finally {
      _delete(file);
    }
  }

  static String? _readUnitsPreference(Database db) {
    try {
      final rows = db.select("SELECT ZALL FROM ZMETADATA WHERE ZIDENTIFIER = 'SystemOfUnits'");
      if (rows.isEmpty) return null;
      return rows.first['ZALL'] as String?;
    } catch (_) {
      return null;
    }
  }

  static List<MacDiveRawSite> _readSites(Database db) {
    final rows = db.select('SELECT * FROM ZDIVESITE');
    return rows.map((r) => MacDiveRawSite(
      pk: r['Z_PK'] as int,
      uuid: (r['ZUUID'] as String?) ?? '',
      name: _str(r['ZNAME']),
      country: _str(r['ZCOUNTRY']),
      location: _str(r['ZLOCATION']),
      bodyOfWater: _str(r['ZBODYOFWATER']),
      waterType: _str(r['ZWATERTYPE']),
      difficulty: _str(r['ZDIFFICULTY']),
      flag: _str(r['ZFLAG']),
      latitude: _dbl(r['ZGPSLAT']),
      longitude: _dbl(r['ZGPSLON']),
      altitude: _dbl(r['ZALTITUDE']),
      notes: _str(r['ZNOTES']),
    )).toList();
  }

  static List<MacDiveRawBuddy> _readBuddies(Database db) =>
      db.select('SELECT Z_PK, ZUUID, ZNAME FROM ZBUDDY')
        .map((r) => MacDiveRawBuddy(pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '', name: _str(r['ZNAME'])))
        .toList();

  static List<MacDiveRawTag> _readTags(Database db) =>
      db.select('SELECT Z_PK, ZUUID, ZNAME FROM ZTAG')
        .map((r) => MacDiveRawTag(pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '', name: _str(r['ZNAME'])))
        .toList();

  static List<MacDiveRawGear> _readGear(Database db) {
    final rows = db.select('SELECT * FROM ZGEARITEM');
    return rows.map((r) => MacDiveRawGear(
      pk: r['Z_PK'] as int,
      uuid: (r['ZUUID'] as String?) ?? '',
      name: _str(r['ZNAME']),
      manufacturer: _str(r['ZMANUFACTURER']),
      model: _str(r['ZMODEL']),
      serial: _str(r['ZSERIAL']),
      type: _str(r['ZTYPE']),
      weight: _dbl(r['ZWEIGHT']),
      price: _dbl(r['ZPRICE']),
      datePurchase: _date(r['ZDATEPURCHASE']),
      dateNextService: _date(r['ZDATENEXTSERVICE']),
      notes: _str(r['ZNOTES']),
      url: _str(r['ZURL']),
      warranty: _str(r['ZWARRANTY']),
    )).toList();
  }

  static List<MacDiveRawTank> _readTanks(Database db) =>
      db.select('SELECT * FROM ZTANK').map((r) => MacDiveRawTank(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        name: _str(r['ZNAME']), size: _dbl(r['ZSIZE']),
        workingPressure: _dbl(r['ZWORKINGPRESSURE']), type: _str(r['ZTYPE']),
      )).toList();

  static List<MacDiveRawGas> _readGases(Database db) =>
      db.select('SELECT * FROM ZGAS').map((r) => MacDiveRawGas(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        name: _str(r['ZNAME']), oxygen: _dbl(r['ZOXYGEN']),
        helium: _dbl(r['ZHELIUM']), maxPpO2: _dbl(r['ZMAXPPO2']),
        minPpO2: _dbl(r['ZMINPPO2']),
      )).toList();

  static List<MacDiveRawTankAndGas> _readTankAndGases(Database db) =>
      db.select('SELECT * FROM ZTANKANDGAS').map((r) => MacDiveRawTankAndGas(
        diveFk: r['ZRELATIONSHIPDIVE'] as int,
        tankFk: r['ZRELATIONSHIPTANK'] as int,
        gasFk: r['ZRELATIONSHIPGAS'] as int,
        airStart: _dbl(r['ZAIRSTART']),
        airEnd: _dbl(r['ZAIREND']),
        duration: _dbl(r['ZDURATION']),
        isDouble: (r['ZISDOUBLE'] as int? ?? 0) != 0,
        order: r['ZORDER'] as int? ?? 0,
        supplyType: _str(r['ZSUPPLYTYPE']),
      )).toList();

  static List<MacDiveRawCritter> _readCritters(Database db) {
    try {
      return db.select('SELECT * FROM ZCRITTER').map((r) => MacDiveRawCritter(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        name: _str(r['ZNAME']), species: _str(r['ZSPECIES']),
        size: _dbl(r['ZSIZE']), notes: _str(r['ZNOTES']),
        imagePath: _str(r['ZIMAGE']),
      )).toList();
    } catch (_) { return const []; }
  }

  static List<MacDiveRawCertification> _readCertifications(Database db) {
    try {
      return db.select('SELECT * FROM ZCERTIFICATION').map((r) => MacDiveRawCertification(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        name: _str(r['ZNAME']), agency: _str(r['ZAGENCY']),
        attained: _date(r['ZATTAINED']), expiry: _date(r['ZEXPIRY']),
        instructorName: _str(r['ZINSTRUCTORNAME']),
        instructorNumber: _str(r['ZINSTRUCTORNUMBER']),
        cardFrontPath: _str(r['ZCARDFRONT']),
        cardBackPath: _str(r['ZCARDBACK']),
      )).toList();
    } catch (_) { return const []; }
  }

  static List<MacDiveRawServiceRecord> _readServiceRecords(Database db) {
    try {
      return db.select('SELECT * FROM ZSERVICERECORD').map((r) => MacDiveRawServiceRecord(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        gearFk: r['ZRELATIONSHIPGEARITEM'] as int,
        serviceDate: _date(r['ZSERVICEDATE']),
        servicedBy: _str(r['ZSERVICEDBY']),
        notes: _str(r['ZNOTES']),
      )).toList();
    } catch (_) { return const []; }
  }

  static List<MacDiveRawEvent> _readEvents(Database db) {
    try {
      return db.select('SELECT * FROM ZEVENT').map((r) => MacDiveRawEvent(
        pk: r['Z_PK'] as int, uuid: (r['ZUUID'] as String?) ?? '',
        diveFk: r['ZRELATIONSHIPEVENTTODIVE'] as int?,
        type: r['ZTYPE'] as int?,
        time: _dbl(r['ZTIME']),
        detail: _str(r['ZDETAIL']),
      )).toList();
    } catch (_) { return const []; }
  }

  static List<MacDiveRawDive> _readDives(Database db) {
    final rows = db.select('SELECT * FROM ZDIVE');
    return rows.map((r) => MacDiveRawDive(
      pk: r['Z_PK'] as int,
      uuid: (r['ZUUID'] as String?) ?? '',
      identifier: _str(r['ZIDENTIFIER']),
      rawDate: _nsDate(_dbl(r['ZRAWDATE'])),
      timezoneBplist: _bytes(r['ZTIMEZONE']),
      maxDepth: _dbl(r['ZMAXDEPTH']),
      averageDepth: _dbl(r['ZAVERAGEDEPTH']),
      diveNumber: r['ZDIVENUMBER'] as int?,
      repetitiveDiveNumber: r['ZREPETITIVEDIVENUMBER'] as int?,
      rating: _dbl(r['ZRATING']),
      airTemp: _dbl(r['ZAIRTEMP']),
      tempHigh: _dbl(r['ZTEMPHIGH']),
      tempLow: _dbl(r['ZTEMPLOW']),
      cns: _dbl(r['ZCNS']),
      surfaceInterval: _dbl(r['ZSURFACEINTERVAL']),
      sampleInterval: _dbl(r['ZSAMPLEINTERVAL']),
      totalDuration: _dbl(r['ZTOTALDURATION']),
      setpointHigh: _dbl(r['ZSETPOINTHIGH']),
      setpointLow: _dbl(r['ZSETPOINTLOW']),
      decoModel: _str(r['ZDECOMODEL']),
      gasModel: _str(r['ZGASMODEL']),
      computer: _str(r['ZCOMPUTER']),
      computerSerial: _str(r['ZCOMPUTERSERIAL']),
      notes: _str(r['ZNOTES']),
      weather: _str(r['ZWEATHER']),
      surfaceConditions: _str(r['ZSURFACECONDITIONS']),
      current: _str(r['ZCURRENT']),
      entryType: _str(r['ZENTRYTYPE']),
      diveMaster: _str(r['ZDIVEMASTER']),
      diveOperator: _str(r['ZDIVEOPERATOR']),
      boatName: _str(r['ZBOATNAME']),
      boatCaptain: _str(r['ZBOATCAPTAIN']),
      personalMode: _str(r['ZPERSONALMODE']),
      altitudeMode: _str(r['ZALTITUDEMODE']),
      signature: _str(r['ZSIGNATURE']),
      visibility: _str(r['ZVISIBILITY']),
      weight: _str(r['ZWEIGHT']),
      diveSiteFk: r['ZRELATIONSHIPDIVESITE'] as int?,
      certificationFk: r['ZRELATIONSHIPCERTIFICATION'] as int?,
      samplesBplist: _bytes(r['ZSAMPLES']),
      rawDataBplist: _bytes(r['ZRAWDATA']),
    )).toList();
  }

  static Map<int, List<int>> _readJunction(
    Database db, String table, String left, String right,
  ) {
    final out = <int, List<int>>{};
    try {
      final rows = db.select('SELECT $left, $right FROM $table');
      for (final r in rows) {
        final l = r[left] as int;
        final rgt = r[right] as int;
        out.putIfAbsent(l, () => <int>[]).add(rgt);
      }
    } catch (_) {}
    return out;
  }

  static String _tmpPath() => '${Directory.systemTemp.path}/macdive_import_${DateTime.now().microsecondsSinceEpoch}.sqlite';
  static void _delete(File f) { try { if (f.existsSync()) f.deleteSync(); } catch (_) {} }
  static String? _str(dynamic v) { if (v == null) return null; final s = v.toString(); return s.isEmpty ? null : s; }
  static double? _dbl(dynamic v) { if (v == null) return null; if (v is num) return v.toDouble(); return double.tryParse(v.toString()); }
  static DateTime? _date(dynamic v) {
    final d = _dbl(v);
    return d == null ? null : _nsDate(d);
  }
  static DateTime? _nsDate(double? s) {
    if (s == null) return null;
    return DateTime.utc(2001).add(Duration(microseconds: (s * 1e6).round()));
  }
  static Uint8List? _bytes(dynamic v) {
    if (v == null) return null;
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return null;
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): MacDiveDbReader for MacDive SQLite schema"
```

---

## Task 9: `MacDiveDiveMapper`

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_dive_mapper.dart`
- Create: `test/features/universal_import/data/services/macdive_dive_mapper_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('maps synthetic raw logbook to ImportPayload with 3 dives, 2 sites, 2 buddies, 2 tags, 1 gear', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final bytes = Uint8List.fromList(await f.readAsBytes());
  final logbook = await MacDiveDbReader.readAll(bytes);
  final payload = MacDiveDiveMapper.toPayload(logbook);
  expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
  expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
  expect(payload.entitiesOf(ImportEntityType.buddies).length, 2);
  expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
  expect(payload.entitiesOf(ImportEntityType.equipment).length, 1);
});

test('dive 1 carries buddyRefs for buddy-uuid-1 and buddy-uuid-2', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final bytes = Uint8List.fromList(await f.readAsBytes());
  final logbook = await MacDiveDbReader.readAll(bytes);
  final payload = MacDiveDiveMapper.toPayload(logbook);
  final dive1 = payload.entitiesOf(ImportEntityType.dives).firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
  expect(dive1['buddyRefs'], containsAll(['buddy-uuid-1', 'buddy-uuid-2']));
});

test('dive 1 has tank pressures and gas mix from ZTANKANDGAS', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final bytes = Uint8List.fromList(await f.readAsBytes());
  final logbook = await MacDiveDbReader.readAll(bytes);
  final payload = MacDiveDiveMapper.toPayload(logbook);
  final dive1 = payload.entitiesOf(ImportEntityType.dives).firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
  final tanks = dive1['tanks'] as List;
  expect(tanks, hasLength(1));
  expect(tanks.first['gasMix']['o2'], closeTo(0.32, 1e-6));
  expect(tanks.first['startPressure'], closeTo(3000, 0.01));
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_converter.dart';
import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart'
  show MacDiveUnitSystem;

class MacDiveDiveMapper {
  const MacDiveDiveMapper._();

  static ImportPayload toPayload(MacDiveRawLogbook logbook) {
    final units = MacDiveUnitSystem.fromXml(logbook.unitsPreference);
    final c = MacDiveUnitConverter(units);

    final siteMaps = <Map<String, dynamic>>[];
    for (final s in logbook.sitesByPk.values) {
      final m = <String, dynamic>{};
      if (s.uuid.isNotEmpty) m['sourceUuid'] = s.uuid;
      if (s.name != null) m['name'] = s.name;
      if (s.country != null) m['country'] = s.country;
      if (s.location != null) m['region'] = s.location;
      if (s.bodyOfWater != null) m['bodyOfWater'] = s.bodyOfWater;
      if (s.waterType != null) m['waterType'] = s.waterType;
      if (s.difficulty != null) m['difficulty'] = s.difficulty;
      if (s.flag != null) m['flag'] = s.flag;
      if (s.altitude != null) m['altitude'] = c.depthToMeters(s.altitude);
      final lat = s.latitude;
      final lon = s.longitude;
      if (lat != null && lon != null && !(lat == 0.0 && lon == 0.0)) {
        m['latitude'] = lat;
        m['longitude'] = lon;
      }
      if (s.notes != null) m['description'] = s.notes;
      siteMaps.add(m);
    }

    final buddyMaps = logbook.buddiesByPk.values.map((b) => {
      if (b.uuid.isNotEmpty) 'sourceUuid': b.uuid,
      if (b.name != null) 'name': b.name,
    }).toList();

    final tagMaps = logbook.tagsByPk.values.map((t) => {
      if (t.uuid.isNotEmpty) 'sourceUuid': t.uuid,
      if (t.name != null) 'name': t.name,
    }).toList();

    final gearMaps = logbook.gearByPk.values.map((g) => {
      if (g.uuid.isNotEmpty) 'sourceUuid': g.uuid,
      if (g.name != null) 'name': g.name,
      if (g.manufacturer != null) 'manufacturer': g.manufacturer,
      if (g.model != null) 'model': g.model,
      if (g.serial != null) 'serialNumber': g.serial,
      if (g.type != null) 'type': g.type,
      if (g.weight != null) 'weight': c.weightToKg(g.weight),
      if (g.price != null) 'price': g.price,
      if (g.datePurchase != null) 'purchaseDate': g.datePurchase,
      if (g.dateNextService != null) 'nextServiceDate': g.dateNextService,
      if (g.notes != null) 'notes': g.notes,
    }).toList();

    final diveMaps = <Map<String, dynamic>>[];
    for (final d in logbook.dives) {
      final m = <String, dynamic>{};
      if (d.uuid.isNotEmpty) m['sourceUuid'] = d.uuid;
      if (d.identifier != null) m['sourceIdentifier'] = d.identifier;
      if (d.rawDate != null) m['dateTime'] = d.rawDate;
      if (d.diveNumber != null) m['diveNumber'] = d.diveNumber;
      if (d.repetitiveDiveNumber != null) m['diveNumberOfDay'] = d.repetitiveDiveNumber;
      if (d.maxDepth != null) m['maxDepth'] = c.depthToMeters(d.maxDepth);
      if (d.averageDepth != null) m['avgDepth'] = c.depthToMeters(d.averageDepth);
      if (d.totalDuration != null) m['runtime'] = Duration(seconds: d.totalDuration!.round());
      if (d.surfaceInterval != null) m['surfaceInterval'] = Duration(seconds: d.surfaceInterval!.round());
      if (d.tempLow != null) m['waterTemp'] = c.tempToCelsius(d.tempLow);
      if (d.airTemp != null) m['airTemp'] = c.tempToCelsius(d.airTemp);
      if (d.cns != null) m['cns'] = d.cns;
      if (d.decoModel != null) m['decoModel'] = d.decoModel;
      if (d.gasModel != null) m['gasModel'] = d.gasModel;
      if (d.computer != null) m['diveComputerModel'] = d.computer;
      if (d.computerSerial != null) m['diveComputerSerial'] = d.computerSerial;
      if (d.notes != null) m['notes'] = d.notes;
      if (d.weather != null) m['weather'] = d.weather;
      if (d.surfaceConditions != null) m['surfaceConditions'] = d.surfaceConditions;
      if (d.current != null) m['currentDirection'] = d.current;
      if (d.entryType != null) m['entryMethod'] = d.entryType;
      if (d.diveMaster != null) m['diveMaster'] = d.diveMaster;
      if (d.diveOperator != null) m['diveOperator'] = d.diveOperator;
      if (d.boatName != null) m['boatName'] = d.boatName;
      if (d.boatCaptain != null) m['boatCaptain'] = d.boatCaptain;
      if (d.personalMode != null) m['personalMode'] = d.personalMode;
      if (d.altitudeMode != null) m['altitudeMode'] = d.altitudeMode;
      if (d.signature != null) m['signature'] = d.signature;
      if (d.visibility != null) m['visibility'] = d.visibility;
      if (d.rating != null) m['rating'] = d.rating!.round();

      // Site FK -> siteRef (by site UUID)
      if (d.diveSiteFk != null) {
        final site = logbook.sitesByPk[d.diveSiteFk];
        if (site != null && site.uuid.isNotEmpty) m['siteRef'] = site.uuid;
      }
      // Buddy junction -> buddyRefs
      final buddyPks = logbook.diveToBuddyPks[d.pk] ?? const [];
      if (buddyPks.isNotEmpty) {
        m['buddyRefs'] = [
          for (final bp in buddyPks)
            if (logbook.buddiesByPk[bp] != null) logbook.buddiesByPk[bp]!.uuid,
        ].where((u) => u.isNotEmpty).toList();
      }
      // Tag junction -> tagRefs (by tag name, which is how UDDF import resolves them)
      final tagPks = logbook.diveToTagPks[d.pk] ?? const [];
      if (tagPks.isNotEmpty) {
        m['tagRefs'] = [
          for (final tp in tagPks)
            if (logbook.tagsByPk[tp]?.name != null) logbook.tagsByPk[tp]!.name!,
        ];
      }
      // Gear junction -> equipmentRefs
      final gearPks = logbook.diveToGearPks[d.pk] ?? const [];
      if (gearPks.isNotEmpty) {
        m['equipmentRefs'] = [
          for (final gp in gearPks)
            if (logbook.gearByPk[gp]?.uuid.isNotEmpty == true) logbook.gearByPk[gp]!.uuid,
        ];
      }

      // Tanks: join ZTANKANDGAS for this dive
      final tankRows = logbook.tankAndGases.where((t) => t.diveFk == d.pk).toList();
      if (tankRows.isNotEmpty) {
        final tanks = <Map<String, dynamic>>[];
        for (final t in tankRows) {
          final tank = logbook.tanksByPk[t.tankFk];
          final gas = logbook.gasesByPk[t.gasFk];
          tanks.add({
            'index': t.order,
            if (tank?.name != null) 'name': tank!.name,
            if (tank?.size != null) 'volumeL': c.tankSizeLiters(tank!.size, tank.workingPressure),
            if (tank?.workingPressure != null) 'workingPressureBar': c.pressureToBar(tank!.workingPressure),
            if (t.airStart != null) 'startPressure': c.pressureToBar(t.airStart),
            if (t.airEnd != null) 'endPressure': c.pressureToBar(t.airEnd),
            if (t.duration != null) 'runtime': Duration(seconds: t.duration!.round()),
            if (t.supplyType != null) 'supplyType': t.supplyType,
            'gasMix': {
              if (gas?.oxygen != null) 'o2': gas!.oxygen,
              if (gas?.helium != null) 'he': gas!.helium,
            },
          });
        }
        m['tanks'] = tanks;
      }

      diveMaps.add(m);
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveMaps.isNotEmpty) entities[ImportEntityType.dives] = diveMaps;
    if (siteMaps.isNotEmpty) entities[ImportEntityType.sites] = siteMaps;
    if (buddyMaps.isNotEmpty) entities[ImportEntityType.buddies] = buddyMaps;
    if (tagMaps.isNotEmpty) entities[ImportEntityType.tags] = tagMaps;
    if (gearMaps.isNotEmpty) entities[ImportEntityType.equipment] = gearMaps;

    return ImportPayload(
      entities: entities,
      warnings: const [],
      metadata: {'source': 'macdive_sqlite', 'diveCount': logbook.dives.length},
    );
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): MacDiveDiveMapper joins raw rows into ImportPayload"
```

---

## Task 10: `MacDiveSqliteParser`

**Files:**
- Create: `lib/features/universal_import/data/parsers/macdive_sqlite_parser.dart`
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_parser_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('parses synthetic MacDive SQLite end-to-end', () async {
  final f = buildSyntheticMacDiveDb(
      '${Directory.systemTemp.path}/msp_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final bytes = Uint8List.fromList(await f.readAsBytes());
  final payload = await MacDiveSqliteParser().parse(bytes);
  expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
});

test('returns error payload on non-MacDive SQLite', () async {
  final tmp = File('${Directory.systemTemp.path}/random.sqlite');
  if (tmp.existsSync()) tmp.deleteSync();
  final db = sqlite3.open(tmp.path);
  db.execute('CREATE TABLE foo(id INTEGER);');
  db.dispose();
  final payload = await MacDiveSqliteParser().parse(Uint8List.fromList(await tmp.readAsBytes()));
  expect(payload.isEmpty, isTrue);
  expect(payload.warnings, isNotEmpty);
  expect(payload.warnings.first.severity, ImportWarningSeverity.error);
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';

class MacDiveSqliteParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.macdiveSqlite];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final valid = await MacDiveDbReader.isMacDiveDb(fileBytes);
    if (!valid) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'File is not a MacDive SQLite database. Expected ZDIVE, ZDIVESITE, ZGAS, and ZTANKANDGAS tables.',
          ),
        ],
      );
    }
    try {
      final logbook = await MacDiveDbReader.readAll(fileBytes);
      if (logbook.dives.isEmpty) {
        return const ImportPayload(
          entities: {},
          warnings: [
            ImportWarning(
              severity: ImportWarningSeverity.info,
              message: 'MacDive database contains no dives.',
            ),
          ],
        );
      }
      return MacDiveDiveMapper.toPayload(logbook);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to read MacDive database: $e',
          ),
        ],
      );
    }
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): MacDiveSqliteParser implements ImportParser"
```

---

## Task 11: Wire into `_detectFormat` and `_parserFor`

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`

- [ ] **Step 1: Write failing integration test**

```dart
test('pickFile with MacDive SQLite detects format and produces payload', () async {
  final f = buildSyntheticMacDiveDb('${Directory.systemTemp.path}/mspw_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  final bytes = Uint8List.fromList(await f.readAsBytes());

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = container.read(universalImportNotifierProvider.notifier);

  await notifier.loadFileFromBytes(bytes, 'MacDive.sqlite');
  await notifier.confirmSource();

  final state = container.read(universalImportNotifierProvider);
  expect(state.detectionResult?.format, ImportFormat.macdiveSqlite);
  expect(state.payload?.entitiesOf(ImportEntityType.dives).length, 3);
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Extend `_detectFormat`**

```dart
Future<DetectionResult> _detectFormat(Uint8List bytes) async {
  const detector = FormatDetector();
  var detection = detector.detect(bytes);

  if (detection.format == ImportFormat.sqlite) {
    if (await ShearwaterDbReader.isShearwaterCloudDb(bytes)) {
      detection = const DetectionResult(
        format: ImportFormat.shearwaterDb,
        sourceApp: SourceApp.shearwater,
        confidence: 0.95,
      );
    } else if (await MacDiveDbReader.isMacDiveDb(bytes)) {
      detection = const DetectionResult(
        format: ImportFormat.macdiveSqlite,
        sourceApp: SourceApp.macdive,
        confidence: 0.95,
      );
    }
  }
  return detection;
}
```

- [ ] **Step 4: Add the switch case**

```dart
return switch (format) {
  ImportFormat.csv => CsvImportParser(…),
  ImportFormat.uddf => UddfImportParser(),
  ImportFormat.macdiveXml => MacDiveXmlParser(),
  ImportFormat.macdiveSqlite => MacDiveSqliteParser(),   // <-- NEW
  ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
  ImportFormat.fit => const FitImportParser(),
  ImportFormat.shearwaterDb => ShearwaterCloudParser(),
  _ => const PlaceholderParser(),
};
```

Add imports at the top.

- [ ] **Step 5: Run — expect PASS.**

- [ ] **Step 6: Commit**

```bash
git commit -am "feat(import): wire MacDiveSqliteParser into pipeline with SQLite kind detection"
```

---

## Task 12: Source-UUID-based duplicate matching

**Files:**
- Modify: `lib/features/universal_import/data/services/import_duplicate_checker.dart`
- Modify: `test/features/universal_import/data/services/import_duplicate_checker_test.dart`

- [ ] **Step 1: Write failing test**

```dart
test('matches dive by sourceUuid even when content differs', () {
  final existing = [
    Dive(id: 'existing-1', dateTime: DateTime(2024, 6, 1), maxDepth: 25.0, sourceUuid: 'dive-uuid-1', …),
  ];
  final payload = ImportPayload(entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'dive-uuid-1', 'dateTime': DateTime(2024, 6, 2), 'maxDepth': 10.0},
    ],
  });
  final result = const ImportDuplicateChecker().check(
    payload: payload, existingDives: existing, /* … */
  );
  expect(result.diveMatches, contains(0));
});
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Extend the checker**

In `check()`, before content fuzzy matching, add:

```dart
// Pass 1: exact source_uuid match takes precedence.
final existingBySourceUuid = <String, Dive>{
  for (final d in existingDives)
    if (d.sourceUuid != null && d.sourceUuid!.isNotEmpty) d.sourceUuid!: d,
};
for (var i = 0; i < diveItems.length; i++) {
  final uuid = diveItems[i]['sourceUuid'] as String?;
  if (uuid != null && existingBySourceUuid.containsKey(uuid)) {
    diveMatches[i] = DiveMatchResult.exact(existingBySourceUuid[uuid]!);
  }
}
```

Do the same for sites, buddies, etc. (each has a `sourceUuid` field now).

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(import): duplicate checker matches entities by sourceUuid first"
```

---

## Task 13: Real-sample integration test

**Files:**
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`

- [ ] **Step 1: Write gated test**

```dart
@Tags(['real-data'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';

const _path =
  '/Users/ericgriffin/Documents/submersion development/submersion data/Macdive/MacDive.sqlite';

void main() {
  test('imports 540 dives from real MacDive SQLite', () async {
    final file = File(_path);
    if (!file.existsSync()) {
      markTestSkipped('Real sample not present');
      return;
    }
    final bytes = Uint8List.fromList(await file.readAsBytes());
    final payload = await MacDiveSqliteParser().parse(bytes);
    expect(payload.entitiesOf(ImportEntityType.dives).length, 540);
    expect(payload.entitiesOf(ImportEntityType.sites).length, greaterThanOrEqualTo(370));
    expect(payload.entitiesOf(ImportEntityType.tags).length, 39);
    expect(payload.entitiesOf(ImportEntityType.buddies).length, greaterThanOrEqualTo(30));
  });
}
```

- [ ] **Step 2: Run — expect PASS.**

Run: `flutter test --tags=real-data test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`

- [ ] **Step 3: Commit**

```bash
git commit -am "test(import): MacDive SQLite real-sample regression"
```

---

## Task 14: CHANGELOG + final sweep

- [ ] **Step 1: Update CHANGELOG**

```markdown
### Added
- Support for importing MacDive's SQLite database directly. All dives,
  sites, buddies, gear, tags, tank/gas pressures, and critters transfer
  without a MacDive export step.
- Cross-format import deduplication by source UUID: re-importing the
  same MacDive dives in a different format no longer produces duplicates.
```

- [ ] **Step 2: Final sweep**

```
dart format lib/ test/
flutter analyze
flutter test
flutter test --tags=real-data
```

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: changelog for MacDive SQLite import"
```

---

## Self-Review Checklist

- [x] Spec requirement "schema detection for MacDive" → Task 8 (`isMacDiveDb`).
- [x] Spec requirement "bplist decoder" → Tasks 1-4.
- [x] Spec requirement "unit conversion" → Milestone 2's `MacDiveUnitConverter`, used by `MacDiveDiveMapper` in Task 9.
- [x] Spec requirement "sourceUuid-based dedup" → Task 12.
- [x] Spec requirement "ZSAMPLES profile" — **deferred**. The decoder is in place (Task 4 verifies it decodes), but `MacDiveDiveMapper` does not yet attach `profile` to the dive map. Add Task 9.5 in a separate follow-up PR once real-world key names are confirmed.
- [x] Tests use the synthetic builder for fast CI; real-sample test is tagged and skipped in CI by default.
- [x] Each new field has a failing test before implementation.
- [x] The `MacDiveValueMapper` from Milestone 2 is reused, not duplicated.

## Notes for the executor

- `flutter test` needs `sqlite3_flutter_libs` available as a dev dep; it should already be in `pubspec.yaml` from the Shearwater Cloud work.
- When rebuilding the synthetic DB in a test, always write to a unique path (`DateTime.now().microsecondsSinceEpoch`) — parallel tests on macOS otherwise race on file locks.
- Core Data's NSDate epoch is 2001-01-01 00:00:00 **UTC**. Don't localize.
- If you see warnings about `ZRAWDATA` or `ZSAMPLES` being non-null but empty: MacDive writes a placeholder bplist for dives without profile data. Treat as empty and carry on.
- ZRAWDATA/ZSAMPLES BLOB decoding → sample profile population is intentionally punted to a follow-up. Opening it in this milestone risks making the PR too large; the mapper has a clear integration point to receive decoded profile arrays later.
