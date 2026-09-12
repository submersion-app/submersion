import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selection_inset.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

void main() {
  const leadingChild = ValueKey('leading_child');
  const insetChild = ValueKey('inset_child');

  /// A first line led by a [SelectionLeading], and a later line indented to
  /// sit under that line's leading element.
  Widget host({required bool isSelectionMode, double start = 0}) => MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: false,
            child: const SizedBox(key: leadingChild, width: 40, height: 40),
          ),
          SelectionInset(
            isSelectionMode: isSelectionMode,
            start: start,
            child: const SizedBox(key: insetChild, width: 10, height: 10),
          ),
        ],
      ),
    ),
  );

  group('SelectionInset', () {
    testWidgets('indents by start alone outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: false, start: 52));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(insetChild)).dx, 52);
    });

    testWidgets('moves with the checkbox column in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: true));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(insetChild)).dx,
        tester.getTopLeft(find.byKey(leadingChild)).dx,
        reason: 'the inset grows by exactly the width the checkbox adds',
      );
    });

    testWidgets('keeps start on top of the checkbox column', (tester) async {
      await tester.pumpWidget(host(isSelectionMode: true, start: 52));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(insetChild)).dx,
        tester.getTopLeft(find.byKey(leadingChild)).dx + 52,
      );
    });
  });
}
