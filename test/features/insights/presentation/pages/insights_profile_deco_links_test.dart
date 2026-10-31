import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Issue #3805: the deco tiles show their number, so each opens its dives in
/// one tap. The rate is a share of two groups, so it opens nothing.
void main() {
  late ProviderContainer container;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) =>
              const Scaffold(body: InsightsProfilePage(embedded: true)),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          decoObligationStatsProvider.overrideWith(
            (ref) async => (decoCount: 2, noDecoCount: 3, unknownCount: 1),
          ),
          decoDiveIdsProvider.overrideWith(
            (ref) async => (
              deco: const ['d1', 'd2'],
              noDeco: const ['n1', 'n2', 'n3'],
              unknown: const ['u1'],
            ),
          ),
          ascentDescentRatesProvider.overrideWith(
            (ref) async => (avgAscent: null, avgDescent: null),
          ),
          timeAtDepthRangesProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(InsightsProfilePage)),
    );
  }

  testWidgets('the Deco tile opens its dives', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    final filter = container.read(diveFilterProvider);
    expect(filter.diveIds, ['d1', 'd2']);
    expect(filter.diveIdsLabel, 'Decompression Obligation: Deco Dives');
  });

  testWidgets('the No deco tile opens its dives', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(container.read(diveFilterProvider).diveIds, ['n1', 'n2', 'n3']);
  });

  testWidgets('the not recorded hint opens its dives', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.textContaining('excluded from the rate'));
    await tester.pumpAndSettle();

    final filter = container.read(diveFilterProvider);
    expect(filter.diveIds, ['u1']);
    expect(filter.diveIdsLabel, 'Decompression Obligation: Not recorded');
  });

  testWidgets('the deco rate tile opens nothing', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('40.0%'));
    await tester.pumpAndSettle();

    expect(find.text('dive list'), findsNothing);
  });

  testWidgets('a deco tile is one stop for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    final nodes = find.semantics.byLabel('Deco Dives: 2');
    expect(nodes, findsOne);
    semantics.dispose();
  });
}
