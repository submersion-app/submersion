import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// Pumps [child] at [width] logical pixels, pinned to the top start corner.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 700,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  double left(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dx;
  double right(WidgetTester tester, String text) =>
      tester.getTopRight(find.text(text)).dx;

  testWidgets('value starts 16 px after its label when ungrouped', (
    tester,
  ) async {
    await _pump(tester, DetailRow.text(label: 'Brand', value: 'Apeks'));

    expect(left(tester, 'Apeks'), right(tester, 'Brand') + DetailRow.gap);
  });

  testWidgets('values in one group share a column', (tester) async {
    await _pump(
      tester,
      DetailRowGroup(
        child: Column(
          children: [
            DetailRow.text(label: 'Status', value: 'Active'),
            DetailRow.text(label: 'Serial number', value: 'AX1'),
          ],
        ),
      ),
    );

    final column = right(tester, 'Serial number') + DetailRow.gap;
    expect(left(tester, 'Active'), column);
    expect(left(tester, 'AX1'), column);
  });

  testWidgets('label column is capped at 40% and the label wraps', (
    tester,
  ) async {
    const label = 'Surface interval label';
    await _pump(tester, DetailRow.text(label: label, value: 'x'), width: 300);

    expect(tester.takeException(), isNull);
    expect(left(tester, 'x'), 300 * DetailRow.maxLabelShare + DetailRow.gap);
    // Wrapped onto more than one line.
    expect(
      tester.getSize(find.text(label)).height,
      greaterThan(tester.getSize(find.text('x')).height),
    );
  });

  testWidgets('an icon row and a plain row align', (tester) async {
    await _pump(
      tester,
      DetailRowGroup(
        child: Column(
          children: [
            DetailRow.text(label: 'State', icon: Icons.waves, value: 'Rising'),
            DetailRow.text(label: 'Height', value: '1.2 m'),
          ],
        ),
      ),
    );

    expect(left(tester, 'Rising'), left(tester, '1.2 m'));
    // The icon row's cell (icon, gap, label) is the wider one.
    expect(left(tester, 'Rising'), right(tester, 'State') + DetailRow.gap);
  });

  testWidgets('empty label continuation row aligns under the value above', (
    tester,
  ) async {
    await _pump(
      tester,
      DetailRowGroup(
        child: Column(
          children: [
            DetailRow.text(label: 'Training courses', value: 'Open Water'),
            DetailRow.text(label: '', value: 'Nitrox'),
          ],
        ),
      ),
    );

    expect(left(tester, 'Nitrox'), left(tester, 'Open Water'));
  });

  testWidgets('long value wraps inside the value column', (tester) async {
    const value =
        'Long hose right post, bungeed necklace on the left, and a spare';
    await _pump(
      tester,
      DetailRow.text(label: 'Notes', value: value),
      width: 400,
    );

    final start = right(tester, 'Notes') + DetailRow.gap;
    expect(left(tester, value), start);
    expect(right(tester, value), lessThanOrEqualTo(400));
    expect(
      tester.getSize(find.text(value)).height,
      greaterThan(tester.getSize(find.text('Notes')).height),
    );
  });

  testWidgets('a row added later widens the column in the same frame', (
    tester,
  ) async {
    var showLate = false;
    late StateSetter setState;
    await _pump(
      tester,
      DetailRowGroup(
        child: StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Column(
              children: [
                DetailRow.text(label: 'Status', value: 'Active'),
                if (showLate)
                  DetailRow.text(label: 'Surface interval', value: '1:20'),
              ],
            );
          },
        ),
      ),
    );
    final before = left(tester, 'Active');

    setState(() => showLate = true);
    await tester.pump();

    expect(left(tester, 'Active'), greaterThan(before));
    expect(left(tester, 'Active'), left(tester, '1:20'));
  });

  testWidgets('removing the widest row and changing a label move the column', (
    tester,
  ) async {
    var showWide = true;
    var label = 'Status';
    late StateSetter setState;
    await _pump(
      tester,
      DetailRowGroup(
        child: StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Column(
              children: [
                DetailRow.text(label: label, value: 'Active'),
                DetailRow.text(label: 'Model', value: 'XTX50'),
                if (showWide)
                  DetailRow.text(label: 'Serial number', value: 'AX1'),
              ],
            );
          },
        ),
      ),
    );
    final wide = left(tester, 'Active');

    setState(() => showWide = false);
    await tester.pump();
    final narrow = left(tester, 'Active');
    expect(narrow, lessThan(wide));
    expect(narrow, right(tester, 'Status') + DetailRow.gap);

    setState(() => label = 'Status of the item');
    await tester.pump();
    expect(left(tester, 'XTX50'), right(tester, label) + DetailRow.gap);
    expect(left(tester, 'XTX50'), greaterThan(wide));
  });

  testWidgets('RTL mirrors the layout', (tester) async {
    await _pump(
      tester,
      DetailRow.text(label: 'Brand', value: 'Apeks'),
      textDirection: TextDirection.rtl,
    );

    expect(
      right(tester, 'Brand'),
      tester.getTopRight(find.byType(DetailRow)).dx,
    );
    expect(right(tester, 'Apeks'), left(tester, 'Brand') - DetailRow.gap);
  });

  testWidgets('text scale widens the column', (tester) async {
    await _pump(tester, DetailRow.text(label: 'Brand', value: 'Apeks'));
    final normal = left(tester, 'Apeks');

    await _pump(
      tester,
      DetailRow.text(label: 'Brand', value: 'Apeks'),
      textScale: 2,
    );

    expect(left(tester, 'Apeks'), greaterThan(normal));
    expect(left(tester, 'Apeks'), right(tester, 'Brand') + DetailRow.gap);
  });

  testWidgets('narrow width with large text does not overflow', (tester) async {
    await _pump(
      tester,
      DetailRow.text(
        label: 'Oberflaechenintervall',
        value: 'Long value text here',
      ),
      width: 200,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('taps inside the value land', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      DetailRow(
        label: 'Receipt',
        value: InkWell(onTap: () => tapped = true, child: const Text('link')),
      ),
    );

    await tester.tap(find.text('link'));

    expect(tapped, isTrue);
  });

  testWidgets('values top-align with the first label line', (tester) async {
    await _pump(
      tester,
      DetailRow.text(label: 'Surface interval label', value: 'x'),
      width: 300,
    );

    expect(
      tester.getTopLeft(find.text('x')).dy,
      tester.getTopLeft(find.text('Surface interval label')).dy,
    );
  });
}
