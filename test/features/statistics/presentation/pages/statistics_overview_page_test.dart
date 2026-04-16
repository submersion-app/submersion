import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

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
}

/// Mock CurrentDiverIdNotifier that does not access the database.
class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

void main() {
  group('StatisticsOverviewPage aggregate cards', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders total dives, total time, max depth, and sites', (
      tester,
    ) async {
      final fixture = DiveStatistics(
        totalDives: 42,
        totalTimeSeconds: 108000, // 30h 0m
        maxDepth: 38.5,
        avgMaxDepth: 18.2,
        avgTemperature: 24.0,
        totalSites: 7,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 730)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => fixture),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget); // total dives
      expect(find.textContaining('30h'), findsOneWidget); // total time
      expect(
        find.textContaining('7'),
        findsWidgets,
      ); // sites (may appear elsewhere)
    });
  });

  group('StatisticsOverviewPage Personal Records', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders deepest and longest records', (tester) async {
      final stats = DiveStatistics(
        totalDives: 10,
        totalTimeSeconds: 18000,
        maxDepth: 35.0,
        avgMaxDepth: 20.0,
        totalSites: 3,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      final deepest = DiveRecord(
        diveId: 'd1',
        diveNumber: 5,
        dateTime: DateTime(2025, 1, 10),
        maxDepth: 35.0,
        bottomTime: const Duration(minutes: 40),
      );
      final records = DiveRecords(deepestDive: deepest, longestDive: deepest);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => records),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
    });

    testWidgets('tapping a record navigates to dive detail', (tester) async {
      final stats = DiveStatistics(
        totalDives: 1,
        totalTimeSeconds: 3000,
        maxDepth: 20,
        avgMaxDepth: 20,
        totalSites: 1,
      );
      final deepest = DiveRecord(
        diveId: 'dive-xyz',
        diveNumber: 1,
        dateTime: DateTime(2025, 3, 1),
        maxDepth: 20,
        bottomTime: const Duration(seconds: 3000),
      );
      final records = DiveRecords(deepestDive: deepest);

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(
            path: '/statistics/overview',
            builder: (ctx, s) => const StatisticsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (ctx, state) {
              navigatedTo = '/dives/${state.pathParameters['id']}';
              return const Scaffold(body: Text('Dive Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => records),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deepest Dive'));
      await tester.pumpAndSettle();

      expect(navigatedTo, equals('/dives/dive-xyz'));
    });
  });

  group('StatisticsOverviewPage Most Visited Sites', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders top sites from stats.topSites', (tester) async {
      final stats = DiveStatistics(
        totalDives: 20,
        totalTimeSeconds: 36000,
        maxDepth: 30.0,
        avgMaxDepth: 18.0,
        totalSites: 3,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        topSites: [
          TopSiteStat(siteId: 'site-1', siteName: 'Blue Hole', diveCount: 10),
          TopSiteStat(siteId: 'site-2', siteName: 'Coral Garden', diveCount: 7),
          TopSiteStat(siteId: 'site-3', siteName: 'The Wall', diveCount: 3),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Most Visited Sites'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Coral Garden'), findsOneWidget);
      expect(find.text('The Wall'), findsOneWidget);
    });

    testWidgets('hides section when topSites is empty', (tester) async {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 9000,
        maxDepth: 20.0,
        avgMaxDepth: 15.0,
        totalSites: 0,
        topSites: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Most Visited Sites'), findsNothing);
    });

    testWidgets('tapping a site navigates to site detail', (tester) async {
      final stats = DiveStatistics(
        totalDives: 10,
        totalTimeSeconds: 18000,
        maxDepth: 25.0,
        avgMaxDepth: 15.0,
        totalSites: 1,
        topSites: [
          TopSiteStat(
            siteId: 'site-abc',
            siteName: 'Mystery Cave',
            diveCount: 10,
          ),
        ],
      );

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(
            path: '/statistics/overview',
            builder: (ctx, s) => const StatisticsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/sites/:siteId',
            builder: (ctx, state) {
              navigatedTo = '/sites/${state.pathParameters['siteId']}';
              return const Scaffold(body: Text('Site Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mystery Cave'));
      await tester.pumpAndSettle();

      expect(navigatedTo, equals('/sites/site-abc'));
    });
  });

  group('StatisticsOverviewPage Distributions', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders depth and type pies when data is present', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 15,
        totalTimeSeconds: 27000,
        maxDepth: 30.0,
        avgMaxDepth: 18.0,
        totalSites: 2,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        depthDistribution: [
          DepthRangeStat(label: '0-10m', minDepth: 0, maxDepth: 10, count: 5),
          DepthRangeStat(label: '10-20m', minDepth: 10, maxDepth: 20, count: 7),
          DepthRangeStat(label: '20-30m', minDepth: 20, maxDepth: 30, count: 3),
        ],
      );

      final diveTypes = [
        DistributionSegment(label: 'Recreational', count: 10, percentage: 66.7),
        DistributionSegment(label: 'Technical', count: 5, percentage: 33.3),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            diveTypeDistributionProvider.overrideWith((ref) async => diveTypes),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsOneWidget);
    });

    testWidgets('hides Distributions when totalDives is 0', (tester) async {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsNothing);
    });
  });
}
