import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../../helpers/mock_providers.dart';

/// The entry and exit rows of the header editor: a date, then a time, with
/// the minute on show standing for the stored instant (issue #4527, plan 4).
void main() {
  final stored = DateTime.utc(2026, 3, 9, 10, 34, 51);

  Future<List<DateTime>> pumpRow(
    WidgetTester tester, {
    DateTime? value,
    DateTime? hint,
    DateTime? stored,
    DateTime? first,
    DateTime? last,
  }) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveTimeRow(
              label: 'Exit',
              value: value,
              hint: hint,
              stored: stored,
              onPicked: picked.add,
              firstDate: first ?? DateTime(2026, 3, 9),
              lastDate: last ?? DateTime(2026, 3, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  Future<void> openRow(WidgetTester tester) async {
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('the stored minute picked again keeps the stored instant', (
    tester,
  ) async {
    final picked = await pumpRow(tester, value: stored);

    await openRow(tester);
    await confirm(tester); // the date
    await confirm(tester); // the time

    expect(picked, [stored]);
  });

  testWidgets('a date with the time cancelled keeps the old time on the new '
      'date', (tester) async {
    final picked = await pumpRow(tester, value: stored);

    await openRow(tester);
    await tester.tap(find.text('10'));
    await confirm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [DateTime.utc(2026, 3, 10, 10, 34, 51)]);
  });

  testWidgets('the date cancelled changes nothing', (tester) async {
    final picked = await pumpRow(tester, value: stored);

    await openRow(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a dive with no exit shows the estimate, and it is picked '
      'exactly', (tester) async {
    final picked = await pumpRow(tester, hint: stored);

    await openRow(tester);
    await confirm(tester);
    await confirm(tester);

    expect(picked, [stored]);
  });

  // Final review, Important 1: a picker shows minutes, so a time moved and
  // moved back must find the stored seconds again.
  testWidgets('a date moved back to the stored one keeps the stored instant', (
    tester,
  ) async {
    final moved = DateTime.utc(2026, 3, 10, 10, 34, 51);
    final picked = await pumpRow(tester, value: moved, stored: stored);

    await openRow(tester);
    await tester.tap(find.text('9'));
    await confirm(tester);
    await confirm(tester);

    expect(picked, [stored]);
  });

  testWidgets('a date alone moved keeps the time\'s seconds', (tester) async {
    final picked = await pumpRow(tester, value: stored);

    await openRow(tester);
    await tester.tap(find.text('10'));
    await confirm(tester);
    await confirm(tester);

    expect(picked, [DateTime.utc(2026, 3, 10, 10, 34, 51)]);
  });

  // Final review, minor 5: a cancel is not a pick.
  testWidgets('with only an estimate, a cancelled time stores nothing', (
    tester,
  ) async {
    final picked = await pumpRow(tester, hint: stored);

    await openRow(tester);
    await confirm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
  });

  testWidgets('the date picker is given the row\'s range', (tester) async {
    await pumpRow(
      tester,
      value: stored,
      first: DateTime(2026, 3, 8),
      last: DateTime(2026, 3, 10),
    );

    await openRow(tester);

    final dialog = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(dialog.firstDate, DateTime(2026, 3, 8));
    expect(dialog.lastDate, DateTime(2026, 3, 10));
  });
}
