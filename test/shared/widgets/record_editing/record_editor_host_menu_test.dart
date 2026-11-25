import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'record_editor_host_harness.dart';

/// The editor host's seeds, bar menu, Save result and refusal hook (issue
/// #4527, phase 4, plan 2).
void main() {
  late EditorProbe probe;

  /// What each push of the editor came back with, in order.
  late List<Object?> results;

  setUp(() async {
    await setUpTestDatabase();
    probe = EditorProbe();
    results = [];
  });
  tearDown(() async => tearDownTestDatabase());

  /// The editor pushed over a stand-in list that waits for the push's
  /// result, as the Transmitter card waits for the key editor's.
  Future<void> pump(WidgetTester tester, {String? storedId = 'rec-1'}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('list'),
                TextButton(
                  onPressed: () async =>
                      results.add(await context.push<Object?>('/edit')),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              // The app's leave check, as every editor route has.
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) =>
                  FakeEditorPage(probe: probe, storedId: storedId),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
        ],
        child: RecordEditShortcuts(
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AppBarTextAction barAction(WidgetTester tester, String label) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == label);

  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const ValueKey('field')), value);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('recordEditorMenu')));
    await tester.pumpAndSettle();
  }

  PopupMenuItem<int> operationItem(WidgetTester tester) =>
      tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Fake operation'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );

  group('seeds', () {
    testWidgets('a seeded new record opens with Save enabled', (tester) async {
      probe
        ..initialText = 'seeded'
        ..seedFrom = '';
      await pump(tester, storedId: null);
      expect(barAction(tester, 'Save').onPressed, isNotNull);
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a seed equal to the form is no change', (tester) async {
      probe.seedFrom = '';
      await pump(tester, storedId: null);
      expect(barAction(tester, 'Save').onPressed, isNull);
    });

    testWidgets('a seeded record typed back to its seed is unchanged', (
      tester,
    ) async {
      probe
        ..initialText = 'seeded'
        ..seedFrom = '';
      await pump(tester, storedId: null);
      await type(tester, '');
      expect(barAction(tester, 'Save').onPressed, isNull);
    });
  });

  group('the bar menu', () {
    testWidgets('shows on a stored record', (tester) async {
      probe.operation = () async => false;
      await pump(tester);
      expect(find.byKey(const ValueKey('recordEditorMenu')), findsOneWidget);
    });

    testWidgets('does not show on a new record', (tester) async {
      probe.operation = () async => false;
      await pump(tester, storedId: null);
      expect(find.byKey(const ValueKey('recordEditorMenu')), findsNothing);
    });

    testWidgets('does not show for an editor with no operations', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('recordEditorMenu')), findsNothing);
    });

    testWidgets('its operation is disabled while there are changes', (
      tester,
    ) async {
      probe.operation = () async => true;
      await pump(tester);
      await type(tester, 'changed');
      await openMenu(tester);
      expect(operationItem(tester).enabled, isFalse);
      expect(find.text('Save or cancel your changes first'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await type(tester, 'stored');
      await openMenu(tester);
      expect(operationItem(tester).enabled, isTrue);
      expect(find.text('Save or cancel your changes first'), findsNothing);
    });

    testWidgets('an operation that writes leaves the page', (tester) async {
      var runs = 0;
      probe.operation = () async {
        runs++;
        return true;
      };
      await pump(tester);
      await openMenu(tester);
      await tester.tap(find.text('Fake operation'));
      await tester.pumpAndSettle();
      expect(runs, 1);
      expect(find.byType(FakeEditorPage), findsNothing);
      expect(find.text('list'), findsOneWidget);
      expect(probe.writes, isEmpty);
    });

    testWidgets('an operation that writes nothing keeps the page', (
      tester,
    ) async {
      probe.operation = () async => false;
      await pump(tester);
      await openMenu(tester);
      await tester.tap(find.text('Fake operation'));
      await tester.pumpAndSettle();
      expect(find.byType(FakeEditorPage), findsOneWidget);
    });
  });

  group('the Save result', () {
    testWidgets('Save pops with the editor result', (tester) async {
      probe.savedResult = 'saved!';
      await pump(tester);
      await type(tester, 'changed');
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
      await tester.pumpAndSettle();
      expect(probe.writes, ['rec-1']);
      expect(results, ['saved!']);
    });

    testWidgets('Cancel pops with no result', (tester) async {
      probe.savedResult = 'saved!';
      await pump(tester);
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('Back pops with no result', (tester) async {
      probe.savedResult = 'saved!';
      await pump(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  group('a failed Save', () {
    testWidgets('one the editor shows itself shows no snackbar', (
      tester,
    ) async {
      probe
        ..failWrite = true
        ..handlesFailure = true;
      await pump(tester);
      await type(tester, 'changed');
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
      await tester.pumpAndSettle();
      expect(probe.failures.single, isA<StateError>());
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(FakeEditorPage), findsOneWidget);
      expect(find.text('changed'), findsOneWidget);
      expect(barAction(tester, 'Save').onPressed, isNotNull);
    });

    testWidgets('one the editor does not show still says it failed', (
      tester,
    ) async {
      probe.failWrite = true;
      await pump(tester);
      await type(tester, 'changed');
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
      await tester.pumpAndSettle();
      expect(probe.failures, hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  testWidgets('a page that leaves while it is still being pushed leaves', (
    tester,
  ) async {
    probe.leaveAtStart = true;
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(results, [null]);
  });
}
