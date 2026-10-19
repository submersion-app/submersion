import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Serves the dive list from the real database, but answers profile batches
/// itself, holding the first one open until [releaseFirstBatch] completes.
///
/// [DiveRepository]'s only public constructor is a factory, so this delegates
/// rather than extends, forwarding the methods the notifier calls.
class _SlowFirstProfileBatchRepository implements DiveRepository {
  _SlowFirstProfileBatchRepository(this._inner);

  final DiveRepository _inner;
  final Completer<void> releaseFirstBatch = Completer<void>();
  final Completer<void> firstBatchStarted = Completer<void>();
  int _batches = 0;

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) => _inner.getDiveSummaries(
    diverId: diverId,
    filter: filter,
    cursor: cursor,
    offset: offset,
    limit: limit,
    sort: sort,
    disabledSafetyRules: disabledSafetyRules,
  );

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
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    if (++_batches == 1) {
      firstBatchStarted.complete();
      await releaseFirstBatch.future;
    }
    return {
      for (final id in diveIds)
        id: const [DiveProfilePoint(timestamp: 0, depth: 10)],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('a page whose profiles land late keeps the next page\'s profiles '
      '(#3506)', () async {
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    final diveRepo = DiveRepository();
    for (var i = 0; i < 60; i++) {
      await diveRepo.createDive(
        Dive(
          id: '',
          diverId: diver.id,
          diveNumber: 60 - i,
          dateTime: DateTime(2024, 1, 1).add(Duration(days: 60 - i)),
        ),
      );
    }
    final repo = _SlowFirstProfileBatchRepository(diveRepo);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diveRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);

    // Page one's profiles are still being summarised...
    await repo.firstBatchStarted.future;
    // ...when the diver scrolls on and page two's profiles land first.
    await container.read(paginatedDiveListProvider.notifier).loadNextPage();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final loaded = container.read(paginatedDiveListProvider).value!.dives;
    expect(loaded, hasLength(60));
    final pageTwo = loaded.skip(50).map((d) => d.id).toSet();
    expect(
      container.read(batchProfileCacheProvider).keys,
      containsAll(pageTwo),
    );

    repo.releaseFirstBatch.complete();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      container.read(batchProfileCacheProvider).keys.toSet(),
      loaded.map((d) => d.id).toSet(),
      reason:
          'the late batch must merge into the cache as it is now, not into '
          'the snapshot it took before awaiting, or page two loses its '
          'sparklines',
    );
  });
}
