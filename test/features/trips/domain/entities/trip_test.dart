import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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
      final updated = baseTrip.copyWith(location: null, resortName: null);

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
      final cleared = tripWithLiveaboard.copyWith(liveaboardName: null);

      expect(cleared.liveaboardName, isNull);
    });

    test('copyWith can replace null with a value', () {
      final tripWithoutLiveaboard = baseTrip.copyWith(liveaboardName: null);

      expect(tripWithoutLiveaboard.liveaboardName, isNull);

      // Now set it
      final updated = tripWithoutLiveaboard.copyWith(
        liveaboardName: 'Sea Spirit',
      );

      expect(updated.liveaboardName, 'Sea Spirit');
    });
  });

  group('Trip tripType', () {
    test('defaults to shore when not specified', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(trip.tripType, TripType.shore);
    });

    test('isLiveaboard returns true for liveaboard type', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Red Sea Trip',
        tripType: TripType.liveaboard,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(trip.isLiveaboard, isTrue);
    });

    test(
      'isLiveaboard returns false for shore type even with liveaboardName set',
      () {
        final trip = Trip(
          id: 'trip-1',
          name: 'Test',
          tripType: TripType.shore,
          liveaboardName: 'Some Vessel',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        expect(trip.isLiveaboard, isFalse);
      },
    );

    test('copyWith preserves tripType', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        tripType: TripType.liveaboard,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final copy = trip.copyWith(name: 'Updated');
      expect(copy.tripType, TripType.liveaboard);
    });

    test('copyWith can change tripType', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Test',
        tripType: TripType.shore,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 7),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final updated = trip.copyWith(tripType: TripType.liveaboard);
      expect(updated.tripType, TripType.liveaboard);
    });
  });

  group('isShared', () {
    test('defaults to false', () {
      final trip = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(trip.isShared, isFalse);
    });

    test('copyWith sets isShared', () {
      final trip = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final shared = trip.copyWith(isShared: true);
      expect(shared.isShared, isTrue);
      expect(trip.isShared, isFalse);
    });

    test('props include isShared so equality distinguishes shared state', () {
      final base = Trip(
        id: 't1',
        name: 'Test',
        startDate: DateTime(2024),
        endDate: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(base == base.copyWith(isShared: true), isFalse);
    });
  });
}
