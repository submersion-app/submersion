import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/features/tags/presentation/widgets/custom_tag_color_dialog.dart';
import 'package:submersion/features/tags/presentation/widgets/hsv_color_controls.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';

import '../../../../helpers/test_app.dart';

/// The dialog the picker's "+" dot opens (issue #4384).
void main() {
  final hexField = find.byKey(const ValueKey('tag-color-hex'));
  final use = find.byKey(const ValueKey('tag-color-use'));

  /// Opens the dialog on [initial] and returns a holder for its result.
  Future<List<String?>> open(WidgetTester tester, Color initial) async {
    final results = <String?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showCustomTagColorDialog(
                context,
                initial: initial,
                name: 'Night dive',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(hexField).controller!.text;

  bool useEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(use).onPressed != null;

  testWidgets('opens on the colour it was given, ready to use', (tester) async {
    final results = await open(tester, const Color(0xFFFF0000));
    expect(fieldText(tester), '#FF0000');
    expect(useEnabled(tester), isTrue);
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(results, ['#FF0000']);
  });

  testWidgets('takes a typed code in any casing, and previews it', (
    tester,
  ) async {
    final results = await open(tester, const Color(0xFFFF0000));
    await tester.enterText(hexField, '2e8b57');
    await tester.pump();
    final chip = tester.widget<TagChip>(find.byType(TagChip));
    expect(chip.color, const Color(0xFF2E8B57));
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(results, ['#2E8B57']);
  });

  testWidgets('a code that is not six digits disables Use and says why', (
    tester,
  ) async {
    await open(tester, const Color(0xFFFF0000));
    await tester.enterText(hexField, '#2E8B5');
    await tester.pump();
    expect(useEnabled(tester), isFalse);
    expect(find.text('Enter six digits 0-9 or A-F, like #2E8B57'), findsOne);
  });

  testWidgets('the square writes its colour into the code field', (
    tester,
  ) async {
    await open(tester, const Color(0xFF2E8B57));
    final square = tester.getRect(find.byType(SaturationValueSquare));
    await tester.tapAt(square.topRight + const Offset(-0.5, 0.5));
    await tester.pump();
    final shown = tester.widget<SaturationValueSquare>(
      find.byType(SaturationValueSquare),
    );
    expect(shown.color.saturation, closeTo(1, 0.01));
    expect(shown.color.value, closeTo(1, 0.01));
    expect(fieldText(tester), tagHexOf(shown.color.toColor()));
  });

  testWidgets('a vertical drag on the square wins over a scrolling dialog', (
    tester,
  ) async {
    // Short enough that the dialog scrolls, as it does with the keyboard up.
    tester.view.physicalSize = const Size(360, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, const Color(0xFF2E8B57));
    final square = find.byType(SaturationValueSquare);
    final box = tester.getRect(square);
    // Pressing at the centre reports brightness 0.5; dragging a quarter of
    // the square's height down must carry on to about 0.25.
    await tester.dragFrom(box.center, Offset(0, box.height / 4));
    await tester.pump();
    final after = tester.widget<SaturationValueSquare>(square).color.value;
    expect(after, closeTo(0.25, 0.05));
  });

  testWidgets('typing a grey keeps the hue where it was', (tester) async {
    await open(tester, const Color(0xFF2E8B57));
    await tester.enterText(hexField, '#808080');
    await tester.pump();
    final slider = tester.widget<HueSlider>(find.byType(HueSlider));
    expect(slider.color.hue, closeTo(146, 1));
    expect(slider.color.saturation, 0);
  });

  testWidgets('Cancel gives nothing back', (tester) async {
    final results = await open(tester, const Color(0xFFFF0000));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });
}
