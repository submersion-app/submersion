import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';

import '../../helpers/test_app.dart';

void main() {
  // Opens the dialog from a button and records what it returned.
  Future<void> openDialog(
    WidgetTester tester,
    String initialName,
    void Function(String?) onResult,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showPlanNameDialog(
                  context,
                  initialName: initialName,
                  title: 'Name your plan',
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the field with the initial name', (tester) async {
    await openDialog(tester, 'Blue Hole 40m - Jul 25', (_) {});

    expect(find.text('Name your plan'), findsOneWidget);
    expect(find.text('Blue Hole 40m - Jul 25'), findsOneWidget);
  });

  testWidgets('cancel returns null', (tester) async {
    String? result;
    var called = false;
    await openDialog(tester, 'Blue Hole', (value) {
      result = value;
      called = true;
    });

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('confirm returns the trimmed text', (tester) async {
    String? result;
    await openDialog(tester, 'Blue Hole', (value) => result = value);

    await tester.enterText(find.byType(TextField), '  Wreck of the Zenobia  ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Wreck of the Zenobia');
  });

  testWidgets('an all-whitespace field disables confirm', (tester) async {
    await openDialog(tester, 'Blue Hole', (_) {});

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('confirm is enabled again once text is restored', (tester) async {
    await openDialog(tester, 'Blue Hole', (_) {});

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(confirm.onPressed, isNotNull);
  });
}
