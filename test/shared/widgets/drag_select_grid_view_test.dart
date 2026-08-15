import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

void main() {
  Widget buildTestGrid({
    int itemCount = 12,
    Set<int> initialSelection = const {},
    ValueChanged<Set<int>>? onSelectionChanged,
    ValueChanged<bool>? onSelectionModeChanged,
    bool startInSelectionMode = false,
    bool exitOnEmptySelection = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DragSelectGridView<int>(
          items: List.generate(itemCount, (i) => i),
          initialSelection: initialSelection,
          startInSelectionMode: startInSelectionMode,
          exitOnEmptySelection: exitOnEmptySelection,
          onSelectionChanged: onSelectionChanged ?? (_) {},
          onSelectionModeChanged: onSelectionModeChanged ?? (_) {},
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, item, isSelected) {
            return Container(
              key: ValueKey('item_$item'),
              color: isSelected ? Colors.blue : Colors.grey,
              child: Center(child: Text('$item')),
            );
          },
        ),
      ),
    );
  }

  group('DragSelectGridView', () {
    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(buildTestGrid(itemCount: 8));
      for (var i = 0; i < 8; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('shows initial selection', (tester) async {
      await tester.pumpWidget(
        buildTestGrid(
          itemCount: 4,
          initialSelection: {0, 2},
          startInSelectionMode: true,
        ),
      );
      // Items 0 and 2 should be blue (selected), 1 and 3 grey
      final item0 = tester.widget<Container>(
        find.byKey(const ValueKey('item_0')),
      );
      expect(item0.color, Colors.blue);
      final item1 = tester.widget<Container>(
        find.byKey(const ValueKey('item_1')),
      );
      expect(item1.color, Colors.grey);
    });

    testWidgets('long press does not enter selection mode', (tester) async {
      bool? selectionModeChangedTo;
      Set<int> selection = {};
      await tester.pumpWidget(
        buildTestGrid(
          onSelectionModeChanged: (active) => selectionModeChangedTo = active,
          onSelectionChanged: (s) => selection = s,
        ),
      );

      await tester.longPress(find.text('0'));
      await tester.pumpAndSettle();

      expect(selectionModeChangedTo, isNull);
      expect(selection, isEmpty);
    });

    testWidgets('long press inside selection mode checks the anchor', (
      tester,
    ) async {
      Set<int> selection = {};
      await tester.pumpWidget(
        buildTestGrid(
          initialSelection: {1},
          startInSelectionMode: true,
          onSelectionChanged: (s) => selection = s,
        ),
      );

      await tester.longPress(find.text('3'));
      await tester.pumpAndSettle();

      // The drag anchor joins the selection rather than replacing it, so an
      // accidental hold cannot wipe out what the user already checked.
      expect(selection, containsAll(<int>[1, 3]));
    });

    testWidgets('tap toggles selection when in selection mode', (tester) async {
      Set<int> selection = {};
      await tester.pumpWidget(
        buildTestGrid(
          initialSelection: {0},
          startInSelectionMode: true,
          onSelectionChanged: (s) => selection = s,
        ),
      );

      // Tap item 2 to select it
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(selection, contains(2));

      // Tap item 0 to deselect it
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(selection.contains(0), isFalse);
    });

    testWidgets('tap passes through when not in selection mode', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DragSelectGridView<int>(
              items: List.generate(4, (i) => i),
              initialSelection: const {},
              onSelectionChanged: (_) {},
              onSelectionModeChanged: (_) {},
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              onItemTap: (index) => tapped = true,
              itemBuilder: (context, item, isSelected) {
                return Container(
                  key: ValueKey('item_$item'),
                  color: Colors.grey,
                  child: Center(child: Text('$item')),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('exits selection mode when selection becomes empty', (
      tester,
    ) async {
      bool selectionModeActive = true;
      await tester.pumpWidget(
        buildTestGrid(
          initialSelection: {0},
          startInSelectionMode: true,
          onSelectionModeChanged: (active) => selectionModeActive = active,
          onSelectionChanged: (_) {},
        ),
      );

      // Deselect the only selected item
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(selectionModeActive, isFalse);
    });

    testWidgets('stays in selection mode at empty when told not to exit', (
      tester,
    ) async {
      // Surfaces that hand mode ownership to a SelectionController need the
      // grid to stop deciding on its own: an explicitly entered mode has to
      // survive at zero checked, and the grid cannot know how it was entered.
      bool? reportedMode;
      Set<int> selection = {0};
      await tester.pumpWidget(
        buildTestGrid(
          initialSelection: {0},
          startInSelectionMode: true,
          exitOnEmptySelection: false,
          onSelectionModeChanged: (active) => reportedMode = active,
          onSelectionChanged: (s) => selection = s,
        ),
      );

      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(selection, isEmpty, reason: 'the item must still be unchecked');
      expect(
        reportedMode,
        isNull,
        reason: 'the grid must not announce an exit it was told not to make',
      );

      // Still in selection mode, so a tap toggles rather than passing through.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(selection, {1});
    });
  });
}
