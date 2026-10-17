import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether [saved] is the dive the Apple Watch import saved for [incoming]'s
/// HealthKit workout.
bool isSameAppleWatchWorkout(Dive saved, ImportedDive incoming) =>
    saved.importSource == 'appleWatch' && saved.importId == incoming.sourceId;

/// The shift that moves [saved] to [incoming]'s wall-clock start, or null
/// when [saved] needs none (issue #2812).
///
/// Before #2811 the Apple Watch import saved a dive's start as the real
/// instant HealthKit reported, while every dive time is the wall clock the
/// diver saw, flagged UTC; such a dive's start equals that instant to the
/// millisecond. Anything else is left alone: a dive saved after #2811 already
/// holds the wall clock, and one whose time the diver changed by hand no
/// longer matches the instant. In UTC instant and wall clock agree, so
/// nothing moves.
Duration? appleWatchWallClockShift(Dive saved, ImportedDive incoming) {
  final instant = incoming.startInstant;
  if (instant == null || !isSameAppleWatchWorkout(saved, incoming)) {
    return null;
  }
  final stored = saved.dateTime.millisecondsSinceEpoch;
  if (stored != instant.millisecondsSinceEpoch) return null;
  final shift = Duration(
    milliseconds: incoming.startTime.millisecondsSinceEpoch - stored,
  );
  return shift == Duration.zero ? null : shift;
}
