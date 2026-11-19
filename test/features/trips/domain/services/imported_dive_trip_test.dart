import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/imported_dive_trip.dart';

void main() {
  final created = DateTime(2026, 1, 1);

  Trip trip(String id, DateTime start, DateTime end) => Trip(
    id: id,
    name: id,
    startDate: start,
    endDate: end,
    createdAt: created,
    updatedAt: created,
  );

  final bonaire = trip('bonaire', DateTime(2026, 3, 7), DateTime(2026, 3, 14));
  final fileTrip = trip('file', DateTime(2026, 5, 1), DateTime(2026, 5, 3));
  final onTrip = DateTime.utc(2026, 3, 10, 9);

  group('placesImportedDiveByDate', () {
    test('only a dated dive with no trip of its own may be placed', () {
      // hasOwnTrip, hasTripRef, sourceHasTrips, isDated -> placed
      final cases = <(bool, bool, bool, bool, bool)>[
        (false, false, false, true, true),
        (false, true, false, true, true),
        (false, true, true, true, true),
        (false, false, true, true, false),
        (true, false, false, true, false),
        (true, true, true, true, false),
        (false, false, false, false, false),
        (false, true, true, false, false),
      ];
      for (final (own, ref, sourceTrips, dated, expected) in cases) {
        expect(
          placesImportedDiveByDate(
            hasOwnTrip: own,
            hasTripRef: ref,
            sourceHasTrips: sourceTrips,
            isDated: dated,
          ),
          expected,
          reason: 'own=$own ref=$ref sourceHasTrips=$sourceTrips dated=$dated',
        );
      }
    });
  });

  group('tripForImportedDive', () {
    test('ownTripWins', () {
      expect(
        tripForImportedDive(
          ownTrip: fileTrip,
          hasTripRef: true,
          sourceHasTrips: true,
          diveDateTime: onTrip,
          trips: [bonaire],
        ),
        fileTrip,
      );
    });

    test('noFileTripsPlacesByDate', () {
      expect(
        tripForImportedDive(diveDateTime: onTrip, trips: [bonaire]),
        bonaire,
      );
    });

    test('fileWithTripsLeavesUnreferencedDiveOut', () {
      expect(
        tripForImportedDive(
          sourceHasTrips: true,
          diveDateTime: onTrip,
          trips: [bonaire],
        ),
        isNull,
      );
    });

    test('unimportedOwnTripPlacesByDate', () {
      expect(
        tripForImportedDive(
          hasTripRef: true,
          sourceHasTrips: true,
          diveDateTime: onTrip,
          trips: [bonaire],
        ),
        bonaire,
      );
    });

    test('undatedDiveIsNeverPlaced', () {
      expect(tripForImportedDive(diveDateTime: null, trips: [bonaire]), isNull);
    });
  });
}
