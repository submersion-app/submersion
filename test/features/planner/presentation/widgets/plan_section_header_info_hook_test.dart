import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/test_app.dart';

InfoContent _info(BuildContext context) =>
    const InfoContent(title: 'Gas', summary: 'Gas use per cylinder.');

Widget _header({InfoContentBuilder? info}) => testApp(
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 360, child: PlanSectionHeader('Gas', info: info)),
  ),
);

void main() {
  testWidgets('no icon without info', (tester) async {
    await tester.pumpWidget(_header());
    expect(find.byType(InfoButton), findsNothing);
  });

  testWidgets('icon sits at the far right', (tester) async {
    await tester.pumpWidget(_header(info: _info));
    final header = tester.getRect(find.byType(PlanSectionHeader));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(header.right - icon.right, lessThan(24));
  });

  testWidgets('header height is unchanged by the icon', (tester) async {
    await tester.pumpWidget(_header());
    final without = tester.getSize(find.byType(PlanSectionHeader)).height;
    await tester.pumpWidget(_header(info: _info));
    expect(tester.getSize(find.byType(PlanSectionHeader)).height, without);
  });
}
