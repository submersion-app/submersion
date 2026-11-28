import 'package:submersion/core/database/database.dart';
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
  if (name == _trimmed(stored.retailer)) return next;
  if (name != null && name == await _linkedName(db, next)) return next;
  return next.copyWith(clearSellerLinks: true);
}

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
