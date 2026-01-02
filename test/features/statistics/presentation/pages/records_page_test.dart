import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/records_page.dart';

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

void main() {
  group('RecordsPage', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    /// Helper to create common provider overrides
    List<Override> getOverrides({
      Future<DiveRecords> Function(Ref)? diveRecordsOverride,
    }) {
      return [
        diveRecordsProvider.overrideWith(
          diveRecordsOverride ?? (ref) async => DiveRecords(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Mock the settingsProvider to avoid database access
        settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
        // Mock the currentDiverIdProvider to avoid database access
        currentDiverIdProvider
            .overrideWith((ref) => _MockCurrentDiverIdNotifier()),
      ];
    }

    testWidgets('should display Dive Records title in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );

      expect(find.text('Dive Records'), findsOneWidget);
    });

    testWidgets('should display empty state when no records exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
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

    testWidgets('should display refresh button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(),
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should display record cards when records exist',
        (tester) async {
      final records = DiveRecords(
        deepestDive: DiveRecord(
          diveId: '1',
          diveNumber: 1,
          dateTime: DateTime(2024, 6, 15),
          maxDepth: 35.0,
          duration: const Duration(minutes: 45),
        ),
        longestDive: DiveRecord(
          diveId: '2',
          diveNumber: 2,
          dateTime: DateTime(2024, 7, 20),
          maxDepth: 20.0,
          duration: const Duration(minutes: 90),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: getOverrides(
            diveRecordsOverride: (ref) async => records,
          ),
          child: const MaterialApp(
            home: RecordsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show record sections
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
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
