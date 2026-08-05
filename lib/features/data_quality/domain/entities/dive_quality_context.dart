import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

class QualitySample {
  const QualitySample({required this.t, required this.depth, this.temp});

  /// Seconds from dive start.
  final int t;
  final double depth;
  final double? temp;
}

class QualityPressureSample {
  const QualityPressureSample({required this.t, required this.bar});
  final int t;
  final double bar;
}

class QualityNeighbor {
  const QualityNeighbor({
    required this.id,
    required this.entryTime,
    this.exitTime,
    this.maxDepth,
    this.durationSeconds,
    this.computerSerial,
    this.firstSampleDepth,
    this.lastSampleDepth,
  });

  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double? maxDepth;
  final int? durationSeconds;
  final String? computerSerial;
  final double? firstSampleDepth;
  final double? lastSampleDepth;
}

/// Everything a detector may look at for one dive. Built once per dive per
/// scan; detectors are pure functions over this. All numeric series are
/// sanitized (finite values only) and sorted by timestamp.
class DiveQualityContext {
  const DiveQualityContext({
    required this.dive,
    required this.now,
    this.sources = const [],
    this.primarySamples = const [],
    this.tanks = const [],
    this.pressuresByTankId = const {},
    this.gasSwitches = const [],
    this.neighbors = const [],
  });

  final domain.Dive dive;
  final DateTime now;
  final List<DiveDataSource> sources;
  final List<QualitySample> primarySamples;
  final List<domain.DiveTank> tanks;
  final Map<String, List<QualityPressureSample>> pressuresByTankId;
  final List<GasSwitch> gasSwitches;
  final List<QualityNeighbor> neighbors;
}
