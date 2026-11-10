import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/presentation/widgets/hsv_color_controls.dart';

import '../../../../helpers/test_app.dart';

/// The custom colour dialog's two controls (issue #4384).
void main() {
  const start = HSVColor.fromAHSV(1, 120, 0.5, 0.5);

  Future<List<HSVColor>> pumpControl(
    WidgetTester tester,
    Widget Function(ValueChanged<HSVColor> onChanged) build,
  ) async {
    final reported = <HSVColor>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Center(
          child: SizedBox(width: 200, height: 100, child: build(reported.add)),
        ),
      ),
    );
    return reported;
  }

  group('SaturationValueSquare', () {
    Future<List<HSVColor>> pumpSquare(WidgetTester tester) => pumpControl(
      tester,
      (onChanged) => SaturationValueSquare(color: start, onChanged: onChanged),
    );

    testWidgets('top right is full saturation and full brightness', (
      tester,
    ) async {
      final reported = await pumpSquare(tester);
      final box = tester.getRect(find.byType(SaturationValueSquare));
      await tester.tapAt(box.topRight + const Offset(-0.5, 0.5));
      expect(reported.last.saturation, closeTo(1, 0.01));
      expect(reported.last.value, closeTo(1, 0.01));
      expect(reported.last.hue, 120);
    });

    testWidgets('bottom left is no saturation and no brightness', (
      tester,
    ) async {
      final reported = await pumpSquare(tester);
      final box = tester.getRect(find.byType(SaturationValueSquare));
      await tester.tapAt(box.bottomLeft + const Offset(0.5, -0.5));
      expect(reported.last.saturation, closeTo(0, 0.01));
      expect(reported.last.value, closeTo(0, 0.01));
    });

    testWidgets('a drag past the edge reports clamped values', (tester) async {
      final reported = await pumpSquare(tester);
      final box = tester.getRect(find.byType(SaturationValueSquare));
      await tester.dragFrom(box.center, const Offset(400, -400));
      expect(reported.last.saturation, 1);
      expect(reported.last.value, 1);
    });

    testWidgets('is announced by name', (tester) async {
      await pumpSquare(tester);
      expect(find.bySemanticsLabel('Saturation and brightness'), findsOne);
    });
  });

  group('HueSlider', () {
    Future<List<HSVColor>> pumpSlider(WidgetTester tester) => pumpControl(
      tester,
      (onChanged) => HueSlider(color: start, onChanged: onChanged),
    );

    testWidgets('the middle is hue 180, keeping saturation and brightness', (
      tester,
    ) async {
      final reported = await pumpSlider(tester);
      await tester.tapAt(tester.getCenter(find.byType(HueSlider)));
      expect(reported.last.hue, closeTo(180, 1));
      expect(reported.last.saturation, 0.5);
      expect(reported.last.value, 0.5);
    });

    testWidgets('a drag past the end reports hue 360 at most', (tester) async {
      final reported = await pumpSlider(tester);
      final box = tester.getRect(find.byType(HueSlider));
      await tester.dragFrom(box.center, const Offset(400, 0));
      expect(reported.last.hue, 360);
    });

    testWidgets('is announced by name', (tester) async {
      await pumpSlider(tester);
      expect(find.bySemanticsLabel('Hue'), findsOne);
    });
  });
}
