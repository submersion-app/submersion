import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// #1512: the trips landing panel dated both the recent-trips list and the
/// next-trip card with `DateFormat.yMMMd()`, so a diver on DD/MM/YYYY read
/// "Jun 1, 2025" on the first screen the Trips tab shows them.
///
/// The host pins `Locale('en')`: UnitFormatter spells the month with `MMM`,
/// which intl resolves against the app locale.

/// The widget only reads the trip list; every mutation is out of scope here.
class _StubTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _StubTripListNotifier(List<TripWithStats> trips)
    : super(AsyncValue.data(trips));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TripWithStats _trip({
  required String id,
  required String name,
  required DateTime start,
}) => TripWithStats(
  trip: Trip(
    id: id,
    name: name,
    startDate: start,
    endDate: DateTime(start.year, start.month, start.day + 7),
    tripType: TripType.shore,
    createdAt: start,
    updatedAt: start,
  ),
  diveCount: 4,
);

Future<void> _pump(
  WidgetTester tester,
  DateFormatPreference format,
  List<TripWithStats> trips, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripListNotifierProvider.overrideWith(
          (ref) => _StubTripListNotifier(trips),
        ),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(AppSettings(dateFormat: format)),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TripSummaryWidget(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Anchored off "now" so the widget's own past/upcoming split holds whenever
  // the suite runs; only the month and day are asserted, never the year.
  final past = DateTime(DateTime.now().year - 1, 6, 1);
  final now = DateTime.now();
  // Calendar-day offsets, never `Duration`: adding elapsed time across a
  // daylight-saving transition lands an hour either side of midnight and
  // shifts the calendar date the countdown is asserted against.
  final upcoming = DateTime(now.year, now.month, now.day + 30);

  group('TripSummaryWidget honours the diver date format', () {
    testWidgets('the recent-trips list is day-first', (tester) async {
      await _pump(tester, DateFormatPreference.ddmmyyyy, [
        _trip(id: 't1', name: 'Red Sea Explorer', start: past),
      ]);

      expect(find.textContaining('01/06/${past.year}'), findsOneWidget);
      expect(find.textContaining('Jun 1,'), findsNothing);
    });

    testWidgets('the recent-trips list spells the month when asked', (
      tester,
    ) async {
      await _pump(tester, DateFormatPreference.mmmDYYYY, [
        _trip(id: 't1', name: 'Red Sea Explorer', start: past),
      ]);

      expect(find.textContaining('Jun 1, ${past.year}'), findsOneWidget);
    });

    testWidgets('the next-trip card follows the same preference', (
      tester,
    ) async {
      await _pump(tester, DateFormatPreference.yyyymmdd, [
        _trip(id: 't1', name: 'Red Sea Explorer', start: past),
        _trip(id: 't2', name: 'Palau Liveaboard', start: upcoming),
      ]);

      final iso =
          '${upcoming.year}-'
          '${upcoming.month.toString().padLeft(2, '0')}-'
          '${upcoming.day.toString().padLeft(2, '0')}';
      expect(find.textContaining(iso), findsWidgets);
    });
  });

  testWidgets('the next-trip card counts whole calendar days to departure', (
    tester,
  ) async {
    // Counting from the current instant instead of today's date floors away
    // the rest of today, so a trip five calendar days out read "In 4 days" at
    // any hour past midnight; a spring-forward inside the window took another.
    //
    // Both the widget's upcoming filter and Trip.daysUntilStart read the
    // clock while the frame builds, so a real clock leaves a window in which
    // local midnight passes between the test's reading and the widget's and
    // makes the trip four days out. Pinning the clock removes the window and
    // lets the range span a real transition: 2026-10-28 to 2026-11-02 crosses
    // the fall-back on 2026-11-01.
    //
    // Midday, not midnight: a fall-back adds an hour to the range, so from
    // 00:30 the elapsed total is exactly 120 hours and truncating it also
    // gives 5. The assertion would then hold against the very implementation
    // it exists to reject, in the one zone that crosses the transition. From
    // midday the elapsed total is 108 or 109 hours, which truncates to 4
    // whatever the zone does.
    await withClock(Clock.fixed(DateTime(2026, 10, 28, 12)), () async {
      await _pump(tester, DateFormatPreference.mmmDYYYY, [
        _trip(id: 't2', name: 'Palau Liveaboard', start: DateTime(2026, 11, 2)),
      ]);

      expect(find.textContaining('In 5 days'), findsOneWidget);
    });
  });

  group('TripSummaryWidget localises the next-trip countdown', () {
    // #2218: the subtitle was a hardcoded English
    // `'$date • In $days days'`, so it shipped English to every locale and
    // disagreed with its own count at one day.
    //
    // Dated from the preamble's `upcoming`, which is today plus 30 calendar
    // days: built field-by-field rather than with a Duration, because adding
    // 30 days of elapsed time lands an hour short whenever the window crosses
    // a DST change, which is the trap #2207 was.

    testWidgets('a German diver reads the countdown in German', (tester) async {
      await _pump(tester, DateFormatPreference.yyyymmdd, [
        _trip(id: 't1', name: 'Palau Liveaboard', start: upcoming),
      ], locale: const Locale('de'));

      // de spells the plural's `other` branch "In {days} Tagen", so finding
      // it proves both that the string resolved through l10n and that the
      // count reached the plural as a number.
      expect(find.textContaining('Tagen'), findsOneWidget);
      expect(find.textContaining('days'), findsNothing);
    });

    // English renders byte-identically either side of the fix, so this one
    // cannot go red on the old code. It is here to hold the composition in
    // place: the date and the countdown stay in a single Text, separated by
    // the bullet the translation supplies.
    testWidgets('the English card keeps the date and countdown together', (
      tester,
    ) async {
      await _pump(tester, DateFormatPreference.yyyymmdd, [
        _trip(id: 't1', name: 'Palau Liveaboard', start: upcoming),
      ]);

      final iso =
          '${upcoming.year}-'
          '${upcoming.month.toString().padLeft(2, '0')}-'
          '${upcoming.day.toString().padLeft(2, '0')}';
      expect(find.textContaining('$iso • In '), findsOneWidget);
    });
  });
}
