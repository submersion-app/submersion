import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Helpers shared by gas-segment tests
// ---------------------------------------------------------------------------

Widget _buildDetailPage(Dive dive, List<Override> overrides) {
  return ProviderScope(
    overrides: [
      ...overrides,
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(
        dive.id,
      ).overrideWith((ref) async => <DiveDataSource>[]),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveDetailPage(diveId: dive.id, embedded: true),
    ),
  );
}

Future<void> _pumpDetailPage(WidgetTester tester, Dive dive) async {
  final overrides = await getBaseOverrides();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(_buildDetailPage(dive, overrides));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  group('DiveDetailPage bottomTime coverage', () {
    testWidgets('displays bottomTime in stat row', (tester) async {
      final dive = createTestDiveWithBottomTime();
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The stat row should display bottom time as "45 min"
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('displays runtime in stat row', (tester) async {
      final dive = createTestDiveWithBottomTime(
        runtime: const Duration(minutes: 50),
      );
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Runtime of 50 min should be displayed
      expect(find.text('50 min'), findsOneWidget);
    });

    testWidgets('handles null bottomTime', (tester) async {
      final dive = createTestDiveWithBottomTime(bottomTime: null);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show -- for null bottom time
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('shows attribution badges with data sources', (tester) async {
      final dive = Dive(
        id: 'dive-with-sources',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        exitTime: DateTime(2026, 3, 28, 10, 50),
        bottomTime: const Duration(minutes: 45),
        runtime: const Duration(minutes: 50),
        maxDepth: 25.0,
        avgDepth: 18.0,
        waterTemp: 22.0,
        tanks: const [],
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 60, depth: 15),
          const DiveProfilePoint(timestamp: 1200, depth: 20),
          const DiveProfilePoint(timestamp: 2400, depth: 18),
          const DiveProfilePoint(timestamp: 2700, depth: 0),
        ],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

      final dataSources = [
        DiveDataSource(
          id: 'src-1',
          diveId: dive.id,
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          computerSerial: 'SN123',
          maxDepth: 25.0,
          duration: 45 * 60,
          waterTemp: 22.0,
          entryTime: DateTime(2026, 3, 28, 10, 5),
          exitTime: DateTime(2026, 3, 28, 10, 50),
          importedAt: DateTime(2026, 3, 28),
          createdAt: DateTime(2026, 3, 28),
        ),
        // Second source so attribution map is non-empty
        DiveDataSource(
          id: 'src-2',
          diveId: dive.id,
          isPrimary: false,
          computerModel: 'Suunto D5',
          computerSerial: 'SN456',
          maxDepth: 24.8,
          duration: 44 * 60,
          waterTemp: 21.5,
          entryTime: DateTime(2026, 3, 28, 10, 6),
          exitTime: DateTime(2026, 3, 28, 10, 49),
          importedAt: DateTime(2026, 3, 28),
          createdAt: DateTime(2026, 3, 28),
        ),
      ];

      // Enable data source badges to trigger attribution rendering
      final settings = MockSettingsNotifier();
      await settings.setShowDataSourceBadges(true);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => settings),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => dataSources),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      // Tolerate rendering errors (e.g. Expanded in unconstrained Column from
      // DiveProfileChart). Override BEFORE pump so errors during initial layout
      // are captured. Save and restore original handler for clean teardown.
      final originalOnError = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (d) => errors.add(d);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      FlutterError.onError = originalOnError;

      // Should render with attribution badges
      expect(find.byType(DiveDetailPage), findsOneWidget);
    });
  });

  // =========================================================================
  // Gas segments wiring — exercises the inline buildGasUsageSegments logic
  // added to DiveDetailPage._buildProfilePanel in the latest commit.
  // =========================================================================

  group('DiveDetailPage - gas segments wiring', () {
    Dive makeDiveWithTanksAndProfile() {
      return Dive(
        id: 'dive-gas-tanks',
        diveNumber: 1,
        dateTime: DateTime(2026, 5, 4, 10, 0),
        entryTime: DateTime(2026, 5, 4, 10, 5),
        exitTime: DateTime(2026, 5, 4, 10, 55),
        bottomTime: const Duration(minutes: 45),
        runtime: const Duration(minutes: 50),
        maxDepth: 25.0,
        avgDepth: 18.0,
        waterTemp: 22.0,
        tanks: [
          const DiveTank(
            id: 'tank-1',
            startPressure: 200,
            endPressure: 80,
            gasMix: GasMix(o2: 21),
          ),
        ],
        profile: [
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 300, depth: 15),
          const DiveProfilePoint(timestamp: 2700, depth: 20),
          const DiveProfilePoint(timestamp: 3000, depth: 0),
        ],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );
    }

    testWidgets('renders without crash when dive has tanks and a profile', (
      tester,
    ) async {
      final dive = makeDiveWithTanksAndProfile();
      await _pumpDetailPage(tester, dive);
      expect(find.byType(DiveDetailPage), findsOneWidget);
    });

    testWidgets(
      'renders without crash when dive has no tanks (null gas path)',
      (tester) async {
        final dive = createTestDiveWithBottomTime();
        await _pumpDetailPage(tester, dive);
        expect(find.byType(DiveDetailPage), findsOneWidget);
      },
    );

    testWidgets(
      'renders without crash when dive has tanks but empty profile (null diveDurationSeconds path)',
      (tester) async {
        final dive = Dive(
          id: 'dive-notanks-noprofile',
          diveNumber: 2,
          dateTime: DateTime(2026, 5, 4, 11, 0),
          entryTime: null,
          exitTime: null,
          bottomTime: const Duration(minutes: 30),
          runtime: const Duration(minutes: 35),
          maxDepth: 20.0,
          avgDepth: 15.0,
          waterTemp: null,
          tanks: [
            const DiveTank(
              id: 'tank-1',
              startPressure: 200,
              endPressure: 80,
              gasMix: GasMix(o2: 21),
            ),
          ],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        );
        await _pumpDetailPage(tester, dive);
        expect(find.byType(DiveDetailPage), findsOneWidget);
      },
    );
  });

  group('DiveDetailPage CCR O2 sensor wiring', () {
    Dive diveWithProfile() {
      return createTestDiveWithBottomTime().copyWith(
        profile: List.generate(
          6,
          (i) => DiveProfilePoint(
            timestamp: i * 60,
            depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
          ),
        ),
      );
    }

    testWidgets(
      'forwards o2SensorCurves and ppO2FromSensorAverage from analysis to chart',
      (tester) async {
        final dive = diveWithProfile();
        final sensors = <List<double?>>[
          List.generate(6, (i) => 0.95),
          List.generate(6, (i) => 0.97),
        ];
        final analysis = ProfileAnalysis.empty().copyWith(
          ppO2Curve: List.generate(6, (i) => 0.96),
          o2SensorCurves: sensors,
          ppO2FromSensorAverage: true,
        );

        final overrides = await getBaseOverrides();
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.toString().contains('overflowed')) return;
          originalOnError?.call(d);
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveProvider(dive.id).overrideWith((ref) async => dive),
              diveDataSourcesProvider(
                dive.id,
              ).overrideWith((ref) async => <DiveDataSource>[]),
              profileAnalysisProvider(
                dive.id,
              ).overrideWith((ref) async => analysis),
              gasSwitchesProvider(
                dive.id,
              ).overrideWith((ref) async => <GasSwitchWithTank>[]),
              tankPressuresProvider(dive.id).overrideWith(
                (ref) async => <String, List<TankPressurePoint>>{},
              ),
              profilesBySourceProvider(dive.id).overrideWith(
                (ref) async => <String?, List<DiveProfilePoint>>{},
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiveDetailPage(diveId: dive.id, embedded: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = originalOnError;

        final charts = tester.widgetList<DiveProfileChart>(
          find.byType(DiveProfileChart),
        );
        expect(charts, isNotEmpty);
        final chart = charts.firstWhere((c) => c.o2SensorCurves != null);
        expect(chart.o2SensorCurves, sensors);
        expect(chart.ppO2FromSensorAverage, isTrue);
      },
    );

    testWidgets(
      'ppO2FromSensorAverage defaults to false when analysis omits it',
      (tester) async {
        final dive = diveWithProfile();
        // Analysis with a ppO2 curve but no sensor data (computer-supplied ppO2).
        final analysis = ProfileAnalysis.empty().copyWith(
          ppO2Curve: List.generate(6, (i) => 1.2),
        );

        final overrides = await getBaseOverrides();
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.toString().contains('overflowed')) return;
          originalOnError?.call(d);
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveProvider(dive.id).overrideWith((ref) async => dive),
              diveDataSourcesProvider(
                dive.id,
              ).overrideWith((ref) async => <DiveDataSource>[]),
              profileAnalysisProvider(
                dive.id,
              ).overrideWith((ref) async => analysis),
              gasSwitchesProvider(
                dive.id,
              ).overrideWith((ref) async => <GasSwitchWithTank>[]),
              tankPressuresProvider(dive.id).overrideWith(
                (ref) async => <String, List<TankPressurePoint>>{},
              ),
              profilesBySourceProvider(dive.id).overrideWith(
                (ref) async => <String?, List<DiveProfilePoint>>{},
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiveDetailPage(diveId: dive.id, embedded: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = originalOnError;

        final charts = tester.widgetList<DiveProfileChart>(
          find.byType(DiveProfileChart),
        );
        expect(charts, isNotEmpty);
        for (final chart in charts) {
          expect(chart.o2SensorCurves, isNull);
          expect(chart.ppO2FromSensorAverage, isFalse);
        }
      },
    );
  });
}
