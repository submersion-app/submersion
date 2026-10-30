import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/enum_multi_picker_row.dart';

enum Flavor { mild, medium, spicy }

String flavorName(Flavor f) => switch (f) {
  Flavor.mild => 'Mild',
  Flavor.medium => 'Medium',
  Flavor.spicy => 'Spicy',
};

/// Holds the selection the way a form does, so each toggle re-renders the
/// row with the value it reported.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.reports});

  final List<Flavor> initial;
  final List<List<Flavor>> reports;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<Flavor> _value = widget.initial;

  @override
  Widget build(BuildContext context) => EnumMultiPickerRow<Flavor>(
    label: 'Flavor',
    value: _value,
    values: Flavor.values,
    displayName: flavorName,
    placeholder: 'Not specified',
    onChanged: (v) {
      widget.reports.add(v);
      setState(() => _value = v);
    },
  );
}

Future<List<List<Flavor>>> _pump(
  WidgetTester tester, {
  List<Flavor> initial = const [],
}) async {
  final reports = <List<Flavor>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Material(
          child: _Host(initial: initial, reports: reports),
        ),
      ),
    ),
  );
  return reports;
}

void main() {
  testWidgets('an empty selection shows the placeholder', (tester) async {
    await _pump(tester);
    expect(find.text('Not specified'), findsOneWidget);
  });

  testWidgets('a selection shows the names joined in order', (tester) async {
    await _pump(tester, initial: const [Flavor.mild, Flavor.spicy]);
    expect(find.text('Mild, Spicy'), findsOneWidget);
  });

  testWidgets('ticking reports the selection in declaration order', (
    tester,
  ) async {
    final reports = await _pump(tester);
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Spicy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mild'));
    await tester.pumpAndSettle();

    expect(reports, [
      [Flavor.spicy],
      [Flavor.mild, Flavor.spicy],
    ]);
  });

  testWidgets('the sheet shows the current selection ticked', (tester) async {
    await _pump(tester, initial: const [Flavor.medium]);
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();

    final medium = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Medium'),
    );
    final mild = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Mild'),
    );
    expect(medium.value, isTrue);
    expect(mild.value, isFalse);
  });

  testWidgets('unticking the last item reports an empty selection', (
    tester,
  ) async {
    final reports = await _pump(tester, initial: const [Flavor.medium]);
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Medium'));
    await tester.pumpAndSettle();

    expect(reports, [<Flavor>[]]);
  });
}
