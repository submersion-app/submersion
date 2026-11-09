import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_labels.dart';

void main() {
  RhythmLabelSpec spec(RhythmLabelKind kind, double at, double width) =>
      (kind: kind, centerFraction: at, width: width);

  group('placeRhythmLabels', () {
    test('centres labels and clamps them inside the bar', () {
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.tick, 0, 30),
        spec(RhythmLabelKind.sunrise, 0.5, 40),
        spec(RhythmLabelKind.tick, 1, 30),
      ], 300);
      expect(placed.map((p) => p.left), [0, 130, 270]);
    });

    test('drops the midday tick when a sun label covers it', () {
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.sunrise, 0.45, 60),
        spec(RhythmLabelKind.tick, 0.5, 30),
      ], 300);
      expect(placed.map((p) => p.spec.kind), [RhythmLabelKind.sunrise]);
    });

    test('moves the sunset clear of the sunrise', () {
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.sunrise, 0.40, 60),
        spec(RhythmLabelKind.sunset, 0.45, 60),
      ], 300);
      expect(placed.map((p) => p.left), [90, 154]);
    });

    test('moves a sunset that lies before the sunrise to the left', () {
      // A sunset past midnight comes before the day's sunrise.
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.sunset, 0.45, 60),
        spec(RhythmLabelKind.sunrise, 0.5, 60),
      ], 300);
      expect(placed.map((p) => p.spec.kind), [
        RhythmLabelKind.sunset,
        RhythmLabelKind.sunrise,
      ]);
      expect(placed.map((p) => p.left), [56, 120]);
    });

    test('drops a label wider than the bar', () {
      // Large text on a narrow bar: the label cannot fit anywhere, so it is
      // dropped rather than drawn past the bar's end.
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.sunrise, 0.25, 120),
        spec(RhythmLabelKind.tick, 0.5, 40),
      ], 100);
      expect(placed.map((p) => p.spec.kind), [RhythmLabelKind.tick]);
    });

    test('drops the sunset when there is no room', () {
      final placed = placeRhythmLabels([
        spec(RhythmLabelKind.sunrise, 0.9, 60),
        spec(RhythmLabelKind.sunset, 0.95, 60),
      ], 300);
      expect(placed.map((p) => p.spec.kind), [RhythmLabelKind.sunrise]);
    });
  });

  group('DayRhythmLabelRow', () {
    Widget host(Widget child, {double textScale = 1, double width = 500}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        );

    const labels = [
      (kind: RhythmLabelKind.sunrise, centerFraction: 0.26, text: '6:12 AM'),
      (kind: RhythmLabelKind.tick, centerFraction: 0.5, text: '12:00 PM'),
      (kind: RhythmLabelKind.sunset, centerFraction: 0.78, text: '6:47 PM'),
    ];

    testWidgets("shows each label's text", (tester) async {
      await tester.pumpWidget(host(const DayRhythmLabelRow(labels: labels)));
      expect(find.text('6:12 AM'), findsOneWidget);
      expect(find.text('12:00 PM'), findsOneWidget);
      expect(find.text('6:47 PM'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(2));
    });

    testWidgets('lays out at a large text scale', (tester) async {
      await tester.pumpWidget(
        host(const DayRhythmLabelRow(labels: labels), textScale: 3, width: 200),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
