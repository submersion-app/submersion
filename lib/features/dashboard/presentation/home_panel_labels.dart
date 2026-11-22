import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A panel's name in the diver's language, for the settings list. The gas
/// trend takes the name Home shows it by, from the diver's [lane].
String homePanelLabel(
  AppLocalizations l10n,
  HomePanelType panel, {
  required GasConsumptionLane lane,
}) => switch (panel) {
  HomePanelType.keyNumbers => l10n.settings_homePanels_keyNumbers,
  HomePanelType.waitingForDownload =>
    l10n.settings_homeCards_card_waitingForDownload,
  HomePanelType.preDive => l10n.dashboard_checklists_title,
  HomePanelType.activeCourses => l10n.dashboard_activeCourses_title,
  HomePanelType.activityCalendar => l10n.settings_homePanels_activityCalendar,
  HomePanelType.recentOutings => l10n.settings_homePanels_recentOutings,
  HomePanelType.gearService => l10n.dashboard_panel_gearService,
  HomePanelType.comingDue => l10n.dashboard_panel_comingDue,
  HomePanelType.nextTrip => l10n.dashboard_key_nextTrip,
  HomePanelType.latestProfile => l10n.dashboard_panel_latestProfile,
  HomePanelType.latestVsAverage => l10n.dashboard_panel_latestVsAverage,
  HomePanelType.recentDives => l10n.dashboard_panel_recentDives,
  HomePanelType.sacTrend =>
    lane == GasConsumptionLane.sac
        ? l10n.dashboard_panel_sacTrend
        : l10n.dashboard_panel_rmvTrend,
  HomePanelType.depthMix => l10n.dashboard_panel_depthMix,
  HomePanelType.divesPerMonth => l10n.dashboard_panel_divesPerMonth,
  HomePanelType.gasMix => l10n.dashboard_panel_gasMix,
  HomePanelType.diveTypes => l10n.dashboard_panel_diveTypes,
  HomePanelType.topSites => l10n.dashboard_panel_topSites,
  HomePanelType.topBuddies => l10n.dashboard_panel_topBuddies,
  HomePanelType.speciesSeen => l10n.dashboard_panel_speciesSeen,
  HomePanelType.photoRibbon => l10n.dashboard_media_title,
  HomePanelType.recentSitesMap => l10n.dashboard_recentSites_title,
  HomePanelType.onThisDay => l10n.dashboard_onThisDay_title,
};

String homePresetLabel(AppLocalizations l10n, HomeLayoutPreset preset) =>
    switch (preset) {
      HomeLayoutPreset.balanced => l10n.settings_homeLayout_balanced,
      HomeLayoutPreset.ready => l10n.settings_homeLayout_ready,
      HomeLayoutPreset.trends => l10n.settings_homeLayout_trends,
      HomeLayoutPreset.logbook => l10n.settings_homeLayout_logbook,
    };
