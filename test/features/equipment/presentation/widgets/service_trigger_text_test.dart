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
    expect(text, contains('40 of 35 dives, 0 left'));
    expect(text, contains('12.0 of 11.0 hours, 0.0 left'));
  });

  testWidgets('dives and hours triggers show the used value alongside the '
      'remaining one', (tester) async {
    final text = await format(
      tester,
      now: DateTime(2026, 1, 1),
      divesSinceAnchor: 61,
      divesRemaining: 59,
      hoursSinceAnchor: 10.0,
      hoursRemaining: 30.0,
    );
    expect(text, contains('61 of 120 dives, 59 left'));
    expect(text, contains('10.0 of 40.0 hours, 30.0 left'));
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

  group('formatServiceTriggerLines', () {
    Future<List<String>> lines(
      WidgetTester tester, {
      DateTime? dueDate,
      int? divesSinceAnchor,
      int? divesRemaining,
      double? hoursSinceAnchor,
      double? hoursRemaining,
    }) async {
      late List<String> result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              result = formatServiceTriggerLines(
                context,
                units: const UnitFormatter(AppSettings()),
                now: DateTime(2026, 1, 1),
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

    testWidgets('returns one unjoined entry per trigger, date first', (
      tester,
    ) async {
      final result = await lines(
        tester,
        dueDate: DateTime(2026, 7, 16),
        divesSinceAnchor: 10,
        divesRemaining: 5,
        hoursSinceAnchor: 2.0,
        hoursRemaining: 8.0,
      );
      expect(result, hasLength(3));
      expect(result[0], startsWith('Due '));
      expect(result[1], '10 of 15 dives, 5 left');
      expect(result[2], '2.0 of 10.0 hours, 8.0 left');
      expect(result.any((line) => line.contains(' · ')), isFalse);
    });

    testWidgets('returns an empty list for a clock with no trigger', (
      tester,
    ) async {
      expect(await lines(tester), isEmpty);
    });
  });
}
