import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_finding_identity.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26);
  SafetyFinding f(String id, {int? start = 100, int? end = 140}) =>
      SafetyFinding(
        id: id,
        diveId: 'dive-1',
        ruleId: SafetyRuleId.rapidAscent,
        severity: SafetySeverity.caution,
        startTimestamp: start,
        endTimestamp: end,
        value: 12,
        engineVersion: 2,
        createdAt: now,
      );

  test('keys number repeats of the same span in order', () {
    final keys = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2),
      (ruleId: 'a', start: 1, end: 2),
      (ruleId: 'a', start: 3, end: 4),
    ]);
    expect(keys, [('a', 1, 2, 0), ('a', 1, 2, 1), ('a', 3, 4, 0)]);
  });

  test('the same finding gets the same id on every device', () {
    final a = withDeterministicIds('dive-1', [f('x')]);
    final b = withDeterministicIds('dive-1', [f('y')]);
    expect(a.single.id, b.single.id);
    expect(a.single.id, isNot('x'));
  });

  test('different dives, spans and repeats get different ids', () {
    final ids = {
      safetyFindingId('dive-1', ('rapidAscent', 100, 140, 0)),
      safetyFindingId('dive-2', ('rapidAscent', 100, 140, 0)),
      safetyFindingId('dive-1', ('rapidAscent', 100, 141, 0)),
      safetyFindingId('dive-1', ('rapidAscent', 100, 140, 1)),
      safetyFindingId('dive-1', ('rapidAscent', null, null, 0)),
    };
    expect(ids, hasLength(5));
  });

  test('repeats of one span get distinct ids', () {
    final ids = withDeterministicIds('dive-1', [
      f('a'),
      f('b'),
    ]).map((x) => x.id);
    expect(ids.toSet(), hasLength(2));
  });
}
