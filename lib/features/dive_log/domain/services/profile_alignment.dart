import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// How a secondary record that does not overlap the primary in time is
/// placed on the primary's timeline when it is merged as another computer
/// (#552). Its clock cannot be trusted: that is why the records do not
/// overlap.
enum ConsolidationAlignment {
  /// Slide the secondary's depth trace to where it matches the primary's.
  bestFit,

  /// Line the two records' starts up (offset 0).
  starts,
}

/// Where [ProfileAligner] placed a secondary trace, and how well it fits.
class ProfileAlignmentResult {
  const ProfileAlignmentResult({
    required this.offsetSeconds,
    required this.rmsDepthError,
    required this.overlapFraction,
    required this.usedFallback,
    required this.isStrongMatch,
  });

  /// No usable profile on one side: the starts are lined up and nothing is
  /// scored, so the result can never suggest the records are one dive.
  const ProfileAlignmentResult.fallback()
    : offsetSeconds = 0,
      rmsDepthError = null,
      overlapFraction = 0,
      usedFallback = true,
      isStrongMatch = false;

  /// Seconds to add to the secondary's timestamps (may be negative).
  final int offsetSeconds;

  /// Root mean square depth difference, in metres, where the traces overlap.
  final double? rmsDepthError;

  /// The overlapping span as a fraction of the shorter trace, 0 to 1.
  final double overlapFraction;
  final bool usedFallback;

  /// Whether the two traces look like one dive recorded twice.
  final bool isStrongMatch;

  ProfileAlignmentResult copyWith({int? offsetSeconds}) =>
      ProfileAlignmentResult(
        offsetSeconds: offsetSeconds ?? this.offsetSeconds,
        rmsDepthError: rmsDepthError,
        overlapFraction: overlapFraction,
        usedFallback: usedFallback,
        isStrongMatch: isStrongMatch,
      );
}

class _Fit {
  const _Fit(this.shift, this.rms, this.overlap);
  final int shift;
  final double rms;
  final double overlap;
}

/// Finds the shift that best lines one dive computer's depth trace up with
/// another's.
///
/// Both profiles' timestamps count from their own record's start, so a shift
/// of 0 lines the starts up and the wall-clock difference between the two
/// computers never enters the search.
class ProfileAligner {
  const ProfileAligner();

  static const int maxWindowSeconds = 15 * 60;
  static const int gridSeconds = 5;
  static const int coarseStepSeconds = 10;
  static const double surfaceDepthMeters = 0.5;
  static const int minSubmergedSamples = 3;
  static const double strongMatchMinOverlap = 0.8;
  static const double strongMatchMinRmsMeters = 1.0;

  /// A computer set to fresh water reads about 3% deeper than one set to
  /// salt, at every depth, so the allowed error grows with depth.
  static const double strongMatchDepthFraction = 0.05;
  static const double _tieEpsilon = 1e-9;

  ProfileAlignmentResult align(
    List<DiveProfilePoint> primary,
    List<DiveProfilePoint> secondary,
  ) {
    final p = _sorted(primary);
    final s = _sorted(secondary);
    if (_submerged(p) < minSubmergedSamples ||
        _submerged(s) < minSubmergedSamples) {
      return const ProfileAlignmentResult.fallback();
    }
    final shorter = math.min(
      p.last.timestamp - p.first.timestamp,
      s.last.timestamp - s.first.timestamp,
    );
    if (shorter <= 0) return const ProfileAlignmentResult.fallback();
    // Wide enough for a computer switched on late or one that logged the
    // surface first; narrow enough that one record's descent cannot slide
    // onto the other's ascent.
    final window = math.min(shorter ~/ 2, maxWindowSeconds);

    _Fit? best;
    void consider(int shift) {
      if (shift.abs() > window) return;
      final fit = _score(p, s, shift, shorter);
      if (fit == null) return;
      final current = best;
      if (current == null ||
          fit.rms < current.rms - _tieEpsilon ||
          ((fit.rms - current.rms).abs() <= _tieEpsilon &&
              shift.abs() < current.shift.abs())) {
        best = fit;
      }
    }

    for (var k = 0; k * coarseStepSeconds <= window; k++) {
      consider(k * coarseStepSeconds);
      if (k > 0) consider(-k * coarseStepSeconds);
    }
    final coarse = best;
    if (coarse == null) return const ProfileAlignmentResult.fallback();
    for (
      var shift = coarse.shift - coarseStepSeconds;
      shift <= coarse.shift + coarseStepSeconds;
      shift++
    ) {
      consider(shift);
    }

    final fit = best!;
    final maxDepth = p.map((e) => e.depth).reduce(math.max);
    final threshold = math.max(
      strongMatchMinRmsMeters,
      strongMatchDepthFraction * maxDepth,
    );
    return ProfileAlignmentResult(
      offsetSeconds: fit.shift,
      rmsDepthError: fit.rms,
      overlapFraction: fit.overlap,
      usedFallback: false,
      isStrongMatch:
          fit.overlap >= strongMatchMinOverlap && fit.rms <= threshold,
    );
  }

  static List<DiveProfilePoint> _sorted(List<DiveProfilePoint> points) =>
      [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  static int _submerged(List<DiveProfilePoint> points) =>
      points.where((e) => e.depth > surfaceDepthMeters).length;

  /// RMS depth difference with the secondary shifted by [shift] seconds,
  /// over the span both traces cover, or null when they barely overlap.
  static _Fit? _score(
    List<DiveProfilePoint> p,
    List<DiveProfilePoint> s,
    int shift,
    int shorter,
  ) {
    final start = math.max(p.first.timestamp, s.first.timestamp + shift);
    final end = math.min(p.last.timestamp, s.last.timestamp + shift);
    if (end - start < gridSeconds) return null;
    var sum = 0.0;
    var n = 0;
    for (var t = start; t <= end; t += gridSeconds) {
      final d = _depthAt(p, t) - _depthAt(s, t - shift);
      sum += d * d;
      n++;
    }
    return _Fit(
      shift,
      math.sqrt(sum / n),
      math.min(1.0, (end - start) / shorter),
    );
  }

  /// Linear interpolation of [points] (sorted, [t] within their span).
  static double _depthAt(List<DiveProfilePoint> points, int t) {
    var lo = 0;
    var hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (points[mid].timestamp <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    if (lo >= points.length - 1) return points.last.depth;
    final a = points[lo];
    final b = points[lo + 1];
    final span = b.timestamp - a.timestamp;
    if (span <= 0) return a.depth;
    return a.depth + (b.depth - a.depth) * (t - a.timestamp) / span;
  }
}
