import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_role_option.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('TankRoleOption', () {
    testWidgets('shows the role glyph before its localized name', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: const TankRoleOption(role: TankRole.pony),
        ),
      );

      final icon = find.byIcon(SubmersionIcons.tankPony);
      final label = find.text('Pony Bottle');
      expect(icon, findsOneWidget);
      expect(label, findsOneWidget);
      expect(tester.getTopLeft(icon).dx, lessThan(tester.getTopLeft(label).dx));
    });

    testWidgets('a long name ellipsizes instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 60,
              child: TankRoleOption(role: TankRole.sidemountRight),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // One line, cut with an ellipsis: wrapping would make the selected
      // field and every menu row taller on a narrow layout.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Sidemount Right'),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 15),
            )
            .map((box) => box.top)
            .toSet(),
        hasLength(1),
      );
    });
  });
}
