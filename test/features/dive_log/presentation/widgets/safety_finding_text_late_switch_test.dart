import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  SafetyFinding finding(double value) => SafetyFinding(
    id: 'f1',
    diveId: 'd1',
    ruleId: SafetyRuleId.lateGasSwitch,
    severity: SafetySeverity.caution,
    startTimestamp: 1630,
    endTimestamp: 1910,
    value: value,
    engineVersion: 6,
    createdAt: DateTime.utc(2026, 10, 5),
  );
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());

  test('names the extra deco a late switch cost', () {
    expect(
      safetyFindingTitle(finding(250), l10n, units),
      'A late or missed gas switch added 4m 10s of deco',
    );
  });

  test('a finding with no stored value reads a neutral placeholder', () {
    final unknown = SafetyFinding(
      id: 'f2',
      diveId: 'd1',
      ruleId: SafetyRuleId.lateGasSwitch,
      severity: SafetySeverity.caution,
      engineVersion: 6,
      createdAt: DateTime.utc(2026, 10, 5),
    );
    expect(
      safetyFindingTitle(unknown, l10n, units),
      'A late or missed gas switch added -- of deco',
    );
  });

  test('does not claim "0s of deco" for a switch that cost nothing', () {
    expect(
      safetyFindingTitle(finding(0), l10n, units),
      'A gas switch was late but added no deco',
    );
  });
}
