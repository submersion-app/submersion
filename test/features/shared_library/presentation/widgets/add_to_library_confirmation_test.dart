import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/shared_library/presentation/widgets/add_to_library_confirmation.dart';

import '../../../../helpers/test_app.dart';

Future<bool?> _ask(
  WidgetTester tester, {
  required int siteCount,
  String? siteName,
  required String tapLabel,
}) async {
  bool? answer;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await confirmAddToLibrary(
            context,
            libraryName: 'Reef Survey',
            siteCount: siteCount,
            siteName: siteName,
          ),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tapLabel));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('lists what is shared and what stays private', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await confirmAddToLibrary(
              context,
              libraryName: 'Reef Survey',
              siteCount: 1,
              siteName: 'Blue Hole',
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Add Blue Hole to Reef Survey?'), findsOneWidget);
    expect(find.textContaining('Every member will see'), findsOneWidget);
    expect(find.textContaining('your notes and rating'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('several sites are counted, and Cancel says no', (tester) async {
    final answer = await _ask(tester, siteCount: 3, tapLabel: 'Cancel');
    expect(answer, isFalse);
  });

  testWidgets('the title counts several sites', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAddToLibrary(
              context,
              libraryName: 'Reef Survey',
              siteCount: 3,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Add 3 sites to Reef Survey?'), findsOneWidget);
  });
}
