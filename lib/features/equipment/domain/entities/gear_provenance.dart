import 'package:equatable/equatable.dart';

/// Where one gear row on a dive or plan came from (issue #1487): the
/// assembly it was attached through, and the equipment set that was
/// applied. Both null means the diver added the item by hand.
///
/// Mirrors the two nullable columns on the gear junctions. Ids only, so
/// the expander and the repositories can work without loading items.
class GearProvenance extends Equatable {
  final String equipmentId;

  /// The immediate parent assembly, null for a top-level row.
  final String? viaEquipmentId;

  /// The set that was applied, carried by every row of its expansion.
  final String? viaSetId;

  const GearProvenance({
    required this.equipmentId,
    this.viaEquipmentId,
    this.viaSetId,
  });

  bool get isTopLevel => viaEquipmentId == null;

  GearProvenance copyWith({
    String? viaEquipmentId,
    String? viaSetId,
    bool clearViaEquipmentId = false,
    bool clearViaSetId = false,
  }) => GearProvenance(
    equipmentId: equipmentId,
    viaEquipmentId: clearViaEquipmentId
        ? null
        : (viaEquipmentId ?? this.viaEquipmentId),
    viaSetId: clearViaSetId ? null : (viaSetId ?? this.viaSetId),
  );

  @override
  List<Object?> get props => [equipmentId, viaEquipmentId, viaSetId];
}
