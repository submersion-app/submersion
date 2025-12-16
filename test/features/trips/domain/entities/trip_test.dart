import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  group('Trip copyWith', () {
    late Trip baseTrip;

    setUp(() {
      baseTrip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        location: 'Maldives',
        resortName: 'Paradise Resort',
        liveaboardName: null,
        notes: 'Great diving',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    test('copyWith preserves values when not provided', () {
      final updated = baseTrip.copyWith();

      expect(updated.id, baseTrip.id);
      expect(updated.name, baseTrip.name);
      expect(updated.location, baseTrip.location);
      expect(updated.resortName, baseTrip.resortName);
      expect(updated.liveaboardName, baseTrip.liveaboardName);
    });

    test('copyWith updates provided values', () {
      final updated = baseTrip.copyWith(
        name: 'Updated Trip',
        location: 'Thailand',
      );

      expect(updated.name, 'Updated Trip');
      expect(updated.location, 'Thailand');
      expect(updated.resortName, baseTrip.resortName); // unchanged
    });

    test('copyWith can set nullable fields to null', () {
      // This is the key test - can we clear optional fields?
      final updated = baseTrip.copyWith(
        location: null,
        resortName: null,
      );

      expect(updated.location, isNull);
      expect(updated.resortName, isNull);
      expect(updated.name, baseTrip.name); // unchanged
    });

    test('copyWith can set liveaboardName to null', () {
      final tripWithLiveaboard = baseTrip.copyWith(
        liveaboardName: 'Ocean Explorer',
      );
      
      expect(tripWithLiveaboard.liveaboardName, 'Ocean Explorer');
      
      // Now clear it
      final cleared = tripWithLiveaboard.copyWith(
        liveaboardName: null,
      );
      
      expect(cleared.liveaboardName, isNull);
    });

    test('copyWith can replace null with a value', () {
      final tripWithoutLiveaboard = baseTrip.copyWith(
        liveaboardName: null,
      );
      
      expect(tripWithoutLiveaboard.liveaboardName, isNull);
      
      // Now set it
      final updated = tripWithoutLiveaboard.copyWith(
        liveaboardName: 'Sea Spirit',
      );
      
      expect(updated.liveaboardName, 'Sea Spirit');
    });
  });
}
