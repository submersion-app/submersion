import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drags the page up from [from], a step at a time, until [field] sits
/// wholly above [bottom], or the page stops moving.
Future<void> dragPageUntilShown(
  WidgetTester tester,
  Finder field, {
  required double bottom,
  required Offset from,
}) async {
  for (var i = 0; i < 20; i++) {
    final rect = tester.getRect(field);
    if (rect.bottom <= bottom && rect.top >= 0 && !_underTabRow(tester, rect)) {
      return;
    }
    final step = rect.top < 0 ? 80.0 : -80.0;
    await tester.dragFrom(from, Offset(0, step));
    await tester.pumpAndSettle();
    if (tester.getRect(field) == rect) return;
  }
}

/// [field] lies wholly above [bottom], over the tab row, and takes a tap.
void expectFullyShown(
  WidgetTester tester,
  Finder field, {
  required double bottom,
}) {
  final rect = tester.getRect(field);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$field top');
  expect(rect.bottom, lessThanOrEqualTo(bottom), reason: '$field bottom');
  expect(
    _underTabRow(tester, rect),
    isFalse,
    reason: '$field lies under the tab row',
  );
  final target = tester.renderObject(field);
  final hits = tester.hitTestOnBinding(rect.center).path;
  expect(
    hits.any((entry) => entry.target == target),
    isTrue,
    reason: '$field takes no tap at its centre',
  );
}

/// Whether [rect] overlaps the tab row.
bool _underTabRow(WidgetTester tester, Rect rect) {
  final tabs = find.byType(TabBar);
  if (tabs.evaluate().isEmpty) return false;
  final tabRow = tester.getRect(tabs);
  return rect.bottom > tabRow.top && rect.top < tabRow.bottom;
}
