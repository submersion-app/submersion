import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Dive Lab compare section on a dive's detail page.
InfoContent diveLabCompareInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveDetailSection_diveLab_name,
    summary: l10n.info_diveLab_compare_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.ndl,
      DiveTerm.decoStops,
      DiveTerm.surfaceGf,
      DiveTerm.bottomTime,
      DiveTerm.runtime,
    ]),
    howToUse: l10n.info_diveLab_compare_howToUse,
  );
}
