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
}
