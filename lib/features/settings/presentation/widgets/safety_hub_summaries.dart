import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Live-state subtitles for the rows of the Safety settings hub, so a diver
/// can see what each sub-page is set to without opening it.

/// "On, 5 of 6 rules, no-fly Standard" or "Off, no-fly Standard".
///
/// The no-fly preset is named in both states because flying-after-diving
/// guidance applies whether or not the post-dive review runs.
String safetyReviewSummary(AppLocalizations l10n, AppSettings settings) {
  final noFly = switch (settings.noFlyPreset) {
    NoFlyPreset.standard => l10n.safetyHub_noFlyStandard,
    NoFlyPreset.strict => l10n.safetyHub_noFlyStrict,
  };
  if (!settings.safetyReviewEnabled) return l10n.safetyHub_reviewOff(noFly);
  final enabled = SafetyRuleId.values
      .where((r) => !settings.safetyReviewDisabledRules.contains(r.dbValue))
      .length;
  return l10n.safetyHub_reviewOn(enabled, SafetyRuleId.values.length, noFly);
}

/// "GF 30/70".
String decompressionSummary(AppLocalizations l10n, AppSettings settings) =>
    l10n.settings_decompression_gfValue(settings.gfLow, settings.gfHigh);

/// "On, 9 of 10 rules" or "Off".
String equipmentConditionSummary(AppLocalizations l10n, AppSettings settings) {
  if (!settings.conditionEngineEnabled) return l10n.safetyHub_off;
  final enabled = ConditionRuleId.values
      .where((r) => !settings.conditionDisabledRules.contains(r.dbValue))
      .length;
  return l10n.safetyHub_conditionOn(enabled, ConditionRuleId.values.length);
}
