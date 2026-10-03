import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';

/// The shortcuts that open a sub-page must push rather than go, so the
/// Android system back button can pop them instead of closing the app (#647).
///
/// Tests default to TargetPlatform.android, so platformShortcut() builds
/// Control-based activators here.
void main() {
  late ProviderContainer container;

  Widget host(String label) => Builder(
    builder: (context) {
      container = ProviderScope.containerOf(context);
      return CallbackShortcuts(
        bindings: AppShortcuts.globalBindings(context),
        child: Focus(autofocus: true, child: Text(label)),
      );
    },
  );

  Future<GoRouter> pumpShortcutHost(
    WidgetTester tester, {
    String initialLocation = '/dives',
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) => host('Dive list'),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const Text('New dive')),
          ],
        ),
        GoRoute(path: '/sites', builder: (_, _) => host('Sites')),
      ],
    );
    addTearDown(router.dispose);

    // The app shell always sits under a ProviderScope; the bindings read
    // the Explore platform gate from it.
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
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

    testWidgets('search shortcut opens and focuses the dive search row', (
      tester,
    ) async {
      final router = await pumpShortcutHost(tester);
      await pressControl(tester, LogicalKeyboardKey.digit2);
      expect(locationOf(router), '/sites');

      await pressControl(tester, LogicalKeyboardKey.keyF);

      expect(locationOf(router), '/dives');
      expect(container.read(diveSearchBarOpenProvider), isTrue);
      expect(container.read(diveSearchFocusPendingProvider), isTrue);
    });

    // Code review: the phone map view is /dives?view=map and has no search
    // row, so the shortcut returns to the list instead of doing nothing.
    testWidgets('from the phone map view the search shortcut shows the list', (
      tester,
    ) async {
      final router = await pumpShortcutHost(
        tester,
        initialLocation: '/dives?view=map',
      );
      await pressControl(tester, LogicalKeyboardKey.keyF);
      expect(locationOf(router), '/dives');
      expect(container.read(diveSearchFocusPendingProvider), isTrue);
    });

    testWidgets('on the dive list the search shortcut does not navigate', (
      tester,
    ) async {
      final router = await pumpShortcutHost(tester);
      await pressControl(tester, LogicalKeyboardKey.keyF);
      expect(locationOf(router), '/dives');
      expect(router.routerDelegate.canPop(), isFalse);
      expect(container.read(diveSearchBarOpenProvider), isTrue);
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
