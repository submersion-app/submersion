import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/sighting_time_bound.dart';

/// The latest time a sighting can be given (issue #5092).
void main() {
  final day = DateTime.utc(2026, 11, 27);
  final profile = [
    for (var t = 0; t <= 3000; t += 10)
      DiveProfilePoint(timestamp: t, depth: 5),
  ];

  test('the profile\'s last second wins', () {
    final dive = Dive(
      id: 'd',
      dateTime: day,
      runtime: const Duration(minutes: 90),
    );
    expect(sightingTimeMaxSeconds(dive, profile), 3000);
  });

  test('with no profile, the recorded runtime', () {
    final dive = Dive(
      id: 'd',
      dateTime: day,
      runtime: const Duration(minutes: 47),
      bottomTime: const Duration(minutes: 40),
    );
    expect(sightingTimeMaxSeconds(dive, const []), 47 * 60);
  });

  test('with no runtime either, the bottom time', () {
    final dive = Dive(
      id: 'd',
      dateTime: day,
      bottomTime: const Duration(minutes: 40),
    );
    expect(sightingTimeMaxSeconds(dive, const []), 40 * 60);
  });

  test('with nothing recorded, a day', () {
    expect(
      sightingTimeMaxSeconds(Dive(id: 'd', dateTime: day), const []),
      86400,
    );
  });
}
