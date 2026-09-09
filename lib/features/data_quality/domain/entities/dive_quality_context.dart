import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
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
    this.sampleCount,
  });

  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double? maxDepth;
  final int? durationSeconds;
  final String? computerSerial;
  final double? firstSampleDepth;
  final double? lastSampleDepth;

  /// Samples stored across the neighbor's primary series, from the same
  /// column [DiveQualityContext.primarySampleCount] reads, so the two sides
  /// of a pair are compared on one measure. Null when unknown.
  final int? sampleCount;
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
    this.primarySampleCount,
    this.tanks = const [],
    this.pressuresByTankId = const {},
    this.gasSwitches = const [],
    this.neighbors = const [],
    this.ppO2MaxBar = QualityThresholds.ppO2WarnBar,
    this.knownTransmitterSerials = const {},
  });

  final domain.Dive dive;
  final DateTime now;
  final List<DiveDataSource> sources;
  final List<QualitySample> primarySamples;

  /// Samples stored across the dive's primary series, as the series report
  /// them. Deliberately not `primarySamples.length`: that list is sanitized
  /// and merged, and a neighbor's count comes straight from the stored
  /// column, so comparing the two would make a pair's richer side depend on
  /// which dive the scan happened to start from. Null when unknown.
  final int? primarySampleCount;
  final List<domain.DiveTank> tanks;
  final Map<String, List<QualityPressureSample>> pressuresByTankId;
  final List<GasSwitch> gasSwitches;
  final List<QualityNeighbor> neighbors;

  /// The diver's maximum (deco / contingency) ppO2 ceiling in bar, from
  /// decompression settings. Detectors treat a recorded gas/depth combination
  /// as suspect above this, and genuinely wrong further above it. Defaults to
  /// [QualityThresholds.ppO2WarnBar] (1.6) when settings are unavailable.
  final double ppO2MaxBar;

  /// Normalized serials of the diver's registered transmitters (issue #1365),
  /// so a detector can tell a downloaded tank nobody has assigned yet.
  final Set<String> knownTransmitterSerials;
}
