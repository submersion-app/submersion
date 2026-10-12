import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/nav_shortcut_pages.dart';

Future<GoRouter> _pump(WidgetTester tester, String initial) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Text('Dashboard'),
          ),
          navShortcutRoute(
            pages: {
              'probe': (query) => Scaffold(
                appBar: AppBar(title: Text('Probe ${query['q'] ?? ''}')),
              ),
            },
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

void main() {
  testWidgets('a shortcut opens as a one-page stack', (tester) async {
    final router = await _pump(tester, '/shortcut/probe');
    expect(find.text('Probe '), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('the page receives the alias query', (tester) async {
    await _pump(tester, '/shortcut/probe?q=x');
    expect(find.text('Probe x'), findsOneWidget);
  });

  testWidgets('an unknown shortcut redirects to the dashboard', (tester) async {
    await _pump(tester, '/shortcut/nope');
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
