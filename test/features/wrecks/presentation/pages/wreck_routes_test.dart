import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // A local router mirroring the four /wrecks route definitions, so the
  // path-parameter contract is pinned without booting the app shell.
  testWidgets('the wrecks routes parse their path parameters', (tester) async {
    String? seenWreckId;
    String? seenEditId;

    final router = GoRouter(
      initialLocation: '/wrecks',
      routes: [
        GoRoute(
          path: '/wrecks',
          builder: (context, state) => const Scaffold(body: Text('WRECK_LIST')),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  const Scaffold(body: Text('WRECK_NEW')),
            ),
            GoRoute(
              path: ':wreckId',
              builder: (context, state) {
                seenWreckId = state.pathParameters['wreckId'];
                return const Scaffold(body: Text('WRECK_DETAIL'));
              },
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    seenEditId = state.pathParameters['wreckId'];
                    return const Scaffold(body: Text('WRECK_EDIT'));
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('WRECK_LIST'), findsOneWidget);

    // `new` must win over the :wreckId pattern.
    router.go('/wrecks/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_NEW'), findsOneWidget);

    router.go('/wrecks/w-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_DETAIL'), findsOneWidget);
    expect(seenWreckId, 'w-1');

    router.go('/wrecks/w-1/edit');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WRECK_EDIT'), findsOneWidget);
    expect(seenEditId, 'w-1');
  });
}
