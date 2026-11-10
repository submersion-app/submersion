import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The no-fly status card.
InfoContent noFlyInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.safetySettings_noFlyHeader,
    summary: l10n.info_safety_noFly_summary,
    terms: diveTermEntries(l10n, units, const [DiveTerm.noFlyTime]),
  );
}
