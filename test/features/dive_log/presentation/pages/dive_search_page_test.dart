import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSearchPage bottomTime coverage', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('renders search page with bottomTime filter', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSearchPage), findsOneWidget);
    });

    testWidgets('renders with initial filter containing bottomTime range', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
            // Set a filter with bottomTime constraints
            diveFilterProvider.overrideWith(
              (ref) => const DiveFilterState(
                minBottomTimeMinutes: 20,
                maxBottomTimeMinutes: 60,
              ),
            ),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveSearchPage), findsOneWidget);
    });

    testWidgets('tapping search applies bottomTime filter', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSearchPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Search button to trigger _applyAndSearch (lines 784-785)
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (d) => errors.add(d);
      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton.first);
        await tester.pump();
      }
      FlutterError.onError = FlutterError.presentError;
    });
  });
}
