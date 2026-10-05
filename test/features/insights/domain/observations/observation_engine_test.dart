import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_engine.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

import 'observation_fixtures.dart';

Observation obs(ObservationRuleId rule, double score, [String fp = 'x']) =>
    Observation(
      ruleId: rule,
      fingerprint: fp,
      score: score,
      facts: const MonthFacts(month: 1, years: 2),
      target: const DiveLogTarget(),
    );

void main() {
  final inputs = ObservationInputs(now: now);

  test('the registry covers every rule id', () {
    expect(observationRules.keys.toSet(), ObservationRuleId.values.toSet());
  });

  test('an empty log produces nothing and nothing throws', () {
    final errors = <ObservationRuleId>[];
    expect(
      runObservationRules(
        inputs,
        onRuleError: (rule, _, _) => errors.add(rule),
      ),
      isEmpty,
    );
    expect(errors, isEmpty);
  });

  test('muted rules and dismissed keys are dropped', () {
    final out = runObservationRules(
      inputs,
      rules: {
        ObservationRuleId.diveGap: (_) => [obs(ObservationRuleId.diveGap, 1)],
        ObservationRuleId.busiestMonth: (_) => [
          obs(ObservationRuleId.busiestMonth, 1, 'a'),
          obs(ObservationRuleId.busiestMonth, 1, 'b'),
        ],
        ObservationRuleId.rmvTrend: (_) => [obs(ObservationRuleId.rmvTrend, 1)],
      },
      mutedRuleIds: {'diveGap', 'fromANewerBuild'},
      dismissedKeys: {'busiestMonth:a'},
    );
    expect(out.map((o) => o.key), ['rmvTrend:x', 'busiestMonth:b']);
  });

  test('a throwing rule is reported and the rest survive', () {
    final errors = <ObservationRuleId>[];
    final out = runObservationRules(
      inputs,
      rules: {
        ObservationRuleId.diveGap: (_) => throw StateError('boom'),
        ObservationRuleId.rmvTrend: (_) => [obs(ObservationRuleId.rmvTrend, 1)],
      },
      onRuleError: (rule, _, _) => errors.add(rule),
    );
    expect(errors, [ObservationRuleId.diveGap]);
    expect(out, hasLength(1));
  });

  test('ranking: tier, then score, then rule order, then fingerprint', () {
    final ranked = [
      obs(ObservationRuleId.diveGap, 9),
      obs(ObservationRuleId.rmvTrend, 0.6),
      obs(ObservationRuleId.maxDepthTrend, 0.9),
      obs(ObservationRuleId.newCountry, 0.5, 'b'),
      obs(ObservationRuleId.newCountry, 0.5, 'a'),
      obs(ObservationRuleId.ascentRate, 11),
    ]..sort(compareObservations);
    expect(ranked.map((o) => o.key), [
      'ascentRate:x',
      'newCountry:a',
      'newCountry:b',
      'maxDepthTrend:x',
      'rmvTrend:x',
      'diveGap:x',
    ]);
  });

  test('strip: three items, at most two per kind', () {
    final ranked = [
      obs(ObservationRuleId.deepestDive, 1),
      obs(ObservationRuleId.newCountry, 0.9),
      obs(ObservationRuleId.newSpecies, 0.8),
      obs(ObservationRuleId.rmvTrend, 2),
      obs(ObservationRuleId.diveGap, 1),
    ];
    expect(selectStrip(ranked).map((o) => o.ruleId), [
      ObservationRuleId.deepestDive,
      ObservationRuleId.newCountry,
      ObservationRuleId.rmvTrend,
    ]);
    expect(selectStrip(const []), isEmpty);
  });
}
