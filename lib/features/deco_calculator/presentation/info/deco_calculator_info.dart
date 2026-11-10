import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Deco calculator page.
InfoContent decoCalculatorInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.decoCalculator_title,
    summary: l10n.info_decoCalculator_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.ppO2,
      DiveTerm.mod,
      DiveTerm.end,
      DiveTerm.ndl,
      DiveTerm.decoStops,
      DiveTerm.tts,
    ]),
    howToUse: l10n.info_decoCalculator_howToUse,
  );
}
