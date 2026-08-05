import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

import 'safety_review_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16);
  var idCounter = 0;
  String nextId() => 'finding-${idCounter++}';

  setUp(() => idCounter = 0);

  List<SafetyFinding> reviewProfile(
    ({List<double> depths, List<int> timestamps}) profile,
  ) {
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    return const SafetyReviewService().review(
      diveId: 'dive-1',
      analysis: analysis,
      now: now,
      idGenerator: nextId,
    );
  }

  group('rapid ascent rule', () {
    test('clean dive produces no rapid ascent findings', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.rapidAscent),
        isEmpty,
      );
    });

    test('18 m/min ascent produces a significant rapid ascent finding', () {
      final findings = reviewProfile(rapidAscentProfile());
      final rapid = findings
          .where((f) => f.ruleId == SafetyRuleId.rapidAscent)
          .toList();
      expect(rapid, isNotEmpty);
      expect(rapid.first.severity, SafetySeverity.significant);
      expect(rapid.first.value, greaterThan(12));
      expect(rapid.first.startTimestamp, isNotNull);
      expect(rapid.first.endTimestamp, isNotNull);
      expect(rapid.first.engineVersion, SafetyReviewService.engineVersion);
      expect(rapid.first.diveId, 'dive-1');
    });

    test(
      'uses fixed design thresholds, not the diver ascent-rate settings',
      () {
        final profile = rapidAscentProfile();
        // Diver has configured very lax ascent-rate alarms, so the profile
        // analysis itself reports no violation for the 18 m/min ascent.
        final laxAnalysis = analyzeFixture(
          depths: profile.depths,
          timestamps: profile.timestamps,
          ascentRateWarning: 20,
          ascentRateCritical: 25,
        );
        expect(
          laxAnalysis.ascentRateViolations,
          isEmpty,
          reason: 'lax settings should not flag 18 m/min in the analysis',
        );

        // The safety rule re-derives against the fixed 9/12 design thresholds,
        // so the finding is produced regardless of the diver's settings. This
        // keeps the engineVersion re-grading contract honest.
        final findings = const SafetyReviewService().review(
          diveId: 'dive-1',
          analysis: laxAnalysis,
          now: now,
          idGenerator: nextId,
        );
        final rapid = findings
            .where((f) => f.ruleId == SafetyRuleId.rapidAscent)
            .toList();
        expect(rapid, isNotEmpty);
        expect(rapid.first.severity, SafetySeverity.significant);
        expect(rapid.first.value, greaterThan(12));
      },
    );
  });

  group('missed deco stop rule', () {
    test('clean dive produces no missed stop findings', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.missedDecoStop),
        isEmpty,
      );
    });

    test('blowing through deco stops produces a significant finding', () {
      final findings = reviewProfile(missedDecoStopProfile());
      final missed = findings
          .where((f) => f.ruleId == SafetyRuleId.missedDecoStop)
          .toList();
      expect(missed, isNotEmpty);
      expect(missed.first.severity, SafetySeverity.significant);
      expect(missed.first.value, greaterThan(0));
    });
  });

  group('high surface GF rule', () {
    test('clean dive surfaces below GF-high', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.highSurfaceGf),
        isEmpty,
      );
    });

    test('deco violation dive surfaces above GF-high', () {
      final findings = reviewProfile(missedDecoStopProfile());
      final high = findings
          .where((f) => f.ruleId == SafetyRuleId.highSurfaceGf)
          .toList();
      expect(high, isNotEmpty);
      expect(high.first.severity, SafetySeverity.info);
      expect(high.first.value, greaterThan(70)); // fixture GF-high is 70
    });
  });

  group('omitted safety stop rule', () {
    test('dive with a completed safety stop produces no finding', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        isEmpty,
      );
    });

    test('skipping the safety stop on an 18 m dive produces a finding', () {
      final findings = reviewProfile(omittedSafetyStopProfile());
      final omitted = findings
          .where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop)
          .toList();
      expect(omitted, hasLength(1));
      // maxDepth 18 is not > 25, so severity stays info per the spec table.
      expect(omitted.first.severity, SafetySeverity.info);
      expect(omitted.first.value, greaterThan(30));
    });

    test('deco dives are exempt (deco stops supersede the safety stop)', () {
      final findings = reviewProfile(missedDecoStopProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.omittedSafetyStop),
        isEmpty,
      );
    });
  });

  group('sawtooth profile rule', () {
    test('clean dive produces no sawtooth finding', () {
      final findings = reviewProfile(cleanDiveProfile());
      expect(
        findings.where((f) => f.ruleId == SafetyRuleId.sawtoothProfile),
        isEmpty,
      );
    });

    test('three 6 m excursions produce a sawtooth caution', () {
      final findings = reviewProfile(sawtoothProfile());
      final sawtooth = findings
          .where((f) => f.ruleId == SafetyRuleId.sawtoothProfile)
          .toList();
      expect(sawtooth, hasLength(1));
      expect(sawtooth.first.severity, SafetySeverity.caution);
      expect(sawtooth.first.value, greaterThanOrEqualTo(3));
    });
  });
}
