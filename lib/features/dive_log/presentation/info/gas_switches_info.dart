import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Gas Switches card.
InfoContent gasSwitchesInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLog_gasSwitches_title,
    summary: l10n.info_diveLog_gasSwitches_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.idealSwitchDepth,
      DiveTerm.extraDeco,
      DiveTerm.mod,
      DiveTerm.decoGas,
    ]),
  );
}
