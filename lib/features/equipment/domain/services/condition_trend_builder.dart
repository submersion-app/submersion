import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

/// The default trend kind for an item type, or null for a type with no
/// per-dive sensor story (a mask, a fin, a cylinder).
ConditionTrendKind? defaultConditionTrendKind(EquipmentType type) {
  return switch (type) {
    EquipmentType.o2Cell ||
    EquipmentType.rebreather => ConditionTrendKind.cellGain,
    EquipmentType.transmitter => ConditionTrendKind.transmitterGapFraction,
    EquipmentType.regulator ||
    EquipmentType.bcd ||
    EquipmentType.drysuit ||
    EquipmentType.light => ConditionTrendKind.minTemperature,
    _ => null,
  };
}

/// Pure. Builds the per-dive series for [item] from the same inputs the
/// condition engine reads, so the chart and the findings agree dive for
/// dive. [samples] must be in date order (the exposure query's order).
/// [kind] overrides the type's default, which lets a rebreather page ask
/// for its scrubber chart as well as its cell chart. Null when the type
/// has no trend or the kind does not apply to it.
ConditionTrend? buildConditionTrend({
  required EquipmentItem item,
  required EquipmentItem? parent,
  required List<EquipmentExposureSample> samples,
  required Map<String, DiveSensorSummary> summariesByDive,
  required List<EquipmentObservation> observations,
  required Set<String> transmitterSerials,
  ConditionTrendKind? kind,
}) {
  final resolved = kind ?? defaultConditionTrendKind(item.type);
  if (resolved == null) return null;
  return switch (resolved) {
    ConditionTrendKind.cellGain => _cellGain(item, samples, summariesByDive),
    ConditionTrendKind.scrubberMinutes => _scrubber(
      item,
      samples,
      summariesByDive,
    ),
    ConditionTrendKind.transmitterGapFraction => _gapFraction(
      item,
      samples,
      summariesByDive,
      transmitterSerials,
    ),
    // Only the types whose default it is: the other kinds check the type
    // themselves, and this one has no type of its own to check.
    ConditionTrendKind.minTemperature =>
      defaultConditionTrendKind(item.type) == ConditionTrendKind.minTemperature
          ? _minTemperature(item, samples, observations)
          : null,
  };
}

TrendDataPoint _point(EquipmentExposureSample s, double value) =>
    TrendDataPoint(date: s.date, value: value, diveId: s.diveId);

ConditionTrend? _cellGain(
  EquipmentItem item,
  List<EquipmentExposureSample> samples,
  Map<String, DiveSensorSummary> summariesByDive,
) {
  final Iterable<int> slots;
  if (item.type == EquipmentType.o2Cell) {
    final own = item.cellSlot;
    if (own == null) return null;
    slots = [own];
  } else if (item.type == EquipmentType.rebreather) {
    final seen = <int>{};
    for (final s in samples) {
      for (final c in summariesByDive[s.diveId]?.cellMetrics ?? const []) {
        seen.add(c.slot);
      }
    }
    slots = seen.toList()..sort();
  } else {
    return null;
  }
  final series = <ConditionTrendSeries>[];
  for (final slot in slots) {
    final points = <TrendDataPoint>[];
    for (final s in samples) {
      final summary = summariesByDive[s.diveId];
      if (summary == null) continue;
      for (final c in summary.cellMetrics) {
        if (c.slot == slot && c.gainMvPerBar != null) {
          points.add(_point(s, c.gainMvPerBar!));
        }
      }
    }
    series.add(
      ConditionTrendSeries(key: 'slot$slot', slot: slot, points: points),
    );
  }
  return ConditionTrend(kind: ConditionTrendKind.cellGain, series: series);
}

ConditionTrend? _scrubber(
  EquipmentItem item,
  List<EquipmentExposureSample> samples,
  Map<String, DiveSensorSummary> summariesByDive,
) {
  if (item.type != EquipmentType.rebreather) return null;
  final points = <TrendDataPoint>[
    for (final s in samples)
      if (summariesByDive[s.diveId]?.scrubberConsumedMinutes case final m?)
        _point(s, m),
  ];
  return ConditionTrend(
    kind: ConditionTrendKind.scrubberMinutes,
    series: [ConditionTrendSeries(key: 'scrubber', points: points)],
  );
}

/// The worst gap fraction on the dive among the item's own serials, the
/// same reading the transmitter rules use.
ConditionTrend? _gapFraction(
  EquipmentItem item,
  List<EquipmentExposureSample> samples,
  Map<String, DiveSensorSummary> summariesByDive,
  Set<String> transmitterSerials,
) {
  if (item.type != EquipmentType.transmitter) return null;
  final points = <TrendDataPoint>[];
  for (final s in samples) {
    final summary = summariesByDive[s.diveId];
    if (summary == null) continue;
    double? worst;
    for (final g in summary.transmitterGaps) {
      final serial = normalizeTransmitterSerial(g.transmitterSerial);
      if (serial == null || !transmitterSerials.contains(serial)) continue;
      final f = g.gapFraction;
      if (worst == null || f > worst) worst = f;
    }
    if (worst != null) points.add(_point(s, worst));
  }
  return ConditionTrend(
    kind: ConditionTrendKind.transmitterGapFraction,
    series: [ConditionTrendSeries(key: 'gap', points: points)],
  );
}

ConditionTrend _minTemperature(
  EquipmentItem item,
  List<EquipmentExposureSample> samples,
  List<EquipmentObservation> observations,
) {
  final issueDives = {
    for (final o in observations)
      if (o.status == ObservationStatus.issue && o.diveId != null) o.diveId!,
  };
  final temps = <TrendDataPoint>[];
  final issues = <TrendDataPoint>[];
  for (final s in samples) {
    final t = s.minTemperature;
    if (t == null) continue;
    final p = _point(s, t);
    temps.add(p);
    if (issueDives.contains(s.diveId)) issues.add(p);
  }
  return ConditionTrend(
    kind: ConditionTrendKind.minTemperature,
    series: [
      ConditionTrendSeries(key: 'temp', points: temps),
      ConditionTrendSeries(key: 'issues', points: issues),
    ],
  );
}
