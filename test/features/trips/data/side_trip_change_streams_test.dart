import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../helpers/test_database.dart';

/// Views whose queries take in a larger trip's side trips refresh when a
/// side trip is linked or unlinked, a write to the trips table alone (issue
/// #3658).
void main() {
  late TripRepository trips;
  late Trip parent;
  late Trip side;

  Trip trip(String name) => Trip(
    id: '',
    name: name,
    startDate: DateTime(2026, 3, 2),
    endDate: DateTime(2026, 3, 16),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    trips = TripRepository();
    parent = await trips.createTrip(trip('Indonesia'));
    side = await trips.createTrip(trip('Raja Ampat'));
  });
  tearDown(tearDownTestDatabase);

  Future<void> link() =>
      trips.updateTrip(side.copyWith(parentTripId: parent.id));

  test('the cylinder board and gas record tick on a side-trip link', () async {
    final cylinders = TripCylinderRepository();
    final board = cylinders.watchTripCylinderChanges().first;
    final record = cylinders.watchGasRecordChanges().first;
    await link();
    await expectLater(board, completes);
    await expectLater(record, completes);
  });

  test('the media library ticks on a side-trip link', () async {
    final ticks = <void>[];
    final sub = MediaLibraryRepository().watchLibraryChanges().listen(
      ticks.add,
    );
    addTearDown(sub.cancel);
    await link();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(ticks, isNotEmpty);
  });
}
