import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';

enum Flavor { mild, medium, spicy }

String flavorName(Flavor f) => switch (f) {
  Flavor.mild => 'Mild',
  Flavor.medium => 'Medium',
  Flavor.spicy => 'Spicy',
};

Widget _harness({
  required Flavor? value,
  required ValueChanged<Flavor?> onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: Material(
      child: EnumPickerRow<Flavor>(
        label: 'Flavor',
        value: value,
        values: Flavor.values,
        displayName: flavorName,
        onChanged: onChanged,
        placeholder: 'Not specified',
      ),
    ),
  ),
);

void main() {
  testWidgets('shows value; tap opens sheet; selection fires onChanged', (
    tester,
  ) async {
    Flavor? changed;
    await tester.pumpWidget(
      _harness(value: Flavor.mild, onChanged: (v) => changed = v),
    );
    expect(find.text('Mild'), findsOneWidget);
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spicy'));
    await tester.pumpAndSettle();
    expect(changed, Flavor.spicy);
  });

  testWidgets('clear option fires onChanged(null)', (tester) async {
    Flavor? changed = Flavor.mild;
    await tester.pumpWidget(
      _harness(value: Flavor.mild, onChanged: (v) => changed = v),
    );
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not specified').last);
    await tester.pumpAndSettle();
    expect(changed, isNull);
  });

  // A hint says what applies while nothing is picked (a dive with no entry
  // method of its own shows its site's). It is not a choice, so it must not
  // name the option that clears the value.
  testWidgets('a hint shows in the resting row and not as the clear option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: EnumPickerRow<Flavor>(
              label: 'Flavor',
              value: null,
              values: Flavor.values,
              displayName: flavorName,
              onChanged: (_) {},
              placeholder: 'Not specified',
              hint: 'Mild',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Mild'), findsOneWidget);
    expect(find.text('Not specified'), findsNothing);

    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Not specified'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Mild'), findsOneWidget);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _harness(value: Flavor.mild, onChanged: (_) => calls++),
    );
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
