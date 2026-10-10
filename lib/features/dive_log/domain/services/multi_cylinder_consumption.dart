import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Gas consumption arithmetic over every cylinder a diver breathed from
/// (issue #3109): a sidemount pair, doubles logged as independents, stages.
///
/// The SQL statistics mirror these rules in `multi_cylinder_sac_sql.dart`,
/// so a chart and the dive overview agree on one dive.

/// The two roles of a sidemount pair.
const Set<TankRole> sidemountRoles = {
  TankRole.sidemountLeft,
  TankRole.sidemountRight,
};

/// The volume of [tank] for consumption math, in liters: its own, else the
/// volume of the first other cylinder of the dive that forms a matched pair
/// with it (see [isMatchedPair]), since a pair is the same size and
/// downloads often size only one of them. Null when neither is known.
double? consumptionVolume(DiveTank tank, List<DiveTank> tanks) {
  final own = tank.volume;
  if (own != null && own > 0) return own;
  for (final other in tanks) {
    if (identical(other, tank) || !isMatchedPair(tank, other)) continue;
    final volume = other.volume;
    if (volume != null && volume > 0) return volume;
  }
  return null;
}

/// The pressure drop of [reference] plus that of every other breathed
/// cylinder of [tanks], each converted into bar of [reference] by volume
/// (`drop * V / Vref`). When either size is unknown, a cylinder of a
/// matched pair with the reference (see [isMatchedPair]) counts one to one.
/// A cylinder whose size cannot be related to the reference, or that was
/// carried but not breathed, adds nothing.
///
/// With [referenceOnly] (a rebreather dive, where diluent and oxygen
/// drops are not breathing gas in one unit) only [reference] counts.
/// Null when [reference] has no positive drop.
double? referencePressureDrop({
  required DiveTank reference,
  required List<DiveTank> tanks,
  bool referenceOnly = false,
}) {
  final referenceDrop = _drop(reference);
  if (referenceDrop == null) return null;
  if (referenceOnly) return referenceDrop;

  final referenceVolume = consumptionVolume(reference, tanks);
  var total = referenceDrop;
  for (final tank in tanks) {
    if (identical(tank, reference)) continue;
    final drop = _drop(tank);
    if (drop == null) continue;
    final volume = consumptionVolume(tank, tanks);
    if (volume != null && referenceVolume != null) {
      total += drop * volume / referenceVolume;
    } else if (isMatchedPair(tank, reference)) {
      total += drop;
    }
  }
  return total;
}

/// Whether [a] and [b] are a matched pair, assumed the same size when a
/// size is missing: both sidemount cylinders, or both back gas on the same
/// gas (doubles logged as independents). The gas matters for back gas
/// because downloads default an untagged cylinder, a deco stage included,
/// to that role.
bool isMatchedPair(DiveTank a, DiveTank b) =>
    (sidemountRoles.contains(a.role) && sidemountRoles.contains(b.role)) ||
    (a.role == TankRole.backGas &&
        b.role == TankRole.backGas &&
        a.gasMix.roundedO2 == b.gasMix.roundedO2 &&
        a.gasMix.roundedHe == b.gasMix.roundedHe);

double? _drop(DiveTank tank) {
  final start = tank.startPressure;
  final end = tank.endPressure;
  if (start == null || end == null) return null;
  final drop = start - end;
  return drop > 0 ? drop : null;
}
