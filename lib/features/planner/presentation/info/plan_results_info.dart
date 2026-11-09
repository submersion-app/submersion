import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The planner's results tile grid. [inDeco] swaps NDL for TTS, as the tile
/// does.
InfoContent planResultsTilesInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool inDeco,
}) {
  return InfoContent(
    title: l10n.divePlanner_tab_results,
    summary: l10n.info_planner_results_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.runtime,
      inDeco ? DiveTerm.tts : DiveTerm.ndl,
      DiveTerm.cns,
    ]),
  );
}

/// A results section with a header: its [title], [summary] and [terms].
InfoContent planSectionInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required String title,
  required String summary,
  List<DiveTerm> terms = const [],
}) {
  return InfoContent(
    title: title,
    summary: summary,
    terms: diveTermEntries(l10n, units, terms),
  );
}

/// The Decompression schedule section and its table columns.
InfoContent planDecoScheduleInfo(AppLocalizations l10n, UnitFormatter units) =>
    planSectionInfo(
      l10n,
      units,
      title: l10n.divePlanner_label_decoSchedule,
      summary: l10n.info_planner_decoSchedule_summary,
      terms: const [
        DiveTerm.decoStops,
        DiveTerm.runtime,
        DiveTerm.ppO2,
        DiveTerm.end,
      ],
    );

/// The Gas section.
InfoContent planGasInfo(AppLocalizations l10n, UnitFormatter units) =>
    planSectionInfo(
      l10n,
      units,
      title: l10n.divePlanner_label_gasConsumption,
      summary: l10n.info_planner_gas_summary,
      terms: const [
        DiveTerm.turnPressure,
        DiveTerm.minGas,
        DiveTerm.reserveGas,
      ],
    );

/// The logged-dive carry card.
InfoContent planCarryInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required String title,
  required bool showsOtu,
}) => planSectionInfo(
  l10n,
  units,
  title: title,
  summary: l10n.info_planner_carry_summary,
  terms: [DiveTerm.surfaceInterval, DiveTerm.cns, if (showsOtu) DiveTerm.otu],
);
