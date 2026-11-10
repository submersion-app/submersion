import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Oxygen Toxicity panel and card. Both always show the daily and weekly
/// OTU windows; [showsDetails] is whether the max ppO2 readouts and, with
/// [showsTimeAbove], the time above the limits are on screen.
InfoContent o2ToxicityInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool showsDetails,
  required bool showsTimeAbove,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_oxygenToxicity,
    summary: l10n.info_diveLog_o2Toxicity_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.cns,
      DiveTerm.cnsStartAdded,
      DiveTerm.otu,
      DiveTerm.otuWindows,
      DiveTerm.ppO2,
      if (showsDetails) DiveTerm.maxPpO2,
      if (showsDetails && showsTimeAbove) DiveTerm.timeAboveLimit,
    ]),
    background: l10n.info_diveLog_o2Toxicity_background,
  );
}
