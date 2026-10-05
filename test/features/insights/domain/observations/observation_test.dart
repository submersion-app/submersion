import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

void main() {
  group('ObservationRuleId', () {
    test('dbValue round-trips and unknown ids are null', () {
      for (final rule in ObservationRuleId.values) {
        expect(ObservationRuleId.fromDbValue(rule.dbValue), rule);
      }
      expect(ObservationRuleId.fromDbValue('fromANewerBuild'), isNull);
    });

    test('kinds follow the spec catalog', () {
      expect(ObservationRuleId.ascentRate.kind, ObservationKind.safety);
      expect(ObservationRuleId.rmvTrend.kind, ObservationKind.trend);
      expect(ObservationRuleId.frequencyTrend.kind, ObservationKind.trend);
      expect(ObservationRuleId.newSpecies.kind, ObservationKind.milestone);
      expect(ObservationRuleId.busiestMonth.kind, ObservationKind.pattern);
      final byKind = <ObservationKind, int>{};
      for (final r in ObservationRuleId.values) {
        byKind.update(r.kind, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(byKind, {
        ObservationKind.safety: 1,
        ObservationKind.milestone: 6,
        ObservationKind.trend: 5,
        ObservationKind.pattern: 4,
      });
    });
  });

  group('TrendFacts', () {
    test('direction and signed percent change', () {
      const down = TrendFacts(
        recent: 15,
        previous: 20,
        recentDives: 9,
        previousDives: 9,
      );
      expect(down.direction, TrendDirection.down);
      expect(down.percentChange, closeTo(-25, 1e-9));
      const fromZero = TrendFacts(
        recent: 3,
        previous: 0,
        recentDives: 9,
        previousDives: 9,
      );
      expect(fromZero.percentChange, 0);
    });
  });

  group('identity', () {
    test('key and dismissal id are deterministic', () {
      const o = Observation(
        ruleId: ObservationRuleId.rmvTrend,
        fingerprint: 'down:1',
        score: 0.8,
        facts: TrendFacts(
          recent: 15,
          previous: 20,
          recentDives: 9,
          previousDives: 9,
        ),
        target: InsightsCategoryTarget('gas'),
      );
      expect(o.key, 'rmvTrend:down:1');
      expect(o.kind, ObservationKind.trend);
      final a = observationDismissalId('diver-1', o.ruleId, o.fingerprint);
      final b = observationDismissalId('diver-1', o.ruleId, o.fingerprint);
      expect(a, b);
      expect(a, startsWith('od_'));
      expect(a.length, 3 + 40);
      expect(
        observationDismissalId('diver-2', o.ruleId, o.fingerprint),
        isNot(a),
      );
      expect(o.copyWith(score: 2).score, 2);
      expect(o.copyWith(score: 2).key, o.key);
    });
  });
}
