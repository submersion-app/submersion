import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';

ItineraryDay _row(int? planned) => ItineraryDay(
  id: 'r',
  tripId: 't',
  dayNumber: 1,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  plannedDives: planned,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('no row, a derived plan or a planned rest day has no progress', () {
    for (final row in [null, _row(null), _row(0)]) {
      expect(
        dayPlanProgress(row: row, logged: 1, kind: TripStoryDayKind.past),
        isNull,
      );
    }
  });

  test('past and today report logged against planned', () {
    for (final kind in [TripStoryDayKind.past, TripStoryDayKind.today]) {
      final p = dayPlanProgress(row: _row(3), logged: 4, kind: kind)!;
      expect((p.planned, p.logged, p.upcoming), (3, 4, false));
    }
  });

  test('a future day is upcoming', () {
    final p = dayPlanProgress(
      row: _row(2),
      logged: 0,
      kind: TripStoryDayKind.future,
    )!;
    expect(p.upcoming, isTrue);
  });
}
