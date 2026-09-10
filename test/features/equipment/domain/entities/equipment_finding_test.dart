import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';

void main() {
  test('rule ids round-trip and unknown names are null', () {
    expect(ConditionRuleId.cellDivergent.dbValue, 'cellDivergent');
    expect(
      ConditionRuleId.fromDbValue('issueRecurring'),
      ConditionRuleId.issueRecurring,
    );
    expect(ConditionRuleId.fromDbValue('nope'), isNull);
    expect(ConditionRuleId.values, hasLength(10));
  });

  test('severities follow the spec table', () {
    const info = ConditionSeverity.info;
    const caution = ConditionSeverity.caution;
    const significant = ConditionSeverity.significant;
    expect(ConditionRuleId.issueColdCorrelated.severity, info);
    expect(ConditionRuleId.issueDeepCorrelated.severity, info);
    expect(ConditionRuleId.incidentLinked.severity, info);
    expect(ConditionRuleId.cellOutputDeclining.severity, caution);
    expect(ConditionRuleId.cellDivergent.severity, caution);
    expect(ConditionRuleId.transmitterDropoutRising.severity, caution);
    expect(ConditionRuleId.issueRecurring.severity, caution);
    expect(ConditionRuleId.cellOutputLow.severity, significant);
    expect(ConditionRuleId.cellCurrentLimited.severity, significant);
    expect(ConditionRuleId.transmitterDropoutHigh.severity, significant);
    expect(ConditionSeverity.fromDbValue('caution'), caution);
    expect(ConditionSeverity.fromDbValue('bogus'), info);
  });

  test('ids are deterministic per item, rule and slot', () {
    expect(
      conditionFindingId('reg', ConditionRuleId.issueRecurring),
      'cf_reg_issueRecurring',
    );
    expect(
      conditionFindingId('ccr', ConditionRuleId.cellDivergent, slot: 2),
      'cf_ccr_cellDivergent_2',
    );
    expect(
      conditionFindingId(
        'reg',
        ConditionRuleId.issueRecurring,
        tag: 'freeFlow',
      ),
      'cf_reg_issueRecurring_freeFlow',
    );
  });

  test('evidence round-trips through its column shape', () {
    final evidence = FindingEvidence(
      n: 14,
      windowStart: DateTime.utc(2026, 3, 3),
      windowEnd: DateTime.utc(2026, 9, 1),
      diveIds: const ['d1', 'd2'],
      values: const {'recentMedian': 41.2, 'baselineMedian': 52.8},
      tag: 'freeFlow',
      slot: 2,
    );
    final decoded = FindingEvidence.decode(evidence.encode());
    expect(decoded, evidence);
    expect(FindingEvidence.decode('{}'), isNull);
    expect(FindingEvidence.decode('garbage'), isNull);
    expect(FindingEvidence.decode(''), isNull);
  });

  test('the evidence fingerprint ignores dive order and sees values', () {
    final a = FindingEvidence(
      n: 2,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026, 2),
      diveIds: const ['d1', 'd2'],
      values: const {'x': 1.0},
    );
    final b = FindingEvidence(
      n: 2,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026, 2),
      diveIds: const ['d2', 'd1'],
      values: const {'x': 1.0},
    );
    final c = FindingEvidence(
      n: 2,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026, 2),
      diveIds: const ['d1', 'd2'],
      values: const {'x': 2.0},
    );
    expect(evidenceFingerprint(a), evidenceFingerprint(b));
    expect(evidenceFingerprint(a), isNot(evidenceFingerprint(c)));
    expect(evidenceFingerprint(a), hasLength(40));
  });

  test('a finding is a value object with clearDismissedAt', () {
    final evidence = FindingEvidence(
      n: 1,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026),
      diveIds: const ['d1'],
    );
    final f = EquipmentFinding(
      id: 'cf_reg_incidentLinked',
      equipmentId: 'reg',
      ruleId: ConditionRuleId.incidentLinked,
      severity: ConditionSeverity.info,
      value: 1,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      dismissedAt: DateTime.utc(2026, 5),
      createdAt: DateTime.utc(2026, 4),
    );
    expect(f.isDismissed, isTrue);
    expect(f.copyWith(clearDismissedAt: true).isDismissed, isFalse);
    expect(f, f.copyWith());
  });

  group('lenient decoding', () {
    // decode() is documented to return null on anything it cannot read,
    // never to throw: it runs on the sync read path, where a TypeError
    // would take the whole batch down rather than dropping one row.
    test('a non-string tag decodes as no tag', () {
      final decoded = FindingEvidence.decode(
        '{"n":3,"windowStart":0,"windowEnd":1000,"tag":42}',
      );
      expect(decoded, isNotNull);
      expect(decoded!.tag, isNull);
      expect(decoded.n, 3);
    });

    test('a wrong type anywhere else still decodes what it can', () {
      final decoded = FindingEvidence.decode(
        '{"n":3,"windowStart":0,"windowEnd":1000,"diveIds":[1,"d2"],'
        '"values":{"count":"lots","worst":2.5},"slot":"one","tag":{"a":1}}',
      );
      expect(decoded!.diveIds, ['d2']);
      expect(decoded.values, {'worst': 2.5});
      expect(decoded.slot, isNull);
      expect(decoded.tag, isNull);
    });
  });
}
