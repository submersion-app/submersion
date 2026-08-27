import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/records_page.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  /// Already "loaded": the mock's state is supplied up front.
  @override
  Future<void> get initialLoad async {}

  @override
  Future<void> setAccentNavIcons(bool value) async =>
      state = state.copyWith(accentNavIcons: value);

  @override
  Future<void> setAccentSectionHeaders(bool value) async =>
      state = state.copyWith(accentSectionHeaders: value);

  @override
  Future<void> setAccentListIcons(bool value) async =>
      state = state.copyWith(accentListIcons: value);

  @override
  Future<void> setSeascapeAppearance(SeascapeAppearance appearance) async =>
      state = state.copyWith(seascapeAppearance: appearance);

  @override
  Future<void> setChamberHidden(String chamberId, bool hidden) async {
    final ids = {...state.hiddenChamberIds};
    if (hidden) {
      ids.add(chamberId);
    } else {
      ids.remove(chamberId);
    }
    state = state.copyWith(hiddenChamberIds: ids);
  }

  @override
  Future<void> setEmergencyRegion(String? countryCode) async =>
      state = countryCode == null
      ? state.copyWith(clearEmergencyRegion: true)
      : state.copyWith(emergencyRegion: countryCode);

  @override
  Future<void> setDefaultShowGasTimeline(bool value) async =>
      state = state.copyWith(defaultShowGasTimeline: value);
  @override
  Future<void> setDefaultShowAscentRateLine(bool value) async =>
      state = state.copyWith(defaultShowAscentRateLine: value);
  @override
  Future<void> setDefaultShowPhotoMarkers(bool value) async =>
      state = state.copyWith(defaultShowPhotoMarkers: value);
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
  Future<void> setGasModel(GasModel model) async =>
      state = state.copyWith(gasModel: model);

  @override
  Future<void> setDefaultCurrency(String currencyCode) async =>
      state = state.copyWith(defaultCurrency: currencyCode);
  @override
  Future<void> setVisibilityScale({
    required VisibilityScalePreset preset,
    double? excellentM,
    double? goodM,
    double? moderateM,
  }) async => state = state.copyWith(
    visibilityScalePreset: preset,
    visibilityScaleExcellentM: excellentM,
    visibilityScaleGoodM: goodM,
    visibilityScaleModerateM: moderateM,
  );
  @override
  Future<void> setAltitudeUnit(AltitudeUnit unit) async =>
      state = state.copyWith(altitudeUnit: unit);
  @override
  Future<void> setCoordinateFormat(CoordinateFormat format) async =>
      state = state.copyWith(coordinateFormat: format);
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
  Future<void> setPlaceNameLanguage(String code) async =>
      state = state.copyWith(placeNameLanguage: code);
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
  Future<void> setShowDecoStopsOnProfile(bool value) async =>
      state = state.copyWith(showDecoStopsOnProfile: value);
  @override
  Future<void> setSafetyReviewEnabled(bool value) async =>
      state = state.copyWith(safetyReviewEnabled: value);
  @override
  Future<void> setNoFlyPreset(NoFlyPreset preset) async =>
      state = state.copyWith(noFlyPreset: preset);
  @override
  Future<void> setHomeChipEnabled(String chipId, bool enabled) async {
    final hidden = {...state.hiddenHomeChips};
    if (enabled) {
      hidden.remove(chipId);
    } else {
      hidden.add(chipId);
    }
    state = state.copyWith(hiddenHomeChips: hidden);
  }

  @override
  Future<void> setHomeCardEnabled(String cardId, bool enabled) async {
    final hidden = {...state.hiddenHomeCards};
    if (enabled) {
      hidden.remove(cardId);
    } else {
      hidden.add(cardId);
    }
    state = state.copyWith(hiddenHomeCards: hidden);
  }

  @override
  Future<void> setHomeCardOrder(List<String> order) async =>
      state = state.copyWith(homeCardOrder: order);

  @override
  Future<void> resetHomeCards() async => state = state.copyWith(
    homeCardOrder: const <String>[],
    hiddenHomeCards: const <String>{},
  );

  @override
  Future<void> setSafetyRuleEnabled(SafetyRuleId rule, bool enabled) async {
    final rules = {...state.safetyReviewDisabledRules};
    if (enabled) {
      rules.remove(rule.dbValue);
    } else {
      rules.add(rule.dbValue);
    }
    state = state.copyWith(safetyReviewDisabledRules: rules);
  }

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
  Future<void> setPscrRatio(double value) async =>
      state = state.copyWith(pscrRatio: value);
  @override
  Future<void> setO2Narcotic(bool value) async =>
      state = state.copyWith(o2Narcotic: value);
  @override
  Future<void> setEndLimit(double value) async =>
      state = state.copyWith(endLimit: value);
  @override
  Future<void> setAscentGasSet(AscentGasSet value) async =>
      state = state.copyWith(ascentGasSet: value);
  @override
  Future<void> setDefaultNdlSource(MetricDataSource value) async =>
      state = state.copyWith(defaultNdlSource: value);
  @override
  Future<void> setDefaultCeilingSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCeilingSource: value);
  @override
  Future<void> setDefaultDecoStopSource(MetricDataSource value) async =>
      state = state.copyWith(defaultDecoStopSource: value);
  @override
  Future<void> setDefaultTtsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultTtsSource: value);
  @override
  Future<void> setDefaultCnsSource(MetricDataSource value) async =>
      state = state.copyWith(defaultCnsSource: value);
  @override
  Future<void> setCnsCalculationMethod(CnsCalculationMethod value) async =>
      state = state.copyWith(cnsCalculationMethod: value);
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
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);
  @override
  Future<void> setSiteMatchSensitivity(SiteMatchSensitivity value) async =>
      state = state.copyWith(siteMatchSensitivity: value);
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
  Future<void> setShowMaxDepthMarker(bool value) async =>
      state = state.copyWith(showMaxDepthMarker: value);
  @override
  Future<void> setShowPressureThresholdMarkers(bool value) async =>
      state = state.copyWith(showPressureThresholdMarkers: value);
  @override
  Future<void> setShowDetailsPaneForSection(
    String sectionKey,
    bool value,
  ) async {}
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
  Future<void> setTripServiceLeadDays(int days) async =>
      state = state.copyWith(tripServiceLeadDays: days);
  @override
  Future<void> toggleReminderDay(int days) async {
    final current = List<int>.from(state.serviceReminderDays);
    if (current.contains(days)) {
      if (current.length > 1) {
        current.remove(days);
      }
    } else {
      current.add(days);
    }
    state = state.copyWith(serviceReminderDays: current);
  }

  // Profile chart default metric setters
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
  Future<void> setDefaultShowO2CellMv(bool value) async =>
      state = state.copyWith(defaultShowO2CellMv: value);
  @override
  Future<void> setDefaultShowEstimatedTankPressure(bool value) async =>
      state = state.copyWith(defaultShowEstimatedTankPressure: value);
  @override
  Future<void> setShowDataSourceBadges(bool value) async =>
      state = state.copyWith(showDataSourceBadges: value);
  @override
  Future<void> setShowProfilePanelInTableView(bool value) async =>
      state = state.copyWith(showProfilePanelInTableView: value);
  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);
  @override
  Future<void> resetDiveDetailSections() async =>
      state = state.copyWith(clearDiveDetailSections: true);

  @override
  Future<void> setFullscreenReadoutCardPosition(double x, double y) async =>
      state = state.copyWith(
        fullscreenReadoutCardX: x,
        fullscreenReadoutCardY: y,
      );

  @override
  Future<void> setProfileMetricsFollowViewport(bool value) async =>
      state = state.copyWith(profileMetricsFollowViewport: value);

  @override
  Future<void> setPerdixOverlayEnabled(bool value) async =>
      state = state.copyWith(perdixOverlayEnabled: value);

  @override
  Future<void> setPerdixOverlayPosition(double x, double y) async =>
      state = state.copyWith(
        // Mirror SettingsNotifier: clamp to the 0..1 fraction contract and
        // canonicalize non-finite values to the top-right default corner.
        perdixOverlayX: x.isFinite ? x.clamp(0.0, 1.0) : 1.0,
        perdixOverlayY: y.isFinite ? y.clamp(0.0, 1.0) : 0.0,
      );
}

/// Mock CurrentDiverIdNotifier that doesn't access the database
class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async {
    state = id;
  }

  @override
  Future<void> clearCurrentDiver() async {
    state = null;
  }
}

void main() {
  group('RecordsPage', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    /// Helper to create common provider overrides.
    ///
    /// [filter] drives the Statistics scope the page now follows (issue
    /// #1028); an active one also makes StatisticsFilterBar read the filtered
    /// statistics, hence the paired override.
    List<Override> getOverrides({
      Future<DiveRecords> Function(Ref)? diveRecordsOverride,
      DiveFilterState filter = const DiveFilterState(),
    }) {
      return [
        filteredDiveRecordsProvider.overrideWith(
          diveRecordsOverride ?? (ref) async => DiveRecords(),
        ),
        statisticsFilterProvider.overrideWith((ref) => filter),
        filteredDiveStatisticsProvider.overrideWith(
          (ref) async => DiveStatistics(
            totalDives: 0,
            totalTimeSeconds: 0,
            maxDepth: 0,
            avgMaxDepth: 0,
            totalSites: 0,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Mock the settingsProvider to avoid database access
        settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
        // Mock the currentDiverIdProvider to avoid database access
        currentDiverIdProvider.overrideWith(
          (ref) => _MockCurrentDiverIdNotifier(),
        ),
      ];
    }

    testWidgets('should display Dive Records title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );

      expect(find.text('Dive Records'), findsOneWidget);
    });

    testWidgets('should display empty state when no records exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Records Yet'), findsOneWidget);
      expect(
        find.text('Start logging dives to see your records here'),
        findsOneWidget,
      );
    });

    // Issue #1028: the page follows the Statistics filter, so an empty result
    // can mean "the filter is too narrow" rather than "no dives logged".
    testWidgets('shows the filtered empty state when a filter is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(
            filter: const DiveFilterState(favoritesOnly: true),
          ),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives match your filters'), findsOneWidget);
      expect(find.text('No Records Yet'), findsNothing);
    });

    testWidgets('hosts the filter bar, collapsed while no filter is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatisticsFilterBar), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsNothing);
    });

    testWidgets('shows the filter bar summary while a filter is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(
            filter: const DiveFilterState(favoritesOnly: true),
          ),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('should display refresh button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should display record cards when records exist', (
      tester,
    ) async {
      final records = DiveRecords(
        deepestDive: DiveRecord(
          diveId: '1',
          diveNumber: 1,
          dateTime: DateTime(2024, 6, 15),
          maxDepth: 35.0,
          bottomTime: const Duration(minutes: 45),
        ),
        longestDive: DiveRecord(
          diveId: '2',
          diveNumber: 2,
          dateTime: DateTime(2024, 7, 20),
          maxDepth: 20.0,
          bottomTime: const Duration(minutes: 90),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(diveRecordsOverride: (ref) async => records),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show record sections
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
    });

    // firstDive/lastDive carry no field predicate, so a dive logged with only
    // a date populates the milestones while every superlative stays null. The
    // page must not call that "no records".
    testWidgets('shows milestones when only first and last dive are known', (
      tester,
    ) async {
      final records = DiveRecords(
        firstDive: DiveRecord(
          diveId: '1',
          diveNumber: 1,
          dateTime: DateTime(2024, 6, 15),
        ),
        lastDive: DiveRecord(
          diveId: '2',
          diveNumber: 2,
          dateTime: DateTime(2024, 7, 20),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(diveRecordsOverride: (ref) async => records),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Records Yet'), findsNothing);
      expect(find.text('First Dive'), findsOneWidget);
      expect(find.text('Most Recent Dive'), findsOneWidget);
    });

    testWidgets('shows the shallowest dive card when it is the only record', (
      tester,
    ) async {
      final records = DiveRecords(
        shallowestDive: DiveRecord(
          diveId: '1',
          diveNumber: 1,
          dateTime: DateTime(2024, 6, 15),
          maxDepth: 6.0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(diveRecordsOverride: (ref) async => records),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Records Yet'), findsNothing);
      expect(find.text('Shallowest Dive'), findsOneWidget);
    });

    testWidgets('should display error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(
            diveRecordsOverride: (ref) async {
              throw Exception('Failed to load records');
            },
          ),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error loading records'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
