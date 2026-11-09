import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Oxygen Toxicity panel and card.
InfoContent o2ToxicityInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool showsOtuWindows,
  required bool showsTimeAbove,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_oxygenToxicity,
    summary: l10n.info_diveLog_o2Toxicity_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.cns,
      DiveTerm.cnsStartAdded,
      DiveTerm.otu,
      if (showsOtuWindows) DiveTerm.otuWindows,
      DiveTerm.ppO2,
      DiveTerm.maxPpO2,
      if (showsTimeAbove) DiveTerm.timeAboveLimit,
    ]),
    background: l10n.info_diveLog_o2Toxicity_background,
  );
}
