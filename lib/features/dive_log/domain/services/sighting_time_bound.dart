import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The latest time, in seconds from the dive start, a sighting on [dive]
/// can be given (issue #5092): the last second of [profile] (the one the
/// chart draws), else the dive's measured runtime, else its bottom time,
/// else a day. Never an estimate of the runtime.
int sightingTimeMaxSeconds(Dive dive, List<DiveProfilePoint> profile) {
  if (profile.isNotEmpty) return profile.last.timestamp;
  final recorded = dive.measuredRuntime ?? dive.bottomTime;
  if (recorded != null && recorded.inSeconds > 0) return recorded.inSeconds;
  return Duration.secondsPerDay;
}
