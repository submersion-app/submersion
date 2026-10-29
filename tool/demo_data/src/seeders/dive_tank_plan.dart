import 'dart:math';

import 'package:submersion/core/constants/enums.dart';

import '../shape/dive_shape.dart';
import '../story/course_plan.dart';
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
/// follow the place (rental aluminium 80s on trips, the diver's own steel
/// HP100 at home), and technical and rebreather dives keep the gas plan of the real
/// dive their shape came from.
List<PlannedTank> planTanks(PlannedDive d, DiveShape shape, Random random) {
  final home = d.destination.key == 'home' || d.destination.nearHome;
  if (d.phase == StoryPhase.recreational ||
      shape.tanks.length <= 1 && d.diveMode == 'oc') {
    final nitrox =
        d.number >= nitroxDive &&
        d.targetMaxDepth <= 30 &&
        random.nextDouble() < 0.6;
    return [
      PlannedTank(
        o2: nitrox ? 32 : 21,
        he: 0,
        role: TankRole.backGas,
        volumeL: home ? 12.9 : 11.1,
        workingBar: home ? 237.3 : 207,
        startBar: home ? 227.5 : 200,
        material: home ? TankMaterial.steel : TankMaterial.aluminum,
        presetName: home ? 'hp100' : 'al80',
      ),
    ];
  }
  if (d.diveMode == 'ccr') {
    final roles = _rebreatherRoles(shape.tanks);
    return [
      for (var i = 0; i < shape.tanks.length; i++)
        PlannedTank(
          o2: shape.tanks[i].o2,
          he: shape.tanks[i].he,
          role: roles[i],
          volumeL: roles[i] == TankRole.bailout ? 7 : 3,
          workingBar: 232,
          startBar: 200,
          material: roles[i] == TankRole.bailout
              ? TankMaterial.aluminum
              : TankMaterial.steel,
        ),
      // Rebreather computers rarely log the oxygen cylinder; every
      // rebreather dive has one.
      if (!roles.contains(TankRole.oxygenSupply))
        const PlannedTank(
          o2: 100,
          he: 0,
          role: TankRole.oxygenSupply,
          volumeL: 3,
          workingBar: 232,
          startBar: 200,
          material: TankMaterial.steel,
        ),
    ];
  }
  final bottomO2 = shape.tanks.first.o2;
  // A trimix dive breathes trimix whatever the source shape carried: real
  // open-circuit trimix shapes are scarce, so deep deco shapes stand in.
  final trimix =
      d.targetMaxDepth > 45 &&
      (d.requiresCert == CertLevel.trimix || d.courseId == 'course-trimix');
  final (o2, he) = trimix
      ? (d.targetMaxDepth > 60 ? (18.0, 45.0) : (21.0, 35.0))
      : (shape.tanks.first.o2, shape.tanks.first.he);
  return [
    for (var i = 0; i < shape.tanks.length; i++)
      PlannedTank(
        o2: i == 0 ? o2 : shape.tanks[i].o2,
        he: i == 0 ? he : shape.tanks[i].he,
        role: i == 0
            ? TankRole.backGas
            : _specificRole(shape.tanks[i].role) ??
                  (shape.tanks[i].o2 > bottomO2
                      ? TankRole.deco
                      : TankRole.stage),
        volumeL: i == 0 ? 25.8 : 5.7,
        workingBar: i == 0 ? 237.3 : 207,
        startBar: i == 0 ? 227.5 : 200,
        material: i == 0 ? TankMaterial.steel : TankMaterial.aluminum,
      ),
  ];
}

/// The source's role when it says more than back gas, the label many
/// computers give every cylinder.
TankRole? _specificRole(String name) {
  final role = TankRole.values.where((r) => r.name == name).firstOrNull;
  return role == TankRole.backGas ? null : role;
}

/// A rebreather dive's cylinders: a specific source role is kept, and the
/// rest are read from the gas, as a diver would: 80 % oxygen or more is the
/// oxygen supply, the leanest other gas the diluent, anything else bailout.
List<TankRole> _rebreatherRoles(List<ShapeTank> tanks) {
  final known = [for (final t in tanks) _specificRole(t.role)];
  var needOxygen = !known.contains(TankRole.oxygenSupply);
  int? diluent;
  if (!known.contains(TankRole.diluent)) {
    for (var i = 0; i < tanks.length; i++) {
      if (known[i] != null || tanks[i].o2 >= 80) continue;
      if (diluent == null || tanks[i].o2 < tanks[diluent].o2) diluent = i;
    }
  }
  final roles = <TankRole>[];
  for (var i = 0; i < tanks.length; i++) {
    var role = known[i];
    if (role == null && i == diluent) {
      role = TankRole.diluent;
    } else if (role == null && needOxygen && tanks[i].o2 >= 80) {
      role = TankRole.oxygenSupply;
      needOxygen = false;
    }
    roles.add(role ?? TankRole.bailout);
  }
  return roles;
}
