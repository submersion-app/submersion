import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

DiveTerm _termFor(SafetyRuleId rule) => switch (rule) {
  SafetyRuleId.rapidAscent => DiveTerm.ascentRate,
  SafetyRuleId.missedDecoStop => DiveTerm.missedDecoStop,
  SafetyRuleId.omittedSafetyStop => DiveTerm.safetyStop,
  SafetyRuleId.sawtoothProfile => DiveTerm.sawtooth,
  SafetyRuleId.highSurfaceGf => DiveTerm.surfaceGf,
  SafetyRuleId.lateGasSwitch => DiveTerm.lateGasSwitch,
  SafetyRuleId.isobaricCounterdiffusion => DiveTerm.isobaricCounterdiffusion,
};

/// The Safety review section, listing the rules behind its [rules] findings
/// in rule order.
InfoContent safetyReviewInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required Set<SafetyRuleId> rules,
}) {
  return InfoContent(
    title: l10n.safetyReview_sectionTitle,
    summary: l10n.info_diveLog_safetyReview_summary,
    terms: diveTermEntries(l10n, units, [
      for (final rule in SafetyRuleId.values)
        if (rules.contains(rule)) _termFor(rule),
    ]),
    background: l10n.info_diveLog_safetyReview_background,
    howToUse: rules.isEmpty ? null : l10n.info_diveLog_safetyReview_howToUse,
  );
}
