import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Connections map and the panel that styles it.
InfoContent connectionsInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.connections_display_title,
    summary: l10n.info_connections_display_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.colourBy,
      DiveTerm.weightedEdges,
      DiveTerm.hops,
    ]),
    howToUse: l10n.info_connections_display_howToUse,
  );
}
