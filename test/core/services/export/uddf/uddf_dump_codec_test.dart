import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';

void main() {
  group('UddfDumpCodec', () {
    test('round trips the committed libdivecomputer fixtures', () {
      const paths = [
        'packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin',
        'packages/libdivecomputer_plugin/test/native/fixtures/'
            'petrel3_ccr_o2_cells.bin',
        'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
            'shearwater_teric_dive.bin',
      ];

      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing fixture: $path');
        final raw = Uint8List.fromList(file.readAsBytesSync());

        final encoded = UddfDumpCodec.encodeOne(raw);
        expect(encoded, isNotEmpty);

        final decoded = UddfDumpCodec.decodeOne(encoded);
        expect(decoded, equals(raw), reason: 'round trip failed for $path');
      }
    });

    test('round trips empty and single byte payloads', () {
      for (final raw in [
        Uint8List(0),
        Uint8List.fromList([0x42]),
      ]) {
        expect(
          UddfDumpCodec.decodeOne(UddfDumpCodec.encodeOne(raw)),
          equals(raw),
        );
      }
    });

    test('decode tolerates surrounding whitespace from pretty printed XML', () {
      final raw = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
      final encoded = UddfDumpCodec.encodeOne(raw);
      expect(UddfDumpCodec.decodeOne('\n  $encoded\n  '), equals(raw));
    });

    test('decode refuses a payload that expands past the ceiling', () {
      // Built with the raw encoder rather than encodeOne, which refuses an
      // oversized input up front. Highly compressible: megabytes of zeros
      // bzip2 down to a few hundred bytes, so the guard has to fire during
      // the decode itself rather than on the size of the encoded text.
      final encoded = base64.encode(
        BZip2Encoder().encodeBytes(Uint8List(12 * 1024 * 1024)),
      );
      expect(
        encoded.length,
        lessThan(kMaxRawDiveBlobBytes),
        reason:
            'the encoded text must be small, or the bound under test '
            'would be the input size rather than the inflated size',
      );

      expect(
        () => UddfDumpCodec.decodeOne(encoded),
        throwsA(isA<UddfDumpTooLargeException>()),
      );
    });

    test('encode never mints a dump its own decoder would refuse', () {
      // The invariant behind the test above: the encoder's guard is what
      // makes it impossible to write a file we could not read back.
      expect(
        () => UddfDumpCodec.encodeOne(Uint8List(kMaxRawDiveBlobBytes + 1)),
        throwsA(isA<UddfDumpTooLargeException>()),
      );
    });

    test('decode never silently returns corrupted bytes', () {
      // These bytes are the only recoverable copy of a download, so a damaged
      // payload has to fail rather than restore something subtly wrong. bzip2
      // carries block and stream CRCs, but the decoder only compares them
      // when asked to verify.
      final raw = Uint8List.fromList(
        List<int>.generate(2048, (i) => (i * 13) % 256),
      );
      final compressed = BZip2Encoder().encodeBytes(raw);

      var checked = 0;
      // Walk past the 4-byte header so the corruption lands in the payload.
      for (var i = 8; i < compressed.length; i += 37) {
        final damaged = Uint8List.fromList(compressed);
        damaged[i] ^= 0xFF;

        checked++;
        try {
          final decoded = UddfDumpCodec.decodeOne(base64.encode(damaged));
          expect(
            decoded,
            equals(raw),
            reason:
                'byte $i decoded without error, so it must match the '
                'original exactly; anything else is silent corruption',
          );
        } on FormatException {
          // The wanted outcome: refused rather than silently wrong.
        } on UddfDumpTooLargeException {
          // Also fine: garbage that inflates past the ceiling.
        }
      }

      expect(checked, greaterThan(4), reason: 'sanity: the loop ran');
    });

    test('decode rejects text that is not bzip2', () {
      expect(
        () => UddfDumpCodec.decodeOne('bm90IGJ6aXAy'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'encodeAll yields null for a failed blob and keeps the rest',
      () async {
        final good = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final tooBig = Uint8List(kMaxRawDiveBlobBytes + 1);

        final result = await UddfDumpCodec.encodeAll([good, tooBig, good]);

        expect(result.length, 3);
        expect(result[0], isNotNull);
        expect(result[1], isNull);
        expect(result[2], isNotNull);
        expect(UddfDumpCodec.decodeOne(result[0]!), equals(good));
      },
    );
  });
}
