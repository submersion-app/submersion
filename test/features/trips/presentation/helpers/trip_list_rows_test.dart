import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_list_rows.dart';

/// Side trips nest under their larger trip in the trip list (issue #3658).
void main() {
  Trip trip(String id, {String? parent, int startDay = 1}) => Trip(
    id: id,
    name: 'Trip $id',
    startDate: DateTime(2026, 3, startDay),
    endDate: DateTime(2026, 3, startDay + 2),
    parentTripId: parent,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Map<String, Trip> byId(List<Trip> trips) => {for (final t in trips) t.id: t};

  test('side trips follow their parent, earliest first', () {
    final p = trip('P');
    final s2 = trip('S2', parent: 'P', startDay: 9);
    final s1 = trip('S1', parent: 'P', startDay: 5);
    final q = trip('Q');
    final all = [s2, q, p, s1];
    final rows = nestTripRows([
      for (final t in all) TripWithStats(trip: t),
    ], byId(all));
    expect(rows.map((r) => (r.item.trip.id, r.isSideTrip)), [
      ('Q', false),
      ('P', false),
      ('S1', true),
      ('S2', true),
    ]);
    expect(rows.firstWhere((r) => r.item.trip.id == 'P').sideTripCount, 2);
    expect(rows.firstWhere((r) => r.item.trip.id == 'Q').sideTripCount, 0);
  });

  test('a side trip whose parent was filtered out stands alone, named', () {
    final p = trip('P');
    final s = trip('S', parent: 'P');
    final rows = nestTripRows([TripWithStats(trip: s)], byId([p, s]));
    expect(rows.single.isSideTrip, isFalse);
    expect(rows.single.partOfName, 'Trip P');
  });

  test('a link to an unknown or nested trip is ignored', () {
    final p = trip('P', parent: 'Q');
    final q = trip('Q');
    final s = trip('S', parent: 'P');
    final lost = trip('L', parent: 'gone');
    final all = [q, p, s, lost];
    final rows = nestTripRows([
      for (final t in all) TripWithStats(trip: t),
    ], byId(all));
    final s0 = rows.firstWhere((r) => r.item.trip.id == 'S');
    expect(s0.isSideTrip, isFalse);
    expect(s0.partOfName, isNull);
    expect(rows.firstWhere((r) => r.item.trip.id == 'L').partOfName, isNull);
    expect(rows.firstWhere((r) => r.item.trip.id == 'P').isSideTrip, isTrue);
  });

  test('groups start at each top-level row', () {
    final p = trip('P');
    final s = trip('S', parent: 'P');
    final q = trip('Q');
    final rows = nestTripRows([
      TripWithStats(trip: p),
      TripWithStats(trip: q),
      TripWithStats(trip: s),
    ], byId([p, s, q]));
    expect(
      tripRowGroups(rows).map((g) => g.map((r) => r.item.trip.id).toList()),
      [
        ['P', 'S'],
        ['Q'],
      ],
    );
  });
}
