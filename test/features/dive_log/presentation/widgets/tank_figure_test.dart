import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

TankFigure _figure({
  double? start = 200,
  double? end = 60,
  double rated = 232,
  double? volume = 11.1,
  String? usedLabel = 'Used 140 bar',
}) {
  return TankFigure(
    levels: TankFillLevels.resolve(start: start, end: end, rated: rated),
    gasColor: Colors.green,
    volumeLiters: volume,
    startLabel: 'Start ${start?.round() ?? '--'}${start == null ? '' : ' bar'}',
    endLabel: 'End ${end?.round() ?? '--'}${end == null ? '' : ' bar'}',
    usedLabel: usedLabel,
  );
}

void main() {
  testWidgets('shows the three labels', (tester) async {
    await tester.pumpWidget(_host(_figure()));

    expect(find.text('Start 200 bar'), findsOneWidget);
    expect(find.text('End 60 bar'), findsOneWidget);
    expect(find.text('Used 140 bar'), findsOneWidget);
  });

  testWidgets('no used label when none is given', (tester) async {
    await tester.pumpWidget(
      _host(_figure(start: 100, end: 150, usedLabel: null)),
    );

    expect(find.textContaining('Used'), findsNothing);
    expect(find.text('Start 100 bar'), findsOneWidget);
    expect(find.text('End 150 bar'), findsOneWidget);
  });

  testWidgets('reads the values as one node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_figure()));

    expect(
      tester.getSemantics(find.byType(TankFigure)),
      matchesSemantics(label: 'Start 200 bar, End 60 bar, Used 140 bar'),
    );
    handle.dispose();
  });

  testWidgets('a barely used tank keeps its labels apart', (tester) async {
    await tester.pumpWidget(
      _host(_figure(start: 200, end: 195, usedLabel: 'Used 5 bar')),
    );

    final rects = [
      tester.getRect(find.text('Start 200 bar')),
      tester.getRect(find.text('Used 5 bar')),
      tester.getRect(find.text('End 195 bar')),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'label $i overlaps label $j',
        );
      }
    }
    // Start sits above Used, which sits above End.
    expect(rects[0].top, lessThan(rects[1].top));
    expect(rects[1].top, lessThan(rects[2].top));
  });

  testWidgets('a barely used tank fits at a large text scale', (tester) async {
    await tester.pumpWidget(
      _host(
        _figure(start: 200, end: 195, volume: 3, usedLabel: 'Used 5 bar'),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    final figure = tester.getRect(find.byType(TankFigure));
    for (final label in ['Start 200 bar', 'Used 5 bar', 'End 195 bar']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(figure.top - 0.01));
      expect(rect.bottom, lessThanOrEqualTo(figure.bottom + 0.01));
    }
  });

  testWidgets('a bigger tank is drawn taller', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: const Key('small'), child: _figure(volume: 5)),
            KeyedSubtree(key: const Key('big'), child: _figure(volume: 18)),
          ],
        ),
      ),
    );

    final small = tester.getSize(find.byKey(const Key('small')));
    final big = tester.getSize(find.byKey(const Key('big')));
    expect(big.height, greaterThan(small.height));
  });
}
