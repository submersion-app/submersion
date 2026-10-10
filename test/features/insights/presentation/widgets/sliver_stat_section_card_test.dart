import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverStatSectionCard(
                title: 'Dives',
                sliver: SliverList.builder(
                  itemCount: 500,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('row $i')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ShapeDecoration decorationOf(WidgetTester tester) =>
      tester.widget<DecoratedSliver>(find.byType(DecoratedSliver)).decoration
          as ShapeDecoration;

  testWidgets('shows the title and builds its sliver body lazily', (
    tester,
  ) async {
    await pump(tester, ThemeData());
    expect(find.text('Dives'), findsOneWidget);
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 499', skipOffstage: false), findsNothing);
  });

  testWidgets('paints with the card theme, like the box cards', (tester) async {
    const shape = RoundedRectangleBorder(side: BorderSide(color: Colors.teal));
    await pump(
      tester,
      ThemeData(
        cardTheme: const CardThemeData(
          color: Colors.amber,
          shape: shape,
          elevation: 5,
          shadowColor: Colors.red,
          margin: EdgeInsets.all(9),
        ),
      ),
    );
    final decoration = decorationOf(tester);
    expect(decoration.color, Colors.amber);
    expect(decoration.shape, shape);
    // Elevation 5 has no Material shadow of its own; it takes 4's layers,
    // in the theme's shadow colour.
    expect(decoration.shadows, hasLength(kElevationToShadow[4]!.length));
    for (final s in decoration.shadows!) {
      expect(s.color.r, Colors.red.r);
    }
    final padding = tester.widget<SliverPadding>(
      find.byType(SliverPadding).first,
    );
    expect(padding.padding, const EdgeInsets.all(9));
  });

  testWidgets('falls back to the Material 3 card defaults', (tester) async {
    final theme = ThemeData();
    await pump(tester, theme);
    final decoration = decorationOf(tester);
    expect(decoration.color, theme.colorScheme.surfaceContainerLow);
    expect(decoration.shadows, hasLength(kElevationToShadow[1]!.length));
  });

  testWidgets('a flat card theme draws no shadow', (tester) async {
    await pump(tester, ThemeData(cardTheme: const CardThemeData(elevation: 0)));
    expect(decorationOf(tester).shadows, isEmpty);
  });
}
