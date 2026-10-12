import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// A master-detail page PUSHED over another page (a filtered dive list opened
/// from a site, say) changes its own URL for every selection, save and
/// cancel. Doing that with go() erased the page underneath and the back
/// arrow with it (#3292); on a pushed page it must keep the stack.
Future<GoRouter> _pump(
  WidgetTester tester, {
  required String initialLocation,
  double width = 1200,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/root',
        builder: (_, _) => const Scaffold(body: Text('ROOT')),
      ),
      GoRoute(
        path: '/list',
        builder: (context, state) => MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: MasterDetailScaffold(
            sectionId: 'list',
            masterBuilder: (_, onItemSelected, _) => Column(
              children: [
                TextButton(
                  onPressed: () => onItemSelected('a'),
                  child: const Text('Pick a'),
                ),
              ],
            ),
            detailBuilder: (_, id) => Text('DETAIL $id'),
            summaryBuilder: (_) => const Text('SUMMARY'),
            editBuilder: (_, id, onSaved, _) => TextButton(
              onPressed: () => onSaved(id),
              child: const Text('Save'),
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
    ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('MasterDetailScaffold on a pushed page (#3292)', () {
    testWidgets('selecting an item keeps the page underneath', (tester) async {
      final router = await _pump(tester, initialLocation: '/root');
      router.push('/list');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pick a'));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'selection must not go()');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('saving an edit keeps the page underneath', (tester) async {
      final router = await _pump(tester, initialLocation: '/root');
      router.push('/list?selected=a&mode=edit');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL a'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'save must not go()');
    });

    testWidgets('at phone width an item opens on top of the pushed list', (
      tester,
    ) async {
      final router = await _pump(tester, initialLocation: '/root', width: 400);
      router.push('/list');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pick a'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE a'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Pick a'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });
  });

  testWidgets('selecting on a root page still goes', (tester) async {
    final router = await _pump(tester, initialLocation: '/list');

    await tester.tap(find.text('Pick a'));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL a'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
