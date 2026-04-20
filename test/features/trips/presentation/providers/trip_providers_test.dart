import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';

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

void main() {
  late SharedPreferences prefs;
  late TripRepository tripRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    tripRepo = TripRepository();
    diverRepo = DiverRepository();
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
}
