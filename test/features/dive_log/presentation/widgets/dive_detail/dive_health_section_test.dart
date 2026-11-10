import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_health_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Heart rate, recovery and sleep from Apple Health on a dive's detail page
/// (issue #637): plain numbers, never a verdict.
void main() {
  DiveHealthRecord record({
    int? average = 79,
    int? atExit = 88,
    double? hrv = 48.5,
    int? sleep = 412,
  }) => DiveHealthRecord(
    id: 'h1',
    diveId: 'd1',
    avgHeartRate: average,
    maxHeartRate: average == null ? null : 96,
    heartRateAtExit: atExit,
    heartRateExitPlus5: atExit == null ? null : 74,
    heartRateExitPlus15: atExit == null ? null : 66,
    overnightHrvMs: hrv,
    sleepBeforeMinutes: sleep,
    fetchedAt: DateTime.utc(2026, 7, 17, 13),
  );

  Future<void> pump(WidgetTester tester, DiveHealthRecord r) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: DiveHealthSection(record: r)),
          ),
        ),
      );

  testWidgets('shows the numbers without a verdict', (tester) async {
    await pump(tester, record());

    expect(find.text('Heart rate and recovery'), findsOneWidget);
    for (final value in ['79 bpm', '96 bpm', '88 bpm', '74 bpm', '66 bpm']) {
      expect(find.text(value), findsOneWidget, reason: value);
    }
    expect(find.text('49 ms'), findsOneWidget);
    expect(
      find.text(
        'Heart rate at surfacing and 5 and 15 minutes later, from Apple '
        'Health.',
      ),
      findsOneWidget,
    );
    for (final verdict in ['good', 'poor', 'normal', 'healthy']) {
      expect(
        find.textContaining(RegExp(verdict, caseSensitive: false)),
        findsNothing,
        reason: verdict,
      );
    }
  });

  testWidgets('the sleep note gives hours and minutes', (tester) async {
    await pump(tester, record());

    expect(find.text('Slept 6 h 52 min the night before'), findsOneWidget);
  });

  testWidgets('leaves out what Health did not have', (tester) async {
    await pump(tester, record(average: null, hrv: null, sleep: null));

    expect(find.text('88 bpm'), findsOneWidget);
    expect(find.textContaining('Average'), findsNothing);
    expect(find.textContaining('Slept'), findsNothing);
    expect(find.textContaining('ms'), findsNothing);
  });

  test('a record with nothing in it has nothing to show', () {
    expect(
      diveHealthHasContent(
        record(average: null, atExit: null, hrv: null, sleep: null),
      ),
      isFalse,
    );
    expect(diveHealthHasContent(null), isFalse);
    expect(diveHealthHasContent(record()), isTrue);
  });
}
