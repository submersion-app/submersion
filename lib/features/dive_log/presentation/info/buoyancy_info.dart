import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Buoyancy section.
InfoContent buoyancyInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool hasDrysuitGas,
  required bool canAdjust,
}) {
  return InfoContent(
    title: l10n.diveDetailSection_buoyancy_name,
    summary: l10n.info_diveLog_buoyancy_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.netBuoyancy,
      DiveTerm.buoyancySwing,
      DiveTerm.peakLift,
      DiveTerm.minDitchable,
      if (hasDrysuitGas) DiveTerm.drysuitGas,
    ]),
    howToUse: canAdjust ? l10n.info_diveLog_buoyancy_howToUse : null,
  );
}
