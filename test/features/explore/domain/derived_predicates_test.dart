import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  test('predicates compare by value, so a family key caches', () {
    expect(
      const SacTrendIs(SacTrend.rising),
      const SacTrendIs(SacTrend.rising),
    );
    expect(const SacRoseAfter(minutes: 20), const SacRoseAfter(minutes: 20));
    expect(
      const SacRoseAfter(minutes: 20),
      isNot(const SacRoseAfter(minutes: 30)),
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]).hashCode,
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]).hashCode,
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
      isNot(const DerivedConditionsKey([SacTrendIs(SacTrend.falling)])),
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
      isNot(const DerivedConditionsKey([])),
    );
  });

  test('every predicate binds its values rather than inlining them', () {
    final predicates = <DerivedPredicate>[
      const SacTrendIs(SacTrend.rising),
      const SacRoseAfter(minutes: 20),
      const FinalStopUnstable(),
      const FinalStopDuration(minSeconds: 120),
      const HasFinding(SafetyRuleId.rapidAscent),
    ];
    for (final p in predicates) {
      final c = derivedPredicateCondition(p, diveIdRef: 'dives.id');
      expect(c.sql, contains('dives.id'), reason: '$p');
      expect(c.sql, contains('?'), reason: '$p');
      expect(c.params, isNotEmpty, reason: '$p');
      // A bound value must never be spliced into the text.
      expect(c.sql, isNot(contains('20')), reason: '$p');
    }
  });

  test('the trend bands are expressed as an explicit range', () {
    final flat = derivedPredicateCondition(
      const SacTrendIs(SacTrend.flat),
      diveIdRef: 'd.id',
    );
    expect(flat.sql, contains('BETWEEN'));
    expect(flat.params, hasLength(2));
    expect(flat.params, [-0.02, 0.02]);

    final rising = derivedPredicateCondition(
      const SacTrendIs(SacTrend.rising),
      diveIdRef: 'd.id',
    );
    expect(rising.sql, contains('>'));
    expect(rising.params, [0.02]);

    final falling = derivedPredicateCondition(
      const SacTrendIs(SacTrend.falling),
      diveIdRef: 'd.id',
    );
    expect(falling.sql, contains('<'));
    expect(falling.params, [-0.02]);
  });

  test('a dismissed finding does not count', () {
    final c = derivedPredicateCondition(
      const HasFinding(SafetyRuleId.omittedSafetyStop),
      diveIdRef: 'd.id',
    );
    expect(c.sql, contains('dismissed_at IS NULL'));
    expect(c.params, ['omittedSafetyStop']);
  });

  test('an unbounded duration binds only the bound that is set', () {
    final minOnly = derivedPredicateCondition(
      const FinalStopDuration(minSeconds: 120),
      diveIdRef: 'd.id',
    );
    expect(minOnly.params, [120]);
    final both = derivedPredicateCondition(
      const FinalStopDuration(minSeconds: 120, maxSeconds: 300),
      diveIdRef: 'd.id',
    );
    expect(both.params, [120, 300]);
    final neither = derivedPredicateCondition(
      const FinalStopDuration(),
      diveIdRef: 'd.id',
    );
    expect(neither.params, isEmpty);
    // With no bound set it still means "the dive had a final stop".
    expect(neither.sql, contains('final_stop_duration_s IS NOT NULL'));
  });

  test('the rise mark is converted to a bucket index, not minutes', () {
    final c = derivedPredicateCondition(
      const SacRoseAfter(minutes: 20),
      diveIdRef: 'd.id',
    );
    // 20 minutes is 1200 s, which is bucket 4 at kSacBucketSeconds = 300.
    expect(c.params.first, 20 * 60 ~/ kSacBucketSeconds);
    expect(c.params, [4, 1.1, 4]);
  });
}
