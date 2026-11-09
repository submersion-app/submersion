import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Altitude section on a site's detail page.
InfoContent siteAltitudeInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveSites_detail_section_altitude,
    summary: l10n.info_site_altitude_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.surfacePressure,
      DiveTerm.altitudeGroup,
    ]),
  );
}
