import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/features/nav_track/domain/nav_track_source_file_codec.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('nav track source file codec (issue #4231)', () {
    test('round-trips a file byte for byte', () {
      // LF endings, no BOM and no final newline, as the console writes it:
      // nothing may be normalised on the way through.
      final original = _bytes(
        'Date,Time,Pos3Dx,Pos3Dy,Pos3Dz,Course,Pitch,Roll,'
        'Distance,Speed,Temp,BattV\n'
        '1.11.2026,11:46:14,36512.324219,6966.21875,2,246.4,-34.9,-5,'
        '0.45,27.7,14,3.92\n'
        '1.11.2026,12:12:08,36969.019531,6648.476563,34.299999,157.1,2.2,'
        '-3.2,666.26,14.5,7.5,-101',
      );

      final decoded = decodeNavTrackSourceFile(
        encodeNavTrackSourceFile(original),
      );

      expect(decoded, original);
    });

    test('keeps a byte order mark and CRLF endings as they were', () {
      final original = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('Date,Time\r\n1.1.2026,10:00:00\r\n'),
      ]);

      expect(
        decodeNavTrackSourceFile(encodeNavTrackSourceFile(original)),
        original,
      );
    });

    test('stores the file compressed', () {
      final original = _bytes('1.11.2026,11:46:14,0,0,2,246.4\n' * 2000);

      final blob = encodeNavTrackSourceFile(original);

      expect(blob.length, lessThan(original.length ~/ 4));
    });

    test('refuses to encode a file over the cap', () {
      final tooLarge = Uint8List(kMaxNavTrackSourceFileBytes + 1);

      expect(
        () => encodeNavTrackSourceFile(tooLarge),
        throwsA(isA<NavTrackSourceFileCodecException>()),
      );
    });

    test('rejects a blob that is not gzip', () {
      expect(
        () => decodeNavTrackSourceFile(_bytes('not a gzip stream')),
        throwsA(isA<NavTrackSourceFileCodecException>()),
      );
    });

    test('rejects a blob that inflates past the cap', () {
      final bomb = PlatformZlib.gzip(
        Uint8List(kMaxNavTrackSourceFileBytes + 1),
      );

      expect(
        () => decodeNavTrackSourceFile(bomb),
        throwsA(isA<NavTrackSourceFileCodecException>()),
      );
    });
  });
}
