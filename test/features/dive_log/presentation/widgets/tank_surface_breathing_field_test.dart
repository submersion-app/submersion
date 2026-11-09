import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_surface_breathing_field.dart';

import '../../../../helpers/test_app.dart';

/// The cylinder's "Breathed at the surface" minutes (issue #2930).
void main() {
  Future<List<Duration?>> pump(WidgetTester tester, Duration? value) async {
    final reported = <Duration?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TankSurfaceBreathingField(value: value, onChanged: reported.add),
      ),
    );
    return reported;
  }

  testWidgets('shows the label, unit and what the time is for', (tester) async {
    await pump(tester, null);
    expect(find.text('Breathed at the surface'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
    expect(
      find.textContaining('after the computer stopped logging'),
      findsOneWidget,
    );
  });

  testWidgets('shows entered minutes', (tester) async {
    await pump(tester, const Duration(minutes: 12));
    expect(find.widgetWithText(TextField, '12'), findsOneWidget);
  });

  testWidgets('reports typed minutes as a duration', (tester) async {
    final reported = await pump(tester, null);
    await tester.enterText(find.byType(TextField), '1.5');
    expect(reported.last, const Duration(seconds: 90));
  });

  testWidgets('a cleared or zero field reports none', (tester) async {
    final reported = await pump(tester, const Duration(minutes: 10));
    await tester.enterText(find.byType(TextField), '');
    expect(reported.last, isNull);
    await tester.enterText(find.byType(TextField), '0');
    expect(reported.last, isNull);
  });

  testWidgets('follows a new value from its host', (tester) async {
    await pump(tester, const Duration(minutes: 5));
    await pump(tester, const Duration(minutes: 8));
    expect(find.widgetWithText(TextField, '8'), findsOneWidget);
  });
}
