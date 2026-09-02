# Profile Series Codec Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship PR 1 of the packed-series program: a pure-Dart, lossless, versioned codec that packs a dive's profile samples (and a tank's pressure samples) into one zlib-compressed columnar blob and back, together with the summary scalars the series tables will store.

**Architecture:** A small byte-level reader/writer (`byte_io.dart`) provides varints, zigzag signed varints, float64, and presence-bitmapped columns. `ProfileSeriesCodec` walks a fixed, versioned field table over a `ProfileSample` value type, writes one column block per field, and zlib-compresses the result; decoding reverses it strictly and throws `ProfileSeriesCodecException` on anything malformed. `TankPressureSeriesCodec` is the two-field sibling. Nothing in this PR touches the database, the repositories, or sync; the codec is consumed in PR 2.

**Tech Stack:** Dart 3 (records, switch expressions), `dart:typed_data`, `dart:io` `ZLibCodec`, `package:equatable`, `flutter_test`, Drift's generated table metadata (test only).

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md`, sections 3 (architecture), 5 (codec v1), 10 (codec tests), 11 (delivery: this is PR 1).

## Global Constraints

- Work only inside the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage` on branch `worktree-profile-sample-storage`. Every command below assumes `cd` into that directory first; the shell's working directory does not persist between commands.
- Never use an em-dash (U+2014) or an en-dash as punctuation anywhere: code, comments, tests, commit messages, this plan. Rewrite with a colon, comma, or two sentences.
- No emojis in code, comments, or documentation.
- Lints in force: `package:flutter_lints/flutter.yaml` plus `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `always_use_package_imports`. All imports of project files use the `package:submersion/...` form.
- Codec files under `lib/` import nothing from Drift or Flutter. Allowed: `dart:*`, `package:equatable`, `package:meta`, and the domain entity file `package:submersion/features/dive_log/domain/entities/dive.dart`.
- Codec v1 constants, verbatim from the spec: version byte `1`; real fields are float64 little-endian (lossless, never float32 or fixed point); integer fields are delta-encoded zigzag varints with the delta reset to 0 at the start of each block and taken from the last present value; presence modes are `0` absent, `1` all present, `2` bitmap (LSB-first within each byte); the whole body is zlib level 6. The 28-field table order is fixed in Task 4 and must not be reordered.
- Run tests per file (`flutter test <one file>`), never a whole directory; the Bash tool times out on directories. Never pipe `flutter test` through `grep` or `tail`: the exit code you see would be the pipe's, not the test run's.
- Before every commit run `dart format .` from the worktree root (the whole project, not a subdirectory) and `flutter analyze`. CI fails on a single unformatted file.
- Commit messages: conventional prefix (`feat:`, `test:`, `docs:`), no `Co-Authored-By` trailer, no session URL.
- Files stay small: none of the new files should exceed 400 lines.

---

## File structure

Create:

| file | responsibility |
|---|---|
| `lib/features/dive_log/domain/codecs/profile_series_codec_exception.dart` | the one exception type every decoder throws |
| `lib/features/dive_log/domain/codecs/byte_io.dart` | `ByteWriter`, `ByteReader`, varint/zigzag/float64, presence-bitmapped column blocks |
| `lib/features/dive_log/domain/codecs/profile_sample.dart` | `ProfileSample`, the 28-field value type the codec packs, with conversions to and from `DiveProfilePoint` |
| `lib/features/dive_log/domain/codecs/profile_series_summary.dart` | `ProfileSeriesSummary` and its computation from a sample list |
| `lib/features/dive_log/domain/codecs/profile_series_codec.dart` | `ProfileField`, `ProfileFieldKind`, the v1 field table, `EncodedProfileSeries`, `ProfileSeriesCodec` |
| `lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart` | `TankPressureSample`, `TankPressureSeriesSummary`, `EncodedTankPressureSeries`, `TankPressureSeriesCodec` |
| `test/features/dive_log/domain/codecs/byte_io_test.dart` | |
| `test/features/dive_log/domain/codecs/profile_sample_test.dart` | |
| `test/features/dive_log/domain/codecs/profile_series_summary_test.dart` | |
| `test/features/dive_log/domain/codecs/profile_series_codec_test.dart` | round trips, malformed input, forward tolerance |
| `test/features/dive_log/domain/codecs/profile_series_field_table_test.dart` | the field table enumerated against Drift's `dive_profiles` columns |
| `test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart` | |

Modify: nothing. This PR adds files only.

---

### Task 1: Exception type and byte reader/writer

**Files:**
- Create: `lib/features/dive_log/domain/codecs/profile_series_codec_exception.dart`
- Create: `lib/features/dive_log/domain/codecs/byte_io.dart`
- Test: `test/features/dive_log/domain/codecs/byte_io_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ProfileSeriesCodecException implements Exception { const ProfileSeriesCodecException(String message); final String message; }`
  - `class ByteWriter { int get length; void writeByte(int); void writeVarUint(int); void writeVarInt(int); void writeFloat64(double); void writeBytes(List<int>); Uint8List takeBytes(); }`
  - `class ByteReader { ByteReader(Uint8List bytes); int get offset; int get remaining; bool get isAtEnd; int readByte(); int readVarUint(); int readVarInt(); double readFloat64(); Uint8List readBytes(int count); }`
  - `extension ColumnWriter on ByteWriter { bool writePresence(List<Object?> values); void writeColumn<T extends Object>(List<T?> values, void Function(T value) writeValue); }`
  - `extension ColumnReader on ByteReader { List<bool> readPresence(int count); List<T?> readColumn<T extends Object>(int count, T Function() readValue); }`
  - Constants `kPresenceAbsent = 0`, `kPresenceAll = 1`, `kPresenceBitmap = 2`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/codecs/byte_io_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// The raw IEEE-754 bits, so -0.0 and NaN payloads compare exactly.
int bitsOf(double value) =>
    (ByteData(8)..setFloat64(0, value, Endian.little)).getInt64(
      0,
      Endian.little,
    );

void main() {
  group('varuint', () {
    for (final value in [
      0,
      1,
      127,
      128,
      255,
      300,
      16383,
      16384,
      1 << 31,
      (1 << 62) - 1,
    ]) {
      test('round-trips $value', () {
        final writer = ByteWriter()..writeVarUint(value);
        expect(ByteReader(writer.takeBytes()).readVarUint(), value);
      });
    }

    test('127 fits in one byte and 128 needs two', () {
      expect((ByteWriter()..writeVarUint(127)).takeBytes(), hasLength(1));
      expect((ByteWriter()..writeVarUint(128)).takeBytes(), hasLength(2));
    });
  });

  group('varint (zigzag)', () {
    for (final value in [
      0,
      -1,
      1,
      -2,
      2,
      -64,
      63,
      -65,
      64,
      -1000000,
      1000000,
      -(1 << 40),
      1 << 40,
    ]) {
      test('round-trips $value', () {
        final writer = ByteWriter()..writeVarInt(value);
        expect(ByteReader(writer.takeBytes()).readVarInt(), value);
      });
    }

    test('small negatives stay one byte', () {
      expect((ByteWriter()..writeVarInt(-1)).takeBytes(), hasLength(1));
      expect((ByteWriter()..writeVarInt(-64)).takeBytes(), hasLength(1));
      expect((ByteWriter()..writeVarInt(-65)).takeBytes(), hasLength(2));
    });
  });

  group('float64', () {
    for (final value in [
      0.0,
      -0.0,
      1.5,
      18.3,
      -273.15,
      double.maxFinite,
      double.minPositive,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('round-trips $value bit-exactly', () {
        final writer = ByteWriter()..writeFloat64(value);
        final bytes = writer.takeBytes();
        expect(bytes, hasLength(8));
        expect(bitsOf(ByteReader(bytes).readFloat64()), bitsOf(value));
      });
    }

    test('NaN round-trips as NaN', () {
      final writer = ByteWriter()..writeFloat64(double.nan);
      expect(ByteReader(writer.takeBytes()).readFloat64().isNaN, isTrue);
    });

    test('two consecutive floats do not alias each other', () {
      final writer = ByteWriter()
        ..writeFloat64(1.0)
        ..writeFloat64(2.0);
      final reader = ByteReader(writer.takeBytes());
      expect(reader.readFloat64(), 1.0);
      expect(reader.readFloat64(), 2.0);
    });
  });

  group('reader bounds', () {
    test('reading past the end throws', () {
      final reader = ByteReader(Uint8List.fromList([0x01]));
      reader.readByte();
      expect(reader.isAtEnd, isTrue);
      expect(reader.readByte, throwsA(isA<ProfileSeriesCodecException>()));
    });

    test('a float needs eight bytes', () {
      final reader = ByteReader(Uint8List.fromList([0, 0, 0, 0]));
      expect(reader.readFloat64, throwsA(isA<ProfileSeriesCodecException>()));
    });

    test('an unterminated varint throws', () {
      final reader = ByteReader(Uint8List.fromList([0x80, 0x80]));
      expect(reader.readVarUint, throwsA(isA<ProfileSeriesCodecException>()));
    });

    test('a varint longer than 64 bits throws', () {
      final reader = ByteReader(Uint8List.fromList(List.filled(11, 0x80)));
      expect(reader.readVarUint, throwsA(isA<ProfileSeriesCodecException>()));
    });

    test('readBytes past the end throws', () {
      final reader = ByteReader(Uint8List.fromList([1, 2, 3]));
      expect(
        () => reader.readBytes(4),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('offset and remaining track consumption', () {
      final reader = ByteReader(Uint8List.fromList([1, 2, 3]));
      reader.readByte();
      expect(reader.offset, 1);
      expect(reader.remaining, 2);
    });
  });

  group('columns', () {
    // Note: `writer` is declared on its own line in every case below. Dart
    // rejects a closure that names the variable being initialised
    // ("referenced before declaration"), so the cascade form cannot be used.

    test('an all-null column costs exactly one byte', () {
      final writer = ByteWriter();
      writer.writeColumn<int>([null, null, null], writer.writeVarInt);
      final bytes = writer.takeBytes();
      expect(bytes, [kPresenceAbsent]);
      final reader = ByteReader(bytes);
      expect(reader.readColumn<int>(3, reader.readVarInt), [null, null, null]);
      expect(reader.isAtEnd, isTrue);
    });

    test('a fully present column carries no bitmap', () {
      final writer = ByteWriter();
      writer.writeColumn<int>([5, 6, 7], writer.writeVarInt);
      final bytes = writer.takeBytes();
      expect(bytes.first, kPresenceAll);
      expect(bytes, hasLength(4));
      final reader = ByteReader(bytes);
      expect(reader.readColumn<int>(3, reader.readVarInt), [5, 6, 7]);
    });

    test('a mixed column uses a bitmap and round-trips across a byte edge', () {
      // Nine values force a two-byte bitmap.
      final values = <int?>[1, null, 3, null, null, 6, 7, null, 9];
      final writer = ByteWriter();
      writer.writeColumn<int>(values, writer.writeVarInt);
      final bytes = writer.takeBytes();
      expect(bytes.first, kPresenceBitmap);
      // mode + 2 bitmap bytes + 5 one-byte values
      expect(bytes, hasLength(8));
      final reader = ByteReader(bytes);
      expect(reader.readColumn<int>(9, reader.readVarInt), values);
      expect(reader.isAtEnd, isTrue);
    });

    test('float columns round-trip through the same presence logic', () {
      final values = <double?>[1.5, null, -2.25];
      final writer = ByteWriter();
      writer.writeColumn<double>(values, writer.writeFloat64);
      final reader = ByteReader(writer.takeBytes());
      expect(reader.readColumn<double>(3, reader.readFloat64), values);
    });

    test('an unknown presence mode throws', () {
      final reader = ByteReader(Uint8List.fromList([7]));
      expect(
        () => reader.readColumn<int>(1, reader.readVarInt),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an empty column writes only the absent marker', () {
      final writer = ByteWriter();
      writer.writeColumn<int>(const [], writer.writeVarInt);
      expect(writer.takeBytes(), [kPresenceAbsent]);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/codecs/byte_io_test.dart`
Expected: compilation failure, `Error: Couldn't resolve the package 'submersion/features/dive_log/domain/codecs/byte_io.dart'` (or "Target of URI doesn't exist").

- [ ] **Step 3: Create the exception type**

Create `lib/features/dive_log/domain/codecs/profile_series_codec_exception.dart`:

```dart
/// Thrown when a packed series blob cannot be decoded.
///
/// Decoders never guess. An unknown version byte, a truncated payload,
/// trailing bytes, or a block that disagrees with its field table all end
/// here rather than in a partial sample list.
class ProfileSeriesCodecException implements Exception {
  const ProfileSeriesCodecException(this.message);

  final String message;

  @override
  String toString() => 'ProfileSeriesCodecException: $message';
}
```

- [ ] **Step 4: Create the byte reader and writer**

Create `lib/features/dive_log/domain/codecs/byte_io.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// Presence mode for a column block: every value is null, no payload.
const int kPresenceAbsent = 0;

/// Presence mode for a column block: every value is present, no bitmap.
const int kPresenceAll = 1;

/// Presence mode for a column block: a bitmap of `ceil(n / 8)` bytes
/// (LSB-first within each byte) precedes the present values.
const int kPresenceBitmap = 2;

/// Append-only little-endian byte sink for the series codecs.
class ByteWriter {
  // copy: true (the default) matters: writeFloat64 hands the builder a view
  // of a reused scratch buffer, and a non-copying builder would alias every
  // float written to the same eight bytes.
  final BytesBuilder _builder = BytesBuilder();
  final ByteData _scratch = ByteData(8);

  int get length => _builder.length;

  void writeByte(int value) {
    assert(value >= 0 && value <= 0xFF, 'not a byte: $value');
    _builder.addByte(value);
  }

  /// Unsigned LEB128 varint: seven bits per byte, high bit set on all but
  /// the last byte.
  void writeVarUint(int value) {
    assert(value >= 0, 'varuint cannot encode $value');
    var remaining = value;
    while (remaining >= 0x80) {
      _builder.addByte((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    _builder.addByte(remaining);
  }

  /// Zigzag-mapped signed varint, so small negatives stay small: 0, -1, 1,
  /// -2, 2 map to 0, 1, 2, 3, 4.
  void writeVarInt(int value) => writeVarUint((value << 1) ^ (value >> 63));

  /// IEEE-754 binary64, little-endian, bit-exact.
  void writeFloat64(double value) {
    _scratch.setFloat64(0, value, Endian.little);
    _builder.add(_scratch.buffer.asUint8List(0, 8));
  }

  void writeBytes(List<int> bytes) => _builder.add(bytes);

  /// Returns everything written and resets the writer.
  Uint8List takeBytes() => _builder.takeBytes();
}

/// Strict forward-only reader over a byte buffer. Every read that would run
/// past the end throws [ProfileSeriesCodecException].
class ByteReader {
  ByteReader(Uint8List bytes)
    : _bytes = bytes,
      _data = ByteData.sublistView(bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;
  bool get isAtEnd => _offset >= _bytes.length;

  int readByte() {
    _ensure(1);
    return _bytes[_offset++];
  }

  int readVarUint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = readByte();
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const ProfileSeriesCodecException('varint longer than 64 bits');
      }
    }
  }

  int readVarInt() {
    final zigzag = readVarUint();
    return (zigzag >>> 1) ^ -(zigzag & 1);
  }

  double readFloat64() {
    _ensure(8);
    final value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  Uint8List readBytes(int count) {
    _ensure(count);
    final view = Uint8List.sublistView(_bytes, _offset, _offset + count);
    _offset += count;
    return view;
  }

  void _ensure(int count) {
    if (count < 0 || _offset + count > _bytes.length) {
      throw ProfileSeriesCodecException(
        'unexpected end of data: needed $count byte(s) at offset $_offset '
        'of ${_bytes.length}',
      );
    }
  }
}

/// Column blocks: a presence mode byte, an optional bitmap, then only the
/// present values in order.
extension ColumnWriter on ByteWriter {
  /// Writes the presence mode and, when needed, the bitmap. Returns whether
  /// any value is present, so the caller knows whether to write payload.
  bool writePresence(List<Object?> values) {
    var presentCount = 0;
    for (final value in values) {
      if (value != null) presentCount++;
    }
    if (presentCount == 0) {
      writeByte(kPresenceAbsent);
      return false;
    }
    if (presentCount == values.length) {
      writeByte(kPresenceAll);
      return true;
    }
    writeByte(kPresenceBitmap);
    final bitmap = Uint8List((values.length + 7) >> 3);
    for (var i = 0; i < values.length; i++) {
      if (values[i] != null) bitmap[i >> 3] |= 1 << (i & 7);
    }
    writeBytes(bitmap);
    return true;
  }

  /// Writes one column: presence, then [writeValue] for each present value
  /// in order. [writeValue] may keep state between calls (delta encoding).
  void writeColumn<T extends Object>(
    List<T?> values,
    void Function(T value) writeValue,
  ) {
    if (!writePresence(values)) return;
    for (final value in values) {
      if (value != null) writeValue(value);
    }
  }
}

extension ColumnReader on ByteReader {
  /// Reads a presence block for [count] values.
  List<bool> readPresence(int count) {
    final mode = readByte();
    switch (mode) {
      case kPresenceAbsent:
        return List<bool>.filled(count, false);
      case kPresenceAll:
        return List<bool>.filled(count, true);
      case kPresenceBitmap:
        final bitmap = readBytes((count + 7) >> 3);
        return [
          for (var i = 0; i < count; i++)
            ((bitmap[i >> 3] >> (i & 7)) & 1) == 1,
        ];
      default:
        throw ProfileSeriesCodecException('unknown presence mode $mode');
    }
  }

  /// Reads one column of [count] values, calling [readValue] once per
  /// present value in order. [readValue] may keep state between calls.
  List<T?> readColumn<T extends Object>(int count, T Function() readValue) {
    final present = readPresence(count);
    return [for (final isPresent in present) isPresent ? readValue() : null];
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/byte_io_test.dart`
Expected: all tests pass (around 45 cases).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/codecs/profile_series_codec_exception.dart lib/features/dive_log/domain/codecs/byte_io.dart test/features/dive_log/domain/codecs/byte_io_test.dart
git commit -m "feat: byte reader and writer for the profile series codec"
```

---

### Task 2: ProfileSample value type

**Files:**
- Create: `lib/features/dive_log/domain/codecs/profile_sample.dart`
- Test: `test/features/dive_log/domain/codecs/profile_sample_test.dart`

**Interfaces:**
- Consumes: `DiveProfilePoint` from `package:submersion/features/dive_log/domain/entities/dive.dart` (27 fields, no `pressure`).
- Produces: `class ProfileSample extends Equatable` with 28 fields matching the `dive_profiles` sample columns: `int timestamp`, `double depth`, `double? pressure`, `double? temperature`, `int? heartRate`, `double? ascentRate`, `double? ceiling`, `int? ndl`, `double? setpoint`, `double? ppO2`, `double? o2Sensor1` to `o2Sensor6`, `double? cns`, `int? tts`, `int? rbt`, `int? decoType`, `String? heartRateSource`, `double? heading`, `int? o2SensorMv1` to `o2SensorMv6`. Plus `factory ProfileSample.fromPoint(DiveProfilePoint point, {double? pressure})` and `DiveProfilePoint toPoint()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/domain/codecs/profile_sample_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const point = DiveProfilePoint(
    timestamp: 120,
    depth: 18.3,
    temperature: 21.5,
    heartRate: 88,
    heading: 270.0,
    setpoint: 1.2,
    ppO2: 1.19,
    o2Sensor1: 1.18,
    o2Sensor2: 1.2,
    o2Sensor3: 1.21,
    o2Sensor4: 1.17,
    o2Sensor5: 1.22,
    o2Sensor6: 1.19,
    o2SensorMv1: 51,
    o2SensorMv2: 52,
    o2SensorMv3: 53,
    o2SensorMv4: 50,
    o2SensorMv5: 54,
    o2SensorMv6: 52,
    heartRateSource: 'appleWatch',
    cns: 12.5,
    ndl: 1800,
    ceiling: 3.0,
    ascentRate: -9.0,
    rbt: 1500,
    decoType: 2,
    tts: 900,
  );

  test('fromPoint then toPoint is the identity on every point field', () {
    final sample = ProfileSample.fromPoint(point);
    expect(sample.toPoint(), point);
  });

  test('fromPoint carries the legacy per-sample pressure separately', () {
    final sample = ProfileSample.fromPoint(point, pressure: 180.5);
    expect(sample.pressure, 180.5);
    // DiveProfilePoint has no pressure field, so it cannot survive toPoint.
    expect(sample.toPoint(), point);
  });

  test('a minimal point maps with every optional field null', () {
    const minimal = DiveProfilePoint(timestamp: 0, depth: 0.0);
    final sample = ProfileSample.fromPoint(minimal);
    expect(sample.timestamp, 0);
    expect(sample.depth, 0.0);
    expect(sample.pressure, isNull);
    expect(sample.temperature, isNull);
    expect(sample.heartRateSource, isNull);
    expect(sample.o2SensorMv6, isNull);
    expect(sample.toPoint(), minimal);
  });

  test('value equality covers every field', () {
    final a = ProfileSample.fromPoint(point, pressure: 1.0);
    final b = ProfileSample.fromPoint(point, pressure: 1.0);
    final c = ProfileSample.fromPoint(point, pressure: 2.0);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/codecs/profile_sample_test.dart`
Expected: compilation failure, `profile_sample.dart` not found.

- [ ] **Step 3: Create the value type**

Create `lib/features/dive_log/domain/codecs/profile_sample.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One profile sample exactly as the `dive_profiles` table stores it, minus
/// the identity columns (`id`, `dive_id`, `computer_id`, `source_id`,
/// `is_primary`) that live on the series row.
///
/// This is the codec's input and output type. It differs from
/// [DiveProfilePoint] in one field: the legacy per-sample [pressure]
/// column, which the v59 migration moved to tank pressure profiles but
/// which older rows still populate. The codec is lossless over the stored
/// row, so the field rides along; [toPoint] drops it, as every read path
/// does today.
class ProfileSample extends Equatable {
  const ProfileSample({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.ascentRate,
    this.ceiling,
    this.ndl,
    this.setpoint,
    this.ppO2,
    this.o2Sensor1,
    this.o2Sensor2,
    this.o2Sensor3,
    this.o2Sensor4,
    this.o2Sensor5,
    this.o2Sensor6,
    this.cns,
    this.tts,
    this.rbt,
    this.decoType,
    this.heartRateSource,
    this.heading,
    this.o2SensorMv1,
    this.o2SensorMv2,
    this.o2SensorMv3,
    this.o2SensorMv4,
    this.o2SensorMv5,
    this.o2SensorMv6,
  });

  factory ProfileSample.fromPoint(DiveProfilePoint point, {double? pressure}) {
    return ProfileSample(
      timestamp: point.timestamp,
      depth: point.depth,
      pressure: pressure,
      temperature: point.temperature,
      heartRate: point.heartRate,
      ascentRate: point.ascentRate,
      ceiling: point.ceiling,
      ndl: point.ndl,
      setpoint: point.setpoint,
      ppO2: point.ppO2,
      o2Sensor1: point.o2Sensor1,
      o2Sensor2: point.o2Sensor2,
      o2Sensor3: point.o2Sensor3,
      o2Sensor4: point.o2Sensor4,
      o2Sensor5: point.o2Sensor5,
      o2Sensor6: point.o2Sensor6,
      cns: point.cns,
      tts: point.tts,
      rbt: point.rbt,
      decoType: point.decoType,
      heartRateSource: point.heartRateSource,
      heading: point.heading,
      o2SensorMv1: point.o2SensorMv1,
      o2SensorMv2: point.o2SensorMv2,
      o2SensorMv3: point.o2SensorMv3,
      o2SensorMv4: point.o2SensorMv4,
      o2SensorMv5: point.o2SensorMv5,
      o2SensorMv6: point.o2SensorMv6,
    );
  }

  /// Seconds from dive start.
  final int timestamp;

  /// Metres.
  final double depth;

  /// Legacy per-sample pressure in bar; null on every row written after the
  /// v59 migration.
  final double? pressure;
  final double? temperature;
  final int? heartRate;
  final double? ascentRate;
  final double? ceiling;
  final int? ndl;
  final double? setpoint;
  final double? ppO2;
  final double? o2Sensor1;
  final double? o2Sensor2;
  final double? o2Sensor3;
  final double? o2Sensor4;
  final double? o2Sensor5;
  final double? o2Sensor6;
  final double? cns;
  final int? tts;
  final int? rbt;
  final int? decoType;
  final String? heartRateSource;
  final double? heading;
  final int? o2SensorMv1;
  final int? o2SensorMv2;
  final int? o2SensorMv3;
  final int? o2SensorMv4;
  final int? o2SensorMv5;
  final int? o2SensorMv6;

  /// The domain point. Drops [pressure], which [DiveProfilePoint] does not
  /// carry.
  DiveProfilePoint toPoint() {
    return DiveProfilePoint(
      timestamp: timestamp,
      depth: depth,
      temperature: temperature,
      heartRate: heartRate,
      heading: heading,
      setpoint: setpoint,
      ppO2: ppO2,
      o2Sensor1: o2Sensor1,
      o2Sensor2: o2Sensor2,
      o2Sensor3: o2Sensor3,
      o2Sensor4: o2Sensor4,
      o2Sensor5: o2Sensor5,
      o2Sensor6: o2Sensor6,
      o2SensorMv1: o2SensorMv1,
      o2SensorMv2: o2SensorMv2,
      o2SensorMv3: o2SensorMv3,
      o2SensorMv4: o2SensorMv4,
      o2SensorMv5: o2SensorMv5,
      o2SensorMv6: o2SensorMv6,
      heartRateSource: heartRateSource,
      cns: cns,
      ndl: ndl,
      ceiling: ceiling,
      ascentRate: ascentRate,
      rbt: rbt,
      decoType: decoType,
      tts: tts,
    );
  }

  @override
  List<Object?> get props => [
    timestamp,
    depth,
    pressure,
    temperature,
    heartRate,
    ascentRate,
    ceiling,
    ndl,
    setpoint,
    ppO2,
    o2Sensor1,
    o2Sensor2,
    o2Sensor3,
    o2Sensor4,
    o2Sensor5,
    o2Sensor6,
    cns,
    tts,
    rbt,
    decoType,
    heartRateSource,
    heading,
    o2SensorMv1,
    o2SensorMv2,
    o2SensorMv3,
    o2SensorMv4,
    o2SensorMv5,
    o2SensorMv6,
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/profile_sample_test.dart`
Expected: 4 tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/codecs/profile_sample.dart test/features/dive_log/domain/codecs/profile_sample_test.dart
git commit -m "feat: ProfileSample value type for the series codec"
```

---

### Task 3: ProfileSeriesSummary

**Files:**
- Create: `lib/features/dive_log/domain/codecs/profile_series_summary.dart`
- Test: `test/features/dive_log/domain/codecs/profile_series_summary_test.dart`

**Interfaces:**
- Consumes: `ProfileSample` (Task 2).
- Produces: `class ProfileSeriesSummary extends Equatable` with `int sampleCount`, `int startTimestamp`, `int endTimestamp`, `double maxDepth`, `double firstDepth`, `double lastDepth`, `bool hasDecoType`, `bool hasDecoStop`, `bool hasPositiveCeiling`, and `factory ProfileSeriesSummary.of(List<ProfileSample> samples)` which throws `ArgumentError` on an empty list. Constant `kDecoTypeDecoStop = 2`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/domain/codecs/profile_series_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

void main() {
  test('summarises a plain no-deco series', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0),
      ProfileSample(timestamp: 10, depth: 5.2),
      ProfileSample(timestamp: 20, depth: 18.7),
      ProfileSample(timestamp: 30, depth: 12.1),
      ProfileSample(timestamp: 40, depth: 0.3),
    ];
    final summary = ProfileSeriesSummary.of(samples);
    expect(
      summary,
      const ProfileSeriesSummary(
        sampleCount: 5,
        startTimestamp: 0,
        endTimestamp: 40,
        maxDepth: 18.7,
        firstDepth: 0.0,
        lastDepth: 0.3,
        hasDecoType: false,
        hasDecoStop: false,
        hasPositiveCeiling: false,
      ),
    );
  });

  test('a recorded deco type without a stop sets only hasDecoType', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, decoType: 0),
      ProfileSample(timestamp: 10, depth: 20.0, decoType: 1),
    ];
    final summary = ProfileSeriesSummary.of(samples);
    expect(summary.hasDecoType, isTrue);
    expect(summary.hasDecoStop, isFalse);
  });

  test('deco type 2 on any sample sets hasDecoStop', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, decoType: 0),
      ProfileSample(timestamp: 10, depth: 6.0, decoType: kDecoTypeDecoStop),
    ];
    expect(ProfileSeriesSummary.of(samples).hasDecoStop, isTrue);
  });

  test('a positive ceiling on any sample sets hasPositiveCeiling', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, ceiling: 0.0),
      ProfileSample(timestamp: 10, depth: 30.0, ceiling: 3.0),
    ];
    expect(ProfileSeriesSummary.of(samples).hasPositiveCeiling, isTrue);
  });

  test('a zero or null ceiling does not count as positive', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0, ceiling: 0.0),
      ProfileSample(timestamp: 10, depth: 30.0),
    ];
    expect(ProfileSeriesSummary.of(samples).hasPositiveCeiling, isFalse);
  });

  test('a single sample is its own start, end, first, last and max', () {
    const samples = [ProfileSample(timestamp: 7, depth: 4.4)];
    final summary = ProfileSeriesSummary.of(samples);
    expect(summary.sampleCount, 1);
    expect(summary.startTimestamp, 7);
    expect(summary.endTimestamp, 7);
    expect(summary.maxDepth, 4.4);
    expect(summary.firstDepth, 4.4);
    expect(summary.lastDepth, 4.4);
  });

  test('an empty series is a caller error', () {
    expect(() => ProfileSeriesSummary.of(const []), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/codecs/profile_series_summary_test.dart`
Expected: compilation failure, `profile_series_summary.dart` not found.

- [ ] **Step 3: Create the summary**

Create `lib/features/dive_log/domain/codecs/profile_series_summary.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// The `deco_type` value that marks a mandatory decompression stop
/// (0 = NDL, 1 = safety stop, 2 = deco stop, 3 = deep stop).
const int kDecoTypeDecoStop = 2;

/// The scalars a `dive_profile_series` row stores next to its blob.
///
/// These exist so the SQL consumers that only need a predicate or a span
/// (deco classification, runtime fallback, quality neighbours) never decode
/// a blob. They are computed from the same sample list the codec packs, so
/// a scalar can never disagree with its blob.
class ProfileSeriesSummary extends Equatable {
  const ProfileSeriesSummary({
    required this.sampleCount,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.maxDepth,
    required this.firstDepth,
    required this.lastDepth,
    required this.hasDecoType,
    required this.hasDecoStop,
    required this.hasPositiveCeiling,
  });

  /// Computes the summary of a non-empty, timestamp-ordered series.
  factory ProfileSeriesSummary.of(List<ProfileSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(
        samples,
        'samples',
        'a series needs at least one sample',
      );
    }
    var maxDepth = samples.first.depth;
    var hasDecoType = false;
    var hasDecoStop = false;
    var hasPositiveCeiling = false;
    for (final sample in samples) {
      if (sample.depth > maxDepth) maxDepth = sample.depth;
      final decoType = sample.decoType;
      if (decoType != null) {
        hasDecoType = true;
        if (decoType == kDecoTypeDecoStop) hasDecoStop = true;
      }
      final ceiling = sample.ceiling;
      if (ceiling != null && ceiling > 0) hasPositiveCeiling = true;
    }
    return ProfileSeriesSummary(
      sampleCount: samples.length,
      startTimestamp: samples.first.timestamp,
      endTimestamp: samples.last.timestamp,
      maxDepth: maxDepth,
      firstDepth: samples.first.depth,
      lastDepth: samples.last.depth,
      hasDecoType: hasDecoType,
      hasDecoStop: hasDecoStop,
      hasPositiveCeiling: hasPositiveCeiling,
    );
  }

  final int sampleCount;

  /// Seconds from dive start of the first sample.
  final int startTimestamp;

  /// Seconds from dive start of the last sample.
  final int endTimestamp;

  /// Metres.
  final double maxDepth;
  final double firstDepth;
  final double lastDepth;

  /// Any sample carries a `deco_type`.
  final bool hasDecoType;

  /// Any sample carries `deco_type == 2`.
  final bool hasDecoStop;

  /// Any sample carries `ceiling > 0`.
  final bool hasPositiveCeiling;

  @override
  List<Object?> get props => [
    sampleCount,
    startTimestamp,
    endTimestamp,
    maxDepth,
    firstDepth,
    lastDepth,
    hasDecoType,
    hasDecoStop,
    hasPositiveCeiling,
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/profile_series_summary_test.dart`
Expected: 7 tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/codecs/profile_series_summary.dart test/features/dive_log/domain/codecs/profile_series_summary_test.dart
git commit -m "feat: ProfileSeriesSummary scalars for series rows"
```

---

### Task 4: ProfileSeriesCodec

**Files:**
- Create: `lib/features/dive_log/domain/codecs/profile_series_codec.dart`
- Test: `test/features/dive_log/domain/codecs/profile_series_codec_test.dart`

**Interfaces:**
- Consumes: `ByteWriter`, `ByteReader`, `ColumnWriter`, `ColumnReader` (Task 1); `ProfileSample` (Task 2); `ProfileSeriesSummary` (Task 3); `ProfileSeriesCodecException` (Task 1).
- Produces:
  - `enum ProfileFieldKind { deltaInt, float64, runLengthString }`
  - `class ProfileField { const ProfileField(String name, ProfileFieldKind kind); final String name; final ProfileFieldKind kind; }`
  - `class EncodedProfileSeries { final Uint8List bytes; final int codecVersion; final ProfileSeriesSummary summary; }`
  - `class ProfileSeriesCodec { const ProfileSeriesCodec({Map<int, List<ProfileField>> fieldTables}); static const int version = 1; static const List<ProfileField> fieldTableV1; EncodedProfileSeries encode(List<ProfileSample> samples, {int version = 1}); List<ProfileSample> decode(Uint8List bytes); }`
  - PR 2 calls `const ProfileSeriesCodec().encode(samples)` and `.decode(bytes)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/codecs/profile_series_codec_test.dart`:

```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

/// A fully populated sample: every one of the 28 fields present.
ProfileSample fullSample(int i) => ProfileSample(
  timestamp: i * 10,
  depth: 10.0 + i * 0.5,
  pressure: 200.0 - i,
  temperature: 20.0 - i * 0.01,
  heartRate: 80 + (i % 7),
  ascentRate: -3.0 + i * 0.1,
  ceiling: i > 5 ? 3.0 : 0.0,
  ndl: 1800 - i * 15,
  setpoint: 1.2,
  ppO2: 1.19 + i * 0.001,
  o2Sensor1: 1.18,
  o2Sensor2: 1.20,
  o2Sensor3: 1.21,
  o2Sensor4: 1.17,
  o2Sensor5: 1.22,
  o2Sensor6: 1.19,
  cns: 12.5 + i,
  tts: 900 + i * 3,
  rbt: 1500 - i * 2,
  decoType: i > 5 ? 2 : 0,
  heartRateSource: i < 4 ? 'diveComputer' : 'appleWatch',
  heading: (i * 37) % 360 * 1.0,
  o2SensorMv1: 51 + i,
  o2SensorMv2: 52 - i,
  o2SensorMv3: 53,
  o2SensorMv4: 50,
  o2SensorMv5: 54,
  o2SensorMv6: 52,
);

/// Depth and timestamp only, like a manually entered profile.
ProfileSample minimalSample(int i) =>
    ProfileSample(timestamp: i * 30, depth: 5.0 * (i % 4));

void main() {
  const codec = ProfileSeriesCodec();

  group('round trips', () {
    test('every field present', () {
      final samples = [for (var i = 0; i < 12; i++) fullSample(i)];
      final encoded = codec.encode(samples);
      expect(encoded.codecVersion, 1);
      expect(codec.decode(encoded.bytes), samples);
    });

    test('every optional field null', () {
      final samples = [for (var i = 0; i < 12; i++) minimalSample(i)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('mixed presence within one column', () {
      final samples = [
        for (var i = 0; i < 20; i++)
          ProfileSample(
            timestamp: i,
            depth: 1.0 * i,
            temperature: i.isEven ? 20.0 : null,
            ndl: i % 3 == 0 ? 600 - i : null,
            heartRateSource: i % 5 == 0 ? 'garmin' : null,
          ),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('a single sample', () {
      final samples = [fullSample(0)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('duplicate timestamps survive in insertion order', () {
      const samples = [
        ProfileSample(timestamp: 10, depth: 5.0),
        ProfileSample(timestamp: 10, depth: 5.5),
        ProfileSample(timestamp: 10, depth: 5.0, temperature: 19.0),
        ProfileSample(timestamp: 20, depth: 6.0),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('integer fields that decrease encode negative deltas correctly', () {
      final samples = [
        for (var i = 0; i < 50; i++)
          ProfileSample(
            timestamp: i,
            depth: 1.0,
            ndl: 3000 - i * 60,
            rbt: 2000 - i * 45,
            heartRate: 100 - i,
            o2SensorMv1: -5 + i,
          ),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('float64 fields are bit-exact', () {
      const samples = [
        ProfileSample(timestamp: 0, depth: 0.1 + 0.2, temperature: -0.0),
        ProfileSample(timestamp: 1, depth: double.maxFinite, cns: 1e-300),
      ];
      final decoded = codec.decode(codec.encode(samples).bytes);
      expect(decoded[0].depth, samples[0].depth);
      expect(decoded[0].temperature!.isNegative, isTrue);
      expect(decoded[1].depth, double.maxFinite);
      expect(decoded[1].cns, 1e-300);
    });

    test('the largest realistic series: 20,000 samples at one second', () {
      final random = Random(42);
      var depth = 0.0;
      final samples = <ProfileSample>[];
      for (var i = 0; i < 20000; i++) {
        depth = max(0.0, depth + (random.nextDouble() - 0.5) * 0.3);
        samples.add(
          ProfileSample(
            timestamp: i,
            depth: depth,
            temperature: 8.0 + (i ~/ 600) * 0.1,
            ndl: max(0, 3600 - i ~/ 2),
            cns: i / 400.0,
            decoType: i > 15000 ? 2 : 0,
          ),
        );
      }
      final encoded = codec.encode(samples);
      expect(codec.decode(encoded.bytes), samples);
      // 20,000 samples of six fields. Row storage today costs roughly 300
      // bytes per sample; the packed blob must land far below even the raw
      // columnar size (8 bytes per float64 field per sample).
      expect(encoded.bytes.length, lessThan(20000 * 3 * 8));
    });
  });

  group('summary', () {
    test('encode returns the summary of the packed samples', () {
      final samples = [for (var i = 0; i < 12; i++) fullSample(i)];
      final encoded = codec.encode(samples);
      expect(encoded.summary, ProfileSeriesSummary.of(samples));
      expect(encoded.summary.sampleCount, 12);
      expect(encoded.summary.hasDecoStop, isTrue);
      expect(encoded.summary.hasPositiveCeiling, isTrue);
    });
  });

  group('caller errors', () {
    test('an empty series cannot be encoded', () {
      expect(() => codec.encode(const []), throwsArgumentError);
    });

    test('timestamps must be non-decreasing', () {
      const samples = [
        ProfileSample(timestamp: 10, depth: 1.0),
        ProfileSample(timestamp: 9, depth: 1.0),
      ];
      expect(() => codec.encode(samples), throwsArgumentError);
    });

    test('an unregistered version cannot be encoded', () {
      expect(
        () => codec.encode([fullSample(0)], version: 9),
        throwsArgumentError,
      );
    });
  });

  group('malformed input', () {
    Uint8List validBytes() =>
        codec.encode([for (var i = 0; i < 8; i++) fullSample(i)]).bytes;

    /// Re-compresses a tampered body so the failure is in the codec, not
    /// in zlib.
    Uint8List recompress(List<int> body) =>
        Uint8List.fromList(ZLibCodec(level: 6).encode(body));

    Uint8List inflate(Uint8List bytes) => Uint8List.fromList(zlib.decode(bytes));

    test('bytes that are not a zlib stream', () {
      expect(
        () => codec.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an empty blob', () {
      expect(
        () => codec.decode(Uint8List(0)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an unknown version byte', () {
      final body = inflate(validBytes());
      body[0] = 42;
      expect(
        () => codec.decode(recompress(body)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });

    test('a truncated body', () {
      final body = inflate(validBytes());
      final truncated = body.sublist(0, body.length ~/ 2);
      expect(
        () => codec.decode(recompress(truncated)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('trailing bytes after the last block', () {
      final body = inflate(validBytes());
      final padded = Uint8List.fromList([...body, 0, 0, 0]);
      expect(
        () => codec.decode(recompress(padded)),
        throwsA(
          isA<ProfileSeriesCodecException>().having(
            (e) => e.message,
            'message',
            contains('trailing'),
          ),
        ),
      );
    });

    test('a blob whose timestamp column is marked absent', () {
      // Header is version (1 byte) then count varint (8 fits in 1 byte);
      // byte 2 is the timestamp block's presence mode.
      final body = inflate(validBytes());
      expect(body[2], isNot(0));
      body[2] = 0;
      expect(
        () => codec.decode(recompress(body)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a sample count larger than the payload', () {
      final body = inflate(validBytes());
      // Replace the one-byte count (8) with a five-byte varint for 2^32.
      const huge = [0x80, 0x80, 0x80, 0x80, 0x10];
      final tampered = Uint8List.fromList([
        body[0],
        ...huge,
        ...body.sublist(2),
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a string run longer than the present values', () {
      // A three-field table keeps the body small enough to address by hand:
      // [version][count 3][timestamp: mode, 3 deltas][depth: mode, 3 floats]
      // [heart_rate_source: mode, run count, run length, byte length, 'a'].
      const table = [
        ProfileField('timestamp', ProfileFieldKind.deltaInt),
        ProfileField('depth', ProfileFieldKind.float64),
        ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
      ];
      const small = ProfileSeriesCodec(fieldTables: {9: table});
      const samples = [
        ProfileSample(timestamp: 0, depth: 1.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 1, depth: 2.0, heartRateSource: 'a'),
        ProfileSample(timestamp: 2, depth: 3.0, heartRateSource: 'a'),
      ];
      final body = inflate(small.encode(samples, version: 9).bytes);
      const runLengthOffset = 1 + 1 + (1 + 3) + (1 + 24) + 1 + 1;
      expect(body[runLengthOffset], 3);
      body[runLengthOffset] = 5;
      expect(
        () => small.decode(recompress(body)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });
  });

  group('forward tolerance', () {
    // A hypothetical older format that never recorded heading.
    final withoutHeading = [
      for (final field in ProfileSeriesCodec.fieldTableV1)
        if (field.name != 'heading') field,
    ];

    test('a newer decoder reads an older version with missing fields null', () {
      final legacy = ProfileSeriesCodec(fieldTables: {7: withoutHeading});
      final modern = ProfileSeriesCodec(
        fieldTables: {
          7: withoutHeading,
          ProfileSeriesCodec.version: ProfileSeriesCodec.fieldTableV1,
        },
      );
      final samples = [for (var i = 0; i < 6; i++) fullSample(i)];
      final bytes = legacy.encode(samples, version: 7).bytes;
      final decoded = modern.decode(bytes);
      expect(decoded, hasLength(6));
      for (var i = 0; i < 6; i++) {
        expect(decoded[i].heading, isNull);
        expect(decoded[i], samples[i].copyWithoutHeading());
      }
    });

    test('a decoder that does not know the version refuses it', () {
      final legacy = ProfileSeriesCodec(fieldTables: {7: withoutHeading});
      final bytes = legacy.encode([fullSample(0)], version: 7).bytes;
      expect(
        () => codec.decode(bytes),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('every field table must carry timestamp and depth', () {
      final noDepth = [
        for (final field in ProfileSeriesCodec.fieldTableV1)
          if (field.name != 'depth') field,
      ];
      expect(
        () => ProfileSeriesCodec(fieldTables: {1: noDepth}).encode([
          fullSample(0),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('field table', () {
    test('v1 has 28 entries with unique names', () {
      final names = ProfileSeriesCodec.fieldTableV1.map((f) => f.name);
      expect(names, hasLength(28));
      expect(names.toSet(), hasLength(28));
    });

    test('v1 begins with timestamp and depth', () {
      expect(ProfileSeriesCodec.fieldTableV1[0].name, 'timestamp');
      expect(ProfileSeriesCodec.fieldTableV1[1].name, 'depth');
    });
  });
}

extension on ProfileSample {
  ProfileSample copyWithoutHeading() => ProfileSample(
    timestamp: timestamp,
    depth: depth,
    pressure: pressure,
    temperature: temperature,
    heartRate: heartRate,
    ascentRate: ascentRate,
    ceiling: ceiling,
    ndl: ndl,
    setpoint: setpoint,
    ppO2: ppO2,
    o2Sensor1: o2Sensor1,
    o2Sensor2: o2Sensor2,
    o2Sensor3: o2Sensor3,
    o2Sensor4: o2Sensor4,
    o2Sensor5: o2Sensor5,
    o2Sensor6: o2Sensor6,
    cns: cns,
    tts: tts,
    rbt: rbt,
    decoType: decoType,
    heartRateSource: heartRateSource,
    o2SensorMv1: o2SensorMv1,
    o2SensorMv2: o2SensorMv2,
    o2SensorMv3: o2SensorMv3,
    o2SensorMv4: o2SensorMv4,
    o2SensorMv5: o2SensorMv5,
    o2SensorMv6: o2SensorMv6,
  );
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/codecs/profile_series_codec_test.dart`
Expected: compilation failure, `profile_series_codec.dart` not found.

- [ ] **Step 3: Create the codec**

Create `lib/features/dive_log/domain/codecs/profile_series_codec.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

/// How a field's column block is written.
enum ProfileFieldKind {
  /// Zigzag varint of the difference from the previous present value; the
  /// previous value starts at 0 for each block.
  deltaInt,

  /// IEEE-754 binary64, little-endian.
  float64,

  /// Runs of identical strings: run count, then (length, UTF-8 length,
  /// UTF-8 bytes) per run, covering the present values only.
  runLengthString,
}

/// One entry of a field table. [name] is the `dive_profiles` column name.
class ProfileField {
  const ProfileField(this.name, this.kind);

  final String name;
  final ProfileFieldKind kind;
}

/// The bytes and scalars a `dive_profile_series` row stores.
class EncodedProfileSeries {
  const EncodedProfileSeries({
    required this.bytes,
    required this.codecVersion,
    required this.summary,
  });

  final Uint8List bytes;
  final int codecVersion;
  final ProfileSeriesSummary summary;
}

/// Packs a series of [ProfileSample]s into one zlib-compressed columnar blob
/// and back. Lossless.
///
/// Layout of the uncompressed body: a version byte, the sample count as a
/// varint, then one column block per entry of that version's field table in
/// table order. See `byte_io.dart` for the block format.
///
/// Versioning: a later codec appends fields under a new version byte. The
/// decoder selects the field table by the blob's version byte, so an older
/// blob decodes under a newer codec with its missing fields null. A version
/// this codec does not know is refused.
class ProfileSeriesCodec {
  const ProfileSeriesCodec({
    this.fieldTables = const {version: fieldTableV1},
  });

  /// The version new blobs are written with.
  static const int version = 1;

  /// Codec v1: every `dive_profiles` sample column, in this order. Never
  /// reorder or remove an entry; append under a new version instead.
  static const List<ProfileField> fieldTableV1 = [
    ProfileField('timestamp', ProfileFieldKind.deltaInt),
    ProfileField('depth', ProfileFieldKind.float64),
    ProfileField('pressure', ProfileFieldKind.float64),
    ProfileField('temperature', ProfileFieldKind.float64),
    ProfileField('heart_rate', ProfileFieldKind.deltaInt),
    ProfileField('ascent_rate', ProfileFieldKind.float64),
    ProfileField('ceiling', ProfileFieldKind.float64),
    ProfileField('ndl', ProfileFieldKind.deltaInt),
    ProfileField('setpoint', ProfileFieldKind.float64),
    ProfileField('pp_o2', ProfileFieldKind.float64),
    ProfileField('o2_sensor1', ProfileFieldKind.float64),
    ProfileField('o2_sensor2', ProfileFieldKind.float64),
    ProfileField('o2_sensor3', ProfileFieldKind.float64),
    ProfileField('o2_sensor4', ProfileFieldKind.float64),
    ProfileField('o2_sensor5', ProfileFieldKind.float64),
    ProfileField('o2_sensor6', ProfileFieldKind.float64),
    ProfileField('cns', ProfileFieldKind.float64),
    ProfileField('tts', ProfileFieldKind.deltaInt),
    ProfileField('rbt', ProfileFieldKind.deltaInt),
    ProfileField('deco_type', ProfileFieldKind.deltaInt),
    ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
    ProfileField('heading', ProfileFieldKind.float64),
    ProfileField('o2_sensor_mv1', ProfileFieldKind.deltaInt),
    ProfileField('o2_sensor_mv2', ProfileFieldKind.deltaInt),
    ProfileField('o2_sensor_mv3', ProfileFieldKind.deltaInt),
    ProfileField('o2_sensor_mv4', ProfileFieldKind.deltaInt),
    ProfileField('o2_sensor_mv5', ProfileFieldKind.deltaInt),
    ProfileField('o2_sensor_mv6', ProfileFieldKind.deltaInt),
  ];

  /// Field table per version byte this codec can read.
  final Map<int, List<ProfileField>> fieldTables;

  // ZLibCodec has no const constructor, so this is `final`, not `const`.
  static final ZLibCodec _zlib = ZLibCodec(level: 6);

  /// Encodes a non-empty, timestamp-ordered series.
  ///
  /// Throws [ArgumentError] on an empty list, on decreasing timestamps, on
  /// an unregistered [version], or on a field table without `timestamp` and
  /// `depth`. These are caller bugs, not data faults.
  EncodedProfileSeries encode(
    List<ProfileSample> samples, {
    int version = ProfileSeriesCodec.version,
  }) {
    final table = fieldTables[version];
    if (table == null) {
      throw ArgumentError.value(version, 'version', 'no field table');
    }
    _requireTimestampAndDepth(table);
    final summary = ProfileSeriesSummary.of(samples);
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].timestamp < samples[i - 1].timestamp) {
        throw ArgumentError.value(
          samples,
          'samples',
          'timestamps must be non-decreasing (sample $i)',
        );
      }
    }

    final writer = ByteWriter()
      ..writeByte(version)
      ..writeVarUint(samples.length);
    for (final field in table) {
      final column = [for (final sample in samples) _fieldOf(sample, field.name)];
      _writeColumn(writer, field.kind, column);
    }
    return EncodedProfileSeries(
      bytes: Uint8List.fromList(_zlib.encode(writer.takeBytes())),
      codecVersion: version,
      summary: summary,
    );
  }

  /// Decodes a blob written by [encode] under any registered version.
  ///
  /// Throws [ProfileSeriesCodecException] on anything malformed: not a zlib
  /// stream, an unknown version, a truncated block, trailing bytes, or a
  /// sample without timestamp or depth.
  List<ProfileSample> decode(Uint8List bytes) {
    final Uint8List body;
    try {
      body = Uint8List.fromList(_zlib.decode(bytes));
    } catch (e) {
      throw ProfileSeriesCodecException('not a zlib stream: $e');
    }
    if (body.isEmpty) {
      throw const ProfileSeriesCodecException('empty body');
    }
    final reader = ByteReader(body);
    final blobVersion = reader.readByte();
    final table = fieldTables[blobVersion];
    if (table == null) {
      throw ProfileSeriesCodecException('unknown codec version $blobVersion');
    }
    final count = reader.readVarUint();
    // Every sample carries at least a one-byte timestamp delta, so a count
    // the remaining payload cannot hold is corruption, not a large series.
    // Guarding here keeps a bogus count from sizing 28 column lists.
    if (count > reader.remaining) {
      throw ProfileSeriesCodecException(
        'sample count $count exceeds the ${reader.remaining} remaining '
        'byte(s)',
      );
    }
    final columns = <String, List<Object?>>{};
    for (final field in table) {
      columns[field.name] = _readColumn(reader, field.kind, count);
    }
    if (!reader.isAtEnd) {
      throw ProfileSeriesCodecException(
        '${reader.remaining} trailing byte(s) after the last block',
      );
    }
    return _samplesFrom(columns, count);
  }

  static void _requireTimestampAndDepth(List<ProfileField> table) {
    final names = {for (final field in table) field.name};
    if (!names.contains('timestamp') || !names.contains('depth')) {
      throw ArgumentError.value(
        table,
        'fieldTables',
        'every field table must carry timestamp and depth',
      );
    }
  }

  static Object? _fieldOf(ProfileSample s, String name) => switch (name) {
    'timestamp' => s.timestamp,
    'depth' => s.depth,
    'pressure' => s.pressure,
    'temperature' => s.temperature,
    'heart_rate' => s.heartRate,
    'ascent_rate' => s.ascentRate,
    'ceiling' => s.ceiling,
    'ndl' => s.ndl,
    'setpoint' => s.setpoint,
    'pp_o2' => s.ppO2,
    'o2_sensor1' => s.o2Sensor1,
    'o2_sensor2' => s.o2Sensor2,
    'o2_sensor3' => s.o2Sensor3,
    'o2_sensor4' => s.o2Sensor4,
    'o2_sensor5' => s.o2Sensor5,
    'o2_sensor6' => s.o2Sensor6,
    'cns' => s.cns,
    'tts' => s.tts,
    'rbt' => s.rbt,
    'deco_type' => s.decoType,
    'heart_rate_source' => s.heartRateSource,
    'heading' => s.heading,
    'o2_sensor_mv1' => s.o2SensorMv1,
    'o2_sensor_mv2' => s.o2SensorMv2,
    'o2_sensor_mv3' => s.o2SensorMv3,
    'o2_sensor_mv4' => s.o2SensorMv4,
    'o2_sensor_mv5' => s.o2SensorMv5,
    'o2_sensor_mv6' => s.o2SensorMv6,
    _ => throw ArgumentError.value(name, 'name', 'not a profile sample field'),
  };

  static void _writeColumn(
    ByteWriter writer,
    ProfileFieldKind kind,
    List<Object?> column,
  ) {
    switch (kind) {
      case ProfileFieldKind.deltaInt:
        var previous = 0;
        writer.writeColumn<int>(column.cast<int?>(), (value) {
          writer.writeVarInt(value - previous);
          previous = value;
        });
      case ProfileFieldKind.float64:
        writer.writeColumn<double>(column.cast<double?>(), writer.writeFloat64);
      case ProfileFieldKind.runLengthString:
        _writeStringColumn(writer, column.cast<String?>());
    }
  }

  static List<Object?> _readColumn(
    ByteReader reader,
    ProfileFieldKind kind,
    int count,
  ) {
    switch (kind) {
      case ProfileFieldKind.deltaInt:
        var previous = 0;
        return reader.readColumn<int>(count, () {
          previous += reader.readVarInt();
          return previous;
        });
      case ProfileFieldKind.float64:
        return reader.readColumn<double>(count, reader.readFloat64);
      case ProfileFieldKind.runLengthString:
        return _readStringColumn(reader, count);
    }
  }

  static void _writeStringColumn(ByteWriter writer, List<String?> values) {
    if (!writer.writePresence(values)) return;
    final runs = <(String, int)>[];
    for (final value in values) {
      if (value == null) continue;
      if (runs.isNotEmpty && runs.last.$1 == value) {
        runs[runs.length - 1] = (value, runs.last.$2 + 1);
      } else {
        runs.add((value, 1));
      }
    }
    writer.writeVarUint(runs.length);
    for (final (value, length) in runs) {
      final encoded = utf8.encode(value);
      writer
        ..writeVarUint(length)
        ..writeVarUint(encoded.length)
        ..writeBytes(encoded);
    }
  }

  static List<String?> _readStringColumn(ByteReader reader, int count) {
    final present = reader.readPresence(count);
    var presentCount = 0;
    for (final isPresent in present) {
      if (isPresent) presentCount++;
    }
    if (presentCount == 0) return List<String?>.filled(count, null);
    final runCount = reader.readVarUint();
    final values = <String>[];
    for (var run = 0; run < runCount; run++) {
      final length = reader.readVarUint();
      if (values.length + length > presentCount) {
        throw ProfileSeriesCodecException(
          'string run $run of length $length overruns the $presentCount '
          'present values',
        );
      }
      final byteLength = reader.readVarUint();
      final String value;
      try {
        value = utf8.decode(reader.readBytes(byteLength));
      } on FormatException catch (e) {
        throw ProfileSeriesCodecException(
          'invalid UTF-8 in string run $run: ${e.message}',
        );
      }
      for (var i = 0; i < length; i++) {
        values.add(value);
      }
    }
    if (values.length != presentCount) {
      throw ProfileSeriesCodecException(
        'string runs cover ${values.length} of $presentCount present values',
      );
    }
    var next = 0;
    return [for (final isPresent in present) isPresent ? values[next++] : null];
  }

  static List<ProfileSample> _samplesFrom(
    Map<String, List<Object?>> columns,
    int count,
  ) {
    List<T?> column<T>(String name) {
      final values = columns[name];
      if (values == null) return List<T?>.filled(count, null);
      return values.cast<T?>();
    }

    final timestamps = column<int>('timestamp');
    final depths = column<double>('depth');
    final pressures = column<double>('pressure');
    final temperatures = column<double>('temperature');
    final heartRates = column<int>('heart_rate');
    final ascentRates = column<double>('ascent_rate');
    final ceilings = column<double>('ceiling');
    final ndls = column<int>('ndl');
    final setpoints = column<double>('setpoint');
    final ppO2s = column<double>('pp_o2');
    final o2Sensor1s = column<double>('o2_sensor1');
    final o2Sensor2s = column<double>('o2_sensor2');
    final o2Sensor3s = column<double>('o2_sensor3');
    final o2Sensor4s = column<double>('o2_sensor4');
    final o2Sensor5s = column<double>('o2_sensor5');
    final o2Sensor6s = column<double>('o2_sensor6');
    final cnss = column<double>('cns');
    final ttss = column<int>('tts');
    final rbts = column<int>('rbt');
    final decoTypes = column<int>('deco_type');
    final heartRateSources = column<String>('heart_rate_source');
    final headings = column<double>('heading');
    final mv1s = column<int>('o2_sensor_mv1');
    final mv2s = column<int>('o2_sensor_mv2');
    final mv3s = column<int>('o2_sensor_mv3');
    final mv4s = column<int>('o2_sensor_mv4');
    final mv5s = column<int>('o2_sensor_mv5');
    final mv6s = column<int>('o2_sensor_mv6');

    return [
      for (var i = 0; i < count; i++)
        ProfileSample(
          timestamp:
              timestamps[i] ??
              (throw ProfileSeriesCodecException(
                'sample $i has no timestamp',
              )),
          depth:
              depths[i] ??
              (throw ProfileSeriesCodecException('sample $i has no depth')),
          pressure: pressures[i],
          temperature: temperatures[i],
          heartRate: heartRates[i],
          ascentRate: ascentRates[i],
          ceiling: ceilings[i],
          ndl: ndls[i],
          setpoint: setpoints[i],
          ppO2: ppO2s[i],
          o2Sensor1: o2Sensor1s[i],
          o2Sensor2: o2Sensor2s[i],
          o2Sensor3: o2Sensor3s[i],
          o2Sensor4: o2Sensor4s[i],
          o2Sensor5: o2Sensor5s[i],
          o2Sensor6: o2Sensor6s[i],
          cns: cnss[i],
          tts: ttss[i],
          rbt: rbts[i],
          decoType: decoTypes[i],
          heartRateSource: heartRateSources[i],
          heading: headings[i],
          o2SensorMv1: mv1s[i],
          o2SensorMv2: mv2s[i],
          o2SensorMv3: mv3s[i],
          o2SensorMv4: mv4s[i],
          o2SensorMv5: mv5s[i],
          o2SensorMv6: mv6s[i],
        ),
    ];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/profile_series_codec_test.dart`
Expected: all tests pass, including the 20,000-sample case. If the size assertion in "the largest realistic series" fails, the encoder is writing a bitmap or payload it should not; do not loosen the bound, find the block that grew.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/codecs/profile_series_codec.dart test/features/dive_log/domain/codecs/profile_series_codec_test.dart
git commit -m "feat: ProfileSeriesCodec, lossless columnar packing of profile samples"
```

---

### Task 5: Field table enumerated against the Drift table

**Files:**
- Test: `test/features/dive_log/domain/codecs/profile_series_field_table_test.dart`

**Interfaces:**
- Consumes: `ProfileSeriesCodec.fieldTableV1` (Task 4); `AppDatabase` and its `diveProfiles` table from `package:submersion/core/database/database.dart`; `NativeDatabase.memory()` from `package:drift/native.dart`; `DriftSqlType` from `package:drift/drift.dart`.
- Produces: nothing; this task is the guard the spec's risk list names ("a sample field the field table forgot fails the test, not the user").

- [ ] **Step 1: Write the test**

Create `test/features/dive_log/domain/codecs/profile_series_field_table_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// Columns of `dive_profiles` that identify the series, not the sample.
/// They live on the series row and are never packed.
const identityColumns = {
  'id',
  'dive_id',
  'computer_id',
  'source_id',
  'is_primary',
};

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('codec v1 covers every dive_profiles sample column, and only those', () {
    final tableColumns = {
      for (final column in db.diveProfiles.$columns) column.$name,
    };
    final expected = tableColumns.difference(identityColumns);
    final actual = {
      for (final field in ProfileSeriesCodec.fieldTableV1) field.name,
    };
    expect(
      actual,
      expected,
      reason:
          'A dive_profiles column was added or removed without a codec '
          'version. Append the field under a new version in '
          'ProfileSeriesCodec; never edit fieldTableV1.',
    );
  });

  test('each field kind matches its column type', () {
    final typeByName = {
      for (final column in db.diveProfiles.$columns) column.$name: column.type,
    };
    for (final field in ProfileSeriesCodec.fieldTableV1) {
      final type = typeByName[field.name];
      final expectedKind = switch (type) {
        DriftSqlType.int => ProfileFieldKind.deltaInt,
        DriftSqlType.double => ProfileFieldKind.float64,
        DriftSqlType.string => ProfileFieldKind.runLengthString,
        _ => fail('unexpected column type $type for ${field.name}'),
      };
      expect(field.kind, expectedKind, reason: field.name);
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/profile_series_field_table_test.dart`
Expected: 2 tests pass. If the first fails, the set difference in the failure output names the column the field table is missing or has extra; that is a real finding, resolve it in the field table only if the column genuinely is a sample column, otherwise add it to `identityColumns` with a comment.

- [ ] **Step 3: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/features/dive_log/domain/codecs/profile_series_field_table_test.dart
git commit -m "test: pin the codec field table to the dive_profiles columns"
```

---

### Task 6: TankPressureSeriesCodec

**Files:**
- Create: `lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart`
- Test: `test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart`

**Interfaces:**
- Consumes: `ByteWriter`, `ByteReader`, `ColumnWriter`, `ColumnReader`, `ProfileSeriesCodecException` (Task 1).
- Produces:
  - `class TankPressureSample extends Equatable { const TankPressureSample({required int timestamp, required double pressure}); }`
  - `class TankPressureSeriesSummary extends Equatable { int sampleCount; int startTimestamp; int endTimestamp; factory TankPressureSeriesSummary.of(List<TankPressureSample>); }`
  - `class EncodedTankPressureSeries { Uint8List bytes; int codecVersion; TankPressureSeriesSummary summary; }`
  - `class TankPressureSeriesCodec { const TankPressureSeriesCodec(); static const int version = 1; EncodedTankPressureSeries encode(List<TankPressureSample> samples); List<TankPressureSample> decode(Uint8List bytes); }`

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

void main() {
  const codec = TankPressureSeriesCodec();

  List<TankPressureSample> descending(int count) => [
    for (var i = 0; i < count; i++)
      TankPressureSample(timestamp: i * 10, pressure: 210.0 - i * 0.3),
  ];

  group('round trips', () {
    test('a typical series', () {
      final samples = descending(200);
      final encoded = codec.encode(samples);
      expect(encoded.codecVersion, 1);
      expect(codec.decode(encoded.bytes), samples);
    });

    test('a single sample', () {
      const samples = [TankPressureSample(timestamp: 0, pressure: 200.0)];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('duplicate timestamps survive in insertion order', () {
      const samples = [
        TankPressureSample(timestamp: 5, pressure: 200.0),
        TankPressureSample(timestamp: 5, pressure: 199.0),
        TankPressureSample(timestamp: 6, pressure: 198.5),
      ];
      expect(codec.decode(codec.encode(samples).bytes), samples);
    });

    test('pressures are bit-exact', () {
      const samples = [
        TankPressureSample(timestamp: 0, pressure: 0.1 + 0.2),
        TankPressureSample(timestamp: 1, pressure: 1e-300),
      ];
      final decoded = codec.decode(codec.encode(samples).bytes);
      expect(decoded[0].pressure, 0.1 + 0.2);
      expect(decoded[1].pressure, 1e-300);
    });

    test('20,000 samples pack below raw columnar size', () {
      final samples = descending(20000);
      final encoded = codec.encode(samples);
      expect(codec.decode(encoded.bytes), samples);
      // Raw columnar is one varint byte plus eight float bytes per sample.
      // Any compression at all lands below this; the bound is deterministic.
      expect(encoded.bytes.length, lessThan(20000 * 9));
    });
  });

  group('summary', () {
    test('encode returns the summary of the packed samples', () {
      final samples = descending(10);
      final encoded = codec.encode(samples);
      expect(encoded.summary, TankPressureSeriesSummary.of(samples));
      expect(encoded.summary.sampleCount, 10);
      expect(encoded.summary.startTimestamp, 0);
      expect(encoded.summary.endTimestamp, 90);
    });
  });

  group('caller errors', () {
    test('an empty series cannot be encoded', () {
      expect(() => codec.encode(const []), throwsArgumentError);
    });

    test('an empty summary is a caller error', () {
      expect(() => TankPressureSeriesSummary.of(const []), throwsArgumentError);
    });

    test('timestamps must be non-decreasing', () {
      const samples = [
        TankPressureSample(timestamp: 10, pressure: 1.0),
        TankPressureSample(timestamp: 9, pressure: 1.0),
      ];
      expect(() => codec.encode(samples), throwsArgumentError);
    });
  });

  group('malformed input', () {
    Uint8List validBytes() => codec.encode(descending(8)).bytes;
    Uint8List recompress(List<int> body) =>
        Uint8List.fromList(ZLibCodec(level: 6).encode(body));
    Uint8List inflate(Uint8List bytes) => Uint8List.fromList(zlib.decode(bytes));

    test('bytes that are not a zlib stream', () {
      expect(
        () => codec.decode(Uint8List.fromList([9, 9, 9])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('an unknown version byte', () {
      final body = inflate(validBytes());
      body[0] = 2;
      expect(
        () => codec.decode(recompress(body)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a truncated body', () {
      final body = inflate(validBytes());
      expect(
        () => codec.decode(recompress(body.sublist(0, body.length - 3))),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('trailing bytes', () {
      final body = inflate(validBytes());
      expect(
        () => codec.decode(recompress([...body, 0])),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });

    test('a sample count larger than the payload', () {
      final body = inflate(validBytes());
      // Replace the one-byte count (8) with a five-byte varint for 2^32.
      const huge = [0x80, 0x80, 0x80, 0x80, 0x10];
      final tampered = Uint8List.fromList([
        body[0],
        ...huge,
        ...body.sublist(2),
      ]);
      expect(
        () => codec.decode(recompress(tampered)),
        throwsA(isA<ProfileSeriesCodecException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart`
Expected: compilation failure, `tank_pressure_series_codec.dart` not found.

- [ ] **Step 3: Create the codec**

Create `lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// One tank pressure reading as `tank_pressure_profiles` stores it, minus
/// the identity columns (`id`, `dive_id`, `tank_id`, `computer_id`) that
/// live on the series row.
class TankPressureSample extends Equatable {
  const TankPressureSample({required this.timestamp, required this.pressure});

  /// Seconds from dive start.
  final int timestamp;

  /// Bar.
  final double pressure;

  @override
  List<Object?> get props => [timestamp, pressure];
}

/// The scalars a `tank_pressure_series` row stores next to its blob.
class TankPressureSeriesSummary extends Equatable {
  const TankPressureSeriesSummary({
    required this.sampleCount,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  /// Computes the summary of a non-empty, timestamp-ordered series.
  factory TankPressureSeriesSummary.of(List<TankPressureSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(
        samples,
        'samples',
        'a series needs at least one sample',
      );
    }
    return TankPressureSeriesSummary(
      sampleCount: samples.length,
      startTimestamp: samples.first.timestamp,
      endTimestamp: samples.last.timestamp,
    );
  }

  final int sampleCount;
  final int startTimestamp;
  final int endTimestamp;

  @override
  List<Object?> get props => [sampleCount, startTimestamp, endTimestamp];
}

/// The bytes and scalars a `tank_pressure_series` row stores.
class EncodedTankPressureSeries {
  const EncodedTankPressureSeries({
    required this.bytes,
    required this.codecVersion,
    required this.summary,
  });

  final Uint8List bytes;
  final int codecVersion;
  final TankPressureSeriesSummary summary;
}

/// Packs a tank's pressure readings into one zlib-compressed columnar blob
/// and back. Lossless.
///
/// Body: version byte, sample count varint, a delta-zigzag-varint timestamp
/// column, a float64 pressure column. Both columns are always fully present
/// (the fields are non-nullable), so each costs one presence byte.
class TankPressureSeriesCodec {
  const TankPressureSeriesCodec();

  static const int version = 1;

  // ZLibCodec has no const constructor, so this is `final`, not `const`.
  static final ZLibCodec _zlib = ZLibCodec(level: 6);

  /// Encodes a non-empty, timestamp-ordered series. Throws [ArgumentError]
  /// on an empty list or on decreasing timestamps.
  EncodedTankPressureSeries encode(List<TankPressureSample> samples) {
    final summary = TankPressureSeriesSummary.of(samples);
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].timestamp < samples[i - 1].timestamp) {
        throw ArgumentError.value(
          samples,
          'samples',
          'timestamps must be non-decreasing (sample $i)',
        );
      }
    }
    final writer = ByteWriter()
      ..writeByte(version)
      ..writeVarUint(samples.length);
    var previous = 0;
    writer.writeColumn<int>([for (final s in samples) s.timestamp], (value) {
      writer.writeVarInt(value - previous);
      previous = value;
    });
    writer.writeColumn<double>(
      [for (final s in samples) s.pressure],
      writer.writeFloat64,
    );
    return EncodedTankPressureSeries(
      bytes: Uint8List.fromList(_zlib.encode(writer.takeBytes())),
      codecVersion: version,
      summary: summary,
    );
  }

  /// Decodes a blob written by [encode]. Throws
  /// [ProfileSeriesCodecException] on anything malformed.
  List<TankPressureSample> decode(Uint8List bytes) {
    final Uint8List body;
    try {
      body = Uint8List.fromList(_zlib.decode(bytes));
    } catch (e) {
      throw ProfileSeriesCodecException('not a zlib stream: $e');
    }
    if (body.isEmpty) {
      throw const ProfileSeriesCodecException('empty body');
    }
    final reader = ByteReader(body);
    final blobVersion = reader.readByte();
    if (blobVersion != version) {
      throw ProfileSeriesCodecException('unknown codec version $blobVersion');
    }
    final count = reader.readVarUint();
    // Every sample carries at least a one-byte timestamp delta, so a count
    // the remaining payload cannot hold is corruption, not a large series.
    if (count > reader.remaining) {
      throw ProfileSeriesCodecException(
        'sample count $count exceeds the ${reader.remaining} remaining '
        'byte(s)',
      );
    }
    var previous = 0;
    final timestamps = reader.readColumn<int>(count, () {
      previous += reader.readVarInt();
      return previous;
    });
    final pressures = reader.readColumn<double>(count, reader.readFloat64);
    if (!reader.isAtEnd) {
      throw ProfileSeriesCodecException(
        '${reader.remaining} trailing byte(s) after the last block',
      );
    }
    return [
      for (var i = 0; i < count; i++)
        TankPressureSample(
          timestamp:
              timestamps[i] ??
              (throw ProfileSeriesCodecException(
                'sample $i has no timestamp',
              )),
          pressure:
              pressures[i] ??
              (throw ProfileSeriesCodecException(
                'sample $i has no pressure',
              )),
        ),
    ];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart`
Expected: all tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart
git commit -m "feat: TankPressureSeriesCodec"
```

---

### Task 7: Verification and PR

**Files:**
- No new files. This task proves the branch is green and opens the PR.

**Interfaces:**
- Consumes: everything above.
- Produces: an open PR against `main` titled `feat: profile series codec (packed sample storage, part 1)`.

- [ ] **Step 1: Run every codec test file individually**

Run each of these; every one must report `All tests passed!`:

```bash
flutter test test/features/dive_log/domain/codecs/byte_io_test.dart
flutter test test/features/dive_log/domain/codecs/profile_sample_test.dart
flutter test test/features/dive_log/domain/codecs/profile_series_summary_test.dart
flutter test test/features/dive_log/domain/codecs/profile_series_codec_test.dart
flutter test test/features/dive_log/domain/codecs/profile_series_field_table_test.dart
flutter test test/features/dive_log/domain/codecs/tank_pressure_series_codec_test.dart
```

- [ ] **Step 2: Confirm format and analyze are clean project-wide**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
```

Expected: both exit 0. `flutter analyze` must report `No issues found!`; an "info" level finding still fails CI.

- [ ] **Step 3: Confirm the codec files import nothing from Drift or Flutter**

```bash
grep -l "package:drift\|package:flutter" lib/features/dive_log/domain/codecs/*.dart
```

Expected: no output (exit 1 from grep is the success case here).

- [ ] **Step 4: Run the full suite once in the background**

```bash
flutter test --reporter compact > /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/full-suite-pr1.log 2>&1; echo "exit=$?" >> /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/full-suite-pr1.log
```

Run with `run_in_background: true` and a 600000 ms timeout. When it finishes, read the last 30 lines of the log. Expected: `exit=0` and a summary line with zero failures. Do not start a second suite run while this one is going; overlapping runs fake lone failures. If a single unrelated test fails, rerun that one file alone before concluding anything.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin worktree-profile-sample-storage
gh pr create --title "feat: profile series codec (packed sample storage, part 1)" --body-file /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/pr1-body.md
```

Write the body file first with exactly this content (no attribution line, no session URL):

```markdown
## Summary

Part 1 of the packed profile sample storage program
(`docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md`).
Adds a pure-Dart, lossless, versioned codec that packs a series of profile
samples (or a tank's pressure readings) into one zlib-compressed columnar
blob, plus the summary scalars the series tables will store. Nothing in
this PR touches the database, repositories, or sync; part 2 adopts it.

## Why

On a 40-dive database the two row-per-sample tables and their indexes are
25.4 of 28.1 MB (90%). Measured on that data, this codec packs
`dive_profiles` 74x and `tank_pressure_profiles` 129x, lossless.

## What is in it

- `byte_io.dart`: varint, zigzag varint, float64, presence-bitmapped
  column blocks.
- `ProfileSample`: the 28 sample columns of `dive_profiles` as a value
  type, with `DiveProfilePoint` conversions.
- `ProfileSeriesSummary`: the scalars that keep the deco, runtime, and
  quality predicates in SQL.
- `ProfileSeriesCodec`: versioned field table, encode/decode, strict
  failure on anything malformed, forward tolerance for older versions.
- `TankPressureSeriesCodec`: the two-field sibling.
- A test that pins the field table to the live `dive_profiles` column
  list, so a column added without a codec version fails CI.

## Test plan

- Round trips: every field present, every optional field null, mixed
  presence, duplicate timestamps, decreasing integers, float64
  bit-exactness, 20,000 samples.
- Malformed input: non-zlib bytes, empty, unknown version, truncated,
  trailing bytes, absent required column.
- Forward tolerance: a newer decoder reads an older version with the
  missing field null; an unknown version is refused.
- Full suite green locally.
```

- [ ] **Step 6: Report**

Reply with the PR URL, the measured blob size from the 20,000-sample test (print `encoded.bytes.length` once while verifying, then remove the print), and any test that needed a rerun and why.

---

## Self-review

**Spec coverage.** Section 5's layout (version byte, count varint, per-field blocks, three presence modes, delta zigzag ints with reset per block and delta from last present value, float64 reals, run-length strings, zlib level 6, 28-field table in the stated order): Tasks 1 and 4. Section 5's versioning and strict failure: Task 4 (`fieldTables` keyed by version byte, `ProfileSeriesCodecException` on unknown version, truncation, trailing bytes, missing required column). Section 5's "summary scalars computed by the encoder and returned alongside the bytes": Task 3 and `EncodedProfileSeries` in Task 4. Section 4's scalar set for `dive_profile_series` (sample_count, start_timestamp, end_timestamp, max_depth, first_depth, last_depth, has_deco_type, has_deco_stop, has_positive_ceiling): Task 3, one for one. Section 4's scalar set for `tank_pressure_series`: Task 6. Section 10's codec tests (property round trips, largest series, bit-exactness, forward tolerance, the three malformed cases, the field-table-versus-Drift guard): Tasks 4, 5, 6. Section 11's PR 1 scope (codec, exception, summary, tests; no schema or behaviour change): all tasks; Task 7 verifies no Drift or Flutter import leaked into `lib/`. Section 3's layering ("pure Dart, same layering as `track_point_codec.dart`"): files live under `lib/features/dive_log/domain/codecs/`.

Deliberately not in this plan, by spec: the repository, migration packer, sync shim, and benchmark fixture are PR 2.

**Placeholder scan.** Every code step carries the full file or test. No "similar to", no "add handling". The one open-ended instruction, Task 5 step 2's "resolve it in the field table only if the column genuinely is a sample column", is a decision rule, not a placeholder.

## Post-review amendments (2026-08-29)

The whole-branch review after Task 7 added the following on top of the tasks
above. They are recorded here so the plan matches the branch.

- `byte_io.dart`: `readVarUint` rejects a tenth byte whose payload reaches
  bit 63 (the value would wrap negative and escape the count guard as a
  `RangeError`); `ByteWriter.length` removed as dead API.
- `profile_series_codec.dart`: `_validateTable` also rejects duplicate field
  names and runs on decode as well as encode; `decode` rejects a zero sample
  count. `ProfileFieldKind`, `ProfileField`, and the v1 table moved to
  `profile_field_table.dart` (top-level `kProfileFieldTableV1`;
  `ProfileSeriesCodec.fieldTableV1` forwards to it) to keep every file under
  400 lines.
- `tank_pressure_series_codec.dart`: `decode` rejects a zero sample count.
- Tests: absent-timestamp and absent-depth (and absent-pressure) bodies
  built on a two-field table so the tampering stays aligned and reaches the
  `no timestamp` / `no depth` / `no pressure` guards; malformed UTF-8 in a
  string run; duplicate field name refused on both sides; zero count; the
  tank table column pin; `props` length 28; and
  `profile_series_golden_test.dart`, which freezes the v1 wire format as
  hard-coded bytes for both codecs.
- Deferred to PR 2 or later (recorded in the review): narrow the `catch (e)`
  around zlib decode to `on FormatException`; a decode-side monotonic
  timestamp re-check; `ProfileSample.copyWith`; a version-dispatch note on
  the tank codec; a bounded inflate for peer-received blobs; the spec section
  10 summary-scalar SQL equivalence test belongs to PR 2.

**Type consistency.** `ProfileSeriesCodecException(String message)` with a `message` field is used by Tasks 1, 4, 6 and matched by `.having((e) => e.message, ...)` in tests. `ByteWriter.writeColumn<T extends Object>(List<T?>, void Function(T))` and `ByteReader.readColumn<T extends Object>(int, T Function())` are called with `int` and `double` in Tasks 1, 4, 6. `writePresence` returns `bool` and `readPresence` returns `List<bool>`, used by the string column in Task 4. `ProfileSeriesSummary.of(List<ProfileSample>)` is used in Task 4's encode and asserted in its test. `EncodedProfileSeries.bytes`, `.codecVersion`, `.summary` and the tank equivalents match between implementation and tests. `ProfileSeriesCodec.fieldTableV1` and `.version` are referenced by Tasks 4 and 5 with those exact names. `kDecoTypeDecoStop` is defined in Task 3 and used in its test.
