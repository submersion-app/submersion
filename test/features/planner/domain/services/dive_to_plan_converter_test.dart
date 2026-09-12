import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/services/dive_to_plan_converter.dart';

DivePlanState _defaults() {
  final now = DateTime.now();
  return DivePlanState(
    id: 'template',
    name: 'template',
    segments: const [],
    tanks: [
      const DiveTank(
        id: 'default-tank',
        name: 'Primary',
        volume: 11.1,
        workingPressure: 207,
        startPressure: 200,
        gasMix: GasMix(o2: 21, he: 0),
        role: TankRole.backGas,
        order: 0,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

Dive _dive({
  required List<DiveProfilePoint> profile,
  List<DiveTank> tanks = const [],
  WaterType? waterType,
  double? altitude,
}) {
  return Dive(
    id: 'dive-1',
    dateTime: DateTime(2026, 1, 1, 9),
    profile: profile,
    tanks: tanks,
    waterType: waterType,
    altitude: altitude,
  );
}

List<DiveProfilePoint> _squareProfile({
  int descentSeconds = 120,
  int bottomSeconds = 1200,
  double depth = 30,
  int ascentSeconds = 300,
  int stepSeconds = 10,
}) {
  final points = <DiveProfilePoint>[];
  var t = 0;
  // Descent.
  for (; t <= descentSeconds; t += stepSeconds) {
    points.add(
      DiveProfilePoint(timestamp: t, depth: depth * t / descentSeconds),
    );
  }
  // Bottom.
  final bottomEnd = descentSeconds + bottomSeconds;
  for (; t <= bottomEnd; t += stepSeconds) {
    points.add(DiveProfilePoint(timestamp: t, depth: depth));
  }
  // Ascent to surface (with no explicit deco modelling here).
  final ascentEnd = bottomEnd + ascentSeconds;
  for (; t <= ascentEnd; t += stepSeconds) {
    final frac = (t - bottomEnd) / ascentSeconds;
    points.add(DiveProfilePoint(timestamp: t, depth: depth * (1 - frac)));
  }
  return points;
}

List<DiveProfilePoint> _multilevelProfile() {
  final points = <DiveProfilePoint>[];
  var t = 0;
  void ramp(int seconds, double fromDepth, double toDepth, int step) {
    for (var s = 0; s <= seconds; s += step) {
      final frac = s / seconds;
      points.add(
        DiveProfilePoint(
          timestamp: t + s,
          depth: fromDepth + (toDepth - fromDepth) * frac,
        ),
      );
    }
    t += seconds;
  }

  ramp(120, 0, 40, 10); // descent to 40m
  ramp(600, 40, 40, 10); // level 1: 10 min at 40m
  ramp(60, 40, 25, 10); // up to 25m
  ramp(600, 25, 25, 10); // level 2: 10 min at 25m
  ramp(60, 25, 12, 10); // up to 12m
  ramp(900, 12, 12, 10); // level 3: 15 min at 12m
  ramp(300, 12, 0, 10); // ascent
  return points;
}

List<DiveProfilePoint> _sawToothProfile() {
  final base = _squareProfile(bottomSeconds: 900);
  return [
    for (final p in base)
      DiveProfilePoint(
        timestamp: p.timestamp,
        depth: p.depth + (p.timestamp % 20 == 0 ? 0.3 : -0.3),
      ),
  ];
}

void main() {
  const converter = DiveToPlanConverter();

  group('DiveToPlanConverter', () {
    DivePlanState run(
      List<DiveProfilePoint> profile,
      int levels, {
      List<DiveTank> tanks = const [],
      List<GasSwitch> switches = const [],
    }) {
      return converter.convert(
        dive: _dive(profile: profile, tanks: tanks),
        profile: profile,
        gasSwitches: switches,
        levels: levels,
        planName: 'What if',
        defaults: _defaults(),
      );
    }

    int totalSeconds(DivePlanState s) =>
        s.segments.fold(0, (sum, seg) => sum + seg.durationSeconds);

    test('level 1 authors descent and bottom, leaving the ascent to the '
        'engine', () {
      final profile = _squareProfile();
      final result = run(profile, 1);

      // Descent to 30 m over the real descent time, then the 20 min hold at
      // 30 m. No ascent leg: the planner computes ascent and deco itself.
      expect(result.segments.length, 2);
      final descent = result.segments[0];
      final bottom = result.segments[1];
      expect(descent.targetDepth, 30);
      expect(descent.durationSeconds, closeTo(120, 10));
      expect(bottom.targetDepth, 30);
      expect(bottom.durationSeconds, closeTo(1200, 60));
      expect(result.sourceDiveId, 'dive-1');
    });

    test('copies the logged dive water type and altitude onto the plan', () {
      final profile = _squareProfile();
      final result = converter.convert(
        dive: _dive(
          profile: profile,
          waterType: WaterType.fresh,
          altitude: 1500,
        ),
        profile: profile,
        gasSwitches: const [],
        levels: 1,
        planName: 'What if',
        defaults: _defaults(),
      );
      expect(result.waterType, WaterType.fresh);
      expect(result.altitude, 1500);
    });

    test('bottom time is preserved at every detail level', () {
      final profile = _squareProfile();
      for (var levels = 1; levels <= 5; levels++) {
        final result = run(profile, levels);
        // The longest hold at 30 m is the bottom time; ramps in and out of
        // the bottom are short and never target exactly 30 m for long.
        final atBottom = result.segments
            .where((s) => s.targetDepth == 30)
            .map((s) => s.durationSeconds)
            .fold(0, (a, b) => a > b ? a : b);
        expect(atBottom, closeTo(1200, 60), reason: 'levels=$levels');
        expect(result.segments.last.targetDepth, 30, reason: 'levels=$levels');
      }
    });

    test('more detail never removes segments and only adds between them', () {
      final profile = _multilevelProfile();
      var previous = 0;
      for (var levels = 1; levels <= 5; levels++) {
        final result = run(profile, levels);
        expect(result.segments.length, greaterThanOrEqualTo(previous));
        previous = result.segments.length;
        for (final seg in result.segments) {
          expect(seg.durationSeconds, greaterThanOrEqualTo(30));
        }
        // The 25 m level (over half of max depth) is a working level and is
        // kept at every detail; the 12 m level reads as a stop and is left
        // for the engine to plan.
        expect(result.segments.any((s) => s.targetDepth == 25), isTrue);
        expect(result.segments.any((s) => s.targetDepth == 12), isFalse);
        expect(result.segments.last.targetDepth, 25);
        expect(
          totalSeconds(result),
          closeTo(1380, 90),
          reason: 'levels=$levels',
        );
      }
      // Level 1: descent, bottom at 40 m, ramp to 25 m, hold at 25 m.
      expect(run(profile, 1).segments.length, 4);
    });

    test('saw-tooth noise does not explode the segment count', () {
      final result = run(_sawToothProfile(), 5);
      expect(result.segments.length, lessThanOrEqualTo(6));
    });

    test('gas switch is a milestone at every level and changes the tank', () {
      final profile = _multilevelProfile();
      const backGas = DiveTank(
        id: 'back',
        gasMix: GasMix(o2: 21, he: 0),
        role: TankRole.backGas,
        order: 0,
      );
      const deco = DiveTank(
        id: 'deco',
        gasMix: GasMix(o2: 50, he: 0),
        role: TankRole.deco,
        order: 1,
      );
      // Switch gas on arrival at the 25 m level, timestamp 780.
      final switches = [
        GasSwitch(
          id: 'sw1',
          diveId: 'dive-1',
          timestamp: 780,
          tankId: deco.id,
          createdAt: DateTime.now(),
        ),
      ];

      for (var levels = 1; levels <= 5; levels++) {
        final result = run(
          profile,
          levels,
          tanks: [backGas, deco],
          switches: switches,
        );
        expect(result.tanks.map((t) => t.id), containsAll(['back', 'deco']));
        expect(result.segments.first.tankId, 'back');
        var elapsed = 0;
        for (final seg in result.segments) {
          expect(
            seg.tankId,
            elapsed >= 780 ? 'deco' : 'back',
            reason: 'levels=$levels elapsed=$elapsed',
          );
          elapsed += seg.durationSeconds;
        }
        expect(result.segments.any((s) => s.tankId == 'deco'), isTrue);
      }
    });

    test('breakpoints match the segments the plan is built from', () {
      final profile = _multilevelProfile();
      final points = converter.breakpoints(
        profile: profile,
        gasSwitches: const [],
        levels: 3,
      );
      final result = run(profile, 3);
      expect(points.length, result.segments.length + 1);
      expect(points.first.timeSeconds, 0);
      expect(points.first.depth, 0);
    });

    test('reuses the defaults passed in rather than inventing new ones', () {
      final defaults = _defaults().copyWith(
        gfLow: 20,
        gfHigh: 85,
        sacRate: 18.5,
        descentRate: 15,
      );
      final result = converter.convert(
        dive: _dive(profile: _squareProfile()),
        profile: _squareProfile(),
        gasSwitches: const [],
        levels: 2,
        planName: 'What if',
        defaults: defaults,
      );
      expect(result.gfLow, 20);
      expect(result.gfHigh, 85);
      expect(result.sacRate, 18.5);
      expect(result.descentRate, 15);
    });

    test(
      'usedTankIds keeps the first tank, switch targets and drained tanks',
      () {
        const back = DiveTank(id: 'back', role: TankRole.backGas, order: 0);
        const deco = DiveTank(id: 'deco', role: TankRole.deco, order: 1);
        const spare = DiveTank(
          id: 'spare',
          role: TankRole.deco,
          order: 2,
          startPressure: 200,
          endPressure: 200,
        );
        const drained = DiveTank(
          id: 'drained',
          role: TankRole.stage,
          order: 3,
          startPressure: 200,
          endPressure: 120,
        );
        final dive = _dive(
          profile: _squareProfile(),
          tanks: [back, deco, spare, drained],
        );
        final used = DiveToPlanConverter.usedTankIds(dive, [
          GasSwitch(
            id: 'sw',
            diveId: dive.id,
            timestamp: 600,
            tankId: 'deco',
            createdAt: DateTime.now(),
          ),
        ]);
        expect(used, {'back', 'deco', 'drained'});
      },
    );

    test('unused cylinders are left out and logged GF is applied', () {
      const back = DiveTank(id: 'back', role: TankRole.backGas, order: 0);
      const spare = DiveTank(
        id: 'spare',
        role: TankRole.deco,
        order: 1,
        startPressure: 200,
        endPressure: 200,
      );
      final dive = Dive(
        id: 'dive-gf',
        dateTime: DateTime(2026, 1, 1, 9),
        profile: _squareProfile(),
        tanks: const [back, spare],
        gradientFactorLow: 35,
        gradientFactorHigh: 75,
      );
      final result = converter.convert(
        dive: dive,
        profile: dive.profile,
        gasSwitches: const [],
        levels: 2,
        planName: 'Replan',
        defaults: _defaults(),
      );
      expect(result.tanks.map((t) => t.id), ['back']);
      expect(result.gfLow, 35);
      expect(result.gfHigh, 75);
    });

    test('empty profile yields no segments but still a valid plan', () {
      final result = run(const [], 3);
      expect(result.segments, isEmpty);
      expect(result.sourceDiveId, 'dive-1');
    });
  });
}
