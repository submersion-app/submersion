import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_logo_field.dart';

import '../../../../helpers/test_app.dart';

/// The edit page's logo control (#4460).
void main() {
  testWidgets('the logo can be reached and opened from the keyboard', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DiveCenterLogoField(logo: null, onTap: () => taps++),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a tap opens it too', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DiveCenterLogoField(logo: null, onTap: () => taps++),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Logo'));
    expect(taps, 1);
  });
}
