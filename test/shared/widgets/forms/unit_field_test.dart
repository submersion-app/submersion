import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/unit_field.dart';

void main() {
  testWidgets('renders label, unit suffix, accepts numeric text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitField(
            controller: controller,
            label: 'Start pressure',
            unitSymbol: 'bar',
          ),
        ),
      ),
    );
    expect(find.text('Start pressure'), findsOneWidget);
    expect(find.text('bar'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '200');
    expect(controller.text, '200');
  });

  testWidgets('runs validator inside a Form', (tester) async {
    final controller = TextEditingController(text: '');
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: UnitField(
              controller: controller,
              label: 'Volume',
              unitSymbol: 'L',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      ),
    );
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('strips non-numeric characters from pasted/typed input', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitField(
            controller: controller,
            label: 'Volume',
            unitSymbol: 'L',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'abc11.1xyz');
    expect(controller.text, '11.1');
  });

  testWidgets('rejects the decimal separator when allowDecimal is false', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitField(
            controller: controller,
            label: 'Pressure',
            unitSymbol: 'bar',
            allowDecimal: false,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '20.0');
    expect(controller.text, '200');
  });
}
