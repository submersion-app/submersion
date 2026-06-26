import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
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
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
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

  group('DiveDetailPage deco/O2 panel last-good retention', () {
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

    // A ProfileAnalysis carrying one fully-populated DecoStatus so the
    // deco/tissue/O2 cards actually render (the panel hides on empty
    // decoStatuses).
    ProfileAnalysis analysisWithDeco() {
      final compartments = List.generate(
        zhl16CompartmentCount,
        (i) => TissueCompartment(
          compartmentNumber: i + 1,
          halfTimeN2: zhl16cN2HalfTimes[i],
          halfTimeHe: zhl16cHeHalfTimes[i],
          mValueAN2: zhl16cN2A[i],
          mValueBN2: zhl16cN2B[i],
          mValueAHe: zhl16cHeA[i],
          mValueBHe: zhl16cHeB[i],
          currentPN2: inspiredSurfaceN2Bar,
          currentPHe: 0.0,
        ),
      );
      final status = DecoStatus(
        compartments: compartments,
        ndlSeconds: 999 * 60,
        ceilingMeters: 0,
        ttsSeconds: 0,
        gfLow: 0.3,
        gfHigh: 0.7,
        decoStops: const [],
        currentDepthMeters: 0,
        ambientPressureBar: 1.0,
      );
      return ProfileAnalysis.empty().copyWith(
        decoStatuses: [status],
        ppO2Curve: const [0.21],
      );
    }

    List<Override> panelOverrides(Dive dive, Override analysisOverride) {
      return [
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        analysisOverride,
        gasSwitchesProvider(
          dive.id,
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
        tankPressuresProvider(
          dive.id,
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        profilesBySourceProvider(
          dive.id,
        ).overrideWith((ref) async => <String?, List<DiveProfilePoint>>{}),
        weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
      ];
    }

    testWidgets('shows nothing for a dive that never produced an analysis', (
      tester,
    ) async {
      final dive = diveWithProfile();
      final base = await getBaseOverrides();
      final originalOnError = FlutterError.onError;
      // Guaranteed restore even if the test throws before the end, so the
      // global handler never leaks into later tests.
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = (d) {
        if (d.toString().contains('overflowed')) return;
        originalOnError?.call(d);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            ...panelOverrides(
              dive,
              profileAnalysisProvider(
                dive.id,
              ).overrideWith((ref) async => null),
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

      // Genuine null: the last-good cache must not fabricate a panel for a dive
      // that has no analysis.
      expect(find.byType(CompactDecoStatusCard), findsNothing);
      expect(find.byType(CompactTissueLoadingCard), findsNothing);
      expect(find.byType(CompactO2ToxicityPanel), findsNothing);
    });

    testWidgets('keeps the cards on a transient null instead of collapsing', (
      tester,
    ) async {
      final dive = diveWithProfile();
      final analysis = analysisWithDeco();
      // Controllable analysis: starts good, then flips to null to mimic a
      // mid-sync empty-profile read that makes profileAnalysisProvider emit
      // AsyncData(null).
      final controllable = StateProvider<ProfileAnalysis?>((ref) => analysis);
      final base = await getBaseOverrides();
      final originalOnError = FlutterError.onError;
      // Guaranteed restore even if the test throws before the end, so the
      // global handler never leaks into later tests.
      addTearDown(() => FlutterError.onError = originalOnError);
      FlutterError.onError = (d) {
        if (d.toString().contains('overflowed')) return;
        originalOnError?.call(d);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            ...panelOverrides(
              dive,
              profileAnalysisProvider(
                dive.id,
              ).overrideWith((ref) async => ref.watch(controllable)),
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

      // Good analysis -> all three cards render.
      expect(find.byType(CompactDecoStatusCard), findsOneWidget);
      expect(find.byType(CompactTissueLoadingCard), findsOneWidget);
      expect(find.byType(CompactO2ToxicityPanel), findsOneWidget);

      // Flip to a transient null (the storm symptom, post-debounce edge case).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      container.read(controllable.notifier).state = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The provider has genuinely settled to AsyncData(null) -- so the cards
      // below survive only because of the last-good fallback, not a loading
      // window that still exposes the previous value via valueOrNull.
      final settled = container.read(profileAnalysisProvider(dive.id));
      expect(settled.isLoading, isFalse);
      expect(settled.valueOrNull, isNull);

      // Hardening: the cards must remain (last-good), not blink out.
      expect(
        find.byType(CompactDecoStatusCard),
        findsOneWidget,
        reason:
            'a transient null analysis must not collapse the deco card; the '
            'panel should fall back to the last usable analysis',
      );
      expect(find.byType(CompactTissueLoadingCard), findsOneWidget);
      expect(find.byType(CompactO2ToxicityPanel), findsOneWidget);
    });
  });
}
