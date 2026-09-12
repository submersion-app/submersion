import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A contiguous run where one O2 cell disagreed with the median of its
/// peers by more than the divergence threshold. Seconds are profile
/// seconds, so the chart can draw the run directly.
class DivergenceRange extends Equatable {
  final int startSeconds;
  final int endSeconds;

  /// The largest absolute divergence inside the run, in bar.
  final double peakBar;

  const DivergenceRange({
    required this.startSeconds,
    required this.endSeconds,
    required this.peakBar,
  });

  int get durationSeconds => endSeconds - startSeconds;

  /// Stored as `[start, end, peak]`, the spec's compact shape.
  List<num> toJson() => [startSeconds, endSeconds, peakBar];

  static DivergenceRange? fromJson(Object? json) {
    if (json is! List || json.length < 3) return null;
    final start = json[0];
    final end = json[1];
    final peak = json[2];
    if (start is! num || end is! num || peak is! num) return null;
    return DivergenceRange(
      startSeconds: start.toInt(),
      endSeconds: end.toInt(),
      peakBar: peak.toDouble(),
    );
  }

  @override
  List<Object?> get props => [startSeconds, endSeconds, peakBar];
}

/// What one O2 cell slot did on one dive. One entry per slot that carried
/// ppO2 data; a slot the computer never reported is absent, not zeroed.
class CellMetrics extends Equatable {
  /// 1-based slot number, matching `o2Sensor1` to `o2Sensor6`.
  final int slot;

  /// Samples with a ppO2 reading for this slot, so every sentence built
  /// from these numbers can state its n.
  final int samples;

  /// Median of mV over ppO2 for the slot's own reading, in mV per bar.
  /// Null when the profile carries no millivolts for the slot.
  final double? gainMvPerBar;

  /// 95th percentile of the absolute difference between this slot and the
  /// median of all slots with data, in bar. Null when fewer than two slots
  /// ever carried data at the same sample.
  final double? p95DivergenceBar;

  /// Samples where the median ppO2 exceeded the current-limit line.
  final int highPpO2Samples;

  /// Of [highPpO2Samples], the fraction where this slot read more than the
  /// current-limit margin below the median. Null when the slot did not
  /// agree with its peers at low ppO2 on this dive, or when there were no
  /// high-ppO2 samples, so the figure is never quoted without its basis.
  final double? lowAtHighFraction;

  final List<DivergenceRange> divergenceRanges;

  const CellMetrics({
    required this.slot,
    required this.samples,
    this.gainMvPerBar,
    this.p95DivergenceBar,
    this.highPpO2Samples = 0,
    this.lowAtHighFraction,
    this.divergenceRanges = const [],
  });

  Map<String, Object?> toJson() => {
    'slot': slot,
    'samples': samples,
    'gainMvPerBar': gainMvPerBar,
    'p95DivergenceBar': p95DivergenceBar,
    'highPpO2Samples': highPpO2Samples,
    'lowAtHighFraction': lowAtHighFraction,
    'divergenceRanges': [for (final r in divergenceRanges) r.toJson()],
  };

  static CellMetrics? fromJson(Object? json) {
    if (json is! Map) return null;
    final slot = json['slot'];
    final samples = json['samples'];
    if (slot is! num || samples is! num) return null;
    final ranges = json['divergenceRanges'];
    return CellMetrics(
      slot: slot.toInt(),
      samples: samples.toInt(),
      gainMvPerBar: _double(json['gainMvPerBar']),
      p95DivergenceBar: _double(json['p95DivergenceBar']),
      highPpO2Samples: _int(json['highPpO2Samples']),
      lowAtHighFraction: _double(json['lowAtHighFraction']),
      divergenceRanges: ranges is List
          ? [for (final r in ranges) ?DivergenceRange.fromJson(r)]
          : const [],
    );
  }

  @override
  List<Object?> get props => [
    slot,
    samples,
    gainMvPerBar,
    p95DivergenceBar,
    highPpO2Samples,
    lowAtHighFraction,
    divergenceRanges,
  ];
}

/// How reliably one tank's transmitter reported during one dive.
class TransmitterGap extends Equatable {
  final String tankId;

  /// Normalised transmitter serial from the dive tank, or null when the
  /// computer logged none. Phase 3 maps it to a transmitter item.
  final String? transmitterSerial;
  final String? computerId;

  /// Median interval between consecutive pressure samples, seconds.
  final double cadenceSeconds;

  /// Seconds inside gaps (intervals longer than three cadences, plus the
  /// spans of the profile the series never covered).
  final int gapSeconds;
  final int gapCount;
  final int longestGapSeconds;

  /// Seconds the dive spans, the denominator of [gapFraction].
  final int diveSeconds;

  const TransmitterGap({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.cadenceSeconds,
    required this.gapSeconds,
    required this.gapCount,
    required this.longestGapSeconds,
    required this.diveSeconds,
  });

  double get gapFraction => diveSeconds <= 0 ? 0 : gapSeconds / diveSeconds;

  Map<String, Object?> toJson() => {
    'tankId': tankId,
    'transmitterSerial': transmitterSerial,
    'computerId': computerId,
    'cadenceSeconds': cadenceSeconds,
    'gapSeconds': gapSeconds,
    'gapCount': gapCount,
    'longestGapSeconds': longestGapSeconds,
    'diveSeconds': diveSeconds,
  };

  static TransmitterGap? fromJson(Object? json) {
    if (json is! Map) return null;
    final tankId = json['tankId'];
    final cadence = json['cadenceSeconds'];
    if (tankId is! String || cadence is! num) return null;
    return TransmitterGap(
      tankId: tankId,
      transmitterSerial: _string(json['transmitterSerial']),
      computerId: _string(json['computerId']),
      cadenceSeconds: cadence.toDouble(),
      gapSeconds: _int(json['gapSeconds']),
      gapCount: _int(json['gapCount']),
      longestGapSeconds: _int(json['longestGapSeconds']),
      diveSeconds: _int(json['diveSeconds']),
    );
  }

  @override
  List<Object?> get props => [
    tankId,
    transmitterSerial,
    computerId,
    cadenceSeconds,
    gapSeconds,
    gapCount,
    longestGapSeconds,
    diveSeconds,
  ];
}

/// One `dive_sensor_summaries` row: everything a profile decode can tell
/// the condition engine about one dive, computed once per dive version.
class DiveSensorSummary extends Equatable {
  final String diveId;
  final int engineVersion;

  /// The dive's `updated_at` when computed. A mismatch means stale.
  final int sourceUpdatedAt;
  final DateTime computedAt;

  /// Profile minimum, Celsius. Null when the profile carries no temperature.
  final double? minTemperature;

  /// Profile maximum, metres. Null when the dive has no profile.
  final double? maxDepth;

  /// Scrubber minutes consumed on this dive; see
  /// `DiveSensorSummaryService.scrubberConsumedMinutes`.
  final double? scrubberConsumedMinutes;
  final List<CellMetrics> cellMetrics;
  final List<TransmitterGap> transmitterGaps;

  const DiveSensorSummary({
    required this.diveId,
    required this.engineVersion,
    required this.sourceUpdatedAt,
    required this.computedAt,
    this.minTemperature,
    this.maxDepth,
    this.scrubberConsumedMinutes,
    this.cellMetrics = const [],
    this.transmitterGaps = const [],
  });

  @override
  List<Object?> get props => [
    diveId,
    engineVersion,
    sourceUpdatedAt,
    computedAt,
    minTemperature,
    maxDepth,
    scrubberConsumedMinutes,
    cellMetrics,
    transmitterGaps,
  ];
}

String encodeCellMetrics(List<CellMetrics> metrics) =>
    jsonEncode([for (final m in metrics) m.toJson()]);

/// Lenient on purpose: the column defaults to `[]`, and a row written by a
/// newer build with a shape this build does not know must not throw on
/// read. Unreadable entries are dropped, not surfaced.
List<CellMetrics> decodeCellMetrics(String json) =>
    _decodeList(json, CellMetrics.fromJson);

String encodeTransmitterGaps(List<TransmitterGap> gaps) =>
    jsonEncode([for (final g in gaps) g.toJson()]);

List<TransmitterGap> decodeTransmitterGaps(String json) =>
    _decodeList(json, TransmitterGap.fromJson);

List<T> _decodeList<T>(String json, T? Function(Object?) parse) {
  if (json.isEmpty) return const [];
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return [for (final entry in raw) ?parse(entry)];
}

double? _double(Object? value) => value is num ? value.toDouble() : null;

/// Counted fields default to zero rather than throwing: a newer peer or a
/// corrupt row must not take a whole sync batch down with a TypeError.
int _int(Object? value) => value is num ? value.toInt() : 0;

String? _string(Object? value) => value is String ? value : null;
