import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/profile_depth_sanitizer.dart';

void main() {
  group('repairDepthOutliers', () {
    test('replaces a single spiked sample with its neighbours', () {
      final depths = [10.0, 10.2, 47.0, 10.6, 10.8];
      final timestamps = [0, 2, 4, 6, 8];

      final repaired = repairDepthOutliers(depths, timestamps);

      expect(repaired[2], closeTo(10.4, 0.01));
      expect(repaired[0], 10.0);
      expect(repaired[4], 10.8);
    });

    test('leaves a fast but physically possible ascent alone', () {
      // 36 m/min is the fastest rate seen across a real 40-dive logbook.
      final depths = [20.0, 18.8, 17.6, 16.4, 15.2];
      final timestamps = [0, 2, 4, 6, 8];

      expect(repairDepthOutliers(depths, timestamps), equals(depths));
    });

    test('leaves a step change alone when it is not a spike', () {
      // One large jump that the profile stays at is a gap or a real descent,
      // not a bad reading: only an out-and-back excursion is repaired.
      final depths = [10.0, 10.2, 40.0, 40.2, 40.4];
      final timestamps = [0, 2, 4, 6, 8];

      expect(repairDepthOutliers(depths, timestamps), equals(depths));
    });

    test('preserves length so analysis curves stay index-aligned', () {
      final depths = [10.0, 10.2, 47.0, 10.6, 10.8];
      final timestamps = [0, 2, 4, 6, 8];

      expect(repairDepthOutliers(depths, timestamps), hasLength(depths.length));
    });

    test('tolerates duplicate timestamps without dividing by zero', () {
      final depths = [10.0, 10.0, 47.0, 10.6];
      final timestamps = [0, 0, 2, 4];

      final repaired = repairDepthOutliers(depths, timestamps);

      expect(repaired.every((d) => d.isFinite), isTrue);
    });
  });
}
