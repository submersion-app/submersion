import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../helpers/test_app.dart';

InfoContent _content(BuildContext context) =>
    const InfoContent(title: 'Results', summary: 'What the tiles show.');

void main() {
  testWidgets('HeaderInfoButton takes the height it is given', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: HeaderInfoButton(title: 'Results', content: _content),
        ),
      ),
    );

    final size = tester.getSize(find.byType(HeaderInfoButton));
    expect(size, const Size(48, 24));
  });

  testWidgets('HeaderInfoButton opens the sheet from its centre', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: HeaderInfoButton(title: 'Results', content: _content),
        ),
      ),
    );

    await tester.tap(find.byType(HeaderInfoButton));
    await tester.pumpAndSettle();
    expect(find.text('What the tiles show.'), findsOneWidget);
  });

  testWidgets('InfoCorner without info adds nothing', (tester) async {
    const tiles = SizedBox(key: Key('tiles'), width: 300, height: 120);
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: InfoCorner(title: 'Results', child: tiles),
        ),
      ),
    );

    expect(find.byType(InfoButton), findsNothing);
    expect(tester.getSize(find.byType(InfoCorner)), const Size(300, 120));
  });

  testWidgets('InfoCorner puts the icon in the top-right corner', (
    tester,
  ) async {
    const tiles = SizedBox(key: Key('tiles'), width: 300, height: 120);
    await tester.pumpWidget(
      testApp(
        child: const Center(
          child: InfoCorner(title: 'Results', info: _content, child: tiles),
        ),
      ),
    );

    final grid = tester.getRect(find.byKey(const Key('tiles')));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(tester.getSize(find.byType(InfoCorner)), const Size(300, 120));
    expect(icon.right, lessThanOrEqualTo(grid.right));
    expect(grid.right - icon.right, lessThan(24));
    expect(icon.top - grid.top, lessThan(16));
  });

  testWidgets('InfoCorner mirrors to the top-left in Arabic', (tester) async {
    const tiles = SizedBox(key: Key('tiles'), width: 300, height: 120);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('ar'),
        child: const Center(
          child: InfoCorner(title: 'Results', info: _content, child: tiles),
        ),
      ),
    );

    final grid = tester.getRect(find.byKey(const Key('tiles')));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(icon.left - grid.left, lessThan(24));
  });
}
