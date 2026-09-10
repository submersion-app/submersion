import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

void main() {
  const service = DiveSensorSummaryService();
  final computedAt = DateTime.utc(2026, 9, 9, 12);

  group('extremes', () {
    test('min temperature and max depth come from the profile', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0, temperature: 18.0),
          ProfileSample(timestamp: 10, depth: 12.5, temperature: 9.5),
          ProfileSample(timestamp: 20, depth: 31.2, temperature: 4.1),
          ProfileSample(timestamp: 30, depth: 5.0),
        ],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.diveId, 'd1');
      expect(summary.engineVersion, DiveSensorSummaryService.version);
      expect(summary.sourceUpdatedAt, 7);
      expect(summary.computedAt, computedAt);
      expect(summary.maxDepth, 31.2);
      expect(summary.minTemperature, 4.1);
    });

    test('an empty profile yields null extremes and empty metrics', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.maxDepth, isNull);
      expect(summary.minTemperature, isNull);
      expect(summary.cellMetrics, isEmpty);
      expect(summary.transmitterGaps, isEmpty);
    });

    test('a profile without temperature yields a depth but no temperature', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        sourceUpdatedAt: 7,
        computedAt: computedAt,
      );
      expect(summary.maxDepth, 3.0);
      expect(summary.minTemperature, isNull);
    });
  });

  group('scrubberConsumedMinutes', () {
    test('rated minus remaining when both are present', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.oc,
          runtimeSeconds: 3600,
          durationMinutes: 180,
          remainingMinutes: 85,
        ),
        95,
      );
    });

    test('a negative difference falls through to runtime on the loop', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 5400,
          durationMinutes: 180,
          remainingMinutes: 200,
        ),
        90,
      );
    });

    test('runtime minutes for CCR and SCR dives without scrubber figures', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 4500,
        ),
        75,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.scr,
          runtimeSeconds: 600,
        ),
        10,
      );
    });

    test('null for open circuit and gauge dives without figures', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.oc,
          runtimeSeconds: 4500,
        ),
        isNull,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.gauge,
          runtimeSeconds: 4500,
        ),
        isNull,
      );
    });

    test('null on the loop when runtime is missing or zero', () {
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
        ),
        isNull,
      );
      expect(
        DiveSensorSummaryService.scrubberConsumedMinutes(
          diveMode: DiveMode.ccr,
          runtimeSeconds: 0,
        ),
        isNull,
      );
    });

    test('summarize threads the dive fields through', () {
      final summary = service.summarize(
        diveId: 'd1',
        samples: const [],
        diveMode: DiveMode.ccr,
        runtimeSeconds: 3000,
        scrubberDurationMinutes: 180,
        scrubberRemainingMinutes: 120,
        sourceUpdatedAt: 1,
        computedAt: computedAt,
      );
      expect(summary.scrubberConsumedMinutes, 60);
    });
  });

  group('cellMetrics', () {
    /// Three cells reading [c1, c2, c3] bar with optional millivolts.
    ProfileSample cells(
      int t,
      List<double?> ppO2, {
      List<int?> mv = const [null, null, null],
    }) => ProfileSample(
      timestamp: t,
      depth: 20.0,
      o2Sensor1: ppO2[0],
      o2Sensor2: ppO2[1],
      o2Sensor3: ppO2[2],
      o2SensorMv1: mv[0],
      o2SensorMv2: mv[1],
      o2SensorMv3: mv[2],
    );

    test('gain is the median of mV over ppO2, skipping low ppO2', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, null, null], mv: [50, null, null]),
        cells(10, [1.2, null, null], mv: [66, null, null]),
        cells(20, [0.7, null, null], mv: [42, null, null]),
        // Below the 0.2 bar floor: skipped even though it would read 500.
        cells(30, [0.1, null, null], mv: [50, null, null]),
        // No millivolts: counts as a sample, contributes no gain.
        cells(40, [1.0, null, null]),
      ]);
      expect(metrics, hasLength(1));
      final slot1 = metrics.single;
      expect(slot1.slot, 1);
      expect(slot1.samples, 5);
      // 50, 55, 60 -> median 55.
      expect(slot1.gainMvPerBar, closeTo(55.0, 1e-9));
      // A single slot never diverges from anything.
      expect(slot1.p95DivergenceBar, isNull);
      expect(slot1.divergenceRanges, isEmpty);
      expect(slot1.lowAtHighFraction, isNull);
    });

    test('a slot with no millivolts has a null gain but keeps its count', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, null]),
        cells(10, [1.0, 1.0, null]),
      ]);
      expect(metrics.map((m) => m.slot), [1, 2]);
      expect(metrics.first.gainMvPerBar, isNull);
      expect(metrics.first.samples, 2);
    });

    test('divergence is against the median of the slots with data', () {
      // Slot 3 reads 0.3 bar high on every sample; the median of three is
      // the middle value, so slots 1 and 2 diverge by 0 and slot 3 by 0.3.
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 100; t += 10) cells(t, [1.0, 1.0, 1.3]),
      ]);
      final bySlot = {for (final m in metrics) m.slot: m};
      expect(bySlot[1]!.p95DivergenceBar, closeTo(0.0, 1e-9));
      expect(bySlot[2]!.p95DivergenceBar, closeTo(0.0, 1e-9));
      expect(bySlot[3]!.p95DivergenceBar, closeTo(0.3, 1e-9));
    });

    test('p95 is the nearest-rank 95th percentile of |divergence|', () {
      // Slot 3 diverges by 0.02 on 19 samples and by 0.5 on one.
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 190; t += 10) cells(t, [1.0, 1.0, 1.02]),
        cells(190, [1.0, 1.0, 1.5]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      // ceil(0.95 * 20) = 19 -> the 19th sorted value, still 0.02.
      expect(slot3.p95DivergenceBar, closeTo(0.02, 1e-9));
    });

    test('a divergence run of exactly 30 seconds is stored', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.0]),
        cells(100, [1.0, 1.0, 1.15]),
        cells(110, [1.0, 1.0, 1.2]),
        cells(120, [1.0, 1.0, 1.18]),
        cells(130, [1.0, 1.0, 1.12]),
        cells(140, [1.0, 1.0, 1.0]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, hasLength(1));
      final range = slot3.divergenceRanges.single;
      expect(range.startSeconds, 100);
      expect(range.endSeconds, 130);
      expect(range.peakBar, closeTo(0.2, 1e-9));
    });

    test('a divergence run shorter than 30 seconds is not stored', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.0]),
        cells(100, [1.0, 1.0, 1.15]),
        cells(110, [1.0, 1.0, 1.2]),
        cells(120, [1.0, 1.0, 1.18]),
        cells(130, [1.0, 1.0, 1.0]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('a run is broken by a sample where the slot has no data', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, 1.0, 1.2]),
        cells(10, [1.0, 1.0, 1.2]),
        cells(20, [1.0, 1.0, null]),
        cells(30, [1.0, 1.0, 1.2]),
        cells(40, [1.0, 1.0, 1.2]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      // Two runs of 10 seconds each, neither long enough.
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('divergence at exactly 0.1 bar is not a range', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 100; t += 10) cells(t, [1.0, 1.0, 1.1]),
      ]);
      final slot3 = metrics.firstWhere((m) => m.slot == 3);
      expect(slot3.divergenceRanges, isEmpty);
    });

    test('current limiting is computed only after low-ppO2 agreement', () {
      // Slot 3 agrees at 0.7 bar, then reads 0.2 low once the loop is
      // above 1.2 bar. Median of [1.3, 1.3, 1.1] is 1.3.
      final agreed = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.72]),
        for (var t = 100; t < 140; t += 10) cells(t, [1.3, 1.3, 1.1]),
        cells(140, [1.3, 1.3, 1.3]),
      ]);
      final slot3 = agreed.firstWhere((m) => m.slot == 3);
      expect(slot3.highPpO2Samples, 5);
      expect(slot3.lowAtHighFraction, closeTo(0.8, 1e-9));
      // Slots 1 and 2 sat on the median at high ppO2.
      expect(agreed.firstWhere((m) => m.slot == 1).lowAtHighFraction, 0);

      // Same high-ppO2 behaviour, but slot 3 was already 0.1 off at low
      // ppO2: the limiting figure is withheld.
      final disagreed = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.8]),
        for (var t = 100; t < 140; t += 10) cells(t, [1.3, 1.3, 1.1]),
        cells(140, [1.3, 1.3, 1.3]),
      ]);
      expect(
        disagreed.firstWhere((m) => m.slot == 3).lowAtHighFraction,
        isNull,
      );
      expect(disagreed.firstWhere((m) => m.slot == 3).highPpO2Samples, 5);
    });

    test('no high-ppO2 samples yields a null fraction', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.7]),
      ]);
      expect(metrics.first.highPpO2Samples, 0);
      expect(metrics.first.lowAtHighFraction, isNull);
    });

    test('reading exactly 0.1 below the median is not limited', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        for (var t = 0; t < 50; t += 10) cells(t, [0.7, 0.7, 0.7]),
        for (var t = 100; t < 150; t += 10) cells(t, [1.3, 1.3, 1.2]),
      ]);
      expect(metrics.firstWhere((m) => m.slot == 3).lowAtHighFraction, 0);
    });

    test('slots the computer never reported are absent', () {
      final metrics = DiveSensorSummaryService.cellMetrics([
        cells(0, [1.0, null, 1.0]),
      ]);
      expect(metrics.map((m) => m.slot), [1, 3]);
    });
  });

  group('transmitterGaps', () {
    List<ProfileSample> depth(int endSeconds) => [
      for (var t = 0; t <= endSeconds; t += 10)
        ProfileSample(timestamp: t, depth: 20.0),
    ];

    TankSensorSeries tank(List<int> timestamps, {String id = 't1'}) =>
        TankSensorSeries(
          tankId: id,
          transmitterSerial: '180777',
          computerId: 'c1',
          samples: [
            for (final t in timestamps)
              TankPressureSample(timestamp: t, pressure: 200.0),
          ],
        );

    test('a clean series has no gaps and carries its identity', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]),
      ]);
      expect(gaps, hasLength(1));
      final gap = gaps.single;
      expect(gap.tankId, 't1');
      expect(gap.transmitterSerial, '180777');
      expect(gap.computerId, 'c1');
      expect(gap.cadenceSeconds, 10);
      expect(gap.gapSeconds, 0);
      expect(gap.gapCount, 0);
      expect(gap.longestGapSeconds, 0);
      expect(gap.diveSeconds, 100);
      expect(gap.gapFraction, 0);
    });

    test('an uncovered edge span is judged by the same threshold', () {
      // Waking 20s into a dive at a 10s cadence is the first reading
      // landing normally, not a dropout: the edge spans go through the
      // same "longer than three cadences" test as an interval, so a
      // transmitter is not charged for the moment before it started.
      final late20 = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([20, 30, 40, 50, 60, 70, 80, 90, 100]),
      ]);
      expect(late20.single.gapCount, 0);
      expect(late20.single.gapSeconds, 0);
      expect(late20.single.diveSeconds, 100);

      // Waking 40s in is past the threshold and is charged.
      final late40 = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([40, 50, 60, 70, 80, 90, 100]),
      ]);
      expect(late40.single.gapCount, 1);
      expect(late40.single.gapSeconds, 40);
    });

    test('an interval of exactly three cadences is not a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(60), [
        tank([0, 10, 20, 50, 60]),
      ]);
      expect(gaps.single.gapCount, 0);
    });

    test('an interval longer than three cadences is a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([0, 10, 20, 60, 70, 80, 90, 100]),
      ]);
      final gap = gaps.single;
      expect(gap.cadenceSeconds, 10);
      expect(gap.gapCount, 1);
      expect(gap.gapSeconds, 40);
      expect(gap.longestGapSeconds, 40);
      expect(gap.gapFraction, closeTo(0.4, 1e-9));
    });

    test('several gaps accumulate and the longest is kept', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(200), [
        tank([0, 10, 20, 60, 70, 80, 90, 100, 190, 200]),
      ]);
      final gap = gaps.single;
      expect(gap.gapCount, 2);
      expect(gap.gapSeconds, 130);
      expect(gap.longestGapSeconds, 90);
    });

    test('a series that stops while the profile continues is a gap', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(200), [
        tank([0, 10, 20, 30, 40, 50]),
      ]);
      final gap = gaps.single;
      expect(gap.diveSeconds, 200);
      expect(gap.gapCount, 1);
      expect(gap.gapSeconds, 150);
    });

    test('a series that starts late is a gap too', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([60, 70, 80, 90, 100]),
      ]);
      expect(gaps.single.gapSeconds, 60);
    });

    test('without a profile the series span is the dive span', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(const [], [
        tank([0, 10, 20, 30]),
      ]);
      expect(gaps.single.diveSeconds, 30);
      expect(gaps.single.gapCount, 0);
    });

    test('a series with fewer than two samples is skipped', () {
      final gaps = DiveSensorSummaryService.transmitterGaps(depth(100), [
        tank([50]),
        tank([0, 50, 100], id: 't2'),
      ]);
      expect(gaps.map((g) => g.tankId), ['t2']);
    });
  });

  group('percentile', () {
    // Nearest-rank, the definition the p95 divergence figure is built on:
    // the smallest value at or above which the requested share of the data
    // sits, at rank ceil(fraction * n) counting from one.
    test('takes the value at the ceiling rank, not a rounded index', () {
      expect(DiveSensorSummaryService.percentile([1, 2, 3, 4], 0.5), 2);
      expect(DiveSensorSummaryService.percentile([1, 2, 3, 4], 0.25), 1);
      expect(DiveSensorSummaryService.percentile([1, 2, 3, 4], 0.75), 3);
    });

    test('a rank that lands exactly on a value takes that value', () {
      // ceil(0.4 * 5) = 2 -> the second smallest.
      expect(DiveSensorSummaryService.percentile([5, 1, 4, 2, 3], 0.4), 2);
    });

    test('the ends clamp to the smallest and largest', () {
      expect(DiveSensorSummaryService.percentile([3, 1, 2], 0), 1);
      expect(DiveSensorSummaryService.percentile([3, 1, 2], 1), 3);
    });

    test('a single value is every percentile of itself', () {
      expect(DiveSensorSummaryService.percentile([7], 0.95), 7);
      expect(DiveSensorSummaryService.percentile([7], 0), 7);
    });

    test('p95 of twenty values is the nineteenth, sorted', () {
      // The shipped call site: 19 small readings and one large one leave
      // p95 on the small side, so a lone spike never sets the figure.
      final values = [for (var i = 0; i < 19; i++) 0.02, 0.5];
      expect(DiveSensorSummaryService.percentile(values, 0.95), 0.02);
    });
  });
}
