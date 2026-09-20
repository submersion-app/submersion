import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../../helpers/test_database.dart';

/// Statistics, the paginated list, its count and the id query must select
/// the same dives for every derived predicate (the three-path rule).
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> metrics(
    String id, {
    double? slope,
    String stopKind = 'none',
    double? excursion,
    int? stopDuration,
  }) => db
      .into(db.diveDerivedMetricsRows)
      .insert(
        DiveDerivedMetricsRowsCompanion.insert(
          diveId: id,
          engineVersion: 1,
          sourceUpdatedAt: now,
          computedAt: now,
          finalStopKind: Value(stopKind),
          finalStopMaxExcursionM: Value(excursion),
          finalStopDurationS: Value(stopDuration),
          sacSlopeBarMinPerMin: Value(slope),
        ),
      );

  Future<void> buckets(String id, List<double> values) async {
    for (var i = 0; i < values.length; i++) {
      await db
          .into(db.diveSacBuckets)
          .insert(
            DiveSacBucketsCompanion.insert(
              diveId: id,
              bucketIndex: i,
              sacBarMin: values[i],
            ),
          );
    }
  }

  Future<void> finding(String id, SafetyRuleId rule, {int? dismissedAt}) => db
      .into(db.diveSafetyFindings)
      .insert(
        DiveSafetyFindingsCompanion.insert(
          id: '$id-${rule.name}',
          diveId: id,
          ruleId: rule.dbValue,
          severity: 'caution',
          engineVersion: 1,
          createdAt: now,
          dismissedAt: Value(dismissedAt),
        ),
      );

  Future<Set<String>> statsIds(DiveFilterState f) async {
    final q = buildFilteredDiveIdSubquery(f);
    final rows = await db
        .customSelect(
          q.subquery,
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<void> expectParity(
    List<DerivedPredicate> predicates,
    Set<String> expected,
  ) async {
    final f = DiveFilterState(derivedPredicates: predicates);
    expect(await statsIds(f), expected, reason: 'statistics');
    expect(
      (await repo.getDiveSummaries(filter: f)).map((s) => s.id).toSet(),
      expected,
      reason: 'list',
    );
    expect(
      await repo.getDiveCount(filter: f),
      expected.length,
      reason: 'count',
    );
    expect(
      await repo.getDiveIdsMatchingDerived(predicates),
      expected,
      reason: 'id query',
    );
  }

  test('SAC trend', () async {
    await dive('rising');
    await dive('falling');
    await dive('flat');
    await dive('unknown');
    await metrics('rising', slope: 0.5);
    await metrics('falling', slope: -0.5);
    await metrics('flat', slope: 0.001);
    await metrics('unknown');
    await expectParity([const SacTrendIs(SacTrend.rising)], {'rising'});
    await expectParity([const SacTrendIs(SacTrend.falling)], {'falling'});
    await expectParity([const SacTrendIs(SacTrend.flat)], {'flat'});
  });

  test('SAC rose after a mark', () async {
    await dive('rose');
    await dive('steady');
    await dive('short');
    // 20 minutes is bucket 4, so give each dive six.
    await buckets('rose', [0.4, 0.4, 0.4, 0.4, 0.9, 0.9]);
    await buckets('steady', [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    // Ends before the mark: it must not count as a riser.
    await buckets('short', [0.4, 0.4]);
    await expectParity([const SacRoseAfter(minutes: 20)], {'rose'});
  });

  test('final stop stability and duration', () async {
    await dive('wobbly');
    await dive('steady');
    await dive('nostop');
    await metrics(
      'wobbly',
      stopKind: 'safety',
      excursion: 2.4,
      stopDuration: 200,
    );
    await metrics(
      'steady',
      stopKind: 'safety',
      excursion: 0.2,
      stopDuration: 180,
    );
    await metrics('nostop', excursion: 5.0);
    await expectParity([const FinalStopUnstable()], {'wobbly'});
    await expectParity([const FinalStopDuration(minSeconds: 190)], {'wobbly'});
    await expectParity([const FinalStopDuration()], {'wobbly', 'steady'});
  });

  test('safety findings, ignoring dismissed ones', () async {
    await dive('fast');
    await dive('answered');
    await dive('clean');
    await finding('fast', SafetyRuleId.rapidAscent);
    await finding('answered', SafetyRuleId.rapidAscent, dismissedAt: now);
    await expectParity([const HasFinding(SafetyRuleId.rapidAscent)], {'fast'});
  });

  test('several predicates AND together', () async {
    await dive('both');
    await dive('one');
    await metrics('both', slope: 0.5, stopKind: 'safety', excursion: 2.0);
    await metrics('one', slope: 0.5, stopKind: 'safety', excursion: 0.1);
    await expectParity(
      [const SacTrendIs(SacTrend.rising), const FinalStopUnstable()],
      {'both'},
    );
  });

  test(
    'a derived predicate narrows a stored axis rather than replacing it',
    () async {
      await dive('keep');
      await dive('drop');
      await metrics('keep', slope: 0.5);
      await metrics('drop', slope: 0.5);
      await (db.update(db.dives)..where((t) => t.id.equals('drop'))).write(
        const DivesCompanion(maxDepth: Value(10)),
      );
      await (db.update(db.dives)..where((t) => t.id.equals('keep'))).write(
        const DivesCompanion(maxDepth: Value(40)),
      );
      const f = DiveFilterState(
        minDepth: 30,
        derivedPredicates: [SacTrendIs(SacTrend.rising)],
      );
      expect(await statsIds(f), {'keep'});
      expect(
        (await repo.getDiveSummaries(filter: f)).map((s) => s.id).toSet(),
        {'keep'},
      );
      expect(await repo.getDiveCount(filter: f), 1);
    },
  );

  test('an empty predicate list matches nothing in the id query', () async {
    await dive('d1');
    expect(await repo.getDiveIdsMatchingDerived(const []), isEmpty);
  });

  test('apply leaves the axis to SQL', () async {
    // The entity carries no profile, so evaluating this in memory would
    // match nothing at all; callers intersect an id set instead.
    const f = DiveFilterState(derivedPredicates: [FinalStopUnstable()]);
    expect(f.readsDerivedMetrics, isTrue);
    expect(f.hasActiveFilters, isTrue);
    expect(f.apply(const []), isEmpty);
  });

  test('clearing the axis empties it', () {
    const f = DiveFilterState(derivedPredicates: [FinalStopUnstable()]);
    expect(f.copyWith(clearDerivedPredicates: true).derivedPredicates, isEmpty);
    expect(
      f.copyWith(clearDerivedPredicates: true).readsDerivedMetrics,
      isFalse,
    );
    expect(
      f
          .copyWith(derivedPredicates: const [SacTrendIs(SacTrend.falling)])
          .derivedPredicates,
      const [SacTrendIs(SacTrend.falling)],
    );
  });

  test('the derived tick fires on a metrics write alone', () async {
    await dive('d1');
    final ticks = <void>[];
    final sub = repo.watchDerivedMetricsFilterChanges().listen(ticks.add);
    await metrics('d1', slope: 0.1);
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
