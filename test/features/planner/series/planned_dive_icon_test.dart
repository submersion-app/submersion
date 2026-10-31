import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/planned_dive_icon.dart';

/// The planned-dive diver (issue #3565): the main menu's diver glyph, filled
/// white and outlined in the given colour.
void main() {
  Future<void> pump(WidgetTester tester, Widget icon) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: icon)),
    ),
  );

  List<Text> glyphs(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(PlannedDiveIcon),
          matching: find.byType(Text),
        ),
      )
      .toList();

  testWidgets('paints the diver glyph white, then its outline on top', (
    tester,
  ) async {
    await pump(tester, const PlannedDiveIcon(color: Colors.indigo));

    final [fill, outline] = glyphs(tester);
    final glyph = String.fromCharCode(Icons.scuba_diving.codePoint);
    expect(fill.data, glyph);
    expect(outline.data, glyph);
    expect(fill.style!.fontFamily, Icons.scuba_diving.fontFamily);
    expect(fill.style!.color, Colors.white);
    expect(outline.style!.foreground!.style, PaintingStyle.stroke);
    expect(
      outline.style!.foreground!.color.toARGB32(),
      Colors.indigo.toARGB32(),
    );
  });

  testWidgets('sizes to the icon theme and defaults to the primary colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        home: const Scaffold(
          body: Center(
            child: IconTheme(
              data: IconThemeData(size: 18),
              child: PlannedDiveIcon(),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PlannedDiveIcon)), const Size(18, 18));
    final context = tester.element(find.byType(PlannedDiveIcon));
    final [_, outline] = glyphs(tester);
    expect(
      outline.style!.foreground!.color.toARGB32(),
      Theme.of(context).colorScheme.primary.toARGB32(),
    );
  });

  testWidgets('is decorative: no semantics of its own', (tester) async {
    await pump(tester, const PlannedDiveIcon());
    expect(
      find.descendant(
        of: find.byType(PlannedDiveIcon),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });
}
