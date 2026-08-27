import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../../helpers/test_app.dart';

void main() {
  late SelectionController controller;

  setUp(() => controller = SelectionController());
  tearDown(() => controller.dispose());

  Widget host({
    SelectionBarShell shell = SelectionBarShell.appBar,
    List<BulkAction> actions = const [],
    VoidCallback? onDelete,
    int maxInlineActions = 3,
    List<String> selectableIds = const ['a', 'b', 'c'],
  }) {
    final bar = SelectionAppBar(
      controller: controller,
      selectableIds: selectableIds,
      actions: actions,
      shell: shell,
      onDelete: onDelete ?? () {},
      maxInlineActions: maxInlineActions,
    );
    return testApp(
      // Pinned: these assertions read English UI strings, and the app ships
      // 11 locales, so platform-locale resolution would make them
      // environment-dependent.
      locale: const Locale('en'),
      child: shell == SelectionBarShell.appBar
          ? Scaffold(appBar: bar, body: const SizedBox())
          : Column(children: [bar]),
    );
  }

  group('SelectionAppBar', () {
    testWidgets('shows the selected count', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('the count follows the controller', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      controller.toggle('b');
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('exit control clears the selection', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_exit')));
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('select all checks every selectable id', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    testWidgets('select all is disabled once everything is checked', (
      tester,
    ) async {
      controller.selectAll(const ['a', 'b', 'c']);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_select_all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('deselect all is disabled at zero checked', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_deselect_all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('delete is never an inline control', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Delete sits behind the overflow so it cannot be hit by accident while
      // reaching for a neighbouring control.
      expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('a delete-only surface still gets an overflow menu', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
    });

    testWidgets('delete is disabled at zero checked', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();

      final item = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('selection_delete')),
      );
      expect(item.enabled, isFalse);
    });

    testWidgets('delete invokes onDelete when chosen from the overflow', (
      tester,
    ) async {
      var deleted = false;
      controller.enterImplicit('a');
      await tester.pumpWidget(host(onDelete: () => deleted = true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_delete')));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('an action id colliding with the delete sentinel asserts', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: '__selection_delete__',
              icon: Icons.merge_type,
              label: 'Collides',
              onInvoke: () {},
            ),
          ],
        ),
      );

      // Silently routing this action's menu entry to onDelete would fire the
      // wrong handler, and a destructive one. It must fail loudly instead.
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('delete sorts last, below the surface extras', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          maxInlineActions: 0,
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();

      // A divider keeps the destructive entry visually apart from the extras.
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      final mergeY = tester
          .getCenter(find.byKey(const ValueKey('selection_menu_merge')))
          .dy;
      final deleteY = tester
          .getCenter(find.byKey(const ValueKey('selection_delete')))
          .dy;
      expect(deleteY, greaterThan(mergeY));
    });

    testWidgets(
      'omits the overflow entirely when there is nothing to put in it',
      (tester) async {
        controller.enterImplicit('a');
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            child: Scaffold(
              appBar: SelectionAppBar(
                controller: controller,
                selectableIds: const ['a', 'b', 'c'],
                actions: const [],
                shell: SelectionBarShell.appBar,
                onDelete: null,
              ),
              body: const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Omitted, not disabled: a surface with no true delete and no extras has
        // nothing to overflow, so the menu button itself must not render.
        expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
        expect(find.byKey(const ValueKey('selection_overflow')), findsNothing);
        // The rest of the baseline still renders.
        expect(
          find.byKey(const ValueKey('selection_select_all')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('selection_deselect_all')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
      },
    );

    testWidgets('an extra below its minCount renders disabled', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              minCount: 2,
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_action_merge')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an enabled extra invokes its callback', (tester) async {
      var invoked = false;
      controller.enterImplicit('a');
      controller.toggle('b');
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              minCount: 2,
              onInvoke: () => invoked = true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();
      expect(invoked, isTrue);
    });

    testWidgets('an alwaysEnabled extra stays enabled at zero checked', (
      tester,
    ) async {
      controller.enterExplicit();
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: 'date_range',
              icon: Icons.date_range,
              label: 'By date range',
              alwaysEnabled: true,
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_action_date_range')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('extras beyond maxInlineActions move to the overflow', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          maxInlineActions: 1,
          actions: [
            BulkAction(
              id: 'one',
              icon: Icons.merge_type,
              label: 'One',
              onInvoke: () {},
            ),
            BulkAction(
              id: 'two',
              icon: Icons.ios_share,
              label: 'Two',
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('selection_action_one')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('selection_action_two')), findsNothing);
      expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
    });

    testWidgets('an overflowed extra invokes its callback when chosen', (
      tester,
    ) async {
      var invoked = false;
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          maxInlineActions: 0,
          actions: [
            BulkAction(
              id: 'two',
              icon: Icons.ios_share,
              label: 'Two',
              onInvoke: () => invoked = true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(invoked, isTrue);
    });

    testWidgets('the pane shell renders the same actions without an AppBar', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          shell: SelectionBarShell.pane,
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byKey(const ValueKey('selection_action_merge')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);

      // The pane shell hides delete behind the overflow too, so neither shell
      // offers a one-tap destructive control.
      expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_delete')), findsOneWidget);
    });
  });
}
