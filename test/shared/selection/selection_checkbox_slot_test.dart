import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/selection/selection_checkbox_slot.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Row(children: [child])),
  );

  group('SelectionCheckboxSlot', () {
    testWidgets('renders nothing measurable when not in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: false, isChecked: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(
        tester.getSize(find.byType(SelectionCheckboxSlot)).width,
        0,
        reason: 'the slot must reserve no width outside selection mode',
      );
    });

    testWidgets('renders a checkbox and a gap in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: true, isChecked: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        tester.getSize(find.byType(SelectionCheckboxSlot)).width,
        greaterThan(12),
        reason: 'the slot must occupy the checkbox width plus the gap',
      );
    });

    testWidgets('reports the checked value', (tester) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: true, isChecked: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('reports taps through onChanged', (tester) async {
      bool? received;
      await tester.pumpWidget(
        host(
          SelectionCheckboxSlot(
            isSelectionMode: true,
            isChecked: false,
            onChanged: (value) => received = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('renders nothing for a non-selectable row', (tester) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(
            isSelectionMode: true,
            isChecked: false,
            isSelectable: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(tester.getSize(find.byType(SelectionCheckboxSlot)).width, 0);
    });
  });
}
