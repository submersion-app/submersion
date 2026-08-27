import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';

/// The shortcuts that open a sub-page must push rather than go, so the
/// Android system back button can pop them instead of closing the app (#647).
///
/// Tests default to TargetPlatform.android, so platformShortcut() builds
/// Control-based activators here.
void main() {
  Future<GoRouter> pumpShortcutHost(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) => CallbackShortcuts(
            bindings: AppShortcuts.globalBindings(context),
            child: const Focus(autofocus: true, child: Text('Dive list')),
          ),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const Text('New dive')),
            GoRoute(
              path: 'search',
              builder: (_, _) => const Text('Advanced search'),
            ),
          ],
        ),
        GoRoute(path: '/sites', builder: (_, _) => const Text('Sites')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> pressControl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('AppShortcuts navigation', () {
    testWidgets('new-dive shortcut pushes a poppable sub-page', (tester) async {
      final router = await pumpShortcutHost(tester);

      await pressControl(tester, LogicalKeyboardKey.keyN);

      expect(find.text('New dive'), findsOneWidget);
      // Pushed, not replaced: the list is still underneath to pop back to.
      // This is the property that keeps system back from closing the app.
      expect(router.routerDelegate.canPop(), isTrue);
    });

    testWidgets('search shortcut pushes a poppable sub-page', (tester) async {
      final router = await pumpShortcutHost(tester);

      await pressControl(tester, LogicalKeyboardKey.keyF);

      expect(find.text('Advanced search'), findsOneWidget);
      expect(router.routerDelegate.canPop(), isTrue);
    });

    testWidgets('tab shortcuts still replace rather than stack', (
      tester,
    ) async {
      final router = await pumpShortcutHost(tester);

      await pressControl(tester, LogicalKeyboardKey.digit2);

      expect(locationOf(router), '/sites');
      // go() for tab switches is deliberate: tabs must not stack up.
      expect(router.routerDelegate.canPop(), isFalse);
    });
  });
}
