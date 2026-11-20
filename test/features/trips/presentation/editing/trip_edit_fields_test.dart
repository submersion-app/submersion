import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The trip page's values and the rules its form keeps (issue #4527,
/// phase 3).
void main() {
  final trip = Trip(
    id: 't1',
    diverId: 'me',
    name: 'Red Sea',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 8),
    location: 'Hurghada',
    tripType: TripType.liveaboard,
    notes: 'Calm',
    expectedDives: 18,
    diversSharingCylinders: 2,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  TripDates dates(DateTime start, DateTime end) => (start: start, end: end);

  group('dates', () {
    test('a start after the end pulls the end', () {
      final picked = tripStartPicked(
        DateTime(2026, 6, 10),
        end: DateTime(2026, 6, 8),
        type: TripType.shore,
      );
      expect(picked, dates(DateTime(2026, 6, 10), DateTime(2026, 6, 10)));
    });

    test('a start before the end leaves the end', () {
      final picked = tripStartPicked(
        DateTime(2026, 5, 30),
        end: DateTime(2026, 6, 8),
        type: TripType.shore,
      );
      expect(picked, dates(DateTime(2026, 5, 30), DateTime(2026, 6, 8)));
    });

    test('a Day trip keeps its end on a moved start', () {
      final picked = tripStartPicked(
        DateTime(2026, 5, 30),
        end: DateTime(2026, 6, 8),
        type: TripType.dayTrip,
      );
      expect(picked, dates(DateTime(2026, 5, 30), DateTime(2026, 5, 30)));
    });

    test('choosing Day trip collapses the dates', () {
      expect(
        tripTypePicked(
          TripType.dayTrip,
          dates(DateTime(2026, 6, 1), DateTime(2026, 6, 8)),
        ),
        dates(DateTime(2026, 6, 1), DateTime(2026, 6, 1)),
      );
    });

    test('leaving Day trip keeps the dates', () {
      final one = dates(DateTime(2026, 6, 1), DateTime(2026, 6, 1));
      expect(tripTypePicked(TripType.resort, one), one);
    });

    test('a one-day Day trip locks its end', () {
      expect(
        tripEndLocked(
          TripType.dayTrip,
          dates(DateTime(2026, 6, 1, 9), DateTime(2026, 6, 1, 17)),
        ),
        isTrue,
      );
      expect(
        tripEndLocked(
          TripType.shore,
          dates(DateTime(2026, 6, 1), DateTime(2026, 6, 1)),
        ),
        isFalse,
      );
    });

    test('a stored multi-day Day trip keeps its end editable', () {
      expect(
        tripEndLocked(
          TripType.dayTrip,
          dates(DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
        ),
        isFalse,
      );
    });

    test('a start and its pulled end are one change of the header', () {
      final session = EditSession(trip)
        ..set(
          tripDatesField,
          tripStartPicked(
            DateTime(2026, 6, 10),
            end: trip.endDate,
            type: trip.tripType,
          ),
        );
      expect(session.working.startDate, DateTime(2026, 6, 10));
      expect(session.working.endDate, DateTime(2026, 6, 10));
      expect(session.changedCardIds, {'header'});
    });
  });

  test('the return flight is wall clock as UTC', () {
    final at = tripReturnFlightAt(
      DateTime(2026, 6, 9),
      const TimeOfDay(hour: 14, minute: 30),
    );
    expect(at, DateTime.utc(2026, 6, 9, 14, 30));
  });

  group('numbers', () {
    test('zero and below store null', () {
      expect(tripPositiveOrNull(0), isNull);
      expect(tripPositiveOrNull(-3), isNull);
      expect(tripPositiveOrNull(null), isNull);
      expect(tripPositiveOrNull(4), 4);
      final session = EditSession(trip)..set(tripExpectedDivesField, 0.0);
      expect(session.working.expectedDives, isNull);
    });

    test('divers sharing blank or zero stores one', () {
      final blank = EditSession(trip)..set(tripDiversSharingField, null);
      expect(blank.working.diversSharingCylinders, 1);
      final zero = EditSession(trip)..set(tripDiversSharingField, 0.0);
      expect(zero.working.diversSharingCylinders, 1);
      final three = EditSession(trip)..set(tripDiversSharingField, 3.0);
      expect(three.working.diversSharingCylinders, 3);
    });

    test('plan values are changes of the plan card', () {
      final session = EditSession(trip)
        ..set(tripDivesPerDayField, 3.0)
        ..set(tripExpectedRuntimeField, 55.0);
      expect(session.working.divesPerDayTarget, 3);
      expect(session.working.expectedRuntimeMinutes, 55);
      expect(session.changedCardIds, {'plan'});
    });
  });

  group('text', () {
    test('a blank name is invalid', () {
      expect(tripNameValid('  '), isFalse);
      expect(tripNameValid(' Red Sea '), isTrue);
    });

    test('a blank location stores null, and trims', () {
      final session = EditSession(trip)..set(tripLocationField, '   ');
      expect(session.working.location, isNull);
      final trimmed = EditSession(trip)..set(tripResortField, ' Oasis ');
      expect(trimmed.working.resortName, 'Oasis');
    });

    test('the name is trimmed, and spaces alone are no change', () {
      final session = EditSession(trip)..set(tripNameField, 'Red Sea  ');
      expect(session.isDirty, isFalse);
    });
  });

  test('each header value is a change of the header card', () {
    final session = EditSession(trip)
      ..set(tripTypeField, TripType.resort)
      ..set(tripParentField, 'p1')
      ..set(tripLiveaboardNameField, 'MV Old')
      ..set(tripReturnFlightField, DateTime.utc(2026, 6, 9, 12));
    expect(session.working.tripType, TripType.resort);
    expect(session.working.parentTripId, 'p1');
    expect(session.working.liveaboardName, 'MV Old');
    expect(session.working.returnFlightAt, DateTime.utc(2026, 6, 9, 12));
    expect(session.changedCardIds, {'header'});
  });

  test('notes are a change of the notes card', () {
    final session = EditSession(trip)..set(tripNotesField, 'Windy');
    expect(session.working.notes, 'Windy');
    expect(session.changedCardIds, {'notes'});
  });
}
