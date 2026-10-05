import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Static inputs for the current CNS/OTU readout, captured from the diver's
/// most recent dive and the OTU totals around it.
///
/// [CnsOtuLiveService] re-derives the live CNS% from [cnsAtDiveEnd] and
/// [lastDiveEnd] on every UI tick; everything else here is a plain snapshot
/// that only changes when the dive table is written to or a day ends (see
/// `cnsOtuSnapshotProvider`).
class CnsOtuSnapshot {
  /// Which dive this readout is projected from; loaded by the page to render
  /// its hero header.
  final String lastDiveId;

  /// End of the most recent dive, wall-clock-as-UTC (the dive-time frame;
  /// see [NoFlyService.wallClockNowUtc]).
  final DateTime lastDiveEnd;

  /// That dive's own O2 exposure. [O2Exposure.cnsEnd] is the CNS% at the
  /// moment the diver surfaced, before any live decay.
  ///
  /// Null when the dive has no profile analysis (a manually logged dive with
  /// no depth samples, or an analysis that failed): its CNS% and OTU are then
  /// unknown, and the readout warns instead of implying "no load".
  final O2Exposure? exposure;

  /// OTU accrued on the calendar day of [computedAt], across every dive that
  /// reached into it (a dive crossing midnight counts only its part).
  final double dailyOtu;

  /// Rolling 7-day OTU total ending on the calendar day of [computedAt]
  /// (REPEX guideline).
  final double weeklyOtu;

  /// When [dailyOtu] and [weeklyOtu] were computed, wall-clock-as-UTC.
  final DateTime computedAt;

  const CnsOtuSnapshot({
    required this.lastDiveId,
    required this.lastDiveEnd,
    required this.exposure,
    required this.dailyOtu,
    required this.weeklyOtu,
    required this.computedAt,
  });

  /// Whether the last dive's own CNS% and OTU are known.
  bool get hasProfile => exposure != null;

  double? get cnsAtDiveEnd => exposure?.cnsEnd;

  /// [clearExposure] sets [exposure] to null, which a null argument cannot.
  CnsOtuSnapshot copyWith({
    String? lastDiveId,
    DateTime? lastDiveEnd,
    O2Exposure? exposure,
    bool clearExposure = false,
    double? dailyOtu,
    double? weeklyOtu,
    DateTime? computedAt,
  }) {
    return CnsOtuSnapshot(
      lastDiveId: lastDiveId ?? this.lastDiveId,
      lastDiveEnd: lastDiveEnd ?? this.lastDiveEnd,
      exposure: clearExposure ? null : exposure ?? this.exposure,
      dailyOtu: dailyOtu ?? this.dailyOtu,
      weeklyOtu: weeklyOtu ?? this.weeklyOtu,
      computedAt: computedAt ?? this.computedAt,
    );
  }
}
