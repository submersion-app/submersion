import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_overline.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders uppercased label and actions; taps fire', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(
        FormOverline(
          label: 'Equipment',
          actions: [
            FormOverlineAction(label: 'Use set', onPressed: () => tapped++),
            FormOverlineAction(
              label: 'Add',
              icon: Icons.add,
              onPressed: () => tapped += 10,
            ),
          ],
        ),
      ),
    );
    expect(find.text('EQUIPMENT'), findsOneWidget);
    await tester.tap(find.text('Use set'));
    await tester.tap(find.text('Add'));
    expect(tapped, 11);
  });

  testWidgets('null onPressed renders a disabled action', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FormOverline(
          label: 'Weather',
          actions: [FormOverlineAction(label: 'Fetch', onPressed: null)],
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('trailingText renders before actions', (tester) async {
    await tester.pumpWidget(
      _wrap(const FormOverline(label: 'Weight', trailingText: '4.0 kg')),
    );
    expect(find.text('4.0 kg'), findsOneWidget);
  });

  testWidgets('busy action shows a progress indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FormOverline(
          label: 'Weather',
          actions: [
            FormOverlineAction(label: 'Fetch', onPressed: null, busy: true),
          ],
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
