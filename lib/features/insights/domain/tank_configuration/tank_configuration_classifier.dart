import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';

/// A single Back Gas cylinder this large is a twin set logged as one:
/// common single cylinders top out around 18 L, while 2x10 L, 2xAL80
/// (22.2 L) and 2x12 L all reach it.
const double twinSetMinVolumeLiters = 20.0;

const Set<TankRole> _rebreatherRoles = {
  TankRole.diluent,
  TankRole.oxygenSupply,
};

final RegExp _twinWord = RegExp('twin|double|doppel|manifold');
// The 2 must start a number: "12x232" is a 12 L single by its pressure.
final RegExp _twinCount = RegExp(r'(?<![0-9.,])2\s*[x×]\s*\d');
final RegExp _twinDCode = RegExp(r'(?<![a-z0-9])d\d{1,2}(?![a-z0-9])');

/// Whether [tank] looks like a twin set logged as one cylinder: its name or
/// preset says so (twin, double, doppel, manifold, 2x12, D12), or it holds
/// [twinSetMinVolumeLiters] or more. Preset names are stored slugs such as
/// `twin_12`, so an underscore separates words.
bool looksLikeTwinSet(DiveTank tank) {
  final volume = tank.volume;
  if (volume != null && volume >= twinSetMinVolumeLiters) return true;
  return _namesTwin(tank.name) || _namesTwin(tank.presetName);
}

bool _namesTwin(String? raw) {
  if (raw == null) return false;
  final text = raw.toLowerCase().replaceAll('_', ' ');
  return _twinWord.hasMatch(text) ||
      _twinCount.hasMatch(text) ||
      _twinDCode.hasMatch(text);
}

/// Sorts [dive] into its base configuration and extras (issue #3421).
///
/// Downloads tag every open-circuit gas under 41% O2 as Back Gas, so two
/// Back Gas cylinders are a twin set only when they form a matched pair on
/// one gas ([isMatchedPair]); air plus an untagged EAN32 is a single.
TankConfigurationResult classifyTankConfiguration(TankConfigurationDive dive) =>
    (base: _base(dive), extras: _extras(dive));

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
  final backGas = tanks.where((t) => t.role == TankRole.backGas).toList();
  if (backGas.isEmpty) return TankBaseConfiguration.other;
  final pairs = backGas.indexed.any(
    (a) => backGas.skip(a.$1 + 1).any((b) => isMatchedPair(a.$2, b)),
  );
  if (pairs || backGas.any(looksLikeTwinSet)) {
    return TankBaseConfiguration.twinBackmount;
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
