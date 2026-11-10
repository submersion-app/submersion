import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Cylinders card. Without [hasBreathingGas] (only suit inflation) the
/// card shows no MOD, MND, ppO2 or consumption, so the sheet lists none.
InfoContent cylindersInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool hasNitrox,
  required bool hasTrimix,
  required bool isRebreather,
  required bool hasBreathingGas,
  required bool showsSac,
  required bool showsRmv,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_cylinders,
    summary: l10n.info_diveLog_cylinders_summary,
    terms: diveTermEntries(l10n, units, [
      if (hasBreathingGas) ...[DiveTerm.mod, DiveTerm.mnd, DiveTerm.ppO2],
      if (hasNitrox) DiveTerm.nitrox,
      if (hasTrimix) DiveTerm.trimix,
      if (isRebreather) ...[DiveTerm.loop, DiveTerm.diluent, DiveTerm.bailout],
      if (hasBreathingGas && showsSac) DiveTerm.sac,
      if (hasBreathingGas && showsRmv) DiveTerm.rmv,
    ]),
  );
}
