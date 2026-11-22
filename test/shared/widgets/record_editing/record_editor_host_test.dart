import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../helpers/mock_providers.dart';
import 'record_editor_host_harness.dart';
import '../../../helpers/test_database.dart';

void main() {
  late EditorProbe probe;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    probe = EditorProbe();
  });
  tearDown(() async => tearDownTestDatabase());

  /// The editor pushed over a stand-in list. [shell] puts both in a shell
  /// navigator, as the app's preset routes are, so a dialog opens above
  /// it in the root one; [onExit] gives the editor's route the app's leave
  /// check, as the app's routes have.
  Future<FakeEditorState> pump(
    WidgetTester tester, {
    String? storedId = 'rec-1',
    bool shell = false,
    bool onExit = false,
    String? diver = 'a',
    Future<void> Function()? beforeEdit,
  }) async {
    final list = GoRoute(
      path: shell ? 'list' : '/',
      builder: (_, _) => const Scaffold(body: Text('list')),
      routes: [
        GoRoute(
          path: 'edit',
          onExit: onExit ? confirmLeaveRecordSitting : null,
          builder: (_, _) => FakeEditorPage(probe: probe, storedId: storedId),
        ),
      ],
    );
    // In the shell the list sits over a page of its own, as the app's
    // preset lists sit over Settings.
    router = GoRouter(
      routes: shell
          ? [
              ShellRoute(
                builder: (_, _, child) => child,
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const Scaffold(body: Text('home')),
                    routes: [list],
                  ),
                ],
              ),
            ]
          : [list],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async {
            probe.diverReadInScope.add(ChangeLogScope.currentOperationId);
            final current = ref.watch(currentDiverIdProvider);
            if (probe.diverFails) throw StateError('database closed');
            final resolved = probe.resolveDiver?.call(current) ?? current;
            final gate = probe.diverGate;
            return gate == null ? resolved : gate.future;
          }),
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
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    if (diver != null) {
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(diver);
    }
    if (shell) {
      router.push('/list');
      await tester.pumpAndSettle();
    }
    await beforeEdit?.call();
    router.push(shell ? '/list/edit' : '/edit');
    await tester.pumpAndSettle();
    return tester.state<FakeEditorState>(find.byType(FakeEditorPage));
  }

  AppBarTextAction saveButton(WidgetTester tester) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == 'Save');

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const ValueKey('field')), value);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the tinted bar with Save disabled and no back arrow', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('typing enables Save; typing it back disables it again', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    expect(saveButton(tester).onPressed, isNotNull);
    await type(tester, 'stored');
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Cancel with no change closes at once, asking nothing', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(find.byType(FakeEditorPage), findsNothing);
  });

  testWidgets('Cancel with a change asks; Keep editing keeps the text', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);
  });

  testWidgets('Back with a change asks; Discard leaves one page only', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(probe.writes, isEmpty);
  });

  testWidgets('Save writes once, in one change log operation, then leaves', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    await tapSave(tester);
    expect(probe.writes, ['rec-1']);
    expect(probe.afterSaved, 1);
    final label = RecordEditLabel.decode(probe.operationLabels.single!);
    expect(label?.table, 'fake');
    expect(label?.id, 'rec-1');
    expect(label?.cardIds, isEmpty);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('Save tapped twice writes once', (tester) async {
    final state = await pump(tester);
    await type(tester, 'changed');
    unawaited(state.saveEditor());
    unawaited(state.saveEditor());
    await tester.pumpAndSettle();
    expect(probe.writes, ['rec-1']);
  });

  testWidgets('validateEditor false writes nothing and stays', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.valid = false;
    await tapSave(tester);
    expect(probe.writes, isEmpty);
    expect(find.byType(FakeEditorPage), findsOneWidget);
  });

  testWidgets('a write that throws stays with the text and says it failed', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.failWrite = true;
    await tapSave(tester);
    expect(find.byType(FakeEditorPage), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FakeEditorPage)),
    );
    expect(find.text(l10n.recordEdit_saveFailed), findsOneWidget);
  });

  testWidgets('a new record writes under its own new id', (tester) async {
    final state = await pump(tester, storedId: null);
    expect(saveButton(tester).onPressed, isNull);
    await type(tester, 'typed');
    await tapSave(tester);
    expect(probe.writes, [state.newEditorRecordId]);
    expect(state.newEditorRecordId, hasLength(36));
  });

  testWidgets('the app exit guard asks while there is a change', (
    tester,
  ) async {
    await pump(tester);
    final guard = container.read(appExitGuardProvider);
    expect(await guard.mayLeave(), isTrue);
    await type(tester, 'changed');
    final leaving = guard.mayLeave();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);
    expect(find.text('changed'), findsOneWidget);
  });

  testWidgets('a change of active diver closes a clean editor', (tester) async {
    await pump(tester);
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('a change of active diver closes a changed new record, '
      'writing nothing', (tester) async {
    await pump(tester, storedId: null);
    await type(tester, 'typed');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(probe.writes, isEmpty);
  });

  testWidgets('a page with nothing under it saves and stays', (tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => FakeEditorPage(probe: probe),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await type(tester, 'changed');
    await tapSave(tester);
    expect(tester.takeException(), isNull);
    expect(probe.writes, ['rec-1']);
    expect(find.byType(FakeEditorPage), findsOneWidget);
  });

  testWidgets('the diver is read before the write, outside its transaction', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    await tapSave(tester);
    expect(probe.diversSeen, ['a']);
    expect(probe.diverReadInScope, isNotEmpty);
    expect(probe.diverReadInScope, everyElement(isNull));
  });

  testWidgets('a diver change during a Save that fails closes the editor', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    probe
      ..failWrite = true
      ..duringWrite = () =>
          container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tapSave(tester);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('an afterEditorSaved that throws still leaves', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.failAfterSaved = true;
    await tapSave(tester);
    expect(probe.writes, ['rec-1']);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('a page with nothing under it leaves to its leave location', (
    tester,
  ) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              FakeEditorPage(probe: probe, leaveLocation: '/list'),
        ),
        GoRoute(
          path: '/list',
          builder: (_, _) => const Scaffold(body: Text('list')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await type(tester, 'changed');
    await tapSave(tester);
    expect(probe.writes, ['rec-1']);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('a diver change under Back\'s discard question pops only the '
      'editor', (tester) async {
    await pump(tester, shell: true);
    await type(tester, 'changed');
    final shellNavigator = tester
        .stateList<NavigatorState>(find.byType(Navigator))
        .last;
    unawaited(shellNavigator.maybePop());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  group('on a route with the app\'s leave check', () {
    testWidgets('Save leaves once', (tester) async {
      await pump(tester, onExit: true);
      await type(tester, 'changed');
      await tapSave(tester);
      expect(probe.writes, ['rec-1']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('Cancel with a change asks once, then leaves', (tester) async {
      await pump(tester, onExit: true);
      await type(tester, 'changed');
      await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('Back with a change asks once, then leaves', (tester) async {
      await pump(tester, onExit: true);
      await type(tester, 'changed');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });
  });

  testWidgets('the app exit guard\'s Discard ends the sitting and closes the '
      'page', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    final leaving = container.read(appExitGuardProvider).mayLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(await leaving, isTrue);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(probe.writes, isEmpty);
  });

  testWidgets('a discard from the exit guard while Save resolves the diver '
      'closes the page', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    final gate = probe.diverGate = Completer<String?>();
    // The diver is being worked out again, as after a divers-table
    // change: Save waits for it.
    container.invalidate(validatedCurrentDiverIdProvider);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pump();
    // The bar shows the save in progress meanwhile, so the page never
    // settles until the diver is known: step the frames instead.
    final leaving = container.read(appExitGuardProvider).mayLeave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Discard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await leaving, isTrue);
    gate.complete('a');
    await tester.pumpAndSettle();
    expect(probe.writes, isEmpty);
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('the form is checked after Save resolves the diver, as it is '
      'written', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    final gate = probe.diverGate = Completer<String?>();
    // The diver is being worked out again, as after a divers-table
    // change: Save waits for it.
    container.invalidate(validatedCurrentDiverIdProvider);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pump();
    probe.valid = false;
    gate.complete('a');
    await tester.pumpAndSettle();
    expect(probe.writes, isEmpty);
    expect(find.byType(FakeEditorPage), findsOneWidget);
  });

  testWidgets('a diver id repaired from none to a diver keeps the editor '
      'open', (tester) async {
    await pump(tester, diver: null);
    await type(tester, 'changed');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);
    // That diver is now the editor's: switching away from it closes it.
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
  });

  testWidgets('a stale diver id repaired to the default diver keeps the '
      'editor open', (tester) async {
    // 'stale' names a diver deleted elsewhere: the editor writes under the
    // default diver 'x' from the start, so the repair changes nothing.
    probe.resolveDiver = (id) => id == 'stale' ? 'x' : id;
    await pump(tester, diver: 'stale');
    await tester.pumpAndSettle();
    await type(tester, 'changed');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('x');
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsOneWidget);
    await tapSave(tester);
    expect(probe.writes, ['rec-1']);
  });

  testWidgets('while Save resolves the diver the bar shows it saving', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    final gate = probe.diverGate = Completer<String?>();
    // The diver is being worked out again, as after a divers-table
    // change: Save waits for it.
    container.invalidate(validatedCurrentDiverIdProvider);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pump();
    final bar = tester.widget<RecordEditBar>(find.byType(RecordEditBar));
    expect(bar.isSaving, isTrue);
    final cancel = tester
        .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
        .firstWhere((a) => a.label == 'Cancel');
    expect(cancel.onPressed, isNull);
    gate.complete('a');
    await tester.pumpAndSettle();
    expect(probe.writes, ['rec-1']);
  });

  testWidgets('a diver that cannot be worked out fails the Save, saying so', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.diverFails = true;
    container.invalidate(validatedCurrentDiverIdProvider);
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(tester.takeException(), isNull);
    expect(probe.writes, isEmpty);
    expect(find.byType(FakeEditorPage), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FakeEditorPage)),
    );
    expect(find.text(l10n.recordEdit_saveFailed), findsOneWidget);
  });

  testWidgets('Escape while Save works out the diver does not discard', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    final gate = probe.diverGate = Completer<String?>();
    // The diver is being worked out again, as after a divers-table
    // change: Save waits for it.
    container.invalidate(validatedCurrentDiverIdProvider);
    // No field holds the focus, so Escape is the page's cancel key.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    gate.complete('a');
    await tester.pumpAndSettle();
    expect(probe.writes, ['rec-1']);
  });

  testWidgets('a new record opened while the diver is being worked out '
      'again closes on a switch before that settles', (tester) async {
    final gate = Completer<String?>();
    await pump(
      tester,
      storedId: null,
      beforeEdit: () async {
        // 'a' is settled, then worked out again: the editor opens while the
        // provider still holds 'a' from before.
        expect(
          await container.read(validatedCurrentDiverIdProvider.future),
          'a',
        );
        probe.diverGate = gate;
        // A change the provider depends on (the raw id repaired) makes it
        // reload, not refresh: the reload holds the previous diver aside.
        await container
            .read(currentDiverIdProvider.notifier)
            .setCurrentDiver('a-repaired');
        await tester.pump();
      },
    );
    await type(tester, 'typed');
    probe.diverGate = null;
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    gate.complete('b');
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(probe.writes, isEmpty);
  });

  testWidgets('a diver switch while the record loads closes the page '
      'unopened', (tester) async {
    final loading = probe.loadGate = Completer<void>();
    await pump(tester);
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    loading.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('Ctrl+S saves and Escape cancels', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(probe.writes, ['rec-1']);

    router.push('/edit');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });
}
