import 'package:submersion/core/util/wall_clock_utc.dart';

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

  /// Best-known moment the diver surfaced: the stored [exitTime], or the
  /// effective start plus [effectiveRuntime] when it is missing. Mirrors
  /// the fallback chain in `DiveRepository.getSurfaceInterval`.
  DateTime get effectiveExitTime =>
      exitTime ??
      (entryTime ?? dateTime).add(effectiveRuntime ?? Duration.zero);

  /// [effectiveExitTime] as a true instant, read in the device's zone, for
  /// measuring elapsed time against now.
  ///
  /// The start is converted before the runtime is added: added to clock
  /// digits, a runtime that spans a DST change lands an hour from the real
  /// end, and no later conversion can recover it (issue #3960).
  DateTime get effectiveExitInstant {
    final exit = exitTime;
    if (exit != null) return fromWallClockUtc(exit).toUtc();
    final start = fromWallClockUtc(entryTime ?? dateTime).toUtc();
    return start.add(effectiveRuntime ?? Duration.zero);
  }
}
