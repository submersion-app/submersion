import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

void main() {
  test('tts colors run neutral to amber across the series range', () {
    final colors = MetricPalette.colorsFor(SceneMetric.tts, [0, 10, 20]);
    // First sample is the low end (gray-blue), last is amber: red channel rises.
    expect(colors[0], lessThan(colors[6]));
    expect(colors[6], greaterThan(0.9)); // amber red channel ~0.96
  });
}
