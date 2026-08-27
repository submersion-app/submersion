import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_raw_decompressor.dart';

/// A Shearwater-compressed log produced outside Dart, by the inverse of
/// libdivecomputer's `shearwater_common_decompress_lre` / `_decompress_xor`.
/// The generator round-trips through a decoder verified against 267 real
/// MacDive `ZRAWDATA` blobs, so this fixture pins the Dart port to bytes it
/// did not produce itself.
const _compressedHex =
    '8801e021780c040d010bc0e061e80c043d078387a03010f4'
    '520a0ca70360bdc02660351401c076a0b8183ac404f502e0'
    '20e9d80e079f05c1c1dff02438352501c0f280b8383acc04'
    'f702e020e9c80e03ba05c0c1d14026583301f600a420da70'
    '3609ec01406021e81c0c3d018087a0f070f406021eed4143'
    'c00000000000';

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void main() {
  group('ShearwaterRawDecompressor', () {
    test('recovers Petrel Native Format from a compressed log', () {
      final out = ShearwaterRawDecompressor.decompress(_hex(_compressedHex));

      expect(out, isNotNull);
      expect(out!.length % 32, 0, reason: 'PNF records are 32 bytes');

      final types = <int>[for (var i = 0; i < out.length; i += 32) out[i]];
      // libdivecomputer requires opening and closing records 0..5.
      for (var i = 0; i < 6; i++) {
        expect(types, contains(0x10 + i), reason: 'opening record $i');
        expect(types, contains(0x20 + i), reason: 'closing record $i');
      }
      expect(types, contains(0xFF), reason: 'final record');
    });

    test('decodes the sample series with correct field offsets', () {
      final out = ShearwaterRawDecompressor.decompress(_hex(_compressedHex))!;

      final depths = <double>[];
      final temps = <int>[];
      final pressures = <int>[];
      for (var i = 0; i < out.length; i += 32) {
        if (out[i] != 0x01) continue;
        depths.add(((out[i + 1] << 8) | out[i + 2]) / 10.0);
        temps.add(out[i + 14].toSigned(8));
        pressures.add((((out[i + 28] << 8) | out[i + 29]) & 0x0FFF) * 2);
      }

      expect(depths, [
        0.0,
        15.2,
        30.1,
        45.5,
        60.0,
        59.8,
        45.0,
        30.0,
        15.0,
        0.0,
      ]);
      expect(temps, [78, 78, 77, 76, 75, 75, 76, 77, 78, 78]);
      expect(pressures, [
        3000,
        2960,
        2900,
        2850,
        2780,
        2710,
        2650,
        2600,
        2560,
        2520,
      ]);
    });

    test('reads the units flag from opening record 0', () {
      final out = ShearwaterRawDecompressor.decompress(_hex(_compressedHex))!;
      // Scan record boundaries: 0x10 is a record *type*, and the same byte
      // value occurs freely inside sample payloads.
      final open0 = [
        for (var i = 0; i < out.length; i += 32)
          if (out[i] == 0x10) i,
      ];
      expect(open0, hasLength(1));
      expect(out[open0.single + 8], 1, reason: '1 = imperial');
    });

    test('rejects data whose bit count is not a multiple of 9', () {
      // 8 bytes = 64 bits, not divisible by 9.
      expect(
        ShearwaterRawDecompressor.decompress(
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        ),
        isNull,
      );
    });

    test('rejects empty input', () {
      expect(ShearwaterRawDecompressor.decompress(Uint8List(0)), isNull);
    });

    test('stops at the terminator and ignores trailing padding', () {
      // One literal byte (0x1AA), then the zero terminator, then padding.
      // 9 bits * 8 = 72 bits = 9 bytes, satisfying the multiple-of-9 rule.
      final bits = StringBuffer()
        ..write(
          '1'
          '10101010',
        ) // literal 0xAA
        ..write(
          '0'
          '00000000',
        ); // terminator
      while (bits.length % 72 != 0) {
        bits.write('1'); // padding that would decode to literals if not stopped
      }
      final s = bits.toString();
      final bytes = Uint8List(s.length ~/ 8);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(s.substring(i * 8, i * 8 + 8), radix: 2);
      }

      expect(ShearwaterRawDecompressor.decompress(bytes), [0xAA]);
    });

    test('applyXorDelta leaves the first 32-byte block unchanged', () {
      final data = Uint8List.fromList(List.generate(64, (i) => i));
      final first = data.sublist(0, 32);
      ShearwaterRawDecompressor.applyXorDelta(data);
      expect(data.sublist(0, 32), first);
      // Second block: 32..63 XORed with 0..31.
      for (var i = 32; i < 64; i++) {
        expect(data[i], i ^ (i - 32));
      }
    });
  });
}
