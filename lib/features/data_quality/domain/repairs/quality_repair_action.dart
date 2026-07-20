import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

/// A repair option offered for a finding. Pure data; the UI/executor turn a
/// selected action into the actual write.
sealed class QualityRepairAction {
  const QualityRepairAction();
}

class TimeShiftRepair extends QualityRepairAction {
  const TimeShiftRepair({
    required this.suggestedOffset,
    this.offerImportWide = false,
  });
  final Duration suggestedOffset;
  final bool offerImportWide;
}

class ConsolidateDuplicateRepair extends QualityRepairAction {
  const ConsolidateDuplicateRepair({
    required this.targetDiveId,
    required this.secondaryDiveId,
  });
  final String targetDiveId;
  final String secondaryDiveId;
}

class CombineSplitRepair extends QualityRepairAction {
  const CombineSplitRepair(this.diveIds);
  final List<String> diveIds;
}

class SetPrimarySourceRepair extends QualityRepairAction {
  const SetPrimarySourceRepair({required this.diveId, required this.sourceId});
  final String diveId;
  final String sourceId;
}

class SplitSourceRepair extends QualityRepairAction {
  const SplitSourceRepair({required this.diveId, required this.sourceId});
  final String diveId;
  final String sourceId;
}

class DespikeRepair extends QualityRepairAction {
  const DespikeRepair(this.diveId);
  final String diveId;
}

class FillGapsRepair extends QualityRepairAction {
  const FillGapsRepair(this.diveId);
  final String diveId;
}

class SmoothTemperatureRepair extends QualityRepairAction {
  const SmoothTemperatureRepair(this.diveId);
  final String diveId;
}

class ConvertTemperatureRepair extends QualityRepairAction {
  const ConvertTemperatureRepair({
    required this.diveId,
    required this.kelvinScale,
  });
  final String diveId;
  final bool kelvinScale;
}

class RecomputeMetricsRepair extends QualityRepairAction {
  const RecomputeMetricsRepair(this.diveId);
  final String diveId;
}

class SwapTankRecordPressuresRepair extends QualityRepairAction {
  const SwapTankRecordPressuresRepair({
    required this.diveId,
    required this.tankId,
    required this.startBar,
    required this.endBar,
  });
  final String diveId;
  final String tankId;
  final double startBar;
  final double endBar;
}

class SetTankRecordFromSeriesRepair extends QualityRepairAction {
  const SetTankRecordFromSeriesRepair({
    required this.diveId,
    required this.tankId,
    required this.seriesBar,
    required this.endpoint,
  });
  final String diveId;
  final String tankId;
  final double seriesBar;
  final String endpoint; // 'start' | 'end'
}

class SwapPressureSeriesRepair extends QualityRepairAction {
  const SwapPressureSeriesRepair({
    required this.diveId,
    required this.tankIdA,
    required this.tankIdB,
  });
  final String diveId;
  final String tankIdA;
  final String tankIdB;
}

class ReassignPressureSeriesRepair extends QualityRepairAction {
  const ReassignPressureSeriesRepair({
    required this.diveId,
    required this.fromTankId,
  });
  final String diveId;
  final String fromTankId;
}

class CompareSourcesRepair extends QualityRepairAction {
  const CompareSourcesRepair(this.diveId);
  final String diveId;
}

class GoToDiveRepair extends QualityRepairAction {
  const GoToDiveRepair(this.diveId);
  final String diveId;
}

double? _num(Map<String, Object?> p, String k) => (p[k] as num?)?.toDouble();

/// Pure mapping from a finding to its offered repairs (spec's repair table).
/// Repairs automate mechanics, never judgment: information-preserving,
/// unambiguous fixes get a one-tap action; everything else explains and
/// navigates.
List<QualityRepairAction> repairOptionsFor(QualityFinding f) {
  final p = f.params;
  final diveId = f.diveId;
  final related = f.relatedDiveId;

  switch (f.detectorId) {
    case 'clock_offset':
      if (p.containsKey('offsetHours')) {
        final hours = (p['offsetHours'] as num).toInt();
        return [
          TimeShiftRepair(
            suggestedOffset: Duration(hours: -hours),
            offerImportWide: true,
          ),
          GoToDiveRepair(diveId),
        ];
      }
      if (p.containsKey('overlapMinutes')) {
        return [
          GoToDiveRepair(diveId),
          if (related != null) GoToDiveRepair(related),
        ];
      }
      if (p.containsKey('entryTimeMs')) {
        return [
          const TimeShiftRepair(
            suggestedOffset: Duration.zero,
            offerImportWide: true,
          ),
          GoToDiveRepair(diveId),
        ];
      }
      return [GoToDiveRepair(diveId)];

    case 'duplicate':
      return [
        if (related != null)
          ConsolidateDuplicateRepair(
            targetDiveId: diveId,
            secondaryDiveId: related,
          ),
        if (related != null) GoToDiveRepair(related),
        GoToDiveRepair(diveId),
      ];

    case 'split_pair':
      return [
        if (related != null) CombineSplitRepair([diveId, related]),
        GoToDiveRepair(diveId),
      ];

    case 'sample_gap':
      return [FillGapsRepair(diveId), GoToDiveRepair(diveId)];

    case 'depth_spike':
      if (p.containsKey('storedMaxDepth')) {
        return [RecomputeMetricsRepair(diveId)];
      }
      return [DespikeRepair(diveId), GoToDiveRepair(diveId)];

    case 'impossible_rate':
      return [DespikeRepair(diveId), GoToDiveRepair(diveId)];

    case 'temp_anomaly':
      if (p['fahrenheitAsKelvinSuspected'] == true) {
        return [
          ConvertTemperatureRepair(diveId: diveId, kelvinScale: true),
          GoToDiveRepair(diveId),
        ];
      }
      if (p.containsKey('deltaC')) {
        return [SmoothTemperatureRepair(diveId), GoToDiveRepair(diveId)];
      }
      if (p.containsKey('waterTempC')) {
        return [GoToDiveRepair(diveId)];
      }
      return [
        ConvertTemperatureRepair(diveId: diveId, kelvinScale: false),
        GoToDiveRepair(diveId),
      ];

    case 'pressure_anomaly':
      final tankId = p['tankId'] as String?;
      if (tankId != null &&
          p.containsKey('startBar') &&
          p.containsKey('endBar')) {
        // A swap: the corrected record has start/end exchanged.
        return [
          SwapTankRecordPressuresRepair(
            diveId: diveId,
            tankId: tankId,
            startBar: _num(p, 'endBar')!,
            endBar: _num(p, 'startBar')!,
          ),
        ];
      }
      if (tankId != null && p.containsKey('recordBar')) {
        return [
          SetTankRecordFromSeriesRepair(
            diveId: diveId,
            tankId: tankId,
            seriesBar: _num(p, 'seriesBar')!,
            endpoint: (p['endpoint'] as String?) ?? 'start',
          ),
          GoToDiveRepair(diveId),
        ];
      }
      return [GoToDiveRepair(diveId)];

    case 'gas_mod':
      return [GoToDiveRepair(diveId)];

    case 'tank_assignment':
      final a = p['tankIdA'] as String?;
      final b = p['tankIdB'] as String?;
      if (a != null && b != null) {
        return [
          SwapPressureSeriesRepair(diveId: diveId, tankIdA: a, tankIdB: b),
          ReassignPressureSeriesRepair(diveId: diveId, fromTankId: a),
        ];
      }
      final tankId = p['tankId'] as String?;
      if (tankId != null) {
        return [
          ReassignPressureSeriesRepair(diveId: diveId, fromTankId: tankId),
          GoToDiveRepair(diveId),
        ];
      }
      return [GoToDiveRepair(diveId)];

    case 'source_conflict':
      final sourceId = p['sourceId'] as String?;
      if (sourceId != null) {
        return [
          SetPrimarySourceRepair(diveId: diveId, sourceId: sourceId),
          SplitSourceRepair(diveId: diveId, sourceId: sourceId),
          CompareSourcesRepair(diveId),
        ];
      }
      return [GoToDiveRepair(diveId)];

    default:
      return [GoToDiveRepair(diveId)];
  }
}
