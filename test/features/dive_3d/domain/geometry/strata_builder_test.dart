import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strata_builder.dart';

void main() {
  group('StrataBuilder.bin', () {
    test('averages temperatures per 2m depth band, skipping empty bands', () {
      final bands = StrataBuilder.bin(
        depths: [0.5, 1.0, 5.0, 5.5],
        temperatures: [20.0, 22.0, 10.0, 12.0],
      );
      expect(bands.length, 2);
      expect(bands[0].topMeters, 0);
      expect(bands[0].bottomMeters, 2);
      expect(bands[0].meanTempCelsius, closeTo(21.0, 1e-9));
      expect(bands[1].topMeters, 4);
      expect(bands[1].meanTempCelsius, closeTo(11.0, 1e-9));
    });

    test('samples without temperature are ignored', () {
      final bands = StrataBuilder.bin(
        depths: [1.0, 1.5],
        temperatures: [null, null],
      );
      expect(bands, isEmpty);
    });
  });

  group('StrataBuilder.build', () {
    test('emits one horizontal quad per band', () {
      const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 10);
      final bands = [
        const StrataBand(topMeters: 0, bottomMeters: 2, meanTempCelsius: 20),
        const StrataBand(topMeters: 4, bottomMeters: 6, meanTempCelsius: 11),
      ];
      final mesh = StrataBuilder.build(bands: bands, bounds: bounds)!;
      expect(mesh.vertexCount, 8); // 4 per quad
      expect(mesh.triangleCount, 4); // 2 per quad
      // First quad sits at the band's mid-depth: (0+2)/2 = 1m -> y=-0.6
      expect(mesh.positions[1], closeTo(-0.6, 1e-6));
      expect(mesh.opacity, lessThan(0.5));
    });

    test('returns null for empty bands', () {
      const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 10);
      expect(StrataBuilder.build(bands: const [], bounds: bounds), isNull);
    });
  });
}
