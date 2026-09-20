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
  List<TripWithStats> trips,
) async {
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
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripSummaryWidget(),
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
    // The clock is read here rather than in the file's preamble, which runs
    // before the tests above it: the widget reads its own clock while it
    // builds, so the further apart the two readings are, the wider the window
    // in which local midnight can pass between them and make the trip four
    // days out instead of five. Reading it immediately before the pump leaves
    // only the frame itself.
    final today = DateTime.now();
    final inFiveDays = DateTime(today.year, today.month, today.day + 5);

    await _pump(tester, DateFormatPreference.mmmDYYYY, [
      _trip(id: 't2', name: 'Palau Liveaboard', start: inFiveDays),
    ]);

    expect(find.textContaining('In 5 days'), findsOneWidget);
  });
}
