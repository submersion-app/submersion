import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_gf99_aligner.dart';

void main() {
  List<Map<String, dynamic>> samplesAt(List<int> times) => [
    for (final t in times) <String, dynamic>{'timestamp': t, 'depth': 10.0},
  ];

  ShearwaterGf99Sample gf(int t, int value) =>
      ShearwaterGf99Sample(timeSeconds: t, gf99: value);

  group('ShearwaterGf99Aligner.apply', () {
    test('returns the samples untouched when the series is empty', () {
      final samples = samplesAt([0, 10, 20]);
      final result = ShearwaterGf99Aligner.apply(samples, const []);
      expect(result, samples);
      expect(result.any((s) => s.containsKey('gf99')), isFalse);
    });

    test('returns an empty list for no samples', () {
      final result = ShearwaterGf99Aligner.apply(const [], [gf(0, 5)]);
      expect(result, isEmpty);
    });

    test('sets gf99 on samples whose time matches exactly', () {
      final result = ShearwaterGf99Aligner.apply(samplesAt([0, 10, 20]), [
        gf(0, 3),
        gf(10, 7),
        gf(20, 11),
      ]);
      expect(result.map((s) => s['gf99']), [3, 7, 11]);
    });

    test('picks the nearest point within half the sample interval', () {
      // 10 s samples: tolerance is 5 s.
      final result = ShearwaterGf99Aligner.apply(samplesAt([0, 10, 20, 30]), [
        gf(4, 1), // 4 s from sample 0: kept
        gf(16, 2), // 4 s from sample 20: kept
        gf(37, 3), // 7 s from sample 30: too far
      ]);
      expect(result[0]['gf99'], 1);
      expect(result[1].containsKey('gf99'), isFalse);
      expect(result[2]['gf99'], 2);
      expect(result[3].containsKey('gf99'), isFalse);
    });

    test('prefers the closer of two candidates on either side', () {
      final result = ShearwaterGf99Aligner.apply(samplesAt([0, 10, 20]), [
        gf(7, 1), // 3 s before 10
        gf(11, 2), // 1 s after 10: closer
      ]);
      expect(result[1]['gf99'], 2);
      expect(result[0].containsKey('gf99'), isFalse);
      expect(result[2].containsKey('gf99'), isFalse);
    });

    test('tolerates an unsorted series', () {
      final result = ShearwaterGf99Aligner.apply(samplesAt([0, 10, 20]), [
        gf(20, 3),
        gf(0, 1),
        gf(10, 2),
      ]);
      expect(result.map((s) => s['gf99']), [1, 2, 3]);
    });

    test('uses the series spacing for the tolerance when there is a single '
        'sample', () {
      final result = ShearwaterGf99Aligner.apply(samplesAt([12]), [
        gf(0, 1),
        gf(10, 2),
        gf(20, 3),
      ]);
      expect(result.single['gf99'], 2);
    });

    test('requires an exact match when no interval can be derived', () {
      expect(
        ShearwaterGf99Aligner.apply(samplesAt([12]), [gf(10, 2)]).single,
        isNot(contains('gf99')),
      );
      expect(
        ShearwaterGf99Aligner.apply(samplesAt([10]), [
          gf(10, 2),
        ]).single['gf99'],
        2,
      );
    });

    test('does not mutate the input maps', () {
      final samples = samplesAt([0, 10]);
      final before = samples.map(Map<String, dynamic>.from).toList();
      ShearwaterGf99Aligner.apply(samples, [gf(0, 1), gf(10, 2)]);
      expect(samples, before);
    });

    test('keeps every other key of the sample', () {
      final samples = [
        <String, dynamic>{'timestamp': 0, 'depth': 1.0, 'ppO2': 1.2},
      ];
      final result = ShearwaterGf99Aligner.apply(samples, [gf(0, 9)]);
      expect(result.single, {
        'timestamp': 0,
        'depth': 1.0,
        'ppO2': 1.2,
        'gf99': 9,
      });
    });

    test('skips samples without a numeric timestamp', () {
      final samples = [
        <String, dynamic>{'depth': 1.0},
        <String, dynamic>{'timestamp': 10, 'depth': 2.0},
      ];
      final result = ShearwaterGf99Aligner.apply(samples, [
        gf(0, 1),
        gf(10, 2),
      ]);
      expect(result[0].containsKey('gf99'), isFalse);
      expect(result[1]['gf99'], 2);
    });
  });
}
