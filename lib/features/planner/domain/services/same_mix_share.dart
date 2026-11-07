import 'package:submersion/core/constants/enums.dart';
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

/// The cylinders in [tanks] that share what a computed ascent charged to
/// [tankId]: those carrying its mix in the same role class. A deco or stage
/// cylinder shares only with other deco or stage cylinders, the ones the
/// engine's tank-for-gas lookup prefers, so back gas of the same mix is not
/// billed for deco it did not supply. Empty when no cylinder has [tankId].
List<DiveTank> sameMixShareGroup(List<DiveTank> tanks, String? tankId) {
  final charged = tanks.where((t) => t.id == tankId).firstOrNull;
  if (charged == null) return const [];
  bool isDeco(DiveTank tank) =>
      tank.role == TankRole.deco || tank.role == TankRole.stage;
  return [
    for (final tank in sameMixTanks(
      tanks,
      fO2: charged.gasMix.o2 / 100.0,
      fHe: charged.gasMix.he / 100.0,
    ))
      if (isDeco(tank) == isDeco(charged)) tank,
  ];
}

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
/// as one call for their sum: a caller timing each draw can split it as it
/// goes.
Map<String, double> balancedShare(
  double liters,
  List<SharedCylinder> cylinders,
) {
  if (cylinders.isEmpty) return const {};
  if (liters <= 0) return {for (final c in cylinders) c.id: 0.0};
  final known = cylinders.where((c) => c.capacityLiters > 0).toList();
  if (known.isEmpty) {
    final each = liters / cylinders.length;
    return {for (final c in cylinders) c.id: each};
  }
  if (known.length == 1) return {known.single.id: liters};

  double fraction(SharedCylinder c) => c.usedLiters / c.capacityLiters;
  final byUse = [...known]..sort((a, b) => fraction(a).compareTo(fraction(b)));

  // Fill the least-used cylinders up to the next one's fraction, adding a
  // cylinder to the pool each time the level reaches it.
  var pooledCapacity = 0.0;
  var pooledUsed = 0.0;
  var level = 0.0;
  var pooled = 0;
  while (pooled < byUse.length) {
    pooledCapacity += byUse[pooled].capacityLiters;
    pooledUsed += byUse[pooled].usedLiters;
    pooled++;
    level = (liters + pooledUsed) / pooledCapacity;
    if (pooled == byUse.length || fraction(byUse[pooled]) >= level) break;
  }
  return {
    for (var i = 0; i < pooled; i++)
      byUse[i].id: level * byUse[i].capacityLiters - byUse[i].usedLiters,
  };
}
