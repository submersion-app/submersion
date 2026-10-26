import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

/// Stands in for a list page's remembered, still-listed record.
final _remembered = StateProvider<AsyncValue<String?>?>((ref) => null);

Future<(GoRouter, ProviderContainer)> _pump(
  WidgetTester tester, {
  String initialLocation = '/items',
  double width = 1200,
  AsyncValue<String?>? remembered,
  Map<String, String> closed = const {},
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(_remembered.notifier).state = remembered;
  container.read(closedPaneRecordProvider.notifier).state = closed;

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/other',
        builder: (_, _) => const Scaffold(body: Text('OTHER')),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Consumer(
            builder: (context, ref, _) => MasterDetailScaffold(
              sectionId: 'items',
              rememberedSelectedId: ref.watch(_remembered),
              masterBuilder: (_, onItemSelected, _) => ListView(
                key: const Key('master-list'),
                children: [
                  TextButton(
                    onPressed: () => onItemSelected('a'),
                    child: const Text('Pick a'),
                  ),
                  TextButton(
                    onPressed: () => onItemSelected(null),
                    child: const Text('Clear'),
                  ),
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 40, child: Text('Row $i')),
                ],
              ),
              detailBuilder: (_, id) => Text('DETAIL $id'),
              summaryBuilder: (_) => const Text('SUMMARY'),
              editBuilder: (_, id, _, _) => Text('EDIT $id'),
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('PAGE ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, container);
}

/// Leaves the list for another section and comes back, which rebuilds the
/// list page from scratch, as a nav-rail tap does.
Future<void> _returnToItems(WidgetTester tester, GoRouter router) async {
  router.go('/other');
  await tester.pumpAndSettle();
  router.go('/items');
  await tester.pumpAndSettle();
}

Map<String, String> _query(GoRouter router) =>
    router.routeInformationProvider.value.uri.queryParameters;

void main() {
  group('MasterDetailScaffold returning to a list (#3301)', () {
    testWidgets('reopens the remembered record', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/other',
        remembered: const AsyncData('a'),
      );
      router.go('/items');
      await tester.pumpAndSettle();

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(_query(router)['selected'], 'a');
    });

    testWidgets('a deselected pane stays closed', (tester) async {
      final (router, container) = await _pump(
        tester,
        initialLocation: '/items?selected=a',
        remembered: const AsyncData('a'),
      );
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(container.read(closedPaneRecordProvider)['items'], 'a');

      await _returnToItems(tester, router);

      expect(find.text('SUMMARY'), findsOneWidget);
      expect(_query(router)['selected'], isNull);
    });

    testWidgets('a different remembered record reopens despite a closed '
        'entry', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/other',
        remembered: const AsyncData('b'),
        closed: const {'items': 'a'},
      );
      router.go('/items');
      await tester.pumpAndSettle();

      expect(find.text('DETAIL b'), findsOneWidget);
    });

    testWidgets('opening a record clears the closed entry', (tester) async {
      final (_, container) = await _pump(
        tester,
        initialLocation: '/items?selected=a',
        closed: const {'items': 'a'},
      );

      expect(container.read(closedPaneRecordProvider), isEmpty);
    });

    testWidgets('an explicit selection wins over the memory', (tester) async {
      final (_, _) = await _pump(
        tester,
        initialLocation: '/items?selected=b',
        remembered: const AsyncData('a'),
      );

      expect(find.text('DETAIL b'), findsOneWidget);
    });

    testWidgets('waits while the list loads, then reopens', (tester) async {
      final (router, container) = await _pump(
        tester,
        remembered: const AsyncLoading(),
      );
      expect(find.text('SUMMARY'), findsOneWidget);

      container.read(_remembered.notifier).state = const AsyncData('a');
      await tester.pumpAndSettle();

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(_query(router)['selected'], 'a');
    });

    testWidgets('a diver who scrolls while the list loads is not interrupted '
        'by the pane opening later', (tester) async {
      final (router, container) = await _pump(
        tester,
        remembered: const AsyncLoading(),
      );
      await tester.drag(
        find.byKey(const Key('master-list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      container.read(_remembered.notifier).state = const AsyncData('a');
      await tester.pumpAndSettle();

      expect(find.text('SUMMARY'), findsOneWidget);
      expect(_query(router)['selected'], isNull);
    });

    testWidgets('a list built under a page of its own leaves that page\'s '
        'address alone', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/items/x?tab=notes',
        remembered: const AsyncData('a'),
      );

      expect(find.text('PAGE x'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/items/x?tab=notes',
      );
    });

    testWidgets('a list built under a page of its own reopens its record '
        'once the diver goes back to it', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/items/x',
        remembered: const AsyncData('a'),
      );

      router.go('/items');
      await tester.pumpAndSettle();

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(_query(router)['selected'], 'a');
    });

    testWidgets('nothing remembered shows the summary', (tester) async {
      final (router, _) = await _pump(
        tester,
        remembered: const AsyncData(null),
      );

      expect(find.text('SUMMARY'), findsOneWidget);
      expect(_query(router)['selected'], isNull);
    });

    testWidgets('an edit form comes back in view mode', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/items?selected=a&mode=edit',
        remembered: const AsyncData('a'),
      );
      expect(find.text('EDIT a'), findsOneWidget);

      await _returnToItems(tester, router);

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(_query(router)['mode'], isNull);
    });

    testWidgets('a narrow window never restores', (tester) async {
      final (router, _) = await _pump(
        tester,
        width: 600,
        remembered: const AsyncData('a'),
      );

      expect(_query(router)['selected'], isNull);
    });

    testWidgets('a pushed list never restores', (tester) async {
      final (router, _) = await _pump(
        tester,
        initialLocation: '/other',
        remembered: const AsyncData('a'),
      );
      router.push('/items');
      await tester.pumpAndSettle();

      expect(find.text('SUMMARY'), findsOneWidget);
    });

    testWidgets('without a remembered id it behaves as before', (tester) async {
      final (router, _) = await _pump(tester);

      expect(find.text('SUMMARY'), findsOneWidget);
      expect(_query(router)['selected'], isNull);
    });
  });
}
