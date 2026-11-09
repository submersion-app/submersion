/// The part of a recording the diver spent underwater, which is what a
/// whole-dive SAC or RMV divides by (issue #2930).
///
/// Some computers keep logging while a transmitter is pressurised, so a
/// recording can end with minutes at the surface, and some start before the
/// descent. Counting those minutes as breathing time at depth makes the rate
/// read too low. Pure: the dive entity runs it on its profile and the derived
/// metrics repository on the same merged profile, so both report the same
/// window.
library;

import 'dart:math' as math;

import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/domain/services/surface_breathing.dart';

export 'package:submersion/features/dive_log/domain/services/surface_breathing.dart'
    show SurfaceBreathing;

/// A sample deeper than this, in metres, is underwater; one at or above it
/// is at the surface. Matches the buoyancy twin analyzer's surface depth.
const double kGasUseSurfaceDepthM = 1.0;

/// How long a dive's gas was breathed, and the mean depth over that time:
/// what a whole-dive SAC or RMV divides by in place of the runtime and the
/// recorded average depth.
class GasUse {
  final int seconds;

  /// Metres, time-weighted over [seconds].
  final double avgDepth;

  const GasUse({required this.seconds, required this.avgDepth});

  @override
  bool operator ==(Object other) =>
      other is GasUse && other.seconds == seconds && other.avgDepth == avgDepth;

  @override
  int get hashCode => Object.hash(seconds, avgDepth);

  @override
  String toString() => 'GasUse($seconds s, $avgDepth m)';
}

/// The [GasUse] of one recording, with where in it the window sits, in the
/// recording's own seconds.
class GasUseWindow {
  final int startSeconds;
  final int endSeconds;

  /// Metres, time-weighted from [startSeconds] to [endSeconds].
  final double avgDepth;

  const GasUseWindow({
    required this.startSeconds,
    required this.endSeconds,
    required this.avgDepth,
  });

  int get seconds => endSeconds - startSeconds;

  GasUse get use => GasUse(seconds: seconds, avgDepth: avgDepth);
}

/// The window of [samples] from the end of the leading surface run to the
/// start of the trailing one, or null when there is nothing to leave out.
///
/// The window opens at the sample just before the first one deeper than
/// [kGasUseSurfaceDepthM], where the descent starts, and closes at the sample
/// just after the last one, where the ascent ends. Only the two ends are
/// trimmed: a surface interval in the middle of the dive stays in. Null with
/// fewer than two samples, with none underwater, or when the window would be
/// the whole recording, so a dive with no surface time keeps exactly the rate
/// it has today.
///
/// [surfaceBreathing] stretches the window back over surface time a cylinder
/// was breathed in (see `surfaceBreathingOf`): to the sample at or before its
/// `from`, and to the sample at or after its `until`. It never shrinks it.
GasUseWindow? gasUseWindowOf<T>(
  Iterable<T> samples, {
  required int Function(T sample) time,
  required double Function(T sample) depth,
  SurfaceBreathing? surfaceBreathing,
}) {
  final ordered = [for (final s in samples) (t: time(s), d: depth(s))]
    ..sort((a, b) => a.t.compareTo(b.t));
  if (ordered.length < 2) return null;

  final first = ordered.indexWhere((s) => s.d > kGasUseSurfaceDepthM);
  if (first < 0) return null;
  final last = ordered.lastIndexWhere((s) => s.d > kGasUseSurfaceDepthM);

  var startIndex = first > 0 ? first - 1 : first;
  var endIndex = last < ordered.length - 1 ? last + 1 : last;
  final from = surfaceBreathing?.from;
  if (from != null) {
    final at = ordered.lastIndexWhere((s) => s.t <= from);
    startIndex = math.min(startIndex, math.max(at, 0));
  }
  final until = surfaceBreathing?.until;
  if (until != null) {
    final at = ordered.indexWhere((s) => s.t >= until);
    endIndex = math.max(endIndex, at < 0 ? ordered.length - 1 : at);
  }
  if (startIndex == 0 && endIndex == ordered.length - 1) return null;

  final inside = ordered.sublist(startIndex, endIndex + 1);
  final avgDepth = timeWeightedMean(
    inside,
    time: (s) => s.t,
    value: (s) => s.d,
  );
  final startSeconds = inside.first.t;
  final endSeconds = inside.last.t;
  if (avgDepth == null || endSeconds <= startSeconds) return null;

  return GasUseWindow(
    startSeconds: startSeconds,
    endSeconds: endSeconds,
    avgDepth: avgDepth,
  );
}
