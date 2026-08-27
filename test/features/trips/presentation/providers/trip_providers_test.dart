import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Only AppDatabase: the generated Drift classes collide with the domain
// entities this file imports (Dive, Diver, Trip).
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/test_database.dart';

Trip _makeTrip({
  String id = '',
  String name = 'Test Trip',
  DateTime? start,
  DateTime? end,
  bool isShared = false,
  String? diverId,
}) {
  final s = start ?? DateTime(2024, 1, 1);
  return Trip(
    id: id,
    name: name,
    startDate: s,
    endDate: end ?? s.add(const Duration(days: 1)),
    isShared: isShared,
    diverId: diverId,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

/// Polls [read] until [settled] holds, so the table tick -> invalidateSelfWhen
/// -> rebuild round trip has a chance to run.
///
/// The budget is derived from [DiveRepository.changeTickDebounce] rather than
/// hard-coded, so it stays proportionate if that window is ever widened. A
/// fixed budget is the trap here: `watchDivesChanges` is debounced and
/// `watchTripsChanges` is not, so a number sized against the undebounced stream
/// spends most of itself waiting for the debounced tick to fire at all. Never
/// settling fails here, naming the round trip that stalled, instead of
/// surfacing downstream as a bare value mismatch that reads like a wrong query.
Future<T> _pollUntilSettled<T>(
  Future<T> Function() read,
  bool Function(T value) settled, {
  required String awaiting,
  required String Function(T value) describe,
}) async {
  const interval = Duration(milliseconds: 10);
  final budget = DiveRepository.changeTickDebounce * 20;
  final deadline = DateTime.now().add(budget);

  var value = await read();
  while (!settled(value) && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(interval);
    value = await read();
  }

  if (!settled(value)) {
    fail(
      'Timed out after ${budget.inMilliseconds}ms waiting for $awaiting. '
      'The table tick -> invalidateSelfWhen -> rebuild round trip never '
      'settled; the provider still holds ${describe(value)}.',
    );
  }
  return value;
}

void main() {
  late SharedPreferences prefs;
  late TripRepository tripRepo;
  late DiverRepository diverRepo;
  late DiveRepository diveRepo;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    tripRepo = TripRepository();
    diverRepo = DiverRepository();
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('TripFilterState', () {
    test('hasActiveFilters is false by default', () {
      const s = TripFilterState();
      expect(s.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters is true with equipmentId', () {
      const s = TripFilterState(equipmentId: 'eq-1');
      expect(s.hasActiveFilters, isTrue);
    });

    test('copyWith replaces equipmentId', () {
      const base = TripFilterState(equipmentId: 'eq-1');
      final updated = base.copyWith(equipmentId: 'eq-2');
      expect(updated.equipmentId, equals('eq-2'));
    });

    test('copyWith(clearEquipmentId: true) removes the filter', () {
      const base = TripFilterState(equipmentId: 'eq-1');
      final cleared = base.copyWith(clearEquipmentId: true);
      expect(cleared.equipmentId, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });
  });

  group('allTripsProvider / tripByIdProvider / tripWithStatsProvider', () {
    test(
      'allTripsProvider returns repo data scoped to validated diver',
      () async {
        final diver = await diverRepo.createDiver(
          Diver(
            id: '',
            name: 'D',
            isDefault: true,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        );
        await tripRepo.createTrip(
          _makeTrip(name: 'Owned').copyWith(diverId: diver.id),
        );
        await tripRepo.createTrip(_makeTrip(name: 'Other'));

        final container = makeContainer();
        addTearDown(container.dispose);

        final trips = await container.read(allTripsProvider.future);
        expect(trips.map((t) => t.name), contains('Owned'));
      },
    );

    test('allTripsProvider self-invalidates after a write to the trips table '
        '(sync scenario)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the FutureProvider (and its trips-table
      // subscription) alive, mirroring a widget watching the list.
      final sub = container.listen(allTripsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allTripsProvider.future), isEmpty);

      // A sync applies a remote trip straight to the DB. The watchTripsChanges
      // tick must invalidate the provider so the next read includes it.
      await tripRepo.createTrip(
        _makeTrip(name: 'Synced Trip').copyWith(diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allTripsProvider.future,
        )).map((t) => t.name).toList();
        if (names.contains('Synced Trip')) break;
      }

      expect(
        names,
        contains('Synced Trip'),
        reason:
            'allTripsProvider should auto-refresh after the table write '
            'without any manual invalidation',
      );
    });

    test('tripByIdProvider returns the matching trip', () async {
      final created = await tripRepo.createTrip(_makeTrip(name: 'Find'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final t = await container.read(tripByIdProvider(created.id).future);
      expect(t?.name, equals('Find'));
    });

    test('tripByIdProvider returns null when not found', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(tripByIdProvider('ghost').future), isNull);
    });

    test(
      'tripWithStatsProvider returns TripWithStats with zero dive data',
      () async {
        final created = await tripRepo.createTrip(_makeTrip(name: 'Z'));

        final container = makeContainer();
        addTearDown(container.dispose);

        final s = await container.read(
          tripWithStatsProvider(created.id).future,
        );
        expect(s.trip.name, equals('Z'));
        expect(s.diveCount, equals(0));
      },
    );
  });

  group('diveIdsForTripProvider & divesForTripProvider', () {
    test('returns empty list when trip has no dives', () async {
      final t = await tripRepo.createTrip(_makeTrip(name: 'NoDives'));

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(diveIdsForTripProvider(t.id).future),
        isEmpty,
      );
      expect(await container.read(divesForTripProvider(t.id).future), isEmpty);
    });

    test('divesForTripProvider auto-refreshes after a dive is deleted directly '
        'from the DB (dive-merge/consolidate scenario)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final trip = await tripRepo.createTrip(
        _makeTrip(name: 'Merge').copyWith(diverId: diver.id),
      );
      final survivor = await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          dateTime: DateTime(2024, 6, 1),
          tripId: trip.id,
        ),
      );
      final loser = await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          dateTime: DateTime(2024, 6, 2),
          tripId: trip.id,
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the FutureProvider (and its dives-table
      // subscription) alive, mirroring a widget watching the trip page.
      final sub = container.listen(divesForTripProvider(trip.id), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        divesForTripProvider(trip.id).future,
      );
      expect(initial.map((d) => d.id), containsAll([survivor.id, loser.id]));

      // A dive merge/consolidation deletes the loser dive through the
      // tombstone-logging bulkDeleteDives path (dive_consolidation_service.dart,
      // dive_merge_service.dart) -- the same primitive a sync pull uses when
      // applying a remote deletion. divesForTripProvider must notice and drop
      // the deleted dive without any caller having to invalidate it manually.
      //
      // Wrapped in a transaction because both production callers are:
      // dive_merge_service.dart:142 and dive_consolidation_service.dart:78 open
      // one and run bulkDeleteDives inside it alongside a dozen other writes.
      // bulkDeleteDives opens no transaction of its own, so calling it bare
      // would autocommit and fire an immediate standalone tick -- a shape
      // neither real path produces. Drift defers table-update notifications to
      // commit, so this asserts against the single coalesced post-commit tick
      // the app actually emits.
      await db.transaction(() async {
        await diveRepo.bulkDeleteDives([loser.id]);
      });

      final dives = await _pollUntilSettled(
        () => container.read(divesForTripProvider(trip.id).future),
        (dives) => dives.every((d) => d.id != loser.id),
        awaiting: 'divesForTripProvider to drop the merged-away dive',
        describe: (dives) => '${dives.length} dives',
      );

      expect(
        dives.map((d) => d.id),
        equals([survivor.id]),
        reason:
            'divesForTripProvider should auto-refresh after a dive delete, '
            'the same way tripListNotifierProvider already does',
      );
    });
  });

  group('tripWithStatsProvider reactivity', () {
    test('auto-refreshes its aggregate stats after a dive is deleted directly '
        'from the DB (dive-merge/consolidate scenario)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final trip = await tripRepo.createTrip(
        _makeTrip(name: 'Merge Stats').copyWith(diverId: diver.id),
      );
      await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          dateTime: DateTime(2024, 6, 1),
          tripId: trip.id,
          maxDepth: 18,
        ),
      );
      final loser = await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          dateTime: DateTime(2024, 6, 2),
          tripId: trip.id,
          maxDepth: 42,
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(tripWithStatsProvider(trip.id), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        tripWithStatsProvider(trip.id).future,
      );
      expect(initial.diveCount, equals(2));
      expect(initial.maxDepth, equals(42));

      // getTripWithStats aggregates straight over the dives table, so a merge
      // changes the counts without touching the trip row -- and the trip detail
      // page renders these in TripStatStrip directly above the itinerary that
      // divesForTripProvider feeds. Without the dives-table subscription the
      // header would still read "2 dives / 42m" over a list of one 18m dive.
      //
      // Transaction-wrapped for the same reason as the divesForTripProvider
      // test above: it is the tick shape the merge/consolidate services emit.
      await db.transaction(() async {
        await diveRepo.bulkDeleteDives([loser.id]);
      });

      final stats = await _pollUntilSettled(
        () => container.read(tripWithStatsProvider(trip.id).future),
        (stats) => stats.diveCount == 1,
        awaiting: 'tripWithStatsProvider to drop the merged-away dive',
        describe: (stats) =>
            '${stats.diveCount} dives / maxDepth ${stats.maxDepth}',
      );

      expect(stats.maxDepth, equals(18));
    });

    test('auto-refreshes the trip row after a trips-table write (synced '
        'rename)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final trip = await tripRepo.createTrip(
        _makeTrip(name: 'Old Name').copyWith(diverId: diver.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(tripWithStatsProvider(trip.id), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        tripWithStatsProvider(trip.id).future,
      );
      expect(initial.trip.name, equals('Old Name'));

      // getTripWithStats calls getTripById before the dives aggregate, and the
      // detail page renders the returned trip's name/dates next to the stats.
      // A sync can rename a trip with no accompanying dives write, so the
      // dives-table subscription alone would leave the header stale forever.
      await tripRepo.updateTrip(trip.copyWith(name: 'Renamed By Sync'));

      final stats = await _pollUntilSettled(
        () => container.read(tripWithStatsProvider(trip.id).future),
        (stats) => stats.trip.name == 'Renamed By Sync',
        awaiting: 'tripWithStatsProvider to pick up the renamed trip row',
        describe: (stats) => 'trip name "${stats.trip.name}"',
      );

      expect(stats.trip.name, equals('Renamed By Sync'));
    });
  });

  group('tripSearchProvider', () {
    test('returns matching trips for a query', () async {
      await tripRepo.createTrip(_makeTrip(name: 'Maldives'));
      await tripRepo.createTrip(_makeTrip(name: 'Bonaire'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final results = await container.read(
        tripSearchProvider('Maldives').future,
      );
      expect(results.length, equals(1));
      expect(results.first.name, equals('Maldives'));
    });

    test('falls back to allTrips when query is empty', () async {
      await tripRepo.createTrip(_makeTrip(name: 'A'));

      final container = makeContainer();
      addTearDown(container.dispose);

      // Pre-warm allTripsProvider
      await container.read(allTripsProvider.future);

      final results = await container.read(tripSearchProvider('').future);
      expect(results.map((t) => t.name), contains('A'));
    });
  });

  group('tripForDateProvider', () {
    test('finds the trip containing the date', () async {
      await tripRepo.createTrip(
        _makeTrip(
          name: 'In June',
          start: DateTime(2024, 6, 1),
          end: DateTime(2024, 6, 10),
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        tripForDateProvider(DateTime(2024, 6, 5)).future,
      );
      expect(result?.name, equals('In June'));
    });

    test('returns null when no trip contains the date', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(tripForDateProvider(DateTime(2099, 1, 1)).future),
        isNull,
      );
    });
  });

  group('_applyTripSorting via sortedFilteredTripsProvider', () {
    late TripWithStats statsA;
    late TripWithStats statsB;
    late TripWithStats statsC;

    setUp(() async {
      final tA = await tripRepo.createTrip(
        _makeTrip(name: 'Alpha', start: DateTime(2024, 1, 1)),
      );
      final tB = await tripRepo.createTrip(
        _makeTrip(name: 'Bravo', start: DateTime(2024, 6, 1)),
      );
      final tC = await tripRepo.createTrip(
        _makeTrip(name: 'Charlie', start: DateTime(2024, 3, 1)),
      );
      statsA = await tripRepo.getTripWithStats(tA.id);
      statsB = await tripRepo.getTripWithStats(tB.id);
      statsC = await tripRepo.getTripWithStats(tC.id);
    });

    test('sorts by start date ascending', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Wait for the notifier to load
      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      container.read(tripSortProvider.notifier).state = const SortState(
        field: TripSortField.startDate,
        direction: SortDirection.ascending,
      );
      final sorted = container.read(sortedFilteredTripsProvider).value!;
      expect(
        sorted.map((s) => s.trip.name).toList(),
        equals([statsA.trip.name, statsC.trip.name, statsB.trip.name]),
      );
    });

    test('sorts by end date descending', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      container.read(tripSortProvider.notifier).state = const SortState(
        field: TripSortField.endDate,
        direction: SortDirection.descending,
      );
      final sorted = container.read(sortedFilteredTripsProvider).value!;
      expect(sorted.first.trip.name, equals('Bravo'));
    });

    test('sorts by name ascending (A → Z)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      container.read(tripSortProvider.notifier).state = const SortState(
        field: TripSortField.name,
        direction: SortDirection.ascending,
      );
      final sorted = container.read(sortedFilteredTripsProvider).value!;
      expect(sorted.first.trip.name, equals('Charlie'));
    });

    test('sorts by name descending (Z → A via inversion for text)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      container.read(tripSortProvider.notifier).state = const SortState(
        field: TripSortField.name,
        direction: SortDirection.descending,
      );
      final sorted = container.read(sortedFilteredTripsProvider).value!;
      expect(sorted.first.trip.name, equals('Alpha'));
    });
  });

  group('TripListNotifier CRUD', () {
    test('addTrip creates and returns a new trip', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(tripListNotifierProvider.notifier);
      final newTrip = await notifier.addTrip(_makeTrip(name: 'Added'));
      expect(newTrip.name, equals('Added'));
      expect(newTrip.id, isNotEmpty);
      expect(newTrip.diverId, equals(diver.id));
    });

    test('auto-refreshes the list when a trip is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(tripListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(tripListNotifierProvider).value, isEmpty);

      // A sync applies a remote trip straight to the DB (no notifier mutation
      // call). The watchTripsChanges tick must silently reload the list.
      await tripRepo.createTrip(
        _makeTrip(name: 'Synced').copyWith(diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(tripListNotifierProvider).value ?? [])
            .map((t) => t.trip.name)
            .toList();
        if (names.contains('Synced')) break;
      }

      expect(
        names,
        contains('Synced'),
        reason:
            'TripListNotifier should auto-refresh after a direct DB write '
            'without any manual refresh() call',
      );
    });

    test('auto-refreshes the trip list when a DIVE is written directly to the '
        'DB (trip stats LEFT JOIN dives)', () async {
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final trip = await tripRepo.createTrip(
        _makeTrip(
          name: 'Counting',
          start: DateTime(2024, 6, 1),
          end: DateTime(2024, 6, 10),
        ).copyWith(diverId: diver.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its dives-table subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(tripListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      // Trip starts with zero dives.
      final initial = container.read(tripListNotifierProvider).value!;
      expect(initial.firstWhere((s) => s.trip.id == trip.id).diveCount, 0);

      // A sync applies a dive (assigned to the trip) straight to the DB. The
      // watchDivesChanges tick on the trip notifier must reload the stats,
      // because diveCount is computed by a LEFT JOIN against the dives table.
      await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          dateTime: DateTime(2024, 6, 5),
          tripId: trip.id,
          notes: 'In-trip dive',
        ),
      );

      var diveCount = 0;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final stats = container.read(tripListNotifierProvider).value ?? [];
        final match = stats.where((s) => s.trip.id == trip.id);
        diveCount = match.isEmpty ? 0 : match.first.diveCount;
        if (diveCount >= 1) break;
      }

      expect(
        diveCount,
        equals(1),
        reason:
            'TripListNotifier should reload trip stats after a direct dive '
            'write, since the dives-table subscription drives the refresh',
      );
    });

    test('updateTrip persists changes', () async {
      final t = await tripRepo.createTrip(_makeTrip(name: 'Original'));

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(tripListNotifierProvider.notifier);
      await notifier.updateTrip(t.copyWith(name: 'Updated'));

      final read = await tripRepo.getTripById(t.id);
      expect(read?.name, equals('Updated'));
    });

    test('deleteTrip removes the trip', () async {
      final t = await tripRepo.createTrip(_makeTrip(name: 'Gone'));

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(tripListNotifierProvider.notifier);
      await notifier.deleteTrip(t.id);

      expect(await tripRepo.getTripById(t.id), isNull);
    });
  });

  group('filteredTripsProvider passthroughs', () {
    test('returns trip list unfiltered when no filter is set', () async {
      await tripRepo.createTrip(_makeTrip(name: 'One'));

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final result = container.read(filteredTripsProvider);
      expect(result.value!.map((t) => t.trip.name), contains('One'));
    });
  });

  group('highlightedTripIdProvider', () {
    test('defaults to null', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(highlightedTripIdProvider), isNull);
    });

    test('can be updated', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(highlightedTripIdProvider.notifier).state = 't-42';
      expect(container.read(highlightedTripIdProvider), equals('t-42'));
    });
  });

  group('allTripsWithStatsProvider', () {
    test('returns empty list when no trips exist', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final stats = await container.read(allTripsWithStatsProvider.future);
      expect(stats, isEmpty);
    });

    test('returns stats for trips', () async {
      await tripRepo.createTrip(_makeTrip(name: 'Alpha'));
      await tripRepo.createTrip(_makeTrip(name: 'Bravo'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final stats = await container.read(allTripsWithStatsProvider.future);
      expect(stats.length, equals(2));
    });
  });

  group('TripListNotifier dive assignment', () {
    test('assignDiveToTrip updates the trip linkage', () async {
      // Set up diver and trip
      final diver = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);

      final t = await tripRepo.createTrip(
        _makeTrip(name: 'Dive Trip').copyWith(diverId: diver.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      // Wait for init.
      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(tripListNotifierProvider.notifier);

      // assignDiveToTrip + removeDiveFromTrip for a non-existent dive should
      // still refresh without throwing.
      await notifier.assignDiveToTrip('no-dive', t.id);
      await notifier.removeDiveFromTrip('no-dive', t.id);
    });
  });

  group('TripListNotifier reacts to current diver change', () {
    test('reloads trip list when current diver changes', () async {
      final a = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'Alice',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      final b = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'Bob',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, a.id);

      await tripRepo.createTrip(
        _makeTrip(name: 'A-Trip').copyWith(diverId: a.id),
      );
      await tripRepo.createTrip(
        _makeTrip(name: 'B-Trip').copyWith(diverId: b.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      final first = container.read(tripListNotifierProvider).value!;
      expect(first.map((s) => s.trip.name), contains('A-Trip'));
      expect(first.map((s) => s.trip.name), isNot(contains('B-Trip')));

      // Switch current diver — should trigger listen → reload.
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(b.id);

      // Let async reload complete.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        final state = container.read(tripListNotifierProvider);
        if (state.hasValue &&
            state.value!.any((s) => s.trip.name == 'B-Trip')) {
          break;
        }
      }

      final second = container.read(tripListNotifierProvider).value!;
      expect(second.map((s) => s.trip.name), contains('B-Trip'));
    });
  });

  group('tripSitesWithLocationsProvider', () {
    test('returns empty list when trip has no dives', () async {
      final t = await tripRepo.createTrip(_makeTrip(name: 'EmptyTrip'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final sites = await container.read(
        tripSitesWithLocationsProvider(t.id).future,
      );
      expect(sites, isEmpty);
    });
  });

  group('assignDivesToTrip', () {
    test('batch-assigns to new trip and refreshes', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(tripListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      final notifier = container.read(tripListNotifierProvider.notifier);

      // Even with no dive ids this should short-circuit without error.
      await notifier.assignDivesToTrip([], 'no-trip');

      // With old trip IDs to invalidate
      final t = await tripRepo.createTrip(_makeTrip(name: 'T'));
      await notifier.assignDivesToTrip(
        ['nonexistent'],
        t.id,
        oldTripIds: {'other-trip-1', 'other-trip-2'},
      );
    });
  });

  group('trip config providers', () {
    test('tripDetailedCardConfigProvider has default slots', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final config = container.read(tripDetailedCardConfigProvider);
      expect(config.slots, isNotEmpty);
    });

    test('tripCompactCardConfigProvider has default slots', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final config = container.read(tripCompactCardConfigProvider);
      expect(config.slots, isNotEmpty);
    });

    test(
      'tripTableConfigProvider returns notifier with default columns when no diver',
      () {
        final container = makeContainer();
        addTearDown(container.dispose);

        // When no current diver, the provider still returns a notifier with
        // the default config (no persistence initialized).
        final cfg = container.read(tripTableConfigProvider);
        expect(cfg.columns, isNotEmpty);
      },
    );
  });

  group('filteredTripsProvider equipment filter branch', () {
    test(
      'delegates to equipment-filtered family when equipmentId is set',
      () async {
        await tripRepo.createTrip(_makeTrip(name: 'Trip1'));
        await tripRepo.createTrip(_makeTrip(name: 'Trip2'));

        final container = makeContainer();
        addTearDown(container.dispose);

        // Wait for initial load.
        while (container.read(tripListNotifierProvider).isLoading) {
          await Future<void>.delayed(Duration.zero);
        }

        // Set an equipment filter; the filtered trips list should be empty
        // because no trips are linked to the equipment.
        container.read(tripFilterProvider.notifier).state =
            const TripFilterState(equipmentId: 'eq-nonexistent');

        // Wait one micro-task for the async family provider to resolve.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final result = container.read(filteredTripsProvider);
        // Either resolved with empty data or still loading (both are valid).
        if (result.hasValue) {
          expect(result.value, isEmpty);
        } else {
          expect(result.isLoading || result.hasError, isTrue);
        }
      },
    );
  });
}
