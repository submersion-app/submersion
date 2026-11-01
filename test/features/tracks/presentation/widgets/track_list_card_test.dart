import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_list_card.dart';
import 'package:submersion/shared/widgets/record_list_card.dart';

/// A track entry looks and reacts like a dive entry (#4101): the shared
/// card, its highlight fill, and the dive card's text colours.
void main() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.dark,
  );

  Future<RecordCardColors?> pump(
    WidgetTester tester, {
    required bool highlighted,
    bool picked = false,
    VoidCallback? onTap,
  }) async {
    RecordCardColors? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Scaffold(
          body: TrackListCard(
            highlighted: highlighted,
            picked: picked,
            onTap: onTap ?? () {},
            builder: (context, colors) {
              received = colors;
              return const ListTile(
                title: Text('Wreck dive'),
                subtitle: Text('r1.csv'),
              );
            },
          ),
        ),
      ),
    );
    return received;
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

  Color? cardColor(WidgetTester tester) =>
      tester.widget<Card>(find.byType(Card)).color;

  testWidgets('at rest the entry keeps the theme card colour', (tester) async {
    final colors = await pump(tester, highlighted: false);
    final expected = RecordCardColors.forFill(scheme, null);

    expect(find.byType(RecordListCard), findsOneWidget);
    expect(cardColor(tester), isNull);
    expect(textColor(tester, 'Wreck dive'), expected.primaryText);
    expect(textColor(tester, 'r1.csv'), expected.secondaryText);
    expect(colors?.accent, expected.accent);
  });

  testWidgets('a highlighted entry takes the dive list selection fill', (
    tester,
  ) async {
    final colors = await pump(tester, highlighted: true);
    final fill = recordCardSelectionFill(scheme);
    final expected = RecordCardColors.forFill(scheme, fill);

    expect(cardColor(tester), fill);
    expect(textColor(tester, 'Wreck dive'), expected.primaryText);
    expect(colors?.accent, expected.accent);
  });

  testWidgets('the tile inside takes the dive card inner padding', (
    tester,
  ) async {
    await pump(tester, highlighted: false);
    final tile = tester.getRect(find.byType(ListTile));
    final title = tester.getRect(find.text('Wreck dive'));
    expect(title.left - tile.left, 12);
  });

  testWidgets('the card takes the tap, not the tile inside it', (tester) async {
    var taps = 0;
    await pump(tester, highlighted: false, onTap: () => taps++);

    await tester.tap(find.text('Wreck dive'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });

  group('selected state for assistive technology', () {
    Future<SemanticsNode> cardSemantics(
      WidgetTester tester, {
      required bool highlighted,
      required bool picked,
    }) async {
      await pump(tester, highlighted: highlighted, picked: picked);
      return tester.getSemantics(
        find.descendant(
          of: find.byType(RecordListCard),
          matching: find.byType(InkWell),
        ),
      );
    }

    testWidgets('the live pick is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      final node = await cardSemantics(tester, highlighted: true, picked: true);
      expect(node, isSemantics(isSelected: true));
      handle.dispose();
    });

    testWidgets('the entry merely last opened is filled but not selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final node = await cardSemantics(
        tester,
        highlighted: true,
        picked: false,
      );
      expect(node, isSemantics(isSelected: false));
      handle.dispose();
    });
  });
}
