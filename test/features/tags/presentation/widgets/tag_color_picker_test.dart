import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_chip_colors.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';

/// The colour picker offers the colour a tag will actually display
/// (issue #2269).
///
/// It used to paint a solid 28 dp dot of the stored hex, which is not a
/// colour the diver ever sees on a tag: the chip is a pale tint of it. Every
/// swatch is now the chip itself, drawn by the same colour function, so
/// Settings and the rest of the app cannot disagree again.
void main() {
  final theme = ThemeData(
    colorScheme: const ColorScheme.light().copyWith(
      surface: Colors.white,
      onSurface: const Color(0xFF1C1B1F),
    ),
  );

  Widget harness({
    String? selectedColor,
    TextEditingController? nameController,
    void Function(String)? onColorSelected,
    TargetPlatform? platform,
  }) => MaterialApp(
    theme: platform == null ? theme : theme.copyWith(platform: platform),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: TagColorPicker(
            selectedColor: selectedColor,
            nameController: nameController,
            onColorSelected: onColorSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('offers one chip per palette colour', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.byType(TagChip), findsNWidgets(TagColors.predefined.length));
  });

  testWidgets('paints each swatch as the chip, not as the raw hex', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    final expected = tagChipColorsFor(
      seed: TagColors.fromHex(TagColors.predefined.first),
      surface: Colors.white,
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(TagChip).first,
            matching: find.byType(Material),
          )
          .first,
    );

    expect(material.color, expected.fill);
    expect(
      material.color,
      isNot(TagColors.fromHex(TagColors.predefined.first)),
      reason: 'a swatch showing the raw hex is the mismatch this fixes',
    );
  });

  testWidgets('shows the name being typed inside every swatch', (tester) async {
    final controller = TextEditingController(text: 'Shore');
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(nameController: controller));

    expect(
      find.text('Shore'),
      findsNWidgets(TagColors.predefined.length),
      reason: 'the swatch is a preview of this tag, not of a generic one',
    );
  });

  testWidgets('follows the name as it is typed', (tester) async {
    final controller = TextEditingController(text: 'Shore');
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(nameController: controller));
    controller.text = 'Night';
    await tester.pump();

    expect(find.text('Night'), findsNWidgets(TagColors.predefined.length));
    expect(find.text('Shore'), findsNothing);
  });

  testWidgets('still offers every colour when no name has been typed', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(nameController: controller));

    expect(find.byType(TagChip), findsNWidgets(TagColors.predefined.length));
  });

  testWidgets('reports the hex of the swatch that was tapped', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(onColorSelected: (hex) => picked = hex));

    await tester.tap(find.byType(TagChip).at(2));
    await tester.pumpAndSettle();

    expect(picked, TagColors.predefined[2]);
  });

  testWidgets('marks the chosen swatch as selected for assistive tech', (
    tester,
  ) async {
    final chosen = TagColors.predefined[3];
    await tester.pumpWidget(harness(selectedColor: chosen));

    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected == true);

    expect(semantics, hasLength(1));
  });

  group('a swatch is a reachable tap target', () {
    // The swatch is the control the diver taps to choose a colour, so it
    // answers to the same floor as the chip's own close button: 48 dp where
    // a finger points, 32 dp where a mouse does. The dots it replaced were
    // 28 dp and the dense chip on its own is 29, so neither the old grid nor
    // the new one cleared either floor until this was measured.
    for (final (platform, floor) in [
      (TargetPlatform.android, 48.0),
      (TargetPlatform.iOS, 48.0),
      (TargetPlatform.macOS, 32.0),
      (TargetPlatform.windows, 32.0),
      (TargetPlatform.linux, 32.0),
    ]) {
      testWidgets('$platform reaches $floor', (tester) async {
        await tester.pumpWidget(harness(platform: platform));

        final swatch = tester.getSize(find.byType(GestureDetector).first);

        expect(swatch.height, greaterThanOrEqualTo(floor));
        expect(swatch.width, greaterThanOrEqualTo(floor));
      });
    }
  });
}
