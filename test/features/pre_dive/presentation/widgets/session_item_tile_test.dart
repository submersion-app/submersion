import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/session_item_tile.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session({bool locked = false, bool strict = false}) =>
      PreDiveSession(
        id: 's1',
        templateName: 'T',
        startedAt: now,
        createdAt: now,
        updatedAt: now,
        strictOrder: strict,
        status: locked
            ? PreDiveSessionStatus.completed
            : PreDiveSessionStatus.inProgress,
      );

  PreDiveSessionItem item({
    String id = 'i1',
    String title = 'Check air',
    PreDiveItemState state = PreDiveItemState.pending,
    PreDiveItemType type = PreDiveItemType.check,
    bool required = false,
    String note = '',
    String notes = '',
    String? valueLabel,
    double? valueNumber,
    String? valueUnit,
    double? valueMin,
    double? valueMax,
    DateTime? completedAt,
  }) => PreDiveSessionItem(
    id: id,
    sessionId: 's1',
    title: title,
    state: state,
    itemType: type,
    isRequired: required,
    note: note,
    notes: notes,
    valueLabel: valueLabel,
    valueNumber: valueNumber,
    valueUnit: valueUnit,
    valueMin: valueMin,
    valueMax: valueMax,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required PreDiveSession s,
    required PreDiveSessionItem it,
    List<PreDiveSessionItem>? items,
    VoidCallback? onDone,
    VoidCallback? onSkip,
    VoidCallback? onFlag,
    VoidCallback? onEditValue,
    VoidCallback? onAddNote,
    VoidCallback? onReset,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SessionItemTile(
          session: s,
          sortedItems: items ?? [it],
          item: it,
          onDone: onDone ?? () {},
          onSkip: onSkip ?? () {},
          onFlag: onFlag ?? () {},
          onEditValue: onEditValue ?? () {},
          onAddNote: onAddNote ?? () {},
          onReset: onReset ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  group('state rendering', () {
    testWidgets('pending item shows unchecked icon and title', (tester) async {
      await pumpTile(tester, s: session(), it: item());
      expect(find.text('Check air'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('done item shows filled check and a completion time', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          state: PreDiveItemState.done,
          completedAt: DateTime(2024, 1, 1, 10, 30),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // Trailing completion time is rendered (line-exercise for completedAt).
      expect(find.textContaining('10:30'), findsOneWidget);
    });

    testWidgets('skipped item shows remove-circle icon', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.skipped),
      );
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('flagged item shows flag icon', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.flagged),
      );
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });
  });

  group('subtitle content', () {
    testWidgets('value item renders the value line', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 200,
          valueUnit: 'bar',
        ),
      );
      expect(find.text('SPG: 200.0 bar'), findsOneWidget);
    });

    testWidgets('out-of-range value line is bold', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 300,
          valueUnit: 'bar',
          valueMax: 200,
        ),
      );
      final text = tester.widget<Text>(find.text('SPG: 300.0 bar'));
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('note and notes lines both render', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(note: 'Needle jumpy', notes: 'Should read 200 bar'),
      );
      expect(find.text('Needle jumpy'), findsOneWidget);
      expect(find.text('Should read 200 bar'), findsOneWidget);
    });
  });

  group('tap target', () {
    testWidgets('tapping a check item fires onDone', (tester) async {
      var done = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onDone: () => done = true,
      );
      await tester.tap(find.byType(ListTile));
      expect(done, isTrue);
    });

    testWidgets('tapping a value item fires onEditValue, not onDone', (
      tester,
    ) async {
      var done = false;
      var edit = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 200,
        ),
        onDone: () => done = true,
        onEditValue: () => edit = true,
      );
      await tester.tap(find.byType(ListTile));
      expect(edit, isTrue);
      expect(done, isFalse);
    });
  });

  group('strict-order gating', () {
    testWidgets('non-next item is dimmed and inert', (tester) async {
      var done = false;
      final first = item(id: 'a', title: 'First');
      final target = item(id: 'b', title: 'Second');
      await pumpTile(
        tester,
        s: session(strict: true),
        it: target,
        items: [first, target],
        onDone: () => done = true,
      );

      // Wrapped in a 0.4-opacity layer when gated.
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
        findsOneWidget,
      );
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);

      await tester.tap(find.byType(ListTile), warnIfMissed: false);
      expect(done, isFalse);

      // The overflow menu is also gated: Skip/Flag/Note must not be reachable
      // on a not-yet-actionable pending item in a strict-order session.
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('the next item is not dimmed and is actionable', (
      tester,
    ) async {
      var done = false;
      final first = item(id: 'a', title: 'First');
      final second = item(id: 'b', title: 'Second');
      await pumpTile(
        tester,
        s: session(strict: true),
        it: first,
        items: [first, second],
        onDone: () => done = true,
      );
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
        findsNothing,
      );
      await tester.tap(find.byType(ListTile));
      expect(done, isTrue);
    });
  });

  group('popup menu', () {
    testWidgets('pending optional item offers Skip, Flag, Add note', (
      tester,
    ) async {
      await pumpTile(tester, s: session(), it: item());
      await openMenu(tester);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Reset to pending'), findsNothing);
    });

    testWidgets('required item hides Skip', (tester) async {
      await pumpTile(tester, s: session(), it: item(required: true));
      await openMenu(tester);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
    });

    testWidgets('resolved item offers Undo but not Skip/Flag', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.done),
      );
      await openMenu(tester);
      expect(find.text('Reset to pending'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Flag'), findsNothing);
    });

    testWidgets('selecting Skip fires onSkip', (tester) async {
      var skipped = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onSkip: () => skipped = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
    });

    testWidgets('selecting Flag fires onFlag', (tester) async {
      var flagged = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onFlag: () => flagged = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Flag'));
      await tester.pumpAndSettle();
      expect(flagged, isTrue);
    });

    testWidgets('selecting Add note fires onAddNote', (tester) async {
      var noted = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onAddNote: () => noted = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      expect(noted, isTrue);
    });

    testWidgets('selecting Undo fires onReset', (tester) async {
      var reset = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.done),
        onReset: () => reset = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Reset to pending'));
      await tester.pumpAndSettle();
      expect(reset, isTrue);
    });

    testWidgets('locked session hides the menu entirely', (tester) async {
      await pumpTile(
        tester,
        s: session(locked: true),
        it: item(state: PreDiveItemState.done),
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });
}
