import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Deco Status card. [inDeco] swaps NDL for the ceiling, as the card does.
InfoContent decoStatusInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool inDeco,
  required bool hasStops,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_decoStatus,
    summary: l10n.info_diveLog_decoStatus_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.decoStatus,
      inDeco ? DiveTerm.ceiling : DiveTerm.ndl,
      DiveTerm.tts,
      DiveTerm.gf99,
      DiveTerm.surfaceGf,
      DiveTerm.gradientFactors,
      if (hasStops) DiveTerm.decoStops,
    ]),
    background: l10n.info_diveLog_decoStatus_background,
  );
}
