import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/planner/presentation/info/plan_setup_info.dart';

/// Settings sections that carry an info icon.
enum SettingsInfoSection {
  gradientFactors,
  oxygenToxicity,
  dataSources,
  narcosis,
  isobaricCounterdiffusion,
  ascentPlanning,
  ascentRate,
  plannerRates,
  plannerGas,
  plannerContingency,
  plannerDpvTeam,
  safetyReviewRules,
  conditionThresholds,
  sensorSummaries,
  conditionRules,
  notifications,
}

/// The info sheet for a settings [section].
InfoContent settingsSectionInfo(
  AppLocalizations l10n,
  UnitFormatter units,
  SettingsInfoSection section,
) {
  InfoContent sheet(
    String title,
    String summary,
    List<DiveTerm> terms, {
    String? background,
  }) => InfoContent(
    title: title,
    summary: summary,
    terms: diveTermEntries(l10n, units, terms),
    background: background,
  );

  return switch (section) {
    SettingsInfoSection.gradientFactors => sheet(
      l10n.settings_decompression_header_gradientFactors,
      l10n.info_settings_gradientFactors_summary,
      const [DiveTerm.gradientFactors, DiveTerm.mValue],
      background: l10n.info_settings_gradientFactors_background,
    ),
    SettingsInfoSection.oxygenToxicity => sheet(
      l10n.settings_decompression_header_oxygenToxicity,
      l10n.info_settings_oxygenToxicity_summary,
      const [DiveTerm.ppO2, DiveTerm.cns, DiveTerm.otu],
    ),
    SettingsInfoSection.dataSources => sheet(
      l10n.settings_decompression_header_dataSources,
      l10n.info_settings_dataSources_summary,
      const [DiveTerm.sourceDcCalc, DiveTerm.gtr],
    ),
    SettingsInfoSection.narcosis => sheet(
      l10n.settings_decompression_header_narcosis,
      l10n.info_settings_narcosis_summary,
      const [DiveTerm.end, DiveTerm.mnd, DiveTerm.o2Narcotic],
    ),
    SettingsInfoSection.isobaricCounterdiffusion => sheet(
      l10n.settings_decompression_header_icd,
      l10n.info_settings_icd_summary,
      const [DiveTerm.isobaricCounterdiffusion],
    ),
    SettingsInfoSection.ascentPlanning => sheet(
      l10n.settings_decompression_header_ascent,
      l10n.info_settings_ascent_summary,
      const [DiveTerm.ascentGasSet, DiveTerm.tts, DiveTerm.ceiling],
    ),
    SettingsInfoSection.ascentRate => sheet(
      l10n.settings_decompression_header_ascentRate,
      l10n.info_term_ascentRate_body(units.formatDepthRate(9, decimals: 0)),
      const [DiveTerm.ascentRate],
    ),
    SettingsInfoSection.plannerRates => planSetupSectionInfo(
      l10n,
      units,
      'rates',
      title: l10n.settings_decompression_header_plannerRates,
    ),
    SettingsInfoSection.plannerGas => planSetupSectionInfo(
      l10n,
      units,
      'gas',
      title: l10n.settings_decompression_header_plannerGas,
    ),
    SettingsInfoSection.plannerContingency => planSetupSectionInfo(
      l10n,
      units,
      'contingencies',
      title: l10n.settings_decompression_header_plannerContingency,
    ),
    SettingsInfoSection.plannerDpvTeam => planSetupSectionInfo(
      l10n,
      units,
      'dpvTeam',
      title: l10n.settings_decompression_header_plannerDpvTeam,
    ),
    SettingsInfoSection.safetyReviewRules => sheet(
      l10n.safetySettings_rulesHeader,
      l10n.info_settings_safetyRules_summary,
      const [
        DiveTerm.ascentRate,
        DiveTerm.missedDecoStop,
        DiveTerm.safetyStop,
        DiveTerm.sawtooth,
        DiveTerm.surfaceGf,
        DiveTerm.lateGasSwitch,
      ],
    ),
    SettingsInfoSection.conditionThresholds => sheet(
      l10n.equipmentConditionSettings_thresholdsHeader,
      l10n.info_settings_conditionThresholds_summary,
      const [DiveTerm.coldDives, DiveTerm.deepCycles, DiveTerm.highO2Hours],
    ),
    SettingsInfoSection.sensorSummaries => sheet(
      l10n.equipmentConditionSettings_sensorHeader,
      l10n.info_settings_sensorSummaries_summary,
      const [
        DiveTerm.cellGain,
        DiveTerm.transmitterDropouts,
        DiveTerm.scrubber,
      ],
    ),
    SettingsInfoSection.conditionRules => sheet(
      l10n.equipmentConditionSettings_rulesHeader,
      l10n.info_settings_conditionRules_summary,
      const [DiveTerm.conditionRules],
    ),
    SettingsInfoSection.notifications => sheet(
      l10n.settings_notifications_header_serviceReminders,
      l10n.info_settings_notifications_summary,
      const [],
    ),
  };
}
