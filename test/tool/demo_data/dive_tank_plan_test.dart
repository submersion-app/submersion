import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

import '../../../tool/demo_data/src/seeders/dive_tank_plan.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';

PlannedDive _dive(
  StoryPhase phase,
  String mode, {
  double depth = 45,
  CertLevel? requires,
}) => PlannedDive(
  number: 250,
  start: DateTime.utc(2026, 6, 1, 9),
  phase: phase,
  wantedKinds: const {},
  siteId: 'site',
  destination: StoryPlanner.home,
  targetMaxDepth: depth,
  diveMode: mode,
  tankCount: 2,
  buddyIds: const [],
  plannedDuration: const Duration(minutes: 60),
  waterTempC: 12,
  requiresCert: requires,
);

DiveShape _shape(String mode, List<ShapeTank> tanks) => DiveShape(
  id: 'shape',
  kinds: const {},
  diveMode: mode,
  sampleIntervalSec: 10,
  samples: const [ShapeSample(t: 0, depth: 0), ShapeSample(t: 600, depth: 45)],
  tanks: tanks,
);

ShapeTank _tank(double o2, {double he = 0, String role = 'backGas'}) =>
    ShapeTank(o2: o2, he: he, role: role);

List<TankRole> _roles(StoryPhase phase, String mode, List<ShapeTank> tanks) => [
  for (final t in planTanks(_dive(phase, mode), _shape(mode, tanks), Random(1)))
    t.role,
];

void main() {
  group('rebreather cylinders mislabelled as back gas in the source', () {
    test('the oxygen and the leanest gas are told apart', () {
      expect(_roles(StoryPhase.rebreather, 'ccr', [_tank(100), _tank(21)]), [
        TankRole.oxygenSupply,
        TankRole.diluent,
      ]);
    });

    test('a third cylinder is bailout', () {
      expect(
        _roles(StoryPhase.rebreather, 'ccr', [
          _tank(21, he: 35),
          _tank(100),
          _tank(32),
        ]),
        [TankRole.diluent, TankRole.oxygenSupply, TankRole.bailout],
      );
    });

    test('a specific label from the source is kept', () {
      expect(
        _roles(StoryPhase.rebreather, 'ccr', [
          _tank(21, role: 'diluent'),
          _tank(50, role: 'bailout'),
        ]),
        [TankRole.diluent, TankRole.bailout, TankRole.oxygenSupply],
      );
    });

    test('an oxygen cylinder the source did not log is added', () {
      // Rebreather computers rarely record the oxygen cylinder, but every
      // rebreather dive has one.
      final tanks = planTanks(
        _dive(StoryPhase.rebreather, 'ccr'),
        _shape('ccr', [_tank(21, he: 35), _tank(32)]),
        Random(1),
      );

      expect(tanks.map((t) => t.role), [
        TankRole.diluent,
        TankRole.bailout,
        TankRole.oxygenSupply,
      ]);
      expect(tanks.last.o2, 100);
      expect(tanks.last.volumeL, 3);
    });
  });

  group('open-circuit cylinders mislabelled as back gas in the source', () {
    test('a richer gas than the bottom mix is a deco bottle', () {
      expect(
        _roles(StoryPhase.technicalOc, 'oc', [
          _tank(21),
          _tank(50),
          _tank(100),
        ]),
        [TankRole.backGas, TankRole.deco, TankRole.deco],
      );
    });

    test('a gas no richer than the bottom mix is a stage', () {
      expect(_roles(StoryPhase.technicalOc, 'oc', [_tank(32), _tank(32)]), [
        TankRole.backGas,
        TankRole.stage,
      ]);
    });
  });

  group('trimix', () {
    test('a 60 m dive after the trimix card breathes trimix', () {
      final tanks = planTanks(
        _dive(
          StoryPhase.technicalOc,
          'oc',
          depth: 60,
          requires: CertLevel.trimix,
        ),
        _shape('oc', [_tank(21), _tank(50)]),
        Random(1),
      );

      expect(tanks.first.role, TankRole.backGas);
      expect(tanks.first.he, greaterThanOrEqualTo(35));
      expect(tanks.first.o2, lessThanOrEqualTo(21));
    });

    test('a 45 m deco dive without the trimix card keeps its nitrox', () {
      final tanks = planTanks(
        _dive(StoryPhase.technicalOc, 'oc', requires: CertLevel.decoProcedures),
        _shape('oc', [_tank(28), _tank(50)]),
        Random(1),
      );

      expect(tanks.first.he, 0);
    });
  });
}
