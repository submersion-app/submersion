import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

void main() {
  final profile = [
    const DiveProfilePoint(timestamp: 0, depth: 0),
    const DiveProfilePoint(timestamp: 10, depth: 5),
    const DiveProfilePoint(timestamp: 20, depth: 10),
    const DiveProfilePoint(timestamp: 40, depth: 12),
  ];

  group('indexForTimestamp', () {
    test('exact match', () => expect(indexForTimestamp(profile, 20), 2));
    test(
      'between samples returns earlier sample',
      () => expect(indexForTimestamp(profile, 25), 2),
    );
    test(
      'before start clamps to 0',
      () => expect(indexForTimestamp(profile, -5), 0),
    );
    test(
      'after end clamps to last',
      () => expect(indexForTimestamp(profile, 999), 3),
    );
    test(
      'empty profile returns null',
      () => expect(indexForTimestamp(const [], 10), isNull),
    );
  });

  group('pressureAtTimestamp', () {
    final points = [
      const TankPressurePoint(
        id: '1',
        tankId: 'tank1',
        timestamp: 0,
        pressure: 200,
      ),
      const TankPressurePoint(
        id: '2',
        tankId: 'tank1',
        timestamp: 60,
        pressure: 180,
      ),
      const TankPressurePoint(
        id: '3',
        tankId: 'tank1',
        timestamp: 120,
        pressure: 160,
      ),
    ];
    test('exact match', () => expect(pressureAtTimestamp(points, 60), 180));
    test(
      'between points returns earlier value',
      () => expect(pressureAtTimestamp(points, 90), 180),
    );
    test(
      'after last returns last',
      () => expect(pressureAtTimestamp(points, 999), 160),
    );
    test(
      'empty returns null',
      () => expect(pressureAtTimestamp(const [], 10), isNull),
    );
  });
}
