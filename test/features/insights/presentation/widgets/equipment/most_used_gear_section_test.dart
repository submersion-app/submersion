import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/most_used_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<List<RankingItem>> Function() load,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: SingleChildScrollView(child: MostUsedGearSection()),
        ),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (c, s) => Text('item ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mostUsedGearProvider.overrideWith((ref) => load())],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows hours on the subtitle', (tester) async {
    await _pump(
      tester,
      () async => [
        RankingItem(
          id: 'a',
          name: 'Apex',
          count: 340,
          value: 412.4,
          subtitle: 'Apeks • regulator',
        ),
      ],
    );
    expect(find.text('Apeks • regulator • 412 hours'), findsOneWidget);
  });

  testWidgets('a row with no recorded time keeps its plain subtitle', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => [
        RankingItem(
          id: 'a',
          name: 'Apex',
          count: 3,
          value: 0,
          subtitle: 'regulator',
        ),
      ],
    );
    expect(find.text('regulator'), findsOneWidget);
  });

  testWidgets('show all expands past ten and show less collapses', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => [
        for (var i = 0; i < 12; i++)
          RankingItem(id: '$i', name: 'item $i', count: 20 - i),
      ],
    );
    expect(find.text('item 11'), findsNothing);
    await tester.ensureVisible(find.text('Show all'));
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('item 11'));
    expect(find.text('item 11'), findsOneWidget);
    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('item 11'), findsNothing);
  });

  testWidgets('a row opens the item page', (tester) async {
    await _pump(
      tester,
      () async => [RankingItem(id: 'a1', name: 'Apex', count: 3)],
    );
    await tester.tap(find.text('Apex'));
    await tester.pumpAndSettle();
    expect(find.text('item a1'), findsOneWidget);
  });
}
