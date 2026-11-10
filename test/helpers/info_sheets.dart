import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_sheet.dart';

/// Opens and closes the info sheet of every info icon built on screen, and
/// returns how many there were.
///
/// Each icon's content builder runs when it is pressed, not when its card
/// builds, so this is what proves a page's sheets build: a builder that reads
/// a missing provider or an unknown key throws here. The button is pressed
/// through its callback rather than a tap, so an icon scrolled out of view or
/// covered by an overlapping header still opens.
Future<int> openEveryInfoSheet(WidgetTester tester) async {
  final icons = find.byType(InfoButton, skipOffstage: false);
  final count = icons.evaluate().length;
  for (var i = 0; i < count; i++) {
    final button = tester.widget<IconButton>(
      find.descendant(
        of: icons.at(i),
        matching: find.byType(IconButton),
        skipOffstage: false,
      ),
    );
    button.onPressed!();
    // Fixed pumps, not pumpAndSettle: pages with a spinner never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final sheet = find.byType(InfoSheetBody);
    expect(sheet, findsOneWidget, reason: 'info icon $i opened no sheet');
    expect(
      tester.widget<InfoSheetBody>(sheet).content.title,
      isNotEmpty,
      reason: 'info icon $i',
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return count;
}
