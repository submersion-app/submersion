import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

void main() {
  Widget host({
    required bool isSelectionMode,
    bool isChecked = false,
    bool isSelectable = true,
    ValueChanged<bool>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          isSelectable: isSelectable,
          onChanged: onChanged ?? (_) {},
          child: const Text('412'),
        ),
      ),
    );
  }

  group('SelectionLeading', () {
    testWidgets('shows the child and no checkbox outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: false));
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('replaces the child with a checkbox in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: true));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('412'), findsNothing);
    });

    testWidgets('reflects the checked state', (tester) async {
      await tester.pumpWidget(host(isSelectionMode: true, isChecked: true));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('keeps the child for non-selectable rows', (tester) async {
      await tester.pumpWidget(host(isSelectionMode: true, isSelectable: false));
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('reports a change when tapped', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        host(isSelectionMode: true, onChanged: (v) => reported = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      expect(reported, isTrue);
    });

    testWidgets('renders a disabled checkbox when onChanged is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectionLeading(
              isSelectionMode: true,
              isChecked: false,
              child: Text('412'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });
  });
}
