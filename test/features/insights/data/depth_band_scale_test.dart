import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/data/depth_band_scale.dart';
import 'package:submersion/features/insights/data/series_profile_aggregates.dart';

void main() {
  group('DepthBandScale', () {
    test('forUnit maps units', () {
      expect(DepthBandScale.forUnit(DepthUnit.meters), DepthBandScale.metric);
      expect(DepthBandScale.forUnit(DepthUnit.feet), DepthBandScale.imperial);
    });

    test('edge depths land in the deeper band', () {
      expect(DepthBandScale.metric.bandOf(30.0), 3);
      expect(DepthBandScale.metric.bandOf(29.99), 2);
      // 60 ft is stored as 18.288 m; float division must not drop it to 1.
      expect(DepthBandScale.imperial.bandOf(18.288), 2);
      expect(DepthBandScale.imperial.bandOf(9.144 * 7), 7);
    });

    test('negative depth counts in the first band', () {
      expect(DepthBandScale.metric.bandOf(-0.4), 0);
    });
  });

  group('bucketsFromSeconds', () {
    test('fills gaps with zero bars', () {
      expect(bucketsFromSeconds({0: 300, 4: 600}), [
        (lowerDepth: 0, upperDepth: 10, minutes: 5),
        (lowerDepth: 10, upperDepth: 20, minutes: 0),
        (lowerDepth: 20, upperDepth: 30, minutes: 0),
        (lowerDepth: 30, upperDepth: 40, minutes: 0),
        (lowerDepth: 40, upperDepth: 50, minutes: 10),
      ]);
    });

    test('caps at eight bars with an open-ended last bar', () {
      final buckets = bucketsFromSeconds({for (var i = 0; i < 12; i++) i: 60});
      expect(buckets, hasLength(timeAtDepthMaxBars));
      expect(buckets.last, (lowerDepth: 70, upperDepth: null, minutes: 5));
      expect(buckets[6], (lowerDepth: 60, upperDepth: 70, minutes: 1));
    });

    test('exactly eight bands stay closed', () {
      final buckets = bucketsFromSeconds({for (var i = 0; i < 8; i++) i: 60});
      expect(buckets, hasLength(8));
      expect(buckets.last, (lowerDepth: 70, upperDepth: 80, minutes: 1));
    });

    test('cap sums seconds before rounding', () {
      final buckets = bucketsFromSeconds({0: 60, 7: 20, 8: 20, 9: 20});
      expect(buckets.last, (lowerDepth: 70, upperDepth: null, minutes: 1));
    });

    test('imperial edges', () {
      final buckets = bucketsFromSeconds({
        0: 60,
        2: 60,
      }, scale: DepthBandScale.imperial);
      expect(buckets.map((b) => b.lowerDepth), [0, 30, 60]);
      expect(buckets.map((b) => b.upperDepth), [30, 60, 90]);
    });

    test('a sliver of deep time does not add empty trailing bars', () {
      // A two-second glitch at 95 m rounds to no minutes at all.
      expect(bucketsFromSeconds({0: 600, 9: 2}), [
        (lowerDepth: 0, upperDepth: 10, minutes: 10),
      ]);
    });

    test('an open-ended bar that rounds to nothing is dropped too', () {
      expect(bucketsFromSeconds({0: 600, 1: 600, 7: 20, 12: 5}), [
        (lowerDepth: 0, upperDepth: 10, minutes: 10),
        (lowerDepth: 10, upperDepth: 20, minutes: 10),
      ]);
    });

    test('a log of slivers still keeps its first bar', () {
      expect(bucketsFromSeconds({3: 10}), [
        (lowerDepth: 0, upperDepth: 10, minutes: 0),
      ]);
    });

    test('empty seconds give no buckets', () {
      expect(bucketsFromSeconds(const {}), isEmpty);
    });
  });
}
