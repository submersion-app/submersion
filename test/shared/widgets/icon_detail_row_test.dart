import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/icon_detail_row.dart';

void main() {
  // Under the test font every glyph is one em wide, so a bodyMedium (14 px)
  // string is 14 px per character and one line is 20 px tall.
  const lineHeight = 20.0;
  const rowWidth = 300.0;
  // The icon (20 px) and its 12 px gap come off the front of the row.
  const textWidth = rowWidth - 32;

  Future<void> pumpRow(
    WidgetTester tester, {
    required String label,
    required String value,
    Color? valueColor,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: rowWidth,
                child: IconDetailRow(
                  icon: Icons.card_membership,
                  label: label,
                  value: value,
                  valueColor: valueColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a long value wraps beside a one-line label (issue #2695)', (
    tester,
  ) async {
    await pumpRow(tester, label: 'Type', value: 'CCR Normoxic Plus 70m MOD2');

    final label = find.text('Type');
    final value = find.text('CCR Normoxic Plus 70m MOD2');
    expect(tester.getSize(label).height, lineHeight);
    expect(tester.getSize(value).height, greaterThan(lineHeight));
    expect(
      tester.getTopLeft(value).dx,
      greaterThan(tester.getTopRight(label).dx),
    );
    // The label stays on the value's first line instead of drifting to the
    // middle of the wrapped block.
    expect(tester.getTopLeft(label).dy, tester.getTopLeft(value).dy);
  });

  testWidgets('a long label wraps rather than squeezing a short value', (
    tester,
  ) async {
    // 23 characters, as the Spanish "Also Recognized" label is: wider than
    // the row leaves once a short value is placed.
    await pumpRow(tester, label: 'Tambien reconocida como', value: 'PADI');

    expect(tester.getSize(find.text('PADI')).height, lineHeight);
    expect(
      tester.getSize(find.text('Tambien reconocida como')).height,
      greaterThan(lineHeight),
    );
  });

  testWidgets('a long label never takes more than 40% from a long value', (
    tester,
  ) async {
    await pumpRow(
      tester,
      label: 'Tambien reconocida como',
      value: 'CCR Normoxic Plus 70m MOD2',
    );

    final label = find.text('Tambien reconocida como');
    final value = find.text('CCR Normoxic Plus 70m MOD2');
    expect(tester.getSize(label).width, lessThanOrEqualTo(textWidth * 0.4));
    expect(
      tester.getSize(value).width,
      greaterThanOrEqualTo(textWidth * 0.6 - 16),
    );
  });

  testWidgets('a label that fits beside its value keeps one line', (
    tester,
  ) async {
    // 12 characters is 168 px, wider than 40% of the row, yet it fits beside
    // a four-character value, so it must not be wrapped early.
    await pumpRow(tester, label: 'Gemeinsame T', value: '12');

    expect(tester.getSize(find.text('Gemeinsame T')).height, lineHeight);
  });

  testWidgets('the icon centres on the first line at a larger text size', (
    tester,
  ) async {
    await pumpRow(tester, label: 'Type', value: 'PADI', textScale: 1.35);

    final icon = tester.getCenter(find.byIcon(Icons.card_membership)).dy;
    final label = tester.getCenter(find.text('Type')).dy;
    expect(icon, closeTo(label, 0.01));
  });

  testWidgets('reads as one "label: value" node and tints the value', (
    tester,
  ) async {
    await pumpRow(
      tester,
      label: 'Expiry Date',
      value: 'May 1, 2026',
      valueColor: Colors.red,
    );

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Expiry Date: May 1, 2026',
      ),
      findsOneWidget,
    );
    final value = tester.widget<Text>(find.text('May 1, 2026'));
    expect(value.style?.color, Colors.red);
    expect(value.style?.fontWeight, FontWeight.bold);
  });
}
