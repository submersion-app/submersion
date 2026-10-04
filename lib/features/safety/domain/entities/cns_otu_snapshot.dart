import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Static inputs for the current CNS/OTU readout, captured from the diver's
/// most recent dive.
///
/// [CnsOtuLiveService] re-derives the live CNS% from [cnsAtDiveEnd] and
/// [lastDiveEnd] on every UI tick; everything else here is a plain snapshot
/// that only changes when the dive table is written to (see
/// `cnsOtuSnapshotProvider`).
class CnsOtuSnapshot {
  final String lastDiveId;

  /// End of the most recent dive, wall-clock-as-UTC (the dive-time frame;
  /// see [NoFlyService.wallClockNowUtc]).
  final DateTime lastDiveEnd;

  /// That dive's own O2 exposure. [O2Exposure.cnsEnd] is the CNS% at the
  /// moment the diver surfaced, before any live decay.
  final O2Exposure exposure;

  /// Rolling 7-day OTU total as of the most recent dive (REPEX guideline).
  final double weeklyOtu;

  const CnsOtuSnapshot({
    required this.lastDiveId,
    required this.lastDiveEnd,
    required this.exposure,
    required this.weeklyOtu,
  });

  double get cnsAtDiveEnd => exposure.cnsEnd;
}
