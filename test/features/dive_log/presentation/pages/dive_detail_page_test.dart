import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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
  });
}
