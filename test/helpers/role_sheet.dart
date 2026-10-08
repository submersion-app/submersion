import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In an open role sheet (issue #1221), leaves exactly [label] ticked and
/// confirms with the sheet's Done, which is the topmost Done when a buddy
/// selection sheet sits underneath.
Future<void> pickOnlyRole(WidgetTester tester, String label) async {
  final target = find.widgetWithText(CheckboxListTile, label);
  if (tester.widget<CheckboxListTile>(target).value != true) {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
  while (true) {
    final keep = tester.widget<CheckboxListTile>(target);
    final others = find.byWidgetPredicate(
      (w) => w is CheckboxListTile && w.value == true && !identical(w, keep),
    );
    if (others.evaluate().isEmpty) break;
    await tester.tap(others.first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Done').last);
  await tester.pumpAndSettle();
}
