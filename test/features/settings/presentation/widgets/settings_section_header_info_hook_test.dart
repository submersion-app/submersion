import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/test_app.dart';

InfoContent _info(BuildContext context) => const InfoContent(
  title: 'Gradient Factors',
  summary: 'How conservative the schedule is.',
);

Widget _header({InfoContentBuilder? info}) => testApp(
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 360,
      child: Builder(
        builder: (context) => KeyedSubtree(
          key: const Key('header'),
          child: buildSettingsSectionHeader(
            context,
            'Gradient Factors',
            info: info,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('no icon without info', (tester) async {
    await tester.pumpWidget(_header());
    expect(find.byType(InfoButton), findsNothing);
  });

  testWidgets('icon sits at the far right', (tester) async {
    await tester.pumpWidget(_header(info: _info));
    final header = tester.getRect(find.byKey(const Key('header')));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    expect(header.right - icon.right, lessThan(24));
  });

  testWidgets('header height is unchanged by the icon', (tester) async {
    await tester.pumpWidget(_header());
    final without = tester.getSize(find.byKey(const Key('header'))).height;
    await tester.pumpWidget(_header(info: _info));
    expect(tester.getSize(find.byKey(const Key('header'))).height, without);
  });

  testWidgets('tapping the icon opens the sheet', (tester) async {
    await tester.pumpWidget(_header(info: _info));
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.text('How conservative the schedule is.'), findsOneWidget);
  });
}
