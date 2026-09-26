import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('returns the trimmed name, refuses an empty one', (tester) async {
    String? result;
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSaveQueryDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  Deep ones ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Deep ones');
  });

  testWidgets('dismissing returns null', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSaveQueryDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
