import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';

void main() {
  // A seven-day trip; "now" is 09:00 on its third day, Mar 10.
  final start = DateTime(2026, 3, 8);
  final end = DateTime(2026, 3, 14);
  final morning = DateTime(2026, 3, 10, 9);

  ItineraryDay day(int d, {DayType type = DayType.diveDay, int? planned}) =>
      ItineraryDay(
        id: 'i$d',
        tripId: 't1',
        dayNumber: d - 7,
        date: DateTime(2026, 3, d),
        dayType: type,
        plannedDives: planned,
        createdAt: start,
        updatedAt: start,
      );

  FillForecast? forecast({
    DateTime? now,
    int full = 6,
    int partial = 1,
    int slots = 8,
    List<ItineraryDay> itinerary = const [],
    int? target,
    int? expected,
    List<double> history = const [],
    int divers = 1,
    int logged = 0,
    int? opens,
    int? closes,
  }) => computeFillForecast(
    FillForecastInputs(
      now: now ?? morning,
      tripStart: start,
      tripEnd: end,
      slotCount: slots,
      fullCount: full,
      partialCount: partial,
      itinerary: itinerary,
      divesPerDayTarget: target,
      expectedDives: expected,
      divesPerDiveDayHistory: history,
      diversSharing: divers,
      divesLoggedToday: logged,
      fillOpensAt: opens,
      fillClosesAt: closes,
    ),
  );

  List<int> planned(FillForecast f) => [for (final d in f.days) d.plannedDives];

  group('planned dives per day, first match wins', () {
    test('nothing set: two a day, today through the last day', () {
      final f = forecast()!;
      expect(f.days.first.date, DateTime(2026, 3, 10));
      expect(planned(f), [2, 2, 2, 2, 2]);
    });

    test('the median of recent trips, rounded up', () {
      // Median of 2.0 and 3.0 is 2.5, rounded up to 3.
      expect(planned(forecast(history: [2.0, 3.0])!).first, 3);
    });

    test('the expected dives spread over the dive days beat history', () {
      // 15 dives over 7 dive days is 2.14 a day, rounded up to 3.
      expect(planned(forecast(expected: 15, history: [1.0])!).first, 3);
    });

    test('the spread counts only dive days', () {
      // Mar 12 is a sea day: 13 dives over 6 dive days is 2.17, so 3 (over
      // 7 it would be 1.86, so 2). The sea day plans none.
      final f = forecast(
        expected: 13,
        itinerary: [day(12, type: DayType.seaDay)],
      )!;
      expect(planned(f), [3, 3, 0, 3, 3]);
    });

    test('the trip target beats the expected dives', () {
      expect(planned(forecast(target: 4, expected: 15)!).first, 4);
    });

    test('a zero or negative target counts as unset', () {
      expect(planned(forecast(target: 0, history: [3.0])!).first, 3);
    });

    test('a planned itinerary day beats everything, even off a dive day', () {
      final f = forecast(
        target: 4,
        itinerary: [
          day(11, type: DayType.portDay, planned: 1),
          day(12, planned: 0),
        ],
      )!;
      expect(planned(f), [4, 1, 0, 4, 4]);
      expect(
        [for (final d in f.days) d.isOverride],
        [false, true, true, false, false],
      );
    });
  });

  group('demand and supply', () {
    test('the spec example: tomorrow short once today has used its share', () {
      // 2 divers, 2 dives a day: today needs 4 of the 6 full, leaving 2 for
      // tomorrow's 4.
      final f = forecast(divers: 2)!;
      expect(f.todayDemand, 4);
      expect(f.tomorrowDemand, 4);
      expect(f.tomorrowSupply, 2);
      expect(f.todayShortfall, 0);
      expect(f.tomorrowShortfall, 2);
      expect(f.fillRunNeeded, isTrue);
      expect(f.caution, isFalse);
    });

    test('dives logged today reduce today\'s planned dives', () {
      // 3 divers, 1 of 2 dives logged: 1 dive left is 3 cylinders. 4 full
      // leaves 1 for tomorrow's 6: 5 short.
      final f = forecast(divers: 3, logged: 1, full: 4)!;
      expect(f.todayDemand, 3);
      expect(f.tomorrowDemand, 6);
      expect(f.tomorrowSupply, 1);
      expect(f.tomorrowShortfall, 5);
    });

    test('more dives logged than planned needs nothing more today', () {
      expect(forecast(logged: 3)!.todayDemand, 0);
    });

    test('today short: caution, and nothing left for tomorrow', () {
      // 1 full, today needs 2: 1 short; tomorrow's 2 have none left.
      final f = forecast(full: 1)!;
      expect(f.todayShortfall, 1);
      expect(f.caution, isTrue);
      expect(f.tomorrowSupply, 0);
      expect(f.tomorrowShortfall, 2);
    });

    test('enough: 6 full cover today\'s 2 and tomorrow\'s 2', () {
      final f = forecast()!;
      expect(f.tomorrowSupply, 4);
      expect(f.isShort, isFalse);
    });

    test('partial slots are reported, never counted', () {
      final f = forecast(full: 1, partial: 5)!;
      expect(f.partialCount, 5);
      expect(f.caution, isTrue);
    });

    test('the whole trip\'s remaining demand', () {
      // Today 2, then Mar 11 to 14 at 2 each: 10.
      expect(forecast()!.remainingDemand, 10);
    });
  });

  group('the trip calendar', () {
    test('an ended trip has no forecast', () {
      expect(forecast(now: DateTime(2026, 3, 15, 9)), isNull);
    });

    test('a trip with no slots has no forecast', () {
      expect(forecast(slots: 0, full: 0, partial: 0), isNull);
    });

    test('the last day asks nothing of tomorrow', () {
      final f = forecast(now: DateTime(2026, 3, 14, 9))!;
      expect(f.tomorrowDemand, 0);
      expect(f.days, hasLength(1));
    });

    test('the evening before the trip, tomorrow is its first day', () {
      final f = forecast(now: DateTime(2026, 3, 7, 20))!;
      expect(f.todayDemand, 0);
      expect(f.tomorrowDemand, 2);
      expect(f.days.first.date, DateTime(2026, 3, 8));
      expect(f.days, hasLength(7));
      expect(f.remainingDemand, 14);
    });
  });

  group('the fill deadline', () {
    test('closing later today is the deadline', () {
      expect(forecast(opens: 480, closes: 1020)!.deadlineMinutes, 1020);
    });

    test('after closing there is none', () {
      final f = forecast(
        now: DateTime(2026, 3, 10, 17, 30),
        opens: 480,
        closes: 1020,
      )!;
      expect(f.deadlineMinutes, isNull);
    });

    test('without both hours there is none', () {
      expect(forecast(closes: 1020)!.deadlineMinutes, isNull);
    });

    test('hours that close before they open are ignored', () {
      expect(forecast(opens: 1020, closes: 480)!.deadlineMinutes, isNull);
    });
  });

  group('fillForecastNextRefresh', () {
    test('at the deadline while it is ahead', () {
      final f = forecast(opens: 480, closes: 1020)!;
      expect(fillForecastNextRefresh(morning, f), DateTime(2026, 3, 10, 17));
    });

    test('else at the next midnight', () {
      expect(
        fillForecastNextRefresh(morning, forecast()!),
        DateTime(2026, 3, 11),
      );
    });
  });
}
