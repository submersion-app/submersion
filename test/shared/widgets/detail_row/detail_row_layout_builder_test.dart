import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// A detail card as the dive detail page builds one: a group of rows whose
/// labels differ in width, the widest first, so the column narrows as the
/// card's rows leave one by one.
Widget _card(String tag) => Card(
  child: DetailRowGroup(
    child: Column(
      children: [
        DetailRow.text(label: 'Surface interval', value: '$tag-1'),
        DetailRow.text(label: 'Dive type', value: '$tag-2'),
        DetailRow.text(label: 'Mode', value: '$tag-3'),
      ],
    ),
  ),
);

/// Pumps [child] at [width] logical pixels inside the macOS window the
/// assertion was seen in: 1280x860 logical.
Future<void> _pump(WidgetTester tester, Widget child, {required double width}) {
  tester.view
    ..physicalSize = const Size(1280, 860)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a card removed below a LayoutBuilder drops its rows cleanly', (
    tester,
  ) async {
    var showCard = true;
    late StateSetter setState;
    await _pump(
      tester,
      LayoutBuilder(
        builder: (context, constraints) => StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Column(
              children: [
                if (showCard) _card('a') else const Text('No card'),
                _card('b'),
              ],
            );
          },
        ),
      ),
      width: 1000,
    );

    // The StatefulBuilder sits below the LayoutBuilder, so it rebuilds
    // during the LayoutBuilder's layout, not in the frame's build pass.
    setState(() => showCard = false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('a-1'), findsNothing);
    expect(
      tester.getTopLeft(find.text('b-1')).dx,
      tester.getTopLeft(find.text('b-3')).dx,
    );
  });

  testWidgets('a keyed row lifted out of a dropped card takes the new column', (
    tester,
  ) async {
    final key = GlobalKey();
    var inCard = true;
    late StateSetter setState;
    await _pump(
      tester,
      LayoutBuilder(
        builder: (context, constraints) => DetailRowGroup(
          child: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              final mode = DetailRow.text(key: key, label: 'Mode', value: 'M');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inCard)
                    Column(
                      children: [
                        DetailRow.text(label: 'Surface interval', value: 'S'),
                        mode,
                      ],
                    )
                  else
                    mode,
                  DetailRow.text(label: 'Dive type', value: 'D'),
                ],
              );
            },
          ),
        ),
      ),
      width: 1000,
    );
    final wide = tester.getTopLeft(find.text('M')).dx;

    // The card's widest row detaches while the keyed row is still inside
    // the dropped card, so the keyed row skips the narrower column, then
    // comes back at the same width and constraints.
    setState(() => inCard = false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final narrow = tester.getTopLeft(find.text('M')).dx;
    expect(narrow, lessThan(wide));
    expect(narrow, tester.getTopLeft(find.text('D')).dx);
  });

  testWidgets('a row leaving a live group below a LayoutBuilder still '
      'narrows the column in the same frame', (tester) async {
    var showWide = true;
    late StateSetter setState;
    await _pump(
      tester,
      LayoutBuilder(
        builder: (context, constraints) => DetailRowGroup(
          child: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return Column(
                children: [
                  if (showWide)
                    DetailRow.text(label: 'Surface interval', value: 'S'),
                  DetailRow.text(label: 'Mode', value: 'M'),
                  DetailRow.text(label: 'Dive type', value: 'D'),
                ],
              );
            },
          ),
        ),
      ),
      width: 1000,
    );
    final wide = tester.getTopLeft(find.text('M')).dx;

    setState(() => showWide = false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final narrow = tester.getTopLeft(find.text('M')).dx;
    expect(narrow, lessThan(wide));
    expect(narrow, tester.getTopLeft(find.text('D')).dx);
  });
}
