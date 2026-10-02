import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

class _NoDiverNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _NoDiverNotifier() : super(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInsightsRepository extends InsightsRepository {
  final yearsAsked = <int>[];

  @override
  Stream<void> watchInsightsChanges() => const Stream.empty();

  @override
  Future<YearStats> getYearStats(int year, {String? diverId}) async {
    yearsAsked.add(year);
    return const YearStats(diveCount: 1, totalSeconds: 60);
  }
}

class _FakeDiveRepository implements DiveRepository {
  var statisticsCalls = 0;
  final onThisDayAsked = <(int, int)>[];

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Stream<void> watchTables(Set<String> tableNames) => const Stream.empty();

  @override
  Future<DiveStatistics> getStatistics({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    statisticsCalls++;
    return DiveStatistics(
      totalDives: 0,
      totalTimeSeconds: 0,
      maxDepth: 0,
      avgMaxDepth: 0,
      totalSites: 0,
    );
  }

  @override
  Future<List<String>> getOnThisDayDiveIds({
    required int month,
    required int day,
    required int excludeYear,
    String? diverId,
    int limit = 5,
  }) async {
    onThisDayAsked.add((month, day));
    return const [];
  }

  @override
  Future<Dive?> getDiveById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Providers that read "today" or "this year" from the clock rebuild when the
/// local date changes, not only when the data does. Without that an app left
/// open across New Year kept showing last year's "Dives This Year" (#2600)
/// and year-in-review, and "on this day" kept yesterday's date.
void main() {
  late _FakeInsightsRepository insights;
  late _FakeDiveRepository dives;

  ProviderContainer container() {
    insights = _FakeInsightsRepository();
    dives = _FakeDiveRepository();
    return ProviderContainer(
      overrides: [
        insightsRepositoryProvider.overrideWithValue(insights),
        diveRepositoryProvider.overrideWithValue(dives),
        currentDiverIdProvider.overrideWith((ref) => _NoDiverNotifier()),
      ],
    );
  }

  test('year in review asks for the new year after New Year', () {
    fakeAsync((async) {
      final c = container();
      c.listen(yearInReviewProvider, (_, _) {});
      async.flushMicrotasks();
      expect(insights.yearsAsked, [2026, 2025]);

      async.elapse(const Duration(hours: 2));
      async.flushMicrotasks();

      expect(insights.yearsAsked, [2026, 2025, 2027, 2026]);
      c.dispose();
    }, initialTime: DateTime(2026, 12, 31, 23));
  });

  test('on this day asks for the new date after midnight', () {
    fakeAsync((async) {
      final c = container();
      c.listen(onThisDayProvider, (_, _) {});
      async.flushMicrotasks();
      expect(dives.onThisDayAsked, [(7, 15)]);

      async.elapse(const Duration(hours: 2));
      async.flushMicrotasks();

      expect(dives.onThisDayAsked, [(7, 15), (7, 16)]);
      c.dispose();
    }, initialTime: DateTime(2026, 7, 15, 23));
  });

  test('both statistics providers re-query after midnight', () {
    fakeAsync((async) {
      final c = container();
      c.listen(diveStatisticsProvider, (_, _) {});
      c.listen(filteredDiveStatisticsProvider, (_, _) {});
      async.flushMicrotasks();
      expect(dives.statisticsCalls, 2);

      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(dives.statisticsCalls, 2, reason: 'still Dec 31');

      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(dives.statisticsCalls, 4);
      c.dispose();
    }, initialTime: DateTime(2026, 12, 31, 23));
  });
}
