import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _site = DiveSite(id: 'site', name: 'House Reef');
const _minutes = 20;

/// A dive's measured runtime can come from its profile, and a sync pull or a
/// profile edit writes the series without touching the dive row. Anything
/// reporting that runtime has to refresh on the series too (issue #3304).
void main() {
  late AppDatabase db;
  late String tripId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    await SiteRepository().createSite(_site);
    final now = DateTime.utc(2026, 3, 1);
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: now,
        endDate: DateTime.utc(2026, 3, 8),
        createdAt: now,
        updatedAt: now,
      ),
    );
    tripId = trip.id;
    await DiveRepository().createDive(
      Dive(
        id: 'd',
        dateTime: DateTime.utc(2026, 3, 2, 10),
        maxDepth: 18,
        site: _site,
        tripId: tripId,
        bottomTime: const Duration(minutes: 15),
      ),
    );
  });
  tearDown(() async => tearDownTestDatabase());

  /// A series and nothing else: no write reaches `dives`.
  Future<void> writeProfile() async {
    await ProfileSeriesRepository(database: db).insertSeries(
      diveId: 'd',
      samples: [
        for (var t = 0; t <= _minutes * 60; t += 60)
          ProfileSample(
            timestamp: t,
            depth: t == 0 || t == _minutes * 60 ? 0 : 18,
          ),
      ],
    );
    // Past the change tick's debounce.
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('both tick sets cover what a measured runtime reads', () {
    expect(
      DiveRepository.statisticsTickTables,
      containsAll(DiveRepository.measuredRuntimeTickTables),
    );
    expect(
      DiveRepository.diveListTickTables,
      containsAll(DiveRepository.measuredRuntimeTickTables),
    );
  });

  test('career statistics follow a profile-only write', () async {
    final container = makeContainer();
    container.listen(diveStatisticsProvider, (_, _) {});
    final before = await container.read(diveStatisticsProvider.future);
    expect(before.totalTimeSeconds, 0);

    await writeProfile();

    final after = await container.read(diveStatisticsProvider.future);
    expect(after.totalTimeSeconds, _minutes * 60);
  });

  test('a trip total follows a profile-only write', () async {
    final container = makeContainer();
    final provider = tripWithStatsProvider(tripId);
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future)).totalRuntime, 0);

    await writeProfile();

    expect((await container.read(provider.future)).totalRuntime, _minutes * 60);
  });

  test('the trip list follows a profile-only write', () async {
    final container = makeContainer();
    container.listen(allTripsWithStatsProvider, (_, _) {});
    final before = await container.read(allTripsWithStatsProvider.future);
    expect(before.single.totalRuntime, 0);

    await writeProfile();

    final after = await container.read(allTripsWithStatsProvider.future);
    expect(after.single.totalRuntime, _minutes * 60);
  });

  test('a trip day row follows a profile-only write', () async {
    final container = makeContainer();
    final provider = divesForTripProvider(tripId);
    container.listen(provider, (_, _) {});
    final before = await container.read(provider.future);
    expect(before.single.measuredRuntime, isNull);

    await writeProfile();

    final after = await container.read(provider.future);
    expect(after.single.measuredRuntime, const Duration(minutes: _minutes));
  });

  test('a site list row follows a profile-only write', () async {
    final container = makeContainer();
    container.listen(sitesWithCountsProvider, (_, _) {});
    final before = await container.read(sitesWithCountsProvider.future);
    expect(before.single.longestDiveSeconds, isNull);

    await writeProfile();

    final after = await container.read(sitesWithCountsProvider.future);
    expect(after.single.longestDiveSeconds, _minutes * 60);
  });

  test('the trip list page follows a profile-only write', () async {
    final container = makeContainer();
    container.listen(tripListNotifierProvider, (_, _) {});
    final notifier = container.read(tripListNotifierProvider.notifier);
    await notifier.refresh();
    final before = container.read(tripListNotifierProvider).value!;
    expect(before.single.totalRuntime, 0);

    await writeProfile();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final after = container.read(tripListNotifierProvider).value!;
    expect(after.single.totalRuntime, _minutes * 60);
  });

  test('a site page follows a profile-only write', () async {
    const diverId = 'diver';
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Me', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET diver_id = '$diverId'");
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(container.dispose);
    final provider = siteDiveStatisticsProvider(_site.id);
    container.listen(provider, (_, _) {});
    final before = await container.read(provider.future);
    expect(before.longestDiveSeconds, isNull);

    await writeProfile();

    final after = await container.read(provider.future);
    expect(after.longestDiveSeconds, _minutes * 60);
  });

  test('one tick follows the dive row and the series', () async {
    var ticks = 0;
    final sub = DiveRepository().watchMeasuredRuntimeChanges().listen(
      (_) => ticks++,
    );
    addTearDown(sub.cancel);

    db.notifyUpdates({const TableUpdate('dives', kind: UpdateKind.update)});
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    expect(ticks, 1);

    await writeProfile();
    expect(ticks, 2);
  });

  test('the surface interval column follows a source write', () async {
    final container = makeContainer();
    var loads = 0;
    container.listen(diveSurfaceIntervalsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) loads++;
    });
    await container.read(diveSurfaceIntervalsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final before = loads;

    db.notifyUpdates({
      const TableUpdate('dive_data_sources', kind: UpdateKind.update),
    });
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    await container.read(diveSurfaceIntervalsProvider.future);

    expect(loads, greaterThan(before));
  });
}
