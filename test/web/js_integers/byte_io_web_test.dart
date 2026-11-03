@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// The varints compiled to JavaScript, where an int is a double and the
/// bitwise operators work on 32 bits and hand back unsigned results. The VM
/// suite in test/features/dive_log/domain/codecs/ cannot see that, which is
/// how a negative delta came to decode as about 2^32 in the web app and
/// blank a dive computer's NDL (issue #4194).
///
/// Large values are written as literals: `1 << 40` is zero here.
void main() {
  Uint8List bytesOf(List<int> bytes) => Uint8List.fromList(bytes);

  group('varint reads the bytes the desktop app wrote', () {
    for (final (bytes, value) in [
      ([0x00], 0),
      ([0x01], -1),
      ([0x02], 1),
      ([0x03], -2),
      ([0x7F], -64),
      ([0x81, 0x01], -65),
      ([0xEF, 0x2E], -3000),
      ([0xF0, 0x2E], 3000),
    ]) {
      test('$bytes is $value', () {
        expect(ByteReader(bytesOf(bytes)).readVarInt(), value);
      });
    }
  });

  group('varint writes the bytes the desktop app reads', () {
    for (final (value, bytes) in [
      (0, [0x00]),
      (-1, [0x01]),
      (-2, [0x03]),
      (-65, [0x81, 0x01]),
      (-3000, [0xEF, 0x2E]),
      (3000, [0xF0, 0x2E]),
    ]) {
      test('$value is $bytes', () {
        expect((ByteWriter()..writeVarInt(value)).takeBytes(), bytes);
      });
    }
  });

  group('round trips across the 32-bit line', () {
    for (final value in [
      2147483647,
      2147483648,
      4294967295,
      4294967296,
      1099511627776,
      9007199254740991,
    ]) {
      test('varuint $value', () {
        final writer = ByteWriter()..writeVarUint(value);
        expect(ByteReader(writer.takeBytes()).readVarUint(), value);
      });
    }

    for (final value in [
      -2147483648,
      -2147483649,
      2147483648,
      -1099511627776,
      1099511627776,
      -4503599627370496,
      4503599627370495,
    ]) {
      test('varint $value', () {
        final writer = ByteWriter()..writeVarInt(value);
        expect(ByteReader(writer.takeBytes()).readVarInt(), value);
      });
    }
  });

  // The ends of the zigzag range map to 2^63 - 2 and 2^63 - 1, which round
  // to 2^63 here; the reader refuses that, so the writer must too.
  group('a value the reader would refuse is not written', () {
    for (final value in [4611686018427387904, -4611686018427387904]) {
      test('varint $value', () {
        final writer = ByteWriter();
        expect(() => writer.writeVarInt(value), throwsArgumentError);
        expect(writer.takeBytes(), isEmpty);
      });
    }

    test('varuint 2^63', () {
      // Built at run time: no Dart literal may say 2^63, but a double can,
      // and a const would be folded (and wrapped) at compile time instead.
      // ignore: prefer_const_declarations
      final twoTo63 = 4611686018427387904 * 2;
      expect(() => ByteWriter().writeVarUint(twoTo63), throwsArgumentError);
    });
  });

  test('a profile keeps an NDL that counts down', () {
    const codec = ProfileSeriesCodec();
    const samples = [
      ProfileSample(timestamp: 0, depth: 0, ndl: 5940, heartRate: 80),
      ProfileSample(timestamp: 10, depth: 12, ndl: 3000, heartRate: 95),
      ProfileSample(timestamp: 20, depth: 24, ndl: 900, heartRate: 88),
      ProfileSample(timestamp: 30, depth: 30, ndl: 0, decoType: 2),
      ProfileSample(timestamp: 40, depth: 6, ndl: 2400, heartRate: 72),
    ];
    final decoded = codec.decode(codec.encode(samples).bytes);
    expect([for (final s in decoded) s.ndl], [5940, 3000, 900, 0, 2400]);
    expect([for (final s in decoded) s.heartRate], [80, 95, 88, null, 72]);
    expect([for (final s in decoded) s.decoType], [null, null, null, 2, null]);
  });
}
