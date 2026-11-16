import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Volumes closer than this are the same cylinder size (the tolerance
/// [TankPresets] matches specs with).
const double _volumeToleranceL = 0.2;

/// Working pressures closer than this are the same rating, so an AL80 logged
/// at 207 bar matches the preset's 206.8.
const double _pressureToleranceBar = 2.0;

/// One dive tank considered for a cylinder item (issue #4494).
class TankRef {
  const TankRef({required this.diveId, required this.tank});

  final String diveId;
  final DiveTank tank;
}

/// Cylinders the diver could add to their gear for a group of dive tanks of
/// one spec. [tanksByCylinder] has one list per cylinder: on each dive, the
/// dive's tanks of this spec in tank order go to cylinder 1, 2 and so on, so
/// a sidemount pair makes two cylinders rather than one linked twice.
class CylinderProposal {
  const CylinderProposal({
    required this.volumeL,
    required this.workingPressureBar,
    required this.material,
    required this.suitInflation,
    required this.suggestedName,
    required this.tanksByCylinder,
  });

  final double volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;
  final bool suitInflation;

  /// The first tank's own name, else the preset these specs match; null when
  /// neither exists, and the UI describes the size instead.
  final String? suggestedName;
  final List<List<TankRef>> tanksByCylinder;

  int get cylinderCount => tanksByCylinder.length;

  List<TankRef> get allTanks => [for (final c in tanksByCylinder) ...c];

  int get diveCount => {for (final r in allTanks) r.diveId}.length;
}

bool _isSuitTank(DiveTank tank) => tank.role == TankRole.suitInflation;

bool _specMatches({
  required double? volumeL,
  required double? workingPressureBar,
  required TankMaterial? material,
  required DiveTank tank,
}) {
  final tankVolume = tank.volume;
  if (volumeL == null || tankVolume == null) return false;
  if ((volumeL - tankVolume).abs() >= _volumeToleranceL) return false;
  final tankPressure = tank.workingPressure;
  if (workingPressureBar != null &&
      tankPressure != null &&
      (workingPressureBar - tankPressure).abs() >= _pressureToleranceBar) {
    return false;
  }
  final tankMaterial = tank.material;
  return material == null || tankMaterial == null || material == tankMaterial;
}

/// Whether [item] is a cylinder the diver owns that [tank] could be: same
/// size within 0.2 L, and the same rating and material wherever both sides
/// record one. A suit inflation tank matches only suit inflation cylinders,
/// and any other tank only cylinders that are not.
bool cylinderMatchesTank(EquipmentItem item, DiveTank tank) {
  if (item.isSuitInflationCylinder != _isSuitTank(tank)) return false;
  return _specMatches(
    volumeL: item.volumeL,
    workingPressureBar: item.workingPressureBar,
    material: item.tankMaterial,
    tank: tank,
  );
}

/// Whether the twin set of [a] and [b] (issue #4242) is what [tank] logged:
/// the pair's combined volume, the lower working pressure, and a material
/// both cylinders share.
bool pairMatchesTank(EquipmentItem a, EquipmentItem b, DiveTank tank) {
  if (_isSuitTank(tank)) return false;
  final va = a.volumeL;
  final vb = b.volumeL;
  final pa = a.workingPressureBar;
  final pb = b.workingPressureBar;
  final pressure = pa == null ? pb : (pb == null || pa < pb ? pa : pb);
  final ma = a.tankMaterial;
  final mb = b.tankMaterial;
  if (ma != null && mb != null && ma != mb) return false;
  return _specMatches(
    volumeL: va == null || vb == null ? null : va + vb,
    workingPressureBar: pressure,
    material: ma ?? mb,
    tank: tank,
  );
}

/// Groups the [tanks] no cylinder in [owned] (or twin set in [ownedPairs])
/// matches into one proposal per spec, the rows covering the most dives
/// first. Tanks already linked to a gear item, and tanks with no volume,
/// are left out: there is nothing to create or nothing to prefill.
List<CylinderProposal> proposeCylinders(
  List<TankRef> tanks, {
  required List<EquipmentItem> owned,
  required List<(EquipmentItem, EquipmentItem)> ownedPairs,
}) {
  final groups = <_GroupKey, List<TankRef>>{};
  for (final ref in tanks) {
    final tank = ref.tank;
    final volume = tank.volume;
    if (tank.equipmentId != null || volume == null || volume <= 0) continue;
    if (owned.any((item) => cylinderMatchesTank(item, tank))) continue;
    if (ownedPairs.any((p) => pairMatchesTank(p.$1, p.$2, tank))) continue;
    groups.putIfAbsent(_GroupKey.of(tank), () => []).add(ref);
  }
  final proposals = [for (final refs in groups.values) _proposalOf(refs)];
  // A stable sort, so equal rows keep the order the tanks came in.
  final indexed = proposals.indexed.toList()
    ..sort((a, b) {
      final byDives = b.$2.diveCount.compareTo(a.$2.diveCount);
      return byDives != 0 ? byDives : a.$1.compareTo(b.$1);
    });
  return [for (final (_, p) in indexed) p];
}

/// The per-tank "Add to my gear" proposal: one cylinder for [ref] alone,
/// whatever the diver already owns. A tank with no volume proposes 0 L,
/// which the review sheet asks the diver to fill in.
CylinderProposal proposalForTank(TankRef ref) => _proposalOf([ref]);

CylinderProposal _proposalOf(List<TankRef> refs) {
  final byDive = <String, List<TankRef>>{};
  for (final ref in refs) {
    byDive.putIfAbsent(ref.diveId, () => []).add(ref);
  }
  final cylinders = <List<TankRef>>[];
  for (final diveTanks in byDive.values) {
    final ordered = [...diveTanks]
      ..sort((a, b) => a.tank.order.compareTo(b.tank.order));
    for (var i = 0; i < ordered.length; i++) {
      if (cylinders.length <= i) cylinders.add([]);
      cylinders[i].add(ordered[i]);
    }
  }
  final first = refs.first.tank;
  return CylinderProposal(
    volumeL: first.volume ?? 0,
    workingPressureBar: first.workingPressure,
    material: first.material,
    suitInflation: _isSuitTank(first),
    suggestedName: _suggestedName(refs, first),
    tanksByCylinder: cylinders,
  );
}

String? _suggestedName(List<TankRef> refs, DiveTank first) {
  for (final ref in refs) {
    final name = ref.tank.name?.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  final volume = first.volume;
  final pressure = first.workingPressure;
  if (volume == null || pressure == null) return null;
  return TankPresets.matchAnyBySpecs(
    volume,
    pressure,
    material: first.material,
  )?.displayName;
}

/// What makes two tanks one row: the size to a tenth of a liter, the rating
/// to the bar, the material, and whether it is a suit inflation bottle. An
/// absent rating or material is its own value, not a wildcard, so a tank
/// with only a volume never merges into a row that states more.
class _GroupKey {
  const _GroupKey(this.decilitres, this.bar, this.material, this.suit);

  factory _GroupKey.of(DiveTank tank) => _GroupKey(
    (tank.volume! * 10).round(),
    tank.workingPressure?.round(),
    tank.material,
    _isSuitTank(tank),
  );

  final int decilitres;
  final int? bar;
  final TankMaterial? material;
  final bool suit;

  @override
  bool operator ==(Object other) =>
      other is _GroupKey &&
      other.decilitres == decilitres &&
      other.bar == bar &&
      other.material == material &&
      other.suit == suit;

  @override
  int get hashCode => Object.hash(decilitres, bar, material, suit);
}
