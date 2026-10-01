import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show TankPressurePoint;
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// A stored tank pressure series of [samples], given as (seconds, bar).
TankPressureSeries testTankSeries(
  String id, {
  String diveId = 'dive-1',
  required String tankId,
  String? sourceId,
  String? computerId,
  required List<(int, double)> samples,
}) {
  final list = [
    for (final (t, p) in samples) TankPressureSample(timestamp: t, pressure: p),
  ];
  return TankPressureSeries(
    id: id,
    diveId: diveId,
    tankId: tankId,
    computerId: computerId,
    sourceId: sourceId,
    summary: TankPressureSeriesSummary.of(list),
    samples: list,
    codecVersion: 1,
    createdAt: 0,
    updatedAt: 0,
  );
}

/// [byTank] as one unattributed series per tank, for a test that only
/// cares about the readings an export writes into its samples.
DiveTankPressureExport testPressureExport(
  Map<String, List<TankPressurePoint>> byTank,
) => DiveTankPressureExport(
  series: [
    for (final entry in byTank.entries)
      testTankSeries(
        'series-${entry.key}',
        tankId: entry.key,
        samples: [for (final p in entry.value) (p.timestamp, p.pressure)],
      ),
  ],
);
