import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/trackpad_zoom.dart';

void main() {
  group('trackpadScrollZoomDelta', () {
    test('zero scroll yields zero delta', () {
      expect(trackpadScrollZoomDelta(0), 0);
    });

    test('scroll up (negative dy) zooms out (negative delta)', () {
      expect(trackpadScrollZoomDelta(-100), lessThan(0));
    });

    test('scroll down (positive dy) zooms in (positive delta)', () {
      expect(trackpadScrollZoomDelta(100), greaterThan(0));
    });

    test('is symmetric for equal-and-opposite scrolls', () {
      expect(trackpadScrollZoomDelta(-50), -trackpadScrollZoomDelta(50));
    });

    test('scales with sensitivity', () {
      expect(
        trackpadScrollZoomDelta(-100, sensitivity: 0.02),
        2 * trackpadScrollZoomDelta(-100, sensitivity: 0.01),
      );
    });

    test('default sensitivity maps a ~100px flick to ~1 zoom level', () {
      expect(trackpadScrollZoomDelta(100), closeTo(1.0, 0.0001));
    });
  });
}
