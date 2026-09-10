import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// One gear row on a dive: the item plus where it came from (issue #1487).
/// A dive holds one of these per junction row, so membership and
/// provenance cannot drift apart.
class GearLink extends Equatable {
  final EquipmentItem item;

  /// The immediate parent assembly, null for a top-level row.
  final String? viaEquipmentId;

  /// The set that was applied, null when the row was added by hand.
  final String? viaSetId;

  const GearLink({required this.item, this.viaEquipmentId, this.viaSetId});

  bool get isTopLevel => viaEquipmentId == null;

  GearProvenance get provenance => GearProvenance(
    equipmentId: item.id,
    viaEquipmentId: viaEquipmentId,
    viaSetId: viaSetId,
  );

  @override
  List<Object?> get props => [item, viaEquipmentId, viaSetId];
}

/// Wraps items the diver attached by hand: top-level rows with no set.
List<GearLink> looseGear(Iterable<EquipmentItem> items) => [
  for (final item in items) GearLink(item: item),
];

/// Pairs every item with its provenance entry, in item order. An item with
/// no entry is a top-level row added by hand; an entry with no item is
/// ignored. Used where a page holds items and provenance separately.
List<GearLink> gearLinksFor(
  List<EquipmentItem> items,
  List<GearProvenance> provenance,
) {
  final byId = {for (final p in provenance) p.equipmentId: p};
  return [
    for (final item in items)
      GearLink(
        item: item,
        viaEquipmentId: byId[item.id]?.viaEquipmentId,
        viaSetId: byId[item.id]?.viaSetId,
      ),
  ];
}
