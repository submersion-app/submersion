import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';

QualityFinding f({
  required String detectorId,
  Map<String, Object?> params = const {},
  String? relatedDiveId,
}) => QualityFinding(
  id: 'f1',
  diveId: 'd1',
  relatedDiveId: relatedDiveId,
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: QualitySeverity.warning,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

void main() {
  test('clock offset maps to a pre-filled inverse time shift', () {
    final actions = repairOptionsFor(
      f(detectorId: 'clock_offset', params: {'offsetHours': 3}),
    );
    final shift = actions.whereType<TimeShiftRepair>().single;
    expect(shift.suggestedOffset, const Duration(hours: -3));
    expect(shift.offerImportWide, isTrue);
  });

  test('duplicate maps to consolidate with the pair', () {
    final actions = repairOptionsFor(
      f(detectorId: 'duplicate', relatedDiveId: 'd2'),
    );
    final c = actions.whereType<ConsolidateDuplicateRepair>().single;
    expect(c.targetDiveId, 'd1');
    expect(c.secondaryDiveId, 'd2');
  });

  test('split pair maps to combine', () {
    final actions = repairOptionsFor(
      f(detectorId: 'split_pair', relatedDiveId: 'd2'),
    );
    expect(actions.whereType<CombineSplitRepair>().single.diveIds, [
      'd1',
      'd2',
    ]);
  });

  test('maxdepth mismatch maps to recompute, not despike', () {
    final actions = repairOptionsFor(
      f(detectorId: 'depth_spike', params: {'storedMaxDepth': 40.0}),
    );
    expect(actions.whereType<RecomputeMetricsRepair>(), hasLength(1));
    expect(actions.whereType<DespikeRepair>(), isEmpty);
  });

  test('gas_mod gets navigation only (judgment repair)', () {
    final actions = repairOptionsFor(
      f(detectorId: 'gas_mod', params: {'peakPpO2': 2.25}),
    );
    expect(actions, hasLength(1));
    expect(actions.single, isA<GoToDiveRepair>());
  });

  test('every detector id yields at least one action', () {
    for (final id in [
      'clock_offset',
      'duplicate',
      'split_pair',
      'sample_gap',
      'depth_spike',
      'impossible_rate',
      'temp_anomaly',
      'pressure_anomaly',
      'gas_mod',
      'tank_assignment',
      'source_conflict',
    ]) {
      expect(
        repairOptionsFor(f(detectorId: id, relatedDiveId: 'd2')),
        isNotEmpty,
        reason: id,
      );
    }
  });

  group('clock_offset sub-branches', () {
    test('overlap offers navigation to both dives', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'clock_offset',
          params: {'overlapMinutes': 10},
          relatedDiveId: 'd2',
        ),
      );
      expect(actions.whereType<GoToDiveRepair>().map((a) => a.diveId), [
        'd1',
        'd2',
      ]);
    });

    test('overlap without related dive navigates to only the dive', () {
      final actions = repairOptionsFor(
        f(detectorId: 'clock_offset', params: {'overlapMinutes': 10}),
      );
      expect(actions.whereType<GoToDiveRepair>(), hasLength(1));
    });

    test('ancient/future entry offers a zero-offset import-wide shift', () {
      final actions = repairOptionsFor(
        f(detectorId: 'clock_offset', params: {'entryTimeMs': 0}),
      );
      final shift = actions.whereType<TimeShiftRepair>().single;
      expect(shift.suggestedOffset, Duration.zero);
      expect(shift.offerImportWide, isTrue);
    });

    test('bare clock_offset falls back to navigation', () {
      final actions = repairOptionsFor(f(detectorId: 'clock_offset'));
      expect(actions.single, isA<GoToDiveRepair>());
    });
  });

  group('pair repairs without a related dive', () {
    test('duplicate offers no consolidate when related is null', () {
      final actions = repairOptionsFor(f(detectorId: 'duplicate'));
      expect(actions.whereType<ConsolidateDuplicateRepair>(), isEmpty);
      expect(actions.whereType<GoToDiveRepair>(), hasLength(1));
    });

    test('split offers no combine when related is null', () {
      final actions = repairOptionsFor(f(detectorId: 'split_pair'));
      expect(actions.whereType<CombineSplitRepair>(), isEmpty);
    });
  });

  test('sample_gap offers fill-gaps then navigation', () {
    final actions = repairOptionsFor(f(detectorId: 'sample_gap'));
    expect(actions.first, isA<FillGapsRepair>());
    expect(actions.whereType<GoToDiveRepair>(), hasLength(1));
  });

  test('depth spike (non-mismatch) offers despike', () {
    final actions = repairOptionsFor(
      f(detectorId: 'depth_spike', params: {'depth': 60.0}),
    );
    expect(actions.first, isA<DespikeRepair>());
  });

  test('impossible_rate offers despike', () {
    final actions = repairOptionsFor(f(detectorId: 'impossible_rate'));
    expect(actions.first, isA<DespikeRepair>());
  });

  group('temp_anomaly branches', () {
    test('fahrenheit-as-kelvin offers a kelvin-scale conversion', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'temp_anomaly',
          params: {'fahrenheitAsKelvinSuspected': true},
        ),
      );
      final c = actions.whereType<ConvertTemperatureRepair>().single;
      expect(c.kelvinScale, isTrue);
    });

    test('delta jump offers temperature smoothing', () {
      final actions = repairOptionsFor(
        f(detectorId: 'temp_anomaly', params: {'deltaC': 9.0}),
      );
      expect(actions.first, isA<SmoothTemperatureRepair>());
    });

    test('scalar water temp gets navigation only', () {
      final actions = repairOptionsFor(
        f(detectorId: 'temp_anomaly', params: {'waterTempC': 60.0}),
      );
      expect(actions.single, isA<GoToDiveRepair>());
    });

    test('range anomaly offers a non-kelvin conversion', () {
      final actions = repairOptionsFor(
        f(detectorId: 'temp_anomaly', params: {'minTempC': 1.0}),
      );
      final c = actions.whereType<ConvertTemperatureRepair>().single;
      expect(c.kelvinScale, isFalse);
    });
  });

  group('pressure_anomaly branches', () {
    test('swap offers a start/end-exchanged record repair', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'pressure_anomaly',
          params: {'tankId': 't1', 'startBar': 50.0, 'endBar': 200.0},
        ),
      );
      final r = actions.whereType<SwapTankRecordPressuresRepair>().single;
      expect(r.startBar, 200.0); // exchanged
      expect(r.endBar, 50.0);
    });

    test('endpoint mismatch offers set-from-series with the endpoint', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'pressure_anomaly',
          params: {
            'tankId': 't1',
            'recordBar': 210.0,
            'seriesBar': 190.0,
            'endpoint': 'end',
          },
        ),
      );
      final r = actions.whereType<SetTankRecordFromSeriesRepair>().single;
      expect(r.seriesBar, 190.0);
      expect(r.endpoint, 'end');
    });

    test('endpoint mismatch defaults endpoint to start', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'pressure_anomaly',
          params: {'tankId': 't1', 'recordBar': 210.0, 'seriesBar': 190.0},
        ),
      );
      expect(
        actions.whereType<SetTankRecordFromSeriesRepair>().single.endpoint,
        'start',
      );
    });

    test('rise (no tankId) gets navigation only', () {
      final actions = repairOptionsFor(
        f(detectorId: 'pressure_anomaly', params: {'riseBar': 15.0}),
      );
      expect(actions.single, isA<GoToDiveRepair>());
    });
  });

  group('tank_assignment branches', () {
    test('twin tanks offer swap and reassign', () {
      final actions = repairOptionsFor(
        f(
          detectorId: 'tank_assignment',
          params: {'tankIdA': 'a', 'tankIdB': 'b'},
        ),
      );
      expect(actions.whereType<SwapPressureSeriesRepair>(), hasLength(1));
      expect(actions.whereType<ReassignPressureSeriesRepair>(), hasLength(1));
    });

    test('single-tank drop offers reassign then navigation', () {
      final actions = repairOptionsFor(
        f(detectorId: 'tank_assignment', params: {'tankId': 't1'}),
      );
      expect(actions.first, isA<ReassignPressureSeriesRepair>());
      expect(actions.whereType<GoToDiveRepair>(), hasLength(1));
    });

    test('tank_assignment without ids gets navigation only', () {
      final actions = repairOptionsFor(f(detectorId: 'tank_assignment'));
      expect(actions.single, isA<GoToDiveRepair>());
    });
  });

  group('source_conflict branches', () {
    test('with a source id offers set-primary, split, and compare', () {
      final actions = repairOptionsFor(
        f(detectorId: 'source_conflict', params: {'sourceId': 's1'}),
      );
      expect(actions.whereType<SetPrimarySourceRepair>(), hasLength(1));
      expect(actions.whereType<SplitSourceRepair>(), hasLength(1));
      expect(actions.whereType<CompareSourcesRepair>(), hasLength(1));
    });

    test('without a source id gets navigation only', () {
      final actions = repairOptionsFor(f(detectorId: 'source_conflict'));
      expect(actions.single, isA<GoToDiveRepair>());
    });
  });

  test('unknown detector id falls back to navigation', () {
    final actions = repairOptionsFor(f(detectorId: 'mystery'));
    expect(actions.single, isA<GoToDiveRepair>());
  });
}
