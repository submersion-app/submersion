import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';

/// Pages the notifier keeps in memory once the user has scrolled past the
/// first page. Mirrors `PaginatedDiveListNotifier._pageSize`.
const _pageSize = 50;

/// Serves the first page from the real database, then fails every later one,
/// standing in for a transient read error while paging.
///
/// [DiveRepository]'s only public constructor is a factory, so this delegates
/// rather than extends, forwarding the handful of methods the notifier calls.
class _FailsAfterFirstPageRepository implements DiveRepository {
  _FailsAfterFirstPageRepository(this._inner);

  final DiveRepository _inner;
  int _calls = 0;

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) async {
    _calls++;
    if (_calls > 1) throw StateError('page load failed');
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
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

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

  group('PaginatedDiveListNotifier page retention on a change tick', () {
    test('keeps every loaded page when the edited dive is saved', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, _pageSize * 2 + 10);

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);

      final loaded = await loadPages(container, 3);
      expect(loaded.dives, hasLength(_pageSize * 2 + 10));
      expect(loaded.hasMore, isFalse);

      // The user edits a dive on the detail pane and saves. The write ticks
      // watchDivesChanges, which must not shrink the list back to page one.
      final edited = dives.first.copyWith(name: 'Edited name');
      await container
          .read(paginatedDiveListProvider.notifier)
          .updateDive(edited);

      // Wait past the change-tick debounce so the silent reload has landed.
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 400),
      );

      final after = container.read(paginatedDiveListProvider).value!;
      expect(
        after.dives,
        hasLength(_pageSize * 2 + 10),
        reason:
            'saving an edit must not discard the pages the user scrolled '
            'through (#1610)',
      );
      expect(
        after.hasMore,
        isFalse,
        reason:
            'the whole list is loaded, so no trailing spinner row may reappear',
      );
      expect(
        after.dives.firstWhere((d) => d.id == edited.id).name,
        'Edited name',
      );
    });

    test(
      'keeps every loaded page when a sync writes a dive directly',
      () async {
        final diver = await setUpCurrentDiver();
        final dives = await seedDives(diver.id, _pageSize * 2 + 10);

        final container = makeContainer();
        addTearDown(container.dispose);
        final sub = container.listen(paginatedDiveListProvider, (_, _) {});
        addTearDown(sub.close);

        final loaded = await loadPages(container, 3);
        expect(loaded.dives, hasLength(_pageSize * 2 + 10));

        // A sync applies a remote change straight to the DB, bypassing the
        // notifier's mutation methods. Only the silent reload can surface it.
        await diveRepo.updateDive(dives.first.copyWith(name: 'Synced name'));

        var names = <String?>[];
        var length = 0;
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final state = container.read(paginatedDiveListProvider).value;
          names = state?.dives.map((d) => d.name).toList() ?? <String?>[];
          length = state?.dives.length ?? 0;
          if (names.contains('Synced name')) break;
        }

        expect(
          names,
          contains('Synced name'),
          reason: 'reload should have run',
        );
        expect(
          length,
          _pageSize * 2 + 10,
          reason:
              'the silent reload must refresh in place, not truncate (#1610)',
        );
      },
    );
  });

  group('PaginatedDiveListNotifier load-more failures', () {
    test('records the failure instead of going quietly idle', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, _pageSize * 2);

      final failing = _FailsAfterFirstPageRepository(diveRepo);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveRepositoryProvider.overrideWithValue(failing),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(paginatedDiveListProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        container.read(paginatedDiveListProvider).value?.dives,
        hasLength(_pageSize),
      );

      await container.read(paginatedDiveListProvider.notifier).loadNextPage();

      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.isLoadingMore, isFalse);
      expect(
        state.loadMoreFailed,
        isTrue,
        reason:
            'a swallowed failure leaves the trailing spinner spinning on '
            'nothing, with no way back except a manual scroll (#1610)',
      );
    });
  });
}
