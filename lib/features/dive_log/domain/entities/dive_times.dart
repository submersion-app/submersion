/// Times-only projection of a dive row, used by the analysis lookback
/// chains and surface-interval math so they never hydrate full [Dive]
/// object graphs (large-DB performance program, WS2).
///
/// [effectiveRuntime] mirrors `Dive.effectiveRuntime` exactly; the
/// profile-derived fallback is carried as [profileSpan]
/// (MAX(timestamp) - MIN(timestamp) of the dive's profile samples, null
/// unless positive, matching `Dive.calculateRuntimeFromProfile`).
class DiveTimes {
  final String id;
  final DateTime dateTime;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final Duration? runtime;
  final Duration? bottomTime;
  final Duration? profileSpan;

  const DiveTimes({
    required this.id,
    required this.dateTime,
    this.entryTime,
    this.exitTime,
    this.runtime,
    this.bottomTime,
    this.profileSpan,
  });

  /// Same resolution order as `Dive.effectiveRuntime`:
  /// runtime, then exit - entry, then profile span, then bottom time.
  Duration? get effectiveRuntime {
    if (runtime != null) return runtime;

    if (entryTime != null && exitTime != null) {
      final computed = exitTime!.difference(entryTime!);
      if (!computed.isNegative && computed > Duration.zero) return computed;
    }

    if (profileSpan != null) return profileSpan;

    return bottomTime;
  }
}
