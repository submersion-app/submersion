import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

/// Issue #4530: isobaric counterdiffusion raises a safety finding, from the
/// tissue model and from gas switches that break the rule of fifths.
void main() {
  List<SafetyFinding> review(CounterdiffusionAnalysis counterdiffusion) =>
      const SafetyReviewService()
          .review(
            diveId: 'd1',
            analysis: ProfileAnalysis.empty().copyWith(
              counterdiffusion: counterdiffusion,
            ),
            now: DateTime.utc(2026, 11, 14),
          )
          .where((f) => f.ruleId == SafetyRuleId.isobaricCounterdiffusion)
          .toList();

  IcdSwitchMarker marker(int time, IcdSeverity severity) => IcdSwitchMarker(
    timestamp: time,
    severity: severity,
    from: const GasMix(o2: 18, he: 45),
    to: const GasMix(o2: 50),
  );

  test('each ICD range is a caution over its span', () {
    final findings = review(
      const CounterdiffusionAnalysis(
        heliumPresent: true,
        icdRanges: [
          CounterdiffusionRange(
            startSeconds: 600,
            endSeconds: 780,
            kind: CounterdiffusionKind.netOngassing,
            compartmentNumbers: [4, 5],
          ),
        ],
      ),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, SafetySeverity.caution);
    expect(findings.single.startTimestamp, 600);
    expect(findings.single.endTimestamp, 780);
  });

  test('a rule-of-fifths violation is a caution at the switch instant', () {
    final findings = review(
      CounterdiffusionAnalysis(
        heliumPresent: true,
        switchMarkers: [marker(1910, IcdSeverity.violation)],
      ),
    );

    expect(findings.single.startTimestamp, 1910);
    expect(findings.single.endTimestamp, 1910);
    expect(findings.single.severity, SafetySeverity.caution);
  });

  test('cautions at switches and opposing phases raise no finding', () {
    final findings = review(
      CounterdiffusionAnalysis(
        heliumPresent: true,
        switchMarkers: [marker(1910, IcdSeverity.caution)],
        opposingRanges: const [
          CounterdiffusionRange(
            startSeconds: 1910,
            endSeconds: 3000,
            kind: CounterdiffusionKind.opposing,
            compartmentNumbers: [1, 2, 3],
          ),
        ],
      ),
    );

    expect(findings, isEmpty);
  });

  test('no counterdiffusion, no finding', () {
    expect(review(CounterdiffusionAnalysis.none), isEmpty);
  });

  test('the rule round-trips through its stored value', () {
    expect(
      SafetyRuleId.fromDbValue(SafetyRuleId.isobaricCounterdiffusion.dbValue),
      SafetyRuleId.isobaricCounterdiffusion,
    );
  });
}
