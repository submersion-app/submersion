import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/render_detail_row.dart';

/// Pumps [child] at [width] logical pixels, pinned to the top start corner.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 700,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
  bool boldText = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            boldText: boldText,
          ),
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

/// The SDK's bundled Roboto fonts: under FLUTTER_ROOT when it is set,
/// otherwise found by walking up from the test binary to the SDK root.
String _materialFontsDir() {
  String fontsUnder(String root) =>
      p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) return fontsUnder(root);
  var dir = p.dirname(Platform.resolvedExecutable);
  while (p.dirname(dir) != dir) {
    if (Directory(fontsUnder(dir)).existsSync()) return fontsUnder(dir);
    dir = p.dirname(dir);
  }
  throw StateError('No Flutter SDK above ${Platform.resolvedExecutable}');
}

void main() {
  // A real font, registered mid-test to stand in for a theme font that
  // google_fonts fetches after the first frame. Read here: file reads in a
  // testWidgets body deadlock under its fake clock. The engine cannot
  // unload a font, so both families are named for this file alone and no
  // other test can render with them.
  late ByteData lateFont;
  const boldFamily = 'DetailRowBoldFont';
  setUpAll(() async {
    final fonts = _materialFontsDir();
    Future<ByteData> font(String name) async => ByteData.sublistView(
      await File(p.join(fonts, '$name.ttf')).readAsBytes(),
    );
    lateFont = await font('Roboto-Regular');
    // Regular and bold faces of one family, so bold text really is wider,
    // which the test font's square glyphs are not.
    await (FontLoader(boldFamily)
          ..addFont(font('Roboto-Regular'))
          ..addFont(font('Roboto-Bold')))
        .load();
  });

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

  testWidgets('rows with no label at all start at the edge, with no gap', (
    tester,
  ) async {
    await _pump(
      tester,
      DetailRowGroup(
        child: DetailRow.text(label: '', value: 'Served'),
      ),
    );

    expect(left(tester, 'Served'), 0);
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

  testWidgets('Bold Text keeps the widest label on one line', (tester) async {
    const style = TextStyle(fontFamily: boldFamily, fontSize: 14);
    await _pump(
      tester,
      DetailRowGroup(
        child: Column(
          children: [
            DetailRow.text(
              label: 'Manufacturer',
              labelStyle: style,
              value: 'Shearwater',
            ),
            DetailRow.text(label: 'Model', labelStyle: style, value: 'Perdix'),
          ],
        ),
      ),
      boldText: true,
    );

    expect(
      tester.getSize(find.text('Manufacturer')).height,
      tester.getSize(find.text('Model')).height,
    );
    expect(
      left(tester, 'Shearwater'),
      right(tester, 'Manufacturer') + DetailRow.gap,
    );
  });

  testWidgets('a font that loads after the first frame re-measures the '
      'column', (tester) async {
    const family = 'DetailRowLateFont';
    const style = TextStyle(fontFamily: family, fontSize: 14);
    await _pump(
      tester,
      DetailRow.text(label: 'Manufacturer', labelStyle: style, value: 'x'),
    );

    await tester.runAsync(
      () => (FontLoader(family)..addFont(Future.value(lateFont))).load(),
    );
    await tester.pump();

    expect(left(tester, 'x'), right(tester, 'Manufacturer') + DetailRow.gap);
  });

  testWidgets('the dry baseline is the label baseline', (tester) async {
    await _pump(tester, DetailRow.text(label: 'Brand', value: 'Apeks'));

    final row = tester.renderObject<RenderBox>(find.byType(DetailRowLayout));
    // The label sits at the row's top, so the row's baseline is its own.
    final painter = TextPainter(
      text: TextSpan(
        text: 'Brand',
        style: tester.widget<Text>(find.text('Brand')).style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    expect(
      row.getDryBaseline(
        BoxConstraints(maxWidth: row.size.width),
        TextBaseline.alphabetic,
      ),
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    );
  });

  testWidgets('a label-less row adds no gap to its min intrinsic width', (
    tester,
  ) async {
    await _pump(
      tester,
      DetailRowGroup(
        child: DetailRow.text(label: '', value: 'Served'),
      ),
    );

    final row = tester.renderObject<RenderBox>(find.byType(DetailRowLayout));
    final value = tester.renderObject<RenderBox>(find.text('Served'));
    expect(
      row.getMinIntrinsicWidth(double.infinity),
      value.getMinIntrinsicWidth(double.infinity),
    );
  });

  testWidgets('an unbounded row sizes to its label, gap and value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [DetailRow.text(label: 'Brand', value: 'Apeks')],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(left(tester, 'Apeks'), right(tester, 'Brand') + DetailRow.gap);
    expect(
      tester.getSize(find.byType(DetailRowLayout)).width,
      right(tester, 'Apeks') - left(tester, 'Brand'),
    );
  });

  testWidgets('dry layout and intrinsic heights match the real layout', (
    tester,
  ) async {
    // A label over the 40% cap, so the label wraps and sets the height.
    await _pump(
      tester,
      DetailRow.text(label: 'Surface interval label', value: 'x'),
      width: 300,
    );

    final row = tester.renderObject<RenderBox>(find.byType(DetailRowLayout));
    expect(row.getDryLayout(const BoxConstraints(maxWidth: 300)), row.size);
    expect(row.getMinIntrinsicHeight(300), row.size.height);
    expect(row.getMaxIntrinsicHeight(300), row.size.height);
  });

  testWidgets('max intrinsic width is the label column, gap and value', (
    tester,
  ) async {
    await _pump(tester, DetailRow.text(label: 'Brand', value: 'Apeks'));

    final row = tester.renderObject<RenderBox>(find.byType(DetailRowLayout));
    expect(
      row.getMaxIntrinsicWidth(double.infinity),
      tester.getSize(find.text('Brand')).width +
          DetailRow.gap +
          tester.getSize(find.text('Apeks')).width,
    );
  });

  testWidgets('a row moved to another group leaves the old column', (
    tester,
  ) async {
    final key = GlobalKey();
    Widget build({required bool inFirst}) => Column(
      children: [
        DetailRowGroup(
          child: Column(
            children: [
              DetailRow.text(label: 'Model', value: 'A'),
              if (inFirst)
                DetailRow.text(key: key, label: 'Serial number', value: 'S'),
            ],
          ),
        ),
        DetailRowGroup(
          child: Column(
            children: [
              DetailRow.text(label: 'Brand', value: 'B'),
              if (!inFirst)
                DetailRow.text(key: key, label: 'Serial number', value: 'S'),
            ],
          ),
        ),
      ],
    );
    await _pump(tester, build(inFirst: true));
    expect(left(tester, 'A'), left(tester, 'S'));

    await _pump(tester, build(inFirst: false));

    expect(left(tester, 'A'), right(tester, 'Model') + DetailRow.gap);
    expect(left(tester, 'B'), left(tester, 'S'));
  });

  testWidgets('switching direction mirrors a laid-out row', (tester) async {
    await _pump(tester, DetailRow.text(label: 'Brand', value: 'Apeks'));
    expect(left(tester, 'Apeks'), greaterThan(left(tester, 'Brand')));

    await _pump(
      tester,
      DetailRow.text(label: 'Brand', value: 'Apeks'),
      textDirection: TextDirection.rtl,
    );

    expect(right(tester, 'Apeks'), left(tester, 'Brand') - DetailRow.gap);
  });

  testWidgets('a baseline-aligned row lines up with the label', (tester) async {
    await _pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('Ref', style: TextStyle(fontSize: 30)),
          Expanded(
            child: DetailRow.text(
              label: 'Brand',
              value: 'Apeks',
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    // Different sizes, so the texts' tops differ by exactly the difference
    // between their baselines only when the row reports the label's.
    double baselineOf(String text) {
      final element = tester.element(find.text(text));
      final style = DefaultTextStyle.of(
        element,
      ).style.merge(tester.widget<Text>(find.text(text)).style);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      return painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    }

    final ref = tester.getTopLeft(find.text('Ref')).dy;
    final brand = tester.getTopLeft(find.text('Brand')).dy;
    expect(brand - ref, closeTo(baselineOf('Ref') - baselineOf('Brand'), 0.01));
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
