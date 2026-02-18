import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef Override = riverpod.Override;

/// Mock SettingsNotifier that doesn't access the database
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
  Future<void> setCardColorAttribute(CardColorAttribute attribute) async =>
      state = state.copyWith(cardColorAttribute: attribute);
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
  Future<void> setShowMaxDepthMarker(bool value) async =>
      state = state.copyWith(showMaxDepthMarker: value);
  @override
  Future<void> setShowPressureThresholdMarkers(bool value) async =>
      state = state.copyWith(showPressureThresholdMarkers: value);
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

/// Mock DiverListNotifier that doesn't access the database
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
  Future<void> deleteDiver(String id) async {}
  @override
  Future<void> setAsDefault(String id) async {}
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // Set up SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Helper to create common provider overrides for SettingsPage tests
  List<Override> getOverrides() {
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Mock the settingsProvider to avoid database access
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
      // Mock the currentDiverIdProvider to avoid database access
      currentDiverIdProvider.overrideWith(
        (ref) => _MockCurrentDiverIdNotifier(),
      ),
      // Mock currentDiverProvider
      currentDiverProvider.overrideWith((ref) async => null),
      // Mock diverListNotifierProvider
      diverListNotifierProvider.overrideWith((ref) => _MockDiverListNotifier()),
    ];
  }

  /// Builds a test widget with mobile screen size to avoid MasterDetailScaffold
  /// which requires GoRouter. The SettingsPage uses MasterDetailScaffold on
  /// desktop (>=800px) which calls GoRouterState.of(context).
  Widget buildTestWidget(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: ProviderScope(
        overrides: getOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
  }

  group('SettingsPage', () {
    testWidgets('should display Settings title in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display Units section with subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));

      // Mobile layout shows Units section tile
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Measurement preferences'), findsOneWidget);
    });

    testWidgets('should display Appearance section with theme info', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      // Scroll to find Appearance section which may be off screen
      await tester.scrollUntilVisible(
        find.text('Appearance'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme & display'), findsOneWidget);
    });

    testWidgets('should display Manage section with subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));

      // Mobile layout shows section tiles - scroll to find Manage section
      await tester.scrollUntilVisible(
        find.text('Manage'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Manage'), findsOneWidget);
      // The subtitle describes what's in the Manage section
      expect(find.text('Dive types & tank presets'), findsOneWidget);
    });

    testWidgets('should display Data section for backup/restore/storage', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      // Scroll to find Data section
      await tester.scrollUntilVisible(
        find.text('Data'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Backup, restore & storage'), findsOneWidget);
    });

    testWidgets('should display Diver Profile section', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));

      expect(find.text('Diver Profile'), findsOneWidget);
      expect(find.text('Active diver & profiles'), findsOneWidget);
    });

    testWidgets('should display About section', (tester) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      // Scroll to find About section at the bottom
      await tester.scrollUntilVisible(
        find.text('About'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('About'), findsOneWidget);
      expect(find.text('App info & licenses'), findsOneWidget);
    });
  });
}
