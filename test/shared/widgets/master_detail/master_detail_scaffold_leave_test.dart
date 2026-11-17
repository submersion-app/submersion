import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Changing selection is leaving the record the pane shows (issue #4527):
/// unsaved work held there is asked about first.
void main() {
  late AppExitGuard guard;
  late GoRouter router;

  setUp(() {
    guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (_) async {},
      revealWindow: () async {},
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/test?selected=a',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) => MasterDetailScaffold(
            sectionId: 'test',
            masterBuilder: (_, onItemSelected, _) => Column(
              children: [
                TextButton(
                  onPressed: () => onItemSelected('a'),
                  child: const Text('Row a'),
                ),
                TextButton(
                  onPressed: () => onItemSelected('b'),
                  child: const Text('Row b'),
                ),
              ],
            ),
            detailBuilder: (_, id) => Text('Detail $id'),
            summaryBuilder: (_) => const Text('Summary'),
            editBuilder: (_, id, _, _) => Text('Edit form $id'),
            createBuilder: (_, _, _) => const Text('Create form'),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appExitGuardProvider.overrideWithValue(guard)],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a held blocker that says no keeps the selection', (
    tester,
  ) async {
    var answer = false;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async => answer,
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Row b'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/test?selected=a');
    expect(find.text('Detail a'), findsOneWidget);

    answer = true;
    await tester.tap(find.text('Row b'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/test?selected=b');
  });

  testWidgets('the create button asks the same', (tester) async {
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async => false,
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(find.text('Create form'), findsNothing);
  });

  testWidgets('the row already shown asks nothing: nothing would leave', (
    tester,
  ) async {
    var asked = 0;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async {
          asked++;
          return false;
        },
      ),
    );
    await pump(tester);

    await tester.tap(find.text('Row a'));
    await tester.pumpAndSettle();

    expect(asked, 0);
    expect(router.state.uri.toString(), '/test?selected=a');
  });

  testWidgets('with nothing held selection changes at once', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Row b'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/test?selected=b');
  });
}
