import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/router/section_navigation.dart';

/// Shell-shaped like the real app: /media and /dives live inside one
/// ShellRoute, and :diveId is a child of /dives.
GoRouter _router({required void Function(BuildContext) onTap}) {
  return GoRouter(
    initialLocation: '/media',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/media',
            builder: (context, state) => Builder(
              builder: (inner) => TextButton(
                onPressed: () => onTap(inner),
                child: const Text('Media'),
              ),
            ),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) => const Text('Dive List'),
            routes: [
              GoRoute(
                path: ':diveId',
                builder: (context, state) => Builder(
                  builder: (inner) => Column(
                    children: [
                      Text('Dive ${state.pathParameters['diveId']}'),
                      TextButton(
                        onPressed: () => inner.push('/trips/t1/gallery'),
                        child: const Text('To Gallery'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/trips/:tripId/gallery',
            builder: (context, state) => Builder(
              builder: (inner) => TextButton(
                onPressed: () => onTap(inner),
                child: const Text('Gallery'),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pushes the target when it is not already in the stack', (
    tester,
  ) async {
    final router = _router(onTap: (c) => c.pushOrReturnTo('/dives/d1'));
    addTearDown(router.dispose);
    await _pump(tester, router);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.text('Dive d1'), findsOneWidget);
    // The originating section is still underneath.
    expect(router.canPop(), isTrue);
  });

  testWidgets('two taps in the same frame do not stack a duplicate page', (
    tester,
  ) async {
    final router = _router(onTap: (c) => c.pushOrReturnTo('/dives/d1'));
    addTearDown(router.dispose);
    await _pump(tester, router);

    // Both taps land before the router rebuilds.
    final button = find.text('Media');
    await tester.tap(button, warnIfMissed: false);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Dive d1'), findsOneWidget);

    // One back press must reach the media section, not a second copy.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Media'), findsOneWidget);
  });

  testWidgets('returns to an already-open page instead of duplicating it', (
    tester,
  ) async {
    final router = _router(onTap: (c) => c.pushOrReturnTo('/dives/d1'));
    addTearDown(router.dispose);
    await _pump(tester, router);

    // media -> dive d1 -> trip gallery, then "go to dive" for d1 again.
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    // Back on the dive, and it is the SAME page: one pop reaches media.
    expect(find.text('Dive d1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Media'), findsOneWidget);
  });
}
