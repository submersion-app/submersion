import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Records which dive reads the dashboard's summary cards make, forwarding
/// each to the real repository.
///
/// [DiveRepository]'s only public constructor is a factory, so this
/// delegates rather than extends, forwarding the methods the providers call.
class _CountingRepository implements DiveRepository {
  _CountingRepository(this._inner);

  final DiveRepository _inner;
  final detailReads = <String>[];
  final sampleFreeReads = <List<String>>[];

  @override
  Stream<void> watchDivesChanges() => _inner.watchDivesChanges();

  @override
  Stream<void> watchDivesChangesWithBuddyLinks() =>
      _inner.watchDivesChangesWithBuddyLinks();

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) => _inner.getDiveSummaries(diverId: diverId, limit: limit);

  @override
  Future<List<String>> getOnThisDayDiveIds({
    required int month,
    required int day,
    required int excludeYear,
    String? diverId,
    int limit = 5,
  }) => _inner.getOnThisDayDiveIds(
    month: month,
    day: day,
    excludeYear: excludeYear,
    diverId: diverId,
    limit: limit,
  );

  @override
  Future<Dive?> getDiveById(String id) {
    detailReads.add(id);
    return _inner.getDiveById(id);
  }

  @override
  Future<List<Dive>> getDivesByIdsWithoutSamples(
    List<String> ids, {
    int chunkSize = 900,
  }) {
    sampleFreeReads.add(ids);
    return _inner.getDivesByIdsWithoutSamples(ids);
  }

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) => _inner.getBatchProfileSummaries(diveIds, maxSamples: maxSamples);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Regression tests for issue #4251: the summary cards on Home hydrated each
/// dive through `getDiveById`, which decodes its merged profile and tank
/// pressure series, to show values the dive row already stores.
void main() {
  late DiveRepository dives;
  late _CountingRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    dives = DiveRepository();
    repo = _CountingRepository(dives);
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('recent dives load in one sample-free read, newest first', () async {
    for (var n = 1; n <= 4; n++) {
      await dives.createDive(
        Dive(id: 'd$n', diveNumber: n, dateTime: DateTime.utc(2026, 3, n, 10)),
      );
    }

    final recent = await makeContainer().read(recentDivesProvider.future);

    expect(recent.map((d) => d.id), ['d4', 'd3', 'd2']);
    expect(repo.detailReads, isEmpty, reason: 'no per-dive detail read');
    expect(repo.sampleFreeReads, [
      ['d4', 'd3', 'd2'],
    ]);
  });

  test('recent dives keep the summary order, not the read order', () async {
    // Same instant: the summary query and the sample-free read each break
    // the tie on their own, so the provider must keep the summary's order.
    final at = DateTime.utc(2026, 3, 1, 10);
    for (final id in ['a', 'b', 'c']) {
      await dives.createDive(Dive(id: id, dateTime: at));
    }
    final summaryOrder = [
      for (final s in await dives.getDiveSummaries(limit: 3)) s.id,
    ];

    final recent = await makeContainer().read(recentDivesProvider.future);

    expect(recent.map((d) => d.id), summaryOrder);
  });

  test('on this day loads its matches in one sample-free read', () async {
    final today = DateTime(2026, 7, 24, 12);
    for (final years in [1, 2, 3]) {
      await dives.createDive(
        Dive(
          id: 'y$years',
          dateTime: DateTime.utc(today.year - years, today.month, today.day),
          maxDepth: 20.0 + years,
          runtime: Duration(minutes: 40 + years),
        ),
      );
    }

    final matches = await withClock(
      Clock.fixed(today),
      () => makeContainer().read(onThisDayProvider.future),
    );

    expect(matches.map((d) => d.id), ['y1', 'y2', 'y3']);
    expect(matches.map((d) => d.maxDepth), [21.0, 22.0, 23.0]);
    expect(matches.map((d) => d.effectiveRuntime), [
      const Duration(minutes: 41),
      const Duration(minutes: 42),
      const Duration(minutes: 43),
    ]);
    expect(repo.detailReads, isEmpty, reason: 'no per-dive detail read');
    expect(repo.sampleFreeReads, [
      ['y1', 'y2', 'y3'],
    ]);
  });
}
