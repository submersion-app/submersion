import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_scene_facts.dart';

/// A trip starting [start] (a whole day) and lasting [days] calendar days.
TripWithStats sceneTrip(
  String id,
  String name,
  DateTime start, {
  int days = 7,
  int dives = 4,
  TripType type = TripType.shore,
}) => TripWithStats(
  trip: Trip(
    id: id,
    name: name,
    startDate: start,
    endDate: DateTime(start.year, start.month, start.day + days - 1),
    tripType: type,
    createdAt: start,
    updatedAt: start,
  ),
  diveCount: dives,
);

void main() {
  final now = DateTime(2026, 10, 17, 15);
  DateTime day(int n) => DateTime(now.year, now.month, now.day + n);

  test('totals trips, days, liveaboards and dives as the widget does', () {
    final facts = TripSceneFacts.from([
      sceneTrip('a', 'Bali', day(-150), days: 10, dives: 20),
      sceneTrip(
        'b',
        'Red Sea',
        day(-400),
        days: 8,
        dives: 18,
        type: TripType.liveaboard,
      ),
      sceneTrip('c', 'Komodo', day(23), days: 12, dives: 0),
    ], now);

    expect(facts.tripCount, 3);
    expect(facts.totalDays, 30);
    expect(facts.liveaboards, 1);
    expect(facts.totalDives, 38);
  });

  test(
    'next is the earliest upcoming trip and last the latest started one',
    () {
      final facts = TripSceneFacts.from([
        sceneTrip('old', 'Red Sea', day(-400)),
        sceneTrip('far', 'Raja Ampat', day(90)),
        sceneTrip('last', 'Bali', day(-150)),
        sceneTrip('next', 'Komodo', day(23)),
      ], now);

      expect(facts.next?.trip.id, 'next');
      expect(facts.last?.trip.id, 'last');
    },
  );

  test('a trip starting today is the last trip, not the next', () {
    final facts = TripSceneFacts.from([
      sceneTrip('today', 'Gozo', day(0)),
      sceneTrip('tomorrow', 'Komodo', day(1)),
    ], now);

    expect(facts.last?.trip.id, 'today');
    expect(facts.next?.trip.id, 'tomorrow');
  });

  test('only upcoming trips leave last empty, only past ones leave next '
      'empty', () {
    expect(
      TripSceneFacts.from([sceneTrip('n', 'Komodo', day(5))], now).last,
      isNull,
    );
    expect(
      TripSceneFacts.from([sceneTrip('l', 'Bali', day(-5))], now).next,
      isNull,
    );
  });
}
