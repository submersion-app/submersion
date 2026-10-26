import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';

/// Counts the notifier's reads, records each profile batch, and can hold the
/// [gateCall]th `getDiveSummaries` call open until [release] completes.
class _CountingRepository implements DiveRepository {
  _CountingRepository(
    this._inner, {
    this.gateCall,
    this.reportedCount,
    this.failCall,
  });

  final DiveRepository _inner;
  final int? gateCall;

  /// When set, the `getDiveSummaries` call that throws, as a failed read does.
  final int? failCall;

  /// When set, the dive count reported in place of the real one, as a count
  /// that lags rows written since does.
  final int? reportedCount;
  final Completer<void> gateReached = Completer<void>();
  final Completer<void> release = Completer<void>();
  int summaryCalls = 0;
  final profileCalls = <List<String>>[];

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
    summaryCalls++;
    if (summaryCalls == failCall) throw StateError('read failed');
    if (summaryCalls == gateCall) {
      gateReached.complete();
      await release.future;
    }
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
  }) async =>
      reportedCount ??
      await _inner.getDiveCount(diverId: diverId, filter: filter);

  @override
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

  @override
  Stream<void> watchDiveListChanges() => _inner.watchDiveListChanges();

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) {
    profileCalls.add(diveIds);
    return _inner.getBatchProfileSummaries(diveIds, maxSamples: maxSamples);
  }

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

  ProviderContainer makeContainer({DiveRepository? repository}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (repository != null)
          diveRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 2000 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(done(), isTrue);
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

  group('PaginatedDiveListNotifier.loadThrough', () {
    test('loads through a far target in one query', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 200);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);

      final target = dives[130];
      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(target.id, targetIndex: 130);

      expect(loaded, isTrue);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives.map((d) => d.id), contains(target.id));
      expect(state.dives.length, greaterThanOrEqualTo(131));
      expect(state.hasMore, isTrue);
    });

    test(
      'dropping on the last dive loads everything and ends paging',
      () async {
        final diver = await setUpCurrentDiver();
        final dives = await seedDives(diver.id, 260);
        final container = makeContainer();
        addTearDown(container.dispose);
        final sub = container.listen(paginatedDiveListProvider, (_, _) {});
        addTearDown(sub.close);
        await loadPages(container, 1);

        final loaded = await container
            .read(paginatedDiveListProvider.notifier)
            .loadThrough(dives.last.id, targetIndex: 259);

        expect(loaded, isTrue);
        final state = container.read(paginatedDiveListProvider).value!;
        expect(state.dives, hasLength(260));
        expect(state.hasMore, isFalse);
        expect(state.isLoadingMore, isFalse);
      },
    );

    test('reports false and keeps the rows when the target is gone', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, 120);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await loadPages(container, 1);

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough('no-such-dive', targetIndex: 90);

      expect(loaded, isFalse);
      final after = container.read(paginatedDiveListProvider).value!;
      expect(after.dives.take(before.dives.length), before.dives);
    });

    test('revision bumps on reloads, not on page loads', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 120);
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      final first = await loadPages(container, 1);
      expect(first.revision, greaterThan(0));

      final notifier = container.read(paginatedDiveListProvider.notifier);
      await notifier.loadNextPage();
      expect(
        container.read(paginatedDiveListProvider).value!.revision,
        first.revision,
      );

      await notifier.loadThrough(dives[110].id, targetIndex: 110);
      expect(
        container.read(paginatedDiveListProvider).value!.revision,
        first.revision,
      );

      await notifier.reloadLoadedPages();
      expect(
        container.read(paginatedDiveListProvider).value!.revision,
        greaterThan(first.revision),
      );
    });

    test('a large load reads the rows in exactly one query', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 400);
      final repo = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);
      final before = repo.summaryCalls;

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadThrough(dives[380].id, targetIndex: 380);

      expect(loaded, isTrue);
      expect(repo.summaryCalls - before, 1);
    });

    test(
      'a large load preloads one window of profiles at its target',
      () async {
        final diver = await setUpCurrentDiver();
        final dives = await seedDives(diver.id, 400);
        final repo = _CountingRepository(diveRepo);
        final container = makeContainer(repository: repo);
        addTearDown(container.dispose);
        final sub = container.listen(paginatedDiveListProvider, (_, _) {});
        addTearDown(sub.close);
        await loadPages(container, 1);
        await until(() => repo.profileCalls.isNotEmpty);
        repo.profileCalls.clear();

        final target = dives[380];
        await container
            .read(paginatedDiveListProvider.notifier)
            .loadThrough(target.id, targetIndex: 380);
        final loaded = container.read(paginatedDiveListProvider).value!.dives;
        await until(() => repo.profileCalls.isNotEmpty);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        final window = loaded
            .skip(loaded.length - 100)
            .map((d) => d.id)
            .toSet();
        expect(repo.profileCalls, hasLength(1));
        expect(repo.profileCalls.single.toSet(), window);
        expect(window, contains(target.id));
        expect(window, containsAll(dives.sublist(360, 400).map((d) => d.id)));
      },
    );

    test('a silent reload after it skips the rows it jumped over', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 400);
      final repo = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);
      final notifier = container.read(paginatedDiveListProvider.notifier);
      await notifier.loadThrough(dives[380].id, targetIndex: 380);
      final loaded = container.read(paginatedDiveListProvider).value!.dives;
      final jumpedOver = loaded
          .skip(50)
          .take(loaded.length - 50 - 100)
          .map((d) => d.id)
          .toSet();
      expect(jumpedOver, isNotEmpty);
      await until(() => repo.profileCalls.isNotEmpty);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      repo.profileCalls.clear();

      await notifier.reloadLoadedPages();
      await until(() => repo.profileCalls.isNotEmpty);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final requested = {for (final call in repo.profileCalls) ...call};
      expect(requested.intersection(jumpedOver), isEmpty);
      expect(requested, contains(dives[380].id));
      expect(requested, contains(dives.first.id));
    });

    test('a page load queued during it keeps its spinner', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 200);
      final repo = _CountingRepository(diveRepo, gateCall: 2);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final target = dives[130];
      bool? spinnerWhenApplied;
      final sub = container.listen(paginatedDiveListProvider, (_, next) {
        final state = next.valueOrNull;
        if (spinnerWhenApplied == null &&
            state != null &&
            state.dives.any((d) => d.id == target.id)) {
          spinnerWhenApplied = state.isLoadingMore;
        }
      });
      addTearDown(sub.close);
      await loadPages(container, 1);
      final notifier = container.read(paginatedDiveListProvider.notifier);

      final through = notifier.loadThrough(target.id, targetIndex: 130);
      await repo.gateReached.future;
      final page = notifier.loadNextPage();
      expect(
        container.read(paginatedDiveListProvider).value!.isLoadingMore,
        isTrue,
      );
      repo.release.complete();
      await through;
      await page;

      expect(spinnerWhenApplied, isTrue);
      expect(
        container.read(paginatedDiveListProvider).value!.isLoadingMore,
        isFalse,
      );
    });
  });

  // End in the dive list reaches the last dive, not the last loaded one
  // (#3302).
  group('PaginatedDiveListNotifier.loadRest', () {
    test('loads every remaining dive in one query and ends paging', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 260);
      final repo = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);
      final before = repo.summaryCalls;

      await container.read(paginatedDiveListProvider.notifier).loadRest();

      final state = container.read(paginatedDiveListProvider).value!;
      expect(repo.summaryCalls - before, 1);
      expect(state.dives, hasLength(260));
      expect(state.dives.last.id, dives.last.id);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test('still reaches the last dive when the count lags behind', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, 260);
      final repo = _CountingRepository(diveRepo, reportedCount: 60);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);

      await container.read(paginatedDiveListProvider.notifier).loadRest();

      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives, hasLength(260));
      expect(state.dives.last.id, dives.last.id);
      expect(state.hasMore, isFalse);
    });

    test('logs a failed read and leaves the retry to the list', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, 120);
      final repo = _CountingRepository(diveRepo, failCall: 2);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);
      final errors = <LogEntry>[];
      final logs = LoggerService.logStream
          .where((entry) => entry.level == LogLevel.error)
          .listen(errors.add);
      addTearDown(logs.cancel);

      await container.read(paginatedDiveListProvider.notifier).loadRest();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.loadMoreFailed, isTrue);
      expect(state.dives, hasLength(50));
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('read failed'));
    });

    test('reads nothing when every dive is already loaded', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, 30);
      final repo = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repo);
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);
      await loadPages(container, 1);
      final before = repo.summaryCalls;

      await container.read(paginatedDiveListProvider.notifier).loadRest();

      expect(repo.summaryCalls, before);
      expect(
        container.read(paginatedDiveListProvider).value!.dives,
        hasLength(30),
      );
    });
  });
}
