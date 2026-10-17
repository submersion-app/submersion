import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_route_scope.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// The save and cancel callbacks the edit form was last built with.
void Function(String)? _lastOnSaved;
VoidCallback? _lastOnCancel;

/// One page under one key at both `/a` and `/b`, so the scaffold stays
/// mounted while the address moves away from it, as a hidden Training tab's
/// does.
GoRouter _router({
  required String initialLocation,
  required List<String> detailRequests,
  required bool scoped,
}) {
  Page<void> page() {
    final scaffold = MediaQuery(
      data: const MediaQueryData(size: Size(1200, 800)),
      child: MasterDetailScaffold(
        sectionId: 'a',
        masterBuilder: (_, _, _) => const Text('Master'),
        detailBuilder: (_, id) {
          detailRequests.add(id);
          return Text('Detail $id');
        },
        summaryBuilder: (_) => const Text('Summary'),
        editBuilder: (_, id, onSaved, onCancel) {
          _lastOnSaved = onSaved;
          _lastOnCancel = onCancel;
          return Text('Edit form $id');
        },
        createBuilder: (_, _, _) => const Text('Create form'),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
    return NoTransitionPage<void>(
      key: const ValueKey('host'),
      child: scoped
          ? MasterDetailRouteScope(path: '/a', child: scaffold)
          : scaffold,
    );
  }

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/a', pageBuilder: (_, _) => page()),
      GoRoute(path: '/b', pageBuilder: (_, _) => page()),
    ],
  );
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String initialLocation,
  required List<String> detailRequests,
  bool scoped = true,
}) async {
  final router = _router(
    initialLocation: initialLocation,
    detailRequests: detailRequests,
    scoped: scoped,
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
  testWidgets('keeps its own selection while the address is elsewhere', (
    tester,
  ) async {
    final requests = <String>[];
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1',
      detailRequests: requests,
    );
    expect(find.text('Detail 1'), findsOneWidget);

    router.go('/b?selected=2');
    await tester.pumpAndSettle();

    expect(find.text('Detail 1'), findsOneWidget);
    expect(requests, isNot(contains('2')));
  });

  testWidgets('keeps an open edit form while the address is elsewhere', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1&mode=edit',
      detailRequests: <String>[],
    );
    expect(find.text('Edit form 1'), findsOneWidget);

    router.go('/b');
    await tester.pumpAndSettle();

    expect(find.text('Edit form 1'), findsOneWidget);
  });

  testWidgets('a save that lands while the address is elsewhere goes to its '
      'own address', (tester) async {
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1&mode=edit',
      detailRequests: <String>[],
    );
    router.go('/b?selected=2');
    await tester.pumpAndSettle();

    _lastOnSaved!('1');
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/a?selected=1',
    );
  });

  testWidgets('a cancel that lands while the address is elsewhere goes to '
      'its own address', (tester) async {
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1&mode=edit',
      detailRequests: <String>[],
    );
    router.go('/b?selected=2');
    await tester.pumpAndSettle();

    _lastOnCancel!();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/a?selected=1',
    );
  });

  testWidgets('the add button opens the create form at its own address', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      initialLocation: '/a',
      detailRequests: <String>[],
    );

    // The scaffold swaps its own create handler into the add button; call
    // it directly, since this harness lays the page out wider than its view.
    tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/a?mode=new',
    );
    expect(find.text('Create form'), findsOneWidget);
  });

  testWidgets('follows the address again when it comes back', (tester) async {
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1',
      detailRequests: <String>[],
    );

    router.go('/b?selected=2');
    await tester.pumpAndSettle();
    router.go('/a?selected=3');
    await tester.pumpAndSettle();

    expect(find.text('Detail 3'), findsOneWidget);
  });

  testWidgets('without a scope it follows every address, as before', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      initialLocation: '/a?selected=1',
      detailRequests: <String>[],
      scoped: false,
    );

    router.go('/b?selected=2');
    await tester.pumpAndSettle();

    expect(find.text('Detail 2'), findsOneWidget);
  });
}
