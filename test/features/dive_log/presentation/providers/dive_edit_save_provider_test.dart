import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveCenter, Trip;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Trips whose dates cannot be moved, so a test can tell this repository
/// was the one the service was given.
class _RefusingTrips extends TripRepository {
  @override
  Future<List<TripDateStretch>> stretchToCoverDives(
    List<String> diveIds,
  ) async => throw StateError('the provider passed this repository');
}

/// The provider that builds the service an editing sitting is saved with
/// (issue #4527).
void main() {
  late AppDatabase db;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
  });
  tearDown(tearDownTestDatabase);

  test('builds a save service', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(diveEditSaveServiceProvider),
      isA<DiveEditSaveService>(),
    );
  });

  test('the service stretches trips with the trip repository', () async {
    final trip = await TripRepository().createTrip(
      Trip(
        id: 'a',
        diverId: 'me',
        name: 'Trip a',
        startDate: DateTime(1970, 1, 5),
        endDate: DateTime(1970, 1, 7),
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    final container = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(_RefusingTrips())],
    );
    addTearDown(container.dispose);

    // Putting the dive on a trip it falls outside of stretches that trip.
    await expectLater(
      container
          .read(diveEditSaveServiceProvider)
          .save(
            diveId: 'dive',
            apply: (dive) => diveTripField.write(dive, trip),
            changedCardIds: ['details'],
          ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'the provider passed this repository',
        ),
      ),
    );
  });
}
