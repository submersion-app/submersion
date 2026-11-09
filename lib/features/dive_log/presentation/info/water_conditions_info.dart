import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The water conditions block in a dive's Environment section.
InfoContent waterConditionsInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool hasDhw,
  required bool hasAnomaly,
  required bool hasAlert,
}) {
  return InfoContent(
    title: l10n.water_conditions_title,
    summary: l10n.info_diveLog_waterConditions_summary,
    terms: diveTermEntries(l10n, units, [
      if (hasDhw) DiveTerm.degreeHeatingWeeks,
      if (hasAnomaly) DiveTerm.sstAnomaly,
      if (hasAlert) DiveTerm.bleachingAlert,
    ]),
  );
}
