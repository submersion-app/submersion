import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// The Tissue Loading card. [view] is the visualisation under the bars, null
/// when the card shows none.
InfoContent tissueLoadingInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required TissueVizMode? view,
  required bool hasHelium,
}) {
  return InfoContent(
    title: l10n.diveLog_deco_sectionTissueLoading,
    summary: l10n.info_diveLog_tissueLoading_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.tissueCompartment,
      DiveTerm.leadingCompartment,
      DiveTerm.tissueLoad,
      DiveTerm.mValue,
      DiveTerm.surfaceLevel,
      DiveTerm.gradientFactors,
      DiveTerm.halfTime,
      DiveTerm.ongassing,
      if (hasHelium) DiveTerm.nitrogenHelium,
      if (view == TissueVizMode.heatMap) DiveTerm.heatMap,
      if (view == TissueVizMode.stackedArea) DiveTerm.stackedArea,
    ]),
    background: l10n.info_diveLog_tissueLoading_background,
  );
}
