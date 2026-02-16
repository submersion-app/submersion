import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  late ProfileEditingService service;

  setUp(() {
    service = ProfileEditingService();
  });

  group('detectOutliers', () {
    test('returns empty for clean profile', () {
      // Smooth descent: 0m, 3m, 6m, 9m, 12m, 15m, 18m (steady 1m/s)
      final profile = List.generate(
        7,
        (i) => DiveProfilePoint(timestamp: i * 3, depth: i * 3.0),
      );
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('detects sudden depth spike', () {
      // Smooth descent with one 20m spike at index 3
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 3.0),
        const DiveProfilePoint(timestamp: 8, depth: 6.0),
        const DiveProfilePoint(timestamp: 12, depth: 25.0), // spike!
        const DiveProfilePoint(timestamp: 16, depth: 9.0),
        const DiveProfilePoint(timestamp: 20, depth: 12.0),
        const DiveProfilePoint(timestamp: 24, depth: 15.0),
        const DiveProfilePoint(timestamp: 28, depth: 18.0),
        const DiveProfilePoint(timestamp: 32, depth: 18.0),
        const DiveProfilePoint(timestamp: 36, depth: 18.0),
        const DiveProfilePoint(timestamp: 40, depth: 18.0),
        const DiveProfilePoint(timestamp: 44, depth: 18.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers, isNotEmpty);
      expect(outliers.any((o) => o.index == 3), isTrue);
    });

    test('does not flag normal fast descent', () {
      // Fast but consistent descent: ~2m per sample
      final profile = List.generate(
        16,
        (i) => DiveProfilePoint(timestamp: i * 2, depth: i * 2.0),
      );
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('flags physical impossibility (>3m/s)', () {
      // Normal profile with one physically impossible jump
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 1, depth: 10.0),
        const DiveProfilePoint(timestamp: 2, depth: 10.0),
        const DiveProfilePoint(timestamp: 3, depth: 10.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 5, depth: 10.0),
        const DiveProfilePoint(timestamp: 6, depth: 10.0),
        const DiveProfilePoint(timestamp: 7, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 10.0),
        const DiveProfilePoint(timestamp: 9, depth: 10.0),
        const DiveProfilePoint(timestamp: 10, depth: 10.0),
        const DiveProfilePoint(timestamp: 11, depth: 15.0), // 5m in 1s = 5m/s
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers.any((o) => o.isPhysicallyImpossible), isTrue);
    });

    test('returns empty for profile with fewer than 3 points', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('returns empty for empty profile', () {
      final outliers = service.detectOutliers([]);
      expect(outliers, isEmpty);
    });
  });
}
