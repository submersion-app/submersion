import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/trips/presentation/navigation/open_trip_list.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// "Show these trips" pushes the trip list over the page the link is on,
/// so its back arrow returns there (#3350).
void main() {
  Future<({GoRouter router, ProviderContainer container, List<Object?> extras})>
  pumpHarness(WidgetTester tester) async {
    final extras = <Object?>[];
    final router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    onPressed: () => openTripList(
                      context,
                      ref,
                      const TripFilterState(equipmentId: 'e1'),
                    ),
                    child: const Text('Open'),
                  ),
                  TextButton(
                    onPressed: () => openTripList(
                      context,
                      ref,
                      const TripFilterState(equipmentId: 'e2'),
                    ),
                    child: const Text('Open other'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trips',
          builder: (_, state) {
            extras.add(state.extra);
            return const Scaffold(body: Text('LIST'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    return (router: router, container: container, extras: extras);
  }

  testWidgets('pushes the trip list with the new filter and a return '
      'snapshot of the old one', (tester) async {
    final h = await pumpHarness(tester);
    h.container.read(tripFilterProvider.notifier).state = const TripFilterState(
      equipmentId: 'e0',
    );
    h.container.read(highlightedTripIdProvider.notifier).state = 't0';

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(h.router.canPop(), isTrue, reason: 'the list must be pushed');
    expect(h.container.read(tripFilterProvider).equipmentId, 'e1');
    final ret = h.extras.last! as TripListReturn;
    expect(ret.filter.equipmentId, 'e0');
    expect(ret.highlightedTripId, 't0');
  });

  testWidgets('a double tap opens one list, so one Back returns', (
    tester,
  ) async {
    final h = await pumpHarness(tester);

    // Both taps land before the router rebuilds.
    await tester.tap(find.text('Open'), warnIfMissed: false);
    await tester.tap(find.text('Open'), warnIfMissed: false);
    await tester.pumpAndSettle();

    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(h.router.canPop(), isFalse);
  });

  testWidgets('a different set of trips still opens on top', (tester) async {
    final h = await pumpHarness(tester);

    await tester.tap(find.text('Open'), warnIfMissed: false);
    await tester.tap(find.text('Open other'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(h.container.read(tripFilterProvider).equipmentId, 'e2');
    h.router.pop();
    await tester.pumpAndSettle();
    expect(h.router.canPop(), isTrue, reason: 'the first list is underneath');
  });
}
