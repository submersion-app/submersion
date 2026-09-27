import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_page.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('an unreadable shift keeps the sheet open instead of applying '
      'no shift (#1900)', (tester) async {
    Intl.defaultLocale = 'en_US';
    final results = <({Duration offset, bool importWide})?>[];
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => results.add(
                await showTimeShiftSheet(
                  context,
                  suggestedOffset: Duration.zero,
                  offerImportWide: false,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2.5');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(results, isEmpty);
  });
}
