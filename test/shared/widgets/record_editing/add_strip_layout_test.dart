import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip_layout.dart';

const _tags = AddStripEntry(cardId: 'tags', label: 'Tags');

/// A page of numbered rows under the strip, 600 px high, so the body
/// scrolls.
Widget _host(
  List<AddStripEntry> entries,
  ScrollController scroll, {
  int rows = 40,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: AddStripLayout(
          strip: AddStrip(entries: entries, onAdd: (_) {}),
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                for (var row = 0; row < rows; row++)
                  SizedBox(height: 50, child: Text('Row $row')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// An unlocked page gains the strip and a locked one loses it. The page
/// under it must not move when it does: the diver is looking at it.
void main() {
  late ScrollController scroll;

  setUp(() => scroll = ScrollController());
  tearDown(() => scroll.dispose());

  double rowTop(WidgetTester tester, int row) =>
      tester.getTopLeft(find.text('Row $row')).dy;

  testWidgets('the strip arriving does not move the page', (tester) async {
    await tester.pumpWidget(_host(const [], scroll));
    scroll.jumpTo(300);
    await tester.pump();
    final before = rowTop(tester, 10);

    await tester.pumpWidget(_host(const [_tags], scroll));

    expect(find.text('Tags'), findsOneWidget);
    expect(rowTop(tester, 10), before);
  });

  testWidgets('the strip leaving does not move the page', (tester) async {
    await tester.pumpWidget(_host(const [_tags], scroll));
    scroll.jumpTo(300);
    await tester.pump();
    final before = rowTop(tester, 10);

    await tester.pumpWidget(_host(const [], scroll));

    expect(find.text('Tags'), findsNothing);
    expect(rowTop(tester, 10), before);
  });

  // At the top the strip lies over the first rows rather than push them
  // down. They are a scroll away.
  testWidgets('at the top, the page stays and its first rows can be '
      'scrolled to', (tester) async {
    await tester.pumpWidget(_host(const [], scroll));
    final before = rowTop(tester, 3);

    await tester.pumpWidget(_host(const [_tags], scroll));
    await tester.pumpAndSettle();
    expect(rowTop(tester, 3), before);

    scroll.jumpTo(0);
    await tester.pump();
    final strip = tester.getBottomLeft(find.byType(AddStrip)).dy;
    expect(rowTop(tester, 0), strip);
  });

  // It cannot scroll above the top: what was under the strip comes back
  // into view, and nothing is left blank.
  testWidgets('leaving near the top, the page settles at the top', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const [_tags], scroll));
    scroll.jumpTo(10);
    await tester.pump();

    await tester.pumpWidget(_host(const [], scroll));
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(rowTop(tester, 0), tester.getTopLeft(find.byType(Scaffold)).dy);
  });

  // A page that fits has nothing to scroll: the strip pushes it down, as it
  // must, or its top would be hidden under the strip with no way to it.
  testWidgets('a page that fits is pushed down, not scrolled and sprung '
      'back', (tester) async {
    await tester.pumpWidget(_host(const [], scroll, rows: 4));
    final before = rowTop(tester, 0);

    await tester.pumpWidget(_host(const [_tags], scroll, rows: 4));

    expect(scroll.offset, 0);
    expect(tester.hasRunningAnimations, isFalse);
    final strip = tester.getBottomLeft(find.byType(AddStrip)).dy;
    expect(rowTop(tester, 0), strip);
    expect(strip, greaterThan(before));
  });
}
