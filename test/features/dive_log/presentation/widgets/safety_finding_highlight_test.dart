import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  final now = DateTime.utc(2026, 8, 7);

  SafetyFinding finding({
    SafetySeverity severity = SafetySeverity.caution,
    int? start = 300,
    int? end = 420,
  }) => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: severity,
    startTimestamp: start,
    endTimestamp: end,
    value: 12.0,
    engineVersion: 1,
    createdAt: now,
  );

  group('safetySeverityColor', () {
    test('significant maps to tertiary', () {
      expect(
        safetySeverityColor(SafetySeverity.significant, scheme),
        scheme.tertiary,
      );
    });

    test('info and caution stay neutral', () {
      expect(
        safetySeverityColor(SafetySeverity.info, scheme),
        scheme.onSurfaceVariant,
      );
      expect(
        safetySeverityColor(SafetySeverity.caution, scheme),
        scheme.onSurfaceVariant,
      );
    });
  });

  group('profileHighlightRangeFor', () {
    test('maps a finding to its range and severity color', () {
      final range = profileHighlightRangeFor(
        finding(severity: SafetySeverity.significant),
        scheme,
      );
      expect(range, isNotNull);
      expect(range!.startTimestamp, 300);
      expect(range.endTimestamp, 420);
      expect(range.color, scheme.tertiary);
    });

    test('returns null for a null finding', () {
      expect(profileHighlightRangeFor(null, scheme), isNull);
    });

    test('returns null when the start timestamp is missing', () {
      expect(profileHighlightRangeFor(finding(start: null), scheme), isNull);
      expect(
        profileHighlightRangeFor(finding(start: null, end: null), scheme),
        isNull,
      );
    });

    test('a start-only finding maps to an instant range', () {
      final range = profileHighlightRangeFor(finding(end: null), scheme);
      expect(range, isNotNull);
      expect(range!.startTimestamp, 300);
      expect(range.endTimestamp, 300);
    });
  });

  group('chartSafetyFindings', () {
    SafetyFinding entry(
      String id, {
      int? start,
      SafetyRuleId rule = SafetyRuleId.rapidAscent,
      DateTime? dismissedAt,
    }) {
      return SafetyFinding(
        id: id,
        diveId: 'dive-1',
        ruleId: rule,
        severity: SafetySeverity.caution,
        startTimestamp: start,
        engineVersion: 1,
        dismissedAt: dismissedAt,
        createdAt: now,
      );
    }

    test('filters dismissed, disabled-rule, and timestampless findings', () {
      final review = SafetyReview(
        diveId: 'dive-1',
        engineVersion: 1,
        reviewedAt: now,
        findings: [
          entry('keep', start: 200),
          entry('dismissed', start: 100, dismissedAt: now),
          entry('no-time'),
          entry('disabled', start: 50, rule: SafetyRuleId.sawtoothProfile),
          entry('earlier', start: 10),
        ],
      );
      final result = chartSafetyFindings(review, {
        SafetyRuleId.sawtoothProfile.dbValue,
      });
      expect(result.map((f) => f.id), ['earlier', 'keep']);
    });

    test('null review yields an empty list', () {
      expect(chartSafetyFindings(null, const {}), isEmpty);
    });
  });
}
