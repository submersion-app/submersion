import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Altitude Dive section.
InfoContent altitudeInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLog_detail_section_altitudeDive,
    summary: l10n.info_diveLog_altitude_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.surfacePressure,
      DiveTerm.altitudeGroup,
    ]),
  );
}
