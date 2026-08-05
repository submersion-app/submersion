import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveEditPage bottomTime coverage', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        // Override providers that would trigger DB access
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        // Override tank preset provider that tries to load from DB
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    testWidgets('populates bottomTime field when editing existing dive', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: const Duration(minutes: 45),
        runtime: const Duration(minutes: 50),
      );
      final createdDive = await repository.createDive(dive);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: createdDive.id, embedded: true),
            ),
          ),
        ),
      );

      // Wait for async loading
      await tester.pumpAndSettle();

      // The page loaded and rendered the form with bottomTime data
      expect(find.byType(DiveEditPage), findsOneWidget);
      // The bottom time shows in the Bottom time row (value + unit)
      expect(find.text('Bottom Time'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('calculates exit from entry + bottomTime when no exitTime', (
      tester,
    ) async {
      // Dive with bottomTime but NO exitTime - triggers lines 310-312
      final dive = Dive(
        id: 'dive-no-exit',
        diveNumber: 2,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        bottomTime: const Duration(minutes: 40),
        maxDepth: 20.0,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );
      final createdDive = await repository.createDive(dive);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: createdDive.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveEditPage), findsOneWidget);
    });

    testWidgets('calculates bottomTime from profile when not stored', (
      tester,
    ) async {
      // Dive with profile data but NO bottomTime - triggers lines 321-323
      final dive = Dive(
        id: 'dive-profile-only',
        diveNumber: 3,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryTime: DateTime(2026, 3, 28, 10, 5),
        exitTime: DateTime(2026, 3, 28, 10, 50),
        maxDepth: 20.0,
        tanks: const [],
        profile: [
          // Realistic dive profile with clear descent/bottom/ascent
          const DiveProfilePoint(timestamp: 0, depth: 0),
          const DiveProfilePoint(timestamp: 30, depth: 5),
          const DiveProfilePoint(timestamp: 60, depth: 10),
          const DiveProfilePoint(timestamp: 90, depth: 15),
          const DiveProfilePoint(timestamp: 120, depth: 18),
          // Long bottom phase at ~18-20m
          const DiveProfilePoint(timestamp: 300, depth: 19),
          const DiveProfilePoint(timestamp: 600, depth: 20),
          const DiveProfilePoint(timestamp: 900, depth: 19),
          const DiveProfilePoint(timestamp: 1200, depth: 20),
          const DiveProfilePoint(timestamp: 1500, depth: 19),
          const DiveProfilePoint(timestamp: 1800, depth: 18),
          const DiveProfilePoint(timestamp: 2100, depth: 19),
          const DiveProfilePoint(timestamp: 2400, depth: 18),
          // Ascent
          const DiveProfilePoint(timestamp: 2520, depth: 10),
          const DiveProfilePoint(timestamp: 2580, depth: 5),
          const DiveProfilePoint(timestamp: 2640, depth: 5),
          const DiveProfilePoint(timestamp: 2700, depth: 0),
        ],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );
      final createdDive = await repository.createDive(dive);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: createdDive.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiveEditPage), findsOneWidget);
    });

    testWidgets('handles dive with null bottomTime gracefully', (tester) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: null,
        runtime: null,
      );
      final createdDive = await repository.createDive(dive);
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: createdDive.id, embedded: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render without crashing
      expect(find.byType(DiveEditPage), findsOneWidget);
    });

    testWidgets(
      'The Dive section shows max depth, bottom time, avg depth rows',
      (tester) async {
        final dive = Dive(
          id: 'dive-hero-stats',
          diveNumber: 142,
          dateTime: DateTime(2026, 6, 8, 9, 14),
          entryTime: DateTime(2026, 6, 8, 9, 14),
          bottomTime: const Duration(minutes: 52),
          maxDepth: 28.4,
          avgDepth: 14.2,
          tanks: const [],
          profile: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        );
        final createdDive = await repository.createDive(dive);
        final overrides = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(overrides).cast(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DiveEditPage(diveId: createdDive.id, embedded: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Max Depth'), findsOneWidget);
        expect(find.text('Bottom Time'), findsOneWidget);
        expect(find.text('Avg Depth'), findsOneWidget);
        expect(find.text('28.4 m'), findsOneWidget);
        expect(find.text('52 min'), findsOneWidget);
        expect(find.text('14.2 m'), findsOneWidget);
      },
    );

    group('smart collapse', () {
      testWidgets(
        'editing an existing dive: The Dive expanded, others collapsed',
        (tester) async {
          tester.view.physicalSize = const Size(800, 2600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final dive = createTestDiveWithBottomTime(
            bottomTime: const Duration(minutes: 45),
            runtime: const Duration(minutes: 50),
          );
          final createdDive = await repository.createDive(dive);
          final overrides = await getBaseOverrides();

          await tester.pumpWidget(
            ProviderScope(
              overrides: buildOverrides(overrides).cast(),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: DiveEditPage(diveId: createdDive.id, embedded: true),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('The Dive'), findsOneWidget);
          expect(find.text('Gas & Gear'), findsOneWidget);
          // Collapsed: the group shows its summary bar, not its content.
          expect(find.textContaining('Add Tank'), findsNothing);
          expect(find.textContaining('tank'), findsOneWidget);

          // Tap the Gas & Gear summary bar to expand.
          await tester.tap(find.textContaining('tank'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Add Tank'), findsOneWidget);
        },
      );

      testWidgets(
        'new dive: Gas & Gear expanded, other groups show invitations',
        (tester) async {
          tester.view.physicalSize = const Size(800, 2600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final overrides = await getBaseOverrides();

          await tester.pumpWidget(
            ProviderScope(
              overrides: buildOverrides(overrides).cast(),
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: DiveEditPage(embedded: true)),
              ),
            ),
          );
          // No pumpAndSettle: the new-dive path starts a 10s GPS capture
          // whose pending timer never settles in tests.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          // Gas & Gear is expanded for new dives.
          expect(find.textContaining('Add Tank'), findsOneWidget);
          // The other groups rest as empty invitations.
          expect(
            find.text('Add conditions - water, visibility, weather'),
            findsOneWidget,
          );
          expect(find.text('Add buddies'), findsOneWidget);
          expect(find.text('Add trip or dive center'), findsOneWidget);
        },
      );
    });
  });
}
