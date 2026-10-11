import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';

import 'entity_table_test_harness.dart';

/// Column resizing follows the pointer and saves once (#2984).
void main() {
  Finder header(String label) =>
      find.widgetWithText(EntityTableHeaderCell, label);

  Future<TestGesture> grabRightEdge(WidgetTester tester, String label) async {
    final rect = tester.getRect(header(label));
    return tester.startGesture(
      Offset(rect.right - 2, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
  }

  testWidgets('the edge stays under the pointer past the minimum and back', (
    tester,
  ) async {
    final commits = <double>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [TestEntity('a', 'Alpha', 1)],
        onResizeColumn: (_, w) => commits.add(w),
      ),
    );
    // Count is 120 wide with a 60 minimum.
    final gesture = await grabRightEdge(tester, 'Count');
    await gesture.moveBy(const Offset(-100, 0)); // asks for 20, clamps to 60
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 60);

    await gesture.moveBy(const Offset(40, 0)); // pointer is 60 left of start
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 60);

    await gesture.moveBy(const Offset(30, 0)); // pointer is 30 left of start
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 90);
    expect(commits, isEmpty, reason: 'nothing saved mid-drag');

    await gesture.up();
    await tester.pump();
    expect(commits, [90]);
  });

  testWidgets('the width never exceeds the maximum', (tester) async {
    final commits = <double>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [TestEntity('a', 'Alpha', 1)],
        onResizeColumn: (_, w) => commits.add(w),
      ),
    );
    final gesture = await grabRightEdge(tester, 'Count');
    await gesture.moveBy(const Offset(900, 0));
    await gesture.up();
    await tester.pump();
    expect(commits, [600]);
  });

  testWidgets('in a right-to-left locale the handle is the left edge and '
      'tracks the pointer', (tester) async {
    final commits = <double>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [TestEntity('a', 'Alpha', 1)],
        onResizeColumn: (_, w) => commits.add(w),
        locale: const Locale('ar'),
      ),
    );
    // Columns run right to left, so Count's trailing edge is its left one.
    final rect = tester.getRect(header('Count'));
    final gesture = await tester.startGesture(
      Offset(rect.left + 2, rect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(100, 0)); // asks for 20, clamps to 60
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 60);

    await gesture.moveBy(const Offset(-70, 0)); // pointer 30 right of start
    await tester.pump();
    expect(tester.getSize(header('Count')).width, 90);

    await gesture.up();
    await tester.pump();
    expect(commits, [90]);
  });
}
