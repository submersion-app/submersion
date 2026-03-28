import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
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

    testWidgets('displays longest dive record with bottomTime', (tester) async {
      // Create a dive with bottomTime to populate the records
      final dive = createTestDiveWithBottomTime(
        bottomTime: const Duration(minutes: 45),
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

      // Should show the longest dive duration
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
}
