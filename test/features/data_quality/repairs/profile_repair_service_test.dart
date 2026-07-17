import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

domain.DiveProfilePoint p(int t, double depth, {double? temp}) =>
    domain.DiveProfilePoint(timestamp: t, depth: depth, temperature: temp);

void main() {
  group('despike', () {
    test('replaces the single-sample spike with neighbor interpolation', () {
      // 20 -> 55 -> 20 at 10 s: 3.5 m/s both ways, opposite signs.
      final points = [p(0, 20), p(10, 20), p(20, 55), p(30, 20), p(40, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[2].depth, 20); // midpoint of neighbors 20 and 20
      expect(out.length, points.length);
      expect(points[2].depth, 55); // input untouched
    });

    test('leaves genuine fast-but-possible movement alone', () {
      // 2.5 m/s is below the 3.0 threshold.
      final points = [p(0, 20), p(10, 45), p(20, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[1].depth, 45);
    });
  });

  group('fillGaps', () {
    test('interpolates a 120 s hole at the median interval', () {
      // Median 10 s; hole 100->220 gets 11 synthetic samples at 110..210.
      final points = [
        for (var t = 0; t <= 100; t += 10) p(t, 20),
        for (var t = 220; t <= 300; t += 10) p(t, 30),
      ];
      final out = ProfileRepairService.fillGaps(points);
      final inserted = out.where((q) => q.timestamp > 100 && q.timestamp < 220);
      expect(inserted, hasLength(11));
      // Linear: at t=160 (halfway), depth = (20+30)/2 = 25.
      expect(
        inserted.firstWhere((q) => q.timestamp == 160).depth,
        closeTo(25.0, 1e-9),
      );
    });

    test('holes longer than gapFillMaxSeconds are left alone', () {
      final points = [p(0, 20), p(400, 20), p(410, 20)];
      final out = ProfileRepairService.fillGaps(points);
      expect(out.length, points.length);
    });
  });

  group('smoothTemperature', () {
    test('clamps a single-sample 8 C jump, depth untouched', () {
      final points = [
        p(0, 20, temp: 20),
        p(10, 20, temp: 12), // 8 C jump down and back
        p(20, 20, temp: 20),
      ];
      final out = ProfileRepairService.smoothTemperature(points);
      expect(out[1].temperature, closeTo(20.0, 1e-9));
      expect(out[1].depth, 20);
    });
  });

  group('convertTemperature', () {
    test('kelvin scale: 295.15 -> 22 C', () {
      final out = ProfileRepairService.convertTemperature([
        p(0, 20, temp: 295.15),
      ], kelvinScale: true);
      expect(out.single.temperature, closeTo(22.0, 1e-9));
    });

    test('fahrenheit scale: 72 F -> 22.2 C', () {
      final out = ProfileRepairService.convertTemperature([
        p(0, 20, temp: 72),
      ], kelvinScale: false);
      expect(out.single.temperature, closeTo((72 - 32) * 5 / 9, 1e-9));
    });
  });
}
