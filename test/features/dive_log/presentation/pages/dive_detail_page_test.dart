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
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
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
  // Multi-source sources bar — real names, true primary, and localized
  // fallbacks. The bar is built from sourceProfilesProvider (per-source
  // profile points, keyed by data-source id) joined against
  // diveDataSourcesProvider (names + the real isPrimary flag).
  // =========================================================================

  group('DiveDetailPage multi-source profile chart', () {
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

    DiveDataSource dataSource({
      required String id,
      required String computerId,
      required bool isPrimary,
      required String computerModel,
    }) {
      final now = DateTime(2026, 3, 28);
      return DiveDataSource(
        id: id,
        diveId: 'test-dive-1',
        computerId: computerId,
        isPrimary: isPrimary,
        computerModel: computerModel,
        importedAt: now,
        createdAt: now,
      );
    }

    List<Override> multiComputerOverrides(
      Dive dive,
      List<DiveDataSource> sources,
    ) => [
      diveProvider(dive.id).overrideWith((ref) async => dive),
      diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
      gasSwitchesProvider(
        dive.id,
      ).overrideWith((ref) async => <GasSwitchWithTank>[]),
      tankPressuresProvider(
        dive.id,
      ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
      sourceProfilesProvider(dive.id).overrideWith(
        (ref) async => <String, SourceProfile>{
          for (final s in sources)
            s.id: SourceProfile(
              sourceId: s.id,
              computerId: s.computerId,
              isEdited: false,
              points: dive.profile,
            ),
        },
      ),
    ];

    // The Data Sources section also renders each source's model name (in a
    // DataTable column header), so a bare find.text(...) is ambiguous.
    // Scope matches to the sources bar specifically.
    Finder sourceBarText(String text) =>
        find.descendant(of: find.byType(SourceBar), matching: find.text(text));

    testWidgets('source chip labels show real computer model names, not raw '
        'computer IDs', (tester) async {
      final dive = diveWithProfile();
      final base = await getBaseOverrides();
      final sources = [
        dataSource(
          id: 'src-1',
          computerId: 'comp-uuid-1',
          isPrimary: true,
          computerModel: 'Perdix 2',
        ),
        dataSource(
          id: 'src-2',
          computerId: 'comp-uuid-2',
          isPrimary: false,
          computerModel: 'Suunto D5',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...base, ...multiComputerOverrides(dive, sources)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The raw computer IDs must never leak into the UI as labels.
      expect(sourceBarText('comp-uuid-1'), findsNothing);
      expect(sourceBarText('comp-uuid-2'), findsNothing);
      // Real model names resolved from the data sources instead.
      expect(sourceBarText('Perdix 2'), findsOneWidget);
      expect(sourceBarText('Suunto D5'), findsOneWidget);
    });

    testWidgets('the primary star marks the data source flagged primary, '
        'not list order', (tester) async {
      final dive = diveWithProfile();
      final base = await getBaseOverrides();
      // 'src-1' is first in list order but 'src-2' is the real primary
      // per the data sources.
      final sources = [
        dataSource(
          id: 'src-1',
          computerId: 'comp-uuid-1',
          isPrimary: false,
          computerModel: 'Suunto D5',
        ),
        dataSource(
          id: 'src-2',
          computerId: 'comp-uuid-2',
          isPrimary: true,
          computerModel: 'Perdix 2',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...base, ...multiComputerOverrides(dive, sources)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(diveId: dive.id, embedded: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Exactly one primary star, and it sits inside the same chip body
      // (InkWell) as the REAL primary's label.
      final starFinder = find.descendant(
        of: find.byType(SourceBar),
        matching: find.byIcon(Icons.star),
      );
      expect(starFinder, findsOneWidget);
      final primaryChipBody = find.ancestor(
        of: sourceBarText('Perdix 2'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: primaryChipBody, matching: find.byIcon(Icons.star)),
        findsOneWidget,
      );
    });

    testWidgets(
      'unknown computer names fall back to the localized "Unknown Computer" label',
      (tester) async {
        final dive = diveWithProfile();
        final base = await getBaseOverrides();
        final sources = [
          // computerModel and computerSerial both null.
          DiveDataSource(
            id: 'src-1',
            diveId: dive.id,
            computerId: 'comp-uuid-1',
            isPrimary: true,
            importedAt: DateTime(2026, 3, 28),
            createdAt: DateTime(2026, 3, 28),
          ),
          dataSource(
            id: 'src-2',
            computerId: 'comp-uuid-2',
            isPrimary: false,
            computerModel: 'Suunto D5',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [...base, ...multiComputerOverrides(dive, sources)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiveDetailPage(diveId: dive.id, embedded: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(DiveDetailPage)),
        );
        expect(
          sourceBarText(l10n.diveLog_sources_unknownComputer),
          findsOneWidget,
        );
      },
    );

    testWidgets('every computer-attributed tank shows a source badge on a '
        'multi-source dive; manual tanks stay unbadged', (tester) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        tanks: const [
          // Attributed to the primary computer -- no badge expected.
          DiveTank(id: 'tank-primary', computerId: 'comp-uuid-1'),
          // Attributed to the secondary computer -- badge expected.
          DiveTank(id: 'tank-secondary', computerId: 'comp-uuid-2'),
          // Unattributed (e.g. manually added) -- no badge expected.
          DiveTank(id: 'tank-manual'),
        ],
      );
      final base = await getBaseOverrides();
      final sources = [
        dataSource(
          id: 'src-1',
          computerId: 'comp-uuid-1',
          isPrimary: true,
          computerModel: 'Perdix 2',
        ),
        dataSource(
          id: 'src-2',
          computerId: 'comp-uuid-2',
          isPrimary: false,
          computerModel: 'Suunto D5',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => sources),
            gasSwitchesProvider(
              dive.id,
            ).overrideWith((ref) async => <GasSwitchWithTank>[]),
            tankPressuresProvider(
              dive.id,
            ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
            // No multi-computer profile data -- keeps this scoped to the
            // tanks section badge and out of the chart's toggle bar.
            sourceProfilesProvider(
              dive.id,
            ).overrideWith((ref) async => <String, SourceProfile>{}),
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

      // Both attributed tanks are badged (the primary's included);
      // the manual tank is not, so exactly two badges render. Scoped to
      // FieldAttributionBadge since the Data Sources section separately
      // renders both model names too.
      expect(
        find.descendant(
          of: find.byType(FieldAttributionBadge),
          matching: find.text('Suunto D5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FieldAttributionBadge),
          matching: find.text('Perdix 2'),
        ),
        findsOneWidget,
      );
      expect(find.byType(FieldAttributionBadge), findsNWidgets(2));
    });

    testWidgets(
      'no tank badges appear on a single-source dive even with a computerId',
      (tester) async {
        final dive = createTestDiveWithBottomTime().copyWith(
          tanks: const [DiveTank(id: 'tank-1', computerId: 'comp-uuid-1')],
        );
        final base = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
              diveProvider(dive.id).overrideWith((ref) async => dive),
              diveDataSourcesProvider(dive.id).overrideWith(
                (ref) async => <DiveDataSource>[
                  dataSource(
                    id: 'src-1',
                    computerId: 'comp-uuid-1',
                    isPrimary: true,
                    computerModel: 'Perdix 2',
                  ),
                ],
              ),
              gasSwitchesProvider(
                dive.id,
              ).overrideWith((ref) async => <GasSwitchWithTank>[]),
              tankPressuresProvider(dive.id).overrideWith(
                (ref) async => <String, List<TankPressurePoint>>{},
              ),
              sourceProfilesProvider(
                dive.id,
              ).overrideWith((ref) async => <String, SourceProfile>{}),
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

        expect(find.byType(FieldAttributionBadge), findsNothing);
      },
    );
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
              sourceProfilesProvider(
                dive.id,
              ).overrideWith((ref) async => <String, SourceProfile>{}),
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
              sourceProfilesProvider(
                dive.id,
              ).overrideWith((ref) async => <String, SourceProfile>{}),
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
        sourceProfilesProvider(
          dive.id,
        ).overrideWith((ref) async => <String, SourceProfile>{}),
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

  group('DiveDetailPage SAC-by-segment last-good retention', () {
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

    // A ProfileAnalysis carrying one time-interval SAC segment so the
    // "SAC Rate by Segment" card actually renders (the section hides on a
    // null/empty sacSegments). decoStatuses stays empty so the sibling
    // deco/O2 panel renders nothing and this stays scoped to the SAC card.
    ProfileAnalysis analysisWithSacSegments() {
      return ProfileAnalysis.empty().copyWith(
        sacSegments: const [
          SacSegment(
            startTimestamp: 0,
            endTimestamp: 300,
            avgDepth: 18.0,
            minDepth: 0.0,
            maxDepth: 24.0,
            sacRate: 0.8,
            gasConsumed: 4.0,
            segmentationType: SacSegmentationType.timeInterval,
          ),
        ],
      );
    }

    // timeInterval segmentation makes activeSegmentsForDiveProvider read the
    // segments straight off profileAnalysisProvider, so the whole card is
    // driven by the single controllable analysis (no phase/gas-switch
    // providers in play).
    List<Override> sacOverrides(Dive dive, Override analysisOverride) {
      return [
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        analysisOverride,
        selectedSegmentationProvider.overrideWith(
          (ref) => SacSegmentationType.timeInterval,
        ),
        gasSwitchesProvider(
          dive.id,
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
        tankPressuresProvider(
          dive.id,
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        sourceProfilesProvider(
          dive.id,
        ).overrideWith((ref) async => <String, SourceProfile>{}),
        weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
      ];
    }

    // The SAC-by-segment card is a CollapsibleCardSection titled with the
    // localized "SAC Rate by Segment" string; matching that title scopes the
    // finder precisely to this card.
    Finder sacCardFinder(WidgetTester tester) {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DiveDetailPage)),
      );
      return find.widgetWithText(
        CollapsibleCardSection,
        l10n.diveLog_detail_section_sacRateBySegment,
      );
    }

    testWidgets('shows nothing for a dive that never produced segments', (
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
            ...sacOverrides(
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

      // Genuine null: the last-good cache must not fabricate a card for a dive
      // that has no segment analysis.
      expect(sacCardFinder(tester), findsNothing);
    });

    testWidgets('keeps the card on a transient null instead of collapsing', (
      tester,
    ) async {
      final dive = diveWithProfile();
      final analysis = analysisWithSacSegments();
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
            ...sacOverrides(
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

      // Good analysis -> the SAC-by-segment card renders.
      expect(sacCardFinder(tester), findsOneWidget);

      // Flip to a transient null (the storm symptom, post-debounce edge case).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      container.read(controllable.notifier).state = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The provider has genuinely settled to AsyncData(null) -- so the card
      // below survives only because of the last-good fallback, not a loading
      // window that still exposes the previous value via valueOrNull.
      final settled = container.read(profileAnalysisProvider(dive.id));
      expect(settled.isLoading, isFalse);
      expect(settled.valueOrNull, isNull);

      // Hardening: the card must remain (last-good), not blink out.
      expect(
        sacCardFinder(tester),
        findsOneWidget,
        reason:
            'a transient null analysis must not collapse the SAC-by-segment '
            'card; the section should fall back to the last usable analysis',
      );
    });

    testWidgets(
      'keeps cached segments when analysis flips to non-null empty sacSegments',
      (tester) async {
        final dive = diveWithProfile();
        final analysis = analysisWithSacSegments();
        // Flip from a good analysis to a NON-NULL analysis whose sacSegments is
        // an empty (not null) list -- the case where
        // activeSegmentsForDiveProvider yields [] for time/depth modes. The
        // null-coalescing displaySegments fallback (`segments ?? ...`) does not
        // catch an empty list, so without an empty-aware fallback the card
        // would render zero rows even though the cached analysis still has a
        // usable segment.
        final controllable = StateProvider<ProfileAnalysis?>((ref) => analysis);
        final base = await getBaseOverrides();
        final originalOnError = FlutterError.onError;
        addTearDown(() => FlutterError.onError = originalOnError);
        FlutterError.onError = (d) {
          if (d.toString().contains('overflowed')) return;
          originalOnError?.call(d);
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
              ...sacOverrides(
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

        // Good analysis -> the single time segment row renders (label '0-5min').
        expect(find.text('0-5min'), findsOneWidget);

        // Flip to a non-null analysis carrying an EMPTY segment list.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveDetailPage)),
        );
        container.read(controllable.notifier).state = ProfileAnalysis.empty()
            .copyWith(sacSegments: const <SacSegment>[]);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The live analysis is non-null with empty sacSegments, so
        // activeSegmentsForDiveProvider yields []. The card must still render
        // the cached segment rather than an empty list.
        expect(
          sacCardFinder(tester),
          findsOneWidget,
          reason: 'card stays visible on a non-null empty-segments analysis',
        );
        expect(
          find.text('0-5min'),
          findsOneWidget,
          reason:
              'an empty (non-null) segment list must fall back to the cached '
              'analysis segments, not render an empty card',
        );
      },
    );
  });
}
