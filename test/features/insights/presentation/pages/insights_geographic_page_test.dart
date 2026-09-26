import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/pages/insights_geographic_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/semantics_finders.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<RankingItem>> Function() countries,
    required Future<List<RankingItem>> Function() regions,
    required Future<List<RankingItem>> Function() trips,
    bool embedded = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          countriesVisitedProvider.overrideWith((ref) => countries()),
          regionsExploredProvider.overrideWith((ref) => regions()),
          divesPerTripProvider.overrideWith((ref) => trips()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: embedded
              ? const Scaffold(body: InsightsGeographicPage(embedded: true))
              : const InsightsGeographicPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RankingItem item(String name, int count) =>
      RankingItem(id: name, name: name, count: count);

  testWidgets('summarises each ranking for screen readers', (tester) async {
    await pumpPage(
      tester,
      countries: () async => [item('Bonaire', 12), item('Mexico', 4)],
      regions: () async => [item('Caribbean', 16)],
      trips: () async => [
        item('Klein Bonaire week', 9),
        item('Cozumel', 4),
        item('Cenotes', 3),
      ],
    );

    expect(
      findSemanticsLabelled('2 countries. Top: Bonaire with 12 dives'),
      findsOneWidget,
    );
    expect(
      findSemanticsLabelled('1 regions. Top: Caribbean with 16 dives'),
      findsOneWidget,
    );
    expect(
      findSemanticsLabelled('3 trips. Top: Klein Bonaire week with 9 dives'),
      findsOneWidget,
    );
  });

  testWidgets('an empty ranking reads its empty message', (tester) async {
    await pumpPage(
      tester,
      countries: () async => const [],
      regions: () async => const [],
      trips: () async => const [],
    );

    expect(findSemanticsLabelled('No countries visited'), findsOneWidget);
    expect(findSemanticsLabelled('No regions explored'), findsOneWidget);
    expect(findSemanticsLabelled('No trip data'), findsOneWidget);
  });

  testWidgets('shows a per-section error when a query fails', (tester) async {
    await pumpPage(
      tester,
      countries: () async => throw Exception('countries'),
      regions: () async => throw Exception('regions'),
      trips: () async => throw Exception('trips'),
    );

    expect(find.text('Failed to load country data'), findsOneWidget);
    expect(find.text('Failed to load region data'), findsOneWidget);
    expect(find.text('Failed to load trip data'), findsOneWidget);
  });

  testWidgets('the full page has its own app bar', (tester) async {
    await pumpPage(
      tester,
      countries: () async => const [],
      regions: () async => const [],
      trips: () async => const [],
      embedded: false,
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Geographic'),
      ),
      findsOneWidget,
    );
  });
}
