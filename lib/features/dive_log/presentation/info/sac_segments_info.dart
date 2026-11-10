import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Gas consumption by segment card.
InfoContent sacSegmentsInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool showsSac,
  required bool showsRmv,
  required bool hasSelector,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_sacRateBySegment,
    summary: l10n.info_diveLog_sacSegments_summary,
    terms: diveTermEntries(l10n, units, [
      if (showsSac) DiveTerm.sac,
      if (showsRmv) DiveTerm.rmv,
    ]),
    howToUse: hasSelector ? l10n.info_diveLog_sacSegments_howToUse : null,
  );
}
