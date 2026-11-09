import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The info sheet for the gas calculator [id] (one of `kGasCalculatorIds`).
///
/// Each sheet carries the facts the calculator's old About card stated,
/// without its advice, plus the terms its results use and how to use it.
InfoContent calculatorInfo(
  AppLocalizations l10n,
  UnitFormatter units,
  String id,
) {
  final (title, summary, background, howToUse, terms) = switch (id) {
    'mod' => (
      l10n.gasCalculators_tab_mod,
      l10n.info_calculators_mod_summary,
      l10n.info_calculators_mod_background,
      l10n.info_calculators_mod_howToUse,
      const [
        DiveTerm.mod,
        DiveTerm.ppO2,
        DiveTerm.ead,
        DiveTerm.end,
        DiveTerm.o2Narcotic,
      ],
    ),
    'best-mix' => (
      l10n.gasCalculators_tab_bestMix,
      l10n.info_calculators_bestMix_summary,
      null,
      l10n.info_calculators_bestMix_howToUse,
      const [
        DiveTerm.mod,
        DiveTerm.end,
        DiveTerm.gasDensity,
        DiveTerm.trimix,
        DiveTerm.diluent,
        DiveTerm.bailout,
      ],
    ),
    'consumption' => (
      l10n.gasCalculators_tab_consumption,
      l10n.info_calculators_consumption_summary,
      null,
      l10n.info_calculators_consumption_howToUse,
      const [DiveTerm.rmv, DiveTerm.sac],
    ),
    'rock-bottom' => (
      l10n.gasCalculators_tab_rockBottom,
      l10n.info_calculators_rockBottom_summary,
      l10n.info_calculators_rockBottom_background,
      l10n.info_calculators_rockBottom_howToUse,
      const [
        DiveTerm.rockBottom,
        DiveTerm.minGas,
        DiveTerm.rmv,
        DiveTerm.safetyStop,
      ],
    ),
    'mnd' => (
      l10n.gasCalculators_tab_mnd,
      l10n.info_calculators_mnd_summary,
      null,
      l10n.info_calculators_mnd_howToUse,
      const [DiveTerm.mnd, DiveTerm.end, DiveTerm.o2Narcotic],
    ),
    'icd' => (
      l10n.gasCalculators_tab_icd,
      l10n.info_calculators_icd_summary,
      l10n.info_calculators_icd_background,
      l10n.info_calculators_icd_howToUse,
      const [DiveTerm.isobaricCounterdiffusion],
    ),
    'density' => (
      l10n.gasCalculators_tab_density,
      l10n.info_calculators_density_summary,
      l10n.info_calculators_density_background,
      l10n.info_calculators_density_howToUse,
      const [
        DiveTerm.gasDensity,
        DiveTerm.eadd,
        DiveTerm.hypercapnia,
        DiveTerm.setpoint,
      ],
    ),
    'blender' => (
      l10n.gasCalculators_tab_blender,
      l10n.info_calculators_blender_summary,
      l10n.info_calculators_blender_background,
      l10n.info_calculators_blender_howToUse,
      const [DiveTerm.trimix, DiveTerm.nitrox],
    ),
    _ => throw ArgumentError.value(id, 'id', 'not a gas calculator'),
  };
  return InfoContent(
    title: title,
    summary: summary,
    terms: diveTermEntries(l10n, units, terms),
    background: background,
    howToUse: howToUse,
  );
}
