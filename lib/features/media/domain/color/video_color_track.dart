import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/color/auto_correction.dart';

/// The automatic fix measured at one moment of a clip.
class VideoColorKey extends Equatable {
  const VideoColorKey({required this.seconds, required this.params});

  final double seconds;
  final AutoCorrectionParams params;

  @override
  List<Object?> get props => [seconds, params];
}

/// A video's automatic fix through the clip: sampled frames, blended during
/// playback, and limited at each moment by the depth the profile gives
/// for it, so a clip that descends warms up as it goes.
class VideoColorTrack extends Equatable {
  const VideoColorTrack(this.keys);

  final List<VideoColorKey> keys;

  List<VideoColorKey> get _sorted =>
      List.of(keys)..sort((a, b) => a.seconds.compareTo(b.seconds));

  /// The fix at [seconds] into the clip. [depthAt] gives the depth at a
  /// moment (null when unknown), which bounds the blended params.
  AutoCorrectionParams paramsAt(
    double seconds, {
    double? Function(double seconds)? depthAt,
  }) {
    final sorted = _sorted;
    if (sorted.isEmpty) return AutoCorrectionParams.none;
    final AutoCorrectionParams blended;
    if (seconds <= sorted.first.seconds) {
      blended = sorted.first.params;
    } else if (seconds >= sorted.last.seconds) {
      blended = sorted.last.params;
    } else {
      var i = 1;
      while (sorted[i].seconds < seconds) {
        i++;
      }
      final lo = sorted[i - 1], hi = sorted[i];
      final t = (seconds - lo.seconds) / (hi.seconds - lo.seconds);
      blended = AutoCorrectionParams.lerp(lo.params, hi.params, t);
    }
    return depthAt == null ? blended : blended.boundedFor(depthAt(seconds));
  }

  /// The clip's overall fix, for thumbnails and grids.
  AutoCorrectionParams get average {
    if (keys.isEmpty) return AutoCorrectionParams.none;
    var mean = keys.first.params;
    for (var k = 1; k < keys.length; k++) {
      mean = AutoCorrectionParams.lerp(mean, keys[k].params, 1 / (k + 1));
    }
    return mean;
  }

  @override
  List<Object?> get props => [keys];
}

/// When to sample [count] frames from a clip of [duration], in seconds: the
/// middle of each of [count] equal slices, so no sample sits on the first
/// or last frame (often black, or the camera being raised).
List<double> frameSampleTimes(Duration duration, {int count = 7}) {
  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0 || count <= 0) return const [];
  return [for (var i = 0; i < count; i++) (i + 0.5) * seconds / count];
}
