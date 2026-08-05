import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

void main() {
  group('DisplayZoom constants', () {
    test('range and step describe 14 slider divisions', () {
      expect(DisplayZoom.min, 0.70);
      expect(DisplayZoom.max, 1.40);
      expect(DisplayZoom.step, 0.05);
      expect(DisplayZoom.defaultValue, 1.0);
      expect(
        ((DisplayZoom.max - DisplayZoom.min) / DisplayZoom.step).round(),
        DisplayZoom.divisions,
      );
    });
  });

  group('DisplayZoom.normalize', () {
    test('returns supported levels unchanged', () {
      expect(DisplayZoom.normalize(0.85), 0.85);
      expect(DisplayZoom.normalize(DisplayZoom.min), DisplayZoom.min);
      expect(DisplayZoom.normalize(DisplayZoom.max), DisplayZoom.max);
      expect(
        DisplayZoom.normalize(DisplayZoom.defaultValue),
        DisplayZoom.defaultValue,
      );
    });

    test('clamps values below the minimum', () {
      expect(DisplayZoom.normalize(0.0), DisplayZoom.min);
      expect(DisplayZoom.normalize(-1.0), DisplayZoom.min);
    });

    test('clamps values above the maximum', () {
      expect(DisplayZoom.normalize(9.9), DisplayZoom.max);
    });

    test('falls back to the default for non-finite values', () {
      expect(DisplayZoom.normalize(double.nan), DisplayZoom.defaultValue);
      expect(DisplayZoom.normalize(double.infinity), DisplayZoom.defaultValue);
      expect(
        DisplayZoom.normalize(double.negativeInfinity),
        DisplayZoom.defaultValue,
      );
    });

    test('snaps a float-drifted value back onto the ladder exactly', () {
      // Reachable by stepping down past the 0.70 floor and back up: repeated
      // 0.05 arithmetic lands here. It displays as "100%", so it must also
      // compare equal to defaultValue, or the Reset button stays visible and
      // DisplayZoomScope builds a transform layer at nominal 100%.
      const drifted = 1.0000000000000002;
      expect(drifted == DisplayZoom.defaultValue, isFalse);
      expect(DisplayZoom.normalize(drifted), DisplayZoom.defaultValue);
    });

    test('snaps off-ladder values to the nearest supported level', () {
      expect(DisplayZoom.normalize(0.87), 0.85);
      expect(DisplayZoom.normalize(0.88), 0.90);
      expect(DisplayZoom.normalize(1.02), 1.0);
      expect(DisplayZoom.normalize(1.33), 1.35);
    });

    test('every result is an exact whole percent on the 5% ladder', () {
      // The displayed percentage and the stored value must never disagree.
      for (var i = 0; i <= 200; i++) {
        final value = DisplayZoom.normalize(0.5 + i * 0.005);
        final percent = (value * 100).round();
        expect(
          value,
          percent / 100,
          reason: 'normalize must land on an exact whole-percent double',
        );
        expect(percent % 5, 0, reason: '$value is not on the 5% ladder');
      }
    });
  });
}
