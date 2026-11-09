import 'package:equatable/equatable.dart';

/// Heart rate, recovery and sleep from Apple Health for one dive (issue
/// #637). Times are offsets from the dive's entry, so the record follows the
/// dive if its times are corrected.
class DiveHealthRecord extends Equatable {
  const DiveHealthRecord({
    required this.id,
    required this.diveId,
    this.heartRateSamples = const [],
    this.avgHeartRate,
    this.maxHeartRate,
    this.heartRateAtExit,
    this.heartRateExitPlus5,
    this.heartRateExitPlus15,
    this.overnightHrvMs,
    this.sleepBeforeMinutes,
    this.settled = false,
    required this.fetchedAt,
  });

  final String id;
  final String diveId;

  /// `[offsetSeconds, bpm]` pairs from the entry, in time order.
  final List<List<int>> heartRateSamples;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? heartRateAtExit;
  final int? heartRateExitPlus5;
  final int? heartRateExitPlus15;

  /// Mean heart rate variability (SDNN) the night before, in ms.
  final double? overnightHrvMs;

  /// Minutes asleep the night before.
  final int? sleepBeforeMinutes;

  /// Every reading the dive can have is in; nothing asks Health again.
  final bool settled;
  final DateTime fetchedAt;

  DiveHealthRecord copyWith({
    String? id,
    String? diveId,
    List<List<int>>? heartRateSamples,
    int? avgHeartRate,
    int? maxHeartRate,
    int? heartRateAtExit,
    int? heartRateExitPlus5,
    int? heartRateExitPlus15,
    double? overnightHrvMs,
    int? sleepBeforeMinutes,
    bool? settled,
    DateTime? fetchedAt,
  }) => DiveHealthRecord(
    id: id ?? this.id,
    diveId: diveId ?? this.diveId,
    heartRateSamples: heartRateSamples ?? this.heartRateSamples,
    avgHeartRate: avgHeartRate ?? this.avgHeartRate,
    maxHeartRate: maxHeartRate ?? this.maxHeartRate,
    heartRateAtExit: heartRateAtExit ?? this.heartRateAtExit,
    heartRateExitPlus5: heartRateExitPlus5 ?? this.heartRateExitPlus5,
    heartRateExitPlus15: heartRateExitPlus15 ?? this.heartRateExitPlus15,
    overnightHrvMs: overnightHrvMs ?? this.overnightHrvMs,
    sleepBeforeMinutes: sleepBeforeMinutes ?? this.sleepBeforeMinutes,
    settled: settled ?? this.settled,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diveId,
    heartRateSamples,
    avgHeartRate,
    maxHeartRate,
    heartRateAtExit,
    heartRateExitPlus5,
    heartRateExitPlus15,
    overnightHrvMs,
    sleepBeforeMinutes,
    settled,
    fetchedAt,
  ];
}
