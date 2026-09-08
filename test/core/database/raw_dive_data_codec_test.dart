import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// The three fixtures are the real libdivecomputer downloads already
/// committed to this repository. Compressing a synthetic byte pattern would
/// measure the pattern, not the payload, and the 2026-04-15 spec's "negligible
/// savings" ruling came from exactly that mistake.
Uint8List fixture(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

const teric =
    'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
    'shearwater_teric_dive.bin';
const petrel3 =
    'packages/libdivecomputer_plugin/test/native/fixtures/'
    'petrel3_ccr_o2_cells.bin';
const smallDive =
    'packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin';

void main() {
  group('round trip', () {
    for (final path in [teric, petrel3, smallDive]) {
      test('$path survives encode then decode and gets smaller', () {
        final raw = fixture(path);
        final encoded = encodeRawDiveData(raw);

        expect(encoded.length, lessThan(raw.length));
        expect(isCompressedRawDiveData(encoded), isTrue);
        expect(decodeRawDiveData(encoded), equals(raw));
      });
    }
  });

  test('encode does not mutate its input', () {
    final raw = fixture(teric);
    final before = Uint8List.fromList(raw);

    encodeRawDiveData(raw);

    expect(raw, equals(before));
  });

  test('incompressible bytes are stored raw and read back unchanged', () {
    // 32 random-looking bytes: zlib cannot beat 8 bytes of header plus its
    // own framing on a payload this small.
    final raw = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 97 + 13) & 0xFF),
    );

    final encoded = encodeRawDiveData(raw);

    expect(encoded, equals(raw));
    expect(isCompressedRawDiveData(encoded), isFalse);
    expect(decodeRawDiveData(encoded), equals(raw));
  });

  test('legacy bytes with no magic pass through untouched', () {
    final legacy = fixture(teric);

    expect(decodeRawDiveData(legacy), equals(legacy));
  });

  test('a legacy blob that begins with the magic reads back as itself', () {
    // The one collision the format cannot rule out by the magic alone. It
    // survives because decode also requires the body to inflate to exactly
    // the declared length, and this body is not a zlib stream at all.
    final legacy = Uint8List.fromList([
      ...kRawDiveDataMagic,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);

    expect(decodeRawDiveData(legacy), equals(legacy));
  });

  test('a truncated stream behind a valid magic reads back as stored', () {
    // zlib accepts a truncated stream and returns what it managed to inflate,
    // with no error. Only the declared-length check catches this.
    final encoded = encodeRawDiveData(fixture(teric));
    final truncated = Uint8List.sublistView(encoded, 0, encoded.length - 40);

    expect(decodeRawDiveData(truncated), equals(truncated));
  });

  test('a declared length past the cap is refused, not inflated', () {
    final encoded = encodeRawDiveData(fixture(teric));
    final tampered = Uint8List.fromList(encoded);
    ByteData.sublistView(tampered).setUint32(4, 0x7FFFFFFF, Endian.little);

    expect(decodeRawDiveData(tampered), equals(tampered));
  });

  test('a zlib bomb is abandoned, not inflated', () {
    // 64 MiB of zeroes compresses to a few tens of KiB and is well past
    // kMaxRawDiveBlobBytes, so the bound must stop it mid-stream.
    final bomb = ZLibCodec(level: 9).encode(Uint8List(64 * 1024 * 1024));
    final blob = Uint8List.fromList([
      ...kRawDiveDataMagic,
      0x00,
      0x00,
      0x00,
      0x04, // declares 64 MiB, little-endian
      ...bomb,
    ]);

    expect(decodeRawDiveData(blob), equals(blob));
  });

  test('a blob over the cap is stored raw so decode can still read it', () {
    // The encoder must never mint something its own decode bound refuses.
    final huge = Uint8List(kMaxRawDiveBlobBytes + 1);

    final encoded = encodeRawDiveData(huge);

    expect(encoded, same(huge));
    expect(decodeRawDiveData(encoded), equals(huge));
  });

  test('empty and single-byte blobs round trip', () {
    for (final raw in [
      Uint8List(0),
      Uint8List.fromList([42]),
    ]) {
      final encoded = encodeRawDiveData(raw);
      expect(decodeRawDiveData(encoded), equals(raw));
    }
  });

  group('RawDiveDataConverter', () {
    const converter = RawDiveDataConverter();

    test('toSql compresses and fromSql restores', () {
      final raw = fixture(teric);
      final stored = converter.toSql(raw);

      expect(stored.length, lessThan(raw.length));
      expect(converter.fromSql(stored), equals(raw));
    });

    test('fromSql reads a legacy uncompressed row', () {
      final legacy = fixture(teric);

      expect(converter.fromSql(legacy), equals(legacy));
    });
  });
}
