import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_for_dive_date.dart';

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

  // Dives keep their wall-clock time in UTC components.
  DateTime dive(int month, int day, [int hour = 10]) =>
      DateTime.utc(2026, month, day, hour);

  final bonaire = trip('bonaire', DateTime(2026, 3, 7), DateTime(2026, 3, 14));

  test('a dive on any day of the trip falls in it', () {
    expect(tripForDiveDate(dive(3, 7, 8), [bonaire]), bonaire);
    expect(tripForDiveDate(dive(3, 10), [bonaire]), bonaire);
  });

  test('a dive late on the last day falls in the trip', () {
    // The trip ends at local midnight of 14 March; the whole day counts.
    expect(tripForDiveDate(dive(3, 14, 22), [bonaire]), bonaire);
  });

  test('a dive outside the dates falls in no trip', () {
    expect(tripForDiveDate(dive(3, 6, 23), [bonaire]), isNull);
    expect(tripForDiveDate(dive(3, 15, 0), [bonaire]), isNull);
    expect(tripForDiveDate(dive(3, 10), const []), isNull);
  });

  test('the dive day is its wall-clock day, not the local one', () {
    // 23:30 wall clock on 14 March stays the 14th whatever the device zone.
    expect(
      tripForDiveDate(DateTime.utc(2026, 3, 14, 23, 30), [bonaire]),
      bonaire,
    );
    expect(tripForDiveDate(DateTime.utc(2026, 3, 6, 23, 30), [bonaire]), null);
  });

  test('a trip whose start carries a time of day still covers that day', () {
    final t = trip('t', DateTime(2026, 5, 1, 18), DateTime(2026, 5, 3, 9));
    expect(tripForDiveDate(dive(5, 1, 7), [t]), t);
    expect(tripForDiveDate(dive(5, 3, 20), [t]), t);
  });

  test('of overlapping trips the one that started last wins', () {
    final season = trip('season', DateTime(2026, 3, 1), DateTime(2026, 3, 31));
    final listed = [season, bonaire];
    expect(tripForDiveDate(dive(3, 10), listed), bonaire);
    expect(tripForDiveDate(dive(3, 10), listed.reversed), bonaire);
    expect(tripForDiveDate(dive(3, 20), listed), season);
  });
}
