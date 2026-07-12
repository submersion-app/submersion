import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  group('SceneBounds', () {
    const bounds = SceneBounds(durationSeconds: 3600, maxDepthMeters: 40);

    test('maps time linearly onto xSpan', () {
      expect(bounds.xOf(0), 0);
      expect(bounds.xOf(1800), SceneBounds.xSpan / 2);
      expect(bounds.xOf(3600), SceneBounds.xSpan);
    });

    test('maps depth downward onto negative ySpan', () {
      expect(bounds.yOf(0), 0);
      expect(bounds.yOf(40), -SceneBounds.ySpan);
      expect(bounds.yOf(20), -SceneBounds.ySpan / 2);
    });

    test('degenerate dive does not divide by zero', () {
      const empty = SceneBounds(durationSeconds: 0, maxDepthMeters: 0);
      expect(empty.xOf(10), 0);
      expect(empty.yOf(10), 0);
    });
  });
}
