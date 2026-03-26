import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/reset_database_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('ResetDatabaseDialog', () {
    testWidgets('renders title, body, and text field', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Title includes warning icon and text.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Body text and text field are present.
      expect(find.byType(TextField), findsOneWidget);

      // Cancel and Reset buttons exist.
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('reset button is disabled initially', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final resetButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(resetButton.onPressed, isNull);
    });

    testWidgets('reset button stays disabled for incorrect text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Type incorrect text.
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      final resetButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(resetButton.onPressed, isNull);
    });

    testWidgets('reset button becomes enabled when "Delete" is typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Type the exact confirmation text.
      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      final resetButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(resetButton.onPressed, isNotNull);
    });

    testWidgets('cancel button closes dialog and returns false', (
      tester,
    ) async {
      bool? dialogResult;

      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await ResetDatabaseDialog.show(context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Cancel.
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets('confirming returns true when Delete is typed', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await ResetDatabaseDialog.show(context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Type the confirmation text and tap Reset.
      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('reset button disables again when text is cleared', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enable the button.
      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      var resetButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(resetButton.onPressed, isNotNull);

      // Clear the text.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      resetButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(resetButton.onPressed, isNull);
    });

    testWidgets('trims whitespace when checking confirmation text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ResetDatabaseDialog.show(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Whitespace around "Delete" should still work.
      await tester.enterText(find.byType(TextField), '  Delete  ');
      await tester.pump();

      final resetButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(resetButton.onPressed, isNotNull);
    });
  });
}
