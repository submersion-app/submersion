import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/icon_detail_row.dart';

void main() {
  // Under the test font every glyph is one em wide, so a bodyMedium (14 px)
  // string is 14 px per character and one line is 20 px tall.
  const lineHeight = 20.0;
  const rowWidth = 300.0;

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

    // The label column (icon, gap, label) stops at 40% of the row, and the
    // value starts one gap after it.
    final label = find.text('Tambien reconocida como');
    final value = find.text('CCR Normoxic Plus 70m MOD2');
    expect(tester.getTopRight(label).dx, lessThanOrEqualTo(rowWidth * 0.4));
    expect(tester.getTopLeft(value).dx, rowWidth * 0.4 + 16);
  });

  testWidgets('the 40% cap holds even beside a short value (issue #3678)', (
    tester,
  ) async {
    // 12 characters is 168 px: with the icon it is wider than 40% of the
    // row, so it wraps, even though it would fit beside "12". Every value
    // of a card shares one column, which only labels decide.
    await pumpRow(tester, label: 'Gemeinsame T', value: '12');

    expect(
      tester.getSize(find.text('Gemeinsame T')).height,
      greaterThan(lineHeight),
    );
    expect(tester.getTopLeft(find.text('12')).dx, rowWidth * 0.4 + 16);
  });

  testWidgets('a short value sits beside its label, start-aligned', (
    tester,
  ) async {
    await pumpRow(tester, label: 'Type', value: 'PADI');

    expect(
      tester.getTopLeft(find.text('PADI')).dx,
      tester.getTopRight(find.text('Type')).dx + 16,
    );
    // Its box hugs the text instead of spanning the row end-aligned.
    expect(
      tester.widget<Text>(find.text('PADI')).textAlign,
      isNot(TextAlign.end),
    );
    expect(tester.getSize(find.text('PADI')).width, lessThan(rowWidth / 4));
  });

  for (final scale in [1.35, 0.85]) {
    testWidgets('the icon centres on the first line at text scale $scale', (
      tester,
    ) async {
      await pumpRow(tester, label: 'Type', value: 'PADI', textScale: scale);

      final icon = tester.getCenter(find.byIcon(Icons.card_membership)).dy;
      final label = tester.getCenter(find.text('Type')).dy;
      expect(icon, closeTo(label, 0.01));
    });
  }

  testWidgets('a screen reader hears the row once, as "label: value"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester, label: 'Type', value: 'PADI');

    expect(find.bySemanticsLabel('Type: PADI'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Type$')), findsNothing);
    // Disposed in the body: the binding checks for a live handle before
    // tear-downs run.
    semantics.dispose();
  });

  testWidgets('a row narrower than its icon never builds invalid '
      'constraints', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 20,
              child: IconDetailRow(
                icon: Icons.card_membership,
                label: 'Type',
                value: 'PADI',
              ),
            ),
          ),
        ),
      ),
    );

    // The fixed icon and gaps overflow a 20 px row, which is reported; what
    // must not happen is a negative label width failing the constraints.
    final error = tester.takeException();
    expect(error.toString(), isNot(contains('NOT NORMALIZED')));
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
