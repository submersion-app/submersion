import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_density.dart';

void main() {
  group('densityIntensity', () {
    test('returns 0 when maxWeight <= 0', () {
      expect(densityIntensity(5, 0), 0.0);
      expect(densityIntensity(5, -1), 0.0);
    });

    test('returns the floor for the lowest weight', () {
      expect(densityIntensity(0, 10), closeTo(0.35, 1e-9));
    });

    test('returns 1.0 when weight equals maxWeight', () {
      expect(densityIntensity(10, 10), closeTo(1.0, 1e-9));
    });

    test('is monotonic increasing in weight', () {
      final a = densityIntensity(1, 10);
      final b = densityIntensity(5, 10);
      final c = densityIntensity(9, 10);
      expect(a, lessThan(b));
      expect(b, lessThan(c));
    });

    test('sqrt curve lifts small weights (normalized 0.25 -> 0.675)', () {
      expect(densityIntensity(2.5, 10), closeTo(0.35 + 0.65 * 0.5, 1e-9));
    });

    test('respects custom floor and gamma', () {
      expect(densityIntensity(0, 10, floor: 0.5), closeTo(0.5, 1e-9));
      expect(
        densityIntensity(5, 10, floor: 0.0, gamma: 1.0),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('densityBlobGradient', () {
    test('center alpha equals intensity, edge is transparent', () {
      final g = densityBlobGradient(0.6);
      expect(g.colors.first.a, closeTo(0.6, 1e-6));
      expect(g.colors.last.a, closeTo(0.0, 1e-6));
    });

    test('stops run 0..1 and match colors length', () {
      final g = densityBlobGradient(0.5);
      expect(g.stops.first, 0.0);
      expect(g.stops.last, 1.0);
      expect(g.stops.length, g.colors.length);
    });

    test('clamps intensity into range', () {
      expect(densityBlobGradient(2.0).colors.first.a, closeTo(1.0, 1e-6));
      expect(densityBlobGradient(-1.0).colors.first.a, closeTo(0.0, 1e-6));
    });
  });

  group('isPointVisible', () {
    const size = Size(200, 100);

    test('inside is visible', () {
      expect(isPointVisible(const Offset(100, 50), size, 60), isTrue);
    });

    test('far off-screen beyond radius is culled', () {
      expect(isPointVisible(const Offset(-100, 50), size, 60), isFalse);
      expect(isPointVisible(const Offset(400, 50), size, 60), isFalse);
    });

    test('just off-screen within radius padding is visible', () {
      expect(isPointVisible(const Offset(-30, 50), size, 60), isTrue);
      expect(isPointVisible(const Offset(230, 50), size, 60), isTrue);
    });
  });
}
