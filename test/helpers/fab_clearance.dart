import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shrinks the test view to [height] logical pixels, so a page whose rows
/// come from fixed seed data still overflows it. Resets when the test ends.
void useShortViewport(WidgetTester tester, {double height = 400}) {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Scrolls the page's list to its end and checks that its last row clears
/// the floating action button (issue #2029).
///
/// Without bottom clearance the last row of a list stops at the viewport
/// edge, right under the FAB, and a tap on its trailing action lands on the
/// FAB instead. The list must actually overflow the viewport, otherwise the
/// last row never reaches the FAB and the check would pass for any layout.
///
/// [lastRow] defaults to the last [ListTile] built once the list is at its
/// end. Pass it when the part that matters is narrower than the row, such as
/// a trailing button; it may name a widget a lazy list has not built yet.
Future<void> expectLastRowClearOfFab(
  WidgetTester tester, {
  Finder? lastRow,
}) async {
  // The last tile, not the first: a page may put a settings tile above its
  // list, outside any scrollable.
  final scrollable = find
      .ancestor(
        of: find.byType(ListTile).last,
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(
    position.maxScrollExtent,
    greaterThan(0),
    reason: 'the list must overflow the viewport for the check to mean much',
  );

  // A lazy list only estimates its extent until the tail rows are built, so
  // one jump can land short of the real end. Jump until the extent holds.
  double end;
  do {
    end = position.maxScrollExtent;
    position.jumpTo(end);
    await tester.pump();
  } while (position.maxScrollExtent != end);

  // Re-resolve after the scroll: a lazy list may have built new rows.
  final rowRect = tester.getRect(lastRow ?? find.byType(ListTile).last);
  final fabRect = tester.getRect(find.byType(FloatingActionButton));
  expect(
    rowRect.overlaps(fabRect),
    isFalse,
    reason: 'last row $rowRect sits under the FAB $fabRect',
  );
}
