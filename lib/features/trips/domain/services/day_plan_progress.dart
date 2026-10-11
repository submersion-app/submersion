import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// A day's plan against what was logged. [upcoming] days have nothing logged
/// yet, so they read as a plan; past days and today read as progress, which
/// lets the diver compare plan and reality afterwards.
class DayPlanProgress extends Equatable {
  final int planned;
  final int logged;
  final bool upcoming;

  const DayPlanProgress({
    required this.planned,
    required this.logged,
    required this.upcoming,
  });

  @override
  List<Object?> get props => [planned, logged, upcoming];
}

/// The plan to show for a day, or null when there is none to show: no
/// itinerary row, a derived plan (null), or a planned rest day (0), which the
/// story already labels a surface day.
DayPlanProgress? dayPlanProgress({
  required ItineraryDay? row,
  required int logged,
  required TripStoryDayKind kind,
}) {
  final planned = row?.plannedDives;
  if (planned == null || planned <= 0) return null;
  return DayPlanProgress(
    planned: planned,
    logged: logged,
    upcoming: kind == TripStoryDayKind.future,
  );
}
