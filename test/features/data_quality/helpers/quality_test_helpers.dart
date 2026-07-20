import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Minimal dive for pure detector tests. If domain.Dive gains required
/// constructor parameters, extend HERE only.
domain.Dive makeTestDive({
  String id = 'd1',
  DateTime? entry,
  Duration? runtime = const Duration(minutes: 40),
  double? maxDepth = 30.0,
  double? avgDepth,
  double? waterTemp,
  String? serial,
  List<domain.DiveTank> tanks = const [],
}) => domain.Dive(
  id: id,
  dateTime: entry ?? DateTime.utc(2026, 7, 1, 10),
  entryTime: entry ?? DateTime.utc(2026, 7, 1, 10),
  runtime: runtime,
  maxDepth: maxDepth,
  avgDepth: avgDepth,
  waterTemp: waterTemp,
  diveComputerSerial: serial,
  tanks: tanks,
);

DiveQualityContext makeContext({
  required domain.Dive dive,
  DateTime? now,
  List<DiveDataSource> sources = const [],
  List<QualitySample> samples = const [],
  Map<String, List<QualityPressureSample>> pressures = const {},
  List<QualityNeighbor> neighbors = const [],
  List<GasSwitch> gasSwitches = const [],
}) => DiveQualityContext(
  dive: dive,
  now: now ?? DateTime.utc(2026, 7, 17, 12),
  sources: sources,
  primarySamples: samples,
  tanks: dive.tanks,
  pressuresByTankId: pressures,
  gasSwitches: gasSwitches,
  neighbors: neighbors,
);

/// Descend to [depth] at t=0..60, hold, surface in the last minute.
/// Interval fixed at 10 s.
List<QualitySample> flatProfile({
  double depth = 30,
  int durationSeconds = 2400,
  double? temp,
}) => [
  for (var t = 0; t <= durationSeconds; t += 10)
    QualitySample(
      t: t,
      depth: t < 60
          ? depth * (t / 60)
          : (t > durationSeconds - 60
                ? depth * ((durationSeconds - t) / 60)
                : depth),
      temp: temp,
    ),
];
