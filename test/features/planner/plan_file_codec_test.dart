import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

domain.DivePlan _plan() {
  const air = GasMix(o2: 21, he: 0);
  const trimix = GasMix(o2: 18, he: 45);
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Codec test',
    notes: 'Some notes',
    mode: domain.PlanMode.ccr,
    altitude: 1200.0,
    waterType: WaterType.fresh,
    gfLow: 35,
    gfHigh: 75,
    descentRate: 20.0,
    ascentRate: 10.0,
    lastStopDepth: 6.0,
    gasSwitchStopSeconds: 60,
    airBreaks: const AirBreakPolicy(o2Seconds: 900, breakSeconds: 300),
    sacBottom: 16.0,
    sacDeco: 13.0,
    reservePressure: 60.0,
    setpointLow: 0.7,
    setpointHigh: 1.4,
    setpointSwitchDepth: 12.0,
    deviationDepthDelta: 6.0,
    deviationTimeMinutes: 10,
    turnPressureRule: domain.TurnPressureRule.thirds,
    tanks: const [
      DiveTank(
        id: 'tank-1',
        name: 'Diluent',
        volume: 3.0,
        startPressure: 200.0,
        gasMix: trimix,
        role: TankRole.diluent,
      ),
      DiveTank(
        id: 'tank-2',
        volume: 11.1,
        startPressure: 207.0,
        gasMix: air,
        role: TankRole.bailout,
        order: 1,
      ),
    ],
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 50.0,
        tankId: 'tank-1',
        gasMix: trimix,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 50.0,
        durationMinutes: 30,
        tankId: 'tank-1',
        gasMix: trimix,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  test('round-trip preserves every engine-relevant field', () {
    final original = _plan();
    final restored = subplanFromJson(planToSubplanJson(original));

    // Fresh identity...
    expect(restored.id, isNot(original.id));
    // ...same inputs.
    expect(restored.name, original.name);
    expect(restored.notes, original.notes);
    expect(restored.mode, original.mode);
    expect(restored.altitude, original.altitude);
    expect(restored.waterType, original.waterType);
    expect(restored.gfLow, original.gfLow);
    expect(restored.gfHigh, original.gfHigh);
    expect(restored.descentRate, original.descentRate);
    expect(restored.ascentRate, original.ascentRate);
    expect(restored.lastStopDepth, original.lastStopDepth);
    expect(restored.gasSwitchStopSeconds, original.gasSwitchStopSeconds);
    expect(restored.airBreaks?.o2Seconds, original.airBreaks?.o2Seconds);
    expect(restored.sacBottom, original.sacBottom);
    expect(restored.sacDeco, original.sacDeco);
    expect(restored.reservePressure, original.reservePressure);
    expect(restored.setpointHigh, original.setpointHigh);
    expect(restored.setpointSwitchDepth, original.setpointSwitchDepth);
    expect(restored.deviationDepthDelta, original.deviationDepthDelta);
    expect(restored.deviationTimeMinutes, original.deviationTimeMinutes);
    expect(restored.turnPressureRule, original.turnPressureRule);

    expect(restored.tanks, hasLength(2));
    expect(restored.tanks.first.gasMix, original.tanks.first.gasMix);
    expect(restored.tanks.first.role, TankRole.diluent);
    expect(restored.tanks[1].role, TankRole.bailout);

    expect(restored.segments, hasLength(2));
    expect(restored.segments[1].type, SegmentType.bottom);
    expect(restored.segments[1].durationSeconds, 30 * 60);
    // Segment tank references remap onto the regenerated tank ids.
    expect(restored.segments.first.tankId, restored.tanks.first.id);

    // The engine computes the same schedule for both.
    const engine = PlanEngine();
    final a = engine.compute(original);
    final b = engine.compute(restored);
    expect(b.ttsAtBottom, a.ttsAtBottom);
    expect(b.stops.length, a.stops.length);
  });

  test('foreign or future files are rejected', () {
    expect(() => subplanFromJson('not json'), throwsFormatException);
    expect(
      () => subplanFromJson(jsonEncode({'format': 'other', 'version': 1})),
      throwsFormatException,
    );
    expect(
      () => subplanFromJson(
        jsonEncode({
          'format': subplanFormat,
          'version': subplanVersion + 1,
          'plan': {},
        }),
      ),
      throwsFormatException,
    );
  });

  test('malformed plan bodies raise FormatException, not TypeError', () {
    // gfLow required but missing / wrong type -> cast failure becomes a
    // FormatException instead of escaping as a raw TypeError.
    expect(
      () => subplanFromJson(
        jsonEncode({
          'format': subplanFormat,
          'version': subplanVersion,
          'plan': {'name': 'x', 'gfLow': 'not-a-number', 'gfHigh': 80},
        }),
      ),
      throwsFormatException,
    );
    // Tanks is not a list.
    expect(
      () => subplanFromJson(
        jsonEncode({
          'format': subplanFormat,
          'version': subplanVersion,
          'plan': {'name': 'x', 'gfLow': 40, 'gfHigh': 80, 'tanks': 'nope'},
        }),
      ),
      throwsFormatException,
    );
  });

  test('a segment referencing an unknown tank is rejected', () {
    expect(
      () => subplanFromJson(
        jsonEncode({
          'format': subplanFormat,
          'version': subplanVersion,
          'plan': {
            'name': 'x',
            'gfLow': 40,
            'gfHigh': 80,
            'tanks': [
              {'key': 'back', 'o2': 21, 'he': 0, 'role': 'backGas', 'order': 0},
            ],
            'segments': [
              {
                'type': 'bottom',
                'startDepth': 30,
                'endDepth': 30,
                'durationSeconds': 1200,
                'tankKey': 'ghost',
                'o2': 21,
                'he': 0,
                'order': 0,
              },
            ],
          },
        }),
      ),
      throwsFormatException,
    );
  });
}
