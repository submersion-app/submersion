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

  group('crowded headers (issue #2652)', () {
    List<FormOverlineAction> four(List<String> taps) => [
      for (final (label, icon) in [
        ('Use set', Icons.folder_special),
        ('Add', Icons.add),
        ('Scan', Icons.qr_code_scanner),
        ('Sort', Icons.sort),
      ])
        FormOverlineAction(
          label: label,
          icon: icon,
          onPressed: () => taps.add(label),
        ),
    ];

    testWidgets('show icons with tooltips when labels do not fit', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: FormOverline(label: 'Equipment', actions: four(taps)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Use set', 'Add', 'Scan', 'Sort']) {
        expect(find.text(label), findsNothing, reason: label);
        expect(find.byTooltip(label), findsOneWidget, reason: label);
        expect(
          tester.getRect(find.byTooltip(label)).right,
          lessThanOrEqualTo(300),
        );
        await tester.tap(find.byTooltip(label));
      }
      expect(taps, ['Use set', 'Add', 'Scan', 'Sort']);
      expect(find.text('EQUIPMENT'), findsOneWidget);
    });

    testWidgets('keep their labels when there is room', (tester) async {
      await tester.pumpWidget(
        _wrap(FormOverline(label: 'Equipment', actions: four([]))),
      );
      for (final label in ['Use set', 'Add', 'Scan', 'Sort']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('an action without an icon keeps its label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: FormOverline(
                label: 'Equipment',
                actions: [
                  ...four([]),
                  FormOverlineAction(label: 'Go', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
    });
  });
}
