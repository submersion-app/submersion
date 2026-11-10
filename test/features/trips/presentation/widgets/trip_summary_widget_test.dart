import 'dart:async';

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

  _StubTripListNotifier.failed(Object error)
    : super(AsyncValue.error(error, StackTrace.empty));

  /// A reload of the whole list, as a diver switch starts one.
  void startReload() => state = const AsyncValue.loading();

  /// The reloaded list lands: the new diver's trips.
  void finishReload(List<TripWithStats> trips) =>
      state = AsyncValue.data(trips);

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
  TripFilterState filter = const TripFilterState(),
  Set<String> matchingIds = const {},
  Future<Set<String>> Function(TripFilterState filter)? idsFor,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripListNotifierProvider.overrideWith(
          (ref) => _StubTripListNotifier(trips),
        ),
        tripFilterProvider.overrideWith((ref) => filter),
        queryFilteredTripIdsProvider.overrideWith(
          (ref, filter) => idsFor?.call(filter) ?? Future.value(matchingIds),
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

  testWidgets('a failed trip load says so without the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripListNotifierProvider.overrideWith(
            (ref) =>
                _StubTripListNotifier.failed(StateError('database is locked')),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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

    expect(find.text("Couldn't load your trips."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  // Issue #3658: a larger trip's dive count already includes its side trips'
  // dives, so adding the side trip again would count those dives twice.
  testWidgets('the overview counts each dive and day once', (tester) async {
    final start = DateTime(DateTime.now().year - 1, 3, 2);
    final larger = TripWithStats(
      trip: Trip(
        id: 'p',
        name: 'Indonesia',
        startDate: start,
        endDate: DateTime(start.year, 3, 15),
        createdAt: start,
        updatedAt: start,
      ),
      diveCount: 5,
    );
    final side = TripWithStats(
      trip: Trip(
        id: 's',
        name: 'Raja Ampat',
        startDate: DateTime(start.year, 3, 8),
        endDate: DateTime(start.year, 3, 11),
        parentTripId: 'p',
        createdAt: start,
        updatedAt: start,
      ),
      diveCount: 2,
    );
    await _pump(tester, DateFormatPreference.mmmDYYYY, [larger, side]);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets("a side trip's days past its larger trip still count", (
    tester,
  ) async {
    final year = DateTime.now().year - 1;
    TripWithStats trip(String id, int from, int to, {String? parent}) =>
        TripWithStats(
          trip: Trip(
            id: id,
            name: id,
            startDate: DateTime(year, 3, from),
            endDate: DateTime(year, 3, to),
            parentTripId: parent,
            createdAt: DateTime(year),
            updatedAt: DateTime(year),
          ),
          diveCount: 3,
        );
    // Larger trip Mar 2 to 15 (14 days); the side trip runs Mar 12 to 18,
    // three days past it.
    await _pump(tester, DateFormatPreference.mmmDYYYY, [
      trip('p', 2, 15),
      trip('s', 12, 18, parent: 'p'),
    ]);
    expect(find.text('17'), findsOneWidget);
  });

  // Issue #4414: an equipment item's Trips row opens the trip list filtered
  // to the trips that used it, but the overview beside that list summed and
  // previewed every trip, so "10 trips" landed on "82 trips" and on three
  // trips the item never went on.
  group('TripSummaryWidget under a trip list filter', () {
    final year = DateTime.now().year - 1;
    TripWithStats trip(String id, String name, int month, int dives) =>
        TripWithStats(
          trip: Trip(
            id: id,
            name: name,
            startDate: DateTime(year, month, 1),
            endDate: DateTime(year, month, 5),
            createdAt: DateTime(year),
            updatedAt: DateTime(year),
          ),
          diveCount: dives,
        );
    final all = [
      trip('a', 'Sardinia', 8, 11),
      trip('b', 'Belgium', 6, 3),
      trip('c', 'Southern France', 5, 19),
      trip('d', 'Zeeland', 2, 7),
    ];
    const byTank = TripFilterState(equipmentId: 'tank-1');

    testWidgets('summarizes only the trips the list shows', (tester) async {
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        matchingIds: const {'b', 'd'},
      );

      expect(find.text('Filtered: summarizing 2 of 4 trips'), findsOneWidget);
      expect(find.bySemanticsLabel('Total Trips: 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Dives on these trips: 10'), findsOneWidget);
      expect(find.textContaining('Total Dives'), findsNothing);
      expect(find.text('Belgium'), findsOneWidget);
      expect(find.text('Zeeland'), findsOneWidget);
      expect(find.text('Sardinia'), findsNothing);
      expect(find.text('Southern France'), findsNothing);
    });

    testWidgets('Clear all drops the filter the list shares', (tester) async {
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        matchingIds: const {'b'},
      );

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );
      expect(container.read(tripFilterProvider), const TripFilterState());
      expect(find.textContaining('Filtered:'), findsNothing);
      expect(find.text('Sardinia'), findsOneWidget);
    });

    testWidgets('an unfiltered list shows no banner', (tester) async {
      await _pump(tester, DateFormatPreference.mmmDYYYY, all);

      expect(find.textContaining('Filtered:'), findsNothing);
      expect(find.bySemanticsLabel('Total Trips: 4'), findsOneWidget);
      expect(find.text('Total Dives'), findsOneWidget);
    });

    // A new filter's trip ids take a query's time and arrive with no
    // previous value. Until they land the overview waits, as the list does:
    // the previous filter's trips would sit under the new filter's banner
    // as rows the list does not show.
    testWidgets("shows no earlier filter's trips while a new filter loads", (
      tester,
    ) async {
      final second = Completer<Set<String>>();
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        idsFor: (filter) =>
            filter == byTank ? Future.value(const {'b'}) : second.future,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );

      container.read(tripFilterProvider.notifier).state = const TripFilterState(
        equipmentId: 'tank-2',
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Belgium'), findsNothing);
      expect(find.textContaining('of 4 trips'), findsNothing);

      second.complete(const {'a', 'd'});
      await tester.pumpAndSettle();

      expect(find.text('Filtered: summarizing 2 of 4 trips'), findsOneWidget);
      expect(find.text('Sardinia'), findsOneWidget);
      expect(find.text('Belgium'), findsNothing);
    });

    // A failed id query shows the error line, never the previous filter's
    // trips as if they were this filter's.
    testWidgets('a failed filter query keeps no earlier trips', (tester) async {
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        idsFor: (filter) => filter == byTank
            ? Future.value(const {'b'})
            : Future.error(StateError('query failed')),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );
      expect(find.text('Belgium'), findsOneWidget);

      container.read(tripFilterProvider.notifier).state = const TripFilterState(
        equipmentId: 'tank-2',
      );
      await tester.pumpAndSettle();

      expect(find.text('Belgium'), findsNothing);
      expect(find.text("Couldn't load your trips."), findsOneWidget);
      // The banner still says the overview is filtered, not a blank bar.
      expect(find.text('Filtered trips'), findsOneWidget);
    });

    // The unfiltered overview is not the filter's: it must not stand under
    // a "Filtered" banner while the filter's ids load.
    testWidgets('a first filter does not keep the unfiltered overview', (
      tester,
    ) async {
      final pending = Completer<Set<String>>();
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        idsFor: (_) => pending.future,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );

      container.read(tripFilterProvider.notifier).state = byTank;
      await tester.pump();

      expect(find.textContaining('of 4 trips'), findsNothing);
      expect(find.text('Sardinia'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const {'b'});
      await tester.pumpAndSettle();
      expect(find.text('Filtered: summarizing 1 of 4 trips'), findsOneWidget);
    });

    // A reload of the trip list itself (another diver) blanks as the list
    // does, rather than showing the previous list's trips and count.
    testWidgets('a trip list reload keeps no earlier trips', (tester) async {
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        matchingIds: const {'b'},
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );

      (container.read(tripListNotifierProvider.notifier)
              as _StubTripListNotifier)
          .startReload();
      await tester.pump();

      expect(find.text('Belgium'), findsNothing);
      expect(find.textContaining('of 4 trips'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // A diver switch reloads the list; a filter change during it starts an
    // id query with no previous value. When the new diver's list lands
    // first, the previous diver's trips must not come back while that
    // query is still in flight.
    testWidgets('a diver switch leaves no earlier trips to fall back to', (
      tester,
    ) async {
      final pending = Completer<Set<String>>();
      await _pump(
        tester,
        DateFormatPreference.mmmDYYYY,
        all,
        filter: byTank,
        idsFor: (filter) =>
            filter == byTank ? Future.value(const {'b'}) : pending.future,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripSummaryWidget)),
      );
      final list =
          container.read(tripListNotifierProvider.notifier)
              as _StubTripListNotifier;
      expect(find.text('Belgium'), findsOneWidget);

      list.startReload();
      await tester.pump();
      container.read(tripFilterProvider.notifier).state = const TripFilterState(
        equipmentId: 'tank-2',
      );
      await tester.pump();
      list.finishReload([trip('e', 'Malta', 9, 4)]);
      await tester.pump();

      expect(find.text('Belgium'), findsNothing);
      expect(find.textContaining('of 4 trips'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const {'e'});
      await tester.pumpAndSettle();
      expect(find.text('Malta'), findsOneWidget);
      expect(find.text('Filtered: summarizing 1 of 1 trip'), findsOneWidget);
    });
  });

  testWidgets('the recent-trips dive count is translated', (tester) async {
    await _pump(tester, DateFormatPreference.ddmmyyyy, [
      _trip(id: 't1', name: 'Belgien 2026', start: past),
    ], locale: const Locale('de'));

    expect(find.textContaining('4 Tauchgänge'), findsOneWidget);
    expect(find.textContaining('dives'), findsNothing);
  });
}
