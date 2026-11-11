import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Holds the settings load at its first read until [gate] completes.
class _GatedDiverRepository extends DiverRepository {
  _GatedDiverRepository(this.gate);

  final Completer<void> gate;

  @override
  Future<Diver?> getDiverById(String id) async {
    await gate.future;
    return super.getDiverById(id);
  }
}

/// Calls every [SettingsNotifier] setter once, in a fixed order, each with
/// a value other than the default where the setter takes one.
Future<void> _changeEverySetting(SettingsNotifier n) {
  const d = AppSettings();
  return Future.wait([
    // Resets first: they would undo the matching setters below.
    n.resetHomeCards(),
    n.resetProfileMetricColors(),
    n.resetDiveDetailSections(),
    n.resetSiteDetailSections(),
    n.setTemperatureUnit(TemperatureUnit.fahrenheit),
    n.setPressureUnit(PressureUnit.psi),
    n.setVolumeUnit(VolumeUnit.cubicFeet),
    n.setWeightUnit(WeightUnit.pounds),
    n.setGasConsumptionDisplay(GasConsumptionDisplay.values.last),
    n.setGasModel(GasModel.values.last),
    n.setDefaultPlannerWaterType(PlannerWaterType.values.last),
    n.setDefaultCurrency(' eur '),
    n.setVisibilityScale(
      preset: VisibilityScalePreset.values.last,
      excellentM: 30,
      goodM: 15,
      moderateM: 5,
    ),
    n.setCoordinateFormat(CoordinateFormat.values.last),
    n.setAltitudeUnit(AltitudeUnit.feet),
    n.setDistanceUnit(DistanceUnit.miles),
    n.setTimeFormat(TimeFormat.values.last),
    n.setDateFormat(DateFormatPreference.values.last),
    n.setFirstDayOfWeek(FirstDayOfWeek.values.last),
    n.setThemeMode(ThemeMode.dark),
    n.setThemePresetId('reef'),
    n.setAccentNavIcons(!d.accentNavIcons),
    n.setAccentSectionHeaders(!d.accentSectionHeaders),
    n.setAccentListIcons(!d.accentListIcons),
    n.setLocale('de'),
    n.setPlaceNameLanguage('fr'),
    n.setDefaultDiveType('training'),
    n.setDefaultTankVolume(15),
    n.setDefaultStartPressure(230),
    n.setDefaultTankPreset('hp100'),
    n.setTankPresetHidden('al80', true),
    n.setBuiltInHidden(BuiltInCatalog.diveTypes, 'recreational', true),
    n.setApplyDefaultTankToImports(!d.applyDefaultTankToImports),
    n.setGfHigh(80),
    n.setGfLow(40),
    n.setGradientFactors(35, 75),
    n.setPpO2MaxWorking(1.3),
    n.setPpO2MaxDeco(1.5),
    n.setPpO2Limits(1.2, 1.5),
    n.setPpO2DecoBandsConfig(
      bandsEnabled: true,
      band1: 1.3,
      band2: 1.4,
      band3: 1.5,
      maxO2DepthEnabled: true,
      maxO2DepthMeters: 5,
    ),
    n.setCcrPpO2Limits(
      setpointLow: 0.6,
      setpointHigh: 1.2,
      diluentModPpO2: 1.1,
    ),
    n.setCnsWarningThreshold(70),
    n.setAscentRateThresholds(warning: 8, critical: 12),
    n.setShowCeilingOnProfile(!d.showCeilingOnProfile),
    n.setShowDecoStopsOnProfile(!d.showDecoStopsOnProfile),
    n.setSafetyReviewEnabled(!d.safetyReviewEnabled),
    n.setColdWaterThresholdC(12),
    n.setDeepDiveThresholdM(25),
    n.setHighO2ThresholdPercent(40),
    n.setHomeChipEnabled('depth', false),
    n.setHomeCardEnabled('stats', false),
    n.setHomeCardOrder(const ['stats', 'recent']),
    n.setSafetyRuleEnabled(SafetyRuleId.values.first, false),
    n.setConditionEngineEnabled(!d.conditionEngineEnabled),
    n.setConditionRuleEnabled(ConditionRuleId.values.first, false),
    n.setObservationRuleMuted(ObservationRuleId.values.first, true),
    n.setNoFlyPreset(NoFlyPreset.values.last),
    n.setChamberHidden('chamber-1', true),
    n.setEmergencyRegion('AU'),
    n.setShowAscentRateColors(!d.showAscentRateColors),
    n.setShowNdlOnProfile(!d.showNdlOnProfile),
    n.setLastStopDepth(6),
    n.setPlannerDescentRate(20),
    n.setPlannerAscentRate(8),
    n.setPlannerIntermediateAscentRate(6),
    n.setPlannerShallowAscentRate(4),
    n.setPlannerFinalAscentRate(2),
    n.setPlannerGasSwitchStopSeconds(90),
    n.setPlannerSacBottom(22),
    n.setPlannerSacDeco(16),
    n.setPlannerSacStressedFactor(2.5),
    n.setPlannerBuddyFactor(1.5),
    n.setPlannerHypercapniaConfig(enabled: true, factor: 3, minutes: 5),
    n.setPlannerProblemSolvingMinutes(4),
    n.setPlannerBestMixEndMeters(25),
    n.setPlannerDeviationDepthDelta(4),
    n.setPlannerDeviationTimeMinutes(6),
    n.setPlannerBatteryReserveFraction(0.4),
    n.setPlannerWalkSpeedMps(0.8),
    n.setPlannerTurnPressureRule(TurnPressureRule.thirds),
    n.setPlannerTurnPressureFraction(0.4),
    n.setPlannerAirBreakO2Seconds(1200),
    n.setPlannerAirBreakBreakSeconds(300),
    n.setPlannerAirBreakPolicy(o2Seconds: 1080, breakSeconds: 360),
    n.setPlannerReservePressure(60),
    n.setDecoStopIncrement(2),
    n.setPscrRatio(8),
    n.setO2Narcotic(!d.o2Narcotic),
    n.setTrendGapThreshold(TrendGapThreshold.values.last),
    n.setEquipmentDefaultStatuses({EquipmentStatus.values.first}),
    n.setEquipmentDefaultStatusIncluded(EquipmentStatus.values.last, true),
    n.setProfileMetricColor(
      ProfileMetric.values.first,
      const Color(0xFF123456),
    ),
    n.setIcdWarningsEnabled(!d.icdWarningsEnabled),
    n.setAscentGasSet(AscentGasSet.values.last),
    n.setEndLimit(35),
    n.setDefaultNdlSource(MetricDataSource.values.last),
    n.setDefaultDecoStopSource(MetricDataSource.values.last),
    n.setDefaultTtsSource(MetricDataSource.values.last),
    n.setDefaultCnsSource(MetricDataSource.values.last),
    n.setDefaultGtrSource(MetricDataSource.values.last),
    n.setGtrReservePressure(40),
    n.setCnsCalculationMethod(CnsCalculationMethod.values.last),
    n.setCardColorAttribute(CardColorAttribute.values.last),
    n.setDiveListViewMode(ListViewMode.values.last),
    n.setGroupTripsInDiveList(!d.groupTripsInDiveList),
    n.toggleGroupTripsInDiveList(),
    n.setAutoTagImports(!d.autoTagImports),
    n.setSiteListViewMode(ListViewMode.values.last),
    n.setTripListViewMode(ListViewMode.values.last),
    n.setEquipmentListViewMode(ListViewMode.values.last),
    n.setBuddyListViewMode(ListViewMode.values.last),
    n.setDiveCenterListViewMode(ListViewMode.values.last),
    n.setCertificationListViewMode(ListViewMode.values.last),
    n.setCourseListViewMode(ListViewMode.values.last),
    n.setMapStyle(MapStyle.values.last),
    n.setSiteMatchSensitivity(SiteMatchSensitivity.values.last),
    n.setDownloadsFollowComputerOwner(!d.downloadsFollowComputerOwner),
    n.setOmitUnusedOcGases(!d.omitUnusedOcGases),
    n.setTrimTankPressureAtSurfacing(!d.trimTankPressureAtSurfacing),
    n.setCardColorGradientPreset('sunset'),
    n.setCardColorGradientCustom(0xFF000000, 0xFFFFFFFF),
    n.setTissueColorScheme(TissueColorScheme.values.last),
    n.setSeascapeVerticalExaggerationOverride('site-1', 2),
    n.setSeascapeVerticalExaggerationOverride('site-2', 3),
    n.setSeascapeVerticalExaggerationOverride('site-2', null),
    n.setTissueVizMode(TissueVizMode.values.last),
    n.setShowMapBackgroundOnDiveCards(!d.showMapBackgroundOnDiveCards),
    n.setShowPhotoBackgroundOnDiveCards(!d.showPhotoBackgroundOnDiveCards),
    n.setCardPhotoOverlayDark(0.3),
    n.setCardPhotoOverlayLight(0.2),
    n.setShowMapBackgroundOnSiteCards(!d.showMapBackgroundOnSiteCards),
    n.setShowMaxDepthMarker(!d.showMaxDepthMarker),
    n.setShowPressureThresholdMarkers(!d.showPressureThresholdMarkers),
    n.setDefaultRightAxisMetric(ProfileRightAxisMetric.values.last),
    n.setDefaultShowTemperature(!d.defaultShowTemperature),
    n.setDefaultShowPressure(!d.defaultShowPressure),
    n.setDefaultShowHeartRate(!d.defaultShowHeartRate),
    n.setDefaultShowSac(!d.defaultShowSac),
    n.setDefaultShowEvents(!d.defaultShowEvents),
    n.setDefaultShowPpO2(!d.defaultShowPpO2),
    n.setDefaultShowPpN2(!d.defaultShowPpN2),
    n.setDefaultShowPpHe(!d.defaultShowPpHe),
    n.setDefaultShowGasDensity(!d.defaultShowGasDensity),
    n.setDefaultShowGf(!d.defaultShowGf),
    n.setDefaultShowSurfaceGf(!d.defaultShowSurfaceGf),
    n.setDefaultShowMeanDepth(!d.defaultShowMeanDepth),
    n.setDefaultShowTts(!d.defaultShowTts),
    n.setDefaultShowGtr(!d.defaultShowGtr),
    n.setDefaultShowCns(!d.defaultShowCns),
    n.setDefaultShowOtu(!d.defaultShowOtu),
    n.setDefaultShowGasSwitchMarkers(!d.defaultShowGasSwitchMarkers),
    n.setDefaultShowLateGasSwitches(!d.defaultShowLateGasSwitches),
    n.setDefaultShowPhotoMarkers(!d.defaultShowPhotoMarkers),
    n.setDefaultShowGasTimeline(!d.defaultShowGasTimeline),
    n.setDefaultShowO2CellMv(!d.defaultShowO2CellMv),
    n.setDefaultShowEstimatedTankPressure(!d.defaultShowEstimatedTankPressure),
    n.setDefaultShowAscentRateLine(!d.defaultShowAscentRateLine),
    n.setNotificationsEnabled(false),
    n.setServiceReminderDays(const [14, 3, 14]),
    n.toggleReminderDay(60),
    n.toggleReminderDay(3),
    n.setReminderTime(const TimeOfDay(hour: 7, minute: 30)),
    n.setTripServiceLeadDays(21),
    n.setShowDataSourceBadges(!d.showDataSourceBadges),
    n.setShowDiveFigure(!d.showDiveFigure),
    n.setAutoColorCorrection(!d.autoColorCorrection),
    n.acceptPlanningDisclaimer(),
    n.setShowProfilePanelInTableView(!d.showProfilePanelInTableView),
    n.setDiveDetailSections(d.diveDetailSections.reversed.toList()),
    n.setDiveDetailLayout(DiveDetailLayout.values.last),
    n.setDiveDetailSectionExpanded(
      d.diveDetailSections.first.id,
      !d.diveDetailSections.first.expanded,
    ),
    n.setSiteDetailSections(d.siteDetailSections.reversed.toList()),
    n.setSiteDetailLayout(DiveDetailLayout.values.last),
    n.setSiteDetailSectionExpanded(
      d.siteDetailSections.first.id,
      !d.siteDetailSections.first.expanded,
    ),
    n.setProfileMetricsFollowViewport(!d.profileMetricsFollowViewport),
    n.setO2CellUnit(O2CellUnit.values.last),
    n.setPerdixOverlayEnabled(!d.perdixOverlayEnabled),
    n.setPerdixOverlayPosition(0.25, 0.75),
    n.setShowDetailsPaneForSection('dives', !d.showDetailsPaneDives),
    n.setShowDetailsPaneForSection('sites', !d.showDetailsPaneSites),
    n.setShowDetailsPaneForSection('buddies', !d.showDetailsPaneBuddies),
    n.setShowDetailsPaneForSection('trips', !d.showDetailsPaneTrips),
    n.setShowDetailsPaneForSection('equipment', !d.showDetailsPaneEquipment),
    n.setShowDetailsPaneForSection(
      'diveCenters',
      !d.showDetailsPaneDiveCenters,
    ),
    n.setShowDetailsPaneForSection(
      'certifications',
      !d.showDetailsPaneCertifications,
    ),
    n.setShowDetailsPaneForSection('courses', !d.showDetailsPaneCourses),
    n.setShowDetailsPaneForSection('unknown', true),
    n.setImperial(),
    n.setMetric(),
    n.setDepthUnit(DepthUnit.feet),
  ]);
}

/// Every setter waits for the diver's settings to load (issue #4449). The
/// same changes made before the load lands and after it must leave the
/// diver with the same settings, in state and in the stored row. Without
/// the wait, the ones made before the load are overwritten by it.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<({AppSettings state, AppSettings? stored})> run({
    required bool beforeLoad,
  }) async {
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diver.id});
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        diverRepositoryProvider.overrideWithValue(_GatedDiverRepository(gate)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    if (!beforeLoad) {
      gate.complete();
      await notifier.initialLoad;
    }
    final changing = _changeEverySetting(notifier);
    if (beforeLoad) gate.complete();
    await changing;
    return (
      state: container.read(settingsProvider),
      stored: await DiverSettingsRepository().getSettingsForDiver(diver.id),
    );
  }

  test('changes made before the load end as the same changes made '
      'after it', () async {
    final after = await run(beforeLoad: false);
    final before = await run(beforeLoad: true);

    // The changes took: the settings no longer match the defaults.
    expect(
      DiverSettingsRepository.storesSameSettings(
        after.state,
        const AppSettings(),
      ),
      isFalse,
    );
    expect(
      DiverSettingsRepository.storesSameSettings(before.state, after.state),
      isTrue,
      reason: 'a change made before the load was lost',
    );
    expect(
      DiverSettingsRepository.storesSameSettings(before.stored!, after.stored!),
      isTrue,
      reason: 'a change made before the load was not stored',
    );
    expect(
      DiverSettingsRepository.storesSameSettings(after.stored!, after.state),
      isTrue,
    );
  });
}
