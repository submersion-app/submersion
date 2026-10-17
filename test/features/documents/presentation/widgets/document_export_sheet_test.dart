import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/presentation/widgets/document_export_sheet.dart';

import '../../../../helpers/test_app.dart';

void main() {
  late String? result;
  late bool closed;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    closed = false;
    result = null;
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDocumentExportSheet(
                context,
                documentCount: 3,
                fileCount: 5,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder exportButton() => find.widgetWithText(FilledButton, 'Export');
  bool enabled(WidgetTester t) =>
      t.widget<FilledButton>(exportButton()).onPressed != null;

  Future<void> type(WidgetTester t, String password, String confirm) async {
    await t.enterText(field('Password'), password);
    await t.enterText(field('Confirm password'), confirm);
    await t.pumpAndSettle();
  }

  testWidgets('shows the counts and the honest note', (t) async {
    await open(t);
    expect(find.text('Documents: 3, files: 5'), findsOneWidget);
    expect(find.textContaining('cannot be recovered'), findsOneWidget);
    expect(find.textContaining('not strong encryption'), findsOneWidget);
    expect(enabled(t), isFalse);
  });

  testWidgets('a short password is refused', (t) async {
    await open(t);
    await type(t, 'short', 'short');
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(enabled(t), isFalse);
  });

  testWidgets('letters outside plain ASCII are refused', (t) async {
    await open(t);
    await type(t, 'pässwörd1', 'pässwörd1');
    expect(find.textContaining('Use only letters A to Z'), findsOneWidget);
    expect(enabled(t), isFalse);
  });

  testWidgets('an untouched confirm field shows no error', (t) async {
    await open(t);
    await t.enterText(field('Password'), 'correct horse');
    await t.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsNothing);
  });

  testWidgets('the two passwords must match', (t) async {
    await open(t);
    await type(t, 'correct horse', 'correct house');
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(enabled(t), isFalse);
  });

  testWidgets('a valid password is returned', (t) async {
    await open(t);
    await type(t, 'correct horse', 'correct horse');
    expect(enabled(t), isTrue);
    await t.tap(exportButton());
    await t.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, 'correct horse');
  });

  testWidgets('Enter in the confirm field exports', (t) async {
    await open(t);
    await type(t, 'correct horse', 'correct horse');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(result, 'correct horse');
  });

  testWidgets('Enter does nothing while the password is refused', (t) async {
    await open(t);
    await type(t, 'short', 'short');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(closed, isFalse);
  });

  testWidgets('the password is hidden until shown', (t) async {
    await open(t);
    EditableText input() => t.widget<EditableText>(
      find.descendant(
        of: field('Password'),
        matching: find.byType(EditableText),
      ),
    );
    expect(input().obscureText, isTrue);
    await t.tap(find.byTooltip('Show password'));
    await t.pumpAndSettle();
    expect(input().obscureText, isFalse);
  });

  testWidgets('dismissing returns null', (t) async {
    await open(t);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
