import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_list_count_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

import '../../../../helpers/test_database.dart';

/// The dive list's title reads "34 of 812 dives" while a filter is active
/// (issue #2669), so the paginator carries the unfiltered total next to the
/// filtered [PaginatedDiveListState.totalCount].
void main() {
  late SharedPreferences prefs;
  late String diverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    diverId = diver.id;
    await prefs.setString(currentDiverIdKey, diverId);
    final diveRepo = DiveRepository();
    for (final (id, day, favorite) in [
      ('a', 1, true),
      ('b', 2, false),
      ('c', 3, false),
    ]) {
      await diveRepo.createDive(
        Dive(
          id: id,
          diverId: diverId,
          dateTime: DateTime(2026, 1, day),
          isFavorite: favorite,
        ),
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  Future<PaginatedDiveListState?> waitFor(
    ProviderContainer container,
    bool Function(PaginatedDiveListState) done,
  ) async {
    for (var i = 0; i < 200; i++) {
      final value = container.read(paginatedDiveListProvider).value;
      if (value != null && done(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(paginatedDiveListProvider).value;
  }

  /// A mutation refreshes the trip list without awaiting it; let that load
  /// finish so it does not write to a notifier the container has disposed.
  Future<void> settleTrips(ProviderContainer container) async {
    for (var i = 0; i < 200; i++) {
      if (!container.read(tripListNotifierProvider).isLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('with no filter only the count is loaded', () async {
    final container = makeContainer();

    final state = await waitFor(container, (s) => s.dives.length == 3);
    expect(state!.totalCount, 3);
    expect(state.unfilteredTotalCount, isNull);
    expect(
      container.read(diveListCountProvider),
      const ListEntryCount.unfiltered(3),
    );
  });

  test('a filter narrows the count but not the unfiltered total', () async {
    final container = makeContainer();
    await waitFor(container, (s) => s.dives.length == 3);

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      favoritesOnly: true,
    );

    final state = await waitFor(container, (s) => s.dives.length == 1);
    expect(state!.totalCount, 1);
    expect(state.unfilteredTotalCount, 3);
    expect(
      container.read(diveListCountProvider),
      const ListEntryCount.filtered(shown: 1, total: 3),
    );
  });

  test('deleting a listed dive lowers both counts', () async {
    final container = makeContainer();
    await waitFor(container, (s) => s.dives.length == 3);
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      favoritesOnly: true,
    );
    await waitFor(container, (s) => s.dives.length == 1);

    await container.read(paginatedDiveListProvider.notifier).deleteDive('a');
    await settleTrips(container);

    final state = container.read(paginatedDiveListProvider).value!;
    expect(state.totalCount, 0);
    expect(state.unfilteredTotalCount, 2);
  });

  test('bulk deleting listed dives lowers both counts', () async {
    final container = makeContainer();
    await waitFor(container, (s) => s.dives.length == 3);

    await container.read(paginatedDiveListProvider.notifier).bulkDeleteDives([
      'b',
      'c',
    ]);
    await settleTrips(container);

    final state = container.read(paginatedDiveListProvider).value!;
    expect(state.totalCount, 1);
    expect(state.unfilteredTotalCount, isNull);
  });

  test('logging a dive under a filter recounts from the query', () async {
    final container = makeContainer();
    await waitFor(container, (s) => s.dives.length == 3);
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      favoritesOnly: true,
    );
    await waitFor(container, (s) => s.dives.length == 1);

    await container
        .read(paginatedDiveListProvider.notifier)
        .addDive(Dive(id: 'd', diverId: diverId, dateTime: DateTime(2026, 2)));
    await settleTrips(container);

    final state = container.read(paginatedDiveListProvider).value!;
    expect(state.unfilteredTotalCount, 4);
    // The new dive is not a favorite, so the filtered list and its count
    // stay as they were rather than taking it in optimistically.
    expect(state.totalCount, 1);
    expect(state.dives.map((d) => d.id), ['a']);
  });

  // An edit can move a dive into or out of the active filter, so under a
  // filter the rows and count come from the query, not an in-place patch.
  group('edits under a filter', () {
    Future<ProviderContainer> favorites() async {
      final container = makeContainer();
      await waitFor(container, (s) => s.dives.length == 3);
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        favoritesOnly: true,
      );
      await waitFor(container, (s) => s.dives.length == 1);
      return container;
    }

    void expectListed(ProviderContainer container, List<String> ids) {
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives.map((d) => d.id), ids);
      expect(state.totalCount, ids.length);
      expect(state.unfilteredTotalCount, 3);
    }

    test('unfavoriting a listed dive drops it and its count', () async {
      final container = await favorites();

      await container
          .read(paginatedDiveListProvider.notifier)
          .setFavorite('a', false);
      await settleTrips(container);

      expectListed(container, []);
    });

    test('favoriting an unlisted dive brings it in', () async {
      final container = await favorites();

      await container
          .read(paginatedDiveListProvider.notifier)
          .toggleFavorite('b');
      await settleTrips(container);

      expect(
        container.read(paginatedDiveListProvider).value!.dives.map((d) => d.id),
        unorderedEquals(['a', 'b']),
      );
      expect(container.read(paginatedDiveListProvider).value!.totalCount, 2);
    });

    test('an edit that leaves the filter drops the dive', () async {
      final container = await favorites();
      final dive = await DiveRepository().getDiveById('a');

      await container
          .read(paginatedDiveListProvider.notifier)
          .updateDive(dive!.copyWith(isFavorite: false));
      await settleTrips(container);

      expectListed(container, []);
    });
  });

  // Table mode loads every dive and its filtered subset in full.
  group('diveTableCountProvider', () {
    Future<ListEntryCount?> tableCount(ProviderContainer container) async {
      final sub = container.listen(diveTableCountProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 200; i++) {
        final count = container.read(diveTableCountProvider);
        if (count != null) return count;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return container.read(diveTableCountProvider);
    }

    test('counts every dive with no filter', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(await tableCount(container), const ListEntryCount.unfiltered(3));
    });

    test('counts the filtered dives against every dive', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        favoritesOnly: true,
      );

      expect(
        await tableCount(container),
        const ListEntryCount.filtered(shown: 1, total: 3),
      );
    });
  });

  test('the count is null while the list loads', () {
    final container = makeContainer();
    expect(container.read(diveListCountProvider), isNull);
  });
}
