import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';
import 'package:submersion/shared/widgets/scenes/scene_clock.dart';
import 'package:submersion/shared/widgets/summary/chart_marks_layer.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

Future<void> _pump(
  WidgetTester tester,
  List<ChartMark> marks, {
  Size size = const Size(900, 500),
  bool compact = false,
  TextDirection direction = TextDirection.ltr,
  ValueNotifier<double>? time,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  Widget layer = ChartMarksLayer(marks: marks, compact: compact);
  if (time != null) layer = SceneTime(seconds: time, child: layer);
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: layer),
      ),
    ),
  );
}

ChartMark _mark(Offset at, String label, {VoidCallback? onTap}) => ChartMark(
  spot: ChartSpot(at: at),
  label: label,
  compactLabel: label.split(' ').first,
  onTap: onTap,
);

void main() {
  testWidgets('a mark with onTap is a link that calls it', (tester) async {
    var tapped = false;
    await _pump(tester, [
      _mark(
        const Offset(0.3, 0.5),
        'Blue Hole · 12',
        onTap: () => tapped = true,
      ),
    ]);

    await tester.tap(find.text('Blue Hole · 12'));

    expect(find.byType(SceneLink), findsOneWidget);
    expect(tapped, isTrue);
  });

  testWidgets('a mark without onTap is a plain label', (tester) async {
    await _pump(tester, [_mark(const Offset(0.3, 0.5), 'Home')]);

    expect(find.byType(SceneLink), findsNothing);
    expect(find.byType(SceneLabel), findsOneWidget);
  });

  testWidgets('compact shows the compact label', (tester) async {
    await _pump(tester, [
      _mark(const Offset(0.3, 0.5), 'Blue Hole · 12'),
    ], compact: true);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('Blue Hole · 12'), findsNothing);
  });

  testWidgets('labels sit to the end of a dot on the start half and flip '
      'past 60 percent', (tester) async {
    await _pump(tester, [
      _mark(const Offset(0.3, 0.5), 'Near'),
      _mark(const Offset(0.8, 0.5), 'Far'),
    ]);

    final near = tester.getRect(find.text('Near'));
    final far = tester.getRect(find.text('Far'));
    expect(near.left, greaterThan(0.3 * 900));
    expect(far.right, lessThan(0.8 * 900));
    expect(far.right, greaterThan(0.8 * 900 - 20));
  });

  testWidgets('a right-to-left locale does not move the marks', (tester) async {
    final marks = [
      _mark(const Offset(0.3, 0.5), 'Near'),
      _mark(const Offset(0.8, 0.3), 'Far'),
    ];
    await _pump(tester, marks);
    final ltr = [
      tester.getRect(find.byKey(const ValueKey('chart-mark-0'))),
      tester.getRect(find.byKey(const ValueKey('chart-mark-1'))),
    ];

    await _pump(tester, marks, direction: TextDirection.rtl);

    expect(tester.getRect(find.byKey(const ValueKey('chart-mark-0'))), ltr[0]);
    expect(tester.getRect(find.byKey(const ValueKey('chart-mark-1'))), ltr[1]);
  });

  testWidgets('a long label wraps without overflow at 400 x 400', (
    tester,
  ) async {
    await _pump(tester, [
      _mark(const Offset(0.74, 0.5), 'A very long site name ' * 4),
      _mark(const Offset(0.3, 0.9), 'Another rather long site name ' * 3),
    ], size: const Size(400, 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the painter repaints off SceneTime', (tester) async {
    final time = ValueNotifier<double>(0);
    addTearDown(time.dispose);
    await _pump(tester, [_mark(const Offset(0.3, 0.5), 'Near')], time: time);

    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChartMarksPainter,
      ),
    );

    expect((paint.painter! as ChartMarksPainter).time, same(time));
  });
}
