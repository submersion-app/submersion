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
  });
}
