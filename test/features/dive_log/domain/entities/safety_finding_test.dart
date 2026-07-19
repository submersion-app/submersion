import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16);

  SafetyFinding base({DateTime? dismissedAt}) => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: SafetySeverity.significant,
    startTimestamp: 100,
    endTimestamp: 140,
    value: 14.2,
    engineVersion: 1,
    dismissedAt: dismissedAt,
    createdAt: now,
  );

  group('SafetyRuleId', () {
    test('dbValue round-trips through fromDbValue', () {
      for (final rule in SafetyRuleId.values) {
        expect(SafetyRuleId.fromDbValue(rule.dbValue), rule);
      }
    });

    test('fromDbValue returns null for an unknown value', () {
      expect(SafetyRuleId.fromDbValue('not-a-rule'), isNull);
    });
  });

  group('SafetySeverity', () {
    test('dbValue round-trips through fromDbValue', () {
      for (final s in SafetySeverity.values) {
        expect(SafetySeverity.fromDbValue(s.dbValue), s);
      }
    });

    test('fromDbValue falls back to info for an unknown value', () {
      expect(SafetySeverity.fromDbValue('bogus'), SafetySeverity.info);
    });
  });

  group('SafetyFinding', () {
    test('isDismissed reflects dismissedAt', () {
      expect(base().isDismissed, isFalse);
      expect(base(dismissedAt: now).isDismissed, isTrue);
    });

    test('copyWith overrides each field', () {
      final updated = base().copyWith(
        id: 'f2',
        diveId: 'dive-2',
        ruleId: SafetyRuleId.sawtoothProfile,
        severity: SafetySeverity.caution,
        startTimestamp: 200,
        endTimestamp: 260,
        value: 3,
        engineVersion: 2,
        dismissedAt: now,
        createdAt: now.add(const Duration(days: 1)),
      );
      expect(updated.id, 'f2');
      expect(updated.diveId, 'dive-2');
      expect(updated.ruleId, SafetyRuleId.sawtoothProfile);
      expect(updated.severity, SafetySeverity.caution);
      expect(updated.startTimestamp, 200);
      expect(updated.endTimestamp, 260);
      expect(updated.value, 3);
      expect(updated.engineVersion, 2);
      expect(updated.dismissedAt, now);
      expect(updated.createdAt, now.add(const Duration(days: 1)));
    });

    test('copyWith with no arguments preserves every field (Equatable)', () {
      expect(base(dismissedAt: now).copyWith(), base(dismissedAt: now));
    });

    test('copyWith(clearDismissedAt: true) removes the dismissal', () {
      final restored = base(dismissedAt: now).copyWith(clearDismissedAt: true);
      expect(restored.dismissedAt, isNull);
      expect(restored.isDismissed, isFalse);
    });

    test('value equality is by props', () {
      expect(base(), base());
      expect(base(), isNot(base(dismissedAt: now)));
    });
  });

  group('SafetyReview', () {
    SafetyReview reviewWith(List<SafetyFinding> findings) => SafetyReview(
      diveId: 'dive-1',
      engineVersion: 1,
      reviewedAt: now,
      findings: findings,
    );

    test('activeFindings excludes dismissed findings', () {
      final active = base();
      final dismissed = base(dismissedAt: now).copyWith(id: 'f2');
      final review = reviewWith([active, dismissed]);
      expect(review.activeFindings, [active]);
    });

    test('value equality is by props', () {
      expect(reviewWith([base()]), reviewWith([base()]));
      expect(reviewWith([base()]), isNot(reviewWith(const [])));
    });
  });
}
