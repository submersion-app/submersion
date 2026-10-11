import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_itinerary_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

ItineraryDay _row(String id, DateTime date, int storedNumber) => ItineraryDay(
  id: id,
  tripId: 'trip-1',
  dayNumber: storedNumber,
  date: date,
  dayType: DayType.diveDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// The tab over [days] for [trip] with no dives, in a [viewSize] window. The
/// story is left unresolved: the tab reads it only for media lines.
Future<void> _pumpTab(
  WidgetTester tester, {
  required Trip trip,
  required List<ItineraryDay> days,
  Size viewSize = const Size(800, 700),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        tripByIdProvider('trip-1').overrideWith((ref) async => trip),
        itineraryDaysProvider('trip-1').overrideWith((ref) async => days),
        divesForTripProvider('trip-1').overrideWith((ref) async => const []),
        tripStoryProvider(
          'trip-1',
        ).overrideWith((ref) => Completer<Never>().future),
      ].cast(),
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TripItineraryTab(tripId: 'trip-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('opens at today', () {
    List<ItineraryDay> rows(List<int> days) => [
      for (final d in days) _row('r$d', DateTime(2026, 3, d), d),
    ];
    Trip longTrip() => Trip(
      id: 'trip-1',
      name: 'Bonaire',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 30),
      tripType: TripType.resort,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('anchor is the first row today or later', () {
      final now = DateTime(2026, 3, 10, 9);
      expect(itineraryAnchorIndex(rows([8, 10, 12]), now), 1);
      expect(itineraryAnchorIndex(rows([8, 11, 12]), now), 1);
      expect(itineraryAnchorIndex(rows([8, 9]), now), isNull);
    });

    // Thirty rows, so plenty follows today and it can open at the top.
    testWidgets('an in-progress trip opens with today on top', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 30; d++) d]),
        );
      });
      final chip = find.byKey(const Key('today-chip'));
      expect(chip, findsOneWidget);
      expect(tester.getTopLeft(chip).dy, lessThan(150));
      expect(find.text('Day 1'), findsNothing);
    });

    testWidgets('earlier days are above, by scrolling up', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 20; d++) d]),
        );
        for (var i = 0; i < 6; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 700),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
      expect(find.text('Day 1'), findsOneWidget);
      // Day 1 reads above Day 2: the list stays in reading order.
      expect(
        tester.getTopLeft(find.text('Day 1')).dy,
        lessThan(tester.getTopLeft(find.text('Day 2')).dy),
      );
    });

    testWidgets('a day without a row anchors on the next one', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([
            for (var d = 1; d <= 30; d++)
              if (d != 15) d,
          ]),
        );
      });
      expect(find.text('Day 1'), findsNothing);
      expect(tester.getTopLeft(find.text('Day 16')).dy, lessThan(150));
    });

    testWidgets('a trip that has ended opens at Day 1', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 4, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 20; d++) d]),
        );
      });
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets('the last day fills the window with the days before it', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 20; d++) d]),
        );
      });
      // Today is the last row: rather than sit at the top over a blank
      // window, it ends the window with the days before it above.
      final chip = find.byKey(const Key('today-chip'));
      expect(tester.getTopLeft(chip).dy, greaterThan(300));
      expect(find.text('Day 19'), findsOneWidget);
      expect(find.text('Day 18'), findsOneWidget);
    });

    testWidgets('the gap above today matches the gaps between other days', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 15, 9)), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 30; d++) d]),
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
        await tester.pump();
      });
      Rect card(String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(Card)),
      );
      final aboveToday = card('Day 15').top - card('Day 14').bottom;
      final belowToday = card('Day 16').top - card('Day 15').bottom;
      expect(aboveToday, belowToday);
    });

    testWidgets('today moves on at midnight while the tab stays open', (
      tester,
    ) async {
      var now = DateTime(2026, 3, 15, 23, 30);
      Finder todayCard() => find.ancestor(
        of: find.byKey(const Key('today-chip')),
        matching: find.byType(Card),
      );
      await withClock(Clock(() => now), () async {
        await _pumpTab(
          tester,
          trip: longTrip(),
          days: rows([for (var d = 1; d <= 30; d++) d]),
        );
        expect(
          find.descendant(of: todayCard(), matching: find.text('Day 15')),
          findsOneWidget,
        );

        now = now.add(const Duration(hours: 1));
        await tester.pump(const Duration(hours: 1));
        await tester.pump();
        expect(
          find.descendant(of: todayCard(), matching: find.text('Day 16')),
          findsOneWidget,
        );
      });
    });
  });
}
