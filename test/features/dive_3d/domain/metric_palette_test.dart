import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

void main() {
  group('MetricPalette.colorsFor', () {
    test('emits one rgb triplet per value', () {
      final colors = MetricPalette.colorsFor(SceneMetric.temperature, [
        10,
        15,
        20,
      ]);
      expect(colors.length, 9);
    });

    test('null values map to neutral gray', () {
      final colors = MetricPalette.colorsFor(SceneMetric.temperature, [null]);
      expect(colors[0], closeTo(0.62, 0.01));
      expect(colors[1], closeTo(0.62, 0.01));
      expect(colors[2], closeTo(0.62, 0.01));
    });

    test('ascent rate uses discrete safety bands', () {
      final colors = MetricPalette.colorsFor(SceneMetric.ascentRate, [
        5.0,
        10.0,
        15.0,
      ]);
      // green (<=9), orange (9-12), red (>12) -- assert channels dominate
      expect(colors[1], greaterThan(colors[0])); // g > r for safe
      expect(colors[6], greaterThan(colors[7])); // r > g for dangerous
    });

    test('ppO2 uses fixed 0.2-1.6 domain (identical inputs, identical colors '
        'regardless of dive range)', () {
      final a = MetricPalette.colorsFor(SceneMetric.ppO2, [1.0, 1.2]);
      final b = MetricPalette.colorsFor(SceneMetric.ppO2, [1.0, 1.6]);
      expect(a.sublist(0, 3), b.sublist(0, 3));
    });

    test('flat series does not divide by zero', () {
      final colors = MetricPalette.colorsFor(SceneMetric.heartRate, [
        80,
        80,
        80,
      ]);
      expect(colors.length, 9);
      expect(colors.every((c) => c.isFinite), isTrue);
    });
  });

  // The underwater track scene colors every metric through this ramp.
  group('MetricPalette.rampColorsFor', () {
    const grey = 0x9E / 255;

    test('maps the min and max of a series to the ramp endpoints', () {
      final colors = MetricPalette.rampColorsFor([0.0, 5.0, 10.0]);
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
      final colors = MetricPalette.rampColorsFor([0.0, null, 10.0]);
      expect(colors[3], closeTo(grey, 0.01));
      expect(colors[4], closeTo(grey, 0.01));
      expect(colors[5], closeTo(grey, 0.01));
    });

    test('a constant series maps every value to the same color', () {
      final colors = MetricPalette.rampColorsFor([4.0, 4.0, 4.0]);
      for (var i = 0; i < 3; i++) {
        expect(colors.sublist(i * 3, i * 3 + 3), colors.sublist(0, 3));
      }
    });

    test('an all-null series does not throw and stays grey', () {
      final colors = MetricPalette.rampColorsFor([null, null]);
      expect(colors[0], closeTo(grey, 0.01));
      expect(colors[3], closeTo(grey, 0.01));
    });
  });
}
