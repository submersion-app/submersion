import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain_dive;
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

/// Fails the [failCall]th `getDiveSummaries` call and serves every other one
/// from the real database, standing in for a transient read error while paging.
///
/// [DiveRepository]'s only public constructor is a factory, so this delegates
/// rather than extends, forwarding the handful of methods the notifier calls.
class _FailsOnCallRepository implements DiveRepository {
  _FailsOnCallRepository(this._inner, {required this.failCall});

  final DiveRepository _inner;
  final int failCall;
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
    if (_calls == failCall) throw StateError('page load failed');
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

/// Holds the Nth `getDiveSummaries` call open until the test releases it, so a
/// change tick can be made to land while a page load is genuinely in flight.
class _GatedRepository implements DiveRepository {
  _GatedRepository(this._inner, {required this.gateCall});

  final DiveRepository _inner;
  final int gateCall;
  final Completer<void> gateReached = Completer<void>();
  final Completer<void> release = Completer<void>();
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
    if (_calls == gateCall) {
      if (!gateReached.isCompleted) gateReached.complete();
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
  }) => _inner.getDiveCount(diverId: diverId, filter: filter);

  @override
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

  /// Set to park the first batch-profile fetch, the fire-and-forget tail of
  /// every load, until [releaseProfiles] completes.
  Completer<void>? profileGate;
  final Completer<void> profileGateReached = Completer<void>();

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    final gate = profileGate;
    if (gate != null && !gate.isCompleted) {
      if (!profileGateReached.isCompleted) profileGateReached.complete();
      await gate.future;
    }
    return _inner.getBatchProfileSummaries(diveIds, maxSamples: maxSamples);
  }

  @override
  Future<domain_dive.Dive?> getDiveById(String id) => _inner.getDiveById(id);

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

      // Call 1 is the initial first page; call 2 is the page load that fails.
      final failing = _FailsOnCallRepository(diveRepo, failCall: 2);
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

  group('PaginatedDiveListNotifier paging is serialized', () {
    test('a change tick landing mid page-load keeps both the new page and the '
        'refreshed rows', () async {
      final diver = await setUpCurrentDiver();
      final dives = await seedDives(diver.id, _pageSize * 2);

      // Call 1 is the initial first page; call 2 is the page load this test
      // holds open while a change tick arrives.
      final gated = _GatedRepository(diveRepo, gateCall: 2);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveRepositoryProvider.overrideWithValue(gated),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(paginatedDiveListProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      // Page two is now in flight and parked inside the repository.
      final pageLoad = container
          .read(paginatedDiveListProvider.notifier)
          .loadNextPage();
      await gated.gateReached.future;

      // A sync rewrites a row on page one while that load is parked.
      await diveRepo.updateDive(dives.first.copyWith(name: 'Refreshed name'));
      await Future<void>.delayed(
        DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
      );

      gated.release.complete();
      await pageLoad;

      var names = <String?>[];
      var length = 0;
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final state = container.read(paginatedDiveListProvider).value;
        names = state?.dives.map((d) => d.name).toList() ?? <String?>[];
        length = state?.dives.length ?? 0;
        if (names.contains('Refreshed name') && length == _pageSize * 2) break;
      }

      expect(
        length,
        _pageSize * 2,
        reason: 'the reload must not truncate the page that just landed',
      );
      expect(
        names,
        contains('Refreshed name'),
        reason:
            'the page append must not reinstate rows the reload refreshed '
            '(#1610)',
      );
      expect(
        names.toSet(),
        hasLength(names.length),
        reason: 'no row may appear twice after the two operations interleave',
      );
    });
  });

  group('PaginatedDiveListNotifier reload keeps transient paging flags', () {
    test(
      'a reload landing while a page load is queued keeps the spinner on',
      () async {
        final diver = await setUpCurrentDiver();
        await seedDives(diver.id, _pageSize * 2);

        // Call 1 is the initial first page; call 2 is the reload this test holds
        // open while a page load queues up behind it.
        final gated = _GatedRepository(diveRepo, gateCall: 2);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            diveRepositoryProvider.overrideWithValue(gated),
          ],
        );
        addTearDown(container.dispose);

        final seen = <PaginatedDiveListState>[];
        final sub = container.listen(paginatedDiveListProvider, (_, next) {
          final value = next.value;
          if (value != null) seen.add(value);
        });
        addTearDown(sub.close);

        while (container.read(paginatedDiveListProvider).isLoading) {
          await Future<void>.delayed(Duration.zero);
        }

        // A sync ticks the dives table, parking the reload inside the repository.
        await diveRepo.createDive(
          Dive(
            id: '',
            diverId: diver.id,
            diveNumber: 999,
            dateTime: DateTime(2030),
            name: 'Synced dive',
          ),
        );
        await gated.gateReached.future;

        // The diver reaches the bottom of the list while that reload is parked.
        seen.clear();
        final pageLoad = container
            .read(paginatedDiveListProvider.notifier)
            .loadNextPage();
        gated.release.complete();
        await pageLoad;

        expect(seen, isNotEmpty);
        final beforeThePageLanded = seen
            .takeWhile((s) => s.dives.length <= _pageSize)
            .toList();
        expect(
          beforeThePageLanded.every((s) => s.isLoadingMore),
          isTrue,
          reason:
              'the reload must not blink the spinner off while the page load it '
              'is queued ahead of is still pending (#1610)',
        );
      },
    );

    test(
      'a reload does not clear the retry state of a failed page load',
      () async {
        final diver = await setUpCurrentDiver();
        final dives = await seedDives(diver.id, _pageSize * 2);

        // Call 1 is the initial first page, call 2 the page load that fails;
        // the reload that follows the write below must succeed.
        final failing = _FailsOnCallRepository(diveRepo, failCall: 2);
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
        await container.read(paginatedDiveListProvider.notifier).loadNextPage();
        expect(
          container.read(paginatedDiveListProvider).value!.loadMoreFailed,
          isTrue,
        );

        // A sync refreshes the rows already loaded. That says nothing about
        // whether the NEXT page can be fetched, so the retry row must survive.
        await diveRepo.updateDive(dives.first.copyWith(name: 'Refreshed name'));

        var names = <String?>[];
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names =
              container
                  .read(paginatedDiveListProvider)
                  .value
                  ?.dives
                  .map((d) => d.name)
                  .toList() ??
              <String?>[];
          if (names.contains('Refreshed name')) break;
        }
        expect(
          names,
          contains('Refreshed name'),
          reason: 'reload should have run',
        );

        expect(
          container.read(paginatedDiveListProvider).value!.loadMoreFailed,
          isTrue,
          reason:
              'clearing this swaps the retry row back for a spinner the stranded '
              'loader kick then declines to touch (#1610)',
        );
      },
    );
  });

  group('PaginatedDiveListNotifier disposal', () {
    test('a page load finishing after disposal writes nothing', () async {
      final diver = await setUpCurrentDiver();
      await seedDives(diver.id, _pageSize * 2);

      // Call 1 is the initial first page; call 2 is the page load held open
      // while the provider is invalidated out from under it.
      final gated = _GatedRepository(diveRepo, gateCall: 2);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveRepositoryProvider.overrideWithValue(gated),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(paginatedDiveListProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final pageLoad = container
          .read(paginatedDiveListProvider.notifier)
          .loadNextPage();
      await gated.gateReached.future;

      // An import or a merge invalidates the provider, disposing the notifier
      // while its query is still running.
      container.invalidate(paginatedDiveListProvider);
      gated.release.complete();

      // Writing state on a disposed StateNotifier throws, so this must
      // complete without error rather than surfacing an unhandled exception.
      await expectLater(pageLoad, completes);
    });

    test(
      'the fire-and-forget profile preload survives the container going away',
      () async {
        final diver = await setUpCurrentDiver();
        await seedDives(diver.id, 3);

        // gateCall 0 never matches, so only the profile preload is parked.
        final gated = _GatedRepository(diveRepo, gateCall: 0);
        gated.profileGate = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            diveRepositoryProvider.overrideWithValue(gated),
          ],
        );
        final sub = container.listen(paginatedDiveListProvider, (_, _) {});

        // The first page has landed and its profile preload is parked
        // mid-fetch.
        await gated.profileGateReached.future;

        // The app shuts down while that fetch is parked. Reading a provider
        // from a disposed container throws, and nobody awaits this preload, so
        // the throw would escape into the zone and fail this test.
        //
        // Disposing the container, not just invalidating the provider:
        // invalidation unmounts the notifier but leaves the container
        // readable, so it never throws and cannot tell the guard from its
        // absence.
        sub.close();
        container.dispose();
        gated.profileGate!.complete();

        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
    );
  });
}
