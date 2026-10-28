import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Counts the notifier's row reads.
class _CountingRepository implements DiveRepository {
  _CountingRepository(this._inner, {this.gateCall});

  final DiveRepository _inner;

  /// When set, the `getDiveSummaries` call held open until [release].
  final int? gateCall;
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
  }) => _inner.getDiveCount(diverId: diverId, filter: filter);

  @override
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

  @override
  Stream<void> watchDiveListChanges() => _inner.watchDiveListChanges();

  @override
  Stream<void> watchTables(Set<String> tableNames) =>
      _inner.watchTables(tableNames);

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
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (repository != null)
          diveRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  Future<String> setUpCurrentDiver() async {
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
    return diver.id;
  }

  /// Creates [count] dives, newest first, so the default date sort is
  /// stable. Every tenth one's notes mention a reef, for a text filter.
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
            notes: i % 10 == 0 ? 'reef' : '',
          ),
        ),
      );
    }
    return created;
  }

  Future<PaginatedDiveListState> firstPage(ProviderContainer container) async {
    while (container.read(paginatedDiveListProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(paginatedDiveListProvider).value!;
  }

  group('PaginatedDiveListNotifier.loadUntil (#3744)', () {
    test('pages a far dive in, a few reads rather than a page each', () async {
      final diverId = await setUpCurrentDiver();
      final dives = await seedDives(diverId, 700);
      final repository = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repository);
      await firstPage(container);
      final readsBefore = repository.summaryCalls;

      final target = dives[600];
      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadUntil(target.id);

      expect(loaded, isTrue);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives.map((d) => d.id), contains(target.id));
      // Fifty at a time would take twelve more reads; doubling takes four.
      expect(repository.summaryCalls - readsBefore, lessThanOrEqualTo(4));
    });

    test(
      'preloads profiles around the dive, not only a read\'s tail',
      () async {
        final diverId = await setUpCurrentDiver();
        final dives = await seedDives(diverId, 700);
        final repository = _CountingRepository(diveRepo);
        final container = makeContainer(repository: repository);
        await firstPage(container);

        // Row 210 arrives in a read of rows 200 to 399, whose last hundred
        // rows are the ones a read preloads.
        final target = dives[210];
        await container
            .read(paginatedDiveListProvider.notifier)
            .loadUntil(target.id);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          repository.profileCalls.any((ids) => ids.contains(target.id)),
          isTrue,
        );
      },
    );

    test('stops paging once the query changes under it', () async {
      final diverId = await setUpCurrentDiver();
      final dives = await seedDives(diverId, 700);
      // The first page is read 1; loadUntil's second read is read 3.
      final repository = _CountingRepository(diveRepo, gateCall: 3);
      final container = makeContainer(repository: repository);
      await firstPage(container);

      final loading = container
          .read(paginatedDiveListProvider.notifier)
          .loadUntil(dives[600].id);
      await repository.gateReached.future;
      container.read(diveFilterProvider.notifier).state = DiveFilterState(
        query: TextNode(['reef']),
      );
      repository.release.complete();

      expect(await loading, isFalse);
      // Settles on the new query's reload, its own one read, rather than
      // paging the new query on from the old one's cursor first.
      final reloaded = await firstPage(container);
      while (container
              .read(paginatedDiveListProvider)
              .value!
              .unfilteredTotalCount ==
          null) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(repository.summaryCalls, 4);
      expect(reloaded.dives, isNotEmpty);
    });

    test('a dive already loaded is a no-op', () async {
      final diverId = await setUpCurrentDiver();
      final dives = await seedDives(diverId, 120);
      final repository = _CountingRepository(diveRepo);
      final container = makeContainer(repository: repository);
      await firstPage(container);
      final readsBefore = repository.summaryCalls;

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadUntil(dives[3].id);

      expect(loaded, isTrue);
      expect(repository.summaryCalls, readsBefore);
    });

    test('runs behind a filter cleared just before it', () async {
      final diverId = await setUpCurrentDiver();
      final dives = await seedDives(diverId, 300);
      final container = makeContainer();
      container.read(diveFilterProvider.notifier).state = DiveFilterState(
        query: TextNode(['reef']),
      );
      final filtered = await firstPage(container);
      expect(filtered.dives, hasLength(30));

      // A dive the filter hides, asked for in the same breath as the clear.
      final target = dives[255];
      container.read(diveFilterProvider.notifier).state =
          const DiveFilterState();
      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadUntil(target.id);

      expect(loaded, isTrue);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.unfilteredTotalCount, isNull);
      expect(state.dives.map((d) => d.id), contains(target.id));
      expect(state.dives.first.id, dives.first.id);
    });

    test('reports false once the list runs out without the dive', () async {
      final diverId = await setUpCurrentDiver();
      await seedDives(diverId, 120);
      final container = makeContainer();
      await firstPage(container);

      final loaded = await container
          .read(paginatedDiveListProvider.notifier)
          .loadUntil('no-such-dive');

      expect(loaded, isFalse);
      final state = container.read(paginatedDiveListProvider).value!;
      expect(state.dives, hasLength(120));
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });
  });
}
