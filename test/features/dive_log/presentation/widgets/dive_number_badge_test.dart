import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_number_badge.dart';

import '../../../../helpers/dive_number_badge_expectations.dart';

Future<void> _pumpBadge(WidgetTester tester, int? diveNumber) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: DiveNumberBadge(diveNumber: diveNumber)),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the dive number with a hash', (tester) async {
    await _pumpBadge(tester, 42);

    expect(find.text('#42'), findsOneWidget);
  });

  testWidgets('shows a dash for a dive without a number', (tester) async {
    await _pumpBadge(tester, null);

    expect(find.text('#-'), findsOneWidget);
  });

  testWidgets('stays a 40 point square', (tester) async {
    await _pumpBadge(tester, 7);

    expect(tester.getSize(find.byType(DiveNumberBadge)), const Size(40, 40));
  });

  // #4497: a fixed 40 point box wrapped "#1234" onto two lines.
  for (final number in [999, 1234, 12345]) {
    testWidgets('keeps #$number on one line inside the badge', (tester) async {
      await _pumpBadge(tester, number);

      expectDiveNumberOnOneLineInBadge(tester, '#$number');
    });
  }

  testWidgets('does not enlarge a short number to fill the badge', (
    tester,
  ) async {
    await _pumpBadge(tester, 7);

    final paragraph = tester.renderObject<RenderParagraph>(find.text('#7'));
    final rect = tester.getRect(find.text('#7'));
    expect(rect.width, closeTo(paragraph.size.width, 0.01));
  });
}
