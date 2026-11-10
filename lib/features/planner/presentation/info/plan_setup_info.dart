import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The setup accordion's section keys that have an info sheet.
const planSetupSectionKeys = [
  'deco',
  'rates',
  'gas',
  'environment',
  'ccr',
  'pscr',
  'contingencies',
  'dpvTeam',
  'gear',
];

/// The info sheet for the setup section [key] (one of
/// [planSetupSectionKeys]), titled [title] as the accordion shows it.
InfoContent planSetupSectionInfo(
  AppLocalizations l10n,
  UnitFormatter units,
  String key, {
  required String title,
}) {
  final (summary, howToUse, terms) = switch (key) {
    'deco' => (
      l10n.info_plannerSetup_deco_summary,
      l10n.info_plannerSetup_deco_howToUse,
      const [DiveTerm.gradientFactors, DiveTerm.lastStop, DiveTerm.airBreaks],
    ),
    'rates' => (
      l10n.info_plannerSetup_rates_summary,
      l10n.info_plannerSetup_rates_howToUse,
      const [DiveTerm.descentRate, DiveTerm.ascentRate, DiveTerm.ascentStages],
    ),
    'gas' => (
      l10n.info_plannerSetup_gas_summary,
      l10n.info_plannerSetup_gas_howToUse,
      const [DiveTerm.sac, DiveTerm.reserveGas],
    ),
    'environment' => (
      l10n.info_plannerSetup_environment_summary,
      l10n.info_plannerSetup_environment_howToUse,
      const [
        DiveTerm.salinity,
        DiveTerm.altitudeGroup,
        DiveTerm.surfacePressure,
      ],
    ),
    'ccr' => (
      l10n.info_plannerSetup_ccr_summary,
      l10n.info_plannerSetup_ccr_howToUse,
      const [DiveTerm.setpoint, DiveTerm.setpointSwitchDepth, DiveTerm.diluent],
    ),
    'pscr' => (
      l10n.info_plannerSetup_pscr_summary,
      l10n.info_plannerSetup_pscr_howToUse,
      const [DiveTerm.pscrRatio],
    ),
    'contingencies' => (
      l10n.info_plannerSetup_contingencies_summary,
      l10n.info_plannerSetup_contingencies_howToUse,
      const [DiveTerm.turnPressure, DiveTerm.turnFraction, DiveTerm.thirds],
    ),
    'dpvTeam' => (
      l10n.info_plannerSetup_dpvTeam_summary,
      l10n.info_plannerSetup_dpvTeam_howToUse,
      const [DiveTerm.dpv],
    ),
    'gear' => (
      l10n.info_plannerSetup_gear_summary,
      l10n.info_plannerSetup_gear_howToUse,
      const [DiveTerm.netBuoyancy],
    ),
    _ => throw ArgumentError.value(key, 'key', 'no info for this section'),
  };
  return InfoContent(
    title: title,
    summary: summary,
    terms: diveTermEntries(l10n, units, terms),
    howToUse: howToUse,
  );
}
