import 'package:submersion/features/data_quality/domain/detectors/clock_offset_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/depth_spike_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/duplicate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/impossible_rate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/pressure_anomaly_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/sample_gap_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/source_conflict_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/split_pair_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/temp_anomaly_detector.dart';

const List<QualityDetector> kQualityDetectors = [
  ClockOffsetDetector(),
  DuplicateDetector(),
  SplitPairDetector(),
  SampleGapDetector(),
  DepthSpikeDetector(),
  ImpossibleRateDetector(),
  TempAnomalyDetector(),
  PressureAnomalyDetector(),
  GasModDetector(),
  TankAssignmentDetector(),
  SourceConflictDetector(),
];

Map<String, int> qualityDetectorVersions() => {
  for (final d in kQualityDetectors) d.id: d.version,
};
