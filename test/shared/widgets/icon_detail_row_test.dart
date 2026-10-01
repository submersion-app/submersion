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
