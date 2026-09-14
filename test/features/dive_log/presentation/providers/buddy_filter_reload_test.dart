import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, BuddiesCompanion, DiveBuddiesCompanion;
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The buddy filters read `dive_buddies` (and `buddies.name`), which the
/// dive list's own ticks do not watch. A sync pull of a buddy link, a buddy
/// merge and a buddy rename write only those tables, so every list filtered
/// by buddy must follow the buddy tick while the filter is set (#1915).
///
/// Counts page loads and forwards everything the paginator calls to the real
/// repository. [DiveRepository]'s only public constructor is a factory, so
/// this delegates rather than extends.
class _CountingRepository implements DiveRepository {
  _CountingRepository(this._inner);

  final DiveRepository _inner;
  int summaryCalls = 0;
  int allDivesCalls = 0;

  @override
  Future<List<Dive>> getAllDives({String? diverId}) {
    allDivesCalls++;
    return _inner.getAllDives(diverId: diverId);
  }

  @override
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) {
    summaryCalls++;
    return _inner.getDiveSummaries(
      diverId: diverId,
      filter: filter,
      cursor: cursor,
      offset: offset,
      limit: limit,
      sort: sort,
      disabledSafetyRules: disabledSafetyRules,
    );
  }

  @override
  Future<int> getDiveCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _inner.getDiveCount(diverId: diverId, filter: filter);

  @override
  Stream<void> watchDiveListChanges() => _inner.watchDiveListChanges();

  @override
  Stream<void> watchEquipmentAttrFilterChanges() =>
      _inner.watchEquipmentAttrFilterChanges();

  @override
  Stream<void> watchDiveListChangesWithBuddyLinks() =>
      _inner.watchDiveListChangesWithBuddyLinks();

  @override
  Stream<void> watchDivesChangesWithBuddyLinks() =>
      _inner.watchDivesChangesWithBuddyLinks();

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) => _inner.getBatchProfileSummaries(diveIds, maxSamples: maxSamples);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late String diverId;

  Future<void> insertBuddy(String id, String name) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: name,
          diverId: Value(diverId),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  /// What a sync pull of a buddy link writes: a junction row, no dive row.
  Future<void> link(String diveId, String buddyId) => db
      .into(db.diveBuddies)
      .insert(
        DiveBuddiesCompanion.insert(
          id: '$diveId|$buddyId',
          diveId: diveId,
          buddyId: buddyId,
          createdAt: 1,
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
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
    await prefs.setString(currentDiverIdKey, diver.id);
    final diveRepo = DiveRepository();
    for (final (id, day) in [('annDive', 1), ('otherDive', 2)]) {
      await diveRepo.createDive(
        Dive(id: id, diverId: diver.id, dateTime: DateTime(2026, 1, day)),
      );
    }
    await insertBuddy('ann', 'Ann');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer containerWith(
    DiveFilterState filter, {
    DiveRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (repository != null)
          diveRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(diveFilterProvider.notifier).state = filter;
    return container;
  }

  /// Polls [read] until [done] holds, returning the last value either way.
  Future<T?> waitFor<T>(T? Function() read, bool Function(T) done) async {
    for (var i = 0; i < 200; i++) {
      final value = read();
      if (value != null && done(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return read();
  }

  Future<Set<String>?> listedIds(
    ProviderContainer container,
    bool Function(Set<String>) done,
  ) => waitFor(() {
    final state = container.read(paginatedDiveListProvider);
    if (state.isLoading) return null;
    return state.value?.dives.map((d) => d.id).toSet();
  }, done);

  group('paginated dive list', () {
    test('a link-only write reloads a buddy-filtered page and count', () async {
      final container = containerWith(const DiveFilterState(buddyId: 'ann'));
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await listedIds(container, (ids) => ids.isEmpty), isEmpty);

      await link('annDive', 'ann');

      expect(await listedIds(container, (ids) => ids.isNotEmpty), {
        'annDive',
      }, reason: 'the list tick does not watch dive_buddies');
      expect(container.read(paginatedDiveListProvider).value!.totalCount, 1);
    });

    test('a buddy rename reloads a name-filtered page', () async {
      await insertBuddy('bob', 'Bob');
      await link('otherDive', 'bob');
      final container = containerWith(
        const DiveFilterState(buddyNameFilter: 'Robert'),
      );
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await listedIds(container, (ids) => ids.isEmpty), isEmpty);

      await (db.update(db.buddies)..where((t) => t.id.equals('bob'))).write(
        const BuddiesCompanion(name: Value('Robert')),
      );

      expect(await listedIds(container, (ids) => ids.isNotEmpty), {
        'otherDive',
      }, reason: 'a rename writes only buddies, which the name filter joins');
    });

    test('a no-buddy list drops a dive that gains a link', () async {
      final container = containerWith(const DiveFilterState(noBuddyOnly: true));
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await listedIds(container, (ids) => ids.length == 2), {
        'annDive',
        'otherDive',
      });

      await link('annDive', 'ann');

      expect(await listedIds(container, (ids) => ids.length == 1), {
        'otherDive',
      });
    });

    test('an unfiltered list does not reload on a buddy write', () async {
      final counting = _CountingRepository(DiveRepository());
      final container = containerWith(
        const DiveFilterState(buddyId: 'ann'),
        repository: counting,
      );
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await listedIds(container, (ids) => ids.isEmpty);
      // Clearing the filter must also drop the subscription.
      container.read(diveFilterProvider.notifier).state =
          const DiveFilterState();
      await listedIds(container, (ids) => ids.length == 2);
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
      );
      final before = counting.summaryCalls;

      await link('annDive', 'ann');
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 300),
      );

      expect(counting.summaryCalls, before);
    });

    test('a local buddy edit reloads a buddy-filtered page once', () async {
      // The dive editor's link writers touch dive_buddies and then bump the
      // dive row, outside a transaction. Two separately debounced ticks
      // would reload the page once for each write.
      final counting = _CountingRepository(DiveRepository());
      final container = containerWith(
        const DiveFilterState(buddyId: 'ann'),
        repository: counting,
      );
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await listedIds(container, (ids) => ids.isEmpty);
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
      );
      final before = counting.summaryCalls;

      await BuddyRepository().addBuddyToDive(
        'annDive',
        'ann',
        DiveRole.buddyId,
      );
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce * 2 +
            const Duration(milliseconds: 300),
      );

      expect(await listedIds(container, (ids) => ids.isNotEmpty), {'annDive'});
      expect(counting.summaryCalls - before, 1);
    });
  });

  test('turning on a buddy filter re-reads the maps list', () async {
    // Unfiltered, the in-memory list does not watch the buddy tables, so a
    // link synced in meanwhile leaves its hydrated buddies stale. The
    // filter must not then be applied to that stale data.
    final container = containerWith(const DiveFilterState());
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    Set<String>? filteredIds() =>
        container.read(filteredDivesProvider).value?.map((d) => d.id).toSet();
    await waitFor(filteredIds, (ids) => ids.length == 2);
    await link('annDive', 'ann');
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );

    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      buddyNameFilter: 'Ann',
    );

    expect(await waitFor(filteredIds, (ids) => ids.length == 1), {
      'annDive',
    }, reason: 'the link was written while the list was unfiltered');
  });

  test('a local buddy edit reloads the maps list once', () async {
    final counting = _CountingRepository(DiveRepository());
    final container = containerWith(
      const DiveFilterState(buddyNameFilter: 'Ann'),
      repository: counting,
    );
    final sub = container.listen(filteredDivesProvider, (_, _) {});
    addTearDown(sub.close);
    Set<String>? filteredIds() =>
        container.read(filteredDivesProvider).value?.map((d) => d.id).toSet();
    await waitFor(filteredIds, (ids) => ids.isEmpty);
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    final before = counting.allDivesCalls;

    await BuddyRepository().addBuddyToDive('annDive', 'ann', DiveRole.buddyId);
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce * 2 + const Duration(milliseconds: 300),
    );

    expect(await waitFor(filteredIds, (ids) => ids.isNotEmpty), {'annDive'});
    expect(counting.allDivesCalls - before, 1);
  });

  test('a link-only write refreshes detail-page neighbor ids', () async {
    // getOrderedDiveIds shares the list's WHERE builder, so previous/next
    // navigation reads dive_buddies while a buddy filter is set.
    final container = containerWith(const DiveFilterState(buddyId: 'ann'));
    final sub = container.listen(orderedDiveIdsProvider, (_, _) {});
    addTearDown(sub.close);
    List<String>? orderedIds() => container.read(orderedDiveIdsProvider).value;
    expect(await waitFor(orderedIds, (ids) => ids.isEmpty), isEmpty);

    await link('annDive', 'ann');

    expect(await waitFor(orderedIds, (ids) => ids.isNotEmpty), [
      'annDive',
    ], reason: 'the dives tick never fires for a link-only write');
  });

  test(
    'a link-only write refreshes the in-memory list behind the maps',
    () async {
      // filteredDivesProvider filters DiveListNotifier's hydrated dives in
      // memory, reading dive.buddies, which only a reload refreshes.
      final container = containerWith(
        const DiveFilterState(buddyNameFilter: 'Ann'),
      );
      final sub = container.listen(filteredDivesProvider, (_, _) {});
      addTearDown(sub.close);
      Set<String>? filteredIds() =>
          container.read(filteredDivesProvider).value?.map((d) => d.id).toSet();
      expect(await waitFor(filteredIds, (ids) => ids.isEmpty), isEmpty);

      await link('annDive', 'ann');

      expect(await waitFor(filteredIds, (ids) => ids.isNotEmpty), {
        'annDive',
      }, reason: 'DiveListNotifier reloads only on the dives tick');
    },
  );
}
