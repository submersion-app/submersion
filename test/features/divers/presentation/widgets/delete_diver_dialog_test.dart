import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/presentation/widgets/delete_diver_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DeleteDiverDialog', () {
    testWidgets('renders title, body, and text field', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
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

      // Cancel and Delete buttons exist.
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('delete button is disabled initially', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('delete button stays disabled for incorrect text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Type incorrect text (wrong case).
      await tester.enterText(find.byType(TextField), 'delete alice');
      await tester.pump();

      final deleteButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('delete button becomes enabled when exact text is typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
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
      await tester.enterText(find.byType(TextField), 'Delete Alice');
      await tester.pump();

      final deleteButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(deleteButton.onPressed, isNotNull);
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
                  dialogResult = await DeleteDiverDialog.show(
                    context,
                    diverName: 'Alice',
                  );
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

    testWidgets('confirming returns true when correct text is typed', (
      tester,
    ) async {
      bool? dialogResult;

      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await DeleteDiverDialog.show(
                    context,
                    diverName: 'Alice',
                  );
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

      // Type the confirmation text and tap Delete.
      await tester.enterText(find.byType(TextField), 'Delete Alice');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('delete button disables again when text is cleared', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
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
      await tester.enterText(find.byType(TextField), 'Delete Alice');
      await tester.pump();

      var deleteButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(deleteButton.onPressed, isNotNull);

      // Clear the text.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      deleteButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('trims whitespace when checking confirmation text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Whitespace around "Delete Alice" should still work.
      await tester.enterText(find.byType(TextField), '  Delete Alice  ');
      await tester.pump();

      final deleteButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(deleteButton.onPressed, isNotNull);
    });

    testWidgets('body text mentions permanent deletion', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    DeleteDiverDialog.show(context, diverName: 'Alice'),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Body text should mention permanent deletion and the diver name.
      expect(find.textContaining('permanently delete'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
    });
  });
}
