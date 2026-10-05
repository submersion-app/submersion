import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

void main() {
  GasSwitchWindow window(int extra, {int start = 1630}) => GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: start,
    idealDepth: 21,
    switchTimestamp: start + 280,
    switchDepth: 15,
    endTimestamp: start + 280,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: extra,
  );

  List<SafetyFinding> review(GasSwitchEfficiency? efficiency) =>
      const SafetyReviewService()
          .review(
            diveId: 'd1',
            analysis: ProfileAnalysis.empty().copyWith(
              gasSwitchEfficiency: efficiency,
            ),
            now: DateTime.utc(2026, 10, 5),
          )
          .where((f) => f.ruleId == SafetyRuleId.lateGasSwitch)
          .toList();

  test('engine version is 6', () {
    expect(SafetyReviewService.engineVersion, 6);
  });

  test('one finding per window, severity by extra deco', () {
    final findings = review(
      GasSwitchEfficiency(
        evaluated: true,
        windows: [window(120), window(300, start: 2510)],
        totalExtraDecoSeconds: 400,
      ),
    );
    expect(findings, hasLength(2));
    expect(findings[0].severity, SafetySeverity.caution);
    expect(findings[0].startTimestamp, 1630);
    expect(findings[0].endTimestamp, 1910);
    expect(findings[0].value, 120);
    expect(findings[1].severity, SafetySeverity.significant);
  });

  test('a late switch that cost no deco is info, not a caution', () {
    final findings = review(
      GasSwitchEfficiency(evaluated: true, windows: [window(0)]),
    );
    expect(findings.single.severity, SafetySeverity.info);
  });

  test('no efficiency or not evaluated means no finding', () {
    expect(review(null), isEmpty);
    expect(review(GasSwitchEfficiency.notEvaluated), isEmpty);
  });
}
