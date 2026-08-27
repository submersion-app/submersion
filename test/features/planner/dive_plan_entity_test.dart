import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

DivePlan _plan({
  double sacBottom = 15.0,
  double? sacDeco,
  double? sacStressed,
  List<PlanSegment> segments = const [],
}) {
  return DivePlan(
    id: 'p1',
    name: 'Test plan',
    gfLow: 50,
    gfHigh: 80,
    sacBottom: sacBottom,
    sacDeco: sacDeco,
    sacStressed: sacStressed,
    segments: segments,
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  group('DivePlan', () {
    test('SAC defaults derive from bottom SAC', () {
      final plan = _plan(sacBottom: 15.0);
      expect(plan.sacDecoEffective, closeTo(12.0, 1e-9));
      expect(plan.sacStressedEffective, closeTo(37.5, 1e-9));
    });

    test('explicit SAC values override the derived defaults', () {
      final plan = _plan(sacBottom: 15.0, sacDeco: 14.0, sacStressed: 40.0);
      expect(plan.sacDecoEffective, 14.0);
      expect(plan.sacStressedEffective, 40.0);
    });

    test('maxDepth spans segment start and end depths', () {
      const gas = GasMix(o2: 21);
      final plan = _plan(
        segments: [
          PlanSegment.descent(
            id: 's1',
            targetDepth: 42.0,
            tankId: 't1',
            gasMix: gas,
          ),
          PlanSegment.bottom(
            id: 's2',
            depth: 42.0,
            durationMinutes: 20,
            tankId: 't1',
            gasMix: gas,
          ),
        ],
      );
      expect(plan.maxDepth, 42.0);
      expect(_plan().maxDepth, 0.0);
    });

    test('copyWith clear-flags null out nullable fields', () {
      final plan = _plan().copyWith(
        airBreaks: const AirBreakPolicy(),
        surfaceInterval: const Duration(hours: 1),
        sourceDiveId: 'dive-1',
      );
      expect(plan.airBreaks, isNotNull);
      final cleared = plan.copyWith(
        clearAirBreaks: true,
        clearSurfaceInterval: true,
        clearSourceDiveId: true,
      );
      expect(cleared.airBreaks, isNull);
      expect(cleared.surfaceInterval, isNull);
      expect(cleared.sourceDiveId, isNull);
      // Untouched fields survive.
      expect(cleared.name, 'Test plan');
      expect(cleared.gfHigh, 80);
    });

    test('copyWith carries every field through', () {
      const gas = GasMix(o2: 32);
      const tank = DiveTank(id: 't1', volume: 11.1, gasMix: gas);
      final segment = PlanSegment.bottom(
        id: 's1',
        depth: 30,
        durationMinutes: 20,
        tankId: 't1',
        gasMix: gas,
      );
      final updated = _plan().copyWith(
        id: 'p2',
        name: 'Renamed',
        notes: 'notes',
        siteId: 'site-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        mode: PlanMode.ccr,
        altitude: 1500.0,
        waterType: WaterType.fresh,
        gfLow: 35,
        gfHigh: 75,
        descentRate: 20.0,
        ascentRate: 10.0,
        lastStopDepth: 6.0,
        gasSwitchStopSeconds: 60,
        airBreaks: const AirBreakPolicy(o2Seconds: 900, breakSeconds: 300),
        sacBottom: 16.0,
        sacDeco: 12.0,
        sacStressed: 40.0,
        reservePressure: 60.0,
        surfaceInterval: const Duration(hours: 2),
        sourceDiveId: 'src',
        linkedDiveId: 'link',
        setpointLow: 0.7,
        setpointHigh: 1.4,
        setpointSwitchDepth: 12.0,
        deviationDepthDelta: 6.0,
        deviationTimeMinutes: 10,
        turnPressureRule: TurnPressureRule.thirds,
        turnPressureFraction: 0.4,
        segments: [segment],
        tanks: const [tank],
      );

      expect(updated.id, 'p2');
      expect(updated.name, 'Renamed');
      expect(updated.notes, 'notes');
      expect(updated.siteId, 'site-1');
      expect(updated.createdAt, DateTime(2026, 1, 1));
      expect(updated.updatedAt, DateTime(2026, 1, 2));
      expect(updated.mode, PlanMode.ccr);
      expect(updated.altitude, 1500.0);
      expect(updated.waterType, WaterType.fresh);
      expect(updated.gfLow, 35);
      expect(updated.gfHigh, 75);
      expect(updated.descentRate, 20.0);
      expect(updated.ascentRate, 10.0);
      expect(updated.lastStopDepth, 6.0);
      expect(updated.gasSwitchStopSeconds, 60);
      expect(updated.airBreaks?.o2Seconds, 900);
      expect(updated.sacBottom, 16.0);
      expect(updated.sacDeco, 12.0);
      expect(updated.sacStressed, 40.0);
      expect(updated.reservePressure, 60.0);
      expect(updated.surfaceInterval, const Duration(hours: 2));
      expect(updated.sourceDiveId, 'src');
      expect(updated.linkedDiveId, 'link');
      expect(updated.setpointLow, 0.7);
      expect(updated.setpointHigh, 1.4);
      expect(updated.setpointSwitchDepth, 12.0);
      expect(updated.deviationDepthDelta, 6.0);
      expect(updated.deviationTimeMinutes, 10);
      expect(updated.turnPressureRule, TurnPressureRule.thirds);
      expect(updated.turnPressureFraction, 0.4);
      expect(updated.segments, [segment]);
      expect(updated.tanks, const [tank]);
    });

    test('every clear-flag nulls its field', () {
      final full = _plan().copyWith(
        siteId: 'site',
        altitude: 100,
        waterType: WaterType.salt,
        airBreaks: const AirBreakPolicy(),
        sacDeco: 12,
        sacStressed: 40,
        surfaceInterval: const Duration(hours: 1),
        sourceDiveId: 'src',
        linkedDiveId: 'link',
        setpointLow: 0.7,
        setpointHigh: 1.3,
        setpointSwitchDepth: 10,
        turnPressureRule: TurnPressureRule.halves,
        turnPressureFraction: 0.5,
      );
      final cleared = full.copyWith(
        clearSiteId: true,
        clearAltitude: true,
        clearWaterType: true,
        clearAirBreaks: true,
        clearSacDeco: true,
        clearSacStressed: true,
        clearSurfaceInterval: true,
        clearSourceDiveId: true,
        clearLinkedDiveId: true,
        clearSetpointLow: true,
        clearSetpointHigh: true,
        clearSetpointSwitchDepth: true,
        clearTurnPressureRule: true,
        clearTurnPressureFraction: true,
      );
      expect(cleared.siteId, isNull);
      expect(cleared.altitude, isNull);
      expect(cleared.waterType, isNull);
      expect(cleared.airBreaks, isNull);
      expect(cleared.sacDeco, isNull);
      expect(cleared.sacStressed, isNull);
      expect(cleared.surfaceInterval, isNull);
      expect(cleared.sourceDiveId, isNull);
      expect(cleared.linkedDiveId, isNull);
      expect(cleared.setpointLow, isNull);
      expect(cleared.setpointHigh, isNull);
      expect(cleared.setpointSwitchDepth, isNull);
      expect(cleared.turnPressureRule, isNull);
      expect(cleared.turnPressureFraction, isNull);
    });

    test('equality tracks props', () {
      expect(_plan(), equals(_plan()));
      expect(_plan().hashCode, _plan().hashCode);
      expect(_plan(sacBottom: 15.0), isNot(equals(_plan(sacBottom: 16.0))));
    });
  });

  group('DivePlanSummary', () {
    DivePlanSummary summary({String name = 'Reef'}) => DivePlanSummary(
      id: 'p1',
      name: name,
      updatedAt: DateTime(2026, 7, 5),
      maxDepth: 30,
      runtimeSeconds: 2700,
      ttsSeconds: 300,
      mode: PlanMode.oc,
    );

    test('equality tracks props', () {
      expect(summary(), equals(summary()));
      expect(summary().hashCode, summary().hashCode);
      expect(summary(), isNot(equals(summary(name: 'Wreck'))));
      expect(summary().props, hasLength(7));
    });

    test('mode defaults to open circuit', () {
      final s = DivePlanSummary(id: 'p', name: 'n', updatedAt: DateTime(2026));
      expect(s.mode, PlanMode.oc);
    });
  });
}
