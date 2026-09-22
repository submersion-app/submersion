import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_chip_colors.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';

/// TagChip paints a tag as a pale tint of the diver's colour (issue #2269).
///
/// #2255 filled the chip with the stored colour at full strength to make the
/// app agree with Settings. The agreement is wanted; the flooded chip is not.
/// The chip is quiet again, and the tint is resolved against the theme's own
/// surface and painted opaque, so a tag is still one colour everywhere
/// instead of the four that the translucent fill produced.
void main() {
  final amber = Tag(
    id: 'shore',
    name: 'Shore',
    colorHex: '#F59E0B',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const amberSeed = Color(0xFFF59E0B);

  final theme = ThemeData(
    colorScheme: const ColorScheme.light().copyWith(
      surface: Colors.white,
      onSurface: const Color(0xFF1C1B1F),
    ),
  );

  Widget harness(Widget child, {Color? surface, ThemeData? withTheme}) =>
      MaterialApp(
        theme: withTheme ?? theme,
        home: Scaffold(
          body: Center(
            child: ColoredBox(
              color: surface ?? Colors.white,
              child: Padding(padding: const EdgeInsets.all(8), child: child),
            ),
          ),
        ),
      );

  Material materialOf(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(of: find.byType(TagChip), matching: find.byType(Material))
        .first,
  );

  Color fillOf(WidgetTester tester) => materialOf(tester).color!;

  BorderSide borderOf(WidgetTester tester) =>
      (materialOf(tester).shape! as RoundedRectangleBorder).side;

  testWidgets('fills with a pale tint, not the stored colour', (tester) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    final expected = tagChipColorsFor(seed: amberSeed, surface: Colors.white);

    expect(fillOf(tester), expected.fill);
    expect(fillOf(tester), isNot(amberSeed));
  });

  testWidgets('fills opaquely', (tester) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    expect(fillOf(tester).a, 1.0);
  });

  testWidgets('shows the same colour whatever surface is behind it', (
    tester,
  ) async {
    // The second is the blue-grey of a selected dive row. Under the old
    // translucent tint the chip came out F2E8D7 on one and C4C2B7 on the
    // other, so one tag read as two colours. The tint is resolved from the
    // theme now, so what sits behind the chip cannot reach it.
    final fills = <Color>[];
    for (final surface in [Colors.white, const Color(0xFFBBC8D6)]) {
      await tester.pumpWidget(harness(TagChip(tag: amber), surface: surface));
      fills.add(fillOf(tester));
    }

    expect(fills.first, fills.last);
  });

  testWidgets('outlines the chip in the stored colour at full strength', (
    tester,
  ) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    expect(borderOf(tester).color, amberSeed);
  });

  testWidgets('labels the chip in the tag hue, darkened to stay readable', (
    tester,
  ) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    final label = tester.widget<Text>(find.text('Shore'));
    final expected = tagChipColorsFor(seed: amberSeed, surface: Colors.white);

    expect(label.style?.color, expected.label);
    expect(label.style?.color, isNot(Colors.black));
    expect(label.style?.color, isNot(Colors.white));
  });

  testWidgets('a colourless tag still fills opaquely', (tester) async {
    final plain = amber.copyWith(colorHex: '');

    await tester.pumpWidget(harness(TagChip(tag: plain)));

    expect(fillOf(tester).a, 1.0);
    expect(borderOf(tester).color, plain.color);
  });

  testWidgets('reports a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(TagChip(tag: amber, onTap: () => taps++)));

    await tester.tap(find.byType(TagChip));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('reports a delete', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(
      harness(TagChip(tag: amber, onDeleted: () => deletes++)),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(deletes, 1);
  });

  group('the delete control keeps a reachable tap target', () {
    // A 16px icon with only a splash radius left a 16x16 target, well under
    // either platform's floor. Measured per platform, because a chip is not
    // allowed to shrink the target the way VisualDensity.compact once did.
    // The colour of the chip has nothing to do with this floor, so the fix
    // that introduced it outlives the fill that came with it.
    for (final (platform, floor) in [
      (TargetPlatform.android, 48.0),
      (TargetPlatform.iOS, 48.0),
      (TargetPlatform.macOS, 32.0),
      (TargetPlatform.windows, 32.0),
      (TargetPlatform.linux, 32.0),
    ]) {
      testWidgets('$platform reaches $floor', (tester) async {
        await tester.pumpWidget(
          harness(
            TagChip(tag: amber, onDeleted: () {}),
            withTheme: theme.copyWith(platform: platform),
          ),
        );

        final target = tester.getSize(
          find.ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(IconButton),
          ),
        );

        expect(target.width, greaterThanOrEqualTo(floor));
        expect(target.height, greaterThanOrEqualTo(floor));
      });
    }

    testWidgets('and the whole chip stays no taller than that target', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          TagChip(tag: amber, onDeleted: () {}),
          withTheme: theme.copyWith(platform: TargetPlatform.macOS),
        ),
      );

      expect(tester.getSize(find.byType(TagChip)).height, 32.0);
    });
  });

  testWidgets('the dense variant keeps the same fill and border', (
    tester,
  ) async {
    // One tint across the app, not the 0.15 of a list row and the 0.2 of a
    // card: two tints would give a tag two display colours again, and the
    // Settings swatch could only tell the truth about one of them.
    await tester.pumpWidget(harness(TagChip(tag: amber)));
    final normalFill = fillOf(tester);

    await tester.pumpWidget(harness(TagChip(tag: amber, dense: true)));

    expect(fillOf(tester), normalFill);
    expect(borderOf(tester).color, amberSeed);
  });
}
