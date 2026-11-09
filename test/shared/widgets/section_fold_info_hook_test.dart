import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

import '../../helpers/test_app.dart';

InfoContent _info(BuildContext context) =>
    const InfoContent(title: 'Tissue Loading', summary: 'Compartment load.');

Widget _fold({
  InfoContentBuilder? info,
  ValueChanged<bool>? onToggle,
  Locale? locale,
  double width = 400,
}) => testApp(
  locale: locale,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: SectionFold(
        title: 'Tissue Loading',
        icon: Icons.grid_on,
        isExpanded: false,
        onToggle: onToggle ?? (_) {},
        info: info,
        contentBuilder: (_) => const SizedBox(height: 40),
      ),
    ),
  ),
);

void main() {
  testWidgets('no icon without info', (tester) async {
    await tester.pumpWidget(_fold());
    expect(find.byType(InfoButton), findsNothing);
  });

  testWidgets('icon sits immediately left of the arrow', (tester) async {
    await tester.pumpWidget(_fold(info: _info));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    final arrow = tester.getRect(find.byIcon(Icons.expand_more));
    expect(icon.right, lessThanOrEqualTo(arrow.left + 12));
    expect(arrow.left - icon.right, lessThan(24));
  });

  testWidgets('tapping the icon does not unfold the section', (tester) async {
    final toggles = <bool>[];
    await tester.pumpWidget(_fold(info: _info, onToggle: toggles.add));
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(toggles, isEmpty);
    expect(find.text('Compartment load.'), findsOneWidget);
  });

  testWidgets('header height is unchanged by the icon', (tester) async {
    await tester.pumpWidget(_fold());
    final without = tester.getSize(find.byType(InkWell)).height;
    await tester.pumpWidget(_fold(info: _info));
    expect(tester.getSize(find.byType(InkWell).first).height, without);
  });

  testWidgets('icon stays beside the arrow in Arabic', (tester) async {
    await tester.pumpWidget(_fold(info: _info, locale: const Locale('ar')));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    final arrow = tester.getRect(find.byIcon(Icons.expand_more));
    expect(icon.left, greaterThanOrEqualTo(arrow.right - 12));
  });
}
