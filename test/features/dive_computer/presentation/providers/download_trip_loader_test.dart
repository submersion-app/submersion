import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The resolver `diveImportServiceProvider` hands to `DiveImportService`
/// (issue #3022): the trip, among those the diver the download is filed
/// under can see, whose dates cover the dive's day.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['eric', 'sam']);
    final now = DateTime(2026, 10, 1);
    await TripRepository().createTrip(
      domain.Trip(
        id: 'maldives',
        diverId: 'eric',
        name: 'Maldives',
        startDate: DateTime(2026, 11, 7),
        endDate: DateTime(2026, 11, 21),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String?> load(
    DateTime start, {
    String? diverId,
    String? activeDiverId = 'eric',
  }) async {
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => activeDiverId,
        ),
      ],
    );
    addTearDown(container.dispose);
    final probe = FutureProvider<String?>(
      (ref) => loadTripIdForDownload(ref, start, diverId: diverId),
    );
    return container.read(probe.future);
  }

  test('a dive inside the dates joins the active diver\'s trip', () async {
    expect(await load(DateTime.utc(2026, 11, 8, 9, 30)), 'maldives');
  });

  test('dives on the first and late on the last day join it', () async {
    expect(await load(DateTime.utc(2026, 11, 7, 6)), 'maldives');
    expect(await load(DateTime.utc(2026, 11, 21, 22, 45)), 'maldives');
  });

  test('a dive outside the dates joins no trip', () async {
    expect(await load(DateTime.utc(2026, 11, 22, 9)), isNull);
    expect(await load(DateTime.utc(2026, 11, 6, 9)), isNull);
  });

  test('a download filed under the trip\'s owner finds it', () async {
    expect(
      await load(
        DateTime.utc(2026, 11, 8, 9),
        diverId: 'eric',
        activeDiverId: 'sam',
      ),
      'maldives',
    );
  });

  test(
    'a download filed under another diver skips a trip they cannot see',
    () async {
      expect(await load(DateTime.utc(2026, 11, 8, 9), diverId: 'sam'), isNull);
    },
  );
}
