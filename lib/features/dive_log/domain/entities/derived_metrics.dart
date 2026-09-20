/// What only a profile decode can answer about a dive, computed once per
/// dive version so the Explore filter can ask about it in SQL.
///
/// Pure value types: no Flutter, no database, no analysis engine, so the
/// worker isolate can build them and the filter can read them.
library;

/// The width of one SAC bucket. Five minutes is coarse enough that a single
/// breath does not move a bucket and fine enough that "after 20 minutes"
/// lands on a bucket boundary.
const int kSacBucketSeconds = 300;

enum FinalStopKind { safety, deco, none }

/// Why a metric could not be derived. A row always exists for a dive the
/// sweep has visited, so a predicate simply does not match rather than the
/// sweep revisiting the dive forever.
enum UnsupportedReason { noProfile, gaugeMode, noPressureSeries, tooShort }

enum SacTrend { rising, falling, flat }

class SacBucket {
  /// Zero-based, so bucket n covers [n * kSacBucketSeconds, (n+1) * ...).
  final int index;

  /// Bar per minute at surface pressure, matching ProfileAnalysis.sacCurve.
  final double sacBarPerMin;

  const SacBucket({required this.index, required this.sacBarPerMin});

  @override
  bool operator ==(Object other) =>
      other is SacBucket &&
      other.index == index &&
      other.sacBarPerMin == sacBarPerMin;

  @override
  int get hashCode => Object.hash(index, sacBarPerMin);

  @override
  String toString() => 'SacBucket($index, $sacBarPerMin)';
}

class DiveDerivedMetrics {
  final String diveId;
  final int engineVersion;

  /// The dive's `updated_at` this was built from. A mismatch means stale.
  final int sourceUpdatedAt;
  final int computedAt;

  final FinalStopKind finalStopKind;
  final int? finalStopStartSeconds;
  final int? finalStopDurationSeconds;
  final double? finalStopDepthStdDevMeters;
  final double? finalStopMaxExcursionMeters;

  final double? sacMeanBarPerMin;

  /// Least-squares slope of SAC against time, in bar per minute per minute.
  final double? sacSlopeBarPerMinPerMin;

  final int? runtimeSeconds;
  final UnsupportedReason? unsupportedReason;
  final List<SacBucket> sacBuckets;

  const DiveDerivedMetrics({
    required this.diveId,
    required this.engineVersion,
    required this.sourceUpdatedAt,
    required this.computedAt,
    this.finalStopKind = FinalStopKind.none,
    this.finalStopStartSeconds,
    this.finalStopDurationSeconds,
    this.finalStopDepthStdDevMeters,
    this.finalStopMaxExcursionMeters,
    this.sacMeanBarPerMin,
    this.sacSlopeBarPerMinPerMin,
    this.runtimeSeconds,
    this.unsupportedReason,
    this.sacBuckets = const [],
  });

  bool get hasSac => sacMeanBarPerMin != null && sacBuckets.isNotEmpty;

  bool get hasFinalStop => finalStopKind != FinalStopKind.none;

  /// Rising, falling or flat, judged against a band the engine treats as
  /// noise. Null when no slope could be computed.
  SacTrend? trend({double flatBand = 0.02}) {
    final slope = sacSlopeBarPerMinPerMin;
    if (slope == null) return null;
    if (slope > flatBand) return SacTrend.rising;
    if (slope < -flatBand) return SacTrend.falling;
    return SacTrend.flat;
  }
}
