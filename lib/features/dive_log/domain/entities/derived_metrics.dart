/// What only a profile decode can answer about a dive, computed once per
/// dive version so the dive query fields can ask about it in SQL.
///
/// Pure value types: no Flutter, no database, no analysis engine, so the
/// worker isolate can build them.
library;

/// The width of one SAC bucket. Five minutes is coarse enough that a single
/// breath does not move a bucket and fine enough to see a trend.
const int kSacBucketSeconds = 300;

/// A slope within this many bar/min per minute of zero is steady: the
/// engine cannot tell a smaller change from noise.
const double kSacSteadyBand = 0.02;

/// A final stop that strays further than this from its median depth, in
/// metres, is unstable.
const double kFinalStopUnstableMeters = 1.0;

enum FinalStopKind { safety, deco, none }

/// How steady the final stop was. Stored by name; the dive query field
/// `finalStop` lists these names.
enum FinalStopState { stable, unstable, noStop }

/// Why a metric could not be derived. A row always exists for a dive the
/// sweep has visited, so a field is empty rather than the sweep revisiting
/// the dive forever.
enum UnsupportedReason {
  noProfile,
  gaugeMode,
  noPressureSeries,
  tooShort,

  /// A closed or semi-closed circuit dive: a diluent or oxygen bottle's
  /// pressure drop is not open-circuit gas consumption, so no SAC. The
  /// depth track still gives the final stop.
  rebreather,
}

/// Stored by name; the dive query field `sacTrend` lists these names.
enum SacTrend { rising, steady, falling }

/// One five-minute slice of SAC. Computed by the engine and used for the
/// mean, slope and change; not stored.
class SacBucket {
  /// Zero-based, so bucket n covers [n * kSacBucketSeconds, (n+1) * ...).
  final int index;

  /// Bar per minute at surface pressure.
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

  /// Percent change of mean SAC from the dive's first half to its second.
  final double? sacChangePercent;

  final int? runtimeSeconds;
  final UnsupportedReason? unsupportedReason;

  /// The engine's buckets. Empty when read back from storage.
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
    this.sacChangePercent,
    this.runtimeSeconds,
    this.unsupportedReason,
    this.sacBuckets = const [],
  });

  DiveDerivedMetrics copyWith({
    String? diveId,
    int? engineVersion,
    int? sourceUpdatedAt,
    int? computedAt,
    FinalStopKind? finalStopKind,
    int? finalStopStartSeconds,
    int? finalStopDurationSeconds,
    double? finalStopDepthStdDevMeters,
    double? finalStopMaxExcursionMeters,
    double? sacMeanBarPerMin,
    double? sacSlopeBarPerMinPerMin,
    double? sacChangePercent,
    int? runtimeSeconds,
    UnsupportedReason? unsupportedReason,
    List<SacBucket>? sacBuckets,
  }) => DiveDerivedMetrics(
    diveId: diveId ?? this.diveId,
    engineVersion: engineVersion ?? this.engineVersion,
    sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
    computedAt: computedAt ?? this.computedAt,
    finalStopKind: finalStopKind ?? this.finalStopKind,
    finalStopStartSeconds: finalStopStartSeconds ?? this.finalStopStartSeconds,
    finalStopDurationSeconds:
        finalStopDurationSeconds ?? this.finalStopDurationSeconds,
    finalStopDepthStdDevMeters:
        finalStopDepthStdDevMeters ?? this.finalStopDepthStdDevMeters,
    finalStopMaxExcursionMeters:
        finalStopMaxExcursionMeters ?? this.finalStopMaxExcursionMeters,
    sacMeanBarPerMin: sacMeanBarPerMin ?? this.sacMeanBarPerMin,
    sacSlopeBarPerMinPerMin:
        sacSlopeBarPerMinPerMin ?? this.sacSlopeBarPerMinPerMin,
    sacChangePercent: sacChangePercent ?? this.sacChangePercent,
    runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
    unsupportedReason: unsupportedReason ?? this.unsupportedReason,
    sacBuckets: sacBuckets ?? this.sacBuckets,
  );

  bool get hasSac => sacMeanBarPerMin != null;

  bool get hasFinalStop => finalStopKind != FinalStopKind.none;

  /// Rising, falling or steady against [kSacSteadyBand]. Null when no slope
  /// could be computed.
  SacTrend? get sacTrend {
    final slope = sacSlopeBarPerMinPerMin;
    if (slope == null) return null;
    if (slope > kSacSteadyBand) return SacTrend.rising;
    if (slope < -kSacSteadyBand) return SacTrend.falling;
    return SacTrend.steady;
  }

  /// Null when the profile could not be judged at all. Missing pressure
  /// data does not stop the depth track from being read, so a dive with no
  /// pressure series still gets a stop state.
  FinalStopState? get finalStopState {
    // Pressure data (missing, or a rebreather's) says nothing about the
    // depth track, so those dives still get a stop state.
    final reason = unsupportedReason;
    if (reason != null &&
        reason != UnsupportedReason.noPressureSeries &&
        reason != UnsupportedReason.rebreather) {
      return null;
    }
    if (finalStopKind == FinalStopKind.none) return FinalStopState.noStop;
    final excursion = finalStopMaxExcursionMeters ?? 0;
    return excursion > kFinalStopUnstableMeters
        ? FinalStopState.unstable
        : FinalStopState.stable;
  }
}
