import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  Future<void> setThemeMode(ThemeMode mode) async =>
      state = state.copyWith(themeMode: mode);
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
  Future<void> setShowDepthColoredDiveCards(bool value) async =>
      state = state.copyWith(showDepthColoredDiveCards: value);
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
      currentDiverIdProvider
          .overrideWith((ref) => _MockCurrentDiverIdNotifier()),
      // Mock currentDiverProvider
      currentDiverProvider.overrideWith((ref) async => null),
      // Mock diverListNotifierProvider
      diverListNotifierProvider.overrideWith((ref) => _MockDiverListNotifier()),
    ];
  }

  group('SettingsPage', () {
    testWidgets('should display Settings title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display Units section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Depth'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
    });

    testWidgets('should display Appearance section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find Appearance section which may be off screen
      await tester.scrollUntilVisible(
        find.text('Appearance'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('should display Manage section with navigation items',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Scroll to find Manage section which may be off screen due to unit tiles
      await tester.scrollUntilVisible(
        find.text('Manage'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Manage'), findsOneWidget);

      // Scroll to find Buddies which may be off screen
      await tester.scrollUntilVisible(
        find.text('Buddies'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Buddies'), findsOneWidget);

      // Scroll to find Certifications which may be off screen
      await tester.scrollUntilVisible(
        find.text('Certifications'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Certifications'), findsOneWidget);

      // Scroll to find Dive Centers which may be off screen
      await tester.scrollUntilVisible(
        find.text('Dive Centers'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dive Centers'), findsOneWidget);
    });

    testWidgets('should display metric/imperial toggle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Find the segmented button for metric/imperial
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('Imperial'), findsOneWidget);
    });

    testWidgets('should show default metric units (m, bar, C)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Default units should be metric
      expect(find.text('m'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('should display Theme & Display navigation item',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find Theme & Display which may be off screen after unit tiles
      await tester.scrollUntilVisible(
        find.text('Theme & Display'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Theme & Display'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
    });
  });
}
