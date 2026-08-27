import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSummaryWidget bottomTime coverage', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('displays longest dive using runtime when set', (tester) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: null,
        runtime: const Duration(minutes: 123),
        maxDepth: 25.0,
        waterTemp: 22.0,
      );
      await repository.createDive(dive);

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('123 min'), findsOneWidget);
    });

    testWidgets('displays longest dive using bottomTime when runtime is null', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: const Duration(minutes: 45),
        runtime: null,
        maxDepth: 25.0,
        waterTemp: 22.0,
      );
      await repository.createDive(dive);

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('handles empty records', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without crashing
      expect(find.byType(DiveSummaryWidget), findsOneWidget);
    });
  });

  group('DiveSummaryWidget career totals (#808)', () {
    Future<void> pumpWithDiver(WidgetTester tester, Diver? diver) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 247,
                totalTimeSeconds: 669600, // 186h 0m
                maxDepth: 52.0,
                avgMaxDepth: 27.5,
                totalSites: 83,
              ),
            ),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            currentDiverProvider.overrideWith((ref) async => diver),
          ].cast(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds prior dives and time, with a breakdown', (tester) async {
      await pumpWithDiver(
        tester,
        Diver(
          id: '1',
          name: 'Eric Griffin',
          priorDiveCount: 125,
          priorDiveTimeSeconds: 360000, // 100h 0m
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(find.text('372'), findsOneWidget);
      expect(find.text('286h 0m'), findsOneWidget);
      expect(find.text('247 logged + 125 prior'), findsOneWidget);
      expect(find.text('186h 0m logged + 100h 0m prior'), findsOneWidget);
    });

    testWidgets('shows logged totals alone without priors', (tester) async {
      await pumpWithDiver(
        tester,
        Diver(
          id: '1',
          name: 'Eric Griffin',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(find.text('247'), findsOneWidget);
      expect(find.text('186h 0m'), findsOneWidget);
      expect(find.textContaining('prior'), findsNothing);
    });
  });
}
