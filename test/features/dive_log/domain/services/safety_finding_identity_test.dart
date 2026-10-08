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
      (ruleId: 'a', start: 1, end: 2, value: null, severity: null),
      (ruleId: 'a', start: 1, end: 2, value: null, severity: null),
      (ruleId: 'a', start: 3, end: 4, value: null, severity: null),
    ]);
    expect(keys, [('a', 1, 2, 0), ('a', 1, 2, 1), ('a', 3, 4, 0)]);
  });

  test('repeats of a span are numbered by value, not by input order', () {
    // Stored rows and the engine's output arrive in different orders; the
    // same finding must get the same ordinal from either side.
    final forward = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2, value: 20.0, severity: null),
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: null),
    ]);
    final reversed = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: null),
      (ruleId: 'a', start: 1, end: 2, value: 20.0, severity: null),
    ]);
    expect(forward, [('a', 1, 2, 1), ('a', 1, 2, 0)]);
    expect(reversed, [('a', 1, 2, 0), ('a', 1, 2, 1)]);
  });

  test('equal values are told apart by severity, not by input order', () {
    final forward = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: 'significant'),
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: 'caution'),
    ]);
    final reversed = safetyFindingKeys([
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: 'caution'),
      (ruleId: 'a', start: 1, end: 2, value: 10.0, severity: 'significant'),
    ]);
    expect(forward, [('a', 1, 2, 1), ('a', 1, 2, 0)]);
    expect(reversed, [('a', 1, 2, 0), ('a', 1, 2, 1)]);
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
