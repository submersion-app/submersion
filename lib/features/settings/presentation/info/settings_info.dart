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
  return switch (section) {
    SettingsInfoSection.gradientFactors => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_gradientFactors,
      summary: l10n.info_settings_gradientFactors_summary,
      terms: const [DiveTerm.gradientFactors, DiveTerm.mValue],
      background: l10n.info_settings_gradientFactors_background,
    ),
    SettingsInfoSection.oxygenToxicity => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_oxygenToxicity,
      summary: l10n.info_settings_oxygenToxicity_summary,
      terms: const [DiveTerm.ppO2, DiveTerm.cns, DiveTerm.otu],
    ),
    SettingsInfoSection.dataSources => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_dataSources,
      summary: l10n.info_settings_dataSources_summary,
      terms: const [DiveTerm.sourceDcCalc, DiveTerm.gtr],
    ),
    SettingsInfoSection.narcosis => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_narcosis,
      summary: l10n.info_settings_narcosis_summary,
      terms: const [DiveTerm.end, DiveTerm.mnd, DiveTerm.o2Narcotic],
    ),
    SettingsInfoSection.isobaricCounterdiffusion => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_icd,
      summary: l10n.info_settings_icd_summary,
      terms: const [DiveTerm.isobaricCounterdiffusion],
    ),
    SettingsInfoSection.ascentPlanning => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_ascent,
      summary: l10n.info_settings_ascent_summary,
      terms: const [DiveTerm.ascentGasSet, DiveTerm.tts, DiveTerm.ceiling],
    ),
    SettingsInfoSection.ascentRate => termsInfo(
      l10n,
      units,
      title: l10n.settings_decompression_header_ascentRate,
      summary: l10n.info_settings_ascentRate_summary,
      terms: const [DiveTerm.ascentRate],
    ),
    SettingsInfoSection.plannerRates => _plannerDefaultInfo(
      l10n,
      units,
      'rates',
      l10n.settings_decompression_header_plannerRates,
    ),
    SettingsInfoSection.plannerGas => _plannerDefaultInfo(
      l10n,
      units,
      'gas',
      l10n.settings_decompression_header_plannerGas,
    ),
    SettingsInfoSection.plannerContingency => _plannerDefaultInfo(
      l10n,
      units,
      'contingencies',
      l10n.settings_decompression_header_plannerContingency,
    ),
    SettingsInfoSection.plannerDpvTeam => _plannerDefaultInfo(
      l10n,
      units,
      'dpvTeam',
      l10n.settings_decompression_header_plannerDpvTeam,
    ),
    SettingsInfoSection.safetyReviewRules => termsInfo(
      l10n,
      units,
      title: l10n.safetySettings_rulesHeader,
      summary: l10n.info_settings_safetyRules_summary,
      terms: const [
        DiveTerm.ascentRate,
        DiveTerm.missedDecoStop,
        DiveTerm.safetyStop,
        DiveTerm.sawtooth,
        DiveTerm.surfaceGf,
        DiveTerm.lateGasSwitch,
        DiveTerm.isobaricCounterdiffusion,
        DiveTerm.counterdiffusionProfile,
      ],
    ),
    SettingsInfoSection.conditionThresholds => termsInfo(
      l10n,
      units,
      title: l10n.equipmentConditionSettings_thresholdsHeader,
      summary: l10n.info_settings_conditionThresholds_summary,
      terms: const [
        DiveTerm.coldDives,
        DiveTerm.deepCycles,
        DiveTerm.highO2Hours,
      ],
    ),
    SettingsInfoSection.sensorSummaries => termsInfo(
      l10n,
      units,
      title: l10n.equipmentConditionSettings_sensorHeader,
      summary: l10n.info_settings_sensorSummaries_summary,
      terms: const [
        DiveTerm.cellGain,
        DiveTerm.transmitterDropouts,
        DiveTerm.scrubber,
      ],
    ),
    SettingsInfoSection.conditionRules => termsInfo(
      l10n,
      units,
      title: l10n.equipmentConditionSettings_rulesHeader,
      summary: l10n.info_settings_conditionRules_summary,
      terms: const [DiveTerm.conditionRules],
    ),
    SettingsInfoSection.notifications => termsInfo(
      l10n,
      units,
      title: l10n.settings_notifications_header_serviceReminders,
      summary: l10n.info_settings_notifications_summary,
      terms: const [],
    ),
  };
}

/// A planner default section: the setup section's summary and terms, but not
/// its How to use, which describes a plan's own controls and results that the
/// defaults page does not have.
InfoContent _plannerDefaultInfo(
  AppLocalizations l10n,
  UnitFormatter units,
  String key,
  String title,
) {
  final setup = planSetupSectionInfo(l10n, units, key, title: title);
  return InfoContent(
    title: setup.title,
    summary: setup.summary,
    terms: setup.terms,
  );
}
