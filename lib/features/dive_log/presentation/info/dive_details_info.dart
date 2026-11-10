import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Details section of a dive.
InfoContent diveDetailsInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool showsSac,
  required bool showsRmv,
  required bool hasGradientFactors,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_details,
    summary: l10n.info_diveLog_details_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.diveModes,
      if (showsSac) DiveTerm.sac,
      if (showsRmv) DiveTerm.rmv,
      if (hasGradientFactors) DiveTerm.gradientFactors,
    ]),
  );
}
