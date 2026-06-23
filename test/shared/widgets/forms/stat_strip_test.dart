import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatCell display', () {
    testWidgets('shows value, unit and label', (tester) async {
      final controller = TextEditingController(text: '28.4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          StatStrip(
            cells: [
              StatCell(label: 'Max depth', unit: 'm', controller: controller),
            ],
          ),
        ),
      );
      expect(find.text('28.4'), findsOneWidget);
      expect(find.text(' m'), findsOneWidget);
      expect(find.text('MAX DEPTH'), findsOneWidget);
    });

    testWidgets('empty controller shows placeholder dash', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          StatStrip(
            cells: [
              StatCell(label: 'Avg depth', unit: 'm', controller: controller),
            ],
          ),
        ),
      );
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('display-only cell renders displayValue', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatStrip(
            cells: [StatCell(label: 'Mix', displayValue: 'EAN32')],
          ),
        ),
      );
      expect(find.text('EAN32'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('StatCell editing', () {
    testWidgets('tap swaps to text field, commit updates display', (
      tester,
    ) async {
      final controller = TextEditingController(text: '28.4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          StatStrip(
            cells: [
              StatCell(label: 'Max depth', unit: 'm', controller: controller),
            ],
          ),
        ),
      );
      await tester.tap(find.text('28.4'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '30.1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.text, '30.1');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('30.1'), findsOneWidget);
    });

    testWidgets('display-only cell does not enter edit mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatStrip(
            cells: [StatCell(label: 'Mix', displayValue: 'EAN32')],
          ),
        ),
      );
      await tester.tap(find.text('EAN32'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('decimal cell strips colon/comma/letters, keeps . and -', (
      tester,
    ) async {
      final controller = TextEditingController(text: '5');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          StatStrip(
            cells: [
              StatCell(label: 'Water temp', unit: 'C', controller: controller),
            ],
          ),
        ),
      );
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '-2a8.5,:');
      expect(controller.text, '-28.5');
    });

    testWidgets('integer cell rejects the decimal point (digits only)', (
      tester,
    ) async {
      final controller = TextEditingController(text: '40');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          StatStrip(
            cells: [
              StatCell(
                label: 'Bottom time',
                unit: 'min',
                controller: controller,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('40'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '30.5');
      expect(controller.text, '305');
    });
  });
}
