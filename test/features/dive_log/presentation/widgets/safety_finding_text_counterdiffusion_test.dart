import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Issue #4530: the counterdiffusion finding names how long the tissues
/// counterdiffused, or the gas switch that broke the rule of fifths.
void main() {
  SafetyFinding finding({int? start, int? end}) => SafetyFinding(
    id: 'f1',
    diveId: 'd1',
    ruleId: SafetyRuleId.isobaricCounterdiffusion,
    severity: SafetySeverity.caution,
    startTimestamp: start,
    endTimestamp: end,
    engineVersion: 12,
    createdAt: DateTime.utc(2026, 11, 14),
  );
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());

  test('a tissue-model span names its duration', () {
    expect(
      safetyFindingTitle(finding(start: 600, end: 780), l10n, units),
      'Isobaric counterdiffusion for 3m',
    );
  });

  test('an instant names the gas switch', () {
    expect(
      safetyFindingTitle(finding(start: 1910, end: 1910), l10n, units),
      'A gas switch broke the rule of fifths',
    );
  });

  test('a finding without a span reads a neutral placeholder', () {
    expect(
      safetyFindingTitle(finding(), l10n, units),
      'Isobaric counterdiffusion for --',
    );
  });

  test('the short label is the rule name', () {
    expect(
      safetyFindingShortLabel(finding(start: 0, end: 60), l10n),
      'Isobaric counterdiffusion',
    );
  });
}
