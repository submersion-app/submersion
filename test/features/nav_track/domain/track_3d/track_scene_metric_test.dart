import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';

void main() {
  group('TrackMetricPalette.colorsFor', () {
    test('maps the min and max of a series to the ramp endpoints', () {
      final colors = TrackMetricPalette.colorsFor([0.0, 5.0, 10.0]);
      expect(colors.length, 9);
      // First stop of the ramp: #0077B6.
      expect(colors[0], closeTo(0 / 255, 0.01));
      expect(colors[1], closeTo(0x77 / 255, 0.01));
      expect(colors[2], closeTo(0xB6 / 255, 0.01));
      // Last stop of the ramp: #EF4444.
      expect(colors[6], closeTo(0xEF / 255, 0.01));
      expect(colors[7], closeTo(0x44 / 255, 0.01));
      expect(colors[8], closeTo(0x44 / 255, 0.01));
    });

    test('a null entry gets the grey fallback, not a ramp color', () {
      final colors = TrackMetricPalette.colorsFor([0.0, null, 10.0]);
      const grey = 0x9E / 255;
      expect(colors[3], closeTo(grey, 0.01));
      expect(colors[4], closeTo(grey, 0.01));
      expect(colors[5], closeTo(grey, 0.01));
    });

    test('a constant series maps every value to the ramp midpoint', () {
      final colors = TrackMetricPalette.colorsFor([4.0, 4.0, 4.0]);
      for (var i = 0; i < 3; i++) {
        expect(colors.sublist(i * 3, i * 3 + 3), colors.sublist(0, 3));
      }
    });

    test('an all-null series does not throw and stays grey', () {
      final colors = TrackMetricPalette.colorsFor([null, null]);
      const grey = 0x9E / 255;
      expect(colors[0], closeTo(grey, 0.01));
      expect(colors[3], closeTo(grey, 0.01));
    });
  });
}
