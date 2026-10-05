import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/safety_rules.dart';

import '../observation_fixtures.dart';

void main() {
  List<ObservationDive> profiled(int n) => [
    for (var k = 0; k < n; k++)
      dive('p$k', daysAgo(10 + k * 30), hasProfile: true),
    dive('noProfile', daysAgo(3)),
  ]..sort((a, b) => a.date.compareTo(b.date));

  test('fires above 9 m/min over 5 profiled dives, banded by whole m/min', () {
    final out = ascentRateRule(
      ObservationInputs(now: now, dives: profiled(5), recentAscentRate: 11.4),
    );
    final f = out.single.facts as RateFacts;
    expect([f.metersPerMin, f.dives], [11.4, 5]);
    expect(out.single.fingerprint, '11');
    expect(out.single.target, const InsightsCategoryTarget('profile'));
  });

  test('silent at or below the guidance, without data, or under 5 dives', () {
    expect(
      ascentRateRule(
        ObservationInputs(now: now, dives: profiled(5), recentAscentRate: 9.0),
      ),
      isEmpty,
    );
    expect(
      ascentRateRule(ObservationInputs(now: now, dives: profiled(5))),
      isEmpty,
    );
    expect(
      ascentRateRule(
        ObservationInputs(now: now, dives: profiled(4), recentAscentRate: 14),
      ),
      isEmpty,
    );
  });
}
