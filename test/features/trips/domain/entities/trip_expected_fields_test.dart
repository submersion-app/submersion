import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// The two scrubber margin overrides on a trip (condition phase 4b).
void main() {
  final base = Trip(
    id: 't1',
    name: 'Red Sea',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 8),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    expectedDives: 12,
    expectedRuntimeMinutes: 70,
  );

  test('copyWith keeps the other field and can clear one', () {
    final more = base.copyWith(expectedDives: 14);
    expect(more.expectedDives, 14);
    expect(more.expectedRuntimeMinutes, 70);
    final cleared = base.copyWith(expectedRuntimeMinutes: null);
    expect(cleared.expectedRuntimeMinutes, isNull);
    expect(cleared.expectedDives, 12);
  });

  test('equality includes both fields', () {
    expect(base, base.copyWith());
    expect(base, isNot(base.copyWith(expectedDives: 1)));
    expect(base, isNot(base.copyWith(expectedRuntimeMinutes: 1)));
  });
}
