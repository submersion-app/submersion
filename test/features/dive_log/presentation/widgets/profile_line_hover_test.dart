import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_line_hover.dart';

void main() {
  group('nearestHoveredBarIndex', () {
    // A simple, linear data-Y -> pixel-Y mapping: pixelY == -dataY (as if
    // the chart's depth axis ran from 0 at the top to a large negative
    // number at the bottom, one pixel per data unit).
    double identityPixelY(double dataY) => -dataY;

    test('returns null when there are no candidate spots', () {
      final result = nearestHoveredBarIndex(
        spots: const [],
        cursorPixelY: 50,
        toPixelY: identityPixelY,
      );

      expect(result, isNull);
    });

    test('picks the single candidate when there is only one', () {
      final result = nearestHoveredBarIndex(
        spots: const [(barIndex: 3, dataY: -20)],
        cursorPixelY: 25,
        toPixelY: identityPixelY,
      );

      expect(result, 3);
    });

    test('picks the candidate whose pixel-Y is closest to the cursor', () {
      // pixelY for each: barIndex 0 -> 10, barIndex 1 -> 40, barIndex 2 -> 90.
      final result = nearestHoveredBarIndex(
        spots: const [
          (barIndex: 0, dataY: -10),
          (barIndex: 1, dataY: -40),
          (barIndex: 2, dataY: -90),
        ],
        cursorPixelY: 35,
        toPixelY: identityPixelY,
      );

      expect(result, 1);
    });

    test('breaks an exact tie in favour of the first candidate seen', () {
      final result = nearestHoveredBarIndex(
        spots: const [(barIndex: 5, dataY: -10), (barIndex: 6, dataY: -30)],
        cursorPixelY: 20, // equidistant from 10 and 30
        toPixelY: identityPixelY,
      );

      expect(result, 5);
    });

    test('uses the supplied conversion, not the raw dataY', () {
      // A non-trivial mapping (e.g. a metric squeezed into a band via
      // MetricBand): pixelY is data-Y scaled and offset, not identical to
      // dataY itself. The nearest candidate must be picked in pixel space.
      double scaledPixelY(double dataY) => dataY * 2 + 100;

      final result = nearestHoveredBarIndex(
        spots: const [
          (barIndex: 0, dataY: -10), // pixelY = 80
          (barIndex: 1, dataY: -40), // pixelY = 20
        ],
        cursorPixelY: 25,
        toPixelY: scaledPixelY,
      );

      expect(result, 1);
    });
  });
}
