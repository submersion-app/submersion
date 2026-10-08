import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_signature.dart';

List<String> _headersOf(String path) =>
    File(path).readAsLinesSync().first.split(',');

void main() {
  group('looksLikeSeacraftEnc', () {
    test('recognises the real dive fixture (no GPS fix)', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf('test/fixtures/nav_tracks/seacraft_enc3_real.csv'),
        ),
        isTrue,
      );
    });

    test('recognises the fixture with a GPS re-calibration jump', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf('test/fixtures/nav_tracks/seacraft_enc3_gps_fix.csv'),
        ),
        isTrue,
      );
    });

    test('recognises the short manufacturer sample', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf('test/fixtures/nav_tracks/seacraft_enc3_short.csv'),
        ),
        isTrue,
      );
    });

    test('recognises the bench test recording', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf('test/fixtures/nav_tracks/seacraft_enc3_bench.csv'),
        ),
        isTrue,
      );
    });

    test('is case-insensitive and ignores surrounding whitespace', () {
      expect(
        looksLikeSeacraftEnc([' DATE ', 'time', 'POS3DX', 'pos3dy', 'Pos3Dz']),
        isTrue,
      );
    });

    test('tolerates a leading byte order mark on the first header', () {
      expect(
        looksLikeSeacraftEnc([
          '\u{FEFF}Date',
          'Time',
          'Pos3Dx',
          'Pos3Dy',
          'Pos3Dz',
        ]),
        isTrue,
      );
    });

    test('tolerates extra or reordered columns', () {
      expect(
        looksLikeSeacraftEnc([
          'Pos3Dz',
          'Date',
          'SomeFutureColumn',
          'Time',
          'Pos3Dy',
          'Pos3Dx',
          'BattV',
        ]),
        isTrue,
      );
    });

    test('rejects headers missing one required column', () {
      expect(
        looksLikeSeacraftEnc([
          'Date',
          'Time',
          'Pos3Dx',
          'Pos3Dy',
          // Pos3Dz missing
          'Course',
        ]),
        isFalse,
      );
    });

    test('rejects an empty header list', () {
      expect(looksLikeSeacraftEnc(const []), isFalse);
    });

    test('does not misfire on the GPS logger CSV format', () {
      expect(
        looksLikeSeacraftEnc(_headersOf('test/fixtures/gps_tracks/sample.csv')),
        isFalse,
      );
    });

    test('does not misfire on a Subsurface dive-profile CSV export', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf(
            'test/fixtures/subsurface-dive_computer_dive_profile.csv',
          ).map((h) => h.replaceAll('"', '')).toList(),
        ),
        isFalse,
      );
    });

    test('does not misfire on a Subsurface dive-list CSV export', () {
      expect(
        looksLikeSeacraftEnc(
          _headersOf(
            'test/fixtures/subsurface-dive_list.csv',
          ).map((h) => h.replaceAll('"', '')).toList(),
        ),
        isFalse,
      );
    });

    test(
      'does not misfire on a generic dive-log CSV with unrelated columns',
      () {
        expect(
          looksLikeSeacraftEnc([
            'Date',
            'Time',
            'Depth',
            'Duration',
            'Site',
            'Buddy',
          ]),
          isFalse,
        );
      },
    );
  });
}
