import 'course_plan.dart';
import 'story_plan.dart';

export 'story_plan.dart' show StoryMilestone;

/// The scooter is bought before this dive.
const scooterDive = 450;

/// The dive number of every milestone in [dives] (numbered from 1, in time
/// order), with the rebreather course starting at [ccrStart].
Map<StoryMilestone, int> storyMilestones(
  List<PlannedDive> dives, {
  required int ccrStart,
  required Map<CertLevel, (int, int)> courses,
}) {
  int first(bool Function(PlannedDive d) test, {int from = 1}) =>
      dives.firstWhere((d) => d.number >= from && test(d)).number;
  final trips = <String>[];
  for (final d in dives) {
    if (d.tripId != null && !trips.contains(d.tripId)) trips.add(d.tripId!);
  }
  final coldLake = first(
    (d) =>
        d.destination.key == 'home' &&
        d.courseId == null &&
        (d.start.month < 5 || d.start.month > 9),
  );
  return {
    StoryMilestone.firstDive: 1,
    StoryMilestone.firstTrip: first((d) => d.tripId != null),
    // Rented for the first two trips.
    StoryMilestone.ownRegulator: first((d) => d.tripId == trips[2]),
    StoryMilestone.advanced: courses[CertLevel.advanced]!.$1,
    StoryMilestone.firstColdLake: coldLake,
    StoryMilestone.drysuit: coldLake,
    // A camera for a trip.
    StoryMilestone.photo: first((d) => d.tripId != null, from: 120),
    StoryMilestone.airIntegrated: 180,
    StoryMilestone.nitrox: nitroxDive,
    StoryMilestone.techStart: courses[CertLevel.decoProcedures]!.$1,
    StoryMilestone.trimix: courses[CertLevel.trimix]!.$1,
    StoryMilestone.scooter: scooterDive,
    StoryMilestone.ccrCourse: ccrStart,
    StoryMilestone.cellSwap: ccrStart + 8,
  };
}
