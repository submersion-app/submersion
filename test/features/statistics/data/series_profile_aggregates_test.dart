import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/statistics/data/series_profile_aggregates.dart';

void main() {
  List<ProfileSample> ramp({
    required int step,
    required int count,
    required double perStep,
    double start = 0,
  }) => [
    for (var i = 0; i < count; i++)
      ProfileSample(timestamp: i * step, depth: start + i * perStep),
  ];

  group('ascentDescentRates', () {
    test('a steady descent then ascent averages the two transit rates', () {
      // 10 s samples: descend 1 m per 10 s for 120 s (6 m/min), hold, ascend
      // 0.5 m per 10 s (3 m/min, exactly the threshold, included). The last
      // 15 s window of the descent (t 120..130) straddles the hold phase's
      // first sample, which pulls that one window's rate down from -6.0 to
      // -4.0 m/min; the legacy SQL bucketing does the same (verified against
      // it directly), so the pooled descent average is 5.75, not 6.0.
      final samples = [
        ...ramp(step: 10, count: 13, perStep: 1.0), // t 0..120, depth 0..12
        for (var i = 1; i <= 6; i++)
          ProfileSample(timestamp: 120 + i * 10, depth: 12.0), // hold to 180
        for (var i = 1; i <= 24; i++)
          ProfileSample(
            timestamp: 180 + i * 10,
            depth: 12.0 - i * 0.5,
          ), // ascend to 0 at 420
      ];
      final r = ascentDescentRates({('d1', 'c1'): samples});
      expect(r.avgDescent, closeTo(5.75, 0.01));
      expect(r.avgAscent, closeTo(3.0, 0.01));
    });

    test('a flat profile yields nulls', () {
      final r = ascentDescentRates({
        ('d1', null): [
          for (var t = 0; t <= 300; t += 10)
            ProfileSample(timestamp: t, depth: 20.0),
        ],
      });
      expect(r.avgAscent, isNull);
      expect(r.avgDescent, isNull);
    });

    test('windows are averaged per stream, not across dives', () {
      final descent = ramp(step: 10, count: 13, perStep: 1.0);
      final r1 = ascentDescentRates({('d1', 'c1'): descent});
      final r2 = ascentDescentRates({
        ('d1', 'c1'): descent,
        ('d2', 'c1'): descent,
      });
      expect(r2.avgDescent, closeTo(r1.avgDescent!, 1e-9));
    });

    test('empty input yields nulls', () {
      final r = ascentDescentRates(const {});
      expect(r.avgAscent, isNull);
      expect(r.avgDescent, isNull);
    });
  });

  group('timeAtDepthRanges', () {
    test('buckets whole intervals by the interval start depth and caps gaps', () {
      // 60 s at 5 m, 60 s at 15 m, then a 600 s gap (capped by cadence), then 60 s at 25 m
      final samples = [
        const ProfileSample(timestamp: 0, depth: 5.0),
        const ProfileSample(timestamp: 60, depth: 15.0),
        const ProfileSample(timestamp: 120, depth: 25.0),
        const ProfileSample(timestamp: 720, depth: 25.0),
        const ProfileSample(timestamp: 780, depth: 25.0),
      ];
      // cadence cap = (780 - 0) * 4 / (5 - 1) = 780 s, so the 600 s gap is kept whole
      final r = timeAtDepthRanges({('d1', null): samples});
      expect(r, [
        (lowerDepth: 0, upperDepth: 10, minutes: 1),
        (lowerDepth: 10, upperDepth: 20, minutes: 1),
        (lowerDepth: 20, upperDepth: 30, minutes: 11),
      ]);
    });

    test('a gap longer than the cadence cap is clipped to the cap', () {
      // 10 s cadence for 5 samples then a 3600 s gap: cap = (3640 * 4) / 5 = 2912
      final samples = [
        for (var i = 0; i < 5; i++)
          ProfileSample(timestamp: i * 10, depth: 45.0),
        const ProfileSample(timestamp: 3640, depth: 45.0),
      ];
      final r = timeAtDepthRanges({('d1', null): samples});
      expect(r.single.lowerDepth, 40);
      expect(r.single.upperDepth, isNull);
      expect(r.single.minutes, ((40 + 2912) / 60).round());
    });

    test('a stream with a single sample contributes nothing', () {
      expect(
        timeAtDepthRanges({
          ('d1', null): const [ProfileSample(timestamp: 0, depth: 10.0)],
        }),
        isEmpty,
      );
    });

    test('buckets come back ascending by lower depth', () {
      final r = timeAtDepthRanges({
        ('d1', null): [
          const ProfileSample(timestamp: 0, depth: 35.0),
          const ProfileSample(timestamp: 60, depth: 5.0),
          const ProfileSample(timestamp: 120, depth: 5.0),
        ],
      });
      expect(r.map((b) => b.lowerDepth), [0, 30]);
    });
  });

  test('the blob entry points decode and agree with the pure functions', () {
    const codec = ProfileSeriesCodec();
    final ascentSamples = [
      for (var i = 0; i <= 12; i++)
        ProfileSample(timestamp: i * 15, depth: i * 2.0),
      for (var i = 1; i <= 12; i++)
        ProfileSample(timestamp: 180 + i * 15, depth: 24.0 - i * 2.0),
    ];
    final depthSamples = [
      const ProfileSample(timestamp: 0, depth: 5.0),
      const ProfileSample(timestamp: 60, depth: 15.0),
      const ProfileSample(timestamp: 120, depth: 25.0),
      const ProfileSample(timestamp: 180, depth: 25.0),
    ];

    final blobs = [
      SeriesBlob(
        diveId: 'd1',
        computerId: 'c1',
        samples: codec.encode(ascentSamples).bytes,
      ),
      SeriesBlob(
        diveId: 'd2',
        computerId: null,
        samples: codec.encode(depthSamples).bytes,
      ),
    ];
    final byStream = {('d1', 'c1'): ascentSamples, ('d2', null): depthSamples};

    expect(ascentDescentRatesFromBlobs(blobs), ascentDescentRates(byStream));
    expect(timeAtDepthRangesFromBlobs(blobs), timeAtDepthRanges(byStream));
  });

  test(
    'one corrupt blob is skipped rather than blanking the whole aggregate',
    () {
      const codec = ProfileSeriesCodec();
      final descent = ramp(step: 10, count: 13, perStep: 1.0);
      final blobs = [
        SeriesBlob(
          diveId: 'd1',
          computerId: 'c1',
          samples: codec.encode(descent).bytes,
        ),
        SeriesBlob(
          diveId: 'd2',
          computerId: 'c1',
          samples: Uint8List.fromList([1, 2, 3]),
        ),
      ];

      final r = ascentDescentRatesFromBlobs(blobs);

      expect(r, ascentDescentRates({('d1', 'c1'): descent}));
    },
  );
}
