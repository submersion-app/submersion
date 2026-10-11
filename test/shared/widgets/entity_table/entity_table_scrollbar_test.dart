import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entity_table_test_harness.dart';

/// Every table shows a vertical and a horizontal scrollbar (#2984).
void main() {
  final many = [for (var i = 0; i < 80; i++) TestEntity('e$i', 'Name $i', i)];

  Scrollbar bar(WidgetTester tester, Axis axis) => tester
      .widgetList<Scrollbar>(find.byType(Scrollbar))
      .singleWhere((s) => s.controller!.position.axis == axis);

  testWidgets(
    'one vertical and one horizontal scrollbar, always shown on desktop',
    (tester) async {
      await tester.pumpWidget(buildTestTable(entities: many));
      await tester.pumpAndSettle();
      expect(bar(tester, Axis.vertical).thumbVisibility, isTrue);
      expect(bar(tester, Axis.horizontal).thumbVisibility, isTrue);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('touch platforms keep the default visibility', (tester) async {
    await tester.pumpWidget(buildTestTable(entities: many));
    await tester.pumpAndSettle();
    expect(bar(tester, Axis.vertical).thumbVisibility, isNull);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('the vertical bar tracks the body list as it scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestTable(entities: many));
    await tester.pumpAndSettle();
    final vertical = bar(tester, Axis.vertical).controller!;
    await tester.drag(find.text('5'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
  });
}
