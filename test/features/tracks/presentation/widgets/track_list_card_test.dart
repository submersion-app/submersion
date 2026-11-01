import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_list_card.dart';
import 'package:submersion/shared/widgets/record_list_card.dart';

/// A track entry looks and reacts like a dive entry (issue #4024): the
/// shared card, its highlight fill, and the dive card's text colours.
void main() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.dark,
  );

  Future<RecordCardColors?> pump(
    WidgetTester tester, {
    required bool selected,
    VoidCallback? onTap,
  }) async {
    RecordCardColors? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Scaffold(
          body: TrackListCard(
            selected: selected,
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
    final colors = await pump(tester, selected: false);
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
    final colors = await pump(tester, selected: true);
    final fill = recordCardSelectionFill(scheme);
    final expected = RecordCardColors.forFill(scheme, fill);

    expect(cardColor(tester), fill);
    expect(textColor(tester, 'Wreck dive'), expected.primaryText);
    expect(colors?.accent, expected.accent);
  });

  testWidgets('the card takes the tap, not the tile inside it', (tester) async {
    var taps = 0;
    await pump(tester, selected: false, onTap: () => taps++);

    await tester.tap(find.text('Wreck dive'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });
}
