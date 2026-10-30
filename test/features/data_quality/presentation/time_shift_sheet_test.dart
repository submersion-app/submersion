import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/data_quality/presentation/widgets/time_shift_sheet.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<List<({Duration offset, bool widen})?>> pumpSheet(
    WidgetTester tester, {
    Duration suggestedOffset = Duration.zero,
    String? widenLabel,
  }) async {
    Intl.defaultLocale = 'en_US';
    final results = <({Duration offset, bool widen})?>[];
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => results.add(
                await showTimeShiftSheet(
                  context,
                  suggestedOffset: suggestedOffset,
                  widenLabel: widenLabel,
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
    return results;
  }

  testWidgets('an unreadable shift keeps the sheet open instead of applying '
      'no shift (#1900)', (tester) async {
    final results = await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), '2.5');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a blank field applies no shift', (tester) async {
    final results = await pumpSheet(
      tester,
      suggestedOffset: const Duration(hours: 2),
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(results.single, (offset: Duration.zero, widen: false));
  });

  testWidgets('no widen label, no checkbox', (tester) async {
    await pumpSheet(tester, suggestedOffset: const Duration(hours: -1));
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('the widen checkbox carries its label and its answer', (
    tester,
  ) async {
    final results = await pumpSheet(
      tester,
      suggestedOffset: const Duration(hours: -1),
      widenLabel: 'Every dive',
    );

    expect(find.text('Every dive'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(results.single, (offset: const Duration(hours: -1), widen: true));
  });
}
