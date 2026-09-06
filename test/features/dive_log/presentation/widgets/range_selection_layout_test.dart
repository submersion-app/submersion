import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/range_selection_layout.dart';

void main() {
  group('RangePlotAxis', () {
    // A 400 px chart with the profile chart's real gutters: 48 px of
    // axis name + depth ticks on the left, 54 px of right axis, leaving a
    // 298 px plot rect that starts at x = 48.
    const axis = RangePlotAxis(
      plotLeft: 48,
      plotWidth: 298,
      visibleMinSeconds: 0,
      visibleMaxSeconds: 3600,
    );

    test('the start of the dive sits on the left edge of the plot rect', () {
      expect(axis.xForSeconds(0), 48);
    });

    test('the end of the dive sits on the right edge of the plot rect', () {
      expect(axis.xForSeconds(3600), 48 + 298);
    });

    test('interpolates linearly between the plot edges', () {
      expect(axis.xForSeconds(1800), closeTo(48 + 149, 0.001));
    });

    test('secondsForX inverts xForSeconds', () {
      expect(axis.secondsForX(axis.xForSeconds(900)), closeTo(900, 0.001));
    });

    test('reports whether a timestamp is inside the visible window', () {
      expect(axis.isVisible(0), isTrue);
      expect(axis.isVisible(3600), isTrue);
      expect(axis.isVisible(-1), isFalse);
      expect(axis.isVisible(3601), isFalse);
    });

    test('clamps positions of off-window timestamps to the plot rect', () {
      expect(axis.clampedXForSeconds(-600), 48);
      expect(axis.clampedXForSeconds(7200), 48 + 298);
    });

    group('when the chart is zoomed', () {
      // Zoomed 2x onto the second half of the same dive.
      const zoomed = RangePlotAxis(
        plotLeft: 48,
        plotWidth: 298,
        visibleMinSeconds: 1800,
        visibleMaxSeconds: 3600,
      );

      test('maps the visible window across the whole plot rect', () {
        expect(zoomed.xForSeconds(1800), 48);
        expect(zoomed.xForSeconds(3600), 48 + 298);
        expect(zoomed.xForSeconds(2700), closeTo(48 + 149, 0.001));
      });

      test('reports timestamps scrolled off the left as not visible', () {
        expect(zoomed.isVisible(0), isFalse);
      });

      test('scales a drag by the visible window, not the whole dive', () {
        // Half the plot width is half of the visible 1800 s window.
        expect(zoomed.secondsPerPixel * 149, closeTo(900, 0.001));
      });
    });

    group('degenerate geometry', () {
      test('a zero-width plot rect does not divide by zero', () {
        const flat = RangePlotAxis(
          plotLeft: 48,
          plotWidth: 0,
          visibleMinSeconds: 0,
          visibleMaxSeconds: 3600,
        );
        expect(flat.xForSeconds(1800), 48);
        expect(flat.secondsForX(48), 0);
      });

      test('an empty time window does not divide by zero', () {
        const frozen = RangePlotAxis(
          plotLeft: 48,
          plotWidth: 298,
          visibleMinSeconds: 100,
          visibleMaxSeconds: 100,
        );
        expect(frozen.xForSeconds(100), 48);
        expect(frozen.secondsPerPixel, 0);
      });
    });
  });
}
