import 'package:submersion/features/trips/domain/entities/trip.dart';

/// The facts the Trips passage scene shows, derived from the trip list
/// exactly as `TripSummaryWidget` derives them.
class TripSceneFacts {
  const TripSceneFacts._({
    required this.tripCount,
    required this.totalDays,
    required this.liveaboards,
    required this.totalDives,
    required this.next,
    required this.last,
  });

  factory TripSceneFacts.from(List<TripWithStats> trips, DateTime now) {
    // Upcoming is "starts after now", as the details view counts it, so a
    // trip under way or starting today is the last trip, not the next.
    final upcoming = trips.where((t) => t.trip.startDate.isAfter(now)).toList()
      ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));
    final started = trips.where((t) => !t.trip.startDate.isAfter(now)).toList()
      ..sort((a, b) => b.trip.startDate.compareTo(a.trip.startDate));

    return TripSceneFacts._(
      tripCount: trips.length,
      totalDays: trips.fold(0, (sum, t) => sum + t.trip.durationDays),
      liveaboards: trips.where((t) => t.trip.isLiveaboard).length,
      totalDives: trips.fold(0, (sum, t) => sum + t.diveCount),
      next: upcoming.firstOrNull,
      last: started.firstOrNull,
    );
  }

  final int tripCount;
  final int totalDays;
  final int liveaboards;
  final int totalDives;

  /// The earliest trip that has not started yet.
  final TripWithStats? next;

  /// The latest trip that has started, under way or over.
  final TripWithStats? last;
}
