import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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
    String? equipmentId,
    List<OverdueServiceEntry>? overdueServices,
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
    equipmentId: equipmentId,
    overdueServices: overdueServices,
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
    List<dynamic> overrides = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
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
    testWidgets('long item title keeps its width beside the completion time', (
      tester,
    ) async {
      // Guards the ListTile.trailing hazard behind issue #935: the trailing
      // widget is measured against the full tile width before the title column
      // gets what is left.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const longTitle =
          'Verify both oxygen cells read within 2 mV of each '
          'other before closing the loop';
      await pumpTile(
        tester,
        s: session(),
        it: item(
          title: longTitle,
          state: PreDiveItemState.done,
          completedAt: now,
        ),
      );

      final titleSize = tester.getSize(find.text(longTitle));

      expect(
        titleSize.width,
        greaterThan(150),
        reason:
            'Item title collapsed to ${titleSize.width}px wide on a 360px '
            'screen; the trailing row is starving the text column.',
      );
    });

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

  group('overdue service warning', () {
    final overdueStatus = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 'sched1',
        equipmentId: 'g1',
        serviceKindId: 'vip',
        createdAt: now,
        updatedAt: now,
      ),
      kind: ServiceKind(
        id: 'vip',
        name: 'Visual inspection',
        applicableTypes: const [],
        createdAt: now,
        updatedAt: now,
      ),
      anchor: now,
      dueDate: DateTime(2020, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 1, 1),
    );

    testWidgets(
      'pending item with overdue equipment shows a live warning, not a '
      'resolved state',
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(equipmentId: 'g1'),
          overrides: [
            serviceClockStatusesProvider(
              'g1',
            ).overrideWith((ref) async => [overdueStatus]),
          ],
        );
        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Visual inspection'), findsOneWidget);
        // Still pending: the warning is informative only, not a done state.
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
        expect(find.byIcon(Icons.flag), findsNothing);
      },
    );

    testWidgets('pending item with no overdue clocks shows nothing extra', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: [
          serviceClockStatusesProvider('g1').overrideWith((ref) async => []),
        ],
      );
      expect(find.text('Service overdue'), findsNothing);
    });

    testWidgets(
      'resolved item shows its frozen overdue snapshot without touching the '
      "equipment provider (a later service log entry can't rewrite it)",
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(
            state: PreDiveItemState.done,
            completedAt: now,
            equipmentId: 'g1',
            overdueServices: const [
              OverdueServiceEntry(
                kindName: 'Hydrostatic test',
                divesRemaining: -3,
              ),
            ],
          ),
          // No serviceClockStatusesProvider override: a resolved item must
          // never watch it, so this would fail with a missing-provider error
          // if the live path were used by mistake.
        );
        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Hydrostatic test'), findsOneWidget);
      },
    );

    testWidgets('resolved item with an empty frozen list shows nothing extra', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          state: PreDiveItemState.done,
          completedAt: now,
          equipmentId: 'g1',
          overdueServices: const [],
        ),
      );
      expect(find.text('Service overdue'), findsNothing);
    });

    testWidgets(
      'a frozen entry is worded against completedAt, not the wall clock: a '
      'dueDate that was still in the future at freeze time keeps reading '
      '"Due", however long ago the item was resolved',
      (tester) async {
        // The entry was frozen because its dives trigger was overdue, while
        // its date trigger was not yet due. Reading it against DateTime.now()
        // would silently reword the snapshot to "Overdue since" once real
        // time passed dueDate, even though nothing stored changed.
        await pumpTile(
          tester,
          s: session(),
          it: item(
            state: PreDiveItemState.done,
            completedAt: now, // 2023-11-14
            equipmentId: 'g1',
            overdueServices: [
              OverdueServiceEntry(
                kindName: 'Hydrostatic test',
                dueDate: DateTime(2024, 6), // after completedAt, before today
                divesSinceAnchor: 53,
                divesRemaining: -3,
              ),
            ],
          ),
        );

        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Hydrostatic test: Due '), findsOneWidget);
        expect(find.textContaining('Overdue since'), findsNothing);
      },
    );

    testWidgets(
      'a pending item is still worded against the wall clock, so a dueDate '
      'already in the past reads "Overdue since"',
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(equipmentId: 'g1'),
          overrides: [
            serviceClockStatusesProvider('g1').overrideWith(
              (ref) async => [
                ServiceClockStatus(
                  schedule: overdueStatus.schedule,
                  kind: overdueStatus.kind,
                  anchor: now,
                  dueDate: DateTime(2024, 6),
                  severity: ServiceClockSeverity.overdue,
                  now: DateTime(2026, 1, 1),
                ),
              ],
            ),
          ],
        );

        expect(find.textContaining('Overdue since'), findsOneWidget);
      },
    );
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
