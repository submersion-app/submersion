import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_list_card.dart';

void main() {
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.dark,
  );
  final light = ColorScheme.fromSeed(seedColor: const Color(0xFF0077B6));

  group('RecordCardColors', () {
    test('light text and cyan accent on a dark fill', () {
      final colors = RecordCardColors.forFill(dark, const Color(0xFF1A1A2E));
      expect(colors.primaryText, Colors.white);
      expect(colors.secondaryText, Colors.white70);
      expect(colors.accent, Colors.cyan.shade200);
    });

    test('dark text and teal accent on a light fill', () {
      final colors = RecordCardColors.forFill(dark, Colors.white);
      expect(colors.primaryText, Colors.black87);
      expect(colors.secondaryText, Colors.black54);
      expect(colors.accent, Colors.teal.shade800);
    });

    test('no fill reads the theme card as surfaceContainerHighest', () {
      expect(
        RecordCardColors.forFill(dark, null).primaryText,
        RecordCardColors.forFill(
          dark,
          dark.surfaceContainerHighest,
        ).primaryText,
      );
      expect(RecordCardColors.forFill(dark, null).primaryText, Colors.white);
      expect(RecordCardColors.forFill(light, null).primaryText, Colors.black87);
    });
  });

  test('the selection fill is primaryContainer at half opacity', () {
    expect(
      recordCardSelectionFill(dark),
      dark.primaryContainer.withValues(alpha: 0.5),
    );
  });

  group('RecordListCard', () {
    Future<void> pump(
      WidgetTester tester,
      Widget card, {
      CardThemeData? cardTheme,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(cardTheme: cardTheme),
        home: Scaffold(body: card),
      ),
    );

    testWidgets('keeps the theme card colour unless given one', (tester) async {
      await pump(tester, const RecordListCard(child: Text('row')));
      expect(tester.widget<Card>(find.byType(Card)).color, isNull);

      await pump(
        tester,
        const RecordListCard(color: Colors.amber, child: Text('row')),
      );
      expect(tester.widget<Card>(find.byType(Card)).color, Colors.amber);
    });

    testWidgets('the ink follows the theme card shape', (tester) async {
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      );
      await pump(
        tester,
        const RecordListCard(child: Text('row')),
        cardTheme: CardThemeData(shape: shape),
      );
      expect(tester.widget<InkWell>(find.byType(InkWell)).customBorder, shape);
    });

    testWidgets('falls back to 12 px corners without a theme shape', (
      tester,
    ) async {
      await pump(tester, const RecordListCard(child: Text('row')));
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).customBorder,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    });

    testWidgets('sits 16 px in and 4 px apart by default', (tester) async {
      await pump(tester, const RecordListCard(child: Text('row')));
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.byType(Card), matching: find.byType(Container))
            .first,
      );
      expect(
        container.margin,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
    });

    testWidgets('a tap reaches onTap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        RecordListCard(
          onTap: () => taps++,
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      await tester.tap(find.byType(RecordListCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a double tap reaches onDoubleTap', (tester) async {
      var doubleTaps = 0;
      await pump(
        tester,
        RecordListCard(
          onDoubleTap: () => doubleTaps++,
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      await tester.tap(find.byType(RecordListCard));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(RecordListCard));
      await tester.pumpAndSettle();
      expect(doubleTaps, 1);
    });

    testWidgets('announces itself as a button with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        RecordListCard(
          semanticsLabel: 'Dive 40 at Blue Hole',
          onTap: () {},
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      expect(find.bySemanticsLabel('Dive 40 at Blue Hole'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dive 40 at Blue Hole')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
