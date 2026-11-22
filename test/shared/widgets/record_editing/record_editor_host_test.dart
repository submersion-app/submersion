import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// What the fake editor was asked to do, and how it should answer.
class _Probe {
  final writes = <String>[];
  final operationLabels = <String?>[];
  int afterSaved = 0;
  bool valid = true;
  bool failWrite = false;
  bool failAfterSaved = false;

  /// The diver the write was handed ([RecordEditorHost.editorDiverId]).
  final diversSeen = <String?>[];

  /// The change log operation in force each time the validated diver was
  /// read: null outside any sitting's transaction.
  final diverReadInScope = <String?>[];

  /// Runs inside the write, before it answers.
  Future<void> Function()? duringWrite;
}

/// An editor with no read page, as small as one can be: one text field
/// whose text is the draft.
class _FakeEditorPage extends ConsumerStatefulWidget {
  const _FakeEditorPage({
    required this.probe,
    this.storedId = 'rec-1',
    this.leaveLocation,
  });

  final _Probe probe;
  final String? storedId;
  final String? leaveLocation;

  @override
  ConsumerState<_FakeEditorPage> createState() => _FakeEditorState();
}

class _FakeEditorState extends ConsumerState<_FakeEditorPage>
    with RecordEditorHost<_FakeEditorPage, String> {
  late final TextEditingController text;

  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.storedId == null ? '' : 'stored')
      ..addListener(editorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => openEditor());
  }

  @override
  void dispose() {
    disposeEditor();
    text.dispose();
    super.dispose();
  }

  @override
  String get editorTable => 'fake';

  @override
  String? get editorLeaveLocation => widget.leaveLocation;

  @override
  String? get editorStoredId => widget.storedId;

  @override
  String editorTitle(BuildContext context) => 'Fake editor';

  @override
  String readEditorDraft() => text.text;

  @override
  bool validateEditor() => widget.probe.valid;

  @override
  Future<void> writeEditor(String recordId) async {
    final probe = widget.probe;
    probe.diversSeen.add(editorDiverId);
    await probe.duringWrite?.call();
    if (probe.failWrite) throw StateError('write refused');
    probe.writes.add(recordId);
    final operationId = ChangeLogScope.currentOperationId;
    final row = operationId == null
        ? null
        : await DatabaseService.instance.database
              .customSelect(
                'SELECT label FROM change_log_operations WHERE id = ?',
                variables: [Variable(operationId)],
              )
              .getSingleOrNull();
    probe.operationLabels.add(row?.read<String?>('label'));
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    widget.probe.afterSaved++;
    if (widget.probe.failAfterSaved) throw StateError('refresh failed');
  }

  @override
  Widget build(BuildContext context) => editorScaffold(
    context,
    body: TextField(key: const ValueKey('field'), controller: text),
  );
}

void main() {
  late _Probe probe;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    probe = _Probe();
  });
  tearDown(() async => tearDownTestDatabase());

  /// The editor pushed over a stand-in list. [shell] puts both in a shell
  /// navigator, as the app's preset routes are, so a dialog opens above
  /// it in the root one; [onExit] gives the editor's route the app's leave
  /// check, as the app's routes have.
  Future<_FakeEditorState> pump(
    WidgetTester tester, {
    String? storedId = 'rec-1',
    bool shell = false,
    bool onExit = false,
  }) async {
    final list = GoRoute(
      path: shell ? 'list' : '/',
      builder: (_, _) => const Scaffold(body: Text('list')),
      routes: [
        GoRoute(
          path: 'edit',
          onExit: onExit ? confirmLeaveRecordSitting : null,
          builder: (_, _) => _FakeEditorPage(probe: probe, storedId: storedId),
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
            return ref.watch(currentDiverIdProvider);
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
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    if (shell) {
      router.push('/list');
      await tester.pumpAndSettle();
    }
    router.push(shell ? '/list/edit' : '/edit');
    await tester.pumpAndSettle();
    return tester.state<_FakeEditorState>(find.byType(_FakeEditorPage));
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
    expect(find.byType(_FakeEditorPage), findsNothing);
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
    expect(find.byType(_FakeEditorPage), findsOneWidget);
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
    expect(find.byType(_FakeEditorPage), findsNothing);
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
    expect(find.byType(_FakeEditorPage), findsNothing);
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
    expect(find.byType(_FakeEditorPage), findsOneWidget);
  });

  testWidgets('a write that throws stays with the text and says it failed', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.failWrite = true;
    await tapSave(tester);
    expect(find.byType(_FakeEditorPage), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(_FakeEditorPage)),
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
    expect(find.byType(_FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('a change of active diver closes a changed new record, '
      'writing nothing', (tester) async {
    await pump(tester, storedId: null);
    await type(tester, 'typed');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('b');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(_FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(probe.writes, isEmpty);
  });

  testWidgets('a page with nothing under it saves and stays', (tester) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => _FakeEditorPage(probe: probe),
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
    expect(find.byType(_FakeEditorPage), findsOneWidget);
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
    expect(find.byType(_FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('an afterEditorSaved that throws still leaves', (tester) async {
    await pump(tester);
    await type(tester, 'changed');
    probe.failAfterSaved = true;
    await tapSave(tester);
    expect(probe.writes, ['rec-1']);
    expect(find.byType(_FakeEditorPage), findsNothing);
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
              _FakeEditorPage(probe: probe, leaveLocation: '/list'),
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
    expect(find.byType(_FakeEditorPage), findsNothing);
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
    expect(find.byType(_FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
    expect(probe.writes, isEmpty);
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
    expect(find.byType(_FakeEditorPage), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });
}
