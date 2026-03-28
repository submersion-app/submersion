import 'package:flutter/material.dart' hide Visibility;
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that doesn't access the database
class MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDepthUnit(DepthUnit unit) async =>
      state = state.copyWith(depthUnit: unit);
  @override
  Future<void> setTemperatureUnit(TemperatureUnit unit) async =>
      state = state.copyWith(temperatureUnit: unit);
  @override
  Future<void> setPressureUnit(PressureUnit unit) async =>
      state = state.copyWith(pressureUnit: unit);
  @override
  Future<void> setVolumeUnit(VolumeUnit unit) async =>
      state = state.copyWith(volumeUnit: unit);
  @override
  Future<void> setWeightUnit(WeightUnit unit) async =>
      state = state.copyWith(weightUnit: unit);
  @override
  Future<void> setSacUnit(SacUnit unit) async =>
      state = state.copyWith(sacUnit: unit);
  @override
  Future<void> setAltitudeUnit(AltitudeUnit unit) async =>
      state = state.copyWith(altitudeUnit: unit);
  @override
  Future<void> setTimeFormat(TimeFormat format) async =>
      state = state.copyWith(timeFormat: format);
  @override
  Future<void> setDateFormat(DateFormatPreference format) async =>
      state = state.copyWith(dateFormat: format);
  @override
  Future<void> setThemeMode(ThemeMode mode) async =>
      state = state.copyWith(themeMode: mode);
  @override
  Future<void> setThemePresetId(String presetId) async =>
      state = state.copyWith(themePresetId: presetId);
  @override
  Future<void> setLocale(String locale) async =>
      state = state.copyWith(locale: locale);
  @override
  Future<void> setDefaultDiveType(String diveType) async =>
      state = state.copyWith(defaultDiveType: diveType);
  @override
  Future<void> setDefaultTankVolume(double volume) async =>
      state = state.copyWith(defaultTankVolume: volume);
  @override
  Future<void> setDefaultStartPressure(int pressure) async =>
      state = state.copyWith(defaultStartPressure: pressure);
  @override
  Future<void> setDefaultTankPreset(String? presetName) async =>
      state = state.copyWith(
        defaultTankPreset: presetName,
        clearDefaultTankPreset: presetName == null,
      );
  @override
  Future<void> setApplyDefaultTankToImports(bool value) async =>
      state = state.copyWith(applyDefaultTankToImports: value);
  @override
  Future<void> setGfLow(int value) async =>
      state = state.copyWith(gfLow: value);
  @override
  Future<void> setGfHigh(int value) async =>
      state = state.copyWith(gfHigh: value);
  @override
  Future<void> setGradientFactors(int low, int high) async =>
      state = state.copyWith(gfLow: low, gfHigh: high);
  @override
  Future<void> setPpO2MaxWorking(double value) async =>
      state = state.copyWith(ppO2MaxWorking: value);
  @override
  Future<void> setPpO2MaxDeco(double value) async =>
      state = state.copyWith(ppO2MaxDeco: value);
  @override
  Future<void> setCnsWarningThreshold(int value) async =>
      state = state.copyWith(cnsWarningThreshold: value);
  @override
  Future<void> setAscentRateWarning(double value) async =>
      state = state.copyWith(ascentRateWarning: value);
  @override
  Future<void> setAscentRateCritical(double value) async =>
      state = state.copyWith(ascentRateCritical: value);
  @override
  Future<void> setShowCeilingOnProfile(bool value) async =>
      state = state.copyWith(showCeilingOnProfile: value);
  @override
  Future<void> setShowAscentRateColors(bool value) async =>
      state = state.copyWith(showAscentRateColors: value);
  @override
  Future<void> setShowNdlOnProfile(bool value) async =>
      state = state.copyWith(showNdlOnProfile: value);
  @override
  Future<void> setLastStopDepth(double value) async =>
      state = state.copyWith(lastStopDepth: value);
  @override
  Future<void> setDecoStopIncrement(double value) async =>
      state = state.copyWith(decoStopIncrement: value);
  @override
  Future<void> setO2Narcotic(bool value) async =>
      state = state.copyWith(o2Narcotic: value);
  @override
  Future<void> setEndLimit(double value) async =>
      state = state.copyWith(endLimit: value);
  @override
  Future<void> setDefaultNdlSource(MetricDataSource value) async =>
      state = state.copyWith(defaultNdlSource: value);
  @override
  Future<void> setDefaultCeilingSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCeilingSource: value);
  @override
  Future<void> setDefaultTtsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultTtsSource: value);
  @override
  Future<void> setDefaultCnsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCnsSource: value);
  @override
  Future<void> setCardColorAttribute(CardColorAttribute attribute) async =>
      state = state.copyWith(cardColorAttribute: attribute);
  @override
  Future<void> setDiveListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveListViewMode: mode);
  @override
  Future<void> setSiteListViewMode(ListViewMode mode) async =>
      state = state.copyWith(siteListViewMode: mode);
  @override
  Future<void> setTripListViewMode(ListViewMode mode) async =>
      state = state.copyWith(tripListViewMode: mode);
  @override
  Future<void> setEquipmentListViewMode(ListViewMode mode) async =>
      state = state.copyWith(equipmentListViewMode: mode);
  @override
  Future<void> setBuddyListViewMode(ListViewMode mode) async =>
      state = state.copyWith(buddyListViewMode: mode);
  @override
  Future<void> setDiveCenterListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveCenterListViewMode: mode);
  @override
  Future<void> setCardColorGradientPreset(String preset) async =>
      state = state.copyWith(cardColorGradientPreset: preset);
  @override
  Future<void> setCardColorGradientCustom(int start, int end) async =>
      state = state.copyWith(
        cardColorGradientPreset: 'custom',
        cardColorGradientStart: start,
        cardColorGradientEnd: end,
      );
  @override
  Future<void> setShowMapBackgroundOnDiveCards(bool value) async =>
      state = state.copyWith(showMapBackgroundOnDiveCards: value);
  @override
  Future<void> setShowMapBackgroundOnSiteCards(bool value) async =>
      state = state.copyWith(showMapBackgroundOnSiteCards: value);
  @override
  Future<void> setTissueColorScheme(TissueColorScheme scheme) async =>
      state = state.copyWith(tissueColorScheme: scheme);
  @override
  Future<void> setTissueVizMode(TissueVizMode mode) async =>
      state = state.copyWith(tissueVizMode: mode);
  @override
  Future<void> setMetric() async => state = state.copyWith(
    depthUnit: DepthUnit.meters,
    temperatureUnit: TemperatureUnit.celsius,
    pressureUnit: PressureUnit.bar,
    volumeUnit: VolumeUnit.liters,
    weightUnit: WeightUnit.kilograms,
  );
  @override
  Future<void> setImperial() async => state = state.copyWith(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
    pressureUnit: PressureUnit.psi,
    volumeUnit: VolumeUnit.cubicFeet,
    weightUnit: WeightUnit.pounds,
  );
  @override
  Future<void> setNotificationsEnabled(bool value) async =>
      state = state.copyWith(notificationsEnabled: value);
  @override
  Future<void> setServiceReminderDays(List<int> days) async =>
      state = state.copyWith(serviceReminderDays: days);
  @override
  Future<void> setReminderTime(TimeOfDay time) async =>
      state = state.copyWith(reminderTime: time);
  @override
  Future<void> toggleReminderDay(int days) async {
    final current = List<int>.from(state.serviceReminderDays);
    if (current.contains(days)) {
      if (current.length > 1) current.remove(days);
    } else {
      current.add(days);
    }
    state = state.copyWith(serviceReminderDays: current);
  }

  @override
  Future<void> setDefaultRightAxisMetric(dynamic metric) async =>
      state = state.copyWith(defaultRightAxisMetric: metric);
  @override
  Future<void> setDefaultShowTemperature(bool value) async =>
      state = state.copyWith(defaultShowTemperature: value);
  @override
  Future<void> setDefaultShowPressure(bool value) async =>
      state = state.copyWith(defaultShowPressure: value);
  @override
  Future<void> setDefaultShowHeartRate(bool value) async =>
      state = state.copyWith(defaultShowHeartRate: value);
  @override
  Future<void> setDefaultShowSac(bool value) async =>
      state = state.copyWith(defaultShowSac: value);
  @override
  Future<void> setDefaultShowEvents(bool value) async =>
      state = state.copyWith(defaultShowEvents: value);
  @override
  Future<void> setDefaultShowGasSwitchMarkers(bool value) async =>
      state = state.copyWith(defaultShowGasSwitchMarkers: value);
  @override
  Future<void> setDefaultShowPpO2(bool value) async =>
      state = state.copyWith(defaultShowPpO2: value);
  @override
  Future<void> setDefaultShowPpN2(bool value) async =>
      state = state.copyWith(defaultShowPpN2: value);
  @override
  Future<void> setDefaultShowPpHe(bool value) async =>
      state = state.copyWith(defaultShowPpHe: value);
  @override
  Future<void> setDefaultShowGasDensity(bool value) async =>
      state = state.copyWith(defaultShowGasDensity: value);
  @override
  Future<void> setDefaultShowGf(bool value) async =>
      state = state.copyWith(defaultShowGf: value);
  @override
  Future<void> setDefaultShowSurfaceGf(bool value) async =>
      state = state.copyWith(defaultShowSurfaceGf: value);
  @override
  Future<void> setDefaultShowMeanDepth(bool value) async =>
      state = state.copyWith(defaultShowMeanDepth: value);
  @override
  Future<void> setDefaultShowTts(bool value) async =>
      state = state.copyWith(defaultShowTts: value);
  @override
  Future<void> setDefaultShowCns(bool value) async =>
      state = state.copyWith(defaultShowCns: value);
  @override
  Future<void> setDefaultShowOtu(bool value) async =>
      state = state.copyWith(defaultShowOtu: value);
  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);
  @override
  Future<void> resetDiveDetailSections() async =>
      state = state.copyWith(clearDiveDetailSections: true);
  @override
  Future<void> setShowDataSourceBadges(bool value) async =>
      state = state.copyWith(showDataSourceBadges: value);
  @override
  Future<void> setShowMaxDepthMarker(bool value) async =>
      state = state.copyWith(showMaxDepthMarker: value);
  @override
  Future<void> setShowPressureThresholdMarkers(bool value) async =>
      state = state.copyWith(showPressureThresholdMarkers: value);
}

/// Mock CurrentDiverIdNotifier that doesn't access the database
class MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

/// Standard test dive with bottomTime for widget testing
Dive createTestDiveWithBottomTime({
  String id = 'test-dive-1',
  int? diveNumber = 1,
  Duration? bottomTime = const Duration(minutes: 45),
  Duration? runtime = const Duration(minutes: 50),
  double? maxDepth = 25.0,
  double? avgDepth = 18.0,
  double? waterTemp = 22.0,
}) {
  return Dive(
    id: id,
    diveNumber: diveNumber,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    exitTime: DateTime(2026, 3, 28, 10, 50),
    bottomTime: bottomTime,
    runtime: runtime,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    waterTemp: waterTemp,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
}

/// Common provider overrides for widget tests
Future<List<Override>> getBaseOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
  ];
}
