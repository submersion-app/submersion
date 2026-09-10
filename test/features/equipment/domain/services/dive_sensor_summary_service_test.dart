import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
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
}
