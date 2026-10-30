import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';

class _CountingRepository implements DiveRepository {
  int indexCalls = 0;

  @override
  Future<List<DiveScrubberEntry>> getDiveScrubberIndex({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async {
    indexCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedList extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _FixedList(int totalCount)
    : super(
        AsyncValue.data(
          PaginatedDiveListState(totalCount: totalCount, revision: 1),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late DiveRepository diveRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    diveRepo = DiveRepository();
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

  Future<Diver> setUpCurrentDiver() async {
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
    return diver;
  }

  /// Creates [count] dives, newest first, so the default date sort is stable.
  Future<List<Dive>> seedDives(String diverId, int count) async {
    final created = <Dive>[];
    for (var i = 0; i < count; i++) {
      created.add(
        await diveRepo.createDive(
          Dive(
            id: '',
            diverId: diverId,
            diveNumber: count - i,
            dateTime: DateTime(2024, 1, 1).add(Duration(days: count - i)),
            name: 'Dive ${count - i}',
            maxDepth: i.isEven ? 30 : 10,
          ),
        ),
      );
    }
    return created;
  }

  /// Drives the list to [pages] loaded pages and returns the resulting state.
  Future<PaginatedDiveListState> loadPages(
    ProviderContainer container,
    int pages,
  ) async {
    while (container.read(paginatedDiveListProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final notifier = container.read(paginatedDiveListProvider.notifier);
    for (var i = 1; i < pages; i++) {
      await notifier.loadNextPage();
    }
    return container.read(paginatedDiveListProvider).value!;
  }

  /// Waits, past the list's change-tick debounce, for an index whose ids
  /// pass [done], and returns them.
  Future<List<String>> indexWhen(
    ProviderContainer container,
    bool Function(List<String> ids) done,
  ) async {
    var ids = <String>[];
    for (var i = 0; i < 300; i++) {
      final index = container.read(diveScrubberIndexProvider).valueOrNull;
      ids = [for (final e in index?.entries ?? const []) e.id];
      if (index != null && done(ids)) return ids;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('index never settled; last ids: ${ids.length}');
  }

  group('DiveScrubberIndex.builtFor', () {
    test('accepts an equal filter that is a different instance', () {
      const sort = SortState(
        field: DiveSortField.date,
        direction: SortDirection.descending,
      );
      // Built by copyWith, so each is its own instance: identity and
      // equality tell different stories.
      DiveFilterState deep() =>
          const DiveFilterState().copyWith(minDepth: 20, tagIds: ['t']);
      final built = deep();
      final again = deep();
      expect(identical(built, again), isFalse);
      final index = DiveScrubberIndex(
        entries: const [],
        diverId: 'd',
        filter: built,
        sort: sort,
      );

      expect(index.builtFor(diverId: 'd', filter: again, sort: sort), isTrue);
      expect(
        index.builtFor(
          diverId: 'd',
          filter: const DiveFilterState(minDepth: 30),
          sort: sort,
        ),
        isFalse,
      );
    });
  });

  group('diveScrubberIndexProvider', () {
    Future<_CountingRepository> gated(int totalCount) async {
      final repo = _CountingRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveRepositoryProvider.overrideWithValue(repo),
          paginatedDiveListProvider.overrideWith(
            (ref) => _FixedList(totalCount),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(diveScrubberIndexProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(diveScrubberIndexProvider.future);
      return repo;
    }

    test('a list too short for a scrubber never queries the index', () async {
      final repo = await gated(diveScrubberMinDives - 1);
      expect(repo.indexCalls, 0);
    });

    test('a list long enough for a scrubber queries the index', () async {
      final repo = await gated(diveScrubberMinDives);
      expect(repo.indexCalls, 1);
    });

    test(
      'holds every dive in list order and follows a filter change',
      () async {
        final diver = await setUpCurrentDiver();
        final dives = await seedDives(diver.id, 120);
        final container = makeContainer();
        addTearDown(container.dispose);
        final listSub = container.listen(paginatedDiveListProvider, (_, _) {});
        addTearDown(listSub.close);
        final indexSub = container.listen(diveScrubberIndexProvider, (_, _) {});
        addTearDown(indexSub.close);

        final page = await loadPages(container, 1);
        final built = await container.read(diveScrubberIndexProvider.future);
        final index = built.entries;
        expect(index, hasLength(120));
        expect(built.diverId, diver.id);
        expect(
          index.take(page.dives.length).map((e) => e.id),
          page.dives.map((d) => d.id),
        );

        const deepFilter = DiveFilterState(minDepth: 20);
        container.read(diveFilterProvider.notifier).state = deepFilter;
        final deep = [
          for (final (i, d) in dives.indexed)
            if (i.isEven) d.id,
        ];
        final filtered = await indexWhen(
          container,
          (ids) => ids.isNotEmpty && ids.length < 120,
        );
        expect(filtered, deep);
        final current = container.read(diveScrubberIndexProvider).value!;
        expect(identical(current.filter, deepFilter), isTrue);
        expect(current.sort, container.read(diveSortProvider));
      },
    );

    test('a table tick refetches the index', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, 60);
      final container = makeContainer();
      addTearDown(container.dispose);
      final listSub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(listSub.close);
      final indexSub = container.listen(diveScrubberIndexProvider, (_, _) {});
      addTearDown(indexSub.close);
      await loadPages(container, 1);
      expect(
        (await container.read(diveScrubberIndexProvider.future)).entries,
        hasLength(60),
      );

      final added = await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          diveNumber: 61,
          dateTime: DateTime(2025, 6, 1),
          name: 'Dive 61',
        ),
      );

      final ids = await indexWhen(container, (ids) => ids.length == 61);
      expect(ids.first, added.id);
    });
  });
}
