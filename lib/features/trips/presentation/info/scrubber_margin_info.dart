import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The scrubber margin sheet on a trip's gear tab.
InfoContent scrubberMarginInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.trips_scrubber_title,
    summary: l10n.info_trips_scrubberMargin_summary,
    terms: diveTermEntries(l10n, units, const [DiveTerm.scrubber]),
  );
}
