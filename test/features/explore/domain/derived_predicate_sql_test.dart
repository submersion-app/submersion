import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

/// The shape tests next door prove the builder binds its values. These run
/// what it produces against the real schema, because a well-shaped string
/// can still be invalid SQL or select the wrong dives.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertMetrics(
    String diveId, {
    String finalStopKind = 'none',
    int? finalStopDurationS,
    double? finalStopMaxExcursionM,
    double? sacSlope,
  }) => db
      .into(db.diveDerivedMetricsRows)
      .insert(
        DiveDerivedMetricsRowsCompanion.insert(
          diveId: diveId,
          engineVersion: 1,
          sourceUpdatedAt: now,
          computedAt: now,
          finalStopKind: Value(finalStopKind),
          finalStopDurationS: Value(finalStopDurationS),
          finalStopMaxExcursionM: Value(finalStopMaxExcursionM),
          sacSlopeBarMinPerMin: Value(sacSlope),
        ),
      );

  Future<void> insertBuckets(String diveId, Map<int, double> buckets) =>
      db.batch(
        (b) => b.insertAll(db.diveSacBuckets, [
          for (final e in buckets.entries)
            DiveSacBucketsCompanion.insert(
              diveId: diveId,
              bucketIndex: e.key,
              sacBarMin: e.value,
            ),
        ]),
      );

  Future<List<String>> matching(DerivedPredicate p) async {
    final c = derivedPredicateCondition(p, diveIdRef: 'dives.id');
    final rows = await db
        .customSelect(
          'SELECT id FROM dives WHERE ${c.sql} ORDER BY id',
          variables: [for (final v in c.params) Variable(v)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  test('the trend bands select the right dives', () async {
    await insertDive('rising');
    await insertMetrics('rising', sacSlope: 0.09);
    await insertDive('falling');
    await insertMetrics('falling', sacSlope: -0.09);
    await insertDive('flat');
    await insertMetrics('flat', sacSlope: 0.001);
    // No slope at all: a single-bucket dive has no trend, and must not fall
    // into the flat band by default.
    await insertDive('unknown');
    await insertMetrics('unknown');

    expect(await matching(const SacTrendIs(SacTrend.rising)), ['rising']);
    expect(await matching(const SacTrendIs(SacTrend.falling)), ['falling']);
    expect(await matching(const SacTrendIs(SacTrend.flat)), ['flat']);
  });

  test('a dive with no metrics row matches nothing', () async {
    await insertDive('bare');
    expect(await matching(const SacTrendIs(SacTrend.rising)), isEmpty);
    expect(await matching(const FinalStopUnstable()), isEmpty);
    expect(await matching(const FinalStopDuration()), isEmpty);
  });

  test('SAC rose after the mark', () async {
    await insertDive('rose');
    await insertBuckets('rose', {0: 0.4, 1: 0.4, 4: 0.9, 5: 0.9});
    await insertDive('steady');
    await insertBuckets('steady', {0: 0.5, 1: 0.5, 4: 0.5, 5: 0.5});
    await insertDive('fell');
    await insertBuckets('fell', {0: 0.9, 1: 0.9, 4: 0.4, 5: 0.4});

    expect(await matching(const SacRoseAfter(minutes: 20)), ['rose']);
  });

  test('a dive that ended before the mark is not a riser', () async {
    // Only early buckets: the later average is NULL, so the comparison is
    // NULL, which SQL treats as not matching.
    await insertDive('short');
    await insertBuckets('short', {0: 0.4, 1: 0.9});
    expect(await matching(const SacRoseAfter(minutes: 20)), isEmpty);
  });

  test('a dive that started after the mark is not a riser either', () async {
    await insertDive('lateOnly');
    await insertBuckets('lateOnly', {4: 0.9, 5: 0.9});
    expect(await matching(const SacRoseAfter(minutes: 20)), isEmpty);
  });

  test('final stop stability and duration', () async {
    await insertDive('wander');
    await insertMetrics(
      'wander',
      finalStopKind: 'safety',
      finalStopDurationS: 200,
      finalStopMaxExcursionM: 1.8,
    );
    await insertDive('steady');
    await insertMetrics(
      'steady',
      finalStopKind: 'safety',
      finalStopDurationS: 200,
      finalStopMaxExcursionM: 0.2,
    );
    // No stop at all: a large excursion column would be meaningless, and
    // the kind guard is what keeps it out.
    await insertDive('nostop');
    await insertMetrics('nostop', finalStopMaxExcursionM: 9.0);

    expect(await matching(const FinalStopUnstable()), ['wander']);
    expect(await matching(const FinalStopDuration()), ['steady', 'wander']);
    expect(await matching(const FinalStopDuration(minSeconds: 300)), isEmpty);
    expect(
      await matching(const FinalStopDuration(minSeconds: 120, maxSeconds: 300)),
      ['steady', 'wander'],
    );
  });

  test('a dismissed finding stops matching', () async {
    await insertDive('flagged');
    await db
        .into(db.diveSafetyFindings)
        .insert(
          DiveSafetyFindingsCompanion.insert(
            id: 'f1',
            diveId: 'flagged',
            ruleId: SafetyRuleId.rapidAscent.dbValue,
            severity: 'caution',
            engineVersion: 1,
            createdAt: now,
          ),
        );
    expect(await matching(const HasFinding(SafetyRuleId.rapidAscent)), [
      'flagged',
    ]);
    expect(
      await matching(const HasFinding(SafetyRuleId.missedDecoStop)),
      isEmpty,
    );

    await (db.update(db.diveSafetyFindings)..where((t) => t.id.equals('f1')))
        .write(DiveSafetyFindingsCompanion(dismissedAt: Value(now)));
    expect(await matching(const HasFinding(SafetyRuleId.rapidAscent)), isEmpty);
  });

  test('the condition works under a table alias too', () async {
    await insertDive('d1');
    await insertMetrics('d1', sacSlope: 0.09);
    final c = derivedPredicateCondition(
      const SacTrendIs(SacTrend.rising),
      diveIdRef: 'd.id',
    );
    final rows = await db
        .customSelect(
          'SELECT d.id AS id FROM dives d WHERE ${c.sql}',
          variables: [for (final v in c.params) Variable(v)],
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')), ['d1']);
  });
}
