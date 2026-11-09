import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';

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

/// The roles that mean the primary gas worn on the back: a single cylinder
/// or a manifolded twin set logged as one (issue #3374).
const Set<TankRole> backmountRoles = {TankRole.backGas, TankRole.twinSet};

/// The cylinders of [tanks] that hold breathing gas, in order: every one but
/// a suit inflation bottle (issue #4243, see [TankRole.isBreathingGas]).
/// Every breathing gas calculation starts from this list, not from all of a
/// dive's cylinders.
List<DiveTank> breathingTanks(List<DiveTank> tanks) {
  if (tanks.every((t) => t.role.isBreathingGas)) return tanks;
  return [
    for (final tank in tanks)
      if (tank.role.isBreathingGas) tank,
  ];
}

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

/// The cylinder a SAC in bar is expressed in, chosen among the
/// [breathingTanks]: on a multi-tank dive the backmount gas (back gas or
/// twin set), else the first breathing cylinder; the only one on a dive with
/// one, whatever its role. Never a suit inflation bottle (issue #4243). Null
/// when no cylinder holds breathing gas.
DiveTank? sacReferenceTankOf(List<DiveTank> tanks) {
  final breathing = breathingTanks(tanks);
  if (breathing.isEmpty) return null;
  if (breathing.length == 1) return breathing.first;
  return breathing.firstWhere(
    (t) => backmountRoles.contains(t.role),
    orElse: () => breathing.first,
  );
}

/// The pressure drop of [reference] plus that of every other breathed
/// cylinder of [tanks], each converted into bar of [reference] by volume
/// (`drop * V / Vref`). When either size is unknown, a cylinder of a
/// matched pair with the reference (see [isMatchedPair]) counts one to one.
/// A cylinder whose size cannot be related to the reference, or that was
/// carried but not breathed, adds nothing, and so does a suit inflation
/// bottle (issue #4243), which is no reference either.
///
/// [reference] is the unit of account, so one that was measured and did not
/// fall adds zero and the others still count (#3974). Null when [reference]
/// has no known pressures, since nothing says how much it gave, and when
/// nothing adds up to a drop. A rebreather dive has no SAC at all (issue
/// #3673), so its callers never reach here.
///
/// [dropOf] reads a cylinder's drop, zero when it did not fall and null when
/// it was not measured: its start minus end pressure by default; a part of
/// the dive passes the drop over that part (#2928).
double? referencePressureDrop({
  required DiveTank reference,
  required List<DiveTank> tanks,
  double? Function(DiveTank tank) dropOf = _drop,
}) {
  if (!reference.role.isBreathingGas) return null;
  final referenceDrop = dropOf(reference);
  if (referenceDrop == null) return null;

  var total = referenceDrop;
  for (final tank in tanks) {
    if (identical(tank, reference) || !tank.role.isBreathingGas) continue;
    final drop = dropOf(tank);
    if (drop == null) continue;
    final ratio = referenceBarsPerBar(tank, reference, tanks);
    if (ratio != null) total += drop * ratio;
  }
  return total > 0 ? total : null;
}

/// What one bar of [tank] is worth in bar of [reference]: `V / Vref`, or one
/// to one for a matched pair (see [isMatchedPair]) when either size is
/// unknown. Null when the two cannot be related, so [tank] adds nothing to a
/// [referencePressureDrop].
double? referenceBarsPerBar(
  DiveTank tank,
  DiveTank reference,
  List<DiveTank> tanks,
) {
  if (identical(tank, reference)) return 1;
  final volume = consumptionVolume(tank, tanks);
  final referenceVolume = consumptionVolume(reference, tanks);
  if (volume != null && referenceVolume != null) {
    return volume / referenceVolume;
  }
  return isMatchedPair(tank, reference) ? 1 : null;
}

/// The surface seconds the diver entered on [tanks] that a rate counts
/// (issue #2930): those of each cylinder [contributes] says adds gas to the
/// rate, except where a matched partner in [tanks] entered more (on a tie,
/// the one with the lower id counts). A matched pair is breathed as one
/// timeline, so its shared surface time counts once, at its longer entry.
/// [secondsOf] defaults to the cylinder's own entry. `gas_use_sql.dart`
/// mirrors it; partners share a consumption volume, so they count alike.
int enteredSurfaceSeconds(
  List<DiveTank> tanks, {
  required bool Function(DiveTank tank) contributes,
  int Function(DiveTank tank)? secondsOf,
}) {
  int seconds(DiveTank t) =>
      secondsOf?.call(t) ?? t.surfaceBreathingDuration?.inSeconds ?? 0;
  var total = 0;
  for (final tank in tanks) {
    final own = seconds(tank);
    if (own <= 0 || !contributes(tank)) continue;
    final outdone = tanks.any((p) {
      if (p.id == tank.id || !isMatchedPair(p, tank)) return false;
      final theirs = seconds(p);
      return theirs > own || (theirs == own && p.id.compareTo(tank.id) < 0);
    });
    if (!outdone) total += own;
  }
  return total;
}

/// Two logged mixes within this many percentage points of O2 and of He
/// are the same gas, the tolerance consolidation and the sequential tank
/// merge use. `multi_cylinder_sac_sql.dart` mirrors it.
const double sameGasTolerancePct = 0.5;

/// Whether [a] and [b] are a matched pair, assumed the same size when a
/// size is missing: both sidemount cylinders, both twin set rows (a diver
/// chose that role, so no gas check), or both back gas on the same gas
/// (doubles logged as independents). The gas matters for back gas because
/// downloads default an untagged cylinder, a deco stage included, to that
/// role.
bool isMatchedPair(DiveTank a, DiveTank b) =>
    (sidemountRoles.contains(a.role) && sidemountRoles.contains(b.role)) ||
    (a.role == TankRole.twinSet && b.role == TankRole.twinSet) ||
    (a.role == TankRole.backGas &&
        b.role == TankRole.backGas &&
        (a.gasMix.o2 - b.gasMix.o2).abs() <= sameGasTolerancePct &&
        (a.gasMix.he - b.gasMix.he).abs() <= sameGasTolerancePct);

double? _drop(DiveTank tank) {
  final start = tank.startPressure;
  final end = tank.endPressure;
  if (start == null || end == null) return null;
  final drop = start - end;
  return drop > 0 ? drop : 0;
}
