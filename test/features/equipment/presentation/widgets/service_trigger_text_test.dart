import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<String> format(
    WidgetTester tester, {
    required DateTime now,
    AppSettings settings = const AppSettings(),
    DateTime? dueDate,
    int? divesSinceAnchor,
    int? divesRemaining,
    double? hoursSinceAnchor,
    double? hoursRemaining,
  }) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = formatServiceTriggerText(
              context,
              units: UnitFormatter(settings),
              now: now,
              dueDate: dueDate,
              divesSinceAnchor: divesSinceAnchor,
              divesRemaining: divesRemaining,
              hoursSinceAnchor: hoursSinceAnchor,
              hoursRemaining: hoursRemaining,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('overdue date trigger reads "Overdue since"', (tester) async {
    final text = await format(
      tester,
      now: DateTime(2026, 7, 16),
      dueDate: DateTime(2026, 1, 1),
    );
    expect(text, contains('Overdue since'));
  });

  // #1512: the due date came from MaterialLocalizations.formatShortDate, which
  // follows the UI locale rather than the diver's date preference.
  testWidgets('the due date follows the diver date format', (tester) async {
    final text = await format(
      tester,
      settings: const AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
      now: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 6, 15),
    );
    expect(text, contains('15/06/2026'));
  });

  testWidgets('future date trigger reads "Due"', (tester) async {
    final text = await format(
      tester,
      now: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 7, 16),
    );
    expect(text, contains('Due'));
    expect(text, isNot(contains('Overdue')));
  });

  testWidgets('exact due instant reads "Due", not "Overdue"', (tester) async {
    final due = DateTime(2026, 1, 1);
    final text = await format(tester, now: due, dueDate: due);
    expect(text, isNot(contains('Overdue')));
  });

  testWidgets('negative dives/hours remaining clamp to zero in the label', (
    tester,
  ) async {
    final text = await format(
      tester,
      now: DateTime(2026, 1, 1),
      divesSinceAnchor: 40,
      divesRemaining: -5,
      hoursSinceAnchor: 12.0,
      hoursRemaining: -1.0,
    );
    expect(text, contains('0 of 35 dives left'));
    expect(text, contains('0.0 of 11.0 hours left'));
  });

  testWidgets('multiple triggers join with a middle dot', (tester) async {
    final text = await format(
      tester,
      now: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 7, 16),
      divesSinceAnchor: 10,
      divesRemaining: 5,
    );
    expect(text, contains(' · '));
  });
}
