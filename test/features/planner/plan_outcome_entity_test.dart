import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

void main() {
  group('PlanIssue', () {
    test('equality tracks all props', () {
      const a = PlanIssue(
        type: PlanIssueType.ppO2High,
        severity: PlanIssueSeverity.warning,
        message: 'high',
        atRuntime: 120,
        atDepth: 40,
        segmentId: 's1',
        value: 1.5,
        threshold: 1.4,
      );
      const b = PlanIssue(
        type: PlanIssueType.ppO2High,
        severity: PlanIssueSeverity.warning,
        message: 'high',
        atRuntime: 120,
        atDepth: 40,
        segmentId: 's1',
        value: 1.5,
        threshold: 1.4,
      );
      expect(a, equals(b));
      expect(a.props, hasLength(8));
      expect(
        a,
        isNot(
          equals(
            const PlanIssue(
              type: PlanIssueType.gasOut,
              severity: PlanIssueSeverity.critical,
              message: 'out',
            ),
          ),
        ),
      );
    });
  });

  group('PlanStop', () {
    test('carries gas and arrival, equality tracks props', () {
      const stop = PlanStop(
        depthMeters: 6,
        durationSeconds: 600,
        airBreakSeconds: 120,
        gasFO2: 1.0,
        gasFHe: 0.0,
        tankId: 't-o2',
        arrivalRuntimeSeconds: 1800,
      );
      expect(stop.props, hasLength(7));
      expect(
        stop,
        equals(
          const PlanStop(
            depthMeters: 6,
            durationSeconds: 600,
            airBreakSeconds: 120,
            gasFO2: 1.0,
            gasFHe: 0.0,
            tankId: 't-o2',
            arrivalRuntimeSeconds: 1800,
          ),
        ),
      );
    });
  });

  group('SegmentOutcome', () {
    test('inDeco is true only for a negative NDL', () {
      SegmentOutcome make(int ndl) => SegmentOutcome(
        segmentId: 's1',
        startRuntime: 0,
        endRuntime: 600,
        ndlAtEnd: ndl,
        ceilingAtEnd: 0,
        ttsAtEnd: 0,
        cns: 1,
        otu: 1,
        maxPpO2: 1.2,
      );
      expect(make(-1).inDeco, isTrue);
      expect(make(300).inDeco, isFalse);
      expect(make(300).props, hasLength(9));
    });
  });

  group('PlanTankUsage', () {
    test('defaults and equality', () {
      const usage = PlanTankUsage(
        tankId: 't1',
        litersUsed: 1200,
        percentUsed: 60,
      );
      expect(usage.remainingPressure, isNull);
      expect(usage.reserveViolation, isFalse);
      expect(usage.turnPressureBar, isNull);
      expect(usage.minGasBar, isNull);
      expect(usage.props, hasLength(7));
    });
  });

  group('PlanOutcome', () {
    PlanOutcome make(List<PlanIssue> issues, List<PlanStop> stops) {
      return PlanOutcome(
        runtimeSeconds: 3000,
        maxDepth: 45,
        ndlAtBottom: -1,
        ttsAtBottom: 1200,
        stops: stops,
        segmentOutcomes: const [],
        tankUsages: const [],
        cnsEnd: 20,
        otuTotal: 30,
        issues: issues,
        endTissue: const BuhlmannState(compartments: []),
        tissueTimeline: const [],
      );
    }

    test('isDiveable is false when a critical issue is present', () {
      final diveable = make(const [
        PlanIssue(
          type: PlanIssueType.ppO2High,
          severity: PlanIssueSeverity.warning,
          message: 'w',
        ),
      ], const []);
      expect(diveable.isDiveable, isTrue);

      final blocked = make(const [
        PlanIssue(
          type: PlanIssueType.gasOut,
          severity: PlanIssueSeverity.critical,
          message: 'c',
        ),
      ], const []);
      expect(blocked.isDiveable, isFalse);
    });

    test('totalDecoSeconds sums stop durations', () {
      final outcome = make(const [], const [
        PlanStop(
          depthMeters: 6,
          durationSeconds: 600,
          gasFO2: 1.0,
          gasFHe: 0.0,
          arrivalRuntimeSeconds: 1500,
        ),
        PlanStop(
          depthMeters: 3,
          durationSeconds: 300,
          gasFO2: 1.0,
          gasFHe: 0.0,
          arrivalRuntimeSeconds: 2100,
        ),
      ]);
      expect(outcome.totalDecoSeconds, 900);
    });
  });
}
