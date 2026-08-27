import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The tolerance around a dive's profile inside which an automatically
/// derived media position is still trusted.
///
/// A capture time a few minutes past the exit is a surface shot and belongs
/// pinned to the end of the profile; a capture time days away (a camera
/// with an unset clock, a file whose only date is its copy-to-disk time) is
/// not knowledge about the dive at all, and drawing it at the exit invents
/// a position the diver never chose (issue #1090). The buffers are the same
/// ones [DivePhotoMatcher] uses to decide a file belongs to a dive in the
/// first place, so a file that matched by time is never dropped here.
class MediaDiveWindow {
  const MediaDiveWindow._();

  /// The dive's length as the chart measures it: the last sample's offset,
  /// or 0 for a dive with no profile.
  static int profileLengthSeconds(List<DiveProfilePoint> profile) {
    var length = 0;
    for (final point in profile) {
      if (point.timestamp > length) length = point.timestamp;
    }
    return length;
  }

  /// Slack before the profile start: boat, dock and pre-descent shots.
  static const Duration before = Duration(minutes: 30);

  /// Slack after the profile end: surface-interval and debrief shots.
  static const Duration after = Duration(minutes: 60);

  /// Whether [elapsedSeconds] from the dive start lies inside the profile of
  /// [profileLengthSeconds], widened by [before] and [after].
  static bool contains({
    required int elapsedSeconds,
    required int profileLengthSeconds,
  }) {
    return elapsedSeconds >= -before.inSeconds &&
        elapsedSeconds <= profileLengthSeconds + after.inSeconds;
  }
}
