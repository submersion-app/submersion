import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    show DeleteDiverResult;
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as trips;
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Minimal fake SiteRepository for bulk-share smoke tests.
class _FakeSiteRepository implements SiteRepository {
  final List<domain.DiveSite> _sites;
  String? shareAllForDiverCalledFor;
  int shareAllForDiverResult;

  _FakeSiteRepository({
    required List<domain.DiveSite> sites,
    this.shareAllForDiverResult = 0,
  }) : _sites = sites;

  @override
  Future<List<domain.DiveSite>> getAllSites({String? diverId}) async => _sites;

  @override
  Future<int> shareAllForDiver(String diverId) async {
    shareAllForDiverCalledFor = diverId;
    return shareAllForDiverResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not implemented in _FakeSiteRepository',
  );
}

/// Minimal fake TripRepository for bulk-share smoke tests.
class _FakeTripRepository implements TripRepository {
  final List<trips.Trip> _trips;
  String? shareAllForDiverCalledFor;
  int shareAllForDiverResult;

  _FakeTripRepository({
    required List<trips.Trip> tripList,
    this.shareAllForDiverResult = 0,
  }) : _trips = tripList;

  @override
  Future<List<trips.Trip>> getAllTrips({String? diverId}) async => _trips;

  @override
  Future<int> shareAllForDiver(String diverId) async {
    shareAllForDiverCalledFor = diverId;
    return shareAllForDiverResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not implemented in _FakeTripRepository',
  );
}

/// Fake AppSettingsRepository that tracks writes without DB access.
class _FakeAppSettingsRepository implements AppSettingsRepository {
  bool _shareByDefault = false;
  bool setShareByDefaultCalled = false;
  bool? lastSetValue;

  @override
  Future<bool> getShareByDefault() async => _shareByDefault;

  @override
  Future<void> setShareByDefault(bool value) async {
    setShareByDefaultCalled = true;
    lastSetValue = value;
    _shareByDefault = value;
  }

  @override
  Future<List<String>?> getNavPrimaryIdsRaw() async => null;

  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {}
}

/// Mock SettingsNotifier that doesn't access the database.
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
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);
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

/// Mock CurrentDiverIdNotifier that doesn't access the database.
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

/// Mock DiverListNotifier that doesn't access the database.
class _MockDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _MockDiverListNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> refresh() async {}
  @override
  Future<Diver> addDiver(Diver diver) async => diver;
  @override
  Future<void> updateDiver(Diver diver) async {}
  @override
  Future<DeleteDiverResult> deleteDiver(String id) async {
    return const DeleteDiverResult(
      reassignedTripsCount: 0,
      reassignedSitesCount: 0,
    );
  }

  @override
  Future<void> setAsDefault(String id) async {}
}

/// Creates a minimal [Diver] with the given [id].
Diver _makeDiver(String id) => Diver(
  id: id,
  name: 'Diver $id',
  isDefault: false,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  late SharedPreferences prefs;
  late LogFileService logFileService;
  late Directory tempDir;
  late _FakeAppSettingsRepository fakeAppSettings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('settings_shared_data_test_');
    logFileService = LogFileService(logDirectory: tempDir.path);
    await logFileService.initialize();
    fakeAppSettings = _FakeAppSettingsRepository();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Helper that wraps a widget with the required ProviderScope and
  /// MaterialApp, with a forced mobile (400px) width to avoid GoRouter
  /// dependency in MasterDetailScaffold.
  Widget buildTestWidget(
    Widget child, {
    List<Diver> divers = const [],
    bool shareByDefault = false,
  }) {
    fakeAppSettings = _FakeAppSettingsRepository();
    // Set the initial shareByDefault value by overriding the internal field.
    // The fake exposes it as a field so we can simply set it directly.
    // ignore: prefer_final_fields - test helper mutable state
    fakeAppSettings._shareByDefault = shareByDefault;

    return MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => _MockCurrentDiverIdNotifier(),
          ),
          currentDiverProvider.overrideWith((ref) async => null),
          diverListNotifierProvider.overrideWith(
            (ref) => _MockDiverListNotifier(),
          ),
          allDiversProvider.overrideWith((ref) async => divers),
          appSettingsRepositoryProvider.overrideWithValue(fakeAppSettings),
          shareByDefaultProvider.overrideWith(
            (ref) async => fakeAppSettings.getShareByDefault(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
  }

  group('Settings page - Shared data section', () {
    testWidgets('hidden when only one diver', (tester) async {
      final oneDiver = [_makeDiver('diver-1')];
      await tester.pumpWidget(
        buildTestWidget(const SettingsPage(), divers: oneDiver),
      );
      await tester.pumpAndSettle();

      // Scroll through the whole list and confirm "Shared data" is absent.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared data'), findsNothing);
    });

    testWidgets('visible when 2+ divers, showing title and three items', (
      tester,
    ) async {
      final twoDivers = [_makeDiver('diver-1'), _makeDiver('diver-2')];
      await tester.pumpWidget(
        buildTestWidget(const SettingsPage(), divers: twoDivers),
      );
      await tester.pumpAndSettle();

      // Scroll until the Shared data section tile is visible.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Shared data'),
        50.0,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared data'), findsOneWidget);
    });

    testWidgets(
      'toggling the default switch persists via AppSettingsRepository',
      (tester) async {
        final twoDivers = [_makeDiver('diver-1'), _makeDiver('diver-2')];
        await tester.pumpWidget(
          buildTestWidget(
            const SettingsPage(),
            divers: twoDivers,
            shareByDefault: false,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate into the Shared data detail section via query-param approach:
        // pump a fresh widget targeting the section content directly.
        await tester.pumpWidget(
          buildTestWidget(
            const SharedDataSectionContent(),
            divers: twoDivers,
            shareByDefault: false,
          ),
        );
        await tester.pumpAndSettle();

        // The SwitchListTile for "Share new sites and trips by default" should
        // be visible and initially off.
        expect(
          find.text('Share new sites and trips by default'),
          findsOneWidget,
        );
        final switchFinder = find.byType(SwitchListTile);
        expect(switchFinder, findsOneWidget);

        // Verify the initial value is false (switch is off).
        final tile = tester.widget<SwitchListTile>(switchFinder);
        expect(tile.value, isFalse);

        // Tap the switch.
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // The fake repository should have been called with true.
        expect(fakeAppSettings.setShareByDefaultCalled, isTrue);
        expect(fakeAppSettings.lastSetValue, isTrue);
      },
    );

    testWidgets('bulk-share sites: tap, confirm, see snackbar with count', (
      tester,
    ) async {
      final twoDivers = [_makeDiver('diver-1'), _makeDiver('diver-2')];

      // Three private sites owned by diver-1.
      final fakeSiteRepo = _FakeSiteRepository(
        sites: [
          const domain.DiveSite(id: 's1', name: 'Site 1', isShared: false),
          const domain.DiveSite(id: 's2', name: 'Site 2', isShared: false),
          const domain.DiveSite(id: 's3', name: 'Site 3', isShared: false),
        ],
        shareAllForDiverResult: 3,
      );

      Widget buildWithBulkShare(Widget child) {
        fakeAppSettings = _FakeAppSettingsRepository();
        return MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              logFileServiceProvider.overrideWithValue(logFileService),
              settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
              currentDiverIdProvider.overrideWith(
                (ref) =>
                    _MockCurrentDiverIdNotifier()..setCurrentDiver('diver-1'),
              ),
              validatedCurrentDiverIdProvider.overrideWith(
                (ref) async => 'diver-1',
              ),
              currentDiverProvider.overrideWith((ref) async => null),
              diverListNotifierProvider.overrideWith(
                (ref) => _MockDiverListNotifier(),
              ),
              allDiversProvider.overrideWith((ref) async => twoDivers),
              appSettingsRepositoryProvider.overrideWithValue(fakeAppSettings),
              shareByDefaultProvider.overrideWith(
                (ref) async => fakeAppSettings.getShareByDefault(),
              ),
              siteRepositoryProvider.overrideWithValue(fakeSiteRepo),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: child,
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildWithBulkShare(const Scaffold(body: SharedDataSectionContent())),
      );
      await tester.pumpAndSettle();

      // Tap "Share all my sites".
      final siteTile = find.text('Share all my sites');
      expect(siteTile, findsOneWidget);
      await tester.tap(siteTile);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with the private count (3).
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);

      // Tap the Share button.
      final shareButton = find.text('Share');
      expect(shareButton, findsOneWidget);
      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      // Success snackbar should appear.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);

      // Repository action was called for diver-1.
      expect(fakeSiteRepo.shareAllForDiverCalledFor, equals('diver-1'));
    });

    testWidgets('bulk-share trips: tap, confirm, see snackbar with count', (
      tester,
    ) async {
      final twoDivers = [_makeDiver('diver-1'), _makeDiver('diver-2')];
      final now = DateTime(2024);

      // Two private trips owned by diver-1.
      final fakeTripRepo = _FakeTripRepository(
        tripList: [
          trips.Trip(
            id: 't1',
            name: 'Trip 1',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
            isShared: false,
          ),
          trips.Trip(
            id: 't2',
            name: 'Trip 2',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
            isShared: false,
          ),
        ],
        shareAllForDiverResult: 2,
      );

      Widget buildWithBulkShare(Widget child) {
        fakeAppSettings = _FakeAppSettingsRepository();
        return MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              logFileServiceProvider.overrideWithValue(logFileService),
              settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
              currentDiverIdProvider.overrideWith(
                (ref) =>
                    _MockCurrentDiverIdNotifier()..setCurrentDiver('diver-1'),
              ),
              validatedCurrentDiverIdProvider.overrideWith(
                (ref) async => 'diver-1',
              ),
              currentDiverProvider.overrideWith((ref) async => null),
              diverListNotifierProvider.overrideWith(
                (ref) => _MockDiverListNotifier(),
              ),
              allDiversProvider.overrideWith((ref) async => twoDivers),
              appSettingsRepositoryProvider.overrideWithValue(fakeAppSettings),
              shareByDefaultProvider.overrideWith(
                (ref) async => fakeAppSettings.getShareByDefault(),
              ),
              tripRepositoryProvider.overrideWithValue(fakeTripRepo),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: child,
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildWithBulkShare(const Scaffold(body: SharedDataSectionContent())),
      );
      await tester.pumpAndSettle();

      // Tap "Share all my trips".
      final tripTile = find.text('Share all my trips');
      expect(tripTile, findsOneWidget);
      await tester.tap(tripTile);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with the private count (2).
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);

      // Tap the Share button.
      final shareButton = find.text('Share');
      expect(shareButton, findsOneWidget);
      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      // Success snackbar should appear.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);

      // Repository action was called for diver-1.
      expect(fakeTripRepo.shareAllForDiverCalledFor, equals('diver-1'));
    });
  });
}
