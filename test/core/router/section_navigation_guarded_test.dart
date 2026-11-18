import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/router/section_navigation.dart';

/// A tab's own destination (the rail's Dives, Cmd/Ctrl+1) keeps the same
/// route, so no onExit sees it, yet it drops the list pane's record: work
/// held there is asked about first (issue #4527).
void main() {
  testWidgets('goGuarded asks held work first, and goes once let', (
    tester,
  ) async {
    final guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (_) async {},
      revealWindow: () async {},
    );
    var answer = false;
    var asked = 0;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async {
          asked++;
          return answer;
        },
      ),
    );
    final router = GoRouter(
      initialLocation: '/dives?selected=a',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) => Builder(
            builder: (inner) => TextButton(
              onPressed: () => inner.goGuarded('/dives'),
              child: Text('List ${state.uri.queryParameters['selected']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appExitGuardProvider.overrideWithValue(guard)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('List a'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(router.state.uri.toString(), '/dives?selected=a');

    answer = true;
    await tester.tap(find.text('List a'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/dives');
  });
}
