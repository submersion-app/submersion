import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Surface Interval tool, carrying the facts its old "About Tissue
/// Loading" card stated.
InfoContent surfaceIntervalInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.surfaceInterval_title,
    summary: l10n.info_surfaceIntervalTool_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.tissueCompartment,
      DiveTerm.leadingCompartment,
      DiveTerm.surfaceInterval,
      DiveTerm.ndl,
    ]),
    background: l10n.info_surfaceIntervalTool_background,
    howToUse: l10n.info_surfaceIntervalTool_howToUse,
  );
}
