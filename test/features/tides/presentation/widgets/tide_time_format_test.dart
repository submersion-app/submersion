import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_times_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  // The widget formats via DateFormat(pattern) with no explicit locale, so it
  // resolves against intl's process-global default. Pin it so the expected
  // digits do not depend on the locale the test host happens to run under.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets(
    'renders wall-clock-as-UTC tide times without a device-local shift (#222)',
    (tester) async {
      // Dive timestamps are stored wall-clock-as-UTC: the digits the diver
      // saw, flagged UTC. Formatting must print them verbatim; .toLocal()
      // shifts them by the MACHINE's UTC offset (the reported -7h in PDT).
      // On a UTC machine this test passes either way; on any other timezone
      // the pre-fix code renders a shifted time and this fails.
      final extremes = [
        TideExtreme(
          type: TideExtremeType.high,
          time: DateTime.utc(2026, 1, 15, 10, 30),
          heightMeters: 1.2,
        ),
        TideExtreme(
          type: TideExtremeType.low,
          time: DateTime.utc(2026, 1, 15, 16, 45),
          heightMeters: 0.3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TideTimesTable(
              extremes: extremes,
              now: DateTime.utc(2026, 1, 15, 9),
              showPast: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('10:30'), findsWidgets);
      expect(find.textContaining('16:45'), findsWidgets);
    },
  );

  testWidgets(
    'labels extremes beyond tomorrow with their wall-clock date (#222)',
    (tester) async {
      // Neither today nor tomorrow relative to `now`, so the row falls through
      // to the absolute 'EEE, MMM d' label. A device-local shift would move
      // the extreme across a day boundary and rewrite that date.
      final extremes = [
        TideExtreme(
          type: TideExtremeType.high,
          time: DateTime.utc(2026, 1, 20, 10, 30),
          heightMeters: 1.2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TideTimesTable(
              extremes: extremes,
              now: DateTime.utc(2026, 1, 15, 9),
              showPast: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>();
      expect(
        labels.any((l) => l.contains('Tue, Jan 20 at 10:30')),
        isTrue,
        reason: 'row semantics should carry the unshifted date and time',
      );
    },
  );

  testWidgets(
    'NextTideTimes renders unshifted next high and low times (#222)',
    (tester) async {
      final extremes = [
        TideExtreme(
          type: TideExtremeType.high,
          time: DateTime.utc(2026, 1, 15, 10, 30),
          heightMeters: 1.2,
        ),
        TideExtreme(
          type: TideExtremeType.low,
          time: DateTime.utc(2026, 1, 15, 16, 45),
          heightMeters: 0.3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NextTideTimes(
              extremes: extremes,
              now: DateTime.utc(2026, 1, 15, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('16:45'), findsOneWidget);
    },
  );
}
