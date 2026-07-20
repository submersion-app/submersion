import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_session_runner_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../helpers/test_app.dart';

/// Records the write-through calls the page makes. Only the members the page
/// actually invokes are overridden; everything else routes to [noSuchMethod].
class _FakeSessionRepo implements PreDiveSessionRepository {
  final calls =
      <
        ({
          String itemId,
          PreDiveItemState state,
          double? valueNumber,
          String? note,
        })
      >[];
  final completed = <String>[];
  final aborted = <String>[];

  @override
  Future<void> updateItemState({
    required String sessionId,
    required String itemId,
    required PreDiveItemState state,
    double? valueNumber,
    String? valueText,
    String? note,
  }) async {
    calls.add((
      itemId: itemId,
      state: state,
      valueNumber: valueNumber,
      note: note,
    ));
  }

  @override
  Future<void> completeSession(String id) async => completed.add(id);

  @override
  Future<void> abortSession(String id) async => aborted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session({
    bool strict = true,
    PreDiveSessionStatus status = PreDiveSessionStatus.inProgress,
    DateTime? completedAt,
  }) => PreDiveSession(
    id: 's1',
    templateName: 'CCR Build',
    strictOrder: strict,
    startedAt: now,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(
    int order, {
    PreDiveItemState state = PreDiveItemState.pending,
    bool required = true,
    PreDiveItemType itemType = PreDiveItemType.check,
    String? section,
    String? valueLabel,
    String? valueUnit,
    double? valueMin,
    double? valueMax,
    double? valueNumber,
    String note = '',
  }) => PreDiveSessionItem(
    id: 'i$order',
    sessionId: 's1',
    title: 'Item $order',
    section: section,
    sortOrder: order,
    state: state,
    isRequired: required,
    itemType: itemType,
    valueLabel: valueLabel,
    valueUnit: valueUnit,
    valueMin: valueMin,
    valueMax: valueMax,
    valueNumber: valueNumber,
    note: note,
    completedAt: state == PreDiveItemState.pending ? null : now,
    createdAt: now,
    updatedAt: now,
  );

  Future<_FakeSessionRepo> pumpRunner(
    WidgetTester tester, {
    required PreDiveSession s,
    required List<PreDiveSessionItem> items,
  }) async {
    final repo = _FakeSessionRepo();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveSessionProvider('s1').overrideWith((ref) async => s),
          preDiveSessionItemsProvider('s1').overrideWith((ref) async => items),
        ],
        child: const PreDiveSessionRunnerPage(sessionId: 's1'),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('shows progress and strict-order gating', (tester) async {
    final items = [item(0, state: PreDiveItemState.done), item(1), item(2)];
    final repo = await pumpRunner(tester, s: session(), items: items);

    expect(find.text('1 of 3'), findsOneWidget);

    // Second item is the next actionable; third is inert.
    final tile1 = tester.widget<ListTile>(
      find.ancestor(of: find.text('Item 1'), matching: find.byType(ListTile)),
    );
    final tile2 = tester.widget<ListTile>(
      find.ancestor(of: find.text('Item 2'), matching: find.byType(ListTile)),
    );
    expect(tile1.enabled, isTrue);
    expect(tile2.enabled, isFalse);

    // Tapping the actionable item records a done state change.
    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.itemId, 'i1');
    expect(repo.calls.single.state, PreDiveItemState.done);
  });

  // Note: one pump per test — re-pumping a new ProviderScope in the same
  // test updates the existing scope element, whose overrides are fixed at
  // creation, so the second set of overrides would be silently ignored.
  testWidgets('Complete disabled while a required item pends', (tester) async {
    await pumpRunner(tester, s: session(), items: [item(0)]);
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Complete'),
    );
    expect(disabled.onPressed, isNull);
  });

  testWidgets('Complete enabled once required items resolve', (tester) async {
    await pumpRunner(
      tester,
      s: session(),
      items: [item(0, state: PreDiveItemState.done)],
    );
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Complete'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('locked session renders banner and no Complete button', (
    tester,
  ) async {
    await pumpRunner(
      tester,
      s: session(status: PreDiveSessionStatus.completed),
      items: [item(0, state: PreDiveItemState.done)],
    );
    expect(find.textContaining('This checklist is locked'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
    // No abort action either.
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('locked banner shows aborted status and completed date', (
    tester,
  ) async {
    await pumpRunner(
      tester,
      s: session(
        status: PreDiveSessionStatus.aborted,
        completedAt: DateTime(2023, 11, 14),
      ),
      items: [item(0, state: PreDiveItemState.skipped, required: false)],
    );
    // Status label and formatted date are folded into the locked banner.
    // (Date format is locale-dependent; assert the month/day are present.)
    expect(find.textContaining('Aborted'), findsOneWidget);
    expect(find.textContaining('Nov 14'), findsOneWidget);
  });

  testWidgets('locked session is read-only: tiles disabled, no item menu', (
    tester,
  ) async {
    await pumpRunner(
      tester,
      s: session(status: PreDiveSessionStatus.completed),
      items: [item(0, state: PreDiveItemState.done)],
    );
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Item 0'), matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    // No bottom bar on a locked session.
    expect(find.byType(BottomAppBar), findsNothing);
  });

  testWidgets('renders a section header above grouped items', (tester) async {
    await pumpRunner(
      tester,
      s: session(),
      items: [item(0, section: 'Pre-breathe')],
    );
    expect(find.text('Pre-breathe'), findsOneWidget);
    expect(find.text('Item 0'), findsOneWidget);
  });

  testWidgets('error from session provider surfaces error text', (
    tester,
  ) async {
    final repo = _FakeSessionRepo();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveSessionProvider(
            's1',
          ).overrideWith((ref) async => throw Exception('boom')),
          preDiveSessionItemsProvider('s1').overrideWith((ref) async => []),
        ],
        child: const PreDiveSessionRunnerPage(sessionId: 's1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('value item opens entry dialog and records value + note', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [
        item(
          0,
          itemType: PreDiveItemType.value,
          valueLabel: 'Set point',
          valueUnit: 'bar',
        ),
      ],
    );

    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();

    // Dialog titled by the value label (also echoed in the tile subtitle);
    // the value-field label is unique to the dialog.
    expect(find.text('Set point'), findsWidgets);
    expect(find.text('Enter value'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), '1.2');
    await tester.enterText(fields.at(1), 'looks good');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    final call = repo.calls.single;
    expect(call.itemId, 'i0');
    expect(call.state, PreDiveItemState.done);
    expect(call.valueNumber, 1.2);
    expect(call.note, 'looks good');
  });

  testWidgets('value entry dialog cancel writes nothing', (tester) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [
        item(0, itemType: PreDiveItemType.value, valueLabel: 'Set point'),
      ],
    );

    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('Skip menu action records a skipped state', (tester) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [item(0, required: false)],
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repo.calls.single.itemId, 'i0');
    expect(repo.calls.single.state, PreDiveItemState.skipped);
  });

  testWidgets('Reset menu action on a resolved item restores pending', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [item(0, state: PreDiveItemState.done)],
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to pending'));
    await tester.pumpAndSettle();

    expect(repo.calls.single.state, PreDiveItemState.pending);
  });

  testWidgets('Add note menu records the note, preserving state', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [item(0, state: PreDiveItemState.done)],
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'checked twice');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    final call = repo.calls.single;
    expect(call.note, 'checked twice');
    // Add note keeps the current state (done), never forcing a transition.
    expect(call.state, PreDiveItemState.done);
  });

  testWidgets('Add note cancel writes nothing', (tester) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [item(0, state: PreDiveItemState.done)],
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('Flag menu records a flagged state with the note', (
    tester,
  ) async {
    final repo = await pumpRunner(tester, s: session(), items: [item(0)]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flag'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'o-ring worn');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    final call = repo.calls.single;
    expect(call.state, PreDiveItemState.flagged);
    expect(call.note, 'o-ring worn');
  });

  testWidgets('Flag dialog cancel writes nothing', (tester) async {
    final repo = await pumpRunner(tester, s: session(), items: [item(0)]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flag'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('flagged badge shows and Complete confirms before finishing', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [
        item(0, state: PreDiveItemState.done),
        item(1, state: PreDiveItemState.flagged),
      ],
    );

    // Flagged badge chip in the app bar.
    expect(find.text('1 flagged'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsWidgets);

    // Complete is enabled (flagged counts as resolved for required items).
    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    // Confirmation dialog names the flagged count.
    expect(find.text('Complete with 1 flagged items?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Complete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.completed, ['s1']);
  });

  testWidgets('cancelling the flagged confirmation does not complete', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [
        item(0, state: PreDiveItemState.done),
        item(1, state: PreDiveItemState.flagged),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.completed, isEmpty);
  });

  testWidgets('Complete with no flagged items finishes without a dialog', (
    tester,
  ) async {
    final repo = await pumpRunner(
      tester,
      s: session(),
      items: [item(0, state: PreDiveItemState.done)],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    // No confirmation dialog was shown for a clean checklist.
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.completed, ['s1']);
  });

  testWidgets('Abort confirmation aborts the session', (tester) async {
    final repo = await pumpRunner(tester, s: session(), items: [item(0)]);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('Abort this checklist?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Abort checklist'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.aborted, ['s1']);
  });

  testWidgets('Abort cancel leaves the session untouched', (tester) async {
    final repo = await pumpRunner(tester, s: session(), items: [item(0)]);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.aborted, isEmpty);
  });
}
