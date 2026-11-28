import 'package:equatable/equatable.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// What a gear item's seller is (issue #5140).
enum EquipmentSellerKind { buddy, diveCenter, typed }

/// A gear item's seller as it reads: a buddy or dive centre this profile
/// can open, or a typed name.
class EquipmentSeller extends Equatable {
  final EquipmentSellerKind kind;

  /// The buddy's or centre's id; null for a typed seller.
  final String? id;
  final String name;

  const EquipmentSeller({required this.kind, required this.name, this.id});

  @override
  List<Object?> get props => [kind, id, name];
}

/// [item]'s seller, read against the viewing profile's [buddies] and
/// [centers] by id. A link resolves to the target's current name; a link
/// this profile cannot open (another profile's buddy, or one not synced
/// yet) reads as the `retailer` snapshot, typed. Null when there is none.
EquipmentSeller? resolveEquipmentSeller(
  EquipmentItem item, {
  required Map<String, Buddy> buddies,
  required Map<String, DiveCenter> centers,
}) {
  final buddy = buddies[item.sellerBuddyId];
  if (buddy != null) {
    return EquipmentSeller(
      kind: EquipmentSellerKind.buddy,
      id: buddy.id,
      name: buddy.name,
    );
  }
  final center = centers[item.sellerDiveCenterId];
  if (center != null) {
    return EquipmentSeller(
      kind: EquipmentSellerKind.diveCenter,
      id: center.id,
      name: center.name,
    );
  }
  final typed = item.retailer?.trim() ?? '';
  if (typed.isEmpty) return null;
  return EquipmentSeller(kind: EquipmentSellerKind.typed, name: typed);
}
