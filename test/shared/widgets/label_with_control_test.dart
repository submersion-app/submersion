import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/label_with_control.dart';

void main() {
  const labelKey = Key('label');
  const controlKey = Key('control');

  Future<void> pumpRow(
    WidgetTester tester, {
    required double width,
    required String label,
    double controlWidth = 200,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LabelWithControl(
                label: Text(label, key: labelKey),
                control: SizedBox(
                  key: controlKey,
                  width: controlWidth,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps label and control on one line when both fit', (
    tester,
  ) async {
    await pumpRow(tester, width: 600, label: 'Short');

    final label = tester.getRect(find.byKey(labelKey));
    final control = tester.getRect(find.byKey(controlKey));
    expect(label.left, 0);
    // The control sits at the far end of the same line.
    expect(control.right, 600);
    expect(control.center.dy, closeTo(label.center.dy, 0.5));
  });

  testWidgets(
    'moves the control below the label instead of squeezing it (#3358)',
    (tester) async {
      const longLabel = 'Aufstiegsplanung mit allen mitgefuehrten Flaschen';
      await pumpRow(tester, width: 300, label: longLabel, controlWidth: 240);

      final label = tester.getRect(find.byKey(labelKey));
      final control = tester.getRect(find.byKey(controlKey));
      // The label keeps the full width, so it breaks between words rather
      // than one character per line.
      expect(label.width, greaterThan(200));
      expect(control.top, greaterThanOrEqualTo(label.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fills a ListTile title so the control sits at the far end', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: ListTile(
                title: LabelWithControl(
                  label: Text('Short', key: labelKey),
                  control: SizedBox(key: controlKey, width: 100, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final label = tester.getRect(find.byKey(labelKey));
    final control = tester.getRect(find.byKey(controlKey));
    // A Material 3 ListTile pads 16 at the start and 24 at the end.
    expect(control.right, closeTo(576, 0.5));
    expect(control.center.dy, closeTo(label.center.dy, 0.5));
  });

  testWidgets('works as a ListTile title with a dropdown', (tester) async {
    // The test font draws every glyph a full em wide, so at 560 the title
    // slot (560 - 16 - 24 padding - 40 leading = 480) fits the label alone
    // (19 glyphs at 16) or the dropdown alone, but not both. A trailing
    // dropdown here left the label about 150, three lines tall.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            child: ListTile(
              leading: const Icon(Icons.swap_vert),
              title: LabelWithControl(
                label: const Text('Aufstieg planen mit', key: labelKey),
                control: DropdownButton<int>(
                  key: controlKey,
                  value: 0,
                  onChanged: (_) {},
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Alle mitgefuehrten'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final label = tester.getRect(find.byKey(labelKey));
    final control = tester.getRect(find.byKey(controlKey));
    expect(control.top, greaterThanOrEqualTo(label.bottom));
    // One line for the label: no per-character wrapping.
    final style = DefaultTextStyle.of(
      tester.element(find.byKey(labelKey)),
    ).style;
    expect(label.height, lessThan((style.fontSize ?? 16) * 2));
    expect(tester.takeException(), isNull);
  });
}
