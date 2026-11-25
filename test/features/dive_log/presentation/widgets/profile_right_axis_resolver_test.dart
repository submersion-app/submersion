/// Issue #5012: the right axis follows the lines on the chart. The diver's
/// preferred metric keeps it only while its line is drawn.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_resolver.dart';

/// A chart that draws exactly [drawn].
bool Function(ProfileRightAxisMetric) _drawing(
  Set<ProfileRightAxisMetric> drawn,
) => drawn.contains;

void main() {
  group('resolveRightAxisMetric', () {
    test('keeps the preferred metric while its line is drawn', () {
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({
            ProfileRightAxisMetric.temperature,
            ProfileRightAxisMetric.pressure,
          }),
        ),
        ProfileRightAxisMetric.temperature,
      );
    });

    test('moves to a drawn line when the preferred one is hidden', () {
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({ProfileRightAxisMetric.heartRate}),
        ),
        ProfileRightAxisMetric.heartRate,
      );
    });

    test('takes drawn lines in the fallback order', () {
      // Pressure comes before heart rate in fallbackPriority, whatever order
      // the lines were switched on in.
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({
            ProfileRightAxisMetric.heartRate,
            ProfileRightAxisMetric.pressure,
          }),
        ),
        ProfileRightAxisMetric.pressure,
      );
    });

    test('reaches a drawn line outside the fallback order', () {
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({ProfileRightAxisMetric.cns}),
        ),
        ProfileRightAxisMetric.cns,
      );
    });

    test('a fallback-order line wins over any other drawn line', () {
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({
            ProfileRightAxisMetric.gf,
            ProfileRightAxisMetric.ppO2,
          }),
        ),
        ProfileRightAxisMetric.ppO2,
      );
    });

    test('never falls back to ascent rate, which has no line on the axis', () {
      // Its bars are drawn by their own overlay, not against this scale, so
      // the axis menu leaves it out too.
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing({ProfileRightAxisMetric.ascentRate}),
        ),
        isNull,
      );
    });

    test('shows no axis when only depth is drawn', () {
      expect(
        resolveRightAxisMetric(
          ProfileRightAxisMetric.temperature,
          isDrawn: _drawing(const {}),
        ),
        isNull,
      );
    });
  });
}
