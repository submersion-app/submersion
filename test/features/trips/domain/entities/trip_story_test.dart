import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

Trip _trip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 8),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TripStory _story() => TripStory(
  trip: _trip(),
  days: const [],
  checklist: const TripStoryChecklistSummary(done: 1, total: 3),
  mapGeometry: const TripStoryMapGeometry(points: []),
);

void main() {
  test('TripStoryChecklistSummary reports isEmpty and value equality', () {
    const empty = TripStoryChecklistSummary(done: 0, total: 0);
    expect(empty.isEmpty, isTrue);

    // Non-const on purpose: const instances are canonicalized and `==`
    // short-circuits via identical(), which would skip the props getter.
    // ignore: prefer_const_constructors
    final a = TripStoryChecklistSummary(done: 1, total: 3, nextDue: []);
    // ignore: prefer_const_constructors
    final b = TripStoryChecklistSummary(done: 1, total: 3, nextDue: []);
    expect(a.isEmpty, isFalse);
    expect(a, equals(b));
  });

  test('TripStory compares by value', () {
    final a = _story();
    final b = _story();
    expect(a, equals(b));
    expect(a.isEmpty, isTrue); // no days
  });
}
