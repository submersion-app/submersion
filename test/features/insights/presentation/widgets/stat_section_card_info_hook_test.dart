import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/test_app.dart';

InfoContent _info(BuildContext context) =>
    const InfoContent(title: 'Gas consumption', summary: 'Gas use per dive.');

Widget _card({
  InfoContentBuilder? info,
  String title = 'Gas consumption',
  Widget? trailing,
  VoidCallback? onTap,
  double width = 400,
}) {
  return Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: StatSectionCard(
        title: title,
        trailing: trailing,
        onTap: onTap,
        info: info,
        child: const SizedBox(height: 40),
      ),
    ),
  );
}

void main() {
  testWidgets('no icon without info', (tester) async {
    await tester.pumpWidget(testApp(child: _card()));
    expect(find.byType(InfoButton), findsNothing);
  });

  testWidgets('icon sits at the far right of the title row', (tester) async {
    await tester.pumpWidget(testApp(child: _card(info: _info)));

    final card = tester.getRect(find.byType(Card));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    final title = tester.getRect(find.text('Gas consumption'));
    expect(card.right - icon.right, lessThan(40));
    expect(icon.left, greaterThan(title.right));
    expect(icon.center.dy, closeTo(title.center.dy, 4));
  });

  testWidgets('icon rides the label row when a trailing control is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: _card(
          info: _info,
          trailing: TextButton(onPressed: () {}, child: const Text('Mode')),
        ),
      ),
    );

    final title = tester.getRect(find.text('Gas consumption'));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(icon.center.dy, closeTo(title.center.dy, 4));
  });

  testWidgets('tapping the icon does not fire the card onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        child: _card(info: _info, onTap: () => taps++),
      ),
    );

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('Gas use per dive.'), findsOneWidget);
  });

  testWidgets('header height is unchanged by the icon', (tester) async {
    await tester.pumpWidget(testApp(child: _card()));
    final without = tester.getSize(find.byType(StatSectionHeader)).height;

    await tester.pumpWidget(testApp(child: _card(info: _info)));
    final with_ = tester.getSize(find.byType(StatSectionHeader)).height;
    expect(with_, without);
  });

  testWidgets('icon mirrors to the left in Arabic', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('ar'),
        child: _card(info: _info),
      ),
    );

    final title = tester.getRect(find.text('Gas consumption'));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(icon.right, lessThan(title.left));
  });

  testWidgets('a long title at 300 px keeps the icon and does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: _card(info: _info, width: 300, title: '${'A' * 30} ${'B' * 29}'),
      ),
    );

    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(Card));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(icon.right, lessThanOrEqualTo(card.right));
  });
}
