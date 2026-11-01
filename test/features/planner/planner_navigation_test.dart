import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/planner/presentation/planner_navigation.dart';

/// Opening the planner from a dive (issue #3565): the router nests the
/// planning section in its own shell inside the main one, as the app does.
void main() {
  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            ShellRoute(
              pageBuilder: (context, state, child) =>
                  NoTransitionPage(key: state.pageKey, child: child),
              routes: [
                GoRoute(
                  path: '/planning',
                  builder: (_, _) => const Text('HUB'),
                  routes: [
                    GoRoute(
                      path: 'dive-planner',
                      builder: (_, _) => const Text('PLANNER'),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/dives',
              builder: (_, _) => const Text('LIST'),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, _) => TextButton(
                    onPressed: () => openDivePlanner(context),
                    child: const Text('PLAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('from a dive it pushes the planner, so Back returns', (
    tester,
  ) async {
    final router = await pump(tester);
    router.push('/dives/d1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAN'));
    await tester.pumpAndSettle();
    expect(find.text('PLANNER'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('from a dive opened from the planner it does not stack a '
      'second planner', (tester) async {
    final router = await pump(tester);
    router.push('/dives/d1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAN'));
    await tester.pumpAndSettle();
    // A dive opened from inside the planner, such as Open in dive log.
    router.push('/dives/d1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAN'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PLANNER'), findsOneWidget);
  });
}
