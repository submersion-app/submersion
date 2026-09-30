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

  test('logging a dive raises the unfiltered total', () async {
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
  });

  test('the count is null while the list loads', () {
    final container = makeContainer();
    expect(container.read(diveListCountProvider), isNull);
  });
}
