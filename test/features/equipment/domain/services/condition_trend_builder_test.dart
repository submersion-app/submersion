import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/condition_trend_builder.dart';

/// Pure: which trend an item type gets and its per-dive series, from the
/// same samples and summaries the engine reads.
void main() {
  EquipmentExposureSample sample(String id, int day, {double? temp}) =>
      EquipmentExposureSample(
        diveId: id,
        date: DateTime.utc(2026, 1, day),
        durationSeconds: 3600,
        minTemperature: temp,
      );

  DiveSensorSummary summary(
    String id, {
    List<CellMetrics> cells = const [],
    List<TransmitterGap> gaps = const [],
    double? scrubber,
  }) => DiveSensorSummary(
    diveId: id,
    engineVersion: 1,
    sourceUpdatedAt: 0,
    computedAt: DateTime.utc(2026),
    cellMetrics: cells,
    transmitterGaps: gaps,
    scrubberConsumedMinutes: scrubber,
  );

  CellMetrics cell(int slot, double gain) =>
      CellMetrics(slot: slot, samples: 100, gainMvPerBar: gain);

  const rebreather = EquipmentItem(
    id: 'r1',
    name: 'CCR',
    type: EquipmentType.rebreather,
  );

  final samples = [sample('d1', 1), sample('d2', 2), sample('d3', 3)];
  final ccrSummaries = {
    'd1': summary('d1', cells: [cell(1, 50), cell(2, 48)], scrubber: 100),
    'd2': summary('d2', cells: [cell(1, 49), cell(2, 47)], scrubber: 110),
    'd3': summary('d3', cells: [cell(1, 47)], scrubber: 90),
  };

  test('a rebreather gets one cell gain series per slot in date order', () {
    final trend = buildConditionTrend(
      item: rebreather,
      parent: null,
      samples: samples,
      summariesByDive: ccrSummaries,
      observations: const [],
      transmitterSerials: const {},
    );
    expect(trend!.kind, ConditionTrendKind.cellGain);
    expect(trend.series.map((s) => s.slot), [1, 2]);
    expect(trend.series[0].points.map((p) => p.value), [50, 49, 47]);
    expect(trend.series[0].points.map((p) => p.diveId), ['d1', 'd2', 'd3']);
    expect(trend.series[1].points, hasLength(2));
  });

  test('a cell child gets its own slot only', () {
    final cellItem = EquipmentItem(
      id: 'c2',
      name: 'Cell 2',
      type: EquipmentType.o2Cell,
      parentEquipmentId: 'r1',
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'c2',
          key: EquipmentAttrKeys.cellSlot,
          valueNum: 2,
        ),
      ],
    );
    final trend = buildConditionTrend(
      item: cellItem,
      parent: rebreather,
      samples: samples,
      summariesByDive: ccrSummaries,
      observations: const [],
      transmitterSerials: const {},
    );
    expect(trend!.kind, ConditionTrendKind.cellGain);
    expect(trend.series.map((s) => s.slot), [2]);
    expect(trend.series.single.points.map((p) => p.value), [48, 47]);
  });

  test('a rebreather asked for scrubber minutes gets that series', () {
    final trend = buildConditionTrend(
      item: rebreather,
      parent: null,
      samples: samples,
      summariesByDive: ccrSummaries,
      observations: const [],
      transmitterSerials: const {},
      kind: ConditionTrendKind.scrubberMinutes,
    );
    expect(trend!.kind, ConditionTrendKind.scrubberMinutes);
    expect(trend.series.single.points.map((p) => p.value), [100, 110, 90]);
  });

  test('a transmitter gets the gap fraction for its own serials only', () {
    const tx = EquipmentItem(
      id: 't1',
      name: 'Tx',
      type: EquipmentType.transmitter,
    );
    final trend = buildConditionTrend(
      item: tx,
      parent: null,
      samples: [sample('d1', 1), sample('d2', 2)],
      summariesByDive: {
        'd1': summary(
          'd1',
          gaps: const [
            TransmitterGap(
              tankId: 'k1',
              transmitterSerial: 'S1',
              cadenceSeconds: 10,
              gapSeconds: 60,
              gapCount: 2,
              longestGapSeconds: 40,
              diveSeconds: 600,
            ),
            TransmitterGap(
              tankId: 'k2',
              transmitterSerial: 'S2',
              cadenceSeconds: 10,
              gapSeconds: 300,
              gapCount: 2,
              longestGapSeconds: 200,
              diveSeconds: 600,
            ),
          ],
        ),
      },
      observations: const [],
      transmitterSerials: const {'S1'},
    );
    expect(trend!.kind, ConditionTrendKind.transmitterGapFraction);
    expect(trend.series.single.points, hasLength(1));
    expect(trend.series.single.points.single.value, closeTo(0.1, 1e-9));
  });

  test('a regulator gets minimum temperature with the issue dives marked', () {
    const reg = EquipmentItem(
      id: 'reg',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    final trend = buildConditionTrend(
      item: reg,
      parent: null,
      samples: [sample('d1', 1, temp: 8), sample('d2', 2, temp: 21)],
      summariesByDive: const {},
      observations: [
        EquipmentObservation(
          id: 'o1',
          equipmentId: 'reg',
          diveId: 'd1',
          observedAt: DateTime.utc(2026, 1, 1),
          status: ObservationStatus.issue,
          issueTags: const [ObservationTag.freeFlow],
          note: '',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ],
      transmitterSerials: const {},
    );
    expect(trend!.kind, ConditionTrendKind.minTemperature);
    expect(trend.series.map((s) => s.key), ['temp', 'issues']);
    expect(trend.series[0].points.map((p) => p.value), [8, 21]);
    expect(trend.series[1].points.map((p) => p.diveId), ['d1']);
  });

  test('a mask has no trend', () {
    expect(
      buildConditionTrend(
        item: const EquipmentItem(
          id: 'm',
          name: 'Mask',
          type: EquipmentType.mask,
        ),
        parent: null,
        samples: samples,
        summariesByDive: const {},
        observations: const [],
        transmitterSerials: const {},
      ),
      isNull,
    );
  });
  test('a mask asked for minimum temperature still has no trend', () {
    // An explicit kind cannot reach a type the default would not give it.
    expect(
      buildConditionTrend(
        item: const EquipmentItem(
          id: 'm',
          name: 'Mask',
          type: EquipmentType.mask,
        ),
        parent: null,
        samples: [sample('d1', 1, temp: 8)],
        summariesByDive: const {},
        observations: const [],
        transmitterSerials: const {},
        kind: ConditionTrendKind.minTemperature,
      ),
      isNull,
    );
  });
}
