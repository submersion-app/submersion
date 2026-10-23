import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

/// "Show these dives" pushes the dive list over the page the link is on,
/// so its back arrow returns there (#2784, #3292).
void main() {
  Future<
    ({
      GoRouter router,
      ProviderContainer container,
      List<String> locations,
      List<Object?> extras,
    })
  >
  pumpHarness(WidgetTester tester) async {
    final locations = <String>[];
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
                    onPressed: () => openDiveList(
                      context,
                      ref,
                      const DiveFilterState(siteId: 's1'),
                    ),
                    child: const Text('Open'),
                  ),
                  TextButton(
                    onPressed: () => openDiveList(
                      context,
                      ref,
                      const DiveFilterState(tripId: 't1'),
                      map: true,
                    ),
                    child: const Text('Open map'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dives',
          builder: (_, state) {
            locations.add(state.uri.toString());
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
    return (
      router: router,
      container: container,
      locations: locations,
      extras: extras,
    );
  }

  testWidgets('pushes the dive list with the new filter and a return '
      'snapshot of the old one', (tester) async {
    final h = await pumpHarness(tester);
    h.container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      buddyId: 'b0',
    );
    h.container.read(highlightedDiveIdProvider.notifier).state = 'd0';

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(h.router.canPop(), isTrue, reason: 'the list must be pushed');
    expect(h.container.read(diveFilterProvider).siteId, 's1');
    expect(
      h.container.read(diveFilterProvider).buddyId,
      isNull,
      reason: 'the filter is replaced, not merged',
    );
    final ret = h.extras.last! as DiveListReturn;
    expect(ret.filter.buddyId, 'b0');
    expect(ret.highlightedDiveId, 'd0');
  });

  // What the diver opens or empties in a pushed list must not change whether
  // the Dives tab reopens its pane on return (#3301).
  testWidgets('the return snapshot carries the tab\'s closed pane', (
    tester,
  ) async {
    final h = await pumpHarness(tester);
    h.container.read(closedPaneRecordProvider.notifier).state = const {
      'dives': 'd0',
    };

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final ret = h.extras.last! as DiveListReturn;
    expect(ret.closedPaneDiveId, 'd0');
  });

  Future<Map<String, String>> restoredClosedPanes(
    WidgetTester tester, {
    required String? snapshot,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late VoidCallback restore;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            restore = DiveListReturn(
              filter: const DiveFilterState(),
              highlightedDiveId: null,
              closedPaneDiveId: snapshot,
            ).bindRestore(ref);
            return const SizedBox();
          },
        ),
      ),
    );
    // The pushed list emptied its pane on another dive.
    container.read(closedPaneRecordProvider.notifier).state = const {
      'dives': 'other',
      'sites': 's1',
    };
    restore();
    return container.read(closedPaneRecordProvider);
  }

  testWidgets('going away puts the tab\'s closed pane back', (tester) async {
    expect(await restoredClosedPanes(tester, snapshot: 'd0'), {
      'dives': 'd0',
      'sites': 's1',
    });
  });

  testWidgets('going away clears a closed pane the tab did not have', (
    tester,
  ) async {
    expect(await restoredClosedPanes(tester, snapshot: null), {'sites': 's1'});
  });

  testWidgets('map: true pushes the map view', (tester) async {
    final h = await pumpHarness(tester);

    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();

    expect(h.locations.last, '/dives?view=map');
    expect(h.router.canPop(), isTrue);
    expect(h.container.read(diveFilterProvider).tripId, 't1');
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

  testWidgets('a different set of dives still opens on top', (tester) async {
    final h = await pumpHarness(tester);

    await tester.tap(find.text('Open'), warnIfMissed: false);
    await tester.tap(find.text('Open map'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(h.locations, contains('/dives?view=map'));
    h.router.pop();
    await tester.pumpAndSettle();
    expect(h.router.canPop(), isTrue, reason: 'the first list is underneath');
    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
