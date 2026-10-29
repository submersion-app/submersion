import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/side_trips.dart';

/// The side-trip rule in Dart (issue #3658), matching side_trip_sql.dart.
void main() {
  Trip trip(String id, {String? parent}) => Trip(
    id: id,
    name: id,
    startDate: DateTime(2026, 3, 2),
    endDate: DateTime(2026, 3, 16),
    parentTripId: parent,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final byId = {
    for (final t in [
      trip('A'),
      trip('B', parent: 'A'),
      trip('C', parent: 'B'),
      trip('D', parent: 'D'),
      trip('E', parent: 'gone'),
    ])
      t.id: t,
  };

  test('effectiveParentId honours only a valid link', () {
    expect(effectiveParentId(byId['A']!, byId), isNull);
    expect(effectiveParentId(byId['B']!, byId), 'A');
    expect(effectiveParentId(byId['C']!, byId), isNull);
    expect(effectiveParentId(byId['D']!, byId), isNull);
    expect(effectiveParentId(byId['E']!, byId), isNull);
  });

  test('canChooseAsParent refuses the trip itself and side trips', () {
    expect(canChooseAsParent(byId['A']!, forTripId: 'X'), isTrue);
    expect(canChooseAsParent(byId['A']!, forTripId: 'A'), isFalse);
    expect(canChooseAsParent(byId['B']!, forTripId: 'X'), isFalse);
    expect(canChooseAsParent(byId['A']!, forTripId: null), isTrue);
  });
}
