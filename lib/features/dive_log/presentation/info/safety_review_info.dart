import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

List<DiveTerm> _termsFor(SafetyRuleId rule) => switch (rule) {
  SafetyRuleId.rapidAscent => const [DiveTerm.ascentRate],
  SafetyRuleId.missedDecoStop => const [DiveTerm.missedDecoStop],
  SafetyRuleId.omittedSafetyStop => const [DiveTerm.safetyStop],
  SafetyRuleId.sawtoothProfile => const [DiveTerm.sawtooth],
  SafetyRuleId.highSurfaceGf => const [DiveTerm.surfaceGf],
  SafetyRuleId.lateGasSwitch => const [DiveTerm.lateGasSwitch],
  // The rule fires on a switch that breaks the rule of fifths and on a
  // tissue-model span where helium enters faster than nitrogen leaves; the
  // first term explains only the switch, the second the span (#4530).
  SafetyRuleId.isobaricCounterdiffusion => const [
    DiveTerm.isobaricCounterdiffusion,
    DiveTerm.counterdiffusionProfile,
  ],
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
        if (rules.contains(rule)) ..._termsFor(rule),
    ]),
    background: l10n.info_diveLog_safetyReview_background,
    howToUse: rules.isEmpty ? null : l10n.info_diveLog_safetyReview_howToUse,
  );
}
