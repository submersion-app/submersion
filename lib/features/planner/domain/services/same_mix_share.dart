import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One cylinder in a group carrying the same mix: what it holds at its fill
/// and what has been breathed from it so far, both in surface liters.
typedef SharedCylinder = ({
  String id,
  double capacityLiters,
  double usedLiters,
});

/// Two gas fractions closer than this are the same mix, the tolerance every
/// tank-for-gas lookup in the planner already matches with.
const double sameMixTolerance = 0.005;

/// The cylinders in [tanks] holding the mix [fO2]/[fHe] (fractions, not
/// percent), in their own order.
List<DiveTank> sameMixTanks(
  Iterable<DiveTank> tanks, {
  required double fO2,
  required double fHe,
}) => [
  for (final tank in tanks)
    if ((tank.gasMix.o2 / 100.0 - fO2).abs() < sameMixTolerance &&
        (tank.gasMix.he / 100.0 - fHe).abs() < sameMixTolerance)
      tank,
];

/// What [tank] holds at its fill in surface liters, the planner's own
/// pricing: an unset size reads as 11 L, and no fill pressure holds nothing.
double fillCapacityLiters(DiveTank tank, GasModel model) {
  final start = tank.startPressure;
  if (start == null) return 0.0;
  return gasVolume(
    tankSizeLiters: tank.volume ?? 11.0,
    pressureBar: start,
    o2Percent: tank.gasMix.o2,
    hePercent: tank.gasMix.he,
    model: model,
  );
}

/// The cylinders in [tanks] that share what a computed ascent charged to
/// [tankId]: every one carrying its mix, whatever its role. On open circuit
/// only the cylinder the deepest leg breathes is back gas, so its twin of
/// the same mix (the other side of a sidemount pair) resolves to a stage;
/// the two share the ascent rather than the stage taking all of it. A deco
/// mix is richer than the bottom mix by definition, so back gas never joins
/// a deco gas's group. Empty when no cylinder has [tankId].
List<DiveTank> sameMixShareGroup(List<DiveTank> tanks, String? tankId) {
  final charged = tanks.where((t) => t.id == tankId).firstOrNull;
  if (charged == null) return const [];
  return sameMixTanks(
    tanks,
    fO2: charged.gasMix.o2 / 100.0,
    fHe: charged.gasMix.he / 100.0,
  );
}

/// Whether [role] is a deco or stage role: the class the engine's
/// tank-for-gas lookup prefers when several cylinders carry a mix.
bool isDecoClassRole(TankRole role) =>
    role == TankRole.deco || role == TankRole.stage;

/// [litersByTank] with each cylinder's liters spread across its
/// [sameMixShareGroup] in [tanks], through [balancedShare].
///
/// For a schedule that charged a mix to the first cylinder holding it: what
/// [alreadyUsed] says a cylinder had given before is balanced against, and
/// left out of the result. A key naming no cylinder in [tanks] is kept as it
/// is.
Map<String, double> spreadAcrossSameMix(
  Map<String, double> litersByTank, {
  required List<DiveTank> tanks,
  required double Function(DiveTank tank) capacityOf,
  Map<String, double> alreadyUsed = const {},
}) {
  final spread = <String, double>{};
  void add(String id, double liters) => spread[id] = (spread[id] ?? 0) + liters;
  // Each cylinder's running total, so a second key of the same mix balances
  // against what the first one's share already gave.
  final used = Map.of(alreadyUsed);
  for (final MapEntry(key: id, value: liters) in litersByTank.entries) {
    final group = sameMixShareGroup(tanks, id);
    if (group.isEmpty) {
      add(id, liters);
      continue;
    }
    final share = balancedShare(liters, [
      for (final tank in group)
        (
          id: tank.id,
          capacityLiters: capacityOf(tank),
          usedLiters: used[tank.id] ?? 0,
        ),
    ]);
    for (final MapEntry(key: shareId, value: shareLiters) in share.entries) {
      add(shareId, shareLiters);
      used[shareId] = (used[shareId] ?? 0) + shareLiters;
    }
  }
  return spread;
}

/// Splits [liters] breathed from one mix across the [cylinders] carrying it,
/// so they end at the same fraction of their own capacity (#4138).
///
/// The least-used cylinders are drawn first until they level with the rest,
/// then every cylinder takes its capacity's share of what is left: the diver
/// swapping regulators to keep the bottles balanced. A draw beyond what the
/// group holds takes every cylinder past empty by the same fraction, so the
/// shortfall shows on each rather than on the first alone.
///
/// A cylinder with no capacity known (no fill pressure) takes nothing while
/// another has one; when none does, the draw splits evenly.
///
/// The level only rises, so calling this once per draw gives the same totals
/// as one call for their sum. A caller timing each draw needs
/// [balancedDrawPhases] instead: within one draw, a cylinder that joins once
/// the levels meet does not draw from the start.
Map<String, double> balancedShare(
  double liters,
  List<SharedCylinder> cylinders,
) {
  final share = {for (final c in cylinders) c.id: 0.0};
  for (final phase in balancedDrawPhases(liters, cylinders)) {
    for (final MapEntry(:key, :value) in phase.liters.entries) {
      share[key] = share[key]! + value;
    }
  }
  return share;
}

/// One stretch of a [balancedDrawPhases] draw: the [fraction] of the draw it
/// covers, and the [liters] each cylinder breathing in it gives.
typedef DrawPhase = ({double fraction, Map<String, double> liters});

/// [balancedShare]'s split of [liters] in the order it is breathed: first
/// the least-used cylinders alone until they level with the next, then that
/// larger pool together, and so on. Each phase's cylinders draw together for
/// its [DrawPhase.fraction] of the draw, so a caller placing the draw in time
/// can place each cylinder's part where it is actually breathed (#4138).
/// Empty when there is nothing to draw.
List<DrawPhase> balancedDrawPhases(
  double liters,
  List<SharedCylinder> cylinders,
) {
  if (cylinders.isEmpty || liters <= 0) return const [];
  final known = cylinders.where((c) => c.capacityLiters > 0).toList();
  if (known.isEmpty) {
    final each = liters / cylinders.length;
    return [
      (fraction: 1.0, liters: {for (final c in cylinders) c.id: each}),
    ];
  }

  double fraction(SharedCylinder c) => c.usedLiters / c.capacityLiters;
  final byUse = [...known]..sort((a, b) => fraction(a).compareTo(fraction(b)));

  final phases = <DrawPhase>[];
  var remaining = liters;
  var pooled = 1;
  var pooledCapacity = byUse.first.capacityLiters;
  var level = fraction(byUse.first);
  while (remaining > 0) {
    // What brings the pool level with the next cylinder, if there is one.
    final next = pooled < byUse.length ? fraction(byUse[pooled]) : null;
    final toNext = next == null
        ? double.infinity
        : (next - level) * pooledCapacity;
    final drawn = toNext < remaining ? toNext : remaining;
    if (drawn > 0) {
      phases.add((
        fraction: drawn / liters,
        liters: {
          for (var i = 0; i < pooled; i++)
            byUse[i].id: drawn * byUse[i].capacityLiters / pooledCapacity,
        },
      ));
    }
    remaining -= drawn;
    if (next == null || remaining <= 0) break;
    level = next;
    pooledCapacity += byUse[pooled].capacityLiters;
    pooled++;
  }
  return phases;
}
