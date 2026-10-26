import 'dart:math';

import 'package:submersion/core/constants/enums.dart';

import '../shape/dive_shape.dart';
import '../story/story_plan.dart';

/// One cylinder a demo dive is breathed from.
class PlannedTank {
  const PlannedTank({
    required this.o2,
    required this.he,
    required this.role,
    required this.volumeL,
    required this.workingBar,
    required this.startBar,
    required this.material,
    this.presetName,
  });

  final double o2;
  final double he;
  final TankRole role;
  final double volumeL;
  final double workingBar;
  final double startBar;
  final TankMaterial material;
  final String? presetName;

  /// Maximum operating depth at ppO2 1.6, in metres.
  double get modMeters => (1.6 / (o2 / 100) - 1) * 10;
}

/// Chooses a dive's cylinders: the gases follow the diver's certifications
/// (air until the nitrox card, then nitrox on shallower dives), the sizes
/// follow the place (rental aluminium on trips, the diver's own steel at
/// home), and technical and rebreather dives keep the gas plan of the real
/// dive their shape came from.
List<PlannedTank> planTanks(PlannedDive d, DiveShape shape, Random random) {
  final home = d.destination.key == 'home';
  if (d.phase == StoryPhase.recreational ||
      shape.tanks.length <= 1 && d.diveMode == 'oc') {
    final nitrox =
        d.number >= 30 && d.targetMaxDepth <= 30 && random.nextDouble() < 0.6;
    return [
      PlannedTank(
        o2: nitrox ? 32 : 21,
        he: 0,
        role: TankRole.backGas,
        volumeL: home ? 12 : 11.1,
        workingBar: home ? 232 : 207,
        startBar: home ? 220 : 200,
        material: home ? TankMaterial.steel : TankMaterial.aluminum,
        presetName: home ? null : 'al80',
      ),
    ];
  }
  if (d.diveMode == 'ccr') {
    return [
      for (final t in shape.tanks)
        PlannedTank(
          o2: t.o2,
          he: t.he,
          role: _role(t.role),
          volumeL: t.role == 'bailout' ? 7 : 3,
          workingBar: 232,
          startBar: 200,
          material: t.role == 'bailout'
              ? TankMaterial.aluminum
              : TankMaterial.steel,
        ),
    ];
  }
  return [
    for (var i = 0; i < shape.tanks.length; i++)
      PlannedTank(
        o2: shape.tanks[i].o2,
        he: shape.tanks[i].he,
        role: i == 0
            ? TankRole.backGas
            : _role(shape.tanks[i].role, fallback: TankRole.deco),
        volumeL: i == 0 ? 24 : 7,
        workingBar: i == 0 ? 232 : 207,
        startBar: i == 0 ? 220 : 200,
        material: i == 0 ? TankMaterial.steel : TankMaterial.aluminum,
      ),
  ];
}

TankRole _role(String name, {TankRole fallback = TankRole.backGas}) =>
    TankRole.values.where((r) => r.name == name).firstOrNull ?? fallback;
