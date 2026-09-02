import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_marine_life_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/stats',
  routes: [
    GoRoute(
      path: '/stats',
      builder: (context, state) =>
          const Scaffold(body: StatisticsMarineLifePage(embedded: true)),
    ),
    GoRoute(
      path: '/species',
      builder: (context, state) => const Scaffold(body: Text('SPECIES PAGE')),
      routes: [
        GoRoute(
          path: ':speciesId',
          builder: (context, state) => Scaffold(
            body: Text('DETAIL ${state.pathParameters['speciesId']}'),
          ),
        ),
      ],
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testAppRouter(
      router: _router(),
      locale: locale,
      overrides: [
        ...overrides,
        uniqueSpeciesCountProvider.overrideWith((ref) async => 3),
        mostCommonSightingsProvider.overrideWith(
          (ref) async => [
            RankingItem(
              id: 'sp_whale_shark',
              name: 'Whale Shark',
              count: 5,
              subtitle: 'shark',
            ),
          ],
        ),
        bestSitesForMarineLifeProvider.overrideWith(
          (ref) async => <RankingItem>[],
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers a See all species card that opens the Species page', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('See all species'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('see_all_species')));
    await tester.pumpAndSettle();
    expect(find.text('SPECIES PAGE'), findsOneWidget);
  });

  testWidgets('renders the most common species under its localized name', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('de'));

    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('Whale Shark'), findsNothing);
  });

  testWidgets('tapping a ranked species still opens its detail page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });
}
