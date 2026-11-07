import 'package:collection/collection.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';

const Set<TankRole> _rebreatherRoles = {
  TankRole.diluent,
  TankRole.oxygenSupply,
};

/// Sorts [dive] into its base configuration and extras (issue #3421).
///
/// The base reads cylinder roles alone (issue #3374): a dive is twin
/// backmount only when a cylinder's role is Twin Set, never by a name, a
/// size or a matched pair of Back Gas rows, so a sidemount dive logged as
/// two untagged cylinders stays a single until the diver says otherwise.
///
/// A suit inflation bottle is not breathing gas (issue #4243): the dive is
/// sorted as if it were not carried, so a dive with only one has no tanks
/// and one never adds a gas. A switch naming one is dropped here, since this
/// only decides which cylinders were breathed and the bottle never was.
TankConfigurationResult classifyTankConfiguration(TankConfigurationDive dive) {
  final breathing = _breathingOnly(dive);
  return (base: _base(breathing), extras: _extras(breathing));
}

TankConfigurationDive _breathingOnly(TankConfigurationDive dive) {
  if (dive.tanks.every((t) => t.role.isBreathingGas)) return dive;
  final tanks = breathingTanks(dive.tanks);
  final ids = {for (final t in tanks) t.id};
  return TankConfigurationDive(
    diveMode: dive.diveMode,
    tanks: tanks,
    gasSwitches: [
      for (final s in dive.gasSwitches)
        if (ids.contains(s.tankId)) s,
    ],
    hasProfile: dive.hasProfile,
  );
}

TankBaseConfiguration _base(TankConfigurationDive dive) {
  final tanks = dive.tanks;
  if (dive.diveMode == DiveMode.ccr ||
      dive.diveMode == DiveMode.scr ||
      tanks.any((t) => _rebreatherRoles.contains(t.role))) {
    return TankBaseConfiguration.rebreather;
  }
  if (tanks.isEmpty) return TankBaseConfiguration.noTanks;
  if (tanks.any((t) => sidemountRoles.contains(t.role))) {
    return TankBaseConfiguration.sidemount;
  }
  if (tanks.any((t) => t.role == TankRole.twinSet)) {
    return TankBaseConfiguration.twinBackmount;
  }
  if (!tanks.any((t) => backmountRoles.contains(t.role))) {
    return TankBaseConfiguration.other;
  }
  return TankBaseConfiguration.singleBackmount;
}

Set<TankConfigurationExtra> _extras(TankConfigurationDive dive) => {
  if (dive.tanks.any((t) => t.role == TankRole.stage))
    TankConfigurationExtra.stages,
  if (dive.tanks.any((t) => t.role == TankRole.deco))
    TankConfigurationExtra.decoGas,
  if (_isMultiGas(dive)) TankConfigurationExtra.multiGas,
};

/// Two breathed open-circuit mixes that differ by more than
/// [sameGasTolerancePct]. A rebreather's diluent and oxygen are left out,
/// or every rebreather dive would count.
bool _isMultiGas(TankConfigurationDive dive) {
  final mixes = [
    for (final t in _breathed(dive))
      if (!_rebreatherRoles.contains(t.role)) t.gasMix,
  ];
  final first = mixes.firstOrNull;
  if (first == null) return false;
  return mixes.any(
    (m) =>
        (m.o2 - first.o2).abs() > sameGasTolerancePct ||
        (m.he - first.he).abs() > sameGasTolerancePct,
  );
}

/// The cylinders [dive] is known to have breathed: those with a pressure
/// drop, those a gas switch names, and the starting cylinder. A hand-logged
/// dive (no profile, no switches, no drops) breathed every cylinder it
/// lists, since nothing else says otherwise; a recorded dive with no switch
/// stayed on its starting gas.
List<DiveTank> _breathed(TankConfigurationDive dive) {
  final tanks = dive.tanks;
  if (tanks.isEmpty) return const [];
  bool dropped(DiveTank t) {
    final start = t.startPressure;
    final end = t.endPressure;
    return start != null && end != null && start > end;
  }

  final ids = {for (final t in tanks) t.id};
  final switches =
      dive.gasSwitches.where((s) => ids.contains(s.tankId)).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (!dive.hasProfile && switches.isEmpty && !tanks.any(dropped)) {
    return tanks;
  }
  final first = switches.firstOrNull;
  final startingId =
      first != null && first.timestamp <= startingSwitchGraceSeconds
      ? first.tankId
      : sacReferenceTankOf(tanks)!.id;
  final switched = {for (final s in switches) s.tankId};
  return [
    for (final t in tanks)
      if (dropped(t) || switched.contains(t.id) || t.id == startingId) t,
  ];
}
