import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart'
    show ModCalculatorMode;
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
  // These sheets list what their card shows, which the live controls
  // decide; without them they show each calculator's default mode.
  switch (id) {
    case 'best-mix':
      return bestMixInfo(l10n, units, isCcr: false, hasHelium: false);
    case 'mod':
      return modInfo(l10n, units, mode: ModCalculatorMode.rec);
    case 'density':
      return densityInfo(l10n, units, isCcr: false);
  }
  final (title, summary, background, howToUse, terms) = switch (id) {
    'consumption' => (
      l10n.gasCalculators_tab_consumption,
      l10n.info_calculators_consumption_summary,
      null,
      l10n.info_calculators_consumption_howToUse,
      const [DiveTerm.rmv],
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

/// The Best Mix sheet. END and density show in every mode; the diluent and
/// bailout source exists only in CCR Tec ([isCcr]), and trimix only matters
/// when the recommended mix carries helium ([hasHelium]).
InfoContent bestMixInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool isCcr,
  required bool hasHelium,
}) {
  return InfoContent(
    title: l10n.gasCalculators_tab_bestMix,
    summary: l10n.info_calculators_bestMix_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.mod,
      DiveTerm.end,
      DiveTerm.gasDensity,
      if (hasHelium) DiveTerm.trimix,
      if (isCcr) ...[DiveTerm.diluent, DiveTerm.bailout],
    ]),
    howToUse: l10n.info_calculators_bestMix_howToUse,
  );
}

/// The MOD sheet for [mode]. Rec shows the MOD, ppO2 and EAD; the Tec modes
/// add END, EADD, density and MND, and CCR Tec works from a setpoint and a
/// diluent.
InfoContent modInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required ModCalculatorMode mode,
}) {
  final isTec = mode != ModCalculatorMode.rec;
  return termsInfo(
    l10n,
    units,
    title: l10n.gasCalculators_tab_mod,
    summary: l10n.info_calculators_mod_summary,
    background: l10n.info_calculators_mod_background(
      units.formatDepth(10, decimals: 0),
    ),
    howToUse: l10n.info_calculators_mod_howToUse,
    terms: [
      DiveTerm.mod,
      DiveTerm.ppO2,
      DiveTerm.ead,
      if (isTec) ...[
        DiveTerm.end,
        DiveTerm.eadd,
        DiveTerm.gasDensity,
        DiveTerm.mnd,
        DiveTerm.o2Narcotic,
      ],
      if (mode == ModCalculatorMode.ccrTec) ...[
        DiveTerm.setpoint,
        DiveTerm.diluent,
      ],
    ],
  );
}

/// The Gas Density sheet. The setpoint control shows only in CCR ([isCcr]).
InfoContent densityInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool isCcr,
}) {
  return termsInfo(
    l10n,
    units,
    title: l10n.gasCalculators_tab_density,
    summary: l10n.info_calculators_density_summary,
    background: l10n.info_calculators_density_background,
    howToUse: l10n.info_calculators_density_howToUse,
    terms: [
      DiveTerm.gasDensity,
      DiveTerm.eadd,
      DiveTerm.hypercapnia,
      if (isCcr) DiveTerm.setpoint,
    ],
  );
}
