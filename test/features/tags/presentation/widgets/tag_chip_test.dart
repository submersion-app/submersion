import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_color_contrast.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';

/// TagChip paints a tag in the colour the diver chose (issue #2254).
///
/// The chips used to fill with `tag.color.withValues(alpha: 0.15)`, which is
/// not a colour but a recipe: the result depended on the surface behind the
/// chip, so one tag read as four different colours across the app and changed
/// again when its row was selected. These tests pin the fill to the stored
/// colour, opaque, whatever sits behind it.
void main() {
  final amber = Tag(
    id: 'shore',
    name: 'Shore',
    colorHex: '#F59E0B',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Widget harness(Widget child, {Color? surface}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ColoredBox(
          color: surface ?? Colors.white,
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      ),
    ),
  );

  /// The colour [TagChip] fills itself with.
  Color fillOf(WidgetTester tester) {
    final material = tester.widget<Material>(
      find
          .descendant(of: find.byType(TagChip), matching: find.byType(Material))
          .first,
    );
    return material.color!;
  }

  testWidgets('fills with the exact stored colour, fully opaque', (
    tester,
  ) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    expect(fillOf(tester), const Color(0xFFF59E0B));
    expect(fillOf(tester).a, 1.0);
  });

  testWidgets('shows the same colour whatever surface is behind it', (
    tester,
  ) async {
    // The second is the blue-grey of a selected dive row. Composited under
    // the old 15% tint the chip came out F2E8D7 on one and C4C2B7 on the
    // other, so one tag read as two colours.
    for (final surface in [Colors.white, const Color(0xFFBBC8D6)]) {
      await tester.pumpWidget(harness(TagChip(tag: amber), surface: surface));

      expect(
        Color.alphaBlend(fillOf(tester), surface),
        const Color(0xFFF59E0B),
        reason: 'on $surface',
      );
    }
  });

  testWidgets('labels the chip with the contrasting colour', (tester) async {
    await tester.pumpWidget(harness(TagChip(tag: amber)));

    final label = tester.widget<Text>(find.text('Shore'));
    expect(label.style?.color, tagForegroundColor(amber.color));
  });

  testWidgets('a colourless tag still fills opaquely', (tester) async {
    final plain = amber.copyWith(colorHex: '');

    await tester.pumpWidget(harness(TagChip(tag: plain)));

    expect(fillOf(tester), plain.color);
    expect(fillOf(tester).a, 1.0);
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
    for (final (platform, floor) in [
      (TargetPlatform.android, 48.0),
      (TargetPlatform.iOS, 48.0),
      (TargetPlatform.macOS, 32.0),
      (TargetPlatform.windows, 32.0),
      (TargetPlatform.linux, 32.0),
    ]) {
      testWidgets('$platform reaches $floor', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: TagChip(tag: amber, onDeleted: () {}),
              ),
            ),
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
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Center(
              child: TagChip(tag: amber, onDeleted: () {}),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(TagChip)).height, 32.0);
    });
  });

  testWidgets('the dense variant keeps the same fill', (tester) async {
    await tester.pumpWidget(harness(TagChip(tag: amber, dense: true)));

    expect(fillOf(tester), const Color(0xFFF59E0B));
  });
}
