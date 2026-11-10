import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import '../../../../helpers/test_app.dart';

InfoContent _info(BuildContext context) =>
    const InfoContent(title: 'Deco Status', summary: 'Model state.');

typedef _Build =
    Widget Function({
      required bool expanded,
      required ValueChanged<bool> onToggle,
      InfoContentBuilder? info,
      String title,
    });

Widget _section({
  required bool expanded,
  required ValueChanged<bool> onToggle,
  InfoContentBuilder? info,
  String title = 'Deco Status',
}) => CollapsibleSection(
  title: title,
  icon: Icons.timer,
  isExpanded: expanded,
  onToggle: onToggle,
  info: info,
  child: const SizedBox(height: 40),
);

Widget _cardSection({
  required bool expanded,
  required ValueChanged<bool> onToggle,
  InfoContentBuilder? info,
  String title = 'Deco Status',
}) => CollapsibleCardSection(
  title: title,
  icon: Icons.timer,
  isExpanded: expanded,
  onToggle: onToggle,
  info: info,
  contentBuilder: (_) => const SizedBox(height: 40),
);

Widget _host(Widget child, {double width = 400}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, child: child),
);

void _hookTests(String name, _Build build) {
  group(name, () {
    testWidgets('no icon without info', (tester) async {
      await tester.pumpWidget(
        testApp(child: _host(build(expanded: true, onToggle: (_) {}))),
      );
      expect(find.byType(InfoButton), findsNothing);
    });

    testWidgets('icon sits immediately left of the arrow', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: _host(build(expanded: true, onToggle: (_) {}, info: _info)),
        ),
      );

      final icon = tester.getRect(find.byIcon(Icons.info_outline));
      final arrow = tester.getRect(find.byIcon(Icons.expand_more));
      expect(icon.right, lessThanOrEqualTo(arrow.left + 12));
      expect(arrow.left - icon.right, lessThan(24));
    });

    testWidgets('tapping the icon does not toggle the section', (tester) async {
      final toggles = <bool>[];
      await tester.pumpWidget(
        testApp(
          child: _host(
            build(expanded: true, onToggle: toggles.add, info: _info),
          ),
        ),
      );

      await tester.tap(find.byType(InfoButton));
      await tester.pumpAndSettle();
      expect(toggles, isEmpty);
      expect(find.text('Model state.'), findsOneWidget);
    });

    testWidgets('header height is unchanged by the icon', (tester) async {
      await tester.pumpWidget(
        testApp(child: _host(build(expanded: false, onToggle: (_) {}))),
      );
      final without = tester.getSize(find.byType(InkWell).first).height;

      await tester.pumpWidget(
        testApp(
          child: _host(build(expanded: false, onToggle: (_) {}, info: _info)),
        ),
      );
      final with_ = tester.getSize(find.byType(InkWell).first).height;
      expect(with_, without);
    });

    testWidgets('icon stays beside the arrow in Arabic', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          child: _host(build(expanded: true, onToggle: (_) {}, info: _info)),
        ),
      );

      final icon = tester.getRect(find.byIcon(Icons.info_outline));
      final arrow = tester.getRect(find.byIcon(Icons.expand_more));
      expect(icon.left, greaterThanOrEqualTo(arrow.right - 12));
      expect(icon.left - arrow.right, lessThan(24));
    });

    testWidgets('a long title at 300 px does not overflow', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: _host(
            build(
              expanded: true,
              onToggle: (_) {},
              info: _info,
              title: '${'A' * 30} ${'B' * 29}',
            ),
            width: 300,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(InfoButton), findsOneWidget);
    });
  });
}

void main() {
  _hookTests('CollapsibleSection', _section);
  _hookTests('CollapsibleCardSection', _cardSection);
}
