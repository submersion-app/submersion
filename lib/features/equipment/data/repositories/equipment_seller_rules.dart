import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// [next] as it may be saved over [stored] (null for a new item), for the
/// seller links (issue #5140):
///
/// - Both links set is refused with an [ArgumentError].
/// - A retailer changed with the links left as they were is a typed seller
///   written by something other than the Seller field (an agent, an
///   import): the links are dropped. Unless the new retailer is the linked
///   buddy's or centre's current name, which is the Seller field picking a
///   renamed seller again.
/// - A linked item saved with its retailer unchanged takes the linked
///   seller's current name, which exports and other profiles read.
Future<EquipmentItem> applySellerRules(
  AppDatabase db, {
  required EquipmentItem? stored,
  required EquipmentItem next,
}) async {
  if (next.sellerBuddyId != null && next.sellerDiveCenterId != null) {
    throw ArgumentError.value(
      next.id,
      'equipment',
      'A gear item names one seller: a buddy or a dive centre, not both',
    );
  }
  if (stored == null) return next;
  final linksKept =
      next.sellerBuddyId == stored.sellerBuddyId &&
      next.sellerDiveCenterId == stored.sellerDiveCenterId;
  final linked = next.sellerBuddyId != null || next.sellerDiveCenterId != null;
  if (!linksKept || !linked) return next;
  final name = _trimmed(next.retailer);
  final current = await _linkedName(db, next);
  if (name == _trimmed(stored.retailer)) {
    return current == null || current == name
        ? next
        : _withRetailer(next, current);
  }
  if (name != null && name == current) return next;
  return next.copyWith(clearSellerLinks: true);
}

EquipmentItem _withRetailer(EquipmentItem item, String name) => item.copyWith(
  attributes: [
    for (final a in item.attributes)
      if (a.isCustom || a.key != EquipmentAttrKeys.retailer) a,
    EquipmentAttribute.curated(
      equipmentId: item.id,
      key: EquipmentAttrKeys.retailer,
      valueText: name,
    ),
  ],
);

String? _trimmed(String? value) {
  final t = value?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

Future<String?> _linkedName(AppDatabase db, EquipmentItem item) async {
  final buddyId = item.sellerBuddyId;
  if (buddyId != null) {
    final row = await (db.select(
      db.buddies,
    )..where((t) => t.id.equals(buddyId))).getSingleOrNull();
    return _trimmed(row?.name);
  }
  final centerId = item.sellerDiveCenterId;
  if (centerId == null) return null;
  final row = await (db.select(
    db.diveCenters,
  )..where((t) => t.id.equals(centerId))).getSingleOrNull();
  return _trimmed(row?.name);
}
