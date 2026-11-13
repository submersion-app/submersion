import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expects the dive-number text [label] to be laid out on a single line and
/// drawn wholly inside the 40 point badge that holds it (#4497).
///
/// A wrapped paragraph is taller than its one-line height, which is its
/// intrinsic height at unbounded width. The drawn rect comes from
/// [WidgetTester.getRect], so it includes any scaling applied above the text.
void expectDiveNumberOnOneLineInBadge(WidgetTester tester, String label) {
  final text = find.text(label);
  expect(text, findsOneWidget);

  final paragraph = tester.renderObject<RenderParagraph>(text);
  final oneLineHeight = paragraph.getMaxIntrinsicHeight(double.infinity);
  expect(
    paragraph.size.height,
    closeTo(oneLineHeight, 0.01),
    reason: '$label wrapped onto more than one line',
  );

  // The nearest ancestor laid out as the 40 point square, whatever widget
  // draws it.
  final badge = find
      .ancestor(of: text, matching: find.byWidgetPredicate((_) => true))
      .evaluate()
      .firstWhere((element) {
        final box = element.renderObject;
        return box is RenderBox && box.size == const Size(40, 40);
      });
  final badgeBox = badge.renderObject! as RenderBox;
  final badgeRect = badgeBox.localToGlobal(Offset.zero) & badgeBox.size;
  final textRect = tester.getRect(text);
  expect(
    badgeRect.inflate(0.01).contains(textRect.topLeft) &&
        badgeRect.inflate(0.01).contains(textRect.bottomRight),
    isTrue,
    reason: '$label at $textRect spills out of its badge at $badgeRect',
  );
}
