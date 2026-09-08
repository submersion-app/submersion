import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_import_page_size_dialog.dart';

import '../../../../helpers/test_app.dart';

/// Records what the dialog popped so a test can assert on it after settling.
class _DialogResult {
  int? value;
  bool closed = false;
}

void main() {
  group('CloudImportPageSizeDialog', () {
    /// Pumps a button, taps it to open the dialog, and returns the recorder
    /// the dialog's result lands in.
    Future<_DialogResult> openDialog(
      WidgetTester tester, {
      int initial = 15,
    }) async {
      final result = _DialogResult();

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result.value = await showDialog<int>(
                  context: context,
                  builder: (_) =>
                      CloudImportPageSizeDialog(initialValue: initial),
                );
                result.closed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      return result;
    }

    /// Settles the pending pop and returns the value the dialog handed back.
    Future<int?> closedWith(WidgetTester tester, _DialogResult result) async {
      await tester.pumpAndSettle();
      expect(result.closed, isTrue, reason: 'dialog never closed');
      return result.value;
    }

    testWidgets('seeds the field with the current page size', (tester) async {
      await openDialog(tester, initial: 42);

      expect(find.widgetWithText(TextField, '42'), findsOneWidget);
    });

    testWidgets('labels the field and states the accepted range', (
      tester,
    ) async {
      await openDialog(tester);

      expect(find.text('Dives per page'), findsOneWidget);
      expect(
        find.text(
          'Between ${CloudImportPaging.minPageSize} and '
          '${CloudImportPaging.maxPageSize}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('save pops the entered value', (tester) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '30');
      await tester.tap(find.text('Save'));

      expect(await closedWith(tester, result), 30);
    });

    testWidgets('save clamps a value above the maximum', (tester) async {
      final result = await openDialog(tester);

      await tester.enterText(
        find.byType(TextField),
        '${CloudImportPaging.maxPageSize + 5}',
      );
      await tester.tap(find.text('Save'));

      expect(await closedWith(tester, result), CloudImportPaging.maxPageSize);
    });

    testWidgets('submitting the field saves without tapping Save', (
      tester,
    ) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '7');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(await closedWith(tester, result), 7);
    });

    testWidgets('save on an empty field pops nothing', (tester) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));

      expect(await closedWith(tester, result), isNull);
    });

    testWidgets('cancel pops nothing', (tester) async {
      final result = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '30');
      await tester.tap(find.text('Cancel'));

      expect(await closedWith(tester, result), isNull);
    });
  });
}
