import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveCandidate', () {
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 3, 5),
      notes: '',
      tanks: const [],
      profile: const [],
      equipment: const [],
      photoIds: const [],
      sightings: const [],
      diveTypeIds: [''],
    );

    test('isUnassigned returns true when currentTripId is null', () {
      final candidate = DiveCandidate(dive: dive);
      expect(candidate.isUnassigned, isTrue);
    });

    test('isUnassigned returns false when currentTripId is set', () {
      final candidate = DiveCandidate(
        dive: dive,
        currentTripId: 'trip-99',
        currentTripName: 'Other Trip',
      );
      expect(candidate.isUnassigned, isFalse);
    });

    test('supports value equality via Equatable', () {
      final a = DiveCandidate(dive: dive);
      final b = DiveCandidate(dive: dive);
      expect(a, equals(b));
    });

    test('different currentTripId produces inequality', () {
      final a = DiveCandidate(dive: dive);
      final b = DiveCandidate(dive: dive, currentTripId: 'trip-99');
      expect(a, isNot(equals(b)));
    });
  });
}
