import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/record_list_chevron.dart';

/// The painted bounds of the first record card on screen: the [Material] a
/// [Card] builds inside its margin.
Rect recordCardBounds(WidgetTester tester) => tester.getRect(
  find.descendant(of: find.byType(Card), matching: find.byType(Material)).first,
);

/// Expects the row's [RecordListChevron] to end [padding] from the end of
/// [bounds], the same distance the row's content starts from its start, so
/// the chevron sits at one place in every list (issue #4639).
void expectChevronAtEndPadding(
  WidgetTester tester, {
  required Rect bounds,
  required double padding,
}) {
  final chevron = find.byType(RecordListChevron);
  expect(chevron, findsOneWidget, reason: 'the row shows one shared chevron');
  expect(bounds.right - tester.getRect(chevron).right, closeTo(padding, 0.01));
}
