import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

void main() {
  const childKey = ValueKey('leading_child');

  Widget leading({
    required bool isSelectionMode,
    bool isChecked = false,
    bool isSelectable = true,
    ValueChanged<bool>? onChanged,
  }) {
    return SelectionLeading(
      isSelectionMode: isSelectionMode,
      isChecked: isChecked,
      isSelectable: isSelectable,
      onChanged: onChanged ?? (_) {},
      child: const SizedBox(
        key: childKey,
        width: 40,
        height: 40,
        child: Text('412'),
      ),
    );
  }

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  group('SelectionLeading', () {
    testWidgets('shows the child and no checkbox outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(leading(isSelectionMode: false)));
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('reserves no width outside selection mode', (tester) async {
      await tester.pumpWidget(host(leading(isSelectionMode: false)));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SelectionLeading)).width,
        40,
        reason: 'only the child is laid out when selection mode is off',
      );
    });

    testWidgets('keeps the child beside the checkbox in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(leading(isSelectionMode: true)));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.text('412'),
        findsOneWidget,
        reason:
            'the leading element carries identifying data such as the dive '
            'number, so the checkbox must not replace it (issue #1717)',
      );
      expect(
        tester.getTopRight(find.byType(Checkbox)).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(childKey)).dx),
        reason: 'the checkbox sits ahead of the child, not on top of it',
      );
    });

    testWidgets('leads with the checkbox on the start side in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: leading(isSelectionMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(Checkbox)).dx,
        greaterThanOrEqualTo(tester.getTopRight(find.byKey(childKey)).dx),
        reason: 'the checkbox leads the row on its start side',
      );
    });

    testWidgets('reflects the checked state', (tester) async {
      await tester.pumpWidget(
        host(leading(isSelectionMode: true, isChecked: true)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('keeps the child and shows no checkbox for non-selectable '
        'rows', (tester) async {
      await tester.pumpWidget(
        host(leading(isSelectionMode: true, isSelectable: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('aligns a non-selectable row with its selectable neighbours', (
      tester,
    ) async {
      const selectableChild = ValueKey('selectable_child');
      const lockedChild = ValueKey('locked_child');
      await tester.pumpWidget(
        host(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectionLeading(
                isSelectionMode: true,
                isChecked: false,
                child: SizedBox(key: selectableChild, width: 40, height: 40),
              ),
              SelectionLeading(
                isSelectionMode: true,
                isChecked: false,
                isSelectable: false,
                child: SizedBox(key: lockedChild, width: 40, height: 40),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(lockedChild)).dx,
        tester.getTopLeft(find.byKey(selectableChild)).dx,
        reason:
            'a row without a checkbox keeps the checkbox column blank, so '
            'its leading element lines up with the rows that have one',
      );
    });

    testWidgets('reports a change when tapped', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        host(leading(isSelectionMode: true, onChanged: (v) => reported = v)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      expect(reported, isTrue);
    });

    testWidgets('renders a disabled checkbox when onChanged is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionLeading(
            isSelectionMode: true,
            isChecked: false,
            child: Text('412'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });
  });
}
