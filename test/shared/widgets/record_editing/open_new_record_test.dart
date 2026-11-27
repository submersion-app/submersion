import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// An opener with no place of its own to show a new record opens it once
/// created (issue #4527, phase 3, plan 11).
void main() {
  Future<GoRouter> pump(WidgetTester tester, Object? Function() popWith) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/notes',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => openNewRecord(
                context,
                newLocation: '/notes/new',
                recordLocation: (id) => '/notes/$id',
                idOf: (popped) => switch (popped) {
                  final String id => id,
                  (final String id,) => id,
                  _ => null,
                },
              ),
              child: const Text('add'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(popWith()),
                  child: const Text('done'),
                ),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => Text('note ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
      initialLocation: '/notes',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('an id back opens the record', (tester) async {
    await pump(tester, () => 'n1');

    expect(find.text('note n1'), findsOneWidget);
  });

  testWidgets('a record back opens it by the id read from it', (tester) async {
    await pump(tester, () => ('n2',));

    expect(find.text('note n2'), findsOneWidget);
  });

  testWidgets('nothing back stays', (tester) async {
    final router = await pump(tester, () => null);

    expect(find.text('add'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/notes');
  });
  // With the switch off an opener keeps today's behaviour: the form
  // returns, and the record is not opened.
}
