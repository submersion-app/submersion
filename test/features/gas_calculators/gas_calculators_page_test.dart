import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculators_page.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_list_content.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_list_content.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// Gas Calculators used to be six tabs inside the Planning detail pane. It is
/// now a pushed page with a split view of its own: the calculators on the
/// left, the selected one filling the pane on the right.
///
/// The tab strip must be gone in every branch, not merely hidden: it was
/// costing the pane about 72px of height on every calculator, which is the
/// reason for the change.
void main() {
  late List<Object> base;

  setUp(() async {
    base = await getBaseOverrides();
  });

  Future<GoRouter> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/planning',
      routes: [
        GoRoute(
          path: '/planning',
          builder: (_, _) => const Scaffold(body: Text('planning hub')),
          routes: [
            GoRoute(
              path: 'gas-calculators',
              builder: (_, _) => const GasCalculatorsPage(),
              routes: [
                for (final id in kGasCalculatorIds)
                  GoRoute(
                    path: id,
                    builder: (_, _) => GasCalculatorDetailPage(toolId: id),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: base.cast(),
      ),
    );
    await tester.pumpAndSettle();

    // GO, mirroring what the Planning tile does for a split-view tool. The
    // verb matters here: see 'the first selection does not re-animate'.
    router.go('/planning/gas-calculators');
    await tester.pumpAndSettle();

    return router;
  }

  group('narrow window', () {
    const narrow = Size(800, 1200);

    testWidgets('shows the six calculators and no tab strip', (tester) async {
      await pumpAt(tester, narrow);

      expect(find.byType(PlanningTile), findsNWidgets(6));
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
    });

    testWidgets('a calculator opens as its own page', (tester) async {
      final router = await pumpAt(tester, narrow);

      await tester.tap(find.text('MOD'));
      await tester.pumpAndSettle();

      expect(find.byType(ModCalculator), findsOneWidget);
      // The list is covered, not split: this is a push, not a selection.
      expect(find.byType(PlanningTile), findsNothing);
      // An imperative push does not move currentConfiguration.uri, so read
      // the pushed match itself.
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/planning/gas-calculators/mod',
      );
    });
  });

  group('split view', () {
    const wide = Size(1400, 1200);

    testWidgets('shows the list and the summary, with no tab strip', (
      tester,
    ) async {
      await pumpAt(tester, wide);

      expect(find.byType(GasCalculatorsListContent), findsOneWidget);
      expect(find.text('Select a calculator to get started'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('a calculator opens beside the list, not over it', (
      tester,
    ) async {
      await pumpAt(tester, wide);

      await tester.tap(find.text('Rock Bottom'));
      await tester.pumpAndSettle();

      expect(find.byType(RockBottomCalculator), findsOneWidget);
      // The list is still there beside it.
      expect(find.byType(PlanningTile), findsNWidgets(6));
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('the chosen calculator rides in the URL', (tester) async {
      final router = await pumpAt(tester, wide);

      await tester.tap(find.text('Rock Bottom'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['calc'],
        'rock-bottom',
      );
    });

    // Regression: the first calculator tapped used to slide the whole page in
    // from the right a second time, then never again. MasterDetailScaffold
    // selects with go(), which keys the page by its path; entering on a push
    // left a generated key, so that first go() swapped one page for another
    // and Flutter animated the swap. Mid-transition both copies are mounted,
    // so counting the list is what tells the two behaviours apart.
    testWidgets('the first selection does not re-animate the page', (
      tester,
    ) async {
      await pumpAt(tester, wide);

      await tester.tap(find.text('Rock Bottom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GasCalculatorsListContent), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(RockBottomCalculator), findsOneWidget);
    });

    // The page is entered from Planning and the nav rail does not highlight
    // it, so the master pane header carries the only way back.
    testWidgets('the master pane offers a way back', (tester) async {
      await pumpAt(tester, wide);

      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('planning hub'), findsOneWidget);
    });
  });
}
