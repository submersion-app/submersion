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
}

/// An editor with no read page, as small as one can be: one text field
/// whose text is the draft.
class _FakeEditorPage extends ConsumerStatefulWidget {
  const _FakeEditorPage({required this.probe, this.storedId = 'rec-1'});

  final _Probe probe;
  final String? storedId;

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
  void afterEditorSaved(ScaffoldMessengerState messenger) =>
      widget.probe.afterSaved++;

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

  Future<_FakeEditorState> pump(
    WidgetTester tester, {
    String? storedId = 'rec-1',
  }) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('list')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) =>
                  _FakeEditorPage(probe: probe, storedId: storedId),
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
    container = ProviderScope.containerOf(tester.element(find.text('list')));
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    router.push('/edit');
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
