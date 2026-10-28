import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';

/// A new trip prefilled from the selected dives (issue #3658).
void main() {
  SelectionDiveFacts dive(
    String id,
    DateTime at, {
    String? tripId,
    String? region,
    String? country,
    String? center,
  }) => SelectionDiveFacts(
    diveId: id,
    diveDateTime: at,
    tripId: tripId,
    siteRegion: region,
    siteCountry: country,
    diveCenterName: center,
  );

  Trip trip(String id, {String? parent}) => Trip(
    id: id,
    name: id,
    startDate: DateTime(2026, 3, 1),
    endDate: DateTime(2026, 3, 20),
    parentTripId: parent,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  String nameFor(String? location, DateTime start) =>
      '${location ?? 'Trip'} ${start.year}-${start.month}';

  TripDraft draft(
    List<SelectionDiveFacts> facts, {
    Map<String, Trip> trips = const {},
  }) => buildTripDraft(facts, tripsById: trips, nameFor: nameFor);

  test('dates are the wall-clock days of the first and last dive', () {
    final d = draft([
      dive('b', DateTime.utc(2026, 3, 31, 23, 30)),
      dive('a', DateTime.utc(2026, 3, 8, 0, 15)),
    ]);
    expect(d.trip.startDate, DateTime(2026, 3, 8));
    expect(d.trip.endDate, DateTime(2026, 3, 31));
    expect(d.diveIds, ['b', 'a']);
  });

  test('a shared region and country name the location', () {
    final d = draft([
      dive('a', DateTime.utc(2026, 3, 8), region: 'Raja Ampat', country: 'ID'),
      dive('b', DateTime.utc(2026, 3, 9), region: 'Raja Ampat', country: 'ID'),
      dive('c', DateTime.utc(2026, 3, 9)),
    ]);
    expect(d.trip.location, 'Raja Ampat, ID');
    expect(d.trip.name, 'Raja Ampat, ID 2026-3');
  });

  test('mixed regions in one country name the country', () {
    final d = draft([
      dive('a', DateTime.utc(2026, 3, 8), region: 'Raja Ampat', country: 'ID'),
      dive('b', DateTime.utc(2026, 3, 9), region: 'Bali', country: 'ID'),
    ]);
    expect(d.trip.location, 'ID');
  });

  test('a shared region with no country names the region', () {
    final d = draft([
      dive('a', DateTime.utc(2026, 3, 8), region: 'Red Sea'),
      dive('b', DateTime.utc(2026, 3, 9), region: 'Red Sea'),
    ]);
    expect(d.trip.location, 'Red Sea');
  });

  test('dives with no site leave the location empty', () {
    final d = draft([dive('a', DateTime.utc(2026, 3, 8))]);
    expect(d.trip.location, isNull);
    expect(d.trip.name, 'Trip 2026-3');
  });

  test('a shared dive center becomes the resort name', () {
    final d = draft([
      dive('a', DateTime.utc(2026, 3, 8), center: 'Kri Eco'),
      dive('b', DateTime.utc(2026, 3, 9), center: 'Kri Eco'),
    ]);
    expect(d.trip.resortName, 'Kri Eco');
    final mixed = draft([
      dive('a', DateTime.utc(2026, 3, 8), center: 'Kri Eco'),
      dive('b', DateTime.utc(2026, 3, 9), center: 'Other'),
    ]);
    expect(mixed.trip.resortName, isNull);
  });

  test('dives all on one trip make the new trip its side trip', () {
    final trips = {'P': trip('P'), 'S': trip('S', parent: 'P')};
    final onP = draft([
      dive('a', DateTime.utc(2026, 3, 8), tripId: 'P'),
      dive('b', DateTime.utc(2026, 3, 9), tripId: 'P'),
    ], trips: trips);
    expect(onP.trip.parentTripId, 'P');
    final onS = draft([
      dive('a', DateTime.utc(2026, 3, 8), tripId: 'S'),
    ], trips: trips);
    expect(onS.trip.parentTripId, 'P');
  });

  test('dives on several trips, or none, make a trip of its own', () {
    final trips = {'P': trip('P'), 'Q': trip('Q')};
    expect(
      draft([
        dive('a', DateTime.utc(2026, 3, 8), tripId: 'P'),
        dive('b', DateTime.utc(2026, 3, 9), tripId: 'Q'),
      ], trips: trips).trip.parentTripId,
      isNull,
    );
    expect(
      draft([
        dive('a', DateTime.utc(2026, 3, 8), tripId: 'P'),
        dive('b', DateTime.utc(2026, 3, 9)),
      ], trips: trips).trip.parentTripId,
      isNull,
    );
  });

  test('a side trip whose larger trip is gone is never offered as one', () {
    // C keeps a link to a trip deleted elsewhere: readers treat it as a trip
    // of its own, but a new trip pointing at it would be two levels deep.
    final trips = {'C': trip('C', parent: 'gone')};
    final d = draft([
      dive('a', DateTime.utc(2026, 3, 8), tripId: 'C'),
    ], trips: trips);
    expect(d.trip.parentTripId, isNull);
  });

  test('a draft needs at least one dive', () {
    expect(() => draft(const []), throwsArgumentError);
  });
}
